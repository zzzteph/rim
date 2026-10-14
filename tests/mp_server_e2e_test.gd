extends SceneTree
## End to end against the real lobby server: starts `node server/index.js` on a spare port (short countdown),
## connects two games through scripts/botnet_net.gd, and walks the whole path — names, public lobby listed,
## join, chat, host settings, ready → countdown → start, a lockstep match with commands from both sides
## (identical fingerprints, no desync), then a player leaves and the other carries on.
## Needs Node.js (and `npm ci` once in server/).
##   godot --headless --path . --script tests/mp_server_e2e_test.gd

const PORT := 8799
var checks := 0
var failures: Array = []
var server_pid := -1


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func _initialize() -> void:
	_run.call_deferred()


func _start_server() -> void:
	var dir := ProjectSettings.globalize_path("res://server")
	if OS.get_name() == "Windows":
		server_pid = OS.create_process("cmd.exe", ["/c", "cd /d %s && set PORT=%d&& set COUNTDOWN_MS=800&& node index.js" % [dir, PORT]])   # (the repo path has no spaces)
	else:
		server_pid = OS.create_process("sh", ["-c", "cd '%s' && PORT=%d COUNTDOWN_MS=800 exec node index.js" % [dir, PORT]])


func _stop_server() -> void:
	if server_pid <= 0: return
	if OS.get_name() == "Windows": OS.execute("taskkill", ["/T", "/F", "/PID", str(server_pid)])
	else: OS.kill(server_pid)


func _game(player: String):
	var g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	root.add_child(g); g.set_process(false)
	var n = g._net()
	n.url = "ws://127.0.0.1:%d/ws" % PORT
	n.player_name = player
	n.open()
	return g


func _until(cond: Callable, seconds: float, games: Array = []) -> bool:   # let frames pass (games ticking) until cond holds
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		for g in games: g._process(1.0 / 30.0)
		if cond.call(): return true
	return false


func _run() -> void:
	_start_server()
	var a = _game("Ann"); var b = _game("Bob")
	var up: bool = await _until(func(): return a.net.online() and b.net.online(), 15.0)
	check(up, "Both games connect to the local server")
	if not up:
		_finish(); return
	check(a.net.my_id != b.net.my_id and a.net.player_name == "Ann", "Each player gets an id and keeps its name")
	a.net.create(true, 2, "small")
	check(await _until(func(): return a.net.in_lobby(), 5.0), "Creating a public lobby puts you in it")
	b.net.refresh()
	check(await _until(func(): return not b.net.lobbies.is_empty(), 5.0), "The other player sees the public lobby in the list")
	if b.net.lobbies.is_empty():
		_finish(); return
	b.net.join_id(int(b.net.lobbies[0].id))
	check(await _until(func(): return b.net.in_lobby() and (a.net.lobby.players as Array).size() == 2, 5.0), "Joining by the list: two players in the lobby")
	check(a.net.is_host() and not b.net.is_host(), "The creator hosts the lobby")
	b.net.say("hi from Bob")
	check(await _until(func(): return a.net.chat.any(func(l): return str(l.text) == "hi from Bob"), 5.0), "Chat reaches the other player")
	a.net.settings({"size": "small", "max": 2})
	a.net.set_ready(true); b.net.set_ready(true)
	check(await _until(func(): return a.net.countdown_left() > 0.0 or a._mp_on, 5.0), "Both ready: the start countdown runs")
	check(await _until(func(): return a._mp_on and b._mp_on, 8.0), "The countdown ends: both games start the match")
	if not (a._mp_on and b._mp_on):
		_finish(); return
	check(a.PLAYER == 1 and b.PLAYER == 2 and a._mp_hash() == b._mp_hash(), "Factions 1 and 2, one identical town")
	# both players act
	var target := -1
	for i in a.hosts.size():
		if int(a.hosts[i].owner) == 1:
			for o in a.hosts[i].links:
				if int(a.hosts[int(o)].owner) == a.NEUTRAL: target = int(o)
	a.sel = {}
	for i in a.hosts.size():
		if int(a.hosts[i].owner) == 1: a.sel[i] = true
	var target_bots: float = float(a.hosts[target].bots)
	a._wire(target); a._launch(target, "attack")
	var second := -1
	for i in b.hosts.size():
		if int(b.hosts[i].owner) == 2 and not bool(b.hosts[i].rig): second = i
	b._drop_build(second, b._free_slot(second), "intel")
	var compared := {"n": 0, "diff": 0}
	var ah := {}; var bh := {}
	var t_end := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < t_end:
		await process_frame
		var ta: int = a._mp_turn; var tb: int = b._mp_turn
		a._process(1.0 / 30.0); b._process(1.0 / 30.0)
		if a._mp_turn > ta: ah[a._mp_turn - 1] = a._mp_hash()
		if b._mp_turn > tb: bh[b._mp_turn - 1] = b._mp_hash()
	for t in ah:
		if bh.has(t):
			compared.n += 1
			if ah[t] != bh[t]: compared.diff += 1
	check(compared.n >= 60 and compared.diff == 0, "Through the real server: %d turns compared, %d differ" % [compared.n, compared.diff])
	check(a._mp_desync < 0 and b._mp_desync < 0, "The server's fingerprint check saw no desync")
	check(int(a.hosts[target].owner) == 1 or float(a.hosts[target].bots) < target_bots - 0.5, "Player 1's attack wore the target down or took it (%.1f → %.1f, owner %d)" % [target_bots, float(a.hosts[target].bots), int(a.hosts[target].owner)])
	check(not (b.hosts[second].jobs as Dictionary).is_empty() or (b.hosts[second].builds as Array).has("intel"), "Player 2's build order arrived on its building")
	# Bob leaves mid-match: Ann keeps playing, Bob's botnet idles
	b._mp_leave()
	var t0: int = a._mp_turn
	check(await _until(func(): return a._mp_dropped.has(2), 5.0, [a]), "Leaving sends a drop to the other player")
	check(await _until(func(): return a._mp_turn > t0 + 30, 8.0, [a]), "The remaining player keeps playing after the drop")
	check(a.botnets.has(2) and a.rig.has(2), "The leaver's botnet stays on the map")
	_finish()


func _finish() -> void:
	_stop_server()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
