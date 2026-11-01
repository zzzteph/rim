extends SceneTree
## Theft must arrive: Phishing, Packet siphon and Vault raid bring their loot home through your own network,
## in the amounts the cards promise, from targets that are not next to your main node. DDoS hits three hosts.
## 0.6.14: a pile is claimed once (one unit draws one worker); your own salvage ranks with your exports while stolen
## goods stay the workers' last job on every turn; a Worm's second stage is scouted from a snapshot taken after a loaded
## Patch there fired, and its preview promises that only when the Recon is still fresh as the first stage resolves.
## godot --headless --path . --script tests/theft_test.gd
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
	g.rolls_always_hit = true   # these checks are about what each card does; recon_test covers the odds
	g._open_menu(false)
	P = g.PLAYER; R = g.RIVAL
	for fac in [P, R]:   # only the main nodes' built-in income (and their two workers): every other gain is the theft being measured
		for i in g.hosts.size():
			if int(g.hosts[i].owner) == fac: g._set_builds(i, (["bot", "bot", "bot"] if fac == P else ["bot"]) if i == int(g.rig[fac]) else [])   # your six workers carry the loot
		g.bank[fac] = {"intel": 0.0, "cash": 0.0, "creds": 0.0, "research": 0.0}
	g._tick_teams(0.0)


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func path_avoiding(a: int, b: int, avoid: int) -> Array:   # a shortest link path a..b that crosses no host of `avoid`
	var prev := {a: a}; var q := [a]; var head := 0
	while head < q.size():
		var c: int = q[head]; head += 1
		if c == b: break
		for o in g.hosts[c].links:
			var n := int(o)
			if prev.has(n) or (n != b and int(g.hosts[n].owner) == avoid): continue
			prev[n] = c; q.append(n)
	if not prev.has(b): return []
	var p := [b]
	while int(p[-1]) != a: p.append(prev[p[-1]])
	p.reverse()
	return p


func reach(target: int) -> void:   # the player takes the hosts leading up to target, so a card can get there, and scouts it
	var path := path_avoiding(int(g.rig[P]), target, R)
	for k in range(1, path.size() - 1):
		if int(g.hosts[path[k]].owner) != P: g._capture(path[k], P)
	g._mark_scanned(P, target)   # fresh Recon: these checks are about what the theft does, at full odds (recon_test covers the odds)


func rival_outpost() -> int:   # a rival host next to its main node, given an Intel harvester (rate × host multiplier a cycle, no input)
	var home: int = int(g.rig[R])
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == R and i != home and g.hosts[home].links.has(i):
			g._set_builds(i, ["intel"]); return i
	for nb in g.hosts[home].links:   # none yet: hand the rival one
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL:
			g._capture(n, R); g._set_builds(n, ["intel"]); return n
	return -1


func overclaim(fac: int) -> float:   # the most any host has claimed for fac beyond what is there for it (its pile and its storage)
	var worst := 0.0
	for i in g.hosts.size():
		for res in g.RES:
			var pc := float(((g.hosts[i].get("pclaim", {}) as Dictionary).get(fac, {}) as Dictionary).get(str(res), 0.0))   # (pile claims, 0.6.14)
			worst = maxf(worst, g._claimed(i, fac, str(res)) + pc - g._loot(i, fac, str(res)) - float(g._store_of(i, fac).get(str(res), 0.0)))
	return worst


func going_to(fac: int, i: int) -> int:   # fac's workers on their way to collect at host i
	var n := 0
	for f in g.flights:
		if str(f.kind) == "courier" and int(f.owner) == fac and int((f.get("job", {}) as Dictionary).get("src", -1)) == i: n += 1
	return n


func cands_now() -> Array:   # what a free worker at your main node could do now, as the dispatcher sees it (_assign)
	var hub: int = int(g.rig[P])
	var owed: Dictionary = g._build_owed(P)
	var out := []
	for r in g._open_requests(P, hub):
		if not g._route_ok(P, hub, int(r.host)): continue
		var amt: float = g._amount(P, hub, r, owed)
		if amt > 0.0001: var c: Dictionary = r.duplicate(); c.amt = amt; out.append(c)
	return out


func own_chain(n: int) -> Array:   # n of your hosts in a row from your main node (the last one is n hops out)
	var chain := [int(g.rig[P])]
	while chain.size() < n + 1:
		var nxt := -1
		for nb in g.hosts[int(chain[-1])].links:
			if int(g.hosts[int(nb)].owner) == g.NEUTRAL: nxt = int(nb); break
		if nxt < 0: break
		g._capture(nxt, P); g._set_builds(nxt, []); chain.append(nxt)
	return chain


func worm_pair() -> Array:   # [t, n]: a neutral host next to your main node and a neutral host next to it, both handed to the rival
	var home: int = int(g.rig[P])
	for nb in g.hosts[home].links:
		var t := int(nb)
		if int(g.hosts[t].owner) != g.NEUTRAL: continue
		for nb2 in g.hosts[t].links:
			var n := int(nb2)
			if n == home or int(g.hosts[n].owner) != g.NEUTRAL: continue
			g._capture(t, R); g._capture(n, R)
			return [t, n]
	return [-1, -1]


func run() -> void:
	phishing()
	siphon()
	vault()
	ddos()
	piles_claimed_once()
	vault_leaves_no_claims()
	salvage_is_not_loot()
	loot_last_on_every_turn()
	worm_snapshot_after_patch()
	worm_preview_scouting()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func phishing() -> void:
	fresh()
	var v := rival_outpost(); reach(v)
	check(not g.hosts[int(g.rig[P])].links.has(v), "phishing: the target is not next to your main node")
	g.cards[P] = {"phish": 1}
	check(g._can_play(P, "phish", v) == "", "phishing: playable on the rival outpost (%s)" % g._can_play(P, "phish", v))
	g._play_card(P, "phish", v)
	var secs: float = float(g.CARDS.phish.dur) + 60.0   # travel there (9 hops), the theft itself, the last workers home
	step(secs)
	var stolen: float = float(g.bank[P].intel) - secs * float(g.MAIN_INCOME)   # less your own main node's trickle
	var per: float = float(g.BUILD_KINDS.intel.rate) * g._tmult(v, "intel")   # what the outpost makes a cycle
	var promised: float = per * float(g.CARDS.phish.dur) / g.PROD_CYCLE   # all it makes while phished (one cycle may fall outside: its phase)
	check(stolen >= promised - per - 0.001, "phishing: all it makes while phished reaches you, 9 hops away (%.1f of %.1f)" % [stolen, promised])


func siphon() -> void:
	fresh()
	var v := rival_outpost(); reach(v)
	g.cards[P] = {"siphon": 1}
	check(g._can_play(P, "siphon", v) == "", "siphon: playable on the rival outpost (%s)" % g._can_play(P, "siphon", v))
	var mine0: int = int(g._worker_counts(P).total); var theirs0: int = int(g._worker_counts(R).total)
	g._play_card(P, "siphon", v, "intel")
	var secs: float = float(g.CARDS.siphon.dur) + 60.0
	var over := 0.0; var most := 0; var pile_max := 0.0
	for k in int(round(secs / g.SIM_DT)):   # (0.6.14) watch the claims as the stolen units wait at the host
		g._sim_step(g.SIM_DT)
		over = maxf(over, overclaim(P))
		for i in g.hosts.size():
			if int(g.hosts[i].owner) != P: most = maxi(most, going_to(P, i)); pile_max = maxf(pile_max, g._loot(i, P, "intel"))
	var stolen: float = float(g.bank[P].intel) - secs * float(g.MAIN_INCOME)
	var per: float = float(g.BUILD_KINDS.intel.rate) * g._tmult(v, "intel")
	var promised: float = minf(float(g.CARDS.siphon.cargo), per * float(g.CARDS.siphon.dur) / g.PROD_CYCLE)   # the outpost's cargo while it lasts
	check(stolen >= promised - per - 0.001, "siphon: all the cargo it diverted reaches you (%.1f of %.1f Intel that left the host)" % [stolen, promised])
	check(over <= 0.001 and most <= ceili(pile_max - 0.0001), "siphon: each stolen unit is claimed once: no more workers go for a pile than it holds (at most %d for a pile of up to %.0f; claims beyond what is there %.2f)" % [most, pile_max, over])
	check(int(g._worker_counts(P).total) == mine0 and int(g._worker_counts(R).total) == theirs0, "siphon: it takes their cargo, not their workers; your workers fetch it and come back (%d, %d)" % [mine0, theirs0])


func vault() -> void:   # Vault raid empties the storage of the target and its 2 nearest linked hosts of that owner
	fresh()
	var v := rival_outpost(); reach(v)
	g._set_builds(v, [])
	g._set_builds(int(g.rig[R]), []); g._tick_teams(0.0)   # no rival workers, so what is stored stays put until the raid
	var chain: Array = g._chain_hosts(v, int(g.CARDS.vault.reach), R)
	var put := 0
	for h in chain:
		if int(h) == int(g.rig[R]): continue   # the main node keeps its output in the bank, not in storage
		g.hosts[int(h)].store = {R: {"intel": 5.0, "cash": 4.0}}
		put += 9
	g.cards[P] = {"vault": 1}
	check(g._can_play(P, "vault", v) == "", "vault: playable on a rival host that is not a main node (%s)" % g._can_play(P, "vault", v))
	check(put >= 9, "vault: there is storage to raid (%d units on %d hosts)" % [put, chain.size()])
	g._play_card(P, "vault", v)
	var secs := 80.0   # 9 hops each way: six workers bring six units per 22-s round trip
	step(secs)
	var stolen: float = float(g.bank[P].intel) + float(g.bank[P].cash) - 2.0 * secs * float(g.MAIN_INCOME)
	var promised := mini(put, int(g.CARDS.vault.cargo))
	check(stolen >= float(promised) - 1.0, "vault: the storage reaches you (%.0f of %d units)" % [stolen, promised])
	var left := 0.0
	for h in chain: left += g._store_total(int(h))
	check(left < 1.0, "vault: their storage on those hosts is empty (%.0f left)" % left)


func ddos() -> void:   # DDoS takes down the target and its owner's 2 nearest hosts at once
	fresh()
	var v := rival_outpost(); reach(v)
	var n := 0
	for i in g.hosts.size():   # make sure the rival has at least three hosts
		if int(g.hosts[i].owner) == R: n += 1
	for i in g.hosts.size():
		if n >= 4: break
		if int(g.hosts[i].owner) == g.NEUTRAL and g.hosts[int(g.rig[R])].links.has(i): g._capture(i, R); n += 1
	var hit: Array = g._nearest_of_owner(v, int(g.CARDS.ddos.reach))
	g._op_land(P, "ddos", v, int(g.hosts[v].gen), {"id": 9200})
	var down := 0
	for h in hit: down += 1 if g._ddos_down(int(h)) else 0
	check(hit.size() == 3 and down == 3, "ddos: the target and its owner's 2 nearest hosts all go down (%d of %d)" % [down, hit.size()])


func piles_claimed_once() -> void:   # (0.6.14) a pile is offered less what is already claimed: one unit draws one worker, not the idle pool
	fresh()
	var chain := own_chain(3)
	var far: int = chain[-1]
	step(1.0)   # your workers are free at the main node
	var idle0: int = int(g._worker_counts(P).idle)
	g._add_to(far, "loot", P, "cash", 1.0)   # one unit left at your host three hops out
	g._logi_poke(P)
	var most := 0; var over := 0.0
	var c0: float = float(g.bank[P].cash)
	var secs := 30.0
	for k in int(round(secs / g.SIM_DT)):
		g._sim_step(g.SIM_DT)
		most = maxi(most, going_to(P, far))
		over = maxf(over, overclaim(P))
	var got: float = float(g.bank[P].cash) - c0 - secs * float(g.MAIN_INCOME)
	check(idle0 >= 2 and most == 1 and over <= 0.001 and absf(got - 1.0) < 0.01,
		"A 1-unit pile %d hops out draws one of your %d free workers, no claim beyond what it holds, and arrives (%d went, claims beyond it %.2f, %.2f arrived)" % [chain.size() - 1, idle0, most, over, got])


func salvage_is_not_loot() -> void:   # (0.6.14) a pile on your own host is your salvage: what a project waits for comes home first
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot", "bot", ""]); g._tick_teams(0.0)   # a free slot for the project
	var own := []
	var frontier := [home]
	while own.size() < 3 and not frontier.is_empty():
		var c: int = frontier.pop_front()
		for nb in g.hosts[c].links:
			if int(g.hosts[int(nb)].owner) == g.NEUTRAL and own.size() < 3:
				g._capture(int(nb), P); g._set_builds(int(nb), []); own.append(int(nb)); frontier.append(int(nb))
	var v := rival_outpost(); reach(v)
	step(1.0)
	var site: int = own[0]
	var pile: float = float(g._build_cost("wall").get("cash", 0.0))
	g._add_to(site, "loot", P, "cash", pile)   # a cancelled project's Crypto, left at its site
	g._add_to(v, "loot", P, "cash", 1.0)       # and stolen Crypto waiting on the rival's host
	for k in [1, 2]: g.hosts[int(own[k])].store = {P: {"intel": 6.0}}   # two of your hosts with Intel to ship
	g.bank[P] = {"intel": 100.0, "cash": 0.0, "creds": 0.0, "research": 0.0}
	var cls := {}
	for r in cands_now(): cls["%d:%s" % [int(r.host), str(r.res)]] = g._req_class(r)
	var export_cls: int = int(g.REQ_CLASS.export)
	check(int(cls.get("%d:cash" % site, -1)) == export_cls and int(cls.get("%d:cash" % v, -1)) > export_cls,
		"Your own salvage ranks with your exports (class %d); only stolen goods come last (%s)" % [export_cls, str(cls)])
	(g.hosts[v].loot as Dictionary).erase(P)   # (from here on, only your own hosts)
	g._start_job(home, "wall", 2)   # a Firewall at your main node waits for its Crypto: what the salvage holds
	var free0: int = int(g._worker_counts(P).idle)
	g._logi_poke(P)
	step(0.5)   # one dispatch
	var to_site: float = g._claimed(site, P, "cash") + float(((g.hosts[site].get("pclaim", {}) as Dictionary).get(P, {}) as Dictionary).get("cash", 0.0))   # (a pile's claims are its own, 0.6.14)
	var to_exports: float = g._claimed(int(own[1]), P, "intel") + g._claimed(int(own[2]), P, "intel")
	check(free0 >= 2 and to_site >= minf(pile, float(free0)) - 0.001 and to_exports <= 0.001,
		"A project waits for %.0f Crypto that lies as salvage on your host: all %d free workers go for it first, before the Intel exports (%.0f claimed there, %.0f Intel)" % [pile, free0, to_site, to_exports])


func loot_last_on_every_turn() -> void:   # (0.6.14) stolen goods wait on the fair turn too; with nothing else to do they still come home
	fresh()
	var v := rival_outpost(); reach(v)
	var hub: int = int(g.rig[P])
	var a := -1   # one of your hosts with Crypto to ship, served just now
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == P and i != hub: a = i; break
	g._set_builds(a, []); g._set_builds(v, [])
	g.hosts[a].store = {P: {"cash": 3.0}}
	g._add_to(v, "loot", P, "intel", 3.0)   # stolen Intel waiting on the rival's host, never served
	g._mark_served(P, a)
	var turns := int(g.PRIORITY_TURNS) + 1
	var picks := []
	var cands := cands_now()
	for turn in turns: picks.append(str(g._pick_request(P, cands, turn, g._build_lack(P, g._build_owed(P))).purpose))
	g.bank[P] = {"intel": 60.0, "cash": 60.0, "creds": 60.0, "research": 60.0}
	g._start_job(a, "intel")   # a project on that host: its materials go out
	cands = cands_now()
	var picks_b := []
	for turn in turns: picks_b.append(str(g._pick_request(P, cands, turn, g._build_lack(P, g._build_owed(P))).purpose))
	var only := cands.filter(func(r): return str(r.purpose) == "loot")
	var picks_l := []
	for turn in turns: picks_l.append(str(g._pick_request(P, only, turn, {}).purpose))
	check(not picks.has("loot") and not picks_b.has("loot") and picks_b.any(func(p): return str(p).begins_with("build:")) and only.size() >= 1 and picks_l.count("loot") == turns,
		"Over %d assignments, the fair one included, stolen goods never go before your own export (%s) or a project (%s), and come when nothing else waits (%s)" % [turns, ", ".join(PackedStringArray(picks)), ", ".join(PackedStringArray(picks_b)), ", ".join(PackedStringArray(picks_l))])


func worm_snapshot_after_patch() -> void:   # (0.6.14) the second stage counts as scouted, from a snapshot taken after a loaded Patch there fired
	fresh()
	var tn := worm_pair(); var t: int = tn[0]
	for nb in g.hosts[t].links:   # every rival host next to t: a Firewall with a Patch loaded
		var x := int(nb)
		if int(g.hosts[x].owner) == R: g._set_builds(x, ["wall", "intel"]); g.hosts[x].sockets = ["patch", "", ""]; g.hosts[x].fw_on = true
	g._mark_scanned(P, t)   # fresh Recon on the first host
	g._start_exec({"id": 9300, "fac": P, "card": "worm", "effect": "worm", "target": t, "gen": int(g.hosts[t].gen), "ends": g._t, "stage": 1, "victim": R, "seen": [t]})
	step(0.1)
	var st2: Array = g.op_outcomes.filter(func(o): return str(o.card) == "worm" and int(o.stage) == 2)
	var nx: int = int(st2[0].target) if st2.size() == 1 else -1
	var rec: Dictionary = (g.recon.get(P, {}) as Dictionary).get(nx, {}) if nx >= 0 else {}
	var says := ""
	if nx >= 0:
		for l in g._known_defences(P, nx, "capture", float(g.CARDS.exploit.exec)): says += str(l[0]) + " "
	check(int(g.hosts[t].owner) == P and nx >= 0 and str(st2[0].outcome) == "countered" and g._recon_fresh(P, nx)
		and str(rec.get("sockets", [])) == str(g.hosts[nx].sockets) and not says.contains("would fire"),
		"A Worm's second stage stopped on the spot by a loaded Patch: the host still counts as scouted, and its snapshot shows the socket the Patch left empty (%s; live %s) — %s" % [str(rec.get("sockets", [])), str(g.hosts[nx].sockets) if nx >= 0 else "-", says.strip_edges()])


func worm_preview_scouting() -> void:   # (0.6.14) "scouted like this one" only when the Recon is still fresh as the first stage resolves
	var seen := []
	for stale in [false, true]:
		fresh()
		var tn := worm_pair(); var t: int = tn[0]; var n: int = tn[1]
		for nb in g.hosts[n].links:   # one of your hosts next to the second, so you see it
			var m := int(nb)
			if m != t and int(g.hosts[m].owner) == g.NEUTRAL: g._capture(m, P); break
		g._refresh_sight()
		g.cards[P] = {"worm": 1}
		g._mark_scanned(P, t)
		var ex: float = g._exec_time("worm", t)
		if stale: g.recon[P][t].at = g._t - (float(g.CARDS.recon.dur) - ex * 0.5)   # fresh now, stale halfway through the execution
		var line := ""
		for l in g._target_preview(P, "worm", t).lines:
			if str(l[0]).begins_with("Next if it captures"): line = str(l[0])
		g._play_card(P, "worm", t)
		var scouted2 := -1
		for k in int(round((ex + 20.0) / g.SIM_DT)):
			g._sim_step(g.SIM_DT)
			for e in g._execs:
				if int(e.fac) == P and int(e.stage) == 2: scouted2 = 1 if g._recon_fresh(P, int(e.target)) else 0
			if scouted2 >= 0: break
		seen.append([line, scouted2])
	check(str(seen[0][0]).contains("scouted") and int(seen[0][1]) == 1 and not str(seen[1][0]).contains("scouted") and int(seen[1][1]) == 0,
		"The Worm preview promises a scouted second stage only when the Recon is still fresh as the first resolves, as it then runs (%s)" % str(seen))


func vault_leaves_no_claims() -> void:   # (0.6.15) a Vault raid takes stock the owner's workers were on their way for: their claims shrink
	fresh()                               # to what is left, so new output there is collected again at once
	var v := rival_outpost()
	g.hosts[v].store = {R: {"intel": 3.0}}
	g._add_to(v, "loot", R, "creds", 3.0)
	g._add_to(v, "claim", R, "intel", 3.0); g._add_to(v, "pclaim", R, "creds", 1.0)   # its workers are on their way
	g._resolve_vault(P, v)
	var left_claims := 0.0
	for field in ["claim", "pclaim"]:
		for res in ((g.hosts[v].get(field, {}) as Dictionary).get(R, {}) as Dictionary): left_claims += float(g.hosts[v][field][R][res])
	check(left_claims <= 0.001 and g._loot(v, P, "intel") >= 3.0 - 0.001, "A Vault raid takes the stock the owner's workers were coming for, and leaves no claim on what is gone (%.1f left)" % left_claims)
