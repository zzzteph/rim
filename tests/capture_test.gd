extends SceneTree
## Deterministic capture (Milestone A, brief §8): an eligible capture that runs its full execution always succeeds;
## a Patch, a lost route or a change of owner stops it, each with its own outcome. Covers neutral and rival hosts,
## a rival main node, route loss, two captures ending on the same step, a same-step manual Patch, and each Worm stage.
## godot --headless --path . --script tests/capture_test.gd
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


func fresh(seed := 7) -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = seed; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER; R = g.RIVAL
	for fac in [P, R]: g.bank[fac] = {"bots": 200.0, "intel": 300.0, "cash": 300.0, "creds": 300.0, "research": 300.0}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func until(cond: Callable, limit := 60.0) -> bool:   # step until cond() holds (or the limit passes)
	var steps := int(limit / g.SIM_DT)
	for k in steps:
		if cond.call(): return true
		g._sim_step(g.SIM_DT)
	return cond.call()


func outcomes_for(target: int) -> Array:
	return g.op_outcomes.filter(func(o): return int(o.target) == target).map(func(o): return str(o.outcome))


func soft_neighbour(fac: int, type := "pc") -> int:   # a neutral host linked to fac's main node, made a given type
	for nb in g.hosts[int(g.rig[fac])].links:
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL:
			g.hosts[n].type = type
			return n
	return -1


func path_avoiding(a: int, b: int, avoid: Array) -> Array:   # a shortest link path a..b through no host owned by a faction in avoid
	var prev := {a: a}; var q := [a]; var head := 0
	while head < q.size():
		var c: int = q[head]; head += 1
		if c == b: break
		for o in g.hosts[c].links:
			var n := int(o)
			if prev.has(n) or (n != b and avoid.has(int(g.hosts[n].owner))): continue
			prev[n] = c; q.append(n)
	if not prev.has(b): return []
	var p := [b]
	while int(p[-1]) != a: p.append(prev[p[-1]])
	p.reverse()
	return p


func take_path(fac: int, path: Array) -> void:   # fac captures every host on path except its ends
	for k in range(1, path.size() - 1):
		if int(g.hosts[path[k]].owner) != fac: g._capture(int(path[k]), fac)


func last_op_flight() -> Dictionary:
	for k in range(g.flights.size() - 1, -1, -1):
		if str(g.flights[k].kind) == "op": return g.flights[k]
	return {}


func run() -> void:
	neutral_on_every_seed()
	ineligible_is_refused()
	rival_host()
	rival_main_node()
	route_loss()
	same_step_competition()
	same_step_manual_patch()
	worm_stages()
	no_probability_text()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func neutral_on_every_seed() -> void:
	var exact := 0; var seeds := [3, 7, 11, 19, 23, 42]
	for seed in seeds:
		fresh(seed)
		var t := soft_neighbour(P)
		if t < 0: continue
		g.cards[P] = {"breach": 1}
		g._play_card(P, "breach", t)
		var lands := float(last_op_flight().get("arrive_t", -1.0))
		var done_at := lands + float(g.CARDS.breach.exec)
		step(done_at - g._t - 0.2)
		var before: bool = int(g.hosts[t].owner) == g.NEUTRAL
		step(0.4)
		if before and int(g.hosts[t].owner) == P and outcomes_for(t) == ["captured"]: exact += 1
	check(exact == seeds.size(), "An undefended neutral host is captured exactly after travel + %d s execution on every seed (%d of %d)" % [int(g.CARDS.breach.exec), exact, seeds.size()])


func ineligible_is_refused() -> void:
	fresh()
	var t := soft_neighbour(P, "server")
	g.cards[P] = {"breach": 1}
	var why: String = g._can_play(P, "breach", t)
	var ok: bool = g._play_card(P, "breach", t)
	check(not ok and g._held(P, "breach") == 1 and "security" in why, "Breach on a security-2 host is refused, keeps the card and says why (%s)" % why)


func rival_host() -> void:
	fresh()
	var home: int = int(g.rig[R])
	var v := -1
	for nb in g.hosts[home].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: v = int(nb); break
	g._capture(v, R); g.hosts[v].type = "pc"; g._set_builds(v, ["intel", "bot"])
	take_path(P, path_avoiding(int(g.rig[P]), v, [R]))
	g.cards[P] = {"breach": 1}
	check(g._can_play(P, "breach", v) == "", "Breach can be launched at a rival security-1 host (%s)" % g._can_play(P, "breach", v))
	g._play_card(P, "breach", v)
	check(until(func(): return int(g.hosts[v].owner) == P, 60.0), "A rival host is captured when its execution completes")
	check((g.hosts[v].builds as Array).count("") == (g.hosts[v].builds as Array).size(), "A captured rival host is wiped: no installations survive")


func rival_main_node() -> void:
	fresh()
	var home: int = int(g.rig[R])
	take_path(P, path_avoiding(int(g.rig[P]), home, [R]))
	g.cards[P] = {"zeroday": 1}; g.known[P]["zeroday"] = true
	check(g._can_play(P, "zeroday", home) == "", "0day can be launched at the rival main node (%s)" % g._can_play(P, "zeroday", home))
	g._play_card(P, "zeroday", home)
	var lands := float(last_op_flight().get("arrive_t", -1.0))
	step(lands - g._t + float(g.CARDS.zeroday.exec) + 0.5)
	check(int(g.hosts[home].owner) == R, "On an active main node 0day still runs after %d s (its main-node time is %d s)" % [int(g.CARDS.zeroday.exec), int(g.CARDS.zeroday.exec_rig)])
	step(float(g.CARDS.zeroday.exec_rig) - float(g.CARDS.zeroday.exec))
	check(int(g.hosts[home].owner) == P and g._eliminated.has(R), "After %d s the main node falls and its network is eliminated" % int(g.CARDS.zeroday.exec_rig))


func route_loss() -> void:
	fresh()
	var home: int = int(g.rig[P])
	var target := -1; var via := -1
	for i in g.hosts.size():   # a neutral host two links away whose only link to us will be one host we can lose
		if int(g.hosts[i].owner) != g.NEUTRAL or g.hosts[home].links.has(i) or bool(g.hosts[i].rig): continue
		var path := path_avoiding(home, i, [R])
		if path.size() != 3: continue
		var mine_next := 0
		for nb in g.hosts[i].links: if int(g.hosts[int(nb)].owner) == P: mine_next += 1
		if mine_next == 0: target = i; via = int(path[1]); break
	g.hosts[target].type = "pc"
	g._capture(via, P)
	g.cards[P] = {"breach": 1}
	g._play_card(P, "breach", target)
	check(until(func(): return g._execs.any(func(e): return int(e.target) == target), 20.0), "route loss: the Breach starts executing on its target")
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1   # the only way in is lost mid-execution
	step(float(g.CARDS.breach.exec) + 1.0)
	check(int(g.hosts[target].owner) == g.NEUTRAL and outcomes_for(target) == ["route_failed"] and g._held(P, "breach") == 0,
		"route loss: the capture fails with its own outcome, the host stays neutral, the card is spent (%s)" % str(outcomes_for(target)))


func same_step_competition() -> void:
	fresh()
	var t := -1; var pp := []; var rp := []
	for i in g.hosts.size():   # a neutral host both networks can reach without crossing each other
		if int(g.hosts[i].owner) != g.NEUTRAL or bool(g.hosts[i].hub): continue
		var a := path_avoiding(int(g.rig[P]), i, [R]); var b := path_avoiding(int(g.rig[R]), i, [P])
		if a.size() < 3 or b.size() < 3: continue
		var clash := false
		for k in range(1, a.size() - 1): if b.has(a[k]): clash = true
		if not clash: t = i; pp = a; rp = b; break
	g.hosts[t].type = "pc"
	take_path(P, pp); take_path(R, rp)
	check(g._op_reachable(P, t) and g._op_reachable(R, t), "same step: both networks can reach the contested host")
	var ends: float = g._t + 0.5
	g._execs.append({"id": 9002, "fac": R, "card": "breach", "effect": "capture", "target": t, "gen": int(g.hosts[t].gen), "ends": ends, "stage": 1})
	g._execs.append({"id": 9001, "fac": P, "card": "breach", "effect": "capture", "target": t, "gen": int(g.hosts[t].gen), "ends": ends, "stage": 1})
	step(1.0)
	var res := outcomes_for(t)
	check(int(g.hosts[t].owner) == P and res == ["captured", "owner_changed"],
		"same step: the earlier-launched capture wins, the other is stopped as owner-changed, never captured twice (%s)" % str(res))


func same_step_manual_patch() -> void:
	fresh()
	var h := soft_neighbour(P)
	g._capture(h, P)
	var rv := soft_neighbour(R)
	g._capture(rv, R)   # the rival needs a foothold for the exec bookkeeping; reachability is not reached
	g._execs.append({"id": 9100, "fac": R, "card": "breach", "effect": "capture", "target": h, "gen": int(g.hosts[h].gen), "ends": g._t + g.SIM_DT * 0.5, "stage": 1})
	g.cards[P] = {"patch": 1}
	g._apply_cmd(P, ["card", "patch", h])   # accepted before the step in which the intrusion would complete
	step(g.SIM_DT * 2.0)
	check(int(g.hosts[h].owner) == P and outcomes_for(h) == ["countered"], "A manual Patch applied for that step resolves before the intrusion completes (%s)" % str(outcomes_for(h)))


func worm_stages() -> void:
	fresh()
	var home: int = int(g.rig[R])
	var a := -1; var b := -1; var c := -1
	for i in g.hosts.size():   # three linked hosts in a row, none of them a main node, held by the rival
		if bool(g.hosts[i].rig) or int(g.hosts[i].owner) == P: continue
		for nb in g.hosts[i].links:
			var j := int(nb)
			if j == i or bool(g.hosts[j].rig) or int(g.hosts[j].owner) == P: continue
			for nb2 in g.hosts[j].links:
				var k := int(nb2)
				if k == i or k == j or bool(g.hosts[k].rig) or int(g.hosts[k].owner) == P or g.hosts[i].links.has(k): continue
				if path_avoiding(int(g.rig[P]), i, [R]).size() >= 2: a = i; b = j; c = k
				if a >= 0: break
			if a >= 0: break
		if a >= 0: break
	for x in [a, b, c]:
		if int(g.hosts[x].owner) != R: g._capture(x, R)
		g.hosts[x].type = "pc"
	take_path(P, path_avoiding(int(g.rig[P]), a, [R]))
	g._refresh_sight()
	g.cards[P] = {"worm": 2}; g.known[P]["worm"] = true
	check(g._can_play(P, "worm", a) == "", "worm: playable on the first rival host (%s)" % g._can_play(P, "worm", a))
	g._play_card(P, "worm", a)
	check(until(func(): return int(g.hosts[a].owner) == P, 40.0), "worm stage 1: the target is captured after its execution")
	var stage2: Array = g._execs.filter(func(e): return str(e.effect) == "worm" and int(e.stage) == 2)
	check(stage2.size() == 1 and int(stage2[0].target) == g._worm_next(P, a, R, [a]) and int(g.hosts[int(stage2[0].target)].owner) == R,
		"worm stage 2: it moves on to the nearest linked host of the same owner")
	var b2 := int(stage2[0].target) if stage2.size() == 1 else -1
	check(until(func(): return b2 >= 0 and int(g.hosts[b2].owner) == P, 20.0), "worm stage 2: the second host is captured after its own execution")
	step(float(g.CARDS.worm.exec) + 2.0)
	var worm_caps: int = g.op_outcomes.filter(func(o): return str(o.card) == "worm" and str(o.outcome) == "captured").size()
	check(worm_caps == 2 and not g._execs.any(func(e): return str(e.effect) == "worm"), "worm: it stops after %d hosts (%d captured)" % [int(g.CARDS.worm.reach), worm_caps])
	# stage 2 stopped on its own: a Patch on the second host ends the chain there
	fresh()
	for x in [a, b, c]:
		if int(g.hosts[x].owner) != R: g._capture(x, R)
		g.hosts[x].type = "pc"
	take_path(P, path_avoiding(int(g.rig[P]), a, [R]))
	g._refresh_sight()
	g.cards[P] = {"worm": 1}; g.known[P]["worm"] = true
	g._play_card(P, "worm", a)
	until(func(): return g._execs.any(func(e): return str(e.effect) == "worm" and int(e.stage) == 2), 40.0)
	var st2: Array = g._execs.filter(func(e): return str(e.effect) == "worm" and int(e.stage) == 2)
	var second := int(st2[0].target) if not st2.is_empty() else -1
	g.cards[R] = {"patch": 1}
	g._apply_cmd(R, ["card", "patch", second])
	step(float(g.CARDS.worm.exec) + 1.0)
	check(int(g.hosts[a].owner) == P and second >= 0 and int(g.hosts[second].owner) == R and outcomes_for(second) == ["countered"],
		"worm: a Patch on stage 2 stops only that stage; stage 1's capture stands")


func no_probability_text() -> void:
	var bad := []
	for k in g.CARDS:
		var text := (str(g.CARDS[k].lead) + " " + str(g.CARDS[k].rules)).to_lower()
		if "chance" in text or "%" in text or "one time in" in text or "odds" in text: bad.append(k)
	var help: Dictionary = load("res://scripts/botnet_help.gd").new().LEADS
	for k in help:
		for line in help[k]: if "odds" in str(line).to_lower() or "chance" in str(line).to_lower(): bad.append("help:" + str(k))
	check(bad.is_empty(), "No card or Help text promises odds any more (%s)" % str(bad))
