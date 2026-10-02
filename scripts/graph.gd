extends Control
## Cash-over-time sparkline for the Stats tab. Reads main._hist_cash (1 Hz samples).

var main: Node2D

func _process(_d: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.03, 0.05, 0.85), true)
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.2, 1.0, 0.9, 0.3), false, 1.0)
	if main == null:
		return
	var goal: float = float(main.GOAL_CREDITS)
	# goal line (dashed-ish) at the top
	draw_line(Vector2(0, 2), Vector2(sz.x, 2), Color(1.0, 0.85, 0.3, 0.35), 1.0)
	var hist: Array = main._hist_cash
	if hist.size() < 2:
		var l := ThemeDB.fallback_font
		draw_string(l, Vector2(8, sz.y * 0.5), "Cash over time — collecting…", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.7, 0.8))
		return
	var pts := PackedVector2Array()
	for i in hist.size():
		var x := sz.x * float(i) / float(max(1, hist.size() - 1))
		var y := sz.y * (1.0 - clampf(float(hist[i]) / maxf(goal, 1.0), 0.0, 1.0))
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color(1.0, 0.85, 0.3), 2.0)
	var fnt := ThemeDB.fallback_font
	draw_string(fnt, Vector2(6, 16), "Cash → %d goal" % int(goal), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.85, 0.95))
