extends SceneTree
## First run: a fresh profile can enter a skirmish without finishing Learn; the main menu is navigation only (Learn,
## Skirmish, Help, Feedback, Exit); Multiplayer is hidden for now while its backend stays; Learn is never a key.
## godot --headless --path . --script tests/onboarding_test.gd
var g
var checks := 0
var failures := []


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func menu_texts() -> Array:
	var out := []
	for c in g.menu_box.get_children():
		if c is Button: out.append("button:" + (c as Button).text)
		elif c is Label: out.append("label:" + (c as Label).text)
	return out


func press(text: String) -> bool:
	for c in g.menu_box.get_children():
		if c is Button and (c as Button).text == text:
			(c as Button).pressed.emit(); return true
	return false


func fresh() -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	root.add_child(g); g.set_process(false)
	g._open_menu(true); g._menu_view = "main"; g._refresh_menu()


func run() -> void:
	var path: String = "user://campaign_harness_%d.json" % OS.get_process_id()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))   # a fresh profile
	fresh()
	var m := menu_texts()
	check(m.has("label:RIM"), "The menu is titled RIM (%s)" % str(m.slice(0, 3)))
	check(m.has("button:Learn") and m.has("button:Skirmish") and m.has("button:Help") and m.has("button:Exit"), "A fresh profile sees Learn and Skirmish at once (%s)" % str(m))
	check(not m.has("button:Multiplayer"), "Multiplayer is not offered in the menu")
	check(m.filter(func(t): return str(t).begins_with("label:")).size() == 1, "The main menu holds its title and navigation buttons only")
	check(not m.any(func(t): return "unlock" in str(t).to_lower()), "Nothing in the menu is locked behind Learn")
	check(press("Skirmish") and g._menu_view == "newgame" and menu_texts().has("label:Skirmish"), "Skirmish opens the match setup")
	g._start_new_game()
	check(not g.menu_open and not g._camp and g.hosts.size() > 0 and int(g.hosts[int(g.rig[g.PLAYER])].owner) == g.PLAYER, "A skirmish starts without Learn")
	fresh()
	check(press("Learn") and g._menu_view == "campaign" and menu_texts().has("button:Start"), "Learn opens its screen with Start on a fresh profile")
	check(g.has_method("_mp_open") and g.has_method("_mp_hash"), "The multiplayer backend stays in the game, only hidden")
	g._camp_write(1, 2)
	fresh()
	check(press("Learn") and menu_texts().any(func(t): return str(t).begins_with("button:Continue — 2.")), "With progress, Learn offers to continue where you were")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)
