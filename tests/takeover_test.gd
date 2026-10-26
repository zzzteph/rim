extends SceneTree
## Takeover price, breach, Intel upkeep, connection drain, cards against big armies, sight by reach, map shapes.
## godot --headless --path . --script tests/takeover_test.gd
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


func fresh(shape := "grid") -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7; g._opt_shape = shape
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._open_menu(false)
	g.panel_box = null
	P = g.PLAYER; R = g.RIVAL


func quiet_income() -> void:   # no Intel / Credentials / Research income: only what a check grants
	for h in g.hosts.size():
		if int(g.hosts[h].owner) == P: g._set_builds(h, [])
	g.hosts[int(g.rig[P])].prod_off = 100000.0


func pair() -> Array:   # [your source, a neutral neighbour]
	var s: int = int(g.rig[P])
	for o in g.hosts[s].links:
		if int(g.hosts[int(o)].owner) == g.NEUTRAL and not g.hosts[int(o)].hub: return [s, int(o)]
	return []


func step(secs: float) -> int:   # run the real simulation; count the player's bot departures
	var sent := 0
	for k in int(round(secs / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		for fl in g.flights:
			if str(fl.kind) == "bot" and int(fl.owner) == P and not fl.has("_seen"): fl["_seen"] = true; sent += 1
	return sent


func run() -> void:
	breach_and_takeover()
	price()
	upkeep_and_drain()
	cards_vs_blobs()
	sight_and_shapes()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func breach_and_takeover() -> void:
	fresh(); quiet_income()
	var pr := pair(); var s: int = pr[0]; var t: int = pr[1]
	g.hosts[s].bots = 30.0; g.hosts[t].bots = 5.0; g._set_builds(t, [])
	g.creds[P] = 0.0; g.research[P] = 0.0; g.intel[P] = 100.0
	g._do_wire(P, [s], t); g._do_launch(P, t, "attack")
	step(12.0)
	check(int(g.hosts[t].owner) == g.NEUTRAL and g._breached_by(t) == P, "Bots only breach: at zero defenders it stays unowned until paid")
	var later := step(5.0)
	check(later == 0 and float(g.hosts[s].bots) > 20.0, "Your bots stop while it is breached (no waste)")
	check(g._src_state(s) == "breached — paying", "The source says why it waits (%s)" % g._src_state(s))
	var cost: Dictionary = g._takeover_cost(P, t)
	g.creds[P] = float(cost.creds) + 1.0; g.research[P] = float(cost.research) + 1.0
	step(0.2)
	check(int(g.hosts[t].owner) == P and is_equal_approx(float(g.creds[P]), 1.0) and is_equal_approx(float(g.research[P]), 1.0), "With Credentials + Research in hand it flips at once, and the price is paid")
	check(int(g.hosts[s].assign) == -1, "The link into a taken-over computer ends")
	# a breach ends when the owner's farm refills it, and the attack resumes
	fresh(); quiet_income()
	pr = pair(); s = pr[0]; t = pr[1]
	g.hosts[s].bots = 30.0; g.hosts[t].bots = 3.0; g._set_builds(t, ["bot"]); g.hosts[t].owner = R
	g.creds[P] = 0.0; g.research[P] = 0.0; g.intel[P] = 100.0
	g._do_wire(P, [s], t); g._do_assault(P, t, 100)   # 4 bots/s out-hits a farm's 1 bot/s
	var breached := false
	for k in int(10.0 / g.SIM_DT):
		g._sim_step(g.SIM_DT)
		if g._breached_by(t) == P: breached = true; break
	check(breached, "Fixture: the rival computer is breached")
	g._do_unassault(P, t)   # stop attacking: its farm refills it
	step(3.0)
	check(int(g.hosts[t].owner) == R and g._breached_by(t) == -1 and float(g.hosts[t].bots) > 0.5, "Unpaid, the breach ends when its farms refill it")
	# 0day takes over without the price
	fresh()
	pr = pair(); t = pr[1]
	g.creds[P] = 0.0; g.research[P] = 0.0
	g._apply_effect(P, g.CARDS["zeroday"], t, 1)
	check(int(g.hosts[t].owner) == P or str(g.hosts[t].card_result) == "capture failed", "0day takes a computer over without the Credentials + Research price")
	# a working rig trickles both, never above the limits
	fresh()
	g.creds[P] = 0.0; g.research[P] = 0.0
	step(10.0)
	check(float(g.creds[P]) > 1.5 and float(g.research[P]) > 0.5, "A working rig trickles Credentials and Research (%.1f / %.1f in 10 s)" % [float(g.creds[P]), float(g.research[P])])
	g.creds[P] = g._res_cap(P, "cred")
	step(2.0)
	check(float(g.creds[P]) <= g._res_cap(P, "cred") + 0.001, "The trickle never passes the limit")


func price() -> void:
	fresh()
	var types := {}
	for i in g.hosts.size(): types[str(g.hosts[i].type)] = i
	var pc := int(types.get("pc", -1)); var erp := int(types.get("erp", -1))
	if pc >= 0 and erp >= 0:
		check(float(g._takeover_cost(P, erp).creds) > float(g._takeover_cost(P, pc).creds), "Credentials depend on the computer: an ERP costs more than a PC")
	var r_small := float(g._takeover_cost(P, pc).research)
	for k in 10:   # grow the botnet by ten computers
		for i in g.hosts.size():
			if int(g.hosts[i].owner) == g.NEUTRAL and not g.hosts[i].hub: g.hosts[i].owner = P; break
	var r_big := float(g._takeover_cost(P, pc).research)
	check(r_big > r_small * 2.0, "Research rises with the size of your botnet (%.1f -> %.1f)" % [r_small, r_big])
	check(g._takeover_text(P, pc).contains("Credentials") and g._takeover_text(P, pc).contains("Research"), "The price reads as Credentials + Research")


func upkeep_and_drain() -> void:
	fresh(); quiet_income()
	var host := -1
	for i in g.hosts.size():
		if g._mine(i) and not g.hosts[i].rig: host = i
	g._set_builds(host, ["bot"]); g.hosts[host].bots = 0.0
	g.intel[P] = 100.0
	step(5.0)
	var grown := float(g.hosts[host].bots)
	check(grown > 3.0 and is_equal_approx(100.0 - float(g.intel[P]), grown * g.REGEN_PRICE), "Every regrown bot costs %s Intel (%.1f bots, %.2f Intel)" % [str(g.REGEN_PRICE), grown, 100.0 - float(g.intel[P])])
	g.intel[P] = 0.0; g.hosts[host].bots = 0.0
	step(3.0)
	check(float(g.hosts[host].bots) < 0.01, "With no Intel the farm stops regrowing — it never goes into debt")
	# a connection drains a little Intel
	fresh(); quiet_income()
	var pr := pair()
	g.intel[P] = 50.0
	g._do_wire(P, [pr[0]], pr[1])
	step(10.0)
	check(is_equal_approx(50.0 - float(g.intel[P]), g.LINK_INTEL * 10.0), "A connection drains %s Intel per second (%.3f in 10 s)" % [str(g.LINK_INTEL), 50.0 - float(g.intel[P])])


func cards_vs_blobs() -> void:
	fresh()
	var t := -1
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == g.NEUTRAL and not g.hosts[i].hub and (g.hosts[i].links as Array).size() >= 4: t = i; break
	g.hosts[t].owner = R
	var near := []
	for n in g.hosts[t].links:
		if not g.hosts[int(n)].rig and int(g.hosts[int(n)].owner) == g.NEUTRAL:
			g.hosts[int(n)].owner = R; g.hosts[int(n)].bots = 40.0; near.append(int(n))
	g._apply_effect(P, g.CARDS["supply"], t, 1)
	var halved := 0
	for n in near:
		if is_equal_approx(float(g.hosts[n].bots), 20.0): halved += 1
	check(halved == mini(3, near.size()), "Supply halves the bots on up to 3 of the owner's computers next to it (%d of %d)" % [halved, near.size()])
	g.hosts[t].bots = 60.0; g.hosts[t].prod_off = 0.0
	g._apply_effect(P, g.CARDS["ddos"], t, 1)
	check(is_equal_approx(float(g.hosts[t].prod_off), g._card_duration(g.CARDS["ddos"], 1) * 2.0), "DDOS lasts twice as long on a 60-bot garrison")
	var small := -1
	for n in g.hosts[t].links:
		if int(g.hosts[int(n)].owner) == R: small = int(n)
	g.hosts[small].bots = 10.0; g.hosts[small].prod_off = 0.0
	g._apply_effect(P, g.CARDS["ddos"], small, 1)
	check(is_equal_approx(float(g.hosts[small].prod_off), g._card_duration(g.CARDS["ddos"], 1)), "…and its normal time on a small one")


func sight_and_shapes() -> void:
	fresh()
	var rig: int = int(g.rig[P]); var reach: float = g.LINK_REACH * g.MAP_CELL
	var near_ok := true; var far_ok := true
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == P: continue
		var close := false
		for o in g.hosts.size():
			if int(g.hosts[o].owner) == P and (g.hosts[o].pos as Vector2).distance_to(g.hosts[i].pos) <= reach: close = true
		if close and not g._in_sight(P, i): near_ok = false
		if not close and g._in_sight(P, i): far_ok = false
	check(near_ok and far_ok, "You see exactly the computers within reach of your own")
	var a := -1
	for o in g.hosts[rig].links:
		if int(g.hosts[int(o)].owner) == g.NEUTRAL: a = int(o); break
	check(a >= 0 and g._link_kind(rig, a) == "attack", "Anything within reach can be connected to")
	fresh()   # routes are hidden until you use them; then they stay drawn (roads you built)
	var home: int = int(g.rig[P]); var tgt: int = pair()[1]
	check((g._roads.get(P, {}) as Dictionary).is_empty(), "A new map draws no routes: the network is hidden")
	g._do_wire(P, [home], tgt)
	check((g._roads.get(P, {}) as Dictionary).has(g._lk(home, tgt)), "Connecting establishes the route: it is drawn from now on")
	g._do_unwire(P, home)
	check((g._roads.get(P, {}) as Dictionary).has(g._lk(home, tgt)) and not g._roads.has(R), "The road stays after the connection is gone, and only on your map")
	var probe = load("res://scripts/botnet_proto.gd").new()
	check(str(probe._opt_shape) == "spiral" and g.GALAXIES.has(str(probe._opt_shape)), "New game defaults to a galaxy (spiral), not the grid")
	probe.free()
	for shape in g.SHAPES:
		fresh(shape)
		check(g._layout == shape and g._components().size() == 1, "%s map: one connected network (%d computers)" % [shape, g.hosts.size()])
		if not g.GALAXIES.has(shape): continue
		var layout: Array = []
		for h in g.hosts: layout.append(h.pos)
		fresh(shape)
		var again: Array = []
		for h in g.hosts: again.append(h.pos)
		check(JSON.stringify(layout) == JSON.stringify(again), "%s: the same seed builds the same galaxy" % shape)
		for enemies in [1, 2, 3]:
			g._opt_enemies = enemies; g._opt_seed = 7 + enemies; g._reset()
			var centre: Vector2 = Vector2(float(g._cols - 1) * 0.5, float(g._rows - 1) * 0.5) * g.MAP_CELL
			var expect := int(round(float(g._cols * g._rows) * (1.0 - g.EMPTY_CELL)))
			var close := INF
			for i in g.hosts.size():
				for j in range(i + 1, g.hosts.size()): close = minf(close, (g.hosts[i].pos as Vector2).distance_to(g.hosts[j].pos))
			var tag := "%s, %d botnets" % [shape, g.botnets.size()]
			check(g._components().size() == 1 and g.hosts.size() >= expect - 2 and g.hosts.size() <= expect and close >= g.STAR_SPACING * g.MAP_CELL - 0.01,
				"%s: one network of %d computers (the grid has ~%d), none closer than %.2f cells" % [tag, g.hosts.size(), expect, close / g.MAP_CELL])
			var balance := Vector2.ZERO; var radii := []; var homes_ok := true
			for f in g.botnets:
				var r: int = int(g.rig[f])
				balance += (g.hosts[r].pos as Vector2) - centre; radii.append((g.hosts[r].pos as Vector2).distance_to(centre))
				var second := false
				for o in g.hosts[r].links:
					if int(g.hosts[int(o)].owner) == f and not g.hosts[int(o)].rig: second = true
				if not second: homes_ok = false
			check(homes_ok, "%s: every botnet starts with its rig and a second computer next to it" % tag)
			check(balance.length() < 0.01 * g.MAP_CELL and (shape == "elliptical" or float(radii.max()) - float(radii.min()) < 0.01 * g.MAP_CELL), "%s: the rigs sit at even angles round the centre" % tag)
			var you: Vector2 = g.hosts[int(g.rig[P])].pos
			check(you.x < centre.x and you.y < centre.y, "%s: you start top-left, as on the grid" % tag)
			var inner := INF
			for h in g.hosts: inner = minf(inner, (h.pos as Vector2).distance_to(centre))
			if shape == "ring": check(g.hub < 0 and inner > 1.5 * g.MAP_CELL, "%s: an empty middle (nearest computer %.1f cells out)" % [tag, inner / g.MAP_CELL])
			else: check(g.hub >= 0 and (g.hosts[g.hub].pos as Vector2).distance_to(centre) < 0.01 and int(g.hosts[g.hub].value) == 3, "%s: the hub is the rich core" % tag)
	for s in [4242, 4243, 4244]:
		g._mp_on = true; g._opt_shape = "grid"; g._opt_seed = s; g._apply_options(); g._mp_on = false
		check(g._layout == g.GALAXIES[s % g.GALAXIES.size()], "Multiplayer seed %d builds the %s galaxy on every screen, whatever the local menu says" % [s, g._layout])
