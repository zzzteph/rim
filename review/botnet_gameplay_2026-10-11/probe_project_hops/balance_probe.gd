extends SceneTree

var rates := [1.0, 1.5, 2.0, 2.5]
var horizon := 60.0
var fps := 60.0
var results := []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rates="):
			rates = []
			for value in arg.trim_prefix("--rates=").split(","): rates.append(float(value))
		if arg.begins_with("--seconds="): horizon = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--fps="): fps = float(arg.trim_prefix("--fps="))
	assert(horizon > 0 and fps >= 30)
	_run.call_deferred()

func scenario(rate: float, contributors: int, initial_stock: float, link_time: float) -> Dictionary:
	var source := FileAccess.get_file_as_string("res://scripts/botnet_proto.gd")
	source = source.replace("const SEND_RATE := 1.0", "const SEND_RATE := " + str(rate))
	source = source.replace("const LINK_TIME := 1.0", "const LINK_TIME := " + str(link_time))
	var program := GDScript.new(); program.source_code = source
	assert(program.reload() == OK)
	var game = program.new(); root.add_child(game); game.set_process(false)
	game._enemy_timer = horizon + 100.0
	game.hosts[0].bots = initial_stock; game.hosts[0].assign = 1
	game.hosts[5].bots = initial_stock
	if contributors == 2: game.hosts[5].assign = 1
	var captured_at := -1.0
	var minimum_source: float = initial_stock
	var source_at_10 := -1.0
	for tick in int(horizon * fps):
		game._process(1.0 / fps)
		if captured_at < 0:
			minimum_source = minf(minimum_source, float(game.hosts[0].bots))
		if tick == int(10 * fps)-1: source_at_10 = float(game.hosts[0].bots)
		for h in game.hosts: assert(h.bots >= -0.000001 and h.bots <= game.NODE_CAP+0.000001)
		if game.hosts[1].owned and captured_at < 0:
			captured_at = (tick+1)/fps
			# Completed fixture: stop future supply; already launched packets continue.
			game.hosts[0].assign = -1; game.hosts[5].assign = -1
	var result := {"send_rate":rate,"link_time":link_time,"contributors":contributors,
		"initial_source_stock":initial_stock,"initial_target_stock":20.0,"captured_at":captured_at,
		"source_min_until_capture":minimum_source,"source_at_10s":source_at_10,
		"target_final_bots":game.hosts[1].bots,"target_final_owned":game.hosts[1].owned}
	game.free()
	return result

func _run() -> void:
	for rate in rates:
		assert(rate > 0 and rate < fps)
		for contributors in [1,2]:
			for stock in [0.0,30.0]:
				for link_time in [0.5,1.0]:
					var result := scenario(rate,contributors,stock,link_time)
					results.append(result)
					print(JSON.stringify(result))
	var output := FileAccess.open("res://balance_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"model":"Actual frozen runtime, in-memory rate/link-time overrides, deterministic target fixture",
		"horizon":horizon,"fps":fps,"rates":rates,"enemy_ai":"disabled to isolate production/arrival thresholds",
		"player_policy":"one or two assigned sources attack node 1; stop future supply on first capture",
		"limitations":"Runtime has known timing/list-order defects; high-frequency single-faction arrival fixture avoids contested arrival order. Capture times are diagnostic approximations, not accepted tuning targets.",
		"cases":results},"\t"))
	output.close(); print("BALANCE_PROBE_COMPLETE ",results.size()," scenarios"); quit()
