extends SceneTree
## Menus: every view keeps every control inside its panel with equal visible side insets, at 1280x720, 1366x768,
## a 4:3 viewport and a narrow one; Main → Help → every page → Back repeated leaves the main menu (Exit included)
## intact; no menu text uses a glyph the bundled fonts lack; the main menu holds navigation only (no Multiplayer,
## no guidance); New game has no layout control, and the seed alone picks a reproducible layout and map.
## godot --headless --path . --script tests/menu_test.gd
var game
var view: SubViewport
var checks := 0
var failures := []
var fonts := []


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL  " + label)


func settle(n := 4) -> void:
	for k in n: await process_frame


func run() -> void:
	fonts = [load("res://assets/fonts/JetBrainsMono-Regular.ttf"), load("res://assets/fonts/JetBrainsMono-Bold.ttf"), load("res://assets/fonts/NotoSansSymbols-Regular.ttf")]
	view = SubViewport.new(); view.size = Vector2i(1280, 720); root.add_child(view)
	game = load("res://scripts/botnet_proto.gd").new()
	game.theme = load("res://assets/ui_theme.tres")
	game._opt_size = Vector2i(8, 6); game._opt_enemies = 1; game._opt_seed = 7
	view.add_child(game); game.set_process(false)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.CAMP_SAVE_HARNESS))
	for res in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1280, 960), Vector2i(1024, 768)]:
		view.size = res; game.size = Vector2(res); game._layout_ui()
		await settle()
		await main_menu(res)
		await help_round_trips(res)
		await other_views(res)
	await learn_progress()
	await seed_layouts()
	source_glyphs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.CAMP_SAVE_HARNESS))
	print(JSON.stringify({"checks": checks, "failures": failures}))
	game.free(); quit(0 if failures.is_empty() else 1)


func texts() -> Array:   # every visible Label/Button text in the menu
	var out := []
	var stack: Array = [game.menu_box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if n is Control and not (n as Control).is_visible_in_tree(): continue
		if n is Label: out.append((n as Label).text)
		elif n is Button: out.append((n as Button).text)
	return out


func glyphs_ok(where: String) -> void:
	for t in texts():
		for i in str(t).length():
			var c := str(t).unicode_at(i)
			if c < 128: continue
			var ok := false
			for f in fonts: ok = ok or (f as Font).has_char(c)
			check(ok, "%s: '%s' uses U+%X, which no bundled font has" % [where, str(t).substr(0, 30), c])


func contained(where: String) -> void:   # every leaf control inside the panel; equal visible insets left and right
	var panel: Rect2 = game.menu_panel.get_global_rect()
	var vp := Rect2(Vector2.ZERO, Vector2(view.size))
	check(vp.encloses(panel), "%s: the panel %s fits the window %s" % [where, panel, vp.size])
	var minx := INF; var maxx := -INF
	var stack: Array = [game.menu_box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if not (n is Control) or not (n as Control).is_visible_in_tree() or n == game.menu_box: continue
		if n is Container and not (n is Button): continue
		var r: Rect2 = (n as Control).get_global_rect()
		check(panel.grow(0.5).encloses(r), "%s: %s '%s' %s leaves the panel %s" % [where, n.get_class(), (n as Control).get("text") if (n is Label or n is Button) else n.name, r, panel])
		if n is Button and (n as Button).clip_text and (n as Button).text != "":
			var b := n as Button
			var need: float = b.get_theme_default_font().get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x + 16.0 + (24.0 if b.icon != null else 0.0)
			check(need <= r.size.x + 0.5, "%s: button '%s' is cut (%.0f of %.0f px)" % [where, b.text, need, r.size.x])
		minx = minf(minx, r.position.x); maxx = maxf(maxx, r.end.x)
	var left := minx - panel.position.x; var right := panel.end.x - maxx
	check(absf(left - right) <= 1.0, "%s: side insets equal (left %.1f, right %.1f)" % [where, left, right])
	check(left >= 16.0, "%s: content keeps a visible inset (%.1f px)" % [where, left])


func buttons() -> Array:
	return texts().filter(func(t): return t != "")


func main_menu(res: Vector2i) -> void:
	game._open_menu(true); await settle()
	var where := "main @%s" % res
	contained(where); glyphs_ok(where)
	var b := buttons()
	check(b.has("Exit") and b.has("Help") and b.has("Skirmish"), "%s: Skirmish, Help and Exit are there (%s)" % [where, b])
	check(not b.has("Multiplayer"), "%s: no Multiplayer entry" % where)
	var prose := false
	for t in texts(): prose = prose or str(t).contains("New to RIM") or str(t).contains("Skip for now") or str(t).length() > 40
	check(not prose, "%s: navigation only, no guidance text (%s)" % [where, texts()])


func help_round_trips(res: Vector2i) -> void:
	for round in 3:
		game._open_menu(true); await settle()
		game._help_page = 0; game._menu_view = "help"; game._refresh_menu(); await settle()
		for p in game.HELP_PAGES.size():
			contained("help page %d (round %d) @%s" % [p + 1, round + 1, res]); glyphs_ok("help page %d @%s" % [p + 1, res])
			game.menu_sc.scroll_vertical = 10000   # read to the bottom, where Back is
			await settle()
			if p < game.HELP_PAGES.size() - 1: game._help_page += 1; game._refresh_menu(); await settle()
		game._menu_view = "main"; game._refresh_menu(); await settle()   # Back to menu
		contained("main after Help (round %d) @%s" % [round + 1, res])
		var exit_btn: Control = null
		for c in game.menu_box.get_children():
			if c is Button and (c as Button).text == "Exit": exit_btn = c
		check(exit_btn != null and game.menu_panel.get_global_rect().encloses(exit_btn.get_global_rect()), "Exit stays inside the panel after Help (round %d) @%s" % [round + 1, res])


func other_views(res: Vector2i) -> void:
	for v in ["newgame", "campaign", "feedback"]:
		game._menu_view = v; game._refresh_menu(); await settle()
		contained("%s @%s" % [v, res]); glyphs_ok("%s @%s" % [v, res])
		game._menu_view = "main"; game._refresh_menu(); await settle()
		contained("main after %s @%s" % [v, res])
	game._menu_view = "newgame"; game._refresh_menu(); await settle()
	var layout_ctrl := false
	for t in texts(): layout_ctrl = layout_ctrl or str(t).to_lower().contains("layout") or str(t).to_lower().contains("spiral") or str(t).to_lower().contains("grid")
	check(not layout_ctrl, "newgame @%s: no layout/type control" % res)
	check(texts().has("Small") and texts().has("Seed (blank = random)") and texts().has("Start"), "newgame @%s: size, enemies and seed stay" % res)


func learn_progress() -> void:   # the Learn screen with no progress and with progress part-way
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.CAMP_SAVE_HARNESS))
	view.size = Vector2i(1280, 720); game.size = Vector2(1280, 720); game._layout_ui()
	game._open_menu(true); game._menu_view = "campaign"; game._refresh_menu(); await settle()
	contained("Learn, fresh"); glyphs_ok("Learn, fresh")
	game._camp_write(2, 1)
	game._menu_view = "campaign"; game._refresh_menu(); await settle()
	contained("Learn, part-way"); glyphs_ok("Learn, part-way")
	var b := buttons()
	var cont := false
	for t in b: cont = cont or str(t).begins_with("Continue")
	check(cont, "Learn part-way offers to continue (%s)" % [b])
	game._menu_view = "main"; game._refresh_menu(); await settle()
	glyphs_ok("main with Learn progress"); contained("main with Learn progress")


func seed_layouts() -> void:   # no shape option: the seed picks the layout, and the same seed gives the same map
	game._opt_shape = ""
	var seen := {}
	var sig := {}
	for s in range(1, 41):
		game._opt_seed = s; game._reset()
		seen[game._layout] = true
		if s <= 3: sig[s] = [game._layout, game.hosts.size(), str(game.hosts[0].pos), str(game.hosts[game.hosts.size() - 1].pos)]
	check(seen.size() == game.SHAPES.size(), "40 seeds use every supported layout (%s)" % [seen.keys()])
	for s in [1, 2, 3]:
		game._opt_seed = s; game._reset()
		check([game._layout, game.hosts.size(), str(game.hosts[0].pos), str(game.hosts[game.hosts.size() - 1].pos)] == sig[s], "seed %d reproduces its layout and map (%s)" % [s, sig[s][0]])
	game._opt_seed = 0; game._reset()
	check(game.town_seed > 0 and game.SHAPES.has(game._layout), "a random game gets a seed and a supported layout (%d, %s)" % [game.town_seed, game._layout])
	var picked: String = game._layout_for_seed(game.town_seed)
	check(picked == game._layout, "the random game's layout follows its seed")
	game._opt_shape = "grid"; game._opt_seed = 5; game._reset()
	check(game._layout == "grid", "an explicit internal fixture still picks the layout")
	game._opt_shape = ""


func source_glyphs() -> void:   # no interface script uses a character the bundled fonts cannot draw
	var files := ["res://scripts/botnet_proto.gd", "res://scripts/botnet_help.gd"]
	for f in DirAccess.get_files_at("res://scripts/botnet_cfg"):
		if f.ends_with(".gd"): files.append("res://scripts/botnet_cfg/" + f)
	for path in files:
		var txt := FileAccess.get_file_as_string(path)
		var ln := 0
		for line in txt.split("\n"):
			ln += 1
			for i in line.length():
				var c := line.unicode_at(i)
				if c < 128: continue
				var ok := false
				for fo in fonts: ok = ok or (fo as Font).has_char(c)
				check(ok, "%s:%d uses U+%X, which no bundled font has" % [path.get_file(), ln, c])
