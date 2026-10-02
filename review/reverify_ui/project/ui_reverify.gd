extends SceneTree

var results := {}

func _initialize() -> void:
	_run.call_deferred()

func _settle() -> void:
	for index in 4:
		await process_frame

func _rect(c: Control) -> Dictionary:
	var r := c.get_global_rect()
	return {"x":r.position.x,"y":r.position.y,"w":r.size.x,"h":r.size.y,"visible":c.is_visible_in_tree(),"font":c.get_theme_font_size("font_size")}

func _emit(key: String, value) -> void:
	results[key] = value
	print(key," ",JSON.stringify(value))

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var session = root.get_node("Session")
	var settings = root.get_node("Settings")
	session.start_mode = "new"
	session.seed = 42
	settings.text_scale = 1.0
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _settle()
	game.set_process(false)
	var ui = game.get_node("UILayer/UI")
	_emit("B27_build",{"scroll":_rect(ui.build_scroll),"status":_rect(ui.status_label)})
	ui._on_tab("tech")
	await _settle()
	_emit("B27_tech",{"scroll":_rect(ui.tech_scroll),"status":_rect(ui.status_label)})
	ui._on_tab("build")
	settings.text_scale = 2.0
	ui._apply_text_scale()
	await _settle()
	var tabs = ui.minimap.get_parent().get_child(1)
	var fonts := []
	for child in tabs.get_children():
		fonts.append({"text":child.text,"rect":_rect(child)})
	_emit("B29_scale200",{"top":_rect(ui.top_label),"body":_rect(ui.info_body),"status":_rect(ui.status_label),"tabs":fonts})
	game.selected_id = game.hub_id
	await _settle()
	_emit("B29_scale200_visible_inspector",{"body":_rect(ui.info_body),"title":_rect(ui.info_title)})
	game.selected_id = -1
	settings.text_scale = 1.0
	ui._apply_text_scale()
	game.selected_id = game.hub_id
	ui._on_tab("menu")
	await _settle()
	_emit("B30_selected_menu",{"menu":_rect(ui.menu_box),"info":_rect(ui.sel_box)})
	game.selected_id = -1
	game.set_tool("phish")
	await _settle()
	_emit("B31_tool_help",{"info":_rect(ui.sel_box),"title":ui.info_title.text})
	game.set_tool("cancel")
	game.message = "Game saved."
	await _settle()
	_emit("B32_save_feedback",ui.status_label.text)
	var unlinked = game.nodes[game.hub_id].duplicate(true)
	unlinked.id = 2
	unlinked.type = "nest"
	unlinked.size = 2
	unlinked.cell += Vector2i(8, 0)
	unlinked.parent = -1
	game.nodes[2] = unlinked
	ui._alert_acc = 1.0
	await _settle()
	_emit("B33_unlinked_alert",{"visible":ui.alert_btns.offline.visible,"text":ui.alert_btns.offline.text})
	game.selected_id = 2
	game.paused = false
	ui._open_settings()
	await _settle()
	_emit("B35_settings_pause",{"paused":game.paused,"visible":ui.settings_overlay.visible})
	game._input(_key(KEY_E))
	_emit("B37_modal_shortcut",{"node_on":game.nodes[2].on})
	game.selected_id = -1
	game._input(_key(KEY_ESCAPE))
	await _settle()
	_emit("B36_escape_settings",{"paused":game.paused,"visible":ui.settings_overlay.visible})
	game._input(_key(KEY_ESCAPE))
	await _settle()
	_emit("B36_escape_settings_again",{"paused":game.paused,"visible":ui.settings_overlay.visible})
	ui._close_settings()
	ui._on_tab("build")
	await _settle()
	ui.tool_buttons.phish.grab_focus()
	ui._open_settings()
	await _settle()
	_emit("B38_modal_background_focus",{"background_focus":root.gui_get_focus_owner()==ui.tool_buttons.phish})
	Input.parse_input_event(_key(KEY_ENTER))
	await _settle()
	var release := _key(KEY_ENTER)
	release.pressed = false
	Input.parse_input_event(release)
	await _settle()
	_emit("B38_modal_background_activation",{"tool":game.current_tool})
	ui._close_settings()
	game.set_tool("cancel")
	game.nodes[2].parent = game.hub_id
	game.nodes[2].tunnel = "dns"
	game.nodes[2].path = [Vector2i(52,50),Vector2i(53,50)]
	game.selected_tunnel = 2
	ui._jump_alert("trace")
	await _settle()
	_emit("B34_alert_conflicts",{"selected_id":game.selected_id,"selected_tunnel":game.selected_tunnel,"title":ui.info_title.text})
	game.selected_id = -1
	game.selected_tunnel = -1
	game.set_tool("phish")
	ui._jump_alert("trace")
	await _settle()
	_emit("B34_alert_armed_tool",{"tool":game.current_tool,"selected_id":game.selected_id,"title":ui.info_title.text})
	game.set_tool("cancel")
	game.selected_id = -1
	game.trace = 95.0
	game.warn_overload = true
	game.rates = {"compute":1.5,"data":2.0,"credits":3.0}
	await _settle()
	_emit("B47_warning_overlap",{"warning":_rect(ui.warn_banner),"rate":_rect(ui.netrate_label),"overlap":ui.warn_banner.get_global_rect().intersects(ui.netrate_label.get_global_rect())})
	var rooftop_center = game._center_world(game.hub_id) + Vector2(14,-40)
	var roof_cell = Vector2i(floor(rooftop_center.x/game.TILE),floor(rooftop_center.y/game.TILE))
	_emit("B48_roof_hit",{"hit":game._node_at(roof_cell),"hub":game.hub_id,"roof_cell":str(roof_cell),"hub_cell":str(game.nodes[game.hub_id].cell)})
	ui._on_tab("jobs")
	game.contracts.clear()
	for index in 3:
		var contract = game._gen_contract()
		contract.desc = "Run 6 linked structures"
		game.contracts.append(contract)
	game._contracts_ver += 1
	await _settle()
	var cards := []
	for child in ui.jobs_box.get_children():
		if child is Control:
			cards.append(_rect(child))
	_emit("B28_jobs",{"board":_rect(ui.jobs_box),"cards":cards,"status":_rect(ui.status_label)})
	game.won = true
	await _settle()
	_emit("B40_victory",{"label":_rect(ui.win_label),"panel":_rect(ui.win_label.get_parent().get_parent())})
	game.won = false
	game.paused = true
	await _settle()
	_emit("B39_pause_mouse_blocker",{"overlay":_rect(ui.pause_overlay),"dim_mouse_filter":ui.pause_overlay.get_child(0).mouse_filter})
	game.paused = false
	game.set_tool("cancel")
	ui._on_tab("stats")
	await _settle()
	_emit("NEW_stats_fit",{"stats":_rect(ui.stats_box),"status":_rect(ui.status_label)})
	settings.text_scale = 2.0
	ui._apply_text_scale()
	ui._open_settings()
	await _settle()
	_emit("NEW_settings_200_fit",{"panel":_rect(ui.settings_overlay.get_child(1))})
	ui._close_settings()
	settings.text_scale = 1.0
	ui._apply_text_scale()
	game.resources = {"compute":1000000.0,"data":1000000.0,"crypto":1000000.0,"tools":1000000.0,"research":1000000.0,"credits":1000000.0}
	await _settle()
	_emit("NEW_long_resources",{"rect":_rect(ui.top_label),"text":ui.top_label.text})
	ui._on_tab("build")
	game.selected_tunnel = 2
	game.set_tool("phish")
	await _settle()
	_emit("NEW_tool_selection_conflict",{"tool":game.current_tool,"selected_tunnel":game.selected_tunnel,"build_visible":ui.build_scroll.is_visible_in_tree(),"info":_rect(ui.sel_box)})
	game.selected_tunnel = -1
	game.set_tool("cancel")
	game.selected_id = 2
	game.nodes[2].relay = true
	await _settle()
	_emit("NEW_proxy_inspector",{"title":ui.info_title.text,"body":ui.info_body.text})
	game.selected_id = -1
	game.nodes[2].relay = false
	game.nodes[2].type = "forge"
	game.selected_id = 2
	await _settle()
	_emit("NEW_forge_inspector",{"body":ui.info_body.text,"actual_conv":game.CONV.forge})
	game.nodes[2].type = "lab"
	await _settle()
	_emit("NEW_lab_inspector",{"body":ui.info_body.text,"actual_conv":game.CONV.lab})
	game.nodes[2].type = "phish"
	game.nodes[2].relay = true
	await _settle()
	_emit("NEW_proxy_intel_inspector",{"body":ui.info_body.text})
	game.nodes[2].relay = false
	game.nodes[2].on = true
	game.nodes[2].quarantine = 5.0
	game.resources.compute = 80.0
	game.sweep = {}
	game._sim_tick(0.1)
	await _settle()
	_emit("NEW_quarantine_inspector",{"body":ui.info_body.text,"parent":game.nodes[2].parent,"quarantine":game.nodes[2].quarantine})
	game.nodes[2].quarantine = 0.0
	game._sim_tick(0.1)
	game.selected_id = -1
	game.selected_tunnel = 2
	await _settle()
	_emit("NEW_hot_trace_loss_label",{"body":ui.info_body.text,"edge":game._edge[2],"trace":game.trace,"path_cells":game.nodes[2].path.size()})
	game.sweep = {"path":[2,game.hub_id],"step":0,"warn":0.0,"t":0.0}
	await _settle()
	_emit("NEW_sweep_hops",{"text":ui.warn_banner.text,"route_edges":1})
	game.sweep = {}
	ui._open_settings()
	game.selected_tunnel = -1
	game.selected_id = -1
	var key_right := _key(KEY_RIGHT)
	Input.parse_input_event(key_right)
	await _settle()
	var key_pan_before = game.camera.position
	game._process(0.1)
	_emit("NEW_modal_keyboard_pan",{"raw_key_pressed":Input.is_key_pressed(KEY_RIGHT),"camera_moved":game.camera.position!=key_pan_before})
	key_right.pressed = false
	Input.parse_input_event(key_right)
	ui._close_settings()
	var minimap = ui.minimap
	minimap._bake_grid()
	var texture_before = minimap._grid_tex
	game.seed = 43
	game.rng.seed = 43
	game._generate_city()
	minimap._process(0.1)
	_emit("B49_seed_texture",{"same_texture":texture_before==minimap._grid_tex})
	var legend = ui.get_child(3)
	var legend_label: Label = null
	for child in ui.get_children():
		if child is HBoxContainer and child.get_child_count()==6:
			legend_label = child.get_child(0).get_child(1)
	var original_legend = legend_label.get_theme_color("font_color")
	settings.cb = true
	await _settle()
	_emit("B44_legend_palette",{"same_label_color":original_legend==legend_label.get_theme_color("font_color"),"matches_settings":legend_label.get_theme_color("font_color")==settings.res_color("compute")})
	settings.reduced_motion = true
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	menu.set_process(false)
	menu._process(1.0)
	_emit("B41_menu_motion",{"animation_time_after_one_second":menu._t,"reduced_motion":settings.reduced_motion})
	menu.queue_free()
	settings.cb = false
	settings.reduced_motion = false
	var outside_drag := InputEventMouseMotion.new()
	outside_drag.position = Vector2(-50.0,-50.0)
	outside_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	minimap._gui_input(outside_drag)
	_emit("NEW_minimap_outside_drag",{"camera":str(game.camera.position),"map_min":"(0,0)"})
	var move := InputEventMouseMotion.new()
	move.position = Vector2(700,400)
	move.global_position = Vector2(700,400)
	Input.parse_input_event(move)
	await _settle()
	game._lmb_down = true
	game._lmb_moved = false
	move.relative = Vector2(2,0)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	for index in 20:
		game._unhandled_input(move)
	_emit("B45_slow_drag",{"viewport_mouse":str(root.get_mouse_position()),"recognized":game._lmb_moved,"total_motion":40})
	game._lmb_down = false
	game._panning = true
	var camera_before = game.camera.position
	move.button_mask = 0
	move.relative = Vector2(10,0)
	game._unhandled_input(move)
	_emit("B46_latched_pan",{"viewport_mouse":str(root.get_mouse_position()),"pan_without_buttons":game.camera.position!=camera_before})
	var file := FileAccess.open("res://results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	quit()
