extends Control
## Cash-over-time sparkline for the Stats tab. Reads main._hist_cash (1 Hz samples).

var main: Node2D
# RIM-083: only repaint when something that affects the sparkline actually changed — a new
# history sample, a resize, a text-scale change, or the graph (re)appearing. A paused, unchanged
# Stats panel then costs zero graph redraws instead of one every frame.
var _last_n := -1
var _last_last := INF
var _last_size := Vector2.ZERO
var _last_ts := -1.0
var _was_visible := false

func _process(_d: float) -> void:
	if not visible:
		_was_visible = false
		return
	if main == null:
		return
	var hist: Array = main._hist_cash
	var n: int = hist.size()
	var last: float = float(hist[n - 1]) if n > 0 else INF
	if n != _last_n or last != _last_last or size != _last_size or Settings.text_scale != _last_ts or not _was_visible:
		_last_n = n
		_last_last = last
		_last_size = size
		_last_ts = Settings.text_scale
		_was_visible = true
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
		draw_string(l, Vector2(8, sz.y * 0.5), "Cash over time — collecting…", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(14 * Settings.text_scale)), Color(0.6, 0.7, 0.8))
		return
	var pts := PackedVector2Array()
	for i in hist.size():
		var x := sz.x * float(i) / float(max(1, hist.size() - 1))
		var y := sz.y * (1.0 - clampf(float(hist[i]) / maxf(goal, 1.0), 0.0, 1.0))
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color(1.0, 0.85, 0.3), 2.0)
	var fnt := ThemeDB.fallback_font
	draw_string(fnt, Vector2(6, 16), "Cash → %d goal" % int(goal), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(13 * Settings.text_scale)), Color(0.7, 0.85, 0.95))
