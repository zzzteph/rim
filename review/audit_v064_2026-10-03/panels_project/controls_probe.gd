extends SceneTree

func settle() -> void:
	for unused in range(8):
		await process_frame

func box(c: Control) -> Dictionary:
	return {"position":[c.global_position.x,c.global_position.y],"size":[c.size.x,c.size.y],"bottom":c.global_position.y+c.size.y,"right":c.global_position.x+c.size.x}

func focus() -> Dictionary:
	var c=root.gui_get_focus_owner()
	return {"text":c.text if c is Button else "", "path":str(c.get_path()) if is_instance_valid(c) else "null"}

func tab_key(shift:=false) -> void:
	var e=InputEventKey.new()
	e.keycode=KEY_TAB
	e.physical_keycode=KEY_TAB
	e.pressed=true
	e.shift_pressed=shift
	root.push_input(e)
	await settle()
	e=e.duplicate()
	e.pressed=false
	root.push_input(e)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,720)
	var settings=root.get_node("Settings")
	settings.text_scale=2.0
	settings.high_contrast=true
	settings.cb=true
	var out={"menu":{},"modal_sizes":[],"focus_steps":[]}
	var menu=load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await settle()
	var menus=[]
	for c in menu.find_children("","Label",true,false)+menu.find_children("","Button",true,false):
		menus.append({"text":c.text,"font":c.get_theme_font_size("font_size"),"rect":box(c)})
	out.menu={"text_scale":settings.text_scale,"controls":menus,"initial_focus":focus()}
	menu.queue_free()
	await settle()
	settings.text_scale=1.0
	settings.high_contrast=false
	settings.cb=false
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await settle()
	main.set_process(false)
	var ui=main.ui
	ui._on_tab("menu")
	await settle()
	var origin_button=ui.menu_box.get_child(1)
	origin_button.grab_focus()
	ui._open_settings()
	await settle()
	out.focus_steps.append(focus())
	for unused in range(8):
		await tab_key()
		out.focus_steps.append(focus())
	var enter=InputEventKey.new()
	enter.keycode=KEY_ENTER
	enter.pressed=true
	root.push_input(enter)
	await settle()
	enter=enter.duplicate()
	enter.pressed=false
	root.push_input(enter)
	await settle()
	out.background_activation={"tab":ui.tab,"settings_visible":ui.settings_overlay.visible,"focus":focus()}
	ui._close_settings()
	await settle()
	out.settings_closed_focus=focus()
	main.pause_menu=true
	main.paused=true
	await settle()
	ui._open_settings()
	await settle()
	ui._close_settings()
	await settle()
	out.nested_settings_closed_focus=focus()
	main.pause_menu=false
	await settle()
	for vp in [Vector2i(1280,720),Vector2i(1024,600),Vector2i(1366,768)]:
		root.size=vp
		for scale in [1.0,2.0]:
			settings.text_scale=scale
			ui._register_and_scale_fonts()
			ui._open_settings()
			await settle()
			var sp=ui.settings_overlay.get_child(1)
			var sv=sp.get_child(0)
			var entry={"viewport":[vp.x,vp.y],"logical_viewport":[ui.size.x,ui.size.y],"scale":scale,"settings_panel":box(sp),"settings_close":box(sv.get_child(sv.get_child_count()-1))}
			ui._close_settings()
			main.pause_menu=true
			main.paused=true
			await settle()
			entry.pause_panel=box(ui.pause_overlay.get_child(1))
			entry.pause_quit=box(ui.pause_overlay.find_children("","Button",true,false)[5])
			main.pause_menu=false
			main.won=true
			main.resources.credits=1000.0
			main._run_time=7200.0
			main._peak_cash_rate=123.45
			main._packets_delivered=123456
			main._max_trace=99.9
			ui.win_dismissed=false
			await settle()
			entry.win_panel=box(ui.win_overlay.get_child(1))
			entry.win_last_button=box(ui.win_overlay.find_children("","Button",true,false)[1])
			entry.win_text=ui.win_label.text
			out.modal_sizes.append(entry)
			main.won=false
			await settle()
	root.size=Vector2i(1280,720)
	settings.text_scale=1.0
	ui._register_and_scale_fonts()
	ui._on_tab("build")
	var n={"id":100,"type":"nest","cell":main.nodes[main.hub_id].cell+Vector2i(6,0),"size":2,"parent":main.hub_id,"tunnel":"dns","relay":false,"on":true,"cap_rate":1.0,"boost_t":0.0,"lane":0,"path":[]}
	main.nodes[100]=n
	main.nodes[101]=n.duplicate(true)
	main.nodes[101].id=101
	main.nodes[101].cell=n.cell+Vector2i(6,0)
	main.nodes[101].parent=100
	main._connected[100]=true
	main._connected[101]=true
	main._edge[100]={"frac":1.0,"offered":1.0,"delivered":1.0,"cap":3.0,"over":false,"dist_loss":0.0,"over_loss":0.0,"trace_hot":false}
	main._edge[101]=main._edge[100].duplicate(true)
	main.selected_id=100
	main.selected_tunnel=-1
	main.message=""
	await settle()
	out.inspector={"normal_body":ui.info_body.text,"output_100_plus_disabled":ui.rate_up.disabled,"overclock_text":ui.oc_btn.text,"overclock_tooltip":ui.oc_btn.tooltip_text}
	main.nodes[100].cap_rate=0.0
	await settle()
	out.inspector.output_0_minus_disabled=ui.rate_down.disabled
	main.nodes[100].cap_rate=1.0
	main.overclock_selected()
	await settle()
	out.inspector.boost_time=main.nodes[100].boost_t
	out.inspector.boost_body=ui.info_body.text
	main.nodes[100].on=false
	await settle()
	out.inspector.disabled_body=ui.info_body.text
	main.selected_id=-1
	main.selected_tunnel=101
	await settle()
	out.inspector.tunnel_body=ui.info_body.text
	main.selected_id=100
	main.selected_tunnel=-1
	main.nodes[100].on=true
	settings.text_scale=2.0
	ui._register_and_scale_fonts()
	main.message=""
	await settle()
	out.inspector.scaled={"scroll":box(ui.sel_scroll),"body":box(ui.info_body),"dismantle":box(ui.remove_btn),"power":box(ui.power_btn),"overclock":box(ui.oc_btn),"row":box(ui.rate_down.get_parent())}
	var f=FileAccess.open("res://controls_probe_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(out,"\t"))
	f.close()
	print("CONTROLS_PROBE_DONE")
	quit()
