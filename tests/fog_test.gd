extends SceneTree
## Fog: a foreign host you have not scouted shows a neutral public name and a plain marker — no type, no slots, no
## "?/N" badge, no contents — on the map and in the inspector. A fresh Recon adds its type, slots and contents; when
## it goes stale the host collapses back and says "Recon expired". The AI plays by the same knowledge.
## godot --headless --path . --script tests/fog_test.gd
var g
var P := 1
var checks := 0
var failures := []


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func fresh() -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER


func panel_text() -> String:
	g._refresh_panel()
	var out := []
	var stack: Array = [g.panel_box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).is_visible_in_tree(): out.append((n as Label).text)
		for c in n.get_children(): stack.append(c)
	return "\n".join(out)


func run() -> void:
	names_are_neutral()
	unknown_reveals_nothing()
	recon_reveals_then_expires()
	ai_uses_recon_only()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func names_are_neutral() -> void:
	fresh()
	var bad := []
	for i in g.hosts.size():
		var nm := str(g.hosts[i].name)
		for tp in g.NODE_TYPES:
			var short := str(g.NODE_TYPES[tp].short)
			if nm.begins_with(short + " ") or nm.contains(str(g.NODE_TYPES[tp].name)): bad.append(nm)
	check(bad.is_empty(), "No public host name names its type (%s)" % str(bad.slice(0, 5)))


func unknown_reveals_nothing() -> void:
	fresh()
	var home: int = int(g.rig[P])
	var t := -1
	for nb in g.hosts[home].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: t = int(nb); break
	check(not g._known_host(P, t) and g._public_type(t) == "unknown", "An unscouted neutral host's type is unknown to you")
	check(g._visible_bot_count(t) == "", "No slot badge, not even '?/%d'" % int(g.hosts[t].slots))
	var radii := {}
	for i in g.hosts.size():
		if not g._known_host(P, i): radii[g._r(i)] = true
	check(radii.size() == 1, "Every unknown host is drawn the same size (its slots do not show)")
	g.sel = {}; g._inspect = t
	var txt := panel_text()
	var leaks := []
	for tp in g.NODE_TYPES: if txt.contains(str(g.NODE_TYPES[tp].name)): leaks.append(str(g.NODE_TYPES[tp].name))
	if txt.contains("slot"): leaks.append("slots")
	if txt.contains("storage"): leaks.append("storage")
	check(txt.contains("Unknown host — send Recon to inspect.") and leaks.is_empty(), "The inspector says only: unknown, send Recon (leaks: %s)" % str(leaks))
	var rival_rig: int = int(g.rig[g.botnets[1] if int(g.botnets[0]) == P else g.botnets[0]])
	g._inspect = rival_rig
	txt = panel_text()
	check(txt.contains("main node") and not txt.contains("Server"), "A rival main node is a public landmark, not a known building")


func recon_reveals_then_expires() -> void:
	fresh()
	var home: int = int(g.rig[P])
	var t := -1
	for nb in g.hosts[home].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: t = int(nb); break
	g._mark_scanned(P, t)
	g.sel = {}; g._inspect = t
	var txt := panel_text()
	var tname := str(g.NODE_TYPES[str(g.hosts[t].type)].name)
	check(g._known_host(P, t) and txt.contains(tname) and txt.contains("%d slots" % int(g.hosts[t].slots)), "A fresh Recon adds its type and slots (%s)" % tname)
	check(g._visible_bot_count(t) == "0/%d" % int(g.hosts[t].slots), "...and its slot badge")
	g._t += float(g.CARDS.recon.dur) + 1.0
	txt = panel_text()
	check(not g._known_host(P, t) and txt.contains("Recon expired") and not txt.contains(tname), "When it goes stale the host collapses back: 'Recon expired'")
	check(g._visible_bot_count(t) == "" and g._public_type(t) == "unknown", "...and the map shows the plain marker again")


func ai_uses_recon_only() -> void:   # it presses the host whose producers its Recon saw, not the one it cannot see into
	fresh()
	var ai: int = g.botnets[1] if int(g.botnets[0]) == P else g.botnets[0]
	var near := []
	for nb in g.hosts[int(g.rig[ai])].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: near.append(int(nb))
	if near.size() < 2: check(false, "two hosts next to the AI's main node"); return
	near.sort()
	var a: int = near[0]; var b: int = near[1]
	g._capture(a, P); g._capture(b, P)
	g._set_builds(a, []); g._set_builds(b, ["intel", "cash", "cred"])
	check(g._ai_press_target(ai, "phish") == a, "Unscouted, both look the same to the AI: it takes the first (%d)" % g._ai_press_target(ai, "phish"))
	g._mark_scanned(ai, a)
	check(g._ai_press_target(ai, "phish") == b, "Its Recon of the empty one makes it look elsewhere")
	g.recon[ai] = {}
	g._mark_scanned(ai, b)
	check(g._ai_press_target(ai, "phish") == b, "Its Recon of the busy one makes it the target")
