extends SceneTree
## RIM two-scale game assertion suite (global city + local component graphs, cards, programs,
## overload/recapture, research, phishing). Run:
##   godot --headless --script res://review/netrun_assertions.gd
## Save/load tests back up and restore the real user save.

var nr
var pass_count := 0
var fail_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(id: String, ok: bool, detail := "") -> void:
	if ok: pass_count += 1
	else: fail_count += 1
	print("ASSERT %-34s %s  %s" % [id, "PASS" if ok else "FAIL", detail])

func fresh() -> void:
	nr = load("res://scenes/netrun.tscn").instantiate()
	nr.seed = 777
	nr.rng.seed = 777
	nr.city_size = "small"
	nr.camera = Camera2D.new()
	nr.resources = {"compute": 200.0, "data": 120.0, "crypto": 20.0, "tools": 20.0, "credits": 0.0, "research": 0.0}
	nr.researched = {}
	nr.packets = []
	nr.won = false
	nr._first_banked = false
	nr._generate()

# force a component into a known shape for deterministic attack/economy tests
func setcomp(gid: int, type: String, state: String, p: int, v: int, a: int, traits: Array, captured_cap: float = -1.0) -> void:
	nr.comps[gid].type = type
	nr.comps[gid].state = state
	nr.comps[gid]["pass"] = p
	nr.comps[gid].vuln = v
	nr.comps[gid].aware = a
	nr.comps[gid].traits = traits
	nr.comps[gid].slots = int(nr.COMP[type].slots)
	nr.comps[gid].cap = captured_cap if captured_cap > 0.0 else float(nr.COMP[type].cap)
	nr.comps[gid].affin = str(nr.COMP[type].affin)

func c2_entry() -> int:
	return int(nr.hosts[nr.c2_id].entry_gid)

func run() -> void:
	fresh()
	# NR01: start — exactly one captured component (the C2 entry); everything else unknown.
	var cap := 0; var unknown := 0
	for gid in nr.comps:
		if nr.comps[gid].state == "captured": cap += 1
		elif nr.comps[gid].state == "unknown": unknown += 1
	check("NR01_start_one_component", cap == 1 and nr.comps[c2_entry()].state == "captured" and nr._has_foothold(nr.c2_id),
		"captured=%d unknown=%d total=%d foothold=%s" % [cap, unknown, nr.comps.size(), nr._has_foothold(nr.c2_id)])

	# NR02: building reachability — C2's neighbours are reachable; a non-adjacent building is not.
	var reach_nb := -1; var far := -1
	for nb in nr.hosts[nr.c2_id].neighbors:
		if nr._breachable(nb): reach_nb = nb; break
	for id in nr.hosts:
		if id != nr.c2_id and not nr._breachable(id): far = id; break
	check("NR02_building_frontier", reach_nb != -1 and far != -1, "reachable_nb=%d unreachable=%d" % [reach_nb, far])

	# NR03: enter a building → entry visible; scan it → neighbours revealed.
	nr._enter_building(reach_nb)
	var e2: int = int(nr.hosts[reach_nb].entry_gid)
	var vis_entry: bool = nr.comps[e2].state == "scanned"
	var unk_nb := 0
	for g in nr.comps[e2].neighbors:
		if nr.comps[g].state == "unknown": unk_nb += 1
	nr.scan_component(e2)
	var revealed := 0
	for g in nr.comps[e2].neighbors:
		if nr.comps[g].state == "scanned": revealed += 1
	check("NR03_local_progressive_discovery", vis_entry and revealed == unk_nb and revealed > 0,
		"entry_visible=%s revealed %d/%d neighbours" % [vis_entry, revealed, unk_nb])

	# NR04: deterministic card capture — applicable + power>=defence + affordable + unlocked captures;
	# wrong-trait and insufficient-power are refused WITHOUT charging.
	fresh()
	nr._enter_building(nr.c2_id)
	# pick a scanned frontier component in C2 (scan entry first)
	nr.scan_component(c2_entry())
	var tgt := -1
	for g in nr.hosts[nr.c2_id].comps:
		if nr._comp_attack_frontier(g) and nr.comps[g].state != "captured": tgt = g; break
	setcomp(tgt, "iot", "scanned", 2, 9, 0, ["login"])     # pass 2, vuln 9 (resistant), login only
	var before: float = nr.resources.compute
	nr.attack_component(tgt, "vuln1")                      # wrong trait (needs software) → refused, no charge
	var no_charge_trait: bool = nr.comps[tgt].state == "scanned" and nr.resources.compute == before
	setcomp(tgt, "db", "scanned", 9, 9, 0, ["login", "software"])  # defences 9 — basic power 3 too weak
	nr.attack_component(tgt, "cred1")                      # insufficient power → refused, no charge
	var no_charge_power: bool = nr.comps[tgt].state == "scanned" and nr.resources.compute == before
	setcomp(tgt, "iot", "scanned", 2, 3, 0, ["login"])     # beatable by cred1 (power 3 >= pass 2)
	nr.attack_component(tgt, "cred1")
	var captured_ok: bool = nr.comps[tgt].state == "captured" and nr.resources.compute == before - 4.0
	check("NR04_card_capture_deterministic", no_charge_trait and no_charge_power and captured_ok,
		"wrongtrait_norefund=%s weakpower_norefund=%s captured=%s" % [no_charge_trait, no_charge_power, captured_ok])

	# NR05: capturing the first component in a building establishes a foothold + route, and the
	# building becomes scannable to map onward links (no program required to expand).
	fresh()
	var b2 := -1
	for nb in nr.hosts[nr.c2_id].neighbors:
		if nr._breachable(nb): b2 = nb; break
	nr._enter_building(b2)
	var be: int = int(nr.hosts[b2].entry_gid)
	setcomp(be, "iot", "scanned", 1, 1, 0, ["login"])
	var had_fh: bool = nr._has_foothold(b2)
	nr.attack_component(be, "cred1")
	check("NR05_foothold_and_expand", (not had_fh) and nr._has_foothold(b2) and nr._building_routed(b2) and nr._building_scannable(b2) and nr.comps[be].programs.is_empty(),
		"foothold=%s routed=%s scannable=%s no_program=%s" % [nr._has_foothold(b2), nr._building_routed(b2), nr._building_scannable(b2), nr.comps[be].programs.is_empty()])

	# NR06: installing a producer on a routed captured component delivers real resource to C2.
	fresh()
	var ce := c2_entry()
	setcomp(ce, "iot", "captured", 0, 0, 0, ["login"])   # affin compute
	nr.resources.compute = 100.0
	nr.install_program(ce, "mirai")
	var c0: float = nr.resources.compute
	for i in 40: nr._sim(0.1)
	check("NR06_install_delivers_to_c2", nr.resources.compute > c0, "Cycles %.0f -> %.0f over 4s" % [c0, nr.resources.compute])

	# NR07: component specialty — a producer matching affinity runs at full rate, else ×0.5.
	fresh()
	var g1 := c2_entry()
	setcomp(g1, "iot", "captured", 0, 0, 0, ["login"])   # affin compute → mirai full
	nr.comps[g1].programs = [{"key": "mirai", "acc": 0.0, "enabled": true}]
	var a0: float = nr.resources.compute
	for i in 20: nr._sim(0.1)
	var full_gain: float = nr.resources.compute - a0
	fresh()
	var g2 := c2_entry()
	setcomp(g2, "db", "captured", 0, 0, 0, ["login"])    # affin data → mirai (compute) at ×0.5
	nr.comps[g2].programs = [{"key": "mirai", "acc": 0.0, "enabled": true}]
	var b0: float = nr.resources.compute
	for i in 20: nr._sim(0.1)
	var half_gain: float = nr.resources.compute - b0
	check("NR07_specialty_affinity", full_gain > half_gain * 1.5, "full=%.1f half=%.1f" % [full_gain, half_gain])

	# NR08: overload (load > capacity) degrades integrity until the component is lost; then recapture.
	fresh()
	var gd := c2_entry()
	setcomp(gd, "db", "captured", 1, 1, 0, ["login", "software"], 3.0)  # cap 3
	nr.resources.compute = 500.0; nr.resources.data = 200.0
	nr.install_program(gd, "botfarm")   # load 2
	nr.install_program(gd, "botfarm")   # load 2 → total 4 > cap 3
	var overloaded: bool = nr._comp_overloaded(gd)
	for i in 300: nr._sim(0.1)           # ~30s of overload
	var lost: bool = nr.comps[gd].state != "captured"
	# recapture with a basic card (defences low)
	nr.comps[gd]["pass"] = 1
	nr.attack_component(gd, "cred1")
	var recaptured: bool = nr.comps[gd].state == "captured" and float(nr.comps[gd].integrity) > 0.0
	check("NR08_overload_loss_recapture", overloaded and lost and recaptured,
		"overloaded=%s lost=%s recaptured=%s integrity=%d" % [overloaded, lost, recaptured, int(nr.comps[gd].integrity)])

	# NR09: research spends Research to unlock a tier-2 card; before/after availability flips.
	fresh()
	var locked_before: bool = not nr._card_unlocked("cred2")
	nr.resources.research = 20.0
	nr.research_card("cred2")
	check("NR09_research_unlocks_card", locked_before and nr._card_unlocked("cred2") and nr.researched.has("cred2"),
		"locked_before=%s unlocked_after=%s" % [locked_before, nr._card_unlocked("cred2")])

	# NR10: phishing eligibility — a human-facing PC is phishable; a machine without the trait is not.
	fresh()
	var gp := c2_entry()
	setcomp(gp, "pc", "scanned", 4, 4, 2, ["human", "login", "software"])
	var pc_phishable: bool = nr._card_applicable(gp, "phish1")
	setcomp(gp, "iot", "scanned", 2, 2, 0, ["login"])
	var iot_not_phishable: bool = not nr._card_applicable(gp, "phish1")
	check("NR10_phishing_eligibility", pc_phishable and iot_not_phishable,
		"pc_phishable=%s iot_not=%s" % [pc_phishable, iot_not_phishable])

	# NR11: full control / win only when EVERY component (incl. hidden) is captured.
	fresh()
	var all_but_one := true
	var first := true
	for gid in nr.comps:
		if first and gid != c2_entry():
			first = false
			continue   # leave one uncaptured
		nr.comps[gid].state = "captured"
	nr._check_win()
	var not_won_yet: bool = not nr.won
	for gid in nr.comps:
		nr.comps[gid].state = "captured"
	nr._check_win()
	check("NR11_full_control_truthful", not_won_yet and nr.won, "partial_not_won=%s all_won=%s" % [not_won_yet, nr.won])

	# NR12: save/load round-trip preserves hidden+discovered components, programs, researched, resources.
	var sp: String = nr.SAVE_PATH
	var had := FileAccess.file_exists(sp)
	var backup := FileAccess.get_file_as_string(sp) if had else ""
	fresh()
	nr._enter_building(nr.c2_id)
	nr.scan_component(c2_entry())
	setcomp(c2_entry(), "iot", "captured", 0, 0, 0, ["login"])
	nr.resources.compute = 100.0
	nr.install_program(c2_entry(), "mirai")
	nr.researched["vuln2"] = true
	var comp_total: int = nr.comps.size()
	var saved: bool = nr.save_game()
	var progs: int = nr.comps[c2_entry()].programs.size()
	fresh()
	var loaded: bool = nr.load_game()
	var ok_rt: bool = loaded and nr.comps.size() == comp_total and nr.comps[c2_entry()].programs.size() == progs and nr.researched.has("vuln2")
	check("NR12_save_load_roundtrip", saved and ok_rt, "loaded=%s comps=%d/%d programs=%d researched_vuln2=%s" % [loaded, nr.comps.size(), comp_total, nr.comps[c2_entry()].programs.size() if nr.comps.has(c2_entry()) else -1, nr.researched.has("vuln2")])
	if had:
		var f := FileAccess.open(sp, FileAccess.WRITE); f.store_string(backup); f.close()
	elif FileAccess.file_exists(sp):
		DirAccess.remove_absolute(sp)

	# NR13: a REAL generated run has a recoverable opening — a component reachable from the C2
	# foothold that a BASIC (free) card can capture, so the economy→research→card loop can start.
	fresh()
	nr._enter_building(nr.c2_id)
	nr.scan_component(c2_entry())
	var openable := false
	for g in nr.hosts[nr.c2_id].comps:
		if nr._comp_attack_frontier(g) and nr.comps[g].state != "captured":
			for basic in ["cred1", "vuln1", "phish1"]:
				if nr._card_outcome(g, basic).ok:
					openable = true
	check("NR13_recoverable_opening", openable, "a basic card can capture a reachable component")

	print("\nSUMMARY: %d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)
