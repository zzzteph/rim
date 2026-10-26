extends SceneTree
## Runtime effects, friendly targeting, spread, shielding and probabilistic capture.
var game
var checks := 0
var failures := []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func fresh() -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scripts/botnet_proto.gd").new()
	game.theme = load("res://assets/ui_theme.tres"); game._opt_seed = 7
	root.add_child(game); game.set_process(false); game.ai_enabled = false; game._open_menu(false)
func fixture(i: int, owner: int, type := "pc") -> void:
	game.hosts[i].owner = owner; game.hosts[i].type = type; game.hosts[i].bots = 30.0
	game.hosts[i].slots = 5; game.hosts[i].value = 1; game.hosts[i].jobs = {}
	for key in ["prod_off", "route_off", "boost_until", "patch_until", "sca_until", "steal_until"]: game.hosts[i][key] = 0.0
	game.hosts[i].steal_by = -1; game.hosts[i].producer_paused = {}; game.hosts[i].erase("card_result")
	game._set_builds(i, ["bot", "intel", "cash", "cred", "lab"])
func graph(owned := false, complete := false) -> Array:
	fresh()
	for host in game.hosts: host.links = []
	var nodes := []
	for i in game.hosts.size():
		if game.hosts[i].rig: continue
		fixture(i, game.PLAYER if owned else game.RIVAL); nodes.append(i)
		if nodes.size() == 6: break
	for a in nodes.size():
		for b in range(a + 1, nodes.size()):
			if complete or b == a + 1: game._link(nodes[a], nodes[b])
	return nodes
func run() -> void:
	fresh()
	check(game.CARD_ORDER.size() == 8, "Eight unique attack/protection cards")
	for defense in game.CfgCards.DEFENSE_ORDER:
		var cd: Dictionary = game.CARDS[defense]; var attack: Dictionary = game.CARDS[cd.pair]
		for resource in cd.cost: check(cd.cost[resource] == attack.cost[resource] * 2, defense + " doubled " + resource)
		check(game._card_levels(cd) == 5, defense + " five hosts")
	for card in ["phishworm", "ddos"]:
		var nodes := graph(); game._land_card(game.PLAYER, card + ":linked", nodes[0])
		var durations: Array = [30.0, 20.0, 10.0] if card == "phishworm" else [30.0, 20.0, 10.0, 5.0, 2.0]
		for k in nodes.size():
			var expected: float = durations[k] if k < durations.size() else 0.0
			if card == "phishworm" and expected > 0.0: expected *= clampf(1.0 + float(game._faction_nodes(game.RIVAL)) / 20.0, 1.0, 2.0)   # longer on a big network
			var actual: float = game.hosts[nodes[k]].steal_until if card == "phishworm" else game.hosts[nodes[k]].prod_off
			check(is_equal_approx(actual, expected), "%s duration on successive host %d" % [card,k])
			var route_expected: float = expected if card == "ddos" else 0.0
			check(game.hosts[nodes[k]].bots == 30.0 and is_equal_approx(game.hosts[nodes[k]].route_off, route_expected), card + (" cuts routing for its level's duration" if card == "ddos" else " leaves routes intact") + " and keeps defenders")
	for card in game.CfgCards.DEFENSE_ORDER:
		var nodes := graph(true)
		for node in nodes: game.hosts[node].steal_by = game.RIVAL; game.hosts[node].steal_until = 100.0
		game._land_card(game.PLAYER, card + ":linked", nodes[0])
		check(game._worms.size() == 4, card + " visits five owned hosts")
		for k in nodes.size():
			var h: Dictionary = game.hosts[nodes[k]]
			var applied: bool = h.boost_until == 10.0 if card == "cdn" else (h.patch_until == 30.0 if card == "patch" else (h.sca_until == 60.0 if card == "sca" else h.steal_by == -1))
			check(applied == (k < 5), card + " owns-only chain boundary")
		var blocked := graph(true); game.hosts[blocked[1]].owner = game.RIVAL
		game._land_card(game.PLAYER, card + ":linked", blocked[0])
		check(game._worms.is_empty(), card + " cannot cross a foreign bridge")
	for seed in [1,7,42,99,1234]:
		var nodes := graph(true, true); game.rng.seed = seed
		game._land_card(game.PLAYER, "patch:linked", nodes[0])
		var seen := {nodes[0]: true}
		for hop in game._worms:
			check(not seen.has(hop.b) and game.hosts[hop.a].links.has(hop.b), "Defense cycle uses distinct adjacent hosts")
			seen[hop.b] = true
		check(seen.size() == 5, "Defense branch stops at five")
	var nodes := graph(true); var target: int = nodes[0]
	game.hosts[target].prod_off = 20.0
	game._apply_effect(game.PLAYER, game.CARDS.cdn, target)
	check(game.hosts[target].prod_off == 0 and game._production_multiplier(target) == 1, "CDN clears DDOS without granting a new boost")
	game._apply_effect(game.PLAYER, game.CARDS.cdn, target)
	game._apply_effect(game.PLAYER, game.CARDS.cdn, target)
	check(game._production_multiplier(target) == 2 and game._regen(target) == 2.0, "CDN doubles bots and never stacks to x4")
	game._t = 10.0
	check(game._production_multiplier(target) == 1, "CDN expires at ten seconds")
	for shield in ["patch", "sca"]:
		game._t = 0.0; fixture(target, game.PLAYER)
		game._apply_effect(game.PLAYER, game.CARDS[shield], target)
		game.hosts[target].jobs = {0: {"kind":"bot"}}
		game._crypto_credit[target] = 0.5
		check(game._apply_effect(game.RIVAL, game.CARDS.supply, target) == -1 and game.hosts[target].bots == 30.0 and game.hosts[target].jobs.size() == 1, shield + " blocks complete wipe")
		check("blocked" in game._effect_text(game.CARDS.supply,target,1.0,1,true), "Landing feedback reports shield block")
		check("stolen" in game._effect_text(game.CARDS.phishworm,target,1.0), "Previous shield outcome cannot contaminate another card preview")
		if shield == "patch": check(game._apply_effect(game.RIVAL, game.CARDS.zeroday, target) == -1 and game.hosts[target].owner == game.PLAYER, "Patch blocks 0day before RNG")
		game._t = 30.0 if shield == "patch" else 60.0
		game._apply_effect(game.RIVAL, game.CARDS.supply, target)
		check(game.hosts[target].owner == game.PLAYER and game.hosts[target].bots == 0.0 and game._built_kinds(target).is_empty() and game.hosts[target].jobs.is_empty() and not game._crypto_credit.has(target), shield + " exact expiry permits complete wipe but preserves ownership")
	fixture(target, game.PLAYER); game._t = 0
	game._apply_effect(game.RIVAL, game.CARDS.phishworm, target)
	game._apply_effect(game.PLAYER, game.CARDS.response, target)
	check(not game._stolen(target), "Response ends theft immediately")
	game._apply_effect(game.RIVAL, game.CARDS.phishworm, target)
	check(game._stolen(target), "Response does not add unrequested immunity")
	# Stable RNG sample with actual captures. Every success must have valid nonnegative defenders.
	game.rng.seed = 98123; var captures := 0
	for trial in 2000:
		fixture(target, game.RIVAL)
		var result: float = game._apply_effect(game.PLAYER, game.CARDS.zeroday, target)
		if result == 1.0: captures += 1
		check((game.hosts[target].owner == game.PLAYER and game.hosts[target].bots == 0.0) if result == 1.0 else (game.hosts[target].owner == game.RIVAL and game.hosts[target].bots == 30.0 and game._built_kinds(target).size() == 5), "0day either captures or leaves host intact")
	check(captures >= 1420 and captures <= 1580, "Seeded 0day rate agrees with 75% within four percentage points")
	fresh(); var home: int = game.rig[game.PLAYER]; var foreign: int = game.hosts[home].links[0]
	for card in game.CARD_ORDER: game.cards[game.PLAYER][card + ":linked"] = 1
	check(game._can_play(game.PLAYER, "patch:linked", home) == "", "Protection can target own rig")
	check(game._can_play(game.PLAYER, "patch:linked", foreign) != "" and game._can_play(game.PLAYER, "ddos:linked", home) != "", "Attack and protection target restrictions")
	check(game._play_card(game.PLAYER, "patch:linked", home), "Protection launches onto its own source")
	game._deliver_due()
	check(game.hosts[home].get("patch_until", 0) > game._t and game._held(game.PLAYER, "patch:linked") == 0, "Own-rig packet lands and consumes one card")
	game._land_card(game.PLAYER, "cdn:linked", foreign)
	check(game.hosts[foreign].get("boost_until", 0) == 0, "Lost ownership in transit prevents defensive landing")
	fixture(home, game.PLAYER)
	game._apply_effect(game.RIVAL, game.CARDS.ddos, home)
	check(game._intel_rate(game.PLAYER) == 0 and game._regen(home) == 0 and game._cred_rate(game.PLAYER) == 0 and game._research_rate(game.PLAYER) == 0 and game._cash_rate(game.PLAYER) == 0, "DDOS stops every production type including native rig Intel")
	game._apply_effect(game.PLAYER, game.CARDS.cdn, home)
	check(game._intel_rate(game.PLAYER) > 0 and game._production_multiplier(home) == 1, "CDN restores DDOS production without boosting")
	# 0day needs one of your connections; DDOS cuts routing, CDN restores it, and a cut rig can still defend itself
	fresh(); home = game.rig[game.PLAYER]; foreign = game.hosts[home].links[0]
	game.hosts[foreign].owner = game.RIVAL
	for card in ["zeroday", "cdn", "phishworm"]: game.cards[game.PLAYER][card + ":linked"] = 1
	check("connection" in game._can_play(game.PLAYER, "zeroday:linked", foreign), "0day refuses a host without one of your connections")
	game.sel = {home: true}; game._wire(foreign)
	check(game._linked(game.PLAYER, foreign) and game._can_play(game.PLAYER, "zeroday:linked", foreign) == "", "A dormant connection is enough to aim 0day")
	game._apply_effect(game.RIVAL, game.CARDS.ddos, home)
	check(game._routing_down(home) and game._prod_down(home), "DDOS cuts routing as well as production")
	check(game._can_play(game.PLAYER, "phishworm:linked", foreign) != "" and game._can_play(game.PLAYER, "cdn:linked", home) == "", "A DDOSed rig cannot send attacks but can still defend itself")
	game._apply_effect(game.PLAYER, game.CARDS.cdn, home)
	check(not game._routing_down(home) and not game._prod_down(home) and game._production_multiplier(home) == 1, "CDN restores routing and production after DDOS")
	var report := {"checks":checks,"failures":failures,"zero_day_trials":2000,"zero_day_captures":captures}
	var file := FileAccess.open("res://review/implemented_ui/four_card_effects.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report)); game.free(); quit(0 if failures.is_empty() else 1)
