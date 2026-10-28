extends SceneTree
## Writes every constant of scripts/botnet_cfg/*.gd (and a few engine values) to docs/rim_constants.json,
## the data behind docs/DESIGN.md. Run from the project root:
##   godot --headless --path . --script res://docs/tools/dump_constants.gd
func _initialize() -> void: run.call_deferred()


func clean(v):   # JSON-friendly: colours become hex strings, vectors become arrays
	match typeof(v):
		TYPE_COLOR: return "#" + (v as Color).to_html(false)
		TYPE_VECTOR2I, TYPE_VECTOR2: return [v.x, v.y]
		TYPE_DICTIONARY:
			var o := {}
			for k in v: o[str(k)] = clean(v[k])
			return o
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var a := []
			for x in v: a.append(clean(x))
			return a
		TYPE_OBJECT: return null
	return v


func run() -> void:
	var out := {}
	for f in DirAccess.get_files_at("res://scripts/botnet_cfg"):
		if not f.ends_with(".gd"): continue
		var m: Dictionary = load("res://scripts/botnet_cfg/" + f).get_script_constant_map()
		var d := {}
		for k in m:
			var c = clean(m[k])
			if c != null: d[k] = c
		out[f.trim_suffix(".gd")] = d
	var pm: Dictionary = load("res://scripts/botnet_proto.gd").get_script_constant_map()
	out["engine"] = {"SIM_DT": pm.SIM_DT, "SIZE_PRESETS": clean(pm.SIZE_PRESETS), "GAME_VERSION": pm.GAME_VERSION, "MAP_CELL": pm.MAP_CELL,
		"SOCKET_TRIGGER": clean(pm.SOCKET_TRIGGER), "CONVERT_ORDER": clean(pm.CONVERT_ORDER), "MP_SIZES": clean(pm.MP_SIZES)}
	var fa := FileAccess.open("res://docs/rim_constants.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "  ", false))
	fa.close()
	print("wrote docs/rim_constants.json: ", out.keys())
	quit(0)
