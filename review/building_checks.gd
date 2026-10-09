extends Node
## Building (local network map) + economy checks — headless, full project so autoloads load:
##   godot --headless res://review/building_checks.tscn
## Per building kind × 15 seeds: the graph is connected; the entry is a controlled firewall and everything
## else starts hidden; you cannot network-scan a node you don't control; you cannot take control before
## profiling the endpoint; every map is fully solvable by perfect play (net-scan → profile → take, hop by
## hop); a leaf's network scan reports "no further connections"; slot type + count are enforced; the
## city's "under hack" summary is written once progress is made.
## Economy: actions cost Intel and are refused when broke; a deployed producer raises its stockpile on
## tick; a converter consumes its input and never drives it negative; a boosted capture burns one
## credential / exploit; deploying costs the program's price.
var fails := 0


func ck(name: String, ok: bool, detail := "") -> void:
	if not ok: fails += 1
	print(("PASS " if ok else "FAIL ") + name + "  " + str(detail))


func mk(kind: String, sec: String, people: Array, sd: int):
	Session.seed = sd
	Session.enter = {"key": [sd, kind.hash() % 50], "name": kind + " test", "kind": kind, "sec": sec,
		"col": [0.4, 0.9, 1.0], "owner": "Orbis Neural", "industry": "data", "district": "Test", "people": people}
	Session.interior = {}; Session.hacked = {}
	Econ.reset(); Econ.test_uncapped = true; Econ.stock.intel = 1000000.0   # mechanics: no passive/clamp, never dry
	var b = load("res://scenes/building.tscn").instantiate()
	add_child(b)
	b.instant_actions = true   # mechanics tests resolve timed actions immediately
	return b


func connected(b) -> bool:
	var seen := {0: true}; var st := [0]
	while not st.is_empty():
		var c = st.pop_back()
		for o in b.nodes[c].nbrs:
			if not seen.has(o): seen[o] = true; st.append(o)
	return seen.size() == b.nodes.size()


# perfect play with the dice forced to succeed: net-scan every controlled node, profile every detected
# node, take every profiled node that touches a controlled one — repeat until nothing changes
func flood(b) -> int:
	var changed := true
	while changed:
		changed = false
		for nd in b.nodes:
			if str(nd.state) == "controlled" and not bool(nd.enum_done):
				for o in nd.nbrs:
					if str(b.nodes[o].state) == "hidden": b.nodes[o].state = "detected"
				nd.enum_done = true; changed = true
		for nd in b.nodes:
			if str(nd.state) == "detected" and not bool(nd.profiled): nd.profiled = true; changed = true
		for nd in b.nodes:
			if str(nd.state) == "detected" and bool(nd.profiled) and b._reachable(nd): nd.state = "controlled"; changed = true
	var c := 0
	for nd in b.nodes:
		if str(nd.state) == "controlled": c += 1
	return c


func _ready() -> void:
	await get_tree().process_frame
	var people := ["Mira Okafor", "Kenji Tanaka", "Amara Silva"]
	for cfg in [["fh", "None to speak of", people], ["ap", "Patchwork", people], ["shop_b", "Consumer-grade", ["Zara Kahn"]],
			["off_m", "Corporate ICE", []], ["corp", "Black ICE", []], ["hub", "Lethal — black ICE", []]]:
		var minn := 999; var maxn := 0; var leaf_msgs := 0
		for sd in range(1, 16):
			var b = mk(cfg[0], cfg[1], cfg[2], sd)
			minn = mini(minn, b.nodes.size()); maxn = maxi(maxn, b.nodes.size())
			if not connected(b): ck("connected " + cfg[0] + " seed" + str(sd), false); return
			var ok0: bool = str(b.nodes[0].type) == "fw" and str(b.nodes[0].state) == "controlled" and bool(b.nodes[0].profiled)
			for i in range(1, b.nodes.size()):
				if str(b.nodes[i].state) != "hidden" or bool(b.nodes[i].profiled): ok0 = false
			if not ok0: ck("initial-state " + cfg[0], false); return
			# cannot network-scan a node you don't control
			var victim := 1
			b.nodes[victim].state = "detected"; b.nodes[victim].profiled = true
			var hidden_before := 0
			for o in b.nodes[victim].nbrs:
				if str(b.nodes[o].state) == "hidden": hidden_before += 1
			b._net_scan(victim)
			var hidden_after := 0
			for o in b.nodes[victim].nbrs:
				if str(b.nodes[o].state) == "hidden": hidden_after += 1
			if hidden_before != hidden_after or bool(b.nodes[victim].enum_done): ck("no-netscan-uncontrolled " + cfg[0], false); return
			# cannot take control before profiling
			b.nodes[victim].state = "detected"; b.nodes[victim].profiled = false
			if not b.nodes[0].nbrs.has(victim):
				b.nodes[0].nbrs.append(victim); b.nodes[victim].nbrs.append(0)
			for i in 30: b._take(victim)
			if str(b.nodes[victim].state) == "controlled": ck("no-take-unprofiled " + cfg[0], false); return
			# cannot profile a hidden node
			b.nodes[victim].state = "hidden"
			b._profile(victim)
			if bool(b.nodes[victim].profiled): ck("no-profile-hidden " + cfg[0], false); return
			# every scan attempt costs Intel; a broke player is refused (state untouched, stock untouched)
			var before: float = Econ.stock.intel
			b.nodes[0].enum_done = false
			b._net_scan(0)
			if absf((before - float(Econ.stock.intel)) - float(Econ.COST.net_scan)) > 0.001: ck("scan-costs-intel " + cfg[0], false, "%.1f" % (before - float(Econ.stock.intel))); return
			Econ.stock.intel = 1.0
			b.nodes[0].enum_done = false
			for o in b.nodes[0].nbrs: b.nodes[o].state = "hidden"
			b._net_scan(0)
			var leaked := false
			for o in b.nodes[0].nbrs:
				if str(b.nodes[o].state) != "hidden": leaked = true
			if leaked or bool(b.nodes[0].enum_done) or absf(float(Econ.stock.intel) - 1.0) > 0.001: ck("broke-refused " + cfg[0], false); return
			Econ.stock.intel = 1000000.0
			# solvable by perfect play
			var reached := flood(b)
			if reached != b.nodes.size(): ck("solvable " + cfg[0] + " seed" + str(sd), false, "%d/%d" % [reached, b.nodes.size()]); return
			# a leaf's network scan must complete and report no connections
			for nd in b.nodes:
				if nd.nbrs.size() == 1 and nd.id != 0:
					nd.enum_done = false
					var tries := 0
					while not bool(nd.enum_done) and tries < 200: b._net_scan(nd.id); tries += 1
					if not bool(nd.enum_done): ck("leaf-scan " + cfg[0], false); return
					if not ("no further connections" in b._msg): ck("leaf-no-connections-msg " + cfg[0], false, b._msg); return
					leaf_msgs += 1
					break
			# slot rules + deploy cost + production
			var slotnode := -1
			for i in b.nodes.size():
				if int(b.nodes[i].slots) > 0: slotnode = i; break
			if slotnode >= 0:
				var nd = b.nodes[slotnode]
				var accepts: Array = b.NODE[nd.type].accepts
				var bad := ""; var good := ""
				for pk in Econ.PROGRAMS:
					var cat: String = Econ.PROGRAMS[pk].cat
					if accepts.has(cat) and good == "" and Econ.PROGRAMS[pk].has("out") and not Econ.PROGRAMS[pk].has("in"): good = pk
					if not accepts.has(cat) and bad == "": bad = pk
				if bad != "":
					var n0: int = nd.progs.size(); b._install(slotnode, bad)
					if nd.progs.size() != n0: ck("reject-wrong-type " + cfg[0], false); return
				if good != "":
					var pre: float = Econ.stock.intel
					b._install(slotnode, good)
					if nd.progs.size() != 1: ck("install-fitting " + cfg[0], false); return
					var price: float = float(Econ.PROGRAMS[good].cost.get("intel", 0.0))
					if absf((pre - float(Econ.stock.intel)) - price) > 0.001: ck("deploy-costs " + cfg[0], false); return
					var out: String = Econ.PROGRAMS[good].out
					var s0: float = Econ.stock[out]
					Econ.tick(10.0)
					var expect: float = float(Econ.PROGRAMS[good].rate) * 10.0 - (10.0 * 0.0)
					var got: float = float(Econ.stock[out]) - s0
					if got < expect * 0.999: ck("producer-ticks " + cfg[0], false, "%s got %.2f want %.2f" % [out, got, expect]); return
					for i in 20: b._install(slotnode, good)
					if nd.progs.size() != int(nd.slots): ck("slot-cap " + cfg[0], false, "%d>%d" % [nd.progs.size(), nd.slots]); return
			# converter never drives its input negative: a mixer with zero crypto produces no cash
			var mixnode := -1
			for i in b.nodes.size():
				if (b.NODE[b.nodes[i].type].accepts as Array).has("ops"): mixnode = i; break
			if mixnode >= 0:
				b.nodes[mixnode].progs = ["mixer"]; b._save()
				Econ.stock.crypto = 0.0; var cash0: float = Econ.stock.cash
				Econ.tick(5.0)
				if float(Econ.stock.crypto) < -0.001 or float(Econ.stock.cash) - cash0 > 0.001: ck("converter-no-negative " + cfg[0], false); return
				Econ.stock.crypto = 2.0; cash0 = Econ.stock.cash
				Econ.tick(10.0)   # needs 10 crypto, has 2 → runs at 20%: +1.6 cash, crypto → 0
				if absf(float(Econ.stock.crypto)) > 0.001 or absf((float(Econ.stock.cash) - cash0) - 1.6) > 0.01: ck("converter-scales " + cfg[0], false, "crypto %.2f cash +%.2f" % [Econ.stock.crypto, float(Econ.stock.cash) - cash0]); return
				b.nodes[mixnode].progs = []
			# a boosted capture burns exactly one credential, success or not
			var tgt := -1
			for i in range(1, b.nodes.size()):
				if b.LOGIN_TYPES.has(str(b.nodes[i].type)) and b.nodes[i].nbrs.has(0): tgt = i; break
			if tgt >= 0:
				b.nodes[tgt].state = "detected"; b.nodes[tgt].profiled = true
				Econ.stock.creds = 3.0
				b._take(tgt, "creds")
				if absf(float(Econ.stock.creds) - 2.0) > 0.001: ck("credential-burns " + cfg[0], false, "%.1f" % float(Econ.stock.creds)); return
				Econ.stock.creds = 0.0
				b.nodes[tgt].state = "detected"
				var intel_b: float = Econ.stock.intel
				b._take(tgt, "creds")   # no credential to burn → refused, nothing paid
				if str(b.nodes[tgt].state) != "detected" or absf(float(Econ.stock.intel) - intel_b) > 0.001: ck("no-boost-when-empty " + cfg[0], false); return
			# the city summary exists and counts controlled nodes
			for nd in b.nodes: nd.state = "controlled"
			b._save()
			var hk = Session.hacked.get(b._keystr(), null)
			if hk == null or int(hk.ctl) != b.nodes.size() or int(hk.n) != b.nodes.size(): ck("hacked-summary " + cfg[0], false, str(hk)); return
			b.queue_free()
			await get_tree().process_frame
		ck("suite " + cfg[0], true, "nodes %d..%d · leaf-scan msgs %d" % [minn, maxn, leaf_msgs])
	# economy: passive Intel, the 100 cap, and storage widening it
	Session.interior = {}; Econ.reset(); Econ.test_uncapped = false
	var i0: float = Econ.stock.intel; Econ.tick(5.0)
	if absf((float(Econ.stock.intel) - i0) - 5.0) > 0.01: ck("passive-intel", false, "%.2f" % (float(Econ.stock.intel) - i0)); return
	ck("passive-intel", true, "+1/s")
	Econ.stock.intel = 99.0; Econ.tick(10.0)
	if absf(float(Econ.stock.intel) - 100.0) > 0.001: ck("cap-clamps", false, "%.2f" % Econ.stock.intel); return
	ck("cap-clamps", true, "at 100")
	Session.interior = {"0,0": [{"state": "controlled", "profiled": true, "enum_done": true, "progs": ["vault_i"]}]}
	Econ.reset()
	if int(Econ.cap.intel) != 250: ck("storage-raises-cap", false, "%d" % int(Econ.cap.intel)); return
	Econ.stock.intel = 240.0; Econ.tick(20.0)   # passive pushes toward the new 250 cap, not 100
	if float(Econ.stock.intel) <= 100.0 or float(Econ.stock.intel) > 250.001: ck("storage-raises-cap", false, "%.1f" % Econ.stock.intel); return
	ck("storage-raises-cap", true, "cap 250")
	# production is gated to CONNECTED nodes: a lost relay cuts off everything behind it
	Econ.reset(); Econ.test_uncapped = false
	Session.interior = {"0,0": [
		{"state": "controlled", "progs": [], "heat": 0.0, "burned": 0, "nbrs": [1]},
		{"state": "controlled", "progs": ["scraper"], "heat": 0.0, "burned": 0, "nbrs": [0, 2]},
		{"state": "controlled", "progs": ["scraper"], "heat": 0.0, "burned": 0, "nbrs": [1]}]}
	Econ.stock.intel = 0.0; Econ.tick(1.0)
	if absf(float(Econ.stock.intel) - 2.2) > 0.05: ck("reachable-production", false, "%.2f" % Econ.stock.intel); return
	Session.interior["0,0"][1].state = "detected"   # break the relay → node 2 is cut off
	Econ.stock.intel = 0.0; Econ.tick(1.0)
	if absf(float(Econ.stock.intel) - 1.0) > 0.05: ck("reachable-production", false, "cut %.2f" % Econ.stock.intel); return
	ck("reachable-production", true, "relay loss stops downstream")
	# EVADE cools heat
	Econ.reset(); Econ.test_uncapped = false
	Session.interior = {"a": [{"state": "controlled", "progs": [], "heat": 0.0, "burned": 0, "nbrs": [1]},
		{"state": "controlled", "progs": ["cloak"], "heat": 50.0, "burned": 0, "nbrs": [0]}]}
	Econ.tick(1.0)
	if absf(float(Session.interior["a"][1].heat) - 48.0) > 0.01: ck("evade-cools", false, "%.1f" % float(Session.interior["a"][1].heat)); return
	ck("evade-cools", true, "-2/s")
	# ALARM at 100%: tools wiped, control lost, re-hack penalty stacked
	Econ.reset(); Econ.test_uncapped = false
	Session.interior = {"a": [{"state": "controlled", "progs": [], "heat": 0.0, "burned": 0, "nbrs": [1]},
		{"state": "controlled", "progs": ["scraper"], "heat": 100.0, "burned": 0, "nbrs": [0]}]}
	Econ.tick(1.0)
	var n1 = Session.interior["a"][1]
	if str(n1.state) != "detected" or (n1.progs as Array).size() != 0 or int(n1.burned) != 1 or float(n1.heat) != 0.0:
		ck("alarm-at-100", false, "%s burned=%d progs=%d heat=%.0f" % [n1.state, int(n1.burned), (n1.progs as Array).size(), float(n1.heat)]); return
	ck("alarm-at-100", true, "node lost + burned")
	# capture cost escalates with how many nodes you already control (Stellaris-style)
	Econ.reset()
	Session.interior = {"a": [{"state": "controlled"}]}
	var sc1 := Econ.capture_scale()
	Session.interior = {"a": [{"state": "controlled"}, {"state": "controlled"}, {"state": "controlled"}, {"state": "controlled"}, {"state": "controlled"}]}
	var sc5 := Econ.capture_scale()
	if absf(sc1 - 1.0) > 0.001 or absf(sc5 - (1.0 + Econ.CAPTURE_SCALE * 4.0)) > 0.001: ck("capture-escalates", false, "%.2f→%.2f" % [sc1, sc5]); return
	ck("capture-escalates", true, "1.0 → %.2f at 5 nodes" % sc5)
	# timed actions: a scan does not resolve instantly; it clears after its duration
	Session.interior = {}; Econ.reset(); Econ.test_uncapped = true; Econ.stock.intel = 1000.0
	var tb = load("res://scenes/building.tscn").instantiate(); add_child(tb)
	tb.instant_actions = false
	await get_tree().process_frame
	tb._net_scan(0)
	if str(tb.nodes[0].task) != "scan" or bool(tb.nodes[0].enum_done): ck("timed-action", false, "did not start / resolved instantly"); return
	tb._advance_tasks(float(Econ.TIME.net_scan) + 0.1)
	if str(tb.nodes[0].task) != "": ck("timed-action", false, "did not finish"); return
	ck("timed-action", true, "scan takes %ds" % int(Econ.TIME.net_scan))
	tb.queue_free(); await get_tree().process_frame
	print("BLD TESTS: %d failed" % fails)
	get_tree().quit(1 if fails > 0 else 0)
