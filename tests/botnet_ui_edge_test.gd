extends SceneTree
## Run: godot --headless --path . --script tests/botnet_ui_edge_test.gd
## Regressions for live sidebar changes, guard management and live resizing.

var game
var viewport: SubViewport
var checks := 0
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func fresh() -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scripts/botnet_proto.gd").new()
	game.theme = load("res://assets/ui_theme.tres")
	game._opt_seed = 7; game._opt_size = Vector2i(6, 4)
	viewport.add_child(game)
	game.set_process(false); game.ai_enabled = false
	game.set_anchors_preset(Control.PRESET_TOP_LEFT); game.size = Vector2(viewport.size)
	game._open_menu(false); game._layout_ui(); game._fit_view()

func settle() -> void:
	for frame in 4: await process_frame

func find_button(node: Node, name: String) -> Button:
	if node is Button and str(node.name) == name: return node
	for child in node.get_children():
		var found := find_button(child, name)
		if found != null: return found
	return null

func scripted_nodes(node: Node, script: Script) -> Array:
	var found := []
	if node.get_script() == script: found.append(node)
	for child in node.get_children(): found.append_array(scripted_nodes(child, script))
	return found

func mouse(at: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = at; motion.global_position = at
	viewport.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = at; event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	viewport.push_input(event, true)
	await process_frame

func attack_fixture() -> Array:
	var source: int = game.rig[game.PLAYER]
	var target := -1
	for neighbor in game.hosts[source].links:
		if int(game.hosts[neighbor].owner) == game.NEUTRAL:
			target = neighbor; break
	game._mark_scanned(game.PLAYER, target)
	game.sel = {source: true}; game._wire(target); game._launch(target, "attack")
	game.intel[game.PLAYER] = 10.0; game._refresh_panel()
	return [source, target]

func _run() -> void:
	root.size = Vector2i(1, 1); root.position = Vector2i(-20000, -20000)
	viewport = SubViewport.new(); viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	for appearing in [true, false]:
		fresh()
		var fixture := attack_fixture()
		game.intel[game.PLAYER] = 10.0 if appearing else 0.0
		game._refresh_panel(); await settle()
		var stop := find_button(game.panel, "Stop")
		var point := stop.get_global_rect().get_center()
		var identity := stop.get_instance_id()
		await mouse(point, true)
		game.intel[game.PLAYER] = 0.0 if appearing else 10.0
		game._refresh_panel(); await settle()
		check(find_button(game.panel, "Stop").get_instance_id() == identity, "Stop identity survives blocker %s" % ("appearing" if appearing else "clearing"))
		await mouse(point, false)
		check(not game.hosts[fixture[0]].live, "Stop press completes across blocker %s" % ("appearing" if appearing else "clearing"))

	fresh()
	var source: int = game.rig[game.PLAYER]
	var guarded := -1
	for index in game.hosts.size():
		if game._mine(index) and index != source: guarded = index; break
	game.sel = {source: true}; game._wire(guarded); await settle()
	check(game._inspect == guarded and game.sel.is_empty(), "Guard connection opens friendly inspection")
	check(find_button(game.panel, "Disconnect_%d" % source) != null, "Friendly inspected node exposes its incoming guard")

	fresh()
	var fixture := attack_fixture()
	game._capture(fixture[1], game.PLAYER); game._refresh_panel(); await settle()
	check(find_button(game.panel, "Disconnect_%d" % fixture[0]) != null, "Captured inspected target keeps connection management")

	viewport.size = Vector2i(1920, 1080); fresh()
	game._set_tab("research"); game.paused = true; await settle()
	var tiles := scripted_nodes(game.panel, game.ResearchTile)
	var identity: int = tiles[0].get_instance_id()
	viewport.size = Vector2i(1280, 720); game.size = Vector2(viewport.size)
	await settle()
	tiles = scripted_nodes(game.panel, game.ResearchTile)
	check(tiles[0].get_instance_id() == identity, "Live resize preserves catalogue control identity")
	var gallery_fits := true
	for tile in tiles:
		if not game.panel.get_global_rect().encloses(tile.get_global_rect()): gallery_fits = false
	check(gallery_fits, "All eight catalogue cards fit after wide-to-small resize while paused")
	check(game.panel.get_global_rect().encloses(game.panel_box.get_global_rect()), "Research sidebar content fits after live resize")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
