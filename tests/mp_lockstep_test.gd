extends SceneTree
## Multiplayer lockstep without a server: two or three games in one process and a relay that behaves like
## server/PROTOCOL.md (every turn goes to every player, sender included, through a JSON round trip, optionally
## late). Every screen must hold the identical simulation after every turn, commands must change the match,
## malformed or foreign commands must do nothing, and a dropped player must leave an idle botnet without
## stalling the others.
##   godot --headless --path . --script tests/mp_lockstep_test.gd

var checks := 0
var failures: Array = []


class Relay:
	var games := {}           # faction -> game
	var latency := 0          # frames a message is in flight
	var queue := []           # [frame due, faction to, message]
	var frame := 0
	var last_sent := {}       # faction -> the last turn it sent
	var cut := {}             # faction -> true: its messages no longer arrive (it dropped)
	var hashes := {}          # turn -> {faction: hash} reported by the games

	func out(fac: int, msg: Dictionary) -> void:
		if cut.has(fac): return
		match str(msg.get("t", "")):
			"turn":
				last_sent[fac] = int(msg.turn)
				var wire: Variant = JSON.parse_string(JSON.stringify({"t": "turn", "turn": msg.turn, "from": fac, "cmds": msg.cmds}))
				for f in games: queue.append([frame + latency, f, wire])
			"hash":
				if not hashes.has(int(msg.turn)): hashes[int(msg.turn)] = {}
				hashes[int(msg.turn)][fac] = str(msg.h)

	func pump() -> void:
		var keep := []
		for q in queue:
			if int(q[0]) <= frame:
				if not cut.has(int(q[1])): games[int(q[1])]._mp_on_message(q[2])
			else: keep.append(q)
		queue = keep
		frame += 1


class Pipe extends Node:   # stands in for scripts/botnet_net.gd: the game calls send() and leave() and sets auto_retry
	var relay
	var fac := 0
	var auto_retry := false
	func send(msg: Dictionary) -> void: relay.out(fac, msg)
	func leave() -> void: pass


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func _initialize() -> void:
	_run.call_deferred()


func _match(n: int, size: String, seed: int, latency: int) -> Relay:
	var relay := Relay.new(); relay.latency = latency
	var players := []
	for f in range(1, n + 1): players.append({"id": 100 + f, "name": ["Ann", "Bob", "Cy"][f - 1], "faction": f})
	for f in range(1, n + 1):
		var game = load("res://scripts/botnet_proto.gd").new()
		game.theme = load("res://assets/ui_theme.tres")
		root.add_child(game); game.set_process(false)
		var pipe := Pipe.new(); pipe.relay = relay; pipe.fac = f
		game.net = pipe
		relay.games[f] = game
		var start: Variant = JSON.parse_string(JSON.stringify({"t": "start", "seed": seed, "size": size, "turn_steps": 3, "delay": 2, "you": f, "players": players}))
		game._mp_on_message(start)
	return relay


func _end(relay: Relay) -> void:
	for f in relay.games:
		var g = relay.games[f]
		if is_instance_valid(g.net): g.net.free()
		g.net = null
		g.queue_free()


func _frame(relay: Relay, skip: Dictionary = {}) -> Dictionary:   # one frame everywhere; returns faction -> turn finished this frame (or -1)
	var done := {}
	for f in relay.games:
		var g = relay.games[f]
		done[f] = -1
		if skip.has(f) or relay.cut.has(f): continue
		var before: int = g._mp_turn
		g._process(1.0 / 30.0)
		if g._mp_turn > before: done[f] = g._mp_turn - 1
	relay.pump()
	return done


func _neutral_next_to(g, fac: int) -> int:   # a neutral building one street from one of fac's
	for i in g.hosts.size():
		if int(g.hosts[i].owner) != fac: continue
		for o in g.hosts[i].links:
			if int(g.hosts[int(o)].owner) == g.NEUTRAL: return int(o)
	return -1


func _owned(g, fac: int) -> Array:
	var out := []
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == fac: out.append(i)
	return out


func _run() -> void:
	# ---- 1. two players, no delay: same town, same state every turn, commands matter ----
	var r := _match(2, "small", 4242, 0)
	var a = r.games[1]; var b = r.games[2]
	check(a._mp_on and b._mp_on and a.PLAYER == 1 and b.PLAYER == 2, "Both screens start a multiplayer match as their own faction")
	check(a.humans == [1, 2] and b.humans == [1, 2] and a.ais.is_empty() and a.botnets == [1, 2], "People only: two human botnets, no AI")
	check(a._mp_hash() == b._mp_hash() and a.hosts.size() == b.hosts.size(), "Both screens built the identical town from the seed")
	check(str(a.hosts[int(a.rig[2])].name) == "Bob RIG" and str(a.hosts[int(a.rig[1])].name) == "YOUR RIG", "Rigs are labelled with the players' names")
	var ta := _neutral_next_to(a, 1); var tb := _neutral_next_to(b, 2)
	check(ta >= 0 and tb >= 0, "Fixture: each player has a neutral neighbour to attack")
	var sec_a: float = float(a.hosts[ta].sec)
	a.sel = {}
	for i in _owned(a, 1): a.sel[i] = true
	a._wire(ta); a._launch(ta, "attack")
	b.sel = {}
	for i in _owned(b, 2): b.sel[i] = true
	b._wire(tb); b._launch(tb, "attack")
	var second_b: int = -1
	for i in _owned(b, 2):
		if not bool(b.hosts[i].rig): second_b = i
	b._drop_build(second_b, b._free_slot(second_b), "intel")
	a._card_research_click("phishworm:linked")
	check(int(a.hosts[_owned(a, 1)[0]].assign) == -1 or not bool(a.hosts[_owned(a, 1)[0]].live), "A multiplayer command waits for its turn instead of applying at once")
	var mismatch := -1; var turns := 0
	for k in 900:   # 30 s
		var done := _frame(r)
		if done[1] >= 0 and done[1] == done[2]:
			turns += 1
			if a._mp_hash() != b._mp_hash() and mismatch < 0: mismatch = done[1]
	check(turns >= 250 and mismatch < 0, "Identical simulation on both screens after every one of %d turns (first mismatch: %d)" % [turns, mismatch])
	check(int(a.hosts[ta].owner) == 1 or float(a.hosts[ta].bots) < sec_a, "Player 1's wire + attack reached the target")
	check(int(b.hosts[tb].owner) == 2 or float(b.hosts[tb].bots) < float(a.hosts[tb].sec) + 0.001, "Player 2's attack is seen on player 1's screen too")
	check(not (b.hosts[second_b].builds as Array).filter(func(x): return str(x) == "intel").is_empty() or not (b.hosts[second_b].jobs as Dictionary).is_empty(), "Player 2's build order runs on its building")
	check((a.lab[1].queue as Array).has("phishworm:linked") or int(a._held(1, "phishworm:linked")) > 0, "Player 1's research order is in its lab")
	check(r.hashes.size() >= 8, "Each screen reports a state fingerprint every 30 turns (%d reports)" % r.hashes.size())
	var agree := true
	for t in r.hashes:
		var hs: Dictionary = r.hashes[t]
		if hs.size() == 2 and hs[1] != hs[2]: agree = false
	check(agree, "The reported fingerprints agree")
	# ---- 2. malformed and foreign commands do nothing, identically ----
	var victim := -1
	for i in _owned(a, 1):
		if int(a.hosts[i].assign) >= 0: victim = i; break
	var bad := [["wire", "x", null], ["build", 99999, 0, "intel"], ["card", "nonsense", -5], ["launch", 3], [], ["frobnicate", 1],
		["unwire", victim], ["halt", ta], ["demolish", _owned(a, 1)[0], 0], ["build", _owned(a, 1)[0], 0, "lab"], ["wire", [_owned(a, 1)[0]], tb]]
	var assign_before: int = int(a.hosts[victim].assign) if victim >= 0 else -2
	for c in bad: b._cmd(c)
	for k in 60: _frame(r)
	check(a._mp_hash() == b._mp_hash(), "Garbage commands leave both screens identical")
	check(victim < 0 or int(a.hosts[victim].assign) == assign_before, "A command on another player's building does nothing")
	_end(r)

	# ---- 3. late messages and an uneven pace: the faster screen waits, nothing drifts ----
	r = _match(2, "small", 777, 9)
	a = r.games[1]; b = r.games[2]
	a.sel = {}
	for i in _owned(a, 1): a.sel[i] = true
	a._wire(_neutral_next_to(a, 1)); a._launch(_neutral_next_to(a, 1), "attack")
	var waited := false; var a_hashes := {}; var b_hashes := {}
	for k in 600:
		var done := _frame(r, {2: true} if k % 2 == 1 else {})   # player 2 only gets every other frame
		if a._mp_wait > 0.0: waited = true
		if done[1] >= 0: a_hashes[done[1]] = a._mp_hash()
		if done[2] >= 0: b_hashes[done[2]] = b._mp_hash()
	var same := 0; var diff := 0
	for t in b_hashes:
		if a_hashes.has(t):
			if a_hashes[t] == b_hashes[t]: same += 1
			else: diff += 1
	check(waited, "With 300 ms latency and a slow partner, the faster screen waits for missing turns")
	check(same >= 80 and diff == 0, "Late, uneven delivery still gives identical turns (%d compared, %d differ)" % [same, diff])
	_end(r)

	# ---- 4. three players; one drops: its botnet idles, the others carry on ----
	r = _match(3, "medium", 31337, 2)
	a = r.games[1]; b = r.games[2]; var c = r.games[3]
	check(a.botnets == [1, 2, 3] and a.rig.size() == 3 and a._mp_hash() == c._mp_hash(), "Three players: three rigs, one identical town")
	for k in 120: _frame(r)
	var c_owned := _owned(a, 3).size()
	r.cut[3] = true                                   # player 3's connection dies …
	var from_turn: int = int(r.last_sent.get(3, 1)) + 1
	for f in [1, 2]:                                  # … and the server tells the others
		r.games[f]._mp_on_message(JSON.parse_string(JSON.stringify({"t": "drop", "faction": 3, "from_turn": from_turn})))
	var t0: int = a._mp_turn
	var mism := false
	for k in 300:
		var done := _frame(r)
		if done[1] >= 0 and done[1] == done[2] and a._mp_hash() != b._mp_hash(): mism = true
	check(a._mp_turn > t0 + 60 and b._mp_turn > t0 + 60, "After a drop the remaining players keep playing (turn %d → %d)" % [t0, a._mp_turn])
	check(not mism, "The remaining players stay identical after the drop")
	check(_owned(a, 3).size() >= mini(c_owned, 1) and a.botnets.has(3), "The dropped player's botnet stays on the map, idle")
	_end(r)

	# ---- 5. a flood of far-future turns is ignored; the server taking you out of a match ends it on your screen ----
	r = _match(2, "small", 99, 0)
	a = r.games[1]
	for k in 30: _frame(r)
	var before_keys: int = a._mp_turns.size()
	a._mp_on_message(JSON.parse_string(JSON.stringify({"t": "turn", "turn": a._mp_turn + 1000, "from": 2, "cmds": [["halt", 1]]})))
	check(a._mp_turns.size() == before_keys and not a._mp_turns.has(a._mp_turn + 1000), "A turn far in the future is ignored (no unbounded buffering)")
	var pipe = a.net
	var real = load("res://scripts/botnet_net.gd").new()   # the menu needs the real connection object (never opened here)
	a.net = real; a.add_child(real)
	a._mp_on_message({"t": "left"})
	check(not a._mp_on and a.PLAYER == 1 and a.humans == [1] and a.menu_open and a._menu_view == "mp", "Taken out of the match by the server: back to the Multiplayer menu, single-player state restored")
	pipe.free()
	_end(r)

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
