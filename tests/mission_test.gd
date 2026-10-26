extends SceneTree
## The network objective mission (fictional game state): scan reveal, temporary access distinct from ownership,
## objective-packet delivery and progress, alert and the owner's route interruption, access expiry, capture/route
## transitions, and the two resolve outcomes. Runs on the real simulation (_sim_step), AIs off unless a case says so.
##   godot --headless --path . --script tests/mission_test.gd
var g
var P := 1
var R := 2
var checks := 0
var failures := []
var report := {}


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func fresh() -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._open_menu(false)
	g.panel_box = null
	P = g.PLAYER; R = g.RIVAL


func own(i: int, bots: float) -> void:
	g.hosts[i].owner = P; g.hosts[i].bots = bots; g.hosts[i].assign = -1; g.hosts[i].live = false; g._set_builds(i, ["bot"])


func corridor() -> Array:   # [home, mid, target] — a two-street path so the owner can cut the middle
	var home: int = int(g.rig[P])
	for m in g.hosts[home].links:
		if g.hosts[int(m)].rig: continue
		for t in g.hosts[int(m)].links:
			if int(t) != home and not g.hosts[home].links.has(t) and not g.hosts[int(t)].rig: return [home, int(m), int(t)]
	return []


func step(secs: float, watch_home := -1, src := -1) -> int:
	var n := int(round(secs / g.SIM_DT))
	var delivered := 0
	for k in n:
		var before = g._records_got(P, src) if src >= 0 else 0.0
		g._sim_step(g.SIM_DT)
		if src >= 0 and g._records_got(P, src) > before: delivered += 1
	return delivered


func run() -> void:
	access_vs_ownership()
	extraction_and_progress()
	alert_and_response()
	transitions()
	resolve_outcomes()
	determinism()
	print(JSON.stringify({"checks": checks, "failures": failures, "report": report}))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/implemented_ui"))
	var f := FileAccess.open("res://review/implemented_ui/mission.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures, "report": report}, "\t")); f.close()
	g.free(); quit(0 if failures.is_empty() else 1)


func access_vs_ownership() -> void:
	fresh()
	var c := corridor(); check(c.size() == 3, "Fixture: a two-street corridor home→mid→target")
	var home: int = c[0]; var mid: int = c[1]; var t: int = c[2]
	own(mid, 30.0)
	g.hosts[t].owner = R; g.hosts[t].bots = 120.0; g._set_builds(t, ["cash", "cash"])
	g._setup_mission(t, 5, "Kessler Finance", "A neighbourhood's records")
	check(g._is_mission(t), "A target carries an authored objective")
	# before scanning, access is refused
	g.intel[P] = 500.0; g.creds[P] = 500.0
	check(g._can_access(P, t) != "", "Access refused before the target is scanned")
	g._apply_cmd(P, ["access", t])
	check(not g._access_live(P, t), "A pre-scan access command does nothing")
	g._mark_scanned(P, t)
	check(g._can_access(P, t) == "", "Scanned, with a foothold and the resources, access is available")
	# a huge Credentials bank alone is not enough without a route foothold
	fresh()
	var t2 := -1
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == g.NEUTRAL and not g.hosts[i].rig:
			var adj := false
			for o in g.hosts[i].links:
				if int(g.hosts[int(o)].owner) == P: adj = true
			if not adj: t2 = i; break
	g.hosts[t2].owner = R; g.hosts[t2].bots = 80.0; g._setup_mission(t2, 5)
	g._mark_scanned(P, t2); g.creds[P] = 100000.0; g.intel[P] = 100000.0
	check(g._access_foothold(P, t2) < 0 and g._can_access(P, t2) != "", "No reachable foothold: a giant Credentials bank still cannot open access")
	# cost is target-specific (scales with records)
	fresh()
	var a := corridor(); own(a[1], 30.0)
	g.hosts[a[2]].owner = R; g._setup_mission(a[2], 4); g._mark_scanned(P, a[2])
	var cheap = g._access_cost(a[2])
	g._setup_mission(a[2], 40)
	var dear = g._access_cost(a[2])
	check(float(dear.intel) > float(cheap.intel) and float(dear.creds) > float(cheap.creds), "Access cost scales with the target's records")


func extraction_and_progress() -> void:
	fresh()
	var c := corridor(); var home: int = c[0]; var mid: int = c[1]; var t: int = c[2]
	own(mid, 30.0)
	g.hosts[t].owner = R; g.hosts[t].bots = 200.0; g._set_builds(t, ["cash"])
	g._setup_mission(t, 6); g._mark_scanned(P, t)
	g.intel[P] = 500.0; g.creds[P] = 500.0
	var intel0 := float(g.intel[P]); var creds0 := float(g.creds[P])
	g._apply_cmd(P, ["access", t])
	check(g._access_live(P, t) and int(g.hosts[t].owner) == R, "Temporary access is live and the target is still the rival's (access ≠ ownership)")
	var cost = g._access_cost(t)
	check(abs((intel0 - float(g.intel[P])) - float(cost.intel)) < 0.01 and abs((creds0 - float(g.creds[P])) - float(cost.creds)) < 0.01, "Access charged exactly its cost")
	check(g._built_kinds(t).size() == 1 and int(g.hosts[t].bots) == 200, "Access granted no buildings and no bots of the target")
	var got = step(30.0, home, t)
	check(got >= 1 and g._records_got(P, t) >= 1.0, "Objective packets reach home and advance progress (%d delivered)" % got)
	report["delivery_30s"] = got
	# complete it
	g.hosts[t].access_until = g._t + 100.0   # keep access open for the test
	step(40.0, home, t)
	check(g._mission_complete(P, t), "Delivery completes the mission (%d / %d)" % [int(g._records_got(P, t)), int(g.hosts[t].records_total)])
	check(int(g.hosts[t].owner) == R, "Completing it did not capture the target")


func alert_and_response() -> void:
	fresh()
	var c := corridor(); var home: int = c[0]; var mid: int = c[1]; var t: int = c[2]
	own(mid, 30.0)
	g.hosts[t].owner = g.RIVAL; g.hosts[t].bots = 200.0; g._set_builds(t, ["cash"])
	g.ais = [g.RIVAL]   # make the owner an AI so it responds
	g._setup_mission(t, 50); g._mark_scanned(P, t); g.intel[P] = 500.0; g.creds[P] = 500.0
	g._apply_cmd(P, ["access", t])
	var cut_seen := false; var alert_peak := 0.0; var cost_seen := false
	for k in int(40.0 / g.SIM_DT):
		g._sim_step(g.SIM_DT)
		alert_peak = maxf(alert_peak, float(g.hosts[t].get("alert", 0.0)))
		if float(g.hosts[mid].get("route_off", 0.0)) > 0.0:
			cut_seen = true
			if g._routing_down(mid): cost_seen = true   # while isolated, the node's own routing is down too
	check(alert_peak >= g.MIS_ALERT_RESPOND * 0.5, "Transferring records raises the alert meter (peak %.0f)" % alert_peak)
	check(cut_seen, "At high alert the AI owner isolates a node on the extraction route")
	report["alert_peak"] = snappedf(alert_peak, 1.0)
	# isolating the mid node also stops its OWN service (route_off blocks its routing)
	check(cost_seen, "The isolated node's own routing is down too (interruption has a cost)")


func transitions() -> void:
	# access expiry: extraction stops, progress is kept, no catch-up burst on re-open
	fresh()
	var c := corridor(); var home: int = c[0]; var mid: int = c[1]; var t: int = c[2]
	own(mid, 30.0); g.hosts[t].owner = R; g.hosts[t].bots = 200.0; g._set_builds(t, ["cash"]); g._setup_mission(t, 50)
	g._mark_scanned(P, t); g.intel[P] = 500.0; g.creds[P] = 500.0
	g._apply_cmd(P, ["access", t]); g.hosts[t].access_until = g._t + 3.0
	step(5.0, home, t)
	var kept = g._records_got(P, t)
	check(not g._access_live(P, t), "Access expires on its timer")
	var after = step(5.0, home, t)
	check(after == 0 and g._records_got(P, t) == kept, "After expiry nothing more is delivered; progress is kept (%d)" % int(kept))
	g.intel[P] = 500.0; g.creds[P] = 500.0; g._apply_cmd(P, ["access", t])
	var burst = step(1.0, home, t)
	check(burst <= 1, "Re-opening access makes no catch-up burst (%d in the first second)" % burst)
	# a cut route pauses delivery without losing progress
	fresh()
	c = corridor(); home = c[0]; mid = c[1]; t = c[2]
	own(mid, 30.0); g.hosts[t].owner = R; g.hosts[t].bots = 200.0; g._set_builds(t, ["cash"]); g._setup_mission(t, 50)
	g._mark_scanned(P, t); g.intel[P] = 500.0; g.creds[P] = 500.0; g._apply_cmd(P, ["access", t])
	step(6.0, home, t)
	g.hosts[mid].route_off = 12.0
	step(3.0, home, t)                       # packets already in flight still land
	var settled = g._records_got(P, t)
	var during = step(6.0, home, t)          # mid stays isolated: no new packets depart
	check(during == 0 and g._records_got(P, t) == settled, "A cut route pauses new delivery; delivered progress holds")
	# capturing the target ends access
	fresh()
	c = corridor(); mid = c[1]; t = c[2]
	own(mid, 30.0); g.hosts[t].owner = R; g.hosts[t].bots = 5.0; g._setup_mission(t, 50)
	g._mark_scanned(P, t); g.intel[P] = 500.0; g.creds[P] = 500.0; g._apply_cmd(P, ["access", t])
	g._capture(t, P)
	check(not g._access_live(P, t) and int(g.hosts[t].owner) == P, "Capturing the target clears the access status")


func resolve_outcomes() -> void:
	# sell: Crypto to the finisher
	fresh()
	var c := corridor(); var mid: int = c[1]; var t: int = c[2]
	own(mid, 30.0); g.hosts[t].owner = R; g._setup_mission(t, 3); g._mark_scanned(P, t)
	g.records_home[g._mkey(P, t)] = 3.0   # pretend it was delivered
	check(g._mission_complete(P, t), "Fixture: mission complete")
	var cash0 := float(g.cash[P])
	g._apply_cmd(P, ["resolve", t, "sell"])
	check(abs(float(g.cash[P]) - (cash0 + g.MIS_SELL_CRYPTO)) < 0.01, "Sell pays the finisher %d Crypto" % int(g.MIS_SELL_CRYPTO))
	g._apply_cmd(P, ["resolve", t, "sell"])
	check(abs(float(g.cash[P]) - (cash0 + g.MIS_SELL_CRYPTO)) < 0.01, "A mission resolves only once")
	# publish: temporary use of a community relay (timed ownership that reverts)
	fresh()
	c = corridor(); mid = c[1]; t = c[2]
	own(mid, 30.0); g.hosts[t].owner = R; g._setup_mission(t, 3); g._mark_scanned(P, t)
	var relay := -1
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == g.NEUTRAL and i != t and not g.hosts[i].rig: relay = i; break
	g.hosts[relay].relay = true
	g.records_home[g._mkey(P, t)] = 3.0
	g._apply_cmd(P, ["resolve", t, "publish"])
	check(int(g.hosts[relay].owner) == P, "Publish grants temporary use of the community relay")
	check(float(g.hosts[relay].bots) >= 0.0, "The lent relay keeps its own defenders (never a negative garrison)")
	for k in int((g.MIS_RELAY_SECS + 2.0) / g.SIM_DT): g._sim_step(g.SIM_DT)
	check(int(g.hosts[relay].owner) != P, "The relay reverts when its loan is up")


func determinism() -> void:
	var hashes := []
	for run_i in 2:
		fresh()
		var c := corridor(); var mid: int = c[1]; var t: int = c[2]
		own(mid, 30.0); g.hosts[t].owner = g.RIVAL; g.hosts[t].bots = 200.0; g._set_builds(t, ["cash"]); g.ais = [g.RIVAL]
		g._setup_mission(t, 50); g._mark_scanned(P, t); g.intel[P] = 500.0; g.creds[P] = 500.0; g._apply_cmd(P, ["access", t])
		for k in int(30.0 / g.SIM_DT): g._sim_step(g.SIM_DT)
		hashes.append(g._mp_hash())
	check(hashes[0] == hashes[1], "The mission runs deterministically (same hash twice)")
