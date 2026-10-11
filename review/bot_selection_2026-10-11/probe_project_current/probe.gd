extends SceneTree

# Controlled audit of the frozen production script, not a human playtest.
var game
var view: SubViewport
var findings := []
var render_capture := false

func _initialize() -> void:
	render_capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-3000, -3000)
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run.call_deferred()

func settle() -> void:
	for i in 4: await process_frame

func fresh() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await settle()
	game = load("res://scripts/botnet_proto.gd").new()
	view.add_child(game)
	game.set_deferred("size", Vector2(view.size))
	game.set_process(false)
	game._process(0.0)
	await settle()

func input_mouse(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	view.push_input(event, true)

func click_at(pos: Vector2) -> void:
	input_mouse(pos, true)
	input_mouse(pos, false)
	await settle()

func click_host(index: int) -> void:
	await click_at(game.hosts[index].pos)

func drag_host(source: int, target: int) -> void:
	input_mouse(game.hosts[source].pos, true)
	var motion := InputEventMouseMotion.new()
	motion.position = game.hosts[target].pos
	motion.global_position = motion.position
	motion.relative = motion.position - game.hosts[source].pos
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	view.push_input(motion, true)
	input_mouse(game.hosts[target].pos, false)
	await settle()

func button(fragment: String) -> Button:
	for c in game.find_children("*", "Button", true, false):
		if fragment in c.text: return c
	return null

func click_button(fragment: String) -> void:
	var b := button(fragment)
	assert(b != null, "Missing button: " + fragment)
	assert(not b.disabled, "Disabled button: " + fragment)
	await click_at(b.get_global_rect().get_center())

func right_at(pos: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		view.push_input(event, true)
	await settle()

func right_host(index: int) -> void:
	await right_at(game.hosts[index].pos)

func record(name: String, notes: String = "") -> void:
	game.queue_redraw()
	await settle()
	var controls := []
	for c in game.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or not (c is Label or c is Button): continue
		var rect: Rect2 = c.get_global_rect()
		controls.append({"text": c.text, "class": c.get_class(),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"disabled": c.disabled if c is Button else false,
			"focus_mode": c.focus_mode})
	var assignments := {}
	for i in game.hosts.size():
		if int(game.hosts[i].assign) >= 0: assignments[str(i)] = int(game.hosts[i].assign)
	findings.append({"name": name, "notes": notes,
		"selected_sources": game.sel_sources.keys(), "selected_target": game.sel_target,
		"selected_build": game.sel_build, "assignments": assignments,
		"ops": game.ops.duplicate(true), "controls": controls,
		"intel": game._intel(), "animation_clock": game._t})
	if render_capture:
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var err := view.get_texture().get_image().save_png("res://captures/" + name + ".png")
		assert(err == OK)
	print("CASE ", name)

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): quit(9))
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.gui_disable_input = false
	root.add_child(view)
	view.notify_mouse_entered()
	await fresh()
	await record("01_initial")
	await click_host(0)
	await click_host(1)
	assert(game.sel_sources.has(0) and game.sel_target == 1)
	await record("02_one_source_plan")
	await click_button("ATTACK")
	assert(game.hosts[0].assign == 1)
	game._process(1.0)
	await record("03_operation_stale_panel", "One simulation second elapsed without a user-input refresh")
	await fresh()
	await drag_host(0, 1)
	await drag_host(5, 6)
	assert(game.sel_sources.size() == 2 and game.sel_target == 6)
	await record("04_two_different_drags", "A→1 followed by B→6 becomes A+B→6")
	await click_button("ATTACK")
	assert(game.hosts[0].assign == 6 and game.hosts[5].assign == 6)
	await record("05_both_assigned_second_target")
	await fresh()
	await click_host(0)
	await click_host(5)
	assert(game.sel_target == -1 and game.sel_sources.size() == 2)
	await record("06_friendly_click_adds_source", "Attempt source click then friendly target click")
	await fresh()
	game.hosts[10].owned = true
	await click_host(0)
	await click_host(10)
	assert(game.sel_sources.is_empty() and game.sel_build == 10)
	await record("07_friendly_nonwar_opens_build")
	await fresh()
	await drag_host(0, 5)
	await click_button("DEFEND")
	assert(game.hosts[0].assign == 5)
	game._process(0.5)
	await click_host(0)
	await record("08_defend_source_no_stop")
	await click_button("Clear links")
	assert(game.hosts[0].assign == 5 and game.sel_target == 5)
	await record("09_clear_links_keeps_live_order")
	await fresh()
	game.hosts[14].owned = true
	game.hosts[14].war = true
	game.hosts[14].bots = 10.0
	await click_host(0)
	await click_host(14)
	await click_host(1)
	await record("10_mixed_eligibility")
	await click_button("ATTACK")
	assert(game.hosts[0].assign == 1 and game.hosts[14].assign == -1)
	await record("11_silent_partial_commit")
	await fresh()
	game.sel_sources = {0: true}
	game.sel_target = 1
	game._attack()
	game.hosts[0].bots = 0.0
	game.ops[1].abots = 0.0
	game.ops[1].acap = 0.0
	game._tick_op(game.ops[1], 0.1)
	game._refresh_panel()
	await record("12_production_wait_named_fuel", "Sources exist, no active/resident bots; positive Intel")
	game.paused = true
	var old_clock: float = game._t
	game._process(1.0)
	assert(game._t > old_clock)
	game._refresh_panel()
	await record("13_paused_flow_clock_advances")
	await fresh()
	for i in 10:
		game.hosts[i].owned = true
		game.hosts[i].war = true
		game.hosts[i].bots = 10.0
	for i in 10: await click_host(i)
	await click_host(14)
	assert(game.sel_sources.size() == 10)
	await record("14_ten_source_plan", "Synthetic scale fixture: ten source clicks + one target + one Attack = 12 clicks")
	await click_button("ATTACK")
	for i in 10: assert(game.hosts[i].assign == 14)
	await record("15_ten_source_committed")
	await fresh()
	game.hosts[10].owned = true
	await click_host(10)
	assert(button("Build War").disabled)
	game._process(10.0)
	assert(game._intel() >= game.WAR_COST and button("Build War").disabled)
	await record("16_stale_build_affordability", "Enough Intel earned; Build button remains disabled until input refresh")
	await click_host(6)
	assert(game.sel_build == 10 and game.sel_target == 6)
	await record("17_build_panel_shadows_target", "Clicking an enemy after selecting a build site retains the Build panel")
	await fresh()
	await drag_host(0, 4)
	assert(game.sel_sources.is_empty() and game.sel_target == -1 and game._msg == "")
	await record("18_invalid_drag_silent", "Illegal drag destination produces no explanation")
	await fresh()
	await drag_host(0, 1)
	await click_button("ATTACK")
	await drag_host(5, 0)
	await click_button("DEFEND")
	game._process(1.0)
	assert(game.hosts[0].assign == 1 and game.hosts[5].assign == 0)
	await right_host(0)
	assert(game.hosts[0].assign == -1 and game.hosts[5].assign == -1 and game.ops.has(1))
	await record("19_right_source_cancels_incoming_too", "Right-click A clears A outgoing AND B incoming; deployed force remains at enemy")
	await fresh()
	await click_host(0)
	await click_host(5)
	await click_host(1)
	await click_button("ATTACK")
	game._process(1.0)
	assert(float(game.ops[1].abots) > 0.0)
	await right_host(1)
	assert(not game.ops.has(1) and game.hosts[0].assign == -1 and game.hosts[5].assign == -1)
	await record("20_right_enemy_erases_operation", "Right-click enemy destroys operation and all contributor assignments without confirmation")
	await fresh()
	await drag_host(0, 1)
	await click_button("ATTACK")
	await right_at(Vector2(1100, 650))
	assert(game.hosts[0].assign == 1 and game.sel_target == -1)
	await record("21_right_empty_only_clears_draft")
	var output := FileAccess.open("res://results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"viewport": [1280, 720],
		"method": "Frozen production script, SubViewport input dispatch and controlled simulation states",
		"human_playtest": false, "cases": findings}, "\t"))
	output.close()
	print("AUDIT_COMPLETE ", findings.size(), " cases")
	quit()
