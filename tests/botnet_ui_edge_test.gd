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

func fresh(map_size := Vector2i(6, 4)) -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scripts/botnet_proto.gd").new()
	game.theme = load("res://assets/ui_theme.tres")
	game._opt_seed = 7; game._opt_size = map_size
	viewport.add_child(game)
	game.set_process(false); game.ai_enabled = false
	game.set_anchors_preset(Control.PRESET_TOP_LEFT); game.size = Vector2(viewport.size)
	game._open_menu(false); game._layout_ui(); game._fit_view()

func settle() -> void:
	for frame in 4: await process_frame

func find_button(node: Node, name: String) -> Button:
	if node is Button and (str(node.name) == name or name in node.text): return node
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
	game.paused = true; await settle()
	var tiles := scripted_nodes(game.hand_panel, game.CardTile)
	var identity: int = tiles[0].get_instance_id()
	viewport.size = Vector2i(1280, 720); game.size = Vector2(viewport.size)
	await settle()
	tiles = scripted_nodes(game.hand_panel, game.CardTile)
	check(tiles[0].get_instance_id() == identity, "Live resize preserves permanent card identity")
	var cards_fit := true
	for tile in tiles:
		if not game.hand_panel.get_global_rect().encloses(tile.get_global_rect()): cards_fit = false
	check(cards_fit and tiles.size() == 4, "Four permanent cards fit after wide-to-small resize while paused")
	check(game.hand_panel.size.x >= viewport.size.x - 60 and tiles[0].size.x >= 240 and tiles[0].size.y >= 240, "Live resize retains four large detailed cards across the bottom")
	game._left_click(game.rig[game.PLAYER], false); game._refresh_panel(); await settle()
	check(game.panel.get_global_rect().end.y <= game.hand_panel.position.y - 10 and not game.panel.get_global_rect().intersects(game.hand_panel.get_global_rect()), "Resized sidebar stays above the full-width card dock")
	game._card_research_click("phishworm:linked"); game._card_research_click("zeroday:linked"); await settle()
	var zero_day: Control = tiles[1]
	var cancel: Button = zero_day.stop_button
	var cancel_identity := cancel.get_instance_id()
	var cancel_point := cancel.get_global_rect().get_center()
	await mouse(cancel_point, true)
	game.cash[game.PLAYER] = 100; game.creds[game.PLAYER] = 100; game.research[game.PLAYER] = 100
	game._tick_research(42); game._refresh_hand(); await settle()
	check(cancel.get_instance_id() == cancel_identity, "Another card's completion preserves a pressed cancel control")
	await mouse(cancel_point, false)
	check(game.lab[game.PLAYER].queue.is_empty() and game._held(game.PLAYER, "phishworm:linked") == 1, "Cancel resolves by card identity after queue indices shift")
	fresh(); await settle()
	var empty_tile: Control = scripted_nodes(game.hand_panel, game.CardTile)[0]
	var empty_point := empty_tile.get_global_rect().get_center()
	await mouse(empty_point, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(400, 400); motion.global_position = motion.position
	motion.relative = motion.position - empty_point; motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion, true); await process_frame
	await mouse(motion.position, false)
	check(game.lab[game.PLAYER].queue.is_empty(), "Dragging an empty card off the tray does not queue research on release")
	fresh(); source = game.rig[game.PLAYER]
	game.hosts[source].slots = 5; game._set_builds(source, [])
	game.intel[game.PLAYER] = 100
	game._left_click(source, false); game._refresh_panel(); await settle()
	var available_cards := scripted_nodes(game.panel, game.BuildCard)
	check(game.panel_scroll.get_v_scroll_bar().visible, "Shorter sidebar exposes scrolling for its building palette")
	var wheel_point: Vector2 = game.panel_scroll.get_global_rect().get_center()
	for turn in 6:
		var wheel := InputEventMouseButton.new()
		wheel.position = wheel_point; wheel.global_position = wheel_point
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true
		viewport.push_input(wheel, true)
		wheel.pressed = false; viewport.push_input(wheel, true)
		await process_frame
	await settle()
	var build_card: Control = available_cards[0]
	check(game.panel_scroll.get_global_rect().encloses(build_card.get_global_rect()), "Scrolling exposes the whole building card above the dock")
	var build_point := build_card.get_global_rect().get_center()
	await mouse(build_point, true)
	game._refresh_panel()
	await mouse(build_point, false)
	check(game.hosts[source].jobs.size() == 1, "A palette click after scrolling still starts construction across refresh")
	for has_resume in [false, true]:
		fresh(); game._t = 1.0 if has_resume else 0.0
		game._open_menu(true); await settle()
		check(game.menu_sc.get_global_rect().encloses(game.menu_box.get_global_rect()) and not game.menu_sc.get_v_scroll_bar().visible, "Main menu fits without scrolling, Resume %s" % has_resume)
		var exit_button := find_button(game.menu_box, "Exit")
		check(exit_button != null and game.menu_sc.get_global_rect().encloses(exit_button.get_global_rect()), "Exit remains visible inside the main menu")
	fresh(); game._open_menu(true)
	for menu in ["newgame", "feedback"]:
		game._menu_view = menu; game._refresh_menu(); await settle()
		check(game.menu_sc.get_global_rect().encloses(game.menu_box.get_global_rect()) and not game.menu_sc.get_v_scroll_bar().visible, "%s menu fits without scrolling with the bundled font" % menu)
		check(viewport.get_visible_rect().encloses(game.menu_panel.get_global_rect()), "%s menu stays inside the viewport" % menu)
	for resolution in [Vector2i(1280, 720), Vector2i(1366, 768)]:
		viewport.size = resolution
		for map_size in [Vector2i(8, 6), Vector2i(10, 8)]:
			fresh(map_size); game._clear_all(); game._refresh_panel(); game._fit_view(); await settle()
			var glyphs_clear := true
			for index in game.hosts.size():
				var point: Vector2 = game._w2s(game.hosts[index].pos)
				var margin := maxf(22, game._r(index) * game._zoom + 5)
				if point.y + margin > game.hand_panel.position.y - 12: glyphs_clear = false
			check(game.hand_panel.visible and not game.panel.visible and glyphs_clear, "Fitted node glyphs stay above the permanent row: %s / %s" % [resolution, map_size])
			game._open_menu(true); game._reset(); game._open_menu(false); await settle()
			var restart_clear := true
			for index in game.hosts.size():
				if game._w2s(game.hosts[index].pos).y + maxf(22, game._r(index) * game._zoom + 5) > game.hand_panel.position.y - 12: restart_clear = false
			check(restart_clear, "Starting from the menu fits the town above the row: %s / %s" % [resolution, map_size])
		fresh(); game._left_click(game.rig[game.PLAYER], false); game._refresh_panel()
		for message in ["Connected 1 building to TRAINING TARGET (dormant - press SCAN or ATTACK on its panel). Travelling packets still arrive.", "Phishing campaign hit the server: remove 10% of defenders and steal every resource output for 30 seconds, spreading to the database for 20 seconds and ERP for 10 seconds."]:
			game._flash(message); game._update_chrome(); await settle()
			check(game.feedback_label.visible and game.feedback_label.get_global_rect().end.y <= game.hand_panel.position.y - 10, "Wrapped connection/card toast ends above the permanent row: %s" % resolution)
			check(not game.feedback_label.get_global_rect().intersects(game.panel.get_global_rect()), "Wrapped toast stays inside the map's available width: %s" % resolution)
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
