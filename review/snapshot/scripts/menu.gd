extends Control
## Main menu: new game (fresh generated map), continue (load save), quit.

var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(320, 0)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-160, -170)
	add_child(box)

	var title := Label.new()
	title.text = "R I M"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "a game about cyberspace"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	_btn(box, "New Game", _new_game)
	var cont := _btn(box, "Continue", _continue)
	cont.disabled = not Session.has_save()
	_btn(box, "Quit", get_tree().quit)

	var ver := Label.new()
	ver.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	box.add_child(ver)


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _new_game() -> void:
	Session.start_mode = "new"
	Session.seed = randi()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _continue() -> void:
	Session.start_mode = "load"
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.09), true)
	var grid := Color(0.2, 1.0, 0.9, 0.06)
	for x in range(0, int(size.x) + 1, 40):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid)
	for y in range(0, int(size.y) + 1, 40):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid)
	# packets drifting through the net
	var cols := [Color(0.4, 1.0, 0.5), Color(0.35, 0.7, 1.0), Color(1.0, 0.85, 0.2)]
	for i in 28:
		var yy := fmod(float(i) * 97.0, maxf(size.y, 1.0))
		var xx := fmod(_t * (30.0 + float(i) * 7.0) + float(i) * 131.0, size.x + 40.0) - 20.0
		var c: Color = cols[i % 3]
		c.a = 0.55
		draw_circle(Vector2(xx, yy), 2.5, c)
