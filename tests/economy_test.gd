extends SceneTree
## RIM research–manufacture–deliver model: main-node income, bank caps, research unlock,
## manufacture into ready copies, security threshold + Firewall, and a card capture end to end.
## godot --headless --path . --script tests/economy_test.gd
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


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func fat_bank() -> void:   # plenty of every resource, so cost is never the blocker in a focused check
	g.bank[P] = {"bots": 300.0, "intel": 300.0, "cash": 300.0, "creds": 300.0, "research": 300.0}


func neutral_neighbour(sec_type := "iot") -> int:   # a neutral host wired to your main node, forced to a chosen type
	var home: int = int(g.rig[P])
	for nb in g.hosts[home].links:
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL:
			g.hosts[n].type = sec_type
			g.hosts[n].builds = g._slot_array([], int(g.hosts[n].slots))
			g.hosts[n].gen = int(g.hosts[n].get("gen", 0)) + 1
			return n
	# none neutral: commandeer the first neighbour into a neutral soft host
	var first := int(g.hosts[home].links[0])
	g.hosts[first].owner = g.NEUTRAL; g.hosts[first].type = sec_type
	g.hosts[first].builds = g._slot_array([], int(g.hosts[first].slots))
	g.hosts[first].rig = false
	g.hosts[first].gen = int(g.hosts[first].get("gen", 0)) + 1
	return first


func run() -> void:
	income_and_known()
	caps()
	research_unlock()
	manufacture_into_inventory()
	security_and_firewall()
	capture_end_to_end()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func income_and_known() -> void:
	fresh()
	var start: Dictionary = (g.known.get(P, {}) as Dictionary).duplicate()
	var want := ["recon", "breach", "phish", "patch", "response"]
	var all := true
	for r in want:
		if not bool(start.get(r, false)): all = false
	check(all and start.size() == want.size(), "Start blueprints are exactly recon/breach/phish/patch/response")
	var before: Dictionary = (g.bank[P] as Dictionary).duplicate()
	step(10.0)
	var grew := true
	for res in g.RES:
		if float(g.bank[P][res]) < float(before[res]) + 5.0: grew = false
	check(grew, "The main node delivers one of each resource per second locally (every bank grew ~10 in 10 s)")


func caps() -> void:
	fresh()
	var res := "cash"
	var cap: float = g._cap(P, res)
	g.bank[P][res] = cap - 1.0
	var fit: float = g._add_bank(P, res, 50.0)
	check(is_equal_approx(float(g.bank[P][res]), cap) and fit <= 1.0001, "A bank credit is clamped to its cap (cap = base + 50/producer)")


func research_unlock() -> void:
	fresh(); fat_bank()
	check(not g._known(P, "exploit"), "Exploit starts locked (behind the research tree)")
	var before: float = float(g.bank[P]["research"])
	g._do_research(P, "exploit")
	step(g._research_time("exploit") + 1.0)
	check(g._known(P, "exploit"), "Funded research learns the Exploit blueprint after its research time")
	check(float(g.bank[P]["research"]) < before - 1.0, "Research spends resources over the job (research bank fell)")


func manufacture_into_inventory() -> void:
	fresh(); fat_bank()
	g._lane_set(P, 0, "breach")
	check(g._held(P, "breach") == 0, "No ready Breach copy before manufacture finishes")
	var cash_before: float = float(g.bank[P]["cash"])
	g._lane_manufacture(P, 0)
	step(g.SIM_DT)   # the lane charges its cost on the step it starts (before income can refill a capped bank)
	check(float(g.bank[P]["cash"]) < cash_before - 2.0, "Manufacturing charges the recipe cost up front (cash fell ~3)")
	step(g._make_time("breach") + 1.0)
	check(g._held(P, "breach") == 1, "A lane manufactures one ready Breach copy after its make time")


func security_and_firewall() -> void:
	fresh()
	var t := neutral_neighbour("iot")
	check(g._security(t) == 1, "An IoT host is security 1")
	g.hosts[t].builds = g._slot_array(["wall"], int(g.hosts[t].slots))
	check(g._has_firewall(t) and g._security(t) == 2, "A Firewall raises security by one (to 2)")
	# Breach (reach 1) cannot capture a security-2 host
	g.cards[P] = {"breach": 1}
	var why: String = g._can_play(P, "breach", t)
	check("security" in why, "Breach is refused on a security-2 host (%s)" % why)


func capture_end_to_end() -> void:
	fresh()
	var t := neutral_neighbour("iot")
	g.cards[P] = {"breach": 1}
	var why: String = g._can_play(P, "breach", t)
	check(why == "", "Breach is playable on a reachable security-1 neighbour (%s)" % ("ok" if why == "" else why))
	var ok: bool = g._play_card(P, "breach", t)
	check(ok and g._held(P, "breach") == 0, "Playing Breach consumes the copy and launches an operation")
	step(float(g.CARDS["breach"].exec) + 12.0)   # travel + 8 s execution + margin
	check(int(g.hosts[t].owner) == P, "The operation captures the host after travel and execution")
