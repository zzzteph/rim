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
	game._opt_seed = 7; game._opt_size = map_size
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
	if node.get_script() == script: found.append(node)
	for child in node.get_children(): found.append_array(scripted_nodes(child, script))
	return found

func panel_fits(description: String) -> void:
	check(game.panel.get_global_rect().encloses(game.panel_box.get_global_rect()), description)
	check(not game.panel_scroll.get_v_scroll_bar().visible, "Sidebar has no vertical scrollbar")

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
	panel_fits("Blocked operation fits without scrolling")
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
	game.intel[game.PLAYER] = 10
	game._start_job(source, "intel", 0); game._start_job(source, "cash", 1)
	game.intel[game.PLAYER] = 1
	game._tick_jobs(1)
	check(is_equal_approx(float(game.hosts[source].jobs[0].left), 9.5) and is_equal_approx(float(game.hosts[source].jobs[1].left), 9.5), "Partial funding produces proportional, fair progress")
	check(is_zero_approx(float(game.intel[game.PLAYER])), "Job funding has exact resource accounting")
	game.sel = {source:true}
	await shot("02_funded_construction")
	panel_fits("Construction slots and palette fit without scrolling")
	var slots := scripted_nodes(game.panel, game.SlotBox)
	var palette := scripted_nodes(game.panel, game.BuildCard)
	check(slots[0].size.x == palette[0].size.x, "Slots and building cards have equal width")
	var slot_point: Vector2 = slots[0].get_global_rect().position + Vector2(36, 30)
	await mouse(slot_point, true); await mouse(slot_point, false)
	check(bool(game.hosts[source].jobs[0].get("paused", false)), "Clicking a construction slot pauses it")
	var work_before: float = game.hosts[source].jobs[0].left
	game.intel[game.PLAYER] = 30; game._tick_jobs(1)
	check(game.hosts[source].jobs[0].left == work_before and is_equal_approx(float(game.intel[game.PLAYER]), 29), "Paused job does not spend Intel; other job continues")
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
	advance(10)
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
	var clock_before: float = game._t; advance(2)
	check(game._t == clock_before, "Result freezes simulation")
	fresh(); var enemy_rig: int = game.rig[game.RIVAL]
	game._capture(enemy_rig, game.PLAYER)
	check(game._eliminated.has(game.RIVAL) and game._faction_nodes(game.RIVAL) == 0, "Rivals also lose when their rig falls")
	game.cards[game.RIVAL]["phish:linked"] = 1
	check(game._can_play(game.RIVAL, "phish:linked", game.rig[game.PLAYER]) != "", "Eliminated rivals cannot cast from a captured rig")
	check(not "150" in game._effect_text(game.CARDS.stuff, enemy_rig, 1.5), "Defender removal preview caps at 100 percent")
	fresh(); source = game.rig[game.PLAYER]; target = neighbor(source)
	game.cards[game.PLAYER]["phish:linked"] = 1
	game.hosts[source].route_off = 25
	check(game._can_play(game.PLAYER, "phish:linked", target) != "", "A routing-disabled rig cannot launch a card")
	check(not game._play_card(game.PLAYER, "phish:linked", target) and game._held(game.PLAYER, "phish:linked") == 1 and game.flights.is_empty(), "Blocked card launch preserves the held card without creating a packet")
	game.hosts[source].route_off = 0
	check(game._play_card(game.PLAYER, "phish:linked", target), "Card launch resumes when rig routing recovers")
	fresh(); source = game.rig[game.PLAYER]
	game.hosts[source].slots = 5; game.hosts[source].type = "erp"; game.hosts[source].bots = 30
	game._set_builds(source, ["cash", "cred", "lab", "intel", "intel"])
	var production_before := Vector4(game._cash_rate(game.PLAYER), game._cred_rate(game.PLAYER), game._research_rate(game.PLAYER), game._intel_rate(game.PLAYER))
	game._apply_effect(game.RIVAL, game.CARDS.supply, source)
	check(game._benef(source) == game.RIVAL, "Supplychain diverts production while its caster is active")
	game._capture(game.rig[game.RIVAL], game.PLAYER)
	var production_restored := Vector4(game._cash_rate(game.PLAYER), game._cred_rate(game.PLAYER), game._research_rate(game.PLAYER), game._intel_rate(game.PLAYER))
	check(not game.won and not game.lost and game._benef(source) == game.PLAYER and production_restored.is_equal_approx(production_before), "Eliminating a Supplychain caster restores all victim production during the match")
	var eliminated_cash: float = game.cash[game.RIVAL]
	advance(1)
	check(is_equal_approx(float(game.cash[game.RIVAL]), eliminated_cash), "An eliminated faction receives no further stolen Cash")

	for resolution in [Vector2i(1280, 720), Vector2i(1366, 768)]:
		vp.size = resolution
		for map_size in game.SIZE_PRESETS:
			fresh(map_size)
			game._left_click(game.rig[game.RIVAL], false)
			for card in game.CARD_ORDER: game.cards[game.PLAYER][game._card_key(card, "linked")] = 1
			game._refresh_hand()
			await shot("layout_%dx%d_map_%dx%d" % [resolution.x, resolution.y, map_size.x, map_size.y])
			check(game._map_rect().grow(-20).has_point(game._w2s(game.hosts[game._inspect].pos)), "Selected target stays visible: %s / %s" % [resolution, map_size])
			check(not game.panel.get_global_rect().intersects(game.feedback_label.get_global_rect()) and not game.panel.get_global_rect().intersects(game.hand_panel.get_global_rect()), "Panel, feedback and hand do not overlap: %s" % resolution)
			check(not game.hand_scroll.get_h_scroll_bar().visible, "All eight held cards fit without horizontal scrolling")
			panel_fits("Foreign building panel fits at each map size")
			game._fit_view()
			var all_visible := true
			for host in game.hosts:
				if not game._map_rect().has_point(game._w2s(host.pos)): all_visible = false
			check(all_visible, "Fit town includes every node")
			var zoom_before: float = game._zoom
			game._zoom_at(game._map_rect().get_center(), 1 / 1.15)
			check(game._zoom <= zoom_before, "Wheel zoom never jumps in at the fit-town scale")
		game._set_tab("research")
		await shot("research_%d" % resolution.x)
		check(game.CARD_ORDER.size() == 8, "Catalogue contains the requested eight cards")
		check(game.panel.get_global_rect().encloses(game.panel_box.get_global_rect()), "Entire gallery and ready cards fit without scrolling")
		game._inspect_card("zeroday:linked")
		await shot("card_detail_%d" % resolution.x)
		panel_fits("Card details fit without scrolling")
		game._set_tab("board"); await shot("leaderboard_%d" % resolution.x)
		check(not "Cash" in game._panel_text() and not "cards played" in game._panel_text(), "Board contains only standings")

	vp.size = Vector2i(1280, 720); fresh()
	game._set_tab("research"); await settle()
	var gallery := scripted_nodes(game.panel, game.ResearchTile)
	var phishing: Control = gallery[1]
	var phishing_point := phishing.get_global_rect().get_center()
	await mouse(phishing_point, true)
	await mouse(phishing_point, false)
	check(game.lab[game.PLAYER].queue == ["phish:linked"], "Single click queues research")
	game.cash[game.PLAYER] = 100; game.creds[game.PLAYER] = 100; game.research[game.PLAYER] = 100
	game._queue_research(game.PLAYER, "oneday:linked"); game._tick_research(2)
	await settle()
	var queue_tiles: Array = scripted_nodes(game.pending_research, game.ResearchTile)
	var queue_point: Vector2 = queue_tiles[0].get_global_rect().position + Vector2(40, 55)
	await mouse(queue_point, true); await mouse(queue_point, false)
	var saved_progress: float = game.lab[game.PLAYER].items[0].progress
	game._tick_research(1)
	check(game.lab[game.PLAYER].items[0].progress == saved_progress and float(game.lab[game.PLAYER].items[1].progress) > 0, "Pausing a research card preserves progress and lets the next card work")
	await shot("research_queue_paused")
	panel_fits("Gallery and paused research fit together")
	game._dequeue_research(game.PLAYER, 1)
	check(game.lab[game.PLAYER].items[0].progress == saved_progress, "Cancelling another research card preserves paused work")
	game._toggle_research_item(game.PLAYER, 0); game._tick_research(30)
	check(game._held(game.PLAYER, "phish:linked") == 1, "Resumed research completes exactly once")
	await shot("research_ready_card")
	check(game._rate_tag("intel").contains("+0.0/s"), "HUD always includes an explicit signed rate")
	var ready_tiles: Array = scripted_nodes(game.hand_panel, game.CardTile)
	var ready_start: Vector2 = ready_tiles[0].get_global_rect().get_center()
	await mouse(ready_start, true)
	var ready_motion := InputEventMouseMotion.new()
	ready_motion.position = ready_start + Vector2(20, -20); ready_motion.global_position = ready_motion.position
	ready_motion.relative = Vector2(20, -20); ready_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(ready_motion, true)
	for frame in 3: await process_frame
	check(vp.gui_is_dragging() and not game.panel.visible, "Dragging ready research reveals the map and preserves the native drag")
	var ready_target := neighbor(game.rig[game.PLAYER])
	await mouse(game._w2s(game.hosts[ready_target].pos), false)
	check(game._held(game.PLAYER, "phish:linked") == 0, "Completed research can be dragged directly from the gallery onto the map")

	fresh(); target = neighbor(game.rig[game.PLAYER])
	game.hosts[target].owner = game.RIVAL; game.hosts[target].type = "erp"
	game.hosts[target].slots = 5; game.hosts[target].value = 3; game.hosts[target].bots = 30
	game._set_builds(target, ["cash", "cred", "lab", "intel", "intel"])
	var supply_before := Vector4(game._cash_rate(game.PLAYER), game._cred_rate(game.PLAYER), game._research_rate(game.PLAYER), game._intel_rate(game.PLAYER))
	game._apply_effect(game.PLAYER, game.CARDS.supply, target)
	var supply_after := Vector4(game._cash_rate(game.PLAYER), game._cred_rate(game.PLAYER), game._research_rate(game.PLAYER), game._intel_rate(game.PLAYER))
	check((supply_after - supply_before).is_equal_approx(Vector4(1.5, 0.75, 0.75, 3)), "Supplychain runtime production matches the executable balance model")
	check(is_equal_approx(float(game.hosts[target].steal_until) - game._t, 22.5), "Supplychain runtime duration includes ERP susceptibility")

	fresh(); game._set_tab("research")
	for card in game.CARD_ORDER: game.cards[game.PLAYER][game._card_key(card, "linked")] = 1
	for card in ["phish", "oneday", "dos", "supply", "zeroday"]:
		game._queue_research(game.PLAYER, game._card_key(card, "linked"))
	await shot("research_full_queue")
	check(game.lab[game.PLAYER].queue.size() == 4, "Research queue rejects a fifth card")
	check(scripted_nodes(game.panel, game.ResearchTile).size() == 8, "Catalogue contains no queue pagination")
	check(scripted_nodes(game.pending_research, game.ResearchTile).size() == 4, "Four pending cards share the dashboard with ready cards")
	check(not game.hand_scroll.get_h_scroll_bar().visible, "Eight ready plus four pending cards fit without scrolling")
	check(not has_tooltips(game), "Research and dashboard have no tooltips")
	panel_fits("Full research catalogue fits above persistent dashboard")
	var pending_tiles := scripted_nodes(game.pending_research, game.ResearchTile)
	var pending_stop: Button = pending_tiles[0].stop_button
	var stop_point := pending_stop.get_global_rect().get_center()
	await mouse(stop_point, true); game._refresh_hand(); await mouse(stop_point, false)
	check(game.lab[game.PLAYER].queue.size() == 3 and game.lab[game.PLAYER].queue[0] == "oneday:linked", "Dashboard stop cancels its card across live refresh")
	game._queue_research(game.PLAYER, "zeroday:linked")
	check(game.lab[game.PLAYER].queue.size() == 4, "Cancelling frees a queue place immediately")
	game._clear_all(); await settle()
	check(game.hand_panel.visible and scripted_nodes(game.pending_research, game.ResearchTile).size() == 4, "Pending research stays visible on the map")
	game._left_click(game.rig[game.PLAYER], false); await shot("pending_research_left")
	check(game.panel.get_global_rect().end.y == vp.size.y - 24, "Right sidebar extends to the bottom margin")
	check(game.pending_research.get_global_rect().end.y <= game.hand_panel.position.y and game.pending_research.get_global_rect().end.x < game.panel.position.x, "Pending research is above ready cards and left of sidebar")
	check(not game.hand_panel.get_global_rect().intersects(game.panel.get_global_rect()), "Ready cards do not cover the expanded sidebar")
	check(not game.hand_scroll.get_h_scroll_bar().visible, "Returning from Research fits the ready cards into the left tray")
	check(scripted_nodes(game.panel, game.BuildCard).size() == 5, "Available building cards are restored to the sidebar")
	check(not has_tooltips(game), "Map controls have no tooltips")

	fresh(); source = game.rig[game.PLAYER]; target = neighbor(source)
	game._left_click(target, false); await settle()
	var fixed_slot_rect: Rect2 = scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect()
	game.sel = {source:true}; game._wire(target); await settle()
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Connecting preserves unknown target slot position")
	game._launch(target, "scan"); await settle()
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Starting a scan preserves target slot position")
	game._mark_scanned(game.PLAYER, target); game._halt(target); await settle()
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Revealing contents preserves target slot position")
	game._launch(target, "attack"); await settle()
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Starting an attack preserves target slot position")
	game._disconnect_source(source); await shot("fixed_target_slots")
	check(scripted_nodes(game.panel, game.PeekSlot)[0].get_global_rect() == fixed_slot_rect, "Disconnecting preserves target slot position")
	game.scans[game.PLAYER].erase(target)
	game.hosts[target].bots = 73
	check(game._visible_bot_count(target) == "?" and not "73" in game._stage_line(target), "Unscanned enemy strength is hidden on map and sidebar")
	game._mark_scanned(game.PLAYER, target)
	check(game._visible_bot_count(target) == "73", "Completed scan reveals enemy strength")
	game.scans[game.PLAYER][target].done = false
	check(game._visible_bot_count(target) == "?" and not "73" in game._stage_line(target), "Stale scan memory cannot leak an estimated enemy count")
	game.sel = {source:true}; game._wire(target); await settle()
	check(find_button(game.panel, "Scan") != null and not "Scout" in game._panel_text(), "Operation controls say Scan")
	await shot("operation_icons")
	game._left_click(source, false)
	game.hosts[source].slots = 5; game._set_builds(source, ["bot", "intel", "cash", "cred", "lab"])
	await shot("building_dashboard")
	panel_fits("Five-slot building dashboard fits with connection controls")
	check("Node buildings" in game._panel_text() and "Available buildings" in game._panel_text(), "Both building rows have explicit headings")
	check(game.pending_research.get_global_rect().end.y < game.hand_panel.position.y and game.pending_research.get_global_rect().end.x < game.panel.position.x, "Pending research sits left of sidebar and above ready cards")
	check(not game.panel_box.get_global_rect().intersects(game.hand_panel.get_global_rect()), "Building controls stay above the card tray")
	check(game._map_rect().end.y > game.hand_panel.position.y + 80, "Map extends behind transparent card dashboard")
	game._zoom = 0.15; game.queue_redraw(); await shot("zoomed_connection_frames")
	var building_panel_rect: Rect2 = game.panel.get_rect()
	var built_cards := scripted_nodes(game.panel, game.SlotBox)
	var available_cards := scripted_nodes(game.panel, game.BuildCard)
	check(built_cards[0].size == available_cards[0].size, "Built and available building cards have identical dimensions")
	var second_source := -1
	for i in game.hosts.size():
		if i != source and game._mine(i): second_source = i; break
	game.hosts[second_source].assign = target
	game._left_click(target, false); await settle()
	check(game.panel.get_rect() == building_panel_rect, "Building and target dashboards have identical size and position")
	var attack_icon := find_button(game.panel, "Attack")
	var scan_icon := find_button(game.panel, "Scan")
	check(attack_icon == null and scan_icon != null, "Unknown target has one contextual action")
	var disconnect_icon := find_button(game.panel, "Disconnect_%d" % source)
	check(disconnect_icon != null and disconnect_icon.size.x < scan_icon.size.x, "Disconnect is a compact control beside a connected node")
	var disconnect_point := disconnect_icon.get_global_rect().get_center()
	await mouse(disconnect_point, true); game._refresh_panel(); await mouse(disconnect_point, false)
	check(game.hosts[source].assign == -1 and game.hosts[second_source].assign == target, "Per-node disconnect preserves the other contributor")
	game._launch(target, "attack"); await settle()
	check(find_button(game.panel, "Attack") == null and find_button(game.panel, "Scan") == null and find_button(game.panel, "Stop") != null, "Running operation has one Stop action")
	await shot("consistent_target_dashboard")
	game.hosts[target].slots = 5; game._set_builds(target, ["bot", "intel", "cash", "cred", "lab"])
	game._mark_scanned(game.PLAYER, target); await shot("scanned_connected_target")
	check(scripted_nodes(game.panel, game.PeekSlot).size() == 5 and "bot capacity" in game._panel_text(), "Connected scanned targets show all buildings and capacity")
	panel_fits("Scanned target contents and connection table fit together")
	check("Source" in game._panel_text() and "Target" in game._panel_text() and "Disconnect" in game._panel_text(), "Connections identify source, target and action in columns")
	var hover_disconnect := find_button(game.panel, "Disconnect_%d" % second_source)
	var hover_size := hover_disconnect.size
	var hover_motion := InputEventMouseMotion.new(); hover_motion.position = hover_disconnect.get_global_rect().get_center()
	vp.push_input(hover_motion, true); await process_frame; await process_frame
	check(hover_disconnect.size == hover_size, "Disconnect size is unchanged on hover")
	check(not game.objective_label.visible and find_button(game.top_tabs, "🧪 RESEARCH") != null, "Top bar hides objective strip and research inventory count")

	fresh(); game._queue_research(game.PLAYER, "phish:linked")
	game.cash[game.PLAYER] = 0; game.creds[game.PLAYER] = 100; game.research[game.PLAYER] = 100
	game._tick_research(1.0 / 60)
	check(game.lab[game.PLAYER].items[0].waiting_for == "cash", "Research reports sustained resource starvation")
	for frame in 10:
		game.cash[game.PLAYER] = 1 if frame % 2 == 0 else 0
		game._tick_research(1.0 / 60)
		check(game.lab[game.PLAYER].items[0].waiting_for == "cash", "Intermittent resource arrivals do not blink the waiting state")
	game.cash[game.PLAYER] = 100; game._tick_research(1)
	check(game.lab[game.PLAYER].items[0].waiting_for == "", "Stable funding clears the waiting state")
	game._set_tab("research"); await settle()
	var dismiss_point := Vector2(400, 680)
	await mouse(dismiss_point, true); await mouse(dismiss_point, false); await settle()
	check(game._tab == "" and not game.panel.visible, "Clicking exposed map through empty dashboard space closes Research")
	check(game.sel.is_empty() and game._inspect == -1, "Research dismissal does not also select or command a map node")
	game._set_tab("research"); await settle()
	var catalogue_card: Control = scripted_nodes(game.panel, game.ResearchTile)[0]
	var catalogue_point := catalogue_card.get_global_rect().get_center()
	await mouse(catalogue_point, true); await mouse(catalogue_point, false)
	check(game._tab == "research", "Clicking a research card keeps the gallery open")

	fresh(); source = game.rig[game.PLAYER]
	game._set_builds(source, []); game.intel[game.PLAYER] = 100
	game._left_click(source, false); await settle()
	var left_build_card: Control = scripted_nodes(game.panel, game.BuildCard)[0]
	var left_build_point := left_build_card.get_global_rect().get_center()
	await mouse(left_build_point, true); game._refresh_panel(); await mouse(left_build_point, false)
	check(game.hosts[source].jobs.size() == 1, "Left building palette starts construction in the selected node")
	var feeder_count := 0
	for i in game.hosts.size():
		if i == source: continue
		game.hosts[i].owner = game.PLAYER; game.hosts[i].assign = source
		feeder_count += 1
		if feeder_count == 8: break
	await shot("expanded_connections")
	panel_fits("Eight connections and node buildings fit the expanded sidebar")
	game._set_tab("research"); await settle()
	check(scripted_nodes(game.panel, game.BuildCard).is_empty(), "Building palette hides while researching")

	vp.size = Vector2i(1280, 720); fresh()
	game.cards[game.PLAYER]["phish:linked"] = 1; game._refresh_hand()
	await settle()
	var tile: Control = game.hand_bar.get_child(0)
	var card_start := tile.get_global_rect().get_center()
	var card_target := neighbor(game.rig[game.PLAYER])
	await mouse(card_start, true)
	var drag := InputEventMouseMotion.new()
	drag.position = card_start + Vector2(20, -20); drag.global_position = drag.position
	drag.relative = Vector2(20, -20)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT; vp.push_input(drag, true)
	await process_frame
	drag = InputEventMouseMotion.new()
	drag.position = game._w2s(game.hosts[card_target].pos); drag.global_position = drag.position
	drag.relative = drag.position - card_start - Vector2(20, -20)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT; vp.push_input(drag, true)
	await process_frame
	check(vp.gui_is_dragging(), "Pointer motion starts native card drag")
	await shot("card_drag_preview")
	await mouse(game._w2s(game.hosts[card_target].pos), false)
	check(game._held(game.PLAYER, "phish:linked") == 0, "A held card can actually be dragged from the scroll tray onto the map")
	fresh()
	game._start_tutorial(); game.set_process(false)
	await shot("tutorial_01_connect")
	check(game.tut_panel.get_global_rect().encloses(find_button(game.tut_panel, "Skip tutorial").get_global_rect()), "Skip tutorial fits inside the tutorial window")
	advance(1)
	check(game._tut_stage == 0 and game._ai_paused, "Tutorial cannot advance by waiting or wake AI early")
	source = game.rig[game.PLAYER]; target = game._tut_target
	game.sel = {source:true}; game._wire(target); advance(0.3)
	check(game._tut_stage == 1, "Tutorial observes connection")
	game._launch(target, "attack"); advance(0.3)
	check(game._tut_stage == 2, "Tutorial observes attack")
	game.sel = {game._tut_second:true}; game._wire(target); advance(0.3)
	check(game._tut_stage == 3, "Tutorial observes second contributor")
	advance(40)
	check(game._tut_stage == 4 and game._mine(target), "Tutorial reaches capture and build lesson")
	await shot("tutorial_05_build")
	game._player_build(target, "intel"); advance(11)
	check(game._tut_stage == 5, "Tutorial observes completed construction")
	game._queue_research(game.PLAYER, "phish:linked"); advance(24)
	check(game._held(game.PLAYER, "phish:linked") > 0 and game._tut_stage == 6, "Training fixture funds the full card lesson")
	await shot("tutorial_07_card")
	for i in game.hosts.size():
		if game._can_play(game.PLAYER, "phish:linked", i) == "": game._play_card(game.PLAYER, "phish:linked", i); break
	advance(0.3)
	check(game._tut_stage == 7 and game._ai_paused, "Tutorial observes card play and waits for explicit start")
	game._tut_finish(); check(not game._ai_paused, "Finishing tutorial releases the rival")
	var report := {"checks": checks, "failures": failures, "scope": "Automated mechanics, synthetic input and layout fixtures; not a human playtest"}
	var file := FileAccess.open(output + "/results.json", FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t")); file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
