extends SceneTree
## Recon and the odds: there are no security levels. A Recon gets through 50% of the time (a miss shows nothing).
## Every other offensive card succeeds 50% against a host you hold FRESH, faction-specific Recon of and 25% without,
## drawn once per resolved operation from the match's deterministic RNG; counters and route failure are decided before
## the draw; defence cards on your own hosts always work; the preview shows the odds.
## godot --headless --path . --script tests/recon_test.gd
var g
var P := 1
var R := 2
var checks := 0
var failures := []


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func fresh(seed := 7) -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = seed; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER; R = g.RIVAL
	for fac in [P, R]: g.bank[fac] = {"bots": 200.0, "intel": 300.0, "cash": 300.0, "creds": 300.0, "research": 300.0}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func neighbour() -> int:
	for nb in g.hosts[int(g.rig[P])].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: return int(nb)
	return -1


func resolve_capture(t: int, id: int) -> String:   # one Breach intrusion on t ending now; its outcome
	if g.op_outcomes.size() >= g.OP_OUTCOME_KEEP - 1: g.op_outcomes.clear()   # the record keeps only the last OP_OUTCOME_KEEP
	var n: int = g.op_outcomes.size()
	g._execs.append({"id": id, "fac": P, "card": "breach", "effect": "capture", "target": t, "gen": int(g.hosts[t].gen), "ends": g._t, "stage": 1, "victim": int(g.hosts[t].owner), "seen": [t]})
	g._tick_execs()
	return str(g.op_outcomes[n].outcome) if g.op_outcomes.size() > n else "none"


func run() -> void:
	no_security()
	unscouted_odds()
	scouted_baseline()
	expired_and_late()
	determinism()
	counters_first()
	exemptions_and_scope()
	preview_odds()
	odds_in_flight_and_after()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func no_security() -> void:
	fresh()
	var t := neighbour()
	var gates := []
	for type in ["iot", "pc", "server", "web", "file", "db", "erp"]:
		g.hosts[t].type = type
		for card in ["breach", "exploit", "zeroday", "worm", "phish"]:
			g.cards[P] = {card: 1}; g.known[P][card] = true
			if str(g._can_play(P, card, t)).contains("ecurity"): gates.append("%s@%s" % [card, type])
	check(gates.is_empty(), "No card is gated by a host's type or tier (%s)" % str(gates))
	check(not g.has_method("_security") and not "SEC_BY_TYPE" in g, "The security level is gone from the game")
	var exec_t := []
	for card in ["zeroday", "exploit", "breach"]: exec_t.append(float(g.CARDS[card].exec))
	check(exec_t[0] < exec_t[1] and exec_t[1] < exec_t[2], "Capture cards differ by speed instead: 0day %ds < Exploit %ds < Breach %ds" % exec_t)


func unscouted_odds() -> void:   # 400 unscouted captures: about a quarter succeed, never all, never none
	fresh()
	var t := neighbour()
	var won := 0; var missed := 0
	for k in 400:
		g.hosts[t].owner = g.NEUTRAL; g.hosts[t].gen = int(g.hosts[t].gen) + 1
		var o := resolve_capture(t, 10000 + k)
		if o == "captured": won += 1
		elif o == "missed": missed += 1
	check(won + missed == 400, "Each unscouted capture either succeeds or misses (%d + %d)" % [won, missed])
	check(won >= 70 and won <= 130, "Unscouted, about a quarter succeed: %d of 400 (UNSCOUTED_CHANCE %.2f)" % [won, g.UNSCOUTED_CHANCE])
	check(g.op_outcomes.any(func(o): return str(o.outcome) == "missed"), "A miss is recorded with its own outcome")


func scouted_baseline() -> void:
	fresh()
	var t := neighbour()
	var won := 0
	for k in 400:
		g.hosts[t].owner = g.NEUTRAL; g.hosts[t].gen = int(g.hosts[t].gen) + 1
		g._mark_scanned(P, t)
		if resolve_capture(t, 20000 + k) == "captured": won += 1
	check(won >= 160 and won <= 240, "With fresh Recon about half the captures succeed: %d of 400 (SCOUTED_CHANCE %.2f)" % [won, g.SCOUTED_CHANCE])
	# Recon itself: about half get through, and a miss leaves no snapshot
	var seen := 0; var miss_clean := true
	for k in 400:
		g.recon[P] = {}
		g._op_land(P, "recon", t, int(g.hosts[t].gen), {"id": 21000 + k})
		if g._recon_fresh(P, t): seen += 1
		elif str(g.op_outcomes.back().outcome) != "missed" or str(g.op_outcomes.back().card) != "recon": miss_clean = false
	check(seen >= 160 and seen <= 240, "A Recon gets through about half the time: %d of 400 (RECON_CHANCE %.2f)" % [seen, g.RECON_CHANCE])
	check(miss_clean, "A Recon that misses leaves no snapshot and is recorded as missed")
	g.rolls_always_hit = true
	won = 0
	for k in 20:
		g.hosts[t].owner = g.NEUTRAL; g.hosts[t].gen = int(g.hosts[t].gen) + 1
		if resolve_capture(t, 22000 + k) == "captured": won += 1
	check(won == 20, "The test switch that forces every draw to hit works (%d of 20)" % won)


func expired_and_late() -> void:
	fresh()
	var t := neighbour()
	g._mark_scanned(P, t)
	check(g._op_chance(P, t, "breach") == g.SCOUTED_CHANCE, "Fresh Recon: 50%")
	step(float(g.CARDS.recon.dur) + 1.0)
	check(g._op_chance(P, t, "breach") == g.UNSCOUTED_CHANCE, "Expired Recon (%d s): back to 25%%" % int(g.CARDS.recon.dur))
	g._mark_scanned(P, t)
	step(float(g.CARDS.recon.dur) - 5.0)
	check(g._op_chance(P, t, "breach") == g.SCOUTED_CHANCE and g._op_chance(P, t, "breach", g._t + 15.0) == g.UNSCOUTED_CHANCE,
		"Freshness is judged when the operation resolves: fresh now, stale 15 s later")
	g._mark_scanned(P, t)
	g._capture(t, R)   # the host changed hands: what you scouted belongs to the old owner
	check(g._op_chance(P, t, "breach") == g.UNSCOUTED_CHANCE, "A change of owner voids the Recon")


func outcomes_with(seed: int) -> Array:
	fresh(seed)
	var t := neighbour()
	var out := []
	for k in 40:
		g.hosts[t].owner = g.NEUTRAL; g.hosts[t].gen = int(g.hosts[t].gen) + 1
		out.append(resolve_capture(t, 30000 + k))
	return [out, g.sim_rng.state, g._mp_hash()]


func determinism() -> void:
	var a := outcomes_with(11)
	var b := outcomes_with(11)
	check(a[0] == b[0] and a[1] == b[1] and a[2] == b[2], "Same seed, same operations: the same outcomes, dice state and fingerprint")
	var c := outcomes_with(12)
	check(a[0] != c[0], "Another seed rolls other dice")
	fresh()
	var t := neighbour()
	var h0: String = g._mp_hash()
	g.sim_rng.randf()
	check(g._mp_hash() != h0, "The dice are part of the lockstep fingerprint")


func counters_first() -> void:   # an armed Patch, a lost route: decided without touching the dice
	fresh()
	var t := neighbour()
	g._capture(t, R)
	g.hosts[t].patch_armed_until = g._t + 30.0
	var st: int = g.sim_rng.state
	check(resolve_capture(t, 40001) == "countered" and g.sim_rng.state == st, "An armed Patch stops an unscouted capture before any draw")
	g.hosts[t].patch_armed_until = 0.0
	var far := -1
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == g.NEUTRAL and g._attack_route(P, i).is_empty(): far = i; break
	st = g.sim_rng.state
	check(resolve_capture(far, 40002) == "route_failed" and g.sim_rng.state == st, "No route: the capture fails before any draw")
	g._set_builds(t, ["intel", "wall"]); g.hosts[t].sockets = ["response"]; g.hosts[t].fw_on = true
	st = g.sim_rng.state
	g._op_land(P, "phish", t, int(g.hosts[t].gen), {"id": 40003})
	check(not g._phished(t) and g.sim_rng.state == st and g._loaded(t).is_empty(), "A loaded Response stops an unscouted Phishing before any draw")


func exemptions_and_scope() -> void:
	fresh()
	var t := neighbour()
	g._capture(t, R)
	check(g._op_chance(P, t, "recon") == g.RECON_CHANCE and g.RECON_CHANCE == 0.5 and g.SCOUTED_CHANCE == 0.5 and g.UNSCOUTED_CHANCE == 0.25,
		"Recon itself: 50%, scouted or not; attacks 50% scouted, 25% unscouted")
	var mine: int = int(g.rig[P])
	check(g._op_chance(P, mine, "patch") == 1.0 and g._op_chance(P, mine, "response") == 1.0, "Defence cards on your own hosts need no Recon")
	g._mark_scanned(R, t)
	check(g._op_chance(P, t, "breach") == g.UNSCOUTED_CHANCE, "Recon is per faction: a rival's scan does not help you")
	var probe0 := RandomNumberGenerator.new(); probe0.seed = 1; probe0.state = g.sim_rng.state; probe0.randf()
	g._op_land(P, "recon", t, int(g.hosts[t].gen), {"id": 50001})
	check(g.sim_rng.state == probe0.state, "A Recon draws exactly once")
	var rec_n: int = g.events.size()
	g.recon[P] = {}
	g.op_outcomes.clear()
	for k in 40:   # the victim never hears of a Recon, landed or missed
		g._op_land(R, "recon", int(g.rig[P]), int(g.hosts[int(g.rig[P])].gen), {"id": 50100 + k})
	check(g.events.size() == rec_n and g.op_outcomes.size() == 40, "A rival's Recon on you, hit or miss, never shows in your Logs")
	# a DDoS reaching three hosts is one operation: one draw, judged on the target's Recon
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == g.NEUTRAL and g.hosts[int(g.rig[R])].links.has(i): g._capture(i, R)
	g.recon[P] = {}
	var probe := RandomNumberGenerator.new(); probe.seed = 1; probe.state = g.sim_rng.state; probe.randf()
	g._op_land(P, "ddos", t, int(g.hosts[t].gen), {"id": 50002})
	check(g.sim_rng.state == probe.state, "DDoS on three hosts draws exactly once")
	# each Worm stage is its own operation: stage 2's target has its own Recon check
	var nxt := -1
	for nb in g.hosts[t].links:
		if bool(g.hosts[int(nb)].rig) or int(g.hosts[int(nb)].owner) == P: continue
		if int(g.hosts[int(nb)].owner) != R: g._capture(int(nb), R)
		nxt = int(nb); break
	g.recon[P] = {}
	g._mark_scanned(P, t)
	check(nxt >= 0 and g._op_chance(P, t, "worm") == g.SCOUTED_CHANCE and g._op_chance(P, nxt, "worm") == g.UNSCOUTED_CHANCE, "A Worm's second stage is judged on its own target's Recon")


func preview_odds() -> void:
	fresh()
	var t := neighbour()
	g.cards[P] = {"breach": 1}
	var lines: Array = g._target_preview(P, "breach", t).lines
	var s := ""
	for l in lines: s += str(l[0]) + "\n"
	check(s.contains("Chance: 25%"), "The preview shows 25% before launch without Recon")
	g._mark_scanned(P, t)
	s = ""
	for l in g._target_preview(P, "breach", t).lines: s += str(l[0]) + "\n"
	check(s.contains("Chance: 50%"), "...and 50% with fresh Recon")
	s = ""
	g.cards[P] = {"recon": 1}
	for l in g._target_preview(P, "recon", t).lines: s += str(l[0]) + "\n"
	check(s.contains("Chance: 50%"), "A Recon's own preview shows its 50%")
	g.cards[P] = {"breach": 1}
	step(float(g.CARDS.recon.dur) - 3.0)
	s = ""
	for l in g._target_preview(P, "breach", t).lines: s += str(l[0]) + "\n"
	check(s.contains("goes stale before it resolves"), "...and warns when the Recon will be stale by the time it resolves")


func odds_in_flight_and_after() -> void:   # a capture draws after its execution: the packet's odds are judged then, and a miss keeps its recorded odds
	fresh()
	var t := neighbour()
	g._mark_scanned(P, t)
	g.recon[P][t].at = g._t - 32.0   # fresh for 13 s more: stale by the time a Breach has executed (travel + 15 s)
	g.cards[P] = {"breach": 1}
	g._play_card(P, "breach", t)
	var fl: Dictionary = {}
	for f in g.flights:
		if str(f.kind) == "op" and int(f.owner) == P and str(f.get("card", "")) == "breach": fl = f
	var tip := "\n".join(PackedStringArray(g._flight_lines(fl))) if not fl.is_empty() else ""
	check(tip.contains("Chance: 25% (unscouted)"), "A Breach in flight is judged at its draw, after execution: 25%% when the Recon will be stale (%s)" % tip.replace("\n", " | "))
	check(g._miss_why(P, t, "breach", 1).contains("50%") and g._miss_why(P, t, "breach", 0).contains("25%"), "A miss is explained with the odds it was drawn at, not today's Recon")
	# the AI does not scout for an attack that resolves after any Recon sent now would be stale: a big spiral, far hosts
	g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = g.SIZE_PRESETS[2]; g._opt_enemies = 1; g._opt_seed = 3; g._opt_shape = "spiral"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER; R = g.RIVAL
	var far := -1
	var ai: int = R
	var prev := {int(g.rig[ai]): -1}   # the AI holds a long chain up to your main node (BFS path), then targets it
	var queue := [int(g.rig[ai])]
	while not queue.is_empty():
		var h: int = queue.pop_front()
		for nb in g.hosts[h].links:
			if not prev.has(int(nb)): prev[int(nb)] = h; queue.append(int(nb))
	var goal: int = int(g.rig[P])
	var step_h: int = int(prev.get(goal, -1))
	while step_h >= 0 and step_h != int(g.rig[ai]):
		g._capture(step_h, ai); step_h = int(prev[step_h])
	var rt: Array = g._attack_route(ai, goal)
	if not rt.is_empty() and g._travel_time(rt) + g._exec_time("breach", goal) > float(g.CARDS.recon.dur): far = goal
	if far >= 0:
		g.cards[ai] = {"breach": 1, "recon": 1}
		check(not g._ai_scout_first(ai, far, "breach") and g._held(ai, "recon") == 1, "The AI keeps its Recon when no Recon could still be fresh when the attack resolves")
	else:
		check(false, "a host whose Breach resolves later than a Recon stays fresh (%d hosts)" % g.hosts.size())
