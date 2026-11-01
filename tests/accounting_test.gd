extends SceneTree
## Economic accounting (Milestone A, brief §9.2): every bank movement is recorded once, by cause; the recorded flows
## reconcile with the banks; a simple layout's measured delivery matches its cycle; output still waiting in a host's
## storage, a starved Firewall, a capped bank and a broken route never show fictional income or spending; the ledger
## stays out of the lockstep fingerprint. 0.6.16 (a job moves one unit from its source straight to its destination):
## material a host sends straight to a site never touches the bank's ledger; what the ledger books as delivered (per
## host) and as supply is exactly what the workers carried into and out of the bank; a bank unit a worker never
## collects goes back as returned, nothing lost; own goods are never booked as stolen; cargo diverted to the bank, or
## landing in room the trickle took, never puts a bank over its cap.
## godot --headless --path . --script tests/accounting_test.gd
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


func own_pc(kinds: Array) -> int:   # a plain PC next to the main node, yours, with these buildings
	var home: int = int(g.rig[P])
	for nb in g.hosts[home].links:
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL:
			g.hosts[n].type = "pc"; g.hosts[n].slots = 3
			g._capture(n, P)
			g._set_builds(n, kinds)
			return n
	return -1


func by(res: String, kind: String, cause: String) -> float:
	return float((g._econ_rates(P, res)[kind + "_by"] as Dictionary).get(cause, 0.0))


func led(key: String) -> float: return float(g._ledger_sums(P).get(key, 0.0))   # one ledger total ("in:delivered:intel") over the window


func linked(a: int, b: int) -> bool:
	for x in g.hosts[a].links:
		if int(x) == b: return true
	return false


func adjacent_pair() -> Array:   # [a, b]: two neutral hosts next to the main node AND to each other, made yours (plain PCs, nothing built)
	var home: int = int(g.rig[P])
	for x in g.hosts[home].links:
		var a := int(x)
		if int(g.hosts[a].owner) != g.NEUTRAL: continue
		for y in g.hosts[a].links:
			var b := int(y)
			if b == home or int(g.hosts[b].owner) != g.NEUTRAL or not linked(home, b): continue
			for i in [a, b]:
				g.hosts[i].type = "pc"; g.hosts[i].slots = 3
				g._capture(i, P); g._set_builds(i, [])
			return [a, b]
	return []


# ---- 0.6.16: every leg P's workers make, to hold the ledger against what was physically carried ----
var legs := {}   # flight id -> {wid, trip, from, to, route, cargo, bank, job, live}


func watch() -> void:   # from now on: a cleared ledger, and every new leg recorded (keep the run under LEDGER_SECS - 1)
	legs = {}
	g._ledger = {}
	track()


func track() -> void:   # after every step: new legs, where each now goes and what it carries; a leg gone from the flights has ended
	var live := {}
	for f in g.flights:
		if str(f.kind) != "courier" or int(f.owner) != P: continue
		var id := int(f.id)
		live[id] = true
		if not legs.has(id):
			var jb: Dictionary = (f.get("job", {}) as Dictionary).duplicate()
			legs[id] = {"wid": int(f.wid), "trip": str(f.trip), "from": int(f.get("src", f.route[0])) if str(f.trip) == "carry" else int(f.route[0]),
				"route": (f.route as Array).duplicate(), "bank": bool(jb.get("bank", false)), "job": jb, "live": true}
		legs[id].to = int(f.dest)   # (it may turn home)
		legs[id].cargo = (f.cargo as Dictionary).duplicate()
	for id in legs:
		if bool(legs[id].live) and not live.has(id): legs[id].live = false


func run_watched(secs: float, until := Callable()) -> void:   # step and track; stop early once until() holds
	for k in int(round(secs / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		track()
		if until.is_valid() and bool(until.call()): return


func landed(from_host: int, to_host: int, res: String) -> float:   # units of res on carry legs from -> to that have ended (-1: any)
	var n := 0.0
	for id in legs:
		var l: Dictionary = legs[id]
		if str(l.trip) != "carry" or bool(l.live): continue
		if (from_host >= 0 and int(l.from) != from_host) or (to_host >= 0 and int(l.to) != to_host): continue
		n += float((l.cargo as Dictionary).get(res, 0.0))
	return n


func bank_sent(res: String) -> float:   # units of res workers took out of the bank: carried from the main node, or claimed there by a worker still on its way
	var hub: int = int(g.rig[P])
	var n := 0.0
	for id in legs:
		var l: Dictionary = legs[id]
		if str(l.trip) == "carry" and int(l.from) == hub: n += float((l.cargo as Dictionary).get(res, 0.0))
		elif str(l.trip) == "fetch" and bool(l.live) and bool(l.bank) and str(l.job.res) == res: n += float(l.job.amt)
	return n


func ledger_vs_legs(res_list: Array) -> String:   # "" when delivered income (in all and per host) and supply spending are exactly what the workers carried
	var hub: int = int(g.rig[P])
	var bad := []
	for res in res_list:
		var per := {}; var total := 0.0
		for id in legs:
			var l: Dictionary = legs[id]
			if str(l.trip) != "carry" or bool(l.live) or int(l.to) != hub or int(l.from) == hub: continue
			var q := float((l.cargo as Dictionary).get(res, 0.0))
			per[int(l.from)] = float(per.get(int(l.from), 0.0)) + q; total += q
		if absf(led("in:delivered:" + res) - total) > 0.001: bad.append("%s delivered %s, carried in %s" % [res, g._amt(led("in:delivered:" + res)), g._amt(total)])
		for i in g.hosts.size():
			var want := float(per.get(i, 0.0))
			if absf(led("from:%d:%s" % [i, res]) - want) > 0.001: bad.append("%s from host %d %s, carried %s" % [res, i, g._amt(led("from:%d:%s" % [i, res])), g._amt(want)])
		if absf(led("out:supply:" + res) - bank_sent(res)) > 0.001: bad.append("%s supply %s, taken by workers %s" % [res, g._amt(led("out:supply:" + res)), g._amt(bank_sent(res))])
	return ", ".join(PackedStringArray(bad))


func run() -> void:
	reconcile()
	layout_rate()
	starved_and_capped()
	cargo_loss()
	not_hashed()
	direct_to_site()
	causes_match_legs()
	bank_unit_returned()
	diverted_into_full_bank()
	trickle_takes_held_room()
	own_goods_not_stolen()
	sane_banks_with_ai()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func reconcile() -> void:   # within one ledger window, the change in every bank equals what came in minus what went out
	fresh()
	own_pc(["bot", "intel", "cash"])
	var need := {}   # the three projects' bills together: twice that in the bank pays for all of them
	for bill in [g._build_cost("cred"), g._recipe_cost("breach"), g._research_cost("exploit")]:
		for r in bill: need[r] = float(need.get(r, 0.0)) + float(bill[r])
	g.bank[P] = {}
	for res in g.RES: g.bank[P][res] = minf(2.0 * float(need.get(res, 0.0)), g._cap(P, res))
	var before: Dictionary = (g.bank[P] as Dictionary).duplicate()
	g._start_job(int(g.rig[P]), "cred", 2)          # a building (the main node's free slot)
	g._cmd(["queue", "breach", 1])                 # manufacturing
	g._do_research(P, "exploit")                   # research, paid as it goes
	step(20.0)
	var sums: Dictionary = g._ledger_sums(P)
	var worst := 0.0; var worst_res := ""
	for res in g.RES:
		var got := 0.0; var gave := 0.0
		for key in sums:
			var parts := str(key).split(":")
			if parts[2] != res: continue
			if parts[0] == "in": got += float(sums[key])
			elif parts[0] == "out": gave += float(sums[key])
		var diff: float = absf((float(g.bank[P][res]) - float(before[res])) - (got - gave))
		if diff > worst: worst = diff; worst_res = res
	check(worst < 0.05, "Every bank's change equals recorded income minus spending (worst gap %.3f on %s)" % [worst, worst_res])
	check(by("creds", "out", "manufacturing") > 0.0 and by("intel", "out", "buildings") > 0.0 and by("intel", "out", "research") > 0.0,
		"Spending is split by cause: buildings, manufacturing, research")
	check(by("cash", "in", "delivered") > 0.0 and by("cash", "in", "trickle") > 0.0, "Income is split by cause: deliveries and the main-node trickle")


func one_cycle(i: int, kind: String) -> float:   # what one producer of this kind makes on host i in one cycle (rate x host type)
	return float(g.BUILD_KINDS[kind].rate) * g._tmult(i, str(g.BUILD_KINDS[kind].out))


func layout_rate() -> void:   # station + 2 harvesters + Miner, no input used (0.6.12): 2 Intel and 1 Crypto go home per PROD_CYCLE
	fresh()
	g._set_builds(int(g.rig[P]), [])
	var n := own_pc(["bot", "intel", "intel", "cash"])
	step(2.0 * g.LEDGER_SECS)   # warm-up past the ledger window
	var cash := by("cash", "in", "delivered"); var intel := by("intel", "in", "delivered"); var trickle := by("cash", "in", "trickle")
	var per_min: float = 60.0 / g.PROD_CYCLE   # cycles a minute
	var want_cash: float = one_cycle(n, "cash") * per_min; var want_intel: float = 2.0 * one_cycle(n, "intel") * per_min
	var tol: float = 0.5 * per_min   # half a unit a cycle: the 30-s window holds a whole number of landed units
	check(absf(cash - want_cash) <= tol and absf(intel - want_intel) <= tol, "Measured delivery matches the layout: %.1f Crypto/min (%s) and %.1f Intel/min (%s)" % [cash, g._amt(want_cash), intel, g._amt(want_intel)])
	check(absf(trickle - g.MAIN_INCOME * 60.0) <= 0.5, "The main-node trickle reads %.0f/min (%.1f)" % [g.MAIN_INCOME * 60.0, trickle])
	check(not bool(g._econ_rates(P, "cash").early), "After 30 s the rates are no longer an early estimate")


func starved_and_capped() -> void:
	fresh()
	g._set_builds(int(g.rig[P]), [])   # no Bot station anywhere: no worker brings this host anything or carries anything home
	var n := own_pc(["cash", "wall"])   # a Miner and a Firewall, and nothing on the host makes Intel
	var plenty: float = floorf(0.5 * g._cap(P, "intel"))   # far more Intel in the bank than any upkeep
	g.bank[P].intel = plenty
	var made := 0   # cycles the host ran
	for k in int(round((3.0 * g.PROD_CYCLE - 1.0) / g.SIM_DT)):   # at least two whole cycles, never enough to fill its storage
		var left := float(g.hosts[n].get("cyc", g.PROD_CYCLE))
		g._sim_step(g.SIM_DT)
		if float(g.hosts[n].get("cyc", g.PROD_CYCLE)) > left: made += 1   # its timer wrapped: it ran a cycle
	var stored: float = g._st_get(n, P, "cash")
	check(made >= 2 and absf(stored - made * one_cycle(n, "cash")) < 0.001 and by("cash", "in", "delivered") == 0.0 and by("cash", "in", "production") == 0.0,
		"A remote Miner makes its Crypto with no input, but none shows as income while no worker brings it home (%s waiting after %d cycles)" % [g._amt(stored), made])
	check(not bool(g.hosts[n].fw_on) and by("intel", "out", "upkeep") == 0.0 and float(g._econ_rates(P, "intel")["out"]) == 0.0 and float(g.bank[P].intel) >= plenty,
		"A remote Firewall with no Intel on its host is starved: it is off and no upkeep is booked, whatever the bank holds (bank Intel %d)" % int(g.bank[P].intel))
	g.bank[P].cash = g._cap(P, "cash")   # a full bank: the trickle cannot land
	step(float(g.LEDGER_SECS) + 1.0)   # a whole ledger window of it
	var r: Dictionary = g._econ_rates(P, "cash")
	check(float(r["in"]) < 0.5 and float((r.lost_by as Dictionary).get("cap", 0.0)) > 0.8 * g.MAIN_INCOME * 60.0, "A full bank records overflow as lost to the cap, not as income (in %.1f, lost %.1f)" % [float(r["in"]), float((r.lost_by as Dictionary).get("cap", 0.0))])


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


func held_cargo() -> Array:   # P's workers held on their way with what they carry
	return g.flights.filter(func(f): return str(f.kind) == "courier" and int(f.owner) == P and bool(f.get("blocked", false)) and not (f.cargo as Dictionary).is_empty())


func cargo_loss() -> void:   # a broken route holds cargo where it is; it goes on when the route returns, and is lost only with its host
	fresh()
	var pair := far_pair()
	var via: int = pair[0]; var far: int = pair[1]
	g.hosts[far].store = {P: {"intel": 6.0}}
	step(2.0)   # the main node's workers have reached the far host for its spare Intel (0.6.16: a fetch leg there, then a carry leg home)
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1   # the way home breaks behind them
	step(3.0)
	var held := held_cargo().size()
	var at_far := held_cargo().all(func(f): return int(f.get("at", -1)) == far)
	check(held >= 1 and at_far and by("intel", "lost", "cargo") == 0.0 and g._incoming(P, "intel") >= float(held), "Cargo whose route broke waits at the far host, held, nothing lost (%d held)" % held)
	g._capture(via, P)   # the route returns
	step(8.0)
	var riding := 0.0   # cargo heading to the bank, and pickups for the bank claimed by workers on their way: exactly the room held
	for f in g.flights:
		if str(f.kind) != "courier" or int(f.owner) != P: continue
		if int(f.dest) == int(g.rig[P]): riding += float((f.cargo as Dictionary).get("intel", 0.0))
		var jb: Dictionary = f.get("job", {})   # (0.6.16: a fetch leg's job; only one bound for the bank holds bank room)
		if jb.has("src") and str(jb.res) == "intel" and int(jb.dst) == int(g.rig[P]): riding += float(jb.amt)
	check(held_cargo().is_empty() and by("intel", "in", "delivered") > 0.0 and absf(g._incoming(P, "intel") - riding) < 0.001, "When the route returns the held cargo goes on and arrives; the bank room held is only what still rides or is claimed (%.0f)" % riding)
	g.hosts[far].store = {P: {"intel": 4.0}}
	for k in 600:   # until a worker has loaded at the far host and is about to leave it
		g._sim_step(g.SIM_DT)
		if g.flights.any(func(f): return str(f.kind) == "courier" and str(f.trip) == "carry" and not (f.cargo as Dictionary).is_empty() and int(f.route[0]) == far and int(f.hop_i) == 0): break
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1
	step(2.0)
	var waiting := held_cargo().size()
	g._capture(far, g.RIVAL)   # the host it waits in is taken
	step(1.0)
	check(waiting >= 1 and by("intel", "lost", "cargo") > 0.0 and held_cargo().is_empty(), "Cargo waiting in a host that is taken is lost, and recorded as lost (%d waiting)" % waiting)
	check(g._incoming(P, "intel") < 0.001, "Its reserved bank room is released when it is lost")


func not_hashed() -> void:
	fresh()
	step(5.0)
	var h1: String = g._mp_hash()
	g._ledger = {}
	check(g._mp_hash() == h1, "The ledger is presentation: clearing it does not change the lockstep fingerprint")


func bank_copy() -> Dictionary: return (g.bank[P] as Dictionary).duplicate()


func bank_gap(before: Dictionary) -> float:   # the worst gap between a bank's change since `before` and the ledger's income minus spending
	var sums: Dictionary = g._ledger_sums(P)
	var worst := 0.0
	for res in g.RES:
		var got := 0.0; var gave := 0.0
		for key in sums:
			var parts := str(key).split(":")
			if parts[2] != res: continue
			if parts[0] == "in": got += float(sums[key])
			elif parts[0] == "out": gave += float(sums[key])
		worst = maxf(worst, absf((float(g.bank[P][res]) - float(before[res])) - (got - gave)))
	return worst


func carried_from(src: int, res: String) -> float:   # units of res that left host src on carry legs (ended or still riding)
	var n := 0.0
	for id in legs:
		var l: Dictionary = legs[id]
		if str(l.trip) == "carry" and int(l.from) == src: n += float((l.cargo as Dictionary).get(res, 0.0))
	return n


func escrow_of(i: int, slot: int, res: String) -> float:
	var job: Dictionary = (g.hosts[i].jobs as Dictionary).get(slot, {})
	return float((job.get("escrow", {}) as Dictionary).get(res, 0.0))


func direct_to_site() -> void:   # 0.6.16: a site's material comes from a host's spare stock straight to it; the bank's ledger never sees it
	fresh()
	var hub: int = int(g.rig[P])
	g._set_builds(hub, ["", "bot", "bot"])   # (no harvester at the main node: the bank gets Intel only from the trickle; 0.6.18: two
	# stations, four workers, so the doubled bill, then the surplus, are carried inside one ledger window, as two did before)
	var pair := adjacent_pair()       # two hosts next to the main node and to each other: the straight leg needs no relay
	var src: int = pair[0]; var site: int = pair[1]
	var bill: Dictionary = g._build_cost("bot")
	var budget: float = float(g.LEDGER_SECS) - 2.0   # the whole watched run stays inside one ledger window
	g.hosts[src].store = {P: {"intel": g.STORE_CAP}}   # more spare Intel than the bill: the rest is surplus for the bank
	g.bank[P].intel = 0.0; g.bank[P].cash = float(bill.cash) + 10.0   # the Crypto can only come from the bank; the Intel is at the host
	g._start_job(site, "bot", 0)
	var before := bank_copy()
	var t0: float = g._t
	watch()
	run_watched(budget - 2.0, func(): return escrow_of(site, 0, "intel") >= float(bill.intel) - 0.0001 and escrow_of(site, 0, "cash") >= float(bill.cash) - 0.0001)
	var funded := escrow_of(site, 0, "intel") >= float(bill.intel) - 0.0001 and escrow_of(site, 0, "cash") >= float(bill.cash) - 0.0001
	var straight := landed(src, site, "intel")
	var via_hub := false   # a unit for the site that stopped at the main node (a leg from the host home while the site was short)
	for id in legs:
		var l: Dictionary = legs[id]
		if str(l.trip) == "carry" and int(l.from) == src and int(l.to) == site and (l.route as Array).has(hub): via_hub = true
	check(funded and straight >= 1.0 and not via_hub and landed(src, hub, "intel") == 0.0 and led("from:%d:intel" % src) == 0.0 and led("in:delivered:intel") == 0.0,
		"A site's material from a host's spare stock rides straight to it: %s Intel host -> site on one leg each, none via the main node, none booked at the bank (funded in %.1f s)" % [g._amt(straight), g._t - t0])
	var esc_i := escrow_of(site, 0, "intel"); var esc_c := escrow_of(site, 0, "cash")
	var src_drop: float = float(g.STORE_CAP) - g._st_get(src, P, "intel")
	var lv := ledger_vs_legs(["intel", "cash"])
	check(absf(esc_i - straight - landed(hub, site, "intel")) < 0.001 and absf(esc_c - landed(hub, site, "cash")) < 0.001 and absf(src_drop - carried_from(src, "intel")) < 0.001 and lv == "" and bank_gap(before) < 0.001,
		"...and every unit at the site is accounted for: %s Intel straight from the host (its storage fell by %s), %s Intel + %s Crypto from the bank booked once as supply (%s) %s" % [g._amt(straight), g._amt(src_drop), g._amt(landed(hub, site, "intel")), g._amt(landed(hub, site, "cash")), g._amt(led("out:supply:cash")), lv])
	run_watched(t0 + budget - g._t, func(): return g._st_get(src, P, "intel") < 0.001 and not legs.values().any(func(l): return bool(l.live) and str(l.trip) != "home"))
	var home_from_src := landed(src, hub, "intel")
	lv = ledger_vs_legs(["intel", "cash"])
	check(home_from_src >= 1.0 and absf(led("from:%d:intel" % src) - home_from_src) < 0.001 and lv == "" and bank_gap(before) < 0.001,
		"Once the site is served, the host's remaining spare Intel goes to the bank, booked as delivered from that host (%s) %s" % [g._amt(home_from_src), lv])


var fw_off_s := 0.0


func causes_match_legs() -> void:   # a busy network: the ledger's delivered income (per host) and supply spending are exactly what the workers carried
	fresh()
	var hub: int = int(g.rig[P])
	own_pc(["bot", "intel", "cash"])            # spare Intel and Crypto next to the main node
	var w := own_pc(["wall"])                   # a Firewall on a host that makes no Intel: its upkeep comes from elsewhere
	g._start_job(w, "cred", 1)                  # and a project there
	var pair := far_pair()                      # a producing host two links out
	g.hosts[pair[1]].type = "pc"; g.hosts[pair[1]].slots = 3
	g._set_builds(pair[1], ["intel", "lab"])
	g.bank[P].intel = 0.0; g.bank[P].cash = 0.0   # a short bank: the site's material and the upkeep come from the hosts too, not only the bank
	var before := bank_copy()
	watch()
	fw_off_s = 0.0
	var secs: float = float(g.LEDGER_SECS) - 2.0   # inside one ledger window
	for k in int(round(secs / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		track()
		if not bool(g.hosts[w].get("fw_on", true)): fw_off_s += g.SIM_DT
	var lv := ledger_vs_legs(g.RES)
	var moved := 0.0; var host_to_host := 0.0
	for id in legs:
		var l: Dictionary = legs[id]
		if str(l.trip) != "carry" or bool(l.live): continue
		for res in (l.cargo as Dictionary):
			moved += float(l.cargo[res])
			if int(l.from) != hub and int(l.to) != hub: host_to_host += float(l.cargo[res])
	check(lv == "" and moved >= 10.0, "%.0f s of a busy network: delivered income (in all and per host) and supply spending are exactly what the workers carried into and out of the bank (%s units carried) %s" % [secs, g._amt(moved), lv])
	var odd := 0.0
	for res in g.RES: odd += led("in:returned:" + res) + led("lost:cargo:" + res)
	check(host_to_host >= 1.0 and odd == 0.0 and bank_gap(before) < 0.001, "...%s units went host to host and are booked nowhere; nothing returned or lost; every bank reconciles" % g._amt(host_to_host))
	check(fw_off_s == 0.0 and led("out:upkeep:intel") == 0.0 and g._count_all(w, "wall") == 1, "A remote Firewall fed by workers is never off, and its upkeep is never booked as bank spending (%.1f s off)" % fw_off_s)


func bank_unit_returned() -> void:   # 0.6.16: a bank unit leaves the bank when its job starts; if its worker never collects it, it goes back
	fresh()
	g._set_builds(int(g.rig[P]), ["intel"])   # no station at the main node
	var pair := far_pair()
	var via: int = pair[0]; var far: int = pair[1]
	g.hosts[far].type = "pc"; g.hosts[far].slots = 3
	g._set_builds(far, ["bot"])       # the only workers start two links out
	var site := own_pc([])
	g._start_job(site, "intel", 0)
	g.bank[P].intel = 2.0 * float(g._build_cost("intel").intel)   # twice the bill
	var before := bank_copy()
	watch()
	var out_of_far := func() -> bool:   # every worker on its way to the bank has left the far host and is in the relay
		var fl: Array = g.flights.filter(func(f): return str(f.kind) == "courier" and int(f.owner) == P and str(f.trip) == "fetch" and bool((f.get("job", {}) as Dictionary).get("bank", false)))
		return not fl.is_empty() and fl.all(func(f): return int(f.hop_i) == 1 and int(f.route[1]) == via)
	run_watched(10.0, out_of_far)
	var taken := led("out:supply:intel")
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1   # the relay they are in is taken: they are lost there
	run_watched(1.5)
	var job: Dictionary = (g.hosts[site].jobs as Dictionary).get(0, {})
	var held := float((job.get("inbound", {}) as Dictionary).get("intel", 0.0))
	check(taken >= 1.0 and absf(led("in:returned:intel") - taken) < 0.001 and led("lost:cargo:intel") == 0.0 and held < 0.001 and bank_gap(before) < 0.001 and g._worker_counts(P).total == 0,
		"A bank unit leaves the bank when its job starts (%s booked as supply while its workers were still two links out); when they are lost before collecting it, it goes back: %s returned, nothing lost, the site's room released (%s held)" % [g._amt(taken), g._amt(led("in:returned:intel")), g._amt(held)])


var peak := -INF


func watch_peak(secs: float, res: String) -> void:   # step and track, keeping the most the bank of res stood over its cap
	for k in int(round(secs / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		track()
		peak = maxf(peak, g._avail(P, res) - g._cap(P, res))


func diverted_into_full_bank() -> void:   # 0.6.16: material riding from a host to a site that is lost turns to the bank: never over its cap
	fresh()
	var hub: int = int(g.rig[P])
	var pair := adjacent_pair()
	var src: int = pair[0]; var site: int = pair[1]
	g.hosts[src].store = {P: {"intel": 6.0}}
	g.bank[P].intel = 0.0
	g._start_job(site, "intel", 0)
	watch()
	run_watched(10.0, func(): return g.flights.any(func(f): return str(f.kind) == "courier" and int(f.owner) == P and str(f.trip) == "carry" and int(f.route[0]) == src and int(f.dest) == site and int(f.hop_i) == 0))
	var riding := 0.0
	for f in g.flights:
		if str(f.kind) == "courier" and int(f.owner) == P and str(f.trip) == "carry" and int(f.dest) == site: riding += float((f.cargo as Dictionary).get("intel", 0.0))
	g.bank[P].intel = g._cap(P, "intel")   # a full bank
	g._capture(site, g.RIVAL)              # the site is lost while its Intel is about to leave the host
	peak = -INF
	watch_peak(6.0, "intel")
	check(riding >= 1.0 and peak <= 0.001, "Material riding from a host to a site that is lost never puts a full bank over its cap (%s riding, %s turned home, bank peaked %s over its cap of %s)" % [g._amt(riding), g._amt(landed(src, hub, "intel")), g._amt(maxf(0.0, peak)), g._amt(g._cap(P, "intel"))])


func trickle_takes_held_room() -> void:   # room held in the bank for cargo on its way is that cargo's: the trickle never fills it
	fresh()
	g._set_builds(int(g.rig[P]), ["", "bot"])   # (no harvester at the main node: only the trickle adds Intel there)
	var src := own_pc([])
	g.hosts[src].store = {P: {"intel": 3.0}}
	var cap: float = g._cap(P, "intel")
	g.bank[P].intel = cap - 1.1   # room for one unit and a tenth: one worker sets off for a unit and holds its room
	watch()
	peak = -INF
	watch_peak(6.0, "intel")
	check(landed(src, int(g.rig[P]), "intel") >= 1.0 and peak <= 0.001,
		"Bank room held for cargo on its way stays held: the trickle does not fill it, so the cargo never lands over the cap (%s delivered, bank peaked %s over its cap)" % [g._amt(landed(src, int(g.rig[P]), "intel")), g._amt(maxf(0.0, peak))])


func own_goods_not_stolen() -> void:   # the cause of a delivery is where it was picked up, not who holds that host when it lands
	fresh()
	var hub: int = int(g.rig[P])
	var src := own_pc([])
	g.hosts[src].store = {P: {"intel": 3.0}}
	watch()
	run_watched(10.0, func(): return g.flights.any(func(f): return str(f.kind) == "courier" and int(f.owner) == P and str(f.trip) == "carry" and int(f.get("src", -1)) == src and int(f.hop_i) >= 1))
	g._capture(src, g.RIVAL)   # its host is taken behind it
	run_watched(4.0)
	var home := landed(src, hub, "intel")
	check(home >= 1.0 and led("in:stolen:intel") == 0.0 and absf(led("in:delivered:intel") - home) < 0.001,
		"Your own surplus whose host is taken while it rides home is booked as delivered, not stolen (%s home: delivered %s, stolen %s)" % [g._amt(home), g._amt(led("in:delivered:intel")), g._amt(led("in:stolen:intel"))])


func sane_banks_with_ai() -> void:   # a busy four-network match: no bank below zero or above its cap
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 3; g._opt_seed = 5; g._opt_shape = "spiral"
	root.add_child(g); g.set_process(false); g._camp = false; g._open_menu(false); g.ai_enabled = true
	g.humans = []; g.ais = g.botnets.duplicate()
	for fac in g.ais:
		if not g._ai.has(fac): g._ai[fac] = {"timer": 0.5 * float(fac), "dead": false}
	var bad := []
	for k in 6:
		step(20.0)
		for fac in g.botnets:
			for res in g.RES:
				var v: float = g._avail(fac, res)
				if v < -0.001 or v > g._cap(fac, res) + 0.001: bad.append("%d:%s=%.1f" % [fac, res, v])
	check(bad.is_empty(), "Two minutes of four AIs: no bank goes negative or over its cap (%s)" % str(bad.slice(0, 4)))
