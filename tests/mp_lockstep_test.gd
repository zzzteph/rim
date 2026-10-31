extends SceneTree
## Multiplayer lockstep determinism: two screens (one plays faction 1, the other faction 2) start from the same
## match message and receive the same per-turn command lists, exactly as the server relays them. Their state
## fingerprints (_mp_hash) must match after every turn, with every command verb exercised (including garbage).
## A screen that differs only in its local PLAYER must not drift: nothing in the simulation may read it.
## godot --headless --path . --script tests/mp_lockstep_test.gd
var screens := []
var checks := 0
var failures := []
const TURNS := 600   # 600 turns × 3 steps × 1/30 s = 60 s of match: long enough for a 40-s research after its restart


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func make_screen(me: int):
	var g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	root.add_child(g); g.set_process(false)
	g._mp_start({"players": [{"faction": 1, "name": "Ada"}, {"faction": 2, "name": "Bo"}], "you": me,
		"turn_steps": 3, "delay": 2, "size": "medium", "seed": 4242})
	return g


func neutral_next_to(g, home: int) -> int:   # a neutral host next to any host of home's owner (a Breach can reach it)
	var fac := int(g.hosts[home].owner)
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != fac: continue
		for nb in g.hosts[i].links:
			if int(g.hosts[int(nb)].owner) == g.NEUTRAL: return int(nb)
	return -1


func soften(t: int) -> void:   # identical setup on every screen: make t an IoT host (security 1) so Breach can take it
	for g in screens:
		if t >= 0: g.hosts[t].type = "iot"


func script_for(g) -> Dictionary:   # turn -> {faction: [commands]}, every verb at least once, plus garbage
	var r1: int = int(g.rig[1]); var r2: int = int(g.rig[2])
	var n1 := neutral_next_to(g, r1); var n2 := neutral_next_to(g, r2)
	var s1: int = g._free_slot(r1); var s2: int = g._free_slot(r2)
	return {
		2: {1: [["build", r1, s1, "intel"], ["research", "exploit"], ["build", n1, 0, "bot"]],
			2: [["build", r2, s2, "bot"], ["queue", "breach", 1], ["queue", "breach", 2]]},
		5: {1: [["queue", "breach", 1], ["queue", "breach", 1], ["queue", "patch", 2]],   # a replayed command id adds nothing
			2: [["research", "ddos"], ["queue", "phish", 3], ["queue_pause"]]},
		9: {1: [["build", -5, "x", 7], ["build", r1, 0, "nuke"], ["card", "nope", 99999], ["research", "nope"],   # garbage: ignored alike
				["queue", "nope", 9], ["unqueue", 4242], ["reserve", 7], ["priority", "gold"], ["lane_make", 0], ["want", r1, "intel", 3], [], ["warp"]],
			2: [["job", r2, s2], ["job", r2, s2], ["queue_pause"], ["refill", r2]]},   # "refill", "job" and "produce" are retired verbs: ignored on both screens
		40: {1: [["cancel_research"], ["research", "exploit"]], 2: [["cancel", r2, s2]]},
		130: {1: [["card", "breach", n1]], 2: [["card", "breach", n2]]},
		180: {1: [["card", "patch", r1], ["produce", r1, s1]], 2: [["unqueue", 3], ["demolish", r2, s2]]},
		260: {1: [["produce", r1, s1], ["queue", "recon", 3]], 2: [["build", r2, s2, "wall"], ["refill_cancel", r2]]},   # (retired: ignored)
	}


func run() -> void:
	screens = [make_screen(1), make_screen(2)]
	var a = screens[0]; var b = screens[1]
	check(a._mp_on and b._mp_on and a.PLAYER == 1 and b.PLAYER == 2, "Both screens start the match, as faction 1 and faction 2")
	check(a.hosts.size() == b.hosts.size() and a.hosts.size() > 0 and a._mp_hash() == b._mp_hash(), "Same seed builds the same town on both screens")
	soften(neutral_next_to(a, int(a.rig[1]))); soften(neutral_next_to(a, int(a.rig[2])))
	for g in screens:   # the same well-stocked banks on both screens, so research and lanes run in the time the test has
		for fac in [1, 2]: g.bank[fac] = {"intel": 200.0, "cash": 150.0, "creds": 120.0, "research": 120.0}
	var plan := script_for(a)
	var n1 := neutral_next_to(a, int(a.rig[1]))
	var outpost := -1   # a remote host with a Bot station on every screen: its new workers join the pool, then serve every host
	for i in a.hosts.size():   # next to any host of faction 1, but not the one its Breach will take
		if int(a.hosts[i].owner) != 1 or outpost >= 0: continue
		for nb in a.hosts[i].links:
			if int(a.hosts[int(nb)].owner) == a.NEUTRAL and int(nb) != n1 and int(nb) != neutral_next_to(a, int(a.rig[2])): outpost = int(nb); break
	for g in screens:
		if outpost >= 0: g._capture(outpost, 1); g.hosts[outpost].slots = 3; g._set_builds(outpost, ["bot", "intel"])
	check(outpost >= 0 and a._mp_hash() == b._mp_hash(), "Both screens start with the same remote station")
	var start_owned := 0
	for i in a.hosts.size():
		if int(a.hosts[i].owner) != a.NEUTRAL: start_owned += 1
	# the server relays every turn to every screen: both factions' lists, empty when idle
	for g in screens:
		for t in range(g._mp_delay, TURNS + g._mp_delay):
			var turn: Dictionary = plan.get(t, {})
			g._mp_turns[t] = {1: (turn.get(1, []) as Array).duplicate(true), 2: (turn.get(2, []) as Array).duplicate(true)}
	var first_split := -1
	for t in TURNS:
		for g in screens:
			if not g._mp_ready(g._mp_turn): check(false, "turn %d is ready on faction %d's screen" % [t, g.PLAYER]); break
			g._mp_begin_turn()
			for s in g._mp_turn_steps: g._sim_step(g.SIM_DT)
			g._mp_end_turn()
		if first_split < 0 and a._mp_hash() != b._mp_hash(): first_split = t
	check(first_split < 0, "Fingerprints match after every one of %d turns%s" % [TURNS, "" if first_split < 0 else " (first split at turn %d)" % first_split])

	# the script really changed the match, identically (otherwise matching hashes prove nothing)
	var r1: int = int(a.rig[1]); var r2: int = int(a.rig[2])
	check(a._count_all(r1, "intel") >= 1 and b._count_all(r1, "intel") >= 1, "build: faction 1's Intel harvester stands on both screens")
	check(a._known(1, "exploit") and b._known(1, "exploit") and a._known(2, "ddos") and b._known(2, "ddos"), "research: both blueprints learned on both screens")
	check(a._mq(1).size() == b._mq(1).size() and a._mq(2).size() == b._mq(2).size() and a.workers.size() == b.workers.size(), "queue and workers: every faction's queue and worker identities agree (%d workers)" % a.workers.size())
	check(a._held(1, "breach") + a._mq_count(1, "breach") + int(a.card_plays.get(1, 0)) <= 3, "queue: the replayed command id made no extra copy")
	check(int(a.card_plays.get(1, 0)) >= 1 and int(a.card_plays.get(1, 0)) == int(b.card_plays.get(1, 0)), "card: faction 1's plays agree on both screens (%d)" % int(a.card_plays.get(1, 0)))
	var owned_a := []; var owned_b := []
	for i in a.hosts.size():
		owned_a.append(int(a.hosts[i].owner)); owned_b.append(int(b.hosts[i].owner))
	check(owned_a == owned_b, "Ownership of every host agrees")
	var end_owned := 0
	for o in owned_a:
		if int(o) != a.NEUTRAL: end_owned += 1
	check(a.intrusions_resolved >= 1 and a.intrusions_resolved == b.intrusions_resolved and end_owned >= start_owned,
		"Breach rolls resolved alike on both screens (%d resolved, owned %d -> %d), exercising flights, execution and the roll" % [a.intrusions_resolved, start_owned, end_owned])

	# negative control: one extra command on one screen must show up in the fingerprint
	b._apply_cmd(2, ["queue", "recon", 77])
	for s in 3:
		a._sim_step(a.SIM_DT); b._sim_step(b.SIM_DT)
	check(a._mp_hash() != b._mp_hash(), "A command applied on only one screen changes its fingerprint (the desync check can see drift)")

	print(JSON.stringify({"checks": checks, "failures": failures, "turns": TURNS}))
	for g in screens: g.free()
	quit(0 if failures.is_empty() else 1)
