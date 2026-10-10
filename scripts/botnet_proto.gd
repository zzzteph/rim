extends Control
## PROTOTYPE v2 — the botnet conquest loop, built to design/BOTNET_ATTACK_DESIGN.md (the PROPOSED model).
## Standalone sandbox; NOT wired into the real city.
##
## You ASSIGN owned buildings to attack a target; the assignment PERSISTS and the source's production feeds
## the operation automatically (demand-gated, with reinforcements) while the global clock runs. Bots are the
## firepower (1 dmg/s each, 10 dmg of allowance); Intel is the fuel (0.2/active bot/s); damage needs both.
## Pick an internal objective (Direct vs Utility-first). Net Watch warns, then strikes an owned building —
## resident bots defend. Capture the HUB → CITY OVERLOAD. Lose your last building → defeat. SPACE pauses.

# ---- tunables (see design/BOTNET_ATTACK_DESIGN.md §10; all provisional) ----
const GRID_COLS := 5
const GRID_ROWS := 3
const BOT_START := 10.0
const BOT_RATE := 1.0 / 5.0        # +1 bot / 5s per war building
const BOT_CAP := 80.0
const WAR_COST := 25.0             # Intel to stand up a war building
const INTEL_START := 15.0
const INTEL_PER_HOST := 0.6        # Intel/sec per owned host
const DMG_RATE := 1.0              # defence removed per active bot per second
const FUEL_RATE := 0.2             # Intel burned per active bot per second
const BOT_CAPACITY := 10.0         # damage one bot can deal before it is spent (10s allowance)
const BASE_RESIST := 6.0           # every owned building's base defensive resistance
const UTIL_ACT := 3.0              # seconds to activate a captured utility node
const UTIL_RED := 20.0             # CORE defence removed once the utility is activated
# Net Watch
const NW_FIRST := 50.0             # first warned attack
const NW_CADENCE := 45.0           # time between subsequent attacks
const NW_STR := 12.0               # base strength
const NW_GROW := 4.0               # +strength per attack
# geometry
const R := 20.0

var _t := 0.0
var paused := false
var won := false
var lost := false
var _msg := ""
var _msg_t := 0.0

# global ------------------------------------------------------
var hosts := []        # {pos,grid,ring,name,links:[i],owned,war,hub,bots:float,assign:int}
var hub := -1
var _intel_store := INTEL_START

# operations --------------------------------------------------
var ops := {}          # target host index -> operation dict
var pend_obj := "direct"

# net watch ---------------------------------------------------
var nw := {}           # {target:int, eta:float, str:float} or {}
var nw_count := 0

# selection / ui ----------------------------------------------
var sel_sources := {}   # set of owned war-host indices chosen to run the next attack (multi-select)
var sel_build := -1     # owned host with no war building, selected to build on
var sel_target := -1
var hud: Label
var panel: Panel
var panel_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_gen()
	hud = Label.new(); hud.position = Vector2(20, 12)
	hud.add_theme_font_size_override("font_size", 18); add_child(hud)
	panel = Panel.new(); panel.size = Vector2(400, 232); add_child(panel)
	panel_box = VBoxContainer.new(); panel_box.position = Vector2(14, 12)
	panel_box.custom_minimum_size = Vector2(372, 0); panel.add_child(panel_box)
	panel.position = Vector2(16, get_viewport_rect().size.y - panel.size.y - 14)
	_schedule_netwatch(true)
	_refresh_panel(); set_process(true)


# ============================================================ GENERATION
func _gen() -> void:
	var sz := get_viewport_rect().size
	hosts = []; hub = -1
	var ax := 170.0; var ay := 96.0
	var aw := sz.x - 340.0; var ah := sz.y - 420.0
	var hc := Vector2i(GRID_COLS / 2, GRID_ROWS / 2)
	var cell := {}
	for gy in GRID_ROWS:
		for gx in GRID_COLS:
			var p := Vector2(ax + aw * (float(gx) / float(GRID_COLS - 1)), ay + ah * (float(gy) / float(GRID_ROWS - 1)))
			var ring: int = maxi(absi(gx - hc.x), absi(gy - hc.y))
			var is_hub: bool = gx == hc.x and gy == hc.y
			cell[Vector2i(gx, gy)] = hosts.size()
			if is_hub: hub = hosts.size()
			hosts.append({"pos": p, "grid": Vector2i(gx, gy), "ring": ring, "hub": is_hub,
				"name": "CENTRAL HUB" if is_hub else "Host %d" % hosts.size(),
				"links": [], "owned": false, "war": false, "bots": 0.0, "assign": -1})
	for gy in GRID_ROWS:
		for gx in GRID_COLS:
			var a: int = cell[Vector2i(gx, gy)]
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = Vector2i(gx, gy) + d
				if cell.has(nb): _link(a, cell[nb])
	# §12 slice: start with TWO owned source buildings in a corner
	var s0: int = cell[Vector2i(0, 0)]
	var s1: int = cell[Vector2i(0, 1)]
	for s in [s0, s1]:
		hosts[s].owned = true; hosts[s].war = true; hosts[s].bots = BOT_START
	hosts[s0].name = "RIG A"; hosts[s1].name = "RIG B"


func _link(a: int, b: int) -> void:
	if a == b: return
	if not (hosts[a].links as Array).has(b): hosts[a].links.append(b)
	if not (hosts[b].links as Array).has(a): hosts[b].links.append(a)


func _owned_component(start: int) -> Dictionary:
	var seen := {start: true}; var st := [start]
	while not st.is_empty():
		var c: int = st.pop_back()
		for o in hosts[c].links:
			if bool(hosts[o].owned) and not seen.has(o): seen[o] = true; st.append(o)
	return seen


func _legal_target(t: int) -> bool:   # enemy host bordering your territory
	if t < 0 or bool(hosts[t].owned): return false
	for o in hosts[t].links:
		if bool(hosts[o].owned): return true
	return false


func _source_ok(src: int, t: int) -> bool:   # owned war-host with an owned path to an owned neighbour of t
	if src < 0 or not (bool(hosts[src].owned) and bool(hosts[src].war)): return false
	if not _legal_target(t): return false
	for o in hosts[t].links:
		if bool(hosts[o].owned) and _owned_component(o).has(src): return true
	return false


# ============================================================ OPERATIONS
func _make_op(t: int, objective: String) -> Dictionary:
	# internal net: entry → required → CORE, with a utility side-node. Test fixtures per §6 (HUB scaled up).
	var big: bool = bool(hosts[t].hub)
	var req := 40.0 if big else 22.0
	var util := 16.0 if big else 10.0
	var core := 160.0 if big else 70.0
	var nodes := [
		{"name": "Firewall", "kind": "entry", "def": 0.0, "defmax": 0.0, "controlled": true},
		{"name": "Required Node", "kind": "required", "def": req, "defmax": req, "controlled": false},
		{"name": "Utility Node", "kind": "utility", "def": util, "defmax": util, "controlled": false},
		{"name": "CORE MAINFRAME", "kind": "core", "def": core, "defmax": core, "controlled": false},
	]
	var seq := [1, 3] if objective == "direct" else [2, 1, 3]   # utility-first captures the utility, then required, then core
	return {"target": t, "objective": objective, "nodes": nodes, "seq": seq, "cur": 0,
		"abots": 0.0, "acap": 0.0, "activating": 0.0, "util_applied": false, "blocked": false, "waiting": false}


func _remaining_req(op: Dictionary) -> float:
	var r := 0.0
	for idx in range(int(op.cur), (op.seq as Array).size()):
		r += float((op.nodes[op.seq[idx]] as Dictionary).def)
	if str(op.objective) == "utility" and not bool(op.util_applied): r -= UTIL_RED   # CORE will drop
	return maxf(0.0, r)


func _capture_host(t: int) -> void:
	hosts[t].owned = true; hosts[t].war = false; hosts[t].bots = 0.0; hosts[t].assign = -1
	for i in hosts.size():
		if int(hosts[i].assign) == t: hosts[i].assign = -1   # clear assignments that pointed here
	ops.erase(t)
	_flash("Captured %s — core cracked" % str(hosts[t].name))
	if t == hub: won = true


# ============================================================ GLOBAL CLOCK
func _process(dt: float) -> void:
	_t += dt
	if _msg_t > 0.0: _msg_t -= dt
	if not paused and not won and not lost:
		for i in hosts.size():   # production + resident accumulation
			if bool(hosts[i].owned) and bool(hosts[i].war):
				hosts[i].bots = minf(BOT_CAP, float(hosts[i].bots) + BOT_RATE * dt)
		_intel_set(_intel() + _intel_income() * dt)
		_tick_netwatch(dt)
		for t in ops.keys():
			if ops.has(t): _tick_op(ops[t], dt)
		var owned := 0
		for h in hosts:
			if bool(h.owned): owned += 1
		if owned == 0: lost = true
	hud.text = _hud_text()
	queue_redraw()


func _tick_op(op: Dictionary, dt: float) -> void:
	# validity: all sources gone AND no active bots left → nothing to do (stays, awaiting reassignment)
	op.blocked = not _has_source(int(op.target))
	# utility activation phase (no firing while activating)
	if float(op.activating) > 0.0:
		op.activating = float(op.activating) - dt
		if float(op.activating) <= 0.0:
			var ci := _node_of(op, "core")
			if ci >= 0: (op.nodes[ci] as Dictionary).def = maxf(0.0, float((op.nodes[ci] as Dictionary).def) - UTIL_RED)
			op.util_applied = true
		return
	_dispatch(op)
	if int(op.cur) >= (op.seq as Array).size(): return
	var node: Dictionary = op.nodes[op.seq[int(op.cur)]]
	op.waiting = false
	if float(op.abots) <= 0.0 or float(op.acap) <= 0.0:
		op.waiting = true   # waiting for production / reinforcement
		return
	var want := float(op.abots)
	var fuel_bots := _intel() / (FUEL_RATE * dt) if dt > 0.0 else want
	var fire := minf(want, fuel_bots)
	if fire < want - 0.001: op.waiting = true   # throttled by fuel (§5.1)
	var dmg := minf(minf(fire * DMG_RATE * dt, float(op.acap)), float(node.def))
	node.def = float(node.def) - dmg
	op.acap = float(op.acap) - dmg
	_intel_set(_intel() - dmg * FUEL_RATE)
	if float(op.acap) <= 0.001: op.abots = 0.0; op.acap = 0.0   # committed bots spent
	if float(node.def) <= 0.0:
		node.controlled = true
		if str(node.kind) == "core":
			_capture_host(int(op.target)); return
		if str(node.kind) == "utility" and str(op.objective) == "utility" and not bool(op.util_applied):
			op.activating = UTIL_ACT
		op.cur = int(op.cur) + 1


func _node_of(op: Dictionary, kind: String) -> int:
	for i in (op.nodes as Array).size():
		if str((op.nodes[i] as Dictionary).kind) == kind: return i
	return -1


func _has_source(t: int) -> bool:
	for i in hosts.size():
		if bool(hosts[i].owned) and bool(hosts[i].war) and int(hosts[i].assign) == t: return true
	return false


# demand-gated dispatch: send only enough resident bots to cover the operation's remaining capacity need,
# and only when it can accept + fuel them (§4.1). Dispatched bots are committed one-way.
func _dispatch(op: Dictionary) -> void:
	if str(op.objective) == "" or bool(op.blocked): return
	if _intel() <= 0.0: return                       # no fuel → keep bots at their sources (§5.1)
	var need := _remaining_req(op) - float(op.acap)
	if need <= 0.0: return
	for i in hosts.size():
		if need <= 0.0: break
		if not (bool(hosts[i].owned) and bool(hosts[i].war)): continue
		if int(hosts[i].assign) != int(op.target) or float(hosts[i].bots) <= 0.0: continue
		var send := minf(float(hosts[i].bots), need / BOT_CAPACITY)
		hosts[i].bots = float(hosts[i].bots) - send
		op.abots = float(op.abots) + send
		op.acap = float(op.acap) + send * BOT_CAPACITY
		need -= send * BOT_CAPACITY


# ============================================================ NET WATCH
func _schedule_netwatch(first: bool) -> void:
	var owned_war := []
	for i in hosts.size():
		if bool(hosts[i].owned) and bool(hosts[i].war): owned_war.append(i)
	if owned_war.is_empty(): nw = {}; return
	var front := []
	for i in owned_war:
		for o in hosts[i].links:
			if not bool(hosts[o].owned): front.append(i); break
	var pool: Array = front if not front.is_empty() else owned_war
	var tgt: int = pool[nw_count % pool.size()]
	nw = {"target": tgt, "eta": (NW_FIRST if first else NW_CADENCE), "str": NW_STR + NW_GROW * float(nw_count)}


func _tick_netwatch(dt: float) -> void:
	if nw.is_empty(): return
	if not bool(hosts[int(nw.target)].owned):   # target no longer ours → retarget
		nw_count += 1; _schedule_netwatch(false); return
	nw.eta = float(nw.eta) - dt
	if float(nw.eta) <= 0.0: _resolve_netwatch()


func _resolve_netwatch() -> void:
	var t: int = int(nw.target)
	var defenders := float(hosts[t].bots) + BASE_RESIST
	if defenders >= float(nw.str):
		hosts[t].bots = maxf(0.0, float(hosts[t].bots) - float(nw.str))
		_flash("Net Watch repelled at %s (held %d)" % [str(hosts[t].name), int(hosts[t].bots)])
	else:
		hosts[t].owned = false; hosts[t].war = false; hosts[t].bots = 0.0; hosts[t].assign = -1
		for i in hosts.size():
			if int(hosts[i].assign) == t: hosts[i].assign = -1
		_flash("NET WATCH RETOOK %s!" % str(hosts[t].name))
	nw_count += 1
	_schedule_netwatch(false)


# ============================================================ MONEY
func _intel() -> float: return _intel_store
func _intel_set(v: float) -> void: _intel_store = maxf(0.0, v)
func _intel_income() -> float:
	var n := 0
	for h in hosts:
		if bool(h.owned): n += 1
	return float(n) * INTEL_PER_HOST


# ============================================================ INPUT
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		paused = not paused; _refresh_panel(); queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	var hit := _host_at(event.position)
	if hit < 0:
		sel_sources = {}; sel_build = -1; sel_target = -1
	elif bool(hosts[hit].owned) and bool(hosts[hit].war):
		if sel_sources.has(hit): sel_sources.erase(hit)   # toggle this building into the attack force
		else: sel_sources[hit] = true
		sel_build = -1
	elif bool(hosts[hit].owned):
		sel_build = hit; sel_sources = {}; sel_target = -1   # owned host with no war building → build here
	elif _legal_target(hit):
		sel_target = hit
	_refresh_panel(); queue_redraw()


func _host_at(p: Vector2) -> int:
	for i in hosts.size():
		if (hosts[i].pos as Vector2).distance_to(p) <= R + 5.0: return i
	return -1


# the route an attack actually runs along: BFS over OWNED hosts from the source to an owned host bordering
# the target, then the final hop to the target. [] if there is no owned path (so attacks can't come "from
# anywhere" — only through your network).
func _route(src: int, t: int) -> Array:
	var prev := {src: src}; var q := [src]; var head := 0; var hit := -1
	while head < q.size():
		var c: int = q[head]; head += 1
		for o in hosts[c].links:
			if o == t: hit = c; break
		if hit >= 0: break
		for o in hosts[c].links:
			if bool(hosts[o].owned) and not prev.has(o): prev[o] = c; q.append(o)
	if hit < 0: return []
	var p := [hit]
	while int(p[p.size() - 1]) != src: p.append(prev[p[p.size() - 1]])
	p.reverse(); p.append(t)
	return p


# ============================================================ ACTIONS
# launch: every selected building that can reach the target is assigned to attack it (assignment persists)
func _attack() -> void:
	if sel_target < 0 or sel_sources.is_empty(): return
	var n := 0
	for s in sel_sources.keys():
		if _source_ok(int(s), sel_target):
			if not ops.has(sel_target): ops[sel_target] = _make_op(sel_target, pend_obj)
			hosts[int(s)].assign = sel_target; n += 1
	if n > 0:
		_flash("Attacking %s with %d building(s)" % [str(hosts[sel_target].name), n])
		sel_sources = {}
	_refresh_panel()


# DEFEND = hold these buildings at home. Bots don't move between buildings (locked design), so "defend" means
# keeping a building's resident bots home to repel Net Watch there, instead of spending them on an attack.
func _defend() -> void:
	for s in sel_sources.keys(): hosts[int(s)].assign = -1
	_flash("Holding %d building(s) for defense" % sel_sources.size()); sel_sources = {}; _refresh_panel()


func _clear_sel() -> void:
	sel_sources = {}; sel_build = -1; _refresh_panel()


func _retreat(t: int) -> void:
	if ops.has(t):
		for i in hosts.size():
			if int(hosts[i].assign) == t: hosts[i].assign = -1
		ops.erase(t); _flash("Retreated — dispatched bots lost")   # internal damage resets (baseline)
	_refresh_panel()


func _build_war() -> void:
	if sel_build < 0 or bool(hosts[sel_build].war) or not bool(hosts[sel_build].owned) or _intel() < WAR_COST: return
	_intel_set(_intel() - WAR_COST); hosts[sel_build].war = true; hosts[sel_build].bots = BOT_START
	_refresh_panel()


func _reset() -> void:
	_intel_store = INTEL_START; ops = {}; nw = {}; nw_count = 0; _t = 0.0
	sel_sources = {}; sel_build = -1; sel_target = -1; won = false; lost = false; paused = false
	_gen(); _schedule_netwatch(true); _refresh_panel()


func _flash(m: String) -> void: _msg = m; _msg_t = 4.0


# ============================================================ UI PANEL
func _plabel(txt: String, sz := 15, col := Color(0.85, 0.9, 1.0)) -> void:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(372, 0)
	panel_box.add_child(l)


func _btn(txt: String, cb: Callable, enabled := true) -> void:
	var b := Button.new(); b.text = txt; b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled; b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(cb); panel_box.add_child(b)


func _refresh_panel() -> void:
	for c in panel_box.get_children(): c.queue_free()
	if won:
		_plabel("CITY OVERLOAD — the net is yours.", 20, Color(0.5, 1, 1)); _btn("Reset", _reset); return
	if lost:
		_plabel("DEFEATED — Net Watch took your last building.", 20, Color(1, 0.5, 0.5)); _btn("Reset", _reset); return
	if not sel_sources.is_empty():
		var nb := 0.0
		for s in sel_sources.keys(): nb += float(hosts[int(s)].bots)
		_plabel("ATTACK FORCE:  %d building(s)  ·  %d bots ready (consumed on attack)" % [sel_sources.size(), int(nb)], 18)
		if sel_target >= 0:
			var elig := 0
			for s in sel_sources.keys():
				if _source_ok(int(s), sel_target): elig += 1
			_plabel("Target: %s   ·   %d of %d can reach it" % [str(hosts[sel_target].name), elig, sel_sources.size()], 15, Color(1, 0.9, 0.5))
			if not ops.has(sel_target):
				var hb := HBoxContainer.new(); panel_box.add_child(hb)
				var bd := Button.new(); bd.text = ("◉ Direct" if pend_obj == "direct" else "Direct"); bd.focus_mode = Control.FOCUS_NONE
				bd.pressed.connect(func(): pend_obj = "direct"; _refresh_panel())
				var bu := Button.new(); bu.text = ("◉ Utility first" if pend_obj == "utility" else "Utility first"); bu.focus_mode = Control.FOCUS_NONE
				bu.pressed.connect(func(): pend_obj = "utility"; _refresh_panel())
				hb.add_child(bd); hb.add_child(bu)
			else:
				_plabel("(joins the existing operation — objective already set)", 13, Color(0.6, 0.7, 0.8))
			_btn("⚔  ATTACK %s" % str(hosts[sel_target].name), _attack, elig > 0)
		else:
			_plabel("Now click an enemy host bordering your territory to attack it.", 13, Color(0.6, 0.7, 0.8))
		_btn("🛡  Defend — hold these at home", _defend)
		_btn("Clear selection", _clear_sel)
	elif sel_build >= 0:
		_plabel("%s" % str(hosts[sel_build].name), 18)
		_plabel("No war building here.")
		_btn("Build War Building  (%d Intel)" % int(WAR_COST), _build_war, _intel() >= WAR_COST)
	elif sel_target >= 0:
		var h: Dictionary = hosts[sel_target]
		_plabel("TARGET  ·  %s" % str(h.name), 18)
		if ops.has(sel_target):
			var op: Dictionary = ops[sel_target]
			var srcs := 0
			for i in hosts.size():
				if int(hosts[i].assign) == sel_target: srcs += 1
			var cur_name := "done"
			if int(op.cur) < (op.seq as Array).size(): cur_name = str((op.nodes[op.seq[int(op.cur)]] as Dictionary).name)
			_plabel("Objective: %s   ·   assigned sources: %d" % [str(op.objective), srcs])
			_plabel("Active bots: %d   ·   now hitting: %s%s" % [int(ceil(float(op.abots))), cur_name,
				("  (activating…)" if float(op.activating) > 0.0 else ("  ⛽ waiting for fuel" if bool(op.waiting) else ""))])
			_btn("◀ Retreat operation", func(): _retreat(sel_target))
		else:
			_plabel("Select your war buildings (click them), then click this host and ATTACK.", 14, Color(0.7, 0.8, 0.9))
	else:
		_plabel("Click war buildings to pick an attack force, then click a bordering enemy host and ATTACK.", 15)
		_plabel("Attacks run through your network path. Unassigned buildings defend themselves. SPACE pauses.", 13, Color(0.6, 0.7, 0.8))
		_plabel("Assignments persist and are fed by production. SPACE pauses.", 13, Color(0.6, 0.7, 0.8))
	if paused: _plabel("— PAUSED —", 16, Color(1, 0.9, 0.4))


func _hud_text() -> String:
	var owned := 0; var resid := 0.0; var active := 0.0
	for h in hosts:
		if bool(h.owned): owned += 1
		resid += float(h.bots)
	for t in ops: active += float((ops[t] as Dictionary).abots)
	var s := "BOTNET  ·  hosts %d/%d  ·  bots resident %d / active %d  ·  Intel %d (+%.1f/s)" % [
		owned, hosts.size(), int(resid), int(ceil(active)), int(_intel()), _intel_income()]
	if not nw.is_empty(): s += "   ·   ⚠ NET WATCH → %s in %ds (str %d)" % [str(hosts[int(nw.target)].name), int(ceil(float(nw.eta))), int(nw.str)]
	return s


# ============================================================ DRAW
func _draw() -> void:
	var f := get_theme_default_font()
	# links
	for i in hosts.size():
		for j in hosts[i].links:
			if j < i: continue
			var both: bool = bool(hosts[i].owned) and bool(hosts[j].owned)
			draw_line(hosts[i].pos, hosts[j].pos, Color(0.3, 1, 0.55, 0.5) if both else Color(0.35, 0.55, 0.8, 0.22), 2.0 if both else 1.0, true)
	# assignment streams (instant transit — just show the data flow)
	for i in hosts.size():
		var asg := int(hosts[i].assign)
		if asg >= 0:
			var a: Vector2 = hosts[i].pos; var b: Vector2 = hosts[asg].pos
			draw_line(a, b, Color(0.6, 1, 1, 0.25), 1.5, true)
			var fr := fposmod(_t * 0.6 + float(i) * 0.2, 1.0)
			draw_circle(a.lerp(b, fr), 3.5, Color(0.6, 1, 1, 0.9))
	# net watch warning line
	if not nw.is_empty():
		var p: Vector2 = hosts[int(nw.target)].pos
		draw_arc(p, R + 10.0 + 3.0 * sin(_t * 4.0), 0.0, TAU, 32, Color(1, 0.4, 0.3, 0.8), 2.0, true)
	# hosts
	for i in hosts.size():
		var p: Vector2 = hosts[i].pos
		var fill: Color
		if bool(hosts[i].hub): fill = Color(0.2, 0.9, 1.0)
		elif bool(hosts[i].owned): fill = Color(0.25, 0.85, 0.45)
		elif ops.has(i): fill = Color(0.95, 0.55, 0.2)
		else: fill = Color(0.55, 0.3, 0.34)
		draw_circle(p, R, fill)
		if bool(hosts[i].war): draw_circle(p, R * 0.42, Color(0.05, 0.1, 0.12))
		if i == sel_source: draw_arc(p, R + 6.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 3.0, true)
		if i == sel_target: draw_arc(p, R + 8.0, 0.0, TAU, 32, Color(1, 0.9, 0.3), 3.0, true)
		# operation progress ring on a target under attack
		if ops.has(i):
			var op: Dictionary = ops[i]
			var tot := 0.0; var rem := 0.0
			for n in op.nodes:
				tot += float((n as Dictionary).defmax); rem += float((n as Dictionary).def)
			var prog: float = 1.0 - (rem / maxf(tot, 1.0))
			draw_arc(p, R + 4.0, -PI / 2.0, -PI / 2.0 + TAU * prog, 40, Color(1, 0.85, 0.3), 3.0, true)
		draw_string(f, p + Vector2(-R - 2.0, -R - 7.0), str(hosts[i].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.92, 1.0))
		if bool(hosts[i].owned) and bool(hosts[i].war):
			draw_string(f, p + Vector2(-R, R + 15.0), "%d bots" % int(hosts[i].bots), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 1, 0.7))
	# internal inset for the selected operation
	if sel_target >= 0 and ops.has(sel_target): _draw_op_inset(ops[sel_target])
	# toast
	if _msg_t > 0.0:
		draw_string(f, Vector2(20, 44), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 1, 1, clampf(_msg_t, 0, 1)))
	# overlays
	if won or lost:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.55), true)
		var txt := "CITY  OVERLOAD" if won else "DEFEATED"
		draw_string(f, get_viewport_rect().size * 0.5 + Vector2(-180, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(0.5, 1, 1) if won else Color(1, 0.5, 0.5))


func _draw_op_inset(op: Dictionary) -> void:
	var f := get_theme_default_font()
	var sz := get_viewport_rect().size
	var y := sz.y - 150.0
	var x0 := 448.0
	var span := minf(200.0, (sz.x - x0 - 60.0) / float((op.nodes as Array).size()))
	draw_string(f, Vector2(x0, y - 34.0), "INSIDE %s — %s" % [str(hosts[int(op.target)].name), str(op.objective)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.8, 1.0))
	var cur_ni := -1
	if int(op.cur) < (op.seq as Array).size(): cur_ni = int(op.seq[int(op.cur)])
	for i in (op.nodes as Array).size():
		var n: Dictionary = op.nodes[i]
		var p := Vector2(x0 + float(i) * span + 24.0, y)
		if i > 0: draw_line(Vector2(x0 + float(i - 1) * span + 24.0, y), p, Color(0.4, 0.7, 1.0, 0.3), 1.5, true)
		var col: Color
		if bool(n.controlled): col = Color(0.25, 0.85, 0.45)
		elif i == cur_ni: col = Color(0.95, 0.55, 0.2)
		else: col = Color(0.35, 0.37, 0.45)
		if str(n.kind) == "core": col = col.lerp(Color(1, 0.85, 0.3), 0.5)
		draw_circle(p, 16.0, col)
		if i == cur_ni and float(op.activating) <= 0.0: draw_arc(p, 20.0, 0.0, TAU, 28, Color(0.6, 1, 1), 2.0, true)
		draw_string(f, p + Vector2(-26.0, -22.0), str(n.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.9, 1.0))
		if not bool(n.controlled):
			var fr: float = clampf(float(n.def) / maxf(float(n.defmax), 1.0), 0.0, 1.0)
			draw_rect(Rect2(p.x - 16.0, p.y + 20.0, 32.0, 4.0), Color(0.1, 0.12, 0.16), true)
			draw_rect(Rect2(p.x - 16.0, p.y + 20.0, 32.0 * fr, 4.0), Color(1, 0.4, 0.45), true)
