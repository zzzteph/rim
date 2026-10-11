extends SceneTree
## Renders ~30 screenshots of the v2 prototype in scripted states. Run under Xvfb:
##   xvfb-run -a godot --path <project> --rendering-driver opengl3 --script res://gallery.gd

var game
var shot_n := 0
var greedy_think := 0.0

func _initialize() -> void:
	_run.call_deferred()

func fresh(seed_v: int, rival_on: bool = false) -> void:
	if is_instance_valid(game):
		game.free()
	game = load("res://scripts/botnet_proto.gd").new()
	game.town_seed = seed_v
	root.add_child(game)
	game.set_process(false)            # we step the simulation by hand so every shot is deterministic
	game.ai_enabled = rival_on
	greedy_think = 0.0

func rigP() -> int: return int(game.rig[game.PLAYER])
func secondP() -> int: return game.cell_at(0, 1)

func neutral_nb(i: int, exclude: Array = []) -> int:
	for o in game.hosts[i].links:
		if int(game.hosts[o].owner) == game.NEUTRAL and not exclude.has(int(o)): return int(o)
	return -1

func sim(seconds: float, greedy: bool = false) -> void:
	var n := int(round(seconds / 0.1))
	for k in n:
		game._process(0.1)
		if greedy:
			greedy_think += 0.1
			if greedy_think >= 1.0:
				greedy_think = 0.0
				_greedy_player()

func shoot(name: String) -> void:
	game._process(0.0)                 # refresh HUD + queue a redraw without advancing time
	game._refresh_panel()
	await process_frame
	await process_frame
	await process_frame
	shot_n += 1
	var img: Image = root.get_viewport().get_texture().get_image()
	var path := "res://gallery/%02d_%s.png" % [shot_n, name]
	img.save_png(path)
	print("saved ", path)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://gallery"))
	# ── towns: different every run ──
	for s in [7, 11, 23, 42]:
		fresh(s)
		await shoot("town_seed_%d" % s)

	# ── the command flow on seed 7 ──
	fresh(7)
	var rp := rigP(); var sp := secondP()
	game.hosts[rp].builds = ["bot", "bot", "intel"]; game.intel[game.PLAYER] = 100.0   # fuel for the whole sequence
	var t1 := neutral_nb(rp, [sp])
	var t2 := neutral_nb(sp, [rp, t1])
	if t2 < 0: t2 = neutral_nb(sp, [rp])
	game.sel = {sp: true}
	await shoot("select_one_building")
	game.sel = {sp: true, rp: true}
	await shoot("select_group")
	game._wire(t1)
	await shoot("wired_dormant_launch_pad")
	game.sel = {sp: true}; game._wire(rp)
	await shoot("guard_wire_standby")
	game.sel = {sp: true, rp: true}; game._wire(t1); game._launch(t1)
	sim(6.0)
	await shoot("attack_launched_two_streams_link_busy")
	game._clear_all(); game._inspect = t1
	await shoot("inspect_target_reducing_defenders")
	# a single stream that cannot overcome regeneration, on a second target
	if t2 >= 0:
		game.hosts[sp].assign = t2; game.hosts[sp].live = true
		sim(4.0)
		game._clear_all(); game._inspect = t2
		await shoot("inspect_not_overcoming_regeneration")
		game.hosts[sp].assign = t1; game.hosts[sp].live = true
	# run until the first target falls
	var guard := 0
	while int(game.hosts[t1].owner) != game.PLAYER and guard < 400:
		sim(0.5); guard += 1
	game._clear_all()
	sim(0.5)
	await shoot("captured_flows_become_guards")
	# rally point with auto-supply flowing
	game._cancel_to(t1)
	game.rally = t1
	sim(4.0)
	game.sel = {t1: true}
	await shoot("rally_point_auto_supply")
	# rate dial
	game.rally = -1
	game.sel = {sp: true}; game._adjust_rate(-0.5)
	await shoot("rate_dial_50_percent")
	game.hosts[sp].rate = 1.0
	# a guard arms itself when the building it protects is damaged
	game.sel = {sp: true}; game._wire(rp); game.hosts[rp].bots = 20.0
	sim(4.0)
	game.sel = {sp: true}
	await shoot("guard_arms_when_damaged")
	game._cancel_to(rp)
	# cash flowing home
	game.hosts[t1].builds = ["bot", "cash", "cash"]; game.hosts[t1].bots = 25.0; game.hosts[rp].builds = ["bot", "bot", "cash"]
	sim(8.0)
	game._clear_all()
	await shoot("cash_packets_travelling_home")

	# ── the local view (micro) ──
	game.sel = {sp: true}; game._enter(sp)
	await shoot("enter_building_connecting")
	sim(2.5)
	await shoot("inside_building_slots")
	game._player_build(sp, "cash")
	sim(2.0)
	await shoot("inside_build_job_in_progress")
	sim(5.0)
	game.hosts[sp].builds = ["bot", "intel", "cash"]
	await shoot("inside_slots_full_demolish")
	game._leave()

	# ── threats ──
	var rn := neutral_nb(sp, [rp, t1])
	if rn < 0: rn = neutral_nb(t1, [rp, sp])
	if rn >= 0:
		game.hosts[rn].owner = game.RIVAL; game.hosts[rn].bots = 30.0; game.hosts[rn].assign = sp; game.hosts[rn].live = true
		game._flash("⚔ NYX is attacking %s with 1 source(s) — defend it!" % str(game.hosts[sp].name))
		sim(4.0)
		game._clear_all()
		await shoot("under_attack_red_ring")
		game.sel = {sp: true}; game._enter(sp); sim(2.5)
		await shoot("inside_while_under_attack")
		game._leave()
	game.paused = true
	await shoot("paused")
	game.paused = false

	# ── a scripted match (greedy player with perfect attention vs the rival), one shot per minute ──
	fresh(7, true)
	for m in [1, 2, 3, 4, 5]:
		sim(60.0, true)
		game._clear_all()
		await shoot("match_seed7_%d_min" % m)
		if game.won or game.lost: break
	fresh(11, true)
	sim(180.0, true)
	game._clear_all()
	await shoot("match_seed11_3_min")

	# ── endings ──
	fresh(7)
	game.cash[game.PLAYER] = game.CASH_GOAL - 150.0; game.cash[game.RIVAL] = 410.0
	game._bank(game.PLAYER, 150.0)
	await shoot("victory_screen")
	fresh(7)
	game.cash[game.PLAYER] = 260.0
	game._bank(game.RIVAL, game.CASH_GOAL)
	await shoot("defeat_nyx_banked_first")
	fresh(7)
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.PLAYER: game.hosts[i].owner = game.RIVAL
	sim(0.1)
	await shoot("defeat_lost_last_building")
	print("GALLERY_COMPLETE %d shots" % shot_n)
	quit()


# the probe's greedy player: builds Intel then markets/farms, releases finished orders, attacks the
# softest neighbour with enough concentrated streams, with perfect attention
func _greedy_player() -> void:
	var mine := []
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == game.PLAYER: mine.append(i)
	for i in mine:
		var a := int(game.hosts[i].assign)
		if a >= 0 and int(game.hosts[a].owner) == game.PLAYER: game.hosts[i].assign = -1; game.hosts[i].live = false
	if game._inside >= 0 and not (game.hosts[game._inside].job as Dictionary).is_empty(): return
	game._inside = -1
	var intel_n := 0; var cash_n := 0
	for i in mine: intel_n += game._count_all(i, "intel"); cash_n += game._count_all(i, "cash")
	for i in mine:
		if (game.hosts[i].builds as Array).size() >= int(game.hosts[i].slots) or not (game.hosts[i].job as Dictionary).is_empty(): continue
		var frontier := false
		for p in game.hosts[i].links:
			if int(game.hosts[p].owner) != game.PLAYER: frontier = true
		var kind := "cash"
		if intel_n < 2: kind = "intel"
		elif frontier and game._count_all(i, "bot") < 2: kind = "bot"
		elif cash_n <= intel_n: kind = "cash"
		else: kind = "intel"
		if game._start_job(i, kind):
			game._inside = i; game._enter_left = game.ENTER_TIME
			break
	var active := false
	for i in mine:
		if int(game.hosts[i].assign) >= 0 and bool(game.hosts[i].live): active = true
	if active: return
	var cands := []
	for i in mine:
		for p in game.hosts[i].links:
			if int(game.hosts[p].owner) != game.PLAYER and not cands.has(p): cands.append(p)
	if cands.is_empty(): return
	var pick := -1; var best := INF
	for c in cands:
		var score: float = float(game.hosts[c].bots) - 3.0 * float(game.hosts[c].value)
		if score < best: best = score; pick = int(c)
	var regen: float = float(game._count(pick, "bot")) * game.PROD_RATE
	var need: int = maxi(2, floori(regen * game.DEFEND_POWER / (game.ATTACK_POWER * game.SEND_RATE)) + 2)
	var srcs := []
	for i in mine:
		if float(game.hosts[i].bots) < 12.0: continue
		var rt: Array = game._route(i, pick)
		if not rt.is_empty(): srcs.append([rt.size(), i])
	srcs.sort_custom(func(a, b): return a[0] < b[0])
	if srcs.size() < 2: return
	for s in srcs.slice(0, mini(need, srcs.size())):
		game.hosts[int(s[1])].assign = pick; game.hosts[int(s[1])].live = true
