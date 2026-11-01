extends SceneTree
## AI competence: with every faction AI-driven, the economic AI must research blueprints, manufacture
## cards and actually capture ground within ten minutes — not sit idle — and every AI on its own keeps developing.
## Amounts come from the game's constants. Flow and prices rescale together (0.6.18: a PROD_CYCLE of 6 s and every price
## doubled), so what a minute buys is unchanged; the pace of "ten minutes" is set by the build, make and research times,
## which a rescale keeps.
## godot --headless --path . --script tests/ai_test.gd
var g
var checks := 0
var failures := []

const HORIZON := 600.0   # ten minutes of play
const SETTLE := 60.0     # a host taken in the last minute has had no time to be built on: it does not count as ground to develop
const MIN_BUILT := 7     # 0.6.4: the AI once stopped at 4 buildings; ten minutes must take it well past that


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func owned() -> int:
	var n := 0
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != g.NEUTRAL: n += 1
	return n


func held_by(fac: int) -> Array:
	var out := []
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == fac: out.append(i)
	return out


func run() -> void:
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 3; g._opt_seed = 5; g._opt_shape = "spiral"
	root.add_child(g); g.set_process(false); g._camp = false
	g._open_menu(false); g.ai_enabled = true
	# drive every faction with the AI so the whole board plays out
	g.humans = []; g.ais = g.botnets.duplicate()
	for fac in g.ais:
		if not g._ai.has(fac): g._ai[fac] = {"timer": 0.5 * float(fac), "dead": false}

	var start_owned := owned()
	var started := {}   # fac -> hosts it starts with
	for fac in g.botnets: started[fac] = held_by(int(fac)).size()
	var settled := {}   # fac -> hosts it held SETTLE s before the end
	var snap_at := int((HORIZON - SETTLE) / g.SIM_DT)
	var breach: Dictionary = g._recipe_cost("breach")
	var price := []
	for r in breach: price.append("%s %s" % [g._amt(float(breach[r])), g.RES_NAME[r]])
	print("Ten minutes of AI play: every producer makes 1 unit every %s s, the main node 1 of each every %s s; a Breach costs %s"
		% [g._amt(g.PROD_CYCLE), g._amt(1.0 / g.MAIN_INCOME), " + ".join(price)])
	for k in int(HORIZON / g.SIM_DT):
		if k == snap_at:
			for fac in g.botnets: settled[fac] = held_by(int(fac))
		g._sim_step(g.SIM_DT)
		if g.won or g.lost: break
	if settled.is_empty():
		for fac in g.botnets: settled[fac] = held_by(int(fac))

	var end_owned := owned()
	var plays := 0; var blueprints := 0
	for fac in g.botnets:
		plays += int(g.card_plays.get(fac, 0))
		blueprints += (g.known.get(fac, {}) as Dictionary).size()
	var researched: int = blueprints - int(g.botnets.size()) * int(g.KNOWN_START.size())   # beyond the starting set each

	check(researched >= 3, "The AIs research new blueprints (%d learned beyond the starting set)" % researched)
	check(plays >= 8, "The AIs manufacture and play cards (%d plays)" % plays)
	check(end_owned >= start_owned + 5, "The AIs capture ground (owned %d -> %d of %d)" % [start_owned, end_owned, g.hosts.size()])

	# every AI on its own keeps developing (not just the total): buildings, workers and a blueprint of its own in 10 minutes
	var breach_secs := 0.0   # how long the main node's trickle alone takes to pay for one Breach (flow and prices scale together)
	for r in breach: breach_secs = maxf(breach_secs, float(breach[r]) / g.MAIN_INCOME)
	var min_tries := int(HORIZON / breach_secs)   # an AI that keeps trying makes at least the attempts the trickle alone pays for
	for fac in g.botnets:
		if g._eliminated.has(fac): continue
		var built := 0
		for i in held_by(int(fac)):
			for kind in g.hosts[i].builds: if str(kind) != "": built += 1
		var learned := (g.known.get(fac, {}) as Dictionary).size() - int(g.KNOWN_START.size())
		var w: Dictionary = g._worker_counts(int(fac))
		var kept: Array = (settled[fac] as Array).filter(func(i): return int(g.hosts[i].owner) == int(fac))
		if kept.size() > int(started[fac]):   # it took ground in time to build on it
			check(built >= MIN_BUILT and int(w.total) >= 2 * int(g.WORKERS_PER_STATION) and learned >= 1,
				"AI %d keeps developing: %d buildings (>= %d), %d workers (>= %d: a second Bot station), %d blueprints learned"
				% [int(fac), built, MIN_BUILT, int(w.total), 2 * int(g.WORKERS_PER_STATION), learned])
		else:
			# The dice kept it on the hosts it started with: its capture rolls failed (25% unscouted, 50% with fresh Recon), so
			# it has no room for MIN_BUILT buildings and no need of a second station. (0.6.18: seed 5's AI 2 lost 9 Breach rolls
			# of 9; the old fixed bar failed it with all 6 of its 6 slots built.) It must still develop all it holds: every
			# slot built, the workers its own rule asks for (one station per two hosts held), a blueprint, and it keeps
			# attacking at least as often as its trickle alone pays for.
			var room := 0; var built_there := 0
			for i in kept:
				for kind in g.hosts[i].builds:
					room += 1
					if str(kind) != "": built_there += 1
			var tries := 0; var lost := 0
			for o in g.op_outcomes:
				if int(o.fac) != int(fac) or not (str(g.CARDS[str(o.card)].effect) in ["capture", "worm"]): continue
				tries += 1
				if str(o.outcome) != "captured": lost += 1
			var need_w: int = int(g.WORKERS_PER_STATION) * ceili(float(kept.size()) / 2.0)
			check(built_there >= room and int(w.total) >= need_w and learned >= 1 and tries >= min_tries,
				"AI %d, boxed in (%d of %d capture rolls failed), develops all it holds: %d of %d slots built, %d workers (>= %d), %d blueprints learned, %d capture tries (>= %d, what its trickle alone pays for)"
				% [int(fac), lost, tries, built_there, room, int(w.total), need_w, learned, tries, min_tries])

	print(JSON.stringify({"checks": checks, "failures": failures, "owned": "%d->%d" % [start_owned, end_owned], "plays": plays}))
	g.free(); quit(0 if failures.is_empty() else 1)
