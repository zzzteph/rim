extends SceneTree
## RIM research–manufacture–deliver model: main-node income, 5-s production cycles with host storage,
## Bot stations, bank caps, research unlock, manufacture into ready copies, security thresholds,
## Firewall sockets that fire on their own, and a card capture end to end.
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


func own_pc() -> int:   # a plain 3-slot PC next to your main node, yours and empty
	var n := neutral_neighbour("pc")
	g.hosts[n].slots = 3
	g._capture(n, P)
	g.hosts[n].type = "pc"; g.hosts[n].builds = g._slot_array([], 3)
	return n


func run() -> void:
	income_and_known()
	cycles_and_storage()
	stations()
	caps()
	research_unlock()
	manufacture_into_inventory()
	security_and_firewall()
	recon_and_worm()
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
	g._set_builds(int(g.rig[P]), [])   # only the main node's own trickle
	var before: Dictionary = (g.bank[P] as Dictionary).duplicate()
	step(10.0)
	var grew := true
	for res in g.RES:
		if absf(float(g.bank[P][res]) - float(before[res]) - 10.0 * g.MAIN_INCOME) > 0.3: grew = false
	check(grew, "The main node delivers one of each resource every 5 s locally (every bank grew ~2 in 10 s)")


func cycles_and_storage() -> void:
	fresh()
	var n := own_pc()
	g._set_builds(n, ["intel", "cash"])
	g.bank[P].bots = 0.0; g.bot_reserve[P] = 999   # no courier Bots to spare: what the host makes stays in its storage
	step(g.PROD_CYCLE + 0.1)
	check(is_equal_approx(g._st_get(n, P, "intel"), 1.0) and is_equal_approx(g._st_get(n, P, "cash"), 1.0),
		"One cycle: the harvester makes 2 Intel, the Miner turns 1 of it into 1 Crypto (%s)" % g._store_text(n))
	step(g.PROD_CYCLE * 10.0)
	check(g._store_total(n) <= g.STORE_CAP + 0.001 and g._store_total(n) >= g.STORE_CAP - 1.0, "Host storage fills to its cap of 10 and stops there (%s)" % g._store_text(n))
	var m := own_pc()
	g._set_builds(m, ["cash"])
	g.bank[P].intel = 200.0
	step(g.PROD_CYCLE * 2.0)
	check(g._store_total(m) < 0.01 and float(g.bank[P].intel) >= 200.0, "A Miner far from the main node uses only its own host's Intel, never the bank's")
	g.bank[P].bots = 100.0; g.bot_reserve[P] = 10   # couriers again: the stored units leave
	step(20.0)
	check(g._store_total(n) < 1.0, "Bank couriers fetch a host's storage once Bots are spare (%s)" % g._store_text(n))


func stations() -> void:
	fresh()
	var n := own_pc()
	g._set_builds(n, ["intel", "cash", "bot"])
	g._set_builds(int(g.rig[P]), [])
	g.bank[P].bots = 0.0
	var before: Dictionary = (g.bank[P] as Dictionary).duplicate()
	step(g.PROD_CYCLE * 4.0 + 6.0)   # four cycles plus the trip home
	var trickle: float = (g.PROD_CYCLE * 4.0 + 6.0) * g.MAIN_INCOME
	check(float(g.bank[P].bots) - float(before.bots) - trickle >= 7.0, "A Bot station's 2 Bots per cycle reach your bank (+%.0f Bots)" % (float(g.bank[P].bots) - float(before.bots) - trickle))
	check(float(g.bank[P].intel) - float(before.intel) - trickle >= 3.0 and float(g.bank[P].cash) - float(before.cash) - trickle >= 3.0,
		"... carrying the host's 1 Intel and 1 Crypto per cycle home with them")
	check(g._store_total(n) < 1.0, "With a station nothing waits in storage, even with no bank couriers")


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
	var creds_before: float = float(g.bank[P]["creds"])
	g._lane_manufacture(P, 0)
	step(g.SIM_DT)   # the lane charges its cost on the step it starts (before income can refill a capped bank)
	check(float(g.bank[P]["creds"]) < creds_before - float(g.CARDS.breach.make.creds) + 1.0, "Manufacturing charges the recipe cost up front (Credentials fell by Breach's price)")
	step(g._make_time("breach") + 1.0)
	check(g._held(P, "breach") == 1, "A lane manufactures one ready Breach copy after its make time")


func security_and_firewall() -> void:
	fresh()
	var t := neutral_neighbour("iot")
	check(g._security(t) == 1, "An IoT host is security 1")
	g.hosts[t].type = "server"
	g.cards[P] = {"breach": 1}
	var why: String = g._can_play(P, "breach", t)
	check("security" in why, "Breach is refused on a security-2 host (%s)" % why)
	# a Firewall: no security, 3 sockets for defence cards that fire on their own
	var n := own_pc()
	g._set_builds(n, ["intel", "wall"])
	check(g._security(n) == 1 and g._sockets(n) == 3, "A Firewall adds 3 card sockets and no security")
	g.cards[P] = {"patch": 1, "response": 1}
	g._play_card(P, "patch", n)
	check(g._held(P, "patch") == 0 and (g.hosts[n].sockets as Array).has("patch"), "Patch played on a Firewall host is loaded into a socket")
	step(g.PROD_CYCLE + 0.1)
	check(bool(g.hosts[n].fw_on), "The Firewall is powered by its host's Intel (1 per cycle)")
	var R: int = g.RIVAL
	g._op_land(R, "breach", n, int(g.hosts[n].gen), {"id": 9001})
	var busy := false
	for e in g._execs: if int(e.target) == n: busy = true
	check(not busy and (g.hosts[n].sockets as Array).is_empty(), "The loaded Patch fires itself and stops a rival Breach the moment it starts")
	g._op_land(R, "phish", n, int(g.hosts[n].gen), {"id": 9002})
	check(g._phished(n), "With the socket used up, the next attack (Phishing) lands")
	g._play_card(P, "response", n)
	check(not g._phished(n) and (g.hosts[n].sockets as Array).is_empty(), "A defence card whose attack is already here fires at once instead of loading")
	g._set_builds(n, ["", "wall"])   # no Intel on the host: the Firewall goes dark
	g.hosts[n].store = {}
	g.cards[P] = {"filter": 1}
	g.known[P]["filter"] = true
	g._play_card(P, "filter", n)
	step(g.PROD_CYCLE + 0.1)
	check(not bool(g.hosts[n].fw_on), "Without Intel on its host the Firewall switches off")
	g._op_land(R, "ddos", n, int(g.hosts[n].gen), {"id": 9003})
	check(g._ddos_down(n) and (g.hosts[n].sockets as Array).has("filter"), "A switched-off Firewall does not fire: the DDoS lands, the Filter waits")


func recon_and_worm() -> void:
	fresh()
	var R: int = g.RIVAL
	var home: int = int(g.rig[P])
	var soft := []   # two neutral neighbours of your main node, made security-1
	for nb in g.hosts[home].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL and soft.size() < 2:
			g.hosts[int(nb)].type = "iot"; soft.append(int(nb))
	g.hosts[soft[1]].owner = R; g.hosts[soft[1]].gen += 1
	g._set_builds(soft[1], ["intel"])
	g._refresh_sight()
	check(g._worm_next(P, home, R) == soft[1], "Worm: the chain only moves to hosts of the first target's owner")
	check(g._worm_next(P, home, R) != soft[0], "Worm: a neutral soft host next to the chain is skipped")
	check(not g._scanned(P, soft[1]), "Recon: a rival host's slots are hidden before a scan")
	g._op_land(P, "recon", soft[1], int(g.hosts[soft[1]].gen), {"id": 9100})
	check(g._scanned(P, soft[1]) and g._seen_build(P, soft[1], 0) == "intel", "Recon: the scan shows what the host holds")
	g._set_builds(soft[1], ["cash"])
	check(g._seen_build(P, soft[1], 0) == "intel", "Recon: you see the snapshot, not later changes")
	step(float(g.CARDS.recon.dur) + 1.0)
	check(not g._scanned(P, soft[1]), "Recon: the view expires after %d s" % int(g.CARDS.recon.dur))


func capture_end_to_end() -> void:
	fresh()
	var t := neutral_neighbour("iot")
	g.cards[P] = {"breach": 1}
	var why: String = g._can_play(P, "breach", t)
	check(why == "", "Breach is playable on a reachable security-1 neighbour (%s)" % ("ok" if why == "" else why))
	var ok: bool = g._play_card(P, "breach", t)
	check(ok and g._held(P, "breach") == 0, "Playing Breach consumes the copy and launches an operation")
	step(float(g.CARDS["breach"].exec) + 12.0)   # travel + execution + margin (tests/capture_test.gd checks the exact timing)
	check(int(g.hosts[t].owner) == P, "The operation captures the host after travel and execution")
