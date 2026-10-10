extends Node
## Autoload "Econ": the run's economy, ticking globally so installed programs keep producing whether
## you're on the city map or inside a building. ALL tunable numbers live in data/economy.json (see
## design/ECONOMY_GUIDE.md) — this script only loads and applies them.
##
## Five stockpiles, Intel the universal currency: Intel (pays for every scan/profile/capture; +1/s
## passive baseline), Cash, Credentials & Exploits (burned on a capture for a better chance), Crypto
## (only a Mixer turns it into Cash). Every stockpile holds 100 by default; STORAGE programs raise a
## resource's cap. Programs run only on nodes that are CONNECTED back to the city (the entry firewall) —
## a lost relay cuts off everything behind it.
##
## HEAT (per node): each running tool emits heat with its own chance; EVADE tools cool it. At 50% heat a
## node risks an alarm each minute; at 100% it alarms at once. An alarm wipes the node's tools, drops
## your control (re-hack needed), and leaves it harder to crack again (costs more, lower odds).

const RES := ["intel", "cash", "creds", "exploits", "crypto"]
const RES_NAME := {"intel": "Intel", "cash": "Cash", "creds": "Credentials", "exploits": "Exploits", "crypto": "Crypto"}
const RES_SYM := {"intel": "◈", "cash": "¥", "creds": "⚿", "exploits": "⚡", "crypto": "₿"}
const COLOR_KEY := {"intel": "data", "cash": "credits", "creds": "creds", "exploits": "tools", "crypto": "crypto", "evade": "evade"}
const CAT_RES := {"intel": "intel", "creds": "creds", "crypto": "crypto", "ops": "cash", "evade": "evade"}
const DATA_PATH := "res://data/economy.json"
const BAR_H := 44.0

# tunables (loaded from economy.json; the values here are the fallback if the file is missing/broken)
var PROGRAMS := {}
var START := {"intel": 20.0, "cash": 0.0, "creds": 0.0, "exploits": 0.0, "crypto": 0.0}
var CAP_BASE := 100.0
var PASSIVE_INTEL := 1.0
var COST := {"net_scan": 4.0, "profile": 3.0, "take": 8.0}
var BOOST := 0.3
var CAPTURE_SCALE := 0.15   # each node you already control adds this fraction to the next capture's cost
var TIME := {"net_scan": 10.0, "profile": 8.0, "take": 10.0, "install_per_hop": 0.6, "install_min": 1.2, "install_finalise": 1.4, "install_fail_chance": 0.05}
var HEAT := {"max": 100.0, "alarm_at": 100.0, "warn_at": 50.0, "alarm_minute_chance": 0.05,
	"rehack_cost_per_alarm": 0.10, "rehack_chance_per_alarm": 0.05, "rehack_alarm_cap": 5}

var stock := {}
var cap := {}         # current capacity per stockpile (CAP_BASE + installed storage)
var rate := {}        # net per-second change from the last tick (for the HUD trend)
var test_uncapped := false   # tests only: skip passive income, the cap clamp, heat and reachability

var _heat_acc := 0.0
var _minute_acc := 0
var alarm_msg := ""
var _alarm_t := 0.0
var _hud: CanvasLayer
var _hud_lbls := {}
var _hud_rate := {}
var _alarm_lbl: Label
var _hud_acc := 0.0
var _menu_btn: Button


func _ready() -> void:
	_load_params()
	reset()
	_build_hud()


# ---------------------------------------------------------------- params from data/economy.json
func _load_params() -> void:
	var txt := FileAccess.get_file_as_string(DATA_PATH)
	var d = JSON.parse_string(txt) if txt != "" else null
	if not (d is Dictionary) or not d.has("programs"):
		push_error("Econ: could not load %s — using built-in fallback numbers" % DATA_PATH)
		PROGRAMS = _fallback_programs()
		return
	PROGRAMS = {}
	for pk in d.programs:
		var src: Dictionary = d.programs[pk]
		var p := {}
		for k in src:
			if k == "cost":
				p[k] = _to_float_dict(src[k])
			elif k in ["rate", "in_rate", "amount", "heat", "noise", "evade", "tier"]:
				p[k] = float(src[k])
			else:
				p[k] = src[k]
		PROGRAMS[pk] = p
	for r in RES:
		START[r] = float(d.get("start", {}).get(r, START[r]))
	CAP_BASE = float(d.get("cap_base", CAP_BASE))
	PASSIVE_INTEL = float(d.get("passive_intel", PASSIVE_INTEL))
	for k in d.get("action_cost", {}): COST[k] = float(d.action_cost[k])
	BOOST = float(d.get("capture_boost", BOOST))
	CAPTURE_SCALE = float(d.get("capture_scale_per_node", CAPTURE_SCALE))
	for k in d.get("action_time", {}): TIME[k] = float(d.action_time[k])
	for k in d.get("heat", {}): HEAT[k] = float(d.heat[k])


func _to_float_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src: out[k] = float(src[k])
	return out


func _fallback_programs() -> Dictionary:
	return {"scraper": {"name": "Scraper Botnet", "cat": "intel", "tier": 1.0, "glyph": "scraper", "out": "intel", "rate": 0.6, "heat": 1.0, "noise": 0.2, "cost": {"intel": 10.0}},
		"cloak": {"name": "Traffic Cloak", "cat": "evade", "tier": 1.0, "glyph": "cloak", "evade": 2.0, "cost": {"intel": 20.0}},
		"mixer": {"name": "Crypto Mixer", "cat": "ops", "tier": 1.0, "glyph": "mixer", "in": "crypto", "in_rate": 1.0, "out": "cash", "rate": 0.8, "heat": 1.0, "noise": 0.55, "cost": {"intel": 15.0}}}


func reset() -> void:
	stock = {}; cap = {}
	for r in RES: stock[r] = float(START[r]); rate[r] = 0.0; cap[r] = CAP_BASE
	_heat_acc = 0.0; _minute_acc = 0; alarm_msg = ""; _alarm_t = 0.0
	_recompute_caps()


func prog_glyph(pk: String) -> String:
	return str(PROGRAMS.get(pk, {}).get("glyph", pk))


# ---------------------------------------------------------------- stockpiles
func _recompute_caps() -> void:
	for r in RES: cap[r] = CAP_BASE
	for key in Session.interior:
		for nd in Session.interior[key]:
			for pk in nd.get("progs", []):
				var p: Dictionary = PROGRAMS.get(pk, {})
				if p.has("store"): cap[str(p.store)] = float(cap[str(p.store)]) + float(p.amount)


func can_pay(cost: Dictionary) -> bool:
	for r in cost:
		if float(stock.get(r, 0.0)) + 1e-6 < float(cost[r]): return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_pay(cost): return false
	for r in cost: stock[r] = float(stock[r]) - float(cost[r])
	return true


func add(res: String, amt: float) -> void:
	stock[res] = clampf(float(stock.get(res, 0.0)) + amt, 0.0, float(cap.get(res, CAP_BASE)))


func color(res: String) -> Color:
	return Settings.res_color(str(COLOR_KEY.get(res, res)))


func cat_color(cat: String) -> Color:
	return color(str(CAT_RES.get(cat, "intel")))


func describe(pk: String) -> String:
	var p: Dictionary = PROGRAMS[pk]
	if p.has("evade"): return "−%d heat/s" % int(p.evade)
	if p.has("store"): return "+%d %s capacity" % [int(p.amount), RES_NAME[p.store]]
	if p.has("in"): return "%.1f %s → %.1f %s /s" % [float(p.in_rate), RES_NAME[p.in], float(p.rate), RES_NAME[p.out]]
	return ("+%.2f %s/s" % [float(p.rate), RES_NAME[p.out]]) if float(p.rate) < 0.2 else ("+%.1f %s/s" % [float(p.rate), RES_NAME[p.out]])


func heat_text(pk: String) -> String:
	var p: Dictionary = PROGRAMS[pk]
	if p.has("evade"): return "cools %d heat/s" % int(p.evade)
	if p.has("heat"): return "heat +%d/s @ %d%%" % [int(p.heat), int(round(float(p.get("noise", 0.0)) * 100.0))]
	return "no heat"


func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for r in cost: parts.append("%d %s" % [int(round(float(cost[r]))), RES_SYM[r]])
	return " + ".join(parts)


func controlled_total() -> int:
	var n := 0
	for key in Session.interior:
		for nd in Session.interior[key]:
			if str(nd.get("state", "")) == "controlled": n += 1
	return n


# the Intel multiplier on the NEXT capture: it gets pricier the bigger your foothold (Stellaris-style)
func capture_scale() -> float:
	return 1.0 + CAPTURE_SCALE * float(maxi(0, controlled_total() - 1))


# advance every in-progress task across every building; resolve the ones that finish (a failure resolves
# at its pre-rolled interrupt time, a success at full duration). Runs globally so progress never pauses.
func advance_tasks(dt: float) -> void:
	for key in Session.interior:
		var recs: Array = Session.interior[key]
		for i in recs.size():
			var nd: Dictionary = recs[i]
			if str(nd.get("task", "")) == "": continue
			nd["t"] = float(nd.get("t", 0.0)) + dt
			var succ := bool(nd.get("tsucc", false))
			var tfail := float(nd.get("tfail", -1.0))
			var fails_now: bool = not succ and tfail >= 0.0 and float(nd.t) >= tfail
			if fails_now or float(nd.t) >= float(nd.get("dur", 0.0)):
				_resolve_task(key, recs, i)


# apply a finished task's PRE-ROLLED outcome to the saved record, and leave a `result` the building reads
# to show the ✓/✕ cue. Pure data (uses the stored graph + slot count), so it works with no scene loaded.
func _resolve_task(key: String, recs: Array, i: int) -> void:
	var nd: Dictionary = recs[i]
	var kind := str(nd.task)
	var succ := bool(nd.get("tsucc", false))
	nd.task = ""; nd["t"] = 0.0; nd["dur"] = 0.0; nd["tfail"] = -1.0
	var res := {"kind": kind, "ok": succ}
	match kind:
		"scan":
			if str(nd.state) == "controlled" and succ:
				var found := 0
				for o in nd.get("nbrs", []):
					if o >= 0 and o < recs.size() and str(recs[o].state) == "hidden": recs[o].state = "detected"; found += 1
				nd.enum_done = true; res["found"] = found
			else: res.ok = false
		"profile":
			if str(nd.state) == "detected" and succ: nd.profiled = true
			else: res.ok = false
		"take":
			var reach := false
			for o in nd.get("nbrs", []):
				if o >= 0 and o < recs.size() and str(recs[o].state) == "controlled": reach = true
			if str(nd.state) == "detected" and succ and reach: nd.state = "controlled"
			else: res.ok = false
		"install":
			var prog := str(nd.get("tprog", "")); res["prog"] = prog
			if succ and str(nd.state) == "controlled" and (nd.get("progs", []) as Array).size() < int(nd.get("slots", 99)) and PROGRAMS.has(prog):
				nd.progs.append(prog)
			else: res.ok = false
	nd["result"] = res
	var ctl := 0; var det := 0
	for r in recs:
		if str(r.state) == "controlled": ctl += 1
		elif str(r.state) == "detected": det += 1
	if ctl > 1 or det > 0: Session.hacked[key] = {"ctl": ctl, "n": recs.size(), "det": det}
	if host_conquered(recs): Session.owned[key] = true   # the conquest goal: core cracked (or every node taken)


# a host counts as CONQUERED once its core node(s) are controlled, or — for minor hosts with no core —
# once every node is controlled. Pure data on the saved records, so it holds on the city map too.
func host_conquered(recs: Array) -> bool:
	var cores := 0; var cores_ctl := 0; var ctl := 0
	for r in recs:
		if str(r.state) == "controlled": ctl += 1
		if str(r.get("type", "")) == "core":
			cores += 1
			if str(r.state) == "controlled": cores_ctl += 1
	if cores > 0: return cores_ctl == cores
	return recs.size() > 0 and ctl >= recs.size()


func installed_count() -> int:
	var n := 0
	for key in Session.interior:
		for nd in Session.interior[key]: n += (nd.get("progs", []) as Array).size()
	return n


# ---------------------------------------------------------------- the tick
func _process(dt: float) -> void:
	if _alarm_t > 0.0: _alarm_t -= dt
	var sc := get_tree().current_scene
	var active := sc != null and (sc.scene_file_path.ends_with("city.tscn") or sc.scene_file_path.ends_with("building.tscn"))
	if active or test_uncapped:
		tick(dt)
	_hud_acc += dt
	if _hud_acc >= 0.2: _hud_acc = 0.0; _update_hud()


# every building's reachable set: controlled nodes with a path over controlled nodes to the entry (0)
func _reachable_set(recs: Array) -> Dictionary:
	var seen := {}
	if recs.is_empty(): return seen
	if not recs[0].has("nbrs"):   # older saves without the graph → treat every controlled node as connected
		for i in recs.size():
			if str(recs[i].state) == "controlled": seen[i] = true
		return seen
	if str(recs[0].state) != "controlled": return seen
	seen[0] = true; var st := [0]
	while not st.is_empty():
		var c: int = st.pop_back()
		for o in recs[c].get("nbrs", []):
			if o >= 0 and o < recs.size() and str(recs[o].state) == "controlled" and not seen.has(o):
				seen[o] = true; st.append(o)
	return seen


func tick(dt: float) -> void:
	_recompute_caps()
	var net := {}
	for r in RES: net[r] = 0.0
	if not test_uncapped:
		advance_tasks(dt)   # timed scans/captures/installs keep running wherever you are
		stock.intel = float(stock.intel) + PASSIVE_INTEL * dt
		net.intel += PASSIVE_INTEL
	for key in Session.interior:
		var recs: Array = Session.interior[key]
		var reach := {} if test_uncapped else _reachable_set(recs)
		for i in recs.size():
			if not test_uncapped and not reach.has(i): continue   # only connected nodes generate
			for pk in recs[i].get("progs", []):
				if not PROGRAMS.has(pk): continue
				var p: Dictionary = PROGRAMS[pk]
				if p.has("store") or p.has("evade"):
					continue
				elif p.has("in"):
					var need := float(p.in_rate) * dt
					var f := 1.0 if need <= 0.0 else clampf(float(stock[p.in]) / need, 0.0, 1.0)
					if f <= 0.0: continue
					stock[p.in] = float(stock[p.in]) - need * f
					stock[p.out] = float(stock[p.out]) + float(p.rate) * dt * f
					net[p.in] -= float(p.in_rate) * f; net[p.out] += float(p.rate) * f
				else:
					stock[p.out] = float(stock[p.out]) + float(p.rate) * dt
					net[p.out] += float(p.rate)
	if not test_uncapped:
		for r in RES: stock[r] = clampf(float(stock[r]), 0.0, float(cap[r]))
		_heat_acc += dt
		while _heat_acc >= 1.0:
			_heat_acc -= 1.0
			_heat_second()
			_minute_acc += 1
			if _minute_acc >= 60:
				_minute_acc = 0; _heat_minute()
	rate = net


# one second of heat: connected running tools emit heat by their own chance; evade tools cool it
func _heat_second() -> void:
	for key in Session.interior:
		var recs: Array = Session.interior[key]
		var reach := _reachable_set(recs)
		for i in recs.size():
			if not reach.has(i) or str(recs[i].state) != "controlled": continue
			var dh := 0.0
			for pk in recs[i].get("progs", []):
				var p: Dictionary = PROGRAMS.get(pk, {})
				if p.has("evade"): dh -= float(p.evade)
				elif p.has("heat") and randf() < float(p.get("noise", 0.0)): dh += float(p.heat)
			if dh == 0.0 and not recs[i].has("heat"): continue
			recs[i]["heat"] = clampf(float(recs[i].get("heat", 0.0)) + dh, 0.0, float(HEAT.max))
			if float(recs[i].heat) >= float(HEAT.alarm_at): _alarm(key, recs, i)


# once a minute, every warm node (≥ warn_at) risks an alarm
func _heat_minute() -> void:
	for key in Session.interior:
		var recs: Array = Session.interior[key]
		for i in recs.size():
			if str(recs[i].state) == "controlled" and float(recs[i].get("heat", 0.0)) >= float(HEAT.warn_at) and randf() < float(HEAT.alarm_minute_chance):
				_alarm(key, recs, i)


# the node is traced: tools wiped, control lost (re-hack needed and harder), connections behind it cut
func _alarm(key: String, recs: Array, i: int) -> void:
	var nd: Dictionary = recs[i]
	if str(nd.state) != "controlled": return
	nd.state = "detected"; nd.progs = []; nd["heat"] = 0.0
	nd["burned"] = mini(int(nd.get("burned", 0)) + 1, int(HEAT.rehack_alarm_cap))
	alarm_msg = "⚠ ALARM — node traced, foothold lost"; _alarm_t = 5.0
	var ctl := 0; var det := 0
	for r in recs:
		if str(r.state) == "controlled": ctl += 1
		elif str(r.state) == "detected": det += 1
	if ctl > 1 or det > 0: Session.hacked[key] = {"ctl": ctl, "n": recs.size(), "det": det}


# ---------------------------------------------------------------- HUD: full-width top bar
func _build_hud() -> void:
	_hud = CanvasLayer.new(); _hud.layer = 20; add_child(_hud)
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	sb.border_color = Color(0.2, 1.0, 0.9, 0.5); sb.border_width_bottom = 1
	sb.content_margin_left = 16; sb.content_margin_right = 10; sb.content_margin_top = 5; sb.content_margin_bottom = 5
	bar.add_theme_stylebox_override("panel", sb)
	bar.anchor_right = 1.0; bar.offset_top = 0; bar.offset_bottom = BAR_H
	_hud.add_child(bar)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 26)
	bar.add_child(hb)
	for r in RES:
		var cell := HBoxContainer.new(); cell.add_theme_constant_override("separation", 7); hb.add_child(cell)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_font_override("font", Settings.font_bold)
		l.add_theme_color_override("font_color", color(r))
		cell.add_child(l); _hud_lbls[r] = l
		var t := Label.new(); t.add_theme_font_size_override("font_size", 14)
		cell.add_child(t); _hud_rate[r] = t
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(spacer)
	_alarm_lbl = Label.new(); _alarm_lbl.add_theme_font_size_override("font_size", 16)
	_alarm_lbl.add_theme_font_override("font", Settings.font_bold)
	_alarm_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_alarm_lbl.clip_text = true; _alarm_lbl.custom_minimum_size = Vector2(0, 0)
	hb.add_child(_alarm_lbl)
	var spacer2 := Control.new(); spacer2.custom_minimum_size = Vector2(16, 0); hb.add_child(spacer2)
	_menu_btn = Button.new(); _menu_btn.text = "☰  MENU"; _menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.add_theme_font_size_override("font_size", 15); _menu_btn.custom_minimum_size = Vector2(124, 32)
	_menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	hb.add_child(_menu_btn)
	_update_hud()


func _update_hud() -> void:
	if _hud == null: return
	var sc := get_tree().current_scene
	var path := sc.scene_file_path if sc != null else ""
	_hud.visible = path.ends_with("city.tscn") or path.ends_with("building.tscn")
	if not _hud.visible: return
	for r in RES:
		_hud_lbls[r].text = "%s %s  %d / %d" % [RES_SYM[r], RES_NAME[r], int(floor(float(stock[r]))), int(cap.get(r, CAP_BASE))]
		var dr := float(rate.get(r, 0.0)); var t: Label = _hud_rate[r]
		if absf(dr) < 0.005:
			t.text = ""
		else:
			t.text = ("%+.1f/s" % dr) if absf(dr) >= 0.1 else ("%+.2f/s" % dr)
			t.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55) if dr > 0.0 else Color(1.0, 0.45, 0.45))
	_alarm_lbl.text = alarm_msg if _alarm_t > 0.0 else ""
