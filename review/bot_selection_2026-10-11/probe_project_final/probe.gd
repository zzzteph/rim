extends SceneTree

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
	if is_instance_valid(game): game.queue_free(); await settle()
	game = load("res://scripts/botnet_proto.gd").new()
	view.add_child(game)
	game.set_deferred("size", Vector2(view.size))
	game.set_process(false)
	game._process(0.0)
	await settle()

func mouse(pos: Vector2, pressed: bool, which := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos; event.global_position = pos
	event.button_index = which; event.pressed = pressed
	view.push_input(event, true)

func click(pos: Vector2, which := MOUSE_BUTTON_LEFT) -> void:
	mouse(pos, true, which); mouse(pos, false, which)
	await settle()

func host(index: int, which := MOUSE_BUTTON_LEFT) -> void:
	await click(game.hosts[index].pos, which)

func drag(source: int, target: int) -> void:
	mouse(game.hosts[source].pos, true)
	var motion := InputEventMouseMotion.new()
	motion.position = game.hosts[target].pos; motion.global_position = motion.position
	motion.relative = motion.position - game.hosts[source].pos
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	view.push_input(motion, true)
	mouse(game.hosts[target].pos, false)
	await settle()

func button(fragment: String) -> Button:
	for c in game.find_children("*", "Button", true, false):
		if fragment in c.text: return c
	return null

func commit(fragment := "ATTACK") -> void:
	var b := button(fragment)
	assert(b != null and not b.disabled)
	await click(b.get_global_rect().get_center())

func record(name: String, notes := "") -> void:
	game.queue_redraw(); await settle()
	var controls := []
	for c in game.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or not (c is Label or c is Button): continue
		var r: Rect2 = c.get_global_rect()
		controls.append({"text": c.text, "class": c.get_class(), "rect": [r.position.x,r.position.y,r.size.x,r.size.y],
			"disabled": c.disabled if c is Button else false, "focus_mode": c.focus_mode})
	var assignments := {}; var bots := {}
	for i in game.hosts.size():
		bots[str(i)] = game.hosts[i].bots
		if int(game.hosts[i].assign) >= 0: assignments[str(i)] = int(game.hosts[i].assign)
	findings.append({"name": name, "notes": notes, "selected_sources": game.sel_sources.keys(),
		"selected_target": game.sel_target, "assignments": assignments, "bots": bots,
		"flights": game.flights.duplicate(true), "controls": controls})
	if render_capture:
		RenderingServer.force_draw(); await RenderingServer.frame_post_draw
		assert(view.get_texture().get_image().save_png("res://captures/"+name+".png") == OK)
	print("CASE ", name)

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): quit(9))
	view = SubViewport.new(); view.size = Vector2i(1280,720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view); view.notify_mouse_entered()
	await fresh(); await record("01_initial")
	await host(0); await host(1); await record("02_one_source_plan")
	await commit(); assert(game.hosts[0].assign == 1)
	game._process(1.0)
	assert(float(game.hosts[1].bots) == 21.0)
	await record("03_panel_target_count_stale", "Panel says 20 target bots while node has regenerated to 21")
	await fresh(); await drag(0,1); await drag(5,6)
	assert(game.sel_sources.size() == 2 and game.sel_target == 6)
	await record("04_two_drags_share_target")
	await commit(); assert(game.hosts[0].assign == 6 and game.hosts[5].assign == 6)
	await record("05_both_sources_second_target")
	await fresh(); await host(0); await host(5)
	assert(game.sel_sources.size() == 2 and game.sel_target == -1)
	await record("06_friendly_click_is_source")
	await fresh(); await drag(0,5); await commit("DEFEND")
	await commit_clear()
	assert(game.hosts[0].assign == 5 and game.sel_target == -1)
	await record("07_clear_draft_keeps_assignment")
	await fresh(); await drag(0,1); await commit()
	await drag(5,0); await commit("DEFEND")
	game._process(1.0)
	var flight_count: int = game.flights.size()
	assert(flight_count > 0)
	await host(0, MOUSE_BUTTON_RIGHT)
	assert(game.hosts[0].assign == -1 and game.hosts[5].assign == -1 and game.flights.size() == flight_count)
	await record("08_right_source_cancels_incoming", "Outgoing A→X AND incoming B→A removed; in-flight packets preserved")
	await fresh(); await drag(0,4)
	assert(game.sel_sources.is_empty() and game.sel_target == -1 and game._msg == "")
	await record("09_invalid_drag_silent")
	await fresh()
	for i in 10: game.hosts[i].owned = true; game.hosts[i].bots = 30.0
	for i in 10: await host(i)
	await host(14); assert(game.sel_sources.size() == 10)
	await record("10_ten_source_plan", "10 source clicks + target click + commit = 12 clicks")
	await commit()
	for i in 10: assert(game.hosts[i].assign == 14)
	await record("11_ten_sources_committed")
	await fresh(); await drag(0,1); await commit()
	game._deliver({"route":[0,1],"count":21.0,"player":true})
	assert(game.hosts[1].owned and game.hosts[0].assign == 1 and game._link_kind(0,1) == "defend")
	await record("12_capture_keeps_order_as_defend", "An attack assignment implicitly becomes reinforcement after capture")
	await fresh(); await drag(0,1)
	game._deliver({"route":[0,1],"count":21.0,"player":true})
	assert(game._link_kind(0,1) == "defend" and button("ATTACK") != null)
	await record("13_draft_label_wrong_after_capture", "ATTACK button persists although the current target is now friendly")
	await fresh(); await drag(0,1); await commit(); game._process(1.0)
	var first: float = game.flights[0].t
	game.paused = true; game._process(1.0)
	assert(float(game.flights[0].t) == first)
	await record("14_packets_freeze_when_paused", "Credit: actual packet motion now freezes correctly")
	await fresh(); game.hosts[14].owned = true
	await host(0); await host(14); await host(1)
	await record("15_mixed_eligibility")
	await commit(); assert(game.hosts[0].assign == 1 and game.hosts[14].assign == -1)
	await record("16_silent_partial_commit")
	await fresh(); game.hosts[1].assign = 0
	await host(1, MOUSE_BUTTON_RIGHT)
	assert(game.hosts[1].assign == -1)
	await record("17_right_click_enemy_stops_enemy", "Current cancel accepts an enemy node and removes its enemy AI attack assignment")
	var output := FileAccess.open("res://results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"source_lines":405,"viewport":[1280,720],"human_playtest":false,
		"method":"Frozen latest script; actual GUI input; controlled attrition/ownership fixtures", "cases":findings},"\t"))
	output.close(); print("AUDIT_COMPLETE ",findings.size()," cases"); quit()

func commit_clear() -> void:
	var b := button("Clear links")
	assert(b != null)
	await click(b.get_global_rect().get_center())
