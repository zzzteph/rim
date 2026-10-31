extends SceneTree
## Host inspection (feedback round B, section 4): the host panels hold state, quantities, progress and controls, not
## prose; no card is sent or launched from them; nothing is left behind when the selection or the panel changes; a
## finished Firewall shows its 3 socket positions right under it (empty, a card on its way, loaded, off), and every
## card stays in the Firewall it was loaded into when another fires, is demolished or is built.
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
	g.bank[P] = {"intel": 200.0, "cash": 200.0, "creds": 100.0, "research": 100.0}


func until_built(n: int, limit := 180.0) -> void:   # construction waits for its materials: run until the host's projects are done
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


func run() -> void:
	await sockets_stay_seated()
	await sockets_render()
	await no_launch_controls()
	await no_stale_controls()
	await local_supplies()
	await inspector()
	await typed_rates_and_lost_selection()
	await view_stays_put()
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
	check(not items.any(func(s): return str(s).contains("Refill") or str(s).contains("LOCAL STOCK") or str(s).contains("WORKERS") or str(s).contains("slots")), "No Refill, no stock table, no worker list, no slot count")
	var boxes := 0; var cards := 0
	var stack := [g.panel_box]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		for ch in c.get_children(): stack.append(ch)
		if "slot" in c and "host" in c and c.has_method("_can_drop_data") and not ("first" in c): boxes += 1
		elif "kind" in c and c.has_method("_get_drag_data"): cards += 1
	check(boxes == int(g.hosts[n].slots) and cards == g.BUILD_KINDS.size(), "Its slots and the six buildings are all there (%d, %d)" % [boxes, cards])
	g._cmd(["build", n, 1, "intel"])
	var box = null
	stack = [g.panel_box]
	while not stack.is_empty():
		var c2: Node = stack.pop_back()
		for ch in c2.get_children(): stack.append(ch)
		if "slot" in c2 and "host" in c2 and c2.has_method("_can_drop_data") and not ("first" in c2) and int(c2.slot) == 1: box = c2
	g._refresh_panel(); await frames()
	check(box != null and box.stop_button.visible and str(box.stop_button.text).contains("Cancel") and str(g._slot_tip(n, 1)).contains("Waiting for its materials"),
		"An order waiting for its materials says so on its slot (and its tooltip), with a cancel button, not in prose")


func typed_rates_and_lost_selection() -> void:
	fresh()
	var home: int = int(g.rig[P])   # a Server: Intel x1.5
	check(g._build_short("intel", home) == "+1.5 Intel" and g._build_short("intel") == "+1 Intel", "A slot card gives what it makes on THIS host (%s on a Server; the palette card says %s)" % [g._build_short("intel", home), g._build_short("intel")])
	var n := neighbour(g.NEUTRAL)
	g._capture(n, P); g.hosts[n].type = "db"; g.hosts[n].slots = 4; g._set_builds(n, ["intel", "cred", "", ""])
	check(g._build_short("intel", n) == "+2 Intel" and g._build_short("cred", n) == "+1.5 Cred", "...+2 Intel and +1.5 Cred on a Database")
	g.sel = {n: true}; g._inspect = -1; g._refresh_panel()
	g._capture(n, R); g._set_builds(n, ["wall", "lab", "", ""])   # a rival takes the host you are looking at, and builds
	var txt := "\n".join(PackedStringArray(panel_items()))
	check(g.sel.is_empty() and g._inspect == n and not txt.contains("Research lab") and not txt.contains("Firewall"), "A selected host a rival takes stops being your build menu: you inspect it behind its fog")


func view_stays_put() -> void:   # the sim never moves your view or your reading place; one selected host never sits under the drawer
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
