extends SceneTree
## Run: godot --headless --path . --script tests/ai_card_smoke_test.gd
## Exercises AI research, casting and economy with the four-card catalogue.

var checks := 0
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var scenarios := []
	for scenario in [
		{"size": Vector2i(6, 4), "enemies": 1, "seed": 7},
		{"size": Vector2i(8, 6), "enemies": 3, "seed": 33},
	]:
		var game = load("res://scripts/botnet_proto.gd").new()
		game.theme = load("res://assets/ui_theme.tres")
		game._opt_size = scenario.size; game._opt_enemies = scenario.enemies; game._opt_seed = scenario.seed
		root.add_child(game); game.set_process(false); game._open_menu(false)
		for faction in game.ais:
			game.cash[faction] = 200.0; game.creds[faction] = 100.0; game.research[faction] = 100.0
			for card in game.CARD_ORDER: game.cards[faction][game._card_key(card, "linked")] = 1
		var stocks_valid := true
		var queues_valid := true
		for frame in 5400:
			if game.won or game.lost: break
			game._process(1.0 / 30.0)
			for faction in game.botnets:
				if float(game.intel[faction]) < -0.00001 or float(game.cash[faction]) < -0.00001 or float(game.creds[faction]) < -0.00001 or float(game.research[faction]) < -0.00001: stocks_valid = false
				for key in game.lab[faction].queue:
					if not game.CARD_ORDER.has(game._card_of(str(key))): queues_valid = false
		var plays := 0
		for faction in game.ais: plays += int(game.card_plays.get(faction, 0))
		check(game._t > 10.0, "AI match advances with seed %d" % scenario.seed)
		check(stocks_valid, "AI card research keeps resource stocks nonnegative: seed %d" % scenario.seed)
		check(queues_valid, "AI research uses only the four retained cards: seed %d" % scenario.seed)
		check(plays > 0, "AI can cast retained cards: seed %d" % scenario.seed)
		scenarios.append({"seed": scenario.seed, "map": str(scenario.size), "enemies": scenario.enemies, "simulated_seconds": game._t, "ai_card_plays": plays, "won": game.won, "lost": game.lost})
		game.free()
	var report := {"checks": checks, "failures": failures, "scenarios": scenarios, "scope": "Deterministic AI integration smoke, not a difficulty or pacing verdict"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/implemented_ui"))
	var file := FileAccess.open("res://review/implemented_ui/ai_card_smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
