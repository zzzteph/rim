extends SceneTree
## Theft must arrive: Phishing, Packet siphon and Vault raid bring their loot home through your own network,
## in the amounts the cards promise, from targets that are not next to your main node. DDoS hits three hosts.
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
	g._open_menu(false)
	P = g.PLAYER; R = g.RIVAL
	for fac in [P, R]:   # only the main nodes' built-in income: every other gain is the theft being measured
		for i in g.hosts.size():
			if int(g.hosts[i].owner) == fac: g._set_builds(i, [])
		g.bank[fac] = {"bots": 150.0, "intel": 0.0, "cash": 0.0, "creds": 0.0, "research": 0.0}


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


func rival_outpost() -> int:   # a rival host next to its main node, given an Intel harvester (2 Intel every 5 s, no input)
	var home: int = int(g.rig[R])
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == R and i != home and g.hosts[home].links.has(i):
			g._set_builds(i, ["intel"]); return i
	for nb in g.hosts[home].links:   # none yet: hand the rival one
		var n := int(nb)
		if int(g.hosts[n].owner) == g.NEUTRAL:
			g._capture(n, R); g._set_builds(n, ["intel"]); return n
	return -1


func run() -> void:
	phishing()
	siphon()
	vault()
	ddos()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func phishing() -> void:
	fresh()
	var v := rival_outpost(); reach(v)
	check(not g.hosts[int(g.rig[P])].links.has(v), "phishing: the target is not next to your main node")
	g.cards[P] = {"phish": 1}
	check(g._can_play(P, "phish", v) == "", "phishing: playable on the rival outpost (%s)" % g._can_play(P, "phish", v))
	g._play_card(P, "phish", v)
	var secs: float = float(g.CARDS.phish.dur) + 25.0   # travel there, the theft itself, the last couriers home
	step(secs)
	var stolen: float = float(g.bank[P].intel) - secs * float(g.MAIN_INCOME)   # less your own main node's trickle
	var promised: float = 2.0 * float(g.CARDS.phish.dur) / g.PROD_CYCLE   # the outpost makes 2 Intel a cycle
	check(stolen >= promised * 0.6, "phishing: its output reaches you (%.0f of ~%.0f Intel)" % [stolen, promised])


func siphon() -> void:
	fresh()
	var v := rival_outpost(); reach(v)
	g.cards[P] = {"siphon": 1}
	check(g._can_play(P, "siphon", v) == "", "siphon: playable on the rival outpost (%s)" % g._can_play(P, "siphon", v))
	var bots_before: float = float(g.bank[P].bots)
	g._play_card(P, "siphon", v, "intel")
	var secs: float = float(g.CARDS.siphon.dur) + 25.0
	step(secs)
	var stolen: float = float(g.bank[P].intel) - secs * float(g.MAIN_INCOME)
	var promised: float = minf(float(g.CARDS.siphon.cargo), 2.0 * float(g.CARDS.siphon.dur) / g.PROD_CYCLE)
	check(stolen >= promised * 0.6, "siphon: diverted cargo reaches you (%.0f of ~%.0f Intel)" % [stolen, promised])
	check(float(g.bank[P].bots) + float(g._couriers_out(P, g._hub(P))) >= bots_before + secs * float(g.MAIN_INCOME) - 1.0, "siphon: it takes their cargo, not their couriers; your couriers fetch it and come back")


func vault() -> void:   # Vault raid empties the storage of the target and its 2 nearest linked hosts of that owner
	fresh()
	var v := rival_outpost(); reach(v)
	g._set_builds(v, [])
	g.bot_reserve[R] = 999   # their couriers stay home, so what is stored stays put until the raid
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
	var secs := 50.0
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
