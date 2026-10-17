extends SceneTree
## The finite ASSAULT order (prototype): quotas, costs, transitions, exposure, AI use. Fixed-seed fixtures on the
## real simulation (_sim_step), AIs off unless a case says otherwise.
##   godot --headless --path . --script tests/assault_test.gd
var g
var P := 1
var R := 2
var checks := 0
var failures := []
var report := {}


func _initialize() -> void: run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func fresh(pause := true) -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._open_menu(false)
	g.panel_box = null
	g.assault_pause_regen = pause
	P = g.PLAYER; R = g.RIVAL


func own(i: int, builds: Array, bots: float, kind := "pc") -> void:
	g.hosts[i].owner = P; g.hosts[i].type = kind; g.hosts[i].slots = maxi(3, builds.size()); g._set_builds(i, builds); g.hosts[i].bots = bots
	g.hosts[i].assign = -1; g.hosts[i].live = false; g.hosts[i].mode = "attack"; g.hosts[i].assault = {}


func enemy(i: int, bots: float, builds := []) -> void:
	g.hosts[i].owner = R; g.hosts[i].type = "pc"; g.hosts[i].slots = maxi(3, builds.size()); g._set_builds(i, builds); g.hosts[i].bots = bots
	g.hosts[i].assign = -1; g.hosts[i].live = false; g.hosts[i].assault = {}


func bank(intel_amount: float) -> void:   # Intel above the base limit needs harvesters: park them on the rig
	var need := int(ceil(maxf(0.0, intel_amount - g.INTEL_CAP_BASE) / g.INTEL_CAP_PER_BUILD))
	var rig: int = int(g.rig[P])
	if need > 0:
		var kinds: Array = []
		for k in (g.hosts[rig].builds as Array):
			if str(k) != "": kinds.append(str(k))
		for k in need: kinds.append("intel")
		g.hosts[rig].slots = kinds.size(); g._set_builds(rig, kinds)
	g.intel[P] = intel_amount


var seen := {}
func step(secs: float, watch: Array = []) -> Dictionary:   # run the real simulation; count departures per watched source
	var out := {"sent": {}, "min": {}, "neg": false}
	for s in watch: out.sent[s] = 0; out.min[s] = float(g.hosts[s].bots)
	var n := int(round(secs / g.SIM_DT))
	for k in n:
		g._sim_step(g.SIM_DT)
		for fl in g.flights:
			if str(fl.kind) == "bot" and not fl.has("_seen"):
				fl["_seen"] = true
				var src := int((fl.route as Array)[0])
				if out.sent.has(src) and int(fl.owner) == P: out.sent[src] = int(out.sent[src]) + 1
		for s in watch: out.min[s] = minf(float(out.min[s]), float(g.hosts[s].bots))
		for f in g.botnets:
			if float(g.intel[f]) < -0.000001 or float(g.cash[f]) < -0.000001: out.neg = true
		for h in g.hosts:
			if float(h.bots) < -0.000001 and int(h.owner) != g.NEUTRAL: out.neg = true
	return out


func hub(n: int) -> Array:   # [host, [n non-rig neighbours]] — a non-rig host with at least n such neighbours
	for h in g.hosts.size():
		if g.hosts[h].rig: continue
		var ns := []
		for o in g.hosts[h].links:
			if not g.hosts[int(o)].rig: ns.append(int(o))
		if ns.size() >= n: return [h, ns.slice(0, n)]
	return []


func adjacent_pair() -> Array:   # [source, target]: the rig and a non-rig neighbour
	var s: int = int(g.rig[P])
	for o in g.hosts[s].links:
		if not g.hosts[int(o)].rig: return [s, int(o)]
	return []


func two_hop() -> Array:   # [source, middle, target] with target not next to the source
	for s in g.hosts.size():
		if g.hosts[s].rig: continue
		for m in g.hosts[s].links:
			if g.hosts[int(m)].rig or bool(g.hosts[int(m)].get("junction", false)): continue
			for t in g.hosts[int(m)].links:
				if int(t) != s and not g.hosts[s].links.has(t) and not g.hosts[int(t)].rig: return [s, int(m), int(t)]
	return []


func funnel() -> Array:   # [[a, b, c], m, t]: three sources whose only way to t is the one street m -> t
	for m in g.hosts.size():
		if g.hosts[m].rig or bool(g.hosts[m].get("junction", false)): continue
		for t in g.hosts[m].links:
			if bool(g.hosts[int(t)].get("junction", false)) or g.hosts[int(t)].rig: continue
			var srcs := []
			for o in g.hosts[m].links:
				if int(o) == int(t) or g.hosts[int(t)].links.has(o) or g.hosts[int(o)].rig: continue
				srcs.append(int(o))
			if srcs.size() >= 3: return [srcs.slice(0, 3), m, int(t)]
	return []


func order(s: int) -> Dictionary: return g._assault_of(s)


func run() -> void:
	quota_cases()
	intel_route_link_cases()
	transition_cases()
	exposure_cases()
	ai_cases()
	print(JSON.stringify({"checks": checks, "failures": failures, "report": report}))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/implemented_ui"))
	var f := FileAccess.open("res://review/implemented_ui/assault.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures, "report": report}, "\t")); f.close()
	g.free()
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- exact quotas
func quota_cases() -> void:
	for pause in [true, false]:
		fresh(pause)
		var pr := adjacent_pair(); var s: int = pr[0]; var t: int = pr[1]
		own(s, ["bot"], 30.0); enemy(t, 500.0); bank(100.0)
		g._do_wire(P, [s], t)
		g._do_assault(P, t, 75)
		var o := order(s)
		check(int(o.get("total", -1)) == 22 and int(o.left) == 22, "75%% of 30 bots commits exactly 22 (pause=%s)" % pause)
		var mid := step(2.0, [s])
		g._do_assault(P, t, 100)   # pressing again, even at 100 %, must not enlarge or restart it
		check(int(order(s).get("total", -1)) == 22, "Pressing Assault again adds nothing (pause=%s)" % pause)
		g.hosts[s].bots = float(g.hosts[s].bots) + 10.0   # a reinforcement lands mid-order
		var rest := step(20.0, [s])
		var total_sent := int(mid.sent[s]) + int(rest.sent[s])
		check(total_sent == 22, "Exactly the accepted quota departs: %d of 22 (pause=%s)" % [total_sent, pause])
		check(order(s).is_empty() and int(g.hosts[s].assign) == -1 and not bool(g.hosts[s].live), "A spent order ends with no wire left running (pause=%s)" % pause)
		check(not mid.neg and not rest.neg, "No negative banks or garrisons (pause=%s)" % pause)
		var before := float(g.hosts[s].bots)
		var after := step(3.0, [s])
		check(int(after.sent[s]) == 0 and (float(g.hosts[s].bots) > before or float(g.hosts[s].bots) >= g._cap_of(s) - 0.01), "After the order: nothing more leaves and the farm regenerates (pause=%s)" % pause)
	# a live stream into the target becomes the finite order; nothing keeps streaming once it is spent
	fresh()
	var pr2 := adjacent_pair(); var s2: int = pr2[0]; var t2: int = pr2[1]
	own(s2, ["bot"], 30.0); enemy(t2, 500.0); bank(100.0)
	g._do_wire(P, [s2], t2); g._do_launch(P, t2, "attack")
	step(1.0, [s2])
	var bots_now := int(floor(float(g.hosts[s2].bots)))
	g._do_assault(P, t2, 50)
	check(int(order(s2).get("total", -1)) == int(floor(0.5 * bots_now)) and str(g.hosts[s2].mode) == "assault", "Assault replaces the stream with a finite order sized from the garrison now")
	var r2 := step(20.0, [s2])
	check(order(s2).is_empty() and int(g.hosts[s2].assign) == -1 and int(r2.sent[s2]) == int(floor(0.5 * bots_now)), "The old stream does not resume after the order")
	# launch rate: 4/s, not the stream's 1/s
	fresh()
	var pr3 := adjacent_pair(); var s3: int = pr3[0]; var t3: int = pr3[1]
	own(s3, ["bot", "bot", "bot"], 90.0); enemy(t3, 500.0); bank(100.0)
	g._do_wire(P, [s3], t3); g._do_assault(P, t3, 50)
	var r3 := step(5.0, [s3])
	check(int(r3.sent[s3]) >= 18 and int(r3.sent[s3]) <= 21, "An assault source launches ~%d bots/s (%d in 5 s)" % [int(g.ASSAULT_RATE), int(r3.sent[s3])])
	report["rate_5s"] = r3.sent[s3]


# ---------------------------------------------------------------- Intel, routes, shared streets
func intel_route_link_cases() -> void:
	fresh()
	var hb := hub(1); var s: int = hb[0]; var t: int = hb[1][0]
	own(s, ["bot", "bot", "bot"], 90.0); enemy(t, 500.0)
	g.intel[P] = 0.0
	for h in g.hosts.size():   # no Intel income at all: only what the test grants
		if int(g.hosts[h].owner) == P and h != s: g._set_builds(h, [])
	g.hosts[int(g.rig[P])].prod_off = 1000.0   # the rig's own trickle stops too
	g._do_wire(P, [s], t); g._do_assault(P, t, 75)
	var q: int = int(order(s).total)
	var z := step(5.0, [s])
	check(int(z.sent[s]) == 0 and not z.neg and not order(s).is_empty(), "Zero Intel: nothing departs, no debt, the order waits")
	check(g._src_state(s) == "no Intel", "The blocker reads 'no Intel' (%s)" % g._src_state(s))
	g.intel[P] = 5.0
	var p5 := step(5.0, [s])
	check(int(p5.sent[s]) == 5 and float(g.intel[P]) >= 0.0, "Partial Intel buys exactly that many departures (%d of 5)" % int(p5.sent[s]))
	g.intel[P] = 100.0
	var burst := step(1.0, [s])
	check(int(burst.sent[s]) <= int(g.ASSAULT_RATE) + 1, "No catch-up burst after the wait (%d in the first second)" % int(burst.sent[s]))
	var finish := step(40.0, [s])
	check(5 + int(burst.sent[s]) + int(finish.sent[s]) == q, "Across the stall the total is still the quota (%d of %d)" % [5 + int(burst.sent[s]) + int(finish.sent[s]), q])
	# a cut route pauses without catch-up; the order survives
	fresh()
	var th := two_hop()
	check(th.size() == 3, "Fixture: a two-street route")
	var a: int = th[0]; var m: int = th[1]; var tt: int = th[2]
	own(a, ["bot", "bot", "bot"], 90.0); own(m, [], 30.0); enemy(tt, 500.0); bank(100.0)
	g._do_wire(P, [a], tt); g._do_assault(P, tt, 75)
	step(2.0, [a])
	g.hosts[m].route_off = 6.0
	var cut := step(5.0, [a])
	check(int(cut.sent[a]) == 0 and not order(a).is_empty() and bool(g.hosts[a].live), "A cut route pauses the order; it is not dropped")
	check(g._src_state(a) == "no route", "The blocker reads 'no route' (%s)" % g._src_state(a))
	step(1.5, [a])
	var back := step(1.0, [a])
	check(int(back.sent[a]) <= int(g.ASSAULT_RATE) + 1, "Routed again: no catch-up burst (%d in a second)" % int(back.sent[a]))
	# three sources through one ordinary street: the street admits LINK_CAP per second, not 3 x ASSAULT_RATE
	fresh()
	var fn := funnel()
	check(fn.size() == 3, "Fixture: three sources behind one street")
	if fn.size() == 3:
		var srcs: Array = fn[0]; var mid: int = fn[1]; var tgt: int = fn[2]
		for x in srcs: own(int(x), ["bot", "bot", "bot"], 90.0)
		own(mid, [], 30.0); enemy(tgt, 2000.0); bank(250.0)
		g._do_wire(P, srcs, tgt); g._do_assault(P, tgt, 75)
		var w := step(10.0, srcs)
		var total := 0
		for x in srcs: total += int(w.sent[x])
		var delivered: float = 2000.0 - float(g.hosts[tgt].bots)
		report["funnel_10s"] = {"departed": total, "landed": delivered}
		check(delivered <= 10.0 * g.LINK_CAP + 0.001 and delivered >= 8.0 * g.LINK_CAP - 8.0, "Three 4/s sources (%d departures in 10 s) land only %.0f through one %d/s street" % [total, delivered, g.LINK_CAP])


# ---------------------------------------------------------------- transitions
func transition_cases() -> void:
	# source loss voids the order
	fresh()
	var pr := adjacent_pair(); var s: int = pr[0]; var t: int = pr[1]
	var s_other := -1
	for o in g.hosts[s].links:
		if int(o) != t and not g.hosts[int(o)].rig: s_other = int(o)
	own(s, ["bot", "bot", "bot"], 90.0); enemy(t, 500.0); bank(100.0)
	g._do_wire(P, [s], t); g._do_assault(P, t, 75)
	step(2.0, [s])
	g._capture(s, R)
	var lost := step(3.0, [s])
	check((g.hosts[s].get("assault", {}) as Dictionary).is_empty() and int(lost.sent[s]) == 0, "A lost source's remaining order is void")
	# target capture: unsent departures stop; the wire does not become a guard
	fresh()
	pr = adjacent_pair(); s = pr[0]; t = pr[1]
	own(s, ["bot", "bot", "bot"], 90.0); enemy(t, 10.0); bank(100.0)
	g._do_wire(P, [s], t); g._do_assault(P, t, 75)
	var cap := step(8.0, [s])
	check(int(g.hosts[t].owner) == P, "The assault takes a weak target")
	check(int(cap.sent[s]) < 67 and order(s).is_empty() and int(g.hosts[s].assign) == -1, "Once it is ours the rest stays home (%d of 67 sent) and the wire is gone" % int(cap.sent[s]))
	g.hosts[t].hit_t = g._t; g.hosts[t].bots = 1.0
	var guard := step(2.0, [s])
	check(int(guard.sent[s]) == 0 and not bool(g.hosts[s].live), "No accidental guard: a damaged capture does not re-arm the spent order")
	# cancel: unsent stop, packets in the air land, the farms wake up
	fresh()
	pr = adjacent_pair(); s = pr[0]; t = pr[1]
	own(s, ["bot", "bot", "bot"], 90.0); enemy(t, 500.0); bank(100.0)
	g._do_wire(P, [s], t); g._do_assault(P, t, 75)
	step(3.0, [s])
	var air := 0
	for fl in g.flights:
		if int(fl.owner) == P and str(fl.kind) == "bot": air += 1
	var t_bots := float(g.hosts[t].bots)
	g._do_unassault(P, t)
	var bots_at_cancel := float(g.hosts[s].bots)
	var after := step(3.0, [s])
	check(int(after.sent[s]) == 0 and order(s).is_empty() and int(g.hosts[s].assign) == -1, "Cancel: nothing more departs and no wire is left")
	check(air > 0 and float(g.hosts[t].bots) <= t_bots - float(air) + 0.001, "Cancel: %d packets already out still land" % air)
	check(float(g.hosts[s].bots) > bots_at_cancel + 5.0, "Cancel: the source's farms regenerate again")
	# halt on the target cancels an assault too
	g._do_wire(P, [s], t); g._do_assault(P, t, 50)
	g._do_halt(P, t)
	check(order(s).is_empty() and int(g.hosts[s].assign) == -1, "Stop on the target cancels its assault")
	# re-wiring a source elsewhere replaces its order; more wires never join it
	fresh()
	var hb3 := hub(3); s = hb3[0]; t = hb3[1][0]; s_other = hb3[1][1]
	var other: int = hb3[1][2]
	own(s, ["bot", "bot", "bot"], 90.0); enemy(t, 500.0); enemy(other, 500.0); bank(100.0)
	own(s_other, ["bot"], 30.0)
	g._do_wire(P, [s], t); g._do_assault(P, t, 75)
	step(1.0, [s])
	if s_other >= 0 and g.hosts[s_other].links.has(t):
		g._do_wire(P, [s_other], t)
		check(not bool(g.hosts[s_other].live) and order(s_other).is_empty(), "A new wire into an assaulted target stays dormant: it does not join the order")
	if true:
		g._do_wire(P, [s], other)
		check(order(s).is_empty() and int(g.hosts[s].assign) == other and not bool(g.hosts[s].live), "Re-wiring the source replaces its order with a dormant wire")
	g._do_launch(P, t, "attack")
	check(order(s).is_empty(), "Launching attacks on the old target does not revive the order")
	# commands go through the door: bad input does nothing
	fresh()
	pr = adjacent_pair(); s = pr[0]; t = pr[1]
	own(s, ["bot"], 30.0); enemy(t, 500.0); bank(100.0)
	g._do_wire(P, [s], t)
	var h0: String = g._mp_hash()
	for c in [["assault", t, 33], ["assault", "x", 75], ["assault", t], ["assault", 99999, 75], ["unassault", "y"], ["assault", s, 75]]: g._apply_cmd(P, c)
	check(g._mp_hash() == h0 and order(s).is_empty(), "Malformed or self-targeted assault commands change nothing")
	g._apply_cmd(R, ["assault", t, 75])
	check(order(s).is_empty(), "A rival's command cannot order your sources")
	g._apply_cmd(P, ["assault", t, 75])
	check(not order(s).is_empty() and (g._mp_hash() != h0), "A valid command enters the state the multiplayer hash covers")


# ---------------------------------------------------------------- exposure: farmed and boosted sources
func exposure_cases() -> void:
	var rows := []
	for setup in [["ordinary 1 farm", ["bot"], "pc", 30.0, false], ["ordinary 3 farms", ["bot", "bot", "bot"], "pc", 90.0, false],
			["ERP 5 farms", ["bot", "bot", "bot", "bot", "bot"], "erp", 150.0, false], ["3 farms + CDN", ["bot", "bot", "bot"], "pc", 90.0, true]]:
		for pause in [false, true]:
			fresh(pause)
			var pr := adjacent_pair(); var s: int = pr[0]; var t: int = pr[1]
			own(s, setup[1], setup[3], setup[2]); enemy(t, 3000.0); bank(220.0)
			if setup[4]: g.hosts[s].boost_until = 1000.0
			g._do_wire(P, [s], t); g._do_assault(P, t, 75)
			var q: int = int(order(s).total)
			var low := float(g.hosts[s].bots); var half := 0.0; var t_low := -1.0; var t0: float = g._t; var full_again := -1.0
			for k in int(90.0 / g.SIM_DT):
				g._sim_step(g.SIM_DT)
				var b := float(g.hosts[s].bots)
				if b < low: low = b; t_low = g._t - t0
				if b <= float(setup[3]) * 0.5: half += g.SIM_DT
				if order(s).is_empty() and full_again < 0.0 and b >= float(setup[3]) - 0.5: full_again = g._t - t0
			rows.append({"source": setup[0], "pause_regen": pause, "quota": q, "start": setup[3], "min_garrison": snappedf(low, 0.1), "min_at_s": snappedf(t_low, 0.1),
				"secs_at_or_below_half": snappedf(half, 0.1), "full_again_s": snappedf(full_again, 0.1)})
	report["exposure"] = rows
	var by := {}
	for r in rows: by["%s|%s" % [r.source, r.pause_regen]] = r
	check(float(by["ordinary 3 farms|false"].min_garrison) > 60.0, "Free regeneration: a 3-farm source never drops below %d (no real exposure)" % int(by["ordinary 3 farms|false"].min_garrison))
	check(float(by["ERP 5 farms|false"].min_garrison) > 140.0 and float(by["3 farms + CDN|false"].min_garrison) > 80.0, "Free regeneration: ERP / CDN sources stay full")
	for name in ["ordinary 1 farm", "ordinary 3 farms", "ERP 5 farms", "3 farms + CDN"]:
		var r: Dictionary = by["%s|true" % name]
		check(float(r.min_garrison) <= float(r.start) - float(r.quota) + 0.5 and float(r.secs_at_or_below_half) >= 5.0, "Farms resting: %s falls to %d (quota %d) and stays at or below half for %.1f s" % [name, int(r.min_garrison), int(r.quota), float(r.secs_at_or_below_half)])
	# the pause is not a toggle to abuse: cancel → regen at once; re-issue → sized from what is home now
	fresh(true)
	var pr := adjacent_pair(); var s: int = pr[0]; var t: int = pr[1]
	own(s, ["bot", "bot", "bot"], 90.0); enemy(t, 3000.0); bank(220.0)
	g._do_wire(P, [s], t); g._do_assault(P, t, 75)
	step(5.0, [s])
	var held := float(g.hosts[s].bots)
	step(1.0, [s])
	check(float(g.hosts[s].bots) < held, "While the order stands the farms rest (bots only fall)")
	g._do_unassault(P, t)
	g._do_wire(P, [s], t); g._do_assault(P, t, 100)
	var q2: int = int(order(s).get("total", 0))
	check(q2 <= int(floor(float(g.hosts[s].bots))), "A re-issued order commits only what is home now (%d ≤ %d)" % [q2, int(floor(float(g.hosts[s].bots)))])


# ---------------------------------------------------------------- the Normal AI uses the same order
func ai_cases() -> void:
	# a fortress streams cannot take: the AI concentrates
	fresh(true)
	var A: int = R
	var pr := adjacent_pair()
	var t := -1; var srcs := []
	for m in g.hosts.size():   # an AI host with 3 neighbours it owns-to-be, next to a 4-farm target
		if g.hosts[m].rig: continue
		var ns := []
		for o in g.hosts[m].links:
			if not g.hosts[int(o)].rig: ns.append(int(o))
		if ns.size() >= 4: t = m; srcs = ns.slice(0, 3); break
	check(t >= 0, "Fixture: a target with three approaches")
	for x in srcs:
		g.hosts[x].owner = A; g.hosts[x].type = "pc"; g.hosts[x].slots = 3; g._set_builds(x, ["bot", "bot", "bot"]); g.hosts[x].bots = 90.0; g.hosts[x].assign = -1; g.hosts[x].live = false
	g.hosts[t].owner = P; g.hosts[t].type = "pc"; g.hosts[t].slots = 3; g._set_builds(t, ["bot", "bot", "bot"]); g.hosts[t].bots = 90.0
	g.scans[A][t] = {"key": "bot,bot,bot", "done": true, "progress": 1.0, "bots": 90.0, "cap": 90.0, "at": g._t}
	g.intel[A] = 100.0
	var rig_a: int = int(g.rig[A]); g.hosts[rig_a].slots = 10; g._set_builds(rig_a, ["bot", "bot", "intel", "intel", "intel", "intel", "intel", "intel", "intel", "intel"])
	g.intel[A] = 220.0
	g._refresh_sight()
	g._ai_think(A)
	var orders := 0
	for x in srcs:
		if not order(x).is_empty() and int(order(x).t) == t: orders += 1
	check(orders >= 2, "Normal AI: three streams cannot take a scanned 3-farm host, so it orders an assault (%d sources)" % orders)
	report["ai_assault_sources"] = orders
	# an assault's origin is exposed: the defender scouts it, then punishes it
	fresh(true)
	var D: int = R
	var th := two_hop()
	var a: int = th[0]; var mid: int = th[1]; var tgt: int = th[2]
	own(a, ["bot", "bot", "bot"], 90.0)
	g.hosts[mid].owner = D; g.hosts[mid].slots = 5; g._set_builds(mid, ["bot", "bot", "bot", "bot", "bot"]); g.hosts[mid].bots = 150.0
	g.hosts[tgt].owner = D; g.hosts[tgt].bots = 30.0; g._set_builds(tgt, ["bot"])
	for o in g.hosts[mid].links:   # the defender's guards next to the origin
		if int(o) != a and int(o) != tgt and not g.hosts[int(o)].rig and int(g.hosts[int(o)].owner) == g.NEUTRAL:
			g.hosts[int(o)].owner = D; g.hosts[int(o)].bots = 60.0; g._set_builds(int(o), ["bot", "bot"])
	g.intel[D] = 100.0; bank(100.0)
	g._refresh_sight()
	g._do_wire(P, [a], mid); g._do_assault(P, mid, 100)
	var scouted := false; var punished := false
	for k in int(30.0 / g.SIM_DT):
		g._sim_step(g.SIM_DT)
		if k % 15 == 0: g._ai_think(D)
		for i in g.hosts.size():
			if int(g.hosts[i].owner) == D and int(g.hosts[i].assign) == a:
				if str(g.hosts[i].mode) == "scan": scouted = true
				elif bool(g.hosts[i].live): punished = true
		if punished: break
	check(scouted, "Normal AI: under assault, it scans the assault's origin")
	check(punished or int(g.hosts[a].owner) == D, "Normal AI: it strikes the drained origin (owner now %d, bots %.0f)" % [int(g.hosts[a].owner), float(g.hosts[a].bots)])
