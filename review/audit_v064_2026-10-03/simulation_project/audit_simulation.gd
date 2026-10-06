extends SceneTree

var m: Node2D
var results := {}

func _initialize() -> void:
	call_deferred("run")

func fresh() -> void:
	if m != null:
		root.remove_child(m)
		m.free()
	root.get_node("Session").seed = 12345
	m = load("res://scripts/main.gd").new()
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	m.add_child(cam)
	root.add_child(m)
	m.set_process(false)

func n(id: int, type: String, cell: Vector2i, parent: int = -1, tunnel: String = "") -> Dictionary:
	return {"id": id, "type": type, "cell": cell, "size": 3 if type == "hub" else 2,
		"parent": parent, "tunnel": tunnel, "relay": false, "on": true,
		"cap_rate": 1.0, "boost_t": 0.0, "lane": 0,
		"path": [cell + Vector2i(2, 0), cell + Vector2i(3, 0)], "coverage": 5}

func fixture() -> void:
	fresh()
	m.nodes = {1: n(1, "hub", Vector2i(10, 10)), 2: n(2, "nest", Vector2i(15, 10), 1, "dns")}
	m.hub_id = 1
	m.next_id = 3
	m.resources = {"compute": 1000.0, "data": 0.0, "credits": 0.0, "crypto": 0.0, "tools": 0.0, "research": 0.0}
	m._connected = {1: true, 2: true}
	m._pl_cache.clear()
	m.rng.seed = 100

func run() -> void:
	fixture()
	m.nodes[2].type = "botfarm"
	m._sim_tick(0.1)
	results.capacity_soft_ceiling = m._edge[2].duplicate(true)

	fixture()
	m.nodes[2].type = "forge"
	m.resources.data = 100.0
	m.resources.compute = 0.0
	results.converter_no_fuel = {"traffic": m._node_traffic(2), "fuel": m.resources.compute}
	m._sim_tick(0.1)
	results.converter_no_fuel["spawned"] = m.packets.size()

	fixture()
	m.nodes[2].cap_rate = 0.0
	m.resources.compute = 0.0
	m._sim_tick(0.1)
	results.zero_output_emergency = {"production": m._production(2), "compute": m.resources.compute, "has_income": m._has_cycle_income(), "reserve": m._emergency_active}

	fixture()
	m.nodes[3] = n(3, "forge", Vector2i(20, 10), 2, "dns")
	m._connected[3] = true
	m._spawn("data", [2, 3], -1)
	m.nodes[3].parent = 1
	m._pl_cache.clear()
	var first_len: float = m._polyline(2).total
	m._move_packets((first_len + 1.0) / m.PACKET_SPEED)
	results.stale_downward_route = {"packets": m.packets.duplicate(true), "processor_parent": m.nodes[3].parent, "intermediate": 2}

	fixture()
	m.nodes[2].type = "forge"
	m._spawn("data", [2], -1)
	m.nodes[2].on = false
	m._move_packets(100.0)
	m._move_packets(100.0)
	results.disabled_inflight_converter = {"tools": m.resources.tools, "on": m.nodes[2].on}

	fixture()
	m.nodes[2].on = false
	m.selected_id = 2
	var before: float = m.resources.compute
	m.overclock_selected()
	results.disabled_overclock = {"cost": before - m.resources.compute, "boost": m.nodes[2].boost_t, "production": m._production(2)}

	fixture()
	m.nodes[2].parent = -1
	m.nodes[2].tunnel = ""
	m.selected_id = 2
	before = m.resources.compute
	m.overclock_selected()
	results.offline_overclock = {"cost": before - m.resources.compute, "boost": m.nodes[2].boost_t, "chain": m._chain(2)}

	fixture()
	m.contracts = [{"id": 1, "kind": "stock", "res": "data", "amount": 20.0, "accepted": false, "done": false, "deadline": 90.0, "client": "Audit", "desc": "Deliver 20 Intel to C2", "reward_cash": 50.0, "reward_rp": 5.0}]
	m.accept_contract(1)
	m.resources.data += 20.0
	m.resources.data -= 5.0
	m._update_contracts(0.1)
	results.consumed_deliveries_contract = {"actual_delivered_fixture": 20.0, "progress": m._contract_progress(m.contracts[0]), "done": m.contracts[0].done}

	fresh()
	var placed := []
	for y in m.MAP_H:
		for x in m.MAP_W:
			var origin := Vector2i(x, y)
			if m._placement_error("nest", origin, 2) == "":
				m._try_place_node("nest", origin + Vector2i.ONE)
				placed.append(origin)
				if placed.size() == 2:
					break
		if placed.size() == 2:
			break
	m.contracts = [{"id": 1, "kind": "stock", "res": "compute", "amount": 20.0, "accepted": false, "done": false, "deadline": 90.0, "client": "Audit", "desc": "Deliver 20 Cycles to C2", "reward_cash": 50.0, "reward_rp": 5.0}]
	m.accept_contract(1)
	m.undo_last()
	m.undo_last()
	m._update_contracts(0.1)
	results.legal_placement_refund_contract = {"placed_origins": placed, "progress": m._contract_progress(m.contracts[0]), "done": m.contracts[0].done, "packets_delivered": m._packets_delivered}

	fixture()
	var good: Dictionary = m._serialize().duplicate(true)
	var bad := good.duplicate(true)
	bad.nodes["2"].erase("tunnel")
	results.save_missing_tunnel = m._validate_save(bad)
	bad = good.duplicate(true)
	bad.nodes["2"].path = [[1]]
	results.save_bad_path = m._validate_save(bad)
	bad = good.duplicate(true)
	bad.nodes["2"].parent = 1
	bad.nodes["2"].tunnel = "invalid"
	results.save_unknown_tunnel = m._validate_save(bad)
	bad = good.duplicate(true)
	bad.nodes["1"].parent = 2
	bad.nodes["1"].tunnel = "dns"
	results.save_cycle = m._validate_save(bad)
	bad = good.duplicate(true)
	bad.packets = [{"route": [2], "idx": 0}]
	results.save_missing_packet_fields = m._validate_save(bad)
	bad = good.duplicate(true)
	bad.contracts = [{"id": 1}]
	results.save_missing_contract_fields = m._validate_save(bad)
	bad = good.duplicate(true)
	bad.researched = ["invalid_tech"]
	results.save_unknown_research = m._validate_save(bad)
	bad = good.duplicate(true)
	bad.next_id = 1
	bad.camera = [0.0, 0.0, 0.0]
	bad.resources.compute = -100.0
	results.save_invalid_ranges = m._validate_save(bad)
	bad = good.duplicate(true)
	bad.version = "999.0"
	results.save_unknown_version = m._validate_save(bad)
	bad = good.duplicate(true)
	bad.nodes["2"].id = 1
	results.save_duplicate_id = m._validate_save(bad)

	fixture()
	m.save_game()
	m.resources.compute = 999.0
	m.save_game()
	var invalid := FileAccess.open(root.get_node("Session").SAVE_PATH, FileAccess.WRITE)
	invalid.store_string('{"version":"0.6.4"}')
	invalid.close()
	var backup_before = m._read_valid_save(root.get_node("Session").BACKUP_PATH)
	m.resources.compute = 888.0
	m.save_game()
	var backup_after = m._read_valid_save(root.get_node("Session").BACKUP_PATH)
	results.invalid_backup_rotation = {"valid_before": backup_before != null, "valid_after": backup_after != null}

	fixture()
	m.nodes[2].quarantine = 5.0
	m.trace = 60.0
	m.resources.tools = 1.0
	m.scrub_trace()
	results.scrub_retains_quarantine = {"trace": m.trace, "quarantine": m.nodes[2].quarantine, "message": m.message}

	fixture()
	m.nodes[2].on = false
	m.nodes[2].tunnel = "tcp"
	m.nodes[3] = n(3, "phish", Vector2i(20, 10), 2, "dns")
	m.trace = 10.0
	m._sim_tick(0.1)
	results.disabled_tunnel_noise = {"upkeep": m.total_upkeep, "trace": m.trace, "operational_connection": m._connected.has(2), "downstream_production": m._production(3)}

	fixture()
	m.nodes[10] = n(10, "phish", Vector2i(20, 10), 1, "dns")
	m._connected[10] = true
	m.next_id = 11
	m._launch_sweep()
	var target_before: int = m.sweep.path[0]
	var roundtrip = m._json_or_null(JSON.stringify(m._serialize()))
	m._apply_save(roundtrip)
	m._connected = {1: true, 2: true, 10: true}
	m._launch_sweep()
	results.saved_iteration_order = {"target_before": target_before, "target_after": m.sweep.path[0], "restored_ids": m.nodes.keys()}

	fixture()
	m.resources.credits = 1000.0
	var price_before: float = m._market_price()
	m.resources.credits -= 500.0
	results.wallet_market_price = {"price_before": price_before, "price_after_spending": m._market_price()}

	fresh()
	m.resources.tools = 100.0
	m.resources.compute = 1000.0
	var ice_example := {}
	for y in range(1, m.MAP_H - 3):
		for x in range(1, m.MAP_W - 3):
			var origin := Vector2i(x, y)
			if m._zone_ice(origin) == 0 and m._zone_ice(origin + Vector2i.ONE) > 0:
				m.nodes[m.hub_id].cell = origin - Vector2i(5, 5)
				m._vis_sig.clear()
				if m._placement_error("fence", origin, 2) == "":
					var tools_before: float = m.resources.tools
					m._try_place_node("fence", origin + Vector2i.ONE)
					ice_example = {"origin": origin, "origin_ice": m._zone_ice(origin), "centre_ice": m._zone_ice(origin + Vector2i.ONE), "tools_paid": tools_before - m.resources.tools}
					break
		if not ice_example.is_empty():
			break
	results.footprint_ice_bypass = ice_example

	fresh()
	m.nodes = {1: n(1, "hub", Vector2i(40, 40))}
	m.hub_id = 1
	m.next_id = 2
	m.resources.compute = 1000.0
	m.regions = [{"type": "registry", "cells": 2, "ice": 0}]
	m.region_grid.fill(0)
	m._vis_sig.clear()
	var nests := []
	for y in range(29, 55):
		for x in range(29, 55):
			var origin := Vector2i(x, y)
			if m._placement_error("nest", origin, 2) == "":
				m._try_place_node("nest", origin + Vector2i.ONE)
				nests.append(origin)
				if nests.size() == 3:
					break
		if nests.size() == 3:
			break
	results.nest_slot_bypass = {"district_cap": 2, "nests_placed": nests.size(), "slots_left": m._slots_left(Vector2i(40, 40)), "origins": nests}

	fixture()
	m.resources.credits = 1000.0
	m._sim_tick(0.1)
	results.win_run_time_before = m._run_time
	for i in 100:
		m._sim_tick(0.1)
	results.win_run_time_after = m._run_time

	var out := FileAccess.open("res://simulation_results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(results, "\t"))
	out.close()
	print(JSON.stringify(results))
	quit()
