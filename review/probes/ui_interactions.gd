extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var session = root.get_node("Session")
	session.start_mode = "new"
	session.seed = 42
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _settle()
	var ui = game.get_node("UILayer/UI")
	var node = game.nodes[game.hub_id].duplicate(true)
	node.id = 2
	node.type = "nest"
	node.size = 2
	node.cell += Vector2i(8, 0)
	node.parent = -1
	game.nodes[2] = node
	await _settle()
	print("UNLINKED OFFLINE ALERT ",ui.alert_btns.offline.visible," connected=",game._connected.has(2))
	game.selected_id = 2
	ui._open_settings()
	var disable = InputEventKey.new()
	disable.keycode = KEY_E
	disable.pressed = true
	game._input(disable)
	print("SETTINGS SHORTCUT disabled=",not game.nodes[2].on)
	ui._close_settings()
	game.selected_id = -1
	ui.tool_buttons.phish.grab_focus()
	print("PREMODAL FOCUS ",root.gui_get_focus_owner())
	ui._open_settings()
	await _settle()
	print("MODAL FOCUS ",root.gui_get_focus_owner()," background=",root.gui_get_focus_owner()==ui.tool_buttons.phish)
	var accept = InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	Input.parse_input_event(accept)
	await _settle()
	accept.pressed = false
	Input.parse_input_event(accept)
	await _settle()
	print("MODAL ENTER TOOL ",game.current_tool)
	ui._close_settings()
	game.set_tool("cancel")
	game.nodes[2].parent = game.hub_id
	game.nodes[2].tunnel = "dns"
	game.nodes[2].path = [Vector2i(52, 50), Vector2i(53, 50)]
	game.selected_tunnel = 2
	ui._jump_alert("trace")
	await _settle()
	print("ALERT AFTER TUNNEL selected_id=",game.selected_id," selected_tunnel=",game.selected_tunnel," title=",ui.info_title.text)
	game.selected_tunnel = -1
	game.selected_id = -1
	game.nodes[2].on = true
	game.trace = 95.0
	game.warn_overload = true
	game.rates = {"compute":1.5,"data":2.0,"credits":3.0}
	await _settle()
	print("WARNING RECT ",ui.warn_banner.get_global_rect()," RATE RECT ",ui.netrate_label.get_global_rect()," overlap=",ui.warn_banner.get_global_rect().intersects(ui.netrate_label.get_global_rect()))
	var hub = game.nodes[game.hub_id]
	var rooftop_center = game._center_world(game.hub_id) + Vector2(14,-40)
	var hit_cell = Vector2i(floor(rooftop_center.x/game.TILE),floor(rooftop_center.y/game.TILE))
	print("ROOFTOP HIT ",game._node_at(hit_cell)," hub=",game.hub_id," roofcell=",hit_cell," hubcell=",hub.cell)
	game._lmb_down = true
	game._lmb_moved = false
	var slow_motion = InputEventMouseMotion.new()
	slow_motion.relative = Vector2(2, 0)
	slow_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	for index in 20:
		game._unhandled_input(slow_motion)
	print("SLOW40PX DRAG recognized=",game._lmb_moved)
	quit()
