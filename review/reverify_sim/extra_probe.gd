extends SceneTree

var game
var findings := []

func _initialize() -> void:
	call_deferred("run")

func report(label: String, observed: Dictionary) -> void:
	findings.append({"probe": label, "observed": observed})
	print(JSON.stringify(findings[-1]))

func node(id: int, kind: String, cell: Vector2i, parent := -1, path: Array = []) -> Dictionary:
	return {"id": id, "type": kind, "cell": cell, "size": 3 if kind == "hub" else 2,
		"parent": parent, "tunnel": "dns" if parent != -1 else "", "relay": false,
		"on": true, "cap_rate": 1.0, "boost_t": 0.0, "lane": 0, "path": path, "acc": 0.0}

func reset() -> void:
	game.nodes = {1: node(1, "hub", Vector2i(5, 5)), 2: node(2, "fence", Vector2i(9, 5), 1, [Vector2i(8, 5)])}
	game.hub_id = 1
	game.next_id = 3
	game.resources = {"compute": 1000.0, "data": 100.0, "credits": 0.0, "crypto": 0.0, "tools": 0.0, "research": 0.0}
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
	game.contracts.clear()
	game._contract_cd = 1000.0
	game.slow_factor = 1.0
	game.current_tool = ""
	game.pending_child = -1
	game.selected_id = -1
	game.selected_tunnel = -1
	game.regions = [{"type": "residential", "ice": 0, "cells": 400, "cx": 10.0, "cy": 10.0}]
	game.region_grid.fill(0)

func run() -> void:
	root.get_node("Session").seed = 12345
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.get_node("UILayer/UI").set_process(false)
	await process_frame

	reset()
	game.nodes[3] = node(3, "phish", Vector2i(13, 5), 2, [Vector2i(12, 5)])
	game.nodes[4] = node(4, "fence", Vector2i(9, 9), 1, [Vector2i(8, 9)])
	game._connected[3] = true
	game._connected[4] = true
	game._edge = {2: {"frac": 1.0}, 3: {"frac": 1.0}, 4: {"frac": 1.0}}
	game._spawn("compute", [3, 2], 1)
	game.nodes[3].parent = 4
	game.nodes[3].path = [Vector2i(12, 6), Vector2i(12, 7), Vector2i(12, 8)]
	game._pl_cache.clear()
	game.packets[0].dist = game._polyline(3).total - 1.0
	game._move_packets(0.05)
	report("stale_packet_route_after_reparent", {"live_parent": game.nodes[3].parent, "packet_route": game.packets[0].route, "edge_after_crossing": game.packets[0].route[game.packets[0].idx]})

	reset()
	game.nodes[3] = node(3, "fence", Vector2i(13, 9), 1, [Vector2i(12, 9)])
	var old_parent = game.nodes[2].parent
	game.selected_tunnel = 2
	game.remove_selected()
	game.set_tool("dns")
	game._try_tunnel(game.nodes[2].cell)
	var pending_after_source = game.pending_child
	game.undo_last()
	var restored_parent = game.nodes[2].parent
	var pending_after_restore = game.pending_child
	game._try_tunnel(game.nodes[3].cell)
	var new_parent = game.nodes[2].parent
	game.undo_last()
	report("reroute_undo_loses_old_tunnel_legal_commands", {"old_parent": old_parent, "pending_after_source": pending_after_source, "restored_parent": restored_parent, "pending_after_restore": pending_after_restore, "new_parent": new_parent, "parent_after_undo": game.nodes[2].parent, "path_after_undo": game.nodes[2].path})

	reset()
	game.nodes[3] = node(3, "nest", Vector2i(13, 5))
	game._push_undo({"t": "place", "id": 3, "cost": {"compute": 10.0}})
	game.current_tool = "dns"
	game.pending_child = 3
	game.undo_last()
	report("undo_pending_child", {"pending_child": game.pending_child, "pending_exists": game.nodes.has(game.pending_child)})

	reset()
	game.selected_tunnel = 2
	game._push_undo({"t": "tunnel", "child": 2, "cost": {"compute": 5.0}})
	game.undo_last()
	report("undo_selected_tunnel", {"selected_tunnel": game.selected_tunnel, "selected_type": game.nodes[2].tunnel})

	reset()
	game.nodes[3] = node(3, "phish", Vector2i(13, 5), 2, [Vector2i(12, 5)])
	game._connected[3] = true
	game._launch_sweep()
	game._update_sweep(0.1)
	report("sweep_warning_quarantine", {"warn_remaining": game.sweep.warn, "target_quarantine": game.nodes[3].get("quarantine", 0.0)})
	game.nodes[2].on = false
	game.nodes[3].on = false
	report("linked_structure_contract_includes_off", {"enabled_nonhub": 0, "reported_progress": game._contract_progress({"kind": "nodes"})})

	reset()
	game.nodes[2].on = false
	game._edge = {2: {"frac": 1.0}}
	game._spawn("data", [2], -1)
	game.packets[0].dist = game._polyline(2).total - 1.0
	game._move_packets(0.05)
	report("input_arrival_off_converter", {"market_on": false, "packets": game.packets.duplicate(true)})

	reset()
	game.nodes[3] = node(3, "nest", Vector2i(13, 5))
	game.nodes[3].on = false
	game.selected_id = 3
	game.overclock_selected()
	var compute_after_off = game.resources.compute
	game.nodes[3].boost_t = 15.0
	game.overclock_selected()
	report("overclock_off_and_repeat", {"disabled": true, "first_charge": 1000.0 - compute_after_off, "second_charge": compute_after_off - game.resources.compute, "duration_after_second": game.nodes[3].boost_t})

	reset()
	game.regions = [{"type": "glasshouse", "ice": 0, "cells": 2, "cx": 0.0, "cy": 0.0}, {"type": "glasshouse", "ice": 0, "cells": 2, "cx": 0.0, "cy": 0.0}]
	game.region_grid.fill(1)
	game.region_grid[0] = 0
	game.nodes = {1: node(1, "hub", Vector2i(10, 5)), 2: node(2, "phish", Vector2i(8, 8)), 3: node(3, "phish", Vector2i(12, 8))}
	game.next_id = 4
	var boundary_origin = Vector2i(4, 2)
	var boundary_error = game._placement_error("phish", boundary_origin, 2)
	var slots_in_dest_before = game._slots_left(Vector2i(5, 2))
	game._try_place_node("phish", boundary_origin + Vector2i(1, 1))
	report("district_slots_origin_center_mismatch", {"placement_error": boundary_error, "origin_region": game._region_at(boundary_origin), "center_region": game._region_at(boundary_origin + Vector2i(1, 1)), "destination_slots_before": slots_in_dest_before, "destination_slots_after": game._slots_left(Vector2i(5, 2)), "placed": game.nodes.has(4)})

	reset()
	var overlap_origin = Vector2i(6, 8)
	game.nodes[2].path = [Vector2i(7, 8), Vector2i(7, 9)]
	var overlap_err = game._placement_error("fence", overlap_origin, 2)
	game._try_place_node("fence", overlap_origin + Vector2i(1, 1))
	report("construction_over_existing_tunnel", {"placement_error": overlap_err, "placed": game.nodes.has(3), "occupied_tunnel_cell": game._node_at(Vector2i(7, 8)), "path_after": game.nodes[2].path})

	reset()
	var mismatches := []
	game._generate_city()
	for by in 25:
		for bx in 25:
			var dtype = game._tile_type(Vector2i(bx * 4 + 1, by * 4 + 1))
			var is_rendered = game._h2(bx, by) % 10 >= (4 if dtype == "slums" else 2)
			for dy in 3:
				for dx in 3:
					var c = Vector2i(bx * 4 + dx, by * 4 + dy)
					if is_rendered != game._is_building_cell(c):
						mismatches.append({"cell": [c.x, c.y], "rendered": is_rendered, "collision": game._is_building_cell(c), "render_district": dtype, "cell_district": game._tile_type(c)})
	report("city_vacancy_render_collision", {"count": mismatches.size(), "examples": mismatches.slice(0, 5)})
	var farm_mismatch := []
	for by in 25:
		for bx in 25:
			var dtype = game._tile_type(Vector2i(bx * 4 + 1, by * 4 + 1))
			if dtype == "farm" and game._h2(bx, by) % 10 >= 2:
				var c = Vector2i(bx * 4 + 1, by * 4 + 2)
				if game._is_building_cell(c):
					farm_mismatch.append([c.x, c.y])
	report("farm_narrow_render_wide_collision", {"count": farm_mismatch.size(), "examples": farm_mismatch.slice(0, 5)})

	reset()
	var coverage_examples := []
	for y in range(5, 20):
		for x in range(5, 20):
			var ctr = Vector2i(x, y)
			var disk := {}
			var square := {}
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var c = ctr + Vector2i(dx, dy)
					if game._is_building_cell(c):
						square[Vector2i(c.x / 4, c.y / 4)] = true
						if dx * dx + dy * dy <= 16:
							disk[Vector2i(c.x / 4, c.y / 4)] = true
			if square.size() > disk.size():
				coverage_examples.append({"center": [x, y], "square": game._coverage(ctr), "disk": disk.size()})
	report("coverage_square_versus_disk", {"different_centers": coverage_examples.size(), "examples": coverage_examples.slice(0, 5)})

	reset()
	game.regions = [{"type": "residential", "ice": 0, "cells": 400, "cx": 10.0, "cy": 10.0}]
	game.region_grid.fill(0)
	var ground = Vector2i(4, 2)
	report("advanced_cycles_residential", {"nest_error": game._placement_error("nest", ground, 2), "package_error": game._placement_error("package", ground, 2), "botfarm_error": game._placement_error("botfarm", ground, 2)})

	var out := FileAccess.open("res://../reverify_sim_extra_results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(findings, "\t"))
	out.close()
	quit()
