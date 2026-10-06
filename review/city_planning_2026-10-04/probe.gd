extends Node
const DIRS := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
func _ready():
	var results := []
	for sz in ["small","medium","large"]:
		var summary := {"size":sz,"seeds":100,"missing_mall":[],"missing_park":[],"missing_downtown":[],"zero_houses":[],"fewer_malls_than_target":[],"fewer_park_districts_than_target":[],"kinds":{},"building_dids":{},"roads":0,"tiles":0,"water_road":0,"buildings":0,"deco_street":0,"deco_water":0,"prom":0,"prom_under_buildings":0,"res_districts":0,"deco_street_seeds":[],"deco_water_seeds":[],"park_tiles":0,"mixed_district_kind_buildings":0,"district_count":0,"no_park_tiles":[],"res_nonzero":0}
		for sd in range(1,101):
			var c = load("res://scripts/city.gd").new()
			Session.city_size = sz
			c.seed = sd
			c.rng.seed = sd
			c._generate()
			var kinds := {}
			var pk_count := 0
			var down_count := 0
			for d in c.districts:
				summary.district_count += 1
				if d.type == "park": pk_count += 1
				if d.type == "bus": down_count += 1
				if d.type == "res": summary.res_districts += 1
			for k in c.lots:
				var b = c.lots[k]
				kinds[b.kind] = int(kinds.get(b.kind,0)) + 1
				summary.kinds[b.kind] = int(summary.kinds.get(b.kind,0)) + 1
				var did = str(b.did)
				summary.building_dids[did] = int(summary.building_dids.get(did,0)) + 1
				summary.buildings += 1
				if c.districts[b.did].type != b.dtype: summary.mixed_district_kind_buildings += 1
			if int(kinds.get("mall",0)) == 0: summary.missing_mall.append(sd)
			if int(kinds.get("mall",0)) < {"small":1,"medium":2,"large":3}[sz]: summary.fewer_malls_than_target.append(sd)
			if pk_count == 0: summary.missing_park.append(sd)
			if pk_count < {"small":1,"medium":3,"large":5}[sz]: summary.fewer_park_districts_than_target.append(sd)
			if down_count == 0: summary.missing_downtown.append(sd)
			if int(kinds.get("fh",0)) == 0: summary.zero_houses.append(sd)
			var roads := 0
			for y in c._grid.y:
				for x in c._grid.x:
					var t := Vector2i(x,y)
					if c._is_street(x,y):
						roads += 1
						if c.water.has(t): summary.water_road += 1
			summary.roads += roads
			summary.tiles += c._grid.x * c._grid.y
			var ds := 0
			var dw := 0
			var park_tiles := 0
			for t in c.deco:
				if c.deco[t] == "park": park_tiles += 1
				if c._is_street(t.x,t.y): ds += 1
				if c.water.has(t): dw += 1
				if c.deco[t] == "prom":
					summary.prom += 1
					if c.occ.has(t): summary.prom_under_buildings += 1
			if park_tiles == 0: summary.no_park_tiles.append(sd)
			summary.park_tiles += park_tiles
			summary.deco_street += ds
			summary.deco_water += dw
			if ds > 0: summary.deco_street_seeds.append(sd)
			if dw > 0: summary.deco_water_seeds.append(sd)
			c.free()
		results.append(summary)
	print("PROBE_RESULT " + JSON.stringify(results))
	get_tree().quit()
