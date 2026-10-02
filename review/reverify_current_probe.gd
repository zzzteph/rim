extends SceneTree

var game
var findings := []
var draw_count := 0

func _initialize() -> void:
	call_deferred("run")

func report(label: String, observed: Dictionary) -> void:
	findings.append({"probe": label, "observed": observed})
	print(JSON.stringify(findings[-1]))

func fixture_node(id: int, kind: String, cell: Vector2i, parent := -1, path: Array = []) -> Dictionary:
	return {"id": id, "type": kind, "cell": cell, "size": 3 if kind == "hub" else 2,
		"parent": parent, "tunnel": "dns" if parent != -1 else "", "relay": false,
		"on": true, "cap_rate": 1.0, "boost_t": 0.0, "lane": 0, "path": path, "acc": 0.0}

func reset() -> void:
	game.nodes = {1: fixture_node(1, "hub", Vector2i(20, 20)), 2: fixture_node(2, "fence", Vector2i(24, 20), 1, [Vector2i(23, 20)])}
	game.hub_id = 1
	game.next_id = 3
	game.resources = {"compute": 1000.0, "data": 0.0, "credits": 0.0, "crypto": 0.0, "tools": 0.0, "research": 0.0}
	game.packets.clear()
	game._pl_cache.clear()
	game._edge.clear()
	game._connected = {1: true, 2: true}
	game._undo.clear()
	game._vis_sig.clear()
	game.sweep = {}
	game.trace = 0.0
	game.notoriety = 0.0
	game._blackout_t = 0.0
	game._sweep_charge = 0.0
	game.contracts.clear()
	game._contract_cd = 1000.0
	game.slow_factor = 1.0
	game.current_tool = ""
	game.pending_child = -1
	game.selected_id = -1
	game.selected_tunnel = -1
	game.camera.position = Vector2(800, 1000)
	game.camera.zoom = Vector2.ONE

func new_game():
	var instance = load("res://scenes/main.tscn").instantiate()
	root.add_child(instance)
	instance.set_process(false)
	instance.get_node("UILayer/UI").set_process(false)
	return instance

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("Session").seed = 12345
	game = new_game()
	await process_frame
	reset()
	game._spawn("credits", [2], 1, 0.5)
	game.nodes[2].boost_t = 17.0
	game.nodes[2].quarantine = 5.0
	game.notoriety = 65.0
	game._run_time = 250.0
	game._packets_delivered = 40
	game._max_trace = 91.0
	game._peak_cash_rate = 6.0
	game.sweep = {"route": [2], "step": 0, "warn": 3.0, "t": 0.5, "hop": 2.0}
	game._sweep_charge = 7.0
	game._blackout_t = 2.0
	game.contracts = [{"id": 1, "accepted": true, "done": false}]
	game._hist_cash = [10.0, 20.0]
	game.save_game()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(root.get_node("Session").SAVE_PATH))
	report("current_save_schema", {"version": saved.version, "packet_value_saved": saved.packets[0].has("value"),
		"boost_saved": saved.nodes["2"].has("boost_t"), "quarantine_saved": saved.nodes["2"].has("quarantine"),
		"notoriety_saved": saved.has("notoriety"), "contracts_saved": saved.has("contracts"),
		"run_time_saved": saved.has("_run_time"), "rng_state_saved": saved.has("rng_state")})
	root.get_node("Session").start_mode = "load"
	var continued = new_game()
	report("fresh_continue", {"loaded_packet_value": continued.packets[0].get("value", 1.0),
		"loaded_boost": continued.nodes[2].get("boost_t", 0.0), "loaded_quarantine": continued.nodes[2].get("quarantine", 0.0),
		"loaded_notoriety": continued.notoriety, "loaded_sweep_empty": continued.sweep.is_empty(),
		"loaded_blackout": continued._blackout_t, "loaded_contract_count": continued.contracts.size(),
		"loaded_run_time": continued._run_time, "loaded_delivered": continued._packets_delivered,
		"loaded_peak_trace": continued._max_trace, "loaded_history_count": continued._hist_cash.size()})
	continued.queue_free()
	game.load_game()
	report("in_place_threat_retained", {"notoriety": game.notoriety, "sweep_retained": not game.sweep.is_empty(),
		"blackout": game._blackout_t, "contracts_retained": game.contracts.size()})
	reset()
	game.rng.randf()
	game.rng.randf()
	var expected_state: int = game.rng.state
	game.save_game()
	var expected_next: float = game.rng.randf()
	game.load_game()
	report("rng_round_trip", {"original_state": str(expected_state), "loaded_state": str(game.rng.state),
		"expected_next": expected_next, "loaded_next": game.rng.randf()})
	reset()
	game.rates = {"credits": 20.0}
	game._rate_prev = game.resources.duplicate()
	game._rate_t = 0.8
	game._hist_cash = [50.0, 100.0]
	game._accum = 0.09
	game.selected_tunnel = 2
	game._panning = true
	game._hint_cell = Vector2i(24, 20)
	game._hint_pending = 2
	game._hint_tool = "dns"
	game._hint_route = {"cached_marker": true}
	game.save_game()
	game.load_game()
	report("load_transient_leaks", {"selected_tunnel": game.selected_tunnel, "panning": game._panning,
		"rate_sample_t": game._rate_t, "cached_rate": game.rates.credits,
		"old_history_count": game._hist_cash.size(), "simulation_remainder": game._accum,
		"cached_route_retained": game._hint_route.has("cached_marker")})
	reset()
	game.save_game()
	game._push_undo({"t": "tunnel", "child": 2, "cost": {"compute": 5.0}})
	game.load_game()
	var before: float = game.resources.compute
	game.undo_last()
	report("stale_undo", {"before": before, "after": game.resources.compute})
	reset()
	var f := FileAccess.open(root.get_node("Session").SAVE_PATH, FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	var valid: bool = game.load_game()
	report("empty_object_load", {"returned_success": valid, "node_count": game.nodes.size(), "hub_exists": game.nodes.has(game.hub_id)})
	reset()
	var path := []
	for y in range(10, 43): path.append(Vector2i(4, y))
	for x in range(5, 13): path.append(Vector2i(x, 42))
	for y in range(41, 9, -1): path.append(Vector2i(12, y))
	game.nodes = {1: fixture_node(1, "hub", Vector2i(12, 8)), 2: fixture_node(2, "nest", Vector2i(4, 8), 1, path)}
	game._pl_cache.clear()
	var viewport: Vector2 = game.get_viewport_rect().size / game.camera.zoom.x
	var view := Rect2(game.camera.position - viewport * 0.5, viewport)
	var a := Rect2(Vector2(game.nodes[2].cell) * game.TILE, Vector2(2, 2) * game.TILE)
	var b := Rect2(Vector2(game.nodes[1].cell) * game.TILE, Vector2(3, 3) * game.TILE)
	var onscreen_path_point := false
	for point in game._edge_pts(2, 1):
		if view.has_point(point): onscreen_path_point = true
	report("detour_culling_geometry", {"viewport": [viewport.x, viewport.y],
		"endpoint_box_passes_culling": view.grow(game.TILE * 4.0).intersects(a.merge(b)),
		"actual_path_point_inside_view": onscreen_path_point})
	reset()
	game.nodes = {1: fixture_node(1, "hub", Vector2i(68, 40))}
	game.selected_id = 1
	var footprint := Rect2(Vector2(game.nodes[1].cell) * game.TILE, Vector2(3, 3) * game.TILE)
	var center: Vector2 = game._center_world(1)
	var ring_point := center - Vector2(game.VISION.hub * game.TILE, 0)
	report("selected_ring_culling_geometry", {"footprint_passes_culling": view.grow(game.TILE * 2.0).intersects(footprint),
		"vision_ring_point_inside_view": view.has_point(ring_point)})
	reset()
	game.draw.connect(func(): draw_count += 1)
	game.paused = true
	game.queue_redraw()
	await process_frame
	await process_frame
	var initial_draws := draw_count
	game._process(0.0)
	await process_frame
	await process_frame
	var primed_draws := draw_count
	game.selected_id = 2
	game.toggle_selected()
	game._process(0.0)
	await process_frame
	await process_frame
	var action_draws := draw_count
	game.queue_redraw()
	await process_frame
	await process_frame
	report("paused_action_redraw", {"initial_draws": initial_draws, "primed_draws": primed_draws,
		"after_toggle_draws": action_draws, "after_force_redraw": draw_count,
		"disabled_state_changed": not game.nodes[2].on})
	var output := FileAccess.open("res://../reverify_current_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(findings, "\t"))
	output.close()
	quit()
