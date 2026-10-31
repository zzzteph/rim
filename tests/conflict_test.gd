extends SceneTree
## The 0.6.13 conflict rules: a Patch that stops an intrusion leaves its host open for 30 s (no Patch played, armed or
## loaded there; one on its way returns to the hand; a loaded one still fires and restarts the window; public and in the
## lockstep fingerprint); a main node under DDoS takes no card from its owner; the captor of a main node inherits the
## loser's network with its buildings; Sabotage also stops the hit hosts' station workers; Phishing and Siphon last
## longer; stolen goods are the thief's workers' last job; Worm is a Known exploit that moves on, its second stage
## scouted when the first was.
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


func fresh(seed := 7) -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = seed; g._opt_shape = "grid"
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


func run() -> void:
	patch_recovery()
	ddos_main_node()
	inheritance()
	theft_and_sabotage()
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


func inheritance() -> void:
	fresh()
	var their: int = int(g.rig[R])
	var hs := []
	for nb in g.hosts[their].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL and hs.size() < 2:
			g._capture(int(nb), R); g._set_builds(int(nb), ["bot", "intel", "cash"]); hs.append(int(nb))
	g._tick_teams(0.0)
	check(hs.size() == 2, "Setup: the rival holds two more hosts with buildings")
	g._capture(their, P)   # you take its main node
	step(0.2)
	check(g._eliminated.has(R), "Taking the rival's main node eliminates it")
	var ok := true
	for i in hs: ok = ok and int(g.hosts[i].owner) == P and g.hosts[i].builds.has("intel") and g.hosts[i].builds.has("cash")
	check(ok, "Its other hosts are now yours, with their finished buildings")
	step(1.0)
	var staffed := 0
	for i in hs: staffed += int(g._worker_counts(P, i).total)
	check(staffed == 2 * g.WORKERS_PER_STATION, "Their Bot stations staff themselves for you (%d workers)" % staffed)


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
