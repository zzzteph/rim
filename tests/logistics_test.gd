extends SceneTree
## Logistics (feedback round B, section 7): couriers are reusable and belong to a host; a remote host can be supplied
## from the main node, uses only what arrived, and its output rides back; wanted inputs stay put; every material is
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
	g.bank[P] = {"bots": 40.0, "intel": 100.0, "cash": 60.0, "creds": 60.0, "research": 60.0}


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


func hub_couriers() -> int: return int(g.bank[P].bots) + g._couriers_out(P, int(g.rig[P]))


func run() -> void:
	supply_round_trip()
	firewall_sockets()
	relays()
	no_foreign_transit()
	full_destinations()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func supply_round_trip() -> void:
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, [])   # no station at home: the main node's couriers are what it starts with plus the trickle
	var pair := far_pair()
	var far: int = pair[1]
	g._set_builds(far, ["cash"])   # a lone Miner: no Intel of its own, no station
	var bots0 := hub_couriers()
	g._cmd(["want", far, "intel", 4])
	check(g._want(far, "intel") == 4.0, "A host can ask its main node to keep 4 Intel there")
	step(1.0)
	check(in_flight("intel") >= 1.0 and g._inbound(far, "intel") >= 1.0, "Main-node couriers set off with Intel; the host's room for it is held (%.0f on the way)" % in_flight("intel"))
	check(float(g.hosts[far].store.get(P, {}).get("intel", 0.0)) < 0.001, "Nothing is there before it arrives: production uses only what has arrived")
	step(24.0)
	var supplied := led("out:supply:intel")
	var at_host: float = float(g.hosts[far].store.get(P, {}).get("intel", 0.0))
	var cash_made: float = led("in:delivered:cash") + float(g.hosts[far].store.get(P, {}).get("cash", 0.0)) + in_flight("cash")
	check(supplied >= 4.0 and cash_made >= 1.0, "The Miner turns the supplied Intel into Crypto (%.0f Intel sent, %.0f Crypto made)" % [supplied, cash_made])
	check(absf(supplied - (at_host + in_flight("intel") + cash_made)) < 0.01, "Intel is conserved: sent %.0f = %.0f at the host + %.0f on the way + %.0f turned into Crypto" % [supplied, at_host, in_flight("intel"), cash_made])
	check(led("in:delivered:cash") >= 1.0 and led("from:%d:cash" % far) == led("in:delivered:cash"), "Its Crypto rides back on the couriers and reaches the bank (%.0f)" % led("in:delivered:cash"))
	check(led("from:%d:intel" % far) == 0.0, "The wanted Intel is never carried back out of the host")
	var trickle_bots := led("in:trickle:bots")
	check(absf(float(hub_couriers()) - (float(bots0) + trickle_bots)) < 0.05, "Couriers are reused, never used up: %d now = %d + %.1f made since" % [hub_couriers(), bots0, trickle_bots])
	var bank_intel_check := led("out:supply:intel") + float(g.bank[P].intel) - 100.0 - led("in:trickle:intel")
	check(absf(bank_intel_check) < 0.01, "The bank paid exactly what was sent, no more (gap %.3f)" % bank_intel_check)
	g._cmd(["want", far, "intel", 0])
	step(12.0)
	check(g._inbound(far, "intel") < 0.001 and in_flight("intel") < 0.001, "With no stock wanted, no more Intel is sent")


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
	step(11.0)
	check(g._sockets(far) == 3, "Once built it has its 3")
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
	g._set_builds(far, ["intel"])   # no station here: the main node's couriers serve it
	var far2 := -1   # a second host past the relay, with its own Bot station
	for nb in g.hosts[far].links:
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL and not g.hosts[via].links.has(n) and not g.hosts[home].links.has(n): far2 = n; break
	g._capture(far2, P); g.hosts[far2].type = "pc"; g.hosts[far2].slots = 3
	g._set_builds(far2, ["bot", "intel"])
	var beyond := -1   # a rival host linked to far only
	for nb in g.hosts[far].links:
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL and not g.hosts[via].links.has(n) and not g.hosts[home].links.has(n): beyond = n; break
	g._capture(beyond, R)
	g._mark_scanned(P, beyond)
	g.cards[P] = {"breach": 1, "patch": 1}
	g.hosts[far2].couriers = 1; g.hosts[far2].store = {P: {"creds": 1.0}}
	g._cmd(["want", far, "cash", 1])
	g._play_card(P, "breach", beyond)
	g._play_card(P, "patch", far)
	g._tick_logistics()   # far2's courier with Credentials; a main-node courier with Crypto for far
	var kinds := {}
	for f in g.flights: kinds[str(f.kind) + ("/def" if str(f.kind) == "op" and bool(g._is_defense(str(f.card))) else "") + ("/host" if str(f.kind) == "courier" and int(f.origin) != home else "")] = true
	check(kinds.has("op") and kinds.has("op/def") and kinds.has("courier") and kinds.has("courier/host"), "Four kinds on the road: an attack, a defence card, a main-node courier, a host's courier (%s)" % [kinds.keys()])
	g.hosts[via].ddos_until = g._t + 6.0   # the relay is knocked out
	step(2.0)
	var held: int = g.flights.filter(func(f): return bool(f.get("blocked", false))).size()
	check(held == g.flights.size() and held >= 4, "A relay under DDoS holds every packet before it (%d of %d held)" % [held, g.flights.size()])
	check(float(g.hosts[far].store.get(P, {}).get("cash", 0.0)) < 0.001 and g._held(P, "breach") == 0 and g._execs.is_empty(), "Nothing jumps the relay: no early delivery, no early execution")
	check(g.events.any(func(e): return str(e.key).begins_with("held:") and bool(e.live)), "The held packets show as one live event per host")
	var tips_ok := true
	for f in g.flights: tips_ok = tips_ok and (g._flight_lines(f) as Array).size() >= 2 and str(g._flight_lines(f)[1]).begins_with("Held at")
	check(tips_ok, "Hovering a held packet says where it waits and why")
	step(14.0)
	check(g._execs.any(func(e): return int(e.target) == beyond) or g.op_outcomes.any(func(o): return int(o.get("target", -1)) == beyond), "When the DDoS ends they go on: the Breach executes on its target")
	check(float(g.hosts[far].patch_armed_until) > g._t and float(g.hosts[far].store.get(P, {}).get("cash", 0.0)) >= 1.0, "...the Patch reaches its host, the supply is delivered")
	check(led("from:%d:creds" % far2) >= 1.0, "...and the host's courier brings its Credentials home")
	# held inside a relay that is then taken: lost there, and every reservation it held is settled
	fresh()
	home = int(g.rig[P])
	pair = far_pair()
	via = pair[0]; far = pair[1]
	g._set_builds(far, ["intel"])
	g.cards[P] = {"patch": 1}
	g.hosts[far].store = {P: {"intel": 2.0}}
	g._cmd(["want", far, "cash", 1])
	g._play_card(P, "patch", far)
	g._tick_logistics()   # main-node couriers: one fetching Intel, one bringing Crypto
	var inc0: float = g._incoming(P, "intel") + g._incoming(P, "bots")
	var n0: int = g.flights.size()
	for f in g.flights: g._block(f, via)   # all of them wait inside the relay
	g._capture(via, R)
	g._tick_blocked()
	check(n0 >= 3 and g.flights.is_empty(), "Packets held in a relay that is taken are lost with it (%d)" % n0)
	check(g._socket_res(far) == 0 and g._inbound(far, "cash") < 0.001 and g._claimed(far, P, "intel") < 0.001,
		"Their reservations at the far host are released: the held socket, the room for the supply, the claimed pickup")
	check(inc0 >= 2.0 and g._incoming(P, "intel") < 0.001 and g._incoming(P, "bots") < 0.001, "...and the bank room they held for cargo and couriers")
	check(led("lost:cargo:cash") >= 1.0 and led("lost:couriers:bots") >= 1.0, "The lost cargo and couriers are recorded")
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
	g._cmd(["want", far, "cash", 6])
	g.hosts[far].store = {P: {"intel": 10.0}}   # full storage: no room for supplies
	var sent0 := led("out:supply:cash")
	step(3.0)
	check(led("out:supply:cash") == sent0, "No supply is sent to a host with no room for it")
