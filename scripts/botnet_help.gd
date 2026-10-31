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
	if game == null or not LEADS.has(page): return
	_lead(lead_lines(page))
	_tile(ILLUSTRATION)
	match page:
		"research": _p_research()
		"deliver": _p_deliver()
		"produce": _p_produce()
		"build": _p_build()
		"attack": _p_attack()
		"goal": _p_goal()
	_caption(str(CAPTIONS[page]))


# Each page's words, kept as data so tests/text_fit_test.gd measures exactly what is drawn:
# every lead line fits on one line with room to spare, every caption fits in two lines.
const LEADS := {
	"research": ["Research unlocks a blueprint; manufacture makes a card copy.", "Launching uses that copy. The bar under the top bar shows research."],
	"deliver": ["Each Bot station provides two reusable workers.", "Each carries one unit per leg and returns for another job."],
	"produce": ["Installations use the materials they need here first.", "Workers take the surplus to your main node."],
	"build": ["Queue up to four copies, including the one being made.", "They are made in order, one at a time; finished copies go to Ready."],
	"attack": ["Phishing diverts new output. Packet siphon grabs cargo in transit.", "Send Recon to inspect a host; unscouted attacks work half the time."],
	"goal": ["Hold at least {pct}% of all hosts for {secs} seconds,", "or be the last network with its main node."],
}
const CAPTIONS := {
	"research": "Only materials at your main node fund cards and research. Research gives no free card; a copy pays when it starts.",
	"deliver": "Missing inputs are fetched from your main node; its workers serve hosts with no station. Losing a host destroys its stations' workers.",
	"produce": "Workers bring what a host needs automatically. Refill supplies asks once for one cycle of inputs; clicking again adds nothing. Full storage (10) stops it.",
	"build": "A building's materials must reach its site before its 10 s of work start. The 12-card Ready inventory is separate from the queue.",
	"attack": "Stolen resources help only when your workers bring them home. Defence cards travel too; a Firewall holds 3 that fire on their own.",
	"goal": "Lose your main node and you are eliminated. The top bar always shows the hosts needed, yours, and who holds the majority.",
}
const LEAD_FS := 14
const LEAD_PITCH := 24.0   # 14 px lines 24 px apart: 7 px clear between them, 14 px above the illustration
const LEAD_WIDTH := 588.0
const CAPTION_FS := 12


func lead_lines(p: String) -> Array:
	var out := []
	for line in LEADS[p]:
		out.append(str(line).format({"pct": int(game.HOLD_FRACTION * 100.0), "secs": int(game.HOLD_SECS)}))
	return out


func _lead(lines: Array) -> void:   # one line each at full size: the test keeps every lead short enough
	for k in lines.size():
		_text(str(lines[k]), Rect2(16, 14 + k * LEAD_PITCH, LEAD_WIDTH, 22), LEAD_FS, TEXT, false)


# Every page: two lead lines, an illustration tile (y 70..250) drawn round CY, and a caption that wraps below it.
const CY := 132.0
const ILLUSTRATION := Rect2(0, 70, 620, 180)
const CAPTION := Rect2(16, 202, 588, 40)


func _caption(value: String) -> void:   # wraps to a second line instead of shrinking and clipping
	draw_multiline_string(get_theme_default_font(), CAPTION.position + Vector2(0, CAPTION_FS), value,
		HORIZONTAL_ALIGNMENT_LEFT, CAPTION.size.x, CAPTION_FS, 2, DIM)


func _p_research() -> void:
	_text("LOCKED  →  RESEARCH  →  KNOWN  →  QUEUE  →  READY  →  LAUNCH", Rect2(16, CY - 12, 588, 24), 15, BLUE, false)


func _p_deliver() -> void:
	_host(Vector2(120, CY), GREEN, "producer", "server")
	_arrow(Vector2(176, CY), Vector2(470, CY), GOLD)
	_host(Vector2(520, CY), GREEN, "main node", "server")


func _p_produce() -> void:
	var makes := {"intel": "Intel", "bot": "2 workers", "cash": "Crypto", "cred": "Creds", "lab": "Research"}
	var x := 70.0
	for kind in makes:
		_kind(kind, Vector2(x, CY - 8))
		_text(str(makes[kind]), Rect2(x - 60, CY + 24, 120, 20), 12, game.BUILD_KINDS[kind].col)
		x += 117.5


func _p_build() -> void:   # the queue's four places (the first one making) and the separate Ready inventory
	var names := ["1 MAKING", "2", "3", "4"]
	for k in 4:
		var r := Rect2(24 + k * 110, CY - 36, 100, 72)
		draw_rect(r, INK)
		draw_rect(r, GOLD if k == 0 else BLUE, false, 2.0 if k == 0 else 1.5)
		_text(str(names[k]), Rect2(r.position.x, CY - 11, r.size.x, 22), 14, TEXT)
	_arrow(Vector2(462, CY), Vector2(500, CY), GOLD)
	var ready := Rect2(506, CY - 36, 98, 72)
	draw_rect(ready, INK); draw_rect(ready, GREEN, false, 2.0)
	_text("READY", Rect2(ready.position.x, CY - 11, ready.size.x, 22), 14, GREEN)


func _p_attack() -> void:
	_host(Vector2(110, CY), RED, "producer", "server")
	_arrow(Vector2(166, CY), Vector2(254, CY), GOLD, true)
	_host(Vector2(310, CY), RED, "in transit", "pc")
	_arrow(Vector2(366, CY), Vector2(454, CY), GOLD, true)
	_host(Vector2(510, CY), RED, "main node", "server")


func _p_goal() -> void:
	_bar(Rect2(40, CY - 10, 540, 20), 0.55, GREEN)
	var mark := 40.0 + 540.0 * float(game.HOLD_FRACTION)   # the majority line the bar has to cross
	draw_line(Vector2(mark, CY - 18), Vector2(mark, CY + 18), GOLD, 2)
	_text("%d%%" % int(game.HOLD_FRACTION * 100.0), Rect2(mark - 40, CY + 22, 80, 20), 12, GOLD)
