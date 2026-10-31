extends SceneTree
## The 0.6.13 conflict rules: a Patch that stops an intrusion leaves its host open for 30 s (no Patch played, armed or
## loaded there; one on its way returns to the hand; a loaded one still fires and restarts the window; public and in the
## lockstep fingerprint); a main node under DDoS takes no card from its owner; the captor of a main node inherits the
## loser's network with its buildings; Sabotage also stops the hit hosts' station workers; Phishing and Siphon last
## longer; stolen goods are the thief's workers' last job; Worm is a Known exploit that moves on, its second stage
## scouted when the first was.
## 0.6.14: an eliminated thief's siphons stop and what its Phishing diverted is the owner's again at once; the Patch
## recovery window shows on rival hosts (effects, map label, attack preview); a defence that cannot be played previews
## nothing, and the DDoS and Filter texts say a Filter cannot clear a DDoS on a main node; siphon, Filter, Cargo cover
## and a cargo's cover are in the lockstep fingerprint; inheriting a network is announced and logged.
## godot --headless --path . --script tests/conflict_test.gd
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


func fresh(seed := 7, enemies := 1) -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = enemies; g._opt_seed = seed; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER; R = g.RIVAL
	for f in [P, R]: g.bank[f] = {"intel": 200.0, "cash": 200.0, "creds": 200.0, "research": 200.0}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func neighbour_of(i: int, owner: int) -> int:
	for nb in g.hosts[i].links:
		if int(g.hosts[int(nb)].owner) == owner: return int(nb)
	return -1


func intrusion(fac: int, card: String, t: int) -> Dictionary:   # an intrusion that starts executing on t now
	var e := {"id": 9000 + checks, "fac": fac, "card": card, "effect": str(g.CARDS[card].effect), "target": t, "gen": int(g.hosts[t].gen), "ends": g._t + g._exec_time(card, t), "stage": 1, "victim": int(g.hosts[t].owner), "seen": [t]}
	g._start_exec(e)
	return e


func preview(fac: int, key: String, t: int) -> String:
	var s := ""
	for l in g._target_preview(fac, key, t).lines: s += str(l[0]) + "\n"
	return s


func units(d: Dictionary) -> float:
	var n := 0.0
	for res in d: n += float(d[res])
	return n


func run() -> void:
	patch_recovery()
	recovery_public()
	ddos_main_node()
	ddos_texts()
	inheritance()
	eliminated_thief()
	theft_and_sabotage()
	fingerprint()
	worm()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func patch_recovery() -> void:
	fresh()
	var home: int = int(g.rig[P])
	g.cards[P] = {"patch": 3}
	intrusion(R, "breach", home)
	check(g._can_play(P, "patch", home) == "", "Setup: a Patch may be played on your main node while a Breach runs there")
	var hash0: String = g._mp_hash()
	g._play_card(P, "patch", home)
	check(g._execs.is_empty() and g._patch_recovering(home), "A Patch stops the Breach, and the host starts its 30 s of recovery")
	check(g._mp_hash() != hash0, "The recovery is part of the lockstep fingerprint")
	var why: String = g._can_play(P, "patch", home)
	check(why.contains("no Patch for"), "Meanwhile no other Patch can be played there (%s)" % why)
	check(str(g._effects_line(home)).contains("Patch recover"), "The window is public: the host's effects say so (%s)" % str(g._effects_line(home)))
	g.hosts[home].builds[2] = "wall"; g.hosts[home].sockets = ["patch", "", ""]; g.hosts[home].fw_on = true
	var until0: float = float(g.hosts[home].patch_recover_until)
	step(5.0)
	intrusion(R, "breach", home)
	check(g._execs.is_empty() and (g.hosts[home].sockets as Array).count("patch") == 0, "A Patch already loaded in the Firewall still fires during the window")
	check(float(g.hosts[home].patch_recover_until) > until0 + 4.0, "...and restarts it")
	# a Patch on its way to a host that starts recovering goes back to the hand
	var h := neighbour_of(home, g.NEUTRAL)
	g._capture(h, P)
	var held: int = g._held(P, "patch")
	g._play_card(P, "patch", h)
	check(g._held(P, "patch") == held - 1, "Setup: a Patch sets off for another host of yours")
	g.hosts[h].patch_recover_until = g._t + 30.0   # a Patch there just stopped something
	step(6.0)
	check(g._held(P, "patch") == held, "Arriving while that host recovers, it cannot act: it is back in your hand")


func recovery_public() -> void:   # (0.6.14) the window is public: the attacker, who gains from it, sees it too
	fresh()
	g.cards[P] = {"breach": 1}
	var t := neighbour_of(int(g.rig[P]), g.NEUTRAL)
	g._capture(t, R)   # a rival host next to your main node: in sight, never scouted
	g.hosts[t].patch_recover_until = g._t + float(g.CARDS.patch.dur)   # a Patch there just stopped something
	var fx: String = g._effects_line(t)
	var sub := str(g._node_sub(t, true)[0])
	check(not g._known_host(P, t) and fx.contains("Patch recover") and sub.begins_with("NO PATCH"), "A rival's Patch recovery shows on an unscouted host: its effects (%s) and its map label (%s)" % [fx, sub])
	var pv := preview(P, "breach", t)
	check(pv.contains("no Patch can be played on it"), "...and in the attack preview, Recon or not")
	g._mark_scanned(P, t)
	sub = str(g._node_sub(t, true)[0])
	check(g._known_host(P, t) and sub.begins_with("NO PATCH") and preview(P, "breach", t).contains("no Patch can be played on it"), "Scouted, the map label (%s) and the preview still show it" % sub)


func ddos_main_node() -> void:
	fresh()
	var home: int = int(g.rig[P])
	g.cards[P] = {"patch": 2, "response": 1}
	g.hosts[home].ddos_until = g._t + 20.0
	check(g._can_play(P, "patch", home).contains("under DDoS") and g._can_play(P, "response", home).contains("under DDoS"), "While your main node is under DDoS you can play no card on it")
	g.hosts[home].patch_armed_until = g._t + 30.0   # a Patch armed before the DDoS
	intrusion(R, "breach", home)
	step(16.0)
	check(int(g.hosts[home].owner) == P, "A Patch armed before it still stops a Breach there")
	g.hosts[home].ddos_until = 0.0
	check(g._can_play(P, "patch", home) == "" or g._can_play(P, "patch", home).contains("no Patch for"), "Once it ends, cards may be played there again")


func ddos_texts() -> void:   # (0.6.14) nothing clears a DDoS on your main node by hand, and no text says otherwise
	fresh()
	var home: int = int(g.rig[P])
	g.cards[P] = {"filter": 1}
	g.hosts[home].ddos_until = g._t + float(g.CARDS.ddos.dur)
	var pv := preview(P, "filter", home)
	check(pv.contains("under DDoS") and not pv.contains(str(g.CARDS.filter.lead)) and not pv.contains("Takes effect"), "A Filter on your DDoSed main node is refused, and its preview promises nothing:\n%s" % pv)
	var said := ""
	for s in str(g.CARDS.ddos.rules).split(". "):
		if s.contains("filter"): said = s
	check(said.contains("main node") and str(g.CARDS.filter.rules).contains("main node is under DDoS"), "The DDoS text (%s) and the Filter text say a Filter cannot clear a DDoS on a main node" % said)


func inheritance() -> void:
	fresh()
	var their: int = int(g.rig[R])
	var hs := []
	for nb in g.hosts[their].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL and hs.size() < 2:
			g._capture(int(nb), R); g._set_builds(int(nb), ["bot", "intel", "cash"]); hs.append(int(nb))
	g._tick_teams(0.0)
	check(hs.size() == 2, "Setup: the rival holds two more hosts with buildings")
	var others := -1   # what you inherit: every host it holds but its main node
	for i in g.hosts.size(): others += int(int(g.hosts[i].owner) == R)
	g._capture(their, P)   # you take its main node
	var news := "%d other hosts are yours" % others
	var logged := false
	for e in g.events: logged = logged or (str(e.key) == "elim:%d" % R and str(e.text).contains(news))
	check(str(g._msg).contains(news) and logged, "You are told, over the capture message, and the Logs record that its %d other hosts are yours (%s)" % [others, str(g._msg)])
	step(0.2)
	check(g._eliminated.has(R), "Taking the rival's main node eliminates it")
	var ok := true
	for i in hs: ok = ok and int(g.hosts[i].owner) == P and g.hosts[i].builds.has("intel") and g.hosts[i].builds.has("cash")
	check(ok, "Its other hosts are now yours, with their finished buildings")
	step(1.0)
	var staffed := 0
	for i in hs: staffed += int(g._worker_counts(P, i).total)
	check(staffed == 2 * g.WORKERS_PER_STATION, "Their Bot stations staff themselves for you (%d workers)" % staffed)


func eliminated_thief() -> void:   # (0.6.14) a botnet that is out steals nothing more from the survivors
	fresh(7, 2)
	var R2: int = g.RIVAL2
	var home: int = int(g.rig[P])
	var h := neighbour_of(home, g.NEUTRAL)
	g._capture(h, P); g._set_builds(h, ["cash", "cash", "cash"])
	step(15.0)   # its Crypto is on the move to your main node
	g.hosts[h].siphon = {"by": R, "res": "cash", "since": g._t, "until": g._t + float(g.CARDS.siphon.dur), "left": int(g.CARDS.siphon.cargo)}   # as it lands
	g._capture(int(g.rig[R]), R2)   # another rival takes R's main node: R is out
	check(g._eliminated.has(R) and (g.hosts[h].siphon as Dictionary).is_empty(), "An eliminated thief's Packet siphon stops at once")
	g.hosts[h].siphon = {"by": R, "res": "cash", "since": g._t, "until": g._t + float(g.CARDS.siphon.dur), "left": int(g.CARDS.siphon.cargo)}   # one left behind
	step(30.0)
	var taken := float((g._econ_rates(P, "cash").lost_by as Dictionary).get("siphoned", 0.0))
	var sent := float((g._econ_rates(P, "cash").in_by as Dictionary).get("delivered", 0.0))
	check(sent > 0.0 and taken == 0.0 and not (g.hosts[h].get("loot", {}) as Dictionary).has(R), "...and a siphon of a botnet that is out takes nothing (%.1f/min taken; your Crypto arrives at %.1f/min)" % [taken, sent])
	fresh(7, 2)
	R2 = g.RIVAL2
	home = int(g.rig[P])
	h = neighbour_of(home, g.NEUTRAL)
	g._capture(h, P); g._set_builds(h, ["intel", "cash", "cred"])
	step(3.0)
	g.hosts[h].steal_by = R; g.hosts[h].steal_until = g._t + float(g.CARDS.phish.dur)   # R's Phishing lands
	step(30.0)
	var stolen := units(g.hosts[h].store.get(R, {}))
	var total: float = g._store_total(h)
	g._capture(int(g.rig[R]), R2)
	var back := units(g.hosts[h].store.get(P, {}))
	check(stolen > 0.0 and not (g.hosts[h].store as Dictionary).has(R) and absf(g._store_total(h) - total) < 0.001 and back >= stolen - 0.001 and int(g.hosts[h].steal_by) == -1 and not g._phished(h),
		"When the thief is eliminated its Phishing ends, and the %.1f units it diverted are yours again at once (storage %.1f of %d)" % [stolen, g._store_total(h), int(g.STORE_CAP)])
	step(30.0)
	check(g._store_total(h) < g.STORE_CAP - 0.001, "...so the host's storage ships and does not stay full of goods nobody collects (%.1f of %d)" % [g._store_total(h), int(g.STORE_CAP)])


func theft_and_sabotage() -> void:
	check(float(fresh_card("phish").dur) == 180.0 and float(g.CARDS.siphon.dur) == 60.0, "Phishing lasts 180 s, Packet siphon 60 s")
	fresh()
	var home: int = int(g.rig[P])
	var h := neighbour_of(home, g.NEUTRAL)
	g._capture(h, P); g._set_builds(h, ["bot", "intel", ""]); g._tick_teams(0.0)
	step(4.0)   # its workers reach the main node
	g.hosts[h].sabot_until = g._t + 30.0
	step(2.0)
	var blocked := 0
	for wid in g.workers:
		if int(g.workers[wid].home) == h and g._worker_state(int(wid)) == "blocked": blocked += 1
	var away := 0
	for f in g.flights:
		if str(f.kind) == "courier" and int(g.workers.get(int(f.get("wid", -1)), {}).get("home", -1)) == h: away += 1
	check(blocked + away == g.WORKERS_PER_STATION and blocked >= 1, "Sabotage stops the station's workers: free ones stay put, blocked (%d blocked, %d finishing a leg)" % [blocked, away])
	var reqs := [{"key": "a", "id": 1, "since": 0.0, "host": h, "purpose": "loot", "res": "intel", "qty": 3.0, "dir": "out", "amt": 1.0},
		{"key": "b", "id": 2, "since": 0.0, "host": h, "purpose": "export", "res": "intel", "qty": 3.0, "dir": "out", "amt": 1.0}]
	check(str(g._pick_request(P, reqs, 0, {}).purpose) == "export" and str(g._pick_request(P, reqs, 0, {"intel": 5.0}).purpose) == "export", "Stolen goods are the workers' last job, even when building waits for that material")


func fingerprint() -> void:   # (0.6.14) every timed state the sim reads is in the lockstep fingerprint
	fresh()
	var home: int = int(g.rig[P])
	var h := neighbour_of(home, g.NEUTRAL)
	g._capture(h, P); g._set_builds(h, ["intel", "cash", ""])
	var cargo := {}
	for k in 60:   # until a worker is on the road with its output
		step(0.5)
		for f in g.flights:
			if str(f.kind) == "courier": cargo = f
		if not cargo.is_empty(): break
	var h0: String = g._mp_hash()
	var moved := []
	g.hosts[h].siphon = {"by": R, "res": "cash", "since": g._t, "until": g._t + float(g.CARDS.siphon.dur), "left": int(g.CARDS.siphon.cargo)}
	if g._mp_hash() != h0: moved.append("siphon")
	var h1: String = g._mp_hash()
	g.hosts[h].siphon.left = int(g.CARDS.siphon.cargo) - 1   # what it may still take
	if g._mp_hash() != h1: moved.append("siphon left")
	g.hosts[h].siphon = {}
	g.hosts[h].filter_until = g._t + float(g.CARDS.filter.dur)
	if g._mp_hash() != h0: moved.append("filter_until")
	g.hosts[h].filter_until = 0.0
	g.hosts[h].cover_until = g._t + float(g.CARDS.cover.dur)
	if g._mp_hash() != h0: moved.append("cover_until")
	g.hosts[h].cover_until = 0.0
	if not cargo.is_empty():
		cargo.covered = not bool(cargo.get("covered", false))
		if g._mp_hash() != h0: moved.append("covered")
		cargo.covered = not bool(cargo.covered)
	check(moved == ["siphon", "siphon left", "filter_until", "cover_until", "covered"] and g._mp_hash() == h0, "A Packet siphon (and what it may still take), a Filter, a Cargo cover and a cargo's cover each change the lockstep fingerprint (%s)" % ", ".join(PackedStringArray(moved)))


func fresh_card(k: String) -> Dictionary:
	fresh()
	return g.CARDS[k]


func worm() -> void:
	fresh()
	check(float(g.CARDS.worm.exec) == float(g.CARDS.exploit.exec) and float(g.CARDS.worm.exec_rig) == float(g.CARDS.exploit.exec_rig), "A Worm stage executes as long as a Known exploit (%s s, %s s on a main node)" % [str(g.CARDS.worm.exec), str(g.CARDS.worm.exec_rig)])
	var scouted_next := false; var tried := 0
	for seed in [3, 5, 7, 9, 11, 13, 17, 19, 23, 29]:
		fresh(seed)
		var home: int = int(g.rig[P])
		var t := neighbour_of(home, g.NEUTRAL)
		if t < 0: continue
		var nxt := -1
		for nb in g.hosts[t].links:
			if int(g.hosts[int(nb)].owner) == g.NEUTRAL: nxt = int(nb); break
		if nxt < 0: continue
		g._mark_scanned(P, t)
		var e := intrusion(P, "worm", t)
		e.ends = g._t
		step(0.1)
		tried += 1
		if int(g.hosts[t].owner) == P:
			for e2 in g._execs:
				if int(e2.fac) == P and str(e2.card) == "worm" and int(e2.stage) == 2: scouted_next = g._recon_fresh(P, int(e2.target))
			break
	check(scouted_next, "After a first stage on fresh Recon, the second stage counts as scouted (%d tries)" % tried)
