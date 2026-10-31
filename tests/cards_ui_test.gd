extends SceneTree
## The cards area: a compact strip (the four-place manufacturing queue, ready cards at a fixed size, the cards button),
## a drawer that keeps ready cards apart from recipes, a Research button beside Economy and Menu, an unmistakable
## blueprint selection, and the active research's name, progress and paused / stalled state.
## godot --headless --path . --script tests/cards_ui_test.gd
var g
var P := 1
var checks := 0
var failures := []


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func frames(n := 2) -> void:
	for k in n: await process_frame


func fresh() -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7; g._opt_shape = "grid"
	root.add_child(g); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER
	g.bank[P] = {"intel": 300.0, "cash": 300.0, "creds": 300.0, "research": 300.0}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func visible_chips() -> Array:
	return g.ready_strip.get_children().filter(func(c): return c != g.ready_more and (c as Control).visible)


func visible_tiles() -> Array:
	return g.ready_grid.get_children().filter(func(c): return (c as Control).visible)


func run() -> void:
	await top_bar()
	await empty_inventory()
	await crowded_inventory()
	await select_and_launch()
	await research_states()
	await queue_strip()
	await research_bar()
	await recipe_actions()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func top_bar() -> void:
	fresh(); await frames()
	var names := []
	for b in g.top_tabs.get_children(): names.append(str(b.name))
	check(names.size() == 3 and names[0] == "Research" and names[1] == "Economy", "Research sits beside Economy and Menu in the top bar (%s)" % str(names))
	check(g.hud.position.x + g.hud.size.x <= g.top_tabs.position.x - 8.0, "The HUD ends before the top buttons (%.0f < %.0f)" % [g.hud.position.x + g.hud.size.x, g.top_tabs.position.x])
	g.research_button.pressed.emit(); await frames()
	check(g._deck_open and g._card_bank == "research", "The Research button opens the research view")
	g.research_button.pressed.emit(); await frames()
	check(not g._deck_open, "...and closes it again")


func empty_inventory() -> void:
	fresh(); await frames()
	g.cards[P] = {}
	g._update_card_banks(); await frames()
	check(visible_chips().is_empty() and g.ready_empty.visible, "Nothing ready: the strip says so instead of showing empty cards")
	g._open_drawer("ready"); await frames()
	check(visible_tiles().is_empty() and (g.hand_panel.get_node("ReadyNone") as Label).visible, "The Ready view explains how to make a copy")
	g._open_drawer("attack"); await frames()
	var recipes: Array = g.hand_bar.get_children().filter(func(c): return (c as Control).visible)
	check(not recipes.is_empty() and not recipes[0].has_method("_get_drag_data"), "Recipes are their own view: a recipe makes copies, it is never dragged as a card")


func crowded_inventory() -> void:
	fresh(); await frames()
	for r in g.CARD_ORDER: g.known[P][r] = true; g.cards[P][r] = 3
	g._update_card_banks(); await frames()
	var chips := visible_chips()
	var same := chips.all(func(c): return absf((c as Control).size.x - g.READY_CHIP_W) < 0.5)
	check(chips.size() >= 3 and same, "15 kinds held: %d chips at their full %d px, never squeezed" % [chips.size(), int(g.READY_CHIP_W)])
	check(g.ready_more.visible and g.ready_more.text == "+%d" % (15 - chips.size()), "The rest wait behind '%s'" % g.ready_more.text)
	g.ready_more.pressed.emit(); await frames()
	check(g._deck_open and g._card_bank == "ready", "'+n' opens the Ready view")
	var seen := {}
	for page in g._deck_pages():
		for t in visible_tiles():
			seen[str(t.key)] = int(seen.get(str(t.key), 0)) + 1
			check(absf((t as Control).size.x - g.READY_TILE.x) < 0.5 and (t as Control).get_global_rect().end.y <= g.hand_panel.get_global_rect().end.y + 0.5, "ready tile %s keeps its size inside the drawer" % str(t.key))
		g._deck_turn(1); await frames()
	check(seen.size() == 15 and seen.values().all(func(v): return int(v) == 1), "Paging shows every ready card exactly once (%d pages)" % g._deck_pages())


func select_and_launch() -> void:
	fresh(); await frames()
	g.cards[P] = {"breach": 2, "patch": 1}
	var home: int = int(g.rig[P])
	var t := -1
	for nb in g.hosts[home].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: t = int(nb); break
	g._open_drawer("ready"); await frames()
	var tile = visible_tiles().filter(func(x): return g._card_of(str(x.key)) == "breach")[0]
	g._arm_card(str(tile.key)); await frames()
	check(g._armed == "breach" and not g._deck_open, "Clicking a ready card selects it and the drawer gets out of the map's way")
	g._open_drawer("ready"); await frames()
	check(g._armed == "breach", "Opening the drawer again keeps the selection")
	g._set_deck_open(false); await frames()
	check(g._launch_armed(home) and g._armed == "breach" and g._held(P, "breach") == 2, "A click on a host it cannot target keeps it selected and spends nothing")
	check(g._launch_armed(t) and g._armed == "" and g._held(P, "breach") == 1 and g.flights.any(func(f): return str(f.get("card", "")) == "breach"),
		"A click on a valid target launches one copy and clears the selection")
	g._arm_card(g._card_key("breach", "linked"))
	var esc := InputEventKey.new(); esc.keycode = KEY_ESCAPE; esc.pressed = true
	g._input(esc)
	check(g._armed == "", "Esc unselects")
	g._arm_card(g._card_key("patch", "linked"))
	g.cards[P].patch = 0; g._update_card_banks()
	check(g._armed == "", "A selected card that is used up elsewhere is unselected")


func research_states() -> void:
	fresh(); await frames()
	g._open_drawer("research"); await frames()
	g._research_node_click("ddos")
	check(g._research_sel == "ddos" and str(g._research_action("ddos")[0]) == "Research", "Clicking a blueprint selects it; its action is Research")
	check(not bool(g._research_action("sabotage")[1]) and str(g._research_action("recon")[0]) == "Open its recipes", "A locked one cannot be researched; a known one opens its recipes")
	g._research_act()
	check(str(g.research_job[P].get("key", "")) == "ddos", "The action starts the research")
	step(3.0); g._update_card_banks()
	check(g.research_button.text.begins_with("Research ") and g.research_button.text.ends_with("%") and str(g._research_status_line()[0]).begins_with("Researching DDoS"),
		"The button shows its progress (%s) and the view names it: %s" % [g.research_button.text, str(g._research_status_line()[0])])
	check(str(g._research_action("ddos")[0]) == "Pause", "Selected while running: Pause")
	g._research_act(); g._update_card_banks()
	check(g.research_button.text.begins_with("Paused") and str(g._research_status_line()[0]).begins_with("Paused: DDoS"), "Paused: %s" % g.research_button.text)
	g._research_act()
	for r in ["intel", "cash", "research"]: g.bank[P][r] = 0.0
	step(1.0); g._update_card_banks()
	check(g.research_button.text.begins_with("Stalled") and str(g._research_status_line()[1]) == str(g.C_BAD), "Starved of resources: %s, in red" % g.research_button.text)
	g._research_node_click("express")
	var st_sel: Dictionary = g._research_node_state("express"); var st_run: Dictionary = g._research_node_state("ddos")
	check(g._research_sel == "express" and str(st_run.state) == "stalled" and str(st_sel.state) == "open", "Selection and the running research are different nodes with different looks")


func chip(k: int):
	return g.lane_strip.get_child(k)


func queue_strip() -> void:
	fresh(); await frames()
	g.bank[P] = {"intel": 100.0, "cash": 100.0, "creds": 100.0, "research": 100.0}
	var chips: Array = g.lane_strip.get_children().filter(func(c): return c.has_method("state"))
	check(chips.size() == g.QUEUE_SIZE, "The strip shows the queue's %d places (%d)" % [g.QUEUE_SIZE, chips.size()])
	check(str(chip(0).state().kind) == "empty" and str(chip(0).state().text) == "+ Queue a card", "An empty queue invites: %s" % str(chip(0).state().text))
	g._enqueue(g._card_key("recon", "linked")); g._enqueue(g._card_key("recon", "linked"))
	step(1.0)
	check(str(chip(0).state().kind) == "making" and float(chip(0).state().progress) > 0.0 and str(chip(1).state().kind) == "queued",
		"The head shows what it makes and how far (%s); the next one waits (%s)" % [str(chip(0).state().text), str(chip(1).state().text)])
	var st: Dictionary = g._card_research_state(g._card_key("recon", "linked"))
	check(int(st.n) == 2, "The recipe knows how many copies are queued (%d)" % int(st.n))
	g.queue_pause.pressed.emit(); g._update_card_banks()
	check(str(chip(0).state().kind) == "paused" and g.queue_pause.text == "Resume", "Pause is its own control: %s, button '%s'" % [str(chip(0).state().text), g.queue_pause.text])
	g.queue_pause.pressed.emit(); g._update_card_banks()
	check(g.queue_pause.text == "Pause", "...and resumes")
	step(float(g.CARDS.recon.make_time) * 2.0 + 0.2)
	check(str(chip(0).state().kind) == "done" and g._held(P, "recon") == 2, "Finished: it shows done, and both copies are ready")
	for r in g.RES: g.bank[P][r] = 0.0
	g._enqueue(g._card_key("recon", "linked"))
	step(0.5)
	check(str(chip(0).state().kind) == "waiting" and str(chip(0).state().text).begins_with("Needs"), "A head that cannot start says what it needs: %s" % str(chip(0).state().text))
	var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true; ev.position = Vector2(chip(0).size.x - 8.0, 10.0)
	chip(0)._gui_input(ev)
	check(str(chip(0).state().kind) in ["empty", "done"] and g._mq(P).is_empty(), "x on the chip removes it")


func research_bar() -> void:   # always on screen, outside the drawer: name, track, %, state, work left; idle says so
	fresh(); await frames()
	var bar: Control = g.research_bar
	check(bar.visible and not g._deck_open, "The research bar is on screen with the drawer closed")
	check(str(g._research_bar_state().state) == "idle" and str(bar._get_tooltip(Vector2.ZERO)).begins_with("Nothing is being researched"), "Idle: it says nothing is being researched and how to start")
	var hud_end: float = g.hud.get_global_rect().end.y
	check(bar.get_global_rect().position.y >= hud_end - 0.5 and not bar.get_global_rect().intersects(g.panel.get_global_rect()), "It sits under the HUD and clear of the inspector")
	g._cmd(["research", "ddos"]); step(2.0)
	var st: Dictionary = g._research_bar_state()
	check(str(st.state) == "active" and str(st.name) == "DDoS" and str(st.track) == "Attack" and float(st.frac) > 0.0 and float(st.left) > 0.0,
		"Active: name, track, progress and work left (%s)" % str(st))
	g.research_job[P].paused = true
	check(str(g._research_bar_state().state) == "paused", "Paused reads paused")
	g.research_job[P].paused = false
	for r in ["intel", "cash", "research"]: g.bank[P][r] = 0.0
	check(str(g._research_bar_state().state) == "stalled" and str(g._research_bar_state().why).contains("no"), "Stalled names what is missing: %s" % str(g._research_bar_state().why))
	var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true
	bar._gui_input(ev); await frames()
	check(g._deck_open and g._card_bank == "research", "Clicking it opens Research")


func recipe_actions() -> void:   # explicit actions: + Queue on a known recipe, Research on a locked one; the tile body does not queue
	fresh(); await frames()
	g._open_drawer("attack"); await frames()
	var tiles: Array = g.hand_bar.get_children().filter(func(c): return (c as Control).visible)
	var recon_tile = tiles.filter(func(t): return g._card_of(str(t.key)) == "recon")[0]
	await frames()
	check(str(recon_tile.queue_button.text) == "+ Queue" and not recon_tile.queue_button.disabled, "A known recipe has its own + Queue button")
	var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true; ev.position = Vector2(30, 30)
	recon_tile._gui_input(ev); var up := ev.duplicate(); up.pressed = false; recon_tile._gui_input(up)
	check(g._mq(P).is_empty(), "Clicking the tile's body explains; it does not queue a copy")
	recon_tile.queue_button.pressed.emit(); recon_tile.queue_button.pressed.emit()
	check(g._mq_count(P, "recon") == 2 and g._recipe_hint(g._card_key("recon", "linked")) == "2 queued · 0 ready", "+ Queue adds copies; the tile reads '%s'" % g._recipe_hint(g._card_key("recon", "linked")))
	check(tiles.all(func(t): return g._known(P, g._card_of(str(t.key)))), "Recipes lists only learned blueprints; the rest are researched from the Research tree")
