extends SceneTree
## Event history (Milestone A, brief §17.4): one persistent, deduplicated queue in three priorities. Lasting conditions
## are one entry that updates and then ends (kept in history, no longer active); repeated news counts up; clicking an
## entry finds its host; the queue never touches the simulation.
## godot --headless --path . --script tests/events_test.gd
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
	P = g.PLAYER
	R = int(g.botnets[1]) if int(g.botnets[0]) == P else int(g.botnets[0])
	g.bank[P] = {"bots": 60.0, "intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func own_pc(kinds: Array) -> int:   # a plain PC linked to your network, yours
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != g.NEUTRAL: continue
		for nb in g.hosts[i].links:
			if int(g.hosts[int(nb)].owner) == P:
				g.hosts[i].type = "pc"; g.hosts[i].slots = 3
				g._capture(i, P); g._set_builds(i, kinds)
				return i
	return -1


func entries(key_prefix: String) -> Array:
	return g.events.filter(func(e): return str(e.key).begins_with(key_prefix))


func intrusion(id: int, t: int, secs: float) -> void:   # a rival intrusion starting on host t
	g._start_exec({"id": id, "fac": R, "card": "breach", "effect": "capture", "target": t, "gen": int(g.hosts[t].gen), "ends": g._t + secs, "stage": 1, "victim": P, "seen": [t]})


func run() -> void:
	intrusions()
	conditions()
	news()
	strip_and_history()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func intrusions() -> void:
	fresh()
	var t := own_pc(["intel"])
	intrusion(9001, t, 12.0)
	step(4.0)
	var e: Array = entries("intr:9001")
	check(e.size() == 1 and bool(e[0].live) and int(e[0].pri) == g.EV_ACT and str(e[0].text).contains("s left"), "A rival intrusion on your host is one live, actionable entry with its countdown")
	g.hosts[t].patch_armed_until = g._t + 30.0
	step(9.0)
	e = entries("intr:9001")
	check(e.size() == 1 and not bool(e[0].live) and str(e[0].text).contains("Your defence stopped") and int(e[0].pri) == g.EV_INFO, "When your Patch stops it, the same entry ends with the outcome (%s)" % (str(e[0].text) if e.size() > 0 else "none"))
	intrusion(9002, int(g.rig[P]), 15.0)
	step(1.0)
	e = entries("intr:9002")
	check(e.size() == 1 and int(e[0].pri) == g.EV_CRIT, "An intrusion on your main node is critical")
	g._op_outcome({"id": 9003, "fac": R, "card": "breach", "target": t, "stage": 1}, "captured")
	e = entries("intr:9003")
	check(e.size() == 1 and str(e[0].text).contains("took") and int(e[0].pri) == g.EV_ACT, "A host you lose is recorded: %s" % (str(e[0].text) if e.size() > 0 else "none"))
	g._op_outcome({"id": 9004, "fac": P, "card": "breach", "target": t, "stage": 1}, "route_failed")
	check(entries("op:9004").size() == 1 and str(entries("op:9004")[0].text).contains("lost the route"), "Your own failed operation says why")


func conditions() -> void:
	fresh()
	var t := own_pc(["intel"])
	g.hosts[t].ddos_until = g._t + 5.0
	step(3.0)
	var n_live := entries("fx:ddos").size()
	step(4.0)
	var e: Array = entries("fx:ddos")
	check(n_live == 1 and e.size() == 1 and not bool(e[0].live) and str(e[0].text).ends_with("ended."), "A DDoS on your host is one entry that ends when the DDoS does (%s)" % (str(e[0].text) if e.size() > 0 else "none"))
	# a cut route home, then restored
	var far := -1; var via := -1
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != g.NEUTRAL: continue
		var touches := false
		for nb in g.hosts[i].links: touches = touches or int(g.hosts[int(nb)].owner) == P
		if touches: continue
		for nb in g.hosts[i].links:
			var v := int(nb)
			if int(g.hosts[v].owner) != g.NEUTRAL: continue
			for nb2 in g.hosts[v].links:
				if int(g.hosts[int(nb2)].owner) == P and via < 0: via = v; far = i
		if far >= 0: break
	g._capture(via, P); g._capture(far, P); g._set_builds(far, ["intel"])
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1
	step(2.0)
	e = entries("cutoff")
	check(e.size() == 1 and bool(e[0].live) and int(e[0].pri) == g.EV_CRIT and int(e[0].host) == far, "A host cut off from the main node is critical and points at it")
	g._capture(via, P)
	step(2.0)
	check(entries("cutoff").size() == 1 and not bool(entries("cutoff")[0].live), "Restoring the route ends it; it stays in the history")
	# couriers held at the reserve
	g.bank[P].bots = 0.0
	g.hosts[t].store = {P: {"intel": 4.0}}
	step(1.0)
	check(entries("couriers").size() == 1 and bool(entries("couriers")[0].live), "Units waiting with no Bots above the reserve: couriers held")
	# research that cannot pay
	g.bank[P] = {"bots": 60.0, "intel": 0.0, "cash": 0.0, "creds": 60.0, "research": 0.0}
	g.research_job[P] = {"key": "exploit", "progress": 1.0, "paused": false}
	step(1.0)
	check(entries("research").size() == 1 and str(entries("research")[0].text).contains("stopped"), "Research that cannot pay is actionable: %s" % (str(entries("research")[0].text) if entries("research").size() > 0 else "none"))
	# a rival holding the majority
	var need: int = int(g._objective().need)
	var given := 0
	for i in g.hosts.size():
		if given >= need: break
		if int(g.hosts[i].owner) == g.NEUTRAL: g.hosts[i].owner = R; given += 1
	step(2.0)
	e = entries("majority")
	check(e.size() == 1 and bool(e[0].live) and int(e[0].pri) == g.EV_CRIT and str(e[0].text).contains("wins in"), "A rival holding the majority is critical, with its countdown")
	var h0: String = g._mp_hash()
	var saved: Array = g.events.duplicate(true)
	g.events = []
	check(g._mp_hash() == h0, "The event history is not part of the lockstep fingerprint")
	g.events = saved


func news() -> void:
	fresh()
	g.cards[P] = {}
	g.known[P]["breach"] = true
	for k in 2:
		g._lane_set(P, k, "breach"); g._lane_manufacture(P, k)
	step(16.0)
	var e: Array = entries("mf:breach")
	check(e.size() == 1 and int(e[0].n) == 2 and int(e[0].pri) == g.EV_INFO, "Two copies finished together: one entry ×2")
	g.research_job[P] = {"key": "exploit", "progress": g._research_time("exploit") - 0.05, "paused": false}
	step(1.0)
	check(entries("bp:exploit").size() == 1, "A learned blueprint is recorded")
	var t := own_pc(["wall", "intel"])
	g.hosts[t].sockets = ["patch"]
	step(5.5)   # the Firewall is powered by its cycle
	intrusion(9101, t, 12.0)
	check(entries("fw:%d" % t).size() == 1 and str(entries("fw:%d" % t)[0].text).contains("fired Patch"), "A Firewall that fires is recorded with what is left in it")
	check(entries("intr:9101").size() == 1 and str(entries("intr:9101")[0].text).contains("Firewall's Patch"), "The stopped intrusion is recorded too")


func strip_and_history() -> void:
	fresh()
	var t := own_pc(["intel"])
	for k in 6: intrusion(9200 + k, t, 30.0)
	g.hosts[t].ddos_until = g._t + 20.0
	intrusion(9300, int(g.rig[P]), 30.0)
	step(1.0)
	var rows: Array = g._ev_strip_rows()
	check(rows.size() == g.EV_STRIP_ROWS and int(rows[0].pri) == g.EV_CRIT, "The map strip shows at most %d rows, critical first" % g.EV_STRIP_ROWS)
	g._refresh_event_strip()
	check(g.event_strip.get_child_count() == g.EV_STRIP_ROWS + 1 and str((g.event_strip.get_child(g.EV_STRIP_ROWS) as Button).text).begins_with("Event history (H)"), "Under the rows, a button opens the history")
	g._on_strip_row(0)
	check(g._inspect == int(g.rig[P]) or g.sel.has(int(g.rig[P])), "Clicking the critical row opens its host")
	g._toggle_events()
	var txt: String = g._panel_text()
	check(g._tab == "events" and txt.contains("Events") and txt.contains("(ongoing)"), "H opens the history, marking what is still going on")
	for k in 100: g._event("spam:%d" % k, g.EV_INFO, "news %d" % k)
	check(g.events.size() == g.EV_KEEP, "The history keeps the last %d entries" % g.EV_KEEP)
	g._gen()
	check(g.events.is_empty() and g.op_outcomes.is_empty() and g._ledger.is_empty(), "A new match starts with an empty history and ledger")
