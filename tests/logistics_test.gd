extends SceneTree
## Logistics: delivery workers are reusable and belong to a host; a remote host is supplied automatically (0.6.12: its
## Firewall's upkeep, the one input left), uses only what arrived, and its output rides to the bank; every material is
## conserved; defence cards travel and load a socket only on arrival (no overbooking); every kind of packet is held at a
## cut relay, goes on when it reopens, is lost only with a host it is in; nothing ever crosses a rival's or a neutral
## host; destinations never overfill. 0.6.16: a job moves one unit from a source straight to its destination (a site's
## material from the nearest place that can spare it, never via the main node); a worker is free where it delivers and
## goes on from there; building and upkeep strictly first; no more workers sent to a host than it has units; every
## reservation always matches the workers on the road; no worker stays free while a job it could take waits.
## godot --headless --path . --script tests/logistics_test.gd
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


func far_pair() -> Array:   # [via, far]: a host two links out whose only link to your network is `via`
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != g.NEUTRAL or bool(g.hosts[i].hub): continue
		var touches := false
		for nb in g.hosts[i].links: touches = touches or int(g.hosts[int(nb)].owner) == P
		if touches: continue
		for nb in g.hosts[i].links:
			var v := int(nb)
			if int(g.hosts[v].owner) != g.NEUTRAL: continue
			for nb2 in g.hosts[v].links:
				if int(g.hosts[int(nb2)].owner) == P:
					g._capture(v, P); g._capture(i, P)
					g.hosts[i].type = "pc"; g.hosts[i].slots = 3
					return [v, i]
	return []


func sums() -> Dictionary: return g._ledger_sums(P)
func led(key: String) -> float: return float(sums().get(key, 0.0))


func in_flight(res: String) -> float:   # units of res riding P's couriers right now, or taken from the bank for a worker on its way to pick them up
	var n := 0.0
	for f in g.flights:
		if str(f.kind) != "courier" or int(f.owner) != P: continue
		n += float((f.cargo as Dictionary).get(res, 0.0))
		var jb: Dictionary = f.get("job", {})   # (0.6.16: a bank unit leaves the bank when the job starts, before its worker gets there)
		if str(f.trip) == "fetch" and bool(jb.get("bank", false)) and str(jb.get("res", "")) == res: n += float(jb.amt)
	return n


func worker_ids() -> Array:
	var out := []
	for wid in g.workers:
		if int(g.workers[wid].fac) == P: out.append(int(wid))
	out.sort()
	return out


var cycles := 0   # production cycles the watched host ran during step_watch (or watch)
var fed := 0      # ...of them in which its Firewalls were fed (on after the cycle: each ate its upkeep)


func step_watch(secs: float, i: int) -> void:   # step(), counting host i's production cycles and those its Firewalls ate their upkeep in
	for k in int(round(secs / g.SIM_DT)):
		var left := float(g.hosts[i].get("cyc", g.PROD_CYCLE))
		g._sim_step(g.SIM_DT)
		if float(g.hosts[i].get("cyc", g.PROD_CYCLE)) > left:   # its timer wrapped: the host ran a cycle
			cycles += 1
			if bool(g.hosts[i].fw_on): fed += 1


func upkeep_of(i: int) -> float: return float(g.BUILD_KINDS.wall.use.intel) * g._count_all(i, "wall")   # Intel host i's Firewalls eat per cycle


# ---- 0.6.16 watchers: every leg of every worker, the reservations they hold, and free workers while work waits ----
var legs := {}           # wid -> its legs in launch order: {id, trip, from, to, route, cargo, purpose, job, t}
var seen_legs := {}
var idle_streak := {}    # wid -> how long it has been free while a job it could take was waiting
var idle_worst := 0.0    # the longest such streak seen
var idle_time := 0.0     # worker-seconds free while a job was waiting
var busy_time := 0.0     # worker-seconds on a leg
var free_time := 0.0     # worker-seconds free (with or without a job waiting)
var home_with_work := 0  # empty legs home that set off while a job was waiting
var home_legs := 0
var resv_err := ""       # the first reservation that did not match what the workers on the road hold


func watch_reset() -> void:
	legs = {}; seen_legs = {}; idle_streak = {}; idle_worst = 0.0; idle_time = 0.0; busy_time = 0.0; free_time = 0.0
	home_with_work = 0; home_legs = 0; resv_err = ""; cycles = 0; fed = 0
	for f in g.flights: seen_legs[int(f.id)] = true   # (legs already under way are not recorded)


func track() -> int:   # record every new leg of P's workers; returns how many empty legs home just set off
	var homes := 0
	for f in g.flights:
		if str(f.kind) != "courier" or int(f.owner) != P or seen_legs.has(int(f.id)): continue
		seen_legs[int(f.id)] = true
		var wid := int(f.wid)
		if not legs.has(wid): legs[wid] = []
		legs[wid].append({"id": int(f.id), "trip": str(f.trip), "from": int(f.route[0]), "to": int(f.dest), "route": (f.route as Array).duplicate(),
			"cargo": (f.cargo as Dictionary).duplicate(), "purpose": str(f.get("purpose", "")), "job": (f.get("job", {}) as Dictionary).duplicate(), "t": float(g._t)})
		if str(f.trip) == "home": homes += 1
	return homes


func work_waiting() -> bool:   # a job a free worker could start now: a host's whole spare unit with bank room for it, or a site's unit the bank has
	var hub: int = int(g.rig[P])
	var owed: Dictionary = g._build_owed(P)
	var due: Dictionary = g._arriving(P)   # (a host's surplus waits for the loaded worker already on its way there: that is not a free worker's job)
	for i in g.hosts.size():
		if i == hub or int(g.hosts[i].owner) != P or g._routing_down(i) or not g._route_ok(P, hub, i): continue
		var plan: Dictionary = g._host_plan(i, P, g._supply_budget(P, owed), g._upkeep_extra(P, owed))   # (it only reads)
		var spare_units := 0.0
		for res in g.RES: spare_units += floorf(float(plan.export[res]) + 0.0001) if g._room(P, res) >= 1.0 else 0.0
		if spare_units - float((due.get(i, []) as Array).size()) * g.WORKER_CARRY >= 0.999: return true
		for b in g._build_requests(i, P):
			if g._free(P, str(b[1])) >= minf(g.WORKER_CARRY, float(b[2])) - 0.0001: return true
	return false


func dest_key(d: int, purpose: String, res: String) -> String:   # which reservation a unit on its way to d holds ("": none)
	if d == int(g.rig[P]): return "bank:" + res
	if purpose.begins_with("build:"):   # (a cancelled project's units land at its site as salvage: nothing is held for them)
		return "" if g._job_for(d, purpose.trim_prefix("build:")).is_empty() else "escrow:%d:%s:%s" % [d, purpose.trim_prefix("build:"), res]
	return "inbound:%d:%s" % [d, res]


func reservations_ok() -> String:   # "" when every reservation is exactly what P's workers on the road hold (no claim or room left behind, none missing)
	var want := {}
	for f in g.flights:
		if str(f.kind) != "courier" or int(f.owner) != P: continue
		var jb: Dictionary = f.get("job", {})
		var add := {}
		if str(f.trip) == "fetch" and not jb.is_empty():
			if not bool(jb.get("bank", false)): add["%s:%d:%s" % ["pclaim" if bool(jb.get("pile", false)) else "claim", int(jb.src), str(jb.res)]] = float(jb.amt)
			add[dest_key(int(jb.dst), str(jb.purpose), str(jb.res))] = float(jb.amt)
		for res in (f.cargo as Dictionary):
			var k := dest_key(int(f.dest), str(f.get("purpose", "")), str(res))
			add[k] = float(add.get(k, 0.0)) + float(f.cargo[res])
		for k in add:
			if str(k) != "": want[k] = float(want.get(k, 0.0)) + float(add[k])
	var have := {}
	for i in g.hosts.size():
		for field in ["claim", "pclaim"]:
			var mine: Dictionary = (g.hosts[i].get(field, {}) as Dictionary).get(P, {})
			for res in mine:
				have["%s:%d:%s" % [field, i, res]] = float(mine[res])
				var there: float = g._loot(i, P, str(res)) if field == "pclaim" else float(g._store_of(i, P).get(res, 0.0))
				if float(mine[res]) > there + 0.001: return "%s on %d: %s claimed of %s there (t %.2f)" % [field, i, g._amt(float(mine[res])), g._amt(there), g._t]
		if int(g.hosts[i].owner) != P: continue   # (room on a rival's host is the rival's workers')
		for res in (g.hosts[i].get("inbound", {}) as Dictionary): have["inbound:%d:%s" % [i, res]] = float(g.hosts[i].inbound[res])
		for slot in (g.hosts[i].jobs as Dictionary):
			var job: Dictionary = g.hosts[i].jobs[slot]
			for res in (job.get("inbound", {}) as Dictionary): have["escrow:%d:%d:%d:%s" % [i, int(job.slot), int(job.id), res]] = float(job.inbound[res])
	for res in g.RES:
		if g._incoming(P, res) > 0.0001: have["bank:" + res] = g._incoming(P, res)
	for k in want.keys() + have.keys():
		if absf(float(want.get(k, 0.0)) - float(have.get(k, 0.0))) > 0.001:
			return "%s: %s held, %s on the road (t %.2f)" % [k, g._amt(float(have.get(k, 0.0))), g._amt(float(want.get(k, 0.0))), g._t]
	return ""


func watch(secs: float, fw_host := -1) -> void:   # step(), recording every leg, checking the reservations, timing free workers while work waits
	for k in int(round(secs / g.SIM_DT)):   # (fw_host: count that host's cycles and those its Firewalls were fed in, as step_watch)
		var left := float(g.hosts[fw_host].get("cyc", g.PROD_CYCLE)) if fw_host >= 0 else 0.0
		g._sim_step(g.SIM_DT)
		if fw_host >= 0 and float(g.hosts[fw_host].get("cyc", g.PROD_CYCLE)) > left:
			cycles += 1
			if bool(g.hosts[fw_host].fw_on): fed += 1
		var homes := track()
		home_legs += homes
		var waiting := -1   # (worked out only when needed)
		if homes > 0:
			waiting = 1 if work_waiting() else 0
			if waiting == 1: home_with_work += homes
		for wid in g.workers:
			var w: Dictionary = g.workers[wid]
			if int(w.fac) != P or str(w.state) == "retiring": continue
			if str(w.state) != "idle": busy_time += g.SIM_DT; idle_streak[wid] = 0.0; continue
			free_time += g.SIM_DT
			if g._sabotaged(int(w.home)) or g._routing_down(int(w.get("base", w.home))): idle_streak[wid] = 0.0; continue
			if waiting < 0: waiting = 1 if work_waiting() else 0
			if waiting == 1:
				idle_streak[wid] = float(idle_streak.get(wid, 0.0)) + g.SIM_DT; idle_time += g.SIM_DT
			else: idle_streak[wid] = 0.0
			idle_worst = maxf(idle_worst, float(idle_streak[wid]))
		if resv_err == "": resv_err = reservations_ok()


func teleports() -> Array:   # legs that did not start where the worker's previous leg ended (where it was free)
	var bad := []
	for wid in legs:
		var ls: Array = legs[wid]
		for k in range(1, ls.size()):
			if int(ls[k].from) != int(ls[k - 1].to): bad.append("worker %d: %s to %d, then %s from %d" % [int(wid), str(ls[k - 1].trip), int(ls[k - 1].to), str(ls[k].trip), int(ls[k].from)])
	return bad


func ring() -> Array:   # [a, b, e]: a and its neighbour b neutral (a linked to the main node, b not), e a host of yours linked to the main node
	var hub: int = int(g.rig[P])
	for nb in g.hosts[hub].links:
		var a := int(nb)
		if int(g.hosts[a].owner) != g.NEUTRAL: continue
		for nb2 in g.hosts[a].links:
			var b := int(nb2)
			if b == hub or int(g.hosts[b].owner) != g.NEUTRAL or (g.hosts[hub].links as Array).has(b): continue
			for nb3 in g.hosts[hub].links:
				if int(nb3) != a and int(g.hosts[int(nb3)].owner) == P: return [a, b, int(nb3)]
	return []


func own(i: int, kinds: Array) -> void:   # take host i as an ordinary 3-slot pc with these buildings
	if int(g.hosts[i].owner) != P: g._capture(i, P)
	g.hosts[i].type = "pc"; g.hosts[i].slots = 3
	g._set_builds(i, kinds)


func run() -> void:
	supply_round_trip()
	firewall_sockets()
	relays()
	no_foreign_transit()
	full_destinations()
	held_at_a_rival_pickup()
	delivered_then_surplus()
	direct_to_site()
	no_overbooking()
	room_for_upkeep()
	main_node_lack()
	upkeep_from_host()
	salvage_to_site()
	ddos_pickup()
	busy_network()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func supply_round_trip() -> void:   # automatic: nobody asks; the Firewall's upkeep (0.6.12: the one input left) is enough
	fresh()
	var pair := far_pair()
	var far: int = pair[1]
	g._set_builds(far, ["cash", "wall"])   # a Miner and a Firewall, no Intel harvester, no station: the main node's two workers bring the upkeep
	var need := upkeep_of(far)   # Intel the Firewall eats each cycle
	var per_cash: float = float(g.BUILD_KINDS.cash.rate) * g._tmult(far, "cash")   # Crypto the Miner makes each cycle (no input)
	var ids0 := worker_ids()
	var bank0 := 0.0
	for r in g.RES: bank0 += g._avail(P, r)
	watch_reset()
	watch(1.0, far)
	var upkeep_out := false   # a main-node courier on its way to the host with the Firewall's Intel, as an upkeep delivery
	for f in g.flights:
		if str(f.kind) == "courier" and int(f.owner) == P and int(f.dest) == far and str(f.get("purpose", "")) == "upkeep":
			upkeep_out = upkeep_out or float((f.cargo as Dictionary).get("intel", 0.0)) >= need - 0.001
	check(upkeep_out and in_flight("intel") >= need - 0.001 and g._inbound(far, "intel") >= need - 0.001,
		"The main node's workers set off with the Firewall's %s Intel on their own; the host's room for it is held" % g._amt(need))
	check(float(g.hosts[far].store.get(P, {}).get("intel", 0.0)) < 0.001, "Nothing is there before it arrives: the Firewall uses only what has arrived")
	watch(24.0, far)
	var supplied := led("out:supply:intel")
	var at_host: float = float(g.hosts[far].store.get(P, {}).get("intel", 0.0))
	var eaten: float = fed * need
	var cash_made: float = led("in:delivered:cash") + float(g.hosts[far].store.get(P, {}).get("cash", 0.0)) + in_flight("cash")
	check(cycles >= 2 and fed == cycles and supplied >= eaten,
		"The workers bring the upkeep in time: the Firewall ate %s Intel in each of its %d cycles and stayed on (%s Intel sent)" % [g._amt(need), cycles, g._amt(supplied)])
	check(absf(cash_made - cycles * per_cash) < 0.001,   # (that it took none of the Intel: the conservation check next)
		"The Miner makes its %s Crypto per cycle with no input (%s Crypto in %d cycles)" % [g._amt(per_cash), g._amt(cash_made), cycles])
	check(absf(supplied - (at_host + in_flight("intel") + eaten)) < 0.01,
		"Intel is conserved: sent %s = %s at the host + %s on the way + %s eaten by the Firewall" % [g._amt(supplied), g._amt(at_host), g._amt(in_flight("intel")), g._amt(eaten)])
	check(led("in:delivered:cash") >= 1.0 and led("from:%d:cash" % far) == led("in:delivered:cash"), "Its Crypto rides back with the workers and reaches the bank (%.0f)" % led("in:delivered:cash"))
	check(led("from:%d:intel" % far) == 0.0, "The Firewall's Intel is never carried back out of the host: what was delivered waits for its cycle")
	check(worker_ids() == ids0, "The same two workers did every trip: reused, never used up (%s)" % str(worker_ids()))
	check(home_legs >= 1 and home_with_work == 0 and idle_worst <= g.LOGI_EVERY + 2.0 * g.SIM_DT and resv_err == "" and teleports().is_empty(),
		"(0.6.16) With nothing left to do a worker heads home from where it delivered (%d legs home), never while a job waits (%d); no worker is free while one waits (longest %.2f s); every reservation matches the road (%s)"
		% [home_legs, home_with_work, idle_worst, resv_err])
	var made := 0.0   # what the main node made (its trickle and production); a remote host's output is booked only when it lands
	for r in g.RES: made += led("in:trickle:" + r) + led("in:production:" + r)
	var now := 0.0
	for r in g.RES: now += g._avail(P, r) + float(g.hosts[far].store.get(P, {}).get(r, 0.0)) + in_flight(r)
	var expect: float = bank0 + made + cycles * per_cash - eaten   # plus the far Miner's Crypto, less the Intel its Firewall ate
	check(absf(now - expect) < 0.05,
		"Every material is accounted for across the round trip: bank + host + in flight = start + made - eaten by the upkeep (%.2f vs %.2f)" % [now, expect])


func firewall_sockets() -> void:
	fresh()
	var pair := far_pair()
	var far: int = pair[1]
	g._set_builds(far, ["intel", "wall"])
	g.hosts[far].fw_on = true
	g.cards[P] = {"patch": 5}
	for k in 4: g._play_card(P, "patch", far)
	var loads: int = g.flights.filter(func(f): return str(f.kind) == "op" and bool(f.get("load", false))).size()
	check(g._socket_res(far) == 3 and loads == 3 and g._loaded(far).is_empty(), "Four Patches sent to a 3-socket Firewall: three hold a socket, nothing is loaded before they arrive")
	step(4.0)
	check((g.hosts[far].sockets as Array).count("patch") == 3 and g._socket_res(far) == 0, "On arrival three load their sockets")
	check(float(g.hosts[far].patch_armed_until) > g._t, "...and the fourth, with no socket left, acts on arrival (it arms a Patch)")
	g.hosts[far].sockets = []
	g._play_card(P, "patch", far)
	check(g._socket_res(far) == 1, "A Patch on its way holds a socket")
	g._set_builds(far, ["intel", ""])   # the Firewall is demolished while the card flies
	g.hosts[far].patch_armed_until = 0.0
	step(4.0)
	check(g._socket_res(far) == 0 and float(g.hosts[far].patch_armed_until) > g._t, "Its Firewall gone on arrival, the Patch acts instead and the held socket is released")
	g._start_job(far, "wall", 1)
	check(g._sockets(far) == 0, "A Firewall still being built has no sockets yet")
	var t0: float = g._t
	var bill := 0.0
	for r in g.BUILD_COSTS.wall: bill += float(g.BUILD_COSTS.wall[r])
	var n_w := worker_ids().size()
	var bank_trips: float = ceilf(bill / (n_w * g.WORKER_CARRY)) * 2.0 * g._leg_time(P, int(g.rig[P]), far)   # every unit from the bank, there and back
	var limit: float = 2.0 * (bank_trips + g.BUILD_TIME)   # (only a timeout: twice that, then the work; it scales with the bill)
	for k in int(round(limit / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		if not g.hosts[far].jobs.has(1): break
	check(g._sockets(far) == g.FIREWALL_SOCKETS, "Once its %d units have arrived (two hops, %d main-node workers) and it is built, it has its %d (%.0f s)" % [int(bill), n_w, g.FIREWALL_SOCKETS, g._t - t0])
	# a defence card whose target is lost on the way comes back to your hand
	g.cards[P] = {"response": 1}
	g._play_card(P, "response", far)
	g._capture(far, R)
	step(6.0)
	check(g._held(P, "response") == 1 and not g.flights.any(func(f): return str(f.kind) == "op"), "A defence card whose host is taken on the way returns, and the copy is back in your hand")


func relays() -> void:   # every kind of packet, at a relay that is knocked out, then at one that is taken
	fresh()
	var home: int = int(g.rig[P])
	var pair := far_pair()
	var via: int = pair[0]; var far: int = pair[1]
	g._set_builds(far, ["cash", "wall"])   # no station and no Intel here: the main node's workers bring its Firewall's upkeep
	var need := upkeep_of(far)
	var far2 := -1   # a second host past the relay, with its own Bot station
	for nb in g.hosts[far].links:
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL and not g.hosts[via].links.has(n) and not g.hosts[home].links.has(n): far2 = n; break
	g._capture(far2, P); g.hosts[far2].type = "pc"; g.hosts[far2].slots = 3
	g._set_builds(far2, ["bot", "intel"]); g._tick_teams(0.0)
	var beyond := -1   # a rival host linked to far only
	for nb in g.hosts[far].links:
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL and not g.hosts[via].links.has(n) and not g.hosts[home].links.has(n): beyond = n; break
	g._capture(beyond, R)
	g._mark_scanned(P, beyond)
	g.cards[P] = {"breach": 1, "patch": 1}
	g.hosts[far2].store = {P: {"creds": 1.0}}
	g._play_card(P, "breach", beyond)
	g._play_card(P, "patch", far)
	g._tick_logistics()   # far2's courier with Credentials; a main-node courier with the upkeep Intel for far
	var kinds := {}
	for f in g.flights: kinds[str(f.kind) + ("/def" if str(f.kind) == "op" and bool(g._is_defense(str(f.card))) else "") + ("/host" if str(f.kind) == "courier" and int(f.origin) != home else "")] = true
	check(kinds.has("op") and kinds.has("op/def") and kinds.has("courier") and kinds.has("courier/host"), "Four kinds on the road: an attack, a defence card, a main-node courier, a host's courier (%s)" % [kinds.keys()])
	g.hosts[via].ddos_until = g._t + 6.0   # the relay is knocked out
	cycles = 0; fed = 0
	step_watch(2.0, far)
	var held: int = g.flights.filter(func(f): return bool(f.get("blocked", false))).size()
	check(held == g.flights.size() and held >= 4, "A relay under DDoS holds every packet before it (%d of %d held)" % [held, g.flights.size()])
	check(float(g.hosts[far].store.get(P, {}).get("intel", 0.0)) < 0.001 and g._held(P, "breach") == 0 and g._execs.is_empty(), "Nothing jumps the relay: no early delivery, no early execution")
	check(g.events.any(func(e): return str(e.key).begins_with("held:") and bool(e.live)), "The held packets show as one live event per host")
	var tips_ok := true
	for f in g.flights: tips_ok = tips_ok and (g._flight_lines(f) as Array).size() >= 2 and str(g._flight_lines(f)[1]).begins_with("Held at")
	check(tips_ok, "Hovering a held packet says where it waits and why")
	step_watch(14.0, far)
	check(g._execs.any(func(e): return int(e.target) == beyond) or g.op_outcomes.any(func(o): return int(o.get("target", -1)) == beyond), "When the DDoS ends they go on: the Breach executes on its target")
	var landed: float = float(g.hosts[far].store.get(P, {}).get("intel", 0.0)) + fed * need   # waiting in its storage, or eaten by the Firewall since
	check((g.hosts[far].sockets as Array).has("patch") and g._socket_res(far) == 0 and led("out:supply:intel") >= need and landed >= need and g._inbound(far, "intel") < 0.001,
		"...the Patch reaches its host and loads its Firewall, the upkeep is delivered (%s Intel)" % g._amt(landed))
	check(led("from:%d:creds" % far2) >= 1.0, "...and the host's courier brings its Credentials home")
	# held inside a relay that is then taken: lost there, and every reservation it held is settled
	fresh()
	home = int(g.rig[P])
	pair = far_pair()
	via = pair[0]; far = pair[1]
	g._set_builds(far, ["cash", "wall"])
	need = upkeep_of(far)
	g.cards[P] = {"patch": 1}
	# (0.6.16) the host keeps UPKEEP_KEEP cycles of upkeep within reach and building comes strictly first: with all of it
	# missing, both main-node workers would carry Intel out. One cycle's worth is already there, so one worker carries the
	# one unit still missing and the other, with no building left to serve, goes to collect the Credentials for the bank.
	var keep_have: float = need * g.UPKEEP_KEEP - g.WORKER_CARRY
	g.hosts[far].store = {P: {"creds": 2.0, "intel": keep_have}}
	g._play_card(P, "patch", far)   # (it holds a socket of the Firewall on its way)
	g._tick_logistics()   # one main-node worker: Intel out for the Firewall's upkeep; the other: on its way to collect a Credential
	var up_out := 0; var cr_fetch := 0
	for f in g.flights:
		if str(f.kind) != "courier" or int(f.owner) != P: continue
		if str(f.trip) == "carry" and int(f.dest) == far and str(f.purpose) == "upkeep" and float((f.cargo as Dictionary).get("intel", 0.0)) > 0.0: up_out += 1
		var jb: Dictionary = f.get("job", {})
		if str(f.trip) == "fetch" and int(jb.get("src", -1)) == far and int(jb.get("dst", -1)) == home and str(jb.get("res", "")) == "creds": cr_fetch += 1
	check(keep_have > 0.0 and up_out == 1 and cr_fetch == 1,
		"Upkeep first: one main-node worker carries the missing %s Intel out, the other goes straight out to collect a Credential (%d, %d)" % [g._amt(g.WORKER_CARRY), up_out, cr_fetch])
	var held0 := [g._socket_res(far), g._inbound(far, "intel"), g._claimed(far, P, "creds")]   # what they hold at the far host
	var inc0: float = g._incoming(P, "creds")
	var n_workers := worker_ids().size()
	var n0: int = g.flights.size()
	for f in g.flights: g._block(f, via)   # all of them wait inside the relay
	g._capture(via, R)
	g._tick_blocked()
	check(n0 >= 3 and g.flights.is_empty(), "Packets held in a relay that is taken are lost with it (%d)" % n0)
	check(int(held0[0]) >= 1 and float(held0[1]) >= g.WORKER_CARRY - 0.001 and float(held0[2]) >= 1.0
		and g._socket_res(far) == 0 and g._inbound(far, "intel") < 0.001 and g._claimed(far, P, "creds") < 0.001,
		"Their reservations at the far host are released: the held socket (%d), the room for the upkeep (%s), the claimed pickup (%s)" % [int(held0[0]), g._amt(float(held0[1])), g._amt(float(held0[2]))])
	check(inc0 >= 1.0 and g._incoming(P, "creds") < 0.001, "...and the bank room they held for cargo")
	check(led("lost:cargo:intel") >= g.WORKER_CARRY - 0.001 and worker_ids().size() < n_workers,
		"The lost cargo is recorded (%s Intel) and the workers are gone (%d of %d left)" % [g._amt(led("lost:cargo:intel")), worker_ids().size(), n_workers])
	step(6.0)
	check(worker_ids().size() == n_workers, "Their surviving station replaces them after 5 s")
	check(g._held(P, "patch") == 0, "A lost card is not refunded")


func no_foreign_transit() -> void:
	fresh()
	var home: int = int(g.rig[P])
	var pair := far_pair()
	var via: int = pair[0]; var far: int = pair[1]
	var beyond := -1
	for nb in g.hosts[far].links:
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL and not g.hosts[via].links.has(n) and not g.hosts[home].links.has(n): beyond = n; break
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1
	g.cards[P] = {"breach": 1, "patch": 1}
	g._mark_scanned(P, beyond)
	check(g._can_play(P, "patch", far) != "" and g._can_play(P, "breach", beyond) != "", "A neutral host is no relay: nothing reaches past it")
	g._capture(via, R)
	check(g._travel_route(P, home, far).is_empty() and g._attack_route(P, beyond).is_empty(), "A rival's host is no relay either")
	check(g._attack_route(P, via) == [home, via] or g._attack_route(P, via).size() == 2, "...but it can be the end of an attack")


func full_destinations() -> void:
	fresh()
	var pair := far_pair()
	var far: int = pair[1]
	g._set_builds(far, ["intel", "intel", "cash"])
	g.bank[P].intel = g._cap(P, "intel")   # the bank has no room for Intel
	var over := false
	for k in 30 * 30:
		g._sim_step(g.SIM_DT)
		if g._store_total(far) + g._inbound_total(far) > g.STORE_CAP + 0.001: over = true
		if g._avail(P, "intel") > g._cap(P, "intel") + 0.001: over = true
	check(not over, "Storage plus what is on its way never exceeds the host's room; the bank never exceeds its cap")
	check(led("from:%d:intel" % far) == 0.0 and led("lost:cap:intel") < 0.001 + led("lost:cap:intel"), "No Intel is fetched for a full bank")
	g._set_builds(far, ["wall"])   # its Firewall needs its upkeep Intel brought (0.6.12: the one input left), and the bank has it...
	g.hosts[far].store = {P: {"creds": g.STORE_CAP}}   # ...but its storage is full of Credentials the full bank cannot take
	g.bank[P].creds = g._cap(P, "creds")
	var sent0 := led("out:supply:intel")
	step(3.0)
	check(led("out:supply:intel") == sent0 and g._free(P, "intel") >= upkeep_of(far) and float(g.hosts[far].store.get(P, {}).get("intel", 0.0)) < 0.001,
		"No supply is sent to a host with no room for it: its Firewall's %s Intel stays in the bank" % g._amt(upkeep_of(far)))
	check(str(g._host_diag(far).lines).contains("full"), "...and the host says why: its storage and the bank for what it holds are full")


func held_at_a_rival_pickup() -> void:   # your worker collecting on a rival's host waits there when its way home is cut for a moment
	fresh()
	var hub: int = int(g.rig[P])
	var a := -1; var x := -1
	for nb in g.hosts[hub].links:
		for nb2 in g.hosts[int(nb)].links:
			if int(nb2) != hub and not g.hosts[hub].links.has(int(nb2)) and int(g.hosts[int(nb2)].owner) == g.NEUTRAL: a = int(nb); x = int(nb2); break
		if a >= 0: break
	if x < 0: check(false, "a rival host two hops from the main node"); return
	g._capture(a, P); g.hosts[a].slots = 3; g._set_builds(a, [])
	g._capture(x, R); g._set_builds(x, [])
	g._add_to(x, "loot", P, "intel", 2.0)   # stolen goods waiting for your workers there
	var f := {}
	for k in 300:
		g._sim_step(g.SIM_DT)
		for ff in g.flights:
			if str(ff.kind) == "courier" and int(ff.owner) == P and int(ff.dest) == x and int(ff.get("hop_i", 0)) == (ff.route as Array).size() - 1: f = ff; break
		if not f.is_empty(): break
	if f.is_empty(): check(false, "a worker on its way to collect at the rival's host"); return
	g.hosts[x].cover_until = g._t + 30.0; g.hosts[x].express_until = g._t + 30.0   # the rival's own Cargo cover and Express there
	g.hosts[a].ddos_until = g._t + 3.0   # your relay home goes down for 3 s just as it picks up
	var wid := int(f.wid)
	var fid0 := int(f.id)
	for k in 30:   # (0.6.16) the empty "fetch" leg ends at the pickup; the loaded leg home is a new packet: follow the worker
		g._sim_step(g.SIM_DT)
		f = g._flight_of(wid)
		if not f.is_empty() and int(f.id) != fid0: break
	check(not f.is_empty() and str(f.trip) == "carry" and int(f.get("src", -1)) == x and float((f.cargo as Dictionary).get("intel", 0.0)) > 0.0
		and not bool(f.get("covered", false)) and not bool(f.get("express", false)),
		"Leaving a rival's host, your worker gets nothing from the rival's Cargo cover or Express there")
	step(1.0)
	f = g._flight_of(wid)
	check(g.workers.has(wid) and not f.is_empty() and bool(f.get("blocked", false)) and int(f.get("at", -1)) == x and float((f.cargo as Dictionary).get("intel", 0.0)) > 0.0,
		"With the way home cut it waits where it collected, with its cargo (not lost)")
	var before := float(g._ledger_sums(P).get("in:stolen:intel", 0.0))
	step(10.0)
	check(g.workers.has(wid) and float(g._ledger_sums(P).get("in:stolen:intel", 0.0)) > before, "When the relay is back it brings the stolen cargo home")


func delivered_then_surplus() -> void:   # (0.6.16) a worker is free where it delivers: after the upkeep it takes that host's Crypto home from there
	fresh()
	var hub: int = int(g.rig[P])
	var pair := far_pair()
	var far: int = pair[1]
	g._set_builds(far, ["cash", "wall"])   # a Miner and a Firewall: no Intel made there
	var ids := worker_ids()
	var want: float = upkeep_of(far) * g.UPKEEP_KEEP   # it keeps UPKEEP_KEEP cycles of upkeep within reach
	var crypto: float = ids.size() * g.WORKER_CARRY    # a unit of Crypto waiting there for each worker
	g.hosts[far].store = {P: {"cash": crypto}}
	g.hosts[far].cyc = g.PROD_CYCLE   # (its next cycle is a whole cycle away: nothing is made or eaten meanwhile)
	watch_reset()
	watch(2.0 * g._leg_time(P, hub, far) + 1.0)
	var first_ok := true; var second_ok := true; var empty := 0
	for wid in ids:
		var ls: Array = legs.get(wid, [])
		first_ok = first_ok and ls.size() >= 1 and str(ls[0].trip) == "carry" and int(ls[0].to) == far and str(ls[0].purpose) == "upkeep" and float(ls[0].cargo.get("intel", 0.0)) > 0.0
		second_ok = second_ok and ls.size() >= 2 and str(ls[1].trip) == "carry" and int(ls[1].from) == far and int(ls[1].to) == hub and float(ls[1].cargo.get("cash", 0.0)) > 0.0
		for l in ls:
			if (l.cargo as Dictionary).is_empty(): empty += 1
	check(want >= ids.size() * g.WORKER_CARRY - 0.001 and first_ok,
		"Upkeep first: all %d main-node workers carry the Firewall's Intel out (%s, %s cycles' worth); none sets off for the Crypto waiting there" % [ids.size(), g._amt(want), g._amt(g.UPKEEP_KEEP)])
	check(second_ok, "Each is free where it delivered and takes a unit of that host's Crypto home from there, loaded from the moment it leaves")
	check(empty == 0 and teleports().is_empty(), "No empty leg and no stop at the main node in between: every leg starts where the last one ended (%s)" % str(teleports()))
	check(absf(led("from:%d:cash" % far) - crypto) < 0.001 and absf(float(g._store_of(far, P).get("intel", 0.0)) - want) < 0.001 and resv_err == "",
		"The %s Crypto reaches the bank, the host holds its %s Intel, and nothing stays reserved (%s)" % [g._amt(led("from:%d:cash" % far)), g._amt(float(g._store_of(far, P).get("intel", 0.0))), resv_err])


func direct_to_site() -> void:   # (0.6.16) a site's material comes from the nearest place that can spare it, straight to the site; building strictly first
	fresh()
	var hub: int = int(g.rig[P])
	var r := ring()
	if r.is_empty(): check(false, "two hosts in a row from the main node, and one of yours beside it"); return
	var a: int = r[0]; var b: int = r[1]; var e: int = r[2]
	own(a, ["intel", "intel", "intel"]); own(b, []); own(e, ["cash", "cash", "cash"])
	var bill: float = float(g.BUILD_COSTS.intel.intel)   # an Intel harvester for b: an Intel-only bill
	var own_part: float = bill - g.STORE_CAP
	g.hosts[a].store = {P: {"intel": g.STORE_CAP}}   # a's harvesters have filled its storage: every unit is spare
	g.hosts[b].store = {P: {"intel": own_part}}      # what the site holds goes into its project first: a has exactly the rest
	g.hosts[e].store = {P: {"cash": g.STORE_CAP}}    # e is full and its Miners have stopped: its Crypto is the most urgent surplus
	var via_a: float = g._leg_time(P, hub, a) + g._leg_time(P, a, b)
	var shuttle: float = g._leg_time(P, b, a) + g._leg_time(P, a, b)
	check(own_part > 0.0 and not (g._travel_route(P, a, b) as Array).has(hub) and via_a < g._leg_time(P, hub, b) and shuttle < 2.0 * g._leg_time(P, hub, b)
		and g._free(P, "intel") >= bill and g._tight_now(e),
		"Setup: the bank holds the Intel too, but %s's spare stock gets a unit to the site sooner (%.2f s from the main node, %.2f s from the site, vs %.2f s and %.2f s); %s is full"
		% [str(g.hosts[a].name), via_a, shuttle, g._leg_time(P, hub, b), 2.0 * g._leg_time(P, hub, b), str(g.hosts[e].name)])
	g._start_job(b, "intel", 0)
	var job: Dictionary = g.hosts[b].jobs[0]
	var n_w := worker_ids().size()
	var rounds := ceili(g.STORE_CAP / (n_w * g.WORKER_CARRY))
	var expect: float = via_a + (rounds - 1) * shuttle   # first unit from the main node through a, then the site <-> a shuttle
	var slack: float = 2.0 * rounds * 2.0 * g.SIM_DT     # (each leg may wait up to two steps: its arrival and its departure fall on steps)
	watch_reset()
	var t0: float = g._t
	var covered := -1.0; var funded := -1.0; var export_short := 0; var first_export := -1; var e_waited := false; var bank_used := -1.0
	for k in int(round(2.0 * (expect + slack) / g.SIM_DT)):   # (0.6.18: a timeout that scales with the bill; it ends as soon as both are seen)
		watch(g.SIM_DT)
		var short: float = g._job_short(job, "intel") if (g.hosts[b].jobs as Dictionary).has(0) else 0.0
		for wid in legs:
			var l: Dictionary = legs[wid][legs[wid].size() - 1]
			if absf(float(l.t) - g._t) > 0.0001 or str(l.trip) == "home": continue
			if int((l.job as Dictionary).get("dst", -1)) != hub and not (str(l.trip) == "carry" and int(l.to) == hub): continue
			if covered < 0.0: export_short += 1   # surplus on its way to the bank while the site still lacked a unit
			elif first_export < 0: first_export = int((l.job as Dictionary).get("src", l.from))
		if covered < 0.0 and short <= 0.0001:
			covered = g._t
			e_waited = g._store_total(e) >= g.STORE_CAP - 0.001 and led("from:%d:cash" % e) < 0.001
			bank_used = led("out:supply:intel")
		if funded < 0.0 and (not (g.hosts[b].jobs as Dictionary).has(0) or g._job_funded(job)): funded = g._t
		if funded >= 0.0 and first_export >= 0: break
	var into_b := 0; var straight := 0; var carried := 0.0; var via_hub := 0
	for wid in legs:
		var ls: Array = legs[wid]
		for k in ls.size():
			var l: Dictionary = ls[k]
			if covered >= 0.0 and float(l.t) <= covered + 0.0001 and k > 0 and (l.route as Array).has(hub): via_hub += 1
			if str(l.trip) != "carry" or int(l.to) != b: continue
			into_b += 1; carried += float(l.cargo.get("intel", 0.0))
			if int(l.from) == a and l.route == [a, b]: straight += 1
	check(into_b >= 1 and straight == into_b and absf(carried - g.STORE_CAP) < 0.001 and bank_used == 0.0,
		"Every unit the site lacked came from %s's spare stock straight to the site (%d of %d legs on the one link %d -> %d, %s Intel); none from the bank, none via the main node"
		% [str(g.hosts[a].name), straight, into_b, a, b, g._amt(carried)])
	check(via_hub == 0 and teleports().is_empty(),
		"A worker that delivers is free at the site and fetches its next unit from there: after its first leg, no leg touched the main node until the bill was covered (%d did)" % via_hub)
	check(covered >= 0.0 and export_short == 0 and e_waited,
		"Building strictly first: no surplus set off for the bank while the site lacked a unit, not even the full host's (%d did)" % export_short)
	check(first_export == e, "Once the bill was all at the site or on its way, the first surplus collected was the full host's (%d, expected %d)" % [first_export, e])
	check(funded >= 0.0 and funded - t0 <= expect + slack,
		"The bill is at the site after %.2f s: %d workers shuttling the %d s link, %d rounds (at most %.2f s)" % [funded - t0, n_w, int(g._leg_time(P, a, b)), rounds, expect + slack])
	check(funded >= 0.0 and absf(float(job.escrow.get("intel", 0.0)) - bill) < 0.001 and resv_err == "",
		"Nothing lost or counted twice: the escrow holds the whole %s Intel bill (%s), every reservation matched the workers on the road (%s)"
		% [g._amt(bill), g._amt(float(job.escrow.get("intel", 0.0))), resv_err])


func no_overbooking() -> void:   # (0.6.16) no more workers are sent to a host than it has units to give, however many are free
	fresh()
	var hub: int = int(g.rig[P])
	g._set_builds(hub, ["bot", "bot", "bot"])   # three Bot stations: six workers at the main node
	var ids := worker_ids()
	var r := ring()
	if r.is_empty(): check(false, "a host of yours beside the main node"); return
	var e: int = r[2]
	own(e, ["cash", "cash", "wall"])
	var keep: float = upkeep_of(e) * g.UPKEEP_KEEP   # the Intel its Firewall keeps within reach (it makes none): never spare
	var spare: float = (ids.size() - 1) * g.WORKER_CARRY   # one unit fewer than there are workers
	# (0.6.18) About to fill up: the room left is just its next cycle plus the upkeep coming in, a unit short of what
	# _tight_now wants free (as when its Intel and Crypto filled the 10-unit store). What a bigger STORE_CAP holds beyond
	# them is Credentials that cannot go home, the bank having no room for them: the host still has only its Crypto to give.
	var stuck: float = maxf(0.0, g.STORE_CAP - (g._cycle_gross(e) + upkeep_of(e)) - keep - spare)
	g.hosts[e].store = {P: {"intel": keep, "cash": spare, "creds": stuck}}
	g.bank[P].creds = g._cap(P, "creds")
	g.hosts[e].cyc = g.PROD_CYCLE   # (no cycle meanwhile)
	check(ids.size() == 3 * g.WORKERS_PER_STATION and g._tight_now(e) and g._store_room(e) >= 1.0 + g._cycle_gross(e)
		and absf(g._spare_total(e, P) - spare - stuck) < 0.001 and g._room(P, "creds") < g.WORKER_CARRY,
		"Setup: %d free workers at the main node; a host about to fill up (counting the room its Firewall's incoming upkeep needs) with %s spare Crypto (its %s Intel is its Firewall's%s)"
		% [ids.size(), g._amt(spare), g._amt(keep), ("; its %s Credentials wait for room in the full bank" % g._amt(stuck)) if stuck > 0.0 else ""])
	watch_reset()
	watch(g.SIM_DT)   # one dispatch
	var sent := 0
	for wid in legs:
		for l in legs[wid]:
			if str(l.trip) == "fetch" and int((l.job as Dictionary).get("src", -1)) == e: sent += 1
	var free := 0
	for wid in ids:
		if str(g.workers[wid].state) == "idle": free += 1
	check(sent == roundi(spare / g.WORKER_CARRY) and absf(g._claimed(e, P, "cash") - spare) < 0.001 and g._claimed(e, P, "intel") < 0.001 and free == ids.size() - sent,
		"%d free workers, %s spare units: exactly %d go, one per unit (%s claimed), the Firewall's Intel is not touched, %d stays free"
		% [ids.size(), g._amt(spare), sent, g._amt(g._claimed(e, P, "cash")), free])
	check(not g._tight_now(e), "With its units claimed the host is no longer about to fill up: nobody else is sent for them")
	watch(2.0 * g._leg_time(P, hub, e) + 1.0)
	var carried := 0; var empty := 0
	for wid in legs:
		for l in legs[wid]:
			if str(l.trip) == "carry" and int(l.from) == e: carried += 1
			if str(l.trip) == "home": empty += 1
	check(carried == sent and empty == 0 and absf(led("from:%d:cash" % e) - spare) < 0.001 and float(g._store_of(e, P).get("cash", 0.0)) < 0.001
		and absf(float(g._store_of(e, P).get("intel", 0.0)) - keep) < 0.001,
		"Every worker sent comes back loaded: %s Crypto reaches the bank, nobody arrives to find nothing, the Firewall keeps its %s Intel"
		% [g._amt(led("from:%d:cash" % e)), g._amt(float(g._store_of(e, P).get("intel", 0.0)))])
	check(resv_err == "" and g._claims_total(e) < 0.001 and g._inbound_total(e) < 0.001, "...and no claim or held room is left behind (%s)" % resv_err)


func busy_network() -> void:   # (0.6.16) a working network for 90 s: nobody free while a job waits, every reservation matches the road
	fresh()
	var hub: int = int(g.rig[P])
	var r := ring()
	if r.is_empty(): check(false, "two hosts in a row from the main node, and one of yours beside it"); return
	var a: int = r[0]; var b: int = r[1]; var e: int = r[2]
	var c := -1   # another neutral host beside the main node: a second Bot station
	for nb in g.hosts[hub].links:
		if int(nb) != a and int(g.hosts[int(nb)].owner) == g.NEUTRAL: c = int(nb); break
	if c < 0: check(false, "a third host beside the main node"); return
	own(a, ["intel", "intel", "intel"])   # Intel to spare every cycle
	own(e, ["cash", "cash", "wall"])      # Crypto to spare, and a Firewall whose upkeep is brought
	own(c, ["bot", "cred", ""])           # two more workers, starting there; Credentials to spare
	own(b, [])
	g._start_job(b, "lab", 0); g._start_job(b, "cash", 1)   # two projects at a site with no station
	var bill := 0.0   # (0.6.18) long enough to bring both bills, whatever they are: every unit from the bank (the slowest source)
	for kind in ["lab", "cash"]:   # with every worker on it, then the work, and a cycle for the Firewall's upkeep runs between
		for res in g.BUILD_COSTS[kind]: bill += float(g.BUILD_COSTS[kind][res])
	var n_w := worker_ids().size()
	var secs: float = ceilf(bill / (n_w * g.WORKER_CARRY)) * 2.0 * g._leg_time(P, hub, b) + g.BUILD_TIME + g.PROD_CYCLE
	watch_reset()
	watch(secs, e)
	var limit: float = g.LOGI_EVERY + 2.0 * g.SIM_DT   # (a free worker is dealt a job the step something changes, or at the next planning pass)
	check(idle_worst <= limit,
		"Over %.0f s no worker stayed free more than %.2f s while a job it could take waited (longest %.2f s; %.1f worker-s free with a job waiting, %.0f%% of all worker time on the road)"
		% [secs, limit, idle_worst, idle_time, 100.0 * busy_time / maxf(0.001, busy_time + free_time)])
	check(home_with_work == 0, "No worker set off home empty while a job was waiting (%d of %d legs home)" % [home_with_work, home_legs])
	check(resv_err == "", "At every step each claim, each room held at a host or a site and each held bank room matched the workers on the road (%s)" % resv_err)
	check(teleports().is_empty(), "Every leg started where the worker's previous leg ended: free where it delivers (%s)" % str(teleports().slice(0, 3)))
	var during := "%d of %d" % [fed, cycles]   # (0.6.20) building goes first: the Firewall may wait while the bills go out
	watch_reset()
	watch(3.0 * g.PROD_CYCLE + 2.0 * g._leg_time(P, hub, e), e)
	check(g._build_owed(P).is_empty() and cycles >= 3 and fed == cycles,
		"Once both bills are out (building first: fed in %s cycles meanwhile), the Firewall eats its upkeep in each of its next %d cycles (%d)" % [during, cycles, fed])
	check((g.hosts[b].builds as Array).has("lab") and (g.hosts[b].builds as Array).has("cash") and (g.hosts[b].jobs as Dictionary).is_empty(),
		"Both projects at the site (%s units) were supplied and built (%s)" % [g._amt(bill), str(g.hosts[b].builds)])


func room_for_upkeep() -> void:   # (0.6.16) a Firewall whose host's storage is full: its surplus goes first, as urgently as upkeep, then the upkeep
	fresh()
	var hub: int = int(g.rig[P])
	var r := ring()
	if r.is_empty(): check(false, "two hosts beside the main node"); return
	var a: int = r[0]; var e: int = r[2]
	own(e, ["cash", "cash", "wall"])   # full of Crypto, a Firewall, no Intel: there is no room for its upkeep
	g.hosts[e].store = {P: {"cash": g.STORE_CAP}}
	var leg: float = g._leg_time(P, hub, e)
	g.hosts[e].cyc = 3.0 * leg + 1.0   # (time for a unit out to make room, then the upkeep in, with a second to spare)
	watch_reset()
	watch(g.SIM_DT)
	var room_legs := 0
	for wid in legs:
		for l in legs[wid]:
			if str(l.trip) == "fetch" and int((l.job as Dictionary).get("src", -1)) == e: room_legs += 1
	check(g._store_room(e) < g.WORKER_CARRY and room_legs >= 1, "A full host's Firewall needs room for its upkeep: its surplus goes first (%d workers sent for it)" % room_legs)
	watch(3.0 * leg + 2.0, e)
	check(cycles == 1 and fed == 1 and resv_err == "", "...then its upkeep arrives and the Firewall eats it in its cycle (%d of %d)" % [fed, cycles])
	# GAME BUG check: one unit of room is enough for one cycle's upkeep, but the "room" demand is never used up in a dispatch pass,
	# so every free worker is sent to make room while another Firewall's upkeep waits and goes off.
	fresh()
	r = ring(); a = r[0]; e = r[2]
	own(e, ["cash", "cash", "wall"])
	g.hosts[e].store = {P: {"cash": g.STORE_CAP}}
	g.hosts[e].cyc = g.PROD_CYCLE
	own(a, ["cash", "wall"])           # a second Firewall, its Intel all eaten, its cycle 2 s away and 1 s from the main node
	g.hosts[a].store = {P: {}}
	var leg_a: float = g._leg_time(P, hub, a)
	g.hosts[a].cyc = leg_a + 1.0
	var n_w := worker_ids().size()
	watch_reset()
	watch(g.SIM_DT)
	room_legs = 0
	var up_legs := 0
	for wid in legs:
		for l in legs[wid]:
			if str(l.trip) == "fetch" and int((l.job as Dictionary).get("src", -1)) == e: room_legs += 1
			if int(l.to) == a and str(l.purpose) == "upkeep": up_legs += 1
	check(n_w >= 2 and up_legs >= 1,
		"Two Firewalls short, one at a full host, %d free workers: making room at the full host (%s unit is room for a cycle's upkeep) does not take them all, a free one carries the other Firewall's upkeep at once (room legs %d, upkeep legs %d)"
		% [n_w, g._amt(minf(g.WORKER_CARRY, upkeep_of(e))), room_legs, up_legs])
	var cyc := {a: 0, e: 0}; var ok := {a: 0, e: 0}
	for k in int(round((g.PROD_CYCLE + 1.0) / g.SIM_DT)):   # (until both have run a cycle)
		var left := {a: float(g.hosts[a].cyc), e: float(g.hosts[e].cyc)}
		g._sim_step(g.SIM_DT)
		for i in [a, e]:
			if float(g.hosts[i].cyc) > float(left[i]):
				cyc[i] = int(cyc[i]) + 1
				if bool(g.hosts[i].fw_on): ok[i] = int(ok[i]) + 1
	check(int(cyc[a]) >= 1 and ok[a] == cyc[a],
		"...so the other Firewall, %.0f s from the main node with its cycle %.0f s away and a worker free, stays on (fed %d of %d cycles)" % [leg_a, leg_a + 1.0, int(ok[a]), int(cyc[a])])
	check(int(cyc[e]) >= 1 and ok[e] == cyc[e], "...and the full host's Firewall gets its room and its upkeep in time too (fed %d of %d)" % [int(ok[e]), int(cyc[e])])


func main_node_lack() -> void:   # (0.6.16) what a main-node project waits for that is not in the bank is brought home as building, before any surplus
	fresh()
	var hub: int = int(g.rig[P])
	var r := ring()
	if r.is_empty(): check(false, "two hosts beside the main node"); return
	var a: int = r[0]; var e: int = r[2]
	own(a, ["cash", "cash", "cash"]); own(e, ["cred", "cred", "cred"])
	var spare: float = 4.0 * g.WORKER_CARRY
	g.hosts[a].store = {P: {"cash": spare}}         # Crypto to spare (not about to fill up)
	g.hosts[e].store = {P: {"creds": g.STORE_CAP}}   # full: the most urgent surplus
	g.bank[P].cash = 0.0                             # no Crypto in the bank for the project
	g._start_job(hub, "lab", 2)
	var lack: Dictionary = g._build_lack(P, g._build_owed(P, true))
	check(float(lack.get("cash", 0.0)) > spare and not g._tight_now(a) and g._tight_now(e),
		"Setup: a main-node project lacks %s Crypto the bank does not have; one host has %s to spare, another is full" % [g._amt(float(lack.get("cash", 0.0))), g._amt(spare)])
	watch_reset()
	var bad := 0; var first := -1
	for k in int(round(8.0 / g.SIM_DT)):
		watch(g.SIM_DT)
		var lk: float = float(g._build_lack(P, g._build_owed(P, true)).get("cash", 0.0))
		for wid in legs:
			var ls: Array = legs[wid]
			var l: Dictionary = ls[ls.size() - 1]
			if absf(float(l.t) - g._t) > 0.0001 or str(l.trip) == "home": continue
			# (0.6.18) the loaded leg on from a pickup is the second half of the job its "fetch" leg started: its source was
			# chosen then. A cycle at the other host while the worker was on its way does not make that choice too early.
			var prev: Dictionary = ls[ls.size() - 2] if ls.size() >= 2 else {}
			if (str(l.trip) == "carry" and not prev.is_empty() and str(prev.trip) == "fetch" and int(prev.to) == int(l.from)
				and int((prev.job as Dictionary).get("src", -1)) == int(l.from) and (l.cargo as Dictionary).has(str((prev.job as Dictionary).get("res", "")))): continue
			var src := int((l.job as Dictionary).get("src", l.from))
			if first < 0: first = src
			if src == e and lk > 0.0001 and g._store_free(a, P, "cash") >= 1.0: bad += 1
	check(first == a and bad == 0, "Brought home as building: the workers fetch the Crypto from the host that has it, and the full host's surplus waits while any is left (first from %d, %d surplus jobs started too early)" % [first, bad])
	check(led("from:%d:cash" % a) >= spare - 0.001 and led("from:%d:creds" % e) >= 1.0 and resv_err == "" and teleports().is_empty(),
		"...all %s of it reaches the bank, then the full host is relieved (%s Credentials so far)" % [g._amt(led("from:%d:cash" % a)), g._amt(led("from:%d:creds" % e))])


func upkeep_from_host() -> void:   # (0.6.16) a Firewall's upkeep comes straight from the nearest host with spare Intel, not from the bank
	fresh()
	var hub: int = int(g.rig[P])
	var pair := far_pair()
	var via: int = pair[0]; var far: int = pair[1]
	g.hosts[via].type = "pc"; g.hosts[via].slots = 3
	g._set_builds(via, ["intel", "intel"])
	g._set_builds(far, ["cash", "wall"])
	var want: float = upkeep_of(far) * g.UPKEEP_KEEP
	g.hosts[via].store = {P: {"intel": want}}   # exactly the upkeep the far host keeps within reach, spare at the relay
	g.hosts[via].cyc = g.PROD_CYCLE; g.hosts[far].cyc = g.PROD_CYCLE   # (no cycle meanwhile)
	var through: float = g._leg_time(P, hub, via) + g._leg_time(P, via, far)
	check(through < g._leg_time(P, hub, far) and (g._travel_route(P, via, far) as Array) == [via, far],
		"Setup: through the relay's spare Intel the upkeep is there sooner (%.2f s) than from the bank (%.2f s)" % [through, g._leg_time(P, hub, far)])
	watch_reset()
	watch(through + 0.5)
	var straight := 0.0
	for wid in legs:
		for l in legs[wid]:
			if str(l.trip) == "carry" and int(l.from) == via and int(l.to) == far and str(l.purpose) == "upkeep": straight += float(l.cargo.get("intel", 0.0))
	check(absf(straight - want) < 0.001 and led("out:supply:intel") < 0.001 and led("from:%d:intel" % via) < 0.001 and absf(float(g._store_of(far, P).get("intel", 0.0)) - want) < 0.001,
		"The Firewall's %s Intel came straight from the relay's spare stock to its host (%s carried on the one link), none from the bank, none via the main node" % [g._amt(want), g._amt(straight)])
	check(resv_err == "" and g._claims_total(via) < 0.001 and g._inbound_total(far) < 0.001, "...and nothing stays claimed or held (%s)" % resv_err)


func salvage_to_site() -> void:   # (0.6.16) a cancelled site's materials stay there as salvage, and go straight to the next site that needs them
	fresh()
	var hub: int = int(g.rig[P])
	var r := ring()
	if r.is_empty(): check(false, "two hosts in a row from the main node, and one of yours beside it"); return
	var a: int = r[0]; var b: int = r[1]; var e: int = r[2]
	own(a, []); own(b, []); own(e, [])
	g._start_job(b, "wall", 0)
	watch_reset()
	watch(2.0 * g._leg_time(P, hub, b) + 0.5)   # the first units are at the site, more are on their way
	var job: Dictionary = g.hosts[b].jobs[0]
	var at_site: float = float(job.escrow.get("intel", 0.0))
	var total0: float = g._avail(P, "intel") + at_site + in_flight("intel")
	var made0: float = led("in:trickle:intel") + led("in:production:intel")
	g._do_cancel_job(P, b, 0)
	check(at_site >= 1.0 and absf(g._loot(b, P, "intel") - at_site) < 0.001, "A project cancelled before its work leaves what was delivered at its site as salvage (%s Intel)" % g._amt(at_site))
	g._start_job(e, "wall", 0)
	watch(12.0)
	var b_to_e := 0.0
	for wid in legs:
		for l in legs[wid]:
			if str(l.trip) == "carry" and int(l.from) == b and int(l.to) == e: b_to_e += float(l.cargo.get("intel", 0.0))
	var made: float = led("in:trickle:intel") + led("in:production:intel") - made0
	var ej: Dictionary = g.hosts[e].jobs.get(0, {})
	var total1: float = g._avail(P, "intel") + g._loot(b, P, "intel") + float((ej.get("escrow", {}) as Dictionary).get("intel", 0.0)) + in_flight("intel")
	check(b_to_e >= 1.0, "Your salvage is a source too: it goes straight from the old site to the new one (%s Intel), not via the bank" % g._amt(b_to_e))
	check(absf(total1 - (total0 + made)) < 0.01 and resv_err == "",
		"Nothing lost or counted twice: bank + salvage + the new site + on the way = before + the main node's own income (%.2f vs %.2f) (%s)" % [total1, total0 + made, resv_err])


func ddos_pickup() -> void:   # a host under DDoS cannot send: a worker that reaches its pickup there waits with the unit until the DDoS ends
	fresh()
	var hub: int = int(g.rig[P])
	var pair := far_pair()
	var far: int = pair[1]
	g._set_builds(far, ["cash"])
	g.hosts[far].store = {P: {"cash": 2.0 * g.WORKER_CARRY}}
	g.hosts[far].cyc = g.PROD_CYCLE
	watch_reset()
	watch(g.SIM_DT)   # the workers set off to collect
	var wid := -1
	for w in legs:
		if str(legs[w][0].trip) == "fetch" and int((legs[w][0].job as Dictionary).get("src", -1)) == far: wid = int(w)
	if wid < 0: check(false, "a worker on its way to collect"); return
	var trip: float = g._leg_time(P, hub, far)
	var until: float = g._t + trip + 2.0   # the host goes down before they get there and stays down 2 s after
	g.hosts[far].ddos_until = until
	var left_at := -1.0
	while g._t < until - g.SIM_DT:
		watch(g.SIM_DT)
		var f: Dictionary = g._flight_of(wid)
		if left_at < 0.0 and not f.is_empty() and str(f.trip) == "carry" and int(f.route[0]) == far and int(f.get("hop_i", 0)) >= 1 and not bool(f.get("blocked", false)): left_at = g._t
	check(left_at < 0.0, "A worker that reaches its pickup on a host under DDoS waits there with the unit: the host cannot send until %.2f s (it left at %.2f s)" % [until, left_at])
	watch(trip + 1.0)
	check(led("from:%d:cash" % far) >= 2.0 * g.WORKER_CARRY - 0.001 and resv_err == "", "...then it brings the unit home (%s Crypto) (%s)" % [g._amt(led("from:%d:cash" % far)), resv_err])
