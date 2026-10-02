extends Node
## Autoload: accessibility & display options, persisted to user://.

const PATH := "res://review_settings.json"

var reduced_motion := false   # stop ambient animation (twinkle, matrix rain, tendrils, motes…)
var high_contrast := false    # brighter structures, thicker lines, dimmer city
var text_scale := 1.0         # 1.0 / 1.25 / 1.5
var cb := false               # colour-blind-safe palette (Okabe–Ito)
var dots := false             # packets as plain dots instead of Matrix code

# Resource colours. Default = the neon set; CB = Okabe–Ito (deutan/protan-safe).
const RES_DEFAULT := {
	"compute": Color(0.45, 1.0, 0.55), "data": Color(0.4, 0.8, 1.0), "crypto": Color(1.0, 0.55, 0.2),
	"tools": Color(0.8, 0.5, 1.0), "research": Color(0.5, 0.9, 1.0), "credits": Color(1.0, 0.85, 0.25),
}
const RES_CB := {
	"compute": Color(0.941, 0.894, 0.259), "data": Color(0.337, 0.705, 0.914), "crypto": Color(0.902, 0.624, 0.0),
	"tools": Color(0.8, 0.475, 0.655), "research": Color(0.0, 0.447, 0.698), "credits": Color(0.0, 0.619, 0.451),
}
const HEALTH_DEFAULT := {"ok": Color(0.3, 1.0, 0.5), "warn": Color(1.0, 0.9, 0.3), "bad": Color(1.0, 0.3, 0.3)}
const HEALTH_CB := {"ok": Color(0.337, 0.705, 0.914), "warn": Color(0.941, 0.894, 0.259), "bad": Color(0.835, 0.369, 0.0)}


func _ready() -> void:
	load_settings()


func res_color(res: String) -> Color:
	return (RES_CB if cb else RES_DEFAULT).get(res, Color.WHITE)


func health_color(state: String) -> Color:
	return (HEALTH_CB if cb else HEALTH_DEFAULT).get(state, Color.WHITE)


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"rm": reduced_motion, "hc": high_contrast, "ts": text_scale, "cb": cb, "dots": dots}))
		f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) == TYPE_DICTIONARY:
		reduced_motion = bool(d.get("rm", false))
		high_contrast = bool(d.get("hc", false))
		text_scale = float(d.get("ts", 1.0))
		cb = bool(d.get("cb", false))
		dots = bool(d.get("dots", false))

