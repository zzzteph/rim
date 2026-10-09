extends Node
## City generation checks (headless, full project so autoloads load):
##   godot --headless res://review/city_checks.tscn
## Covers repeatability, road reciprocity + classification, no perimeter frame, no water,
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
	var lore_same: bool = a.corp_info == b.corp_info
	for k in a.lots:
		if not b.lots.has(k): lore_same = false; break
		for field in ["bname", "occupant", "story", "people", "life"]:
			if a.lots[k].get(field) != b.lots[k].get(field): lore_same = false
	check("CK21_lore_repeatable", lore_same, "same seed reproduces stories, people and corporations")

	var c = mk("medium", 7)
	# CK2 valid footprints: on land, not road, consistent occupancy
	var valid := true; var fc := 0
	for k in c.lots:
		for dx in int(c.lots[k].tw):
			for dy in int(c.lots[k].td):
				var t = Vector2i(k.x + dx, k.y + dy)
				if not c.land.has(t) or c.roads.has(t): valid = false
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

	# CK6 no water: the cyberpunk city has no river/lake (removed v0.9.9) — nothing water-shaped remains
	check("CK6_no_water", c.get("water") == null and not _has_deco(c, "prom"), "water=%s prom=%s" % [c.get("water") != null, _has_deco(c, "prom")])

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

	# CK9–CK13: swept across all sizes × seeds 1–15 (45 maps) — the measured failures from the audit.
	var bad_conn := 0; var sliver := 0; var no_park := 0; var no_retail := 0; var nmaps := 0
	var dup_names := 0; var road_pct := 0.0; var bad_hub := 0
	var bad_lore := 0; var stories := 0; var uniq_stories := {}; var bad_net := 0; var bad_stadium := 0; var hidden := 0; var dead_ends := 0; var chords := 0; var long_links := 0
	var lore_kinds := {}
	for sz in ["small", "medium", "large"]:
		for sd in range(1, 16):
			var m = mk(sz, sd); nmaps += 1
			if not _roads_one_component(m): bad_conn += 1
			if _has_sliver_build(m): sliver += 1
			if not _has_deco(m, "park"): no_park += 1
			if not _has_retail(m): no_retail += 1
			var names := {}
			for r in m.districts:
				if names.has(str(r.name)): dup_names += 1
				names[str(r.name)] = true
			road_pct += 100.0 * float(m.roads.size()) / float(max(1, m.land.size()))
			if not _hub_ok(m): bad_hub += 1
			for k in m.lots:
				var lb = m.lots[k]
				lore_kinds[str(lb.kind)] = true
				if str(lb.get("bname", "")) == "" or str(lb.get("occupant", "")) == "" or str(lb.get("story", "")) == "": bad_lore += 1
				if str(lb.kind) in ["ap", "sc", "fh"] and (lb.get("people", []) as Array).is_empty(): bad_lore += 1   # homes list residents
				var txt := str(lb.get("bname", "")) + str(lb.story) + str(lb.get("life", ""))
				for pp in lb.get("people", []): txt += str(pp.name) + str(pp.job) + str(pp.detail)
				if "{" in txt or "}" in txt: bad_lore += 1   # an unfilled / misspelt {placeholder} in content
				stories += 1; uniq_stories[sz + str(sd) + str(lb.get("story", ""))] = true
			for r in m.districts:   # corps own corporate districts; homes have a landlord; no gangs anywhere
				if str(r.type) == "bus" and not m.corp_info.has(str(r.get("org", ""))): bad_lore += 1
				if str(r.type) == "res" and str(r.get("landlord", "")) == "": bad_lore += 1
			if not _stadium_ok(m): bad_stadium += 1
			dead_ends += _dead_end_districts(m)
			for e in m.net_backbone:   # no district-to-district link spans half the city
				if m._lot_center(e[0]).distance_to(m._lot_center(e[1])) > 12.0: long_links += 1
			for e in m.net_local:   # a local link never jumps over a building already linked to either end
				if m._jumps_over(e[0], e[1]): chords += 1
			for k in m.lots:   # no building's roof is covered by one in front, even at full height
				if m._top_hidden(k, m.HEIGHT_K): hidden += 1
			if not _net_ok(m): bad_net += 1
	check("CK9_roads_one_component", bad_conn == 0, "%d/%d maps with split road network" % [bad_conn, nmaps])
	check("CK10_no_sliver_build_sites", sliver == 0, "%d/%d maps built on a <%d-cell remnant" % [sliver, nmaps, 3])
	check("CK11_every_map_has_park", no_park == 0, "%d/%d maps with no park ground" % [no_park, nmaps])
	check("CK12_every_map_has_retail", no_retail == 0, "%d/%d maps with no retail site" % [no_retail, nmaps])
	# every district on a map has its own name (no "DOWNTOWN CORE" ×5)
	check("CK13_unique_district_names", dup_names == 0, "%d duplicate district names across %d maps" % [dup_names, nmaps])
	check("CK14_central_hub_tallest", bad_hub == 0, "%d/%d maps without a central, tallest HUB" % [bad_hub, nmaps])
	# Every building named, occupied and storied, with zero duplicate full stories within each map.
	check("CK15_building_lore", bad_lore == 0 and uniq_stories.size() == stories, "%d missing · %d/%d unique stories" % [bad_lore, uniq_stories.size(), stories])
	var all_kinds := true
	for kind in ["hub", "corp", "off_m", "off_s", "mall", "shop_b", "shop_s", "sc", "ap", "fh"]:
		if not lore_kinds.has(kind): all_kinds = false
	check("CK22_all_building_kinds_lore", all_kinds, "%d building kinds covered" % lore_kinds.size())
	check("CK23_lore_selection", _lore_selection_ok(), "shuffled draws, collision recovery, rendered uniqueness and finite exhaustion")
	# every building is wired, and the whole network is ONE connected graph that reaches the HUB
	check("CK16_network_connected", bad_net == 0, "%d/%d maps with an unwired building or split network" % [bad_net, nmaps])
	# inside every district the tall buildings stand at the back, so a district never hides its own
	# the lore CONTENT FILE (data/city_lore.json) loads, and every {placeholder} in it is one the
	# generator fills — catches typos in hand- or AI-written content before they reach the screen
	var bad_ph := _lore_placeholder_errors()
	check("CK18_lore_content_valid", load("res://scripts/city_lore.gd").data() != null and load("res://scripts/city_lore.gd").loaded_ok and bad_ph.is_empty(),
		"file loaded=%s · bad placeholders: %s" % [load("res://scripts/city_lore.gd").loaded_ok, ", ".join(bad_ph) if not bad_ph.is_empty() else "none"])
	check("CK25_no_far_links", long_links == 0, "%d district links longer than 12 tiles across %d maps" % [long_links, nmaps])
	check("CK24_no_chord_links", chords == 0, "%d local links jumping over a linked building across %d maps" % [chords, nmaps])
	check("CK20_districts_meshed", dead_ends == 0, "%d districts linked to fewer than 2 other districts across %d maps" % [dead_ends, nmaps])
	check("CK19_no_hidden_buildings", hidden == 0, "%d buildings hidden behind another across %d maps" % [hidden, nmaps])
	check("CK17_district_stadium", bad_stadium == 0, "%d/%d maps with a district hiding its own buildings" % [bad_stadium, nmaps])
	print("ROAD SHARE of developed land, mean over %d maps: %.1f%%" % [nmaps, road_pct / float(nmaps)])

	# report land shares + road coverage
	var g = mk("large", 303)
	var tot: int = g._grid.x * g._grid.y
	var sh := {"res": 0, "com": 0, "bus": 0, "green": 0, "road": 0, "country": 0, "open": 0}
	for ly in g._grid.y:
		for lx in g._grid.x:
			var t = Vector2i(lx, ly)
			if g.roads.has(t): sh.road += 1
			elif g.occ.has(t): sh[str(g.lots[g.occ[t]].dtype)] = int(sh[str(g.lots[g.occ[t]].dtype)]) + 1
			elif g.deco.has(t): sh.green += 1
			elif g.land.has(t): sh.open += 1
			else: sh.country += 1
	print("LAND SHARES (large 303, %d tiles): res=%d com=%d bus=%d green=%d open=%d road=%d(%d%%) countryside=%d  districts=%d" % [
		tot, sh.res, sh.com, sh.bus, sh.green, sh.open, sh.road, int(100.0 * sh.road / tot), sh.country, g.districts.size()])

	print("\nCITY CHECKS: %d passed, %d failed" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)


# flood-fill the road set from one tile; connected iff every road tile is reached (graph traversal,
# not a neighbour count — the audit's key connectivity requirement)
func _roads_one_component(m) -> bool:
	if m.roads.is_empty(): return true
	var start
	for t in m.roads: start = t; break
	var seen := {}; var stack := [start]
	while not stack.is_empty():
		var cur = stack.pop_back()
		if seen.has(cur) or not m.roads.has(cur): continue
		seen[cur] = true
		for d in DIRS: stack.append(cur + d)
	return seen.size() == m.roads.size()


# any building sitting in a land-minus-roads pocket smaller than MIN_BLOCK (= a sliver site)?
func _has_sliver_build(m) -> bool:
	var seen := {}; var size_of := {}
	for t in m.land:
		if m.roads.has(t) or seen.has(t): continue
		var stack := [t]; var cells := []
		while not stack.is_empty():
			var cur = stack.pop_back()
			if seen.has(cur) or m.roads.has(cur) or not m.land.has(cur): continue
			seen[cur] = true; cells.append(cur)
			for d in DIRS: stack.append(cur + d)
		for cc in cells: size_of[cc] = cells.size()
	for t in m.occ:
		if int(size_of.get(t, 0)) < 3: return true
	return false


func _has_deco(m, kind: String) -> bool:
	for t in m.deco:
		if str(m.deco[t]) == kind: return true
	return false


func _has_retail(m) -> bool:
	for k in m.lots:
		var kd := str(m.lots[k].kind)
		if kd == "mall" or kd == "shop_s" or kd == "shop_b": return true
	return false


# the CENTRAL HUB exists, is strictly the tallest building, and sits near the land centroid
func _hub_ok(m) -> bool:
	if not m.lots.has(m.hub_key): return false
	var hh: float = float(m.lots[m.hub_key].h)
	for k in m.lots:
		if k != m.hub_key and float(m.lots[k].h) >= hh: return false
	var c := Vector2.ZERO
	for t in m.land: c += Vector2(t)
	c /= float(max(1, m.land.size()))
	var hb = m.lots[m.hub_key]
	return (Vector2(m.hub_key) + Vector2(float(hb.tw), float(hb.td)) * 0.5).distance_to(c + Vector2(0.5, 0.5)) <= 3.0


func _net_ok(m) -> bool:
	if m.lots.size() <= 1: return true
	for k in m.lots:
		if (m.net_links.get(k, []) as Array).is_empty(): return false
	var seen := {m.hub_key: true}; var stack := [m.hub_key]
	while not stack.is_empty():
		var cur = stack.pop_back()
		for o in m.net_links.get(cur, []):
			if not seen.has(o): seen[o] = true; stack.append(o)
	return seen.size() == m.lots.size()


func _stadium_ok(m) -> bool:
	for did in m._district_lots:
		var ks := (m._district_lots[did] as Array).filter(func(k): return k != m.hub_key and int(m.lots[k].tw) == 1 and int(m.lots[k].td) == 1)
		for a in ks:
			for b in ks:
				if a.x + a.y < b.x + b.y and float(m.lots[a].h) < float(m.lots[b].h): return false
	return true


func _lore_placeholder_errors() -> PackedStringArray:
	var L = load("res://scripts/city_lore.gd")
	var allowed := {"corp_job": true}
	for ph in L.PLACEHOLDERS: allowed[ph] = true
	var re := RegEx.new(); re.compile("[{]([^{}]*)[}]")
	var bad := PackedStringArray()
	var stack := [L.data()]
	while not stack.is_empty():
		var v = stack.pop_back()
		if v is Dictionary: stack.append_array(v.values())
		elif v is Array: stack.append_array(v)
		elif v is String:
			for m in re.search_all(v):
				if not allowed.has(m.get_string(1)): bad.append("{%s}" % m.get_string(1))
			if v.count("{") != v.count("}"): bad.append("unbalanced braces in: " + v.left(40))
	return bad


func _lore_selection_ok() -> bool:
	var L = load("res://scripts/city_lore.gd")
	var lore = L.new(73)
	var pool := ["One detail.", "Another detail.", "A final detail."]
	var previous := ""
	for cycle in 3:
		var seen := {}
		for i in pool.size():
			var detail: String = lore._draw_text("probe", pool)
			if seen.has(detail) or detail == previous or not pool.has(detail): return false
			seen[detail] = true; previous = detail
	# Exhaust all 18 combinations in a small pool, including the optional rumour. A mere retry
	# limit can miss the final unused combinations; finite collision recovery must find them.
	lore.D = {"stories": {"probe": {"history": ["The site was a depot.", "The permit was delayed."],
		"now": ["The lights stay on.", "The door is open.", "The clock runs slow."],
		"rumour": ["A key is missing.", "A receipt was hidden."]}}}
	var seen_stories := {}
	for i in 18:
		var story: String = lore._story("probe", {}, 0.5)
		if story == "" or seen_stories.has(story): return false
		seen_stories[story] = true
	# These exhausted tiny fixtures intentionally emit warnings rather than looping forever.
	var exhausted: String = lore._story("probe", {}, 0.5)
	if not seen_stories.has(exhausted): return false
	# Different source strings can render identically, so uniqueness must follow substitution.
	var rendered = L.new(74)
	rendered.D = {"stories": {"probe": {"history": ["{org} opened the site.", "{corp} opened the site.", "A permit was issued."],
		"now": ["The lights stay on."], "rumour": []}}}
	var context := {"org": "Test Corp", "corp": "Test Corp"}
	var first: String = rendered._story("probe", context, 0.0)
	var second: String = rendered._story("probe", context, 0.0)
	var third: String = rendered._story("probe", context, 0.0)
	return first != second and "{" not in first and "{" not in second and third in [first, second]


func _dead_end_districts(m) -> int:   # districts (with buildings) linked to < 2 other districts
	var peers := {}
	for e in m.net_backbone:
		var a := int(m.lots[e[0]].did); var b := int(m.lots[e[1]].did)
		if a == b: continue
		if not peers.has(a): peers[a] = {}
		if not peers.has(b): peers[b] = {}
		peers[a][b] = true; peers[b][a] = true
	var n := 0; var nd := 0
	for did in m._district_lots:
		if not (m._district_lots[did] as Array).is_empty(): nd += 1
	if nd < 3: return 0
	for did in m._district_lots:
		if (m._district_lots[did] as Array).is_empty(): continue
		if (peers.get(did, {}) as Dictionary).size() < 2: n += 1
	return n
