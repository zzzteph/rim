extends SceneTree
## AI competence: with every faction AI-driven, the economic AI must research blueprints, manufacture
## cards and actually capture ground within a couple of minutes — not sit idle.
## godot --headless --path . --script tests/ai_test.gd
var g
var checks := 0
var failures := []


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
	for k in int(240.0 / g.SIM_DT):   # four minutes: income is one production cycle every 5 s, so the first cards take a while
		g._sim_step(g.SIM_DT)
		if g.won or g.lost: break

	var end_owned := owned()
	var plays := 0; var blueprints := 0
	for fac in g.botnets:
		plays += int(g.card_plays.get(fac, 0))
		blueprints += (g.known.get(fac, {}) as Dictionary).size()
	var researched: int = blueprints - int(g.botnets.size()) * int(g.KNOWN_START.size())   # beyond the starting five each

	check(researched >= 3, "The AIs research new blueprints (%d learned beyond the starting set)" % researched)
	check(plays >= 8, "The AIs manufacture and play cards (%d plays)" % plays)
	check(end_owned >= start_owned + 5, "The AIs capture ground (owned %d -> %d of %d)" % [start_owned, end_owned, g.hosts.size()])

	print(JSON.stringify({"checks": checks, "failures": failures, "owned": "%d->%d" % [start_owned, end_owned], "plays": plays}))
	g.free(); quit(0 if failures.is_empty() else 1)
