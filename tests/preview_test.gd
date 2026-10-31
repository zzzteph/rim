extends SceneTree
## Target preview (Milestone A, brief §12.2): legality and its reason, the Recon odds, route and travel, the
## execution and what stops it, affected hosts only as far as you can see, public and dated Recon defences, and no
## change to the game until the card is launched.
## godot --headless --path . --script tests/preview_test.gd
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


func fresh() -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER
	R = int(g.botnets[1]) if int(g.botnets[0]) == P else int(g.botnets[0])
	g.bank[P] = {"bots": 60.0, "intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func neighbour(type := "pc") -> int:   # a neutral host linked to your network, of this type
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != g.NEUTRAL or bool(g.hosts[i].get("rig", false)): continue
		for nb in g.hosts[i].links:
			if int(g.hosts[int(nb)].owner) == P:
				g.hosts[i].type = type
				return i
	return -1


func text(pv: Dictionary) -> String:
	var out := []
	for l in pv.lines: out.append(str(l[0]))
	return "\n".join(out)


func run() -> void:
	capture_preview()
	illegal_targets()
	defences()
	area_effects()
	other_cards()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func capture_preview() -> void:
	fresh()
	var t := neighbour("pc")
	g.cards[P] = {"breach": 1}
	var h0: String = g._mp_hash(); var nf: int = g.flights.size()
	var pv: Dictionary = g._target_preview(P, "breach", t)
	var s := text(pv)
	check(bool(pv.ok) and s.contains("Ready: Credential breach") and not s.contains("ecurity"), "A neighbour: ready, with no security level anywhere")
	check(s.contains("Chance: 50% without fresh Recon"), "Unscouted, the preview says the chance is 50%")
	g._mark_scanned(P, t)
	check(text(g._target_preview(P, "breach", t)).contains("Chance: full"), "Scouted, the preview says the chance is full")
	g.recon[P] = {}
	s = text(g._target_preview(P, "breach", t))
	check(s.contains("Route: 1 hop") or s.contains("Route: 2 hops"), "It gives the route: %s" % s.get_slice("\n", 2))
	check(s.contains("executes for 15 s") and s.contains("unless a Patch, a lost route or a change of owner"), "It gives the execution time and what stops it")
	check(s.contains("Defences unknown: no Recon") and s.contains("used only when you launch"), "Unknown defences stay unknown; the card is used only on launch")
	check(g._mp_hash() == h0 and g.flights.size() == nf and int(g.cards[P].breach) == 1, "Previewing changes nothing: fingerprint, flights and the copy are untouched")
	var arrive := -1.0
	for l in pv.lines:
		var line := str(l[0])
		if line.begins_with("Route:"): arrive = float(line.get_slice("arrives in ~", 1).get_slice(" s", 0))
	check(g._play_card(P, "breach", t) and int(g.cards[P].breach) == 0, "Launching uses exactly one copy")
	var f: Dictionary = g.flights[g.flights.size() - 1]
	check(absf((float(f.arrive_t) - g._t) - arrive) < 0.06, "The previewed arrival matches the launched card (%.2f vs %.2f s)" % [arrive, float(f.arrive_t) - g._t])
	check(g._can_drop_data(g._w2s(g.hosts[t].pos), {"card": "breach"}) == bool(g._target_preview(P, "breach", t).ok), "Drag and preview agree on whether a drop is legal")


func illegal_targets() -> void:
	fresh()
	var t := neighbour("web")
	g.cards[P] = {"breach": 1}
	var pv: Dictionary = g._target_preview(P, "breach", t)
	check(bool(pv.ok), "A web server is a legal Breach target: no security levels")
	g.cards[P] = {}
	pv = g._target_preview(P, "breach", t)
	check(not bool(pv.ok) and text(pv).contains("none ready"), "No ready copy: the preview says so")
	var far := -1
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == g.NEUTRAL and g._attack_route(P, i).is_empty(): far = i; break
	g.hosts[far].type = "pc"
	g.cards[P] = {"breach": 1}
	pv = g._target_preview(P, "breach", far)
	check(not bool(pv.ok) and text(pv).contains("Route: none") and text(pv).contains("no route"), "No path from the main node: route none, cannot launch")


func defences() -> void:
	fresh()
	var t := neighbour("pc")
	g._capture(t, R)
	g.cards[P] = {"breach": 1, "phish": 1}
	g.hosts[t].patch_armed_until = g._t + 40.0
	check(text(g._target_preview(P, "breach", t)).contains("Patch armed here for 40 s"), "An armed Patch (shown on the map) is in the preview with its time")
	g.hosts[t].patch_armed_until = 0.0
	g._set_builds(t, ["wall", "intel"])
	g.hosts[t].sockets = ["patch"]
	check(not text(g._target_preview(P, "breach", t)).contains("Firewall holding"), "A loaded Firewall stays hidden without Recon")
	g._mark_scanned(P, t)
	step(3.0)
	var s := text(g._target_preview(P, "breach", t))
	check(s.contains("Recon 3 s ago: Firewall holding Patch") and s.contains("its Patch would fire"), "Recon shows the Firewall's cards, dated, and warns that its Patch would fire")
	g.hosts[t].sockets = []   # changed after the scan: the preview keeps the snapshot
	check(text(g._target_preview(P, "breach", t)).contains("holding Patch"), "The preview shows the snapshot, not the live sockets")
	check(text(g._target_preview(P, "phish", t)).contains("Recon 3 s ago: Intel harvester."), "Phishing previews the production Recon saw")
	step(50.0)
	check(text(g._target_preview(P, "breach", t)).contains("(out of date)"), "An old snapshot is marked out of date")


func area_effects() -> void:
	fresh()
	var t := neighbour("pc")
	g._capture(t, R)
	var hidden := -1
	for i in g.hosts.size():   # a rival host the player cannot see
		if int(g.hosts[i].owner) == R and not g._visible_to(P, i): hidden = i; break
	g.cards[P] = {"ddos": 1, "sabotage": 1, "worm": 1, "vault": 1}
	for key in ["ddos", "sabotage", "vault"]:
		var pv: Dictionary = g._target_preview(P, key, t)
		var leak := false
		for i in g.hosts.size():
			if int(g.hosts[i].owner) == R and not g._visible_to(P, i) and text(pv).contains(str(g.hosts[i].name) + ",") : leak = true
			if int(g.hosts[i].owner) == R and not g._visible_to(P, i) and text(pv).contains(str(g.hosts[i].name) + "."): leak = true
		check(text(pv).contains(str(g.hosts[t].name)) and not leak, "%s lists the hosts it would hit as far as you can see, none out of sight (hidden rival host %d exists)" % [key, hidden])
	for nb in g.hosts[t].links:   # a second rival host beside t that you can see: the Worm's next stage
		var u := int(nb)
		if int(g.hosts[u].owner) == g.NEUTRAL and g._visible_to(P, u) and not bool(g.hosts[u].get("rig", false)):
			g.hosts[u].type = "pc"; g._capture(u, R); break
	var nxt: int = g._worm_next(P, t, R, [t])
	var want := ("Next if it captures: %s." % str(g.hosts[nxt].name)) if nxt >= 0 else "no eligible host in sight"
	check(text(g._target_preview(P, "worm", t)).contains(want), "Worm names the host its second stage would try (%s)" % want)


func other_cards() -> void:
	fresh()
	var t := neighbour("pc")
	g._capture(t, R)
	g.cards[P] = {"siphon": 1, "recon": 1, "patch": 1}
	check(text(g._target_preview(P, "siphon", t, "", true)).contains("A drag takes Crypto"), "A Siphon dragged says it takes Crypto and where to choose another")
	check(text(g._target_preview(P, "siphon", t, "research")).contains("Research carried by workers"), "A Siphon from the panel names the chosen resource")
	check(text(g._target_preview(P, "recon", t)).contains("fresh for 45 s"), "Recon says how long its snapshot stays fresh")
	var mine := int(g.rig[P])
	g._set_builds(mine, ["wall"])
	check(text(g._target_preview(P, "patch", mine)).contains("Loads into the Firewall here"), "A defence card on a host with a free socket says it loads into the Firewall")
