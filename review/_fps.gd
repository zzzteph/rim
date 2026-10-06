extends Node
## Windowed FPS probe. PROBE_MODE env selects what it measures at overview zoom (large/seed 303):
##   raw  = force a full repaint every frame   (pessimistic _draw() throughput)
##   pan  = drag the camera every frame, no forced repaint (real panning — exercises the gating)
##   idle = touch nothing (real idle — gating should keep it free)
## Run: PROBE_MODE=pan Godot_v4.7.2-stable_win64.exe --path . res://review/_fps.tscn
var city: Node2D
var mode := ""
var f := 0
var samples: Array[float] = []

func _ready() -> void:
	mode = OS.get_environment("PROBE_MODE")
	if mode == "": mode = "raw"
	var sz := OS.get_environment("PROBE_SIZE")
	Session.city_size = sz if sz != "" else "large"
	Session.seed = 303
	Engine.max_fps = 0
	var w := OS.get_environment("PROBE_W"); var h := OS.get_environment("PROBE_H")
	if w != "" and h != "":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(int(w), int(h)))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # after resize (resize re-enables it)
	city = load("res://scenes/city.tscn").instantiate()
	add_child(city)

var _dtsum := 0.0
func _process(_dt: float) -> void:
	if city == null: return
	match mode:
		"raw": city.queue_redraw()
		"pan": city.camera.position += Vector2(60.0, 18.0) * _dt   # simulate a steady drag-pan
		"detail":
			var z := OS.get_environment("PROBE_ZOOM")
			var zv := float(z) if z != "" else 1.6
			city.camera.zoom = Vector2(zv, zv)                     # zoomed into a neighbourhood
			city.camera.position += Vector2(90.0, 30.0) * _dt      # pan through it (culled repaints)
		"idle": pass
	f += 1
	if f < 40: return   # warm-up (shader compile, first layout, a few pans)
	samples.append(Engine.get_frames_per_second())
	_dtsum += _dt                                  # real wall-clock per frame (unambiguous)
	if samples.size() >= 120:
		var mn := 100000.0; var sum := 0.0
		for s in samples:
			sum += s; mn = minf(mn, s)
		var real_fps := float(samples.size()) / maxf(_dtsum, 0.0001)
		var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prim := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		print(">>>FPS size=%s mode=%s realfps=%d gfps_avg=%d gfps_min=%d items=%d zoom=%.3f vp=%s draw_calls=%d prims=%d" % [
			Session.city_size, mode, int(round(real_fps)), int(round(sum / samples.size())), int(mn),
			city._draw_items.size(), city.camera.zoom.x, str(get_viewport().size), int(dc), int(prim)])
		get_tree().quit(0)
