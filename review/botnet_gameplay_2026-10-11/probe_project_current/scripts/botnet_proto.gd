extends Control
## PROTOTYPE — bot-attrition conquest. Strict rules of engagement (prototype only):
##
##   • Every node holds up to 30 bots = its power/health. Nodes regenerate bots over time.
##   • ATTACK: link your node(s) to an enemy node, press ATTACK. Bots FLOW there; only ON ARRIVAL do they
##     reduce the target's bots. Sending drains the source. Reduce an enemy node to 0 → it becomes yours.
##   • DEFEND: link your node(s) to a friendly node, press DEFEND. Bots flow; only ON ARRIVAL do they add to
##     that node's bots. When the enemy attacks you it reduces your node's bots the same way.
##   • Main loop: whoever produces the most bots and pushes longest wins.
##
## Take the central HUB → CITY OVERLOAD. Lose all your nodes → defeat.

const GRID_COLS := 5
const GRID_ROWS := 3
const NODE_CAP := 30.0             # RULE 1 — bots limit per node
const PROD_RATE := 1.0             # bots/sec every node regenerates, up to NODE_CAP

# ── the THREE bot-flow timing variables (tunable; later raised by node/route upgrades) ──────────────
const SEND_RATE := 1.0             # (2) SPEED OF SENDING — bots/sec a source releases, one at a time
const LINK_TIME := 1.0             # (1) SPEED THROUGH A LINK — seconds a bot takes to cross one link (hop)
const NODE_ROUTE_DELAY := 0.25     # (3) SPEED OF ROUTING THROUGH A NODE — extra seconds per node a flow passes through
# ────────────────────────────────────────────────────────────────────────────────────────────────────

const ENEMY_CADENCE := 6.0         # how often the enemy activates another node to start streaming at you
const R := 20.0

var rng := RandomNumberGenerator.new()
var _t := 0.0
var paused := false
var won := false
var lost := false
var _msg := ""
var _msg_t := 0.0
var _enemy_timer := ENEMY_CADENCE
var _emit_acc := {}                # per-source packet timer

var hosts := []        # {pos,grid,ring,name,links:[i],owned(=player),hub,bots:float,assign:int}
var hub := -1
var flights := []      # in-flight bot packets: {route:[idx], t, dur, count, player:bool}

# selection / drag
var sel_sources := {}  # player nodes chosen to send from
var sel_target := -1   # node they're linked to
var drag_from := -1
var drag_pos := Vector2.ZERO
var _press_pos := Vector2.ZERO

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
	panel = Panel.new(); panel.size = Vector2(390, 240); add_child(panel)
	panel_box = VBoxContainer.new(); panel_box.position = Vector2(14, 12)
	panel_box.custom_minimum_size = Vector2(362, 0); panel.add_child(panel_box)
	panel.position = Vector2(16, get_viewport_rect().size.y - panel.size.y - 14)
	_refresh_panel(); set_process(true)


# ============================================================ GENERATION
func _gen() -> void:
	var sz := get_viewport_rect().size
	hosts = []; hub = -1; flights = []; _emit_acc = {}
	var ax := 170.0; var ay := 100.0
	var aw := sz.x - 340.0; var ah := sz.y - 360.0
	var hc := Vector2i(GRID_COLS / 2, GRID_ROWS / 2)
	var cell := {}
	for gy in GRID_ROWS:
		for gx in GRID_COLS:
			var p := Vector2(ax + aw * (float(gx) / float(GRID_COLS - 1)), ay + ah * (float(gy) / float(GRID_ROWS - 1)))
			var ring: int = maxi(absi(gx - hc.x), absi(gy - hc.y))
			var is_hub: bool = gx == hc.x and gy == hc.y
			cell[Vector2i(gx, gy)] = hosts.size()
			if is_hub: hub = hosts.size()
			var start_bots := 30.0 if is_hub else (10.0 + float(2 - mini(ring, 2)) * 10.0)   # outer weaker, inner stronger
			hosts.append({"pos": p, "grid": Vector2i(gx, gy), "ring": ring, "hub": is_hub,
				"name": "CENTRAL HUB" if is_hub else "Node %d" % hosts.size(),
				"links": [], "owned": false, "bots": start_bots, "assign": -1})
	for gy in GRID_ROWS:
		for gx in GRID_COLS:
			var a: int = cell[Vector2i(gx, gy)]
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = Vector2i(gx, gy) + d
				if cell.has(nb): _link(a, cell[nb])
	for s in [cell[Vector2i(0, 0)], cell[Vector2i(0, 1)]]:   # you start with two nodes, full
		hosts[s].owned = true; hosts[s].bots = NODE_CAP
	hosts[cell[Vector2i(0, 0)]].name = "YOUR RIG"


func _link(a: int, b: int) -> void:
	if a == b: return
	if not (hosts[a].links as Array).has(b): hosts[a].links.append(b)
	if not (hosts[b].links as Array).has(a): hosts[b].links.append(a)


# the route bots travel: BFS over YOUR nodes from src to a node bordering t, then the final hop to t. []
# if there is no owned path (so bots can only move through your own network).
func _route(src: int, t: int) -> Array:
	if src < 0 or t < 0 or src == t: return []
	var fac := bool(hosts[src].owned)                 # bots travel only through their OWN side's network
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


# travel time for a route: 1s per hop + 0.25s per node routed through (distance matters for reinforcing)
func _travel_time(rt: Array) -> float:
	# (1) time crossing each link + (3) routing delay at each node passed through
	if rt.size() < 2: return LINK_TIME
	return float(rt.size() - 1) * LINK_TIME + float(rt.size()) * NODE_ROUTE_DELAY


func _link_kind(src: int, t: int) -> String:
	if src < 0 or t < 0 or src == t or not bool(hosts[src].owned): return ""
	if _route(src, t).is_empty(): return ""
	return "defend" if bool(hosts[t].owned) else "attack"


# ============================================================ LOOP
func _process(dt: float) -> void:
	_t += dt
	if _msg_t > 0.0: _msg_t -= dt
	if not paused and not won and not lost:
		for i in hosts.size():   # every node regenerates toward the cap — production is the whole game
			hosts[i].bots = minf(NODE_CAP, float(hosts[i].bots) + PROD_RATE * dt)
		_emit(dt)
		_advance_flights(dt)
		_enemy_ai(dt)
		var pc := 0
		for h in hosts:
			if bool(h.owned): pc += 1
		if pc == 0: lost = true
	hud.text = _hud_text()
	queue_redraw()


# committed sources push bots into flows over time (bots leave the source gradually)
func _emit(dt: float) -> void:
	var interval := 1.0 / SEND_RATE          # ONE bot per interval → a flow of single bots, not a group of 10
	for i in hosts.size():
		var tgt := int(hosts[i].assign)
		if tgt < 0: continue
		if _route(i, tgt).is_empty(): hosts[i].assign = -1; continue   # route broke → drop it
		if float(hosts[i].bots) < 1.0: continue
		_emit_acc[i] = float(_emit_acc.get(i, 0.0)) + dt
		if float(_emit_acc[i]) < interval: continue
		_emit_acc[i] = float(_emit_acc[i]) - interval
		hosts[i].bots = float(hosts[i].bots) - 1.0
		var rt := _route(i, tgt)
		flights.append({"route": rt, "t": 0.0, "dur": _travel_time(rt), "count": 1.0, "player": bool(hosts[i].owned)})


func _advance_flights(dt: float) -> void:
	var keep := []
	for f in flights:
		f.t = float(f.t) + dt
		if float(f.t) >= float(f.dur): _deliver(f)
		else: keep.append(f)
	flights = keep


# RULE — bots only ACT on arrival: same side → reinforce; enemy → attrition, and a node reduced to 0 flips
func _deliver(f: Dictionary) -> void:
	var rt: Array = f.route
	if rt.is_empty(): return
	var t: int = int(rt[rt.size() - 1])
	var count := float(f.count)
	if bool(hosts[t].owned) == bool(f.player):
		hosts[t].bots = minf(NODE_CAP, float(hosts[t].bots) + count)
	else:
		hosts[t].bots = float(hosts[t].bots) - count
		if float(hosts[t].bots) <= 0.0:
			hosts[t].owned = bool(f.player)
			hosts[t].bots = minf(NODE_CAP, -float(hosts[t].bots))   # overflow occupies the node
			hosts[t].assign = -1
			if bool(f.player) and t == hub: won = true
			if sel_target == t and not bool(f.player): sel_target = -1


func _enemy_ai(dt: float) -> void:
	_enemy_timer -= dt
	if _enemy_timer > 0.0: return
	_enemy_timer = ENEMY_CADENCE
	# activate one idle enemy frontier node: it then STREAMS bots 1-by-1 at a bordering node of yours (via _emit)
	var opts := []
	for e in hosts.size():
		if bool(hosts[e].owned) or int(hosts[e].assign) >= 0 or float(hosts[e].bots) < 5.0: continue
		for p in hosts[e].links:
			if bool(hosts[p].owned): opts.append([e, p]); break
	if opts.is_empty(): return
	var pick: Array = opts[rng.randi() % opts.size()]
	hosts[int(pick[0])].assign = int(pick[1])
	_flash("⚔ %s is attacking %s — DEFEND it!" % [str(hosts[int(pick[0])].name), str(hosts[int(pick[1])].name)])


# ============================================================ INPUT
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if drag_from >= 0: drag_pos = event.position; queue_redraw()
		return
	if not (event is InputEventMouseButton): return
	var hit := _host_at(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position; drag_pos = event.position
			drag_from = hit if (hit >= 0 and bool(hosts[hit].owned)) else -1
			return
		var moved: bool = event.position.distance_to(_press_pos) > 8.0
		if drag_from >= 0 and moved and hit >= 0 and _link_kind(drag_from, hit) != "":
			sel_sources[drag_from] = true; sel_target = hit
			_flash("Linked %s → %s · press %s" % [str(hosts[drag_from].name), str(hosts[hit].name), ("DEFEND" if bool(hosts[hit].owned) else "ATTACK")])
			drag_from = -1; _refresh_panel(); queue_redraw(); return
		drag_from = -1
		if not moved: _click_select(hit)
		_refresh_panel(); queue_redraw()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:   # right-click = cancel / remove routes
		_cancel_at(hit); _refresh_panel(); queue_redraw()


func _click_select(hit: int) -> void:
	if hit < 0:
		sel_sources = {}; sel_target = -1
	elif bool(hosts[hit].owned):
		if sel_sources.has(hit): sel_sources.erase(hit)   # toggle a source in/out
		else: sel_sources[hit] = true
	else:
		sel_target = hit


func _cancel_at(hit: int) -> void:
	if hit < 0:
		sel_sources = {}; sel_target = -1; return
	if int(hosts[hit].assign) >= 0: hosts[hit].assign = -1
	for i in hosts.size():
		if int(hosts[i].assign) == hit: hosts[i].assign = -1
	if sel_sources.has(hit): sel_sources.erase(hit)
	if sel_target == hit: sel_target = -1
	_flash("Cancelled routes at %s" % str(hosts[hit].name))


func _host_at(p: Vector2) -> int:
	for i in hosts.size():
		if (hosts[i].pos as Vector2).distance_to(p) <= R + 5.0: return i
	return -1


# commit the links (step 2): the linked sources start sending bots to the target
func _commit() -> void:
	if sel_target < 0: return
	var n := 0
	for s in sel_sources.keys():
		if _link_kind(int(s), sel_target) != "": hosts[int(s)].assign = sel_target; n += 1
	if n > 0: _flash(("Attacking " if not bool(hosts[sel_target].owned) else "Defending ") + str(hosts[sel_target].name))
	sel_sources = {}; _refresh_panel()


func _reset() -> void:
	won = false; lost = false; paused = false; _t = 0.0; _enemy_timer = ENEMY_CADENCE
	sel_sources = {}; sel_target = -1; drag_from = -1
	_gen(); _refresh_panel()


func _flash(m: String) -> void: _msg = m; _msg_t = 4.0


# ============================================================ UI PANEL
func _plabel(txt: String, sz := 15, col := Color(0.85, 0.9, 1.0)) -> void:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(362, 0)
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
		_plabel("DEFEATED — you lost every node.", 20, Color(1, 0.5, 0.5)); _btn("Reset", _reset); return
	if sel_target >= 0 or not sel_sources.is_empty():
		var defend: bool = sel_target >= 0 and bool(hosts[sel_target].owned)
		_plabel("LINKS → " + ("DEFEND" if defend else "ATTACK"), 18)
		if sel_target >= 0: _plabel("①  Linked to: %s  (%d bots)" % [str(hosts[sel_target].name), int(hosts[sel_target].bots)], 15, Color(1, 0.9, 0.5))
		else: _plabel("①  Drag onto a node to link it", 14, Color(0.7, 0.8, 0.9))
		var nb := 0.0; var elig := 0
		for s in sel_sources.keys():
			nb += float(hosts[int(s)].bots)
			if sel_target >= 0 and _link_kind(int(s), sel_target) != "": elig += 1
		if sel_sources.is_empty():
			_plabel("②  From: drag your nodes onto the target", 14, Color(0.7, 0.8, 0.9))
		else:
			_plabel("②  From: %d node(s) · %d bots%s" % [sel_sources.size(), int(nb), ("   (%d linked)" % elig) if sel_target >= 0 else ""], 15)
		if defend:
			_btn("③  🛡  DEFEND — send bots to hold", _commit, elig > 0)
		else:
			_btn("③  ⚔  ATTACK — send the bots", _commit, elig > 0)
		_btn("Clear links", func(): sel_sources = {}; sel_target = -1; _refresh_panel())
	else:
		_plabel("DRAG from your node to another to LINK it.", 15)
		_plabel("Enemy → ATTACK, friendly → DEFEND. Then press the button.", 14, Color(0.7, 0.8, 0.9))
		_plabel("Bots act only when they ARRIVE. Right-click a node to cancel. SPACE pauses.", 13, Color(0.6, 0.7, 0.8))
	if paused: _plabel("— PAUSED —", 16, Color(1, 0.9, 0.4))


func _hud_text() -> String:
	var mine := 0; var mybots := 0.0; var enemybots := 0.0
	for h in hosts:
		if bool(h.owned): mine += 1; mybots += float(h.bots)
		else: enemybots += float(h.bots)
	return "BOTNET  ·  your nodes %d / %d  ·  your bots %d  ·  enemy bots %d  ·  take the HUB → OVERLOAD" % [
		mine, hosts.size(), int(mybots), int(enemybots)]


# ============================================================ DRAW
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		paused = not paused; _refresh_panel(); queue_redraw()


func _draw() -> void:
	var f := get_theme_default_font()
	for i in hosts.size():   # network links
		for j in hosts[i].links:
			if j < i: continue
			var both: bool = bool(hosts[i].owned) and bool(hosts[j].owned)
			draw_line(hosts[i].pos, hosts[j].pos, Color(0.3, 1, 0.55, 0.45) if both else Color(0.35, 0.5, 0.7, 0.2), 2.0 if both else 1.0, true)
	# committed route lines (bright, with arrow) + the link preview
	for i in hosts.size():
		if int(hosts[i].assign) >= 0: _draw_route_line(_route(i, int(hosts[i].assign)), int(hosts[i].assign))
	if sel_target >= 0:
		for s in sel_sources.keys():
			if _link_kind(int(s), sel_target) != "": _draw_route_line(_route(int(s), sel_target), sel_target)
	# in-flight bot packets — the only thing that "moves"; they act on arrival
	for fl in flights:
		var rt: Array = fl.route
		if rt.size() < 2: continue
		var frac := clampf(float(fl.t) / maxf(float(fl.dur), 0.01), 0.0, 1.0)
		var seg := float(rt.size() - 1) * frac
		var si: int = clampi(int(floor(seg)), 0, rt.size() - 2)
		var pp := (hosts[int(rt[si])].pos as Vector2).lerp(hosts[int(rt[si + 1])].pos, seg - float(si))
		var col: Color = Color(0.5, 1, 0.7) if bool(fl.player) else Color(1, 0.45, 0.4)
		draw_circle(pp, 3.5, col)   # a single bot streaming along the route
	# nodes
	for i in hosts.size():
		var p: Vector2 = hosts[i].pos
		var fill: Color
		if bool(hosts[i].hub): fill = Color(0.2, 0.9, 1.0) if not bool(hosts[i].owned) else Color(0.3, 0.9, 0.6)
		elif bool(hosts[i].owned): fill = Color(0.25, 0.85, 0.45)
		else: fill = Color(0.75, 0.3, 0.33)
		draw_circle(p, R, fill)
		if sel_sources.has(i): draw_arc(p, R + 6.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 3.0, true)
		if i == sel_target: draw_arc(p, R + 8.0, 0.0, TAU, 32, Color(1, 0.9, 0.3), 3.0, true)
		# bots bar + number (the node's power/health)
		var fr: float = clampf(float(hosts[i].bots) / NODE_CAP, 0.0, 1.0)
		draw_rect(Rect2(p.x - R, p.y + R + 5.0, R * 2.0, 5.0), Color(0.1, 0.12, 0.16), true)
		draw_rect(Rect2(p.x - R, p.y + R + 5.0, R * 2.0 * fr, 5.0), Color(0.4, 1, 0.6) if bool(hosts[i].owned) else Color(1, 0.5, 0.5), true)
		draw_string(f, p + Vector2(-10, 5), "%d" % int(round(float(hosts[i].bots))), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.05, 0.08, 0.1))
		draw_string(f, p + Vector2(-R - 2.0, -R - 7.0), str(hosts[i].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.92, 1.0))
	# drag line on top + reachable highlights
	if drag_from >= 0:
		for i in hosts.size():
			var k := _link_kind(drag_from, i)
			if k != "": draw_arc(hosts[i].pos, R + 7.0, 0.0, TAU, 32, (Color(1, 0.7, 0.3, 0.85) if k == "attack" else Color(0.4, 1, 0.7, 0.85)), 2.5, true)
		var sp: Vector2 = hosts[drag_from].pos
		draw_line(sp, drag_pos, Color(0.75, 1, 1, 0.95), 3.0, true)
		draw_circle(sp, 6.0, Color(0.75, 1, 1, 0.95)); draw_circle(drag_pos, 5.0, Color(0.75, 1, 1, 0.95))
	if _msg_t > 0.0:
		draw_string(f, Vector2(20, 44), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 1, 1, clampf(_msg_t, 0, 1)))
	if won or lost:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.55), true)
		draw_string(f, get_viewport_rect().size * 0.5 + Vector2(-180, 0), ("CITY  OVERLOAD" if won else "DEFEATED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(0.5, 1, 1) if won else Color(1, 0.5, 0.5))


func _draw_route_line(rt: Array, tgt: int) -> void:
	if rt.size() < 2: return
	var col: Color = Color(0.4, 1, 0.7) if bool(hosts[tgt].owned) else Color(1, 0.85, 0.35)
	var pts := PackedVector2Array()
	for idx in rt: pts.append(hosts[int(idx)].pos)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.3), 6.0, true)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.9), 2.5, true)
	var a: Vector2 = hosts[int(rt[rt.size() - 2])].pos
	var b: Vector2 = hosts[int(rt[rt.size() - 1])].pos
	var dir: Vector2 = (b - a).normalized()
	var tip: Vector2 = b - dir * (R + 3.0)
	var perp := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 14.0 + perp * 8.0, tip - dir * 14.0 - perp * 8.0]), Color(col.r, col.g, col.b, 0.9))
