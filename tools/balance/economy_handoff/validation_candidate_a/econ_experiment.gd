extends SceneTree
## Economy candidate A — paired experiment harness (not part of the game).
## Small 6x4 map, the human seat vacated (as tests/ai_insane_test.gd does), three Normal AI botnets. Faction 2 (NYX) is
## the "policy player": it keeps the Normal AI's attack/defence/scan logic, but its construction is decided by the
## policy below (through the game's ai_build_hook probe and the ordinary build command). Factions 3 and 4 are unmodified
## Normal AIs: the two opponents. The same script runs against two project copies that differ ONLY in the two economy
## parameters (Bot farm price; Intel limit per harvester); the AI code is the current resource-aware code in both.
##   godot --headless --path <project> --script econ_experiment.gd -- --mode match --seed 7 --policy adapted --out x.json
##   godot --headless --path <project> --script econ_experiment.gd -- --mode fixtures --seed 7 --out y.json
## Policies (both avoid cards; neither builds labs or credential harvesters):
##   original : harvesters into the start slots; every capture filled with Bot farms whenever the price is free in the
##              bank; more harvesters while Intel income < 8/s. Never builds a miner.
##   adapted  : the same plan plus enough well-placed miners to fund it — a miner whenever delivered-capable Crypto
##              income is below max(1/3, 2.5 farms' Crypto per capture over the last 120 s), on the richest host with a
##              road home — and miners paused while free Crypto exceeds three farms (resumed below one and a half).
##              With an Intel-priced farm (baseline) the miner rules are off, so the two policies coincide there.
##   adapted_late : adapted, but no miner before its first capture (the starting Intel goes to attacks first).

const DT := 1.0 / 30.0
const H_INCOME := 8.0
const MAX_T := 900.0
const SAMPLE := 5.0
const PF := 2                  # the policy faction

var g
var P := PF
var policy := "adapted"
var start_hosts := {}
var owned_prev := {}
var captures := {}             # host -> {at, first_farm, all_farms}
var capture_times: Array = []
var lost_count := 0
var orders := {"rejected": 0, "farm": 0, "intel": 0, "cash": 0}
var acct := {}
var samples: Array = []
var stages := {}
var events := {}
var policy_on := true


func _initialize() -> void: _run.call_deferred()


func _arg(flag: String, def: String) -> String:
	var a := OS.get_cmdline_user_args(); var k := a.find(flag)
	return a[k + 1] if k >= 0 and k + 1 < a.size() else def


func _new_game(seed: int, seat_off := true) -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(6, 4); g._opt_enemies = 3 if seat_off else 2; g._opt_seed = seed; g._opt_ai_level = "normal"
	root.add_child(g); g.set_process(false); g._open_menu(false)
	if seat_off:   # the human seat leaves: its corner becomes ordinary rim buildings (tests/ai_insane_test.gd _game)
		g.botnets = g.ais.duplicate(); g._mp_on = true
		for i in g.hosts.size():
			if int(g.hosts[i].owner) == g.PLAYER:
				g.hosts[i].owner = g.NEUTRAL; g.hosts[i].rig = false; g.hosts[i].sec = 9.0; g.hosts[i].bots = 9.0; g._set_builds(i, ["bot"])
		g._refresh_sight()
		P = PF
		g.ai_build_hook[PF] = Callable(self, "_policy_build")
	else:
		P = g.PLAYER
	g.panel_box = null
	captures = {}; capture_times = []; samples = []; stages = {}; events = {}; lost_count = 0; policy_on = true
	acct = {"attack_intel": 0.0, "build_intel": 0.0, "build_cash": 0.0, "overflow_intel": 0.0, "crypto_produced": 0.0, "crypto_delivered": 0.0,
		"stall_cash_s": 0.0, "stall_intel_s": 0.0, "miner_toggles": 0.0, "miner_paused_s": 0.0}
	orders = {"rejected": 0, "farm": 0, "intel": 0, "cash": 0}
	start_hosts = {}; owned_prev = {}
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == P: start_hosts[i] = true; owned_prev[i] = true


func _run() -> void:
	var mode := _arg("--mode", "match")
	var seed := int(_arg("--seed", "7"))
	policy = _arg("--policy", "adapted")
	var out: Dictionary = _match(seed) if mode == "match" else _fixtures(seed)
	out["ruleset"] = {"farm_cost": g._build_cost("bot"), "intel_cap_per_harvester": g.INTEL_CAP_PER_BUILD, "version": g.GAME_VERSION}
	var f := FileAccess.open(_arg("--out", "user://econ.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t")); f.close()
	print("ECON_DONE " + _arg("--out", ""))
	g.free()
	quit(0)


# ------------------------------------------------------------------ the match
func _match(seed: int) -> Dictionary:
	_new_game(seed)
	var layout = {"hosts": g.hosts.size(), "types": {}, "policy_rig": int(g.rig[P]), "need_for_majority": g._control_need()}
	for h in g.hosts: layout.types[str(h.type)] = int(layout.types.get(str(h.type), 0)) + 1
	var next_sample = 0.0
	while not g.won and not g.lost and g._t < MAX_T and not g._eliminated.has(P) and _winner() < 0:
		_step_accounted()
		if g._t >= next_sample: next_sample = g._t + SAMPLE; _sample()
		for st in [[120.0, "early"], [300.0, "mid"], [600.0, "late"]]:
			if not stages.has(st[1]) and g._t >= float(st[0]): stages[st[1]] = _composition()
	_sample()
	var ai = {}
	for f in g.ais:
		ai[str(f)] = {"hosts": _owned(int(f)).size(), "farms": _count_kind(int(f), "bot"), "miners": _count_kind(int(f), "cash"), "harvesters": _count_kind(int(f), "intel"), "eliminated": g._eliminated.has(int(f))}
	var cap_list = []
	for h in captures:
		var c: Dictionary = captures[h]
		cap_list.append({"host": int(h), "type": str(g.hosts[int(h)].type), "value": int(g.hosts[int(h)].value), "slots": int(g.hosts[int(h)].slots), "at": c.at,
			"first_farm_after_s": (snappedf(float(c.first_farm) - float(c.at), 0.1) if float(c.first_farm) >= 0.0 else null),
			"all_farms_after_s": (snappedf(float(c.all_farms) - float(c.at), 0.1) if float(c.all_farms) >= 0.0 else null),
			"kinds_now": _kinds(int(h)) if int(g.hosts[int(h)].owner) == P else "lost"})
	var w := _winner()
	return {"mode": "match", "seed": seed, "policy": policy, "layout": layout, "winner": w, "policy_won": w == P, "end_t": snappedf(g._t, 0.1), "cause": str(g._end_cause),
		"events": events, "orders": orders, "accounting": _rounded(acct), "captures_total": capture_times.size(), "hosts_lost": lost_count,
		"captures": cap_list, "stages": stages, "ai": ai, "final": _composition(), "samples": samples}


func _winner() -> int:   # an AI-only match: whoever held the majority or is the last rig standing
	var alive := []
	for f in g.botnets:
		if not g._eliminated.has(int(f)): alive.append(int(f))
	if alive.size() == 1: return int(alive[0])
	if str(g._end_cause) == "": return -1
	for f in g.botnets:
		if str(g._end_cause).find(g.fname(int(f))) >= 0: return int(f)
	return -1


func _step_accounted() -> void:
	var t0: float = g._t
	var intel0 := float(g.intel[P]); var cap0: float = g._intel_cap(P); var rate0: float = g._intel_rate(P)
	var jobs0 := _job_debts()
	var credit0 := _credit(); var fly0 := _inflight(); var cash0 := float(g.cash[P])
	g._sim_step(DT)
	if intel0 >= cap0 - 0.0001: acct.overflow_intel += rate0 * DT   # the bank sat at its limit while income kept coming
	for fl in g.flights:   # each attack / scan bot that left cost 1 Intel (marked once)
		if int(fl.owner) == P and str(fl.kind) in ["bot", "scan"] and not fl.has("_x"):
			fl["_x"] = true; acct.attack_intel += 1.0
	var jobs1 := _job_debts()
	var cash_spent := 0.0
	for k in jobs0:
		var before: Dictionary = jobs0[k]; var after: Dictionary = jobs1.get(k, {})
		var host := int(str(k).split(":")[0])
		if after.is_empty() and int(g.hosts[host].owner) != P: continue   # lost with the host: it paid nothing more
		acct.build_intel += float(before.get("intel", 0.0)) - float(after.get("intel", 0.0))
		var dc := float(before.get("cash", 0.0)) - float(after.get("cash", 0.0))
		acct.build_cash += dc; cash_spent += dc
	for i in _owned(P):
		for job in (g.hosts[i].jobs as Dictionary).values():
			if bool(job.get("paused", false)) or str(job.phase) != "build": continue
			if str(job.get("short", "")) == "cash": acct.stall_cash_s += DT
			elif str(job.get("short", "")) == "intel": acct.stall_intel_s += DT
		for k in (g.hosts[i].builds as Array).size():
			if str(g.hosts[i].builds[k]) == "cash" and g._producer_paused(i, k): acct.miner_paused_s += DT
	var delivered := float(g.cash[P]) - cash0 + cash_spent
	acct.crypto_delivered += delivered
	acct.crypto_produced += delivered + (_credit() - credit0) + (_inflight() - fly0)
	var now := {}
	for i in _owned(P): now[i] = true
	for i in now:
		if not owned_prev.has(i): _on_capture(int(i))
	for i in owned_prev:
		if not now.has(i): lost_count += 1
	owned_prev = now
	for h in captures.keys(): _track_capture(int(h))


func _job_debts() -> Dictionary:
	var out := {}
	for i in _owned(P):
		for s in (g.hosts[i].jobs as Dictionary).keys():
			out["%d:%d" % [i, int(s)]] = (g._job_cost_left(g.hosts[i].jobs[s]) as Dictionary).duplicate()
	return out


func _credit() -> float:
	var c := 0.0
	for i in g._crypto_credit:
		if int(g.hosts[int(i)].owner) == P: c += float(g._crypto_credit[i])
	return c


func _inflight() -> float:
	var c := 0.0
	for fl in g.flights:
		if str(fl.kind) == "cash" and int(fl.owner) == P: c += float(fl.get("amount", 1.0))
	return c


func _sample() -> void:
	samples.append({"t": snappedf(g._t, 0.1), "intel": snappedf(float(g.intel[P]), 0.1), "intel_cap": g._intel_cap(P), "cash": snappedf(float(g.cash[P]), 0.1),
		"intel_rate": snappedf(g._intel_rate(P), 0.01), "crypto_gross_rate": snappedf(g._cash_rate(P), 0.01), "hosts": _owned(P).size(),
		"farms": _count_kind(P, "bot"), "harvesters": _count_kind(P, "intel"), "miners": _count_kind(P, "cash"), "jobs": _jobs_total(P),
		"stalled_jobs": _stalled(P), "attack_intel": snappedf(float(acct.attack_intel), 0.1), "build_intel": snappedf(float(acct.build_intel), 0.1),
		"build_cash": snappedf(float(acct.build_cash), 0.1), "overflow_intel": snappedf(float(acct.overflow_intel), 0.1),
		"crypto_produced": snappedf(float(acct.crypto_produced), 0.1), "crypto_delivered": snappedf(float(acct.crypto_delivered), 0.1), "ai_hosts": _ai_hosts()})


func _composition() -> Dictionary:
	return {"t": snappedf(g._t, 0.1), "hosts": _owned(P).size(), "farms": _count_kind(P, "bot"), "harvesters": _count_kind(P, "intel"), "miners": _count_kind(P, "cash"),
		"empty_slots": _empty_slots(P), "intel": snappedf(float(g.intel[P]), 0.1), "cash": snappedf(float(g.cash[P]), 0.1), "ai_hosts": _ai_hosts()}


func _ai_hosts() -> Dictionary:
	var out := {}
	for f in g.ais: out[str(f)] = _owned(int(f)).size()
	return out


func _on_capture(t: int) -> void:
	capture_times.append(g._t)
	if not events.has("first_capture"): events["first_capture"] = snappedf(g._t, 0.1)
	captures[t] = {"at": snappedf(g._t, 0.1), "first_farm": -1.0, "all_farms": -1.0}


func _track_capture(h: int) -> void:
	var c: Dictionary = captures[h]
	if int(g.hosts[h].owner) != P: return
	var farms := (g.hosts[h].builds as Array).count("bot")
	if farms > 0 and float(c.first_farm) < 0.0:
		c.first_farm = g._t
		if not events.has("first_new_farm"): events["first_new_farm"] = snappedf(g._t, 0.1)
	if farms == int(g.hosts[h].slots) and float(c.all_farms) < 0.0: c.all_farms = g._t


# ------------------------------------------------------------------ the policy: construction only (called on the AI's think)
func _policy_build(_fac: int) -> void:
	if not policy_on: return
	var farm_cash = float(g._build_cost("bot").get("cash", 0.0))
	var placed = 0
	if policy in ["adapted", "adapted_late"] and farm_cash > 0.0 and (policy == "adapted" or not capture_times.is_empty()):
		_mining_switch(farm_cash)
		var recent = 0
		for t in capture_times:
			if float(t) > g._t - 120.0: recent += 1
		var target = maxf(1.0 / 3.0, farm_cash * 2.5 * float(recent) / 120.0)
		if _crypto_capacity() < target - 0.0001 and _jobs_of_kind(P, "cash") == 0:
			var s = _best_slot("cash")
			if s.size() == 2 and _order(s, "cash"): placed += 1
	if placed < 2 and _count_kind(P, "intel") + _jobs_of_kind(P, "intel") < 3:   # the opening: harvesters into the start slots
		var s = _best_slot("intel", true)
		if s.size() == 2 and _order(s, "intel"): placed += 1
	for h in captures.keys():   # fill every capture with Bot farms whenever the price is free in the bank
		if placed >= 3: break
		var hi = int(h)
		if int(g.hosts[hi].owner) != P: continue
		var slot: int = g._free_slot(hi)
		while slot >= 0 and placed < 3 and _affordable("bot"):
			if not _order([hi, slot], "bot"): break
			placed += 1; slot = g._free_slot(hi)
	if placed < 3 and g._intel_rate(P) < H_INCOME + _crypto_capacity() and _jobs_of_kind(P, "intel") == 0:   # more Intel while short
		var s = _best_slot("intel")
		if s.size() == 2 and _order(s, "intel"): placed += 1


func _mining_switch(farm_cash: float) -> void:   # mine for the plan, not for a pile
	var free_cash = float(g.cash[P]) - _debt("cash")
	for i in _owned(P):
		for k in (g.hosts[i].builds as Array).size():
			if str(g.hosts[i].builds[k]) != "cash" or (g.hosts[i].jobs as Dictionary).has(k): continue
			var paused = g._producer_paused(i, k)
			if (free_cash > 3.0 * farm_cash and not paused) or (free_cash < 1.5 * farm_cash and paused):
				g._apply_cmd(P, ["produce", i, k]); acct.miner_toggles += 1.0


func _debt(res: String) -> float:
	var d = 0.0
	for i in _owned(P):
		for job in (g.hosts[i].jobs as Dictionary).values(): d += float((g._job_cost_left(job) as Dictionary).get(res, 0.0))
	return d


func _affordable(kind: String) -> bool:   # the bank minus what accepted jobs still owe covers the price
	var price: Dictionary = g._build_cost(kind)
	for r in price:
		if float(g._pool(P, str(r))) - _debt(str(r)) < float(price[r]) - 0.0001: return false
	return true


func _order(site: Array, kind: String) -> bool:
	if not _affordable(kind): return false
	var before = _jobs_total(P)
	g._apply_cmd(P, ["build", int(site[0]), int(site[1]), kind])
	if _jobs_total(P) > before:
		var key = "farm" if kind == "bot" else kind
		orders[key] = int(orders.get(key, 0)) + 1
		if kind == "cash" and not events.has("first_miner_order"): events["first_miner_order"] = snappedf(g._t, 0.1)
		return true
	orders.rejected += 1
	return false


func _best_slot(kind: String, start_only := false) -> Array:
	var rig = int(g.rig[P])
	var best = []; var bs = -INF
	for i in _owned(P):
		if start_only and not start_hosts.has(i): continue
		var s: int = g._free_slot(i)
		if s < 0: continue
		var sc = 0.0
		if kind == "cash":
			if i != rig and g._route(i, rig).is_empty(): continue
			sc = float(g.hosts[i].value) * g._tmult(i, "cash") - (0.5 if g._ai_borders_botnet(i) else 0.0)
		else:
			sc = g._tmult(i, "intel") + (2.0 if start_hosts.has(i) else 0.0) - (0.5 if g._ai_frontier(i) else 0.0)
		if sc > bs: bs = sc; best = [i, s]
	return best


func _crypto_capacity() -> float:   # Crypto/s from standing miners with a road home, plus miners under construction
	var rig = int(g.rig[P]); var r = 0.0
	for i in _owned(P):
		var per = float(g.hosts[i].value) * g._tmult(i, "cash") / 3.0
		var jobs: Dictionary = g.hosts[i].jobs
		for k in (g.hosts[i].builds as Array).size():
			var standing = str(g.hosts[i].builds[k]) == "cash" and not jobs.has(k)
			var coming = jobs.has(k) and str(jobs[k].kind) == "cash"
			if not (standing or coming): continue
			if i != rig and g._route(i, rig).is_empty(): continue
			r += per
	return r


# ------------------------------------------------------------------ small readers
func _owned(f: int) -> Array:
	var out := []
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == f: out.append(i)
	return out


func _count_kind(f: int, kind: String) -> int:
	var n := 0
	for i in _owned(f): n += (g.hosts[i].builds as Array).count(kind)
	return n


func _jobs_of_kind(f: int, kind: String) -> int:
	var n := 0
	for i in _owned(f):
		for job in (g.hosts[i].jobs as Dictionary).values():
			if str(job.kind) == kind: n += 1
	return n


func _jobs_total(f: int) -> int:
	var n := 0
	for i in _owned(f): n += (g.hosts[i].jobs as Dictionary).size()
	return n


func _stalled(f: int) -> int:
	var n := 0
	for i in _owned(f):
		for job in (g.hosts[i].jobs as Dictionary).values():
			if str(job.get("short", "")) != "" and not bool(job.get("paused", false)): n += 1
	return n


func _empty_slots(f: int) -> int:
	var n := 0
	for i in _owned(f): n += (g.hosts[i].builds as Array).count("")
	return n


func _kinds(h: int) -> String: return ",".join(PackedStringArray(g.hosts[h].builds))


func _rounded(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d: out[k] = snappedf(float(d[k]), 0.1)
	return out


# ------------------------------------------------------------------ decisive fixtures (economy in isolation)
func _fixtures(seed: int) -> Dictionary:
	var out := {"mode": "fixtures", "seed": seed}
	out["bootstrap_direct"] = _fx_opening(seed, "direct")
	out["bootstrap_harvester_first"] = _fx_opening(seed, "harvester_first")
	out["recovery_direct"] = _fx_recovery(seed, "direct")
	out["recovery_optimized"] = _fx_recovery(seed, "optimized")
	out["prepared_equal_bank"] = _fx_prepared(seed, "equal")
	out["prepared_full_cap"] = _fx_prepared(seed, "full_cap")
	out["interruption"] = []
	for bank in [0.0, 30.0, 100.0, 900.0]: out["interruption"].append(_fx_interrupt(seed, bank))
	out["card_alternative"] = _fx_card(seed)
	return out


func _run_until(cond: Callable, limit: float) -> float:   # simulated seconds until cond() holds, or -1
	var t0: float = g._t
	while g._t - t0 < limit:
		if cond.call(): return snappedf(g._t - t0, 0.1)
		g._sim_step(DT)
	return -1.0


func _first_free_slot() -> Array:
	for i in _owned(P):
		var s: int = g._free_slot(i)
		if s >= 0: return [i, s]
	return []


# 1. Opening: the real human seat, normal start, no grants, AIs frozen. direct = a miner at once on the best start
# slot, then the first additional farm the moment it is affordable; harvester_first = one harvester, then the miner.
# Baseline has no miner step (the farm is Intel-priced). Time from match start to the farm standing.
func _fx_opening(seed: int, plan: String) -> Dictionary:
	_new_game(seed, false); g.ai_enabled = false
	var start_farms := _count_kind(P, "bot")
	var farm_cash := float(g._build_cost("bot").get("cash", 0.0))
	var t0: float = g._t
	var log := []
	if farm_cash > 0.0:
		if plan == "harvester_first":   # one harvester first (10 Intel), then the miner once its 50 Intel is free
			var s := _best_slot("intel", true); g._apply_cmd(P, ["build", int(s[0]), int(s[1]), "intel"]); log.append(["intel", snappedf(g._t - t0, 0.1)])
		_run_until(func(): return _affordable("cash"), 300.0)
		var m := _best_slot("cash"); g._apply_cmd(P, ["build", int(m[0]), int(m[1]), "cash"]); log.append(["cash", snappedf(g._t - t0, 0.1), str(g.hosts[int(m[0])].type), int(g.hosts[int(m[0])].value)])
	var st := {"placed": false}
	var t := _run_until(func():
		if not st.placed and _affordable("bot"):
			var s := _first_free_slot()
			if s.size() == 2: g._apply_cmd(P, ["build", int(s[0]), int(s[1]), "bot"]); st.placed = true; log.append(["bot", snappedf(g._t - t0, 0.1)])
		return _count_kind(P, "bot") > start_farms, 400.0)
	return {"plan": plan, "first_additional_farm_s": snappedf(g._t - t0, 0.1) if t >= 0.0 else null, "orders": log}


# 5. Recovery: the rig alone (one farm, three empty slots), every other host gone, no miners, both banks empty.
func _fx_recovery(seed: int, plan: String) -> Dictionary:
	_new_game(seed, false); g.ai_enabled = false
	var rig := int(g.rig[P])
	for i in _owned(P):
		if i != rig: g.hosts[i].owner = g.NEUTRAL; g._set_builds(i, ["bot"])
	g.hosts[rig].slots = 4; g._set_builds(rig, ["bot"])
	g.intel[P] = 0.0; g.cash[P] = 0.0
	var start_farms := _count_kind(P, "bot")
	var t0: float = g._t
	var log := []
	var farm_cash := float(g._build_cost("bot").get("cash", 0.0))
	var st := {"stage": 0}
	var t := _run_until(func():
		if farm_cash <= 0.0:
			if st.stage == 0 and _affordable("bot"):
				var s := _first_free_slot(); g._apply_cmd(P, ["build", int(s[0]), int(s[1]), "bot"]); st.stage = 9; log.append(["bot", snappedf(g._t - t0, 0.1)])
		else:
			if plan == "optimized" and st.stage == 0 and g._can_afford_build(P, "intel"):
				var s := _first_free_slot(); g._apply_cmd(P, ["build", int(s[0]), int(s[1]), "intel"]); st.stage = 1; log.append(["intel", snappedf(g._t - t0, 0.1)])
			if plan == "direct" and st.stage == 0: st.stage = 1
			if st.stage == 1 and g._can_afford_build(P, "cash"):
				var s := _first_free_slot(); g._apply_cmd(P, ["build", int(s[0]), int(s[1]), "cash"]); st.stage = 2; log.append(["cash", snappedf(g._t - t0, 0.1)])
			if st.stage == 2 and _affordable("bot") and _count_kind(P, "cash") > 0:
				var s := _first_free_slot()
				if s.size() == 2: g._apply_cmd(P, ["build", int(s[0]), int(s[1]), "bot"]); st.stage = 3; log.append(["bot", snappedf(g._t - t0, 0.1)])
		return _count_kind(P, "bot") > start_farms, 600.0)
	return {"plan": plan, "first_farm_s": t if t >= 0.0 else null, "orders": log}


# Shared midgame — SYNTHETIC and identical in every ruleset (a played midgame diverges between rulesets, so it would
# not be comparable): the human seat, AIs frozen; the rig + the five nearest ordinary hosts are ours (rig: 2 farms +
# harvester; others: farm + harvester; the two richest of them also a miner); the next three hosts are fresh empty
# captures (9 slots). Every own host holds 30 bots. Banks are set by each fixture.
func _midgame(seed: int) -> Array:
	_new_game(seed, false); g.ai_enabled = false
	var rig := int(g.rig[P])
	var rigs := {}
	for f in g.rig: rigs[int(g.rig[f])] = true
	var order := [rig]; var seen := {rig: true}; var head := 0
	while head < order.size():
		var c: int = order[head]; head += 1
		for o in g.hosts[c].links:
			var oi := int(o)
			if not seen.has(oi) and not rigs.has(oi) and int(g.hosts[oi].owner) in [g.NEUTRAL, P]: seen[oi] = true; order.append(oi)
	for i in _owned(P):
		if i != rig: g.hosts[i].owner = g.NEUTRAL
	var core: Array = order.slice(1, 6); var fresh: Array = order.slice(6, 9)
	core.sort_custom(func(a, b): return float(g.hosts[a].value) * g._tmult(a, "cash") > float(g.hosts[b].value) * g._tmult(b, "cash") or (float(g.hosts[a].value) * g._tmult(a, "cash") == float(g.hosts[b].value) * g._tmult(b, "cash") and a < b))
	g._set_builds(rig, ["bot", "bot", "intel"]); g.hosts[rig].bots = 60.0
	for k in core.size():
		var h := int(core[k])
		g.hosts[h].owner = P; g.hosts[h].bots = 30.0
		g._set_builds(h, ["bot", "intel", "cash"] if k < 2 else ["bot", "intel"])
	for h in fresh:
		g.hosts[int(h)].owner = P; g.hosts[int(h)].slots = 3; g.hosts[int(h)].type = "pc"; g.hosts[int(h)].value = 1; g._set_builds(int(h), []); g.hosts[int(h)].bots = 30.0
	g._refresh_sight()
	g.intel[P] = 150.0; g.cash[P] = 0.0
	return fresh


func _midgame_state() -> Dictionary:
	return {"hosts": _owned(P).size(), "farms": _count_kind(P, "bot"), "harvesters": _count_kind(P, "intel"), "miners": _count_kind(P, "cash"),
		"intel": snappedf(float(g.intel[P]), 0.1), "intel_cap": g._intel_cap(P), "cash": snappedf(float(g.cash[P]), 0.1), "crypto_gross_rate": snappedf(g._cash_rate(P), 0.01), "intel_rate": snappedf(g._intel_rate(P), 0.01)}


# 2. Prepared expansion: nine empty slots on fresh captures; fill them with farms. equal = 150 Intel + 0 Crypto in
# both rulesets; full_cap = Intel at that ruleset's own limit, Crypto 0. Farms standing after 30/60/120/180 s.
func _fx_prepared(seed: int, bank: String) -> Dictionary:
	var fresh := _midgame(seed)
	var state := _midgame_state()
	g.intel[P] = 150.0 if bank == "equal" else g._intel_cap(P); g.cash[P] = 0.0
	var start := _count_kind(P, "bot")
	var t0: float = g._t
	var marks := {}
	while g._t - t0 < 180.0:
		for h in fresh:
			var s: int = g._free_slot(int(h))
			if s >= 0 and _affordable("bot"): g._apply_cmd(P, ["build", int(h), s, "bot"])
		g._sim_step(DT)
		for m in [30.0, 60.0, 120.0, 180.0]:
			if not marks.has(str(m)) and g._t - t0 >= m: marks[str(m)] = _count_kind(P, "bot") - start
	return {"bank": bank, "midgame": state, "intel_start": snappedf(float(150.0 if bank == "equal" else state.intel_cap), 0.1), "farms_standing_after_s": marks, "cash_end": snappedf(float(g.cash[P]), 0.1)}


# 3. Mining interruption: midgame, Crypto bank B, up to three farm jobs ordered on the fresh hosts whenever free
# Crypto allows; every miner paused for the first 60 s, then resumed. Farms completed in the outage and by 120 s.
func _fx_interrupt(seed: int, bank_cash: float) -> Dictionary:
	var fresh := _midgame(seed)
	var state := _midgame_state()
	g.cash[P] = bank_cash; g.intel[P] = minf(150.0, g._intel_cap(P))
	var miners := []
	for i in _owned(P):
		for k in (g.hosts[i].builds as Array).size():
			if str(g.hosts[i].builds[k]) == "cash":
				if not g._producer_paused(i, k): g._apply_cmd(P, ["produce", i, k])
				miners.append([i, k])
	var start := _count_kind(P, "bot")
	var t0: float = g._t
	var stall := 0.0; var during := -1
	while g._t - t0 < 120.0:
		if g._t - t0 >= 60.0 and during < 0:
			during = _count_kind(P, "bot") - start
			for m in miners:
				if g._producer_paused(int(m[0]), int(m[1])): g._apply_cmd(P, ["produce", int(m[0]), int(m[1])])
		if _count_kind(P, "bot") - start + _jobs_of_kind(P, "bot") < 3 and _affordable("bot"):
			for h in fresh:
				var s: int = g._free_slot(int(h))
				if s >= 0: g._apply_cmd(P, ["build", int(h), s, "bot"]); break
		g._sim_step(DT)
		for i in _owned(P):
			for job in (g.hosts[i].jobs as Dictionary).values():
				if str(job.get("short", "")) != "": stall += DT
	return {"crypto_bank": bank_cash, "midgame": state, "miners_paused": miners.size(), "farms_done_in_outage": during, "farms_done_by_120s": _count_kind(P, "bot") - start,
		"stalled_job_seconds": snappedf(stall, 0.1), "cash_end": snappedf(float(g.cash[P]), 0.1)}


# 4. Card alternative: the synthetic midgame with 150 Intel + 60 Crypto; a neutral host bordering us becomes a rival
# fortress (3 farms, 90 bots).
# card  = build a Credential harvester + Research lab from earned resources, research Supply, play it, then attack.
# farms = put the Crypto into farms on the fresh hosts instead, attack at 60 s. Same attack routine; 300 s limit.
func _fx_card(seed: int) -> Dictionary:
	var out := {}
	for path in ["card", "farms"]:
		var fresh := _midgame(seed)
		g.cash[P] = 60.0
		var target := -1
		for i in g.hosts.size():   # the first neutral host bordering us becomes a rival fortress
			if target >= 0 or int(g.hosts[i].owner) != g.NEUTRAL or g.hosts[i].rig: continue
			for l in g.hosts[i].links:
				if int(g.hosts[int(l)].owner) == P: target = i
		if target < 0:
			out[path] = {"skipped": "no neutral host borders the synthetic midgame"}
			continue
		g.hosts[target].owner = int(g.ais[0]); g.hosts[target].slots = 3; g._set_builds(target, ["bot", "bot", "bot"]); g.hosts[target].bots = g._cap_of(target)
		g._refresh_sight()
		var res := {"midgame": _midgame_state(), "target_type": str(g.hosts[target].type)}
		var t0: float = g._t
		var log := []
		var stage := 0; var next_strike := 0.0
		while g._t - t0 < 300.0 and int(g.hosts[target].owner) != P:
			var el: float = g._t - t0
			if fmod(el, 1.0) < DT:
				if path == "card":
					if stage == 0:
						for kind in ["cred", "lab"]:
							if g._kind_total(P, kind) + _jobs_of_kind(P, kind) == 0 and _affordable(kind):
								var s := _first_free_slot()
								if s.size() == 2: g._apply_cmd(P, ["build", int(s[0]), int(s[1]), kind]); log.append([kind, snappedf(el, 0.1)])
						if g._kind_total(P, "cred") > 0 and g._kind_total(P, "lab") > 0: g._apply_cmd(P, ["research", "supply:linked"]); stage = 1; log.append(["research", snappedf(el, 0.1)])
					elif stage == 1 and g._held(P, "supply:linked") > 0:
						if g._play_card(P, "supply:linked", target): stage = 2; log.append(["play", snappedf(el, 0.1)])
					elif stage == 2 and float(g.hosts[target].bots) < 15.0: stage = 3; log.append(["attack", snappedf(el, 0.1)])
				else:
					for h in fresh:
						var s: int = g._free_slot(int(h))
						if s >= 0 and _affordable("bot"): g._apply_cmd(P, ["build", int(h), s, "bot"]); log.append(["bot", snappedf(el, 0.1)])
					if stage == 0 and el >= 60.0: stage = 3; log.append(["attack", snappedf(el, 0.1)])
				if stage == 3 and el >= next_strike: _strike(target); next_strike = el + 20.0
			g._sim_step(DT)
		res["captured_after_s"] = snappedf(g._t - t0, 0.1) if int(g.hosts[target].owner) == P else null
		res["orders"] = log
		out[path] = res
	return out


func _strike(target: int) -> void:   # every own host with bots to spare and a road to target, up to 5, nearest first
	var cand := []
	for i in _owned(P):
		if float(g.hosts[i].bots) < 12.0: continue
		var rt: Array = g._route(i, target)
		if not rt.is_empty(): cand.append([rt.size(), i])
	cand.sort()
	var srcs := []
	for c in cand.slice(0, 5): srcs.append(int(c[1]))
	if srcs.is_empty(): return
	g._apply_cmd(P, ["wire", srcs, target]); g._apply_cmd(P, ["launch", target, "attack"])
