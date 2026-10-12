extends Control
## PROTOTYPE v2 — macro/micro botnet race, free for all (spec: design/BOTNET_ATTACK_DESIGN.md).
##
## GLOBAL map (this screen) = MACRO: you wire where bots go and redirect Cash traffic between buildings.
## LOCAL view ("Enter building") = MICRO: you build inside one building. Entering takes time, a build
## only progresses while you stay inside, and while you are inside the map KEEPS RUNNING and cannot be
## commanded — attention is the cost of micro.
##
## TWO SEPARATE VERBS — the user's control scheme (do not merge them):
##   1. CONNECT — DRAG a line from your building (or a selected group member) onto a target. Drag-and-drop
##      is the ONLY wiring gesture; clicking never wires (it selects / opens a panel). A link can only be
##      made where a path runs through YOUR OWN buildings — never through foreign territory. Wiring makes
##      a dashed, DORMANT connection: it never fires, never spends Intel, and can be rewired forever. One
##      connection per building; rewiring replaces it (a rewired connection is dormant until launched again).
##   2. LAUNCH / GUARD — "attack and defend is the STATUS" of a wire. Wire → a FOREIGN building = an ATTACK:
##      click that building and press ⚔ ATTACK on its panel (the only trigger); each target launches
##      independently and later wires stay dormant until the button is pressed again. Wire → YOUR OWN
##      building = a GUARD: it arms ITSELF the moment that building is under attack (or below full) and
##      stands down after — no button, never hand-stopped, only disconnected. "Stop" pauses attack flows but
##      keeps wires; "Disconnect" removes them. Esc / right-click clears selection — never your wires.
##
##   • A generated TOWN, different every run: a 6×6 cell grid with gaps, jittered positions, missing and
##     diagonal streets, a rich DOWNTOWN in the middle and a poor rim. Buildings differ in security
##     (neutral defenders), slots (how much you can build inside) and value (Cash per market packet).
##   • FREE FOR ALL: YOU (top-left), the NYX botnet (bottom-right) and the KRAKEN botnet (bottom-left) all
##     start with a rig and one building; the rest of the town is NEUTRAL, guarded by its own security which
##     regenerates only to its own level. Every botnet plays by the same rules: it builds inside its
##     buildings, pays 1 Intel per attack bot, routes Cash home, defends, and wins by banking CASH_GOAL first.
##   • A building's bots ARE its health and its defence (cap NODE_CAP once owned). It regenerates PROD_RATE
##     per Bot farm it runs. The more bots it holds the more of its slots keep working (control stages).
##   • A live flow releases one bot per second × the source's rate dial along its own network. Bots act only
##     on ARRIVAL: an attack arrival removes ATTACK/DEFEND (≈0.667) of a defender; a reinforcement adds a
##     full bot. At 0 the building flips.
##   • Links have CAPACITY (LINK_CAP packets per LINK_TIME per direction). Bots and Cash packets share
##     it: a busy link queues packets at the building before it and holds a source whose queue is long.
##   • Rally point (one): every UNWIRED idle building of yours sends its surplus above a garrison to it —
##     the command-unit experiment (does one standing order for the rear scale to a town?).
## SPACE pauses everything.

const NEUTRAL := 0
const PLAYER := 1
const RIVAL := 2          # NYX
const RIVAL2 := 3         # KRAKEN
const FACTIONS := {
	0: {"name": "city security", "col": Color(0.35, 0.45, 0.6)},
	1: {"name": "yours",         "col": Color(0.25, 0.85, 0.45)},
	2: {"name": "NYX",           "col": Color(0.85, 0.3, 0.33)},
	3: {"name": "KRAKEN",        "col": Color(0.7, 0.4, 0.95)},
}
const BOTNETS := [1, 2, 3]
const AIS := [2, 3]
# AI personalities: aggr = taste for attacking other botnets and opening a second front; cadence = think rate
const AI_PROFILE := {2: {"aggr": 0.8, "cadence": 3.0}, 3: {"aggr": 0.45, "cadence": 3.5}}

# ── the town ──
const GRID_COLS := 6
const GRID_ROWS := 6
const EMPTY_CELL := 0.15           # chance a cell is a gap (park, void) — never the rigs or downtown
const LINK_KEEP := 0.78            # chance a street between two neighbouring buildings exists
const DIAG_P := 0.18               # chance of a diagonal shortcut street
const TOWN_WORDS := ["Block", "Yard", "Row", "Plaza", "Depot", "Tower", "Mill", "Court", "Lane", "Pier", "Works", "Arcade"]

# ── building TYPES: slots and production multipliers; the picture on the map is the type's icon ──
const NODE_TYPES := {
	"pc":     {"name": "PC",          "short": "PC",   "slots": 3, "bot": 1.0, "intel": 1.0, "cash": 1.0, "sec": 0,  "desc": "an office workstation — 3 slots"},
	"iot":    {"name": "IoT device",  "short": "IoT",  "slots": 1, "bot": 1.0, "intel": 1.0, "cash": 1.0, "sec": -3, "desc": "a camera or a router — 1 slot, soft"},
	"server": {"name": "Server",      "short": "Srv",  "slots": 3, "bot": 1.0, "intel": 1.5, "cash": 1.0, "sec": 2,  "desc": "a rack server — 3 slots, Intel ×1.5"},
	"web":    {"name": "Web server",  "short": "Web",  "slots": 3, "bot": 1.0, "intel": 1.5, "cash": 1.0, "sec": 2,  "desc": "a public web host — 3 slots, Intel ×1.5"},
	"db":     {"name": "Database",    "short": "DB",   "slots": 4, "bot": 1.0, "intel": 2.0, "cash": 1.0, "sec": 3,  "desc": "a database cluster — 4 slots, Intel ×2"},
	"file":   {"name": "File server", "short": "Files","slots": 4, "bot": 1.0, "intel": 2.0, "cash": 1.0, "sec": 3,  "desc": "a file server — 4 slots, Intel ×2"},
	"erp":    {"name": "ERP system",  "short": "ERP",  "slots": 5, "bot": 1.5, "intel": 1.5, "cash": 1.5, "sec": 6,  "desc": "an enterprise core — 5 slots, everything ×1.5"},
}
# spawn weights by district value (rim 1 … downtown 3)
const TYPE_WEIGHTS := {
	1: {"iot": 0.35, "pc": 0.40, "web": 0.10, "server": 0.10, "file": 0.05},
	2: {"pc": 0.30, "server": 0.20, "web": 0.20, "db": 0.15, "file": 0.15},
	3: {"db": 0.25, "file": 0.20, "server": 0.20, "web": 0.15, "erp": 0.20},
}

const NODE_CAP := 30.0             # bots limit per OWNED building
const PROD_RATE := 1.0             # bots/sec PER active Bot farm

# combat power — a defender is worth 1.5× an attacker (D = 1.5·A); an arriving attack bot removes A/D
const ATTACK_POWER := 1.0
const DEFEND_POWER := 1.5

# ── the LOCAL layer: buildings inside a building (slots), built on a timer while you are INSIDE ──
const BUILD_TIME := 10.0           # seconds a build job needs; YOUR jobs progress only while you are inside
const DEMOLISH_TIME := 5.0         # seconds to clear an occupied slot first (replace = DEMOLISH_TIME + BUILD_TIME)
const ENTER_TIME := 2.0            # seconds to connect into a building before its local view is usable
const BUILD_KINDS := {
	"bot":   {"name": "Bot farm",        "short": "B", "col": Color(0.45, 0.95, 0.6),  "desc": "+1 bot/s regeneration here"},
	"intel": {"name": "Intel harvester", "short": "I", "col": Color(0.4, 0.85, 1.0),   "desc": "+1 Intel/s (global). Attacks spend 1 Intel per bot."},
	"cash":  {"name": "Darknet market",  "short": "$", "col": Color(1.0, 0.85, 0.3),   "desc": "a Cash packet (worth the building's value) every 3 s, travelling home to your rig"},
	"cap":   {"name": "Intel vault",     "short": "C", "col": Color(0.75, 0.55, 1.0),  "desc": "+100 Intel capacity"},
}
const INTEL_START := 50.0
const INTEL_CAP_BASE := 100.0
const CAP_PER_BUILD := 100.0
const INTEL_PER_BUILD := 1.0
const CASH_INTERVAL := 3.0         # seconds between Cash packets per active Darknet market
const CASH_GOAL := 600.0           # bank this first → win (another botnet banking it first → defeat)

# ── the bot-flow dials ──
# ── scanning: a foreign building must be SCANNED before it can be attacked. Scan bots travel like attack
# bots, cost the same, and are consumed on arrival without hurting a defender; they reveal the target's bots
# and slots once SCAN_BASE + SCAN_PER_BUILD × (buildings inside) of them have landed. The protection is a
# fixed threshold: not regenerated, not depleted. A changed inside (built, demolished, replaced) needs a rescan.
const SCAN_BASE := 10.0
const SCAN_PER_BUILD := 5.0
const SCAN_COSTS_INTEL := true     # scan bots are attack bots: 1 Intel each
# Any ATTACK on an unscanned building reveals it as its bots land — but it raises the alarm (red frame,
# guards arm, the owner's AI reacts). The SCAN launch is the quiet route: nothing alerts the owner.

const SEND_RATE := 1.0             # bots/sec a live flow releases at rate dial 100%
const LINK_TIME := 1.0             # seconds to cross one link (hop)
const NODE_ROUTE_DELAY := 0.25     # pause (s) at each intermediate building
const LINK_CAP := 2                # packets a link DIRECTION admits per LINK_TIME (throughput 2/s)
const MAX_QUEUE := 1.0             # a source holds its packet if the first link can't admit it within this

# ── control stages: fewer bots → fewer working slots (first slot always works) ──
const STAGE_FULL := 2.0 / 3.0
const STAGE_SHAKY := 1.0 / 3.0
const STAGE_NAME := ["FULL", "SHAKY", "CRITICAL"]

# ── rally (command-unit experiment) & the AI botnets ──
const RALLY_RESERVE := 10.0        # an auto-supplying building keeps this garrison at home
const AI_MAX_STREAMS := 4          # sources an AI concentrates on one target
const AI_RESERVE := 6.0            # garrison an AI building keeps
const AI_PATIENCE := 30.0          # seconds WITHOUT PROGRESS before an AI gives up an attack
const PANEL_W := 440.0

var town_seed := 0                 # 0 = a new town every run; set before _ready to reproduce a layout
var ai_enabled := true             # probes switch the AI botnets off for fixture cases

var rng := RandomNumberGenerator.new()
var _t := 0.0                      # the single simulation clock everything shares
var paused := false
var won := false
var lost := false
var _end_shown := false
var _end_cause := ""
var _msg := ""
var _msg_t := 0.0

var hosts := []        # {pos,grid,name,links,owner,bots,sec,value,slots,builds,job,assign,live,rate,hub,rig}
var hub := -1
var rig := {}          # faction -> index of its rig (the Cash sink)
var _cell := {}        # Vector2i grid cell -> host index (gaps have no entry)
var intel := {}        # faction -> Intel reserve
var cash := {}         # faction -> Cash banked
var flights := []      # {route:[idx], hops:[link entry times], depart_t, arrive_t, owner, kind:"bot"|"cash", amount}
var _res := {}         # "a>b" -> sorted entry times reserved on that link direction (capacity)
var _next_depart := {} # bot source -> absolute time its next bot is due
var _next_cash := {}   # cash emitter -> absolute time its next packet is due
var rally := -1        # your rally point, or -1
var _inside := -1      # the building whose LOCAL view is open, or -1
var _enter_left := 0.0 # seconds until the local view is usable
var _ai := {}          # faction -> {timer, ops:{target:{since,bots}}, avoid, dead}
var scans := {}        # faction -> {host: {"key": contents when scanned, "done": bool, "progress": bots landed}}

# selection / command
var sel := {}          # selected buildings of yours (the ones a drag would wire)
var _inspect := -1     # the building whose panel is open (a target's panel carries its ⚔ ATTACK launch), or -1
var _press_pos := Vector2.ZERO
var _boxing := false
var _box_start := Vector2.ZERO
var _drag_from := -1   # your building a line is being dragged FROM (to wire a target), or -1
var _dragging := false
var _emit_cursor := 0
var _panel_t := 0.0

var hud: Label
var panel: Panel
var panel_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_gen()
	var sz := get_viewport_rect().size
	hud = Label.new(); hud.position = Vector2(20, 10)
	hud.size = Vector2(sz.x - PANEL_W - 60.0, 70)
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_theme_font_size_override("font_size", 15); add_child(hud)
	panel = Panel.new(); panel.size = Vector2(PANEL_W, sz.y - 24.0)
	panel.position = Vector2(sz.x - PANEL_W - 12.0, 12.0); add_child(panel)
	var sc := ScrollContainer.new()
	sc.position = Vector2(8, 8); sc.size = panel.size - Vector2(16, 16)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.custom_minimum_size = Vector2(PANEL_W - 36.0, 0)
	sc.add_child(panel_box)
	_refresh_panel(); set_process(true)


func fname(fac: int) -> String: return str(FACTIONS[fac].name)
func fcol(fac: int) -> Color: return FACTIONS[fac].col


# ============================================================ TOWN GENERATION
# A different town every run: cells may be gaps, positions jitter, streets are missing or diagonal,
# downtown is rich and well defended, the rim is poor and soft. Everything stays connected.
func _gen() -> void:
	if town_seed == 0:
		rng.randomize(); town_seed = int(rng.randi() % 900000) + 1
	rng.seed = town_seed
	var sz := get_viewport_rect().size
	hosts = []; hub = -1; rig = {}; _cell = {}; flights = []; _res = {}; _next_depart = {}; _next_cash = {}
	intel = {}; cash = {}; _ai = {}
	for fac in BOTNETS: intel[fac] = INTEL_START; cash[fac] = 0.0; scans[fac] = {}
	for fac in AIS: _ai[fac] = {"timer": float(AI_PROFILE[fac].cadence) * (0.5 + 0.3 * float(fac)), "ops": {}, "avoid": -1, "dead": false}
	var ax := 70.0; var ay := 112.0
	var aw := sz.x - PANEL_W - 150.0; var ah := sz.y - ay - 120.0
	var sx := aw / float(GRID_COLS - 1); var sy := ah / float(GRID_ROWS - 1)
	var centre := Vector2(float(GRID_COLS - 1) * 0.5, float(GRID_ROWS - 1) * 0.5)
	var hub_cell := Vector2i(int(centre.x) + (rng.randi() % 2), int(centre.y) + (rng.randi() % 2))
	var starts := {   # each botnet: [rig cell, second cell]
		PLAYER: [Vector2i(0, 0), Vector2i(0, 1)],
		RIVAL:  [Vector2i(GRID_COLS - 1, GRID_ROWS - 1), Vector2i(GRID_COLS - 1, GRID_ROWS - 2)],
		RIVAL2: [Vector2i(0, GRID_ROWS - 1), Vector2i(0, GRID_ROWS - 2)],
	}
	var forced := [hub_cell]
	for fac in starts.keys(): forced += starts[fac]
	for gy in GRID_ROWS:
		for gx in GRID_COLS:
			var c := Vector2i(gx, gy)
			if not forced.has(c) and rng.randf() < EMPTY_CELL: continue   # a park, a lot, a void
			var is_hub: bool = c == hub_cell
			var dist: float = Vector2(gx, gy).distance_to(centre) / centre.length()   # 0 downtown … 1 corner
			var value := 3 if (is_hub or dist < 0.38) else (2 if dist < 0.72 else 1)
			if not is_hub and rng.randf() < 0.2: value = clampi(value + (1 if rng.randf() < 0.5 else -1), 1, 3)
			var ntype := "erp" if is_hub else _pick_type(value)
			var tp: Dictionary = NODE_TYPES[ntype]
			var sec := 30.0 if is_hub else clampf(float(2 + value * 5 + int(rng.randi() % 6) + int(tp.sec)), 4.0, 28.0)   # 4…28 defenders
			var slots := int(tp.slots)
			var p := Vector2(ax + sx * float(gx), ay + sy * float(gy)) + Vector2(rng.randf_range(-0.26, 0.26) * sx, rng.randf_range(-0.26, 0.26) * sy)
			_cell[c] = hosts.size()
			if is_hub: hub = hosts.size()
			hosts.append({"pos": p, "grid": c, "hub": is_hub, "rig": false,
				"name": "DOWNTOWN HUB" if is_hub else "%s %d" % [str(tp.short), hosts.size() + 1], "type": ntype,
				"links": [], "owner": NEUTRAL, "bots": sec, "sec": sec, "value": value, "slots": slots,
				"builds": _slot_array(["bot", "bot"] if is_hub else ["bot"], slots), "job": {}, "assign": -1, "live": false, "mode": "attack", "rate": 1.0})
	for c in _cell.keys():   # streets: grid neighbours (some missing), a few diagonals (never crossing)
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb: Vector2i = c + d
			if not _cell.has(nb): continue
			var must := false
			for fac in starts.keys():
				if (starts[fac] as Array).has(c) and (starts[fac] as Array).has(nb): must = true
			if must or rng.randf() < LINK_KEEP: _link(_cell[c], _cell[nb])
		var se: Vector2i = c + Vector2i(1, 1)
		if _cell.has(se) and rng.randf() < DIAG_P: _link(_cell[c], _cell[se])
		var ne: Vector2i = c + Vector2i(1, -1)
		var up: Vector2i = c + Vector2i(0, -1)
		var rt: Vector2i = c + Vector2i(1, 0)
		if _cell.has(ne) and rng.randf() < DIAG_P:
			var crosses: bool = _cell.has(up) and _cell.has(rt) and (hosts[_cell[up]].links as Array).has(_cell[rt])
			if not crosses: _link(_cell[c], _cell[ne])
	var guard := 0   # connect every island to the main town by its shortest gap
	while guard < 64:
		guard += 1
		var comps := _components()
		if comps.size() <= 1: break
		var main: Array = comps[0]
		var best := INF; var pa := -1; var pb := -1
		for k in range(1, comps.size()):
			for a in main:
				for b in comps[k]:
					var dd: float = (hosts[int(a)].pos as Vector2).distance_to(hosts[int(b)].pos)
					if dd < best: best = dd; pa = int(a); pb = int(b)
		if pa >= 0: _link(pa, pb)
	# every botnet starts with a rig (its Cash sink) and one more building
	_claim(_cell[starts[PLAYER][0]], PLAYER, true, "YOUR RIG")
	_claim(_cell[starts[PLAYER][1]], PLAYER, false, "")
	_claim(_cell[starts[RIVAL][0]], RIVAL, true, "NYX RIG")
	_claim(_cell[starts[RIVAL][1]], RIVAL, false, "")
	_claim(_cell[starts[RIVAL2][0]], RIVAL2, true, "KRAKEN RIG")
	_claim(_cell[starts[RIVAL2][1]], RIVAL2, false, "")


func _components() -> Array:   # connected groups of buildings over the street network, ownership ignored
	var seen := {}; var out := []
	for s in hosts.size():
		if seen.has(s): continue
		var comp := [s]; seen[s] = true; var head := 0
		while head < comp.size():
			var c: int = comp[head]; head += 1
			for o in hosts[c].links:
				if not seen.has(o): seen[o] = true; comp.append(int(o))
		out.append(comp)
	out.sort_custom(func(a, b): return a.size() > b.size())
	return out


func _claim(i: int, fac: int, is_rig: bool, nm: String) -> void:   # every botnet starts with a Server rig + a PC
	hosts[i].owner = fac; hosts[i].bots = NODE_CAP; hosts[i].value = 1
	hosts[i].type = "server" if is_rig else "pc"; hosts[i].slots = int(NODE_TYPES[hosts[i].type].slots)
	if is_rig:
		hosts[i].rig = true; rig[fac] = i; hosts[i].builds = _slot_array(["bot", "bot"], int(hosts[i].slots))
	else:
		hosts[i].builds = _slot_array(_built_kinds(i), int(hosts[i].slots))
		hosts[i].name = "PC %d" % (i + 1)
	if nm != "": hosts[i].name = nm


func _pick_type(value: int) -> String:   # weighted by district: soft IoT and PCs on the rim, data and ERP downtown
	var w: Dictionary = TYPE_WEIGHTS[clampi(value, 1, 3)]
	var r := rng.randf(); var acc := 0.0
	for k in w.keys():
		acc += float(w[k])
		if r <= acc: return str(k)
	return str(w.keys()[w.size() - 1])


func _tmult(i: int, what: String) -> float:   # the building type's multiplier for "bot", "intel" or "cash"
	return float(NODE_TYPES[str(hosts[i].get("type", "pc"))].get(what, 1.0))


func _regen(i: int) -> float:   # bots/s the building regenerates (its working Bot farms × its type)
	return float(_count(i, "bot")) * PROD_RATE * _tmult(i, "bot")


# ---- scanning ----
func _contents_key(i: int) -> String:   # what a scan learned; any change inside invalidates it
	return ",".join(PackedStringArray(hosts[i].builds))


func _scan_cost(i: int) -> float:   # scan bots needed: a fixed protection plus more per building inside
	return SCAN_BASE + SCAN_PER_BUILD * float(_built_kinds(i).size())


func _scanned(fac: int, t: int) -> bool:   # you always know your own buildings
	if t < 0 or fac == NEUTRAL: return false
	if int(hosts[t].owner) == fac: return true
	var rec: Dictionary = (scans[fac] as Dictionary).get(t, {})
	return not rec.is_empty() and bool(rec.done) and str(rec.key) == _contents_key(t)


func _scan_progress(fac: int, t: int) -> float:
	var rec: Dictionary = (scans[fac] as Dictionary).get(t, {})
	if rec.is_empty() or str(rec.key) != _contents_key(t): return 0.0
	return float(rec.progress)


func _mark_scanned(fac: int, t: int) -> void:   # scripts/probes and the moment a scan completes
	scans[fac][t] = {"key": _contents_key(t), "done": true, "progress": _scan_cost(t)}


func _scan_land(fac: int, t: int) -> void:   # one scan bot arrived: progress, and completion stands wires down
	var key := _contents_key(t)
	var rec: Dictionary = (scans[fac] as Dictionary).get(t, {})
	if rec.is_empty() or str(rec.key) != key: rec = {"key": key, "done": false, "progress": 0.0}
	rec.progress = float(rec.progress) + 1.0
	if float(rec.progress) >= _scan_cost(t): rec.done = true
	scans[fac][t] = rec
	if not bool(rec.done): return
	var stood := 0
	for i in hosts.size():   # a secret scan is done: its flows stand down; attacking is a separate, explicit launch
		if int(hosts[i].owner) == fac and int(hosts[i].assign) == t and bool(hosts[i].live) and str(hosts[i].get("mode", "attack")) == "scan":
			hosts[i].live = false; _next_depart.erase(i); stood += 1
	if fac == PLAYER:
		if stood > 0: _flash("🔍 Scanned %s quietly — %d bots, inside: %s. Press ATTACK to launch." % [str(hosts[t].name), int(round(float(hosts[t].bots))), _build_names(hosts[t].builds)])
		else: _flash("🔍 Your attack revealed %s — %d bots, inside: %s" % [str(hosts[t].name), int(round(float(hosts[t].bots))), _build_names(hosts[t].builds)])
		_refresh_panel()


func _slot_array(kinds: Array, n: int) -> Array:   # positional slots, "" = empty
	var out := []
	for k in n: out.append(str(kinds[k]) if k < kinds.size() else "")
	return out


func _set_builds(i: int, kinds: Array) -> void:   # scripts/probes: place these kinds from slot 1, pad with empties
	hosts[i].slots = maxi(int(hosts[i].slots), kinds.size())
	hosts[i].builds = _slot_array(kinds, int(hosts[i].slots))


func _built_kinds(i: int) -> Array:   # kinds present, in slot order (empties skipped)
	var out := []
	for b in hosts[i].builds:
		if str(b) != "": out.append(str(b))
	return out


func _link(a: int, b: int) -> void:
	if a == b: return
	if not (hosts[a].links as Array).has(b): hosts[a].links.append(b)
	if not (hosts[b].links as Array).has(a): hosts[b].links.append(a)


func cell_at(gx: int, gy: int) -> int:   # host index at a grid cell, or -1 for a gap
	return int(_cell.get(Vector2i(gx, gy), -1))


func _mine(i: int) -> bool: return i >= 0 and int(hosts[i].owner) == PLAYER


func _is_botnet(fac: int) -> bool: return fac != NEUTRAL


func _cap_of(i: int) -> float:   # neutral security regenerates only to its own level; owned → NODE_CAP
	return NODE_CAP if int(hosts[i].owner) != NEUTRAL else float(hosts[i].sec)


func _r(i: int) -> float:   # drawn radius grows with the building's slots
	return 11.0 + 2.5 * float(hosts[i].slots)


# route packets travel: BFS over same-faction buildings from src to one bordering t, then the final hop
func _route(src: int, t: int) -> Array:
	if src < 0 or t < 0 or src == t: return []
	var fac := int(hosts[src].owner)
	var prev := {src: src}; var q := [src]; var head := 0; var hit := -1
	while head < q.size():
		var c: int = q[head]; head += 1
		for o in hosts[c].links:
			if int(o) == t: hit = c; break
		if hit >= 0: break
		for o in hosts[c].links:
			if int(hosts[o].owner) == fac and not prev.has(o): prev[o] = c; q.append(o)
	if hit < 0: return []
	var p := [hit]
	while int(p[p.size() - 1]) != src: p.append(prev[p[p.size() - 1]])
	p.reverse(); p.append(t)
	return p


# ---- link capacity: a link direction admits LINK_CAP packets per LINK_TIME; later ones queue ----
func _lkey(a: int, b: int) -> String: return "%d>%d" % [a, b]


# earliest time >= t at which link direction `key` can admit one more packet
func _link_entry(key: String, t: float) -> float:
	var arr: Array = _res.get(key, [])
	var e := t
	var guard := 0
	while guard < 10000:
		guard += 1
		var oldest := INF; var n := 0
		for x in arr:
			var xf := float(x)
			if xf > e - LINK_TIME and xf <= e + 0.00001:
				n += 1
				if xf < oldest: oldest = xf
		if n < LINK_CAP: return e
		e = oldest + LINK_TIME + 0.0001
	return e


func _reserve(key: String, e: float) -> void:
	if not _res.has(key): _res[key] = []
	var arr: Array = _res[key]
	var k := arr.size()
	while k > 0 and float(arr[k - 1]) > e: k -= 1
	arr.insert(k, e)


func _prune_res() -> void:
	for key in _res.keys():
		var arr: Array = _res[key]
		while not arr.is_empty() and float(arr[0]) < _t - LINK_TIME - 0.01: arr.remove_at(0)
		if arr.is_empty(): _res.erase(key)


# schedule a packet along rt departing at dep: every hop waits for room on its link (queue at the
# building), then crosses it; intermediate buildings add NODE_ROUTE_DELAY. The timeline is fixed here.
func _schedule(rt: Array, dep: float, fac: int, kind: String, amount := 1.0) -> Dictionary:
	var hops := []
	var t := dep
	for k in range(rt.size() - 1):
		var key := _lkey(int(rt[k]), int(rt[k + 1]))
		var e := _link_entry(key, t)
		_reserve(key, e)
		hops.append(e)
		t = e + LINK_TIME
		if k < rt.size() - 2: t += NODE_ROUTE_DELAY
	return {"route": rt, "hops": hops, "depart_t": dep, "arrive_t": t, "owner": fac, "kind": kind, "amount": amount}


func _first_wait(rt: Array) -> float:   # how long the first link would make this packet wait right now
	if rt.size() < 2: return 0.0
	return _link_entry(_lkey(int(rt[0]), int(rt[1])), _t) - _t


# uncongested travel time: hops × LINK_TIME + intermediate buildings × NODE_ROUTE_DELAY
func _travel_time(rt: Array) -> float:
	if rt.size() < 2: return 0.0
	return float(rt.size() - 1) * LINK_TIME + float(maxi(0, rt.size() - 2)) * NODE_ROUTE_DELAY


# where a packet is at time `now`: queued at a building, crossing a link, or arrived
func _packet_pos(f: Dictionary, now: float) -> Vector2:
	var rt: Array = f.route
	var hops: Array = f.hops
	if rt.size() < 2: return hosts[int(rt[0])].pos
	for k in hops.size():
		var h := float(hops[k])
		if now < h: return hosts[int(rt[k])].pos
		if now < h + LINK_TIME: return (hosts[int(rt[k])].pos as Vector2).lerp(hosts[int(rt[k + 1])].pos, (now - h) / LINK_TIME)
	return hosts[int(rt[rt.size() - 1])].pos


func _link_busy(a: int, b: int) -> bool:   # either direction at capacity right now
	for key in [_lkey(a, b), _lkey(b, a)]:
		var n := 0
		for x in _res.get(key, []):
			if float(x) > _t - LINK_TIME and float(x) <= _t: n += 1
		if n >= LINK_CAP: return true
	return false


func _link_kind(src: int, t: int) -> String:   # what a wire from src into t would be, "" if impossible
	if src < 0 or t < 0 or src == t or not _mine(src): return ""
	if _route(src, t).is_empty(): return ""
	return "defend" if _mine(t) else "attack"


func _player_nodes() -> int:
	return _faction_nodes(PLAYER)


func _faction_nodes(fac: int) -> int:
	var n := 0
	for h in hosts:
		if int(h.owner) == fac: n += 1
	return n


func _incoming(t: int, fac: int) -> float:   # bots of a faction currently flying toward t
	var s := 0.0
	for f in flights:
		if str(f.kind) == "bot" and int((f.route as Array)[(f.route as Array).size() - 1]) == t and int(f.owner) == fac: s += 1.0
	return s


func _hostile_incoming(t: int) -> float:   # bots of ANY other faction flying toward t
	var s := 0.0
	for f in flights:
		if str(f.kind) == "bot" and int((f.route as Array)[(f.route as Array).size() - 1]) == t and int(f.owner) != int(hosts[t].owner): s += 1.0
	return s


func _under_attack(t: int) -> bool:   # hostile attack bots inbound, or a hostile LIVE attack wire aimed at it
	if _hostile_incoming(t) > 0.0: return true
	for i in hosts.size():
		if int(hosts[i].owner) != int(hosts[t].owner) and bool(hosts[i].live) and int(hosts[i].assign) == t and str(hosts[i].get("mode", "attack")) != "scan": return true
	return false   # a secret scan raises no alarm


func _threat_rate(t: int) -> float:   # defenders/s the hostile LIVE wires into t remove
	var r := 0.0
	for i in hosts.size():
		if int(hosts[i].owner) != int(hosts[t].owner) and bool(hosts[i].live) and int(hosts[i].assign) == t and str(hosts[i].get("mode", "attack")) != "scan":
			r += SEND_RATE * float(hosts[i].rate) * (ATTACK_POWER / DEFEND_POWER)
	return r


func _drain(t: int) -> float:   # bots/s the building itself is streaming out right now
	if _bot_target(t) >= 0 and _next_depart.has(t): return SEND_RATE * float(hosts[t].rate)
	return 0.0


# ---- control stages, buildings & the economy ----
func _stage(i: int) -> int:
	var fr: float = float(hosts[i].bots) / NODE_CAP
	if fr >= STAGE_FULL: return 0
	if fr >= STAGE_SHAKY: return 1
	return 2


func _slot_busy(i: int, k: int) -> bool:   # a job is working on this slot; its building is offline meanwhile
	var job: Dictionary = hosts[i].job
	return not job.is_empty() and int(job.slot) == k


func _built(i: int) -> Array:   # [slot, kind] of every standing building in slot order (busy slots excluded)
	var out := []
	var b: Array = hosts[i].builds
	for k in b.size():
		if str(b[k]) != "" and not _slot_busy(i, k): out.append([k, str(b[k])])
	return out


func _active_slots(i: int) -> int:   # a weakened building runs fewer of its slots (the first always works)
	return maxi(1, _built(i).size() - _stage(i))


func _slot_active(i: int, k: int) -> bool:   # is the building in slot k among the ones still working?
	var bl := _built(i); var act := _active_slots(i)
	for idx in bl.size():
		if int(bl[idx][0]) == k: return idx < act
	return false


func _count(i: int, kind: String) -> int:   # ACTIVE buildings of a kind
	var n := 0
	var bl := _built(i)
	for k in mini(_active_slots(i), bl.size()):
		if str(bl[k][1]) == kind: n += 1
	return n


func _count_all(i: int, kind: String) -> int:   # built, active or not
	var n := 0
	for b in hosts[i].builds:
		if str(b) == kind: n += 1
	return n


func _free_slot(i: int) -> int:   # first empty slot not reserved by a running job, or -1
	var b: Array = hosts[i].builds
	for k in b.size():
		if str(b[k]) == "" and not _slot_busy(i, k): return k
	return -1


func _intel_cap(fac: int) -> float:
	var caps := 0
	for i in hosts.size():
		if int(hosts[i].owner) == fac: caps += _count(i, "cap")
	return INTEL_CAP_BASE + CAP_PER_BUILD * float(caps)


func _intel_rate(fac: int) -> float:
	var r := 0.0
	for i in hosts.size():
		if int(hosts[i].owner) == fac: r += float(_count(i, "intel")) * INTEL_PER_BUILD * _tmult(i, "intel")
	return r


func _cash_rate(fac: int) -> float:   # Cash/s a faction's active markets emit (before travel)
	var r := 0.0
	for i in hosts.size():
		if int(hosts[i].owner) == fac: r += float(_count(i, "cash")) * float(hosts[i].value) * _tmult(i, "cash") / CASH_INTERVAL
	return r


# one job per building. Into an EMPTY slot: build (BUILD_TIME). Onto an OCCUPIED slot: replace — the old
# building goes offline at once, the slot is cleared (DEMOLISH_TIME), then the new one is built (BUILD_TIME).
func _start_job(i: int, kind: String, slot := -1) -> bool:
	if i < 0 or int(hosts[i].owner) == NEUTRAL or not BUILD_KINDS.has(kind): return false
	if not (hosts[i].job as Dictionary).is_empty(): return false
	if slot < 0: slot = _free_slot(i)
	if slot < 0 or slot >= (hosts[i].builds as Array).size(): return false
	var cur := str(hosts[i].builds[slot])
	if cur == kind: return false
	if cur == "": hosts[i].job = {"kind": kind, "slot": slot, "phase": "build", "left": BUILD_TIME}
	else: hosts[i].job = {"kind": kind, "slot": slot, "phase": "demolish", "left": DEMOLISH_TIME}
	return true


func _can_drop(i: int, slot: int, kind: String) -> bool:   # a card held over a slot of the building you are in
	if i < 0 or not _mine(i) or _inside != i or _enter_left > 0.0 or not BUILD_KINDS.has(kind): return false
	if not (hosts[i].job as Dictionary).is_empty(): return false
	if slot < 0 or slot >= (hosts[i].builds as Array).size(): return false
	return str(hosts[i].builds[slot]) != kind


func _drop_build(i: int, slot: int, kind: String) -> void:   # a card dropped on a slot
	if not _can_drop(i, slot, kind): return
	var cur := str(hosts[i].builds[slot])
	if _start_job(i, kind, slot):
		if cur == "": _flash("Building %s in slot %d of %s — %.0f s, stay inside" % [BUILD_KINDS[kind].name, slot + 1, str(hosts[i].name), BUILD_TIME])
		else: _flash("Replacing %s with %s in slot %d — %.0f s to clear, then %.0f s to build" % [BUILD_KINDS[cur].name, BUILD_KINDS[kind].name, slot + 1, DEMOLISH_TIME, BUILD_TIME])
	_refresh_panel(); queue_redraw()


func _card_click(kind: String) -> void:   # clicking a card (no drag) builds into the first empty slot
	if _inside < 0: return
	var s := _free_slot(_inside)
	if s < 0:
		_flash("No empty slot — drag the card onto an occupied slot to replace that building")
		return
	_drop_build(_inside, s, kind)


func _player_build(i: int, kind: String) -> void:   # script helper: first empty slot of the building you are in
	_drop_build(i, _free_slot(i), kind)


func _cancel_job(i: int) -> void:
	if i >= 0: hosts[i].job = {}
	_refresh_panel(); queue_redraw()


func _demolish(i: int, slot: int) -> void:   # clear a slot (DEMOLISH_TIME); the building is offline meanwhile
	if i < 0 or slot < 0 or slot >= (hosts[i].builds as Array).size(): return
	if str(hosts[i].builds[slot]) == "" or not (hosts[i].job as Dictionary).is_empty(): return
	hosts[i].job = {"kind": "", "slot": slot, "phase": "demolish", "left": DEMOLISH_TIME}
	_flash("Demolishing %s in slot %d of %s — %.0f s" % [BUILD_KINDS[str(hosts[i].builds[slot])].name, slot + 1, str(hosts[i].name), DEMOLISH_TIME])
	_refresh_panel(); queue_redraw()


# a build job progresses only while its owner is "inside": you must stay in the local view; an AI
# botnet runs one job at a time (its attention) and is always inside it
func _tick_jobs(dt: float) -> void:
	for i in hosts.size():
		var job: Dictionary = hosts[i].job
		if job.is_empty(): continue
		var fac := int(hosts[i].owner)
		var progress: bool = (fac != PLAYER) or (_inside == i and _enter_left <= 0.0)
		if not progress: continue
		job.left = float(job.left) - dt
		if float(job.left) > 0.0: continue
		var slot := int(job.slot)
		if str(job.phase) == "demolish":
			hosts[i].builds[slot] = ""
			if str(job.kind) == "":
				hosts[i].job = {}
				if fac == PLAYER: _flash("Slot %d of %s cleared" % [slot + 1, str(hosts[i].name)]); _refresh_panel()
			else:
				job.phase = "build"; job.left = BUILD_TIME
		else:
			hosts[i].builds[slot] = str(job.kind)
			hosts[i].job = {}
			if fac == PLAYER:
				_flash("Built %s in slot %d of %s" % [BUILD_KINDS[str(job.kind)].name, slot + 1, str(hosts[i].name)])
				_refresh_panel()


func _bank(fac: int, amount: float) -> void:
	cash[fac] = float(cash[fac]) + amount
	if won or lost: return
	if float(cash[fac]) < CASH_GOAL: return
	if fac == PLAYER: won = true; _end_cause = "You banked %d Cash." % int(CASH_GOAL)
	else: lost = true; _end_cause = "%s banked %d Cash first." % [fname(fac), int(CASH_GOAL)]


# ---- who sends what where ----
func _reserve_of(i: int) -> float:   # garrison a source keeps at home
	if int(hosts[i].owner) != PLAYER: return AI_RESERVE
	if int(hosts[i].assign) < 0: return RALLY_RESERVE   # auto-supply keeps a garrison
	return 0.0


# where a building's bots go right now: its wire if LIVE; an UNWIRED idle building of yours auto-supplies
# the rally point (never while under attack); a dormant wire sends nothing
func _bot_target(i: int) -> int:
	var a := int(hosts[i].assign)
	if a >= 0: return a if bool(hosts[i].live) else -1
	if _mine(i) and rally >= 0 and rally != i and _mine(rally) and not _under_attack(i): return rally
	return -1


func _attack_demand(fac: int) -> float:   # Intel/s a faction's LIVE attack flows would spend
	var n := 0.0
	for i in hosts.size():
		var t := int(hosts[i].assign)
		if int(hosts[i].owner) == fac and bool(hosts[i].live) and t >= 0 and int(hosts[t].owner) != fac and not _route(i, t).is_empty():
			n += SEND_RATE * float(hosts[i].rate)
	return n


# why a source isn't delivering right now — drives the cause→action diagnostics
func _src_state(s: int) -> String:
	var fac := int(hosts[s].owner)
	var a := int(hosts[s].assign)
	if a >= 0:
		var rt := _route(s, a)
		if rt.is_empty(): return "no route"
		if int(hosts[a].owner) == fac:                        # guard wire: the STATUS does the work
			if not bool(hosts[s].live): return "guarding (standby)"
			return "defending" if float(hosts[s].bots) - 1.0 >= _reserve_of(s) else "defending · no bots"
		if not bool(hosts[s].live): return "wired (not launched)"
		if float(hosts[s].bots) - 1.0 < _reserve_of(s): return "no bots"
		if float(intel[fac]) < 1.0 and (SCAN_COSTS_INTEL or _scanned(fac, a)): return "no Intel"
		if _first_wait(rt) > MAX_QUEUE: return "link busy"
		return "scanning" if str(hosts[s].get("mode", "attack")) == "scan" else "sending"
	var tgt := _bot_target(s)
	if tgt < 0: return "idle"
	var rt2 := _route(s, tgt)
	if rt2.is_empty(): return "no route"
	if float(hosts[s].bots) - 1.0 < _reserve_of(s): return "garrison"
	if _first_wait(rt2) > MAX_QUEUE: return "link busy"
	return "sending"


# ============================================================ LOOP
func _process(dt: float) -> void:
	if _msg_t > 0.0: _msg_t -= dt
	if not paused and not won and not lost:
		_t += dt                        # the shared clock only advances while playing → pause freezes everything
		for i in hosts.size():
			var nb := _count(i, "bot")
			if nb > 0 and float(hosts[i].bots) < _cap_of(i):
				hosts[i].bots = minf(_cap_of(i), float(hosts[i].bots) + _regen(i) * dt)
		for fac in BOTNETS: intel[fac] = minf(_intel_cap(fac), float(intel[fac]) + _intel_rate(fac) * dt)
		if _inside >= 0 and _enter_left > 0.0: _enter_left = maxf(0.0, _enter_left - dt)
		_tick_jobs(dt)
		_prune_res()
		_auto_guards()      # guard wires arm themselves while their building is threatened, stand down after
		_emit_due()
		if not won and not lost: _deliver_due()      # chronological; may set won/lost and then stops
		if not won and not lost: _ai_tick(dt)
		if not won and not lost and _player_nodes() == 0: lost = true; _end_cause = "You lost your last building."
		for fac in AIS:
			if not bool(_ai[fac].dead) and _faction_nodes(fac) == 0:
				_ai[fac].dead = true; _flash("%s is out of the game" % fname(fac))
		_panel_t += dt
		if _panel_t >= 0.25 and not _pointer_over_panel():
			_panel_t = 0.0; _refresh_panel()
	if (won or lost) and not _end_shown:
		_end_shown = true; _refresh_panel()
	hud.text = _hud_text()
	queue_redraw()


# "Attack and defend is the STATUS": a wire into a building of the SAME faction is a GUARD — it stands by
# dormant and starts flowing AUTOMATICALLY the moment the protected building is under attack (or below
# full, counting help already in the air), then stands down again. Guards are never launched or stopped
# by hand. The same rule serves every botnet.
func _auto_guards() -> void:
	for s in hosts.size():
		var fac := int(hosts[s].owner)
		if fac == NEUTRAL: continue
		var t := int(hosts[s].assign)
		if t < 0 or int(hosts[t].owner) != fac: continue
		var want: bool = _under_attack(t) or (float(hosts[t].bots) + _incoming(t, fac) < NODE_CAP - 0.25)
		if want and not bool(hosts[s].live):
			hosts[s].live = true; _next_depart[s] = _t
		elif not want and bool(hosts[s].live):
			hosts[s].live = false; _next_depart.erase(s)


func _can_emit(i: int) -> bool:
	var tgt := _bot_target(i)
	if tgt < 0 or not _next_depart.has(i): return false
	if float(_next_depart[i]) > _t: return false
	if float(hosts[i].bots) - 1.0 < _reserve_of(i): return false
	var fac := int(hosts[i].owner)
	var hostile: bool = int(hosts[tgt].owner) != fac
	if hostile and str(hosts[i].get("mode", "attack")) == "scan" and _scanned(fac, tgt): return false   # scan done
	if hostile and float(intel[fac]) < 1.0 and (SCAN_COSTS_INTEL or _scanned(fac, tgt)): return false
	if not hostile and int(hosts[i].assign) < 0:   # auto-supply never overfills its rally
		if float(hosts[tgt].bots) + _incoming(tgt, fac) >= NODE_CAP - 0.001: return false
	var rt := _route(i, tgt)
	if rt.is_empty() or _first_wait(rt) > MAX_QUEUE: return false
	return true


func _can_emit_cash(i: int) -> bool:
	if not _next_cash.has(i) or float(_next_cash[i]) > _t: return false
	var fac := int(hosts[i].owner)
	if not rig.has(fac): return false
	var rg := int(rig[fac])
	if int(hosts[rg].owner) != fac: return false   # the sink is gone → Cash holds until it is retaken
	if i == rg: return true
	var rt := _route(i, rg)
	if rt.is_empty() or _first_wait(rt) > MAX_QUEUE: return false
	return true


# Release every DUE departure (bots AND Cash packets) in TIME order with a rotating tie-break, so no
# source wins scarce Intel or link room purely by index. A held source never builds a catch-up backlog.
func _emit_due() -> void:
	var n := hosts.size()
	for i in n:                                     # validate LIVE wires & seed departure clocks
		var a := int(hosts[i].assign)
		if a >= 0 and bool(hosts[i].live) and _route(i, a).is_empty():
			hosts[i].live = false; _next_depart.erase(i)   # flow pauses; the WIRE stays — relaunch when routed
			if _mine(i): _flash("%s's flow stopped — no route (connection kept; launch again when routed)" % str(hosts[i].name))
		var tgt := _bot_target(i)
		if tgt < 0: _next_depart.erase(i)
		elif not _next_depart.has(i): _next_depart[i] = _t
		if int(hosts[i].owner) != NEUTRAL and _count(i, "cash") > 0:
			if not _next_cash.has(i): _next_cash[i] = _t
		else: _next_cash.erase(i)
	var due := []    # only sources whose clock is due are candidates — the loop below re-checks just these
	var cdue := []
	for k in n:
		var i: int = (_emit_cursor + k) % n
		if _next_depart.has(i) and float(_next_depart[i]) <= _t: due.append(i)
		if _next_cash.has(i) and float(_next_cash[i]) <= _t: cdue.append(i)
	var guard := 0
	while guard < 4000 and (not due.is_empty() or not cdue.is_empty()):
		guard += 1
		var best := -1; var best_t := INF; var best_kind := ""
		for i in due:
			if _can_emit(i) and float(_next_depart[i]) < best_t:
				best = i; best_t = float(_next_depart[i]); best_kind = "bot"
		for i in cdue:
			if _can_emit_cash(i) and float(_next_cash[i]) < best_t:
				best = i; best_t = float(_next_cash[i]); best_kind = "cash"
		if best < 0: break
		var fac := int(hosts[best].owner)
		if best_kind == "bot":
			var tgt := _bot_target(best)
			hosts[best].bots = float(hosts[best].bots) - 1.0
			var hostile: bool = int(hosts[tgt].owner) != fac
			var pk := "scan" if (hostile and str(hosts[best].get("mode", "attack")) == "scan" and not _scanned(fac, tgt)) else "bot"
			if hostile and (pk == "bot" or SCAN_COSTS_INTEL): intel[fac] = float(intel[fac]) - 1.0   # spends Intel
			flights.append(_schedule(_route(best, tgt), best_t, fac, pk))
			_next_depart[best] = best_t + 1.0 / (SEND_RATE * float(hosts[best].rate))
			if float(_next_depart[best]) > _t: due.erase(best)
		else:
			var rg := int(rig[fac])
			var amount := float(hosts[best].value) * _tmult(best, "cash")
			if best == rg: _bank(fac, amount)        # the rig banks its own market directly
			else: flights.append(_schedule(_route(best, rg), best_t, fac, "cash", amount))
			_next_cash[best] = best_t + CASH_INTERVAL / float(_count(best, "cash"))
			if float(_next_cash[best]) > _t: cdue.erase(best)
			if won or lost: return
		_emit_cursor = best + 1
	for i in n:                                     # anti-burst: a held emitter doesn't accumulate a backlog
		if _next_depart.has(i) and float(_next_depart[i]) < _t: _next_depart[i] = _t
		if _next_cash.has(i) and float(_next_cash[i]) < _t: _next_cash[i] = _t


func _deliver_due() -> void:
	var due := []
	var rest := []
	for f in flights:
		if float(f.arrive_t) <= _t: due.append(f)
		else: rest.append(f)
	flights = rest
	due.sort_custom(_arrival_cmp)           # resolve by ARRIVAL TIME, independent of list order
	for f in due:
		if won or lost: break               # terminal reached — stop applying later arrivals
		_deliver(f)


# chronological; ties resolved deterministically: arrive time → target → the holder's reinforcements first
func _arrival_cmp(a: Dictionary, b: Dictionary) -> bool:
	if absf(float(a.arrive_t) - float(b.arrive_t)) > 0.0001: return float(a.arrive_t) < float(b.arrive_t)
	var ta := int((a.route as Array)[(a.route as Array).size() - 1])
	var tb := int((b.route as Array)[(b.route as Array).size() - 1])
	if ta != tb: return ta < tb
	var ra := int(a.owner) == int(hosts[ta].owner)
	var rb := int(b.owner) == int(hosts[tb].owner)
	return ra and not rb


# arrival applies: Cash → banked by whoever holds the sink; same faction → reinforce (capped);
# other faction → attrition; reduced to 0 → the building flips to the attacker
func _deliver(f: Dictionary) -> void:
	var rt: Array = f.route
	if rt.is_empty(): return
	var t: int = int(rt[rt.size() - 1])
	var fac := int(f.owner)
	if str(f.kind) == "cash":
		if int(hosts[t].owner) != NEUTRAL: _bank(int(hosts[t].owner), float(f.get("amount", 1.0)))
		return
	if str(f.kind) == "scan":   # consumed on arrival; reveals, never wounds
		if int(hosts[t].owner) != fac: _scan_land(fac, t)
		return
	if int(hosts[t].owner) == fac:
		hosts[t].bots = minf(NODE_CAP, float(hosts[t].bots) + 1.0)
		return
	if not _scanned(fac, t): _scan_land(fac, t)   # any attack scans as it goes — loudly
	hosts[t].bots = float(hosts[t].bots) - (ATTACK_POWER / DEFEND_POWER)
	if float(hosts[t].bots) <= 0.0: _capture(t, fac)


# ownership changes: attack flows into a building the attacker CAPTURES become guards that top it up and
# stand down; wires of the LOSER into it stand down (kept, dormant) — retaking it is an explicit call
func _capture(t: int, fac: int) -> void:
	var prev := int(hosts[t].owner)
	var nm := str(hosts[t].name)
	hosts[t].owner = fac
	hosts[t].bots = minf(NODE_CAP, -float(hosts[t].bots))
	hosts[t].assign = -1; hosts[t].live = false; hosts[t].job = {}; hosts[t].rate = 1.0
	_next_depart.erase(t); _next_cash.erase(t)
	if fac != PLAYER:
		if sel.has(t): sel.erase(t)          # a selected building lost to a rival is uncontrollable
		if rally == t: rally = -1
		if _inside == t:
			_inside = -1; _enter_left = 0.0
			_flash("Connection lost — %s fell while you were inside it" % nm)
	var stood := 0                           # the loser's wires into it stand down, kept
	if prev != NEUTRAL:
		for i in hosts.size():
			if int(hosts[i].owner) == prev and int(hosts[i].assign) == t and bool(hosts[i].live):
				hosts[i].live = false; _next_depart.erase(i); stood += 1
	if fac == PLAYER:
		var flowing := 0
		for i in hosts.size():
			if _mine(i) and int(hosts[i].assign) == t and bool(hosts[i].live): flowing += 1
		var from := "" if prev == NEUTRAL else " from %s" % fname(prev)
		if flowing > 0: _flash("Captured %s%s — %d flow(s) now top it up as guards" % [nm, from, flowing])
		else: _flash("Captured %s%s" % [nm, from])
	elif prev == PLAYER:
		if stood > 0: _flash("Lost %s to %s — %d connection(s) stand down (press ATTACK there to retake)" % [nm, fname(fac), stood])
		else: _flash("Lost %s to %s" % [nm, fname(fac)])
	else:
		_flash("%s took %s%s" % [fname(fac), nm, ("" if prev == NEUTRAL else " from %s" % fname(prev))])
	_refresh_panel()


# ============================================================ AI BOTNETS
# Every AI plays by the player's rules: one build job at a time, 1 Intel per attack bot, routes Cash home.
# Each think: housekeeping → defence (guards + counter-attack) → build → offence (cost-aware target) → supply.
func _ai_tick(dt: float) -> void:
	if not ai_enabled: return
	for fac in AIS:
		var st: Dictionary = _ai[fac]
		st.timer = float(st.timer) - dt
		if float(st.timer) > 0.0: continue
		st.timer = float(AI_PROFILE[fac].cadence)
		_ai_think(fac)


func _ai_mine(fac: int) -> Array:
	var out := []
	for e in hosts.size():
		if int(hosts[e].owner) == fac: out.append(e)
	return out


func _ai_frontier(e: int) -> bool:   # borders a building of another faction (incl. neutral)
	for p in hosts[e].links:
		if int(hosts[p].owner) != int(hosts[e].owner): return true
	return false


func _ai_borders_botnet(e: int) -> bool:   # borders another BOTNET (a live threat)
	for p in hosts[e].links:
		var o := int(hosts[p].owner)
		if o != NEUTRAL and o != int(hosts[e].owner): return true
	return false


func _ai_release(e: int) -> void:
	hosts[e].assign = -1; hosts[e].live = false; _next_depart.erase(e)


func _ai_think(fac: int) -> void:
	var st: Dictionary = _ai[fac]
	var mine := _ai_mine(fac)
	if mine.is_empty(): return
	var aggr := float(AI_PROFILE[fac].aggr)
	# ── 0. housekeeping: finished / unreachable wires, stalled attacks (progress-based patience) ──
	for e in mine:
		var a := int(hosts[e].assign)
		if a < 0: continue
		if int(hosts[a].owner) == fac:
			if float(hosts[a].bots) >= NODE_CAP - 0.5 and not _under_attack(a) and not _ai_frontier(a): _ai_release(e)
		elif _route(e, a).is_empty(): _ai_release(e)
	var ops := {}   # attack target -> [sources]
	for e in mine:
		var a := int(hosts[e].assign)
		if a >= 0 and bool(hosts[e].live) and int(hosts[a].owner) != fac:
			if not ops.has(a): ops[a] = []
			ops[a].append(e)
	var recs: Dictionary = st.ops
	for t in recs.keys():
		if not ops.has(t): recs.erase(t)
	for t in ops.keys():
		if not recs.has(t): recs[t] = {"since": _t, "bots": float(hosts[t].bots)}
		elif float(hosts[t].bots) < float(recs[t].bots) - 0.5: recs[t].bots = float(hosts[t].bots); recs[t].since = _t
		elif _t - float(recs[t].since) > AI_PATIENCE:
			for e in ops[t]: _ai_release(e)
			st.avoid = t; recs.erase(t); ops.erase(t)
	# ── 1. defence: guard a threatened building, counter-attack a soft attacker ──
	for t in mine:
		if not _under_attack(t): continue
		var threat := _threat_rate(t)
		var regen := _regen(t) - _drain(t)
		var help := 0.0
		for e in mine:
			if int(hosts[e].assign) == t and bool(hosts[e].live): help += SEND_RATE * float(hosts[e].rate)
		var deficit := threat - regen - help + 0.3
		if deficit > 0.0:
			var needed := mini(3, int(ceil(deficit / SEND_RATE)))
			var helpers := []
			for e in mine:
				if e == t or int(hosts[e].assign) >= 0 or _under_attack(e) or float(hosts[e].bots) < AI_RESERVE + 4.0: continue
				var rt := _route(e, t)
				if not rt.is_empty(): helpers.append([rt.size(), e])
			helpers.sort_custom(func(a, b): return a[0] < b[0])
			for h in helpers.slice(0, mini(needed, helpers.size())):
				hosts[int(h[1])].assign = t; hosts[int(h[1])].live = true; _next_depart[int(h[1])] = _t
		# counter-attack: an attacker that is streaming at us is net-zero on its own — two streams take it
		for i in hosts.size():
			if int(hosts[i].owner) == fac or int(hosts[i].owner) == NEUTRAL or not bool(hosts[i].live) or int(hosts[i].assign) != t: continue
			if ops.has(i) or float(intel[fac]) < 20.0 or float(hosts[i].bots) > 14.0: continue
			var free := []
			for e in mine:
				if int(hosts[e].assign) >= 0 or _under_attack(e) or float(hosts[e].bots) < AI_RESERVE + 4.0: continue
				var rt := _route(e, i)
				if not rt.is_empty(): free.append([rt.size(), e])
			if free.size() < 2: continue
			free.sort_custom(func(a, b): return a[0] < b[0])
			for h in free.slice(0, 2):
				hosts[int(h[1])].assign = i; hosts[int(h[1])].live = true; hosts[int(h[1])].mode = "attack"; _next_depart[int(h[1])] = _t
			ops[i] = [int(free[0][1]), int(free[1][1])]
			recs[i] = {"since": _t, "bots": float(hosts[i].bots)}
			if _mine(i): _flash("⚔ %s counter-attacks %s" % [fname(fac), str(hosts[i].name)])
	# ── 2. build: one job at a time (its attention), chosen by need ──
	var busy := false
	for e in mine:
		if not (hosts[e].job as Dictionary).is_empty(): busy = true
	if not busy:
		var free_slot := []
		for e in mine:
			if _free_slot(e) >= 0: free_slot.append(e)
		if not free_slot.is_empty():
			var site := -1; var kind := ""
			var want_intel: bool = _intel_rate(fac) < 1.0 + float(ops.size()) or float(intel[fac]) < 15.0
			if want_intel:   # harvester in the safest building (rear first, then fewest hostile neighbours)
				kind = "intel"; var best := INF
				for e in free_slot:
					var sc := (0.0 if not _ai_frontier(e) else 5.0) + (5.0 if _ai_borders_botnet(e) else 0.0) - 4.0 * (_tmult(e, "intel") - 1.0)
					if sc < best: best = sc; site = e
			if site < 0:   # a frontier building facing a botnet with a single farm gets a second
				for e in free_slot:
					if _ai_borders_botnet(e) and _count_all(e, "bot") < 2: site = e; kind = "bot"; break
			if site < 0:   # otherwise the richest building gets a market
				var bestv := -1.0
				for e in free_slot:
					var v := float(hosts[e].value) * 2.0 * _tmult(e, "cash") + float(int(hosts[e].slots) - _built_kinds(e).size()) * 0.3 - (1.0 if _ai_borders_botnet(e) else 0.0)
					if v > bestv: bestv = v; site = e; kind = "cash"
			if site >= 0: _start_job(site, kind)
	# ── 3. offence: a cost-aware target, enough streams to beat its regeneration, affordable in Intel ──
	var max_ops := 1 + (1 if aggr > 0.6 and mine.size() >= 5 else 0)
	if ops.size() < max_ops and float(intel[fac]) >= 12.0:
		var cands := []
		for e in mine:
			for p in hosts[e].links:
				if int(hosts[p].owner) != fac and not cands.has(p) and not ops.has(p): cands.append(p)
		if cands.size() > 1 and cands.has(int(st.avoid)): cands.erase(int(st.avoid))
		var free := []
		for e in mine:
			if int(hosts[e].assign) >= 0 and bool(hosts[e].live): continue
			if _under_attack(e) or float(hosts[e].bots) < AI_RESERVE + 4.0: continue
			free.append(e)
		var pick := -1; var pick_srcs := []; var best := 0.0
		for c in cands:
			var srcs := []
			for e in free:
				var rt := _route(e, c)
				if not rt.is_empty(): srcs.append([rt.size(), e])
			if srcs.size() < 2: continue
			srcs.sort_custom(func(a, b): return a[0] < b[0])
			var regen_net := _regen(c) - _drain(c)
			var need := clampi(int(ceil((maxf(regen_net, 0.0) + 0.5) / (SEND_RATE * ATTACK_POWER / DEFEND_POWER))), 2, AI_MAX_STREAMS)
			var n := mini(need, srcs.size())
			var dmg := float(n) * SEND_RATE * (ATTACK_POWER / DEFEND_POWER)
			var net := dmg - regen_net
			if net <= 0.1: continue
			var secs := float(hosts[c].bots) / net + float(srcs[0][0])
			var cost := secs * float(n)
			if cost > float(intel[fac]) + _intel_rate(fac) * secs: continue
			var o := int(hosts[c].owner)
			var benefit := float(hosts[c].value) * 3.0 + float(hosts[c].slots) + float(_built_kinds(c).size()) + 2.0 * (_tmult(c, "intel") + _tmult(c, "cash") + _tmult(c, "bot") - 3.0)
			if o != NEUTRAL: benefit += 4.0 + 6.0 * aggr          # taking a rival's building also hurts its income
			if o == PLAYER: benefit += 2.0 * aggr
			var others := 0
			for i in hosts.size():
				if int(hosts[i].owner) != fac and int(hosts[i].owner) != o and bool(hosts[i].live) and int(hosts[i].assign) == c: others += 1
			if others > 0: benefit += 3.0                         # someone else is softening it — pile on
			for p in hosts[c].links:
				if int(hosts[p].owner) == fac and bool(hosts[p].rig): benefit += 3.0   # it sits on our doorstep
			var score := benefit / (secs + 8.0)
			if score > best: best = score; pick = c; pick_srcs = srcs.slice(0, n)
		if pick >= 0:
			var quiet: bool = not _scanned(fac, pick)   # unknown building: scan it quietly first
			for s in pick_srcs:
				hosts[int(s[1])].assign = pick; hosts[int(s[1])].live = true; hosts[int(s[1])].mode = "scan" if quiet else "attack"; _next_depart[int(s[1])] = _t
			recs[pick] = {"since": _t, "bots": float(hosts[pick].bots)}
			if _mine(pick) and not quiet: _flash("⚔ %s is attacking %s with %d source(s) — defend it!" % [fname(fac), str(hosts[pick].name), pick_srcs.size()])
	# ── 4. supply: full rear buildings wire dormant guards to the weakest frontier building ──
	for e in mine:
		if int(hosts[e].assign) >= 0 or _ai_frontier(e) or float(hosts[e].bots) < NODE_CAP - 2.0: continue
		var worst := -1; var wb := INF
		for f in mine:
			if f == e or not _ai_frontier(f) or float(hosts[f].bots) >= wb: continue
			if _route(e, f).is_empty(): continue
			worst = f; wb = float(hosts[f].bots)
		if worst >= 0: hosts[e].assign = worst; hosts[e].live = false; _next_depart.erase(e)


# ============================================================ INPUT
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: paused = not paused; _refresh_panel(); queue_redraw()
		elif event.keycode == KEY_ESCAPE:
			if _inside >= 0: _leave()
			else: _clear_all()
			_refresh_panel(); queue_redraw()


func _pointer_over_panel() -> bool:
	return panel != null and panel.get_global_rect().has_point(get_viewport().get_mouse_position())


func _clear_all() -> void:   # clears SELECTION state only — never touches wired connections
	sel = {}; _inspect = -1; _drag_from = -1; _dragging = false; _boxing = false


func _enter(i: int) -> void:   # go MICRO: the local view opens after ENTER_TIME; the map keeps running
	if not _mine(i): return
	_inside = i; _enter_left = ENTER_TIME; _drag_from = -1; _dragging = false
	_flash("Connecting into %s… the map keeps running while you are inside" % str(hosts[i].name))
	_refresh_panel(); queue_redraw()


func _leave() -> void:
	_inside = -1; _enter_left = 0.0
	_refresh_panel(); queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if won or lost: return                 # no map commands after a terminal result (use Restart)
	if _inside >= 0:                       # inside a building: the map is visible but not commandable
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_leave()
		return
	if event is InputEventMouseMotion:
		if _drag_from >= 0 and event.position.distance_to(_press_pos) > 8.0: _dragging = true
		if _boxing or _dragging or not sel.is_empty(): queue_redraw()
		return
	if not (event is InputEventMouseButton): return
	var hit := _host_at(event.position)
	var shift: bool = event.shift_pressed
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			_box_start = event.position
			_boxing = hit < 0              # a marquee starts only on EMPTY map
			_drag_from = hit if _mine(hit) else -1   # drag a line only FROM your building
			_dragging = false
			return
		var moved: bool = event.position.distance_to(_press_pos) > 8.0
		if _boxing and moved:
			_marquee(Rect2(_box_start, event.position - _box_start).abs(), shift)
		elif _drag_from >= 0 and moved and hit >= 0 and hit != _drag_from:
			_drag_wire(_drag_from, hit)    # dragged a line onto a building → WIRE a dormant connection
		elif not moved:
			_left_click(hit, shift)
		_boxing = false; _drag_from = -1; _dragging = false
		_refresh_panel(); queue_redraw()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_clear_all()                       # right-click = clear selection / panel — never wires
		_refresh_panel(); queue_redraw()


# CLICK never wires — links are made ONLY by drag-and-drop (the user was explicit about this).
# Click = look at / select: your building → select it + its panel; any other → just open its panel.
# Shift-click builds a group; drag from any group member then wires the whole group.
func _left_click(hit: int, shift: bool) -> void:
	if hit < 0:
		_clear_all()
		return
	if shift and _mine(hit):
		if sel.has(hit): sel.erase(hit)
		else: sel[hit] = true
		_inspect = -1
		return
	if _mine(hit):
		sel = {hit: true}; _inspect = hit    # your building: select it (ready to drag) + show its panel
	else:
		sel = {}; _inspect = hit             # other building: open its panel (the launch pad)


# dragging a line from your building onto another WIRES it (dormant connection) — it never fires.
# Dragging from a building already in the selection wires the whole group; from an unselected one, just it.
func _drag_wire(src: int, dest: int) -> void:
	if not sel.has(src): sel = {src: true}
	_wire(dest)


func _marquee(r: Rect2, shift: bool) -> void:
	if not shift: sel = {}
	for i in hosts.size():
		if _mine(i) and r.has_point(hosts[i].pos): sel[i] = true
	_inspect = -1


func _host_at(p: Vector2) -> int:
	for i in hosts.size():
		if (hosts[i].pos as Vector2).distance_to(p) <= _r(i) + 5.0: return i
	return -1


# CONNECT (drag-and-drop only): wire every selected building of yours to `dest` — dashed and DORMANT,
# nothing fires, no Intel spent. A link can only be made where a PATH exists through your own buildings.
# One connection per building: wiring replaces the old one (a rewired one is dormant again); wiring a
# building's current target changes nothing (it never interrupts a live flow).
func _wire(dest: int) -> void:
	if dest < 0 or sel.is_empty(): return
	var done := 0; var nopath := 0
	for s in sel.keys():
		var i := int(s)
		if not _mine(i) or i == dest: continue
		if _route(i, dest).is_empty(): nopath += 1; continue
		if int(hosts[i].assign) != dest:
			hosts[i].assign = dest; hosts[i].live = false; hosts[i].mode = "attack"; _next_depart.erase(i)
		done += 1
	if done > 0:
		var extra := ("  ·  %d had no path" % nopath) if nopath > 0 else ""
		if _mine(dest):
			_flash("Connected %d guard(s) → %s%s  (auto-defend when it's attacked or damaged)" % [done, str(hosts[dest].name), extra])
		else:
			_flash("Connected %d building(s) → %s%s  (dormant — press ATTACK on %s to launch)" % [done, str(hosts[dest].name), extra, str(hosts[dest].name)])
		sel = {}; _inspect = dest            # wired: move to the target's panel
	elif nopath > 0:
		_flash("✖ No path to %s — links can only run through your own buildings" % str(hosts[dest].name))
	_refresh_panel(); queue_redraw()


# LAUNCH: the button on the TARGET's panel — turns every dormant connection into `t` live, together.
# Connections wired after this stay dormant until the button is pressed again. Unrouted wires stay dormant.
func _launch(t: int, mode := "attack") -> void:   # "scan" = quiet reveal; "attack" = alarms, wounds, reveals as it lands
	if mode == "scan" and _scanned(PLAYER, t): mode = "attack"
	var started := 0; var unrouted := 0
	for i in hosts.size():
		if not _mine(i) or int(hosts[i].assign) != t or bool(hosts[i].live): continue
		if _route(i, t).is_empty(): unrouted += 1; continue
		hosts[i].live = true; hosts[i].mode = mode; _next_depart[i] = _t; started += 1
	var verb := "🔍 Scanning quietly" if mode == "scan" else ("⚔ Attacking blind (alarm raised)" if not _scanned(PLAYER, t) else "⚔ Attacking")
	if started > 0: _flash("%s %s — %d flow(s) launched%s" % [verb, str(hosts[t].name), started, ("  ·  %d held (no route)" % unrouted) if unrouted > 0 else ""])
	elif unrouted > 0: _flash("Cannot launch on %s — no routes (capture a bordering building first)" % str(hosts[t].name))
	else: _flash("Nothing to launch — no dormant connections into %s" % str(hosts[t].name))
	_refresh_panel(); queue_redraw()


# STOP: pause every live attack flow into `t` — the wires stay, ready to launch again
func _halt(t: int) -> void:
	var n := 0
	for i in hosts.size():
		if _mine(i) and int(hosts[i].assign) == t and bool(hosts[i].live):
			hosts[i].live = false; _next_depart.erase(i); n += 1
	if n > 0: _flash("Stopped %d flow(s) into %s (connections kept)" % [n, str(hosts[t].name)])
	else: _flash("No live flows into %s" % str(hosts[t].name))
	_refresh_panel(); queue_redraw()


# DISCONNECT the selected buildings entirely (wire removed; travelling bots still finish)
func _disconnect_selected() -> void:
	var n := 0
	for s in sel.keys():
		if _mine(int(s)) and int(hosts[int(s)].assign) >= 0:
			hosts[int(s)].assign = -1; hosts[int(s)].live = false; _next_depart.erase(int(s)); n += 1
	if n > 0: _flash("Disconnected %d building(s)" % n)
	else: _flash("Nothing to disconnect")
	_refresh_panel()


func _adjust_rate(d: float) -> void:   # the output-limit dial, 25% steps, for every selected source
	var last := 1.0
	for s in sel.keys():
		if _mine(int(s)):
			hosts[int(s)].rate = clampf(float(hosts[int(s)].rate) + d, 0.25, 1.0)
			last = float(hosts[int(s)].rate)
	_flash("Send rate: %d%% of %.0f bot/s" % [int(round(last * 100.0)), SEND_RATE])
	_refresh_panel(); queue_redraw()


func _set_rally(i: int) -> void:
	rally = i
	if i >= 0: _flash("Rally point: %s — unwired idle buildings of yours send surplus above %d bots there" % [str(hosts[i].name), int(RALLY_RESERVE)])
	else: _flash("Rally point cleared")
	_refresh_panel(); queue_redraw()


func _select_contributors(feeders: Array) -> void:
	sel = {}
	for i in feeders: sel[int(i)] = true
	_inspect = -1; _refresh_panel(); queue_redraw()


func _owned_feeders(node: int) -> Array:   # your buildings wired into `node`
	var out := []
	for i in hosts.size():
		if _mine(i) and int(hosts[i].assign) == node: out.append(i)
	return out


# A CONNECTION persists until you disconnect it (stopping a flow with _halt keeps the wire). Player
# commands only ever touch your own buildings — other botnets' wires and flows are never affected.
func _cancel_to(dest: int) -> void:
	var n := 0
	for i in _owned_feeders(dest):
		hosts[int(i)].assign = -1; hosts[int(i)].live = false; _next_depart.erase(int(i)); n += 1
	if n > 0: _flash("Disconnected %d building(s) from %s" % [n, str(hosts[dest].name)])
	else: _flash("Nothing of yours is connected to %s" % str(hosts[dest].name))
	_refresh_panel(); queue_redraw()


func _reset() -> void:   # a NEW town every restart
	won = false; lost = false; _end_shown = false; _end_cause = ""; paused = false; _t = 0.0
	_emit_cursor = 0; _panel_t = 0.0
	rally = -1; _inside = -1; _enter_left = 0.0; town_seed = 0
	_clear_all()
	_gen(); _refresh_panel()


func _build_names(builds: Array) -> String:
	var out := []
	for b in builds:
		if str(b) != "": out.append(BUILD_KINDS[str(b)].name if BUILD_KINDS.has(str(b)) else str(b))
	return ", ".join(out) if not out.is_empty() else "none"


func _flash(m: String) -> void: _msg = m; _msg_t = 4.0


# ============================================================ UI PANEL
func _plabel(txt: String, sz := 15, col := Color(0.85, 0.9, 1.0)) -> void:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(PANEL_W - 52.0, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_child(l)


func _btn(txt: String, cb: Callable, enabled := true) -> void:
	var b := Button.new(); b.text = txt; b.focus_mode = Control.FOCUS_ALL
	b.disabled = not enabled; b.custom_minimum_size = Vector2(0, 30)
	b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb); panel_box.add_child(b)


func _btn_row(items: Array) -> void:   # [[text, callable, enabled], ...] side by side
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		var b := Button.new(); b.text = str(it[0]); b.focus_mode = Control.FOCUS_ALL
		b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.disabled = not bool(it[2]) if it.size() > 2 else false
		b.custom_minimum_size = Vector2(0, 30); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[1]); row.add_child(b)
	panel_box.add_child(row)


func _names(arr: Array) -> String:
	var out := []
	for i in arr: out.append(str(hosts[int(i)].name))
	return ", ".join(out)


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


func _esc_btn() -> void: _clear_all(); _refresh_panel(); queue_redraw()


# Panel is organised around the two verbs: CONNECT (selection panel) and LAUNCH (a building's own panel
# carries its ⚔ ATTACK button). States: RESULT · INSIDE (micro) · SELECTING · NODE (launch pad) · IDLE.
func _refresh_panel() -> void:
	if is_inside_tree() and get_viewport() != null and get_viewport().gui_is_dragging(): return   # a card is in the air
	for c in panel_box.get_children(): c.queue_free()
	if won or lost: _panel_result(); return
	if _inside >= 0: _panel_inside()
	elif not sel.is_empty(): _panel_selecting()
	elif _inspect >= 0: _panel_inspect()
	else: _panel_idle()
	if paused: _plabel("— PAUSED (Space) —", 15, Color(1, 0.9, 0.4))
	_btn("↻ Restart in a new town", _reset)   # always available, any time


func _panel_result() -> void:
	if won: _plabel("✔ VICTORY", 20, Color(0.5, 1, 1))
	else: _plabel("✖ DEFEATED", 20, Color(1, 0.5, 0.5))
	if _end_cause != "": _plabel(_end_cause, 14, Color(0.9, 0.95, 1.0))
	_plabel("Elapsed %s  ·  buildings %d/%d  ·  Cash you %d · NYX %d · KRAKEN %d  ·  town #%d" % [_fmt_time(_t), _player_nodes(), hosts.size(), int(cash[PLAYER]), int(cash[RIVAL]), int(cash[RIVAL2]), town_seed], 14, Color(0.8, 0.9, 1.0))
	_btn("↻ Restart in a new town", _reset)


func _type_line(i: int) -> String:   # "Database · 4 slots · Intel ×2"
	var tp: Dictionary = NODE_TYPES[str(hosts[i].get("type", "pc"))]
	var mults := ""
	for what in ["bot", "intel", "cash"]:
		if float(tp[what]) != 1.0: mults += " · %s ×%.1f" % [{"bot": "bots", "intel": "Intel", "cash": "Cash"}[what], float(tp[what])]
	return "%s · %d slots%s" % [str(tp.name), int(tp.slots), mults]


func _stage_line(i: int) -> String:
	var h: Dictionary = hosts[i]
	if not _mine(i) and not _scanned(PLAYER, i):
		return "unscanned · bots ? · slots ? · value ×%d · %s" % [int(h.value), str(NODE_TYPES[str(h.get("type", "pc"))].name)]
	if int(h.owner) == NEUTRAL:
		return "security %d/%d · value ×%d · %s" % [int(h.bots), int(h.sec), int(h.value), _type_line(i)]
	return "%s · %d/%d bots · %d of %d slots working · value ×%d · %s" % [STAGE_NAME[_stage(i)], int(h.bots), int(NODE_CAP), mini(_active_slots(i), _built(i).size()), int(h.slots), int(h.value), _type_line(i)]


func _panel_inside() -> void:   # MICRO — the local view of one building of yours: slots and building cards
	var i := _inside
	var h: Dictionary = hosts[i]
	_plabel("INSIDE  %s" % str(h.name), 18, Color(1, 0.9, 0.5))
	var badge := TypeBadge.new(); badge.game = self; badge.host = i
	panel_box.add_child(badge)
	_plabel("⚠ The map keeps running. You can't command it from in here.", 12, Color(1, 0.82, 0.4))
	if _enter_left > 0.0:
		_plabel("Connecting… %.1f s" % _enter_left, 15, Color(0.8, 0.9, 1.0))
		_btn("← Leave (Esc)", _leave)
		return
	_plabel(_stage_line(i), 13, Color(0.82, 0.9, 1.0))
	var hin := int(_hostile_incoming(i))
	if hin > 0: _plabel("⚠ Under attack — %d hostile bots inbound." % hin, 13, Color(1, 0.6, 0.5))
	var row := HBoxContainer.new()   # the SLOTS: drop a card on one to build there; on an occupied one to replace
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sw := minf(76.0, (PANEL_W - 60.0 - 8.0 * float(int(h.slots) - 1)) / float(int(h.slots)))
	for sl in int(h.slots):
		var sb := SlotBox.new(); sb.game = self; sb.host = i; sb.slot = sl
		sb.custom_minimum_size = Vector2(sw, 90)
		row.add_child(sb)
	panel_box.add_child(row)
	var job: Dictionary = h.job
	if not job.is_empty():
		var kn: String = str(BUILD_KINDS[str(job.kind)].name) if str(job.kind) != "" else ""
		if str(job.phase) == "demolish" and kn == "": _plabel("Clearing slot %d… %.1f s (only while you stay inside)" % [int(job.slot) + 1, float(job.left)], 12, Color(1, 0.8, 0.5))
		elif str(job.phase) == "demolish": _plabel("Replacing slot %d with %s: clearing… %.1f s, then %.0f s to build (only while you stay inside)" % [int(job.slot) + 1, kn, float(job.left), BUILD_TIME], 12, Color(1, 0.8, 0.5))
		else: _plabel("Building %s in slot %d… %.1f s (only while you stay inside)" % [kn, int(job.slot) + 1, float(job.left)], 12, Color(1, 0.9, 0.5))
		_btn("✖ Cancel job", _cancel_job.bind(i))
	else:
		_plabel("Drag a card onto a slot: empty = build (%.0f s) · occupied = replace (%.0f s to clear + %.0f s). Click a card = first empty slot." % [BUILD_TIME, DEMOLISH_TIME, BUILD_TIME], 11, Color(0.7, 0.8, 0.9))
	var cards := HBoxContainer.new()   # the CARDS: one per building kind, draggable
	cards.add_theme_constant_override("separation", 6)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in BUILD_KINDS.keys():
		var c := BuildCard.new(); c.game = self; c.kind = str(k)
		cards.add_child(c)
	panel_box.add_child(cards)
	for k in BUILD_KINDS.keys():
		_plabel("%s — %s" % [BUILD_KINDS[k].name, BUILD_KINDS[k].desc], 10, Color(0.65, 0.75, 0.88))
	if job.is_empty():
		for sl in int(h.slots):
			if str(h.builds[sl]) != "": _btn("✖ Demolish slot %d: %s (%.0f s)" % [sl + 1, BUILD_KINDS[str(h.builds[sl])].name, DEMOLISH_TIME], _demolish.bind(i, sl))
	_btn("← Leave building (Esc)", _leave)


func _panel_selecting() -> void:   # CONNECT step: what you hold, where it is wired, what a drag would do
	var stock := 0.0; var wired := 0
	for s in sel.keys():
		stock += float(hosts[int(s)].bots)
		if int(hosts[int(s)].assign) >= 0: wired += 1
	if sel.size() == 1:
		var s0: int = int(sel.keys()[0])
		_plabel("SELECTED: %s" % str(hosts[s0].name), 17)
		_plabel(_stage_line(s0) + " · rate %d%%" % int(round(float(hosts[s0].rate) * 100.0)), 12, Color(0.82, 0.9, 1.0))
		_plabel("Inside: %s" % _build_names(hosts[s0].builds), 12, Color(0.75, 0.9, 0.8))
		var a := int(hosts[s0].assign)
		if a >= 0:
			var kind := "defend" if _mine(a) else "attack"
			_plabel("Connection: %s → %s  ·  %s" % [kind, str(hosts[a].name), _src_state(s0)], 14,
				Color(0.6, 1, 0.8) if bool(hosts[s0].live) else Color(0.95, 0.9, 0.6))
		elif _bot_target(s0) >= 0: _plabel("Connection: none · auto-supplying rally %s  (%s)" % [str(hosts[rally].name), _src_state(s0)], 14, Color(0.6, 0.9, 0.8))
		else: _plabel("Connection: none", 14, Color(0.7, 0.8, 0.9))
	else:
		_plabel("SELECTED: %d buildings · %d bots" % [sel.size(), int(stock)], 17)
		if wired > 0: _plabel("%d of them already have a connection (wiring replaces it)." % wired, 13, Color(0.7, 0.85, 1.0))
	_plabel("▶ CONNECT: DRAG a line from a selected building onto the target (only where a path runs through your buildings). Nothing fires — launch from the target's panel.", 14, Color(1, 0.9, 0.5))
	if wired > 0: _btn("✖ Disconnect (%d)" % wired, _disconnect_selected)
	_btn_row([["− rate 25%", _adjust_rate.bind(-0.25)], ["+ rate 25%", _adjust_rate.bind(0.25)]])
	if sel.size() == 1:
		var s1: int = int(sel.keys()[0])
		_btn("🏢 Enter building (%.0f s) — build inside" % ENTER_TIME, _enter.bind(s1))
		if rally == s1: _btn("⚑ Clear rally point", _set_rally.bind(-1))
		else: _btn("⚑ Set rally point here (unwired idle buildings auto-supply it)", _set_rally.bind(s1))
		_panel_node_in(s1)   # this building as a TARGET: guards wired into it
	_btn("Clear selection (Esc)", _esc_btn)


# what launching every connection into `t` would do, before the button is pressed
func _assault_preview(t: int, conns: Array) -> void:
	var dmg := 0.0; var n := 0
	for i in conns:
		if not _route(int(i), t).is_empty(): dmg += SEND_RATE * float(hosts[int(i)].rate) * (ATTACK_POWER / DEFEND_POWER); n += 1
	if n == 0: return
	var regen := _regen(t) - _drain(t)
	var net := dmg - regen
	if net <= 0.001:
		_plabel("If all %d flow: −%.1f/s vs +%.1f/s regeneration — not enough; wire more or raise rates." % [n, dmg, regen], 12, Color(1, 0.85, 0.5))
	else:
		var secs := float(hosts[t].bots) / net
		_plabel("If all %d flow: −%.1f/s vs +%.1f/s → ≈ %d s after arrival, ≈ %d Intel." % [n, dmg, regen, int(ceil(secs)), int(ceil(secs * dmg * DEFEND_POWER / ATTACK_POWER))], 12, Color(0.7, 1, 0.8))


# the LAUNCH PAD: everything about building `t` as a destination — who is wired into it, who is
# flowing, and the ⚔ ATTACK button that is the ONLY thing that starts attack flows
func _panel_node_in(t: int) -> void:
	var efeed := []                      # other botnets' buildings wired into t (red-ringed when focused)
	for i in hosts.size():
		var o := int(hosts[i].owner)
		if o != NEUTRAL and o != PLAYER and int(hosts[i].assign) == t: efeed.append(i)
	if not efeed.is_empty():
		var what := "attacking it" if int(hosts[t].owner) != int(hosts[efeed[0]].owner) else "supplying it"
		_plabel("⚠ %d hostile building(s) %s: %s" % [efeed.size(), what, _names(efeed)], 13, Color(1, 0.6, 0.5))
	var conns := _owned_feeders(t)
	if conns.is_empty():
		if not _mine(t):
			if not _scanned(PLAYER, t): _plabel("🔍 Not scanned — wire your building(s) into it, then SCAN quietly or ATTACK blind. Progress so far: %d bots." % int(_scan_progress(PLAYER, t)), 13, Color(0.8, 0.92, 1.0))
			_plabel("No connections of yours into it yet — select your building(s), then DRAG a line here to connect.", 13, Color(0.7, 0.8, 0.9))
		return
	var livec := 0
	for i in conns:
		if bool(hosts[int(i)].live): livec += 1
	var dormant := conns.size() - livec
	if not _mine(t) and not _scanned(PLAYER, t):   # unknown building: the launch is a SCAN
		_plabel("Connected to %s: %d building(s) — %d scanning · %d dormant" % [str(hosts[t].name), conns.size(), livec, dormant], 14, Color(0.85, 0.95, 0.9))
		_plabel("🔍 Not scanned — its bots and slots are unknown. A quiet SCAN sends bots that are consumed without wounding it and never alert its owner: %d bots plus %d per building inside. Progress: %d landed. Attacking blind also reveals it as bots land — but raises the alarm." % [int(SCAN_BASE), int(SCAN_PER_BUILD), int(_scan_progress(PLAYER, t))], 12, Color(0.8, 0.92, 1.0))
		_plabel("Either costs 1 Intel per bot  (reserve %d · +%d/s)" % [int(intel[PLAYER]), int(_intel_rate(PLAYER))], 12, Color(0.82, 0.9, 1.0))
		if dormant > 0: _btn("🔍  SCAN %s quietly  (launch %d)" % [str(hosts[t].name), dormant], _launch.bind(t, "scan"))
		if dormant > 0: _btn("⚔  ATTACK %s blind  (launch %d · alarms)" % [str(hosts[t].name), dormant], _launch.bind(t, "attack"))
		if livec > 0: _btn("■ Stop %d flow(s) (keep connections)" % livec, _halt.bind(t))
	elif not _mine(t):
		_plabel("Connected to %s: %d building(s) — %d flowing · %d dormant   ✓ scanned" % [str(hosts[t].name), conns.size(), livec, dormant], 14, Color(0.85, 0.95, 0.9))
		_assault_preview(t, conns)
		if livec > 0:
			var sending := []
			for i in conns:
				if _src_state(int(i)) == "sending": sending.append(int(i))
			_panel_attack_diag(t, conns, sending)
		_plabel("Launching costs 1 Intel per bot  (reserve %d · +%d/s · −%.1f/s)" % [int(intel[PLAYER]), int(_intel_rate(PLAYER)), _attack_demand(PLAYER)], 12, Color(0.82, 0.9, 1.0))
		if dormant > 0: _btn("⚔  ATTACK %s  (launch %d)" % [str(hosts[t].name), dormant], _launch.bind(t, "attack"))
		if livec > 0: _btn("■ Stop %d flow(s) (keep connections)" % livec, _halt.bind(t))
	else:
		_plabel("🛡 %d guard(s) connected — %d defending now · %d on standby" % [conns.size(), livec, dormant], 14, Color(0.85, 0.95, 0.9))
		_plabel("Guards flow automatically while %s is under attack or below full, then stand down." % str(hosts[t].name), 12, Color(0.7, 0.85, 0.95))
	_btn("✖ Disconnect all (%d)" % conns.size(), _cancel_to.bind(t))
	_btn("Select connected building(s)", _select_contributors.bind(conns))
	var shown := 0
	for i in conns:
		if shown >= 6: break
		_plabel("   • %s: %s" % [str(hosts[int(i)].name), _src_state(int(i))], 12, Color(0.72, 0.86, 1.0)); shown += 1


func _panel_inspect() -> void:   # a building's own panel (for a foreign one: the launch pad)
	var h: Dictionary = hosts[_inspect]
	var fac := int(h.owner)
	_plabel("%s  ·  %s" % [str(h.name), fname(fac).to_upper()], 17, fcol(fac).lightened(0.35) if fac != NEUTRAL else Color(0.8, 0.88, 1.0))
	_plabel(_stage_line(_inspect), 13, Color(0.82, 0.9, 1.0))
	if _mine(_inspect) or _scanned(PLAYER, _inspect): _plabel("Inside: %s" % _build_names(h.builds), 12, Color(0.75, 0.9, 0.8))
	else: _plabel("Inside: unknown until scanned", 12, Color(0.7, 0.75, 0.85))
	var yin := int(_incoming(_inspect, PLAYER)); var hin := int(_hostile_incoming(_inspect)) if _mine(_inspect) else int(_incoming(_inspect, RIVAL) + _incoming(_inspect, RIVAL2))
	_plabel("In transit toward it: %d yours · %d from other botnets" % [yin, hin], 13, Color(0.7, 0.85, 1.0))
	if _mine(_inspect) and _under_attack(_inspect): _plabel("⚠ Under attack.", 13, Color(1, 0.72, 0.5))
	var aout := int(h.assign)            # whom THIS building is wired to (gold-ringed on the map)
	if aout >= 0:
		var verb := "defending" if int(hosts[aout].owner) == fac else "attacking"
		_plabel("Its own connection → %s  (%s, %s)" % [str(hosts[aout].name), verb, ("flowing" if bool(h.live) else "dormant")],
			13, Color(1, 0.75, 0.6) if verb == "attacking" else Color(0.7, 0.9, 0.8))
	_panel_node_in(_inspect)
	_plabel("Esc clears. Click your building(s) to select, then DRAG to wire.", 12, Color(0.6, 0.7, 0.8))


# cause → action for an attack that isn't finishing. Regeneration counts the target's OWN outgoing
# stream as a drain, so a building that is attacking someone reads as the softer target it really is.
func _panel_attack_diag(t: int, feeders: Array, sending: Array) -> void:
	if sending.is_empty():
		var reason := "idle"
		for i in feeders:
			var st := _src_state(int(i))
			if st != "idle" and st != "sending": reason = st; break
		match reason:
			"wired (not launched)": _plabel("⛔ Not launched — press SCAN or ATTACK to start these flows.", 12, Color(1, 0.82, 0.4))
			"scanning": _plabel("🔍 Scanning — these bots reveal the building, they do not wound it.", 12, Color(0.8, 0.95, 1.0))
			"no Intel": _plabel("⛔ Waiting for Intel — build an Intel harvester or stop another attack.", 12, Color(1, 0.82, 0.4))
			"no bots": _plabel("⛔ Waiting for bots — let the source regenerate or guard it.", 12, Color(1, 0.82, 0.4))
			"no route": _plabel("⛔ No route — capture a building bordering it, then launch again.", 12, Color(1, 0.82, 0.4))
			"link busy": _plabel("⛔ Link at capacity — lower rates, route elsewhere, or wait.", 12, Color(1, 0.82, 0.4))
			_: _plabel("⛔ Supply is paused.", 12, Color(1, 0.82, 0.4))
		return
	var regen := _regen(t)
	var drain := _drain(t)
	var dmg := 0.0
	for s in sending: dmg += SEND_RATE * float(hosts[int(s)].rate) * (ATTACK_POWER / DEFEND_POWER)
	var net := regen - drain
	if drain > 0.0: _plabel("It is streaming bots out itself (−%.1f/s): a softer target while it does." % drain, 12, Color(0.8, 0.95, 1.0))
	if dmg <= net + 0.001: _plabel("↔ Not overcoming regeneration (−%.1f/s vs +%.1f/s) — wire and launch another source." % [dmg, net], 12, Color(1, 0.85, 0.5))
	else: _plabel("✔ Reducing defenders (−%.1f/s net) — bots still need to arrive." % (dmg - net), 12, Color(0.7, 1, 0.8))


func _panel_idle() -> void:
	_plabel("OBJECTIVE: bank %d Cash before NYX or KRAKEN does." % int(CASH_GOAL), 15, Color(0.92, 0.96, 1.0))
	_plabel("Three botnets, one town. Capture buildings, build inside them, and route their Cash home to YOUR RIG. Downtown is rich but well defended; the rim is poor and soft. Lose every building and you are out.", 12, Color(0.85, 0.9, 1.0))
	_plabel("① CONNECT — DRAG a line from your building onto a target (Shift / box-drag selects a group; dragging from the group wires them all). Links need a path through YOUR buildings. Dashed = dormant: nothing fires yet.", 13)
	_plabel("② SCAN or ATTACK — click the target building itself: its panel lists who's connected. An unscanned building shows '?'. 🔍 SCAN quietly reveals its bots and slots without wounding it or alerting anyone (10 bots + 5 per building inside). ⚔ ATTACK starts the flows; on an unscanned building it reveals as bots land but raises the alarm. Wires into YOUR OWN buildings are GUARDS — they defend automatically.", 13, Color(0.8, 0.86, 0.96))
	_plabel("Clicking only selects / opens a building's panel — it never wires. Rewire any time; bots act only when they ARRIVE.", 13, Color(0.8, 0.86, 0.96))
	_plabel("🏢 Enter a building you own to build inside it: Bot farms defend, Intel harvesters fuel attacks, Darknet markets make Cash (× the building's value). Time keeps running in there. The AI botnets build the same way.", 12, Color(0.8, 0.9, 0.85))
	_plabel("⚑ A rally point turns every unwired idle building into a supplier. Links carry %d packets/s each — bots and Cash share them." % LINK_CAP, 12, Color(0.8, 0.9, 0.85))
	_plabel("Right-click or Esc clears selection (never your wires) · Space pauses · town #%d" % town_seed, 12, Color(0.6, 0.7, 0.8))


func _hud_text() -> String:
	var mybots := 0.0
	for h in hosts:
		if int(h.owner) == PLAYER: mybots += float(h.bots)
	var s := "YOU: %d buildings · %d bots · Intel %d/%d (+%d/s · −%.1f/s) · CASH %d/%d (+%.1f/s)    NYX: %d bldg · Cash %d (+%.1f/s)    KRAKEN: %d bldg · Cash %d (+%.1f/s)    %s · town #%d" % [
		_player_nodes(), int(mybots), int(intel[PLAYER]), int(_intel_cap(PLAYER)), int(_intel_rate(PLAYER)), _attack_demand(PLAYER),
		int(cash[PLAYER]), int(CASH_GOAL), _cash_rate(PLAYER),
		_faction_nodes(RIVAL), int(cash[RIVAL]), _cash_rate(RIVAL),
		_faction_nodes(RIVAL2), int(cash[RIVAL2]), _cash_rate(RIVAL2), _fmt_time(_t), town_seed]
	if rally >= 0: s += "   ·   ⚑ rally: %s" % str(hosts[rally].name)
	if _inside >= 0: s += "   ·   INSIDE %s (map running)" % str(hosts[_inside].name)
	return s


# ============================================================ DRAW
# the building whose plan is in focus: the one under a dragged line, else the one whose panel is open
func _aim_target() -> int:
	if _dragging and _drag_from >= 0:
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and hov != _drag_from: return hov
	return _inspect


# the sources whose routes light up for the focused building: everything WIRED into it, plus the drag group
func _aim_sources() -> Array:
	var out := {}
	var aim := _aim_target()
	if aim >= 0:
		for i in _owned_feeders(aim): out[int(i)] = true
	if _dragging and _drag_from >= 0:
		if sel.has(_drag_from):
			for s in sel.keys(): out[int(s)] = true
		else: out[_drag_from] = true
	return out.keys()


func _lk(a: int, b: int) -> String: return "%d_%d" % [mini(a, b), maxi(a, b)]


func _focus_route(rt: Array, flinks: Dictionary) -> void:
	for k in range(rt.size() - 1): flinks[_lk(int(rt[k]), int(rt[k + 1]))] = true


# the focused subgraph for building `aim`: STRICTLY the building itself, the buildings WIRED into it
# (any faction), the one its own wire points at, and the drag group. Route intermediates light their
# LINKS only — the buildings a route merely passes through stay fogged, as does everything unconnected
# (threat rings still draw at full brightness on fogged buildings, so an attack elsewhere is never invisible).
func _build_focus(aim: int, fnodes: Dictionary, flinks: Dictionary) -> void:
	fnodes[aim] = true
	for i in hosts.size():                      # incoming: everyone wired into it, any faction
		if int(hosts[i].assign) == aim:
			fnodes[i] = true
			_focus_route(_route(i, aim), flinks)
	var aout := int(hosts[aim].assign)          # outgoing: whom this building itself is wired to
	if aout >= 0:
		fnodes[aout] = true
		_focus_route(_route(aim, aout), flinks)
	for s in _aim_sources():                    # the drag group while a wire is being aimed
		if int(s) == aim: continue
		fnodes[int(s)] = true
		_focus_route(_route(int(s), aim), flinks)


func _fill_of(i: int) -> Color:
	var fac := int(hosts[i].owner)
	if fac == NEUTRAL and bool(hosts[i].hub): return Color(0.2, 0.75, 0.9)
	return fcol(fac)


func _draw() -> void:
	var f := get_theme_default_font()
	var aim := _aim_target()
	var focus_on := aim >= 0 and _inside < 0
	var fnodes := {}; var flinks := {}
	if focus_on: _build_focus(aim, fnodes, flinks)
	for i in hosts.size():   # streets, tinted by the botnet holding both ends; amber when at capacity
		for j in hosts[i].links:
			if j < i: continue
			var oi := int(hosts[i].owner); var oj := int(hosts[j].owner)
			var lcol := Color(0.35, 0.5, 0.7, 0.18); var w := 1.0
			if oi == oj and oi != NEUTRAL: lcol = fcol(oi); lcol.a = 0.35; w = 1.3
			if _link_busy(i, int(j)): lcol = Color(1, 0.75, 0.3, 0.65); w = 1.8
			if focus_on and not flinks.has(_lk(i, int(j))): lcol.a *= 0.22
			draw_line(hosts[i].pos, hosts[int(j)].pos, lcol, w, true)
	# connections. LIVE = solid flowing route; DORMANT = the dashed plan (nothing moving, nothing spent);
	# rally auto-supply = thin dim route. Strict fog: only the focused building's own connections stay bright.
	for i in hosts.size():
		var a := int(hosts[i].assign)
		if a < 0:
			var d := _bot_target(i)
			if d >= 0 and _next_depart.has(i): _draw_route_line(_route(i, d), i, d, true)
			continue
		var dimmed: bool = focus_on and not (fnodes.has(i) and fnodes.has(a))
		if bool(hosts[i].live) and not _mine(i) and str(hosts[i].get("mode", "attack")) == "scan": continue   # their quiet scans are invisible
		if bool(hosts[i].live):
			_draw_route_line(_route(i, a), i, a, dimmed)
		else:
			var kcol: Color = Color(0.45, 0.95, 0.7, 0.8) if int(hosts[a].owner) == int(hosts[i].owner) else Color(1, 0.85, 0.4, 0.8)
			if not _mine(i): kcol = fcol(int(hosts[i].owner)); kcol.a = 0.45
			if dimmed: kcol.a *= 0.25
			var rt := _route(i, a)
			if rt.size() >= 2: _draw_dashed(rt, kcol, 1.2)
			elif _mine(i): _draw_dashed([i, a], Color(0.8, 0.5, 0.5, (0.15 if dimmed else 0.55)), 1.0)   # unrouted plan
	for fl in flights:   # packets: yours = circle, other botnets = square in their colour, Cash = diamond
		var pp := _packet_pos(fl, _t)
		var endn := int((fl.route as Array)[(fl.route as Array).size() - 1])
		var threat: bool = int(fl.owner) != PLAYER and _mine(endn)
		var ba: float = 1.0 if (not focus_on or fnodes.has(endn) or threat) else 0.3
		var fc := fcol(int(fl.owner))
		if str(fl.kind) == "scan":
			if int(fl.owner) == PLAYER: draw_arc(pp, 3.5, 0.0, TAU, 12, Color(0.6, 0.95, 1.0, ba), 1.5, true)   # a quiet scan: only you see it
			continue
		if str(fl.kind) == "cash":
			var c := Color(1, 0.9, 0.3, ba) if int(fl.owner) == PLAYER else Color(fc.r, fc.g, fc.b, ba).lightened(0.3)
			draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -4), pp + Vector2(4, 0), pp + Vector2(0, 4), pp + Vector2(-4, 0)]), c)
		elif int(fl.owner) == PLAYER: draw_circle(pp, 3.5, Color(0.5, 1, 0.7, ba))
		else: draw_rect(Rect2(pp - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), Color(fc.r, fc.g, fc.b, ba).lightened(0.25), true)
	for i in hosts.size():   # strict fog: ONLY buildings connected to the focused one stay bright
		_draw_node(f, i, 1.0 if (not focus_on or fnodes.has(i)) else 0.22, i == aim)
	if focus_on:   # rings: GOLD = friendly connections, wide RED = hostile buildings wired into it
		var gold := Color(1, 0.85, 0.3, 0.95)
		var red := Color(1, 0.35, 0.3, 0.95)
		for i in hosts.size():
			if i != aim and int(hosts[i].assign) == aim:
				_frame(hosts[i].pos, _r(i) + 11.0, gold if _mine(i) else red, 1.8)   # gold = yours, red = another botnet's
		var aout := int(hosts[aim].assign)
		if aout >= 0: _frame(hosts[aout].pos, _r(aout) + 11.0, gold, 1.8)
		var reach := 0
		for s in _aim_sources():
			if _link_kind(int(s), aim) != "": _draw_dashed(_route(int(s), aim), Color(1, 0.95, 0.55, 0.95), 1.6); reach += 1
		if _dragging and reach == 0:
			draw_string(f, (hosts[aim].pos as Vector2) + Vector2(-_r(aim), -_r(aim) - 24.0), "✖ no path to %s" % str(hosts[aim].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.45, 0.4))
		else:
			var act: String = "🛡 defend %s" if _mine(aim) else "⚔ attack %s"
			draw_string(f, (hosts[aim].pos as Vector2) + Vector2(-_r(aim), -_r(aim) - 24.0), act % str(hosts[aim].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.92, 0.5))
	elif not sel.is_empty() and _inside < 0:   # connect step: glow where a wire could go + hover preview
		var src_keys: Array = sel.keys()
		for i in hosts.size():
			var ok := false
			for s in src_keys:
				if _link_kind(int(s), i) != "": ok = true; break
			if ok: _frame(hosts[i].pos, _r(i) + 7.0, Color(1, 0.8, 0.4, 0.55), 2.0)
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and not sel.has(hov):
			var elig := 0
			for s in src_keys:
				if _link_kind(int(s), hov) != "": _draw_dashed(_route(int(s), hov)); elig += 1
			if elig > 0:
				draw_string(f, (hosts[hov].pos as Vector2) + Vector2(-_r(hov), -_r(hov) - 22.0), "drag here to connect %s" % str(hosts[hov].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.5))
	if _dragging and _drag_from >= 0:   # the rubber band: RED over a target no selected source has a path to
		var to := get_local_mouse_position()
		var hv := _host_at(to)
		var lcol2 := Color(1, 0.95, 0.55, 0.95)
		if hv >= 0 and hv != _drag_from:
			to = hosts[hv].pos
			var ok := false
			for s in _aim_sources():
				if _link_kind(int(s), hv) != "": ok = true; break
			if not ok: lcol2 = Color(1, 0.4, 0.35, 0.95)
		draw_line(hosts[_drag_from].pos, to, lcol2, 1.8, true)
		draw_circle(to, 3.0, lcol2)
	if _boxing:
		var r := Rect2(_box_start, get_local_mouse_position() - _box_start).abs()
		draw_rect(r, Color(0.6, 1, 1, 0.08), true)
		draw_rect(r, Color(0.6, 1, 1, 0.6), false, 1.0, true)
	var sz := get_viewport_rect().size
	if _inside >= 0:   # MICRO: the map stays visible and alive behind a veil, but it is not yours to command
		draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x - PANEL_W - 24.0, sz.y)), Color(0, 0, 0, 0.35), true)
		var p: Vector2 = hosts[_inside].pos
		_frame(p, _r(_inside) + 12.0, Color(1, 0.9, 0.5, 0.95), 3.0)
		draw_string(f, Vector2(20, sz.y - 44.0), "INSIDE %s — the map keeps running. Esc / right-click leaves." % str(hosts[_inside].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.92, 0.5))
	if _msg_t > 0.0:
		draw_string(f, Vector2(20, sz.y - 20.0), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 1, 1, clampf(_msg_t, 0, 1)))
	if won or lost:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.55), true)
		draw_string(f, Vector2((sz.x - PANEL_W) * 0.5 - 150.0, sz.y * 0.5), ("VICTORY" if won else "DEFEATED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(0.5, 1, 1) if won else Color(1, 0.5, 0.5))


func _draw_node(f: Font, i: int, a: float, is_aim: bool) -> void:
	var p: Vector2 = hosts[i].pos
	var rr := _r(i)
	var fill := _fill_of(i)
	fill.a = a
	var ink := Color(0.04, 0.06, 0.1, 0.9 * a)
	_draw_type_glyph(self, str(hosts[i].get("type", "pc")), p, rr * 1.9, fill, ink)   # the building IS its pictogram
	if bool(hosts[i].rig): _frame(p, rr + 1.0, Color(1, 1, 1, 0.8 * a), 2.0)   # a rig = Cash sink
	if _mine(i) and _under_attack(i):   # under attack → red frame, always full brightness (never fogged)
		_frame(p, rr + 3.0, Color(1, 0.4, 0.35, 0.95), 2.5)
	if sel.has(i): _frame(p, rr + 6.0, Color(1, 1, 1, 0.95 * a), 2.0)
	if i == _inspect: _frame(p, rr + 8.0, Color(1, 0.9, 0.3, a), 1.5)
	if is_aim: _frame(p, rr + 9.0, Color(1, 0.9, 0.3), 2.0)
	if i == rally: draw_string(f, p + Vector2(rr + 4.0, 5.0), "⚑ RALLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.5, a))
	var fr: float = clampf(float(hosts[i].bots) / NODE_CAP, 0.0, 1.0)
	draw_rect(Rect2(p.x - rr, p.y + rr + 5.0, rr * 2.0, 5.0), Color(0.1, 0.12, 0.16, a), true)
	var bar := fcol(int(hosts[i].owner)).lightened(0.25); bar.a = a
	draw_rect(Rect2(p.x - rr, p.y + rr + 5.0, rr * 2.0 * fr, 5.0), bar, true)
	var nb_txt := "%d" % int(round(float(hosts[i].bots)))   # the bot counter: a small dark badge at the foot
	if not _mine(i) and not _scanned(PLAYER, i): nb_txt = "?"   # unscanned: its strength is unknown to you
	var bw := 8.0 + 7.0 * float(nb_txt.length())
	draw_rect(Rect2(p.x - bw * 0.5, p.y + rr * 0.42, bw, 13.0), Color(0.03, 0.05, 0.08, 0.88 * a), true)
	draw_string(f, Vector2(p.x - 3.6 * float(nb_txt.length()), p.y + rr * 0.42 + 10.5), nb_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.97, 1.0, a))
	var vmarks := ""
	for k in int(hosts[i].value): vmarks += "$"
	draw_string(f, p + Vector2(-rr - 2.0, -rr - 7.0), str(hosts[i].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.92, 1.0, a))
	draw_string(f, p + Vector2(rr + 3.0, -rr + 2.0), vmarks, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.4, 0.9 * a))
	var bi := ""   # build badges: B bot farm · I intel · $ cash · C vault — lowercase when offline
	var bl := _built(i); var act := _active_slots(i)
	for k in bl.size():
		var sh: String = str(BUILD_KINDS[str(bl[k][1])].short)
		bi += sh if k < act else sh.to_lower()
	if not (hosts[i].job as Dictionary).is_empty(): bi += "…"
	if bi != "" and int(hosts[i].owner) != NEUTRAL: draw_string(f, p + Vector2(-rr, rr + 22.0), bi, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.95, 0.6, 0.95 * a))
	var st := _stage(i)
	var sub := ""
	if st > 0 and int(hosts[i].owner) != NEUTRAL: sub = STAGE_NAME[st]
	if _mine(i) and float(hosts[i].rate) < 1.0: sub += ("  " if sub != "" else "") + "%d%%" % int(round(float(hosts[i].rate) * 100.0))
	if _mine(i) and float(hosts[i].bots) >= NODE_CAP - 0.5 and _incoming(i, PLAYER) > 0.0: sub += ("  " if sub != "" else "") + "FULL"
	if sub != "": draw_string(f, p + Vector2(rr + 3.0, rr + 10.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.85, 0.4, a))


func _draw_dashed(rt: Array, col := Color(1, 0.9, 0.5, 0.9), w := 1.2) -> void:   # dashed = a dormant plan
	for k in range(rt.size() - 1):
		var a: Vector2 = hosts[int(rt[k])].pos
		var b: Vector2 = hosts[int(rt[k + 1])].pos
		var ln := a.distance_to(b)
		var dir := (b - a) / maxf(ln, 0.001)
		var d := 0.0
		while d < ln:
			draw_line(a + dir * d, a + dir * minf(d + 9.0, ln), col, w, true)
			d += 15.0


# colour by the SOURCE's faction, shape by kind (defend/reinforce = diamond, attack = arrow)
func _draw_route_line(rt: Array, src: int, tgt: int, dim := false) -> void:
	if rt.size() < 2: return
	var from_player: bool = _mine(src)
	var reinforce: bool = int(hosts[src].owner) == int(hosts[tgt].owner)
	var col: Color
	if from_player and not reinforce: col = Color(1, 0.85, 0.35)
	elif from_player and reinforce: col = Color(0.4, 1, 0.7)
	else:
		col = fcol(int(hosts[src].owner)).lightened(0.15)
		if not _mine(tgt): col = col.darkened(0.2)          # an attack on someone else reads duller than one on you
	var fade := 0.3 if dim else 1.0
	var pts := PackedVector2Array()
	for idx in rt: pts.append(hosts[int(idx)].pos)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.16 * fade), 3.2, true)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.9 * fade), 1.4, true)
	var a: Vector2 = hosts[int(rt[rt.size() - 2])].pos
	var b: Vector2 = hosts[int(rt[rt.size() - 1])].pos
	var dir: Vector2 = (b - a).normalized()
	var tip: Vector2 = b - dir * (_r(tgt) + 3.0)
	var perp := Vector2(-dir.y, dir.x)
	var c := Color(col.r, col.g, col.b, 0.95 * fade)
	if reinforce:
		var ctr := tip - dir * 5.0
		draw_colored_polygon(PackedVector2Array([ctr + dir * 5.0, ctr + perp * 4.0, ctr - dir * 5.0, ctr - perp * 4.0]), c)
	else:
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 9.0 + perp * 5.0, tip - dir * 9.0 - perp * 5.0]), c)


# ============================================================ LOCAL VIEW WIDGETS (slots & cards)
# Icons are drawn procedurally so the prototype needs no art: each building kind has a glyph and a colour.
func _draw_kind_icon(c: CanvasItem, kind: String, centre: Vector2, sz: float, col: Color, f: Font) -> void:
	var ink := Color(0.06, 0.08, 0.12, col.a)
	match kind:
		"bot":   # a server rack: three units with a status LED each
			for r in 3:
				var y := centre.y - sz * 0.46 + float(r) * sz * 0.34
				c.draw_rect(Rect2(centre.x - sz * 0.45, y, sz * 0.9, sz * 0.26), col, true)
				c.draw_circle(Vector2(centre.x + sz * 0.3, y + sz * 0.13), sz * 0.06, ink)
		"intel":   # an eye with an antenna arc
			c.draw_arc(centre, sz * 0.4, 0.0, TAU, 32, col, sz * 0.09, true)
			c.draw_circle(centre, sz * 0.15, col)
			c.draw_arc(centre + Vector2(0, sz * 0.1), sz * 0.62, -2.45, -0.7, 16, col, sz * 0.07, true)
		"cash":   # a coin with a $ sign
			c.draw_circle(centre, sz * 0.46, col)
			c.draw_arc(centre, sz * 0.36, 0.0, TAU, 32, ink, sz * 0.04, true)
			c.draw_string(f, centre + Vector2(-sz * 0.17, sz * 0.21), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz * 0.62), ink)
		"cap":   # a vault door: a square with a dial
			c.draw_rect(Rect2(centre - Vector2(sz * 0.44, sz * 0.44), Vector2(sz * 0.88, sz * 0.88)), col, true)
			c.draw_arc(centre, sz * 0.2, 0.0, TAU, 24, ink, sz * 0.08, true)
			c.draw_line(centre, centre + Vector2(sz * 0.17, 0), ink, sz * 0.06, true)
		_:
			c.draw_rect(Rect2(centre - Vector2(sz * 0.4, sz * 0.4), Vector2(sz * 0.8, sz * 0.8)), col, false, 2.0)


func _frame(p: Vector2, half: float, col: Color, w: float) -> void:   # a square frame around a pictogram
	draw_rect(Rect2(p - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), col, false, w)


func _ellipse(centre: Vector2, rx: float, ry: float, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n: pts.append(centre + Vector2(cos(TAU * float(k) / float(n)) * rx, sin(TAU * float(k) / float(n)) * ry))
	return pts


# the seven building types as filled pictograms in `fill` with details in `ink`, inside a square of side `sz`
func _draw_type_glyph(c: CanvasItem, t: String, centre: Vector2, sz: float, fill: Color, ink: Color) -> void:
	var w := maxf(1.2, sz * 0.05)
	var dim := Color(ink.r, ink.g, ink.b, ink.a * 0.35)
	match t:
		"pc":      # a monitor on a stand
			var body := Rect2(centre + Vector2(-sz * 0.46, -sz * 0.46), Vector2(sz * 0.92, sz * 0.6))
			c.draw_rect(body, fill, true); c.draw_rect(body, ink, false, w)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.38, -sz * 0.38), Vector2(sz * 0.76, sz * 0.44)), dim, true)
			c.draw_line(centre + Vector2(0, sz * 0.14), centre + Vector2(0, sz * 0.3), ink, w * 1.6, true)
			var base := Rect2(centre + Vector2(-sz * 0.26, sz * 0.3), Vector2(sz * 0.52, sz * 0.12))
			c.draw_rect(base, fill, true); c.draw_rect(base, ink, false, w)
		"iot":     # a chip with legs and an antenna
			var chip := Rect2(centre + Vector2(-sz * 0.3, -sz * 0.22), Vector2(sz * 0.6, sz * 0.52))
			for k in 3:
				var x := centre.x - sz * 0.18 + float(k) * sz * 0.18
				c.draw_line(Vector2(x, centre.y + sz * 0.3), Vector2(x, centre.y + sz * 0.46), ink, w * 1.3, true)
				c.draw_line(Vector2(x, centre.y - sz * 0.22), Vector2(x, centre.y - sz * 0.34), ink, w * 1.3, true)
			c.draw_rect(chip, fill, true); c.draw_rect(chip, ink, false, w)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.14, -sz * 0.08), Vector2(sz * 0.28, sz * 0.26)), dim, true)
			c.draw_arc(centre + Vector2(sz * 0.28, -sz * 0.3), sz * 0.2, -2.9, -1.2, 10, ink, w, true)
		"server":  # a rack: three units with a light each
			for r in 3:
				var slab := Rect2(centre.x - sz * 0.44, centre.y - sz * 0.46 + float(r) * sz * 0.31, sz * 0.88, sz * 0.26)
				c.draw_rect(slab, fill, true); c.draw_rect(slab, ink, false, w)
				c.draw_circle(Vector2(slab.position.x + sz * 0.76, slab.position.y + sz * 0.13), sz * 0.045, ink)
				c.draw_line(slab.position + Vector2(sz * 0.08, sz * 0.13), slab.position + Vector2(sz * 0.5, sz * 0.13), dim, w * 1.4, true)
		"web":     # a globe
			c.draw_circle(centre, sz * 0.46, fill)
			c.draw_arc(centre, sz * 0.46, 0.0, TAU, 40, ink, w, true)
			c.draw_line(centre + Vector2(-sz * 0.46, 0), centre + Vector2(sz * 0.46, 0), ink, w, true)
			c.draw_line(centre + Vector2(0, -sz * 0.46), centre + Vector2(0, sz * 0.46), ink, w, true)
			c.draw_polyline(_ellipse(centre, sz * 0.2, sz * 0.46, 32), ink, w, true)
			c.draw_line(centre + Vector2(-sz * 0.4, -sz * 0.22), centre + Vector2(sz * 0.4, -sz * 0.22), dim, w, true)
			c.draw_line(centre + Vector2(-sz * 0.4, sz * 0.22), centre + Vector2(sz * 0.4, sz * 0.22), dim, w, true)
		"db":      # a cylinder
			var body := Rect2(centre + Vector2(-sz * 0.38, -sz * 0.3), Vector2(sz * 0.76, sz * 0.62))
			c.draw_rect(body, fill, true)
			c.draw_colored_polygon(_ellipse(centre + Vector2(0, sz * 0.32), sz * 0.38, sz * 0.14), fill)
			c.draw_polyline(_ellipse(centre + Vector2(0, sz * 0.32), sz * 0.38, sz * 0.14, 32), ink, w, true)
			c.draw_line(centre + Vector2(-sz * 0.38, -sz * 0.3), centre + Vector2(-sz * 0.38, sz * 0.32), ink, w, true)
			c.draw_line(centre + Vector2(sz * 0.38, -sz * 0.3), centre + Vector2(sz * 0.38, sz * 0.32), ink, w, true)
			c.draw_polyline(_ellipse(centre + Vector2(0, 0), sz * 0.38, sz * 0.14, 32), dim, w, true)
			c.draw_colored_polygon(_ellipse(centre + Vector2(0, -sz * 0.3), sz * 0.38, sz * 0.14), fill.lightened(0.15))
			c.draw_polyline(_ellipse(centre + Vector2(0, -sz * 0.3), sz * 0.38, sz * 0.14, 32), ink, w, true)
		"file":    # a filing cabinet with two drawers
			var cab := Rect2(centre + Vector2(-sz * 0.36, -sz * 0.46), Vector2(sz * 0.72, sz * 0.92))
			c.draw_rect(cab, fill, true); c.draw_rect(cab, ink, false, w)
			c.draw_line(centre + Vector2(-sz * 0.36, 0), centre + Vector2(sz * 0.36, 0), ink, w, true)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.12, -sz * 0.27), Vector2(sz * 0.24, sz * 0.07)), ink, true)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.12, sz * 0.2), Vector2(sz * 0.24, sz * 0.07)), ink, true)
		"erp":     # a factory with a gear
			var pts := PackedVector2Array([centre + Vector2(-sz * 0.46, sz * 0.46), centre + Vector2(-sz * 0.46, -sz * 0.4), centre + Vector2(-sz * 0.16, -sz * 0.16), centre + Vector2(-sz * 0.16, -sz * 0.4), centre + Vector2(sz * 0.14, -sz * 0.16), centre + Vector2(sz * 0.14, -sz * 0.4), centre + Vector2(sz * 0.46, -sz * 0.16), centre + Vector2(sz * 0.46, sz * 0.46)])
			c.draw_colored_polygon(pts, fill)
			var outline := PackedVector2Array(pts); outline.append(pts[0])
			c.draw_polyline(outline, ink, w, true)
			var g := centre + Vector2(sz * 0.2, sz * 0.2)
			c.draw_circle(g, sz * 0.16, dim)
			c.draw_arc(g, sz * 0.16, 0.0, TAU, 16, ink, w, true)
			for k in 6:
				var ang := float(k) * TAU / 6.0
				c.draw_line(g + Vector2(cos(ang), sin(ang)) * sz * 0.16, g + Vector2(cos(ang), sin(ang)) * sz * 0.24, ink, w * 1.3, true)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.36, sz * 0.12), Vector2(sz * 0.1, sz * 0.14)), dim, true)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.18, sz * 0.12), Vector2(sz * 0.1, sz * 0.14)), dim, true)
		_:
			c.draw_rect(Rect2(centre - Vector2(sz * 0.4, sz * 0.4), Vector2(sz * 0.8, sz * 0.8)), fill, true)
			c.draw_rect(Rect2(centre - Vector2(sz * 0.4, sz * 0.4), Vector2(sz * 0.8, sz * 0.8)), ink, false, w)


class TypeBadge extends Control:   # "what this building is": its picture, name, slots and multipliers
	var game
	var host := -1

	func _init() -> void:
		custom_minimum_size = Vector2(0, 42)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := get_theme_default_font()
		var t: String = str(game.hosts[host].get("type", "pc"))
		var tp: Dictionary = game.NODE_TYPES[t]
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 40)), Color(0.12, 0.14, 0.19), true)
		game._draw_type_glyph(self, t, Vector2(22, 20), 32.0, Color(0.75, 0.85, 1.0), Color(0.08, 0.1, 0.16))
		draw_string(f, Vector2(46, 17), str(tp.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.97, 1.0))
		draw_string(f, Vector2(46, 33), str(tp.desc), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.8, 0.9))


class SlotBox extends Control:   # one slot of the building you are inside: "+" when empty, the icon when built
	var game
	var host := -1
	var slot := 0

	func _init() -> void:
		custom_minimum_size = Vector2(76, 90)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Drop a building card here"

	func _process(_dt: float) -> void: queue_redraw()

	func _can_drop_data(_p: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).has("kind") and game._can_drop(host, slot, str(data.kind))

	func _drop_data(_p: Vector2, data: Variant) -> void:
		game._drop_build(host, slot, str(data.kind))

	func _draw() -> void:
		var f := get_theme_default_font()
		var w := size.x
		var box := Rect2(Vector2.ZERO, Vector2(w, 72))
		var h: Dictionary = game.hosts[host]
		var kind := str(h.builds[slot])
		var job: Dictionary = h.job
		var busy: bool = not job.is_empty() and int(job.slot) == slot
		var dragging: bool = get_viewport().gui_is_dragging()
		var hover: bool = dragging and get_global_rect().has_point(get_global_mouse_position())
		draw_rect(box, Color(0.1, 0.12, 0.17), true)
		var edge := Color(0.45, 0.55, 0.7, 0.7)
		if dragging: edge = Color(1, 0.9, 0.5, 0.95) if hover else Color(0.8, 0.75, 0.5, 0.7)
		draw_rect(box, edge, false, 2.0)
		draw_string(f, Vector2(4, 12), "slot %d" % (slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.65, 0.8))
		var centre := Vector2(w * 0.5, 38)
		if busy:
			var phase := str(job.phase)
			var total: float = game.DEMOLISH_TIME if phase == "demolish" else game.BUILD_TIME
			var frac: float = clampf(1.0 - float(job.left) / total, 0.0, 1.0)
			var k2: String = str(job.kind) if phase == "build" else kind
			if k2 != "": game._draw_kind_icon(self, k2, centre, 30.0, Color(game.BUILD_KINDS[k2].col, 0.35), f)
			draw_rect(Rect2(6, 62, w - 12, 6), Color(0.2, 0.22, 0.28), true)
			draw_rect(Rect2(6, 62, (w - 12) * frac, 6), Color(1, 0.6, 0.4) if phase == "demolish" else Color(1, 0.9, 0.5), true)
			draw_string(f, Vector2(4, 86), ("clearing %.0f s" if phase == "demolish" else "building %.0f s") % float(job.left), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.5))
		elif kind == "":
			draw_string(f, centre + Vector2(-9, 11), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.6, 0.7, 0.85))
			draw_string(f, Vector2(4, 86), "empty", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.7, 0.8))
		else:
			var active: bool = game._slot_active(host, slot)
			var col: Color = game.BUILD_KINDS[kind].col
			if not active: col.a = 0.4
			game._draw_kind_icon(self, kind, centre, 34.0, col, f)
			draw_string(f, Vector2(4, 86), str(game.BUILD_KINDS[kind].name) + ("" if active else " · OFF"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.95, 0.9) if active else Color(0.9, 0.7, 0.6))


class DragIcon extends Control:   # the picture that follows the pointer while a card is dragged
	var game
	var kind := ""

	func _draw() -> void:
		game._draw_kind_icon(self, kind, size * 0.5, 36.0, game.BUILD_KINDS[kind].col, get_theme_default_font())


class BuildCard extends Control:   # a draggable card for one building kind
	var game
	var kind := ""

	func _init() -> void:
		custom_minimum_size = Vector2(92, 98)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		tooltip_text = "%s — %s. Drag onto a slot." % [str(game.BUILD_KINDS[kind].name), str(game.BUILD_KINDS[kind].desc)]

	func _get_drag_data(_p: Vector2) -> Variant:
		var icon := DragIcon.new(); icon.game = game; icon.kind = kind
		icon.custom_minimum_size = Vector2(48, 48); icon.size = Vector2(48, 48)
		set_drag_preview(icon)
		return {"kind": kind}

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			game._card_click(kind)

	func _draw() -> void:
		var f := get_theme_default_font()
		var col: Color = game.BUILD_KINDS[kind].col
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.15, 0.21), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(col.r, col.g, col.b, 0.85), false, 2.0)
		game._draw_kind_icon(self, kind, Vector2(size.x * 0.5, 32), 32.0, col, f)
		draw_string(f, Vector2(4, 68), str(game.BUILD_KINDS[kind].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.95, 1.0))
		draw_string(f, Vector2(4, 84), "%.0f s · drag ↑" % game.BUILD_TIME, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.8, 0.9))
