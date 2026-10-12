extends SceneTree
# Rendered capture: run the real scene for a few seconds with scripted state, save PNGs for review.
var game
var frames := 0
var shots := 0
func _initialize() -> void:
	var scene = load("res://scenes/botnet_proto.tscn").instantiate()
	root.add_child(scene)
	game = scene
func _process(_delta: float) -> bool:
	frames += 1
	if frames == 90 and shots == 0:
		_save("01_initial.png"); shots += 1
		var rp: int = game.rig[1]; var sp: int = game.cell_at(0, 1)
		var tg: int = -1
		for o in game.hosts[rp].links:
			if int(game.hosts[o].owner) == 0: tg = int(o); break
		game.sel = {sp: true, rp: true}; game.sel_target = tg; game._refresh_panel()
	elif frames == 150 and shots == 1:
		_save("02_preview.png"); shots += 1
		game._do_command(); game.hosts[game.cell_at(0, 1)].builds = ["bot", "cash"]; game.rally = game.rig[1]; game._refresh_panel()
	elif frames == 500 and shots == 2:
		_save("03_running.png"); shots += 1
		game.sel = {}; game._enter(game.cell_at(0, 1)); game._refresh_panel()
	elif frames == 660 and shots == 3:
		_save("04_inside.png"); shots += 1
		return true
	return false
func _save(name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("res://captures/" + name)
	print("saved ", name)
