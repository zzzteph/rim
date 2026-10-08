extends Node
## Windowed screenshot harness. Env: CAP_SIZE, CAP_SEED, CAP_ZOOM (optional), CAP_OUT (png path).
## Resizes to a fixed window first so the city frames to it, lets a few frames settle, saves a PNG.
func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await get_tree().process_frame
	await get_tree().process_frame
	var sz := OS.get_environment("CAP_SIZE"); Session.city_size = sz if sz != "" else "large"
	var sd := OS.get_environment("CAP_SEED"); Session.seed = int(sd) if sd != "" else 303
	var city = load("res://scenes/city.tscn").instantiate()
	add_child(city)
	await get_tree().process_frame
	var z := OS.get_environment("CAP_ZOOM")
	if z != "":
		city.camera.zoom = Vector2(float(z), float(z))
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := OS.get_environment("CAP_OUT")
	img.save_png(out if out != "" else "cap.png")
	print(">>>CAP saved ", out, " buildings=", city.lots.size(), " zoom=%.3f" % city.camera.zoom.x)
	get_tree().quit()
