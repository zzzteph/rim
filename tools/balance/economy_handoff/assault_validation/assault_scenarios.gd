extends SceneTree
## Finite-assault prototype — decisive 10-host-versus-12-host scenarios (not part of the game).
##   godot --headless --path <repo> --script tools/balance/economy_handoff/assault_validation/assault_scenarios.gd -- --out results.json
## Prepared positions on Small 6x4 maps (~22 hosts: the two territories meet): AIs frozen; both sides act only through the game's command door (_apply_cmd)
## under identical rules. Territories grow by alternating breadth-first steps from each rig until side A holds 10 hosts
## and side B 12; every host is developed alike (2 farms + 1 Intel harvester, full garrison) and both banks hold 150 Intel.
## Each layout is played with A = the human seat and again with the seats swapped.
## Modes: current = streams only (the game before the prototype) · finite = assault orders, farms keep regenerating ·
##        exposure = assault orders, the source's farms rest while its order stands (ASSAULT_PAUSES_REGEN).
## Scripted responses read exact garrisons — an upper bound on what a player sees (labelled in the results).

const DT := 1.0 / 30.0
var g
var A := 1
var B := 2
var seen := {}


func _initialize() -> void: _run.call_deferred()


func _arg(flag: String, def: String) -> String:
	var a := OS.get_cmdline_user_args(); var k := a.find(flag)
	return a[k + 1] if k >= 0 and k + 1 < a.size() else def


func setup(seed: int, swap: bool, mode: String) -> Dictionary:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(6, 4); g._opt_enemies = 1; g._opt_seed = seed
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._open_menu(false)
	g.panel_box = null; g._mp_on = true   # (no single-player game-over checks: both seats are scripted)
	g.assault_pause_regen = mode == "exposure"
	A = g.RIVAL if swap else g.PLAYER
	B = g.PLAYER if swap else g.RIVAL
	for i in g.hosts.size():
		if not g.hosts[i].rig: g.hosts[i].owner = g.NEUTRAL
	var qa := [int(g.rig[A])]; var qb := [int(g.rig[B])]
	var own := {int(g.rig[A]): A, int(g.rig[B]): B}
	var na := 1; var nb := 1; var ha := 0; var hb := 0
	while na < 10 or nb < 12:
		var progressed := false
		for side in [A, B]:
			if (side == A and na >= 10) or (side == B and nb >= 12): continue
			var q: Array = qa if side == A else qb
			var head: int = ha if side == A else hb
			while head < q.size():
				var c: int = q[head]
				var took := -1
				for o in g.hosts[c].links:
					if not own.has(int(o)): took = int(o); break
				if took < 0: head += 1; continue
				own[took] = side; q.append(took); progressed = true
				if side == A: na += 1
				else: nb += 1
				break
			if side == A: ha = head
			else: hb = head
		if not progressed: break
	for i in own:
		var h: Dictionary = g.hosts[i]
		h.owner = own[i]
		h.slots = maxi(3, int(h.slots))
		g._set_builds(i, ["bot", "bot", "intel"])
		h.bots = g._cap_of(i); h.assign = -1; h.live = false; h.mode = "attack"; h.assault = {}
		h.jobs = {}; h.producer_paused = {}
	for f in [A, B]: g.intel[f] = 150.0; g.cash[f] = 0.0
	g._refresh_sight()
	var types := {}
	for i in own: types[str(g.hosts[i].type)] = int(types.get(str(g.hosts[i].type), 0)) + 1
	return {"seed": seed, "swap": swap, "mode": mode, "a_faction": A, "b_faction": B, "a_hosts": _owned(A).size(), "b_hosts": _owned(B).size(), "types": types,
		"intel_cap": [g._intel_cap(A), g._intel_cap(B)]}


func _owned(f: int) -> Array:
	var out := []
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == f: out.append(i)
	return out


func _adj_owned(i: int, f: int) -> Array:
	var out := []
	for o in g.hosts[i].links:
		if int(g.hosts[int(o)].owner) == f: out.append(int(o))
	return out


func objective() -> int:   # B's frontier host that the most A hosts touch (ties: lower index)
	var best := -1; var bn := 0
	for i in _owned(B):
		if g.hosts[i].rig: continue
		var n := _adj_owned(i, A).size()
		if n > bn: bn = n; best = i
	return best


func funnel_objective() -> Array:   # [X, M]: a B host that exactly ONE A host M touches, M itself fed by ≥2 other A hosts
	for i in _owned(B):
		if g.hosts[i].rig: continue
		var adj := _adj_owned(i, A)
		if adj.size() != 1: continue
		var m: int = adj[0]
		if bool(g.hosts[m].get("junction", false)) or bool(g.hosts[i].get("junction", false)): continue
		var feeders := 0
		for o in _adj_owned(m, A):
			if not g.hosts[int(o)].links.has(i): feeders += 1
		if feeders >= 2: return [i, m]
	return []


func sources_for(x: int, side: int, n: int, exclude := []) -> Array:   # nearest own hosts with a route to x
	var cand := []
	for i in _owned(side):
		if exclude.has(i): continue
		var rt: Array = g._route(i, x)
		if not rt.is_empty(): cand.append([rt.size(), -float(g.hosts[i].bots), i])
	cand.sort()
	var out := []
	for c in cand.slice(0, n): out.append(int(c[2]))
	return out


func cmd(f: int, c: Array) -> void: g._apply_cmd(f, c)


func strike(side: int, srcs: Array, x: int, mode: String, pct: int) -> void:   # the attacker's order, by mode
	cmd(side, ["wire", srcs, x])
	if mode == "current": cmd(side, ["launch", x, "attack"])
	else: cmd(side, ["assault", x, pct])


class Track:
	var sent := 0
	var intel := 0.0
	var mins := {}
	var low_secs := {}      # source -> seconds at or below half its start
	var start := {}
	var crit_secs := {}     # source -> seconds below 15 bots


func run_until(secs: float, watch: Array, side: int, stop: Callable = Callable(), events: Callable = Callable()) -> Dictionary:
	var tr := Track.new()
	for s in watch: tr.mins[s] = float(g.hosts[s].bots); tr.start[s] = float(g.hosts[s].bots); tr.low_secs[s] = 0.0; tr.crit_secs[s] = 0.0
	var t0: float = g._t
	var intel0 := float(g.intel[side])
	var cancelled := 0
	while g._t - t0 < secs:
		if events.is_valid(): events.call(g._t - t0)
		g._sim_step(DT)
		for fl in g.flights:
			if str(fl.kind) == "bot" and int(fl.owner) == side and not fl.has("_c"):
				fl["_c"] = true; tr.sent += 1
		for s in watch:
			var b := float(g.hosts[s].bots) if int(g.hosts[s].owner) == side else 0.0
			tr.mins[s] = minf(float(tr.mins[s]), b)
			if b <= float(tr.start[s]) * 0.5: tr.low_secs[s] = float(tr.low_secs[s]) + DT
			if b < 15.0: tr.crit_secs[s] = float(tr.crit_secs[s]) + DT
		if stop.is_valid() and stop.call(): break
	var mins := []; var lows := []; var crits := []
	for s in watch: mins.append(snappedf(float(tr.mins[s]), 0.1)); lows.append(snappedf(float(tr.low_secs[s]), 0.1)); crits.append(snappedf(float(tr.crit_secs[s]), 0.1))
	return {"elapsed": snappedf(g._t - t0, 0.1), "bots_sent": tr.sent, "intel_spent_approx": snappedf(maxf(0.0, intel0 - float(g.intel[side])), 0.1),
		"source_min": mins, "source_secs_at_or_below_half": lows, "source_secs_below_15": crits}


# ---------------------------------------------------------------- 1. local opportunity
func s1(seed: int, swap: bool, mode: String) -> Dictionary:
	var meta := setup(seed, swap, mode)
	var x := objective()
	var srcs := sources_for(x, A, 4)
	var xbots := float(g.hosts[x].bots)
	strike(A, srcs, x, mode, 75)
	var guards := sources_for(x, B, 2, [x])
	var react := {"done": false}
	var r := run_until(120.0, srcs, A, func(): return int(g.hosts[x].owner) == A,
		func(el):   # B notices late (8 s) and wires two guards
			if not react.done and el >= 8.0:
				react.done = true
				for gd in guards: cmd(B, ["wire", [gd], x]))
	meta.merge({"scenario": "local_opportunity", "objective": x, "objective_type": str(g.hosts[x].type), "objective_bots": xbots, "sources": srcs,
		"b_guards_after_8s": guards, "captured": int(g.hosts[x].owner) == A,
		"capture_s": r.elapsed if int(g.hosts[x].owner) == A else null}, true)
	meta.merge(r, true)
	return meta


# ---------------------------------------------------------------- 2. counterattack on an overcommitted attacker
func s2(seed: int, swap: bool, mode: String, counter: String) -> Dictionary:
	var meta := setup(seed, swap, mode)
	var x := objective()
	g.hosts[x].slots = 3; g._set_builds(x, ["bot", "bot", "bot"]); g.hosts[x].bots = g._cap_of(x)   # a guarded stronghold: the order grinds
	for gd in sources_for(x, B, 2, [x]): cmd(B, ["wire", [gd], x])
	var srcs := sources_for(x, A, 4)
	strike(A, srcs, x, mode, 100)   # the attacker overcommits
	var st := {"origin": -1, "c_srcs": [], "captured_origin_at": -1.0, "origin_bots_at_response": -1.0}
	var r := run_until(90.0, srcs, A, func(): return st.captured_origin_at >= 0.0,
		func(el):
			if st.origin < 0 and el >= 5.0:   # B answers after 5 s: the attacking host it can reach that holds the fewest bots
				var best := -1; var bb := INF
				for s in srcs:
					if int(g.hosts[s].owner) != A: continue
					if sources_for(s, B, 1).is_empty(): continue
					if float(g.hosts[s].bots) < bb: bb = float(g.hosts[s].bots); best = s
				if best >= 0:
					st.origin = best; st.origin_bots_at_response = snappedf(bb, 0.1)
					st.c_srcs = sources_for(best, B, 3, [x])
					if not (st.c_srcs as Array).is_empty():
						cmd(B, ["wire", st.c_srcs, best])
						if counter == "assault" and mode != "current": cmd(B, ["assault", best, 75])
						else: cmd(B, ["launch", best, "attack"])
			if st.origin >= 0 and st.captured_origin_at < 0.0 and int(g.hosts[st.origin].owner) == B: st.captured_origin_at = el)
	meta.merge({"scenario": "counterattack", "counter": counter, "objective": x, "sources": srcs, "objective_taken": int(g.hosts[x].owner) == A,
		"origin": st.origin, "origin_bots_at_response": st.origin_bots_at_response, "counter_sources": st.c_srcs,
		"origin_captured_after_s": (snappedf(st.captured_origin_at - 5.0, 0.1) if st.captured_origin_at >= 0.0 else null)}, true)
	meta.merge(r, true)
	return meta


# ---------------------------------------------------------------- 3. sound defence
func s3(seed: int, swap: bool, mode: String) -> Dictionary:
	var meta := setup(seed, swap, mode)
	var x := objective()
	g.hosts[x].slots = 3; g._set_builds(x, ["bot", "bot", "bot"]); g.hosts[x].bots = g._cap_of(x)   # a stronghold: 3 farms
	var guards := sources_for(x, B, 3, [x])
	for gd in guards: cmd(B, ["wire", [gd], x])                                                 # guards wired in advance
	var srcs := sources_for(x, A, 4)
	strike(A, srcs, x, mode, 75)
	var low := {"v": float(g.hosts[x].bots)}
	var r := run_until(120.0, srcs, A, func(): return int(g.hosts[x].owner) == A,
		func(_el): low.v = minf(float(low.v), float(g.hosts[x].bots)))
	meta.merge({"scenario": "sound_defence", "objective": x, "guards": guards, "sources": srcs, "captured": int(g.hosts[x].owner) == A,
		"objective_min_bots": snappedf(float(low.v), 0.1)}, true)
	meta.merge(r, true)
	return meta


# ---------------------------------------------------------------- 4. chokepoint
func s4(seed: int, swap: bool, mode: String) -> Dictionary:
	var meta := setup(seed, swap, mode)
	var fo := funnel_objective()
	if fo.is_empty():
		meta.merge({"scenario": "chokepoint", "skipped": "no B host reachable through exactly one A host on this layout/side"}, true)
		return meta
	var x: int = fo[0]; var m: int = fo[1]
	var srcs := sources_for(x, A, 4, [m])   # everything must squeeze through m -> x
	var b0 := float(g.hosts[x].bots)
	strike(A, srcs, x, mode, 75)
	var r := run_until(90.0, srcs, A, func(): return int(g.hosts[x].owner) == A, func(_el): pass)
	meta.merge({"scenario": "chokepoint", "objective": x, "street_from": m, "sources": srcs, "captured": int(g.hosts[x].owner) == A,
		"capture_s": r.elapsed if int(g.hosts[x].owner) == A else null, "objective_bots": b0,
		"street_cap_per_s": g._link_cap(m, x), "attack_rate_offered": (srcs.size() * (g.ASSAULT_RATE if mode != "current" else g.SEND_RATE))}, true)
	meta.merge(r, true)
	return meta


# ---------------------------------------------------------------- 5. repeated assault from one source
func s5(seed: int, swap: bool, mode: String, when: String = "spent") -> Dictionary:
	var meta := setup(seed, swap, mode)
	var x := objective()
	g.hosts[x].slots = 5; g._set_builds(x, ["bot", "bot", "bot", "bot", "bot"]); g.hosts[x].bots = 5000.0   # a sponge: only the flow matters
	var srcs := sources_for(x, A, 1)
	if srcs.is_empty():
		meta.merge({"scenario": "repeated_assault", "skipped": "no A host reaches the objective"}, true)
		return meta
	var s: int = srcs[0]
	g.intel[A] = g._intel_cap(A)
	var orders := {"n": 0}
	var cap_s: float = g._cap_of(s)
	cmd(A, ["wire", [s], x])
	var r := run_until(180.0, [s], A, Callable(),
		func(_el):
			g.intel[A] = g._intel_cap(A)   # Intel is not the limit here: the source is
			if mode == "current":
				if orders.n == 0: cmd(A, ["launch", x, "attack"]); orders.n = 1
			elif g._assault_of(s).is_empty() and (when == "spent" or float(g.hosts[s].bots) >= cap_s - 0.5):
				cmd(A, ["wire", [s], x]); cmd(A, ["assault", x, 75])
				if not g._assault_of(s).is_empty(): orders.n = int(orders.n) + 1)
	meta.merge({"scenario": "repeated_assault", "reissue": when, "source": s, "source_farms": g._count(s, "bot"), "orders": orders.n, "avg_bots_per_s": snappedf(float(r.bots_sent) / 180.0, 0.01),
		"ordinary_stream_per_s": g.SEND_RATE, "source_regen": 2.0}, true)
	meta.merge(r, true)
	return meta


func _run() -> void:
	var rows := []
	for seed in [5, 11, 23]:
		for swap in [false, true]:
			for mode in ["current", "finite", "exposure"]:
				rows.append(s1(seed, swap, mode))
				rows.append(s2(seed, swap, mode, "streams"))
				if mode != "current": rows.append(s2(seed, swap, mode, "assault"))
				rows.append(s3(seed, swap, mode))
				rows.append(s4(seed, swap, mode))
				rows.append(s5(seed, swap, mode, "spent"))
				if mode != "current": rows.append(s5(seed, swap, mode, "full"))
	var out := {"rows": rows, "notes": ["AIs frozen; both sides scripted through _apply_cmd under identical rules",
		"scripted responses read exact garrisons (an upper bound on what a player could see)", "Small 6x4 maps, seeds 5/11/23, sides swapped",
		"development: every host 2 farms + 1 harvester, full garrison; 150 Intel each"]}
	var f := FileAccess.open(_arg("--out", "user://assault_scenarios.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t")); f.close()
	print("SCENARIOS_DONE %d rows" % rows.size())
	g.free()
	quit(0)
