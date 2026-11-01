extends SceneTree
## The HUD's income forecast (feedback round B, section 3): what will reach the main node's bank per minute with the
## network as it stands, worked out from the network rather than extrapolated from early ledger events. It is checked
## against a long controlled simulation, and against the conditions that cut income: no free workers, a cut route,
## a Miner with no input beside a Firewall whose upkeep workers bring (0.6.12: the one input left), a building that
## cannot be paused, a full bank, a full storage its producers share evenly, a phished host, a main node under DDoS.
## Workers show activity, not an income. 0.6.16: a job moves one unit from a source straight to its destination and a
## worker is free where it delivers, so the forecast is checked against that too: a Firewall's upkeep from a nearer
## host's spare Intel never reaches the bank, the worker that brings a host its upkeep takes that host's output home
## (one round trip, as the forecast's workers needed say), and workers short of work are never left free.
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
	g.bank[P] = (g.START as Dictionary).duplicate()   # a match's opening bank (it scales with the economy)
	watch = -1; recording = false


func stock_bank() -> void:   # the bank half full of everything: nothing caps, nothing starves (half its cap, whatever the scale)
	for res in g.RES: g.bank[P][res] = 0.5 * g._cap(P, res)


var watch := -1    # a host whose production step() follows (-1: none, see watch_host):
var cycles := 0    # ...the production cycles it ran,
var fed := 0       # ...those after which its Firewalls were on (each ate its upkeep),
var picked := {}   # ...and what workers picked up there and carried off, per material
var _seen := {}    # (the loaded legs whose pickup is already counted)


func loaded_leg_from(f: Dictionary, i: int) -> bool:   # (0.6.16) one of P's workers setting off from host i with what it collected
	return str(f.kind) == "courier" and int(f.owner) == P and str(f.get("trip", "")) == "carry" and int(f.get("src", -1)) == i


func watch_host(i: int) -> void:   # start following host i from now on
	watch = i; cycles = 0; fed = 0; picked = {}; _seen = {}
	for res in g.RES: picked[res] = 0.0
	for f in g.flights:   # (what is already on its way was picked up before)
		if loaded_leg_from(f, i): _seen[int(f.id)] = true


var recording := false   # (0.6.16, see record) step() also keeps every new leg of P's workers and how they spend their time:
var legs := []           # ...{id, wid, trip, route, dest, cargo, job} in launch order (a loaded leg is a packet of its own)
var _leg_ids := {}
var busy_s := 0.0        # ...worker-seconds on a leg (empty to a pickup, loaded, heading home, held on the way)
var free_s := 0.0        # ...worker-seconds free


func record() -> void:   # from now on (until fresh()), every new leg and the workers' time
	recording = true; legs = []; _leg_ids = {}; busy_s = 0.0; free_s = 0.0
	for f in g.flights: _leg_ids[int(f.id)] = true   # (legs already under way are not recorded)


func next_leg(k: int) -> Dictionary:   # the leg the same worker set off on after legs[k] ({} if none yet)
	for j in range(k + 1, legs.size()):
		if int(legs[j].wid) == int(legs[k].wid): return legs[j]
	return {}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)):
		var left := float(g.hosts[watch].cyc) if watch >= 0 else 0.0
		g._sim_step(g.SIM_DT)
		if recording:
			for f in g.flights:
				if str(f.kind) != "courier" or int(f.owner) != P or _leg_ids.has(int(f.id)): continue
				_leg_ids[int(f.id)] = true
				legs.append({"id": int(f.id), "wid": int(f.wid), "trip": str(f.trip), "route": (f.route as Array).duplicate(), "dest": int(f.dest),
					"cargo": (f.cargo as Dictionary).duplicate(), "job": (f.get("job", {}) as Dictionary).duplicate()})
			var wc: Dictionary = g._worker_counts(P)
			busy_s += float(int(wc.collecting) + int(wc.carrying) + int(wc.joining) + int(wc.blocked)) * g.SIM_DT
			free_s += float(wc.idle) * g.SIM_DT
		if watch < 0: continue
		if float(g.hosts[watch].cyc) > left:   # its timer wrapped: the host ran a cycle
			cycles += 1
			if bool(g.hosts[watch].fw_on): fed += 1
		for f in g.flights:   # a worker leaving it loaded (0.6.16: its loaded leg is a packet of its own): what it picked up there, counted once
			if not loaded_leg_from(f, watch) or _seen.has(int(f.id)): continue
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
	var got := {}                        # (and "supply:<res>": what left the bank to supply hosts; "from:<host>:<res>": what each host delivered)
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
			if parts[0] == "from": got[str(key)] = float(got.get(str(key), 0.0)) + float(L.data[slot][key])
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
	direct_upkeep()
	paused()
	full_bank()
	no_early_spike()
	short_of_workers()
	bank_feeds_firewall("mixed")
	bank_feeds_firewall("clog")
	full_storage()
	phished()
	main_node_down()
	sabotaged_stations()
	clogged_host()
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
	var tip := " ".join(PackedStringArray(g._forecast_lines("workers").map(func(l): return str(l[0]))))   # (0.6.16) and its tooltip tells the rules as they are:
	var stale := []                                                                                      # no pool at the main node, no fourth-trip turn
	for words in ["every fourth trip", "free at your main node", "work from your main node"]: if tip.contains(words): stale.append(words)
	check(stale.is_empty(), "The Workers tooltip describes the 0.6.16 dispatch (building and upkeep strictly first, a worker free where it delivers), not the old main-node pool: stale %s in '%s'" % [str(stale), tip])
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
	                                    # (0.6.16: the worker that delivers it is free there and takes the host's output home)
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot"])   # workers, and no Intel made at the main node beyond its trickle
	var h: int = neighbours_of(home)[0]
	g._capture(h, P); g._set_builds(h, ["cash"])   # a lone Miner: no Intel on its host
	var miner: float = per_cycle() * float(g.BUILD_KINDS.cash.rate) * g._tmult(h, "cash")   # its Crypto a minute
	var upkeep: float = float(g.BUILD_KINDS.wall.use.intel)   # a Firewall's Intel a cycle
	g._fc_gen += 1
	var need0 := float(g._forecast(P).need)
	step(30.0)
	var got0 := track(60.0)   # (with input to make, its Intel would go out to it from the bank's stock)
	check(absf(rate("cash") - trickle() - miner) < 0.01 and float(got0["supply:intel"]) == 0.0,
		"A lone Miner needs no input: with no Intel on its host and none sent to it (%.1f/min) it adds its %.0f Crypto/min to the forecast (%.0f)" % [float(got0["supply:intel"]), miner, rate("cash")])
	g._set_builds(h, ["cash", "wall"]); g._fc_gen += 1   # a Firewall beside it: its upkeep must be brought
	var need1 := float(g._forecast(P).need)
	check(absf(rate("cash") - trickle() - miner) < 0.01 and absf(rate("intel") - trickle()) < 0.01 and absf(need1 - need0) < 0.001,
		"A Firewall beside it, its %s Intel a cycle brought by workers: the Miner still adds %.0f Crypto/min, the supplied Intel is not income (%.0f, %.0f), and one round trip takes the upkeep out and the Crypto back (%.2f workers needed, as without it)"
		% [g._amt(upkeep), miner, rate("cash"), rate("intel"), need1])
	step(30.0)
	watch_host(h); record()
	var secs := 180.0
	var got := track(secs)
	var sent: float = float(got["supply:intel"]) * secs / 60.0; var eaten: float = fed * upkeep   # (units over the run)
	var kept: float = g.UPKEEP_KEEP * upkeep   # (0.6.16) what a host that makes no Intel keeps within reach: it may differ at either end
	check(absf(float(got.cash) - rate("cash")) <= 2.5 and cycles > 0 and fed == cycles and absf(sent - eaten) <= kept + 0.001,
		"...which the simulation delivers (%.1f Crypto/min vs %.0f), the Firewall on in all %d cycles: %s Intel sent for the %s it ate (the %s cycles' upkeep the host keeps within reach may differ at either end)"
		% [float(got.cash), rate("cash"), cycles, g._amt(sent), g._amt(eaten), g._amt(g.UPKEEP_KEEP)])
	var ups := 0; var chained := 0; var empty_home := 0; var sent_for := 0   # (0.6.16) each delivery of upkeep to it, and what that worker did next
	for k in legs.size():
		var l: Dictionary = legs[k]
		if str(l.trip) == "home" and int(l.route[0]) == h: empty_home += 1
		if str(l.trip) == "fetch" and int((l.job as Dictionary).get("src", -1)) == h: sent_for += 1   # a worker sent there empty to collect
		if str(l.trip) != "carry" or int(l.dest) != h or not (l.cargo as Dictionary).has("intel"): continue
		var nx := next_leg(k)
		if nx.is_empty(): continue   # (the last one, still under way)
		ups += 1
		if str(nx.trip) == "carry" and int(nx.route[0]) == h and int(nx.dest) == home and (nx.cargo as Dictionary).has("cash"): chained += 1
	var busy := busy_s / secs   # workers busy on average
	check(ups > 0 and chained == ups and empty_home == 0 and absf(busy - need1) <= 0.2 * need1,
		"...on one round trip a cycle: the worker that brings the upkeep takes the Crypto home (%d of %d deliveries; %d workers sent there empty to collect it, %d empty legs home), so the workers are busy %.2f on average, as the forecast's %.2f needed"
		% [chained, ups, sent_for, empty_home, busy, need1])
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


func direct_upkeep() -> void:   # (0.6.16) a Firewall's upkeep comes from the nearest place that can spare it, straight to its host: here
	fresh()                       # a host with twice the Intel the Firewall eats, between it and the main node. That Intel never reaches the
	var home: int = int(g.rig[P])   # bank (host -> site, not host -> main node -> site), and the forecast leaves it out of the bank's income
	g._set_builds(home, ["bot"])   # workers, and no Intel made at the main node beyond its trickle
	var a: int = neighbours_of(home)[0]
	g._capture(a, P); g.hosts[a].type = "pc"; g.hosts[a].slots = 3
	g._set_builds(a, ["intel", "intel"])
	var b := far_host(a)
	g._capture(b, P); g.hosts[b].type = "pc"; g.hosts[b].slots = 3
	g._set_builds(b, ["cash", "wall"])   # a Miner and a Firewall: no Intel of its own
	var upkeep: float = float(g.BUILD_KINDS.wall.use.intel)
	var harvest: float = 2.0 * float(g.BUILD_KINDS.intel.rate) * g._tmult(a, "intel")   # a's Intel a cycle
	var miner: float = float(g.BUILD_KINDS.cash.rate) * g._tmult(b, "cash")              # b's Crypto a cycle
	var an := str(g.hosts[a].name); var bn := str(g.hosts[b].name)
	g._fc_gen += 1
	var fc: Dictionary = g._forecast(P)
	var fa := float((fc.from.get("intel", {}) as Dictionary).get(an, 0.0)); var fb := float((fc.from.get("cash", {}) as Dictionary).get(bn, 0.0))
	check(g._leg_time(P, a, b) < g._leg_time(P, home, b) and absf(fa - per_cycle() * (harvest - upkeep)) < 0.01 and absf(fb - per_cycle() * miner) < 0.01,
		"%s is nearer %s's Firewall than the main node: the forecast has it give the upkeep straight there, so its Intel at the bank is its harvest less the upkeep (%.0f/min) beside %s's %.0f Crypto/min"
		% [an, bn, fa, bn, fb])
	step(60.0)   # past the start
	watch_host(b); record()
	var secs := 240.0
	var got := track(secs)
	var ups := 0; var direct := 0; var via := 0   # Intel delivered to b: straight from a, or by way of the main node
	for l in legs:
		if str(l.trip) != "carry" or int(l.dest) != b or not (l.cargo as Dictionary).has("intel"): continue
		ups += 1
		if (l.route as Array).has(home): via += 1
		elif int(l.route[0]) == a: direct += 1
	check(ups > 0 and direct == ups and float(got["supply:intel"]) == 0.0 and cycles > 0 and fed == cycles,
		"...and so the workers take it: %d of %d units of upkeep went %s → %s straight (%d by way of the main node), %.1f Intel/min left the bank for it, the Firewall on in %d of %d cycles"
		% [direct, ups, an, bn, via, float(got["supply:intel"]), fed, cycles])
	var ma := float(got.get("from:%d:intel" % a, 0.0))
	check(absf(ma - fa) <= maxf(2.5, 0.12 * fa) and absf(float(got.get("from:%d:cash" % b, 0.0)) - fb) <= maxf(2.5, 0.12 * fb),
		"...and what reaches the bank from them is what the forecast says: %s's Intel %.1f/min (forecast %.0f), %s's Crypto %.1f/min (forecast %.0f)"
		% [an, ma, fa, bn, float(got.get("from:%d:cash" % b, 0.0)), fb])


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


# (0.6.16) With two workers for six hosts the dispatcher also spends worker time the forecast's round trips do not count:
# a Firewall host's upkeep carried straight from a neighbour, room made for it, a worker's leg to the host it is sent
# from. The total stays within 20%; each material and each host within SHORT_TOL.
const SHORT_TOL := 0.4


func short_of_workers() -> void:   # two workers for six hosts: the forecast follows the dispatcher (0.6.16: the Firewalls' upkeep strictly
	fresh()                          # first, from the nearest place that can spare it; then the hosts about to fill up, the hosts in turn;
	                                 # supplies only where they fit), material by material and host by host, not one even share for everything
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
	var b0: Array = (g.hosts[home].builds as Array).duplicate()   # (0.6.18: the flow doubled, so the same shortage takes twice the workers: two
	for k in b0.size():                                           #  Bot stations at the main node, four workers for six hosts)
		if str(b0[k]) == "" and b0.count("bot") < 2: b0[k] = "bot"
	g._set_builds(home, b0); g._tick_teams(0.0)
	stock_bank()
	step(240.0)   # settle
	record()
	var fc_by := {}; var got_by := {}; var n := 0   # what the remote hosts deliver, per material
	var fc_host := {}; var got_host := {}           # ...and per host (by name), all materials together
	for res in g.RES: fc_by[res] = 0.0; got_by[res] = 0.0
	var off := 0   # seconds a Firewall was off: its upkeep was not brought in time
	var fw_fc := 0.0; var fw_got := 0.0   # (0.6.19) the bank's Intel for the Firewalls: forecast, and what workers took out of it
	var secs := 600   # (0.6.16: workers go on from where they deliver, so the far hosts are served in no fixed rhythm: a slow material
	for sec in secs:  # such as the Lab's Research, about a unit a minute here, reads only a handful of units in any 300 s, so it is measured over 600)
		step(1.0)
		for i in walled: if not bool(g.hosts[i].fw_on): off += 1
		stock_bank()   # nothing caps, nothing starves
		g._fc_gen += 1
		var fc: Dictionary = g._forecast(P)
		for r in g.RES:
			for src in (fc.from.get(r, {}) as Dictionary):
				if str(src).begins_with("main node"): continue
				fc_by[r] = float(fc_by[r]) + float(fc.from[r][src])
				fc_host[str(src)] = float(fc_host.get(str(src), 0.0)) + float(fc.from[r][src])
		for what in (fc.use.get("intel", {}) as Dictionary): if str(what).begins_with("Firewall at"): fw_fc += float(fc.use.intel[what])
		n += 1
		if sec % 30 == 29:   # the ledger keeps 30 s: "from:<host>:<res>" is what each host delivered
			var sums: Dictionary = g._ledger_sums(P)
			fw_got += float(sums.get("out:supply:intel", 0.0))
			for key in sums:
				var parts := str(key).split(":")
				if parts[0] != "from": continue
				got_by[parts[2]] = float(got_by[parts[2]]) + float(sums[key])
				var hn := str(g.hosts[int(parts[1])].name)
				got_host[hn] = float(got_host.get(hn, 0.0)) + float(sums[key])
	var f := 0.0; var m := 0.0; var bad := []; var said := []
	for r in g.RES:
		var fr := float(fc_by[r]) / n; var mr := float(got_by[r]) * 60.0 / float(secs)
		f += fr; m += mr
		said.append("%s %.1f/%.1f" % [g.RES_NAME[r], fr, mr])
		if absf(fr - mr) > SHORT_TOL * mr: bad.append(g.RES_NAME[r])
	check(absf(f - m) <= 0.2 * m, "Two workers for six hosts: the forecast of what the hosts deliver (%.1f/min) is within 20%% of what arrives (%.1f/min)" % [f, m])
	check(bad.is_empty(), "...and each material is within %d%% of what arrives, forecast/measured per minute: %s %s" % [int(SHORT_TOL * 100.0), ", ".join(PackedStringArray(said)), str(bad)])
	var hbad := []; var hsaid := []   # (0.6.16) and each host (the "From:" line). (0.6.18) Intel it gives a Firewall host rides its own trips, so it is
	                                  # taken off what they bring home; the worker who brings it carries that host's output home
	for k in hs.size():
		var hn := str(g.hosts[hs[k]].name)
		var fh := float(fc_host.get(hn, 0.0)) / n; var mh := float(got_host.get(hn, 0.0)) * 60.0 / float(secs)
		hsaid.append("%s %.1f/%.1f" % [hn, fh, mh])
		if absf(fh - mh) > SHORT_TOL * mh: hbad.append(hn)
	check(hbad.is_empty(), "...and each host is within %d%% of what arrives from it, all materials, forecast/measured per minute: %s %s" % [int(SHORT_TOL * 100.0), ", ".join(PackedStringArray(hsaid)), str(hbad)])
	var fwf := fw_fc / n; var fwm := fw_got * 60.0 / float(secs)
	check(absf(fwf - fwm) <= maxf(2.5, SHORT_TOL * fwm), "...and the bank's Intel for those Firewalls (what their neighbours' trips do not bring) is forecast within %d%%: %.1f/min forecast, %.1f/min taken out"
		% [int(SHORT_TOL * 100.0), fwf, fwm])
	check(not walled.is_empty() and off == 0, "...while the %d Firewalls on hosts that make no Intel get their upkeep first: never off (%d s off)" % [walled.size(), off])
	var homes := 0
	for l in legs: if str(l.trip) == "home": homes += 1
	check(free_s <= 0.01 * (busy_s + free_s) and homes == 0,
		"...and with more work than workers, they are never left free: %.1f of %.0f worker-seconds free, %d empty legs home" % [free_s, busy_s + free_s, homes])


func bank_feeds_firewall(scen: String) -> void:   # (0.6.19) a Firewall host's upkeep its neighbours' trips do not bring comes from the bank,
	fresh()                                       # and the forecast says so: "mixed", the workers are short; "clog", the neighbour that
	var home: int = int(g.rig[P])                 # could give stops whole, its Crypto unwanted by a full Crypto bank
	var hs := []
	var frontier := [home]; var seen := {home: true}
	while hs.size() < 7 and not frontier.is_empty():
		var nxt := []
		for f0 in frontier:
			for nb in g.hosts[int(f0)].links:
				if seen.has(int(nb)): continue
				seen[int(nb)] = true
				if hs.size() < 7 and int(g.hosts[int(nb)].owner) == g.NEUTRAL: hs.append(int(nb)); g._capture(int(nb), P); nxt.append(int(nb))
		frontier = nxt
	for h in hs: g.hosts[h].type = "pc"; g.hosts[h].slots = 3
	var fw := -1; var giver := -1   # a Firewall host farther from home than a neighbour that may give it Intel
	for a in hs:
		for b in hs:
			if fw >= 0 or a == b or not (g.hosts[a].links as Array).has(b): continue
			if g._leg_time(P, b, a) <= g._leg_time(P, b, home) + 0.0001 and g._leg_time(P, a, home) > g._leg_time(P, b, home): fw = a; giver = b
	var lay := {}
	if scen == "mixed": lay[fw] = ["wall", "wall", "cash"]; lay[giver] = ["intel", "cash", "cred"]
	else: lay[fw] = ["wall", "wall"]; lay[giver] = ["intel", "intel", "cash"]
	var fill := [["cash", "cred", "lab"], ["intel", "cash", "lab"], ["cred", "cash", "intel"], ["lab", "cash", "cred"], ["cash", "cash", "cred"]]
	if scen == "clog": fill = [["cred", "lab", "cred"], ["lab", "cred", "lab"]]
	var fi := 0
	for h in hs:
		if not lay.has(h): lay[h] = fill[fi % fill.size()]; fi += 1
		g._set_builds(h, lay[h])
	var b0: Array = (g.hosts[home].builds as Array).duplicate()
	for k in b0.size(): if str(b0[k]) == "" and b0.count("bot") < 2: b0[k] = "bot"
	g._set_builds(home, b0); g._tick_teams(0.0)
	var feed := func() -> void:
		stock_bank()
		if scen == "clog": g.bank[P].cash = g._cap(P, "cash")
	feed.call()
	for k in 8: step(30.0); feed.call()
	var fcs := 0.0; var got := 0.0; var n := 0; var secs := 300
	var line := "Firewall at %s" % str(g.hosts[fw].name)
	for sec in secs:
		step(1.0); feed.call()
		g._fc_gen += 1
		fcs += float((g._forecast(P).use.get("intel", {}) as Dictionary).get(line, 0.0)); n += 1
		if sec % 30 == 29: got += float(g._ledger_sums(P).get("out:supply:intel", 0.0))
	var f := fcs / n; var m := got * 60.0 / float(secs)
	check(fw >= 0 and m > 2.5 and absf(f - m) <= maxf(2.5, SHORT_TOL * m),
		"%s: the bank's Intel for a Firewall host's upkeep that its neighbours' trips do not bring is in the forecast (%.1f/min forecast, %.1f/min taken out of the bank)"
		% ["Workers short" if scen == "mixed" else "The neighbour that could give stops whole", f, m])


func host_rates(secs: int) -> Dictionary:   # {fc, got}: what the remote hosts are forecast to deliver and do deliver, per material per minute
	var fc_by := {}; var got_by := {}         # (the bank stays stocked: nothing caps, nothing starves)
	for res in g.RES: fc_by[res] = 0.0; got_by[res] = 0.0
	for sec in secs:
		step(1.0)
		stock_bank()
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
	g._capture(near, P); g._set_builds(near, [])   # two empty relays: the File server is three hops out (0.6.14: the crumbs of a
	var mid := far_host(near)                       # shared cycle ride home with whole units, so two hops no longer outrun them)
	g._capture(mid, P); g._set_builds(mid, [])
	var h := -1
	for nb in g.hosts[mid].links:
		var n := int(nb)
		if n != near and int(g.hosts[n].owner) == g.NEUTRAL and not g.hosts[home].links.has(n) and not g.hosts[near].links.has(n): h = n; break
	var lay := ["intel", "lab", "cash", "cred"]
	g.hosts[h].type = "file"; g.hosts[h].slots = int(g.NODE_TYPES.file.slots)
	g._capture(h, P); g._set_builds(h, lay)
	stock_bank()
	for k in 8:
		step(30.0)
		stock_bank()
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
	g._set_builds(h, ["cash", "lab"])   # (0.6.14) no harvester: a Miner and a Lab fill a storage just the same
	g.hosts[h].store = {g.RIVAL: {"creds": float(g.STORE_CAP)}}
	g._fc_gen += 1
	fc = g._forecast(P)
	var got_none := float((fc.from.get("cash", {}) as Dictionary).get(src, 0.0)) == 0.0 and float((fc.from.get("research", {}) as Dictionary).get(src, 0.0)) == 0.0
	check(got_none and str(fc.limits.get("cash", [])).contains("storage full at") and str(fc.limits.get("research", [])).contains("storage full at"),
		"...and a phished Miner and Lab with no harvester beside them get the same reason (%s)" % str(fc.limits.get("cash", [])))


func main_node_down() -> void:   # a DDoSed main node sends no worker out: the remote hosts' output waits where it is
	var n := network()
	step(20.0)
	g.hosts[n.home].ddos_until = g._t + 60.0; g._fc_gen += 1
	var fc: Dictionary = g._forecast(P)
	var remote := 0.0
	for r in g.RES:
		for src in (fc.from.get(r, {}) as Dictionary): if not str(src).begins_with("main node"): remote += float(fc.from[r][src])
	check(remote == 0.0 and str(fc.limits.get("creds", [])).contains("your main node is under DDoS"), "Main node under DDoS: nothing from the hosts is forecast while it lasts (%.1f/min), and it says why" % remote)


func sabotaged_stations() -> void:   # (0.6.14) workers Sabotage keeps at their stations carry nothing: the forecast leaves them out
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot", "bot"])   # every station on the main node
	var h: int = neighbours_of(home)[0]
	g.hosts[h].type = "pc"; g.hosts[h].slots = 3
	g._capture(h, P); g._set_builds(h, ["cred", "cred", "cred"])
	step(40.0)
	var src := str(g.hosts[h].name)
	g._fc_gen += 1
	var before := float((g._forecast(P).from.get("creds", {}) as Dictionary).get(src, 0.0))
	g.hosts[home].sabot_until = g._t + 60.0
	step(6.0)   # the workers that were out finish their legs and stop where they are (0.6.16: free where they deliver)
	g._fc_gen += 1
	var fc: Dictionary = g._forecast(P)
	var f := float((fc.from.get("creds", {}) as Dictionary).get(src, 0.0))
	var c0 := float(g.bank[P].creds)
	step(48.0)
	var got: float = (float(g.bank[P].creds) - c0 - 48.0 * g.MAIN_INCOME) * 60.0 / 48.0
	check(before > 0.5 and f <= 0.01 and str(fc.limits.get("creds", [])).contains("Sabotage") and got <= 0.5,
		"Sabotage on the main node, where all the stations are: the host's Credentials leave the forecast (%.0f → %.0f/min) and it says why (%s); none arrive (%.1f/min)"
		% [before, f, str(fc.limits.get("creds", [])), got])


func clogged_host() -> void:   # (0.6.14) one output its bank cannot take fills the host's storage, and then the whole host stops
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, ["bot", "bot"])
	var h: int = neighbours_of(home)[0]
	g.hosts[h].type = "pc"; g.hosts[h].slots = 3
	g._capture(h, P); g._set_builds(h, ["intel", "intel", "cash"])
	var fill: float = g.STORE_CAP / (float(g.BUILD_KINDS.cash.rate) * g._tmult(h, "cash"))   # the cycles its Crypto alone takes to fill the storage
	for k in int(round(g.PROD_CYCLE * 2.0 * fill / g.SIM_DT)):   # the Crypto bank stays full: the host's Crypto piles up until its storage is full (twice over)
		g.bank[P].cash = g._cap(P, "cash"); g.bank[P].intel = 0.5 * g._cap(P, "intel")   # (the Intel bank never fills)
		g._sim_step(g.SIM_DT)
	var src := str(g.hosts[h].name)
	g._fc_gen += 1
	var fc: Dictionary = g._forecast(P)
	var f := float((fc.from.get("intel", {}) as Dictionary).get(src, 0.0))
	var i0 := float(g.bank[P].intel)
	for k in int(round(60.0 / g.SIM_DT)):
		g.bank[P].cash = g._cap(P, "cash")
		g._sim_step(g.SIM_DT)
	var got: float = float(g.bank[P].intel) - i0 - 60.0 * g.MAIN_INCOME
	check(g._store_room(h) < 1.0 and f <= 0.01 and str(fc.limits.get("intel", [])).contains("Crypto bank is full") and got <= 0.5,
		"A host whose storage is full of Crypto its bank cannot take: its Intel leaves the forecast too (%.0f/min) and it says why (%s); none arrives (%.1f in 60 s)"
		% [f, str(fc.limits.get("intel", [])), got])
