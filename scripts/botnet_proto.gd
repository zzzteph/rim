extends Control
## Building-level botnet prototype. Rules and visual guidance are in design/.
## Drag to connect. Explicit Scan / Attack starts an inactive target operation.
## New contributors join an existing attack. Friendly connections guard automatically.
## Bots and cards take effect on arrival; Stop keeps links, Disconnect removes them.
## Construction shares remaining Intel after attack departures. Research uses Cash,
## Credentials and Research. A captured rig eliminates any faction. Hold a majority
## for HOLD_SECS or eliminate the rivals to win. Menu pause is independent of Space.

const CfgFactions := preload("res://scripts/botnet_cfg/factions.gd")
const CfgTown := preload("res://scripts/botnet_cfg/town.gd")
const CfgTypes := preload("res://scripts/botnet_cfg/types.gd")
const CfgBuildings := preload("res://scripts/botnet_cfg/buildings.gd")
const CfgCards := preload("res://scripts/botnet_cfg/cards.gd")
const CfgTuning := preload("res://scripts/botnet_cfg/tuning.gd")

const NEUTRAL := CfgFactions.NEUTRAL
const PLAYER := CfgFactions.PLAYER
const RIVAL := CfgFactions.RIVAL
const RIVAL2 := CfgFactions.RIVAL2
const RIVAL3 := CfgFactions.RIVAL3
const FACTIONS := CfgFactions.FACTIONS
const BOTNETS := CfgFactions.BOTNETS   # defaults; the live sets below are chosen by the new-game options
const AIS := CfgFactions.AIS
var botnets: Array = BOTNETS.duplicate()   # the factions actually in THIS game (player + chosen enemies)
var ais: Array = AIS.duplicate()
const AI_PROFILE := CfgFactions.AI_PROFILE
const AI_MAX_STREAMS := CfgFactions.AI_MAX_STREAMS
const AI_RESERVE := CfgFactions.AI_RESERVE
const AI_PATIENCE := CfgFactions.AI_PATIENCE
const AI_SPEED := CfgFactions.AI_SPEED
const AI_PRIOR_BOTNET := CfgFactions.AI_PRIOR_BOTNET
const AI_SCOUT_INTEL := CfgFactions.AI_SCOUT_INTEL
const AI_CHOKE_LEAD := CfgFactions.AI_CHOKE_LEAD
const AI_EDGE_MEMORY := CfgFactions.AI_EDGE_MEMORY
const AI_SIEGE_MAX := CfgFactions.AI_SIEGE_MAX
const AI_CASH_MULT := CfgFactions.AI_CASH_MULT
const AI_REACT := CfgFactions.AI_REACT

const GRID_COLS := CfgTown.GRID_COLS
const GRID_ROWS := CfgTown.GRID_ROWS
const EMPTY_CELL := CfgTown.EMPTY_CELL
const LINK_KEEP := CfgTown.LINK_KEEP
const DIAG_P := CfgTown.DIAG_P
const TOWN_WORDS := CfgTown.TOWN_WORDS
const HIGHWAY_P := CfgTown.HIGHWAY_P
const JUNCTIONS := CfgTown.JUNCTIONS
const JUNCTION_CAP_MULT := CfgTown.JUNCTION_CAP_MULT

const NODE_TYPES := CfgTypes.NODE_TYPES
const TYPE_WEIGHTS := CfgTypes.TYPE_WEIGHTS
const RESIST := CfgTypes.RESIST

const BUILD_TIME := CfgBuildings.BUILD_TIME
const DEMOLISH_TIME := CfgBuildings.DEMOLISH_TIME
const BUILD_COST_INTEL := CfgBuildings.BUILD_COST_INTEL
const BUILD_KINDS := CfgBuildings.BUILD_KINDS

const CARDS := CfgCards.CARDS
const CARD_ORDER := CfgCards.CARD_ORDER
const FAMILY_NAME := CfgCards.FAMILY_NAME
const FAMILY_COL := CfgCards.FAMILY_COL
const WORM_FALLOFF := CfgCards.WORM_FALLOFF
const CARD_ALARM := CfgCards.CARD_ALARM
const STEAL_DUR := CfgCards.STEAL_DUR

const NODE_CAP := CfgTuning.NODE_CAP
const PROD_RATE := CfgTuning.PROD_RATE
const ATTACK_POWER := CfgTuning.ATTACK_POWER
const DEFEND_POWER := CfgTuning.DEFEND_POWER
const INTEL_START := CfgTuning.INTEL_START
const INTEL_CAP_BASE := CfgTuning.INTEL_CAP_BASE
const INTEL_CAP_PER_BUILD := CfgTuning.INTEL_CAP_PER_BUILD
const INTEL_PER_BUILD := CfgTuning.INTEL_PER_BUILD
const CRED_PER_BUILD := CfgTuning.CRED_PER_BUILD
const RESEARCH_PER_BUILD := CfgTuning.RESEARCH_PER_BUILD
const RES_CAP_BASE := CfgTuning.RES_CAP_BASE
const RES_CAP_PER_BUILD := CfgTuning.RES_CAP_PER_BUILD
const CASH_INTERVAL := CfgTuning.CASH_INTERVAL
const HOLD_FRACTION := CfgTuning.HOLD_FRACTION
const HOLD_SECS := CfgTuning.HOLD_SECS
const RIG_INTEL := CfgTuning.RIG_INTEL
const SCAN_BASE := CfgTuning.SCAN_BASE
const SCAN_PER_BUILD := CfgTuning.SCAN_PER_BUILD
const SCAN_COSTS_INTEL := CfgTuning.SCAN_COSTS_INTEL
const SEND_RATE := CfgTuning.SEND_RATE
const LINK_TIME := CfgTuning.LINK_TIME
const NODE_ROUTE_DELAY := CfgTuning.NODE_ROUTE_DELAY
const LINK_CAP := CfgTuning.LINK_CAP
const MAX_QUEUE := CfgTuning.MAX_QUEUE
const STAGE_FULL := CfgTuning.STAGE_FULL
const STAGE_SHAKY := CfgTuning.STAGE_SHAKY
const STAGE_NAME := CfgTuning.STAGE_NAME

const PANEL_W := 620.0
const MENU_W := 384.0           # menu panel width
const GAME_VERSION := "0.1.0"
# Feedback is collected IN-GAME (no redirect). It is always appended to user://feedback.jsonl, and — if you set
# an endpoint — POSTed there as JSON too (point it at any collector: a webhook, an Apps Script, your own API).
const FEEDBACK_ENDPOINT := ""   # e.g. "https://script.google.com/macros/s/XXXX/exec"  (empty = save locally only)
# one text palette, one meaning per colour: TEXT = facts · DIM = secondary · WARN = needs you · GOOD = going
# your way · BAD = hostile or lost. Faction colours mark owners; card families keep their own neon.
const C_TEXT := Color(0.88, 0.92, 1.0)
const C_DIM := Color(0.6, 0.68, 0.8)
const C_WARN := Color(1.0, 0.84, 0.45)
const C_GOOD := Color(0.6, 0.95, 0.75)
const C_BAD := Color(1.0, 0.55, 0.5)

var town_seed := 0                 # 0 = a new town every run; set before _ready to reproduce a layout
var _cols := GRID_COLS             # live grid size (chosen by the new-game options)
var _rows := GRID_ROWS
# new-game options (chosen in the menu): size preset (cols, rows) and enemy count
const SIZE_PRESETS := [Vector2i(6, 4), Vector2i(8, 6), Vector2i(10, 8)]   # Small · Medium · Big
var _opt_size := Vector2i(8, 6)    # default: Medium
var _opt_enemies := 2
var _opt_seed := 0                 # 0 = random town
var menu_seed_edit: LineEdit
# in-game feedback form state
var _fb_rating := 0
var _fb_type := "general"
var _fb_status := ""
var _fb_draft := {"details": "", "version": GAME_VERSION, "name": ""}
var fb_details: TextEdit
var fb_version: LineEdit
var fb_name: LineEdit
var fb_http: HTTPRequest
var ai_enabled := true             # probes switch the AI botnets off for fixture cases
var ai_speed: float = AI_SPEED     # the think-cadence multiplier (probes vary it; the config sets the default)
var ai_cash_mult: float = AI_CASH_MULT   # the AI botnets' Cash income multiplier — the honest handicap knob

var rng := RandomNumberGenerator.new()
var _t := 0.0                      # the single simulation clock everything shares
var paused := false
var won := false
var lost := false
var _end_shown := false
var _end_cause := ""
var _msg := ""
var _msg_t := 0.0
var _msg_priority := 0
var _departures: Array = []
var _resource_samples: Array = []
var _defender_samples: Dictionary = {}
var _eliminated: Dictionary = {}
var _panel_context := ""
var hand_scroll: ScrollContainer
var pending_research: HBoxContainer
var objective_label: Label
var feedback_label: Label
var _selected_card := ""
var _catalogue_card := "phish:linked"
const RESEARCH_QUEUE_LIMIT := 4
var _tut_target := -1
var _tut_second := -1
var _tut_connected := false
var _tut_attacked := false
var _tut_combined := false
var _tut_captured := false
var _seed_draft := ""

var hosts := []        # {pos,grid,name,links,owner,bots,sec,value,slots,builds,job,assign,live,rate,hub,rig}
var hub := -1
var rig := {}          # faction -> index of its rig (the Cash sink)
var _cell := {}        # Vector2i grid cell -> host index (gaps have no entry)
var _highways := {}    # "a_b" (a<b) -> true: a street that bridges a gap — a second path across the town
var intel := {}        # faction -> Intel reserve
var cash := {}         # faction -> Cash (fuels cards; no longer the win)
var _hold := {}        # faction -> seconds it has continuously held the majority
var flights := []      # {route:[idx], hops:[link entry times], depart_t, arrive_t, owner, kind:"bot"|"cash", amount}
var _res := {}         # "a>b" -> sorted entry times reserved on that link direction (capacity)
var _next_depart := {} # bot source -> absolute time its next bot is due
var _next_cash := {}   # cash emitter -> absolute time its next packet is due
var _ai := {}          # faction -> {timer, ops:{target:{since,bots}}, avoid, dead}
var scans := {}        # faction -> {host: {"key": contents when scanned, "done": bool, "progress": bots landed}}
var creds := {}        # faction -> Credentials (pay for cards)
var research := {}     # faction -> Research points (pay for cards)
var cards := {}        # faction -> {"card:reach": count} — the hand; it accumulates without limit
var lab := {}          # faction -> {"queue": ["card:reach", …], "progress": s into the head item, "paused": bool, "stall": resource short of}
var _fx := []          # pulses on hit buildings {host, until, col}
var _worms := []       # drawn worm jumps {a, b, until, col}
var _tab := ""         # the open sidebar: "" (hidden / building context), "research" or "board"
var panel_scroll: ScrollContainer = null   # the panel's scroll, kept across refreshes
var card_plays := {}   # faction -> cards played (probes and the result screen)

# selection / command
var sel := {}          # selected buildings of yours (the ones a drag would wire)
var _inspect := -1     # the building whose panel is open (a target's panel carries its ⚔ ATTACK launch), or -1
var _press_pos := Vector2.ZERO
var _boxing := false
var _box_start := Vector2.ZERO
var _drag_from := -1   # your building a line is being dragged FROM (to wire a target), or -1
var _dragging := false
var _emit_cursor := 0
var _panel_t := 0.0
var _redraw_t := 0.0             # gate the per-frame canvas redraw (only while something animates + a light heartbeat)
var _menu_t := 0.0               # animation clock for the menu's drifting-packet background
var _zoom := 1.0                 # map zoom (wheel); 1.0 = identity. Pan with the middle mouse button.
var _pan := Vector2.ZERO
var _panning := false
var _pan_last := Vector2.ZERO

var hud: Control
var panel: Panel
var panel_box: VBoxContainer
var hand_panel: Control          # the persistent hand of cards along the bottom (no background — just the cards)
var hand_bar: GridContainer
var _hand_sig := ""              # rebuild the hand only when its composition changes (keeps it cheap)
var menu_panel: Panel            # the Esc menu: Start / Resume / Restart (pauses while open)
var menu_box: VBoxContainer
var menu_sc: ScrollContainer
var menu_open := false
var _menu_view := "main"          # "main" · "newgame" · "help" · "feedback"
var _help_page := 0
# tutorial
var _tut := false
var _tut_stage := 0
var _ai_paused := false           # the tutorial freezes the AI until the last stage
var tut_panel: Panel
var tut_box: VBoxContainer
var top_tabs: HBoxContainer       # always-visible RESEARCH / BOARD buttons; the side panel is hidden by default
var _toptab_sig := "@"            # rebuild the top tabs only when their state changes (clicks aren't eaten)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_options()
	_gen()
	var sz := get_viewport_rect().size
	hud = HudBar.new(); hud.game = self; hud.position = Vector2(24, 10)
	hud.size = Vector2(sz.x - PANEL_W - 60.0, 32); add_child(hud)
	panel = Panel.new(); panel.size = Vector2(PANEL_W, sz.y - 70.0)
	panel.position = Vector2(sz.x - PANEL_W - 16.0, 56.0); add_child(panel)   # a clear gap below the top dashboard
	var sc := ScrollContainer.new(); panel_scroll = sc
	sc.position = Vector2(14, 12); sc.size = panel.size - Vector2(28, 24)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 4)
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.custom_minimum_size = Vector2(_panel_width() - 28.0, 0)
	sc.add_child(panel_box)
	hand_panel = Control.new()                                 # your hand, along the bottom — NO background, just cards
	hand_panel.size = Vector2(sz.x - 60.0, 96.0)
	hand_panel.position = Vector2(24.0, sz.y - 104.0)
	hand_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE      # empty hand space never blocks the map
	add_child(hand_panel)
	hand_bar = GridContainer.new(); hand_bar.columns = 4
	hand_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_bar.add_theme_constant_override("h_separation", 6); hand_bar.add_theme_constant_override("v_separation", 6)
	hand_bar.position = Vector2(10.0, 6.0)
	hand_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_scroll = ScrollContainer.new()
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_panel.add_child(hand_scroll)
	hand_scroll.add_child(hand_bar)
	pending_research = HBoxContainer.new(); pending_research.add_theme_constant_override("separation", 6)
	pending_research.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(pending_research)
	_refresh_hand()
	top_tabs = HBoxContainer.new()                             # RESEARCH / BOARD buttons on the top dashboard
	top_tabs.add_theme_constant_override("separation", 6)
	top_tabs.position = Vector2(sz.x - 296.0, 7.0)   # top-right of the dashboard
	add_child(top_tabs)
	_refresh_top_tabs()
	menu_panel = Panel.new()                                   # the Esc / start menu overlay
	menu_panel.size = Vector2(MENU_W, 640)
	menu_panel.position = ((sz - menu_panel.size) * 0.5).floor()
	add_child(menu_panel)
	menu_sc = ScrollContainer.new()
	menu_sc.position = Vector2(24.0, 22.0)
	menu_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_panel.add_child(menu_sc)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	menu_box.custom_minimum_size = Vector2(MENU_W - 60.0, 0)
	menu_sc.add_child(menu_box)
	fb_http = HTTPRequest.new(); add_child(fb_http)            # posts feedback if an endpoint is configured
	tut_panel = Panel.new()                                   # the tutorial prompt banner (top-centre)
	tut_panel.size = Vector2(780.0, 172.0)
	tut_panel.position = Vector2(floorf((sz.x - 780.0) * 0.5), 54.0)
	tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE      # clicks fall through to the map; only its buttons catch
	tut_panel.visible = false
	add_child(tut_panel)
	tut_box = VBoxContainer.new()
	tut_box.position = Vector2(22.0, 14.0); tut_box.custom_minimum_size = Vector2(736.0, 0)
	tut_box.add_theme_constant_override("separation", 8); tut_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_panel.add_child(tut_box)
	objective_label = Label.new(); objective_label.add_theme_font_size_override("font_size", 14)
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(objective_label)
	feedback_label = Label.new(); feedback_label.add_theme_font_size_override("font_size", 14)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(feedback_label)
	resized.connect(_layout_ui)
	_layout_ui()
	_refresh_panel()
	_fit_view()                                                # fit the opening town in view
	_open_menu(true)                                           # the game opens on the start menu
	set_process(true)


func fname(fac: int) -> String: return str(FACTIONS[fac].name)
func fcol(fac: int) -> Color: return FACTIONS[fac].col


# ============================================================ TOWN GENERATION
# A different town every run: cells may be gaps, positions jitter, streets are missing or diagonal,
# downtown is rich and well defended, the rim is poor and soft. Everything stays connected.
func _gen() -> void:
	if town_seed == 0:
		rng.randomize(); town_seed = int(rng.randi() % 900000) + 1
	rng.seed = town_seed
	var sz := get_viewport_rect().size
	hosts = []; hub = -1; rig = {}; _cell = {}; _highways = {}; flights = []; _res = {}; _next_depart = {}; _next_cash = {}
	intel = {}; cash = {}; _ai = {}; creds = {}; research = {}; cards = {}; lab = {}; _fx = []; _worms = []; _hold = {}
	for fac in botnets:
		intel[fac] = INTEL_START; cash[fac] = 0.0; scans[fac] = {}; creds[fac] = 0.0; research[fac] = 0.0
		cards[fac] = {}; lab[fac] = {"queue": [], "progress": 0.0, "paused": false, "stall": ""}; card_plays[fac] = 0; _hold[fac] = 0.0
	for fac in ais: _ai[fac] = {"timer": float(AI_PROFILE[fac].cadence) * (0.5 + 0.3 * float(fac)), "ops": {}, "avoid": -1, "dead": false, "lost": {}, "edges": {}, "threat_seen": {}}
	# fixed WORLD spacing between cells → the map never crowds; the view is fit around it afterwards (_fit_view)
	var cell := 190.0
	var sx := cell; var sy := cell
	var ax := 0.0; var ay := 0.0
	var centre := Vector2(float(_cols - 1) * 0.5, float(_rows - 1) * 0.5)
	var hub_cell := Vector2i(int(centre.x) + (rng.randi() % 2), int(centre.y) + (rng.randi() % 2))
	# each botnet starts in a corner: you top-left, the enemies in the other corners (only the active ones)
	var corner := {
		RIVAL:  [Vector2i(_cols - 1, _rows - 1), Vector2i(_cols - 1, _rows - 2)],
		RIVAL2: [Vector2i(0, _rows - 1), Vector2i(0, _rows - 2)],
		RIVAL3: [Vector2i(_cols - 1, 0), Vector2i(_cols - 2, 0)],
	}
	var starts := {PLAYER: [Vector2i(0, 0), Vector2i(0, 1)]}
	for fac in ais: starts[fac] = corner[fac]
	var forced := [hub_cell]
	for fac in starts.keys(): forced += starts[fac]
	for gy in _rows:
		for gx in _cols:
			var c := Vector2i(gx, gy)
			if not forced.has(c) and rng.randf() < EMPTY_CELL: continue   # a park, a lot, a void
			var is_hub: bool = c == hub_cell
			var dist: float = Vector2(gx, gy).distance_to(centre) / centre.length()   # 0 downtown … 1 corner
			var value := 3 if (is_hub or dist < 0.38) else (2 if dist < 0.72 else 1)
			if not is_hub and rng.randf() < 0.2: value = clampi(value + (1 if rng.randf() < 0.5 else -1), 1, 3)
			var ntype := "erp" if is_hub else _pick_type(value)
			var tp: Dictionary = NODE_TYPES[ntype]
			var sec := 30.0 if is_hub else clampf(float(2 + value * 5 + int(rng.randi() % 6) + int(tp.sec)), 4.0, 28.0)   # 4…28 defenders
			var slots := int(tp.slots)
			var p := Vector2(ax + sx * float(gx), ay + sy * float(gy)) + Vector2(rng.randf_range(-0.18, 0.18) * sx, rng.randf_range(-0.09, 0.09) * sy)
			_cell[c] = hosts.size()
			if is_hub: hub = hosts.size()
			hosts.append({"pos": p, "grid": c, "hub": is_hub, "rig": false,
				"name": "HUB" if is_hub else "%s %d" % [str(tp.short), hosts.size() + 1], "type": ntype,
				"links": [], "owner": NEUTRAL, "bots": sec, "sec": sec, "value": value, "slots": slots,
				"builds": _slot_array(["bot", "bot"] if is_hub else ["bot"], slots), "jobs": {}, "assign": -1, "live": false, "mode": "attack", "rate": 1.0,
				"prod_off": 0.0, "route_off": 0.0, "steal_until": -100.0, "steal_by": -1, "hit_t": -100.0, "junction": false})
	for c in _cell.keys():   # streets: grid neighbours (some missing), a few diagonals (never crossing)
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb: Vector2i = c + d
			if not _cell.has(nb): continue
			var must := false
			for fac in starts.keys():
				if (starts[fac] as Array).has(c) and (starts[fac] as Array).has(nb): must = true
			if must or rng.randf() < LINK_KEEP: _link(_cell[c], _cell[nb])
		var se: Vector2i = c + Vector2i(1, 1)
		if _cell.has(se) and rng.randf() < DIAG_P: _link(_cell[c], _cell[se])
		var ne: Vector2i = c + Vector2i(1, -1)
		var up: Vector2i = c + Vector2i(0, -1)
		var rt: Vector2i = c + Vector2i(1, 0)
		if _cell.has(ne) and rng.randf() < DIAG_P:
			var crosses: bool = _cell.has(up) and _cell.has(rt) and (hosts[_cell[up]].links as Array).has(_cell[rt])
			if not crosses: _link(_cell[c], _cell[ne])
	for gy in _rows:   # HIGHWAYS: a street across a gap, joining the buildings on either side — nothing to cross
		for gx in _cols:
			var g := Vector2i(gx, gy)
			if _cell.has(g): continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var a: Vector2i = g - d; var b: Vector2i = g + d
				if _cell.has(a) and _cell.has(b) and rng.randf() < HIGHWAY_P:
					_link(_cell[a], _cell[b]); _highways[_lk(_cell[a], _cell[b])] = true
	var cands := []   # JUNCTIONS: the best-connected crossroads of the mid town — their streets carry double traffic
	for i in hosts.size():
		if bool(hosts[i].hub) or forced.has(hosts[i].grid) or int(hosts[i].value) < 2 or (hosts[i].links as Array).size() < 3: continue
		cands.append([(hosts[i].links as Array).size() + rng.randf() * 0.5, i])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	for k in mini(JUNCTIONS, cands.size()): hosts[int(cands[k][1])].junction = true
	var guard := 0   # connect every island to the main town by its shortest gap
	while guard < 64:
		guard += 1
		var comps := _components()
		if comps.size() <= 1: break
		var main: Array = comps[0]
		var best := INF; var pa := -1; var pb := -1
		for k in range(1, comps.size()):
			for a in main:
				for b in comps[k]:
					var dd: float = (hosts[int(a)].pos as Vector2).distance_to(hosts[int(b)].pos)
					if dd < best: best = dd; pa = int(a); pb = int(b)
		if pa >= 0: _link(pa, pb)
	# every botnet starts with a rig (its Cash sink) and one more building
	_claim(_cell[starts[PLAYER][0]], PLAYER, true, "YOUR RIG")
	_claim(_cell[starts[PLAYER][1]], PLAYER, false, "")
	for fac in ais:   # each active enemy claims its corner rig + a second building
		_claim(_cell[starts[fac][0]], fac, true, "%s RIG" % fname(fac))
		_claim(_cell[starts[fac][1]], fac, false, "")


func _components() -> Array:   # connected groups of buildings over the street network, ownership ignored
	var seen := {}; var out := []
	for s in hosts.size():
		if seen.has(s): continue
		var comp := [s]; seen[s] = true; var head := 0
		while head < comp.size():
			var c: int = comp[head]; head += 1
			for o in hosts[c].links:
				if not seen.has(o): seen[o] = true; comp.append(int(o))
		out.append(comp)
	out.sort_custom(func(a, b): return a.size() > b.size())
	return out


func _claim(i: int, fac: int, is_rig: bool, nm: String) -> void:   # every botnet starts with a Server rig + a PC
	hosts[i].owner = fac; hosts[i].value = 1
	hosts[i].type = "server" if is_rig else "pc"; hosts[i].slots = int(NODE_TYPES[hosts[i].type].slots)
	if is_rig:
		hosts[i].rig = true; rig[fac] = i; hosts[i].builds = _slot_array(["bot", "bot"], int(hosts[i].slots))
	else:
		hosts[i].builds = _slot_array(_built_kinds(i), int(hosts[i].slots))
		hosts[i].name = "PC %d" % (i + 1)
	hosts[i].bots = _cap_of(i)   # a claimed building starts FULL at its (stacked) cap
	if nm != "": hosts[i].name = nm


func _pick_type(value: int) -> String:   # weighted by district: soft IoT and PCs on the rim, data and ERP downtown
	var w: Dictionary = TYPE_WEIGHTS[clampi(value, 1, 3)]
	var r := rng.randf(); var acc := 0.0
	for k in w.keys():
		acc += float(w[k])
		if r <= acc: return str(k)
	return str(w.keys()[w.size() - 1])


func _tmult(i: int, what: String) -> float:   # the building type's multiplier for "bot", "intel", "cash", "cred" or "research"
	return float(NODE_TYPES[str(hosts[i].get("type", "pc"))].get(what, 1.0))


func _regen(i: int) -> float:   # bots/s the building regenerates (its working Bot farms × its type)
	return float(_count(i, "bot")) * PROD_RATE * _tmult(i, "bot")


# ---- scanning ----
func _contents_key(i: int) -> String:   # what a scan learned; any change inside invalidates it
	return ",".join(PackedStringArray(hosts[i].builds))


func _scan_cost(i: int) -> float:   # scan bots needed: a fixed protection plus more per building inside
	return SCAN_BASE + SCAN_PER_BUILD * float(_built_kinds(i).size())


func _scanned(fac: int, t: int) -> bool:   # you always know your own buildings
	if t < 0 or fac == NEUTRAL: return false
	if int(hosts[t].owner) == fac: return true
	var rec: Dictionary = (scans[fac] as Dictionary).get(t, {})
	return not rec.is_empty() and bool(rec.done) and str(rec.key) == _contents_key(t)


func _scan_progress(fac: int, t: int) -> float:
	var rec: Dictionary = (scans[fac] as Dictionary).get(t, {})
	if rec.is_empty() or str(rec.key) != _contents_key(t): return 0.0
	return float(rec.progress)


func _mark_scanned(fac: int, t: int) -> void:   # scripts/probes and the moment a scan completes
	scans[fac][t] = {"key": _contents_key(t), "done": true, "progress": _scan_cost(t), "bots": float(hosts[t].bots), "cap": _cap_of(t), "at": _t}


func _scan_land(fac: int, t: int) -> void:   # one scan bot arrived: progress, and completion stands wires down
	var key := _contents_key(t)
	var rec: Dictionary = (scans[fac] as Dictionary).get(t, {})
	if rec.is_empty() or str(rec.key) != key:   # a fresh scan; what was seen before stays as memory
		var fresh := {"key": key, "done": false, "progress": 0.0}
		for mk in ["bots", "cap", "at"]:
			if rec.has(mk): fresh[mk] = rec[mk]
		rec = fresh
	if bool(rec.done): return                       # already revealed — a late scan bot is simply spent
	rec.progress = float(rec.progress) + 1.0
	if float(rec.progress) >= _scan_cost(t): rec.done = true; rec.bots = float(hosts[t].bots); rec.cap = _cap_of(t); rec.at = _t   # what was seen, when
	scans[fac][t] = rec
	if not bool(rec.done): return
	var stood := 0
	for i in hosts.size():   # a secret scan is done: its flows stand down; attacking is a separate, explicit launch
		if int(hosts[i].owner) == fac and int(hosts[i].assign) == t and bool(hosts[i].live) and str(hosts[i].get("mode", "attack")) == "scan":
			hosts[i].live = false; _next_depart.erase(i); stood += 1
	if fac == PLAYER:
		if stood > 0: _flash("🔍 Scanned %s quietly — %d bots, inside: %s. Press ATTACK to launch." % [str(hosts[t].name), int(round(float(hosts[t].bots))), _build_names(hosts[t].builds)])
		else: _flash("Attack revealed %s · %d defenders" % [str(hosts[t].name), int(round(float(hosts[t].bots)))], 0)
		_refresh_panel()


func _slot_array(kinds: Array, n: int) -> Array:   # positional slots, "" = empty
	var out := []
	for k in n: out.append(str(kinds[k]) if k < kinds.size() else "")
	return out


func _set_builds(i: int, kinds: Array) -> void:   # scripts/probes: place these kinds from slot 1, pad with empties
	hosts[i].slots = maxi(int(hosts[i].slots), kinds.size())
	hosts[i].builds = _slot_array(kinds, int(hosts[i].slots))


func _built_kinds(i: int) -> Array:   # kinds present, in slot order (empties skipped)
	var out := []
	for b in hosts[i].builds:
		if str(b) != "": out.append(str(b))
	return out


func _link(a: int, b: int) -> void:
	if a == b: return
	if not (hosts[a].links as Array).has(b): hosts[a].links.append(b)
	if not (hosts[b].links as Array).has(a): hosts[b].links.append(a)


func cell_at(gx: int, gy: int) -> int:   # host index at a grid cell, or -1 for a gap
	return int(_cell.get(Vector2i(gx, gy), -1))


func _mine(i: int) -> bool: return i >= 0 and int(hosts[i].owner) == PLAYER


func _routing_down(i: int) -> bool: return float(hosts[i].get("route_off", 0.0)) > 0.0   # a card cut its routing


func _stolen(i: int) -> bool: return float(hosts[i].get("steal_until", -100.0)) > _t and int(hosts[i].get("steal_by", -1)) in botnets and not _eliminated.has(int(hosts[i].get("steal_by", -1)))


func _benef(i: int) -> int:   # who gets i's production right now: the supply-chain thief, else the owner
	return int(hosts[i].steal_by) if _stolen(i) else int(hosts[i].owner)


func _prod_down(i: int) -> bool: return float(hosts[i].get("prod_off", 0.0)) > 0.0       # a card switched it off


func _is_botnet(fac: int) -> bool: return fac != NEUTRAL


func _bot_farms(i: int) -> int:   # how many Bot farms are BUILT here (not stage-limited) — each stacks the cap
	var n := 0
	for b in hosts[i].builds:
		if str(b) == "bot": n += 1
	return n


func _cap_of(i: int) -> float:   # neutral: its own security; owned: NODE_CAP PER Bot farm (2 farms → 60)
	if int(hosts[i].owner) == NEUTRAL: return float(hosts[i].sec)
	return NODE_CAP * float(maxi(1, _bot_farms(i)))


func _r(i: int) -> float:   # drawn radius grows with the building's slots
	return 11.0 + 2.5 * float(hosts[i].slots)


# route packets travel: BFS over same-faction buildings from src to one bordering t, then the final hop
func _route(src: int, t: int) -> Array:
	if src < 0 or t < 0 or src == t: return []
	var fac := int(hosts[src].owner)
	var prev := {src: src}; var q := [src]; var head := 0; var hit := -1
	while head < q.size():
		var c: int = q[head]; head += 1
		for o in hosts[c].links:
			if int(o) == t: hit = c; break
		if hit >= 0: break
		for o in hosts[c].links:
			if int(hosts[o].owner) == fac and not prev.has(o) and not _routing_down(int(o)): prev[o] = c; q.append(o)
	if hit < 0: return []
	var p := [hit]
	while int(p[p.size() - 1]) != src: p.append(prev[p[p.size() - 1]])
	p.reverse(); p.append(t)
	return p





# ---- link capacity: a link direction admits LINK_CAP packets per LINK_TIME; later ones queue ----
func _lkey(a: int, b: int) -> String: return "%d>%d" % [a, b]


func _link_cap(a: int, b: int) -> int:   # packets a link direction admits per LINK_TIME; a junction's streets carry more
	return LINK_CAP * (JUNCTION_CAP_MULT if (bool(hosts[a].get("junction", false)) or bool(hosts[b].get("junction", false))) else 1)


func _key_cap(key: String) -> int:
	var ab := key.split(">")
	return _link_cap(int(ab[0]), int(ab[1]))


# earliest time >= t at which link direction `key` can admit one more packet
func _link_entry(key: String, t: float) -> float:
	var arr: Array = _res.get(key, [])
	var cap := _key_cap(key)
	var e := t
	var guard := 0
	while guard < 10000:
		guard += 1
		var oldest := INF; var n := 0
		for x in arr:
			var xf := float(x)
			if xf > e - LINK_TIME and xf <= e + 0.00001:
				n += 1
				if xf < oldest: oldest = xf
		if n < cap: return e
		e = oldest + LINK_TIME + 0.0001
	return e


func _reserve(key: String, e: float) -> void:
	if not _res.has(key): _res[key] = []
	var arr: Array = _res[key]
	var k := arr.size()
	while k > 0 and float(arr[k - 1]) > e: k -= 1
	arr.insert(k, e)


func _prune_res() -> void:
	for key in _res.keys():
		var arr: Array = _res[key]
		while not arr.is_empty() and float(arr[0]) < _t - LINK_TIME - 0.01: arr.remove_at(0)
		if arr.is_empty(): _res.erase(key)


# schedule a packet along rt departing at dep: every hop waits for room on its link (queue at the
# building), then crosses it; intermediate buildings add NODE_ROUTE_DELAY. The timeline is fixed here.
func _schedule(rt: Array, dep: float, fac: int, kind: String, amount := 1.0) -> Dictionary:
	var hops := []
	var t := dep
	for k in range(rt.size() - 1):
		var key := _lkey(int(rt[k]), int(rt[k + 1]))
		var e := _link_entry(key, t)
		_reserve(key, e)
		hops.append(e)
		t = e + LINK_TIME
		if k < rt.size() - 2: t += NODE_ROUTE_DELAY
	return {"route": rt, "hops": hops, "depart_t": dep, "arrive_t": t, "owner": fac, "kind": kind, "amount": amount}


func _first_wait(rt: Array) -> float:   # how long the first link would make this packet wait right now
	if rt.size() < 2: return 0.0
	return _link_entry(_lkey(int(rt[0]), int(rt[1])), _t) - _t


# uncongested travel time: hops × LINK_TIME + intermediate buildings × NODE_ROUTE_DELAY
func _travel_time(rt: Array) -> float:
	if rt.size() < 2: return 0.0
	return float(rt.size() - 1) * LINK_TIME + float(maxi(0, rt.size() - 2)) * NODE_ROUTE_DELAY


# where a packet is at time `now`: queued at a building, crossing a link, or arrived
func _packet_pos(f: Dictionary, now: float) -> Vector2:
	var rt: Array = f.route
	var hops: Array = f.hops
	if rt.size() < 2: return hosts[int(rt[0])].pos
	for k in hops.size():
		var h := float(hops[k])
		if now < h: return hosts[int(rt[k])].pos
		if now < h + LINK_TIME: return (hosts[int(rt[k])].pos as Vector2).lerp(hosts[int(rt[k + 1])].pos, (now - h) / LINK_TIME)
	return hosts[int(rt[rt.size() - 1])].pos


func _link_busy(a: int, b: int) -> bool:   # either direction at capacity right now
	for key in [_lkey(a, b), _lkey(b, a)]:
		var n := 0
		for x in _res.get(key, []):
			if float(x) > _t - LINK_TIME and float(x) <= _t: n += 1
		if n >= _link_cap(a, b): return true
	return false


func _link_kind(src: int, t: int) -> String:   # what a wire from src into t would be, "" if impossible
	if src < 0 or t < 0 or src == t or not _mine(src): return ""
	if _route(src, t).is_empty(): return ""
	return "defend" if _mine(t) else "attack"


func _player_nodes() -> int:
	return _faction_nodes(PLAYER)


func _faction_nodes(fac: int) -> int:
	var n := 0
	for h in hosts:
		if int(h.owner) == fac: n += 1
	return n


func _incoming(t: int, fac: int) -> float:   # bots of a faction currently flying toward t
	var s := 0.0
	for f in flights:
		if str(f.kind) == "bot" and int((f.route as Array)[(f.route as Array).size() - 1]) == t and int(f.owner) == fac: s += 1.0
	return s


func _hostile_incoming(t: int) -> float:   # bots of ANY other faction flying toward t
	var s := 0.0
	for f in flights:
		if str(f.kind) == "bot" and int((f.route as Array)[(f.route as Array).size() - 1]) == t and int(f.owner) != int(hosts[t].owner): s += 1.0
	return s


func _under_attack(t: int) -> bool:   # hostile attack bots inbound, a hostile LIVE attack wire aimed at it, or a recent card hit
	if _t - float(hosts[t].get("hit_t", -100.0)) < CARD_ALARM: return true
	if _hostile_incoming(t) > 0.0: return true
	for i in hosts.size():
		if int(hosts[i].owner) != int(hosts[t].owner) and bool(hosts[i].live) and int(hosts[i].assign) == t and str(hosts[i].get("mode", "attack")) != "scan": return true
	return false   # a secret scan raises no alarm


func _threat_rate(t: int) -> float:   # defenders/s the hostile LIVE wires into t remove — the attacker's rate dial is hidden: assume 100 %
	var r := 0.0
	for i in hosts.size():
		if int(hosts[i].owner) != int(hosts[t].owner) and bool(hosts[i].live) and int(hosts[i].assign) == t and str(hosts[i].get("mode", "attack")) != "scan":
			r += SEND_RATE * (ATTACK_POWER / DEFEND_POWER)
	return r


func _drain(t: int) -> float:   # bots/s the building itself is streaming out right now
	if _bot_target(t) >= 0 and _next_depart.has(t): return SEND_RATE * float(hosts[t].rate)
	return 0.0


# ---- control stages, buildings & the economy ----
func _stage(i: int) -> int:
	# More storage must never switch off a working building.
	var fr := float(hosts[i].bots) / NODE_CAP
	if fr >= STAGE_FULL: return 0
	if fr >= STAGE_SHAKY: return 1
	return 2


func _slot_busy(i: int, k: int) -> bool:   # a job is working on this slot; its building is offline meanwhile
	return (hosts[i].jobs as Dictionary).has(k)


func _built(i: int) -> Array:   # [slot, kind] of every standing building in slot order (busy slots excluded)
	var out := []
	var b: Array = hosts[i].builds
	for k in b.size():
		if str(b[k]) != "" and not _slot_busy(i, k): out.append([k, str(b[k])])
	return out


func _active_slots(i: int) -> int:   # a weakened building runs fewer of its slots (the first always works)
	return maxi(1, _built(i).size() - _stage(i))


func _slot_active(i: int, k: int) -> bool:   # is the building in slot k among the ones still working?
	if _prod_down(i): return false              # a card switched the whole building off
	var bl := _built(i); var act := _active_slots(i)
	for idx in bl.size():
		if int(bl[idx][0]) == k: return idx < act
	return false


func _count(i: int, kind: String) -> int:   # ACTIVE buildings of a kind (none while a card has production switched off)
	if _prod_down(i): return 0
	var n := 0
	var bl := _built(i)
	for k in mini(_active_slots(i), bl.size()):
		if str(bl[k][1]) == kind: n += 1
	return n


func _count_all(i: int, kind: String) -> int:   # built, active or not
	var n := 0
	for b in hosts[i].builds:
		if str(b) == kind: n += 1
	return n


func _free_slot(i: int) -> int:   # first empty slot not reserved by a running job, or -1
	var b: Array = hosts[i].builds
	for k in b.size():
		if str(b[k]) == "" and not _slot_busy(i, k): return k
	return -1


func _intel_cap(fac: int) -> float:   # every Intel harvester (built, working or not) raises the limit
	var n := 0
	for i in hosts.size():
		if int(hosts[i].owner) == fac: n += _count_all(i, "intel")
	return INTEL_CAP_BASE + INTEL_CAP_PER_BUILD * float(n)


func _res_cap(fac: int, kind: String) -> float:   # "cred" or "lab": the resource's limit grows with its buildings
	var n := 0
	for i in hosts.size():
		if int(hosts[i].owner) == fac: n += _count_all(i, kind)
	return RES_CAP_BASE + RES_CAP_PER_BUILD * float(n)


func _cred_rate(fac: int) -> float:
	var r := 0.0
	for i in hosts.size():
		if _benef(i) == fac: r += float(_count(i, "cred")) * CRED_PER_BUILD * _tmult(i, "cred")
	return r


func _research_rate(fac: int) -> float:
	var r := 0.0
	for i in hosts.size():
		if _benef(i) == fac: r += float(_count(i, "lab")) * RESEARCH_PER_BUILD * _tmult(i, "research")
	return r


func _kind_total(fac: int, kind: String) -> int:   # buildings of a kind a faction has built anywhere
	var n := 0
	for i in hosts.size():
		if int(hosts[i].owner) == fac: n += _count_all(i, kind)
	return n


func _pool(fac: int, r: String) -> float:   # "cash" | "creds" | "research"
	match r:
		"cash": return float(cash[fac])
		"creds": return float(creds[fac])
		_: return float(research[fac])


func _pool_add(fac: int, r: String, d: float) -> void:   # add to (or spend from) a resource pool, clamped to its cap
	match r:
		"cash": cash[fac] = float(cash[fac]) + d
		"creds": creds[fac] = float(creds[fac]) + d
		_: research[fac] = float(research[fac]) + d


func _intel_rate(fac: int) -> float:   # harvesters, plus the rig's own trickle while the botnet still holds it
	var r := 0.0
	for i in hosts.size():
		if _benef(i) == fac: r += float(_count(i, "intel")) * INTEL_PER_BUILD * _tmult(i, "intel")
	var home := int(rig.get(fac, -1))
	if home >= 0 and int(hosts[home].owner) == fac and not _prod_down(home): r += RIG_INTEL
	return r


func _cash_rate(fac: int) -> float:   # Cash/s a faction's active markets emit (a stolen market feeds the thief)
	var r := 0.0
	for i in hosts.size():
		if _benef(i) == fac: r += _cash_of_host(i)
	return r


func _cash_of_host(i: int) -> float:   # Cash/s this one market produces
	return float(_count(i, "cash")) * float(hosts[i].value) * _tmult(i, "cash") / CASH_INTERVAL


# one job per building. Into an EMPTY slot: build (BUILD_TIME). Onto an OCCUPIED slot: replace — the old
# building goes offline at once, the slot is cleared (DEMOLISH_TIME), then the new one is built (BUILD_TIME).
func _start_job(i: int, kind: String, slot := -1) -> bool:   # several jobs may run in one building; funding is shared over time, after attack packets
	if i < 0 or int(hosts[i].owner) == NEUTRAL or not BUILD_KINDS.has(kind): return false
	if slot < 0: slot = _free_slot(i)
	if slot < 0 or slot >= (hosts[i].builds as Array).size() or _slot_busy(i, slot): return false
	var cur := str(hosts[i].builds[slot])
	if cur == kind: return false
	var fac := int(hosts[i].owner)
	if float(intel[fac]) < BUILD_COST_INTEL: return false   # must be able to afford it, but it's PAID OVER THE BUILD
	if cur == "": hosts[i].jobs[slot] = {"kind": kind, "slot": slot, "phase": "build", "left": BUILD_TIME, "cost_left": BUILD_COST_INTEL}
	else: hosts[i].jobs[slot] = {"kind": kind, "slot": slot, "phase": "demolish", "left": DEMOLISH_TIME, "cost_left": BUILD_COST_INTEL}
	return true


func _can_drop(i: int, slot: int, kind: String) -> bool:   # a card held over a slot of a building you own
	if i < 0 or not _mine(i) or not BUILD_KINDS.has(kind): return false
	if slot < 0 or slot >= (hosts[i].builds as Array).size() or _slot_busy(i, slot): return false
	return str(hosts[i].builds[slot]) != kind


func _drop_build(i: int, slot: int, kind: String) -> void:   # a card dropped on a slot
	if not _can_drop(i, slot, kind): return
	var cur := str(hosts[i].builds[slot])
	if _start_job(i, kind, slot):
		if cur == "": _flash("Building %s in slot %d of %s — %.0f s · %d Intel" % [BUILD_KINDS[kind].name, slot + 1, str(hosts[i].name), BUILD_TIME, int(BUILD_COST_INTEL)])
		else: _flash("Replacing %s with %s in slot %d — %.0f s to clear, then %.0f s to build · %d Intel" % [BUILD_KINDS[cur].name, BUILD_KINDS[kind].name, slot + 1, DEMOLISH_TIME, BUILD_TIME, int(BUILD_COST_INTEL)])
	elif float(intel[PLAYER]) < BUILD_COST_INTEL: _flash("Not enough Intel — a build costs %d" % int(BUILD_COST_INTEL))
	_refresh_panel(); queue_redraw()


func _card_click(kind: String) -> void:   # clicking a card (no drag) builds into the first empty slot of the selected building
	var i := _build_site()
	if i < 0: return
	var s := _free_slot(i)
	if s < 0:
		_flash("No empty slot — drag the card onto an occupied slot to replace that building")
		return
	_drop_build(i, s, kind)


func _build_site() -> int:   # the one building of yours whose slot board is open: a single own selection
	if sel.size() != 1: return _inspect if _mine(_inspect) else -1
	var i := int(sel.keys()[0])
	return i if _mine(i) else -1


func _player_build(i: int, kind: String) -> void:   # script helper: first empty slot of the building you are in
	_drop_build(i, _free_slot(i), kind)


func _toggle_job(i: int, slot: int) -> void:
	if not _mine(i) or not (hosts[i].jobs as Dictionary).has(slot): return
	var job: Dictionary = hosts[i].jobs[slot]
	job["paused"] = not bool(job.get("paused", false))
	_refresh_panel(); queue_redraw()


func _cancel_job(i: int, slot: int) -> void:   # a cancelled job refunds nothing
	if i >= 0: (hosts[i].jobs as Dictionary).erase(slot)
	_refresh_panel(); queue_redraw()


func _demolish(i: int, slot: int) -> void:   # clear a slot (DEMOLISH_TIME); the building is offline meanwhile
	if i < 0 or slot < 0 or slot >= (hosts[i].builds as Array).size(): return
	if str(hosts[i].builds[slot]) == "" or _slot_busy(i, slot): return
	hosts[i].jobs[slot] = {"kind": "", "slot": slot, "phase": "demolish", "left": DEMOLISH_TIME}
	_flash("Demolishing %s in slot %d of %s — %.0f s" % [BUILD_KINDS[str(hosts[i].builds[slot])].name, slot + 1, str(hosts[i].name), DEMOLISH_TIME])
	_refresh_panel(); queue_redraw()


# build jobs run on their own: several per building, nobody has to stay and watch them
func _tick_jobs(dt: float) -> void:
	# Attacks have first use of Intel. Keep the next packet's fractional funding
	# between frames, then share the remainder proportionally across all jobs.
	var demand := {}
	var budget := {}
	for fac in botnets:
		demand[fac] = 0.0
		budget[fac] = maxf(0.0, float(intel[fac]) - _attack_reserve(fac))
	for h in hosts:
		var fac := int(h.owner)
		if fac == NEUTRAL: continue
		for job in (h.jobs as Dictionary).values():
			if str(job.phase) == "build" and not bool(job.get("paused", false)): demand[fac] += minf(float(job.cost_left), BUILD_COST_INTEL / BUILD_TIME * dt)
	for i in hosts.size():
		var jobs: Dictionary = hosts[i].jobs
		var fac := int(hosts[i].owner)
		if fac == NEUTRAL: continue
		for slot_key in jobs.keys():
			var job: Dictionary = jobs[slot_key]
			if bool(job.get("paused", false)): continue
			var work := dt
			if str(job.phase) == "build":
				var requested := minf(float(job.cost_left), BUILD_COST_INTEL / BUILD_TIME * dt)
				var fraction := minf(1.0, float(budget[fac]) / maxf(0.000001, float(demand[fac])))
				var pay := requested * fraction
				intel[fac] = maxf(0.0, float(intel[fac]) - pay)
				job.cost_left = maxf(0.0, float(job.cost_left) - pay)
				work = pay / (BUILD_COST_INTEL / BUILD_TIME)
				job["funding"] = fraction
			job.left = maxf(0.0, float(job.left) - work)
			if float(job.left) > 0.00001: continue
			var slot := int(job.slot)
			if str(job.phase) == "demolish":
				hosts[i].builds[slot] = ""
				if str(job.kind) != "":
					job.phase = "build"; job.left = BUILD_TIME
					continue
			else: hosts[i].builds[slot] = str(job.kind)
			jobs.erase(slot_key)
			if fac == PLAYER: _flash("%s · slot %d ready" % [str(hosts[i].name), slot + 1], 0)


func _attack_reserve(fac: int) -> float:
	for i in hosts.size():
		if int(hosts[i].owner) != fac or not bool(hosts[i].live) or _routing_down(i): continue
		var t := _bot_target(i)
		if t < 0 or int(hosts[t].owner) == fac or _route(i, t).is_empty(): continue
		if float(hosts[i].bots) - 1.0 < _reserve_of(i): continue
		if str(hosts[i].mode) == "scan" and (_scanned(fac, t) or _scan_pending(fac, t)): continue
		return 1.0
	return 0.0


func _scan_pending(fac: int, target: int) -> bool:
	for flight in flights:
		if int(flight.owner) == fac and str(flight.kind) == "scan" and int(flight.route.back()) == target: return true
	return false


func _check_rigs() -> void:
	# A rig is the same elimination condition for every faction. Resolve it
	# before majority checks, including captures within an arrival batch.
	for fac in botnets:
		if _eliminated.has(fac) or int(hosts[int(rig[fac])].owner) == fac: continue
		_eliminated[fac] = true
		if fac == PLAYER:
			lost = true; won = false; _end_cause = "Your rig was captured. Protect it to stay in the game."
		else: _ai[fac].dead = true
		lab[fac].queue = []; lab[fac].progress = 0.0
		for i in hosts.size():
			if int(hosts[i].owner) != fac: continue
			hosts[i].owner = NEUTRAL; hosts[i].sec = maxf(1.0, float(hosts[i].bots))
			hosts[i].jobs = {}; hosts[i].assign = -1; hosts[i].live = false
			_next_depart.erase(i); _next_cash.erase(i)
		if fac != PLAYER: _flash("%s eliminated · its remaining buildings are neutral" % fname(fac), 0)


func _record_observations() -> void:
	_departures = _departures.filter(func(d): return float(d.at) > _t - 4.0)
	_resource_samples.append({"at": _t, "intel": float(intel[PLAYER]), "cash": float(cash[PLAYER]), "creds": float(creds[PLAYER]), "research": float(research[PLAYER])})
	while _resource_samples.size() > 1 and float(_resource_samples[1].at) < _t - 4.0: _resource_samples.pop_front()
	for i in hosts.size():
		if not _scanned(PLAYER, i): _defender_samples.erase(i); continue
		var samples: Array = _defender_samples.get(i, [])
		samples.append({"at": _t, "bots": float(hosts[i].bots)})
		while samples.size() > 1 and float(samples[1].at) < _t - 4.0: samples.pop_front()
		_defender_samples[i] = samples


func _observed_net(res: String) -> float:
	if _resource_samples.size() < 2: return 0.0
	var first: Dictionary = _resource_samples.front()
	var last: Dictionary = _resource_samples.back()
	return (float(last[res]) - float(first[res])) / maxf(0.001, float(last.at) - float(first.at))


func _bank(fac: int, amount: float) -> void:   # Cash only fuels cards now; capturing ground is the win
	cash[fac] = float(cash[fac]) + amount


func _control_need() -> int:   # buildings a faction must exceed to hold the majority
	return int(floor(HOLD_FRACTION * float(hosts.size())))


func _win_for(fac: int, cause: String) -> void:
	if won or lost: return
	_end_cause = cause
	if fac == PLAYER: won = true
	else: lost = true


func _bot_sum(fac: int) -> float:
	var b := 0.0
	for h in hosts:
		if int(h.owner) == fac: b += float(h.bots)
	return b


func _control_leader() -> int:   # the botnet holding the most buildings (ties: the most bots, then faction order)
	var best := -1; var bn := -1; var bb := -1.0
	for fac in botnets:
		var n := _faction_nodes(fac); var b := _bot_sum(fac)
		if n > bn or (n == bn and b > bb): bn = n; bb = b; best = fac
	return best


func _tick_domination(dt: float) -> void:   # a true majority held wins; the last botnet standing wins; there is no clock
	var need := _control_need()
	var alive := []
	for fac in botnets:
		if _faction_nodes(fac) > 0: alive.append(fac)
		if _faction_nodes(fac) > need: _hold[fac] = float(_hold[fac]) + dt
		else: _hold[fac] = 0.0
	for fac in botnets:
		if float(_hold[fac]) >= HOLD_SECS:
			_win_for(fac, ("You held the majority for %d s." % int(HOLD_SECS)) if fac == PLAYER else ("%s held the majority for %d s." % [fname(fac), int(HOLD_SECS)]))
			return
	if alive.size() == 1:
		_win_for(int(alive[0]), "You are the last botnet standing." if int(alive[0]) == PLAYER else "%s wiped out the other botnets." % fname(int(alive[0])))


# ---- who sends what where ----
func _reserve_of(i: int) -> float:   # garrison a source keeps at home
	if int(hosts[i].owner) != PLAYER: return AI_RESERVE
	return 0.0


# where a building's bots go right now: its wire if LIVE; a dormant wire, or no wire, sends nothing
func _bot_target(i: int) -> int:
	var a := int(hosts[i].assign)
	if a >= 0: return a if bool(hosts[i].live) else -1
	return -1


func _attack_demand(fac: int) -> float:   # Intel/s a faction's LIVE attack flows would spend
	var n := 0.0
	for i in hosts.size():
		var t := int(hosts[i].assign)
		if int(hosts[i].owner) == fac and bool(hosts[i].live) and t >= 0 and int(hosts[t].owner) != fac and not _route(i, t).is_empty():
			n += SEND_RATE * float(hosts[i].rate)
	return n


# why a source isn't delivering right now — drives the cause→action diagnostics
func _src_state(s: int) -> String:
	var fac := int(hosts[s].owner)
	var a := int(hosts[s].assign)
	if _routing_down(s) and (a >= 0 or _bot_target(s) >= 0): return "routing cut"
	if a >= 0:
		var rt := _route(s, a)
		if rt.is_empty(): return "no route"
		if int(hosts[a].owner) == fac:                        # guard wire: the STATUS does the work
			if not bool(hosts[s].live): return "guarding (standby)"
			return "defending" if float(hosts[s].bots) - 1.0 >= _reserve_of(s) else "defending · no bots"
		if not bool(hosts[s].live): return "wired (not launched)"
		if float(hosts[s].bots) - 1.0 < _reserve_of(s): return "no bots"
		if str(hosts[s].mode) == "scan" and _scan_pending(fac, a): return "scan in transit"
		if float(intel[fac]) < 1.0 and (SCAN_COSTS_INTEL or str(hosts[s].mode) != "scan"): return "no Intel"
		if _first_wait(rt) > MAX_QUEUE: return "link busy"
		return "scanning" if str(hosts[s].get("mode", "attack")) == "scan" else "sending"
	var tgt := _bot_target(s)
	if tgt < 0: return "idle"
	var rt2 := _route(s, tgt)
	if rt2.is_empty(): return "no route"
	if float(hosts[s].bots) - 1.0 < _reserve_of(s): return "garrison"
	if _first_wait(rt2) > MAX_QUEUE: return "link busy"
	return "sending"


# ============================================================ LOOP
func _process(dt: float) -> void:
	if _msg_t > 0.0: _msg_t -= dt
	if not paused and not menu_open and not won and not lost:
		_t += dt                        # the shared clock only advances while playing → pause freezes everything
		for i in hosts.size():
			var nb := _count(i, "bot")
			if nb > 0 and float(hosts[i].bots) < _cap_of(i):
				hosts[i].bots = minf(_cap_of(i), float(hosts[i].bots) + _regen(i) * dt)
		for fac in botnets:
			intel[fac] = minf(_intel_cap(fac), float(intel[fac]) + _intel_rate(fac) * dt)
			creds[fac] = minf(_res_cap(fac, "cred"), float(creds[fac]) + _cred_rate(fac) * dt)
			research[fac] = minf(_res_cap(fac, "lab"), float(research[fac]) + _research_rate(fac) * dt)
		for i in hosts.size():   # card effects wear off
			if float(hosts[i].prod_off) > 0.0: hosts[i].prod_off = maxf(0.0, float(hosts[i].prod_off) - dt)
			if float(hosts[i].route_off) > 0.0: hosts[i].route_off = maxf(0.0, float(hosts[i].route_off) - dt)
			if _stolen(i):   # intel/cred/research already route to the thief via _benef; credit its Cash too
				var thief := int(hosts[i].steal_by)
				cash[thief] = float(cash[thief]) + _cash_of_host(i) * (ai_cash_mult if thief != PLAYER else 1.0) * dt
		_tick_research(dt)
		_fx = _fx.filter(func(x): return float(x.until) > _t)
		_worms = _worms.filter(func(x): return float(x.until) > _t)
		_ai_remember(PLAYER)   # your memory of a scanned building stays as fresh as the AI's
		_prune_res()
		_auto_guards()      # guard wires arm themselves while their building is threatened, stand down after
		_emit_due()
		_tick_jobs(dt)
		if not won and not lost: _deliver_due()      # chronological; may set won/lost and then stops
		if not won and not lost and not _ai_paused: _ai_tick(dt)   # the tutorial freezes the AI early on
		_check_rigs()
		if not won and not lost: _tick_domination(dt)
		if not won and not lost and int(hosts[int(rig[PLAYER])].owner) != PLAYER: lost = true; _end_cause = "Your rig was captured — the botnet is finished."
		if not won and not lost and _player_nodes() == 0: lost = true; _end_cause = "You lost your last building."
		for fac in ais:
			if not bool(_ai[fac].dead) and _faction_nodes(fac) == 0:
				_ai[fac].dead = true; _flash("%s is out of the game" % fname(fac))
		_panel_t += dt
		if _panel_t >= 0.25:
			_panel_t = 0.0; _record_observations(); _tick_tutorial(); _refresh_panel()
	if (won or lost) and not _end_shown:
		_end_shown = true; _refresh_panel()
	_update_chrome()
	var hs := _hand_signature()
	if hs != _hand_sig: _hand_sig = hs; _refresh_hand()   # rebuild the bottom hand only when it changes
	if menu_open:
		_menu_t += dt; queue_redraw()                     # keep the menu's drifting packets moving
		return
	# redraw only while something is actually moving, plus a light heartbeat for regen/number updates
	_redraw_t += dt
	var animating: bool = not paused and (not flights.is_empty() or not _worms.is_empty() or not _fx.is_empty() or _dragging)
	if animating or _redraw_t >= 0.2:
		_redraw_t = 0.0
		hud.queue_redraw()
		queue_redraw()


# "Attack and defend is the STATUS": a wire into a building of the SAME faction is a GUARD — it stands by
# dormant and starts flowing AUTOMATICALLY the moment the protected building is under attack (or below
# full, counting help already in the air), then stands down again. Guards are never launched or stopped
# by hand. The same rule serves every botnet.
func _auto_guards() -> void:
	for s in hosts.size():
		var fac := int(hosts[s].owner)
		if fac == NEUTRAL: continue
		var t := int(hosts[s].assign)
		if t < 0 or int(hosts[t].owner) != fac: continue
		var want: bool = _under_attack(t) or (float(hosts[t].bots) + _incoming(t, fac) < _cap_of(t) - 0.25)
		if want and not bool(hosts[s].live):
			hosts[s].live = true; _next_depart[s] = _t
		elif not want and bool(hosts[s].live):
			hosts[s].live = false; _next_depart.erase(s)


func _can_emit(i: int) -> bool:
	var tgt := _bot_target(i)
	if tgt < 0 or not _next_depart.has(i) or _routing_down(i): return false
	if float(_next_depart[i]) > _t: return false
	if float(hosts[i].bots) - 1.0 < _reserve_of(i): return false
	var fac := int(hosts[i].owner)
	var hostile: bool = int(hosts[tgt].owner) != fac
	if hostile and str(hosts[i].get("mode", "attack")) == "scan" and (_scanned(fac, tgt) or _scan_pending(fac, tgt)): return false   # scan done
	if hostile and float(intel[fac]) < 1.0 and (SCAN_COSTS_INTEL or str(hosts[i].mode) != "scan"): return false
	if not hostile and int(hosts[i].assign) < 0:   # an unwired building sends nothing; kept as a guard
		if float(hosts[tgt].bots) + _incoming(tgt, fac) >= NODE_CAP - 0.001: return false
	var rt := _route(i, tgt)
	if rt.is_empty() or _first_wait(rt) > MAX_QUEUE: return false
	return true


func _can_emit_cash(i: int) -> bool:
	if not _next_cash.has(i) or float(_next_cash[i]) > _t or _routing_down(i): return false
	var fac := int(hosts[i].owner)
	if not rig.has(fac): return false
	if _stolen(i): return false   # its Cash is being siphoned by a supply-chain thief, credited directly
	var rg := int(rig[fac])
	if int(hosts[rg].owner) != fac: return false   # the sink is gone → Cash holds until it is retaken
	if i == rg: return true
	var rt := _route(i, rg)
	if rt.is_empty() or _first_wait(rt) > MAX_QUEUE: return false
	return true


# Release every DUE departure (bots AND Cash packets) in TIME order with a rotating tie-break, so no
# source wins scarce Intel or link room purely by index. A held source never builds a catch-up backlog.
func _emit_due() -> void:
	var n := hosts.size()
	for i in n:                                     # validate LIVE wires & seed departure clocks
		var a := int(hosts[i].assign)
		if a >= 0 and bool(hosts[i].live) and _route(i, a).is_empty():
			hosts[i].live = false; _next_depart.erase(i)   # flow pauses; the WIRE stays — relaunch when routed
			if _mine(i): _flash("%s's flow stopped — no route (connection kept; launch again when routed)" % str(hosts[i].name))
		var tgt := _bot_target(i)
		if tgt < 0: _next_depart.erase(i)
		elif not _next_depart.has(i): _next_depart[i] = _t
		if int(hosts[i].owner) != NEUTRAL and _count(i, "cash") > 0:
			if not _next_cash.has(i): _next_cash[i] = _t
		else: _next_cash.erase(i)
	var due := []    # only sources whose clock is due are candidates — the loop below re-checks just these
	var cdue := []
	for k in n:
		var i: int = (_emit_cursor + k) % n
		if _next_depart.has(i) and float(_next_depart[i]) <= _t: due.append(i)
		if _next_cash.has(i) and float(_next_cash[i]) <= _t: cdue.append(i)
	var guard := 0
	while guard < 4000 and (not due.is_empty() or not cdue.is_empty()):
		guard += 1
		var best := -1; var best_t := INF; var best_kind := ""
		for i in due:
			if _can_emit(i) and float(_next_depart[i]) < best_t:
				best = i; best_t = float(_next_depart[i]); best_kind = "bot"
		for i in cdue:
			if _can_emit_cash(i) and float(_next_cash[i]) < best_t:
				best = i; best_t = float(_next_cash[i]); best_kind = "cash"
		if best < 0: break
		var fac := int(hosts[best].owner)
		if best_kind == "bot":
			var tgt := _bot_target(best)
			hosts[best].bots = float(hosts[best].bots) - 1.0
			var hostile: bool = int(hosts[tgt].owner) != fac
			var pk := "scan" if (hostile and str(hosts[best].get("mode", "attack")) == "scan" and not _scanned(fac, tgt)) else "bot"
			if hostile and (pk == "bot" or SCAN_COSTS_INTEL): intel[fac] = float(intel[fac]) - 1.0   # spends Intel
			flights.append(_schedule(_route(best, tgt), best_t, fac, pk))
			if fac == PLAYER: _departures.append({"at": _t, "source": best, "target": tgt, "kind": pk})
			_next_depart[best] = best_t + 1.0 / (SEND_RATE * float(hosts[best].rate))
			if float(_next_depart[best]) > _t: due.erase(best)
		else:
			var rg := int(rig[fac])
			var amount := float(hosts[best].value) * _tmult(best, "cash") * (ai_cash_mult if fac != PLAYER else 1.0)
			if best == rg: _bank(fac, amount)        # the rig banks its own market directly
			else: flights.append(_schedule(_route(best, rg), best_t, fac, "cash", amount))
			_next_cash[best] = best_t + CASH_INTERVAL / float(_count(best, "cash"))
			if float(_next_cash[best]) > _t: cdue.erase(best)
			if won or lost: return
		_emit_cursor = best + 1
	for i in n:                                     # anti-burst: a held emitter doesn't accumulate a backlog
		if _next_depart.has(i) and float(_next_depart[i]) < _t: _next_depart[i] = _t
		if _next_cash.has(i) and float(_next_cash[i]) < _t: _next_cash[i] = _t


func _deliver_due() -> void:
	var due := []
	var rest := []
	for f in flights:
		if float(f.arrive_t) <= _t: due.append(f)
		else: rest.append(f)
	flights = rest
	due.sort_custom(_arrival_cmp)           # resolve by ARRIVAL TIME, independent of list order
	for f in due:
		if won or lost: break               # terminal reached — stop applying later arrivals
		_deliver(f)


# chronological; ties resolved deterministically: arrive time → target → the holder's reinforcements first
func _arrival_cmp(a: Dictionary, b: Dictionary) -> bool:
	if absf(float(a.arrive_t) - float(b.arrive_t)) > 0.0001: return float(a.arrive_t) < float(b.arrive_t)
	var ta := int((a.route as Array)[(a.route as Array).size() - 1])
	var tb := int((b.route as Array)[(b.route as Array).size() - 1])
	if ta != tb: return ta < tb
	var ra := int(a.owner) == int(hosts[ta].owner)
	var rb := int(b.owner) == int(hosts[tb].owner)
	return ra and not rb


# arrival applies: Cash → banked by whoever holds the sink; same faction → reinforce (capped);
# other faction → attrition; reduced to 0 → the building flips to the attacker
func _deliver(f: Dictionary) -> void:
	var rt: Array = f.route
	if rt.is_empty(): return
	var t: int = int(rt[rt.size() - 1])
	var fac := int(f.owner)
	if _eliminated.has(fac): return # packets remain visible but cannot resurrect an eliminated botnet
	if str(f.kind) == "cash":
		if int(hosts[t].owner) != NEUTRAL: _bank(int(hosts[t].owner), float(f.get("amount", 1.0)))
		return
	if str(f.kind) == "scan":   # consumed on arrival; reveals, never wounds
		if int(hosts[t].owner) != fac: _scan_land(fac, t)
		return
	if str(f.kind) == "card":   # a card packet: its effect lands now
		_land_card(fac, str(f.get("card", "stuff:linked")), t)
		return
	if int(hosts[t].owner) == fac:
		hosts[t].bots = minf(_cap_of(t), float(hosts[t].bots) + 1.0)
		return
	if not _scanned(fac, t): _scan_land(fac, t)   # any attack scans as it goes — loudly
	hosts[t].bots = float(hosts[t].bots) - (ATTACK_POWER / DEFEND_POWER)
	if float(hosts[t].bots) <= 0.0: _capture(t, fac)


# ownership changes: attack flows into a building the attacker CAPTURES become guards that top it up and
# stand down; wires of the LOSER into it stand down (kept, dormant) — retaking it is an explicit call
func _capture(t: int, fac: int) -> void:
	var prev := int(hosts[t].owner)
	var nm := str(hosts[t].name)
	if ais.has(prev): _ai[prev].lost[t] = {"to": fac, "at": _t}   # an AI remembers what it lost
	hosts[t].owner = fac
	for f in botnets:   # the capture is announced to everyone: a just-taken building is known to be near empty
		if f == fac or _scanned(f, t): continue
		var old: Dictionary = (scans[f] as Dictionary).get(t, {})
		scans[f][t] = {"key": str(old.get("key", "")), "done": bool(old.get("done", false)), "progress": 0.0, "bots": 0.0, "cap": NODE_CAP, "at": _t}
	hosts[t].bots = minf(NODE_CAP, -float(hosts[t].bots))
	hosts[t].assign = -1; hosts[t].live = false; hosts[t].jobs = {}; hosts[t].rate = 1.0
	hosts[t].builds = _slot_array([], int(hosts[t].slots))   # a captured building is empty inside: the new owner builds from scratch
	hosts[t].prod_off = 0.0; hosts[t].route_off = 0.0; hosts[t].steal_until = -100.0; hosts[t].steal_by = -1; hosts[t].hit_t = -100.0   # a new owner, a clean slate
	_next_depart.erase(t); _next_cash.erase(t)
	if fac != PLAYER:
		if sel.has(t): sel.erase(t)          # a selected building lost to a rival is uncontrollable
	var stood := 0                           # the loser's wires into it stand down, kept
	if prev != NEUTRAL:
		for i in hosts.size():
			if int(hosts[i].owner) == prev and int(hosts[i].assign) == t and bool(hosts[i].live):
				hosts[i].live = false; _next_depart.erase(i); stood += 1
	if fac == PLAYER:
		var flowing := 0
		for i in hosts.size():
			if _mine(i) and int(hosts[i].assign) == t and bool(hosts[i].live): flowing += 1
		var from := "" if prev == NEUTRAL else " from %s" % fname(prev)
		if flowing > 0: _flash("Captured %s%s — %d flow(s) now top it up as guards" % [nm, from, flowing])
		else: _flash("Captured %s%s" % [nm, from])
	elif prev == PLAYER:
		if stood > 0: _flash("Lost %s to %s — %d connection(s) stand down (press ATTACK there to retake)" % [nm, fname(fac), stood])
		else: _flash("Lost %s to %s" % [nm, fname(fac)])
	else:
		_flash("%s took %s%s" % [fname(fac), nm, ("" if prev == NEUTRAL else " from %s" % fname(prev))], 0)
	if _tut and t == _tut_target and fac == PLAYER: _tut_captured = true
	_check_rigs()
	if prev != NEUTRAL and not won and not lost:   # did that capture leave one botnet standing?
		var alive := []
		for f in botnets:
			if _faction_nodes(f) > 0: alive.append(f)
		if alive.size() == 1: _win_for(int(alive[0]), "You are the last botnet standing." if int(alive[0]) == PLAYER else "%s wiped out the other botnets." % fname(int(alive[0])))
	_refresh_panel()


# ============================================================ CARDS
func _card_key(card: String, reach: String) -> String: return "%s:%s" % [card, reach]
func _card_of(key: String) -> String: return key.split(":")[0]
func _reach_of(key: String) -> String: return key.split(":")[1]


func _card_cost(key: String) -> Dictionary:   # what researching this card consumes in total
	var cd: Dictionary = CARDS[_card_of(key)]
	var out := {}
	for r in (cd.cost as Dictionary).keys(): out[str(r)] = float(cd.cost[r])
	return out


func _card_time(key: String) -> float:
	return float(CARDS[_card_of(key)].time)


func _cost_text(key: String) -> String:
	var c := _card_cost(key)
	return "%d Cash · %d Credentials · %d Research" % [int(c.cash), int(c.creds), int(c.research)]


func _held(fac: int, key: String) -> int: return int((cards[fac] as Dictionary).get(key, 0))


func _hand(fac: int) -> Array:   # keys held, in catalogue order
	var out := []
	for c in CARD_ORDER:
		if _held(fac, _card_key(c, "linked")) > 0: out.append(_card_key(c, "linked"))
	return out


func _hand_size(fac: int) -> int:
	var n := 0
	for k in (cards[fac] as Dictionary).keys(): n += int(cards[fac][k])
	return n


func _linked(fac: int, t: int) -> bool:   # a connection of this faction runs into t (dormant or live)
	for i in hosts.size():
		if int(hosts[i].owner) == fac and int(hosts[i].assign) == t: return true
	return false


func _xmult(v: float) -> String: return "×%s" % str(snapped(v, 0.01))   # ×1.5, ×1.25, ×0.5


func _card_scale(fam: String, i: int) -> float:   # 1 = full effect · 0 = immune · 1.5 = weak
	var rs: Dictionary = RESIST[str(hosts[i].get("type", "pc"))]
	return clampf(1.0 - float(rs.get(fam, 0.0)), 0.0, 1.5)


func _resist_line(i: int) -> String:   # "weak to phishing ×1.5 · resists credential attacks 25 %"
	var rs: Dictionary = RESIST[str(hosts[i].get("type", "pc"))]
	var weak := []; var strong := []
	for fam in FAMILY_NAME.keys():
		var v := float(rs.get(fam, 0.0))
		if v < 0.0: weak.append("%s %s" % [FAMILY_NAME[fam], _xmult(1.0 - v)])
		elif v > 0.0: strong.append("%s %d %%" % [FAMILY_NAME[fam], int(round(v * 100.0))])
	var parts := []
	if not weak.is_empty(): parts.append("weak to " + ", ".join(weak))
	if not strong.is_empty(): parts.append("resists " + ", ".join(strong))
	return " · ".join(parts) if not parts.is_empty() else "no particular weakness"


func _can_play(fac: int, key: String, t: int) -> String:   # "" if playable, else why not
	if won or lost: return "match finished"
	if not rig.has(fac) or _eliminated.has(fac) or int(hosts[int(rig[fac])].owner) != fac: return "your rig is not under your control"
	if _routing_down(int(rig[fac])): return "your rig's routing is cut"
	if t < 0 or t >= hosts.size() or int(hosts[t].owner) == fac: return "not a foreign building"
	if _held(fac, key) <= 0: return "none held"
	if _route(int(rig[fac]), t).is_empty(): return "no route from your rig — capture a path toward it first"   # no wire needed, just reach
	return ""


func _effect_text(cd: Dictionary, i: int, s: float) -> String:
	var mult := "" if absf(s - 1.0) < 0.01 else " (%s %s)" % [str(NODE_TYPES[str(hosts[i].get("type", "pc"))].name), _xmult(s)]
	match str(cd.effect):
		"defenders": return "defenders −%d %%%s" % [int(round(clampf(float(cd.power) * s, 0.0, 1.0) * 100.0)), mult]
		"deny": return "production off + routing cut %.0f s%s" % [float(cd.dur) * s, mult]
		"steal": return "production stolen %.0f s%s" % [float(cd.dur) * s, mult]
		_: return "defenders −%d %% + routing cut %.0f s%s" % [int(round(clampf(float(cd.power) * s, 0.0, 1.0) * 100.0)), float(cd.dur) * s, mult]


# ---- research: a queue per botnet; the head item consumes its cost spread over its time ----
func _queue_research(fac: int, key: String) -> void:
	if not CARD_ORDER.has(_card_of(key)) or _eliminated.has(fac): return
	if (lab[fac].queue as Array).size() >= RESEARCH_QUEUE_LIMIT:
		if fac == PLAYER: _flash("Research queue full · finish or cancel a card", 1)
		return
	_research_items(fac)
	(lab[fac].queue as Array).append(key)
	(lab[fac].items as Array).append({"progress": 0.0, "paused": false})
	if fac == PLAYER: _refresh_panel(); _refresh_hand()


func _research_items(fac: int) -> Array:
	var state: Dictionary = lab[fac]
	if not state.has("items"): state.items = []
	var items: Array = state.items
	while items.size() < (state.queue as Array).size(): items.append({"progress": float(state.progress) if items.is_empty() else 0.0, "paused": false})
	while items.size() > (state.queue as Array).size(): items.pop_back()
	return items


func _toggle_research_item(fac: int, index: int) -> void:
	var items := _research_items(fac)
	if index < 0 or index >= items.size(): return
	items[index].paused = not bool(items[index].paused)
	if fac == PLAYER: _refresh_panel(); _refresh_hand()


func _requeue_first(fac: int, index: int) -> void:
	var items := _research_items(fac)
	var queue: Array = lab[fac].queue
	if index < 0 or index >= queue.size(): return
	var key: String = queue[index]; var item: Dictionary = items[index]
	queue.remove_at(index); items.remove_at(index)
	queue.push_front(key); items.push_front(item)
	if fac == PLAYER: _refresh_panel(); _refresh_hand()


func _dequeue_research(fac: int, index: int) -> void:
	var items := _research_items(fac)
	if index < 0 or index >= items.size(): return
	(lab[fac].queue as Array).remove_at(index); items.remove_at(index)
	lab[fac].progress = 0.0; lab[fac].stall = ""
	if fac == PLAYER: _refresh_panel(); _refresh_hand()


func _toggle_research(fac: int) -> void:
	lab[fac].paused = not bool(lab[fac].paused)
	if fac == PLAYER:
		_flash("Research %s" % ("paused — nothing is consumed" if bool(lab[fac].paused) else "resumed"))
		_refresh_panel()


func _tick_research(dt: float) -> void:
	for fac in botnets:
		var state: Dictionary = lab[fac]
		var items := _research_items(fac)
		var queue: Array = state.queue
		state["active"] = -1
		if queue.is_empty() or bool(state.paused): state.stall = ""; continue
		var index := -1
		for k in items.size():
			if not bool(items[k].paused): index = k; break
		if index < 0: state.stall = ""; continue
		state.active = index
		var key := str(queue[index]); var duration := _card_time(key)
		var work := minf(dt, duration - float(items[index].progress))
		var cost := _card_cost(key); var fraction := work / duration
		state.stall = ""
		for resource in cost:
			if _pool(fac, resource) < float(cost[resource]) * fraction - 0.000001: state.stall = resource; break
		state.progress = float(items[index].progress)
		if str(state.stall) != "":
			items[index]["waiting_for"] = str(state.stall); items[index]["funded_time"] = 0.0
			continue
		items[index]["funded_time"] = float(items[index].get("funded_time", 0)) + dt
		if float(items[index].funded_time) >= 0.75: items[index]["waiting_for"] = ""
		for resource in cost: _pool_add(fac, resource, -float(cost[resource]) * fraction)
		items[index].progress = float(items[index].progress) + work
		state.progress = float(items[index].progress)
		if float(items[index].progress) >= duration - 0.00001:
			cards[fac][key] = _held(fac, key) + 1
			queue.remove_at(index); items.remove_at(index)
			state.progress = 0.0
			if fac == PLAYER:
				_flash("Ready: %s" % str(CARDS[_card_of(key)].name), 0)
				_refresh_panel(); _refresh_hand()


func _play_card(fac: int, key: String, t: int) -> bool:   # the card leaves your network as a packet and lands on arrival
	var why := _can_play(fac, key, t)
	if why != "":
		if fac == PLAYER: _flash("Cannot play: %s" % why)
		return false
	var src := int(rig[fac])   # a card ALWAYS flies from your rig (the main host), along its own network
	var rt := _route(src, t)
	if rt.is_empty():
		if fac == PLAYER: _flash("Cannot play: no route from your rig to %s" % str(hosts[t].name))
		return false
	var cd: Dictionary = CARDS[_card_of(key)]
	cards[fac][key] = _held(fac, key) - 1
	card_plays[fac] = int(card_plays.get(fac, 0)) + 1
	var f := _schedule(rt, _t, fac, "card")
	f.card = key
	flights.append(f)
	if fac == PLAYER: _flash("🃏 %s is on its way to %s from %s — lands in %d s" % [str(cd.name), str(hosts[t].name), str(hosts[src].name), int(ceil(float(f.arrive_t) - _t))])
	elif _mine(t): _flash("⚠ A card from %s is flying toward %s" % [fname(fac), str(hosts[t].name)])
	_refresh_panel(); queue_redraw()
	return true


func _land_card(fac: int, key: String, t: int) -> void:   # the packet arrived: the effect lands (× the type), a worm spreads
	if int(hosts[t].owner) == fac: return   # it became yours meanwhile: the card fizzles
	var cd: Dictionary = CARDS[_card_of(key)]
	var hit := [t]
	var s0 := _apply_effect(fac, cd, t)
	if bool(cd.chain) and s0 > 0.0: hit += _worm(fac, cd, t)
	for h in hit: _fx.append({"host": int(h), "until": _t + 3.0, "col": fcol(fac)})
	if fac == PLAYER:
		if s0 <= 0.0: _flash("%s on %s — immune: %s resists %s fully" % [str(cd.name), str(hosts[t].name), str(NODE_TYPES[str(hosts[t].type)].name), str(FAMILY_NAME[str(cd.fam)])])
		else: _flash("🃏 %s → %s: %s%s" % [str(cd.name), str(hosts[t].name), _effect_text(cd, t, s0), (" · spread to %d more: %s%s" % [hit.size() - 1, _names(hit.slice(1, 6)), "…" if hit.size() > 6 else ""]) if hit.size() > 1 else ""])
	else:
		var yours := []
		for h in hit:
			if _mine(int(h)): yours.append(int(h))
		if not yours.is_empty(): _flash("⚠ %s hit %s with %s — %s" % [fname(fac), _names(yours), str(cd.name), _effect_text(cd, int(yours[0]), _card_scale(str(cd.fam), int(yours[0])))])
	_refresh_panel(); queue_redraw()


func _apply_effect(fac: int, cd: Dictionary, i: int) -> float:   # returns the scale that landed (0 = immune)
	var s := _card_scale(str(cd.fam), i)
	if s <= 0.0: return 0.0
	var eff := str(cd.effect)
	if eff == "defenders" or eff == "breach":
		hosts[i].bots = maxf(0.0, float(hosts[i].bots) - float(hosts[i].bots) * minf(1.0, float(cd.power) * s))
	if eff == "deny": hosts[i].prod_off = maxf(float(hosts[i].prod_off), float(cd.dur) * s)
	if eff == "routing" or eff == "breach" or eff == "deny": hosts[i].route_off = maxf(float(hosts[i].route_off), float(cd.dur) * s)
	if eff == "steal":   # the target's production flows to the caster for a few seconds
		hosts[i].steal_until = maxf(float(hosts[i].steal_until), _t + float(cd.dur) * s); hosts[i].steal_by = fac
	hosts[i].hit_t = _t
	_mark_scanned(fac, i)   # the payload reports back: the building is revealed to its attacker
	return s


func _worm(fac: int, cd: Dictionary, start: int) -> Array:   # the buildings hit beyond `start`, in jump order
	var hit := []; var frontier := [start]; var seen := {start: true}; var jump := 1
	while not frontier.is_empty():
		var p := 1.0 - WORM_FALLOFF * float(jump - 1)   # jump 1: 100 % · 2: 75 % · 3: 50 % · 4: 25 % · 5: 0
		if p <= 0.0: break
		var nxt := []
		for h in frontier:
			for o in hosts[int(h)].links:
				if seen.has(int(o)) or int(hosts[int(o)].owner) == fac: continue   # never the caster's own
				if rng.randf() >= p: continue
				seen[int(o)] = true
				_worms.append({"a": int(h), "b": int(o), "until": _t + 4.0, "col": fcol(fac)})
				var s := _apply_effect(fac, cd, int(o))
				if s > 0.0: hit.append(int(o)); nxt.append(int(o))   # an immune building stops the chain there
		frontier = nxt; jump += 1
	return hit


# ============================================================ AI BOTNETS
# Every AI plays by the player's rules AND under the player's fog: inside this section a foreign building's
# bots, builds, job, rate, sec and the engine helpers over them (_regen, _drain, _built_kinds, _count,
# _scan_cost, _stage) may be read only for the AI's OWN buildings. Everything else goes through the two
# knowledge gates below — exactly what the player's badge and panel show: own = exact; scanned (record done,
# contents unchanged) = live; else "?" and a public estimate from the type, value and owner, or a memory of
# what was last seen (regrown since). An AI scouts (a quiet scan) before it strikes, keeps what it learned,
# re-scans only when the inside changed, and reads the rest from what is drawn: live attack flows (never a
# quiet scan), packets, cards in flight, the OFF/CUT frames, rival Cash in the HUD, captures it witnessed.
# Each think: remember → housekeeping → defence → build → research → cards → choke the leader → offence
# (scout-then-strike) → idle scouting → supply.
func _ai_tick(dt: float) -> void:
	if not ai_enabled: return
	for fac in ais:
		var st: Dictionary = _ai[fac]
		st.timer = float(st.timer) - dt
		if float(st.timer) > 0.0: continue
		st.timer = float(AI_PROFILE[fac].cadence) * ai_speed
		_ai_think(fac)


func _ai_mine(fac: int) -> Array:
	var out := []
	for e in hosts.size():
		if int(hosts[e].owner) == fac: out.append(e)
	return out


func _ai_frontier(e: int) -> bool:   # borders a building of another faction (incl. neutral)
	for p in hosts[e].links:
		if int(hosts[p].owner) != int(hosts[e].owner): return true
	return false


func _ai_borders_botnet(e: int) -> bool:   # borders another BOTNET (a live threat)
	for p in hosts[e].links:
		var o := int(hosts[p].owner)
		if o != NEUTRAL and o != int(hosts[e].owner): return true
	return false


func _ai_release(e: int) -> void:
	hosts[e].assign = -1; hosts[e].live = false; _next_depart.erase(e)


# ---- knowledge: what an AI may know about a building it does not own ----
func _ai_prior_bots(i: int) -> float:   # the public estimate: type, value, owner, the hub — never the real number
	if bool(hosts[i].hub): return 30.0                                 # the generator's rule, and the hub is named
	if int(hosts[i].owner) != NEUTRAL: return AI_PRIOR_BOTNET * NODE_CAP   # a garrisoned botnet building
	return clampf(2.0 + 5.0 * float(hosts[i].value) + 2.5 + float(NODE_TYPES[str(hosts[i].get("type", "pc"))].sec), 4.0, 28.0)


func _ai_record(fac: int, i: int) -> Dictionary:   # the AI's own scan record of i (may be stale), or {}
	return (scans[fac] as Dictionary).get(i, {})


func _ai_known_bots(fac: int, i: int) -> float:   # THE bots gate: live when own or scanned; else memory regrown; else the prior
	if int(hosts[i].owner) == fac or _scanned(fac, i): return float(hosts[i].bots)
	var rec := _ai_record(fac, i)
	if rec.has("bots"):
		var age := _t - float(rec.get("at", _t))
		return minf(float(rec.get("cap", NODE_CAP)), float(rec.bots) + PROD_RATE * _tmult(i, "bot") * age)
	return _ai_prior_bots(i)


func _ai_known_builds(fac: int, i: int) -> Array:   # THE builds gate: live when own or scanned; else the last-seen key; else the prior
	if int(hosts[i].owner) == fac or _scanned(fac, i): return _built_kinds(i)
	var rec := _ai_record(fac, i)
	if rec.has("key") and bool(rec.get("done", false)) and str(rec.key) != "":
		var out := []
		for k in str(rec.key).split(","):
			if str(k) != "": out.append(str(k))
		return out
	if bool(hosts[i].hub) or bool(hosts[i].rig): return ["bot", "bot"]   # the generator's and _claim's rule
	return ["bot"]


func _ai_known_regen(fac: int, i: int) -> float:   # bots/s it believes i regenerates (the OFF frame is public)
	if _prod_down(i): return 0.0
	var kinds := _ai_known_builds(fac, i)
	var fr := _ai_known_bots(fac, i) / NODE_CAP
	var stg := 0 if fr >= STAGE_FULL else (1 if fr >= STAGE_SHAKY else 2)
	var act := maxi(1, kinds.size() - stg)
	var n := 0
	for k in mini(act, kinds.size()):
		if str(kinds[k]) == "bot": n += 1
	return float(n) * PROD_RATE * _tmult(i, "bot")


func _ai_seen_drain(i: int) -> float:   # bots/s visibly leaving i: a drawn live flow (never a quiet scan), or its bot packets in flight
	var d := _bot_target(i)
	if d >= 0 and _next_depart.has(i) and _route(i, d).size() >= 2:   # mirrors the draw path: a live non-scan route is drawn solid
		if not (int(hosts[i].assign) >= 0 and str(hosts[i].get("mode", "attack")) == "scan"): return SEND_RATE
	for fl in flights:
		if str(fl.kind) == "bot" and int((fl.route as Array)[0]) == i and int(fl.owner) == int(hosts[i].owner): return SEND_RATE
	return 0.0


func _ai_fall_secs(fac: int, t: int, n: int) -> float:   # seconds n streams need to take t, from what the AI knows (INF: never)
	var net := float(n) * SEND_RATE * (ATTACK_POWER / DEFEND_POWER) - maxf(_ai_known_regen(fac, t) - _ai_seen_drain(t), 0.0)
	if net <= 0.1: return INF
	return _ai_known_bots(fac, t) / net


func _ai_others_on(fac: int, c: int) -> int:   # visible third-party pressure on c: live non-scan wires, bot packets in flight
	var n := 0
	var o := int(hosts[c].owner)
	for i in hosts.size():
		var oi := int(hosts[i].owner)
		if oi == fac or oi == o or oi == NEUTRAL: continue
		if bool(hosts[i].live) and int(hosts[i].assign) == c and str(hosts[i].get("mode", "attack")) != "scan": n += 1
	for f in botnets:
		if f != fac and f != o and _incoming(c, f) > 0.0: n += 1
	return n


func _ai_worm_value(fac: int, seed: int) -> float:   # expected reach of a credential worm from seed, by public types only
	var p := [1.0, 0.75, 0.5, 0.25]
	var seen := {seed: true}; var frontier := [seed]; var total := _card_scale("phish", seed)
	for depth in 4:
		var nxt := []
		for h in frontier:
			for o in hosts[int(h)].links:
				if seen.has(int(o)) or int(hosts[int(o)].owner) == fac: continue
				seen[int(o)] = true
				var sc := _card_scale("phish", int(o))
				total += float(p[depth]) * sc
				if sc > 0.0: nxt.append(int(o))
		frontier = nxt
	return total


func _ai_remember(fac: int) -> void:   # refresh the memory of every building it can see right now (the player's badge is live too)
	for i in hosts.size():
		if int(hosts[i].owner) == fac or not _scanned(fac, i): continue
		var rec := _ai_record(fac, i)
		rec.bots = float(hosts[i].bots); rec.cap = NODE_CAP if int(hosts[i].owner) != NEUTRAL else float(rec.get("cap", NODE_CAP)); rec.at = _t
		scans[fac][i] = rec


func _ai_leader(fac: int) -> int:   # the other botnet ahead in the public Cash race, or -1
	var best := -1
	for f in botnets:
		if f == fac or _faction_nodes(f) == 0: continue
		if best < 0 or _faction_nodes(f) > _faction_nodes(best): best = f
	return best


func _ai_think(fac: int) -> void:
	var st: Dictionary = _ai[fac]
	var mine := _ai_mine(fac)
	if mine.is_empty(): return
	var aggr := float(AI_PROFILE[fac].aggr)
	_ai_remember(fac)
	var threatened := false   # a building of ours under attack pulls attention off a build
	for t in mine:
		if _under_attack(t): threatened = true; break
	# ── 0. housekeeping: finished / unreachable wires, stalled attacks (patience on what it can SEE) ──
	var nr: Dictionary = st.get("noroute", {})
	for e in mine:
		var a := int(hosts[e].assign)
		if a < 0: nr.erase(e); continue
		if int(hosts[a].owner) == fac:
			if float(hosts[a].bots) >= NODE_CAP - 0.5 and not _under_attack(a) and not _ai_frontier(a): _ai_release(e)
		elif _route(e, a).is_empty():   # a cut route (a card, a lost relay) pauses the flow; give it patience, then let go
			if not nr.has(e): nr[e] = _t
			elif _t - float(nr[e]) > AI_PATIENCE: _ai_release(e); nr.erase(e)
		else: nr.erase(e)
	st.noroute = nr
	var avoid := -1   # a stalled target is shunned for a while, and only while it keeps its owner
	var av: Dictionary = st.get("avoid_rec", {})
	if not av.is_empty() and _t - float(av.at) <= 2.0 * AI_PATIENCE and int(hosts[int(av.t)].owner) == int(av.owner): avoid = int(av.t)
	var ops := {}   # attack / scan target -> [sources]
	for e in mine:
		var a := int(hosts[e].assign)
		if a >= 0 and bool(hosts[e].live) and int(hosts[a].owner) != fac:
			if not ops.has(a): ops[a] = []
			ops[a].append(e)
	var recs: Dictionary = st.ops
	for t in recs.keys():
		if not ops.has(t): recs.erase(t)
	for tk in ops.keys():
		var t := int(tk)
		var kb := _ai_known_bots(fac, t); var pr := _scan_progress(fac, t)
		if not recs.has(t): recs[t] = {"since": _t, "bots": kb, "prog": pr}
		elif kb < float(recs[t].bots) - 0.5 or pr > float(recs[t].get("prog", 0.0)) + 0.5: recs[t].bots = kb; recs[t].prog = pr; recs[t].since = _t
		elif _t - float(recs[t].since) > AI_PATIENCE:
			for e in ops[t]: _ai_release(e)
			st.avoid_rec = {"t": t, "owner": int(hosts[t].owner), "at": _t}; avoid = t; recs.erase(t); ops.erase(t)
	# ── 1. defence: guard a threatened building, remember the edge, counter a visible attacker it can take ──
	var seen: Dictionary = st.get("threat_seen", {})
	for sk in seen.keys():
		if not _under_attack(int(sk)): seen.erase(sk)
	for t in mine:
		if not _under_attack(t): continue
		st.edges[t] = _t
		if not seen.has(t): seen[t] = _t                 # first noticed now
		var reacted: bool = _t - float(seen[t]) >= AI_REACT   # a human takes a moment to pull reserves
		var threat := _threat_rate(t)
		var regen := _regen(t) - _drain(t)
		var help := 0.0
		for e in mine:
			if int(hosts[e].assign) == t and bool(hosts[e].live): help += SEND_RATE * float(hosts[e].rate)
		var deficit := threat - regen - help + 0.3
		if deficit > 0.0 and reacted:
			var needed := mini(3, int(ceil(deficit / SEND_RATE)))
			var helpers := []
			for e in mine:
				if e == t or _under_attack(e) or float(hosts[e].bots) < AI_RESERVE + 4.0: continue
				var ea := int(hosts[e].assign)
				if ea >= 0 and (bool(hosts[e].live) or (int(hosts[ea].owner) == fac and _under_attack(ea))): continue   # busy, or guarding a building that burns too
				var rt := _route(e, t)
				if not rt.is_empty(): helpers.append([rt.size(), e])
			helpers.sort_custom(func(a, b): return a[0] < b[0])
			for h in helpers.slice(0, mini(needed, helpers.size())):
				hosts[int(h[1])].assign = t; hosts[int(h[1])].live = true; hosts[int(h[1])].mode = "attack"; _next_depart[int(h[1])] = _t
		# counter-attack: a VISIBLE attacker (a drawn live flow, never a quiet scan) streaming out is net-zero at home — two streams take it
		for i in hosts.size():
			if int(hosts[i].owner) == fac or int(hosts[i].owner) == NEUTRAL or not bool(hosts[i].live) or int(hosts[i].assign) != t: continue
			if str(hosts[i].get("mode", "attack")) == "scan": continue
			var cs := _ai_fall_secs(fac, i, 2)
			if ops.has(i) or float(intel[fac]) < 20.0 or cs > AI_PATIENCE or 2.0 * SEND_RATE * cs > float(intel[fac]) + _intel_rate(fac) * cs: continue
			var free := []
			for e in mine:
				if int(hosts[e].assign) >= 0 or _under_attack(e) or float(hosts[e].bots) < AI_RESERVE + 4.0: continue
				var rt := _route(e, i)
				if not rt.is_empty(): free.append([rt.size(), e])
			if free.size() < 2: continue
			free.sort_custom(func(a, b): return a[0] < b[0])
			for h in free.slice(0, 2):
				hosts[int(h[1])].assign = i; hosts[int(h[1])].live = true; hosts[int(h[1])].mode = "attack"; _next_depart[int(h[1])] = _t
			ops[i] = [int(free[0][1]), int(free[1][1])]
			recs[i] = {"since": _t, "bots": _ai_known_bots(fac, i), "prog": _scan_progress(fac, i)}
			if _mine(i): _flash("⚔ %s counter-attacks %s" % [fname(fac), str(hosts[i].name)])
	st.threat_seen = seen
	# ── 2. build: one new job per think, chosen by need; jobs run on their own and several may overlap ──
	if float(intel[fac]) >= BUILD_COST_INTEL:
		var free_slot := []
		for e in mine:
			if _free_slot(e) >= 0: free_slot.append(e)
		if not free_slot.is_empty():
			var site := -1; var kind := ""
			var want_intel: bool = _intel_rate(fac) < 1.0 + float(ops.size()) or float(intel[fac]) < 15.0
			if want_intel:   # harvester in the safest building (rear first, then fewest hostile neighbours)
				kind = "intel"; var best := INF
				for e in free_slot:
					var sc := (0.0 if not _ai_frontier(e) else 5.0) + (5.0 if _ai_borders_botnet(e) else 0.0) - 4.0 * (_tmult(e, "intel") - 1.0)
					if sc < best: best = sc; site = e
			if site < 0:   # a frontier building facing a botnet with a single farm gets a second
				for e in free_slot:
					if _ai_borders_botnet(e) and _count_all(e, "bot") < 2: site = e; kind = "bot"; break
			if site < 0 and mine.size() >= 3 and _kind_total(fac, "cash") > 0:   # the card economy: one harvester, then one lab, in the rear
				for kind2 in ["cred", "lab"]:
					if site >= 0 or _kind_total(fac, str(kind2)) > 0: continue
					var best2 := -INF
					for e in free_slot:
						var sc2 := _tmult(e, "cred" if str(kind2) == "cred" else "research") * 2.0 - (3.0 if _ai_borders_botnet(e) else 0.0) - (1.0 if _ai_frontier(e) else 0.0)
						if sc2 > best2: best2 = sc2; site = e; kind = str(kind2)
			if site < 0:   # otherwise the richest building gets a market
				var bestv := -1.0
				for e in free_slot:
					var v := float(hosts[e].value) * 2.0 * _tmult(e, "cash") + float(int(hosts[e].slots) - _built_kinds(e).size()) * 0.3 - (1.0 if _ai_borders_botnet(e) else 0.0)
					if v > bestv: bestv = v; site = e; kind = "cash"
			if site >= 0: _start_job(site, kind)
	# ── 2b. research: a cheap card of each useful kind; phishing first when a rival leads the Cash race ──
	var L: Dictionary = lab[fac]
	var leader := _ai_leader(fac)
	var chased: bool = leader >= 0 and _faction_nodes(leader) >= _faction_nodes(fac) + int(AI_CHOKE_LEAD)
	if (L.queue as Array).is_empty() and _kind_total(fac, "lab") > 0 and _kind_total(fac, "cred") > 0:
		var want := ""
		if chased and _held(fac, "dos:linked") < 1: want = "dos:linked"            # deny the control leader
		elif _held(fac, "oneday:linked") < 1: want = "oneday:linked"               # a cheap defender-dropper
		elif _held(fac, "stuff:linked") < 1: want = "stuff:linked"                 # the full wipe
		elif aggr > 0.6 and _held(fac, "phishworm:linked") < 1: want = "phishworm:linked"
		elif _held(fac, "oneday:linked") < 2: want = "oneday:linked"
		if want != "": _queue_research(fac, want)
	# ── 2c. cards on a target it is streaming at (scanned, so the numbers are real): phish its regeneration off, then wipe it ──
	var worm_seed := -1; var worm_best := 0.0
	for tk in ops.keys():
		var t2 := int(tk)
		if not _scanned(fac, t2) or _ai_known_bots(fac, t2) < 4.0: continue       # about to fall anyway
		if _held(fac, "phishworm:linked") > 0 and int(hosts[t2].owner) != NEUTRAL and _card_scale("phish", t2) > 0.0:
			var wv := _ai_worm_value(fac, t2)
			if wv > worm_best: worm_best = wv; worm_seed = t2
			continue
		if _held(fac, "stuff:linked") > 0 and _card_scale("cred", t2) >= 0.5: _play_card(fac, "stuff:linked", t2); break
		if _held(fac, "phish:linked") > 0 and _card_scale("phish", t2) >= 0.5: _play_card(fac, "phish:linked", t2); break
		if _held(fac, "oneday:linked") > 0 and _card_scale("oneday", t2) >= 0.5: _play_card(fac, "oneday:linked", t2); break
	if worm_seed >= 0: _play_card(fac, "phishworm:linked", worm_seed)   # the seed whose public types promise the longest chain
	# ── 2d. choke the control leader: DoS one of its production buildings (markets, harvesters, labs) ──
	if chased and _held(fac, "dos:linked") > 0:
		for tk in (scans[fac] as Dictionary).keys():
			var t3 := int(tk)
			if int(hosts[t3].owner) != leader or not _scanned(fac, t3) or _prod_down(t3) or _card_scale("dos", t3) < 0.5: continue
			var kinds3 := _ai_known_builds(fac, t3)
			if not (kinds3.has("cash") or kinds3.has("intel") or kinds3.has("cred") or kinds3.has("lab")): continue
			var laid := -1
			if not _linked(fac, t3):   # a dormant wire is free and silent: the LINKED delivery route
				var bsrc := -1; var bl := 999
				for e in mine:
					if int(hosts[e].assign) >= 0: continue
					var rt := _route(e, t3)
					if not rt.is_empty() and rt.size() < bl: bl = rt.size(); bsrc = e
				if bsrc < 0: continue
				hosts[bsrc].assign = t3; hosts[bsrc].live = false; _next_depart.erase(bsrc); laid = bsrc
			var played := _play_card(fac, "dos:linked", t3)
			if laid >= 0: _ai_release(laid)   # the card is in the air; the source is free again
			if played: break
	# ── 3. offence: scout what it does not know, strike what it knows it can take ──
	var max_ops := 1 + (1 if aggr > 0.6 and mine.size() >= 5 else 0)
	var cands := []
	for e in mine:
		for p in hosts[e].links:
			if int(hosts[p].owner) != fac and not cands.has(p) and not ops.has(p): cands.append(p)
	if cands.size() > 1 and avoid >= 0 and cands.has(avoid): cands.erase(avoid)
	var free := []
	for e in mine:
		if int(hosts[e].assign) >= 0 and bool(hosts[e].live): continue
		if _under_attack(e) or float(hosts[e].bots) < AI_RESERVE + 4.0: continue
		free.append(e)
	var pick := -1; var pick_srcs := []; var best := 0.0; var pick_known := false
	if ops.size() < max_ops and float(intel[fac]) >= 12.0:
		for c in cands:
			var srcs := []
			for e in free:
				var rt := _route(e, c)
				if not rt.is_empty(): srcs.append([rt.size(), e])
			if srcs.size() < 2: continue
			srcs.sort_custom(func(a, b): return a[0] < b[0])
			var known: bool = _scanned(fac, c)
			var kinds := _ai_known_builds(fac, c)
			var pressure := _ai_others_on(fac, c)
			var regen_net := _ai_known_regen(fac, c) - _ai_seen_drain(c)
			var need := clampi(int(ceil((maxf(regen_net, 0.0) + 0.5) / (SEND_RATE * ATTACK_POWER / DEFEND_POWER))), 2, AI_MAX_STREAMS)
			if known and _ai_known_bots(fac, c) <= 6.0 and pressure > 0: need = 2   # steal the kill: it is nearly down already
			var n := mini(need, srcs.size())
			var travel := float(int(srcs[0][0]) - 1) * (LINK_TIME + NODE_ROUTE_DELAY)
			var secs := _ai_fall_secs(fac, c, n) + travel
			if secs > AI_SIEGE_MAX: continue                       # know your limits: a siege it cannot finish in its budget is not started
			var quiet_c: bool = not known and pressure == 0
			var cost := secs * float(n) * SEND_RATE if not quiet_c else SCAN_BASE + SCAN_PER_BUILD * float(kinds.size()) + 0.5 * secs * float(n) * SEND_RATE
			if cost > float(intel[fac]) + _intel_rate(fac) * secs: continue
			var o := int(hosts[c].owner)
			var benefit := float(hosts[c].value) * 3.0 + float(hosts[c].slots) + float(kinds.size()) + 2.0 * (_tmult(c, "intel") + _tmult(c, "cash") + _tmult(c, "bot") - 3.0)
			if o != NEUTRAL: benefit += 4.0 + 6.0 * aggr          # taking a rival's building also hurts its income
			if o == PLAYER: benefit += 2.0 * aggr
			if known: benefit += 2.0                              # trust what it learned
			if known and _ai_known_bots(fac, c) <= 6.0 and pressure > 0: benefit += 8.0
			elif pressure > 0: benefit += 3.0                     # someone else is visibly softening it — pile on
			if _ai_seen_drain(c) > 0.0: benefit += 1.5            # it is bleeding bots out: softer than it looks
			if (st.lost as Dictionary).has(c): benefit += 4.0 + 2.0 * aggr   # it was ours
			if bool(hosts[c].get("junction", false)): benefit += 3.0         # a junction is a second front
			for p in hosts[c].links:
				if int(hosts[p].owner) == fac and bool(hosts[p].rig): benefit += 3.0   # it sits on our doorstep
			var score := benefit / (secs + 8.0)
			if score > best: best = score; pick = c; pick_srcs = srcs.slice(0, n); pick_known = known
	if pick >= 0:
		var quiet: bool = not pick_known and _ai_others_on(fac, pick) == 0   # an alarmed target has nothing left to keep quiet for
		var launch: Array = pick_srcs.slice(0, 2) if quiet else pick_srcs
		for s in launch:
			hosts[int(s[1])].assign = pick; hosts[int(s[1])].live = true; hosts[int(s[1])].mode = "scan" if quiet else "attack"; _next_depart[int(s[1])] = _t
		if pick_known and _ai_known_bots(fac, pick) >= 4.0 and _linked(fac, pick):   # prepare the ground: soften it as the streams arrive
			for ck in [["stuff", "cred"], ["phish", "phish"], ["oneday", "oneday"]]:
				if _held(fac, str(ck[0]) + ":linked") > 0 and _card_scale(str(ck[1]), pick) >= 0.5:
					_play_card(fac, str(ck[0]) + ":linked", pick); break
		recs[pick] = {"since": _t, "bots": _ai_known_bots(fac, pick), "prog": _scan_progress(fac, pick)}
		if _mine(pick) and not quiet: _flash("⚔ %s is attacking %s with %d source(s) — defend it!" % [fname(fac), str(hosts[pick].name), launch.size()])
	elif ops.is_empty() and float(intel[fac]) >= AI_SCOUT_INTEL:   # ── 3b. idle scouting: learn the richest unknown neighbour ──
		var sc_pick := -1; var sc_v := -1.0; var sc_src := -1
		for c in cands:
			if _scanned(fac, c): continue
			var v := float(hosts[c].value) + (1.0 if bool(hosts[c].hub) else 0.0)
			if v <= sc_v: continue
			for e in free:
				if not _route(e, c).is_empty(): sc_pick = c; sc_v = v; sc_src = e; break
		if sc_pick >= 0:
			hosts[sc_src].assign = sc_pick; hosts[sc_src].live = true; hosts[sc_src].mode = "scan"; _next_depart[sc_src] = _t
			recs[sc_pick] = {"since": _t, "bots": _ai_known_bots(fac, sc_pick), "prog": _scan_progress(fac, sc_pick)}
	# ── 4. supply: full rear buildings pre-wire dormant guards where the last blow landed, else to the weakest front ──
	for e in mine:
		if (int(hosts[e].assign) >= 0 and bool(hosts[e].live)) or _ai_frontier(e) or float(hosts[e].bots) < NODE_CAP - 2.0: continue
		var worst := -1; var wb := INF; var hot := -1; var ht := -INF
		for f in mine:
			if f == e or not _ai_frontier(f) or _route(e, f).is_empty(): continue
			var last := float((st.edges as Dictionary).get(f, -INF))
			if _t - last <= AI_EDGE_MEMORY and last > ht: ht = last; hot = f
			if float(hosts[f].bots) < wb: worst = f; wb = float(hosts[f].bots)
		var dest := hot if hot >= 0 else worst
		if dest >= 0 and dest != int(hosts[e].assign): hosts[e].assign = dest; hosts[e].live = false; hosts[e].mode = "attack"; _next_depart.erase(e)


# ============================================================ INPUT
var _research_dismiss_click := false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _research_dismiss_click and not event.pressed:
			_research_dismiss_click = false
			get_viewport().set_input_as_handled(); return
		if event.pressed and _tab == "research" and not menu_open and not get_viewport().gui_is_dragging():
			var point: Vector2 = event.position
			var over_control := point.y < 60 or panel.get_global_rect().has_point(point)
			for card in hand_bar.get_children() + pending_research.get_children():
				if (card is CardTile or card is ResearchTile) and card.get_global_rect().has_point(point): over_control = true
			if not over_control:
				_research_dismiss_click = true
				_clear_all(); _refresh_panel(); queue_redraw()
				get_viewport().set_input_as_handled(); return
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.keycode == KEY_ESCAPE:
		if menu_open: _open_menu(false)
		elif _panel_shown(): _clear_all(); _refresh_panel(); queue_redraw()
		else: _open_menu(true)
		get_viewport().set_input_as_handled(); return
	if menu_open or won or lost: return
	if event.keycode == KEY_SPACE:
		paused = not paused; _refresh_panel(); queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R: _set_tab("research")
	elif event.keycode == KEY_L: _set_tab("board")
	elif event.keycode == KEY_0: _reset_view()


func _can_drop_data(pos: Vector2, data: Variant) -> bool:   # a hand card held over the map
	if not (data is Dictionary) or not (data as Dictionary).has("card"): return false
	var t := _host_at(pos)
	return t >= 0 and _can_play(PLAYER, str(data.card), t) == "" and _card_scale(str(CARDS[_card_of(str(data.card))].fam), t) > 0.0


func _drop_data(pos: Vector2, data: Variant) -> void:
	var t := _host_at(pos)
	if t >= 0: _play_card(PLAYER, str(data.card), t)


func _dragged_card() -> String:   # the hand card being dragged right now, or ""
	if not is_inside_tree() or get_viewport() == null or not get_viewport().gui_is_dragging(): return ""
	var d: Variant = get_viewport().gui_get_drag_data()
	if d is Dictionary and (d as Dictionary).has("card"): return str(d.card)
	return ""


func _pointer_over_panel() -> bool:
	return panel != null and panel.visible and panel.get_global_rect().has_point(get_viewport().get_mouse_position())


# the hand along the bottom: draggable cards. Drag one onto a reachable enemy building (highlighted) to play it.
func _refresh_hand() -> void:
	if hand_bar == null: return
	# Preserve pending buttons through refreshes, including mouse press/release.
	var signature := _hand_signature()
	if hand_bar.get_meta("signature", "") == signature: return
	hand_bar.set_meta("signature", signature)
	for c in hand_bar.get_children(): hand_bar.remove_child(c); c.queue_free()
	for c in pending_research.get_children(): pending_research.remove_child(c); c.queue_free()
	if won or lost: return
	var held := _hand(PLAYER)
	var pending: Array = lab[PLAYER].queue
	var gallery := _tab == "research"
	var available := get_viewport_rect().size.x - PANEL_W - 72
	var width := floorf((available - 18) / 4)
	var ready_width := floorf((get_viewport_rect().size.x - 112) / 8) if gallery else width - 6
	for key in held:
		var c := CardTile.new(); c.game = self; c.key = str(key)
		c.custom_minimum_size = Vector2(ready_width, 104); hand_bar.add_child(c)
	for index in pending.size():
		var c := ResearchTile.new(); c.game = self; c.key = str(pending[index])
		c.catalogue = false; c.queue_index = index
		c.custom_minimum_size = Vector2(width, 104); pending_research.add_child(c)
	hand_bar.reset_size()



func _hand_signature() -> String:
	if won or lost: return "END"
	var parts := [str(get_viewport_rect().size.x), str(_tab == "research"), str(lab[PLAYER].queue)]
	for key in _hand(PLAYER): parts.append("%s:%d" % [str(key), _held(PLAYER, str(key))])
	return ",".join(parts)


func _clear_all() -> void:   # clears SELECTION + sidebar back to the bare map — never touches wired connections
	sel = {}; _inspect = -1; _drag_from = -1; _dragging = false; _boxing = false; _tab = ""


func _gui_input(event: InputEvent) -> void:
	if won or lost or menu_open: return    # no map commands after a terminal result or while the menu is up
	if event is InputEventMouseMotion:
		if _panning: _pan += event.position - _pan_last; _pan_last = event.position; queue_redraw(); return
		if _drag_from >= 0 and event.position.distance_to(_press_pos) > 8.0: _dragging = true
		if _boxing or _dragging or not sel.is_empty(): queue_redraw()
		return
	if not (event is InputEventMouseButton): return
	if _pointer_over_panel(): return   # the sidebar eats wheel/clicks — never zoom or command through it
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: _zoom_at(event.position, 1.15); return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: _zoom_at(event.position, 1.0 / 1.15); return
	if event.button_index == MOUSE_BUTTON_MIDDLE:   # middle-drag pans the map
		_panning = event.pressed; _pan_last = event.position; return
	var hit := _host_at(event.position)
	var shift: bool = event.shift_pressed
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			_box_start = event.position
			if hit < 0:
				if shift: _boxing = true                              # Shift+drag on empty = box-select
				else: _panning = true; _pan_last = event.position     # plain drag on empty = PAN the map
			else: _boxing = false
			_drag_from = hit if _mine(hit) else -1   # drag a line only FROM your building
			_dragging = false
			return
		var moved: bool = event.position.distance_to(_press_pos) > 8.0
		if _panning:
			_panning = false
			if not moved: _left_click(-1, shift)                      # a tap on empty = clear selection
			_refresh_panel(); queue_redraw(); return
		if _boxing and moved:
			var ws := _s2w(_box_start)
			_marquee(Rect2(ws, _s2w(event.position) - ws).abs(), shift)   # world-space marquee (zoom-aware)
		elif _drag_from >= 0 and moved and hit >= 0 and hit != _drag_from:
			_drag_wire(_drag_from, hit)    # dragged a line onto a building → WIRE a dormant connection
		elif not moved:
			_left_click(hit, shift)
		_boxing = false; _drag_from = -1; _dragging = false
		_refresh_panel(); queue_redraw()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var src := _connection_at(_s2w(event.position))   # right-click ON a connection removes it
		if src >= 0:
			sel = {src: true}; _inspect = -1; _tab = ""
			_flash("Route: %s → %s. Use Disconnect in its panel to remove it." % [str(hosts[src].name), str(hosts[int(hosts[src].assign)].name)])
		else:
			_clear_all()                   # right-click empty = clear selection / panel
		_refresh_panel(); queue_redraw()


# CLICK never wires — links are made ONLY by drag-and-drop (the user was explicit about this).
# Click = look at / select: your building → select it + its panel; any other → just open its panel.
# Shift-click builds a group; drag from any group member then wires the whole group.
func _left_click(hit: int, shift: bool) -> void:
	_tab = ""                                 # any building click returns the sidebar to building context
	if hit < 0:
		_clear_all()
		return
	if shift and _mine(hit):
		if sel.has(hit): sel.erase(hit)
		else: sel[hit] = true
		_inspect = -1
		return
	if _mine(hit):
		sel = {hit: true}; _inspect = hit    # your building: select it (ready to drag) + show its panel
	else:
		sel = {}; _inspect = hit             # other building: open its panel (the launch pad)


# dragging a line from your building onto another WIRES it (dormant connection) — it never fires.
# Dragging from a building already in the selection wires the whole group; from an unselected one, just it.
func _drag_wire(src: int, dest: int) -> void:
	if not sel.has(src): sel = {src: true}
	_wire(dest)


func _marquee(r: Rect2, shift: bool) -> void:
	if not shift: sel = {}
	for i in hosts.size():
		if _mine(i) and r.has_point(hosts[i].pos): sel[i] = true
	_inspect = -1


# screen ⇄ world (map zoom/pan). Node positions are WORLD; mouse events are SCREEN.
func _s2w(s: Vector2) -> Vector2: return (s - _pan) / _zoom
func _w2s(w: Vector2) -> Vector2: return w * _zoom + _pan
func _mouse_world() -> Vector2: return _s2w(get_local_mouse_position())


func _zoom_at(screen_pos: Vector2, factor: float) -> void:   # zoom toward the cursor, keeping that point fixed
	var w := _s2w(screen_pos)
	_zoom = clampf(_zoom * factor, 0.08, 3.0)
	_pan = screen_pos - w * _zoom
	queue_redraw()


func _reset_view() -> void: _fit_view()   # "recenter" = fit the whole map in view


func _fit_view() -> void:
	if hosts.is_empty(): return
	var mn: Vector2 = hosts[0].pos; var mx: Vector2 = hosts[0].pos
	for h in hosts: mn = mn.min(h.pos); mx = mx.max(h.pos)
	var view := _map_rect().grow(-42)
	var world := (mx - mn).max(Vector2.ONE)
	_zoom = minf(view.size.x / world.x, view.size.y / world.y)
	_pan = view.get_center() - (mn + mx) * 0.5 * _zoom
	queue_redraw()


func _host_at(p: Vector2) -> int:
	if not _map_rect().has_point(p): return -1
	var hit := -1; var nearest := INF
	for i in hosts.size():
		var distance := p.distance_to(_w2s(hosts[i].pos))
		if distance <= maxf(22, _r(i) * _zoom + 5) and distance < nearest:
			hit = i; nearest = distance
	return hit


func _connection_at(w: Vector2) -> int:
	var best := -1; var bestd := 9.0 / maxf(_zoom, 0.1)
	for i in hosts.size():
		if not _mine(i) or int(hosts[i].assign) < 0: continue
		var rt := _route(i, int(hosts[i].assign))
		for k in range(rt.size() - 1):
			var a: Vector2 = hosts[int(rt[k])].pos
			var b: Vector2 = hosts[int(rt[k + 1])].pos
			var d := w.distance_to(Geometry2D.get_closest_point_to_segment(w, a, b))
			if d < bestd: bestd = d; best = i
	return best


# CONNECT (drag-and-drop only): wire every selected building of yours to `dest` — dashed and DORMANT,
# nothing fires, no Intel spent. A link can only be made where a PATH exists through your own buildings.
# One connection per building: wiring replaces the old one (a rewired one is dormant again); wiring a
# building's current target changes nothing (it never interrupts a live flow).
func _wire(dest: int) -> void:
	if dest < 0 or sel.is_empty(): return
	var join_attack := false
	for source in _owned_feeders(dest):
		if bool(hosts[source].live) and str(hosts[source].mode) == "attack": join_attack = true
	var done := 0; var nopath := 0
	for s in sel.keys():
		var i := int(s)
		if not _mine(i) or i == dest: continue
		if _route(i, dest).is_empty(): nopath += 1; continue
		if int(hosts[i].assign) != dest:
			hosts[i].assign = dest; hosts[i].live = join_attack; hosts[i].mode = "attack"; _next_depart.erase(i)
		done += 1
	if done > 0:
		var extra := ("  ·  %d had no path" % nopath) if nopath > 0 else ""
		if _mine(dest):
			_flash("Connected %d guard(s) → %s%s  (auto-defend when it's attacked or damaged)" % [done, str(hosts[dest].name), extra])
		elif join_attack:
			_flash("%d building(s) joined the attack on %s" % [done, str(hosts[dest].name)])
		else:
			_flash("Connected %d building(s) → %s%s  (dormant — press SCAN or ATTACK on its panel)" % [done, str(hosts[dest].name), extra])
		sel = {}; _inspect = dest            # wired: move to the target's panel
	elif nopath > 0:
		_flash("✖ No path to %s — links can only run through your own buildings" % str(hosts[dest].name))
	_refresh_panel(); queue_redraw()


# LAUNCH: the button on the TARGET's panel — turns every dormant connection into `t` live, together.
# Added contributors join an existing attack; new inactive targets need explicit launch.
func _launch(t: int, mode := "attack") -> void:   # "scan" = quiet reveal; "attack" = alarms, wounds, reveals as it lands
	if mode == "scan" and _scanned(PLAYER, t):
		_flash("Already scanned. Choose Attack to send combat bots."); return
	var started := 0; var unrouted := 0
	for i in hosts.size():
		if not _mine(i) or int(hosts[i].assign) != t or bool(hosts[i].live): continue
		if _route(i, t).is_empty(): unrouted += 1; continue
		hosts[i].live = true; hosts[i].mode = mode; _next_depart[i] = _t; started += 1
	var verb := "🔍 Scanning quietly" if mode == "scan" else ("⚔ Attacking blind (alarm raised)" if not _scanned(PLAYER, t) else "⚔ Attacking")
	if started > 0: _flash("%s %s — %d flow(s) launched%s" % [verb, str(hosts[t].name), started, ("  ·  %d held (no route)" % unrouted) if unrouted > 0 else ""])
	elif unrouted > 0: _flash("Cannot launch on %s — no routes (capture a bordering building first)" % str(hosts[t].name))
	else: _flash("Nothing to launch — no dormant connections into %s" % str(hosts[t].name))
	_refresh_panel(); queue_redraw()


# STOP: pause every live attack flow into `t` — the wires stay, ready to launch again
func _halt(t: int) -> void:
	var n := 0
	for i in hosts.size():
		if _mine(i) and int(hosts[i].assign) == t and bool(hosts[i].live):
			hosts[i].live = false; _next_depart.erase(i); n += 1
	if n > 0: _flash("Stopped %d flow(s) into %s (connections kept)" % [n, str(hosts[t].name)])
	else: _flash("No live flows into %s" % str(hosts[t].name))
	_refresh_panel(); queue_redraw()


# DISCONNECT the selected buildings entirely (wire removed; travelling bots still finish)
func _disconnect_selected() -> void:
	var n := 0
	for s in sel.keys():
		if _mine(int(s)) and int(hosts[int(s)].assign) >= 0:
			hosts[int(s)].assign = -1; hosts[int(s)].live = false; _next_depart.erase(int(s)); n += 1
	if n > 0: _flash("Disconnected %d building(s)" % n)
	else: _flash("Nothing to disconnect")
	_refresh_panel()


func _adjust_rate(d: float) -> void:   # the output-limit dial, 25% steps, for every selected source
	var last := 1.0
	for s in sel.keys():
		if _mine(int(s)):
			hosts[int(s)].rate = clampf(float(hosts[int(s)].rate) + d, 0.25, 1.0)
			last = float(hosts[int(s)].rate)
	_flash("Send rate: %d%% of %.0f bot/s" % [int(round(last * 100.0)), SEND_RATE])
	_refresh_panel(); queue_redraw()





func _select_contributors(feeders: Array) -> void:
	sel = {}
	for i in feeders: sel[int(i)] = true
	_inspect = -1; _refresh_panel(); queue_redraw()


func _owned_feeders(node: int) -> Array:   # your buildings wired into `node`
	var out := []
	for i in hosts.size():
		if _mine(i) and int(hosts[i].assign) == node: out.append(i)
	return out


# A CONNECTION persists until you disconnect it (stopping a flow with _halt keeps the wire). Player
# commands only ever touch your own buildings — other botnets' wires and flows are never affected.
func _cancel_to(dest: int) -> void:
	var n := 0
	for i in _owned_feeders(dest):
		hosts[int(i)].assign = -1; hosts[int(i)].live = false; _next_depart.erase(int(i)); n += 1
	if n > 0: _flash("Disconnected %d building(s) from %s" % [n, str(hosts[dest].name)])
	else: _flash("Nothing of yours is connected to %s" % str(hosts[dest].name))
	_refresh_panel(); queue_redraw()


func _apply_options() -> void:   # turn the menu choices into the live grid + faction set + seed
	_cols = _opt_size.x; _rows = _opt_size.y
	var pool := [RIVAL, RIVAL2, RIVAL3]
	ais = []
	for k in clampi(_opt_enemies, 1, 3): ais.append(pool[k])
	botnets = [PLAYER] + ais
	town_seed = _opt_seed   # 0 = random


func _reset() -> void:   # a NEW town every restart, with the current options
	won = false; lost = false; _end_shown = false; _end_cause = ""; paused = false; _t = 0.0
	_emit_cursor = 0; _panel_t = 0.0
	_departures.clear(); _resource_samples.clear(); _defender_samples.clear(); _eliminated.clear()
	_panel_context = ""; _msg_t = 0.0; _msg_priority = 0
	_tab = ""; _hold = {}
	_tut = false; _ai_paused = false
	if tut_panel != null: tut_panel.visible = false
	_apply_options()
	_clear_all()
	_gen(); _fit_view(); _refresh_panel(); _refresh_hand(); _refresh_top_tabs()


func _build_names(builds: Array) -> String:
	var out := []
	for b in builds:
		if str(b) != "": out.append(BUILD_KINDS[str(b)].name if BUILD_KINDS.has(str(b)) else str(b))
	return ", ".join(out) if not out.is_empty() else "none"


func _flash(m: String, priority := 2) -> void:
	if _msg_t > 0.0 and priority < _msg_priority: return
	_msg = m; _msg_t = 5.0; _msg_priority = priority


func _plabel(txt: String, sz := 14, col := C_TEXT) -> void:
	_lbl(panel_box, txt, sz, col, PANEL_W - 64.0)


func _lbl(parent: Control, txt: String, sz: int, col: Color, minw: float) -> Label:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", maxi(14, sz)); l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(minw, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func _card_grid(keys: Array, big: bool, counts: bool, enabled_fn: Callable, note_fn: Callable, click_fn: Callable, draggable := false) -> void:   # a grid of card faces
	var grid := GridContainer.new(); grid.columns = 2 if big else 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	for key in keys:
		var c := CardFace.new(); c.game = self; c.card = _card_of(str(key)); c.reach = _reach_of(str(key))
		c.custom_minimum_size = Vector2(190, 262) if big else Vector2(124, 174)
		if counts: c.count = _held(PLAYER, str(key))
		c.enabled = bool(enabled_fn.call(str(key))) if enabled_fn.is_valid() else true
		c.note = str(note_fn.call(str(key))) if note_fn.is_valid() else ""
		if click_fn.is_valid(): c.on_click = click_fn.bind(str(key))
		c.draggable = draggable
		grid.add_child(c)
	panel_box.add_child(grid)


func _btn(txt: String, cb: Callable, enabled := true, parent: Control = null, tip := "", height := 32.0) -> void:
	var b := Button.new(); b.text = txt; b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 16)
	b.disabled = not enabled; b.custom_minimum_size = Vector2(0, height)
	b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb); (parent if parent != null else panel_box).add_child(b)


func _action_button(action: String, callback: Callable, parent: Control = null, enabled := true) -> void:
	var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else panel_box).add_child(column)
	var button := Button.new(); button.name = action
	button.text = {"Attack": "⚔", "Scan": "⌕", "Disconnect": "⛓ ×", "Stop": "■"}[action]
	button.custom_minimum_size = Vector2(96, 44)
	button.disabled = not enabled
	button.add_theme_font_size_override("font_size", 20)
	button.clip_text = true
	button.add_theme_color_override("font_color", C_BAD if action in ["Disconnect", "Stop"] else (C_WARN if action == "Attack" else C_GOOD))
	if action in ["Disconnect", "Stop"]:
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.08, 0.1) if state == "normal" else Color(0.45, 0.1, 0.13)
			style.border_color = C_BAD; style.set_border_width_all(1); style.set_corner_radius_all(4)
			button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback); column.add_child(button)
	_lbl(column, action, 12, C_TEXT, 0).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _btn_row(items: Array) -> void:   # [[text, callable, enabled, tooltip], ...] side by side
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		var b := Button.new(); b.text = str(it[0]); b.focus_mode = Control.FOCUS_ALL
		b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.disabled = not bool(it[2]) if it.size() > 2 else false
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(0, 36); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[1]); row.add_child(b)
	panel_box.add_child(row)


func _gap(h: float) -> void:
	var c := Control.new(); c.custom_minimum_size = Vector2(0, h); panel_box.add_child(c)


func _flat(txt: String, cb: Callable) -> void:   # a quiet text button for things that are never the action
	var b := Button.new(); b.text = txt; b.flat = true; b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 24); b.add_theme_font_size_override("font_size", 12)
	b.modulate = Color(1, 1, 1, 0.65)
	b.pressed.connect(cb); panel_box.add_child(b)


func _kicker(txt: String) -> void:   # a small uppercase line above a heading
	_plabel(txt.to_upper(), 11, C_DIM)


func _names(arr: Array) -> String:
	var out := []
	for i in arr: out.append(str(hosts[int(i)].name))
	return ", ".join(out)


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


func _esc_btn() -> void: _clear_all(); _refresh_panel(); queue_redraw()


func _open_menu(open: bool) -> void:   # the menu pauses the game while it's up
	menu_open = open
	if menu_panel != null: menu_panel.visible = open
	if hud != null: hud.visible = not open                 # only the menu + its drifting backdrop while it's up
	if hand_panel != null: hand_panel.visible = not open
	if top_tabs != null: top_tabs.visible = not open
	if open and panel != null: panel.visible = false
	if tut_panel != null: tut_panel.visible = _tut and not open   # the tutorial prompt hides under the menu
	if open: _menu_view = "main"; _refresh_menu()
	_refresh_panel(); queue_redraw()


func _menu_label(t: String) -> void:
	var l := Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", 13); l.add_theme_color_override("font_color", C_DIM)
	menu_box.add_child(l)


func _menu_title(t: String) -> void:
	var l := Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", 26); l.add_theme_color_override("font_color", C_TEXT)
	menu_box.add_child(l)


func _mbtn(txt: String, cb: Callable) -> void:   # a full-width menu button
	var b := Button.new(); b.text = txt; b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, 42)
	b.pressed.connect(cb); menu_box.add_child(b)


func _menu_gap(h: float) -> void:
	var c := Control.new(); c.custom_minimum_size = Vector2(0, h); menu_box.add_child(c)


func _size_menu(w: float, h: float) -> void:   # fit the panel to the view so no view has dead space
	if menu_panel == null: return
	menu_panel.size = Vector2(w, h)
	menu_panel.position = ((get_viewport_rect().size - menu_panel.size) * 0.5).floor()
	if menu_sc != null: menu_sc.size = menu_panel.size - Vector2(48.0, 44.0)
	if menu_box != null: menu_box.custom_minimum_size.x = w - 60.0


func _refresh_menu() -> void:
	if menu_box == null: return
	if is_instance_valid(fb_details): _fb_draft.details = fb_details.text
	if is_instance_valid(fb_version): _fb_draft.version = fb_version.text
	if is_instance_valid(fb_name): _fb_draft.name = fb_name.text
	fb_details = null; fb_version = null; fb_name = null
	for c in menu_box.get_children(): c.queue_free()
	if is_instance_valid(menu_seed_edit): _seed_draft = menu_seed_edit.text
	menu_seed_edit = null
	menu_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if _menu_view == "feedback" else ScrollContainer.SCROLL_MODE_AUTO
	match _menu_view:
		"help": _size_menu(680.0, 640.0); _menu_help()
		"newgame": _size_menu(MENU_W, 452.0); _menu_newgame()
		"feedback": _size_menu(480.0, 590.0); _menu_feedback()
		_:
			var nb := 6 if (_t >= 0.01 and not won and not lost) else 5
			_size_menu(MENU_W, 96.0 + float(nb) * 52.0); _menu_main()


func _menu_main() -> void:
	_menu_title("BOTNET")
	_menu_gap(6)
	if _t >= 0.01 and not won and not lost: _mbtn("▶ Resume", func(): _open_menu(false))
	_mbtn("🎮 New game", func(): _menu_view = "newgame"; _refresh_menu())
	_mbtn("🎓 Tutorial", func(): _start_tutorial())
	_mbtn("❔ Help", func(): _help_page = 0; _menu_view = "help"; _refresh_menu())
	_mbtn("📝 Feedback", func(): _fb_status = ""; _menu_view = "feedback"; _refresh_menu())
	_mbtn("✖ Exit", func(): get_tree().quit())


func _menu_newgame() -> void:
	_menu_title("New game")
	_menu_label("Map size  ·  %d × %d cells" % [_opt_size.x, _opt_size.y])
	var names := ["Small", "Medium", "Big"]
	var srow := HBoxContainer.new(); srow.add_theme_constant_override("separation", 6)
	for i in 3:
		var b := Button.new(); b.text = names[i]; b.custom_minimum_size = Vector2(0, 36); b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.focus_mode = Control.FOCUS_ALL
		if _opt_size == SIZE_PRESETS[i]: b.add_theme_color_override("font_color", C_GOOD)
		b.pressed.connect(func(idx = i): _opt_size = SIZE_PRESETS[idx]; _refresh_menu())
		srow.add_child(b)
	menu_box.add_child(srow)
	_menu_label("Enemies")
	var erow := HBoxContainer.new(); erow.add_theme_constant_override("separation", 6)
	for n in [1, 2, 3]:
		var b := Button.new(); b.text = str(n); b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.focus_mode = Control.FOCUS_ALL
		if _opt_enemies == n: b.add_theme_color_override("font_color", C_GOOD)
		b.pressed.connect(func(k = n): _opt_enemies = k; _refresh_menu())
		erow.add_child(b)
	menu_box.add_child(erow)
	_menu_label("Seed (blank = random)")
	menu_seed_edit = LineEdit.new(); menu_seed_edit.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, 34)
	menu_seed_edit.placeholder_text = "random"
	menu_seed_edit.text = _seed_draft
	menu_box.add_child(menu_seed_edit)
	_menu_gap(4)
	_mbtn("▶ Start", _start_new_game)
	_mbtn("← Back", func(): _menu_view = "main"; _refresh_menu())


func _help_head(t: String) -> void:
	var l := Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", 16); l.add_theme_color_override("font_color", C_WARN)
	menu_box.add_child(l)


func _help_text(t: String, col := C_DIM) -> void:
	var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, 0)
	l.add_theme_font_size_override("font_size", 13); l.add_theme_color_override("font_color", col)
	menu_box.add_child(l)


func _help_row(kind: String, card: String, title: String, desc: String) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := HelpGlyph.new(); g.game = self; g.custom_minimum_size = Vector2(88, 88)
	if card != "": g.card = card; g.col = FAMILY_COL[str(CARDS[card].fam)]
	elif kind != "": g.kind = kind; g.col = BUILD_KINDS[kind].col
	row.add_child(g)
	var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vb.add_theme_constant_override("separation", 3)
	var tl := Label.new(); tl.text = title; tl.add_theme_font_size_override("font_size", 15); tl.add_theme_color_override("font_color", C_TEXT); vb.add_child(tl)
	var dl := Label.new(); dl.text = desc; dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x - 110.0, 0)
	dl.add_theme_font_size_override("font_size", 12); dl.add_theme_color_override("font_color", C_DIM); vb.add_child(dl)
	row.add_child(vb)
	menu_box.add_child(row)


const HELP_PAGES := ["goal", "network", "build", "resources", "cards", "controls"]

func _menu_help() -> void:   # big paginated help with Prev / Next
	_help_page = clampi(_help_page, 0, HELP_PAGES.size() - 1)
	_menu_title("Help  ·  %d / %d" % [_help_page + 1, HELP_PAGES.size()])
	_menu_gap(2)
	match HELP_PAGES[_help_page]:
		"goal":
			_help_head("Goal")
			_help_text("Hold MORE THAN HALF the buildings continuously for 45 seconds, or eliminate every rival by capturing their rigs. Lose your rig and you lose. No match timer.", C_TEXT)
			_help_head("The buildings")
			_help_text("Every building has a TYPE (PC, Server, Web, Database, IoT, ERP) that sets how many build slots it has and which production it's best at. A building's BOTS are both its health and its soldiers. Grey buildings are neutral city hosts; coloured ones belong to a botnet.")
			_help_text("Your RIG is your home base — if you lose it, you lose. Capture the central HUB and the big ERP cores for the most slots.")
		"network":
			_help_head("Grow your network")
			_help_text("DRAG a line from a building you own onto a target to CONNECT it (a dashed wire — nothing fires yet). Its panel opens automatically: choose Scan quietly or Attack: your bots stream over and grind its defenders to zero to capture it.", C_TEXT)
			_help_text("Drag another source into a running attack to join it immediately. Stop keeps links; Disconnect removes them. Packets already travelling still arrive. A line into one of YOUR OWN buildings is a GUARD — it reinforces that building automatically whenever it comes under attack, then stands down.")
			_help_text("Bots travel along the streets; far targets take longer and you can lose a building before help arrives.")
		"build":
			_help_head("Build inside the slots")
			_help_text("Click a building you own, then drop a build card on an empty slot. Each build consumes 10 Intel over 10 seconds of funded work. Attack packets take priority; remaining Intel is shared across jobs. Limited funding slows progress proportionally.", C_TEXT)
			_help_row("bot", "", "Bot farm", "+1 bot/s regeneration, and each farm RAISES this building's cap by 30 (two farms → 60, three → 90). Stack them to make a fortress.")
			_help_row("intel", "", "Intel harvester", "+1 Intel/s and +50 Intel cap.")
			_help_row("cash", "", "Darknet market", "A Cash packet every few seconds, flowing home to your rig.")
			_help_row("cred", "", "Credential harvester", "+Credentials/s (× the building type).")
			_help_row("lab", "", "Research lab", "+Research/s (× the building type).")
		"resources":
			_help_head("The four resources")
			_help_row("intel", "", "Intel", "Your attack fuel: every attack bot you launch costs 1 Intel. Out of Intel → your attacks pause. Build Intel harvesters to keep pushing.")
			_help_row("cash", "", "Cash", "Earned by Darknet markets (packets flow home to your rig). Cash is the first of the three card-research inputs.")
			_help_row("cred", "", "Credentials", "Harvested by Credential harvesters. The second research input.")
			_help_row("lab", "", "Research", "Produced by Research labs. The third research input. Cash + Credentials + Research together pay for cards over time.")
			_help_text("The resource rates measure actual reserve changes over the last four seconds, including spending and caps. They are not promised production rates.")
		"cards":
			_help_head("Ultimate weapons — cards")
			_help_text("Open the RESEARCH tab (top-right), queue a card, and it's paid for from Cash, Credentials and Research over time. Then drag the finished card from your hand onto any reachable enemy — it flies from your rig and lands a big hit. Worm cards spread along the streets. Each family hits some building types harder than others.", C_TEXT)
			_help_row("", "stuff", "Credential attacks", "Remove up to all defenders; the building type can resist it. Bots must arrive to capture.")
			_help_row("", "phish", "Phishing", "Cheap — removes half the defenders.")
			_help_row("", "zeroday", "0-day exploits", "Breach: defenders down and routing cut.")
			_help_row("", "supply", "Supply-chain", "Steal a building's production for a while.")
			_help_row("", "dos", "Denial of service", "Switch a building off: no production, no routing.")
		"controls":
			_help_head("Controls")
			_help_text("• DRAG from your building onto a target = connect a wire.\n• CLICK a building = open its panel (attack / defend / build).\n• DRAG empty map = pan · mouse WHEEL = zoom · 0 = recenter.\n• RESEARCH / BOARD buttons = top-right.\n• Drag a card from your hand onto a lit-up enemy to play it.\n• SPACE pauses · ESC opens this menu.", C_TEXT)
	_menu_gap(8)
	var nav := HBoxContainer.new(); nav.add_theme_constant_override("separation", 8)
	var prev := Button.new(); prev.text = "← Prev"; prev.custom_minimum_size = Vector2(0, 40); prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev.disabled = _help_page == 0; prev.pressed.connect(func(): _help_page -= 1; _refresh_menu())
	nav.add_child(prev)
	var nxt := Button.new(); nxt.text = "Next →"; nxt.custom_minimum_size = Vector2(0, 40); nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt.disabled = _help_page >= HELP_PAGES.size() - 1; nxt.pressed.connect(func(): _help_page += 1; _refresh_menu())
	nav.add_child(nxt)
	menu_box.add_child(nav)
	_mbtn("← Back to menu", func(): _menu_view = "main"; _refresh_menu())


func _menu_feedback() -> void:
	_menu_title("Feedback")
	if _fb_status != "":
		_help_text(_fb_status, C_GOOD)
		_mbtn("← Back to menu", func(): _menu_view = "main"; _refresh_menu())
		return
	var rr := HBoxContainer.new(); rr.add_theme_constant_override("separation", 6)
	for n in [1, 2, 3, 4, 5]:
		var b := Button.new(); b.text = "★ %d" % n; b.custom_minimum_size = Vector2(0, 36); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.focus_mode = Control.FOCUS_ALL
		if _fb_rating == n: b.add_theme_color_override("font_color", C_GOOD)
		b.pressed.connect(func(k = n): _fb_rating = k; _refresh_menu())
		rr.add_child(b)
	menu_box.add_child(rr)
	var tr := HBoxContainer.new(); tr.add_theme_constant_override("separation", 6)
	for t in ["bug", "suggestion", "general"]:
		var b := Button.new(); b.text = str(t).capitalize(); b.custom_minimum_size = Vector2(0, 36); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.focus_mode = Control.FOCUS_ALL
		if _fb_type == t: b.add_theme_color_override("font_color", C_GOOD)
		b.pressed.connect(func(k = t): _fb_type = k; _refresh_menu())
		tr.add_child(b)
	menu_box.add_child(tr)
	_menu_label("Details")
	fb_details = TextEdit.new(); fb_details.placeholder_text = "What happened, or your idea…"
	fb_details.text = str(_fb_draft.details)
	fb_details.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, 100)
	menu_box.add_child(fb_details)
	_menu_label("Name (optional)")
	fb_name = LineEdit.new(); fb_name.placeholder_text = "anonymous"; fb_name.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, 32)
	fb_name.text = str(_fb_draft.name)
	menu_box.add_child(fb_name)
	_menu_gap(4)
	_mbtn("✓ Submit", _submit_feedback)
	_mbtn("← Back", func(): _menu_view = "main"; _refresh_menu())


func _submit_feedback() -> void:
	var data := {
		"rating": _fb_rating, "type": _fb_type,
		"details": (fb_details.text if fb_details != null else ""),
		"version": GAME_VERSION,
		"name": (fb_name.text if fb_name != null else ""),
		"when": Time.get_datetime_string_from_system(),
		"town": town_seed, "outcome": ("win" if won else ("loss" if lost else "in-progress")),
	}
	var exists := FileAccess.file_exists("user://feedback.jsonl")
	var f := FileAccess.open("user://feedback.jsonl", FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f != null:
		f.seek_end(); f.store_line(JSON.stringify(data)); f.close()
	if FEEDBACK_ENDPOINT != "" and fb_http != null:
		fb_http.request(FEEDBACK_ENDPOINT, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(data))
	_fb_status = "Thanks! Saved" + (" and sent." if FEEDBACK_ENDPOINT != "" else " to user://feedback.jsonl.")
	_fb_rating = 0; _fb_type = "general"
	_fb_draft = {"details": "", "version": GAME_VERSION, "name": ""}
	fb_details = null; fb_version = null; fb_name = null
	_refresh_menu()


# ---------------------------------------------------------------- TUTORIAL
func _tut_stages() -> Array:
	var target := str(hosts[_tut_target].name) if _tut_target >= 0 else "Training target"
	return [
		{"title": "Connect", "text": "Drag from YOUR RIG to TARGET. A dashed connection is a plan; it spends nothing."},
		{"title": "Scan, then attack", "text": "Press Scan on %s's panel. When it finishes, the same button becomes Attack. Press it to capture." % target},
		{"title": "Combine", "text": "Drag SUPPORT to the same target. It immediately joins the running attack."},
		{"title": "Capture", "text": "Watch the target's defenders fall. Your connected sources become automatic guards when it turns green."},
		{"title": "Build", "text": "Select your captured building. Click Intel harvester below its slots. Wait for construction to finish."},
		{"title": "Research", "text": "Open Research and click Phishing. Training support supplies all three inputs; wait for the card in your tray."},
		{"title": "Play a card", "text": "Drag the Phishing card from the bottom tray onto a highlighted enemy. Cards weaken; bots capture."},
		{"title": "Ready", "text": "Hold the building count shown above for 45 seconds, or capture the rival rig. Losing your rig ends the match."},
	]


func _start_tutorial() -> void:
	_opt_size = SIZE_PRESETS[0]; _opt_enemies = 1; _opt_seed = 7
	_reset()
	_tut = true; _tut_stage = 0; _ai_paused = true
	_tut_connected = false; _tut_attacked = false; _tut_combined = false; _tut_captured = false
	var source := int(rig[PLAYER])
	_tut_second = -1; _tut_target = -1
	for i in hosts.size():
		if _mine(i) and i != source: _tut_second = i; break
	for i in hosts[source].links:
		if int(hosts[i].owner) == NEUTRAL: _tut_target = i; break
	if _tut_target < 0:
		for i in hosts.size():
			if int(hosts[i].owner) == NEUTRAL: _tut_target = i; break
	# This is a repeatable teaching fixture, not the random competitive setup.
	hosts[_tut_target].name = "TRAINING TARGET"
	hosts[_tut_target].sec = 40.0; hosts[_tut_target].bots = 40.0
	_set_builds(_tut_target, [])
	hosts[_tut_second].name = "TRAINING SUPPORT"
	hosts[_tut_second].slots = 4
	_set_builds(_tut_second, ["bot", "cash", "cred", "lab"])
	hosts[_tut_second].bots = 30.0
	_link(source, _tut_target); _link(_tut_second, _tut_target)
	cash[PLAYER] = 50.0; creds[PLAYER] = 50.0; research[PLAYER] = 50.0
	_catalogue_card = "phish:linked"
	_open_menu(false); _show_tut(); _fit_view()


func _tick_tutorial() -> void:
	if not _tut or _tut_target < 0: return
	var contributors := _owned_feeders(_tut_target)
	if not contributors.is_empty(): _tut_connected = true
	var attacks := 0
	for source in contributors:
		if bool(hosts[source].live) and str(hosts[source].mode) == "attack": attacks += 1
	if attacks > 0 and not _mine(_tut_target): _tut_attacked = true
	if attacks >= 2 and not _mine(_tut_target): _tut_combined = true
	var done := false
	match _tut_stage:
		0: done = _tut_connected
		1: done = _tut_attacked
		2: done = _tut_combined or (_tut_captured and contributors.size() >= 2)
		3: done = _tut_captured
		4: done = _mine(_tut_target) and _count_all(_tut_target, "intel") > 0
		5: done = _held(PLAYER, "phish:linked") > 0 or int(card_plays.get(PLAYER, 0)) > 0
		6: done = int(card_plays.get(PLAYER, 0)) > 0
	if done: _tut_next()


func _show_tut() -> void:
	if tut_box == null: return
	for c in tut_box.get_children(): tut_box.remove_child(c); c.queue_free()
	var stages := _tut_stages()
	var step: Dictionary = stages[_tut_stage]
	var row := HBoxContainer.new(); tut_box.add_child(row)
	_lbl(row, "%d/%d · %s" % [_tut_stage + 1, stages.size(), step.title], 16, C_WARN, 0)
	var button := Button.new(); button.custom_minimum_size = Vector2(126, 32); button.add_theme_font_size_override("font_size", 14)
	button.text = "Start match" if _tut_stage == stages.size() - 1 else "Skip tutorial"
	button.pressed.connect(_tut_finish); row.add_child(button)
	var body := _lbl(tut_box, str(step.text), 14, C_TEXT, 0)
	body.custom_minimum_size.x = maxf(200, get_viewport_rect().size.x - PANEL_W - 104)
	tut_panel.visible = _tut and not menu_open
	_layout_ui()


func _tutorial_target() -> int:
	if not _tut: return -1
	if _tut_stage == 0: return int(rig[PLAYER])
	if _tut_stage == 2: return _tut_second
	if _tut_stage in [1, 3, 4]: return _tut_target
	return -1


func _tut_next() -> void:
	_tut_stage = mini(_tut_stage + 1, _tut_stages().size() - 1)
	if _tut_stage == 4:
		sel = {_tut_target: true}; _inspect = -1; _tab = ""; _refresh_panel()
	_show_tut()


func _tut_finish() -> void:
	_tut = false; _ai_paused = false
	if tut_panel != null: tut_panel.visible = false
	_flash("Rival active. Capture territory and protect your rig.")
	_layout_ui(); _fit_view()


func _start_new_game() -> void:
	if menu_seed_edit != null:
		var s := menu_seed_edit.text.strip_edges()
		if s != "" and (not s.is_valid_int() or int(s) <= 0):
			menu_seed_edit.placeholder_text = "Use a positive whole number"
			menu_seed_edit.add_theme_color_override("font_color", C_BAD)
			return
		_opt_seed = int(s) if s != "" else 0
	_reset()
	_open_menu(false)


# Panel is organised around the two verbs: CONNECT (selection panel) and LAUNCH (a building's own panel
# carries its ⚔ ATTACK button). States: RESULT · INSIDE (micro) · SELECTING · NODE (launch pad) · IDLE.
func _panel_shown() -> bool:   # the sidebar is HIDDEN by default — only a building or a top tab opens it
	return won or lost or _tab == "research" or _tab == "board" or _tab == "card" or not sel.is_empty() or _inspect >= 0


func _refresh_panel() -> void:
	if panel_box == null: return
	if is_inside_tree() and get_viewport().gui_is_dragging(): return
	_refresh_top_tabs()
	var shown := _panel_shown()
	panel.visible = shown and not menu_open
	var context := "%s|%s|%d|%s|%s|%s" % [_tab, str(sel.keys()), _inspect, str(won), str(lost), _selected_card]
	var changed := context != _panel_context
	var keep := 0 if changed else _scroll_pos()
	var previous := panel_box
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 4)
	panel_box.custom_minimum_size = Vector2(_panel_width() - 28.0, 0)
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if shown:
		if won or lost: _panel_result()
		elif _tab == "research": _panel_research()
		elif _tab == "board": _panel_board()
		elif _tab == "card": _panel_card()
		elif not sel.is_empty(): _panel_selecting()
		elif _inspect >= 0: _panel_inspect()

	# Reconcile text and state into existing controls. Pointer hover never
	# freezes values, and heartbeat refreshes never destroy a pressed button.
	if not changed and _same_ui_shape(previous, panel_box):
		_sync_ui(previous, panel_box)
		panel_box.free(); panel_box = previous
	else:
		panel_scroll.remove_child(previous); previous.queue_free()
		panel_scroll.add_child(panel_box)
	_panel_context = context
	_restore_scroll(keep)
	_layout_ui()
	if changed: _keep_target_visible()


func _same_ui_shape(a: Node, b: Node) -> bool:
	if a is SlotBox and b is SlotBox: return a.host == b.host and a.slot == b.slot
	if a is ResearchTile and b is ResearchTile: return a.key == b.key and a.queue_index == b.queue_index and a.catalogue == b.catalogue
	if a.get_class() != b.get_class() or a.get_script() != b.get_script() or a.get_child_count() != b.get_child_count(): return false
	if a is OptionButton and a.selected != b.selected: return false
	if a is ResearchTile and (a.key != b.key or a.queue_index != b.queue_index): return false
	if a is Button:
		var ac := a.get_signal_connection_list("pressed")
		var bc := b.get_signal_connection_list("pressed")
		if ac.size() != bc.size(): return false
		for i in ac.size():
			if ac[i].callable != bc[i].callable: return false
	for i in a.get_child_count():
		if not _same_ui_shape(a.get_child(i), b.get_child(i)): return false
	return true


func _sync_ui(a: Node, b: Node) -> void:
	if a is SlotBox or a is ResearchTile: a.queue_redraw(); return
	if a is Label or a is Button: a.text = b.text
	if a is Button: a.disabled = b.disabled
	if a is Control:
		for key in ["font_color", "font_disabled_color"]:
			if b.has_theme_color_override(key): a.add_theme_color_override(key, b.get_theme_color(key))
		a.queue_redraw()
	for i in a.get_child_count(): _sync_ui(a.get_child(i), b.get_child(i))


func _panel_width() -> float:
	if _tab == "research": return get_viewport_rect().size.x - 48
	return PANEL_W


func _layout_ui() -> void:
	if hud == null or feedback_label == null: return
	var sz := get_viewport_rect().size
	hud.position = Vector2(24, 8); hud.size = Vector2(sz.x - 440, 46)
	top_tabs.position = Vector2(sz.x - 396, 14)
	objective_label.position = Vector2(24, 62); objective_label.size = Vector2(sz.x - 48, 24)
	var gallery := _tab == "research"
	panel.position = Vector2(24 if gallery else sz.x - _panel_width() - 24, 100 if gallery else 64)
	panel.size = Vector2(_panel_width(), sz.y - 356 if gallery else maxf(180, sz.y - 88))
	panel_scroll.size = panel.size - Vector2(28, 24)
	panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_scroll.scroll_vertical = 0
	var rows := 1 if gallery else maxi(1, ceili(float(_hand(PLAYER).size()) / 4))
	var tray_height := rows * 104 + (rows - 1) * 6 + 8
	hand_bar.columns = 8 if gallery else 4
	hand_panel.position = Vector2(24, sz.y - tray_height - 12)
	hand_panel.size = Vector2(sz.x - 48 if gallery else sz.x - PANEL_W - 72, tray_height)
	hand_panel.visible = not menu_open
	pending_research.position = Vector2(24, hand_panel.position.y - 116)
	pending_research.size = Vector2(sz.x - PANEL_W - 72, 104)
	pending_research.visible = not menu_open and not won and not lost
	_refresh_hand()
	feedback_label.position = Vector2(24, pending_research.position.y - 46 if not lab[PLAYER].queue.is_empty() else hand_panel.position.y - 46)
	feedback_label.size = Vector2(sz.x - PANEL_W - 72, 42)
	if gallery: feedback_label.visible = false
	tut_panel.position = Vector2(24, 98); tut_panel.size = Vector2(sz.x - PANEL_W - 72, 120)
	tut_box.position = Vector2(16, 10); tut_box.custom_minimum_size = Vector2(tut_panel.size.x - 32, 0)
	tut_box.size.x = tut_panel.size.x - 32
	tut_panel.visible = _tut and not menu_open and not gallery
	for c in tut_box.get_children():
		if c is Label: c.custom_minimum_size.x = tut_panel.size.x - 32
	queue_redraw()


func _map_rect() -> Rect2:
	var sz := get_viewport_rect().size
	var right := sz.x - _panel_width() - 48 if _panel_shown() else sz.x - 24
	var top := 234.0 if _tut else 100.0
	return Rect2(24, top, maxf(200, right - 24), maxf(100, sz.y - 24 - top))


func _keep_target_visible() -> void:
	var target := _inspect
	if target < 0 and sel.size() == 1: target = int(sel.keys()[0])
	if target < 0: return
	var point := _w2s(hosts[target].pos)
	var safe := _map_rect().grow(-42)
	_pan += Vector2(clampf(point.x, safe.position.x, safe.end.x), clampf(point.y, safe.position.y, safe.end.y)) - point


func _update_chrome() -> void:
	if objective_label == null: return
	objective_label.visible = false
	feedback_label.visible = not menu_open and _tab != "research" and _msg_t > 0
	feedback_label.text = _msg
	if _dragging and _drag_from >= 0:
		feedback_label.visible = true
		var old := int(hosts[_drag_from].assign)
		feedback_label.text = "Connect %s · release over a target" % str(hosts[_drag_from].name)
		if old >= 0: feedback_label.text += " · replaces route to %s; travelling packets still arrive" % str(hosts[old].name)
	var dragged := _dragged_card()
	if dragged != "":
		feedback_label.visible = true
		var target := _host_at(get_local_mouse_position())
		feedback_label.text = "Release over a highlighted enemy to play this card."
		if target >= 0:
			var reason := _can_play(PLAYER, dragged, target)
			var cd: Dictionary = CARDS[_card_of(dragged)]
			var scale := _card_scale(str(cd.fam), target)
			if reason == "" and scale <= 0: reason = "immune to this card family"
			feedback_label.text = "%s · %s" % [str(hosts[target].name), reason if reason != "" else _effect_text(cd, target, scale)]
	var need := _control_need() + 1
	var warning := ""
	for fac in ais:
		if float(_hold.get(fac, 0.0)) > 0: warning = "  ·  %s wins in %.0fs" % [fname(fac), maxf(0, HOLD_SECS - float(_hold[fac]))]
	if _under_attack(int(rig[PLAYER])): warning = "  ·  YOUR RIG IS UNDER ATTACK"
	objective_label.text = "%sHold %d buildings for %ds  ·  Yours %d/%d  ·  Hold %.0f/%ds  ·  Protect your rig%s" % ["PAUSED  ·  " if paused else "", need, int(HOLD_SECS), _player_nodes(), need, float(_hold.get(PLAYER, 0.0)), int(HOLD_SECS), warning]
	objective_label.add_theme_color_override("font_color", C_WARN if warning != "" or paused else C_TEXT)


func _refresh_top_tabs() -> void:
	if top_tabs == null: return
	var n := _hand_size(PLAYER)
	var sig := _tab
	if sig == _toptab_sig: return   # only rebuild when it actually changes — a periodic rebuild would eat clicks
	_toptab_sig = sig
	for c in top_tabs.get_children(): c.queue_free()
	_mk_top_tab("🧪 RESEARCH", "research", 160.0)
	_mk_top_tab("🏆 BOARD", "board", 120.0)
	var menu_button := Button.new(); menu_button.text = "Menu"
	menu_button.custom_minimum_size = Vector2(88, 36)
	menu_button.pressed.connect(_open_menu.bind(true)); top_tabs.add_child(menu_button)


func _mk_top_tab(txt: String, tab: String, w: float) -> void:
	var b := Button.new(); b.text = txt; b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(w, 30); b.clip_text = true
	if _tab == tab: b.add_theme_color_override("font_color", C_GOOD)   # the open tab is highlighted
	b.pressed.connect(_set_tab.bind(tab)); top_tabs.add_child(b)


func _scroll_pos() -> int:
	return panel_scroll.scroll_vertical if panel_scroll != null else 0


func _restore_scroll(v: int) -> void:
	if panel_scroll != null: panel_scroll.set_deferred("scroll_vertical", v)


func _set_tab(t: String) -> void:   # a top button TOGGLES its sidebar; opening one drops any building context
	if _tab == t:
		_tab = ""
	else:
		_tab = t; sel = {}; _inspect = -1
	_refresh_panel(); queue_redraw()
	if panel_scroll != null: panel_scroll.set_deferred("scroll_vertical", 0)


func _panel_text() -> String:   # probes: every label and button of the panel, in order
	_refresh_panel()
	var out := []
	var stack: Array = panel_box.get_children()
	while not stack.is_empty():
		var c: Node = stack.pop_front()
		if c is Label: out.append(str((c as Label).text))
		elif c is Button: out.append("[%s]" % str((c as Button).text))
		for ch in c.get_children(): stack.append(ch)
	return "\n".join(out)


func _panel_tabs() -> void:   # MAP (context) · RESEARCH (cards); the active tab is the disabled button
	var n := _hand_size(PLAYER)
	var q: Array = lab[PLAYER].queue
	var rl := "🧪 RESEARCH"
	if n > 0: rl += " ·%d" % n
	_btn_row([["🗺 MAP", _set_tab.bind("map"), _tab != "map", "The map: connect, scan, attack, build"], [rl, _set_tab.bind("research"), _tab != "research", "Cards weaken a building; your bots take it. Researched from Cash, Credentials and Research."], ["🏆 BOARD", _set_tab.bind("board"), _tab != "board", "The leaderboard: who holds what (L)"]])


func _panel_research() -> void:
	_plabel("Research · %d/4 queued" % (lab[PLAYER].queue as Array).size(), 22, C_TEXT)
	var grid := GridContainer.new(); grid.columns = 8
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	var width := (_panel_width() - 28 - 84) / 8
	for card in CARD_ORDER:
		var tile := ResearchTile.new(); tile.game = self; tile.key = _card_key(card, "linked")
		tile.custom_minimum_size = Vector2(width, 300); grid.add_child(tile)
	panel_box.add_child(grid)


func _leave_research_for_drag() -> void:
	_tab = ""; sel.clear(); _inspect = -1
	panel.hide()
	_layout_ui(); _refresh_top_tabs(); queue_redraw()


func _research_selected(index: int) -> void:
	_choose_research(_card_key(str(CARD_ORDER[index]), "linked"))


func _choose_research(key: String) -> void:
	_catalogue_card = key; _panel_context = ""; _refresh_panel()


func _inspect_card(key: String) -> void:
	_selected_card = key; _tab = "card"; sel.clear(); _inspect = -1; _refresh_panel()


func _panel_card() -> void:
	if _selected_card == "": return
	var card: Dictionary = CARDS[_card_of(_selected_card)]
	_plabel(str(card.name), 20, FAMILY_COL[str(card.fam)])
	var art := HelpGlyph.new(); art.game = self; art.card = _card_of(_selected_card)
	art.custom_minimum_size = Vector2(110, 110); panel_box.add_child(art)
	_plabel(_card_description(_selected_card).split("\n")[1], 16, C_TEXT)
	_plabel("%d ready" % _held(PLAYER, _selected_card), 14, C_GOOD)


func _research_effect(key: String) -> String:
	var cd: Dictionary = CARDS[_card_of(key)]
	var text := ""
	match str(cd.effect):
		"defenders": text = "Remove %d%% of defenders." % int(float(cd.power) * 100)
		"breach": text = "Remove %d%% of defenders. Cut routes for %.0fs." % [int(float(cd.power) * 100), float(cd.dur)]
		"deny": text = "Stop production and routes for %.0fs." % float(cd.dur)
		"steal": text = "Steal resource production for %.0fs." % float(cd.dur)
	if bool(cd.chain): text += " Spreads along streets."
	return text


func _card_description(key: String) -> String:
	var cd: Dictionary = CARDS[_card_of(key)]
	var effect := ""
	match str(cd.effect):
		"defenders": effect = "Base effect: remove %d%% of current defenders." % int(float(cd.power) * 100)
		"breach": effect = "Remove %d%% of defenders and cut routing for %.0fs." % [int(float(cd.power) * 100), float(cd.dur)]
		"steal": effect = "Siphon resource production for %.0fs." % float(cd.dur)
		"deny": effect = "Stop production and routing for %.0fs." % float(cd.dur)
	return "%s\n%s Type resistance or weakness changes the effect.%s" % [str(cd.name), effect, " Spreads along streets; each later jump is less likely." if bool(cd.chain) else " Affects one building."]


func _card_detail(key: String, for_research: bool) -> void:
	var cd: Dictionary = CARDS[_card_of(key)]
	_plabel(str(cd.name), 20, FAMILY_COL[str(cd.fam)])
	var glyph := HelpGlyph.new(); glyph.game = self; glyph.card = _card_of(key)
	glyph.custom_minimum_size = Vector2(110, 110); panel_box.add_child(glyph)
	_plabel(("WORM · spreads" if bool(cd.chain) else "SINGLE · one building"), 12, C_DIM)
	_plabel(_card_description(key).split("\n")[1], 16, C_TEXT)
	if for_research:
		_plabel("Research: %s · %.0fs" % [_cost_text(key), _card_time(key)], 14, C_WARN)
		_btn("Queue research", _queue_research.bind(PLAYER, key), true, null, "Payments are spread across research time. Pauses if any input runs out.", 40)
	else:
		_plabel("%d held · no additional cost to play" % _held(PLAYER, key), 14, C_GOOD)
		var reachable := false
		for i in hosts.size():
			if _can_play(PLAYER, key, i) == "" and _card_scale(str(cd.fam), i) > 0: reachable = true; break
		_plabel("Ready · drag onto a reachable enemy" if reachable else "No valid target · capture a path from your rig", 14, C_GOOD if reachable else C_WARN)


func _family_line(fam: String) -> String:   # which types a card family hurts most / least
	var weak := []; var strong := []
	for t in NODE_TYPES.keys():
		var v := float((RESIST[t] as Dictionary).get(fam, 0.0))
		if v < 0.0: weak.append(str(NODE_TYPES[t].short))
		elif v >= 0.5: strong.append("%s %d %%" % [str(NODE_TYPES[t].short), int(round(v * 100.0))])
	var parts := []
	if not weak.is_empty(): parts.append("hurts " + ", ".join(weak) + " ×1.5")
	if not strong.is_empty(): parts.append("resisted by " + ", ".join(strong))
	return " · ".join(parts) if not parts.is_empty() else "lands evenly on every type"


# read-only slot view for a building you do NOT own: shows its TYPE and the buildings already inside it,
# FOGGED until you scan it (scan is launched from the launch-pad above). Never a build palette.
func _panel_enemy_slots(i: int) -> void:
	var scanned := _scanned(PLAYER, i)
	_plabel("Node buildings · %d/%d slots · bot capacity %d" % [_built(i).size(), int(hosts[i].slots), int(_cap_of(i))] if scanned else " ", 14, C_DIM)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER; row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for sl in int(hosts[i].slots):
		var ps := PeekSlot.new(); ps.game = self; ps.host = i; ps.slot = sl
		row.add_child(ps)
	panel_box.add_child(row)


func _panel_hand() -> void:
	pass


func _panel_result() -> void:
	if won: _plabel("✔ VICTORY", 20, C_GOOD)
	else: _plabel("✖ DEFEATED", 20, C_BAD)
	if _end_cause != "": _plabel(_end_cause, 14, C_TEXT)
	var rivs := []
	for fac in ais: rivs.append("%s %d" % [fname(fac), int(cash[fac])])
	_plabel("Elapsed %s  ·  buildings %d/%d  ·  Cash you %d · %s  ·  town #%d" % [_fmt_time(_t), _player_nodes(), hosts.size(), int(cash[PLAYER]), " · ".join(rivs), town_seed], 14, C_TEXT)
	_btn("📝 Tell us how it went", func(): _fb_status = ""; _open_menu(true); _menu_view = "feedback"; _refresh_menu())   # in-game feedback form
	_btn("↻ Restart in a new town", _reset)


func _type_line(i: int) -> String:   # "Database · 4 slots · Intel ×2"
	var tp: Dictionary = NODE_TYPES[str(hosts[i].get("type", "pc"))]
	var mults := ""
	for what in ["bot", "intel", "cash", "cred", "research"]:
		if float(tp.get(what, 1.0)) != 1.0: mults += " · %s ×%.1f" % [{"bot": "bots", "intel": "Intel", "cash": "Cash", "cred": "Creds", "research": "Research"}[what], float(tp[what])]
	return "%s · %d slots%s" % [str(tp.name), int(tp.slots), mults]


func _stage_line(i: int) -> String:   # one line that says what the building is right now
	var h: Dictionary = hosts[i]
	var tname := str(NODE_TYPES[str(h.get("type", "pc"))].name)
	if bool(h.get("junction", false)): tname += " · junction (streets carry ×%d)" % JUNCTION_CAP_MULT
	if not _mine(i) and not _scanned(PLAYER, i):
		return " "
	if int(h.owner) == NEUTRAL:
		return "Security %d/%d · %s" % [int(h.bots), int(h.sec), tname]
	if not _mine(i):
		return "%d/%d bots · %s" % [int(h.bots), int(_cap_of(i)), tname]
	return "%d/%d bots · %s · %d/%d working slots" % [int(h.bots), int(_cap_of(i)), ["Stable", "Shaky", "Critical"][_stage(i)], mini(_active_slots(i), _built(i).size()), int(h.slots)]


func _panel_build(i: int) -> void:
	var h: Dictionary = hosts[i]
	_plabel("Node buildings", 16, C_TEXT)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for slot in int(h.slots):
		var box := SlotBox.new(); box.game = self; box.host = i; box.slot = slot
		box.custom_minimum_size = Vector2(112, 140); row.add_child(box)
	panel_box.add_child(row)
	_plabel("Available buildings", 16, C_TEXT)
	var palette := HBoxContainer.new(); palette.add_theme_constant_override("separation", 8)
	for kind in BUILD_KINDS:
		var card := BuildCard.new(); card.game = self; card.kind = kind
		card.custom_minimum_size = Vector2(112, 140); palette.add_child(card)
	panel_box.add_child(palette)



func _panel_selecting() -> void:
	if sel.size() != 1:
		_plabel("%d buildings selected" % sel.size(), 20, C_TEXT)
		_connection_list(sel.keys())
		return
	var source := int(sel.keys()[0])
	var heading := HBoxContainer.new(); panel_box.add_child(heading)
	_lbl(heading, str(hosts[source].name), 20, C_TEXT, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plabel(_stage_line(source), 14, C_TEXT)
	var target := int(hosts[source].assign)
	_panel_build(source)
	var guards := _owned_feeders(source)
	var connections: Array = guards.duplicate()
	if target >= 0: connections.push_front(source)
	if not connections.is_empty(): _connection_list(connections)


func _disconnect_source(source: int) -> void:
	if not _mine(source): return
	hosts[source].assign = -1; hosts[source].live = false; _next_depart.erase(source)
	_refresh_panel(); queue_redraw()


func _fixed_button_style(button: Button, red := false) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.08, 0.1) if red else Color(0.09, 0.12, 0.17)
		if state == "hover": style.bg_color = style.bg_color.lightened(0.08)
		style.border_color = C_BAD if red else C_DIM
		style.set_border_width_all(1); style.set_corner_radius_all(4)
		style.content_margin_left = 2; style.content_margin_right = 2
		style.content_margin_top = 0; style.content_margin_bottom = 0
		button.add_theme_stylebox_override(state, style)


func _connection_chip(source: int, label: String, parent: Control) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(row)
	var name_label := _lbl(row, label, 13, C_DIM, 0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.custom_minimum_size.x = 146
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var button := Button.new(); button.text = "×"; button.name = "Disconnect_%d" % source
	button.custom_minimum_size = Vector2(28, 28); button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", C_BAD)
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.3, 0.08, 0.1)
	style.border_color = C_BAD; style.set_border_width_all(1); style.set_corner_radius_all(4)
	_fixed_button_style(button, true)
	button.pressed.connect(_disconnect_source.bind(source)); row.add_child(button)


func _connection_list(sources: Array) -> void:
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 0)
	panel_box.add_child(grid)
	for header in ["Source", "Target", "Disconnect"]:
		_lbl(grid, header, 12, C_DIM, 220 if header != "Disconnect" else 90)
	for source in sources:
		var target := int(hosts[int(source)].assign)
		_lbl(grid, str(hosts[int(source)].name), 13, C_TEXT, 220)
		_lbl(grid, str(hosts[target].name) if target >= 0 else "—", 13, C_TEXT, 220)
		var button := Button.new(); button.text = "×"; button.name = "Disconnect_%d" % source
		button.custom_minimum_size = Vector2(28, 24); button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 14); button.add_theme_color_override("font_color", C_BAD)
		_fixed_button_style(button, true)
		button.pressed.connect(_disconnect_source.bind(int(source))); grid.add_child(button)


func _assault_preview(t: int, conns: Array) -> void:
	var potential := 0.0
	for source in conns:
		if not _route(source, t).is_empty(): potential += SEND_RATE * float(hosts[source].rate)
	_plabel("Potential: %.1f bots/s, using up to %.1f Intel/s. Actual flow depends on bots, Intel and route capacity." % [potential, potential], 14, C_DIM)


func _panel_node_in(t: int) -> void:
	var conns := _owned_feeders(t)
	if conns.is_empty(): return
	if _mine(t):
		_connection_list(conns)
		return
	var live := 0; var attacks := 0
	var waiting := {}
	for source in conns:
		if bool(hosts[source].live):
			live += 1
			if str(hosts[source].mode) == "attack": attacks += 1
		var state := _src_state(source)
		if state in ["no Intel", "no bots", "no route", "routing cut", "link busy"]: waiting[state] = true
	var dormant := conns.size() - live
	var title := "Connected"
	if attacks > 0: title = "Attacking" if _scanned(PLAYER, t) else "Attacking blind"
	elif live > 0: title = "Scanning · no damage"
	_plabel(title, 18, C_TEXT)
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 12); panel_box.add_child(actions)
	if live > 0:
		_action_button("Stop", _halt.bind(t), actions)
	elif _scanned(PLAYER, t):
		_action_button("Attack", _launch.bind(t, "attack"), actions)
	else:
		_action_button("Scan", _launch.bind(t, "scan"), actions)
	if waiting.has("no Intel"): _plabel("Waiting for Intel · add a harvester or stop another attack.", 14, C_WARN)
	elif waiting.has("no bots"): _plabel("Waiting for bots to regenerate", 14, C_WARN)
	elif not waiting.is_empty(): _plabel(", ".join(waiting.keys()), 14, C_WARN)
	_connection_list(conns)
	_plabel(_operation_observation(t), 14, C_TEXT)


func _operation_observation(t: int) -> String:
	var sent := 0; var in_air := 0
	for d in _departures:
		if int(d.target) == t and str(d.kind) == "bot": sent += 1
	for f in flights:
		if int(f.owner) == PLAYER and int(f.route.back()) == t and str(f.kind) in ["bot", "scan"]: in_air += 1
	return "%.1f bots/s sent · %d in transit" % [float(sent) / maxf(1, minf(4, _t)), in_air]


func _panel_inspect() -> void:
	var i := _inspect
	if _mine(i):
		_plabel(str(hosts[i].name), 20, C_TEXT)
		_plabel(_stage_line(i), 14, C_TEXT)
		_panel_build(i)
		return
	_plabel(str(hosts[i].name), 20, C_TEXT)
	_plabel(_stage_line(i), 14, C_DIM)
	_panel_enemy_slots(i)
	_panel_node_in(i)


func _panel_attack_diag(t: int, _feeders: Array, _sending: Array) -> void:
	_plabel(_operation_observation(t), 16, C_TEXT)


func _panel_idle() -> void:
	_plabel("Hold more than half the town to win.", 16, C_TEXT)
	_gap(2.0)
	_plabel("①  Drag from your building onto a target to connect.", 13)
	_plabel("②  Click the target → SCAN or ATTACK.", 13)
	_plabel("③  Drag a card from your hand onto a reachable enemy.", 13)
	_gap(4.0)
	_plabel("Drag empty map to pan · wheel to zoom · 0 recenters", 11, C_DIM)
	_plabel("Esc menu · Space pause · R research · L board", 11, C_DIM)


func _panel_board() -> void:
	_plabel("Leaderboard", 22, C_TEXT)
	var standings := []
	for fac in botnets: standings.append([fac, _faction_nodes(fac)])
	standings.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	for index in standings.size():
		var fac := int(standings[index][0]); var count := int(standings[index][1])
		var status := "Out" if _eliminated.has(fac) else "%d buildings · %d%%" % [count, _control_pct(fac)]
		_plabel("%d. %s    %s" % [index + 1, "You" if fac == PLAYER else fname(fac), status], 16, fcol(fac).lightened(0.3))


func _control_pct(fac: int) -> int:
	return int(round(100.0 * float(_faction_nodes(fac)) / float(maxi(1, hosts.size()))))


# per-second income − spend for a resource, so the HUD can show whether it's rising or falling
func _res_income(res: String) -> float:
	match res:
		"intel": return _intel_rate(PLAYER)
		"cash": return _cash_rate(PLAYER)
		"creds": return _cred_rate(PLAYER)
		"research": return _research_rate(PLAYER)
	return 0.0


func _res_spend(res: String) -> float:
	if res == "intel": return _attack_demand(PLAYER)
	var L: Dictionary = lab[PLAYER]
	var q: Array = L.queue
	if q.is_empty() or bool(L.paused) or str(L.stall) != "": return 0.0   # nothing is consuming
	var key := str(q[0]); var tm := _card_time(key)
	if tm <= 0.0: return 0.0
	return float((_card_cost(key) as Dictionary).get(res, 0.0)) / tm


func _rate_tag(res: String) -> String:
	var net := _observed_net(res)
	if absf(net) < 0.05: net = 0.0
	return " %+.1f/s" % net


func _rate_col(res: String) -> Color:
	var net := _observed_net(res)
	if net > 0.05: return C_GOOD
	if net < -0.05: return C_WARN
	return C_TEXT


func _hud_items() -> Array:   # the HUD, one glance: just YOUR resources (control % and time live on the BOARD)
	# [kind, text, colour, column width] — every item owns a fixed column, so a growing number never shifts the row
	return [
		["intel", "%d/%d%s" % [int(intel[PLAYER]), int(_intel_cap(PLAYER)), _rate_tag("intel")], _rate_col("intel"), 185.0],
		["cash", "%d%s" % [int(cash[PLAYER]), _rate_tag("cash")], _rate_col("cash"), 150.0],
		["cred", "%d/%d%s" % [int(creds[PLAYER]), int(_res_cap(PLAYER, "cred")), _rate_tag("creds")], _rate_col("creds"), 170.0],
		["lab", "%d/%d%s" % [int(research[PLAYER]), int(_res_cap(PLAYER, "lab")), _rate_tag("research")], _rate_col("research"), 170.0],
	]


func _hud_text() -> String:   # probes and scripts: the HUD as one line
	var parts := []
	for it in _hud_items(): parts.append(("%s " % {"cash": "Cash", "intel": "Intel", "cred": "Creds", "lab": "Research"}[str(it[0])] if str(it[0]) != "" else "") + str(it[1]))
	return "   ·   ".join(parts)


# ============================================================ DRAW
# the building whose plan is in focus: the one under a dragged line, else the one whose panel is open
func _aim_target() -> int:
	if _dragging and _drag_from >= 0:
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and hov != _drag_from: return hov
	return _inspect


# the sources whose routes light up for the focused building: everything WIRED into it, plus the drag group
func _aim_sources() -> Array:
	var out := {}
	var aim := _aim_target()
	if aim >= 0:
		for i in _owned_feeders(aim): out[int(i)] = true
	if _dragging and _drag_from >= 0:
		if sel.has(_drag_from):
			for s in sel.keys(): out[int(s)] = true
		else: out[_drag_from] = true
	return out.keys()


func _lk(a: int, b: int) -> String: return "%d_%d" % [mini(a, b), maxi(a, b)]


func _wire_visible(i: int) -> bool:   # a foreign wire is public only while it flows and is not a quiet scan (a guard is never a scan)
	if not bool(hosts[i].live): return false
	var a := int(hosts[i].assign)
	if a >= 0 and int(hosts[a].owner) == int(hosts[i].owner): return true
	return str(hosts[i].get("mode", "attack")) != "scan"


func _link_busy_visible(a: int, b: int) -> bool:   # a street at capacity, judged from the traffic you can see
	var n := 0
	for fl in flights:
		if str(fl.kind) == "scan" and int(fl.owner) != PLAYER: continue
		var rt: Array = fl.route; var hops: Array = fl.hops
		for k in hops.size():
			if float(hops[k]) <= _t and _t < float(hops[k]) + LINK_TIME and ((int(rt[k]) == a and int(rt[k + 1]) == b) or (int(rt[k]) == b and int(rt[k + 1]) == a)): n += 1
	return n >= _link_cap(a, b)


func _focus_route(rt: Array, flinks: Dictionary) -> void:
	for k in range(rt.size() - 1): flinks[_lk(int(rt[k]), int(rt[k + 1]))] = true


# the focused subgraph for building `aim`: STRICTLY the building itself, the buildings WIRED into it
# (any faction), the one its own wire points at, and the drag group. Route intermediates light their
# LINKS only — the buildings a route merely passes through stay fogged, as does everything unconnected
# (threat rings still draw at full brightness on fogged buildings, so an attack elsewhere is never invisible).
func _build_focus(aim: int, fnodes: Dictionary, flinks: Dictionary) -> void:
	fnodes[aim] = true
	for i in hosts.size():                      # incoming: everyone VISIBLY wired into it (yours: always; others: live, not a quiet scan)
		if int(hosts[i].assign) == aim and (_mine(i) or _wire_visible(i)):
			fnodes[i] = true
			_focus_route(_route(i, aim), flinks)
	var aout := int(hosts[aim].assign)          # outgoing: whom this building itself is wired to — a foreign plan only while it visibly flows
	if aout >= 0 and (_mine(aim) or _wire_visible(aim)):
		fnodes[aout] = true
		_focus_route(_route(aim, aout), flinks)
	for s in _aim_sources():                    # the drag group while a wire is being aimed
		if int(s) == aim: continue
		fnodes[int(s)] = true
		_focus_route(_route(int(s), aim), flinks)


func _fill_of(i: int) -> Color:
	var fac := int(hosts[i].owner)
	if fac == NEUTRAL and bool(hosts[i].hub): return Color(0.2, 0.75, 0.9)
	return fcol(fac)


func _draw() -> void:
	var f := get_theme_default_font()
	if menu_open:
		_draw_menu_bg(get_viewport_rect().size)   # the old drifting-packet backdrop; the menu panel draws on top
		return
	draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))   # map layer: everything below is in WORLD space (zoom/pan)
	var aim := _aim_target()
	var focus_on := aim >= 0
	var fnodes := {}; var flinks := {}
	if focus_on: _build_focus(aim, fnodes, flinks)
	for i in hosts.size():   # streets, tinted by the botnet holding both ends; amber when at capacity
		for j in hosts[i].links:
			if j < i: continue
			var oi := int(hosts[i].owner); var oj := int(hosts[j].owner)
			var lcol := Color(0.35, 0.5, 0.7, 0.18); var w := 1.0
			if _highways.has(_lk(i, int(j))): lcol = Color(0.55, 0.7, 0.85, 0.3); w = 2.2   # a highway across a gap
			if oi == oj and oi != NEUTRAL: lcol = fcol(oi); lcol.a = 0.35; w = (2.4 if _highways.has(_lk(i, int(j))) else 1.3)
			if _link_busy_visible(i, int(j)): lcol = Color(1, 0.75, 0.3, 0.65); w = 1.8
			if focus_on and not flinks.has(_lk(i, int(j))): lcol.a *= 0.6
			draw_line(hosts[i].pos, hosts[int(j)].pos, lcol, w, true)
	# connections. LIVE = solid flowing route; DORMANT = the dashed plan (nothing moving, nothing spent);
	# Strict fog: only the focused building's own connections stay bright.
	for i in hosts.size():
		var a := int(hosts[i].assign)
		if a < 0:
			var d := _bot_target(i)
			if d >= 0 and _next_depart.has(i): _draw_route_line(_route(i, d), i, d, true)
			continue
		var dimmed: bool = focus_on and not (fnodes.has(i) and fnodes.has(a))
		if not _mine(i) and not _wire_visible(i): continue   # others' quiet scans and dormant plans are invisible — to you and to them
		if bool(hosts[i].live):
			_draw_route_line(_route(i, a), i, a, dimmed)
		else:
			var kcol: Color = Color(0.45, 0.95, 0.7, 0.8) if int(hosts[a].owner) == int(hosts[i].owner) else Color(1, 0.85, 0.4, 0.8)
			if not _mine(i): kcol = fcol(int(hosts[i].owner)); kcol.a = 0.45
			if dimmed: kcol.a *= 0.25
			var rt := _route(i, a)
			if rt.size() >= 2: _draw_dashed(rt, kcol, 1.2)
			else: _draw_dashed([i, a], Color(0.8, 0.5, 0.5, (0.15 if dimmed else 0.55)), 1.0)   # your unrouted plan (only yours reach here)
	for fl in flights:   # packets: yours = circle, other botnets = square in their colour, Cash = diamond
		var pp := _packet_pos(fl, _t)
		var endn := int((fl.route as Array)[(fl.route as Array).size() - 1])
		var threat: bool = int(fl.owner) != PLAYER and _mine(endn)
		var ba: float = 1.0 if (not focus_on or fnodes.has(endn) or threat) else 0.3
		var fc := fcol(int(fl.owner))
		if str(fl.kind) == "scan":
			if int(fl.owner) == PLAYER: draw_arc(pp, 3.5, 0.0, TAU, 12, Color(0.6, 0.95, 1.0, ba), 1.5, true)   # a quiet scan: only you see it
			continue
		if str(fl.kind) == "card":   # a card in flight: its remaining path dashed in its colour (the packet itself is drawn above the buildings)
			var cc: Color = FAMILY_COL[str(CARDS[_card_of(str(fl.get("card", "stuff:linked")))].fam)]
			var rt: Array = fl.route; var hops: Array = fl.hops
			var nxt := rt.size() - 1
			for k in hops.size():
				if _t < float(hops[k]) + LINK_TIME: nxt = k + 1; break
			var path := [pp]
			for k in range(nxt, rt.size()): path.append(hosts[int(rt[k])].pos)
			for k in range(path.size() - 1):
				var a2: Vector2 = path[k]; var b2: Vector2 = path[k + 1]
				var ln := a2.distance_to(b2); var dir := (b2 - a2) / maxf(ln, 0.001); var d := 0.0
				while d < ln:
					draw_line(a2 + dir * d, a2 + dir * minf(d + 6.0, ln), Color(cc.r, cc.g, cc.b, 0.5), 1.2, true)
					d += 11.0
			continue
		if str(fl.kind) == "cash":
			var c := Color(1, 0.9, 0.3, ba) if int(fl.owner) == PLAYER else Color(fc.r, fc.g, fc.b, ba).lightened(0.3)
			draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -4), pp + Vector2(4, 0), pp + Vector2(0, 4), pp + Vector2(-4, 0)]), c)
		elif int(fl.owner) == PLAYER: draw_circle(pp, 3.5, Color(0.5, 1, 0.7, ba))
		else: draw_rect(Rect2(pp - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), Color(fc.r, fc.g, fc.b, ba).lightened(0.25), true)
	for w in _worms:   # a worm's jumps: a bold trail, a pulse racing to the newly-infected building, a ring on it
		var wa := clampf((float(w.until) - _t) / 4.0, 0.0, 1.0)
		var wc: Color = w.col
		var a_pos: Vector2 = hosts[int(w.a)].pos
		var b_pos: Vector2 = hosts[int(w.b)].pos
		draw_line(a_pos, b_pos, Color(wc.r, wc.g, wc.b, 0.28 * wa), 7.0, true)   # underglow
		draw_line(a_pos, b_pos, Color(wc.r, wc.g, wc.b, 0.95 * wa), 3.0, true)   # core
		var prog := clampf((4.0 - (float(w.until) - _t)) / 0.7, 0.0, 1.0)         # pulse races a→b in the first 0.7 s
		draw_circle(a_pos.lerp(b_pos, prog), 5.0, Color(1, 1, 1, 0.9 * wa))
		draw_arc(b_pos, _r(int(w.b)) + 5.0, 0.0, TAU, 28, Color(wc.r, wc.g, wc.b, 0.95 * wa), 2.5, true)
	for i in hosts.size():   # strict fog: ONLY buildings connected to the focused one stay bright
		_draw_node(f, i, 1.0 if (not focus_on or fnodes.has(i)) else 0.6, i == aim)
	for fl in flights:   # card packets ride above everything: a glowing card shape in the family's colour
		if str(fl.kind) != "card": continue
		var pp2 := _packet_pos(fl, _t)
		var cc2: Color = FAMILY_COL[str(CARDS[_card_of(str(fl.get("card", "stuff:linked")))].fam)]
		draw_circle(pp2, 11.0, Color(cc2.r, cc2.g, cc2.b, 0.25))
		draw_rect(Rect2(pp2 - Vector2(5.0, 7.0), Vector2(10, 14)), cc2, true)
		draw_rect(Rect2(pp2 - Vector2(5.0, 7.0), Vector2(10, 14)), Color(1, 1, 1, 0.95), false, 1.2)
	for x in _fx:   # a card landed: an expanding frame in the caster's colour
		var rem := clampf((float(x.until) - _t) / 3.0, 0.0, 1.0)
		var xc: Color = x.col; xc.a = rem
		_frame(hosts[int(x.host)].pos, _r(int(x.host)) + 10.0 + (1.0 - rem) * 14.0, xc, 1.5)
	if focus_on:   # rings: GOLD = friendly connections, wide RED = hostile buildings wired into it
		var gold := Color(1, 0.85, 0.3, 0.95)
		var red := Color(1, 0.35, 0.3, 0.95)
		for i in hosts.size():
			if i != aim and int(hosts[i].assign) == aim and (_mine(i) or _wire_visible(i)):
				_node_frame(i, 11, gold if _mine(i) else red, 1.8)   # gold = yours, red = another botnet's
		var aout := int(hosts[aim].assign)
		if aout >= 0 and (_mine(aim) or _wire_visible(aim)): _node_frame(aout, 11, gold, 1.8)
		var reach := 0
		for s in _aim_sources():
			if _link_kind(int(s), aim) != "": _draw_dashed(_route(int(s), aim), Color(1, 0.95, 0.55, 0.95), 1.6); reach += 1
		if _dragging and reach == 0:
			draw_string(f, _label_pos(aim), "✖ no path to %s" % str(hosts[aim].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.45, 0.4))
		else:
			var act: String = "🛡 defend %s" if _mine(aim) else "⚔ attack %s"
			pass # selected target already has a readable screen-space name
	elif not sel.is_empty():   # connect step: glow where a wire could go + hover preview
		var src_keys: Array = sel.keys()
		for i in hosts.size():
			var ok := false
			for s in src_keys:
				if _link_kind(int(s), i) != "": ok = true; break
			if ok: _frame(hosts[i].pos, _r(i) + 7.0, Color(1, 0.8, 0.4, 0.55), 2.0)
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and not sel.has(hov):
			var elig := 0
			for s in src_keys:
				if _link_kind(int(s), hov) != "": _draw_dashed(_route(int(s), hov)); elig += 1
			if elig > 0:
				draw_string(f, _label_pos(hov), "drag here to connect %s" % str(hosts[hov].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.5))
	var dk := _dragged_card()
	if dk != "":   # a hand card in the air: where it can land, and what it would do there
		var cd: Dictionary = CARDS[_card_of(dk)]
		var cc: Color = FAMILY_COL[str(cd.fam)]
		for i in hosts.size():
			if _can_play(PLAYER, dk, i) == "" and _card_scale(str(cd.fam), i) > 0.0: _frame(hosts[i].pos, _r(i) + 7.0, Color(cc.r, cc.g, cc.b, 0.7), 2.0)
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0:
			var sc := _card_scale(str(cd.fam), hov)
			var why := _can_play(PLAYER, dk, hov)
			var txt: String = ("✖ your own building" if int(hosts[hov].owner) == PLAYER else ("✖ " + why if why != "" else ("✖ immune" if sc <= 0.0 else "▼ " + _effect_text(cd, hov, sc))))
			var ok: bool = why == "" and sc > 0.0
			if ok: _frame(hosts[hov].pos, _r(hov) + 9.0, cc, 2.5)
			pass # full-size preview is shown in the reserved feedback lane
	if _dragging and _drag_from >= 0:   # the rubber band: RED over a target no selected source has a path to
		var to := _mouse_world()
		var hv := _host_at(get_local_mouse_position())
		var lcol2 := Color(1, 0.95, 0.55, 0.95)
		if hv >= 0 and hv != _drag_from:
			to = hosts[hv].pos
			var ok := false
			for s in _aim_sources():
				if _link_kind(int(s), hv) != "": ok = true; break
			if not ok: lcol2 = Color(1, 0.4, 0.35, 0.95)
		draw_line(hosts[_drag_from].pos, to, lcol2, 1.8, true)
		draw_circle(to, 3.0, lcol2)
	if _boxing:
		var ws := _s2w(_box_start)
		var r := Rect2(ws, _mouse_world() - ws).abs()
		draw_rect(r, Color(0.6, 1, 1, 0.08), true)
		draw_rect(r, Color(0.6, 1, 1, 0.6), false, 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # back to SCREEN space for the overlays below
	var sz := get_viewport_rect().size
	# Mask map content outside its reserved area; controls draw above this.
	var map := _map_rect()
	var background := Color(0.04, 0.05, 0.08)
	draw_rect(Rect2(0, 0, sz.x, map.position.y - 8), background)
	if _panel_shown(): draw_rect(Rect2(map.end.x + 8, 88, sz.x - map.end.x, sz.y - 264), background)
	if won or lost:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.55), true)
		draw_string(f, Vector2((sz.x - PANEL_W) * 0.5 - 150.0, sz.y * 0.5), ("VICTORY" if won else "DEFEATED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(0.5, 1, 1) if won else Color(1, 0.5, 0.5))


func _draw_menu_bg(sz: Vector2) -> void:   # ported from the old title screen: grid + drifting packets
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.06, 0.09), true)
	var grid := Color(0.2, 1.0, 0.9, 0.06)
	for x in range(0, int(sz.x) + 1, 40): draw_line(Vector2(x, 0), Vector2(x, sz.y), grid)
	for y in range(0, int(sz.y) + 1, 40): draw_line(Vector2(0, y), Vector2(sz.x, y), grid)
	var cols := [Color(0.4, 1.0, 0.5), Color(0.35, 0.7, 1.0), Color(1.0, 0.85, 0.2)]
	for i in 60:
		var yy := fmod(float(i) * 97.0, maxf(sz.y, 1.0))
		var xx := fmod(_menu_t * (30.0 + float(i) * 7.0) + float(i) * 131.0, sz.x + 40.0) - 20.0
		var c: Color = cols[i % 3]; c.a = 0.55
		draw_circle(Vector2(xx, yy), 2.5, c)


func _visible_bot_count(i: int) -> String:
	return str(int(round(float(hosts[i].bots)))) if _mine(i) or _scanned(PLAYER, i) else "?"


func _node_frame(i: int, margin: float, col: Color, width: float) -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_frame(_w2s(hosts[i].pos), maxf(16, _r(i) * _zoom) + margin, col, width)
	draw_set_transform(_pan, 0, Vector2(_zoom, _zoom))


func _draw_node(f: Font, i: int, a: float, is_aim: bool) -> void:
	var p := _w2s(hosts[i].pos)
	var rr := maxf(16, _r(i) * _zoom)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var fill := _fill_of(i)
	fill.a = a
	var ink := Color(0.04, 0.06, 0.1, 0.9 * a)
	var focused: bool = sel.has(i) or i == _inspect or is_aim
	_draw_type_glyph(self, str(hosts[i].get("type", "pc")), p, rr * 1.9, fill, ink)   # the building IS its pictogram
	if bool(hosts[i].rig): _frame(p, rr + 1.0, Color(1, 1, 1, 0.8 * a), 2.0)   # a rig = Cash sink
	if bool(hosts[i].get("junction", false)): _frame(p, rr + 1.5, Color(0.75, 0.9, 1.0, 0.7 * a), 1.0)   # a junction: double traffic
	if _mine(i) and _under_attack(i):   # under attack → red frame, always full brightness (never fogged)
		_frame(p, rr + 3.0, Color(1, 0.4, 0.35, 0.95), 2.5)
	if _prod_down(i): _frame(p, rr + 4.5, Color(1, 0.62, 0.2, 0.9), 1.5)      # a card: production off
	if _routing_down(i): _frame(p, rr + 6.0, Color(1, 0.35, 0.65, 0.9), 1.5)  # a card: routing cut
	if _stolen(i): _frame(p, rr + 7.5, FAMILY_COL["supply"], 1.5)             # a card: production siphoned
	if sel.has(i): _frame(p, rr + 6.0, Color(1, 1, 1, 0.95 * a), 2.0)
	if i == _inspect: _frame(p, rr + 8.0, Color(1, 0.9, 0.3, a), 1.5)
	if is_aim: _frame(p, rr + 9.0, Color(1, 0.9, 0.3), 2.0)
	if i == _tutorial_target() or (_tut and _tut_stage <= 3 and i == _tut_target):
		_frame(p, rr + 13, C_WARN, 3)
		if i == _tut_target: draw_circle(p + Vector2(0, -rr - 18), 5, C_WARN)
	var nb_txt := _visible_bot_count(i)
	var bw := 8.0 + 7.0 * float(nb_txt.length())
	draw_rect(Rect2(p.x - bw * 0.5, p.y + rr * 0.42, bw, 13.0), Color(0.03, 0.05, 0.08, 0.88 * a), true)
	draw_string(f, Vector2(p.x - 3.6 * float(nb_txt.length()), p.y + rr * 0.42 + 10.5), nb_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.97, 1.0, a))
	var nm := str(hosts[i].name)
	if _tut: nm = nm.replace("TRAINING TARGET", "TARGET").replace("TRAINING SUPPORT", "SUPPORT")
	if _zoom < 0.45 and not focused and not _mine(i) and i != _host_at(get_local_mouse_position()) and not (_tut and i == _tut_target): nm = ""
	var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var x0 := p.x - nw * 0.5   # name centred above the glyph
	var ncol := Color(0.85, 0.92, 1.0, a) if not _mine(i) else Color(0.95, 1.0, 0.95, a)
	draw_string(f, Vector2(x0, p.y - rr - 8.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ncol)
	var sub := ""   # ONE warning under the glyph, most urgent first; the rest is in the panel
	if bool(hosts[i].get("junction", false)): sub = "junction"
	var st := _stage(i)
	var known: bool = _mine(i) or _scanned(PLAYER, i)
	if known and int(hosts[i].owner) != NEUTRAL and st == 2: sub = "CRITICAL"
	elif known and int(hosts[i].owner) != NEUTRAL and st == 1: sub = "SHAKY"
	elif _mine(i) and float(hosts[i].bots) >= _cap_of(i) - 0.5 and _incoming(i, PLAYER) > 0.0: sub = "FULL ↩"
	elif _stolen(i): sub = "SIPHON %ds" % int(ceil(float(hosts[i].steal_until) - _t))
	elif _prod_down(i): sub = "OFF %ds" % int(ceil(float(hosts[i].prod_off)))
	elif _routing_down(i): sub = "CUT %ds" % int(ceil(float(hosts[i].route_off)))
	var subcol := Color(1, 0.85, 0.4, a)
	if sub == "junction": subcol = Color(0.7, 0.85, 1.0, 0.8 * a)
	if sub.begins_with("SIPHON"): subcol = Color(FAMILY_COL["supply"].r, FAMILY_COL["supply"].g, FAMILY_COL["supply"].b, a)
	if sub.begins_with("OFF"): subcol = Color(1, 0.62, 0.2, a)
	elif sub.begins_with("CUT"): subcol = Color(1, 0.4, 0.65, a)
	elif sub == "CRITICAL": subcol = Color(1, 0.5, 0.45, a)
	if focused and _mine(i):   # details only while you look at it: what is built, the send rate
		var bi := ""
		var bl := _built(i); var act := _active_slots(i)
		for k in bl.size():
			var sh: String = str(BUILD_KINDS[str(bl[k][1])].short)
			bi += sh if k < act else sh.to_lower()
		if not (hosts[i].jobs as Dictionary).is_empty(): bi += "…"
		if float(hosts[i].rate) < 1.0: bi += ("  " if bi != "" else "") + "%d%%" % int(round(float(hosts[i].rate) * 100.0))
		if bi != "": sub = bi if sub == "" else sub + "  " + bi
	if sub != "" and (_zoom >= 0.45 or focused or _mine(i)):
		var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(f, Vector2(p.x - sw * 0.5, p.y + rr + 16.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, subcol)
	draw_set_transform(_pan, 0, Vector2(_zoom, _zoom))


func _label_pos(i: int) -> Vector2:   # where a floating label for building i goes: above it, or below it near the top edge
	var p: Vector2 = hosts[i].pos
	var y := p.y - _r(i) - 24.0
	if y < 56.0: y = p.y + _r(i) + 34.0
	return Vector2(p.x - _r(i), y)


func _draw_dashed(rt: Array, col := Color(1, 0.9, 0.5, 0.9), w := 1.2) -> void:   # dashed = a dormant plan
	for k in range(rt.size() - 1):
		var a: Vector2 = hosts[int(rt[k])].pos
		var b: Vector2 = hosts[int(rt[k + 1])].pos
		var ln := a.distance_to(b)
		var dir := (b - a) / maxf(ln, 0.001)
		var d := 0.0
		while d < ln:
			draw_line(a + dir * d, a + dir * minf(d + 9.0, ln), col, w, true)
			d += 15.0


# colour by the SOURCE's faction, shape by kind (defend/reinforce = diamond, attack = arrow)
func _draw_route_line(rt: Array, src: int, tgt: int, dim := false) -> void:
	if rt.size() < 2: return
	var from_player: bool = _mine(src)
	var reinforce: bool = int(hosts[src].owner) == int(hosts[tgt].owner)
	var col: Color
	if from_player and not reinforce: col = Color(1, 0.85, 0.35)
	elif from_player and reinforce: col = Color(0.4, 1, 0.7)
	else:
		col = fcol(int(hosts[src].owner)).lightened(0.15)
		if not _mine(tgt): col = col.darkened(0.2)          # an attack on someone else reads duller than one on you
	var fade := 0.3 if dim else 1.0
	var pts := PackedVector2Array()
	for idx in rt: pts.append(hosts[int(idx)].pos)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.16 * fade), 3.2, true)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.9 * fade), 1.4, true)
	var a: Vector2 = hosts[int(rt[rt.size() - 2])].pos
	var b: Vector2 = hosts[int(rt[rt.size() - 1])].pos
	var dir: Vector2 = (b - a).normalized()
	var tip: Vector2 = b - dir * (_r(tgt) + 3.0)
	var perp := Vector2(-dir.y, dir.x)
	var c := Color(col.r, col.g, col.b, 0.95 * fade)
	if reinforce:
		var ctr := tip - dir * 5.0
		draw_colored_polygon(PackedVector2Array([ctr + dir * 5.0, ctr + perp * 4.0, ctr - dir * 5.0, ctr - perp * 4.0]), c)
	else:
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 9.0 + perp * 5.0, tip - dir * 9.0 - perp * 5.0]), c)


# ============================================================ LOCAL VIEW WIDGETS (slots & cards)
# Icons are drawn procedurally so the prototype needs no art: each building kind has a glyph and a colour.
func _draw_kind_icon(c: CanvasItem, kind: String, centre: Vector2, sz: float, col: Color, f: Font) -> void:
	var ink := Color(0.06, 0.08, 0.12, col.a)
	match kind:
		"bot":   # a server rack: three units with a status LED each
			for r in 3:
				var y := centre.y - sz * 0.46 + float(r) * sz * 0.34
				c.draw_rect(Rect2(centre.x - sz * 0.45, y, sz * 0.9, sz * 0.26), col, true)
				c.draw_circle(Vector2(centre.x + sz * 0.3, y + sz * 0.13), sz * 0.06, ink)
		"intel":   # an eye with an antenna arc
			c.draw_arc(centre, sz * 0.4, 0.0, TAU, 32, col, sz * 0.09, true)
			c.draw_circle(centre, sz * 0.15, col)
			c.draw_arc(centre + Vector2(0, sz * 0.1), sz * 0.62, -2.45, -0.7, 16, col, sz * 0.07, true)
		"cash":   # a coin with a $ sign
			c.draw_circle(centre, sz * 0.46, col)
			c.draw_arc(centre, sz * 0.36, 0.0, TAU, 32, ink, sz * 0.04, true)
			c.draw_string(f, centre + Vector2(-sz * 0.17, sz * 0.21), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz * 0.62), ink)
		"cred":   # a key
			c.draw_arc(centre + Vector2(-sz * 0.24, 0), sz * 0.19, 0.0, TAU, 20, col, sz * 0.11, true)
			c.draw_line(centre + Vector2(-sz * 0.05, 0), centre + Vector2(sz * 0.47, 0), col, sz * 0.11, true)
			c.draw_line(centre + Vector2(sz * 0.3, 0), centre + Vector2(sz * 0.3, sz * 0.2), col, sz * 0.1, true)
			c.draw_line(centre + Vector2(sz * 0.44, 0), centre + Vector2(sz * 0.44, sz * 0.15), col, sz * 0.1, true)
		"lab":    # a flask with liquid
			var fl := PackedVector2Array([centre + Vector2(-sz * 0.12, -sz * 0.46), centre + Vector2(sz * 0.12, -sz * 0.46), centre + Vector2(sz * 0.12, -sz * 0.1),
				centre + Vector2(sz * 0.44, sz * 0.38), centre + Vector2(sz * 0.36, sz * 0.46), centre + Vector2(-sz * 0.36, sz * 0.46), centre + Vector2(-sz * 0.44, sz * 0.38), centre + Vector2(-sz * 0.12, -sz * 0.1)])
			c.draw_colored_polygon(fl, col)
			c.draw_colored_polygon(PackedVector2Array([centre + Vector2(-sz * 0.3, sz * 0.2), centre + Vector2(sz * 0.3, sz * 0.2), centre + Vector2(sz * 0.38, sz * 0.4), centre + Vector2(-sz * 0.38, sz * 0.4)]), ink)
			c.draw_circle(centre + Vector2(-sz * 0.1, sz * 0.06), sz * 0.05, ink)
		_:
			c.draw_rect(Rect2(centre - Vector2(sz * 0.4, sz * 0.4), Vector2(sz * 0.8, sz * 0.8)), col, false, 2.0)


func _frame(p: Vector2, half: float, col: Color, w: float) -> void:   # a square frame around a pictogram
	draw_rect(Rect2(p - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), col, false, w)


func _ellipse(centre: Vector2, rx: float, ry: float, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n: pts.append(centre + Vector2(cos(TAU * float(k) / float(n)) * rx, sin(TAU * float(k) / float(n)) * ry))
	return pts


# the seven building types as filled pictograms in `fill` with details in `ink`, inside a square of side `sz`
func _draw_type_glyph(c: CanvasItem, t: String, centre: Vector2, sz: float, fill: Color, ink: Color) -> void:
	var w := maxf(1.2, sz * 0.05)
	var dim := Color(ink.r, ink.g, ink.b, ink.a * 0.35)
	match t:
		"pc":      # a monitor on a stand
			var body := Rect2(centre + Vector2(-sz * 0.46, -sz * 0.46), Vector2(sz * 0.92, sz * 0.6))
			c.draw_rect(body, fill, true); c.draw_rect(body, ink, false, w)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.38, -sz * 0.38), Vector2(sz * 0.76, sz * 0.44)), dim, true)
			c.draw_line(centre + Vector2(0, sz * 0.14), centre + Vector2(0, sz * 0.3), ink, w * 1.6, true)
			var base := Rect2(centre + Vector2(-sz * 0.26, sz * 0.3), Vector2(sz * 0.52, sz * 0.12))
			c.draw_rect(base, fill, true); c.draw_rect(base, ink, false, w)
		"iot":     # a chip with legs and an antenna
			var chip := Rect2(centre + Vector2(-sz * 0.3, -sz * 0.22), Vector2(sz * 0.6, sz * 0.52))
			for k in 3:
				var x := centre.x - sz * 0.18 + float(k) * sz * 0.18
				c.draw_line(Vector2(x, centre.y + sz * 0.3), Vector2(x, centre.y + sz * 0.46), ink, w * 1.3, true)
				c.draw_line(Vector2(x, centre.y - sz * 0.22), Vector2(x, centre.y - sz * 0.34), ink, w * 1.3, true)
			c.draw_rect(chip, fill, true); c.draw_rect(chip, ink, false, w)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.14, -sz * 0.08), Vector2(sz * 0.28, sz * 0.26)), dim, true)
			c.draw_arc(centre + Vector2(sz * 0.28, -sz * 0.3), sz * 0.2, -2.9, -1.2, 10, ink, w, true)
		"server":  # a rack: three units with a light each
			for r in 3:
				var slab := Rect2(centre.x - sz * 0.44, centre.y - sz * 0.46 + float(r) * sz * 0.31, sz * 0.88, sz * 0.26)
				c.draw_rect(slab, fill, true); c.draw_rect(slab, ink, false, w)
				c.draw_circle(Vector2(slab.position.x + sz * 0.76, slab.position.y + sz * 0.13), sz * 0.045, ink)
				c.draw_line(slab.position + Vector2(sz * 0.08, sz * 0.13), slab.position + Vector2(sz * 0.5, sz * 0.13), dim, w * 1.4, true)
		"web":     # a globe
			c.draw_circle(centre, sz * 0.46, fill)
			c.draw_arc(centre, sz * 0.46, 0.0, TAU, 40, ink, w, true)
			c.draw_line(centre + Vector2(-sz * 0.46, 0), centre + Vector2(sz * 0.46, 0), ink, w, true)
			c.draw_line(centre + Vector2(0, -sz * 0.46), centre + Vector2(0, sz * 0.46), ink, w, true)
			c.draw_polyline(_ellipse(centre, sz * 0.2, sz * 0.46, 32), ink, w, true)
			c.draw_line(centre + Vector2(-sz * 0.4, -sz * 0.22), centre + Vector2(sz * 0.4, -sz * 0.22), dim, w, true)
			c.draw_line(centre + Vector2(-sz * 0.4, sz * 0.22), centre + Vector2(sz * 0.4, sz * 0.22), dim, w, true)
		"db":      # a cylinder
			var body := Rect2(centre + Vector2(-sz * 0.38, -sz * 0.3), Vector2(sz * 0.76, sz * 0.62))
			c.draw_rect(body, fill, true)
			c.draw_colored_polygon(_ellipse(centre + Vector2(0, sz * 0.32), sz * 0.38, sz * 0.14), fill)
			c.draw_polyline(_ellipse(centre + Vector2(0, sz * 0.32), sz * 0.38, sz * 0.14, 32), ink, w, true)
			c.draw_line(centre + Vector2(-sz * 0.38, -sz * 0.3), centre + Vector2(-sz * 0.38, sz * 0.32), ink, w, true)
			c.draw_line(centre + Vector2(sz * 0.38, -sz * 0.3), centre + Vector2(sz * 0.38, sz * 0.32), ink, w, true)
			c.draw_polyline(_ellipse(centre + Vector2(0, 0), sz * 0.38, sz * 0.14, 32), dim, w, true)
			c.draw_colored_polygon(_ellipse(centre + Vector2(0, -sz * 0.3), sz * 0.38, sz * 0.14), fill.lightened(0.15))
			c.draw_polyline(_ellipse(centre + Vector2(0, -sz * 0.3), sz * 0.38, sz * 0.14, 32), ink, w, true)
		"file":    # a filing cabinet with two drawers
			var cab := Rect2(centre + Vector2(-sz * 0.36, -sz * 0.46), Vector2(sz * 0.72, sz * 0.92))
			c.draw_rect(cab, fill, true); c.draw_rect(cab, ink, false, w)
			c.draw_line(centre + Vector2(-sz * 0.36, 0), centre + Vector2(sz * 0.36, 0), ink, w, true)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.12, -sz * 0.27), Vector2(sz * 0.24, sz * 0.07)), ink, true)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.12, sz * 0.2), Vector2(sz * 0.24, sz * 0.07)), ink, true)
		"erp":     # a factory with a gear
			var pts := PackedVector2Array([centre + Vector2(-sz * 0.46, sz * 0.46), centre + Vector2(-sz * 0.46, -sz * 0.4), centre + Vector2(-sz * 0.16, -sz * 0.16), centre + Vector2(-sz * 0.16, -sz * 0.4), centre + Vector2(sz * 0.14, -sz * 0.16), centre + Vector2(sz * 0.14, -sz * 0.4), centre + Vector2(sz * 0.46, -sz * 0.16), centre + Vector2(sz * 0.46, sz * 0.46)])
			c.draw_colored_polygon(pts, fill)
			var outline := PackedVector2Array(pts); outline.append(pts[0])
			c.draw_polyline(outline, ink, w, true)
			var g := centre + Vector2(sz * 0.2, sz * 0.2)
			c.draw_circle(g, sz * 0.16, dim)
			c.draw_arc(g, sz * 0.16, 0.0, TAU, 16, ink, w, true)
			for k in 6:
				var ang := float(k) * TAU / 6.0
				c.draw_line(g + Vector2(cos(ang), sin(ang)) * sz * 0.16, g + Vector2(cos(ang), sin(ang)) * sz * 0.24, ink, w * 1.3, true)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.36, sz * 0.12), Vector2(sz * 0.1, sz * 0.14)), dim, true)
			c.draw_rect(Rect2(centre + Vector2(-sz * 0.18, sz * 0.12), Vector2(sz * 0.1, sz * 0.14)), dim, true)
		_:
			c.draw_rect(Rect2(centre - Vector2(sz * 0.4, sz * 0.4), Vector2(sz * 0.8, sz * 0.8)), fill, true)
			c.draw_rect(Rect2(centre - Vector2(sz * 0.4, sz * 0.4), Vector2(sz * 0.8, sz * 0.8)), ink, false, w)


# the seven cards as skill icons: a bold glyph in the family's neon on a dark tile — procedural, no files
func _draw_card_glyph(c: CanvasItem, card: String, centre: Vector2, sz: float, col: Color, f: Font) -> void:
	var texture: Texture2D = CfgCards.FAMILY_ART.get(str(CARDS[card].fam))
	if texture != null:
		var extent := Vector2.ONE * sz
		var source := Rect2(texture.get_size() * 0.1, texture.get_size() * 0.8)
		c.draw_texture_rect_region(texture, Rect2(centre - extent * 0.5, extent), source, Color(1, 1, 1, col.a))
		return
	# Keep the procedural emblem as a fallback for future families without an image.
	var ink := Color(0.06, 0.07, 0.1, col.a)
	var w := maxf(1.5, sz * 0.07)
	match str(CARDS[card].fam):
		"cred":      # a padlock sprung open, a key driven into it
			var body := Rect2(centre + Vector2(-sz * 0.3, -sz * 0.02), Vector2(sz * 0.6, sz * 0.46))
			c.draw_rect(body, col, true)
			c.draw_arc(centre + Vector2(-sz * 0.08, -sz * 0.14), sz * 0.2, PI, TAU, 16, col, w, true)
			c.draw_line(centre + Vector2(-sz * 0.28, -sz * 0.14), centre + Vector2(-sz * 0.28, 0), col, w, true)
			c.draw_circle(centre + Vector2(0, sz * 0.18), sz * 0.07, ink)
			c.draw_line(centre + Vector2(sz * 0.02, sz * 0.2), centre + Vector2(sz * 0.44, sz * 0.46), ink, w * 1.2, true)
			c.draw_circle(centre + Vector2(sz * 0.44, sz * 0.46), sz * 0.07, ink)
		"phish":     # a baited hook under an envelope
			var env := Rect2(centre + Vector2(-sz * 0.42, -sz * 0.46), Vector2(sz * 0.5, sz * 0.32))
			c.draw_rect(env, col, true)
			c.draw_line(env.position, env.position + env.size * 0.5, ink, w, true)
			c.draw_line(env.position + Vector2(env.size.x, 0), env.position + Vector2(env.size.x * 0.5, env.size.y * 0.5), ink, w, true)
			c.draw_line(centre + Vector2(sz * 0.2, -sz * 0.48), centre + Vector2(sz * 0.2, sz * 0.12), col, w, true)
			c.draw_arc(centre + Vector2(sz * 0.05, sz * 0.12), sz * 0.15, 0.0, PI, 14, col, w, true)
			c.draw_line(centre + Vector2(-sz * 0.1, sz * 0.12), centre + Vector2(-sz * 0.02, sz * 0.0), col, w, true)
		"oneday", "zeroday":   # a shield with the day count — 1-day outlined, 0-day filled
			var zero: bool = str(CARDS[card].fam) == "zeroday"
			var sh := PackedVector2Array([centre + Vector2(-sz * 0.4, -sz * 0.42), centre + Vector2(sz * 0.4, -sz * 0.42), centre + Vector2(sz * 0.4, sz * 0.05), centre + Vector2(0, sz * 0.48), centre + Vector2(-sz * 0.4, sz * 0.05)])
			if zero: c.draw_colored_polygon(sh, col)
			else:
				var o := PackedVector2Array(sh); o.append(sh[0]); c.draw_polyline(o, col, w, true)
			var crack := PackedVector2Array([centre + Vector2(sz * 0.05, -sz * 0.42), centre + Vector2(-sz * 0.08, -sz * 0.12), centre + Vector2(sz * 0.08, sz * 0.02), centre + Vector2(-sz * 0.04, sz * 0.3)])
			c.draw_polyline(crack, ink if zero else col, w, true)
			c.draw_string(f, centre + Vector2(sz * 0.08, sz * 0.12), "0" if zero else "1", HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz * 0.42), ink if zero else col)
		"supply":    # crates on a belt, the middle one struck
			for k in 3:
				var bx := centre + Vector2(-sz * 0.32 + float(k) * sz * 0.32, 0)
				c.draw_rect(Rect2(bx - Vector2(sz * 0.13, sz * 0.13), Vector2(sz * 0.26, sz * 0.26)), col, k == 1)
				if k < 2: c.draw_line(bx + Vector2(sz * 0.13, 0), bx + Vector2(sz * 0.19, 0), col, w, true)
			var bolt := PackedVector2Array([centre + Vector2(sz * 0.08, -sz * 0.48), centre + Vector2(-sz * 0.06, -sz * 0.12), centre + Vector2(sz * 0.04, -sz * 0.12), centre + Vector2(-sz * 0.08, sz * 0.14)])
			c.draw_polyline(bolt, ink, w * 1.3, true)
			c.draw_line(centre + Vector2(-sz * 0.46, sz * 0.36), centre + Vector2(sz * 0.46, sz * 0.36), col, w, true)
			for k in 4: c.draw_circle(centre + Vector2(-sz * 0.36 + float(k) * sz * 0.24, sz * 0.44), sz * 0.05, col)
		"dos":       # a building swamped by arrows from every side (the flood)
			var box := Rect2(centre - Vector2(sz * 0.18, sz * 0.18), Vector2(sz * 0.36, sz * 0.36))
			c.draw_rect(box, col, false, w)
			c.draw_line(box.position + Vector2(0, box.size.y), box.position + box.size, ink, w, true)
			for a in 8:   # arrows converging on it
				var ang := float(a) * TAU / 8.0
				var dir := Vector2(cos(ang), sin(ang))
				var tip := centre + dir * sz * 0.26
				var tail := centre + dir * sz * 0.48
				c.draw_line(tail, tip, col, w, true)
				var perp := Vector2(-dir.y, dir.x)
				c.draw_line(tip, tip + (perp - dir) * sz * 0.08, col, w, true)
				c.draw_line(tip, tip + (-perp - dir) * sz * 0.08, col, w, true)
		_:
			c.draw_rect(Rect2(centre - Vector2(sz * 0.4, sz * 0.4), Vector2(sz * 0.8, sz * 0.8)), col, false, w)


class HelpGlyph extends Control:   # a big icon for the Help screen: a building kind, or a card family glyph
	var game
	var kind := ""
	var card := ""
	var col := Color(1, 1, 1)

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		custom_minimum_size = Vector2(88, 88); mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.14), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(col.r, col.g, col.b, 0.5), false, 1.5)
		if card != "": game._draw_card_glyph(self, card, size * 0.5, size.y * 0.9, col, f)
		elif kind != "": game._draw_kind_icon(self, kind, size * 0.5, size.y * 0.58, col, f)


class HudBar extends Control:   # the one-line HUD with resource icons
	var game

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true            # a hard guard: the row can never bleed under the right panel

	func _draw() -> void:
		var f := get_theme_default_font()
		var x := 0.0
		for it in game._hud_items():
			var kind := str(it[0])
			var tx := x
			if kind != "":
				game._draw_kind_icon(self, kind, Vector2(x + 9.0, 28.0), 16.0, game.BUILD_KINDS[kind].col, f)
				tx += 22.0
			draw_string(f, Vector2(tx, 36.0), str(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, it[2])
			x += float(it[3])   # a fixed column: the next item never moves when this number grows





class ResearchTile extends Control:
	var game
	var key := "phish:linked"
	var catalogue := true
	var queue_index := -1
	var stop_button: Button
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP; focus_mode = Control.FOCUS_ALL
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _ready() -> void:
		if not catalogue and queue_index >= 0:
			var shader := Shader.new()
			shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV)*COLOR;float g=dot(c.rgb,vec3(0.299,0.587,0.114));COLOR=vec4(vec3(g),c.a);}"
			var shader_material := ShaderMaterial.new(); shader_material.shader = shader; material = shader_material
			stop_button = Button.new(); stop_button.text = "■"
			stop_button.add_theme_color_override("font_color", game.C_BAD)
			stop_button.add_theme_font_size_override("font_size", 12)
			stop_button.position = Vector2(0, 78); stop_button.size = Vector2(custom_minimum_size.x, 26)
			stop_button.pressed.connect(game._dequeue_research.bind(game.PLAYER, queue_index)); add_child(stop_button)
	func _process(_dt: float) -> void: queue_redraw()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if catalogue and not event.double_click: game._queue_research(game.PLAYER, key); accept_event()
			elif not catalogue and queue_index >= 0 and event.position.y < 78: game._toggle_research_item(game.PLAYER, queue_index); accept_event()
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			if catalogue: game._queue_research(game.PLAYER, key)
			elif queue_index >= 0: game._toggle_research_item(game.PLAYER, queue_index)
			accept_event()
	func _get_drag_data(_pos: Vector2) -> Variant:
		if catalogue or queue_index >= 0: return null
		var preview := CardTile.new(); preview.game = game; preview.key = key
		preview.custom_minimum_size = Vector2(170, 104); preview.position = Vector2(24, 24); set_drag_preview(preview)
		game._leave_research_for_drag.call_deferred()
		return {"card": key}
	func _draw() -> void:
		var font := get_theme_default_font()
		var cd: Dictionary = game.CARDS[game._card_of(key)]
		var colour: Color = game.FAMILY_COL[str(cd.fam)]
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.065, 0.08, 0.115))
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), colour.darkened(0.3), false, 1)
		if not catalogue: draw_multiline_string(font, Vector2(10, 20), str(cd.name), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 12, 2, game.C_TEXT)
		if catalogue:
			draw_rect(Rect2(5, 5, size.x - 10, 48), colour.darkened(0.78))
			draw_multiline_string(font, Vector2(8, 25), str(cd.name), HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 16, 2, game.C_TEXT)
			draw_rect(Rect2(10, 59, size.x - 20, 90), Color(0.035, 0.045, 0.07))
			game._draw_card_glyph(self, game._card_of(key), Vector2(size.x * 0.5, 104), 84, colour, font)
			draw_rect(Rect2(8, 155, size.x - 16, 88), Color(0.09, 0.105, 0.14))
			draw_multiline_string(font, Vector2(12, 169), game._research_effect(key), HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 13, 5, game.C_TEXT)
			var cost: Dictionary = game._card_cost(key)
			var x := 10.0
			var y := 260.0
			var cost_index := 0
			for pair in [["cash", "cash"], ["creds", "cred"], ["research", "lab"]]:
				game._draw_kind_icon(self, pair[1], Vector2(x + 6, y), 14, game.BUILD_KINDS[pair[1]].col, font)
				draw_string(font, Vector2(x + 17, y + 5), str(int(cost[pair[0]])), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, game.C_TEXT)
				cost_index += 1
				x = 10 + (cost_index % 2) * ((size.x - 20) / 2)
				y = 260 + (cost_index / 2) * 24
			draw_arc(Vector2(x + 6, y), 6, 0, TAU, 20, game.C_DIM, 1)
			draw_line(Vector2(x + 6, y - 4), Vector2(x + 6, y), game.C_DIM)
			draw_line(Vector2(x + 6, y), Vector2(x + 10, y), game.C_DIM)
			draw_string(font, Vector2(x + 17, y + 5), "%.0fs" % game._card_time(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, game.C_TEXT)

		else:
			game._draw_card_glyph(self, game._card_of(key), Vector2(25, 55), 30, colour, font)
			if queue_index >= 0:
				var items: Array = game._research_items(game.PLAYER)
				if queue_index >= items.size(): return
				var item: Dictionary = items[queue_index]
				var progress := float(item.progress) / float(game._card_time(key))
				var status := "Ⅱ" if bool(item.paused) else "%d%%" % int(progress * 100)
				if not bool(item.paused) and int(game.lab[game.PLAYER].get("active", -1)) != queue_index: status = "Queued"
				if not bool(item.paused) and int(game.lab[game.PLAYER].get("active", -1)) == queue_index and str(item.get("waiting_for", "")) != "": status = "Waiting"
				draw_string(font, Vector2(45, 60), status, HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 12, game.C_TEXT)
				draw_rect(Rect2(8, 73, (size.x - 16) * progress, 3), game.C_TEXT)
			else:
				draw_string(font, Vector2(67, 72), "×%d" % game._held(game.PLAYER, key), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, game.C_GOOD)
				draw_string(font, Vector2(10, 114), "Ready", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, game.C_GOOD)


class CardTile extends Control:
	var game
	var key := "phish:linked"
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _get_drag_data(_pos: Vector2) -> Variant:
		if game.menu_open or game.won or game.lost: return null
		var preview := CardTile.new(); preview.game = game; preview.key = key
		preview.custom_minimum_size = Vector2(184, 104)
		preview.position = Vector2(24, 24)
		set_drag_preview(preview)
		if game._tab == "research": game._leave_research_for_drag.call_deferred()
		return {"card": key}
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			game._inspect_card(key); accept_event()
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]:
			game._inspect_card(key); accept_event()
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_MOUSE_ENTER, NOTIFICATION_MOUSE_EXIT, NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT]: queue_redraw()
	func _draw() -> void:
		var font := get_theme_default_font()
		var cd: Dictionary = game.CARDS[game._card_of(key)]
		var col: Color = game.FAMILY_COL[str(cd.fam)]
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.065, 0.08, 0.115))
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), col.darkened(0.4), false, 2 if has_focus() else 1)
		var title := str(cd.name)
		draw_multiline_string(font, Vector2(10, 18), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 12, 2, game.C_TEXT)
		game._draw_card_glyph(self, game._card_of(key), Vector2(24, 59), 28, col, font)
		var effect := "−%d%% bots" % int(float(cd.power) * 100)
		if str(cd.effect) == "deny": effect = "Disable %.0fs" % float(cd.dur)
		elif str(cd.effect) == "steal": effect = "Siphon %.0fs" % float(cd.dur)
		elif str(cd.effect) == "breach": effect = "Damage + cut"
		draw_multiline_string(font, Vector2(43, 50), effect, HORIZONTAL_ALIGNMENT_LEFT, size.x - 47, 12, 3, game.C_TEXT)
		draw_string(font, Vector2(12, 94), "Ready", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, game.C_DIM)
		draw_string(font, Vector2(size.x - 40, 94), "×%d" % game._held(game.PLAYER, key), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, game.C_TEXT)


class CardFace extends Control:   # a Magic-style card: title, art, type line, rules text, flavour, cost — click to act
	var game
	var card := "stuff"
	var reach := "linked"
	var count := -1          # copies held (a badge when >= 0)
	var enabled := true
	var draggable := false   # a hand card: drag it onto a building on the map to play it
	var note := ""           # replaces the flavour line: the effect on this target, or why it can't be played
	var on_click: Callable = Callable()

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _get_drag_data(_p: Vector2) -> Variant:
		if not draggable or not enabled: return null
		var pv := CardFace.new(); pv.game = game; pv.card = card; pv.reach = reach
		pv.custom_minimum_size = Vector2(96, 134); pv.size = Vector2(96, 134); pv.modulate.a = 0.9
		set_drag_preview(pv)
		return {"card": game._card_key(card, reach)}

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and enabled and on_click.is_valid():
			on_click.call()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT: queue_redraw()

	func _draw() -> void:
		var f := get_theme_default_font()
		var cd: Dictionary = game.CARDS[card]
		var col: Color = game.FAMILY_COL[str(cd.fam)]
		var w := size.x; var h := size.y
		var k := w / 190.0                                   # the big card is the reference layout
		var big: bool = k >= 0.85
		var a := 1.0 if enabled else 0.4
		var hover: bool = enabled and on_click.is_valid() and get_global_rect().has_point(get_global_mouse_position())
		var ch := 12.0 * k
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w - ch, 0), Vector2(w, ch), Vector2(w, h), Vector2(0, h)])
		draw_colored_polygon(pts, Color(0.1, 0.11, 0.15, a))
		draw_rect(Rect2(0, 0, w - ch, 26.0 * k), Color(col.r, col.g, col.b, 0.2 * a), true)
		var fs_title := maxi(10, int(13.0 * k))
		draw_string(f, Vector2(8.0 * k, 18.0 * k), str(cd.name), HORIZONTAL_ALIGNMENT_LEFT, w - 16.0 * k, fs_title, Color(1, 1, 1, a))
		var art := Rect2(8.0 * k, 32.0 * k, w - 16.0 * k, 100.0 * k)   # the art window
		draw_rect(art, Color(0.051, 0.059, 0.09, a), true)
		draw_rect(art, Color(col.r, col.g, col.b, 0.5 * a), false, 1.0)
		game._draw_card_glyph(self, card, art.get_center(), art.size.y, Color(col.r, col.g, col.b, a), f)
		var tl := "%s — %s" % ["Worm" if bool(cd.chain) else "Single host", str(game.FAMILY_NAME[str(cd.fam)]).capitalize()]
		draw_string(f, Vector2(8.0 * k, 147.0 * k), tl, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0 * k, maxi(9, int(10.0 * k)), Color(col.r, col.g, col.b, 0.95 * a))
		draw_line(Vector2(8.0 * k, 151.0 * k), Vector2(w - 8.0 * k, 151.0 * k), Color(col.r, col.g, col.b, 0.4 * a), 1.0)
		var fs_rules := maxi(9, int(11.0 * k))
		draw_multiline_string(f, Vector2(8.0 * k, 165.0 * k), str(cd.rules), HORIZONTAL_ALIGNMENT_LEFT, w - 16.0 * k, fs_rules, 3, Color(0.92, 0.95, 1.0, a))
		var line2: String = note if note != "" else (str(cd.flavor) if big else "")
		if line2 != "":
			var lc := Color(1, 0.9, 0.6, a) if note != "" else Color(0.6, 0.68, 0.8, a)
			draw_multiline_string(f, Vector2(8.0 * k, (h - 28.0 * k) - float(fs_rules) * (1.2 if big else 1.0)), line2, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0 * k, maxi(9, int(10.0 * k)), 2, lc)
		draw_rect(Rect2(0, h - 22.0 * k, w, 22.0 * k), Color(col.r, col.g, col.b, 0.14 * a), true)   # the cost bar
		var key: String = game._card_key(card, reach)
		var cost: Dictionary = game._card_cost(key)
		var bx := 6.0 * k
		var fsz := maxi(9, int(10.0 * k))
		for r in [["cash", "cash"], ["creds", "cred"], ["research", "lab"]]:
			var txt := "%d" % int(cost[str(r[0])])
			game._draw_kind_icon(self, str(r[1]), Vector2(bx + 6.0 * k, h - 11.0 * k), 11.0 * k, Color(game.BUILD_KINDS[str(r[1])].col, a), f)
			draw_string(f, Vector2(bx + 14.0 * k, h - 7.0 * k), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(1, 0.95, 0.8, a))
			bx += 14.0 * k + f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + 8.0 * k
		draw_string(f, Vector2(bx, h - 7.0 * k), "%.0f s" % game._card_time(key), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(1, 0.95, 0.8, 0.8 * a))
		if bool(cd.chain):   # chain marker beside the title
			for j in 3:
				var cx := w - ch - 34.0 * k + float(j) * 10.0 * k
				draw_circle(Vector2(cx, 13.0 * k), 2.2 * k, col)
				if j < 2: draw_line(Vector2(cx + 2.2 * k, 13.0 * k), Vector2(cx + 7.8 * k, 13.0 * k), col, 1.0)
		if count >= 0:
			var txt := "×%d" % count
			var bw := (10.0 + 7.0 * float(txt.length())) * maxf(k, 0.8)
			draw_rect(Rect2(w - bw - 4.0, 30.0 * k, bw, 16.0 * maxf(k, 0.8)), Color(0.03, 0.04, 0.07, 0.92), true)
			draw_string(f, Vector2(w - bw, 30.0 * k + 12.0 * maxf(k, 0.8)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, int(11.0 * k)), Color(1, 1, 1))
		var o := PackedVector2Array(pts); o.append(pts[0])
		draw_polyline(o, Color(col.r, col.g, col.b, (1.0 if hover else 0.8) * a), 2.0 if hover else 1.5, true)


class TypeBadge extends Control:   # "what this building is": its picture, name, slots and multipliers
	var game
	var host := -1

	func _init() -> void:
		custom_minimum_size = Vector2(0, 42)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := get_theme_default_font()
		var t: String = str(game.hosts[host].get("type", "pc"))
		var tp: Dictionary = game.NODE_TYPES[t]
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 40)), Color(0.12, 0.14, 0.19), true)
		game._draw_type_glyph(self, t, Vector2(22, 20), 32.0, Color(0.75, 0.85, 1.0), Color(0.08, 0.1, 0.16))
		draw_string(f, Vector2(46, 17), str(tp.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.97, 1.0))
		draw_string(f, Vector2(46, 33), str(tp.desc), HORIZONTAL_ALIGNMENT_LEFT, size.x - 50, 12, Color(0.7, 0.8, 0.9))


func _draw_building_card(canvas: Control, kind: String, footer: String, gray := false) -> void:
	var font := canvas.get_theme_default_font()
	var colour: Color = BUILD_KINDS[kind].col if not gray else Color(0.6, 0.6, 0.6)
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.13, 0.15, 0.21) if not gray else Color(0.15, 0.15, 0.15))
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), colour, false, 2)
	canvas.draw_rect(Rect2(4, 4, canvas.size.x - 8, 34), colour.darkened(0.8))
	canvas.draw_rect(Rect2(6, 40, canvas.size.x - 12, 43), Color(0.04, 0.05, 0.07))
	_draw_kind_icon(canvas, kind, Vector2(canvas.size.x * 0.5, 62), 42, colour, font)
	canvas.draw_multiline_string(font, Vector2(7, 17), str(BUILD_KINDS[kind].name), HORIZONTAL_ALIGNMENT_CENTER, canvas.size.x - 14, 13, 2, C_TEXT)
	var effect: String = {"bot": "+1 bot/s", "intel": "+1 Intel/s\n+50 capacity", "cash": "Cash every 3s\nBased on value", "cred": "+0.5 Creds/s\n+50 capacity", "lab": "+0.5 Research/s\n+50 capacity"}[kind]
	canvas.draw_multiline_string(font, Vector2(7, 93), effect, HORIZONTAL_ALIGNMENT_CENTER, canvas.size.x - 14, 12, 2, C_TEXT)
	canvas.draw_string(font, Vector2(7, 131), footer, HORIZONTAL_ALIGNMENT_LEFT, canvas.size.x - 14, 12, C_DIM)


class SlotBox extends Control:
	var game
	var host := -1
	var slot := 0
	var stop_button: Button
	func _init() -> void:
		custom_minimum_size = Vector2(112, 140)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
	func _ready() -> void:
		stop_button = Button.new(); stop_button.text = "■"
		stop_button.add_theme_color_override("font_color", game.C_BAD)
		stop_button.add_theme_font_size_override("font_size", 12)
		stop_button.position = Vector2(0, 114); stop_button.size = Vector2(112, 26)
		game._fixed_button_style(stop_button, true)
		stop_button.size = Vector2(112, 26)
		stop_button.pressed.connect(game._cancel_job.bind(host, slot)); add_child(stop_button)
	func _process(_dt: float) -> void:
		var busy: bool = game.hosts[host].jobs.has(slot)
		stop_button.visible = busy
		stop_button.size = Vector2(size.x, 26)
		stop_button.position = Vector2(0, size.y - 26)
		self_modulate = Color(0.72, 0.72, 0.72) if busy else Color.WHITE
		var kind := str(game.hosts[host].builds[slot])
		queue_redraw()
	func _can_drop_data(_p: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("kind") and game._can_drop(host, slot, str(data.kind))
	func _drop_data(_p: Vector2, data: Variant) -> void:
		game._drop_build(host, slot, str(data.kind))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and event.position.y < 114: game._toggle_job(host, slot); accept_event()
			elif event.button_index == MOUSE_BUTTON_RIGHT and str(game.hosts[host].builds[slot]) != "": game._demolish(host, slot)
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER: game._toggle_job(host, slot); accept_event()
	func _draw() -> void:
		var font := get_theme_default_font()
		var h: Dictionary = game.hosts[host]
		var job: Dictionary = h.jobs.get(slot, {})
		var kind := str(h.builds[slot])
		if not job.is_empty() and str(job.phase) == "build": kind = str(job.kind)
		if kind == "":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.17))
			draw_rect(Rect2(Vector2.ZERO, size), game.C_DIM, false, 1)
			draw_string(font, Vector2(46, 76), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, game.C_DIM)
			return
		var footer := "" if game._slot_active(host, slot) else "Inactive"
		if not job.is_empty():
			footer = ""
			stop_button.text = "■  Paused" if bool(job.get("paused", false)) else "■  %.0fs" % float(job.left)
		game._draw_building_card(self, kind, footer, not job.is_empty())
		if not job.is_empty():
			var total: float = game.DEMOLISH_TIME if str(job.phase) == "demolish" else game.BUILD_TIME
			draw_rect(Rect2(6, 110, 100 * (1 - float(job.left) / total), 3), Color(0.8, 0.8, 0.8))



class PeekSlot extends Control:   # read-only view of ONE slot of a building you don't own (fogged if unscanned)
	var game
	var host := -1
	var slot := 0

	func _init() -> void:
		custom_minimum_size = Vector2(104, 84); mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := get_theme_default_font()
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, Color(0.1, 0.12, 0.17), true)
		draw_rect(box, Color(0.4, 0.5, 0.65, 0.55), false, 1.5)

		var centre := Vector2(size.x * 0.5, 26)
		if not game._scanned(game.PLAYER, host):
			var baseline := size.y * 0.5 + (f.get_ascent(26) - f.get_descent(26)) * 0.5
			draw_string(f, Vector2(0, baseline), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(0.5, 0.6, 0.75, 0.7))
			return
		var kind := str(game.hosts[host].builds[slot])
		if kind == "":
			draw_line(size * 0.5 - Vector2(7, 0), size * 0.5 + Vector2(7, 0), Color(0.5, 0.58, 0.7), 2)
		else:
			game._draw_kind_icon(self, kind, centre, 36.0, game.BUILD_KINDS[kind].col, f)
			draw_multiline_string(f, Vector2(4, 57), str(game.BUILD_KINDS[kind].name), HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 12, 2, game.C_TEXT)


class DragIcon extends Control:   # the picture that follows the pointer while a card is dragged
	var game
	var kind := ""

	func _draw() -> void:
		game._draw_kind_icon(self, kind, size * 0.5, 36.0, game.BUILD_KINDS[kind].col, get_theme_default_font())


class BuildCard extends Control:   # a draggable card for one building kind
	var game
	var kind := ""

	func _init() -> void:
		custom_minimum_size = Vector2(72, 94)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL

	func _get_drag_data(_p: Vector2) -> Variant:
		var icon := DragIcon.new(); icon.game = game; icon.kind = kind
		icon.custom_minimum_size = Vector2(48, 48); icon.size = Vector2(48, 48)
		set_drag_preview(icon)
		return {"kind": kind}

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			game._card_click(kind)
		elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ENTER:
			game._card_click(kind); accept_event()

	func _draw() -> void:
		game._draw_building_card(self, kind, "10 Intel · 10s")
