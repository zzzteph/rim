extends SceneTree
## The AI's turn-taking rules, one at a time on a quiet board (0.6.5 review): a project cut off from the main node
## does not hold up the AI's research and credit, and is dropped after a while; a station never takes the host planned
## for Research while another host has room, nor a slot its layout needs; research is due when there is nowhere left to build; a retool gives up a producer the AI really has;
## a retool on credit waits like any other project.
## godot --headless --path . --script tests/ai_rules_test.gd
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


func fresh() -> void:
	if g != null and is_instance_valid(g): g.free()
	g = load("res://scripts/botnet_proto.gd").new()
	g.theme = load("res://assets/ui_theme.tres")
	g._opt_size = Vector2i(8, 6); g._opt_enemies = 1; g._opt_seed = 7; g._opt_shape = "grid"
	root.add_child(g); g.set_process(false); g.ai_enabled = false; g._camp = false
	g._open_menu(false)
	P = g.PLAYER
	R = int(g.botnets[1]) if int(g.botnets[0]) == P else int(g.botnets[0])
	g.bank[R] = {"intel": 0.0, "cash": 0.0, "creds": 0.0, "research": 0.0}


func hub() -> int: return int(g.rig[R])


func free_neighbours(of: int, n: int) -> Array:   # neutral hosts linked to `of`
	var out := []
	for nb in g.hosts[of].links:
		if int(g.hosts[int(nb)].owner) == g.NEUTRAL and out.size() < n: out.append(int(nb))
	return out


func give(i: int, slots: int, kinds: Array) -> void:
	g.hosts[i].type = "pc"; g.hosts[i].slots = slots
	g._capture(i, R); g._set_builds(i, kinds)


func run() -> void:
	stranded_project()
	station_spares_the_research_host()
	research_when_boxed_in()
	retool_a_producer_it_has()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	g.free(); quit(0 if failures.is_empty() else 1)


func stranded_project() -> void:
	fresh()
	var via: int = free_neighbours(hub(), 1)[0]
	var far := -1
	for nb in g.hosts[via].links:
		var c := int(nb)
		if int(g.hosts[c].owner) != g.NEUTRAL or (g.hosts[hub()].links as Array).has(c): continue
		var other := false   # its only road home runs through `via`
		for nb2 in g.hosts[c].links: other = other or (int(nb2) != via and int(g.hosts[int(nb2)].owner) == R)
		if not other: far = c; break
	give(via, 3, []); give(far, 3, [])
	check(g._start_job(far, "bot", 0), "Setup: a project ordered on credit at a host beyond a relay")
	check(g._ai_waiting_build(R), "While its road home is open, the unfunded project waits: research pauses and no second project is owed")
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1   # a rival takes the relay
	check(g._home_route(R, far).is_empty() and not g._ai_waiting_build(R), "Cut off, nothing can bring its bill: it no longer holds up research or credit")
	var mine: Array = g._ai_mine(R)
	g._ai_drop_stranded(R, mine)
	check((g.hosts[far].jobs as Dictionary).has(0), "It is not dropped at once (a DDoS'd relay comes back)")
	g._t += g.AI_STRAND_DROP - 1.0; g._ai_drop_stranded(R, mine)
	check((g.hosts[far].jobs as Dictionary).has(0), "...nor before %d s" % int(g.AI_STRAND_DROP))
	g._t += 2.0; g._ai_drop_stranded(R, mine)
	check(not (g.hosts[far].jobs as Dictionary).has(0), "After %d s cut off the AI cancels it: the slot, the retool turn and the worker count are free" % int(g.AI_STRAND_DROP))
	# a project whose road comes back in time stays
	g._capture(via, R)
	check(g._start_job(far, "intel", 1), "Setup: a second project")
	g._ai_drop_stranded(R, mine)
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1
	g._ai_drop_stranded(R, g._ai_mine(R)); g._t += 30.0
	g._capture(via, R); g._ai_drop_stranded(R, g._ai_mine(R))
	g.hosts[via].owner = g.NEUTRAL; g.hosts[via].gen = int(g.hosts[via].gen) + 1
	g._t += 40.0; g._ai_drop_stranded(R, g._ai_mine(R))
	check((g.hosts[far].jobs as Dictionary).has(1), "A cut that heals restarts the count: two short cuts never add up to a cancel")


func reachable_neutral(n: int) -> Array:   # neutral hosts linked to the AI's network, nearest first
	var out := []
	for i in g._ai_mine(R):
		for nb in g.hosts[i].links:
			if int(g.hosts[int(nb)].owner) == g.NEUTRAL and not out.has(int(nb)) and out.size() < n: out.append(int(nb))
	return out


func fill_all(kinds_by_slots: Dictionary) -> void:   # every host the AI holds, by its slot count
	for i in g._ai_mine(R): g._set_builds(i, kinds_by_slots[int(g.hosts[i].slots)])


func station_spares_the_research_host() -> void:
	fresh()
	var spare := -1   # the AI's own empty 3-slot host besides its main node
	for i in g._ai_mine(R):
		if i != hub() and int(g.hosts[i].slots) == 3: spare = i
	g._set_builds(spare, [])
	g._set_builds(hub(), ["intel", "intel", "cash"])   # the main node is full
	var nbs: Array = reachable_neutral(2)
	give(int(nbs[0]), 2, []); give(int(nbs[1]), 1, ["intel"])
	var mine: Array = g._ai_mine(R)
	check(g._ai_workers_short(R), "Setup: four hosts and no station, the pool is short of workers")
	check(not g._ai_plan(R, spare, mine.size()).has("lab"), "A 3-slot host is never planned to make Research: its Lab would eat the bank's scarce Intel (%s)" % str(g._ai_plan(R, spare, mine.size())))
	g.hosts[spare].slots = 4; g._set_builds(spare, [])   # a 4-slot host: one harvester for the Miner, one for the Lab
	check(g._ai_plan(R, spare, mine.size()) == ["intel", "cash", "intel", "lab"], "Setup: the empty 4-slot host is the one planned to make Research (%s)" % str(g._ai_plan(R, spare, mine.size())))
	var spot: Array = g._ai_station_spot(R, mine, mine.size())
	check(not spot.is_empty() and int(spot[0]) == int(nbs[0]), "The station goes to another host with room, not the Research host (%s, Research host %d)" % [str(spot), spare])
	g._set_builds(int(nbs[0]), ["intel", "cash"])   # now only the Research host has room
	spot = g._ai_station_spot(R, mine, mine.size())
	check(spot == [spare, 2], "With room only there, the station takes the Lab's harvester's place (%s)" % str(spot))
	g._set_builds(spare, ["", "", "bot"])
	check(g._ai_plan(R, spare, mine.size()) == ["intel", "cash", "intel", "lab"], "...and the host still becomes the Research host: harvester, Miner, station, Lab (%s)" % str(g._ai_plan(R, spare, mine.size())))
	g._set_builds(spare, ["", "", "intel"])
	check(g._ai_station_spot(R, mine, mine.size()).is_empty(), "A station never takes the Miner's, the Miner's harvester's or the Lab's place")


func research_when_boxed_in() -> void:
	fresh()
	fill_all({3: ["intel", "bot", "cash"], 5: ["intel", "bot", "cash", "lab", "cred"]})
	g.known[R]["exploit"] = true; g.known[R]["filter"] = true   # two blueprints: more than its 6 buildings / 4
	var next: String = g._ai_next_research(R)
	var price: Dictionary = g.RESEARCH[next]; var want: Dictionary = g._ai_wanted(R)
	g.bank[R] = {}
	for res in g.RES: g.bank[R][res] = float(price.get(res, 0.0)) + float(want.get(res, 0.0)) + 1.0   # the price on top of the next capture card
	check(g._ai_research_due(R), "Every slot it can build on is taken and the bank holds %s's price on top of its next card: research is due" % next)
	g.bank[R]["intel"] = float(price.get("intel", 0.0)) + float(want.get("intel", 0.0)) - 1.0
	check(not g._ai_research_due(R), "...but not with less: boxed-in research only spends what neither building nor its cards need")
	g.bank[R]["intel"] = 100.0
	g._set_builds(hub(), ["intel", "bot", ""])
	check(not g._ai_research_due(R), "A free slot: building takes its turn first (2 blueprints for 5 buildings)")
	fill_all({3: ["intel", "bot", "cash"], 5: ["intel", "bot", "cash", "lab", "cred"]})
	g._ai_research(R)
	check(str((g.research_job.get(R, {}) as Dictionary).get("key", "")) == next, "Boxed in with the spare price in the bank, it starts the next blueprint (%s)" % str(g.research_job.get(R, {}).get("key", "none")))


func retool_a_producer_it_has() -> void:
	fresh()
	fill_all({3: ["intel", "bot", "intel"], 5: ["intel", "bot", "intel", "lab", "intel"]})   # no Miner anywhere
	g.bank[R] = {"intel": 40.0, "cash": 100.0, "creds": 0.0, "research": 0.0}
	var fill_cash: float = 100.0 / g._cap(R, "cash"); var fill_intel: float = 40.0 / g._cap(R, "intel")
	check(fill_cash > fill_intel, "Setup: Crypto piles fuller than Intel (%.2f vs %.2f) and has no producer" % [fill_cash, fill_intel])
	var sites: Array = g._ai_mine(R)
	sites.erase(hub()); sites.push_front(hub())   # as _ai_develop passes them: the main node first
	var old_cut: bool = g._ai_retool_spot(R, sites, "cash").is_empty()
	g._ai_rebalance(R, sites, true)
	var job: Dictionary = (g.hosts[hub()].jobs as Dictionary).get(0, {})
	check(old_cut and str(job.get("kind", "")) == "cred", "The retool gives up an Intel harvester for the dry Credentials, not a Miner it does not have (%s)" % str(g.hosts[hub()].jobs))
	check(str(job.get("phase", "")) == "demolish" and g._ai_waiting_build(R), "A retool on credit waits like any other project from its demolition on: no second project is owed meanwhile")
	check(not g._ai_may_owe(R), "...so the AI may not order another on credit")
