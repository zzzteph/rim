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
	game = load("res://scripts/botnet_proto.gd").new(); game._opt_seed = 7; game._opt_shape = "grid"
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
	var prices := {"intel": {"intel": 10.0}, "bot": {"cash": 30.0}, "cash": {"intel": 50.0}, "cred": {"intel": 50.0}, "lab": {"intel": 50.0, "cash": 25.0}}
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
	candidate_a()
	intel_full_cases()
	var report := {"checks":checks,"failures":failures}
	var file := FileAccess.open("res://review/implemented_ui/production_costs.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report)); game.free(); quit(0 if failures.is_empty() else 1)


# Economy candidate A (tools/balance/economy_handoff/HANDOFF.md): a Bot farm costs 30 Crypto; a harvester adds +15 Intel limit.
func paid(job: Dictionary, res: String) -> float: return float(game._job_cost_total(job).get(res, 0.0)) - float(game._job_cost_left(job).get(res, 0.0))
func candidate_a() -> void:
	var P: int = game.PLAYER
	check(near(game.INTEL_CAP_BASE, 100.0) and near(game.INTEL_CAP_PER_BUILD, 15.0), "Intel limit: base 100, +15 per harvester")
	# 1. Intel-rich, zero Crypto: rejected without resource loss (direct and through the command door)
	var home := fresh(); game.intel[P] = 100.0
	check(not game._start_job(home, "bot", 0), "A farm cannot be queued with Intel only")
	game._apply_cmd(P, ["build", home, 0, "bot"])
	check(near(game.intel[P], 100.0) and near(game.cash[P], 0.0) and game.hosts[home].jobs.is_empty(), "A rejected farm order costs nothing and leaves no job")
	# 2. 30 Crypto: accepted, paid evenly over ten funded seconds, no Intel
	home = fresh(); game.intel[P] = 7.0; game.cash[P] = 30.0
	check(game._start_job(home, "bot", 0), "30 Crypto and a free slot queue a farm")
	game._tick_jobs(5.0)
	check(near(game.cash[P], 15.0) and near(game.intel[P], 7.0) and near(game.hosts[home].jobs[0].left, 5.0), "Half the build pays 15 Crypto and no Intel")
	for k in 50: game._tick_jobs(0.1)
	check(game.hosts[home].builds[0] == "bot" and game.hosts[home].jobs.is_empty() and near(game.cash[P], 0.0) and near(game.intel[P], 7.0), "A finished farm has paid exactly 30 Crypto")
	# 3. three farm jobs admitted against one 30-Crypto bank: they share it, none is free, nothing goes negative
	home = fresh(); game.cash[P] = 30.0
	var all_in := true
	for s in 3: all_in = game._start_job(home, "bot", s) and all_in
	check(all_in, "Quotes are not reserved: three farms queue against 30 Crypto")
	var never_negative := true
	for k in 600:
		game._tick_jobs(0.1)
		if float(game.cash[P]) < -0.000001: never_negative = false
	var spent := 0.0
	for s in 3: spent += paid(game.hosts[home].jobs[s], "cash")
	check(never_negative and near(game.cash[P], 0.0) and absf(spent - 30.0) < 0.0001 and game._count_all(home, "bot") == 0, "With no income the three share 30 Crypto exactly and none finishes")
	check(game.hosts[home].jobs[0].short == "cash" and near(game.hosts[home].jobs[0].funding, 0.0), "A starved farm job reports Crypto as its shortage")
	game.cash[P] = 60.0
	for k in 100: game._tick_jobs(0.1)
	check(game._count_all(home, "bot") == 3 and game.hosts[home].jobs.is_empty() and near(game.cash[P], 0.0), "60 more Crypto finishes all three: 90 paid for three farms")
	# 4. research and a farm compete: research is paid first, the farm gets the rest and says why it is slow
	home = fresh(); game.cash[P] = 30.0; game.creds[P] = 100.0; game.research[P] = 100.0
	game._start_job(home, "bot", 0)
	game._queue_research(P, "supply:linked")
	game.cash[P] = 2.0
	game._tick_research(1.0); game._tick_jobs(1.0)
	var per_s: float = 40.0 / game._card_time("supply:linked")
	var job: Dictionary = game.hosts[home].jobs[0]
	check(near(game.lab[P].items[0].progress, 1.0) and near(job.left, 10.0 - (2.0 - per_s) / 3.0) and job.short == "cash" and near(game.cash[P], 0.0), "Card research spends Crypto before the farm job; the farm gets the remainder")
	game._tick_research(1.0); game._tick_jobs(1.0)
	check(str(game.lab[P].stall) == "cash" and job.short == "cash" and near(job.funding, 0.0), "At zero Crypto both report the same shortage")
	# 5. pause, cancel, replace
	home = fresh(); game.cash[P] = 60.0
	game._start_job(home, "bot", 0); game._do_toggle_job(P, home, 0); game._tick_jobs(5.0)
	check(near(game.cash[P], 60.0) and near(game.hosts[home].jobs[0].left, 10.0), "A paused farm job spends nothing")
	game._do_toggle_job(P, home, 0); game._tick_jobs(2.0)
	check(near(game.cash[P], 54.0), "Resumed, it pays again (6 Crypto in 2 s)")
	game._do_cancel_job(P, home, 0)
	check(near(game.cash[P], 54.0) and game.hosts[home].jobs.is_empty() and game.hosts[home].builds[0] == "", "Cancelling refunds nothing and leaves the slot empty")
	home = fresh(); game._set_builds(home, ["intel"]); game.cash[P] = 30.0
	check(game._start_job(home, "bot", 0) and game.hosts[home].jobs[0].phase == "demolish", "Replacing a harvester with a farm demolishes first")
	game._tick_jobs(4.9)
	check(near(game.cash[P], 30.0) and game.hosts[home].builds[0] == "intel", "Demolition pays nothing")
	game._tick_jobs(0.1)
	check(game.hosts[home].builds[0] == "" and game.hosts[home].jobs[0].phase == "build" and near(game.hosts[home].jobs[0].left, 10.0), "After 5 s the slot is clear and the farm's build starts")
	game._tick_jobs(10.0)
	check(game.hosts[home].builds[0] == "bot" and near(game.cash[P], 0.0), "The replacement farm costs its 30 Crypto")
	# 6. Intel limits: 8 / 10 harvesters; a loss clamps the surplus; a harvester still under construction adds nothing
	home = fresh(); game._set_builds(home, ["intel", "intel", "intel", "intel", "intel", "intel", "intel", "intel"])
	check(near(game._intel_cap(P), 220.0), "Eight harvesters: Intel limit 220")
	game.hosts[home].slots = 12; game._set_builds(home, ["intel", "intel", "intel", "intel", "intel", "intel", "intel", "intel", "intel", "intel"])
	check(near(game._intel_cap(P), 250.0), "Ten harvesters: Intel limit 250")
	game.intel[P] = 250.0; game._tick_intel(0.001)
	check(game.intel[P] <= 250.0 + 0.000001, "The bank stays at the limit")
	game._set_builds(home, ["intel", "intel", "intel", "intel", "intel", "intel", "intel", "intel"]); game._tick_intel(0.001)
	check(near(game.intel[P], 220.0), "Losing two harvesters clamps the bank to 220 at the next tick")
	game.intel[P] = 20.0; game._start_job(home, "intel", 8); game._start_job(home, "intel", 9)
	check(near(game._intel_cap(P), 220.0), "Harvesters under construction add no limit")
	# 7. miners: a cut route, a capture and pending packets never make free or usable Crypto
	home = fresh()
	var mid := -1; var far := -1
	for n in game.hosts[home].links:
		for m in game.hosts[int(n)].links:
			if int(m) != home and not game.hosts[home].links.has(m) and not game.hosts[int(m)].rig and not game.hosts[int(n)].rig and far < 0: mid = int(n); far = int(m)
	check(far >= 0, "Fixture: a host two streets from the rig")
	game.hosts[mid].owner = P; game.hosts[far].owner = P; game.hosts[far].type = "pc"; game.hosts[far].value = 1; game._set_builds(far, ["cash"])
	game.intel[P] = 50.0; game.hosts[mid].route_off = 30.0
	game._tick_production(3.0)
	check(near(game.intel[P], 50.0) and float(game._crypto_credit.get(far, 0.0)) == 0.0, "A miner whose road home is cut spends no Intel and makes no Crypto")
	game.hosts[mid].route_off = 0.0; game._tick_production(1.0)
	check(near(float(game._crypto_credit[far]), 1.0 / 3.0) and near(game.intel[P], 50.0 - 1.0 / 3.0), "With the road back it converts 1 Intel per Crypto")
	check(near(game.cash[P], 0.0) and not game._start_job(home, "bot", 0), "Crypto still in transit is not spendable: no farm")
	game._capture(far, game.RIVAL)
	check(not game._crypto_credit.has(far) and near(game.cash[P], 0.0) and near(game.cash[game.RIVAL], 0.0), "Capturing a miner destroys its unsent Crypto: nobody gets it free")
	game.hosts[far].owner = P; game._set_builds(far, ["cash"]); game.intel[P] = 50.0
	game._apply_effect(game.RIVAL, game.CARDS.ddos, far); game._tick_production(1.0)
	check(near(game.intel[P], 50.0) and float(game._crypto_credit.get(far, 0.0)) == 0.0, "DDOS on a miner stops its Crypto and its Intel spending")


func intel_full_cases() -> void:   # playtest #3: a full bank read "114/115 +0.0/s"
	var P: int = game.PLAYER
	var home := fresh(); game._set_builds(home, ["intel", "cash"])
	var cap: float = game._intel_cap(P)
	game.intel[P] = cap
	for k in int(6.0 / game.SIM_DT): game._sim_step(game.SIM_DT)
	var hud := str(game._hud_items()[0][1])
	check(near(game.intel[P], cap), "A full Intel bank ends every step exactly at its limit while a miner draws on it (%.5f of %d)" % [game.intel[P], int(cap)])
	check(hud.begins_with("%d/%d" % [int(cap), int(cap)]) and hud.contains("full") and not hud.contains("+0.0/s"), "The HUD reads 'full' at the limit, not 'limit-1 +0.0/s' (%s)" % hud)
	game.intel[P] = cap; game.cash[P] = 500.0
	check(game._start_job(home, "lab", 2) and game._start_job(home, "lab", 3), "Fixture: two labs under construction draw Intel")
	for k in int(5.0 / game.SIM_DT): game._sim_step(game.SIM_DT)
	hud = str(game._hud_items()[0][1])
	check(game.intel[P] < cap - 1.0 and not hud.contains("full"), "While Intel drains the HUD shows a rate, not 'full' (%s)" % hud)
