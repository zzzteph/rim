extends SceneTree
## Plays Learn end to end as ONE session: capture, build + deliver, research + manufacture + capture, steal + protect,
## then the open lesson. Every lesson continues on the same board (no rebuild, no clock reset, no forced wait, what
## you built stays), and leaving then continuing restores the lesson's start with what earlier lessons had you do.
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


func make(recipe: String) -> void:   # + Queue, through the command path
	if not g._known(P, recipe): return
	g._enqueue(g._card_key(recipe, "linked"))


var chooser_builds := 0   # orders placed through the slot chooser, as a player does
var chooser_ok := true       # ...each one opened on an empty slot, listed every building, started its project in THAT slot and closed


func panel_nodes(pred: Callable) -> Array:
	var out := []
	var stack: Array = [g.panel_box]
	while not stack.is_empty():
		var c: Node = stack.pop_front()
		for ch in c.get_children(): stack.append(ch)
		if pred.call(c): out.append(c)
	return out


func click(c: Control) -> void:   # a press and a release on the control, as the GUI delivers them
	for down in [true, false]:
		var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = down
		c._gui_input(ev)


func build(host: int, kind: String) -> void:   # select the host, click an empty slot, pick the building in the chooser
	var slot: int = g._free_slot(host)
	if slot < 0: return
	g.sel = {host: true}; g._inspect = -1; g._refresh_panel()
	var rows := panel_nodes(func(c): return "stop_button" in c and int(c.get("host")) == host and int(c.get("slot")) == slot)
	if rows.is_empty(): chooser_ok = false; return
	click(rows[0])
	var opts := panel_nodes(func(c): return c.has_method("choose"))
	var ok: bool = g._chooser_slot(host) == slot and opts.map(func(o): return str(o.kind)) == g.BUILD_KINDS.keys()
	var pick := opts.filter(func(o): return str(o.kind) == kind)
	if pick.is_empty(): chooser_ok = false; return
	click(pick[0])
	var job: Dictionary = (g.hosts[host].jobs as Dictionary).get(slot, {})
	ok = ok and str(job.get("kind", "")) == kind and g._chooser.is_empty() and panel_nodes(func(c): return c.has_method("choose")).is_empty()
	chooser_ok = chooser_ok and ok
	chooser_builds += 1


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
		"0:1": play_when_held("recon", g._camp_relay)
		"0:2": if once(key): make("breach")
		"0:3": play_when_held("breach", g._camp_relay)
		"1:0":
			if once(key):   # the cue: an empty relay slot, then the Bot station in that slot's chooser
				g.sel = {g._camp_relay: true}; g._inspect = -1; g._refresh_panel()
				var t0: Array = g._camp_ui_targets()
				var free: int = g._free_slot(g._camp_relay)
				var first_cue: bool = t0.size() == 1 and "stop_button" in t0[0] and int(t0[0].slot) == free
				if not t0.is_empty(): click(t0[0])
				var t1: Array = g._camp_ui_targets()
				cue_checks["slot_cue"] = first_cue and t1.size() == 1 and t1[0].has_method("choose") and str(t1[0].kind) == "bot"
				g._close_chooser()
				build(g._camp_relay, "bot")
		"1:1":
			if once(key + "i"): build(g._camp_relay, "intel")
			if once(key + "c"): build(g._camp_relay, "cash")
		"1:2": pass   # its workers carry the surplus home
		"2:0": if once(key): g._cmd(["research", "exploit"])
		"2:1": if g._known(P, "exploit") and g._held(P, "exploit") + g._mq_count(P, "exploit") < 2: make("exploit")
		"2:2": play_when_held("recon", g._camp_gateway)
		"2:3": play_when_held("exploit", g._camp_gateway)
		"2:4":
			if once(key + "c"): build(g._camp_gateway, "cred")
			if once(key + "b"): build(g._camp_gateway, "bot")
		"2:5": pass   # your workers carry the Credentials home
		"3:0": play_when_held("recon", g._camp_practice)
		"3:1": play_when_held("phish", g._camp_practice)
		"3:2": play_when_held("response", g._camp_relay)
		"3:3":
			if once(key):   # what the step shows before you act: no pause, who did it, where to build, the cue
				var spot: int = g._camp_target()
				var said: String = g._camp_fill(str(g._camp_step().a))
				cue_checks["losses_step"] = not g._camp_paused and spot >= 0 and g._mine(spot) and g._free_slot(spot) >= 0 and g.sel.has(spot) \
					and said.contains("NYX (red)") and said.contains(str(g.hosts[spot].name)) and not g._camp_ui_targets().is_empty()
				build(g._camp_home, "bot")


var cue_checks := {}   # what the cues did once an action was accepted


func watch_cues() -> void:
	var key := "%d:%d" % [g._camp_chapter, g._tut_stage]
	if key == "0:3" and g._camp_op_active("breach", g._camp_relay) and not cue_checks.has("launch"):
		g.cards[P]["breach"] = g._held(P, "breach") + 1   # a spare copy in hand must not keep blinking
		g._update_card_banks()
		cue_checks["launch"] = g._camp_ui_targets().is_empty() and str(g._camp_status()).contains("Credential breach")
	if key == "0:3" and g._held(P, "breach") == 0 and g._mq_count(P, "breach") > 0 and not cue_checks.has("making"):
		cue_checks["making"] = g._camp_ui_targets().is_empty() and str(g._camp_status()).contains("underway")
	if key == "1:0" and g._camp_ordered(g._camp_relay, "bot") and g._count_all(g._camp_relay, "bot") == 0 and not cue_checks.has("build"):
		cue_checks["build"] = g._camp_ui_targets().is_empty() and str(g._camp_status()).contains("materials")
	if g._camp_relay >= 0 and g._mine(g._camp_relay) and g._count_all(g._camp_relay, "bot") >= 1 and not cue_checks.has("workers"):
		cue_checks["workers"] = g._worker_ids(P, g._camp_relay).size() == 2
	if key == "3:3" and not cue_checks.has("lost"):
		cue_checks["lost"] = g.events.any(func(e): return str(e.text).contains("Outpost lost") and str(e.text).contains("2 station workers destroyed"))


func run() -> void:
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	root.add_child(g); g.set_process(false)
	P = g.PLAYER
	if FileAccess.file_exists(g._camp_save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(g._camp_save_path()))
	g._start_campaign(0)
	check(g._camp and g._camp_chapter == 0, "Learn starts at lesson 1")
	var board: Array = g.hosts          # the same Array object for the whole session: a rebuild would replace it
	var relay_captured := false
	var gateway_captured := false
	var resets := 0; var waits := 0; var last_t := 0.0
	var relay_builds_at_l2 := []
	var guard := 0
	var shown := {}
	while g._camp_chapter < g.CAMP_OPEN and guard < 900:
		guard += 1
		var before := "%d:%d" % [g._camp_chapter, g._tut_stage]
		do_action(g._camp_chapter, g._tut_stage)   # no helper unpauses: only your commands end a lesson's pause
		watch_cues()
		pump(1.0)
		if not is_same(g.hosts, board) or g._t + 0.001 < last_t: resets += 1
		last_t = g._t
		if g._camp_step_done(g._camp_chapter, g._tut_stage) and g._camp_chapter < g.CAMP_OPEN:   # a done step still on screen
			waits += 1
		var now := "%d:%d" % [g._camp_chapter, g._tut_stage]
		shown[now] = true
		if now != before and g._camp_chapter == 2 and relay_builds_at_l2.is_empty(): relay_builds_at_l2 = (g.hosts[g._camp_relay].builds as Array).duplicate()
		if g._mine(g._camp_relay): relay_captured = true
		if g._camp_gateway >= 0 and g._mine(g._camp_gateway): gateway_captured = true
	check(relay_captured, "Lesson 1: Credential breach captured the relay")
	check(gateway_captured, "Lesson 3: Known exploit captured the gateway")
	check(g._camp_chapter >= g.CAMP_OPEN, "Every guided lesson completes and the open lesson begins (reached %d/%d)" % [g._camp_chapter + 1, g.CAMP_CHAPTERS])
	check(resets == 0, "One session: the board and the clock are never rebuilt between lessons (%d resets)" % resets)
	check(waits == 0, "No forced waits: a done step hands over at once (%d waits)" % waits)
	check(relay_builds_at_l2.has("intel") and relay_builds_at_l2.has("bot"), "What you built in lesson 2 is still there in lesson 3 (%s)" % str(relay_builds_at_l2))
	check(not g._ai_paused, "The open lesson wakes the rival")
	check(bool(cue_checks.get("making", false)), "A queued copy stops the + Queue cue while it is made, and says so")
	check(bool(cue_checks.get("launch", false)), "An accepted launch stops the card cue at once, even with a spare copy ready; the status follows it")
	check(bool(cue_checks.get("build", false)), "An accepted building order stops the recipe cue during delivery; the status shows its materials")
	check(bool(cue_checks.get("workers", false)), "The relay's finished Bot station has exactly 2 workers")
	check(bool(cue_checks.get("lost", false)), "The lost Outpost is explained: 2 station workers destroyed")
	check(bool(cue_checks.get("losses_step", false)), "The loss step does not pause, says who took it (NYX, red), names a host of yours with a free slot, selects it and cues the Bot station")
	check(bool(cue_checks.get("slot_cue", false)), "A build step cues an empty slot of its host first, then the building in that slot's chooser")
	check(chooser_ok and chooser_builds >= 5, "Every lesson building is ordered through the slot chooser: it opens on an empty slot, lists every building, starts the project in that slot and closes (%d orders)" % chooser_builds)
	var t0: float = g._t
	pump(2.0)
	check(g._camp_chapter == g.CAMP_OPEN and not g._camp_paused and not g.paused and g._t > t0 + 1.5, "Free play runs without Space (%.1f s passed)" % (g._t - t0))
	check(g.tut_panel.visible, "Free play shows its banner at first")
	pump(9.0)
	check(g.tut_panel.visible and g.tut_panel.size.y <= g.CAMP_STRIP_H + 0.5 and g._map_rect().position.y < 170.0 and str(g.tut_box.get_child(0).text).contains("Win: hold"),
		"...and after 10 s of play shrinks it to one line with the goal, giving the map most of its room back (map top %.0f)" % g._map_rect().position.y)
	var space := InputEventKey.new(); space.keycode = KEY_SPACE; space.pressed = true
	g._input(space)
	t0 = g._t; pump(2.0)
	check(g.paused and absf(g._t - t0) < 0.001, "Your own pause still works in Learn (Space)")
	g._input(space)
	t0 = g._t; pump(1.0)
	check(not g.paused and g._t > t0, "...and Space resumes it")
	var no_why := true
	for ch in g.CAMP_CHAPTERS:
		for st in g._camp_steps(ch): no_why = no_why and not (st as Dictionary).has("w")
	check(no_why, "No lesson step carries a WHY block")
	g._show_tut()
	var banner := ""
	for c in g.tut_box.get_children():
		if c is RichTextLabel: banner += (c as RichTextLabel).get_parsed_text()
		elif c is Container:
			for d in c.get_children(): if d is Label: banner += (d as Label).text + " "
	check(not banner.contains("Why") and not banner.contains("complete") and not banner.contains("starts in"), "The banner shows no WHY, no completion screen and no countdown (%s)" % banner.substr(0, 80))
	# leave part-way and continue later
	var save: Dictionary = g._camp_load()
	g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	root.add_child(g); g.set_process(false)
	g._camp_write(2, 1)
	g._camp_resume_or_start()
	check(g._camp and g._camp_chapter == 2 and g._tut_stage == 0, "Continue resumes at the saved lesson's start (lesson 3)")
	check(g._mine(g._camp_relay) and g._count_all(g._camp_relay, "intel") > 0 and g._count_all(g._camp_relay, "bot") > 0, "...with what lessons 1-2 had you do: the relay is yours with its harvester and station")
	check(int(g.hosts[g._camp_gateway].owner) == g.RIVAL, "...and lesson 3's own situation: a rival holds the gateway")
	check(not g._camp_paused or bool(g._camp_step().get("pause", false)), "The pause shows only on a step that waits for you")
	g._camp_paused = true; g._show_tut()
	var paused_txt := ""
	for c in g.tut_box.get_children():
		if c is Container:
			for d in c.get_children():
				if d is Label: paused_txt += (d as Label).text + " "
				if d is TextureRect: paused_txt += "[icon]"
	check(paused_txt.contains("[icon]") and paused_txt.contains("Paused until you act"), "A paused step shows a pause icon and plain words (%s)" % paused_txt)
	if FileAccess.file_exists(g._camp_save_path()): DirAccess.remove_absolute(ProjectSettings.globalize_path(g._camp_save_path()))
	print(JSON.stringify({"checks": checks, "failures": failures, "reached_chapter": 5, "guard": guard, "saved": save}))
	g.free(); quit(0 if failures.is_empty() else 1)
