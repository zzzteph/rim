extends SceneTree
## Paid conversion conservation, starvation, caps, packet funding and buffs.
var game
var checks := 0
var failures := []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func near(a: float, b: float) -> bool: return absf(a - b) < 0.00001
func fresh() -> int:
	if is_instance_valid(game): game.free()
	game = load("res://scripts/botnet_proto.gd").new(); game._opt_seed = 7
	root.add_child(game); game.set_process(false); game.ai_enabled = false; game._open_menu(false)
	for i in game.hosts.size():
		game.hosts[i].jobs = {}; game._set_builds(i, [])
	var home: int = game.rig[game.PLAYER]
	game.hosts[home].slots = 5; game.hosts[home].type = "pc"; game.hosts[home].value = 1; game.hosts[home].bots = 30.0
	for fac in game.botnets:
		game.cash[fac] = 0.0; game.creds[fac] = 0.0; game.research[fac] = 0.0; game.intel[fac] = 0.0
	return home
func run() -> void:
	for step in [1.0 / 60.0, 0.1, 1.0]:
		var home := fresh(); game._set_builds(home, ["cred", "lab"])
		game.intel[game.PLAYER] = 100.0; game.cash[game.PLAYER] = 100.0
		for tick in int(round(10.0 / step)): game._tick_production(step)
		check(near(game.creds[game.PLAYER],5.0) and near(game.intel[game.PLAYER],95.0), "Credentials consume exactly one Intel per output at dt=" + str(step))
		check(near(game.research[game.PLAYER],5.0) and near(game.cash[game.PLAYER],95.0), "Research consumes exactly one Crypto per output at dt=" + str(step))
	var home := fresh(); game._set_builds(home,["cash", "cred", "lab"])
	game._tick_production(10.0); game._emit_due()
	check(game.cash[game.PLAYER] == 0 and game.creds[game.PLAYER] == 0 and game.research[game.PLAYER] == 0 and game._crypto_credit.get(home,0) == 0, "Zero input gives zero output and no free initial Crypto packet")
	game.intel[game.PLAYER] = 0.5; game._tick_production(1.0)
	check(near(game._crypto_credit[home],0.2) and near(game.creds[game.PLAYER],0.3) and near(game.intel[game.PLAYER],0), "Scarce Intel shared proportionally across markets and harvesters")
	home = fresh(); game._set_builds(home,["cred","cred","lab","lab"])
	game.creds[game.PLAYER] = game._res_cap(game.PLAYER,"cred") - 0.2
	game.research[game.PLAYER] = game._res_cap(game.PLAYER,"lab") - 0.2
	game.intel[game.PLAYER] = 10.0; game.cash[game.PLAYER] = 10.0
	game._tick_production(1.0)
	check(near(game.intel[game.PLAYER],9.8) and near(game.cash[game.PLAYER],9.8), "Shared cap room charges only actual output")
	game._tick_production(1.0)
	check(near(game.intel[game.PLAYER],9.8) and near(game.cash[game.PLAYER],9.8), "Full storage consumes no input")
	home = fresh(); game._set_builds(home,["cash"]); game.intel[game.PLAYER] = 100.0
	for tick in 300:
		game._t += 0.1; game._tick_production(0.1); game._emit_due()
	check(near(game.cash[game.PLAYER],10.0) and near(game.intel[game.PLAYER],90.0) and near(game._crypto_credit[home],0), "Thirty seconds yields ten paid Crypto on an ordinary PC")
	game._t += 100; game._emit_due()
	check(near(game.cash[game.PLAYER],10.0), "A long clock jump cannot emit unfunded catch-up Crypto")
	home = fresh(); game._set_builds(home,["cash","cred","lab"])
	game.intel[game.PLAYER] = 100.0; game.cash[game.PLAYER] = 100.0
	game._apply_effect(game.RIVAL,game.CARDS.phishworm,home)
	game._tick_production(2.0)
	check(near(game.intel[game.PLAYER],100.0-5.0/3.0) and near(game.cash[game.PLAYER],99.0), "Victim funds phished conversions")
	check(near(game.cash[game.RIVAL],2.0/3.0) and near(game.creds[game.RIVAL],1.0) and near(game.research[game.RIVAL],1.0), "All funded resource output goes to phishing caster")
	check(game.creds[game.PLAYER] == 0 and game.research[game.PLAYER] == 0, "Phishing does not duplicate outputs")
	game._apply_effect(game.PLAYER,game.CARDS.response,home); game._tick_production(2.0)
	check(near(game.creds[game.PLAYER],1.0) and near(game.research[game.PLAYER],1.0), "Response restores paid production to owner")
	home = fresh(); game._set_builds(home,["cash","cred","lab","bot","intel"])
	game.intel[game.PLAYER] = 100.0; game.cash[game.PLAYER] = 100.0
	game._apply_effect(game.PLAYER,game.CARDS.cdn,home); game._tick_production(1.0)
	check(near(game._crypto_credit[home],2.0/3.0) and near(game.creds[game.PLAYER],1.0) and near(game.research[game.PLAYER],1.0), "CDN doubles all paid outputs")
	check(near(game.intel[game.PLAYER],100.0-5.0/3.0) and near(game.cash[game.PLAYER],99), "CDN preserves 1:1 input costs")
	check(near(game._intel_rate(game.PLAYER),4.0) and near(game._regen(home),2.0), "CDN doubles free Intel and bot production too")
	game._apply_effect(game.RIVAL,game.CARDS.ddos,home)
	var before: float = game.intel[game.PLAYER]; game._tick_production(1.0)
	check(near(before,game.intel[game.PLAYER]) and near(game.cash[game.PLAYER],99), "DDOS suppresses spending as well as output")
	home = fresh(); game._set_builds(home,["cred"]); game.intel[game.PLAYER] = 20
	game._toggle_producer(home,0); game._tick_production(5.0)
	check(near(game.intel[game.PLAYER],20) and game.creds[game.PLAYER] == 0 and game._res_cap(game.PLAYER,"cred") == game.RES_CAP_BASE + game.RES_CAP_PER_BUILD, "Paused producer consumes nothing and retains storage capacity")
	game._toggle_producer(home,0); game._tick_production(2.0)
	check(near(game.creds[game.PLAYER],1), "Producer resumes from click")
	game._toggle_producer(home,0); game.intel[game.PLAYER] = 60.0; game.cash[game.PLAYER] = 30.0
	game._start_job(home,"lab",0)
	check(not game._producer_paused(home,0), "Replacing a producer clears its pause state")
	# per-kind prices (cfg BUILD_COSTS): paid evenly over the build; a Research lab also takes Crypto
	var prices := {"intel": {"intel": 10.0}, "bot": {"intel": 30.0}, "cash": {"intel": 50.0}, "cred": {"intel": 50.0}, "lab": {"intel": 50.0, "cash": 25.0}}
	for kind in prices: check(game._build_cost(kind) == prices[kind], "%s price is %s" % [kind, str(prices[kind])])
	check(game.BUILD_KINDS.cash.name == "Crypto miner", "The Crypto building is a Crypto miner")
	home = fresh(); game.intel[game.PLAYER] = 50.0; game.cash[game.PLAYER] = 24.0
	check(not game._start_job(home, "lab", 0), "A lab cannot be queued without its Crypto")
	game.cash[game.PLAYER] = 25.0
	check(game._start_job(home, "lab", 0), "A lab queues with 50 Intel and 25 Crypto in the bank")
	game._tick_jobs(game.BUILD_TIME / 2.0)
	check(near(game.intel[game.PLAYER], 25.0) and near(game.cash[game.PLAYER], 12.5) and near(game.hosts[home].jobs[0].left, game.BUILD_TIME / 2.0), "Half the build pays half of each resource")
	game.cash[game.PLAYER] = 0.0
	var lab_left: float = game.hosts[home].jobs[0].left
	game._tick_jobs(1.0)
	check(near(game.hosts[home].jobs[0].left, lab_left) and near(game.intel[game.PLAYER], 25.0), "Out of Crypto, a lab waits and spends no Intel either")
	game.cash[game.PLAYER] = 100.0; game._tick_jobs(game.BUILD_TIME)
	check(game._built_kinds(home).has("lab") and near(game.intel[game.PLAYER], 0.0) and near(game.cash[game.PLAYER], 87.5), "A finished lab has paid exactly 50 Intel and 25 Crypto")
	home = fresh(); game._set_builds(home,["cred"]); game.intel[game.PLAYER] = 1.0
	var target: int = game.hosts[home].links[0]
	game.hosts[home].assign = target; game.hosts[home].live = true; game.hosts[home].mode = "attack"
	game._tick_production(1.0)
	check(near(game.intel[game.PLAYER],1.0) and game.creds[game.PLAYER] == 0, "Production reserves the next attack packet")
	home = fresh(); game._set_builds(home,["cash","cred","lab"])
	game.intel[game.PLAYER] = 10.0; game._start_job(home,"intel",3); game.intel[game.PLAYER] = 1.0
	game._tick_jobs(1.0); game._tick_production(1.0)
	check(near(game.hosts[home].jobs[3].left,9.0) and game.creds[game.PLAYER] == 0, "Construction funding precedes conversion spending")
	var report := {"checks":checks,"failures":failures}
	var file := FileAccess.open("res://review/implemented_ui/production_costs.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report)); game.free(); quit(0 if failures.is_empty() else 1)
