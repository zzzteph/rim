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
	game._rival_timer = 1.0e9      # rival off unless a case turns it on

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
	var own := {0: 0, 1: 0, 2: 0}
	for h in game.hosts: own[int(h.owner)] += 1
	var distinct := {}
	for s in sizes: distinct[s] = true
	check("01_generation", game.hosts.size() <= 36 and game.hosts.size() >= 24 and own[1] == 2 and own[2] == 2
		and rigP() == game.cell_at(0, 0) and rigR() == game.cell_at(5, 5) and game.hub >= 0
		and int(game.hosts[game.hub].owner) == game.NEUTRAL and (game.hosts[game.hub].builds as Array).size() == 2
		and int(game.hosts[game.hub].slots) == 4 and all_connected and all_linked and distinct.size() > 1,
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
	game.hosts[n8].builds = ["bot", "intel", "cash"]
	var st := []
	for b in [25.0, 15.0, 5.0]:
		game.hosts[n8].bots = b
		st.append([game._stage(n8), game._active_slots(n8), game._count(n8, "bot"), game._count(n8, "intel"), game._count(n8, "cash")])
	check("05_control_stages", st == [[0, 3, 1, 1, 1], [1, 2, 1, 1, 0], [2, 1, 1, 0, 0]], {"stages": st})

	# 06 a build job only progresses while you are INSIDE; the rival's always does
	fresh()
	game._start_job(n8, "cash")
	game._tick_jobs(100.0)
	var not_built: bool = (game.hosts[n8].builds as Array).size() == 1
	game._inside = n8; game._enter_left = 0.0
	game._tick_jobs(game.BUILD_TIME + 0.01)
	var built: bool = (game.hosts[n8].builds as Array) == ["bot", "cash"]
	game._start_job(secondR(), "cash"); game._tick_jobs(game.BUILD_TIME + 0.01)
	check("06_jobs_need_attention", not_built and built and (game.hosts[secondR()].builds as Array) == ["bot", "cash"],
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

	# 08 the rival concentrates several sources on one soft bordering building and starts one build
	fresh()
	game._rival_timer = 0.0
	game._rival_ai(0.01)
	var assigned := []
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and int(game.hosts[i].assign) >= 0: assigned.append([i, game.hosts[i].assign])
	var jobs := []
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.RIVAL and not (game.hosts[i].job as Dictionary).is_empty(): jobs.append([i, game.hosts[i].job.kind])
	var same_target: bool = assigned.size() == 2 and int(assigned[0][1]) == int(assigned[1][1]) and int(game.hosts[int(assigned[0][1])].owner) == game.NEUTRAL
	check("08_rival_concentrates_and_builds", same_target and jobs.size() == 1, {"assigned": assigned, "jobs": jobs})

	# 09 Cash packets travel home and bank at the rig; a market ON the rig banks directly
	fresh()
	game.hosts[n8].builds = ["bot", "cash"]
	step(10.0, 0.1)
	var c1: float = game.cash[game.PLAYER]
	fresh()
	game.hosts[rigP()].builds = ["bot", "bot", "cash"]
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
		game.hosts[rigP()].assign = t11; game.hosts[n8].assign = t11
		step(20.0, dt)
		boards.append({"dt": dt, "target_bots": game.hosts[t11].bots, "owner": game.hosts[t11].owner, "intel": game.intel, "flights": game.flights.size()})
	var b_ok := absf(float(boards[0].target_bots) - float(boards[1].target_bots)) <= 1.0 and absf(float(boards[0].intel) - float(boards[1].intel)) <= 1.0
	check("11_frame_rate_consistency", b_ok, {"boards": boards})

	# 12 a building that streams out is softer: ONE stream drives it down to its garrison but no further;
	#    a second stream then captures it
	fresh()
	var tgt := neutral_nb(rigP())
	game.hosts[tgt].owner = game.RIVAL; game.hosts[tgt].bots = 12.0; game.hosts[tgt].assign = rigP()   # it attacks your rig
	game.hosts[rigP()].assign = tgt                                                                    # one stream back
	game.intel = 1000.0
	step(40.0, 0.1)
	var at_garrison: bool = int(game.hosts[tgt].owner) == game.RIVAL and float(game.hosts[tgt].bots) <= game.RIVAL_RESERVE + 1.5
	var bots_mid: float = game.hosts[tgt].bots
	game.hosts[n8].assign = tgt
	step(45.0, 0.1)
	check("12_attack_the_attacker", at_garrison and int(game.hosts[tgt].owner) == game.PLAYER, {"one_stream_bots": bots_mid, "owner_after_two": game.hosts[tgt].owner})

	# 13 pacing readings (NOT balance verdicts): the rival alone, and a scripted greedy player vs the rival
	var alone := _run_match(SEED, false, 900.0)
	var greedy7 := _run_match(SEED, true, 900.0)
	var greedy11 := _run_match(11, true, 900.0)
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
	game._rival_timer = game.RIVAL_CADENCE
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
	return {"outcome": ("WIN" if game.won else ("LOSS" if game.lost else "timeout")), "cause": game._end_cause, "t": snapped(t, 0.1),
		"player_nodes": game._player_nodes(), "rival_nodes": game._faction_nodes(game.RIVAL),
		"cash": [int(game.cash[game.PLAYER]), int(game.cash[game.RIVAL])], "first_capture_t": snapped(first_capture, 0.1), "intel": int(game.intel)}


func _greedy_player() -> void:
	var mine := []
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.PLAYER: mine.append(i)
	for i in mine:   # an order whose target is now ours is done
		var a := int(game.hosts[i].assign)
		if a >= 0 and int(game.hosts[a].owner) == game.PLAYER: game.hosts[i].assign = -1
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
		if intel_n < 2: kind = "intel"
		elif frontier and game._count_all(i, "bot") < 2: kind = "bot"
		elif cash_n <= intel_n: kind = "cash"
		else: kind = "intel"
		if game._start_job(i, kind):
			game._inside = i; game._enter_left = game.ENTER_TIME
			break
	# one attack at a time, concentrated
	var active := false
	for i in mine:
		if int(game.hosts[i].assign) >= 0: active = true
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
		game.hosts[int(s[1])].assign = pick
