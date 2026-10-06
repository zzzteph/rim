extends SceneTree

func settle() -> void:
	for unused in range(8):
		await process_frame

func rect_data(c: Control) -> Dictionary:
	return {"pos": [c.global_position.x,c.global_position.y], "size":[c.size.x,c.size.y], "min":[c.get_combined_minimum_size().x,c.get_combined_minimum_size().y]}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,720)
	var settings=root.get_node("Settings")
	settings.text_scale=1.0
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await settle()
	main.set_process(false)
	var ui=main.ui
	var out={"scales":[]}
	for scale in [1.0,1.5,2.0]:
		settings.text_scale=scale
		ui._apply_text_scale()
		ui._register_and_scale_fonts()
		ui._on_tab("build")
		ui._set_build_cat("hacks")
		await settle()
		var sc={"scale":scale,"build_scroll":rect_data(ui.build_scroll),"tools":[],"tabs":[]}
		for code in ui.tool_buttons:
			var b=ui.tool_buttons[code]
			var h=b.get_child(0)
			var v=h.get_child(1)
			var name=v.get_child(0)
			var cost=v.get_child(1)
			sc.tools.append({"code":code,"button":rect_data(b),"content":rect_data(h),"name":name.text,"name_rect":rect_data(name),"cost":cost.text,"cost_rect":rect_data(cost),"button_text":b.text,"tooltip":b.tooltip_text,"disabled":b.disabled})
		var tabs=ui.build_cat_row.get_parent().get_child(1)
		for b in tabs.get_children():
			sc.tabs.append({"text":b.text,"rect":rect_data(b),"font":b.get_theme_font_size("font_size")})
		out.scales.append(sc)
	ui.build_scroll.scroll_vertical=200
	await settle()
	var cat_before=ui.build_scroll.scroll_vertical
	ui._set_build_cat("proc")
	await settle()
	out.category_scroll={"before":cat_before,"after":ui.build_scroll.scroll_vertical,"first_processor":rect_data(ui.tool_buttons.fence),"viewport":rect_data(ui.build_scroll)}
	settings.text_scale=1.0
	ui._register_and_scale_fonts()
	ui._on_tab("build")
	ui._on_hover("nest")
	await settle()
	out.hover={"inspector_visible":ui.sel_scroll.is_visible_in_tree(),"info":ui.info_body.text}
	ui._on_tab("tech")
	await settle()
	out.research=[]
	for tid in ui.tech_rows:
		var b=ui.tech_rows[tid].btn
		var tw=b.get_theme_font("font").get_string_size(b.text,HORIZONTAL_ALIGNMENT_LEFT,-1,b.get_theme_font_size("font_size")).x
		out.research.append({"tid":tid,"text":b.text,"tooltip":b.tooltip_text,"disabled":b.disabled,"rect":rect_data(b),"text_width":tw})
	main.contracts=[]
	for i in range(1,4):
		main.contracts.append({"id":i,"client":"Null Collective","accepted":false,"done":false,"desc":"Deliver 40 Intel to C2","reward_cash":100.0,"reward_rp":5.0,"deadline":90.0,"kind":"stock","res":"data","amount":40.0})
	main._contracts_ver+=1
	ui._on_tab("jobs")
	await settle()
	var old_card: PanelContainer
	for ch in ui.jobs_box.get_children():
		if ch is PanelContainer:
			old_card=ch
			break
	var accept=old_card.get_child(0).get_child(3)
	accept.grab_focus()
	out.jobs_before={"focus":str(root.gui_get_focus_owner()),"cards":ui.jobs_box.get_child_count()}
	main.accept_contract(1)
	await settle()
	out.jobs_after={"old_valid":is_instance_valid(old_card),"focus":str(root.gui_get_focus_owner()),"cards":ui.jobs_box.get_child_count()}
	main.resources.data+=40.0
	main.message="baseline"
	main._update_contracts(0.0)
	await settle()
	out.completed={"done":main.contracts[0].done,"message":main.message}
	var f=FileAccess.open("res://panel_probe_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(out,"\t"))
	f.close()
	print("PANEL_PROBE_DONE")
	quit()
