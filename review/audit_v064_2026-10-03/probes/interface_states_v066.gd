extends SceneTree

const OUT := "C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03"
var game
var results := []

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for i in 12:
		await process_frame

func snapshot(name: String) -> void:
	game.queue_redraw()
	await settle()
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + "/screenshots_v066/" + name + ".png")
	var items := []
	for c in root.find_children("", "Control", true, false):
		if c.is_visible_in_tree() and (c is Button or c is Label):
			var r: Rect2 = c.get_global_rect()
			items.append({"path": str(c.get_path()), "text": c.text,
				"rect": [r.position.x, r.position.y, r.size.x, r.size.y], "font_size": c.get_theme_font_size("font_size")})
	results.append({"name": name, "controls": items})
	var f := FileAccess.open(OUT + "/interface_states_v066.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "\t"))
	f.close()
	print("SCREENSHOT ", name)

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var settings = root.get_node("Settings")
	settings.text_scale = 1.0
	settings.reduced_motion = true
	settings.high_contrast = false
	settings.cb = false
	root.get_node("Session").start_mode = "load"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.paused = true
	game._sim_tick(0.1)
	# Controlled alert fixture layered over the saved legal opening.
	game.trace = 95.0
	game.warn_overload = true
	game.slow_factor = 0.5
	game.sweep = {"path": [2, 1], "step": 0, "warn": 5.0, "t": 0.0, "hop": 2.0}
	game._edge[2] = {"over": true, "offered": 10.0, "cap": 3.0, "frac": 0.25, "dist_loss": 0.015, "over_loss": 0.735, "trace_hot": true}
	game._connected = {1: true}
	game.message = "Controlled alert layout fixture"
	game.ui.tab = "build"
	await snapshot("25_alerts_100")
	settings.text_scale = 2.0
	game.ui._apply_text_scale()
	await snapshot("26_alerts_200")
	settings.text_scale = 1.0
	game.ui._apply_text_scale()
	game.selected_tunnel = 2
	game.ui.tab = "build"
	await snapshot("27_tunnel_inspector")
	game.sweep.clear()
	game.trace = 0.0
	game.warn_overload = false
	game.slow_factor = 1.0
	game.selected_tunnel = -1
	game.resources.credits = 1000.0
	game.won = true
	settings.text_scale = 2.0
	game.ui._apply_text_scale()
	await snapshot("28_victory_200")
	# The main menu is opened under the same 200% persisted display preference.
	game.queue_free()
	await settle()
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + "/screenshots_v066/29_main_menu_200.png")
	var fonts := []
	for c in menu.find_children("", "Control", true, false):
		if c is Label or c is Button:
			fonts.append({"text": c.text, "font_size": c.get_theme_font_size("font_size")})
	results.append({"name": "29_main_menu_200", "settings_scale": settings.text_scale, "fonts": fonts})
	var f := FileAccess.open(OUT + "/interface_states_v066.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "\t"))
	f.close()
	print("DONE interface_states")
	quit()
