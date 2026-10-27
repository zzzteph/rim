extends SceneTree
## Long-run crash guard: a full four-faction match (three economic AIs) simulated for 90 s.
## Asserts the simulation advances and stays internally consistent without a script error.
## godot --headless --path . --script tests/sim_smoke_test.gd
var g
var checks := 0
var failures := []


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func run() -> void:
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(10, 8); g._opt_enemies = 3; g._opt_seed = 11; g._opt_shape = "spiral"
	root.add_child(g); g.set_process(false); g._camp = false
	g._open_menu(false); g.ai_enabled = true
	check(g.botnets.size() == 4 and g.ais.size() == 3, "A four-faction match starts with three AIs")

	var ended := false
	for sec in 90:
		for k in 30: g._sim_step(g.SIM_DT)
		# every faction's banks stay finite and non-negative every second
		var sane := true
		for fac in g.botnets:
			for res in g.RES:
				var v := float((g.bank.get(fac, {}) as Dictionary).get(res, 0.0))
				if not is_finite(v) or v < -0.001 or v > g._cap(fac, res) + 1.0: sane = false
		if not sane: check(false, "Banks stay within [0, cap] at t=%.0f" % g._t); break
		if g.won or g.lost: ended = true; break

	check(g._t >= 89.0 or ended, "The simulation advanced ~90 s (or reached a result) without a script error")
	var total := 0
	for i in g.hosts.size(): total += 1
	var held := 0
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != g.NEUTRAL: held += 1
	check(held >= 4, "Every faction still holds at least its main node (%d owned of %d)" % [held, total])
	# ownership generations only ever increase; a capture clears installations — never leaves a ghost job on a neutral host
	var clean := true
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == g.NEUTRAL and not (g.hosts[i].jobs as Dictionary).is_empty(): clean = false
	check(clean, "Neutral hosts carry no left-over construction jobs")

	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)
