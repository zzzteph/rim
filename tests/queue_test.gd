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
	g.bank[P] = {"intel": 200.0, "cash": 200.0, "creds": 200.0, "research": 200.0}
	g.cards[P] = {}
	g.known[P]["breach"] = true


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
	full_hand()
	pause_and_cancel()
	command_ids()
	ai_queue()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


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


func waiting_head() -> void:
	fresh()
	for r in g.RES: g.bank[P][r] = 0.0
	queue("breach"); queue("recon")
	step(1.0)
	var why: String = g._mq_head_why(P)
	check((g._mq(P)[0].paid as Dictionary).is_empty() and why.begins_with("Needs ") and why.contains("Intel") and why.contains("Main rig"),
		"An unfunded head waits and says what it needs: '%s'" % why)
	check(g._held(P, "recon") == 0 and recipes() == ["breach", "recon"], "Nothing behind it starts first, even a cheaper copy")
	var bank0: Dictionary = g.bank[P].duplicate()
	g._cmd(["unqueue", int(g._mq(P)[1].id)])
	check(recipes() == ["breach"] and g.bank[P] == bank0, "Removing a waiting entry is free")
	g.bank[P].intel = 12.0; g.bank[P].creds = 12.0
	g.rig_claim[P] = {"intel": 6.0}   # a worker's pickup holds some of it
	step(0.5)
	check((g._mq(P)[0].paid as Dictionary).is_empty(), "Stock held for a worker's pickup does not pay for a copy")
	g.rig_claim[P] = {}
	step(0.5)
	check(not (g._mq(P)[0].paid as Dictionary).is_empty() and g._mq_head_why(P) == "", "With the stock free the head pays and starts")


func full_hand() -> void:
	fresh()
	g.cards[P] = {"recon": 11}
	queue("recon"); queue("recon")
	step(0.2)
	check(not (g._mq(P)[0].paid as Dictionary).is_empty() and g._ready_total(P) == 12, "The copy being made holds the 12th ready place")
	step(4.0)
	check(g._held(P, "recon") == 12 and (g._mq(P)[0].paid as Dictionary).is_empty() and g._mq_head_why(P) == "Ready inventory full — use a card",
		"With 12 ready the next head waits: '%s'" % g._mq_head_why(P))
	var home: int = int(g.rig[P])
	var t := -1
	for nb in g.hosts[home].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: t = int(nb); break
	g._play_card(P, "recon", t)
	check(g._held(P, "recon") == 11 and g._ready_total(P) == 12 and (g._mq(P)[0].paid as Dictionary).is_empty(),
		"A card in flight that may come back still counts against the 12 (%d)" % g._ready_total(P))
	for k in 200:
		step(0.1)
		if not g.flights.any(func(f): return str(f.kind) == "op"): break
	step(0.3)
	check(not (g._mq(P)[0].paid as Dictionary).is_empty(), "When it has landed the place frees and the head starts")


func pause_and_cancel() -> void:
	fresh()
	g.bank[P] = {"intel": 40.0, "cash": 40.0, "creds": 40.0, "research": 40.0}   # below the caps, so a refund fits
	queue("breach")
	step(0.1)
	var paid: Dictionary = (g._mq(P)[0].paid as Dictionary).duplicate()
	var bank_after: Dictionary = g.bank[P].duplicate()
	g._cmd(["queue_pause"])
	var p0 := float(g._mq(P)[0].progress)
	step(3.0)
	check(absf(float(g._mq(P)[0].progress) - p0) < 0.0001 and bool(g.mq_paused[P]), "Paused: the head keeps its payment and makes no progress")
	g._cmd(["queue_pause"])
	step(5.9)   # about half of its 12 s
	var frac: float = 1.0 - float(g._mq(P)[0].progress) / float(g._make_time("breach"))
	var trickle := {}
	for r in g.RES: trickle[r] = float(g.bank[P][r]) - float(bank_after[r])
	g._cmd(["unqueue", int(g._mq(P)[0].id)])
	var ok := true
	for r in paid:
		var want: float = float(bank_after[r]) + float(trickle[r]) + float(paid[r]) * frac
		if absf(float(g.bank[P][r]) - want) > 0.01: ok = false; print("  %s bank %.2f want %.2f (paid %.1f, trickle %.2f)" % [r, float(g.bank[P][r]), want, float(paid[r]), float(trickle[r])])
	check(ok and g._mq(P).is_empty() and absf(frac - 0.5) < 0.05, "Cancelling the paid head refunds its unworked share (%.0f%%)" % (frac * 100.0))


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
