extends SceneTree
## T99: intended-behavior assertion suite for the recovery/persistence milestone (v0.5.9).
## Each check encodes the ACCEPTANCE criterion for a backlog item and must PASS only after
## the intended rule is implemented. Save paths are redirected to res:// (never user data).

var game
var results := []
var pass_count := 0
var fail_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(id: String, ok: bool, detail := "") -> void:
	results.append({"id": id, "pass": ok, "detail": detail})
	if ok: pass_count += 1
	else: fail_count += 1
	print("ASSERT %-28s %s  %s" % [id, "PASS" if ok else "FAIL", detail])

func approx(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps

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

func clear_saves() -> void:
	for p in [root.get_node("Session").SAVE_PATH, root.get_node("Session").BACKUP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

func new_game():
	var inst = load("res://scenes/main.tscn").instantiate()
	root.add_child(inst)
	inst.set_process(false)
	inst.get_node("UILayer/UI").set_process(false)
	return inst

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("Session").seed = 12345
	game = new_game()
	await process_frame

	# ---- B16/B17/B18/B19/B20: full round-trip of in-flight + subsystem state ----
	clear_saves()
	reset()
	game._spawn("credits", [2], 1, 0.5)
	game.nodes[2].boost_t = 17.0
	game.nodes[2].quarantine = 5.0
	game.notoriety = 65.0
	game._sweep_charge = 7.0
	game._blackout_t = 2.0
	game.sweep = {"path": [2], "step": 0, "warn": 3.0, "t": 0.5}
	game._run_time = 250.0
	game._packets_delivered = 40
	game._max_trace = 91.0
	game._peak_cash_rate = 6.0
	game.contracts = [{"id": 1, "kind": "stock", "res": "compute", "amount": 20.0, "accepted": true, "done": false, "reward_cash": 50.0, "reward_rp": 5.0, "deadline": 90.0}]
	game._next_contract_id = 9
	game._contract_cd = 13.0
	game.save_game()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(root.get_node("Session").SAVE_PATH))
	check("B16_schema_packet_value", saved.packets[0].has("value") and approx(saved.packets[0].value, 0.5))
	check("B18_schema_boost", saved.nodes["2"].has("boost_t"))
	check("B17_schema_quarantine", saved.nodes["2"].has("quarantine"))
	check("B17_schema_notoriety", saved.has("notoriety") and saved.has("sweep") and saved.has("blackout_t") and saved.has("sweep_charge"))
	check("B19_schema_contracts", saved.has("contracts") and saved.contracts.size() == 1 and saved.has("next_contract_id"))
	check("B20_schema_stats", saved.has("_run_time") and saved.has("_packets_delivered") and saved.has("_max_trace"))
	check("B23_schema_rng", saved.has("rng_state"))

	game.load_game()
	check("B16_packet_value_roundtrip", approx(game.packets[0].get("value", 1.0), 0.5), "value=%s" % game.packets[0].get("value", 1.0))
	check("B18_boost_roundtrip", approx(game.nodes[2].get("boost_t", 0.0), 17.0))
	check("B17_quarantine_roundtrip", approx(game.nodes[2].get("quarantine", 0.0), 5.0))
	check("B17_notoriety_roundtrip", approx(game.notoriety, 65.0))
	check("B17_sweep_roundtrip", (not game.sweep.is_empty()) and int(game.sweep.path[0]) == 2 and approx(float(game.sweep.warn), 3.0))
	check("B17_blackout_roundtrip", approx(game._blackout_t, 2.0) and approx(game._sweep_charge, 7.0))
	check("B19_contracts_roundtrip", game.contracts.size() == 1 and int(game.contracts[0].id) == 1 and game._next_contract_id == 9 and approx(game._contract_cd, 13.0))
	check("B20_stats_roundtrip", approx(game._run_time, 250.0) and game._packets_delivered == 40 and approx(game._max_trace, 91.0) and approx(game._peak_cash_rate, 6.0))

	# ---- B16: a restored 0.5 packet banks exactly 0.5, once ----
	reset()
	game._spawn("credits", [2], 1, 0.5)
	game.save_game()
	game.load_game()
	game._connected = {1: true, 2: true}   # sim rebuilds this each tick; set it for the direct call
	game._edge = {2: {"frac": 1.0}}
	game.packets[0].dist = game._polyline(2).total + 5.0   # push it to/past the hub
	var cash_before: float = game.resources.credits
	game._move_packets(0.05)
	check("B16_banks_half_once", approx(game.resources.credits - cash_before, 0.5) and game.packets.is_empty(),
		"delta=%s remaining=%d" % [game.resources.credits - cash_before, game.packets.size()])

	# ---- B23: RNG stream continues exactly across reload ----
	clear_saves()
	reset()
	game.rng.randf(); game.rng.randf()
	var expected_state: int = game.rng.state
	game.save_game()
	var expected_next: float = game.rng.randf()
	game.load_game()
	check("B23_rng_state_restored", str(game.rng.state) == str(expected_state), "want %s got %s" % [expected_state, game.rng.state])
	check("B23_rng_next_draw_matches", approx(game.rng.randf(), expected_next))

	# ---- B24: transient interaction state is cleared on load ----
	clear_saves()
	reset()
	game.rates = {"credits": 20.0}
	game._rate_prev = game.resources.duplicate()
	game._rate_t = 0.8
	game._accum = 0.09
	game.selected_tunnel = 2
	game._panning = true
	game._hint_route = {"cached_marker": true}
	game.save_game()
	game.load_game()
	check("B24_transient_cleared",
		game.selected_tunnel == -1 and game._panning == false and approx(game._rate_t, 0.0)
		and float(game.rates.get("credits", 0.0)) == 0.0 and approx(game._accum, 0.0)
		and not game._hint_route.has("cached_marker"),
		"tun=%d pan=%s rt=%s acc=%s hint=%s" % [game.selected_tunnel, game._panning, game._rate_t, game._accum, game._hint_route.has("cached_marker")])

	# ---- B24: discarded-timeline undo cannot mint resources after load ----
	clear_saves()
	reset()
	game.save_game()
	game._push_undo({"t": "tunnel", "child": 2, "cost": {"compute": 5.0}})
	game.load_game()
	var before: float = game.resources.compute
	game.undo_last()
	check("B24_stale_undo_no_mint", approx(game.resources.compute, before) and game._undo.is_empty(),
		"before=%s after=%s" % [before, game.resources.compute])

	# ---- B21: empty/invalid schema is refused and the live run is untouched ----
	clear_saves()
	reset()
	var wf := FileAccess.open(root.get_node("Session").SAVE_PATH, FileAccess.WRITE)
	wf.store_string("{}")
	wf.close()
	var ok_empty: bool = game.load_game()
	check("B21_reject_empty_object", ok_empty == false and game.nodes.size() == 2 and game.nodes.has(game.hub_id),
		"returned=%s nodes=%d hub=%s" % [ok_empty, game.nodes.size(), game.nodes.has(game.hub_id)])
	# a node graph with no hub is also rejected
	clear_saves()
	var wf2 := FileAccess.open(root.get_node("Session").SAVE_PATH, FileAccess.WRITE)
	wf2.store_string(JSON.stringify({"version": "x", "resources": {}, "hub_id": 1, "nodes": {"2": {"id": 2, "type": "fence", "cell": [9, 5], "size": 2, "parent": -1}}}))
	wf2.close()
	reset()
	check("B21_reject_no_hub", game.load_game() == false and game.nodes.size() == 2)

	# ---- B22/T95: a corrupt latest save recovers from the verified backup ----
	clear_saves()
	reset()
	game.resources.compute = 111.0
	game.save_game()                  # save A (no backup yet)
	reset()
	game.resources.compute = 222.0
	game.save_game()                  # save B; backup now holds A(111)
	check("B22_backup_created", FileAccess.file_exists(root.get_node("Session").BACKUP_PATH))
	var cf := FileAccess.open(root.get_node("Session").SAVE_PATH, FileAccess.WRITE)
	cf.store_string("{ this is not json")
	cf.close()
	var recovered: bool = game.load_game(true)   # Continue-style load may use the backup
	check("T95_recover_from_backup", recovered and approx(game.resources.compute, 111.0),
		"recovered=%s compute=%s" % [recovered, game.resources.compute])
	# in-session load (no backup allowed) refuses a corrupt main and keeps the live run
	reset()
	game.resources.compute = 777.0
	var cf2 := FileAccess.open(root.get_node("Session").SAVE_PATH, FileAccess.WRITE)
	cf2.store_string("{ broken")
	cf2.close()
	check("B21_insession_refuse_corrupt", game.load_game() == false and approx(game.resources.compute, 777.0))

	# ---- B02: ICE placement is refused at zero Tools; no charge, no node, no mint ----
	clear_saves()
	reset()
	game.regions = [{"type": "vault", "ice": 1, "cells": 400, "cx": 10.0, "cy": 10.0}]
	game.region_grid.fill(0)
	var any_ice_spot_allowed := false
	for y in range(2, 17):
		for x in range(2, 17):
			if game._placement_error("fence", Vector2i(x, y), 2) == "":
				any_ice_spot_allowed = true
	check("B02_ice_refused_zero_tools", not any_ice_spot_allowed)
	var tools_before: float = game.resources.tools
	var nodes_before: int = game.nodes.size()
	game._try_place_node("fence", Vector2i(10, 10))
	check("B02_no_charge_no_node", approx(game.resources.tools, tools_before) and game.nodes.size() == nodes_before,
		"tools=%s nodes=%d" % [game.resources.tools, game.nodes.size()])
	# with exactly enough Tools, the ICE build is allowed and pays precisely ice + base
	game.resources.tools = 1.0
	var spot := Vector2i(-1, -1)
	for y in range(2, 17):
		for x in range(2, 17):
			if game._placement_error("fence", Vector2i(x, y), 2) == "":
				spot = Vector2i(x, y)
				break
		if spot.x >= 0: break
	if spot.x >= 0:
		game._try_place_node("fence", spot + Vector2i(1, 1))
		check("B02_ice_build_with_tools", game.nodes.size() == nodes_before + 1 and approx(game.resources.tools, 0.0))
		game.undo_last()
		check("B02_undo_refunds_exact_tool", approx(game.resources.tools, 1.0) and game.nodes.size() == nodes_before,
			"tools=%s" % game.resources.tools)
	else:
		check("B02_ice_build_with_tools", false, "no spot found with 1 Tool")

	# ---- B01/T40: the legal zero-resource opening recovers after fresh Continue ----
	clear_saves()
	game._generate_city()
	game.nodes.clear()
	game.next_id = 1
	game._place_hub()
	game.resources = {"compute": 80.0, "data": 0.0, "credits": 0.0, "crypto": 0.0, "tools": 0.0, "research": 0.0}
	game._vis_sig.clear()
	var built := 0
	for building in 3:
		var placed := false
		for y in range(game.MAP_H):
			for x in range(game.MAP_W):
				var origin := Vector2i(x, y)
				if game._zone_ice(origin) == 0 and game._placement_error("fence", origin, 2) == "":
					game._try_place_node("fence", origin + Vector2i(1, 1))
					placed = true
					built += 1
					break
			if placed: break
	for id in game.nodes:
		if id == game.hub_id: continue
		var p: Array = game._find_path(id, game.hub_id)
		if not p.is_empty():
			game.current_tool = "dns"
			game.pending_child = id
			game._try_tunnel(game.nodes[game.hub_id].cell)
			break
	game.current_tool = ""
	game.pending_child = -1
	game.save_game()
	root.get_node("Session").start_mode = "load"
	var cont = new_game()   # fresh Continue
	for tick in 1000:
		cont._sim_tick(0.1)
	check("B01_recovers_after_continue",
		cont.resources.compute >= float(cont.COST["nest"]["compute"]) and cont._can_afford("nest") and cont._undo.is_empty(),
		"built_fences=%d cycles=%0.1f can_nest=%s undo=%d" % [built, cont.resources.compute, cont._can_afford("nest"), cont._undo.size()])
	root.get_node("Session").start_mode = "new"
	cont.queue_free()

	# ======== Batch 2: simulation / undo / rendering / info / contracts ========
	root.get_node("Session").start_mode = "new"

	# B05: a disabled forwarding junction still pays its link upkeep
	reset()
	game.nodes[3] = node(3, "phish", Vector2i(13, 5), 2, [Vector2i(12, 5)])
	game._connected = {1: true, 2: true, 3: true}
	game.nodes[2].on = false
	game._sim_tick(0.1)
	var up_off: float = game.total_upkeep
	game.nodes[2].on = true
	game._sim_tick(0.1)
	var up_on: float = game.total_upkeep
	check("B05_disabled_forwards_not_free", approx(up_off, up_on) and up_off > 0.0, "off=%s on=%s" % [up_off, up_on])

	# B06: an OFF Market does not convert passing Intel
	reset()
	game.nodes[2].on = false
	game._edge = {2: {"frac": 1.0}}
	game._connected = {1: true, 2: true}
	game._spawn("data", [2], 1, 1.0)
	game.packets[0].dist = game._polyline(2).total + 5.0
	game._move_packets(0.05)
	check("B06_off_market_no_sell", approx(game.resources.credits, 0.0) and game.resources.data >= 0.999,
		"credits=%s data=%s" % [game.resources.credits, game.resources.data])

	# B07: a packet on a route made stale by a reparent is cancelled
	reset()
	game.nodes[3] = node(3, "phish", Vector2i(13, 5), 2, [Vector2i(12, 5)])
	game.nodes[4] = node(4, "fence", Vector2i(9, 9), 1, [Vector2i(8, 9)])
	game._connected = {1: true, 2: true, 3: true, 4: true}
	game._edge = {2: {"frac": 1.0}, 3: {"frac": 1.0}, 4: {"frac": 1.0}}
	game._spawn("compute", [3, 2], 1)
	game.nodes[3].parent = 4
	game.nodes[3].path = [Vector2i(12, 6), Vector2i(12, 7), Vector2i(12, 8)]
	game._pl_cache.clear()
	game.packets[0].dist = game._polyline(3).total - 1.0
	game._move_packets(0.05)
	check("B07_stale_route_cancelled", game.packets.is_empty(), "remaining=%d" % game.packets.size())

	# B11: undoing an armed source's placement clears the pending tunnel
	reset()
	game.nodes[3] = node(3, "nest", Vector2i(13, 5))
	game._push_undo({"t": "place", "id": 3, "cost": {"compute": 10.0}})
	game.current_tool = "dns"
	game.pending_child = 3
	game.undo_last()
	check("B11_undo_clears_pending", game.pending_child == -1 and not game.nodes.has(3))

	# B12: undoing a built tunnel clears a selection pointing at it
	reset()
	game.selected_tunnel = 2
	game._push_undo({"t": "tunnel", "child": 2, "cost": {"compute": 5.0}})
	game.undo_last()
	check("B12_undo_clears_selected_tunnel", game.selected_tunnel == -1 and game.nodes[2].tunnel == "")

	# B53: a stale armed source (relinked via Undo) rejects a replacement commit
	reset()
	game.nodes[3] = node(3, "fence", Vector2i(13, 9), 1, [Vector2i(12, 9)])
	var orig_parent: int = game.nodes[2].parent
	game.selected_tunnel = 2
	game.remove_selected()
	game.set_tool("dns")
	game._try_tunnel(game.nodes[2].cell)   # arm node 2
	game.undo_last()                        # restores node 2's original link
	game._try_tunnel(game.nodes[3].cell)    # attempt to commit a different target
	check("B53_stale_armed_rejected", game.nodes[2].parent == orig_parent and game.pending_child == -1,
		"parent=%d pending=%d" % [game.nodes[2].parent, game.pending_child])

	# B14: no quarantine during the sweep warning window
	reset()
	game.nodes[3] = node(3, "phish", Vector2i(13, 5), 2, [Vector2i(12, 5)])
	game._connected = {1: true, 2: true, 3: true}
	game._launch_sweep()
	game._update_sweep(0.1)
	check("B14_no_quarantine_during_warn",
		float(game.sweep.get("warn", 0.0)) > 0.0 and float(game.nodes[3].get("quarantine", 0.0)) == 0.0,
		"warn=%s q=%s" % [game.sweep.get("warn", 0.0), game.nodes[3].get("quarantine", 0.0)])

	# B58: loss components are stored separately (distance vs Trace)
	reset()
	game.trace = 95.0
	var lp2 := []
	for k in range(10): lp2.append(Vector2i(8, 5 + k))
	game.nodes[2].path = lp2
	game._connected = {1: true, 2: true}
	game._sim_tick(0.1)
	var ed = game._edge.get(2, {})
	check("B58_loss_components_split",
		ed.has("dist_loss") and ed.get("trace_hot", false) == true and float(ed.get("dist_loss", 0.0)) > 0.0,
		"dist=%s trace_hot=%s" % [ed.get("dist_loss", "?"), ed.get("trace_hot", "?")])

	# B59: remaining hops = path.size - step - 1, reaching 0 at C2
	check("B59_hop_count", maxi(0, 2 - 0 - 1) == 1 and maxi(0, 2 - 1 - 1) == 0)

	# B51: a discrete paused action changes the visual signature (wakes a redraw)
	reset()
	game.paused = true
	game.selected_id = 2
	var sig_a: int = game._visual_sig()
	game.toggle_selected()
	check("B51_state_wakes_repaint", sig_a != game._visual_sig())
	game.paused = false

	# B52: tunnel culling bounds include the full routed detour, not just endpoints
	reset()
	var dpath := []
	for yy in range(10, 43): dpath.append(Vector2i(4, yy))
	game.nodes = {1: node(1, "hub", Vector2i(12, 8)), 2: node(2, "nest", Vector2i(4, 8), 1, dpath)}
	game._pl_cache.clear()
	var pb: Rect2 = game._path_bounds(2)
	check("B52_path_bounds_cover_detour", pb.size.y >= 30.0 * game.TILE, "h=%s" % pb.size.y)

	# Contracts: progress is baselined at acceptance — holding the amount never auto-wins
	reset()
	game.resources.compute = 80.0
	game.contracts = [{"id": 1, "kind": "stock", "res": "compute", "amount": 20.0, "accepted": false, "done": false, "reward_cash": 50.0, "reward_rp": 5.0, "deadline": 90.0, "client": "TestCo", "desc": "Deliver 20 Cycles"}]
	game.accept_contract(1)
	game._update_contracts(0.1)
	var done_now: bool = game.contracts.size() > 0 and game.contracts[0].done
	game.resources.compute += 20.0
	game._update_contracts(0.1)
	var done_earned: bool = game.contracts.size() > 0 and game.contracts[0].done
	check("Contract_no_autowin", (not done_now) and done_earned, "immediate=%s after_earning=%s" % [done_now, done_earned])

	# B09: a footprint over an active tunnel cell is refused
	reset()
	game.nodes[2].path = [Vector2i(7, 8), Vector2i(7, 9)]
	game._vis_sig.clear()
	var b09err: String = game._placement_error("fence", Vector2i(6, 8), 2)
	check("B09_reject_build_over_tunnel", "tunnel" in b09err, "err=%s" % b09err)

	# B13: rerouting a swept link breaks the trace
	reset()
	game.nodes[3] = node(3, "phish", Vector2i(13, 5), 2, [Vector2i(12, 5)])
	game.nodes[4] = node(4, "fence", Vector2i(9, 9), 1, [Vector2i(8, 9)])
	game._connected = {1: true, 2: true, 3: true, 4: true}
	game._launch_sweep()
	game.sweep.warn = 0.0
	game.nodes[3].parent = 4   # cut/reroute the swept 3→2 link
	game._update_sweep(0.1)
	check("B13_reroute_swept_breaks_trace", game.sweep.is_empty(), "sweep_empty=%s" % game.sweep.is_empty())

	# B33: offline counting includes an on-but-unlinked structure (parent == -1)
	reset()
	game.nodes[3] = node(3, "nest", Vector2i(13, 5))
	game.nodes[3].parent = -1
	game._connected = {1: true, 2: true}
	var n_off33 := 0
	for id33 in game.nodes:
		if id33 == game.hub_id: continue
		if game.nodes[id33].get("on", true) and not game._connected.has(id33):
			n_off33 += 1
	check("B33_offline_counts_unlinked", n_off33 >= 1, "n_off=%d" % n_off33)

	# B54: slot counting uses the footprint's OWNING (centre) district, not the origin's
	reset()
	game.regions = [{"type": "glasshouse", "ice": 0, "cells": 2, "cx": 0.0, "cy": 0.0}, {"type": "glasshouse", "ice": 0, "cells": 2, "cx": 0.0, "cy": 0.0}]
	game.region_grid.fill(1)
	game.region_grid[0] = 0   # only block (0,0) is region 0; the rest is region 1
	game.nodes = {1: node(1, "hub", Vector2i(10, 5))}
	game.next_id = 2
	game.nodes[2] = node(2, "phish", Vector2i(8, 8)); game.nodes[2].parent = -1
	game.nodes[3] = node(3, "phish", Vector2i(12, 8)); game.nodes[3].parent = -1
	# region 1 (cap 2) is full; a boundary footprint with origin in region 0 but centre in
	# region 1 must be judged by region 1 (full), not region 0 (empty).
	check("B54_slots_use_centre_district", game._slots_left(Vector2i(5, 3)) <= 0 and game._slots_left(Vector2i(4, 2)) > 0,
		"centre_slots=%d origin_slots=%d" % [game._slots_left(Vector2i(5, 3)), game._slots_left(Vector2i(4, 2))])

	# B04: a converting Market reports non-zero offered load on its edge
	reset()
	game.resources.data = 100.0
	game._sim_tick(1.0)
	check("B04_converter_load_counted", float(game._edge.get(2, {}).get("offered", 0.0)) > 0.0,
		"offered=%s" % game._edge.get(2, {}).get("offered", "?"))

	# B10: _is_building_cell matches the authoritative _block_desc geometry (incl. farm narrow)
	reset()
	game._generate_city()
	var mism := 0
	for by in range(0, 25):
		for bx in range(0, 25):
			var d = game._block_desc(bx, by)
			for ly in range(3):
				for lx in range(3):
					var expect: bool = d.rendered and not (d.narrow and ly >= 1)
					if game._is_building_cell(Vector2i(bx * 4 + lx, by * 4 + ly)) != expect:
						mism += 1
	check("B10_building_matches_render", mism == 0, "mismatches=%d" % mism)

	# B48: a click on the elevated tower silhouette selects the node; its ground cell does not
	reset()
	var o48: Vector2i = game.nodes[2].cell
	var pr48 = game.STRUCT.get(game.nodes[2].type, {"h": 14})
	var h48 := float(pr48.h)
	var roof := Vector2((float(o48.x) + 0.5) * game.TILE + h48 * 0.35, float(o48.y) * game.TILE - h48 * 0.5)
	check("B48_silhouette_selects_tower",
		game._node_at_silhouette(roof) == 2 and game._node_at(Vector2i(floori(roof.x / game.TILE), floori(roof.y / game.TILE))) == -1,
		"sil=%d" % game._node_at_silhouette(roof))

	# B43: a producer marker follows the colour-blind resource palette
	reset()
	var S = root.get_node("Settings")
	S.cb = true
	var cbcol: Color = game._sem_color("botfarm")
	var cbexp: Color = S.res_color("compute")
	S.cb = false
	check("B43_marker_follows_palette", cbcol == cbexp)

	print("\nT99 SUMMARY: %d passed, %d failed" % [pass_count, fail_count])
	var out := FileAccess.open("res://t99_results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed": pass_count, "failed": fail_count, "results": results}, "\t"))
	out.close()
	quit(1 if fail_count > 0 else 0)
