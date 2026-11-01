extends SceneTree
## RIM research–manufacture–deliver model: main-node income, 5-s production cycles with host storage,
## Bot stations, bank caps, research unlock, manufacture into ready copies, no security levels,
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
	g.rolls_always_hit = true   # these checks are about what each card does; recon_test covers the odds
	g._open_menu(false)
	P = g.PLAYER


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func fat_bank() -> void:   # plenty of every resource, so cost is never the blocker in a focused check
	g.bank[P] = {"intel": 300.0, "cash": 300.0, "creds": 300.0, "research": 300.0}


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
	firewall_eats_harvest_first()
	room_held_for_cargo()
	tight_counts_every_producer()
	crumbs_ride_home()
	stolen_goods_last_on_every_turn()
	ready_full_head_holds_nothing()
	crumbs_bound_in_one_pass()
	phished_plan_keeps_upkeep()
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
	check(grew, "The main node delivers one of each resource every 12 s locally (every bank grew ~0.8 in 10 s)")


func one_cycle(i: int, kind: String) -> float:   # what one producer of this kind makes on host i in one cycle (rate x host type)
	var out := str(g.BUILD_KINDS[kind].out)
	return float(g.BUILD_KINDS[kind].rate) * g._tmult(i, out)


func cycles_and_storage() -> void:   # 0.6.12: every producer makes its own resource with no input; only the Firewall eats Intel
	fresh()
	var n := own_pc()
	var kinds := ["intel", "cash", "cred"]   # the harvester and two former converters, all on one host
	g._set_builds(n, kinds)
	g._set_builds(int(g.rig[P]), ["intel"])   # no Bot station anywhere: no workers, so what the host makes stays in its storage
	step(g.PROD_CYCLE + 0.1)
	var each := true
	var gross := 0.0   # one whole cycle's output of this host
	for kind in kinds:
		gross += one_cycle(n, kind)
		if not is_equal_approx(g._st_get(n, P, str(g.BUILD_KINDS[kind].out)), one_cycle(n, kind)): each = false
	check(each and is_equal_approx(g._store_total(n), gross),
		"One cycle: the harvester makes %s Intel, and the Miner and the Credential harvester make %s Crypto and %s Credentials with no input, leaving the Intel (%s)"
		% [g._amt(one_cycle(n, "intel")), g._amt(one_cycle(n, "cash")), g._amt(one_cycle(n, "cred")), g._store_text(n)])
	step(g.PROD_CYCLE * 10.0)
	check(g._store_total(n) <= g.STORE_CAP + 0.001 and g._store_total(n) >= g.STORE_CAP - 1.0, "Host storage fills to its cap of %d and stops there (%s)" % [int(g.STORE_CAP), g._store_text(n)])
	# Equal producers make the same every cycle, also the last one that only partly fits (it fits STORE_CAP - 3 x gross =
	# 1 of 3 units here): each holds STORE_CAP / 3, where filling the storage in build order would give the harvester more.
	var even := absf(g._store_total(n) - g.STORE_CAP) < 0.001
	for kind in kinds:
		if absf(g._st_get(n, P, str(g.BUILD_KINDS[kind].out)) - g.STORE_CAP / float(kinds.size())) > 0.001: even = false
	check(even, "A full storage is shared evenly: the cycle that only partly fits gives each of the %d producers the same share, %s each (%s)"
		% [kinds.size(), g._amt(g.STORE_CAP / float(kinds.size())), g._store_text(n)])
	var m := own_pc()
	g._set_builds(m, ["cash", "wall"])   # a Miner and a Firewall, no Intel harvester: nothing on this host makes Intel
	g.bank[P].intel = 200.0
	step(g.PROD_CYCLE * 2.0)
	check(is_equal_approx(g._st_get(m, P, "cash"), 2.0 * one_cycle(m, "cash")) and g._st_get(m, P, "intel") < 0.0001,
		"A remote Miner makes its Crypto with no Intel on its host (%s after 2 cycles)" % g._store_text(m))
	check(not bool(g.hosts[m].fw_on) and float(g.bank[P].intel) >= 200.0,
		"A remote Firewall uses only Intel that has reached its host, never the bank's directly (it switched off, bank Intel %d)" % int(g.bank[P].intel))
	g._set_builds(int(g.rig[P]), ["intel", "bot"])   # a Bot station again: its two workers start collecting, and bring the upkeep
	step(30.0)
	check(g._store_total(n) < 2.0 and bool(g.hosts[m].fw_on),
		"The main node's workers collect a host's storage and bring the Firewall its %s Intel per cycle: it is on again (%s · %s)"
		% [g._amt(float(g.BUILD_KINDS.wall.use.intel)), g._store_text(n), g._store_text(m)])


func stations() -> void:
	fresh()
	var n := own_pc()
	g._set_builds(n, ["intel", "intel", "cash", "bot"])   # nothing used (0.6.12): 2 Intel and 1 Crypto to send each cycle
	g._set_builds(int(g.rig[P]), [])
	var before: Dictionary = (g.bank[P] as Dictionary).duplicate()
	step(g.PROD_CYCLE * 4.0 + 6.0)   # four cycles plus the trip home
	var trickle: float = (g.PROD_CYCLE * 4.0 + 6.0) * g.MAIN_INCOME
	var per_intel: float = 2.0 * one_cycle(n, "intel"); var per_cash: float = one_cycle(n, "cash")   # each cycle's output
	check(g._worker_counts(P, n).total == 2 and g._worker_counts(P).total == 2, "A Bot station's two workers have it as their station (%d here, %d in all)" % [int(g._worker_counts(P, n).total), int(g._worker_counts(P).total)])
	check(float(g.bank[P].intel) - float(before.intel) - trickle >= 4.0 * per_intel - 1.0 and float(g.bank[P].cash) - float(before.cash) - trickle >= 4.0 * per_cash - 1.0,
		"... and, working from the main node, carry the host's %s Intel and %s Crypto per cycle home (four cycles' worth, but for a unit on its way)" % [g._amt(per_intel), g._amt(per_cash)])
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
	g._cmd(["queue", "breach", 1])
	check(g._held(P, "breach") == 0, "No ready Breach copy before manufacture finishes")
	var creds_before: float = float(g.bank[P]["creds"])
	step(g.SIM_DT)   # the head charges its cost on the step it starts (before income can refill a capped bank)
	check(float(g.bank[P]["creds"]) < creds_before - float(g.CARDS.breach.make.creds) + 1.0, "Manufacturing charges the recipe cost up front (Credentials fell by Breach's price)")
	step(g._make_time("breach") + 1.0)
	check(g._held(P, "breach") == 1, "The queue's head becomes one ready Breach copy after its make time")


func security_and_firewall() -> void:   # there are no security levels; a Firewall holds defence cards that fire on their own
	fresh()
	var t := neutral_neighbour("iot")
	g.hosts[t].type = "server"
	g.cards[P] = {"breach": 1}
	var why: String = g._can_play(P, "breach", t)
	check(why == "", "Breach may target a server: there are no security levels (%s)" % ("ok" if why == "" else why))
	var n := own_pc()
	g._set_builds(n, ["intel", "wall"])
	check(g._sockets(n) == 3, "A Firewall adds 3 card sockets")
	g.cards[P] = {"patch": 1, "response": 1}
	g._play_card(P, "patch", n)
	check(g._held(P, "patch") == 0 and g._loaded(n).is_empty() and g._socket_res(n) == 1, "A Patch sent to a Firewall host travels there: a socket is held for it, nothing is loaded yet")
	step(3.0)
	check((g.hosts[n].sockets as Array).has("patch") and g._socket_res(n) == 0, "... and loads into that socket when it arrives")
	step(g.PROD_CYCLE + 0.1)
	check(bool(g.hosts[n].fw_on), "The Firewall is powered by its host's Intel (1 per cycle)")
	var R: int = g.RIVAL
	g._op_land(R, "breach", n, int(g.hosts[n].gen), {"id": 9001})
	var busy := false
	for e in g._execs: if int(e.target) == n: busy = true
	check(not busy and g._loaded(n).is_empty(), "The loaded Patch fires itself and stops a rival Breach the moment it starts")
	g._mark_scanned(R, n)   # the rival scouted it: its attacks land at full odds
	g._op_land(R, "phish", n, int(g.hosts[n].gen), {"id": 9002})
	check(g._phished(n), "With the socket used up, the next attack (Phishing) lands")
	g._play_card(P, "response", n)
	step(3.0)
	check(not g._phished(n) and g._loaded(n).is_empty(), "A defence card whose attack is already there acts on arrival instead of loading")
	g._set_builds(n, ["", "wall"])
	g.cards[P] = {"filter": 1}
	g.known[P]["filter"] = true
	g._play_card(P, "filter", n)
	step(3.0)   # it arrives and loads
	g.hosts[int(g.rig[P])].ddos_until = g._t + 60.0   # the main node is knocked out: no more Intel can come...
	step(3.0)   # ...once what is already on its way has landed
	g.hosts[n].store = {}   # and none is left on the host: the Firewall goes dark
	step(g.PROD_CYCLE + 0.1)
	check(not bool(g.hosts[n].fw_on), "Without Intel on its host (and none to bring) the Firewall switches off")
	g._mark_scanned(R, n)
	g._op_land(R, "ddos", n, int(g.hosts[n].gen), {"id": 9003})
	check(g._ddos_down(n) and (g.hosts[n].sockets as Array).has("filter"), "A switched-off Firewall does not fire: the DDoS lands, the Filter waits")


func recon_and_worm() -> void:
	fresh()
	var R: int = g.RIVAL
	var home: int = int(g.rig[P])
	var soft := []   # two neutral neighbours of your main node
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
	check(why == "", "Breach is playable on a reachable neighbour (%s)" % ("ok" if why == "" else why))
	g._mark_scanned(P, t)   # scouted: the baseline, a capture that runs its time succeeds
	var ok: bool = g._play_card(P, "breach", t)
	check(ok and g._held(P, "breach") == 0, "Playing Breach consumes the copy and launches an operation")
	step(float(g.CARDS["breach"].exec) + 12.0)   # travel + execution + margin (tests/capture_test.gd checks the exact timing)
	check(int(g.hosts[t].owner) == P, "The operation captures the host after travel and execution")


func firewall_eats_harvest_first() -> void:   # (0.6.14) a remote Firewall eats its host's Intel harvest before the storage is shared out
	fresh()
	g.bank[P] = {"intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	var n := own_pc()
	g._set_builds(n, ["intel", "cash", "wall"])
	var need: float = float(g.BUILD_KINDS.wall.use.intel)
	var room := one_cycle(n, "cash")   # room for the Miner's cycle only: the harvest the Firewall eats takes none
	g.hosts[n].store = {P: {"creds": g.STORE_CAP - room}}
	g.hosts[n].fw_on = true
	g._run_cycle(n)
	check(bool(g.hosts[n].fw_on) and g._st_get(n, P, "intel") < 0.0001 and absf(g._st_get(n, P, "cash") - room) < 0.0001 and g._store_total(n) <= g.STORE_CAP + 0.0001,
		"A storage with room for %s unit: the Firewall eats %s Intel of its host's harvest first (never stored), and the Miner gets the room, not a share cut by the Intel (%s, Firewall %s)"
		% [g._amt(room), g._amt(need), g._store_text(n), "on" if bool(g.hosts[n].fw_on) else "OFF"])
	fresh()   # the same host while its Crypto cannot ship (the bank is full): its storage clogs, its Firewall stays on
	g.bank[P] = {"intel": 40.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	n = own_pc()
	g._set_builds(n, ["intel", "cash", "wall"])
	g.hosts[n].fw_on = true
	var cycles := 0; var off := 0
	for k in int(round(g.PROD_CYCLE * 20.0 / g.SIM_DT)):
		g.bank[P].cash = g._cap(P, "cash")
		var left := float(g.hosts[n].cyc)
		g._sim_step(g.SIM_DT)
		if float(g.hosts[n].cyc) > left:
			cycles += 1
			if not bool(g.hosts[n].fw_on): off += 1
	check(cycles >= 19 and off == 0 and g._store_total(n) >= g.STORE_CAP - 0.5,
		"A host whose storage fills with Crypto its bank cannot take keeps its Firewall on with its own harvest: on in all %d cycles (off in %d; %s)" % [cycles, off, g._store_text(n)])


func room_held_for_cargo() -> void:   # (0.6.14) the room held for a Firewall's upkeep on its way stays free: the storage never goes over its cap
	fresh()
	g.bank[P] = {"intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	var n := own_pc()
	g._set_builds(n, ["cash", "cash", "wall"])   # no Intel made here: a worker brings the upkeep, holding its room on the way
	g.hosts[n].store = {P: {"creds": g.STORE_CAP - 2.0 * one_cycle(n, "cash")}}   # room for one cycle of the Miners
	g.hosts[n].fw_on = true
	g.hosts[n].cyc = 1.0   # the Miners run while the Intel is on its way
	var most := 0.0; var held := 0.0
	for k in int(round(6.0 / g.SIM_DT)):
		g.bank[P].cash = g._cap(P, "cash"); g.bank[P].creds = g._cap(P, "creds")   # nothing ships: the storage keeps what it gets
		g._sim_step(g.SIM_DT)
		most = maxf(most, g._store_total(n))
		held = maxf(held, g._inbound_total(n))
	check(held >= float(g.BUILD_KINDS.wall.use.intel) - 0.001 and g._st_get(n, P, "intel") >= float(g.BUILD_KINDS.wall.use.intel) - 0.001 and most <= g.STORE_CAP + 0.001 and not g._store_text(n).contains("%d/%d" % [int(g.STORE_CAP) + 1, int(g.STORE_CAP)]),
		"The Miners leave the room held for the Intel on its way: it lands and the storage holds at most %d (most %s; %s)" % [int(g.STORE_CAP), g._amt(most), g._store_text(n)])


func tight_counts_every_producer() -> void:   # (0.6.14) a host whose next cycle will not fit is 'about to fill up', whatever it makes
	fresh()
	var a := own_pc()
	g._set_builds(a, ["cash", "cred", "lab"])
	var gross := one_cycle(a, "cash") + one_cycle(a, "cred") + one_cycle(a, "lab")
	g.hosts[a].store = {P: {"creds": g.STORE_CAP - (gross - 1.0)}}   # room for all but one unit of its next cycle
	check(g._storage_tight(a), "A Miner, a Credential harvester and a Lab with room for %s of their %s units next cycle: the host is about to fill up, so its surplus goes first (room %s)"
		% [g._amt(gross - 1.0), g._amt(gross), g._amt(g._store_room(a))])
	g.hosts[a].store = {}
	check(not g._storage_tight(a), "...and with its storage empty it is not")


func crumbs_ride_home() -> void:   # (0.6.14) a shared cycle's fractions leave with the whole units: none stays on the host for good
	fresh()
	g.bank[P] = {"intel": 20.0, "cash": 20.0, "creds": 20.0, "research": 20.0}
	g._set_builds(int(g.rig[P]), ["bot", "bot"])   # plenty of workers: whatever can ship, ships
	var n := own_pc()
	var kinds := ["intel", "cash", "lab"]
	g._set_builds(n, kinds)
	g.hosts[n].store = {P: {"creds": g.STORE_CAP - 1.0}}   # room for one unit: each producer makes a third of its cycle
	g.hosts[n].cyc = 0.01
	step(0.1)
	var split := true
	for kind in kinds: split = split and absf(g._st_get(n, P, str(g.BUILD_KINDS[kind].out)) - one_cycle(n, kind) / (one_cycle(n, "intel") + one_cycle(n, "cash") + one_cycle(n, "lab"))) < 0.001
	step(g.PROD_CYCLE * 10.0)
	var crumbs := 0.0   # what of each material is not a whole unit
	for res in g.RES:
		var v: float = g._st_get(n, P, res)
		crumbs += absf(v - roundf(v))
	check(split and crumbs < 0.001, "After a cycle that left a third of a unit of each material, the crumbs ride home with the next whole units (%s; fractions left %s)" % [g._store_text(n), g._amt(crumbs)])


func stolen_goods_last_on_every_turn() -> void:   # (0.6.14) loot never wins an assignment, the fair fourth one included
	fresh()
	var a := own_pc()
	g._set_builds(a, ["cash"])
	var b := neutral_neighbour("pc")
	g._mark_served(P, a)   # your host was just served; the loot's host never was
	var lo := {"key": "l", "id": 1, "since": 0.0, "host": b, "purpose": "loot", "res": "intel", "qty": 3.0, "dir": "out"}
	var ex := {"key": "e", "id": 2, "since": 0.0, "host": a, "purpose": "export", "res": "cash", "qty": 1.0, "dir": "out"}
	var bl := {"key": "c", "id": 3, "since": 0.0, "host": a, "purpose": "build:1", "res": "intel", "qty": 1.0, "dir": "in"}
	var picks := []
	for turn in g.PRIORITY_TURNS + 1: picks.append(str(g._pick_request(P, [lo, ex], turn).purpose))
	for turn in g.PRIORITY_TURNS + 1: picks.append(str(g._pick_request(P, [lo, ex, bl], turn).purpose))
	check(not picks.has("loot"), "Stolen goods are the workers' last job on every turn, the fourth (fair) one too, with or without a project (%s)" % ", ".join(PackedStringArray(picks)))


func ready_full_head_holds_nothing() -> void:   # (0.6.14) a queue head that cannot start for a full Ready inventory keeps no price from research
	fresh()
	var price: Dictionary = g._recipe_cost("recon")
	g.bank[P] = {"intel": 40.0, "cash": 40.0, "creds": 40.0, "research": 40.0}
	for r in price: g.bank[P][r] = float(price[r])   # exactly its price: the bank holds it
	g.cards[P] = {"recon": g.READY_SLOTS}
	g._mq(P).append({"id": 999, "recipe": "recon", "paid": {}, "progress": 0.0})
	var rk := ""
	for k in g.RESEARCH:
		if not g._known(P, str(k)) and g._can_research(P, str(k)) == "": rk = str(k); break
	g.research_job[P] = {"key": rk, "progress": 0.0, "paused": false}
	for k in int(round(30.0 / g.SIM_DT)):
		for r in price: g.bank[P][r] = float(price[r])
		g._sim_step(g.SIM_DT)
	check(g._head_owed(P).is_empty() and float(g.research_job[P].get("progress", 0.0)) > 1.0 and not g._research_stall(P).contains("price"),
		"With the Ready inventory full (%d) the waiting Recon copy holds none of its price: research of %s uses the bank (%.0f s done; '%s')"
		% [g.READY_SLOTS, str(g.CARDS[rk].name), float(g.research_job[P].get("progress", 0.0)), g._research_stall(P)])


func idle_workers() -> Array:
	var out := []
	for wid in g.workers:
		if int(g.workers[wid].fac) == P and str(g.workers[wid].state) == "idle": out.append(int(wid))
	out.sort()
	return out


func plan_of(n: int) -> Dictionary:
	var owed: Dictionary = g._build_owed(P)
	return g._host_plan(n, P, g._supply_budget(P, owed), g._upkeep_extra(P, owed))


func firewall_host(kind: String, builds: Array, stock: float) -> int:   # a host next to your main node, its cycle held off, with this stock
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot", "bot"]); g._tick_teams(0.0)
	var n := own_pc()
	g.hosts[n].type = kind; g._set_builds(n, [])
	for k in int(round(25.0 / g.SIM_DT)):   # the workers gather at the main node
		g.hosts[n].cyc = 11.0
		g._sim_step(g.SIM_DT)
	g._set_builds(n, builds)
	g.hosts[n].store = {P: {"intel": stock}}
	g.hosts[n].fw_on = true; g.hosts[n].cyc = 11.0
	return n


func crumbs_bound_in_one_pass() -> void:   # (0.6.15) workers sent in one dispatch pass take no more than the plan spares:
	fresh()                                 # the crumbs ride with the last unit only out of what the Firewalls do not need
	g.bank[P] = {"intel": 0.0, "cash": 10.0, "creds": 10.0, "research": 10.0}
	var n := firewall_host("server", ["intel", "wall", "wall"], 2.5)
	var pl := plan_of(n)
	var hub: int = int(g.rig[P])
	var reqs: Array = g._open_requests(P, hub)
	var owed: Dictionary = g._build_owed(P)
	for wid in idle_workers():
		if not g._assign(P, hub, wid, reqs, owed): break
	var claimed: float = g._claimed(n, P, "intel")
	g._run_cycle(n)
	var st: float = float(g._store_of(n, P).get("intel", 0.0))
	check(float(pl.reserve.intel) > 0.0 and claimed <= float(pl.export.intel) + 0.001 and bool(g.hosts[n].fw_on) and g._claimed(n, P, "intel") <= st + 0.001,
		"Workers sent in one pass take %s of the %s Intel the plan spares, leaving the %s its Firewalls need: they stay on and no claim exceeds the stock" % [g._amt(claimed), g._amt(float(pl.export.intel)), g._amt(float(pl.reserve.intel))])


func phished_plan_keeps_upkeep() -> void:   # (0.6.15) a phished host's harvest is the thief's: your Intel there feeds its Firewall first,
	fresh()                                  # so your workers leave that much of it
	g.bank[P] = {"intel": 30.0, "cash": 30.0, "creds": 30.0, "research": 30.0}
	var n := firewall_host("pc", ["intel", "wall", ""], 2.0)
	g.hosts[n].steal_by = g.RIVAL; g.hosts[n].steal_until = g._t + 60.0
	var pl := plan_of(n)
	var need := float(g.BUILD_KINDS.wall.use.intel)
	var hub: int = int(g.rig[P])
	var reqs: Array = g._open_requests(P, hub)
	var owed: Dictionary = g._build_owed(P)
	for wid in idle_workers():
		if not g._assign(P, hub, wid, reqs, owed): break
	g._run_cycle(n)
	var st: float = float(g._store_of(n, P).get("intel", 0.0))
	check(float(pl.reserve.intel) >= need - 0.001 and bool(g.hosts[n].fw_on) and g._claimed(n, P, "intel") <= st + 0.001,
		"Phished, your stock there keeps the Firewall's %s Intel (kept %s): it stays on, and your workers' claims never exceed what is left" % [g._amt(need), g._amt(float(pl.reserve.intel))])
