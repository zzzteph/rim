extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("Session").seed = 12345
	var m = load("res://scripts/main.gd").new()
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	m.add_child(cam)
	root.add_child(m)
	m.set_process(false)
	m.nodes[2] = {"id": 2, "type": "nest", "cell": Vector2i(10, 10), "size": 2,
		"parent": -1, "tunnel": "", "relay": false, "path": [], "on": true}
	m.next_id = 3
	var p: Dictionary = m._serialize().duplicate(true)
	p.nodes["2"].path = [[1]]
	var f := FileAccess.open(root.get_node("Session").SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(p))
	f.close()
	var returned: bool = m.load_game()
	var res := {"returned": returned, "nodes_after": m.nodes.keys(), "message": m.message}
	var output := FileAccess.open("res://corrupt_save_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(res, "\t"))
	output.close()
	print(JSON.stringify(res))
	quit()
