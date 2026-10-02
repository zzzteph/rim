extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _rect(c: Control) -> String:
	return "%s visible=%s min=%s" % [c.get_global_rect(), c.is_visible_in_tree(), c.get_combined_minimum_size()]

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
	var ui = game.get_node("UILayer/UI")
	print("VIEWPORT ", root.get_visible_rect())
	print("BUILD ", _rect(ui.build_scroll))
	print("STATUS ", _rect(ui.status_label))
	print("HUD ", _rect(ui.top_label))
	print("DEFAULT FONTS top/body/status ", ui.top_label.get_theme_font_size("font_size"), "/", ui.info_body.get_theme_font_size("font_size"), "/", ui.status_label.get_theme_font_size("font_size"))
	ui._on_tab("tech")
	await _settle()
	print("TECH ", _rect(ui.tech_scroll))
	print("TECH STATUS ", _rect(ui.status_label))
	ui._on_tab("build")
	settings.text_scale = 2.0
	ui._apply_text_scale()
	await _settle()
	print("SCALE200 BUILD ", _rect(ui.build_scroll))
	print("SCALE200 STATUS ", _rect(ui.status_label))
	print("SCALE200 FONTS top/body/status ", ui.top_label.get_theme_font_size("font_size"), "/", ui.info_body.get_theme_font_size("font_size"), "/", ui.status_label.get_theme_font_size("font_size"))
	var tabs = ui.minimap.get_parent().get_child(1)
	for child in tabs.get_children():
		print("SCALE200 TAB ", child.text, " ", _rect(child), " fontsize=",child.get_theme_font_size("font_size"))
	settings.text_scale = 1.0
	ui._apply_text_scale()
	game.set_tool("phish")
	await _settle()
	print("ARMED INFO ", _rect(ui.sel_box), " title=", ui.info_title.text)
	game.set_tool("cancel")
	game.selected_id = game.hub_id
	ui._on_tab("menu")
	await _settle()
	print("SELECTED MENU ", _rect(ui.menu_box), " INFO ",_rect(ui.sel_box))
	game.selected_id = -1
	game.selected_tunnel = game.hub_id
	game.set_tool("phish")
	await _settle()
	print("TUNNEL THEN TOOL selection=",game.selected_tunnel," build=",ui.build_scroll.is_visible_in_tree()," info=",ui.sel_box.is_visible_in_tree())
	game.selected_tunnel = -1
	game.set_tool("cancel")
	game.message = "Game saved."
	await _settle()
	print("SAVE FEEDBACK status=",ui.status_label.text)
	game.paused = false
	ui._open_settings()
	await _settle()
	print("SETTINGS PAUSED ",game.paused," visible=",ui.settings_overlay.visible)
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	await _settle()
	print("SETTINGS ESC PAUSED ",game.paused," visible=",ui.settings_overlay.visible)
	game._input(escape)
	await _settle()
	print("SETTINGS ESC AGAIN PAUSED ",game.paused," visible=",ui.settings_overlay.visible)
	ui._close_settings()
	game.hint = ""
	game.selected_id = -1
	game.selected_tunnel = -1
	ui._on_tab("jobs")
	for index in 3:
		var contract = game._gen_contract()
		contract.desc = "Run 6 linked structures"
		game.contracts.append(contract)
	game._contracts_ver += 1
	await _settle()
	print("JOBS ",_rect(ui.jobs_box))
	print("JOBS STATUS ",_rect(ui.status_label))
	for child in ui.jobs_box.get_children():
		if child is Control:
			print("JOB CHILD ",_rect(child))
	game.won = true
	await _settle()
	print("VICTORY PAUSED ",game.paused," overlay=",ui.win_overlay.visible)
	print("VICTORY LABEL ",_rect(ui.win_label)," PANEL ",_rect(ui.win_label.get_parent().get_parent()))
	print("FOCUS ",root.gui_get_focus_owner())
	quit()

