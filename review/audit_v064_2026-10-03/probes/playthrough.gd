extends SceneTree

const OUT := "C:/Users/steph/Documents/GitHub/rim/review/audit_v064_2026-10-03"
var game
var records := []
var layout := {}

func _initialize() -> void:
	_run.call_deferred()

func settle(n := 5) -> void:
	for i in n:
		await process_frame

func event_record(action: String, data: Dictionary = {}) -> void:
	data["action"] = action
	records.append(data)
	print(JSON.stringify(data))

func click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	Input.warp_mouse(p)
	await settle(2)
	var motion := InputEventMouseMotion.new()
	motion.position = p
	motion.global_position = p
	Input.parse_input_event(motion)
	await settle(2)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = p
		event.global_position = p
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await settle(2)

func key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await settle(2)

func button_named(parent: Node, text: String) -> Button:
	for b in parent.find_children("", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null

func press_named(parent: Node, text: String) -> void:
	var b := button_named(parent, text)
	if b == null:
		event_record("missing_button", {"text": text})
		return
	var disabled := b.disabled
	await click(b.get_global_rect().get_center())
	event_record("click_button", {"text": text, "disabled": disabled})

func controls(parent: Node) -> Array:
	var out := []
	for c in parent.find_children("", "Control", true, false):
		if not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		var item := {"path": str(c.get_path()), "class": c.get_class(),
			"rect": [r.position.x, r.position.y, r.size.x, r.size.y]}
		if c is Label or c is Button:
			item["text"] = c.text
			item["font_size"] = c.get_theme_font_size("font_size")
		if c is Button:
			item["disabled"] = c.disabled
			item["tooltip"] = c.tooltip_text
		out.append(item)
	return out

func snapshot(name: String) -> void:
	await settle(8)
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var err := shot.save_png(OUT + "/screenshots/" + name + ".png")
	layout[name] = {"viewport": [shot.get_width(), shot.get_height()], "controls": controls(root)}
	event_record("screenshot", {"name": name, "error": err, "size": [shot.get_width(), shot.get_height()]})
	write_results()

func write_results() -> void:
	var f := FileAccess.open(OUT + "/playthrough.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"events": records, "layouts": layout}, "\t"))
	f.close()

func world_click(cell: Vector2i) -> void:
	var world: Vector2 = game._cell_center(cell)
	var point: Vector2 = game.get_canvas_transform() * world
	await click(point)
	event_record("world_click", {"cell": [cell.x, cell.y], "screen": [point.x, point.y],
		"mouse_cell": str(game._mouse_cell()), "nodes": game.nodes.size(), "message": game.message})

func candidate(kind: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := INF
	var hub: Vector2i = game._center_cell(game.hub_id)
	for y in range(maxi(0, hub.y - 16), mini(100, hub.y + 17)):
		for x in range(maxi(0, hub.x - 16), mini(100, hub.x + 17)):
			var cell := Vector2i(x, y)
			if game._placement_error(kind, cell - Vector2i.ONE, 2) != "":
				continue
			var d := cell.distance_squared_to(hub)
			if d < best_dist:
				best_dist = d
				best = cell
	return best

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.get_node("Settings").text_scale = 1.0
	root.get_node("Settings").reduced_motion = false
	root.get_node("Settings").high_contrast = false
	root.get_node("Settings").cb = false
	root.get_node("Session").seed = 12345
	seed(12345)
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await snapshot("01_menu")
	# New Game randomizes the seed; the record below captures the actual played city.
	await press_named(menu, "New Game")
	await settle(15)
	game = current_scene
	if game == menu or game == null:
		event_record("new_game_failed")
		write_results()
		quit(1)
		return
	event_record("new_game", {"seed": game.seed, "hub": str(game.nodes[game.hub_id].cell)})
	await snapshot("02_new_game")
	var nest_cell := candidate("nest")
	await click(game.ui.tool_buttons.nest.get_global_rect().get_center())
	await snapshot("03_payload_armed")
	await world_click(nest_cell)
	var nest_id: int = game.next_id - 1
	await key(KEY_ESCAPE)
	await snapshot("04_unlinked_producer")
	await press_named(game.ui, "Links")
	await click(game.ui.tool_buttons.dns.get_global_rect().get_center())
	await world_click(nest_cell)
	await world_click(game._center_cell(game.hub_id))
	await key(KEY_ESCAPE)
	event_record("first_link", {"producer": nest_id, "parent": game.nodes.get(nest_id, {}).get("parent", -1), "cash": game.resources.credits})
	await snapshot("05_first_link")
	await create_timer(12.0).timeout
	event_record("twelve_seconds", {"resources": game.resources.duplicate(), "packets_delivered": game._packets_delivered, "upkeep": game.total_upkeep})
	await world_click(nest_cell)
	await snapshot("06_selected_producer")
	await key(KEY_E)
	await snapshot("07_disabled_producer")
	await key(KEY_E)
	await key(KEY_ESCAPE)
	await press_named(game.ui, "Tech")
	await snapshot("08_tech")
	await press_named(game.ui, "Jobs")
	await snapshot("09_jobs")
	await press_named(game.ui, "Stats")
	await snapshot("10_stats")
	await press_named(game.ui, "Menu")
	await snapshot("11_menu_tab")
	await press_named(game.ui, "Save Game")
	await press_named(game.ui, "Load Game")
	await press_named(game.ui, "⚙ Settings")
	await snapshot("12_settings_100")
	# Settings scale is a display test, using the actual on-screen toggle buttons.
	for i in 4:
		await click(game.ui.setting_btns.ts.get_global_rect().get_center())
	await snapshot("13_settings_200")
	await press_named(game.ui, "Close")
	await snapshot("14_menu_200")
	await press_named(game.ui, "Build")
	await snapshot("15_build_200")
	await press_named(game.ui, "Tech")
	await snapshot("16_tech_200")
	await press_named(game.ui, "Jobs")
	await snapshot("17_jobs_200")
	await press_named(game.ui, "Stats")
	await snapshot("18_stats_200")
	root.get_node("Settings").text_scale = 1.0
	game.ui._apply_text_scale()
	await key(KEY_ESCAPE)
	await snapshot("19_pause")
	await key(KEY_ESCAPE)
	# Inspect gameplay under accessibility display modes; simulation is unchanged.
	root.get_node("Settings").high_contrast = true
	root.get_node("Settings").cb = true
	root.get_node("Settings").reduced_motion = true
	game._invalidate_city()
	await press_named(game.ui, "Build")
	await snapshot("20_accessible_map")
	event_record("complete", {"seed": game.seed, "nodes": game.nodes.size(), "resources": game.resources, "packets_delivered": game._packets_delivered})
	write_results()
	quit()
