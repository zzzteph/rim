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
func secondR2() -> int: return game.cell_at(0, game.GRID_ROWS - 2)
func fill_ai(fac: int) -> void:   # fill every slot so the AI never stops to build — isolates its map decisions
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == fac:
			var full := []
			for k in int(game.hosts[i].slots): full.append("bot")
			game._set_builds(i, full)

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

	# 04 arrivals resolve chronologically and the terminal (last botnet standing) freezes the board mid-delivery
	fresh()
	var n8 := secondP()      # a player building reused by later fixtures
	var rlast := secondR()   # make RIVAL and KRAKEN hold one building each, the player everything else
	var klast := secondR2()
	for i in game.hosts.size():
		if i == rlast or i == klast: continue
		if int(game.hosts[i].owner) != game.PLAYER: game.hosts[i].owner = game.PLAYER; game.hosts[i].bots = game.NODE_CAP
	game.hosts[rlast].owner = game.RIVAL; game.hosts[rlast].bots = 0.5
	game.hosts[klast].owner = game.RIVAL2; game.hosts[klast].bots = 0.5
	var nr := neutral_nb(rlast); if nr < 0: nr = int(game.hosts[rlast].links[0])
	var nk := neutral_nb(klast); if nk < 0: nk = int(game.hosts[klast].links[0])
	game.flights = [
		{"route": [nk, klast], "hops": [0.0], "depart_t": 0.0, "arrive_t": 0.7, "owner": game.PLAYER, "kind": "bot", "amount": 1.0},
		{"route": [nr, rlast], "hops": [0.0], "depart_t": 0.0, "arrive_t": 0.5, "owner": game.PLAYER, "kind": "bot", "amount": 1.0},
	]
	game._t = 1.0
	game._deliver_due()
	# the 0.5 arrival takes RIVAL's last building; KRAKEN still stands, so NOT yet won; the 0.7 arrival then takes KRAKEN's and wins, freezing
	check("04_chronological_terminal_freeze", game.won and int(game.hosts[rlast].owner) == game.PLAYER and int(game.hosts[klast].owner) == game.PLAYER,
		{"won": game.won, "cause": game._end_cause, "rival_last": game.hosts[rlast].owner, "kraken_last": game.hosts[klast].owner})
	fresh()   # later cases assume a fresh town

	# 05 control stages switch slots off as bots fall; the first slot always works
	fresh()
	game._set_builds(n8, ["bot", "intel", "cash"])
	var st := []
	for b in [25.0, 15.0, 5.0]:
		game.hosts[n8].bots = b
		st.append([game._stage(n8), game._active_slots(n8), game._count(n8, "bot"), game._count(n8, "intel"), game._count(n8, "cash")])
	check("05_control_stages", st == [[0, 3, 1, 1, 1], [1, 2, 1, 1, 0], [2, 1, 1, 0, 0]], {"stages": st})

	# 06 build jobs run on their own for everyone: nobody has to stay with them, several can run in one
	#    building at once, and each one is paid in Intel when it starts
	fresh()
	game.hosts[n8].slots = 3; game._set_builds(n8, ["bot"])
	var i06 := float(game.intel[game.PLAYER])
	game._start_job(n8, "cash")                       # slot 1 (slot 0 holds the starting Bot farm)
	var paid: bool = absf(float(game.intel[game.PLAYER]) - (i06 - game.BUILD_COST_INTEL)) < 0.01
	var second_too: bool = game._start_job(n8, "intel")   # a second job in the same building, another slot
	var two_running: bool = (game.hosts[n8].jobs as Dictionary).size() == 2
	game._tick_jobs(game.BUILD_TIME + 0.01)           # nobody "inside": they progress anyway
	var both_built: bool = game._built_kinds(n8) == ["bot", "cash", "intel"] and (game.hosts[n8].jobs as Dictionary).is_empty()
	var r6 := secondR()
	game._start_job(r6, "cash"); game._tick_jobs(game.BUILD_TIME + 0.01)
	var ai_too: bool = game._built_kinds(r6) == ["bot", "cash"]   # the AI's jobs run unattended as well
	game.intel[game.PLAYER] = game.BUILD_COST_INTEL - 1.0
	var broke: bool = not game._start_job(rigP(), "cash")          # no Intel, no job
	check("06_jobs_run_unattended_cost_intel", paid and second_too and two_running and both_built and ai_too and broke,
		{"intel_paid_up_front": paid, "two_jobs_at_once": two_running, "both_built_unattended": both_built, "ai_unattended": ai_too, "refused_without_intel": broke})

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
	var empty_after: bool = game._built_kinds(nn).is_empty()      # a captured building is empty inside
	game._set_builds(nn, ["bot"])                                   # the new owner builds a farm; only then does it regrow
	step(60.0, 0.1)
	var owned_regrows: bool = float(game.hosts[nn].bots) > sec_before + 1.0
	game.hosts[nn].bots = 0.5
	game._deliver({"route": [n8, nn], "hops": [0.0], "depart_t": 0.0, "arrive_t": 1.0, "owner": game.PLAYER, "kind": "bot", "amount": 1.0})
	check("07_capture_and_security_caps", regrew_to_sec and cap_r and empty_after and owned_regrows and int(game.hosts[nn].owner) == game.PLAYER and (game.hosts[nn].jobs as Dictionary).is_empty() and int(game.hosts[nn].assign) == -1,
		{"neutral_regrew_to_security": regrew_to_sec, "after_rival": cap_r, "empty_after_capture": empty_after, "owned_regrows_past_security": owned_regrows, "after_player": game.hosts[nn].owner})

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

	# 10 a captured building is empty inside: whatever the loser had built is gone, jobs included
	fresh()
	var cap10 := neutral_nb(rigP())
	game.hosts[cap10].owner = game.RIVAL; game.hosts[cap10].slots = 3; game._set_builds(cap10, ["bot", "cash", "intel"])
	game.intel[game.RIVAL] = 100.0; game._start_job(cap10, "lab", 0)   # a replace in progress, too
	game.hosts[cap10].bots = -2.0
	game._capture(cap10, game.PLAYER)
	var wiped10: bool = game._built_kinds(cap10).is_empty() and (game.hosts[cap10].jobs as Dictionary).is_empty() and int(game.hosts[cap10].owner) == game.PLAYER
	check("10_capture_empties_the_inside", wiped10, {"builds_after_capture": game.hosts[cap10].builds, "jobs_after_capture": game.hosts[cap10].jobs})

	# 11 frame-rate consistency: the same orders at 60 Hz and at 2 Hz give the same board (tolerance 1 bot)
	var boards := []
	var t11 := -1
	for dt in [1.0 / 60.0, 0.5]:
		fresh()
		t11 = neutral_nb(rigP()); game.hosts[t11].sec = 28.0; game.hosts[t11].bots = 28.0   # worn down, not flipped: a flip is a discontinuity
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
	var nothing_moved: bool = game.flights.is_empty() and float(game.intel[game.PLAYER]) >= game.INTEL_START   # nothing left, nothing spent
	game.sel = {n8: true}; game._wire(rigR())
	var no_path: bool = int(game.hosts[n8].assign) == t14 and game._msg.begins_with("✖ No path")
	var i14: float = game.intel[game.PLAYER]
	game._launch(t14)
	step(1.5, 0.1)
	var launched: bool = bool(game.hosts[n8].live) and game.flights.size() >= 1 and float(game.intel[game.PLAYER]) < i14 + 1.5   # at least one bot paid for, against the 1.5 s trickle
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
	#    the old building goes offline, DEMOLISH_TIME clears the slot, BUILD_TIME builds the new one.
	#    No "entering": the board is open as soon as the building is yours; a foreign building takes no drop
	fresh()
	var cannot_foreign: bool = not game._can_drop(secondR(), 1, "cash")
	var same_refused: bool = not game._can_drop(n8, 0, "bot")
	game._drop_build(n8, 1, "cash")
	var j1: Dictionary = (game.hosts[n8].jobs as Dictionary).get(1, {})
	var build_started: bool = not j1.is_empty() and str(j1.phase) == "build" and int(j1.slot) == 1 and absf(float(j1.left) - game.BUILD_TIME) < 0.01
	game._tick_jobs(game.BUILD_TIME + 0.01)
	var built_in_slot1: bool = str(game.hosts[n8].builds[1]) == "cash" and (game.hosts[n8].jobs as Dictionary).is_empty()
	game._drop_build(n8, 0, "intel")                      # replace the Bot farm in slot 1
	var j2: Dictionary = (game.hosts[n8].jobs as Dictionary).get(0, {})
	var replace_started: bool = not j2.is_empty() and str(j2.phase) == "demolish" and absf(float(j2.left) - game.DEMOLISH_TIME) < 0.01
	var offline_meanwhile: bool = game._count(n8, "bot") == 0
	game._tick_jobs(game.DEMOLISH_TIME + 0.01)
	var j2b: Dictionary = (game.hosts[n8].jobs as Dictionary).get(0, {})
	var cleared_then_building: bool = str(game.hosts[n8].builds[0]) == "" and str(j2b.get("phase", "")) == "build" and absf(float(j2b.get("left", 0.0)) - game.BUILD_TIME) < 0.01
	game._tick_jobs(game.BUILD_TIME + 0.01)
	var replaced: bool = str(game.hosts[n8].builds[0]) == "intel" and (game.hosts[n8].jobs as Dictionary).is_empty()
	check("17_slot_build_and_replace", cannot_foreign and same_refused and build_started and built_in_slot1 and replace_started and offline_meanwhile and cleared_then_building and replaced,
		{"cannot_drop_on_foreign": cannot_foreign, "same_kind_refused": same_refused, "build_started": build_started, "built_in_slot": built_in_slot1,
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
	var intel_x2: bool = absf(game._intel_rate(game.PLAYER) - game.RIG_INTEL - 2.0) < 0.001   # the rig's own trickle aside
	game.hosts[n8].type = "erp"; game.hosts[n8].slots = 5; game._set_builds(n8, ["bot"])
	var regen_x15: bool = absf(game._regen(n8) - 1.5) < 0.001
	game.hosts[n8].type = "iot"; game.hosts[n8].slots = 1; game._set_builds(n8, ["bot"])
	var iot_one: bool = game._free_slot(n8) == -1 and int(game.hosts[n8].slots) == 1
	check("18_building_types", types_ok and intel_x2 and regen_x15 and iot_one and counts.size() >= 4,
		{"types_consistent": types_ok, "db_intel_x2": intel_x2, "erp_regen_x15": regen_x15, "iot_single_slot": iot_one, "type_counts_seed7": counts})

	# 19 scanning: a quiet SCAN consumes bots, never wounds, raises no alarm, reveals on the first scout to land (no quota)
	#    and then stands down; an ATTACK on an unscanned building reveals as bots land but IS an alarm;
	#    a changed inside invalidates the knowledge
	fresh()
	var t19 := neutral_nb(rigP())
	var hidden_before: bool = not game._scanned(game.PLAYER, t19) and game._stage_line(t19).begins_with("unscanned")
	game.sel = {rigP(): true}; game._wire(t19); game._launch(t19, "scan")
	var bots0: float = game.hosts[t19].bots
	step(0.5, 0.1)   # the scout is still on the street
	var quiet: bool = not game._under_attack(t19) and game.flights.size() >= 1 and str(game.flights[0].kind) == "scan"
	var cost: float = game._scan_cost(t19)
	step(cost + 5.5, 0.1)
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
		var progress_from_attack: bool = game._scan_progress(game.PLAYER, t19b) >= 1.0
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
	game._queue_research(game.PLAYER, "stuff:linked")       # 20$ 35K 10R over 25 s
	step(10.0, 0.1)
	var half_spent: bool = absf(float(game.cash[game.PLAYER]) - 92.0) < 0.5 and absf(float(game.creds[game.PLAYER]) - 36.0) < 0.5 and absf(float(game.research[game.PLAYER]) - 46.0) < 0.5   # 0.4 of it consumed
	var not_yet: bool = game._held(game.PLAYER, "stuff:linked") == 0
	game._toggle_research(game.PLAYER)
	step(5.0, 0.1)
	var paused_holds: bool = absf(float(game.cash[game.PLAYER]) - 92.0) < 0.5 and absf(float(game.lab[game.PLAYER].progress) - 10.0) < 0.2
	game._toggle_research(game.PLAYER)
	step(15.5, 0.1)
	var done: bool = game._held(game.PLAYER, "stuff:linked") == 1 and (game.lab[game.PLAYER].queue as Array).is_empty()
	var spent: bool = absf(float(game.cash[game.PLAYER]) - 80.0) < 0.5 and absf(float(game.creds[game.PLAYER]) - 15.0) < 0.5
	game.creds[game.PLAYER] = 0.0
	game._queue_research(game.PLAYER, "stuff:linked")
	step(3.0, 0.1)
	var stalled: bool = str(game.lab[game.PLAYER].stall) == "creds" and float(game.lab[game.PLAYER].progress) < 0.01 and absf(float(game.cash[game.PLAYER]) - 80.0) < 0.5
	game.creds[game.PLAYER] = 50.0
	step(25.5, 0.1)
	var accumulates: bool = game._held(game.PLAYER, "stuff:linked") == 2
	check("21_research_queue", half_spent and not_yet and paused_holds and done and spent and stalled and accumulates,
		{"half_spent": half_spent, "paused_consumes_nothing": paused_holds, "completed": done, "cost_spent": spent, "stalls_without_creds": stalled, "accumulates": accumulates})

	# 22 single cards: the defender ladder (1-day −25 %, phishing −50 %, stuffing −100 %), every card needs a
	#    connection into its target and travels there as a packet; resistances scale the hit; nothing is captured
	fresh()
	var t22 := -1
	for o in game.hosts[rigP()].links:
		if int(game.hosts[o].owner) == game.NEUTRAL: t22 = int(o); break
	game._set_builds(t22, [])   # no regeneration, so a card's effect is exact
	game.cards[game.PLAYER] = {"stuff:linked": 1}
	var refused: bool = not game._play_card(game.PLAYER, "stuff:linked", t22) and game._held(game.PLAYER, "stuff:linked") == 1   # no connection → refused, costs nothing
	game.sel = {rigP(): true}; game._wire(t22); game._clear_all()   # now connected: every card below can travel
	# 1-day −25 % on a Server (oneday resist 0)
	game.hosts[t22].type = "server"; game.hosts[t22].bots = 20.0; game.cards[game.PLAYER] = {"oneday:linked": 1}
	game._play_card(game.PLAYER, "oneday:linked", t22)
	var in_flight: bool = game.flights.size() == 1 and str(game.flights[0].kind) == "card" and absf(float(game.hosts[t22].bots) - 20.0) < 0.01
	step(4.0, 0.1)
	var oneday25: bool = absf(float(game.hosts[t22].bots) - 15.0) < 0.2
	var revealed22: bool = game._scanned(game.PLAYER, t22) and game._under_attack(t22) and int(game.hosts[t22].owner) == game.NEUTRAL   # revealed, alarmed, not captured
	# phishing −50 %, on a PC which is weak to phishing ×1.5 → −75 %
	game.hosts[t22].type = "pc"; game.hosts[t22].bots = 20.0; game.cards[game.PLAYER] = {"phish:linked": 1}
	game._play_card(game.PLAYER, "phish:linked", t22); step(4.0, 0.1)
	var pc_phish: bool = absf(float(game.hosts[t22].bots) - 5.0) < 0.2
	# stuffing −100 % wipes a Web (cred resist 0)
	game.hosts[t22].type = "web"; game.hosts[t22].bots = 20.0; game.cards[game.PLAYER] = {"stuff:linked": 1}
	game._play_card(game.PLAYER, "stuff:linked", t22); step(4.0, 0.1)
	var wiped: bool = float(game.hosts[t22].bots) < 0.01
	# a DB resists credential attacks 50 % → stuffing only halves
	game.hosts[t22].type = "db"; game.hosts[t22].bots = 20.0; game.cards[game.PLAYER] = {"stuff:linked": 1}
	game._play_card(game.PLAYER, "stuff:linked", t22); step(4.0, 0.1)
	var db_half: bool = absf(float(game.hosts[t22].bots) - 10.0) < 0.2
	# an IoT resists phishing 90 % → barely dented
	game.hosts[t22].type = "iot"; game.hosts[t22].bots = 20.0; game.cards[game.PLAYER] = {"phish:linked": 1}
	game._play_card(game.PLAYER, "phish:linked", t22); step(4.0, 0.1)
	var iot_resist: bool = absf(float(game.hosts[t22].bots) - 19.0) < 0.3   # 20 − 20×0.5×0.1
	# 0-day on a DB (zeroday resist 0): halves AND cuts routing; the routing cut wears off
	game.hosts[t22].type = "db"; game.hosts[t22].bots = 20.0; game.cards[game.PLAYER] = {"zeroday:linked": 1}
	game._play_card(game.PLAYER, "zeroday:linked", t22); step(4.0, 0.1)
	var zday: bool = absf(float(game.hosts[t22].bots) - 10.0) < 0.2 and game._routing_down(t22) and float(game.hosts[t22].route_off) > 15.0
	step(21.0, 0.5)
	var zday_over: bool = not game._routing_down(t22)
	check("22_single_cards", refused and in_flight and oneday25 and revealed22 and pc_phish and wiped and db_half and iot_resist and zday and zday_over,
		{"unconnected_refused": refused, "travels_as_packet": in_flight, "oneday_minus25": oneday25, "reveal_alarm_no_capture": revealed22, "pc_phish_minus75": pc_phish, "stuff_wipes": wiped, "db_resists_half": db_half, "iot_resists_phish_90": iot_resist, "zeroday_half_and_cut": zday, "routing_wears_off": zday_over})

	# 23 worms: the chain spreads along the streets with falling odds (jump 1: 100 %, then −25 % per jump),
	#    never onto the caster's own buildings, each building once, at most 4 jumps, captures nothing,
	#    reveals every building it hit, and draws one jump per spread
	fresh()
	game.rng.seed = 12345
	var t23 := neutral_nb(rigP())
	game.cards[game.PLAYER] = {"credworm:linked": 1}
	game.sel = {rigP(): true}; game._wire(t23); game._clear_all()
	var before := []
	for h in game.hosts: before.append([int(h.owner), float(h.bots)])
	game._play_card(game.PLAYER, "credworm:linked", t23)
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

	# 26 several paths: every gap with buildings on both sides may get a highway across it (none crosses a
	#    building), two junctions exist in the mid town, and a junction's streets admit double traffic
	fresh()
	var gaps := 0; var bridged := 0; var straddled := 0
	for gy in game.GRID_ROWS:
		for gx in game.GRID_COLS:
			var g := Vector2i(gx, gy)
			if game._cell.has(g): continue
			gaps += 1
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var a: Vector2i = g - d; var b: Vector2i = g + d
				if game._cell.has(a) and game._cell.has(b):
					straddled += 1
					if game._highways.has(game._lk(int(game._cell[a]), int(game._cell[b]))): bridged += 1
	var only_bridges := true   # every highway spans exactly one gap in a straight line
	for key in game._highways.keys():
		var ab := str(key).split("_")
		var ga: Vector2i = game.hosts[int(ab[0])].grid; var gb: Vector2i = game.hosts[int(ab[1])].grid
		var mid: Vector2i = (ga + gb) / 2
		if (ga - gb).length() != 2.0 or game._cell.has(mid): only_bridges = false
	var junctions := []
	for i in game.hosts.size():
		if bool(game.hosts[i].junction): junctions.append(i)
	var jok: bool = junctions.size() == int(game.JUNCTIONS)
	for j in junctions:
		if int(game.hosts[j].value) < 2 or (game.hosts[j].links as Array).size() < 3 or bool(game.hosts[j].hub) or bool(game.hosts[j].rig): jok = false
	var j0: int = junctions[0]; var nb0: int = int(game.hosts[j0].links[0])
	var kj: String = game._lkey(j0, nb0)
	var entries := []
	for q26 in 5: entries.append(game._link_entry(kj, 0.0)); game._reserve(kj, float(entries[q26]))
	var double_cap: bool = float(entries[3]) == 0.0 and float(entries[4]) > 0.5   # 4 admitted at once on a junction street, the 5th waits
	var plain := -1
	for i in game.hosts.size():
		if bool(game.hosts[i].junction): continue
		for o in game.hosts[i].links:
			if not bool(game.hosts[int(o)].junction): plain = i; break
		if plain >= 0: break
	var kp: String = game._lkey(plain, int(game.hosts[plain].links[0]))
	var pe := []
	for r26 in 3: pe.append(game._link_entry(kp, 0.0)); game._reserve(kp, float(pe[r26]))
	var plain_cap: bool = float(pe[1]) == 0.0 and float(pe[2]) > 0.5
	check("26_several_paths", bridged >= 1 and only_bridges and jok and double_cap and plain_cap,
		{"gaps": gaps, "straddled_gaps": straddled, "highways": bridged, "highways_span_one_gap": only_bridges, "junctions": junctions.size(), "junction_streets_x2": double_cap, "plain_street_x1": plain_cap})

	# ── the AI under the player's fog ──
	# 27 the twin test: the AI's decisions must not change when ONLY hidden fields of buildings it has not
	#    scanned change (bots, security, what is built inside, jobs, rate dials of others)
	var digests := []
	for pass_n in 2:
		fresh(); game.intel[game.RIVAL] = 60.0; game.intel[game.RIVAL2] = 60.0
		if pass_n == 1:
			for i in game.hosts.size():
				var o := int(game.hosts[i].owner)
				if o == game.RIVAL or game._scanned(game.RIVAL, i): continue
				if o == game.NEUTRAL: game.hosts[i].bots = maxf(1.0, float(game.hosts[i].bots) - 3.0)
				else: game.hosts[i].bots = 21.0
				game.hosts[i].sec = float(game.hosts[i].sec) + 5.0
				var bl: Array = game.hosts[i].builds
				var placed := false
				for k27 in bl.size():
					if str(bl[k27]) == "" and not placed: bl[k27] = "intel"; placed = true
				if not placed and bl.size() > 1: bl[1] = "cash"
				game.hosts[i].jobs[0] = {"kind": "cash", "slot": 0, "phase": "build", "left": 5.0}
				game.hosts[i].rate = 0.25
		game._ai_think(game.RIVAL)
		var d := []
		for i in game.hosts.size():
			if int(game.hosts[i].owner) == game.RIVAL: d.append([i, int(game.hosts[i].assign), bool(game.hosts[i].live), str(game.hosts[i].mode), str(((game.hosts[i].jobs as Dictionary).get(0, {}) as Dictionary).get("kind", ""))])
		var ks: Array = (game._ai[game.RIVAL].ops as Dictionary).keys(); ks.sort()
		d.append(ks); d.append(int(game.card_plays[game.RIVAL])); d.append((game.lab[game.RIVAL].queue as Array).duplicate())
		digests.append(JSON.stringify(d))
	var live_any: bool = str(digests[0]).find("true") >= 0
	check("27_fog_twin", digests[0] == digests[1] and live_any, {"same_decisions": digests[0] == digests[1], "acts": live_any, "digest": digests[0].left(160)})

	# 28 the prior is public: computed from type, value, owner and the hub only — never the real bots
	fresh()
	var pri := {}
	for i in game.hosts.size():
		var h: Dictionary = game.hosts[i]
		if int(h.owner) == game.NEUTRAL and not bool(h.hub) and str(h.type) == "pc" and int(h.value) == 1 and not pri.has("pc1"): pri["pc1"] = i
		if int(h.owner) == game.NEUTRAL and str(h.type) == "iot" and int(h.value) == 1 and not pri.has("iot1"): pri["iot1"] = i
		if int(h.owner) == game.RIVAL2 and not pri.has("kraken"): pri["kraken"] = i
	for i in pri.values(): game.hosts[int(i)].bots = 1.0   # the real number must not matter
	var p_pc: float = game._ai_prior_bots(int(pri.pc1)); var p_iot: float = game._ai_prior_bots(int(pri.iot1))
	var p_hub: float = game._ai_prior_bots(game.hub); var p_bot: float = game._ai_prior_bots(int(pri.kraken))
	check("28_prior_is_public", absf(p_pc - 9.5) < 0.01 and absf(p_iot - 6.5) < 0.01 and absf(p_hub - 30.0) < 0.01 and absf(p_bot - 18.0) < 0.01,
		{"pc_value1": p_pc, "iot_value1": p_iot, "hub": p_hub, "botnet_building": p_bot})

	# 29 scout then strike: the first move on an unknown neighbour is a quiet two-source scan that never
	#    alarms it; once the scan lands the AI knows the live numbers and attacks with a sized force
	fresh(); game.intel[game.RIVAL] = 100.0; fill_ai(game.RIVAL)
	game._ai_think(game.RIVAL)
	var tgt29 := -1; var n29 := 0; var all_scan := true
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and int(game.hosts[i].assign) >= 0 and int(game.hosts[game.hosts[i].assign].owner) != game.RIVAL:
			tgt29 = int(game.hosts[i].assign); n29 += 1
			if str(game.hosts[i].mode) != "scan": all_scan = false
	var scouting: bool = tgt29 >= 0 and n29 <= 2 and all_scan and not game._scanned(game.RIVAL, tgt29)
	var rec29_prior: bool = tgt29 >= 0 and absf(float(game._ai[game.RIVAL].ops[tgt29].bots) - game._ai_prior_bots(tgt29)) < 0.01
	var never_alarmed := true; var g29 := 0
	while tgt29 >= 0 and not game._scanned(game.RIVAL, tgt29) and g29 < 400:
		game._process(0.1); g29 += 1
		if game._under_attack(tgt29): never_alarmed = false
	var learned: bool = tgt29 >= 0 and game._scanned(game.RIVAL, tgt29) and absf(float(game.scans[game.RIVAL][tgt29].bots) - float(game.hosts[tgt29].bots)) < 1.5
	var stood := true
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and int(game.hosts[i].assign) == tgt29: stood = false
	if tgt29 >= 0: game.hosts[tgt29].bots = 4.0   # the scan shows a soft building (live numbers, it is scanned): worth a strike
	game.intel[game.RIVAL] = 100.0
	game._ai_think(game.RIVAL)
	var strike := false
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and str(game.hosts[i].mode) == "attack" and int(game.hosts[i].assign) == tgt29: strike = true
	check("29_scout_then_strike", scouting and rec29_prior and never_alarmed and learned and stood and strike,
		{"target": tgt29, "scan_sources": n29, "quiet": never_alarmed, "learned_live_bots": learned, "stood_down": stood, "then_attacks_known": strike, "scan_took_s": snapped(float(g29) * 0.1, 0.1)})

	# 30 pile on what is VISIBLE: a third party's live attack wire or bot packets count, its quiet scan does not
	fresh()
	var t30 := neutral_nb(rigR())
	var k30 := -1
	for o in game.hosts[t30].links:
		if int(game.hosts[o].owner) == game.NEUTRAL and int(o) != t30: k30 = int(o); break
	game.hosts[k30].owner = game.RIVAL2; game.hosts[k30].bots = 30.0
	var o0: int = game._ai_others_on(game.RIVAL, t30)
	game.hosts[k30].assign = t30; game.hosts[k30].live = true; game.hosts[k30].mode = "attack"
	var o1: int = game._ai_others_on(game.RIVAL, t30)
	game.hosts[k30].mode = "scan"
	var o2: int = game._ai_others_on(game.RIVAL, t30)
	game.hosts[k30].live = false; game.hosts[k30].assign = -1
	game.flights = [{"route": [k30, t30], "hops": [game._t], "depart_t": game._t, "arrive_t": game._t + 1.0, "owner": game.RIVAL2, "kind": "bot", "amount": 1.0}]
	var o3: int = game._ai_others_on(game.RIVAL, t30)
	game.flights[0].kind = "scan"
	var o4: int = game._ai_others_on(game.RIVAL, t30)
	game.flights = []
	check("30_pile_on_visible_only", o0 == 0 and o1 == 1 and o2 == 0 and o3 == 1 and o4 == 0, {"none": o0, "live_wire": o1, "quiet_scan_wire": o2, "bot_packet": o3, "scan_packet": o4})

	# 31 the bleeder and the hidden dial: a building visibly streaming out is softer; its rate dial is never read
	#    (A = D: 12 bots, one farm, two streams → 12 s; a visible outflow is read as a full 1/s, never its 0.3 dial → 6 s)
	fresh()
	var t31 := neutral_nb(rigR())
	game.hosts[t31].type = "pc"; game._set_builds(t31, ["bot"]); game.hosts[t31].bots = 12.0; game._mark_scanned(game.RIVAL, t31)
	var s0: float = game._ai_fall_secs(game.RIVAL, t31, 2)
	var n31 := -1
	for o in game.hosts[t31].links:
		if int(game.hosts[o].owner) == game.NEUTRAL and int(o) != t31: n31 = int(o); break
	game.hosts[t31].assign = n31; game.hosts[t31].live = true; game.hosts[t31].mode = "attack"; game._next_depart[t31] = game._t; game.hosts[t31].rate = 0.3
	var s1: float = game._ai_fall_secs(game.RIVAL, t31, 2)
	game.hosts[t31].mode = "scan"
	var s2: float = game._ai_fall_secs(game.RIVAL, t31, 2)
	game.hosts[t31].assign = -1; game.hosts[t31].live = false; game._next_depart.erase(t31)
	check("31_bleeder_hidden_dial", absf(s0 - 12.0) < 0.5 and absf(s1 - 6.0) < 0.5 and absf(s2 - 12.0) < 0.5, {"idle": snapped(s0, 0.1), "visibly_streaming_out": snapped(s1, 0.1), "quiet_scan_invisible": snapped(s2, 0.1)})

	# 32 memory: a scan remembers bots, cap and time; when the inside changes the live number goes dark and the
	#    AI uses what it saw, regrown at a farm's rate; a witnessed capture is remembered as near-empty
	fresh()
	var t32 := neutral_nb(rigR())
	game.hosts[t32].type = "pc"
	game._mark_scanned(game.RIVAL, t32)
	var rec32: Dictionary = game.scans[game.RIVAL][t32]
	var remembered: bool = absf(float(rec32.bots) - float(game.hosts[t32].bots)) < 0.01 and absf(float(rec32.cap) - float(game.hosts[t32].sec)) < 0.01
	var seen_bots: float = float(rec32.bots)
	game.hosts[t32].builds[1] = "cash"; game.hosts[t32].bots = 3.0
	var dark: bool = not game._scanned(game.RIVAL, t32) and absf(game._ai_known_bots(game.RIVAL, t32) - seen_bots) < 0.01
	var kinds32: Array = game._ai_known_builds(game.RIVAL, t32)
	var remembered_kinds: bool = kinds32 == ["bot"]
	game._t += 10.0
	var regrown: bool = absf(game._ai_known_bots(game.RIVAL, t32) - minf(float(rec32.cap), seen_bots + 10.0)) < 0.01
	var t32b := neutral_nb(secondR(), rigR())
	game._capture(t32b, game.PLAYER)
	var flip: bool = absf(game._ai_known_bots(game.RIVAL, t32b)) < 0.01
	var l32 := secondR()
	game._capture(l32, game.PLAYER)   # RIVAL loses its second building: it witnessed that, so it knows the place is near empty
	var loser_knows: bool = absf(game._ai_known_bots(game.RIVAL, l32)) < 0.01 and not game._scanned(game.RIVAL, l32)
	var player_knows: bool = (game.scans[game.PLAYER] as Dictionary).has(t32b) == false and absf(game._ai_known_bots(game.PLAYER, l32) - float(game.hosts[l32].bots)) < 0.01   # the captor owns it: exact
	var no_hidden_key: bool = str((game.scans[game.RIVAL][l32] as Dictionary).get("key", "")) == ""
	check("32_scan_memory", remembered and dark and remembered_kinds and regrown and flip and loser_knows and no_hidden_key,
		{"remembers_on_scan": remembered, "dark_after_change_uses_memory": dark, "remembered_kinds": kinds32, "regrows": regrown, "capture_known_empty": flip, "loser_remembers_near_empty": loser_knows, "memory_carries_no_hidden_key": no_hidden_key})

	# 33 counter-attack is lawful: a VISIBLE attacker gets two streams sized on the public prior; a quiet scan
	#    into its building is not even noticed; hidden bots of the attacker do not change the decision
	var wires33 := []
	for pass33 in 2:
		fresh(); game.intel[game.RIVAL] = 100.0
		var t33 := secondR()
		var k33 := -1
		for o in game.hosts[t33].links:
			if int(game.hosts[o].owner) == game.NEUTRAL: k33 = int(o); break
		game.hosts[k33].owner = game.RIVAL2; game.hosts[k33].bots = 30.0 if pass33 == 0 else 5.0; game._set_builds(k33, ["bot"])
		game.hosts[k33].assign = t33; game.hosts[k33].live = true; game.hosts[k33].mode = "attack"; game._next_depart[k33] = game._t
		for o in game.hosts[rigR()].links:   # a third building, so two sources are free while the attacked one holds
			if int(game.hosts[o].owner) == game.NEUTRAL and int(o) != k33: game.hosts[int(o)].owner = game.RIVAL; game.hosts[int(o)].bots = 30.0; game._set_builds(int(o), ["bot"]); break
		game._ai_think(game.RIVAL)
		var w := []
		for i in game.hosts.size():
			if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and int(game.hosts[i].assign) == k33 and str(game.hosts[i].mode) == "attack": w.append(i)
		wires33.append(w)
		if pass33 == 0:
			var r33: Dictionary = game._ai[game.RIVAL].ops.get(k33, {})
			wires33.append(absf(float(r33.get("bots", -1.0)) - 18.0) < 0.01)
	fresh(); game.intel[game.RIVAL] = 100.0
	var t33b := secondR(); var k33b := -1
	for o in game.hosts[t33b].links:
		if int(game.hosts[o].owner) == game.NEUTRAL: k33b = int(o); break
	game.hosts[k33b].owner = game.RIVAL2; game.hosts[k33b].bots = 30.0; game.hosts[k33b].assign = t33b; game.hosts[k33b].live = true; game.hosts[k33b].mode = "scan"; game._next_depart[k33b] = game._t
	game._ai_think(game.RIVAL)
	var ignored: bool = not game._under_attack(t33b)
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and int(game.hosts[i].assign) == k33b: ignored = false
	check("33_counter_attack_lawful", (wires33[0] as Array).size() == 2 and bool(wires33[1]) and wires33[0] == wires33[2] and ignored,
		{"two_streams": (wires33[0] as Array).size(), "sized_on_prior_18": wires33[1], "same_with_hidden_bots_5": wires33[0] == wires33[2], "quiet_scan_unnoticed": ignored})

	# 34 know your limits, then learn: a target the prior says it cannot take within its patience is not
	#    attacked (a quiet scan is allowed); once scanned and found weak, it is attacked
	fresh(); game.intel[game.RIVAL] = 100.0; fill_ai(game.RIVAL)
	var c34 := neutral_nb(rigR())
	game.hosts[c34].type = "db"; game.hosts[c34].value = 2; game.hosts[c34].slots = 4; game.hosts[c34].sec = 24.0; game.hosts[c34].bots = 24.0; game._set_builds(c34, ["bot"])
	game._ai_think(game.RIVAL)
	var attacked34 := false
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and int(game.hosts[i].assign) == c34 and str(game.hosts[i].mode) == "attack": attacked34 = true
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL: game._ai_release(i)
	game._ai[game.RIVAL].ops = {}
	game._mark_scanned(game.RIVAL, c34); game.hosts[c34].bots = 6.0; game.scans[game.RIVAL][c34].bots = 6.0
	game._ai_think(game.RIVAL)
	var attacked34b := false
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and int(game.hosts[i].assign) == c34 and str(game.hosts[i].mode) == "attack": attacked34b = true
	check("34_know_limits_then_learn", not attacked34 and attacked34b, {"skipped_unknown_strong_prior": not attacked34, "attacks_once_known_weak": attacked34b})

	# 35 retake what it lost: a building it owned and lost ranks above an equal neutral
	fresh(); game.intel[game.RIVAL] = 100.0
	var l35 := secondR()
	game._capture(l35, game.RIVAL2)
	var lost_recorded: bool = int((game._ai[game.RIVAL].lost as Dictionary).get(l35, {}).get("to", -1)) == game.RIVAL2
	game.hosts[l35].bots = 6.0; game.hosts[l35].type = "pc"; game.hosts[l35].value = 1; game._set_builds(l35, ["bot"]); game._mark_scanned(game.RIVAL, l35)
	var m35 := -1
	for o in game.hosts[rigR()].links:
		if int(game.hosts[o].owner) == game.NEUTRAL: m35 = int(o); break
	game.hosts[m35].owner = game.RIVAL; game.hosts[m35].bots = 30.0; game._set_builds(m35, ["bot"])
	var n35 := -1
	for o in game.hosts[rigR()].links:
		if int(game.hosts[o].owner) == game.NEUTRAL and int(o) != l35: n35 = int(o); break
	if n35 >= 0:
		game.hosts[n35].type = "pc"; game.hosts[n35].value = 1; game.hosts[n35].bots = 6.0; game._set_builds(n35, ["bot"]); game._mark_scanned(game.RIVAL, n35)
	game._ai_think(game.RIVAL)
	var retake := false; var other := false
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and str(game.hosts[i].mode) == "attack":
			if int(game.hosts[i].assign) == l35: retake = true
			elif int(game.hosts[i].assign) == n35: other = true
	check("35_retake_remembered", lost_recorded and retake and not other, {"lost_recorded": lost_recorded, "retakes_lost_building": retake, "equal_neutral_not_preferred": not other})

	# 36 idle scouting: with Intel for learning but not for a strike, one source scans the richest unknown
	#    neighbour quietly; with less Intel it keeps its reserve
	fresh(); game.intel[game.RIVAL] = 22.0
	fill_ai(game.RIVAL)   # no free slot, so no build first: a build now costs Intel and would eat the 22 before the scout step
	game.hosts[int(game.rig[game.RIVAL])].prod_off = 1000.0   # its rig's Intel trickle off (as a DoS does): the AI funds sieges on expected income, so only the 22 counts here
	for i in game.hosts.size():   # every neutral the AI borders reads as rich and hard in its public prior: a strike or a two-source scout costs more than 22
		if int(game.hosts[i].owner) != game.NEUTRAL: continue
		for o in game.hosts[i].links:
			if int(game.hosts[o].owner) == game.RIVAL: game.hosts[i].value = 3; game.hosts[i].type = "erp"; break
	game._ai_think(game.RIVAL)
	var sc36 := []
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and int(game.hosts[i].assign) >= 0: sc36.append([i, int(game.hosts[i].assign), str(game.hosts[i].mode)])
	var one_scan: bool = sc36.size() == 1 and str(sc36[0][2]) == "scan" and not game._scanned(game.RIVAL, int(sc36[0][1]))
	fresh(); game.intel[game.RIVAL] = 5.0
	game._ai_think(game.RIVAL)
	var none := true
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and bool(game.hosts[i].live) and int(game.hosts[i].assign) >= 0 and int(game.hosts[game.hosts[i].assign].owner) != game.RIVAL: none = false
	check("36_idle_scouting", one_scan and none, {"scouts_with_22_intel": one_scan, "keeps_reserve_with_5": none, "scout": sc36})

	# 37 choke the leader: a rival far ahead in Cash gets its known market phished, over a dormant wire laid for it
	fresh()
	var claimed37 := 0   # RIVAL2 becomes the control leader: several more buildings than RIVAL
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.NEUTRAL and claimed37 < 4: game.hosts[i].owner = game.RIVAL2; game.hosts[i].bots = 30.0; claimed37 += 1
	var m37 := neutral_nb(rigR())
	game.hosts[m37].owner = game.RIVAL2; game.hosts[m37].type = "pc"; game.hosts[m37].bots = 30.0; game._set_builds(m37, ["bot", "cash"]); game._mark_scanned(game.RIVAL, m37)
	game.cards[game.RIVAL] = {"dos:linked": 1}
	game._ai_think(game.RIVAL)
	var played37: bool = int(game.card_plays[game.RIVAL]) == 1
	var flight37 := false
	for fl in game.flights:
		if str(fl.kind) == "card" and int((fl.route as Array)[(fl.route as Array).size() - 1]) == m37: flight37 = true
	fresh()
	var claimed37b := 0
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.NEUTRAL and claimed37b < 4: game.hosts[i].owner = game.RIVAL2; game.hosts[i].bots = 30.0; claimed37b += 1
	var m37b := neutral_nb(rigR())
	game.hosts[m37b].owner = game.RIVAL2; game.hosts[m37b].type = "pc"; game.hosts[m37b].bots = 30.0; game._set_builds(m37b, ["bot", "bot"]); game._mark_scanned(game.RIVAL, m37b)
	game.cards[game.RIVAL] = {"dos:linked": 1}
	game._ai_think(game.RIVAL)
	var spared: bool = int(game.card_plays[game.RIVAL]) == 0
	check("37_choke_the_leader", played37 and flight37 and spared, {"dossed_known_production": played37 and flight37, "no_production_no_dos": spared})

	# 38 remember where it hurt: a full rear building pre-wires its guard to the frontier building hit most recently
	fresh()
	var rr38 := rigR()
	var fronts := []
	for o in game.hosts[rr38].links:
		if int(game.hosts[o].owner) == game.NEUTRAL: game.hosts[int(o)].owner = game.RIVAL; game.hosts[int(o)].bots = 20.0; game._set_builds(int(o), ["bot"]); fronts.append(int(o))
	for fr38 in fronts:
		for o in game.hosts[int(fr38)].links:
			if int(game.hosts[o].owner) == game.NEUTRAL: game.hosts[int(o)].owner = game.RIVAL; game.hosts[int(o)].bots = 20.0; game._set_builds(int(o), ["bot"])
	fill_ai(game.RIVAL)   # no build to distract it from pre-wiring a guard
	var rear_ok: bool = not game._ai_frontier(rr38)
	var f1 := -1; var att := -1
	for i in game.hosts.size():   # a frontier building of RIVAL's with a neutral neighbour to play the attacker
		if int(game.hosts[i].owner) != game.RIVAL or i == rr38: continue
		for o in game.hosts[i].links:
			if int(game.hosts[o].owner) == game.NEUTRAL: f1 = i; att = int(o); break
		if f1 >= 0: break
	var f2 := -1
	for fr38c in fronts:
		if int(fr38c) != f1 and game._ai_frontier(int(fr38c)): f2 = int(fr38c); break
	if f2 < 0:
		for i in game.hosts.size():
			if int(game.hosts[i].owner) == game.RIVAL and i != f1 and i != rr38 and game._ai_frontier(i): f2 = i; break
	game.hosts[att].owner = game.RIVAL2; game.hosts[att].bots = 30.0; game.hosts[att].assign = f1; game.hosts[att].live = true; game.hosts[att].mode = "attack"; game._next_depart[att] = game._t
	game.hosts[rr38].bots = 30.0; game.hosts[rr38].assign = -1
	game._ai_think(game.RIVAL)
	var edge_seen: bool = absf(float((game._ai[game.RIVAL].edges as Dictionary).get(f1, -1.0)) - game._t) < 0.01
	game.hosts[att].live = false; game.hosts[att].assign = -1; game._next_depart.erase(att)
	if f2 >= 0: game.hosts[f2].bots = 10.0
	game._ai_release(rr38); game.hosts[rr38].bots = 30.0
	game._ai_think(game.RIVAL)
	var guarded_edge: bool = int(game.hosts[rr38].assign) == f1 and not bool(game.hosts[rr38].live)
	check("38_remember_where_it_hurt", rear_ok and edge_seen and guarded_edge, {"rear": rear_ok, "edge_remembered": edge_seen, "guard_on_learned_edge": guarded_edge, "f1": f1, "f2": f2})

	# 39 worm value by public types: a soft cluster (PC, IoT, Web) promises a longer chain than a hard one (DB, ERP)
	fresh()
	var s39 := -1
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.NEUTRAL and (game.hosts[i].links as Array).size() >= 2: s39 = i; break
	var ring := [s39]
	for o in game.hosts[s39].links: ring.append(int(o))
	for i in ring: game.hosts[int(i)].type = "pc"
	var v_soft: float = game._ai_worm_value(game.RIVAL, s39)
	for i in ring: game.hosts[int(i)].type = "erp"
	var v_hard: float = game._ai_worm_value(game.RIVAL, s39)
	check("39_worm_value_public_types", v_soft > v_hard and v_hard > 0.0, {"soft": snapped(v_soft, 0.01), "hard": snapped(v_hard, 0.01)})

	# 40 the AIs still act under the fog: on seeds 7 and 11, both AIs on, each captures a building within 150 s
	#    and holds at least one scan record that came from a quiet scan (a learn scan), not from an attack
	var pacing := {}
	for sd in [7, 11]:
		fresh(sd); game.ai_enabled = true
		var first := {2: -1.0, 3: -1.0}; var tt := 0.0
		while tt < 150.0 and not game.won and not game.lost:
			game._process(0.1); tt += 0.1
			for fac in game.AIS:
				if float(first[fac]) < 0.0 and game._faction_nodes(fac) > 2: first[fac] = snapped(tt, 0.1)
		var learned40 := {2: 0, 3: 0}
		for fac in game.AIS:
			for tk in (game.scans[fac] as Dictionary).keys():
				var r40: Dictionary = game.scans[fac][tk]
				if bool(r40.get("done", false)): learned40[fac] += 1
		pacing[sd] = {"first_capture": first, "scans_done": learned40}
	var active: bool = float(pacing[7].first_capture[2]) > 0.0 and float(pacing[7].first_capture[3]) > 0.0 and float(pacing[11].first_capture[2]) > 0.0 and float(pacing[11].first_capture[3]) > 0.0
	var learns: bool = int(pacing[7].scans_done[2]) > 0 and int(pacing[7].scans_done[3]) > 0
	check("40_ai_acts_under_fog", active and learns, pacing)

	# 41 the UI twin: the player's panel for a foreign target, its focus set and the amber streets are the same
	#    whether or not the target's owner has a hidden rate dial, a job, a quiet scan or a dormant plan running
	var ui := []
	for pass41 in 2:
		fresh()
		var t41 := neutral_nb(rigP())
		game.hosts[t41].owner = game.RIVAL2; game.hosts[t41].bots = 20.0; game._set_builds(t41, ["bot"])
		var k41 := -1
		for o in game.hosts[t41].links:
			if int(game.hosts[o].owner) == game.NEUTRAL and int(o) != t41: k41 = int(o); break
		game.hosts[k41].owner = game.RIVAL2; game.hosts[k41].bots = 20.0
		game._mark_scanned(game.PLAYER, t41)
		game.sel = {rigP(): true}; game._wire(t41); game._launch(t41, "attack")
		step(2.0, 0.1)
		if pass41 == 1:   # hidden facts only
			game.hosts[t41].rate = 0.25; game.hosts[t41].jobs[1] = {"kind": "cash", "slot": 1, "phase": "build", "left": 5.0}
			game.hosts[t41].assign = k41; game.hosts[t41].live = false                       # a dormant plan
			game.hosts[k41].assign = rigP(); game.hosts[k41].live = true; game.hosts[k41].mode = "scan"; game._next_depart[k41] = game._t   # a quiet scan at you
			game.hosts[k41].bots = 7.0
		game._clear_all(); game._inspect = t41
		var txt: String = game._panel_text()
		var fn := {}; var fl := {}
		game._build_focus(t41, fn, fl)
		var fk: Array = fn.keys(); fk.sort(); var lk: Array = fl.keys(); lk.sort()
		var amber := []
		for i in game.hosts.size():
			for j in game.hosts[i].links:
				if int(j) > i and game._link_busy_visible(i, int(j)): amber.append([i, int(j)])
		var badge := "%d" % int(round(float(game.hosts[k41].bots)))
		if not game._scanned(game.PLAYER, k41): badge = "?"
		ui.append(JSON.stringify([txt, fk, lk, amber, badge]))
	check("41_ui_twin", ui[0] == ui[1], {"same_panel_focus_streets": ui[0] == ui[1], "digest": str(ui[0]).left(200)})

	# 43 supply-chain steal: for a few seconds the target's production flows to the caster, not its owner
	fresh()
	var tm43 := neutral_nb(rigP())
	game.hosts[tm43].owner = game.RIVAL; game.hosts[tm43].type = "pc"; game.hosts[tm43].bots = 20.0
	game._set_builds(tm43, ["cash", "intel"]); game._mark_scanned(game.PLAYER, tm43)
	var owner_rate0: float = game._intel_rate(game.RIVAL)   # RIVAL gets tm43's Intel now
	game.cards[game.PLAYER] = {"supply:linked": 1}
	game.sel = {rigP(): true}; game._wire(tm43); game._clear_all()
	game._play_card(game.PLAYER, "supply:linked", tm43); step(3.0, 0.1)
	var stealing: bool = game._stolen(tm43) and int(game.hosts[tm43].steal_by) == game.PLAYER and game._benef(tm43) == game.PLAYER
	var thief_rate: bool = game._intel_rate(game.PLAYER) > 0.9 and game._cash_rate(game.PLAYER) > 0.0   # tm43 now feeds the player
	var owner_denied: bool = game._intel_rate(game.RIVAL) < owner_rate0 - 0.9   # and no longer the owner
	var pcash0: float = game.cash[game.PLAYER]; var rcash0: float = game.cash[game.RIVAL]; var pintel0: float = game.intel[game.PLAYER]
	step(2.0, 0.1)
	var thief_gains: bool = game.cash[game.PLAYER] > pcash0 + 0.1 and game.intel[game.PLAYER] > pintel0 + 0.1
	var owner_gets_nothing: bool = absf(game.cash[game.RIVAL] - rcash0) < 0.01
	step(5.0, 0.1)
	var wore_off: bool = not game._stolen(tm43) and game._benef(tm43) == game.RIVAL
	check("43_supply_chain_steal", stealing and thief_rate and owner_denied and thief_gains and owner_gets_nothing and wore_off,
		{"stealing": stealing, "thief_gets_the_rates": thief_rate, "owner_denied": owner_denied, "thief_pools_grow": thief_gains, "owner_pools_frozen": owner_gets_nothing, "wears_off": wore_off})

	# 44 denial of service: production off AND routing cut together, for the duration, then both recover
	fresh()
	var td44 := neutral_nb(rigP())
	game.hosts[td44].owner = game.RIVAL; game.hosts[td44].type = "pc"; game.hosts[td44].bots = 20.0
	game._set_builds(td44, ["bot", "cash"]); game._mark_scanned(game.PLAYER, td44)
	game.cards[game.PLAYER] = {"dos:linked": 1}
	game.sel = {rigP(): true}; game._wire(td44); game._clear_all()
	game._play_card(game.PLAYER, "dos:linked", td44); step(3.0, 0.1)
	var denied: bool = game._prod_down(td44) and game._routing_down(td44) and game._regen(td44) == 0.0 and game._count(td44, "cash") == 0 and float(game.hosts[td44].route_off) > 20.0
	step(26.0, 0.5)
	var dos_over: bool = not game._prod_down(td44) and not game._routing_down(td44) and game._regen(td44) > 0.0
	check("44_denial_of_service", denied and dos_over, {"production_and_routing_down": denied, "both_recover": dos_over})

	# 45 the AI builds unattended: a job it starts progresses with nobody "inside", is paid in Intel, and it may
	#    start another while the first still runs (one new job per think)
	fresh(); game.intel[game.RIVAL] = 100.0
	var i45 := float(game.intel[game.RIVAL])
	game._ai_think(game.RIVAL)
	var r45 := -1
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and not (game.hosts[i].jobs as Dictionary).is_empty(): r45 = i; break
	var started45: bool = r45 >= 0
	var paid45: bool = started45 and float(game.intel[game.RIVAL]) <= i45 - game.BUILD_COST_INTEL + 0.01
	var left0: float = float((game.hosts[r45].jobs as Dictionary).values()[0].left) if started45 else 0.0
	game._tick_jobs(1.0)
	var progressed45: bool = started45 and float((game.hosts[r45].jobs as Dictionary).values()[0].left) < left0 - 0.5
	var jobs0 := 0
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL: jobs0 += (game.hosts[i].jobs as Dictionary).size()
	game._ai_think(game.RIVAL)   # a later think may add another job while the first still runs
	var jobs1 := 0
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL: jobs1 += (game.hosts[i].jobs as Dictionary).size()
	check("45_ai_builds_unattended", started45 and paid45 and progressed45 and jobs1 >= jobs0,
		{"starts_a_job": started45, "pays_intel": paid45, "progresses_with_nobody_inside": progressed45, "jobs_after_two_thinks": [jobs0, jobs1]})

	# 46 your memory is as fresh as the AI's: while a building stays scanned, its remembered bots and time keep
	#    up with the live values, so when it later goes dark you recall what it was, not a stale snapshot
	fresh()
	var t46 := neutral_nb(rigP())
	game.hosts[t46].sec = 28.0; game.hosts[t46].bots = 20.0; game._set_builds(t46, [])   # sec above bots so the cap does not bind
	game._mark_scanned(game.PLAYER, t46)
	step(5.0, 0.1)
	var rec46: Dictionary = game.scans[game.PLAYER][t46]
	var kept_fresh: bool = absf(float(rec46.at) - game._t) < 0.3 and absf(float(rec46.bots) - 20.0) < 0.5   # refreshed to ~now, not the mark time
	game.hosts[t46].builds = ["cash"]   # the inside changes → it goes dark
	var dark_uses_memory: bool = not game._scanned(game.PLAYER, t46) and absf(game._ai_known_bots(game.PLAYER, t46) - 20.0) < 0.6
	check("46_player_memory_symmetry", kept_fresh and dark_uses_memory, {"memory_refreshes_while_scanned": kept_fresh, "recalls_last_seen_when_dark": dark_uses_memory})

	# 42 domination: holding more than half the town for HOLD_SECS wins; losing the majority resets the clock
	fresh()
	var need42: int = game._control_need()
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.NEUTRAL and game._faction_nodes(game.PLAYER) < need42 + 1:
			game.hosts[i].owner = game.PLAYER; game.hosts[i].bots = game.NODE_CAP
	var majority: bool = game._faction_nodes(game.PLAYER) > need42
	var rivals_alive: bool = game._faction_nodes(game.RIVAL) > 0 and game._faction_nodes(game.RIVAL2) > 0   # so it is a hold win, not elimination
	step(30.0, 0.5)
	var ticking: bool = absf(float(game._hold[game.PLAYER]) - 30.0) < 1.0 and not game.won
	var drop := -1   # lose one building → below majority → the clock resets
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.PLAYER and i != rigP(): drop = i; break
	game.hosts[drop].owner = game.NEUTRAL
	step(1.0, 0.5)
	var reset: bool = float(game._hold[game.PLAYER]) < 0.6
	game.hosts[drop].owner = game.PLAYER; game.hosts[drop].bots = game.NODE_CAP   # retake it, hold to the win
	step(float(game.HOLD_SECS) + 1.0, 0.5)
	check("42_domination_hold", majority and rivals_alive and ticking and reset and game.won and game._end_cause.begins_with("You held"),
		{"majority": majority, "clock_ticks": ticking, "clock_resets_on_loss": reset, "won": game.won, "cause": game._end_cause})

	# 13 pacing readings (NOT balance verdicts): the rival alone, and a scripted greedy player vs the rival
	var alone := _run_match(SEED, false, 300.0)
	var greedy7 := _run_match(SEED, true, 300.0)
	var greedy11 := _run_match(11, true, 300.0)
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
	var intel_n := 0; var cash_n := 0
	for i in mine: intel_n += game._count_all(i, "intel"); cash_n += game._count_all(i, "cash")
	for i in mine:
		if (game.hosts[i].builds as Array).size() >= int(game.hosts[i].slots) or not (game.hosts[i].jobs as Dictionary).is_empty(): continue
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
		if game._start_job(i, kind): break
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
