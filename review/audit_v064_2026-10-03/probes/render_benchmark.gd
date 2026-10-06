extends SceneTree

const OUT := "C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03"
var game
var results := []
var draw_count := 0
var city_draw_count := 0
var graph_draw_count := 0

func _initialize() -> void:
	_run.call_deferred()

func settle(frames := 12) -> void:
	for i in frames:
		await process_frame

func screen(name: String) -> void:
	await settle()
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + "/screenshots/" + name + ".png")

func record(name: String, details: Dictionary) -> void:
	details["name"] = name
	results.append(details)
	print(JSON.stringify(details))
	var f := FileAccess.open(OUT + "/render_results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"renderer": "OpenGL Compatibility, RTX3060 Laptop; 1280x720; VSync disabled", "method": "Fixed camera; main._process disabled to exclude external mouse/edge-pan interference; UI runs normally; world clock/redraw and 10Hz ticks driven by harness. Synthetic fixtures, not legal economic runs. Frame intervals are local renderer/UI observations, not shipping-build FPS.", "tests": results}, "\t"))
	f.close()

func run_frames(name: String, details: Dictionary, count := 80) -> void:
	game.queue_redraw()
	await settle(25)
	var start_camera: Vector2 = game.camera.position
	var start_mouse: Vector2 = root.get_mouse_position()
	draw_count = 0
	graph_draw_count = 0
	var samples := []
	var calls := []
	var cpu := []
	for i in count:
		if not game.paused:
			game._time += 1.0 / 60.0
			if i % 6 == 0:
				game._sim_tick(0.1)
			if not root.get_node("Settings").reduced_motion or not game.packets.is_empty():
				game.queue_redraw()
		var start := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	samples.sort()
	cpu.sort()
	calls.sort()
	details.merge({"frames": count, "frame_p50_ms": samples[count / 2], "frame_p95_ms": samples[int(count * 0.95)],
		"process_p50_ms": cpu[count / 2], "process_p95_ms": cpu[int(count * 0.95)],
		"draw_calls_p50": calls[count / 2], "world_redraws": draw_count, "graph_redraws": graph_draw_count,
		"camera_start": str(start_camera), "camera_end": str(game.camera.position), "mouse": str(start_mouse)})
	record(name, details)

func dense_fixture(count: int) -> void:
	game.nodes.clear()
	game.hub_id = 1
	for i in range(1, count + 1):
		var cell := Vector2i(4 + ((i - 1) % 20) * 4, 4 + ((i - 1) / 20) * 4)
		game.nodes[i] = {"id": i, "type": "hub" if i == 1 else "nest", "cell": cell,
			"size": 3 if i == 1 else 2, "parent": -1, "tunnel": "", "relay": false,
			"on": true, "cap_rate": 0.0, "boost_t": 0.0, "lane": 0, "path": [], "acc": 0.0}
	game.next_id = count + 1
	game._vis_sig.clear()
	game._pl_cache.clear()
	game._undo.clear()
	game._edge.clear()
	game._connected = {1: true}
	game.packets.clear()
	game.camera.position = Vector2(900, 600)
	game.camera.zoom = Vector2.ONE
	game.current_tool = ""
	game.selected_id = -1
	game.selected_tunnel = -1
	game.ui.tab = "build"

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var settings = root.get_node("Settings")
	settings.text_scale = 1.0
	settings.cb = false
	settings.high_contrast = false
	settings.reduced_motion = false
	root.get_node("Session").seed = 1321476956
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.draw.connect(func(): draw_count += 1)
	game._city_layer.draw.connect(func(): city_draw_count += 1)
	var graph = game.ui.stats_box.find_children("", "Control", true, false).filter(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("graph.gd"))[0]
	graph.draw.connect(func(): graph_draw_count += 1)
	await settle()
	await run_frames("normal_opening", {"nodes": 1, "paused": false, "reduced_motion": false})
	game.paused = true
	await run_frames("paused_build", {"nodes": 1, "paused": true, "tab": "build"})
	game.ui.tab = "stats"
	await run_frames("paused_stats", {"nodes": 1, "paused": true, "tab": "stats"})
	# Backdrop load test: same live scene, different saved seed.
	game.ui.tab = "build"
	game.queue_redraw()
	await screen("21_before_seed_load")
	var saved: Dictionary = game._serialize()
	var old_seed: int = game.seed
	var old_grid: PackedInt32Array = game.region_grid.duplicate()
	var old_types := []
	for y in 20:
		for x in 20:
			old_types.append(game._tile_type(Vector2i(x * 5, y * 5)))
	saved.seed = 7654321
	city_draw_count = 0
	game._apply_save(saved)
	game.paused = true
	game.queue_redraw()
	await screen("22_after_seed_load_without_rebake")
	var changed := 0
	for y in 20:
		for x in 20:
			if old_types[y * 20 + x] != game._tile_type(Vector2i(x * 5, y * 5)):
				changed += 1
	record("different_seed_load", {"old_seed": old_seed, "new_seed": game.seed,
		"changed_district_cells": changed, "city_redraws_during_load": city_draw_count,
		"minimap_seed": game.ui.minimap._last_seed})
	game._invalidate_city()
	await screen("23_after_manual_rebake_control")
	# Same seed, same count, same camera: changed node position does not wake minimap.
	await settle()
	await settle()
	var mini_draws := [0]
	game.ui.minimap.draw.connect(func(): mini_draws[0] += 1)
	var same_seed_save: Dictionary = game._serialize()
	same_seed_save.nodes[str(game.hub_id)].cell = [18, 18]
	game._apply_save(same_seed_save)
	game.paused = true
	await settle(20)
	record("same_seed_node_move_load", {"minimap_redraws": mini_draws[0], "hub_cell": str(game.nodes[game.hub_id].cell), "same_seed": game.seed})
	# Dense rendering uses synthetic placement; it is not a legal economy run.
	for count in [50, 150, 400]:
		dense_fixture(count)
		game.paused = true
		settings.reduced_motion = false
		await run_frames("dense_paused", {"nodes": count, "fixture": "synthetic unlinked zero-output nodes; rendering scaling"}, 60)
		game.paused = false
		game._sweep_charge = -100000.0
		game._contract_cd = 100000.0
		game.resources.compute = 100000.0
		await run_frames("dense_running", {"nodes": count, "fixture": "synthetic unlinked zero-output nodes; rendering scaling"}, 60)
		settings.reduced_motion = true
		await run_frames("dense_reduced_motion", {"nodes": count, "fixture": "synthetic unlinked zero-output nodes; rendering scaling"}, 60)
	await screen("24_dense_network")
	quit()
