extends SceneTree
## The HUD's income forecast (feedback round B, section 3): what will reach the main node's bank per minute with the
## network as it stands, worked out from the network rather than extrapolated from early ledger events. It is checked
## against a long controlled simulation, and against the conditions that cut income: no free workers, a cut route,
## a Miner with no input beside a Firewall whose upkeep workers bring (0.6.12: the one input left), a building that
## cannot be paused, a full bank, a full storage its producers share evenly, a phished host, a main node under DDoS.
## Workers show activity, not an income.
## godot --headless --path . --script tests/forecast_test.gd
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
	g.bank[P] = {"intel": 60.0, "cash": 30.0, "creds": 30.0, "research": 30.0}
	watch = -1


var watch := -1    # a host whose production step() follows (-1: none, see watch_host):
var cycles := 0    # ...the production cycles it ran,
var fed := 0       # ...those after which its Firewalls were on (each ate its upkeep),
var picked := {}   # ...and what workers picked up there to take home, per material
var _seen := {}    # (the flights whose pickup is already counted)


func watch_host(i: int) -> void:   # start following host i from now on
	watch = i; cycles = 0; fed = 0; picked = {}; _seen = {}
	for res in g.RES: picked[res] = 0.0
	for f in g.flights:   # (what is already on its way was picked up before)
		if int(f.get("src", -1)) == i and str(f.get("trip", "")) == "back": _seen[int(f.id)] = true


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)):
		var left := float(g.hosts[watch].cyc) if watch >= 0 else 0.0
		g._sim_step(g.SIM_DT)
		if watch < 0: continue
		if float(g.hosts[watch].cyc) > left:   # its timer wrapped: the host ran a cycle
			cycles += 1
			if bool(g.hosts[watch].fw_on): fed += 1
		for f in g.flights:   # a worker leaving it for home: what it picked up there, counted once
			if str(f.kind) != "courier" or int(f.owner) != P or int(f.get("src", -1)) != watch or str(f.get("trip", "")) != "back" or _seen.has(int(f.id)): continue
			_seen[int(f.id)] = true
			for res in (f.cargo as Dictionary): picked[res] = float(picked.get(res, 0.0)) + float(f.cargo[res])


func stored(i: int) -> Dictionary:   # {res: units} in host i's storage for you
	var out := {}
	for res in g.RES: out[res] = float(g._store_of(i, P).get(res, 0.0))
	return out


func rate(res: String) -> float: return float(g._forecast(P).rate[res])
func trickle() -> float: return g.MAIN_INCOME * 60.0           # the main node's 1 of each per cycle, per minute
func per_cycle() -> float: return 60.0 / g.PROD_CYCLE           # one unit a cycle, per minute


func measured(res: String, secs: float) -> float:   # what actually reached the bank per minute over secs of play (refunds aside)
	var before := received(res)
	step(secs)
	return (received(res) - before) * 60.0 / secs


var _total := {}
func received(res: String) -> float:   # a running total of "in" entries, kept by sampling the ledger every second
	return float(_total.get(res, 0.0))


func track(secs: float) -> Dictionary:   # per-minute received per resource over secs, from the ledger's 1-s buckets
	var got := {}                        # (and "supply:<res>": what left the bank to supply hosts)
	for res in g.RES: got[res] = 0.0; got["supply:" + res] = 0.0
	var n := int(round(secs))
	for k in n:
		step(1.0)
		var L: Dictionary = g._ledger.get(P, {})
		var sec := int(floor(g._t)) - 1
		var slot := posmod(sec, g.LEDGER_SECS)
		if L.is_empty() or int(L.sec[slot]) != sec: continue
		for key in (L.data[slot] as Dictionary):
			var parts := str(key).split(":")
			if parts[0] == "in" and not (parts[1] in ["returned", "refunds"]): got[parts[2]] = float(got[parts[2]]) + float(L.data[slot][key])
			if parts[0] == "out" and parts[1] == "supply": got["supply:" + parts[2]] = float(got["supply:" + parts[2]]) + float(L.data[slot][key])
	for res in got: got[res] = float(got[res]) * 60.0 / float(n)
	return got


func neighbours_of(i: int) -> Array:
	var out := []
	for nb in g.hosts[i].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL: out.append(int(nb))
	return out


func far_host(via: int) -> int:   # a neutral host linked to via but not to the main node
	var home: int = int(g.rig[P])
	for nb in g.hosts[via].links:
		var n := int(nb)
		if n != home and int(g.hosts[n].owner) == g.NEUTRAL and not g.hosts[home].links.has(n): return n
	return -1


func run() -> void:
	sustained()
	no_workers()
	cut_route()
	no_input_and_upkeep()
	paused()
	full_bank()
	no_early_spike()
	short_of_workers()
	full_storage()
	phished()
	main_node_down()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func network() -> Dictionary:   # a main node with a harvester and a station, a near host with a station, a far one: one pool serves both
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["intel", "bot"])
	var near: int = neighbours_of(home)[0]
	g._capture(near, P); g.hosts[near].type = "pc"; g.hosts[near].slots = 3
	g._set_builds(near, ["bot", "intel", "cash"])
	var far := far_host(near)
	g._capture(far, P); g.hosts[far].type = "pc"; g.hosts[far].slots = 3
	g._set_builds(far, ["intel", "cred"])
	return {"home": home, "near": near, "far": far}


func sustained() -> void:
	var n := network()
	step(60.0)   # past the start: storages and workers settle
	var fc := {}
	for res in g.RES: fc[res] = rate(res)
	var got := track(240.0)
	var bad := []
	for res in ["intel", "cash", "creds", "research"]:
		var tol := maxf(2.5, 0.12 * float(fc[res]))
		if absf(float(got[res]) - float(fc[res])) > tol: bad.append("%s %.1f vs %.1f" % [res, float(got[res]), float(fc[res])])
	check(bad.is_empty(), "Forecast matches 240 s of steady play within 12%% (Intel %.0f/%.0f, Crypto %.0f/%.0f, Creds %.0f/%.0f) %s" %
		[float(fc.intel), float(got.intel), float(fc.cash), float(got.cash), float(fc.creds), float(got.creds), str(bad)])
	var from: Dictionary = (g._forecast(P).from as Dictionary).get("creds", {})
	check(from.has(str(g.hosts[n.far].name)) and from.has("main node trickle"), "It says where each bank's income comes from (%s)" % str(from))
	var before: float = rate("cash")
	step(10.0)
	check(absf(rate("cash") - before) < 0.01, "A steady network shows a steady forecast (%.1f, then %.1f)" % [before, rate("cash")])


func no_workers() -> void:
	var n := network()
	step(20.0)
	var with: float = rate("creds")
	g._set_builds(n.home, ["intel"]); g._set_builds(n.near, ["intel", "cash"])   # every station goes: its workers retire, nobody carries
	g._fc_gen += 1
	var fc: Dictionary = g._forecast(P)
	check(with > trickle() + 0.5 and rate("creds") <= trickle() + 0.01 and (fc.limits as Dictionary).get("creds", []).has("not enough workers"),
		"No workers for it: the far host's Credentials leave the forecast at once (%.0f → %.0f), and it says why" % [with, rate("creds")])
	var hud := str(g._hud_rate("workers")[0])
	check(hud.contains("busy") and not hud.contains("/min"), "The Workers column shows what workers do, not an income: '%s'" % hud)
	step(10.0)   # the retiring workers finish their legs
	var got := track(60.0)
	check(float(got.creds) <= trickle() + 2.5, "...and none arrive (%.1f/min: the trickle only)" % float(got.creds))
	fresh()   # (0.6.12) a host whose Firewall runs on the Intel workers bring, and one whose Firewall eats its own harvester's Intel
	var home: int = int(g.rig[P])
	g._set_builds(home, ["intel", "bot"])
	var a: int = neighbours_of(home)[0]
	g.hosts[a].type = "pc"; g._capture(a, P); g._set_builds(a, ["wall", "lab"])
	var b: int = neighbours_of(home)[0]
	g.hosts[b].type = "pc"; g.hosts[b].slots = 3; g._capture(b, P); g._set_builds(b, ["intel", "wall", "lab"])
	step(60.0)
	var res_with: float = rate("research")
	var b_intel := float((g._forecast(P).from.get("intel", {}) as Dictionary).get(str(g.hosts[b].name), 0.0))   # all eaten there: none to ship
	g._set_builds(home, ["intel"]); g._fc_gen += 1
	var lim: Dictionary = g._forecast(P).limits
	check(res_with > trickle() + 0.5 and bool(g.hosts[a].fw_on) and (lim.get("research", []) as Array).has("not enough workers"),
		"A host whose Firewall runs on supplies still says why its Research left the forecast (%.0f → %.0f: %s)" % [res_with, rate("research"), str(lim.get("research", []))])
	check(b_intel == 0.0 and bool(g.hosts[b].fw_on) and not (lim.get("intel", []) as Array).has("not enough workers"),
		"...and the shortage is not blamed on Intel, which the other host's Firewall eats anyway (%s)" % str(lim.get("intel", [])))


func cut_route() -> void:
	var n := network()
	step(20.0)
	g._capture(n.near, g.RIVAL)   # the far host's only way home
	var fc: Dictionary = g._forecast(P)
	check(rate("creds") <= trickle() + 0.01 and str((fc.limits as Dictionary).get("creds", [])).contains("no route home"), "A cut route: the far host's output is not counted (%.0f), and the reason is named" % rate("creds"))
	var got := track(40.0)
	check(float(got.creds) <= trickle() + 2.5, "...and it does not arrive (%.1f/min)" % float(got.creds))


func no_input_and_upkeep() -> void:   # 0.6.12: a Miner needs no input; the one input left is a Firewall's Intel, which the workers bring
	fresh()                             # to a host that makes none: it is spending, not income, and it rides out on the trip that brings output back
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot"])   # workers, and no Intel made at the main node beyond its trickle
	var h: int = neighbours_of(home)[0]
	g._capture(h, P); g._set_builds(h, ["cash"])   # a lone Miner: no Intel on its host
	var miner: float = per_cycle() * float(g.BUILD_KINDS.cash.rate) * g._tmult(h, "cash")   # its Crypto a minute
	var upkeep: float = float(g.BUILD_KINDS.wall.use.intel)   # a Firewall's Intel a cycle
	g._fc_gen += 1
	var need0 := float(g._forecast(P).need)
	step(30.0)
	var got0 := track(60.0)   # (with input to make, its Intel would go out to it from the bank's 60)
	check(absf(rate("cash") - trickle() - miner) < 0.01 and float(got0["supply:intel"]) == 0.0,
		"A lone Miner needs no input: with no Intel on its host and none sent to it (%.1f/min) it adds its %.0f Crypto/min to the forecast (%.0f)" % [float(got0["supply:intel"]), miner, rate("cash")])
	g._set_builds(h, ["cash", "wall"]); g._fc_gen += 1   # a Firewall beside it: its upkeep must be brought
	var need1 := float(g._forecast(P).need)
	check(absf(rate("cash") - trickle() - miner) < 0.01 and absf(rate("intel") - trickle()) < 0.01 and absf(need1 - need0) < 0.001,
		"A Firewall beside it, its %s Intel a cycle brought by workers: the Miner still adds %.0f Crypto/min, the supplied Intel is not income (%.0f, %.0f), and one round trip takes the upkeep out and the Crypto back (%.2f workers needed, as without it)"
		% [g._amt(upkeep), miner, rate("cash"), rate("intel"), need1])
	step(30.0)
	watch_host(h)
	var secs := 180.0
	var got := track(secs)
	var sent: float = float(got["supply:intel"]) * secs / 60.0; var eaten: float = fed * upkeep   # (units over the run)
	check(absf(float(got.cash) - rate("cash")) <= 2.5 and cycles > 0 and fed == cycles and absf(sent - eaten) <= 2.0 * upkeep + 0.001,
		"...which the simulation delivers (%.1f Crypto/min vs %.0f), the Firewall on in all %d cycles: %s Intel sent for the %s it ate (a cycle's upkeep may wait at the host or on its way at either end)"
		% [float(got.cash), rate("cash"), cycles, g._amt(sent), g._amt(eaten)])
	g.bank[P].intel = 0.0; g._fc_gen += 1
	check(absf(rate("cash") - trickle() - miner) < 0.01 and absf(float(g._forecast(P).need) - need1) < 0.001,
		"With the bank's Intel gone the forecast stands: the trickle brings in the upkeep (%s a cycle) and the Miner needs none (%.0f)" % [g._amt(g.MAIN_INCOME * g.PROD_CYCLE), rate("cash")])
	watch_host(h)
	var got2 := track(120.0)
	check(absf(float(got2.cash) - trickle() - miner) <= 2.5 and cycles > 0 and fed == cycles,
		"...as the simulation does (%.1f Crypto/min), the Firewall on in all %d cycles on the trickle's Intel" % [float(got2.cash), cycles])
	g.hosts[home].ddos_until = g._t + 60.0; g.bank[P].intel = 0.0; g._fc_gen += 1   # and with the main node down, nothing comes in to send
	var down := rate("cash")
	watch_host(h)
	step(g.PROD_CYCLE * 2.5)   # what was already on its way is eaten first
	check(down <= 0.01 and fed < cycles and not bool(g.hosts[h].fw_on),
		"With no Intel to send at all the Firewall is starved again: off (on in %d of %d cycles), and nothing from the host is forecast (%.0f)" % [fed, cycles, down])


func paused() -> void:   # a building cannot be paused: the old order is ignored and the forecast stays
	var n := network()
	step(10.0)
	var before: float = rate("cash")
	g._cmd(["produce", n.near, 2]); g._cmd(["job", n.near, 2])
	check(g._producer_active(n.near, 2) and absf(rate("cash") - before) < 0.01, "A Miner cannot be paused: the old pause order changes nothing (%.0f → %.0f)" % [before, rate("cash")])


func full_bank() -> void:
	var n := network()
	step(10.0)
	g.bank[P].creds = g._cap(P, "creds")
	var fc: Dictionary = g._forecast(P)
	check(rate("creds") == 0.0 and str(g._hud_rate("creds")[0]) == "full" and (fc.limits as Dictionary).get("creds", []).has("your bank is full"),
		"A full bank: nothing more is forecast to reach it, the HUD says full")


func no_early_spike() -> void:   # the old reading extrapolated the first seconds of the ledger into large numbers
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["intel", "bot"])
	step(1.0)
	var early: float = rate("intel")
	step(29.0)
	var steady: float = trickle() + per_cycle() * float(g.BUILD_KINDS.intel.rate) * g._tmult(home, "intel")
	check(absf(early - rate("intel")) < 0.01 and absf(early - steady) < 0.01, "From the first second the forecast is the network's steady rate (%.0f Intel/min: trickle + harvester)" % early)
	check(not str(g._hud_rate("intel")[0]).begins_with("~"), "No early-estimate tilde: it is a forecast, not a measurement")


func short_of_workers() -> void:   # two workers for six hosts: the forecast follows the dispatcher (the Firewalls' upkeep on three
	fresh()                          # turns of four, every other turn to the host served least recently, supplies only where they
	                                 # fit), material by material, not one even share for everything
	var home: int = int(g.rig[P])
	var hs := []
	var frontier := [home]; var seen := {home: true}
	while hs.size() < 6 and not frontier.is_empty():
		var nxt := []
		for f0 in frontier:
			for nb in g.hosts[int(f0)].links:
				if seen.has(int(nb)): continue
				seen[int(nb)] = true
				if hs.size() < 6 and int(g.hosts[int(nb)].owner) == g.NEUTRAL: hs.append(int(nb)); g._capture(int(nb), P); nxt.append(int(nb))
		frontier = nxt
	var lays := [["intel", "cash", "intel"], ["intel", "cred", "intel"], ["cash", "wall"], ["cred", "wall"], ["intel", "intel", "lab"], ["intel"]]
	for k in hs.size(): g._set_builds(hs[k], (lays[k] as Array).slice(0, int(g.hosts[hs[k]].slots)))   # (0.6.12: two Firewalls with no
	var walled := []                                                                                       # Intel of their own, for supplies)
	for k in hs.size(): if g._count_all(hs[k], "wall") > 0: walled.append(hs[k])
	for res in g.RES: g.bank[P][res] = 100.0
	for k in int(240.0 / g.SIM_DT): g._sim_step(g.SIM_DT)   # settle
	var fc_by := {}; var got_by := {}; var n := 0   # what the remote hosts deliver, per material
	for res in g.RES: fc_by[res] = 0.0; got_by[res] = 0.0
	var off := 0   # seconds a Firewall was off: its upkeep was not brought in time
	for sec in 300:
		for k in int(round(1.0 / g.SIM_DT)): g._sim_step(g.SIM_DT)
		for i in walled: if not bool(g.hosts[i].fw_on): off += 1
		for res in g.RES: g.bank[P][res] = 100.0   # nothing caps, nothing starves
		g._fc_gen += 1
		var fc: Dictionary = g._forecast(P)
		for r in g.RES:
			for src in (fc.from.get(r, {}) as Dictionary):
				if not str(src).begins_with("main node"): fc_by[r] = float(fc_by[r]) + float(fc.from[r][src])
		n += 1
		if sec % 30 == 29:   # the ledger keeps 30 s: "from:<host>:<res>" is what each host delivered
			var sums: Dictionary = g._ledger_sums(P)
			for key in sums:
				var parts := str(key).split(":")
				if parts[0] == "from": got_by[parts[2]] = float(got_by[parts[2]]) + float(sums[key])
	var f := 0.0; var m := 0.0; var bad := []; var said := []
	for r in g.RES:
		var fr := float(fc_by[r]) / n; var mr := float(got_by[r]) / 5.0
		f += fr; m += mr
		said.append("%s %.1f/%.1f" % [g.RES_NAME[r], fr, mr])
		if absf(fr - mr) > 0.3 * mr: bad.append(g.RES_NAME[r])
	check(absf(f - m) <= 0.2 * m, "Two workers for six hosts: the forecast of what the hosts deliver (%.1f/min) is within 20%% of what arrives (%.1f/min)" % [f, m])
	check(bad.is_empty(), "...and each material is within 30%% of what arrives, forecast/measured per minute: %s %s" % [", ".join(PackedStringArray(said)), str(bad)])
	check(not walled.is_empty() and off == 0, "...while the %d Firewalls on hosts that make no Intel get their upkeep first: never off (%d s off)" % [walled.size(), off])


func host_rates(secs: int) -> Dictionary:   # {fc, got}: what the remote hosts are forecast to deliver and do deliver, per material per minute
	var fc_by := {}; var got_by := {}         # (the bank stays stocked: nothing caps, nothing starves)
	for res in g.RES: fc_by[res] = 0.0; got_by[res] = 0.0
	for sec in secs:
		step(1.0)
		for res in g.RES: g.bank[P][res] = 100.0
		g._fc_gen += 1
		var fc: Dictionary = g._forecast(P)
		for r in g.RES:
			for src in (fc.from.get(r, {}) as Dictionary):
				if not str(src).begins_with("main node"): fc_by[r] = float(fc_by[r]) + float(fc.from[r][src]) / float(secs)
		if sec % 30 == 29:   # the ledger keeps 30 s: "from:<host>:<res>" is what each host delivered
			var sums: Dictionary = g._ledger_sums(P)
			for key in sums:
				var parts := str(key).split(":")
				if parts[0] == "from": got_by[parts[2]] = float(got_by[parts[2]]) + float(sums[key]) * 60.0 / float(secs)
	return {"fc": fc_by, "got": got_by}


func full_storage() -> void:   # (0.6.12) one Bot station's workers for a far File server's four producers: they cannot carry all of it home, so its
	fresh()                      # storage has no room for whole cycles, and every producer makes the same share of its output (the
	                             # harvester's Intel no longer fills it first); the forecast counts that share, material by material
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot"])
	var near: int = neighbours_of(home)[0]
	g._capture(near, P); g._set_builds(near, [])   # an empty relay: the File server is two hops out
	var h := far_host(near)
	var lay := ["intel", "lab", "cash", "cred"]
	g.hosts[h].type = "file"; g.hosts[h].slots = int(g.NODE_TYPES.file.slots)
	g._capture(h, P); g._set_builds(h, lay)
	for res in g.RES: g.bank[P][res] = 100.0
	for k in 8:
		step(30.0)
		for res in g.RES: g.bank[P][res] = 100.0
	var st0 := stored(h)
	watch_host(h)
	var r: Dictionary = host_rates(300)
	var st1 := stored(h)
	var made := {}; var full := {}   # per material over the run: what it made (what left for home, plus what its storage gained) and its whole output
	var mt := 0.0; var ft := 0.0
	for res in g.RES: made[res] = float(picked[res]) + float(st1[res]) - float(st0[res]); full[res] = 0.0
	for kind in lay:
		var out := str(g.BUILD_KINDS[kind].out)
		full[out] = float(full[out]) + float(g.BUILD_KINDS[kind].rate) * g._tmult(h, out) * cycles
	for res in g.RES: mt += float(made[res]); ft += float(full[res])
	var share := mt / maxf(0.0001, ft)   # (well short of whole cycles: the share is not just a last fraction now and then)
	check(cycles > 0 and share < 0.95, "Setup: %d workers cannot keep up with the far File server: its storage has no room for whole cycles, it makes %d%% of its output"
		% [int(g._worker_counts(P).total), int(round(100.0 * share))])
	var even := true; var said := []; var bad := []; var fs := []
	for res in g.RES:
		if float(full[res]) <= 0.0: continue
		var frac := float(made[res]) / float(full[res])
		if absf(frac - share) > 0.001: even = false
		said.append("%s %s of %s" % [g.RES_NAME[res], g._amt(float(made[res])), g._amt(float(full[res]))])
		var f := float(r.fc[res]); var m := float(r.got[res])
		fs.append("%s %.1f/%.1f" % [g.RES_NAME[res], f, m])
		if m <= 0.0 or absf(f - m) > 0.2 * m: bad.append(g.RES_NAME[res])
	check(even, "Every producer on it makes the same share of its output in %d cycles, the harvester no more than the rest: %s" % [cycles, ", ".join(PackedStringArray(said))])
	check(bad.is_empty(), "Its output is forecast within 20%% of what arrives, material by material (forecast/measured per minute: %s) %s" % [", ".join(PackedStringArray(fs)), str(bad)])


func phished() -> void:   # a rival's host you phish: its Firewall eats your Intel when the owner keeps none there; a storage
	fresh()                 # full of the owner's stock takes none of yours
	var home: int = int(g.rig[P])
	g._set_builds(home, ["intel", "bot"])
	var h: int = neighbours_of(home)[0]
	g.hosts[h].type = "pc"; g.hosts[h].slots = 3
	g._capture(h, g.RIVAL); g._set_builds(h, ["intel", "intel", "wall"])
	g.hosts[h].steal_by = P; g.hosts[h].steal_until = g._t + 600.0
	g._fc_gen += 1
	var src := str(g.hosts[h].name)
	var f := float((g._forecast(P).from.get("intel", {}) as Dictionary).get(src, 0.0))
	step(30.0)
	var sums := 0.0
	for k in 4:
		step(30.0)
		sums += float(g._ledger_sums(P).get("from:%d:intel" % h, 0.0))
	check(absf(f - per_cycle()) < 0.01 and absf(sums / 2.0 - f) <= 1.5, "Two harvesters and a Firewall, phished: the Firewall's Intel comes out of yours, %.0f/min forecast, %.1f/min arrive" % [f, sums / 2.0])
	g._set_builds(h, ["intel", "intel"])
	g.hosts[h].store = {g.RIVAL: {"intel": float(g.STORE_CAP)}}   # the owner's stock fills it and its workers cannot reach it
	g._fc_gen += 1
	var fc: Dictionary = g._forecast(P)
	f = float((fc.from.get("intel", {}) as Dictionary).get(src, 0.0))
	check(f == 0.0 and str(fc.limits.get("intel", [])).contains("storage full at"), "A storage full of the owner's stock: none of your harvest lands, none is forecast, and it says why (%s)" % str(fc.limits.get("intel", [])))


func main_node_down() -> void:   # a DDoSed main node sends no worker out: the remote hosts' output waits where it is
	var n := network()
	step(20.0)
	g.hosts[n.home].ddos_until = g._t + 60.0; g._fc_gen += 1
	var fc: Dictionary = g._forecast(P)
	var remote := 0.0
	for r in g.RES:
		for src in (fc.from.get(r, {}) as Dictionary): if not str(src).begins_with("main node"): remote += float(fc.from[r][src])
	check(remote == 0.0 and str(fc.limits.get("creds", [])).contains("your main node is under DDoS"), "Main node under DDoS: nothing from the hosts is forecast while it lasts (%.1f/min), and it says why" % remote)
