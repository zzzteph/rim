extends SceneTree
## Illustrated Help navigation and viewport checks; add -- --capture for previews.

var game
var view: SubViewport
var checks := 0
var failures: Array = []
var capture := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/visual_help"))
	capture = "--capture" in OS.get_cmdline_user_args()
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _button(node: Node, text: String) -> Button:
	if node is Button and text in node.text: return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null: return found
	return null

func _settle() -> void:
	for frame in 6: await process_frame

func _run() -> void:
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-20000, -20000)
	view = SubViewport.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size = Vector2i(1280, 720)
	root.add_child(view)
	game = load("res://scripts/botnet_proto.gd").new()
	game.theme = load("res://assets/ui_theme.tres")
	game._opt_seed = 7; game._opt_shape = "grid"
	view.add_child(game)
	game.set_process(false)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for resolution in [Vector2i(1280, 720), Vector2i(1366, 768)]:
		view.size = resolution
		game.size = Vector2(resolution)
		game._layout_ui()
		game._menu_view = "help"
		game._help_page = 0
		game._refresh_menu()
		for page in game.HELP_PAGES.size():
			await _settle()
			var name := str(game.HELP_PAGES[page])
			var back := _button(game.menu_box, "Back to menu")
			var next := _button(game.menu_box, "Next")
			var prev := _button(game.menu_box, "Prev")
			_check(game.menu_sc.get_global_rect().encloses(back.get_global_rect()), "%s Back is visible at %s" % [name, resolution])
			_check(game.menu_sc.get_global_rect().encloses(next.get_global_rect()), "%s Next is visible at %s" % [name, resolution])
			_check(game.menu_box.get_combined_minimum_size().y <= game.menu_sc.size.y, "%s requires no vertical scrolling at %s" % [name, resolution])
			_check(game._help_page == page and prev.disabled == (page == 0) and next.disabled == (page == game.HELP_PAGES.size() - 1), "%s navigation state at %s" % [name, resolution])
			if capture and resolution.x == 1280:
				await RenderingServer.frame_post_draw
				view.get_texture().get_image().save_png("res://review/visual_help/help_%s.png" % name)
			if not next.disabled: next.pressed.emit()
		var prev := _button(game.menu_box, "Prev")
		prev.pressed.emit()
		await _settle()
		_check(game._help_page == game.HELP_PAGES.size() - 2, "Previous navigation works at %s" % resolution)
		_button(game.menu_box, "Back to menu").pressed.emit()
		await _settle()
		_check(game._menu_view == "main", "Back returns to main menu at %s" % resolution)
	var results := {"checks": checks, "failures": failures, "scope": "Help navigation and visibility at 1280x720 and 1366x768"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/visual_help"))
	var file := FileAccess.open("res://review/visual_help/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	print(JSON.stringify(results))
	quit(0 if failures.is_empty() else 1)
