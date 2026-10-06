extends Node2D
## RIM — the game. Two connected map scales (SimCity/Constructor city; Stellaris hierarchy):
##   • GLOBAL city map: a continuous architectural city. Each building is a "system" with links to
##     other buildings. Scanning a building reveals those links; you expand along discovered links
##     from buildings where you hold a foothold.
##   • LOCAL building map: a schematic component network inside one building (IoT/Web/File/DB/PC).
##     You scan components to discover neighbours, capture them with resource-funded attack CARDS
##     (vulnerabilities / credentials / phishing), then install PROGRAMS (the old economy catalog)
##     into captured component slots. Programs produce resources that flow as real packets to C2.
## Risk: a component's installed workload can exceed its capacity; sustained overload degrades its
## access integrity until the component is lost and must be re-captured.
## Shared foundation: Settings autoload (accessibility), atomic validated saves, undo.

const SAVE_PATH := "user://rim_netrun.json"
const TICK := 0.1

# ---------- resources ----------
const RES_KEYS := ["compute", "data", "crypto", "tools", "credits", "research"]
const RES_NAMES := {"compute": "Cycles", "data": "Intel", "crypto": "Crypto",
	"tools": "Tools", "credits": "Cash", "research": "Research"}

# ---------- component catalogue (brief §3) ----------
# slots = install capacity; cap = supported workload (overload if active load > cap); affin = the
# resource this component boosts to 100% (others run at 50%); traits gate which cards apply.
const COMP := {
	"iot":  {"name": "IoT Device",  "slots": 2, "cap": 2.0, "affin": "compute", "traits": ["login"],
			 "pass": 2, "vuln": 3, "aware": 0},
	"web":  {"name": "Web Server",  "slots": 4, "cap": 4.0, "affin": "compute", "traits": ["software", "login"],
			 "pass": 5, "vuln": 4, "aware": 0},
	"file": {"name": "File Server", "slots": 4, "cap": 4.0, "affin": "data",    "traits": ["software", "login"],
			 "pass": 4, "vuln": 5, "aware": 0},
	"db":   {"name": "Database",    "slots": 6, "cap": 3.0, "affin": "data",    "traits": ["software", "login"],
			 "pass": 6, "vuln": 5, "aware": 0},
	"pc":   {"name": "PC",          "slots": 6, "cap": 4.0, "affin": "none",    "traits": ["human", "login", "software"],
			 "pass": 4, "vuln": 4, "aware": 4},
}
const COMP_ORDER := ["iot", "web", "file", "db", "pc"]
const INTEGRITY_MAX := 100.0
const DEGRADE_RATE := 7.0    # integrity/sec lost per unit of load over capacity (MVP default)
const RECOVER_RATE := 4.0    # integrity/sec regained when not overloaded (MVP default)
const RECAPTURE_INTEGRITY := 60.0

# ---------- installable programs (reused economy catalogue; brief §7) ----------
# load = workload contribution toward the component's capacity. producers emit `out`; converters
# consume `in` (+ optional fuel) from banked resources and emit `out`. A producer gets the
# component's affinity factor (100% match / 50% otherwise).
const PROGRAMS := {
	"mirai":   {"name": "Mirai Botnet",       "kind": "producer", "out": "compute", "rate": 1.2, "load": 1.0, "cost": {"compute": 6.0}},
	"package": {"name": "Poisoned Package",    "kind": "producer", "out": "compute", "rate": 2.2, "load": 2.0, "cost": {"compute": 22.0, "data": 6.0}},
	"botfarm": {"name": "Cloud Cryptojacker",  "kind": "producer", "out": "compute", "rate": 2.6, "load": 2.0, "cost": {"compute": 26.0}},
	"phish":   {"name": "Phishing Kit",        "kind": "producer", "out": "data",    "rate": 1.0, "load": 1.0, "cost": {"compute": 8.0}},
	"scraper": {"name": "Scraper Botnet",      "kind": "producer", "out": "data",    "rate": 1.3, "load": 1.0, "cost": {"compute": 12.0}},
	"salami":  {"name": "Magecart Skimmer",    "kind": "producer", "out": "crypto",  "rate": 1.1, "load": 1.5, "cost": {"compute": 22.0, "data": 8.0}},
	"fence":   {"name": "Darknet Market",      "kind": "conv", "in": "data",   "out": "credits",  "rate": 2.0, "load": 1.0, "cost": {"compute": 14.0}},
	"mixer":   {"name": "Crypto Mixer",        "kind": "conv", "in": "crypto", "out": "credits",  "rate": 1.6, "load": 1.0, "cost": {"compute": 20.0}},
	"forge":   {"name": "Exploit Forge",       "kind": "conv", "in": "data", "fuel": "compute", "fuelcost": 2.0, "out": "tools",    "rate": 0.5, "load": 2.0, "cost": {"compute": 24.0, "data": 8.0}},
	"lab":     {"name": "Research Lab",        "kind": "conv", "in": "data", "fuel": "compute", "fuelcost": 2.0, "out": "research", "rate": 0.5, "load": 2.0, "cost": {"compute": 20.0, "data": 8.0}},
}
const PROGRAM_ORDER := ["mirai", "package", "botfarm", "phish", "scraper", "salami", "fence", "mixer", "forge", "lab"]

# ---------- attack cards (brief §6): three branches; basics are free, tier-2 gated by research ----------
# A card applies only if the target has `req` trait; it succeeds (deterministic) when its power >=
# the target's relevant defence (`def`). cost is paid on a committed successful capture.
const CARDS := {
	"cred1":  {"name": "Weak Credentials",  "branch": "credentials", "power": 3, "req": "login",    "def": "pass",  "cost": {"compute": 4.0},               "research": ""},
	"cred2":  {"name": "Brute Force",        "branch": "credentials", "power": 6, "req": "login",    "def": "pass",  "cost": {"compute": 10.0},              "research": "cred2"},
	"vuln1":  {"name": "Known Flaw",         "branch": "vuln",        "power": 3, "req": "software",  "def": "vuln",  "cost": {"compute": 4.0, "tools": 1.0}, "research": ""},
	"vuln2":  {"name": "Service Exploit",    "branch": "vuln",        "power": 6, "req": "software",  "def": "vuln",  "cost": {"compute": 8.0, "tools": 2.0}, "research": "vuln2"},
	"phish1": {"name": "Generic Phish",      "branch": "phishing",    "power": 3, "req": "human",     "def": "aware", "cost": {"data": 4.0},                  "research": ""},
	"phish2": {"name": "Targeted Phish",     "branch": "phishing",    "power": 6, "req": "human",     "def": "aware", "cost": {"data": 8.0, "compute": 4.0},  "research": "phish2"},
}
const CARD_ORDER := ["cred1", "cred2", "vuln1", "vuln2", "phish1", "phish2"]
# research unlocks (spend the Research resource; brief §6): one tier-2 card per branch
const RESEARCH := {
	"cred2":  {"name": "Brute Force (credentials)", "cost": 8.0,  "card": "cred2",  "desc": "Stronger password attack (power 6) — beats hardened logins."},
	"vuln2":  {"name": "Service Exploit (vuln)",    "cost": 10.0, "card": "vuln2",  "desc": "Deeper software exploit (power 6) — beats resistant services."},
	"phish2": {"name": "Targeted Phish (phishing)", "cost": 10.0, "card": "phish2", "desc": "Tailored lure (power 6) — beats aware users."},
}
const RESEARCH_ORDER := ["cred2", "vuln2", "phish2"]

const SCAN_COST := 2.0        # reveal a building's links / a component's neighbours
const ORG_NAMES := ["Axiom Logistics", "Meridian Health", "Kestrel Finance"]
const ORG_COL := [Color(0.35, 0.85, 1.0), Color(1.0, 0.55, 0.85), Color(1.0, 0.78, 0.3)]
const PANEL_W := 346.0
const BLOCK := Vector2(118.0, 104.0)
const BDEPTH := 20.0

# city-size presets (brief §1: 10×10 … 100×100). The grid unit is a building LOT; a preset sets how
# many district blocks and thus buildings are generated.
const SIZES := {
	"small":  {"dcols": 2, "drows": 2, "bcols": 3, "brows": 3, "label": "10×10"},
	"medium": {"dcols": 3, "drows": 2, "bcols": 4, "brows": 3, "label": "24×24"},
	"large":  {"dcols": 3, "drows": 3, "bcols": 4, "brows": 4, "label": "40×40"},
}

var seed := 0
var rng := RandomNumberGenerator.new()
var city_size := "small"
# global city buildings: id -> {id,pos,org,type,scanned(bool),neighbors[],parent(building route),comps[](gids),entry_gid}
var hosts := {}
var decor := []
# local components (flat, stable gids): gid -> {id,bid,type,lpos,state,neighbors[],entry,pass,vuln,aware,
#   traits[],slots,cap,affin,programs[{key,acc,enabled}],integrity,bootstrap}
var comps := {}
var c2_id := 1
var next_bid := 1
var next_gid := 1
var resources := {"compute": 45.0, "data": 12.0, "crypto": 0.0, "tools": 2.0, "credits": 0.0, "research": 0.0}
var researched := {}          # research key -> true
var packets := []             # {res, route:[building ids], idx, dist}
var won := false
var _first_banked := false

# view state
var view := "city"            # "city" | "local"
var entered := -1             # building id whose local map is open
var sel_building := -1
var sel_comp := -1
var _city_cam := Vector2.ZERO
var _city_zoom := Vector2.ONE

var message := "You hold one captured entry component (your C2). Scan a connected building, enter it, and hack your way in."
var camera: Camera2D
var _accum := 0.0
var _time := 0.0
var _panning := false
var _lmb_down := false
var _lmb_moved := false
var _last_cam := Vector2(INF, INF)
var _last_zoomv := Vector2.ZERO
var _dirty := true

# UI
var ui_layer: CanvasLayer
var res_label: Label
var progress_label: Label
var status_label: Label
var info_title: Label
var info_body: Label
var act_scroll: ScrollContainer
var act_box: VBoxContainer
var _act_sig := []


func _ready() -> void:
	seed = Session.seed if Session.seed != 0 else randi()
	rng.seed = seed
	city_size = Session.city_size
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	var loaded := false
	if Session.start_mode == "netrun_load" and FileAccess.file_exists(SAVE_PATH):
		loaded = load_game()
	if not loaded:
		_generate()
	Session.start_mode = "netrun"
	_frame_city()
	_build_ui()


# ============================================================ GENERATION
func _connect_b(a: int, b: int) -> void:
	if a == b or not hosts.has(a) or not hosts.has(b):
		return
	if not hosts[a].neighbors.has(b): hosts[a].neighbors.append(b)
	if not hosts[b].neighbors.has(a): hosts[b].neighbors.append(a)


func _generate() -> void:
	hosts = {}
	decor = []
	comps = {}
	next_bid = 1
	next_gid = 1
	var cfg: Dictionary = SIZES.get(city_size, SIZES.small)
	var bcols: int = int(cfg.bcols)
	var brows: int = int(cfg.brows)
	# lay districts (organizations) spread apart so their plates never overlap
	var span := Vector2(float(bcols + 2) * BLOCK.x, float(brows + 2) * BLOCK.y)
	var districts := []
	var n_orgs: int = min(3, int(cfg.dcols) * int(cfg.drows))
	n_orgs = max(2, n_orgs)
	var ox := 0
	for o in n_orgs:
		var gx := o % 2
		var gy := o / 2
		districts.append({"org": o, "origin": Vector2(gx * (span.x + 160.0) - 400.0, gy * (span.y + 160.0) - 200.0)})
	var org_hosts := []
	for o in n_orgs: org_hosts.append([])
	for d in districts:
		var org: int = int(d.org)
		var gi := 0
		for ry in range(-1, brows + 1):
			for cx in range(-1, bcols + 1):
				var inner: bool = cx >= 0 and cx < bcols and ry >= 0 and ry < brows
				var jit := Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0))
				var pos: Vector2 = Vector2(d.origin) + Vector2(cx, ry) * BLOCK + jit
				var is_host: bool = inner and (gi == 0 or rng.randf() < 0.6)
				if inner: gi += 1
				if is_host:
					var t: String = "gateway" if gi == 1 else ["tower", "block", "complex"][rng.randi() % 3]
					hosts[next_bid] = {"id": next_bid, "pos": pos, "org": org, "type": t,
						"scanned": false, "neighbors": [], "parent": -1, "comps": [], "entry_gid": -1}
					org_hosts[org].append(next_bid)
					_gen_components(next_bid, org)
					next_bid += 1
				else:
					decor.append({"pos": pos, "w": rng.randf_range(42.0, 70.0), "height": rng.randf_range(26.0, 96.0), "org": org})
	# wire each district (chain + nearest extras), then bridge gateways org-to-org
	for org in org_hosts.size():
		var hs: Array = org_hosts[org]
		hs.sort_custom(func(a, b): return (hosts[a].pos.x + hosts[a].pos.y) < (hosts[b].pos.x + hosts[b].pos.y))
		for i in range(hs.size() - 1):
			_connect_b(hs[i], hs[i + 1])
		for a in hs:
			for b in _nearest_b(a, hs, 2):
				_connect_b(a, b)
	var gws := []
	for org in org_hosts.size():
		if not org_hosts[org].is_empty(): gws.append(org_hosts[org][0])
	for i in range(gws.size() - 1):
		_connect_b(gws[i], gws[i + 1])
	# foothold: the C2 building's entry component starts captured, and the building's links are known
	c2_id = gws[0] if not gws.is_empty() else org_hosts[0][0]
	hosts[c2_id].type = "gateway"
	hosts[c2_id].scanned = true
	var e: int = int(hosts[c2_id].entry_gid)
	comps[e].state = "captured"
	comps[e].integrity = INTEGRITY_MAX
	# recoverable opening (brief §6/§9): guarantee one easy IoT next to the C2 entry, beatable by a
	# basic (free) card, so the player can always capture a first target and bootstrap toward a
	# Research Lab without needing a card the lab itself unlocks.
	for nb in comps[e].neighbors:
		var c = comps[nb]
		c.type = "iot"; c["pass"] = 1; c.vuln = 2; c.aware = 0
		c.traits = (COMP.iot.traits as Array).duplicate()
		c.slots = int(COMP.iot.slots); c.cap = float(COMP.iot.cap); c.affin = str(COMP.iot.affin)
		break


func _nearest_b(a: int, pool: Array, k: int) -> Array:
	var cand := []
	for b in pool:
		if b != a: cand.append(b)
	cand.sort_custom(func(x, y): return hosts[a].pos.distance_to(hosts[x].pos) < hosts[a].pos.distance_to(hosts[y].pos))
	return cand.slice(0, k)


# Each building owns a generated component network: one entry component, 3–5 total, progressively
# discovered. Defences scale with the organization (deeper orgs need researched cards).
func _gen_components(bid: int, org: int) -> void:
	var n := 3 + rng.randi() % 3        # 3..5 components
	var ids := []
	var def_bonus := org                # org0 beatable by basic cards; org1/2 need tier-2
	var lpos_ring := [Vector2(0, 0), Vector2(-150, -40), Vector2(150, -40), Vector2(-90, 130), Vector2(110, 130), Vector2(0, -170)]
	for i in n:
		var ct: String = COMP_ORDER[rng.randi() % COMP_ORDER.size()]
		var base: Dictionary = COMP[ct]
		var gid := next_gid
		next_gid += 1
		comps[gid] = {
			"id": gid, "bid": bid, "type": ct,
			"lpos": lpos_ring[i] + Vector2(rng.randf_range(-18, 18), rng.randf_range(-14, 14)),
			"state": "unknown", "neighbors": [], "entry": i == 0,
			"pass": int(base["pass"]) + def_bonus + (rng.randi() % 2),
			"vuln": int(base.vuln) + def_bonus + (rng.randi() % 2),
			"aware": (int(base.aware) + def_bonus + (rng.randi() % 2)) if int(base.aware) > 0 else 0,
			"traits": (base.traits as Array).duplicate(),
			"slots": int(base.slots), "cap": float(base.cap), "affin": str(base.affin),
			"programs": [], "integrity": INTEGRITY_MAX,
		}
		ids.append(gid)
		hosts[bid].comps.append(gid)
	hosts[bid].entry_gid = ids[0]
	# connect components: chain + one extra, so the local graph is connected with a little choice
	for i in range(ids.size() - 1):
		_connect_c(ids[i], ids[i + 1])
	if ids.size() >= 3:
		_connect_c(ids[0], ids[ids.size() - 1])


func _connect_c(a: int, b: int) -> void:
	if a == b: return
	if not comps[a].neighbors.has(b): comps[a].neighbors.append(b)
	if not comps[b].neighbors.has(a): comps[b].neighbors.append(a)


# ============================================================ VIEW SWITCHING
func _frame_city() -> void:
	var city := _city_bounds()
	var vp := Vector2(get_viewport().get_visible_rect().size)
	var uw: float = maxf(vp.x - PANEL_W, 1.0)
	var fit: float = minf(uw / maxf(city.size.x + 200.0, 1.0), vp.y / maxf(city.size.y + 200.0, 1.0))
	var z: float = clampf(fit, 0.25, 1.1)
	camera.zoom = Vector2.ONE * z
	camera.position = city.get_center() - Vector2(PANEL_W * 0.5 / z, 0.0)


func _enter_building(bid: int) -> void:
	if not hosts.has(bid):
		return
	if not _breachable(bid):
		message = "That building isn't reachable yet — expand from a building where you hold a foothold."
		return
	# reveal the entry component on first entry
	var e: int = int(hosts[bid].entry_gid)
	if comps[e].state == "unknown":
		comps[e].state = "scanned"
	_city_cam = camera.position
	_city_zoom = camera.zoom
	view = "local"
	entered = bid
	sel_comp = e
	# frame the local graph (guarded: get_viewport() is null outside the scene tree, e.g. in tests)
	if get_viewport() != null:
		var lb := _local_bounds(bid)
		var vp := Vector2(get_viewport().get_visible_rect().size)
		var uw: float = maxf(vp.x - PANEL_W, 1.0)
		var fit: float = minf(uw / maxf(lb.size.x + 240.0, 1.0), vp.y / maxf(lb.size.y + 200.0, 1.0))
		var z: float = clampf(fit, 0.5, 1.6)
		camera.zoom = Vector2.ONE * z
		camera.position = lb.get_center() - Vector2(PANEL_W * 0.5 / z, 0.0)
	_dirty = true
	message = "Inside %s. Scan the entry component to discover neighbours, then hack with a card." % _bname(bid)


func _exit_to_city() -> void:
	view = "city"
	sel_building = entered
	entered = -1
	sel_comp = -1
	camera.position = _city_cam
	camera.zoom = _city_zoom
	_dirty = true


# ============================================================ RULES
func _has_foothold(bid: int) -> bool:
	for gid in hosts[bid].comps:
		if comps[gid].state == "captured":
			return true
	return false


func _building_full(bid: int) -> bool:
	for gid in hosts[bid].comps:
		if comps[gid].state != "captured":
			return false
	return hosts[bid].comps.size() > 0


# A building is reachable if it holds a foothold, or it is a KNOWN neighbour (via a scanned foothold
# building) of one that does. Discovery of inter-building links comes from scanning a building.
func _breachable(bid: int) -> bool:
	if _has_foothold(bid):
		return true
	for nb in hosts[bid].neighbors:
		if hosts.has(nb) and _has_foothold(nb) and hosts[nb].scanned:
			return true
	return false


func _building_scannable(bid: int) -> bool:
	return hosts.has(bid) and not hosts[bid].scanned and _has_foothold(bid)


# building route to C2 (chain of footholds). parent pointers set when a foothold is established.
func _building_routed(bid: int) -> bool:
	var cur := bid
	var guard := 0
	while cur != -1 and guard < 9999:
		if cur == c2_id:
			return true
		if not hosts.has(cur) or not _has_foothold(cur):
			return false
		cur = int(hosts[cur].parent)
		guard += 1
	return false


func _bchain(bid: int) -> Array:
	var out := []
	var cur := bid
	var guard := 0
	while cur != -1 and guard < 9999:
		out.append(cur)
		if cur == c2_id:
			break
		cur = int(hosts[cur].parent)
		guard += 1
	return out


func _routed_building_neighbor(bid: int) -> int:
	for nb in hosts[bid].neighbors:
		if hosts.has(nb) and _has_foothold(nb) and (nb == c2_id or _building_routed(nb)):
			return nb
	for nb in hosts[bid].neighbors:
		if hosts.has(nb) and _has_foothold(nb):
			return nb
	return -1


# local component access frontier: entry is attackable; otherwise a scanned component connected to a
# captured one in the same building.
func _comp_scannable(gid: int) -> bool:
	# you can scan any component you can see (revealed or captured) that still has unknown neighbours
	if not comps.has(gid) or comps[gid].state == "unknown":
		return false
	for nb in comps[gid].neighbors:
		if comps.has(nb) and comps[nb].state == "unknown":
			return true
	return false


func _comp_attack_frontier(gid: int) -> bool:
	if not comps.has(gid) or comps[gid].state == "captured":
		return false
	if comps[gid].state == "unknown":
		return false
	if comps[gid].entry:
		return true
	for nb in comps[gid].neighbors:
		if comps.has(nb) and comps[nb].state == "captured":
			return true
	return false


func _card_applicable(gid: int, card_key: String) -> bool:
	var card: Dictionary = CARDS[card_key]
	return comps[gid].traits.has(str(card.req))


func _card_unlocked(card_key: String) -> bool:
	var r: String = str(CARDS[card_key].research)
	return r == "" or researched.has(r)


func _card_defense(gid: int, card_key: String) -> int:
	return int(comps[gid].get(str(CARDS[card_key].def), 0))


func _can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if float(resources.get(k, 0.0)) < float(cost[k]):
			return false
	return true


# full outcome preview for a card against a component (deterministic): why/whether it captures.
func _card_outcome(gid: int, card_key: String) -> Dictionary:
	var card: Dictionary = CARDS[card_key]
	if not _card_unlocked(card_key):
		return {"ok": false, "reason": "needs research"}
	if not _comp_attack_frontier(gid):
		return {"ok": false, "reason": "no access route"}
	if not _card_applicable(gid, card_key):
		return {"ok": false, "reason": "needs %s target" % str(card.req)}
	var dv := _card_defense(gid, card_key)
	if int(card.power) < dv:
		return {"ok": false, "reason": "power %d < defence %d" % [int(card.power), dv]}
	if not _can_afford(card.cost):
		return {"ok": false, "reason": "can't afford"}
	return {"ok": true, "reason": "will capture (power %d ≥ %d)" % [int(card.power), dv]}


func _comp_load(gid: int) -> float:
	var l := 0.0
	for p in comps[gid].programs:
		if bool(p.get("enabled", true)):
			l += float(PROGRAMS[str(p.key)].load)
	return l


func _comp_overloaded(gid: int) -> bool:
	return _comp_load(gid) > float(comps[gid].cap) + 0.001


func _free_slots(gid: int) -> int:
	return int(comps[gid].slots) - comps[gid].programs.size()


# ============================================================ ACTIONS
func scan_building(bid: int) -> void:
	if not _building_scannable(bid):
		message = "Scan a building where you already hold a foothold to map its links."
		return
	if resources.compute < SCAN_COST:
		message = "Scan needs %d Cycles." % int(SCAN_COST)
		return
	resources.compute -= SCAN_COST
	hosts[bid].scanned = true
	_dirty = true
	message = "Mapped %s — its links to %d connected building(s) are now visible." % [_bname(bid), hosts[bid].neighbors.size()]


func scan_component(gid: int) -> void:
	if not _comp_scannable(gid):
		message = "Select a revealed component to scan its neighbours."
		return
	if resources.compute < SCAN_COST:
		message = "Scan needs %d Cycles." % int(SCAN_COST)
		return
	resources.compute -= SCAN_COST
	_dirty = true
	var revealed := 0
	for nb in comps[gid].neighbors:
		if comps.has(nb) and comps[nb].state == "unknown":
			comps[nb].state = "scanned"
			revealed += 1
	message = "Scanned %s — revealed %d connected component(s): type, defences and slots now readable." % [_cname(gid), revealed]


func attack_component(gid: int, card_key: String) -> void:
	var out := _card_outcome(gid, card_key)
	if not out.ok:
		message = "%s can't capture this — %s." % [CARDS[card_key].name, out.reason]
		return
	_pay(CARDS[card_key].cost)
	_dirty = true
	var bid: int = int(comps[gid].bid)
	var was_foothold := _has_foothold(bid)
	comps[gid].state = "captured"
	comps[gid].integrity = INTEGRITY_MAX
	# establishing the first foothold in a building sets its route toward C2
	if not was_foothold:
		hosts[bid].parent = _routed_building_neighbor(bid) if bid != c2_id else -1
	message = "%s captured %s with %s. %s" % [CARDS[card_key].name, _cname(gid), CARDS[card_key].branch,
		("Foothold established — scan the building to map onward links." if not was_foothold else "Install programs, or push deeper.")]
	_check_win()


func research_card(key: String) -> void:
	if researched.has(key):
		return
	var r: Dictionary = RESEARCH[key]
	if resources.research < float(r.cost):
		message = "%s needs %d Research — build a Research Lab program and let it run." % [r.name, int(r.cost)]
		return
	resources.research -= float(r.cost)
	researched[key] = true
	_dirty = true
	message = "Researched %s — the %s card is now available for attacks." % [r.name, CARDS[str(r.card)].name]


func install_program(gid: int, key: String) -> void:
	if not comps.has(gid) or comps[gid].state != "captured":
		message = "Capture the component first."
		return
	if _free_slots(gid) <= 0:
		message = "%s has no free slots (%d/%d used)." % [_cname(gid), comps[gid].programs.size(), int(comps[gid].slots)]
		return
	var prog: Dictionary = PROGRAMS[key]
	if not _can_afford(prog.cost):
		message = "%s costs %s." % [prog.name, _cost_str(prog.cost)]
		return
	_pay(prog.cost)
	comps[gid].programs.append({"key": key, "acc": 0.0, "enabled": true})
	_dirty = true
	var warn := ""
	if _comp_overloaded(gid):
		warn = "  ⚠ OVERLOADED (load %.1f > cap %.1f) — access integrity will degrade until you disable/remove load." % [_comp_load(gid), float(comps[gid].cap)]
	message = "Installed %s in %s (%d/%d slots).%s" % [prog.name, _cname(gid), comps[gid].programs.size(), int(comps[gid].slots), warn]


func toggle_program(gid: int, idx: int) -> void:
	if comps.has(gid) and idx >= 0 and idx < comps[gid].programs.size():
		comps[gid].programs[idx].enabled = not bool(comps[gid].programs[idx].get("enabled", true))
		_dirty = true
		message = "%s %s." % [PROGRAMS[str(comps[gid].programs[idx].key)].name, "enabled" if comps[gid].programs[idx].enabled else "disabled"]


func remove_program(gid: int, idx: int) -> void:
	if comps.has(gid) and idx >= 0 and idx < comps[gid].programs.size():
		var k: String = str(comps[gid].programs[idx].key)
		comps[gid].programs.remove_at(idx)
		_dirty = true
		message = "Removed %s." % PROGRAMS[k].name


func _pay(cost: Dictionary) -> void:
	for k in cost:
		resources[k] = float(resources.get(k, 0.0)) - float(cost[k])


func _check_win() -> void:
	for gid in comps:
		if comps[gid].state != "captured":
			return
	won = true
	message = "Total control — every component of every building is captured."


func _bname(bid: int) -> String:
	return "C2" if bid == c2_id else "%s-%02d" % [ORG_NAMES[int(hosts[bid].org)].substr(0, 3).to_upper(), bid]


func _cname(gid: int) -> String:
	return "%s#%d" % [COMP[str(comps[gid].type)].name, gid]


func _cost_str(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), RES_NAMES.get(k, k)])
	return ", ".join(parts)


# ============================================================ ECONOMY / SIM
func _spawn(res: String, route: Array) -> void:
	if route.size() < 2:
		resources[res] = float(resources.get(res, 0.0)) + 1.0
		if not _first_banked:
			_first_banked = true
			message = "First %s delivered to C2 — the economy is live." % RES_NAMES[res]
		return
	packets.append({"res": res, "route": route, "idx": 0, "dist": 0.0})


func _sim(dt: float) -> void:
	for gid in comps:
		var c = comps[gid]
		if c.state != "captured":
			continue
		var bid: int = int(c.bid)
		var routed: bool = _building_routed(bid)
		# overload degrades access integrity; otherwise it recovers
		var over: float = _comp_load(gid) - float(c.cap)
		if over > 0.001:
			c.integrity = maxf(0.0, float(c.integrity) - DEGRADE_RATE * over * dt)
			if float(c.integrity) <= 0.0:
				_lose_component(gid)
				continue
		else:
			c.integrity = minf(INTEGRITY_MAX, float(c.integrity) + RECOVER_RATE * dt)
		if not routed:
			continue
		var chain := _bchain(bid)
		for p in c.programs:
			if not bool(p.get("enabled", true)):
				continue
			var spec: Dictionary = PROGRAMS[str(p.key)]
			if str(spec.kind) == "producer":
				var factor := 1.0 if str(c.affin) == str(spec.out) else 0.5
				p.acc = float(p.acc) + float(spec.rate) * factor * dt
				while float(p.acc) >= 1.0:
					p.acc = float(p.acc) - 1.0
					_spawn(str(spec.out), chain)
			else:
				# converter: consume banked input (+fuel) and emit output to C2
				p.acc = float(p.acc) + float(spec.rate) * dt
				while float(p.acc) >= 1.0:
					var infl: String = str(spec["in"])
					var has_fuel: bool = not spec.has("fuel") or float(resources.get(str(spec.fuel), 0.0)) >= float(spec.fuelcost)
					if float(resources.get(infl, 0.0)) >= 1.0 and has_fuel:
						resources[infl] = float(resources[infl]) - 1.0
						if spec.has("fuel"):
							resources[str(spec.fuel)] = float(resources[str(spec.fuel)]) - float(spec.fuelcost)
						_spawn(str(spec.out), chain)
						p.acc = float(p.acc) - 1.0
					else:
						p.acc = minf(float(p.acc), 1.0)
						break
	_move_packets(dt)
	_emergency_reserve()


func _lose_component(gid: int) -> void:
	var c = comps[gid]
	var bid: int = int(c.bid)
	c.state = "scanned"            # ownership lost; it stays discovered, programs kept but dormant
	c.integrity = 0.0
	for p in c.programs:
		p.enabled = false          # dormant while access is lost (brief §5 default)
	# if this was the building's last foothold, the building loses its route/foothold
	if not _has_foothold(bid):
		hosts[bid].parent = -1
	message = "⚠ Lost access to %s — it overloaded and degraded. Re-hack it to restore control." % _cname(gid)


func _emergency_reserve() -> void:
	# bounded bootstrap: if you can't afford the cheapest attack/scan and have no Cycles income,
	# trickle a little Cycles so a run is never permanently stranded (brief §9).
	if resources.compute < 4.0 and not _has_cycle_income():
		resources.compute = minf(6.0, resources.compute + 2.0 * TICK)


func _has_cycle_income() -> bool:
	for gid in comps:
		if comps[gid].state == "captured" and _building_routed(int(comps[gid].bid)):
			for p in comps[gid].programs:
				if bool(p.get("enabled", true)) and str(PROGRAMS[str(p.key)].get("out", "")) == "compute":
					return true
	return false


func _move_packets(dt: float) -> void:
	var speed := 170.0
	for i in range(packets.size() - 1, -1, -1):
		var p = packets[i]
		var route: Array = p.route
		if int(p.idx) >= route.size() - 1 or not hosts.has(route[int(p.idx)]) or not _has_foothold(route[int(p.idx)]):
			packets.remove_at(i)
			continue
		var a: Vector2 = hosts[route[int(p.idx)]].pos
		var b: Vector2 = hosts[route[int(p.idx) + 1]].pos
		var seg := maxf(a.distance_to(b), 1.0)
		p.dist = float(p.dist) + speed * dt
		var arrived := false
		while float(p.dist) >= seg and int(p.idx) < route.size() - 1:
			p.dist = float(p.dist) - seg
			p.idx = int(p.idx) + 1
			if int(p.idx) >= route.size() - 1:
				_spawn(str(p.res), [])   # bank at C2
				arrived = true
				break
			a = hosts[route[int(p.idx)]].pos
			b = hosts[route[int(p.idx) + 1]].pos
			seg = maxf(a.distance_to(b), 1.0)
		if arrived:
			packets.remove_at(i)


func _process(dt: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.y += 1
	if pan != Vector2.ZERO:
		camera.position += pan.normalized() * 460.0 * dt / camera.zoom.x
	if not won:
		_time += dt
		_accum = minf(_accum + dt, 2.0)
		var ticks := 0
		while _accum >= TICK and ticks < 6:
			_accum -= TICK
			_sim(TICK)
			ticks += 1
	_update_ui()
	if _dirty or not packets.is_empty() or camera.position != _last_cam or camera.zoom != _last_zoomv:
		_dirty = false
		_last_cam = camera.position
		_last_zoomv = camera.zoom
		queue_redraw()


# ============================================================ INPUT
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		if view == "local":
			_exit_to_city()
		else:
			_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and get_viewport().get_mouse_position().x < PANEL_W:
		if event is InputEventMouseButton and not event.pressed: _lmb_down = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_down = true; _lmb_moved = false
			else:
				if _lmb_down and not _lmb_moved:
					_click(get_global_mouse_position())
				_lmb_down = false
	elif event is InputEventMouseMotion:
		if _panning or (_lmb_down and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
			if event.relative.length() > 3.0: _lmb_moved = true
			if _panning or _lmb_moved:
				camera.position -= event.relative / camera.zoom.x


func _click(wpos: Vector2) -> void:
	if view == "city":
		var bid := _building_at(wpos)
		if bid != -1:
			sel_building = bid
			_dirty = true
			# a reachable building opens directly into its local view (brief §1)
			if _breachable(bid):
				_enter_building(bid)
	else:
		var gid := _comp_at(wpos)
		if gid != -1:
			sel_comp = gid
			_dirty = true


func _building_at(wpos: Vector2) -> int:
	var best := -1
	var best_y := -INF
	for id in hosts:
		var w := _bw(id)
		var p: Vector2 = hosts[id].pos
		var box := Rect2(p.x - w * 0.5, p.y - BDEPTH - _bheight(id) - 6.0, w + BDEPTH + 6.0, _bheight(id) + BDEPTH + 10.0)
		if box.has_point(wpos) and p.y > best_y:
			best_y = p.y; best = id
	return best


func _comp_at(wpos: Vector2) -> int:
	if entered == -1: return -1
	var best := -1
	var bd := 34.0
	for gid in hosts[entered].comps:
		if comps[gid].state == "unknown":
			continue
		var d: float = (comps[gid].lpos).distance_to(wpos)
		if d < bd:
			bd = d; best = gid
	return best


# ============================================================ RENDERING
func _bw(id: int) -> float:
	var hh := (id * 2654435761) & 0xffff
	var base: float = 74.0 if hosts[id].type == "gateway" else 52.0
	return base + float(hh % 4) * 7.0

func _bheight(id: int) -> float:
	var hh := (id * 40503) & 0xffff
	if hosts[id].type == "gateway":
		return 92.0 + float(hh % 5) * 7.0
	return 44.0 + float(hh % 6) * 11.0

func _city_bounds() -> Rect2:
	var r := Rect2(hosts[c2_id].pos, Vector2.ZERO)
	for id in hosts:
		r = r.merge(Rect2(hosts[id].pos - Vector2(_bw(id) * 0.5, _bheight(id) + BDEPTH), Vector2(_bw(id), _bheight(id) + BDEPTH)))
	for d in decor:
		r = r.merge(Rect2(d.pos - Vector2(d.w * 0.5, float(d.height) + BDEPTH), Vector2(d.w, float(d.height) + BDEPTH)))
	return r

func _local_bounds(bid: int) -> Rect2:
	var r := Rect2(Vector2.ZERO, Vector2.ZERO)
	for gid in hosts[bid].comps:
		r = r.merge(Rect2(comps[gid].lpos - Vector2(60, 50), Vector2(120, 100)))
	return r

func _org_bounds() -> Array:
	var b := []
	b.resize(ORG_NAMES.size())
	for id in hosts:
		var org: int = int(hosts[id].org)
		var r := Rect2(hosts[id].pos - Vector2(_bw(id) * 0.5 + 24.0, BDEPTH + 24.0), Vector2(_bw(id) + 48.0, BDEPTH + 48.0))
		b[org] = r if b[org] == null else (b[org] as Rect2).merge(r)
	for d in decor:
		var o2: int = int(d.org)
		var r2 := Rect2(d.pos - Vector2(d.w * 0.5 + 10.0, BDEPTH + 10.0), Vector2(d.w + 20.0, BDEPTH + 20.0))
		b[o2] = r2 if b[o2] == null else (b[o2] as Rect2).merge(r2)
	return b


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if view == "city":
		_draw_city(font)
	else:
		_draw_local(font)


func _draw_city(font: Font) -> void:
	var zoom: float = camera.zoom.x
	var bounds := _org_bounds()
	for org in bounds.size():
		if bounds[org] == null: continue
		var r: Rect2 = bounds[org]
		var oc: Color = ORG_COL[org]
		draw_rect(r, Color(oc.r, oc.g, oc.b, 0.045), true)
		draw_rect(r, Color(oc.r, oc.g, oc.b, 0.18), false, 1.5)
		_draw_streets(r)
		draw_string(font, r.position + Vector2(10, -9), ORG_NAMES[org].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(oc.r, oc.g, oc.b, 0.85))
	# inter-building links: only DISCOVERED ones (either endpoint scanned) are drawn
	var drawn := {}
	for id in hosts:
		if not hosts[id].scanned:
			continue
		for nb in hosts[id].neighbors:
			if not hosts.has(nb): continue
			var key := mini(id, nb) * 100000 + maxi(id, nb)
			if drawn.has(key): continue
			drawn[key] = true
			var routed: bool = _has_foothold(id) and _has_foothold(nb) and _building_routed(id) and _building_routed(nb)
			var col := Color(0.2, 0.95, 0.75, 0.8) if routed else Color(0.5, 0.6, 0.75, 0.33)
			draw_line(hosts[id].pos, hosts[nb].pos, col, 3.0 if routed else 1.5)
	for p in packets:
		var route: Array = p.route
		if int(p.idx) < route.size() - 1 and hosts.has(route[int(p.idx)]) and hosts.has(route[int(p.idx) + 1]):
			var a: Vector2 = hosts[route[int(p.idx)]].pos
			var b: Vector2 = hosts[route[int(p.idx) + 1]].pos
			var seg := maxf(a.distance_to(b), 1.0)
			draw_circle(a.lerp(b, clampf(float(p.dist) / seg, 0.0, 1.0)), 4.5, Settings.res_color(str(p.res)))
	var draw_list := []
	for d in decor:
		draw_list.append({"decor": true, "y": d.pos.y, "d": d})
	for id in hosts:
		draw_list.append({"decor": false, "y": hosts[id].pos.y, "id": id})
	draw_list.sort_custom(func(x, y): return x.y < y.y)
	for item in draw_list:
		if item.decor: _draw_decor(item.d)
		else: _draw_building(item.id, font, zoom)


func _draw_streets(r: Rect2) -> void:
	var road := Color(0.55, 0.62, 0.72, 0.06)
	var x := r.position.x + BLOCK.x * 0.5
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), road, 1.0); x += BLOCK.x
	var y := r.position.y + BLOCK.y * 0.5
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), road, 1.0); y += BLOCK.y


func _prism(pos: Vector2, w: float, height: float, topc: Color, frontc: Color, rightc: Color, edgec: Color) -> Array:
	var bx := pos.x - w * 0.5
	var by := pos.y
	var dv := Vector2(BDEPTH * 0.8, -BDEPTH * 0.6)
	var blf := Vector2(bx, by); var brf := Vector2(bx + w, by)
	var tlf := Vector2(bx, by - height); var trf := Vector2(bx + w, by - height)
	var trb := trf + dv; var tlb := tlf + dv; var brb := brf + dv
	draw_colored_polygon(PackedVector2Array([brf, brb, trb, trf]), rightc)
	draw_colored_polygon(PackedVector2Array([blf, brf, trf, tlf]), frontc)
	draw_colored_polygon(PackedVector2Array([tlf, trf, trb, tlb]), topc)
	draw_polyline(PackedVector2Array([blf, brf, trf, tlf, blf]), edgec, 1.0)
	draw_polyline(PackedVector2Array([trf, trb, tlb, tlf]), edgec, 1.0)
	draw_line(brf, brb, edgec, 1.0)
	return [tlf, trf]


func _draw_decor(d: Dictionary) -> void:
	var g := 0.10 + fmod(float(d.pos.x) * 0.013, 0.05)
	_prism(d.pos, float(d.w), float(d.height), Color(g + 0.05, g + 0.06, g + 0.09), Color(g, g + 0.01, g + 0.03),
		Color(g - 0.03, g - 0.02, g), Color(0.22, 0.26, 0.32, 0.5))


func _draw_building(id: int, font: Font, zoom: float) -> void:
	var h = hosts[id]
	var w := _bw(id)
	var height := _bheight(id)
	var oc: Color = ORG_COL[int(h.org)]
	var foothold := _has_foothold(id)
	var full := _building_full(id)
	var known := bool(h.scanned) or foothold or _breachable(id)
	var topc: Color; var frontc: Color; var rightc: Color; var edgec: Color
	if not known:
		topc = Color(0.20, 0.22, 0.27); frontc = Color(0.15, 0.17, 0.21); rightc = Color(0.11, 0.12, 0.15); edgec = Color(0.4, 0.45, 0.54, 0.6)
	elif not foothold:
		# reachable/scanned but not yet captured — cool, tinted
		topc = Color(oc.r * 0.3 + 0.1, oc.g * 0.3 + 0.1, oc.b * 0.3 + 0.12); frontc = Color(oc.r * 0.2 + 0.07, oc.g * 0.2 + 0.08, oc.b * 0.2 + 0.1)
		rightc = Color(0.1, 0.11, 0.14); edgec = Color(oc.r, oc.g, oc.b, 0.65)
	else:
		topc = Color(oc.r * 0.55, oc.g * 0.55, oc.b * 0.62); frontc = Color(oc.r * 0.42, oc.g * 0.42, oc.b * 0.5)
		rightc = Color(oc.r * 0.26, oc.g * 0.26, oc.b * 0.32); edgec = oc
	var tf: Array = _prism(h.pos, w, height, topc, frontc, rightc, edgec)
	if zoom > 0.5 and (foothold or known):
		var lit: bool = foothold
		var wcol := Color(oc.r, oc.g, oc.b, 0.6) if lit else Color(0.5, 0.56, 0.66, 0.15)
		var rows := int(clampf(height / 18.0, 1.0, 5.0))
		for wy in rows:
			for wx in 3:
				draw_rect(Rect2(Vector2(h.pos.x - w * 0.5 + 8 + wx * (w - 16) / 2.0 - 3, h.pos.y - 10 - wy * 15), Vector2(6, 6)), wcol, true)
	# control pips on the roof: captured components / total
	if foothold and zoom > 0.45:
		var cap := 0
		for gid in h.comps:
			if comps[gid].state == "captured": cap += 1
		var txt := ("FULL" if full else "%d/%d" % [cap, h.comps.size()])
		draw_line(tf[0] + Vector2(0, -2), tf[1] + Vector2(0, -2), Color(0.3, 1.0, 0.7, 0.9), 2.0)
		draw_string(font, Vector2(h.pos.x - w * 0.5, h.pos.y - height - 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 1.0, 0.7))
	if _breachable(id) and not foothold:
		var foot := Rect2(h.pos.x - w * 0.5 - 3, h.pos.y - BDEPTH - 3, w + 6, BDEPTH + 6)
		draw_rect(foot, Color(1.0, 0.9, 0.3, 0.8), false, 2.0)   # reachable: you can enter + attack
	if id == sel_building:
		draw_rect(Rect2(h.pos.x - w * 0.5 - 6, h.pos.y - BDEPTH - 6, w + 12, BDEPTH + 12), Color(1, 1, 1, 0.9), false, 2.0)
	if id == c2_id:
		draw_string(font, Vector2(h.pos.x - w * 0.5, h.pos.y - height - 26), "◤ C2", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 1.0, 0.9))


# ---- local component schematic ----
func _draw_local(font: Font) -> void:
	if entered == -1 or not hosts.has(entered):
		return
	var ids: Array = hosts[entered].comps
	# links between discovered components
	for gid in ids:
		if comps[gid].state == "unknown": continue
		for nb in comps[gid].neighbors:
			if not comps.has(nb) or comps[nb].state == "unknown" or nb < gid: continue
			var cap_edge: bool = comps[gid].state == "captured" and comps[nb].state == "captured"
			var incident: bool = gid == sel_comp or nb == sel_comp
			var col := Color(1.0, 0.92, 0.4, 0.9) if incident else (Color(0.2, 0.95, 0.75, 0.75) if cap_edge else Color(0.5, 0.62, 0.78, 0.4))
			draw_line(comps[gid].lpos, comps[nb].lpos, col, 3.0 if (incident or cap_edge) else 1.5)
	# component nodes
	for gid in ids:
		_draw_comp(gid, font)
	# header
	draw_string(font, _local_bounds(entered).position + Vector2(0, -30), "LOCAL NETWORK — %s   (Esc to city)" % _bname(entered),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 1.0, 0.9, 0.9))


func _draw_comp(gid: int, font: Font) -> void:
	var c = comps[gid]
	var p: Vector2 = c.lpos
	var st: String = str(c.state)
	if st == "unknown":
		return   # hidden until scanned from a neighbour
	var oc: Color = ORG_COL[int(hosts[int(c.bid)].org)]
	var r := 26.0
	var captured := st == "captured"
	var body := Color(oc.r * 0.5, oc.g * 0.5, oc.b * 0.58) if captured else Color(0.16, 0.18, 0.22)
	draw_circle(p, r, body)
	var ring := oc if captured else Color(0.55, 0.62, 0.72, 0.8)
	draw_arc(p, r, 0, TAU, 28, ring, 2.5 if captured else 1.5)
	# type label
	draw_string(font, p - Vector2(r - 3, -4), COMP[str(c.type)].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9) if captured else Color(0.8, 0.85, 0.92))
	# slots + load bar for captured; defences for scanned
	if captured:
		var used: int = c.programs.size()
		draw_string(font, p + Vector2(-r + 2, 16), "slots %d/%d" % [used, int(c.slots)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.9, 1.0))
		# integrity ring + overload warning
		var over := _comp_overloaded(gid)
		var frac := clampf(float(c.integrity) / INTEGRITY_MAX, 0.0, 1.0)
		draw_arc(p, r + 5, -PI / 2, -PI / 2 + TAU * frac, 24, Color(1.0, 0.5, 0.3) if over else Color(0.3, 1.0, 0.7, 0.9), 2.5)
		# installed program chips
		var n: int = c.programs.size()
		for i in n:
			var spec: Dictionary = PROGRAMS[str(c.programs[i].key)]
			var mc: Color = Settings.res_color(str(spec.get("out", "compute")))
			if not bool(c.programs[i].get("enabled", true)): mc = Color(0.4, 0.42, 0.48)
			draw_rect(Rect2(p + Vector2(-r + 3 + i * 9, -r - 2), Vector2(7, 7)), mc, true)
		if over:
			draw_string(font, p + Vector2(-r, r + 14), "⚠ OVERLOAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.5, 0.3))
	else:
		draw_string(font, p + Vector2(-r + 2, 16), "P%d V%d%s" % [int(c["pass"]), int(c.vuln), (" A%d" % int(c.aware)) if int(c.aware) > 0 else ""],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.7, 0.5))
	if c.entry:
		draw_string(font, p + Vector2(-10, -r - 6), "entry", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.9, 1.0))
	if _comp_attack_frontier(gid) and not captured:
		draw_arc(p, r + 3, 0, TAU, 28, Color(1.0, 0.9, 0.3, 0.8), 2.0)
	if gid == sel_comp:
		draw_arc(p, r + 9, 0, TAU, 30, Color(1, 1, 1, 0.95), 2.0)


# ============================================================ UI
func _lbl(parent: Control, px: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", int(round(px * Settings.text_scale)))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _mkbtn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, int(round(34 * maxf(1.0, Settings.text_scale))))
	b.add_theme_font_size_override("font_size", int(round(14 * Settings.text_scale)))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = PANEL_W
	ui_layer.add_child(panel)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10; col.offset_top = 10; col.offset_right = -10; col.offset_bottom = -10
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var ttl := _lbl(col, 26)
	ttl.text = "RIM"
	ttl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	res_label = _lbl(col, 15)
	progress_label = _lbl(col, 13)
	progress_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	col.add_child(HSeparator.new())
	info_title = _lbl(col, 18)
	info_title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	info_body = _lbl(col, 13)
	act_scroll = ScrollContainer.new()
	act_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	act_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(act_scroll)
	act_box = VBoxContainer.new()
	act_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_box.add_theme_constant_override("separation", 4)
	act_scroll.add_child(act_box)
	status_label = _lbl(col, 13)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	status_label.custom_minimum_size = Vector2(0, 66)
	_update_ui()


func _update_ui() -> void:
	if res_label == null:
		return
	res_label.text = "Cy %d  In %d  Cr %d  To %d  Ca %d  Re %d" % [int(resources.compute), int(resources.data),
		int(resources.crypto), int(resources.tools), int(resources.credits), int(resources.research)]
	var owned := 0; var total := 0
	for gid in comps:
		total += 1
		if comps[gid].state == "captured": owned += 1
	var bf := 0
	for id in hosts:
		if _has_foothold(id): bf += 1
	progress_label.text = "Components %d/%d   Buildings held %d/%d%s" % [owned, total, bf, hosts.size(), "   ✔ CITY TAKEN" if won else ""]
	status_label.text = message
	# action list rebuilt only when the relevant state signature changes (keeps paused idle cheap)
	var sig := _ui_signature()
	if sig != _act_sig:
		_act_sig = sig
		_rebuild_actions()


func _ui_signature() -> Array:
	var s := [view, entered, sel_building, sel_comp, int(resources.compute), int(resources.data),
		int(resources.tools), int(resources.research), researched.size()]
	if view == "local" and comps.has(sel_comp):
		s.append(str(comps[sel_comp].state))
		s.append(comps[sel_comp].programs.size())
	if view == "city" and hosts.has(sel_building):
		s.append(hosts[sel_building].scanned)
		s.append(_has_foothold(sel_building))
	return s


func _rebuild_actions() -> void:
	for c in act_box.get_children():
		c.queue_free()
	if view == "city":
		_actions_city()
	else:
		_actions_local()


func _actions_city() -> void:
	if sel_building == -1 or not hosts.has(sel_building):
		info_title.text = "City map"
		info_body.text = "Click a building. Yellow outline = reachable (enter it to hack). Scanning a building you hold maps its links to neighbours. Discovered links are drawn; hidden ones stay invisible."
		return
	var bid := sel_building
	var foothold := _has_foothold(bid)
	info_title.text = _bname(bid) + ("  — C2" if bid == c2_id else "")
	var owned := 0
	for gid in hosts[bid].comps:
		if comps[gid].state == "captured": owned += 1
	var body := "Owner: %s\nComponents captured: %d/%d\nStatus: %s" % [ORG_NAMES[int(hosts[bid].org)], owned, hosts[bid].comps.size(),
		("FULL CONTROL" if _building_full(bid) else ("foothold" if foothold else ("reachable" if _breachable(bid) else "not reachable")))]
	if hosts[bid].scanned:
		body += "\nLinks mapped: %d connected building(s)." % hosts[bid].neighbors.size()
	info_body.text = body
	if _breachable(bid):
		_mkbtn(act_box, "Enter local network", func(): _enter_building(bid))
	if _building_scannable(bid):
		_mkbtn(act_box, "Scan building — map links  (%d Cy)" % int(SCAN_COST), func(): scan_building(bid))
	_mkbtn(act_box, "Main Menu  (Esc)", _to_menu)
	_mkbtn(act_box, "Save", func(): save_game())


func _actions_local() -> void:
	_mkbtn(act_box, "◂ Back to city  (Esc)", _exit_to_city)
	if sel_comp == -1 or not comps.has(sel_comp):
		info_title.text = "Local network — %s" % _bname(entered)
		info_body.text = "Click a component. Scan a revealed one to discover its neighbours; attack with a card to capture it; then install programs in its slots."
		return
	var gid := sel_comp
	var c = comps[gid]
	var ct: Dictionary = COMP[str(c.type)]
	info_title.text = "%s" % _cname(gid)
	var st: String = str(c.state).to_upper()
	var body := "Type: %s   (%s)\nState: %s\nSlots: %d   Capacity: %.0f   Affinity: %s" % [ct.name, ", ".join(c.traits),
		st, int(c.slots), float(c.cap), (RES_NAMES[str(c.affin)] if str(c.affin) != "none" else "balanced ×0.5")]
	if str(c.state) != "captured":
		body += "\nDefences — password %d, software %d%s" % [int(c["pass"]), int(c.vuln), (", awareness %d" % int(c.aware)) if int(c.aware) > 0 else ""]
	else:
		body += "\nActive load: %.1f / %.0f %s\nAccess integrity: %d%%" % [_comp_load(gid), float(c.cap),
			("⚠ OVERLOAD — degrading" if _comp_overloaded(gid) else ""), int(round(float(c.integrity)))]
	info_body.text = body

	if _comp_scannable(gid):
		_mkbtn(act_box, "Scan component — neighbours  (%d Cy)" % int(SCAN_COST), func(): scan_component(gid))

	# attack cards
	if str(c.state) != "captured" and _comp_attack_frontier(gid):
		var hdr := _lbl(act_box, 12)
		hdr.text = "ATTACK CARDS:"
		hdr.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
		for key in CARD_ORDER:
			var card: Dictionary = CARDS[key]
			var out := _card_outcome(gid, key)
			var b := _mkbtn(act_box, "%s [%s] p%d  %s  → %s" % [card.name, str(card.branch).substr(0, 4), int(card.power), _cost_str(card.cost), out.reason],
				func(): attack_component(gid, key))
			b.disabled = not out.ok
			if not _card_unlocked(key):
				b.text += "  🔒"

	# install programs
	if str(c.state) == "captured":
		var hdr2 := _lbl(act_box, 12)
		hdr2.text = "BUILD PROGRAMS:  (installed below)"
		hdr2.add_theme_color_override("font_color", Color(0.6, 0.95, 0.8))
		for i in c.programs.size():
			var pk: String = str(c.programs[i].key)
			var en: bool = bool(c.programs[i].get("enabled", true))
			var idx: int = i
			var row := HBoxContainer.new()
			act_box.add_child(row)
			var tgl := _mkbtn(row, "%s %s" % ["▣" if en else "▢", PROGRAMS[pk].name], func(): toggle_program(gid, idx))
			tgl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_mkbtn(row, "✕", func(): remove_program(gid, idx))
		if _free_slots(gid) > 0:
			for key in PROGRAM_ORDER:
				var prog: Dictionary = PROGRAMS[key]
				var tag: String = ("+%.1f %s" % [float(prog.rate), RES_NAMES[str(prog.out)]]) if str(prog.kind) == "producer" else ("%s→%s" % [RES_NAMES[str(prog.get("in","?"))], RES_NAMES[str(prog.out)]])
				var b2 := _mkbtn(act_box, "Build %s  %s  (load %.0f, %s)" % [prog.name, tag, float(prog.load), _cost_str(prog.cost)], func(): install_program(gid, key))
				b2.disabled = not _can_afford(prog.cost)

	# research (available anywhere in local view, funded by Research resource)
	var rhdr := _lbl(act_box, 12)
	rhdr.text = "RESEARCH  (spend Research to unlock stronger cards):"
	rhdr.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	for key in RESEARCH_ORDER:
		var r: Dictionary = RESEARCH[key]
		if researched.has(key):
			var done := _lbl(act_box, 11)
			done.text = "✓ %s" % r.name
			done.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
		else:
			var rb := _mkbtn(act_box, "Research %s  (%d Research)" % [r.name, int(r.cost)], func(): research_card(key))
			rb.disabled = resources.research < float(r.cost)


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ============================================================ SAVE / LOAD
func save_game() -> bool:
	var dsave := []
	for d in decor:
		dsave.append({"pos": [d.pos.x, d.pos.y], "w": d.w, "height": d.height, "org": d.org})
	var hsave := {}
	for id in hosts:
		var h = hosts[id]
		hsave[str(id)] = {"id": id, "pos": [h.pos.x, h.pos.y], "org": h.org, "type": h.type,
			"scanned": h.scanned, "neighbors": h.neighbors, "parent": h.parent, "comps": h.comps, "entry_gid": h.entry_gid}
	var csave := {}
	for gid in comps:
		var c = comps[gid]
		csave[str(gid)] = {"id": c.id, "bid": c.bid, "type": c.type, "lpos": [c.lpos.x, c.lpos.y],
			"state": c.state, "neighbors": c.neighbors, "entry": c.entry, "pass": c["pass"], "vuln": c.vuln,
			"aware": c.aware, "traits": c.traits, "slots": c.slots, "cap": c.cap, "affin": c.affin,
			"programs": c.programs, "integrity": c.integrity}
	var data := {"v": 8, "seed": seed, "city_size": city_size, "c2": c2_id, "next_bid": next_bid, "next_gid": next_gid,
		"rng": str(rng.state), "resources": resources, "researched": researched, "won": won,
		"first_banked": _first_banked, "time": _time, "hosts": hsave, "comps": csave, "decor": dsave,
		"cam": [camera.position.x, camera.position.y], "zoom": camera.zoom.x, "view": view, "entered": entered}
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		message = "Save failed."; return false
	f.store_string(JSON.stringify(data)); f.close()
	if _parse_save(FileAccess.get_file_as_string(tmp)) == null:
		DirAccess.remove_absolute(tmp); message = "Save failed — verification."; return false
	if DirAccess.rename_absolute(tmp, SAVE_PATH) != OK:
		message = "Save failed — finalise."; return false
	message = "Game saved."
	return true


func _parse_save(text: String):
	var j := JSON.new()
	if j.parse(text) != OK: return null
	var d = j.data
	if typeof(d) != TYPE_DICTIONARY or not d.has("hosts") or not d.has("comps"): return null
	if typeof(d.hosts) != TYPE_DICTIONARY or typeof(d.comps) != TYPE_DICTIONARY: return null
	if not d.has("c2") or not d.hosts.has(str(int(d.c2))): return null
	for k in d.comps:
		var c = d.comps[k]
		if typeof(c) != TYPE_DICTIONARY: return null
		for req in ["id", "bid", "type", "lpos", "state", "slots", "cap"]:
			if not c.has(req): return null
	# at least one captured component must exist (a live foothold)
	var any_cap := false
	for k in d.comps:
		if str(d.comps[k].state) == "captured": any_cap = true
	if not any_cap: return null
	return d


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var d = _parse_save(FileAccess.get_file_as_string(SAVE_PATH))
	if d == null:
		message = "Saved game was unreadable — starting fresh."; return false
	seed = int(d.seed); rng.seed = seed
	city_size = str(d.get("city_size", "small"))
	c2_id = int(d.c2); next_bid = int(d.get("next_bid", 1)); next_gid = int(d.get("next_gid", 1))
	var r = d.get("resources", {})
	resources = {}
	for k in RES_KEYS:
		resources[k] = float(r.get(k, 0.0))
	researched = {}
	for k in d.get("researched", {}):
		researched[str(k)] = true
	won = bool(d.get("won", false)); _first_banked = bool(d.get("first_banked", false)); _time = float(d.get("time", 0.0))
	decor = []
	for dd in d.get("decor", []):
		decor.append({"pos": Vector2(float(dd.pos[0]), float(dd.pos[1])), "w": float(dd.w), "height": float(dd.height), "org": int(dd.org)})
	hosts = {}
	for k in d.hosts:
		var h = d.hosts[k]
		var nbs := []
		for nb in h.neighbors: nbs.append(int(nb))
		var cl := []
		for g in h.comps: cl.append(int(g))
		hosts[int(h.id)] = {"id": int(h.id), "pos": Vector2(float(h.pos[0]), float(h.pos[1])), "org": int(h.org),
			"type": str(h.type), "scanned": bool(h.scanned), "neighbors": nbs, "parent": int(h.parent),
			"comps": cl, "entry_gid": int(h.entry_gid)}
	comps = {}
	for k in d.comps:
		var c = d.comps[k]
		var cnbs := []
		for nb in c.neighbors: cnbs.append(int(nb))
		var pls := []
		for p in c.get("programs", []):
			pls.append({"key": str(p.key), "acc": float(p.get("acc", 0.0)), "enabled": bool(p.get("enabled", true))})
		var tr := []
		for t in c.get("traits", []): tr.append(str(t))
		comps[int(c.id)] = {"id": int(c.id), "bid": int(c.bid), "type": str(c.type),
			"lpos": Vector2(float(c.lpos[0]), float(c.lpos[1])), "state": str(c.state), "neighbors": cnbs,
			"entry": bool(c.get("entry", false)), "pass": int(c["pass"]), "vuln": int(c.vuln), "aware": int(c.get("aware", 0)),
			"traits": tr, "slots": int(c.slots), "cap": float(c.cap), "affin": str(c.get("affin", "none")),
			"programs": pls, "integrity": float(c.get("integrity", INTEGRITY_MAX))}
	if d.has("rng"): rng.state = int(str(d.rng))
	view = str(d.get("view", "city")); entered = int(d.get("entered", -1))
	if d.has("cam"): camera.position = Vector2(float(d.cam[0]), float(d.cam[1]))
	if d.has("zoom"): camera.zoom = Vector2.ONE * float(d.zoom)
	packets = []
	return true
