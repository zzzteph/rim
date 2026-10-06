extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var session = root.get_node("Session")
	session.seed = 1321476956
	session.start_mode = "new"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.paused = true
	game.set_process(false)
	game._try_place_node("nest", Vector2i(2, 5))
	var source_id = game.next_id - 1
	var placement_message = game.message
	var target_cell = Vector2i(-1, -1)
	for y in range(4, 15):
		for x in range(7, 15):
			var c = Vector2i(x, y)
			if game._placement_error("nest", c - Vector2i(1, 1), 2) == "":
				target_cell = c
				break
		if target_cell.x != -1:
			break
	var out = {"seed": game.seed, "starter": {"id":source_id, "message":placement_message}, "target_cell":str(target_cell)}
	if target_cell.x == -1:
		out["error"] = "No second legal producer target"
	else:
		game._try_place_node("nest", target_cell)
		var target_id = game.next_id - 1
		game.current_tool = "dns"
		game.pending_child = source_id
		var before = game._cached_preview(target_cell).duplicate(true)
		game.undo_last()
		var after = game._cached_preview(target_cell).duplicate(true)
		var fresh = game._preview_route(target_cell).duplicate(true)
		out["stale_preview"] = {
			"source_exists":game.nodes.has(source_id),
			"target_exists_after_undo":game.nodes.has(target_id),
			"pending_unchanged":game.pending_child == source_id,
			"before":preview_summary(before),
			"cached_after":preview_summary(after),
			"fresh_after":preview_summary(fresh),
			"cached_equals_before":str(after) == str(before),
			"cached_differs_from_fresh":str(after) != str(fresh)
		}
	game._try_convert_relay(Vector2i(2, 5))
	game.current_tool = "dns"
	game.pending_child = source_id
	var hub_cell = game._center_cell(game.hub_id)
	var actual_route = game._preview_route(hub_cell)
	game._hint_cell = game._mouse_cell()
	game._hint_pending = source_id
	game._hint_tool = "dns"
	game._hint_route = actual_route
	game._update_hint()
	var preview_hint = game.hint
	game._try_tunnel(hub_cell)
	game._sim_tick(0.1)
	out["proxy_upkeep"] = {
		"fixture_note":"Cache populated from an actual route to C2 before calling _update_hint; no physical mouse hover is claimed.",
		"relay":game.nodes[source_id].relay,
		"path_length":game.nodes[source_id].path.size(),
		"preview_hint":preview_hint,
		"preview_formula":float(actual_route.len) * game.UPKEEP.dns,
		"actual_total_upkeep":game.total_upkeep,
		"ratio":(float(actual_route.len) * game.UPKEEP.dns) / game.total_upkeep
	}
	game.nodes[source_id].parent = -1
	game.nodes[source_id].tunnel = ""
	game.nodes[source_id].path = []
	game.pending_child = source_id
	var roof_point = game._center_world(game.hub_id) + Vector2(14, -40)
	var roof_cell = Vector2i(floori(roof_point.x / game.TILE), floori(roof_point.y / game.TILE))
	var roof_selection = game._node_at_silhouette(roof_point)
	var footprint_selection = game._node_at(roof_cell)
	game._try_tunnel(roof_cell)
	out["roof_tool_hit"] = {"world_point":str(roof_point),"cell":str(roof_cell),"silhouette_hit":roof_selection,"footprint_hit":footprint_selection,"tunnel_result":game.message,"pending_source":game.pending_child}
	var f = FileAccess.open("res://map_probe_results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print(JSON.stringify(out))
	quit()

func preview_summary(p: Dictionary) -> Dictionary:
	var pts = []
	for v in p.pts:
		pts.append([v.x, v.y])
	return {"blocked":p.blocked,"len":str(p.len),"why":str(p.get("why","")),"pts":pts}

