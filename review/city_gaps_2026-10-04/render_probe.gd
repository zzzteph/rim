extends Node
func _ready() -> void:
	for item in [["small",7,false],["medium",7,false],["large",7,false],["medium",7,true]]:
		Session.city_size = str(item[0])
		Session.seed = int(item[1])
		var city = load("res://scripts/city.gd").new()
		city.disable_water = bool(item[2])
		add_child(city)
		city.set_process_input(false)
		city.set_process_unhandled_input(false)
		for i in 5: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var prefix := "captures/%s_%d%s" % [item[0],item[1],"_dry" if item[2] else ""]
		var err := get_viewport().get_texture().get_image().save_png("res://" + prefix + "_overview.png")
		print("CAPTURE ", prefix, " overview=",err," draw_items=",city._draw_items.size())
		if str(item[0]) != "small" and not item[2]:
			city.camera.zoom = Vector2(1.5,1.5)
			for i in 5: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			err = get_viewport().get_texture().get_image().save_png("res://" + prefix + "_detail.png")
			print("CAPTURE ", prefix, " detail=",err)
		city.queue_free()
		await get_tree().process_frame
	get_tree().quit()