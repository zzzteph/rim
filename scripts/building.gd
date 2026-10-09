extends Node2D
## RIM — a building's LOCAL network map (the Stellaris "inside a system" layer). The city map hands us
## one building (via Session.enter); we generate its internal network of components, laid out as a
## constellation over the building's NETWORK PLAN (its security zones: perimeter → internal LAN →
## secure core). Discovery is two kinds of scan, walking one controlled hop at a time:
##   • SCAN NETWORK from a node you CONTROL → detects its direct neighbours (as unknown blips), or
##     tells you it has no further connections.
##   • SCAN ENDPOINT on a detected node → profiles it (type, owner, details) and unlocks TAKE CONTROL.
##   • TAKE CONTROL of a profiled node that touches one you hold → it becomes yours; scan onward from it.
##     Burn a credential (login nodes) or an exploit (software nodes) for a better chance.
## Every action costs Intel (Econ). Each node has typed SLOTS; you deploy PROGRAMS (Econ.PROGRAMS) into
## matching slots and they produce for you from then on, their output flowing back to the entry.
##
## UI (Stellaris-style, solid panels): TOP bar = title + resources (Econ HUD) · LEFT bar = programs to
## deploy · BOTTOM bar = selected node, its slots, its actions · the MAP fills the rest, on the right.
## Esc returns to the city, which marks every building you've started to compromise.

# node type → slot count, which program CATEGORIES fit (see Econ.PROGRAMS), draw radius, accent colour
const NODE := {
	"fw":   {"name": "Firewall / Router", "slots": 0, "accepts": [],                                     "r": 18.0, "col": Color(1.0, 0.55, 0.3)},
	"iot":  {"name": "IoT Device",        "slots": 2, "accepts": ["crypto", "creds", "evade"],            "r": 14.0, "col": Color(0.5, 1.0, 0.7)},
	"web":  {"name": "Web Server",        "slots": 4, "accepts": ["intel", "crypto", "evade"],            "r": 16.0, "col": Color(0.45, 0.85, 1.0)},
	"file": {"name": "File Server",       "slots": 4, "accepts": ["intel", "ops", "evade"],               "r": 16.0, "col": Color(0.6, 0.8, 1.0)},
	"db":   {"name": "Database",          "slots": 6, "accepts": ["intel", "creds", "evade"],             "r": 18.0, "col": Color(0.7, 0.6, 1.0)},
	"pc":   {"name": "Workstation",       "slots": 6, "accepts": ["intel", "creds", "crypto", "ops", "evade"], "r": 16.0, "col": Color(0.95, 0.85, 0.5)},
	"core": {"name": "Core Mainframe",    "slots": 8, "accepts": ["intel", "creds", "crypto", "ops", "evade"], "r": 24.0, "col": Color(0.4, 1.0, 0.95)},
}
# a burned CREDENTIAL boosts captures of nodes with a login; a burned EXPLOIT those running software
const LOGIN_TYPES := ["fw", "iot", "web", "pc"]
const SOFTWARE_TYPES := ["web", "file", "db", "core"]
# building security label → base success chance for scans / take-control
const SEC_DIFF := {
	"None to speak of": 0.97, "Patchwork": 0.9, "Consumer-grade": 0.82, "Corporate ICE": 0.64,
	"Heavy ICE": 0.52, "Black ICE": 0.38, "Lethal — black ICE": 0.24,
}
# per-type difficulty multiplier (a database/core is tougher than a camera)
const TYPE_MOD := {"fw": 1.0, "iot": 1.25, "web": 1.0, "file": 0.95, "db": 0.8, "pc": 0.9, "core": 0.65}
# the building's security zones on the plan, by node tier
const ZONES := [["PERIMETER · DMZ", [0, 1]], ["INTERNAL LAN", [2]], ["SECURE CORE", [3, 4]]]
# UI frame (screen px)
const TOP_H := 44.0   # = Econ.BAR_H, the global top bar
const LEFT_W := 300.0
const BOT_H := 224.0
const UI_BG := Color(0.05, 0.06, 0.09, 1.0)
const UI_EDGE := Color(0.2, 1.0, 0.9, 0.5)

var info := {}             # the Session.enter payload
var nodes := []            # [{id,type,name,owner,detail,pos,state,profiled,enum_done,progs,nbrs,slots}]
var rng := RandomNumberGenerator.new()
var roll := RandomNumberGenerator.new()   # non-reproducible dice for scan/control attempts (retryable)
var sel := -1
var _shell := Rect2()      # the building outline on the plan
var _bands := []           # [{rect, label}] security-zone bands on the plan
var _rooms := []           # faint "room" rectangles for plan texture
var _flows := []           # [{path:[node ids], res}] — each program's route back to the entry (data flow)
var camera: Camera2D
var _panning := false
var _lmb_down := false
var _lmb_moved := false
var _time := 0.0
var instant_actions := false   # tests only: resolve timed actions immediately
var _task_acc := 0.0          # paces the panel refresh while a task runs
var _msg := ""
var _msg_t := 0.0
var _msg_col := Color(0.6, 1.0, 1.0)

var title_lbl: Label
var b_title: Label
var b_body: Label
var b_slots: HBoxContainer
var b_actions: VBoxContainer
var l_hint: Label
var l_list: VBoxContainer
var _fx: Node2D


func _ready() -> void:
	info = Session.enter if not Session.enter.is_empty() else {"key": [0, 0], "name": "Test Node", "kind": "corp", "sec": "Corporate ICE", "col": [0.4, 0.9, 1.0], "owner": "", "people": []}
	rng.seed = hash(str(info.key)) ^ (Session.seed * 2654435761)
	roll.randomize()
	camera = Camera2D.new(); add_child(camera); camera.make_current()
	_generate()
	if not _restore(): _init_state()
	_frame()
	_fx = _FxLayer.new(); _fx.host = self; add_child(_fx)
	_build_ui()
	_refresh()


# ============================================================ GENERATION
func _kcol() -> Color:
	var c = info.get("col", [0.4, 0.9, 1.0])
	return Color(c[0], c[1], c[2])


# the list of component TYPES for this building (entry firewall is added separately as node 0)
func _compose() -> Array:
	var kind := str(info.kind)
	var out := []
	var np: int = (info.get("people", []) as Array).size()
	match kind:
		"fh":
			for i in rng.randi_range(1, 2): out.append("iot")
			for i in maxi(1, mini(3, np)): out.append("pc")
			if rng.randf() < 0.5: out.append("file")
		"ap", "sc":
			for i in rng.randi_range(2, 3): out.append("iot")
			for i in rng.randi_range(1, 2): out.append("pc")
			out.append("file")
			if kind == "sc" and rng.randf() < 0.6: out.append("db")
		"shop_s", "shop_b":
			out.append("web"); out.append("pc")
			for i in rng.randi_range(1, 2): out.append("iot")
		"mall":
			for i in rng.randi_range(2, 3): out.append("iot")
			out.append("web"); out.append("file")
			for i in rng.randi_range(1, 2): out.append("db")
			out.append("pc")
		"off_s", "off_m":
			out.append("web")
			for i in rng.randi_range(1, 2): out.append("file")
			for i in rng.randi_range(1, 2): out.append("db")
			for i in rng.randi_range(1, 3): out.append("pc")
		"corp":
			for i in rng.randi_range(1, 2): out.append("web")
			for i in 2: out.append("file")
			for i in rng.randi_range(2, 4): out.append("db")
			for i in rng.randi_range(1, 3): out.append("pc")
			out.append("core")
		"hub":
			for i in 2: out.append("web")
			for i in 2: out.append("file")
			for i in rng.randi_range(3, 5): out.append("db")
			for i in 2: out.append("pc")
			for i in rng.randi_range(1, 2): out.append("core")
		_:
			out.append("pc"); out.append("iot")
	return out


# tier = how deep in the network a type sits (public → core); drives both the graph and the layout
func _tier(t: String) -> int:
	return {"fw": 0, "iot": 1, "web": 1, "file": 2, "pc": 2, "db": 3, "core": 4}.get(t, 2)


func _generate() -> void:
	nodes = []
	_add_node("fw")                       # node 0 = the entry router/firewall
	for t in _compose(): _add_node(t)
	# connect each node to a random shallower one (fw for tier 1), so the graph is a tree rooted at the
	# entry with the core deepest — discovery must walk inward hop by hop
	for i in range(1, nodes.size()):
		var ti: int = _tier(nodes[i].type)
		var cands := []
		for j in i:
			if _tier(nodes[j].type) < ti: cands.append(j)
		if cands.is_empty():
			for j in i: cands.append(j)
		var p: int = cands[rng.randi() % cands.size()]
		_link(i, p)
	# a few redundant sibling links (same or adjacent tier) so it reads as a mesh, never over the entry
	var extra := nodes.size() / 4
	for e in extra:
		var a := rng.randi_range(1, nodes.size() - 1); var b := rng.randi_range(1, nodes.size() - 1)
		if a != b and not nodes[a].nbrs.has(b) and absi(_tier(nodes[a].type) - _tier(nodes[b].type)) <= 1:
			_link(a, b)
	_layout()
	_plan()


func _add_node(t: String) -> void:
	var id := nodes.size()
	var nd: Dictionary = NODE[t]
	nodes.append({"id": id, "type": t, "name": _node_name(t, id), "owner": _node_owner(t, id),
		"detail": _node_detail(t), "pos": Vector2.ZERO, "state": "hidden", "profiled": false, "enum_done": false,
		"progs": [], "nbrs": [], "slots": int(nd.slots), "heat": 0.0, "burned": 0,
		"task": "", "t": 0.0, "dur": 0.0, "tprog": "", "tboost": "", "troute": [], "tsucc": false, "tfail": -1.0, "fx_t": 0.0, "fx_kind": ""})


func _link(a: int, b: int) -> void:
	if a == b or nodes[a].nbrs.has(b): return
	nodes[a].nbrs.append(b); nodes[b].nbrs.append(a)


# constellation layout: radial by tier (entry left, core toward the right), then a few relaxation
# passes to spread nodes apart. Computed once; no per-frame physics.
func _layout() -> void:
	var by_tier := {}
	for nd in nodes:
		var d: int = _tier(nd.type)
		if not by_tier.has(d): by_tier[d] = []
		by_tier[d].append(nd.id)
	for d in by_tier:
		var arr: Array = by_tier[d]
		var cx := 160.0 + float(d) * 170.0
		for i in arr.size():
			var f := (float(i) + 0.5) / float(arr.size())
			var ang := (f - 0.5) * PI * 0.9
			nodes[arr[i]].pos = Vector2(cx, 300.0 + sin(ang) * (60.0 + float(arr.size()) * 42.0)) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
	for pass_i in 70:   # repulsion + edge springs
		var disp := {}
		for nd in nodes: disp[nd.id] = Vector2.ZERO
		for i in nodes.size():
			for j in range(i + 1, nodes.size()):
				var d: Vector2 = nodes[i].pos - nodes[j].pos
				var dist := maxf(d.length(), 1.0)
				if dist < 128.0:
					var push := d / dist * (128.0 - dist) * 0.5
					disp[i] += push; disp[j] -= push
		for nd in nodes:
			for o in nd.nbrs:
				if o <= nd.id: continue
				var d: Vector2 = nodes[o].pos - nd.pos
				var dist := d.length()
				if dist > 160.0:
					var pull := d.normalized() * (dist - 160.0) * 0.25
					disp[nd.id] += pull; disp[o] -= pull
		for nd in nodes:
			var dv: Vector2 = disp[nd.id]
			dv.x *= 0.5   # keep the zone bands readable while still spreading nodes apart
			nd.pos += dv


# the building's NETWORK PLAN behind the nodes: an outer shell, one band per security zone (sized to the
# nodes that live in it), and faint "rooms" for architectural texture. Known from the start — it's the
# building's floor plan, not the network.
func _plan() -> void:
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for nd in nodes:
		lo = Vector2(minf(lo.x, nd.pos.x), minf(lo.y, nd.pos.y)); hi = Vector2(maxf(hi.x, nd.pos.x), maxf(hi.y, nd.pos.y))
	_shell = Rect2(lo - Vector2(90, 110), hi - lo + Vector2(180, 200))
	_bands = []
	var bx := _shell.position.x + 14.0
	for z in ZONES:
		var xs := []
		for nd in nodes:
			if (z[1] as Array).has(_tier(nd.type)): xs.append(nd.pos.x)
		if xs.is_empty(): continue
		var mx: float = xs.max()
		var right: float = mx + 75.0
		_bands.append({"rect": Rect2(bx, _shell.position.y + 14.0, right - bx, _shell.size.y - 28.0), "label": str(z[0])})
		bx = right
	if not _bands.is_empty():   # the last band stretches to the shell's edge
		var last: Dictionary = _bands[_bands.size() - 1]
		last.rect.size.x = _shell.end.x - 14.0 - last.rect.position.x
	_rooms = []
	for b in _bands:
		var r: Rect2 = b.rect
		for i in rng.randi_range(2, 4):
			var w := rng.randf_range(40.0, 90.0); var h := rng.randf_range(30.0, 70.0)
			_rooms.append(Rect2(r.position.x + rng.randf_range(8.0, maxf(8.0, r.size.x - w - 8.0)), r.position.y + rng.randf_range(8.0, maxf(8.0, r.size.y - h - 8.0)), w, h))


# ---- node lore (built-in for now; node-name pools can move into data/city_lore.json later) ----
func _node_name(t: String, id: int) -> String:
	match t:
		"fw": return "Edge Firewall"
		"core": return ("%s Mainframe" % str(info.owner).split(" ")[0]) if str(info.owner) != "" else "Core Mainframe"
		"pc":
			var ppl: Array = info.get("people", [])
			var pcs := 0
			for nd in nodes:
				if str(nd.type) == "pc": pcs += 1
			if pcs < ppl.size(): return "%s's Workstation" % str(ppl[pcs]).split(" ")[0]
			return "Workstation %d" % (pcs + 1)
		"db": return _pick(["Records", "Payroll", "Customer", "Archive", "Credential", "Research"]) + " DB"
		"file": return _pick(["Document", "Backup", "Media", "Shared"]) + " Store"
		"web": return _pick(["Public Portal", "Booking Site", "Storefront", "Intranet"])
		"iot": return _pick(["Door Camera", "Smart Lock", "HVAC Unit", "Elevator Ctrl", "Sensor Hub", "Printer"])
	return str(NODE[t].name)


func _node_owner(t: String, _id: int) -> String:
	if t in ["db", "file", "web", "core"] and str(info.owner) != "": return str(info.owner)
	return ""


func _node_detail(t: String) -> String:
	match t:
		"db": return _pick(["%s records" % _num(), "last audit %d" % rng.randi_range(2066, 2079), "replication lag 4s"])
		"pc": return _pick(["logged in", "idle since 02:14", "2 USB devices"])
		"iot": return _pick(["firmware 1.%d" % rng.randi_range(0, 9), "default password", "cloud-linked"])
		"core": return "the crown jewels"
	return ""


func _num() -> String:
	var v := rng.randi_range(2, 900) * (100 if rng.randf() < 0.5 else 1000)
	var sv := str(v); var out := ""
	while sv.length() > 3: out = "," + sv.substr(sv.length() - 3) + out; sv = sv.substr(0, sv.length() - 3)
	return sv + out


func _pick(a: Array): return a[rng.randi() % a.size()]


# ============================================================ STATE / MECHANICS
func _init_state() -> void:
	nodes[0].state = "controlled"; nodes[0].profiled = true   # the entry router is your foothold
	if Session.host_owned(_keystr()):   # already conquered from the city (your start jack, or a breach) → all yours
		for nd in nodes:
			nd.state = "controlled"; nd.profiled = true; nd.enum_done = true
		_save()


func _keystr() -> String: return "%d,%d" % [int(info.key[0]), int(info.key[1])]


# persist this building's progress for the session + a summary the city uses to mark compromised buildings
func _save() -> void:
	var st := []; var ctl := 0; var det := 0
	for nd in nodes:
		st.append({"state": nd.state, "type": str(nd.type), "profiled": nd.profiled, "enum_done": nd.enum_done, "progs": nd.progs.duplicate(),
			"heat": float(nd.heat), "burned": int(nd.burned), "nbrs": (nd.nbrs as Array).duplicate(),
			"task": str(nd.task), "t": float(nd.t), "dur": float(nd.dur), "tprog": str(nd.tprog), "tboost": str(nd.tboost), "troute": (nd.troute as Array).duplicate(), "tsucc": bool(nd.tsucc), "tfail": float(nd.tfail), "slots": int(nd.slots)})
		if str(nd.state) == "controlled": ctl += 1
		elif str(nd.state) == "detected": det += 1
	Session.interior[_keystr()] = st
	if ctl > 1 or det > 0 or bool(nodes[0].enum_done):
		Session.hacked[_keystr()] = {"ctl": ctl, "n": nodes.size(), "det": det}
	if Econ.host_conquered(st): Session.owned[_keystr()] = true   # core cracked (or every node taken) → host is yours


func _restore() -> bool:
	var st = Session.interior.get(_keystr(), null)
	if not (st is Array) or (st as Array).size() != nodes.size(): return false
	for i in nodes.size():
		nodes[i].state = str(st[i].state); nodes[i].profiled = bool(st[i].profiled)
		nodes[i].enum_done = bool(st[i].enum_done); nodes[i].progs = (st[i].progs as Array).duplicate()
		nodes[i].heat = float(st[i].get("heat", 0.0)); nodes[i].burned = int(st[i].get("burned", 0))
		nodes[i].task = str(st[i].get("task", "")); nodes[i].t = float(st[i].get("t", 0.0)); nodes[i].dur = float(st[i].get("dur", 0.0))
		nodes[i].tprog = str(st[i].get("tprog", "")); nodes[i].tboost = str(st[i].get("tboost", "")); nodes[i].troute = (st[i].get("troute", []) as Array).duplicate()
		nodes[i].tsucc = bool(st[i].get("tsucc", false)); nodes[i].tfail = float(st[i].get("tfail", -1.0))
	return true


func _chance(nd: Dictionary) -> float:
	var base: float = SEC_DIFF.get(str(info.sec), 0.7)
	var pen := maxf(1.0 - float(Econ.HEAT.rehack_chance_per_alarm) * float(nd.get("burned", 0)), 1.0 - float(Econ.HEAT.rehack_chance_per_alarm) * float(Econ.HEAT.rehack_alarm_cap))
	return clampf(base * float(TYPE_MOD.get(str(nd.type), 1.0)) * pen, 0.05, 0.99)


# Intel cost of an action, scaled up on a burned node (+10% per past alarm)
func _icost(base: float, nd: Dictionary) -> Dictionary:
	return {"intel": base * (1.0 + float(Econ.HEAT.rehack_cost_per_alarm) * float(nd.get("burned", 0)))}


# a detected node can be taken if it neighbours a controlled node (reachable through your foothold)
func _reachable(nd: Dictionary) -> bool:
	for o in nd.nbrs:
		if str(nodes[o].state) == "controlled": return true
	return false


func _has_hidden_nbr(i: int) -> bool:
	for o in nodes[i].nbrs:
		if str(nodes[o].state) == "hidden": return true
	return false


func _broke(cost: Dictionary) -> bool:   # refuse an action you cannot pay for (and say so)
	if Econ.can_pay(cost): return false
	_flash("Not enough — this needs %s" % Econ.cost_text(cost)); _refresh()
	return true


# the Intel cost of a CAPTURE: the per-node re-hack surcharge × the empire-wide escalation (each node you
# already hold makes the next one dearer)
func _take_cost(nd: Dictionary) -> Dictionary:
	return {"intel": float(Econ.COST.take) * (1.0 + float(Econ.HEAT.rehack_cost_per_alarm) * float(nd.get("burned", 0))) * Econ.capture_scale()}


# a captured path from the entry (0) to node i over controlled nodes — the route a deployed tool travels
func _route_to(i: int) -> Array:
	if i == 0: return [0]
	var prev := {0: 0}; var q := [0]; var head := 0
	while head < q.size():
		var cur: int = q[head]; head += 1
		if cur == i: break
		for o in nodes[cur].nbrs:
			if str(nodes[o].state) == "controlled" and not prev.has(o): prev[o] = cur; q.append(o)
	if not prev.has(i): return [i]
	var path := [i]
	while path[path.size() - 1] != 0: path.append(prev[path[path.size() - 1]])
	path.reverse(); return path


# begin a timed action on a node; resolves instantly in tests or when dur <= 0
func _start(i: int, kind: String, dur: float, prog := "", boost := "") -> void:
	var nd: Dictionary = nodes[i]
	nd.task = kind; nd.t = 0.0; nd.dur = dur; nd.tprog = prog; nd.tboost = boost
	nd.troute = _route_to(i) if kind == "install" else []
	if kind in ["scan", "profile", "take"]:   # roll now; reveal success at the end, a failure interrupts midway
		nd.tsucc = roll.randf() <= clampf(_chance(nd) + (Econ.BOOST if boost != "" else 0.0), 0.0, 0.99)
		nd.tfail = -1.0 if bool(nd.tsucc) else roll.randf_range(0.25, 0.9) * dur
	elif kind == "install":   # delivery can be intercepted partway along the route
		nd.tsucc = instant_actions or roll.randf() >= float(Econ.TIME.install_fail_chance)
		nd.tfail = -1.0 if bool(nd.tsucc) else roll.randf_range(0.55, 0.95) * dur
	else:
		nd.tsucc = true; nd.tfail = -1.0
	if instant_actions or dur <= 0.0:
		_resolve(i)
	else:
		_save(); _refresh()


# advance every running task; resolve the ones that finish (called from _process)
func _advance_tasks(dt: float) -> bool:
	var any := false; var done := []
	for nd in nodes:
		if str(nd.task) == "": continue
		any = true; nd.t = float(nd.t) + dt
		var fails_now: bool = not bool(nd.tsucc) and float(nd.tfail) >= 0.0 and float(nd.t) >= float(nd.tfail)
		if fails_now or float(nd.t) >= float(nd.dur): done.append(int(nd.id))
	for i in done: _resolve(i)
	return any


func _resolve(i: int) -> void:
	var nd: Dictionary = nodes[i]
	var kind := str(nd.task)
	var succ := bool(nd.tsucc)
	nd.task = ""; nd.t = 0.0; nd.dur = 0.0; nd.tfail = -1.0
	match kind:
		"scan":
			if str(nd.state) != "controlled": _refresh(); return
			if succ:
				var found := 0
				for o in nd.nbrs:
					if str(nodes[o].state) == "hidden": nodes[o].state = "detected"; found += 1
				nd.enum_done = true
				_flash("✓  Network scan complete — no further connections" if found == 0 else "✓  Network scan OK — %d device%s detected" % [found, "" if found == 1 else "s"], OK_COL); _cue(i, "scanned")
			else: _flash("✕  Network scan failed — retry", BAD_COL); _cue(i, "failed")
		"profile":
			if str(nd.state) != "detected": _refresh(); return
			if succ:
				nd.profiled = true; _flash("✓  Profiled: %s — %s" % [str(nd.name), str(NODE[nd.type].name)], OK_COL); _cue(i, "profiled")
			else: _flash("✕  Endpoint scan failed — retry", BAD_COL); _cue(i, "failed")
		"take":
			if str(nd.state) != "detected" or not _reachable(nd): _refresh(); return
			var boost := str(nd.tboost)
			if succ:
				nd.state = "controlled"; _flash("✓  CAPTURED  %s — now scan it" % str(nd.name), OK_COL); _cue(i, "captured")
			else: _flash(("✕  Intrusion blocked — %s burned" % ("credential" if boost == "creds" else "exploit")) if boost != "" else "✕  Intrusion blocked — retry", BAD_COL); _cue(i, "failed")
		"install":
			var prog := str(nd.tprog)
			if str(nd.state) != "controlled" or (nd.progs as Array).size() >= int(nd.slots) or not Econ.PROGRAMS.has(prog):
				_flash("Install aborted"); _refresh(); return
			if not succ:
				_flash("✕  Delivery intercepted — %s lost" % str(Econ.PROGRAMS[prog].name), BAD_COL); _cue(i, "failed")
			else:
				nd.progs.append(prog); _flash("✓  Deployed %s — %s" % [str(Econ.PROGRAMS[prog].name), Econ.describe(prog)], OK_COL); _cue(i, "installed")
	_save(); _refresh()


# SCAN NETWORK from a controlled node: reveals its neighbours after a delay (can fail)
func _net_scan(i: int) -> void:
	var nd: Dictionary = nodes[i]
	if str(nd.state) != "controlled" or bool(nd.enum_done) or str(nd.task) != "": return
	var cost := _icost(float(Econ.COST.net_scan), nd)
	if _broke(cost): return
	Econ.pay(cost); _start(i, "scan", float(Econ.TIME.net_scan))


# SCAN ENDPOINT on a detected node: profiles it after a delay (unlocks capture)
func _profile(i: int) -> void:
	var nd: Dictionary = nodes[i]
	if str(nd.state) != "detected" or bool(nd.profiled) or str(nd.task) != "": return
	var cost := _icost(float(Econ.COST.profile), nd)
	if _broke(cost): return
	Econ.pay(cost); _start(i, "profile", float(Econ.TIME.profile))


# TAKE CONTROL of a profiled node (timed; can burn a credential/exploit). Cost escalates with your size.
func _take(i: int, boost := "") -> void:
	var nd: Dictionary = nodes[i]
	if str(nd.state) != "detected" or not bool(nd.profiled) or not _reachable(nd) or str(nd.task) != "": return
	if boost == "creds" and not LOGIN_TYPES.has(str(nd.type)): boost = ""
	if boost == "exploits" and not SOFTWARE_TYPES.has(str(nd.type)): boost = ""
	var cost := _take_cost(nd)
	if boost != "": cost[boost] = 1.0
	if _broke(cost): return
	Econ.pay(cost); _start(i, "take", float(Econ.TIME.take), "", boost)


# DEPLOY a tool: it is delivered from the city along your controlled route to the node, then installed
# (fast, small chance to fail). Cost is paid up front.
func _install(i: int, prog: String) -> void:
	var nd: Dictionary = nodes[i]
	if str(nd.state) != "controlled" or (nd.progs as Array).size() >= int(nd.slots) or str(nd.task) != "": return
	var p: Dictionary = Econ.PROGRAMS[prog]
	if not (NODE[nd.type].accepts as Array).has(str(p.cat)): return
	if _broke(p.cost): return
	Econ.pay(p.cost)
	var hops := maxi(1, _route_to(i).size() - 1)
	var dur := maxf(float(Econ.TIME.install_min), float(hops) * float(Econ.TIME.install_per_hop)) + float(Econ.TIME.install_finalise)
	_start(i, "install", dur, prog)


func _uninstall(i: int, slot: int) -> void:
	var nd: Dictionary = nodes[i]
	if slot >= 0 and slot < (nd.progs as Array).size(): nd.progs.remove_at(slot); _save(); _refresh()


func _cancel(i: int) -> void:
	nodes[i].task = ""; nodes[i].t = 0.0; nodes[i].dur = 0.0; _save(); _refresh()


func _flash(m: String, col := Color(0.6, 1.0, 1.0)) -> void:
	_msg = m; _msg_t = 2.8; _msg_col = col


const OK_COL := Color(0.35, 1.0, 0.55)
const BAD_COL := Color(1.0, 0.45, 0.4)
func _cue(i: int, kind: String) -> void:   # a burst on the node: "captured"/"scanned"/"profiled"/"installed"/"failed"
	nodes[i].fx_t = 1.8; nodes[i].fx_kind = kind


func _fitting(nd: Dictionary) -> Array:
	var out := []
	for pk in Econ.PROGRAMS:
		if (NODE[nd.type].accepts as Array).has(str(Econ.PROGRAMS[pk].cat)): out.append(pk)
	return out


# the data flow: every program's route (over controlled nodes) from its node back to the entry firewall
func _build_flows() -> void:
	_flows = []
	for nd in nodes:
		if str(nd.state) != "controlled" or (nd.progs as Array).is_empty() or nd.id == 0: continue
		var prev := {nd.id: nd.id}; var q := [nd.id]; var head := 0
		while head < q.size():
			var cur: int = q[head]; head += 1
			if cur == 0: break
			for o in nodes[cur].nbrs:
				if str(nodes[o].state) == "controlled" and not prev.has(o): prev[o] = cur; q.append(o)
		if not prev.has(0): continue
		var path := [0]
		while path[path.size() - 1] != nd.id: path.append(prev[path[path.size() - 1]])
		path.reverse()
		for pk in nd.progs:
			if Econ.PROGRAMS[pk].has("out"): _flows.append({"path": path, "res": str(Econ.PROGRAMS[pk].out)})


# ============================================================ UI (Stellaris-style frame of solid panels)
func _panel(layer: CanvasLayer, rect_cb: Callable, edges: Array) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = UI_BG; sb.border_color = UI_EDGE
	sb.border_width_top = 1 if edges.has("t") else 0; sb.border_width_bottom = 1 if edges.has("b") else 0
	sb.border_width_left = 1 if edges.has("l") else 0; sb.border_width_right = 1 if edges.has("r") else 0
	p.add_theme_stylebox_override("panel", sb)
	p.clip_contents = true   # nothing drawn inside a panel ever spills outside it
	rect_cb.call(p)
	layer.add_child(p)
	return p


func _lbl(parent: Node, size: int, col: Color, wrap := true) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", int(round(size * Settings.text_scale)))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)
	# LEFT bar: programs to deploy
	var left := _panel(layer, func(p): p.offset_top = TOP_H; p.anchor_bottom = 1.0; p.offset_bottom = 0; p.offset_right = LEFT_W, ["r"])
	var lv := VBoxContainer.new(); lv.set_anchors_preset(Control.PRESET_FULL_RECT)
	lv.offset_left = 10; lv.offset_top = 8; lv.offset_right = -10; lv.offset_bottom = -8
	lv.add_theme_constant_override("separation", 4); left.add_child(lv)
	var lt := _lbl(lv, 16, Color(0.2, 1.0, 0.9)); lt.text = "PROGRAMS TO DEPLOY"; lt.add_theme_font_override("font", Settings.font_bold)
	l_hint = _lbl(lv, 13, Color(0.6, 0.7, 0.8))
	var lsc := ScrollContainer.new(); lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lsc.size_flags_vertical = Control.SIZE_EXPAND_FILL; lv.add_child(lsc)   # the list scrolls, never overflows
	l_list = VBoxContainer.new(); l_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_list.add_theme_constant_override("separation", 4); lsc.add_child(l_list)
	# BOTTOM bar: selected node · its slots · its actions
	var bot := _panel(layer, func(p): p.offset_left = LEFT_W; p.anchor_right = 1.0; p.anchor_top = 1.0; p.anchor_bottom = 1.0; p.offset_top = -BOT_H; p.offset_bottom = 0, ["t"])
	var bh := HBoxContainer.new(); bh.set_anchors_preset(Control.PRESET_FULL_RECT)
	bh.offset_left = 12; bh.offset_top = 8; bh.offset_right = -276; bh.offset_bottom = -8
	bh.add_theme_constant_override("separation", 18); bot.add_child(bh)
	var c1 := VBoxContainer.new(); c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; c1.size_flags_stretch_ratio = 1.4; c1.custom_minimum_size = Vector2(300, 0); bh.add_child(c1)
	b_title = _lbl(c1, 19, Color(0.95, 1.0, 1.0), false); b_title.add_theme_font_override("font", Settings.font_bold)
	b_body = _lbl(c1, 14, Color(0.82, 0.9, 1.0))
	var c2 := VBoxContainer.new(); c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(c2)
	var st := _lbl(c2, 14, Color(0.6, 0.7, 0.8)); st.text = "SLOTS"
	b_slots = HBoxContainer.new(); b_slots.add_theme_constant_override("separation", 6); c2.add_child(b_slots)
	var c3 := VBoxContainer.new(); c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(c3)
	b_actions = VBoxContainer.new(); b_actions.add_theme_constant_override("separation", 4); c3.add_child(b_actions)
	# BACK TO CITY: big, solid, pinned to the bottom-right corner (outside the column layout)
	var back := Button.new(); back.text = "◂  BACK TO CITY"; back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", int(round(18 * Settings.text_scale)))
	back.add_theme_font_override("font", Settings.font_bold)
	back.anchor_left = 1.0; back.anchor_right = 1.0; back.anchor_top = 1.0; back.anchor_bottom = 1.0
	back.offset_left = -248; back.offset_right = -20; back.offset_top = -80; back.offset_bottom = -20
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/city.tscn"))
	layer.add_child(back)


func _refresh() -> void:
	_build_flows()
	if _fx != null: _fx.queue_redraw()
	queue_redraw()
	if b_title == null: return
	for c in b_actions.get_children(): c.queue_free()
	for c in b_slots.get_children(): c.queue_free()
	for c in l_list.get_children(): c.queue_free()
	var ctl := 0; var det := 0
	for nd in nodes:
		if str(nd.state) == "controlled": ctl += 1
		elif str(nd.state) == "detected": det += 1
	var nd: Dictionary = nodes[sel] if sel >= 0 and sel < nodes.size() else {}
	var owned: bool = not nd.is_empty() and str(nd.state) == "controlled"
	# LEFT: every program, enabled only when it fits a free slot of the selected controlled node
	l_hint.text = ("Deploy into %s" % str(nd.name)) if owned and int(nd.slots) > 0 else "Select a node you control to deploy programs into its slots."
	for pk in Econ.PROGRAMS:
		var p: Dictionary = Econ.PROGRAMS[pk]
		var fits: bool = owned and str(nd.get("task", "")) == "" and (NODE[nd.type].accepts as Array).has(str(p.cat)) and (nd.progs as Array).size() < int(nd.slots)
		var hosts := PackedStringArray()
		for t in NODE:
			if (NODE[t].accepts as Array).has(str(p.cat)): hosts.append(t)
		var cc: Color = Econ.cat_color(str(p.cat))
		var b := Button.new(); b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, 68)
		b.disabled = not fits
		b.tooltip_text = "%s\n%s · %s\nfits: %s" % [str(p.name), Econ.describe(pk), Econ.cost_text(p.cost), ", ".join(hosts)]
		if fits: b.pressed.connect(_install.bind(sel, pk))
		var mc := MarginContainer.new(); mc.set_anchors_preset(Control.PRESET_FULL_RECT); mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.add_theme_constant_override("margin_left", 8); mc.add_theme_constant_override("margin_right", 8)
		mc.add_theme_constant_override("margin_top", 6); mc.add_theme_constant_override("margin_bottom", 6)
		b.add_child(mc)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.add_child(row)
		var ic := ProgramIcon.new(Econ.prog_glyph(pk), (cc if fits else Color(cc.r, cc.g, cc.b, 0.4)), 42.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(ic)
		var tx := VBoxContainer.new(); tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tx.add_theme_constant_override("separation", 2); row.add_child(tx)
		var nm := _lbl(tx, 15, cc if fits else Color(0.5, 0.55, 0.62), false); nm.text = str(p.name); nm.add_theme_font_override("font", Settings.font_bold)
		var d2 := _lbl(tx, 12, Color(0.72, 0.8, 0.9) if fits else Color(0.45, 0.5, 0.58), false); d2.text = "%s  ·  %s" % [Econ.describe(pk), Econ.cost_text(p.cost)]
		var ht := _lbl(tx, 11, (Color(0.5, 0.9, 0.95) if str(p.cat) == "evade" else Color(1.0, 0.6, 0.4)) if fits else Color(0.4, 0.45, 0.52), false); ht.text = Econ.heat_text(pk)
		l_list.add_child(b)
	# BOTTOM: the selection
	if nd.is_empty():
		b_title.text = str(info.name)
		b_body.text = "%s · %d / %d nodes controlled · %d detected · %d programs running\nClick the edge firewall and SCAN NETWORK. SCAN a detected endpoint to profile it, TAKE CONTROL, then scan onward. Every action costs Intel." % [str(info.sec), ctl, nodes.size(), det, _programs_here()]
		return
	var nt: Dictionary = NODE[nd.type]
	var known: bool = bool(nd.profiled) or owned
	b_title.text = ("%s  —  %s" % [str(nd.name), str(nt.name)]) if known else "Unknown device"
	var body := "State: %s" % str(nd.state).to_upper()
	if known:
		if str(nd.owner) != "": body += "   ·   Owner: %s" % str(nd.owner)
		if str(nd.detail) != "": body += "\n%s" % str(nd.detail)
	else:
		body += "\nDetected on the network. Scan the endpoint to learn what it is."
	if owned:
		body += "\nConnections: %s" % ("mapped" if bool(nd.enum_done) else "not yet scanned")
		body += "\nHeat: %d%%%s" % [int(round(float(nd.get("heat", 0.0)))), ("  ⚠ at 50% it can alarm" if float(nd.heat) >= float(Econ.HEAT.warn_at) else "")]
	if int(nd.get("burned", 0)) > 0:
		body += "\nRe-secured ×%d  ·  +%d%% cost · −%d%% success" % [int(nd.burned), int(float(Econ.HEAT.rehack_cost_per_alarm) * 100.0 * float(nd.burned)), int(float(Econ.HEAT.rehack_chance_per_alarm) * 100.0 * float(nd.burned))]
	if nd.type != "fw" and not owned: body += "\nDifficulty: %d%% success" % int(round(_chance(nd) * 100.0))
	b_body.text = body
	# slots: one square button per slot; filled = program (click to remove), empty = pick from the left bar
	if owned and int(nd.slots) > 0:
		for s in int(nd.slots):
			var sb := Button.new(); sb.focus_mode = Control.FOCUS_NONE
			sb.custom_minimum_size = Vector2(48, 48)
			if s < (nd.progs as Array).size():
				var pk: String = nd.progs[s]
				var p: Dictionary = Econ.PROGRAMS[pk]
				sb.tooltip_text = "%s — %s\nclick to remove" % [str(p.name), Econ.describe(pk)]
				var ic := ProgramIcon.new(Econ.prog_glyph(pk), Econ.cat_color(str(p.cat)), 44.0)
				ic.set_anchors_preset(Control.PRESET_FULL_RECT); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sb.add_child(ic)
				sb.pressed.connect(_uninstall.bind(sel, s))
			elif str(nd.task) == "install" and s == (nd.progs as Array).size():
				var pk: String = str(nd.tprog)
				var frac := clampf(float(nd.t) / maxf(float(nd.dur), 0.001), 0.0, 1.0)
				sb.tooltip_text = "installing %s…  %d%%" % [str(Econ.PROGRAMS[pk].name) if Econ.PROGRAMS.has(pk) else "tool", int(round(frac * 100.0))]
				var ic := ProgramIcon.new(Econ.prog_glyph(pk), Econ.cat_color(str(Econ.PROGRAMS[pk].cat)) if Econ.PROGRAMS.has(pk) else Color(0.6, 1, 1), 44.0)
				ic.set_anchors_preset(Control.PRESET_FULL_RECT); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sb.add_child(ic)
				var dim := ColorRect.new(); dim.color = Color(0.05, 0.06, 0.09, 0.8); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
				dim.anchor_left = 0.0; dim.anchor_right = 1.0; dim.anchor_top = 0.0; dim.anchor_bottom = 0.0
				dim.offset_top = 0.0; dim.offset_bottom = (1.0 - frac) * 48.0   # covers the un-installed top portion
				sb.add_child(dim)
				var scan := ColorRect.new(); scan.color = Color(0.7, 1.0, 1.0, 0.9); scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
				scan.anchor_left = 0.0; scan.anchor_right = 1.0; scan.anchor_top = 0.0; scan.anchor_bottom = 0.0
				scan.offset_top = (1.0 - frac) * 48.0 - 1.0; scan.offset_bottom = (1.0 - frac) * 48.0 + 1.0
				sb.add_child(scan)
			else:
				sb.text = "+"; sb.tooltip_text = "empty slot (%s)" % ", ".join(nt.accepts)
				sb.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
			b_slots.add_child(sb)
		var cap := _lbl(b_slots, 13, Color(0.6, 0.7, 0.8), false); cap.text = "  %d / %d  ·  takes %s" % [(nd.progs as Array).size(), int(nd.slots), ", ".join(nt.accepts)]
	elif owned:
		var none := _lbl(b_slots, 13, Color(0.5, 0.6, 0.7), false); none.text = "no slots on a firewall"
	# actions — or the in-progress readout while a timed task runs on this node
	if str(nd.task) != "":
		var pct := int(round(clampf(float(nd.t) / maxf(float(nd.dur), 0.001), 0.0, 1.0) * 100.0))
		var names := {"scan": "Scanning network", "profile": "Scanning endpoint", "take": "Breaking in", "install": "Deploying %s" % (str(Econ.PROGRAMS[nd.tprog].name) if Econ.PROGRAMS.has(str(nd.tprog)) else "tool")}
		var pl := _lbl(b_actions, 16, _kcol(), false); pl.text = "⏳ %s…  %d%%" % [str(names.get(str(nd.task), "Working")), pct]
		_action("✕  Cancel", _cancel.bind(sel), Color(0.9, 0.5, 0.5))
		return
	match str(nd.state):
		"controlled":
			if not bool(nd.enum_done): _action("⌕  Scan network  (S) · %d ◈" % int(round(_icost(float(Econ.COST.net_scan), nd).intel)), _net_scan.bind(sel))
			else:
				var done := _lbl(b_actions, 14, Color(0.5, 0.85, 0.6)); done.text = "✓ All connections mapped"
		"detected":
			if not bool(nd.profiled):
				_action("⌕  Scan endpoint  (S) · %d ◈" % int(round(_icost(float(Econ.COST.profile), nd).intel)), _profile.bind(sel))
			elif _reachable(nd):
				_action("⚷  Take control  (C) · %d ◈ · %d%%" % [int(round(_take_cost(nd).intel)), int(round(_chance(nd) * 100.0))], _take.bind(sel), _kcol())
				var boosted := int(round(clampf(_chance(nd) + Econ.BOOST, 0.0, 0.99) * 100.0))
				if LOGIN_TYPES.has(str(nd.type)) and float(Econ.stock.creds) >= 1.0:
					_action("⚿  …burning a credential · %d%%" % boosted, _take.bind(sel, "creds"), Econ.color("creds"))
				if SOFTWARE_TYPES.has(str(nd.type)) and float(Econ.stock.exploits) >= 1.0:
					_action("⚡  …burning an exploit · %d%%" % boosted, _take.bind(sel, "exploits"), Econ.color("exploits"))
			else:
				var far := _lbl(b_actions, 14, Color(0.6, 0.7, 0.8)); far.text = "Reach it through a controlled neighbour first."


func _programs_here() -> int:
	var n := 0
	for nd in nodes: n += (nd.progs as Array).size()
	return n


func _action(txt: String, cb: Callable, col := Color(0.3, 1.0, 0.9)) -> void:
	var b := Button.new(); b.text = txt; b.focus_mode = Control.FOCUS_NONE; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", int(round(14 * Settings.text_scale)))
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(cb); b_actions.add_child(b)


# ============================================================ FRAMING / INPUT
func _map_rect() -> Rect2:   # the screen area the map occupies inside the UI frame
	var vp := Vector2(get_viewport().get_visible_rect().size)
	return Rect2(LEFT_W, TOP_H, vp.x - LEFT_W, vp.y - TOP_H - BOT_H)


func _frame() -> void:
	var mr := _map_rect()
	var vp := Vector2(get_viewport().get_visible_rect().size)
	var fit: float = minf((mr.size.x - 60.0) / maxf(_shell.size.x, 1.0), (mr.size.y - 50.0) / maxf(_shell.size.y, 1.0))
	camera.zoom = Vector2.ONE * clampf(fit, 0.3, 1.6)
	camera.position = _shell.get_center() - (mr.get_center() - vp * 0.5) / camera.zoom.x   # shell centred in the map area


func _process(dt: float) -> void:
	_time += dt
	if _msg_t > 0.0: _msg_t -= dt
	# the global Econ tick advances and resolves tasks (so they keep running even on the city map); here we
	# just decay fx, mirror what Econ wrote back into our live nodes, and pace the panel while a task runs
	for nd in nodes:
		if float(nd.fx_t) > 0.0: nd.fx_t = maxf(0.0, float(nd.fx_t) - dt)
	_sync_from_global()
	var busy := false
	for nd in nodes:
		if str(nd.task) != "": busy = true; break
	if busy:
		_task_acc += dt
		if _task_acc >= 0.15: _task_acc = 0.0; _refresh()   # live progress in the panel
	if _fx != null: _fx.queue_redraw()


# pull heat/state the global Econ tick wrote into Session.interior back into our live nodes; an alarm
# (a node dropped from controlled → detected) shows a message and refreshes the panel
func _sync_from_global() -> void:
	var recs = Session.interior.get(_keystr(), null)
	if not (recs is Array) or recs.size() != nodes.size(): return
	var dirty := false
	for i in nodes.size():
		var r: Dictionary = recs[i]
		nodes[i].heat = float(r.get("heat", 0.0)); nodes[i].burned = int(r.get("burned", 0))
		nodes[i].t = float(r.get("t", 0.0)); nodes[i].dur = float(r.get("dur", 0.0))
		var was_ctl := str(nodes[i].state) == "controlled"
		if str(nodes[i].state) != str(r.state) or (nodes[i].progs as Array).size() != (r.get("progs", []) as Array).size() or str(nodes[i].task) != str(r.get("task", "")):
			nodes[i].state = str(r.state); nodes[i].progs = (r.get("progs", []) as Array).duplicate()
			nodes[i].profiled = bool(r.get("profiled", nodes[i].profiled)); nodes[i].enum_done = bool(r.get("enum_done", nodes[i].enum_done))
			nodes[i].task = str(r.get("task", "")); nodes[i].tprog = str(r.get("tprog", ""))
			dirty = true
		var res = r.get("result", null)
		if res != null:
			r.erase("result"); _show_result(i, res); dirty = true
		elif was_ctl and str(r.state) != "controlled":   # an alarm dropped this node while we weren't resolving it
			_flash(Econ.alarm_msg, BAD_COL); _cue(i, "failed"); dirty = true
	if dirty: _refresh()


# turn a finished task's result (written by Econ, live or while away) into the on-node cue + toast
func _show_result(i: int, res: Dictionary) -> void:
	var kind := str(res.get("kind", "")); var ok := bool(res.get("ok", false))
	if ok:
		match kind:
			"scan":
				var found := int(res.get("found", 0))
				_flash("✓  Network scan complete — no further connections" if found == 0 else "✓  Network scan OK — %d device%s detected" % [found, "" if found == 1 else "s"], OK_COL); _cue(i, "scanned")
			"profile": _flash("✓  Profiled: %s — %s" % [str(nodes[i].name), str(NODE[nodes[i].type].name)], OK_COL); _cue(i, "profiled")
			"take": _flash("✓  CAPTURED  %s — now scan it" % str(nodes[i].name), OK_COL); _cue(i, "captured")
			"install":
				var pk := str(res.get("prog", ""))
				_flash("✓  Deployed %s" % (str(Econ.PROGRAMS[pk].name) if Econ.PROGRAMS.has(pk) else "tool"), OK_COL); _cue(i, "installed")
	else:
		match kind:
			"scan": _flash("✕  Network scan failed — retry", BAD_COL)
			"profile": _flash("✕  Endpoint scan failed — retry", BAD_COL)
			"take": _flash("✕  Intrusion blocked — retry", BAD_COL)
			"install":
				var pk := str(res.get("prog", ""))
				_flash("✕  Delivery intercepted — %s lost" % (str(Econ.PROGRAMS[pk].name) if Econ.PROGRAMS.has(pk) else "tool"), BAD_COL)
		_cue(i, "failed")


func _node_at(wpos: Vector2) -> int:
	var best := -1; var bd := 30.0
	for nd in nodes:
		if str(nd.state) == "hidden": continue
		var d: float = wpos.distance_to(nd.pos)
		if d < bd: bd = d; best = nd.id
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.3, 0.3), Vector2(3.5, 3.5))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.3, 0.3), Vector2(3.5, 3.5))
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_down = true; _lmb_moved = false
			else:
				if _lmb_down and not _lmb_moved:
					sel = _node_at(get_global_mouse_position()); _refresh()
				_lmb_down = false
	elif event is InputEventMouseMotion:
		if _panning or (_lmb_down and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
			if event.relative.length() > 3.0: _lmb_moved = true
			if _panning or _lmb_moved: camera.position -= event.relative / camera.zoom.x


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/city.tscn")
		elif event.keycode == KEY_S and sel >= 0:   # S = whichever scan applies to the selected node
			if str(nodes[sel].state) == "controlled": _net_scan(sel)
			elif str(nodes[sel].state) == "detected": _profile(sel)
		elif event.keycode == KEY_C and sel >= 0 and str(nodes[sel].state) == "detected":
			_take(sel)


# ============================================================ RENDERING
func _draw() -> void:
	var px := 1.0 / camera.zoom.x
	var kc := _kcol()
	# the building's NETWORK PLAN: shell, zone bands, rooms, labels — a blueprint behind the constellation
	draw_rect(_shell, Color(kc.r, kc.g, kc.b, 0.035), true)
	draw_rect(_shell, Color(kc.r, kc.g, kc.b, 0.35), false, 2.0 * px, true)
	for corner in [_shell.position, Vector2(_shell.end.x, _shell.position.y), _shell.end, Vector2(_shell.position.x, _shell.end.y)]:
		var dx := (-1.0 if corner.x > _shell.get_center().x else 1.0) * 14.0; var dy := (-1.0 if corner.y > _shell.get_center().y else 1.0) * 14.0
		draw_line(corner, corner + Vector2(dx, 0), Color(kc.r, kc.g, kc.b, 0.9), 2.5 * px, true)
		draw_line(corner, corner + Vector2(0, dy), Color(kc.r, kc.g, kc.b, 0.9), 2.5 * px, true)
	var gridc := Color(kc.r, kc.g, kc.b, 0.06)
	var x: float = _shell.position.x
	while x < _shell.end.x: draw_line(Vector2(x, _shell.position.y), Vector2(x, _shell.end.y), gridc, px, true); x += 40.0
	var y: float = _shell.position.y
	while y < _shell.end.y: draw_line(Vector2(_shell.position.x, y), Vector2(_shell.end.x, y), gridc, px, true); y += 40.0
	var f := Settings.font
	for i in _bands.size():
		var b: Dictionary = _bands[i]; var r: Rect2 = b.rect
		var zc := kc.lerp([Color(0.5, 1.0, 0.7), Color(0.6, 0.8, 1.0), Color(1.0, 0.5, 0.6)][mini(i, 2)], 0.6)
		draw_rect(r, Color(zc.r, zc.g, zc.b, 0.05 + 0.03 * float(i)), true)
		if i > 0: _dashed(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Color(zc.r, zc.g, zc.b, 0.45), 1.5 * px, 10.0)
		draw_string(f, r.position + Vector2(10, 22), str(b.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(zc.r, zc.g, zc.b, 0.75))
	for rr in _rooms:
		draw_rect(rr, Color(kc.r, kc.g, kc.b, 0.03), true)
		draw_rect(rr, Color(kc.r, kc.g, kc.b, 0.16), false, px, true)
	draw_string(f, _shell.position + Vector2(10, -8), "%s  ·  NETWORK PLAN" % str(info.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(kc.r, kc.g, kc.b, 0.8))
	# the city uplink entering the building at the firewall
	var e0: Vector2 = nodes[0].pos
	_dashed(Vector2(_shell.position.x - 60.0, e0.y), e0 - Vector2(NODE.fw.r + 4.0, 0), Color(0.9, 1.0, 1.0, 0.7), 2.0 * px, 8.0)
	draw_string(f, Vector2(_shell.position.x - 60.0, e0.y - 8.0), "CITY ⇢", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 1.0, 1.0, 0.7))
	# edges between any two non-hidden nodes (dim toward a node you only detected)
	for nd in nodes:
		if str(nd.state) == "hidden": continue
		for o in nd.nbrs:
			if o <= nd.id or str(nodes[o].state) == "hidden": continue
			var both: bool = str(nd.state) == "controlled" and str(nodes[o].state) == "controlled"
			var col := kc; col.a = 0.7 if both else 0.35
			draw_line(nd.pos, nodes[o].pos, col, (2.0 if both else 1.4) * px, true)
	for nd in nodes:
		if str(nd.state) != "hidden": _draw_node(nd, px)


func _dashed(a: Vector2, b: Vector2, col: Color, w: float, seg: float) -> void:
	var L := a.distance_to(b)
	if L < 0.5: return
	var d := (b - a) / L
	var t := 0.0
	while t < L:
		draw_line(a + d * t, a + d * minf(t + seg * 0.55, L), col, w, true)
		t += seg


# a type-specific glyph (database cylinder, monitor, globe, chip, document, shield, core), stroked in the
# type's accent over a dark disc; unknown (detected, not yet profiled) devices are a dashed "?" blip
func _draw_icon(t: String, p: Vector2, r: float, col: Color, px: float, known: bool) -> void:
	var w := 1.5 * px
	draw_circle(p, r, Color(0.05, 0.07, 0.11, 0.96), true, -1.0, true)
	if not known:
		for i in 10: draw_arc(p, r * 0.62, float(i) / 10.0 * TAU, (float(i) + 0.55) / 10.0 * TAU, 4, Color(0.75, 0.8, 0.9, 0.7), w, true)
		draw_string(Settings.font, p + Vector2(-4.5, 5.5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.9, 1.0, 0.9))
		return
	match t:
		"fw":   # shield with bars
			var s := r * 0.72
			var pts := PackedVector2Array([p + Vector2(-s, -s * 0.9), p + Vector2(s, -s * 0.9), p + Vector2(s, s * 0.15), p + Vector2(0, s), p + Vector2(-s, s * 0.15)])
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.18)); draw_polyline(pts + PackedVector2Array([pts[0]]), col, w, true)
			draw_line(p + Vector2(-s * 0.6, -s * 0.3), p + Vector2(s * 0.6, -s * 0.3), col, w, true)
			draw_line(p + Vector2(-s * 0.55, s * 0.15), p + Vector2(s * 0.55, s * 0.15), col, w, true)
		"iot":  # chip with pins
			var s := r * 0.5
			draw_rect(Rect2(p - Vector2(s, s), Vector2(2 * s, 2 * s)), Color(col.r, col.g, col.b, 0.18), true)
			draw_rect(Rect2(p - Vector2(s, s), Vector2(2 * s, 2 * s)), col, false, w, true)
			for k in 3:
				var o := (float(k) - 1.0) * s * 0.6
				draw_line(p + Vector2(o, -s), p + Vector2(o, -s - r * 0.3), col, w, true); draw_line(p + Vector2(o, s), p + Vector2(o, s + r * 0.3), col, w, true)
				draw_line(p + Vector2(-s, o), p + Vector2(-s - r * 0.3, o), col, w, true); draw_line(p + Vector2(s, o), p + Vector2(s + r * 0.3, o), col, w, true)
			draw_rect(Rect2(p - Vector2(s * 0.4, s * 0.4), Vector2(s * 0.8, s * 0.8)), col, false, w, true)
		"web":  # globe
			var s := r * 0.7
			draw_arc(p, s, 0, TAU, 32, col, w, true)
			draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), col, w, true)
			draw_polyline(_ell(p, s * 0.45, s, 0.0, TAU, 24), col, w, true)
			draw_polyline(_ell(p + Vector2(0, -s * 0.5), s * 0.85, s * 0.18, PI, TAU, 12), col, w, true)
			draw_polyline(_ell(p + Vector2(0, s * 0.5), s * 0.85, s * 0.18, 0.0, PI, 12), col, w, true)
		"file": # document with folded corner + lines
			var hw := r * 0.5; var hh := r * 0.68; var fc := r * 0.28
			var pts := PackedVector2Array([p + Vector2(-hw, -hh), p + Vector2(hw - fc, -hh), p + Vector2(hw, -hh + fc), p + Vector2(hw, hh), p + Vector2(-hw, hh)])
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.14)); draw_polyline(pts + PackedVector2Array([pts[0]]), col, w, true)
			draw_polyline(PackedVector2Array([p + Vector2(hw - fc, -hh), p + Vector2(hw - fc, -hh + fc), p + Vector2(hw, -hh + fc)]), col, w, true)
			for k in 3: draw_line(p + Vector2(-hw * 0.6, -hh * 0.2 + float(k) * hh * 0.4), p + Vector2(hw * 0.6, -hh * 0.2 + float(k) * hh * 0.4), col, w, true)
		"db":   # cylinder
			var rx := r * 0.62; var ry := r * 0.22; var hh := r * 0.5
			draw_colored_polygon(PackedVector2Array([p + Vector2(-rx, -hh), p + Vector2(rx, -hh), p + Vector2(rx, hh), p + Vector2(-rx, hh)]), Color(col.r, col.g, col.b, 0.14))
			draw_polyline(_ell(p + Vector2(0, -hh), rx, ry, 0.0, TAU, 24), col, w, true)
			draw_line(p + Vector2(-rx, -hh), p + Vector2(-rx, hh), col, w, true); draw_line(p + Vector2(rx, -hh), p + Vector2(rx, hh), col, w, true)
			draw_polyline(_ell(p + Vector2(0, hh), rx, ry, 0.0, PI, 14), col, w, true)
			draw_polyline(_ell(p, rx, ry, 0.0, PI, 14), col, w, true)
		"pc":   # monitor on a stand
			var hw := r * 0.72; var hh := r * 0.48
			draw_rect(Rect2(p + Vector2(-hw, -hh - r * 0.15), Vector2(2 * hw, 2 * hh)), Color(col.r, col.g, col.b, 0.16), true)
			draw_rect(Rect2(p + Vector2(-hw, -hh - r * 0.15), Vector2(2 * hw, 2 * hh)), col, false, w, true)
			draw_line(p + Vector2(0, hh - r * 0.15), p + Vector2(0, hh + r * 0.2), col, w, true)
			draw_line(p + Vector2(-r * 0.35, hh + r * 0.2), p + Vector2(r * 0.35, hh + r * 0.2), col, w, true)
			draw_line(p + Vector2(-hw * 0.6, -hh * 0.2 - r * 0.15), p + Vector2(hw * 0.2, -hh * 0.2 - r * 0.15), Color(col.r, col.g, col.b, 0.6), w, true)
		"core": # octagonal core with rings
			var s := r * 0.78
			var pts := PackedVector2Array()
			for k in 8: pts.append(p + Vector2(cos(float(k) / 8.0 * TAU + PI / 8.0), sin(float(k) / 8.0 * TAU + PI / 8.0)) * s)
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.16)); draw_polyline(pts + PackedVector2Array([pts[0]]), col, w, true)
			draw_arc(p, s * 0.55, 0, TAU, 24, col, w, true); draw_arc(p, s * 0.28, 0, TAU, 16, col, w, true)
			draw_circle(p, 2.5 * px, col, true, -1.0, true)
			for k in 4: draw_line(p + Vector2(cos(float(k) * PI / 2.0), sin(float(k) * PI / 2.0)) * s * 0.55, p + Vector2(cos(float(k) * PI / 2.0), sin(float(k) * PI / 2.0)) * s, col, w, true)
		_:
			draw_string(Settings.font, p + Vector2(-5, 5), t.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


func _ell(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw_node(nd: Dictionary, px: float) -> void:
	var nt: Dictionary = NODE[nd.type]
	var rad: float = float(nt.r)
	var accent: Color = nt.col
	var controlled := str(nd.state) == "controlled"
	var known: bool = controlled or bool(nd.profiled)
	var ring := accent if controlled else (accent.darkened(0.3) if known else Color(0.6, 0.65, 0.75))
	var actionable: bool = (controlled and not bool(nd.enum_done)) or (str(nd.state) == "detected" and (not bool(nd.profiled) or _reachable(nd)))
	var pulse := (0.5 + 0.5 * sin(_time * 4.0)) if actionable else 1.0
	if nd.id == sel: draw_circle(nd.pos, rad + 8.0 * px, Color(1, 1, 1, 0.12), true, -1.0, true)
	_draw_icon(str(nd.type), nd.pos, rad, accent if known else Color(0.7, 0.75, 0.85), px, known)
	draw_arc(nd.pos, rad, 0.0, TAU, 32, Color(ring.r, ring.g, ring.b, 0.45 + 0.55 * pulse), (2.6 if controlled else 1.5) * px, true)
	if known and not controlled:   # a padlock tick for a profiled-but-not-owned node
		draw_arc(nd.pos, rad + 4.5 * px, -0.5, 0.5, 6, Color(1, 0.6, 0.4, 0.75), 1.5 * px, true)
	if str(nd.task) != "":   # a timed action is running on this node: a cyan progress ring
		var pf := clampf(float(nd.t) / maxf(float(nd.dur), 0.001), 0.0, 1.0)
		draw_arc(nd.pos, rad + 5.0 * px, -PI / 2.0, -PI / 2.0 + TAU * pf, 30, Color(0.4, 0.95, 1.0, 0.95), 3.0 * px, true)
	var heat: float = float(nd.get("heat", 0.0))
	if controlled:   # ALWAYS-VISIBLE heat bar under the node, so you can read trouble at a glance
		var hf := clampf(heat / float(Econ.HEAT.max), 0.0, 1.0)
		var bw := rad * 1.9; var bh := 4.0 * px
		var bx: float = nd.pos.x - bw * 0.5; var by: float = nd.pos.y + rad + 4.0 * px
		draw_rect(Rect2(bx, by, bw, bh), Color(0.1, 0.12, 0.16, 0.95), true)
		var hc := Color(0.35, 0.9, 0.5) if heat < float(Econ.HEAT.warn_at) else (Color(1.0, 0.7, 0.25) if heat < 80.0 else Color(1.0, 0.3, 0.3))
		if heat >= float(Econ.HEAT.warn_at): hc.a = 0.65 + 0.35 * sin(_time * 6.0)
		if hf > 0.0: draw_rect(Rect2(bx, by, bw * hf, bh), hc, true)
		draw_rect(Rect2(bx, by, bw, bh), Color(hc.r, hc.g, hc.b, 0.6), false, 1.0, true)
		if camera.zoom.x > 0.65 and heat >= 1.0:
			draw_string(Settings.font, Vector2(bx + bw + 4.0 * px, by + bh), "%d%%" % int(round(heat)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(hc.r, hc.g, hc.b, 0.95))
	if controlled and bool(nd.enum_done):   # a small check mark: this node's connections are fully mapped
		var c: Vector2 = nd.pos + Vector2(rad * 0.8, -rad * 0.8)
		draw_circle(c, 5.0 * px, Color(0.2, 0.8, 0.5, 0.95), true, -1.0, true)
		draw_polyline(PackedVector2Array([c + Vector2(-2.5, 0) * px, c + Vector2(-0.5, 2.2) * px, c + Vector2(3, -2.2) * px]), Color(0.05, 0.1, 0.08), 1.6 * px, true)
	var f := Settings.font
	# slots as small squares under the node (the at-a-glance view; the bottom bar has the real controls)
	var sc := int(nd.slots)
	if sc > 0 and controlled:
		var sw := 13.0; var gap := 3.0
		var total := float(sc) * sw + float(sc - 1) * gap
		var sx: float = nd.pos.x - total * 0.5
		var sy: float = nd.pos.y + rad + 14.0   # below the heat bar
		for s in sc:
			var rct := Rect2(sx + float(s) * (sw + gap), sy, sw, sw)
			var ctr := rct.get_center()
			if s < (nd.progs as Array).size():
				var pk: String = nd.progs[s]
				draw_rect(rct, Color(0.05, 0.07, 0.11, 0.92), true)
				ProgramIcon.paint(self, Econ.prog_glyph(pk), ctr, sw * 0.42, Econ.cat_color(str(Econ.PROGRAMS[pk].cat)))
			elif str(nd.task) == "install" and s == (nd.progs as Array).size():
				var pk: String = str(nd.tprog)
				var frac := clampf(float(nd.t) / maxf(float(nd.dur), 0.001), 0.0, 1.0)
				draw_rect(rct, Color(0.05, 0.07, 0.11, 0.92), true)
				ProgramIcon.paint(self, Econ.prog_glyph(pk), ctr, sw * 0.42, Econ.cat_color(str(Econ.PROGRAMS[pk].cat)) if Econ.PROGRAMS.has(pk) else Color(0.6, 1, 1))
				var cover := (1.0 - frac) * sw
				if cover > 0.0: draw_rect(Rect2(rct.position.x, rct.position.y, sw, cover), Color(0.07, 0.09, 0.13, 0.78), true)   # un-installed top dims to grey
				draw_line(Vector2(rct.position.x, rct.position.y + cover), Vector2(rct.position.x + sw, rct.position.y + cover), Color(0.7, 1.0, 1.0, 0.9), 1.0, true)
			else:
				draw_rect(rct, Color(0.13, 0.15, 0.2, 0.85), true)
				draw_rect(rct, Color(accent.r, accent.g, accent.b, 0.4), false, 1.0, true)
	if known and camera.zoom.x > 0.45:   # centred name with a backing pill; unknown nodes stay unlabelled
		var nm := str(nd.name)
		var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var np: Vector2 = nd.pos + Vector2(-tw * 0.5, -rad - 11.0)
		draw_rect(Rect2(np.x - 5.0, np.y - 12.0, tw + 10.0, 16.0), Color(0.05, 0.06, 0.09, 0.78), true)
		draw_string(f, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.93, 1.0, 0.96))


# the animated overlay: each program's output as a resource-coloured packet travelling its route back to
# the entry (the only data flow — it shows what you actually own), plus the status toast over the map
func _draw_fx(c: CanvasItem) -> void:
	var px := 1.0 / camera.zoom.x
	for nd in nodes:   # a tool being delivered from the city along your route to the node
		if str(nd.task) != "install": continue
		var route: Array = nd.troute
		if route.size() < 2: continue
		var travel := maxf(float(nd.dur) - float(Econ.TIME.install_finalise), 0.001)
		var f := clampf(float(nd.t) / travel, 0.0, 1.0) * float(route.size() - 1)
		var seg := mini(int(floor(f)), route.size() - 2)
		var a: Vector2 = nodes[route[seg]].pos; var b: Vector2 = nodes[route[seg + 1]].pos
		var pp := a.lerp(b, f - float(seg))
		var col := Econ.cat_color(str(Econ.PROGRAMS[str(nd.tprog)].cat)) if Econ.PROGRAMS.has(str(nd.tprog)) else Color(0.6, 1.0, 1.0)
		c.draw_circle(pp, 11.0 * px, Color(col.r, col.g, col.b, 0.25), true, -1.0, true)   # glow
		ProgramIcon.paint(c, Econ.prog_glyph(str(nd.tprog)), pp, 8.0 * px, col)
	if not Settings.reduced_motion:
		for i in _flows.size():
			var fl: Dictionary = _flows[i]
			var path: Array = fl.path
			if path.size() < 2: continue
			var col: Color = Econ.color(str(fl.res))
			var L := float(path.size() - 1)
			var t := fmod(_time * 0.45 + float(i * 7 % 11) / 11.0, 1.0) * L
			var seg := mini(int(floor(t)), path.size() - 2)
			var a: Vector2 = nodes[path[seg]].pos; var b: Vector2 = nodes[path[seg + 1]].pos
			var p := a.lerp(b, t - float(seg))
			c.draw_circle(p, 5.0 * px, Color(col.r, col.g, col.b, 0.35), true, -1.0, true)
			c.draw_circle(p, 2.8 * px, col, true, -1.0, true)
	if _msg_t > 0.0:
		var mr := _map_rect(); var vp := Vector2(get_viewport().get_visible_rect().size)
		var p := camera.position + (Vector2(mr.get_center().x, mr.end.y - 22.0) - vp * 0.5) / camera.zoom.x   # just above the bottom bar
		var mc := _msg_col; mc.a = clampf(_msg_t, 0.0, 1.0)
		var bgw := Settings.font_bold.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 / camera.zoom.x)).x
		c.draw_rect(Rect2(p.x - bgw * 0.5 - 12.0 * px, p.y - 15.0 * px, bgw + 24.0 * px, 26.0 * px), Color(0.04, 0.05, 0.08, 0.8 * clampf(_msg_t, 0.0, 1.0)), true)
		c.draw_string(Settings.font_bold, p - Vector2(bgw * 0.5, -5.0 * px), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 / camera.zoom.x), mc)
	for nd in nodes:   # per-node outcome cue: an expanding ring + a floating ✓/✕ label
		if float(nd.fx_t) <= 0.0: continue
		var life := clampf(float(nd.fx_t) / 1.8, 0.0, 1.0)   # 1 → 0
		var k := str(nd.fx_kind)
		var ok := k != "failed"
		var fc: Color = OK_COL if ok else BAD_COL
		var nr: float = float(NODE[nd.type].r)
		c.draw_arc(nd.pos, nr + (1.0 - life) * 26.0 * px, 0.0, TAU, 36, Color(fc.r, fc.g, fc.b, life), 3.5 * px, true)
		if ok: c.draw_arc(nd.pos, nr + 2.0 * px, 0.0, TAU, 36, Color(fc.r, fc.g, fc.b, 0.7 * life), 2.5 * px, true)
		var txt: String = {"captured": "✓ CAPTURED", "scanned": "✓ SCANNED", "profiled": "✓ PROFILED", "installed": "✓ INSTALLED", "failed": "✕ FAILED"}.get(k, "")
		if txt != "":
			var tw := Settings.font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var tp: Vector2 = nd.pos + Vector2(-tw * 0.5, -nr - 18.0 - (1.0 - life) * 16.0)
			c.draw_rect(Rect2(tp.x - 5.0, tp.y - 12.0, tw + 10.0, 16.0), Color(0.04, 0.05, 0.08, 0.8 * life), true)
			c.draw_string(Settings.font_bold, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(fc.r, fc.g, fc.b, 0.4 + 0.6 * life))


# One distinct glyph per program, drawn into ANY CanvasItem so the left list, the bottom slot buttons and
# the on-map slots all show the same picture. A faint category-coloured disc sits behind every glyph, so
# the family (intel / credentials / crypto / ops) still reads at a glance and the glyph says which one.
class ProgramIcon extends Control:
	var gid: String
	var col: Color
	func _init(g: String, c: Color, px_size: float) -> void:
		gid = g; col = c; custom_minimum_size = Vector2(px_size, px_size); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		paint(self, gid, size * 0.5, minf(size.x, size.y) * 0.42, col)

	static func paint(ci: CanvasItem, gid: String, c: Vector2, r: float, col: Color) -> void:
		var w := maxf(r * 0.15, 1.0)
		var hi := col.lerp(Color.WHITE, 0.28)
		ci.draw_circle(c, r * 1.18, Color(col.r, col.g, col.b, 0.15), true, -1.0, true)
		match gid:
			"scraper":   # spider's web — radial threads + rings
				for i in 6:
					var a := float(i) / 6.0 * TAU
					ci.draw_line(c, c + Vector2(cos(a), sin(a)) * r, hi, w, true)
				ci.draw_arc(c, r * 0.42, 0, TAU, 20, hi, w, true)
				ci.draw_arc(c, r * 0.78, 0, TAU, 26, hi, w, true)
			"phish":     # fish-hook over bait
				ci.draw_line(c + Vector2(r * 0.2, -r * 0.95), c + Vector2(r * 0.2, r * 0.25), hi, w, true)
				ci.draw_arc(c + Vector2(-r * 0.05, r * 0.25), r * 0.28, 0.0, PI, 16, hi, w, true)
				ci.draw_line(c + Vector2(r * 0.2, -r * 0.95), c + Vector2(-r * 0.05, -r * 0.6), hi, w, true)
				ci.draw_circle(c + Vector2(-r * 0.55, r * 0.35), r * 0.13, hi, true, -1.0, true)
			"sniffer":   # intercepted envelope + lens
				var e := r * 0.72
				var p0 := c + Vector2(-e, -e * 0.62); var p1 := c + Vector2(e, -e * 0.62)
				var p2 := c + Vector2(e, e * 0.62); var p3 := c + Vector2(-e, e * 0.62)
				ci.draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), hi, w, true)
				ci.draw_polyline(PackedVector2Array([p0, c + Vector2(0, 0), p1]), hi, w, true)
				ci.draw_arc(c + Vector2(e * 0.55, e * 0.5), r * 0.26, 0, TAU, 14, hi, w, true)
			"keylog":    # a key (keystrokes)
				ci.draw_arc(c + Vector2(-r * 0.45, 0), r * 0.34, 0, TAU, 18, hi, w, true)
				ci.draw_line(c + Vector2(-r * 0.12, 0), c + Vector2(r * 0.85, 0), hi, w, true)
				ci.draw_line(c + Vector2(r * 0.55, 0), c + Vector2(r * 0.55, r * 0.32), hi, w, true)
				ci.draw_line(c + Vector2(r * 0.85, 0), c + Vector2(r * 0.85, r * 0.4), hi, w, true)
			"dumper":    # a dump: arrow into a tray
				ci.draw_line(c + Vector2(0, -r * 0.9), c + Vector2(0, r * 0.15), hi, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.3, -r * 0.15), c + Vector2(0, r * 0.15), c + Vector2(r * 0.3, -r * 0.15)]), hi, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.35), c + Vector2(-r * 0.6, r * 0.75), c + Vector2(r * 0.6, r * 0.75), c + Vector2(r * 0.6, r * 0.35)]), hi, w, true)
			"jacker":    # a pickaxe (mining)
				ci.draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.7, -r * 0.7), hi, w * 1.1, true)
				ci.draw_arc(c + Vector2(r * 0.15, -r * 0.15), r * 0.75, PI * 0.08, PI * 0.92, 18, hi, w, true)
			"skimmer":   # a payment card with a magstripe
				var cw := r * 0.95; var ch := r * 0.6
				ci.draw_rect(Rect2(c.x - cw, c.y - ch, cw * 2, ch * 2), Color(col.r, col.g, col.b, 0.2), true)
				ci.draw_rect(Rect2(c.x - cw, c.y - ch, cw * 2, ch * 2), hi, false, w, true)
				ci.draw_rect(Rect2(c.x - cw, c.y - ch * 0.35, cw * 2, ch * 0.5), hi, true)
			"forge":     # a hammer (forge exploits)
				ci.draw_line(c + Vector2(-r * 0.5, r * 0.65), c + Vector2(r * 0.25, -r * 0.1), hi, w * 1.2, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.05, -r * 0.5), c + Vector2(r * 0.7, -r * 0.75), c + Vector2(r * 0.85, -r * 0.35), c + Vector2(r * 0.1, -r * 0.1), c + Vector2(-r * 0.05, -r * 0.5)]), hi, w, true)
			"mixer":     # a recycling loop (crypto → cash)
				ci.draw_arc(c, r * 0.72, PI * 0.25, PI * 1.35, 20, hi, w, true)
				ci.draw_arc(c, r * 0.72, PI * 1.25, PI * 2.35, 20, hi, w, true)
				var a1 := c + Vector2(cos(PI * 0.25), sin(PI * 0.25)) * r * 0.72
				ci.draw_line(a1, a1 + Vector2(-r * 0.26, -r * 0.04), hi, w, true)
				ci.draw_line(a1, a1 + Vector2(-r * 0.02, -r * 0.26), hi, w, true)
				var a2 := c + Vector2(cos(PI * 1.25), sin(PI * 1.25)) * r * 0.72
				ci.draw_line(a2, a2 + Vector2(r * 0.26, r * 0.04), hi, w, true)
				ci.draw_line(a2, a2 + Vector2(r * 0.02, r * 0.26), hi, w, true)
			"market":    # a price tag (darknet market)
				var pts := PackedVector2Array([c + Vector2(-r * 0.15, -r * 0.7), c + Vector2(r * 0.7, -r * 0.7), c + Vector2(r * 0.7, r * 0.15), c + Vector2(-r * 0.1, r * 0.8), c + Vector2(-r * 0.8, r * 0.05)])
				ci.draw_polyline(pts + PackedVector2Array([pts[0]]), hi, w, true)
				ci.draw_circle(c + Vector2(r * 0.42, -r * 0.42), r * 0.12, hi, false, w, true)
			"cloak":    # evade: a signal with a slash through it (go quiet)
				ci.draw_arc(c, r * 0.4, PI * 1.15, PI * 1.85, 12, hi, w, true)
				ci.draw_arc(c, r * 0.7, PI * 1.1, PI * 1.9, 16, hi, w, true)
				ci.draw_arc(c, r * 1.0, PI * 1.05, PI * 1.95, 20, hi, w, true)
				ci.draw_circle(c + Vector2(0, r * 0.6), r * 0.14, hi, true, -1.0, true)
				ci.draw_line(c + Vector2(-r * 0.85, -r * 0.85), c + Vector2(r * 0.85, r * 0.85), hi, w * 1.2, true)
			"vault":    # a storage cell / battery with a charge bar
				var vw := r * 0.72; var vh := r * 0.85
				ci.draw_rect(Rect2(c.x - vw, c.y - vh, vw * 2, vh * 2), Color(col.r, col.g, col.b, 0.18), true)
				ci.draw_rect(Rect2(c.x - vw, c.y - vh, vw * 2, vh * 2), hi, false, w, true)
				ci.draw_rect(Rect2(c.x - vw * 0.4, c.y - vh - r * 0.18, vw * 0.8, r * 0.18), hi, true)
				for k in 3:
					var yy := c.y + vh * 0.5 - float(k) * vh * 0.55
					ci.draw_line(Vector2(c.x - vw * 0.6, yy), Vector2(c.x + vw * 0.6, yy), hi, w, true)
			_:
				ci.draw_circle(c, r * 0.5, hi, false, w, true)


class _FxLayer extends Node2D:
	var host
	func _draw() -> void:
		if host != null: host._draw_fx(self)