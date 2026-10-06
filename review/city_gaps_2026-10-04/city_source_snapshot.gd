extends Node2D
## RIM — city map (isometric, composed, asymmetric). A believable cyberpunk city:
##  • an ASYMMETRIC development footprint (organic mask) surrounded by countryside + water,
##  • an EXPLICIT road network (varied spacing, no perimeter frame, arterials + local streets,
##    cul-de-sacs, limited bridges) — each road tile drawn from its real connections
##    (straight / bend / T / crossroads / endpoint),
##  • BLOCKS derived from the road network (varied sizes), each a complete site: downtown with a
##    square, apartment courtyards, suburbs with gardens, shopping-centre grounds, parks, waterfront.
## True 2:1 isometric. Deterministic from Session.seed. Selection + hover are live.

const TILE_W := 64.0
const TILE_H := 32.0
const HW := TILE_W * 0.5
const HH := TILE_H * 0.5
const LOD_ZOOM := 0.5   # below this (overview) buildings draw as flat tops and the whole map is baked
const WIN_ZOOM := 1.3   # below this the whole map is baked & retained (pan is free); at/above it the
                        # view is culled and fine detail (windows, curbs, furrows, full trees) appears
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]   # N E S W

const KINDS := {
	"res": ["fh", "ap", "sc"], "com": ["shop_s", "shop_b", "mall"], "bus": ["off_s", "off_m", "corp"],
}
const KIND_NAME := {
	"fh": "Family House", "ap": "Apartment", "sc": "Residential Tower",
	"shop_s": "Corner Shop", "shop_b": "Store", "mall": "Shopping Centre",
	"off_s": "Small Office", "off_m": "Office", "corp": "Corporate Tower", "tree": "Tree",
}
const DTYPE_NAME := {"res": "Residential", "com": "Commercial", "bus": "Downtown", "park": "Green"}
const AREA_NAME := {
	"res": ["Suburb", "Apartments", "Residential Towers"],
	"com": ["Local Shops", "Shopping Centre", "Shopping Centre"],
	"bus": ["Office Park", "Downtown", "Downtown Core"],
	"park": ["Pocket Park", "Park", "Central Park"],
}
const DTYPE_COL := {
	"res": Color(0.95, 0.65, 0.35), "com": Color(1.0, 0.35, 0.8),
	"bus": Color(0.35, 0.85, 1.0),  "park": Color(0.35, 0.85, 0.5),
}
const HOOD_NAMES := ["Rimside", "Lo-Tek", "Chiba", "Glasshouse", "Vantablack Row", "The Sprawl",
	"Ono-Sendai", "Chrome Gardens", "Dog Solitude", "Neon Flats", "Kowloon", "Blackwall"]

var seed := 0
var rng := RandomNumberGenerator.new()
var disable_water := false   # set before _ready to generate a city with no river/lake (structure demo)
var _grid := Vector2i.ZERO
var water := {}        # Vector2i -> true
var land := {}         # Vector2i -> true  (developed footprint, excludes water)
var roads := {}        # Vector2i -> true  (road tiles; may be over water = bridge)
var road_class := {}   # Vector2i -> "art" | "loc"
var deco := {}         # Vector2i -> ground role
var lots := {}         # Vector2i -> building {kind,vari,h,dtype,area,tw,td,ins,did}
var occ := {}          # Vector2i -> anchor tile
var trees := []        # {tile:Vector2, sz, wild:bool}
var districts := []    # {id,type,tier,name,centroid_tile,count}
var country := {}      # Vector2i -> "forest" | "field" | "meadow"  (undeveloped surroundings)
var _world := Rect2()

var camera: Camera2D
var _panning := false
var _lmb_down := false
var _lmb_moved := false
var _hover_tile := Vector2i(-999, -999)
var selected := Vector2i(-999, -999)
var _time := 0.0
# repaint gating + precomputed draw order (perf): redraw only on view/hover/state change, with a
# throttled tick for the neon animation; buildings+trees are depth-sorted ONCE at generation.
var _last_cam := Vector2(INF, INF)
var _last_zoomv := Vector2.ZERO
var _last_hover := Vector2i(-9999, -9999)
var _anim_acc := 1.0
var _dirty := true
var _baked_region := Rect2()   # world rect covered by the last static repaint (detail-zoom margin)
# Batched static bake: on heavy maps the whole static scene is accumulated into ONE triangle array
# (canvas_item_add_triangle_array) so a frame is 1 draw call instead of ~3400 (GL-compat won't batch
# thousands of per-colour draw_colored_polygon calls — that submission cost, not fill, was the wall).
const BAKE_MIN_ITEMS := 400    # only the big (large) map is dense enough to need it; medium/small stay live
var _bake_pts := PackedVector2Array()
var _bake_cols := PackedColorArray()
var _bake_idx := PackedInt32Array()
var _bake_tier := -99          # which tier (0 flat / 1 box) the arrays hold; -99 = unbuilt
var _fx: Node2D         # lightweight overlay carrying ONLY the animated primitives (see _draw_fx)
var _draw_items := []   # [{b:bool, k/i, d:int}] sorted by iso depth
var title_lbl: Label
var hover_lbl: Label
var sel_panel: Panel
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


func _iso(fx: float, fy: float) -> Vector2:
	return Vector2((fx - fy) * HW, (fx + fy) * HH)
func _in_grid(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < _grid.x and t.y < _grid.y
func _is_road(t: Vector2i) -> bool:
	return roads.has(t)


# ============================================================ GENERATION
func _grid_dims() -> Vector2i:
	match Session.city_size:
		"large":  return Vector2i(38, 30)
		"medium": return Vector2i(27, 22)
		_:        return Vector2i(18, 15)


func _generate() -> void:
	water = {}; land = {}; roads = {}; road_class = {}; deco = {}; lots = {}; occ = {}; trees = []; districts = []; country = {}
	var g := _grid_dims()
	_grid = g
	# 1) TERRAIN + asymmetric development footprint
	_carve_water(g)
	var dcx := g.x * (0.5 + rng.randf_range(-0.12, 0.12))
	var dcy := g.y * (0.5 + rng.randf_range(-0.12, 0.12))
	var dev_c := Vector2(dcx, dcy)
	_build_land(g, dev_c)
	# 2) ROADS (explicit network) + 3) BLOCKS derived from it
	var down_c := _build_roads(g, dev_c)
	var blocks := _carve_blocks(g)
	if blocks.is_empty():
		_world = Rect2(Vector2.ZERO, Vector2(100, 100)); return
	# 4) DISTRICT PLAN — reserve sites, residential density by distance to downtown
	_plan_and_fill(blocks, g, down_c)
	# countryside dressing + waterfront + bounds
	_dress_countryside(g)
	_world = Rect2(_iso(0, float(g.y)), Vector2.ONE)
	for pt in [_iso(float(g.x), 0), _iso(0, 0) - Vector2(0, 150), _iso(float(g.x), float(g.y)) + Vector2(0, TILE_H)]:
		_world = _world.merge(Rect2(pt, Vector2.ONE))
	_build_draw_order()


# buildings + trees depth-sorted ONCE (they never move), so _draw does no per-frame allocation/sort
func _build_draw_order() -> void:
	_draw_items = []
	for k in lots:
		_draw_items.append({"b": true, "k": k, "d": k.x + k.y + int(lots[k].td) + int(lots[k].tw)})
	for i in trees.size():
		var tt: Vector2 = trees[i].tile
		_draw_items.append({"b": false, "i": i, "d": int(tt.x + tt.y)})
	_draw_items.sort_custom(func(a, c): return a.d < c.d)


func _carve_water(g: Vector2i) -> void:
	# RESTRAINED water (added after the land structure): a slim 1-tile meandering river, and only
	# occasionally a small lake — so it threads through the city without fragmenting it.
	if disable_water:
		return
	var base := float(g.x) * rng.randf_range(0.36, 0.62)
	var amp := float(g.x) * rng.randf_range(0.05, 0.1)
	var freq := rng.randf_range(0.16, 0.3)
	var phase := rng.randf() * TAU
	for ly in g.y:
		var cx := base + amp * sin(float(ly) * freq + phase)
		var lx := int(round(cx))
		if lx >= 0 and lx < g.x: water[Vector2i(lx, ly)] = true
	if rng.randf() < 0.4:
		var lc := Vector2i(rng.randi_range(3, g.x - 4), rng.randi_range(3, g.y - 4))
		var rad := rng.randf_range(1.6, 2.6)
		for ly in g.y:
			for lx in g.x:
				if Vector2(lx, ly).distance_to(Vector2(lc)) <= rad + rng.randf_range(-0.3, 0.3):
					water[Vector2i(lx, ly)] = true


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
			if water.has(t): continue
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
# the developed footprint (plus a couple of highways leaving to the edge, and limited bridges).
func _build_roads(g: Vector2i, dev_c: Vector2) -> Vector2:
	if land.is_empty(): return dev_c
	var minx := g.x; var maxx := 0; var miny := g.y; var maxy := 0
	for t in land:
		minx = mini(minx, t.x); maxx = maxi(maxx, t.x); miny = mini(miny, t.y); maxy = maxi(maxy, t.y)
	var cx := int(round(dev_c.x)); var cy := int(round(dev_c.y))
	# irregular line positions, spacing 2 near centre → up to 5 at the edge
	var xs := _road_lines(minx + 1, maxx - 1, cx, float(maxx - minx) * 0.5)
	var ys := _road_lines(miny + 1, maxy - 1, cy, float(maxy - miny) * 0.5)
	# the central-most line on each axis is an arterial (avenue) + a bridge corridor
	var art_x: int = xs[0] if not xs.is_empty() else cx
	for x in xs:
		if abs(x - cx) < abs(art_x - cx): art_x = x
	var art_y: int = ys[0] if not ys.is_empty() else cy
	for y in ys:
		if abs(y - cy) < abs(art_y - cy): art_y = y
	# roads only on developed LAND; an arterial may cross WATER as a bridge (limited crossings).
	# Local streets MEANDER (a per-line sine wiggle, rasterised with a horizontal/vertical connector
	# at each step so the line stays 4-connected) → curvy blocks & districts. Arterials stay straight.
	for x in xs:
		var xc: int = int(x)
		var is_art: bool = xc == art_x
		var amp: float = 0.0 if is_art else rng.randf_range(1.0, 2.2)
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
		var amp2: float = 0.0 if is_art2 else rng.randf_range(1.0, 2.2)
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
	# prune: drop road tiles that aren't on land and aren't a needed bridge/leaving-tile with 2+ road
	# neighbours (keeps continuity, avoids stray water roads)
	for t in roads.keys():
		if water.has(t) and _road_dirs(t).size() < 2:
			roads.erase(t); road_class.erase(t)
	# downtown centre = densest land near dev centre
	return dev_c


func _lay_road_cell(t: Vector2i, is_art: bool) -> void:
	if land.has(t): _add_road(t, is_art)
	elif is_art and water.has(t): _add_road(t, true)   # arterial bridge over water


func _turn(d: Vector2i, left: bool) -> Vector2i:
	return Vector2i(d.y, -d.x) if left else Vector2i(-d.y, d.x)


func _add_organic_lanes() -> void:
	var n: int = {"small": 3, "medium": 6, "large": 10}.get(Session.city_size, 4)
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
		if water.has(cur) or land.has(cur):
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
		x += 4 + int(round(5.0 * tdist))      # 4 (tight downtown) … 9 (large suburban blocks)
	return out


func _add_road(t: Vector2i, arterial: bool) -> void:
	if not _in_grid(t): return
	# a road may sit on land, or cross water as a BRIDGE (arterials/leaving routes only)
	if not land.has(t) and not water.has(t):
		# countryside: only keep if it's a leaving highway (contiguous with the network edge)
		pass
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
		if cells.size() >= 1:
			var cs := Vector2.ZERO
			for cc in cells: cs += Vector2(cc)
			blocks.append({"tiles": cells, "centroid": cs / float(cells.size())})
	return blocks


func _plan_and_fill(blocks: Array, g: Vector2i, dev_c: Vector2) -> void:
	blocks.sort_custom(func(a, b): return (a.centroid as Vector2).distance_to(dev_c) < (b.centroid as Vector2).distance_to(dev_c))
	var role := {}
	var n_down: int = {"small": 1, "medium": 3, "large": 4}.get(Session.city_size, 1)
	var n_biz: int = {"small": 0, "medium": 2, "large": 4}.get(Session.city_size, 0)   # satellite CBDs
	var n_shop: int = {"small": 1, "medium": 2, "large": 3}.get(Session.city_size, 1)
	var n_park: int = {"small": 1, "medium": 3, "large": 5}.get(Session.city_size, 1)
	var down_tier: int = {"small": 1, "medium": 2, "large": 2}.get(Session.city_size, 1)
	var res_cap: int = {"small": 1, "medium": 2, "large": 2}.get(Session.city_size, 1)
	var dens_scale: float = {"small": 0.5, "medium": 0.9, "large": 1.05}.get(Session.city_size, 0.5)
	var maxr := 0.0
	for b in blocks: maxr = maxf(maxr, (b.centroid as Vector2).distance_to(dev_c))
	# downtown = central blocks (prefer reasonably sized ones)
	var down_c := dev_c
	var dn := 0
	for i in blocks.size():
		if dn >= n_down: break
		if int((blocks[i].tiles as Array).size()) >= 2:
			role[i] = {"type": "bus", "tier": down_tier}; dn += 1
			down_c = blocks[i].centroid
	# satellite business districts — corporate clusters out in the inner-mid ring, spaced from the
	# core and each other so the city reads as several business quarters, not one tiny downtown
	var bizc := []
	for i in blocks.size():
		if bizc.size() >= n_biz: break
		if role.has(i): continue
		var br: float = (blocks[i].centroid as Vector2).distance_to(dev_c) / maxf(maxr, 1.0)
		if br > 0.2 and br < 0.62 and int((blocks[i].tiles as Array).size()) >= 3:
			var ok := (blocks[i].centroid as Vector2).distance_to(down_c) >= 6.0
			for s in bizc:
				if (blocks[i].centroid as Vector2).distance_to(blocks[s].centroid) < 6.0: ok = false
			if ok: role[i] = {"type": "bus", "tier": maxi(down_tier, 2)}; bizc.append(i)
	# shopping centres — mid-ring, spaced; prefer blocks big enough for a mall + grounds
	var shops := []
	for i in blocks.size():
		if shops.size() >= n_shop: break
		if role.has(i): continue
		var r: float = (blocks[i].centroid as Vector2).distance_to(dev_c) / maxf(maxr, 1.0)
		if r > 0.2 and r < 0.8 and int((blocks[i].tiles as Array).size()) >= 4:
			var ok := true
			for s in shops:
				if (blocks[i].centroid as Vector2).distance_to(blocks[s].centroid) < 5.0: ok = false
			if ok: role[i] = {"type": "com", "tier": 1}; shops.append(i)
	# parks — prefer waterfront/large, then scattered
	var parks := 0
	var order := range(blocks.size())
	order.sort_custom(func(a, b): return _block_waterfront(blocks[a].tiles) and not _block_waterfront(blocks[b].tiles))
	for i in order:
		if parks >= n_park: break
		if role.has(i): continue
		if _block_waterfront(blocks[i].tiles) or rng.randf() < 0.3:
			role[i] = {"type": "park", "tier": clampi(int((blocks[i].tiles as Array).size() / 5), 0, 2)}; parks += 1
	# residential — the rest, density by distance to downtown (one-tier smoothed below)
	for i in blocks.size():
		if role.has(i): continue
		var d: float = clampf((blocks[i].centroid as Vector2).distance_to(down_c) / maxf(maxr, 1.0), 0.0, 1.0)
		var dens := (1.0 - d) * dens_scale + _noise(int(blocks[i].centroid.x), int(blocks[i].centroid.y)) * 0.22
		role[i] = {"type": "res", "tier": clampi(int(round(dens * 2.0)), 0, res_cap)}
	# one-tier smoothing between adjacent residential blocks (via shared road borders)
	var adj := _block_adjacency(blocks)
	for pass_i in 3:
		for i in blocks.size():
			if str(role[i].type) != "res": continue
			for j in adj.get(i, []):
				if str(role[j].type) == "res" and int(role[i].tier) - int(role[j].tier) > 1:
					role[i].tier = int(role[j].tier) + 1
	# districts (merge connected same-type, within-one-tier res) + ids
	_assign_districts(blocks, role, adj)
	# fill each block
	for i in blocks.size():
		var tiles: Array = blocks[i].tiles
		match str(role[i].type):
			"bus":  _fill_downtown(tiles, int(role[i].tier), int(role[i].get("did", 0)))
			"com":  _fill_shopping(tiles, int(role[i].get("did", 0)))
			"park": _fill_park(tiles)
			_:      _fill_residential(tiles, int(role[i].tier), int(role[i].get("did", 0)))
	# waterfront promenade
	for t in land:
		if not occ.has(t) and not deco.has(t) and not roads.has(t) and _beside_water(t):
			deco[t] = "prom"


func _block_waterfront(tiles: Array) -> bool:
	for t in tiles:
		if _beside_water(t): return true
	return false

func _beside_water(t: Vector2i) -> bool:
	for d in DIRS:
		if water.has(t + d): return true
	return false


func _block_adjacency(blocks: Array) -> Dictionary:
	# two blocks are adjacent if a single road tile separates them (reachable across a street)
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
	var out := {}
	for i in adj: out[i] = adj[i].keys()
	return out


func _assign_districts(blocks: Array, role: Dictionary, adj: Dictionary) -> void:
	var seen := {}
	var did := 0
	for i in blocks.size():
		if seen.has(i): continue
		var typ: String = str(role[i].type)
		var tier: int = int(role[i].tier)
		var stack := [i]; var members := []
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			if seen.has(cur) or str(role[cur].type) != typ: continue
			if typ == "res" and absi(int(role[cur].tier) - tier) > 1: continue
			seen[cur] = did; members.append(cur)
			for j in adj.get(cur, []):
				if not seen.has(j): stack.append(j)
		var cs := Vector2.ZERO; var cnt := 0
		for m in members:
			role[m]["did"] = did
			cs += blocks[m].centroid; cnt += 1
		var nm: String = AREA_NAME[typ][tier]
		if typ == "res" and tier >= 1: nm = HOOD_NAMES[did % HOOD_NAMES.size()]
		if cnt > 0:
			districts.append({"id": did, "type": typ, "tier": tier, "name": nm, "centroid_tile": cs / float(cnt), "count": cnt})
		did += 1


func _place(k: Vector2i, kind: String, dtype: String, tier: int, ins: float, tw := 1, td := 1, did := 0) -> bool:
	for dx in tw:
		for dy in td:
			var c := Vector2i(k.x + dx, k.y + dy)
			if not land.has(c) or roads.has(c) or water.has(c) or occ.has(c) or lots.has(c):
				return false
	var vari := rng.randi() % 3
	lots[k] = {"kind": kind, "vari": vari, "h": _height_for(kind, vari), "dtype": dtype,
		"area": AREA_NAME[dtype][tier], "tw": tw, "td": td, "ins": ins, "did": did}
	for dx in tw:
		for dy in td:
			occ[Vector2i(k.x + dx, k.y + dy)] = k
	return true


func _fill_downtown(tiles: Array, tier: int, did: int) -> void:
	tiles.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
	var plaza: Vector2i = tiles[tiles.size() / 2]
	deco[plaza] = "plaza"
	var landmark := true
	for t in tiles:
		if t == plaza or occ.has(t): continue
		var kind: String
		if tier >= 2:
			kind = "corp" if (landmark or rng.randf() < 0.55) else ("off_m" if rng.randf() < 0.6 else "off_s")
		else:
			kind = "off_m" if (landmark or rng.randf() < 0.45) else "off_s"
		_place(t, kind, "bus", tier, 0.08, 1, 1, did)
		landmark = false


func _fill_shopping(tiles: Array, did: int) -> void:
	tiles.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
	# try a 2×2 mall; on a bigger site also a 2×1 annex — varied grounds
	var placed_mall := false
	for t in tiles:
		if _place(t, "mall", "com", 1, 0.06, 2, 2, did):
			placed_mall = true
			deco[Vector2i(t.x, t.y + 2)] = "plaza"
			break
	for t in tiles:
		if occ.has(t) or lots.has(t): continue
		var r := rng.randf()
		if r < 0.42: deco[t] = "parking"
		elif r < 0.62: deco[t] = "plaza"
		else: _place(t, "shop_s" if rng.randf() < 0.6 else "shop_b", "com", 0, 0.18, 1, 1, did)
	if not placed_mall and not tiles.is_empty():
		_place(tiles[0], "shop_b", "com", 0, 0.16, 1, 1, did)


func _fill_park(tiles: Array) -> void:
	tiles.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
	var path_row := int(tiles[tiles.size() / 2].y)
	for t in tiles:
		if t.y == path_row:
			deco[t] = "path"
		else:
			deco[t] = "park"
			if rng.randf() < 0.75:
				trees.append({"tile": Vector2(t) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)), "sz": rng.randf_range(8.0, 13.0), "wild": false})


func _fill_residential(tiles: Array, tier: int, did: int) -> void:
	var centre := Vector2.ZERO
	for t in tiles: centre += Vector2(t)
	centre /= float(max(1, tiles.size()))
	var court: Vector2i = tiles[0]; var bestd := INF
	for t in tiles:
		var dd: float = Vector2(t).distance_to(centre)
		if dd < bestd: bestd = dd; court = t
	var shop_tile := Vector2i(-999, -999)
	if rng.randf() < 0.3: shop_tile = tiles[rng.randi() % tiles.size()]
	for t in tiles:
		if occ.has(t): continue
		if t == shop_tile:
			_place(t, "shop_s", "com", 0, 0.2, 1, 1, did); continue
		match tier:
			0:
				if rng.randf() < 0.74:
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
				else:
					_place(t, "ap", "res", 1, 0.1, 1, 1, did)
			_:
				if t == court and rng.randf() < 0.5: deco[t] = "plaza"
				else: _place(t, "sc", "res", 2, 0.14, 1, 1, did)


func _dress_countryside(g: Vector2i) -> void:
	# classify undeveloped land into coherent patches (coarse noise) of FOREST / FIELD / MEADOW and
	# populate them — dense trees in forests, furrowed crop fields, open meadows.
	for ly in g.y:
		for lx in g.x:
			var t := Vector2i(lx, ly)
			if water.has(t) or land.has(t) or roads.has(t): continue
			var cl := _noise(int(lx / 3) * 7 + 3, int(ly / 3) * 7 + 9)    # ~3-tile patches
			var fine := _noise(lx * 2 + 5, ly * 2 + 11)
			var ct := "forest" if cl > 0.18 else ("field" if cl < -0.18 else "meadow")
			country[t] = ct
			match ct:
				"forest":
					var n := 2 + (1 if fine > 0.0 else 0)
					for i in n:
						trees.append({"tile": Vector2(t) + Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.15, 0.85)), "sz": rng.randf_range(6.0, 11.0), "wild": true})
				"meadow":
					if fine > 0.05:
						trees.append({"tile": Vector2(t) + Vector2(0.5, 0.5), "sz": rng.randf_range(6.0, 9.0), "wild": true})
				_:
					if rng.randf() < 0.1:
						trees.append({"tile": Vector2(t) + Vector2(0.8, 0.2), "sz": rng.randf_range(6.0, 8.0), "wild": true})


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
	_update_hover()
	# Repaint gating. Canvas items are RETAINED: the Camera2D transform pans/zooms already-drawn
	# commands on the GPU for free, so _draw only needs to re-run when the drawn CONTENT changes.
	# At overview the whole map is baked into the canvas (see _draw), so panning, hover and the neon
	# animation never force a (costly, ~everything-visible) repaint — only selection or a zoom change
	# does. When zoomed in, culling makes repaints cheap, so pan/hover/anim repaint normally there.
	_anim_acc += dt
	# While the whole map is baked (zoom < WIN_ZOOM) the Camera2D pans/zooms the retained canvas for
	# free, so the static scene repaints only on a zoom change or a content change. Panning, hover and
	# the neon animation ride the cheap _fx overlay instead. Zoomed in past WIN_ZOOM the view is culled
	# to a neighbourhood, so repainting on pan there is cheap and done normally.
	var baked: bool = _is_baked()
	var zoomed: bool = camera.zoom != _last_zoomv
	var moved: bool = camera.position != _last_cam
	var hov: bool = _hover_tile != _last_hover
	# At detail zoom the last repaint covered a margin around the view; only repaint once the camera
	# has panned far enough that the view leaves that baked region. (Heavy maps are always baked.)
	var escaped: bool = not baked and moved and not _baked_region.encloses(_cam_view())
	var repaint: bool = _dirty or zoomed or escaped
	var tick: bool = (not Settings.reduced_motion) and _anim_acc >= 0.05
	if repaint:
		_dirty = false
		_last_cam = camera.position; _last_zoomv = camera.zoom; _last_hover = _hover_tile
		queue_redraw()
		if _fx != null: _fx.queue_redraw()   # keep the overlay in step with content changes
	elif hov or tick:
		_last_hover = _hover_tile
		if tick: _anim_acc = 0.0
		if _fx != null: _fx.queue_redraw()   # hover highlight + animation, without rebuilding the scene


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


func _grid_rect() -> Rect2i:
	return Rect2i(0, 0, _grid.x, _grid.y)


func _cam_view() -> Rect2:   # the world rect currently visible through the camera
	var vp: Vector2 = get_viewport_rect().size / camera.zoom.x
	return Rect2(camera.position - vp * 0.5, vp)


# "Baked" = the whole static scene is drawn & retained, so panning needs no repaint. True while zoomed
# out (zoom < WIN_ZOOM) and ALWAYS for a heavy map, whose scene is a single batched draw at any zoom.
func _is_baked() -> bool:
	return _draw_items.size() > BAKE_MIN_ITEMS or camera.zoom.x < WIN_ZOOM


# tile-index bounds covering the view rect (invert the iso of its corners) → cull ground iteration
func _visible_tiles(view: Rect2) -> Rect2i:
	var minfx := INF; var maxfx := -INF; var minfy := INF; var maxfy := -INF
	for cp in [view.position, Vector2(view.end.x, view.position.y), Vector2(view.position.x, view.end.y), view.end]:
		var fx: float = cp.x / (2.0 * HW) + cp.y / (2.0 * HH)
		var fy: float = cp.y / (2.0 * HH) - cp.x / (2.0 * HW)
		minfx = minf(minfx, fx); maxfx = maxf(maxfx, fx); minfy = minf(minfy, fy); maxfy = maxf(maxfy, fy)
	var x0 := clampi(int(floor(minfx)) - 1, 0, _grid.x)
	var y0 := clampi(int(floor(minfy)) - 1, 0, _grid.y)
	var x1 := clampi(int(ceil(maxfx)) + 2, 0, _grid.x)
	var y1 := clampi(int(ceil(maxfy)) + 2, 0, _grid.y)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))


func _box_hull(k: Vector2i) -> PackedVector2Array:
	var b = lots[k]
	var tw: float = float(b.tw); var td: float = float(b.td); var ins: float = float(b.ins); var h: float = float(b.h)
	var up := Vector2(0, -h)
	var A := _iso(k.x + ins, k.y + ins); var B := _iso(k.x + tw - ins, k.y + ins)
	var C := _iso(k.x + tw - ins, k.y + td - ins); var D := _iso(k.x + ins, k.y + td - ins)
	return PackedVector2Array([A + up, B + up, B, C, D, D + up])


func _building_at(wpos: Vector2) -> Vector2i:
	var best := Vector2i(-999, -999); var best_d := -100000
	for k in lots:
		if Geometry2D.is_point_in_polygon(wpos, _box_hull(k)):
			var d: int = k.x + k.y + int(lots[k].tw) + int(lots[k].td)
			if d > best_d: best_d = d; best = k
	return best


func _select_at(wpos: Vector2) -> void:
	selected = _building_at(wpos); _dirty = true; _update_sel_panel()


func _update_hover() -> void:
	var t := _screen_to_tile(get_global_mouse_position())
	if t != _hover_tile: _hover_tile = t
	if hover_lbl == null: return
	var k := _hover_tile
	var bk: Vector2i = occ[k] if occ.has(k) else k
	if lots.has(bk):
		hover_lbl.text = "%s  ·  %s" % [KIND_NAME[str(lots[bk].kind)], str(lots[bk].area)]
	elif water.has(k):
		hover_lbl.text = "Water"
	elif roads.has(k):
		hover_lbl.text = ("Avenue" if str(road_class.get(k, "loc")) == "art" else "Street") + (" (bridge)" if water.has(k) else "")
	elif deco.has(k):
		hover_lbl.text = {"park": "Park", "garden": "Garden", "court": "Courtyard", "plaza": "Public square", "parking": "Parking", "prom": "Waterfront promenade", "path": "Park path"}.get(str(deco[k]), "Open space")
	elif land.has(k):
		hover_lbl.text = "Open parcel"
	else:
		hover_lbl.text = "Countryside"


# ============================================================ RENDERING
func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp: Vector2 = get_viewport_rect().size / camera.zoom.x
	var view := Rect2(camera.position - vp * 0.5, vp).grow(TILE_W * 2.0)
	# When baked the canvas is retained and panned by the camera without repainting, so the WHOLE
	# map is drawn. Zoomed in past WIN_ZOOM, draw the view plus a half-screen margin (so panning
	# within the margin needs no repaint — see _process) and cull everything else.
	# Heavy map (the large city): ALWAYS emit the whole static scene as one batched triangle array,
	# at EVERY zoom — otherwise zooming in drops into the live per-building path and reloads the whole
	# visible city each frame (the "very loaded / low FPS when zoomed in" case). Panning is retained.
	var heavy := _draw_items.size() > BAKE_MIN_ITEMS
	var baked := camera.zoom.x < WIN_ZOOM
	if heavy:
		var tier := 0 if camera.zoom.x < LOD_ZOOM else 1
		if _bake_tier != tier:
			_build_bake(tier); _bake_tier = tier
		if not _bake_idx.is_empty():
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _bake_idx, _bake_pts, _bake_cols)
		_baked_region = Rect2(-1e12, -1e12, 2e12, 2e12)
	else:
		var cull: Rect2; var tb: Rect2i
		if baked:
			cull = Rect2(-1e9, -1e9, 2e9, 2e9); tb = _grid_rect()
			_baked_region = Rect2(-1e12, -1e12, 2e12, 2e12)
		else:
			cull = view.grow(maxf(vp.x, vp.y) * 0.35); tb = _visible_tiles(cull)
			_baked_region = cull
		for ly in range(tb.position.y, tb.end.y):
			for lx in range(tb.position.x, tb.end.x):
				_draw_ground_tile(lx, ly)
		# buildings + trees in the precomputed depth order (no per-frame sort), culled
		for it in _draw_items:
			if it.b:
				_draw_isobox(it.k, font, cull)
			else:
				_draw_tree(trees[it.i], cull)
	if camera.zoom.x < 1.9:
		for r in districts:
			if int(r.count) < 1: continue
			var dc: Color = DTYPE_COL[str(r.type)]
			var pcen := _iso(float(r.centroid_tile.x) + 0.5, float(r.centroid_tile.y) + 0.5)
			draw_string(font, pcen - Vector2(34, 2), str(r.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(dc.r, dc.g, dc.b, 0.6))


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
func _bline(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var o := (b - a).orthogonal().normalized() * (w * 0.5)
	if o == Vector2.ZERO: return
	_bq(a + o, b + o, b - o, a - o, col)
func _bdot(c: Vector2, r: float, col: Color) -> void:
	_bq(c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r), col)


func _build_bake(tier: int) -> void:
	_bake_pts = PackedVector2Array(); _bake_cols = PackedColorArray(); _bake_idx = PackedInt32Array()
	for ly in _grid.y:
		for lx in _grid.x:
			_bake_ground(lx, ly)
	for it in _draw_items:   # already depth-sorted → painter order preserved within the array
		if it.b: _bake_building(it.k, tier)
		else: _bake_tree_blob(trees[it.i])


func _bake_ground(lx: int, ly: int) -> void:
	var k := Vector2i(lx, ly)
	var q := _tile_quad(lx, ly)
	if water.has(k) and not roads.has(k):
		_bqp(q, Color(0.07, 0.22, 0.42)); return
	if roads.has(k):
		_bake_road(lx, ly); return
	if not land.has(k):
		var ct := str(country.get(k, "meadow"))
		_bqp(q, Color(0.05, 0.13, 0.06) if ct == "forest" else (Color(0.13, 0.14, 0.08) if ct == "field" else Color(0.08, 0.14, 0.08)))
		return
	if deco.has(k):
		match str(deco[k]):
			"park": _bqp(q, Color(0.12, 0.26, 0.15))
			"garden", "court": _bqp(q, Color(0.11, 0.22, 0.13))
			"path": _bqp(q, Color(0.22, 0.2, 0.16))
			"plaza": _bqp(q, Color(0.2, 0.2, 0.24))
			"parking": _bqp(q, Color(0.13, 0.13, 0.15))
			"prom": _bqp(q, Color(0.2, 0.22, 0.24))
			_: _bqp(q, Color(0.19, 0.2, 0.24))
		return
	_bqp(q, Color(0.19, 0.2, 0.24))   # sidewalk pad


func _bake_road(lx: int, ly: int) -> void:
	var k := Vector2i(lx, ly)
	var art: bool = str(road_class.get(k, "loc")) == "art"
	if water.has(k):
		_bqp(_tile_quad(lx, ly), Color(0.07, 0.2, 0.4))
		_bqp(_tile_quad(lx + 0.08, ly + 0.08, 0.84, 0.84), Color(0.17, 0.18, 0.21))
	else:
		_bqp(_tile_quad(lx, ly), Color(0.12, 0.13, 0.17) if art else Color(0.09, 0.1, 0.13))
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
	var tw: float = float(b.tw); var td: float = float(b.td); var ins: float = float(b.ins); var h: float = float(b.h)
	var up := Vector2(0, -h)
	var A := _iso(k.x + ins, k.y + ins); var B := _iso(k.x + tw - ins, k.y + ins)
	var C := _iso(k.x + tw - ins, k.y + td - ins); var D := _iso(k.x + ins, k.y + td - ins)
	var At := A + up; var Bt := B + up; var Ct := C + up; var Dt := D + up
	var kind := str(b.kind)
	var base: Color = DTYPE_COL[str(b.dtype)]
	var hue: Color
	if kind == "fh": hue = Color(0.62, 0.52, 0.42).lerp(Color(0.7, 0.6, 0.48), 0.3 * float(b.vari))
	elif kind == "ap": hue = Color(0.43, 0.45, 0.52).lerp(Color(0.5, 0.5, 0.57), 0.3 * float(b.vari))
	else: hue = base.lerp(Color(0.6, 0.62, 0.72), 0.32 + 0.14 * float(b.vari))
	var top := Color(hue.r * 0.6, hue.g * 0.62, hue.b * 0.7)
	_bq(D, C, Ct, Dt, Color(hue.r * 0.34, hue.g * 0.36, hue.b * 0.44))
	_bq(B, C, Ct, Bt, Color(hue.r * 0.46, hue.g * 0.48, hue.b * 0.56))
	if tier == 0:
		_bq(At, Bt, Ct, Dt, Color(0.5, 0.26, 0.2) if kind == "fh" else top)
		return
	var edge := Color(base.r, base.g, base.b, 0.6)
	if kind == "fh":
		var rh := minf(h * 0.9, 10.0)
		var r1 := (At + Bt) * 0.5 + Vector2(0, -rh)
		var r2 := (Dt + Ct) * 0.5 + Vector2(0, -rh)
		_bq(At, Dt, r2, r1, Color(0.42, 0.21, 0.17))
		_bq(Bt, Ct, r2, r1, Color(0.58, 0.3, 0.23))
		_btri(Dt, Ct, r2, Color(0.5, 0.26, 0.2))
		_bline(At, r1, 1.0, edge); _bline(r1, Bt, 1.0, edge); _bline(Dt, r2, 1.0, edge); _bline(r2, Ct, 1.0, edge)
	else:
		_bq(At, Bt, Ct, Dt, top)
		_bline(Dt, At, 1.0, edge); _bline(At, Bt, 1.0, edge); _bline(Bt, Ct, 1.0, edge)
	_bline(D, C, 1.0, edge); _bline(C, B, 1.0, edge)
	_bline(Dt, D, 1.0, edge); _bline(Ct, C, 1.0, edge); _bline(Bt, B, 1.0, edge)


func _bake_tree_blob(tr: Dictionary) -> void:
	var cz: float = tr.sz
	var c := _iso(tr.tile.x, tr.tile.y) + Vector2(0, -cz * 1.3)
	var r := cz * 1.05
	var prev := c + Vector2(r, 0)
	for s in range(1, 7):   # hexagon approximation of the canopy circle
		var p := c + Vector2(cos(float(s) / 6.0 * TAU), sin(float(s) / 6.0 * TAU)) * r
		_btri(c, prev, p, Color(0.12, 0.4, 0.19))
		prev = p


func _draw_ground_tile(lx: int, ly: int) -> void:
	var k := Vector2i(lx, ly)
	var quad := _tile_quad(lx, ly)
	var is_water: bool = water.has(k)
	var is_road: bool = roads.has(k)
	if is_water and not is_road:
		# flat base; the animated shimmer is overlaid by the _fx layer so this stays retained
		draw_colored_polygon(quad, Color(0.07, 0.22, 0.42))
		draw_polyline(_closed(quad), Color(0.2, 0.5, 0.8, 0.3), 1.0)
		return
	if is_road:
		_draw_road_tile(lx, ly)
		return
	if not land.has(k):
		_draw_country_tile(lx, ly, quad)
		return
	if deco.has(k):
		match str(deco[k]):
			"park", "garden", "court":
				draw_colored_polygon(quad, Color(0.12, 0.26, 0.15) if str(deco[k]) == "park" else Color(0.11, 0.22, 0.13))
			"path":
				draw_colored_polygon(quad, Color(0.22, 0.2, 0.16))
			"plaza":
				draw_colored_polygon(quad, Color(0.2, 0.2, 0.24))
				draw_polyline(_closed(_tile_quad(lx + 0.2, ly + 0.2, 0.6, 0.6)), Color(0.4, 0.45, 0.55, 0.4), 1.0)
			"parking":
				draw_colored_polygon(quad, Color(0.13, 0.13, 0.15))
				draw_line(_iso(lx + 0.33, ly + 0.2), _iso(lx + 0.33, ly + 0.8), Color(0.5, 0.5, 0.3, 0.3), 1.0)
				draw_line(_iso(lx + 0.66, ly + 0.2), _iso(lx + 0.66, ly + 0.8), Color(0.5, 0.5, 0.3, 0.3), 1.0)
			"prom":
				draw_colored_polygon(quad, Color(0.2, 0.22, 0.24))
		if _hover_tile == k: draw_polyline(_closed(quad), Color(1, 1, 1, 0.7), 1.2)
		return
	# a grounded building-lot / sidewalk pad — lighter than the roads so blocks read as solid ground
	draw_colored_polygon(quad, Color(0.19, 0.2, 0.24))
	if _hover_tile == k: draw_polyline(_closed(quad), Color(1, 1, 1, 0.7), 1.2)


func _draw_country_tile(lx: int, ly: int, quad: PackedVector2Array) -> void:
	var ct := str(country.get(Vector2i(lx, ly), "meadow"))
	if ct == "forest":
		draw_colored_polygon(quad, Color(0.05, 0.13, 0.06))
	elif ct == "field":
		draw_colored_polygon(quad, Color(0.13, 0.14, 0.08))
		if camera.zoom.x >= WIN_ZOOM:   # LOD: skip furrow lines at overview zoom
			var fc := Color(0.17, 0.18, 0.1, 0.7)
			var rows := (int(lx / 3) + int(ly / 3)) % 2 == 0   # alternate furrow direction per patch
			for f in [0.25, 0.5, 0.75]:
				if rows: draw_line(_iso(lx, ly + f), _iso(lx + 1, ly + f), fc, 1.0)
				else: draw_line(_iso(lx + f, ly), _iso(lx + f, ly + 1), fc, 1.0)
	else:
		draw_colored_polygon(quad, Color(0.08, 0.14, 0.08))


# draw a road tile from its CONNECTIONS (straight / bend / T / cross / endpoint); centre lines only
# follow directions that actually connect, so straight stretches never show a crossing.
func _draw_road_tile(lx: int, ly: int) -> void:
	var k := Vector2i(lx, ly)
	var quad := _tile_quad(lx, ly)
	var art: bool = str(road_class.get(k, "loc")) == "art"
	var bridge: bool = water.has(k)
	if bridge:
		# water under the deck + a raised deck
		draw_colored_polygon(quad, Color(0.07, 0.2, 0.4))
		draw_colored_polygon(_tile_quad(lx + 0.08, ly + 0.08, 0.84, 0.84), Color(0.17, 0.18, 0.21))
	else:
		draw_colored_polygon(quad, Color(0.12, 0.13, 0.17) if art else Color(0.09, 0.1, 0.13))
	var rN := roads.has(Vector2i(lx, ly - 1)); var rE := roads.has(Vector2i(lx + 1, ly))
	var rS := roads.has(Vector2i(lx, ly + 1)); var rW := roads.has(Vector2i(lx - 1, ly))
	var P00 := _iso(lx, ly); var P10 := _iso(lx + 1, ly); var P11 := _iso(lx + 1, ly + 1); var P01 := _iso(lx, ly + 1)
	var cen := _iso(lx + 0.5, ly + 0.5)
	# LOD: curbs are hairline until close in — skip them (4 lines × every road tile).
	if camera.zoom.x >= WIN_ZOOM:
		var curb := Color(0.42, 0.45, 0.52, 0.7)
		if not rN and not water.has(Vector2i(lx, ly - 1)): draw_line(P00, P10, curb, 1.0)
		if not rE and not water.has(Vector2i(lx + 1, ly)): draw_line(P10, P11, curb, 1.0)
		if not rS and not water.has(Vector2i(lx, ly + 1)): draw_line(P01, P11, curb, 1.0)
		if not rW and not water.has(Vector2i(lx - 1, ly)): draw_line(P00, P01, curb, 1.0)
	var mc := Color(0.3, 0.95, 1.0, 0.65) if art else Color(0.72, 0.74, 0.55, 0.5)
	var mw := 2.0 if art else 1.0
	var cnt := (1 if rN else 0) + (1 if rE else 0) + (1 if rS else 0) + (1 if rW else 0)
	if cnt == 0:
		draw_circle(cen, 3.0, mc)
	else:
		if rN: draw_line(cen, (P00 + P10) * 0.5, mc, mw)
		if rE: draw_line(cen, (P10 + P11) * 0.5, mc, mw)
		if rS: draw_line(cen, (P01 + P11) * 0.5, mc, mw)
		if rW: draw_line(cen, (P00 + P01) * 0.5, mc, mw)
		if cnt == 1: draw_circle(cen, 2.5, mc)   # cul-de-sac / endpoint cap

func _draw_isobox(k: Vector2i, font: Font, view: Rect2) -> void:
	var b = lots[k]
	var tw: float = float(b.tw); var td: float = float(b.td); var ins: float = float(b.ins); var h: float = float(b.h)
	var up := Vector2(0, -h)
	var A := _iso(k.x + ins, k.y + ins); var B := _iso(k.x + tw - ins, k.y + ins)
	var C := _iso(k.x + tw - ins, k.y + td - ins); var D := _iso(k.x + ins, k.y + td - ins)
	if not view.has_point(C) and not view.has_point(A + up):
		return
	var At := A + up; var Bt := B + up; var Ct := C + up; var Dt := D + up
	var kind := str(b.kind)
	var base: Color = DTYPE_COL[str(b.dtype)]
	var hue: Color
	if kind == "fh":
		hue = Color(0.62, 0.52, 0.42).lerp(Color(0.7, 0.6, 0.48), 0.3 * float(b.vari))
	elif kind == "ap":
		hue = Color(0.43, 0.45, 0.52).lerp(Color(0.5, 0.5, 0.57), 0.3 * float(b.vari))
	else:
		hue = base.lerp(Color(0.6, 0.62, 0.72), 0.32 + 0.14 * float(b.vari))
	var top := Color(hue.r * 0.6, hue.g * 0.62, hue.b * 0.7)
	var lface := Color(hue.r * 0.34, hue.g * 0.36, hue.b * 0.44)
	var rface := Color(hue.r * 0.46, hue.g * 0.48, hue.b * 0.56)
	var edge := Color(base.r, base.g, base.b, 0.6)   # hover highlight is drawn by the _fx overlay
	draw_colored_polygon(PackedVector2Array([D, C, Ct, Dt]), lface)
	draw_colored_polygon(PackedVector2Array([B, C, Ct, Bt]), rface)
	# LOD: at overview zoom a building is a few px tall — draw only the flat top face (3 polygons
	# total, no outlines/roof/windows/features). Cuts per-building draw calls ~3x on dense maps.
	if camera.zoom.x < LOD_ZOOM:
		draw_colored_polygon(PackedVector2Array([At, Bt, Ct, Dt]), (Color(0.5, 0.26, 0.2) if kind == "fh" else top))
		if k == selected:
			draw_polyline(_closed(PackedVector2Array([At, Bt, B, C, D, Dt])), Color(1, 1, 1, 0.95), 2.5)
		return
	if kind == "fh":
		var rh := minf(h * 0.9, 10.0)
		var r1 := (At + Bt) * 0.5 + Vector2(0, -rh)
		var r2 := (Dt + Ct) * 0.5 + Vector2(0, -rh)
		draw_colored_polygon(PackedVector2Array([At, Dt, r2, r1]), Color(0.42, 0.21, 0.17))
		draw_colored_polygon(PackedVector2Array([Bt, Ct, r2, r1]), Color(0.58, 0.3, 0.23))
		draw_colored_polygon(PackedVector2Array([Dt, Ct, r2]), Color(0.5, 0.26, 0.2))
		draw_line(r1, r2, Color(0.2, 0.1, 0.08), 1.0)
		draw_polyline(PackedVector2Array([At, r1, Bt]), edge, 1.0)
		draw_polyline(PackedVector2Array([Dt, r2, Ct]), edge, 1.0)
	else:
		draw_colored_polygon(PackedVector2Array([At, Bt, Ct, Dt]), top)
		draw_polyline(PackedVector2Array([Dt, At, Bt]), edge, 1.0)
		draw_polyline(PackedVector2Array([Ct, Bt]), edge, 1.0)
	draw_polyline(PackedVector2Array([D, C, B]), edge, 1.0)
	draw_line(Dt, D, edge, 1.0); draw_line(Ct, C, edge, 1.0); draw_line(Bt, B, edge, 1.0)
	if k == selected:
		draw_polyline(_closed(PackedVector2Array([At, Bt, B, C, D, Dt])), Color(1, 1, 1, 0.95), 2.5)
	_draw_feature(b, At, Bt, Ct, Dt, D, C, B)
	if camera.zoom.x >= WIN_ZOOM:   # windows are tiny speckles until zoomed in close
		_draw_windows(b, D, C, B, h)


func _draw_windows(b: Dictionary, D: Vector2, C: Vector2, B: Vector2, h: float) -> void:
	var wc: Color = _window_col(str(b.dtype))
	var rows := int(clampf(h / 20.0, 1.0, 6.0))   # capped: keeps the retained rect count in check
	var up := Vector2(0, -h)
	for wall in 2:
		var p0: Vector2 = D if wall == 0 else B
		for r in rows:
			var fy := (float(r) + 0.5) / float(rows)
			for cwx in 2:
				var fx := 0.3 + float(cwx) * 0.4
				if ((r * 5 + cwx * 7 + int(b.vari) * 3 + int(p0.x)) % 5) == 0: continue
				draw_rect(Rect2(p0.lerp(C, fx) + up * fy - Vector2(1.5, 1.5), Vector2(3, 3)), wc, true)


func _draw_feature(b: Dictionary, At: Vector2, Bt: Vector2, Ct: Vector2, Dt: Vector2, D: Vector2, C: Vector2, B: Vector2) -> void:
	var topc := (At + Ct) * 0.5
	match str(b.kind):
		"fh":
			draw_rect(Rect2(B.lerp(C, 0.5) + Vector2(-2, -7), Vector2(3, 7)), Color(0.35, 0.22, 0.14), true)
			draw_rect(Rect2(D.lerp(C, 0.5) + Vector2(-1, -6), Vector2(3, 3)), Color(1.0, 0.75, 0.4, 0.85), true)
		"ap":
			for band in [0.32, 0.6, 0.85]:
				var yb := Vector2(0, -float(b.h) * band)
				draw_line(D + yb, C + yb, Color(0.28, 0.31, 0.38, 0.6), 1.0)
				draw_line(B + yb, C + yb, Color(0.34, 0.37, 0.44, 0.6), 1.0)
		"sc":
			draw_line(topc, topc + Vector2(0, -16), Color(0.6, 0.7, 0.8), 1.5)
			draw_circle(topc + Vector2(0, -16), 2.0, Color(1.0, 0.3, 0.3, 0.6 + 0.4 * sin(_time * 4.0)))
		"corp":
			draw_colored_polygon(PackedVector2Array([At, Bt, Ct, Dt]), Color(0.35, 0.85, 1.0, 0.2))
			draw_line(topc, topc + Vector2(0, -26), Color(0.4, 0.8, 1.0, 0.8), 2.0)
			draw_circle(topc + Vector2(0, -26), 2.5, Color(0.5, 0.9, 1.0, 0.7 + 0.3 * sin(_time * 3.0)))
		"mall":
			draw_colored_polygon(PackedVector2Array([At, Bt, Ct, Dt]), Color(0.2, 0.95, 1.0, 0.18))
			draw_rect(Rect2(C + Vector2(-9, -12), Vector2(18, 10)), Color(1.0, 0.3, 0.8, 0.5), true)
		"shop_s", "shop_b":
			draw_rect(Rect2(C + Vector2(-7, -6), Vector2(14, 3)), Color(1.0, 0.35, 0.8, 0.8), true)


func _window_col(dtype: String) -> Color:
	match dtype:
		"res": return Color(1.0, 0.72, 0.35, 0.85)
		"com": return Color(1.0, 0.4, 0.85, 0.8)
		_:     return Color(0.45, 0.9, 1.0, 0.8)


func _draw_tree(tr: Dictionary, view: Rect2) -> void:
	var base: Vector2 = _iso(tr.tile.x, tr.tile.y)
	if not view.has_point(base): return
	var cz: float = tr.sz
	if camera.zoom.x < WIN_ZOOM:
		# LOD: one canopy blob instead of trunk + 3 circles until zoomed in close (256 trees on large).
		draw_circle(base + Vector2(0, -cz * 1.3), cz * 1.05, Color(0.12, 0.4, 0.19))
		return
	var tip := base + Vector2(0, -cz * 1.5)
	var trunk := Color(0.2, 0.15, 0.1) if bool(tr.get("wild", false)) else Color(0.22, 0.16, 0.12)
	draw_line(base, tip, trunk, maxf(1.5, cz * 0.22))
	var g1 := Color(0.1, 0.34, 0.16) if bool(tr.get("wild", false)) else Color(0.14, 0.42, 0.2)
	draw_circle(tip + Vector2(0, -cz * 0.3), cz * 0.95, g1)
	draw_circle(tip + Vector2(-cz * 0.5, 0.0), cz * 0.7, Color(g1.r + 0.04, g1.g + 0.1, g1.b + 0.06))
	draw_circle(tip + Vector2(cz * 0.5, cz * 0.1), cz * 0.65, Color(g1.r + 0.06, g1.g + 0.14, g1.b + 0.08))


func _building_top_center(k: Vector2i) -> Vector2:
	var b = lots[k]
	var tw: float = float(b.tw); var td: float = float(b.td); var ins: float = float(b.ins)
	var up := Vector2(0, -float(b.h))
	return (_iso(k.x + ins, k.y + ins) + _iso(k.x + tw - ins, k.y + td - ins)) * 0.5 + up


# The animated overlay. Runs on the _fx canvas item (above the static scene, same camera transform)
# and draws ONLY things that change every tick, so the expensive static scene can stay retained.
func _draw_fx(c: CanvasItem) -> void:
	# NOTE: this overlay draws ABOVE the whole static scene, so it must only ever touch things that
	# genuinely sit on top (hover/selection on a building). Water is left flat in the static scene —
	# a shimmer overlay here would paint over any building that overlaps a water tile behind it.
	var hk: Vector2i = occ[_hover_tile] if occ.has(_hover_tile) else _hover_tile
	if lots.has(hk) and hk != selected:   # hover highlight (interactive, so it lives on the overlay)
		c.draw_polyline(_closed(_box_hull(hk)), Color(1, 1, 1, 0.85), 1.5)
	if lots.has(selected):             # pulsing selection marker above the building
		var pulse: float = 0.6 + 0.4 * sin(_time * 6.0)
		var mk := _building_top_center(selected) + Vector2(0, -14.0 - 4.0 * pulse)
		c.draw_colored_polygon(PackedVector2Array([mk, mk + Vector2(-5, -8), mk + Vector2(5, -8)]), Color(0.3, 1.0, 0.9, pulse))


class _FxLayer extends Node2D:
	var host
	func _draw() -> void:
		if host != null: host._draw_fx(self)


# ============================================================ UI
func _build_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	title_lbl = Label.new()
	title_lbl.position = Vector2(14, 10)
	title_lbl.add_theme_font_size_override("font_size", int(round(22 * Settings.text_scale)))
	title_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	title_lbl.text = "RIM — CITY  (%s)   ·  WASD/drag pan · wheel zoom · click a building · Esc" % _size_label()
	layer.add_child(title_lbl)
	hover_lbl = Label.new()
	hover_lbl.position = Vector2(14, 40)
	hover_lbl.add_theme_font_size_override("font_size", int(round(16 * Settings.text_scale)))
	hover_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	layer.add_child(hover_lbl)
	sel_panel = Panel.new()
	sel_panel.position = Vector2(14, 72)
	sel_panel.custom_minimum_size = Vector2(320, 100); sel_panel.size = Vector2(320, 100)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.92)
	sb.border_color = Color(0.2, 1.0, 0.9, 0.7); sb.set_border_width_all(1); sb.set_corner_radius_all(4)
	sel_panel.add_theme_stylebox_override("panel", sb)
	sel_panel.visible = false
	layer.add_child(sel_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10; vb.offset_top = 8; vb.offset_right = -10; vb.offset_bottom = -8
	vb.add_theme_constant_override("separation", 4)
	sel_panel.add_child(vb)
	sel_title = Label.new()
	sel_title.add_theme_font_size_override("font_size", int(round(18 * Settings.text_scale)))
	sel_title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	vb.add_child(sel_title)
	sel_body = Label.new()
	sel_body.add_theme_font_size_override("font_size", int(round(14 * Settings.text_scale)))
	sel_body.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	sel_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sel_body)


func _update_sel_panel() -> void:
	if sel_panel == null: return
	if not lots.has(selected):
		sel_panel.visible = false; return
	var b = lots[selected]
	var floors: int = max(1, int(round(float(b.h) / 11.0)))
	sel_panel.visible = true
	sel_title.text = str(KIND_NAME[str(b.kind)])
	sel_body.text = "District: %s  (%s)\n~%d floors   ·   %d×%d lots\nEsc / click ground to deselect" % [
		str(b.area), DTYPE_NAME[str(b.dtype)], floors, int(b.tw), int(b.td)]


func _size_label() -> String:
	var g := _grid_dims()
	return "%s · %d×%d" % [{"large": "Large", "medium": "Medium"}.get(Session.city_size, "Small"), g.x, g.y]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if lots.has(selected):
			selected = Vector2i(-999, -999); _update_sel_panel()
		else:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
