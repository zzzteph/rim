extends RefCounted
## The Insane difficulty: one brain per AI faction, created by botnet_proto.gd on the faction's first tick.
## The game calls tick(dt) every simulated step (1/30 s); the brain keeps its own clocks.
##
## It plays like a strong human under exactly the human's rules:
##  · it SEES what its own map shows and nothing more: its hosts and the hosts one street away, every rig as a
##    landmark, packets and wires only where they cross its sight, foreign bots and buildings only through its
##    own scans, the public leaderboard. Every read of the world sits in the FAIR VIEW section at the bottom.
##  · it ACTS only through game._apply_cmd(fac, cmd) — the commands a human's clicks become (see _cmd).
##  · it PLANS a win: a fast Intel + bot economy, the ring around its own rig first (a rig nobody borders can be
##    neither wired nor carded), a corridor toward the nearest rival rig, Supply chain / 0day research, and a
##    timed strike on that rig the moment its Patch / SCA frames are down; cheap land toward the majority.
##  · it MICRO-MANAGES: sieges sized to finish fast, stalled ones dropped, guards thrown in front of attacks,
##    the strike's bots launched to land right behind the card.

const THINK_EVERY := 1.0     # s between strategic thinks (one think is spread over SLICES consecutive steps)
const MICRO_EVERY := 0.3     # s between micro passes (captures, defence, strike timing)
const SLICES := 4
const MAX_STREAMS := 7       # sources thrown at one target (the last street carries 8 packets/s)
const STALL_SECS := 14.0     # a siege that shows no progress this long is dropped
const CELL := 190.0          # world size of one town cell (= botnet_proto MAP_CELL)

var game                     # the botnet_proto.gd instance (rules + the command door)
var fac := -1                # the faction this brain plays
var record = null            # tests: set to [] and every command is appended here before it is applied

var _next_think := 0.0
var _next_micro := 0.0
var _slice := 0
var _thinks := 0

# ---- the view, rebuilt each think (micro refreshes own + sight) ----
var _own: Array = []         # own hosts, ascending
var _own_set := {}
var _sight := {}             # real sight: own hosts + every host one street away
var _vis := {}               # sight + every rig (landmarks)
var _rigs: Array = []        # every rig host (public: drawn on every map)
var _types: Array = []       # host -> its type's table (static: the pictogram on the map)
var _comp := {}              # own host whose routing works -> component id (bots route only through these)
var _front: Array = []       # foreign hosts in sight = everything this brain can wire into
var _threat := {}            # own host -> visible hostile pressure (packets heading in + visible streams)
var _attackers := {}         # foreign host in sight -> own host it visibly streams into
var _cards_in := {}          # own host -> card key of a visible hostile card packet heading to it
var _my_cards := {}          # target -> [card key, arrive time] of this brain's own card packets in flight
var _my_scans := {}          # target -> true while one of this brain's scan packets flies at it
var _faced := {}             # own host -> true when it borders a rival botnet
var _kb := {}                # per-think cache: host -> [known bots, known regen]
var _board := {}             # per-think cache: botnet -> buildings it holds (the public leaderboard)

# ---- plans ----
var _ops := {}               # target -> {kind, since, prog_t, low, role}
var _avoid := {}             # target -> time until which it is not besieged again
var _goal := -1              # the rival this brain means to eliminate
var _strike := {}            # the rig strike in progress: {rig, card, phase, launch_at, until, srcs}
var _last_strike := {}       # the latest strike (harness / tests: what killed a rig)
var _rival := {}             # rival faction -> what it has been seen doing (see _model_rivals)
var _seen_cards := {}        # identities of hostile card packets already counted
var _lost := {}              # own host taken from this brain -> {by, at} (its own memory, not the engine's)
var _saving := 0.0           # Intel being saved for a build (converters paused, no new sieges meanwhile)
var _income_target := 0.0
var _stats := {"cmds": 0, "built": 0, "research": 0, "cards": 0, "ops": 0, "captures": 0, "strikes": 0, "kills": 0, "defends": 0}


func _init(g, faction: int) -> void:
	game = g; fac = faction
	_next_think = 0.07 * float(fac)              # brains of different factions think on different steps
	_next_micro = _next_think + 0.5 * MICRO_EVERY
	for f in game.rig: _rigs.append(int(game.rig[f]))
	_rigs.sort()
	for h in game.hosts: _types.append(game.NODE_TYPES[str(h.type)])   # a building's type never changes


func tick(_dt: float) -> void:
	var now: float = game._t
	if _slice > 0:                               # a think in progress: one slice per step
		_run_slice(); return
	if now >= _next_think:
		_next_think = now + THINK_EVERY
		_slice = 1; _run_slice(); return
	if now >= _next_micro:
		_next_micro = now + MICRO_EVERY
		_micro()


func _run_slice() -> void:
	match _slice:
		1: _look(); _model_rivals(); _pick_goal()
		2:
			_thinks += 1
			if _thinks % 2 == 1: _economy()      # builds take 10 s: every other think is plenty
			_research()
		3: _offence()
		4: _strike_plan(); _guards()
	_slice = _slice + 1 if _slice < SLICES else 0


# the one door to the match: exactly what a human's click becomes
func _cmd(c: Array) -> void:
	if record != null: (record as Array).append(c.duplicate(true))
	_stats.cmds += 1
	game._apply_cmd(fac, c)


func debug_line() -> String:   # harness timeline: what the brain is doing
	var tally := {}
	for i in _own:
		for b in _obuilds(i):
			if str(b) != "": tally[str(b)] = int(tally.get(str(b), 0)) + 1
	var srcs := 0
	for s in _own:
		if _obots(s) >= 12.0: srcs += 1
	return "own=%d inc=%.1f/%.1f save=%d streams=%d ops=%s srcs=%d build=%s held=%s q=%s goal=%d strike=%s threat=%s" % [_own.size(), _intel_income(), _income_target, int(_saving),
		_live_streams(), str(_ops.keys()), srcs, str(tally), str(_hand()), str(_lab_queue()), _goal, str(_strike.get("phase", "-")), str(_threat.keys())]


func debug_stats() -> Dictionary:
	var out := _stats.duplicate()
	out["goal"] = _goal; out["own"] = _own.size(); out["ops"] = _ops.size(); out["last_strike"] = _last_strike
	return out


func state_hash() -> String:   # tests: the brain's own decisions in one fingerprint
	return str([_ops, _avoid, _goal, _strike, _lost, _saving, _rival, _stats, _next_think, _next_micro, _slice]).md5_text()


# ============================================================ LOOK: the picture this think works from
func _look() -> void:
	_kb = {}; _board = {}
	_refresh_own()
	_comp = {}
	var cid := 0
	for s in _own:                               # connected groups of own hosts whose routing works
		if _comp.has(s) or _ocut(s): continue
		var q := [s]; _comp[s] = cid; var head := 0
		while head < q.size():
			var c: int = q[head]; head += 1
			for o in _links(c):
				if _own_set.has(int(o)) and not _comp.has(int(o)) and not _ocut(int(o)):
					_comp[int(o)] = cid; q.append(int(o))
		cid += 1
	_faced = {}
	for s in _own:
		for o in _links(s):
			var ow := _owner_of(int(o))
			if ow > 0 and ow != fac: _faced[s] = true; break
	_read_threats()


func _refresh_own() -> void:
	var before := _own_set
	_own = []; _own_set = {}; _sight = {}
	var n: int = game.hosts.size()
	for i in n:
		if not _mine(i): continue
		_own.append(i); _own_set[i] = true; _sight[i] = true
		for o in _links(i): _sight[int(o)] = true
	_vis = _sight.duplicate()
	for r in _rigs: _vis[r] = true
	_front = []
	for i in _sight:
		if not _own_set.has(i): _front.append(int(i))
	_front.sort()
	for i in before:                             # remember what was taken (own memory; the owner is in sight)
		if not _own_set.has(i) and not _lost.has(i): _lost[i] = {"by": _owner_of(int(i)), "at": game._t}
	for i in _own_set:
		_lost.erase(i)


# ============================================================ RIVALS: what the board and the map have shown
func _rivals() -> Array:
	var out := []
	for r in game.botnets:
		if int(r) != fac and _alive(int(r)): out.append(int(r))
	return out


func _model_rivals() -> void:   # what each rival is, inferred only from the board, its hosts in view and what flew at us
	var now: float = game._t
	var seen := {}                               # rival -> [labs, miners, harvesters] among its scanned hosts in view
	for i in _front:
		var o := _owner_of(i)
		if o <= 0 or not _scan_fresh(i): continue
		var k := _known_builds(i)
		var row: Array = seen.get(o, [0, 0, 0])
		row[0] += k.count("lab"); row[1] += k.count("cash"); row[2] += k.count("intel")
		seen[o] = row
	for r in _rivals():
		var m: Dictionary = _rival.get(r, {"hist": [], "cards": 0, "last_card": -100.0, "labs": 0})
		m.nodes = _nodes(r)
		(m.hist as Array).append(Vector2(now, float(m.nodes)))
		while (m.hist as Array).size() > 1 and float((m.hist as Array)[0].x) < now - 90.0: (m.hist as Array).pop_front()
		m.growth = (float(m.nodes) - float((m.hist as Array)[0].y)) / maxf(1.0, now - float((m.hist as Array)[0].x)) * 60.0   # hosts per minute
		m.contact = false
		for i in _front:
			if _owner_of(i) == r: m.contact = true; break
		var rg := _rig_of(r)
		m.rig_bots = _known_bots(rg)
		var row: Array = seen.get(r, [0, 0, 0])
		m.labs = maxi(int(m.get("labs", 0)), int(row[0]))  # a lab once seen stays a reason for caution
		# its economy: a captured host starts empty, so every host it holds carries roughly one harvester's worth;
		# cards need labs, and research runs one card at a time (~40 s each) — a seen lab or a seen card means cards
		m.est_income = 1.0 + 0.8 * maxf(0.0, float(m.nodes) - 2.0) + float(row[2])
		m.card_threat = int(m.cards) > 0 or int(m.labs) > 0 or (float(m.nodes) >= 10.0 and now > 150.0)
		_rival[r] = m


func _pick_goal() -> void:   # the rival to eliminate: near, weak, threatening or racing for the majority
	var best := -1; var bs := -INF; var cur_s := -INF
	var need: int = game._control_need()
	for r in _rivals():
		var rg := _rig_of(r)
		if rg < 0 or _owner_of(rg) != r: continue
		var d := INF
		for s in _own: d = minf(d, _pos(s).distance_to(_pos(rg)))
		var m: Dictionary = _rival.get(r, {})
		var sc := -d / CELL - 0.15 * float(m.get("nodes", 0))
		if bool(m.get("contact", false)): sc += 1.5
		if _hold_of(r) > 0.0 or _nodes(r) >= need - 2: sc += 4.0
		if r == _goal: cur_s = sc
		if sc > bs: bs = sc; best = r
	if _goal < 0 or not _alive(_goal) or _owner_of(_rig_of(_goal)) != _goal or bs > cur_s + 1.5: _goal = best


# ============================================================ ECONOMY: what to build, what to research
# Every attack bot costs one bot AND one Intel, and a host sends at most one bot per second, so the economy is
# kept in balance: Intel income ≈ the streams its farm hosts can field + what its converters eat (+ a little to
# build with). Intel harvesters are the cheapest return in the game (10 Intel for 1-2 Intel/s), farms turn every
# host into a source, and a small card core (miners, a credential harvester, a lab) feeds the rig strike.
func _economy() -> void:
	var tally := {"bot": 0, "intel": 0, "cash": 0, "cred": 0, "lab": 0}
	var owed := 0.0
	var owed_cash := 0.0                         # Crypto the accepted jobs still have to pay (a quote is not reserved)
	var farm_hosts := 0                          # hosts with a farm: each can field one stream
	var conv := 0.0                              # Intel/s the converters eat while they run
	for i in _own:
		var b := _obuilds(i); var jobs := _ojobs(i)
		var has_farm := false
		for k in b.size():
			var kind := str(b[k])
			if jobs.has(k):
				var job: Dictionary = jobs[k]
				kind = str(job.kind)
				owed += float((job.get("cost_left", {}) as Dictionary).get("intel", 0.0))
				owed_cash += float((job.get("cost_left", {}) as Dictionary).get("cash", 0.0))
			if kind == "": continue
			tally[kind] += 1
			if kind == "bot": has_farm = true
			elif kind == "cash": conv += float(_ovalue(i)) * _tmult(i, "cash") / 3.0
			elif kind == "cred": conv += 0.5 * _tmult(i, "cred")
		if has_farm: farm_hosts += 1
	var intel := _intel()
	var income := _intel_income()
	var n := _own.size()
	var target := 2.0 + float(farm_hosts) + conv
	_income_target = target
	var plan := []   # ordered wishes: [kind, where] (the site is chosen when the wish comes up)
	if int(tally.intel) < 3: plan.append(["intel", "intel"])
	if income < target: plan.append(["intel", "intel"])
	if float(game._build_cost("bot").get("cash", 0.0)) > 0.0 and int(tally.cash) < 1:
		plan.append(["cash", "cash"])            # farms are paid in Crypto: a miner before the first new farm, whatever the size
	if n >= 4:                                   # the card core: Crypto first (the lab is paid partly in it), then Credentials, then Research
		if int(tally.cash) < 1: plan.append(["cash", "cash"])
		if int(tally.cred) < 1: plan.append(["cred", "cred"])
		if int(tally.lab) < 1: plan.append(["lab", "lab"])
		if int(tally.cash) < 2: plan.append(["cash", "cash"])
	plan.append(["bot", "bot_faced"])
	plan.append(["bot", "bot"])                  # every host a 1 bot/s source: the tempo of the whole game
	if n >= 9:
		if int(tally.lab) < 2: plan.append(["lab", "lab"])
		if int(tally.cash) < 3: plan.append(["cash", "cash"])
	if n >= 14:
		if int(tally.cred) < 2: plan.append(["cred", "cred"])
		if int(tally.cash) < 4: plan.append(["cash", "cash"])
	plan.append(["bot", "bot2"])
	var cap: float = game._intel_cap(fac)
	if income < 1.3 * target and intel < 0.6 * cap: plan.append(["intel", "intel"])
	if intel > 0.85 * cap: plan.append(["bot", "swap"])   # Intel piles up unspent: turn a harvester into a farm
	var started := 0
	_saving = 0.0
	var cash_free := _cash() - owed_cash - _research_cash_left()   # the running card is paid first, so its Crypto is spoken for
	for w in plan:
		var kind := str(w[0])
		var price: Dictionary = game._build_cost(kind)
		var need_cash := float(price.get("cash", 0.0))
		if need_cash > 0.0 and cash_free < need_cash: continue        # a farm or lab waits for its Crypto without blocking the line
		var site := _site(str(w[1]))
		if site.is_empty() and kind == "cash" and float(game._build_cost("bot").get("cash", 0.0)) > 0.0:
			site = _site("cash", true)               # farms need Crypto: a miner at the front beats no miner at all
		if site.is_empty(): continue
		var p := float(price.get("intel", 0.0))
		if intel - 0.5 * owed >= p + 2.0:
			_cmd(["build", int(site[0]), int(site[1]), kind])
			_stats.built += 1; started += 1; owed += p; intel -= p; cash_free -= float(price.get("cash", 0.0))
			if started >= 3: break
		elif p > 10.0:
			_saving = p; break                   # save for it (no new sieges eat the bank meanwhile)
	_converters()


func _site(kind: String, front_ok := false) -> Array:   # [host, slot] where this kind of building does the most good, or []
	var best: Array = []; var bs := -INF
	var rig := _my_rig()
	var rig_comp: int = int(_comp.get(rig, -1))
	var card_kind: bool = kind in ["cash", "cred", "lab"]
	for i in _own:
		var slot := _ofree_slot(i)
		var farms := _ocount_all(i, "bot")
		if kind == "swap":                       # no free slot needed: replace an Intel harvester on a farmless host
			if farms > 0 or _ojobs(i).size() > 0: continue
			var k := _obuilds(i).find("intel")
			if k < 0: continue
			var sw := 1.0 + (1.0 if _faced.has(i) else 0.0) + (0.5 if _frontier(i) else 0.0)
			if sw > bs: bs = sw; best = [i, k]
			continue
		var penalty := 0.0
		if slot < 0:
			if not card_kind: continue
			slot = _obuilds(i).find("intel")     # the card core may take a harvester's slot (it is rebuilt elsewhere)
			if slot < 0 or _ojobs(i).has(slot): continue
			penalty = 1.5
		var sc := 0.0
		match kind:
			"intel":
				sc = _tmult(i, "intel") - (0.6 if _faced.has(i) else 0.0)
			"bot_faced":                         # a host facing a rival with no farm: regen + a 1 bot/s source at the front
				if farms > 0 or not _faced.has(i): continue
				sc = 2.0 + (1.0 if _is_moat(i) else 0.0)
			"bot":
				if farms > 0: continue
				sc = 1.0 + 0.3 * float(_slots(i)) + (0.5 if _frontier(i) else 0.0)
			"bot2":                              # a second farm (cap 60) only on the ring around the rig when a rival presses it
				if farms != 1 or not _faced.has(i) or not (_is_moat(i) or i == rig): continue
				sc = 1.0
			"cred":
				if _faced.has(i): continue
				sc = _tmult(i, "cred")
			"lab":
				if _faced.has(i): continue
				sc = _tmult(i, "research")
			"cash":                              # needs a road home: Crypto travels to the rig as packets
				if (_faced.has(i) and not front_ok) or (i != rig and int(_comp.get(i, -2)) != rig_comp): continue
				sc = float(_ovalue(i)) * _tmult(i, "cash") - (1.0 if _faced.has(i) else 0.0)
		sc -= penalty
		if sc > bs: bs = sc; best = [i, slot]
	return best


func _converters() -> void:   # converters eat Intel: they run while the bank can spare it and their output is wanted
	var want_cash: float = 60.0 + _queue_cost("cash") + _queue_cost("research") + _jobs_cash_left()   # + Crypto that farm / lab jobs still owe
	var cash := _cash()
	var intel := _intel()
	var research_full: bool = _pool("research") >= _head_need("research") + 5.0   # labs would only turn Crypto the card needs into spare Research
	var creds_full: bool = _pool("creds") >= _head_need("creds") + 40.0
	for i in _own:
		var b := _obuilds(i)
		for k in b.size():
			var kind := str(b[k])
			if not kind in ["cash", "cred", "lab"] or _ojobs(i).has(k): continue
			var stop := _opaused(i, k)
			if kind == "lab": stop = research_full
			elif intel < 10.0: stop = true                       # streams and builds come first
			elif kind == "cred": stop = creds_full or (stop and intel < 25.0)
			elif cash > want_cash + 40.0: stop = true            # a miner: only while Crypto is wanted (hysteresis between)
			elif cash < want_cash and intel >= 25.0: stop = false
			if stop != _opaused(i, k): _cmd(["produce", i, k])


func _head_need(res: String) -> float:   # what the card being researched still needs of a resource
	var q := _lab_queue()
	if q.is_empty(): return 0.0
	var key := str(q[0])
	var items := _lab_items()
	var done := float(items[0].progress) / float(game.CARDS[key.split(":")[0]].time) if not items.is_empty() else 0.0
	return float((game.CARDS[key.split(":")[0]].cost as Dictionary).get(res, 0.0)) * (1.0 - done)


func _research_cash_left() -> float:   # Crypto the card being researched still has to take (research pays first; later cards wait their turn)
	return _head_need("cash")


func _jobs_cash_left() -> float:   # Crypto this brain's own construction jobs still owe
	var total := 0.0
	for i in _own:
		for job in _ojobs(i).values(): total += float((job.get("cost_left", {}) as Dictionary).get("cash", 0.0))
	return total


func _queue_cost(res: String) -> float:   # what the queued research still needs of a resource
	var total := 0.0
	for key in _lab_queue(): total += float((game.CARDS[str(key).split(":")[0]].cost as Dictionary).get(res, 0.0))
	return total


func _research() -> void:
	var queue := _lab_queue()
	if queue.size() >= 2: return
	var exposed := _rig_exposed()
	var wary := false                            # a rival that can play cards is at our border
	for r in _rival:
		if _alive(int(r)) and bool(_rival[r].get("contact", false)) and bool(_rival[r].get("card_threat", false)): wary = true
	var wish := []
	if exposed and _held("sca:linked") + _held("patch:linked") < 1: wish.append("sca:linked")
	if _held("supply:linked") < 1: wish.append("supply:linked")
	if _goal >= 0 and _held("zeroday:linked") < 1: wish.append("zeroday:linked")
	if (exposed or wary) and _held("patch:linked") < 1: wish.append("patch:linked")
	if _held("supply:linked") < 2: wish.append("supply:linked")
	for key in wish:
		if queue.has(key): continue
		_cmd(["research", key]); _stats.research += 1
		return


# ============================================================ OFFENCE: sieges sized to end fast
func _offence() -> void:
	_kb = {}
	var now: float = game._t
	var live := {}                               # target -> own live streams into it
	for s in _own:
		var a := _oassign(s)
		if a >= 0 and _olive(s) and not _own_set.has(a): live[a] = int(live.get(a, 0)) + 1
	_live = live
	for t in _ops.keys():
		var op: Dictionary = _ops[t]
		if _own_set.has(t): _ops.erase(t); _stats.captures += 1; continue
		if not live.has(t):
			_ops.erase(t); continue              # nothing flows any more: a scan landed, the route broke, or a halt
		var kb := _known_bots(t)
		if kb < float(op.low) - 0.5: op.low = kb; op.prog_t = now
		elif now - float(op.prog_t) > STALL_SECS and not (_strike.get("rig", -1) == t):
			_cmd(["halt", t]); _avoid[t] = now + 40.0; _ops.erase(t)
	for t in live:
		if not _ops.has(t): _ops[t] = {"kind": "attack", "since": now, "prog_t": now, "low": _known_bots(t), "role": "adopted"}
	if _intel() < 6.0: return
	var pool := {}                               # component -> its free sources, most bots first
	for s in _free_sources():
		var c := int(_comp.get(s, -1))
		if c < 0: continue
		if not pool.has(c): pool[c] = []
		pool[c].append(s)
	if pool.is_empty(): return
	var cands := _candidates(pool, _intel() - _saving)
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var streams := 0
	for t in live: streams += int(live[t])
	var room := _intel_income() * (0.7 if _saving > 0.0 else 1.0) + maxf(0.0, _intel() - _saving) / 15.0 - float(streams)
	var started := 0
	for cd in cands:
		if started >= 3: break
		var t: int = cd[1]; var kind: String = cd[2]; var n: int = cd[3]
		if kind == "attack" and not bool(cd[5]):  # Intel pays for every bot: no more streams than it can fund
			n = mini(n, int(floor(room)))
			if n < mini(2, int(cd[3])) and not _ops.has(t): continue
			if n < 1: continue
		var avail := []
		for c in cd[4]: avail.append_array(pool[c])
		if avail.size() < mini(n, 1 if kind == "scan" else 2): continue
		var srcs := _nearest(avail, t, n)
		if kind == "attack": room -= float(srcs.size())
		if _ops.has(t):                          # reinforce a running siege: the new wires join the live flow
			_cmd(["wire", srcs, t])
		else:
			_cmd(["wire", srcs, t]); _cmd(["launch", t, kind])
			_ops[t] = {"kind": kind, "since": now, "prog_t": now, "low": float(_estimate(t)[0]), "role": "expand"}
			_stats.ops += 1
		for s in srcs: (pool[int(_comp.get(s, -1))] as Array).erase(s)
		started += 1


var _live := {}         # target -> own live streams into it (this think)
var _fuel := {}         # free source -> bots it can still send (above the 6-bot garrison every AI host keeps)
var _fuel_regen := {}   # free source -> bots/s it regenerates
func _free_sources() -> Array:   # own hosts with bots to spare and no attack to run, most bots first
	var out := []
	_fuel = {}; _fuel_regen = {}
	var rig := _my_rig()
	var reserved: Array = _strike.get("srcs", [])
	for s in _own:
		if _ocut(s) or _pressed(s) or reserved.has(s): continue
		var b := _obots(s)
		if b < 12.0: continue
		var a := _oassign(s)
		if a >= 0 and not _own_set.has(a) and _olive(s): continue         # streaming at a target already
		if a >= 0 and _pressed(a): continue                               # guarding a host that is losing ground
		if s == rig and b < _rig_floor(): continue
		out.append([-b, s]); _fuel[s] = maxf(0.0, b - 7.0); _fuel_regen[s] = _oregen(s)
	out.sort()
	var ids := []
	for e in out: ids.append(e[1])
	return ids


func _rig_floor() -> float:   # bots the rig keeps home: plenty while a rival can reach it
	return 40.0 if _rig_exposed() else 14.0


# every siege worth starting: [score, target, "attack"|"scan", streams, components that can reach it]
func _candidates(pool: Dictionary, budget: float) -> Array:
	var now: float = game._t
	var need: int = game._control_need()
	var rig := _my_rig()
	var income := _intel_income()
	var intel := _intel()
	var goal_rig := _rig_of(_goal) if _goal >= 0 else -1
	var goal_pos: Vector2 = _pos(goal_rig) if goal_rig >= 0 else Vector2.ZERO
	var goal_open: bool = goal_rig >= 0 and not _borders_mine(goal_rig)
	var near_hold: bool = _holding() or _own.size() >= need - 3
	var my_best_d := INF
	if goal_rig >= 0:
		for s in _own: my_best_d = minf(my_best_d, _pos(s).distance_to(goal_pos))
	var pre := {}                                # component -> [fuel prefix sums, regen prefix sums] (its sources sorted by bots)
	for c in pool:
		var fp := [0.0]; var rp := [0.0]
		for s in pool[c]: fp.append(float(fp.back()) + float(_fuel[s])); rp.append(float(rp.back()) + float(_fuel_regen[s]))
		pre[c] = [fp, rp]
	var out := []
	var armed: int = _strike.get("rig", -1)
	for t in _front:
		if t == armed or float(_avoid.get(t, -1.0)) > now: continue
		var o := _owner_of(t)
		if o == fac: continue
		var comps := []; var big := -1; var avail := 0
		for nb in _links(t):
			var c := int(_comp.get(int(nb), -1))
			if c >= 0 and pool.has(c) and not comps.has(c):
				comps.append(c); avail += (pool[c] as Array).size()
				if big < 0 or (pool[c] as Array).size() > (pool[big] as Array).size(): big = c
		if avail <= 0: continue
		var running: bool = _ops.has(t)
		if running and str(_ops[t].kind) == "scan": continue
		var is_rig: bool = _is_rig(t) and o > 0
		var scanned := _scan_fresh(t)
		if is_rig and not scanned:               # a rival rig: learn it quietly first (its count stays live after)
			if not running and not _scan_pending(t): out.append([5.0, t, "scan", 1, comps, true])
			continue
		if o > 0 and not scanned and not running:   # a rival host: a quiet scan first, no alarm
			if not _scan_pending(t): out.append([(6.0 + float(_slots(t))) / 10.0, t, "scan", 1, comps, true])
			continue
		var est := _estimate(t)
		var kb: float = est[0]
		var regen: float = float(est[1]) + (0.6 if o > 0 else 0.0)   # a botnet host may also be fed by guards
		var have := int(_live.get(t, 0))
		var n := mini(avail, MAX_STREAMS - have)
		if n <= 0: continue
		var push := float(n + have)
		if push - regen < 0.4: continue
		var secs := kb / (push - regen) + 2.5
		var k := mini(n, (pool[big] as Array).size())
		var fuel := float(pre[big][0][k]) + float(pre[big][1][k]) * secs + float(n - k) * 10.0
		if fuel < kb + regen * secs * 0.8: continue                    # these sources would run dry first
		var cost := kb + regen * secs
		var urgent: bool = _links(t).has(rig) or _attackers.has(t) or (o > 0 and (_hold_of(o) > 0.0 or is_rig))
		if cost > (intel if urgent else budget) + income * secs * 0.7 + 4.0: continue
		var benefit := 3.0 + float(_slots(t)) + 2.0 * maxf(0.0, _tmult(t, "intel") - 1.0) + float(_value_guess(t)) - 1.0
		if _is_hub(t): benefit += 4.0
		if _junction(t): benefit += 1.5
		if _links(t).has(rig): benefit += 40.0 if o > 0 else 25.0       # the ring around the rig: nobody can strike it
		if o > 0:
			benefit += 6.0
			if o == _goal: benefit += 5.0
			if _hold_of(o) > 0.0 or _nodes(o) > need - 2: benefit += 25.0   # any capture resets its hold
		if _attackers.has(t): benefit += 10.0
		if _lost.has(t): benefit += 6.0
		if goal_rig >= 0:
			if goal_open and _links(t).has(goal_rig): benefit += 18.0
			benefit += 4.0 * clampf((my_best_d - _pos(t).distance_to(goal_pos)) / CELL, -1.5, 1.5)
		if is_rig:                               # a scanned rival rig thin enough to take by force: elimination
			if secs > 25.0: continue
			benefit += 200.0
		if near_hold: benefit += 4.0            # the majority is close or its clock runs: every cheap host is a buffer
		var score := benefit / (secs + 8.0)
		if running: score *= 0.8
		out.append([score, t, "attack", n, comps, urgent])
	return out


func _nearest(srcs: Array, t: int, n: int) -> Array:   # the n sources with the fewest hops to t (one BFS through own hosts)
	var dist := {}; var q := []; var head := 0
	for nb in _links(t):
		if _comp.has(int(nb)): dist[int(nb)] = 1; q.append(int(nb))
	while head < q.size():
		var c: int = q[head]; head += 1
		for o in _links(c):
			if _comp.has(int(o)) and not dist.has(int(o)): dist[int(o)] = int(dist[c]) + 1; q.append(int(o))
	var arr := []
	for s in srcs: arr.append([int(dist.get(s, 99)), s])
	arr.sort()
	var out := []
	for k in mini(n, arr.size()): out.append(arr[k][1])
	return out


func _wires_into(t: int) -> int:
	var n := 0
	for s in _own:
		if _oassign(s) == t and _olive(s): n += 1
	return n


func _live_streams() -> int:
	var n := 0
	for s in _own:
		var a := _oassign(s)
		if a >= 0 and _olive(s) and not _own_set.has(a): n += 1
	return n


# ============================================================ GUARDS: idle producers feed the hosts that face rivals
func _guards() -> void:
	var targets := []
	var rig := _my_rig()
	var quiet := _faced.is_empty() and _threat.is_empty()
	for h in _own:
		var front_feed: bool = quiet and _frontier(h) and _obots(h) < _ocap(h) - 1.0
		if not (_faced.has(h) or _pressed(h) or (h == rig and _rig_exposed()) or front_feed): continue
		var need := 1.0 - _obots(h) / maxf(1.0, _ocap(h))
		if h == rig: need += 1.0
		if _is_moat(h): need += 0.5
		if _pressed(h): need += 1.0
		targets.append([need, h])
	if targets.is_empty(): return
	targets.sort(); targets.reverse()
	var count := {}
	for s in _own:
		var a := _oassign(s)
		if a >= 0 and _own_set.has(a): count[a] = int(count.get(a, 0)) + 1
	var moved := 0
	var reserved: Array = _strike.get("srcs", [])
	for s in _own:
		if moved >= 3: break
		if _ocut(s) or _faced.has(s) or _pressed(s) or reserved.has(s): continue
		if s == rig and (_rig_exposed() or _obots(s) < 45.0): continue
		var a := _oassign(s)
		if a >= 0 and not _own_set.has(a): continue          # attacking
		if a >= 0 and (_faced.has(a) or (quiet and _obots(a) < _ocap(a) - 1.0)): continue   # already feeding a host that wants it
		if _oregen(s) <= 0.0 and _obots(s) < 20.0: continue
		for tg in targets:
			var h: int = tg[1]
			if h == s or int(count.get(h, 0)) >= 2 or int(_comp.get(h, -1)) != int(_comp.get(s, -2)): continue
			_cmd(["wire", [s], h]); count[h] = int(count.get(h, 0)) + 1; moved += 1
			break


# ============================================================ THE STRIKE: a card on a rival rig, bots right behind it
func _strike_plan() -> void:
	if not _strike.is_empty(): return
	var order := _rivals()
	if _goal >= 0 and order.has(_goal): order.erase(_goal); order.push_front(_goal)
	for r in order:
		var R := _rig_of(r)
		if R < 0 or _owner_of(R) != r or not _borders_mine(R): continue
		if _my_cards.has(R): continue
		var patch := _fx_left(R, "patch"); var sca := _fx_left(R, "sca")
		var srcs := _strike_sources(R)
		if _held("zeroday:linked") > 0 and patch <= 0.0 and not srcs.is_empty():
			if not _linked(R): _cmd(["wire", [srcs[0]], R])   # a dormant wire is the link a 0day needs
			if game._can_play(fac, "zeroday:linked", R) == "":
				_cmd(["card", "zeroday:linked", R]); _stats.cards += 1; _stats.strikes += 1
				var at := _card_arrival(R)
				_strike = {"rig": R, "card": "zeroday", "phase": "flying", "until": at + 1.0, "srcs": [srcs[0]]}
				_last_strike = {"rig": R, "card": "zeroday", "at": game._t, "lands": at}
				return
		if _held("supply:linked") > 0 and patch <= 0.0 and sca <= 0.0 and srcs.size() >= 2:
			if game._can_play(fac, "supply:linked", R) != "": continue
			var running := _wires_into(R) > 0       # a siege already pours in: the wipe lands into the stream
			_cmd(["wire", srcs, R])               # (else dormant until the card is about to land: no early alarm)
			_cmd(["card", "supply:linked", R]); _stats.cards += 1; _stats.strikes += 1
			var at := _card_arrival(R)
			var near := INF
			var hops := _hops_to(R)
			for s in srcs: near = minf(near, _travel(int(hops.get(s, 3))))
			_strike = {"rig": R, "card": "supply", "phase": "firing" if running else "armed", "launch_at": at - near - 0.35, "until": at + 14.0, "srcs": srcs}
			_last_strike = {"rig": R, "card": "supply", "at": game._t, "lands": at}
			return


func _strike_sources(R: int) -> Array:   # up to 5 sources that can reach the rival rig, nearest first
	var srcs := []
	for nb in _links(R):
		var c := int(_comp.get(int(nb), -1))
		if c < 0: continue
		for s in _own:
			if int(_comp.get(s, -2)) == c and not srcs.has(s) and _obots(s) >= 10.0 and not _pressed(s): srcs.append(s)
	return _nearest(srcs, R, 5)


func _hops_to(t: int) -> Dictionary:
	var dist := {}; var q := []; var head := 0
	for nb in _links(t):
		if _comp.has(int(nb)): dist[int(nb)] = 1; q.append(int(nb))
	while head < q.size():
		var c: int = q[head]; head += 1
		for o in _links(c):
			if _comp.has(int(o)) and not dist.has(int(o)): dist[int(o)] = int(dist[c]) + 1; q.append(int(o))
	return dist


func _travel(hops: int) -> float:
	return float(hops) * game.LINK_TIME + float(maxi(0, hops - 1)) * game.NODE_ROUTE_DELAY


func _strike_micro() -> void:
	if _strike.is_empty(): return
	var now: float = game._t
	var R: int = _strike.rig
	if _mine(R):
		_stats.kills += 1; _strike = {}; return
	if now > float(_strike.until) or _owner_of(R) <= 0:
		if _wires_into(R) > 0: _cmd(["halt", R])
		_strike = {}; return
	if str(_strike.phase) == "armed" and now >= float(_strike.launch_at):
		_cmd(["launch", R, "attack"]); _strike.phase = "firing"
		_ops[R] = {"kind": "attack", "since": now, "prog_t": now, "low": _known_bots(R), "role": "strike"}


# ============================================================ MICRO: captures, defence, card shields, strike timing
func _micro() -> void:
	_refresh_own()
	_read_threats()
	_strike_micro()
	_retake()
	_defend()
	_shield()


func _retake() -> void:   # a capture leaves a host near 0 bots: one of ours just taken back by someone is the cheapest target there is
	var now: float = game._t
	var R: int = _strike.get("rig", -1)
	var done := {}
	for s in _own:
		var a := _oassign(s)
		if a < 0 or a == R or done.has(a) or _own_set.has(a) or _olive(s): continue
		if not _lost.has(a) or now - float(_lost[a].at) > 4.0 or not _sight.has(a): continue
		done[a] = true
		_cmd(["launch", a, "attack"])
		_ops[a] = {"kind": "attack", "since": now, "prog_t": now, "low": _known_bots(a), "role": "retake"}


func _defend() -> void:   # throw guards in front of a visible attack
	var rig := _my_rig()
	var busy := {}
	for h in _threat:
		if not _pressed(h): continue             # a garrison that holds its own needs no help (guards would only overflow it)
		var crit: bool = h == rig or _is_moat(h)
		var help := 0
		for s in _own:
			if _oassign(s) == h: help += 1
		var want := (4 if h == rig else (2 if crit else 1)) - help
		if want <= 0: continue
		var cands := []
		for s in _own:
			if s == h or busy.has(s) or _pressed(s) or _ocut(s) or _obots(s) < 10.0: continue
			var a := _oassign(s)
			if a >= 0 and not _own_set.has(a) and not crit: continue        # a running siege goes on unless the rig burns
			if a >= 0 and _pressed(a): continue
			if int(_comp.get(s, -1)) != int(_comp.get(h, -2)): continue
			cands.append(s)
		if cands.is_empty(): continue
		var pick := _nearest(cands, h, want)
		_cmd(["wire", pick, h]); _stats.defends += 1
		for s in pick: busy[s] = true


func _pressed(h: int) -> bool:   # under visible attack AND losing ground (a full garrison that out-regenerates it needs no help)
	if not _threat.has(h): return false
	var b := _obots(h); var cap := _ocap(h)
	if h == _my_rig(): return b < 0.9 * cap
	return b < 0.75 * cap or b < 3.0 * float(_threat[h]) + 8.0


func _shield() -> void:   # a hostile Supply chain or 0day seen flying at the rig (or its ring): Patch / SCA it first
	var rig := _my_rig()
	for h in _cards_in:
		if h != rig and not _is_moat(h): continue
		var card := str(_cards_in[h]).split(":")[0]
		if not card in ["supply", "zeroday"]: continue
		if _my_cards.has(h): continue
		var key := ""
		if _fx_left(h, "patch") <= 1.0 and _held("patch:linked") > 0: key = "patch:linked"
		elif card == "supply" and _fx_left(h, "sca") <= 1.0 and _fx_left(h, "patch") <= 1.0 and _held("sca:linked") > 0: key = "sca:linked"
		if key != "" and game._can_play(fac, key, h) == "":
			_cmd(["card", key, h]); _stats.cards += 1
			return
	if _rig_exposed():                           # a rival borders the rig: keep it shielded while cards are in hand
		if _fx_left(rig, "patch") <= 0.5 and _fx_left(rig, "sca") <= 0.5 and not _my_cards.has(rig):
			for key in ["sca:linked", "patch:linked"]:
				if _held(key) > 0 and game._can_play(fac, key, rig) == "":
					_cmd(["card", key, rig]); _stats.cards += 1
					return


# ============================================================ small helpers over own state and static map facts
func _my_rig() -> int: return int(game.rig.get(fac, -1))
func _is_moat(i: int) -> bool: return _links(_my_rig()).has(i)
func _frontier(i: int) -> bool:
	for o in _links(i):
		if not _own_set.has(int(o)): return true
	return false
func _borders_mine(t: int) -> bool: return _sight.has(t) and not _own_set.has(t)   # one street from our hosts = in real sight
func _rig_exposed() -> bool:   # a rival botnet borders the rig or its ring
	var rig := _my_rig()
	if _faced.has(rig): return true
	for o in _links(rig):
		if _faced.has(int(o)) or (not _own_set.has(int(o)) and _owner_of(int(o)) > 0): return true
	return false
func _holding() -> bool: return _hold_of(fac) > 0.0
func _linked(t: int) -> bool:
	for s in _own:
		if _oassign(s) == t: return true
	return false
func _intel_income() -> float:   # own Intel/s: the rig's trickle plus every working harvester
	var r := 0.0
	var rig := _my_rig()
	if _mine(rig) and _fx_left(rig, "off") <= 0.0: r += float(game.RIG_INTEL)
	for i in _own:
		if _fx_left(i, "off") > 0.0 or _fx_left(i, "phish") > 0.0: continue
		r += float(_ocount(i, "intel")) * float(game.INTEL_PER_BUILD) * _tmult(i, "intel")
	return r
func _card_arrival(t: int) -> float:
	_read_my_cards()
	return float((_my_cards.get(t, ["", game._t + 3.0]) as Array)[1])


# static map facts (streets, types, positions, rig / hub / junction marks) are drawn on every map
func _links(i: int) -> Array: return game.hosts[i].links
func _pos(i: int) -> Vector2: return game.hosts[i].pos
func _slots(i: int) -> int: return int(game.hosts[i].slots)
func _tmult(i: int, what: String) -> float: return float((_types[i] as Dictionary).get(what, 1.0))
func _is_rig(i: int) -> bool: return bool(game.hosts[i].rig)
func _is_hub(i: int) -> bool: return bool(game.hosts[i].hub)
func _junction(i: int) -> bool: return bool(game.hosts[i].get("junction", false))
func _value_guess(i: int) -> int:   # the district a host sits in, read off the map (downtown 3 … rim 1)
	if _mine(i): return _ovalue(i)
	var centre := Vector2(float(game._cols - 1) * 0.5, float(game._rows - 1) * 0.5)
	var g: Vector2i = game.hosts[i].grid
	var d := Vector2(g).distance_to(centre) / maxf(0.001, centre.length())
	return 3 if d < 0.38 else (2 if d < 0.72 else 1)


# ============================================================ FAIR VIEW
# The ONLY functions that read the match's live state. The rule is the human's fog of war:
#  · own hosts: everything about them (your own panels show it all) — the _o* accessors check ownership live
#  · a foreign host in view (real sight, or a rig: a landmark on every map): its owner and the frames drawn on it
#    (Patch, SCA, OFF, CUT, PHISHED); its bots and buildings only through this faction's own scan records — a
#    scanned host shows its live count while its contents are unchanged, exactly like the player's badge
#  · out of view: the faction's fog memory (last-known owner) and its own scan records, nothing live
#  · packets only where the game's sight rule shows them; foreign wires only while drawn and their source in sight
#  · the public board: buildings per botnet, hold timers, eliminations, rig positions; own resources and cards
func _mine(i: int) -> bool: return int(game.hosts[i].owner) == fac   # knowing which hosts are yours is never hidden
func _obots(i: int) -> float: return float(game.hosts[i].bots) if _mine(i) else 0.0
func _obuilds(i: int) -> Array: return game.hosts[i].builds if _mine(i) else []
func _ojobs(i: int) -> Dictionary: return game.hosts[i].jobs if _mine(i) else {}
func _oassign(i: int) -> int: return int(game.hosts[i].assign) if _mine(i) else -1
func _olive(i: int) -> bool: return _mine(i) and bool(game.hosts[i].live)
func _ocut(i: int) -> bool: return _mine(i) and float(game.hosts[i].get("route_off", 0.0)) > 0.0
func _ocap(i: int) -> float: return game._cap_of(i) if _mine(i) else 0.0
func _oregen(i: int) -> float: return game._regen(i) if _mine(i) else 0.0
func _ovalue(i: int) -> int: return int(game.hosts[i].value) if _mine(i) else 1
func _ofree_slot(i: int) -> int: return game._free_slot(i) if _mine(i) else -1
func _ocount(i: int, kind: String) -> int: return game._count(i, kind) if _mine(i) else 0
func _ocount_all(i: int, kind: String) -> int: return (game.hosts[i].builds as Array).count(kind) if _mine(i) else 0
func _opaused(i: int, slot: int) -> bool: return _mine(i) and game._producer_paused(i, slot)
func _intel() -> float: return float(game.intel[fac])
func _cash() -> float: return float(game.cash[fac])
func _held(key: String) -> int: return int((game.cards[fac] as Dictionary).get(key, 0))
func _hand() -> Dictionary: return game.cards[fac]
func _pool(res: String) -> float: return float(game.creds[fac]) if res == "creds" else float(game.research[fac])
func _lab_queue() -> Array: return game.lab[fac].queue
func _lab_items() -> Array: return game.lab[fac].get("items", [])
func _alive(r: int) -> bool: return not game._eliminated.has(r) and _nodes(r) > 0                  # the leaderboard
func _nodes(r: int) -> int:                                                                         # the leaderboard
	if not _board.has(r): _board[r] = game._faction_nodes(r)
	return int(_board[r])
func _hold_of(r: int) -> float: return float(game._hold.get(r, 0.0))                               # the leaderboard
func _rig_of(r: int) -> int: return int(game.rig.get(r, -1))                                       # a landmark


func _owner_of(i: int) -> int:   # in view: the colour on the map; else the last-known owner; -1 if never seen
	if i < 0: return -1
	if _vis.has(i): return int(game.hosts[i].owner)
	var ls: Dictionary = game._last_seen(fac, i)
	return int(ls.owner) if not ls.is_empty() else -1


func _fx_left(i: int, what: String) -> float:   # seconds left on a frame drawn on a host in view
	if i < 0 or not (_vis.has(i) or _mine(i)): return 0.0
	var h: Dictionary = game.hosts[i]
	var now: float = game._t
	match what:
		"patch": return maxf(0.0, float(h.get("patch_until", 0.0)) - now)
		"sca": return maxf(0.0, float(h.get("sca_until", 0.0)) - now)
		"off": return float(h.get("prod_off", 0.0))
		"cut": return float(h.get("route_off", 0.0))
		"phish": return maxf(0.0, float(h.get("steal_until", -100.0)) - now) if game._stolen(i) else 0.0
	return 0.0


func _scan_fresh(i: int) -> bool:   # a host in view whose scan still matches its contents (the badge shows a number)
	return _mine(i) or (_vis.has(i) and game._scanned(fac, i))


func _scan_pending(i: int) -> bool:   # one of this brain's own scan packets is on its way
	return _my_scans.has(i)


func _record(i: int) -> Dictionary: return (game.scans[fac] as Dictionary).get(i, {})   # this faction's own scan memory


func _known_builds(i: int) -> Array:
	if _mine(i) or _scan_fresh(i): return game._built_kinds(i)
	var rec := _record(i)
	if rec.has("key") and bool(rec.get("done", false)) and str(rec.key) != "":
		var out := []
		for k in str(rec.key).split(","):
			if str(k) != "": out.append(str(k))
		return out
	if _is_rig(i) or _is_hub(i): return ["bot", "bot"]   # the generator's rule, public
	return ["bot"]


func _known_bots(i: int) -> float:
	if i < 0: return 0.0
	if _scan_fresh(i): return float(game.hosts[i].bots)   # own, or a fresh scan of a host in view: the live badge
	var rec := _record(i)
	if rec.has("bots"):                          # an old look, regrown at what it was seen to regenerate
		var age: float = game._t - float(rec.get("at", game._t))
		var farms := maxi(1, _known_builds(i).count("bot"))
		return minf(float(rec.get("cap", 30.0)), float(rec.bots) + float(farms) * _tmult(i, "bot") * age)
	return _prior_bots(i)


func _prior_bots(i: int) -> float:   # what the map alone suggests: the hub's rule, a garrisoned botnet host, a district's security
	if _is_hub(i): return 30.0
	var o := _owner_of(i)
	if o > 0 and o != fac: return 60.0 if _is_rig(i) else 18.0
	return clampf(4.5 + 5.0 * float(_value_guess(i)) + float(game.NODE_TYPES[str(game.hosts[i].type)].sec), 4.0, 28.0)


func _estimate(i: int) -> Array:   # [known bots, known regen], cached for this think
	if not _kb.has(i): _kb[i] = [_known_bots(i), _known_regen(i)]
	return _kb[i]


func _known_regen(i: int) -> float:   # bots/s it is believed to regenerate (the OFF frame is public)
	if _fx_left(i, "off") > 0.0: return 0.0
	return float(_known_builds(i).count("bot")) * _tmult(i, "bot")


func _read_my_cards() -> void:   # this brain's own card and scan packets in flight (its own, always seen)
	_my_cards = {}; _my_scans = {}
	for f in game.flights:
		if int(f.owner) != fac: continue
		if str(f.kind) == "card": _my_cards[int((f.route as Array).back())] = [str(f.card), float(f.arrive_t)]
		elif str(f.kind) == "scan": _my_scans[int((f.route as Array).back())] = true


func _read_threats() -> void:   # one pass over the packets this faction can see, one over the wires drawn in its sight
	_threat = {}; _attackers = {}; _cards_in = {}
	_my_cards = {}; _my_scans = {}
	var now: float = game._t
	var lt: float = game.LINK_TIME
	for f in game.flights:
		var kind: String = f.kind
		if int(f.owner) == fac:                  # this brain's own packets: always seen
			if kind == "card": _my_cards[int((f.route as Array).back())] = [str(f.card), float(f.arrive_t)]
			elif kind == "scan": _my_scans[int((f.route as Array).back())] = true
			continue
		if kind == "scan" or kind == "cash": continue   # a quiet scan is never seen; Crypto is no threat
		var rt: Array = f.route; var hops: Array = f.hops
		var a: int = rt.back(); var b: int = a    # the street it is on right now (= game._flight_segment)
		for k in hops.size():
			var h: float = hops[k]
			if now < h: a = rt[k]; b = a; break
			if now < h + lt: a = rt[k]; b = rt[k + 1]; break
		if not (_sight.has(a) or _sight.has(b)): continue          # = game._flight_visible(fac, f)
		var to: int = rt.back()                  # a seen packet heading into one of our hosts: the alarm on that host
		if not _own_set.has(to): continue
		if kind == "card":
			_cards_in[to] = str(f.get("card", ""))
			var key := "%d:%s:%.3f" % [int(f.owner), str(f.get("card", "")), float(f.depart_t)]
			if not _seen_cards.has(key):
				_seen_cards[key] = true
				var m: Dictionary = _rival.get(int(f.owner), {"hist": [], "cards": 0})
				m.cards = int(m.get("cards", 0)) + 1; m.last_card = now; _rival[int(f.owner)] = m
		else: _threat[to] = float(_threat.get(to, 0.0)) + 1.0
	for i in _front:                             # a drawn foreign stream whose source we see
		if not game._wire_visible(i): continue
		var a := int(game.hosts[i].assign)
		if _own_set.has(a): _attackers[i] = a; _threat[a] = float(_threat.get(a, 0.0)) + 2.0
	for h in _own:                               # a card that just hit one of ours
		if now - float(game.hosts[h].get("hit_t", -100.0)) < 3.0 and not _threat.has(h): _threat[h] = 1.0
