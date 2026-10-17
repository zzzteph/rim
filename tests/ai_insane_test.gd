extends SceneTree
## Run: godot --headless --path . --script tests/ai_insane_test.gd
## The Insane brain (scripts/botnet_ai_insane.gd). It must:
##  · play every part of the game (wire, launch, build, research, play cards) and win: a clear majority of fixed-seed
##    matches against the Normal AI, on every map size
##  · be deterministic (same seed → same match), survive long matches, stay inside its CPU budget
##  · play FAIR — under the human's fog of war: at several points of real matches a second copy of the match has every
##    piece of information the brain must not see scrambled (rivals' resources, cards, research, scans; hosts out of
##    view; unscanned bot counts; undrawn wires; invisible packets), and the brain must decide exactly the same
##  · read the world only through its FAIR VIEW section (a static lint over its source)
## AI-only matches vacate the human seat: its two corner hosts turn into ordinary neutral buildings, so the result is
## decided between the AI botnets alone (one match also keeps an idle human seat, the real single-player setup).

const BRAIN := "res://scripts/botnet_ai_insane.gd"
const SIZES := {"s": Vector2i(6, 4), "m": Vector2i(8, 6), "b": Vector2i(10, 8)}

var checks := 0
var failures: Array = []
var report := {}
var errlog: ErrLog
var tally := {}   # command kind -> how many the Insane brains issued over the whole suite


class ErrLog extends Logger:   # every script error raised while the matches run is a failure
	var errors: Array = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type == ERROR_TYPE_SCRIPT and errors.size() < 20: errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])
	func _log_message(_message: String, _error: bool) -> void:
		pass


class Clock extends RefCounted:   # times one brain's ticks (the brain itself never reads a clock)
	var inner
	var n := 0
	var total := 0
	var worst := 0
	func tick(dt: float) -> void:
		var t0 := Time.get_ticks_usec()
		inner.tick(dt)
		var d := Time.get_ticks_usec() - t0
		n += 1; total += d
		if d > worst: worst = d


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok    " if ok else "FAIL  ") + label)
	if not ok: failures.append(label)


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	errlog = ErrLog.new()
	OS.add_logger(errlog)
	_lint()
	_versus_normal()
	_determinism()
	_cost_and_long_match()
	_idle_human_seat()
	_zero_stock_opening()
	_fog_fairness()
	for kind in ["wire", "launch", "build", "research", "card", "produce"]:
		check(int(tally.get(kind, 0)) > 0, "the brain issues '%s' commands (%d over the suite)" % [kind, int(tally.get(kind, 0))])
	check(errlog.errors.is_empty(), "no script error while the brains played (%s)" % str(errlog.errors))
	OS.remove_logger(errlog)
	report["commands"] = tally
	report["runtime_s"] = (Time.get_ticks_msec() - t0) / 1000.0
	print(JSON.stringify({"checks": checks, "failures": failures, "report": report}))
	quit(0 if failures.is_empty() else 1)


# ------------------------------------------------------------ match plumbing
func _game(size: String, enemies: int, seed: int, levels: Dictionary, seat := "off"):
	var g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = SIZES[size]; g._opt_enemies = enemies; g._opt_seed = seed; g._opt_ai_level = "normal"
	root.add_child(g); g.set_process(false); g._open_menu(false)
	for f in levels: g.ai_level[f] = levels[f]
	if seat == "off":   # the human seat leaves: its hosts become ordinary rim buildings and only the AIs play
		g.botnets = g.ais.duplicate()
		g._mp_on = true   # (only so the single-player "your rig fell" check never ends an AI-only match)
		for i in g.hosts.size():
			if int(g.hosts[i].owner) == g.PLAYER:
				g.hosts[i].owner = g.NEUTRAL; g.hosts[i].rig = false
				g.hosts[i].sec = 9.0; g.hosts[i].bots = 9.0; g._set_builds(i, ["bot"])
		g._refresh_sight()
	g.panel_box = null   # headless: the sidebar is never rebuilt (UI only, the simulation is untouched) — keeps the suite fast
	return g


func _insane(g) -> Array:
	var out := []
	for f in g.ais:
		if str(g.ai_level.get(f, "")) == "insane": out.append(int(f))
	return out


func _step(g) -> void:   # one simulation step; brains created by the game's own _ai_tick start recording at once
	g._sim_step(g.SIM_DT)
	for f in g._brains:
		var b = g._brains[f]
		if b is Clock: b = b.inner
		if b.record == null: b.record = []


func _play(g, cap: float) -> void:
	while not g.won and not g.lost and g._t < cap: _step(g)


func _brain(g, f: int):
	var b = g._brains.get(f)
	return b.inner if b is Clock else b


func _winner(g) -> int:
	if g.won: return g.PLAYER
	if not g.lost: return -1
	for f in g.ais:
		if str(g._end_cause).find(g.fname(f)) >= 0: return int(f)
	return int(g.hosts[int(g.rig[g.PLAYER])].owner)   # the idle human's rig fell: to whom


func _count(g) -> void:   # add the brains' commands to the suite's tally
	for f in g._brains:
		var b = _brain(g, f)
		for c in b.record: tally[str(c[0])] = int(tally.get(str(c[0]), 0)) + 1


# ------------------------------------------------------------ 1. fairness lint over the brain's source
func _lint() -> void:
	var src := FileAccess.get_file_as_string(BRAIN)
	check(src.length() > 1000, "brain source readable")
	var cut := src.find("\n# ============================================================ FAIR VIEW")
	check(cut > 0, "brain source has a FAIR VIEW section")
	var outside := _code(src.substr(0, cut))
	var inside := _code(src.substr(cut))
	var all := outside + "\n" + inside
	var bad := []
	# outside FAIR VIEW: no live state of any host, no packets, no resources / cards / research / scans / memories
	for pat in ["\\.(owner|bots|builds|jobs|assign|live|mode|rate|value|sec|producer_paused|steal_by|steal_until|patch_until|sca_until|prod_off|route_off|boost_until|hit_t|card_result)\\b",
			"game\\.(flights|intel|cash|creds|research|cards|lab|scans|card_plays|_ai\\b|_seen|_next_depart|_next_cash|_crypto_credit|_res\\b|_departures)"]:
		bad += _matches(pat, outside)
	# anywhere: no clock, no global randomness, no game RNG, no helper that reads hidden state, no mutation but the command door
	for pat in ["\\bTime\\.", "\\bOS\\.", "\\brandi", "\\brandf", "randomize", "game\\.rng",
			"_ai_think|_ai_others_on|_ai_chain_reach|_ai_worm_value|_ai_seen_drain|_ai_remember|_ai_known_|_ai_prior_bots|_ai_leader|_control_leader|_bot_sum|_hostile_incoming|_under_attack|_threat_rate|_incoming\\(|_attack_demand|_intel_rate|_cash_rate|_cred_rate|_research_rate|_kind_total|_hand_size|_research_items|game\\._pool\\(",
			"game\\._(start_job|play_card|queue_research|dequeue_research|requeue_first|toggle_\\w+|capture|set_builds|mark_scanned|scan_land|do_\\w+|ai_release|cancel_job|demolish|launch|wire|halt|cmd|drop_build|disconnect_source|apply_effect|land_card|bank|pool_add)\\b",
			"game\\.[\\w.\\[\\]]+\\s*(=|\\+=|-=|\\*=)[^=]"]:
		bad += _matches(pat, all)
	# inside FAIR VIEW: resources, cards, research and scans of this faction only
	bad += _matches("game\\.(intel|cash|creds|research|cards|lab|scans)\\[(?!fac\\])", inside)
	check(bad.is_empty(), "fairness lint: no hidden reads outside FAIR VIEW, no clocks/RNG, no direct mutation (%s)" % str(bad.slice(0, 6)))
	check(all.count("game._apply_cmd(") == 1, "every action goes through the one command door (game._apply_cmd)")


func _code(text: String) -> String:   # source without comments and string literals (so prose never trips the lint)
	var out := PackedStringArray()
	for line in text.split("\n"):
		var keep := ""; var quote := ""; var k := 0
		while k < line.length():
			var ch := line[k]
			if quote != "":
				if ch == "\\": k += 2; continue
				if ch == quote: quote = ""; keep += "\"\""
				k += 1; continue
			if ch == "\"" or ch == "'": quote = ch; k += 1; continue
			if ch == "#": break
			keep += ch; k += 1
		out.append(keep)
	return "\n".join(out)


func _matches(pattern: String, text: String) -> Array:
	var re := RegEx.new(); re.compile(pattern)
	var out := []
	for m in re.search_all(text): out.append(m.get_string())
	return out


# ------------------------------------------------------------ 2. it beats the Normal AI (fixed seeds, every size)
func _versus_normal() -> void:
	var rows := []
	var wins := 0
	var times := []
	for m in [
		{"size": "s", "enemies": 2, "seed": 1, "levels": {2: "insane", 3: "normal"}},
		{"size": "s", "enemies": 2, "seed": 2, "levels": {2: "normal", 3: "insane"}},
		{"size": "m", "enemies": 2, "seed": 3, "levels": {2: "insane", 3: "normal"}},
		{"size": "m", "enemies": 2, "seed": 4, "levels": {2: "normal", 3: "insane"}},
		{"size": "b", "enemies": 3, "seed": 1, "levels": {2: "insane", 3: "normal", 4: "normal"}},
	]:
		var g = _game(m.size, m.enemies, m.seed, m.levels)
		_play(g, 900.0)
		var w := _winner(g)
		var won: bool = w > 0 and str(g.ai_level.get(w, "")) == "insane"
		if won: wins += 1; times.append(snappedf(g._t, 0.1))
		for f in _insane(g):
			var b = _brain(g, f)
			check(b != null and int(b._stats.cmds) > 20, "%s seed %d: the Insane brain played (%d commands)" % [m.size, m.seed, int(b._stats.cmds) if b != null else 0])
		_count(g)
		rows.append({"map": m.size, "seed": m.seed, "insane_won": won, "end_t": snappedf(g._t, 0.1), "cause": g._end_cause})
		g.free()
	report["versus_normal"] = rows
	check(wins >= 4, "Insane wins a clear majority of fixed-seed matches against Normal: %d/5 (win times %s)" % [wins, str(times)])


# ------------------------------------------------------------ 3. same seed, same match
func _determinism() -> void:
	var prints := []
	for run in 2:
		var g = _game("s", 2, 5, {2: "insane", 3: "insane"})
		_play(g, 400.0)
		var b2 = _brain(g, 2); var b3 = _brain(g, 3)
		prints.append([g._mp_hash(), snappedf(g._t, 0.001), str(g._end_cause), b2.state_hash(), b3.state_hash(), JSON.stringify(b2.record).md5_text(), JSON.stringify(b3.record).md5_text()])
		_count(g)
		g.free()
	check(prints[0] == prints[1], "two runs of one seed end identically: state hash, time, outcome, every brain decision")
	report["determinism"] = {"end_t": prints[0][1], "cause": prints[0][2]}


# ------------------------------------------------------------ 4. CPU budget on a Big map with three Insane AIs; a long match to the end
func _cost_and_long_match() -> void:
	var g = _game("b", 3, 3, {2: "insane", 3: "insane", 4: "insane"})
	_step(g)
	for f in g._brains.keys():   # the game made its brains; time them from here on
		var c := Clock.new(); c.inner = g._brains[f]; g._brains[f] = c
	var steps := 0
	while not g.won and not g.lost and g._t < 900.0:
		_step(g); steps += 1
	var total := 0; var worst := 0; var per := {}
	for f in g._brains:
		var c = g._brains[f]
		if not (c is Clock): continue
		total += c.total; worst = maxi(worst, c.worst)
		per[f] = snappedf(float(c.total) / maxf(1.0, float(steps)), 0.1)
	var avg := float(total) / maxf(1.0, float(steps))
	report["cost_big_3_insane"] = {"steps": steps, "avg_us_per_step_all_brains": snappedf(avg, 0.1), "avg_us_per_brain": per, "worst_tick_us": worst, "end_t": snappedf(g._t, 0.1), "cause": g._end_cause}
	check(avg < 300.0, "Big 10x8, 3 Insane AIs: brains average %.1f us per simulation step together (budget 300)" % avg)
	check(g.won or g.lost, "the Big 3-Insane match reaches a decision (%s at %.0f s)" % [str(g._end_cause), float(g._t)])
	_count(g)
	g.free()


# ------------------------------------------------------------ 5. the real single-player setup: an (idle) human seat is a rival like any other
func _idle_human_seat() -> void:
	var g = _game("s", 2, 4, {2: "insane", 3: "insane"}, "idle")
	_play(g, 600.0)
	var w := _winner(g)
	check(g.lost and w in [2, 3], "Insane AIs finish an idle human (%s, by %d at %.0f s)" % [str(g._end_cause), w, float(g._t)])
	_count(g)
	g.free()


# ------------------------------------------------------------ 5b. zero-Crypto opening (farms cost Crypto: economy candidate A)
# No circular farm/miner prerequisite: a miner comes before the first new farm and farms do get built from a normal
# 0-Crypto start; every farm the brain orders is covered by Crypto that no job or queued research already claims.
func _farms_of(g, f: int) -> int:
	var n := 0
	for h in g.hosts:
		if int(h.owner) != f: continue
		n += (h.builds as Array).count("bot")
		for job in (h.jobs as Dictionary).values():
			if str(job.kind) == "bot" and str(job.phase) == "build": n += 1
	return n


func _miners_of(g, f: int) -> int:
	var n := 0
	for h in g.hosts:
		if int(h.owner) != f: continue
		n += (h.builds as Array).count("cash")
		for job in (h.jobs as Dictionary).values():
			if str(job.kind) == "cash": n += 1
	return n


func _zero_stock_opening() -> void:
	var rows := []
	for seed in [7, 19, 43]:
		var g = _game("s", 2, seed, {2: "insane", 3: "insane"})
		var start := {}; var first_miner := {}; var first_farm := {}; var overcommit := 0; var negative := false
		for f in _insane(g):
			start[f] = _farms_of(g, f)
			check(float(g.cash[f]) == 0.0, "zero-stock seed %d: faction %d starts with 0 Crypto" % [seed, f])
		while not g.won and not g.lost and g._t < 300.0:
			var before := {}
			for f in _insane(g): before[f] = _farms_of(g, f)
			_step(g)
			for f in _insane(g):
				if g._eliminated.has(f): continue
				if not first_miner.has(f) and _miners_of(g, f) > 0: first_miner[f] = snappedf(g._t, 0.1)
				var now := _farms_of(g, f)
				if now > int(before[f]):   # it ordered a farm this step: the order must have been covered
					if not first_farm.has(f) and now > int(start[f]): first_farm[f] = snappedf(g._t, 0.1)
					var b = _brain(g, f)
					if float(g.cash[f]) - b._jobs_cash_left() - b._research_cash_left() < -0.0001: overcommit += 1
				if float(g.cash[f]) < -0.00001 or float(g.intel[f]) < -0.00001: negative = true
		for f in _insane(g):
			# no circular prerequisite: Crypto income starts from nothing; a farm (when it chooses one) never comes first.
			# Whether it then spends the Crypto on farms or on cards is its strategy, recorded below, not a pass/fail.
			check(first_miner.has(f) and float(first_miner[f]) <= 120.0, "zero-stock seed %d: faction %d starts a miner by 120 s from 0 Crypto (at %s s)" % [seed, f, str(first_miner.get(f, "-"))])
			check(not first_farm.has(f) or float(first_miner.get(f, INF)) <= float(first_farm[f]), "zero-stock seed %d: faction %d has a miner before any new farm" % [seed, f])
		check(overcommit == 0, "zero-stock seed %d: no farm ordered against Crypto already claimed by jobs or research (%d)" % [seed, overcommit])
		check(not negative, "zero-stock seed %d: Insane Intel and Crypto stay nonnegative" % seed)
		rows.append({"seed": seed, "first_miner_s": first_miner, "first_new_farm_s": first_farm, "end_t": snappedf(g._t, 0.1), "cause": str(g._end_cause)})
		_count(g)
		g.free()
	report["zero_stock_opening"] = rows


# ------------------------------------------------------------ 6. fog fairness: scramble what it must not see, decide the same
func _fog_fairness() -> void:
	var rows := []
	for sc in [
		{"size": "m", "enemies": 2, "seed": 6, "levels": {2: "insane", 3: "normal"}, "fac": 2, "at": 100.0, "control": true},
		{"size": "b", "enemies": 3, "seed": 2, "levels": {2: "insane", 3: "insane", 4: "normal"}, "fac": 3, "at": 150.0, "control": false},
		{"size": "s", "enemies": 2, "seed": 3, "levels": {2: "insane", 3: "insane"}, "fac": 2, "at": 70.0, "control": false},
	]:
		var games := [_game(sc.size, sc.enemies, sc.seed, sc.levels), _game(sc.size, sc.enemies, sc.seed, sc.levels)]
		if sc.control: games.append(_game(sc.size, sc.enemies, sc.seed, sc.levels))
		var a = games[0]; var b = games[1]
		while a._t < float(sc.at) and not a.won and not a.lost:
			for g in games: _step(g)
		var F: int = sc.fac
		var label := "%s seed %d, faction %d at %.0f s" % [sc.size, sc.seed, F, float(a._t)]
		check(not a.won and not a.lost and a._brains.has(F), "fog probe %s: the match is still running" % label)
		if a.won or a.lost or not a._brains.has(F):
			for g in games: g.free()
			continue
		check(a._mp_hash() == b._mp_hash() and _brain(a, F).state_hash() == _brain(b, F).state_hash(), "fog probe %s: the two copies are identical before the scramble" % label)
		for g in games: _boost_own(g, F)   # the same fresh means in every copy: the brain has plenty to decide
		var rng := RandomNumberGenerator.new(); rng.seed = 7700 + int(sc.seed)
		var scrambled := _scramble_hidden(b, F, rng)
		if sc.control: _shift_own(games[2], F)
		for g in games: _brain(g, F).record = []
		for k in 180:   # six seconds of its thinking (six full thinks, ~20 micro passes) on frozen worlds
			for g in games:
				g._t += g.SIM_DT
				g._brains[F].tick(g.SIM_DT)
		var ra: Array = _brain(a, F).record
		var rb: Array = _brain(b, F).record
		check(ra.size() >= 3, "fog probe %s: the brain decided things in the window (%d commands)" % [label, ra.size()])
		check(JSON.stringify(ra) == JSON.stringify(rb) and _brain(a, F).state_hash() == _brain(b, F).state_hash(),
			"fog probe %s: %d hidden facts scrambled, the brain's %d commands and its state are unchanged" % [label, scrambled, ra.size()])
		if sc.control:   # the probe can see a difference: change what the brain DOES see and its decisions change
			var rc: Array = _brain(games[2], F).record
			check(JSON.stringify(ra) != JSON.stringify(rc), "fog probe %s (control): changing its OWN Intel and garrisons changes its decisions" % label)
		rows.append({"probe": label, "scrambled": scrambled, "commands": ra.size()})
		for g in games: g.free()
	report["fog_probes"] = rows


func _scramble_hidden(g, F: int, rng: RandomNumberGenerator) -> int:   # everything a human playing F could not know
	var n := 0
	var vis: Dictionary = g._visible_set(F)
	var sight: Dictionary = g._sight_set(F)
	var kinds := ["bot", "intel", "cash", "cred", "lab", ""]
	for f in g.botnets:   # the rivals' resources, hands, research, scan memory, fog memory, private AI state
		if int(f) == F: continue
		g.intel[f] = rng.randf_range(0.0, 400.0); g.cash[f] = rng.randf_range(0.0, 900.0)
		g.creds[f] = rng.randf_range(0.0, 200.0); g.research[f] = rng.randf_range(0.0, 200.0)
		for c in g.CARD_ORDER: g.cards[f][g._card_key(str(c), "linked")] = rng.randi_range(0, 3)
		g.lab[f] = {"queue": ["ddos:linked", "patch:linked"], "progress": 11.0, "paused": false, "stall": ""}
		g.scans[f] = {}; g._seen[f] = {}; g.card_plays[f] = rng.randi_range(0, 9)
		if g._ai.has(f): g._ai[f].ops = {}; g._ai[f].lost = {}
		n += 8
	for i in g.hosts.size():
		var h: Dictionary = g.hosts[i]
		if int(h.owner) == F: continue
		if not vis.has(i):   # out of view: its garrison, buildings, construction, wire and effects are all unknown
			h.bots = float(h.bots) + rng.randf_range(5.0, 25.0)
			var b: Array = h.builds
			for k in b.size(): b[k] = kinds[rng.randi_range(0, kinds.size() - 1)]
			h.jobs = {}
			h.assign = rng.randi_range(0, g.hosts.size() - 1); h.live = rng.randf() < 0.5; h.mode = "scan" if rng.randf() < 0.3 else "attack"
			h.prod_off = rng.randf_range(0.0, 20.0) if rng.randf() < 0.3 else 0.0
			h.route_off = rng.randf_range(0.0, 20.0) if rng.randf() < 0.3 else 0.0
			h.patch_until = g._t + rng.randf_range(0.0, 30.0) if rng.randf() < 0.3 else 0.0
			h.sca_until = g._t + rng.randf_range(0.0, 60.0) if rng.randf() < 0.3 else 0.0
			g._next_depart[i] = g._t + rng.randf()
			n += 10
			continue
		if not g._scanned(F, i):   # in view but never scanned: its bot count is unknown
			h.bots = float(h.bots) + rng.randf_range(5.0, 25.0); n += 1
		if not (sight.has(i) and g._wire_visible(i)):   # a dormant plan, a quiet scan, or a rig seen from afar: the wire is not drawn
			var t := rng.randi_range(0, g.hosts.size() - 1)
			if int(g.hosts[t].owner) != int(h.owner) and t != i: h.assign = t; h.live = false; n += 1
	var far := []   # packets nobody of F could see: queued on hosts out of its sight, some aimed at its own hosts
	var mine := []
	var other := -1
	for i in g.hosts.size():
		if not sight.has(i): far.append(i)
		if int(g.hosts[i].owner) == F: mine.append(i)
	for f in g.botnets:
		if int(f) != F: other = int(f)
	for k in 6:
		if far.is_empty() or mine.is_empty() or other < 0: break
		var src: int = far[rng.randi_range(0, far.size() - 1)]
		var dst: int = mine[rng.randi_range(0, mine.size() - 1)]
		var fl := {"route": [src, dst], "hops": [g._t + 600.0], "depart_t": g._t, "arrive_t": g._t + 601.0, "owner": other, "kind": "card" if k % 2 == 0 else "bot", "amount": 1.0}
		if k % 2 == 0: fl["card"] = "supply:linked" if k == 0 else "zeroday:linked"
		g.flights.append(fl); n += 1
	return n


func _boost_own(g, F: int) -> void:   # the brain's OWN state, changed identically in every copy of a probe
	g.intel[F] = float(g.intel[F]) + 150.0; g.cash[F] = float(g.cash[F]) + 120.0
	g.cards[F]["supply:linked"] = 1; g.cards[F]["patch:linked"] = 1
	for i in g.hosts.size():   # full garrisons and every wire pulled: it re-plans its sieges and guards inside the window
		if int(g.hosts[i].owner) == F:
			g.hosts[i].bots = g._cap_of(i); g.hosts[i].assign = -1; g.hosts[i].live = false; g._next_depart.erase(i)


func _shift_own(g, F: int) -> void:   # the control: what the brain legitimately sees about itself
	g.intel[F] = 0.0
	for i in g.hosts.size():
		if int(g.hosts[i].owner) == F: g.hosts[i].bots = 8.0
