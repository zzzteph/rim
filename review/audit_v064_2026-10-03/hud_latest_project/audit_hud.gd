extends SceneTree

var results := {}

func _initialize() -> void:
	call_deferred("run")

func rect(c: Control) -> Dictionary:
	var r := c.get_global_rect()
	return {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}

func text_width(l: Label) -> float:
	return l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x

func clear_messages(u) -> void:
	u._last_msg = ""
	u._msg_t = 0.0
	u._msg_queue.clear()
	u._msg_history.clear()
	u._msg_cur = ""
	u._msg_sev = 0

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("Session").seed = 12345
	root.get_node("Settings").text_scale = 1.0
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	m.set_process(false)
	var u = m.get_node("UILayer/UI")
	u.set_process(false)
	await process_frame
	await process_frame
	var legend: HBoxContainer = u._legend_labels.compute.get_parent().get_parent()
	m.rates = {"compute": -99.9, "data": 1000.0, "credits": 150.0, "crypto": 12.0, "tools": 0.6, "research": 0.5}
	u._process(0.0)
	await process_frame
	results.rates_legend = {"rates": u.netrate_label.text, "rate_rect": rect(u.netrate_label), "legend_rect": rect(legend), "intersects": u.netrate_label.get_global_rect().intersects(legend.get_global_rect())}

	m.nodes[2] = {"id": 2, "type": "nest", "cell": Vector2i(10, 10), "size": 2, "parent": m.hub_id,
		"tunnel": "dns", "path": [Vector2i(12,10)], "on": true, "coverage": 5}
	m._connected = {m.hub_id: true, 2: true}
	m._edge = {2: {"over": true, "frac": 0.5, "cap": 3.0, "offered": 10.0, "delivered": 5.0}}
	m.warn_overload = true
	m.sweep = {"path": [2,m.hub_id], "step": 0, "warn": 6.0, "t": 0.0}
	u._alert_acc = 1.0
	u._process(0.0)
	await process_frame
	var banner: Rect2 = u.warn_banner.get_global_rect()
	var bw: float = text_width(u.warn_banner)
	var actual_banner := Rect2(Vector2(banner.get_center().x - bw/2.0, banner.position.y), Vector2(bw,banner.size.y))
	results.warn_alert = {"banner_rect": rect(u.warn_banner), "banner_text_width": bw, "alert_rect": rect(u.alert_btns.overload), "text_intersects": actual_banner.intersects(u.alert_btns.overload.get_global_rect())}
	u._jump_alert("overload")
	results.overload_jump = {"selected_id": m.selected_id, "selected_tunnel": m.selected_tunnel}

	m.nodes[2].quarantine = 5.0
	m._connected.erase(2)
	u._alert_acc = 1.0
	u._process(0.0)
	results.quarantine_alert = u.alert_btns.offline.text
	u._jump_alert("offline")
	var first_jump: int = m.selected_id
	m.nodes[3] = m.nodes[2].duplicate(true)
	m.nodes[3].id = 3
	m.nodes[3].cell = Vector2i(15,15)
	u._jump_alert("offline")
	results.repeated_alert_jump = {"first": first_jump, "second": m.selected_id}

	m.selected_id = -1
	m.selected_tunnel = -1
	m.sweep = {}
	m.warn_overload = false
	m._edge = {}
	u.tab = "stats"
	m.resources.research = 77.0
	clear_messages(u)
	m.message = "Can't place: Not enough resources."
	m.hint = "Hover hint"
	u._process(0.0)
	u._process(3.7)
	m.message = "Can't place: Not enough resources."
	u._process(0.0)
	results.repeated_same_message = {"timer": u._msg_t, "visible_status": u.status_label.text, "last_message": u._last_msg}
	results.stats_research = {"stored_research": m.resources.research, "stats_text": u.stats_label.text}

	root.get_node("Settings").text_scale = 2.0
	u._register_and_scale_fonts()
	m.message = ""
	m.hint = ""
	u._process(3.1)
	await process_frame
	await process_frame
	results.scaled_hud = {"top_rect": rect(u.top_label), "top_text_width": text_width(u.top_label), "top_text": u.top_label.text, "legend_rect": rect(legend), "viewport_w": root.size.x,
		"status_rect": rect(u.status_label), "stats_scroll_rect": rect(u.stats_scroll), "status": u.status_label.text}

	root.get_node("Settings").text_scale = 1.0
	u._register_and_scale_fonts()
	m.paused = true
	clear_messages(u)
	m.message = "Paused."
	m.hint = "Hover hint"
	u._process(0.0)
	u._process(3.1)
	results.planning_pause = {"paused": m.paused, "pause_overlay_visible": u.pause_overlay.visible, "top_text": u.top_label.text, "status": u.status_label.text}

	clear_messages(u)
	for i in 10:
		m.message = "Routine selection %d" % i
		u._process(0.0)
	m.message = "ICE reached your C2 — BLACKOUT"
	u._process(0.0)
	results.warning_fifo = {"displayed": u._msg_cur, "pending_count": u._msg_queue.size(), "last_queued": u._msg_queue.back(), "warning_wait_lower_bound_s": 10 * 2.2}
	for i in 100:
		m.message = "Routine selection extra %d" % i
		u._process(0.0)
	results.queue_bound = {"pending_count": u._msg_queue.size(), "history_count": u._msg_history.size()}

	clear_messages(u)
	m.message = "Contract paid in discarded timeline"
	u._process(0.0)
	m.message = "Contract expired in discarded timeline"
	u._process(0.0)
	var serialized: Dictionary = m._serialize()
	m._apply_save(serialized)
	m.message = "Game loaded."
	u._process(0.0)
	results.load_message_timeline = {"displayed": u._msg_cur, "pending": u._msg_queue.duplicate(true), "history": u._msg_history.duplicate()}

	clear_messages(u)
	m.message = "First same-frame result"
	m.message = "Second same-frame result"
	u._process(0.0)
	results.same_frame_history = u._msg_history.duplicate()
	var out := FileAccess.open("res://hud_results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(results, "\t"))
	out.close()
	print(JSON.stringify(results))
	quit()
