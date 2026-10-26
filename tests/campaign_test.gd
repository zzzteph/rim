extends SceneTree
## The guided campaign: outcome-gated advancement (with the pitfall negative cases), the true reading pause,
## persistence/checkpoints, idempotent supplies, and no training state leaking into normal play.
## Runs on the real game. godot --headless --path . --script tests/campaign_test.gd
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


func fresh(wipe_save := true) -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	root.add_child(g); g.set_process(false); g.ai_enabled = false
	if wipe_save and FileAccess.file_exists(g._camp_save_path()): DirAccess.remove_absolute(ProjectSettings.globalize_path(g._camp_save_path()))
	P = g.PLAYER; R = g.RIVAL


func done(ch: int, step: int) -> bool: return g._camp_step_done(ch, step)


func run() -> void:
	chapter0()
	chapter1()
	chapter2()
	chapter3()
	chapter4()
	chapter5()
	reading_pause()
	banner()
	outcome_beat()
	review_fixes()
	menu_resume()
	harness_save()
	ui_cues()
	rich_text()
	persistence()
	no_leak()
	mandatory_gate()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/implemented_ui"))
	var f := FileAccess.open("res://review/implemented_ui/campaign.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t")); f.close()
	g.free(); quit(0 if failures.is_empty() else 1)


func chapter0() -> void:
	fresh(); g._start_campaign(0)
	check(g._camp and g._camp_chapter == 0 and g._tut_stage == 0 and g._camp_paused, "Ch0 starts paused for reading at step 0")
	var relay: int = g._camp_relay
	# step 0 connect: a mere selection does NOT advance; a feeder does
	g.sel = {relay: true}
	check(not done(0, 0), "Ch0 s0: selecting the relay does not advance (no feeder yet)")
	g._do_wire(P, [g._camp_home], relay)
	check(not g._owned_feeders(relay).is_empty() and done(0, 0), "Ch0 s0: a connection advances it")
	# step 1 scan: an attack started is NOT a scan; a completed scan is
	g.hosts[g._camp_home].mode = "attack"; g.hosts[g._camp_home].live = true
	check(not done(0, 1), "Ch0 s1: starting an attack does not satisfy the scan lesson")
	g._mark_scanned(P, relay)
	check(done(0, 1), "Ch0 s1: a completed scan advances it")
	# step 2 attack landed (defenders fell below the scanned count)
	check(not done(0, 2), "Ch0 s2: not done before any damage")
	g.hosts[relay].bots = float(g.hosts[relay].bots) - 5.0
	check(done(0, 2), "Ch0 s2: defenders falling below the scan advances it")
	# step 3 capture
	check(not done(0, 3), "Ch0 s3: not done while the relay is the rival's")
	g._capture(relay, P)
	check(done(0, 3), "Ch0 s3: owning the relay advances it")


func chapter1() -> void:
	fresh(); g._start_campaign(1)
	var relay: int = g._camp_relay
	check(g._mine(relay), "Ch1 starts with the relay owned")
	# step 0 build intel — a QUEUED job does not count; a finished installation does
	g.hosts[relay].jobs = {0: {"kind": "intel", "slot": 0, "phase": "build", "left": 9.0}}
	check(not done(1, 0), "Ch1 s0: a queued build does not advance (finished-not-queued)")
	g.hosts[relay].jobs = {}; g._set_builds(relay, ["intel"])
	check(done(1, 0), "Ch1 s0: a finished Intel harvester advances it")
	# step 1 miner
	check(not done(1, 1), "Ch1 s1: not done without a miner")
	g._set_builds(relay, ["intel", "cash"])
	check(done(1, 1), "Ch1 s1: a finished miner advances it")
	# step 2 crypto delivered home — the counter, not a bank balance
	g.cash[P] = 999.0
	check(not done(1, 2), "Ch1 s2: a full Crypto bank is not a delivery")
	g._camp_cash_landed = 1
	check(done(1, 2), "Ch1 s2: a delivered Crypto packet advances it")
	# step 3 bot farm
	check(not done(1, 3), "Ch1 s3: not done without a farm")
	g._set_builds(relay, ["intel", "cash", "bot"])
	check(done(1, 3), "Ch1 s3: a finished Bot farm advances it")


func chapter2() -> void:
	fresh(); g._start_campaign(2)
	var support: int = g._camp_support; var gateway: int = g._camp_gateway
	g._camp_set_pause(false)
	# step 0 guard
	check(not done(2, 0), "Ch2 s0: not done without a guard")
	var rear := -1
	for i in g.hosts.size():
		if g._mine(i) and i != support and not g._route(i, support).is_empty(): rear = i; break
	if rear >= 0: g._do_wire(P, [rear], support)
	check(done(2, 0), "Ch2 s0: guarding Support advances it")
	# step 1 assault (sent>0) — ordering alone (0 sent) does not count
	g.hosts[g._camp_src].bots = 60.0; g.intel[P] = 200.0
	g._do_wire(P, [g._camp_src], gateway); g._do_assault(P, gateway, 75)
	check(g._assault_active(g._camp_src) and not done(2, 1), "Ch2 s1: an assault with nothing sent yet does not advance")
	for k in 60: g._sim_step(g.SIM_DT)
	check(done(2, 1), "Ch2 s1: once bots have departed it advances")
	# step 2 cancel
	check(not done(2, 2), "Ch2 s2: not done before cancelling")
	g._do_unassault(P, gateway)
	check(g._camp_cancelled and done(2, 2), "Ch2 s2: cancelling advances it")
	# step 3: the Gateway hits back (a real wave + a routing cut); done once Support is guarded, the wave spent and the cut over
	g._camp_fire("ch2_cut")
	check(g._assault_active(gateway) and float(g.hosts[support].route_off) == g.CAMP_CUT_SECS, "Ch2 s3: the Gateway retaliates with a real Assault and a %ds cut" % int(g.CAMP_CUT_SECS))
	check(not done(2, 3), "Ch2 s3: not done while Support's route is cut")
	g.hosts[support].route_off = 0.0
	check(not done(2, 3), "Ch2 s3: not done while the Gateway's wave is still coming")
	g._end_assault(gateway)
	g.flights = g.flights.filter(func(f): return int(f.owner) != R)
	if not g._camp_guarded(support): g._do_wire(P, [g._camp_guard], support)
	check(done(2, 3), "Ch2 s3: guarded, the wave spent and the cut over advances it")
	# no unrecoverable state: if Support falls during the lesson, the campaign hands it back
	g._tut_stage = 3; g._capture(support, R)
	g._camp_tick()
	check(g._mine(support) and str(g.hosts[support].name) == "Support", "Ch2 s3: a fallen Support is handed back")
	# the guard lesson's FROM is never the Assault source, so step 1's drag can't silently undo it
	fresh(); g._start_campaign(2)
	var guard: int = g._camp_guard
	check(guard >= 0 and guard != g._camp_src and g._link_kind(guard, support) == "defend", "Ch2 s0: the FROM computer can guard Support and is not the Assault source")
	check(g._camp_from() == guard and not g._camp_fill(str(g._camp_step().a)).contains("{from}"), "Ch2 s0: the drag guide starts at FROM and the banner names it")
	g._do_wire(P, [guard], support)
	check(g._camp_from() == -1 and done(2, 0), "Ch2 s0: once the guard wire exists the arrow goes away and the step is done")
	check(str(g.hosts[support].name) == "Support" and str(g.hosts[g._camp_relay].name) == "Neighborhood Relay" and float(g.hosts[g._camp_relay].bots) >= 0.0, "Ch2: the map names match the banner and no garrison starts negative")


func chapter3() -> void:
	fresh(); g._start_campaign(3)
	var relay: int = g._camp_relay; var support: int = g._camp_support
	var prac: int = g._camp_practice; var prac2: int = g._camp_practice2
	# step 0 cred+lab
	check(not done(3, 0), "Ch3 s0: not done without a lab")
	g._set_builds(relay, ["intel", "cash", "bot", "cred", "lab"])
	check(done(3, 0), "Ch3 s0: a Credential harvester and a Research lab advance it")
	# step 1 research phishing (held)
	check(not done(3, 1), "Ch3 s1: not done before a copy is ready")
	g.cards[P]["phishworm:linked"] = 1
	check(done(3, 1), "Ch3 s1: a prepared Phishing copy advances it")
	# step 2 phishing effect — a launched-but-unarrived card does NOT advance
	g.card_plays[P] = 5
	check(not done(3, 2), "Ch3 s2: cards_played does not advance (effect must resolve)")
	g._apply_effect(P, g.CARDS["phishworm"], prac, 1)
	check(g._stolen(prac) and done(3, 2), "Ch3 s2: Phishing resolving on the target advances it")
	# step 3 response clears rival phishing (fired)
	check(not done(3, 3), "Ch3 s3: not done before the rival attack is fired")
	g._camp_fire("ch3_phish")
	check(g._stolen(relay) and not done(3, 3), "Ch3 s3: still stolen → not done")
	g._apply_effect(P, g.CARDS["response"], relay, 1)
	check(not g._stolen(relay) and done(3, 3), "Ch3 s3: Response clearing the theft advances it")
	# step 4 ddos
	g._apply_effect(P, g.CARDS["ddos"], prac, 1)
	check(g._prod_down(prac) and g._routing_down(prac) and done(3, 4), "Ch3 s4: DDoS resolving advances it")
	# step 5 cdn clears your ddos (fired)
	g._camp_fire("ch3_ddos")
	check(g._prod_down(relay) and not done(3, 5), "Ch3 s5: your service down → not done")
	g._apply_effect(P, g.CARDS["cdn"], relay, 1)
	check(not g._prod_down(relay) and done(3, 5), "Ch3 s5: CDN restoring service advances it")
	# step 6 0day: the authored dormant WIRE (not just a graph edge) must satisfy needs_link so the highlighted host accepts the card
	g._tut_stage = 6
	check(g._linked(P, prac2) and g._can_play(P, "zeroday:linked", prac2) == "", "Ch3 s6: the authored dormant connection lets 0day target the Practice host")
	g.cards[P]["zeroday:linked"] = 0   # a 25% breach miss spent the only supplied copy
	g._camp_tick()
	check(g._held(P, "zeroday:linked") >= 1, "Ch3 s6: a spent 0day is re-granted so 'try again' is always possible")
	# step 6 capture
	check(not done(3, 6), "Ch3 s6: not done before capture")
	g._capture(prac2, P)
	check(done(3, 6), "Ch3 s6: seizing the connected host advances it")
	# step 7 patch (shield up); the rival 0day then bounces
	check(not done(3, 7), "Ch3 s7: not done before the shield is up")
	g._apply_effect(P, g.CARDS["patch"], support, 1)
	check(float(g.hosts[support].patch_until) > g._t and done(3, 7), "Ch3 s7: Patch day up advances it")
	g._camp_fire("ch3_0day")
	check(g._mine(support), "Ch3 s7: the rival 0day was blocked by Patch day")
	# step 8 supply wipes a built rival host
	check(not done(3, 8), "Ch3 s8: not done before the wipe")
	g._apply_effect(P, g.CARDS["supply"], prac, 1)
	check(g._built_kinds(prac).is_empty() and int(g.hosts[prac].owner) == R and done(3, 8), "Ch3 s8: Supply wiping the host advances it")
	# step 9 sca shield; supply bounces
	g._apply_effect(P, g.CARDS["sca"], support, 1)
	check(float(g.hosts[support].sca_until) > g._t and done(3, 9), "Ch3 s9: SCA up advances it")
	var builds_before = g._built_kinds(support).size()
	g._camp_fire("ch3_supply")
	check(g._built_kinds(support).size() == builds_before, "Ch3 s9: the rival Supply was blocked by SCA")
	# idempotent supplies
	var held0 = g._held(P, "ddos:linked")
	g._camp_supply("ddos:linked")
	check(g._held(P, "ddos:linked") == held0, "Ch3: a supply already granted this chapter is not duplicated")
	# the tester's dead end: the step's single card was used up earlier (e.g. Patch day dropped on the relay) — it is handed back,
	# but never while a copy is still flying or being prepared
	fresh(); g._start_campaign(3)
	support = g._camp_support; prac = g._camp_practice; prac2 = g._camp_practice2
	check(str(g.hosts[prac].name) != str(g.hosts[prac2].name), "Ch3: the two practice targets have different names")
	g._tut_stage = 7; g.cards[P]["patch:linked"] = 0
	g.flights.append({"kind": "card", "owner": P, "card": "patch:linked", "route": [support], "hops": [], "depart_t": 0.0, "arrive_t": 1e9})
	g._camp_tick()
	check(g._held(P, "patch:linked") == 0, "Ch3 s7: no extra copy while one is still in flight")
	g.flights.pop_back()
	(g.lab[P].queue as Array).append("patch:linked")
	g._camp_tick()
	check(g._held(P, "patch:linked") == 0, "Ch3 s7: no extra copy while one is being prepared")
	(g.lab[P].queue as Array).clear()
	g._camp_tick()
	check(g._held(P, "patch:linked") == 1 and g._tut_stage == 7, "Ch3 s7: a used-up Patch day is handed back so the step can't dead-end")
	# the attack lessons keep their target: a Practice host the player captured is taken back by the rival
	g._tut_stage = 8; g._capture(prac, P)
	g._camp_tick()
	check(int(g.hosts[prac].owner) == R and g._can_play(P, "supply:linked", prac) == "", "Ch3 s8: a captured Practice host returns to the rival so Supply can still land")
	# 0day: one honest miss, then the retry lands
	g._camp_events["0day_missed"] = true
	g._apply_effect(P, g.CARDS["zeroday"], prac2, 1)
	check(g._mine(prac2), "Ch3 s6: after one recorded miss the campaign's retry always lands")


func chapter4() -> void:
	fresh(); g._start_campaign(4)
	var vault: int = g._camp_vault
	check(g._is_mission(vault) and int(g.hosts[vault].owner) == R, "Ch4: the vault carries the objective and is the rival's")
	var neg := 0
	for i in g.hosts.size():
		if g._mine(i) and float(g.hosts[i].bots) < 0.0: neg += 1
	check(neg == 0 and g._camp_foothold >= 0 and g._mine(g._camp_foothold), "Ch4: every computer the campaign hands you starts garrisoned (no negative bots); the vault foothold is yours")
	g._camp_set_pause(false)
	# step 0 scan
	check(not done(4, 0), "Ch4 s0: not done before scanning")
	g._mark_scanned(P, vault)
	check(done(4, 0), "Ch4 s0: scanning advances it")
	# step 1 access (not ownership)
	g.intel[P] = 500.0; g.creds[P] = 500.0
	check(not done(4, 1), "Ch4 s1: not done before access")
	g._do_access(P, vault)
	check(g._access_live(P, vault) and not g._mine(vault) and done(4, 1), "Ch4 s1: temporary access (vault still the rival's) advances it")
	# step 2 extract — drive the sim until a record lands (hold the reading pause off, as acting would)
	for k in int(60.0 / g.SIM_DT):
		g._camp_paused = false
		g._sim_step(g.SIM_DT)
		if g._records_got(P, vault) >= 1.0: break
	check(done(4, 2), "Ch4 s2: a record delivered home advances it (%d)" % int(g._records_got(P, vault)))
	# step 3 detection — entering it fires ch4_detect (snapshot progress + cut the route); it must NOT auto-complete on entry
	g._tut_stage = 2; g._camp_next()
	check(g._tut_stage == 3 and bool(g._camp_events.get("ch4_detect", false)), "Ch4 s3: entering the step fires the detection beat")
	check(not done(4, 3), "Ch4 s3: does not auto-complete on entry (needs one more record past the trace)")
	g.records_home[g._mkey(P, vault)] = g._camp_detect_mark + 1.0
	check(done(4, 3), "Ch4 s3: recovering another record after the trace advances it")
	# step 4 resolve (complete then choose)
	g.records_home[g._mkey(P, vault)] = float(g.hosts[vault].records_total)
	check(not done(4, 4), "Ch4 s4: complete but unresolved → not done")
	g._do_resolve(P, vault, "sell")
	check(done(4, 4), "Ch4 s4: resolving (sell) advances it")


func chapter5() -> void:
	fresh(); g._start_campaign(5)
	check(not g._ai_paused, "Ch5 runs with the rival active")
	check(g._camp_target() == -1, "Ch5 highlights no solution")
	check(not done(5, 0), "Ch5: not done before winning")
	g.won = true
	check(done(5, 0), "Ch5: a genuine win completes the campaign")
	# the win is set synchronously inside _sim_step, which then halts the sim — completion must fire on that same step, not only on a 0.25s panel tick
	fresh(false)
	var def_enemies: int = g._opt_enemies
	g._start_campaign(5); g._camp_set_pause(false)
	g.won = true; g._sim_step(g.SIM_DT)
	check(not g._camp and g._camp_done.count(true) >= g.CAMP_CHAPTERS, "Ch5: a win inside _sim_step finishes the campaign (not stranded on the panel-tick gate)")
	check(g._opt_enemies == def_enemies, "Finishing restores the player's New-game enemy count (not left at the campaign's 1)")
	# a loss keeps the player inside the mandatory flow with a Retry affordance, instead of _reset into free play
	fresh(false); g._start_campaign(5); g._camp_set_pause(false)
	g.lost = true; g._process(1.0 / 30.0)
	g._refresh_panel()
	check(g._camp and has_button(g.panel_box, "Retry chapter") and not has_button(g.panel_box, "Restart in a new town"), "Ch5: a loss stays in the campaign: the only way on is Retry chapter")


func reading_pause() -> void:
	fresh(); g._start_campaign(1)
	g._camp_set_pause(true)
	var t0: float = g._t; var relay: int = g._camp_relay
	var b0 = float(g.hosts[relay].bots)
	for k in 90: g._sim_step(g.SIM_DT)
	for k in 90: g._process(1.0 / 30.0)
	check(g._t == t0 and float(g.hosts[relay].bots) == b0, "Reading pause freezes the whole simulation (time and bots unchanged)")
	g._camp_set_pause(false)
	for k in 10: g._sim_step(g.SIM_DT)
	check(g._t > t0, "Resuming advances the simulation again")
	# taking an action auto-resumes
	g._camp_set_pause(true)
	g._cmd(["build", relay, g._free_slot(relay), "intel"])
	check(not g._camp_paused, "Any action resumes the reading pause")


func count_buttons(n: Node) -> int:
	var k := 1 if n is Button and n.is_visible_in_tree() else 0
	for c in n.get_children(): k += count_buttons(c)
	return k


func has_button(n: Node, text: String) -> bool:
	if n is Button and str(n.text) == text: return true
	for c in n.get_children():
		if has_button(c, text): return true
	return false


func review_fixes() -> void:   # regressions for the dead ends the 2026-10-23 adversarial review confirmed
	# Ch2 'Pull back': a spent order (25 %, or simply waiting) still ends the step, and says what Cancel would have kept
	fresh(); g._assault_pct = 25; g._start_campaign(2, true)
	check(g._assault_pct == g.ASSAULT_DEFAULT, "Ch2 starts the Assault button at its default share, not a leftover 25%%")
	var src: int = g._camp_src; var gate: int = g._camp_gateway
	g.hosts[src].bots = 60.0; g.intel[P] = 100.0
	g._do_wire(P, [src], gate); g._do_assault(P, gate, 25)
	for k in int(15.0 / g.SIM_DT):
		g._camp_paused = false   # act as the player would (any command ends the reading pause)
		g._sim_step(g.SIM_DT)
		if not g._assault_active(src): break
	g._tut_stage = 2
	check(not g._assault_active(src) and done(2, 2) and g._camp_outcome().contains("already sent"), "Ch2 s2: an Assault that ran out still ends the step, with an honest result")
	# acting during a result: the next step does not open frozen
	fresh(); g._start_campaign(1, true)
	var relay: int = g._camp_relay
	g._set_builds(relay, ["intel"]); g._camp_tick()
	g._cmd(["build", relay, g._free_slot(relay), "cash"])
	for k in int((g.CAMP_HOLD_STEP + 0.3) * 30): g._process(1.0 / 30.0)
	check(g._tut_stage == 1 and not g._camp_paused, "A step already started during the previous result opens running, not frozen")
	g._camp_paused = true; g._set_builds(relay, ["intel", "cash"])
	g._process(1.0 / 30.0)
	check(not g._camp_paused, "A step that is already done never sits in a reading pause")
	# Ch1 'Spend it': the 30-Crypto farm is affordable when asked for
	fresh(); g._start_campaign(1, true); g.cash[P] = 2.0
	g._tut_stage = 2; g._camp_next()
	check(g._tut_stage == 3 and float(g.cash[P]) >= 30.0, "Ch1 s3: Crypto is topped up to the farm's price")
	# Ch4: a captured vault goes back to its owner (records only flow through access)
	fresh(); g._start_campaign(4, true)
	var vault: int = g._camp_vault
	check(str(g.hosts[vault].name) == "Records vault", "Ch4: the map names the vault as the lesson does")
	g._capture(vault, P); g._camp_tick()
	check(int(g.hosts[vault].owner) == R and g._can_access(P, vault) != "you own this computer", "Ch4: capturing the vault hands it back so access can still be taught")
	# mid-chapter menu: Resume only, no second button that silently restarts the chapter
	fresh(); g._start_campaign(2, true); g._open_menu(true); g._menu_view = "main"; g._refresh_menu()
	check(has_button(g.menu_box, "Resume") and not has_button(g.menu_box, "▶ Continue the guided campaign"), "Mid-chapter, the menu offers Resume and no restart-in-disguise")
	# a finished chapter is saved the moment its result shows
	fresh(); g._start_campaign(1)
	relay = g._camp_relay
	g._tut_stage = 3; g._set_builds(relay, ["intel", "cash", "bot"]); g._camp_tick()
	var sv: Dictionary = g._camp_load()
	check(g._camp_hold_left > 0.0 and int(sv.get("chapter", -1)) == 2 and bool((sv.get("chapters_completed", []) as Array)[1]), "Closing the game during a chapter's end banner keeps the chapter finished")
	# leaving for the menu mid-campaign keeps the player's own New-game options safe until the campaign is finished
	fresh(); g._opt_enemies = 3; g._start_campaign(2)
	g._camp_leave(); g._open_menu(false)
	g._camp_finish()
	check(g._opt_enemies == 3, "The player's own enemy count survives a mid-campaign trip to the menu")
	check(g._tut_rich("CUT").contains("ff66a6"), "The banner's CUT is the map's pink")


func outcome_beat() -> void:   # playtest: "steps are very fast" — a finished step shows what it did before the next one
	fresh(); g._start_campaign(1, true)
	var relay: int = g._camp_relay
	g._set_builds(relay, ["intel"]); g._camp_tick()
	check(g._tut_stage == 0 and g._camp_hold_left > 0.0 and g._camp_hold_text.contains("Intel harvester"), "A finished step stays on screen with its result")
	check(g._camp_ui_targets().is_empty() and g._camp_from() == -1, "Nothing blinks while the result shows")
	for k in int((g.CAMP_HOLD_STEP + 0.2) * 30): g._process(1.0 / 30.0)
	check(g._tut_stage == 1 and g._camp_hold_left == 0.0, "After the result, the next step begins")
	# the records decision: its consequence shows, and the board is not rebuilt until the longer chapter-end beat is over
	fresh(); g._start_campaign(4, true)
	var vault: int = g._camp_vault
	g._tut_stage = 4; g.records_home[g._mkey(P, vault)] = float(g.hosts[vault].records_total)
	g._do_resolve(P, vault, "sell"); g._camp_tick()
	check(g._camp_chapter == 4 and g._camp_hold_text.contains("+%d Crypto" % int(g.MIS_SELL_CRYPTO)), "Selling the records shows the Crypto it earned before the chapter ends")
	check(is_equal_approx(g._camp_hold_left, g.CAMP_HOLD_CHAPTER), "The end of a chapter holds longer than a step")
	fresh(); g._start_campaign(4, true)
	vault = g._camp_vault
	g._tut_stage = 4; g.records_home[g._mkey(P, vault)] = float(g.hosts[vault].records_total)
	g._do_resolve(P, vault, "publish"); g._camp_tick()
	check(g._camp_hold_text.contains("Community Relay") and g._camp_target() == g._camp_commrelay, "Publishing shows its effect and rings the Community Relay")
	# a scripted answer plays during the result, not after it
	fresh(); g._start_campaign(3, true)
	g._tut_stage = 7; g._apply_effect(P, g.CARDS["patch"], g._camp_support, 1); g._camp_tick()
	check(bool(g._camp_events.get("ch3_0day", false)) and g._camp_hold_left > 0.0, "The rival's 0day bounces off Patch day while the result is on screen")


func banner() -> void:   # the training is unskippable: the banner carries text only, and doing the step is what starts the clock
	fresh()
	var with_buttons := 0
	for ch in g.CAMP_CHAPTERS:
		g._start_campaign(ch, true)
		for st in g._camp_steps(ch).size():
			g._tut_stage = st; g._show_tut()
			with_buttons += count_buttons(g.tut_panel)
	check(with_buttons == 0, "No chapter or step puts a button on the training banner (%d found)" % with_buttons)
	g._start_campaign(1, true)
	check(g._camp_paused, "A step that asks for an action opens with the clock stopped")
	var relay: int = g._camp_relay
	g._cmd(["build", relay, g._free_slot(relay), "intel"])
	check(not g._camp_paused, "Doing the step starts the clock")
	for ch in g.CAMP_CHAPTERS:
		for st in g._camp_steps(ch):
			if str(st.a).begins_with("Wait") and bool(st.get("pause", false)): with_buttons += 100
	check(with_buttons == 0, "A step whose only action is to wait never stops the clock (nothing would restart it)")


func harness_save() -> void:   # tests must never touch the player's real progress file
	fresh()
	check(g._camp_save_path() != g.CAMP_SAVE, "A harness-built game saves to its own file, never the player's campaign.json")


func ui_cues() -> void:   # the step's UI element is found (to blink), and keeps pulsing through the reading pause
	fresh(); g._start_campaign(3)
	g._tut_stage = 1; g._set_deck_open(false)
	var ts: Array = g._camp_ui_targets()
	check(ts.size() == 1 and str(ts[0].key) == "phishworm:linked", "Ch3 s1: the Phishing deck card is the blink target")
	g._tut_stage = 3; g._set_deck_open(true)
	if g._card_bank != "attack": g._bank_pressed("attack")
	ts = g._camp_ui_targets()
	check(ts.size() == 1 and ts[0] == g.card_banks.get_child(1), "Ch3 s3: with the deck on ATTACK, the DEFENCE tab blinks (the card is behind it)")
	g._bank_pressed("defense")
	ts = g._camp_ui_targets()
	check(ts.size() == 1 and str(ts[0].key) == "response:linked", "Ch3 s3: on DEFENCE, the Incident response card itself blinks")
	fresh(); g._start_campaign(1)
	var relay: int = g._camp_relay
	g.sel = {relay: true}; g._refresh_panel()
	ts = g._camp_ui_targets()
	check(ts.size() == 1 and str(ts[0].kind) == "intel", "Ch1 s0: the Intel harvester build card is the blink target")
	g._set_builds(relay, ["intel"])
	check(g._camp_ui_targets().is_empty(), "Ch1 s0: the blink stops once the installation exists")
	g._set_builds(relay, [])   # back to a step that still needs the player (a done step never stays paused)
	g._camp_set_pause(true)
	var t0: float = g._t; var c0: float = g._camp_clock; var p0: float = g._camp_pulse()
	for k in 6: g._process(0.05)
	check(g._t == t0 and g._camp_clock > c0 + 0.25 and absf(g._camp_pulse() - p0) > 0.05, "Cues keep pulsing on the wall clock while the reading pause freezes the game")


func rich_text() -> void:   # every training text renders exactly as written (no corruption), with game terms coloured
	fresh()
	var rtl := RichTextLabel.new(); rtl.bbcode_enabled = true; g.add_child(rtl)
	var strip := RegEx.create_from_string("\\[img[^\\]]*\\][^\\[]*\\[/img\\] ")
	var bad := 0; var n := 0
	for ch in g.CAMP_CHAPTERS:
		g._start_campaign(ch, true)
		var texts := []
		for st in g._camp_steps(ch): texts.append_array([str(st.a), str(st.w)])
		for s in texts:
			n += 1
			rtl.text = strip.sub(g._tut_rich(s), "", true)
			if rtl.get_parsed_text() != s: bad += 1; print("  corrupted: ", s)
	check(n > 50 and bad == 0, "All %d campaign texts render exactly as written" % n)
	var odd := "a [b] bracket [lb] 30 Crypto 0day 51% 7"
	rtl.text = strip.sub(g._tut_rich(odd), "", true)
	check(rtl.get_parsed_text() == odd, "Brackets and digits survive the colouring")
	check(g._tut_rich("Scanning reveals Intelligence; SCAN").count("[color=") == 0, "Only whole words are coloured")
	check(g._tut_rich("Build a Bot farm").contains(g.BUILD_KINDS.bot.col.to_html(false)) and g._tut_rich("Drag Incident response").contains(g.BANK_COL["defense"].to_html(false)), "Installations take their card colour; cards take their deck colour")
	check(g._tut_rich("Drag 0day").contains("schematic/zeroday.png"), "A card name carries its card art as an inline icon")
	var src := FileAccess.get_file_as_string("res://scripts/botnet_proto.gd")
	check(not src.contains(char(1)) and not src.contains(char(2)), "No hidden control characters in the game script")
	rtl.queue_free()


func menu_resume() -> void:
	fresh(); g._start_campaign(0)   # opening reading pause: _camp is true, _t == 0
	check(g._t == 0.0 and g._camp, "A campaign opens at _t==0 under the reading pause")
	g._open_menu(true); g._menu_view = "main"; g._refresh_menu()
	var has_resume := false
	for c in g.menu_box.get_children():
		if c is Button and (c as Button).text == "Resume": has_resume = true
	check(has_resume, "The main menu offers Resume during a campaign reading pause at _t==0")


func persistence() -> void:
	fresh(); g._start_campaign(2)
	var save = g._camp_load()
	check(int(save.get("chapter", -1)) == 2, "Save records the current chapter")
	# resume forces the fixed seed even if New-game options were changed
	g._opt_seed = 99999; g._opt_size = Vector2i(6, 4)
	g._camp_resume_or_start()
	check(g._camp_chapter == 2 and g._opt_seed == g.CAMP_SEED and g._camp_relay >= 0, "Resume rebuilds the authored checkpoint on the fixed seed, not a random map")
	# checkpoint determinism: two fresh builds of the same chapter match
	fresh(); g._start_campaign(3); var h1 = g._mp_hash()
	fresh(false); g._start_campaign(3); var h2 = g._mp_hash()
	check(h1 == h2, "A chapter checkpoint rebuilds deterministically")
	# completion persists across launches
	fresh(false)
	for k in g.CAMP_CHAPTERS: g._camp_done[k] = true
	g._camp_save()
	fresh(false)
	check(g._camp_has_onboarded(), "Completion persists across launches")
	# replay does not reset completion or move the resume point
	g._start_campaign(1, true)
	check(g._camp_replay and g._camp_has_onboarded(), "Replaying a chapter keeps completion")


func no_leak() -> void:
	fresh(false); g._start_campaign(3)
	check(g._camp and g._camp_relay >= 0 and not g._camp_supplied.is_empty(), "Campaign state is set during a chapter")
	g._opt_mission = false; g._opt_seed = 0
	g._reset()
	check(not g._camp and not g._camp_paused and g._camp_chapter == 0 and g._camp_relay == -1 and g._camp_supplied.is_empty() and g._camp_cash_landed == 0, "A normal _reset clears every campaign flag — no training state leaks into play")


func mandatory_gate() -> void:
	fresh()   # wipes the save → first run
	check(not g._camp_has_onboarded(), "A fresh profile has not onboarded (campaign is mandatory)")
	for k in g.CAMP_CHAPTERS: g._camp_done[k] = true
	g._camp_save()
	check(g._camp_has_onboarded(), "After finishing, onboarding is remembered")
