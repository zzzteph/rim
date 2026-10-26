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

func fresh(map_size := Vector2i(6, 4), enemy_count := 2) -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scripts/botnet_proto.gd").new()
	game.theme = load("res://assets/ui_theme.tres")
	game._opt_seed = 7; game._opt_size = map_size; game._opt_enemies = enemy_count
	viewport.add_child(game)
	game.set_process(false); game.ai_enabled = false
	game.set_anchors_preset(Control.PRESET_TOP_LEFT); game.size = Vector2(viewport.size)
	game._open_menu(false); game._layout_ui(); game._fit_view()

func settle() -> void:
	for frame in 4: await process_frame

func set_onboarded(flag: bool) -> void:   # the harness's own campaign save (never the player's)
	var path: String = game._camp_save_path()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if flag:
		for k in game.CAMP_CHAPTERS: game._camp_done[k] = true
		game._camp_save()


func menu_fits() -> bool:   # the scroll box keeps the panel's width, and every visible row lies inside the panel
	var pr: Rect2 = game.menu_panel.get_global_rect().grow(0.5)
	if game.menu_sc.size.x > game.menu_panel.size.x - 48.0 + 0.5:
		print("  scroll box wider than the panel: ", game.menu_sc.size.x, " vs ", game.menu_panel.size.x); return false
	var stack: Array = game.menu_box.get_children()
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is Control and c.is_visible_in_tree() and not pr.encloses(c.get_global_rect()):
			print("  sticks out: ", c, " ", c.get_global_rect(), " panel ", pr); return false
		stack.append_array(c.get_children())
	return true


func find_button(node: Node, name: String) -> Button:
	if node is Button and (str(node.name) == name or name in node.text): return node
	for child in node.get_children():
		var found := find_button(child, name)
		if found != null: return found
	return null

func scripted_nodes(node: Node, script: Script) -> Array:
	var found := []
	if node.get_script() == script and (script != game.CardTile or node.visible): found.append(node)
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
	check(find_button(game.panel, "Disconnect_%d" % fixture[0]) == null and int(game.hosts[fixture[0]].assign) == -1, "A captured target needs no link: the connection into it ends")

	viewport.size = Vector2i(1920, 1080); fresh(); game._set_deck_open(true)
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
	check(game.hand_panel.size.x == viewport.size.x - 48 and game.hand_panel.size.y == 264 and tiles[0].size.x >= 240 and tiles[0].size.y == 264, "Live resize retains the full-width 264px detailed-card dock")
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
	fresh(); game._set_deck_open(true); await settle()
	var empty_tile: Control = scripted_nodes(game.hand_panel, game.CardTile)[0]
	var empty_point := empty_tile.get_global_rect().get_center()
	await mouse(empty_point, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(400, 400); motion.global_position = motion.position
	motion.relative = motion.position - empty_point; motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion, true); await process_frame
	await mouse(motion.position, false)
	check(game.lab[game.PLAYER].queue.is_empty(), "Dragging an empty card off the tray does not queue research on release")
	fresh(); source = game.rig[game.PLAYER]; game._set_deck_open(true)   # pulled-up cards leave the sidebar short
	game.hosts[source].slots = 5; game._set_builds(source, [])
	game.intel[game.PLAYER] = 100; game.cash[game.PLAYER] = 100   # the first palette card (Bot farm) is paid in Crypto
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
	# every menu row must sit inside the PANEL (the scroll box grows with its widest child, so checking against it can never fail)
	for onboarded in [false, true]:
		for has_resume in [false, true]:
			fresh(); set_onboarded(onboarded); game._t = 1.0 if has_resume else 0.0
			game._open_menu(true); await settle()
			check(menu_fits() and not game.menu_sc.get_v_scroll_bar().visible, "Main menu fits inside its panel, onboarded %s, Resume %s" % [onboarded, has_resume])
			var exit_button := find_button(game.menu_box, "Exit")
			check(exit_button != null and game.menu_panel.get_global_rect().encloses(exit_button.get_global_rect()), "Exit remains visible inside the main menu")
	fresh(); set_onboarded(false); game._start_campaign(3, true); game._open_menu(true); await settle()
	check(menu_fits(), "The mid-campaign main menu (Resume + the unlock note) fits inside its panel")
	game._menu_view = "campaign"; game._refresh_menu(); await settle()
	check(menu_fits(), "The mid-campaign Campaign menu (resume note + chapter rows) fits inside its panel")
	fresh(); set_onboarded(true); game._open_menu(true)
	for menu in ["newgame", "feedback", "campaign"]:
		game._menu_view = menu; game._refresh_menu(); await settle()
		check(menu_fits() and not game.menu_sc.get_v_scroll_bar().visible, "%s menu fits inside its panel with the bundled font" % menu)
		check(viewport.get_visible_rect().encloses(game.menu_panel.get_global_rect()), "%s menu stays inside the viewport" % menu)
	game._opt_mission = true; game._menu_view = "newgame"; game._refresh_menu(); await settle()
	check(menu_fits(), "New game with the Records mission selected fits inside its panel")
	game._opt_mission = false; set_onboarded(false)
	viewport.size = Vector2i(1280, 720)
	for enemy_count in [1, 2, 3]:
		fresh(Vector2i(8, 6), enemy_count); await settle()
		check(game.panel.visible and game.panel.size.x == 280 and game.botnets.size() == enemy_count + 1, "Compact standings include every configured faction: %d enemies" % enemy_count)
		check(game.panel_scroll.get_global_rect().encloses(game.panel_box.get_global_rect()) and not game.panel_scroll.get_v_scroll_bar().visible, "Every compact leaderboard row fits without scrolling: %d enemies" % enemy_count)
		game._hold[game.PLAYER] = 10.0; game._refresh_panel(); await settle()
		check("Holding 10" in game._panel_text() and game.panel_scroll.get_global_rect().encloses(game.panel_box.get_global_rect()), "Active hold progress remains readable without clipping any faction: %d enemies" % enemy_count)
	for resolution in [Vector2i(1280, 720), Vector2i(1366, 768)]:
		viewport.size = resolution
		for map_size in [Vector2i(8, 6), Vector2i(10, 8)]:
			fresh(map_size); game._clear_all(); game._refresh_panel(); game._fit_view(); await settle()
			var glyphs_clear := true
			for index in game.hosts.size():
				var point: Vector2 = game._w2s(game.hosts[index].pos)
				var margin := maxf(22, game._r(index) * game._zoom + 5)
				if point.y + margin > game._deck_top() - 12: glyphs_clear = false
			check(game.card_banks.visible and game.panel.visible and not game._panel_has_context() and game._panel_width() == 280 and glyphs_clear, "Fitted nodes stay above the deck beside compact standings: %s / %s" % [resolution, map_size])
			var leaderboard_clear := true
			for index in game.hosts.size():
				if game._w2s(game.hosts[index].pos).x + maxf(22, game._r(index) * game._zoom + 5) > game.panel.position.x - 12: leaderboard_clear = false
			check(leaderboard_clear, "Fitted node glyphs stay left of the automatic leaderboard: %s / %s" % [resolution, map_size])
			game._open_menu(true); game._reset(); game._open_menu(false); await settle()
			var restart_clear := true
			for index in game.hosts.size():
				if game._w2s(game.hosts[index].pos).y + maxf(22, game._r(index) * game._zoom + 5) > game._deck_top() - 12: restart_clear = false
			check(restart_clear, "Starting from the menu fits the town above the row: %s / %s" % [resolution, map_size])
		fresh(); game._left_click(game.rig[game.PLAYER], false); game._refresh_panel()
		var dock_before: Rect2 = game.card_banks.get_global_rect()
		check(game._panel_has_context() and game.panel.size.x == 620, "Node context replaces compact standings with the full sidebar")
		var board_key := InputEventKey.new(); board_key.keycode = KEY_L; board_key.pressed = true
		game._input(board_key); await settle()
		check(game._panel_has_context() and game.card_banks.get_global_rect() == dock_before, "Removed L shortcut preserves node details and deck geometry")
		game._clear_all(); game._refresh_panel(); await settle()
		check(not game._panel_has_context() and game.panel.size.x == 280 and game.card_banks.get_global_rect() == dock_before, "Clearing context restores compact standings without moving the deck")
		game._left_click(game.rig[game.PLAYER], false); game._refresh_panel(); await settle()
		var blank_map_point: Vector2 = game._map_rect().position + Vector2(10, 10)
		await mouse(blank_map_point, true); await mouse(blank_map_point, false); await settle()
		check(not game._panel_has_context() and game.panel.size.x == 280, "Clicking empty map restores the automatic leaderboard")
		game._left_click(game.rig[game.PLAYER], false); game._refresh_panel(); await settle()
		var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
		game._input(escape); await settle()
		check(not game._panel_has_context() and not game.menu_open, "Escape clears node details to the automatic leaderboard")
		game._input(escape); await settle()
		check(game.menu_open and not game.panel.visible, "Escape from compact standings opens the main menu")
		game._input(escape); await settle()
		check(not game.menu_open and game.panel.visible and not game._panel_has_context(), "Closing the menu restores compact standings")
		game._left_click(game.rig[game.PLAYER], false); game._refresh_panel()
		for message in ["Connected 1 building to TRAINING TARGET (dormant - press SCAN or ATTACK on its panel). Travelling packets still arrive.", "Phishing campaign hit the server: steal every resource output for 30 seconds, spreading to the database for 20 seconds and ERP for 10 seconds."]:
			game._flash(message); game._update_chrome(); await settle()
			check(game.feedback_label.visible and game.feedback_label.get_global_rect().end.y <= game._deck_top() - 10, "Wrapped connection/card toast ends above the deck: %s" % resolution)
			check(not game.feedback_label.get_global_rect().intersects(game.panel.get_global_rect()), "Wrapped toast stays inside the map's available width: %s" % resolution)

	# the pull-out deck: pushed down by default; red ATTACK / blue DEFENCE tabs, eight mini cards, a handle and C
	for resolution in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		viewport.size = resolution; fresh(); await settle()
		check(not game._deck_open and not game.hand_panel.visible and game.card_banks.visible and game.deck_chips.visible and game.deck_handle.visible, "Deck starts pushed down to one strip: %s" % resolution)
		check(game.card_banks.get_child(0).text.begins_with("ATTACK") and game.card_banks.get_child(1).text.begins_with("DEFENCE"), "Deck tabs are named ATTACK and DEFENCE")
		var attack_edge: Color = game.card_banks.get_child(0).get_theme_stylebox("normal").border_color
		var defence_edge: Color = game.card_banks.get_child(1).get_theme_stylebox("normal").border_color
		check(attack_edge.r > attack_edge.b + 0.3 and defence_edge.b > defence_edge.r + 0.3, "ATTACK is red and DEFENCE is blue")
		var chips := scripted_nodes(game.deck_chips, game.DeckChip)
		var strip := Rect2(Vector2(24, game._deck_top()), Vector2(resolution.x - 48, game.DECK_BAR_HEIGHT)).grow(1)
		var strip_fits := chips.size() == 8 and strip.encloses(game.deck_handle.get_global_rect()) and strip.encloses(game.card_banks.get_global_rect())
		for chip in chips:
			var r: Rect2 = chip.get_global_rect()
			if not strip.encloses(r) or r.intersects(game.card_banks.get_global_rect()) or r.intersects(game.deck_handle.get_global_rect()) or r.size.x < 84: strip_fits = false
		check(strip_fits, "Tabs, eight readable mini cards and the handle share one strip without overlap: %s" % resolution)
		var closed_map: Rect2 = game._map_rect()
		var defence_tab: Rect2 = game.card_banks.get_child(1).get_global_rect()
		await mouse(defence_tab.get_center(), true); await mouse(defence_tab.get_center(), false); await settle()
		check(game._deck_open and game._card_bank == "defense" and game.hand_panel.visible and not game.deck_chips.visible, "A closed DEFENCE tab pulls the deck up on its cards: %s" % resolution)
		check(closed_map.size.y - game._map_rect().size.y >= game.CARD_DOCK_HEIGHT, "Pushed down, the map gains the whole card height: %s" % resolution)
		check(game.card_banks.get_global_rect().end.y < game.hand_panel.position.y and game.panel.get_global_rect().end.y <= game._deck_top() - 10, "Pulled up, tabs sit above the cards and the sidebar above both: %s" % resolution)
		game.card_banks.get_child(0).pressed.emit(); await settle()
		check(game._deck_open and game._card_bank == "attack", "The other tab switches banks without closing the deck")
		game.card_banks.get_child(0).pressed.emit(); await settle()
		check(not game._deck_open and not game.hand_panel.visible, "The open tab pushes the deck back down")
		game.deck_handle.pressed.emit(); await settle()
		check(game._deck_open and game._card_bank == "attack", "The handle pulls the deck up on the last tab")
		var c_key := InputEventKey.new(); c_key.keycode = KEY_C; c_key.pressed = true
		game._input(c_key); await settle()
		check(not game._deck_open and game._map_rect() == closed_map, "C pushes the deck down and gives the map its full height back")
	viewport.size = Vector2i(1280, 720); fresh(); await settle()
	var phishing_chip: Control = scripted_nodes(game.deck_chips, game.DeckChip)[0]
	var chip_point := phishing_chip.get_global_rect().get_center()
	await mouse(chip_point, true); await mouse(chip_point, false)
	check(game.lab[game.PLAYER].queue == ["phishworm:linked"] and not game._deck_open, "Clicking a mini card queues its research without pulling the deck up")
	game.cards[game.PLAYER]["phishworm:linked"] = 1
	var enemy := -1
	for n in game.hosts[game.rig[game.PLAYER]].links:
		if int(game.hosts[n].owner) != game.PLAYER: enemy = n; break
	await mouse(chip_point, true)
	var pull := InputEventMouseMotion.new(); pull.position = chip_point + Vector2(0, -30); pull.global_position = pull.position
	pull.relative = Vector2(0, -30); pull.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(pull, true); await process_frame
	check(viewport.gui_is_dragging(), "A held copy drags straight from its mini card")
	await mouse(game._w2s(game.hosts[enemy].pos), false); await settle()
	check(game._held(game.PLAYER, "phishworm:linked") == 0 and not game._deck_open, "Dropping a mini card on an enemy plays it; the deck stays down")
	game.cash[game.PLAYER] = 1000; game.creds[game.PLAYER] = 1000; game.research[game.PLAYER] = 1000
	game.lab[game.PLAYER].queue.clear(); game.lab[game.PLAYER].items.clear()
	game._card_research_click("cdn:linked"); game._tick_research(60)
	check(game._held(game.PLAYER, "cdn:linked") == 1 and int(game._bank_alert.get("defense", 0)) > Time.get_ticks_msec(), "A finished DEFENCE card makes its tab blink")
	game._bank_pressed("defense"); await settle()
	check(not game._bank_alert.has("defense") and game._deck_open, "Opening the blinking tab clears the alert")

	# fog of war: you see your hosts, their neighbours and every rig; what you saw stays remembered (dim outline)
	fresh(Vector2i(8, 6), 2); await settle()
	var home: int = game.rig[game.PLAYER]
	var sight: Dictionary = game._visible_set(game.PLAYER)
	var rule_ok := true
	for i in game.hosts.size():
		var expect: bool = int(game.hosts[i].owner) == game.PLAYER or bool(game.hosts[i].rig)
		for o in game.hosts[i].links:
			if int(game.hosts[o].owner) == game.PLAYER: expect = true
		if sight.has(i) != expect or game._visible_to(game.PLAYER, i) != expect: rule_ok = false
	check(rule_ok, "Fog shows exactly your hosts, their neighbours and every rig")
	var far := -1
	for i in game.hosts.size():
		if not sight.has(i): far = i; break
	check(far >= 0 and game._host_at(game._w2s(game.hosts[far].pos)) == -1, "A host in the fog cannot be clicked")
	var rival_rig: int = game.rig[game.RIVAL]
	game._pan = game._map_rect().get_center() - game.hosts[rival_rig].pos * game._zoom
	check(game._host_at(game._w2s(game.hosts[rival_rig].pos)) == rival_rig, "Enemy rigs stay visible and clickable")
	var lost := -1; var edge := -1
	for s in game.hosts.size():
		if not game._mine(s) or s == home: continue
		for x in game.hosts[s].links:
			if game._mine(x) or bool(game.hosts[x].rig) or game.hosts[home].links.has(x): continue
			lost = s; edge = int(x); break
		if lost >= 0: break
	if lost < 0:   # make one: take a host two streets out, then lose it again
		for y in game.hosts.size():
			if game._mine(y) or bool(game.hosts[y].rig) or game.hosts[home].links.has(y): continue
			game._capture(y, game.PLAYER)
			for x in game.hosts[y].links:
				if game._mine(x) or bool(game.hosts[x].rig): continue
				var other := false
				for o in game.hosts[x].links:
					if int(o) != y and game._mine(int(o)): other = true
				if not other: lost = y; edge = int(x); break
			if lost >= 0: break
	check(lost >= 0, "Fog memory fixture found a host that only one building could see")
	if lost >= 0:
		game._capture(lost, game.RIVAL)
		check(not game._visible_to(game.PLAYER, edge) and game._explored(game.PLAYER, edge) and not game._last_seen(game.PLAYER, edge).is_empty(), "A host that slips into the fog stays remembered as last seen")
		check(int(game._last_seen(game.PLAYER, lost).get("owner", -1)) == game.RIVAL, "You remember who took your building")
	var hidden := {"route": [far, far], "hops": [game._t - 0.1], "owner": game.RIVAL, "kind": "bot"}
	var shown := {"route": [home, home], "hops": [game._t - 0.1], "owner": game.RIVAL, "kind": "bot"}
	check(not game._flight_visible(game.PLAYER, hidden) and game._flight_visible(game.PLAYER, shown), "Rival packets are seen only where you have sight")
	var landmark := -1; var out_of_sight := -1   # a rival rig you only see through fog: the rig, not what it sends
	for r in game.rig.values():
		if int(r) != home and not game._in_sight(game.PLAYER, int(r)): landmark = int(r); break
	if landmark >= 0:
		for x in game.hosts[landmark].links:
			if not game._in_sight(game.PLAYER, int(x)): out_of_sight = int(x); break
	check(landmark >= 0 and out_of_sight >= 0 and game._visible_to(game.PLAYER, landmark), "Fixture: a rival rig seen only through fog, with a neighbour out of sight")
	var from_rig := {"route": [landmark, out_of_sight], "hops": [game._t - 0.1], "owner": int(game.hosts[landmark].owner), "kind": "bot"}
	check(not game._flight_visible(game.PLAYER, from_rig) and not game._sight_set(game.PLAYER).has(landmark), "A rig seen through fog shows no packets it sends")
	check(game._tut_rich("Click Intel harvester").contains(game.BUILD_KINDS.intel.col.to_html(false)) and game._tut_rich("Press Scan on TRAINING TARGET").count("[color=") == 2, "Tutorial keywords take their colour without nesting")
	game._open_menu(true); game._menu_view = "feedback"; game._refresh_menu(); await settle()
	var focus_style: StyleBox = game.fb_details.get_theme_stylebox("focus")
	check(focus_style is StyleBoxFlat and focus_style.expand_margin_left == 0.0 and not focus_style.draw_center, "The feedback field's focus outline is drawn inside it, so no side is clipped")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
