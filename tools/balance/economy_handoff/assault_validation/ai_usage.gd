extends SceneTree
## AI-only Small matches (3 Normal AIs, seat vacated): how often the Normal AI orders assaults, and how matches end.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var rows := []
	for seed in [7, 19, 43]:
		var g = load("res://scripts/botnet_proto.gd").new()
		g.theme = load("res://assets/ui_theme.tres")
		g._opt_size = Vector2i(6, 4); g._opt_enemies = 3; g._opt_seed = seed
		root.add_child(g); g.set_process(false); g._open_menu(false)
		g.botnets = g.ais.duplicate(); g._mp_on = true
		for i in g.hosts.size():
			if int(g.hosts[i].owner) == g.PLAYER:
				g.hosts[i].owner = g.NEUTRAL; g.hosts[i].rig = false; g.hosts[i].sec = 9.0; g.hosts[i].bots = 9.0; g._set_builds(i, ["bot"])
		g._refresh_sight(); g.panel_box = null
		var orders := 0; var seen := {}; var exposed_lost := 0; var counter_scans := 0
		while g._t < 900.0 and str(g._end_cause) == "":
			g._sim_step(g.SIM_DT)
			for i in g.hosts.size():
				var o: Dictionary = g.hosts[i].get("assault", {})
				if not o.is_empty():
					var k := "%d@%.3f" % [i, float(o.at)]
					if not seen.has(k): seen[k] = int(g.hosts[i].owner); orders += 1
		var alive := 0
		for f in g.botnets:
			if not g._eliminated.has(f): alive += 1
		rows.append({"seed": seed, "end_t": snappedf(g._t, 0.1), "cause": str(g._end_cause), "assault_orders": orders, "alive": alive})
		g.free()
	print("AIUSE " + JSON.stringify(rows))
	quit(0)
