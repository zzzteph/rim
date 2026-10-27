extends Control
## Illustrated Help examples, using the same symbols as the live board and cards.

var game
var page := "research"

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

func _bar(rect: Rect2, value: float, color := GREEN) -> void:
	draw_rect(rect, LINE)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * value, rect.size.y)), color)

func _draw() -> void:
	if game == null: return
	match page:
		"research": _p_research()
		"deliver": _p_deliver()
		"produce": _p_produce()
		"build": _p_build()
		"attack": _p_attack()
		"goal": _p_goal()


func _lead(lines: Array) -> void:
	for k in lines.size():
		_text(str(lines[k]), Rect2(16, 14 + k * 22, 588, 22), 14, TEXT, false)


# Every page: two lead lines, an illustration tile (y 70..250) drawn round CY, and a caption that wraps below it.
const CY := 132.0
const ILLUSTRATION := Rect2(0, 70, 620, 180)
const CAPTION := Rect2(16, 202, 588, 40)


func _caption(value: String) -> void:   # wraps to a second line instead of shrinking and clipping
	draw_multiline_string(get_theme_default_font(), CAPTION.position + Vector2(0, 12), value,
		HORIZONTAL_ALIGNMENT_LEFT, CAPTION.size.x, 12, 2, DIM)


func _p_research() -> void:
	_lead(["Learn a blueprint once to unlock its recipe.", "Manufacture copies, then launch a ready card."])
	_tile(ILLUSTRATION)
	_text("LOCKED  →  RESEARCH  →  KNOWN  →  LANE  →  READY  →  LAUNCH", Rect2(16, CY - 12, 588, 24), 15, BLUE, false)
	_caption("Research unlocks a recipe — it gives no free card. Manufacturing pays once; launching spends the copy.")


func _p_deliver() -> void:
	_lead(["A resource made outside your main node is not spendable yet.", "One Bot carries one unit home and is consumed on arrival."])
	_tile(ILLUSTRATION)
	_host(Vector2(120, CY), GREEN, "producer", "server")
	_arrow(Vector2(176, CY), Vector2(470, CY), GOLD)
	_host(Vector2(520, CY), GREEN, "main node", "server")
	_caption("4 delivered/s needs 4 courier Bots/s. New Bots deliver themselves; the main node makes 1 of each resource locally.")


func _p_produce() -> void:
	_lead(["Harvesters make Intel. A Bot farm turns 1 Intel into 2 Bots.", "Miners and labs convert; the output still needs a courier."])
	_tile(ILLUSTRATION)
	var makes := {"intel": "Intel", "bot": "Bots", "cash": "Crypto", "cred": "Creds", "lab": "Research"}
	var x := 70.0
	for kind in makes:
		_kind(kind, Vector2(x, CY - 8))
		_text(str(makes[kind]), Rect2(x - 60, CY + 24, 120, 20), 12, game.BUILD_KINDS[kind].col)
		x += 117.5
	_caption("No input stops production. No courier or route stops dispatch. A full local buffer stops production.")


func _p_build() -> void:
	_lead(["One research slot and three manufacturing lanes.", "Repeat makes more copies when resources and slots allow."])
	_tile(ILLUSTRATION)
	for k in 3:
		draw_rect(Rect2(40 + k * 190, CY - 42, 170, 84), INK)
		draw_rect(Rect2(40 + k * 190, CY - 42, 170, 84), BLUE, false, 1.5)
		_text("LANE %d" % (k + 1), Rect2(40 + k * 190, CY - 11, 170, 22), 14, TEXT)
	_caption("A paused lane leaves the others running. Each producing copy reserves one of 12 ready slots.")


func _p_attack() -> void:
	_lead(["Phishing diverts new output. Packet siphon redirects cargo in transit.", "Vault raid takes stored Crypto. Capture cards have a security limit."])
	_tile(ILLUSTRATION)
	_host(Vector2(110, CY), RED, "producer", "server")
	_arrow(Vector2(166, CY), Vector2(254, CY), GOLD, true)
	_host(Vector2(310, CY), RED, "in transit", "pc")
	_arrow(Vector2(366, CY), Vector2(454, CY), GOLD, true)
	_host(Vector2(510, CY), RED, "main node", "server")
	_caption("Stolen resources help only when they reach your main node. Patch, Response, Filter and Cover defend.")


func _p_goal() -> void:
	_lead(["Hold at least %d%% of all hosts for %d seconds," % [int(game.HOLD_FRACTION * 100.0), int(game.HOLD_SECS)], "or be the last network with its main node."])
	_tile(ILLUSTRATION)
	_bar(Rect2(40, CY - 10, 540, 20), 0.55, GREEN)
	var mark := 40.0 + 540.0 * float(game.HOLD_FRACTION)   # the majority line the bar has to cross
	draw_line(Vector2(mark, CY - 18), Vector2(mark, CY + 18), GOLD, 2)
	_text("%d%%" % int(game.HOLD_FRACTION * 100.0), Rect2(mark - 40, CY + 22, 80, 20), 12, GOLD)
	_caption("Lose your main node and you are eliminated. Watch the objective bar for the exact host count.")
