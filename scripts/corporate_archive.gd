extends CanvasLayer
## Readable story and email archive for one corporate building.

signal closed

const ACCENT := Color(0.2, 1.0, 0.9)
const INK := Color(0.86, 0.92, 1.0)
const MUTED := Color(0.65, 0.75, 0.86)

var _root: Control
var _heading: Label
var _picker: OptionButton
var _tabs: TabContainer
var _story_title: Label
var _story_body: RichTextLabel
var _cast: Label
var _mail_list: ItemList
var _mail_subject: Label
var _mail_meta: Label
var _mail_body: RichTextLabel
var _previous: Button
var _next: Button
var _position: Label
var _close_button: Button
var _records: Array = []
var _case_index := 0
var _mail_index := 0


func _ready() -> void:
	layer = 20
	_build()
	_root.hide()


func is_open() -> bool:
	return _root != null and _root.visible


func open_for(building: Dictionary) -> void:
	_records = building.get("corporate_records", [])
	if _records.is_empty(): return
	_heading.text = "%s\n%s · Corporate records" % [str(building.bname), str(building.occupant)]
	_picker.clear()
	for record in _records:
		_picker.add_item(str(record.title))
	_picker.select(0)
	_select_case(0)
	_tabs.current_tab = 0
	_root.show()
	_close_button.grab_focus()


func close() -> void:
	if not is_open(): return
	_root.hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _label(parent: Node, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", int(round(font_size * Settings.text_scale)))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _text(parent: Node) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = false
	text.selection_enabled = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.y = 80
	text.add_theme_font_size_override("normal_font_size", int(round(17 * Settings.text_scale)))
	text.add_theme_color_override("default_color", INK)
	text.add_theme_constant_override("line_separation", 5)
	parent.add_child(text)
	return text


func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size", int(round(15 * Settings.text_scale)))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _build() -> void:
	_root = Control.new()
	_root.name = "CorporateArchive"
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.02, 0.04, 0.94)
	var panel := PanelContainer.new()
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24; panel.offset_top = 24; panel.offset_right = -24; panel.offset_bottom = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.08)
	style.border_color = Color(0.2, 0.75, 0.75)
	style.set_border_width_all(1); style.set_corner_radius_all(6)
	style.content_margin_left = 18; style.content_margin_right = 18
	style.content_margin_top = 14; style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	panel.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	_heading = _label(header, 19, ACCENT)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button = _button(header, "Close · Esc", close)
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var choose := HBoxContainer.new()
	page.add_child(choose)
	var caption := _label(choose, 14, MUTED)
	caption.text = "Case file"
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_picker = OptionButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.add_theme_font_size_override("font_size", int(round(16 * Settings.text_scale)))
	_picker.item_selected.connect(_select_case)
	choose.add_child(_picker)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", int(round(16 * Settings.text_scale)))
	page.add_child(_tabs)
	var overview := VBoxContainer.new()
	overview.name = "Story"
	overview.add_theme_constant_override("separation", 12)
	_tabs.add_child(overview)
	_story_title = _label(overview, 22, ACCENT)
	_story_body = _text(overview)
	_cast = _label(overview, 14, MUTED)
	var mailbox := HSplitContainer.new()
	mailbox.name = "Emails"
	mailbox.add_theme_constant_override("separation", 16)
	_tabs.add_child(mailbox)
	_mail_list = ItemList.new()
	_mail_list.custom_minimum_size = Vector2(280, 0)
	_mail_list.size_flags_horizontal = Control.SIZE_FILL
	_mail_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mail_list.add_theme_font_size_override("font_size", int(round(14 * Settings.text_scale)))
	_mail_list.add_theme_constant_override("v_separation", 12)
	_mail_list.item_selected.connect(_select_email)
	mailbox.add_child(_mail_list)
	var reader := VBoxContainer.new()
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader.add_theme_constant_override("separation", 10)
	mailbox.add_child(reader)
	_mail_subject = _label(reader, 21, ACCENT)
	_mail_meta = _label(reader, 14, MUTED)
	reader.add_child(HSeparator.new())
	_mail_body = _text(reader)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	reader.add_child(navigation)
	_previous = _button(navigation, "Previous", func(): _select_email(_mail_index - 1))
	_position = _label(navigation, 14, MUTED)
	_position.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_position.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next = _button(navigation, "Next", func(): _select_email(_mail_index + 1))


func _select_case(index: int) -> void:
	if index < 0 or index >= _records.size(): return
	_case_index = index
	var record: Dictionary = _records[index]
	_story_title.text = str(record.title)
	_story_body.text = str(record.story)
	_story_body.scroll_to_line(0)
	var people := PackedStringArray(["People in this story"])
	for person in record.cast:
		people.append("%s — %s" % [str(person.name), str(person.job)])
	_cast.text = "\n".join(people)
	_mail_list.clear()
	for i in record.emails.size():
		var message: Dictionary = record.emails[i]
		_mail_list.add_item("%02d  %s" % [i + 1, str(message.subject)])
		_mail_list.set_item_tooltip(i, "%s\nFrom: %s\n%s" % [str(message.subject), str(message.from), str(message.sent)])
	_tabs.set_tab_title(1, "Emails (%d)" % record.emails.size())
	_select_email(0)


func _select_email(index: int) -> void:
	if _records.is_empty(): return
	var emails: Array = _records[_case_index].emails
	if index < 0 or index >= emails.size(): return
	_mail_index = index
	var message: Dictionary = emails[index]
	_mail_list.select(index)
	_mail_list.ensure_current_is_visible()
	_mail_subject.text = str(message.subject)
	_mail_meta.text = "From: %s — %s\nTo: %s\nSent: %s" % [
		str(message.from), str(message.from_job), str(message.to), str(message.sent)]
	_mail_body.text = str(message.body)
	_mail_body.scroll_to_line(0)
	_previous.disabled = index == 0
	_next.disabled = index == emails.size() - 1
	_position.text = "%d of %d" % [index + 1, emails.size()]
