extends SceneTree
## First run (Milestone A, brief §17.1): a fresh profile can enter a skirmish or Multiplayer without finishing the
## campaign; Learn is recommended with "Skip for now"; finishing or skipping Learn is guidance, never a key.
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
	var path: String = load("res://scripts/botnet_proto.gd").CAMP_SAVE_HARNESS
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))   # a fresh profile
	fresh()
	var m := menu_texts()
	check(m.has("label:RIM"), "The menu is titled RIM (%s)" % str(m.slice(0, 3)))
	check(m.has("button:▶ Learn (recommended)") and m.has("button:Skirmish") and m.has("button:Multiplayer"), "A fresh profile sees Learn (recommended), Skirmish and Multiplayer at once")
	check(m.has("button:Skip for now"), "Learn can be skipped for now")
	check(not m.any(func(t): return "unlock" in str(t).to_lower()), "Nothing in the menu is locked behind the campaign")
	check(press("Skirmish") and g._menu_view == "newgame" and menu_texts().has("label:Skirmish"), "Skirmish opens the match setup")
	g._start_new_game()
	check(not g.menu_open and not g._camp and g.hosts.size() > 0 and int(g.hosts[int(g.rig[g.PLAYER])].owner) == g.PLAYER, "A skirmish starts without the campaign")
	fresh()
	check(press("Multiplayer") and g._menu_view in ["mp", "lobby"], "Multiplayer opens the lobby browser without the campaign (%s)" % g._menu_view)
	if g.net != null and g.net.has_method("close"): g.net.close()
	fresh()
	check(press("Skip for now") and menu_texts().has("button:Learn") and not menu_texts().has("button:Skip for now"), "Skip for now drops the recommendation and keeps Learn in the menu")
	check(bool(g._camp_load().get("learn_skipped", false)) and not bool(g._camp_load().get("completed", false)), "Skipping is stored as guidance; the campaign is not marked complete")
	fresh()
	check(menu_texts().has("button:Learn") and not menu_texts().has("button:Skip for now"), "The choice survives a restart")
	check(press("Learn") and g._menu_view == "campaign", "Learn still opens the guided chapters after skipping")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)
