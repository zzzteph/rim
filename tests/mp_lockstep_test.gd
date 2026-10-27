extends SceneTree
## Multiplayer lockstep determinism: two screens (one plays faction 1, the other faction 2) start from the same
## match message and receive the same per-turn command lists, exactly as the server relays them. Their state
## fingerprints (_mp_hash) must match after every turn, with every command verb exercised (including garbage).
## A screen that differs only in its local PLAYER must not drift: nothing in the simulation may read it.
## godot --headless --path . --script tests/mp_lockstep_test.gd
var screens := []
var checks := 0
var failures := []
const TURNS := 360   # 360 turns × 3 steps × 1/30 s = 36 s of match


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
		2: {1: [["build", r1, s1, "intel"], ["research", "exploit"], ["reserve", 5], ["priority", "cash"]],
			2: [["build", r2, s2, "bot"], ["lane_set", 0, "breach"], ["lane_make", 0]]},
		5: {1: [["lane_set", 0, "breach"], ["lane_repeat", 0], ["lane_set", 1, "patch"], ["lane_make", 1]],
			2: [["research", "ddos"], ["card_action", "phish"]]},
		9: {1: [["build", -5, "x", 7], ["build", r1, 0, "nuke"], ["card", "nope", 99999], ["research", "nope"],   # garbage: ignored alike
				["lane_set", 0, "nope"], ["lane_make", 42], ["reserve", 7], ["priority", "gold"], [], ["warp"]],
			2: [["job", r2, s2], ["job", r2, s2], ["priority", "research"]]},
		40: {1: [["cancel_research"], ["research", "exploit"]], 2: [["cancel", r2, s2]]},
		130: {1: [["card", "breach", n1]], 2: [["card", "breach", n2]]},
		180: {1: [["card", "patch", r1], ["produce", r1, s1]], 2: [["lane_cancel", 0], ["demolish", r2, s2]]},
		260: {1: [["produce", r1, s1], ["lane_repeat", 0]], 2: [["build", r2, s2, "wall"], ["reserve", 0]]},
	}


func run() -> void:
	screens = [make_screen(1), make_screen(2)]
	var a = screens[0]; var b = screens[1]
	check(a._mp_on and b._mp_on and a.PLAYER == 1 and b.PLAYER == 2, "Both screens start the match, as faction 1 and faction 2")
	check(a.hosts.size() == b.hosts.size() and a.hosts.size() > 0 and a._mp_hash() == b._mp_hash(), "Same seed builds the same town on both screens")
	soften(neutral_next_to(a, int(a.rig[1]))); soften(neutral_next_to(a, int(a.rig[2])))
	var plan := script_for(a)
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
	check(int(a.bot_reserve.get(2, -1)) == 0 and int(b.bot_reserve.get(1, -1)) == 5, "reserve: each faction's reserve applied everywhere")
	check(int(a.card_plays.get(1, 0)) >= 1 and int(a.card_plays.get(1, 0)) == int(b.card_plays.get(1, 0)), "card: faction 1's plays agree on both screens (%d)" % int(a.card_plays.get(1, 0)))
	var owned_a := []; var owned_b := []
	for i in a.hosts.size():
		owned_a.append(int(a.hosts[i].owner)); owned_b.append(int(b.hosts[i].owner))
	check(owned_a == owned_b, "Ownership of every host agrees")
	var end_owned := 0
	for o in owned_a:
		if int(o) != a.NEUTRAL: end_owned += 1
	check(end_owned > start_owned, "A Breach capture landed during the match (owned %d -> %d), exercising flights and execution" % [start_owned, end_owned])

	# negative control: one extra command on one screen must show up in the fingerprint
	b._apply_cmd(2, ["reserve", 20])
	for s in 3:
		a._sim_step(a.SIM_DT); b._sim_step(b.SIM_DT)
	check(a._mp_hash() != b._mp_hash(), "A command applied on only one screen changes its fingerprint (the desync check can see drift)")

	print(JSON.stringify({"checks": checks, "failures": failures, "turns": TURNS}))
	for g in screens: g.free()
	quit(0 if failures.is_empty() else 1)
