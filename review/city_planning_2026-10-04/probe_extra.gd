extends Node
func _ready():
	for sz in ["small","medium","large"]:
		var stats := {"size":sz,"no_park_blocks":[],"too_few_park_blocks":[],"too_few_shop_blocks":[],"shopping_without_mall":0,"shop_blocks_total":0,"split_downtown":[],"labels_over_water":0,"labels_over_road":0,"labels_outside_own_region":0,"total_labels":0,"two_tier_jumps":0,"non_house_buildings_at_edge":0}
		for sd in range(1,101):
			var c = load("res://scripts/city.gd").new()
			Session.city_size = sz
			c.seed = sd
			c.rng.seed = sd
			c._generate()
			var pk := 0
			var sh := 0
			var db := 0
			for b in c.probe_roles:
				var r = c.probe_roles[b]
				if r.type == "park": pk += 1
				if r.type == "com":
					sh += 1
					var has_mall := false
					for t in c.probe_blocks[b]:
						if c.lots.has(t) and c.lots[t].kind == "mall": has_mall = true
					if not has_mall: stats.shopping_without_mall += 1
				if r.type == "res":
					for d in [Vector2i(1,0),Vector2i(0,1)]:
						if c.probe_roles.has(b+d):
							var r2 = c.probe_roles[b+d]
							if r2.type == "res" and abs(r.tier-r2.tier)>1: stats.two_tier_jumps += 1
			if pk == 0: stats.no_park_blocks.append(sd)
			if pk < {"small":1,"medium":3,"large":5}[sz]: stats.too_few_park_blocks.append(sd)
			if sh < {"small":1,"medium":2,"large":3}[sz]: stats.too_few_shop_blocks.append(sd)
			stats.shop_blocks_total += sh
			for d in c.districts:
				if d.type == "bus": db += 1
				stats.total_labels += 1
				var t = Vector2i(floor(d.centroid_tile.x),floor(d.centroid_tile.y))
				if c.water.has(t): stats.labels_over_water += 1
				if c._is_street(t.x,t.y): stats.labels_over_road += 1
				var block = Vector2i(t.x/c.P,t.y/c.P)
				if not c.probe_roles.has(block) or int(c.probe_roles[block].did) != int(d.id): stats.labels_outside_own_region += 1
			if db > 1: stats.split_downtown.append(sd)
			c.free()
		print("EXTRA " + JSON.stringify(stats))
	get_tree().quit()
