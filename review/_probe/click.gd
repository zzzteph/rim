extends Node
var city
func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await get_tree().process_frame
	Session.city_size = OS.get_environment("CAP_SIZE"); Session.seed = 22
	city = load("res://scenes/city.tscn").instantiate()
	add_child(city)
	await get_tree().process_frame
	city.camera.zoom = Vector2(1.0, 1.0)
	var pick := Vector2i(-999, -999)
	for k in city.lots:   # the tallest non-HUB building
		if k != city.hub_key and (pick.x < -900 or float(city.lots[k].h) > float(city.lots[pick].h)): pick = k
	city.camera.position = city._building_top_center(pick)
	for i in 4: await get_tree().process_frame
	var top: Vector2 = city._building_top_center(pick)
	var base: Vector2 = city._iso(city._lot_center(pick).x, city._lot_center(pick).y)
	for name in ["roof", "mid-body", "base"]:
		var w: Vector2 = top + Vector2(0, 3) if name == "roof" else (top.lerp(base, 0.5) if name == "mid-body" else base)
		var sp: Vector2 = city.get_viewport().get_canvas_transform() * w
		Input.warp_mouse(sp)
		var mv := InputEventMouseMotion.new(); mv.position = sp; mv.global_position = sp
		get_viewport().push_input(mv)
		await get_tree().process_frame; await get_tree().process_frame
		var hov: String = city.hover_lbl.text
		city._clear_selection()
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = pressed
			ev.position = sp; ev.global_position = sp
			get_viewport().push_input(ev)
			await get_tree().process_frame
		print(">>>%-8s hover='%s'  selected=%s (want %s)  %s" % [name, hov.left(40), city.selected, pick, "OK" if city.selected == pick else "MISS"])
	get_tree().quit()
