extends Node
func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await get_tree().process_frame
	Session.city_size = OS.get_environment("CAP_SIZE"); Session.seed = int(OS.get_environment("CAP_SEED"))
	var city = load("res://scenes/city.tscn").instantiate()
	add_child(city)
	await get_tree().process_frame
	var z := OS.get_environment("CAP_ZOOM")
	if z != "": city.camera.zoom = Vector2(float(z), float(z))
	city.net_view = OS.get_environment("CAP_NET") != ""
	if OS.get_environment("CAP_SELECT") != "":
		var pick := Vector2i(-999, -999); var far := -1.0
		for k in city.lots:
			if str(city.lots[k].kind) != OS.get_environment("CAP_SELECT"): continue
			var d: float = Vector2(k).distance_to(Vector2(city.hub_key))
			if d > far and d < 9.0: far = d; pick = k
		city.camera.position = (city._building_top_center(pick) + city._building_top_center(city.hub_key)) * 0.5 + Vector2(-120, 60)
		await get_tree().process_frame
		city._select_at(city._building_top_center(pick) + Vector2(0, 4))
	city._dirty = true
	for i in 14: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("CAP_OUT"))
	get_tree().quit()
