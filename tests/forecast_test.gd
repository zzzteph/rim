extends SceneTree
## The HUD's income forecast (feedback round B, section 3): what will reach the main node's bank per minute with the
## network as it stands, worked out from the network rather than extrapolated from early ledger events. It is checked
## against a long controlled simulation, and against the conditions that cut income: no spare couriers, a cut route,
## a starved converter (and its supply), a paused producer, a full bank. Bots show courier capacity, not an income.
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
	g.bank[P] = {"bots": 40.0, "intel": 60.0, "cash": 30.0, "creds": 30.0, "research": 30.0}


func step(secs: float) -> void:
	for k in int(round(secs / g.SIM_DT)): g._sim_step(g.SIM_DT)


func rate(res: String) -> float: return float(g._forecast(P).rate[res])


func measured(res: String, secs: float) -> float:   # what actually reached the bank per minute over secs of play (refunds and returning couriers aside)
	var before := received(res)
	step(secs)
	return (received(res) - before) * 60.0 / secs


var _total := {}
func received(res: String) -> float:   # a running total of "in" entries, kept by sampling the ledger every second
	return float(_total.get(res, 0.0))


func track(secs: float) -> Dictionary:   # per-minute received per resource over secs, from the ledger's 1-s buckets
	var got := {}
	for res in g.RES: got[res] = 0.0
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
	no_couriers()
	cut_route()
	starved_and_supplied()
	paused()
	full_bank()
	no_early_spike()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func network() -> Dictionary:   # a main node with a harvester and a station, a near host with its own couriers, a far one served from home
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
	step(30.0)   # past the start: storages and couriers settle
	var fc := {}
	for res in g.RES: fc[res] = rate(res)
	var got := track(120.0)
	var bad := []
	for res in ["intel", "cash", "creds", "research"]:
		var tol := maxf(2.5, 0.12 * float(fc[res]))
		if absf(float(got[res]) - float(fc[res])) > tol: bad.append("%s %.1f vs %.1f" % [res, float(got[res]), float(fc[res])])
	check(bad.is_empty(), "Forecast matches 120 s of steady play within 12%% (Intel %.0f/%.0f, Crypto %.0f/%.0f, Creds %.0f/%.0f) %s" %
		[float(fc.intel), float(got.intel), float(fc.cash), float(got.cash), float(fc.creds), float(got.creds), str(bad)])
	var from: Dictionary = (g._forecast(P).from as Dictionary).get("creds", {})
	check(from.has(str(g.hosts[n.far].name)) and from.has("main node trickle"), "It says where each bank's income comes from (%s)" % str(from))
	var before: float = rate("cash")
	step(10.0)
	check(absf(rate("cash") - before) < 0.01, "A steady network shows a steady forecast (%.1f, then %.1f)" % [before, rate("cash")])


func no_couriers() -> void:
	var n := network()
	g._set_builds(n.home, ["intel"])   # no station at home: the fleet stays as it is
	step(20.0)
	var with: float = rate("creds")
	g._cmd(["reserve", 40])
	g.bank[P].bots = 10.0
	var fc: Dictionary = g._forecast(P)
	check(with > 12.5 and rate("creds") <= 12.5 + 0.01 and (fc.limits as Dictionary).get("creds", []).has("not enough couriers"),
		"No spare couriers: the far host's Credentials leave the forecast at once (%.0f → %.0f), and it says why" % [with, rate("creds")])
	check(str(g._hud_rate("bots")[0]).contains("0 spare"), "The Bots column shows courier capacity, not income: '%s'" % str(g._hud_rate("bots")[0]))
	var got := track(60.0)
	check(float(got.creds) <= 12.0 + 2.5, "...and none arrive (%.1f/min: the trickle only)" % float(got.creds))


func cut_route() -> void:
	var n := network()
	step(20.0)
	g._capture(n.near, g.RIVAL)   # the far host's only way home
	var fc: Dictionary = g._forecast(P)
	check(rate("creds") <= 12.0 + 0.01 and str((fc.limits as Dictionary).get("creds", [])).contains("no route home"), "A cut route: the far host's output is not counted (%.0f), and the reason is named" % rate("creds"))
	var got := track(40.0)
	check(float(got.creds) <= 12.0 + 2.5, "...and it does not arrive (%.1f/min)" % float(got.creds))


func starved_and_supplied() -> void:
	fresh()
	var home: int = int(g.rig[P])
	g._set_builds(home, [])
	var h: int = neighbours_of(home)[0]
	g._capture(h, P); g._set_builds(h, ["cash"])   # a lone Miner: no Intel of its own
	step(10.0)
	check(rate("cash") <= 12.0 + 0.01, "A starved Miner adds nothing to the Crypto forecast (%.0f: the trickle)" % rate("cash"))
	g._cmd(["want", h, "intel", 2])
	check(rate("cash") >= 24.0 - 0.01 and rate("intel") <= 12.0 + 0.01, "Kept supplied with Intel it adds 12 Crypto/min; the supplied Intel is not income (%.0f, %.0f)" % [rate("cash"), rate("intel")])
	step(20.0)
	var got := track(90.0)
	check(absf(float(got.cash) - rate("cash")) <= 3.0, "...which the simulation delivers (%.1f/min vs %.0f)" % [float(got.cash), rate("cash")])
	g.bank[P].intel = 0.0; g._fc_gen += 1
	check(absf(rate("cash") - 24.0) < 0.01, "With the bank's Intel gone it still runs on what the trickle brings in (1 a cycle): %.0f" % rate("cash"))
	var got2 := track(60.0)
	check(absf(float(got2.cash) - 24.0) <= 3.0, "...as the simulation does (%.1f/min)" % float(got2.cash))
	g.hosts[home].ddos_until = g._t + 60.0; g.bank[P].intel = 0.0; g._fc_gen += 1   # and with the main node down, nothing comes in to send
	check(rate("cash") <= 0.01, "With no Intel to send at all, the supplied Miner is starved again (%.0f)" % rate("cash"))


func paused() -> void:
	var n := network()
	step(10.0)
	var before: float = rate("cash")
	g._cmd(["produce", n.near, 2])   # pause the near host's Miner
	check(g._producer_paused(n.near, 2) and rate("cash") <= before - 11.9, "Pausing a Miner takes its Crypto out of the forecast at once (%.0f → %.0f)" % [before, rate("cash")])
	check(rate("intel") > 0.0, "...and the Intel it no longer uses is forecast to come home instead (%.0f)" % rate("intel"))


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
	var steady: float = 12.0 + 12.0 * float(g.BUILD_KINDS.intel.rate) * g._tmult(home, "intel")
	check(absf(early - rate("intel")) < 0.01 and absf(early - steady) < 0.01, "From the first second the forecast is the network's steady rate (%.0f Intel/min: trickle + harvester)" % early)
	check(not str(g._hud_rate("intel")[0]).begins_with("~"), "No early-estimate tilde: it is a forecast, not a measurement")
