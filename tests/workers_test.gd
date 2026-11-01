extends SceneTree
## Delivery workers and physical construction: two reusable workers per Bot station with stable identities; automatic
## demand (0.6.12: the only input left is a Firewall's upkeep - local Intel first, the net shortfall brought - while
## every producer makes its own resource with no input, a storage short of room is shared evenly, and the output is
## collected); 0.6.16 logistics: a job moves one unit from a source to a destination, a site's material comes from
## wherever it is spare STRAIGHT to the site, a worker is free where it delivers and goes on from there (home only when
## it has nothing to do), building and upkeep come strictly first (no three-of-four turns), then the hosts' surplus in
## turn; no more workers sent to a host than it has units; one unit per leg; claims taken once; capture destroys a
## station's workers wherever they are; a lost worker is replaced at its surviving station; construction is supplied
## into escrow before its work runs.
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


func upkeep() -> float: return float(g.BUILD_KINDS.wall.use.intel)   # Intel one Firewall eats per cycle


func one(i: int, kind: String) -> float:   # what one producer of this kind makes on host i in one cycle (rate x host type)
	return float(g.BUILD_KINDS[kind].rate) * g._tmult(i, str(g.BUILD_KINDS[kind].out))


func bill_total(kind: String) -> float:   # all the units a building's bill asks for
	var s := 0.0
	for r in (g.BUILD_COSTS[kind] as Dictionary): s += float(g.BUILD_COSTS[kind][r])
	return s


func slots_of(i: int, kinds: Array) -> Array:   # the slots of host i holding these kinds
	var out := []
	for k in (g.hosts[i].builds as Array).size():
		if kinds.has(str(g.hosts[i].builds[k])): out.append(k)
	return out


func station_of(f: Dictionary) -> int: return int((g.workers.get(int(f.get("wid", -1)), {}) as Dictionary).get("home", -1))


func ids(home := -2) -> Array:
	var out := []
	for wid in g.workers:
		if int(g.workers[wid].fac) == P and (home == -2 or int(g.workers[wid].home) == home): out.append(int(wid))
	out.sort()
	return out


func hop2(via: Array) -> int:   # a neutral host linked to one of `via` but not to the main node (two hops out)
	var home: int = int(g.rig[P])
	for v in via:
		for nb in g.hosts[int(v)].links:
			var c := int(nb)
			if c != home and int(g.hosts[c].owner) == g.NEUTRAL and not g.hosts[home].links.has(c) and not via.has(c): return c
	return -1


func leg_text(f: Dictionary) -> String:   # "trip origin->dest res" of one worker leg (res "-" when it is empty)
	var res := "-"
	for r in (f.get("cargo", {}) as Dictionary): res = str(r)
	if str(f.get("trip", "")) == "fetch": res = "for " + str((f.get("job", {}) as Dictionary).get("res", "?"))
	return "%s %d->%d %s" % [str(f.get("trip", "")), int(f.get("origin", -1)), int(f.get("dest", -1)), res]


func follow(wid: int, secs: float) -> Array:   # the legs one worker makes from now on (0.6.16: the loaded leg is a new flight,
	var out := []                               # so the worker is followed by its id, never by an old flight dictionary)
	var last := -1
	for k in int(round(secs / g.SIM_DT)):
		var f: Dictionary = g._flight_of(wid)
		if not f.is_empty() and int(f.id) != last:
			last = int(f.id); out.append(leg_text(f))
		g._sim_step(g.SIM_DT)
	return out


func open_bill(i: int) -> float:   # what host i's projects still lack that is neither at the site nor on its way
	var n := 0.0
	for b in g._build_requests(i, P): n += float(b[2])
	return n


func run() -> void:
	population()
	identities_and_replacement()
	capture_kills()
	retirement()
	local_use_first()
	empty_firewall()
	fractional()
	no_input()
	shared_trips()
	no_double_claim()
	upkeep_from_a_short_bank()
	no_ping_pong()
	one_pool()
	direct_delivery()
	strict_building()
	no_over_serving()
	always_busy()
	builds_first()
	building_first_rules()
	storage_fair()
	construction()
	cancel_and_pause()
	fairness()
	escrow_theft()
	resources_in_turn()
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


func local_use_first() -> void:   # 0.6.12: the only input is a Firewall's upkeep - local Intel first, the net shortfall brought
	fresh()
	var a := near(); own(a, ["intel", "wall", "bot"])   # its harvester makes what its Firewall eats: nothing to fetch
	var plan: Dictionary = g._host_plan(a, P, {"intel": 0.0, "cash": 0.0, "creds": 0.0, "research": 0.0})
	check(absf(one(a, "intel") - upkeep()) < 0.001 and float(plan.short.intel) == 0.0 and bool(plan.wall),
		"Makes %s Intel, its Firewall uses %s: nothing to fetch, and it stays on with nothing in the bank" % [g._amt(one(a, "intel")), g._amt(upkeep())])
	var stock := 1.0
	g.hosts[a].store = {P: {"intel": stock}}
	plan = g._host_plan(a, P, {})
	var may_leave := stock - maxf(0.0, upkeep() - one(a, "intel"))   # the next cycle's upkeep comes from what it makes
	check(absf(float(plan.export.intel) - may_leave) < 0.001,
		"Stock %s + %s made, %s used next cycle with %s made locally: %s may leave (%s)" % [g._amt(stock), g._amt(one(a, "intel")), g._amt(upkeep()), g._amt(one(a, "intel")), g._amt(may_leave), g._amt(float(plan.export.intel))])
	var b := near([a]); own(b, ["intel", "intel", "wall", "wall", "bot"])   # two harvesters, two Firewalls
	g.hosts[b].store = {}
	plan = g._host_plan(b, P, {})
	check(absf(2.0 * one(b, "intel") - 2.0 * upkeep()) < 0.001 and float(plan.short.intel) == 0.0 and float(plan.export.intel) == 0.0,
		"Makes %s, uses %s: nothing to fetch, nothing to send" % [g._amt(2.0 * one(b, "intel")), g._amt(2.0 * upkeep())])
	g._set_builds(b, ["intel", "wall", "wall", "wall"]); g.hosts[b].slots = 4   # one harvester, three Firewalls
	plan = g._host_plan(b, P, {"intel": 50.0})
	# (0.6.16) a host that does not make all its upkeep asks for the next cycle plus UPKEEP_KEEP - 1 more cycles of what it lacks
	var short: float = 3.0 * upkeep() + (g.UPKEEP_KEEP - 1.0) * (3.0 * upkeep() - one(b, "intel")) - one(b, "intel")
	var req := {}
	for r in g._open_requests(P, int(g.rig[P]), b):
		if str(r.purpose) == "upkeep" and str(r.res) == "intel": req = r
	check(short > 0.999 and short <= g.STORE_CAP and absf(float(plan.short.intel) - short) < 0.001 and absf(float(plan.upkeep) - short) < 0.001 and absf(float(req.get("qty", 0.0)) - short) < 0.001,
		"Makes %s, needs %s a cycle and keeps %s cycles of what it lacks within reach: the %s-unit shortfall is brought as the Firewalls' upkeep (requested %s)" % [g._amt(one(b, "intel")), g._amt(3.0 * upkeep()), g._amt(g.UPKEEP_KEEP), g._amt(short), g._amt(float(req.get("qty", 0.0)))])
	g._set_builds(b, ["wall", "", "", ""])   # one Firewall, nothing making Intel: its stock beyond UPKEEP_KEEP + 1 cycles may leave
	var held := 4.0
	g.hosts[b].store = {P: {"intel": held}}
	plan = g._host_plan(b, P, {})
	var keep: float = minf(held, (g.UPKEEP_KEEP + 1.0) * upkeep())   # (UPKEEP_KEEP + 1 cycles: the last one only from a nearer host's surplus)
	check(absf(float(plan.reserve.intel) - keep) < 0.001 and absf(float(plan.export.intel) - (held - keep)) < 0.001,
		"A Firewall host that makes no Intel keeps %s Intel (%s cycles) of its %s and lets %s go (kept %s, may leave %s)" % [g._amt(keep), g._amt(g.UPKEEP_KEEP + 1.0), g._amt(held), g._amt(held - keep), g._amt(float(plan.reserve.intel)), g._amt(float(plan.export.intel))])


func empty_firewall() -> void:   # the baseline reproduction: no setup, no clicks (0.6.12: a Firewall's upkeep is the only input)
	fresh()
	var h := near(); own(h, ["wall", "cash", "bot"])   # nothing makes Intel here: the Firewall's upkeep comes from the bank
	step(15.0)   # (its first cycle may come before the first delivery could reach it)
	var off := 0.0
	for k in 60:   # the ledger's 30-s window
		step(0.5)
		if not bool(g.hosts[h].get("fw_on", true)): off += 0.5
	var cycles := floorf(float(g.LEDGER_SECS) / g.PROD_CYCLE)   # whole cycles in the window
	var brought := led("out:supply:intel"); var crypto := led("from:%d:cash" % h)
	check(off <= 0.01 and brought >= cycles * upkeep() - 0.001 and crypto >= cycles * one(h, "cash") - 0.001,
		"An empty Firewall host gets its Intel brought (%s in the last 30 s, never off) and its Miner's Crypto collected on its own (%s)" % [g._amt(brought), g._amt(crypto)])


func fractional() -> void:   # a fractional need: a Server's harvester makes 1.5 Intel a cycle, its two Firewalls eat 2
	fresh()
	var h := near(); own(h, ["intel", "wall", "wall"], "server")
	var short := 2.0 * upkeep() - one(h, "intel")   # brought each cycle
	step(15.0)   # (its first cycle may come before the first delivery could reach it)
	var biggest := 0.0; var off := 0.0
	for k in int(round(30.0 / g.SIM_DT)):   # the ledger's 30-s window
		g._sim_step(g.SIM_DT)
		for f in g.flights:
			if str(f.kind) == "courier": for r in (f.get("cargo", {}) as Dictionary): biggest = maxf(biggest, float(f.cargo[r]))
		if not bool(g.hosts[h].get("fw_on", true)): off += g.SIM_DT
	var got := led("out:supply:intel")
	var cycles := floorf(float(g.LEDGER_SECS) / g.PROD_CYCLE)
	check(short > 0.001 and absf(short - roundf(short)) > 0.001 and got >= cycles * short - 0.001 and off <= 0.01 and biggest <= short + 0.0001,
		"A fractional upkeep (%s Intel a cycle) is supplied as it is, not in whole units: %s brought in the last 30 s, the Firewalls never off" % [g._amt(short), g._amt(got)])
	check(biggest <= g.WORKER_CARRY + 0.0001, "No worker carries more than one unit (%.2f)" % biggest)


func no_input() -> void:   # 0.6.12: the Miner, Credential harvester and Research lab need no input (they were converters)
	fresh()
	var kinds := ["cash", "cred", "lab"]
	var h := near(); own(h, kinds)
	var plan: Dictionary = g._host_plan(h, P, {"intel": 10.0, "cash": 10.0, "creds": 10.0, "research": 10.0})
	var asks := 0.0
	for r in g.RES: asks += float(plan.short[r])
	check(asks == 0.0 and float(plan.upkeep) == 0.0, "A Miner, a Credential harvester and a Lab ask for nothing when the main node has everything (%s)" % str(plan.short))
	plan = g._host_plan(h, P, {"intel": 0.0, "cash": 0.0, "creds": 0.0, "research": 0.0})
	var full := slots_of(h, kinds).size() == kinds.size()
	for slot in slots_of(h, kinds): if absf(float(plan.frac.get(slot, 0.0)) - 1.0) > 0.0001: full = false
	check(full, "...and with nothing in the bank each still runs its whole cycle (%s)" % str(plan.frac))
	step(50.0)
	var supplied := 0.0
	for r in g.RES: supplied += led("out:supply:" + r)
	var home := {"cash": led("from:%d:cash" % h), "creds": led("from:%d:creds" % h), "research": led("from:%d:research" % h)}
	var each := true
	for kind in kinds: if float(home[str(g.BUILD_KINDS[kind].out)]) < one(h, kind) - 0.001: each = false
	check(each and supplied == 0.0, "With nothing brought to it, the host sends its Crypto, Credentials and Research home (%s; %s supplied)" % [str(home), g._amt(supplied)])


func shared_trips() -> void:   # 0.6.16: no round trips - a worker is free where it delivers and takes that host's surplus next
	fresh()
	var home: int = int(g.rig[P])
	var h := near(); own(h, ["wall", "cash"])   # Intel to bring for the Firewall, Crypto to collect
	g.hosts[h].store = {P: {"cash": 3.0}}
	g._sim_step(g.SIM_DT)
	var wid := -1; var first := []
	for w in ids(home):
		var f: Dictionary = g._flight_of(w)
		first.append(leg_text(f) if not f.is_empty() else "free")
		if wid < 0 and not f.is_empty() and str(f.trip) == "carry" and int(f.dest) == h and (f.cargo as Dictionary).has("intel"): wid = w
	check(first.size() == 2 and first.all(func(x): return str(x) == "carry %d->%d intel" % [home, h]),
		"The Firewall's upkeep goes first: both free workers carry its Intel out before anything else (%s)" % str(first))
	var legs := follow(wid, 4.0)
	check(legs.size() >= 2 and str(legs[0]) == "carry %d->%d intel" % [home, h] and str(legs[1]) == "carry %d->%d cash" % [h, home],
		"The worker that brings the Firewall's Intel is free at the host and carries its Crypto straight home next: no empty leg, no booking for the way back (%s)" % str(legs))


func no_double_claim() -> void:
	fresh()
	var h := near(); own(h, ["wall"])   # its Firewall's upkeep comes from the bank (0.6.16: it keeps UPKEEP_KEEP cycles within reach)
	g.bank[P].intel = upkeep()
	step(0.1)
	var carrying := []; var whole := 0; var on_road := 0.0
	for f in g.flights:
		if str(f.kind) == "courier" and (f.cargo as Dictionary).has("intel"):
			var q := float(f.cargo.intel)
			carrying.append("%.3f" % q); on_road += q
			if q >= g.WORKER_CARRY - 0.0001: whole += 1
	check(whole == 1 and g._avail(P, "intel") < 0.5 and absf(led("out:supply:intel") - on_road) < 0.0001 and led("out:supply:intel") <= upkeep() + 0.01,
		"One Intel at the main node for a Firewall: one worker carries the whole unit, and what left the bank (%s) is exactly what is on the road: it left once" % g._amt(led("out:supply:intel")))
	# GAME BUG (0.6.16): the upkeep request is UPKEEP_KEEP x need capped by the bank's fractional stock (1 + the trickle's
	# 0.003), and _best_delivery's "last fraction the site needs" clause sends the second worker for that sliver
	check(carrying.size() == 1, "Two free workers, one Intel at the main node: only one worker goes; the other is not sent for the trickle's sliver (%d carry Intel: %s)" % [carrying.size(), ", ".join(PackedStringArray(carrying))])
	fresh()
	var x := near(); own(x, ["intel"])
	g.hosts[x].store = {P: {"intel": 1.0}}
	step(0.1)
	var booked := 0
	for f in g.flights:
		if str(f.kind) == "courier" and int((f.job as Dictionary).get("src", -1)) == x: booked += 1
	check(booked == 1, "One unit to collect: only one worker is booked for it (%d)" % booked)


func upkeep_from_a_short_bank() -> void:   # a Firewall short of a fraction of its next cycle, the bank holding that fraction
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["cash", "bot", ""]); g._tick_teams(0.0)   # no Intel harvester at the main node: its Intel grows by the trickle only
	var h := near(); own(h, ["wall"])   # nothing makes Intel on h
	var stock := 0.5; var in_bank := 0.6   # its next cycle lacks 0.5 Intel; the bank holds 0.6, and no other host has any
	g.hosts[h].store = {P: {"intel": stock}}; g.bank[P].intel = in_bank
	g.hosts[h].cyc = 3.0   # its next cycle in 3 s: time for a one-hop trip
	var req := 0.0
	for r in g._open_requests(P, home, h):
		if str(r.purpose) == "upkeep" and str(r.res) == "intel": req = float(r.qty)
	var can: float = minf(g.UPKEEP_KEEP * upkeep() - stock, in_bank)   # what can come: the keep target, as far as the bank has it
	# GAME BUG (0.6.16): _open_requests adds every host's plan export with an EMPTY budget to `spare_intel`; with no budget
	# this host's own Firewall cannot run, so its own 0.5 Intel is listed as spare and counted again as Intel from elsewhere
	check(req <= can + 0.001, "Its upkeep request is what can come (%s: up to %s cycles, as far as the bank's %s go), not inflated by its own stock counted as another host's spare Intel (requested %s)" % [g._amt(can), g._amt(g.UPKEEP_KEEP), g._amt(in_bank), g._amt(req)])
	var off_at := -1.0; var free_s := 0.0
	for k in int(round(3.5 / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		if off_at < 0.0 and not bool(g.hosts[h].get("fw_on", true)): off_at = g._t
		if off_at < 0.0: free_s += g.SIM_DT * float(g._worker_counts(P).idle)
	check(off_at < 0.0, "A Firewall %s Intel short for its next cycle, with %s in the bank and two free workers, stays on (went off at %.1f s; the workers were free %.1f worker-seconds before that)" % [g._amt(upkeep() - stock), g._amt(in_bank), off_at, free_s])
	# the same need split between two places: 0.6 in the bank, 0.6 spare on a host next to the Firewall (0.6.16: straight to the site)
	fresh()
	home = int(g.rig[P])
	g._set_builds(home, ["cash", "bot", ""]); g._tick_teams(0.0)
	h = near(); own(h, ["wall"])   # nothing in its storage
	var y := hop2([h]); own(y, ["cash"])
	var part := 0.6
	g.hosts[y].store = {P: {"intel": part}}; g.bank[P].intel = part   # Intel crumbs on the Miner's host, and as much in the bank
	g.hosts[h].cyc = g._leg_time(P, home, y) + g._leg_time(P, y, h) + 0.75   # time for a worker to fetch y's crumbs and bring them
	var via_bank := 0; var seen := {}
	off_at = -1.0
	for k in int(round((float(g.hosts[h].cyc) + 0.5) / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		if off_at < 0.0 and not bool(g.hosts[h].get("fw_on", true)): off_at = g._t
		for f in g.flights:
			if str(f.kind) != "courier" or int(f.owner) != P or seen.has(int(f.id)): continue
			seen[int(f.id)] = true
			if (str(f.trip) == "fetch" and int((f.job as Dictionary).get("src", -1)) == y and int((f.job as Dictionary).get("dst", -1)) == home) or (str(f.trip) == "carry" and int(f.origin) == y and int(f.dest) == home and (f.cargo as Dictionary).has("intel")): via_bank += 1
	# GAME BUG (0.6.16): _best_delivery takes a source only if it gives a whole unit or the request's whole remainder, so a
	# need split between fractional sources gets nothing; y's crumbs are hauled to the bank instead (host -> main node -> site)
	check(y >= 0 and via_bank == 0, "Spare Intel on a host next to a Firewall that lacks it goes straight there, not through the main node (%d legs %d -> main node)" % [via_bank, y])
	check(off_at < 0.0, "...and with %s Intel in the bank and %s there, the Firewall gets its %s Intel before its cycle (went off at %.1f s)" % [g._amt(part), g._amt(part), g._amt(upkeep()), off_at])


func no_ping_pong() -> void:   # what was brought for a host's next cycle is not carried straight back out
	fresh()
	var h := near(); own(h, ["wall"])   # nothing makes Intel here: its Firewall's upkeep is brought
	g.hosts[h].cyc = 11.0   # its cycle comes late, so the delivered Intel waits there a while
	for k in 120:
		step(0.1)
		if float(g._store_of(h, P).get("intel", 0.0)) >= upkeep() - 0.001: break
	var plan: Dictionary = g._host_plan(h, P, {})
	check(float(g._store_of(h, P).get("intel", 0.0)) >= upkeep() - 0.001 and float(plan.export.intel) < 0.001, "Delivered Intel is kept for the Firewall's next cycle, not offered back")
	step(8.0)
	check(led("from:%d:intel" % h) < 0.001, "...and none of it travels back to the main node")


func one_pool() -> void:   # 0.6.16: a worker works from where it is; one pool still serves every host, a station or not
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["intel"]); g._tick_teams(0.0)   # no station at the main node
	var h := near(); own(h, ["bot"])   # nothing to do on h
	var mine := ids(h)
	var tip := ""; var state := ""
	for k in 30:   # nothing to do where it is: it heads home, and hovering it says so
		g._sim_step(g.SIM_DT)
		for wid in mine:
			var f: Dictionary = g._flight_of(wid)
			if tip == "" and not f.is_empty() and str(f.trip) == "home" and int(f.dest) == home:
				tip = " | ".join(PackedStringArray(g._flight_lines(f))); state = g._worker_state(wid)
		if tip != "": break
	check(tip.contains("Heading home: nothing to do") and state == "joining", "A new remote station's worker with nothing to do on its host heads home, and says so when hovered (%s; state %s)" % [tip, state])
	step(4.0)
	var at_hub := 0
	for wid in mine: if int(g.workers[wid].base) == home and g._worker_state(wid) == "idle": at_hub += 1
	check(at_hub == 2, "...and both wait free at the main node (%d of 2)" % at_hub)
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
	check(int(counts.idle) == 0 and int(counts.joining) == 0, "With materials to carry, no worker stays free or heads home (%s)" % str(counts))
	# a new station's workers start working where their station is: that host's own surplus, loaded there at once
	fresh()
	home = int(g.rig[P])
	var s := near(); own(s, ["intel", "", ""])
	g.hosts[s].store = {P: {"intel": 3.0}}   # three units to send home
	g._set_builds(s, ["intel", "bot", ""]); g._tick_teams(0.0)   # its station is finished now
	var fresh_ids := ids(s)
	g._sim_step(g.SIM_DT)
	var legs := []
	for wid in fresh_ids:
		var f: Dictionary = g._flight_of(wid)
		legs.append(leg_text(f) if not f.is_empty() else "free")
	check(fresh_ids.size() == 2 and legs.all(func(x): return str(x) == "carry %d->%d intel" % [s, home]),
		"A new station's workers start where their station is: their first job is its own surplus, loaded there at once (%s)" % str(legs))


func direct_delivery() -> void:   # 0.6.16: a site's material comes from wherever it is spare STRAIGHT to the site
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["cash", "bot", ""]); g._tick_teams(0.0)   # no Intel harvester at the main node
	g.bank[P].intel = 0.0                                              # and no Intel in the bank (the trickle needs 12 s for a unit)
	var z := near(); own(z, ["intel"])
	var spare := 6.0
	g.hosts[z].store = {P: {"intel": spare}}   # a host with spare Intel
	var s := near([z]); own(s, [])
	g._cmd(["build", s, 0, "intel"])   # a project that needs Intel only
	g._sim_step(g.SIM_DT)
	var jobs := []
	for wid in ids(home):
		var f: Dictionary = g._flight_of(wid)
		var jb: Dictionary = f.get("job", {}) if not f.is_empty() else {}
		jobs.append("%s %d->%d %s %s" % [str(f.get("trip", "free")), int(jb.get("src", -1)), int(jb.get("dst", -1)), str(jb.get("res", "")), str(jb.get("purpose", ""))])
	var want := "fetch %d->%d intel build:" % [z, s]
	check(jobs.size() == 2 and jobs.all(func(x): return str(x).begins_with(want)),
		"A site's Intel, not in the bank but spare on another host, is fetched there for the site itself, not for the bank (%s)" % str(jobs))
	var seen := {}; var direct := 0; var via_home := 0; var from_site := 0
	for k in int(round(8.0 / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		for f in g.flights:
			if str(f.kind) != "courier" or int(f.owner) != P or seen.has(int(f.id)): continue
			seen[int(f.id)] = true
			if (f.cargo as Dictionary).has("intel"):
				if int(f.origin) == z and int(f.dest) == s: direct += 1
				if int(f.dest) == home: via_home += 1
			if str(f.trip) == "fetch" and int(f.origin) == s and int((f.job as Dictionary).get("src", -1)) == z: from_site += 1
	var esc := float((g.hosts[s].jobs.get(0, {}).get("escrow", {}) as Dictionary).get("intel", 0.0)) if g.hosts[s].jobs.has(0) else float(g.BUILD_COSTS.intel.intel)
	check(direct >= int(spare) and via_home == 0 and led("from:%d:intel" % z) < 0.001 and led("in:delivered:intel") < 0.001 and esc >= spare - 0.001,
		"...and carried from that host straight to the site: %d loaded legs host -> site, %d to the main node, nothing banked; %s Intel in the site's escrow (of the %s spare)" % [direct, via_home, g._amt(esc), g._amt(spare)])
	check(from_site >= 1, "A worker that delivered to the site is free there and goes for the next unit from the site (%d fetches started at the site)" % from_site)


func strict_building() -> void:   # 0.6.16: building comes strictly first - no export while a delivery to a site could go
	fresh()
	var home: int = int(g.rig[P])
	var c := near(); own(c, ["", "", ""])   # the site, one hop out
	var a := near([c]); own(a, ["cred"])    # surplus the project does not use: Credentials one hop out...
	var b := hop2([a, c]); own(b, ["lab"])  # ...and Research two hops out
	g.hosts[a].store = {P: {"creds": g.STORE_CAP - 1.0}}; g.hosts[b].store = {P: {"research": 6.0}}   # a is about to fill up
	g._cmd(["build", c, 0, "bot"])   # its whole bill is in the bank
	var tight0: bool = g._tight_now(a)
	var seen := {}; var exports := 0; var done_t := -1.0
	for k in int(round(40.0 / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		var open := open_bill(c)
		for f in g.flights:
			if str(f.kind) != "courier" or int(f.owner) != P or seen.has(int(f.id)): continue
			seen[int(f.id)] = true
			var to_bank := (str(f.trip) == "fetch" and int((f.job as Dictionary).get("dst", -1)) == home) or (str(f.trip) == "carry" and int(f.dest) == home and not (f.cargo as Dictionary).is_empty())
			if to_bank and open > 0.0001: exports += 1
		if open <= 0.0001 and done_t < 0.0: done_t = g._t
		if done_t > 0.0 and g._t > done_t + 20.0: break
	check(b >= 0 and tight0 and done_t > 0.0 and exports == 0,
		"While a project's bill is not all on its way, no worker takes an export, even from a host about to fill up (%d did; all %s units on their way after %.1f s)" % [exports, g._amt(bill_total("bot")), done_t])
	check(led("from:%d:creds" % a) >= 1.0 and led("from:%d:research" % b) >= 1.0,
		"...then both hosts' surplus goes home (%s Credentials, %s Research)" % [g._amt(led("from:%d:creds" % a)), g._amt(led("from:%d:research" % b))])


func no_over_serving() -> void:   # 0.6.16: no more workers sent to a host than it has units to give
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot", "bot", "bot"]); g._tick_teams(0.0)   # six workers at the main node
	var h := near(); own(h, ["cred", "cash", "intel"])   # Credentials, Crypto and Intel made on one host
	g.hosts[h].cyc = 60.0   # (no cycle meanwhile)
	g.hosts[h].store = {P: {"creds": 1.0, "cash": 1.0, "intel": 1.0}}
	var units := 3.0
	g._sim_step(g.SIM_DT)
	var sent := 0; var booked := 0.0
	for f in g.flights:
		if str(f.kind) == "courier" and int(f.owner) == P and int((f.job as Dictionary).get("src", -1)) == h: sent += 1; booked += float(f.job.amt)
	var counts: Dictionary = g._worker_counts(P)
	check(ids().size() == 6 and sent == int(units) and absf(booked - units) < 0.001 and int(counts.idle) == 6 - int(units),
		"A host with %s units to give and 6 free workers gets %d workers, one per unit; the other %d stay free at the main node (%d sent, %s booked)" % [g._amt(units), int(units), 6 - int(units), sent, g._amt(booked)])
	step(4.0)
	var home_got := led("from:%d:creds" % h) + led("from:%d:cash" % h) + led("from:%d:intel" % h)
	check(absf(home_got - units) < 0.001 and (g.hosts[h].get("claim", {}) as Dictionary).is_empty() and g._store_total(h) < 0.001,
		"Each unit went home once (%s) and every claim on the host was released (%s)" % [g._amt(home_got), str(g.hosts[h].get("claim", {}))])


func always_busy() -> void:   # 0.6.16: while there is work, no worker waits - not at the main node, not heading home
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["intel", "bot", "bot"]); g._tick_teams(0.0)   # four workers
	var a := near(); own(a, ["cred"]); var b := near([a]); own(b, ["lab"])
	g.hosts[a].store = {P: {"creds": g.STORE_CAP}}; g.hosts[b].store = {P: {"research": g.STORE_CAP}}   # full storages
	var c := hop2([a, b]); own(c, ["", "", ""])
	g._cmd(["build", c, 0, "intel"])   # and a project two hops out
	var streak := {}; var worst := 0.0; var free_t := 0.0; var all_t := 0.0; var worked := 0.0
	for k in int(round(20.0 / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		var work: float = g._store_free(a, P, "creds") + g._store_free(b, P, "research") + open_bill(c)
		if work < 1.0: continue   # (only while a whole job is still waiting for a worker)
		worked += g.SIM_DT
		for wid in ids():
			var st: String = g._worker_state(wid)
			all_t += g.SIM_DT
			if st == "idle" or st == "joining":
				streak[wid] = float(streak.get(wid, 0.0)) + g.SIM_DT; free_t += g.SIM_DT
				worst = maxf(worst, float(streak[wid]))
			else: streak[wid] = 0.0
	check(c >= 0 and worked >= 10.0 and worst <= g.LOGI_EVERY + g.SIM_DT + 0.0001 and free_t <= 0.02 * all_t,
		"While work waits (%.0f s of 20), no worker is free longer than one dispatch look (%.2f s at most, %.1f%% of worker time free)" % [worked, worst, 100.0 * free_t / maxf(0.001, all_t)])


func cands_now(owed: Dictionary) -> Array:   # every request a worker at the main node could take right now (bank stock, room)
	var home: int = int(g.rig[P])
	var out := []
	for r in g._open_requests(P, home):
		var amt: float = g._amount(P, home, r, owed)
		if amt > 0.0001: var c: Dictionary = r.duplicate(); c.amt = amt; out.append(c)
	return out


func building_first_rules() -> void:   # 0.6.10: building is the workers' first job, and the bank's stock it needs is its own
	fresh()
	var a := near(); own(a, ["intel", "cash"])   # production hosts (0.6.12: a Miner needs no Intel; only a Firewall's upkeep,
	var b := near([a]); own(b, ["cash"])          # checked below, asks the bank for a supply)
	g.bank[P].intel = 12.0
	g._cmd(["build", b, 1, "intel"])               # a project that needs exactly the bank's 12 Intel
	var owed: Dictionary = g._build_owed(P)
	check(absf(float(owed.get("intel", 0.0)) - 12.0) < 0.01 and float(g._supply_budget(P, owed).intel) < 0.01, "The bank's 12 Intel are owed to the project: supplies may use none (owed %s)" % str(owed))
	var cands := cands_now(owed)
	var inputs: Array = g._open_requests(P, int(g.rig[P])).filter(func(r): return str(r.dir) == "in" and not str(r.purpose).begins_with("build:"))
	check(inputs.is_empty() and not cands.any(func(r): return str(r.purpose) == "input" and str(r.res) == "intel"), "No Intel supply to a Miner is asked for or feasible while the project needs it: Miners need none (%s)" % str(inputs))
	var low := INF   # the bank's Intel beyond what the project still needs: supplies only ever take from that
	for k in 40:
		step(0.5)
		low = minf(low, g._free(P, "intel") - float(g._build_owed(P).get("intel", 0.0)))
	var got := float((g.hosts[b].jobs.get(1, {}).get("escrow", {}) as Dictionary).get("intel", 0.0)) if g.hosts[b].jobs.has(1) else 12.0
	check(low > -0.01 and got >= 6.0, "For 20 s supplies only took Intel the project did not need (the bank never fell below its need: %.2f), and the project got %.0f of 12" % [low, got])
	# a Bot station first, whatever was ordered before it
	fresh()
	a = near(); own(a, ["intel", "", ""]); b = near([a]); own(b, ["intel", "", ""])
	g._cmd(["build", a, 1, "wall"]); g._cmd(["build", b, 1, "bot"])
	var first: Dictionary = g._pick_request(P, cands_now(g._build_owed(P)), 0, {})
	var job: Dictionary = g._job_for(int(first.get("host", -1)), str(first.get("purpose", "")).trim_prefix("build:"))
	check(str(job.get("kind", "")) == "bot", "A Bot station's materials go first: its workers carry for every other project (%s)" % str(job.get("kind", "")))
	# (0.6.16) building strictly first: no fourth turn for a host about to fill up any more
	g.hosts[a].store = {P: {"intel": 9.0}}
	var cands2 := cands_now(g._build_owed(P))
	var picks := []
	for turn in 4: picks.append(str(g._pick_request(P, cands2, turn, {}).get("purpose", "")))
	check(g._tight_now(a) and picks.all(func(x): return str(x).begins_with("build:")),
		"While building, every turn carries materials, even with a host about to fill up: the three-turns-of-four rule is gone (%s)" % str(picks))
	var home: int = int(g.rig[P])
	var free := ids(home)
	g._dispatch(P, home, free.duplicate())
	var jobs := []
	for wid in free:
		var f: Dictionary = g._flight_of(wid)
		var p := str(f.get("purpose", "")) if str(f.get("trip", "")) == "carry" else str((f.get("job", {}) as Dictionary).get("purpose", ""))
		jobs.append("%s %s" % [leg_text(f), p] if not f.is_empty() else "free")
	check(free.size() == 2 and jobs.all(func(x): return str(x).contains(" build:")),
		"...and every free worker dispatched serves a site, none relieves the full host (%s)" % str(jobs))
	# what a main-node project waits for that is not in the bank is brought home from a host, as building, before exports
	fresh()
	home = int(g.rig[P])
	var m := near(); own(m, ["cash"]); g.hosts[m].store = {P: {"cash": 3.0}}    # spare Crypto on a host
	var t := near([m]); own(t, ["intel"]); g.hosts[t].store = {P: {"intel": 9.0}}  # a host about to fill up
	g.bank[P].cash = 0.0
	g._cmd(["build", home, 2, "cred"])   # a main-node project: its Intel is in the bank, its Crypto is not
	var lack: Dictionary = g._build_lack(P, g._build_owed(P, true))
	var w0: int = ids(home)[0]
	g._dispatch(P, home, [w0])
	var f0: Dictionary = g._flight_of(w0)
	var j0: Dictionary = f0.get("job", {})
	check(lack.has("cash") and g._tight_now(t) and str(f0.get("trip", "")) == "fetch" and int(j0.get("src", -1)) == m and int(j0.get("dst", -1)) == home and str(j0.get("res", "")) == "cash",
		"Crypto a main-node project waits for, not in the bank, is fetched from a host first, before a full host's export (lack %s; job %s)" % [str(lack), str(j0)])
	# a Firewall fed from the bank stays on while you build, and a project the workers cannot reach holds no stock
	fresh()
	var w := near(); own(w, ["wall", "", ""])   # no Intel harvester: its upkeep comes from the bank
	g.hosts[w].sockets = ["filter", "", ""]
	var others := []
	for k in 3:
		var o := near([w] + others)
		if o < 0: break
		others.append(o); own(o, ["intel", "", ""])
	g.bank[P].intel = 150.0
	for o in others: g._cmd(["build", o, 1, "cred"]); g._cmd(["build", o, 2, "lab"])
	var off := 0.0
	for k in 120:
		step(0.5)
		if not bool(g.hosts[w].get("fw_on", true)): off += 0.5
	check(off <= 0.01, "A Firewall whose upkeep comes from the bank never goes off while you build (off %.1f s of 60)" % off)
	fresh()
	var far := -1   # a host whose only road home runs through b
	for cand_b in g.hosts[int(g.rig[P])].links:
		if far >= 0 or int(g.hosts[int(cand_b)].owner) != g.NEUTRAL: continue
		b = int(cand_b)
		for nb in g.hosts[b].links:
			var c0 := int(nb)
			if far >= 0 or int(g.hosts[c0].owner) != g.NEUTRAL: continue
			var other0 := false
			for nb2 in g.hosts[c0].links: other0 = other0 or (int(nb2) != b and int(g.hosts[int(nb2)].owner) == P)
			if not other0: far = c0
	own(b, ["", "", ""]); own(far, ["", "", ""])
	g._cmd(["build", far, 0, "wall"])
	check(far >= 0 and float(g._build_owed(P).get("intel", 0.0)) > 1.0, "Setup: a Firewall project two hops out holds the bank's Intel (far %d, jobs %s, owed %s)" % [far, str(g.hosts[far].jobs) if far >= 0 else "-", str(g._build_owed(P))])
	g._capture(b, R)   # the road to it is cut
	check(not g._route_ok(P, int(g.rig[P]), far), "Setup: the road to it is cut")
	check(g._build_owed(P).is_empty() and float(g._supply_budget(P, g._build_owed(P)).intel) >= g._free(P, "intel") - 0.01, "Cut off, it holds nothing: supplies elsewhere get the bank's stock again (owed %s)" % str(g._build_owed(P)))


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
	step(60.0)
	check(led("from:%d:intel" % a) >= 1.0 and led("from:%d:intel" % b) >= 1.0, "Once the building is supplied, both hosts' surplus is collected in turn, not one host's only (%.0f, %.0f)" % [led("from:%d:intel" % a), led("from:%d:intel" % b)])


func storage_fair() -> void:   # 0.6.12: a storage short of room for a whole cycle gives every producer the same share of its output
	fresh()
	g._set_builds(int(g.rig[P]), ["intel"]); g._tick_teams(0.0)   # no Bot station: nothing leaves the storage meanwhile
	var kinds := ["intel", "cash", "cred", "lab"]
	var h := near(); own(h, kinds, "erp")
	var gross := 0.0   # one whole cycle's output
	for kind in kinds: gross += one(h, kind)
	var pre: float = g.STORE_CAP - gross / 2.0   # room for half of it
	g.hosts[h].store = {P: {"cash": pre}}
	var before := {}
	for r in g.RES: before[r] = g._st_get(h, P, r)
	g.hosts[h].cyc = 0.05
	step(0.1)
	var share: float = (g.STORE_CAP - pre) / gross
	var even := absf(g._store_total(h) - g.STORE_CAP) < 0.001
	var made := {}
	for kind in kinds:
		var out := str(g.BUILD_KINDS[kind].out)
		made[out] = g._st_get(h, P, out) - float(before[out])
		if absf(float(made[out]) - one(h, kind) * share) > 0.001: even = false
	check(share > 0.001 and share < 0.999 and even,
		"Room for %s of a cycle's %s units: each of the %d producers makes the same %d%% of its output, the harvester does not fill the storage first (%s)"
		% [g._amt(g.STORE_CAP - pre), g._amt(gross), kinds.size(), int(round(share * 100.0)), str(made)])


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
	check(arrived_before_work, "No work happens before all %s units are in the site's escrow (beyond the %s-unit store)" % [g._amt(bill_total("bot")), g._amt(g.STORE_CAP)])
	check(str(g.hosts[h].builds[0]) == "bot" and ids(h).size() == 2, "Built after %.1f s (ideal 26 s on one hop): its two workers start" % (g._t - t0))
	check(absf(led("out:supply:intel") + led("out:supply:cash") - bill_total("bot")) < 0.01, "Exactly the bill was carried: %s units" % g._amt(bill_total("bot")))
	# local stock reduces what is carried
	fresh()
	var h2 := near(); g._capture(h2, P); g.hosts[h2].slots = 3; g._set_builds(h2, [])
	var bill: Dictionary = g.BUILD_COSTS.bot
	var stock := 5.0   # Crypto already at the site: less than the bill's Crypto (0.6.12: a Bot station is paid mainly in Crypto)
	g.hosts[h2].store = {P: {"cash": stock}}
	g._cmd(["build", h2, 0, "bot"])
	for k in 60 * 30:
		g._sim_step(g.SIM_DT)
		if not g.hosts[h2].jobs.has(0): break
	var want_i := float(bill.get("intel", 0.0)); var want_c := maxf(0.0, float(bill.get("cash", 0.0)) - stock)
	check(stock < float(bill.get("cash", 0.0)) and absf(led("out:supply:intel") - want_i) < 0.01 and absf(led("out:supply:cash") - want_c) < 0.01,
		"%s Crypto already there: only %s Intel and %s Crypto were carried (%s, %s)" % [g._amt(stock), g._amt(want_i), g._amt(want_c), g._amt(led("out:supply:intel")), g._amt(led("out:supply:cash"))])


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
		var used := bill_total("bot") * worked
		check(absf(total0 + trickle - used - where) < 0.05, "Cancelled %s: every unit is in the bank, on the road or in the site's salvage pile (%.2f of %.2f; %.1f used by work)" % [when, where, total0 + trickle - used, used])
	fresh()
	var h3 := near(); g._capture(h3, P); g.hosts[h3].slots = 3; g._set_builds(h3, [])
	g._cmd(["build", h3, 0, "bot"])
	step(3.0)
	g._cmd(["job", h3, 0])   # the retired pause order: ignored, deliveries go on
	var esc0 := 0.0
	for r in (g.hosts[h3].jobs[0].escrow as Dictionary): esc0 += float(g.hosts[h3].jobs[0].escrow[r])
	step(3.0)
	var esc1 := 0.0
	for r in (g.hosts[h3].jobs[0].escrow as Dictionary): esc1 += float(g.hosts[h3].jobs[0].escrow[r])
	check(esc1 > esc0 + 0.5 and not g.hosts[h3].jobs[0].has("paused"), "A project cannot be paused: deliveries go on (escrow %.0f → %.0f)" % [esc0, esc1])
	# capture mid-delivery: the site's materials are lost to the former owner, recorded once
	var esc := 0.0
	for r in (g.hosts[h3].jobs[0].escrow as Dictionary): esc += float(g.hosts[h3].jobs[0].escrow[r])
	g._capture(h3, R)
	check(absf(led("lost:site:intel") + led("lost:site:cash") - esc) < 0.001 and (g.hosts[h3].jobs as Dictionary).is_empty(), "Captured mid-delivery: its %.0f site units are recorded lost, nothing refunded" % esc)


func fairness() -> void:   # endless upkeep demand must not starve a build or an export-only host
	fresh()
	var home: int = int(g.rig[P])
	var hosts := []
	for nb in g.hosts[home].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: hosts.append(int(nb))
	var a: int = hosts[0]; var b: int = hosts[1]; var c: int = hosts[2] if hosts.size() > 2 else -1
	g._capture(a, P); g.hosts[a].slots = 3; g._set_builds(a, ["wall", "wall", "wall"])   # hungry: 3 Intel a cycle for its Firewalls, forever
	g._capture(b, P); g.hosts[b].slots = 3; g._set_builds(b, ["intel"])              # export only
	if c >= 0: g._capture(c, P); g.hosts[c].slots = 3; g._set_builds(c, [])
	g.bank[P].intel = 150.0
	if c >= 0: g._cmd(["build", c, 0, "wall"])
	step(60.0)
	# (0.6.16: its Intel may go straight to the hungry Firewall host next door instead of the bank)
	var stored_b: float = float(g._store_of(b, P).get("intel", 0.0))
	check(stored_b < float(g.STORE_CAP) - 0.5, "An export-only host still gets its Intel collected: its storage never fills (%.1f of %d)" % [stored_b, int(g.STORE_CAP)])
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


func resources_in_turn() -> void:   # one host with two surpluses: both go home in turn, not only the older request's
	fresh()
	var home: int = int(g.rig[P])
	var h := near()
	own(h, [])
	g.hosts[h].type = "server"; g.hosts[h].slots = 3; g._set_builds(h, ["intel", "intel", "lab"])   # Intel always spare, plus Research
	for res in g.RES: g.bank[P][res] = 100.0
	step(240.0)
	var sums: Dictionary = g._ledger_sums(P)
	var research := float(sums.get("from:%d:research" % h, 0.0)); var intel := float(sums.get("from:%d:intel" % h, 0.0))
	check(research > 0.5 and intel > 0.5, "A Lab host that always has spare Intel still sends its Research home (recent: %.1f Research, %.1f Intel)" % [research, intel])
