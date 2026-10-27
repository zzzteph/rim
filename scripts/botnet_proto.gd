extends Control
## Building-level botnet prototype. Rules and visual guidance are in design/.
## Drag to connect. Explicit Scan / Attack starts an inactive target operation.
## New contributors join an existing attack. Friendly connections guard automatically.
## Bots and cards take effect on arrival; Stop keeps links, Disconnect removes them.
## Construction shares remaining Intel after attack departures. Research uses Cash,
## Credentials and Research. A captured rig eliminates any faction. Hold at least 51 %
## for HOLD_SECS or eliminate the rivals to win. Menu pause is independent of Space.

const CfgFactions := preload("res://scripts/botnet_cfg/factions.gd")
const CfgTown := preload("res://scripts/botnet_cfg/town.gd")
const CfgTypes := preload("res://scripts/botnet_cfg/types.gd")
const CfgBuildings := preload("res://scripts/botnet_cfg/buildings.gd")
const CfgCards := preload("res://scripts/botnet_cfg/cards.gd")
const CfgTuning := preload("res://scripts/botnet_cfg/tuning.gd")
const HelpIllustration := preload("res://scripts/botnet_help.gd")

const NEUTRAL := CfgFactions.NEUTRAL
var PLAYER: int = CfgFactions.PLAYER   # the faction this screen plays (multiplayer: yours, 1–3)
var humans: Array = [CfgFactions.PLAYER]   # every faction a person plays (single player: just you)
const RIVAL := CfgFactions.RIVAL
const RIVAL2 := CfgFactions.RIVAL2
const RIVAL3 := CfgFactions.RIVAL3
const FACTIONS := CfgFactions.FACTIONS
const BOTNETS := CfgFactions.BOTNETS   # defaults; the live sets below are chosen by the new-game options
const AIS := CfgFactions.AIS
var botnets: Array = BOTNETS.duplicate()   # the factions actually in THIS game (player + chosen enemies)
var ais: Array = AIS.duplicate()
const GRID_COLS := CfgTown.GRID_COLS
const GRID_ROWS := CfgTown.GRID_ROWS
const EMPTY_CELL := CfgTown.EMPTY_CELL
const LINK_REACH := CfgTown.LINK_REACH
const LINK_INTEL := CfgTown.LINK_INTEL
const SHAPES := CfgTown.SHAPES
const GALAXIES := CfgTown.GALAXIES
const STAR_SPACING := CfgTown.STAR_SPACING
const STAR_AREA := CfgTown.STAR_AREA
const STAR_CANDIDATES := CfgTown.STAR_CANDIDATES
const SPIRAL_TWIST := CfgTown.SPIRAL_TWIST
const SPIRAL_ARM := CfgTown.SPIRAL_ARM
const ELLIPSE_X := CfgTown.ELLIPSE_X
const ELLIPSE_Y := CfgTown.ELLIPSE_Y
const RING_HOLE := CfgTown.RING_HOLE
const TOWN_WORDS := CfgTown.TOWN_WORDS
const JUNCTIONS := CfgTown.JUNCTIONS
const JUNCTION_CAP_MULT := CfgTown.JUNCTION_CAP_MULT

const NODE_TYPES := CfgTypes.NODE_TYPES
const TYPE_WEIGHTS := CfgTypes.TYPE_WEIGHTS

const BUILD_TIME := CfgBuildings.BUILD_TIME
const DEMOLISH_TIME := CfgBuildings.DEMOLISH_TIME
const BUILD_COSTS := CfgBuildings.BUILD_COSTS
const BUILD_KINDS := CfgBuildings.BUILD_KINDS
const PRODUCER_KINDS := CfgBuildings.PRODUCER_KINDS

const CARDS := CfgCards.CARDS
const RESEARCH := CfgCards.RESEARCH
const CARD_ORDER := CfgCards.CARD_ORDER
const ATTACK_ORDER := CfgCards.ATTACK_ORDER
const DEFENSE_ORDER := CfgCards.DEFENSE_ORDER
const KNOWN_START := CfgCards.KNOWN_START
const MANUFACTURE_LANES := CfgCards.MANUFACTURE_LANES
const READY_SLOTS := CfgCards.READY_SLOTS
const FAMILY_NAME := CfgCards.FAMILY_NAME
const FAMILY_COL := CfgCards.FAMILY_COL
const FAMILY_ART := CfgCards.FAMILY_ART
const BANK_NAME := CfgCards.BANK_NAME
const BANK_COL := CfgCards.BANK_COL
const CARD_ALARM := CfgCards.CARD_ALARM

# the five resources, in bank/hud/hash order
const RES := CfgTuning.RES
const RES_NAME := CfgTuning.RES_NAME
const START := CfgTuning.START
const BASE_CAP := CfgTuning.BASE_CAP
const CAP_PER_PRODUCER := CfgTuning.CAP_PER_PRODUCER
const MAIN_INCOME := CfgTuning.MAIN_INCOME
const BUFFER_CAP := CfgTuning.BUFFER_CAP
const BOT_RESERVE_CHOICES := CfgTuning.BOT_RESERVE_CHOICES
const BOT_RESERVE_DEFAULT := CfgTuning.BOT_RESERVE_DEFAULT
const SHIP_PRIORITY_TURNS := CfgTuning.SHIP_PRIORITY_TURNS
const LINK_TIME := CfgTuning.LINK_TIME
const NODE_ROUTE_DELAY := CfgTuning.NODE_ROUTE_DELAY
const LINK_CAP := CfgTuning.LINK_CAP
const MAX_QUEUE := CfgTuning.MAX_QUEUE
const EXPRESS_MULT := CfgTuning.EXPRESS_MULT
const SEC_BY_TYPE := CfgTuning.SEC_BY_TYPE
const SEC_MAIN := CfgTuning.SEC_MAIN
const SEC_MAX := CfgTuning.SEC_MAX
const RESEARCH_SLOTS := CfgTuning.RESEARCH_SLOTS
const HOLD_FRACTION := CfgTuning.HOLD_FRACTION
const HOLD_SECS := CfgTuning.HOLD_SECS
const AI_CADENCE := CfgTuning.AI_CADENCE
const LINK_INTEL_DRAIN := CfgTown.LINK_INTEL

const PANEL_W := 620.0
const LEADERBOARD_W := 280.0
const CARD_DOCK_HEIGHT := 264.0
const CARD_DOCK_GAP := 12.0
const MAP_CELL := 190.0         # world size of one town cell; each host sits in its own cell (territories are drawn per cell)
const DECK_BAR_HEIGHT := 40.0   # the always-visible deck strip: ATTACK / DEFENCE tabs, mini cards, pull handle
const DECK_GAP := 8.0           # between the strip and the pulled-up cards
const MENU_W := 384.0           # menu panel width
const GAME_VERSION := "0.4.0"
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
var _opt_shape: String = SHAPES[0]   # the New-game layout: a galaxy (spiral, elliptical, ring) or the grid
var _layout := "grid"              # the live layout of this match
var _opt_enemies := 2
var _seen := {}                    # fog memory: faction -> {host: Vector2(last-known owner, time seen)}
var _hover_host := -1              # the visible host under the mouse, found once per drawn frame
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
var ai_speed: float = 1.0          # the think-cadence multiplier (probes vary it)

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
var _eliminated: Dictionary = {}
var _panel_context := ""
var objective_label: Label
var feedback_label: Label
var _tut_target := -1
var _tut_second := -1
var _tut_connected := false
var _tut_attacked := false
var _tut_combined := false
var _tut_captured := false
var _seed_draft := ""

# ── the town ──
var hosts := []        # per host: pos grid name links owner gen type slots builds jobs buf producer_paused junction
                       #   plus timed-effect fields: ddos_until filter_until sabot_until steal_by steal_until
                       #   siphon patch_armed_until patch_recover_until cover_until express_until hit_t
var hub := -1
var rig := {}          # faction -> index of its MAIN NODE (the rig)
var _cell := {}        # Vector2i grid cell -> host index (gaps have no entry)
var _highways := {}    # "a_b" (a<b) -> true: a street that bridges a gap
var _roads := {}       # faction -> {"a_b": Vector2i(a, b)}: links it has used — drawn on its map for good

# ── per-faction economy (all spendable only at the main node) ──
var bank := {}         # faction -> {res: available amount}, res in RES
var incoming := {}     # faction -> {res: reserved destination room for in-flight shipments}
var committed := {}    # faction -> courier Bots committed to shipments in flight (consumed on arrival/loss)
var bot_reserve := {}  # faction -> Bots kept available for operations (BOT_RESERVE_CHOICES)
var ship_pri := {}     # faction -> "" (balanced) or a resource the round robin favours
var ship_cursor := {}  # faction -> persisted weighted-round-robin cursor
var known := {}        # faction -> {recipe: true}: learned blueprints
var research_job := {} # faction -> {} or {key, progress, paused}
var lanes := {}        # faction -> [MANUFACTURE_LANES x {recipe, progress, paused, repeat, paid}]
var cards := {}        # faction -> {recipe: ready copy count}
var recon := {}        # faction -> {host: {at, builds, buf}}: a dated Recon snapshot
var _hold := {}        # faction -> seconds it has continuously held the majority
var card_plays := {}   # faction -> operations launched (probes and the result screen)

# ── traffic and operations ──
var flights := []      # packets: {id, kind:"cargo"|"newbot"|"op", route, hops, node, depart_t, arrive_t, owner, ...}
var _execs := []       # executing capture/raid/worm: {id, fac, card, target, gen, ends, chain, stage}
var _res := {}         # "a>b" -> sorted entry times reserved on that link direction (capacity)
var _flight_id := 0    # monotonic packet id (deterministic ordering, interception-once)
var _fx := []          # pulses on hit buildings {host, until, col}
var _worms := []       # drawn worm jumps {a, b, until, col}
var _ai := {}          # faction -> {timer, dead, ...}

# selection / command
var sel := {}          # selected hosts of yours
var _inspect := -1     # the host whose panel is open, or -1
var _tab := ""         # the open sidebar section
var _chosen_attack := ""        # the attack recipe the target panel's Launch uses
var _chosen_siphon_res := "cash"   # the resource a Packet siphon redirects (chosen before launch)
var panel_scroll: ScrollContainer = null   # the panel's scroll, kept across refreshes
var panel_gutter: MarginContainer = null   # inside the scroll: holds panel_box 6 px clear of the scrollbar
var _press_pos := Vector2.ZERO
var _boxing := false
var _box_start := Vector2.ZERO
var _drag_from := -1
var _dragging := false
var _panel_t := 0.0
var _redraw_t := 0.0             # gate the per-frame canvas redraw (only while something animates + a light heartbeat)
const SIM_DT := 1.0 / 30.0       # the simulation advances in fixed 1/30 s steps, however fast the screen refreshes
const SIM_MAX_STEPS := 10        # after a hitch catch up at most 1/3 s; the rest is dropped so a slow frame never snowballs
const FPS_PLAY := 60             # frame cap while playing: a 2D map gains nothing from 144/165 Hz, the CPU pays for every frame
const FPS_IDLE := 30             # frame cap with the menu open or the window in the background
var _sim_acc := 0.0              # real time not simulated yet (< SIM_DT); packets are drawn this far ahead so they glide
var _focused := true             # the window has focus (else the frame cap drops to FPS_IDLE)
var _shaped := {}                # Font -> {size -> {text -> TextLine}}: see _shape()
var _route_memo = null           # {src * 65536 + target: route} while _sim_step allows it (see _route), else null
var _terr := {}                  # cached territory shapes for one sight/ownership "key" (see _territory_shapes)
# ---- multiplayer (deterministic lockstep, server/PROTOCOL.md): every screen runs the same simulation; only
# commands travel, grouped in turns of _mp_turn_steps steps and scheduled _mp_delay turns ahead ----
var _mp_on := false              # a multiplayer match runs on this screen
var _mp_names := {}              # faction -> the player's name
var _out := false                # multiplayer: your rig fell; you watch the rest of the match
var _mp_turn := 0                # the next turn to simulate
var _mp_step_in_turn := 0        # steps of _mp_turn already simulated
var _mp_turns := {}              # turn -> {faction: [commands]} received from the server
var _mp_dropped := {}            # faction -> the first turn it no longer sends (disconnected: idle botnet)
var _mp_queue := []              # your commands not sent yet
var _mp_turn_steps := 3
var _mp_delay := 2
var _mp_wait := 0.0              # how long the lockstep has been waiting for another player
var _mp_desync := -1             # turn at which the screens disagreed (-1: never)
var net: Node = null              # the lobby-server connection (scripts/botnet_net.gd), made on first use
const NetScript := preload("res://scripts/botnet_net.gd")
# The map is painted by MapLayer children, bottom to top. ground / nodes / mask repaint only when the view changes
# (pan, zoom, hover, selection, deck, …) and MAP_REFRESH-ly while the match runs; packets / over repaint every
# frame only while something moves. Godot keeps a layer's drawing between repaints, so an idle map costs ~nothing.
const MAP_PARTS := ["ground", "packets", "nodes", "over", "mask"]
const MAP_REFRESH := 0.1         # s between repaints of the slow layers (bot counts, timers, ownership) while playing
var _layers := {}                # part -> MapLayer
var _cv: CanvasItem              # the canvas being painted right now (a MapLayer, or the game itself)
var _ctx := {}                   # _map_ctx() of frame _ctx_frame
var _ctx_frame := -1
var _last_view := []             # _view_key() of the previous frame
var _was_moving := false         # packets were moving last frame (one more repaint clears the last positions)
var _was_fast := false           # the over layer was animating last frame
var _menu_t := 0.0              # animation clock for the menu's drifting-packet background
var _zoom := 1.0                 # map zoom (wheel); 1.0 = identity. Pan with the middle mouse button.
var _pan := Vector2.ZERO
var _panning := false
var _pan_last := Vector2.ZERO

var hud: Control
var panel: Panel
var panel_box: VBoxContainer
var hand_panel: Control          # the pulled-up deck: four detailed cards of the active tab
var hand_bar: GridContainer
var card_banks: HBoxContainer    # the deck tabs: ATTACK (child 0) and DEFENCE (child 1)
var deck_chips: HBoxContainer    # the strip's mini cards: all fifteen, click to research, drag to play
var deck_handle: Button          # pull the deck up / push it down
var _card_bank := "attack"
var _deck_open := false          # the deck starts pushed down: the map gets the room
var _deck_page := 0              # which four of the open bank's cards the pulled-up deck shows
var deck_pager: HBoxContainer    # ← page n / m → in the strip while the deck is up and its bank holds more than four
var _deck_drag_restore := false  # the deck was pushed down for a card drag; pull it back up when the drag ends
var _bank_alert := {}            # bank -> Time.get_ticks_msec() until which its tab blinks (a card became ready)
var _hand_sig := ""              # rebuild the hand only when its composition changes (keeps it cheap)
var menu_panel: Panel            # the Esc menu: Start / Resume / Restart (pauses while open)
var menu_box: VBoxContainer
var menu_sc: ScrollContainer
var menu_open := false
var _menu_view := "main"          # "main" · "newgame" · "help" · "feedback"
var _help_page := 0
# tutorial
var _tut := false
var _tut_stage := 0                # reused by the campaign as the in-chapter step index
var _ai_paused := false           # the tutorial freezes the AI until the last stage
# ── GUIDED CAMPAIGN (6 chapters on a fixed seed; extends the _tut_* scaffold). _camp implies _tut.
const CAMP_SEED := 69
const CAMP_SIZE := Vector2i(8, 6)
const CAMP_SAVE := "user://campaign.json"
const CAMP_SAVE_HARNESS := "user://campaign_harness.json"   # tests/probes build the script by hand: they never touch a player's real progress
const CAMP_CHAPTERS := 5
const CAMP_OPEN := CAMP_CHAPTERS - 1   # the last chapter: open play against an active rival
const CAMP_CUT_SECS := 10.0        # Ch2: how long the Gateway's retaliation cuts Support's routing
const CAMP_HOLD_STEP := 4.0        # seconds a finished step shows what it did (the game keeps running) before the next one
const CAMP_HOLD_CHAPTER := 8.0     # ... and the end of a chapter, before the board is rebuilt for the next
var _camp := false                # master flag; cleared in _reset(). _camp => _tut.
var _camp_chapter := 0            # 0..CAMP_OPEN
var _camp_paused := false         # a TRUE full-simulation pause for reading (gates _sim_step), distinct from paused/_ai_paused
var _camp_clock := 0.0            # wall clock advanced OUTSIDE the sim gate (the cues keep pulsing through the reading pause)
var _camp_replay := false         # replaying a finished chapter: don't move the resume point or completion
var _camp_done := [false, false, false, false, false]
var _camp_supplied := {}          # "chapter:key" -> true: a training supply granted once (idempotent)
var _camp_events := {}            # scripted-beat name -> true (armed/fired)
var _camp_cash_landed := 0        # Ch1: Crypto packets banked home since the delivery lesson began
var _camp_cancelled := false      # Ch2: a finite assault of the player's was cancelled
var _camp_src := -1               # Ch2: the assault source being taught
var _camp_home := -1
var _camp_support := -1
var _camp_relay := -1
var _camp_gateway := -1
var _camp_rivalhq := -1
var _camp_practice := -1          # a rival practice computer for the card lessons
var _camp_practice2 := -1
var _camp_guard := -1             # Ch2: the FROM computer of the guard lesson (never the Assault source, so the next lesson can't undo it)
var _camp_spot: Control           # the pulsing ring on the UI element a step names (CampSpot)
var _camp_hold_left := 0.0        # >0: the step is done; its result is on screen for this many more seconds
var _camp_hold_text := ""         # what the finished step did
var _camp_hold_target := -1       # the computer that result is about (ringed while it shows)
var _camp_acted_in_hold := false  # the player already acted while the result showed: the next step must not freeze them
var tut_panel: Panel
var tut_box: VBoxContainer
var top_tabs: HBoxContainer       # Menu; standings occupy the idle sidebar
var _toptab_sig := "@"            # rebuild the top tabs only when their state changes (clicks aren't eaten)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cv = self
	for part in MAP_PARTS:   # the map layers come first, so every control added below draws above the map
		var layer := MapLayer.new(); layer.game = self; layer.part = part
		add_child(layer); _layers[part] = layer
	_apply_options()
	_gen()
	_refresh_sight()
	var sz := get_viewport_rect().size
	hud = HudBar.new(); hud.game = self; hud.position = Vector2(24, 10)
	hud.size = Vector2(sz.x - PANEL_W - 60.0, 32); add_child(hud)
	panel = Panel.new(); panel.size = Vector2(PANEL_W, sz.y - 70.0)
	panel.position = Vector2(sz.x - PANEL_W - 16.0, 56.0); add_child(panel)   # a clear gap below the top dashboard
	var sc := ScrollContainer.new(); panel_scroll = sc
	sc.position = Vector2(14, 12); sc.size = panel.size - Vector2(28, 24)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	panel.add_child(sc)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 4)
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.custom_minimum_size = Vector2(_panel_width() - 44.0, 0)
	panel_gutter = MarginContainer.new()   # 6 px between the widest row and the scrollbar: nothing touches it
	panel_gutter.add_theme_constant_override("margin_right", 6); panel_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(panel_gutter); panel_gutter.add_child(panel_box)
	hand_panel = Control.new()
	hand_panel.size = Vector2(sz.x - 48, CARD_DOCK_HEIGHT)
	hand_panel.position = Vector2(24.0, sz.y - CARD_DOCK_HEIGHT - 12.0)
	hand_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hand_panel.clip_contents = true
	add_child(hand_panel)
	hand_bar = GridContainer.new(); hand_bar.columns = 4
	hand_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_bar.add_theme_constant_override("h_separation", int(CARD_DOCK_GAP))
	hand_bar.position = Vector2.ZERO
	hand_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_panel.add_child(hand_bar)
	card_banks = HBoxContainer.new(); card_banks.add_theme_constant_override("separation", 8)
	add_child(card_banks)
	for bank in ["attack", "defense"]:
		var button := Button.new(); button.name = str(BANK_NAME[bank])
		button.custom_minimum_size = Vector2(176, DECK_BAR_HEIGHT)   # fixed: a longer label never shifts the strip
		button.clip_text = true; button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_bank_pressed.bind(bank))
		card_banks.add_child(button)
	deck_chips = HBoxContainer.new(); deck_chips.add_theme_constant_override("separation", 16)
	deck_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deck_chips)
	for order in [CfgCards.ATTACK_ORDER, CfgCards.DEFENSE_ORDER]:
		var group := HBoxContainer.new(); group.add_theme_constant_override("separation", 6)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE; deck_chips.add_child(group)
		for card in order:
			var chip := DeckChip.new(); chip.game = self; chip.key = _card_key(str(card), "linked")
			group.add_child(chip)
	deck_handle = Button.new(); deck_handle.name = "DeckHandle"
	deck_handle.custom_minimum_size = Vector2(52, DECK_BAR_HEIGHT); deck_handle.focus_mode = Control.FOCUS_NONE
	_fixed_button_style(deck_handle)
	var chevron := ActionGlyph.new(); chevron.col = C_TEXT
	chevron.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); deck_handle.add_child(chevron)
	deck_handle.pressed.connect(func(): _set_deck_open(not _deck_open))
	add_child(deck_handle)
	deck_pager = HBoxContainer.new(); deck_pager.add_theme_constant_override("separation", 6)
	for step in [-1, 0, 1]:
		if step == 0:
			var page_label := Label.new(); page_label.name = "PageLabel"
			page_label.custom_minimum_size = Vector2(96, DECK_BAR_HEIGHT)
			page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			page_label.add_theme_font_size_override("font_size", 14); page_label.add_theme_color_override("font_color", C_DIM)
			deck_pager.add_child(page_label)
		else:
			var turn := Button.new(); turn.name = "PagePrev" if step < 0 else "PageNext"
			turn.text = "←" if step < 0 else "→"
			turn.custom_minimum_size = Vector2(52, DECK_BAR_HEIGHT); turn.focus_mode = Control.FOCUS_NONE
			_fixed_button_style(turn)
			turn.pressed.connect(_deck_turn.bind(step))
			deck_pager.add_child(turn)
	deck_pager.visible = false
	add_child(deck_pager)
	_refresh_hand()
	top_tabs = HBoxContainer.new()
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
	feedback_label.minimum_size_changed.connect(_layout_feedback_label.call_deferred)
	_camp_spot = CampSpot.new(); _camp_spot.game = self; add_child(_camp_spot)   # campaign cue ring: over every other control
	resized.connect(_on_ui_resized)
	_layout_ui()
	_bake_rich_icons()                                         # inline icons for the training text (not awaited; headless skips it)
	_refresh_panel()
	_fit_view()                                                # fit the opening town in view
	_open_menu(true)                                           # the game opens on the start menu
	_camp_first_run.call_deferred()                           # first run: the guided campaign is mandatory (real game only)
	set_process(true)


func fname(fac: int) -> String: return str(_mp_names.get(fac, FACTIONS[fac].name))   # multiplayer: the player's own name
func _is_human(fac: int) -> bool: return humans.has(fac)
func fcol(fac: int) -> Color: return FACTIONS[fac].col


# ============================================================ TOWN GENERATION
# A different town every run: cells may be gaps, positions jitter, streets are missing or diagonal,
# downtown is rich and well defended, the rim is poor and soft. Everything stays connected.
func _gen() -> void:
	if town_seed == 0:
		rng.randomize(); town_seed = int(rng.randi() % 900000) + 1
	rng.seed = town_seed
	var sz := get_viewport_rect().size
	hosts = []; hub = -1; rig = {}; _cell = {}; _terr = {}; _highways = {}; _roads = {}; flights = []; _execs = []; _res = {}; _flight_id = 0
	bank = {}; incoming = {}; committed = {}; bot_reserve = {}; ship_pri = {}; ship_cursor = {}; known = {}; research_job = {}; lanes = {}; cards = {}; recon = {}
	_ai = {}; _fx = []; _worms = []; _hold = {}; card_plays = {}
	for fac in botnets:
		bank[fac] = {}
		for res in RES: bank[fac][res] = float(START[res])
		incoming[fac] = {}; committed[fac] = 0.0; bot_reserve[fac] = BOT_RESERVE_DEFAULT; ship_pri[fac] = ""; ship_cursor[fac] = 0
		known[fac] = {}
		for recipe in KNOWN_START: known[fac][recipe] = true
		research_job[fac] = {}; cards[fac] = {}; recon[fac] = {}; card_plays[fac] = 0; _hold[fac] = 0.0
		var L := []
		for lane in MANUFACTURE_LANES: L.append({"recipe": "", "progress": 0.0, "paused": false, "repeat": false, "paid": {}, "pending": false})
		lanes[fac] = L
	for fac in ais: _ai[fac] = {"timer": AI_CADENCE * (0.4 + 0.3 * float(fac)), "dead": false}
	_seen = {}     # and a fresh fog memory (filled once the town exists)
	# fixed WORLD spacing between cells → the map never crowds; the view is fit around it afterwards (_fit_view)
	var cell := MAP_CELL
	var sx := cell; var sy := cell
	var ax := 0.0; var ay := 0.0
	var centre := Vector2(float(_cols - 1) * 0.5, float(_rows - 1) * 0.5)
	var hub_cell := Vector2i(int(centre.x) + (rng.randi() % 2), int(centre.y) + (rng.randi() % 2))
	# each botnet starts in a corner: you top-left, the enemies in the other corners (only the active ones)
	var corner := {
		CfgFactions.PLAYER: [Vector2i(0, 0), Vector2i(0, 1)],
		RIVAL:  [Vector2i(_cols - 1, _rows - 1), Vector2i(_cols - 1, _rows - 2)],
		RIVAL2: [Vector2i(0, _rows - 1), Vector2i(0, _rows - 2)],
		RIVAL3: [Vector2i(_cols - 1, 0), Vector2i(_cols - 2, 0)],
	}
	var starts := {}
	for fac in botnets: starts[fac] = corner[fac]
	var forced := []   # grid cells that are never gaps: downtown and the starts
	var home := {}     # fac -> [rig, second building]
	if GALAXIES.has(_layout): home = _place_galaxy(_layout, cell, centre)
	else:
		forced = [hub_cell]
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
				var p := Vector2(ax + sx * float(gx), ay + sy * float(gy)) + Vector2(rng.randf_range(-0.18, 0.18) * sx, rng.randf_range(-0.09, 0.09) * sy)
				_cell[c] = _add_host(p, c, is_hub, value, ntype)
		for fac in starts.keys(): home[fac] = [_cell[starts[fac][0]], _cell[starts[fac][1]]]
	# the HIDDEN NETWORK: every two buildings within reach are linked. Nobody sees it; a building sees, and can
	# connect to, what is within reach of its owner's buildings — so any layout works
	var reach := LINK_REACH * MAP_CELL
	for i in hosts.size():
		for j in range(i + 1, hosts.size()):
			if (hosts[i].pos as Vector2).distance_to(hosts[j].pos) <= reach: _link(i, j)
	var cands := []   # JUNCTIONS: the best-connected crossroads of the mid town — their streets carry double traffic
	for i in hosts.size():
		if bool(hosts[i].hub) or forced.has(hosts[i].grid) or int(hosts[i].value) < 2 or (hosts[i].links as Array).size() < 3 or _is_home(home, i): continue
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
	for fac in botnets:   # each botnet claims its corner rig + a second building
		_claim(int(home[fac][0]), fac, true, "YOUR RIG" if fac == PLAYER else "%s RIG" % fname(fac))
		_claim(int(home[fac][1]), fac, false, "")


func _is_home(home: Dictionary, i: int) -> bool:
	for fac in home:
		if (home[fac] as Array).has(i): return true
	return false


func _add_host(p: Vector2, c: Vector2i, is_hub: bool, value: int, ntype: String) -> int:
	var tp: Dictionary = NODE_TYPES[ntype]
	var slots := int(tp.slots)
	if is_hub: hub = hosts.size()
	# A neutral host has no installations and a type-derived security class; it is captured, not fought.
	hosts.append({"pos": p, "grid": c, "hub": is_hub, "rig": false,
		"name": "HUB" if is_hub else "%s %d" % [str(tp.short), hosts.size() + 1], "type": ntype,
		"links": [], "owner": NEUTRAL, "gen": 0, "value": value, "slots": slots,
		"builds": _slot_array([], slots), "jobs": {}, "buf": {}, "producer_paused": {}, "junction": false,
		"ddos_until": 0.0, "filter_until": 0.0, "sabot_until": 0.0, "steal_by": -1, "steal_until": 0.0,
		"siphon": {}, "patch_armed_until": 0.0, "patch_recover_until": 0.0, "cover_until": 0.0, "express_until": 0.0,
		"hit_t": -100.0, "card_result": ""})
	return hosts.size() - 1


# ---- GALAXY layouts (Stellaris-like). One sampler fills a shape with evenly spaced computers (each the best of
# STAR_CANDIDATES random spots, never closer than STAR_SPACING): SPIRAL — one arm per botnet winding out of a core,
# every rig at an arm's tip; ELLIPTICAL — a wide disc, denser towards the middle; RING — an annulus round an empty
# middle. The rigs sit at even angles, so every botnet starts alike; the ground far from every rig (the core, the
# stretch between two rigs) is the rich, well-defended part. Everything below is in MAP_CELL units round the
# galaxy's centre and draws only from rng, so every multiplayer screen builds the same galaxy.
func _place_galaxy(shape: String, cell: float, centre: Vector2) -> Dictionary:
	var c := centre * cell   # the same centre as the grid, so "how far from the middle" reads the same
	var n := maxi(12, int(round(float(_cols * _rows) * (1.0 - EMPTY_CELL))))   # about as many computers as the same-size grid
	var geo := {}; var pts := []   # [local position, kind]: "hub", "rig", "home" (the second start building), "star"
	for attempt in 4:   # a shape that cannot hold n computers grows a little and is filled again
		geo = _galaxy_geo(shape, n, botnets.size(), 1.0 + 0.15 * float(attempt))
		pts = []
		if bool(geo.hub): pts.append([Vector2.ZERO, "hub"])
		for k in botnets.size():
			pts.append([geo.anchors[k], "rig"])
			pts.append([_galaxy_second(geo, k), "home"])
		var bound := float(geo.r) + 0.5
		var tries := 0
		while pts.size() < n and tries < n * 80:
			var best := Vector2.ZERO; var room := -1.0; var got := 0
			while got < STAR_CANDIDATES and tries < n * 80:
				tries += 1
				var p := Vector2(rng.randf_range(-bound, bound), rng.randf_range(-bound, bound))
				if rng.randf() >= _galaxy_density(geo, p): continue
				got += 1
				var d := INF
				for q in pts: d = minf(d, p.distance_to(q[0]))
				if d > room: room = d; best = p
			if room >= STAR_SPACING: pts.append([best, "star"])
		if pts.size() >= n: break
	var far := 0.001   # value: how far from every start, as a share of the farthest computer's distance
	var dist := []
	for q in pts:
		var d := INF
		for a in geo.anchors: d = minf(d, (q[0] as Vector2).distance_to(a))
		dist.append(d); far = maxf(far, d)
	var home := {}; var fac := -1
	for k in pts.size():
		var p: Vector2 = c + (pts[k][0] as Vector2) * cell
		var kind := str(pts[k][1])
		var frac := float(dist[k]) / far
		var value := 3 if frac > 0.66 else (2 if frac > 0.33 else 1)
		if kind == "star" and rng.randf() < 0.2: value = clampi(value + (1 if rng.randf() < 0.5 else -1), 1, 3)
		var is_hub := kind == "hub"
		var ntype := "erp" if is_hub else _pick_type(value)
		var g := Vector2i(int(round(p.x / cell)), int(round(p.y / cell)))   # a pseudo cell: what the grid-minded code reads
		var idx := _add_host(p, g, is_hub, 3 if is_hub else value, ntype)
		if not _cell.has(g): _cell[g] = idx
		if kind == "rig": fac = int(botnets[home.size()]); home[fac] = [idx, -1]   # rigs come in botnet order, each before its second building
		elif kind == "home": home[fac][1] = idx
	return home


func _galaxy_geo(shape: String, n: int, starts: int, grow := 1.0) -> Dictionary:   # the shape's size and its start points (anchors)
	var area := float(n) * STAR_AREA * grow
	var base := deg_to_rad(225.0)   # you start top-left, as on the grid; the others follow at even angles
	var geo := {"shape": shape, "hub": shape != "ring", "anchors": []}
	match shape:
		"elliptical":
			var s := sqrt(area / (PI * ELLIPSE_X * ELLIPSE_Y))
			geo.ax = s * ELLIPSE_X; geo.ay = s * ELLIPSE_Y; geo.r = geo.ax
			for k in starts:
				var t := base + TAU * float(k) / float(starts)
				geo.anchors.append(Vector2(cos(t) * float(geo.ax), sin(t) * float(geo.ay)) * 0.85)
		"ring":
			geo.ro = sqrt(area / (PI * (1.0 - RING_HOLE * RING_HOLE))); geo.ri = float(geo.ro) * RING_HOLE; geo.r = geo.ro
			for k in starts:
				var t := base + TAU * float(k) / float(starts)
				geo.anchors.append(Vector2(cos(t), sin(t)) * (float(geo.ro) + float(geo.ri)) * 0.5)
		_:   # spiral: one arm per botnet; grow the arms until the core and the arms hold the computers
			geo.core = 1.1 + 0.3 * sqrt(float(n) / 10.0)
			geo.arm = SPIRAL_ARM * sqrt(2.0 / float(starts)); geo.twist = SPIRAL_TWIST * PI * (1.0 + 0.1 * float(starts - 2))
			var lo := float(geo.core) + 1.0; var hi := 40.0
			for it in 24:
				var mid := (lo + hi) * 0.5
				var arm: Array = _spiral_arms(geo, mid, 1, base)[0]
				var room := PI * float(geo.core) * float(geo.core) + 2.0 * float(geo.arm) * _arm_length_beyond(arm, float(geo.core)) * float(starts)
				if room < area: lo = mid
				else: hi = mid
			geo.r = lo; geo.arms = _spiral_arms(geo, lo, starts, base)
			for arm in geo.arms:
				var tip: Vector2 = (arm as Array).back()
				geo.anchors.append(tip * (lo - 0.3) / lo)
	return geo


func _spiral_arms(geo: Dictionary, r: float, count: int, base: float) -> Array:   # one polyline per arm, core -> tip; tip k sits at base + k turns/count
	var arms := []
	var r0 := float(geo.core) * 0.6
	for k in count:
		var tip_angle := base + TAU * float(k) / float(count)
		var line := []
		for j in 25:
			var u := float(j) / 24.0
			var a := tip_angle - float(geo.twist) * (1.0 - u)
			line.append(Vector2(cos(a), sin(a)) * (r0 + (r - r0) * u))
		arms.append(line)
	return arms


func _arm_length_beyond(line: Array, core: float) -> float:   # the arm's length outside the core (inside, it overlaps the core)
	var l := 0.0
	for j in range(1, line.size()):
		if (line[j - 1] as Vector2).length() >= core: l += (line[j] as Vector2).distance_to(line[j - 1])
	return l


func _polyline_dist(line: Array, p: Vector2) -> float:
	var d := INF
	for j in range(1, line.size()):
		var a: Vector2 = line[j - 1]; var b: Vector2 = line[j]
		var ab := b - a
		var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		d = minf(d, p.distance_to(a + ab * u))
	return d


func _galaxy_density(geo: Dictionary, p: Vector2) -> float:   # 0..1: the chance a computer may stand at p
	match str(geo.shape):
		"elliptical":
			var q := pow(p.x / float(geo.ax), 2.0) + pow(p.y / float(geo.ay), 2.0)
			return 0.0 if q > 1.0 else 1.0 - 0.45 * q   # denser towards the middle
		"ring":
			var r := p.length()
			return 1.0 if r >= float(geo.ri) and r <= float(geo.ro) else 0.0
	var rad := p.length()
	if rad > float(geo.r): return 0.0
	if rad <= float(geo.core): return 1.0
	for arm in geo.arms:
		if _polyline_dist(arm, p) <= float(geo.arm): return 1.0
	return 0.0


func _galaxy_second(geo: Dictionary, k: int) -> Vector2:   # the second start building: one step from the rig, the same way for everyone
	var a: Vector2 = geo.anchors[k]
	match str(geo.shape):
		"spiral":   # back along its arm, towards the core
			var line: Array = geo.arms[k]
			var left := 1.0; var at := a
			for j in range(line.size() - 1, 0, -1):
				var nxt: Vector2 = line[j - 1]
				var step := at.distance_to(nxt)
				if step >= left: return at.move_toward(nxt, left)
				left -= step; at = nxt
			return at
		"ring":   # along the ring, counter-clockwise
			return a.rotated(-1.0 / maxf(a.length(), 0.5))
	return a - a.normalized()   # elliptical: one step towards the middle


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


func _claim(i: int, fac: int, is_rig: bool, nm: String) -> void:   # every botnet starts with a Server main node + an empty PC
	hosts[i].owner = fac; hosts[i].value = 1; hosts[i].gen = int(hosts[i].get("gen", 0)) + 1
	hosts[i].type = "server" if is_rig else "pc"; hosts[i].slots = int(NODE_TYPES[hosts[i].type].slots)
	hosts[i].buf = {}; hosts[i].jobs = {}; hosts[i].producer_paused = {}
	if is_rig:
		hosts[i].rig = true; rig[fac] = i; hosts[i].builds = _slot_array(["intel", "bot"], int(hosts[i].slots))
	else:
		hosts[i].builds = _slot_array([], int(hosts[i].slots))
		hosts[i].name = "PC %d" % (i + 1)
	if nm != "": hosts[i].name = nm


func _pick_type(value: int) -> String:   # weighted by district: soft IoT and PCs on the rim, data and ERP downtown
	var w: Dictionary = TYPE_WEIGHTS[clampi(value, 1, 3)]
	var r := rng.randf(); var acc := 0.0
	for k in w.keys():
		acc += float(w[k])
		if r <= acc: return str(k)
	return str(w.keys()[w.size() - 1])




# ---- security (a discrete eligibility class, not health) ----
func _security(i: int) -> int:   # type class, +1 for a Firewall, main node pinned to SEC_MAIN; capped SEC_MAX
	if int(hosts[i].owner) != NEUTRAL and bool(hosts[i].rig): return SEC_MAIN
	var s := int(SEC_BY_TYPE.get(str(hosts[i].get("type", "pc")), 1))
	if _has_firewall(i): s += 1
	return clampi(s, 1, SEC_MAX)


func _has_firewall(i: int) -> bool: return (hosts[i].builds as Array).has("wall")


# ---- Recon: a dated snapshot of a foreign host's installations + buffers; your own hosts are always "known" ----
func _scanned(fac: int, t: int) -> bool:   # you know this host's contents (own, or a fresh-enough Recon)
	if t < 0 or fac == NEUTRAL: return false
	if int(hosts[t].owner) == fac: return true
	return (recon.get(fac, {}) as Dictionary).has(t)


func _recon_fresh(fac: int, t: int) -> bool:   # a Recon snapshot within its 30 s freshness window
	var rec: Dictionary = (recon.get(fac, {}) as Dictionary).get(t, {})
	return not rec.is_empty() and _t - float(rec.get("at", -1e9)) <= float(CARDS.recon.dur)


func _mark_scanned(fac: int, t: int) -> void:   # record a Recon snapshot (also used by scripts/campaign)
	if not recon.has(fac): recon[fac] = {}
	recon[fac][t] = {"at": _t, "builds": (hosts[t].builds as Array).duplicate(), "buf": _buf_total(t)}


# ---- producers ----
func _producer_paused(i: int, slot: int) -> bool:
	var paused_slots = hosts[i].get("producer_paused")
	return paused_slots != null and bool((paused_slots as Dictionary).get(slot, false))


func _toggle_producer(i: int, slot: int) -> void: _cmd(["produce", i, slot])


func _do_produce(fac: int, i: int, slot: int) -> void:   # pause / resume a producer
	if not _owns(fac, i) or slot < 0 or slot >= (hosts[i].builds as Array).size(): return
	if _slot_busy(i, slot) or not str(hosts[i].builds[slot]) in PRODUCER_KINDS: return
	if not hosts[i].has("producer_paused"): hosts[i].producer_paused = {}
	hosts[i].producer_paused[slot] = not _producer_paused(i, slot)
	if fac == PLAYER: _refresh_panel(); queue_redraw()


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


# DDoS stops a host's production, intrinsic income and OUTGOING dispatch/forwarding. It does not stop routing INTO it.
func _ddos_down(i: int) -> bool: return float(hosts[i].get("ddos_until", 0.0)) > _t
func _routing_down(i: int) -> bool: return _ddos_down(i)   # a DDoSed host cannot send or forward
func _prod_down(i: int) -> bool: return _ddos_down(i)      # ... and its producers are off


func _sabotaged(i: int) -> bool: return float(hosts[i].get("sabot_until", 0.0)) > _t   # producers off, routing intact


func _phished(i: int) -> bool:   # a Phishing diversion is active: new producer output is tagged for the thief
	return float(hosts[i].get("steal_until", 0.0)) > _t and int(hosts[i].get("steal_by", -1)) in botnets and not _eliminated.has(int(hosts[i].get("steal_by", -1)))
func _stolen(i: int) -> bool: return _phished(i)


func _benef(i: int) -> int:   # who the new output here belongs to right now: the Phishing thief, else the owner
	return int(hosts[i].steal_by) if _phished(i) else int(hosts[i].owner)


func _is_botnet(fac: int) -> bool: return fac != NEUTRAL


func _r(i: int) -> float:   # drawn radius grows with the building's slots
	return 11.0 + 2.5 * float(hosts[i].slots)


# route packets travel: BFS over same-faction buildings from src to one bordering t, then the final hop
func _route(src: int, t: int) -> Array:
	if src < 0 or t < 0 or src == t: return []
	if _route_memo == null: return _route_bfs(src, t)
	var k := src * 65536 + t   # memo: _sim_step opens it for the phases that change no owner and cut no route
	if not _route_memo.has(k): _route_memo[k] = _route_bfs(src, t)
	return (_route_memo[k] as Array).duplicate()


func _route_bfs(src: int, t: int) -> Array:
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


# schedule a packet along rt departing at dep: every hop waits for room on its link, then crosses it;
# intermediate forwarding adds NODE_ROUTE_DELAY. Express halves per-link travel and forwarding (not capacity).
func _schedule(rt: Array, dep: float, fac: int, kind: String, express := false, extra := {}) -> Dictionary:
	_establish(fac, rt)
	var hops := []
	var lt := LINK_TIME * (EXPRESS_MULT if express else 1.0)
	var fd := NODE_ROUTE_DELAY * (EXPRESS_MULT if express else 1.0)
	var t := dep
	for k in range(rt.size() - 1):
		var key := _lkey(int(rt[k]), int(rt[k + 1]))
		var e := _link_entry(key, t)
		_reserve(key, e)
		hops.append(e)
		t = e + lt
		if k < rt.size() - 2: t += fd
	_flight_id += 1
	var f := {"id": _flight_id, "route": rt, "hops": hops, "lt": lt, "depart_t": dep, "arrive_t": t, "owner": fac, "kind": kind, "node": 0}
	for key in extra: f[key] = extra[key]
	return f


func _establish(fac: int, rt: Array) -> void:   # the network stays hidden, but a route a botnet has used stays on its map: a road it built
	if fac == NEUTRAL: return
	var known: Dictionary = _roads.get(fac, {})
	for k in range(rt.size() - 1):
		var a := int(rt[k]); var b := int(rt[k + 1])
		known[_lk(a, b)] = Vector2i(mini(a, b), maxi(a, b))
	_roads[fac] = known


func _first_wait(rt: Array) -> float:   # how long the first link would make this packet wait right now
	if rt.size() < 2: return 0.0
	return _link_entry(_lkey(int(rt[0]), int(rt[1])), _t) - _t


# uncongested travel time: hops × LINK_TIME + intermediate forwarding × NODE_ROUTE_DELAY
func _travel_time(rt: Array, express := false) -> float:
	if rt.size() < 2: return 0.0
	var m := EXPRESS_MULT if express else 1.0
	return (float(rt.size() - 1) * LINK_TIME + float(maxi(0, rt.size() - 2)) * NODE_ROUTE_DELAY) * m


# where a packet is at time `now`: queued at a building, crossing a link, or arrived
func _packet_pos(f: Dictionary, now: float) -> Vector2:
	var rt: Array = f.route
	var hops: Array = f.hops
	var lt := float(f.get("lt", LINK_TIME))
	if rt.size() < 2: return hosts[int(rt[0])].pos
	for k in hops.size():
		var h := float(hops[k])
		if now < h: return hosts[int(rt[k])].pos
		if now < h + lt: return (hosts[int(rt[k])].pos as Vector2).lerp(hosts[int(rt[k + 1])].pos, (now - h) / lt)
	return hosts[int(rt[rt.size() - 1])].pos


func _link_busy(a: int, b: int) -> bool:   # either direction at capacity right now
	for key in [_lkey(a, b), _lkey(b, a)]:
		var n := 0
		for x in _res.get(key, []):
			if float(x) > _t - LINK_TIME and float(x) <= _t: n += 1
		if n >= _link_cap(a, b): return true
	return false


func _player_nodes() -> int:
	return _faction_nodes(PLAYER)


func _faction_nodes(fac: int) -> int:
	var n := 0
	for h in hosts:
		if int(h.owner) == fac: n += 1
	return n


# ---- attack routing: main node → owned hosts → an owned neighbour of the foreign target, then the final hop ----
func _attack_route(fac: int, t: int) -> Array:
	var home := int(rig.get(fac, -1))
	if home < 0 or int(hosts[home].owner) != fac or t < 0: return []
	if int(hosts[t].owner) == fac: return []
	var best := []
	for nb in hosts[t].links:
		var n := int(nb)
		if int(hosts[n].owner) != fac: continue   # a route runs through your own network to a neighbour of t
		var r := [n] if n == home else _route(home, n)
		if r.is_empty(): continue
		var route := r + [t]
		if best.is_empty() or route.size() < best.size(): best = route
	# the target may itself be a neighbour of the main node
	if hosts[home].links.has(t) and (best.is_empty() or best.size() > 2): best = [home, t]
	return best


func _op_reachable(fac: int, t: int) -> bool:   # a card can reach t from the main node right now
	if t == int(rig.get(fac, -1)): return true
	return not _attack_route(fac, t).is_empty()


func _slot_busy(i: int, k: int) -> bool:   # a job is working on this slot; its producer is offline meanwhile
	return (hosts[i].jobs as Dictionary).has(k)


func _built(i: int) -> Array:   # [slot, kind] of every finished installation in slot order (busy slots excluded)
	var out := []
	var b: Array = hosts[i].builds
	for k in b.size():
		if str(b[k]) != "" and not _slot_busy(i, k): out.append([k, str(b[k])])
	return out


func _standing(i: int) -> int:   # finished installations, without building the list
	var n := 0
	var b: Array = hosts[i].builds; var jobs: Dictionary = hosts[i].jobs
	for k in b.size():
		if str(b[k]) != "" and not jobs.has(k): n += 1
	return n


func _free_slot(i: int) -> int:   # first empty slot not reserved by a running job, or -1
	var b: Array = hosts[i].builds
	for k in b.size():
		if str(b[k]) == "" and not _slot_busy(i, k): return k
	return -1


func _producer_active(i: int, slot: int) -> bool:   # a finished producer that is actually making output right now
	if _prod_down(i) or _sabotaged(i): return false       # DDoS or sabotage switches every producer off
	if _slot_busy(i, slot) or _producer_paused(i, slot): return false
	return str(hosts[i].builds[slot]) in PRODUCER_KINDS


func _count(i: int, kind: String) -> int:   # ACTIVE producers of a kind (0 while DDoSed, sabotaged or paused)
	var b: Array = hosts[i].builds
	if not b.has(kind): return 0
	var n := 0
	for k in b.size():
		if str(b[k]) == kind and _producer_active(i, k): n += 1
	return n


func _count_all(i: int, kind: String) -> int:   # installed, active or not
	return (hosts[i].builds as Array).count(kind)


func _tmult(i: int, out: String) -> float:   # the host type's multiplier for this output resource
	var key := str({"intel": "intel", "cash": "cash", "bots": "bot", "creds": "cred", "research": "research"}.get(out, out))
	return float(NODE_TYPES[str(hosts[i].get("type", "pc"))].get(key, 1.0))


# ---- banks (spendable only at the main node) ----
func _producers_of(fac: int, res: String) -> int:   # installed producers of a faction whose OUTPUT is res (incl. paused/busy)
	var n := 0
	for i in hosts.size():
		if int(hosts[i].owner) != fac: continue
		for kind in hosts[i].builds:
			if str(kind) != "" and str(BUILD_KINDS[str(kind)].get("out", "")) == res: n += 1
	return n


func _cap(fac: int, res: String) -> float:
	return float(BASE_CAP[res]) + CAP_PER_PRODUCER * float(_producers_of(fac, res))


func _avail(fac: int, res: String) -> float:
	return float((bank.get(fac, {}) as Dictionary).get(res, 0.0))


func _incoming(fac: int, res: String) -> float:
	return float((incoming.get(fac, {}) as Dictionary).get(res, 0.0))


func _room(fac: int, res: String) -> float:   # destination room for a new shipment: cap − available − reserved incoming
	return maxf(0.0, _cap(fac, res) - _avail(fac, res) - _incoming(fac, res))


func _add_bank(fac: int, res: String, amt: float) -> float:   # credit, clamped to cap; returns what actually fit
	if not bank.has(fac): return 0.0
	var fit := minf(amt, maxf(0.0, _cap(fac, res) - _avail(fac, res)))
	bank[fac][res] = _avail(fac, res) + fit
	return fit


func _spend(fac: int, res: String, amt: float) -> void:
	bank[fac][res] = maxf(0.0, _avail(fac, res) - amt)


func _reserve_incoming(fac: int, res: String, amt: float) -> void:
	if not incoming.has(fac): incoming[fac] = {}
	incoming[fac][res] = _incoming(fac, res) + amt


func _release_incoming(fac: int, res: String, amt: float) -> void:
	if incoming.has(fac): incoming[fac][res] = maxf(0.0, _incoming(fac, res) - amt)


func _pool(fac: int, res: String) -> float: return _avail(fac, res)   # legacy alias used by some callers


# ---- local output buffers (per producer, keyed by slot, split by beneficiary) ----
func _buf_slot(i: int, slot: int) -> float:
	var b: Dictionary = (hosts[i].buf as Dictionary).get(slot, {})
	var s := 0.0
	for benef in b: s += float(b[benef])
	return s


func _buf_total(i: int) -> float:
	var s := 0.0
	for slot in (hosts[i].buf as Dictionary): s += _buf_slot(i, int(slot))
	return s


func _buf_add(i: int, slot: int, benef: int, amt: float) -> void:
	if not (hosts[i].buf as Dictionary).has(slot): hosts[i].buf[slot] = {}
	hosts[i].buf[slot][benef] = float((hosts[i].buf[slot] as Dictionary).get(benef, 0.0)) + amt


# ---- income + production (Layer 4) ----
func _main_ok(fac: int) -> bool:   # the faction's main node is operational (held and not DDoSed)
	var home := int(rig.get(fac, -1))
	return home >= 0 and int(hosts[home].owner) == fac and not _prod_down(home)


func _tick_production(dt: float) -> void:
	# 1) the main node makes one of each resource per second, delivered locally (no courier, clamped to cap)
	for fac in botnets:
		if _eliminated.has(fac) or not _main_ok(fac): continue
		for res in RES: _add_bank(fac, res, MAIN_INCOME * dt)
	# 2) installed producers: input paid from the OWNER's available bank, output to a local buffer (remote) or bank (local)
	var cands := []; var demand := {}   # demand: owner*8 + input-slot -> input amount
	for i in hosts.size():
		var owner := int(hosts[i].owner)
		if owner == NEUTRAL or not botnets.has(owner) or _eliminated.has(owner): continue
		var benef := _benef(i)
		if not botnets.has(benef) or _eliminated.has(benef): continue
		var home_of_benef := int(rig.get(benef, -1))
		var local: bool = i == home_of_benef
		for slot in (hosts[i].builds as Array).size():
			var kind := str(hosts[i].builds[slot])
			if kind == "" or not (kind in PRODUCER_KINDS) or not _producer_active(i, slot): continue
			var spec: Dictionary = BUILD_KINDS[kind]
			var out := str(spec.out); var inp := str(spec.get("in", ""))
			var mult := _tmult(i, out)
			var out_amt := float(spec.rate) * mult * dt
			var room := 0.0
			if local: room = maxf(0.0, _cap(benef, out) - _avail(benef, out))
			else: room = BUFFER_CAP - _buf_slot(i, slot)
			out_amt = minf(out_amt, room)
			if out_amt <= 0.0: continue           # a capped/full producer burns no input
			var inp_amt := 0.0
			if inp != "":
				inp_amt = float(spec.in_rate) * mult * dt * (out_amt / maxf(0.000001, float(spec.rate) * mult * dt))
				var key := owner * 8 + RES.find(inp)
				demand[key] = float(demand.get(key, 0.0)) + inp_amt
			cands.append({"host": i, "slot": slot, "out": out, "in": inp, "owner": owner, "benef": benef, "local": local, "out_amt": out_amt, "inp_amt": inp_amt})
	for c in cands:
		var scale := 1.0
		if str(c.in) != "":
			var key := int(c.owner) * 8 + RES.find(str(c.in))
			scale = minf(1.0, _avail(int(c.owner), str(c.in)) / maxf(0.000001, float(demand[key])))
		var out_amt := float(c.out_amt) * scale
		if out_amt <= 0.0: continue
		if str(c.in) != "": _spend(int(c.owner), str(c.in), float(c.inp_amt) * scale)
		if bool(c.local): _add_bank(int(c.benef), str(c.out), out_amt)
		else: _buf_add(int(c.host), int(c.slot), int(c.benef), out_amt)


# ---- dispatch: one courier per non-Bot unit; new Bots deliver themselves (Layer 4) ----
func _tick_dispatch(_dt: float) -> void:
	# Build the list of whole units ready to leave, in a stable host/slot order, then serve by weighted round robin.
	var ready := {}   # beneficiary -> [{host, slot, res, newbot}]
	for i in hosts.size():
		if _routing_down(i): continue            # DDoS stops outgoing dispatch; sabotage leaves it open
		var buf: Dictionary = hosts[i].buf
		for slot in buf.keys():
			var benefs: Dictionary = buf[slot]
			for benef_key in benefs.keys():
				var benef := int(benef_key)
				if float(benefs[benef_key]) < 1.0 or _eliminated.has(benef): continue
				var res := str(BUILD_KINDS[str(hosts[i].builds[slot])].out)
				if not ready.has(benef): ready[benef] = []
				ready[benef].append({"host": i, "slot": int(slot), "res": res, "newbot": res == "bots"})
	for benef in ready:
		_dispatch_for(int(benef), ready[benef])


func _dispatch_for(fac: int, items: Array) -> void:
	var home := int(rig.get(fac, -1))
	if home < 0 or int(hosts[home].owner) != fac: return
	# weighted round robin: the chosen priority resource gets more turns; stable by (host, slot)
	items.sort_custom(func(a, b): return (a.host * 16 + a.slot) < (b.host * 16 + b.slot))
	var pri := str(ship_pri.get(fac, ""))
	var guard := 0
	while guard < 4000:
		guard += 1
		var picked := -1
		for n in items.size():
			var k := (int(ship_cursor.get(fac, 0)) + n) % maxi(1, items.size())
			if _can_dispatch(fac, items[k]): picked = k; break
		if picked < 0: break
		var it: Dictionary = items[picked]
		if not _do_dispatch(fac, it, it.host == home): pass
		ship_cursor[fac] = picked + 1
		# priority resource gets an extra turn by not advancing the cursor past it once more
		if pri != "" and str(it.res) == pri:
			for extra in range(SHIP_PRIORITY_TURNS - 1):
				var again := -1
				for n in items.size():
					if str(items[n].res) == pri and _can_dispatch(fac, items[n]): again = n; break
				if again < 0: break
				_do_dispatch(fac, items[again], items[again].host == home)
		# a producer with less than one whole unit left drops out of the rotation
		items = items.filter(func(x): return _buf_unit(x))
		if items.is_empty(): break


func _buf_unit(it: Dictionary) -> bool:
	return _buf_benef(int(it.host), int(it.slot)) >= 1.0


func _buf_benef(i: int, slot: int) -> float:
	var b: Dictionary = (hosts[i].buf as Dictionary).get(slot, {})
	var s := 0.0
	for benef in b: s += float(b[benef])
	return s


func _can_dispatch(fac: int, it: Dictionary) -> bool:
	if _buf_benef(int(it.host), int(it.slot)) < 1.0: return false
	if _room(fac, str(it.res)) < 1.0: return false              # no destination room
	var home := int(rig.get(fac, -1))
	if int(it.host) == home: return true                        # a producer at your own main node credits locally
	if _attack_route_none(fac, int(it.host)): return false      # no path home
	if not bool(it.newbot) and _avail(fac, "bots") - float(bot_reserve.get(fac, BOT_RESERVE_DEFAULT)) < 1.0: return false  # no spare courier
	return true


func _attack_route_none(fac: int, src: int) -> bool:   # true if src cannot reach the main node
	var home := int(rig.get(fac, -1))
	if src == home: return false
	return _route(src, home).is_empty()


func _do_dispatch(fac: int, it: Dictionary, local: bool) -> bool:
	var i := int(it.host); var slot := int(it.slot); var res := str(it.res)
	# take one whole unit tagged to this beneficiary
	(hosts[i].buf[slot] as Dictionary)[fac] = float((hosts[i].buf[slot] as Dictionary).get(fac, 0.0)) - 1.0
	if float(hosts[i].buf[slot][fac]) <= 0.0001: (hosts[i].buf[slot] as Dictionary).erase(fac)
	if local:                                   # at your own main node: credited at once, no courier
		_add_bank(fac, res, 1.0)
		return true
	var rt := _route(i, int(rig[fac]))
	_reserve_incoming(fac, res, 1.0)
	var express := float(hosts[i].get("express_until", 0.0)) > _t
	if bool(it.newbot):                         # a new Bot delivers itself: no courier consumed
		flights.append(_schedule(rt, _t, fac, "newbot", express, {"res": "bots"}))
	else:
		_spend(fac, "bots", 1.0)                # a courier leaves available stock
		committed[fac] = float(committed.get(fac, 0.0)) + 1.0
		var covered := float(hosts[i].get("cover_until", 0.0)) > _t
		flights.append(_schedule(rt, _t, fac, "cargo", express, {"res": res, "payer": fac, "covered": covered, "intercepted": false, "src": i}))
	return true


# ---- construction (producers / Firewall) ----
func _build_cost(kind: String) -> Dictionary:
	var out := {}
	for r in (BUILD_COSTS[kind] as Dictionary): out[str(r)] = float(BUILD_COSTS[kind][r])
	return out


func _can_afford_build(fac: int, kind: String) -> bool:
	for r in _build_cost(kind):
		if _avail(fac, r) < float(_build_cost(kind)[r]) - 0.0001: return false
	return true


func _build_cost_text(kind: String) -> String:
	var parts := []
	for r in _build_cost(kind): parts.append("%d %s" % [int(_build_cost(kind)[r]), RES_NAME[r]])
	return " + ".join(parts)


func _firewall_full(i: int) -> bool:   # a Firewall that would add nothing (already at the security ceiling)
	return _has_firewall(i) or _security(i) >= SEC_MAX


func _job_cost_left(job: Dictionary) -> Dictionary:
	var out := {}
	for r in (job.get("cost_left", {}) as Dictionary): out[str(r)] = float(job.cost_left[r])
	return out


func _job_cost_total(job: Dictionary) -> Dictionary:
	var out := {}
	for r in (job.get("cost_total", {}) as Dictionary): out[str(r)] = float(job.cost_total[r])
	return out


func _start_job(i: int, kind: String, slot := -1) -> bool:
	if i < 0 or int(hosts[i].owner) == NEUTRAL or not BUILD_KINDS.has(kind): return false
	if kind == "wall" and _firewall_full(i): return false
	if slot < 0: slot = _free_slot(i)
	if slot < 0 or slot >= (hosts[i].builds as Array).size() or _slot_busy(i, slot): return false
	var cur := str(hosts[i].builds[slot])
	if cur == kind: return false
	var fac := int(hosts[i].owner)
	if not _can_afford_build(fac, kind): return false
	for r in _build_cost(kind): _spend(fac, r, float(_build_cost(kind)[r]))   # paid in full when the job starts
	(hosts[i].get("producer_paused", {}) as Dictionary).erase(slot)
	var price := _build_cost(kind)
	if cur == "": hosts[i].jobs[slot] = {"kind": kind, "slot": slot, "phase": "build", "left": BUILD_TIME, "total": BUILD_TIME, "cost_left": price.duplicate(), "cost_total": price.duplicate()}
	else: hosts[i].jobs[slot] = {"kind": kind, "slot": slot, "phase": "demolish", "left": DEMOLISH_TIME, "total": DEMOLISH_TIME, "cost_left": price.duplicate(), "cost_total": price.duplicate()}
	return true


func _can_drop(i: int, slot: int, kind: String) -> bool:
	return _can_build(PLAYER, i, slot, kind)


func _can_build(fac: int, i: int, slot: int, kind: String) -> bool:
	if not _owns(fac, i) or not BUILD_KINDS.has(kind): return false
	if slot < 0 or slot >= (hosts[i].builds as Array).size() or _slot_busy(i, slot): return false
	if kind == "wall" and _firewall_full(i): return false
	return _can_afford_build(fac, kind)


func _drop_build(i: int, slot: int, kind: String) -> void: _cmd(["build", i, slot, kind])


func _do_build(fac: int, i: int, slot: int, kind: String) -> void:
	if not _owns(fac, i) or not BUILD_KINDS.has(kind): return   # a malformed command from the wire does nothing
	if kind == "wall" and _firewall_full(i):
		if fac == PLAYER: _flash("Already at maximum security")
		return
	if not _can_afford_build(fac, kind):
		if fac == PLAYER: _flash("Need %s" % _build_cost_text(kind))
		return
	if _start_job(i, kind, slot) and fac == PLAYER: _refresh_panel(); queue_redraw()


func _card_click(kind: String) -> void:
	var i := _build_site()
	if i >= 0: _cmd(["build", i, _free_slot(i), kind])


func _build_site() -> int:
	if sel.size() == 1 and _mine(int(sel.keys()[0])): return int(sel.keys()[0])
	return _inspect if _mine(_inspect) else -1


func _player_build(i: int, kind: String) -> void:
	_do_build(PLAYER, i, _free_slot(i), kind)


func _toggle_job(i: int, slot: int) -> void: _cmd(["job", i, slot])


func _do_toggle_job(fac: int, i: int, slot: int) -> void:
	if not _owns(fac, i) or not (hosts[i].jobs as Dictionary).has(slot): return
	hosts[i].jobs[slot].paused = not bool(hosts[i].jobs[slot].get("paused", false))
	if fac == PLAYER: _refresh_panel()


func _cancel_job(i: int, slot: int) -> void: _cmd(["cancel", i, slot])


func _do_cancel_job(fac: int, i: int, slot: int) -> void:
	if not _owns(fac, i) or not (hosts[i].jobs as Dictionary).has(slot): return
	var job: Dictionary = hosts[i].jobs[slot]
	if str(job.phase) == "build":   # refund the unworked fraction of a funded build, clamped to receiving room
		var frac := clampf(float(job.left) / maxf(0.001, float(job.total)), 0.0, 1.0)
		for r in _job_cost_total(job): _add_bank(fac, r, float(_job_cost_total(job)[r]) * frac)
	(hosts[i].jobs as Dictionary).erase(slot)
	if fac == PLAYER: _refresh_panel(); queue_redraw()


func _demolish(i: int, slot: int) -> void: _cmd(["demolish", i, slot])


func _do_demolish(fac: int, i: int, slot: int) -> void:
	if not _owns(fac, i) or slot < 0 or slot >= (hosts[i].builds as Array).size(): return
	if str(hosts[i].builds[slot]) == "" or _slot_busy(i, slot): return
	hosts[i].jobs[slot] = {"kind": "", "slot": slot, "phase": "demolish", "left": DEMOLISH_TIME, "total": DEMOLISH_TIME, "cost_left": {}, "cost_total": {}}
	if fac == PLAYER: _refresh_panel()


func _tick_jobs(dt: float) -> void:
	for i in hosts.size():
		var fac := int(hosts[i].owner)
		if fac == NEUTRAL: continue
		var jobs: Dictionary = hosts[i].jobs
		for slot_key in jobs.keys():
			var job: Dictionary = jobs[slot_key]
			if bool(job.get("paused", false)): continue
			job.left = maxf(0.0, float(job.left) - dt)   # paid in full at start: work proceeds without further ingredients
			if float(job.left) > 0.00001: continue
			var slot := int(job.slot)
			if str(job.phase) == "demolish":
				hosts[i].builds[slot] = ""
				(hosts[i].buf as Dictionary).erase(slot)
				if str(job.kind) != "":
					job.phase = "build"; job.left = BUILD_TIME; job.total = BUILD_TIME
					continue
			else:
				hosts[i].builds[slot] = str(job.kind)
			jobs.erase(slot_key)
			if fac == PLAYER: _flash("%s · slot %d ready" % [str(hosts[i].name), slot + 1], 0)


# ---- rig loss / elimination / victory ----
func _check_rigs() -> void:
	for fac in botnets:
		if _eliminated.has(fac) or int(hosts[int(rig[fac])].owner) == fac: continue
		_eliminate(fac)


func _eliminate(fac: int) -> void:
	_eliminated[fac] = true
	if fac == PLAYER and not _mp_on:
		lost = true; won = false; _end_cause = "Your main node was captured. Protect it to stay in the game."
	elif fac == PLAYER:
		_out = true; _flash("Your main node was captured — you are out of the match.", 3)
	if _ai.has(fac): _ai[fac].dead = true
	research_job[fac] = {}
	for L in (lanes.get(fac, []) as Array): L.recipe = ""; L.paid = {}; L.progress = 0.0
	# accounting: committed couriers, incoming reservations, banks and inventory are all cleared
	committed[fac] = 0.0; incoming[fac] = {}; cards[fac] = {}
	for res in RES: bank[fac][res] = 0.0
	for i in hosts.size():
		if int(hosts[i].owner) != fac: continue
		hosts[i].owner = NEUTRAL; hosts[i].gen = int(hosts[i].get("gen", 0)) + 1
		hosts[i].builds = _slot_array([], int(hosts[i].slots)); hosts[i].jobs = {}; hosts[i].buf = {}
		hosts[i].producer_paused = {}; hosts[i].rig = false
		_clear_effects(i)
	flights = flights.filter(func(f): return int(f.owner) != fac)
	_execs = _execs.filter(func(e): return int(e.fac) != fac)
	if fac != PLAYER: _flash("%s eliminated · its remaining hosts are neutral" % fname(fac), 0)


func _clear_effects(i: int) -> void:
	for k in ["ddos_until", "filter_until", "sabot_until", "steal_until", "patch_armed_until", "patch_recover_until", "cover_until", "express_until"]:
		hosts[i][k] = 0.0
	hosts[i].steal_by = -1; hosts[i].siphon = {}; hosts[i].card_result = ""


func _bank_crypto(fac: int) -> float: return _avail(fac, "cash")   # the result screen's "Crypto you" line


func _control_need() -> int:
	return maxi(0, _hold_need(hosts.size()) - 1)


func _hold_need(total: int) -> int:
	return int(ceil(HOLD_FRACTION * float(total) - 0.000001))


func _win_for(fac: int, cause: String) -> void:
	if won or lost: return
	_end_cause = cause
	if fac == PLAYER: won = true
	else: lost = true


func _control_leader() -> int:
	var best := -1; var bn := -1
	for fac in botnets:
		var n := _faction_nodes(fac)
		if n > bn: bn = n; best = fac
	return best


func _tick_domination(dt: float) -> void:
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
		_win_for(int(alive[0]), "You are the last network standing." if int(alive[0]) == PLAYER else "%s is the last network standing." % fname(int(alive[0])))


# ============================================================ LOOP
func _process(dt: float) -> void:
	_pace_frames()
	if net != null: net.auto_retry = menu_open and _menu_view in ["mp", "lobby"]   # keep trying the server while you look at it
	if _msg_t > 0.0: _msg_t -= dt
	if _camp: _camp_clock += dt   # a wall clock for the cues, outside the frozen simulation
	if _camp and _camp_paused and _camp_hold_left <= 0.0 and _camp_step_done(_camp_chapter, _tut_stage): _camp_set_pause(false)   # safety: a done step never sits frozen
	if _camp and _camp_hold_left > 0.0 and not menu_open:   # a finished step's result is showing: count down, then move on
		var shown := int(ceil(_camp_hold_left))
		_camp_hold_left -= dt
		if _camp_hold_left <= 0.0: _camp_hold_left = 0.0; _camp_hold_text = ""; _camp_hold_target = -1; _camp_next()   # _camp_next reads (then clears) _camp_acted_in_hold
		elif int(ceil(_camp_hold_left)) != shown: _show_tut()
	if _mp_on:
		if not won and not lost: _mp_advance(dt)
	elif not paused and not menu_open and not _camp_paused and not won and not lost:
		_sim_acc += dt
		var steps := 0
		while _sim_acc >= SIM_DT - 0.000001 and steps < SIM_MAX_STEPS and not won and not lost:
			_sim_acc -= SIM_DT; steps += 1
			_sim_step(SIM_DT)
		if steps >= SIM_MAX_STEPS or won or lost: _sim_acc = 0.0   # a long hitch is dropped, not replayed
		_sim_acc = maxf(0.0, _sim_acc)
	if (won or lost) and not _end_shown:
		_end_shown = true; _refresh_panel()
	_hover_host = _host_at(get_local_mouse_position())
	var view := _view_key()
	_redraw_t += dt
	var tick: bool = view != _last_view or (_redraw_t >= MAP_REFRESH and not paused and not won and not lost)
	_last_view = view
	if tick: _redraw_t = 0.0
	_update_chrome(tick)
	var hs := _hand_signature()
	if hs != _hand_sig: _hand_sig = hs; _refresh_hand()   # rebuild the bottom hand only when it changes
	if menu_open:
		_menu_t += dt; queue_redraw()                     # keep the menu's drifting packets moving
		if _menu_view == "lobby" and net != null: _mp_tick_countdown()
		elif _menu_view == "mp" and net != null and _mp_ui.has("list") and str(_mp_ui.get("err_shown", "")) != net.recent_error():
			_mp_fill_browser()   # a server refusal appeared or ran out
		return
	if tick:   # the slow layers and the HUD: on a view change at once, else MAP_REFRESH-ly while the match runs
		hud.queue_redraw()
		_redraw_map(["ground", "nodes", "over", "mask"])
	var moving: bool = not paused and (not flights.is_empty() or not _worms.is_empty())
	if moving or _was_moving or tick: _layers.packets.queue_redraw()
	_was_moving = moving
	var fast := _over_fast()
	if fast or _was_fast: _layers.over.queue_redraw()
	_was_fast = fast


func _view_key() -> Array:   # what the slow map layers show besides the simulation: when it changes they repaint at once
	return [_pan, _zoom, _hover_host, _aim_target(), sel.keys(), _inspect, _dragging, _drag_from, _boxing, _dragged_card(),
		get_viewport_rect().size, _deck_open, menu_open, paused, won, lost, _tut, _tut_stage]


func _over_fast() -> bool:   # the over layer animates: a wire, card or box being dragged, a card packet flying, a landing pulse
	if _dragging or _boxing or _dragged_card() != "": return true
	if _camp and not menu_open and (_camp_target() >= 0 or _camp_from() >= 0): return true   # the campaign's pulsing cues (they beat through the reading pause)
	if paused: return false
	if not _fx.is_empty(): return true
	for fl in flights:
		if str(fl.kind) == "card": return true
	return false


func _redraw_map(parts: Array = MAP_PARTS) -> void:
	for part in parts:
		if _layers.has(part): (_layers[part] as CanvasItem).queue_redraw()


func _sim_step(dt: float) -> void:   # one fixed step of the whole simulation (Layer 4 step order)
	if _camp_paused: return
	_t += dt
	_fx = _fx.filter(func(x): return float(x.until) > _t)
	_worms = _worms.filter(func(x): return float(x.until) > _t)
	_prune_res()
	_route_memo = {}
	if not won and not lost: _deliver_due()      # 1) settle due arrivals (may capture / eliminate)
	_tick_jobs(dt)                                #    construction completions
	_tick_research(dt)                            #    blueprint research
	_tick_manufacture(dt)                         # 3) manufacturing lanes (manual, then repeat inside)
	if not won and not lost: _tick_execs()        # 4) capture / raid / worm resolutions, after accepted defenses
	_tick_production(dt)                          # 5) income, local credit, buffers
	_tick_dispatch(dt)                            # 6) self-delivering Bots and courier cargo
	_tick_effects(dt)                             #    phishing diversion expiry reverts undispatched output
	_route_memo = null
	if not won and not lost and not _ai_paused: _ai_tick(dt)
	_check_rigs()
	if not won and not lost: _tick_domination(dt)
	for fac in ais:
		if not bool(_ai[fac].dead) and _faction_nodes(fac) == 0: _ai[fac].dead = true
	if _camp and (won or lost): _camp_tick()
	_panel_t += dt
	if _panel_t >= 0.25:
		_panel_t = 0.0; _refresh_sight(); _drop_fogged_focus()
		if _camp: _camp_tick()
		else: _tick_tutorial()
		_refresh_panel()


func _tick_effects(dt: float) -> void:
	# a Phishing diversion that just ended: undispatched diverted buffer reverts to the host owner
	for i in hosts.size():
		if int(hosts[i].get("steal_by", -1)) >= 0 and float(hosts[i].get("steal_until", 0.0)) <= _t and float(hosts[i].get("steal_until", 0.0)) > 0.0:
			_revert_phish(i)
			hosts[i].steal_by = -1; hosts[i].steal_until = 0.0
	# an expired siphon just clears itself
	for i in hosts.size():
		var sp: Dictionary = hosts[i].get("siphon", {})
		if not sp.is_empty() and float(sp.get("until", 0.0)) <= _t: hosts[i].siphon = {}


func _revert_phish(i: int) -> void:   # move the thief's undispatched buffer back to the host owner
	var owner := int(hosts[i].owner)
	var buf: Dictionary = hosts[i].buf
	for slot in buf.keys():
		var benefs: Dictionary = buf[slot]
		for b in benefs.keys():
			if int(b) != owner:
				benefs[owner] = float(benefs.get(owner, 0.0)) + float(benefs[b])
				benefs.erase(b)


# ---- delivery (cargo / self-delivering Bots / operation packets) ----
func _deliver_due() -> void:
	var due := []; var rest := []
	for f in flights:
		if float(f.arrive_t) <= _t: due.append(f)
		else: rest.append(f)
	flights = rest
	due.sort_custom(func(a, b): return float(a.arrive_t) < float(b.arrive_t) if absf(float(a.arrive_t) - float(b.arrive_t)) > 0.0001 else int(a.id) < int(b.id))
	for f in due:
		if won or lost: break
		_deliver(f)


func _route_intact(f: Dictionary) -> bool:   # every forwarding host still owned by the flight faction and able to forward
	var rt: Array = f.route; var fac := int(f.owner)
	for k in range(1, rt.size() - 1):
		if int(hosts[int(rt[k])].owner) != fac or _routing_down(int(rt[k])): return false
	return true


func _deliver(f: Dictionary) -> void:
	var fac := int(f.owner)
	var kind := str(f.kind)
	if kind == "op":
		_op_land(fac, str(f.get("card", "")), int(f.get("target", -1)), int(f.get("gen", -1)), f)
		return
	var res := str(f.get("res", "bots"))
	var home := int(rig.get(fac, -1))
	var arrived := not _eliminated.has(fac) and home >= 0 and int(hosts[home].owner) == fac and _route_intact(f)
	_release_incoming(fac, res, 1.0)
	if kind == "cargo":
		committed[fac] = maxf(0.0, float(committed.get(fac, 0.0)) - 1.0)   # the courier is consumed either way
		if arrived: _add_bank(fac, res, 1.0)
		elif fac == PLAYER: _flash("A %s shipment was lost — its route broke" % RES_NAME[res], 1)
	else:   # newbot: no courier; it either becomes an available Bot or is lost
		if arrived: _add_bank(fac, "bots", 1.0)


# ---- ownership change ----
func _capture(t: int, fac: int) -> void:
	var prev := int(hosts[t].owner)
	var nm := str(hosts[t].name)
	hosts[t].owner = fac; hosts[t].gen = int(hosts[t].get("gen", 0)) + 1
	hosts[t].builds = _slot_array([], int(hosts[t].slots))   # cleared: no salvage, the new owner develops empty slots
	hosts[t].jobs = {}; hosts[t].buf = {}; hosts[t].producer_paused = {}
	_clear_effects(t)
	if bool(hosts[t].get("rig", false)) and prev != NEUTRAL: hosts[t].rig = false   # a captured main node is an ordinary host
	# any operation addressed to the old ownership generation is now invalid
	_execs = _execs.filter(func(e): return not (int(e.target) == t and int(e.gen) != int(hosts[t].gen)))
	if fac == PLAYER: _flash("Captured %s%s" % [nm, "" if prev == NEUTRAL else " from %s" % fname(prev)])
	elif prev == PLAYER: _flash("Lost %s to %s" % [nm, fname(fac)])
	else: _flash("%s took %s%s" % [fname(fac), nm, "" if prev == NEUTRAL else " from %s" % fname(prev)], 0)
	_refresh_sight()
	_check_rigs()
	_refresh_panel()


# ============================================================ CARDS / OPERATIONS
func _card_of(key: String) -> String: return key.split(":")[0] if ":" in key else key
func _card_key(card: String, _reach := "") -> String: return card   # recipes are plain keys now
func _is_defense(recipe: String) -> bool: return str(CARDS[recipe].bank) == "defense"
func _recipe_cost(recipe: String) -> Dictionary:
	var out := {}
	for r in (CARDS[recipe].make as Dictionary):
		if float(CARDS[recipe].make[r]) > 0.0: out[str(r)] = float(CARDS[recipe].make[r])
	return out
func _make_time(recipe: String) -> float: return float(CARDS[recipe].make_time)
func _card_cost(key: String) -> Dictionary: return _recipe_cost(_card_of(key))   # deck-widget shims
func _card_time(key: String) -> float: return _make_time(_card_of(key))
func _slot_active(i: int, slot: int) -> bool: return _producer_active(i, slot)
func _cost_text(key: String) -> String: return _build_cost_text(_card_of(key))
func _held(fac: int, key: String) -> int: return int((cards.get(fac, {}) as Dictionary).get(_card_of(key), 0))
func _known(fac: int, recipe: String) -> bool: return bool((known.get(fac, {}) as Dictionary).get(recipe, false))


func _ready_total(fac: int) -> int:   # ready copies + active manufacturing jobs (the 12-slot budget)
	var n := 0
	for r in (cards.get(fac, {}) as Dictionary).values(): n += int(r)
	for L in (lanes.get(fac, []) as Array):
		if str(L.recipe) != "" and not (L.paid as Dictionary).is_empty(): n += 1
	return n


func _can_play(fac: int, key: String, t: int) -> String:   # "" if playable, else why not
	if won or lost: return "match finished"
	var recipe := _card_of(key)
	if not CARDS.has(recipe): return "unknown card"
	if _held(fac, recipe) <= 0: return "none ready"
	if t < 0 or t >= hosts.size(): return "no host selected"
	if not rig.has(fac) or _eliminated.has(fac) or int(hosts[int(rig[fac])].owner) != fac: return "your main node is not under your control"
	var defense := _is_defense(recipe)
	if defense:
		if int(hosts[t].owner) != fac: return "a support card needs one of your hosts"
		return ""   # support is applied locally, even to an isolated or DDoSed host
	if int(hosts[t].owner) == fac: return "an attack needs a foreign host"
	if not _recon_fresh(fac, t) and str(CARDS[recipe].effect) in ["capture", "worm"]: pass   # capture needs no Recon; security is public
	var eff := str(CARDS[recipe].effect)
	if eff in ["capture", "worm"] and _security(t) > int(CARDS[recipe].get("sec_max", 3)): return "security %d is above this card's reach" % _security(t)
	if eff == "vault" and not bool(hosts[t].get("rig", false)): return "Vault raid targets a rival's main node"
	if _routing_down(int(rig[fac])) and t != int(rig[fac]): return "your main node's routing is cut"
	if not _op_reachable(fac, t): return "no route from your main node — capture a path toward it first"
	# one capture-or-raid intrusion per attacker/target at a time
	if eff in ["capture", "worm", "vault"] and _intrusion_busy(fac, t): return "you already have an intrusion on this host"
	return ""


func _intrusion_busy(fac: int, t: int) -> bool:
	for f in flights:
		if str(f.kind) == "op" and int(f.owner) == fac and int(f.get("target", -1)) == t and str(CARDS[str(f.get("card", ""))].effect) in ["capture", "worm", "vault"]: return true
	for e in _execs:
		if int(e.fac) == fac and int(e.target) == t: return true
	return false


func _play_card(fac: int, key: String, t: int, res := "") -> bool:
	var why := _can_play(fac, key, t)
	if why != "":
		if fac == PLAYER: _flash("Cannot play: %s" % why)
		return false
	var recipe := _card_of(key)
	cards[fac][recipe] = _held(fac, recipe) - 1
	card_plays[fac] = int(card_plays.get(fac, 0)) + 1
	if _is_defense(recipe):
		_apply_support(fac, recipe, t)   # local, instant
	else:
		var rt := [int(rig[fac])] if t == int(rig[fac]) else _attack_route(fac, t)
		var extra := {"card": recipe, "target": t, "gen": int(hosts[t].gen)}
		if str(CARDS[recipe].effect) == "siphon": extra["res"] = res if RES.has(res) and res != "bots" else "cash"
		var f := _schedule(rt, _t, fac, "op", false, extra)
		flights.append(f)
		if fac == PLAYER: _flash("%s is on its way to %s — arrives in %d s" % [str(CARDS[recipe].name), str(hosts[t].name), int(ceil(float(f.arrive_t) - _t))])
	_refresh_panel(); queue_redraw()
	return true


func _op_land(fac: int, recipe: String, t: int, gen: int, f: Dictionary) -> void:
	if _eliminated.has(fac) or not CARDS.has(recipe) or t < 0: return
	if int(hosts[t].gen) != gen and gen >= 0: return   # the host changed hands in transit
	var eff := str(CARDS[recipe].effect)
	hosts[t].hit_t = _t
	_fx.append({"host": t, "until": _t + 2.0, "col": fcol(fac)})
	match eff:
		"recon": _mark_scanned(fac, t)
		"phish":
			hosts[t].steal_by = fac; hosts[t].steal_until = _t + float(CARDS[recipe].dur)
		"ddos":
			if float(hosts[t].get("filter_until", 0.0)) <= _t: hosts[t].ddos_until = _t + float(CARDS[recipe].dur)
		"sabotage":
			for h in _chain_hosts(t, int(CARDS[recipe].reach), int(hosts[t].owner)):
				hosts[int(h)].sabot_until = _t + float(CARDS[recipe].dur)
		"siphon":
			hosts[t].siphon = {"by": fac, "res": str(f.get("res", "cash")), "until": _t + float(CARDS[recipe].dur), "left": int(CARDS[recipe].cargo)}
		"capture", "worm", "vault":
			var exec_s := float(CARDS[recipe].get("exec", 8.0))
			if eff == "worm": exec_s = float(CARDS[recipe].exec)
			if eff == "capture" and bool(hosts[t].get("rig", false)): exec_s = float(CARDS[recipe].get("exec_rig", exec_s))
			_execs.append({"id": int(f.id), "fac": fac, "card": recipe, "effect": eff, "target": t, "gen": int(hosts[t].gen), "ends": _t + exec_s, "stage": 1})
	if fac == PLAYER or _mine(t): _refresh_panel()


func _chain_hosts(start: int, reach: int, owner: int) -> Array:   # start + up to reach-1 adjacent same-owner hosts, by shortest edge then id
	var hit := [start]; var seen := {start: true}; var current := start
	while hit.size() < reach:
		var best := -1; var bd := INF
		for nb in hosts[current].links:
			var n := int(nb)
			if seen.has(n) or int(hosts[n].owner) != owner: continue
			var d := (hosts[current].pos as Vector2).distance_to(hosts[n].pos)
			if d < bd or (d == bd and n < best): bd = d; best = n
		if best < 0: break
		hit.append(best); seen[best] = true; current = best
	return hit


func _tick_execs() -> void:
	var still := []
	_execs.sort_custom(func(a, b): return float(a.ends) < float(b.ends) if absf(float(a.ends) - float(b.ends)) > 0.0001 else int(a.id) < int(b.id))
	for e in _execs:
		var t := int(e.target); var fac := int(e.fac)
		if _eliminated.has(fac) or int(hosts[t].gen) != int(e.gen):
			continue   # the target changed hands or the attacker is gone: the intrusion is void
		if float(e.ends) > _t: still.append(e); continue
		# an armed Patch on the target consumes this intrusion instead of letting it resolve
		if float(hosts[t].get("patch_armed_until", 0.0)) > _t:
			hosts[t].patch_armed_until = 0.0; hosts[t].patch_recover_until = _t + float(CARDS.patch.dur)
			hosts[t].card_result = "blocked by Patch"
			if fac == PLAYER: _flash("Patch blocked your %s on %s" % [str(CARDS[str(e.card)].name), str(hosts[t].name)], 1)
			continue
		var eff := str(e.effect)
		if eff == "vault":
			_resolve_vault(fac, t)
		elif eff == "worm":
			if _security(t) <= 1 and _op_reachable(fac, t):
				_capture(t, fac)
				if int(e.stage) < int(CARDS.worm.reach):   # advance to the next eligible neighbour
					var nxt := _worm_next(fac, t)
					if nxt >= 0: _execs.append({"id": int(e.id), "fac": fac, "card": "worm", "effect": "worm", "target": nxt, "gen": int(hosts[nxt].gen), "ends": _t + float(CARDS.worm.exec), "stage": int(e.stage) + 1})
		else:   # capture family
			if _security(t) <= int(CARDS[str(e.card)].get("sec_max", 3)) and _op_reachable(fac, t):
				_capture(t, fac)
			elif fac == PLAYER:
				_flash("%s failed on %s — its security rose" % [str(CARDS[str(e.card)].name), str(hosts[t].name)], 1)
	_execs = still


func _worm_next(fac: int, from: int) -> int:
	var best := -1; var bd := INF
	for nb in hosts[from].links:
		var n := int(nb)
		if int(hosts[n].owner) == fac or _security(n) > 1 or not _visible_to(fac, n): continue
		var d := (hosts[from].pos as Vector2).distance_to(hosts[n].pos)
		if d < bd or (d == bd and n < best): bd = d; best = n
	return best


func _resolve_vault(fac: int, t: int) -> void:
	var victim := int(hosts[t].owner)
	if victim == NEUTRAL or _eliminated.has(victim): return
	var haulers := int(floor(maxf(0.0, _avail(fac, "bots") - float(bot_reserve.get(fac, BOT_RESERVE_DEFAULT)))))
	var room := int(floor(_room(fac, "cash")))
	var take := int(min(min(int(CARDS.vault.cargo), int(floor(_avail(victim, "cash")))), min(haulers, room)))
	if take <= 0:
		if fac == PLAYER: _flash("Vault raid on %s returned nothing" % str(hosts[t].name), 1)
		return
	_spend(victim, "cash", float(take))
	var rt := _route(t, int(rig[fac]))
	if rt.is_empty(): rt = [t, int(rig[fac])]
	for k in take:
		_spend(fac, "bots", 1.0); committed[fac] = float(committed.get(fac, 0.0)) + 1.0
		_reserve_incoming(fac, "cash", 1.0)
		flights.append(_schedule(rt, _t, fac, "cargo", false, {"res": "cash", "payer": fac, "covered": false, "intercepted": false, "src": t}))
	if fac == PLAYER: _flash("Vault raid on %s: %d Crypto returning" % [str(hosts[t].name), take], 0)


# ---- support cards (applied locally, instantly) ----
func _apply_support(fac: int, recipe: String, t: int) -> void:
	var eff := str(CARDS[recipe].effect)
	hosts[t].hit_t = _t
	_fx.append({"host": t, "until": _t + 2.0, "col": fcol(fac)})
	match eff:
		"patch":
			var cancelled := _patch_cancel(fac, t)
			if cancelled: hosts[t].patch_recover_until = _t + float(CARDS.patch.dur)
			else: hosts[t].patch_armed_until = _t + float(CARDS.patch.dur)
		"response":
			if int(hosts[t].get("steal_by", -1)) >= 0: _revert_phish(t)
			hosts[t].steal_by = -1; hosts[t].steal_until = 0.0
			hosts[t].sabot_until = 0.0; hosts[t].siphon = {}
		"filter": hosts[t].ddos_until = 0.0; hosts[t].filter_until = _t + float(CARDS.filter.dur)
		"cover": hosts[t].cover_until = _t + float(CARDS.cover.dur)
		"express": hosts[t].express_until = _t + float(CARDS.express.dur)
	if fac == PLAYER: _flash("%s on %s" % [str(CARDS[recipe].name), str(hosts[t].name)])


func _patch_cancel(fac: int, t: int) -> bool:   # cancel the earliest-ending capture/raid executing on t; true if one was cancelled
	var best := -1; var bi := -1
	for n in _execs.size():
		var e: Dictionary = _execs[n]
		if int(e.target) == t and str(e.effect) in ["capture", "worm", "vault"]:
			if bi < 0 or float(e.ends) < float(_execs[bi].ends): bi = n
	if bi < 0: return false
	_execs.remove_at(bi)
	return true


# ---- research (one blueprint at a time) ----
func _can_research(fac: int, recipe: String) -> String:
	if _known(fac, recipe): return "already learned"
	if not RESEARCH.has(recipe): return "always available"
	if not _known(fac, str(RESEARCH[recipe].prereq)): return "needs %s" % str(CARDS[RESEARCH[recipe].prereq].name)
	return ""


func _research_cost(recipe: String) -> Dictionary:
	var out := {}
	if RESEARCH.has(recipe):
		for r in ["intel", "cash", "research"]: out[r] = float(RESEARCH[recipe][r])
	return out


func _do_research(fac: int, recipe: String) -> void:
	recipe = _card_of(recipe)
	var job: Dictionary = research_job.get(fac, {})
	if not job.is_empty() and str(job.get("key", "")) == recipe:   # toggle pause on the active research
		job.paused = not bool(job.get("paused", false))
		if fac == PLAYER: _refresh_panel()
		return
	if _can_research(fac, recipe) != "":
		if fac == PLAYER: _flash(_can_research(fac, recipe).capitalize())
		return
	research_job[fac] = {"key": recipe, "progress": 0.0, "paused": false}   # replacing an unfunded choice is free
	if fac == PLAYER: _refresh_panel()


func _cancel_research(fac: int) -> void:
	var job: Dictionary = research_job.get(fac, {})
	if job.is_empty(): return
	var frac := clampf(float(job.progress) / maxf(0.001, _research_time(str(job.key))), 0.0, 1.0)
	for r in _research_cost(str(job.key)): _add_bank(fac, r, float(_research_cost(str(job.key))[r]) * (1.0 - frac))
	research_job[fac] = {}
	if fac == PLAYER: _refresh_panel()


func _research_time(recipe: String) -> float: return float(RESEARCH[recipe].time) if RESEARCH.has(recipe) else 0.0


func _tick_research(dt: float) -> void:
	for fac in botnets:
		var job: Dictionary = research_job.get(fac, {})
		if job.is_empty() or bool(job.get("paused", false)): continue
		var recipe := str(job.key)
		var duration := _research_time(recipe)
		var work := minf(dt, duration - float(job.progress))
		var cost := _research_cost(recipe); var frac := work / maxf(0.001, duration)
		var afford := true
		for r in cost:
			if _avail(fac, r) < float(cost[r]) * frac - 0.000001: afford = false; break
		if not afford: continue
		for r in cost: _spend(fac, r, float(cost[r]) * frac)
		job.progress = float(job.progress) + work
		if float(job.progress) >= duration - 0.00001:
			if not known.has(fac): known[fac] = {}
			known[fac][recipe] = true
			research_job[fac] = {}
			if fac == PLAYER: _flash("Blueprint learned: %s" % str(CARDS[recipe].name), 0)


# ---- manufacture (three independent lanes; manual, then Repeat) ----
func _lane_set(fac: int, lane: int, recipe: String) -> void:
	var L: Array = lanes.get(fac, [])
	if lane < 0 or lane >= L.size(): return
	if recipe != "" and not _known(fac, recipe): return
	if not (L[lane].paid as Dictionary).is_empty(): return   # an active lane must be cancelled before changing its recipe
	L[lane].recipe = recipe; L[lane].progress = 0.0; L[lane].pending = false
	if fac == PLAYER: _refresh_panel(); _refresh_hand()


func _lane_manufacture(fac: int, lane: int) -> void:
	var L: Array = lanes.get(fac, [])
	if lane < 0 or lane >= L.size() or str(L[lane].recipe) == "": return
	if not (L[lane].paid as Dictionary).is_empty(): return
	L[lane].pending = true   # charged only when it actually starts (in _tick_manufacture)
	if fac == PLAYER: _refresh_panel(); _refresh_hand()


func _lane_repeat(fac: int, lane: int) -> void:
	var L: Array = lanes.get(fac, [])
	if lane < 0 or lane >= L.size(): return
	L[lane].repeat = not bool(L[lane].repeat)
	if bool(L[lane].repeat): L[lane].pending = true
	if fac == PLAYER: _refresh_panel()


func _lane_cancel(fac: int, lane: int) -> void:
	var L: Array = lanes.get(fac, [])
	if lane < 0 or lane >= L.size(): return
	var paid: Dictionary = L[lane].paid
	if not paid.is_empty():   # refund the unworked fraction
		var frac := clampf(1.0 - float(L[lane].progress) / maxf(0.001, _make_time(str(L[lane].recipe))), 0.0, 1.0)
		for r in paid: _add_bank(fac, r, float(paid[r]) * frac)
	L[lane].paid = {}; L[lane].progress = 0.0; L[lane].pending = false
	if fac == PLAYER: _refresh_panel(); _refresh_hand()


func _can_start_recipe(fac: int, recipe: String, allow_reserve: bool) -> bool:
	if _ready_total(fac) >= READY_SLOTS: return false
	var cost := _recipe_cost(recipe)
	for r in cost:
		var have := _avail(fac, r)
		if r == "bots" and not allow_reserve: have -= float(bot_reserve.get(fac, BOT_RESERVE_DEFAULT))
		if have < float(cost[r]) - 0.0001: return false
	return true


func _start_recipe(fac: int, recipe: String) -> Dictionary:
	var cost := _recipe_cost(recipe)
	for r in cost: _spend(fac, r, float(cost[r]))
	return cost.duplicate()


func _tick_manufacture(dt: float) -> void:
	for fac in botnets:
		var L: Array = lanes.get(fac, [])
		# advance active jobs
		for lane in L.size():
			var job: Dictionary = L[lane]
			if (job.paid as Dictionary).is_empty() or bool(job.paused): continue
			job.progress = float(job.progress) + dt
			if float(job.progress) >= _make_time(str(job.recipe)) - 0.00001:
				if _ready_total(fac) - 1 < READY_SLOTS:   # it already reserves its slot as an active job
					cards[fac][str(job.recipe)] = _held(fac, str(job.recipe)) + 1
					if fac == PLAYER:
						_flash("Ready: %s" % str(CARDS[str(job.recipe)].name), 0)
						_bank_alert[_bank_of(str(job.recipe))] = Time.get_ticks_msec() + 3000
				job.paid = {}; job.progress = 0.0
				if bool(job.repeat): job.pending = true
		# start pending manual requests (may spend the Bot reserve), rotating which lane goes first
		var order := range(L.size())
		var rot := int(ship_cursor.get(fac, 0)) % maxi(1, L.size())
		for idx in L.size():
			var lane := int(order[(idx + rot) % L.size()])
			var job: Dictionary = L[lane]
			if not (job.paid as Dictionary).is_empty() or str(job.recipe) == "" or not bool(job.pending): continue
			var manual := not bool(job.repeat)
			if _can_start_recipe(fac, str(job.recipe), manual):
				job.paid = _start_recipe(fac, str(job.recipe)); job.progress = 0.0; job.pending = bool(job.repeat)


func _tick_repeat() -> void: pass   # repeat handled inside _tick_manufacture
# ============================================================ AI BOTNETS
# One economic AI. It obeys the same income, delivery, research, prices, lane/reserve/room limits and fog as a
# person: it develops producers, learns blueprints, manufactures known cards and uses them to capture, steal and
# defend. It reads only what it can observe (public security/owners/types, and dated Recon snapshots).
func _ai_tick(dt: float) -> void:
	if not ai_enabled: return
	for fac in ais:
		if bool(_ai[fac].get("dead", false)) or _eliminated.has(fac): continue
		_ai[fac].timer = float(_ai[fac].get("timer", 0.0)) - dt
		if float(_ai[fac].timer) > 0.0: continue
		_ai[fac].timer = AI_CADENCE * ai_speed
		_ai_think(fac)


func _ai_mine(fac: int) -> Array:
	var out := []
	for i in hosts.size():
		if int(hosts[i].owner) == fac: out.append(i)
	return out


func _ai_think(fac: int) -> void:
	var mine := _ai_mine(fac)
	if mine.is_empty(): return
	_ai_develop(fac, mine)
	_ai_research(fac)
	_ai_manufacture(fac)
	_ai_operate(fac, mine)


func _ai_develop(fac: int, mine: Array) -> void:   # fill empty slots with a balanced producer mix with a road home
	var have := {}
	for kind in PRODUCER_KINDS: have[kind] = 0
	for i in mine:
		for k in hosts[i].builds:
			if str(k) in PRODUCER_KINDS: have[str(k)] = int(have[str(k)]) + 1
	# income and couriers first (every other producer and every operation needs Bots and Intel), then the chains
	var want := ["intel", "bot", "cash", "cred", "lab"]
	var room := 2 + mine.size() / 2   # a bigger network supports more of each producer
	for i in mine:
		if not (hosts[i].jobs as Dictionary).is_empty(): continue
		var slot := _free_slot(i)
		if slot < 0: continue
		if i != int(rig[fac]) and _route(i, int(rig[fac])).is_empty(): continue   # a producer needs a road home
		for kind in want:
			if int(have[kind]) >= room: continue
			if _can_afford_build(fac, kind) and _start_job(i, kind, slot):
				have[kind] = int(have[kind]) + 1
				break


func _ai_research(fac: int) -> void:
	if not research_job.get(fac, {}).is_empty(): return
	# capture ladder first (reach is what wins ground), then a counter, disruption, theft, then the rest
	for recipe in ["exploit", "filter", "ddos", "zeroday", "worm", "siphon", "cover", "sabotage", "vault", "express"]:
		if _known(fac, recipe) or _can_research(fac, recipe) != "": continue
		var cost := _research_cost(recipe); var ok := true
		for r in cost:
			if _avail(fac, r) < float(cost[r]): ok = false; break
		if ok: _do_research(fac, recipe); return


func _ai_first_known(fac: int, options: Array) -> String:
	for r in options:
		if _known(fac, r): return str(r)
	return ""


func _ai_capture_need(fac: int) -> int:   # the softest security among reachable foreign hosts (0 = none reachable)
	var best := 0
	for t in hosts.size():
		if int(hosts[t].owner) == fac: continue
		if not _op_reachable(fac, t): continue
		var s := _security(t)
		if best == 0 or s < best: best = s
	return best


func _ai_cheapest_for_sec(fac: int, sec: int) -> String:   # cheapest KNOWN capture card that cracks this security
	for recipe in ["breach", "exploit", "zeroday"]:
		if _known(fac, recipe) and sec <= int(CARDS[recipe].get("sec_max", 0)): return recipe
	return ""


func _ai_manufacture(fac: int) -> void:
	# demand-driven: make only cards we can use, throttled by how many we already hold, so inventory never clogs
	var L: Array = lanes.get(fac, [])
	var plan := []
	var need := _ai_capture_need(fac)
	if need > 0:
		var cap_card := _ai_cheapest_for_sec(fac, need)   # "" if we must still research the right tier
		if cap_card != "" and _held(fac, cap_card) < 3: plan.append(cap_card)
	if _known(fac, "patch") and _held(fac, "patch") < 2: plan.append("patch")
	var press := _ai_first_known(fac, ["ddos", "phish", "siphon"])
	if press != "" and _held(fac, press) < 2: plan.append(press)
	var li := 0
	for lane in L.size():
		if not (L[lane].paid as Dictionary).is_empty(): continue   # busy this tick
		if li < plan.size():
			L[lane].recipe = str(plan[li]); L[lane].repeat = false; L[lane].pending = true; L[lane].progress = 0.0
			li += 1
		else:
			L[lane].recipe = ""; L[lane].pending = false   # nothing useful to make: idle the lane


func _ai_capture_for(fac: int, sec: int) -> String:   # the cheapest held card that cracks this security, else ""
	for recipe in ["breach", "exploit", "zeroday"]:
		if _held(fac, recipe) > 0 and sec <= int(CARDS[recipe].get("sec_max", 0)): return recipe
	return ""


func _ai_defend(fac: int, _mine: Array) -> void:   # Patch an enemy capture or raid executing on one of our hosts
	if _held(fac, "patch") <= 0: return
	for e in _execs:
		if int(e.fac) == fac: continue
		var t := int(e.target)
		if int(hosts[t].owner) != fac: continue
		if str(CARDS[str(e.card)].effect) in ["capture", "worm", "vault"] and _can_play(fac, "patch", t) == "":
			_play_card(fac, "patch", t)
			if _held(fac, "patch") <= 0: return


func _ai_operate(fac: int, mine: Array) -> void:
	var home := int(rig.get(fac, -1))
	if home < 0 or int(hosts[home].owner) != fac: return
	# expand: launch captures at the softest reachable foreign hosts, cheapest card that can crack each
	var launches := clampi(_held(fac, "breach") + _held(fac, "exploit") + _held(fac, "zeroday"), 0, 3)
	while launches > 0:
		var best := -1; var best_sec := 99; var best_d := INF; var best_card := ""
		for t in hosts.size():
			if int(hosts[t].owner) == fac: continue
			var sec := _security(t)
			var card := _ai_capture_for(fac, sec)
			if card == "" or _intrusion_busy(fac, t) or _can_play(fac, card, t) != "": continue
			var d := (hosts[home].pos as Vector2).distance_to(hosts[t].pos)
			if sec < best_sec or (sec == best_sec and d < best_d): best_sec = sec; best_d = d; best = t; best_card = card
		if best < 0: break
		if not _play_card(fac, best_card, best): break
		launches -= 1
	# no capture available: apply DDoS pressure on a producing rival neighbour
	if _held(fac, "ddos") > 0:
		for i in mine:
			for nb in hosts[i].links:
				var t := int(nb)
				if int(hosts[t].owner) != fac and int(hosts[t].owner) != NEUTRAL and not _ddos_down(t) and _can_play(fac, "ddos", t) == "":
					_play_card(fac, "ddos", t); return


# -- knowledge helpers kept for the UI/tests (dated Recon, public security) --
func _ai_remember(_fac: int) -> void: pass


func _ai_known_security(fac: int, i: int) -> int:
	return _security(i)

# ============================================================ INPUT

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.keycode == KEY_ESCAPE:
		if menu_open: _open_menu(false)
		elif _camp: _camp_leave()
		elif _panel_has_context(): _clear_all(); _refresh_panel(); queue_redraw()
		else: _open_menu(true)
		get_viewport().set_input_as_handled(); return
	if menu_open or won or lost: return
	if event.keycode == KEY_SPACE:
		if _camp_paused: _camp_set_pause(false); get_viewport().set_input_as_handled(); return   # resume reading pause
		if _mp_on or _camp: return   # a shared match never pauses; the campaign uses its reading pause
		paused = not paused; _refresh_panel(); queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_0: _reset_view()
	elif event.keycode == KEY_C: _set_deck_open(not _deck_open); get_viewport().set_input_as_handled()


func _can_drop_data(pos: Vector2, data: Variant) -> bool:   # a hand card held over the map
	if not (data is Dictionary) or not (data as Dictionary).has("card"): return false
	var t := _host_at(pos)
	return t >= 0 and _can_play(PLAYER, str(data.card), t) == ""


func _drop_data(pos: Vector2, data: Variant) -> void:
	var t := _host_at(pos)
	if t >= 0: _cmd(["card", str(data.card), t])


func _dragged_card() -> String:   # the hand card being dragged right now, or ""
	if not is_inside_tree() or get_viewport() == null or not get_viewport().gui_is_dragging(): return ""
	var d: Variant = get_viewport().gui_get_drag_data()
	if d is Dictionary and (d as Dictionary).has("card"): return str(d.card)
	return ""


func _pointer_over_panel() -> bool:
	return panel != null and panel.visible and panel.get_global_rect().has_point(get_viewport().get_mouse_position())


# Every recipe has a permanent card; the pulled-up deck shows four of the open bank at a time (paged).
func _refresh_hand() -> void:
	if hand_bar == null: return
	if hand_bar.get_child_count() != CARD_ORDER.size():
		for c in hand_bar.get_children(): hand_bar.remove_child(c); c.queue_free()
		for card in CARD_ORDER:
			var tile := CardTile.new(); tile.game = self; tile.key = _card_key(str(card), "linked")
			hand_bar.add_child(tile)
	var width := floorf((hand_panel.size.x - CARD_DOCK_GAP * 3) / 4)
	var shown := _deck_cards()
	_deck_page = clampi(_deck_page, 0, _deck_pages() - 1)
	for tile in hand_bar.get_children():
		var index := shown.find(_card_of(tile.key))   # -1: the other bank
		tile.visible = index >= _deck_page * 4 and index < _deck_page * 4 + 4
		tile.custom_minimum_size = Vector2(width, CARD_DOCK_HEIGHT); tile.queue_redraw()
	hand_bar.size = hand_panel.size
	_update_card_banks()


func _deck_cards() -> Array:   # the open bank's recipes, in deck order
	return CfgCards.DEFENSE_ORDER if _card_bank == "defense" else CfgCards.ATTACK_ORDER


func _deck_pages() -> int:
	return maxi(1, ceili(float(_deck_cards().size()) / 4.0))


func _deck_page_of(recipe: String) -> int:   # the page a recipe sits on in its own bank
	var order: Array = CfgCards.DEFENSE_ORDER if _is_defense(recipe) else CfgCards.ATTACK_ORDER
	return maxi(0, order.find(recipe)) / 4


func _deck_turn(step: int) -> void:   # page the pulled-up deck; wraps round
	_deck_page = posmod(_deck_page + step, _deck_pages())
	_refresh_hand()


func _update_card_banks(chips := true) -> void:   # tab text (owned · progress), tab look (open / closed / blinking), handle arrow; chips = repaint the mini cards
	if card_banks == null or deck_handle == null: return
	var now := Time.get_ticks_msec()
	for index in 2:
		var bank: String = ["attack", "defense"][index]
		var button: Button = card_banks.get_child(index)
		var owned := 0; var progress := ""
		for card in (CfgCards.DEFENSE_ORDER if bank == "defense" else CfgCards.ATTACK_ORDER):
			var state := _card_research_state(_card_key(card, "linked"))
			owned += int(state.count)
			if str(state.status) == "Researching": progress = " · %d%%" % int(float(state.progress) * 100)
			elif str(state.status) == "Waiting": progress = " · wait"
			elif bool(state.queued) and progress == "": progress = " · next"
		button.text = "%s  x%d%s" % [BANK_NAME[bank], owned, progress]
		var shown := _deck_open and bank == _card_bank
		var blink := not shown and now < int(_bank_alert.get(bank, 0)) and (now / 250) % 2 == 0
		var look := "flash" if blink else ("open" if shown else "closed")
		if str(button.get_meta("look", "")) != look:
			button.set_meta("look", look); _style_bank_tab(button, bank, look)
	var chevron = deck_handle.get_child(0)
	var arrow := "DeckClose" if _deck_open else "DeckOpen"
	if chevron.action != arrow: chevron.action = arrow; chevron.queue_redraw()
	if deck_pager != null:
		var pages := _deck_pages()
		deck_pager.visible = _deck_open and pages > 1 and not menu_open and not won and not lost
		(deck_pager.get_node("PageLabel") as Label).text = "Page %d / %d" % [mini(_deck_page, pages - 1) + 1, pages]
	if deck_chips.visible and chips:
		for chip in _deck_chip_nodes(): chip.queue_redraw()


func _style_bank_tab(button: Button, bank: String, look: String) -> void:   # red ATTACK / blue DEFENCE, filled while its cards show
	var col: Color = BANK_COL[bank]
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {"open": col.darkened(0.55), "flash": col.darkened(0.15), "closed": Color(0.06, 0.08, 0.12)}[look]
		if state == "hover": style.bg_color = style.bg_color.lightened(0.1)
		style.border_color = col if look != "closed" else col.darkened(0.2)
		style.set_border_width_all(2 if look != "closed" else 1); style.set_corner_radius_all(4)
		style.content_margin_left = 10; style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)
	var text: Color = Color.WHITE if look != "closed" else col.lightened(0.2)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, text)


# ---- the deck: pushed down it is one strip (tabs · eight mini cards · handle); pulled up it shows four big cards ----
func _deck_top() -> float:   # the top edge of everything the deck covers right now
	var top := get_viewport_rect().size.y - 12.0 - DECK_BAR_HEIGHT
	if _deck_open: top -= CARD_DOCK_HEIGHT + DECK_GAP
	return top


func _deck_chip_nodes() -> Array:
	var out := []
	for group in deck_chips.get_children(): out.append_array(group.get_children())
	return out


func _layout_deck() -> void:
	if hand_panel == null or card_banks == null or deck_chips == null or deck_handle == null: return
	var sz := get_viewport_rect().size
	var playing := not menu_open and not won and not lost
	var bar_top := _deck_top()
	hand_panel.position = Vector2(24, sz.y - 12.0 - CARD_DOCK_HEIGHT)
	hand_panel.size = Vector2(sz.x - 48, CARD_DOCK_HEIGHT)
	hand_panel.visible = playing and _deck_open
	card_banks.position = Vector2(24, bar_top); card_banks.size = card_banks.get_combined_minimum_size()
	card_banks.visible = playing
	deck_handle.size = deck_handle.custom_minimum_size
	deck_handle.position = Vector2(sz.x - 24 - deck_handle.size.x, bar_top)
	deck_handle.visible = playing
	# the mini cards share the room between the tabs and the handle; attack and defence groups sit apart
	var left := card_banks.position.x + card_banks.size.x + 16.0
	var room := deck_handle.position.x - 12.0 - left
	var chips := _deck_chip_nodes()
	var group_gap := float(deck_chips.get_theme_constant("separation"))
	var chip_gap := float((deck_chips.get_child(0) as Control).get_theme_constant("separation"))
	var width := floorf((room - group_gap - chip_gap * float(chips.size() - 2)) / float(chips.size()))
	for chip in chips: chip.custom_minimum_size = Vector2(clampf(width, 40.0, 150.0), DECK_BAR_HEIGHT)
	deck_chips.position = Vector2(left, bar_top); deck_chips.size = deck_chips.get_combined_minimum_size()
	deck_chips.visible = playing and not _deck_open
	if deck_pager != null:   # the pager takes the strip's free middle while the mini cards are hidden
		deck_pager.size = deck_pager.get_combined_minimum_size()
		deck_pager.position = Vector2(left + floorf((room - deck_pager.size.x) * 0.5), bar_top)
	_update_card_banks()


func _set_deck_open(open: bool) -> void:
	_deck_drag_restore = false
	if open == _deck_open: return
	_deck_open = open
	_layout_ui()
	if open: _keep_target_visible()   # a selected building must not end up under the cards


func _bank_pressed(bank: String) -> void:   # a closed tab pulls its cards up · the open tab pushes the deck down · the other tab switches
	_bank_alert.erase(bank)
	if _deck_open and bank == _card_bank: _set_deck_open(false); return
	if bank != _card_bank: _deck_page = 0   # another bank opens on its first page
	_card_bank = bank
	if _deck_open: _refresh_hand()
	else: _set_deck_open(true)


func _bank_of(key: String) -> String:
	return str(CARDS[_card_of(key)].bank)


func _card_drag_data(source: Control, key: String) -> Variant:   # a held card leaves the deck as one compact preview
	if menu_open or won or lost: return null
	if _held(PLAYER, key) <= 0:   # say why nothing happens: a silent refusal reads as a frozen game
		_flash("No %s ready — click the card to prepare one first" % str(CARDS[_card_of(key)].name)); return null
	var preview := CardDragPreview.new(); preview.game = self; preview.key = key
	preview.custom_minimum_size = Vector2(248, 58); preview.size = preview.custom_minimum_size
	preview.position = Vector2(18, -74)
	source.set_drag_preview(preview)
	_card_drag_started.call_deferred()
	return {"card": key}


func _card_drag_started() -> void:   # a card left the pulled-up deck: push it down so the whole map is a target
	if not _deck_open: return
	_deck_open = false; _deck_drag_restore = true
	_layout_ui()


func _pace_frames() -> void:   # frames cost CPU: 60 fps while you play, 30 with the menu up or the window in the background
	var want := FPS_PLAY if _focused and not menu_open else FPS_IDLE
	if Engine.max_fps != want: Engine.max_fps = want


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _focused = true
	if what == NOTIFICATION_DRAG_END and _deck_drag_restore:   # played or dropped: the deck comes back up
		_deck_drag_restore = false; _deck_open = true
		_layout_ui()

func _hand_signature() -> String:
	return "%s|%s|%s" % [str(get_viewport_rect().size.x), str(won), str(lost)]


# Deck widget bridge: a mini card click learns the blueprint (if locked) or queues a copy into a free lane;
# the research state it shows merges "ready copies", "manufacturing" and "researching the blueprint".
func _lane_of(fac: int, recipe: String) -> int:
	var L: Array = lanes.get(fac, [])
	for lane in L.size():
		if str(L[lane].recipe) == recipe: return lane
	return -1


func _free_lane(fac: int) -> int:
	var L: Array = lanes.get(fac, [])
	for lane in L.size():
		if str(L[lane].recipe) == "" or (L[lane].paid as Dictionary).is_empty() and not bool(L[lane].pending): return lane
	return -1


func _card_queue_index(key: String) -> int:
	return _lane_of(PLAYER, _card_of(key))


func _card_research_click(key: String) -> void:
	if menu_open or won or lost: return
	_cmd(["card_action", _card_of(key)])


func _do_card_action(fac: int, recipe: String) -> void:
	if not CARDS.has(recipe): return
	if not _known(fac, recipe):
		_do_research(fac, recipe); return
	var lane := _lane_of(fac, recipe)
	if lane < 0: lane = _free_lane(fac)
	if lane < 0:
		if fac == PLAYER: _flash("All manufacturing lanes are busy")
		return
	if str((lanes[fac][lane] as Dictionary).recipe) != recipe: _lane_set(fac, lane, recipe)
	_lane_manufacture(fac, lane)


func _card_research_cancel(key: String) -> void:
	var lane := _lane_of(PLAYER, _card_of(key))
	if lane >= 0 and not menu_open and not won and not lost: _cmd(["lane_cancel", lane])


func _card_research_state(key: String) -> Dictionary:   # the deck widget's view of one recipe
	var recipe := _card_of(key)
	var count := _held(PLAYER, recipe)
	var result := {"count": count, "status": "Ready" if count > 0 else "Idle", "progress": 0.0, "queued": false}
	if not _known(PLAYER, recipe):
		var job: Dictionary = research_job.get(PLAYER, {})
		if str(job.get("key", "")) == recipe:
			result.status = "Paused" if bool(job.paused) else "Researching"
			result.progress = clampf(float(job.progress) / maxf(0.001, _research_time(recipe)), 0.0, 1.0)
			result.queued = true
		else:
			result.status = "Locked"
		return result
	var lane := _lane_of(PLAYER, recipe)
	if lane >= 0:
		var L: Dictionary = lanes[PLAYER][lane]
		if not (L.paid as Dictionary).is_empty():
			result.queued = true
			result.progress = clampf(float(L.progress) / maxf(0.001, _make_time(recipe)), 0.0, 1.0)
			result.status = "Paused" if bool(L.paused) else "Making"
		elif bool(L.pending):
			result.queued = true; result.status = "Waiting"
	return result


func _clear_all() -> void:
	sel = {}; _inspect = -1; _drag_from = -1; _dragging = false; _boxing = false; _tab = ""


func _gui_input(event: InputEvent) -> void:
	if won or lost or menu_open: return    # no map commands after a terminal result or while the menu is up
	if event is InputEventMouseMotion:
		if _panning: _pan += event.position - _pan_last; _pan_last = event.position; queue_redraw(); return
		if _drag_from >= 0 and event.position.distance_to(_press_pos) > 8.0: _dragging = true
		# no repaint here: a hover change repaints through _view_key, and the rubber band / box select ride the
		# over layer, which _over_fast repaints every frame (a full-map repaint per motion made selections lag)
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


# routes are computed automatically now; a drag just selects the two hosts (no manual wiring)
func _drag_wire(src: int, dest: int) -> void:
	sel = {src: true}; _inspect = dest if not _mine(dest) else -1
	if _mine(dest): sel[dest] = true


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


func _host_at(p: Vector2) -> int:   # the host under a screen point — only one the player can see (fog of war)
	if not _map_rect().has_point(p): return -1
	var hit := -1; var nearest := INF
	for i in hosts.size():
		var distance := p.distance_to(_w2s(hosts[i].pos))
		if distance <= maxf(22, _r(i) * _zoom + 5) and distance < nearest and _visible_to(PLAYER, i):
			hit = i; nearest = distance
	return hit


func _connection_at(_w: Vector2) -> int:
	return -1   # there are no manual connections to click any more


func _play(t: int, recipe := "") -> void:   # launch the selected (or named) attack card at a foreign host
	if recipe == "": recipe = _chosen_attack
	if recipe != "": _cmd(["card", recipe, t])


func _play_support(recipe: String, t: int) -> void: _cmd(["card", recipe, t])


func _set_reserve(fac_choice: int) -> void: _cmd(["reserve", fac_choice])
func _set_priority(res: String) -> void: _cmd(["priority", res])


func _do_set_reserve(fac: int, choice: int) -> void:
	if choice in BOT_RESERVE_CHOICES: bot_reserve[fac] = choice
	if fac == PLAYER: _refresh_panel()


func _do_set_priority(fac: int, res: String) -> void:
	ship_pri[fac] = res if (res == "" or RES.has(res)) else ""
	if fac == PLAYER: _refresh_panel()


func _owned_feeders(_node: int) -> Array: return []   # legacy: no wired feeders in this model


func _cancel_to(_dest: int) -> void: pass


func _cmd(c: Array) -> void:
	if _camp and _camp_hold_left > 0.0: _camp_acted_in_hold = true
	if _camp_paused: _camp_set_pause(false)
	if not _mp_on: _apply_cmd(PLAYER, c); return
	if _out or won or lost: return
	_mp_queue.append(c)


func _apply_cmd(fac: int, c: Array) -> void:
	if c.is_empty() or not botnets.has(fac) or _eliminated.has(fac): return
	var n := c.size()
	match str(c[0]):
		"build": if n == 4: _do_build(fac, _int(c[1]), _int(c[2]), str(c[3]))
		"job": if n == 3: _do_toggle_job(fac, _int(c[1]), _int(c[2]))
		"cancel": if n == 3: _do_cancel_job(fac, _int(c[1]), _int(c[2]))
		"demolish": if n == 3: _do_demolish(fac, _int(c[1]), _int(c[2]))
		"produce": if n == 3: _do_produce(fac, _int(c[1]), _int(c[2]))
		"research": if n == 2: _do_research(fac, str(c[1]))
		"cancel_research": if n == 1: _cancel_research(fac)
		"card_action": if n == 2: _do_card_action(fac, str(c[1]))
		"lane_set": if n == 3: _lane_set(fac, _int(c[1]), str(c[2]))
		"lane_make": if n == 2: _lane_manufacture(fac, _int(c[1]))
		"lane_repeat": if n == 2: _lane_repeat(fac, _int(c[1]))
		"lane_cancel": if n == 2: _lane_cancel(fac, _int(c[1]))
		"reserve": if n == 2: _do_set_reserve(fac, _int(c[1]))
		"priority": if n == 2: _do_set_priority(fac, str(c[1]))
		"card": if n >= 3 and _host_ok(_int(c[2])) and str(c[1]) != "": _play_card(fac, str(c[1]), _int(c[2]), str(c[3]) if n >= 4 else "")


func _int(v: Variant) -> int:   # a JSON number (or anything else) as a building / slot index; garbage becomes -1
	return int(v) if (v is int or v is float) and is_finite(float(v)) else -1


func _host_ok(i: int) -> bool: return i >= 0 and i < hosts.size()
func _owns(fac: int, i: int) -> bool: return _host_ok(i) and int(hosts[i].owner) == fac


func _apply_options() -> void:   # turn the menu choices into the live grid + faction set + seed
	_cols = _opt_size.x; _rows = _opt_size.y
	if _camp: _layout = "grid"   # the campaign's chapters are authored on its grid
	elif _mp_on: _layout = GALAXIES[maxi(0, _opt_seed) % GALAXIES.size()]   # every lockstep screen must build the same town: the seed picks the galaxy
	else: _layout = _opt_shape if SHAPES.has(_opt_shape) else str(SHAPES[0])
	if _mp_on:   # people only: every faction in the match is a player, no AI
		ais = []; botnets = humans.duplicate(); town_seed = _opt_seed
		return
	var pool := [RIVAL, RIVAL2, RIVAL3]
	ais = []
	for k in clampi(_opt_enemies, 1, 3): ais.append(pool[k])
	botnets = [PLAYER] + ais
	town_seed = _opt_seed   # 0 = random


func _reset() -> void:   # a NEW town every restart, with the current options
	won = false; lost = false; _end_shown = false; _end_cause = ""; paused = false; _t = 0.0; _sim_acc = 0.0
	_panel_t = 0.0; _chosen_attack = ""; _chosen_siphon_res = "cash"
	_eliminated.clear()
	_panel_context = ""; _msg_t = 0.0; _msg_priority = 0
	_tab = ""; _hold = {}; _deck_drag_restore = false; _bank_alert = {}
	_tut = false; _ai_paused = false
	_tut_stage = 0; _tut_connected = false; _tut_attacked = false; _tut_combined = false; _tut_captured = false; _tut_target = -1; _tut_second = -1
	_camp = false; _camp_paused = false; _camp_chapter = 0; _camp_clock = 0.0; _camp_replay = false
	_camp_supplied = {}; _camp_events = {}; _camp_cash_landed = 0; _camp_cancelled = false; _camp_src = -1
	_camp_home = -1; _camp_support = -1; _camp_relay = -1; _camp_gateway = -1; _camp_rivalhq = -1; _camp_practice = -1; _camp_practice2 = -1; _camp_guard = -1; _camp_hold_left = 0.0; _camp_hold_text = ""; _camp_hold_target = -1; _camp_acted_in_hold = false
	if tut_panel != null: tut_panel.visible = false
	_apply_options()
	_clear_all()
	_gen()
	_refresh_sight(); _fit_view(); _refresh_panel(); _refresh_hand(); _refresh_top_tabs()


func _build_names(builds: Array) -> String:
	var out := []
	for b in builds:
		if str(b) != "": out.append(BUILD_KINDS[str(b)].name if BUILD_KINDS.has(str(b)) else str(b))
	return ", ".join(out) if not out.is_empty() else "none"


func _flash(m: String, priority := 2) -> void:
	if _msg_t > 0.0 and priority < _msg_priority: return
	_msg = m; _msg_t = 5.0; _msg_priority = priority


func _plabel(txt: String, sz := 14, col := C_TEXT) -> void:
	_lbl(panel_box, txt, sz, col, _panel_width() - 64.0)


func _lbl(parent: Control, txt: String, sz: int, col: Color, minw: float) -> Label:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", maxi(14, sz)); l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(minw, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


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
	var icon := ActionGlyph.new(); icon.action = action
	icon.col = C_BAD if action in ["Disconnect", "Stop"] else (BANK_COL["attack"] if action == "Attack" or action.ends_with("%") else C_GOOD)   # attack = red everywhere
	if action.ends_with("%") and float(action.trim_suffix("%")) > 100.0: icon.col = C_WARN   # an overcharge reads as a premium at a glance
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
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
	_layout_deck()                                        # the deck hides under the menu and returns as it was
	if top_tabs != null: top_tabs.visible = not open
	if open and panel != null: panel.visible = false
	if tut_panel != null: tut_panel.visible = _tut and not open   # the tutorial prompt hides under the menu
	if open: _menu_view = "main"; _refresh_menu()
	_refresh_panel(); queue_redraw()


func _menu_label(t: String) -> void:   # wraps to the column: an unwrapped sentence widens the scroll box past the panel
	var l := Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", 13); l.add_theme_color_override("font_color", C_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = menu_box.custom_minimum_size.x
	menu_box.add_child(l)


func _menu_title(t: String) -> void:
	var l := Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", 26); l.add_theme_color_override("font_color", C_TEXT)
	menu_box.add_child(l)


func _mbtn(txt: String, cb: Callable) -> void:   # a full-width menu button
	var b := Button.new(); b.text = txt; b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, 42)
	b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # never widen the column
	b.pressed.connect(cb); menu_box.add_child(b)


func _menu_gap(h: float) -> void:
	var c := Control.new(); c.custom_minimum_size = Vector2(0, h); menu_box.add_child(c)


func _size_menu(w: float, h: float) -> void:   # fit the panel to the view so no view has dead space
	if menu_panel == null: return
	menu_panel.size = Vector2(w, h)
	menu_panel.position = ((get_viewport_rect().size - menu_panel.size) * 0.5).floor()
	if menu_sc != null: menu_sc.size = menu_panel.size - Vector2(48.0, 44.0)
	if menu_box != null: menu_box.custom_minimum_size.x = w - 60.0


func _fit_menu_to_contents() -> void:
	if menu_box == null or _menu_view in ["help", "mp", "lobby"]: return
	var content := menu_box.get_combined_minimum_size().y + 44
	var maxh := get_viewport_rect().size.y - 48
	# when the content is taller than the window, clamp and let it scroll instead of overflowing the box
	menu_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if content > maxh else ScrollContainer.SCROLL_MODE_DISABLED
	_size_menu(menu_panel.size.x, minf(content, maxh))


func _refresh_menu() -> void:
	if menu_box == null: return
	if is_instance_valid(fb_details): _fb_draft.details = fb_details.text
	if is_instance_valid(fb_version): _fb_draft.version = fb_version.text
	if is_instance_valid(fb_name): _fb_draft.name = fb_name.text
	fb_details = null; fb_version = null; fb_name = null
	for c in menu_box.get_children(): menu_box.remove_child(c); c.queue_free()
	if is_instance_valid(menu_seed_edit): _seed_draft = menu_seed_edit.text
	menu_seed_edit = null
	menu_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if _menu_view in ["help", "mp", "lobby"] else ScrollContainer.SCROLL_MODE_DISABLED
	menu_box.add_theme_constant_override("separation", 6 if _menu_view == "newgame" else 10)   # newgame packs the most rows; keep it inside the window
	match _menu_view:
		"help": _size_menu(680.0, 640.0); _menu_help()
		"newgame": _size_menu(MENU_W, 452.0); _menu_newgame()
		"campaign": _size_menu(MENU_W + 56.0, 452.0); _menu_campaign()   # its chapter buttons are the widest menu rows
		"feedback": _size_menu(480.0, 590.0); _menu_feedback()
		"mp", "lobby":   # the whole window (minus a margin), in two columns
			var vp := get_viewport_rect().size
			_size_menu(maxf(560.0, vp.x - 48.0), maxf(480.0, vp.y - 48.0))
			if _menu_view == "mp": _menu_mp()
			else: _menu_lobby()
		_:
			var nb := (6 if ((_t >= 0.01 or _camp or _tut) and not won and not lost) else 5) + (0 if _mp_on else 1)
			_size_menu(MENU_W, 96.0 + float(nb) * 52.0); _menu_main()
	_fit_menu_to_contents.call_deferred()


# ============================================================ MULTIPLAYER (lockstep; server/PROTOCOL.md)
const MP_SIZES := ["small", "medium", "big"]   # the lobby's map sizes, as SIZE_PRESETS
var _mp_name_draft := ""
var _mp_code_draft := ""
var _mp_chat_draft := ""
var _mp_public := true                         # the browser's "create" choice
var _mp_ui := {}                               # live controls of the open multiplayer view (updated in place)
var _sp_size := Vector2i.ZERO                  # your single-player map size, restored after a match


func _net() -> Node:
	if net == null:
		net = NetScript.new(); net.version = GAME_VERSION; net.name = "Net"
		add_child(net)
		net.changed.connect(_mp_on_changed)
		net.match_message.connect(_mp_on_message)
	return net


func _mp_open() -> void:   # the menu's Multiplayer button
	if not _camp_has_onboarded():
		_flash("Finish the guided campaign first — it unlocks multiplayer."); return
	_net()
	if net.status == "offline": net.open()
	_mp_name_draft = net.player_name
	_menu_view = "lobby" if net.in_lobby() else "mp"
	_refresh_menu()


func _mp_on_changed() -> void:   # the connection moved: show it without rebuilding text fields the player types in
	if not menu_open: return
	if _menu_view == "mp" and net.in_lobby(): _menu_view = "lobby"; _refresh_menu(); return
	if _menu_view == "lobby" and not net.in_lobby(): _menu_view = "mp"; _refresh_menu(); return
	if _menu_view == "mp": _mp_fill_browser()
	elif _menu_view == "lobby": _mp_fill_lobby()


func _mp_on_message(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"start": _mp_start(m)
		"turn":
			if not _mp_on: return
			var turn := _int(m.get("turn")); var from := _int(m.get("from"))
			if turn < _mp_turn or turn > _mp_turn + 256 or not humans.has(from): return   # far ahead: a flood, not a player
			if not _mp_turns.has(turn): _mp_turns[turn] = {}
			_mp_turns[turn][from] = m.get("cmds") if m.get("cmds") is Array else []
		"drop":
			if not _mp_on: return
			var fac := _int(m.get("faction"))
			if not humans.has(fac): return
			_mp_dropped[fac] = maxi(_int(m.get("from_turn")), 0)
			if fac != PLAYER: _flash("%s left the match — their botnet stands idle" % fname(fac), 3)
		"desync":
			if _mp_on and _mp_desync < 0:
				_mp_desync = _int(m.get("turn"))
				_flash("The players' games drifted apart (turn %d) — this match can no longer be trusted. Leave from the menu." % _mp_desync, 4)
		"left":   # the server took you out of the match (a Leave at the last moment, or no response): back to the menu
			if _mp_on: _mp_end_match()
		"closed":
			if _mp_on and not won and not lost:
				lost = true; _end_cause = "The connection to the server was lost."
				_refresh_panel()


func _mp_start(m: Dictionary) -> void:   # the countdown ran out: everybody builds the same town from the same seed
	var players: Array = m.get("players") if m.get("players") is Array else []
	var me := _int(m.get("you"))
	var hs := []; var names := {}
	for p in players:
		if not (p is Dictionary): continue
		var fac := _int(p.get("faction"))
		if fac in [CfgFactions.PLAYER, RIVAL, RIVAL2] and not hs.has(fac): hs.append(fac); names[fac] = NetScript.clean_name(str(p.get("name", "")))
	hs.sort()
	if not hs.has(me) or hs.size() < 2: return   # a broken start message: stay in the lobby
	if not _mp_on: _sp_size = _opt_size
	PLAYER = me; humans = hs; _mp_names = names
	_mp_on = true; _out = false; _mp_desync = -1; _mp_wait = 0.0
	_mp_turn_steps = clampi(_int(m.get("turn_steps")), 1, 10); _mp_delay = clampi(_int(m.get("delay")), 1, 10)
	_mp_turn = 0; _mp_step_in_turn = 0; _mp_turns = {}; _mp_dropped = {}; _mp_queue = []
	_opt_size = SIZE_PRESETS[maxi(0, MP_SIZES.find(str(m.get("size", "medium"))))]
	_opt_seed = maxi(1, _int(m.get("seed")))
	_reset()
	_open_menu(false)
	_flash("The match is on — you play %s. Hold the majority or be the last botnet standing." % ("green" if PLAYER == CfgFactions.PLAYER else ("red" if PLAYER == RIVAL else "purple")), 3)


func _mp_leave() -> void:   # out of a match, back to the multiplayer menu (the server drops you: your botnet idles)
	if net != null: net.leave()
	_mp_end_match()


func _mp_end_match() -> void:   # this screen leaves the match (the server already knows, or is told by _mp_leave)
	_mp_on = false; _out = false; _mp_turns = {}; _mp_queue = []; _mp_dropped = {}
	PLAYER = CfgFactions.PLAYER; humans = [CfgFactions.PLAYER]; _mp_names = {}
	if _sp_size != Vector2i.ZERO: _opt_size = _sp_size
	_opt_seed = 0   # a random town behind the menu again
	_reset()
	_open_menu(true)
	_menu_view = "mp"; _refresh_menu()


func _mp_advance(dt: float) -> void:   # simulate while every player's turn is in; wait (frozen) while one is missing
	_sim_acc = minf(_sim_acc + dt, 0.5)   # fell behind: catch up as fast as frames allow, but never bank more
	var steps := 0; var stalled := false
	while _sim_acc >= SIM_DT - 0.000001 and steps < SIM_MAX_STEPS and not won and not lost:
		if _mp_step_in_turn == 0:
			if not _mp_ready(_mp_turn): stalled = true; break
			_mp_begin_turn()
		_sim_acc -= SIM_DT; steps += 1
		_sim_step(SIM_DT)
		_mp_step_in_turn += 1
		if _mp_step_in_turn >= _mp_turn_steps: _mp_end_turn()
	_mp_wait = (_mp_wait + dt) if stalled and steps == 0 else 0.0   # held up by someone's late turn


func _mp_ready(turn: int) -> bool:   # every faction still sending has sent this turn
	if turn < _mp_delay: return true
	var got: Dictionary = _mp_turns.get(turn, {})
	for fac in humans:
		if not got.has(fac) and not (_mp_dropped.has(fac) and turn >= int(_mp_dropped[fac])): return false
	return true


func _mp_begin_turn() -> void:   # everyone's commands for this turn, faction by faction; then yours go out for turn + delay
	var got: Dictionary = _mp_turns.get(_mp_turn, {})
	for fac in humans:
		if not got.has(fac) or (_mp_dropped.has(fac) and _mp_turn >= int(_mp_dropped[fac])): continue
		for c in got[fac]:
			if c is Array: _apply_cmd(fac, c)
	var batch := _mp_queue.slice(0, 64)
	_mp_queue = _mp_queue.slice(64)
	if net != null: net.send({"t": "turn", "turn": _mp_turn + _mp_delay, "cmds": batch})


func _mp_end_turn() -> void:
	_mp_step_in_turn = 0
	if _mp_turn > 0 and _mp_turn % 30 == 0 and net != null: net.send({"t": "hash", "turn": _mp_turn, "h": _mp_hash()})
	_mp_turns.erase(_mp_turn)
	_mp_turn += 1


func _mp_hash() -> String:   # the whole simulation in one fingerprint, to catch screens that drifted apart
	var parts := PackedStringArray([str(roundi(_t * 30.0)), str(flights.size()), str(_execs.size())])
	for h in hosts:
		parts.append("%d,%d,%s,%s,%s" % [int(h.owner), int(h.gen), ",".join(PackedStringArray(h.builds)), JSON.stringify(h.jobs), JSON.stringify(h.buf)])
		parts.append("%d,%d,%d,%d,%d" % [roundi(float(h.get("ddos_until", 0.0)) * 100.0), roundi(float(h.get("sabot_until", 0.0)) * 100.0), int(h.get("steal_by", -1)), roundi(float(h.get("steal_until", 0.0)) * 100.0), roundi(float(h.get("express_until", 0.0)) * 100.0)])
	for fac in botnets:
		for res in RES: parts.append(str(roundi(_avail(fac, res) * 1000.0)))
		parts.append("%d:%d" % [roundi(float(committed.get(fac, 0.0)) * 100.0), int(bot_reserve.get(fac, BOT_RESERVE_DEFAULT))])
		parts.append(JSON.stringify(incoming.get(fac, {})) + JSON.stringify(cards[fac]) + JSON.stringify(known.get(fac, {})) + JSON.stringify(research_job.get(fac, {})) + JSON.stringify(lanes.get(fac, [])))
	return "|".join(parts).md5_text()


# ---- the multiplayer menu: a lobby browser and the lobby itself ----
func _mp_row(parent: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	(parent if parent != null else menu_box).add_child(row)
	return row


func _mp_label(parent: Control, t: String) -> void:
	var l := Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", 13); l.add_theme_color_override("font_color", C_DIM)
	parent.add_child(l)


func _mp_columns() -> Array:   # the full-window multiplayer layout: two columns filling what the title rows leave
	var head := menu_box.get_combined_minimum_size().y + menu_box.get_theme_constant("separation") + 2.0
	var cols := HBoxContainer.new(); cols.add_theme_constant_override("separation", 32)
	cols.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, maxf(260.0, menu_sc.size.y - head))
	menu_box.add_child(cols)
	var out := []
	for k in 2:
		var c := VBoxContainer.new(); c.add_theme_constant_override("separation", 10)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(c); out.append(c)
	return out


func _mp_spacer(parent: Control) -> void:
	var c := Control.new(); c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)


func _mp_button(row: Control, txt: String, cb: Callable, on := false) -> Button:
	var b := Button.new(); b.text = txt; b.custom_minimum_size = Vector2(0, 36); b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.focus_mode = Control.FOCUS_ALL
	if on: b.add_theme_color_override("font_color", C_GOOD)
	b.pressed.connect(cb); row.add_child(b)
	return b


func _mp_field(row: Control, txt: String, hint: String, max_len: int) -> LineEdit:
	var e := LineEdit.new(); e.text = txt; e.placeholder_text = hint; e.max_length = max_len
	e.custom_minimum_size = Vector2(0, 34); e.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _inset_focus(e)
	row.add_child(e)
	return e


func _menu_mp() -> void:   # left: who you are, create, join by code · right: the open lobbies on the official server
	_menu_title("Multiplayer")
	var cols := _mp_columns()
	var left: VBoxContainer = cols[0]; var right: VBoxContainer = cols[1]
	_mp_label(left, "Your name")
	var name_edit := _mp_field(_mp_row(left), _mp_name_draft if _mp_name_draft != "" else net.player_name, "Player", 16)
	name_edit.text_changed.connect(func(t): _mp_name_draft = t)
	var save_name := func(_t = ""): net.rename(name_edit.text); _mp_name_draft = net.player_name
	name_edit.text_submitted.connect(save_name); name_edit.focus_exited.connect(save_name)
	_mp_label(left, "Create a lobby")
	var crow := _mp_row(left)
	var go_public := func(): _mp_public = true; _refresh_menu()
	var go_private := func(): _mp_public = false; _refresh_menu()
	var create := func(): net.rename(name_edit.text); net.create(_mp_public, 3, "medium")
	_mp_button(crow, "Public", go_public, _mp_public)
	_mp_button(crow, "Private", go_private, not _mp_public)
	var create_b := _mp_button(crow, "Create lobby", create)
	_mp_label(left, "Join a private lobby by its code")
	var jrow := _mp_row(left)
	var code := _mp_field(jrow, _mp_code_draft, "CODE", 5)
	code.text_changed.connect(func(t): _mp_code_draft = t)
	var join := func(_t = ""): net.rename(name_edit.text); net.join_code(code.text)
	code.text_submitted.connect(join)
	var join_b := _mp_button(jrow, "Join", join)
	_mp_spacer(left)
	var back := func(): _menu_view = "main"; _refresh_menu()
	var back_b := _mp_button(_mp_row(left), "← Back", back)
	back_b.custom_minimum_size.y = 42
	var status := Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	right.add_child(status)
	var lrow := _mp_row(right)
	var heading := Label.new(); heading.text = "Open lobbies"; heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 16)
	lrow.add_child(heading)
	var refresh := Button.new(); refresh.text = "Refresh"; refresh.custom_minimum_size = Vector2(120, 34); refresh.focus_mode = Control.FOCUS_ALL
	refresh.pressed.connect(func(): net.refresh()); lrow.add_child(refresh)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	_mp_ui = {"status": status, "list": list, "needs_server": [create_b, join_b, refresh]}
	_mp_fill_browser()


func _mp_fill_browser() -> void:   # connection state and the lobby list; no server: "Server unavailable", retried on its own
	if not _mp_ui.has("list") or not is_instance_valid(_mp_ui.list): return
	var status: Label = _mp_ui.status
	var unavailable: bool = not net.online() and net.error == NetScript.UNAVAILABLE
	if net.online():
		status.text = "Online as %s" % net.player_name
		status.add_theme_color_override("font_color", C_GOOD)
		if net.recent_error() != "":
			status.text += "  ·  " + net.recent_error()
			status.add_theme_color_override("font_color", C_WARN)
	elif unavailable:
		status.text = "Server unavailable  ·  trying again every few seconds"
		status.add_theme_color_override("font_color", C_BAD)
	else:
		status.text = "Connecting to the server…"
		status.add_theme_color_override("font_color", C_DIM)
	_mp_ui["err_shown"] = net.recent_error()
	for b in _mp_ui.get("needs_server", []): (b as Button).disabled = not net.online()
	var list: VBoxContainer = _mp_ui.list
	for c in list.get_children(): list.remove_child(c); c.queue_free()
	if not net.online() or net.lobbies.is_empty():
		var none := Label.new(); none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if net.online(): none.text = "No open lobbies yet — create one, or join a private one by its code."
		elif unavailable: none.text = "Server unavailable"
		else: none.text = "Connecting…"
		none.add_theme_color_override("font_color", C_BAD if unavailable else C_DIM)
		none.add_theme_font_size_override("font_size", 18 if unavailable else 13)
		list.add_child(none)
		return
	for l in net.lobbies:
		if not (l is Dictionary): continue
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
		var info := Label.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.clip_text = true
		info.text = "%s  ·  %d/%d  ·  %s" % [str(l.get("name", "lobby")), int(l.get("players", 0)), int(l.get("max", 3)), str(l.get("size", "medium")).capitalize()]
		row.add_child(info)
		var b := Button.new(); b.text = "Join"; b.custom_minimum_size = Vector2(90, 32)
		b.disabled = int(l.get("players", 0)) >= int(l.get("max", 3))
		b.pressed.connect(func(id = int(l.get("id", -1))): net.join_id(id))
		row.add_child(b); list.add_child(row)


func _menu_lobby() -> void:   # left: players, the host's settings, the countdown, Ready · right: the chat
	var lob: Dictionary = net.lobby
	var title := Label.new(); title.text = str(lob.get("name", "Lobby"))
	title.add_theme_font_size_override("font_size", 26); title.add_theme_color_override("font_color", C_TEXT)
	menu_box.add_child(title)
	var sub := Label.new(); sub.add_theme_font_size_override("font_size", 13); sub.add_theme_color_override("font_color", C_DIM)
	menu_box.add_child(sub)
	var cols := _mp_columns()
	var left: VBoxContainer = cols[0]; var right: VBoxContainer = cols[1]
	var nrow := _mp_row(left)
	var name_label := Label.new(); name_label.text = "Your name"; name_label.custom_minimum_size.x = 110
	name_label.add_theme_font_size_override("font_size", 13); name_label.add_theme_color_override("font_color", C_DIM)
	nrow.add_child(name_label)
	var name_edit := _mp_field(nrow, net.player_name, "Player", 16)
	var save_name := func(_t = ""):
		if NetScript.clean_name(name_edit.text) != net.player_name: net.rename(name_edit.text)
	name_edit.text_submitted.connect(save_name); name_edit.focus_exited.connect(save_name)
	var players := VBoxContainer.new(); players.add_theme_constant_override("separation", 2)
	left.add_child(players)
	var setting_note := Label.new()
	setting_note.add_theme_font_size_override("font_size", 13); setting_note.add_theme_color_override("font_color", C_DIM)
	left.add_child(setting_note)
	var prow := _mp_row(left)
	var max_b := []
	for n in [2, 3]: max_b.append(_mp_button(prow, "%d players" % n, func(k = n): net.settings({"max": k})))
	var vis_b := [_mp_button(prow, "Public", func(): net.settings({"public": true})), _mp_button(prow, "Private", func(): net.settings({"public": false}))]
	var mrow := _mp_row(left)
	var size_b := []
	for i in 3: size_b.append(_mp_button(mrow, ["Small", "Medium", "Big"][i], func(k = MP_SIZES[i]): net.settings({"size": k})))
	_mp_spacer(left)
	var countdown := Label.new(); countdown.add_theme_font_size_override("font_size", 24); countdown.add_theme_color_override("font_color", C_WARN)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; countdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(countdown)
	var brow := _mp_row(left)
	var ready_b := _mp_button(brow, "Ready", func(): net.set_ready(not net.me_ready()))
	ready_b.custom_minimum_size.y = 46
	var leave_b := _mp_button(brow, "Leave lobby", func(): net.leave())
	leave_b.custom_minimum_size.y = 46
	_mp_label(right, "Chat")
	var chat_log := RichTextLabel.new(); chat_log.bbcode_enabled = true; chat_log.scroll_following = true
	chat_log.custom_minimum_size = Vector2(0, 120); chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.add_theme_font_size_override("normal_font_size", 14)
	right.add_child(chat_log)
	var crow := _mp_row(right)
	var say := _mp_field(crow, _mp_chat_draft, "Say something…", 200)
	say.text_changed.connect(func(t): _mp_chat_draft = t)
	var send := func(_t = ""):
		net.say(say.text); say.text = ""; _mp_chat_draft = ""; say.grab_focus()
	say.text_submitted.connect(send)
	var send_b := _mp_button(crow, "Send", send)
	send_b.custom_minimum_size.x = 90; send_b.size_flags_horizontal = Control.SIZE_SHRINK_END
	var refusal := Label.new(); refusal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refusal.add_theme_font_size_override("font_size", 13); refusal.add_theme_color_override("font_color", C_WARN)
	right.add_child(refusal)
	_mp_ui = {"title": title, "sub": sub, "note": setting_note, "players": players, "max": max_b, "size": size_b, "vis": vis_b, "countdown": countdown, "log": chat_log, "ready": ready_b, "refusal": refusal, "chat_n": -1}
	_mp_fill_lobby()


func _mp_fill_lobby() -> void:
	if not _mp_ui.has("players") or not is_instance_valid(_mp_ui.players): return
	var lob: Dictionary = net.lobby
	var host: bool = net.is_host()
	(_mp_ui.title as Label).text = str(lob.get("name", "Lobby"))   # follows host changes and renames
	(_mp_ui.note as Label).text = "Players · lobby · map size" + ("" if host else "  ·  set by the host")
	(_mp_ui.sub as Label).text = "%s lobby  ·  code %s%s" % ["Public" if bool(lob.get("public", true)) else "Private", str(lob.get("code", "")), "" if bool(lob.get("public", true)) else "  ·  share it so friends can join"]
	var box: VBoxContainer = _mp_ui.players
	for c in box.get_children(): box.remove_child(c); c.queue_free()
	var plist: Array = lob.get("players", [])
	for k in plist.size():
		var p: Variant = plist[k]
		if not (p is Dictionary): continue
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new(); swatch.custom_minimum_size = Vector2(14, 14); swatch.color = fcol(k + 1)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var who := Label.new(); who.size_flags_horizontal = Control.SIZE_EXPAND_FILL; who.clip_text = true
		who.text = str(p.get("name", "Player")) + ("  (host)" if int(p.get("id", -1)) == int(lob.get("host", -2)) else "") + ("  · you" if int(p.get("id", -1)) == net.my_id else "")
		row.add_child(who)
		var rd := Label.new(); rd.text = "READY" if bool(p.get("ready", false)) else "not ready"
		rd.add_theme_color_override("font_color", C_GOOD if bool(p.get("ready", false)) else C_DIM)
		row.add_child(rd); box.add_child(row)
	for k in range(plist.size(), int(lob.get("max", 3))):
		var open_slot := Label.new(); open_slot.text = "      waiting for a player…"; open_slot.add_theme_color_override("font_color", C_DIM)
		box.add_child(open_slot)
	var mx := int(lob.get("max", 3))
	for b in _mp_ui.max:
		var n := 2 if b == _mp_ui.max[0] else 3
		(b as Button).disabled = not host or n < plist.size()
		(b as Button).add_theme_color_override("font_color", C_GOOD if n == mx else C_TEXT)
	var size_now := str(lob.get("size", "medium"))
	for i in 3:
		var b: Button = _mp_ui.size[i]
		b.disabled = not host
		b.add_theme_color_override("font_color", C_GOOD if MP_SIZES[i] == size_now else C_TEXT)
	for i in 2:
		var b: Button = _mp_ui.vis[i]
		b.disabled = not host
		b.add_theme_color_override("font_color", C_GOOD if bool(lob.get("public", true)) == (i == 0) else C_TEXT)
	(_mp_ui.ready as Button).text = "Not ready" if net.me_ready() else "Ready"
	(_mp_ui.ready as Button).add_theme_color_override("font_color", C_WARN if net.me_ready() else C_GOOD)
	if int(_mp_ui.chat_n) != net.chat.size() or net.chat.size() >= NetScript.CHAT_KEEP:
		_mp_ui.chat_n = net.chat.size()
		var chat_log: RichTextLabel = _mp_ui.log
		chat_log.clear()
		for line in net.chat:
			if bool(line.system): chat_log.append_text("[color=#%s]%s[/color]\n" % [C_DIM.to_html(false), _bb(str(line.text))])
			else: chat_log.append_text("[color=#%s]%s:[/color] %s\n" % [C_WARN.to_html(false), _bb(str(line.name)), _bb(str(line.text))])
	_mp_tick_countdown()


func _bb(t: String) -> String: return t.replace("[", "[lb]")   # chat is shown as written, never as markup


func _mp_tick_countdown() -> void:   # the big "starting in 3…" line (also called every frame while the lobby is open)
	if not _mp_ui.has("countdown") or not is_instance_valid(_mp_ui.countdown): return
	var left: float = net.countdown_left()
	var plist: Array = net.lobby.get("players", [])
	var all_ready := plist.size() >= 2
	for p in plist:
		if p is Dictionary and not bool(p.get("ready", false)): all_ready = false
	var txt := ""
	if left > 0.0: txt = "Starting in %d…" % int(ceil(left))
	elif plist.size() < 2: txt = "Waiting for at least one more player"
	elif not all_ready: txt = "Everyone presses Ready to start"
	(_mp_ui.countdown as Label).text = txt
	if _mp_ui.has("refusal") and is_instance_valid(_mp_ui.refusal): (_mp_ui.refusal as Label).text = net.recent_error()


func _menu_main() -> void:
	_menu_title("BOTNET")
	_menu_gap(6)
	if (_t >= 0.01 or _camp or _tut) and not won and not lost: _mbtn("Resume", func(): _open_menu(false))   # an in-progress campaign at _t==0 (reading pause) still resumes
	if _mp_on:
		_mbtn("Leave match", _mp_leave)
	elif not _camp_has_onboarded():
		if not _camp or won or lost:   # a live chapter is continued with Resume above (this button would rebuild it from its start)
			var going := int(_camp_load().get("chapter", 0)) > 0 or (_camp_load().get("chapters_completed", []) as Array).has(true)
			_mbtn("▶ Continue the guided campaign" if going else "▶ Start the guided campaign", func(): _camp_resume_or_start())
		_menu_label("New game and Multiplayer unlock once the campaign is complete.")
	else:
		_mbtn("New game", func(): _menu_view = "newgame"; _refresh_menu())
		_mbtn("Multiplayer", _mp_open)
		_mbtn("Campaign", func(): _menu_view = "campaign"; _refresh_menu())
	_mbtn("Help", func(): _help_page = 0; _menu_view = "help"; _refresh_menu())
	_mbtn("Feedback", func(): _fb_status = ""; _menu_view = "feedback"; _refresh_menu())
	_mbtn("Exit", func(): get_tree().quit())


func _menu_campaign() -> void:
	_menu_title("Campaign")
	var save := _camp_load()
	var cc = save.get("chapters_completed", [])
	if cc is Array and (cc as Array).size() == CAMP_CHAPTERS:
		for k in CAMP_CHAPTERS: _camp_done[k] = bool((cc as Array)[k])
	if not bool(save.get("completed", false)):
		_mbtn("Resume from checkpoint — Chapter %d" % (int(save.get("chapter", 0)) + 1), func(): _camp_resume_or_start())
		_menu_label("Resuming rebuilds that chapter's starting situation; progress within the chapter restarts.")
	var titles := _camp_chapters()
	for ch in CAMP_CHAPTERS:
		var unlocked: bool = ch == 0 or _camp_done[ch - 1] or bool(save.get("completed", false))
		var label := "%s%d. %s" % ["✓ " if _camp_done[ch] else "", ch + 1, titles[ch]]
		if unlocked: _mbtn("Replay — " + label, func(c = ch): _camp_resume_or_start(c))
		else: _menu_label("🔒 " + label)
	_mbtn("← Back", func(): _menu_view = "main"; _refresh_menu())


func _menu_newgame() -> void:
	_menu_title("New game")
	var mrow0 := HBoxContainer.new(); mrow0.add_theme_constant_override("separation", 6)   # "Map · 8 × 6" ... [Layout: Grid]
	var ml := Label.new(); ml.text = "Map  ·  %d × %d" % [_opt_size.x, _opt_size.y]; ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ml.add_theme_font_size_override("font_size", 13); ml.add_theme_color_override("font_color", C_DIM); mrow0.add_child(ml)
	var shape := Button.new(); shape.name = "Shape"; shape.text = "Layout: " + _opt_shape.capitalize()   # click to switch
	shape.focus_mode = Control.FOCUS_ALL; shape.add_theme_font_size_override("font_size", 13); shape.add_theme_color_override("font_color", C_WARN)
	shape.pressed.connect(func(): _opt_shape = str(SHAPES[(SHAPES.find(_opt_shape) + 1) % SHAPES.size()]); _refresh_menu())
	mrow0.add_child(shape); menu_box.add_child(mrow0)
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
	menu_seed_edit = LineEdit.new(); menu_seed_edit.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, 34); _inset_focus(menu_seed_edit)
	menu_seed_edit.placeholder_text = "random"
	menu_seed_edit.text = _seed_draft
	menu_box.add_child(menu_seed_edit)
	_menu_gap(4)
	_mbtn("Start", _start_new_game)
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


const HELP_PAGES := ["research", "deliver", "produce", "build", "attack", "goal"]
const HELP_TITLES := ["Research. Manufacture. Launch.", "Bring resources home", "Feed production and shipping", "Choose what to build next", "Attack the right part of the economy", "Win and keep access useful"]

func _menu_help() -> void:
	_help_page = clampi(_help_page, 0, HELP_PAGES.size() - 1)
	_menu_title("Help  ·  %d / %d" % [_help_page + 1, HELP_PAGES.size()])
	_help_head(str(HELP_TITLES[_help_page]))
	var example := HelpIllustration.new()
	example.name = "HelpIllustration"
	example.game = self; example.page = str(HELP_PAGES[_help_page])
	menu_box.add_child(example)
	var nav := HBoxContainer.new(); nav.add_theme_constant_override("separation", 8)
	var prev := Button.new(); prev.text = "← Prev"; prev.custom_minimum_size = Vector2(0, 40); prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev.disabled = _help_page == 0; prev.pressed.connect(func(): _help_page -= 1; _refresh_menu())
	nav.add_child(prev)
	var nxt := Button.new(); nxt.text = "Next →"; nxt.custom_minimum_size = Vector2(0, 40); nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt.disabled = _help_page >= HELP_PAGES.size() - 1; nxt.pressed.connect(func(): _help_page += 1; _refresh_menu())
	nav.add_child(nxt)
	var back := Button.new(); back.text = "Back to menu"; back.custom_minimum_size = Vector2(0, 40); back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func(): _menu_view = "main"; _refresh_menu())
	nav.add_child(back)
	menu_box.add_child(nav)


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
	fb_details = TextEdit.new(); fb_details.placeholder_text = "What happened, or your idea…"; _inset_focus(fb_details)
	fb_details.text = str(_fb_draft.details)
	fb_details.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, 100)
	menu_box.add_child(fb_details)
	_menu_label("Name (optional)")
	fb_name = LineEdit.new(); fb_name.placeholder_text = "anonymous"; fb_name.custom_minimum_size = Vector2(menu_box.custom_minimum_size.x, 32); _inset_focus(fb_name)
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
	return [
		{"title": "Your main node", "text": "Your main node makes one of each resource every second. Resources made elsewhere must be delivered home by a Bot courier."},
		{"title": "Manufacture", "text": "Click a known card in the deck to manufacture a copy, then drag it from the deck onto a target to launch it."},
		{"title": "Win", "text": "Hold at least 51% of the hosts for 51 seconds, or be the last network with its main node."},
	]


# Tutorial keywords take the colour of the thing they name: buildings their card colour, ATTACK things red, DEFENCE blue,
# your own pieces green, the target and the win numbers gold. Longest phrases first; placeholders stop nested matches.
# Training-text vocabulary: term -> colour/icon source. Whole words, case-sensitive, longest match wins, ONE regex pass
# (no placeholder round trip, so text like "30 Crypto" or "0day" can never be corrupted). "" = leave the word as typed.
const RICH_TERMS := {
	# installations: their building-card colour + pictogram
	"Intel harvester": "kind:intel", "Crypto miner": "kind:cash", "Bot farm": "kind:bot", "Bot farms": "kind:bot",
	"Credential harvester": "kind:cred", "Research lab": "kind:lab", "farms": "tint:bot",
	# resources: the HUD's colour + pictogram
	"Intel": "kind:intel", "Crypto": "kind:cash", "Credentials": "kind:cred", "Creds": "kind:cred", "Research": "kind:lab",
	"bots": "kind:bot", "defenders": "tint:bot",
	# cards: the deck tab's colour (ATTACK red / DEFENCE blue) + the card art
	"Recon": "card:recon", "Credential breach": "card:breach", "Known exploit": "card:exploit", "Phishing": "card:phish",
	"Packet siphon": "card:siphon", "Vault raid": "card:vault", "DDoS": "card:ddos", "0day": "card:zeroday",
	"Worm": "card:worm", "Supply-chain sabotage": "card:sabotage", "Patch": "card:patch", "Incident response": "card:response",
	"Traffic filter": "card:filter", "Courier cover": "card:cover", "Express route": "card:express",
	"ATTACK": "bank:attack", "DEFENCE": "bank:defense",
	# panel buttons: the button's colour (+ its glyph where one exists)
	"Scan": "act:Scan", "Launch": "act:Attack", "Stop": "act:Stop",
	"CUT": "cut", "breached": "breach", "BREACHED": "breach",
	# computers: their CURRENT owner's colour (neutral = the gold highlight ring), no icon
	"YOUR RIG": "rig:p", "rival rig": "rig:r", "rival's rig": "rig:r", "Support": "role:support", "Neighborhood Relay": "role:relay",
	"relay": "role:relay", "Corporate Gateway": "role:gateway", "Gateway": "role:gateway",
	"Practice host": "role:practice", "Practice host 2": "role:practice2",
	# the old free-play tutorial and the win numbers
	"TRAINING TARGET": "warn", "TARGET": "warn", "TRAINING SUPPORT": "fac:p", "Training support": "fac:p", "SUPPORT": "fac:p",
	"green": "fac:p", "51%": "warn", "51 seconds": "warn",
}
var _rich_re: RegEx
var _rich_icons := {}   # id -> baked ImageTexture (strong refs: the resource cache only keeps weak ones)
var _rich_paths := {}   # id -> the res:// path a BBCode [img] tag loads


func _re_escape(s: String) -> String:
	var out := ""
	for ch in s:
		if "\\^$.|?*+()[]{}".contains(ch): out += "\\"
		out += ch
	return out


func _rich_regex() -> RegEx:
	if _rich_re == null:
		var keys: Array = RICH_TERMS.keys()
		keys.sort_custom(func(a, b): return str(a).length() > str(b).length())   # PCRE alternation is leftmost-first: longest first
		var alts := PackedStringArray()
		for k in keys: alts.append(_re_escape(str(k)))
		_rich_re = RegEx.create_from_string("(?<![A-Za-z0-9])(?:%s)(?![A-Za-z0-9])" % "|".join(alts))
	return _rich_re


func _rich_spec(spec: String) -> Array:   # -> [text colour, icon id ("" = none), icon tint]
	var p := spec.split(":", true, 1)
	var k := p[1] if p.size() > 1 else ""
	match p[0]:
		"kind": return [BUILD_KINDS[k].col, "k:" + k, BUILD_KINDS[k].col]
		"tint": return [BUILD_KINDS[k].col, "", Color.WHITE]
		"card":
			var cd: Dictionary = CARDS[k]
			return [BANK_COL[str(cd.bank)], "fam:" + str(cd.fam), Color.WHITE]
		"bank": return [BANK_COL[k], "", Color.WHITE]
		"act":
			var col: Color = BANK_COL["attack"]
			if k == "Scan": col = C_GOOD
			elif k == "Stop": col = C_BAD
			return [col, ("a:" + k) if k in ["Scan", "Attack", "Stop"] else "", col]
		"role":
			var h := _camp_role_host(k) if _camp else -1
			var c: Color = C_WARN   # neutral: the gold of the highlight ring
			if h >= 0 and h < hosts.size() and int(hosts[h].owner) != NEUTRAL: c = fcol(int(hosts[h].owner))
			return [c, "", Color.WHITE]
		"rig", "fac": return [fcol(PLAYER if k == "p" else RIVAL), "", Color.WHITE]
		"cut": return [Color(1, 0.4, 0.65), "", Color.WHITE]   # the map's CUT timer colour
		"breach": return [Color(1, 0.55, 0.25), "", Color.WHITE]   # the map's BREACHED label
	return [C_WARN, "", Color.WHITE]   # "warn"


func _tut_rich(text: String, seen = null) -> String:   # plain training text -> BBCode. It escapes '[', so never feed it BBCode
	if seen == null: seen = {}
	var out := ""; var at := 0
	for m in _rich_regex().search_all(text):
		out += text.substr(at, m.get_start() - at).replace("[", "[lb]")
		var word := m.get_string(); var spec := str(RICH_TERMS[word])
		if spec == "": out += word
		else:
			var r := _rich_spec(spec); var icon := ""
			var id := str(r[1])
			if id != "" and not seen.has(id) and _rich_paths.has(id):   # an icon only on a term's first mention per banner
				seen[id] = true
				var opt := "width=16 height=16" + (" region=250,250,754,754" if id.begins_with("fam:") else " color=#" + (r[2] as Color).to_html(false))
				icon = "[img %s]%s[/img] " % [opt, _rich_paths[id]]
			out += "%s[color=#%s]%s[/color]" % [icon, (r[0] as Color).to_html(false), word]
		at = m.get_end()
	return out + text.substr(at).replace("[", "[lb]")


func _bake_rich_icons() -> void:   # the HUD/palette pictograms, drawn once into textures the training text shows inline
	for fam in CfgCards.FAMILY_ART: _rich_paths["fam:" + fam] = (CfgCards.FAMILY_ART[fam] as Texture2D).resource_path   # real files: fine headless
	if DisplayServer.get_name() == "headless": return   # the dummy renderer never draws a frame: colour-only text
	var ids := [["k", "bot"], ["k", "intel"], ["k", "cash"], ["k", "cred"], ["k", "lab"], ["a", "Scan"], ["a", "Attack"], ["a", "Stop"]]
	var vp := SubViewport.new(); vp.transparent_bg = true; vp.size = Vector2i(48 * ids.size(), 48)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := RichIconPainter.new(); painter.game = self; painter.theme = theme; painter.size = Vector2(vp.size); vp.add_child(painter)
	for k in ids.size():
		if ids[k][0] == "a":
			var ag := ActionGlyph.new(); ag.action = ids[k][1]; ag.col = Color.WHITE
			ag.position = Vector2(k * 48, 0); ag.size = Vector2(24, 24); ag.scale = Vector2(2, 2); vp.add_child(ag)
		else: painter.kinds.append([ids[k][1], k])
	add_child(vp)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp): return
	var img := vp.get_texture().get_image(); vp.queue_free()
	if img == null or img.is_empty(): return
	for k in ids.size():
		var cell := img.get_region(Rect2i(k * 48, 0, 48, 48)); cell.generate_mipmaps()
		var id := "%s:%s" % ids[k]
		var path := "res://__rich_icons/%s.tres" % id.replace(":", "_").replace(" ", "_")
		var tex := ImageTexture.create_from_image(cell); tex.take_over_path(path)   # [img] loads it from the resource cache; nothing touches disk
		_rich_icons[id] = tex; _rich_paths[id] = path
	if _tut: _show_tut()   # the first banner may have been built before the bake finished


func _start_tutorial() -> void:   # a short free-play quickstart (the campaign is the full onboarding)
	_opt_size = SIZE_PRESETS[0]; _opt_enemies = 1; _opt_seed = 7
	_reset()
	_tut = true; _tut_stage = 0; _ai_paused = true
	_open_menu(false); _show_tut(); _fit_view()


func _tick_tutorial() -> void:
	if not _tut: return
	var done := false
	match _tut_stage:
		0: done = _inspect == int(rig[PLAYER]) or sel.has(int(rig[PLAYER]))
		1: done = int(card_plays.get(PLAYER, 0)) > 0
		2: done = won or lost
	if done: _tut_next()


func _show_tut() -> void:
	if _camp: _camp_show(); return
	if tut_box == null: return
	for c in tut_box.get_children(): tut_box.remove_child(c); c.queue_free()
	var stages := _tut_stages()
	var step: Dictionary = stages[_tut_stage]
	var row := HBoxContainer.new(); tut_box.add_child(row)
	_lbl(row, "%d/%d · %s" % [_tut_stage + 1, stages.size(), step.title], 16, C_WARN, 0)
	var button := Button.new(); button.custom_minimum_size = Vector2(126, 32); button.add_theme_font_size_override("font_size", 14)
	button.text = "Start match" if _tut_stage == stages.size() - 1 else "Skip tutorial"
	button.pressed.connect(_tut_finish); row.add_child(button)
	var body := RichTextLabel.new(); body.bbcode_enabled = true; body.fit_content = true; body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("normal_font_size", 14); body.add_theme_color_override("default_color", C_TEXT)
	body.text = _tut_rich(str(step.text)); tut_box.add_child(body)
	body.custom_minimum_size.x = maxf(200, get_viewport_rect().size.x - 80)
	tut_panel.visible = _tut and not menu_open
	_layout_ui()


func _tutorial_target() -> int:
	if _camp: return _camp_target()
	if not _tut: return -1
	if _tut_stage == 0: return int(rig[PLAYER])
	return -1


func _tut_next() -> void:
	_tut_stage = mini(_tut_stage + 1, _tut_stages().size() - 1)
	_show_tut()


func _tut_finish() -> void:
	_tut = false; _ai_paused = false
	if tut_panel != null: tut_panel.visible = false
	_flash("Rival active. Capture territory and protect your rig.")
	_layout_ui(); _fit_view()


# ============================================================ GUIDED CAMPAIGN
# Five chapters of ONE continuous game on CAMP_SEED, on the research-manufacture-launch rules. Chapters are phases;
# the step within a chapter reuses _tut_stage. Advancement is gated on real game-state outcomes. A reading pause
# (_camp_paused) freezes the WHOLE simulation; the player resumes with Space or by taking the action.
func _camp_chapters() -> Array:
	return ["Prepare an operation", "Production is not delivery", "Research and manufacture", "Steal and protect", "Run the network"]


func _camp_steps(chapter: int) -> Array:
	match chapter:
		0: return [
			{"t": "Your main node", "r": "Your main node makes one of every resource each second — already spendable.", "a": "Select YOUR MAIN NODE to read its five banks.", "w": "Resources are only spendable once they reach your main node.", "role": "home", "pause": true},
			{"t": "Manufacture a card", "r": "A Credential breach copy is being manufactured.", "a": "Click Credential breach in the deck to manufacture one copy.", "w": "You already know the basic recipes. Manufacturing spends resources once.", "role": "", "ui": "card:breach", "pause": true},
			{"t": "Capture", "r": "The Neighborhood Relay is yours.", "a": "Drag the ready Credential breach onto the Neighborhood Relay.", "w": "Credential breach captures one security-1 host after a short execution.", "role": "relay", "ui": "card:breach", "card": "breach", "pause": true},
		]
		1: return [
			{"t": "Make Intel", "r": "The Intel harvester is producing — but its output is not home yet.", "a": "Select the relay and build an Intel harvester in a slot.", "w": "A remote producer fills a local buffer; a courier must carry it home.", "role": "relay", "ui": "build:intel", "pause": true},
			{"t": "Bot farm", "r": "The Bot farm makes Bots that deliver themselves.", "a": "Build a Bot farm in another slot of the relay.", "w": "One Intel becomes two Bots. New Bots travel home on their own.", "role": "relay", "ui": "build:bot", "pause": true},
			{"t": "Delivery", "r": "A resource arrived home and its courier was consumed.", "a": "Wait for an Intel courier to reach your main node.", "w": "One Bot carries one unit and is spent on arrival.", "role": "home", "pause": false},
		]
		2: return [
			{"t": "Research a blueprint", "r": "Known exploit is being researched.", "a": "Click Known exploit in the deck to start researching it.", "w": "Research unlocks the recipe. It does not give you a free card.", "role": "", "ui": "card:exploit", "pause": true},
			{"t": "Manufacture it", "r": "A Known exploit copy is ready.", "a": "After it unlocks, click Known exploit to manufacture a copy.", "w": "The blueprint is the prerequisite; a copy is made separately.", "role": "", "ui": "card:exploit", "pause": false},
			{"t": "Use it", "r": "You captured a security-2 host.", "a": "Launch Known exploit at the Corporate Gateway.", "w": "Known exploit reaches security 2.", "role": "gateway", "ui": "card:exploit", "card": "exploit", "pause": false},
		]
		3: return [
			{"t": "Steal production", "r": "The Practice host's output now flows to you.", "a": "Manufacture and launch Phishing on the Practice host.", "w": "Phishing diverts new output; you still need couriers to collect it.", "role": "practice", "ui": "card:phish", "card": "phish", "pause": false},
			{"t": "Protect", "r": "The theft on your relay is cleared.", "a": "Launch Incident response on the Neighborhood Relay.", "w": "Incident response clears theft from your own host.", "role": "relay", "ui": "card:response", "card": "response", "pause": false, "fire": "ch4_phish"},
		]
		_: return [
			{"t": "Your move", "r": "Victory.", "a": "Win the district: hold a majority, or take the rival main node.", "w": "Lose your main node and you lose.", "role": "", "pause": true},
		]


func _camp_role_host(role: String) -> int:
	match role:
		"home": return _camp_home
		"relay", "income": return _camp_relay
		"gateway", "frontier": return _camp_gateway
		"practice": return _camp_practice
		"practice2": return _camp_practice2
		"support": return _camp_support
	return -1


func _camp_target() -> int:
	if not _camp: return -1
	if _camp_hold_left > 0.0: return _camp_hold_target
	if _camp_chapter == CAMP_OPEN: return -1
	var steps := _camp_steps(_camp_chapter)
	if _tut_stage < 0 or _tut_stage >= steps.size(): return -1
	return _camp_role_host(str(steps[_tut_stage].get("role", "")))


func _camp_step() -> Dictionary:
	if not _camp: return {}
	var s := _camp_steps(_camp_chapter)
	return s[_tut_stage] if _tut_stage >= 0 and _tut_stage < s.size() else {}


func _camp_pulse() -> float:
	return 0.5 + 0.5 * sin(_camp_clock * TAU * 1.4)


func _camp_from() -> int: return -1   # no manual wiring to guide any more


func _camp_fill(s: String) -> String: return s


func _camp_ui_targets() -> Array:   # the live Controls the step names (a deck card or a build card), re-found each frame
	var st := _camp_step()
	if st.is_empty() or menu_open or won or lost or _camp_hold_left > 0.0: return []
	var specs = st.get("ui", [])
	if specs is String: specs = [specs]
	var out := []
	for spec in specs:
		var p := str(spec).split(":", true, 1)
		if p.size() != 2: continue
		match p[0]:
			"card": out.append_array(_camp_card_ctrls(p[1]))
			"build": out.append_array(_camp_build_ctrls(p[1]))
	return out


func _camp_card_ctrls(recipe: String) -> Array:
	if not _deck_open: return _deck_chip_nodes().filter(func(c): return _card_of(str(c.key)) == recipe)
	var bank := _bank_of(recipe)
	if bank != _card_bank: return [card_banks.get_child(0 if bank == "attack" else 1)]
	if _deck_page_of(recipe) != _deck_page: return [deck_pager]   # the card is on another page: cue the pager
	return hand_bar.get_children().filter(func(c): return _card_of(str(c.key)) == recipe and c.visible)


func _camp_build_ctrls(kind: String) -> Array:
	var h := int(sel.keys()[0]) if sel.size() == 1 else _inspect
	if h < 0 or not _mine(h) or _count_all(h, kind) > 0: return []
	return _panel_find(func(c): return c is BuildCard and c.kind == kind)


func _panel_find(ok: Callable) -> Array:
	var out := []; var stack: Array = panel_box.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if ok.call(n): out.append(n)
		stack.append_array(n.get_children())
	return out


func _camp_bfs(src: int, avoid := -1) -> Dictionary:
	var dist := {src: 0}; var q := [src]; var head := 0
	while head < q.size():
		var c: int = q[head]; head += 1
		for o in hosts[c].links:
			var oi := int(o)
			if oi == avoid or dist.has(oi): continue
			dist[oi] = int(dist[c]) + 1; q.append(oi)
	return dist


func _camp_roles() -> void:
	_camp_home = int(rig[PLAYER])
	_camp_support = -1
	for i in hosts.size():
		if _mine(i) and i != _camp_home: _camp_support = i; break
	var dist := _camp_bfs(_camp_home)
	_camp_relay = _camp_pick(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub) and hosts[_camp_home].links.has(i),
		func(i): return [int(dist.get(i, 99)), i])
	if _camp_relay < 0:
		_camp_relay = _camp_pick(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub), func(i): return [int(dist.get(i, 99)), i])
	_camp_gateway = _camp_pick(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub) and i != _camp_relay,
		func(i): return [int(dist.get(i, 99)), i])
	var prac := _camp_all(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub) and i not in [_camp_relay, _camp_gateway],
		func(i): return [int(dist.get(i, 99)), i])
	_camp_practice = prac[0] if prac.size() > 0 else -1
	_camp_practice2 = prac[1] if prac.size() > 1 else -1


func _camp_pick(ok: Callable, key: Callable) -> int:
	var best := -1; var bk = null
	for i in hosts.size():
		if not bool(ok.call(i)): continue
		var k = key.call(i)
		if bk == null or _less(k, bk): bk = k; best = i
	return best


func _camp_all(ok: Callable, key: Callable) -> Array:
	var out := []
	for i in hosts.size():
		if bool(ok.call(i)): out.append(i)
	out.sort_custom(func(a, b): return _less(key.call(a), key.call(b)))
	return out


func _less(a: Array, b: Array) -> bool:
	for k in mini(a.size(), b.size()):
		if float(a[k]) != float(b[k]): return float(a[k]) < float(b[k])
	return a.size() < b.size()


func _camp_own(i: int) -> void:
	if i >= 0 and not _mine(i): _capture(i, PLAYER)


func _camp_grant(b: float, intel: float, c: float, k: float, r: float) -> void:
	for pair in [["bots", b], ["intel", intel], ["cash", c], ["creds", k], ["research", r]]:
		bank[PLAYER][str(pair[0])] = maxf(_avail(PLAYER, str(pair[0])), minf(float(pair[1]), _cap(PLAYER, str(pair[0]))))


func _camp_supply(recipe: String) -> void:
	var id := "%d:%s" % [_camp_chapter, recipe]
	if _camp_supplied.get(id, false): return
	_camp_supplied[id] = true
	if not known.has(PLAYER): known[PLAYER] = {}
	known[PLAYER][recipe] = true
	cards[PLAYER][recipe] = _held(PLAYER, recipe) + 1


func _camp_slots(i: int, n: int) -> void:
	if i >= 0 and int(hosts[i].slots) < n: hosts[i].slots = n


func _camp_setup(chapter: int) -> void:
	_camp_own(_camp_support)
	if _camp_support >= 0: hosts[_camp_support].name = "Support"
	if _camp_relay >= 0: hosts[_camp_relay].name = "Neighborhood Relay"
	if _camp_gateway >= 0: hosts[_camp_gateway].name = "Corporate Gateway"
	match chapter:
		0:
			_camp_grant(20, 40, 20, 12, 8)
		1:
			_camp_own(_camp_relay); _camp_slots(_camp_relay, 4)
			_camp_grant(40, 120, 60, 20, 10)
		2:
			_camp_own(_camp_relay); _set_builds(_camp_relay, ["intel", "bot"])
			# a security-2 gateway for Known exploit
			if _camp_gateway >= 0:
				hosts[_camp_gateway].owner = RIVAL; hosts[_camp_gateway].gen += 1; hosts[_camp_gateway].type = "server"
			_camp_grant(60, 200, 200, 120, 120)
		3:
			_camp_own(_camp_relay); _set_builds(_camp_relay, ["intel", "bot", "cash"])
			for p in [_camp_practice]:
				if p >= 0:
					hosts[p].owner = RIVAL; hosts[p].gen += 1; _camp_slots(p, 3); _set_builds(p, ["intel", "cash"]); hosts[p].name = "Practice host"
			_camp_grant(80, 200, 200, 200, 120)
			for recipe in ["phish", "response"]: _camp_supply(recipe)
		CAMP_OPEN:
			_camp_own(_camp_relay); _set_builds(_camp_relay, ["intel", "bot", "cash", "cred", "lab"])
			_camp_grant(80, 150, 150, 120, 120)
	_msg_t = 0.0; _msg_priority = 0
	_refresh_sight()


func _camp_own_path(a: int, b: int, avoid := -1) -> void:
	if a < 0 or b < 0: return
	var prev := {a: a}; var q := [a]; var head := 0
	while head < q.size():
		var c: int = q[head]; head += 1
		if c == b: break
		for o in hosts[c].links:
			var oi := int(o)
			if oi == avoid or prev.has(oi): continue
			prev[oi] = c; q.append(oi)
	if not prev.has(b): return
	var n := b
	while n != a:
		if n != b: _camp_own(n)
		n = int(prev[n])


func _camp_gateway_prev() -> int: return -1


func _nearest_owned(t: int) -> int:
	var best := -1; var bd := 99
	for i in hosts.size():
		if not _mine(i): continue
		var d := int(_camp_bfs(i).get(t, 99))
		if d < bd: bd = d; best = i
	return best


# ---- lifecycle ----
var _opt_backup := {}
func _start_campaign(chapter: int, replay := false) -> void:
	if _opt_backup.is_empty() and not _camp:
		_opt_backup = {"size": _opt_size, "enemies": _opt_enemies, "seed": _opt_seed, "shape": _opt_shape}
	_opt_size = CAMP_SIZE; _opt_enemies = 1; _opt_seed = CAMP_SEED; _opt_shape = "grid"
	_reset()
	_camp_roles()
	_camp_chapter = clampi(chapter, 0, CAMP_OPEN)
	_camp_supplied = {}; _camp_events = {}
	_camp_setup(_camp_chapter)
	_camp = true; _tut = true; _tut_stage = 0; _camp_replay = replay
	_ai_paused = _camp_chapter < CAMP_OPEN
	var steps := _camp_steps(_camp_chapter)
	_camp_paused = bool(steps[0].get("pause", false))
	_open_menu(false); _show_tut(); _fit_view()
	if not replay: _camp_save()


func _camp_save_path() -> String:
	return CAMP_SAVE if is_inside_tree() and get_tree().current_scene == self else CAMP_SAVE_HARNESS


func _camp_save() -> void: _camp_save_at(_camp_chapter, _tut_stage)


func _camp_save_at(chapter: int, step: int) -> void:
	var data := {"schema": 2, "game_version": GAME_VERSION, "campaign_seed": CAMP_SEED,
		"chapter": chapter, "step": step, "completed": _camp_done.count(true) >= CAMP_CHAPTERS,
		"chapters_completed": _camp_done.duplicate()}
	var f := FileAccess.open(_camp_save_path(), FileAccess.WRITE)
	if f != null: f.store_line(JSON.stringify(data)); f.close()


func _camp_load() -> Dictionary:
	if not FileAccess.file_exists(_camp_save_path()): return {}
	var f := FileAccess.open(_camp_save_path(), FileAccess.READ)
	if f == null: return {}
	var d = JSON.parse_string(f.get_as_text()); f.close()
	if not (d is Dictionary): return {}
	var none := []; none.resize(CAMP_CHAPTERS); none.fill(false)
	var cc = (d as Dictionary).get("chapters_completed", none)
	if not (cc is Array) or (cc as Array).size() != CAMP_CHAPTERS: cc = none
	return {"completed": bool((d as Dictionary).get("completed", false)), "chapter": clampi(int((d as Dictionary).get("chapter", 0)), 0, CAMP_OPEN), "step": int((d as Dictionary).get("step", 0)), "chapters_completed": cc}


func _camp_has_onboarded() -> bool:
	return bool(_camp_load().get("completed", false))


func _camp_first_run() -> void:
	if not is_inside_tree() or get_tree() == null or get_tree().current_scene != self: return
	if not _camp_has_onboarded(): _camp_resume_or_start()


func _camp_resume_or_start(replay_chapter := -1) -> void:
	if replay_chapter >= 0:
		_start_campaign(replay_chapter, true); return
	var save := _camp_load()
	var cc = save.get("chapters_completed", [])
	if cc is Array and (cc as Array).size() == CAMP_CHAPTERS:
		for k in CAMP_CHAPTERS: _camp_done[k] = bool((cc as Array)[k])
	_start_campaign(int(save.get("chapter", 0)))


func _camp_restore_opts() -> void:
	if _opt_backup.is_empty(): return
	_opt_size = _opt_backup.get("size", _opt_size)
	_opt_enemies = int(_opt_backup.get("enemies", _opt_enemies))
	_opt_seed = int(_opt_backup.get("seed", _opt_seed))
	_opt_shape = str(_opt_backup.get("shape", _opt_shape))
	_opt_backup = {}


func _camp_leave() -> void:
	_camp_save(); _camp_paused = false
	if _camp_replay: _camp_restore_opts()
	_open_menu(true)


func _camp_retry() -> void:
	_start_campaign(_camp_chapter, _camp_replay)


func _camp_finish() -> void:
	for k in CAMP_CHAPTERS: _camp_done[k] = true
	_camp = false; _tut = false; _camp_paused = false; _ai_paused = false
	if tut_panel != null: tut_panel.visible = false
	_camp_restore_opts()
	_camp_save()
	_flash("Training complete. New game is unlocked.", 0)
	_layout_ui(); _fit_view()


func _camp_fire(name: String) -> void:
	if bool(_camp_events.get(name, false)): return
	_camp_events[name] = true
	match name:
		"ch4_phish":
			if _camp_relay >= 0:
				hosts[_camp_relay].steal_by = RIVAL; hosts[_camp_relay].steal_until = _t + 24.0
			_flash("A rival is phishing your relay — clear it with Incident response.", 3)


func _camp_step_done(chapter: int, step: int) -> bool:
	match chapter:
		0:
			match step:
				0: return _inspect == _camp_home or sel.has(_camp_home)
				1: return _held(PLAYER, "breach") > 0 or _lane_of(PLAYER, "breach") >= 0 or _mine(_camp_relay)
				2: return _mine(_camp_relay)
		1:
			match step:
				0: return _count_all(_camp_relay, "intel") >= 1
				1: return _count_all(_camp_relay, "bot") >= 1
				2: return _avail(PLAYER, "intel") > 40.5 or _count_all(_camp_relay, "intel") >= 2
		2:
			match step:
				0: return _known(PLAYER, "exploit")
				1: return _held(PLAYER, "exploit") > 0 or _mine(_camp_gateway)
				2: return _mine(_camp_gateway)
		3:
			match step:
				0: return _camp_practice >= 0 and int(hosts[_camp_practice].get("steal_by", -1)) == PLAYER
				1: return bool(_camp_events.get("ch4_phish", false)) and int(hosts[_camp_relay].get("steal_by", -1)) < 0
		CAMP_OPEN:
			return won
	return false


func _camp_guarded(_t2: int) -> bool: return false
func _camp_assaulted() -> bool: return false
func _camp_has_kind(kind: String) -> bool:
	for i in hosts.size():
		if _mine(i) and _count_all(i, kind) >= 1: return true
	return false
func _camp_assault_running() -> bool: return false
func _camp_card_in_flight(recipe: String) -> bool:
	for f in flights:
		if str(f.kind) == "op" and int(f.owner) == PLAYER and str(f.get("card", "")) == recipe: return true
	return false


func _camp_tick() -> void:
	if not _camp or _camp_hold_left > 0.0: return
	var step := _camp_step()
	var need := str(step.get("card", ""))
	if need != "" and not _camp_step_done(_camp_chapter, _tut_stage) and _held(PLAYER, need) <= 0 \
			and not _camp_card_in_flight(need) and _lane_of(PLAYER, need) < 0:
		_camp_supply(need); _refresh_hand()
	if _camp_chapter == 2 and _camp_gateway >= 0 and _mine(_camp_gateway) and _tut_stage < 2:
		pass
	if _camp_step_done(_camp_chapter, _tut_stage): _camp_complete_step()


func _camp_complete_step() -> void:
	if _camp_chapter == CAMP_OPEN: _camp_next(); return
	var st := _camp_step()
	if str(st.get("fire_leave", "")) != "": _camp_fire(str(st.fire_leave))
	var last := _tut_stage + 1 >= _camp_steps(_camp_chapter).size()
	if last and not _camp_replay and _camp_chapter + 1 < CAMP_CHAPTERS:
		_camp_done[_camp_chapter] = true; _camp_save_at(_camp_chapter + 1, 0)
	_camp_hold_target = _camp_target()
	_camp_hold_text = _camp_outcome()
	_camp_hold_left = CAMP_HOLD_CHAPTER if last else CAMP_HOLD_STEP
	_show_tut(); queue_redraw()


func _camp_outcome() -> String:
	return str(_camp_step().get("r", "Done."))


func _camp_next() -> void:
	var acted := _camp_acted_in_hold; _camp_acted_in_hold = false
	var steps := _camp_steps(_camp_chapter)
	if _tut_stage + 1 < steps.size():
		_tut_stage += 1
		var step: Dictionary = steps[_tut_stage]
		if str(step.get("fire", "")) != "": _camp_fire(str(step.fire))
		if bool(step.get("pause", false)) and not acted and not _camp_step_done(_camp_chapter, _tut_stage): _camp_paused = true
		var tgt := _camp_target()
		if tgt >= 0 and _mine(tgt): sel = {tgt: true}; _inspect = -1
		elif tgt >= 0: sel = {}; _inspect = tgt
		if not _camp_replay: _camp_save()
		_show_tut(); _refresh_panel()
	else:
		_camp_done[_camp_chapter] = true
		if _camp_chapter + 1 < CAMP_CHAPTERS and not _camp_replay:
			var fin := _camp_chapter + 1
			_start_campaign(fin)
			_flash("Chapter %d complete. Next: %s." % [fin, _camp_chapters()[fin]], 3)
		elif _camp_replay:
			_flash("Chapter replay complete.", 0); _camp_leave()
		else:
			_camp_finish()


func _camp_set_pause(on: bool) -> void:
	_camp_paused = on
	_show_tut()


func _camp_banner_h() -> float:   # fixed: measuring tut_box right after a rebuild reads a width-0 transient and breaks _fit_view
	return 124.0 if _camp else 90.0   # header + a 19 px instruction + a 16 px reason (room for one wrapped line)


func _camp_show() -> void:
	if tut_box == null: return
	for c in tut_box.get_children(): tut_box.remove_child(c); c.queue_free()
	var step := _camp_step()
	if step.is_empty(): return
	var chapters := _camp_chapters()
	var row := HBoxContainer.new(); tut_box.add_child(row)
	var head := "Ch %d/%d · %s — %d/%d · %s" % [_camp_chapter + 1, CAMP_CHAPTERS, chapters[_camp_chapter], _tut_stage + 1, _camp_steps(_camp_chapter).size(), str(step.t)]
	if _camp_hold_left > 0.0: head += "   ✓ done"
	elif _camp_paused: head += "   ⏸ the clock starts when you act"
	_lbl(row, head, 15, C_WARN, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := RichTextLabel.new(); body.bbcode_enabled = true; body.fit_content = true; body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # the card art is shrunk to a 16 px inline icon
	body.add_theme_font_size_override("normal_font_size", 16); body.add_theme_color_override("default_color", C_TEXT)
	body.add_theme_font_size_override("bold_font_size", 19)
	var seen := {}   # each icon only on its first mention in this banner
	# no buttons: the training can't be skipped, and doing the step is what moves it on (and starts the clock)
	var txt := "[b]%s[/b]\n[color=#9fb0c0]Why:[/color] %s" % [_tut_rich(_camp_fill(str(step.a)), seen), _tut_rich(_camp_fill(str(step.w)), seen)]
	if _camp_hold_left > 0.0:   # the result of what you just did, and what comes next
		var secs := int(ceil(_camp_hold_left))
		var steps_all := _camp_steps(_camp_chapter)
		var next := ""
		if _tut_stage + 1 < steps_all.size(): next = "Next: %s — in %d s" % [str(steps_all[_tut_stage + 1].t), secs]
		elif _camp_chapter + 1 < CAMP_CHAPTERS and not _camp_replay: next = "Chapter %d complete. Next chapter: %s — starts in %d s" % [_camp_chapter + 1, chapters[_camp_chapter + 1], secs]
		else: next = "Chapter complete — in %d s" % secs
		txt = "[b][color=#%s]✓[/color] %s[/b]\n[color=#9fb0c0]%s[/color]" % [C_GOOD.to_html(false), _tut_rich(_camp_hold_text, seen), _tut_rich(next, seen)]
	body.text = txt; tut_box.add_child(body)
	body.custom_minimum_size.x = maxf(200, get_viewport_rect().size.x - 80)
	tut_box.reset_size.call_deferred()   # a rebuilt box keeps the tall width-0 transient of its wrapped text unless shrunk back once laid out
	tut_panel.visible = _camp and not menu_open
	_layout_ui()


func _start_new_game() -> void:
	if not _camp_has_onboarded():
		_flash("Finish the guided campaign first — it unlocks New game."); return
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
func _panel_has_context() -> bool:
	return won or lost or not sel.is_empty() or _inspect >= 0


func _panel_shown() -> bool:
	return true   # a compact leaderboard fills the sidebar when no building is selected


func _refresh_panel() -> void:
	if panel_box == null: return
	if is_inside_tree() and get_viewport().gui_is_dragging(): return
	var previous_width := panel.size.x
	_refresh_top_tabs()
	var shown := _panel_shown()
	panel.visible = shown and not menu_open
	var context := "%s|%s|%d|%s|%s" % [_tab, str(sel.keys()), _inspect, str(won), str(lost)]
	var changed := context != _panel_context
	var keep := 0 if changed else _scroll_pos()
	var previous := panel_box
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 4)
	panel_box.custom_minimum_size = Vector2(_panel_width() - 44.0, 0)
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if shown:
		if won or lost: _panel_result()
		elif not sel.is_empty(): _panel_selecting()
		elif _inspect >= 0: _panel_inspect()
		else: _panel_board()

	# Reconcile text and state into existing controls. Pointer hover never
	# freezes values, and heartbeat refreshes never destroy a pressed button.
	if not changed and _same_ui_shape(previous, panel_box):
		_sync_ui(previous, panel_box)
		panel_box.free(); panel_box = previous
	else:
		panel_gutter.remove_child(previous); previous.queue_free()
		panel_gutter.add_child(panel_box)
	_panel_context = context
	_restore_scroll(keep)
	_layout_ui()
	_pan.x += (previous_width - panel.size.x) * 0.5
	if changed: _keep_target_visible()


func _same_ui_shape(a: Node, b: Node) -> bool:
	if a is SlotBox and b is SlotBox: return a.host == b.host and a.slot == b.slot
	if a.get_class() != b.get_class() or a.get_script() != b.get_script() or a.get_child_count() != b.get_child_count(): return false
	if a is OptionButton and a.selected != b.selected: return false
	if a is Button:
		var ac := a.get_signal_connection_list("pressed")
		var bc := b.get_signal_connection_list("pressed")
		if ac.size() != bc.size(): return false
		for i in ac.size():
			# Callable == ignores bound arguments: a Scan button bound to [t,"scan"] would "match" an Attack one bound to [t,"attack"]
			if ac[i].callable != bc[i].callable or ac[i].callable.get_bound_arguments() != bc[i].callable.get_bound_arguments(): return false
	for i in a.get_child_count():
		if not _same_ui_shape(a.get_child(i), b.get_child(i)): return false
	return true


func _sync_ui(a: Node, b: Node) -> void:
	if a is Control: a.custom_minimum_size = b.custom_minimum_size
	if a is SlotBox: a.queue_redraw(); return
	if a is Label or a is Button: a.text = b.text
	if a is Button: a.disabled = b.disabled
	if a is ProgressBar:
		a.value = b.value
		if b.has_theme_stylebox_override("fill"): a.add_theme_stylebox_override("fill", b.get_theme_stylebox("fill"))
	if a is Control:
		for key in ["font_color", "font_disabled_color"]:
			if b.has_theme_color_override(key): a.add_theme_color_override(key, b.get_theme_color(key))
		a.queue_redraw()
	for i in a.get_child_count(): _sync_ui(a.get_child(i), b.get_child(i))


func _panel_width() -> float:
	return PANEL_W if _panel_has_context() else LEADERBOARD_W


func _on_ui_resized() -> void:
	if is_inside_tree() and get_viewport().gui_is_dragging(): _layout_ui()
	else: _refresh_panel()
	if menu_open and _menu_view in ["mp", "lobby"]: _refresh_menu.call_deferred()   # full-window views follow the window
	elif menu_open: _fit_menu_to_contents.call_deferred()


func _layout_ui() -> void:
	if hud == null or feedback_label == null: return
	var sz := get_viewport_rect().size
	hud.position = Vector2(24, 8); hud.size = Vector2(sz.x - 260, 46)
	top_tabs.position = Vector2(sz.x - 112, 14)
	objective_label.position = Vector2(24, 62); objective_label.size = Vector2(sz.x - 48, 24)
	panel.position = Vector2(sz.x - _panel_width() - 24, (_camp_banner_h() + 74) if _tut else 64)
	var panel_bottom := sz.y - 24 if won or lost else _deck_top() - 12
	panel.size = Vector2(_panel_width(), maxf(180, panel_bottom - panel.position.y))
	if not _panel_has_context(): panel.size.y = minf(panel.size.y, 94 + botnets.size() * 60)
	panel_scroll.size = panel.size - Vector2(28, 24)
	panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	hand_bar.columns = 4
	_layout_deck()
	_refresh_hand()
	_layout_feedback_label()
	tut_panel.position = Vector2(24, 64); tut_panel.size = Vector2(sz.x - 48, _camp_banner_h())
	tut_box.position = Vector2(16, 10); tut_box.custom_minimum_size = Vector2(tut_panel.size.x - 32, 0)
	tut_box.size.x = tut_panel.size.x - 32
	tut_panel.visible = _tut and not menu_open
	for c in tut_box.get_children():
		if c is Label or c is RichTextLabel: c.custom_minimum_size.x = tut_panel.size.x - 32
	queue_redraw()


func _map_rect() -> Rect2:
	var sz := get_viewport_rect().size
	var right := sz.x - _panel_width() - 48 if _panel_shown() else sz.x - 24
	var top := (_camp_banner_h() + 74) if _tut else 100.0
	# Reserve the deck (pushed down or pulled up) while fitting a new town behind the menu too.
	var bottom := sz.y - 24 if won or lost else _deck_top() - 12
	return Rect2(24, top, maxf(200, right - 24), maxf(100, bottom - top))


func _keep_target_visible() -> void:
	var target := _inspect
	if target < 0 and sel.size() == 1: target = int(sel.keys()[0])
	if target < 0: return
	var point := _w2s(hosts[target].pos)
	var safe := _map_rect().grow(-42)
	_pan += Vector2(clampf(point.x, safe.position.x, safe.end.x), clampf(point.y, safe.position.y, safe.end.y)) - point


func _layout_feedback_label() -> void:
	if feedback_label == null: return
	feedback_label.size.x = _map_rect().size.x
	var height := feedback_label.get_combined_minimum_size().y
	feedback_label.size.y = height
	feedback_label.position = Vector2(24, _deck_top() - height - 10)


func _update_chrome(tick := true) -> void:   # tick: also repaint the deck chips (the map's slow-layer cadence)
	if objective_label == null: return
	_update_card_banks(tick)
	objective_label.visible = false
	feedback_label.visible = not menu_open and _msg_t > 0
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
		feedback_label.text = "DEFENCE · release over a highlighted host of yours." if _is_defense(_card_of(dragged)) else "ATTACK · release over a highlighted foreign host."
		if target >= 0:
			var reason := _can_play(PLAYER, dragged, target)
			var cd: Dictionary = CARDS[_card_of(dragged)]
			feedback_label.text = "%s · %s" % [str(hosts[target].name), reason if reason != "" else str(cd.lead)]
	if _mp_on and _mp_wait > 1.0 and not won and not lost:   # the lockstep holds: someone's turn is late
		var late := []
		var got: Dictionary = _mp_turns.get(_mp_turn, {})
		for fac in humans:
			if fac != PLAYER and not got.has(fac) and not (_mp_dropped.has(fac) and _mp_turn >= int(_mp_dropped[fac])): late.append(fname(fac))
		feedback_label.visible = true
		feedback_label.text = "Waiting for %s… %d s" % [", ".join(PackedStringArray(late)) if not late.is_empty() else "the other players", int(_mp_wait)]
	_layout_feedback_label()


func _refresh_top_tabs() -> void:
	if top_tabs == null: return
	if top_tabs.get_child_count() > 0: return
	var menu_button := Button.new(); menu_button.text = "Menu"
	menu_button.custom_minimum_size = Vector2(88, 36)
	menu_button.pressed.connect(_open_menu.bind(true)); top_tabs.add_child(menu_button)


func _scroll_pos() -> int:
	return panel_scroll.scroll_vertical if panel_scroll != null else 0


func _restore_scroll(v: int) -> void:
	if panel_scroll != null: panel_scroll.set_deferred("scroll_vertical", v)


func _set_tab(_t: String) -> void:
	pass   # legacy tab calls cannot open removed Research or Board menus


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


func _research_effect(key: String) -> String:   # the plain-language lead first, then the exact rules
	var card: Dictionary = CARDS[_card_of(key)]
	var lead := str(card.get("lead", ""))
	return ("%s\n\n%s" % [lead, str(card.rules)]) if lead != "" else str(card.rules)


func _card_description(key: String) -> String:
	var card: Dictionary = CARDS[_card_of(key)]
	return "%s\n%s" % [str(card.name), str(card.get("lead", card.rules))]


# A card face has room for a few lines only. It shows the lead and then as many WHOLE rule sentences as fit:
# a sentence is never cut in the middle. The full lead + rules are the card's hover tooltip.
# Text is measured as shaped paragraphs: the UI font's symbol fallback reports a 25 px line at 12 px, while a
# shaped line of the text font is ~17 px, so Font.get_height() cannot be used to count or place lines.
const CARD_TEXT_FS := 12
const CARD_TEXT_TOP := 101.0     # under the picture band's rule (95)
const CARD_TEXT_GAP := 3.0       # between the lead and the rules
const CARD_TEXT_CLEAR := 8.0     # kept above the cost row
var _blurbs := {}   # "key|width" -> [lead, rules shown, lead paragraph, rules paragraph or null]


func _card_text_room() -> float:   # the height from CARD_TEXT_TOP down to CARD_TEXT_CLEAR above the cost icons
	return CARD_DOCK_HEIGHT - 66.0 - 7.5 - CARD_TEXT_CLEAR - CARD_TEXT_TOP


func _sentences(text: String) -> Array:   # whole sentences, each with its full stop
	var out := []
	for m in RegEx.create_from_string("[^.!?]+[.!?]+").search_all(text):
		var s := m.get_string().strip_edges()
		if s != "": out.append(s)
	return out


func _para(font: Font, text: String, width: float, fs: int) -> TextParagraph:   # wrapped at word boundaries, as drawn
	var p := TextParagraph.new()
	p.add_string(text, font, fs)
	p.width = width
	return p


func _text_lines(font: Font, text: String, width: float, fs: int) -> int:
	return 0 if text == "" else _para(font, text, width, fs).get_line_count()


func _text_height(font: Font, text: String, width: float, fs: int) -> float:
	return 0.0 if text == "" else _para(font, text, width, fs).get_size().y


func _card_blurb(key: String, font: Font, width: float) -> Array:
	var id := "%s|%d" % [_card_of(key), int(width)]
	if _blurbs.has(id): return _blurbs[id]
	var card: Dictionary = CARDS[_card_of(key)]
	var lead := str(card.get("lead", ""))
	var lead_p := _para(font, lead, width, CARD_TEXT_FS)
	var room := _card_text_room() - lead_p.get_size().y - CARD_TEXT_GAP
	var rules := ""
	for s in _sentences(str(card.rules)):   # in order: a later sentence never jumps an earlier one that did not fit
		var longer: String = str(s) if rules == "" else rules + " " + str(s)
		if _text_height(font, longer, width, CARD_TEXT_FS) > room: break
		rules = longer
	_blurbs[id] = [lead, rules, lead_p, _para(font, rules, width, CARD_TEXT_FS) if rules != "" else null]
	return _blurbs[id]


func _card_tooltip(key: String) -> String:
	return "%s\n\n%s" % [str(CARDS[_card_of(key)].name), _research_effect(key)]


func _wrapped_tooltip(text: String) -> Control:   # a hover note that wraps at a readable width instead of one long line
	var note := Label.new(); note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(360, 0)
	note.add_theme_font_size_override("font_size", 13)
	return note


# read-only slot view for a building you do NOT own: shows its TYPE and the buildings already inside it,
# FOGGED until you scan it (scan is launched from the launch-pad above). Never a build palette.
func _panel_enemy_slots(i: int) -> void:
	var scanned := _scanned(PLAYER, i)
	_plabel("Installations · %d slots · security %d" % [int(hosts[i].slots), _security(i)] if scanned else "Security %d · Recon to see inside" % _security(i), 14, C_DIM)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER; row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for sl in int(hosts[i].slots):
		var ps := PeekSlot.new(); ps.game = self; ps.host = i; ps.slot = sl
		row.add_child(ps)
	panel_box.add_child(row)


func _panel_result() -> void:
	if won: _plabel("VICTORY", 20, C_GOOD)
	else: _plabel("DEFEATED", 20, C_BAD)
	if _end_cause != "": _plabel(_end_cause, 14, C_TEXT)
	_plabel("Elapsed %s  ·  hosts %d/%d  ·  town #%d" % [_fmt_time(_t), _player_nodes(), hosts.size(), town_seed], 14, C_TEXT)
	_btn("Tell us how it went", func(): _fb_status = ""; _open_menu(true); _menu_view = "feedback"; _refresh_menu())
	if _mp_on: _btn("Leave match", _mp_leave)
	elif _camp: _btn("Retry chapter", _camp_retry)
	else: _btn("Restart in a new town", _reset)


func _type_line(i: int) -> String:
	var tp: Dictionary = NODE_TYPES[str(hosts[i].get("type", "pc"))]
	var mults := ""
	for what in ["bot", "intel", "cash", "cred", "research"]:
		if float(tp.get(what, 1.0)) != 1.0: mults += " · %s ×%.1f" % [{"bot": "Bots", "intel": "Intel", "cash": "Crypto", "cred": "Creds", "research": "Research"}[what], float(tp[what])]
	return "%s · %d slots%s" % [str(tp.name), int(tp.slots), mults]


func _stage_line(i: int) -> String:
	var h: Dictionary = hosts[i]
	var tname := str(NODE_TYPES[str(h.get("type", "pc"))].name)
	if bool(h.get("junction", false)): tname += " · junction (×%d streets)" % JUNCTION_CAP_MULT
	if bool(h.get("rig", false)) and int(h.owner) != NEUTRAL: tname = "Main node · " + tname
	var sec := "security %d" % _security(i)
	if int(h.owner) == NEUTRAL: return "Neutral · %s · %s" % [sec, tname]
	if not _mine(i):
		return "%s · %s · %s" % [fname(int(h.owner)), sec, tname]
	return "%s · %d/%d slots · %s" % [sec, _standing(i), int(h.slots), tname]


func _effects_line(i: int) -> String:
	var e := []
	if _ddos_down(i): e.append("DDoS %ds" % int(ceil(float(hosts[i].ddos_until) - _t)))
	if _sabotaged(i): e.append("Sabotaged %ds" % int(ceil(float(hosts[i].sabot_until) - _t)))
	if _phished(i): e.append("Phished %ds" % int(ceil(float(hosts[i].steal_until) - _t)))
	var sp: Dictionary = hosts[i].get("siphon", {})
	if not sp.is_empty() and float(sp.get("until", 0.0)) > _t: e.append("Siphon %ds" % int(ceil(float(sp.until) - _t)))
	if float(hosts[i].get("patch_armed_until", 0.0)) > _t: e.append("Patch armed %ds" % int(ceil(float(hosts[i].patch_armed_until) - _t)))
	if float(hosts[i].get("patch_recover_until", 0.0)) > _t: e.append("Patch recover %ds" % int(ceil(float(hosts[i].patch_recover_until) - _t)))
	if float(hosts[i].get("filter_until", 0.0)) > _t: e.append("Filter %ds" % int(ceil(float(hosts[i].filter_until) - _t)))
	if float(hosts[i].get("cover_until", 0.0)) > _t: e.append("Cover %ds" % int(ceil(float(hosts[i].cover_until) - _t)))
	if float(hosts[i].get("express_until", 0.0)) > _t: e.append("Express %ds" % int(ceil(float(hosts[i].express_until) - _t)))
	for e2 in _execs:
		if int(e2.target) == i: e.append("%s executing %ds" % [str(CARDS[str(e2.card)].short), int(ceil(float(e2.ends) - _t))])
	return " · ".join(e)


func _panel_build(i: int) -> void:
	var h: Dictionary = hosts[i]
	_plabel("Installations", 16, C_TEXT)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for slot in int(h.slots):
		var box := SlotBox.new(); box.game = self; box.host = i; box.slot = slot
		box.custom_minimum_size = Vector2(112, 140); row.add_child(box)
	panel_box.add_child(row)
	# per-producer delivery state
	var prod := []
	for kv in _built(i):
		var kind := str(kv[1])
		if kind in PRODUCER_KINDS:
			var out := str(BUILD_KINDS[kind].out)
			var line := "%s → %s" % [str(BUILD_KINDS[kind].card), RES_NAME[out]]
			if _producer_paused(i, int(kv[0])): line += " · paused"
			elif _buf_slot(i, int(kv[0])) >= BUFFER_CAP - 0.5: line += " · buffer full"
			elif i != int(rig.get(PLAYER, -1)) and _buf_slot(i, int(kv[0])) >= 1.0 and _route(i, int(rig[PLAYER])).is_empty(): line += " · no route home"
			prod.append(line)
	for p in prod: _plabel(p, 12, C_DIM)
	_plabel("Build · %d s of funded work each" % int(BUILD_TIME), 16, C_TEXT)
	var palette := HBoxContainer.new(); palette.add_theme_constant_override("separation", PALETTE_GAP)
	palette.alignment = BoxContainer.ALIGNMENT_CENTER
	for kind in BUILD_KINDS:
		var card := BuildCard.new(); card.game = self; card.kind = kind
		card.custom_minimum_size = Vector2(_palette_card_w(), 140); palette.add_child(card)
	panel_box.add_child(palette)


const PALETTE_GAP := 4


func _palette_card_w() -> float:   # every building kind side by side within the sidebar's content width, never under its scrollbar
	var n := BUILD_KINDS.size()
	return floorf((PANEL_W - 44.0 - PALETTE_GAP * (n - 1)) / float(n))


func _panel_selecting() -> void:
	if sel.size() != 1:
		_plabel("%d hosts selected" % sel.size(), 20, C_TEXT)
		return
	var source := int(sel.keys()[0])
	_plabel(str(hosts[source].name), 20, C_TEXT)
	_plabel(_stage_line(source), 14, C_TEXT)
	var fx := _effects_line(source)
	if fx != "": _plabel(fx, 13, C_WARN)
	_panel_build(source)
	# support cards you can apply to this host right now
	var support := []
	for recipe in DEFENSE_ORDER:
		if _held(PLAYER, recipe) > 0: support.append(recipe)
	if not support.is_empty():
		_plabel("Apply support", 14, C_TEXT)
		var items := []
		for recipe in support: items.append([str(CARDS[recipe].name), _play_support.bind(recipe, source), true])
		_btn_row(items)
	if source == int(rig.get(PLAYER, -1)): _panel_logistics()
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


func _inset_focus(field: Control) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false; style.border_color = Color(0.45, 0.85, 1.0, 0.95)
	style.set_border_width_all(2); style.set_corner_radius_all(3)
	field.add_theme_stylebox_override("focus", style)


func _link_button_style(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 12)
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for state in ["normal", "focus", "disabled"]:
		var calm := StyleBoxEmpty.new(); calm.content_margin_left = 6; calm.content_margin_right = 6
		button.add_theme_stylebox_override(state, calm)
	for state in ["hover", "pressed"]:
		var warm := StyleBoxFlat.new()
		warm.bg_color = Color(0.3, 0.08, 0.1, 0.9); warm.border_color = C_BAD
		warm.set_border_width_all(1); warm.set_corner_radius_all(4)
		warm.content_margin_left = 6; warm.content_margin_right = 6
		button.add_theme_stylebox_override(state, warm)
	button.add_theme_color_override("font_color", C_DIM)
	for key in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: button.add_theme_color_override(key, C_BAD)


func _disconnect_source(_source: int) -> void: pass
func _do_unwire(_fac: int, _source: int) -> void: pass


const _COST_ICON := {"intel": "intel", "cash": "cash", "creds": "cred", "research": "lab", "bots": "bot"}
func _draw_cost_row(c: CanvasItem, cost: Dictionary, secs: float, at: Vector2, fs := 13, icon := 15.0, paint := true) -> float:
	var font := get_theme_default_font()
	var x := at.x
	var items := 0
	for res in ["intel", "cash", "creds", "research"]:
		if not cost.has(res) or float(cost[res]) <= 0.0: continue
		if items > 0: x += icon * 0.7
		var kind: String = _COST_ICON[res]
		var txt := str(int(cost[res]))
		if paint:
			_draw_kind_icon(c, kind, Vector2(x + icon * 0.5, at.y), icon, BUILD_KINDS[kind].col, font)
			_text(c, font, Vector2(x + icon + 3.0, at.y + fs * 0.38), txt, fs, C_TEXT)
		x += icon + 3.0 + _text_w(font, txt, fs)
		items += 1
	if secs > 0.0:
		if items > 0: x += icon * 0.7
		var t := "%ds" % int(round(secs))
		if paint:
			var r := icon * 0.42; var o := Vector2(x + icon * 0.5, at.y)
			c.draw_arc(o, r, 0.0, TAU, 20, C_DIM, 1.4, true)
			c.draw_line(o, o + Vector2(0, -r * 0.7), C_DIM, 1.4, true)
			c.draw_line(o, o + Vector2(r * 0.55, 0), C_DIM, 1.4, true)
			_text(c, font, Vector2(x + icon + 3.0, at.y + fs * 0.38), t, fs, C_DIM)
		x += icon + 3.0 + _text_w(font, t, fs)
	return x - at.x


func _panel_logistics() -> void:   # the main node's shipping controls: Bots reserve and shipping priority
	_gap(4.0)
	_plabel("Logistics", 16, C_TEXT)
	_plabel("Committed couriers: %d · reserve keeps Bots for operations" % int(committed.get(PLAYER, 0.0)), 12, C_DIM)
	var rrow := []
	for choice in BOT_RESERVE_CHOICES:
		rrow.append(["Reserve %d" % choice, _set_reserve.bind(choice), int(bot_reserve.get(PLAYER, BOT_RESERVE_DEFAULT)) != choice])
	_btn_row(rrow)
	var prow := [["Balanced", _set_priority.bind(""), str(ship_pri.get(PLAYER, "")) != ""]]
	for res in ["intel", "cash", "creds", "research"]:
		prow.append([RES_NAME[res], _set_priority.bind(res), str(ship_pri.get(PLAYER, "")) != res])
	_plabel("Shipping priority", 13, C_DIM)
	_btn_row(prow)


func _connection_list(_sources: Array) -> void: pass   # no manual connections in this model


func _panel_node_in(t: int) -> void:   # the attack launcher on a foreign host's panel
	var launchable := []
	for recipe in ATTACK_ORDER:
		if _held(PLAYER, recipe) > 0: launchable.append(recipe)
	if _chosen_attack == "" or _held(PLAYER, _chosen_attack) <= 0:
		_chosen_attack = launchable[0] if not launchable.is_empty() else ""
	if launchable.is_empty():
		_plabel("No attack cards ready — manufacture one from the deck.", 13, C_DIM)
		return
	_plabel("Launch", 16, C_TEXT)
	var chips := []
	for recipe in launchable:
		chips.append(["%s ×%d" % [str(CARDS[recipe].short), _held(PLAYER, recipe)], func(r = recipe): _chosen_attack = r; _refresh_panel(), _chosen_attack != recipe])
	_btn_row(chips)
	if _chosen_attack != "":
		var why := _can_play(PLAYER, _chosen_attack, t)
		if str(CARDS[_chosen_attack].effect) == "siphon":
			var srow := []
			for res in ["intel", "cash", "creds", "research"]:
				srow.append([RES_NAME[res], func(rr = res): _chosen_siphon_res = rr; _refresh_panel(), _chosen_siphon_res != res])
			_plabel("Siphon resource", 12, C_DIM); _btn_row(srow)
		_action_button("Launch", func(): _cmd(["card", _chosen_attack, t, _chosen_siphon_res]), null, why == "")
		if why != "": _plabel(why.capitalize(), 12, C_WARN)
		else: _plabel(str(CARDS[_chosen_attack].rules), 12, C_DIM)


func _cycle_assault_pct() -> void: pass


func _assault_progress(_t2: int, _conns: Array, _left: int, _sent: int, _total: int) -> String: return ""
func _assault_preview(_t2: int, _conns: Array) -> void: pass
func _assault_forecast(_t2: int, _conns: Array) -> String: return ""
func _operation_observation(t: int) -> String:
	var air := 0
	for f in flights:
		if str(f.kind) == "op" and int(f.owner) == PLAYER and int(f.get("target", -1)) == t: air += 1
	return "%d operation(s) inbound" % air if air > 0 else ""


func _panel_inspect() -> void:
	var i := _inspect
	if _mine(i):
		sel = {i: true}; _inspect = -1; _panel_selecting(); return
	_plabel(str(hosts[i].name), 20, C_TEXT)
	_plabel(_stage_line(i), 14, C_DIM)
	var fx := _effects_line(i)
	if fx != "": _plabel(fx, 13, C_WARN)
	if _recon_fresh(PLAYER, i):
		var rec: Dictionary = (recon.get(PLAYER, {}) as Dictionary).get(i, {})
		_plabel("Recon %ds ago" % int(_t - float(rec.get("at", _t))), 12, C_DIM)
	_panel_enemy_slots(i)
	_panel_node_in(i)


func _panel_attack_diag(t: int, _f: Array, _s: Array) -> void:
	var o := _operation_observation(t)
	if o != "": _plabel(o, 14, C_TEXT)


func _panel_idle() -> void:
	_plabel("Hold at least 51%% of the hosts for %d s to win." % int(HOLD_SECS), 16, C_TEXT)
	_gap(2.0)
	_plabel("①  Manufacture a card from the deck.", 13)
	_plabel("②  Drag an attack card onto a foreign host, or select a host to launch.", 13)
	_plabel("③  Build producers; couriers bring their output home.", 13)
	_gap(4.0)
	_plabel("Drag empty map to pan · wheel to zoom · 0 recenters", 11, C_DIM)
	_plabel("Esc menu · Space pause · C cards", 11, C_DIM)


func _panel_board() -> void:
	_plabel("Standings", 18, C_TEXT)
	_plabel("Hold %d / %d to win" % [_control_need() + 1, hosts.size()], 12, C_DIM)
	var standings := []
	for fac in botnets: standings.append([fac, _faction_nodes(fac)])
	standings.sort_custom(func(a, b): return int(a[1]) > int(b[1]) if int(a[1]) != int(b[1]) else int(a[0]) < int(b[0]))
	for index in standings.size():
		var fac := int(standings[index][0]); var count := int(standings[index][1])
		var row := HBoxContainer.new(); panel_box.add_child(row)
		var name_label := _lbl(row, "%d. %s" % [index + 1, "You" if fac == PLAYER else fname(fac)], 14, fcol(fac).lightened(0.3), 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var status := "Out" if _eliminated.has(fac) else "%d · %d%%" % [count, _control_pct(fac)]
		var hold := float(_hold.get(fac, 0.0))
		if hold > 0: status = "Holding %.0f / %.0fs" % [hold, HOLD_SECS]
		var count_label := Label.new(); count_label.text = status
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_color_override("font_color", C_WARN if hold > 0 else C_DIM)
		row.add_child(count_label)


func _control_pct(fac: int) -> int:
	return int(round(100.0 * float(_faction_nodes(fac)) / float(maxi(1, hosts.size()))))


# ---- HUD: the five banks ----
func _res_limit(res: String) -> float: return _cap(PLAYER, res)
func _res_now(res: String) -> float: return _avail(PLAYER, res)
func _res_full(res: String) -> bool: return _avail(PLAYER, res) >= _cap(PLAYER, res) - 0.5


func _hud_items() -> Array:   # [kind-icon, text, colour, column width]
	var out := []
	for res in RES:
		var kind := str({"bots": "bot", "intel": "intel", "cash": "cash", "creds": "cred", "research": "lab"}[res])
		var inc := _incoming(PLAYER, res)
		var txt := "%d/%d" % [int(_avail(PLAYER, res)), int(_cap(PLAYER, res))]
		if res == "bots" and float(committed.get(PLAYER, 0.0)) > 0.5: txt += " (+%d)" % int(committed[PLAYER])
		elif inc > 0.5: txt += " ↓%d" % int(inc)
		var col := C_WARN if _res_full(res) else C_TEXT
		out.append([kind, txt, col, 150.0])
	return out


const HUD_GAP := 10.0   # clear space kept before the next HUD column


func _hud_fs(f: Font, text: String, column: float) -> int:   # 15 px, smaller only when a large late-game number needs it
	var fs := 15
	while fs > 11 and _text_w(f, text, fs) > column - HUD_GAP: fs -= 1
	return fs


func _hud_text() -> String:
	var parts := []
	for res in RES: parts.append("%s %d/%d" % [RES_NAME[res], int(_avail(PLAYER, res)), int(_cap(PLAYER, res))])
	return "  ·  ".join(parts)


func _aim_target() -> int:
	if _dragging and _drag_from >= 0:
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and hov != _drag_from: return hov
	return _inspect


func _aim_sources() -> Array:
	return []


func _lk(a: int, b: int) -> String: return "%d_%d" % [mini(a, b), maxi(a, b)]


# ---- fog of war: ONE rule for the player's screen and for every botnet ----
# A faction sees its own hosts, every host one link away from them, and every rig. What it saw before is
# remembered (_seen: last-known owner and time); the player's map draws those as dim outlines.
func _in_sight(fac: int, i: int) -> bool:   # real sight: fac's own buildings and every building one street away
	if i < 0 or i >= hosts.size(): return false
	var h: Dictionary = hosts[i]
	if int(h.owner) == fac: return true
	for o in h.links:
		if int(hosts[int(o)].owner) == fac: return true
	return false


func _visible_to(fac: int, i: int) -> bool:   # on fac's map: real sight, plus every rig — a landmark: the rig, nothing around it
	return _in_sight(fac, i) or (i >= 0 and i < hosts.size() and bool(hosts[i].rig))


func _sight_set(fac: int) -> Dictionary:   # every host in fac's real sight -> true (packets, wires and effects need it; rigs alone are not sight)
	var out := {}
	for i in hosts.size():
		if int(hosts[i].owner) == fac:
			out[i] = true
			for o in hosts[i].links: out[int(o)] = true
	return out


func _visible_set(fac: int) -> Dictionary:   # every host fac can see right now -> true
	var out := {}
	for i in hosts.size():
		if int(hosts[i].owner) == fac:
			out[i] = true
			for o in hosts[i].links: out[int(o)] = true
		elif bool(hosts[i].rig): out[i] = true
	return out


func _refresh_sight() -> void:   # remember what every botnet sees now (cheap; on captures, eliminations and the heartbeat)
	for fac in botnets:
		var mem: Dictionary = _seen.get(fac, {})
		for i in _visible_set(fac): mem[i] = Vector2(float(hosts[i].owner), _t)
		_seen[fac] = mem


func _drop_fogged_focus() -> void:   # a foreign host that slipped into the fog cannot stay inspected
	if _inspect >= 0 and not _visible_to(PLAYER, _inspect): _inspect = -1


func _explored(fac: int, i: int) -> bool:   # seen now or before
	return _visible_to(fac, i) or (_seen.get(fac, {}) as Dictionary).has(i)


func _last_seen(fac: int, i: int) -> Dictionary:   # {"owner": last-known owner, "at": when}, or {} if never seen
	var v: Variant = (_seen.get(fac, {}) as Dictionary).get(i, null)
	if v == null: return {}
	return {"owner": int((v as Vector2).x), "at": (v as Vector2).y}


func _flight_segment(f: Dictionary, now: float) -> Vector2i:   # the two hosts a packet is between right now (equal while queued / arrived)
	var rt: Array = f.route
	var hops: Array = f.hops
	if rt.size() < 2: return Vector2i(int(rt[0]), int(rt[0]))
	for k in hops.size():
		if now < float(hops[k]): return Vector2i(int(rt[k]), int(rt[k]))
		if now < float(hops[k]) + LINK_TIME: return Vector2i(int(rt[k]), int(rt[k + 1]))
	return Vector2i(int(rt[rt.size() - 1]), int(rt[rt.size() - 1]))


func _flight_visible(fac: int, f: Dictionary) -> bool:   # a packet is seen where it travels: own, or its current street touches sight
	if int(f.owner) == fac: return true
	if str(f.kind) == "scan": return false   # a quiet scan is only ever seen by its sender
	var seg := _flight_segment(f, _t)
	return _in_sight(fac, seg.x) or _in_sight(fac, seg.y)   # a rig seen through fog shows nothing it sends


func _wire_visible(i: int) -> bool:   # a foreign wire is public only while it flows and is not a quiet scan (a guard is never a scan)
	if not bool(hosts[i].live): return false
	var a := int(hosts[i].assign)
	if a >= 0 and int(hosts[a].owner) == int(hosts[i].owner): return true
	return str(hosts[i].get("mode", "attack")) != "scan"


func _street_traffic(sight: Dictionary) -> Dictionary:   # _lk street -> packets on it right now that you can see (one pass)
	var out := {}
	for fl in flights:
		if not _flight_seen(fl, sight): continue
		var rt: Array = fl.route; var hops: Array = fl.hops
		for k in hops.size():
			if float(hops[k]) <= _t and _t < float(hops[k]) + LINK_TIME:
				var key := _lk(int(rt[k]), int(rt[k + 1]))
				out[key] = int(out.get(key, 0)) + 1
	return out


func _focus_route(rt: Array, flinks: Dictionary) -> void:
	for k in range(rt.size() - 1): flinks[_lk(int(rt[k]), int(rt[k + 1]))] = true


# the focused subgraph for host `aim`: the host itself and, for a foreign target you could attack, the
# automatic attack route from your main node (so you can see the path an operation would travel).
func _build_focus(aim: int, fnodes: Dictionary, flinks: Dictionary) -> void:
	fnodes[aim] = true
	if not _mine(aim) and rig.has(PLAYER):
		var rt := _attack_route(PLAYER, aim)
		if not rt.is_empty():
			for n in rt: fnodes[int(n)] = true
			_focus_route(rt, flinks)


func _fill_of(i: int) -> Color:
	var fac := int(hosts[i].owner)
	if fac == NEUTRAL and bool(hosts[i].hub): return Color(0.2, 0.75, 0.9)
	return fcol(fac)


func _draw() -> void:   # the game's own canvas holds only the menu backdrop; the map is painted by its MapLayer children
	_cv = self
	if menu_open: _draw_menu_bg(get_viewport_rect().size)   # the old drifting-packet backdrop; the menu panel draws on top
	_redraw_map()   # a redraw of the game is a redraw of every map layer (they paint nothing while the menu is up)


func _map_ctx() -> Dictionary:   # what the map layers share, worked out once per frame
	var frame := Engine.get_process_frames()
	if frame == _ctx_frame and not _ctx.is_empty(): return _ctx
	_ctx_frame = frame
	_hover_host = _host_at(get_local_mouse_position())  # once per frame (labels ask for it per node)
	var aim := _aim_target()
	var fnodes := {}; var flinks := {}
	if aim >= 0: _build_focus(aim, fnodes, flinks)
	_ctx = {"f": get_theme_default_font(), "vis": _visible_set(PLAYER), "sight": _sight_set(PLAYER), "seen": _seen.get(PLAYER, {}), "vt": _t + minf(_sim_acc, SIM_DT),   # fog of war: your hosts, their neighbours, every rig; + what you saw before
		"aim": aim, "focus_on": aim >= 0, "fnodes": fnodes, "flinks": flinks}   # vt: packets glide between the fixed simulation steps
	return _ctx


func _paint(c: CanvasItem, part: String) -> void:   # one MapLayer; together, in MAP_PARTS order, they paint what one big _draw did
	if menu_open: return
	_cv = c
	var cx := _map_ctx()
	match part:
		"ground": _paint_ground(cx)
		"packets": _paint_packets(cx)
		"nodes": _paint_nodes(cx)
		"over": _paint_over(cx)
		"mask": _paint_mask(cx)
	_cv = self


const ROAD_COL := Color(0.55, 0.72, 0.95, 0.24)   # a link you have used: faint, under every wire and packet
func _paint_ground(cx: Dictionary) -> void:   # territories, roads, wires
	var vis: Dictionary = cx.vis; var sight: Dictionary = cx.sight; var seen: Dictionary = cx.seen; var focus_on: bool = cx.focus_on; var fnodes: Dictionary = cx.fnodes; var flinks: Dictionary = cx.flinks
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))   # WORLD space (zoom/pan)
	_draw_territories(vis)
	# the network itself is hidden; a link you have used (connected along, sent packets over) stays drawn: your roads
	for ab in (_roads.get(PLAYER, {}) as Dictionary).values():
		_cv.draw_line(hosts[ab.x].pos, hosts[ab.y].pos, ROAD_COL, 2.0, true)
	# routes are automatic now; the focus guide in _paint_over draws the chosen attack path on demand.
	if focus_on and fnodes.size() > 0: pass


func _paint_packets(cx: Dictionary) -> void:   # packets in flight and worm jumps (they pass UNDER the buildings)
	var sight: Dictionary = cx.sight; var vt: float = cx.vt; var focus_on: bool = cx.focus_on; var fnodes: Dictionary = cx.fnodes
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))   # WORLD space (zoom/pan)
	for fl in flights:   # packets: yours = circle, other botnets = square in their colour, Cash = diamond
		if not _flight_seen(fl, sight): continue
		var pp := _packet_pos(fl, vt)
		var endn := int((fl.route as Array)[(fl.route as Array).size() - 1])
		var threat: bool = int(fl.owner) != PLAYER and _mine(endn)
		var ba: float = 1.0 if (not focus_on or fnodes.has(endn) or threat) else 0.3
		if fl.has("lost"): ba *= clampf((float(fl.arrive_t) - vt) / (0.5 * LINK_TIME), 0.0, 1.0)   # lost on the way: it fades out mid-link
		var fc := fcol(int(fl.owner))
		if str(fl.kind) == "scan":
			if int(fl.owner) == PLAYER: _cv.draw_arc(pp, 3.5, 0.0, TAU, 12, Color(0.6, 0.95, 1.0, ba), 1.5, true)   # a quiet scan: only you see it
			continue
		if str(fl.kind) == "card":   # a card in flight: its remaining path dashed in its colour (the packet itself is drawn above the buildings)
			var cc: Color = FAMILY_COL[str(CARDS[_card_of(str(fl.get("card", "phishworm:linked")))].fam)]
			var rt: Array = fl.route; var hops: Array = fl.hops
			var nxt := rt.size() - 1
			for k in hops.size():
				if vt < float(hops[k]) + LINK_TIME: nxt = k + 1; break
			var path := [pp]
			for k in range(nxt, rt.size()): path.append(hosts[int(rt[k])].pos)
			var theirs: bool = int(fl.owner) != PLAYER
			for k in range(path.size() - 1):
				if theirs and not (sight.has(int(rt[nxt + k])) and (k == 0 or sight.has(int(rt[nxt + k - 1])))): continue   # never through fog
				var a2: Vector2 = path[k]; var b2: Vector2 = path[k + 1]
				var ln := a2.distance_to(b2); var dir := (b2 - a2) / maxf(ln, 0.001); var d := 0.0
				while d < ln:
					_cv.draw_line(a2 + dir * d, a2 + dir * minf(d + 6.0, ln), Color(cc.r, cc.g, cc.b, 0.5), 1.2, true)
					d += 11.0
			continue
		if str(fl.kind) == "cash":
			var c := Color(1, 0.9, 0.3, ba) if int(fl.owner) == PLAYER else Color(fc.r, fc.g, fc.b, ba).lightened(0.3)
			_cv.draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -4), pp + Vector2(4, 0), pp + Vector2(0, 4), pp + Vector2(-4, 0)]), c)
		elif int(fl.owner) == PLAYER: _cv.draw_circle(pp, 3.5, Color(0.5, 1, 0.7, ba))
		else: _cv.draw_rect(Rect2(pp - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), Color(fc.r, fc.g, fc.b, ba).lightened(0.25), true)
	for w in _worms:   # a worm's jumps: a bold trail, a pulse racing to the newly-infected building, a ring on it
		if not (sight.has(int(w.a)) or sight.has(int(w.b))): continue
		var wa := clampf((float(w.until) - _t) / 4.0, 0.0, 1.0)
		var wc: Color = w.col
		var a_pos: Vector2 = hosts[int(w.a)].pos
		var b_pos: Vector2 = hosts[int(w.b)].pos
		_cv.draw_line(a_pos, b_pos, Color(wc.r, wc.g, wc.b, 0.28 * wa), 7.0, true)   # underglow
		_cv.draw_line(a_pos, b_pos, Color(wc.r, wc.g, wc.b, 0.95 * wa), 3.0, true)   # core
		var prog := clampf((4.0 - (float(w.until) - _t)) / 0.7, 0.0, 1.0)         # pulse races a→b in the first 0.7 s
		_cv.draw_circle(a_pos.lerp(b_pos, prog), 5.0, Color(1, 1, 1, 0.9 * wa))
		_cv.draw_arc(b_pos, _r(int(w.b)) + 5.0, 0.0, TAU, 28, Color(wc.r, wc.g, wc.b, 0.95 * wa), 2.5, true)


func _paint_nodes(cx: Dictionary) -> void:   # the buildings: pictograms, frames, bot counts, names; remembered ones as dim outlines
	var f: Font = cx.f; var vis: Dictionary = cx.vis; var seen: Dictionary = cx.seen; var aim: int = cx.aim; var focus_on: bool = cx.focus_on; var fnodes: Dictionary = cx.fnodes
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))   # WORLD space (zoom/pan)
	for i in hosts.size():   # strict fog: ONLY buildings connected to the focused one stay bright
		if vis.has(i): _draw_node(f, i, 1.0 if (not focus_on or fnodes.has(i)) else 0.6, i == aim)
		elif seen.has(i): _draw_ghost(f, i)
	_paint_names(f, vis, seen, aim, focus_on, fnodes)   # last: every name over every building, none over another


func _paint_over(cx: Dictionary) -> void:   # card packets, landing pulses, focus rings, connect / drag / card-aim guides, box select
	var f: Font = cx.f; var sight: Dictionary = cx.sight; var vt: float = cx.vt; var aim: int = cx.aim; var focus_on: bool = cx.focus_on
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))   # WORLD space (zoom/pan)
	for fl in flights:   # card packets ride above everything: a glowing card shape in the family's colour
		if str(fl.kind) != "card" or not _flight_seen(fl, sight): continue
		var pp2 := _packet_pos(fl, vt)
		var cc2: Color = FAMILY_COL[str(CARDS[_card_of(str(fl.get("card", "phishworm:linked")))].fam)]
		_cv.draw_circle(pp2, 11.0, Color(cc2.r, cc2.g, cc2.b, 0.25))
		_cv.draw_rect(Rect2(pp2 - Vector2(5.0, 7.0), Vector2(10, 14)), cc2, true)
		_cv.draw_rect(Rect2(pp2 - Vector2(5.0, 7.0), Vector2(10, 14)), Color(1, 1, 1, 0.95), false, 1.2)
	for x in _fx:   # a card landed: an expanding frame in the caster's colour
		if not sight.has(int(x.host)): continue
		var rem := clampf((float(x.until) - _t) / 3.0, 0.0, 1.0)
		var xc: Color = x.col; xc.a = rem
		_frame(hosts[int(x.host)].pos, _r(int(x.host)) + 10.0 + (1.0 - rem) * 14.0, xc, 1.5)
	if focus_on and not _mine(aim) and rig.has(PLAYER):   # the automatic attack route to the focused foreign host
		var rt := _attack_route(PLAYER, aim)
		if not rt.is_empty(): _draw_dashed(rt, Color(1, 0.95, 0.55, 0.9), 1.6)   # no route: the sidebar says so (no map note over the name)
	var dk := _dragged_card()
	if dk != "":   # a card in the air: where it can land
		var cd: Dictionary = CARDS[_card_of(dk)]
		var cc: Color = FAMILY_COL[str(cd.fam)]
		for i in hosts.size():
			if _can_play(PLAYER, dk, i) == "": _frame(hosts[i].pos, _r(i) + 7.0, Color(cc.r, cc.g, cc.b, 0.7), 2.0)
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and _can_play(PLAYER, dk, hov) == "": _frame(hosts[hov].pos, _r(hov) + 9.0, cc, 2.5)
	if _boxing:
		var ws := _s2w(_box_start)
		var r := Rect2(ws, _mouse_world() - ws).abs()
		_cv.draw_rect(r, Color(0.6, 1, 1, 0.08), true)
		_cv.draw_rect(r, Color(0.6, 1, 1, 0.6), false, 1.0, true)
	if _camp: _paint_camp_guide(f)


func _paint_camp_guide(f: Font) -> void:   # screen space: a pulsing ring on the step's target; FROM -> TARGET/PROTECT arrow while a drag is due
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var p := _camp_pulse(); var t := _camp_target()
	if t >= 0 and _visible_to(PLAYER, t): _frame(_w2s(hosts[t].pos), maxf(16.0, _r(t) * _zoom) + 16.0 + 4.0 * p, Color(C_WARN, 0.25 + 0.5 * p), 2.0)
	var s := _camp_from()
	if s < 0 or t < 0: return
	var green := Color(0.4, 1.0, 0.7)   # the reinforce-wire colour
	var a := _w2s(hosts[s].pos); var b := _w2s(hosts[t].pos)
	var sr := maxf(16.0, _r(s) * _zoom); var tr := maxf(16.0, _r(t) * _zoom)
	var dir := (b - a).normalized(); var perp := Vector2(-dir.y, dir.x)
	var p0 := a + dir * (sr + 16.0); var p1 := b - dir * (tr + 18.0); var ln := (p1 - p0).dot(dir)   # signed: close hosts never draw backwards
	if ln >= 24.0:   # room for an arrow; the FROM ring and both tags show regardless
		_cv.draw_line(p0, p1, Color(green, 0.22), 9.0, true)
		var d := fmod(_camp_clock * 40.0, 18.0)   # marching dashes toward the target
		while d < ln - 14.0:
			_cv.draw_line(p0 + dir * d, p0 + dir * minf(d + 9.0, ln - 14.0), green, 3.0, true); d += 18.0
		_cv.draw_colored_polygon(PackedVector2Array([p1, p1 - dir * 16.0 + perp * 9.0, p1 - dir * 16.0 - perp * 9.0]), green)
		_cv.draw_circle(p0.lerp(p1, fmod(_camp_clock * 0.6, 1.0)), 6.0, Color(1, 1, 1, 0.9))
	_frame(a, sr + 12.0, Color(green, 0.55 + 0.45 * p), 3.0)
	_camp_pill(f, a, sr, "FROM", green, a - b); _camp_pill(f, b, tr, "PROTECT" if _mine(t) else "TARGET", C_WARN, b - a)


func _camp_pill(f: Font, at: Vector2, r: float, txt: String, col: Color, away: Vector2) -> void:   # a tag in the first free spot: never over a name
	var w := _text_w(f, txt, 14) + 16.0
	var side := Vector2(1.0 if away.x >= 0.0 else -1.0, 0.0)   # first try the side facing away from the arrow
	var spots := [side * (r + 14.0 + w * 0.5), Vector2(0, -r - 46.0), Vector2(0, r + 50.0), -side * (r + 14.0 + w * 0.5)]
	var inside := _map_rect().grow(-4.0)
	var box := Rect2(at.x - w * 0.5, at.y - r - 57.0, w, 22.0)   # fallback: above the name
	for off in spots:
		var c: Vector2 = at + off
		var cand := Rect2(c.x - w * 0.5, c.y - 11.0, w, 22.0)
		if inside.encloses(cand) and not _camp_pill_blocked(f, cand): box = cand; break
	_cv.draw_rect(box, Color(0.03, 0.05, 0.08, 0.92), true); _cv.draw_rect(box, col, false, 2.0)
	_text(_cv, f, Vector2(box.position.x + 8.0, box.position.y + 16.0), txt, 14, col)


func _camp_pill_blocked(f: Font, box: Rect2) -> bool:   # would the tag cover a visible computer, its name or its bot count?
	for k in hosts.size():
		if not _visible_to(PLAYER, k): continue
		var q := _w2s(hosts[k].pos); var rk := maxf(16.0, _r(k) * _zoom)
		if box.intersects(Rect2(q.x - rk, q.y - rk, rk * 2.0, rk * 2.0 + 18.0)): return true                 # glyph + badge
	for r in _name_rects:
		if box.intersects((r as Rect2).grow(2.0)): return true                                                   # a placed name
	return false


func _paint_mask(cx: Dictionary) -> void:   # screen space: masks around the map, the deck backing, the end-of-match veil
	var f: Font = cx.f
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # back to SCREEN space for the overlays below
	var sz := get_viewport_rect().size
	# Mask map content outside its reserved area; controls draw above this.
	var map := _map_rect()
	var background := Color(0.04, 0.05, 0.08)
	_cv.draw_rect(Rect2(0, 0, sz.x, map.position.y - 8), background)
	if _panel_shown(): _cv.draw_rect(Rect2(map.end.x + 8, 64, sz.x - map.end.x, map.end.y - 64), background)
	if not won and not lost:   # the deck's backing: only as tall as the deck is right now
		var deck_top := _deck_top()
		_cv.draw_rect(Rect2(0, deck_top - 10, sz.x, sz.y - deck_top + 10), Color(0.025, 0.035, 0.055))
		_cv.draw_line(Vector2(24, deck_top - 6), Vector2(sz.x - 24, deck_top - 6), Color(0.2, 0.4, 0.45, 0.4))
	if won or lost:
		_cv.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.55), true)
		_text(_cv, f, Vector2((sz.x - PANEL_W) * 0.5 - 150.0, sz.y * 0.5), ("VICTORY" if won else "DEFEATED"), 46, Color(0.5, 1, 1) if won else Color(1, 0.5, 0.5))


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


func _flight_seen(fl: Dictionary, sight: Dictionary) -> bool:   # _flight_visible for the player, against this frame's _sight_set
	if int(fl.owner) == PLAYER: return true
	if str(fl.kind) == "scan": return false
	var seg := _flight_segment(fl, _t)
	return sight.has(seg.x) or sight.has(seg.y)


func _draw_ghost(f: Font, i: int) -> void:   # a host you saw before but cannot see now: a dim outline — no owner, no bots
	var p := _w2s(hosts[i].pos)
	var rr := maxf(16, _r(i) * _zoom)
	_cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_draw_type_glyph(_cv, str(hosts[i].get("type", "pc")), p, rr * 1.9, Color(0.42, 0.48, 0.58, 0.2), Color(0.04, 0.06, 0.1, 0.22))
	_cv.draw_set_transform(_pan, 0, Vector2(_zoom, _zoom))   # its dim name comes from _paint_names


# Territories: every owned building you can see claims a round patch of ground around it (TERR_RADIUS); the
# patches of one botnet melt into one rounded area, and where two botnets' patches meet the ground is split
# halfway between their buildings. Shapes are worked out once per change of sight or ownership (_terr).
const TERR_RADIUS := 0.6 * MAP_CELL   # world units a building's patch reaches
const TERR_SIDES := 32                # circle resolution
const TERR_INSET := 4.0               # two botnets' borders never sit on the same line
const TERR_SMOOTH := 0.5 * TERR_RADIUS   # how far waists between a botnet's patches are filled in (rounder blobs)


func _draw_territories(vis: Dictionary) -> void:
	var shapes := _territory_shapes(vis)
	var bw := 2.0 / maxf(_zoom, 0.3)                    # about 2 px on screen at any zoom
	for piece in shapes.fills:
		var col := fcol(int(piece[1]))
		_cv.draw_colored_polygon(piece[0], Color(col.r, col.g, col.b, 0.1 if int(piece[1]) == PLAYER else 0.07))
	for line in shapes.lines:
		var col := fcol(int(line[1]))
		_cv.draw_polyline(line[0], Color(col.r, col.g, col.b, 0.6 if int(line[1]) == PLAYER else 0.45), bw, true)


func _territory_shapes(vis: Dictionary) -> Dictionary:   # {"fills": [[polygon, owner]], "lines": [[closed outline, owner]]}
	var sites := []; var key := []
	for i in hosts.size():
		var o := int(hosts[i].owner)
		if o == NEUTRAL or not vis.has(i): continue
		sites.append(i); key.append(i * 8 + o)
	if _terr.get("key", null) == key: return _terr
	var patches := {}; var room := {}; var contested := {}   # owner -> polygons; owners with a rival in reach
	for i in sites:
		var o := int(hosts[i].owner)
		var c: Vector2 = hosts[i].pos
		var mine := [_ring(c, TERR_RADIUS)]    # the patch, cut back halfway towards every rival building
		var far := [_ring(c, TERR_RADIUS + TERR_SMOOTH)]   # what smoothing may claim: ground nearer to it than to any rival
		for j in sites:
			if int(hosts[j].owner) == o: continue
			var cj: Vector2 = hosts[j].pos
			var d := c.distance_to(cj)
			if d >= 2.0 * (TERR_RADIUS + TERR_SMOOTH): continue
			var side := _half_plane(c, cj)
			far = _clip_all(far, side); contested[o] = true
			if d < 2.0 * TERR_RADIUS: mine = _clip_all(mine, side)
		if not patches.has(o): patches[o] = []; room[o] = []
		patches[o].append_array(mine); room[o].append_array(far)
	var fills := []; var lines := []
	for o in patches:
		var area: Array = patches[o] if patches[o].size() == 1 else _smooth_area(patches[o], room[o] if contested.has(o) else [])
		if area.is_empty():   # an area with a real hole in it: the plain round patches, cut into pieces that never overlap
			for i in sites:
				if int(hosts[i].owner) != o: continue
				var piece := [_ring(hosts[i].pos, TERR_RADIUS)]
				for j in sites:
					if j != i and (hosts[i].pos as Vector2).distance_to(hosts[j].pos) < 2.0 * TERR_RADIUS: piece = _clip_all(piece, _half_plane(hosts[i].pos, hosts[j].pos))
				for p in piece: fills.append([p, o])
			var u := _union_outline(patches[o])
			for outer in u[0]:
				for inset in Geometry2D.offset_polygon(outer, -TERR_INSET, Geometry2D.JOIN_ROUND): lines.append([_closed(inset), o])
			for hole in u[1]: lines.append([_closed(hole), o])
			continue
		for p in area:
			fills.append([p, o])
			for inset in Geometry2D.offset_polygon(p, -TERR_INSET, Geometry2D.JOIN_ROUND): lines.append([_closed(inset), o])
	_terr = {"key": key, "fills": fills, "lines": lines}
	return _terr


func _smooth_area(patches: Array, room: Array) -> Array:   # the patches' union, waists and small gaps filled in, kept inside room; [] if a real hole stays
	var u := _union_outline(patches)
	for h in u[1]:   # a gap between patches closes when the area grows by TERR_SMOOTH; a bigger one is a real hole
		var gap: PackedVector2Array = h if Geometry2D.is_polygon_clockwise(h) == Geometry2D.is_polygon_clockwise(u[0][0]) else _reversed(h)
		if not Geometry2D.offset_polygon(gap, -TERR_SMOOTH, Geometry2D.JOIN_ROUND).is_empty(): return []
	var grown := []
	for o in u[0]: grown.append_array(Geometry2D.offset_polygon(o, TERR_SMOOTH, Geometry2D.JOIN_ROUND))
	var g := _union_outline(grown)
	if not g[1].is_empty(): return []
	var out := []
	for o in g[0]: out.append_array(Geometry2D.offset_polygon(o, -TERR_SMOOTH, Geometry2D.JOIN_ROUND))
	if room.is_empty(): return out   # no rival in reach: nothing to keep it away from
	var r := _union_outline(room)
	if not r[1].is_empty(): return []
	var kept := []
	for shrunk in out:
		for a in r[0]: kept.append_array(Geometry2D.intersect_polygons(shrunk, a))
	return kept


func _reversed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	out.reverse()
	return out


func _ring(c: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in TERR_SIDES: out.append(c + Vector2.from_angle(TAU * float(k) / float(TERR_SIDES)) * radius)
	return out


func _half_plane(c: Vector2, other: Vector2) -> PackedVector2Array:   # a big quad: everything on c's side of the line halfway to other
	var mid := (c + other) * 0.5
	var n := (other - c).normalized()
	var t := Vector2(-n.y, n.x) * (TERR_RADIUS * 4.0)
	var back := -n * (TERR_RADIUS * 4.0)
	return PackedVector2Array([mid + t, mid + t + back, mid - t + back, mid - t])


func _clip_all(polys: Array, keep: PackedVector2Array) -> Array:
	var out := []
	for p in polys: out.append_array(Geometry2D.intersect_polygons(p, keep))
	return out


func _union_outline(polys: Array) -> Array:   # [outer outlines, hole outlines] of the union of overlapping polygons
	var u := _union_halves(polys)
	var holes: Array = u[1]
	var left := []   # a later patch can fill part of an earlier hole
	for h in holes:
		var parts := [h]
		for p in polys:
			var cut := []
			for x in parts: cut.append_array(Geometry2D.clip_polygons(x, p))
			parts = cut
		left.append_array(parts)
	return [u[0], left]


func _union_halves(polys: Array) -> Array:   # [outers, holes]: each half merged on its own first, so no outline is re-merged many times
	if polys.size() <= 1: return [polys.duplicate(), []]
	var a := _union_halves(polys.slice(0, polys.size() >> 1))
	var b := _union_halves(polys.slice(polys.size() >> 1))
	var outers: Array = a[0]; var holes: Array = a[1] + b[1]
	for p in b[0]:
		var cur: PackedVector2Array = p
		var rest := []
		for o in outers:
			var merged := Geometry2D.merge_polygons(o, cur)
			var most := -1; var cw := false   # holes wind against the outer boundary (the polygon with the most points)
			for q in merged:
				if q.size() > most: most = q.size(); cw = Geometry2D.is_polygon_clockwise(q)
			var outs := []; var hs := []
			for q in merged: (outs if Geometry2D.is_polygon_clockwise(q) == cw else hs).append(q)
			if outs.size() == 1: cur = outs[0]; holes.append_array(hs)
			else: rest.append(o)
		rest.append(cur); outers = rest
	return [outers, holes]


func _closed(p: PackedVector2Array) -> PackedVector2Array:   # a polyline that returns to its start
	var out := p.duplicate()
	if not out.is_empty(): out.append(out[0])
	return out


func _visible_bot_count(i: int) -> String:
	return "S%d" % _security(i)


func _node_frame(i: int, margin: float, col: Color, width: float) -> void:
	_cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_frame(_w2s(hosts[i].pos), maxf(16, _r(i) * _zoom) + margin, col, width)
	_cv.draw_set_transform(_pan, 0, Vector2(_zoom, _zoom))


func _draw_node(f: Font, i: int, a: float, is_aim: bool) -> void:
	var p := _w2s(hosts[i].pos)
	var rr := maxf(16, _r(i) * _zoom)
	_cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var fill := _fill_of(i)
	fill.a = a
	var ink := Color(0.04, 0.06, 0.1, 0.9 * a)
	var focused: bool = sel.has(i) or i == _inspect or is_aim
	_draw_type_glyph(_cv, str(hosts[i].get("type", "pc")), p, rr * 1.9, fill, ink)   # the building IS its pictogram
	if bool(hosts[i].rig): _frame(p, rr + 1.0, Color(1, 1, 1, 0.8 * a), 2.0)   # a rig = Cash sink
	if bool(hosts[i].get("junction", false)): _frame(p, rr + 1.5, Color(0.75, 0.9, 1.0, 0.7 * a), 1.0)   # a junction: double traffic
	if _mine(i) and _t - float(hosts[i].get("hit_t", -100.0)) < CARD_ALARM:   # recently hit → red frame, full brightness
		_frame(p, rr + 3.0, Color(1, 0.4, 0.35, 0.95), 2.5)
	if _prod_down(i): _frame(p, rr + 4.5, Color(1, 0.62, 0.2, 0.9), 1.5)      # a card: production off
	if float(hosts[i].get("patch_until", 0.0)) > _t or float(hosts[i].get("sca_until", 0.0)) > _t: _frame(p, rr + 7.5, C_GOOD, 1.5)
	if _routing_down(i): _frame(p, rr + 10.5, Color(1, 0.35, 0.65, 0.95), 2.5)  # routing cut: outside the selection ring (rr+6) so it stays visible
	if _stolen(i): _frame(p, rr + 7.5, FAMILY_COL["phish"], 1.5)              # a Phishing campaign: production stolen
	if sel.has(i): _frame(p, rr + 6.0, Color(1, 1, 1, 0.95 * a), 2.0)
	if i == _inspect: _frame(p, rr + 8.0, Color(1, 0.9, 0.3, a), 1.5)
	if is_aim: _frame(p, rr + 9.0, Color(1, 0.9, 0.3), 2.0)
	if i == _tutorial_target() or (_tut and _tut_stage <= 3 and i == _tut_target):
		_frame(p, rr + 13, C_WARN, 3)
		if i == _tut_target: _cv.draw_circle(p + Vector2(0, -rr - 18), 5, C_WARN)
	var sec_txt := "S%d" % _security(i) if (not _mine(i)) else "%d/%d" % [_standing(i), int(hosts[i].slots)]
	var bw := _text_w(f, sec_txt, 12) + 8.0   # measured: 4 px either side of the text
	_cv.draw_rect(Rect2(p.x - bw * 0.5, p.y + rr * 0.42, bw, 16.0), Color(0.03, 0.05, 0.08, 0.88 * a), true)
	_text(_cv, f, Vector2(p.x - bw * 0.5 + 4.0, p.y + rr * 0.42 + 12.5), sec_txt, 12, Color(0.95, 0.97, 1.0, a))
	var sub := _node_sub(i, focused)   # the name is placed afterwards by _paint_names, clear of every warning line
	if str(sub[0]) != "":
		var subcol: Color = sub[1]; subcol.a *= a
		_text(_cv, f, (sub[2] as Rect2).position + Vector2(0, 12.0), str(sub[0]), 12, subcol)
	_cv.draw_set_transform(_pan, 0, Vector2(_zoom, _zoom))


func _node_sub(i: int, focused := false) -> Array:   # [text, colour, screen rect]: ONE warning under the glyph, most urgent first
	var sub := ""
	if bool(hosts[i].get("junction", false)): sub = "junction"
	if _ddos_down(i): sub = "DDoS %ds" % int(ceil(float(hosts[i].ddos_until) - _t))
	elif _sabotaged(i): sub = "SABOT %ds" % int(ceil(float(hosts[i].sabot_until) - _t))
	elif _phished(i): sub = "PHISHED %ds" % int(ceil(float(hosts[i].steal_until) - _t))
	elif not (hosts[i].get("siphon", {}) as Dictionary).is_empty() and float((hosts[i].siphon as Dictionary).get("until", 0.0)) > _t: sub = "SIPHON %ds" % int(ceil(float(hosts[i].siphon.until) - _t))
	elif float(hosts[i].get("patch_armed_until", 0.0)) > _t: sub = "PATCH"
	elif float(hosts[i].get("express_until", 0.0)) > _t: sub = "EXPRESS"
	for e in _execs:
		if int(e.target) == i: sub = "%s %ds" % [str(CARDS[str(e.card)].short).to_upper(), int(ceil(float(e.ends) - _t))]; break
	if sub == "" or not (_zoom >= 0.45 or focused or _mine(i)): return ["", Color.WHITE, Rect2()]
	var col := Color(1, 0.85, 0.4)
	if sub == "junction": col = Color(0.7, 0.85, 1.0, 0.8)
	if sub.begins_with("PHISHED") or sub.begins_with("SIPHON"): col = FAMILY_COL["phish"]
	elif sub.begins_with("DDoS") or sub.begins_with("SABOT"): col = Color(1, 0.45, 0.35)
	var p := _w2s(hosts[i].pos); var rr := maxf(16, _r(i) * _zoom)
	var sw := _text_w(get_theme_default_font(), sub, 12)
	var top := p.y + rr + (18.0 if i == _tutorial_target() else 4.0)   # clear of the campaign target frame (rr+13)
	return [sub, col, Rect2(p.x - sw * 0.5, top, sw, 15.0)]


# Host names are placed after every building is drawn: each takes the first free spot round its building
# (above, below, right, left), 2 px clear of the names already placed, of every pictogram and of every warning
# line, in priority order. A minor name with no free spot is left for hover rather than drawn over another.
var _name_rects := []   # the screen rects of the names drawn last (campaign tags keep clear of them)


func _name_rank(i: int, aim: int, vis: Dictionary) -> int:
	if sel.has(i) or i == _inspect or i == aim: return 0
	if i == _hover_host: return 1
	if _camp and (i == _camp_target() or i in [_camp_relay, _camp_gateway, _camp_practice, _camp_practice2, _camp_support]): return 2   # the lessons name them
	if not vis.has(i): return 6   # remembered, out of sight
	if bool(hosts[i].rig) and int(hosts[i].owner) != NEUTRAL: return 3
	if _mine(i): return 4
	return 5


func _paint_names(f: Font, vis: Dictionary, seen: Dictionary, aim: int, focus_on: bool, fnodes: Dictionary) -> void:
	_cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_name_rects = []
	for placed in _place_names(f, vis, seen, aim):
		var i := int(placed[0]); var rank := int(placed[2]); var pick: Rect2 = placed[1]
		var a := 0.3 if rank == 6 else (1.0 if (not focus_on or fnodes.has(i)) else 0.6)
		var col := Color(0.6, 0.66, 0.76, a) if rank == 6 else (Color(0.95, 1.0, 0.95, a) if _mine(i) else Color(0.85, 0.92, 1.0, a))
		_cv.draw_rect(pick, Color(0.03, 0.05, 0.08, 0.72 * a), true)
		_text(_cv, f, pick.position + Vector2(4.0, 13.0), str(hosts[i].name), 12, col)
		_name_rects.append(pick)
	_cv.draw_set_transform(_pan, 0, Vector2(_zoom, _zoom))


func _place_names(f: Font, vis: Dictionary, seen: Dictionary, aim: int) -> Array:   # [[host, screen rect, rank]], no drawing
	var area := _map_rect()
	var placed := []
	var order := []; var blocks := []; var ranks := {}   # blocks: [host, rect] pictograms and warning lines
	for i in hosts.size():
		if not (vis.has(i) or seen.has(i)): continue
		var p := _w2s(hosts[i].pos); var rr := maxf(16, _r(i) * _zoom)
		if not area.grow(80.0).has_point(p): continue
		order.append(i); ranks[i] = _name_rank(i, aim, vis)
		blocks.append([i, Rect2(p - Vector2.ONE * rr * 0.95, Vector2.ONE * rr * 1.9)])
		if vis.has(i):
			var sub := _node_sub(i, sel.has(i) or i == _inspect or i == aim)
			if str(sub[0]) != "": blocks.append([i, sub[2]])
	order.sort_custom(func(x, y): return int(ranks[x]) < int(ranks[y]) if int(ranks[x]) != int(ranks[y]) else int(x) < int(y))
	var taken := []
	for i in order:
		var rank := int(ranks[i])
		if _zoom < 0.45 and rank >= 5: continue   # zoomed out: only the names that matter
		var nm := str(hosts[i].name)
		if nm == "": continue
		var p := _w2s(hosts[i].pos); var rr := maxf(16, _r(i) * _zoom)
		var ring := 2.0   # clear of the selection / aim frames, and of the campaign target frame and its dot
		if rank == 0: ring = 10.0
		if i == _tutorial_target() or (_tut and i == _tut_target): ring = 24.0
		var w := _text_w(f, nm, 12) + 8.0; var h := 17.0
		var below := p.y + rr + ring + 1.0
		var own_sub := blocks.filter(func(b): return int(b[0]) == i and (b[1] as Rect2).position.y > p.y + rr * 0.9)
		if not own_sub.is_empty(): below = maxf(below, (own_sub[0][1] as Rect2).end.y + 2.0)
		var top := p.y - rr - ring - 1.0 - h; var side := rr * 0.35   # diagonal spots lean out from the corners
		var spots := [Rect2(p.x - w * 0.5, top, w, h), Rect2(p.x - w * 0.5, below, w, h),
			Rect2(p.x + rr + ring + 2.0, p.y - h * 0.5, w, h), Rect2(p.x - rr - ring - 2.0 - w, p.y - h * 0.5, w, h),
			Rect2(p.x + side, top, w, h), Rect2(p.x - side - w, top, w, h), Rect2(p.x + side, below, w, h), Rect2(p.x - side - w, below, w, h)]
		var pick := Rect2(); var least := INF
		for s in spots:
			var spot: Rect2 = s
			var clash := 0.0
			for r in taken: clash += spot.grow(2.0).intersection(r).get_area()
			for b in blocks:
				if int(b[0]) != i: clash += spot.grow(2.0).intersection(b[1]).get_area()
			if not area.encloses(spot): clash += 1e6   # under the HUD, sidebar or deck
			if clash < least: least = clash; pick = spot
			if clash == 0.0: break
		if least > 0.0 and rank >= 5: continue   # no free spot: a minor name waits for hover
		taken.append(pick); placed.append([i, pick, rank])
	return placed


func _draw_dashed(rt: Array, col := Color(1, 0.9, 0.5, 0.9), w := 1.2) -> void:   # dashed = a dormant plan
	for k in range(rt.size() - 1):
		var a: Vector2 = hosts[int(rt[k])].pos
		var b: Vector2 = hosts[int(rt[k + 1])].pos
		var ln := a.distance_to(b)
		var dir := (b - a) / maxf(ln, 0.001)
		var d := 0.0
		while d < ln:
			_cv.draw_line(a + dir * d, a + dir * minf(d + 9.0, ln), col, w, true)
			d += 15.0


# colour by the SOURCE's faction, shape by kind (defend/reinforce = diamond, attack = arrow)
func _sighted_runs(rt: Array, vis: Dictionary) -> Array:   # the stretches of a route whose every building is in sight (2+ long)
	var runs := []; var cur := []
	for n in rt:
		if vis.has(int(n)): cur.append(n); continue
		if cur.size() >= 2: runs.append(cur)
		cur = []
	if cur.size() >= 2: runs.append(cur)
	return runs


func _draw_route_line(rt: Array, src: int, tgt: int, dim := false, head := true) -> void:   # head: the arrow / diamond at tgt
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
	_cv.draw_polyline(pts, Color(col.r, col.g, col.b, 0.16 * fade), 3.2, true)
	_cv.draw_polyline(pts, Color(col.r, col.g, col.b, 0.9 * fade), 1.4, true)
	if not head: return
	var a: Vector2 = hosts[int(rt[rt.size() - 2])].pos
	var b: Vector2 = hosts[int(rt[rt.size() - 1])].pos
	var dir: Vector2 = (b - a).normalized()
	var tip: Vector2 = b - dir * (_r(tgt) + 3.0)
	var perp := Vector2(-dir.y, dir.x)
	var c := Color(col.r, col.g, col.b, 0.95 * fade)
	if reinforce:
		var ctr := tip - dir * 5.0
		_cv.draw_colored_polygon(PackedVector2Array([ctr + dir * 5.0, ctr + perp * 4.0, ctr - dir * 5.0, ctr - perp * 4.0]), c)
	else:
		_cv.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 9.0 + perp * 5.0, tip - dir * 9.0 - perp * 5.0]), c)


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
		"cash":   # Crypto token; the internal resource key remains compatible
			c.draw_circle(centre, sz * 0.46, col)
			c.draw_arc(centre, sz * 0.36, 0.0, TAU, 32, ink, sz * 0.04, true)
			_text(c, f, centre + Vector2(-sz * 0.17, sz * 0.21), "C", int(sz * 0.62), ink)
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
	_cv.draw_rect(Rect2(p - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), col, false, w)


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


# Card family glyphs use cached schematic art, with a procedural fallback.
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
		"cdn", "patch", "response", "sca":
			var shield := PackedVector2Array([centre + Vector2(-0.4, -0.4) * sz, centre + Vector2(0.4, -0.4) * sz, centre + Vector2(0.34, 0.15) * sz, centre + Vector2(0, 0.48) * sz, centre + Vector2(-0.34, 0.15) * sz])
			c.draw_colored_polygon(shield, col.darkened(0.78))
			shield.append(shield[0]); c.draw_polyline(shield, col, w * 0.6, true)
			var symbol: String = {"cdn": "x2", "patch": "+", "response": "IR", "sca": "SCA"}[str(CARDS[card].fam)]
			_text(c, f, centre + Vector2(-sz * 0.35, sz * 0.1), symbol, int(sz * 0.26), col, sz * 0.7, HORIZONTAL_ALIGNMENT_CENTER)
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
			_text(c, f, centre + Vector2(sz * 0.08, sz * 0.12), "0" if zero else "1", int(sz * 0.42), ink if zero else col)
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


class MapLayer extends Node2D:   # one slice of the map (see MAP_PARTS); the game paints it, Godot keeps it until the next repaint
	var game
	var part := ""

	func _draw() -> void:
		game._paint(self, part)


class ActionGlyph extends Control:   # operation icons also render without system-font glyphs on Web
	var action := ""
	var col := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var centre := size * 0.5
		match action:
			"Stop": draw_rect(Rect2(centre - Vector2(7, 7), Vector2(14, 14)), col)
			"Scan":
				draw_arc(centre - Vector2(2, 2), 8, 0, TAU, 32, col, 2, true)
				draw_line(centre + Vector2(4, 4), centre + Vector2(11, 11), col, 2, true)
			"Attack":
				for direction in [-1, 1]:
					draw_line(centre + Vector2(-direction * 11, 11), centre + Vector2(direction * 9, -9), col, 2, true)
					draw_line(centre + Vector2(-direction * 8, 3), centre + Vector2(-direction * 3, 8), col, 2, true)
					draw_line(centre + Vector2(direction * 9, -9), centre + Vector2(direction * 9, -3), col, 2, true)
					draw_line(centre + Vector2(direction * 9, -9), centre + Vector2(direction * 3, -9), col, 2, true)
			"Disconnect":
				draw_arc(centre - Vector2(6, 0), 6, PI * 0.35, PI * 1.65, 24, col, 2, true)
				draw_arc(centre + Vector2(6, 0), 6, -PI * 0.65, PI * 0.65, 24, col, 2, true)
				draw_line(centre + Vector2(-3, 7), centre + Vector2(3, -7), col, 2, true)
			"DeckOpen":    # the deck handle: pull the cards up
				draw_polyline(PackedVector2Array([centre + Vector2(-10, 5), centre + Vector2(0, -5), centre + Vector2(10, 5)]), col, 3, true)
			"DeckClose":   # push them back down
				draw_polyline(PackedVector2Array([centre + Vector2(-10, -5), centre + Vector2(0, 5), centre + Vector2(10, -5)]), col, 3, true)
			_:
				if action.ends_with("%"):   # the commitment: a gauge filled to that share
					var share := float(action.trim_suffix("%")) / 100.0
					draw_rect(Rect2(centre - Vector2(18, 6), Vector2(36, 12)), col, false, 1.5)
					draw_rect(Rect2(centre - Vector2(16, 4), Vector2(32.0 * minf(share, 1.0), 8)), col)   # full at 100 %: the gauge never spills out of its frame
					for k in int(round(maxf(0.0, share - 1.0) / 0.25)):   # an overcharge: one spark per +25 %
						var x := 22.0 + 6.0 * k
						draw_polyline(PackedVector2Array([centre + Vector2(x, -5), centre + Vector2(x + 4, 0), centre + Vector2(x, 5)]), col, 2.0, true)


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
			var fs: int = game._hud_fs(f, str(it[1]), float(it[3]) - (tx - x))
			game._text(self, f, Vector2(tx, 36.0), str(it[1]), fs, it[2])
			x += float(it[3])   # a fixed column: the next item never moves when this number grows





class CardTile extends Control:
	var game
	var key := "phishworm:linked"
	var stop_button: Button
	var stock_material: ShaderMaterial
	var press_position := Vector2.ZERO
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _ready() -> void:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform float saturation = 1.0; void fragment(){vec4 c=texture(TEXTURE,UV)*COLOR;float g=dot(c.rgb,vec3(0.299,0.587,0.114));COLOR=vec4(mix(vec3(g),c.rgb,saturation),c.a);}"
		stock_material = ShaderMaterial.new(); stock_material.shader = shader; material = stock_material
		var frame := CardFrame.new(); frame.tile = self   # its own material: the red / blue edge never turns gray
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(frame)
		stop_button = Button.new(); stop_button.text = "Cancel"; stop_button.name = "CancelResearch"   # a quiet link in the status row
		stop_button.focus_mode = Control.FOCUS_NONE
		game._link_button_style(stop_button)
		stop_button.pressed.connect(game._card_research_cancel.bind(key)); add_child(stop_button)
		tooltip_text = game._card_tooltip(key)   # the full lead + rules (the face shows whole sentences that fit)
	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)
	func _process(_dt: float) -> void:
		var state: Dictionary = game._card_research_state(key)
		stock_material.set_shader_parameter("saturation", 0.0 if int(state.count) == 0 else 1.0)
		stop_button.visible = bool(state.queued)
		stop_button.size = Vector2(70, 22); stop_button.position = Vector2(size.x - 14 - 70, size.y - 56)
		queue_redraw(); (get_child(0) as CanvasItem).queue_redraw()
	func _get_drag_data(_pos: Vector2) -> Variant:
		return game._card_drag_data(self, key)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: press_position = event.position
			elif Rect2(Vector2.ZERO, size).has_point(event.position) and press_position.distance_to(event.position) <= 8:
				game._card_research_click(key); accept_event()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
			game._card_research_click(key); accept_event()
	func _draw() -> void:
		var font := get_theme_default_font()
		var card: Dictionary = game.CARDS[game._card_of(key)]
		var state: Dictionary = game._card_research_state(key)
		var colour: Color = game.FAMILY_COL[str(card.fam)]
		var working := str(state.status) == "Researching"
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.075, 0.105))   # the edge is CardFrame's (red / blue)
		draw_rect(Rect2(7, 7, size.x - 14, 28), colour.darkened(0.8))
		game._text(self, font, Vector2(14, 26), str(card.name), 16, game.C_TEXT, size.x - 28, HORIZONTAL_ALIGNMENT_LEFT)
		# picture + held count in one 48 px band (41..89), a rule at 95, then the words from CARD_TEXT_TOP
		for line in 3:
			var y := 47.0 + line * 16.0
			draw_line(Vector2(82, y), Vector2(size.x - 16, y), Color(colour, 0.1))
		draw_rect(Rect2(16, 41, 56, 48), colour.darkened(0.9))
		game._draw_card_glyph(self, game._card_of(key), Vector2(44, 65), 46, colour, font)
		game._text(self, font, Vector2(90, 58), "OWNED", 10, game.C_DIM)
		game._text(self, font, Vector2(90, 84), "x%d" % int(state.count), 24, game.C_TEXT, size.x - 104, HORIZONTAL_ALIGNMENT_LEFT)
		draw_line(Vector2(14, 95), Vector2(size.x - 14, 95), Color(colour, 0.25))
		# the lead in full, then whole rule sentences only (dimmer); shaped paragraphs, so what was measured is what is drawn
		var blurb: Array = game._card_blurb(key, font, size.x - 28)
		var lead: TextParagraph = blurb[2]
		lead.draw(get_canvas_item(), Vector2(14, game.CARD_TEXT_TOP), game.C_TEXT)
		if blurb[3] != null:
			(blurb[3] as TextParagraph).draw(get_canvas_item(), Vector2(14, game.CARD_TEXT_TOP + lead.get_size().y + game.CARD_TEXT_GAP), game.C_DIM)
		# (the research price is drawn as resource icons by CardFrame, in colour)
		var status_colour: Color = Color.WHITE if working else (game.C_WARN if str(state.status) in ["Waiting", "Paused"] else game.C_TEXT)
		var status := "%s · %d%%" % [str(state.status), int(float(state.progress) * 100)] if bool(state.queued) else str(state.status)
		game._text(self, font, Vector2(14, size.y - 41), status, 13, status_colour, size.x - 110, HORIZONTAL_ALIGNMENT_LEFT)
		draw_rect(Rect2(14, size.y - 30, size.x - 28, 8), Color(0.17, 0.20, 0.26))
		draw_rect(Rect2(14, size.y - 30, (size.x - 28) * float(state.progress), 8), status_colour)
		var hint := "Click to resume" if str(state.status) == "Paused" else ("Click to pause" if bool(state.queued) else "Click to research")
		if int(state.count) > 0: hint += " · Drag to play"
		game._text(self, font, Vector2(14, size.y - 8), hint, 10, game.C_DIM, size.x - 28, HORIZONTAL_ALIGNMENT_LEFT)


class CardDragPreview extends Control:
	var game
	var key := "phishworm:linked"
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		var font := get_theme_default_font()
		var card: Dictionary = game.CARDS[game._card_of(key)]
		var colour: Color = game.FAMILY_COL[str(card.fam)]
		var defense := str(card.bank) == "defense"
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.07, 0.105))
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), game.BANK_COL[game._bank_of(key)], false, 2)
		game._draw_card_glyph(self, game._card_of(key), Vector2(28, 29), 36, colour, font)
		game._text(self, font, Vector2(56, 25), str(card.name), 12, game.C_TEXT, size.x - 64, HORIZONTAL_ALIGNMENT_LEFT)
		game._text(self, font, Vector2(56, 44), "Release on one of your hosts" if defense else "Release on a foreign host", 10, game.C_DIM, size.x - 64, HORIZONTAL_ALIGNMENT_LEFT)


class CardFrame extends Control:   # a big card's red / blue edge, drawn outside the gray-until-owned shader
	var tile
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var game = tile.game
		var state: Dictionary = game._card_research_state(tile.key)
		var bank: Color = game.BANK_COL[game._bank_of(tile.key)]
		var hot: bool = str(state.status) == "Researching" or tile.has_focus() or Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
		draw_rect(Rect2(0, 0, size.x, 4), bank)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), game.C_TEXT if hot else bank.darkened(0.1), false, 2 if hot else 1)
		game._draw_cost_row(self, game._card_cost(tile.key), game._card_time(tile.key), Vector2(14, size.y - 66))   # in colour, outside the shader


class DeckChip extends Control:   # a mini card in the pushed-down deck: click = research / pause, drag a held copy = play
	var game
	var key := "phishworm:linked"
	var press_position := Vector2.ZERO
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _ready() -> void:
		tooltip_text = game._card_tooltip(key)
	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)
	func _get_drag_data(_pos: Vector2) -> Variant:
		return game._card_drag_data(self, key)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: press_position = event.position
			elif Rect2(Vector2.ZERO, size).has_point(event.position) and press_position.distance_to(event.position) <= 8:
				game._card_research_click(key); accept_event()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT: queue_redraw()
	func _draw() -> void:
		var font := get_theme_default_font()
		var card: Dictionary = game.CARDS[game._card_of(key)]
		var state: Dictionary = game._card_research_state(key)
		var bank: Color = game.BANK_COL[game._bank_of(key)]
		var owned := int(state.count) > 0
		var working := str(state.status) == "Researching"
		var hot := working or Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.075, 0.105))
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), game.C_TEXT if hot else (bank if owned else bank.darkened(0.45)), false, 2 if hot else 1)
		var warn: bool = str(state.status) in ["Paused", "Waiting"]
		var line_col: Color = game.C_WARN if warn else (bank.lightened(0.3) if owned else game.C_DIM)
		var tint := Color(1, 1, 1, 1.0 if owned else 0.4)
		if size.x >= 84:   # wide: picture, then name over count + status
			game._draw_card_glyph(self, game._card_of(key), Vector2(18, size.y * 0.5), 32, tint, font)
			var room := size.x - 39.0
			var line := "x%d" % int(state.count)
			if bool(state.queued):
				line += {"Paused": " pause", "Waiting": " wait", "Queued": " next"}.get(str(state.status), " %d%%" % int(float(state.progress) * 100))
			if game._text_w(font, line, 11) > room: line = "x%d" % int(state.count)   # drop the status before clipping the count
			var title := str(card.get("short", card.name))
			var fs := 11 if game._text_w(font, title, 11) <= room else 10   # the whole name, never clipped
			game._text(self, font, Vector2(35, 16), title, fs, game.C_TEXT if owned else game.C_DIM, room, HORIZONTAL_ALIGNMENT_LEFT)
			game._text(self, font, Vector2(35, 31), line, 11, line_col, room, HORIZONTAL_ALIGNMENT_LEFT)
		else:   # narrow (most screens): a smaller picture and the bare count, 4 px from every edge
			var glyph := minf(24.0, size.x - 24.0)
			game._draw_card_glyph(self, game._card_of(key), Vector2(4.0 + glyph * 0.5, size.y * 0.5), glyph, tint, font)
			var count := str(int(state.count))
			var room := size.x - glyph - 12.0
			var fs := 12
			while fs > 9 and game._text_w(font, count, fs) > room: fs -= 1
			game._text(self, font, Vector2(glyph + 8.0, size.y * 0.5 + fs * 0.38), count, fs, line_col, room, HORIZONTAL_ALIGNMENT_LEFT)
		if bool(state.queued):   # research progress along the bottom edge
			draw_rect(Rect2(3, size.y - 5, (size.x - 6) * float(state.progress), 3), game.C_WARN if warn else Color.WHITE)


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
		game._text(self, f, Vector2(46, 17), str(tp.name), 13, Color(0.95, 0.97, 1.0))
		game._text(self, f, Vector2(46, 33), str(tp.desc), 12, Color(0.7, 0.8, 0.9), size.x - 50, HORIZONTAL_ALIGNMENT_LEFT)


# A building card (palette and slots share it), in fixed bands so nothing overlaps at 112 x 140:
# title 4-28 · icon 32-72 · two effect lines (88, 101) · bottom band 108-136: the price as icons (palette) or a status (slots).
const BUILD_EFFECT := {
	"bot": ["+2 Bots/s", "1 Intel each"], "intel": ["+2 Intel/s", "+50 cap"], "cash": ["+1 Crypto/s", "1 Intel each"],
	"cred": ["+1 Cred/s", "1 Intel each"], "lab": ["+1 Research/s", "1 Crypto each"], "wall": ["+1 security", "max 3"],
}
func _draw_building_card(canvas: Control, kind: String, footer: String, gray := false, show_cost := false) -> void:
	var font := canvas.get_theme_default_font()
	var w := canvas.size.x
	var colour: Color = BUILD_KINDS[kind].col if not gray else Color(0.6, 0.6, 0.6)
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.13, 0.15, 0.21) if not gray else Color(0.15, 0.15, 0.15))
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), colour, false, 2)
	canvas.draw_rect(Rect2(4, 4, w - 8, 24), colour.darkened(0.8))
	_fit_text(canvas, str(BUILD_KINDS[kind].card), Rect2(6, 21, w - 12, 0), 12, C_TEXT)
	canvas.draw_rect(Rect2(6, 32, w - 12, 40), Color(0.04, 0.05, 0.07))
	_draw_kind_icon(canvas, kind, Vector2(w * 0.5, 52), 34, colour, font)
	var lines: Array = BUILD_EFFECT[kind]
	for k in lines.size(): _fit_text(canvas, str(lines[k]), Rect2(6, 88 + k * 13, w - 12, 0), 11, C_TEXT)
	if show_cost:
		var width := _draw_cost_row(canvas, _build_cost(kind), -1.0, Vector2.ZERO, 11, 12.0, false)   # measure, then centre
		_draw_cost_row(canvas, _build_cost(kind), -1.0, Vector2((w - width) * 0.5, 121), 11, 12.0)
	elif footer != "":
		_fit_text(canvas, footer, Rect2(6, 127, w - 12, 0), 11, C_DIM)


# Text is shaped once and kept. Font.draw_string()/get_string_size() remember only the last 64 strings, and one
# frame draws more than that (names, bot counts, HUD, deck), so every call used to shape its text from scratch.
func _shape(f: Font, s: String, fs: int) -> TextLine:
	var by_size = _shaped.get(f)
	if by_size == null: by_size = {}; _shaped[f] = by_size
	var lines = by_size.get(fs)
	if lines == null: lines = {}; by_size[fs] = lines
	var tl = lines.get(s)
	if tl == null:
		if lines.size() >= 2048: lines.clear()   # countdowns and rates keep minting new strings: never grow without bound
		tl = TextLine.new(); tl.add_string(s, f, fs); lines[s] = tl
	return tl


func _text(c: CanvasItem, f: Font, pos: Vector2, s: String, fs: int, col: Color, w := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# = c.draw_string(f, pos, s, al, w, fs, col) through the cache; pos is the baseline, as for draw_string
	var tl: TextLine = _shape(f, s, fs)
	if tl.width != w: tl.width = w
	if tl.alignment != al: tl.alignment = al
	tl.draw(c.get_canvas_item(), Vector2(pos.x, pos.y - tl.get_line_ascent()), col)


func _text_w(f: Font, s: String, fs: int) -> float:   # = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return _shape(f, s, fs).get_size().x


func _fit_text(c: CanvasItem, text: String, at: Rect2, fs: int, col: Color) -> void:   # centred on at.position.y, shrunk to fit the width
	var font := get_theme_default_font()
	var size := fs
	while size > 8 and _text_w(font, text, size) > at.size.x: size -= 1
	_text(c, font, at.position, text, size, col, at.size.x, HORIZONTAL_ALIGNMENT_CENTER)


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
			if event.button_index == MOUSE_BUTTON_LEFT:
				if game.hosts[host].jobs.has(slot): game._toggle_job(host, slot)
				else: game._toggle_producer(host, slot)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_RIGHT and str(game.hosts[host].builds[slot]) != "": game._demolish(host, slot)
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			if game.hosts[host].jobs.has(slot): game._toggle_job(host, slot)
			else: game._toggle_producer(host, slot)
			accept_event()
	func _draw() -> void:
		var font := get_theme_default_font()
		var h: Dictionary = game.hosts[host]
		var job: Dictionary = h.jobs.get(slot, {})
		var kind := str(h.builds[slot])
		if not job.is_empty() and str(job.phase) == "build": kind = str(job.kind)
		if kind == "":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.17))
			draw_rect(Rect2(Vector2.ZERO, size), game.C_DIM, false, 1)
			game._text(self, font, Vector2(46, 76), "+", 28, game.C_DIM)
			return
		var footer := "" if game._slot_active(host, slot) else "Inactive"
		if kind in ["cash", "cred", "lab"]:
			if game._producer_paused(host, slot): footer = "Paused · click"
			elif game._slot_active(host, slot):
				var input := "cash" if kind == "lab" else "intel"
				footer = "Needs Crypto" if input == "cash" else "Needs Intel"
				if game._pool(int(h.owner), input) > 0.01: footer = "Click to pause"
		if not job.is_empty():
			footer = ""
			stop_button.text = "■  Paused" if bool(job.get("paused", false)) else "■  %.0fs" % float(job.left)
		game._draw_building_card(self, kind, footer, not job.is_empty())
		if not job.is_empty():
			var total: float = game.DEMOLISH_TIME if str(job.phase) == "demolish" else game.BUILD_TIME
			draw_rect(Rect2(6, 106, (size.x - 12) * (1 - float(job.left) / total), 3), Color(0.8, 0.8, 0.8))
			var short := str(job.get("short", ""))
			if str(job.phase) == "build" and not bool(job.get("paused", false)) and short != "":   # construction waits for a resource
				var price: float = float(game._job_cost_total(job).get(short, 0.0))
				var paid: float = price - float(game._job_cost_left(job).get(short, 0.0))
				var res_name: String = "Crypto" if short == "cash" else "Intel"
				draw_rect(Rect2(4, 77, size.x - 8, 28), Color(0.12, 0.07, 0.03))
				game._fit_text(self, "Needs %s" % res_name, Rect2(6, 89, size.x - 12, 0), 12, game.C_WARN)
				game._fit_text(self, "%d / %d paid" % [int(paid), int(price)], Rect2(6, 102, size.x - 12, 0), 11, game.C_TEXT)



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
			game._text(self, f, Vector2(0, baseline), "?", 26, Color(0.5, 0.6, 0.75, 0.7), size.x, HORIZONTAL_ALIGNMENT_CENTER)
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
		game._draw_building_card(self, kind, "", false, true)   # the price as resource icons


class CampSpot extends Control:   # a pulsing gold ring + pointer on the exact UI element a campaign step names (deck card, build card, panel button)
	var game
	var _scrolled := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE; z_index = 50; visible = false
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_dt: float) -> void:
		var on: bool = game._camp and not game.menu_open and not game.won and not game.lost
		if visible != on: visible = on
		if not on: return
		var ts: Array = game._camp_ui_targets()
		if not ts.is_empty() and game.panel_scroll != null and game.panel_scroll.is_ancestor_of(ts[0]) and ts[0].get_instance_id() != _scrolled:
			_scrolled = ts[0].get_instance_id(); game.panel_scroll.ensure_control_visible.call_deferred(ts[0])   # a palette card below the fold: scroll it in once
		queue_redraw()

	func _draw() -> void:
		var p: float = game._camp_pulse(); var gold: Color = game.C_WARN
		for c in game._camp_ui_targets():
			var r: Rect2 = c.get_global_rect()
			if game.panel_scroll != null and game.panel_scroll.is_ancestor_of(c): r = r.intersection(game.panel_scroll.get_global_rect())
			if r.size.x < 2.0 or r.size.y < 2.0: continue
			r.position -= global_position
			var g := 3.0 + 4.0 * p
			draw_rect(r.grow(g + 4.0), Color(gold, 0.2 + 0.25 * p), false, 7.0)
			draw_rect(r.grow(g), Color(gold, 0.55 + 0.45 * p), false, 3.0)
			var tip := Vector2(r.get_center().x, r.position.y - g - 6.0 - 6.0 * p)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-9, -12), tip + Vector2(9, -12)]), gold)


class RichIconPainter extends Control:   # draws the kind pictograms once so _bake_rich_icons can turn them into inline textures
	var game
	var kinds := []

	func _draw() -> void:
		for j in kinds: game._draw_kind_icon(self, j[0], Vector2(j[1] * 48 + 24, 24), 40.0, Color.WHITE, get_theme_default_font())
