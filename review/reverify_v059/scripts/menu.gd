extends Control
## Main menu: new game (fresh generated map), continue (load save), quit.

var _t := 0.0
var _settings_panel: Control      # T80: accessibility settings reachable before the first run
var _preview_box: HBoxContainer   # T03: live readability preview
var _preview_warn: Label
var _set_btns := {}


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
	cont.disabled = not Session.has_save()
	_btn(box, "Netrun (prototype)", _netrun)   # new discover → scan → hack → expand loop
	_btn(box, "⚙ Accessibility", _open_settings)   # T80: set large text / Reduced Motion before New Game
	_btn(box, "Quit", get_tree().quit)

	var ver := Label.new()
	ver.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", int(round(11 * Settings.text_scale)))
	ver.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	box.add_child(ver)

	_build_settings()


# T80 + T03: a menu-side accessibility panel with a live readability preview. It writes the
# shared Settings autoload (persisted immediately), so the choice carries into the game.
func _build_settings() -> void:
	_settings_panel = Control.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	add_child(_settings_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.add_child(dim)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-240, -210)
	p.custom_minimum_size = Vector2(480, 0)
	_settings_panel.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := Label.new()
	t.text = "Accessibility"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	v.add_child(t)
	_setting_row(v, "rm", "Reduced motion")
	_setting_row(v, "cb", "Colour-blind palette")
	_setting_row(v, "hc", "High contrast")
	_setting_row(v, "ts", "Text size")
	var plabel := Label.new()
	plabel.text = "Preview:"
	plabel.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	v.add_child(plabel)
	var pbg := PanelContainer.new()
	v.add_child(pbg)
	var pv := VBoxContainer.new()
	pbg.add_child(pv)
	_preview_box = HBoxContainer.new()
	_preview_box.add_theme_constant_override("separation", 12)
	pv.add_child(_preview_box)
	_preview_warn = Label.new()
	pv.add_child(_preview_warn)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_settings)
	v.add_child(close)
	_refresh_settings()


func _setting_row(parent: Control, key: String, label: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 40)
	b.pressed.connect(_toggle_setting.bind(key))
	row.add_child(b)
	_set_btns[key] = b
	parent.add_child(row)


func _toggle_setting(key: String) -> void:
	match key:
		"rm": Settings.reduced_motion = not Settings.reduced_motion
		"cb": Settings.cb = not Settings.cb
		"hc": Settings.high_contrast = not Settings.high_contrast
		"ts":
			var s := Settings.text_scale
			Settings.text_scale = 1.25 if s < 1.2 else (1.5 if s < 1.45 else (1.75 if s < 1.7 else (2.0 if s < 1.95 else 1.0)))
	Settings.save_settings()
	_refresh_settings()


func _refresh_settings() -> void:
	_set_btns.rm.text = "On" if Settings.reduced_motion else "Off"
	_set_btns.cb.text = "On" if Settings.cb else "Off"
	_set_btns.hc.text = "On" if Settings.high_contrast else "Off"
	_set_btns.ts.text = "%d%%" % int(Settings.text_scale * 100.0)
	# T03: live preview — resource words in the current palette, at the current size, with a warning
	for c in _preview_box.get_children():
		c.queue_free()
	for pair in [["compute", "Cycles 1234"], ["data", "Intel 567"], ["credits", "Cash 89"]]:
		var w := Label.new()
		w.text = pair[1]
		w.add_theme_color_override("font_color", Settings.res_color(pair[0]))
		w.add_theme_font_size_override("font_size", int(round(18 * Settings.text_scale)))
		_preview_box.add_child(w)
	_preview_warn.text = "⚠ TUNNEL OVERLOADED"
	_preview_warn.add_theme_color_override("font_color", Settings.health_color("bad"))
	_preview_warn.add_theme_font_size_override("font_size", int(round(16 * Settings.text_scale)))


func _open_settings() -> void:
	_settings_panel.visible = true
	_refresh_settings()
	_set_btns.rm.grab_focus()   # T80: initial keyboard focus inside the panel


func _close_settings() -> void:
	_settings_panel.visible = false


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", int(round(16 * Settings.text_scale)))
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


func _netrun() -> void:
	Session.start_mode = "netrun"
	Session.seed = randi()
	get_tree().change_scene_to_file("res://scenes/netrun.tscn")


func _process(delta: float) -> void:
	# B41: honor Reduced Motion in the menu too — freeze the time-driven packet drift so the
	# background stays still (it was already drawn once) instead of animating every frame.
	if Settings.reduced_motion:
		return
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
