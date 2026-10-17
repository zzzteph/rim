extends SceneTree
## Run: godot --headless --path . --script tests/ai_card_smoke_test.gd
## Exercises AI research, attack/protection casting and paid production.

var checks := 0
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var scenarios := []
	for scenario in [
		{"size": Vector2i(6, 4), "enemies": 1, "seed": 7},
		{"size": Vector2i(8, 6), "enemies": 3, "seed": 33},
	]:
		var game = load("res://scripts/botnet_proto.gd").new()
		game.theme = load("res://assets/ui_theme.tres")
		game._opt_size = scenario.size; game._opt_enemies = scenario.enemies; game._opt_seed = scenario.seed
		root.add_child(game); game.set_process(false); game._open_menu(false)
		for faction in game.ais:
			game.cash[faction] = 200.0; game.creds[faction] = 100.0; game.research[faction] = 100.0
			for card in game.CARD_ORDER: game.cards[faction][game._card_key(card, "linked")] = 1
		var stocks_valid := true
		var queues_valid := true
		var defensive_cast := false
		for frame in 5400:
			if game.won or game.lost: break
			game._process(1.0 / 30.0)
			for host in game.hosts:
				if game.ais.has(int(host.owner)) and float(host.get("patch_until", 0.0)) > game._t: defensive_cast = true
			for faction in game.botnets:
				if float(game.intel[faction]) < -0.00001 or float(game.cash[faction]) < -0.00001 or float(game.creds[faction]) < -0.00001 or float(game.research[faction]) < -0.00001: stocks_valid = false
				for key in game.lab[faction].queue:
					if not game.CARD_ORDER.has(game._card_of(str(key))): queues_valid = false
		var plays := 0
		for faction in game.ais: plays += int(game.card_plays.get(faction, 0))
		check(game._t > 10.0, "AI match advances with seed %d" % scenario.seed)
		check(stocks_valid, "AI card research keeps resource stocks nonnegative: seed %d" % scenario.seed)
		check(queues_valid, "AI research uses the current eight-card catalogue: seed %d" % scenario.seed)
		check(plays > 0, "AI can cast retained cards: seed %d" % scenario.seed)
		check(defensive_cast, "AI applies protection to its own network: seed %d" % scenario.seed)
		scenarios.append({"seed": scenario.seed, "map": str(scenario.size), "enemies": scenario.enemies, "simulated_seconds": game._t, "ai_card_plays": plays, "won": game.won, "lost": game.lost})
		game.free()
	_zero_crypto_fixture()
	var bootstrap := _zero_crypto_matches()
	var report := {"checks": checks, "failures": failures, "scenarios": scenarios, "zero_crypto_bootstrap": bootstrap, "scope": "Deterministic AI integration smoke, not a difficulty or pacing verdict"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/implemented_ui"))
	var file := FileAccess.open("res://review/implemented_ui/ai_card_smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _jobs_of(g, fac: int, kind: String) -> int:
	var n := 0
	for h in g.hosts:
		if int(h.owner) != fac: continue
		for job in (h.jobs as Dictionary).values():
			if str(job.kind) == kind: n += 1
	return n


func _built_of(g, fac: int, kind: String) -> int:
	var n := 0
	for h in g.hosts:
		if int(h.owner) == fac: n += (h.builds as Array).count(kind)
	return n


# Farms cost Crypto (economy candidate A). A Normal AI with Intel but no Crypto that wants a frontier farm must build a
# miner instead of re-ordering the impossible farm forever, must not stack bootstrap miners, and must hold its labs and
# research while it saves Crypto for the farm — then resume exactly them.
func _zero_crypto_fixture() -> void:
	var g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(6, 4); g._opt_enemies = 2; g._opt_seed = 7
	root.add_child(g); g.set_process(false); g._open_menu(false)
	var f: int = int(g.ais[0]); var r: int = int(g.rig[f]); var p := -1
	for o in g.hosts[r].links:
		if int(g.hosts[int(o)].owner) == f: p = int(o)
	var border := -1
	for o in g.hosts[p].links:
		if int(o) != r and not g.hosts[int(o)].rig and int(g.hosts[int(o)].owner) == g.NEUTRAL and border < 0: border = int(o)
	check(p >= 0 and border >= 0, "Fixture: the AI's second host and a neutral neighbour of it")
	g.hosts[border].owner = g.PLAYER   # p now faces a botnet with a single farm: the AI wants a second farm there
	var q := -1                        # a full rear host of harvesters: Intel income is no excuse to skip the farm
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != f: continue
		for o in g.hosts[i].links:
			var oi := int(o)
			if q >= 0 or oi == border or g.hosts[oi].rig or int(g.hosts[oi].owner) != g.NEUTRAL or g.hosts[oi].links.has(border): continue
			q = oi
	check(q >= 0, "Fixture: a third host away from the border")
	g.hosts[q].owner = f; g.hosts[q].slots = 3; g._set_builds(q, ["intel", "intel", "intel"]); g.hosts[q].bots = 30.0; g.hosts[q].type = "pc"
	g.hosts[p].slots = 4; g._set_builds(p, ["bot"])   # room for a miner and two more farms
	g.intel[f] = 100.0; g.cash[f] = 0.0
	check(float(g._build_cost("bot").get("cash", 0.0)) > 0.0 and g._count_all(p, "bot") == 1 and g._free_slot(p) >= 0, "Fixture: farms cost Crypto; the frontier host has one farm and a free slot")
	g._ai_think(f)
	check(_jobs_of(g, f, "cash") == 1 and _jobs_of(g, f, "bot") == 0, "Zero Crypto: the AI starts a miner instead of the farm it cannot afford")
	for k in 5: g._ai_think(f)
	check(_jobs_of(g, f, "cash") == 1 and _jobs_of(g, f, "bot") == 0, "Repeated thinks keep that one bootstrap miner (no duplicates, no farm loop)")
	var miner_host := -1
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == f:
			for job in (g.hosts[i].jobs as Dictionary).values():
				if str(job.kind) == "cash": miner_host = i
	check(miner_host == r or not g._route(miner_host, r).is_empty(), "The bootstrap miner sits where its Crypto has a road home")
	g.intel[f] = 100.0
	for k in 120: g._tick_jobs(0.1)
	check(_built_of(g, f, "cash") == 1 and _jobs_of(g, f, "cash") == 0, "The bootstrap miner finishes")
	g.cash[f] = 0.0; g.intel[f] = 100.0
	for k in 3: g._ai_think(f)
	check(_jobs_of(g, f, "bot") == 0 and _jobs_of(g, f, "cash") == 0, "With a working miner it saves Crypto for the farm instead of stacking miners")
	g.cash[f] = 35.0; g._ai_think(f)
	check(_jobs_of(g, f, "bot") == 1, "With 30 Crypto free it orders the farm")
	g._ai_think(f)
	check(_jobs_of(g, f, "bot") == 1, "The farm's unpaid Crypto counts as spent: no second farm on the same 35")
	# labs and research wait while it saves, and resume afterwards
	g._set_builds(q, ["lab", "intel", "intel"])
	g._queue_research(f, "zeroday:linked")
	g.cash[f] = 10.0; g._ai_think(f)
	check(bool(g.lab[f].items[0].paused) and g._producer_paused(q, 0), "Saving Crypto for a farm pauses its research and its lab (the player's own controls)")
	g.cash[f] = 200.0; g._ai_think(f)
	check(_jobs_of(g, f, "bot") == 2, "With Crypto to spare it orders the next farm")
	check(not bool(g.lab[f].items[0].paused) and not g._producer_paused(q, 0), "Covered, it resumes exactly the research and lab it paused")
	g.free()


# Normal start, no grants, AI-only: every Normal AI reaches a miner, never stacks bootstrap miners, and its stocks stay
# nonnegative. The times are a record, not a pacing verdict.
func _zero_crypto_matches() -> Array:
	var out := []
	for seed in [7, 19, 43]:
		var g = load("res://scripts/botnet_proto.gd").new()
		g.theme = load("res://assets/ui_theme.tres")
		g._opt_size = Vector2i(6, 4); g._opt_enemies = 2; g._opt_seed = seed
		root.add_child(g); g.set_process(false); g._open_menu(false)
		var start_farms := {}; var first_miner := {}; var first_farm := {}; var stacked := false; var negative := false
		for f in g.ais: start_farms[f] = _built_of(g, int(f), "bot"); check(float(g.cash[f]) == 0.0, "Seed %d: AI %d starts with 0 Crypto" % [seed, int(f)])
		for frame in 30 * 300:
			if g.won or g.lost: break
			g._sim_step(g.SIM_DT)
			if frame % 15 != 0: continue
			for f in g.ais:
				var fi := int(f)
				if g._eliminated.has(fi): continue
				if not first_miner.has(fi) and (_jobs_of(g, fi, "cash") > 0 or _built_of(g, fi, "cash") > 0): first_miner[fi] = snappedf(g._t, 0.1)
				if not first_farm.has(fi) and _built_of(g, fi, "bot") > int(start_farms[f]): first_farm[fi] = snappedf(g._t, 0.1)
				if _built_of(g, fi, "cash") == 0 and _jobs_of(g, fi, "cash") > 1: stacked = true
				if float(g.cash[fi]) < -0.00001 or float(g.intel[fi]) < -0.00001: negative = true
		for f in g.ais:
			check(first_miner.has(int(f)) and float(first_miner[int(f)]) <= 120.0, "Seed %d: AI %d has a miner by 120 s from a 0-Crypto start" % [seed, int(f)])
		check(not stacked, "Seed %d: no AI stacks bootstrap miners" % seed)
		check(not negative, "Seed %d: AI Intel and Crypto stay nonnegative" % seed)
		out.append({"seed": seed, "first_miner_s": first_miner, "first_new_farm_s": first_farm, "t": snappedf(g._t, 0.1), "cause": str(g._end_cause)})
		g.free()
	return out
