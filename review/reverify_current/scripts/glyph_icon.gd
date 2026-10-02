extends Control
## A tiny Control that paints one shared glyph — a structure kind or a resource
## pictogram — so the build list and legend match the map exactly.

var kind := ""   # structure glyph (Glyphs.draw)
var res := ""    # resource pictogram (Glyphs.draw_resource) — takes priority if set
var col := Color.WHITE
var gsize := 10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	if res != "":
		Glyphs.draw_resource(self, res, c, gsize)
	elif kind in ["dns", "vpn", "tcp", "http", "proxy"]:
		Glyphs.draw(self, kind, c, col, gsize)  # tunnels stay flat
	elif kind != "":
		Glyphs.draw_building_icon(self, kind, c, col, gsize)  # structures get a 3D block
