extends SceneTree
## Host diagnoses and route inspection (Milestone A, brief §9.3 and §12.1): the next-cycle preview matches what the
## cycle really does; each problem gets the right status and a cause the player can act on; the route home reports
## hops, travel and queueing; looking never changes the simulation.
## godot --headless --path . --script tests/diagnosis_test.gd
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
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func own_pc(kinds: Array, _nth := 0) -> int:   # a plain PC linked to your network (so it has a route home), yours, with these buildings
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != g.NEUTRAL: continue
		var linked := false
		for nb in g.hosts[i].links: linked = linked or int(g.hosts[int(nb)].owner) == P
		if not linked: continue
		g.hosts[i].type = "pc"; g.hosts[i].slots = 3
		g._capture(i, P)
		g._set_builds(i, kinds)
		return i
	check(false, "the map has a neutral host linked to your network")
	return -1


func far_pair() -> Array:   # [via, far]: a host two links out whose only link to your network is `via`
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != g.NEUTRAL: continue
		var touches := false
		for nb in g.hosts[i].links: touches = touches or int(g.hosts[int(nb)].owner) == P
		if touches: continue
		for nb in g.hosts[i].links:
			var v := int(nb)
			if int(g.hosts[v].owner) != g.NEUTRAL: continue
			for nb2 in g.hosts[v].links:
				if int(g.hosts[int(nb2)].owner) == P:
					g._capture(v, P); g._capture(i, P)
					return [v, i]
	return []


func run() -> void:
	preview_matches_cycle()
	statuses()
	route_inspection()
	delivered_per_host()
	panel_order()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func sent_of(from: int) -> Array:
	var out := []
	for f in g.flights.slice(from):
		if str(f.kind) == "cargo": out.append(str(f.res))
		elif str(f.kind) == "newbot": out.append("")
	return out


func compare(i: int, label: String) -> void:   # the preview, then the real cycle: the same storage after
	var pv: Dictionary = g._cycle_preview(i)
	g._run_cycle(i)
	var benef: int = int(pv.benef)
	var worst := 0.0
	for res in g.RES: worst = maxf(worst, absf(float(g._st_get(i, benef, res)) - float(pv.after[res])))
	check(worst < 0.001, "Preview = cycle: %s (gap %.4f)" % [label, worst])


func preview_matches_cycle() -> void:
	fresh()
	var home: int = int(g.rig[P])
	g.bank[P] = {"intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	compare(own_pc(["intel", "cash"]), "harvester + Miner")
	compare(own_pc(["cash"], 0), "a starved Miner")
	var n := own_pc(["intel", "cash", "lab"], 0)
	g.hosts[n].store = {P: {"intel": 3.0}}
	compare(n, "harvester + Miner + Lab with 3 Intel stored")
	n = own_pc(["bot", "intel", "cash"], 0)
	g.hosts[n].store = {P: {"creds": 2.0, "research": 1.0}}
	compare(n, "a host with its own station and stock")
	n = own_pc(["intel", "intel"], 0)
	g.hosts[n].store = {P: {"intel": 9.0}}
	compare(n, "two harvesters, storage almost full")
	n = own_pc(["wall", "cash"], 0)
	g.hosts[n].store = {P: {"intel": 1.0}}
	compare(n, "Firewall upkeep before the Miner")
	g._set_builds(home, ["cash", "lab"])
	g.bank[P].intel = 1.5; g.bank[P].cash = 0.0
	compare(home, "main node: Miner then Lab on the bank")
	g.bank[P].cash = g._cap(P, "cash") - 0.4
	g.bank[P].intel = 50.0
	compare(home, "main node: Crypto bank almost full")
	n = own_pc(["intel", "cash"], 0)
	var rival: int = int(g.botnets[1]) if int(g.botnets[0]) == P else int(g.botnets[0])
	g.hosts[n].steal_by = rival; g.hosts[n].steal_until = g._t + 30.0
	compare(n, "phished: output tagged for the thief")
	# looking changes nothing
	var h0: String = g._mp_hash()
	var res0: int = g._res.size(); var nf: int = g.flights.size()
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == P: g._host_diag(i); g._delivery_lines(i); g._route_home_line(i)
	check(g._mp_hash() == h0 and g._res.size() == res0 and g.flights.size() == nf, "Diagnosing every host leaves the simulation untouched (fingerprint, link reservations, flights)")


func diag(i: int) -> Dictionary: return g._host_diag(i)


func lines_have(d: Dictionary, needle: String) -> bool:
	for l in d.lines:
		if str(l[0]).contains(needle): return true
	return false


func statuses() -> void:
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, [])
	g.bank[P] = {"intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	var n := own_pc(["intel", "cash"])
	var d := diag(n)
	check(str(d.status) == "operating" and str(d.role) == "CRYPTO HOST", "Harvester + Miner: CRYPTO HOST · operating (%s · %s)" % [d.role, d.status])
	check(str(d.next).begins_with("Next cycle in") and str(d.next).contains("1 Intel → 1 Crypto"), "Its next cycle reads in words: %s" % d.next)
	n = own_pc(["cash"], 0)
	g.bank[P].intel = 0.0
	d = diag(n)
	check(str(d.status) == "starved" and lines_have(d, "has none to send") and lines_have(d, "Intel harvester"),
		"A remote Miner with no Intel anywhere is starved and names both fixes: make Intel, or build a harvester here")
	check(str(d.next).contains("Miner idle") and str(d.full).contains("1 Intel → 1 Crypto"), "Feasible (idle) and theoretical output are shown apart")
	g.bank[P].intel = 60.0
	d = diag(n)
	check(str(d.status) == "starved" and lines_have(d, "no workers to fetch it"), "With Intel at the main node but no workers anywhere it says to build a Bot station (%s)" % str(d.lines))
	g._set_builds(home, ["bot"])
	d = diag(n)
	check(str(d.status) == "starved" and lines_have(d, "workers are bringing it"), "With Intel at the main node it says workers are bringing it (%s)" % str(d.lines))
	n = own_pc(["intel", "lab"], 0)
	g.bank[P].cash = 0.0
	d = diag(n)
	check(str(d.status) == "starved" and lines_have(d, "Crypto miner"), "A Lab with Intel but no Crypto anywhere is starved and points to a Crypto miner")
	g.bank[P].cash = 60.0
	n = own_pc([], 0)
	g.hosts[n].store = {P: {"creds": 10.0}}
	g.bank[P].creds = g._cap(P, "creds")
	d = diag(n)
	check(str(d.status) == "blocked" and lines_have(d, "Credentials is full"), "Full storage with a full bank is blocked and says which bank (%s)" % str(d.lines))
	g.bank[P].creds = 0.0
	g._set_builds(home, [])
	g.hosts[n].store = {P: {"intel": 3.0}}
	d = diag(n)
	check(str(d.status) == "waiting for workers" and lines_have(d, "no workers"), "Stored units with no workers anywhere wait, and say how to get workers (%s · %s)" % [d.status, str(d.lines)])
	g.hosts[n].ddos_until = g._t + 10.0
	check(str(diag(n).status) == "under DDoS", "DDoS is the headline while it lasts")
	g.hosts[n].ddos_until = 0.0
	g._set_builds(n, ["intel"])
	g.hosts[n].sabot_until = g._t + 10.0
	check(str(diag(n).status) == "sabotaged", "Sabotage is the headline while it lasts")
	g.hosts[n].sabot_until = 0.0
	g._set_builds(n, ["wall"]); g.hosts[n].store = {}
	d = diag(n)
	check(str(d.status) == "Firewall off" and str(d.role) == "FIREWALL HOST", "A Firewall with no Intel here will be off, and says so")
	g._set_builds(n, [])
	check(str(diag(n).status) == "idle" and str(diag(n).role) == "EMPTY HOST", "An empty host is idle and says how to start")
	g._set_builds(n, ["intel"]); g.hosts[n].producer_paused = {0: true}
	check(str(diag(n).status) == "paused", "A host whose only producer you paused reads paused")
	g._set_builds(home, ["cash"]); g.bank[P].intel = 0.0
	d = diag(home)
	check(str(d.role) == "MAIN NODE" and str(d.status) == "starved" and lines_have(d, "no Intel in your bank"), "A main-node Miner with an empty Intel bank is starved")
	g.bank[P].intel = 50.0; g.bank[P].cash = g._cap(P, "cash")
	check(str(diag(home).status) == "blocked" and lines_have(diag(home), "Crypto bank is full"), "A main-node Miner with a full Crypto bank is blocked")


func route_inspection() -> void:
	fresh()
	var pair := far_pair()
	if pair.is_empty(): check(false, "map has a host two links out through one neighbour"); return
	var via: int = pair[0]; var far: int = pair[1]
	g._set_builds(far, ["intel"])
	var rt: Array = g._home_route(P, far)
	var eta: Dictionary = g._route_eta(rt)
	check(int(eta.hops) == rt.size() - 1 and absf(float(eta.travel) - g._travel_time(rt)) < 0.001 and float(eta.wait) < 0.001,
		"Route home: %d hops, %.2f s travel, no queue on an empty network" % [int(eta.hops), float(eta.travel)])
	var key: String = g._lkey(int(rt[0]), int(rt[1]))
	for k in g._link_cap(int(rt[0]), int(rt[1])): g._reserve(key, g._t)
	var res0: int = (g._res[key] as Array).size()
	eta = g._route_eta(rt)
	check(float(eta.wait) > 0.5 and (g._res[key] as Array).size() == res0, "A busy first link shows queueing (%.2f s) without reserving anything" % float(eta.wait))
	check(g._route_home_line(far).contains("queue"), "The panel line names the queue: %s" % g._route_home_line(far))
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1
	var d: Dictionary = g._host_diag(far)
	check(str(d.status) == "no route" and g._route_home_line(far) == "Route home: none", "Cut off from the main node: status no route, and the route line says none")
	check(g._cut_off(far).has(far) and not g._cut_off(far).has(int(g.rig[P])), "The cut-off segment holds the host and not the main node")


func delivered_per_host() -> void:
	fresh()
	g._set_builds(int(g.rig[P]), [])
	var n := own_pc(["bot", "intel", "cash"])
	step(45.0)
	var got: Dictionary = g._host_delivered(P, n)
	var cash := float(got.get("cash", 0.0)); var intel := float(got.get("intel", 0.0))
	check(absf(cash - 12.0) <= 2.5 and absf(intel - 12.0) <= 2.5, "Delivered from this host: %.1f Crypto/min (12) and %.1f Intel/min (12)" % [cash, intel])
	var wc: Dictionary = g._worker_counts(P, n)
	check(int(wc.total) == 2, "Its station's two workers stay its own (%d)" % int(wc.total))
	var lines: Array = g._delivery_lines(n)
	var txt := ""
	for l in lines: txt += str(l[0]) + "\n"
	check(txt.contains("Delivered recently: ") and txt.contains("Crypto") and txt.contains("Route home: 1 hop"), "The delivery block reads route, carriers, storage and what arrived")


func panel_order() -> void:   # role → status → problems → next cycle → delivery → installations
	fresh()
	g.bank[P] = {"intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	var n := own_pc(["cash"])
	g.sel = {n: true}; g._inspect = -1
	var txt: String = g._panel_text()
	var a := txt.find("CRYPTO HOST · starved"); var b := txt.find("needs Intel here"); var c := txt.find("Next cycle in")
	var d := txt.find("Route home:"); var e := txt.find("Installations")
	check(a >= 0 and a < b and b < c and c < d and d < e, "Host panel order: role · status, problem, next cycle, delivery, installations (%d %d %d %d %d)" % [a, b, c, d, e])
