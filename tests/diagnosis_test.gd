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
	firewall_upkeep()
	honest_producer_notes()
	firewall_notes_0615()
	upkeep_notes_tell_the_truth()
	sabotaged_workers_note()
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
	compare(own_pc(["cash"], 0), "a Miner alone (it needs no input)")
	var n := own_pc(["intel", "cash", "lab"], 0)
	g.hosts[n].store = {P: {"intel": 3.0}}
	compare(n, "harvester + Miner + Lab with 3 Intel stored")
	n = own_pc(["bot", "intel", "cash"], 0)
	g.hosts[n].store = {P: {"creds": 2.0, "research": 1.0}}
	compare(n, "a host with its own station and stock")
	n = own_pc(["intel", "intel"], 0)
	g.hosts[n].store = {P: {"intel": 9.0}}
	compare(n, "two harvesters, storage almost full")
	n = own_pc(["intel", "cash", "lab"], 0)   # 0.6.12: a storage short of room gives every producer the same share
	var gross := 0.0
	for kind in ["intel", "cash", "lab"]: gross += float(g.BUILD_KINDS[kind].rate) * g._tmult(n, str(g.BUILD_KINDS[kind].out))
	var room := gross / 2.0
	g.hosts[n].store = {P: {"creds": g.STORE_CAP - room}}
	compare(n, "harvester + Miner + Lab with room for half a cycle")
	var gap := 0.0; var made := []
	for kind in ["intel", "cash", "lab"]:
		var res := str(g.BUILD_KINDS[kind].out)
		var got := float(g._st_get(n, P, res))
		gap = maxf(gap, absf(got - float(g.BUILD_KINDS[kind].rate) * g._tmult(n, res) * room / gross))
		made.append("%s %s" % [g._amt(got), g.RES_NAME[res]])
	check(gap < 0.001, "Room for %s of a cycle's %s units: every producer makes the same share, the harvester not first (%s)" % [g._amt(room), g._amt(gross), ", ".join(made)])
	n = own_pc(["wall", "cash"], 0)
	g.hosts[n].store = {P: {"intel": 1.0}}
	compare(n, "Firewall upkeep from stored Intel, beside a Miner")
	g._set_builds(home, ["cash", "lab"])
	g.bank[P].intel = 1.5; g.bank[P].cash = 0.0
	compare(home, "main node: Miner and Lab with 1.5 Intel and no Crypto in the bank")
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
	var crypto := "+%s %s" % [g._amt(float(g.BUILD_KINDS.cash.rate) * g._tmult(n, "cash")), g.RES_NAME.cash]
	var intel := "+%s %s" % [g._amt(float(g.BUILD_KINDS.intel.rate) * g._tmult(n, "intel")), g.RES_NAME.intel]
	check(str(d.next).begins_with("Next cycle in") and str(d.next).contains(intel) and str(d.next).contains(crypto) and not str(d.next).contains("→"),
		"Its next cycle reads in words, the Miner taking no input: %s" % d.next)
	n = own_pc(["cash"], 0)   # 0.6.12: a converter needs no input, so nothing can starve it
	g.bank[P].intel = 0.0
	d = diag(n)
	check(str(d.status) == "operating" and str(d.next).contains(crypto) and not str(d.next).contains("idle") and str(d.full) == "",
		"A remote Miner with no Intel anywhere and no workers still makes %s: %s (%s)" % [crypto, d.status, d.next])
	var stored: float = g.STORE_CAP - float(g.BUILD_KINDS.cash.rate) * g._tmult(n, "cash") / 2.0
	g.hosts[n].store = {P: {"creds": stored}}
	d = diag(n)
	var part := "+%s %s of %s (no room)" % [g._amt(float(g.BUILD_KINDS.cash.rate) * g._tmult(n, "cash") / 2.0), g.RES_NAME.cash, g._amt(float(g.BUILD_KINDS.cash.rate) * g._tmult(n, "cash"))]
	check(str(d.next).contains(part) and str(d.full).contains(crypto), "Storage at %s/%s: the feasible share and the theoretical output are shown apart (%s | %s)" % [g._amt(stored), int(g.STORE_CAP), d.next, d.full])
	g.hosts[n].store = {P: {"creds": g.STORE_CAP}}
	d = diag(n)
	check(str(d.next).contains("Miner idle") and str(d.full).contains(crypto), "Feasible (idle) and theoretical output are shown apart (%s | %s)" % [d.next, d.full])
	g.hosts[n].store = {}
	g.bank[P].intel = 60.0
	n = own_pc(["lab"], 0)
	g.bank[P].intel = 0.0; g.bank[P].cash = 0.0
	d = diag(n)
	var research := "+%s %s" % [g._amt(float(g.BUILD_KINDS.lab.rate) * g._tmult(n, "research")), g.RES_NAME.research]
	g._run_cycle(n)
	check(str(d.status) == "operating" and str(d.next).contains(research) and absf(float(g._st_get(n, P, "research")) - float(g.BUILD_KINDS.lab.rate) * g._tmult(n, "research")) < 0.001,
		"A Lab with no Intel or Crypto anywhere still makes %s a cycle: %s (%s)" % [research, d.status, d.next])
	g.bank[P].intel = 60.0
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
	g._set_builds(n, ["intel"]); g._cmd(["produce", n, 0])   # (a retired verb: a building cannot be paused)
	check(str(diag(n).status) != "paused" and g._producer_active(n, 0), "A building cannot be paused: the old pause order changes nothing")
	var said := []   # no advice to pause anything, anywhere a host explains itself
	for i in g.hosts.size():
		if not g._mine(i): continue
		for line in (g._host_diag(i).lines as Array): said.append(str(line[0]))
		for k in (g.hosts[i].builds as Array).size(): said.append(g._slot_tip(i, k))
	check(not said.any(func(t): return t.to_lower().contains("pause")), "No host note tells you to pause something")
	g._set_builds(home, ["cash"]); g.bank[P].intel = 0.0
	d = diag(home)
	var cash0: float = float(g.bank[P].cash)
	g._run_cycle(home)
	var made_home: float = float(g.bank[P].cash) - cash0
	check(str(d.role) == "MAIN NODE" and str(d.status) == "operating" and str(d.next).contains(crypto) and absf(made_home - float(g.BUILD_KINDS.cash.rate) * g._tmult(home, "cash")) < 0.001 and float(g.bank[P].intel) < 0.001,
		"A main-node Miner with an empty Intel bank still makes Crypto (%s, +%s Crypto, Intel bank %s)" % [d.status, g._amt(made_home), g._amt(float(g.bank[P].intel))])
	g.bank[P].intel = 50.0; g.bank[P].cash = g._cap(P, "cash")
	check(str(diag(home).status) == "blocked" and lines_have(diag(home), "Crypto bank is full"), "A main-node Miner with a full Crypto bank is blocked")


func firewall_upkeep() -> void:   # the one input left (0.6.12): a Firewall's Intel, from its host's storage or brought by workers
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, [])
	g.bank[P] = {"intel": 0.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	var w := own_pc(["wall"])
	var need: float = float(g.BUILD_KINDS.wall.use.intel) * g._count_all(w, "wall")
	var d := diag(w)
	check(str(d.status) == "Firewall off" and lines_have(d, "needs %s Intel here" % g._amt(need)) and lines_have(d, "Build an Intel harvester here"),
		"A remote Firewall with no Intel anywhere will be off and names the fix (%s)" % str(d.lines))
	g.bank[P].intel = 60.0
	step(float(g.hosts[w].cyc) + 0.5)   # Intel at the main node, but no workers: nothing brings it
	d = diag(w)
	check(not bool(g.hosts[w].fw_on) and float(g._st_get(w, P, "intel")) < 0.001 and str(d.status) == "Firewall off",
		"With Intel at the main node but no workers anywhere, the Firewall goes off at its cycle and the host says so (%s)" % d.status)
	g._set_builds(home, ["bot"])
	var left: float = float(g.hosts[w].cyc)
	var waited := 0.0
	while waited < left - 1.0 and float(g._st_get(w, P, "intel")) < need - 0.001:
		step(0.5); waited += 0.5
	d = diag(w)
	check(float(g._st_get(w, P, "intel")) >= need - 0.001 and str(d.status) == "operating" and str(d.next).contains("Firewall uses %s Intel" % g._amt(need)),
		"With Intel at the main node, workers bring the Firewall's %s Intel before its cycle (%.1f s) and the host reads %s: %s" % [g._amt(need), waited, d.status, d.next])
	step(float(g.hosts[w].cyc) + 0.5)
	check(bool(g.hosts[w].fw_on), "The delivered upkeep keeps the Firewall on at its cycle")


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
	var n := own_pc(["bot", "intel", "intel", "cash"])   # every producer makes its own, nothing is used: 2 Intel and 1 Crypto a cycle
	step(60.0)
	var got: Dictionary = g._host_delivered(P, n)
	var cash := float(got.get("cash", 0.0)); var intel := float(got.get("intel", 0.0))
	var per_min: float = 60.0 / g.PROD_CYCLE
	var want_cash: float = float(g.BUILD_KINDS.cash.rate) * g._tmult(n, "cash") * g._count(n, "cash") * per_min
	var want_intel: float = float(g.BUILD_KINDS.intel.rate) * g._tmult(n, "intel") * g._count(n, "intel") * per_min
	check(absf(cash - want_cash) <= 2.5 and absf(intel - want_intel) <= 2.5, "Delivered from this host: %.1f Crypto/min (%.0f) and %.1f Intel/min (%.0f)" % [cash, want_cash, intel, want_intel])
	var wc: Dictionary = g._worker_counts(P, n)
	check(int(wc.total) == 2, "Its station's two workers are counted with it (%d)" % int(wc.total))
	var lines: Array = g._delivery_lines(n)
	var txt := ""
	for l in lines: txt += str(l[0]) + "\n"
	check(txt.contains("Delivered recently: ") and txt.contains("Crypto") and txt.contains("Route home: 1 hop"), "The delivery block reads route, carriers, storage and what arrived")


func dfs_text(n: Node) -> String:
	var out := ""
	if n is Label: out += str((n as Label).text) + "\n"
	elif n is Button: out += "[%s]\n" % str((n as Button).text)
	for c in n.get_children(): out += dfs_text(c)
	return out


func panel_order() -> void:   # your host's panel: its name, its facts drawn as icons, one row per slot; no status prose
	fresh()
	g.bank[P] = {"intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	var n := own_pc(["cash"])
	g.sel = {n: true}; g._inspect = -1
	g._refresh_panel()
	var labels := []; var slots := 0; var options := 0
	var stack: Array = [g.panel_box]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		for ch in c.get_children(): stack.append(ch)
		if c is Label: labels.append(str((c as Label).text))
		elif "stop_button" in c and "slot" in c: slots += 1
		elif c.has_method("choose"): options += 1
	check(labels == [str(g.hosts[n].name)], "The only text label is the host's name; its facts and slots are drawn (%s)" % str(labels))
	check(slots == int(g.hosts[n].slots) and options == 0, "Then one row for each of its %d slots, and the buildings only in a slot's chooser (%d, %d)" % [int(g.hosts[n].slots), slots, options])
	var d: Dictionary = g._host_diag(n)
	var crypto := "+%s %s" % [g._amt(float(g.BUILD_KINDS.cash.rate) * g._tmult(n, "cash")), g.RES_NAME.cash]
	check(str(d.status) == "operating" and str(d.next).contains(crypto), "The diagnosis still exists for the Logs and the Economy view (%s: %s)" % [str(d.status), str(d.next)])


func honest_producer_notes() -> void:   # producers need no input: a nearly full storage is a storage note, and a Firewall's upkeep names its real cause
	fresh()
	var home: int = int(g.rig[P])
	var n := own_pc(["intel", "cash", "lab"])
	g.hosts[n].store = {P: {"creds": 8.5}}
	var d := diag(n)
	check(str(d.status) != "starved" and not lines_have(d, "waits its turn"), "A nearly full storage does not call a Miner or Lab starved for supplies (%s)" % str(d.status))
	fresh()
	home = int(g.rig[P])
	g._set_builds(home, ["intel"]); g.bank[P].intel = 60.0   # Intel at the main node, no workers
	var w := own_pc(["wall"])
	check(lines_have(diag(w), "Build a Bot station"), "A Firewall fed from a bank with no workers says to build a Bot station")
	fresh()
	home = int(g.rig[P])
	g._set_builds(home, ["bot"]); g.bank[P].intel = 60.0
	w = own_pc(["wall"])
	var off_while_coming := false
	for k in 30:
		step(0.1)
		if g._inbound(w, "intel") >= 0.999 and str(diag(w).status) == "Firewall off": off_while_coming = true
	check(not off_while_coming, "While a worker brings its Intel, the Firewall is not called off")
	fresh()
	home = int(g.rig[P])
	g._set_builds(home, ["bot"]); g.bank[P].intel = 60.0
	w = own_pc(["wall"])
	g.hosts[w].store = {P: {"creds": float(g.STORE_CAP)}}
	g.bank[P].creds = g._cap(P, "creds")   # nowhere to ship it: the storage stays full
	step(3.0)
	var d2 := diag(w)
	check(lines_have(d2, "storage is full") and not lines_have(d2, "bringing it"), "A Firewall whose host storage is full says its Intel cannot come, not that workers bring it")


func upkeep_notes_tell_the_truth() -> void:   # (0.6.14) a Firewall's note matches what its next cycle and the workers will do
	fresh()
	g.bank[P] = {"intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	var n := own_pc(["intel", "cash", "wall"])
	var need: float = float(g.BUILD_KINDS.wall.use.intel)
	g.hosts[n].store = {P: {"creds": g.STORE_CAP - float(g.BUILD_KINDS.cash.rate) * g._tmult(n, "cash")}}   # room for the Miner's cycle only
	g.hosts[n].fw_on = true
	var d := diag(n)
	check(str(d.status) != "Firewall off" and str(d.next).contains("Firewall uses %s Intel" % g._amt(need)) and not lines_have(d, "bringing it"),
		"A Firewall beside its own harvester, the storage nearly full: the harvest feeds it first, and the host does not claim workers bring Intel (%s: %s)" % [d.status, d.next])
	g._run_cycle(n)
	check(bool(g.hosts[n].fw_on), "...and the cycle keeps it on, as the preview said")
	fresh()
	g.bank[P] = {"intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	var w := own_pc(["wall", "wall"])   # two Firewalls: more upkeep than the storage has room for
	need = float(g.BUILD_KINDS.wall.use.intel) * g._count_all(w, "wall")
	g.hosts[w].store = {P: {"creds": g.STORE_CAP - (need - 0.5)}}
	var asked := false
	for r in g._open_requests(P, int(g.rig[P])):
		if int(r.host) == w and str(r.purpose) == "upkeep": asked = true
	d = diag(w)
	check(not asked and str(d.status) == "Firewall off" and not lines_have(d, "bringing it"),
		"Two Firewalls needing %s Intel with room for %s: no upkeep is asked for, and the host does not say workers are bringing it (%s)" % [g._amt(need), g._amt(need - 0.5), str(d.lines)])


func sabotaged_workers_note() -> void:   # (0.6.14) workers Sabotage keeps at their stations are named as stopped, not busy
	fresh()
	g.bank[P] = {"intel": 20.0, "cash": 20.0, "creds": 20.0, "research": 20.0}
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot", "bot"]); g._tick_teams(0.0)
	var n := own_pc(["cred", "cred", "cred"])
	step(40.0)
	g.hosts[home].sabot_until = g._t + 60.0   # every station is on the main node: all the workers stop when free
	step(6.0 + g.PROD_CYCLE * 4.0)   # the ones out come home; the host fills up
	var wc: Dictionary = g._worker_counts(P)
	var d := diag(n)
	check(int(wc.idle) == 0 and int(wc.blocked) == int(wc.total) and lines_have(d, "Sabotage") and not lines_have(d, "busy"),
		"With Sabotage holding all %d workers at their stations, the full host says so, not that they are busy (%s)" % [int(wc.total), str(d.lines)])


func firewall_notes_0615() -> void:   # (0.6.15) a stopped harvester is not a missing one; Sabotage holds workers still out on a leg
	for how in ["sabotage", "ddos"]:
		fresh()
		var home: int = int(g.rig[P])
		g._set_builds(home, ["bot"]); g.bank[P].intel = 0.0
		var w := own_pc(["intel", "wall", "cash"])
		if how == "sabotage": g.hosts[w].sabot_until = g._t + 60.0
		else: g.hosts[w].ddos_until = g._t + 60.0
		var d := diag(w)
		check(lines_have(d, "harvester is stopped") and not lines_have(d, "Build an Intel harvester"), "Under %s, a Firewall host whose harvester is stopped does not say to build one" % how)
	fresh()
	var hub: int = int(g.rig[P])
	g._set_builds(hub, ["bot", "bot"]); g._tick_teams(0.0); g.bank[P].intel = 30.0
	step(1.0)
	var w2 := own_pc(["wall"])
	for wid in g.workers: g.workers[wid].state = "trip"   # every worker is out on a leg (none free)
	g.hosts[hub].sabot_until = g._t + 60.0
	var d2 := diag(w2)
	check(not lines_have(d2, "bringing it") and lines_have(d2, "Sabotage"), "While Sabotage holds every worker (even those still on a leg), the Firewall note says so, not that Intel is coming")
