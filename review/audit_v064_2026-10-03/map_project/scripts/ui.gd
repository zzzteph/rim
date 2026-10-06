extends Control
## Knights & Merchants-style interface: a left control panel (minimap + Build /
## Stats / Menu tabs), a bottom info panel describing the selection or the active
## tool, a slim resource bar, and pause / victory overlays.

const PANEL_W := 300.0
const INFO_H := 236.0
const SLIM_H := 46.0  # collapsed dashboard height when nothing is selected
const TOP_H := 36.0

@onready var main := get_parent().get_parent()  # UI -> UILayer -> Main

var tab := "build"
var hover_tool := ""
var win_dismissed := false

var top_label: Label
var minimap: Control
var build_box: VBoxContainer
var stats_box: VBoxContainer
var menu_box: VBoxContainer
var jobs_box: VBoxContainer
var _jobs_ver := -1
var _jobs_status := {}
var stats_label: Label
var info_title: Label
var info_body: Label
var sel_box: VBoxContainer
var oc_btn: Button
var remove_btn: Button
var status_label: Label
var pause_overlay: Control
var win_overlay: Control
var win_label: Label
var warn_banner: Label
var netrate_label: Label
var settings_overlay: Control
var setting_btns := {}
var alert_box: VBoxContainer
var alert_btns := {}
var _alert_acc := 1.0   # throttle the all-nodes alert/stats scan to ~4 Hz
var _last_msg := ""     # B32: timed action-result message channel
var _msg_t := 0.0
var _legend_labels := {}   # B44: res key -> legend Label, refreshed on palette change
var _last_pal := [false, false]
var _settings_prev_paused := false   # B35: pause state to restore when Settings closes
var _prev_pausemenu := false         # B38: track pause-menu visibility transitions
var _font_bases := {}                # B29: Control -> base (100%) font size, rescaled on change

const HACK_TOOLS := ["nest", "package", "botfarm", "phish", "scraper", "salami"]
const PROC_TOOLS := ["fence", "forge", "mixer", "lab", "relay"]
const TUNNEL_TOOLS := ["dns", "vpn", "tcp", "http", "proxy"]

var build_scroll: ScrollContainer
var tech_scroll: ScrollContainer
var jobs_scroll: ScrollContainer
var stats_scroll: ScrollContainer
var sel_scroll: ScrollContainer
var tech_box: VBoxContainer
var tool_buttons := {}   # code -> Button (for greying locked tools)
var tech_rows := {}      # tid -> {btn, status}
var build_cat := "hacks"
var build_cat_row: HBoxContainer
var cat_boxes := {}

var power_btn: Button
var rate_label: Label
var rate_down: Button
var rate_up: Button


func _icon(kind := "", res := "", col := Color.WHITE, px := 24.0) -> Control:
	var ic: Control = load("res://scripts/glyph_icon.gd").new()
	ic.kind = kind
	ic.res = res
	ic.col = col
	ic.gsize = px * 0.42
	ic.custom_minimum_size = Vector2(px, px)
	return ic


func _glyph_for(code: String) -> String:
	return "nest_cam" if code == "nest" else code


func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.94)
	sb.border_color = Color(0.2, 1.0, 0.9, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _ready() -> void:
	main.ui = self   # back-reference so main can route Esc to the frontmost modal (B36)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# big, readable text everywhere (children inherit); scaled by the Text Size option
	theme = Theme.new()
	_apply_text_scale()

	# ---- left control panel ----
	# A plain Panel pinned by anchors → its width is ALWAYS PANEL_W and NEVER grows with the
	# active tab's content. col fills it; labels autowrap so nothing spills past the edge.
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style())
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = PANEL_W
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8
	col.offset_top = 8
	col.offset_right = -8
	col.offset_bottom = -8
	panel.add_child(col)

	minimap = load("res://scripts/minimap.gd").new()
	minimap.custom_minimum_size = Vector2(PANEL_W - 16, 148)
	minimap.main = main
	col.add_child(minimap)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	col.add_child(tabs)
	var group := ButtonGroup.new()
	for t in [["build", "Build"], ["tech", "Tech"], ["stats", "Stats"], ["jobs", "Jobs"], ["menu", "Menu"]]:
		var b := Button.new()
		b.text = t[1]
		b.add_theme_font_size_override("font_size", 16)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab.bind(t[0]))
		tabs.add_child(b)
		if t[0] == "build":
			b.button_pressed = true

	# category sub-tabs for the build menu
	build_cat_row = HBoxContainer.new()
	build_cat_row.add_theme_constant_override("separation", 2)
	col.add_child(build_cat_row)
	var cgrp := ButtonGroup.new()
	for cat in [["hacks", "Hacks"], ["proc", "Proc"], ["tunnels", "Links"]]:
		var cb := Button.new()
		cb.text = cat[1]
		cb.toggle_mode = true
		cb.button_group = cgrp
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.add_theme_font_size_override("font_size", 16)
		cb.pressed.connect(_set_build_cat.bind(cat[0]))
		build_cat_row.add_child(cb)
		if cat[0] == "hacks":
			cb.button_pressed = true

	build_scroll = ScrollContainer.new()
	# B27: fill the remaining column height and scroll internally, so the content + the status
	# region below always fit within a 720p viewport at any text scale.
	build_scroll.custom_minimum_size = Vector2(PANEL_W - 16, 120)
	build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(build_scroll)
	build_box = VBoxContainer.new()
	build_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_scroll.add_child(build_box)
	cat_boxes["hacks"] = _cat_box(build_box, HACK_TOOLS, false)
	cat_boxes["proc"] = _cat_box(build_box, PROC_TOOLS, false)
	cat_boxes["tunnels"] = _cat_box(build_box, TUNNEL_TOOLS, true)

	# ---- Tech tree ----
	tech_scroll = ScrollContainer.new()
	tech_scroll.custom_minimum_size = Vector2(PANEL_W - 16, 120)   # B27: fill + scroll within 720p
	tech_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tech_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(tech_scroll)
	tech_box = VBoxContainer.new()
	tech_box.add_theme_constant_override("separation", 8)
	tech_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_scroll.add_child(tech_box)
	_section(tech_box, "RESEARCH")
	for tid in main.TECH:
		_tech_row(tech_box, tid)

	stats_scroll = ScrollContainer.new()
	stats_scroll.custom_minimum_size = Vector2(PANEL_W - 16, 120)   # B27: fill + scroll within 720p
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(stats_scroll)
	stats_box = VBoxContainer.new()
	stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(stats_box)
	_section(stats_box, "BOTNET STATUS")
	stats_label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_box.add_child(stats_label)
	var smoke := Button.new()
	smoke.text = "DDoS Smokescreen  (40 Cy, 1 Tool)"
	smoke.custom_minimum_size = Vector2(0, 40)
	smoke.pressed.connect(main.scrub_trace)
	stats_box.add_child(smoke)
	var graph: Control = load("res://scripts/graph.gd").new()
	graph.main = main
	graph.custom_minimum_size = Vector2(PANEL_W - 16, 90)
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.add_child(graph)

	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 4)
	col.add_child(menu_box)
	_section(menu_box, "MENU")
	_menu_btn(menu_box, "⚙ Settings", _open_settings)
	_menu_btn(menu_box, "Save Game", main.save_game)
	_menu_btn(menu_box, "Load Game", main.load_game)
	_menu_btn(menu_box, "Main Menu", main.go_main_menu)
	_menu_btn(menu_box, "Quit", main.quit_game)

	# B28: the Jobs board scrolls so 3+ cards (and their accept/claim buttons) stay reachable at 720p
	jobs_scroll = ScrollContainer.new()
	jobs_scroll.custom_minimum_size = Vector2(PANEL_W - 16, 120)   # B27/B28: fill + scroll within 720p
	jobs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	jobs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(jobs_scroll)
	jobs_box = VBoxContainer.new()
	jobs_box.add_theme_constant_override("separation", 6)
	jobs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jobs_scroll.add_child(jobs_box)

	# ---- top resource bar ----
	var top := ColorRect.new()
	top.color = Color(0.03, 0.04, 0.07, 1.0)  # solid, not transparent
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = PANEL_W
	top.offset_bottom = TOP_H + 28  # also backs the legend / net-rate second line
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	top_label = Label.new()
	top_label.position = Vector2(PANEL_W + 12, 7)
	top_label.add_theme_font_size_override("font_size", 18)
	top_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_label)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 14)
	legend.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	legend.position = Vector2(-680, TOP_H + 6)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in [["compute", "Cycles"], ["data", "Intel"], ["crypto", "Crypto"], ["tools", "Tools"], ["research", "Research"], ["credits", "Cash"]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(_icon("", pair[0], Color.WHITE, 22.0))
		var l := Label.new()
		l.text = pair[1]
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Settings.res_color(pair[0]))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_legend_labels[pair[0]] = l   # B44: refresh these when the palette changes
		item.add_child(l)
		legend.add_child(item)
	add_child(legend)

	warn_banner = Label.new()
	warn_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	warn_banner.offset_left = PANEL_W
	warn_banner.offset_right = -16
	# B47: own row, below the net-rate line, so critical warnings never overlap the rate text
	warn_banner.offset_top = TOP_H + 30
	warn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_banner.add_theme_font_size_override("font_size", 17)
	warn_banner.add_theme_color_override("font_color", Color(1.0, 0.6, 0.25))
	warn_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warn_banner.visible = false
	add_child(warn_banner)

	# ---- net-rate HUD (second line, left) ----
	netrate_label = Label.new()
	netrate_label.position = Vector2(PANEL_W + 12, TOP_H + 6)
	netrate_label.add_theme_font_size_override("font_size", 15)
	netrate_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.85))
	netrate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(netrate_label)

	# ---- alerts strip (top-right, click an alert to jump to the problem) ----
	alert_box = VBoxContainer.new()
	alert_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	alert_box.position = Vector2(-356, TOP_H + 34)
	alert_box.add_theme_constant_override("separation", 3)
	add_child(alert_box)
	for kind in ["overload", "offline", "starved", "trace"]:
		var ab := Button.new()
		ab.visible = false
		ab.clip_text = true
		ab.custom_minimum_size = Vector2(340, 30)
		ab.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
		ab.add_theme_font_size_override("font_size", 15)
		ab.tooltip_text = "Click to jump to the problem"
		ab.pressed.connect(_jump_alert.bind(kind))
		alert_box.add_child(ab)
		alert_btns[kind] = ab

	# ---- selection info (LEFT panel): shown when a structure/tunnel is selected ----
	# B27: wrap the inspector in a scroll so long descriptions (esp. at 200% text) stay reachable.
	sel_scroll = ScrollContainer.new()
	sel_scroll.custom_minimum_size = Vector2(PANEL_W - 16, 120)
	sel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sel_scroll.visible = false
	col.add_child(sel_scroll)
	sel_box = VBoxContainer.new()
	sel_box.add_theme_constant_override("separation", 6)
	sel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_scroll.add_child(sel_box)
	info_title = Label.new()
	info_title.add_theme_font_size_override("font_size", 20)
	info_title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_box.add_child(info_title)
	info_body = Label.new()
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.add_theme_font_size_override("font_size", 16)
	sel_box.add_child(info_body)
	remove_btn = Button.new()
	remove_btn.text = "Dismantle  (Del)"
	remove_btn.custom_minimum_size = Vector2(0, 44)
	remove_btn.pressed.connect(main.remove_selected)
	remove_btn.visible = false
	sel_box.add_child(remove_btn)
	power_btn = Button.new()
	power_btn.text = "Disable"
	power_btn.custom_minimum_size = Vector2(0, 40)
	power_btn.pressed.connect(main.toggle_selected)
	power_btn.visible = false
	sel_box.add_child(power_btn)
	oc_btn = Button.new()
	oc_btn.text = "⚡ Overclock  (O)"
	oc_btn.custom_minimum_size = Vector2(0, 40)
	oc_btn.pressed.connect(main.overclock_selected)
	oc_btn.visible = false
	sel_box.add_child(oc_btn)
	var rate_row := HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 4)
	rate_row.name = "RateRow"
	rate_row.visible = false
	rate_down = Button.new()
	rate_down.text = "−"
	rate_down.custom_minimum_size = Vector2(46, 38)
	rate_down.pressed.connect(main.adjust_rate_selected.bind(-0.25))
	rate_row.add_child(rate_down)
	rate_label = Label.new()
	rate_label.text = "Limit 100%"
	rate_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_label.add_theme_font_size_override("font_size", 15)
	rate_row.add_child(rate_label)
	rate_up = Button.new()
	rate_up.text = "+"
	rate_up.custom_minimum_size = Vector2(46, 38)
	rate_up.pressed.connect(main.adjust_rate_selected.bind(0.25))
	rate_row.add_child(rate_up)
	sel_box.add_child(rate_row)
	# ---- persistent status line at the bottom of the left panel ----
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.85))
	col.add_child(status_label)

	# ---- overlays ----
	pause_overlay = _overlay("PAUSED", [
		["Resume", _resume_from_menu],
		["⚙ Settings", _open_settings],
		["Save Game", main.save_game],
		["Load Game", main.load_game],
		["Main Menu", main.go_main_menu],
		["Quit", main.quit_game],
	])
	win_overlay = _overlay("GOAL REACHED", [
		["Keep Playing", _dismiss_win],
		["Main Menu", main.go_main_menu],
	])
	win_label = win_overlay.get_meta("title")
	_build_settings()
	# cap every button's width (clip long labels) so no tab's content can ever widen
	# the fixed-width side panel — this is what kept resizing it between tabs
	for b in find_children("", "Button", true, false):
		b.clip_text = true
	_register_and_scale_fonts()   # B29: snapshot baseline font sizes and apply the current scale


func _build_settings() -> void:
	settings_overlay = Control.new()
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	add_child(settings_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style())
	p.custom_minimum_size = Vector2(460, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-230, -200)
	settings_overlay.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := Label.new()
	t.text = "SETTINGS · Accessibility"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	v.add_child(t)
	setting_btns["rm"] = _setting_row(v, "Reduced motion", "rm")
	setting_btns["cb"] = _setting_row(v, "Colour-blind palette", "cb")
	setting_btns["hc"] = _setting_row(v, "High contrast", "hc")
	setting_btns["dots"] = _setting_row(v, "Packet style", "dots")
	setting_btns["ts"] = _setting_row(v, "Text size", "ts")
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 42)
	close.pressed.connect(_close_settings)
	v.add_child(close)


func _setting_row(parent: Control, label: String, key: String) -> Button:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 17)
	h.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 40)
	b.pressed.connect(_toggle_setting.bind(key))
	h.add_child(b)
	parent.add_child(h)
	return b


func _toggle_setting(key: String) -> void:
	match key:
		"rm":
			Settings.reduced_motion = not Settings.reduced_motion
		"cb":
			Settings.cb = not Settings.cb
		"hc":
			Settings.high_contrast = not Settings.high_contrast
			main._invalidate_city()
		"dots":
			Settings.dots = not Settings.dots
		"ts":
			if Settings.text_scale < 1.2:
				Settings.text_scale = 1.25
			elif Settings.text_scale < 1.45:
				Settings.text_scale = 1.5
			elif Settings.text_scale < 1.7:
				Settings.text_scale = 1.75
			elif Settings.text_scale < 1.95:
				Settings.text_scale = 2.0
			else:
				Settings.text_scale = 1.0
			_register_and_scale_fonts()   # B29: rescale every registered control
	Settings.save_settings()


func _resume_from_menu() -> void:
	main.pause_menu = false
	main.paused = main._menu_prev_paused   # B39: back to whatever planning-pause state preceded the menu


func _open_settings() -> void:
	_settings_prev_paused = main.paused
	main.paused = true   # B35: freeze the sim while the blocking Settings modal is open
	settings_overlay.visible = true
	_grab_modal_focus()  # B38


func _close_settings() -> void:
	settings_overlay.visible = false
	main.paused = _settings_prev_paused   # B35: restore the prior pause state


# B36: called by main when Esc is pressed while a blocking modal is open — dismiss the front one.
func close_topmost_modal() -> void:
	if settings_overlay.visible:
		_close_settings()
	elif win_overlay.visible:
		win_dismissed = true


# B38: move keyboard focus to the first button inside whichever modal is on top.
func _grab_modal_focus() -> void:
	var host: Control = null
	if settings_overlay.visible:
		host = settings_overlay
	elif win_overlay.visible:
		host = win_overlay
	elif pause_overlay.visible:
		host = pause_overlay
	if host != null:
		var btns := host.find_children("", "Button", true, false)
		if not btns.is_empty():
			btns[0].grab_focus()


func _set_build_cat(c: String) -> void:
	build_cat = c


func _cat_box(parent: Control, tools: Array, is_tunnel: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	parent.add_child(box)
	for code in tools:
		_tool_entry(box, code, Color(0.6, 0.65, 0.75) if is_tunnel else main.COLORS[code])
	return box


func _section(parent: Control, text: String) -> void:
	if parent.get_child_count() > 0:
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 10)
		parent.add_child(sep)
	var l := Label.new()
	l.text = "▸ " + text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9, 0.95))
	parent.add_child(l)


func _tool_entry(parent: Control, code: String, chip: Color) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 52)
	b.tooltip_text = main._tool_name(code) + "\n" + main._tool_homage(code) + "\nCost: " + main._cost_str(code)
	b.pressed.connect(_on_tool.bind(code))
	b.mouse_entered.connect(_on_hover.bind(code))
	b.mouse_exited.connect(_on_unhover.bind(code))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	h.offset_left = 8
	h.offset_right = -4
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_tunnel := code in TUNNEL_TOOLS
	h.add_child(_icon(_glyph_for(code), "", chip if is_tunnel else main._sem_color(code), 46.0))   # B43
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := Label.new()
	nm.text = main._tool_name(code)
	nm.add_theme_font_size_override("font_size", 17)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var cost := Label.new()
	cost.text = main._cost_str(code)
	cost.add_theme_font_size_override("font_size", 15)
	cost.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cost)
	h.add_child(v)
	b.add_child(h)
	tool_buttons[code] = b
	parent.add_child(b)


func _tech_row(parent: Control, tid: String) -> void:
	var t = main.TECH[tid]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style())
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var nm := Label.new()
	nm.text = str(t.name)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_size_override("font_size", 16)
	nm.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	v.add_child(nm)
	var desc := Label.new()
	desc.text = str(t.desc)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.72, 0.78, 0.85))
	v.add_child(desc)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 34)
	btn.pressed.connect(main.research_tech.bind(tid))
	v.add_child(btn)
	tech_rows[tid] = {"btn": btn}


func _menu_btn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _overlay(title: String, buttons: Array) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	add_child(o)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style())
	# B40: bounded, centred panel that stays within 1280×720; the title wraps so a long
	# victory result string can never stretch the panel past the viewport edge.
	p.custom_minimum_size = Vector2(560, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-280, -180)
	o.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(520, 0)
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	v.add_child(t)
	o.set_meta("title", t)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(b[1])
		v.add_child(btn)
	return o


func _apply_text_scale() -> void:
	if theme:
		theme.default_font_size = int(round(19 * Settings.text_scale))
	# B29: also rescale every control that set its own fixed font-size override, so the whole
	# interface (HUD, body, status, tabs, buttons) scales — not just defaulted text.
	for c in _font_bases:
		if is_instance_valid(c):
			c.add_theme_font_size_override("font_size", maxi(8, int(round(float(_font_bases[c]) * Settings.text_scale))))


# Snapshot the 100%-baseline font size of every overridden Label/Button once, then rescale.
# New controls (job cards, tech rows) are picked up on later calls without clobbering bases.
func _register_and_scale_fonts() -> void:
	# NOTE: find_children needs a concrete type — an empty type string matches nothing.
	var controls := find_children("", "Label", true, false)
	controls.append_array(find_children("", "Button", true, false))
	for c in controls:
		if not _font_bases.has(c) and c.has_theme_font_size_override("font_size"):
			_font_bases[c] = c.get_theme_font_size("font_size")
	_apply_text_scale()


func _on_tab(code: String) -> void:
	tab = code
	# B30: navigation is an explicit state — opening a tab closes the inspector / disarms the
	# tool so the chosen tab's content is actually shown (selection otherwise hid it).
	main.selected_id = -1
	main.selected_tunnel = -1
	main.current_tool = ""
	main.pending_child = -1
	hover_tool = ""


func _on_tool(code: String) -> void:
	main.set_tool(code)


func _on_hover(code: String) -> void:
	hover_tool = code


func _on_unhover(code: String) -> void:
	if hover_tool == code:
		hover_tool = ""


func _dismiss_win() -> void:
	win_dismissed = true


func _rebuild_jobs() -> void:
	for ch in jobs_box.get_children():
		ch.queue_free()
	_jobs_status = {}
	_section(jobs_box, "CONTRACTS")
	if main.contracts.is_empty():
		var l := Label.new()
		l.text = "No contracts yet — a darknet client will reach out soon."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 15)
		jobs_box.add_child(l)
		return
	for c in main.contracts:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style())
		jobs_box.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var title := Label.new()
		title.text = str(c.client)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		v.add_child(title)
		var desc := Label.new()
		desc.text = "%s\nPays: %d Cash · %d RP" % [str(c.desc), int(c.reward_cash), int(c.reward_rp)]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 15)
		v.add_child(desc)
		var status := Label.new()
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.add_theme_font_size_override("font_size", 14)
		status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.85))
		v.add_child(status)
		_jobs_status[int(c.id)] = status
		var btn := Button.new()
		btn.clip_text = true
		btn.custom_minimum_size = Vector2(0, 34)
		if c.done:
			btn.text = "CLAIM REWARD"
			btn.pressed.connect(main.claim_contract.bind(int(c.id)))
		elif c.accepted:
			btn.text = "Accepted — in progress"
			btn.disabled = true
		else:
			btn.text = "Accept"
			btn.pressed.connect(main.accept_contract.bind(int(c.id)))
		v.add_child(btn)
	_register_and_scale_fonts()   # B29: scale the freshly-built job-card text too


func _set_alert(kind: String, active: bool, text: String) -> void:
	var b = alert_btns.get(kind)
	if b == null:
		return
	b.visible = active
	if active:
		b.text = text


func _jump_alert(kind: String) -> void:
	var target := -1
	for id in main.nodes:
		if id == main.hub_id:
			continue
		if kind == "overload" and main.nodes[id].parent != -1 and main._edge.has(id) and main._edge[id].get("over", false):
			target = id
		elif kind == "offline" and main.nodes[id].get("on", true) and not main._connected.has(id):
			target = id   # includes never-linked nodes (B33)
		if target != -1:
			break
	if target == -1 and (kind == "starved" or kind == "trace"):
		target = main.hub_id
	if target != -1 and main.nodes.has(target):
		# B34: establish one coherent selection — clear any prior tunnel selection / armed tool
		# so the inspector describes exactly the jumped-to object.
		main.camera.position = main._center_world(target)
		main.selected_tunnel = -1
		main.current_tool = ""
		main.pending_child = -1
		main.selected_id = target


func _process(_delta: float) -> void:
	if main == null:
		return
	# B44: when the palette toggles, refresh the cached legend label colours immediately
	var pal := [Settings.cb, Settings.high_contrast]
	if pal != _last_pal:
		_last_pal = pal
		for k in _legend_labels:
			_legend_labels[k].add_theme_color_override("font_color", Settings.res_color(k))
	var r = main.resources
	var pct := int(min(100.0, r.credits / main.GOAL_CREDITS * 100.0))
	var tr := int(main.trace)
	var hot := "  ⚠" if main.trace > main.TRACE_HOT else ""
	top_label.text = "Cycles %d  Intel %d  Crypto %d  Tools %d  Research %d  Cash %d   |   Trace %d%%%s   |   Up %.1f/s feed %d%%   |   Goal %d%%" % [
		int(r.compute), int(r.data), int(r.crypto), int(r.tools), int(r.research), int(r.credits),
		tr, hot, main.total_upkeep, int(main.slow_factor * 100.0), pct,
	]
	if not main.sweep.is_empty():
		warn_banner.visible = true
		warn_banner.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
		if float(main.sweep.get("warn", 0.0)) > 0.0:
			warn_banner.text = "⚠ ICE SWEEP INBOUND — %ds to impact" % int(ceil(float(main.sweep.warn)))
		else:
			# remaining edge transitions to C2 = path.size - step - 1 (reaches 0 at C2) — B59
			var hops: int = maxi(0, int(main.sweep.path.size()) - int(main.sweep.step) - 1)
			warn_banner.text = "⚠ ICE SWEEP — %d hop%s to C2" % [hops, "" if hops == 1 else "s"]
	elif main.warn_overload:
		warn_banner.visible = true
		warn_banner.add_theme_color_override("font_color", Color(1.0, 0.6, 0.25))
		warn_banner.text = "⚠ TUNNEL OVERLOAD — dropping packets"
	else:
		warn_banner.visible = false
	# ---- alerts strip (throttled: an all-nodes scan every frame was pure overhead) ----
	_alert_acc += _delta
	if _alert_acc >= 0.25:
		_alert_acc = 0.0
		var n_over := 0
		var n_off := 0
		for id in main.nodes:
			if id == main.hub_id:
				continue
			if main.nodes[id].parent != -1 and main._edge.has(id) and main._edge[id].get("over", false):
				n_over += 1
			# B33: any structure the player intends to run but that has no live C2 route counts
			# as offline — including never-linked nodes (parent == -1) and detached branches.
			# Intentionally disabled nodes are a separate state and are not flagged here.
			if main.nodes[id].get("on", true) and not main._connected.has(id):
				n_off += 1
		_set_alert("overload", n_over > 0, "⚠ %d tunnel(s) OVERLOADED  →" % n_over)
		_set_alert("offline", n_off > 0, "⚠ %d structure(s) OFFLINE / unlinked  →" % n_off)
		_set_alert("starved", main.slow_factor < 0.98, "⚠ Network STARVED %d%%  →" % int(main.slow_factor * 100.0))
		_set_alert("trace", main.trace > main.TRACE_HOT, "⚠ Trace CRITICAL %d%%  →" % int(main.trace))
	var sel: bool = main.selected_id != -1 or main.selected_tunnel != -1
	# B31: the info panel also hosts armed-tool help, so show it whenever a tool is armed, not
	# only when a map object is selected — otherwise tool/cost/ICE help is invisible.
	var show_info: bool = sel or main.current_tool != ""
	sel_scroll.visible = show_info
	build_scroll.visible = (not show_info) and tab == "build"
	build_cat_row.visible = (not show_info) and tab == "build"
	for c in cat_boxes:
		cat_boxes[c].visible = (not show_info) and tab == "build" and build_cat == c
	tech_scroll.visible = (not show_info) and tab == "tech"
	stats_scroll.visible = (not show_info) and tab == "stats"
	jobs_scroll.visible = (not show_info) and tab == "jobs"
	menu_box.visible = (not show_info) and tab == "menu"
	if main._contracts_ver != _jobs_ver:
		_jobs_ver = main._contracts_ver
		_rebuild_jobs()
	for jc in main.contracts:
		var st = _jobs_status.get(int(jc.id))
		if st != null:
			if jc.done:
				st.text = "✓ COMPLETE — claim your reward"
			elif jc.accepted:
				st.text = "%d / %d    ⏱ %ds left" % [int(main._contract_progress(jc)), int(jc.amount), int(max(0.0, float(jc.deadline)))]
			else:
				st.text = "Reward on completion · %ds timer once accepted" % int(jc.deadline)
	# grey out locked tools
	for code in tool_buttons:
		var unlocked: bool = main._is_unlocked(code)
		var btn: Button = tool_buttons[code]
		btn.disabled = not unlocked
		btn.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.45, 0.45, 0.5, 1)
	# update tech rows
	if tab == "tech":
		for tid in tech_rows:
			var t = main.TECH[tid]
			var b: Button = tech_rows[tid].btn
			if main.researched.has(tid):
				b.text = "✓ Researched"
				b.disabled = true
			else:
				var ready := true
				for req in t.requires:
					if not main.researched.has(req):
						ready = false
				if not ready:
					b.text = "Locked — needs %s" % main.TECH[t.requires[0]].name
					b.disabled = true
				else:
					b.text = "Research  (%d RP)" % int(t.cost)
					b.disabled = main.resources.research < float(t.cost)
	if tab == "stats":
		var tunnels := 0
		for id in main.nodes:
			if main.nodes[id].parent != -1:
				tunnels += 1
		stats_label.text = "Cycles: %d\nIntel: %d\nCrypto: %d\nTools: %d\nCash: %d / %d\n\nTrace: %d%%%s\nStructures: %d\nTunnels: %d\nIn transit: %d\nUpkeep: %.2f Cycles/s\nFeed: %d%%%s\n\nSeed: %d" % [
			int(r.compute), int(r.data), int(r.crypto), int(r.tools), int(r.credits), int(main.GOAL_CREDITS),
			int(main.trace), (" ⚠ ICE hot" if main.trace > main.TRACE_HOT else ""),
			main.nodes.size(), tunnels, main.packets.size(), main.total_upkeep,
			int(main.slow_factor * 100.0), ("\n⚠ a tunnel is overloaded" if main.warn_overload else ""), main.seed,
		]
	# net-rate HUD: production − consumption per second + ETA to the Cash goal
	var nr := ""
	for k in ["compute", "data", "credits"]:
		var v: float = main.rates.get(k, 0.0)
		if absf(v) >= 0.05:
			nr += "%s %+.1f/s    " % [main.RES_NAMES[k], v]
	var cr: float = main.rates.get("credits", 0.0)
	if cr > 0.01 and main.resources.credits < main.GOAL_CREDITS:
		var eta := int((main.GOAL_CREDITS - main.resources.credits) / cr)
		nr += "ETA %d:%02d" % [eta / 60, eta % 60]
	netrate_label.text = nr
	if settings_overlay.visible:
		setting_btns.rm.text = "On" if Settings.reduced_motion else "Off"
		setting_btns.cb.text = "On" if Settings.cb else "Off"
		setting_btns.hc.text = "On" if Settings.high_contrast else "Off"
		setting_btns.dots.text = "Dots" if Settings.dots else "Code"
		setting_btns.ts.text = "%d%%" % int(Settings.text_scale * 100.0)
	# B39: the modal PAUSE MENU is its own state (planning pause does not show the dimmer)
	pause_overlay.visible = main.pause_menu
	win_overlay.visible = main.won and not win_dismissed
	# B35-B38: tell the sim which blocking modals are open, and keep focus inside a modal
	var was_modal: bool = main.modal_open
	main.modal_open = settings_overlay.visible or win_overlay.visible
	if (main.modal_open or pause_overlay.visible) and not (was_modal or _prev_pausemenu):
		_grab_modal_focus()   # B38: move focus into the newly-opened modal
	_prev_pausemenu = pause_overlay.visible
	if main.won:
		win_label.text = "GOAL REACHED — %d CASH\n%s" % [int(main.GOAL_CREDITS), main._scorecard()]
	_update_info()
	# B32: an action result (save, placement failure, reward, …) gets a dedicated timed
	# channel so it stays visible briefly before tool hints / next-step guidance resume.
	if main.message != _last_msg:
		_last_msg = main.message
		if main.message != "":
			_msg_t = 3.0
	_msg_t = maxf(0.0, _msg_t - _delta)
	if _msg_t > 0.0:
		status_label.text = main.message
	elif main.hint != "":
		status_label.text = main.hint
	elif main.selected_id == -1 and main.selected_tunnel == -1 and main.current_tool == "":
		status_label.text = "→ " + main._next_step()
	else:
		status_label.text = main.message


func _update_info() -> void:
	remove_btn.visible = false
	power_btn.visible = false
	oc_btn.visible = false
	var rate_row := power_btn.get_parent().get_node("RateRow")
	rate_row.visible = false
	var nodes = main.nodes
	if main.current_tool != "":
		var code: String = main.current_tool
		info_title.text = main._tool_name(code)
		info_body.text = main._tool_homage(code) + "\nCost: " + main._cost_str(code) + "\n" + main.hint
	elif main.selected_tunnel != -1 and nodes.has(main.selected_tunnel) and nodes[main.selected_tunnel].get("tunnel", "") != "":
		var tid: int = main.selected_tunnel
		var tn = nodes[tid]
		info_title.text = main.TUNNEL_DEFS[tn.tunnel].name
		var tl := [str(main.TUNNEL_DEFS[tn.tunnel].homage)]
		tl.append("Latency: %d pkt    Capacity: %d/s" % [int(main._edge_len(tid, tn.parent)), int(main.CAP[tn.tunnel])])
		tl.append("Links %s → %s" % [main._node_name(tid), main._node_name(tn.parent)])
		if main._edge.has(tid):
			var e = main._edge[tid]
			if e.get("over", false):
				tl.append("⚠ OVERLOADED: carrying %.1f/s but this link holds only %.1f/s. Use a fatter tunnel (Reverse Shell), split the load via a Proxy, or lower the source's Output." % [float(e.get("offered", 0.0)), float(e.get("cap", 0.0))])
			# B58: attribute each loss cause honestly instead of calling it all "distance"
			if float(e.frac) < 0.999:
				var parts := []
				var dl := int(round(float(e.get("dist_loss", 0.0)) * 100.0))
				var ol := int(round(float(e.get("over_loss", 0.0)) * 100.0))
				if dl > 0:
					parts.append("%d%% distance" % dl)
				if ol > 0:
					parts.append("%d%% overload" % ol)
				if e.get("trace_hot", false):
					parts.append("20% ICE (Trace hot)")
				tl.append("Delivery %d%% — %s. A Proxy/shorter hop cuts distance; scrub Trace to lift the ICE penalty." % [
					int(round(float(e.frac) * 100.0)), ("losses: " + ", ".join(parts)) if not parts.is_empty() else "clean"])
		info_body.text = "\n".join(tl)
		remove_btn.visible = true
	elif main.selected_id != -1 and nodes.has(main.selected_id):
		var id: int = main.selected_id
		var n = nodes[id]
		var is_relay: bool = n.get("relay", false)
		var donor = main.DEFS[n.type]
		# B56: a converted Proxy describes its OWN forwarding identity, not the donor's
		# production. Donor provenance stays in the title only.
		var d = main.DEFS["relay"] if is_relay else donor
		var title: String = main._node_name(id)
		if is_relay:
			title += "  (from %s)" % donor.name
		if not n.get("on", true):
			title += "   [DISABLED]"
		info_title.text = title
		var lines := [str(d.homage)]
		var zone: String = main.ZONE_NAMES.get(main._tile_type(n.cell), "")
		lines.append("Zone: %s    Footprint: %d×%d" % [zone, n.size, n.size])
		var prod = main._production(id)
		if not prod.is_empty():
			var k = prod.keys()[0]
			lines.append("Produces: %s %.1f/s" % [main.RES_NAMES.get(k, k), prod[k]])
			lines.append("Covers %d buildings  →  ×%.1f output (denser = more)" % [int(n.get("coverage", 0)), main._cov_mult(id)])
		elif main.CONV.has(n.type):
			var cv = main.CONV[n.type]
			var fuel := ""
			if cv.has("fuel"):
				fuel = " (burns %d %s each)" % [int(cv.fuelcost), main.RES_NAMES.get(cv.fuel, cv.fuel)]
			lines.append("Converts %s → %s at %.1f/s%s while linked to C2." % [
				main.RES_NAMES.get(cv.in, cv.in), main.RES_NAMES.get(cv.out, cv.out), cv.rate, fuel])
		if is_relay:
			lines.append("Proxy — forwards data toward C2 at ~0.4× upkeep; it no longer produces.")
			lines.append("Extends reach: vision %d tiles." % int(main.VISION.get("relay", 15)))
		elif main.DEFS[n.type].get("range", false):
			lines.append("Sweeps buildings within %d tiles — denser coverage boosts output." % int(main.COVERAGE_RADIUS))
		if n.type != "hub":
			if n.parent != -1 and nodes.has(n.parent):
				lines.append("Tunnel out: %s, latency %d pkt → %s" % [
					main.TUNNEL_DEFS[n.tunnel].name, int(main._edge_len(id, n.parent)), main._node_name(n.parent)])
			else:
				lines.append("No tunnel out — not linked to C2.")
			# B57: quarantine (temporary ICE lockout on an intact branch) is a different cause
			# than a severed link — report each distinctly so the player knows what to do.
			var q: float = float(n.get("quarantine", 0.0))
			var status := ""
			if not n.get("on", true):
				status = "DISABLED"
			elif q > 0.0 and main._reaches_hub(id):
				status = "QUARANTINED by ICE — %ds left (branch intact; wait it out or DDoS)" % int(ceil(q))
			elif main._connected.has(id):
				status = "ONLINE"
			else:
				status = "OFFLINE — no path to C2"
			lines.append("Status: " + status)
			remove_btn.visible = true
			power_btn.visible = true
			power_btn.text = ("Enable  (E)" if not n.get("on", true) else "Disable  (E)")
			if main._is_producer(n.type) and not n.get("relay", false):
				rate_row.visible = true
				oc_btn.visible = true
				rate_label.text = "Output %d%%" % int(float(n.get("cap_rate", 1.0)) * 100.0)
		info_body.text = "\n".join(lines)
	elif hover_tool != "" and hover_tool != "cancel":
		info_title.text = main._tool_name(hover_tool)
		info_body.text = main._tool_homage(hover_tool) + "\nCost: " + main._cost_str(hover_tool)
	else:
		info_title.text = "C2 Console"
		info_body.text = "Cash is SOLD, not mined. Steal Intel with a Phishing Kit (on blue Intel ground — Glasshouse Row or The Feeds), tunnel it back to your C2, then build a Darknet Market to sell that Intel for Cash.\nBuild: pick a hack on the left, click the map, then link it to C2 with a tunnel. WASD pans, wheel zooms, Ctrl+Z undoes, Esc = menu.\nICE = district security: a guarded district (shown 'ICE N') charges N extra Tools to breach when you build there, and raises Trace. Forge Tools in an Exploit Forge first.\n→ Next: %s\nGoal: reach %d Cash." % [main._next_step(), int(main.GOAL_CREDITS)]
