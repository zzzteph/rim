extends Node
const DIRS := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
func _ready():
	var output := []
	for sz in ["small","medium","large"]:
		var stats := {"size":sz,"seeds":100,"missing_mall":[],"below_mall_target":[],"missing_park_tiles":[],"missing_park_districts":[],"missing_downtown":[],"missing_houses":[],"kinds":{},"roads":0,"tiles":0,"land":0,"roads_outside_land_dry":0,"water_road":0,"local_water_road":0,"roads_on_land":0,"degree":{"0":0,"1":0,"2":0,"3":0,"4":0},"road_components":{},"unserved_blocks":0,"unserved_block_seeds":[],"unserved_buildings":0,"no_direct_road_buildings":0,"total_blocks":0,"blocks_size1":0,"blocks_size2":0,"block_size_total":0,"buildings":0,"dids":{},"invalid_did":0,"prom":0,"prom_under_buildings":0,"deco_road":0,"deco_water":0,"deco_outside_land":0,"cases":[]}
		for sd in range(1,101):
			var c = load("res://scripts/city.gd").new()
			Session.city_size = sz
			c.seed = sd
			c.rng.seed = sd
			c._generate()
			var kinds := {}
			var seen := {}
			var components := 0
			for t in c.roads:
				if seen.has(t): continue
				components += 1
				var stack := [t]
				while not stack.is_empty():
					var cur = stack.pop_back()
					if seen.has(cur): continue
					seen[cur] = true
					for d in DIRS:
						if c.roads.has(cur+d) and not seen.has(cur+d): stack.append(cur+d)
			var compkey := str(components)
			stats.road_components[compkey] = int(stats.road_components.get(compkey,0)) + 1
			for t in c.roads:
				var degree := str(c._road_dirs(t).size())
				stats.degree[degree] += 1
				if c.land.has(t): stats.roads_on_land += 1
				elif c.water.has(t):
					stats.water_road += 1
					if c.road_class[t] == "loc": stats.local_water_road += 1
				else: stats.roads_outside_land_dry += 1
			stats.roads += c.roads.size()
			stats.land += c.land.size()
			stats.tiles += c._grid.x*c._grid.y
			var unserved_this := 0
			for b in c._carve_blocks(c._grid):
				stats.total_blocks += 1
				stats.block_size_total += b.tiles.size()
				if b.tiles.size() == 1: stats.blocks_size1 += 1
				if b.tiles.size() == 2: stats.blocks_size2 += 1
				var adjacent := false
				var buildings := {}
				for t in b.tiles:
					for d in DIRS:
						if c.roads.has(t+d): adjacent = true
					if c.occ.has(t): buildings[c.occ[t]] = true
				if not adjacent:
					stats.unserved_blocks += 1
					unserved_this += 1
					stats.unserved_buildings += buildings.size()
			if unserved_this > 0: stats.unserved_block_seeds.append(sd)
			var pks := 0
			var park_districts := 0
			var downtown := 0
			for d in c.districts:
				if d.type == "park": park_districts += 1
			for t in c.deco:
				if c.deco[t] == "park": pks += 1
				if c.deco[t] == "prom":
					stats.prom += 1
					if c.occ.has(t): stats.prom_under_buildings += 1
				if c.roads.has(t): stats.deco_road += 1
				if c.water.has(t): stats.deco_water += 1
				if not c.land.has(t): stats.deco_outside_land += 1
			for k in c.lots:
				var b = c.lots[k]
				stats.buildings += 1
				if b.dtype == "bus": downtown += 1
				kinds[b.kind] = int(kinds.get(b.kind,0)) + 1
				stats.kinds[b.kind] = int(stats.kinds.get(b.kind,0)) + 1
				stats.dids[str(b.did)] = int(stats.dids.get(str(b.did),0)) + 1
				if b.did < 0 or b.did >= c.districts.size(): stats.invalid_did += 1
				var adjacent := false
				for dx in int(b.tw):
					for dy in int(b.td):
						var t = k+Vector2i(dx,dy)
						for d in DIRS:
							if c.roads.has(t+d): adjacent = true
				if not adjacent: stats.no_direct_road_buildings += 1
			if int(kinds.get("mall",0)) == 0: stats.missing_mall.append(sd)
			if int(kinds.get("mall",0)) < {"small":1,"medium":2,"large":3}[sz]: stats.below_mall_target.append(sd)
			if int(kinds.get("fh",0)) == 0: stats.missing_houses.append(sd)
			if downtown == 0: stats.missing_downtown.append(sd)
			if park_districts == 0: stats.missing_park_districts.append(sd)
			if pks == 0: stats.missing_park_tiles.append(sd)
			if sd in [7,42,37,58,81]:
				stats.cases.append({"seed":sd,"kinds":kinds,"roads":c.roads.size(),"land":c.land.size(),"park_tiles":pks,"park_districts":park_districts,"road_components":components,"unserved_blocks":unserved_this})
			c.free()
		output.append(stats)
	print("PROBE_RESULT " + JSON.stringify(output))
	get_tree().quit()
