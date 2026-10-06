extends SceneTree

const OUT := "C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03"
var game
var measurements := []

func _initialize() -> void:
	_run.call_deferred()

func fixture_node(id: int, cell: Vector2i, parent := -1, kind := "nest") -> Dictionary:
	return {"id": id, "type": kind, "cell": cell, "size": 3 if kind == "hub" else 2,
		"parent": parent, "tunnel": "dns" if parent != -1 else "", "relay": false,
		"on": true, "cap_rate": 0.0, "boost_t": 0.0, "lane": 0,
		"path": [], "acc": 0.0}

func reset_network(count: int, chain := false) -> void:
	game.nodes.clear()
	game.nodes[1] = fixture_node(1, Vector2i(0, 0), -1, "hub")
	game.hub_id = 1
	for i in range(2, count + 1):
		var ix := (i - 2) % 20
		var iy := (i - 2) / 20
		var cell := Vector2i(4 + ix * 4, 4 + iy * 4)
		var p := i - 1 if chain else 1
		game.nodes[i] = fixture_node(i, cell, p)
		game.nodes[i].path = [cell + Vector2i(2, 0)]
	game.next_id = count + 1
	game.resources = {"compute": 100000.0, "data": 0.0, "crypto": 0.0, "tools": 0.0, "research": 0.0, "credits": 0.0}
	game.packets.clear()
	game._pl_cache.clear()
	game._vis_sig.clear()
	game.contracts.clear()
	game._contract_cd = 100000.0
	game._sweep_charge = -100000.0
	game._blackout_t = 0.0
	game.trace = 0.0
	game.notoriety = 0.0
	game.sweep.clear()
	game._undo.clear()
	game.selected_id = -1
	game.selected_tunnel = -1
	game.current_tool = ""
	game.camera.position = Vector2(900, 600)
	game.camera.zoom = Vector2.ONE

func measure(name: String, fn: Callable, count: int, details: Dictionary) -> void:
	for i in 5:
		fn.call()
	var samples := []
	for i in count:
		var start := Time.get_ticks_usec()
		fn.call()
		samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	var total := 0.0
	for s in samples:
		total += s
	details.merge({"name": name, "iterations": count, "mean_ms": total / count,
		"p50_ms": samples[count / 2], "p95_ms": samples[mini(count - 1, int(count * 0.95))], "max_ms": samples[-1]})
	measurements.append(details)
	print(JSON.stringify(details))

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("Session").seed = 12345
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.ui.set_process(false)
	await process_frame
	for count in [1, 50, 150, 400]:
		reset_network(count)
		measure("sim_tick_star", func(): game._sim_tick(0.1), 80, {"nodes": count, "fixture": "synthetic star, cap_rate=0, single-cell paths; CPU scaling only"})
		measure("visual_signature", func(): game._visual_sig(), 150, {"nodes": count})
		measure("ui_process_build", func(): game.ui._process(0.016), 100, {"nodes": count, "tab": "build"})
		game.ui.tab = "stats"
		measure("ui_process_stats", func(): game.ui._process(0.016), 100, {"nodes": count, "tab": "stats"})
		game.ui.tab = "build"
		measure("minimap_process_cached", func(): game.ui.minimap._process(0.016), 150, {"nodes": count})
		measure("vision_cached", func(): game._vision_list(), 150, {"nodes": count})
		measure("vision_rebuild", func(): game._vis_sig.clear(); game._vision_list(), 12, {"nodes": count, "map": "100x100, 625 fog blocks"})
		reset_network(count, true)
		measure("sim_tick_chain", func(): game._sim_tick(0.1), 50, {"nodes": count, "fixture": "synthetic deep chain, cap_rate=0; CPU scaling only"})
	# Route lookups on the actual generated city, without synthetic occupied links.
	reset_network(2)
	game.nodes[2].parent = -1
	game.nodes[2].tunnel = ""
	game.nodes[2].path = []
	for target in [Vector2i(11, 11), Vector2i(79, 79), Vector2i(99, 99)]:
		measure("a_star_preview", func(): game._find_path_to_cell(2, target), 8,
			{"target": str(target), "seed": game.seed, "actual_city": true})
	# Many packets halfway along one winding polyline. No arrivals during measurement.
	reset_network(2)
	var winding := []
	for i in range(120):
		winding.append(Vector2i(3 + i / 4, 3 + i % 4))
	game.nodes[2].path = winding
	game._pl_cache.clear()
	game._connected = {1: true, 2: true}
	game._edge = {2: {"frac": 1.0}}
	var pl: Dictionary = game._polyline(2)
	for count in [100, 1000, 3000]:
		game.packets.clear()
		for i in count:
			game.packets.append({"res": "compute", "route": [2], "idx": 0, "dir": 1,
				"dist": float(pl.total) * 0.45, "value": 1.0})
		measure("packet_movement", func(): game._move_packets(0.0001), 80,
			{"packets": count, "path_cells": winding.size(), "polyline_points": pl.pts.size(), "fixture": "synthetic one-edge winding route"})
	var f := FileAccess.open(OUT + "/performance_results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine": Engine.get_version_info(), "renderer": "headless CPU microbenchmarks; not GPU FPS", "measurements": measurements}, "\t"))
	f.close()
	quit()
