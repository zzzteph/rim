extends SceneTree
## Plays the guided campaign (training) end to end with the redesigned mechanics: capture, build + deliver,
## research + manufacture + capture, steal + protect, then the open chapter. Asserts every chapter advances.
## godot --headless --path . --script tests/campaign_test.gd
var g
var P := 1
var checks := 0
var failures := []
var acted := {}


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func pump(seconds: float) -> void:
	for k in int(seconds / g.SIM_DT): g._process(g.SIM_DT)


func topup() -> void:   # keep resources ample so the test never stalls on affordability (the setup grants usually suffice)
	for res in g.RES: g.bank[P][res] = maxf(float(g.bank[P][res]), 150.0)


func lane_make(recipe: String) -> void:
	if not g._known(P, recipe): return
	g._cmd(["lane_set", 0, recipe]); g._cmd(["lane_make", 0])


func build(host: int, kind: String) -> void:
	var slot: int = g._free_slot(host)
	if slot >= 0: g._cmd(["build", host, slot, kind])


func once(key: String) -> bool:   # true the first time only (for build/research/select-type actions)
	if acted.get(key, false): return false
	acted[key] = true; return true


func play_when_held(recipe: String, target: int) -> void:   # a card step waits until a copy is in hand (auto-supplied or made)
	if target >= 0 and g._held(P, recipe) > 0: g._cmd(["card", recipe, target])


func do_action(ch: int, st: int) -> void:
	var key := "%d:%d" % [ch, st]
	topup()
	match key:
		"0:0": if once(key): g.sel = {g._camp_home: true}; g._inspect = -1
		"0:1": if once(key): lane_make("breach")
		"0:2": play_when_held("breach", g._camp_relay)
		"1:0": if once(key): build(g._camp_relay, "intel")
		"1:1": if once(key): build(g._camp_relay, "bot")
		"1:2": pass   # wait for the courier to arrive
		"2:0": if once(key): g._cmd(["research", "exploit"])
		"2:1": if g._known(P, "exploit") and g._held(P, "exploit") == 0 and g._lane_of(P, "exploit") < 0: lane_make("exploit")
		"2:2": play_when_held("exploit", g._camp_gateway)
		"3:0": play_when_held("phish", g._camp_practice)
		"3:1": play_when_held("response", g._camp_relay)


func run() -> void:
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	root.add_child(g); g.set_process(false)
	P = g.PLAYER
	if FileAccess.file_exists(g._camp_save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(g._camp_save_path()))
	g._start_campaign(0)
	check(g._camp and g._camp_chapter == 0, "The campaign starts at chapter 1 (index 0)")

	var relay_captured := false
	var gateway_captured := false
	var guard := 0
	while g._camp_chapter < g.CAMP_OPEN and guard < 900:
		guard += 1
		if g._camp_hold_left <= 0.0:
			do_action(g._camp_chapter, g._tut_stage)
			g._camp_set_pause(false)
		pump(1.0)
		if g._mine(g._camp_relay): relay_captured = true
		if g._camp_gateway >= 0 and g._mine(g._camp_gateway): gateway_captured = true

	check(relay_captured, "Chapter 1: Credential breach captured the relay")
	check(gateway_captured, "Chapter 3: Known exploit captured the security-2 gateway")
	check(g._camp_chapter >= g.CAMP_OPEN, "The guided chapters complete and reach the open chapter (reached %d/%d)" % [g._camp_chapter + 1, g.CAMP_CHAPTERS])

	print(JSON.stringify({"checks": checks, "failures": failures, "reached_chapter": g._camp_chapter + 1, "guard": guard}))
	g.free(); quit(0 if failures.is_empty() else 1)
