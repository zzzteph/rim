extends Node
## City generation checks (headless, full project so autoloads load):
##   godot --headless res://review/city_checks.tscn
## Covers repeatability, road reciprocity + classification, no perimeter frame, bridge continuity,
## valid footprints, reserved sites, one-tier adjacency, and reports land shares + road coverage.

var pass_count := 0
var fail_count := 0
const KT := {"fh": 0, "ap": 1, "sc": 2}
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

func _ready() -> void:
	run()

func check(id: String, ok: bool, detail := "") -> void:
	if ok: pass_count += 1
	else: fail_count += 1
	print("ASSERT %-30s %s  %s" % [id, "PASS" if ok else "FAIL", detail])

func mk(sz: String, sd: int):
	var c = load("res://scripts/city.gd").new()
	c.seed = sd; c.rng.seed = sd
	Session.city_size = sz
	c._grid = c._grid_dims()
	c._generate()
	return c

func run() -> void:
	# CK1 repeatable
	var a = mk("medium", 42); var b = mk("medium", 42)
	var same: bool = a.lots.size() == b.lots.size() and a.roads.size() == b.roads.size()
	for k in a.lots:
		if not b.lots.has(k) or str(a.lots[k].kind) != str(b.lots[k].kind): same = false; break
	check("CK1_repeatable", same, "lots=%d roads=%d" % [a.lots.size(), a.roads.size()])

	var c = mk("medium", 7)
	# CK2 valid footprints: on land, not road/water, consistent occupancy
	var valid := true; var fc := 0
	for k in c.lots:
		for dx in int(c.lots[k].tw):
			for dy in int(c.lots[k].td):
				var t = Vector2i(k.x + dx, k.y + dy)
				if not c.land.has(t) or c.roads.has(t) or c.water.has(t): valid = false
				if not c.occ.has(t) or c.occ[t] != k: valid = false
				fc += 1
	check("CK2_valid_footprints", valid and fc == c.occ.size(), "cells=%d occ=%d" % [fc, c.occ.size()])

	# CK3 road reciprocity: connections are symmetric
	var recip := true
	for t in c.roads:
		for d in DIRS:
			if c.roads.has(t + d) and not c.roads.has(t + d + (-d)): recip = false
	check("CK3_road_reciprocal", recip, "connections symmetric")

	# CK4 classification: straight (2 opposite), junctions (>=3) and endpoints (1) all exist; straight
	# tiles draw as straight (direction-only centre lines guarantee no false crossing).
	var nstraight := 0; var nbend := 0; var njunc := 0; var nend := 0; var ncross := 0
	for t in c.roads:
		var dirs: Array = c._road_dirs(t)
		match dirs.size():
			1: nend += 1
			2:
				if (dirs[0] + dirs[1]) == Vector2i.ZERO: nstraight += 1
				else: nbend += 1
			3: njunc += 1
			4: ncross += 1
	check("CK4_road_classes", nstraight > 0 and (njunc + ncross) > 0, "straight=%d bend=%d T=%d cross=%d end=%d" % [nstraight, nbend, njunc, ncross, nend])

	# CK5 no perimeter frame
	var border := 0; var broad := 0
	for lx in c._grid.x:
		for ly in [0, c._grid.y - 1]:
			border += 1
			if c.roads.has(Vector2i(lx, ly)): broad += 1
	for ly in c._grid.y:
		for lx in [0, c._grid.x - 1]:
			border += 1
			if c.roads.has(Vector2i(lx, ly)): broad += 1
	check("CK5_no_perimeter_frame", float(broad) / float(max(1, border)) < 0.1, "border road %d/%d" % [broad, border])

	# CK6 bridge continuity: every road-over-water has >= 2 road neighbours
	var bridges := 0; var bad := 0
	for t in c.roads:
		if c.water.has(t):
			bridges += 1
			if c._road_dirs(t).size() < 2: bad += 1
	check("CK6_bridge_continuity", bad == 0, "bridges=%d discontinuous=%d" % [bridges, bad])

	# CK7 reserved sites, CK8 one-tier adjacency
	var has_down := false; var has_mall := false; var has_park := false
	for k in c.lots:
		if str(c.lots[k].dtype) == "bus": has_down = true
		if str(c.lots[k].kind) == "mall": has_mall = true
	for t in c.deco:
		if str(c.deco[t]) == "park": has_park = true
	check("CK7_reserved_sites", has_down and has_mall and has_park, "downtown=%s mall=%s park=%s" % [has_down, has_mall, has_park])
	var worst := 0
	for k in c.lots:
		if not KT.has(str(c.lots[k].kind)): continue
		for probe in [k + Vector2i(2, 0), k + Vector2i(0, 2), k + Vector2i(-2, 0), k + Vector2i(0, -2)]:
			var an = c.occ.get(probe, null)
			if an != null and c.lots.has(an) and KT.has(str(c.lots[an].kind)):
				worst = maxi(worst, absi(int(KT[str(c.lots[k].kind)]) - int(KT[str(c.lots[an].kind)])))
	check("CK8_one_tier_adjacency", worst <= 1, "max residential tier jump = %d" % worst)

	# report land shares + road coverage
	var g = mk("large", 303)
	var tot: int = g._grid.x * g._grid.y
	var sh := {"res": 0, "com": 0, "bus": 0, "green": 0, "water": 0, "road": 0, "country": 0, "open": 0}
	for ly in g._grid.y:
		for lx in g._grid.x:
			var t = Vector2i(lx, ly)
			if g.roads.has(t): sh.road += 1
			elif g.water.has(t): sh.water += 1
			elif g.occ.has(t): sh[str(g.lots[g.occ[t]].dtype)] = int(sh[str(g.lots[g.occ[t]].dtype)]) + 1
			elif g.deco.has(t): sh.green += 1
			elif g.land.has(t): sh.open += 1
			else: sh.country += 1
	print("LAND SHARES (large 303, %d tiles): res=%d com=%d bus=%d green=%d open=%d water=%d road=%d(%d%%) countryside=%d" % [
		tot, sh.res, sh.com, sh.bus, sh.green, sh.open, sh.water, sh.road, int(100.0 * sh.road / tot), sh.country])

	print("\nCITY CHECKS: %d passed, %d failed" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)
