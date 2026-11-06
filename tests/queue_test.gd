extends SceneTree
## The manufacturing queue: one first-in-first-out list of at most four copies, the one being made included. The head
## pays when it starts, from main-node stock no worker has claimed; a head that cannot start says why and nothing
## overtakes it. Removing a waiting entry costs nothing; cancelling the paid head refunds its unworked share. Pause is
## separate from the queue. The ready inventory (12) is separate and holds the copy being made and cards that may return.
## godot --headless --path . --script tests/queue_test.gd
var g
var P := 1
var checks := 0
var failures := []


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func fresh() -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 11; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER
	g.bank[P] = full_bank()
	g.cards[P] = {}
	g.known[P]["breach"] = true


func full_bank(given := {}) -> Dictionary:   # every resource at its bank cap (plenty for any price), except the amounts given
	var out := {}
	for r in g.RES: out[r] = float(given.get(r, g._cap(P, r)))
	return out


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func recipes() -> Array:
	var out := []
	for j in g._mq(P): out.append(str(j.recipe))
	return out


var _cid := 1000
func queue(recipe: String) -> void:
	_cid += 1
	g._cmd(["queue", recipe, _cid])


func run() -> void:
	capacity_and_order()
	waiting_head()
	head_paid_first()
	held_text()
	ready_full_holds_nothing()
	research_after_projects()
	paused_head_chip()
	full_hand()
	pause_and_cancel()
	command_ids()
	ai_queue()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func head_paid_first() -> void:   # (0.6.27) the head pays as it is made; research leaves alone what it pays over the next cycle
	fresh()
	var price: Dictionary = g._recipe_cost("breach")
	var mt: float = g._make_time("breach")
	var share: float = minf(1.0, g.PROD_CYCLE / mt)
	g.bank[P] = full_bank()
	queue("breach")
	step(0.1)
	var paid0: Dictionary = (g._mq(P)[0].paid as Dictionary).duplicate()
	check(not paid0.is_empty() and float(paid0.get("intel", 0.0)) < 0.05 * float(price.intel) + 0.001, "A copy starts at once and pays only for the work done so far (%s of %s Intel after 0.1 s)" % [g._amt(float(paid0.get("intel", 0.0))), g._amt(float(price.intel))])
	step(0.5 * mt - 0.1)
	var half: float = float((g._mq(P)[0].paid as Dictionary).get("intel", 0.0))
	check(absf(half - 0.5 * float(price.intel)) < 0.06 * float(price.intel), "Half-way through it has paid half its price (%s of %s Intel)" % [g._amt(half), g._amt(float(price.intel))])
	check(absf(float(g._head_owed(P).get("intel", 0.0)) - minf(float(price.intel) - half, float(price.intel) * share)) < 0.05, "What it pays over the next production cycle is held for it (%s)" % str(g._head_owed(P)))
	fresh()   # research beside it: it may use the bank, except the copy's next cycle
	g.bank[P] = full_bank({"intel": float(price.intel) * share})   # exactly the copy's next cycle of Intel
	queue("breach")
	g._cmd(["research", "ddos"])
	var rp0: float = float(g.research_job[P].get("progress", 0.0))
	step(0.2)
	check(float(g.research_job[P].get("progress", 0.0)) <= rp0 + 0.0001 and float(g._mq(P)[0].progress) > 0.1, "Research takes none of the Intel the copy pays next (research held at %.2f s; the copy made %.2f s)" % [float(g.research_job[P].get("progress", 0.0)), float(g._mq(P)[0].progress)])
	g._cmd(["queue_pause"]); queue("recon")
	check(g._head_owed(P).is_empty(), "A paused queue holds nothing back")


func held_text() -> void:   # 0.6.14: the stopped-research text tells what the bank lacks apart from what it has but keeps
	fresh()
	g._set_builds(int(g.rig[P]), ["bot"])   # only the trickle comes in
	var price: Dictionary = g._recipe_cost("breach")
	var held: float = float(price.intel) * minf(1.0, g.PROD_CYCLE / g._make_time("breach"))   # (0.6.27) what the copy pays over the next cycle
	g.bank[P] = full_bank({"intel": held, "cash": 0.0})   # Intel there but held for the copy, no Crypto
	queue("breach")
	g._cmd(["research", "ddos"])   # wants Intel and Crypto
	step(0.1)
	var stall: String = g._research_stall(P)
	var kept := "%s is kept for your %s copy" % [g.RES_NAME.intel, g.CARDS.breach.name]
	check(stall.contains("no %s in your bank" % g.RES_NAME.cash) and stall.contains(kept) and not stall.contains("no %s" % g.RES_NAME.intel),
		"Research names the Crypto the bank lacks and the Intel it keeps for the copy, not 'no Intel': '%s'" % stall)
	g.bank[P].cash = float(g._research_cost("ddos").cash)   # the research's whole Crypto: now only the held Intel stops it
	step(0.1)
	stall = g._research_stall(P)
	check(stall.contains(kept) and not stall.contains("in your bank"), "With Crypto in the bank only the kept Intel is named: '%s'" % stall)


func ready_full_holds_nothing() -> void:   # 0.6.14: a head the full Ready inventory stops cannot use its price, so it holds none
	fresh()
	g._set_builds(int(g.rig[P]), ["bot"])
	var price: Dictionary = g._recipe_cost("breach")
	g.cards[P] = {"recon": g.READY_SLOTS}
	g.bank[P] = full_bank({"intel": float(price.intel)})   # exactly the head's Intel
	queue("breach")
	g._cmd(["research", "ddos"])
	var intel0: float = g.bank[P].intel
	step(2.0)
	var held_full: Dictionary = g._head_owed(P)
	var can: bool = g._can_start_recipe(P, "breach")
	var prog := float(g.research_job[P].get("progress", 0.0))
	var stall: String = g._research_stall(P)
	g.cards[P] = {"recon": g.READY_SLOTS - 1}   # a card is played: a place frees
	step(0.1)
	var back: bool = not (g._mq(P)[0].paid as Dictionary).is_empty() or g._head_owed(P).has("intel")
	check(not can and held_full.is_empty() and back,
		"With %d ready the head cannot start and holds nothing; once a place frees it holds its price again (held while full: %s)" % [g.READY_SLOTS, str(held_full)])
	check(prog >= 2.0 - 0.05 and float(g.bank[P].intel) < intel0 and stall == "",
		"Meanwhile research uses that Intel at full speed (%.2f s of 2) and does not say the copy collects its price ('%s')" % [prog, stall])


func neutral_neighbour() -> int:
	for nb in g.hosts[int(g.rig[P])].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: return int(nb)
	return -1


func remote_firewall(stations: Array, cash: float) -> int:   # a fresh game: a captured neighbour builds a Firewall, research of Sabotage runs
	fresh()
	g._set_builds(int(g.rig[P]), stations)   # stations: workers; no producers, only the trickle comes in
	var n := neutral_neighbour()
	g.hosts[n].slots = 3; g._capture(n, P); g.hosts[n].builds = g._slot_array([], 3)
	g.known[P]["ddos"] = true
	g.bank[P] = full_bank({"cash": cash})
	g._cmd(["build", n, 0, "wall"])
	g._cmd(["research", "sabotage"])   # wants Crypto too
	return n


func research_after_projects() -> void:   # 0.6.14: research leaves a remote project's materials alone too (building first)
	var bill := float(g.BUILD_COSTS.wall.cash)
	var n := remote_firewall(["bot"], 0.5 * bill)   # half the Crypto the Firewall still needs
	check(n >= 0 and int(g._worker_counts(P).total) > 0 and (g.hosts[n].jobs as Dictionary).has(0), "Setup: a Firewall waits for its materials on a captured neighbour; workers carry them")
	step(10.0)
	var prog := float(g.research_job[P].get("progress", 0.0))
	var stall: String = g._research_stall(P)
	var left := float(g.bank[P].cash)
	g.bank[P].cash = float(g.bank[P].cash) + 2.0 * bill   # more than it still needs: the rest is research's
	step(1.0)
	var prog_spare := float(g.research_job[P].get("progress", 0.0)) - prog
	remote_firewall([], 0.5 * bill)   # no Bot station: no worker can carry to the site, so it keeps nothing
	step(2.0)
	var prog_nobody := float(g.research_job[P].get("progress", 0.0))
	check(prog < 0.001 and prog_spare > 0.9 and prog_nobody > 1.9,
		"Research takes none of the Crypto a remote Firewall still needs (%.2f s in 10 s, %.1f left in the bank), but goes on with Crypto to spare (%.2f s) or with no worker to carry it (%.2f s)" % [prog, left, prog_spare, prog_nobody])
	check(stall.contains("%s is kept for your construction" % g.RES_NAME.cash) and not stall.contains("in your bank"),
		"The research bar says the Crypto is kept for the construction: '%s'" % stall)


func paused_head_chip() -> void:   # 0.6.14: a head paused before it started is neither 'Starting' nor paid
	fresh()
	g._cmd(["queue_pause"])
	queue("recon")   # affordable: the bank is full
	step(1.0)
	var chip = g.lane_strip.get_node("Queue1")
	var st: Dictionary = chip.state()
	var tip: String = chip._get_tooltip(Vector2.ZERO)
	var unpaid: bool = (g._mq(P)[0].paid as Dictionary).is_empty()
	g._cmd(["queue_pause"])
	step(0.2)
	var resumed: Dictionary = chip.state()
	check(unpaid and str(st.kind) == "paused" and str(st.text) != "Starting" and not tip.contains("price is paid")
		and not (g._mq(P)[0].paid as Dictionary).is_empty() and str(resumed.kind) == "making",
		"A paused queue's unpaid head reads paused, not 'Starting' or paid: %s / '%s'; resumed, it pays and is made (%s)" % [str(st.text), tip, str(resumed.text)])


func capacity_and_order() -> void:
	fresh()
	for r in ["recon", "breach", "recon", "recon", "breach"]: queue(r)
	check(recipes() == ["recon", "breach", "recon", "recon"], "Four entries, the one being made included; a fifth is refused (%s)" % str(recipes()))
	step(0.1)
	check(not (g._mq(P)[0].paid as Dictionary).is_empty() and (g._mq(P)[1].paid as Dictionary).is_empty(), "Only the head is paid; the entries behind it have spent nothing")
	var order := []
	var last := {}
	for k in 400:
		step(0.1)
		for r in ["recon", "breach"]:
			if g._held(P, r) > int(last.get(r, 0)): order.append(r)
			last[r] = g._held(P, r)
		if g._mq(P).is_empty(): break
	check(order == ["recon", "breach", "recon", "recon"], "Copies finish in the order they were queued, duplicates included (%s)" % str(order))
	queue("recon")
	check(recipes() == ["recon"], "An empty queue takes new entries again")


func waiting_head() -> void:   # (0.6.27) a started head the bank cannot pay waits, and says what it lacks
	fresh()
	for r in g.RES: g.bank[P][r] = 0.0
	queue("breach"); queue("recon")
	step(1.0)
	var why: String = g._mq_head_why(P)
	check(float(g._mq(P)[0].progress) < 0.1 * g._make_time("breach") and why.begins_with("Needs ") and why.contains("Intel") and why.contains("Main rig"),
		"A copy the bank cannot pay for waits, making nothing, and says what it needs: '%s'" % why)
	check(g._held(P, "recon") == 0 and recipes() == ["breach", "recon"], "Nothing behind it starts first, even a cheaper copy")
	var bank0: Dictionary = g.bank[P].duplicate()
	g._cmd(["unqueue", int(g._mq(P)[1].id)])
	check(recipes() == ["breach"] and g.bank[P] == bank0, "Removing a waiting entry is free")
	var price: Dictionary = g._recipe_cost("breach")
	for r in price: g.bank[P][r] = float(price[r])   # exactly the head's price
	step(0.5)
	check(float(g._mq(P)[0].progress) > 0.3 and g._mq_head_why(P) == "", "With the stock in the bank it carries on, paying as it goes")


func full_hand() -> void:
	fresh()
	var slots: int = g.READY_SLOTS
	g.cards[P] = {"recon": slots - 1}
	queue("recon"); queue("recon")
	step(0.2)
	check(not (g._mq(P)[0].paid as Dictionary).is_empty() and g._ready_total(P) == slots, "The copy being made holds the last (%dth) ready place" % slots)
	step(g._make_time("recon") + 1.0)
	check(g._held(P, "recon") == slots and (g._mq(P)[0].paid as Dictionary).is_empty() and g._mq_head_why(P) == "Ready inventory full — use a card",
		"With %d ready the next head waits: '%s'" % [slots, g._mq_head_why(P)])
	var home: int = int(g.rig[P])
	var t := -1
	for nb in g.hosts[home].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: t = int(nb); break
	g._play_card(P, "recon", t)
	check(g._held(P, "recon") == slots - 1 and g._ready_total(P) == slots and (g._mq(P)[0].paid as Dictionary).is_empty(),
		"A card in flight that may come back still counts against the %d (%d)" % [slots, g._ready_total(P)])
	for k in 200:
		step(0.1)
		if not g.flights.any(func(f): return str(f.kind) == "op"): break
	step(0.3)
	check(not (g._mq(P)[0].paid as Dictionary).is_empty(), "When it has landed the place frees and the head starts")


func pause_and_cancel() -> void:   # (0.6.27) paused, it neither pays nor progresses; cancelled, what it used is gone and nothing more is taken
	fresh()
	var price: Dictionary = g._recipe_cost("breach")
	for r in price: g.bank[P][r] = 2.0 * float(price[r])
	queue("breach")
	step(0.1)
	g._cmd(["queue_pause"])
	var p0 := float(g._mq(P)[0].progress)
	var paid0: float = float((g._mq(P)[0].paid as Dictionary).get("intel", 0.0))
	step(3.0)
	check(absf(float(g._mq(P)[0].progress) - p0) < 0.0001 and absf(float((g._mq(P)[0].paid as Dictionary).get("intel", 0.0)) - paid0) < 0.0001 and bool(g.mq_paused[P]), "Paused: the head makes no progress and pays nothing")
	g._cmd(["queue_pause"])
	step(0.5 * g._make_time("breach") - 0.1)
	var paid: float = float((g._mq(P)[0].paid as Dictionary).get("intel", 0.0))
	var before: float = float(g.bank[P].intel)
	g._cmd(["unqueue", int(g._mq(P)[0].id)])
	step(1.0)
	var trickle: float = g.MAIN_INCOME * 1.0
	check(g._mq(P).is_empty() and absf(float(g.bank[P].intel) - before - trickle) < 0.05 and absf(paid - 0.5 * float(price.intel)) < 0.06 * float(price.intel),
		"Cancelled half-way: it had paid half its price (%s), nothing is refunded and nothing more is taken" % g._amt(paid))


func command_ids() -> void:
	fresh()
	g._cmd(["queue", "recon", 77]); g._cmd(["queue", "recon", 77])
	check(recipes() == ["recon"], "The same command id twice queues one copy")
	g._cmd(["queue", "recon", 78])
	check(recipes() == ["recon", "recon"], "A new id queues another")
	g._cmd(["queue", "nonsense", 79]); g._cmd(["queue", "sabotage", 80]); g._cmd(["unqueue", "x"])
	check(recipes() == ["recon", "recon"], "Unknown or unlearned recipes and garbage ids change nothing")


func ai_queue() -> void:
	fresh()
	g.ai_enabled = true
	var worst := 0
	for k in 120:
		step(1.0)
		for fac in g.ais: worst = maxi(worst, (g._mq(int(fac)) as Array).size())
	check(worst > 0 and worst <= g.QUEUE_SIZE, "The AI manufactures through the same four-place queue (longest %d)" % worst)
