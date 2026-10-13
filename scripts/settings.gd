extends Node
## Autoload: accessibility & display options, persisted to user://.


# Accessibility was removed as a user setting (2026-10-09). These remain as FIXED internal defaults so
# the (mostly legacy) code that reads them keeps working — they are no longer configurable or persisted.
const reduced_motion := false
const high_contrast := false
const text_scale := 1.0
const cb := false
const dots := false

# The UI typeface (Segoe UI through the project theme) for draw_string calls; Controls get it from the
# theme automatically. Loaded in _ready so it exists before any scene draws.
var font: Font
var font_bold: Font


func _load_fonts() -> void:
	var th = load("res://assets/ui_theme.tres")
	if th is Theme:
		font = th.default_font
		font_bold = th.get_font("bold", "Fonts") if th.has_font("bold", "Fonts") else th.default_font
	if font == null: font = ThemeDB.fallback_font
	if font_bold == null: font_bold = font

# Resource colours. Default = the neon set; CB = Okabe–Ito (deutan/protan-safe).
const RES_DEFAULT := {
	"compute": Color(0.45, 1.0, 0.55), "data": Color(0.4, 0.8, 1.0), "crypto": Color(1.0, 0.55, 0.2),
	"tools": Color(0.8, 0.5, 1.0), "research": Color(0.5, 0.9, 1.0), "credits": Color(1.0, 0.85, 0.25),
	"creds": Color(1.0, 0.45, 0.6), "evade": Color(0.5, 0.9, 0.95),
}
const HEALTH_DEFAULT := {"ok": Color(0.3, 1.0, 0.5), "warn": Color(1.0, 0.9, 0.3), "bad": Color(1.0, 0.3, 0.3)}


func _ready() -> void:
	_load_fonts()


func res_color(res: String) -> Color:
	return RES_DEFAULT.get(res, Color.WHITE)


func health_color(state: String) -> Color:
	return HEALTH_DEFAULT.get(state, Color.WHITE)
