extends SceneTree
## The net forecast (0.6.17): the HUD's second line under each bank is ONE signed number a minute, the income forecast
## (tests/forecast_test.gd) less what the bank pays out in the next minute: research while it runs and is not paused (its
## price over its time, for the part of the minute it still runs), the card queue while it runs and is not paused (the price
## of each copy that starts within the minute), building (what the projects still need from the bank) and the Firewalls'
## upkeep the bank pays (the main node's, and a remote host's that its workers bring). It is checked against the next 60 s
## of play with research and a card queue running, against a network that uses nothing (net = income), each use on its
## own, short and long cards, a full bank (also one a Firewall uses while a remote host's output waits), the HUD's sign and
## colour, the tooltip and the Economy overview.
## godot --headless --path . --script tests/net_forecast_test.gd
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
	g.bank[P] = {"intel": 60.0, "cash": 30.0, "creds": 30.0, "research": 30.0}
	g.cards[P] = {}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func fc() -> Dictionary:   # the forecast as it stands now (never a cached one)
	g._fc_gen += 1
	return g._forecast(P)


func use_of(res: String, what: String) -> float: return float((fc().use.get(res, {}) as Dictionary).get(what, 0.0))
func used(res: String) -> float: return float(g._use_sum(fc().use, res))
func per_cycle() -> float: return 60.0 / g.PROD_CYCLE


func neighbours_of(i: int) -> Array:
	var out := []
	for nb in g.hosts[i].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: out.append(int(nb))
	return out


func run() -> void:
	steady()
	horizon()
	nothing_used()
	each_use()
	full_bank()
	hud_text()
	overview()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func network() -> Dictionary:   # a main node with two harvesters, a Lab and a station; a near host with two Credential harvesters
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["intel", "intel", "lab", "bot"])
	var near: int = neighbours_of(home)[0]
	g._capture(near, P); g.hosts[near].type = "pc"; g.hosts[near].slots = 3
	g._set_builds(near, ["cred", "cred", "intel"])
	return {"home": home, "near": near}


const START := {"intel": 280.0, "cash": 250.0, "creds": 230.0, "research": 190.0}   # room for two minutes of spending, none to fill up


func steady() -> void:   # research and a card queue running: the net shown now is what the bank does over the next minute
	network()
	g.known[P]["exploit"] = true
	step(30.0)   # the workers settle
	for res in g.RES: g.bank[P][res] = float(START[res])
	g._cmd(["research", "zeroday"])   # 16 Intel, 44 Crypto, 50 Research over 70 s: it runs the whole minute
	for k in 4: g._cmd(["queue", "breach"])   # 12 Intel and 12 Credentials a copy, made in 12 s: all four start within the minute
	var first: Dictionary = fc()
	var at0 := {}
	for res in g.RES: at0[res] = float(g.bank[P][res])
	step(60.0)
	var bad := []; var said := []
	for res in g.RES:
		var got: float = float(g.bank[P][res]) - float(at0[res])
		said.append("%s %.1f/%.1f" % [g.RES_NAME[res], float(first.net[res]), got])
		if absf(got - float(first.net[res])) > maxf(3.0, 0.2 * absf(float(first.net[res]))): bad.append(g.RES_NAME[res])
	check(bad.is_empty(), "Research and a card queue running: the net shown is what the bank does over the next 60 s, shown/measured: %s %s" % [", ".join(PackedStringArray(said)), str(bad)])
	var neg := true
	for res in g.RES: if float(first.net[res]) >= 0.0: neg = false
	check(neg, "...every bank they use shows a negative net though income still comes in (%s)" % str(first.net))
	var cost: Dictionary = g._research_cost("zeroday")
	var rt: float = g._research_time("zeroday")
	var q: Dictionary = g._recipe_cost("breach")
	var u: Dictionary = first.use
	check(absf(float(u.intel.research) - float(cost.intel) * 60.0 / rt) < 0.01 and absf(float(u.research.research) - float(cost.research) * 60.0 / rt) < 0.01
		and absf(float(u.intel["card queue"]) - 4.0 * float(q.intel)) < 0.01 and absf(float(u.creds["card queue"]) - 4.0 * float(q.creds)) < 0.01,
		"...research is its price over its time (%.1f Intel/min), the queue the price of the four copies that start (%.0f Intel)" % [float(u.intel.research), float(u.intel["card queue"])])
	for res in g.RES:
		if absf(float(first.net[res]) - (float(first.rate[res]) - g._use_sum(first.use, res))) > 0.001: bad.append(res)
	check(bad.is_empty(), "...and the net is the income less what is used, for every bank")


func horizon() -> void:   # the next minute: a short card counts its price once, a long queue only what starts, research what is left
	network()
	g.bank[P] = {"intel": 140.0, "cash": 140.0, "creds": 140.0, "research": 140.0}
	g._cmd(["queue", "recon"])   # 8 Intel, made in 3 s
	var rc := float(g._recipe_cost("recon").intel)
	check(absf(use_of("intel", "card queue") - rc) < 0.01, "One Recon queued: its price, %s Intel, once (not its price over its 3 s, %d a minute)" % [g._amt(use_of("intel", "card queue")), int(rc * 60.0 / g._make_time("recon"))])
	var f: Dictionary = fc()
	var at0 := float(g.bank[P].intel)
	step(60.0)
	var got := float(g.bank[P].intel) - at0
	check(absf(got - float(f.net.intel)) <= maxf(3.0, 0.2 * absf(float(f.net.intel))), "...and the net shown is what the Intel bank does in the next minute (%.1f shown, %.1f measured)" % [float(f.net.intel), got])
	g._cmd(["queue", "recon"]); step(0.5)   # it has started: paid, being made
	check(not (g.mq[P][0].paid as Dictionary).is_empty() and use_of("intel", "card queue") == 0.0, "...once it is being made (paid when it started) it takes nothing more")
	g.mq[P].clear(); g.cards[P] = {}
	g.known[P]["zeroday"] = true
	for k in 4: g._cmd(["queue", "zeroday"])   # 26 s a copy: three start within the minute (now, at 26 s and at 52 s)
	var zc := float(g._recipe_cost("zeroday").intel)
	check(absf(use_of("intel", "card queue") - 3.0 * zc) < 0.01, "Four 0days (26 s each): the three that start within the minute, %s Intel" % g._amt(use_of("intel", "card queue")))
	g.cards[P] = {"recon": g.READY_SLOTS - 1}   # room for one more ready copy: only one starts
	check(absf(use_of("intel", "card queue") - zc) < 0.01, "...with room for one more ready copy, only that one (%s Intel)" % g._amt(use_of("intel", "card queue")))
	g.mq[P].clear(); g.cards[P] = {}
	g._cmd(["research", "ddos"])
	var cost: Dictionary = g._research_cost("ddos")
	var rt: float = g._research_time("ddos")
	g.research_job[P].progress = rt - 10.0   # ten seconds left
	check(absf(use_of("cash", "research") - float(cost.cash) * 10.0 / rt) < 0.01, "Research with 10 s left: what those 10 s cost (%s Crypto), not a whole minute's" % g._amt(use_of("cash", "research")))


func nothing_used() -> void:   # nothing uses the bank: the net is the income, as the bank shows
	network()
	step(30.0)
	for res in g.RES: g.bank[P][res] = 40.0
	var f: Dictionary = fc()
	var same := true
	for res in g.RES:
		if float(f.net[res]) != float(f.rate[res]) or not (f.use[res] as Dictionary).is_empty(): same = false
	check(same, "Nothing used: each bank's net is its income (%s)" % str(f.net))
	var at0 := {}
	for res in g.RES: at0[res] = float(g.bank[P][res])
	step(120.0)
	var bad := []; var said := []
	for res in g.RES:
		var got: float = (float(g.bank[P][res]) - float(at0[res])) / 2.0
		said.append("%s %.1f/%.1f" % [g.RES_NAME[res], float(f.net[res]), got])
		if absf(got - float(f.net[res])) > 0.25 * absf(float(f.net[res])): bad.append(g.RES_NAME[res])
	check(bad.is_empty(), "...and it is what the bank gains, within 25%% over 120 s (shown/measured per minute: %s) %s" % [", ".join(PackedStringArray(said)), str(bad)])
	var hud: Array = g._hud_rate("creds")
	check(str(hud[0]) == "+%d/min" % int(round(float(f.net.creds))) and hud[1] == g.C_GOOD, "The HUD shows it with a plus sign, in green: '%s'" % str(hud[0]))


func each_use() -> void:
	var n := network()
	g.bank[P] = {"intel": 100.0, "cash": 100.0, "creds": 100.0, "research": 100.0}
	g._cmd(["research", "ddos"])
	var cost: Dictionary = g._research_cost("ddos")
	var rt: float = g._research_time("ddos")
	check(absf(use_of("cash", "research") - float(cost.cash) * minf(60.0, rt) / rt) < 0.01, "Research running: what it pays in the next minute is used (%.1f Crypto; it takes %.0f s)" % [use_of("cash", "research"), rt])
	g._cmd(["research", "ddos"])   # the same choice again pauses it
	check(bool(g.research_job[P].paused) and use_of("cash", "research") == 0.0 and used("cash") == 0.0, "...paused, it uses nothing")
	g._cmd(["cancel_research"])
	g._cmd(["queue", "patch"])
	var pc: Dictionary = g._recipe_cost("patch")
	var mt: float = g._make_time("patch")
	check(absf(use_of("intel", "card queue") - float(pc.intel)) < 0.01, "A card queue: the price of the copy that starts (%.0f Intel, made in %.0f s)" % [use_of("intel", "card queue"), mt])
	g._cmd(["queue_pause"])
	check(use_of("intel", "card queue") == 0.0, "...paused, it uses nothing")
	g._cmd(["queue_pause"])
	g.mq[P][0].paid = {}; g.mq[P][0].progress = 0.0   # (it waits to start)
	g.cards[P] = {"recon": g.READY_SLOTS}
	check(use_of("intel", "card queue") == 0.0, "...a head that cannot start while the Ready inventory is full uses nothing")
	g.cards[P] = {}; g.mq[P].clear()
	var home: int = n.home
	var far: int = neighbours_of(home)[0]
	g._capture(far, P); g.hosts[far].type = "pc"; g.hosts[far].slots = 3; g._set_builds(far, [])
	g._cmd(["build", far, 0, "cash"])   # a Crypto miner: 15 Intel, nothing delivered yet
	var bill := float(g.BUILD_KINDS.cash.cost.intel)
	check(absf(use_of("intel", "building") - bill) < 0.01 and absf(use_of("intel", "building") - float(g._build_owed(P).get("intel", 0.0))) < 0.001,
		"A project: what it still needs from the bank, %s Intel, is used within the next minute" % g._amt(use_of("intel", "building")))
	g.hosts[home].ddos_until = g._t + 60.0   # its workers cannot reach it: it holds nothing
	check(use_of("intel", "building") == 0.0, "...a project the workers cannot reach holds nothing")
	g.hosts[home].ddos_until = 0.0
	g.hosts[far].jobs = {}
	g._set_builds(home, ["intel", "intel", "lab", "bot", "wall"])
	check(absf(use_of("intel", "main node Firewalls") - float(g.BUILD_KINDS.wall.use.intel) * per_cycle()) < 0.01,
		"A Firewall on the main node: its upkeep, %s Intel/min, comes from the bank" % g._amt(use_of("intel", "main node Firewalls")))
	g._set_builds(home, ["intel", "intel", "lab", "bot"])
	g._set_builds(n.near, ["cred", "cred", "cash"])   # (0.6.16: no neighbour with spare Intel: the bank pays the upkeep)
	g._set_builds(far, ["cash", "wall"])   # a Firewall on a host that makes no Intel: the workers bring its upkeep from the bank
	step(40.0)
	var what := "Firewall at %s" % str(g.hosts[far].name)
	check(absf(use_of("intel", what) - float(g.BUILD_KINDS.wall.use.intel) * per_cycle()) < 0.01,
		"A Firewall on a host with no Intel of its own: the upkeep its workers bring, %s Intel/min, is used from the bank" % g._amt(use_of("intel", what)))
	if (g.hosts[n.near].links as Array).has(far):   # (0.6.16) a neighbour's surplus Intel no farther than the main node feeds it instead
		g._set_builds(n.near, ["cred", "cred", "intel"])
		step(40.0)
		check(use_of("intel", what) == 0.0, "...with a neighbour making spare Intel next to it, the neighbour's surplus feeds it and the bank pays nothing")
	g._set_builds(far, ["intel", "wall"])   # its own harvester feeds it: none from the bank
	check(use_of("intel", "Firewall at %s" % str(g.hosts[far].name)) == 0.0, "...one fed by its own harvester uses nothing from the bank")


func full_bank() -> void:
	var n := network()
	step(20.0)
	g.bank[P].creds = g._cap(P, "creds")
	check(str(g._hud_rate("creds")[0]) == "full" and g._hud_rate("creds")[1] == g.C_WARN, "A full bank nothing uses: 'full', as before")
	g._cmd(["queue", "breach"]); g._cmd(["queue", "breach"])
	g.bank[P].creds = g._cap(P, "creds")
	var f: Dictionary = fc()
	var hud: Array = g._hud_rate("creds")
	check(not bool(f.full.creds) and float(f.net.creds) < 0.0 and str(hud[0]) == "−%d/min" % int(round(-float(f.net.creds))) and hud[1] == g.C_BAD,
		"A full bank a card queue uses faster than it fills: it empties, the HUD shows how fast in red ('%s', income %.0f)" % [str(hud[0]), float(f.rate.creds)])
	g.mq[P].clear()
	g._set_builds(n.home, ["intel", "intel", "lab", "bot", "wall"])   # 5 Intel a minute against 15 coming in
	g.bank[P].intel = g._cap(P, "intel")
	f = fc()
	check(bool(f.full.intel) and str(g._hud_rate("intel")[0]) == "full" and float(f.rate.intel) > g._use_sum(f.use, "intel"),
		"A full bank whose income keeps up with its use stays full: 'full' (income %.0f, used %.0f)" % [float(f.rate.intel), g._use_sum(f.use, "intel")])
	# a full Intel bank whose main-node Firewall the trickle alone keeps paying: a remote host's Intel cannot get in, its
	# storage fills and its Crypto stops too, as with a full bank nothing uses (the use does not make the bank take more)
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot", "wall"])
	var near: int = neighbours_of(home)[0]
	g._capture(near, P); g.hosts[near].type = "pc"; g.hosts[near].slots = 3
	g._set_builds(near, ["intel", "intel", "cash"])
	g.bank[P] = {"intel": g._cap(P, "intel"), "cash": 20.0, "creds": 20.0, "research": 20.0}
	step(60.0)
	g.bank[P].intel = g._cap(P, "intel")
	f = fc()
	var cash0 := float(g.bank[P].cash)
	step(120.0)
	var got := (float(g.bank[P].cash) - cash0) / 2.0
	check(bool(f.full.intel) and absf(got - float(f.net.cash)) <= maxf(2.0, 0.25 * absf(float(f.net.cash))),
		"A full Intel bank its main node refills as fast as its Firewall uses it: the remote host's Intel gets in only as fast as it is used, the rest fills its storage (%.1f Crypto shown, %.1f measured)" % [float(f.net.cash), got])
	for k in 60:   # (0.6.16: workers take the room the Firewall frees before the trickle refills it, so the storage fills more slowly)
		if g._store_room(near) < 1.0 + g._cycle_gross(near): break
		step(2.0)
	g.bank[P].intel = g._cap(P, "intel")
	f = fc()
	check(str((f.limits as Dictionary).get("cash", [])).contains("storage fills"), "...and once its storage is about full, the forecast says its Crypto stops (%s)" % str((f.limits as Dictionary).get("cash", [])))


func hud_text() -> void:
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot"])
	g.hosts[home].ddos_until = g._t + 60.0   # no trickle while it is down: nothing in, nothing used
	var f: Dictionary = fc()
	var hud: Array = g._hud_rate("cash")
	check(float(f.net.cash) == 0.0 and str(hud[0]) == "0/min" and hud[1] == g.C_DIM, "Nothing in, nothing used: '0/min', dim")
	g.hosts[home].ddos_until = 0.0
	g.bank[P].intel = 100.0
	g._cmd(["queue", "patch"])
	hud = g._hud_rate("intel")
	check(str(hud[0]).begins_with("−") and hud[1] == g.C_BAD, "Using more than comes in: a minus sign, in red ('%s')" % str(hud[0]))
	var lines: Array = []
	for l in g._forecast_lines("intel"): lines.append(str(l[0]))
	var text := "\n".join(PackedStringArray(lines))
	var order := text.find("Income:") < text.find("Used per minute:") and text.find("Used per minute:") < text.find("Net:")
	check(order and text.contains("card queue") and text.contains("main node trickle") and text.contains("Net: %s per minute." % str(hud[0]).trim_suffix("/min")),
		"The tooltip lists the income by source, then each use, then the net:\n%s" % text)
	check(g._econ_tooltip("intel").contains("Used per minute:"), "...in the HUD's tooltip")
	check(not text.contains("empty in"), "...a bank the next minute does not empty gets no 'empty in' guess (a card is paid once, not every minute)")
	g.bank[P].intel = 3.0
	var soon := "\n".join(PackedStringArray(g._forecast_lines("intel").map(func(l): return str(l[0]))))
	check(soon.contains("At this rate the bank is empty in about ") and soon.contains(" s."), "...one that the next minute empties says how soon:\n%s" % soon)


func overview() -> void:   # the Economy overview (E) shows the same net as the HUD, and what is used
	network()
	g.bank[P] = {"intel": 100.0, "cash": 100.0, "creds": 100.0, "research": 100.0}
	g._cmd(["research", "ddos"]); g._cmd(["queue", "patch"]); g._cmd(["queue", "patch"])
	step(2.0)   # (the first copy has started, paid; the second starts within the minute)
	g._fc_gen += 1
	g._toggle_economy()
	var texts := []
	for c in g.panel_box.get_children():
		if c is Label: texts.append((c as Label).text)
	var all := "\n".join(PackedStringArray(texts))
	var bad := []
	for res in g.RES:
		var hud := str(g._hud_rate(res)[0])
		var head := "%s  %d / %d   %s" % [str(g.RES_NAME[res]).to_upper(), int(g._avail(P, res)), int(g._cap(P, res)), hud if hud == "full" else "net " + hud]
		if not texts.has(head): bad.append(head)
	check(bad.is_empty() and all.contains("Used per minute: research") and all.contains("card queue"),
		"The Economy overview shows each bank's net as the HUD does, and what uses it %s" % str(bad))
	var nets := 0
	for t in texts: if str(t).begins_with("Net: "): nets += 1
	check(nets == 1, "...once per bank, on its heading (no second net line under it, only the overview's opening line)")
