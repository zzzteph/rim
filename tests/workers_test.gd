extends SceneTree
## Delivery workers and physical construction: two reusable workers per Bot station with stable identities, all of
## them ONE pool working from the main node (a new station's workers go there first); automatic demand (local use
## first, the net shortfall brought, the surplus collected); construction first, then inputs, then surplus, the hosts
## served in turn; one unit per leg; claims taken once; capture destroys a station's workers wherever they are; a lost
## worker is replaced at its surviving station; construction is supplied into escrow before its work runs.
## godot --headless --path . --script tests/workers_test.gd
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


func fresh() -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER; R = g.RIVAL
	g.bank[P] = {"intel": 100.0, "cash": 60.0, "creds": 60.0, "research": 60.0}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func led(key: String) -> float: return float(g._ledger_sums(P).get(key, 0.0))


func near(skip := []) -> int:   # a neutral host linked to the main node
	for nb in g.hosts[int(g.rig[P])].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL and not skip.has(int(nb)): return int(nb)
	return -1


func own(i: int, kinds: Array, type := "pc") -> void:
	g._capture(i, P); g.hosts[i].type = type; g.hosts[i].slots = maxi(3, kinds.size())
	g._set_builds(i, kinds); g._tick_teams(0.0)


func station_of(f: Dictionary) -> int: return int((g.workers.get(int(f.get("wid", -1)), {}) as Dictionary).get("home", -1))


func ids(home := -2) -> Array:
	var out := []
	for wid in g.workers:
		if int(g.workers[wid].fac) == P and (home == -2 or int(g.workers[wid].home) == home): out.append(int(wid))
	out.sort()
	return out


func run() -> void:
	population()
	identities_and_replacement()
	capture_kills()
	retirement()
	local_use_first()
	empty_miner()
	fractional()
	lab_bundle()
	shared_trips()
	no_double_claim()
	no_ping_pong()
	one_pool()
	builds_first()
	storage_fair()
	construction()
	cancel_and_pause()
	fairness()
	escrow_theft()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func population() -> void:
	fresh()
	var home: int = int(g.rig[P])
	check(g.hosts[home].builds.count("bot") == 1 and ids().size() == 2, "The starting main node's one Bot station gives exactly two workers (%d)" % ids().size())
	check(not g.RES.has("bots") and not g.bank[P].has("bots"), "Bots are no material: no bank, no income, no cap")
	step(30.0)
	check(ids().size() == 2, "Production cycles never add workers (%d after 30 s)" % ids().size())
	g._set_builds(home, ["intel", "bot", "bot"]); g._tick_teams(0.0)
	check(ids().size() == 4, "A second finished station adds exactly two (%d)" % ids().size())
	var erp := near(); own(erp, ["bot"], "erp")
	check(ids(erp).size() == 2, "A station on a host with a Bot multiplier still has two (%d)" % ids(erp).size())


func identities_and_replacement() -> void:
	fresh()
	var h := near(); own(h, ["bot", "intel"])
	var before := ids()
	step(60.0)
	check(ids() == before and led("from:%d:intel" % h) >= 2.0, "Many trips later the same worker identities remain (%s), %.0f Intel delivered" % [str(ids()), led("from:%d:intel" % h)])
	# a worker waiting at a knocked-out relay is held, not lost: no replacement
	var far := -1
	for nb in g.hosts[h].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL and not g.hosts[int(g.rig[P])].links.has(int(nb)): far = int(nb); break
	own(far, ["bot", "intel"])
	step(6.0)
	g.hosts[h].ddos_until = g._t + 8.0
	step(4.0)
	var blocked := 0
	for wid in ids(far): if g._worker_state(wid) == "blocked": blocked += 1
	check(ids(far).size() == 2, "Workers held behind a DDoS stay the same two (%d held), nobody is replaced" % blocked)
	# a worker lost on the road leaves a vacant slot, refilled after 5 s of station operation
	g.bank[P].intel = 150.0; g.bank[P].cash = 60.0
	g._cmd(["build", h, 2, "wall"])   # 40 units to carry: every worker of the pool goes on the road
	var lost_id := -1
	for k in 1800:
		g._sim_step(g.SIM_DT)
		for f in g.flights:
			if str(f.kind) == "courier" and station_of(f) == far and not bool(f.get("blocked", false)): lost_id = int(f.wid); g._lose(f, int(g.rig[P]), "test"); break
		if lost_id > 0: break
	g.flights = g.flights.filter(func(x): return not bool(x.get("dead", false)))
	var t0: float = g._t
	check(lost_id > 0 and not g.workers.has(lost_id) and ids(far).size() == 1, "A confirmed loss leaves one worker and a vacant slot")
	step(4.5)
	check(ids(far).size() == 1, "...not refilled before 5 s")
	step(1.0)
	check(ids(far).size() == 2 and not ids(far).has(lost_id), "...then refilled with a new identity (%.1f s)" % (g._t - t0))


func capture_kills() -> void:
	fresh()
	var h := near(); own(h, ["bot", "bot", "intel"])
	step(8.0)
	var away := 0
	for wid in ids(h): if g._worker_state(wid) != "idle": away += 1
	var total_before := ids().size()
	g._capture(h, R)
	check(ids(h).is_empty() and ids().size() == total_before - 4, "Capturing a two-station host destroys its four workers (%d were away)" % away)
	check(not g.flights.any(func(f): return str(f.kind) == "courier" and not g.workers.has(int(f.get("wid", -1)))), "...wherever they were: none of them is still travelling")
	check(g.events.any(func(e): return str(e.text).contains("4 station workers destroyed")), "The former owner is told how many workers were destroyed")
	g._capture(h, P); g._tick_teams(0.0)
	check(ids(h).is_empty() and (g.hosts[h].builds as Array).count("bot") == 0, "Retaken, it has empty slots and no team: nothing restarts by itself")
	step(6.0)
	check(ids().size() == total_before - 4, "No worker comes back or is rehomed (%d)" % ids().size())


func retirement() -> void:
	fresh()
	var h := near(); own(h, ["bot", "intel"])
	step(6.0)
	var n0 := ids().size()
	g._cmd(["build", h, 0, "cash"])   # replace the station while its workers are out
	check(ids(h).size() <= 2 and g._worker_counts(P, h).total == 0, "Replacing the station takes its workers off duty at once")
	step(10.0)
	check(ids(h).is_empty() and ids().size() == n0 - 2, "They finish the leg they were on and retire: no extra main-node workers (%d)" % ids().size())


func local_use_first() -> void:
	fresh()
	var a := near(); own(a, ["intel", "cash", "bot"])   # makes 1 Intel, uses 1: nothing to fetch
	var plan: Dictionary = g._host_plan(a, P, {"intel": 0.0, "cash": 0.0, "creds": 0.0, "research": 0.0})
	check(float(plan.short.intel) == 0.0, "Makes 1, uses 1: nothing to fetch")
	g.hosts[a].store = {P: {"intel": 1.0}}
	plan = g._host_plan(a, P, {})
	check(absf(float(plan.export.intel) - 1.0) < 0.001, "Stock 1 + 1 made, 1 used next cycle with 1 made locally: 1 may leave")
	var b := near([a]); own(b, ["intel", "intel", "cash", "cash", "bot"])   # makes 2, uses 2
	g.hosts[b].store = {}
	plan = g._host_plan(b, P, {})
	check(float(plan.short.intel) == 0.0 and float(plan.export.intel) == 0.0, "Makes 2, uses 2: nothing to fetch, nothing to send")
	g._set_builds(b, ["intel", "cash", "cash", "cash"]); g.hosts[b].slots = 4
	plan = g._host_plan(b, P, {"intel": 50.0})
	check(absf(float(plan.short.intel) - 2.0) < 0.001, "Makes 1, needs 3: the 2-unit shortfall is brought")


func empty_miner() -> void:   # the baseline reproduction: no setup, no clicks
	fresh()
	var h := near(); own(h, ["cash", "bot"])
	step(45.0)
	check(led("from:%d:cash" % h) >= 2.0 and led("out:supply:intel") >= 2.0, "An empty Miner gets its Intel brought and its Crypto collected on its own (%.0f Crypto in the last 30 s)" % led("from:%d:cash" % h))


func fractional() -> void:
	fresh()
	var h := near(); own(h, ["cash", "bot"], "erp")   # an ERP Miner uses 1.5 Intel a cycle
	step(45.0)
	var got := led("from:%d:cash" % h)
	check(got >= 1.5, "A fractional input (1.5 Intel a cycle) is supplied: %.1f Crypto made and delivered" % got)
	var biggest := 0.0
	for f in g.flights: for r in (f.get("cargo", {}) as Dictionary): biggest = maxf(biggest, float(f.cargo[r]))
	check(biggest <= 1.0 + 0.0001, "No worker carries more than one unit (%.2f)" % biggest)


func lab_bundle() -> void:
	fresh()
	var h := near(); own(h, ["lab", "bot"])   # needs 1 Intel + 1 Crypto, has neither
	var plan: Dictionary = g._host_plan(h, P, {"intel": 10.0, "cash": 10.0, "creds": 0.0, "research": 0.0})
	check(float(plan.short.intel) >= 0.99 and float(plan.short.cash) >= 0.99, "A Lab with no inputs asks for both when the main node has both")
	plan = g._host_plan(h, P, {"intel": 10.0, "cash": 0.0, "creds": 0.0, "research": 0.0})
	check(float(plan.short.intel) == 0.0, "...and holds no Intel for itself when no Crypto can come")
	step(50.0)
	check(led("from:%d:research" % h) >= 1.0, "Supplied with both it sends Research home (%.0f)" % led("from:%d:research" % h))


func shared_trips() -> void:
	fresh()
	var h := near(); own(h, ["intel", "lab"])   # surplus Intel to collect, Crypto to bring
	g.hosts[h].store = {P: {"intel": 3.0}}
	step(0.1)
	var both := false
	for f in g.flights:
		if str(f.kind) == "courier" and (f.cargo as Dictionary).has("cash") and int((f.job as Dictionary).get("src", -1)) == h: both = true
	check(both, "One round trip does both: Crypto out to the host, and its surplus Intel booked for the way back")


func no_double_claim() -> void:
	fresh()
	var h := near(); own(h, ["cash"])
	g.bank[P].intel = 1.0
	step(0.1)
	var carrying := 0
	for f in g.flights:
		if str(f.kind) == "courier" and (f.cargo as Dictionary).has("intel"): carrying += 1
	check(carrying == 1 and g._avail(P, "intel") < 0.5, "Two free workers, one Intel at the main node: only one carries it, and it left the bank once")
	fresh()
	var x := near(); own(x, ["intel"])
	g.hosts[x].store = {P: {"intel": 1.0}}
	step(0.1)
	var booked := 0
	for f in g.flights:
		if str(f.kind) == "courier" and int((f.job as Dictionary).get("src", -1)) == x: booked += 1
	check(booked == 1, "One unit to collect: only one worker is booked for it (%d)" % booked)


func no_ping_pong() -> void:   # what was brought for a host's next cycle is not carried straight back out
	fresh()
	var h := near(); own(h, ["cash"])
	g.hosts[h].cyc = 11.0   # its cycle comes late, so the delivered Intel waits there a while
	for k in 120:
		step(0.1)
		if float(g._store_of(h, P).get("intel", 0.0)) >= 0.999: break
	var plan: Dictionary = g._host_plan(h, P, {})
	check(float(g._store_of(h, P).get("intel", 0.0)) >= 0.999 and float(plan.export.intel) < 0.001, "Delivered Intel is kept for the Miner's next cycle, not offered back")
	step(8.0)
	check(led("from:%d:intel" % h) < 0.001, "...and none of it travels back to the main node")


func one_pool() -> void:   # every worker works from the main node: a remote station's workers serve any host
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["intel"]); g._tick_teams(0.0)   # no station at the main node
	var h := near(); own(h, ["bot"])
	var mine := ids(h)
	var join_tip := ""
	for k in 30:   # on the way: hovering it says where it is going
		for f in g.flights:
			if str(f.kind) == "courier" and str(f.get("trip", "")) == "join" and join_tip == "": join_tip = " | ".join(PackedStringArray(g._flight_lines(f)))
		if join_tip != "": break
		g._sim_step(g.SIM_DT)
	check(join_tip.contains("Joining your workers at the main node") and not join_tip.contains("Coming home empty"), "A new worker on its way to the main node says so when hovered (%s)" % join_tip)
	step(4.0)
	var at_hub := 0
	for wid in mine: if int(g.workers[wid].base) == home: at_hub += 1
	check(at_hub == 2, "A remote station's two workers first go to the main node and work from there (%d of 2)" % at_hub)
	var x := near([h]); g._capture(x, P); g.hosts[x].slots = 3; g._set_builds(x, [])
	g._cmd(["build", x, 0, "intel"])
	var served := false
	for k in 300:
		g._sim_step(g.SIM_DT)
		for f in g.flights:
			if str(f.kind) == "courier" and station_of(f) == h and int(f.dest) == x and (f.cargo as Dictionary).size() > 0: served = true
		if served: break
	check(served, "...so they carry building materials to another host that has no station")
	var counts: Dictionary = g._worker_counts(P)
	check(int(counts.idle) == 0, "With materials to carry, no worker stays free (%s)" % str(counts))


func builds_first() -> void:   # construction first, then inputs, then surplus; the hosts are served in turn
	fresh()
	var home: int = int(g.rig[P])
	var hs := []   # three hosts of yours with a route home: the main node's neutral neighbours, then theirs
	var frontier := [home]
	while hs.size() < 3 and not frontier.is_empty():
		var nxt := []
		for f0 in frontier:
			for nb in g.hosts[int(f0)].links:
				if hs.size() < 3 and int(g.hosts[int(nb)].owner) == g.NEUTRAL and not hs.has(int(nb)):
					hs.append(int(nb)); g._capture(int(nb), P); g.hosts[int(nb)].slots = 3; nxt.append(int(nb))
		frontier = nxt
	if hs.size() < 3: check(false, "three hosts of yours"); return
	var a: int = hs[0]; var b: int = hs[1]; var c: int = hs[2]
	g._set_builds(a, ["intel"]); g._set_builds(b, ["intel"]); g._set_builds(c, [])
	g.hosts[a].store = {P: {"intel": 5.0}}; g.hosts[b].store = {P: {"intel": 5.0}}   # surplus waiting on two hosts
	g._cmd(["build", c, 0, "intel"])
	var reqs: Array = g._open_requests(P, home)
	var cands := []
	for r in reqs:
		var amt: float = g._amount(P, home, r)
		if amt > 0.0001: var cc: Dictionary = r.duplicate(); cc.amt = amt; cands.append(cc)
	var first: Dictionary = g._pick_request(P, cands, 0)
	check(str(first.get("purpose", "")).begins_with("build:"), "A building order is served before surplus (%s)" % str(first.get("purpose", "")))
	step(30.0)
	check(led("from:%d:intel" % a) >= 1.0 and led("from:%d:intel" % b) >= 1.0, "Both hosts' surplus is collected in turn, not one host's only (%.0f, %.0f)" % [led("from:%d:intel" % a), led("from:%d:intel" % b)])


func storage_fair() -> void:
	fresh()
	var h := near(); own(h, ["cash", "cash", "cash", "cash", "bot"], "erp")   # 4 ERP Miners need 6 Intel a cycle
	g.hosts[h].store = {P: {"cash": 7.0}}   # little room left
	var ran := {}
	for k in 8:
		step(g.PROD_CYCLE)
		for slot in (g.hosts[h].get("plan_frac", {}) as Dictionary): ran[int(slot)] = true
	check(ran.size() >= 3, "Short of room for every Miner's supplies, they take turns (%d of 4 funded over 8 cycles)" % ran.size())


func construction() -> void:
	fresh()
	var h := near()
	g._capture(h, P); g.hosts[h].type = "pc"; g.hosts[h].slots = 3; g._set_builds(h, [])
	var i0: float = g._avail(P, "intel")
	g._cmd(["build", h, 0, "bot"])
	var job: Dictionary = g.hosts[h].jobs[0]
	check(absf(g._avail(P, "intel") - i0) < 0.001 and (job.escrow as Dictionary).is_empty(), "Ordering pays nothing yet: the bill waits at the site")
	var arrived_before_work := true
	var t0: float = g._t
	for k in 60 * 30:
		g._sim_step(g.SIM_DT)
		if g.hosts[h].jobs.has(0) and float(g.hosts[h].jobs[0].left) < float(g.hosts[h].jobs[0].total) - 0.001 and not g._job_funded(g.hosts[h].jobs[0]): arrived_before_work = false
		if not g.hosts[h].jobs.has(0): break
	check(arrived_before_work, "No work happens before all 16 units are in the site's escrow (beyond the 10-unit store)")
	check(str(g.hosts[h].builds[0]) == "bot" and ids(h).size() == 2, "Built after %.1f s (ideal 26 s on one hop): its two workers start" % (g._t - t0))
	check(absf(led("out:supply:intel") + led("out:supply:cash") - 16.0) < 0.01, "Exactly the bill was carried: 16 units")
	# local stock reduces what is carried
	fresh()
	var h2 := near(); g._capture(h2, P); g.hosts[h2].slots = 3; g._set_builds(h2, [])
	g.hosts[h2].store = {P: {"intel": 5.0}}
	g._cmd(["build", h2, 0, "bot"])
	for k in 60 * 30:
		g._sim_step(g.SIM_DT)
		if not g.hosts[h2].jobs.has(0): break
	check(absf(led("out:supply:intel") - 7.0) < 0.01 and absf(led("out:supply:cash") - 4.0) < 0.01, "5 Intel already there: only 7 Intel and 4 Crypto were carried")


func cancel_and_pause() -> void:
	for when in ["before", "travel", "partial", "work"]:
		fresh()
		var h := near(); g._capture(h, P); g.hosts[h].slots = 3; g._set_builds(h, [])
		var total0 := 0.0
		for r in g.RES: total0 += g._avail(P, r)
		g._cmd(["build", h, 0, "bot"])
		match when:
			"travel": step(0.5)
			"partial": step(6.0)
			"work": step(22.0)
		var job: Dictionary = g.hosts[h].jobs.get(0, {})
		var worked := 0.0
		if not job.is_empty() and g._job_funded(job): worked = 1.0 - float(job.left) / float(job.total)
		g._cmd(["cancel", h, 0])
		step(6.0)
		var where := 0.0
		for r in g.RES: where += g._avail(P, r) + g._loot(h, P, r) + float(g.hosts[h].store.get(P, {}).get(r, 0.0))
		for f in g.flights: for r in (f.get("cargo", {}) as Dictionary): where += float(f.cargo[r])
		var trickle := 0.0
		for r in g.RES: trickle += led("in:trickle:" + r) + led("in:production:" + r)
		var used := 16.0 * worked
		check(absf(total0 + trickle - used - where) < 0.05, "Cancelled %s: every unit is in the bank, on the road or in the site's salvage pile (%.2f of %.2f; %.1f used by work)" % [when, where, total0 + trickle - used, used])
	fresh()
	var h3 := near(); g._capture(h3, P); g.hosts[h3].slots = 3; g._set_builds(h3, [])
	g._cmd(["build", h3, 0, "bot"])
	step(3.0)
	g._cmd(["job", h3, 0])
	var esc0 := 0.0
	step(6.0)
	for r in (g.hosts[h3].jobs[0].escrow as Dictionary): esc0 += float(g.hosts[h3].jobs[0].escrow[r])
	step(6.0)
	var esc1 := 0.0
	for r in (g.hosts[h3].jobs[0].escrow as Dictionary): esc1 += float(g.hosts[h3].jobs[0].escrow[r])
	check(absf(esc1 - esc0) < 0.001, "Paused: loaded cargo landed, then no new deliveries (escrow %.0f)" % esc1)
	# capture mid-delivery: the site's materials are lost to the former owner, recorded once
	g._cmd(["job", h3, 0])
	step(3.0)
	var esc := 0.0
	for r in (g.hosts[h3].jobs[0].escrow as Dictionary): esc += float(g.hosts[h3].jobs[0].escrow[r])
	g._capture(h3, R)
	check(absf(led("lost:site:intel") + led("lost:site:cash") - esc) < 0.001 and (g.hosts[h3].jobs as Dictionary).is_empty(), "Captured mid-delivery: its %.0f site units are recorded lost, nothing refunded" % esc)


func fairness() -> void:   # endless input demand must not starve a build or an export-only host
	fresh()
	var home: int = int(g.rig[P])
	var hosts := []
	for nb in g.hosts[home].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: hosts.append(int(nb))
	var a: int = hosts[0]; var b: int = hosts[1]; var c: int = hosts[2] if hosts.size() > 2 else -1
	g._capture(a, P); g.hosts[a].slots = 3; g._set_builds(a, ["cash", "cash", "cash"])   # hungry: 3 Intel a cycle, forever
	g._capture(b, P); g.hosts[b].slots = 3; g._set_builds(b, ["intel"])              # export only
	if c >= 0: g._capture(c, P); g.hosts[c].slots = 3; g._set_builds(c, [])
	g.bank[P].intel = 150.0
	if c >= 0: g._cmd(["build", c, 0, "wall"])
	step(60.0)
	check(led("from:%d:intel" % b) >= 1.0, "An export-only host still gets its Intel collected (%.0f in the last 30 s)" % led("from:%d:intel" % b))
	check(c < 0 or not g.hosts[c].jobs.has(0) or float(g.hosts[c].jobs[0].escrow.get("intel", 0.0)) >= 4.0, "A construction order still gets its materials")


func escrow_theft() -> void:
	fresh()
	var h := near(); g._capture(h, P); g.hosts[h].slots = 3; g._set_builds(h, [])
	g._cmd(["build", h, 0, "bot"])
	step(10.0)
	var esc := 0.0
	for r in (g.hosts[h].jobs[0].escrow as Dictionary): esc += float(g.hosts[h].jobs[0].escrow[r])
	g._resolve_vault(R, h)
	var after := 0.0
	for r in (g.hosts[h].jobs[0].escrow as Dictionary): after += float(g.hosts[h].jobs[0].escrow[r])
	var pile := 0.0
	for r in g.RES: pile += g._loot(h, R, r)
	check(esc >= 1.0 and after < esc and absf(pile - (esc - after)) < 0.001, "A Vault raid takes unbuilt site materials (%.0f of %.0f) into the raider's pile" % [esc - after, esc])
	check(not g._job_funded(g.hosts[h].jobs[0]) and g._build_requests(h, P).size() > 0, "The project lacks them again and asks for them")
