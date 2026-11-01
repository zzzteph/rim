extends SceneTree
## RIM research–manufacture–deliver model: main-node income, PROD_CYCLE production cycles with host storage,
## Bot stations, bank caps, research unlock, manufacture into ready copies, no security levels,
## Firewall sockets that fire on their own, and a card capture end to end. 0.6.16 (a job moves one unit from its source
## straight to its destination, building strictly first): a station's workers start where it is and are free where they
## deliver; one dispatch pass takes exactly what a host's plan spares (a Firewall host that makes no upkeep keeps
## UPKEEP_KEEP cycles of it); a producing host's whole output reaches the bank with nobody free while a unit waits;
## a Firewall elsewhere is fed in every cycle while the workers ferry a site's bill, and no surplus leaves for the bank
## while the site lacks a unit; a Firewall fed by the trickle alone goes dark only when its Intel could not arrive.
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
	g.bank[P] = {}   # (0.6.18) a full base bank: the caps scale with the prices, so it stays plenty after a rescale
	for res in g.RES: g.bank[P][res] = float(g.BASE_CAP[res])


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
	upkeep_room_reserve()
	station_works_where_it_stands()
	one_host_flow()
	building_before_upkeep()
	trickle_fed_firewall()
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
	check(grew, "The main node delivers one of each resource every %s s locally (every bank grew ~%s in 10 s)" % [g._amt(1.0 / g.MAIN_INCOME), g._amt(10.0 * g.MAIN_INCOME)])


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
	# Equal producers make the same every cycle, also the last one that only partly fits (it fits what is left of STORE_CAP
	# after its whole cycles, fmod(STORE_CAP, gross): 2 of 3 units at 20): each holds STORE_CAP / 3, where filling the
	# storage in build order would give the harvester more.
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
	var hub: int = int(g.rig[P])
	g._set_builds(hub, ["intel", "bot"])   # a Bot station again: its two workers start collecting, and bring the upkeep
	# (0.6.18) no fixed 30 s: the backlog is a full storage and both hosts keep adding to it while the workers clear it.
	# Allow the time the station's spare capacity needs if every unit took a round trip from the main node (a direct
	# host-to-host leg only makes it sooner); it is drained the first moment under 2 units are left, so the 3 units a
	# cycle drops on it cannot hide a drained storage
	var upkeep := float(g.BUILD_KINDS.wall.use.intel)
	var moves: float = g.WORKERS_PER_STATION * g.WORKER_CARRY / (2.0 * maxf(g._leg_time(P, hub, n), g._leg_time(P, hub, m)))   # units a second
	var adds: float = (gross + one_cycle(m, "cash") + upkeep) / g.PROD_CYCLE   # units a second the two hosts give the workers
	var by: float = g.STORE_CAP / (moves - adds) if moves > adds else 0.0
	var t0: float = g._t
	var drained := -1.0
	for k in int(ceilf(by / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		if g._store_total(n) < 2.0 and bool(g.hosts[m].fw_on): drained = g._t - t0; break
	check(drained >= 0.0,
		"The main node's workers collect a host's storage and bring the Firewall its %s Intel per cycle: it is on again (after %.0f s, within the %.0f s a station moving %s unit/s needs while the hosts add %s/s; %s · %s)"
		% [g._amt(upkeep), drained, by, g._amt(moves), g._amt(adds), g._store_text(n), g._store_text(m)])


func stations() -> void:
	fresh()
	var n := own_pc()
	g._set_builds(n, ["intel", "intel", "cash", "bot"])   # nothing used (0.6.12): 2 Intel and 1 Crypto to send each cycle
	g._set_builds(int(g.rig[P]), [])
	var based := 0   # (0.6.16) a new station's workers start working where their station is
	for wid in g.workers:
		if int(g.workers[wid].fac) == P and int(g.workers[wid].home) == n and int(g.workers[wid].get("base", -1)) == n: based += 1
	var before: Dictionary = (g.bank[P] as Dictionary).duplicate()
	# four cycles plus the trip home: (0.6.18) the first a whole cycle away and the time to just before the fifth, not a fixed
	# 6 s more (at a 6-s cycle that ended on the fifth cycle, its output still in storage)
	g.hosts[n].cyc = g.PROD_CYCLE
	var secs: float = g.PROD_CYCLE * 5.0 - 0.5
	step(secs)
	var trickle: float = secs * g.MAIN_INCOME
	var per_intel: float = 2.0 * one_cycle(n, "intel"); var per_cash: float = one_cycle(n, "cash")   # each cycle's output
	check(g._worker_counts(P, n).total == g.WORKERS_PER_STATION and g._worker_counts(P).total == g.WORKERS_PER_STATION and based == g.WORKERS_PER_STATION,
		"A Bot station's %d workers have it as their station and start there (%d here, %d in all, %d started there)" % [g.WORKERS_PER_STATION, int(g._worker_counts(P, n).total), int(g._worker_counts(P).total), based])
	check(float(g.bank[P].intel) - float(before.intel) - trickle >= 4.0 * per_intel - 1.0 and float(g.bank[P].cash) - float(before.cash) - trickle >= 4.0 * per_cash - 1.0,
		"... and, free wherever they deliver, carry the host's %s Intel and %s Crypto per cycle home (four cycles' worth, but for a unit on its way)" % [g._amt(per_intel), g._amt(per_cash)])
	check(g._store_total(n) < 1.0, "With a station nothing waits in storage, even with no station at the main node")


func caps() -> void:
	fresh()
	var res := "cash"
	var cap: float = g._cap(P, res)
	g.bank[P][res] = cap - 1.0
	var fit: float = g._add_bank(P, res, g.CAP_PER_PRODUCER)   # (a producer's worth of cap, far more than the 1 unit of room)
	check(is_equal_approx(float(g.bank[P][res]), cap) and fit <= 1.0001, "A bank credit is clamped to its cap (cap = base + %s/producer)" % g._amt(g.CAP_PER_PRODUCER))


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
	check(bool(g.hosts[n].fw_on), "The Firewall is powered by its host's Intel (%s per cycle)" % g._amt(float(g.BUILD_KINDS.wall.use.intel)))
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


func stolen_goods_last_on_every_turn() -> void:   # (0.6.14) loot never wins an assignment; (0.6.16) the old fair fourth turn is gone:
	fresh()                                          # the turn no longer matters, building wins every pick it is in
	var a := own_pc()
	g._set_builds(a, ["cash"])
	var b := neutral_neighbour("pc")
	g._mark_served(P, a)   # your host was just served; the loot's host never was
	var lo := {"key": "l", "id": 1, "since": 0.0, "host": b, "purpose": "loot", "res": "intel", "qty": 3.0, "dir": "out"}
	var ex := {"key": "e", "id": 2, "since": 0.0, "host": a, "purpose": "export", "res": "cash", "qty": 1.0, "dir": "out"}
	var bl := {"key": "c", "id": 3, "since": 0.0, "host": a, "purpose": "build:1", "res": "intel", "qty": 1.0, "dir": "in"}
	var picks := []; var want := []
	var turns := 4   # (the old rule's cycle of three purpose turns and one fair turn)
	for turn in turns: picks.append(str(g._pick_request(P, [lo, ex], turn).purpose)); want.append("export")
	for turn in turns: picks.append(str(g._pick_request(P, [lo, ex, bl], turn).purpose)); want.append("build:1")
	check(not picks.has("loot"), "Stolen goods are the workers' last job on every turn, with or without a project (%s)" % ", ".join(PackedStringArray(picks)))
	check(picks == want, "Building strictly first: with a project in the candidates every pick is the project, whatever the turn; without one, the surplus (%s)" % ", ".join(PackedStringArray(picks)))


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


func dispatch_pass() -> void:   # one dispatch pass (0.6.16): every free worker takes the most useful job it can start soonest
	g._plan_cache = {}
	g._dispatch(P, int(g.rig[P]), idle_workers())


func plan_of(n: int) -> Dictionary:
	var owed: Dictionary = g._build_owed(P)
	return g._host_plan(n, P, g._supply_budget(P, owed), g._upkeep_extra(P, owed))


func firewall_host(kind: String, builds: Array, stock: float) -> int:   # a host next to your main node, its cycle held off, with this stock
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot", "bot"]); g._tick_teams(0.0)
	var n := own_pc()
	g.hosts[n].type = kind; g._set_builds(n, [])
	for k in int(round(25.0 / g.SIM_DT)):   # the workers gather at the main node
		g.hosts[n].cyc = g.PROD_CYCLE   # (0.6.18: a whole cycle away; a fixed 11 s was more than a cycle)
		g._sim_step(g.SIM_DT)
	g._set_builds(n, builds)
	g.hosts[n].store = {P: {"intel": stock}}
	g.hosts[n].fw_on = true; g.hosts[n].cyc = g.PROD_CYCLE
	return n


func crumbs_bound_in_one_pass() -> void:   # (0.6.15) workers sent in one dispatch pass take no more than the plan spares:
	fresh()                                 # the crumbs ride with the last unit only out of what the Firewalls do not need
	g.bank[P] = {"intel": 0.0, "cash": 10.0, "creds": 10.0, "research": 10.0}
	var n := firewall_host("server", ["intel", "wall", "wall"], 0.0)
	# (0.6.16) a Server's harvester makes 1.5 Intel a cycle, its two Firewalls eat 2: it does not make its own upkeep, so
	# it keeps UPKEEP_KEEP cycles of it within reach, its harvest and the rest of the stock (a fraction: the crumbs are
	# the Firewalls'); two whole units more are spare, fewer than the free workers
	var need := float(g.BUILD_KINDS.wall.use.intel) * 2.0
	var kept: float = (g.UPKEEP_KEEP + 1.0) * (need - one_cycle(n, "intel"))   # (UPKEEP_KEEP + 1 cycles of what it lacks)
	var spare: float = 2.0 * g.WORKER_CARRY
	g.hosts[n].store = {P: {"intel": kept + spare}}
	var pl := plan_of(n)
	var free := idle_workers().size()
	track_reset()
	dispatch_pass()
	track()
	var sent := 0   # workers sent to the host for its units
	for wid in legs:
		for l in legs[wid]:
			if str(l.trip) == "fetch" and int((l.job as Dictionary).get("src", -1)) == n: sent += 1
	var claimed: float = g._claimed(n, P, "intel")
	g._run_cycle(n)
	var st: float = float(g._store_of(n, P).get("intel", 0.0))
	check(kept - floorf(kept) > 0.001 and free > roundi(spare) and absf(float(pl.reserve.intel) - kept) < 0.001 and absf(float(pl.export.intel) - spare) < 0.001
		and absf(claimed - spare) < 0.001 and sent == roundi(spare / g.WORKER_CARRY) and idle_workers().size() == free - sent and bool(g.hosts[n].fw_on) and g._claimed(n, P, "intel") <= st + 0.001,
		"%d free workers in one pass take all %s Intel the plan spares and no crumb more, leaving the %s its Firewalls keep (%s cycles of the %s a cycle it lacks): one worker per unit goes (%d), they stay on and no claim exceeds the stock (took %s)"
		% [free, g._amt(float(pl.export.intel)), g._amt(float(pl.reserve.intel)), g._amt(g.UPKEEP_KEEP + 1.0), g._amt(need - one_cycle(n, "intel")), sent, g._amt(claimed)])


func phished_plan_keeps_upkeep() -> void:   # (0.6.15) a phished host's harvest is the thief's: your Intel there feeds its Firewall first,
	fresh()                                  # so your workers leave that much of it
	g.bank[P] = {"intel": 30.0, "cash": 30.0, "creds": 30.0, "research": 30.0}
	var need := float(g.BUILD_KINDS.wall.use.intel)
	var keep: float = need * g.UPKEEP_KEEP   # (0.6.16) the harvest is the thief's, so the host makes none of its upkeep: it keeps UPKEEP_KEEP cycles
	var n := firewall_host("pc", ["intel", "wall", ""], keep + g.WORKER_CARRY)   # and one unit more is spare
	g.hosts[n].steal_by = g.RIVAL; g.hosts[n].steal_until = g._t + 60.0
	var pl := plan_of(n)
	dispatch_pass()
	var claimed: float = g._claimed(n, P, "intel")
	g._run_cycle(n)
	var st: float = float(g._store_of(n, P).get("intel", 0.0))
	check(absf(float(pl.reserve.intel) - keep) < 0.001 and absf(claimed - g.WORKER_CARRY) < 0.001 and bool(g.hosts[n].fw_on) and g._claimed(n, P, "intel") <= st + 0.001,
		"Phished, your stock there keeps the Firewall's %s Intel for %s cycles (kept %s): one pass takes only the %s spare unit, the Firewall stays on, and your workers' claims never exceed what is left"
		% [g._amt(need), g._amt(g.UPKEEP_KEEP), g._amt(float(pl.reserve.intel)), g._amt(claimed)])


func upkeep_room_reserve() -> void:   # (0.6.19) a host whose Firewalls live on brought-in Intel keeps room for UPKEEP_KEEP cycles of it
	fresh()                            # in its storage, phished too, and it is 'about to fill up' before that room stops its producers
	var keep: float = g.UPKEEP_KEEP * float(g.BUILD_KINDS.wall.use.intel)   # one Firewall, no harvester: it lacks all of its upkeep
	var n := own_pc()
	g._set_builds(n, ["wall", "cash", "cred"]); g.hosts[n].fw_on = false
	var gross := one_cycle(n, "cash") + one_cycle(n, "cred")
	g.hosts[n].steal_by = g.RIVAL; g.hosts[n].steal_until = g._t + 120.0   # phished: the cycle's output is the thief's
	g.hosts[n].store = {g.RIVAL: {"cash": g.STORE_CAP - keep - gross}}       # room for one cycle beyond what the upkeep keeps
	g._run_cycle(n)
	var r1: float = g._store_room(n)
	g._run_cycle(n)
	check(absf(r1 - keep) < 0.001 and absf(g._store_room(n) - keep) < 0.001,
		"Phished, a Firewall host that makes no Intel keeps room for %s cycles of its upkeep: the thief's output fills only the rest (room %s, then %s)"
		% [g._amt(g.UPKEEP_KEEP), g._amt(r1), g._amt(g._store_room(n))])
	fresh()
	var m := own_pc()
	g._set_builds(m, ["wall", "wall", "cash"]); g.hosts[m].fw_on = false
	var keep2: float = g.UPKEEP_KEEP * 2.0 * float(g.BUILD_KINDS.wall.use.intel)
	g.hosts[m].store = {P: {"cash": g.STORE_CAP - keep2}}   # exactly the room its two Firewalls keep: the Miner would make nothing
	var share := float(g._cycle_split(m, P).share)
	check(share < 0.001 and g._tight_now(m), "Two Firewalls and a Miner, no Intel there: at %s stored the Miner stops (share %s), and the host is already 'about to fill up', so its surplus goes first"
		% [g._amt(g.STORE_CAP - keep2), g._amt(share)])


# ---- 0.6.16: every leg P's workers set off on ----
var legs := {}   # wid -> [{id, trip, from, to, cargo, purpose, job, t}]
var seen_legs := {}


func track_reset() -> void:   # from now on, record every new leg (legs already under way are not recorded)
	legs = {}; seen_legs = {}
	for f in g.flights: seen_legs[int(f.id)] = true


func track() -> void:
	for f in g.flights:
		if str(f.kind) != "courier" or int(f.owner) != P or seen_legs.has(int(f.id)): continue
		seen_legs[int(f.id)] = true
		var wid := int(f.wid)
		if not legs.has(wid): legs[wid] = []
		legs[wid].append({"id": int(f.id), "trip": str(f.trip), "from": int(f.route[0]), "to": int(f.dest), "cargo": (f.cargo as Dictionary).duplicate(),
			"purpose": str(f.get("purpose", "")), "job": (f.get("job", {}) as Dictionary).duplicate(), "t": float(g._t)})


func units(d: Dictionary) -> float:
	var n := 0.0
	for r in d: n += float(d[r])
	return n


func on_road(src: int) -> float:   # units riding P's couriers right now that left host src
	var n := 0.0
	for f in g.flights:
		if str(f.kind) == "courier" and int(f.owner) == P and int(f.get("src", -1)) == src: n += units(f.cargo)
	return n


func my_workers() -> Array:
	var out := []
	for wid in g.workers:
		if int(g.workers[wid].fac) == P: out.append(int(wid))
	out.sort()
	return out


func station_works_where_it_stands() -> void:   # (0.6.16) a new station's workers start where it is; each is free where it delivers
	fresh()
	var hub: int = int(g.rig[P])
	g._set_builds(hub, [])   # no other workers
	var n := own_pc()
	g.hosts[n].store = {P: {"intel": g.WORKER_CARRY, "cash": g.WORKER_CARRY}}   # a unit waiting for each of its two workers
	g.hosts[n].cyc = g.PROD_CYCLE   # (its next cycle is a whole cycle away)
	g._set_builds(n, ["intel", "cash", "bot"])
	var ids := my_workers()
	var at_station: bool = ids.size() == g.WORKERS_PER_STATION
	for wid in ids: at_station = at_station and int(g.workers[wid].home) == n and int(g.workers[wid].get("base", -1)) == n
	track_reset()
	step(g.SIM_DT)
	track()
	var first_ok := true
	for wid in ids:
		var ls: Array = legs.get(wid, [])
		first_ok = first_ok and ls.size() == 1 and str(ls[0].trip) == "carry" and int(ls[0].from) == n and int(ls[0].to) == hub and absf(units(ls[0].cargo) - g.WORKER_CARRY) < 0.001
	check(at_station and first_ok and g._claims_total(n) < 0.001 and g._store_total(n) < 0.001,
		"A new Bot station's %d workers start at their station and leave it loaded on the first step: no empty leg from the main node, nothing left there (%s)"
		% [ids.size(), g._store_text(n)])
	step(g._leg_time(P, n, hub) + 1.0)
	track()
	var home_ok := true
	for wid in ids: home_ok = home_ok and str(g.workers[wid].state) == "idle" and int(g.workers[wid].get("base", -1)) == hub and (legs.get(wid, []) as Array).size() == 1
	var got: float = float(g._ledger_sums(P).get("from:%d:intel" % n, 0.0)) + float(g._ledger_sums(P).get("from:%d:cash" % n, 0.0))
	check(home_ok and absf(got - ids.size() * g.WORKER_CARRY) < 0.001,
		"Each is free where it delivered, at the main node, and waits there while nothing is ready (no leg back empty): %s units reached the bank" % g._amt(got))


func one_host_flow() -> void:   # (0.6.16) a Credential harvester, a Miner and an Intel harvester on one host, one station at the main node:
	fresh()                       # the workers circulate between the two, nobody stays free while a unit waits, nothing is lost or made twice
	var hub: int = int(g.rig[P])
	g._set_builds(hub, ["bot"]); g._tick_teams(0.0)
	var n := own_pc()
	var kinds := ["cred", "cash", "intel"]
	g._set_builds(n, kinds)
	var gross := 0.0
	for kind in kinds: gross += one_cycle(n, kind)
	var ids := my_workers()
	var trips_needed: float = gross / g.WORKER_CARRY * 2.0 * g._leg_time(P, n, hub)   # worker-seconds a cycle's output takes home
	track_reset()
	var secs := 120.0
	var cycles := 0; var most := 0.0; var streak := {}; var worst := 0.0; var waited := 0.0; var busy := 0.0
	for k in int(round(secs / g.SIM_DT)):
		var left := float(g.hosts[n].cyc)
		g._sim_step(g.SIM_DT)
		if float(g.hosts[n].cyc) > left: cycles += 1
		most = maxf(most, g._store_total(n))
		track()
		var waiting: bool = g._spare_total(n, P) >= 0.999   # a whole unit nobody is on the way for
		for wid in ids:
			if str(g.workers[wid].state) != "idle": busy += g.SIM_DT; streak[wid] = 0.0; continue
			if waiting: streak[wid] = float(streak.get(wid, 0.0)) + g.SIM_DT; waited += g.SIM_DT
			else: streak[wid] = 0.0
			worst = maxf(worst, float(streak[wid]))
	var off_path := 0; var taken := 0.0; var empty_back := 0; var loaded := 0; var wasted := 0; var homes := 0
	for wid in legs:
		var ls: Array = legs[wid]
		for k in ls.size():
			var l: Dictionary = ls[k]
			if not ((int(l.from) == n and int(l.to) == hub) or (int(l.from) == hub and int(l.to) == n)): off_path += 1
			if str(l.trip) == "carry" and int(l.from) == n: taken += units(l.cargo); loaded += 1
			if str(l.trip) == "home": homes += 1
			if str(l.trip) == "fetch" and int(l.to) == n:
				empty_back += 1
				if k + 1 < ls.size() and not (str(ls[k + 1].trip) == "carry" and int(ls[k + 1].from) == n and units(ls[k + 1].cargo) > 0.0001): wasted += 1   # it found nothing
	var made: float = cycles * gross
	var lost: float = 0.0
	for res in g.RES: lost += float(g._ledger_sums(P).get("lost:cargo:%s" % res, 0.0))
	check(cycles >= int(secs / g.PROD_CYCLE) - 1 and most < g.STORE_CAP - 0.001,
		"Production never stops: the host's storage never fills in %d cycles (most %s of %d)" % [cycles, g._amt(most), int(g.STORE_CAP)])
	check(off_path == 0 and loaded >= 1 and wasted == 0 and homes == 0 and absf(made - taken - g._store_total(n)) < 0.001 and lost < 0.001,
		"Every leg runs between the host and the main node, loaded on the way home (%d loaded legs, %d back for more, %d that found nothing, %d home empty): the %s units made are the %s taken plus the %s still stored (%s on the road), none lost"
		% [loaded, empty_back, wasted, homes, g._amt(made), g._amt(taken), g._amt(g._store_total(n)), g._amt(on_road(n))])
	var limit: float = g.LOGI_EVERY + 2.0 * g.SIM_DT   # (a free worker is dealt a job the step a unit is made, or at the next planning pass)
	check(worst <= limit,
		"No worker stays free more than %.2f s while a unit waits (longest %.2f s, %.1f worker-s in all); the %d workers are on the road %.0f%% of the time for the %.1f worker-s a cycle's output takes"
		% [limit, worst, waited, ids.size(), 100.0 * busy / (secs * ids.size()), trips_needed])


func building_before_upkeep() -> void:   # (0.6.20) building comes strictly first, before a Firewall's upkeep too (research, then supplies, then output)
	fresh(); fat_bank()
	var hub: int = int(g.rig[P])
	g._set_builds(hub, ["bot"]); g._tick_teams(0.0)   # one station: two workers for a big bill and an upkeep
	var e := own_pc()
	g._set_builds(e, ["cash", "wall"])   # a Miner and a Firewall, no Intel made there: its upkeep is brought
	g.hosts[e].store = {}; g.hosts[e].fw_on = true
	var b := own_pc()
	g._set_builds(b, [])
	g._start_job(b, "wall", 0); g._start_job(b, "lab", 1)   # a big bill the bank holds: building for several cycles
	var bill := 0.0
	for kind in ["wall", "lab"]: bill += units(g._build_cost(kind))
	var ids := my_workers()
	# (0.6.18) no fixed 150 s: the bill scales with the prices. Allow twice the bare ferrying time, a round trip from the
	# main node per unit shared by the workers, for the upkeep and the Miner's Crypto share the same workers
	var ferry: float = bill / g.WORKER_CARRY * 2.0 * g._leg_time(P, hub, b) / float(maxi(1, ids.size()))
	track_reset()
	var t0: float = g._t
	var covered := -1.0; var cycles := 0; var fed := 0; var worst := 0.0; var streak := {}; var exports := 0
	for k in int(ceilf(2.0 * ferry / g.SIM_DT)):
		var left := float(g.hosts[e].cyc)
		g._sim_step(g.SIM_DT)
		track()
		var short := false   # a unit of the site's bill nobody is on the way with, that the bank has
		for slot in (g.hosts[b].jobs as Dictionary):
			for res in g.RES:
				if g._job_short(g.hosts[b].jobs[slot], res) > 0.0001 and g._free(P, res) >= g.WORKER_CARRY: short = true
		if not short: covered = g._t; break
		if float(g.hosts[e].cyc) > left:
			cycles += 1
			if bool(g.hosts[e].fw_on): fed += 1
		for wid in legs:
			var ls: Array = legs[wid]
			var l: Dictionary = ls[ls.size() - 1]
			if absf(float(l.t) - g._t) > 0.0001: continue
			if int((l.job as Dictionary).get("dst", -1)) == hub or (str(l.trip) == "carry" and int(l.to) == hub): exports += 1   # surplus on its way to the bank
		for wid in ids:
			if g.workers.has(wid) and str(g.workers[wid].state) == "idle": streak[wid] = float(streak.get(wid, 0.0)) + g.SIM_DT
			else: streak[wid] = 0.0
			worst = maxf(worst, float(streak[wid]))
	var upkeep_legs := 0; var e_to_site := 0.0
	for wid in legs:
		for l in legs[wid]:
			if str(l.trip) == "carry" and int(l.to) == e and float(l.cargo.get("intel", 0.0)) > 0.0: upkeep_legs += 1
			if str(l.trip) == "carry" and int(l.from) == e and int(l.to) == b: e_to_site += float(l.cargo.get("cash", 0.0))
	var after := 0; var fed_after := 0   # once the bill is out, the Firewall is supplied again
	for k in int(ceilf((3.0 * g.PROD_CYCLE + 2.0 * g._leg_time(P, hub, e)) / g.SIM_DT)):
		var left2 := float(g.hosts[e].cyc)
		g._sim_step(g.SIM_DT)
		if float(g.hosts[e].cyc) > left2:
			after += 1
			if bool(g.hosts[e].fw_on): fed_after += 1
	check(covered >= 0.0 and upkeep_legs == 0 and after >= 2 and fed_after >= after - 1,
		"While the %d workers ferry a %s-unit bill to a site (%.0f s until all of it was there or on its way), none brings the Firewall elsewhere its Intel (%d legs: building first; it ate in %d of %d cycles); then it is fed again (%d of the next %d cycles)"
		% [ids.size(), g._amt(bill), covered - t0, upkeep_legs, fed, cycles, fed_after, after])
	var limit: float = g.LOGI_EVERY + 2.0 * g.SIM_DT   # (a free worker is dealt a job the step it is free, or at the next planning pass)
	check(covered >= 0.0 and exports == 0 and worst <= limit,
		"Building strictly first: no surplus set off for the bank while the site lacked a unit the bank had (%d did; the Miner's Crypto went only to the site, %s of it, or waits: %s), and no worker stayed free more than %.2f s meanwhile (longest %.2f s)"
		% [exports, g._amt(e_to_site), g._store_text(e), limit, worst])


func trickle_fed_firewall() -> void:   # (0.6.16) a Firewall fed by the main node's trickle alone goes dark only in a cycle its Intel could not reach
	fresh()
	var hub: int = int(g.rig[P])
	g._set_builds(hub, ["bot"]); g._tick_teams(0.0)   # no Intel harvester anywhere: the bank's Intel is the trickle, MAIN_INCOME x PROD_CYCLE a cycle
	g.bank[P].intel = 0.0
	var n := own_pc()
	g._set_builds(n, ["cash", "cash", "wall"])   # two Miners and a Firewall: no Intel made there
	g.hosts[n].fw_on = true
	var need := float(g.BUILD_KINDS.wall.use.intel)
	var lead: float = 2.0 * g._leg_time(P, hub, n) + 0.5   # (time a free worker needs to reach the bank and bring the unit, with a margin)
	var cycles := 0; var fed := 0; var avoidable := 0; var could := -1.0; var first := ""
	for k in int(round(120.0 / g.SIM_DT)):
		var left := float(g.hosts[n].cyc)
		g._sim_step(g.SIM_DT)
		if float(g.hosts[n].cyc) > left:
			cycles += 1
			if bool(g.hosts[n].fw_on): fed += 1
			elif could >= 0.0:
				avoidable += 1
				if first == "": first = "dark at %.1f s, a cycle's Intel within reach and a worker free since %.1f s" % [g._t, could]
			could = -1.0
			continue
		var within: float = g._store_free(n, P, "intel") + g._inbound(n, "intel") + g._free(P, "intel")   # its storage, on its way, the bank
		if could < 0.0 and within >= need - 0.0001 and float(g.hosts[n].cyc) >= lead and int(g._worker_counts(P).idle) > 0: could = g._t
	# (fixed in 0.6.16; this check guards it. Before the fix:) _open_requests adds every host's plan export under an EMPTY budget to spare_intel, and with no budget
	# this host's own Firewall cannot run, so its own stock is "spare": its upkeep request becomes the bank's Intel PLUS its
	# own stock (always above what the bank holds), a fraction of the bank can never serve it (_best_delivery wants a whole
	# unit or the request's last fraction), and the two free workers wait for a whole unit that comes too late
	check(cycles >= int(120.0 / g.PROD_CYCLE) - 1 and avoidable == 0,
		"A Firewall fed only by the trickle (%s Intel a cycle, its upkeep %s) goes dark only in a cycle its Intel could not reach: fed in %d of %d cycles, %d dark although its storage and the bank held a cycle's Intel and a worker was free %.1f s before (%s)"
		% [g._amt(g.MAIN_INCOME * g.PROD_CYCLE), g._amt(need), fed, cycles, avoidable, lead, first if first != "" else "none"])
