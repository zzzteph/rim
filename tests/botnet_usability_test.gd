extends SceneTree
## Run: godot --headless --path . --script tests/botnet_usability_test.gd
## Add -- --capture with a rendering driver to save the layout fixtures.

var game
var vp: SubViewport
var checks := 0
var failures: Array = []
var capture := false
var output := "res://review/implemented_ui"

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); push_error(description)

func fresh(map_size := Vector2i(6, 4)) -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scripts/botnet_proto.gd").new()
	game.theme = load("res://assets/ui_theme.tres")
	game._opt_seed = 7; game._opt_shape = "grid"; game._opt_size = map_size
	vp.add_child(game)
	game.set_process(false); game.ai_enabled = false
	game.set_anchors_preset(Control.PRESET_TOP_LEFT); game.size = Vector2(vp.size)
	game._open_menu(false); game._layout_ui(); game._fit_view()

func settle() -> void:
	game._update_chrome(); game._refresh_panel(); game.queue_redraw(); game.hud.queue_redraw()
	for i in 4: await process_frame

func advance(seconds: float) -> void:
	for i in int(round(seconds * 60)): game._process(1.0 / 60.0)

func neighbor(source: int) -> int:
	for i in game.hosts[source].links:
		if int(game.hosts[i].owner) == game.NEUTRAL: return i
	return -1

func find_button(node: Node, term: String) -> Button:
	if node is Button and (term in node.text or term == str(node.name)): return node
	for child in node.get_children():
		var found := find_button(child, term)
		if found != null: return found
	return null

func scripted_nodes(node: Node, script: Script) -> Array:
	var found := []
	if node.get_script() == script and (script != game.CardTile or node.visible): found.append(node)
	for child in node.get_children(true): found.append_array(scripted_nodes(child, script))
	return found

func panel_fits(description: String) -> void:
	var visible_area: Rect2 = game.panel_scroll.get_global_rect()
	var content: Rect2 = game.panel_box.get_global_rect()
	check(content.position.x >= visible_area.position.x and content.end.x <= visible_area.end.x + 1, description)
	check(game.panel.get_global_rect().encloses(visible_area) and game.panel.get_global_rect().end.y <= game._deck_top() - 10, "Sidebar stays above the deck")
	check(content.size.y <= visible_area.size.y + 1 or game.panel_scroll.get_v_scroll_bar().visible, "Overflowing sidebar content remains reachable by vertical scrolling")

func visible_controls(node: Node) -> Array:
	var visible := []
	for child in node.get_children():
		if child is Control and child.visible: visible.append(child.get_instance_id())
	return visible

func has_tooltips(node: Node) -> bool:
	if node is Control and not node.tooltip_text.is_empty(): return true
	for child in node.get_children():
		if has_tooltips(child): return true
	return false

func mouse(at: Vector2, pressed: bool, double_click := false) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = at; motion.global_position = at
	vp.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = at; event.global_position = at; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	event.double_click = double_click
	vp.push_input(event, true)
	await process_frame

func shot(name: String) -> void:
	await settle()
	if capture:
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(output + "/" + name + ".png")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1, 1); root.position = Vector2i(-20000, -20000)
	vp = SubViewport.new(); vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	fresh()
	await settle()
	var source: int = game.rig[game.PLAYER]
	var target := neighbor(source)
	await mouse(game._w2s(game.hosts[source].pos), true)
	await mouse(game._w2s(game.hosts[target].pos), false)
	await settle()
	check(game.hosts[source].assign == target and not game.hosts[source].live and game._inspect == target, "Drag connects and opens target without launching")
	var scan_button := find_button(game.panel, "Scan")
	check(scan_button != null and find_button(game.panel, "Attack") == null, "Unscanned target offers only Scan")
	var scan_point := scan_button.get_global_rect().get_center()
	await mouse(scan_point, true); await mouse(scan_point, false); await settle()
	check(find_button(game.panel, "Stop") != null and find_button(game.panel, "Scan") == null, "Active scan offers only Stop")
	advance(30); await settle()
	check(game._scanned(game.PLAYER, target) and not game.hosts[source].live, "Scan completes without automatically attacking")
	var attack := find_button(game.panel, "Attack")
	check(attack != null and find_button(game.panel, "Scan") == null, "Completed scan replaces Scan with Attack")
	if attack != null:
		var point := attack.get_global_rect().get_center()
		await mouse(point, true)
		game._process(0.3) # a heartbeat must not eat the release
		await mouse(point, false)
	await settle()
	check(game.hosts[source].live and game.hosts[source].mode == "attack", "Actual button press survives a live refresh")
	check("Attacking" in game._panel_text() and not "Scanning" in game._panel_text(), "Attack is not mislabelled scanning")
	var second := -1
	for i in game.hosts.size():
		if game._mine(i) and i != source: second = i; break
	game._link(second, target); game.sel = {second:true}; game._wire(target)
	check(game.hosts[second].live, "New source autojoins an existing attack")
	game.intel[game.PLAYER] = 0.0
	await shot("01_attack_waiting_for_intel")
	panel_fits("Blocked operation stays inside the sidebar width")
	check("Waiting for Intel" in game._panel_text(), "Persistent Intel blocker names its recovery action")
	var stop := find_button(game.panel, "Stop")
	var stop_id := stop.get_instance_id() if stop != null else -1
	game._refresh_panel()
	check(find_button(game.panel, "Stop").get_instance_id() == stop_id, "Unchanged command button retains its identity")
	game._halt(target)
	check(game.hosts[source].assign == target and not game.hosts[source].live, "Stop retains connections")
	game.scans[game.PLAYER].erase(target)
	game._launch(target, "scan"); game.intel[game.PLAYER] = 50
	game._emit_due()
	check(game._scan_pending(game.PLAYER, target), "Scout queued")
	var scout_count := 0
	for f in game.flights:
		if f.kind == "scan" and f.route.back() == target: scout_count += 1
	check(scout_count == 1, "Several sources share one pending scout")
	game._mark_scanned(game.PLAYER, target); game._halt(target); game._launch(target, "scan")
	check(not game.hosts[source].live, "Scan of known target never silently launches an attack")

	fresh(); source = game.rig[game.PLAYER]
	game._set_builds(source, [])
	game.intel[game.PLAYER] = 60   # a harvester (10) and a miner (50) can both be queued; neither price is reserved
	game._start_job(source, "intel", 0); game._start_job(source, "cash", 1)
	game.intel[game.PLAYER] = 1
	game._tick_jobs(1)
	var share: float = 1.0 / ((float(game.BUILD_COSTS.intel.intel) + float(game.BUILD_COSTS.cash.intel)) / float(game.BUILD_TIME))   # 1 Intel over both jobs' demand
	check(is_equal_approx(float(game.hosts[source].jobs[0].left), game.BUILD_TIME - share) and is_equal_approx(float(game.hosts[source].jobs[1].left), game.BUILD_TIME - share), "Partial funding produces proportional, fair progress")
	check(is_zero_approx(float(game.intel[game.PLAYER])), "Job funding has exact resource accounting")
	game.sel = {source:true}
	await shot("02_funded_construction")
	panel_fits("Construction slots and palette stay inside the sidebar width")
	var slots := scripted_nodes(game.panel, game.SlotBox)
	var palette := scripted_nodes(game.panel, game.BuildCard)
	check(slots[0].size.x == palette[0].size.x, "Slots and building cards have equal width")
	var slot_point: Vector2 = slots[0].get_global_rect().position + Vector2(36, 30)
	await mouse(slot_point, true); await mouse(slot_point, false)
	check(bool(game.hosts[source].jobs[0].get("paused", false)), "Clicking a construction slot pauses it")
	var work_before: float = game.hosts[source].jobs[0].left
	game.intel[game.PLAYER] = 30; game._tick_jobs(1)
	check(game.hosts[source].jobs[0].left == work_before and is_equal_approx(float(game.intel[game.PLAYER]), 30.0 - float(game.BUILD_COSTS.cash.intel) / game.BUILD_TIME), "Paused job does not spend Intel; other job continues")
	await shot("construction_paused")
	check(slots[0].get_global_rect().encloses(slots[0].stop_button.get_global_rect()), "Construction stop spans the bottom without escaping the card")
	var cancel: Button = slots[0].stop_button
	await mouse(cancel.get_global_rect().get_center(), true)
	game._refresh_panel()
	await mouse(cancel.get_global_rect().get_center(), false)
	check(not game.hosts[source].jobs.has(0) and game.hosts[source].jobs.has(1), "Red slot stop cancels only its own job across a refresh")
	fresh(); source = game.rig[game.PLAYER]; target = neighbor(source)
	game._set_builds(target, []); game.hosts[target].bots = 100
	game.intel[game.PLAYER] = 10; game._start_job(source, "intel", 2)
	game.sel = {source:true}; game._wire(target); game._launch(target, "attack")
	game.intel[game.PLAYER] = 0
	advance(10.5)   # the 9th hit lands at exactly t = 10 s; the margin keeps the check off that rounding boundary
	check(float(game.hosts[target].bots) < 92, "Construction cannot consume fractional Intel before attack packets can depart")
	check(float(game.hosts[source].jobs[2].left) > 9.9, "Starved construction waits without losing paid work")
	check(absf(game._observed_net("intel")) < 0.3, "Observed Intel net reflects actual spending")
	game._set_builds(source, ["bot", "intel"]); game.hosts[source].bots = 25
	var before: int = game._stage(source)
	game._set_builds(source, ["bot", "intel", "bot"])
	check(game._stage(source) == before and game._count(source, "intel") > 0, "Extra storage cannot deactivate a working harvester")
	fresh(); source = game.rig[game.PLAYER]; target = neighbor(source)
	game._set_builds(source, []); game.intel[game.PLAYER] = 10
	game._start_job(source, "intel", 0)
	game.sel = {source:true}; game._wire(target); game._launch(target, "attack")
	game.hosts[source].route_off = 10; game.intel[game.PLAYER] = 0.5
	game._tick_jobs(1)
	check(is_equal_approx(float(game.hosts[source].jobs[0].left), 9.5) and is_zero_approx(float(game.intel[game.PLAYER])), "Routing-disabled attacks leave available Intel for construction")

	fresh()
	game.paused = true; game._open_menu(true); game._open_menu(false)
	check(game.paused, "Menu close preserves manual pause")
	game.paused = false; game._open_menu(true)
	var space := InputEventKey.new(); space.keycode = KEY_SPACE; space.pressed = true
	game._input(space); advance(1)
	check(game._t == 0 and not game.paused, "Space cannot run simulation behind menu")
	game._menu_view = "newgame"; game._refresh_menu(); game.menu_seed_edit.text = "12345"
	game._opt_size = Vector2i(6, 4); game._refresh_menu()
	check(game.menu_seed_edit.text == "12345", "Seed draft survives changing options")
	game.menu_seed_edit.text = "oops"; game._start_new_game()
	check(game.menu_open, "Invalid seed is rejected instead of silently becoming random")
	game._menu_view = "feedback"; game._refresh_menu()
	game.fb_details.text = "Space R L 0 should be ordinary text here."
	game.fb_name.text = "Test draft"; game._fb_rating = 4; game._refresh_menu()
	check(game.fb_details.text == "Space R L 0 should be ordinary text here." and game.fb_name.text == "Test draft", "Feedback drafts survive rating changes")
	game.fb_details.grab_focus(); game._input(space)
	check(not game.paused, "Typing in a text field never triggers the pause shortcut")
	await shot("feedback_compact")
	check(game.fb_version == null, "Feedback does not ask for a version")
	check(game.menu_panel.get_global_rect().encloses(game.menu_box.get_global_rect()) and not game.menu_sc.get_v_scroll_bar().visible, "Feedback fits without scrolling")

	fresh(); source = game.rig[game.PLAYER]
	game._hold[game.PLAYER] = 44.9
	game.hosts[source].bots = 0; game._capture(source, game.RIVAL)
	check(game.lost and not game.won, "Rig loss resolves before majority victory")
	check(game.HOLD_SECS == 51.0 and game._hold_need(100) == 51 and game._hold_need(31) == 16 and game._hold_need(50) == 26 and game._hold_need(37) == 19, "Winning needs at least 51% of the town held for 51 seconds")
	var clock_before: float = game._t; advance(2)
	check(game._t == clock_before, "Result freezes simulation")
	fresh(); var enemy_rig: int = game.rig[game.RIVAL]
	game._capture(enemy_rig, game.PLAYER)
	check(game._eliminated.has(game.RIVAL) and game._faction_nodes(game.RIVAL) == 0, "Rivals also lose when their rig falls")
	game.cards[game.RIVAL]["phishworm:linked"] = 1
	check(game._can_play(game.RIVAL, "phishworm:linked", game.rig[game.PLAYER]) != "", "Eliminated rivals cannot cast from a captured rig")
	check("75" in game._effect_text(game.CARDS.zeroday, enemy_rig, 1.5), "0day preview explains its 75% capture chance")
	fresh(); source = game.rig[game.PLAYER]; target = neighbor(source)
	game.cards[game.PLAYER]["phishworm:linked"] = 1
	game.hosts[source].route_off = 25
	check(game._can_play(game.PLAYER, "phishworm:linked", target) != "", "A routing-disabled rig cannot launch a card")
	check(not game._play_card(game.PLAYER, "phishworm:linked", target) and game._held(game.PLAYER, "phishworm:linked") == 1 and game.flights.is_empty(), "Blocked card launch preserves the held card without creating a packet")
	game.hosts[source].route_off = 0
	check(game._play_card(game.PLAYER, "phishworm:linked", target), "Card launch resumes when rig routing recovers")
	fresh(); source = game.rig[game.PLAYER]
	game.hosts[source].slots = 5; game.hosts[source].type = "erp"; game.hosts[source].bots = 30
	game._set_builds(source, ["cash", "cred", "lab", "intel", "intel"])
	var production_before := Vector4(game._cash_rate(game.PLAYER), game._cred_rate(game.PLAYER), game._research_rate(game.PLAYER), game._intel_rate(game.PLAYER))
	game._apply_effect(game.RIVAL, game.CARDS.phishworm, source)
	check(game._benef(source) == game.RIVAL, "Phishing campaign diverts production while its caster is active")
	game._capture(game.rig[game.RIVAL], game.PLAYER)
	var production_restored := Vector4(game._cash_rate(game.PLAYER), game._cred_rate(game.PLAYER), game._research_rate(game.PLAYER), game._intel_rate(game.PLAYER))
	check(not game.won and not game.lost and game._benef(source) == game.PLAYER and production_restored.is_equal_approx(production_before), "Eliminating a Phishing campaign caster restores all victim production during the match")
	var eliminated_cash: float = game.cash[game.RIVAL]
	advance(1)
	check(is_equal_approx(float(game.cash[game.RIVAL]), eliminated_cash), "An eliminated faction receives no further stolen Crypto")

	for resolution in [Vector2i(1280, 720), Vector2i(1366, 768)]:
		vp.size = resolution
		for map_size in game.SIZE_PRESETS:
			fresh(map_size)
			game._left_click(game.rig[game.RIVAL], false)
			await shot("layout_%dx%d_map_%dx%d" % [resolution.x, resolution.y, map_size.x, map_size.y])
			check(game._map_rect().grow(-20).has_point(game._w2s(game.hosts[game._inspect].pos)), "Selected target stays visible: %s / %s" % [resolution, map_size])
			check(game.CARD_ORDER == ["phishworm", "zeroday", "ddos", "supply", "cdn", "patch", "response", "sca"], "Four attacks and four protection cards exist")
			game._set_deck_open(true); await settle()
			check(game._map_rect().grow(-20).has_point(game._w2s(game.hosts[game._inspect].pos)), "Pulling the deck up keeps the selected target visible: %s / %s" % [resolution, map_size])
			var tiles := scripted_nodes(game.hand_panel, game.CardTile)
			check(tiles.size() == 4 and game.hand_panel.visible, "All four cards are visible at zero copies")
			var cards_fit := true
			for tile in tiles:
				if not game.hand_panel.get_global_rect().encloses(tile.get_global_rect()): cards_fit = false
				if not game._card_research_state(tile.key).count == 0: cards_fit = false
			check(cards_fit, "Four zero-copy cards fit in the permanent dock")
			check(game.hand_panel.size.x == resolution.x - 48 and game.hand_panel.size.y == 264 and tiles[0].size.y == 264 and tiles[0].size.x >= 240, "Four large detailed cards retain the full-width 264px dock")
			check(game.panel.get_global_rect().end.y <= game.hand_panel.position.y - 10 and not game.panel.get_global_rect().intersects(game.hand_panel.get_global_rect()), "Sidebar ends above the full-width card dock")
			panel_fits("Foreign node panel fits at each map size")
			game._fit_view()
			var all_visible := true
			for host in game.hosts:
				if not game._map_rect().has_point(game._w2s(host.pos)): all_visible = false
			check(all_visible, "Fit town includes every node")
			var zoom_before: float = game._zoom
			game._zoom_at(game._map_rect().get_center(), 1 / 1.15)
			check(game._zoom <= zoom_before, "Wheel zoom never jumps in at the fit-town scale")
		game._clear_all(); await shot("automatic_leaderboard_%d" % resolution.x)
		check(game.panel.visible and not game._panel_has_context() and game._panel_width() == 280, "Clearing node selection restores the automatic compact leaderboard")
		check(game.hand_panel.visible and scripted_nodes(game.hand_panel, game.CardTile).size() == 4, "Four detailed cards stay visible with the automatic leaderboard")
		check("Leaderboard" in game._panel_text() and not "cards played" in game._panel_text(), "Default sidebar displays faction standings")

	vp.size = Vector2i(1280, 720); fresh(); game._set_deck_open(true); await settle()
	check(find_button(game.top_tabs, "RESEARCH") == null, "Top bar has no Research button")
	check(find_button(game.top_tabs, "BOARD") == null and find_button(game.top_tabs, "Board") == null, "Top bar has no Board button")
	var research_key := InputEventKey.new(); research_key.keycode = KEY_R; research_key.pressed = true
	game._input(research_key); await settle()
	check(game.panel.visible and not game._panel_has_context() and "Leaderboard" in game._panel_text(), "R leaves the automatic leaderboard in place without opening Research")
	var board_key := InputEventKey.new(); board_key.keycode = KEY_L; board_key.pressed = true
	var leaderboard_identity: int = game.panel_box.get_instance_id()
	game._input(board_key); await settle()
	check(not game._panel_has_context() and game.panel_box.get_instance_id() == leaderboard_identity, "Removed L shortcut leaves the automatic leaderboard unchanged")
	check("Crypto" in game._hud_text() and not "Cash" in game._hud_text(), "HUD resource text uses Crypto consistently")
	check(not has_tooltips(game), "Card and map controls have no tooltips")
	var tiles := scripted_nodes(game.hand_panel, game.CardTile)
	var campaign: Control = tiles[0]
	var point := campaign.get_global_rect().get_center()
	await mouse(point, true); game._refresh_hand(); await mouse(point, false)
	check(game.lab[game.PLAYER].queue == ["phishworm:linked"], "Single click on a permanent card queues its research")
	check(game._card_research_state("phishworm:linked").status == "Researching", "Current research is identified immediately")
	game.cash[game.PLAYER] = 100; game.creds[game.PLAYER] = 100; game.research[game.PLAYER] = 100
	var zero_day: Control = tiles[1]
	await mouse(zero_day.get_global_rect().get_center(), true); await mouse(zero_day.get_global_rect().get_center(), false)
	game._tick_research(2)
	check(game._card_research_state("zeroday:linked").status == "Queued", "Waiting queue card is visibly distinguished from current research")
	check(float(game._card_research_state("phishworm:linked").progress) > 0, "The active card reports visible progress")
	await shot("four_cards_researching")
	await mouse(point, true); await mouse(point, false)
	var saved_progress: float = game.lab[game.PLAYER].items[0].progress
	game._tick_research(1)
	check(game.lab[game.PLAYER].items[0].progress == saved_progress and float(game.lab[game.PLAYER].items[1].progress) > 0, "Pausing one card preserves progress and lets the next card work")
	check(game._card_research_state("phishworm:linked").status == "Paused" and game._card_research_state("zeroday:linked").status == "Researching", "Paused and active statuses identify the working item")
	await shot("four_cards_paused")
	var research_cancel: Button = zero_day.stop_button
	var stop_point := research_cancel.get_global_rect().get_center()
	await mouse(stop_point, true); game._refresh_hand(); await mouse(stop_point, false)
	check(game.lab[game.PLAYER].queue == ["phishworm:linked"] and game.lab[game.PLAYER].items[0].progress == saved_progress, "Embedded cancel preserves the other card's paid work across refresh")
	await mouse(point, true); await mouse(point, false)
	game._tick_research(42)
	check(game._held(game.PLAYER, "phishworm:linked") == 1 and game._card_research_state("phishworm:linked").status == "Ready", "Resumed research completes once and shows its held copy")
	await shot("four_cards_ready")
	await mouse(point, true); await mouse(point, false); game._tick_research(1)
	check(game._card_research_state("phishworm:linked").count == 1 and game._card_research_state("phishworm:linked").status == "Researching" and float(game._card_research_state("phishworm:linked").progress) > 0, "A held x1 copy keeps the next copy's active progress visible on its card")
	check(scripted_nodes(game.hand_panel, game.CardTile).size() == 4, "Research queue and inventory share four permanent unique tiles")

	var card_rect: Rect2 = campaign.get_global_rect()
	var before_hover := visible_controls(game)
	var hover := InputEventMouseMotion.new(); hover.position = point; hover.global_position = point
	vp.push_input(hover, true); await settle()
	check(campaign.get_global_rect() == card_rect and visible_controls(game) == before_hover, "Hover decorates the permanent card without creating an overlay over the map")
	check(game.hand_panel.get_global_rect().encloses(card_rect), "Detailed card stays inside the permanent dock while hovered")
	check("30 / 20 / 10" in game._research_effect("phishworm:linked") and "30 / 20 / 10 / 5 / 2" in game._research_effect("ddos:linked"), "Permanent card descriptions expose exact durations for successive spreading nodes")
	await shot("detailed_card_x1_researching_hover")
	game._left_click(game.rig[game.PLAYER], false); await settle()
	check(game.hand_panel.visible and campaign.get_instance_id() == scripted_nodes(game.hand_panel, game.CardTile)[0].get_instance_id(), "Selecting a building preserves all permanent card controls")
	check(game._panel_has_context() and game._panel_width() == 620 and "Node buildings" in game._panel_text(), "Owned-node details replace the compact leaderboard with the full sidebar")
	game._clear_all(); game._refresh_panel(); await settle()
	check(game.panel.visible and not game._panel_has_context() and game._panel_width() == 280 and game.hand_panel.visible, "Clearing details restores the compact leaderboard beside the same card dock")

	await mouse(point, true)
	var drag := InputEventMouseMotion.new()
	drag.position = point + Vector2(20, -20); drag.global_position = drag.position
	drag.relative = Vector2(20, -20); drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(drag, true); await settle()
	check(vp.gui_is_dragging(), "A held copy starts native drag from its detailed card")
	check(not game._deck_open and not game.hand_panel.visible and game._deck_drag_restore, "Dragging a big card pushes the deck down so the whole map is a target")
	var previews := scripted_nodes(vp, game.CardDragPreview)
	check(previews.size() == 1 and previews[0].size.y < campaign.size.y and previews[0].size.x < campaign.size.x, "Dragging uses one compact preview instead of an enlarged card over the map")
	var card_target := neighbor(game.rig[game.PLAYER])
	await mouse(game._w2s(game.hosts[card_target].pos), false); await settle()
	check(game._held(game.PLAYER, "phishworm:linked") == 0, "Drag plays one held copy from the deck")
	check(game._deck_open and game.hand_panel.visible and not game._deck_drag_restore, "The deck comes back up once the card is dropped")
	check(game._card_queue_index("phishworm:linked") >= 0 and game._card_research_state("phishworm:linked").status == "Researching", "Playing a held copy preserves its next research item")
	await shot("four_cards_after_play")

	fresh(); game._card_research_click("phishworm:linked")
	game.cash[game.PLAYER] = 0; game.creds[game.PLAYER] = 100; game.research[game.PLAYER] = 100
	game._tick_research(1.0 / 60)
	check(game._card_research_state("phishworm:linked").status == "Waiting", "Card shows sustained resource starvation")
	for frame in 10:
		game.cash[game.PLAYER] = 1 if frame % 2 == 0 else 0
		game._tick_research(1.0 / 60)
		check(game._card_research_state("phishworm:linked").status == "Waiting", "Intermittent resource arrivals do not blink the visible waiting state")
	game.cash[game.PLAYER] = 100; game._tick_research(1)
	check(game._card_research_state("phishworm:linked").status == "Researching", "Stable funding restores the active research status")
	await shot("four_cards_waiting_recovered")
	for card in ["zeroday", "ddos", "supply"]: game._card_research_click(game._card_key(card, "linked"))
	check(game.lab[game.PLAYER].queue.size() == 4 and scripted_nodes(game.hand_panel, game.CardTile).size() == 4, "Four queued cards remain four unique bottom tiles")
	await shot("four_cards_full_queue")
	game._open_menu(true); await settle()
	check(not game.hand_panel.visible and not game.card_banks.visible and not game.deck_chips.visible and not game.panel.visible, "Main menu hides the deck and sidebar")
	game._open_menu(false); await settle()
	check(game.card_banks.visible and game.hand_panel.visible == game._deck_open and game.panel.visible and not game._panel_has_context() and game.lab[game.PLAYER].queue.size() == 4, "Returning to play restores the deck as it was, the compact standings and card research")

	fresh(); source = game.rig[game.PLAYER]; target = neighbor(source)
	game._left_click(target, false); await settle()
	var fixed_slot_rect: Rect2 = scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect()
	game.sel = {source:true}; game._wire(target); await settle()
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Connecting preserves unknown target slot position: %s vs %s" % [scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect(), fixed_slot_rect])
	game._launch(target, "scan"); await settle()
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Starting Scan preserves target slot position: %s vs %s" % [scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect(), fixed_slot_rect])
	game._mark_scanned(game.PLAYER, target); game._halt(target); await settle()
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Revealing contents preserves target slot position")
	game._launch(target, "attack"); await settle()
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Starting Attack preserves target slot position")
	game._disconnect_source(source); await settle()
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Disconnecting preserves target slot position")
	game.scans[game.PLAYER].erase(target); game.hosts[target].bots = 73
	check(game._visible_bot_count(target) == "?" and not "73" in game._stage_line(target), "Unscanned enemy strength is hidden on map and sidebar")
	game._mark_scanned(game.PLAYER, target)
	check(game._visible_bot_count(target) == "73", "Completed Scan reveals enemy strength")
	game.scans[game.PLAYER][target].done = false
	check(game._visible_bot_count(target) == "?" and not "73" in game._stage_line(target), "Stale scan memory cannot reveal an estimated enemy count")
	game._left_click(source, false)
	game.hosts[source].slots = 5; game._set_builds(source, ["bot", "intel", "cash", "cred", "lab"])
	await shot("building_dashboard")
	panel_fits("Five-slot building dashboard stays reachable above the permanent cards")
	var built_cards := scripted_nodes(game.panel, game.SlotBox)
	var available_cards := scripted_nodes(game.panel, game.BuildCard)
	check(built_cards[0].size == available_cards[0].size, "Built and available building cards have identical dimensions")
	check(game.card_banks.visible and game.panel.get_global_rect().end.y <= game._deck_top() - 10, "The deck stays below the node sidebar")
	game.sel = {source:true}; game._wire(target); game._launch(target, "attack"); await settle()
	check(find_button(game.panel, "Attack") == null and find_button(game.panel, "Scan") == null and find_button(game.panel, "Stop") != null, "Running operation has one contextual Stop control")
	await shot("consistent_target_dashboard")
	game.hosts[target].slots = 5; game._set_builds(target, ["bot", "intel", "cash", "cred", "lab"])
	game._mark_scanned(game.PLAYER, target); await shot("scanned_connected_target")
	panel_fits("Scanned target contents and connections fit together")

	fresh(); await settle()
	var attack_tiles := scripted_nodes(game.hand_panel, game.CardTile)
	game.cards[game.PLAYER]["cdn:linked"] = 1
	game.cash[game.PLAYER] = 1000; game.creds[game.PLAYER] = 1000; game.research[game.PLAYER] = 1000
	game._card_research_click("cdn:linked"); game._tick_research(22.5); game._update_chrome()
	check("50%" in game.card_banks.get_child(1).text, "Hidden protection research shows its progress in the bank selector")
	var bank_button: Button = game.card_banks.get_child(1)
	await mouse(bank_button.get_global_rect().get_center(), true); await mouse(bank_button.get_global_rect().get_center(), false); await settle()
	var protection_tiles := scripted_nodes(game.hand_panel, game.CardTile)
	check(game._card_bank == "defense" and protection_tiles.size() == 4 and protection_tiles[0].key == "cdn:linked", "Protection selector switches to four large defensive cards")
	check(game.card_banks.get_global_rect().end.y < game.hand_panel.position.y, "Bank selectors stay above the cards without covering their titles")
	check(game.hand_bar.get_child_count() == 8 and protection_tiles[0].size == attack_tiles[0].size, "Both banks retain permanent card identity and equal card dimensions")
	check(game._card_research_state("cdn:linked").count == 1 and game._card_research_state("cdn:linked").progress == 0.5, "Owned copy and next-copy progress coexist on defensive card")
	await shot("protection_cards")
	game.card_banks.get_child(0).pressed.emit(); await settle()
	check(scripted_nodes(game.hand_panel, game.CardTile)[0] == attack_tiles[0] and not protection_tiles[0].visible, "Switching banks preserves each tile without showing hidden cards")
	game.card_banks.get_child(1).pressed.emit(); await settle()
	var own: int = game.rig[game.PLAYER]
	check(game._can_drop_data(game._w2s(game.hosts[own].pos), {"card":"cdn:linked"}), "Protection drag accepts owned host on the map")
	game._drop_data(game._w2s(game.hosts[own].pos), {"card":"cdn:linked"}); game._deliver_due(); await settle()
	check(game._production_multiplier(own) == 2 and game._held(game.PLAYER,"cdn:linked") == 0, "Protection drag/drop consumes one copy and applies the effect")
	game._left_click(own,false); game._refresh_panel(); await settle()
	check("CDN x2" in game._panel_text(), "Owned host details display remaining protection duration")
	game._set_builds(own,["cred"]); game._refresh_panel(); await settle()
	var producer: Control = scripted_nodes(game.panel, game.SlotBox)[0]
	await mouse(producer.get_global_rect().position + Vector2(50,60),true); await mouse(producer.get_global_rect().position + Vector2(50,60),false)
	check(game._producer_paused(own,0), "Installed producer pauses using real pointer input")
	fresh()
	if FileAccess.file_exists(game._camp_save_path()): DirAccess.remove_absolute(ProjectSettings.globalize_path(game._camp_save_path()))
	game._start_campaign(0); game.set_process(false)
	await shot("campaign_01_connect")
	check(game._camp and game._camp_chapter == 0 and game._tut_stage == 0 and game._camp_paused, "Campaign chapter 1 opens paused for reading at step 1")
	check(find_button(game.tut_panel, "Leave & resume later") == null and game.tut_panel.get_global_rect().encloses(game.tut_box.get_global_rect()), "The training banner has no buttons and its text fits inside it")
	var relay = game._camp_relay
	game.sel = {relay: true}; advance(0.3)
	check(game._tut_stage == 0, "Selecting the target does not advance — only the outcome does")
	game.sel = {game._camp_home: true}; game._wire(relay); advance(0.3)
	check(game._tut_stage == 0 and game._camp_hold_left > 0.0, "Connecting finishes the step: its result shows before the next one")
	advance(game.CAMP_HOLD_STEP)
	check(game._tut_stage == 1, "After the result, the scan lesson begins (outcome, not the click)")
	game._launch(relay, "attack"); advance(0.5)
	check(game._tut_stage == 1, "Starting an attack does not satisfy the scan lesson")
	game._mark_scanned(game.PLAYER, relay); advance(0.3 + game.CAMP_HOLD_STEP)
	check(game._tut_stage == 2, "A completed scan advances the lesson (after its result)")
	game._camp_set_pause(false); advance(40)
	check(game._mine(relay), "Chapter 1 reaches the capture of the Neighborhood Relay")
	# the reading pause truly freezes the simulation
	game._start_campaign(1); game._camp_set_pause(true)
	var frozen = game._t; advance(2)
	check(game._t == frozen, "A reading pause freezes the whole simulation")
	game._camp_set_pause(false); advance(0.5); check(game._t > frozen, "Resuming advances it again")
	game._camp_leave(); check(game.menu_open, "Leave & resume returns to the menu")
	var report := {"checks": checks, "failures": failures, "scope": "Automated mechanics, synthetic input and layout fixtures; not a human playtest"}
	var file := FileAccess.open(output + "/results.json", FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t")); file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
