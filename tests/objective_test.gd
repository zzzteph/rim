extends SceneTree
## The win objective (Milestone A, brief §16.2): one source of truth, ceil(0.51 × hosts) held for 51 s in a row,
## always on the HUD with the exact count and the time left; standings and the win check use the same numbers.
## godot --headless --path . --script tests/objective_test.gd
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


func fresh() -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER; R = g.RIVAL


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func give(fac: int, n: int) -> void:   # fac takes neutral hosts until it holds n
	for i in g.hosts.size():
		if g._faction_nodes(fac) >= n: return
		if int(g.hosts[i].owner) == g.NEUTRAL: g._capture(i, fac)


func run() -> void:
	fresh()
	var o: Dictionary = g._objective()
	check(int(o.need) == int(ceil(0.51 * float(g.hosts.size()) - 0.000001)) and int(o.total) == g.hosts.size(), "The majority is ceil(51%% of all hosts): %d of %d" % [int(o.need), int(o.total)])
	check(int((o.counts as Dictionary)[P]) == g._faction_nodes(P) and int(o.holder) == -1, "Counts come from the real ownership; nobody holds the majority at the start")
	var line: Array = g._objective_lines()
	check(str(line[0]) == "MAJORITY %d / %d · you %d" % [int(o.need), int(o.total), g._faction_nodes(P)], "The HUD states the exact count needed and yours (%s)" % str(line[0]))
	give(P, int(o.need))
	step(10.0)
	o = g._objective()
	line = g._objective_lines()
	check(int(o.holder) == P and absf(float(o.hold_left) - 41.0) < 0.2, "Holding the majority counts down from 51 s (%.1f s left)" % float(o.hold_left))
	check(str(line[1]).begins_with("You hold it: win in 41"), "The HUD says you hold it and the time left (%s)" % str(line[1]))
	for i in g.hosts.size():   # drop one host below the majority: the timer resets
		if int(g.hosts[i].owner) == P and not bool(g.hosts[i].rig):
			g.hosts[i].owner = g.NEUTRAL; g.hosts[i].gen = int(g.hosts[i].gen) + 1; break
	step(1.0)
	check(int(g._objective().holder) == -1 and float(g._hold[P]) == 0.0, "Falling below the majority resets the hold")
	give(P, int(o.need))
	step(g.HOLD_SECS + 0.5)
	check(g.won, "Holding it for %d s in a row wins" % int(g.HOLD_SECS))
	fresh()
	give(R, int(g._objective().need))
	step(5.0)
	line = g._objective_lines()
	check(str(line[1]).begins_with("%s holds it: wins in 46" % g.fname(R)) and line[2] == g.C_BAD, "A rival's hold is shown as a threat with its time left (%s)" % str(line[1]))
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)
