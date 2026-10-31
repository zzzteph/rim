extends SceneTree
## Logistics: delivery workers are reusable and belong to a host; a remote host is supplied from the main node
## automatically (0.6.12: its Firewall's upkeep, the one input left), uses only what arrived, and its output rides back; every material is
## conserved across the round trip; defence cards travel and load a socket only on arrival (no overbooking); every
## kind of packet is held at a cut relay, goes on when it reopens, is lost only with a host it is in; nothing ever
## crosses a rival's or a neutral host; destinations never overfill.
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


func in_flight(res: String) -> float:   # units of res riding P's couriers right now
	var n := 0.0
	for f in g.flights:
		if str(f.kind) == "courier" and int(f.owner) == P: n += float((f.cargo as Dictionary).get(res, 0.0))
	return n


func worker_ids() -> Array:
	var out := []
	for wid in g.workers:
		if int(g.workers[wid].fac) == P: out.append(int(wid))
	out.sort()
	return out


var cycles := 0   # production cycles the watched host ran during step_watch
var fed := 0      # ...of them in which its Firewalls were fed (on after the cycle: each ate its upkeep)


func step_watch(secs: float, i: int) -> void:   # step(), counting host i's production cycles and those its Firewalls ate their upkeep in
	for k in int(round(secs / g.SIM_DT)):
		var left := float(g.hosts[i].get("cyc", g.PROD_CYCLE))
		g._sim_step(g.SIM_DT)
		if float(g.hosts[i].get("cyc", g.PROD_CYCLE)) > left:   # its timer wrapped: the host ran a cycle
			cycles += 1
			if bool(g.hosts[i].fw_on): fed += 1


func upkeep_of(i: int) -> float: return float(g.BUILD_KINDS.wall.use.intel) * g._count_all(i, "wall")   # Intel host i's Firewalls eat per cycle


func run() -> void:
	supply_round_trip()
	firewall_sockets()
	relays()
	no_foreign_transit()
	full_destinations()
	held_at_a_rival_pickup()
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
	cycles = 0; fed = 0
	step_watch(1.0, far)
	var upkeep_out := false   # a main-node courier on its way to the host with the Firewall's Intel, as an upkeep delivery
	for f in g.flights:
		if str(f.kind) == "courier" and int(f.owner) == P and int(f.dest) == far and str(f.get("purpose", "")) == "upkeep":
			upkeep_out = upkeep_out or float((f.cargo as Dictionary).get("intel", 0.0)) >= need - 0.001
	check(upkeep_out and in_flight("intel") >= need - 0.001 and g._inbound(far, "intel") >= need - 0.001,
		"The main node's workers set off with the Firewall's %s Intel on their own; the host's room for it is held" % g._amt(need))
	check(float(g.hosts[far].store.get(P, {}).get("intel", 0.0)) < 0.001, "Nothing is there before it arrives: the Firewall uses only what has arrived")
	step_watch(24.0, far)
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
	for k in 180 * 30:
		g._sim_step(g.SIM_DT)
		if not g.hosts[far].jobs.has(1): break
	var bill := 0.0
	for r in g.BUILD_COSTS.wall: bill += float(g.BUILD_COSTS.wall[r])
	check(g._sockets(far) == g.FIREWALL_SOCKETS, "Once its %d units have arrived (two hops, two main-node workers) and it is built, it has its %d (%.0f s)" % [int(bill), g.FIREWALL_SOCKETS, g._t - t0])
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
	g.hosts[far].store = {P: {"creds": 2.0}}
	g._play_card(P, "patch", far)   # (it holds a socket of the Firewall on its way)
	g._tick_logistics()   # main-node workers: Intel out for the Firewall's upkeep, Credentials claimed for the way back
	var held0 := [g._socket_res(far), g._inbound(far, "intel"), g._claimed(far, P, "creds")]   # what they hold at the far host
	var inc0: float = g._incoming(P, "creds")
	var n_workers := worker_ids().size()
	var n0: int = g.flights.size()
	for f in g.flights: g._block(f, via)   # all of them wait inside the relay
	g._capture(via, R)
	g._tick_blocked()
	check(n0 >= 3 and g.flights.is_empty(), "Packets held in a relay that is taken are lost with it (%d)" % n0)
	check(int(held0[0]) >= 1 and float(held0[1]) >= need - 0.001 and float(held0[2]) >= 1.0
		and g._socket_res(far) == 0 and g._inbound(far, "intel") < 0.001 and g._claimed(far, P, "creds") < 0.001,
		"Their reservations at the far host are released: the held socket (%d), the room for the upkeep (%s), the claimed pickup (%s)" % [int(held0[0]), g._amt(float(held0[1])), g._amt(float(held0[2]))])
	check(inc0 >= 1.0 and g._incoming(P, "creds") < 0.001, "...and the bank room they held for cargo")
	check(led("lost:cargo:intel") >= need - 0.001 and worker_ids().size() < n_workers,
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
	for k in 30:
		g._sim_step(g.SIM_DT)
		if str(f.trip) == "back": break
	check(str(f.trip) == "back" and not bool(f.get("covered", false)) and not bool(f.get("express", false)),
		"Leaving a rival's host, your worker gets nothing from the rival's Cargo cover or Express there")
	step(1.0)
	check(g.workers.has(wid) and bool(f.get("blocked", false)) and int(f.at) == x, "With the way home cut it waits where it collected, with its cargo (not lost)")
	var before := float(g._ledger_sums(P).get("in:stolen:intel", 0.0))
	step(10.0)
	check(g.workers.has(wid) and float(g._ledger_sums(P).get("in:stolen:intel", 0.0)) > before, "When the relay is back it brings the stolen cargo home")
