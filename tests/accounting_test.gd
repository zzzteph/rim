extends SceneTree
## Economic accounting (Milestone A, brief §9.2): every bank movement is recorded once, by cause; the recorded flows
## reconcile with the banks; a simple layout's measured delivery matches its cycle; starved, capped and broken-route
## cases never show fictional income; the ledger stays out of the lockstep fingerprint.
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


func run() -> void:
	reconcile()
	layout_rate()
	starved_and_capped()
	cargo_loss()
	not_hashed()
	sane_banks_with_ai()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func reconcile() -> void:   # within one ledger window, the change in every bank equals what came in minus what went out
	fresh()
	own_pc(["bot", "intel", "cash"])
	g.bank[P] = {"intel": 120.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
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


func layout_rate() -> void:   # station + harvester + Miner: its own workers deliver 1 Intel and 1 Crypto per 5-s cycle
	fresh()
	g._set_builds(int(g.rig[P]), [])
	own_pc(["bot", "intel", "cash"])
	step(45.0)   # warm-up past the 30-s window
	var cash := by("cash", "in", "delivered"); var intel := by("intel", "in", "delivered"); var trickle := by("cash", "in", "trickle")
	check(absf(cash - 12.0) <= 2.5 and absf(intel - 12.0) <= 2.5, "Measured delivery matches the layout: %.1f Crypto/min (12) and %.1f Intel/min (12)" % [cash, intel])
	check(absf(trickle - 12.0) <= 0.5, "The main-node trickle reads 12/min (%.1f)" % trickle)
	check(not bool(g._econ_rates(P, "cash").early), "After 30 s the rates are no longer an early estimate")


func starved_and_capped() -> void:
	fresh()
	g._set_builds(int(g.rig[P]), [])
	own_pc(["cash"])   # a Miner with no Intel on its host makes nothing, whatever the bank holds
	g.bank[P].intel = 140.0
	step(35.0)
	check(by("cash", "in", "delivered") == 0.0 and by("cash", "in", "production") == 0.0, "A starved remote Miner shows no Crypto income")
	g.bank[P].cash = g._cap(P, "cash")   # a full bank: the trickle cannot land
	step(31.0)
	var r: Dictionary = g._econ_rates(P, "cash")
	check(float(r["in"]) < 0.5 and float((r.lost_by as Dictionary).get("cap", 0.0)) > 10.0, "A full bank records overflow as lost to the cap, not as income (in %.1f, lost %.1f)" % [float(r["in"]), float((r.lost_by as Dictionary).get("cap", 0.0))])


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


func held_cargo() -> Array:   # main-node couriers on their way home that are held, with what they carry
	return g.flights.filter(func(f): return str(f.kind) == "courier" and int(f.owner) == P and bool(f.get("blocked", false)) and not (f.cargo as Dictionary).is_empty())


func cargo_loss() -> void:   # a broken route holds cargo where it is; it goes on when the route returns, and is lost only with its host
	fresh()
	var pair := far_pair()
	var via: int = pair[0]; var far: int = pair[1]
	g.hosts[far].store = {P: {"intel": 6.0}}
	step(2.0)   # main-node couriers are on the last link to the far host
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1   # the way home breaks behind them
	step(3.0)
	var held := held_cargo().size()
	check(held >= 1 and by("intel", "lost", "cargo") == 0.0 and g._incoming(P, "intel") >= float(held), "Cargo whose route broke waits at the far host, held, nothing lost (%d held)" % held)
	g._capture(via, P)   # the route returns
	step(8.0)
	var riding := 0.0   # cargo heading to the bank, and pickups claimed by workers on their way: exactly the room held
	for f in g.flights:
		if str(f.kind) != "courier": continue
		if int(f.dest) == int(g.rig[P]): riding += float((f.cargo as Dictionary).get("intel", 0.0))
		if (f.get("job", {}) as Dictionary).has("src") and str(f.job.res) == "intel": riding += float(f.job.amt)
	check(held_cargo().is_empty() and by("intel", "in", "delivered") > 0.0 and absf(g._incoming(P, "intel") - riding) < 0.001, "When the route returns the held cargo goes on and arrives; the bank room held is only what still rides or is claimed (%.0f)" % riding)
	g.hosts[far].store = {P: {"intel": 4.0}}
	for k in 600:   # until a worker has loaded at the far host and is about to leave it
		g._sim_step(g.SIM_DT)
		if g.flights.any(func(f): return str(f.kind) == "courier" and str(f.trip) == "back" and not (f.cargo as Dictionary).is_empty() and int(f.route[0]) == far and int(f.hop_i) == 0): break
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
