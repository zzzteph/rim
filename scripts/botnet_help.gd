extends Control
## Illustrated Help examples, using the same symbols as the live board and cards.

var game
var page := "network"

const INK := Color(0.05, 0.07, 0.11)
const TILE := Color(0.075, 0.10, 0.15)
const LINE := Color(0.19, 0.27, 0.36)
const TEXT := Color(0.88, 0.92, 1.0)
const DIM := Color(0.60, 0.68, 0.80)
const GREEN := Color(0.35, 0.90, 0.58)
const BLUE := Color(0.40, 0.85, 1.0)
const RED := Color(1.0, 0.55, 0.5)
const GOLD := Color(1.0, 0.85, 0.3)

func _init() -> void:
	custom_minimum_size = Vector2(620, 380)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _text(value: String, rect: Rect2, font_size := 13, color := TEXT, centered := true) -> void:
	var font := get_theme_default_font()
	var fitted := font_size
	while fitted > 10 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > rect.size.x:
		fitted -= 1
	draw_string(font, rect.position + Vector2(0, fitted), value,
		HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, fitted, color)

func _tile(rect: Rect2) -> void:
	draw_style_box(_style(), rect)

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TILE
	style.border_color = LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

func _arrow(from: Vector2, to: Vector2, color := BLUE, dashed := false) -> void:
	if dashed: draw_dashed_line(from, to, color, 2, 7)
	else: draw_line(from, to, color, 2, true)
	var back := (from - to).normalized()
	var side := Vector2(-back.y, back.x)
	draw_line(to, to + back * 9 + side * 5, color, 2, true)
	draw_line(to, to + back * 9 - side * 5, color, 2, true)

func _host(at: Vector2, color: Color, label: String, kind := "pc", extent := 52.0) -> void:
	draw_rect(Rect2(at - Vector2.ONE * (extent * 0.65), Vector2.ONE * extent * 1.3), INK)
	draw_rect(Rect2(at - Vector2.ONE * (extent * 0.65), Vector2.ONE * extent * 1.3), color, false, 1.5)
	game._draw_type_glyph(self, kind, at, extent, color, INK)
	_text(label, Rect2(at.x - 75, at.y + extent * 0.73, 150, 22), 12, color)

func _kind(kind: String, at: Vector2, extent := 42.0) -> void:
	game._draw_kind_icon(self, kind, at, extent, game.BUILD_KINDS[kind].col, get_theme_default_font())

func _cursor(at: Vector2) -> void:
	var points := PackedVector2Array([at, at + Vector2(3, 22), at + Vector2(9, 16), at + Vector2(16, 24), at + Vector2(21, 20), at + Vector2(14, 12), at + Vector2(23, 9)])
	draw_colored_polygon(points, TEXT)
	points.append(at)
	draw_polyline(points, INK, 1.5, true)

func _bar(rect: Rect2, value: float, color := GREEN) -> void:
	draw_rect(rect, LINE)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * value, rect.size.y)), color)

func _draw() -> void:
	if game == null: return
	match page:
		"network": _network()
		"build": _build()
		"resources": _resources()
		"cards": _cards()
		"protection": _protection()
		"goal": _goal()

func _network() -> void:
	_tile(Rect2(0, 0, 620, 174))
	_text("1  DRAG TO CONNECT", Rect2(16, 12, 588, 22), 15, BLUE, false)
	_host(Vector2(130, 85), GREEN, "YOUR BUILDING")
	_host(Vector2(490, 85), RED, "TARGET", "server")
	_arrow(Vector2(184, 85), Vector2(436, 85), BLUE, true)
	_cursor(Vector2(322, 72))
	_text("A wire is ready. Scan the target, then Attack.", Rect2(20, 145, 580, 22), 12, DIM)
	_tile(Rect2(0, 186, 304, 194))
	_tile(Rect2(316, 186, 304, 194))
	_text("2  SCAN", Rect2(16, 198, 272, 22), 15, BLUE, false)
	_text("3  ATTACK", Rect2(332, 198, 272, 22), 15, RED, false)
	draw_arc(Vector2(72, 273), 23, 0, TAU, 32, BLUE, 3, true)
	draw_line(Vector2(89, 290), Vector2(106, 307), BLUE, 4, true)
	_arrow(Vector2(116, 273), Vector2(176, 273))
	_host(Vector2(226, 273), DIM, "?  ->  20 bots", "server", 42)
	for index in 3:
		draw_circle(Vector2(356 + index * 23, 271), 5, GREEN)
	_arrow(Vector2(426, 273), Vector2(494, 273), RED)
	_host(Vector2(548, 273), GREEN, "0 = captured", "server", 42)
	_text("Reveal defenders + installed buildings", Rect2(12, 345, 280, 25), 11, DIM)
	_text("Each launched bot costs 1 Intel", Rect2(328, 345, 280, 25), 12, DIM)

func _build() -> void:
	_tile(Rect2(0, 0, 620, 188))
	_text("1  SELECT YOUR BUILDING, THEN DROP INTO A SLOT", Rect2(16, 12, 588, 22), 14, BLUE, false)
	draw_rect(Rect2(40, 54, 112, 91), INK)
	draw_rect(Rect2(40, 54, 112, 91), BLUE, false, 1.5)
	_kind("intel", Vector2(96, 94), 48)
	_text("BUILD CARD", Rect2(40, 151, 112, 20), 11, DIM)
	_arrow(Vector2(174, 98), Vector2(270, 98))
	_cursor(Vector2(219, 87))
	for index in 3:
		var rect := Rect2(296 + index * 94, 58, 82, 82)
		draw_rect(rect, INK)
		draw_rect(rect, BLUE if index == 1 else LINE, false, 1.5)
		if index == 1:
			_kind("intel", rect.get_center(), 38)
			_bar(Rect2(rect.position.x + 6, 129, 70, 5), 0.5, BLUE)
		else: _text("+", Rect2(rect.position + Vector2(0, 23), Vector2(82, 40)), 28, DIM)
	_text("10-50 Intel, paid over %ds of funded work" % int(game.BUILD_TIME), Rect2(285, 151, 294, 22), 12, TEXT)
	_tile(Rect2(0, 200, 304, 180))
	_tile(Rect2(316, 200, 304, 180))
	_text("BOT FARM", Rect2(16, 212, 272, 22), 14, GREEN, false)
	_text("INTEL HARVESTER", Rect2(332, 212, 272, 22), 14, BLUE, false)
	_kind("bot", Vector2(73, 281), 58)
	_arrow(Vector2(124, 281), Vector2(174, 281), GREEN)
	_text("+%.0f bot/s" % game.PROD_RATE, Rect2(184, 255, 104, 23), 14, GREEN)
	_text("%.0f cap/farm" % game.NODE_CAP, Rect2(173, 282, 120, 23), 12, DIM)
	_kind("intel", Vector2(389, 281), 58)
	_arrow(Vector2(440, 281), Vector2(490, 281))
	_text("+%.0f Intel/s" % game.INTEL_PER_BUILD, Rect2(494, 255, 112, 23), 13, BLUE)
	_text("+%.0f limit" % game.INTEL_CAP_PER_BUILD, Rect2(494, 282, 112, 23), 12, DIM)
	_text("PC example: replenish defenders", Rect2(12, 344, 280, 22), 11, DIM)
	_text("PC example: fuel your network", Rect2(328, 344, 280, 22), 11, DIM)

func _resource_row(y: float, input: String, output: String, producer: String, input_name: String, output_name: String) -> void:
	_tile(Rect2(0, y, 620, 108))
	_kind(input, Vector2(77, y + 43), 42)
	_text("1 " + input_name, Rect2(14, y + 75, 126, 22), 13, game.BUILD_KINDS[input].col)
	_arrow(Vector2(132, y + 43), Vector2(229, y + 43), game.BUILD_KINDS[input].col)
	draw_rect(Rect2(244, y + 20, 132, 49), INK)
	_text(producer, Rect2(249, y + 36, 122, 22), 13, TEXT)
	_arrow(Vector2(391, y + 43), Vector2(488, y + 43), game.BUILD_KINDS[output].col)
	_kind(output, Vector2(543, y + 43), 42)
	_text("1 " + output_name, Rect2(477, y + 75, 132, 22), 13, game.BUILD_KINDS[output].col)

func _resources() -> void:
	_resource_row(0, "intel", "cred", "HARVESTER", "Intel", "Credential")
	_resource_row(117, "intel", "cash", "MINER", "Intel", "Crypto")
	_resource_row(234, "cash", "lab", "LAB", "Crypto", "Research")
	_text("No input = no output. Crypto packets travel home before spending.", Rect2(0, 347, 620, 17), 11, DIM)
	_text("Click an installed producer to pause / resume.", Rect2(0, 365, 620, 15), 11, BLUE)

func _example_card(rect: Rect2, owned: int, progress: float) -> void:
	var col := GREEN if owned > 0 else DIM
	draw_rect(rect, INK)
	draw_rect(rect, col, false, 1.5)
	_text("PHISHING", Rect2(rect.position + Vector2(10, 9), Vector2(rect.size.x - 20, 22)), 14, col, false)
	_text("x%d" % owned, Rect2(rect.position + Vector2(rect.size.x - 51, 7), Vector2(39, 24)), 19, col)
	if owned > 0:
		game._draw_card_glyph(self, "phishworm", rect.position + Vector2(rect.size.x * 0.5, 83), 79, col, get_theme_default_font())
	else:
		# Draw an empty copy in gray; the colored production card remains a held copy.
		var at := rect.position + Vector2(rect.size.x * 0.5, 83)
		draw_rect(Rect2(at - Vector2(24, 17), Vector2(48, 34)), DIM, false, 2)
		draw_line(at - Vector2(24, 17), at, DIM, 2, true)
		draw_line(at + Vector2(24, -17), at, DIM, 2, true)
	_text("RESEARCHING  %d%%" % int(progress * 100), Rect2(rect.position + Vector2(10, 131), Vector2(rect.size.x - 20, 22)), 12, col)
	_bar(Rect2(rect.position + Vector2(12, 156), Vector2(rect.size.x - 24, 7)), progress, col)

func _cards() -> void:
	_example_card(Rect2(0, 0, 294, 176), 0, 0.55)
	_example_card(Rect2(326, 0, 294, 176), 1, 0.35)
	_text("FIRST COPY: gray until ready", Rect2(0, 184, 294, 22), 12, DIM)
	_text("ONE OWNED: another is building", Rect2(326, 184, 294, 22), 12, GREEN)
	_tile(Rect2(0, 218, 620, 162))
	_text("CLICK: RESEARCH / PAUSE / RESUME    x: CANCEL", Rect2(16, 230, 588, 22), 13, BLUE, false)
	game._draw_card_glyph(self, "phishworm", Vector2(85, 303), 70, GREEN, get_theme_default_font())
	_text("x1", Rect2(115, 288, 42, 24), 19, GREEN)
	_arrow(Vector2(175, 303), Vector2(447, 303), GREEN)
	_cursor(Vector2(284, 289))
	_host(Vector2(514, 301), RED, "REACHABLE TARGET", "server", 42)
	_text("DRAG a held copy to play it · ATTACK / DEFENCE or C pulls the deck up", Rect2(20, 344, 580, 20), 12, DIM)

func _goal() -> void:
	_tile(Rect2(0, 0, 620, 176))
	_text("WIN: HOLD AT LEAST 51%% FOR %d SECONDS" % int(game.HOLD_SECS), Rect2(16, 12, 588, 22), 15, GREEN, false)
	for index in 7:
		_host(Vector2(45 + index * 58, 82), GREEN if index < 4 else DIM, "", "pc", 29)
	_arrow(Vector2(439, 82), Vector2(478, 82), GREEN)
	draw_arc(Vector2(545, 81), 33, -PI * 0.5, PI * 1.5, 48, GREEN, 3, true)
	_text("%ds" % int(game.HOLD_SECS), Rect2(511, 66, 68, 27), 23, GREEN)
	_text("Example: keep 4 of 7 buildings for %d seconds" % int(game.HOLD_SECS), Rect2(16, 135, 588, 24), 13, DIM)
	_tile(Rect2(0, 188, 620, 112))
	_host(Vector2(71, 235), GREEN, "YOUR RIG", "server", 37)
	_text("PROTECT", Rect2(126, 222, 107, 25), 14, GREEN)
	_arrow(Vector2(259, 236), Vector2(375, 236), RED)
	_host(Vector2(433, 235), RED, "RIVAL RIG", "server", 37)
	_text("CAPTURE", Rect2(478, 215, 128, 22), 14, RED)
	_text("all rivals to win", Rect2(472, 239, 140, 22), 11, DIM)
	_tile(Rect2(0, 312, 620, 68))
	_text("DRAG MAP", Rect2(12, 322, 144, 22), 13, BLUE)
	_text("pan", Rect2(12, 346, 144, 20), 12, DIM)
	_text("WHEEL", Rect2(162, 322, 144, 22), 13, BLUE)
	_text("zoom", Rect2(162, 346, 144, 20), 12, DIM)
	_text("SPACE", Rect2(312, 322, 144, 22), 13, BLUE)
	_text("pause", Rect2(312, 346, 144, 20), 12, DIM)
	_text("0 / ESC", Rect2(462, 322, 144, 22), 13, BLUE)
	_text("center / menu", Rect2(462, 346, 144, 20), 12, DIM)

func _protection() -> void:
	var cards := ["cdn", "patch", "response", "sca"]
	var examples := ["DDOS -> CLEAR", "0DAY + SUPPLY -> BLOCK", "PHISHING -> REMOVE", "SUPPLY -> BLOCK"]
	var durations := ["Otherwise: production x2 / 10s", "30 seconds per host", "Production returns to you", "60 seconds per host"]
	for index in 4:
		var x := float(index % 2) * 316; var y := float(index / 2) * 140
		_tile(Rect2(x, y, 304, 130))
		var card: Dictionary = game.CARDS[cards[index]]
		var color: Color = game.FAMILY_COL[card.fam]
		game._draw_card_glyph(self, cards[index], Vector2(x + 40, y + 46), 50, color, get_theme_default_font())
		_text(card.name, Rect2(x + 75, y + 21, 213, 25), 16, color, false)
		_text(examples[index], Rect2(x + 12, y + 78, 280, 20), 12, TEXT)
		_text(durations[index], Rect2(x + 12, y + 103, 280, 20), 11, DIM)
	for index in 5:
		var x := 67.0 + index * 120
		_host(Vector2(x, 320), GREEN, "", "pc", 28)
		if index < 4: _arrow(Vector2(x + 23, 320), Vector2(x + 96, 320), GREEN)
	_text("DEFENCE tab: up to 5 own hosts · costs 2x the matching ATTACK", Rect2(0, 359, 620, 20), 11, game.BANK_COL["defense"])
