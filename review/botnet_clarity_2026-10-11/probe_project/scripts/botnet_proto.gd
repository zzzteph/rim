extends Control
## PROTOTYPE — bot-attrition conquest (current model is design/BOTNET_ATTACK_DESIGN.md §0).
##
##   • A node's bots ARE its health, capped at 30. Every node regenerates toward the cap.
##   • Command a building's production: select source node(s), then command a destination — enemy = Attack,
##     friendly = Reinforce. Sources then release ONE bot/sec along their own network.
##   • Bots move hop by hop (LINK_TIME per link) and PAUSE at each intermediate node (NODE_ROUTE_DELAY);
##     they are never stored at pass-through nodes. Only arrival at the final target applies damage/reinforce.
##   • Reduce an enemy node to 0 → it's yours. Capture the HUB → win. Lose every node → defeat.
##
## Controls: ① LEFT-click your node(s) to select (Shift adds · drag empty map = box-select). ② Aim: LEFT-click
## a target node, OR drag a line from your node onto it — the target + everything connected light up, the rest
## fogs. ③ Press the ⚔ ATTACK / 🛡 REINFORCE button to fire. Nothing commits on a click or a drag — only the
## button does. A link PERSISTS until removed: select a source → "✖ Remove this link"; select/inspect a node →
## "✖ Remove all links into it" (your links only). Right-click = deselect. SPACE pauses.

const GRID_COLS := 5
const GRID_ROWS := 3
const NODE_CAP := 30.0             # bots limit per node
const PROD_RATE := 1.0             # bots/sec PER "bot" building on a node, up to NODE_CAP

# combat power — a defending node is worth 1.5× an attacking bot (D = 1.5·A); so each arriving attack bot
# removes A/D ≈ 0.667 of the target's bots. Reinforcements add a full bot.
const ATTACK_POWER := 1.0
const DEFEND_POWER := 1.5

# ── buildings & the Intel economy ──
const BUILD_SLOTS := 2             # buildings per node (choose from: bot / intel / cap)
const INTEL_START := 50.0
const INTEL_CAP_BASE := 100.0      # base Intel capacity
const CAP_PER_BUILD := 100.0       # each "cap" building adds this to capacity
const INTEL_PER_BUILD := 1.0       # each "intel" building makes this much Intel/sec
# attacking costs Intel: each PLAYER attack bot released needs 1 Intel (reinforcement is free)

# ── the THREE bot-flow timing variables (tunable; later raised by node/route upgrades) ──────────────
const SEND_RATE := 1.0             # (2) SPEED OF SENDING — bots/sec a source releases, one at a time
const LINK_TIME := 1.0             # (1) SPEED THROUGH A LINK — seconds to cross one link (hop)
const NODE_ROUTE_DELAY := 0.25     # (3) SPEED OF ROUTING THROUGH A NODE — pause (s) at each intermediate node
# ────────────────────────────────────────────────────────────────────────────────────────────────────

const ENEMY_CADENCE := 6.0         # how often the enemy (re)activates a node to stream at you
const R := 20.0

var full_hold := false             # EXPERIMENT (off by default): hold friendly supply when target has no room

var rng := RandomNumberGenerator.new()
var _t := 0.0                      # the single simulation clock everything shares
var paused := false
var won := false
var lost := false
var _end_shown := false
var _msg := ""
var _msg_t := 0.0
var _enemy_timer := ENEMY_CADENCE

var hosts := []        # {pos,grid,ring,name,links:[i],owned,hub,bots:float,assign:int,builds:Array}
var hub := -1
var intel := INTEL_START
var flights := []      # in-flight packets: {route:[idx], depart_t, arrive_t, player:bool}
var _next_depart := {} # source index -> absolute time its next bot departs

# selection / command
var sel := {}          # selected owned source indices
var sel_target := -1   # a node clicked as the pending target → the Attack/Reinforce button commits it
var _inspect := -1     # a node being inspected (shows its contributors), or -1
var _press_pos := Vector2.ZERO
var _boxing := false
var _box_start := Vector2.ZERO
var _drag_from := -1   # owned node a line is being dragged FROM (to aim a target), or -1
var _dragging := false # a line is actively being dragged (moved past the threshold)

var hud: Label
var panel: Panel
var panel_box: VBoxContainer


func _ready() -> void:
	rng.seed = 7
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_gen()
	hud = Label.new(); hud.position = Vector2(20, 12)
	hud.add_theme_font_size_override("font_size", 18); add_child(hud)
	panel = Panel.new(); panel.size = Vector2(404, 330); add_child(panel)
	var sc := ScrollContainer.new()                     # scroll so no button ever spills off-screen
	sc.position = Vector2(8, 8); sc.size = Vector2(388, 314)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.custom_minimum_size = Vector2(360, 0)
	sc.add_child(panel_box)
	panel.position = Vector2(16, get_viewport_rect().size.y - panel.size.y - 14)
	_refresh_panel(); set_process(true)


# ============================================================ GENERATION
func _gen() -> void:
	var sz := get_viewport_rect().size
	hosts = []; hub = -1; flights = []; _next_depart = {}
	var ax := 170.0; var ay := 100.0
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
			var start_bots := 30.0 if is_hub else (10.0 + float(2 - mini(ring, 2)) * 10.0)
			hosts.append({"pos": p, "grid": Vector2i(gx, gy), "ring": ring, "hub": is_hub,
				"name": "CENTRAL HUB" if is_hub else "Node %d" % hosts.size(),
				"links": [], "owned": false, "bots": start_bots, "assign": -1,
				"builds": (["bot", "bot"] if is_hub else ["bot"])})   # 1 empty slot to build into
	for gy in GRID_ROWS:
		for gx in GRID_COLS:
			var a: int = cell[Vector2i(gx, gy)]
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = Vector2i(gx, gy) + d
				if cell.has(nb): _link(a, cell[nb])
	for s in [cell[Vector2i(0, 0)], cell[Vector2i(0, 1)]]:
		hosts[s].owned = true; hosts[s].bots = NODE_CAP
	hosts[cell[Vector2i(0, 0)]].name = "YOUR RIG"


func _link(a: int, b: int) -> void:
	if a == b: return
	if not (hosts[a].links as Array).has(b): hosts[a].links.append(b)
	if not (hosts[b].links as Array).has(a): hosts[b].links.append(a)


# route bots travel: BFS over same-faction nodes from src to one bordering t, then the final hop to t
func _route(src: int, t: int) -> Array:
	if src < 0 or t < 0 or src == t: return []
	var fac := bool(hosts[src].owned)
	var prev := {src: src}; var q := [src]; var head := 0; var hit := -1
	while head < q.size():
		var c: int = q[head]; head += 1
		for o in hosts[c].links:
			if o == t: hit = c; break
		if hit >= 0: break
		for o in hosts[c].links:
			if bool(hosts[o].owned) == fac and not prev.has(o): prev[o] = c; q.append(o)
	if hit < 0: return []
	var p := [hit]
	while int(p[p.size() - 1]) != src: p.append(prev[p[p.size() - 1]])
	p.reverse(); p.append(t)
	return p


# travel time: hops × LINK_TIME + intermediate-nodes × NODE_ROUTE_DELAY (source & final target add no delay)
func _travel_time(rt: Array) -> float:
	if rt.size() < 2: return 0.0
	return float(rt.size() - 1) * LINK_TIME + float(maxi(0, rt.size() - 2)) * NODE_ROUTE_DELAY


# hop-by-hop position at a given elapsed time since departure (carries elapsed cleanly across all phases)
func _packet_pos(rt: Array, elapsed: float) -> Vector2:
	if rt.size() < 2: return hosts[int(rt[0])].pos
	var e := maxf(0.0, elapsed)
	for k in range(rt.size() - 1):
		if e < LINK_TIME:
			return (hosts[int(rt[k])].pos as Vector2).lerp(hosts[int(rt[k + 1])].pos, e / LINK_TIME)
		e -= LINK_TIME
		if k + 1 >= rt.size() - 1: return hosts[int(rt[rt.size() - 1])].pos   # arrived at final target
		if e < NODE_ROUTE_DELAY: return hosts[int(rt[k + 1])].pos             # pausing at an intermediate node
		e -= NODE_ROUTE_DELAY
	return hosts[int(rt[rt.size() - 1])].pos


func _link_kind(src: int, t: int) -> String:
	if src < 0 or t < 0 or src == t or not bool(hosts[src].owned): return ""
	if _route(src, t).is_empty(): return ""
	return "reinforce" if bool(hosts[t].owned) else "attack"


func _player_nodes() -> int:
	var n := 0
	for h in hosts:
		if bool(h.owned): n += 1
	return n


func _incoming(t: int, player: bool) -> float:   # bots of a faction currently flying toward t
	var s := 0.0
	for f in flights:
		if int((f.route as Array)[(f.route as Array).size() - 1]) == t and bool(f.player) == player: s += 1.0
	return s


# ---- buildings & Intel ----
func _count(i: int, kind: String) -> int:
	var n := 0
	for b in hosts[i].builds:
		if str(b) == kind: n += 1
	return n


func _intel_cap() -> float:
	var caps := 0
	for i in hosts.size():
		if bool(hosts[i].owned): caps += _count(i, "cap")
	return INTEL_CAP_BASE + CAP_PER_BUILD * float(caps)


func _intel_rate() -> float:
	var r := 0.0
	for i in hosts.size():
		if bool(hosts[i].owned): r += float(_count(i, "intel")) * INTEL_PER_BUILD
	return r


func _build(i: int, kind: String) -> void:
	if i < 0 or not bool(hosts[i].owned) or (hosts[i].builds as Array).size() >= BUILD_SLOTS: return
	hosts[i].builds.append(kind)
	intel = minf(_intel_cap(), intel)
	_flash("Built %s on %s" % [kind, str(hosts[i].name)]); _refresh_panel(); queue_redraw()


# ============================================================ LOOP
func _process(dt: float) -> void:
	if _msg_t > 0.0: _msg_t -= dt
	if not paused and not won and not lost:
		_t += dt                        # the shared clock only advances while playing → pause freezes everything
		for i in hosts.size():
			var nb := _count(i, "bot")
			if nb > 0: hosts[i].bots = minf(NODE_CAP, float(hosts[i].bots) + PROD_RATE * float(nb) * dt)
		intel = minf(_intel_cap(), intel + _intel_rate() * dt)   # Intel from your "intel" buildings
		_emit_due()
		_deliver_due()      # chronological; may set won/lost and then stops
		_enemy_ai(dt)
		if not won and not lost and _player_nodes() == 0: lost = true
	if (won or lost) and not _end_shown:
		_end_shown = true; _refresh_panel()      # show result + Reset without needing a map click
	hud.text = _hud_text()
	queue_redraw()


# release every departure that is due, on the shared clock, each with its true departure time
func _emit_due() -> void:
	var interval := 1.0 / SEND_RATE
	for i in hosts.size():
		var tgt := int(hosts[i].assign)
		if tgt < 0: continue
		if _route(i, tgt).is_empty():
			hosts[i].assign = -1; _next_depart.erase(i)
			_flash("%s's order stopped — no route (reissue to restore)" % str(hosts[i].name)); continue
		if full_hold and bool(hosts[tgt].owned) == bool(hosts[i].owned):   # experimental: hold if no room
			if float(hosts[tgt].bots) + _incoming(tgt, bool(hosts[i].owned)) >= NODE_CAP - 0.001:
				_next_depart[i] = _t; continue
		if not _next_depart.has(i): _next_depart[i] = _t
		var is_patk := bool(hosts[i].owned) and not bool(hosts[tgt].owned)   # a PLAYER attack costs Intel
		var guard := 0
		while float(_next_depart[i]) <= _t and guard < 2000:
			guard += 1
			if float(hosts[i].bots) < 1.0:
				_next_depart[i] = _t   # starved — resume when stock returns, no catch-up burst
				break
			if is_patk and intel < 1.0:
				_next_depart[i] = _t   # out of Intel — the attack holds (production continues)
				break
			var dep := float(_next_depart[i])
			hosts[i].bots = float(hosts[i].bots) - 1.0
			if is_patk: intel -= 1.0
			var rt := _route(i, tgt)
			flights.append({"route": rt, "depart_t": dep, "arrive_t": dep + _travel_time(rt), "player": bool(hosts[i].owned)})
			_next_depart[i] = dep + interval


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


# chronological; ties (same instant) resolved deterministically: by arrive time, then target, then
# reinforcements of the target's current owner before attacks (prevents a flicker/false capture on a tie)
func _arrival_cmp(a: Dictionary, b: Dictionary) -> bool:
	if absf(float(a.arrive_t) - float(b.arrive_t)) > 0.0001: return float(a.arrive_t) < float(b.arrive_t)
	var ta := int((a.route as Array)[(a.route as Array).size() - 1])
	var tb := int((b.route as Array)[(b.route as Array).size() - 1])
	if ta != tb: return ta < tb
	var ra := bool(a.player) == bool(hosts[ta].owned)
	var rb := bool(b.player) == bool(hosts[tb].owned)
	return ra and not rb


# arrival applies: same side → reinforce (capped); opposite → attrition; reduced to 0 → flips ownership
func _deliver(f: Dictionary) -> void:
	var rt: Array = f.route
	if rt.is_empty(): return
	var t: int = int(rt[rt.size() - 1])
	if bool(hosts[t].owned) == bool(f.player):
		hosts[t].bots = minf(NODE_CAP, float(hosts[t].bots) + 1.0)   # reinforcement adds a full bot
	else:
		hosts[t].bots = float(hosts[t].bots) - (ATTACK_POWER / DEFEND_POWER)   # defender is worth 1.5× (D=1.5A)
		if float(hosts[t].bots) <= 0.0:
			var to_player := bool(f.player)
			hosts[t].owned = to_player
			hosts[t].bots = minf(NODE_CAP, -float(hosts[t].bots))
			hosts[t].assign = -1; _next_depart.erase(t)
			if sel.has(t) and not to_player: sel.erase(t)   # a selected source lost to the enemy is uncontrollable
			var feeders := 0
			for i in hosts.size():
				if int(hosts[i].assign) == t: feeders += 1
			if to_player:
				if t == hub: won = true
				elif feeders > 0: _flash("Captured %s — %d source(s) now REINFORCE it" % [str(hosts[t].name), feeders])
				else: _flash("Captured %s" % str(hosts[t].name))
			else:
				if feeders > 0: _flash("Lost %s — %d source(s) now ATTACK it" % [str(hosts[t].name), feeders])
				else: _flash("Lost %s" % str(hosts[t].name))


func _enemy_ai(dt: float) -> void:
	_enemy_timer -= dt
	if _enemy_timer > 0.0: return
	_enemy_timer = ENEMY_CADENCE
	# release any enemy order whose target is no longer a reachable hostile node, so it can re-engage
	for e in hosts.size():
		if bool(hosts[e].owned): continue
		var a := int(hosts[e].assign)
		if a >= 0 and (bool(hosts[a].owned) == false or _route(e, a).is_empty()):
			hosts[e].assign = -1; _next_depart.erase(e)
	# activate one idle enemy frontier node to start streaming at a bordering node of yours
	var opts := []
	for e in hosts.size():
		if bool(hosts[e].owned) or int(hosts[e].assign) >= 0 or float(hosts[e].bots) < 5.0: continue
		for p in hosts[e].links:
			if bool(hosts[p].owned): opts.append([e, p]); break
	if opts.is_empty(): return
	var pick: Array = opts[rng.randi() % opts.size()]
	hosts[int(pick[0])].assign = int(pick[1]); _next_depart[int(pick[0])] = _t
	_flash("⚔ %s is attacking %s — defend it!" % [str(hosts[int(pick[0])].name), str(hosts[int(pick[1])].name)])


# ============================================================ INPUT
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: paused = not paused; _refresh_panel(); queue_redraw()
		elif event.keycode == KEY_ESCAPE: sel = {}; _inspect = -1; _refresh_panel(); queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if won or lost: return                 # no map commands after a terminal result (use Reset in the panel)
	if event is InputEventMouseMotion:
		if _drag_from >= 0 and event.position.distance_to(_press_pos) > 8.0: _dragging = true
		if _boxing or _dragging or not sel.is_empty(): queue_redraw()   # live marquee / drag line / hover
		return
	if not (event is InputEventMouseButton): return
	var hit := _host_at(event.position)
	var shift: bool = event.shift_pressed
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			_box_start = event.position
			_boxing = hit < 0              # a marquee starts only on EMPTY map
			_drag_from = hit if (hit >= 0 and bool(hosts[hit].owned)) else -1   # drag a line only FROM your node
			_dragging = false
			return
		var moved: bool = event.position.distance_to(_press_pos) > 8.0
		if _boxing and moved:
			_marquee(Rect2(_box_start, event.position - _box_start).abs(), shift)
		elif _drag_from >= 0 and moved and hit >= 0 and hit != _drag_from:
			_drag_aim(_drag_from, hit)     # dragged a line onto a node → that node becomes the PENDING target
		elif not moved:
			_left_click(hit, shift)
		_boxing = false; _drag_from = -1; _dragging = false
		_refresh_panel(); queue_redraw()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		sel = {}; sel_target = -1; _inspect = -1       # right-click = deselect / clear the pending target
		_refresh_panel(); queue_redraw()


# (1) left-click your node(s) to SELECT. (2) left-click a target node → it becomes PENDING and an
# ATTACK / REINFORCE button appears in the panel. (3) press the button to start. Nothing fires on click.
func _left_click(hit: int, shift: bool) -> void:
	if hit < 0:
		sel = {}; sel_target = -1; _inspect = -1
		return
	if shift and bool(hosts[hit].owned):
		if sel.has(hit): sel.erase(hit)
		else: sel[hit] = true
		sel_target = -1; _inspect = -1
		return
	if sel.is_empty():                       # no sources yet → this click picks a source (or inspects an enemy)
		if bool(hosts[hit].owned): sel = {hit: true}
		else: _inspect = hit
		sel_target = -1
		return
	if bool(hosts[hit].owned) and sel.has(hit):
		return                               # clicking a selected source → no change
	sel_target = hit                         # any other node → PENDING target; the command button appears


func _do_command() -> void:                  # the Attack/Reinforce button
	if sel_target >= 0: _command(sel_target); sel_target = -1


# dragging a line from your node onto another node AIMS at it (sets the pending target) — it never fires.
# Dragging from a node already in the selection keeps the whole group; from an unselected node picks just it.
func _drag_aim(src: int, dest: int) -> void:
	if not sel.has(src): sel = {src: true}
	sel_target = dest; _inspect = -1


func _marquee(r: Rect2, shift: bool) -> void:
	if not shift: sel = {}
	for i in hosts.size():
		if bool(hosts[i].owned) and r.has_point(hosts[i].pos): sel[i] = true
	_inspect = -1


func _host_at(p: Vector2) -> int:
	for i in hosts.size():
		if (hosts[i].pos as Vector2).distance_to(p) <= R + 5.0: return i
	return -1


# command the selected group to a destination (persistent). Enemy = Attack, friendly = Reinforce. The
# group stays selected so retargeting is one more command. Retargeting affects FUTURE departures only.
func _command(dest: int) -> void:
	if dest < 0 or sel.is_empty(): return
	var done := 0; var excl := 0
	for s in sel.keys():
		if bool(hosts[int(s)].owned) and not _route(int(s), dest).is_empty():
			hosts[int(s)].assign = dest
			if not _next_depart.has(int(s)): _next_depart[int(s)] = _t
			done += 1
		else: excl += 1
	if done > 0:
		var act := "Reinforce" if bool(hosts[dest].owned) else "Attack"
		_flash("%s %s · %d source(s)%s" % [act, str(hosts[dest].name), done, ("  ·  %d excluded (no route)" % excl) if excl > 0 else ""])
	else:
		_flash("No selected source can reach %s" % str(hosts[dest].name))
	_inspect = dest
	_refresh_panel()


# stop ONLY the selected player-owned sources' future outgoing supply (incoming + travelling bots continue)
func _stop_supplying() -> void:
	var n := 0
	for s in sel.keys():
		if bool(hosts[int(s)].owned) and int(hosts[int(s)].assign) >= 0:
			hosts[int(s)].assign = -1; _next_depart.erase(int(s)); n += 1
	if n > 0: _flash("Kept %d source(s) home (outgoing stopped)" % n)
	else: _flash("No outgoing orders to stop")
	_refresh_panel()


func _select_contributors(feeders: Array) -> void:
	sel = {}
	for i in feeders: sel[int(i)] = true
	_inspect = -1; _refresh_panel(); queue_redraw()


# your own sources (links) currently pointing at `node`
func _owned_feeders(node: int) -> Array:
	var out := []
	for i in hosts.size():
		if bool(hosts[i].owned) and int(hosts[i].assign) == node: out.append(i)
	return out


# an order (link) PERSISTS until you remove it: from a source (its outgoing link) or into a node (all your
# links pointing at it). Player commands only ever touch player-owned sources — enemy links are untouched.
func _cancel_from(src: int) -> void:
	if src >= 0 and bool(hosts[src].owned) and int(hosts[src].assign) >= 0:
		hosts[src].assign = -1; _next_depart.erase(src)
		_flash("Removed %s's link" % str(hosts[src].name))
	_refresh_panel(); queue_redraw()


func _cancel_to(dest: int) -> void:
	var n := 0
	for i in _owned_feeders(dest):
		hosts[int(i)].assign = -1; _next_depart.erase(int(i)); n += 1
	if n > 0: _flash("Removed %d link(s) into %s" % [n, str(hosts[dest].name)])
	else: _flash("No links of yours point at %s" % str(hosts[dest].name))
	_refresh_panel(); queue_redraw()


func _reset() -> void:
	won = false; lost = false; _end_shown = false; paused = false; _t = 0.0; _enemy_timer = ENEMY_CADENCE
	sel = {}; sel_target = -1; _inspect = -1; _boxing = false; _drag_from = -1; _dragging = false; intel = INTEL_START
	_gen(); _refresh_panel()


func _build_names(builds: Array) -> String:
	if builds.is_empty(): return "none"
	var out := []
	for b in builds: out.append({"bot": "Bot", "intel": "Intel", "cap": "Cap"}.get(str(b), str(b)))
	return ", ".join(out)


func _flash(m: String) -> void: _msg = m; _msg_t = 4.0


# ============================================================ UI PANEL
func _plabel(txt: String, sz := 15, col := Color(0.85, 0.9, 1.0)) -> void:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(344, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_child(l)


func _btn(txt: String, cb: Callable, enabled := true) -> void:
	var b := Button.new(); b.text = txt; b.focus_mode = Control.FOCUS_ALL   # keyboard-focusable
	b.disabled = not enabled; b.custom_minimum_size = Vector2(0, 30)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb); panel_box.add_child(b)


func _refresh_panel() -> void:
	for c in panel_box.get_children(): c.queue_free()
	if won:
		_plabel("CITY OVERLOAD — the net is yours.", 20, Color(0.5, 1, 1)); _btn("Reset", _reset)
		if paused: _plabel("— PAUSED —", 16, Color(1, 0.9, 0.4))
		return
	if lost:
		_plabel("DEFEATED — you lost every node.", 20, Color(1, 0.5, 0.5)); _btn("Reset", _reset)
		if paused: _plabel("— PAUSED —", 16, Color(1, 0.9, 0.4))
		return
	if not sel.is_empty():
		var stock := 0.0
		for s in sel.keys(): stock += float(hosts[int(s)].bots)
		_plabel("SELECTED  ·  %d source(s)  ·  %d bots" % [sel.size(), int(stock)], 18)
		if sel.size() == 1:
			var s0: int = int(sel.keys()[0])
			var a := int(hosts[s0].assign)
			if a >= 0:
				_plabel("Link: %s → %s" % [("reinforce" if bool(hosts[a].owned) else "attack"), str(hosts[a].name)], 15, Color(0.6, 1, 0.8))
				_btn("✖ Remove this link (from %s)" % str(hosts[s0].name), _cancel_from.bind(s0))
			else: _plabel("Link: none (idle)", 14, Color(0.7, 0.8, 0.9))
			var inlinks := _owned_feeders(s0)
			if not inlinks.is_empty():
				_btn("✖ Remove all %d link(s) into %s" % [inlinks.size(), str(hosts[s0].name)], _cancel_to.bind(s0))
			_plabel("Buildings (%d/%d): %s" % [(hosts[s0].builds as Array).size(), BUILD_SLOTS, _build_names(hosts[s0].builds)], 13, Color(0.8, 0.9, 1.0))
			if (hosts[s0].builds as Array).size() < BUILD_SLOTS:
				_btn("+ Bot production (+%.0f bot/s)" % PROD_RATE, _build.bind(s0, "bot"))
				_btn("+ Intel production (+%.0f/s)" % INTEL_PER_BUILD, _build.bind(s0, "intel"))
				_btn("+ Intel capacity (+%d)" % int(CAP_PER_BUILD), _build.bind(s0, "cap"))
		if sel_target >= 0:
			var elig := 0
			for s in sel.keys():
				if _link_kind(int(s), sel_target) != "": elig += 1
			var atk := not bool(hosts[sel_target].owned)
			_plabel("Target: %s  ·  %d/%d can reach" % [str(hosts[sel_target].name), elig, sel.size()], 15, Color(1, 0.9, 0.5))
			_btn(("⚔  ATTACK %s" if atk else "🛡  REINFORCE %s") % str(hosts[sel_target].name), _do_command, elig > 0)
		else:
			_plabel("▶ Click a target node (or drag a line onto it), then press ATTACK / REINFORCE.", 14, Color(1, 0.9, 0.5))
		if sel.size() > 1: _btn("✖ Remove links from all selected (keep bots here)", _stop_supplying)
		_btn("Clear selection (Esc)", func(): sel = {}; sel_target = -1; _inspect = -1; _refresh_panel(); queue_redraw())
	elif _inspect >= 0:
		var h: Dictionary = hosts[_inspect]
		_plabel("%s  ·  %s" % [str(h.name), ("yours" if bool(h.owned) else "enemy")], 18)
		_plabel("Resident %d / %d  ·  in transit: %d yours · %d enemy" % [int(h.bots), int(NODE_CAP), int(_incoming(_inspect, true)), int(_incoming(_inspect, false))], 13, Color(0.7, 0.85, 1.0))
		_plabel("Buildings: %s" % _build_names(h.builds), 13, Color(0.8, 0.9, 1.0))
		var feeders := []
		for i in hosts.size():
			if int(hosts[i].assign) == _inspect: feeders.append(i)
		if feeders.is_empty(): _plabel("No sources are supplying/attacking it.", 14, Color(0.7, 0.8, 0.9))
		else:
			_plabel("%d source(s) targeting it." % feeders.size(), 14)
			_btn("Select contributors", _select_contributors.bind(feeders))
		var inlinks := _owned_feeders(_inspect)
		if not inlinks.is_empty():
			_btn("✖ Remove all %d of your link(s) into %s" % [inlinks.size(), str(h.name)], _cancel_to.bind(_inspect))
		_plabel("Left-click a source to command production. SPACE pauses.", 13, Color(0.6, 0.7, 0.8))
	else:
		_plabel("① LEFT-CLICK your node(s) to select (Shift adds · drag empty map = box-select).", 15)
		_plabel("② Click a target node OR drag a line onto it (relevant nodes light up), then press the button.", 14, Color(0.7, 0.8, 0.9))
		_plabel("Bots act only on ARRIVAL. Right-click = deselect. SPACE pauses.", 13, Color(0.6, 0.7, 0.8))
	if paused: _plabel("— PAUSED —", 16, Color(1, 0.9, 0.4))


func _hud_text() -> String:
	var mine := 0; var mybots := 0.0; var enemybots := 0.0
	for h in hosts:
		if bool(h.owned): mine += 1; mybots += float(h.bots)
		else: enemybots += float(h.bots)
	return "BOTNET  ·  nodes %d/%d  ·  bots %d  ·  Intel %d/%d (+%.0f/s)  ·  take the HUB → OVERLOAD" % [
		mine, hosts.size(), int(mybots), int(intel), int(_intel_cap()), _intel_rate()]


# ============================================================ DRAW
# which node is being AIMED at: an explicit pending target, else the node under a dragged line
func _aim_target() -> int:
	if sel_target >= 0: return sel_target
	if _dragging and _drag_from >= 0:
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and hov != _drag_from: return hov
	return -1


# which sources the aim applies to (the drag source alone if it isn't part of the selection, else the group)
func _aim_sources() -> Array:
	if _dragging and _drag_from >= 0 and not sel.has(_drag_from): return [_drag_from]
	return sel.keys()


func _lk(a: int, b: int) -> String: return "%d_%d" % [mini(a, b), maxi(a, b)]


# the focused subgraph when aiming: the target, every node connected to it, and the routes your sources take
func _build_focus(aim: int, fnodes: Dictionary, flinks: Dictionary) -> void:
	fnodes[aim] = true
	for nb in hosts[aim].links:
		fnodes[int(nb)] = true; flinks[_lk(aim, int(nb))] = true
	for s in _aim_sources():
		if int(s) == aim: continue
		var rt := _route(int(s), aim)
		for k in rt.size(): fnodes[int(rt[k])] = true
		for k in range(rt.size() - 1): flinks[_lk(int(rt[k]), int(rt[k + 1]))] = true


func _draw() -> void:
	var f := get_theme_default_font()
	# ── focus / fog: while aiming, the relevant subgraph stays bright and everything else fades ──
	var aim := _aim_target()
	var focus_on := aim >= 0
	var fnodes := {}; var flinks := {}
	if focus_on: _build_focus(aim, fnodes, flinks)
	for i in hosts.size():   # network links
		for j in hosts[i].links:
			if j < i: continue
			var both: bool = bool(hosts[i].owned) and bool(hosts[j].owned)
			var lcol: Color = Color(0.3, 1, 0.55, 0.4) if both else Color(0.35, 0.5, 0.7, 0.18)
			if focus_on and not flinks.has(_lk(i, j)): lcol.a *= 0.22      # fog links outside the focus
			draw_line(hosts[i].pos, hosts[j].pos, lcol, 2.0 if both else 1.0, true)
	# committed routes (solid, with arrow) — fogged when not part of the focused subgraph
	for i in hosts.size():
		if int(hosts[i].assign) >= 0:
			var d := int(hosts[i].assign)
			_draw_route_line(_route(i, d), d, focus_on and not (fnodes.has(i) and fnodes.has(d)))
	# in-flight bots (the only moving things) — one dot per bot, position from the shared clock
	for fl in flights:
		var pp := _packet_pos(fl.route, _t - float(fl.depart_t))
		var endn := int((fl.route as Array)[(fl.route as Array).size() - 1])
		var ba: float = 1.0 if (not focus_on or fnodes.has(endn)) else 0.3
		draw_circle(pp, 3.5, Color(0.5, 1, 0.7, ba) if bool(fl.player) else Color(1, 0.45, 0.4, ba))
	# nodes
	for i in hosts.size():
		_draw_node(f, i, 1.0 if (not focus_on or fnodes.has(i)) else 0.22, i == aim)
	# aiming: bold routes from your sources to the target + an on-canvas action label
	if focus_on:
		for s in _aim_sources():
			if _link_kind(int(s), aim) != "": _draw_dashed(_route(int(s), aim), Color(1, 0.95, 0.55, 0.95), 3.0)
		var act: String = "🛡 reinforce %s" if bool(hosts[aim].owned) else "⚔ attack %s"
		draw_string(f, (hosts[aim].pos as Vector2) + Vector2(-R, -R - 24.0), act % str(hosts[aim].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.92, 0.5))
	# sources selected but NOT yet aiming: glow where they can go + hover preview (no fog)
	elif not sel.is_empty():
		var src_keys: Array = sel.keys()
		for i in hosts.size():
			var ok := false
			for s in src_keys:
				if _link_kind(int(s), i) != "": ok = true; break
			if ok: draw_arc(hosts[i].pos, R + 7.0, 0.0, TAU, 32, Color(1, 0.8, 0.4, 0.55), 2.0, true)
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and not sel.has(hov):
			var elig := 0
			for s in src_keys:
				if _link_kind(int(s), hov) != "": _draw_dashed(_route(int(s), hov)); elig += 1
			if elig > 0:
				draw_string(f, (hosts[hov].pos as Vector2) + Vector2(-R, -R - 22.0), "click or drag here to target %s" % str(hosts[hov].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.5))
	# the dragged rubber-band line — the boldest thing on screen while you aim it
	if _dragging and _drag_from >= 0:
		var to := get_local_mouse_position()
		var hv := _host_at(to)
		if hv >= 0 and hv != _drag_from: to = hosts[hv].pos
		draw_line(hosts[_drag_from].pos, to, Color(1, 0.95, 0.55, 0.95), 3.0, true)
		draw_circle(to, 4.0, Color(1, 0.95, 0.55, 0.95))
	# marquee box
	if _boxing:
		var r := Rect2(_box_start, get_local_mouse_position() - _box_start).abs()
		draw_rect(r, Color(0.6, 1, 1, 0.08), true)
		draw_rect(r, Color(0.6, 1, 1, 0.6), false, 1.0, true)
	if _msg_t > 0.0:
		draw_string(f, Vector2(20, 44), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 1, 1, clampf(_msg_t, 0, 1)))
	if won or lost:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.55), true)
		draw_string(f, get_viewport_rect().size * 0.5 + Vector2(-180, 0), ("CITY  OVERLOAD" if won else "DEFEATED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(0.5, 1, 1) if won else Color(1, 0.5, 0.5))


# one node, drawn at opacity `a` (fogged when < 1) — `is_aim` adds the bright pending-target ring
func _draw_node(f: Font, i: int, a: float, is_aim: bool) -> void:
	var p: Vector2 = hosts[i].pos
	var fill: Color
	if bool(hosts[i].hub): fill = Color(0.2, 0.9, 1.0) if not bool(hosts[i].owned) else Color(0.3, 0.9, 0.6)
	elif bool(hosts[i].owned): fill = Color(0.25, 0.85, 0.45)
	else: fill = Color(0.75, 0.3, 0.33)
	fill.a = a
	draw_circle(p, R, fill)
	if sel.has(i): draw_arc(p, R + 6.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95 * a), 3.0, true)
	if i == _inspect: draw_arc(p, R + 8.0, 0.0, TAU, 32, Color(1, 0.9, 0.3, a), 2.0, true)
	if is_aim: draw_arc(p, R + 9.0, 0.0, TAU, 32, Color(1, 0.9, 0.3), 3.0, true)   # aim ring stays full bright
	var fr: float = clampf(float(hosts[i].bots) / NODE_CAP, 0.0, 1.0)
	draw_rect(Rect2(p.x - R, p.y + R + 5.0, R * 2.0, 5.0), Color(0.1, 0.12, 0.16, a), true)
	draw_rect(Rect2(p.x - R, p.y + R + 5.0, R * 2.0 * fr, 5.0), Color(0.4, 1, 0.6, a) if bool(hosts[i].owned) else Color(1, 0.5, 0.5, a), true)
	draw_string(f, p + Vector2(-10, 5), "%d" % int(round(float(hosts[i].bots))), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.05, 0.08, 0.1, a))
	draw_string(f, p + Vector2(-R - 2.0, -R - 7.0), str(hosts[i].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.92, 1.0, a))
	if not (hosts[i].builds as Array).is_empty():   # tiny build badges (B=bot, I=intel, C=cap)
		var bi := ""
		for b in hosts[i].builds: bi += {"bot": "B", "intel": "I", "cap": "C"}.get(str(b), "?")
		draw_string(f, p + Vector2(R - 8.0, -R + 11.0), bi, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.95, 0.6, 0.95 * a))
	# overflow: a full friendly node still being supplied wastes those arrivals
	if bool(hosts[i].owned) and float(hosts[i].bots) >= NODE_CAP - 0.5 and _incoming(i, true) > 0.0:
		draw_string(f, p + Vector2(-R, R + 24.0), "FULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.4, a))


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


func _draw_route_line(rt: Array, tgt: int, dim := false) -> void:
	if rt.size() < 2: return
	var col: Color = Color(0.4, 1, 0.7) if bool(hosts[tgt].owned) else Color(1, 0.85, 0.35)
	var fade := 0.22 if dim else 1.0
	var pts := PackedVector2Array()
	for idx in rt: pts.append(hosts[int(idx)].pos)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.28 * fade), 6.0, true)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.9 * fade), 2.5, true)
	var a: Vector2 = hosts[int(rt[rt.size() - 2])].pos
	var b: Vector2 = hosts[int(rt[rt.size() - 1])].pos
	var dir: Vector2 = (b - a).normalized()
	var tip: Vector2 = b - dir * (R + 3.0)
	var perp := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 14.0 + perp * 8.0, tip - dir * 14.0 - perp * 8.0]), Color(col.r, col.g, col.b, 0.9 * fade))
