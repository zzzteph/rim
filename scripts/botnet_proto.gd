extends Control
## PROTOTYPE v2 — macro/micro botnet race (spec: design/BOTNET_ATTACK_DESIGN.md).
##
## GLOBAL map (this screen) = MACRO: you redirect bots and Cash traffic between buildings.
## LOCAL view ("Enter building") = MICRO: you build inside one building. Entering takes time, a build
## only progresses while you stay inside, and while you are inside the map KEEPS RUNNING and cannot be
## commanded — attention is the cost of micro.
##
##   • A generated TOWN, different every run: a 6×6 cell grid with gaps, jittered positions, missing and
##     diagonal streets, a rich DOWNTOWN in the middle and a poor rim. Buildings differ in security
##     (neutral defenders), slots (how much you can build inside) and value (Cash per market packet).
##   • Three factions: YOU (top-left rig), a RIVAL botnet (bottom-right rig) and NEUTRAL buildings guarded
##     by their own security, which regenerates only to its own level. Both botnets expand and clash.
##   • A building's bots ARE its health and its defence (cap NODE_CAP once owned). It regenerates PROD_RATE
##     per Bot farm it runs. The more bots it holds the more of its slots keep working (control stages).
##   • Command production: select source(s) → aim a destination → START. A source releases one bot per
##     second × its rate dial along its own network. Bots act only on ARRIVAL: an attack arrival removes
##     ATTACK/DEFEND (≈0.667) of a defender; a reinforcement adds a full bot. At 0 the building flips.
##   • Links have CAPACITY (LINK_CAP packets per LINK_TIME per direction). Bots and Cash packets share
##     it: a busy link queues packets at the building before it and holds a source whose queue is long.
##   • Darknet markets emit Cash packets (worth the building's value) that must TRAVEL home to the owner's
##     rig. The first botnet to bank CASH_GOAL wins; losing every building is defeat.
##   • Rally point (one): every idle building of yours sends its surplus above a garrison to it — the
##     command-unit experiment (does one standing order for the rear scale to a town?).
## Right-click / Esc = clear (or leave the building you are inside). SPACE pauses everything.

const NEUTRAL := 0
const PLAYER := 1
const RIVAL := 2
const FACTION_NAME := {0: "city security", 1: "yours", 2: "RIVAL"}

# ── the town ──
const GRID_COLS := 6
const GRID_ROWS := 6
const EMPTY_CELL := 0.15           # chance a cell is a gap (park, void) — never the rigs or downtown
const LINK_KEEP := 0.78            # chance a street between two neighbouring buildings exists
const DIAG_P := 0.18               # chance of a diagonal shortcut street
const TOWN_WORDS := ["Block", "Yard", "Row", "Plaza", "Depot", "Tower", "Mill", "Court", "Lane", "Pier", "Works", "Arcade"]

const NODE_CAP := 30.0             # bots limit per OWNED building
const PROD_RATE := 1.0             # bots/sec PER active Bot farm

# combat power — a defender is worth 1.5× an attacker (D = 1.5·A); an arriving attack bot removes A/D
const ATTACK_POWER := 1.0
const DEFEND_POWER := 1.5

# ── the LOCAL layer: buildings inside a building (slots), built on a timer while you are INSIDE ──
const HUB_SLOTS := 4
const BUILD_TIME := 6.0            # seconds a build job needs; YOUR jobs progress only while you are inside
const ENTER_TIME := 2.0            # seconds to connect into a building before its local view is usable
const BUILD_KINDS := {
	"bot":   {"name": "Bot farm",        "short": "B", "desc": "+1 bot/s regeneration here"},
	"intel": {"name": "Intel harvester", "short": "I", "desc": "+1 Intel/s (global). Attacks spend 1 Intel per bot."},
	"cash":  {"name": "Darknet market",  "short": "$", "desc": "a Cash packet (worth the building's value) every 3 s, travelling home to your rig"},
	"cap":   {"name": "Intel vault",     "short": "C", "desc": "+100 Intel capacity"},
}
const INTEL_START := 50.0
const INTEL_CAP_BASE := 100.0
const CAP_PER_BUILD := 100.0
const INTEL_PER_BUILD := 1.0
const CASH_INTERVAL := 3.0         # seconds between Cash packets per active Darknet market
const CASH_GOAL := 600.0           # bank this first → win (the rival banking it first → defeat)

# ── the bot-flow dials ──
const SEND_RATE := 1.0             # bots/sec a source releases at rate dial 100%
const LINK_TIME := 1.0             # seconds to cross one link (hop)
const NODE_ROUTE_DELAY := 0.25     # pause (s) at each intermediate building
const LINK_CAP := 2                # packets a link DIRECTION admits per LINK_TIME (throughput 2/s)
const MAX_QUEUE := 1.0             # a source holds its packet if the first link can't admit it within this

# ── control stages: fewer bots → fewer working slots (first slot always works) ──
const STAGE_FULL := 2.0 / 3.0
const STAGE_SHAKY := 1.0 / 3.0
const STAGE_NAME := ["FULL", "SHAKY", "CRITICAL"]

# ── rally (command-unit experiment) & the rival ──
const RALLY_RESERVE := 10.0        # an auto-supplying building keeps this garrison at home
const RIVAL_CADENCE := 4.0         # how often the rival thinks
const RIVAL_MAX_STREAMS := 4       # sources the rival concentrates on one target
const RIVAL_RESERVE := 6.0         # garrison a rival building keeps
const RIVAL_PATIENCE := 30.0       # seconds WITHOUT PROGRESS before the rival gives up an attack
const PANEL_W := 440.0

var full_hold := false             # EXPERIMENT (off): hold explicit reinforcement when the target has no room
var town_seed := 0                 # 0 = a new town every run; set before _ready to reproduce a layout

var rng := RandomNumberGenerator.new()
var _t := 0.0                      # the single simulation clock everything shares
var paused := false
var won := false
var lost := false
var _end_shown := false
var _end_cause := ""
var _msg := ""
var _msg_t := 0.0

var hosts := []        # {pos,grid,name,links,owner,bots,sec,value,slots,builds,job,assign,rate,hub,rig}
var hub := -1
var rig := {}          # faction -> index of its rig (the Cash sink)
var _cell := {}        # Vector2i grid cell -> host index (gaps have no entry)
var intel := INTEL_START
var cash := {PLAYER: 0.0, RIVAL: 0.0}
var flights := []      # {route:[idx], hops:[link entry times], depart_t, arrive_t, owner, kind:"bot"|"cash", amount}
var _res := {}         # "a>b" -> sorted entry times reserved on that link direction (capacity)
var _next_depart := {} # bot source -> absolute time its next bot is due
var _next_cash := {}   # cash emitter -> absolute time its next packet is due
var rally := -1        # your rally point, or -1
var _inside := -1      # the building whose LOCAL view is open, or -1
var _enter_left := 0.0 # seconds until the local view is usable
var _rival_timer := RIVAL_CADENCE
var _rival_target := -1
var _rival_since := 0.0
var _rival_tgt_bots := 0.0
var _rival_avoid := -1

# selection / command
var sel := {}
var sel_target := -1
var _inspect := -1
var _press_pos := Vector2.ZERO
var _boxing := false
var _box_start := Vector2.ZERO
var _drag_from := -1
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


# ============================================================ TOWN GENERATION
# A different town every run: cells may be gaps, positions jitter, streets are missing or diagonal,
# downtown is rich and well defended, the rim is poor and soft. Everything stays connected.
func _gen() -> void:
	if town_seed == 0:
		rng.randomize(); town_seed = int(rng.randi() % 900000) + 1
	rng.seed = town_seed
	var sz := get_viewport_rect().size
	hosts = []; hub = -1; rig = {}; _cell = {}; flights = []; _res = {}; _next_depart = {}; _next_cash = {}
	var ax := 70.0; var ay := 104.0
	var aw := sz.x - PANEL_W - 150.0; var ah := sz.y - ay - 120.0
	var sx := aw / float(GRID_COLS - 1); var sy := ah / float(GRID_ROWS - 1)
	var centre := Vector2(float(GRID_COLS - 1) * 0.5, float(GRID_ROWS - 1) * 0.5)
	var hub_cell := Vector2i(int(centre.x) + (rng.randi() % 2), int(centre.y) + (rng.randi() % 2))
	var you := [Vector2i(0, 0), Vector2i(0, 1)]
	var them := [Vector2i(GRID_COLS - 1, GRID_ROWS - 1), Vector2i(GRID_COLS - 1, GRID_ROWS - 2)]
	var forced := you + them + [hub_cell]
	for gy in GRID_ROWS:
		for gx in GRID_COLS:
			var c := Vector2i(gx, gy)
			if not forced.has(c) and rng.randf() < EMPTY_CELL: continue   # a park, a lot, a void
			var is_hub: bool = c == hub_cell
			var dist: float = Vector2(gx, gy).distance_to(centre) / centre.length()   # 0 downtown … 1 corner
			var value := 3 if (is_hub or dist < 0.38) else (2 if dist < 0.72 else 1)
			if not is_hub and rng.randf() < 0.2: value = clampi(value + (1 if rng.randf() < 0.5 else -1), 1, 3)
			var sec := 30.0 if is_hub else float(2 + value * 5 + int(rng.randi() % 6))   # 7…22 defenders
			var slots := HUB_SLOTS if is_hub else clampi(1 + value + (1 if rng.randf() < 0.4 else 0), 2, 4)
			var p := Vector2(ax + sx * float(gx), ay + sy * float(gy)) + Vector2(rng.randf_range(-0.26, 0.26) * sx, rng.randf_range(-0.26, 0.26) * sy)
			_cell[c] = hosts.size()
			if is_hub: hub = hosts.size()
			hosts.append({"pos": p, "grid": c, "hub": is_hub, "rig": false,
				"name": "DOWNTOWN HUB" if is_hub else "%s %d" % [TOWN_WORDS[rng.randi() % TOWN_WORDS.size()], hosts.size() + 1],
				"links": [], "owner": NEUTRAL, "bots": sec, "sec": sec, "value": value, "slots": slots,
				"builds": (["bot", "bot"] if is_hub else ["bot"]), "job": {}, "assign": -1, "rate": 1.0})
	for c in _cell.keys():   # streets: grid neighbours (some missing), a few diagonals (never crossing)
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb: Vector2i = c + d
			if not _cell.has(nb): continue
			var must: bool = (you.has(c) and you.has(nb)) or (them.has(c) and them.has(nb))
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
	# YOU start top-left, the RIVAL bottom-right; each holds a rig (its Cash sink) and one more building
	_claim(_cell[you[0]], PLAYER, true, "YOUR RIG")
	_claim(_cell[you[1]], PLAYER, false, "")
	_claim(_cell[them[0]], RIVAL, true, "RIVAL RIG")
	_claim(_cell[them[1]], RIVAL, false, "")


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


func _claim(i: int, fac: int, is_rig: bool, nm: String) -> void:
	hosts[i].owner = fac; hosts[i].bots = NODE_CAP; hosts[i].value = 1; hosts[i].slots = maxi(3, int(hosts[i].slots))
	if is_rig:
		hosts[i].rig = true; rig[fac] = i; hosts[i].builds = ["bot", "bot"]
	if nm != "": hosts[i].name = nm


func _link(a: int, b: int) -> void:
	if a == b: return
	if not (hosts[a].links as Array).has(b): hosts[a].links.append(b)
	if not (hosts[b].links as Array).has(a): hosts[b].links.append(a)


func cell_at(gx: int, gy: int) -> int:   # host index at a grid cell, or -1 for a gap
	return int(_cell.get(Vector2i(gx, gy), -1))


func _mine(i: int) -> bool: return i >= 0 and int(hosts[i].owner) == PLAYER


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


func _link_kind(src: int, t: int) -> String:
	if src < 0 or t < 0 or src == t or not _mine(src): return ""
	if _route(src, t).is_empty(): return ""
	return "reinforce" if _mine(t) else "attack"


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


# ---- control stages, buildings & the economy ----
func _stage(i: int) -> int:
	var fr: float = float(hosts[i].bots) / NODE_CAP
	if fr >= STAGE_FULL: return 0
	if fr >= STAGE_SHAKY: return 1
	return 2


func _active_slots(i: int) -> int:   # a weakened building runs fewer of its slots (the first always works)
	return maxi(1, (hosts[i].builds as Array).size() - _stage(i))


func _count(i: int, kind: String) -> int:   # ACTIVE buildings of a kind
	var n := 0
	var b: Array = hosts[i].builds
	for k in mini(_active_slots(i), b.size()):
		if str(b[k]) == kind: n += 1
	return n


func _count_all(i: int, kind: String) -> int:   # built, active or not
	var n := 0
	for b in hosts[i].builds:
		if str(b) == kind: n += 1
	return n


func _intel_cap() -> float:
	var caps := 0
	for i in hosts.size():
		if _mine(i): caps += _count(i, "cap")
	return INTEL_CAP_BASE + CAP_PER_BUILD * float(caps)


func _intel_rate() -> float:
	var r := 0.0
	for i in hosts.size():
		if _mine(i): r += float(_count(i, "intel")) * INTEL_PER_BUILD
	return r


func _cash_rate(fac: int) -> float:   # Cash/s a faction's active markets emit (before travel)
	var r := 0.0
	for i in hosts.size():
		if int(hosts[i].owner) == fac: r += float(_count(i, "cash")) * float(hosts[i].value) / CASH_INTERVAL
	return r


func _start_job(i: int, kind: String) -> bool:
	if i < 0 or int(hosts[i].owner) == NEUTRAL or not BUILD_KINDS.has(kind): return false
	if not (hosts[i].job as Dictionary).is_empty(): return false
	if (hosts[i].builds as Array).size() >= int(hosts[i].slots): return false
	hosts[i].job = {"kind": kind, "left": BUILD_TIME}
	return true


func _player_build(i: int, kind: String) -> void:
	if _start_job(i, kind):
		_flash("Building %s in %s — stay inside %.0f s to finish it" % [BUILD_KINDS[kind].name, str(hosts[i].name), BUILD_TIME])
	_refresh_panel(); queue_redraw()


func _cancel_job(i: int) -> void:
	if i >= 0: hosts[i].job = {}
	_refresh_panel(); queue_redraw()


func _demolish(i: int, slot: int) -> void:
	if i < 0 or slot < 0 or slot >= (hosts[i].builds as Array).size(): return
	var kind := str(hosts[i].builds[slot])
	(hosts[i].builds as Array).remove_at(slot)
	intel = minf(_intel_cap(), intel)
	_flash("Demolished %s in %s" % [BUILD_KINDS[kind].name, str(hosts[i].name)])
	_refresh_panel(); queue_redraw()


# a build job progresses only while its owner is "inside": you must stay in the local view; the rival
# runs one job at a time (its attention) and is always inside it
func _tick_jobs(dt: float) -> void:
	for i in hosts.size():
		var job: Dictionary = hosts[i].job
		if job.is_empty(): continue
		var fac := int(hosts[i].owner)
		var progress: bool = (fac == RIVAL) or (fac == PLAYER and _inside == i and _enter_left <= 0.0)
		if not progress: continue
		job.left = float(job.left) - dt
		if float(job.left) <= 0.0:
			(hosts[i].builds as Array).append(str(job.kind))
			hosts[i].job = {}
			if fac == PLAYER:
				_flash("Built %s in %s" % [BUILD_KINDS[str(job.kind)].name, str(hosts[i].name)])
				_refresh_panel()


func _bank(fac: int, amount: float) -> void:
	cash[fac] = float(cash[fac]) + amount
	if won or lost: return
	if fac == PLAYER and float(cash[PLAYER]) >= CASH_GOAL:
		won = true; _end_cause = "You banked %d Cash." % int(CASH_GOAL)
	elif fac == RIVAL and float(cash[RIVAL]) >= CASH_GOAL:
		lost = true; _end_cause = "The rival banked %d Cash first." % int(CASH_GOAL)


# ---- who sends what where ----
func _reserve_of(i: int) -> float:   # garrison a source keeps at home
	if int(hosts[i].owner) == RIVAL: return RIVAL_RESERVE
	if int(hosts[i].assign) < 0: return RALLY_RESERVE   # auto-supply keeps a garrison
	return 0.0


func _bot_target(i: int) -> int:   # explicit order, else your rally point (auto-supply), else none
	var a := int(hosts[i].assign)
	if a >= 0: return a
	if _mine(i) and rally >= 0 and rally != i and _mine(rally) and _hostile_incoming(i) <= 0.0: return rally
	return -1


func _attack_demand() -> float:   # Intel/s your running attack orders would spend
	var n := 0.0
	for i in hosts.size():
		var t := int(hosts[i].assign)
		if _mine(i) and t >= 0 and not _mine(t) and not _route(i, t).is_empty(): n += SEND_RATE * float(hosts[i].rate)
	return n


# why a source isn't delivering right now — drives the cause→action diagnostics
func _src_state(s: int) -> String:
	var tgt := _bot_target(s)
	if tgt < 0: return "idle"
	var rt := _route(s, tgt)
	if rt.is_empty(): return "no route"
	if float(hosts[s].bots) - 1.0 < _reserve_of(s): return "no bots" if int(hosts[s].assign) >= 0 else "garrison"
	if _mine(s) and not _mine(tgt) and intel < 1.0: return "no Intel"
	if _first_wait(rt) > MAX_QUEUE: return "link busy"
	return "sending"


# ============================================================ LOOP
func _process(dt: float) -> void:
	if _msg_t > 0.0: _msg_t -= dt
	if not paused and not won and not lost:
		_t += dt                        # the shared clock only advances while playing → pause freezes everything
		for i in hosts.size():
			var nb := _count(i, "bot")
			if nb > 0 and float(hosts[i].bots) < _cap_of(i):
				hosts[i].bots = minf(_cap_of(i), float(hosts[i].bots) + PROD_RATE * float(nb) * dt)
		intel = minf(_intel_cap(), intel + _intel_rate() * dt)
		if _inside >= 0 and _enter_left > 0.0: _enter_left = maxf(0.0, _enter_left - dt)
		_tick_jobs(dt)
		_prune_res()
		_emit_due()
		if not won and not lost: _deliver_due()      # chronological; may set won/lost and then stops
		if not won and not lost: _rival_ai(dt)
		if not won and not lost and _player_nodes() == 0: lost = true; _end_cause = "You lost your last building."
		_panel_t += dt
		if _panel_t >= 0.25 and not _pointer_over_panel():
			_panel_t = 0.0; _refresh_panel()
	if (won or lost) and not _end_shown:
		_end_shown = true; _refresh_panel()
	hud.text = _hud_text()
	queue_redraw()


func _can_emit(i: int) -> bool:
	var tgt := _bot_target(i)
	if tgt < 0 or not _next_depart.has(i): return false
	if float(_next_depart[i]) > _t: return false
	if float(hosts[i].bots) - 1.0 < _reserve_of(i): return false
	var fac := int(hosts[i].owner)
	var hostile: bool = int(hosts[tgt].owner) != fac
	if fac == PLAYER and hostile and intel < 1.0: return false
	if not hostile and (full_hold or int(hosts[i].assign) < 0):   # auto-supply never overfills its rally
		if float(hosts[tgt].bots) + _incoming(tgt, fac) >= NODE_CAP - 0.001: return false
	var rt := _route(i, tgt)
	if rt.is_empty() or _first_wait(rt) > MAX_QUEUE: return false
	return true


func _can_emit_cash(i: int) -> bool:
	if not _next_cash.has(i) or float(_next_cash[i]) > _t: return false
	var fac := int(hosts[i].owner)
	if not rig.has(fac): return false
	var rg := int(rig[fac])
	if int(hosts[rg].owner) != fac: return false   # your sink is gone → Cash holds until you retake it
	if i == rg: return true
	var rt := _route(i, rg)
	if rt.is_empty() or _first_wait(rt) > MAX_QUEUE: return false
	return true


# Release every DUE departure (bots AND Cash packets) in TIME order with a rotating tie-break, so no
# source wins scarce Intel or link room purely by index. A held source never builds a catch-up backlog.
func _emit_due() -> void:
	var n := hosts.size()
	for i in n:                                     # validate orders & seed departure clocks
		var tgt := _bot_target(i)
		if tgt < 0:
			_next_depart.erase(i)
		elif int(hosts[i].assign) >= 0 and _route(i, tgt).is_empty():
			hosts[i].assign = -1; _next_depart.erase(i)
			if _mine(i): _flash("%s's supply stopped — no route (reissue to restore)" % str(hosts[i].name))
		elif not _next_depart.has(i): _next_depart[i] = _t
		if int(hosts[i].owner) != NEUTRAL and _count(i, "cash") > 0:
			if not _next_cash.has(i): _next_cash[i] = _t
		else: _next_cash.erase(i)
	var guard := 0
	while guard < 4000:
		guard += 1
		var best := -1; var best_t := INF; var best_kind := ""
		for k in n:
			var i: int = (_emit_cursor + k) % n
			if _can_emit(i) and float(_next_depart[i]) < best_t:
				best = i; best_t = float(_next_depart[i]); best_kind = "bot"
			if _can_emit_cash(i) and float(_next_cash[i]) < best_t:
				best = i; best_t = float(_next_cash[i]); best_kind = "cash"
		if best < 0: break
		var fac := int(hosts[best].owner)
		if best_kind == "bot":
			var tgt := _bot_target(best)
			hosts[best].bots = float(hosts[best].bots) - 1.0
			if fac == PLAYER and int(hosts[tgt].owner) != PLAYER: intel -= 1.0   # your attack spends Intel
			flights.append(_schedule(_route(best, tgt), best_t, fac, "bot"))
			_next_depart[best] = best_t + 1.0 / (SEND_RATE * float(hosts[best].rate))
		else:
			var rg := int(rig[fac])
			var amount := float(hosts[best].value)
			if best == rg: _bank(fac, amount)        # the rig banks its own market directly
			else: flights.append(_schedule(_route(best, rg), best_t, fac, "cash", amount))
			_next_cash[best] = best_t + CASH_INTERVAL / float(_count(best, "cash"))
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
	if int(hosts[t].owner) == fac:
		hosts[t].bots = minf(NODE_CAP, float(hosts[t].bots) + 1.0)
		return
	hosts[t].bots = float(hosts[t].bots) - (ATTACK_POWER / DEFEND_POWER)
	if float(hosts[t].bots) <= 0.0: _capture(t, fac)


func _capture(t: int, fac: int) -> void:
	var prev := int(hosts[t].owner)
	var nm := str(hosts[t].name)
	hosts[t].owner = fac
	hosts[t].bots = minf(NODE_CAP, -float(hosts[t].bots))
	hosts[t].assign = -1; hosts[t].job = {}; hosts[t].rate = 1.0
	_next_depart.erase(t); _next_cash.erase(t)
	if fac != PLAYER:
		if sel.has(t): sel.erase(t)          # a selected source lost to the rival is uncontrollable
		if rally == t: rally = -1
		if _inside == t:
			_inside = -1; _enter_left = 0.0
			_flash("Connection lost — %s fell while you were inside it" % nm)
	var feeders := 0
	for i in hosts.size():
		if int(hosts[i].assign) == t: feeders += 1
	if fac == PLAYER:
		if feeders > 0: _flash("Captured %s — %d source(s) now REINFORCE it" % [nm, feeders])
		else: _flash("Captured %s" % nm)
	elif prev == PLAYER:
		if feeders > 0: _flash("Lost %s to the rival — %d source(s) now ATTACK it" % [nm, feeders])
		else: _flash("Lost %s to the rival" % nm)
	else:
		_flash("The rival took %s" % nm)
	_refresh_panel()


# ---- the rival: expands into the town from the bottom, concentrates on the softest border, builds ----
func _rival_ai(dt: float) -> void:
	_rival_timer -= dt
	if _rival_timer > 0.0: return
	_rival_timer = RIVAL_CADENCE
	var mine := []
	for e in hosts.size():
		if int(hosts[e].owner) == RIVAL: mine.append(e)
	if mine.is_empty(): return
	for e in mine:   # release any order whose target it now holds or can no longer reach
		var a := int(hosts[e].assign)
		if a >= 0 and (int(hosts[a].owner) == RIVAL or _route(e, a).is_empty()):
			hosts[e].assign = -1; _next_depart.erase(e)
	var busy := false   # one build job at a time = the rival's attention
	for e in mine:
		if not (hosts[e].job as Dictionary).is_empty(): busy = true
	if not busy:
		for e in mine:
			if (hosts[e].builds as Array).size() >= int(hosts[e].slots): continue
			var frontier := false
			for p in hosts[e].links:
				if int(hosts[p].owner) != RIVAL: frontier = true
			var kind := "bot"
			if frontier: kind = "bot" if _count_all(e, "bot") < 2 else "cash"
			else: kind = "cash" if _count_all(e, "cash") < 2 else "bot"
			if _start_job(e, kind): break
	var active := false
	for e in mine:
		if int(hosts[e].assign) >= 0: active = true
	if active:
		if _rival_target >= 0:
			var now_b := float(hosts[_rival_target].bots)
			if now_b < _rival_tgt_bots - 0.5: _rival_tgt_bots = now_b; _rival_since = _t   # progress
			elif _t - _rival_since > RIVAL_PATIENCE:   # no progress for a while → give up, try elsewhere
				for e in mine:
					if int(hosts[e].assign) == _rival_target: hosts[e].assign = -1; _next_depart.erase(e)
				_rival_avoid = _rival_target; _rival_target = -1
		return
	var cands := []
	for e in mine:
		for p in hosts[e].links:
			if int(hosts[p].owner) != RIVAL and not cands.has(p): cands.append(p)
	if cands.size() > 1 and cands.has(_rival_avoid): cands.erase(_rival_avoid)
	if cands.is_empty(): return
	var pick := -1; var best := INF
	for c in cands:   # softest first, richer and yours preferred on near-ties
		var score: float = float(hosts[c].bots) - 3.0 * float(hosts[c].value) - (3.0 if _mine(int(c)) else 0.0)
		if score < best: best = score; pick = int(c)
	var regen := float(_count(pick, "bot")) * PROD_RATE
	var need := clampi(floori(regen * DEFEND_POWER / (ATTACK_POWER * SEND_RATE)) + 2, 2, RIVAL_MAX_STREAMS)
	var srcs := []
	for e in mine:
		if float(hosts[e].bots) < RIVAL_RESERVE + 2.0: continue
		var rt := _route(e, pick)
		if not rt.is_empty(): srcs.append([rt.size(), e])
	srcs.sort_custom(func(a, b): return a[0] < b[0])
	var n := 0
	for s in srcs:
		if n >= need: break
		hosts[int(s[1])].assign = pick; _next_depart[int(s[1])] = _t; n += 1
	if n > 0:
		_rival_target = pick; _rival_since = _t; _rival_tgt_bots = float(hosts[pick].bots)
		if _mine(pick): _flash("⚔ The RIVAL is attacking %s with %d source(s) — defend it!" % [str(hosts[pick].name), n])


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


func _clear_all() -> void:
	sel = {}; sel_target = -1; _inspect = -1; _drag_from = -1; _dragging = false; _boxing = false


func _enter(i: int) -> void:   # go MICRO: the local view opens after ENTER_TIME; the map keeps running
	if not _mine(i): return
	_inside = i; _enter_left = ENTER_TIME; sel_target = -1; _drag_from = -1; _dragging = false
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
			_boxing = hit < 0
			_drag_from = hit if _mine(hit) else -1
			_dragging = false
			return
		var moved: bool = event.position.distance_to(_press_pos) > 8.0
		if _boxing and moved:
			_marquee(Rect2(_box_start, event.position - _box_start).abs(), shift)
		elif _drag_from >= 0 and moved and hit >= 0 and hit != _drag_from:
			_drag_aim(_drag_from, hit)
		elif not moved:
			_left_click(hit, shift)
		_boxing = false; _drag_from = -1; _dragging = false
		_refresh_panel(); queue_redraw()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_clear_all()
		_refresh_panel(); queue_redraw()


# (1) left-click your building(s) to SELECT. (2) left-click a target → PENDING, the command button
# appears. (3) press the button to start. Nothing fires on click.
func _left_click(hit: int, shift: bool) -> void:
	if hit < 0:
		_clear_all()
		return
	if shift and _mine(hit):
		if sel.has(hit): sel.erase(hit)
		else: sel[hit] = true
		sel_target = -1; _inspect = -1
		return
	if sel.is_empty():
		if _mine(hit): sel = {hit: true}
		else: _inspect = hit
		sel_target = -1
		return
	if _mine(hit) and sel.has(hit):
		return
	sel_target = hit


func _do_command() -> void:
	if sel_target >= 0:
		var t := sel_target
		sel_target = -1
		_command(t)


func _drag_aim(src: int, dest: int) -> void:
	if not sel.has(src): sel = {src: true}
	sel_target = dest; _inspect = -1


func _marquee(r: Rect2, shift: bool) -> void:
	if not shift: sel = {}
	for i in hosts.size():
		if _mine(i) and r.has_point(hosts[i].pos): sel[i] = true
	sel_target = -1; _inspect = -1


func _host_at(p: Vector2) -> int:
	for i in hosts.size():
		if (hosts[i].pos as Vector2).distance_to(p) <= _r(i) + 5.0: return i
	return -1


# command the selected group to a destination (persistent). Other faction = Attack, yours = Reinforce.
func _command(dest: int) -> void:
	if dest < 0 or sel.is_empty(): return
	var done := 0; var excl := 0
	for s in sel.keys():
		if _mine(int(s)) and not _route(int(s), dest).is_empty():
			hosts[int(s)].assign = dest
			if not _next_depart.has(int(s)): _next_depart[int(s)] = _t
			done += 1
		else: excl += 1
	if done > 0:
		var act := "Reinforce" if _mine(dest) else "Attack"
		_flash("%s %s · %d source(s)%s" % [act, str(hosts[dest].name), done, ("  ·  %d excluded (no route)" % excl) if excl > 0 else ""])
	else:
		_flash("No selected source can reach %s" % str(hosts[dest].name))
	_refresh_panel()


func _stop_supplying() -> void:   # only the selected sources' future outgoing supply
	var n := 0
	for s in sel.keys():
		if _mine(int(s)) and int(hosts[int(s)].assign) >= 0:
			hosts[int(s)].assign = -1; _next_depart.erase(int(s)); n += 1
	if n > 0: _flash("Stopped supply from %d source(s)" % n)
	else: _flash("No active supply to stop")
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
	if i >= 0: _flash("Rally point: %s — idle buildings of yours send surplus above %d bots there" % [str(hosts[i].name), int(RALLY_RESERVE)])
	else: _flash("Rally point cleared")
	_refresh_panel(); queue_redraw()


func _select_contributors(feeders: Array) -> void:
	sel = {}
	for i in feeders: sel[int(i)] = true
	_inspect = -1; _refresh_panel(); queue_redraw()


func _owned_feeders(node: int) -> Array:   # your sources explicitly pointing at `node`
	var out := []
	for i in hosts.size():
		if _mine(i) and int(hosts[i].assign) == node: out.append(i)
	return out


func _cancel_to(dest: int) -> void:
	var n := 0
	for i in _owned_feeders(dest):
		hosts[int(i)].assign = -1; _next_depart.erase(int(i)); n += 1
	if n > 0: _flash("Stopped %d supply order(s) into %s" % [n, str(hosts[dest].name)])
	else: _flash("No supply of yours is aimed at %s" % str(hosts[dest].name))
	_refresh_panel(); queue_redraw()


func _reset() -> void:   # a NEW town every restart
	won = false; lost = false; _end_shown = false; _end_cause = ""; paused = false; _t = 0.0
	_rival_timer = RIVAL_CADENCE; _rival_target = -1; _rival_since = 0.0; _rival_tgt_bots = 0.0; _rival_avoid = -1
	_emit_cursor = 0; _panel_t = 0.0; intel = INTEL_START; cash = {PLAYER: 0.0, RIVAL: 0.0}
	rally = -1; _inside = -1; _enter_left = 0.0; town_seed = 0
	_clear_all()
	_gen(); _refresh_panel()


func _build_names(builds: Array) -> String:
	if builds.is_empty(): return "none"
	var out := []
	for b in builds: out.append(BUILD_KINDS[str(b)].name if BUILD_KINDS.has(str(b)) else str(b))
	return ", ".join(out)


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


# Panel states: RESULT · INSIDE (micro) · PREVIEW (about to commit) · SELECTING · INSPECT · IDLE
func _refresh_panel() -> void:
	for c in panel_box.get_children(): c.queue_free()
	if won or lost: _panel_result(); return
	if _inside >= 0: _panel_inside()
	elif not sel.is_empty() and sel_target >= 0: _panel_preview()
	elif not sel.is_empty(): _panel_selecting()
	elif _inspect >= 0: _panel_inspect()
	else: _panel_idle()
	if paused: _plabel("— PAUSED (Space) —", 15, Color(1, 0.9, 0.4))


func _panel_result() -> void:
	if won: _plabel("✔ VICTORY", 20, Color(0.5, 1, 1))
	else: _plabel("✖ DEFEATED", 20, Color(1, 0.5, 0.5))
	if _end_cause != "": _plabel(_end_cause, 14, Color(0.9, 0.95, 1.0))
	_plabel("Elapsed %s  ·  buildings %d/%d  ·  Cash %d vs rival %d  ·  town #%d" % [_fmt_time(_t), _player_nodes(), hosts.size(), int(cash[PLAYER]), int(cash[RIVAL]), town_seed], 14, Color(0.8, 0.9, 1.0))
	_btn("↻ Restart in a new town", _reset)


func _stage_line(i: int) -> String:
	var h: Dictionary = hosts[i]
	if int(h.owner) == NEUTRAL:
		return "security %d/%d · value ×%d · %d slots" % [int(h.bots), int(h.sec), int(h.value), int(h.slots)]
	return "%s · %d/%d bots · %d of %d slots working · value ×%d" % [STAGE_NAME[_stage(i)], int(h.bots), int(NODE_CAP), mini(_active_slots(i), (h.builds as Array).size()), int(h.slots), int(h.value)]


func _panel_inside() -> void:   # MICRO — the local view of one building of yours
	var i := _inside
	var h: Dictionary = hosts[i]
	_plabel("INSIDE  %s" % str(h.name), 18, Color(1, 0.9, 0.5))
	_plabel("⚠ The map keeps running. You can't command it from in here.", 12, Color(1, 0.82, 0.4))
	if _enter_left > 0.0:
		_plabel("Connecting… %.1f s" % _enter_left, 15, Color(0.8, 0.9, 1.0))
		_btn("← Leave (Esc)", _leave)
		return
	_plabel(_stage_line(i), 13, Color(0.82, 0.9, 1.0))
	var hin := int(_hostile_incoming(i))
	if hin > 0: _plabel("⚠ Under attack — %d hostile bots inbound." % hin, 13, Color(1, 0.6, 0.5))
	var builds: Array = h.builds
	var job: Dictionary = h.job
	for s in int(h.slots):
		if s < builds.size():
			var k := str(builds[s])
			var active: bool = s < _active_slots(i)
			_plabel("Slot %d: %s%s — %s" % [s + 1, BUILD_KINDS[k].name, "" if active else " (OFFLINE: too few bots)", BUILD_KINDS[k].desc], 12, Color(0.75, 0.95, 0.8) if active else Color(0.8, 0.7, 0.6))
		elif s == builds.size() and not job.is_empty():
			_plabel("Slot %d: building %s… %.1f s left (only while you stay inside)" % [s + 1, BUILD_KINDS[str(job.kind)].name, float(job.left)], 12, Color(1, 0.9, 0.5))
		else:
			_plabel("Slot %d: empty" % (s + 1), 12, Color(0.6, 0.7, 0.8))
	if not job.is_empty():
		_btn("✖ Cancel build", _cancel_job.bind(i))
	elif builds.size() < int(h.slots):
		_plabel("Build (each takes %.0f s of your attention):" % BUILD_TIME, 13, Color(0.9, 0.95, 1.0))
		for k in BUILD_KINDS.keys():
			_plabel("%s: %s" % [BUILD_KINDS[k].name, BUILD_KINDS[k].desc], 11, Color(0.7, 0.8, 0.9))
			_btn("+ Build %s" % BUILD_KINDS[k].name, _player_build.bind(i, str(k)))
	else:
		_plabel("All slots full. Demolish one to rebuild it:", 12, Color(0.82, 0.86, 0.96))
	for s in builds.size():
		_btn("✖ Demolish slot %d: %s" % [s + 1, BUILD_KINDS[str(builds[s])].name], _demolish.bind(i, s))
	_btn("← Leave building (Esc)", _leave)


func _panel_preview() -> void:   # ABOUT TO COMMIT
	var tgt := sel_target
	var atk := not _mine(tgt)
	var elig := 0; var excl := 0
	for s in sel.keys():
		if _link_kind(int(s), tgt) != "": elig += 1
		else: excl += 1
	_plabel("ORDER PREVIEW", 14, Color(1, 0.9, 0.5))
	_plabel("%s  →  %s (%s)" % [("⚔ ATTACK" if atk else "🛡 REINFORCE"), str(hosts[tgt].name), str(FACTION_NAME[int(hosts[tgt].owner)])],
		17, Color(1, 0.72, 0.6) if atk else Color(0.6, 1, 0.8))
	_plabel("From %d selected · %d can reach%s" % [sel.size(), elig, ("  ·  %d excluded (no route)" % excl) if excl > 0 else ""], 13)
	if atk:
		var regen := float(_count(tgt, "bot")) * PROD_RATE
		if int(hosts[tgt].owner) == NEUTRAL and float(hosts[tgt].bots) >= float(hosts[tgt].sec) - 0.01: regen = 0.0   # full security doesn't grow
		var dmg := 0.0
		for s in sel.keys():
			if _link_kind(int(s), tgt) != "": dmg += SEND_RATE * float(hosts[int(s)].rate) * (ATTACK_POWER / DEFEND_POWER)
		_plabel("Target: %s · regenerates up to +%.1f/s" % [_stage_line(tgt), float(_count(tgt, "bot")) * PROD_RATE], 12, Color(0.82, 0.9, 1.0))
		_plabel("Your streams: −%.1f/s · costs %.1f Intel/s  (reserve %d, +%d/s)" % [dmg, dmg * DEFEND_POWER / ATTACK_POWER, int(intel), int(_intel_rate())], 13, Color(0.82, 0.9, 1.0))
		var net := dmg - float(_count(tgt, "bot")) * PROD_RATE
		if net <= 0.001: _plabel("↔ Not enough to overcome its regeneration — add sources or raise rates.", 12, Color(1, 0.85, 0.5))
		else: _plabel("✔ Beats regeneration by %.1f/s → ≈ %d s after arrival, ≈ %d Intel." % [net, int(ceil(float(hosts[tgt].bots) / net)), int(ceil(float(hosts[tgt].bots) / net * dmg * DEFEND_POWER / ATTACK_POWER))], 12, Color(0.7, 1, 0.8))
		if intel < 1.0: _plabel("⚠ Out of Intel now — bots wait until Intel returns.", 12, Color(1, 0.82, 0.4))
	else:
		_plabel("Free. Adds to the building's bots (its health, and more working slots).", 12, Color(0.82, 0.9, 1.0))
	var already := []
	for i in _owned_feeders(tgt):
		if not sel.has(int(i)): already.append(int(i))
	if not already.is_empty(): _plabel("Already supplying (kept): %s" % _names(already), 12, Color(0.6, 0.92, 0.72))
	_btn(("⚔  START ATTACK on %s" if atk else "🛡  START REINFORCE %s") % str(hosts[tgt].name), _do_command, elig > 0)
	_btn("Cancel preview (Esc)", func(): sel_target = -1; _refresh_panel(); queue_redraw())


func _panel_selecting() -> void:
	var stock := 0.0; var running := 0
	for s in sel.keys():
		stock += float(hosts[int(s)].bots)
		if int(hosts[int(s)].assign) >= 0: running += 1
	if sel.size() == 1:
		var s0: int = int(sel.keys()[0])
		_plabel("SELECTED: %s" % str(hosts[s0].name), 17)
		_plabel(_stage_line(s0) + " · rate %d%%" % int(round(float(hosts[s0].rate) * 100.0)), 12, Color(0.82, 0.9, 1.0))
		_plabel("Inside: %s" % _build_names(hosts[s0].builds), 12, Color(0.75, 0.9, 0.8))
		var a := int(hosts[s0].assign)
		if a >= 0: _plabel("Supply: %s → %s  (%s)" % [("reinforce" if _mine(a) else "attack"), str(hosts[a].name), _src_state(s0)], 14, Color(0.6, 1, 0.8))
		elif _bot_target(s0) >= 0: _plabel("Supply: auto → rally %s  (%s)" % [str(hosts[rally].name), _src_state(s0)], 14, Color(0.6, 0.9, 0.8))
		else: _plabel("Supply: idle", 14, Color(0.7, 0.8, 0.9))
	else:
		_plabel("SELECTED: %d sources · %d bots" % [sel.size(), int(stock)], 17)
		if running > 0: _plabel("%d of them already supplying." % running, 13, Color(0.7, 0.85, 1.0))
	_plabel("▶ Pick a destination: click a building, or drag a line to it.", 14, Color(1, 0.9, 0.5))
	if running > 0: _btn("■ Stop supply (%d)" % running, _stop_supplying)
	_btn_row([["− rate 25%", _adjust_rate.bind(-0.25)], ["+ rate 25%", _adjust_rate.bind(0.25)]])
	if sel.size() == 1:
		var s1: int = int(sel.keys()[0])
		var into := _owned_feeders(s1)
		if not into.is_empty(): _btn("■ Stop all %d supply into %s" % [into.size(), str(hosts[s1].name)], _cancel_to.bind(s1))
		_btn("🏢 Enter building (%.0f s) — build inside" % ENTER_TIME, _enter.bind(s1))
		if rally == s1: _btn("⚑ Clear rally point", _set_rally.bind(-1))
		else: _btn("⚑ Set rally point here (idle buildings auto-supply it)", _set_rally.bind(s1))
	_btn("Clear selection (Esc)", _esc_btn)


func _panel_inspect() -> void:
	var h: Dictionary = hosts[_inspect]
	var fac := int(h.owner)
	_plabel("%s  ·  %s" % [str(h.name), str(FACTION_NAME[fac]).to_upper()], 17, Color(1, 0.72, 0.6) if fac == RIVAL else Color(0.8, 0.88, 1.0))
	_plabel(_stage_line(_inspect), 13, Color(0.82, 0.9, 1.0))
	_plabel("Inside: %s" % _build_names(h.builds), 12, Color(0.75, 0.9, 0.8))
	var yin := int(_incoming(_inspect, PLAYER)); var rin := int(_incoming(_inspect, RIVAL))
	_plabel("In transit toward it: %d yours · %d rival" % [yin, rin], 13, Color(0.7, 0.85, 1.0))
	var feeders := _owned_feeders(_inspect)
	if feeders.is_empty():
		_plabel("None of your sources is supplying it.", 13, Color(0.7, 0.8, 0.9))
	else:
		var sending := []
		for i in feeders:
			if _src_state(int(i)) == "sending": sending.append(int(i))
		_plabel("Your supply: %d source(s) — %d sending, %d waiting" % [feeders.size(), sending.size(), feeders.size() - sending.size()], 13, Color(0.82, 0.95, 0.9))
		_panel_attack_diag(_inspect, feeders, sending)
		_btn("Select these sources", _select_contributors.bind(feeders))
		_btn("■ Stop all supply into it", _cancel_to.bind(_inspect))
		var shown := 0
		for i in feeders:
			if shown >= 6: break
			_plabel("   • %s: %s" % [str(hosts[int(i)].name), _src_state(int(i))], 12, Color(0.72, 0.86, 1.0)); shown += 1
	_plabel("Click a building of yours to command it. Esc clears.", 12, Color(0.6, 0.7, 0.8))


# cause → action for an attack that isn't finishing. Regeneration counts the target's OWN outgoing
# stream as a drain, so a building that is attacking someone reads as the softer target it really is.
func _panel_attack_diag(t: int, feeders: Array, sending: Array) -> void:
	if sending.is_empty():
		var reason := "idle"
		for i in feeders:
			var st := _src_state(int(i))
			if st != "idle" and st != "sending": reason = st; break
		match reason:
			"no Intel": _plabel("⛔ Waiting for Intel — build an Intel harvester or stop another attack.", 12, Color(1, 0.82, 0.4))
			"no bots": _plabel("⛔ Waiting for bots — let the source regenerate or reinforce it.", 12, Color(1, 0.82, 0.4))
			"no route": _plabel("⛔ No route — capture a building bordering it, then re-order.", 12, Color(1, 0.82, 0.4))
			"link busy": _plabel("⛔ Link at capacity — lower rates, route elsewhere, or wait.", 12, Color(1, 0.82, 0.4))
			_: _plabel("⛔ Supply is paused.", 12, Color(1, 0.82, 0.4))
		return
	var regen := float(_count(t, "bot")) * PROD_RATE
	var drain := 0.0
	if _bot_target(t) >= 0 and _next_depart.has(t): drain = SEND_RATE * float(hosts[t].rate)
	var dmg := 0.0
	for s in sending: dmg += SEND_RATE * float(hosts[int(s)].rate) * (ATTACK_POWER / DEFEND_POWER)
	var net := regen - drain
	if drain > 0.0: _plabel("It is streaming bots out itself (−%.1f/s): a softer target while it does." % drain, 12, Color(0.8, 0.95, 1.0))
	if dmg <= net + 0.001: _plabel("↔ Not overcoming regeneration (−%.1f/s vs +%.1f/s) — add another source." % [dmg, net], 12, Color(1, 0.85, 0.5))
	else: _plabel("✔ Reducing defenders (−%.1f/s net) — bots still need to arrive." % (dmg - net), 12, Color(0.7, 1, 0.8))


func _panel_idle() -> void:
	_plabel("OBJECTIVE: bank %d Cash before the RIVAL botnet does." % int(CASH_GOAL), 15, Color(0.92, 0.96, 1.0))
	_plabel("Capture town buildings, build inside them, and route their Cash home to YOUR RIG. Downtown is rich but well defended; the rim is poor and soft. Lose every building and you are out.", 12, Color(0.85, 0.9, 1.0))
	_plabel("① Click a building of yours to select it (Shift-click or drag a box for several).", 13)
	_plabel("② Click a target, or drag a line to it — connected buildings light up.", 13, Color(0.8, 0.86, 0.96))
	_plabel("③ Press START ATTACK / REINFORCE. Bots act only when they ARRIVE.", 13, Color(0.8, 0.86, 0.96))
	_plabel("🏢 Enter a building you own to build inside it: Bot farms defend, Intel harvesters fuel attacks, Darknet markets make Cash (× the building's value). Time keeps running in there.", 12, Color(0.8, 0.9, 0.85))
	_plabel("⚑ A rally point turns every idle building into a supplier. Links carry %d packets/s each — bots and Cash share them." % LINK_CAP, 12, Color(0.8, 0.9, 0.85))
	_plabel("Right-click or Esc clears · Space pauses · town #%d" % town_seed, 12, Color(0.6, 0.7, 0.8))


func _hud_text() -> String:
	var mybots := 0.0
	for h in hosts:
		if int(h.owner) == PLAYER: mybots += float(h.bots)
	var s := "YOU: %d buildings · %d bots · Intel %d/%d (+%d/s · −%.1f/s) · CASH %d/%d (+%.1f/s)     RIVAL: %d buildings · Cash %d (+%.1f/s)     %s · town #%d" % [
		_player_nodes(), int(mybots), int(intel), int(_intel_cap()), int(_intel_rate()), _attack_demand(),
		int(cash[PLAYER]), int(CASH_GOAL), _cash_rate(PLAYER), _faction_nodes(RIVAL), int(cash[RIVAL]), _cash_rate(RIVAL), _fmt_time(_t), town_seed]
	if rally >= 0: s += "   ·   ⚑ rally: %s" % str(hosts[rally].name)
	if _inside >= 0: s += "   ·   INSIDE %s (map running)" % str(hosts[_inside].name)
	return s


# ============================================================ DRAW
func _aim_target() -> int:
	if sel_target >= 0: return sel_target
	if _dragging and _drag_from >= 0:
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and hov != _drag_from: return hov
	return -1


func _aim_sources() -> Array:
	if _dragging and _drag_from >= 0 and not sel.has(_drag_from): return [_drag_from]
	return sel.keys()


func _lk(a: int, b: int) -> String: return "%d_%d" % [mini(a, b), maxi(a, b)]


func _build_focus(aim: int, fnodes: Dictionary, flinks: Dictionary) -> void:
	fnodes[aim] = true
	for nb in hosts[aim].links:
		fnodes[int(nb)] = true; flinks[_lk(aim, int(nb))] = true
	for s in _aim_sources():
		if int(s) == aim: continue
		var rt := _route(int(s), aim)
		for k in rt.size(): fnodes[int(rt[k])] = true
		for k in range(rt.size() - 1): flinks[_lk(int(rt[k]), int(rt[k + 1]))] = true


func _fill_of(i: int) -> Color:
	var fac := int(hosts[i].owner)
	if fac == PLAYER: return Color(0.25, 0.85, 0.45)
	if fac == RIVAL: return Color(0.8, 0.3, 0.33)
	return Color(0.35, 0.45, 0.6) if not bool(hosts[i].hub) else Color(0.2, 0.75, 0.9)


func _draw() -> void:
	var f := get_theme_default_font()
	var aim := _aim_target()
	var focus_on := aim >= 0 and _inside < 0
	var fnodes := {}; var flinks := {}
	if focus_on: _build_focus(aim, fnodes, flinks)
	for i in hosts.size():   # streets, tinted by who holds both ends; amber when at capacity
		for j in hosts[i].links:
			if j < i: continue
			var oi := int(hosts[i].owner); var oj := int(hosts[j].owner)
			var lcol := Color(0.35, 0.5, 0.7, 0.18); var w := 1.0
			if oi == PLAYER and oj == PLAYER: lcol = Color(0.3, 1, 0.55, 0.4); w = 2.0
			elif oi == RIVAL and oj == RIVAL: lcol = Color(1, 0.4, 0.4, 0.35); w = 2.0
			if _link_busy(i, int(j)): lcol = Color(1, 0.75, 0.3, 0.7); w = 3.0
			if focus_on and not flinks.has(_lk(i, int(j))): lcol.a *= 0.22
			draw_line(hosts[i].pos, hosts[int(j)].pos, lcol, w, true)
	for i in hosts.size():   # committed supply routes (solid); auto-supply to the rally thin and dim
		var d := _bot_target(i)
		if d < 0: continue
		var explicit: bool = int(hosts[i].assign) >= 0
		if not explicit and not _next_depart.has(i): continue
		var is_threat: bool = _mine(d) and not _mine(i)
		var dimmed: bool = focus_on and not is_threat and not (fnodes.has(i) and fnodes.has(d))
		_draw_route_line(_route(i, d), i, d, dimmed or not explicit)
	for fl in flights:   # packets: yours = circle, rival = square, Cash = yellow diamond
		var pp := _packet_pos(fl, _t)
		var endn := int((fl.route as Array)[(fl.route as Array).size() - 1])
		var threat: bool = int(fl.owner) != PLAYER and _mine(endn)
		var ba: float = 1.0 if (not focus_on or fnodes.has(endn) or threat) else 0.3
		if str(fl.kind) == "cash":
			var c := Color(1, 0.9, 0.3, ba) if int(fl.owner) == PLAYER else Color(1, 0.7, 0.45, ba)
			draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -4), pp + Vector2(4, 0), pp + Vector2(0, 4), pp + Vector2(-4, 0)]), c)
		elif int(fl.owner) == PLAYER: draw_circle(pp, 3.5, Color(0.5, 1, 0.7, ba))
		else: draw_rect(Rect2(pp - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), Color(1, 0.45, 0.4, ba), true)
	for i in hosts.size():
		var nthreat: bool = _mine(i) and _hostile_incoming(i) > 0.0
		var na: float = 1.0 if (not focus_on or fnodes.has(i) or nthreat) else 0.22
		_draw_node(f, i, na, i == aim)
	if focus_on:
		for s in _aim_sources():
			if _link_kind(int(s), aim) != "": _draw_dashed(_route(int(s), aim), Color(1, 0.95, 0.55, 0.95), 3.0)
		var act: String = "🛡 reinforce %s" if _mine(aim) else "⚔ attack %s"
		draw_string(f, (hosts[aim].pos as Vector2) + Vector2(-_r(aim), -_r(aim) - 24.0), act % str(hosts[aim].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.92, 0.5))
	elif not sel.is_empty() and _inside < 0:
		var src_keys: Array = sel.keys()
		for i in hosts.size():
			var ok := false
			for s in src_keys:
				if _link_kind(int(s), i) != "": ok = true; break
			if ok: draw_arc(hosts[i].pos, _r(i) + 7.0, 0.0, TAU, 32, Color(1, 0.8, 0.4, 0.55), 2.0, true)
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and not sel.has(hov):
			var elig := 0
			for s in src_keys:
				if _link_kind(int(s), hov) != "": _draw_dashed(_route(int(s), hov)); elig += 1
			if elig > 0:
				draw_string(f, (hosts[hov].pos as Vector2) + Vector2(-_r(hov), -_r(hov) - 22.0), "click or drag here to target %s" % str(hosts[hov].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.5))
	if _dragging and _drag_from >= 0:
		var to := get_local_mouse_position()
		var hv := _host_at(to)
		if hv >= 0 and hv != _drag_from: to = hosts[hv].pos
		draw_line(hosts[_drag_from].pos, to, Color(1, 0.95, 0.55, 0.95), 3.0, true)
		draw_circle(to, 4.0, Color(1, 0.95, 0.55, 0.95))
	if _boxing:
		var r := Rect2(_box_start, get_local_mouse_position() - _box_start).abs()
		draw_rect(r, Color(0.6, 1, 1, 0.08), true)
		draw_rect(r, Color(0.6, 1, 1, 0.6), false, 1.0, true)
	var sz := get_viewport_rect().size
	if _inside >= 0:   # MICRO: the map stays visible and alive behind a veil, but it is not yours to command
		draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x - PANEL_W - 24.0, sz.y)), Color(0, 0, 0, 0.35), true)
		var p: Vector2 = hosts[_inside].pos
		draw_arc(p, _r(_inside) + 12.0, 0.0, TAU, 40, Color(1, 0.9, 0.5, 0.95), 3.0, true)
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
	draw_circle(p, rr, fill)
	if bool(hosts[i].rig): draw_arc(p, rr - 4.0, 0.0, TAU, 28, Color(1, 1, 1, 0.8 * a), 2.0, true)   # a rig = Cash sink
	if _hostile_incoming(i) > 0.0 and int(hosts[i].owner) != NEUTRAL:
		draw_arc(p, rr + 3.0, 0.0, TAU, 28, Color(1, 0.4, 0.35, 0.95), 2.5, true)   # under attack → red ring
	if sel.has(i): draw_arc(p, rr + 6.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95 * a), 3.0, true)
	if i == _inspect: draw_arc(p, rr + 8.0, 0.0, TAU, 32, Color(1, 0.9, 0.3, a), 2.0, true)
	if is_aim: draw_arc(p, rr + 9.0, 0.0, TAU, 32, Color(1, 0.9, 0.3), 3.0, true)
	if i == rally: draw_string(f, p + Vector2(rr + 4.0, 5.0), "⚑ RALLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.5, a))
	var fr: float = clampf(float(hosts[i].bots) / NODE_CAP, 0.0, 1.0)
	draw_rect(Rect2(p.x - rr, p.y + rr + 5.0, rr * 2.0, 5.0), Color(0.1, 0.12, 0.16, a), true)
	var bar := Color(0.4, 1, 0.6, a) if _mine(i) else (Color(1, 0.5, 0.5, a) if int(hosts[i].owner) == RIVAL else Color(0.6, 0.7, 0.9, a))
	draw_rect(Rect2(p.x - rr, p.y + rr + 5.0, rr * 2.0 * fr, 5.0), bar, true)
	draw_string(f, p + Vector2(-9, 5), "%d" % int(round(float(hosts[i].bots))), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.05, 0.08, 0.1, a))
	var vmarks := ""
	for k in int(hosts[i].value): vmarks += "$"
	draw_string(f, p + Vector2(-rr - 2.0, -rr - 7.0), str(hosts[i].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.92, 1.0, a))
	draw_string(f, p + Vector2(rr + 3.0, -rr + 2.0), vmarks, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.4, 0.9 * a))
	var bi := ""   # build badges: B bot farm · I intel · $ cash · C vault — lowercase when offline
	var act := _active_slots(i)
	for k in (hosts[i].builds as Array).size():
		var sh: String = str(BUILD_KINDS[str(hosts[i].builds[k])].short)
		bi += sh if k < act else sh.to_lower()
	if not (hosts[i].job as Dictionary).is_empty(): bi += "…"
	if bi != "" and int(hosts[i].owner) != NEUTRAL: draw_string(f, p + Vector2(-rr, rr + 22.0), bi, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.95, 0.6, 0.95 * a))
	var st := _stage(i)
	var sub := ""
	if st > 0 and int(hosts[i].owner) != NEUTRAL: sub = STAGE_NAME[st]
	if _mine(i) and float(hosts[i].rate) < 1.0: sub += ("  " if sub != "" else "") + "%d%%" % int(round(float(hosts[i].rate) * 100.0))
	if _mine(i) and float(hosts[i].bots) >= NODE_CAP - 0.5 and _incoming(i, PLAYER) > 0.0: sub += ("  " if sub != "" else "") + "FULL"
	if sub != "": draw_string(f, p + Vector2(rr + 3.0, rr + 10.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.85, 0.4, a))


func _draw_dashed(rt: Array, col := Color(1, 0.9, 0.5, 0.9), w := 2.0) -> void:   # dashed = a PREVIEW
	for k in range(rt.size() - 1):
		var a: Vector2 = hosts[int(rt[k])].pos
		var b: Vector2 = hosts[int(rt[k + 1])].pos
		var ln := a.distance_to(b)
		var dir := (b - a) / maxf(ln, 0.001)
		var d := 0.0
		while d < ln:
			draw_line(a + dir * d, a + dir * minf(d + 9.0, ln), col, w, true)
			d += 15.0


# colour by the SOURCE's faction, shape by kind (reinforce = diamond, attack = arrow)
func _draw_route_line(rt: Array, src: int, tgt: int, dim := false) -> void:
	if rt.size() < 2: return
	var from_player: bool = _mine(src)
	var reinforce: bool = int(hosts[src].owner) == int(hosts[tgt].owner)
	var col: Color
	if from_player and not reinforce: col = Color(1, 0.85, 0.35)
	elif from_player and reinforce: col = Color(0.4, 1, 0.7)
	elif not from_player and not reinforce: col = Color(1, 0.4, 0.35) if _mine(tgt) else Color(0.95, 0.55, 0.4)
	else: col = Color(0.95, 0.55, 0.4)
	var fade := 0.3 if dim else 1.0
	var pts := PackedVector2Array()
	for idx in rt: pts.append(hosts[int(idx)].pos)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.28 * fade), 6.0, true)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.9 * fade), 2.5, true)
	var a: Vector2 = hosts[int(rt[rt.size() - 2])].pos
	var b: Vector2 = hosts[int(rt[rt.size() - 1])].pos
	var dir: Vector2 = (b - a).normalized()
	var tip: Vector2 = b - dir * (_r(tgt) + 3.0)
	var perp := Vector2(-dir.y, dir.x)
	var c := Color(col.r, col.g, col.b, 0.95 * fade)
	if reinforce:
		var ctr := tip - dir * 7.0
		draw_colored_polygon(PackedVector2Array([ctr + dir * 7.0, ctr + perp * 6.0, ctr - dir * 7.0, ctr - perp * 6.0]), c)
	else:
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 14.0 + perp * 8.0, tip - dir * 14.0 - perp * 8.0]), c)
