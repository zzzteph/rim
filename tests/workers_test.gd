extends SceneTree
## Delivery workers and physical construction: two reusable workers per Bot station with stable identities, all of
## them ONE pool working from the main node (a new station's workers go there first); automatic demand (0.6.12: the
## only input left is a Firewall's upkeep - local Intel first, the net shortfall brought - while every producer makes
## its own resource with no input, a storage short of room is shared evenly, and the output is collected);
## construction and upkeep first, then surplus, the hosts served in turn; one unit per leg; claims taken once; capture
## destroys a station's workers wherever they are; a lost worker is replaced at its surviving station; construction
## is supplied into escrow before its work runs.
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
	no_ping_pong()
	one_pool()
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
	var short := 3.0 * upkeep() - one(b, "intel")
	var req := {}
	for r in g._open_requests(P, int(g.rig[P]), b):
		if str(r.purpose) == "upkeep" and str(r.res) == "intel": req = r
	check(short > 0.999 and absf(float(plan.short.intel) - short) < 0.001 and absf(float(plan.upkeep) - short) < 0.001 and absf(float(req.get("qty", 0.0)) - short) < 0.001,
		"Makes %s, needs %s: the %s-unit shortfall is brought as the Firewalls' upkeep (requested %s)" % [g._amt(one(b, "intel")), g._amt(3.0 * upkeep()), g._amt(short), g._amt(float(req.get("qty", 0.0)))])


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


func shared_trips() -> void:
	fresh()
	var h := near(); own(h, ["wall", "cash"])   # Intel to bring for the Firewall, Crypto to collect
	g.hosts[h].store = {P: {"cash": 3.0}}
	step(0.1)
	var both := false
	for f in g.flights:
		if str(f.kind) == "courier" and (f.cargo as Dictionary).has("intel") and int((f.job as Dictionary).get("src", -1)) == h and str((f.job as Dictionary).get("res", "")) == "cash": both = true
	check(both, "One round trip does both: the Firewall's Intel out to the host, and its Crypto booked for the way back")


func no_double_claim() -> void:
	fresh()
	var h := near(); own(h, ["wall"])   # its Firewall's upkeep: one Intel a cycle from the bank
	g.bank[P].intel = upkeep()
	step(0.1)
	var carrying := 0
	for f in g.flights:
		if str(f.kind) == "courier" and (f.cargo as Dictionary).has("intel"): carrying += 1
	check(carrying == 1 and g._avail(P, "intel") < 0.5 and absf(led("out:supply:intel") - upkeep()) < 0.001,
		"Two free workers, one Intel at the main node for a Firewall: only one carries it, and it left the bank once (%s)" % g._amt(led("out:supply:intel")))
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
	var h := near(); own(h, ["wall"])   # nothing makes Intel here: its Firewall's upkeep is brought
	g.hosts[h].cyc = 11.0   # its cycle comes late, so the delivered Intel waits there a while
	for k in 120:
		step(0.1)
		if float(g._store_of(h, P).get("intel", 0.0)) >= upkeep() - 0.001: break
	var plan: Dictionary = g._host_plan(h, P, {})
	check(float(g._store_of(h, P).get("intel", 0.0)) >= upkeep() - 0.001 and float(plan.export.intel) < 0.001, "Delivered Intel is kept for the Firewall's next cycle, not offered back")
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


func cands_now(owed: Dictionary) -> Array:   # every request a worker could take right now, as _assign sees them
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
	# the fourth turn keeps production going: a host about to fill up, or what the projects wait for
	g.hosts[a].store = {P: {"intel": 9.0}}
	var cands2 := cands_now(g._build_owed(P))
	var turn3: Dictionary = g._pick_request(P, cands2, 3, {})
	var turn0: Dictionary = g._pick_request(P, cands2, 0, {})
	check(str(turn3.get("dir", "")) == "out" and int(turn3.get("host", -1)) == a and str(turn0.get("purpose", "")).begins_with("build:"), "While building, three turns of four carry materials and the fourth relieves a host about to fill up (%s, then %s)" % [str(turn0.get("purpose", "")), str(turn3.get("purpose", ""))])
	g.hosts[a].store = {}; g.hosts[b].store = {P: {"cash": 3.0}}; g.bank[P].cash = 0.0
	var owed3: Dictionary = g._build_owed(P)
	var lack: Dictionary = g._build_lack(P, owed3)
	var pick_lack: Dictionary = g._pick_request(P, cands_now(owed3), 3, lack)
	check(lack.has("cash") and str(pick_lack.get("res", "")) == "cash" and str(pick_lack.get("dir", "")) == "out", "Crypto the projects wait for, not in the bank, is collected from a host on that turn (%s %s)" % [str(lack), str(pick_lack.get("purpose", ""))])
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
