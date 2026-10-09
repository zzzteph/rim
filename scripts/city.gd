extends Node2D
## RIM — city map (isometric, composed, asymmetric). A believable cyberpunk city:
##  • an ASYMMETRIC development footprint (organic mask) surrounded by countryside (no water),
##  • an EXPLICIT road network (varied spacing, no perimeter frame, arterials + local streets,
##    cul-de-sacs) — each road tile drawn from its real connections
##    (straight / bend / T / crossroads / endpoint),
##  • BLOCKS derived from the road network (varied sizes), each a complete site: downtown with a
##    square, apartment courtyards, suburbs with gardens, shopping-centre grounds, parks.
## High-angle dimetric (64×48). Deterministic from Session.seed. Selection + hover are live.

const TILE_W := 64.0
const TILE_H := 58.0   # 64×58 steep dimetric (~65° camera elevation) — looking down onto the city so tall
                        # buildings cover far less of what stands behind them
const HEIGHT_K := 0.36  # FULL (raised) building height scale: ~65° foreshortening (0.54) × 2/3
const FLAT_DEFAULT := 0.12   # the DEFAULT look: buildings low and small (the user's favourite view);
                             # hold F to raise them to full height (×1.0)
const HW := TILE_W * 0.5
const HH := TILE_H * 0.5
const SPACING := 0.035   # extra inset per side → building footprints ~15% smaller (a more spacious city)
const MIN_BLOCK := 3    # blocks smaller than this are slivers → landscaped verge, never a build site
const GRID_COL := Color(0.2, 0.85, 1.0, 0.11)   # faint neon "cyberspace" grid on built ground
const DETAIL_Z0 := 0.75   # architectural detail (floor bands, panel lines, roof gear) fades in from here…
const DETAIL_Z1 := 1.25   # …to fully drawn here
const LOD_ZOOM := 0.5   # below this (overview) the baked buildings are flat tops + a faint rim
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]   # N E S W

const KINDS := {
	"res": ["fh", "ap", "sc"], "com": ["shop_s", "shop_b", "mall"], "bus": ["off_s", "off_m", "corp"],
}
const KIND_NAME := {
	"fh": "Family House", "ap": "Apartment", "sc": "Residential Tower",
	"shop_s": "Corner Shop", "shop_b": "Store", "mall": "Shopping Centre",
	"off_s": "Small Office", "off_m": "Office", "corp": "Corporate Tower", "tree": "Tree",
	"hub": "Central HUB",
}
const DTYPE_NAME := {"res": "Residential", "com": "Commercial", "bus": "Corporate", "park": "Green"}
const AREA_NAME := {
	"res": ["Suburb", "Apartments", "Residential Towers"],
	"com": ["Local Shops", "Shopping Centre", "Shopping Centre"],
	"bus": ["Office Park", "Downtown", "Downtown Core"],
	"park": ["Pocket Park", "Park", "Central Park"],
}
# District names: a seeded random prefix + a zone-flavoured suffix, unique per map — the word lists
# live in data/city_lore.json ("district_names").
# Gibson's matrix: every district is its own neon construct. Hue FAMILY still hints at the zone
# (cold blues/violets = corporate, magentas/oranges = commerce, ambers = habs, greens = parks); within
# a family, adjacent districts always get different hues so territories read apart.
const DISTRICT_HUES := {
	"bus": [Color(0.3, 0.9, 1.0), Color(0.4, 0.55, 1.0), Color(0.35, 1.0, 0.8), Color(0.65, 0.45, 1.0), Color(0.78, 0.92, 1.0), Color(0.2, 0.7, 0.95)],
	"com": [Color(1.0, 0.35, 0.8), Color(1.0, 0.3, 0.5), Color(1.0, 0.55, 0.25), Color(0.85, 0.35, 1.0)],
	"res": [Color(1.0, 0.7, 0.3), Color(1.0, 0.86, 0.4), Color(0.95, 0.5, 0.35), Color(0.85, 0.78, 0.55)],
	"park": [Color(0.4, 0.95, 0.45), Color(0.6, 1.0, 0.35)],
}
const DISTRICT_AREA := 28   # target cells per district: big road blocks split into several territories

var seed := 0
var rng := RandomNumberGenerator.new()
var name_rng := RandomNumberGenerator.new()
var _grid := Vector2i.ZERO
var land := {}         # Vector2i -> true  (developed footprint)
var roads := {}        # Vector2i -> true  (road tiles)
var road_class := {}   # Vector2i -> "art" | "loc"
var deco := {}         # Vector2i -> ground role
var lots := {}         # Vector2i -> building {kind,vari,h,dtype,area,tw,td,ins,did}
var occ := {}          # Vector2i -> anchor tile
var hub_key := Vector2i(-999, -999)   # anchor of the CENTRAL HUB tower
var hub_site := Vector2i(-999, -999)  # the planned 2×2 HUB footprint (chosen nearest the city centre)
var trees := []        # {tile:Vector2, sz, wild:bool}
var districts := []    # {id,type,tier,name,centroid_tile,count}
var country := {}      # Vector2i -> int tile distance to the city (the unmapped void around it)
var dist_of := {}      # Vector2i -> district id (every non-road developed tile)
var _world := Rect2()

var camera: Camera2D
var _panning := false
var _lmb_down := false
var _lmb_moved := false
var _hover_tile := Vector2i(-999, -999)
var _hover_b := Vector2i(-999, -999)    # building under the cursor (by its drawn SHAPE, like the click)
var _hover_m := Vector2(INF, INF)       # mouse world position the hover was last resolved at
var selected := Vector2i(-999, -999)
var sel_did := -1                       # selected DISTRICT (clicking any of its buildings or ground)
var _sel_edges := PackedVector2Array()  # selected district's perimeter, as segment pairs (overlay)
var _sel_tiles := []                    # selected district's ground tiles (overlay)
var _sel_lots := []                     # selected district's buildings, depth-sorted (overlay)
var _focus := []                        # building focus: [selected] + every building linked to it, depth-sorted
var _route := []                        # building focus: the chain of buildings from the selected one to the HUB
var _district_lots := {}                # district id -> [building anchor keys]
const CityLore := preload("res://scripts/city_lore.gd")
# "Optowired" city network: every building is a node. Inside a district, buildings are fibre-linked to
# each other (LOCAL); only GATEWAYS (each district's tallest building, two in big districts) link out to
# other districts (BACKBONE), with the Central HUB as the core.
var net_local := []        # [a, b] anchors — fibre inside one district
var net_backbone := []     # [a, b] anchors — gateway↔gateway links between districts
var net_links := {}        # anchor -> [linked anchors] (local + backbone)
var gateways := {}         # anchor -> true
var district_adj := {}     # district id -> [adjacent district ids]
var net_view := false      # N: full network view (city dims, every link lit)
var corp_info := {}        # megacorp name -> profile (see city_lore.gd)
var _paths_of := {}        # building anchor -> [link entries touching it] (hover / selection)
var _flat := FLAT_DEFAULT  # height factor: FLAT_DEFAULT normally, eases to 1.0 while F is held
var sel_corp: Label
var sel_people: Label
var sel_explore: Button
var _seps := []   # section rules in the side panel (shown with the section that follows)
var sel_bname: Label
var sel_meta: Label
var sel_story: Label
var _time := 0.0
# repaint gating + precomputed draw order (perf): redraw only on view/hover/state change, with a
# throttled tick for the neon animation; buildings+trees are depth-sorted ONCE at generation.
var _last_zoomv := Vector2.ZERO
var _last_hover := Vector2i(-9999, -9999)
var _last_hover_b := Vector2i(-9999, -9999)
var _anim_acc := 1.0
var _dirty := true
# Batched static bake: on EVERY map the whole static scene is accumulated into ONE triangle array
# (canvas_item_add_triangle_array) so a frame is a handful of draw calls instead of thousands (GL-compat
# won't batch per-colour draw_colored_polygon calls — that submission cost, not fill, was the wall).
var _bake_pts := PackedVector2Array()
var _bake_cols := PackedColorArray()
var _bake_idx := PackedInt32Array()
var _ground_pts := PackedVector2Array()   # static ground bake (built once per map)
var _ground_cols := PackedColorArray()
var _ground_idx := PackedInt32Array()
var _bake_tier := -99          # which tier (0 flat / 1 box) the arrays hold; -99 = unbuilt
var _bake_h := -1.0            # the _hmul() the arrays were baked at
var _bake_da := -1.0           # the detail alpha the arrays were baked at (quantised, so a fade = a few rebakes)
var _bake_fa := -1.0           # the rooftop-feature alpha the arrays were baked at (quantised the same way)
var _net_pts := PackedVector2Array()   # N view: the WHOLE network as one cached batch (built on demand)
var _net_cols := PackedColorArray()
var _net_idx := PackedInt32Array()
var _net_h := -1.0                     # the building height the network batch was built at
var _hover_txt := ""                   # last hover text (the label is only touched when it changes)
var _fx: Node2D         # lightweight overlay carrying ONLY the animated primitives (see _draw_fx)
var _draw_items := []   # [{b:bool, k/i, d:int}] sorted by iso depth
var title_lbl: Label
var hover_lbl: Label
var sel_panel: PanelContainer
var sel_title: Label
var sel_body: Label


func _ready() -> void:
	seed = Session.seed if Session.seed != 0 else randi()
	rng.seed = seed
	camera = Camera2D.new(); add_child(camera); camera.make_current()
	_generate()
	_frame()
	_fx = _FxLayer.new(); _fx.host = self; add_child(_fx)   # animated overlay, above the static scene
	_build_ui()
	if not Session.city_return.is_empty():   # came back from a building's local map → restore the view
		var cr: Dictionary = Session.city_return
		camera.position = Vector2(cr.cam[0], cr.cam[1]); camera.zoom = Vector2(cr.zoom, cr.zoom)
		var st := Vector2i(int(cr.sel[0]), int(cr.sel[1]))
		if lots.has(st): _select_building(st)
		Session.city_return = {}


func _iso(fx: float, fy: float) -> Vector2:
	return Vector2((fx - fy) * HW, (fx + fy) * HH)
func _in_grid(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < _grid.x and t.y < _grid.y
func _is_road(t: Vector2i) -> bool:
	return roads.has(t)


# ============================================================ GENERATION
func _grid_dims() -> Vector2i:
	match Session.city_size:
		"large":  return Vector2i(44, 35)   # ~15% bigger than v1.0 on every size
		"medium": return Vector2i(31, 25)
		_:        return Vector2i(21, 17)


func _generate() -> void:
	land = {}; roads = {}; road_class = {}; deco = {}; lots = {}; occ = {}; trees = []; districts = []; country = {}; dist_of = {}
	_district_lots = {}; sel_did = -1; _sel_edges = PackedVector2Array()
	net_local = []; net_backbone = []; net_links = {}; gateways = {}; district_adj = {}
	hub_key = Vector2i(-999, -999)
	var g := _grid_dims()
	_grid = g
	# 1) asymmetric development footprint
	var dcx := g.x * (0.5 + rng.randf_range(-0.12, 0.12))
	var dcy := g.y * (0.5 + rng.randf_range(-0.12, 0.12))
	var dev_c := Vector2(dcx, dcy)
	_build_land(g, dev_c)
	# 2) ROADS (explicit network) → repair into ONE connected network → 3) BLOCKS derived from it
	var down_c := _build_roads(g, dev_c)
	_repair_roads()
	var blocks := _split_blocks(_carve_blocks(g))
	if blocks.is_empty():
		_world = Rect2(Vector2.ZERO, Vector2(100, 100)); return
	# 4) DISTRICT PLAN — reserve sites, residential density by distance to downtown
	_plan_and_fill(blocks, g, down_c)
	# the unmapped void around the city + bounds
	_dress_countryside(g)
	_world = Rect2(_iso(0, float(g.y)), Vector2.ONE)
	for pt in [_iso(float(g.x), 0), _iso(0, 0) - Vector2(0, 150), _iso(float(g.x), float(g.y)) + Vector2(0, TILE_H)]:
		_world = _world.merge(Rect2(pt, Vector2.ONE))
	for k in lots:
		var did := int(lots[k].did)
		if not _district_lots.has(did): _district_lots[did] = []
		_district_lots[did].append(k)
	_stadium_heights()
	_clear_hidden()
	var lore := CityLore.new(seed)   # own rng stream: lore never changes the layout
	lore.make_orgs(districts)
	for k in lots: lore.describe(lots[k], districts[int(lots[k].did)])
	lore.finish(lots, districts)
	corp_info = lore.corp_info
	for r in districts:   # district population (sum of its homes)
		var pop := 0
		for k in _district_lots.get(int(r.id), []): pop += int(lots[k].get("pop", 0))
		r["pop"] = pop
	_build_network()
	_route_network()
	_build_draw_order()


func _depth(k: Vector2i) -> int:   # painter's depth (same key as the draw order)
	return k.x + k.y + int(lots[k].tw) + int(lots[k].td)


# Is building k's roof centre covered on screen by a building standing in FRONT of it, at height hm?
# Occluders can only be a few rows in front on nearly the same screen column, so only those cells are
# tested (via occ), not every building.
func _top_hidden(k: Vector2i, hm: float) -> bool:
	var p := _top_at(k, hm)
	var kd := _depth(k)
	var tested := {}
	for st in range(1, 22):
		for dd in range(-4, 5):
			if (st + dd) % 2 != 0: continue
			var t := Vector2i(k.x + (st + dd) / 2, k.y + (st - dd) / 2)
			if not occ.has(t): continue
			var o: Vector2i = occ[t]
			if o == k or tested.has(o) or _depth(o) <= kd: continue
			tested[o] = true
			if Geometry2D.is_point_in_polygon(p, _hull_at(o, hm)): return true
	return false


# GUARANTEE: no building is hidden behind another. Checked at the TALLEST any building ever draws
# (zoomed fully in, not flattened) — occlusion only shrinks as heights ease down with zoom. Front to
# back (a building's visibility depends only on what stands in front of it), any building whose roof is
# still covered is not built: its plot becomes open ground (a plaza, or a garden among homes).
func _clear_hidden() -> void:
	var order := lots.keys()
	order.sort_custom(func(a, b): return _depth(a) > _depth(b))
	for k in order:
		if k == hub_key or not lots.has(k): continue
		if _top_hidden(k, HEIGHT_K): _unbuild(k)


func _unbuild(k: Vector2i) -> void:
	var b = lots[k]
	var open_kind := "garden" if str(b.dtype) == "res" else "plaza"
	for dx in int(b.tw):
		for dy in int(b.td):
			var c := Vector2i(k.x + dx, k.y + dy)
			occ.erase(c); deco[c] = open_kind
	(_district_lots.get(int(b.did), []) as Array).erase(k)
	lots.erase(k)


# "Stadium" seating inside every district: among its 1×1 buildings the TALLEST stand at the back (far
# from the viewer, small x+y) and the lowest at the front, so a district never hides its own buildings.
# Whole building records are swapped between positions (footprints and occupancy are unchanged).
func _stadium_heights() -> void:
	for did in _district_lots:
		var ks := (_district_lots[did] as Array).filter(func(k): return k != hub_key and int(lots[k].tw) == 1 and int(lots[k].td) == 1)
		if ks.size() < 2: continue
		var recs := ks.map(func(k): return lots[k])
		ks.sort_custom(func(a, b): return (a.x + a.y < b.x + b.y) or (a.x + a.y == b.x + b.y and a.x < b.x))
		recs.sort_custom(func(a, b): return float(a.h) > float(b.h))
		for i in ks.size(): lots[ks[i]] = recs[i]


# ============================================================ NETWORK
func _lot_center(k: Vector2i) -> Vector2:   # footprint centre in tile coords
	return Vector2(k) + Vector2(float(lots[k].tw), float(lots[k].td)) * 0.5


func _link(a: Vector2i, b: Vector2i, backbone: bool) -> void:
	if a == b or (net_links.get(a, []) as Array).has(b): return
	if not net_links.has(a): net_links[a] = []
	if not net_links.has(b): net_links[b] = []
	net_links[a].append(b); net_links[b].append(a)
	(net_backbone if backbone else net_local).append([a, b])


# would a link a→b pass over a building already linked to a or b (i.e. one standing roughly between
# them)? Then a→b is a redundant "chord" (1→3 over 2) that only tangles the picture — never add it.
func _jumps_over(a: Vector2i, b: Vector2i) -> bool:
	var pa := _lot_center(a); var pb := _lot_center(b)
	var d := pa.distance_to(pb)
	for end in [a, b]:
		for m in net_links.get(end, []):
			if m == a or m == b: continue
			var pm := _lot_center(m)
			if pa.distance_to(pm) + pm.distance_to(pb) < 1.3 * d: return true
	return false


# the district-to-district version: would a→b run over an UPLINK neighbour of a or b (a gateway in another
# district linked to either end, standing roughly between them)? Local next-door neighbours don't count.
func _bb_jumps_over(a: Vector2i, b: Vector2i) -> bool:
	var pa := _lot_center(a); var pb := _lot_center(b)
	var d := pa.distance_to(pb)
	for end in [a, b]:
		for m in net_links.get(end, []):
			if m == a or m == b or int(lots[m].did) == int(lots[end].did): continue
			var pm := _lot_center(m)
			if pa.distance_to(pm) + pm.distance_to(pb) < 1.3 * d: return true
	return false


func _build_network() -> void:
	var gw_of := {}   # district id -> [gateway anchors]
	for did in _district_lots:
		var ks: Array = _district_lots[did]
		if ks.is_empty(): continue
		for k in ks:
			if not net_links.has(k): net_links[k] = []
		# LOCAL: a minimum spanning tree over the district's buildings (Prim) — every one wired in…
		var best := {}
		for k in ks:
			if k != ks[0]: best[k] = [_lot_center(k).distance_squared_to(_lot_center(ks[0])), ks[0]]
		while not best.is_empty():
			var nk: Vector2i = best.keys()[0]; var nd := INF
			for k in best:
				if float(best[k][0]) < nd: nd = float(best[k][0]); nk = k
			_link(nk, best[nk][1], false)
			best.erase(nk)
			for k in best:
				var d2: float = _lot_center(k).distance_squared_to(_lot_center(nk))
				if d2 < float(best[k][0]): best[k] = [d2, nk]
		# …plus short redundant links (every leaf, and some 2-link nodes) so it's a routed mesh, not a chain
		for k in ks:
			var deg := (net_links[k] as Array).size()
			if deg > 2 or (deg == 2 and _noise(k.x * 5 + 1, k.y * 5 + 7) < 0.25): continue
			var nb: Vector2i = k; var bd := 6.5
			for o in ks:
				if o == k or (net_links[k] as Array).has(o) or _jumps_over(k, o): continue
				var dd: float = _lot_center(k).distance_squared_to(_lot_center(o))
				if dd < bd: bd = dd; nb = o
			if nb != k: _link(k, nb, false)
		# GATEWAY candidates: the tallest building (the HUB in its own district), then more spread across the
		# district — one per ~8 buildings, up to 4 — so links to different neighbours leave from different
		# buildings (more of the city routes traffic) instead of all funnelling through one tower
		var tall := ks.duplicate()
		tall.sort_custom(func(a, c): return float(lots[a].h) > float(lots[c].h))
		var gws := [hub_key] if ks.has(hub_key) else [tall[0]]
		var n_gw := clampi(1 + ks.size() / 8, 1, 4)
		var pool := tall.slice(0, maxi(1, (tall.size() * 2) / 3))   # the taller two-thirds
		while gws.size() < n_gw:
			var far: Vector2i = gws[0]; var fd := -1.0
			for o in pool:   # farthest from every gateway chosen so far
				if gws.has(o): continue
				var md := INF
				for g in gws: md = minf(md, _lot_center(o).distance_squared_to(_lot_center(g)))
				if md > fd: fd = md; far = o
			if fd < 0.0: break
			gws.append(far)
		gw_of[did] = gws
		for g in gws: gateways[g] = true
	# BACKBONE: a spanning tree over districts (closest gateway pair per link) so every district reaches
	# every other; the HUB wired straight to its nearest districts as the core; a few extra links between
	# adjacent districts for redundancy.
	var dids: Array = gw_of.keys()
	if dids.size() < 2: return
	var pair_of := func(x: int, y: int) -> Array:
		var bp := [gw_of[x][0], gw_of[y][0]]; var bd := INF
		for ga in gw_of[x]:
			for gb in gw_of[y]:
				var dd: float = _lot_center(ga).distance_squared_to(_lot_center(gb))
				if dd < bd: bd = dd; bp = [ga, gb]
		return [bp, bd]
	var joined := {dids[0]: true}
	while joined.size() < dids.size():
		var best_p := []; var best_d := INF; var best_y := -1
		for x in joined:
			for y in dids:
				if joined.has(y): continue
				var pr: Array = pair_of.call(x, y)
				if float(pr[1]) < best_d: best_d = float(pr[1]); best_p = pr[0]; best_y = y
		_link(best_p[0], best_p[1], true)
		joined[best_y] = true
	if lots.has(hub_key):
		var hd := int(lots[hub_key].did)
		var hc := _lot_center(hub_key)
		var gw_near := {}   # each district's gateway nearest the HUB
		for x in dids:
			if x == hd: continue
			var bg: Vector2i = gw_of[x][0]
			for g in gw_of[x]:
				if _lot_center(g).distance_squared_to(hc) < _lot_center(bg).distance_squared_to(hc): bg = g
			gw_near[x] = bg
		var near: Array = gw_near.keys()
		near.sort_custom(func(x, y): return _lot_center(gw_near[x]).distance_squared_to(hc) < _lot_center(gw_near[y]).distance_squared_to(hc))
		var hub_n := 0
		for x in near:   # direct HUB spokes: up to 4, only to NEARBY districts (≤7 tiles), never over another uplink
			if hub_n >= 4 or _lot_center(gw_near[x]).distance_to(hc) > 7.0: break
			if _bb_jumps_over(hub_key, gw_near[x]): continue
			_link(hub_key, gw_near[x], true); hub_n += 1
	for x in dids:
		for y in district_adj.get(x, []):
			if y <= x or not gw_of.has(y) or _noise(x * 13 + 3, y * 17 + 5) < 0.15: continue
			var pr: Array = pair_of.call(x, y)
			if not _bb_jumps_over(pr[0][0], pr[0][1]): _link(pr[0][0], pr[0][1], true)
	# every district links to at least TWO other districts (nearest neighbours first) — no dead-end district
	# hanging off the network by a single link, and the city is a mesh, not just spokes into the HUB
	var peers := {}
	for x in dids: peers[x] = {}
	for e in net_backbone:
		var da := int(lots[e[0]].did); var db := int(lots[e[1]].did)
		if da != db: peers[da][db] = true; peers[db][da] = true
	for x in dids:
		if peers[x].size() >= 2: continue
		var cands := dids.filter(func(y): return y != x and not peers[x].has(y))
		var adj_x: Array = district_adj.get(x, [])
		cands.sort_custom(func(y1, y2):   # adjacent districts first, then by gateway distance
			var a1 := adj_x.has(y1); var a2 := adj_x.has(y2)
			if a1 != a2: return a1
			return float(pair_of.call(x, y1)[1]) < float(pair_of.call(x, y2)[1]))
		if cands.is_empty(): continue
		# only NEARBY candidates: within 1.5× the nearest one's distance (or 6 tiles). First a clean link among
		# them; if every nearby one would be a chord, the nearest one anyway — never a far-away district.
		var d0 := sqrt(float(pair_of.call(x, cands[0])[1]))
		var reach := maxf(d0 * 1.5, 6.0)
		for pass_i in 2:
			for y in cands:
				if peers[x].size() >= 2 or peers[x].has(y): continue
				var pr: Array = pair_of.call(x, y)
				if sqrt(float(pr[1])) > reach: continue
				if pass_i == 0 and _bb_jumps_over(pr[0][0], pr[0][1]): continue
				_link(pr[0][0], pr[0][1], true)
				peers[x][y] = true; peers[y][x] = true
	# a gateway is a building that ACTUALLY uplinks to another district (a candidate the backbone never
	# used is just a local node)
	gateways = {}
	for e in net_backbone:
		gateways[e[0]] = true; gateways[e[1]] = true


# ---- circuit-trace routing: every link becomes a GROUND-LEVEL path, like traces on a circuit board.
# Local links are right-angled traces with a 45° chamfer at the corner, nudged sideways a little per link
# so parallel traces don't merge. Backbone links run along the STREETS as fibre trunks (shortest road
# path between the two gateways). Each entry becomes [a, b, tile_path, iso_path, length].
func _route_network() -> void:
	_paths_of = {}
	for e in net_local:
		var o := float(((e[0].x * 7 + e[1].y * 3) % 5) - 2) * 0.09
		_finish_path(e, _trace_path(_lot_center(e[0]), _lot_center(e[1]), o))
	for e in net_backbone:
		_finish_path(e, _street_path(e[0], e[1]))


func _finish_path(e: Array, path: PackedVector2Array) -> void:
	var iso := PackedVector2Array(); var length := 0.0
	for i in path.size():
		iso.append(_iso(path[i].x, path[i].y))
		if i > 0: length += path[i].distance_to(path[i - 1])
	e.append(path); e.append(iso); e.append(length)
	for k in [e[0], e[1]]:
		if not _paths_of.has(k): _paths_of[k] = []
		_paths_of[k].append(e)


func _trace_path(a: Vector2, b: Vector2, o: float) -> PackedVector2Array:
	var p0 := a + Vector2(0, o); var p1 := b + Vector2(o, 0)
	var corner := Vector2(p1.x, p0.y)
	var dx := corner.x - p0.x; var dy := p1.y - corner.y
	if absf(dx) < 0.05 or absf(dy) < 0.05: return PackedVector2Array([p0, p1])
	var ch := minf(0.3, minf(absf(dx), absf(dy)) * 0.5)   # 45° chamfer, circuit-board style
	return PackedVector2Array([p0, corner - Vector2(signf(dx) * ch, 0), corner + Vector2(0, signf(dy) * ch), p1])


func _road_next_to(k: Vector2i) -> Vector2i:   # nearest street cell to a building's footprint
	var c := _lot_center(k); var best := Vector2i(-999, -999); var bd := INF
	for dx in range(-5, 7):
		for dy in range(-5, 7):
			var t := k + Vector2i(dx, dy)
			if not roads.has(t): continue
			var d: float = (Vector2(t) + Vector2(0.5, 0.5)).distance_squared_to(c)
			if d < bd: bd = d; best = t
	return best


func _street_path(a: Vector2i, b: Vector2i) -> PackedVector2Array:
	var sa := _road_next_to(a); var sb := _road_next_to(b)
	if sa.x < -900 or sb.x < -900: return _trace_path(_lot_center(a), _lot_center(b), 0.0)
	var prev := {sa: sa}; var q := [sa]; var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]; head += 1
		if cur == sb: break
		for d in DIRS:
			var nb: Vector2i = cur + d
			if roads.has(nb) and not prev.has(nb):
				prev[nb] = cur; q.append(nb)
	if not prev.has(sb): return _trace_path(_lot_center(a), _lot_center(b), 0.0)
	var cells := [sb]
	while cells[cells.size() - 1] != sa: cells.append(prev[cells[cells.size() - 1]])
	cells.reverse()
	var path := PackedVector2Array([_lot_center(a)])
	for cc in cells: path.append(Vector2(cc) + Vector2(0.5, 0.5))
	path.append(_lot_center(b))
	var out := PackedVector2Array([path[0]])   # drop collinear points
	for i in range(1, path.size() - 1):
		if not is_zero_approx((path[i] - path[i - 1]).cross(path[i + 1] - path[i])): out.append(path[i])
	out.append(path[path.size() - 1])
	return out


func _path_point(e: Array, t: float) -> Vector2:   # tile-coord point at fraction t along a link's path
	var path: PackedVector2Array = e[2]
	var target := t * float(e[4])
	for i in range(1, path.size()):
		var sl := path[i].distance_to(path[i - 1])
		if target <= sl: return path[i - 1].lerp(path[i], target / maxf(sl, 0.0001))
		target -= sl
	return path[path.size() - 1]


# a link as a neon tube in the overlay: soft halo + band + white-hot core (constant on-screen width)
func _glow_path(c: CanvasItem, pts: PackedVector2Array, col: Color, px: float, strong := 1.0) -> void:
	c.draw_polyline(pts, Color(col.r, col.g, col.b, 0.12 * strong), 10.0 * px, true)
	c.draw_polyline(pts, Color(col.r, col.g, col.b, 0.32 * strong), 4.5 * px, true)
	var core := col.lerp(Color.WHITE, 0.55); core.a = 0.95 * strong
	c.draw_polyline(pts, core, 1.7 * px, true)


# a packet with a comet tail (head + three fading trail dots)
func _comet(c: CanvasItem, e: Array, t: float, col: Color, px: float, size: float) -> void:
	var L := maxf(float(e[4]), 0.5)
	for i in 4:
		var tt := t - float(i) * 0.22 / L
		if tt < 0.0: break
		var pp := _path_point(e, tt)
		c.draw_circle(_iso(pp.x, pp.y), size * px * (1.0 - 0.18 * float(i)), Color(col.r, col.g, col.b, 0.95 - 0.26 * float(i)), true, -1.0, true)


# ---- ARCS: a link drawn as an arc of light from rooftop to rooftop (reads instantly as "A ↔ B") ----
func _arc_lift(a: Vector2, b: Vector2, backbone: bool) -> float:
	return (24.0 + a.distance_to(b) * 0.18) if backbone else (8.0 + a.distance_to(b) * 0.12)


func _arc_pts(a: Vector2, b: Vector2, lift: float, segs := 12) -> PackedVector2Array:
	var m := (a + b) * 0.5 + Vector2(0, -lift)
	var pts := PackedVector2Array()
	for i in segs + 1:
		var t := float(i) / float(segs)
		pts.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
	return pts


func _arc_at(a: Vector2, b: Vector2, lift: float, t: float) -> Vector2:
	var m := (a + b) * 0.5 + Vector2(0, -lift)
	return a.lerp(m, t).lerp(m.lerp(b, t), t)


# the arc of a link between two buildings: [points, roof a, roof b, lift]
func _link_arc(a: Vector2i, b: Vector2i) -> Array:
	var pa := _building_top_center(a); var pb := _building_top_center(b)
	var lift := _arc_lift(pa, pb, int(lots[a].did) != int(lots[b].did))
	return [_arc_pts(pa, pb, lift), pa, pb, lift]


# light flowing along an arc from a to b: short bright dashes marching at a steady on-screen speed
func _flow_arc(c: CanvasItem, arc: Array, col: Color, px: float) -> void:
	if Settings.reduced_motion: return
	var pa: Vector2 = arc[1]; var pb: Vector2 = arc[2]; var lift: float = arc[3]
	var L := pa.distance_to(pb) + lift * 1.2
	if L < 2.0: return
	var spacing := 26.0; var dash := 9.0
	var hot := col.lerp(Color.WHITE, 0.7)
	var sd := fmod(_time * 70.0, spacing)
	while sd < L:
		c.draw_line(_arc_at(pa, pb, lift, sd / L), _arc_at(pa, pb, lift, minf((sd + dash) / L, 1.0)), hot, 2.6 * px, true)
		sd += spacing


func _comet_arc(c: CanvasItem, arc: Array, t: float, col: Color, px: float, size: float) -> void:
	var pa: Vector2 = arc[1]; var pb: Vector2 = arc[2]; var lift: float = arc[3]
	var L := maxf(pa.distance_to(pb) + lift * 1.2, 1.0)
	for i in 4:
		var tt := t - float(i) * 7.0 / L
		if tt < 0.0: break
		c.draw_circle(_arc_at(pa, pb, lift, tt), size * px * (1.0 - 0.18 * float(i)), Color(col.r, col.g, col.b, 0.95 - 0.26 * float(i)), true, -1.0, true)


# a pulsing ring on the ground around a building's footprint (iso ellipse)
func _ground_ring(c: CanvasItem, k: Vector2i, col: Color, px: float) -> void:
	var ctr := _lot_center(k)
	var r := 0.55 * maxf(float(lots[k].tw), float(lots[k].td)) + 0.12 * (0.5 + 0.5 * sin(_time * 4.0))
	var pts := PackedVector2Array()
	for i in 25:
		var a := float(i) / 24.0 * TAU
		pts.append(_iso(ctr.x + r * cos(a), ctr.y + r * sin(a)))
	c.draw_polyline(pts, Color(col.r, col.g, col.b, 0.9), 2.0 * px, true)


# DISTRICT FOCUS network (the only always-animated network drawing left; N is a static batch and the
# default view shows no data flow at all): the district's own wiring as ground traces with packets, its
# uplinks as glowing arcs with packets.
func _draw_net(c: CanvasItem) -> void:
	if sel_did < 0: return
	var px := 1.0 / camera.zoom.x   # one screen pixel in world units
	var anim := not Settings.reduced_motion
	for e in net_local:
		var did := int(lots[e[0]].did)
		if did != sel_did: continue
		var dc := _dcol(did)
		c.draw_polyline(e[3], Color(dc.r, dc.g, dc.b, 0.14), 6.0 * px, true)
		c.draw_polyline(e[3], dc.lerp(Color.WHITE, 0.35), 1.5 * px, true)
		if anim:
			var t := fmod(_time * 1.6 / maxf(float(e[4]), 0.5) + float((e[0].x * 7 + e[1].y * 13) % 17) / 17.0, 1.0)
			_comet(c, e, t, dc.lerp(Color.WHITE, 0.6), px, 2.2)
	for e in net_backbone:
		if int(lots[e[0]].did) != sel_did and int(lots[e[1]].did) != sel_did: continue
		var arc := _link_arc(e[0], e[1])
		_glow_path(c, arc[0], Color(0.45, 0.92, 1.0), px, 1.0)
		if anim:
			for j in 2:
				var t := fmod(_time * 0.3 + 0.5 * float(j) + float((e[0].x * 11 + e[0].y * 3) % 23) / 23.0, 1.0)
				_comet_arc(c, arc, t, Color(0.85, 1.0, 1.0), px, 2.6)


# BUILDING FOCUS (a building was clicked): the city sinks into shadow; every link of the building is a
# glowing ARC with light flowing OUT to its neighbours; the route onward to the Central HUB is a chain of
# fainter white arcs; each linked building is lit in its district's hue, ringed and named; the clicked
# building itself is brightest.
func _draw_focus(c: CanvasItem) -> void:
	var px := 1.0 / camera.zoom.x
	c.draw_rect(_world.grow(4000.0), Color(0.0, 0.0, 0.02, 0.66))
	_focus.sort_custom(func(a, b): return _depth(a) < _depth(b))
	var direct: Array = net_links.get(selected, [])
	for k in _focus:   # depth-sorted: neighbours lit + ringed, route-to-HUB lit, the selected one brightest
		if direct.has(k): _ground_ring(c, k, _dcol(int(lots[k].did)).lerp(Color.WHITE, 0.3), px)
		_fx_box(c, k, 2 if k == selected else 1)
	for i in range(1, _route.size()):   # the route onward to the Central HUB, hop by hop
		if _route[i - 1] == selected: continue
		var arc := _link_arc(_route[i - 1], _route[i])
		_glow_path(c, arc[0], Color(0.9, 1.0, 1.0), px, 0.55)
		_flow_arc(c, arc, Color(0.9, 1.0, 1.0), px)
	for o in direct:   # the building's own links: bright arcs, light flowing out to each neighbour
		var bb: bool = int(lots[o].did) != int(lots[selected].did)
		var col := Color(0.45, 0.92, 1.0) if bb else _dcol(int(lots[selected].did))
		var arc := _link_arc(selected, o)
		_glow_path(c, arc[0], col, px)
		_flow_arc(c, arc, col, px)


# gateways send a short beam of light up from the roof (network view / selected district)
func _draw_gateway_beams(c: CanvasItem) -> void:   # district focus only (N view beams are in its batch)
	if sel_did < 0: return
	var px := 1.0 / camera.zoom.x
	for g in gateways:
		if sel_did >= 0 and int(lots[g].did) != sel_did: continue
		var top := _building_top_center(g)
		c.draw_line(top, top + Vector2(0, -30), Color(0.8, 1.0, 1.0, 0.9), 2.0 * px, true)
		c.draw_circle(top + Vector2(0, -30), 3.0 * px, Color(0.9, 1.0, 1.0, 0.95), true, -1.0, true)


# buildings + trees depth-sorted ONCE (they never move), so _draw does no per-frame allocation/sort
func _build_draw_order() -> void:
	_draw_items = []
	for k in lots:
		_draw_items.append({"b": true, "k": k, "d": k.x + k.y + int(lots[k].td) + int(lots[k].tw)})
	for i in trees.size():
		var tt: Vector2 = trees[i].tile
		_draw_items.append({"b": false, "i": i, "d": int(tt.x + tt.y)})
	_draw_items.sort_custom(func(a, c): return a.d < c.d)


# asymmetric organic footprint: a lobed radial mask around the centre + value noise; leaves the map
# edges as countryside (no development reaching the border → no perimeter road).
func _build_land(g: Vector2i, c: Vector2) -> void:
	# a SUBSTANTIAL, CONTINUOUS footprint: a large radius with gentle lobes so the city stays one
	# connected landmass with a lightly irregular edge; countryside is the margin, not the map.
	var rbase := 0.82 * float(min(g.x, g.y)) * rng.randf_range(0.94, 1.06)
	var a1 := rng.randf() * TAU; var a2 := rng.randf() * TAU; var a3 := rng.randf() * TAU
	for ly in g.y:
		for lx in g.x:
			var t := Vector2i(lx, ly)
			var v := Vector2(lx, ly) - c
			var ang := atan2(v.y, v.x)
			var rr := rbase * (1.0 + 0.16 * sin(3.0 * ang + a1) + 0.1 * sin(5.0 * ang + a2) + 0.06 * sin(7.0 * ang + a3))
			rr += _noise(lx, ly) * rbase * 0.07
			# keep development off the very border (margin) so no edge can become a frame road
			if lx <= 0 or ly <= 0 or lx >= g.x - 1 or ly >= g.y - 1:
				continue
			if v.length() < rr:
				land[t] = true


# explicit road network: arterial + local lines at spacing that tightens toward downtown, clipped to
# the developed footprint (plus a couple of highways leaving to the edge).
func _build_roads(g: Vector2i, dev_c: Vector2) -> Vector2:
	if land.is_empty(): return dev_c
	var minx := g.x; var maxx := 0; var miny := g.y; var maxy := 0
	for t in land:
		minx = mini(minx, t.x); maxx = maxi(maxx, t.x); miny = mini(miny, t.y); maxy = maxi(maxy, t.y)
	var cx := int(round(dev_c.x)); var cy := int(round(dev_c.y))
	# irregular line positions, spacing 2 near centre → up to 5 at the edge
	var xs := _road_lines(minx + 1, maxx - 1, cx, float(maxx - minx) * 0.5)
	var ys := _road_lines(miny + 1, maxy - 1, cy, float(maxy - miny) * 0.5)
	# the central-most line on each axis is an arterial (avenue)
	var art_x: int = xs[0] if not xs.is_empty() else cx
	for x in xs:
		if abs(x - cx) < abs(art_x - cx): art_x = x
	var art_y: int = ys[0] if not ys.is_empty() else cy
	for y in ys:
		if abs(y - cy) < abs(art_y - cy): art_y = y
	# roads only on developed LAND.
	# Local streets MEANDER (a per-line sine wiggle, rasterised with a horizontal/vertical connector
	# at each step so the line stays 4-connected) → curvy blocks & districts. Arterials stay straight.
	for x in xs:
		var xc: int = int(x)
		var is_art: bool = xc == art_x
		var amp: float = 0.0 if is_art else rng.randf_range(0.6, 1.4)
		var fr := rng.randf_range(0.22, 0.42); var ph := rng.randf() * TAU
		var prevp: int = xc
		for ly in range(miny, maxy + 1):
			var target: int = xc + int(round(amp * sin(float(ly) * fr + ph)))
			var xx: int = prevp + clampi(target - prevp, -1, 1)   # slew ≤1/row: smooth curve, few connectors
			for xi in range(mini(prevp, xx), maxi(prevp, xx) + 1):
				_lay_road_cell(Vector2i(xi, ly), is_art)
			prevp = xx
	for y in ys:
		var yc: int = int(y)
		var is_art2: bool = yc == art_y
		var amp2: float = 0.0 if is_art2 else rng.randf_range(0.6, 1.4)
		var fr2 := rng.randf_range(0.22, 0.42); var ph2 := rng.randf() * TAU
		var prevq: int = yc
		for lx in range(minx, maxx + 1):
			var target2: int = yc + int(round(amp2 * sin(float(lx) * fr2 + ph2)))
			var yy: int = prevq + clampi(target2 - prevq, -1, 1)
			for yi in range(mini(prevq, yy), maxi(prevq, yy) + 1):
				_lay_road_cell(Vector2i(lx, yi), is_art2)
			prevq = yy
	# short leaving spurs: extend each arterial a couple tiles past the city toward the map edge
	_leave_spur(Vector2i(art_x, miny), Vector2i(0, -1))
	_leave_spur(Vector2i(art_x, maxy), Vector2i(0, 1))
	_leave_spur(Vector2i(minx, art_y), Vector2i(-1, 0))
	_leave_spur(Vector2i(maxx, art_y), Vector2i(1, 0))
	# organic suburban lanes: branching local streets that TURN (bends), BRANCH (T-junctions) and
	# dead-end (cul-de-sacs) — these break the pure grid and subdivide the big outer blocks.
	_add_organic_lanes()
	# downtown centre = densest land near dev centre
	return dev_c


func _lay_road_cell(t: Vector2i, is_art: bool) -> void:
	if land.has(t): _add_road(t, is_art)


# 4-connected components of the road set
func _road_components() -> Array:
	var seen := {}; var comps := []
	for start in roads:
		if seen.has(start): continue
		var stack := [start]; var comp := []
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			if seen.has(cur) or not roads.has(cur): continue
			seen[cur] = true; comp.append(cur)
			for d in DIRS: stack.append(cur + d)
		comps.append(comp)
	return comps


# Guarantee ONE connected street network (the "connected streets" acceptance item): keep the largest
# component; reconnect any sizeable fragment to it with a carved L-connector; delete stray dots.
func _repair_roads() -> void:
	if roads.is_empty(): return
	var comps := _road_components()
	if comps.size() <= 1: return
	comps.sort_custom(func(a, b): return a.size() > b.size())
	var main: Array = comps[0]
	for i in range(1, comps.size()):
		var comp: Array = comps[i]
		if comp.size() < 4:
			for t in comp: roads.erase(t); road_class.erase(t)   # stray fragment / isolated dot
			continue
		# reconnect: carve from the fragment tile nearest the main network toward it
		var from: Vector2i = comp[0]; var to: Vector2i = main[0]; var bd := INF
		for a in comp:
			for b in main:
				var d: float = Vector2(a).distance_squared_to(Vector2(b))
				if d < bd: bd = d; from = a; to = b
		_carve_connector(from, to)
		main.append_array(comp)


func _carve_connector(a: Vector2i, b: Vector2i) -> void:
	var cur := a; var guard := 0
	while cur != b and guard < 300:
		guard += 1
		if cur.x != b.x: cur.x += signi(b.x - cur.x)
		elif cur.y != b.y: cur.y += signi(b.y - cur.y)
		if _in_grid(cur): _add_road(cur, false)   # may cross a gap to stay connected


func _turn(d: Vector2i, left: bool) -> Vector2i:
	return Vector2i(d.y, -d.x) if left else Vector2i(-d.y, d.x)


func _add_organic_lanes() -> void:
	var n: int = {"small": 2, "medium": 3, "large": 5}.get(Session.city_size, 2)
	for i in n:
		var rk := roads.keys()
		if rk.is_empty(): return
		var s: Vector2i = rk[rng.randi() % rk.size()]
		var opts := []
		for d in DIRS:
			if land.has(s + d) and not roads.has(s + d): opts.append(d)
		if opts.is_empty(): continue
		_grow_lane(s + opts[rng.randi() % opts.size()], opts[rng.randi() % opts.size()], 2 + rng.randi() % 4, true)


func _grow_lane(cur: Vector2i, dir: Vector2i, length: int, allow_branch: bool) -> void:
	var steps := 0
	while steps < length and _in_grid(cur) and land.has(cur) and not roads.has(cur):
		_add_road(cur, false)
		steps += 1
		if rng.randf() < 0.35:
			dir = _turn(dir, rng.randf() < 0.5)                      # a bend
		if allow_branch and rng.randf() < 0.3:
			var bdir := _turn(dir, rng.randf() < 0.5)
			_grow_lane(cur + bdir, bdir, 1 + rng.randi() % 2, false) # a branch → T-junction
		cur += dir


# extend an arterial a short way past the developed edge toward the map border (a road out of town)
func _leave_spur(start: Vector2i, dir: Vector2i) -> void:
	var cur := start
	var steps := 0
	while _in_grid(cur) and steps < 5:
		if land.has(cur):
			cur += dir; steps += 1; continue
		if roads.has(cur - dir):   # only extend if the previous tile is already road (stay connected)
			_add_road(cur, true)
		else:
			break
		cur += dir; steps += 1


func _road_lines(lo: int, hi: int, centre: int, half: float) -> Array:
	var out := []
	if hi <= lo: return out
	var x := lo + rng.randi() % 2
	while x <= hi:
		out.append(x)
		var tdist: float = clampf(abs(x - centre) / maxf(half, 1.0), 0.0, 1.0)
		x += 6 + int(round(6.0 * tdist))      # 6 (downtown) … 12 (large outer blocks)
	return out


func _add_road(t: Vector2i, arterial: bool) -> void:
	if not _in_grid(t): return
	roads[t] = true
	if arterial or not road_class.has(t):
		road_class[t] = "art" if arterial else "loc"


func _road_dirs(t: Vector2i) -> Array:
	var out := []
	for d in DIRS:
		if roads.has(t + d): out.append(d)
	return out


# blocks = connected components of (land AND not road), 4-adjacency → varied sizes/shapes
func _carve_blocks(g: Vector2i) -> Array:
	var seen := {}
	var blocks := []
	for t in land:
		if roads.has(t) or seen.has(t): continue
		var stack := [t]; var cells := []
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			if seen.has(cur) or roads.has(cur) or not land.has(cur): continue
			seen[cur] = true; cells.append(cur)
			for d in DIRS: stack.append(cur + d)
		if cells.size() >= MIN_BLOCK:
			var cs := Vector2.ZERO
			for cc in cells: cs += Vector2(cc)
			blocks.append({"tiles": cells, "centroid": cs / float(cells.size())})
		else:
			for cc in cells: deco[cc] = "verge"   # sliver remnant → landscaped greenery, not a site
	return blocks


func _plan_and_fill(blocks: Array, g: Vector2i, dev_c: Vector2) -> void:
	blocks.sort_custom(func(a, b): return (a.centroid as Vector2).distance_to(dev_c) < (b.centroid as Vector2).distance_to(dev_c))
	var role := {}
	var n_down: int = {"small": 2, "medium": 3, "large": 5}.get(Session.city_size, 2)
	var n_biz: int = {"small": 1, "medium": 2, "large": 4}.get(Session.city_size, 1)   # satellite CBDs
	var n_shop: int = {"small": 1, "medium": 2, "large": 4}.get(Session.city_size, 1)
	var n_park: int = {"small": 1, "medium": 3, "large": 5}.get(Session.city_size, 1)
	var down_tier := 2   # every downtown is a corporate core (towers), whatever the map size
	var res_cap := 2
	# dense megacity housing: hab-stacks and towers dominate; detached houses only on the outer fringe
	var dens_scale: float = {"small": 0.95, "medium": 1.15, "large": 1.25}.get(Session.city_size, 0.95)
	var maxr := 0.0
	for b in blocks: maxr = maxf(maxr, (b.centroid as Vector2).distance_to(dev_c))
	# the CENTRAL HUB site: of every 2×2 footprint in every block, the one whose centre is nearest the
	# city's true centre (land centroid). Its block becomes the heart of the downtown core.
	var city_c := Vector2.ZERO
	for t in land: city_c += Vector2(t)
	city_c /= float(maxi(1, land.size()))
	var hub_i := 0; var bestd := INF
	hub_site = Vector2i(-999, -999)
	for i in blocks.size():
		var tset := {}
		for t in blocks[i].tiles: tset[t] = true
		for t in blocks[i].tiles:
			if tset.has(t + Vector2i(1, 0)) and tset.has(t + Vector2i(0, 1)) and tset.has(t + Vector2i(1, 1)):
				var dd: float = (Vector2(t) + Vector2(1, 1)).distance_to(city_c + Vector2(0.5, 0.5))
				if dd < bestd: bestd = dd; hub_i = i; hub_site = t
	role[hub_i] = {"type": "bus", "tier": down_tier}
	var down_c: Vector2 = blocks[hub_i].centroid
	# rest of downtown = the next central blocks (prefer reasonably sized ones)
	var dn := 1
	for i in blocks.size():
		if dn >= n_down: break
		if role.has(i): continue
		if int((blocks[i].tiles as Array).size()) >= 2:
			role[i] = {"type": "bus", "tier": down_tier}; dn += 1
	# satellite business districts — corporate clusters out in the inner-mid ring, spaced from the
	# core and each other so the city reads as several business quarters, not one tiny downtown
	var bizc := []
	for i in blocks.size():
		if bizc.size() >= n_biz: break
		if role.has(i): continue
		var br: float = (blocks[i].centroid as Vector2).distance_to(dev_c) / maxf(maxr, 1.0)
		if br > 0.2 and br < 0.7 and int((blocks[i].tiles as Array).size()) >= 3:
			var ok := (blocks[i].centroid as Vector2).distance_to(down_c) >= 5.0
			for s in bizc:
				if (blocks[i].centroid as Vector2).distance_to(blocks[s].centroid) < 5.0: ok = false
			if ok: role[i] = {"type": "bus", "tier": maxi(down_tier, 2)}; bizc.append(i)
	# shopping centres — mid-ring, spaced; a block only qualifies if a 2×2 mall actually FITS in it
	# (atomic reservation), so the retail destination is real. Always guarantee at least one site.
	var shops := []
	for i in blocks.size():
		if shops.size() >= n_shop: break
		if role.has(i): continue
		var r: float = (blocks[i].centroid as Vector2).distance_to(dev_c) / maxf(maxr, 1.0)
		if r > 0.2 and r < 0.8 and int((blocks[i].tiles as Array).size()) >= 4:   # room for a frontage + grounds
			var ok := true
			for s in shops:
				if (blocks[i].centroid as Vector2).distance_to(blocks[s].centroid) < 5.0: ok = false
			if ok: role[i] = {"type": "com", "tier": 1}; shops.append(i)
	if shops.is_empty():   # fallback: largest free block becomes a compact retail destination
		var bi := _largest_free_block(blocks, role)
		if bi >= 0: role[bi] = {"type": "com", "tier": 1}; shops.append(bi)
	# parks — scattered green; guarantee at least one usable green site
	var parks := 0
	for i in blocks.size():
		if parks >= n_park: break
		if role.has(i): continue
		if rng.randf() < 0.3:
			role[i] = {"type": "park", "tier": clampi(int((blocks[i].tiles as Array).size() / 5), 0, 2)}; parks += 1
	if parks == 0:
		var pbi := _largest_free_block(blocks, role)
		if pbi >= 0: role[pbi] = {"type": "park", "tier": 1}; parks += 1
	# residential — the rest, density by distance to downtown (one-tier smoothed below)
	for i in blocks.size():
		if role.has(i): continue
		var d: float = clampf((blocks[i].centroid as Vector2).distance_to(down_c) / maxf(maxr, 1.0), 0.0, 1.0)
		var dens := (1.0 - d) * dens_scale + _noise(int(blocks[i].centroid.x), int(blocks[i].centroid.y)) * 0.22
		# inner/mid houses are TERRACED (street-facing rows); the outer edge stays detached suburb
		role[i] = {"type": "res", "tier": clampi(int(round(dens * 2.0)), 0, res_cap), "terr": d < 0.6}
	# last-resort park guarantee for block-poor maps: convert the largest residential block so EVERY
	# map has usable green ground, not just a label (the measured "no park" maps)
	if parks == 0:
		var rbi := -1
		for want in ["res", "bus"]:   # prefer a residential block; else any non-HUB business block
			var rbs := 0
			for i in blocks.size():
				if i == hub_i or str(role[i].type) != want: continue
				if int((blocks[i].tiles as Array).size()) > rbs:
					rbs = int((blocks[i].tiles as Array).size()); rbi = i
			if rbi >= 0: break
		if rbi >= 0: role[rbi] = {"type": "park", "tier": 1}; parks += 1
	# one-tier smoothing between adjacent residential blocks (via shared road borders)
	var adj := _block_adjacency(blocks)
	district_adj = adj
	for pass_i in 3:
		for i in blocks.size():
			if str(role[i].type) != "res": continue
			for j in adj.get(i, []):
				if str(role[j].type) == "res" and int(role[i].tier) - int(role[j].tier) > 1:
					role[i].tier = int(role[j].tier) + 1
	# districts (merge connected same-type, within-one-tier res) + ids
	_assign_districts(blocks, role, adj)
	# fill each block — the HUB first, so the downtown fill builds around it
	_place_hub(blocks[hub_i].tiles, city_c, int(role[hub_i].get("did", 0)))
	for i in blocks.size():
		var tiles: Array = blocks[i].tiles
		if tiles.is_empty(): continue
		match str(role[i].type):
			"bus":  _fill_downtown(tiles, int(role[i].tier), int(role[i].get("did", 0)))
			"com":  _fill_shopping(tiles, int(role[i].get("did", 0)))
			"park": _fill_park(tiles)
			_:      _fill_residential(tiles, int(role[i].tier), int(role[i].get("did", 0)), bool(role[i].get("terr", false)))


# can a 2×2 mall footprint sit inside this block's cells? (atomic shopping-site capacity test)
func _block_fits_mall(tiles: Array) -> bool:
	var s := {}
	for t in tiles: s[t] = true
	for t in tiles:
		if s.has(t + Vector2i(1, 0)) and s.has(t + Vector2i(0, 1)) and s.has(t + Vector2i(1, 1)):
			return true
	return false


# largest block with no role yet (deterministic fallback for a required site)
func _largest_free_block(blocks: Array, role: Dictionary) -> int:
	var bi := -1; var bs := 0
	for i in blocks.size():
		if role.has(i): continue
		var sz: int = (blocks[i].tiles as Array).size()
		if sz > bs: bs = sz; bi = i
	return bi

func _block_adjacency(blocks: Array) -> Dictionary:
	# two blocks are adjacent if they touch (split territories) or a single road tile separates them
	var owner := {}
	for i in blocks.size():
		for t in blocks[i].tiles: owner[t] = i
	var adj := {}
	for i in blocks.size():
		adj[i] = {}
		for t in blocks[i].tiles:
			for d in DIRS:
				var across: Vector2i = t + d + d   # skip one road tile
				if roads.has(t + d) and owner.has(across) and owner[across] != i:
					adj[i][owner[across]] = true
				if owner.has(t + d) and owner[t + d] != i:
					adj[i][owner[t + d]] = true
	var out := {}
	for i in adj: out[i] = adj[i].keys()
	return out


# One district per (split) block — each its own named neon territory. Colour: a hue from the zone's
# family that no already-coloured adjacent district of the same family uses.
func _assign_districts(blocks: Array, role: Dictionary, adj: Dictionary) -> void:
	var used_names := {}
	name_rng.seed = seed * 7919 + 17   # own stream: naming/colouring never perturbs the layout
	for i in blocks.size():
		var typ: String = str(role[i].type)
		role[i]["did"] = i
		for t in blocks[i].tiles: dist_of[t] = i
		var fam: Array = DISTRICT_HUES.get(typ, DISTRICT_HUES.res)
		var taken := {}
		for j in adj.get(i, []):
			if j < i and str(districts[j].type) == typ: taken[int(districts[j].hue)] = true
		var start := name_rng.randi() % fam.size()
		var hi := start
		for o in fam.size():
			if not taken.has((start + o) % fam.size()): hi = (start + o) % fam.size(); break
		districts.append({"id": i, "type": typ, "tier": int(role[i].tier), "name": _district_name(typ, used_names),
			"centroid_tile": blocks[i].centroid, "count": 1, "size": (blocks[i].tiles as Array).size(),
			"hue": hi, "col": fam[hi]})


# Cyberspace territories: a big road block is split into several districts (~DISTRICT_AREA cells) by a
# multi-source BFS from spread-out (farthest-point) seeds — contiguous parts whose shared edges render
# as glowing borders. Roads stay sparse; districts no longer need a street between them.
func _split_blocks(blocks: Array) -> Array:
	var out := []
	for b in blocks:
		var tiles: Array = b.tiles
		var k := int(round(float(tiles.size()) / float(DISTRICT_AREA)))
		if k <= 1:
			out.append(b); continue
		var seeds := [tiles[0]]
		while seeds.size() < k:
			var best: Vector2i = tiles[0]; var bd := -1.0
			for t in tiles:
				var md := INF
				for sd in seeds: md = minf(md, Vector2(t).distance_squared_to(Vector2(sd)))
				if md > bd: bd = md; best = t
			seeds.append(best)
		var tset := {}
		for t in tiles: tset[t] = true
		var own := {}; var q := []
		for si in seeds.size():
			own[seeds[si]] = si; q.append(seeds[si])
		var head := 0
		while head < q.size():
			var cur: Vector2i = q[head]; head += 1
			for d in DIRS:
				var nb: Vector2i = cur + d
				if tset.has(nb) and not own.has(nb):
					own[nb] = own[cur]; q.append(nb)
		var parts := []
		for si in seeds.size(): parts.append([])
		for t in tiles: parts[int(own[t])].append(t)
		for part in parts:
			if part.is_empty(): continue
			var cs := Vector2.ZERO
			for cc in part: cs += Vector2(cc)
			out.append({"tiles": part, "centroid": cs / float(part.size())})
	return out


func _district_name(typ: String, used: Dictionary) -> String:
	var dn: Dictionary = CityLore.data().district_names   # content: data/city_lore.json
	var pre: Array = dn.prefixes; var solo: Array = dn.get("standalone", [])
	var sufs: Array = dn.suffixes.get(typ, dn.suffixes.res)
	for attempt in 40:
		var nm: String
		if typ == "res" and not solo.is_empty() and name_rng.randf() < 0.15:
			nm = solo[name_rng.randi() % solo.size()]
		else:
			nm = "%s %s" % [pre[name_rng.randi() % pre.size()], sufs[name_rng.randi() % sufs.size()]]
		if not used.has(nm):
			used[nm] = true; return nm
	var fb := "Sector %d" % (used.size() + 1)
	used[fb] = true
	return fb


func _area_name(did: int, dtype: String, tier: int) -> String:
	if did >= 0 and did < districts.size() and int(districts[did].id) == did:
		return str(districts[did].name)
	return AREA_NAME[dtype][tier]


func _place(k: Vector2i, kind: String, dtype: String, tier: int, ins: float, tw := 1, td := 1, did := 0) -> bool:
	for dx in tw:
		for dy in td:
			var c := Vector2i(k.x + dx, k.y + dy)
			if not land.has(c) or roads.has(c) or occ.has(c) or lots.has(c) or deco.has(c):
				return false
	var vari := rng.randi() % 3
	lots[k] = {"kind": kind, "vari": vari, "h": _height_for(kind, vari), "dtype": dtype,
		"area": _area_name(did, dtype, tier), "tw": tw, "td": td, "ins": ins + SPACING, "did": did}
	for dx in tw:
		for dy in td:
			occ[Vector2i(k.x + dx, k.y + dy)] = k
	return true


# The CENTRAL HUB: the city's tallest tower, a 2×2 megastructure on the tile nearest the city centre
# (falls back to 1×1 only if no 2×2 fits the core block).
func _place_hub(tiles: Array, centre: Vector2, did: int) -> void:
	if _place(hub_site, "hub", "bus", 2, 0.16, 2, 2, did): hub_key = hub_site; return
	var order := tiles.duplicate()
	order.sort_custom(func(a, b): return Vector2(a).distance_to(centre) < Vector2(b).distance_to(centre))
	for t in order:
		for off in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			if _place(t + off, "hub", "bus", 2, 0.16, 2, 2, did): hub_key = t + off; return
	for t in order:
		if _place(t, "hub", "bus", 2, 0.06, 1, 1, did): hub_key = t; return


func _fill_downtown(tiles: Array, tier: int, did: int) -> void:
	tiles.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
	var free := tiles.filter(func(t): return not occ.has(t))
	if free.size() >= 4:   # a small public square, never under the HUB
		deco[free[free.size() / 2]] = "plaza"
	var landmark := true
	for t in tiles:
		if occ.has(t) or deco.has(t): continue
		var kind: String
		if tier >= 2:
			kind = "corp" if (landmark or rng.randf() < 0.72) else ("off_m" if rng.randf() < 0.7 else "off_s")
		else:
			kind = "off_m" if (landmark or rng.randf() < 0.6) else "off_s"
		# megacorp blocks: a 2×2 corporate tower where it fits
		if kind == "corp" and rng.randf() < 0.3 and _place(t, "corp", "bus", tier, 0.07, 2, 2, did):
			lots[t].h = float(lots[t].h) * 1.25
		else:
			_place(t, kind, "bus", tier, 0.08, 1, 1, did)
		landmark = false


func _fill_shopping(tiles: Array, did: int) -> void:
	tiles.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
	# A real retail destination reads as FRONTAGE: storefronts lining the streets, with a public
	# square (and a mall anchor where it fits) set back behind them — a shopping street/square, not a
	# blob. Small sites become a pure high street; big ones a frontage + mall + square.
	var frontage := []; var interior := []
	for t in tiles:
		var on_street := false
		for d in DIRS:
			if roads.has(t + d): on_street = true; break
		if on_street: frontage.append(t)
		else: interior.append(t)
	var shops := 0
	for t in frontage:                       # continuous shop frontage along the streets
		if occ.has(t) or deco.has(t): continue
		_place(t, "shop_s" if rng.randf() < 0.55 else "shop_b", "com", 0, 0.12, 1, 1, did); shops += 1
	var placed_mall := false
	var malls := 0; var max_malls := maxi(1, interior.size() / 10)
	for t in interior:                       # mall anchors behind the frontage — big sites get several
		if malls >= max_malls: break
		if _place(t, "mall", "com", 1, 0.06, 2, 2, did):
			placed_mall = true; malls += 1
			var fore := Vector2i(t.x, t.y + 2)
			if not occ.has(fore) and interior.has(fore): deco[fore] = "plaza"
	for t in interior:                       # the rest: dense stores, with a square + parking between
		if occ.has(t) or deco.has(t): continue
		var r := rng.randf()
		if r < 0.5: _place(t, "shop_b", "com", 0, 0.12, 1, 1, did)
		else: deco[t] = "plaza" if r < 0.8 else "parking"
	if shops == 0 and not placed_mall:       # guarantee a retail destination on an awkward site
		for t in tiles:
			if _place(t, "shop_b", "com", 0, 0.14, 1, 1, did): break


func _fill_park(tiles: Array) -> void:
	tiles.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
	# only carve a path row when the park has ≥2 rows, so a thin park never becomes ALL path (and
	# thus has no actual green ground) — the measured one-row-park failure.
	var rows := {}
	for t in tiles: rows[int(t.y)] = true
	var path_row := int(tiles[tiles.size() / 2].y) if rows.size() >= 2 else -99999
	for t in tiles:
		if t.y == path_row:
			deco[t] = "path"
		else:
			deco[t] = "park"
			if rng.randf() < 0.75:
				trees.append({"tile": Vector2(t) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)), "sz": rng.randf_range(8.0, 13.0), "wild": false})


func _fill_residential(tiles: Array, tier: int, did: int, terraced := false) -> void:
	var centre := Vector2.ZERO
	for t in tiles: centre += Vector2(t)
	centre /= float(max(1, tiles.size()))
	var court: Vector2i = tiles[0]; var bestd := INF
	for t in tiles:
		var dd: float = Vector2(t).distance_to(centre)
		if dd < bestd: bestd = dd; court = t
	# terraced blocks: BFS road-distance so houses form rows of a per-block DEPTH (1–2) back from the
	# street with rear gardens beyond — the terrace depth then varies from block to block.
	var rdist := {}
	var depth := 1
	if terraced and tier == 0:
		var tset := {}
		for t in tiles: tset[t] = true
		var q := []
		for t in tiles:   # edge-facing: a street OR the border with a neighbouring territory
			for d in DIRS:
				if not tset.has(t + d): rdist[t] = 0; q.append(t); break
		var head := 0
		while head < q.size():
			var cur: Vector2i = q[head]; head += 1
			for d in DIRS:
				var nb: Vector2i = cur + d
				if tset.has(nb) and not rdist.has(nb):
					rdist[nb] = int(rdist[cur]) + 1; q.append(nb)
		depth = 2 if _noise(int(centre.x) * 3 + 5, int(centre.y) * 3 + 2) > -0.1 else 1
	var shop_tile := Vector2i(-999, -999)
	if rng.randf() < 0.3: shop_tile = tiles[rng.randi() % tiles.size()]
	for t in tiles:
		if occ.has(t): continue
		if t == shop_tile:
			_place(t, "shop_s", "com", 0, 0.2, 1, 1, did); continue
		match tier:
			0:
				if terraced:
					# tight street-facing rows `depth` deep, rear gardens behind — denser than suburb
					if int(rdist.get(t, 99)) < depth:
						_place(t, "fh", "res", 0, 0.1, 1, 1, did); deco[t] = "garden"
					else:
						deco[t] = "garden"
						if rng.randf() < 0.35:
							trees.append({"tile": Vector2(t) + Vector2(0.5, 0.5), "sz": rng.randf_range(6.0, 9.0), "wild": false})
				elif rng.randf() < 0.74:
					_place(t, "fh", "res", 0, 0.36, 1, 1, did); deco[t] = "garden"
					if rng.randf() < 0.45:
						trees.append({"tile": Vector2(t) + Vector2(rng.randf_range(0.66, 0.84), rng.randf_range(0.18, 0.4)), "sz": rng.randf_range(6.0, 9.0), "wild": false})
				else:
					deco[t] = "garden"
					if rng.randf() < 0.6:
						trees.append({"tile": Vector2(t) + Vector2(0.5, 0.5), "sz": rng.randf_range(7.0, 10.0), "wild": false})
			1:
				if t == court:
					deco[t] = "court"; trees.append({"tile": Vector2(t) + Vector2(0.5, 0.5), "sz": 9.0, "wild": false})
				elif _place(t, "ap", "res", 1, 0.1, 1, 1, did):
					# street-facing apartments get ground-floor shops (mixed use)
					var on_street := false
					for d in DIRS:
						if roads.has(t + d): on_street = true; break
					if on_street and rng.randf() < 0.5:
						lots[t]["mixed"] = true
			_:
				if t == court and rng.randf() < 0.5: deco[t] = "plaza"
				else: _place(t, "sc", "res", 2, 0.14, 1, 1, did)


# The unmapped VOID around the city (no forests/fields — this is cyberspace): each off-grid tile stores
# its BFS distance to the city so the grid can fade out into darkness.
func _dress_countryside(g: Vector2i) -> void:
	var q := []
	for t in land:
		country[t] = 0; q.append(t)
	for t in roads:
		if not country.has(t): country[t] = 0; q.append(t)
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]; head += 1
		for d in DIRS:
			var nb: Vector2i = cur + d
			if _in_grid(nb) and not country.has(nb):
				country[nb] = int(country[cur]) + 1; q.append(nb)
	for t in land: country.erase(t)
	for t in roads: country.erase(t)


func _height_for(kind: String, vari: float) -> float:
	var v := float(vari)
	match kind:
		"fh":     return 11.0 + v * 3.0
		"ap":     return 24.0 + v * 7.0
		"sc":     return 58.0 + v * 11.0
		"shop_s": return 13.0 + v * 3.0
		"shop_b": return 22.0 + v * 5.0
		"mall":   return 26.0 + v * 5.0
		"off_s":  return 27.0 + v * 7.0
		"off_m":  return 48.0 + v * 11.0
		"corp":   return 86.0 + v * 16.0
		"hub":    return 380.0   # always the tallest structure in the city, by a wide margin
	return 24.0


func _noise(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 2654435761) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 32768.0 - 1.0


# ============================================================ FRAMING / INPUT
func _frame() -> void:
	var vp := Vector2(get_viewport().get_visible_rect().size)
	var fit: float = minf(vp.x / maxf(_world.size.x + 160.0, 1.0), vp.y / maxf(_world.size.y + 180.0, 1.0))
	camera.zoom = Vector2.ONE * clampf(fit, 0.2, 1.4)
	camera.position = _world.get_center()


func _process(dt: float) -> void:
	_time += dt
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.y += 1
	if pan != Vector2.ZERO:
		camera.position += pan.normalized() * 520.0 * dt / camera.zoom.x
	# default = the flat, small-building view; hold F: the city eases up to full height, release to settle back
	var ft := 1.0 if Input.is_key_pressed(KEY_F) else FLAT_DEFAULT
	if not is_equal_approx(_flat, ft):
		_flat = move_toward(_flat, ft, dt * 4.5)
		_dirty = true
	_update_hover()
	# Repaint gating. Canvas items are RETAINED: the Camera2D transform pans/zooms already-drawn
	# commands on the GPU for free, so _draw only needs to re-run when the drawn CONTENT changes.
	# At overview the whole map is baked into the canvas (see _draw), so panning, hover and the neon
	# animation never force a (costly, ~everything-visible) repaint — only selection or a zoom change
	# does. When zoomed in, culling makes repaints cheap, so pan/hover/anim repaint normally there.
	_anim_acc += dt
	# Repaint gating. Canvas items are RETAINED: the Camera2D pans/zooms already-drawn commands on the GPU
	# for free, so the static scene repaints only on a zoom or content change. The overlay repaints on
	# hover, and animates (20 Hz) ONLY while a building/district is selected — the default and N views
	# show no moving data at all, so an idle city costs nothing.
	var zoomed: bool = camera.zoom != _last_zoomv
	var hov: bool = _hover_tile != _last_hover or _hover_b != _last_hover_b
	var animating: bool = (lots.has(selected) or sel_did >= 0) and not Settings.reduced_motion
	var tick: bool = animating and _anim_acc >= 0.05
	if _dirty or zoomed:
		_dirty = false
		_last_zoomv = camera.zoom; _last_hover = _hover_tile; _last_hover_b = _hover_b
		queue_redraw()
		if _fx != null: _fx.queue_redraw()   # keep the overlay in step with content changes
	elif hov or tick:
		_last_hover = _hover_tile; _last_hover_b = _hover_b
		if tick: _anim_acc = 0.0
		if _fx != null: _fx.queue_redraw()   # hover highlight + selection animation, never the scene


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.15, 0.15), Vector2(3.5, 3.5))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.15, 0.15), Vector2(3.5, 3.5))
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click:   # double-click a building → dive into its local map
					if lots.has(_building_at(get_global_mouse_position())):
						_select_at(get_global_mouse_position()); _enter_building(); return
				_lmb_down = true; _lmb_moved = false
			else:
				if _lmb_down and not _lmb_moved: _select_at(get_global_mouse_position())
				_lmb_down = false
	elif event is InputEventMouseMotion:
		if _panning or (_lmb_down and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
			if event.relative.length() > 3.0: _lmb_moved = true
			if _panning or _lmb_moved: camera.position -= event.relative / camera.zoom.x


func _screen_to_tile(wpos: Vector2) -> Vector2i:
	var fx := wpos.x / (2.0 * HW) + wpos.y / (2.0 * HH)
	var fy := wpos.y / (2.0 * HH) - wpos.x / (2.0 * HW)
	return Vector2i(int(floor(fx)), int(floor(fy)))


# Building HEIGHT factor: constant across zoom; FLAT_DEFAULT normally, full height while F is held.
func _hmul() -> float:
	return _hmul_at(camera.zoom.x)
func _hmul_at(_z: float) -> float:   # heights are CONSTANT across zoom (the user didn't want them growing);
	return HEIGHT_K * _flat               # only holding F (raise) changes them
# 0..1 fade for detail that appears with zoom (windows, outlines) — never a hard pop
func _fade(z0: float, z1: float) -> float:
	return smoothstep(z0, z1, camera.zoom.x)


func _box_hull(k: Vector2i) -> PackedVector2Array:
	return _hull_at(k, _hmul())


func _hull_at(k: Vector2i, hm: float) -> PackedVector2Array:
	var b = lots[k]
	var tw: float = float(b.tw); var td: float = float(b.td); var ins: float = float(b.ins); var h: float = float(b.h) * hm
	var up := Vector2(0, -h)
	var A := _iso(k.x + ins, k.y + ins); var B := _iso(k.x + tw - ins, k.y + ins)
	var C := _iso(k.x + tw - ins, k.y + td - ins); var D := _iso(k.x + ins, k.y + td - ins)
	return PackedVector2Array([A + up, B + up, B, C, D, D + up])


# The front-most building whose drawn SHAPE (walls + roof) contains wpos. A building can only contain a
# point if its base stands at or below it on screen, so only cells from the cursor's ground tile toward
# the viewer (within the tallest building's reach) are tested — cheap enough to run on every mouse move.
func _building_at(wpos: Vector2) -> Vector2i:
	var t0 := _screen_to_tile(wpos)
	var best := Vector2i(-999, -999); var best_d := -100000
	var tested := {}
	for st in range(-2, 18):
		for dd in range(-4, 5):
			if posmod(st + dd, 2) != 0: continue
			var t := t0 + Vector2i((st + dd) / 2, (st - dd) / 2)
			if not occ.has(t): continue
			var k: Vector2i = occ[t]
			if tested.has(k): continue
			tested[k] = true
			if Geometry2D.is_point_in_polygon(wpos, _box_hull(k)):
				var d := _depth(k)
				if d > best_d: best_d = d; best = k
	return best


# shortest chain of buildings from a to b through the network (BFS over links) — [a, …, b]
func _route_to(a: Vector2i, b: Vector2i) -> Array:
	if not lots.has(a) or not lots.has(b): return []
	var prev := {a: a}; var q := [a]; var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]; head += 1
		if cur == b: break
		for o in net_links.get(cur, []):
			if not prev.has(o): prev[o] = cur; q.append(o)
	if not prev.has(b): return []
	var path := [b]
	while path[path.size() - 1] != a: path.append(prev[path[path.size() - 1]])
	path.reverse()
	return path


func _select_at(wpos: Vector2) -> void:
	var hit := _building_at(wpos)
	if lots.has(hit):
		_select_building(hit)
	else:
		selected = Vector2i(-999, -999); _focus = []; _route = []
		var t := _screen_to_tile(wpos)   # open district ground (plaza, garden, pad…) selects the district too
		_select_district(int(dist_of[t]) if dist_of.has(t) and not roads.has(t) else -1)
		_dirty = true; _update_sel_panel()


# select a BUILDING: focus it + its links + its route to the HUB (shared by click and return-from-interior)
func _select_building(k: Vector2i) -> void:
	selected = k
	_select_district(int(lots[k].did))
	_focus = [k] + (net_links.get(k, []) as Array)
	_route = _route_to(k, hub_key)
	for r in _route:
		if not _focus.has(r): _focus.append(r)
	_focus.sort_custom(func(a, c): return a.x + a.y + int(lots[a].tw) + int(lots[a].td) < c.x + c.y + int(lots[c].tw) + int(lots[c].td))
	_dirty = true; _update_sel_panel()


# dive into the selected building's local network map (building.gd); stash the city view for the return
func _enter_building() -> void:
	if not lots.has(selected): return
	var b = lots[selected]
	var names := []
	for pp in b.get("people", []): names.append(str(pp.name))
	var col: Color = _dcol(int(b.did))
	var r = districts[int(b.did)]
	Session.enter = {"key": [selected.x, selected.y], "name": str(b.get("bname", "Building")), "kind": str(b.kind),
		"sec": str(b.get("sec", "Unknown")), "did": int(b.did), "col": [col.r, col.g, col.b],
		"owner": str(b.get("occupant", "")), "industry": str(corp_info.get(str(b.get("occupant", "")), {}).get("industry", "")),
		"district": str(r.name), "people": names}
	Session.city_return = {"cam": [camera.position.x, camera.position.y], "zoom": camera.zoom.x, "sel": [selected.x, selected.y]}
	get_tree().change_scene_to_file("res://scenes/building.tscn")


# select a whole district: cache its territory perimeter (edges to any other district/road/void)
func _select_district(did: int) -> void:
	sel_did = did
	_sel_edges = PackedVector2Array(); _sel_tiles = []; _sel_lots = []
	if did < 0: return
	_sel_lots = (_district_lots.get(did, []) as Array).duplicate()
	_sel_lots.sort_custom(func(a, c): return a.x + a.y + int(lots[a].tw) + int(lots[a].td) < c.x + c.y + int(lots[c].tw) + int(lots[c].td))
	for t in dist_of:
		if int(dist_of[t]) != did: continue
		_sel_tiles.append(t)
		var P00 := _iso(t.x, t.y); var P10 := _iso(t.x + 1, t.y); var P11 := _iso(t.x + 1, t.y + 1); var P01 := _iso(t.x, t.y + 1)
		for e in [[Vector2i(0, -1), P00, P10], [Vector2i(1, 0), P10, P11], [Vector2i(0, 1), P01, P11], [Vector2i(-1, 0), P00, P01]]:
			var nb: Vector2i = t + e[0]
			if int(dist_of.get(nb, -1)) != did:
				_sel_edges.append(e[1]); _sel_edges.append(e[2])


func _clear_selection() -> void:
	selected = Vector2i(-999, -999); sel_did = -1; _focus = []; _route = []
	_sel_edges = PackedVector2Array(); _sel_tiles = []; _sel_lots = []
	_dirty = true; _update_sel_panel()


func _update_hover() -> void:
	var m := get_global_mouse_position()
	var t := _screen_to_tile(m)
	if t != _hover_tile: _hover_tile = t
	if m != _hover_m or _dirty:   # resolve the building by its drawn shape — roof and walls count, not just the base
		_hover_m = m; _hover_b = _building_at(m)
	if hover_lbl == null: return
	var k := _hover_tile
	var bk: Vector2i = _hover_b
	var txt := ""
	if lots.has(bk):
		txt = "%s  ·  %s  ·  %s" % [str(lots[bk].get("bname", KIND_NAME[str(lots[bk].kind)])), KIND_NAME[str(lots[bk].kind)], str(lots[bk].area)]
	elif roads.has(k):
		txt = ("Avenue" if str(road_class.get(k, "loc")) == "art" else "Street")
	elif deco.has(k) and dist_of.has(k):
		txt = {"park": "Park", "garden": "Garden", "court": "Courtyard", "plaza": "Public square", "parking": "Parking", "path": "Park path", "verge": "Green verge"}.get(str(deco[k]), "Open space") + "  ·  " + str(districts[int(dist_of[k])].name)
	elif deco.has(k):
		txt = {"park": "Park", "garden": "Garden", "court": "Courtyard", "plaza": "Public square", "parking": "Parking", "path": "Park path", "verge": "Green verge"}.get(str(deco[k]), "Open space")
	elif land.has(k):
		txt = "Open parcel" + ("  ·  " + str(districts[int(dist_of[k])].name) if dist_of.has(k) else "")
	else:
		txt = "Unmapped void"
	if txt != _hover_txt:   # a Label relayout every frame was a measurable cost while moving the mouse
		_hover_txt = txt; hover_lbl.text = txt

# ============================================================ RENDERING
func _draw() -> void:
	var font := Settings.font
	var vp: Vector2 = get_viewport_rect().size / camera.zoom.x
	# The WHOLE static scene (ground, roads, buildings, roof detail, rooftop features, trees) is drawn as a
	# couple of pre-built triangle arrays on EVERY map size and at EVERY zoom — GL-compat doesn't batch
	# thousands of separate draw calls, and that per-call cost was the wall. It is rebuilt only when the
	# LOD tier, the building height (hold F) or a zoom fade step changes; panning/zooming moves it for free.
	var tier := 0 if camera.zoom.x < LOD_ZOOM else 1
	var hm := _hmul(); var da := _detail_a(); var fa := _feature_a()
	if _bake_tier != tier or absf(hm - _bake_h) > 0.02 or not is_equal_approx(da, _bake_da) or not is_equal_approx(fa, _bake_fa):
		_bake_da = da; _bake_fa = fa; _build_bake(tier); _bake_tier = tier; _bake_h = hm
	var ci := get_canvas_item()
	if not _ground_idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci, _ground_idx, _ground_pts, _ground_cols)
	if not _bake_idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci, _bake_idx, _bake_pts, _bake_cols)
	# N: the whole network — every link as an arc, gateways beaming — over a dimmed city, as ONE cached
	# batch (static: no per-frame cost; data FLOW only animates for what you click)
	if net_view and sel_did < 0 and not lots.has(selected):
		draw_rect(_world.grow(4000.0), Color(0.0, 0.0, 0.02, 0.55))
		if absf(_net_h - hm) > 0.001: _build_net_bake(); _net_h = hm
		if not _net_idx.is_empty():
			RenderingServer.canvas_item_add_triangle_array(ci, _net_idx, _net_pts, _net_cols)
	if camera.zoom.x < 1.9:
		for r in districts:
			if int(r.count) < 1: continue
			if int(r.get("size", 99)) < 8: continue   # tiny territories stay unlabelled (less clutter)
			var dc: Color = r.col
			var pcen := _iso(float(r.centroid_tile.x) + 0.5, float(r.centroid_tile.y) + 0.5)
			draw_string(font, pcen - Vector2(34, 2), str(r.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(dc.r, dc.g, dc.b, 0.6))
	if lots.has(hub_key):   # the HUB is always named, at every zoom
		var hb = lots[hub_key]
		var hp := _iso(hub_key.x + float(hb.tw) * 0.5, hub_key.y + float(hb.td) * 0.5) + Vector2(0, -float(hb.h) * _hmul() * 1.3 - 14.0)
		hp.y = maxf(hp.y, camera.position.y - vp.y * 0.5 + 90.0 / camera.zoom.x)   # stay below the title bar
		draw_string(font, hp - Vector2(48, 0), "CENTRAL HUB", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1.0, 1.0, 0.95))


func _tile_quad(lx: float, ly: float, w := 1.0, d := 1.0) -> PackedVector2Array:
	return PackedVector2Array([_iso(lx, ly), _iso(lx + w, ly), _iso(lx + w, ly + d), _iso(lx, ly + d)])
func _closed(q: PackedVector2Array) -> PackedVector2Array:
	var r := PackedVector2Array(q); r.append(q[0]); return r


# ---- batched static bake: accumulate the whole scene into one triangle array (see _draw) ----
func _bq(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var i := _bake_pts.size()
	_bake_pts.push_back(a); _bake_pts.push_back(b); _bake_pts.push_back(c); _bake_pts.push_back(d)
	_bake_cols.push_back(col); _bake_cols.push_back(col); _bake_cols.push_back(col); _bake_cols.push_back(col)
	_bake_idx.push_back(i); _bake_idx.push_back(i + 1); _bake_idx.push_back(i + 2)
	_bake_idx.push_back(i); _bake_idx.push_back(i + 2); _bake_idx.push_back(i + 3)
func _bqp(q: PackedVector2Array, col: Color) -> void:
	_bq(q[0], q[1], q[2], q[3], col)
func _btri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var i := _bake_pts.size()
	_bake_pts.push_back(a); _bake_pts.push_back(b); _bake_pts.push_back(c)
	_bake_cols.push_back(col); _bake_cols.push_back(col); _bake_cols.push_back(col)
	_bake_idx.push_back(i); _bake_idx.push_back(i + 1); _bake_idx.push_back(i + 2)
const FEATHER := 1.2   # world units of soft edge on every baked line (2D MSAA is unavailable on GL)
func _bq4(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	var i := _bake_pts.size()
	_bake_pts.push_back(a); _bake_pts.push_back(b); _bake_pts.push_back(c); _bake_pts.push_back(d)
	_bake_cols.push_back(ca); _bake_cols.push_back(cb); _bake_cols.push_back(cc); _bake_cols.push_back(cd)
	_bake_idx.push_back(i); _bake_idx.push_back(i + 1); _bake_idx.push_back(i + 2)
	_bake_idx.push_back(i); _bake_idx.push_back(i + 2); _bake_idx.push_back(i + 3)
func _bline(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var nrm := (b - a).orthogonal().normalized()
	if nrm == Vector2.ZERO: return
	var o := nrm * (w * 0.5)
	_bq(a + o, b + o, b - o, a - o, col)
	var f := nrm * FEATHER
	var t := Color(col.r, col.g, col.b, 0.0)
	_bq4(a + o, b + o, b + o + f, a + o + f, col, col, t, t)
	_bq4(a - o - f, b - o - f, b - o, a - o, t, t, col, col)
func _bdot(c: Vector2, r: float, col: Color) -> void:
	_bq(c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r), col)
func _bgrid(lx: int, ly: int) -> void:   # faint neon tile outline (cyberspace grid) into the bake
	var a := _iso(lx, ly); var b := _iso(lx + 1, ly); var c := _iso(lx + 1, ly + 1); var d := _iso(lx, ly + 1)
	_bline(a, b, 1.0, GRID_COL); _bline(b, c, 1.0, GRID_COL); _bline(c, d, 1.0, GRID_COL); _bline(d, a, 1.0, GRID_COL)
# The ground never changes with zoom, so it is baked ONCE into its own arrays; only the buildings +
# trees (whose height eases with zoom) are rebaked — keeps a zoom-step rebake cheap.
func _build_bake(tier: int) -> void:
	if _ground_idx.is_empty():
		_bake_pts = PackedVector2Array(); _bake_cols = PackedColorArray(); _bake_idx = PackedInt32Array()
		for ly in _grid.y:
			for lx in _grid.x:
				_bake_ground(lx, ly)
		_ground_pts = _bake_pts; _ground_cols = _bake_cols; _ground_idx = _bake_idx
	_bake_pts = PackedVector2Array(); _bake_cols = PackedColorArray(); _bake_idx = PackedInt32Array()
	for it in _draw_items:   # already depth-sorted → painter order preserved within the array
		if it.b: _bake_building(it.k, tier)
		else: _bake_tree_blob(trees[it.i])


const VOID_COL := Color(0.022, 0.026, 0.04)   # the unmapped void around the city
const PAD_BASE := Color(0.045, 0.055, 0.085)  # dark territory floor, tinted by the district's hue

func _dcol(did: int) -> Color:
	if did >= 0 and did < districts.size(): return districts[did].col
	return Color(0.3, 0.9, 1.0)


# Hologram palette for a building: dark faces tinted by its district's neon hue, a brighter top and a
# glowing edge. Returns [left face, right face, top, edge]. The HUB is ice-white.
func _holo(b, k := Vector2i(-999, -999)) -> Array:
	var dark := Color(0.025, 0.035, 0.06)
	var hk := "%d,%d" % [k.x, k.y]
	if Session.hacked.has(hk):   # a building you've started to compromise: RED, hotter once fully owned
		var st: Dictionary = Session.hacked[hk]
		var full: bool = int(st.ctl) >= int(st.n)
		var red := Color(1.0, 0.2, 0.26)
		return [dark.lerp(red, 0.42 if full else 0.3), dark.lerp(red, 0.58 if full else 0.42), dark.lerp(red, 0.85 if full else 0.62), (Color(1.0, 0.8, 0.8) if full else Color(1.0, 0.45, 0.5))]
	if str(b.kind) == "hub":   # the landmark glows: lit cyan-white faces, white-hot edges
		var hb := Color(0.55, 1.0, 1.0)
		return [dark.lerp(hb, 0.32), dark.lerp(hb, 0.48), dark.lerp(hb, 0.72), Color(0.9, 1.0, 1.0)]
	var base: Color = _dcol(int(b.did))
	var v := 0.03 * float(b.vari)
	return [dark.lerp(base, 0.12 + v), dark.lerp(base, 0.2 + v), dark.lerp(base, 0.36 + v), base.lerp(Color.WHITE, 0.35)]


# Ground look of one non-road tile, SHARED by the live and baked paths so they always match:
# [fill, [[a, b, width, colour], ...]] — district-tinted floor + district-coloured grid, a bright
# double seam where two territories meet, and the void's grid fading out with distance from the city.
func _ground_look(lx: int, ly: int) -> Array:
	var k := Vector2i(lx, ly)
	var P00 := _iso(lx, ly); var P10 := _iso(lx + 1, ly); var P11 := _iso(lx + 1, ly + 1); var P01 := _iso(lx, ly + 1)
	var lines := []
	if not land.has(k):
		var fade := clampf(1.0 - float(country.get(k, 9)) / 6.0, 0.0, 1.0)
		if fade > 0.0:
			var vc := Color(0.2, 0.85, 1.0, 0.12 * fade)
			lines.append([P00, P10, 1.0, vc]); lines.append([P00, P01, 1.0, vc])
		return [VOID_COL, lines]
	var did: int = int(dist_of.get(k, -1))
	var dc: Color = _dcol(did)
	var fill: Color
	match str(deco.get(k, "")):
		"park": fill = Color(0.05, 0.17, 0.09)
		"garden", "court": fill = Color(0.05, 0.13, 0.08)
		"verge": fill = Color(0.04, 0.11, 0.07)
		"path": fill = Color(0.1, 0.12, 0.11)
		"plaza": fill = PAD_BASE.lerp(dc, 0.17)
		"parking": fill = PAD_BASE.lerp(dc, 0.06)
		_: fill = PAD_BASE.lerp(dc, 0.1)
	var gc := Color(dc.r, dc.g, dc.b, 0.17)
	lines.append([P00, P10, 1.0, gc]); lines.append([P00, P01, 1.0, gc])   # N + W edges: each grid line once
	var cen := _iso(lx + 0.5, ly + 0.5)
	var bc := Color(dc.r, dc.g, dc.b, 0.8)
	for e in [[Vector2i(0, -1), P00, P10], [Vector2i(1, 0), P10, P11], [Vector2i(0, 1), P01, P11], [Vector2i(-1, 0), P00, P01]]:
		var nb: Vector2i = k + e[0]
		if dist_of.has(nb) and int(dist_of[nb]) != did:
			var a: Vector2 = e[1]; var b2: Vector2 = e[2]
			var sh := (cen - (a + b2) * 0.5) * 0.1   # inset toward this tile -> two-colour seam
			lines.append([a + sh, b2 + sh, 2.0, bc])
	return [fill, lines]


func _bake_ground(lx: int, ly: int) -> void:
	if roads.has(Vector2i(lx, ly)):
		_bake_road(lx, ly); return
	var look := _ground_look(lx, ly)
	_bqp(_tile_quad(lx, ly), look[0])
	for ln in look[1]: _bline(ln[0], ln[1], ln[2], ln[3])


func _bake_road(lx: int, ly: int) -> void:
	var k := Vector2i(lx, ly)
	var art: bool = str(road_class.get(k, "loc")) == "art"
	_bqp(_tile_quad(lx, ly), Color(0.12, 0.13, 0.17) if art else Color(0.09, 0.1, 0.13))
	_bgrid(lx, ly)   # neon grid floor
	var rN := roads.has(Vector2i(lx, ly - 1)); var rE := roads.has(Vector2i(lx + 1, ly))
	var rS := roads.has(Vector2i(lx, ly + 1)); var rW := roads.has(Vector2i(lx - 1, ly))
	var P00 := _iso(lx, ly); var P10 := _iso(lx + 1, ly); var P11 := _iso(lx + 1, ly + 1); var P01 := _iso(lx, ly + 1)
	var cen := _iso(lx + 0.5, ly + 0.5)
	var mc := Color(0.3, 0.95, 1.0, 0.65) if art else Color(0.72, 0.74, 0.55, 0.5)
	var mw := 2.0 if art else 1.0
	var cnt := (1 if rN else 0) + (1 if rE else 0) + (1 if rS else 0) + (1 if rW else 0)
	if cnt == 0:
		_bdot(cen, 3.0, mc)
	else:
		if rN: _bline(cen, (P00 + P10) * 0.5, mw, mc)
		if rE: _bline(cen, (P10 + P11) * 0.5, mw, mc)
		if rS: _bline(cen, (P01 + P11) * 0.5, mw, mc)
		if rW: _bline(cen, (P00 + P01) * 0.5, mw, mc)
		if cnt == 1: _bdot(cen, 2.5, mc)


func _bake_building(k: Vector2i, tier: int) -> void:
	var b = lots[k]
	var tw: float = float(b.tw); var td: float = float(b.td); var ins: float = float(b.ins)
	var h: float = float(b.h) * _hmul()   # same continuous zoom height as the live path
	var up := Vector2(0, -h)
	var A := _iso(k.x + ins, k.y + ins); var B := _iso(k.x + tw - ins, k.y + ins)
	var C := _iso(k.x + tw - ins, k.y + td - ins); var D := _iso(k.x + ins, k.y + td - ins)
	var At := A + up; var Bt := B + up; var Ct := C + up; var Dt := D + up
	var kind := str(b.kind)
	var pal := _holo(b, k)
	var top: Color = pal[2]
	_bq(D, C, Ct, Dt, pal[0])
	_bq(B, C, Ct, Bt, pal[1])
	var edge: Color = pal[3]
	if tier == 0:   # overview: flat top + a faint glowing rim (the hologram still reads from afar)
		_bq(At, Bt, Ct, Dt, top)
		edge.a = 0.45
		_bline(At, Bt, 1.0, edge); _bline(Bt, Ct, 1.0, edge); _bline(Ct, Dt, 1.0, edge); _bline(Dt, At, 1.0, edge)
		return
	edge.a = 0.45 + 0.5 * _fade(LOD_ZOOM, LOD_ZOOM + 0.25)   # neon outline strengthens as you zoom in
	if kind == "fh":
		var rh := minf(h * 0.9, 10.0)
		var r1 := (At + Bt) * 0.5 + Vector2(0, -rh)
		var r2 := (Dt + Ct) * 0.5 + Vector2(0, -rh)
		_bq(At, Dt, r2, r1, pal[1])
		_bq(Bt, Ct, r2, r1, top)
		_btri(Dt, Ct, r2, pal[1])
		_bline(At, r1, 1.0, edge); _bline(r1, Bt, 1.0, edge); _bline(Dt, r2, 1.0, edge); _bline(r2, Ct, 1.0, edge)
	else:
		_bq(At, Bt, Ct, Dt, top)
		_bline(Dt, At, 1.0, edge); _bline(At, Bt, 1.0, edge); _bline(Bt, Ct, 1.0, edge)
		if kind == "hub":   # glowing crown + spire (the static part of the HUB marker)
			_bq(At, Bt, Ct, Dt, Color(0.4, 1.0, 0.95, 0.35))
			var tc := (At + Ct) * 0.5
			_bline(tc, tc + up * 0.3, 3.0, Color(0.6, 1.0, 1.0, 0.95))
	_bline(D, C, 1.0, edge); _bline(C, B, 1.0, edge)
	_bline(Dt, D, 1.0, edge); _bline(Ct, C, 1.0, edge); _bline(Bt, B, 1.0, edge)
	if _bake_da > 0.01:
		for ln in _detail_lines(b, D, C, B, At, Bt, Ct, Dt, pal[3], _bake_da): _bline(ln[0], ln[1], ln[2], ln[3])
	if _bake_fa > 0.01: _bake_features(b, At, Bt, Ct, Dt, D, C, B, _bake_fa)


# 0..1 strength of the rooftop features (antennas, awnings, roof glow) — fades in just past overview zoom
func _feature_a() -> float:
	return snappedf(_fade(LOD_ZOOM, LOD_ZOOM + 0.3), 0.1)


func _bpoly(pts: PackedVector2Array, w: float, col: Color) -> void:   # a polyline into the batch
	for i in range(1, pts.size()): _bline(pts[i - 1], pts[i], w, col)


func _brect(pos: Vector2, size: Vector2, col: Color) -> void:   # an axis-aligned rect into the batch
	_bq(pos, pos + Vector2(size.x, 0), pos + size, pos + Vector2(0, size.y), col)


# The N-view network as one batch: local links as low arcs in their district's hue, district-to-district
# links as glowing arcs, a light beam on every gateway. Built once per building height, then re-used.
func _build_net_bake() -> void:
	var sp := _bake_pts; var sc := _bake_cols; var si := _bake_idx   # borrow the batch helpers
	_bake_pts = PackedVector2Array(); _bake_cols = PackedColorArray(); _bake_idx = PackedInt32Array()
	for e in net_local:
		var dc := _dcol(int(lots[e[0]].did))
		var pa := _building_top_center(e[0]); var pb := _building_top_center(e[1])
		var pts := _arc_pts(pa, pb, _arc_lift(pa, pb, false), 6)
		_bpoly(pts, 3.5, Color(dc.r, dc.g, dc.b, 0.14)); _bpoly(pts, 1.2, Color(dc.r, dc.g, dc.b, 0.7))
	for e in net_backbone:
		var pts: PackedVector2Array = _link_arc(e[0], e[1])[0]
		_bpoly(pts, 8.0, Color(0.45, 0.92, 1.0, 0.1)); _bpoly(pts, 3.5, Color(0.45, 0.92, 1.0, 0.3))
		_bpoly(pts, 1.4, Color(0.8, 1.0, 1.0, 0.95))
	for g in gateways:
		var top := _building_top_center(g)
		_bline(top, top + Vector2(0, -30), 1.6, Color(0.8, 1.0, 1.0, 0.9)); _bdot(top + Vector2(0, -30), 2.5, Color(0.9, 1.0, 1.0, 0.95))
	_net_pts = _bake_pts; _net_cols = _bake_cols; _net_idx = _bake_idx
	_bake_pts = sp; _bake_cols = sc; _bake_idx = si


# rooftop features baked with the building (they used to exist only on the slow live path)
func _bake_features(b: Dictionary, At: Vector2, Bt: Vector2, Ct: Vector2, Dt: Vector2, D: Vector2, C: Vector2, B: Vector2, a: float) -> void:
	var topc := (At + Ct) * 0.5
	var dc := _dcol(int(b.did))
	var wall := (Dt - D).length()   # base-level details only where the wall is tall enough to carry them
	match str(b.kind):
		"fh":
			if wall >= 8.0: _brect(B.lerp(C, 0.5) + Vector2(-2, -7), Vector2(3, 7), Color(0.35, 0.22, 0.14, a))
		"ap":
			if bool(b.get("mixed", false)) and wall >= 8.0:   # ground-floor retail below the flats
				var mid := D.lerp(C, 0.5)
				_brect(mid + Vector2(-7, -7), Vector2(14, 3), Color(1.0, 0.35, 0.8, 0.85 * a))
				_brect(mid + Vector2(-6, -4), Vector2(12, 3), Color(1.0, 0.62, 0.9, 0.55 * a))
		"sc":
			_bline(topc, topc + Vector2(0, -16), 1.5, Color(0.6, 0.7, 0.8, a)); _bdot(topc + Vector2(0, -16), 2.0, Color(1.0, 0.3, 0.3, 0.85 * a))
		"corp":
			_bq(At, Bt, Ct, Dt, Color(dc.r, dc.g, dc.b, 0.2 * a))
			_bline(topc, topc + Vector2(0, -26), 2.0, Color(dc.r, dc.g, dc.b, 0.8 * a))
			var lit := dc.lerp(Color.WHITE, 0.3)
			_bdot(topc + Vector2(0, -26), 2.5, Color(lit.r, lit.g, lit.b, 0.9 * a))
		"mall":
			_bq(At, Bt, Ct, Dt, Color(dc.r, dc.g, dc.b, 0.18 * a))
			if wall >= 8.0: _brect(C + Vector2(-9, -12), Vector2(18, 10), Color(dc.r, dc.g, dc.b, 0.5 * a))
		"shop_s", "shop_b":
			if wall >= 6.0: _brect(C + Vector2(-7, -6), Vector2(14, 3), Color(dc.r, dc.g, dc.b, 0.8 * a))


# 0..1 strength of the zoomed-in architectural detail, quantised to tenths so the baked large map
# re-bakes only a handful of times across the fade (the live path just uses it as-is)
func _detail_a() -> float:
	return snappedf(_fade(DETAIL_Z0, DETAIL_Z1), 0.1)


# PRECISE VIEW (zoomed in): crisp blueprint lines on each building — floor bands and panel mullions on
# both visible walls, a bright lobby line at street level, a parapet outline on the roof, a rooftop
# plant box on offices/towers and a helipad ring on tall corporate towers. Returned as segments
# [a, b, width, colour] so the live and the baked path draw exactly the same thing, in depth order.
func _detail_lines(b: Dictionary, D: Vector2, C: Vector2, B: Vector2, At: Vector2, Bt: Vector2, Ct: Vector2, Dt: Vector2, edge: Color, a: float) -> Array:
	var out := []
	var kind := str(b.kind)
	var up := Dt - D
	var h := up.length()
	if h < 3.0: return out
	var fc := Color(edge.r, edge.g, edge.b, 0.32 * a)
	var mc := Color(edge.r, edge.g, edge.b, 0.2 * a)
	# floor bands: one line every ~2 floors on screen, never closer than 6px
	var n := clampi(int(h / 7.0), 0, 14)
	for i in range(1, n + 1):
		var f := float(i) / float(n + 1)
		out.append([D + up * f, C + up * f, 1.0, fc]); out.append([C + up * f, B + up * f, 1.0, fc])
	# panel mullions on each wall (vertical lines, base to roof)
	for wall in [[D, C], [C, B]]:
		var w: float = (wall[0] as Vector2).distance_to(wall[1])
		var m := clampi(int(round(w / 13.0)), 1, 5)
		for j in range(1, m + 1):
			var p: Vector2 = (wall[0] as Vector2).lerp(wall[1], float(j) / float(m + 1))
			out.append([p, p + up, 1.0, mc])
	# lobby: a brighter band just above street level
	var lf := minf(5.0 / h, 0.3)
	var lc := Color(edge.r, edge.g, edge.b, 0.65 * a)
	out.append([D + up * lf, C + up * lf, 1.4, lc]); out.append([C + up * lf, B + up * lf, 1.4, lc])
	if kind == "fh": return out
	# roof: parapet inset
	var rc := (At + Ct) * 0.5
	var pc := Color(edge.r, edge.g, edge.b, 0.5 * a)
	var q := [At.lerp(rc, 0.16), Bt.lerp(rc, 0.16), Ct.lerp(rc, 0.16), Dt.lerp(rc, 0.16)]
	for i in 4: out.append([q[i], q[(i + 1) % 4], 1.0, pc])
	# rooftop plant box (offices, towers, malls): a small raised box in outline
	if kind in ["corp", "off_m", "off_s", "sc", "mall", "ap"]:
		var bx := [At.lerp(rc, 0.62), Bt.lerp(rc, 0.62), Ct.lerp(rc, 0.62), Dt.lerp(rc, 0.62)]
		var ru := Vector2(0, -minf(5.0, h * 0.08))
		for i in 4:
			out.append([bx[i] + ru, bx[(i + 1) % 4] + ru, 1.0, pc])
		out.append([bx[2], bx[2] + ru, 1.0, pc]); out.append([bx[1], bx[1] + ru, 1.0, pc]); out.append([bx[3], bx[3] + ru, 1.0, pc])
	# helipad: a ring on the roof of tall corporate towers
	if kind == "corp" and (int(b.tw) == 2 or float(b.h) >= 112.0):   # only the tallest towers + megacorp blocks
		var rw := (Bt - Dt) * 0.18; var rh2 := (Ct - At) * 0.18
		var prev := rc + rw
		for i in range(1, 17):
			var t := float(i) / 16.0 * TAU
			var pt := rc + rw * cos(t) + rh2 * sin(t)
			out.append([prev, pt, 1.2, Color(edge.r, edge.g, edge.b, 0.7 * a)]); prev = pt
	return out


func _bake_tree_blob(tr: Dictionary) -> void:
	var cz: float = tr.sz
	var c := _iso(tr.tile.x, tr.tile.y) + Vector2(0, -cz * 1.3)
	var r := cz * 1.05
	var prev := c + Vector2(r, 0)
	for s in range(1, 7):   # hexagon approximation of the canopy circle
		var p := c + Vector2(cos(float(s) / 6.0 * TAU), sin(float(s) / 6.0 * TAU)) * r
		_btri(c, prev, p, Color(0.12, 0.4, 0.19))
		prev = p


func _building_top_center(k: Vector2i) -> Vector2:
	return _top_at(k, _hmul())


func _top_at(k: Vector2i, hm: float) -> Vector2:
	var b = lots[k]
	var tw: float = float(b.tw); var td: float = float(b.td); var ins: float = float(b.ins)
	var up := Vector2(0, -float(b.h) * hm)
	return (_iso(k.x + ins, k.y + ins) + _iso(k.x + tw - ins, k.y + td - ins)) * 0.5 + up


# The animated overlay. Runs on the _fx canvas item (above the static scene, same camera transform)
# and draws ONLY things that change every tick, so the expensive static scene can stay retained.
func _draw_fx(c: CanvasItem) -> void:
	# NOTE: this overlay draws ABOVE the whole static scene; network-view and focus modes dim the city
	# first, so traces drawn here read as an x-ray "network vision" over the ghosted buildings.
	if lots.has(selected):   # a building was clicked → BUILDING FOCUS (it + everything linked to it)
		_draw_focus(c)
		var pulse: float = 0.6 + 0.4 * sin(_time * 6.0)
		var mk := _building_top_center(selected) + Vector2(0, -14.0 - 4.0 * pulse)
		c.draw_colored_polygon(PackedVector2Array([mk, mk + Vector2(-5, -8), mk + Vector2(5, -8)]), Color(0.3, 1.0, 0.9, pulse))
		var fh: Vector2i = _hover_b
		if lots.has(fh) and fh != selected: c.draw_polyline(_closed(_box_hull(fh)), Color(1, 1, 1, 0.6), 1.2, true)
		return
	var dc := _dcol(sel_did)
	var pz: float = 0.65 + 0.35 * sin(_time * 4.0)
	if sel_did >= 0:   # selected DISTRICT in FOCUS: dim the city, light its ground, pulse its border
		c.draw_rect(_world.grow(4000.0), Color(0.0, 0.0, 0.02, 0.55))
		var gc := Color(dc.r, dc.g, dc.b, 0.22)
		for t in _sel_tiles: c.draw_colored_polygon(_tile_quad(t.x, t.y), gc)
		if not _sel_edges.is_empty():
			c.draw_multiline(_sel_edges, Color(dc.r, dc.g, dc.b, pz), 3.5, true)
			c.draw_multiline(_sel_edges, Color(1, 1, 1, 0.55 * pz), 1.2, true)
	_draw_net(c)   # ground traces + packets — under the focused district's buildings
	if sel_did >= 0:   # its buildings redrawn bright (translucent holograms: the traces show through)
		for k in _sel_lots: _fx_box(c, k)
	_draw_gateway_beams(c)
	var hk: Vector2i = _hover_b
	if lots.has(hk):   # the hovered building: outline + a faint glow of its links
		for o in net_links.get(hk, []): _glow_path(c, _link_arc(hk, o)[0], Color(0.85, 1.0, 1.0), 1.0 / camera.zoom.x, 0.5)
		c.draw_polyline(_closed(_box_hull(hk)), Color(1, 1, 1, 0.85), 1.5, true)
	elif _in_grid(_hover_tile) and (land.has(_hover_tile) or roads.has(_hover_tile)):   # the hovered ground tile
		c.draw_polyline(_closed(_tile_quad(_hover_tile.x, _hover_tile.y)), Color(1, 1, 1, 0.5), 1.2 / camera.zoom.x, true)


# one building of the focused district, drawn into the overlay: same hologram palette, a touch brighter
# level 0 = a district-focus building (translucent so its traces show through); 1 = a building linked
# to the clicked one (lit); 2 = the clicked building itself (brightest, white-hot outline + halo)
func _fx_box(c: CanvasItem, k: Vector2i, level := 0) -> void:
	var b = lots[k]
	var tw: float = float(b.tw); var td: float = float(b.td); var ins: float = float(b.ins)
	var up := Vector2(0, -float(b.h) * _hmul())
	var A := _iso(k.x + ins, k.y + ins); var B := _iso(k.x + tw - ins, k.y + ins)
	var C := _iso(k.x + tw - ins, k.y + td - ins); var D := _iso(k.x + ins, k.y + td - ins)
	var At := A + up; var Bt := B + up; var Ct := C + up; var Dt := D + up
	var pal := _holo(b, k)
	var lift: float = [0.12, 0.22, 0.34][level]
	var alpha: float = [0.82, 0.92, 0.97][level]
	for i in 3: pal[i] = Color((pal[i] as Color).r, (pal[i] as Color).g, (pal[i] as Color).b, alpha)
	var edge: Color = pal[3]
	if level == 2:
		edge = edge.lerp(Color.WHITE, 0.6)
		c.draw_polyline(_closed(PackedVector2Array([At, Bt, B, C, D, Dt])), Color(edge.r, edge.g, edge.b, 0.25), 8.0 / camera.zoom.x, true)
	var ew := (2.0 if level == 2 else 1.3)
	c.draw_colored_polygon(PackedVector2Array([D, C, Ct, Dt]), (pal[0] as Color).lerp(edge, lift))
	c.draw_colored_polygon(PackedVector2Array([B, C, Ct, Bt]), (pal[1] as Color).lerp(edge, lift))
	if str(b.kind) == "fh":
		var rh := minf(up.length() * 0.9, 10.0)
		var r1 := (At + Bt) * 0.5 + Vector2(0, -rh); var r2 := (Dt + Ct) * 0.5 + Vector2(0, -rh)
		c.draw_colored_polygon(PackedVector2Array([At, Dt, r2, r1]), (pal[1] as Color).lerp(edge, lift))
		c.draw_colored_polygon(PackedVector2Array([Bt, Ct, r2, r1]), (pal[2] as Color).lerp(edge, lift))
		c.draw_colored_polygon(PackedVector2Array([Dt, Ct, r2]), (pal[1] as Color).lerp(edge, lift))
		c.draw_polyline(PackedVector2Array([At, r1, Bt]), edge, ew, true); c.draw_polyline(PackedVector2Array([Dt, r2, Ct]), edge, ew, true)
		c.draw_line(r1, r2, edge, ew, true)
	else:
		c.draw_colored_polygon(PackedVector2Array([At, Bt, Ct, Dt]), (pal[2] as Color).lerp(edge, lift + 0.05))
		c.draw_polyline(PackedVector2Array([Dt, At, Bt, Ct, Dt]), edge, ew, true)
	c.draw_polyline(PackedVector2Array([D, C, B]), edge, ew, true)
	c.draw_line(Dt, D, edge, ew, true); c.draw_line(Ct, C, edge, ew, true); c.draw_line(Bt, B, edge, ew, true)


class _FxLayer extends Node2D:
	var host
	func _draw() -> void:
		if host != null: host._draw_fx(self)


# ============================================================ UI
const PANEL_W := 440.0

func _build_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	hover_lbl = Label.new()
	hover_lbl.position = Vector2(14, Econ.BAR_H + 8.0)
	hover_lbl.add_theme_font_size_override("font_size", int(round(15 * Settings.text_scale)))
	hover_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	layer.add_child(hover_lbl)
	# the side panel: solid, fixed width, grows to its content — no manual height maths, nothing overflows
	sel_panel = PanelContainer.new()
	sel_panel.anchor_top = 0.0; sel_panel.anchor_bottom = 1.0   # a fixed full-height column: it never runs off-screen
	sel_panel.offset_left = 14; sel_panel.offset_right = 14 + PANEL_W
	sel_panel.offset_top = Econ.BAR_H + 36.0; sel_panel.offset_bottom = -24
	sel_panel.visible = false
	layer.add_child(sel_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sel_panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	sel_title = _mk_label(vb, 22, Color(0.2, 1.0, 0.9), true)
	sel_body = _mk_label(vb, 15, Color(0.82, 0.9, 1.0))
	_seps.append(_sep(vb))
	sel_corp = _mk_label(vb, 14, Color(0.75, 0.95, 1.0))
	_seps.append(_sep(vb))
	sel_bname = _mk_label(vb, 18, Color(0.95, 1.0, 1.0), true)
	sel_meta = _mk_label(vb, 15, Color(0.82, 0.9, 1.0))
	_seps.append(_sep(vb))
	sel_story = _mk_label(vb, 14, Color(0.68, 0.78, 0.9))
	sel_people = _mk_label(vb, 14, Color(0.85, 0.88, 0.95))
	# GO INSIDE: a big solid button pinned to the bottom-right corner, shown while a building is selected
	sel_explore = Button.new()
	sel_explore.text = "GO INSIDE   ▸"
	sel_explore.add_theme_font_size_override("font_size", int(round(22 * Settings.text_scale)))
	sel_explore.add_theme_font_override("font", Settings.font_bold)
	sel_explore.focus_mode = Control.FOCUS_NONE
	sel_explore.anchor_left = 1.0; sel_explore.anchor_right = 1.0; sel_explore.anchor_top = 1.0; sel_explore.anchor_bottom = 1.0
	sel_explore.offset_left = -344; sel_explore.offset_right = -24; sel_explore.offset_top = -92; sel_explore.offset_bottom = -24
	sel_explore.visible = false
	sel_explore.pressed.connect(_enter_building)
	layer.add_child(sel_explore)


func _sep(parent: Node) -> Control:   # a thin rule between panel sections
	var c := ColorRect.new(); c.color = Color(0.2, 1.0, 0.9, 0.22); c.custom_minimum_size = Vector2(0, 1)
	parent.add_child(c)
	return c


func _mk_label(parent: Node, size: int, col: Color, bold := false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", int(round(size * Settings.text_scale)))
	l.add_theme_color_override("font_color", col)
	if bold: l.add_theme_font_override("font", Settings.font_bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _update_sel_panel() -> void:
	if sel_panel == null: return
	if sel_did < 0 or sel_did >= districts.size():
		sel_panel.visible = false
		if sel_explore: sel_explore.visible = false   # no building selected → hide GO INSIDE
		return
	var r = districts[sel_did]
	sel_panel.visible = true
	sel_title.text = str(r.name)
	sel_title.add_theme_color_override("font_color", (r.col as Color).lerp(Color.WHITE, 0.2))
	var nb: int = (_district_lots.get(sel_did, []) as Array).size()
	var info := "%s district  ·  %d buildings  ·  %d cells" % [DTYPE_NAME[str(r.type)], nb, int(r.get("size", 0))]
	match str(r.type):
		"bus": info += "\nOwned by %s" % str(r.org)
		"com": info += ("\nRun by %s (retail arm)" % str(r.org)) if str(r.org) != "" else "\nIndependent traders"
		"res": info += "\n≈%s residents  ·  landlord: %s" % [_money(int(r.get("pop", 0))), str(r.get("landlord", ""))]
		_: info += "\nPublic green space"
	sel_body.text = info
	var has_b := lots.has(selected)
	# corp profile: the selected building's corp occupant, else the district's owner
	var corp := ""
	if has_b and corp_info.has(str(lots[selected].get("occupant", ""))): corp = str(lots[selected].occupant)
	elif corp_info.has(str(r.get("org", ""))): corp = str(r.org)
	sel_corp.visible = corp != ""
	if corp != "":
		var ci: Dictionary = corp_info[corp]
		sel_corp.text = "◆ %s — %s megacorp, est. %d\nDeals in %s.\nCEO %s  ·  HQ: %s\n%d districts  ·  %d buildings  ·  “%s”" % [
			corp.to_upper(), str(ci.label), int(ci.founded), str(ci.blurb), str(ci.ceo), str(ci.hq),
			int(ci.districts), int(ci.buildings), str(ci.slogan)]
	sel_bname.visible = has_b; sel_meta.visible = has_b; sel_story.visible = has_b
	_seps[0].visible = sel_corp.visible; _seps[1].visible = has_b; _seps[2].visible = has_b
	sel_explore.visible = has_b
	sel_people.visible = has_b and not (lots[selected].get("people", []) as Array).is_empty() if has_b else false
	if has_b:
		var b = lots[selected]
		var floors: int = max(1, int(round(float(b.h) / 11.0)))
		sel_bname.text = "▸ " + str(b.get("bname", KIND_NAME[str(b.kind)]))
		var meta := "%s%s  ·  ~%d floors\nOccupant: %s%s\nSecurity: %s\nNetwork: %s" % [
			KIND_NAME[str(b.kind)], ("  · shops below" if bool(b.get("mixed", false)) else ""), floors,
			str(b.get("occupant", "?")), ("  — " + str(b.occ_kind)) if str(b.get("occ_kind", "")) != "" else "",
			str(b.get("sec", "?")), _net_desc(selected)]
		if str(b.get("life", "")) != "": meta += "\n" + str(b.life)
		var hks := "%d,%d" % [selected.x, selected.y]
		if Session.hacked.has(hks):
			var st: Dictionary = Session.hacked[hks]
			meta += "\n◉ UNDER HACK — %d / %d nodes controlled" % [int(st.ctl), int(st.n)]
		sel_meta.text = meta
		sel_story.text = str(b.get("story", ""))
		if sel_people.visible:
			var lines := PackedStringArray(["Owner:" if str(b.kind).begins_with("shop") else "Residents:"])
			for pp in b.people:
				var inc := ("  ·  ¥%s/yr" % _money(int(pp.income))) if int(pp.income) > 0 else ""
				lines.append("• %s, %d — %s%s" % [pp.name, int(pp.age), pp.job, inc])
				lines.append("    %s" % pp.detail)
			sel_people.text = "\n".join(lines)


func _money(v: int) -> String:   # 48200 -> "48,200"
	var sv := str(absi(v)); var out := ""
	while sv.length() > 3:
		out = "," + sv.substr(sv.length() - 3) + out; sv = sv.substr(0, sv.length() - 3)
	return ("-" if v < 0 else "") + sv + out


# one-line network role of a building for the panel
func _net_desc(k: Vector2i) -> String:
	var links: Array = net_links.get(k, [])
	var ups := []; var locs := []
	for o in links:
		if int(lots[o].did) != int(lots[k].did): ups.append("%s (%s)" % [str(lots[o].get("bname", "?")), str(districts[int(lots[o].did)].name)])
		else: locs.append(str(lots[o].get("bname", "?")))
	var role := "CORE" if k == hub_key else ("GATEWAY" if gateways.has(k) else "local node")
	var hops := _route_to(k, hub_key).size() - 1
	var txt := "%s · %d link%s" % [role, links.size(), "" if links.size() == 1 else "s"]
	if not ups.is_empty(): txt += "\n   uplinks → " + ", ".join(ups.slice(0, 4)) + (" +%d" % (ups.size() - 4) if ups.size() > 4 else "")
	if not locs.is_empty(): txt += "\n   local → " + ", ".join(locs.slice(0, 4)) + (" +%d" % (locs.size() - 4) if locs.size() > 4 else "")
	if k != hub_key and hops > 0: txt += "\n   route to the Central HUB: %d hop%s" % [hops, "" if hops == 1 else "s"]
	return txt


func _size_label() -> String:
	var g := _grid_dims()
	return "%s · %d×%d" % [{"large": "Large", "medium": "Medium"}.get(Session.city_size, "Small"), g.x, g.y]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		net_view = not net_view
		_dirty = true
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and lots.has(selected):
		_enter_building()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if lots.has(selected) or sel_did >= 0:
			_clear_selection()
		else:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
