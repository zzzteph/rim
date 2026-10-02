extends Node2D
## Static city backdrop. Painted ONCE (and again only on map regen) and then retained:
## the hundreds of background buildings are re-rasterized by the camera every frame
## WITHOUT re-running the draw loop in GDScript — the big win against per-frame lag.
## The parent (main.gd) does the actual painting into this layer via _paint_city().

func _draw() -> void:
	var p := get_parent()
	if p and p.has_method("_paint_city"):
		p._paint_city(self)
