extends SceneTree
## Run: godot --headless --path . --script tests/four_card_effect_test.gd
## Runtime checks against independently specified four-card values and graph fixtures.
const ORDER := ["phishworm", "zeroday", "ddos", "supply"]
const DURATIONS := {"phishworm": [30.0, 20.0, 10.0], "zeroday": [20.0], "ddos": [30.0, 20.0, 10.0, 5.0, 2.0], "supply": [0.0]}
const FRACTIONS := {"phishworm": 0.1, "zeroday": 0.75, "ddos": 0.0, "supply": 0.0}
var game
var checks := 0
var failures: Array = []
var chain_cases := []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); push_error(description)

func fresh() -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scripts/botnet_proto.gd").new()
	game.theme = load("res://assets/ui_theme.tres")
	game._opt_seed = 7; game._opt_size = Vector2i(6, 4)
	root.add_child(game)
	game.set_process(false); game.ai_enabled = false; game._open_menu(false)

func target_node() -> int:
	for i in game.hosts.size():
		if not bool(game.hosts[i].rig): return i
	return -1

func fixture(i: int, type := "erp", defenders := 30.0) -> void:
	game.hosts[i].owner = game.RIVAL; game.hosts[i].type = type
	game.hosts[i].bots = defenders; game.hosts[i].slots = 5; game.hosts[i].value = 3
	game.hosts[i].jobs = {}; game.hosts[i].prod_off = 0.0; game.hosts[i].route_off = 0.0
	game.hosts[i].steal_until = -100.0; game.hosts[i].steal_by = -1
	game._set_builds(i, ["cash", "cred", "lab", "intel", "intel"])

func graph(count: int, complete := false) -> Array:
	fresh()
	for host in game.hosts: host.links = []
	var nodes := []
	for i in game.hosts.size():
		if bool(game.hosts[i].rig): continue
		fixture(i); nodes.append(i)
		if nodes.size() == count: break
	for index in nodes.size():
		for next in range(index + 1, nodes.size()):
			if complete or next == index + 1: game._link(nodes[index], nodes[next])
	return nodes

func rates(fac: int) -> Vector4:
	return Vector4(game._cash_rate(fac), game._cred_rate(fac), game._research_rate(fac), game._intel_rate(fac))

func run() -> void:
	fresh()
	check(game.CARD_ORDER == ORDER and game.CARDS.size() == 4, "Runtime catalogue contains exactly four cards")
	var target := target_node()
	for card in ORDER:
		for type in game.NODE_TYPES:
			for defenders in [0.0, 1.0, 20.0, 30.0, 100.0]:
				for index in DURATIONS[card].size():
					fixture(target, type, defenders)
					game._apply_effect(game.PLAYER, game.CARDS[card], target, index + 1)
					var tag := "%s/%s/%s/level%d" % [card, type, defenders, index + 1]
					check(is_equal_approx(float(game.hosts[target].bots), defenders * (1.0 - float(FRACTIONS[card]))), "Exact defender effect: " + tag)
					check(game.hosts[target].owner == game.RIVAL, "Cards preserve ownership: " + tag)
					var route_seconds: float = DURATIONS[card][index] if card in ["zeroday", "ddos"] else 0.0
					check(is_equal_approx(float(game.hosts[target].route_off), route_seconds), "Exact routing duration: " + tag)
					var production_seconds: float = DURATIONS[card][index] if card == "ddos" else 0.0
					check(is_equal_approx(float(game.hosts[target].prod_off), production_seconds), "Exact production duration: " + tag)
					if card == "phishworm": check(is_equal_approx(float(game.hosts[target].steal_until) - game._t, float(DURATIONS[card][index])), "Exact theft duration: " + tag)
					if card == "supply": check(game._built_kinds(target).is_empty() and game.hosts[target].jobs.is_empty(), "All buildings cleared: " + tag)
	# The old IoT profile resists 90% of Phishing, but the new effects are fixed.
	fixture(target, "iot")
	game._apply_effect(game.PLAYER, game.CARDS.phishworm, target)
	check(is_equal_approx(float(game.hosts[target].bots), 27.0) and game._card_scale("phish", target) == 1.0, "Legacy resistance is bypassed")
	fixture(target)
	check(game._apply_effect(game.PLAYER, game.CARDS.phishworm, target, 4) == 0.0 and game.hosts[target].bots == 30.0, "Campaign cannot affect level4")
	check(game._apply_effect(game.PLAYER, game.CARDS.ddos, target, 6) == 0.0 and game.hosts[target].prod_off == 0.0, "DDOS cannot affect level6")
	for card in ["phishworm", "ddos"]:
		var nodes := graph(6)
		game._land_card(game.PLAYER, card + ":linked", nodes[0])
		for index in nodes.size():
			var hit: bool = index < DURATIONS[card].size()
			var duration: float = DURATIONS[card][index] if hit else 0.0
			var actual: float = maxf(0.0, float(game.hosts[nodes[index]].steal_until) - game._t) if card == "phishworm" else float(game.hosts[nodes[index]].prod_off)
			check(is_equal_approx(actual, duration), "%s linear chain level%d duration" % [card, index + 1])
			check(is_equal_approx(float(game.hosts[nodes[index]].bots), 27.0 if hit and card == "phishworm" else 30.0), "%s constant defender effect per node%d" % [card, index + 1])
		check(game._worms.size() == DURATIONS[card].size() - 1, "%s reaches the exact requested number of nodes" % card)
		chain_cases.append({"card": card, "graph": "six-node line", "affected_nodes": DURATIONS[card].size(), "durations": DURATIONS[card]})
	var short_chain := graph(2)
	game._land_card(game.PLAYER, "phishworm:linked", short_chain[0])
	check(game._worms.size() == 1 and game.hosts[short_chain[1]].steal_until == game._t + 20.0, "Campaign stops at a dead end")
	var blocked := graph(3); game.hosts[blocked[1]].owner = game.PLAYER
	game._land_card(game.PLAYER, "ddos:linked", blocked[0])
	check(game._worms.is_empty() and game.hosts[blocked[1]].prod_off == 0.0 and game.hosts[blocked[2]].prod_off == 0.0, "Spread never hits or passes through caster-owned nodes")
	for seed in [1, 7, 42, 99, 1234]:
		var nodes := graph(6, true); game.rng.seed = seed
		game._land_card(game.PLAYER, "ddos:linked", nodes[0])
		var durations := []
		for node in nodes:
			if game.hosts[node].prod_off > 0: durations.append(float(game.hosts[node].prod_off))
		durations.sort()
		check(durations == [2.0, 5.0, 10.0, 20.0, 30.0], "Branch/cycle fixture reaches five distinct nodes: seed%d" % seed)
		var visited := {nodes[0]: true}
		for hop in game._worms:
			check(not visited.has(hop.b) and game.hosts[hop.a].links.has(hop.b), "Every spread hop is adjacent and never revisits: seed%d" % seed)
			visited[hop.b] = true
	# Theft routes all HUD outputs; physical bot regeneration stays at its node.
	fresh(); target = target_node(); fixture(target)
	var before_player := rates(game.PLAYER); var before_owner := rates(game.RIVAL)
	game._apply_effect(game.PLAYER, game.CARDS.phishworm, target)
	var expected := Vector4(1.5, 0.75, 0.75, 3.0)
	check((rates(game.PLAYER) - before_player).is_equal_approx(expected), "All four producer outputs are gained by the caster")
	check((before_owner - rates(game.RIVAL)).is_equal_approx(expected), "All four producer outputs are lost by the owner")
	game._t = 30.01
	check(game._benef(target) == game.RIVAL, "Production returns when theft expires")
	fixture(target, "erp", 20.0); before_player = rates(game.PLAYER)
	game._apply_effect(game.PLAYER, game.CARDS.phishworm, target)
	check((rates(game.PLAYER) - before_player).is_equal_approx(Vector4(1.5, 0.75, 0.75, 1.5)), "Post-damage Shaky production matches the independent model")
	fresh(); var home: int = game.rig[game.RIVAL]
	game.hosts[home].bots = 30.0; game._set_builds(home, ["bot", "bot"])
	var native_before: float = game._intel_rate(game.PLAYER); var regen_before: float = game._regen(home)
	game._apply_effect(game.PLAYER, game.CARDS.phishworm, home)
	check(is_equal_approx(game._intel_rate(game.PLAYER) - native_before, game.RIG_INTEL), "Phishing also steals a rig's native Intel output")
	check(is_equal_approx(game._regen(home), regen_before), "Phishing leaves physical bot regeneration at the target")
	# Supply clears paused/active replacements too, without returning spent Intel.
	fresh(); target = target_node(); fixture(target, "erp", 60.0)
	game._set_builds(target, ["bot", "cash", "lab", "intel", "cred"]); game.intel[game.RIVAL] = 100.0
	check(game._start_job(target, "intel", 0) and game._start_job(target, "lab", 1), "Wipe fixture queues two replacements")
	game._tick_jobs(5.0); game._tick_jobs(1.0)
	var intel_before: float = game.intel[game.RIVAL]
	check(intel_before < 100.0 and game.hosts[target].jobs[0].cost_left < game.BUILD_COST_INTEL, "Wipe fixture has spent Intel on funded construction")
	game.hosts[target].jobs[0]["paused"] = true
	game._apply_effect(game.PLAYER, game.CARDS.supply, target)
	check(game.hosts[target].bots == 60.0 and game.hosts[target].owner == game.RIVAL, "Supply preserves defenders and owner, even above reduced storage")
	check(game.hosts[target].jobs.is_empty() and game._built_kinds(target).is_empty(), "Supply cancels all replacements and removes all slot buildings")
	check(game.intel[game.RIVAL] == intel_before, "Supply never refunds spent construction Intel")
	game._tick_jobs(20.0)
	check(game._built_kinds(target).is_empty(), "Cancelled construction cannot recreate a wiped building")
	game._apply_effect(game.PLAYER, game.CARDS.supply, game.rig[game.RIVAL])
	check(game._intel_rate(game.RIVAL) >= game.RIG_INTEL, "Slot wipe preserves a surviving rig's native Intel output")
	check("-10%" in game._effect_text(game.CARDS.phishworm, target, 1.0, 3) and "10 s" in game._effect_text(game.CARDS.phishworm, target, 1.0, 3), "Campaign preview uses the correct hit-level duration")
	check("-75%" in game._effect_text(game.CARDS.zeroday, target, 1.0) and "20 s" in game._effect_text(game.CARDS.zeroday, target, 1.0), "0day preview matches exact damage and duration")
	var result := {"model_version": 2, "checks": checks, "failures": failures, "chain_cases": chain_cases, "seed_and_trial_count": {"seeds": [1, 7, 42, 99, 1234], "trials": 5}, "scope": "Runtime effect fidelity, resource beneficiary and bounded graph spread; no human playtest or metagame verdict"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/implemented_ui"))
	var file := FileAccess.open("res://review/implemented_ui/four_card_effect_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t")); file.close()
	print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
