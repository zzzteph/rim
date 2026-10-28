extends SceneTree
## Theft must arrive: Phishing, Packet siphon and Vault raid bring their loot home through your own network,
## in the amounts the cards promise, from targets that are not next to your main node.
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


func reach(target: int) -> void:   # the player takes the hosts leading up to target, so a card can get there
	var path := path_avoiding(int(g.rig[P]), target, R)
	for k in range(1, path.size() - 1):
		if int(g.hosts[path[k]].owner) != P: g._capture(path[k], P)


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
	check(float(g.bank[P].bots) >= bots_before + secs * float(g.MAIN_INCOME) - 1.0, "siphon: the diverted couriers are theirs, not yours")


func vault() -> void:
	fresh()
	var home: int = int(g.rig[R])
	reach(home)
	g.bank[R].cash = 200.0
	g.cards[P] = {"vault": 1}
	check(g._can_play(P, "vault", home) == "", "vault: playable on the rival main node (%s)" % g._can_play(P, "vault", home))
	g._play_card(P, "vault", home)
	var secs := 60.0   # 10 s of raid, then a long convoy queues through the links home
	step(secs)
	var card: Dictionary = g.CARDS.vault
	var promised := float(mini(int(card.get("cargo", 8)), maxi(int(200.0 * float(card.get("cargo_pct", 0.0))), int(card.get("cargo_min", 0)))))
	var stolen: float = float(g.bank[P].cash) - secs * float(g.MAIN_INCOME)
	check(promised >= 40.0, "vault: a 200-Crypto bank is worth a real raid (%.0f promised)" % promised)
	check(stolen >= promised - 2.0, "vault: the loot reaches you (%.0f of %.0f Crypto)" % [stolen, promised])
	check(float(g.bank[R].cash) <= 200.0 + secs * float(g.MAIN_INCOME) - promised + 2.0, "vault: the rival loses it (%.0f left)" % float(g.bank[R].cash))
