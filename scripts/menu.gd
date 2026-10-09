extends Control
## Main menu: new game (fresh generated map), continue (load save), quit.

var _t := 0.0
var _size_btn: Button
const SIZE_LABELS := {"small": "City: Small (18×15)", "medium": "City: Medium (27×22)", "large": "City: Large (38×30)"}
const SIZE_CYCLE := {"small": "medium", "medium": "large", "large": "small"}


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
	title.add_theme_font_size_override("font_size", int(round(52 * Settings.text_scale)))
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "a game about cyberspace"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", int(round(14 * Settings.text_scale)))
	sub.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	_btn(box, "New Game", _new_game)
	var cont := _btn(box, "Continue", _continue)
	cont.disabled = not Session.has_netrun_save()
	_size_btn = _btn(box, "", _cycle_size)   # seeded city size, chosen before New Game
	_refresh_size()
	_btn(box, "Quit", get_tree().quit)

	var ver := Label.new()
	ver.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", int(round(11 * Settings.text_scale)))
	ver.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	box.add_child(ver)



func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", int(round(16 * Settings.text_scale)))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _cycle_size() -> void:
	Session.city_size = SIZE_CYCLE.get(Session.city_size, "small")
	_refresh_size()


func _refresh_size() -> void:
	if _size_btn != null:
		_size_btn.text = SIZE_LABELS.get(Session.city_size, "City: Small")


func _new_game() -> void:
	# iteration 1: the cyberpunk city map (fresh rebuild). Gameplay layers on in later iterations.
	Session.seed = randi()
	Session.interior = {}; Session.hacked = {}; Session.city_return = {}   # a fresh city: no footholds, no progress
	Econ.reset()
	get_tree().change_scene_to_file("res://scenes/city.tscn")


func _continue() -> void:
	Session.start_mode = "netrun_load"
	get_tree().change_scene_to_file("res://scenes/netrun.tscn")


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
