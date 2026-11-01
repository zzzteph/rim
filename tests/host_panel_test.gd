extends SceneTree
## Host inspection (feedback round B, section 4): the host panels hold state, quantities, progress and controls, not
## prose; no card is sent or launched from them; nothing is left behind when the selection or the panel changes; a
## finished Firewall shows its 3 socket positions in its row (empty, a card on its way, loaded, off), and every
## card stays in the Firewall it was loaded into when another fires, is demolished or is built. Your host's panel is its
## facts (type, owner, slots used, storage, Firewall) and one row per slot; a click on a slot opens the chooser, which
## lists every building and orders the one picked into THAT slot through the build command, then closes.
## godot --headless --path . --script tests/host_panel_test.gd
var g
var P := 1
var R := 2
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
	P = g.PLAYER; R = g.RIVAL
	g.bank[P] = {}   # (0.6.18) a well-stocked bank, half the base caps: the caps scale with the prices, so it stays plenty after a rescale
	for res in g.RES: g.bank[P][res] = 0.5 * float(g.BASE_CAP[res])


func until_built(n: int) -> void:   # construction waits for its materials: run until the host's projects are done
	# (0.6.18: no fixed 180 s, which the doubled bills outgrew: a Firewall two links out took 189 s.) The time it takes if
	# every unit still owed makes a round trip from the main node, the workers carrying WORKER_CARRY a leg, then the
	# demolition and the work; half as much again for dispatch, and the loop ends the moment the projects are done
	var owed := 0.0
	for k in (g.hosts[n].jobs as Dictionary):
		var job: Dictionary = g.hosts[n].jobs[k]
		for r in (job.bill as Dictionary): owed += maxf(0.0, float(job.bill[r]) - float((job.escrow as Dictionary).get(r, 0.0)))
	var trip: float = 2.0 * g._leg_time(P, int(g.rig[P]), n)
	var workers := maxf(1.0, float(g._worker_counts(P).total))
	var carry: float = owed / (workers * g.WORKER_CARRY) * trip if is_finite(trip) else 0.0
	var limit: float = 1.5 * (carry + float(g.DEMOLISH_TIME) + float(g.BUILD_TIME))
	var t := 0.0
	while t < limit and not (g.hosts[n].jobs as Dictionary).is_empty():
		step(0.5); t += 0.5


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func neighbour(owner: int) -> int:
	for nb in g.hosts[int(g.rig[P])].links:
		if int(g.hosts[int(nb)].owner) == owner: return int(nb)
	return -1


func controls(n: Node, out: Array) -> void:   # every visible Button / Label text in the panel
	if n is Button and (n as Button).is_visible_in_tree(): out.append("B:" + (n as Button).text)
	elif n is Label and (n as Label).is_visible_in_tree(): out.append("L:" + (n as Label).text)
	for c in n.get_children(): controls(c, out)


func panel_items() -> Array:
	g._refresh_panel()
	var out := []; controls(g.panel, out)
	return out


func socket_lists(n: Node, out: Array) -> void:
	if n.get_script() != null and str(n.get_script().get_global_name()) == "" and n.has_method("state") and "first" in n: out.append(n)
	for c in n.get_children(): socket_lists(c, out)


func lists() -> Array:
	g._refresh_panel()
	var out := []; socket_lists(g.panel, out)
	return out


func find(pred: Callable) -> Array:   # every node in the panel the predicate accepts
	g._refresh_panel()
	var out := []
	var stack: Array = [g.panel_box]
	while not stack.is_empty():
		var c: Node = stack.pop_front()   # (in panel order)
		for ch in c.get_children(): stack.append(ch)
		if pred.call(c): out.append(c)
	return out


func rows() -> Array: return find(func(c): return "stop_button" in c and "slot" in c)   # SlotBox
func options() -> Array: return find(func(c): return c.has_method("choose") and "kind" in c)   # BuildOption
func infos() -> Array: return find(func(c): return c.get_class() == "Control" and "host" in c and not ("slot" in c) and not ("first" in c) and not ("kind" in c))   # HostInfo
func row_of(n: int, slot: int):
	for r in rows():
		if int(r.host) == n and int(r.slot) == slot: return r
	return null


func button(text: String):
	for b in find(func(c): return c is Button and (c as Button).text == text and (c as Button).is_visible_in_tree()): return b
	return null


func click(c: Control, right := false) -> void:   # a press and a release on the control, as the GUI delivers them
	for down in [true, false]:
		var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT; ev.pressed = down
		ev.position = c.size * 0.5
		c._gui_input(ev)


func push_click(at: Vector2) -> void:   # a press and a release delivered through the viewport, as the mouse does
	for down in [true, false]:
		var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = down
		ev.position = at; ev.global_position = at
		root.push_input(ev, true)   # (in the viewport's own coordinates: headless runs a stretched 64 px window)


func run() -> void:
	await sockets_stay_seated()
	await sockets_render()
	await no_launch_controls()
	await no_stale_controls()
	await local_supplies()
	await inspector()
	await typed_rates_and_lost_selection()
	await view_stays_put()
	await chooser()
	await notes_know_their_height()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func sockets_stay_seated() -> void:
	fresh()
	var n := neighbour(g.NEUTRAL)
	g._capture(n, P); g.hosts[n].type = "pc"; g.hosts[n].slots = 3
	g._set_builds(n, ["wall", "intel", "wall"])
	check(g._sockets(n) == 6 and g._wall_seat(n, 0) == 0 and g._wall_seat(n, 2) == 1, "Two finished Firewalls: 6 sockets, the left one seats positions 0-2, the right one 3-5")
	for r in ["patch", "filter", "cover", "response"]: g._put_socket(n, r)
	check(g.hosts[n].sockets == ["patch", "filter", "cover", "response"], "Cards load into the first empty position from the left")
	g._fire_socket(n, "patch", "test")
	check(g.hosts[n].sockets == ["", "filter", "cover", "response"], "A card that fires leaves its position empty; no card moves")
	g._put_socket(n, "patch")
	check(str(g.hosts[n].sockets[0]) == "patch", "The next card takes that empty position")
	g._do_demolish(P, n, 0)
	check(g.hosts[n].sockets == ["response"] and g._sockets(n) == 3, "Demolishing the left Firewall takes its 3 cards with it at once; the right one keeps its own (Response)")
	step(float(g.DEMOLISH_TIME) + 0.5)
	check(g.hosts[n].sockets == ["response"] and g._wall_seat(n, 2) == 0, "When it is gone the right Firewall is the first one, with its card")
	g._start_job(n, "wall", 0)
	until_built(n)
	check(g._sockets(n) == 6 and g.hosts[n].sockets == ["", "", "", "response"] and g._wall_seat(n, 2) == 1,
		"A new Firewall built to its left gets 3 empty positions; the Response stays in its own Firewall")
	g._start_job(n, "intel", 2)   # replacing the right Firewall with a harvester
	check(g._loaded(n).is_empty() and g._sockets(n) == 3, "Replacing a Firewall takes its cards away when the work starts")


func sockets_render() -> void:
	fresh()
	var home: int = int(g.rig[P])
	var via := neighbour(g.NEUTRAL)
	g._capture(via, P)
	var n := -1
	for nb in g.hosts[via].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL and not g.hosts[home].links.has(int(nb)): n = int(nb); break
	g._capture(n, P); g.hosts[n].type = "pc"; g.hosts[n].slots = 3
	g._set_builds(n, ["wall", "intel", "wall"])
	g.hosts[n].sockets = ["patch", "", "", "filter"]
	g.cards[P] = {"cover": 1}
	g.sel = {n: true}; g._inspect = -1
	var ls := lists()
	check(ls.size() == 2 and int(ls[0].first) == 0 and int(ls[1].first) == 3, "Each finished Firewall shows its own socket list under it (positions 0 and 3)")
	check(str(ls[0].state(0)[0]) == "loaded" and str(ls[0].state(0)[1]) == "patch" and str(ls[0].state(1)[0]) == "empty" and str(ls[1].state(0)[1]) == "filter",
		"Loaded cards show by name in their own Firewall; free positions read empty")
	g._play_card(P, "cover", n)
	ls = lists()
	check(str(ls[0].state(1)[0]) == "held" and str(ls[0].state(1)[1]) == "cover" and float(ls[0].eta(1)) > 0.0, "A Cover on its way holds the first empty position and shows its arrival time")
	step(5.0)
	ls = lists()
	check(str(ls[0].state(1)[0]) == "loaded" and str(ls[0].state(1)[1]) == "cover", "On arrival it is loaded in that same position")
	g.hosts[n].fw_on = false
	check(str(ls[0]._get_tooltip(Vector2(5, 5))).contains("OFF"), "A Firewall without Intel shows its sockets as off")
	g._set_builds(n, ["", "intel", "wall"])
	ls = lists()
	check(ls.size() == 1 and int(ls[0].first) == 0, "Demolished: its socket list goes at once")
	g._start_job(n, "wall", 0)
	ls = lists()
	check(ls.size() == 1, "A Firewall still being built has no sockets yet")
	until_built(n)
	ls = lists()
	check(ls.size() == 2, "...and gets its list as soon as it is finished")


func no_launch_controls() -> void:
	fresh()
	g.cards[P] = {"recon": 2, "breach": 1, "patch": 1, "response": 1}
	var own := neighbour(g.NEUTRAL)
	g._capture(own, P); g._set_builds(own, ["intel", "cash"])
	var foe := neighbour(g.NEUTRAL)
	g._capture(foe, R)
	var bad := []
	for ctx in [[own, -1], [int(g.rig[P]), -1], [-1, foe]]:
		g.sel = {} if int(ctx[0]) < 0 else {int(ctx[0]): true}; g._inspect = int(ctx[1])
		for it in panel_items():
			var s := str(it)
			if s.contains("Launch") or s.contains("×") or s.contains("Apply support") or s.contains("Recon ×") or (s.begins_with("B:") and (s.contains("Patch") or s.contains("Breach"))): bad.append(s)
	check(bad.is_empty(), "No host panel sends or launches a card (%s)" % str(bad))
	g.sel = {}; g._inspect = foe
	var txt := "\n".join(PackedStringArray(panel_items()))
	check(txt.contains("25% without fresh Recon, 50% with it"), "A foreign host's panel says what your attacks' odds are there")


func no_stale_controls() -> void:   # explore a host, change selection, clear it, switch panels: only the current context shows
	fresh()
	g.cards[P] = {"recon": 1, "breach": 1}
	var foe := neighbour(g.NEUTRAL)
	g._capture(foe, R)
	var own := neighbour(g.NEUTRAL)
	g._capture(own, P)
	var foe_name := str(g.hosts[foe].name)
	var steps := [["inspect", func(): g.sel = {}; g._inspect = foe], ["select own", func(): g.sel = {own: true}; g._inspect = -1],
		["clear", func(): g.sel = {}; g._inspect = -1], ["economy", func(): g._toggle_economy()], ["economy off", func(): g._toggle_economy()],
		["events", func(): g._toggle_events()], ["events off", func(): g._toggle_events()], ["inspect again", func(): g.sel = {}; g._inspect = foe],
		["fogged away", func(): g._inspect = -1; g._refresh_panel()]]
	var stale := []
	for st in steps:
		(st[1] as Callable).call()
		g._refresh_panel(); await frames()
		var items := panel_items()
		var gutter: int = g.panel_gutter.get_child_count()
		var shows_foe := items.any(func(s): return str(s).contains(foe_name))
		var should := str(st[0]).begins_with("inspect")
		if gutter != 1 or shows_foe != should or items.any(func(s): return str(s).contains("Launch")): stale.append("%s (gutter %d, foe %s)" % [st[0], gutter, str(shows_foe)])
	check(stale.is_empty(), "Every step shows only its own context, one panel body, no Launch (%s)" % str(stale))


func local_supplies() -> void:   # supplies are automatic: no Keep-here stepper anywhere, and only two problem lines
	fresh()
	var n := neighbour(g.NEUTRAL)
	g._capture(n, P); g._set_builds(n, ["cash"])
	g.sel = {n: true}; g._inspect = -1
	await frames()
	var items := panel_items()
	check(not items.any(func(s): return str(s).contains("Keep here")), "No Keep-here control: a Miner host is supplied automatically")
	var plus := false
	var stack := [g.panel]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and (node as Button).visible and (node as Button).text == "+": plus = true
		for c in node.get_children(): stack.append(c)
	check(not plus, "No +/- stock stepper")
	var probs := 0
	g._set_builds(n, ["cash", "lab", "cred"]); g.hosts[n].slots = 3
	for it in panel_items():
		if str(it).begins_with("L:") and (str(it).contains("needs") or str(it).contains("waits")): probs += 1
	check(probs <= 2, "At most two problem lines; the rest are for the Economy view and Help (%d)" % probs)


func inspector() -> void:   # compact at 1280×720: your host's panel is its name, its slots and the buildings, nothing else
	fresh()
	await frames()
	check(g.PANEL_W >= 360.0 and g.PANEL_W <= 400.0, "The inspector is %d px wide at 1280×720" % int(g.PANEL_W))
	var home: int = int(g.rig[P])
	g.sel = {home: true}; g._inspect = -1
	var items := panel_items()
	var labels := items.filter(func(s): return str(s).begins_with("L:"))
	check(labels == ["L:" + str(g.hosts[home].name)], "The main node's panel has no prose: only its name (%s)" % str(labels))
	var n := neighbour(g.NEUTRAL)
	g._capture(n, P); g._set_builds(n, ["lab"])
	g.bank[P].intel = 0.0; g.bank[P].cash = 0.0
	g.sel = {n: true}; g._inspect = -1
	items = panel_items()
	check(not items.any(func(s): return str(s).contains("Refill") or str(s).contains("LOCAL STOCK") or str(s).contains("WORKERS")), "No Refill, no stock table, no worker list in words")
	check(rows().size() == int(g.hosts[n].slots) and options().is_empty() and infos().size() == 1, "Its facts, then one row per slot, and no always-open palette (%d rows, %d buildings)" % [rows().size(), options().size()])
	var facts: Dictionary = g._host_info_view(n)
	check(str(facts.line).begins_with(str(g.NODE_TYPES[str(g.hosts[n].type)].name)) and str(facts.line).contains("yours") and str(facts.slots) == "1/%d slots used" % int(g.hosts[n].slots) and str(facts.fill) == "0/%d" % int(g.STORE_CAP),
		"The facts: type, owner, slots used and the storage as x/%d (%s · %s · %s)" % [int(g.STORE_CAP), facts.line, facts.slots, facts.fill])
	var lab: Dictionary = g._slot_view(n, 0)
	check(str(lab.flow[0][1]) == "+" + g._amt(g._tmult(n, "research")) and str(lab.flow[1][0]) == "lab" and str(lab.stock[1][0]) == "lab" and str(lab.stock[2][1]) == "0", "A Research lab's row: what it makes a cycle on this host with the Research icon, and the Research stock here as an icon with its amount")
	g._cmd(["build", n, 1, "intel"])
	g._refresh_panel(); await frames()
	var box = row_of(n, 1)
	var proj: Dictionary = g._slot_view(n, 1)
	var none_of := "0/%d" % int(g._build_cost("intel").intel)   # none of the harvester's Intel bill is here yet
	check(box != null and box.stop_button.visible and str(box.stop_button.text).contains("Cancel") and str(g._slot_tip(n, 1)).contains("Waiting for its materials")
		and str(proj.state) == "Needs materials" and (proj.mats as Array).any(func(it): return str(it[1]) == none_of),
		"An order waiting for its materials says so on its row (and its tooltip), its materials as icons (%s), with a cancel button, not in prose" % none_of)


func typed_rates_and_lost_selection() -> void:
	fresh()
	var home: int = int(g.rig[P])   # a Server: Intel x1.5
	var made := func(kind: String, type := "") -> String:   # one producer's output a cycle: its rate x the host type's multiplier (none without a host)
		return "+" + g._amt(float(g.BUILD_KINDS[kind].rate) * (float(g.NODE_TYPES[type].get(kind, 1.0)) if type != "" else 1.0))
	var srv := str(g.hosts[home].type)
	check(float(g.NODE_TYPES[srv].intel) != 1.0 and str(g._flow_items("intel", home)[0][1]) == made.call("intel", srv) and str(g._flow_items("intel")[0][1]) == made.call("intel"),
		"A slot row gives what it makes on THIS host (%s on a %s; %s without a host)" % [g._flow_items("intel", home)[0][1], g.NODE_TYPES[srv].name, g._flow_items("intel")[0][1]])
	var n := neighbour(g.NEUTRAL)
	g._capture(n, P); g.hosts[n].type = "db"; g.hosts[n].slots = 4; g._set_builds(n, ["intel", "cred", "", ""])
	check(str(g._flow_items("intel", n)[0][1]) == made.call("intel", "db") and str(g._flow_items("cred", n)[0][1]) == made.call("cred", "db") and str(g._option_view("cred", n, 2).flow[0][1]) == made.call("cred", "db"),
		"...%s Intel and %s Credentials on a Database, in its rows and its chooser" % [made.call("intel", "db"), made.call("cred", "db")])
	var upkeep: String = g._amt(float(g.BUILD_KINDS.wall.use.intel))
	check(str(g._flow_items("wall", n)[0][1]) == "-" + upkeep and str(g._flow_items("wall", n)[1][0]) == "intel", "A Firewall's row says it uses %s Intel a cycle, as an icon" % upkeep)
	g.sel = {n: true}; g._inspect = -1; g._refresh_panel()
	g._capture(n, R); g._set_builds(n, ["wall", "lab", "", ""])   # a rival takes the host you are looking at, and builds
	var txt := "\n".join(PackedStringArray(panel_items()))
	check(g.sel.is_empty() and g._inspect == n and not txt.contains("Research lab") and not txt.contains("Firewall"), "A selected host a rival takes stops being your build menu: you inspect it behind its fog")


func view_stays_put() -> void:   # the sim never moves your view or your reading place (a host taken, won, lost or fogged); one selected host never sits under the drawer
	fresh()
	var home: int = int(g.rig[P])
	var n := neighbour(g.NEUTRAL)
	g._capture(n, P); g._set_builds(n, ["intel"])
	g.sel = {n: true}; g._inspect = n; g._refresh_panel(); await frames()
	g._pan += Vector2(-3000, 0); var pan0: Vector2 = g._pan   # the player looks at another part of the town
	g._capture(n, R); await frames()
	check(g._pan.distance_to(pan0) < 1.0 and g._inspect == n, "A rival taking your selected host does not move your view (moved %s)" % str(g._pan - pan0))
	var m := neighbour(g.NEUTRAL)
	g._capture(m, P)
	g.sel = {m: true, home: true}; g._inspect = -1; g._refresh_panel(); await frames()
	g._pan += Vector2(-3000, 0); pan0 = g._pan
	g._capture(m, R); await frames()
	check(g._pan.distance_to(pan0) < 1.0 and g.sel.keys() == [home], "...nor does it jump to the other host you had selected (moved %s)" % str(g._pan - pan0))
	var o := -1   # inspect a neutral host in sight, launch at it, look elsewhere while the attack runs
	for i in g.hosts.size():
		if o < 0 and int(g.hosts[i].owner) == g.NEUTRAL and g._visible_to(P, i): o = i
	g.sel = {}; g._inspect = o; g._tab = ""; g._refresh_panel(); await frames()
	g._deck_open = true; g._refresh_panel(); await frames()   # (the Research drawer opened with R while inspecting)
	g._pan += Vector2(-3000, 0); pan0 = g._pan
	g._capture(o, P); step(0.6); await frames()   # past the next heartbeat refresh
	check(g._pan.distance_to(pan0) < 1.0 and g.sel.keys() == [o] and g._inspect == -1, "Your own capture of the host you inspect does not move your view either; it becomes your selection (moved %s, sel %s)" % [str(g._pan - pan0), str(g.sel.keys())])
	check(not g._deck_open, "...and its build menu replaces the open drawer at once")
	var far := -1   # a host of yours with no other host of yours next to it: lost, it falls into the fog
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != g.NEUTRAL or (g.hosts[home].links as Array).has(i) or i == home: continue
		var lone := true
		for nb in g.hosts[i].links: lone = lone and int(g.hosts[int(nb)].owner) != P
		if lone: far = i; break
	g._capture(far, P)
	g.sel = {far: true}; g._inspect = -1; g._tab = ""; g._refresh_panel(); await frames()
	pan0 = g._pan
	g._capture(far, R); step(0.6); await frames()
	check(not g._visible_to(P, far) and g._inspect == -1 and g.sel.is_empty(), "Setup: a selected outpost lost to a rival falls into the fog and leaves the sidebar")
	check(g._pan.distance_to(pan0) < 1.0, "The narrower sidebar it leaves does not slide the map (moved %s)" % str(g._pan - pan0))
	g.sel = {}; g._inspect = -1; g._tab = ""; g._refresh_panel()
	for k in 40: g._event("scroll:%d" % k, g.EV_INFO, "Entry number %d of a long history" % k)
	g._open_logs(); await frames(3)
	g.panel_scroll.scroll_vertical = 200; await frames()
	var s0: int = g.panel_scroll.scroll_vertical
	g._set_deck_open(true); g._refresh_panel(); await frames()
	var s1: int = g.panel_scroll.scroll_vertical
	g._set_deck_open(false); g._refresh_panel(); await frames()
	check(s0 > 0 and s1 == s0 and g.panel_scroll.scroll_vertical == s0, "Opening and closing the card drawer keeps your place in the Logs (%d -> %d -> %d)" % [s0, s1, g.panel_scroll.scroll_vertical])
	g._tab = ""; g._set_deck_open(true)
	g.sel = {home: true}; g._inspect = home; g._refresh_panel()   # selected by a capture, a lesson step, a log entry, a shift-click
	check(not g._deck_open, "One host of yours selected while the drawer is open: the drawer closes, its build menu gets the full height")


func notes_know_their_height() -> void:   # a hover note is sized before it is shown, so Godot keeps it on screen: never shorter than its text
	fresh()
	var home: int = int(g.rig[P])
	var texts := []
	for r in g.RESEARCH: texts.append(g._research_tooltip(str(r)))
	for r in g.CARDS: texts.append(g._card_tooltip(str(r)))
	for k in (g.hosts[home].builds as Array).size(): texts.append(g._slot_tip(home, k))
	for kind in g.BUILD_KINDS: texts.append(g._option_tip(str(kind), home, 0))
	texts.append(g._host_info_tip(home))
	texts.append("short")
	var worst := 0.0; var worst_t := ""
	for t in texts:
		var note: Label = g._wrapped_tooltip(str(t))
		var est: float = note.custom_minimum_size.y
		var w: float = note.custom_minimum_size.x
		root.add_child(note)
		note.custom_minimum_size = Vector2(w, 0); note.size = Vector2(w, 0)
		await process_frame
		var real: float = note.get_combined_minimum_size().y
		if real - est > worst: worst = real - est; worst_t = str(t).substr(0, 40)
		note.queue_free()
	check(worst <= 0.5, "Every hover note's measured height covers its text, so it is placed on screen (worst short by %.0f px: '%s')" % [worst, worst_t])


func chooser() -> void:   # a click on an empty slot opens the chooser: every building; a pick orders it into THAT slot and closes it
	fresh()
	var home: int = int(g.rig[P])
	var n := neighbour(g.NEUTRAL)
	g._capture(n, P); g.hosts[n].type = "pc"; g.hosts[n].slots = 3; g._set_builds(n, ["intel", "", ""])
	g.sel = {n: true}; g._inspect = -1
	g._refresh_panel(); await frames()
	var empty_row = row_of(n, 1)
	check(empty_row != null and bool(g._slot_view(n, 1).empty) and str(g._slot_view(n, 1).title) == "Empty slot — click to build" and str(g._slot_tip(n, 1)).contains("Click it to choose"),
		"An empty slot reads as empty and invites a click")
	push_click((empty_row as Control).get_global_rect().get_center()); await frames()   # a real click, through the viewport
	var kinds := options().map(func(o): return str(o.kind))
	check(g._chooser_slot(n) == 1 and kinds == g.BUILD_KINDS.keys() and rows().is_empty() and infos().is_empty() and button("Close") != null,
		"A click on it opens the chooser for that slot: every building, in place of the slot rows, with Close (%s)" % str(kinds))
	var labels := panel_items().filter(func(s): return str(s).begins_with("L:"))
	check(labels.has("L:Slot 2: choose a building"), "The chooser says which slot it fills (%s)" % str(labels))
	check(options().all(func(o): return bool(g._option_view(str(o.kind), n, 1).ok)), "On an empty slot every building can be ordered")
	g.bank[P].cash = 0.0
	var bot: Dictionary = g._option_view("bot", n, 1)
	check(bool(bot.ok) and (bot.lack as Dictionary).has("cash") and str(bot.tag) == "Not enough in bank" and not (bot.lack as Dictionary).has("intel"),
		"A price the bank cannot pay now is marked, and the building can still be ordered (workers bring it later)")
	check(str(g._option_view("cash", n, 1).what) != "" and (g._option_view("cash", n, 1).flow as Array).size() >= 2, "Every building says in a short line what it does, and what it makes or uses as icons")
	var miner = null
	for o in options(): if str(o.kind) == "cash": miner = o
	click(miner); await frames()
	var job: Dictionary = (g.hosts[n].jobs as Dictionary).get(1, {})
	check(not job.is_empty() and str(job.kind) == "cash" and str(g.hosts[n].builds[1]) == "" and (g.hosts[n].jobs as Dictionary).size() == 1,
		"Picking the Crypto miner orders it into THAT slot (slot 2), through the build command")
	check(g._chooser.is_empty() and options().is_empty() and rows().size() == 3 and row_of(n, 1).stop_button.visible, "...and the chooser closes: the slot rows are back, slot 2 with its project")
	click(row_of(n, 0)); await frames()
	var intel_opt: Dictionary = g._option_view("intel", n, 0)
	check(g._chooser_slot(n) == 0 and button("Remove") != null and not bool(intel_opt.ok) and str(intel_opt.tag) == "Installed here" and bool(g._option_view("wall", n, 0).ok),
		"A click on a built slot opens the same chooser to replace it: the building there is marked, the others can be ordered, and Remove is offered")
	for o in options(): if str(o.kind) == "intel": click(o)
	check(g._chooser_slot(n) == 0 and (g.hosts[n].jobs as Dictionary).size() == 1, "Picking the building already there does nothing")
	for o in options(): if str(o.kind) == "cred": click(o)
	await frames()
	var rep: Dictionary = (g.hosts[n].jobs as Dictionary).get(0, {})
	check(str(rep.get("kind", "")) == "cred" and str(rep.get("phase", "")) == "demolish" and g._chooser.is_empty(), "Picking another replaces it: the slot is cleared first, then built")
	click(row_of(n, 1)); await frames()
	check(g._chooser_slot(n) == 1 and button("Cancel project") != null and options().all(func(o): return not bool(g._option_view(str(o.kind), n, 1).ok)),
		"A slot with a running project offers Cancel project; no building can be ordered there meanwhile")
	button("Cancel project").emit_signal("pressed"); await frames()
	check((g.hosts[n].jobs as Dictionary).get(1, {}).is_empty() and g._chooser_slot(n) == 1 and button("Cancel project") == null and options().all(func(o): return bool(g._option_view(str(o.kind), n, 1).ok)),
		"Cancel project ends it and the chooser stays open on the now empty slot")
	var esc := InputEventKey.new(); esc.keycode = KEY_ESCAPE; esc.pressed = true
	g._input(esc); await frames()
	check(g._chooser.is_empty() and g.sel.has(n) and rows().size() == 3, "Esc closes the chooser and keeps the host selected")
	g._open_chooser(n, 2); await frames()
	var map_click := InputEventMouseButton.new(); map_click.button_index = MOUSE_BUTTON_LEFT; map_click.pressed = true; map_click.position = Vector2(30, 300)
	g._gui_input(map_click); await frames()
	check(g._chooser.is_empty(), "A click on the map closes it")
	g._open_chooser(n, 2); await frames(3)   # through the real GUI: a click on the sidebar's empty space below the chooser
	var below := Vector2(g.panel.get_global_rect().get_center().x, minf(g.panel_box.get_global_rect().end.y + 30.0, g.panel.get_global_rect().end.y - 10.0))
	push_click(below); await frames()
	check(g._chooser.is_empty() and g.panel.get_global_rect().has_point(below), "A click elsewhere in the sidebar closes it too")
	g._open_chooser(n, 2); await frames(3)   # a real click that lands in the 4 px between two of its rows is a near miss
	var o0: Control = options()[0]; var o1: Control = options()[1]
	var gap := Vector2(o0.get_global_rect().get_center().x, (o0.get_global_rect().end.y + o1.get_global_rect().position.y) * 0.5)
	push_click(gap); await frames()
	check(g._chooser_slot(n) == 2 and not o0.get_global_rect().has_point(gap) and not o1.get_global_rect().has_point(gap) and (g.hosts[n].jobs as Dictionary).get(2, {}).is_empty(),
		"A click between two of its rows orders nothing and leaves it open")
	g._close_chooser(); await frames()
	g._open_chooser(n, 2); await frames(3)   # and a real click on a building in it orders it
	var lab_opt = null
	for o in options(): if str(o.kind) == "lab": lab_opt = o
	push_click((lab_opt as Control).get_global_rect().get_center()); await frames()
	check(str((g.hosts[n].jobs as Dictionary).get(2, {}).get("kind", "")) == "lab" and g._chooser.is_empty(), "A real click on a building in the chooser orders it into that slot and closes it")
	g._cmd(["cancel", n, 2])
	g._open_chooser(n, 2); g.sel = {home: true}; g._refresh_panel(); await frames()
	check(g._chooser.is_empty() and options().is_empty() and rows().size() == int(g.hosts[home].slots), "Selecting another host closes it")
	g._open_chooser(n, 2); g._set_deck_open(true); g._refresh_panel(); await frames()
	check(g._chooser.is_empty(), "Opening the card drawer closes it with the build menu")
	g._set_deck_open(false)
	var foe := neighbour(g.NEUTRAL)
	g._capture(foe, R)
	g.sel = {}; g._inspect = foe; g._refresh_panel()
	g._open_chooser(foe, 0); await frames()
	check(g._chooser.is_empty() and options().is_empty() and rows().is_empty() and infos().is_empty(), "A rival host has no slot rows and no chooser: its inspector keeps its fog rules")
	var nb := neighbour(g.NEUTRAL)
	g.sel = {}; g._inspect = nb; g._open_chooser(nb, 0); await frames()
	check(g._chooser.is_empty() and options().is_empty(), "...nor does a neutral host")
	g._open_chooser(n, 1); await frames()
	for o in options(): o.hover = true; o.queue_redraw()
	for r in rows(): r.hover = true
	await frames(3)
	g._close_chooser(); await frames(3)
	g._cmd(["cancel", n, 0]); g._cmd(["cancel", n, 1])
	var station := neighbour(g.NEUTRAL)
	g._capture(station, P); g._set_builds(station, ["bot", "wall"])
	(g.hosts[station] as Dictionary).erase("teams")
	var v: Dictionary = g._slot_view(station, 0)
	var fv: Dictionary = g._host_info_view(station)
	check(not (g.hosts[station] as Dictionary).has("teams") and str(v.state) == "Off: no workers" and str(fv.wall[1][1]).begins_with("Firewall on"),
		"A station's row reads its workers without writing anything (no teams key added)")
	g._sync_teams(station)
	g.hosts[station].sabot_until = g._t + 30.0
	check(str(g._slot_view(station, 0).state) == "Off: sabotaged", "A sabotaged host's station row says so: Sabotage keeps its workers at the station")
	g.hosts[station].sabot_until = 0.0
	g.sel = {n: true}; g._refresh_panel()
	g.paused = true   # (the clock stands still: only the UI acts below)
	await frames(2)
	var hash1: String = g._mp_hash()
	g._open_chooser(n, 2); await frames(3)
	for o in options(): o.hover = true; o.queue_redraw()
	await frames(3)
	g._close_chooser(); g._open_chooser(n, 0); await frames(3)
	var esc2 := InputEventKey.new(); esc2.keycode = KEY_ESCAPE; esc2.pressed = true
	g._input(esc2); await frames(3)
	check(g._mp_hash() == hash1, "Opening, hovering and closing the chooser and drawing the rows change nothing the simulation reads (lockstep fingerprint unchanged)")
