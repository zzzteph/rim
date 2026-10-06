class_name Glyphs
## Shared vector icons: structure glyphs (world + build list) and resource
## pictograms (packets + legend). Everything draws through one place so the map,
## the menu and the HUD all show the same symbols.

const RES_COLOR := {
	"compute": Color(0.45, 1.0, 0.55),  # Cycles — green
	"data": Color(0.4, 0.8, 1.0),       # Intel — blue
	"credits": Color(1.0, 0.85, 0.25),  # Cash — yellow
	"crypto": Color(1.0, 0.55, 0.2),    # Crypto — orange
	"tools": Color(0.8, 0.5, 1.0),      # Tools — purple
	"research": Color(0.5, 0.9, 1.0),   # Research — cyan
}


# Draw a structure glyph centred at c, sized by `size` (nominal radius in px).
static func draw(ci: CanvasItem, kind: String, c: Vector2, col: Color, size: float) -> void:
	var u := size / 9.0
	var g := col
	g.a = 0.98
	match kind:
		"hub":  # data core: concentric rings with rotating ticks
			ci.draw_arc(c, 9 * u, 0, TAU, 32, g, 1.5 * u)
			ci.draw_arc(c, 4.5 * u, 0, TAU, 24, g, 1.5 * u)
			for i in 4:
				var a := float(i) * TAU / 4.0 + 0.4
				ci.draw_line(c + Vector2.from_angle(a) * 10 * u, c + Vector2.from_angle(a) * 14 * u, g, 1.5 * u)
		"nest_cam":  # CCTV camera: body + lens + mount
			ci.draw_rect(Rect2(c + Vector2(-8, -4) * u, Vector2(13, 8) * u), g, false, 1.5 * u)
			ci.draw_circle(c + Vector2(-1.5, 0) * u, 2.6 * u, g)
			ci.draw_line(c + Vector2(5, 0) * u, c + Vector2(9, -3) * u, g, 1.5 * u)
		"nest_router":  # router: box + two antennas + link dots
			ci.draw_rect(Rect2(c + Vector2(-8, 1) * u, Vector2(16, 6) * u), g, false, 1.5 * u)
			ci.draw_line(c + Vector2(-4, 1) * u, c + Vector2(-6, -7) * u, g, 1.5 * u)
			ci.draw_line(c + Vector2(4, 1) * u, c + Vector2(6, -7) * u, g, 1.5 * u)
			ci.draw_circle(c + Vector2(-2, 4) * u, 1.0 * u, g)
			ci.draw_circle(c + Vector2(2, 4) * u, 1.0 * u, g)
		"nest_fridge":  # smart fridge: tall body + handle + split
			ci.draw_rect(Rect2(c + Vector2(-5, -8) * u, Vector2(10, 16) * u), g, false, 1.5 * u)
			ci.draw_line(c + Vector2(-5, -1) * u, c + Vector2(5, -1) * u, g, 1.2 * u)
			ci.draw_line(c + Vector2(3, -5) * u, c + Vector2(3, -2) * u, g, 1.5 * u)
		"nest_dvr":  # set-top / DVR: wide slab + LED row
			ci.draw_rect(Rect2(c + Vector2(-9, -4) * u, Vector2(18, 8) * u), g, false, 1.5 * u)
			for i in 3:
				ci.draw_circle(c + Vector2(-5 + i * 3, 0) * u, 1.0 * u, g)
		"package":  # npm crate: box with cross-straps
			ci.draw_rect(Rect2(c + Vector2(-7, -7) * u, Vector2(14, 14) * u), g, false, 1.6 * u)
			ci.draw_line(c + Vector2(-7, -2.5) * u, c + Vector2(7, -2.5) * u, g, 1.0 * u)
			ci.draw_line(c + Vector2(-2.5, -7) * u, c + Vector2(-2.5, 7) * u, g, 1.0 * u)
		"botfarm":  # server rack: three stacked units with status LEDs
			for i in 3:
				var y := (-6 + i * 5) * u
				ci.draw_rect(Rect2(c + Vector2(-8, y - 1.6 * u), Vector2(16 * u, 3.4 * u)), g, false, 1.2 * u)
				ci.draw_circle(c + Vector2(5.5 * u, y), 0.9 * u, g)
		"phish":  # envelope / mailbox: rect with a flap
			ci.draw_rect(Rect2(c + Vector2(-9, -6) * u, Vector2(18, 12) * u), g, false, 1.6 * u)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-9, -6) * u, c + Vector2(0, 1) * u, c + Vector2(9, -6) * u]), g, 1.4 * u)
		"scraper":  # leaked list / credential dump: stacked rows with a tick
			for i in 4:
				var yy := (-6 + i * 4) * u
				ci.draw_line(c + Vector2(-8, yy), c + Vector2(4, yy), g, 1.3 * u)
			ci.draw_circle(c + Vector2(7, -6) * u, 1.2 * u, g)
		"salami":  # payment card: rect + magstripe + chip
			ci.draw_rect(Rect2(c + Vector2(-9, -6) * u, Vector2(18, 12) * u), g, false, 1.6 * u)
			ci.draw_line(c + Vector2(-9, -2) * u, c + Vector2(9, -2) * u, g, 2.2 * u)
			ci.draw_rect(Rect2(c + Vector2(-6, 1) * u, Vector2(4, 3) * u), g, false, 1.0 * u)
		"fence":  # market: diamond stall + coin
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -8) * u, c + Vector2(8, 0) * u, c + Vector2(0, 8) * u, c + Vector2(-8, 0) * u, c + Vector2(0, -8) * u]), g, 1.6 * u)
			ci.draw_circle(c, 2.2 * u, g)
		"relay":  # onion routing: concentric rings
			ci.draw_arc(c, 8 * u, 0, TAU, 28, g, 1.3 * u)
			ci.draw_arc(c, 5 * u, 0, TAU, 20, g, 1.3 * u)
			ci.draw_circle(c, 1.8 * u, g)
		"forge":  # zero-day lab: a cog
			ci.draw_arc(c, 6 * u, 0, TAU, 20, g, 1.6 * u)
			for i in 8:
				var a := float(i) / 8.0 * TAU
				ci.draw_line(c + Vector2.from_angle(a) * 6 * u, c + Vector2.from_angle(a) * 9 * u, g, 1.6 * u)
			ci.draw_circle(c, 2 * u, g)
		"mixer":  # tumbler: ring with orbiting blobs
			ci.draw_arc(c, 8 * u, 0, TAU, 24, g, 1.4 * u)
			for i in 3:
				var a := float(i) / 3.0 * TAU
				ci.draw_circle(c + Vector2.from_angle(a) * 5 * u, 1.8 * u, g)
		"lab":  # research: a flask
			ci.draw_polyline(PackedVector2Array([c + Vector2(-2.5, -7) * u, c + Vector2(-2.5, -1) * u, c + Vector2(-7, 7) * u, c + Vector2(7, 7) * u, c + Vector2(2.5, -1) * u, c + Vector2(2.5, -7) * u]), g, 1.6 * u)
			ci.draw_line(c + Vector2(-4, -7) * u, c + Vector2(4, -7) * u, g, 1.6 * u)
			ci.draw_line(c + Vector2(-4.5, 3) * u, c + Vector2(4.5, 3) * u, g, 1.4 * u)
		"dns":  # thin, quiet tunnel
			ci.draw_line(c + Vector2(-9, 0) * u, c + Vector2(9, 0) * u, g, 1.6 * u)
			ci.draw_circle(c, 2.0 * u, g)
		"vpn":  # encrypted: a padlock on the line
			ci.draw_line(c + Vector2(-9, 0) * u, c + Vector2(9, 0) * u, g, 1.8 * u)
			ci.draw_rect(Rect2(c + Vector2(-3.5, -1) * u, Vector2(7, 6) * u), g, false, 1.4 * u)
			ci.draw_arc(c + Vector2(0, -1) * u, 2.4 * u, PI, TAU, 10, g, 1.4 * u)
		"tcp":  # fat, loud tunnel
			ci.draw_line(c + Vector2(-9, 0) * u, c + Vector2(9, 0) * u, g, 3.6 * u)
			ci.draw_circle(c, 2.8 * u, g)
		"http":  # multiplexed firehose: double fat line
			ci.draw_line(c + Vector2(-9, -2.5) * u, c + Vector2(9, -2.5) * u, g, 2.6 * u)
			ci.draw_line(c + Vector2(-9, 2.5) * u, c + Vector2(9, 2.5) * u, g, 2.6 * u)
		"proxy":  # onion route: a zigzag of hops
			ci.draw_polyline(PackedVector2Array([c + Vector2(-9, 2) * u, c + Vector2(-3, -4) * u, c + Vector2(3, 2) * u, c + Vector2(9, -4) * u]), g, 1.8 * u)
		_:
			ci.draw_arc(c, 7 * u, 0, TAU, 20, g, 1.4 * u)


# A small 2.5D neon prism with the structure's glyph on its lit top face — the
# "3D" icon used in the build list, matching the structures on the map.
static func draw_building_icon(ci: CanvasItem, kind: String, c: Vector2, col: Color, s: float) -> void:
	var tw := s * 1.5
	var depth := s * 0.85
	var topc := c + Vector2(0, -depth * 0.4)
	var top := Rect2(topc - Vector2(tw, tw * 0.62), Vector2(tw * 2.0, tw * 1.24))
	var front := Rect2(top.position + Vector2(0, top.size.y), Vector2(top.size.x, depth))
	ci.draw_rect(front, Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.96), true)
	ci.draw_rect(top, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.96), true)
	var e := col
	e.a = 0.95
	ci.draw_rect(front, e, false, 1.3)
	ci.draw_rect(top, e, false, 1.3)
	draw(ci, kind, topc, col, s * 0.78)


# Map an internal node type to its glyph kind (handles IoT device variety & relay).
static func kind_for(type: String, id: int, is_relay: bool) -> String:
	if is_relay:
		return "relay"
	if type == "nest":
		return ["nest_cam", "nest_router", "nest_fridge", "nest_dvr"][id % 4]
	return type


# Resource pictogram: bolt = Cycles, eye = Intel, coin = Cash.
static func draw_resource(ci: CanvasItem, res: String, c: Vector2, size: float) -> void:
	var col: Color = Settings.res_color(res)
	var s := size
	match res:
		"compute":  # lightning bolt — power
			var p := PackedVector2Array([
				Vector2(-0.28, -1.0), Vector2(0.18, -1.0), Vector2(-0.04, -0.12),
				Vector2(0.34, -0.12), Vector2(-0.24, 1.0), Vector2(0.02, 0.06), Vector2(-0.4, 0.06)])
			var poly := PackedVector2Array()
			for v in p:
				poly.append(c + v * s * 1.15)
			ci.draw_colored_polygon(poly, col)
		"data":  # eye — intel / surveillance
			var up := PackedVector2Array()
			var dn := PackedVector2Array()
			var steps := 10
			for i in steps + 1:
				var t := -1.0 + 2.0 * float(i) / float(steps)
				var x := t * s
				var y := (1.0 - t * t) * s * 0.62
				up.append(c + Vector2(x, -y))
				dn.append(c + Vector2(x, y))
			ci.draw_polyline(up, col, maxf(1.0, s * 0.18))
			ci.draw_polyline(dn, col, maxf(1.0, s * 0.18))
			ci.draw_circle(c, s * 0.34, col)
		"credits":  # coin — cash
			ci.draw_circle(c, s, col)
			var dark := Color(0, 0, 0, 0.45)
			ci.draw_arc(c, s * 0.62, 0, TAU, 20, dark, maxf(1.0, s * 0.16))
			ci.draw_line(c + Vector2(0, -s * 0.55), c + Vector2(0, s * 0.55), dark, maxf(1.0, s * 0.16))
		"crypto":  # hexagon — blockchain token
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(float(i) / 6.0 * TAU - PI / 2.0) * s)
			ci.draw_colored_polygon(hex, col)
			var dk := Color(0, 0, 0, 0.4)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.4), c + Vector2(-s * 0.3, s * 0.4), dk, maxf(1.0, s * 0.16))
			ci.draw_line(c + Vector2(s * 0.1, -s * 0.4), c + Vector2(s * 0.1, s * 0.4), dk, maxf(1.0, s * 0.16))
		"tools":  # key — exploit
			ci.draw_arc(c + Vector2(-s * 0.4, 0), s * 0.5, 0, TAU, 14, col, maxf(1.2, s * 0.22))
			ci.draw_line(c + Vector2(0, 0), c + Vector2(s, 0), col, maxf(1.2, s * 0.22))
			ci.draw_line(c + Vector2(s * 0.7, 0), c + Vector2(s * 0.7, s * 0.5), col, maxf(1.2, s * 0.22))
			ci.draw_line(c + Vector2(s, 0), c + Vector2(s, s * 0.4), col, maxf(1.2, s * 0.22))
		"research":  # atom — know-how
			ci.draw_circle(c, s * 0.3, col)
			var w := maxf(1.0, s * 0.14)
			for k in 3:
				var ang := float(k) * PI / 3.0
				_draw_ellipse(ci, c, s, s * 0.42, ang, col, w)
		_:
			ci.draw_circle(c, s, col)


static func _draw_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, ang: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0 * TAU
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry).rotated(ang))
	ci.draw_polyline(pts, col, w)
