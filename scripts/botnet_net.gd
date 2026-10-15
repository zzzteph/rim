extends Node
## The multiplayer connection: one WebSocket to the lobby server (server/PROTOCOL.md). It keeps what the menu
## shows (lobby list, your lobby, chat, countdown) and hands match messages (start, turn, drop, desync, and
## "closed" when the connection dies) to the game, which runs the lockstep (botnet_proto.gd, _mp_*).

signal changed                          # connection, lobby list, lobby, chat or countdown moved: refresh the menu
signal match_message(msg: Dictionary)   # start · turn · drop · desync · closed

const OFFICIAL_URL := "wss://network.thenakedcat.games/ws"
const SAVE_PATH := "user://multiplayer.cfg"
const CHAT_KEEP := 60
const RETRY_MS := 5000                  # while auto_retry is on, an unreachable server is tried again this often
const ERROR_SHOW_MS := 6000             # a server error ("Lobby is full") is shown this long
const UNAVAILABLE := "Server unavailable"

var url := OFFICIAL_URL                 # always the official server; only a developer's --server=… argument changes it
var auto_retry := false                 # the multiplayer menu is open: keep (re)connecting on our own
var player_name := "Player"
var version := ""                       # the game version: lobbies only match the same one
var status := "offline"                 # offline · connecting · online
var error := ""                         # the last problem, shown in the menu
var error_at := 0                       # Time.get_ticks_msec() of the last server error
var my_id := -1
var lobbies: Array = []                 # public open lobbies of this version
var lobby: Dictionary = {}              # the lobby you are in ({} when none)
var chat: Array = []                    # [{"name", "text", "system"}], newest last
var countdown_end := 0                  # Time.get_ticks_msec() when the start countdown ends (0: none)
var _ws: WebSocketPeer = null
var _was := WebSocketPeer.STATE_CLOSED
var _retry_at := 0


func _ready() -> void:
	process_priority = -10   # poll before the game reads turns in the same frame
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		player_name = clean_name(str(cfg.get_value("mp", "name", player_name)))
	if OS.has_feature("web"):   # the web game served by the server itself talks to that same server (official host or a local test)
		var host = JavaScriptBridge.eval("location.hostname")
		if str(host) in ["network.thenakedcat.games", "localhost", "127.0.0.1"]:
			url = str(JavaScriptBridge.eval("(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws'"))
	for arg in OS.get_cmdline_user_args():   # testing against a local server: -- --server=ws://localhost:8787/ws
		if arg.begins_with("--server="): url = arg.trim_prefix("--server=")


static func clean_name(n: String) -> String:
	var t := n.strip_edges().left(16)
	return t if t != "" else "Player"


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("mp", "name", player_name)
	cfg.save(SAVE_PATH)


func online() -> bool: return status == "online"
func in_lobby() -> bool: return not lobby.is_empty()
func is_host() -> bool: return int(lobby.get("host", -1)) == my_id


func me_ready() -> bool:
	for p in lobby.get("players", []):
		if p is Dictionary and int(p.get("id", -1)) == my_id: return bool(p.get("ready", false))
	return false


func recent_error() -> String:   # the server's last refusal while it is fresh ("" otherwise, and never UNAVAILABLE)
	return error if error != UNAVAILABLE and error != "" and Time.get_ticks_msec() - error_at < ERROR_SHOW_MS else ""


func countdown_left() -> float:   # seconds until the match starts, 0 when no countdown runs
	return maxf(0.0, float(countdown_end - Time.get_ticks_msec()) / 1000.0) if countdown_end > 0 else 0.0


func open() -> void:   # (re)connect to url; a failure is reported as UNAVAILABLE (cleared once the server welcomes us)
	close()
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	if _ws.connect_to_url(url) != OK:
		_ws = null; error = UNAVAILABLE; _retry_at = Time.get_ticks_msec() + RETRY_MS; changed.emit(); return
	status = "connecting"; _was = WebSocketPeer.STATE_CONNECTING
	changed.emit()


func close() -> void:
	if _ws != null: _ws.close()
	_ws = null; status = "offline"; my_id = -1; lobby = {}; lobbies = []; countdown_end = 0


func send(msg: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN: _ws.send_text(JSON.stringify(msg))


# ---- what the menu asks for ----
func rename(n: String) -> void:
	player_name = clean_name(n); save()
	send({"t": "name", "name": player_name})


func refresh() -> void: send({"t": "list"})
func create(public: bool, max_players: int, size: String) -> void: send({"t": "create", "public": public, "max": max_players, "size": size})
func join_id(id: int) -> void: send({"t": "join", "id": id})
func join_code(code: String) -> void: send({"t": "join", "code": code.strip_edges().to_upper()})
func leave() -> void: send({"t": "leave"})
func set_ready(r: bool) -> void: send({"t": "ready", "ready": r})
func settings(s: Dictionary) -> void: s["t"] = "settings"; send(s)
func say(text: String) -> void:
	var t := text.strip_edges().left(200)
	if t != "": send({"t": "chat", "text": t})


func _process(_dt: float) -> void:
	if _ws == null:
		if auto_retry and Time.get_ticks_msec() >= _retry_at: open()
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and _was != WebSocketPeer.STATE_OPEN:
		send({"t": "hello", "name": player_name, "version": version})
	_was = st
	while _ws != null and _ws.get_available_packet_count() > 0:
		var parsed: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if parsed is Dictionary: _on(parsed)
	if _ws != null and st == WebSocketPeer.STATE_CLOSED:
		_ws = null; status = "offline"; my_id = -1; lobby = {}; countdown_end = 0
		error = UNAVAILABLE
		_retry_at = Time.get_ticks_msec() + RETRY_MS
		match_message.emit({"t": "closed"})
		changed.emit()


func _on(m: Dictionary) -> void:
	var t := str(m.get("t", ""))
	match t:
		"welcome":
			my_id = int(m.get("id", -1)); player_name = clean_name(str(m.get("name", player_name)))
			status = "online"; error = ""
			send({"t": "list"})
		"lobbies": lobbies = m.get("lobbies") if m.get("lobbies") is Array else []
		"lobby":
			var was := in_lobby()
			lobby = m.get("lobby") if m.get("lobby") is Dictionary else {}
			if not was: chat.clear()
			if str(lobby.get("state", "")) != "countdown": countdown_end = 0
		"left":
			lobby = {}; countdown_end = 0; chat.clear()
			send({"t": "list"})
			match_message.emit(m)   # out of a running match too (a late Leave, or removed for not responding)
		"chat":
			chat.append({"name": str(m.get("name", "")), "text": str(m.get("text", "")), "system": bool(m.get("system", false))})
			while chat.size() > CHAT_KEEP: chat.pop_front()
		"countdown":
			var secs := float(m.get("secs", 0))
			countdown_end = Time.get_ticks_msec() + int(secs * 1000.0) if secs > 0.0 else 0
		"error": error = str(m.get("msg", "Something went wrong")); error_at = Time.get_ticks_msec()
		"start":
			countdown_end = 0
			match_message.emit(m)
		"turn", "drop", "desync":
			match_message.emit(m)
			return   # many per second: the menu does not need them
	changed.emit()
