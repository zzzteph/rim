extends Control
## K&M-style minimap: whole map at a glance; click or drag to move the camera.
## The static district grid is baked once to a texture; the minimap only redraws when
## the camera or the set of nodes actually changes (not every frame) to save CPU.

var main: Node2D
var _grid_tex: ImageTexture
var _last_cam := Vector2(INF, INF)
var _last_zoom := -1.0
var _last_nodes := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp district blocks when scaled


func _gui_input(event: InputEvent) -> void:
	if main == null:
		return
	var press: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if press or drag:
		var f: Vector2 = event.position / size
		main.camera.position = Vector2(f.x * main.MAP_W * main.TILE, f.y * main.MAP_H * main.TILE)
		accept_event()


func _process(_delta: float) -> void:
	if main == null:
		return
	# only repaint when the view or the node set changed — idle frames cost nothing
	var nc: int = main.nodes.size()
	if main.camera.position != _last_cam or main.camera.zoom.x != _last_zoom or nc != _last_nodes:
		_last_cam = main.camera.position
		_last_zoom = main.camera.zoom.x
		_last_nodes = nc
		queue_redraw()


func _bake_grid() -> void:
	var img := Image.create(main.GW, main.GH, false, Image.FORMAT_RGBA8)
	for gy in main.GH:
		for gx in main.GW:
			var t: String = main.regions[main.region_grid[gy * main.GW + gx]].type
			var c: Color = main.ZONE_COLOR.get(t, Color(0.3, 0.3, 0.35))
			c.a = 0.5
			img.set_pixel(gx, gy, c)
	_grid_tex = ImageTexture.create_from_image(img)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 1.0), true)
	if main == null:
		return
	if _grid_tex == null and not main.regions.is_empty():
		_bake_grid()
	if _grid_tex != null:
		draw_texture_rect(_grid_tex, Rect2(Vector2.ZERO, size), false)
	var sx: float = size.x / (main.MAP_W * main.TILE)
	var sy: float = size.y / (main.MAP_H * main.TILE)
	for id in main.nodes:
		var n = main.nodes[id]
		var c: Color = main.COLORS[n.type]
		var p := Vector2((n.cell.x + n.size * 0.5) * main.TILE * sx, (n.cell.y + n.size * 0.5) * main.TILE * sy)
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), c, true)
	# camera view rectangle
	var vp: Vector2 = main.get_viewport_rect().size / main.camera.zoom.x
	var tl: Vector2 = main.camera.position - vp * 0.5
	draw_rect(Rect2(tl.x * sx, tl.y * sy, vp.x * sx, vp.y * sy), Color(1, 1, 1, 0.7), false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 1.0, 0.9, 0.6), false, 1.0)
