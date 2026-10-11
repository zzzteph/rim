extends SceneTree

var game
var view: SubViewport
var findings := []
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1,1); root.position = Vector2i(-3000,-3000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	_run.call_deferred()

func settle() -> void:
	for i in 4: await process_frame

func fresh() -> void:
	if is_instance_valid(game): game.queue_free(); await settle()
	game = load("res://scripts/botnet_proto.gd").new()
	view.add_child(game); game.set_deferred("size",Vector2(view.size))
	game.set_process(false); game._enemy_timer = 9999.0; game._process(0.0)
	await settle()

func mouse(pos: Vector2, pressed: bool, which := MOUSE_BUTTON_LEFT, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos; event.global_position = pos; event.button_index = which
	event.pressed = pressed; event.shift_pressed = shift
	view.push_input(event,true)

func click(pos: Vector2, shift := false, which := MOUSE_BUTTON_LEFT) -> void:
	mouse(pos,true,which,shift); mouse(pos,false,which,shift); await settle()

func host(i: int, shift := false) -> void:
	await click(game.hosts[i].pos,shift)

func drag(a: int,b: int) -> void:
	mouse(game.hosts[a].pos,true)
	var event := InputEventMouseMotion.new(); event.position=game.hosts[b].pos; event.global_position=event.position
	event.relative=event.position-game.hosts[a].pos; event.button_mask=MOUSE_BUTTON_MASK_LEFT
	view.push_input(event,true); mouse(game.hosts[b].pos,false); await settle()

func button(fragment: String) -> Button:
	for c in game.find_children("*","Button",true,false):
		if fragment in c.text: return c
	return null

func press(fragment: String) -> void:
	var b := button(fragment); assert(b != null and not b.disabled)
	var scroll: ScrollContainer = game.find_children("*","ScrollContainer",true,false)[0]
	scroll.ensure_control_visible(b); await settle()
	await click(b.get_global_rect().get_center())

func record(id: String, note := "") -> void:
	game.queue_redraw(); await settle()
	var controls := []
	var scroll: ScrollContainer = game.find_children("*","ScrollContainer",true,false)[0]
	var clip := scroll.get_global_rect()
	for c in game.find_children("*","Control",true,false):
		if not c.is_visible_in_tree() or not (c is Label or c is Button): continue
		var r: Rect2 = c.get_global_rect()
		controls.append({"text":c.text,"rect":[r.position.x,r.position.y,r.size.x,r.size.y],
			"center_in_panel_view":clip.has_point(r.get_center()),"disabled":c.disabled if c is Button else false})
	var assigns := {}; var stock := {}
	for i in game.hosts.size():
		stock[str(i)] = game.hosts[i].bots
		if game.hosts[i].assign >= 0: assigns[str(i)] = game.hosts[i].assign
	findings.append({"case":id,"note":note,"selection":game.sel.keys(),"target":game.sel_target,
		"inspect":game._inspect,"intel":game.intel,"stock":stock,"assignments":assigns,
		"flights":game.flights.duplicate(true),"controls":controls})
	if capture:
		RenderingServer.force_draw(); await RenderingServer.frame_post_draw
		assert(view.get_texture().get_image().save_png("res://captures/"+id+".png")==OK)
	print("CASE ",id)

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(9))
	view=SubViewport.new(); view.size=Vector2i(1280,720); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view); view.notify_mouse_entered()
	await fresh(); await record("01_initial")
	await host(0); await record("02_select_source")
	await host(1); await record("03_aim_enemy")
	await press("ATTACK"); assert(game.hosts[0].assign==1 and game.sel_target==-1 and button("ATTACK")!=null)
	await record("04_commit_leaves_stale_attack_button")
	game._process(1.0); await record("05_live_stock_panel_stale")
	await host(5); assert(game.sel.size()==1 and game.sel.has(0) and game.sel_target==5)
	await record("06_click_other_source_aims_reinforcement")
	await fresh(); await host(0); await host(1)
	var escape := InputEventKey.new(); escape.pressed=true; escape.keycode=KEY_ESCAPE
	game._input(escape); await settle()
	assert(game.sel.is_empty() and game.sel_target==1 and game._aim_target()==1)
	await record("07_escape_keeps_pending_target_and_fog")
	await fresh(); await host(0); await host(5,true); await host(1)
	assert(game.sel.size()==2)
	await record("08_two_sources_aimed")
	await press("ATTACK"); assert(game.hosts[0].assign==1 and game.hosts[5].assign==1)
	game._process(0.1); await record("09_two_sources_attacking")
	await fresh(); await host(10)
	assert(game._inspect==-1 and game.sel_target==-1)
	await record("10_bottom_node_click_intercepted_by_panel","Node10 center is inside panel, actual mouse click does not inspect it")
	await fresh(); game.intel=0.0
	await host(0); await host(5,true); await host(1); await press("ATTACK")
	game._process(1.0); assert(game.flights.is_empty() and game.hosts[0].assign==1)
	await record("11_zero_intel_orders_look_active_no_block_reason")
	await fresh(); await drag(0,1); assert(game.hosts[0].assign==-1)
	await record("12_drag_is_preview_only")
	await fresh(); game.hosts[0].assign=1; game.hosts[5].assign=0
	await host(0); await host(6)
	await record("13_retarget_action_below_build_and_remove_controls")
	await fresh(); game.hosts[10].assign=5; game._next_depart[10]=0.0
	game._process(0.1); await host(0); await host(1)
	var fn := {}; var fl := {}; game._build_focus(1,fn,fl)
	assert(not fn.has(5) and not fn.has(10))
	await record("14_aim_dims_attacked_owned_source","Enemy10 attacks owned5, both excluded from focus while aiming at1")
	await fresh(); game.hosts[0].assign=1; game.hosts[2].assign=1
	await host(1); await press("Select contributors")
	assert(game.sel.has(0) and game.sel.has(2) and not game.hosts[2].owned)
	await record("15_contributor_selection_includes_enemy_source")
	await fresh(); await host(0); await host(1)
	game.hosts[1].owned=true; game.hosts[1].bots=1.0
	game._process(0.0)
	assert(button("ATTACK")!=null and game._link_kind(0,1)=="reinforce")
	await record("16_target_capture_keeps_wrong_action_label")
	await fresh(); await host(0); await host(1)
	game._marquee(Rect2(game.hosts[5].pos-Vector2(25,25),Vector2(50,50)),false)
	game._refresh_panel(); await settle()
	assert(game.sel.has(5) and game.sel_target==1)
	await record("17_new_group_inherits_old_pending_target","Controlled marquee fixture retains prior target")
	var output := FileAccess.open("res://results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"method":"Actual GUI input except explicitly controlled state/keyboard/marquee fixtures; no new human playtest","viewport":[1280,720],"cases":findings},"\t"))
	output.close(); print("CLARITY_AUDIT_COMPLETE ",findings.size()," cases"); quit()
