extends SceneTree
## Headless mechanics probe for scripts/botnet_proto.gd (v2, generated town). Calls the real simulation
## functions with explicit fixtures on a FIXED town seed. Not a usability test and not a balance verdict.

var game
var fails := 0
var results := []
const SEED := 7

func _initialize() -> void:
	_run.call_deferred()

func fresh(seed_v: int = SEED) -> void:
	if is_instance_valid(game):
		game.free()
	game = load("res://scripts/botnet_proto.gd").new()
	game.town_seed = seed_v
	root.add_child(game)
	game.set_process(false)
	game.ai_enabled = false        # AI botnets off unless a case turns them on

func check(name: String, cond: bool, info: Dictionary = {}) -> void:
	results.append({"case": name, "pass": cond, "observed": info})
	if not cond: fails += 1
	print(("PASS " if cond else "FAIL ") + name + " " + JSON.stringify(info))

func rigP() -> int: return int(game.rig[game.PLAYER])
func rigR() -> int: return int(game.rig[game.RIVAL])
func secondP() -> int: return game.cell_at(0, 1)
func secondR() -> int: return game.cell_at(game.GRID_COLS - 1, game.GRID_ROWS - 2)

func neutral_nb(i: int, avoid_nb_of: int = -1) -> int:   # a neutral neighbour of i (not adjacent to avoid_nb_of if possible)
	var fallback := -1
	for o in game.hosts[i].links:
		if int(game.hosts[o].owner) != game.NEUTRAL: continue
		if avoid_nb_of >= 0 and (game.hosts[avoid_nb_of].links as Array).has(o):
			if fallback < 0: fallback = int(o)
			continue
		return int(o)
	return fallback

func step(seconds: float, dt: float) -> void:
	var n := int(round(seconds / dt))
	for k in n: game._process(dt)

func _run() -> void:
	# 01 generation: a connected 6x6 town with gaps, three factions, rigs and a neutral downtown hub;
	#    different seeds give different towns
	var sizes := []; var all_connected := true; var all_linked := true
	for s in [1, 2, 3, 4, 5]:
		fresh(s)
		sizes.append(game.hosts.size())
		if game._components().size() != 1: all_connected = false
		for h in game.hosts:
			if (h.links as Array).is_empty(): all_linked = false
	fresh()
	var own := {0: 0, 1: 0, 2: 0, 3: 0}
	for h in game.hosts: own[int(h.owner)] += 1
	var distinct := {}
	for s in sizes: distinct[s] = true
	check("01_generation", game.hosts.size() <= 36 and game.hosts.size() >= 24 and own[1] == 2 and own[2] == 2 and own[3] == 2
		and int(game.rig[game.RIVAL2]) == game.cell_at(0, 5)
		and rigP() == game.cell_at(0, 0) and rigR() == game.cell_at(5, 5) and game.hub >= 0
		and int(game.hosts[game.hub].owner) == game.NEUTRAL and game._built_kinds(game.hub).size() == 2
		and int(game.hosts[game.hub].slots) == int(game.NODE_TYPES["erp"].slots) and str(game.hosts[game.hub].type) == "erp" and all_connected and all_linked and distinct.size() > 1,
		{"hosts": game.hosts.size(), "owners": own, "hub": game.hub, "sizes_by_seed": sizes, "all_connected": all_connected})

	# 02 routing stays inside the sender's own faction network
	fresh()
	var t2 := neutral_nb(rigP(), secondP())
	var r1: Array = game._route(secondP(), t2)
	var mid_ok := r1.size() >= 2 and int(r1[0]) == secondP() and int(r1[r1.size() - 1]) == t2
	for k in range(1, r1.size() - 1):
		if int(game.hosts[r1[k]].owner) != game.PLAYER: mid_ok = false
	var r3: Array = game._route(secondP(), rigR())
	check("02_routing", mid_ok and r3.is_empty(), {"player_route": r1, "target": t2, "unreachable_rival_rig": r3})

	# 03 link capacity: LINK_CAP packets per LINK_TIME per direction, the next one queues
	fresh()
	var b3: int = int(game.hosts[rigP()].links[0])
	var k: String = game._lkey(rigP(), b3)
	var e := []
	for n in 5:
		var t: float = game._link_entry(k, 0.0)
		game._reserve(k, t); e.append(t)
	var ok3 := absf(float(e[0])) < 0.001 and absf(float(e[1])) < 0.001 and absf(float(e[2]) - 1.0) < 0.01 and absf(float(e[3]) - 1.0) < 0.01 and absf(float(e[4]) - 2.0) < 0.01
	fresh()
	var b3b := neutral_nb(rigP(), secondP())
	for n in game.LINK_CAP: game._reserve(game._lkey(rigP(), b3b), 1.0)
	var f: Dictionary = game._schedule([secondP(), rigP(), b3b], 0.0, game.PLAYER, "bot")
	var expect_second: float = 1.0 + game.LINK_TIME + 0.0001
	var ok3b := absf(float(f.hops[0])) < 0.001 and absf(float(f.hops[1]) - expect_second) < 0.01 and absf(float(f.arrive_t) - (expect_second + game.LINK_TIME)) < 0.01
	var mid_pos: Vector2 = game._packet_pos(f, 1.5)
	check("03_link_capacity_queues", ok3 and ok3b and mid_pos == game.hosts[rigP()].pos,
		{"entries_same_instant": e, "two_hop_hops": f.hops, "arrive": f.arrive_t, "waiting_at_middle": mid_pos == game.hosts[rigP()].pos})

	# 04 arrivals resolve chronologically and a terminal Cash win freezes the board
	fresh()
	game.cash[game.PLAYER] = game.CASH_GOAL - 1.0
	var n8 := secondP()
	game.hosts[n8].bots = 0.5
	game.flights = [
		{"route": [neutral_nb(n8), n8], "hops": [0.0], "depart_t": 0.0, "arrive_t": 0.6, "owner": game.RIVAL, "kind": "bot", "amount": 1.0},
		{"route": [n8, rigP()], "hops": [0.0], "depart_t": 0.0, "arrive_t": 0.5, "owner": game.PLAYER, "kind": "cash", "amount": 1.0},
	]
	game._t = 1.0
	game._deliver_due()
	check("04_chronological_terminal_freeze", game.won and int(game.hosts[n8].owner) == game.PLAYER and float(game.hosts[n8].bots) == 0.5,
		{"won": game.won, "cause": game._end_cause, "node_owner_after": game.hosts[n8].owner, "node_bots": game.hosts[n8].bots})

	# 05 control stages switch slots off as bots fall; the first slot always works
	fresh()
	game._set_builds(n8, ["bot", "intel", "cash"])
	var st := []
	for b in [25.0, 15.0, 5.0]:
		game.hosts[n8].bots = b
		st.append([game._stage(n8), game._active_slots(n8), game._count(n8, "bot"), game._count(n8, "intel"), game._count(n8, "cash")])
	check("05_control_stages", st == [[0, 3, 1, 1, 1], [1, 2, 1, 1, 0], [2, 1, 1, 0, 0]], {"stages": st})

	# 06 a build job only progresses while you are INSIDE; the rival's always does
	fresh()
	game._start_job(n8, "cash")
	game._tick_jobs(100.0)
	var not_built: bool = game._built_kinds(n8).size() == 1
	game._inside = n8; game._enter_left = 0.0
	game._tick_jobs(game.BUILD_TIME + 0.01)
	var built: bool = game._built_kinds(n8) == ["bot", "cash"]
	game._start_job(secondR(), "cash"); game._tick_jobs(game.BUILD_TIME + 0.01)
	check("06_jobs_need_attention", not_built and built and game._built_kinds(secondR()) == ["bot", "cash"],
		{"player_without_inside": not_built, "player_inside": built, "rival_builds": game.hosts[secondR()].builds})

	# 07 capture flips a building to the attacker's faction and cancels its orders and jobs; neutral
	#    security never regrows past its own level, an owned building regrows to NODE_CAP
	fresh()
	var nn := neutral_nb(rigP())
	var sec_before: float = game.hosts[nn].sec
	game.hosts[nn].bots = sec_before - 3.0
	step(10.0, 0.1)
	var regrew_to_sec: bool = absf(float(game.hosts[nn].bots) - sec_before) < 0.01
	game.hosts[nn].bots = 0.5
	game._deliver({"route": [rigR(), nn], "hops": [0.0], "depart_t": 0.0, "arrive_t": 1.0, "owner": game.RIVAL, "kind": "bot", "amount": 1.0})
	var cap_r: bool = int(game.hosts[nn].owner) == game.RIVAL
	step(60.0, 0.1)
	var owned_regrows: bool = float(game.hosts[nn].bots) > sec_before + 1.0
	game.hosts[nn].bots = 0.5
	game._deliver({"route": [n8, nn], "hops": [0.0], "depart_t": 0.0, "arrive_t": 1.0, "owner": game.PLAYER, "kind": "bot", "amount": 1.0})
	check("07_capture_and_security_caps", regrew_to_sec and cap_r and owned_regrows and int(game.hosts[nn].owner) == game.PLAYER and (game.hosts[nn].job as Dictionary).is_empty() and int(game.hosts[nn].assign) == -1,
		{"neutral_regrew_to_security": regrew_to_sec, "after_rival": cap_r, "owned_regrows_past_security": owned_regrows, "after_player": game.hosts[nn].owner})

	# 08 an AI botnet cannot afford an attack from a cold start, so it builds an Intel harvester first, then
	#    concentrates several sources on one soft bordering building (watched over the first 25 s of play)
	fresh()
	game.ai_enabled = true
	var attacked_ever := false; var max_streams := 0
	for tick50 in 50:
		step(0.5, 0.1)
		var live_now := {}
		for i in game.hosts.size():
			var a := int(game.hosts[i].assign)
			if int(game.hosts[i].owner) == game.RIVAL and a >= 0 and bool(game.hosts[i].live) and int(game.hosts[a].owner) != game.RIVAL:
				live_now[a] = int(live_now.get(a, 0)) + 1
		for t in live_now.keys():
			attacked_ever = true
			max_streams = maxi(max_streams, int(live_now[t]))
	var built_intel := 0
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL: built_intel += game._count_all(i, "intel")
	var captured: bool = game._faction_nodes(game.RIVAL) > 2
	check("08_ai_builds_then_concentrates", built_intel >= 1 and attacked_ever and max_streams >= 2,
		{"harvesters": built_intel, "attacked": attacked_ever, "max_streams_on_one_target": max_streams, "captured_within_25s": captured, "nyx_intel": game.intel[game.RIVAL]})

	# 09 Cash packets travel home and bank at the rig; a market ON the rig banks directly
	fresh()
	game._set_builds(n8, ["bot", "cash"])
	step(10.0, 0.1)
	var c1: float = game.cash[game.PLAYER]
	fresh()
	game._set_builds(rigP(), ["bot", "bot", "cash"])
	step(10.0, 0.1)
	check("09_cash_travels_home", c1 >= 3.0 and c1 <= 4.0 and float(game.cash[game.PLAYER]) >= 3.0 and float(game.cash[game.PLAYER]) <= 4.0, {"via_link": c1, "on_rig": game.cash[game.PLAYER]})

	# 10 auto-supply to the rally point keeps a garrison and never overfills the rally
	fresh()
	game.rally = rigP()
	game._emit_due()
	var none_when_full: bool = game.flights.is_empty()
	game.hosts[rigP()].bots = 20.0
	game._emit_due()
	var one: bool = game.flights.size() == 1 and int(game.flights[0].route[0]) == n8
	game.hosts[n8].bots = game.RALLY_RESERVE + 0.5
	game.flights = []; game._next_depart[n8] = game._t
	game._emit_due()
	check("10_rally_garrison", none_when_full and one and game.flights.is_empty(), {"held_when_rally_full": none_when_full, "sent_when_room": one, "held_at_garrison": game.flights.is_empty()})

	# 11 frame-rate consistency: the same orders at 60 Hz and at 2 Hz give the same board (tolerance 1 bot)
	var boards := []
	var t11 := -1
	for dt in [1.0 / 60.0, 0.5]:
		fresh()
		t11 = neutral_nb(rigP())
		game.hosts[rigP()].assign = t11; game.hosts[rigP()].live = true; game.hosts[n8].assign = t11; game.hosts[n8].live = true
		step(20.0, dt)
		boards.append({"dt": dt, "target_bots": game.hosts[t11].bots, "owner": game.hosts[t11].owner, "intel": game.intel[game.PLAYER], "flights": game.flights.size()})
	var b_ok := absf(float(boards[0].target_bots) - float(boards[1].target_bots)) <= 1.0 and absf(float(boards[0].intel) - float(boards[1].intel)) <= 1.0
	check("11_frame_rate_consistency", b_ok, {"boards": boards})

	# 12 a building that streams out is softer: ONE stream drives it down to its garrison but no further;
	#    a second stream then captures it
	fresh()
	var tgt := neutral_nb(rigP())
	game.hosts[tgt].owner = game.RIVAL; game.hosts[tgt].bots = 12.0; game.hosts[tgt].assign = rigP(); game.hosts[tgt].live = true   # it attacks your rig
	game.hosts[rigP()].assign = tgt; game.hosts[rigP()].live = true                                                                 # one stream back
	game.intel[game.PLAYER] = 1000.0; game._set_builds(rigP(), ["bot", "bot", "intel", "intel"])
	game.intel[game.RIVAL] = 1000.0
	step(40.0, 0.1)
	var at_garrison: bool = int(game.hosts[tgt].owner) == game.RIVAL and float(game.hosts[tgt].bots) <= game.AI_RESERVE + 1.5
	var bots_mid: float = game.hosts[tgt].bots
	game.hosts[n8].assign = tgt; game.hosts[n8].live = true
	step(45.0, 0.1)
	check("12_attack_the_attacker", at_garrison and int(game.hosts[tgt].owner) == game.PLAYER, {"one_stream_bots": bots_mid, "owner_after_two": game.hosts[tgt].owner})

	# 14 two verbs: wiring is dormant and free; only LAUNCH starts flows; STOP keeps wires; Esc never
	#    touches wires; a wire needs a path through your own buildings
	fresh()
	var t14 := neutral_nb(rigP())
	game.sel = {n8: true}; game._wire(t14)
	var wired_dormant: bool = int(game.hosts[n8].assign) == t14 and not bool(game.hosts[n8].live) and game._inspect == t14 and game.sel.is_empty()
	step(3.0, 0.1)
	var nothing_moved: bool = game.flights.is_empty() and absf(float(game.intel[game.PLAYER]) - game.INTEL_START) < 0.001
	game.sel = {n8: true}; game._wire(rigR())
	var no_path: bool = int(game.hosts[n8].assign) == t14 and game._msg.begins_with("✖ No path")
	game._launch(t14)
	step(1.5, 0.1)
	var launched: bool = bool(game.hosts[n8].live) and game.flights.size() >= 1 and float(game.intel[game.PLAYER]) < game.INTEL_START
	game._halt(t14)
	var halted: bool = not bool(game.hosts[n8].live) and int(game.hosts[n8].assign) == t14
	game._clear_all()
	var esc_keeps: bool = int(game.hosts[n8].assign) == t14
	game._cancel_to(t14)
	check("14_connect_then_launch", wired_dormant and nothing_moved and no_path and launched and halted and esc_keeps and int(game.hosts[n8].assign) == -1,
		{"wired_dormant": wired_dormant, "nothing_moved": nothing_moved, "no_path_refused": no_path, "launched": launched, "halted_keeps_wire": halted, "esc_keeps_wire": esc_keeps})

	# 15 guards: a wire into your own building arms itself when it is damaged or attacked, stands down when full
	fresh()
	game.sel = {n8: true}; game._wire(rigP())
	game._auto_guards()
	var standby: bool = int(game.hosts[n8].assign) == rigP() and not bool(game.hosts[n8].live) and game._src_state(n8) == "guarding (standby)"
	game.hosts[rigP()].bots = 20.0; game._auto_guards()
	var armed_damaged: bool = bool(game.hosts[n8].live) and game._src_state(n8) == "defending"
	game.hosts[rigP()].bots = 30.0; game._auto_guards()
	var stood_down: bool = not bool(game.hosts[n8].live)
	var foe := neutral_nb(rigP())
	game.hosts[foe].owner = game.RIVAL; game.hosts[foe].bots = 30.0; game.hosts[foe].assign = rigP(); game.hosts[foe].live = true
	game._auto_guards()
	var armed_attacked: bool = bool(game.hosts[n8].live)
	check("15_guards_arm_themselves", standby and armed_damaged and stood_down and armed_attacked,
		{"standby_when_full": standby, "armed_when_damaged": armed_damaged, "stood_down_when_full": stood_down, "armed_when_attacked": armed_attacked})

	# 16 ownership changes: losing a building stands your wires down (kept); capturing one turns your
	#    attack flows into guards that top it up and stand down
	fresh()
	var t16 := neutral_nb(rigP())
	game.sel = {n8: true, rigP(): true}; game._wire(t16); game._launch(t16)
	game.hosts[t16].bots = 0.5
	game._deliver({"route": [rigP(), t16], "hops": [0.0], "depart_t": 0.0, "arrive_t": 1.0, "owner": game.PLAYER, "kind": "bot", "amount": 1.0})
	var became_guards: bool = int(game.hosts[t16].owner) == game.PLAYER and int(game.hosts[n8].assign) == t16 and bool(game.hosts[n8].live)
	game._auto_guards()
	var still_topping: bool = bool(game.hosts[n8].live)
	game.hosts[t16].bots = 30.0; game._auto_guards()
	var guards_stood_down: bool = not bool(game.hosts[n8].live) and int(game.hosts[n8].assign) == t16
	game.hosts[t16].bots = 20.0; game._auto_guards()
	game._capture(t16, game.RIVAL)
	var lost_stands_down: bool = int(game.hosts[n8].assign) == t16 and not bool(game.hosts[n8].live) and game._msg.begins_with("Lost")
	check("16_capture_and_loss_wire_status", became_guards and still_topping and guards_stood_down and lost_stands_down,
		{"flows_became_guards": became_guards, "topping_up_below_full": still_topping, "stood_down_at_full": guards_stood_down, "lost_stands_down_kept": lost_stands_down})

	# 17 slots: a card dropped on an EMPTY slot builds there in BUILD_TIME; on an OCCUPIED slot it replaces —
	#    the old building goes offline, DEMOLISH_TIME clears the slot, BUILD_TIME builds the new one
	fresh()
	var cannot_outside: bool = not game._can_drop(n8, 1, "cash")
	game._inside = n8; game._enter_left = 0.0
	var same_refused: bool = not game._can_drop(n8, 0, "bot")
	game._drop_build(n8, 1, "cash")
	var j1: Dictionary = game.hosts[n8].job
	var build_started: bool = not j1.is_empty() and str(j1.phase) == "build" and int(j1.slot) == 1 and absf(float(j1.left) - game.BUILD_TIME) < 0.01
	game._tick_jobs(game.BUILD_TIME + 0.01)
	var built_in_slot1: bool = str(game.hosts[n8].builds[1]) == "cash" and (game.hosts[n8].job as Dictionary).is_empty()
	game._drop_build(n8, 0, "intel")                      # replace the Bot farm in slot 1
	var j2: Dictionary = game.hosts[n8].job
	var replace_started: bool = not j2.is_empty() and str(j2.phase) == "demolish" and absf(float(j2.left) - game.DEMOLISH_TIME) < 0.01
	var offline_meanwhile: bool = game._count(n8, "bot") == 0
	game._tick_jobs(game.DEMOLISH_TIME + 0.01)
	var cleared_then_building: bool = str(game.hosts[n8].builds[0]) == "" and str(game.hosts[n8].job.phase) == "build" and absf(float(game.hosts[n8].job.left) - game.BUILD_TIME) < 0.01
	game._tick_jobs(game.BUILD_TIME + 0.01)
	var replaced: bool = str(game.hosts[n8].builds[0]) == "intel" and (game.hosts[n8].job as Dictionary).is_empty()
	check("17_slot_build_and_replace", cannot_outside and same_refused and build_started and built_in_slot1 and replace_started and offline_meanwhile and cleared_then_building and replaced,
		{"cannot_drop_from_outside": cannot_outside, "same_kind_refused": same_refused, "build_started": build_started, "built_in_slot": built_in_slot1,
		 "replace_started": replace_started, "offline_meanwhile": offline_meanwhile, "cleared_then_building": cleared_then_building, "replaced": replaced, "builds": game.hosts[n8].builds})

	# 18 building types: every building has a type whose slot count it uses; a harvester in a Database yields
	#    Intel ×2; a Bot farm in an ERP regenerates ×1.5; an IoT device has exactly one slot
	fresh()
	var types_ok := true; var counts := {}
	for h in game.hosts:
		var t: String = str(h.type)
		counts[t] = int(counts.get(t, 0)) + 1
		if not game.NODE_TYPES.has(t) or int(h.slots) != int(game.NODE_TYPES[t].slots) or (h.builds as Array).size() != int(h.slots): types_ok = false
	game.hosts[n8].type = "db"; game.hosts[n8].slots = 4; game._set_builds(n8, ["bot", "intel"])
	var intel_x2: bool = absf(game._intel_rate(game.PLAYER) - 2.0) < 0.001
	game.hosts[n8].type = "erp"; game.hosts[n8].slots = 5; game._set_builds(n8, ["bot"])
	var regen_x15: bool = absf(game._regen(n8) - 1.5) < 0.001
	game.hosts[n8].type = "iot"; game.hosts[n8].slots = 1; game._set_builds(n8, ["bot"])
	var iot_one: bool = game._free_slot(n8) == -1 and int(game.hosts[n8].slots) == 1
	check("18_building_types", types_ok and intel_x2 and regen_x15 and iot_one and counts.size() >= 4,
		{"types_consistent": types_ok, "db_intel_x2": intel_x2, "erp_regen_x15": regen_x15, "iot_single_slot": iot_one, "type_counts_seed7": counts})

	# 19 scanning: a quiet SCAN consumes bots, never wounds, raises no alarm, reveals at 10 + 5 per building
	#    and then stands down; an ATTACK on an unscanned building reveals as bots land but IS an alarm;
	#    a changed inside invalidates the knowledge
	fresh()
	var t19 := neutral_nb(rigP())
	var hidden_before: bool = not game._scanned(game.PLAYER, t19) and game._stage_line(t19).begins_with("unscanned")
	game.sel = {rigP(): true}; game._wire(t19); game._launch(t19, "scan")
	var bots0: float = game.hosts[t19].bots
	step(2.0, 0.1)
	var quiet: bool = not game._under_attack(t19) and game.flights.size() >= 1 and str(game.flights[0].kind) == "scan"
	var cost: float = game._scan_cost(t19)
	step(cost + 4.0, 0.1)
	var revealed: bool = game._scanned(game.PLAYER, t19) and not bool(game.hosts[rigP()].live) and int(game.hosts[rigP()].assign) == t19
	var unharmed: bool = absf(float(game.hosts[t19].bots) - bots0) < 0.01
	game.hosts[t19].builds[1] = "cash"            # its inside changed → the knowledge is stale
	var stale: bool = not game._scanned(game.PLAYER, t19)
	var t19b := neutral_nb(rigP(), -1)
	for o in game.hosts[rigP()].links:
		if int(game.hosts[o].owner) == game.NEUTRAL and int(o) != t19: t19b = int(o)
	var blind_ok := true
	if t19b >= 0 and t19b != t19:
		game.sel = {rigP(): true}; game._wire(t19b); game._launch(t19b, "attack")
		step(1.5, 0.1)
		var alarmed: bool = game._under_attack(t19b)
		step(3.0, 0.1)
		var wounded: bool = float(game.hosts[t19b].bots) < float(game.hosts[t19b].sec) - 0.5
		var progress_from_attack: bool = game._scan_progress(game.PLAYER, t19b) >= 2.0
		blind_ok = alarmed and wounded and progress_from_attack
	check("19_scan_quiet_or_attack_loud", hidden_before and quiet and revealed and unharmed and stale and blind_ok,
		{"hidden_before": hidden_before, "quiet_no_alarm": quiet, "revealed_and_stood_down": revealed, "unharmed": unharmed, "stale_after_change": stale, "blind_attack_alarms_wounds_reveals": blind_ok, "cost": cost})

	# 20 resources: a Credential harvester and a Research lab produce (× the building type) and raise their
	#    own limits; an Intel harvester raises the Intel limit; production switched off stops all of it
	fresh()
	var rp20 := rigP()
	game._set_builds(rp20, ["bot", "cred", "lab"])          # the rig is a Server: Credentials ×1, Research ×1.5
	var cap_c0: float = game._res_cap(game.PLAYER, "cred"); var cap_r0: float = game._res_cap(game.PLAYER, "lab")
	step(10.0, 0.1)
	var c10: float = game.creds[game.PLAYER]; var r10: float = game.research[game.PLAYER]
	var rates_ok: bool = absf(c10 - 5.0) < 0.3 and absf(r10 - 7.5) < 0.3
	var caps_ok: bool = absf(cap_c0 - 100.0) < 0.01 and absf(cap_r0 - 100.0) < 0.01
	game._set_builds(secondP(), ["bot", "intel", "intel"])
	var intel_cap_ok: bool = absf(float(game._intel_cap(game.PLAYER)) - 200.0) < 0.01
	game.hosts[rp20].prod_off = 5.0
	var off_rates: bool = game._cred_rate(game.PLAYER) == 0.0 and game._research_rate(game.PLAYER) == 0.0 and game._regen(rp20) == 0.0
	step(5.1, 0.1)
	var back_on: bool = game._cred_rate(game.PLAYER) > 0.0 and not game._prod_down(rp20)
	check("20_resources_and_limits", rates_ok and caps_ok and intel_cap_ok and off_rates and back_on,
		{"creds_10s": snapped(c10, 0.01), "research_10s": snapped(r10, 0.01), "cred_cap": cap_c0, "research_cap": cap_r0, "intel_cap_two_harvesters": game._intel_cap(game.PLAYER), "production_off_stops_all": off_rates, "wears_off": back_on})

	# 21 research: the head of the queue consumes its cost spread over its time, stalls (consuming nothing)
	#    without a resource, pauses without consuming, completes into the hand, and cards accumulate;
	#    an ANY card costs ×4 and takes ×2
	fresh()
	game.cash[game.PLAYER] = 100.0; game.creds[game.PLAYER] = 50.0; game.research[game.PLAYER] = 50.0
	game._queue_research(game.PLAYER, "stuff:linked")       # 20$ 30K 10R over 20 s
	step(10.0, 0.1)
	var half_spent: bool = absf(float(game.cash[game.PLAYER]) - 90.0) < 0.5 and absf(float(game.creds[game.PLAYER]) - 35.0) < 0.5 and absf(float(game.research[game.PLAYER]) - 45.0) < 0.5
	var not_yet: bool = game._held(game.PLAYER, "stuff:linked") == 0
	game._toggle_research(game.PLAYER)
	step(5.0, 0.1)
	var paused_holds: bool = absf(float(game.cash[game.PLAYER]) - 90.0) < 0.5 and absf(float(game.lab[game.PLAYER].progress) - 10.0) < 0.2
	game._toggle_research(game.PLAYER)
	step(10.5, 0.1)
	var done: bool = game._held(game.PLAYER, "stuff:linked") == 1 and (game.lab[game.PLAYER].queue as Array).is_empty()
	var spent: bool = absf(float(game.cash[game.PLAYER]) - 80.0) < 0.5 and absf(float(game.creds[game.PLAYER]) - 20.0) < 0.5
	game.creds[game.PLAYER] = 0.0
	game._queue_research(game.PLAYER, "stuff:linked")
	step(3.0, 0.1)
	var stalled: bool = str(game.lab[game.PLAYER].stall) == "creds" and float(game.lab[game.PLAYER].progress) < 0.01 and absf(float(game.cash[game.PLAYER]) - 80.0) < 0.5
	game.creds[game.PLAYER] = 50.0
	step(20.5, 0.1)
	var accumulates: bool = game._held(game.PLAYER, "stuff:linked") == 2
	var any_dearer: bool = absf(float(game._card_cost("stuff:any").cash) - 80.0) < 0.01 and absf(game._card_time("stuff:any") - 40.0) < 0.01
	check("21_research_queue", half_spent and not_yet and paused_holds and done and spent and stalled and accumulates and any_dearer,
		{"half_spent": half_spent, "paused_consumes_nothing": paused_holds, "completed": done, "cost_spent": spent, "stalls_without_creds": stalled, "accumulates": accumulates, "any_x4_cost_x2_time": any_dearer})

	# 22 single-host cards: LINKED needs a connection into the target, ANY does not; the effect scales with
	#    the type (DB resists credential attacks 50 % → half; PC weak to phishing → ×1.5; IoT resists phishing
	#    90 %); it never captures (a bot still has to arrive); the hit reveals and alarms; effects wear off
	fresh()
	var t22 := neutral_nb(rigP())
	game.cards[game.PLAYER] = {"stuff:linked": 1, "stuff:any": 1, "phish:linked": 2, "oneday:linked": 1}
	var refused: bool = not game._play_card(game.PLAYER, "stuff:linked", t22) and game._held(game.PLAYER, "stuff:linked") == 1   # a refused play costs nothing
	var b0: float = game.hosts[t22].bots
	game.hosts[t22].type = "db"
	var any_ok: bool = game._play_card(game.PLAYER, "stuff:any", t22)
	var in_flight: bool = game.flights.size() == 1 and str(game.flights[0].kind) == "card" and absf(float(game.hosts[t22].bots) - b0) < 0.01   # nothing lands before it arrives
	step(1.5, 0.1)
	var halved: bool = float(game.hosts[t22].bots) >= b0 * 0.5 - 0.01 and float(game.hosts[t22].bots) < b0 * 0.5 + 0.7   # halved on landing, ~0.5 s of regeneration since
	var revealed22: bool = game._scanned(game.PLAYER, t22) and game._under_attack(t22) and int(game.hosts[t22].owner) == game.NEUTRAL
	game.sel = {rigP(): true}; game._wire(t22)
	game.hosts[t22].type = "pc"
	var linked_ok: bool = game._play_card(game.PLAYER, "stuff:linked", t22)
	step(1.5, 0.1)
	var wiped: bool = float(game.hosts[t22].bots) < 0.7 and int(game.hosts[t22].owner) == game.NEUTRAL   # wiped on landing; ~0.5 s of regeneration since
	game._play_card(game.PLAYER, "phish:linked", t22)
	step(1.5, 0.1)
	var phished: bool = float(game.hosts[t22].prod_off) > 36.5 and float(game.hosts[t22].prod_off) <= 37.5 and game._regen(t22) == 0.0   # 37.5 s on a PC, landed ~0.5 s ago
	game._launch(t22, "attack")                              # one stream now takes it: no defenders, no regeneration
	step(4.0, 0.1)
	var taken_by_bots: bool = int(game.hosts[t22].owner) == game.PLAYER and float(game.hosts[t22].prod_off) == 0.0
	var t22b := neutral_nb(secondP(), rigP())
	game.hosts[t22b].type = "iot"
	game.sel = {secondP(): true}; game._wire(t22b)
	game._play_card(game.PLAYER, "phish:linked", t22b)
	game._play_card(game.PLAYER, "oneday:linked", t22b)
	var hops22: int = game._route(secondP(), t22b).size() - 1
	step(float(hops22) * 1.3 + 0.6, 0.1)
	var iot_resists: bool = game._prod_down(t22b) and float(game.hosts[t22b].prod_off) <= 2.5   # 2.5 s on an IoT device
	var cut: bool = float(game.hosts[t22b].route_off) > 23.0 and float(game.hosts[t22b].route_off) <= 25.0   # 25 s: IoT is weak to exploits ×1.25
	step(3.0, 0.1)
	var phish_over: bool = not game._prod_down(t22b) and game._routing_down(t22b)
	step(23.0, 0.1)
	var cut_over: bool = not game._routing_down(t22b)
	var spent22: bool = game._hand_size(game.PLAYER) == 0
	check("22_single_cards", refused and any_ok and in_flight and halved and revealed22 and linked_ok and wiped and phished and taken_by_bots and iot_resists and cut and phish_over and cut_over and spent22,
		{"linked_refused_without_connection": refused, "any_plays_anywhere": any_ok, "travels_as_a_card_packet": in_flight, "db_halves_credential": halved, "hit_reveals_alarms_no_capture": revealed22, "pc_wiped": wiped, "pc_phish_x1_5": phished, "then_one_stream_takes_it": taken_by_bots, "iot_phish_2_5s": iot_resists, "iot_routing_cut_25s": cut, "effects_wear_off": phish_over and cut_over, "hand_spent": spent22})

	# 23 worms: the chain spreads along the streets with falling odds (jump 1: 100 %, then −25 % per jump),
	#    never onto the caster's own buildings, each building once, at most 4 jumps, captures nothing,
	#    reveals every building it hit, and draws one jump per spread
	fresh()
	game.rng.seed = 12345
	var t23 := neutral_nb(rigP())
	game.cards[game.PLAYER] = {"credworm:any": 1}
	var before := []
	for h in game.hosts: before.append([int(h.owner), float(h.bots)])
	game._play_card(game.PLAYER, "credworm:any", t23)
	step(1.5, 0.1)
	var hit := []
	for i in game.hosts.size():
		if float(game.hosts[i].bots) < float(before[i][1]) - 0.01: hit.append(i)
	var owners_same := true
	for i in game.hosts.size():
		if int(game.hosts[i].owner) != int(before[i][0]): owners_same = false
	var mine_untouched := true
	for i in game.hosts.size():
		if int(before[i][0]) == game.PLAYER and float(game.hosts[i].bots) != float(before[i][1]): mine_untouched = false
	var depth := {t23: 0}; var q := [t23]; var head := 0; var maxd := 0   # the hit set must be a chain from t23
	while head < q.size():
		var c: int = q[head]; head += 1
		for o in game.hosts[c].links:
			if hit.has(int(o)) and not depth.has(int(o)): depth[int(o)] = int(depth[c]) + 1; q.append(int(o)); maxd = maxi(maxd, int(depth[int(o)]))
	var chain_ok: bool = hit.has(t23) and depth.size() == hit.size() and maxd <= 4
	var revealed23 := true
	for i in hit:
		if not game._scanned(game.PLAYER, int(i)): revealed23 = false
	var drawn: bool = game._worms.size() == hit.size() - 1
	var first_jump_certain := true   # every non-own neighbour of t23 was hit
	for o in game.hosts[t23].links:
		if int(game.hosts[o].owner) != game.PLAYER and not hit.has(int(o)): first_jump_certain = false
	check("23_worm_chain", hit.size() >= 2 and owners_same and mine_untouched and chain_ok and revealed23 and drawn and first_jump_certain,
		{"hit": hit.size(), "max_jump": maxd, "no_capture": owners_same, "own_untouched": mine_untouched, "is_a_chain": chain_ok, "revealed": revealed23, "jumps_drawn": drawn, "first_jump_certain": first_jump_certain})

	# 24 routing cut: a building whose routing is cut relays nothing (a flow through it pauses, its wire is
	#    kept), emits nothing itself, still receives, and recovers when the cut wears off
	fresh()
	var rp24 := rigP(); var sp24 := secondP()
	var t24 := neutral_nb(sp24, rp24)
	game._mark_scanned(game.PLAYER, t24)
	game.sel = {rp24: true}; game._wire(t24); game._launch(t24, "attack")
	var via_sp: bool = game._route(rp24, t24).size() == 3 and int(game._route(rp24, t24)[1]) == sp24
	step(2.0, 0.1)
	game.hosts[sp24].route_off = 10.0
	var no_relay: bool = game._route(rp24, t24).is_empty()
	step(0.5, 0.1)
	var flow_paused_wire_kept: bool = not bool(game.hosts[rp24].live) and int(game.hosts[rp24].assign) == t24
	game.sel = {sp24: true}; game._wire(t24); game._launch(t24, "attack")
	var n0 := 0
	for fl in game.flights:
		if int((fl.route as Array)[0]) == sp24: n0 += 1
	step(3.0, 0.1)
	var n1 := 0
	for fl in game.flights:
		if int((fl.route as Array)[0]) == sp24: n1 += 1
	var no_emit: bool = n1 == n0 and game._src_state(sp24) == "routing cut"
	game.hosts[sp24].bots = 20.0
	game.sel = {rp24: true}; game._wire(sp24)   # a guard into it: it still RECEIVES
	step(3.0, 0.1)
	var receives: bool = float(game.hosts[sp24].bots) > 20.5 or game._incoming(sp24, game.PLAYER) > 0.0
	step(5.0, 0.1)
	var recovered: bool = not game._routing_down(sp24) and game._route(rp24, t24).size() == 3
	check("24_routing_cut", via_sp and no_relay and flow_paused_wire_kept and no_emit and receives and recovered,
		{"route_via_second": via_sp, "relays_nothing": no_relay, "flow_paused_wire_kept": flow_paused_wire_kept, "emits_nothing": no_emit, "still_receives": receives, "recovers": recovered})

	# 25 the AI botnets run the card economy: on seed 7 with both AIs on, within 300 s each builds a
	#    Credential harvester and a Research lab, researches, and at least one plays a card
	fresh(); game.ai_enabled = true
	var econ := {2: false, 3: false}; var researched := {2: false, 3: false}; var played := 0; var t25 := 0.0
	while t25 < 300.0 and not game.won and not game.lost:
		game._process(0.1); t25 += 0.1
		for fac in game.AIS:
			if game._kind_total(fac, "cred") > 0 and game._kind_total(fac, "lab") > 0: econ[fac] = true
			if game._hand_size(fac) > 0 or not (game.lab[fac].queue as Array).is_empty(): researched[fac] = true
		played = int(game.card_plays[2]) + int(game.card_plays[3])
	check("25_ai_uses_cards", econ[2] and econ[3] and (researched[2] or researched[3]) and played >= 1,
		{"economy_built": econ, "researched": researched, "cards_played_by_ais": played, "t": snapped(t25, 0.1), "nyx_cash": int(game.cash[2]), "kraken_cash": int(game.cash[3])})

	# 13 pacing readings (NOT balance verdicts): the rival alone, and a scripted greedy player vs the rival
	var alone := _run_match(SEED, false, 600.0)
	var greedy7 := _run_match(SEED, true, 600.0)
	var greedy11 := _run_match(11, true, 600.0)
	check("13_pacing_readings", true, {"rival_alone": alone, "greedy_seed7": greedy7, "greedy_seed11": greedy11})

	var out := FileAccess.open("res://results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"cases": results, "fails": fails}, "\t")); out.close()
	print("PROBE_COMPLETE cases=%d fails=%d" % [results.size(), fails])
	quit(1 if fails > 0 else 0)


# a full match at 10 Hz. scripted=false: you do nothing. scripted=true: a greedy player with perfect
# attention — builds Intel+Cash at home and Bot farms on the frontier, attacks the softest neighbour
# with enough streams to beat its regeneration, keeps a garrison, rallies nothing.
func _run_match(seed_v: int, scripted: bool, max_s: float) -> Dictionary:
	fresh(seed_v)
	game.ai_enabled = true
	var wall0 := Time.get_ticks_msec()
	var dt := 0.1
	var t := 0.0
	var think := 0.0
	var first_capture := -1.0
	while t < max_s and not game.won and not game.lost:
		game._process(dt); t += dt; think += dt
		if scripted and think >= 1.0:
			think = 0.0
			_greedy_player()
		if first_capture < 0.0 and game._player_nodes() > 2: first_capture = t
	print("match seed %d scripted=%s took %d ms wall for %.0f s of game" % [seed_v, str(scripted), Time.get_ticks_msec() - wall0, t])
	return {"outcome": ("WIN" if game.won else ("LOSS" if game.lost else "timeout")), "cause": game._end_cause, "t": snapped(t, 0.1),
		"player_nodes": game._player_nodes(), "rival_nodes": game._faction_nodes(game.RIVAL),
		"cash": [int(game.cash[game.PLAYER]), int(game.cash[game.RIVAL])], "first_capture_t": snapped(first_capture, 0.1), "intel": int(game.intel[game.PLAYER]), "kraken_nodes": game._faction_nodes(game.RIVAL2), "cash_kraken": int(game.cash[game.RIVAL2]),
		"cards_played": [int(game.card_plays[1]), int(game.card_plays[2]), int(game.card_plays[3])]}


func _greedy_player() -> void:
	var mine := []
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.PLAYER: mine.append(i)
	for i in mine:   # a wire whose target is now ours has done its job (its guards stand down on their own)
		var a := int(game.hosts[i].assign)
		if a >= 0 and int(game.hosts[a].owner) == game.PLAYER: game.hosts[i].assign = -1; game.hosts[i].live = false
	# attention: stay inside the building with a running job; else start one somewhere
	if game._inside >= 0 and not (game.hosts[game._inside].job as Dictionary).is_empty(): return
	game._inside = -1
	var intel_n := 0; var cash_n := 0
	for i in mine: intel_n += game._count_all(i, "intel"); cash_n += game._count_all(i, "cash")
	for i in mine:
		if (game.hosts[i].builds as Array).size() >= int(game.hosts[i].slots) or not (game.hosts[i].job as Dictionary).is_empty(): continue
		var frontier := false
		for p in game.hosts[i].links:
			if int(game.hosts[p].owner) != game.PLAYER: frontier = true
		var kind := "cash"
		if intel_n < 1: kind = "intel"
		elif cash_n == 0: kind = "cash"
		elif intel_n < 2: kind = "intel"
		elif frontier and game._count_all(i, "bot") < 2: kind = "bot"
		elif cash_n <= intel_n: kind = "cash"
		else: kind = "intel"
		if game._start_job(i, kind):
			game._inside = i; game._enter_left = game.ENTER_TIME
			break
	# one attack at a time, concentrated
	var active := false
	for i in mine:
		if int(game.hosts[i].assign) >= 0 and bool(game.hosts[i].live): active = true
	if active: return
	var cands := []
	for i in mine:
		for p in game.hosts[i].links:
			if int(game.hosts[p].owner) != game.PLAYER and not cands.has(p): cands.append(p)
	if cands.is_empty(): return
	var pick := -1; var best := INF
	for c in cands:
		var score: float = float(game.hosts[c].bots) - 3.0 * float(game.hosts[c].value)
		if score < best: best = score; pick = int(c)
	var regen: float = float(game._count(pick, "bot")) * game.PROD_RATE
	var need: int = maxi(2, floori(regen * game.DEFEND_POWER / (game.ATTACK_POWER * game.SEND_RATE)) + 2)
	var srcs := []
	for i in mine:
		if float(game.hosts[i].bots) < 12.0: continue
		var rt: Array = game._route(i, pick)
		if not rt.is_empty(): srcs.append([rt.size(), i])
	srcs.sort_custom(func(a, b): return a[0] < b[0])
	if srcs.size() < 2: return
	for s in srcs.slice(0, mini(need, srcs.size())):
		game.hosts[int(s[1])].assign = pick; game.hosts[int(s[1])].live = true
