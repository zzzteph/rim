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
	game.resources = {"compute": 1000.0, "data": 0.0, "credits": 0.0, "crypto": 0.0, "tools": 0.0, "research": 0.0}
	game.packets.clear()
	game._pl_cache.clear()
	game._edge.clear()
	game._connected.clear()
	game._undo.clear()
	game._vis_sig.clear()
	game.sweep = {}
	game.trace = 0.0
	game.notoriety = 0.0
	game._blackout_t = 0.0
	game.contracts.clear()
	game._contract_cd = 1000.0
	game.slow_factor = 1.0

func run() -> void:
	root.get_node("Session").seed = 12345
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.get_node("UILayer/UI").set_process(false)
	await process_frame
	reset()
	game._spawn("credits", [2], 1, 0.5)
	game.nodes[2].boost_t = 17.0
	game.nodes[2].quarantine = 5.0
	game.notoriety = 65.0
	game._run_time = 250.0
	game.contracts = [{"id": 1, "accepted": true, "done": false}]
	game.save_game()
	var save_data = JSON.parse_string(FileAccess.get_file_as_string(root.get_node("Session").SAVE_PATH))
	report("save_schema", {"packet_value_saved": save_data.packets[0].has("value"),
		"boost_saved": save_data.nodes["2"].has("boost_t"), "quarantine_saved": save_data.nodes["2"].has("quarantine"),
		"notoriety_saved": save_data.has("notoriety"), "contracts_saved": save_data.has("contracts"), "run_time_saved": save_data.has("_run_time")})
	game.load_game()
	report("packet_reload_value", {"original_value": 0.5, "loaded_value": game.packets[0].get("value", 1.0)})
	reset()
	game.nodes[2].on = false
	game.nodes[3] = node(3, "phish", Vector2i(13, 5), 2, [Vector2i(12, 5)])
	game._sim_tick(0.1)
	report("disabled_junction", {"disabled_node_reachable": game._connected.has(2),
		"child_reachable": game._connected.has(3), "disabled_link_has_live_edge": game._edge.has(2), "total_upkeep": game.total_upkeep})
	game.packets.clear()
	game._edge = {2: {"frac": 1.0}, 3: {"frac": 1.0}}
	game.packets.append({"res": "data", "route": [3, 2], "idx": 0, "dir": 1,
		"dist": game._polyline(3).total - 1.0, "value": 1.0})
	game._move_packets(0.05)
	report("disabled_market_conversion", {"market_on": game.nodes[2].on, "packet_resource_after_crossing": game.packets[0].res})
	reset()
	game.resources.data = 100.0
	game._sim_tick(1.0)
	report("converter_load", {"offered": game._edge[2].offered, "in_transit_packets": game.packets.size(), "data_debited": 100.0 - game.resources.data})
	reset()
	for i in range(3, 83):
		game.nodes[i] = node(i, "phish", Vector2i(13 + (i % 8) * 4, 9 + (i / 8) * 4), 2, [Vector2i(12, 5)])
	game._sim_tick(0.1)
	report("capacity_floor", {"advertised_cap": game._edge[2].cap, "offered": game._edge[2].offered,
		"model_delivered": game._edge[2].delivered, "delivered_exceeds_cap": game._edge[2].delivered > game._edge[2].cap})
	reset()
	game.nodes[3] = node(3, "phish", Vector2i(13, 5), 2, [Vector2i(12, 5)])
	game._connected = {1: true, 2: true, 3: true}
	game.resources.credits = 100.0
	game._launch_sweep()
	game.sweep.warn = 0.0
	game._remove_tunnel(3)
	game._update_sweep(20.0)
	report("sweep_after_cut_tunnel", {"cut_parent": game.nodes[3].parent, "blackout_seconds": game._blackout_t, "cash_after": game.resources.credits})
	reset()
	game.resources.compute = 80.0
	game.contracts = [{"id": 1, "kind": "stock", "res": "compute", "amount": 20.0, "accepted": true,
		"done": false, "reward_cash": 50.0, "reward_rp": 5.0, "deadline": 90.0}]
	game._update_contracts(0.1)
	game.claim_contract(1)
	report("stock_contract", {"compute_after": game.resources.compute, "cash_reward": game.resources.credits, "research_reward": game.resources.research})
	reset()
	game.regions = [{"type": "vault", "ice": 1, "cells": 400, "cx": 10.0, "cy": 10.0}]
	game.region_grid.fill(0)
	var spot := Vector2i(-1, -1)
	for y in range(2, 17):
		for x in range(2, 17):
			if game._placement_error("fence", Vector2i(x, y), 2) == "":
				spot = Vector2i(x, y)
				break
		if spot.x >= 0:
			break
	if spot.x >= 0:
		game._try_place_node("fence", spot + Vector2i(1, 1))
		report("converter_ice_affordability", {"spot": [spot.x, spot.y], "tools_after_build": game.resources.tools, "placed": game.nodes.size() == 3})
		game.resources.tools = maxf(0.0, game.resources.tools)
		game.undo_last()
		report("unpaid_ice_undo", {"tools_after_clamp_and_undo": game.resources.tools})
	reset()
	game.nodes[2].acc = 0.95
	game.resources.data = 0.0
	game._sim_tick(0.1)
	game.resources.data = 100.0
	game._sim_tick(0.1)
	report("converter_buffer", {"packets_after_refill": game.packets.size(), "accumulator": game.nodes[2].acc})
	reset()
	game.nodes[2].parent = -1
	game.nodes[2].tunnel = ""
	game.nodes[2].path = []
	game.save_game()
	game._pay("dns")
	game.nodes[2].parent = 1
	game.nodes[2].tunnel = "dns"
	game.nodes[2].path = [Vector2i(8, 5)]
	game._push_undo({"t": "tunnel", "child": 2, "cost": game.COST.dns.duplicate()})
	game.load_game()
	var balance_before_undo := float(game.resources.compute)
	game.undo_last()
	report("load_stale_undo", {"cycles_after_load": balance_before_undo, "cycles_after_undo": game.resources.compute,
		"loaded_tunnel_absent": game.nodes[2].parent == -1})
	reset()
	game._generate_city()
	game.nodes.clear()
	game.next_id = 1
	game._place_hub()
	game.resources.compute = 80.0
	game._vis_sig.clear()
	for building in 3:
		var placed := false
		for y in range(game.MAP_H):
			for x in range(game.MAP_W):
				var origin := Vector2i(x, y)
				if game._zone_ice(origin) == 0 and game._placement_error("fence", origin, 2) == "":
					game._try_place_node("fence", origin + Vector2i(1, 1))
					placed = true
					break
			if placed:
				break
	for id in game.nodes:
		if id == game.hub_id:
			continue
		var path: Array = game._find_path(id, game.hub_id)
		if not path.is_empty():
			game.current_tool = "dns"
			game.pending_child = id
			game._try_tunnel(game.nodes[game.hub_id].cell)
			break
	game.save_game()
	root.get_node("Session").start_mode = "load"
	var continued = load("res://scenes/main.tscn").instantiate()
	root.add_child(continued)
	continued.set_process(false)
	continued.get_node("UILayer/UI").set_process(false)
	for tick in 1000:
		continued._sim_tick(0.1)
	var enabled_producers := 0
	for id in continued.nodes:
		if continued._is_producer(continued.nodes[id].type):
			enabled_producers += 1
	report("legal_opening_recovery", {"structures": continued.nodes.size(), "cycles_after_100_seconds": continued.resources.compute,
		"data_after_100_seconds": continued.resources.data, "cash_after_100_seconds": continued.resources.credits,
		"producers": enabled_producers, "undo_records_after_continue": continued._undo.size(), "can_afford_mirai": continued._can_afford("nest")})
	var out := FileAccess.open("res://../reverify_sim_base_results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(findings, "\t"))
	out.close()
	quit()
