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
const CfgMission := preload("res://scripts/botnet_cfg/mission.gd")
const HelpIllustration := preload("res://scripts/botnet_help.gd")
const AiInsane := preload("res://scripts/botnet_ai_insane.gd")   # the Insane difficulty's brain (one per AI faction)
const AI_LEVELS := ["normal", "insane"]
const INSANE_READY := false   # the Insane brain is still being built: its menu button stays disabled until it lands

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
const AI_CRYPTO_WAIT := CfgFactions.AI_CRYPTO_WAIT
const AI_ASSAULT_PCT := CfgFactions.AI_ASSAULT_PCT

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
const BUILD_COSTS := CfgBuildings.BUILD_COSTS
const BUILD_KINDS := CfgBuildings.BUILD_KINDS

const CARDS := CfgCards.CARDS
const CARD_ORDER := CfgCards.CARD_ORDER
const FAMILY_NAME := CfgCards.FAMILY_NAME
const FAMILY_COL := CfgCards.FAMILY_COL
const BANK_NAME := CfgCards.BANK_NAME
const BANK_COL := CfgCards.BANK_COL
const CARD_ALARM := CfgCards.CARD_ALARM

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
const ASSAULT_RATE := CfgTuning.ASSAULT_RATE
const REGEN_PRICE := CfgTuning.REGEN_PRICE
const RIG_FREE_REGEN := CfgTuning.RIG_FREE_REGEN
const MIS_RECORD_INTERVAL := CfgMission.RECORD_INTERVAL
const MIS_RECORD_HOME_STEP := CfgMission.RECORD_HOME_STEP
const MIS_ACCESS_SECS := CfgMission.ACCESS_SECS
const MIS_ACCESS_BASE := CfgMission.ACCESS_BASE
const MIS_ACCESS_PER_RECORD := CfgMission.ACCESS_PER_RECORD
const MIS_ACCESS_PER_SEC := CfgMission.ACCESS_PER_SEC
const MIS_ALERT_PER_RECORD := CfgMission.ALERT_PER_RECORD
const MIS_ALERT_MAX := CfgMission.ALERT_MAX
const MIS_ALERT_DECAY := CfgMission.ALERT_DECAY
const MIS_ALERT_RESPOND := CfgMission.ALERT_RESPOND
const MIS_RESPOND_COOLDOWN := CfgMission.RESPOND_COOLDOWN
const MIS_RESPOND_CUT := CfgMission.RESPOND_CUT_SECS
const MIS_SELL_CRYPTO := CfgMission.SELL_CRYPTO
const MIS_RELAY_SECS := CfgMission.RELAY_ACCESS_SECS
const ASSAULT_COMMITS := CfgTuning.ASSAULT_COMMITS
const ASSAULT_DEFAULT := CfgTuning.ASSAULT_DEFAULT
const ASSAULT_OVERCHARGE_INTEL := CfgTuning.ASSAULT_OVERCHARGE_INTEL
const LINK_TIME := CfgTuning.LINK_TIME
const NODE_ROUTE_DELAY := CfgTuning.NODE_ROUTE_DELAY
const LINK_CAP := CfgTuning.LINK_CAP
const MAX_QUEUE := CfgTuning.MAX_QUEUE
const STAGE_FULL := CfgTuning.STAGE_FULL
const STAGE_SHAKY := CfgTuning.STAGE_SHAKY
const STAGE_NAME := CfgTuning.STAGE_NAME

const PANEL_W := 620.0
const LEADERBOARD_W := 280.0
const CARD_DOCK_HEIGHT := 264.0
const CARD_DOCK_GAP := 12.0
const MAP_CELL := 190.0         # world size of one town cell; each host sits in its own cell (territories are drawn per cell)
const DECK_BAR_HEIGHT := 40.0   # the always-visible deck strip: ATTACK / DEFENCE tabs, mini cards, pull handle
const DECK_GAP := 8.0           # between the strip and the pulled-up cards
const MENU_W := 384.0           # menu panel width
const GAME_VERSION := "0.3.4"
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
var _opt_ai_level := "normal"      # the New-game difficulty: every AI faction plays at this level
var _opt_mission := false          # New-game toggle: author a "Recover the Corporate Records" objective into the town
var ai_level := {}                 # faction -> "normal" | "insane" (set from the option; probes may mix levels)
var _brains := {}                  # faction -> its Insane brain, created on its first tick
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
var paid_regen: bool = CfgTuning.PAID_REGEN   # the paid-replenishment rule (probes compare it with free regeneration)
var regen_hold := {}     # faction -> true: its paid replenishment is paused (the rig's free allowance still works)
var regen_stats := {}    # faction -> {free, paid, unfunded, crypto}: bots and Crypto of replenishment so far (accounting, UI)
var records_home := {}   # "fac:target" -> objective packets this faction has delivered home from that target
var mission_done := {}   # "fac:target" -> the resolve choice ("sell" / "publish") once a mission is completed
var _next_record := {}   # target -> absolute time its next objective packet is due while access is live
var _respond_t := {}     # target -> next time its owner may interrupt an extraction route
var assault_pause_regen: bool = CfgTuning.ASSAULT_PAUSES_REGEN   # probes compare the plain finite quota (false) with the exposure variant
var _assault_pct: int = CfgTuning.ASSAULT_DEFAULT   # the commitment the target panel's Assault button uses (UI only)
var ai_build_hook := {}            # probes: faction -> Callable(fac) that replaces that AI's build step (economy experiments)
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
var objective_label: Label
var feedback_label: Label
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
var _crypto_credit := {} # already paid production waiting for a packet; at most one packet per host
var _ai := {}          # faction -> {timer, ops:{target:{since,bots}}, avoid, dead}
var scans := {}        # faction -> {host: {"key": contents when scanned, "done": bool, "progress": bots landed}}
var creds := {}        # faction -> Credentials (pay for cards)
var research := {}     # faction -> Research points (pay for cards)
var cards := {}        # faction -> {"card:reach": count} — the hand; it accumulates without limit
var lab := {}          # faction -> {"queue": ["card:reach", …], "progress": s into the head item, "paused": bool, "stall": resource short of}
var _fx := []          # pulses on hit buildings {host, until, col}
var _worms := []       # drawn worm jumps {a, b, until, col}
var _tab := ""         # the open sidebar: "" (hidden / building context) or "board"
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
var deck_chips: HBoxContainer    # the strip's mini cards: all eight, click to research, drag to play
var deck_handle: Button          # pull the deck up / push it down
var _card_bank := "attack"
var _deck_open := false          # the deck starts pushed down: the map gets the room
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
const CAMP_CHAPTERS := 6
const CAMP_CUT_SECS := 10.0        # Ch2: how long the Gateway's retaliation cuts Support's routing
const CAMP_HOLD_STEP := 4.0        # seconds a finished step shows what it did (the game keeps running) before the next one
const CAMP_HOLD_CHAPTER := 8.0     # ... and the end of a chapter, before the board is rebuilt for the next
var _camp := false                # master flag; cleared in _reset(). _camp => _tut.
var _camp_chapter := 0            # 0..5
var _camp_paused := false         # a TRUE full-simulation pause for reading (gates _sim_step), distinct from paused/_ai_paused
var _camp_clock := 0.0            # wall clock advanced OUTSIDE the sim gate (the cues keep pulsing through the reading pause)
var _camp_replay := false         # replaying a finished chapter: don't move the resume point or completion
var _camp_done := [false, false, false, false, false, false]
var _camp_supplied := {}          # "chapter:key" -> true: a training supply granted once (idempotent)
var _camp_events := {}            # scripted-beat name -> true (armed/fired)
var _camp_cash_landed := 0        # Ch1: Crypto packets banked home since the delivery lesson began
var _camp_detect_mark := 0.0      # Ch4: records delivered at the moment the route was first cut
var _camp_cancelled := false      # Ch2: a finite assault of the player's was cancelled
var _camp_src := -1               # Ch2: the assault source being taught
var _camp_home := -1
var _camp_support := -1
var _camp_relay := -1
var _camp_gateway := -1
var _camp_vault := -1
var _camp_commrelay := -1
var _camp_rivalhq := -1
var _camp_practice := -1          # a rival practice computer for the card lessons
var _camp_practice2 := -1
var _camp_guard := -1             # Ch2: the FROM computer of the guard lesson (never the Assault source, so the next lesson can't undo it)
var _camp_foothold := -1          # Ch4: the owned neighbour of the vault that scans it
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
	sc.add_child(panel_box)
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
	hosts = []; hub = -1; rig = {}; _cell = {}; _terr = {}; _highways = {}; flights = []; _res = {}; _next_depart = {}; _next_cash = {}; _crypto_credit = {}
	intel = {}; cash = {}; _ai = {}; creds = {}; research = {}; cards = {}; lab = {}; _fx = []; _worms = []; _hold = {}; regen_hold = {}; regen_stats = {}; records_home = {}; mission_done = {}; _next_record = {}; _respond_t = {}
	for fac in botnets:
		intel[fac] = INTEL_START; cash[fac] = 0.0; scans[fac] = {}; creds[fac] = 0.0; research[fac] = 0.0
		cards[fac] = {}; lab[fac] = {"queue": [], "progress": 0.0, "paused": false, "stall": ""}; card_plays[fac] = 0; _hold[fac] = 0.0
	for fac in ais: _ai[fac] = {"timer": float(AI_PROFILE[fac].cadence) * (0.5 + 0.3 * float(fac)), "ops": {}, "avoid": -1, "dead": false, "lost": {}, "edges": {}, "threat_seen": {}}
	_brains = {}   # a new town gets fresh Insane brains (created on their first tick)
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
	for fac in botnets:   # each botnet claims its corner rig + a second building
		_claim(_cell[starts[fac][0]], fac, true, "YOUR RIG" if fac == PLAYER else "%s RIG" % fname(fac))
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


# ---- PAID REPLENISHMENT (experiment). A working rig regenerates up to RIG_FREE_REGEN bots/s free (limited by its
# own farms); every other bot actually added below a garrison's limit costs REGEN_PRICE Crypto. All of a faction's
# demand is summed first, then funded in one proportion, so no computer wins scarce Crypto by its index.
func _regen_step(i: int, dt: float) -> float:   # bots i's farms would add this step, never above its garrison limit
	var nb := _count(i, "bot")
	if nb <= 0 or _regen_paused(i): return 0.0
	var room := _cap_of(i) - float(hosts[i].bots)
	if room <= 0.0: return 0.0
	return minf(room, float(nb) * PROD_RATE * _tmult(i, "bot") * _production_multiplier(i) * dt)


func _tick_regen_paid(dt: float) -> void:
	var want := {}; var demand := {}
	for i in hosts.size():
		var o := int(hosts[i].owner)
		var add := _regen_step(i, dt)
		if add <= 0.0: continue
		if o == NEUTRAL or not botnets.has(o): hosts[i].bots = float(hosts[i].bots) + add; continue   # unowned: nobody pays
		var free := minf(add, RIG_FREE_REGEN * dt) if i == int(rig.get(o, -1)) else 0.0
		var paid := add - free
		var held := paid > 0.0 and bool(regen_hold.get(o, false))
		want[i] = [free, 0.0 if held else paid, paid if held else 0.0]
		demand[o] = float(demand.get(o, 0.0)) + (0.0 if held else paid)
	var share := {}
	for o in demand:
		var cost := float(demand[o]) * REGEN_PRICE
		share[o] = 1.0 if cost <= 0.000001 else clampf(maxf(0.0, float(cash[o])) / cost, 0.0, 1.0)
	for i in want:
		var o := int(hosts[i].owner)
		var w: Array = want[i]
		var bought := float(w[1]) * float(share.get(o, 1.0))
		hosts[i].bots = float(hosts[i].bots) + float(w[0]) + bought
		cash[o] = maxf(0.0, float(cash[o]) - bought * REGEN_PRICE)
		var st: Dictionary = regen_stats.get(o, {"free": 0.0, "paid": 0.0, "unfunded": 0.0, "held": 0.0, "crypto": 0.0})
		st.free = float(st.free) + float(w[0]); st.paid = float(st.paid) + bought; st.crypto = float(st.crypto) + bought * REGEN_PRICE
		st.unfunded = float(st.unfunded) + (float(w[1]) - bought); st.held = float(st.held) + float(w[2])
		regen_stats[o] = st


func _regen_cost_rate(fac: int) -> float:   # Crypto/s this faction's replenishment would cost right now if fully funded
	if not paid_regen or bool(regen_hold.get(fac, false)): return 0.0
	var bots := 0.0
	for i in hosts.size():
		if int(hosts[i].owner) != fac: continue
		var r := _regen_step(i, 1.0)
		if i == int(rig.get(fac, -1)): r = maxf(0.0, r - RIG_FREE_REGEN)
		bots += r
	return bots * REGEN_PRICE


func _do_regen_hold(fac: int) -> void:   # pause / resume paid replenishment (the rig's free allowance keeps working)
	regen_hold[fac] = not bool(regen_hold.get(fac, false))
	if fac == PLAYER:
		_flash("Paid bot replenishment %s" % ("paused — only Home's free %d bots/s regenerate; Crypto is saved" % int(RIG_FREE_REGEN) if bool(regen_hold[fac]) else "resumed"))
		_refresh_panel()


func _regen(i: int) -> float:   # bots/s the building regenerates (its working Bot farms × its type; 0 while its assault rests them)
	if _regen_paused(i): return 0.0
	return float(_count(i, "bot")) * PROD_RATE * _tmult(i, "bot") * _production_multiplier(i)


func _production_multiplier(i: int) -> float:
	return 2.0 if float(hosts[i].get("boost_until", 0.0)) > _t else 1.0


func _producer_paused(i: int, slot: int) -> bool:
	var paused_slots = hosts[i].get("producer_paused")   # (no throwaway {} per call: this runs for every standing slot)
	return paused_slots != null and bool((paused_slots as Dictionary).get(slot, false))


func _toggle_producer(i: int, slot: int) -> void: _cmd(["produce", i, slot])


func _do_produce(fac: int, i: int, slot: int) -> void:   # pause / resume a producer
	if not _owns(fac, i) or slot < 0 or slot >= (hosts[i].builds as Array).size(): return
	if _slot_busy(i, slot) or not str(hosts[i].builds[slot]) in ["cash", "cred", "lab"]: return
	if not hosts[i].has("producer_paused"): hosts[i].producer_paused = {}
	hosts[i].producer_paused[slot] = not _producer_paused(i, slot)
	if fac == PLAYER: _refresh_panel(); queue_redraw()


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
	return (hosts[i].builds as Array).count("bot")


func _cap_of(i: int) -> float:   # neutral: its own security; owned: NODE_CAP PER Bot farm (2 farms → 60)
	if int(hosts[i].owner) == NEUTRAL: return float(hosts[i].sec)
	return NODE_CAP * float(maxi(1, _bot_farms(i)))


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


# schedule a packet along rt departing at dep: every hop waits for room on its link (queue at the
# building), then crosses it; intermediate buildings add NODE_ROUTE_DELAY. The timeline is fixed here.
# ============================================================ NETWORK OBJECTIVE MISSION (fictional game state)
# A target computer carries records_total objective items. A faction reaches them one of two ways: capture a route
# the ordinary way, or buy TEMPORARY ACCESS (a timed status, no ownership change) and let the target stream
# objective packets home. Delivered packets are progress and raise ALERT; a high alert lets the owner cut the route.
func _setup_mission(target: int, records: int, corp := "", stake := "") -> void:   # scripts / campaign author one
	hosts[target].records_total = records
	hosts[target].corp = corp
	hosts[target].stake = stake
	hosts[target].access_until = 0.0; hosts[target].access_by = -1; hosts[target].alert = 0.0


func _is_mission(i: int) -> bool: return i >= 0 and i < hosts.size() and int(hosts[i].get("records_total", 0)) > 0


func _mkey(fac: int, target: int) -> String: return "%d:%d" % [fac, target]
func _records_got(fac: int, target: int) -> float: return float(records_home.get(_mkey(fac, target), 0.0))
func _mission_complete(fac: int, target: int) -> bool: return _is_mission(target) and _records_got(fac, target) >= float(hosts[target].records_total) - 0.001


func _access_live(fac: int, target: int) -> bool:   # this faction's temporary access to the target is in force
	return _is_mission(target) and int(hosts[target].get("access_by", -1)) == fac and float(hosts[target].get("access_until", 0.0)) > _t


func _access_cost(target: int) -> Dictionary:   # target-specific: a flat part + parts that scale with records and the type's security
	var sec := float(NODE_TYPES[str(hosts[target].get("type", "pc"))].get("sec", 0))
	var rec := float(hosts[target].get("records_total", 0))
	return {"intel": float(MIS_ACCESS_BASE.intel) + MIS_ACCESS_PER_RECORD.intel * rec,
		"creds": float(MIS_ACCESS_BASE.creds) + MIS_ACCESS_PER_RECORD.creds * rec + MIS_ACCESS_PER_SEC * maxf(0.0, sec)}


func _access_foothold(fac: int, target: int) -> int:   # a reachable owned computer to run the access from, or -1
	for i in hosts.size():
		if int(hosts[i].owner) == fac and i != target and not _route(i, target).is_empty(): return i
	return -1


func _extract_route(fac: int, target: int) -> Array:   # target → an owned neighbour → … → the faction's rig
	var home := int(rig.get(fac, -1))
	if home < 0 or int(hosts[home].owner) != fac: return []
	var best := []
	for nb in hosts[target].links:
		if int(hosts[int(nb)].owner) != fac or _routing_down(int(nb)): continue   # an isolated foothold cannot carry records
		var r := _route(int(nb), home)   # through this faction's own computers
		if r.is_empty(): continue
		var route := [target] + r
		if best.is_empty() or route.size() < best.size(): best = route
	return best


func _can_access(fac: int, target: int) -> String:   # "" if access can be bought now, else why not
	if not _is_mission(target): return "no objective here"
	if int(hosts[target].owner) == fac: return "you own this computer — records only flow through access to a computer you don't own"
	if not _scanned(fac, target): return "scan it first to find the service opening"
	if _access_foothold(fac, target) < 0: return "need one of your computers with a route to it"
	var cost := _access_cost(target)
	for r in cost:
		if _pool(fac, str(r)) < float(cost[r]) - 0.0001: return "need %s" % _res_cost_text(cost)
	return ""


func _establish_access(target: int) -> void: _cmd(["access", target])


func _do_access(fac: int, target: int) -> void:
	if not _is_mission(target) or int(hosts[target].owner) == fac: return
	if not _scanned(fac, target) or _access_foothold(fac, target) < 0:
		if fac == PLAYER: _flash("Cannot open access to %s: %s" % [str(hosts[target].name), _can_access(fac, target)])
		return
	var cost := _access_cost(target)
	for r in cost:
		if _pool(fac, str(r)) < float(cost[r]) - 0.0001:
			if fac == PLAYER: _flash("Cannot open access — it costs %s" % _res_cost_text(cost))
			return
	for r in cost: _pool_add(fac, str(r), -float(cost[r]))
	hosts[target].access_until = _t + MIS_ACCESS_SECS; hosts[target].access_by = fac
	_next_record[target] = _t
	if fac == PLAYER: _flash("Temporary access to %s for %ds — records now stream to your rig while a route holds" % [str(hosts[target].name), int(MIS_ACCESS_SECS)])
	_refresh_panel(); queue_redraw()


func _record_landed(fac: int, src: int) -> void:
	if not _is_mission(src): return
	var k := _mkey(fac, src)
	records_home[k] = minf(float(hosts[src].records_total), _records_got(fac, src) + MIS_RECORD_HOME_STEP)
	hosts[src].alert = minf(MIS_ALERT_MAX, float(hosts[src].get("alert", 0.0)) + MIS_ALERT_PER_RECORD)
	if _mission_complete(fac, src):
		hosts[src].access_until = 0.0; _next_record.erase(src)
		if fac == PLAYER: _flash("Records recovered from %s — choose: sell for Crypto, or publish to the community relay" % str(hosts[src].name), 0)
	elif fac == PLAYER:
		_flash("Records: %d / %d from %s" % [int(_records_got(fac, src)), int(hosts[src].records_total), str(hosts[src].name)], 1)
	_refresh_panel()


func _tick_mission(dt: float) -> void:
	for i in hosts.size():
		var h: Dictionary = hosts[i]
		if float(h.get("revert_at", 0.0)) > 0.0 and _t >= float(h.revert_at):   # a community relay's loan is up
			h.revert_at = 0.0
			if int(h.owner) != NEUTRAL: _capture(i, NEUTRAL)
			continue
		if not _is_mission(i): continue
		if float(h.get("alert", 0.0)) > 0.0: h.alert = maxf(0.0, float(h.alert) - MIS_ALERT_DECAY * dt)   # cools when quiet
		var fac := int(h.get("access_by", -1))
		if not _access_live(fac, i) or _eliminated.has(fac) or _mission_complete(fac, i): continue
		var rt := _extract_route(fac, i)
		if rt.size() < 2: continue                                       # no route home: extraction pauses, no catch-up
		if not _next_record.has(i): _next_record[i] = _t
		if float(_next_record[i]) > _t: continue
		if _first_wait(rt) > MAX_QUEUE: continue                         # the street is busy: wait, no backlog
		var fl := _schedule(rt, _t, fac, "record"); fl["src"] = i
		flights.append(fl)
		_next_record[i] = _t + MIS_RECORD_INTERVAL
	_mission_response(dt)
	for target in _next_record.keys():                                  # anti-backlog: a paused extractor does not accumulate
		if _next_record.has(target) and float(_next_record[target]) < _t: _next_record[target] = _t


func _mission_response(_dt: float) -> void:   # the target's owner (an AI) cuts the extraction route when its alert is high
	for target in hosts.size():
		if not _is_mission(target) or float(hosts[target].get("alert", 0.0)) < MIS_ALERT_RESPOND: continue
		var owner := int(hosts[target].owner)
		if owner == NEUTRAL or not ais.has(owner): continue        # only an AI owner responds this way
		var fac := int(hosts[target].get("access_by", -1))
		if not _access_live(fac, target): continue
		if _t < float(_respond_t.get(target, 0.0)): continue
		var rt := _extract_route(fac, target)
		if rt.size() < 2: continue
		# cut one intermediate node the extractor routes through (isolating it also stops that node's own service)
		for k in range(rt.size() - 2, 0, -1):
			var node := int(rt[k])
			if int(hosts[node].owner) == fac:
				hosts[node].route_off = maxf(float(hosts[node].get("route_off", 0.0)), MIS_RESPOND_CUT)
				hosts[node].hit_t = _t
				_respond_t[target] = _t + MIS_RESPOND_COOLDOWN
				if fac == PLAYER: _flash("%s traced the records route and isolated %s for %ds" % [fname(owner), str(hosts[node].name), int(MIS_RESPOND_CUT)], 1)
				break


func _resolve_mission(target: int, choice: String) -> void: _cmd(["resolve", target, choice])


func _do_resolve(fac: int, target: int, choice: String) -> void:
	if not _mission_complete(fac, target) or mission_done.has(_mkey(fac, target)): return
	mission_done[_mkey(fac, target)] = choice
	if choice == "sell":
		_pool_add(fac, "cash", MIS_SELL_CRYPTO)
		if fac == PLAYER: _flash("Records sold for %d Crypto — a rival now holds them" % int(MIS_SELL_CRYPTO), 0)
	elif choice == "publish":
		var relay := -1
		for i in hosts.size():
			if bool(hosts[i].get("relay", false)) and int(hosts[i].owner) != fac: relay = i; break
		if relay >= 0:   # temporary use of the community relay: timed ownership that reverts on its own
			var garrison := maxf(0.0, float(hosts[relay].bots))
			_capture(relay, fac)
			hosts[relay].bots = garrison   # its own defenders now back you (not _capture's negative overflow)
			hosts[relay].revert_at = _t + MIS_RELAY_SECS
			if fac == PLAYER: _flash("Records published — the community relay %s backs you for %ds" % [str(hosts[relay].name), int(MIS_RELAY_SECS)], 0)
		elif fac == PLAYER: _flash("Records published to the community.", 0)
	_refresh_panel(); queue_redraw()


func _res_cost_text(cost: Dictionary) -> String:
	var parts := []
	for r in ["intel", "cash", "creds", "research"]:
		if cost.has(r) and float(cost[r]) > 0.0: parts.append("%d %s" % [int(ceil(float(cost[r]))), {"intel": "Intel", "cash": "Crypto", "creds": "Credentials", "research": "Research"}[r]])
	return " + ".join(parts)


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


# every host some source could wire into — {t: true} where _link_kind(s, t) != "" for a source s — in ONE pass
# instead of a route search per (source, host) pair (that made a big selection crawl). A route leaves its
# source, then runs only through your hosts whose routing is up: those groups are labelled once.
func _wire_reach(sources: Array) -> Dictionary:
	var comp := {}; var groups := []
	for i in hosts.size():
		if comp.has(i) or not _mine(i) or _routing_down(i): continue
		var q := [i]; var head := 0; comp[i] = groups.size()
		while head < q.size():
			var c: int = q[head]; head += 1
			for o in hosts[c].links:
				if not comp.has(int(o)) and _mine(int(o)) and not _routing_down(int(o)): comp[int(o)] = groups.size(); q.append(int(o))
		groups.append(q)
	# a source reaches every street end of itself and of each group it touches. A host never wires into itself,
	# so per host keep the first source that reaches it and whether a different one does too.
	var first := {}; var multi := {}; var gfirst := {}; var gmulti := {}
	for s in sources:
		var src := int(s)
		if not _mine(src): continue
		if comp.has(src): _reach_mark(gfirst, gmulti, int(comp[src]), src, false)
		for o in hosts[src].links:
			_reach_mark(first, multi, int(o), src, false)
			if comp.has(int(o)): _reach_mark(gfirst, gmulti, int(comp[int(o)]), src, false)
	for k in gfirst:
		for c in groups[k]:
			for o in hosts[c].links: _reach_mark(first, multi, int(o), int(gfirst[k]), gmulti.has(k))
	var out := {}
	for t in first:
		if int(first[t]) != int(t) or multi.has(t): out[t] = true
	return out


func _reach_mark(first: Dictionary, multi: Dictionary, key: int, src: int, many: bool) -> void:
	if not first.has(key):
		first[key] = src
		if many: multi[key] = true
	elif many or int(first[key]) != src: multi[key] = true


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
			r += _send_rate(i) * _bot_power(i) * (ATTACK_POWER / DEFEND_POWER)   # an overcharged assault drains harder
	return r


func _drain(t: int) -> float:   # bots/s the building itself is streaming out right now
	if _bot_target(t) >= 0 and _next_depart.has(t): return _send_rate(t)
	return 0.0


# ---- control stages, buildings & the economy ----
func _stage(i: int) -> int:   # how full the garrison is: 0 stable, 1 shaky, 2 critical (informational: it switches nothing off)
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


func _standing(i: int) -> int:   # = _built(i).size(), without building the list
	var n := 0
	var b: Array = hosts[i].builds; var jobs: Dictionary = hosts[i].jobs
	for k in b.size():
		if str(b[k]) != "" and not jobs.has(k): n += 1
	return n


func _active_slots(i: int) -> int:   # every standing building works: losing bots never switches a building off
	return _standing(i)


func _slot_active(i: int, k: int) -> bool:   # is the building in slot k among the ones still working?
	if _prod_down(i): return false              # a card switched the whole building off
	if _producer_paused(i, k): return false
	var bl := _built(i); var act := _active_slots(i)
	for idx in bl.size():
		if int(bl[idx][0]) == k: return idx < act
	return false


func _count(i: int, kind: String) -> int:   # ACTIVE buildings of a kind (none while a card has production switched off)
	if _prod_down(i): return 0
	var b: Array = hosts[i].builds
	if not b.has(kind): return 0   # the common case: nothing of that kind here at all
	var jobs: Dictionary = hosts[i].jobs
	var n := 0
	for k in b.size():   # every standing one (a slot under construction is offline), unless its owner paused it
		if str(b[k]) == kind and not jobs.has(k) and not _producer_paused(i, k): n += 1
	return n


func _count_all(i: int, kind: String) -> int:   # built, active or not
	return (hosts[i].builds as Array).count(kind)


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
		if _benef(i) == fac: r += float(_count(i, "cred")) * CRED_PER_BUILD * _tmult(i, "cred") * _production_multiplier(i)
	return r


func _research_rate(fac: int) -> float:
	var r := 0.0
	for i in hosts.size():
		if _benef(i) == fac: r += float(_count(i, "lab")) * RESEARCH_PER_BUILD * _tmult(i, "research") * _production_multiplier(i)
	return r


func _kind_total(fac: int, kind: String) -> int:   # buildings of a kind a faction has built anywhere
	var n := 0
	for i in hosts.size():
		if int(hosts[i].owner) == fac: n += _count_all(i, kind)
	return n


func _pool(fac: int, r: String) -> float:   # "cash" | "creds" | "research"
	match r:
		"intel": return float(intel[fac])
		"cash": return float(cash[fac])
		"creds": return float(creds[fac])
		_: return float(research[fac])


func _pool_add(fac: int, r: String, d: float) -> void:   # add to (or spend from) a resource pool, clamped to its cap
	match r:
		"intel": intel[fac] = float(intel[fac]) + d
		"cash": cash[fac] = float(cash[fac]) + d
		"creds": creds[fac] = float(creds[fac]) + d
		_: research[fac] = float(research[fac]) + d


func _intel_rate(fac: int) -> float:   # harvesters, plus the rig's own trickle while the botnet still holds it
	var r := 0.0
	for i in hosts.size():
		if not (hosts[i].builds as Array).has("intel"): continue   # adds exactly 0 — skip the work
		if _benef(i) == fac: r += float(_count(i, "intel")) * INTEL_PER_BUILD * _tmult(i, "intel") * _production_multiplier(i)
	for owner in botnets:
		var home := int(rig.get(owner, -1))
		if home >= 0 and int(hosts[home].owner) == int(owner) and _benef(home) == fac and not _prod_down(home): r += RIG_INTEL * _production_multiplier(home)
	return r


func _tick_intel(dt: float) -> void:   # every botnet's Intel income and limit in one pass (= _intel_rate / _intel_cap, same order)
	var rate := {}; var harvesters := {}
	for fac in botnets: rate[fac] = 0.0; harvesters[fac] = 0
	for i in hosts.size():
		var b: Array = hosts[i].builds
		if not b.has("intel"): continue
		var o := int(hosts[i].owner)
		if harvesters.has(o): harvesters[o] = int(harvesters[o]) + b.count("intel")
		var to := _benef(i)
		if rate.has(to): rate[to] = float(rate[to]) + float(_count(i, "intel")) * INTEL_PER_BUILD * _tmult(i, "intel") * _production_multiplier(i)
	for fac in botnets:
		var r: float = rate[fac]
		for owner in botnets:
			var home := int(rig.get(owner, -1))
			if home >= 0 and int(hosts[home].owner) == int(owner) and _benef(home) == fac and not _prod_down(home): r += RIG_INTEL * _production_multiplier(home)
		intel[fac] = minf(INTEL_CAP_BASE + INTEL_CAP_PER_BUILD * float(harvesters[fac]), float(intel[fac]) + r * dt)


func _cash_rate(fac: int) -> float:   # Cash/s a faction's active markets emit (a stolen market feeds the thief)
	var r := 0.0
	for i in hosts.size():
		if _benef(i) == fac: r += _cash_of_host(i)
	return r


func _cash_of_host(i: int) -> float:   # Cash/s this one market produces
	return float(_count(i, "cash")) * float(hosts[i].value) * _tmult(i, "cash") / CASH_INTERVAL * _production_multiplier(i)


func _crypto_packet_amount(i: int) -> float:
	return float(hosts[i].value) * _tmult(i, "cash") * (1.0 if _is_human(int(hosts[i].owner)) else ai_cash_mult)


func _production_input_rate(fac: int, input: String) -> float:
	var total := 0.0
	for i in hosts.size():
		if int(hosts[i].owner) != fac: continue
		if input == "intel":
			total += _cash_of_host(i) * (ai_cash_mult if fac != PLAYER else 1.0)
			total += float(_count(i, "cred")) * CRED_PER_BUILD * _tmult(i, "cred") * _production_multiplier(i)
		else: total += float(_count(i, "lab")) * RESEARCH_PER_BUILD * _tmult(i, "research") * _production_multiplier(i)
	return total


func _tick_production(dt: float) -> void:
	# Budget all outputs before spending: scarce inputs and destination capacity
	# are shared proportionally, independent of host order. Each output costs one input.
	# Pools are keyed faction * 4 + (0 Intel, 1 Crypto, 2 Credentials, 3 Research).
	var candidates := []; var cap_demand := {}; var input_demand := {}; var budget := {}
	for fac in botnets:
		budget[fac * 4] = maxf(0.0, float(intel[fac]) - _attack_reserve(fac))
		budget[fac * 4 + 1] = maxf(0.0, float(cash[fac]))
	for i in hosts.size():
		var b: Array = hosts[i].builds
		if not (b.has("cash") or b.has("cred") or b.has("lab")): continue   # no producer here: no candidate
		var owner := int(hosts[i].owner); var beneficiary := _benef(i)
		if owner == NEUTRAL or not botnets.has(beneficiary) or _eliminated.has(owner): continue
		for kind in ["cash", "cred", "lab"]:
			var n := _count(i, kind)
			if n <= 0: continue
			var output := "cash" if kind == "cash" else ("creds" if kind == "cred" else "research")
			var input := "cash" if kind == "lab" else "intel"
			var amount := 0.0
			if kind == "cash":
				amount = float(n) * float(hosts[i].value) * _tmult(i, "cash") / CASH_INTERVAL * _production_multiplier(i) * (1.0 if _is_human(owner) else ai_cash_mult) * dt   # = _cash_of_host(i) * …
				if not _stolen(i):
					if not rig.has(owner) or int(hosts[int(rig[owner])].owner) != owner: continue
					if i != int(rig[owner]) and _route(i, int(rig[owner])).is_empty(): continue
					amount = minf(amount, maxf(0.0, _crypto_packet_amount(i) - float(_crypto_credit.get(i, 0.0))))
			else:
				amount = float(n) * (CRED_PER_BUILD if kind == "cred" else RESEARCH_PER_BUILD) * _tmult(i, "cred" if kind == "cred" else "research") * _production_multiplier(i) * dt
			var cap_key := beneficiary * 4 + (1 if kind == "cash" else (2 if kind == "cred" else 3))
			cap_demand[cap_key] = float(cap_demand.get(cap_key, 0.0)) + amount
			candidates.append({"host": i, "owner": owner, "beneficiary": beneficiary, "kind": kind, "output": output, "input_key": owner * 4 + (1 if kind == "lab" else 0), "input": input, "cap_key": cap_key, "amount": amount})
	var built := {}   # faction * 4 + 2 (cred) / 3 (lab) -> buildings of that kind it owns: _res_cap's count, one pass for all
	if not candidates.is_empty():
		for h in hosts:
			var o := int(h.owner)
			if o == NEUTRAL: continue
			var hb: Array = h.builds
			built[o * 4 + 2] = int(built.get(o * 4 + 2, 0)) + hb.count("cred")
			built[o * 4 + 3] = int(built.get(o * 4 + 3, 0)) + hb.count("lab")
	for candidate in candidates:
		if candidate.kind != "cash":
			var cap := RES_CAP_BASE + RES_CAP_PER_BUILD * float(built.get(int(candidate.cap_key), 0))   # = _res_cap(beneficiary, kind)
			var room := maxf(0.0, cap - _pool(int(candidate.beneficiary), str(candidate.output)))
			candidate.amount *= minf(1.0, room / maxf(0.000001, float(cap_demand[candidate.cap_key])))
		input_demand[candidate.input_key] = float(input_demand.get(candidate.input_key, 0.0)) + float(candidate.amount)
	for candidate in candidates:
		var amount := float(candidate.amount) * minf(1.0, float(budget[candidate.input_key]) / maxf(0.000001, float(input_demand[candidate.input_key])))
		if amount <= 0.0: continue
		_pool_add(int(candidate.owner), str(candidate.input), -amount)
		var i := int(candidate.host)
		if candidate.kind == "cash" and not _stolen(i): _crypto_credit[i] = float(_crypto_credit.get(i, 0.0)) + amount
		else: _pool_add(int(candidate.beneficiary), str(candidate.output), amount)
	for fac in botnets: # floating point roundoff must never leave negative resources
		intel[fac] = maxf(0.0, float(intel[fac])); cash[fac] = maxf(0.0, float(cash[fac]))


# one job per building. Into an EMPTY slot: build (BUILD_TIME). Onto an OCCUPIED slot: replace — the old
# building goes offline at once, the slot is cleared (DEMOLISH_TIME), then the new one is built (BUILD_TIME).
func _start_job(i: int, kind: String, slot := -1) -> bool:   # several jobs may run in one building; funding is shared over time, after attack packets
	if i < 0 or int(hosts[i].owner) == NEUTRAL or not BUILD_KINDS.has(kind): return false
	if slot < 0: slot = _free_slot(i)
	if slot < 0 or slot >= (hosts[i].builds as Array).size() or _slot_busy(i, slot): return false
	var cur := str(hosts[i].builds[slot])
	if cur == kind: return false
	var fac := int(hosts[i].owner)
	if not _can_afford_build(fac, kind): return false   # must be able to afford it, but it's PAID OVER THE BUILD
	(hosts[i].get("producer_paused", {}) as Dictionary).erase(slot)
	var price := _build_cost(kind)
	if cur == "": hosts[i].jobs[slot] = {"kind": kind, "slot": slot, "phase": "build", "left": BUILD_TIME, "cost_left": price.duplicate(), "cost_total": price.duplicate()}
	else: hosts[i].jobs[slot] = {"kind": kind, "slot": slot, "phase": "demolish", "left": DEMOLISH_TIME, "cost_left": price.duplicate(), "cost_total": price.duplicate()}
	return true


func _build_cost(kind: String) -> Dictionary:   # {pool: amount} — e.g. a Research lab: {"intel": 50, "cash": 25}
	return BUILD_COSTS.get(kind, {"intel": BUILD_COST_INTEL})


func _can_afford_build(fac: int, kind: String) -> bool:
	var price := _build_cost(kind)
	for res in price:
		if _pool(fac, str(res)) < float(price[res]) - 0.0001: return false
	return true


func _build_cost_text(kind: String) -> String:   # "50 Intel + 25 Crypto"
	var parts := []
	var price := _build_cost(kind)
	for res in ["intel", "cash"]:
		if price.has(res): parts.append("%d %s" % [int(price[res]), "Intel" if res == "intel" else "Crypto"])
	return " + ".join(parts)


func _job_cost_left(job: Dictionary) -> Dictionary:   # what a job still has to pay; older float records mean Intel
	var left: Variant = job.get("cost_left", {})
	if not (left is Dictionary):
		left = {"intel": float(left)}; job["cost_left"] = left
	return left


func _job_cost_total(job: Dictionary) -> Dictionary:
	var total: Variant = job.get("cost_total", null)
	if total is Dictionary: return total
	return _build_cost(str(job.get("kind", "")))


func _can_drop(i: int, slot: int, kind: String) -> bool:   # a card held over a slot of a building you own
	return _can_build(PLAYER, i, slot, kind)


func _can_build(fac: int, i: int, slot: int, kind: String) -> bool:
	if not _owns(fac, i) or not BUILD_KINDS.has(kind): return false
	if slot < 0 or slot >= (hosts[i].builds as Array).size() or _slot_busy(i, slot): return false
	return str(hosts[i].builds[slot]) != kind


func _drop_build(i: int, slot: int, kind: String) -> void: _cmd(["build", i, slot, kind])   # a card dropped on a slot


func _do_build(fac: int, i: int, slot: int, kind: String) -> void:
	if not _can_build(fac, i, slot, kind): return
	var cur := str(hosts[i].builds[slot])
	var started := _start_job(i, kind, slot)
	if fac != PLAYER: return
	if started:
		if cur == "": _flash("Building %s in slot %d of %s — %.0f s · %s" % [BUILD_KINDS[kind].name, slot + 1, str(hosts[i].name), BUILD_TIME, _build_cost_text(kind)])
		else: _flash("Replacing %s with %s in slot %d — %.0f s to clear, then %.0f s to build · %s" % [BUILD_KINDS[cur].name, BUILD_KINDS[kind].name, slot + 1, DEMOLISH_TIME, BUILD_TIME, _build_cost_text(kind)])
	elif not _can_afford_build(fac, kind):
		var price := _build_cost(kind)
		var hint := ""
		if float(price.get("cash", 0.0)) > float(cash[fac]) + 0.0001: hint = " · you have %d Crypto — Crypto miners make it" % int(cash[fac])
		elif float(price.get("intel", 0.0)) > float(intel[fac]) + 0.0001: hint = " · you have %d Intel" % int(intel[fac])
		_flash("Not enough to build a %s — it costs %s%s" % [BUILD_KINDS[kind].name, _build_cost_text(kind), hint])
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


func _toggle_job(i: int, slot: int) -> void: _cmd(["job", i, slot])


func _do_toggle_job(fac: int, i: int, slot: int) -> void:
	if not _owns(fac, i) or not (hosts[i].jobs as Dictionary).has(slot): return
	var job: Dictionary = hosts[i].jobs[slot]
	job["paused"] = not bool(job.get("paused", false))
	if fac == PLAYER: _refresh_panel(); queue_redraw()


func _cancel_job(i: int, slot: int) -> void: _cmd(["cancel", i, slot])   # a cancelled job refunds nothing


func _do_cancel_job(fac: int, i: int, slot: int) -> void:
	if not _owns(fac, i): return
	(hosts[i].jobs as Dictionary).erase(slot)
	if fac == PLAYER: _refresh_panel(); queue_redraw()


func _demolish(i: int, slot: int) -> void: _cmd(["demolish", i, slot])   # clear a slot (DEMOLISH_TIME); the building is offline meanwhile


func _do_demolish(fac: int, i: int, slot: int) -> void:
	if not _owns(fac, i) or slot < 0 or slot >= (hosts[i].builds as Array).size(): return
	if str(hosts[i].builds[slot]) == "" or _slot_busy(i, slot): return
	(hosts[i].get("producer_paused", {}) as Dictionary).erase(slot)
	hosts[i].jobs[slot] = {"kind": "", "slot": slot, "phase": "demolish", "left": DEMOLISH_TIME}
	if fac != PLAYER: return
	_flash("Demolishing %s in slot %d of %s — %.0f s" % [BUILD_KINDS[str(hosts[i].builds[slot])].name, slot + 1, str(hosts[i].name), DEMOLISH_TIME])
	_refresh_panel(); queue_redraw()


# build jobs run on their own: several per building, nobody has to stay and watch them
func _tick_jobs(dt: float) -> void:
	# Attacks have first use of Intel. Keep the next packet's fractional funding
	# between frames, then share the remainder proportionally across all jobs.
	# A job pays every resource of its price at the same pace, so the scarcest one sets its speed.
	var demand := {}
	var budget := {}
	for fac in botnets:
		budget["%d:intel" % fac] = maxf(0.0, float(intel[fac]) - _attack_reserve(fac))
		budget["%d:cash" % fac] = maxf(0.0, float(cash[fac]))
	for h in hosts:
		var fac := int(h.owner)
		if fac == NEUTRAL: continue
		for job in (h.jobs as Dictionary).values():
			if str(job.phase) != "build" or bool(job.get("paused", false)): continue
			var left := _job_cost_left(job); var total := _job_cost_total(job)
			for res in left:
				var key := "%d:%s" % [fac, res]
				demand[key] = float(demand.get(key, 0.0)) + minf(float(left[res]), float(total.get(res, 0.0)) / BUILD_TIME * dt)
	for i in hosts.size():
		var jobs: Dictionary = hosts[i].jobs
		var fac := int(hosts[i].owner)
		if fac == NEUTRAL: continue
		for slot_key in jobs.keys():
			var job: Dictionary = jobs[slot_key]
			if bool(job.get("paused", false)): continue
			var work := dt
			if str(job.phase) == "build":
				var left := _job_cost_left(job); var total := _job_cost_total(job)
				var fraction := 1.0; var short := ""   # short: the resource that holds this job back (its slot says so)
				for res in left:
					if float(left[res]) <= 0.0: continue
					var key := "%d:%s" % [fac, res]
					var f := float(budget.get(key, 0.0)) / maxf(0.000001, float(demand.get(key, 0.0)))
					if f < fraction - 0.000001: fraction = f; short = str(res)
				fraction = clampf(fraction, 0.0, 1.0)
				job["short"] = short if fraction < 0.999 else ""
				for res in left:
					var requested := minf(float(left[res]), float(total.get(res, 0.0)) / BUILD_TIME * dt)
					var pay := requested * fraction
					_pool_add(fac, str(res), -pay)
					left[res] = maxf(0.0, float(left[res]) - pay)
				intel[fac] = maxf(0.0, float(intel[fac])); cash[fac] = maxf(0.0, float(cash[fac]))
				work = minf(dt, float(job.left)) * fraction
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
	var need := 0.0
	for i in hosts.size():
		if int(hosts[i].owner) != fac or not bool(hosts[i].live) or _routing_down(i): continue
		var t := _bot_target(i)
		if t < 0 or int(hosts[t].owner) == fac or _route(i, t).is_empty(): continue
		if float(hosts[i].bots) - 1.0 < _reserve_of(i): continue
		if str(hosts[i].mode) == "scan" and (_scanned(fac, t) or _scan_pending(fac, t)): continue
		need = maxf(need, _bot_intel(i))   # an overcharged bot costs 1.5 / 2 Intel: hold back that much, or converters starve it
	return need


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
		if fac == PLAYER and not _mp_on:
			lost = true; won = false; _end_cause = "Your rig was captured. Protect it to stay in the game."
		elif fac == PLAYER:
			_out = true; _flash("Your rig was captured — you are out of the match. Watch it to the end or leave from the menu.", 3)
		if _ai.has(fac): _ai[fac].dead = true
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


func _control_need() -> int:   # buildings a faction must EXCEED to hold: holding needs at least 51 % (rounded up)
	return maxi(0, _hold_need(hosts.size()) - 1)


func _hold_need(total: int) -> int:   # buildings that make at least HOLD_FRACTION of `total` (51 of 100, 16 of 31)
	return int(ceil(HOLD_FRACTION * float(total) - 0.000001))


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
	if not _is_human(int(hosts[i].owner)): return AI_RESERVE
	return 0.0


# where a building's bots go right now: its wire if LIVE; a dormant wire, or no wire, sends nothing
func _bot_target(i: int) -> int:
	var a := int(hosts[i].assign)
	if a >= 0: return a if bool(hosts[i].live) else -1
	return -1


# ---- ASSAULT: a finite order. hosts[i].assault = {t, left, total, sent, at, pct} while it stands. It owns the source:
# the wire points at its target in mode "assault" and is live. It ends — wire cleared, nothing left running, no guard —
# when its quota is spent, it is cancelled, the target turns friendly, the source is lost or re-ordered.
func _assault_of(i: int) -> Dictionary:   # the order that stands on source i, or {} (read-only: safe from drawing code)
	var a: Dictionary = hosts[i].get("assault", {})
	if a.is_empty() or int(hosts[i].assign) != int(a.t) or str(hosts[i].get("mode", "")) != "assault": return {}
	return a


func _assault_active(i: int) -> bool: return not _assault_of(i).is_empty()


func _regen_paused(i: int) -> bool:   # the exposure variant: this source's farms rest while its assault stands
	return assault_pause_regen and _assault_active(i)


func _end_assault(i: int) -> void:   # the order is over: unsent bots stay home, the wire is gone (it never becomes a guard)
	hosts[i].assault = {}
	if str(hosts[i].get("mode", "")) == "assault":
		hosts[i].assign = -1; hosts[i].live = false; hosts[i].mode = "attack"; _next_depart.erase(i)


func _assault_check() -> void:   # once per step, before departures: drop orders that were replaced, emptied or made moot
	for i in hosts.size():
		var a: Dictionary = hosts[i].get("assault", {})
		if a.is_empty(): continue
		if int(hosts[i].assign) != int(a.t) or str(hosts[i].get("mode", "")) != "assault" or int(hosts[i].owner) == NEUTRAL:
			hosts[i].assault = {}          # another order took the source: nothing of this one survives
		elif int(a.left) <= 0 or int(hosts[int(a.t)].owner) == int(hosts[i].owner):
			_end_assault(i)


func _assault_quota(i: int, pct: int) -> int:   # bots an order of pct % commits from source i right now (an overcharge commits the whole garrison)
	return int(floor(float(mini(pct, 100)) / 100.0 * floor(maxf(0.0, float(hosts[i].bots) - _reserve_of(i)))))


func _assault_power(pct: int) -> float: return maxf(1.0, float(pct) / 100.0)   # defenders one landed bot removes: x1.25 / x1.5 above 100 %
func _assault_intel(pct: int) -> float: return 1.0 + ASSAULT_OVERCHARGE_INTEL * maxf(0.0, float(pct) - 100.0) / 100.0   # Intel per departing bot


func _bot_intel(i: int) -> float:   # Intel one bot leaving source i costs (an overcharged assault pays more)
	var o := _assault_of(i)
	return 1.0 if o.is_empty() else _assault_intel(int(o.get("pct", 100)))


func _bot_power(i: int) -> float:   # defenders one bot from source i removes when it lands
	var o := _assault_of(i)
	return 1.0 if o.is_empty() else _assault_power(int(o.get("pct", 100)))


func _send_rate(i: int) -> float:   # bots/s source i releases while it is sending
	return ASSAULT_RATE if _assault_active(i) else SEND_RATE * float(hosts[i].rate)


func _attack_demand(fac: int) -> float:   # Intel/s a faction's LIVE attack flows would spend
	var n := 0.0
	for i in hosts.size():
		var t := int(hosts[i].assign)
		if int(hosts[i].owner) == fac and bool(hosts[i].live) and t >= 0 and int(hosts[t].owner) != fac and not _route(i, t).is_empty():
			n += _send_rate(i) * _bot_intel(i)
	return n


# why a source isn't delivering right now — drives the cause→action diagnostics
func _src_state(s: int) -> String:
	var fac := int(hosts[s].owner)
	var a := int(hosts[s].assign)
	if _routing_down(s) and (a >= 0 or _bot_target(s) >= 0): return "routing cut"
	if a >= 0:
		var rt := _route(s, a)
		if rt.is_empty(): return "no route"
		if _assault_active(s):   # a finite order: say what holds it, never that it is merely "wired"
			if float(hosts[s].bots) - 1.0 < _reserve_of(s): return "no bots"
			if float(intel[fac]) < _bot_intel(s): return "no Intel"
			if _first_wait(rt) > MAX_QUEUE: return "link busy"
			return "assaulting"
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


func _sim_step(dt: float) -> void:   # one fixed step of the whole simulation (_process feeds it SIM_DT)
	if _camp_paused: return         # the campaign's reading pause freezes the ENTIRE simulation (AI, production, transit, timers)
	_t += dt                        # the shared clock only advances while playing → pause freezes everything
	if not paid_regen:   # free replenishment: every farm regenerates first thing in the step
		for i in hosts.size():
			var nb := _count(i, "bot")
			if nb <= 0 or _regen_paused(i): continue   # an assault's source rests its farms until the order ends
			var cap := _cap_of(i)
			if float(hosts[i].bots) < cap:
				hosts[i].bots = minf(cap, float(hosts[i].bots) + float(nb) * PROD_RATE * _tmult(i, "bot") * _production_multiplier(i) * dt)   # = _regen(i)
	_tick_research(dt)
	_fx = _fx.filter(func(x): return float(x.until) > _t)
	_worms = _worms.filter(func(x): return float(x.until) > _t)
	for h in humans: _ai_remember(h)   # a person's memory of a scanned building stays as fresh as the AI's
	_prune_res()
	_route_memo = {}    # owners and route cuts hold still from here to production: each route is searched once
	_assault_check()    # finite orders that were emptied, replaced or made moot end before anything departs
	_auto_guards()      # guard wires arm themselves while their building is threatened, stand down after
	_emit_due()
	_tick_jobs(dt)
	if paid_regen: _tick_regen_paid(dt)   # after card preparation and construction, before labs convert Crypto
	_tick_production(dt)
	_tick_intel(dt)     # income + limit AFTER this step's Intel spending (departures, jobs, miners): a full bank ends the step AT its limit, only the true surplus is lost
	_tick_mission(dt)   # objective packets, alert, the owner's route response, timed relay reverts
	_route_memo = null
	for i in hosts.size():
		hosts[i].prod_off = maxf(0.0, float(hosts[i].prod_off) - dt)
		hosts[i].route_off = maxf(0.0, float(hosts[i].route_off) - dt)
	if not won and not lost: _deliver_due()      # chronological; may set won/lost and then stops
	if not won and not lost and not _ai_paused: _ai_tick(dt)   # the tutorial freezes the AI early on
	_check_rigs()
	if not won and not lost: _tick_domination(dt)
	if not _mp_on:   # single player: losing your rig or your last building ends it (multiplayer: you are out and watch)
		if not won and not lost and int(hosts[int(rig[PLAYER])].owner) != PLAYER: lost = true; _end_cause = "Your rig was captured — the botnet is finished."
		if not won and not lost and _player_nodes() == 0: lost = true; _end_cause = "You lost your last building."
	for fac in ais:
		if not bool(_ai[fac].dead) and _faction_nodes(fac) == 0:
			_ai[fac].dead = true; _flash("%s is out of the game" % fname(fac))
	if _camp and (won or lost): _camp_tick()   # ch5 finishes on the step that sets won; the sim halts before the 0.25s tick below would catch it
	_panel_t += dt
	if _panel_t >= 0.25:
		_panel_t = 0.0; _refresh_sight(); _drop_fogged_focus(); _record_observations()
		if _camp: _camp_tick()
		else: _tick_tutorial()
		_refresh_panel()


# "Attack and defend is the STATUS": a wire into a building of the SAME faction is a GUARD — it stands by
# dormant and starts flowing AUTOMATICALLY the moment the protected building is under attack (or below
# full, counting help already in the air), then stands down again. Guards are never launched or stopped
# by hand. The same rule serves every botnet.
func _auto_guards() -> void:
	# _under_attack / _incoming answered for every host in one pass (nothing below changes flights or hostile
	# wires: it only arms and stands down guards, which point at their own faction's buildings)
	var inbound := {}   # target -> {faction: bots flying at it}
	for f in flights:
		if str(f.kind) != "bot": continue
		var rt: Array = f.route
		var to := int(rt[rt.size() - 1])
		var by = inbound.get(to)
		if by == null: by = {}; inbound[to] = by
		by[int(f.owner)] = float(by.get(int(f.owner), 0.0)) + 1.0
	var wired := {}     # hosts a hostile LIVE attack wire is aimed at
	for i in hosts.size():
		var a := int(hosts[i].assign)
		if a >= 0 and bool(hosts[i].live) and int(hosts[i].owner) != int(hosts[a].owner) and str(hosts[i].get("mode", "attack")) != "scan": wired[a] = true
	for s in hosts.size():
		var fac := int(hosts[s].owner)
		if fac == NEUTRAL: continue
		var t := int(hosts[s].assign)
		if t < 0 or int(hosts[t].owner) != fac or str(hosts[s].get("mode", "")) == "assault": continue   # a finite order never turns guard
		var by: Dictionary = inbound.get(t, {})
		var hostile := false
		for o in by:
			if int(o) != fac: hostile = true
		var attacked: bool = _t - float(hosts[t].get("hit_t", -100.0)) < CARD_ALARM or hostile or wired.has(t)   # = _under_attack(t)
		var want: bool = attacked or (float(hosts[t].bots) + float(by.get(fac, 0.0)) < _cap_of(t) - 0.25)
		if want and not bool(hosts[s].live):
			hosts[s].live = true; _next_depart[s] = _t
		elif not want and bool(hosts[s].live):
			hosts[s].live = false; _next_depart.erase(s)


func _can_emit(i: int) -> bool:
	var tgt := _bot_target(i)
	if tgt < 0 or not _next_depart.has(i) or _routing_down(i): return false
	if float(_next_depart[i]) > _t: return false
	if str(hosts[i].get("mode", "")) == "assault" and int(_assault_of(i).get("left", 0)) <= 0: return false
	if float(hosts[i].bots) - 1.0 < _reserve_of(i): return false
	var fac := int(hosts[i].owner)
	var hostile: bool = int(hosts[tgt].owner) != fac
	if hostile and str(hosts[i].get("mode", "attack")) == "scan" and (_scanned(fac, tgt) or _scan_pending(fac, tgt)): return false   # scan done
	if hostile and float(intel[fac]) < _bot_intel(i) and (SCAN_COSTS_INTEL or str(hosts[i].mode) != "scan"): return false   # an overcharged bot needs its full price
	if not hostile and int(hosts[i].assign) < 0:   # an unwired building sends nothing; kept as a guard
		if float(hosts[tgt].bots) + _incoming(tgt, fac) >= NODE_CAP - 0.001: return false
	var rt := _route(i, tgt)
	if rt.is_empty() or _first_wait(rt) > MAX_QUEUE: return false
	return true


func _can_emit_cash(i: int) -> bool:
	if not _next_cash.has(i) or float(_next_cash[i]) > _t or _routing_down(i): return false
	if _count(i, "cash") <= 0 or float(_crypto_credit.get(i, 0.0)) + 0.000001 < _crypto_packet_amount(i): return false
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
		if a >= 0 and bool(hosts[i].live) and _route(i, a).is_empty() and not _assault_active(i):
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
			if hostile and (pk == "bot" or SCAN_COSTS_INTEL): intel[fac] = float(intel[fac]) - (_bot_intel(best) if pk == "bot" else 1.0)   # spends Intel (more when overcharged)
			flights.append(_schedule(_route(best, tgt), best_t, fac, pk, _bot_power(best) if pk == "bot" else 1.0))   # read before the order below can end
			if fac == PLAYER: _departures.append({"at": _t, "source": best, "target": tgt, "kind": pk})
			_next_depart[best] = best_t + 1.0 / _send_rate(best)
			var order := _assault_of(best)
			if not order.is_empty():   # a finite order: exactly its quota leaves, then it is over
				order.left = int(order.left) - 1; order.sent = int(order.sent) + 1
				if int(order.left) <= 0:
					_end_assault(best)
					if fac == PLAYER: _flash("%s's assault is spent — %d bots sent" % [str(hosts[best].name), int(order.sent)], 0)
			if not _next_depart.has(best) or float(_next_depart[best]) > _t: due.erase(best)
		else:
			var rg := int(rig[fac])
			var amount := _crypto_packet_amount(best)
			_crypto_credit[best] = maxf(0.0, float(_crypto_credit.get(best, 0.0)) - amount)
			if best == rg: _bank(fac, amount)        # the rig banks its own market directly
			else: flights.append(_schedule(_route(best, rg), best_t, fac, "cash", amount))
			_next_cash[best] = best_t + CASH_INTERVAL / (float(_count(best, "cash")) * _production_multiplier(best))
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
		if int(hosts[t].owner) != NEUTRAL:
			_bank(int(hosts[t].owner), float(f.get("amount", 1.0)))
			if _camp and int(hosts[t].owner) == PLAYER: _camp_cash_landed += 1   # ch1: Crypto actually reached home
		return
	if str(f.kind) == "scan":   # consumed on arrival; reveals, never wounds
		if int(hosts[t].owner) != fac: _scan_land(fac, t)
		return
	if str(f.kind) == "card":   # a card packet: its effect lands now
		_land_card(fac, str(f.get("card", "phishworm:linked")), t)
		return
	if str(f.kind) == "record":   # an objective packet reached home: mission progress, and the source's alert rises
		_record_landed(fac, int(f.get("src", -1)))
		return
	if int(hosts[t].owner) == fac:
		hosts[t].bots = minf(_cap_of(t), float(hosts[t].bots) + 1.0)
		return
	if not _scanned(fac, t): _scan_land(fac, t)   # any attack scans as it goes — loudly
	hosts[t].bots = float(hosts[t].bots) - (ATTACK_POWER / DEFEND_POWER) * float(f.get("amount", 1.0))   # an overcharged bot hits x1.25 / x1.5
	if float(hosts[t].bots) <= 0.0: _capture(t, fac)


# ownership changes: attack flows into a building the attacker CAPTURES become guards that top it up and
# stand down; wires of the LOSER into it stand down (kept, dormant) — retaking it is an explicit call
func _capture(t: int, fac: int) -> void:
	var prev := int(hosts[t].owner)
	var nm := str(hosts[t].name)
	if ais.has(prev): _ai[prev].lost[t] = {"to": fac, "at": _t}   # an AI remembers what it lost
	hosts[t].owner = fac
	hosts[t].producer_paused = {}; hosts[t].boost_until = 0.0; hosts[t].patch_until = 0.0; hosts[t].sca_until = 0.0
	_crypto_credit.erase(t)
	for f in botnets:   # the capture is announced to everyone: a just-taken building is known to be near empty
		if f == fac or _scanned(f, t): continue
		var old: Dictionary = (scans[f] as Dictionary).get(t, {})
		scans[f][t] = {"key": str(old.get("key", "")), "done": bool(old.get("done", false)), "progress": 0.0, "bots": 0.0, "cap": NODE_CAP, "at": _t}
	hosts[t].bots = minf(NODE_CAP, -float(hosts[t].bots))
	hosts[t].assign = -1; hosts[t].live = false; hosts[t].jobs = {}; hosts[t].rate = 1.0; hosts[t].assault = {}; hosts[t].mode = "attack"   # a lost source's order is void
	for i in hosts.size():   # the target is ours now: assaults on it stop sending (what is in the air lands as usual) — no guards
		var order: Dictionary = hosts[i].get("assault", {})
		if not order.is_empty() and int(order.t) == t and int(hosts[i].owner) == fac: _end_assault(i)
	hosts[t].builds = _slot_array([], int(hosts[t].slots))   # a captured building is empty inside: the new owner builds from scratch
	hosts[t].prod_off = 0.0; hosts[t].route_off = 0.0; hosts[t].steal_until = -100.0; hosts[t].steal_by = -1; hosts[t].hit_t = -100.0   # a new owner, a clean slate
	if _is_mission(t): hosts[t].access_until = 0.0; hosts[t].access_by = -1; hosts[t].alert = 0.0   # access ends if the target changes hands
	_next_depart.erase(t); _next_cash.erase(t); _next_record.erase(t)
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
	if _seen.has(prev): (_seen[prev] as Dictionary)[t] = Vector2(float(fac), _t)   # the loser saw it flip
	_refresh_sight()
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
	return "%d Crypto · %d Credentials · %d Research" % [int(c.cash), int(c.creds), int(c.research)]


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


func _card_scale(_fam: String, _i: int) -> float:
	# The four-card rules use exact values on every building type.
	return 1.0


func _resist_line(_i: int) -> String:
	return "Card effects are fixed across building types."


func _can_play(fac: int, key: String, t: int, rig_reach: Variant = null) -> String:   # "" if playable, else why not; rig_reach = _wire_reach([rig]) when a caller checks many hosts
	if won or lost: return "match finished"
	if not CARDS.has(_card_of(key)): return "unknown card"
	if not rig.has(fac) or _eliminated.has(fac) or int(hosts[int(rig[fac])].owner) != fac: return "your rig is not under your control"
	if t < 0 or t >= hosts.size(): return "no host selected"
	# a cut rig can still defend itself (the card never leaves it), but cannot send anywhere else
	if _routing_down(int(rig[fac])) and t != int(rig[fac]): return "your rig's routing is cut"
	var cd: Dictionary = CARDS[_card_of(key)]
	var defense := bool(cd.get("defense", false))
	if defense and int(hosts[t].owner) != fac: return "DEFENCE needs one of your hosts"
	if not defense and int(hosts[t].owner) == fac: return "ATTACK needs a foreign host"
	if bool(cd.get("needs_link", false)) and not _linked(fac, t): return "%s needs one of your connections into this host" % str(cd.name)
	if _held(fac, key) <= 0: return "none held"
	var routed: bool = (rig_reach as Dictionary).has(t) if rig_reach != null and fac == PLAYER else not _route(int(rig[fac]), t).is_empty()
	if t != int(rig[fac]) and not routed: return "no route from your rig — capture a path toward it first"
	return ""


func _card_levels(cd: Dictionary) -> int:
	return int(cd.get("levels", (cd.get("durations", []) as Array).size())) if bool(cd.chain) else 1


func _card_duration(cd: Dictionary, level := 1) -> float:
	if level < 1 or level > _card_levels(cd): return 0.0
	var schedule: Array = cd.get("durations", [])
	return float(schedule[level - 1]) if not schedule.is_empty() else float(cd.dur)


func _effect_text(cd: Dictionary, i: int, _s: float, level := 1, resolved := false) -> String:
	var duration := _card_duration(cd, level)
	var result := str(hosts[i].get("card_result", "")) if resolved and i >= 0 else ""
	if result.begins_with("blocked") or result == "capture failed": return result
	match str(cd.effect):
		"campaign": return "all resource output stolen %.0f s" % duration
		"deny": return "all production and routing stopped %.0f s" % duration
		"wipe": return "buildings, construction and defenders wiped; ownership stays"
		"breach": return "host captured" if result == "applied" else "75% chance of instant capture"
		"cdn": return "DDOS cleared" if result == "cleared" else ("clear DDOS" if not resolved and i >= 0 and (_prod_down(i) or _routing_down(i)) else "production x2 for 10 s")
		"patch": return "0day + Supply chain blocked for 30 s"
		"response": return "Phishing removed"
		_: return "Supply chain blocked for 60 s"


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
				_bank_alert[_bank_of(key)] = Time.get_ticks_msec() + 3000   # its tab blinks for 3 s
				_refresh_panel(); _refresh_hand()


func _play_card(fac: int, key: String, t: int) -> bool:   # the card leaves your network as a packet and lands on arrival
	var why := _can_play(fac, key, t)
	if why != "":
		if fac == PLAYER: _flash("Cannot play: %s" % why)
		return false
	var src := int(rig[fac])   # a card ALWAYS flies from your rig (the main host), along its own network
	var rt := [src] if src == t else _route(src, t)
	if rt.is_empty():
		if fac == PLAYER: _flash("Cannot play: no route from your rig to %s" % str(hosts[t].name))
		return false
	var cd: Dictionary = CARDS[_card_of(key)]
	cards[fac][key] = _held(fac, key) - 1
	card_plays[fac] = int(card_plays.get(fac, 0)) + 1
	var f := _schedule(rt, _t, fac, "card")
	f.card = key
	flights.append(f)
	if fac == PLAYER: _flash("%s is on its way to %s from %s — lands in %d s" % [str(cd.name), str(hosts[t].name), str(hosts[src].name), int(ceil(float(f.arrive_t) - _t))])
	elif _mine(t): _flash("A card from %s is flying toward %s" % [fname(fac), str(hosts[t].name)])
	_refresh_panel(); queue_redraw()
	return true


func _land_card(fac: int, key: String, t: int) -> void:
	if _eliminated.has(fac) or not CARDS.has(_card_of(key)): return
	var cd: Dictionary = CARDS[_card_of(key)]
	if (int(hosts[t].owner) == fac) != bool(cd.get("defense", false)): return # ownership changed in transit
	var hit := [t]
	_apply_effect(fac, cd, t, 1)
	if bool(cd.chain): hit += _worm(fac, cd, t)
	for h in hit: _fx.append({"host": int(h), "until": _t + 3.0, "col": fcol(fac)})
	if fac == PLAYER:
		var spread := ""
		if hit.size() > 1: spread = " - spread to %d more: %s" % [hit.size() - 1, _names(hit.slice(1))]
		_flash("%s on %s: %s%s" % [str(cd.name), str(hosts[t].name), _effect_text(cd, t, 1.0, 1, true), spread])
	else:
		var yours := []
		for h in hit:
			if _mine(int(h)): yours.append(int(h))
		if not yours.is_empty():
			var first := int(yours[0])
			_flash("%s hit %s with %s: %s" % [fname(fac), _names(yours), str(cd.name), _effect_text(cd, first, 1.0, hit.find(first) + 1, true)])
	_refresh_panel(); queue_redraw()


func _apply_effect(fac: int, cd: Dictionary, i: int, level := 1) -> float:
	if _eliminated.has(fac) or level < 1 or level > _card_levels(cd): return 0.0
	if (int(hosts[i].owner) == fac) != bool(cd.get("defense", false)): return 0.0
	var duration := _card_duration(cd, level)
	var effect := str(cd.effect)
	hosts[i].card_result = "applied"
	if effect in ["breach", "wipe"] and float(hosts[i].get("patch_until", 0.0)) > _t:
		hosts[i].card_result = "blocked by Patch day"; return -1.0
	if effect == "wipe" and float(hosts[i].get("sca_until", 0.0)) > _t:
		hosts[i].card_result = "blocked by SCA"; return -1.0
	if effect == "breach":
		var sure := _camp and fac == PLAYER and bool(_camp_events.get("0day_missed", false))   # campaign: one honest miss teaches "it can miss"; the retry lands
		if not sure and rng.randf() >= float(cd.power):
			hosts[i].card_result = "capture failed"
			if _camp and fac == PLAYER: _camp_events["0day_missed"] = true
			return -2.0
		hosts[i].bots = 0.0; _capture(i, fac)
	if effect == "deny":
		hosts[i].prod_off = maxf(float(hosts[i].prod_off), duration)
		hosts[i].route_off = maxf(float(hosts[i].route_off), duration)
	if effect == "campaign":
		var expires := _t + duration
		if int(hosts[i].steal_by) == fac: expires = maxf(float(hosts[i].steal_until), expires)
		hosts[i].steal_until = expires; hosts[i].steal_by = fac
	if effect == "wipe":
		hosts[i].builds = _slot_array([], int(hosts[i].slots))
		hosts[i].jobs = {}; hosts[i].bots = 0.0; hosts[i].producer_paused = {}
		_next_cash.erase(i); _crypto_credit.erase(i)
	if effect == "cdn":
		if _prod_down(i) or _routing_down(i):   # DDOS: production and routing both come back
			hosts[i].prod_off = 0.0; hosts[i].route_off = 0.0; hosts[i].card_result = "cleared"
		else: hosts[i].boost_until = maxf(float(hosts[i].get("boost_until", 0.0)), _t + duration)
	if effect == "patch": hosts[i].patch_until = maxf(float(hosts[i].get("patch_until", 0.0)), _t + duration)
	if effect == "sca": hosts[i].sca_until = maxf(float(hosts[i].get("sca_until", 0.0)), _t + duration)
	if effect == "response": hosts[i].steal_until = -100.0; hosts[i].steal_by = -1
	hosts[i].hit_t = _t
	_mark_scanned(fac, i)
	return 1.0


func _worm(fac: int, cd: Dictionary, start: int) -> Array:
	# The first target is level 1. Each level follows one new adjacent node.
	var hit := []; var seen := {start: true}; var current := start
	for level in range(2, _card_levels(cd) + 1):
		var candidates := []
		for neighbor in hosts[current].links:
			var node := int(neighbor)
			if not seen.has(node) and (int(hosts[node].owner) == fac) == bool(cd.get("defense", false)): candidates.append(node)
		if candidates.is_empty(): break
		var target: int = candidates[rng.randi_range(0, candidates.size() - 1)]
		seen[target] = true
		_worms.append({"a": current, "b": target, "level": level, "until": _t + 4.0, "col": fcol(fac)})
		_apply_effect(fac, cd, target, level)
		hit.append(target); current = target
	return hit


# ============================================================ AI BOTNETS
# Foreign details pass through _ai_known_bots/_ai_known_builds; public links,
# owners, types and visible effects remain available to every faction.


func _ai_tick(dt: float) -> void:
	if not ai_enabled: return
	for fac in ais:
		if str(ai_level.get(fac, "normal")) == "insane":   # the Insane brain keeps its own clocks (thinking and micro)
			if bool(_ai[fac].get("dead", false)) or _eliminated.has(fac): continue
			if not _brains.has(fac): _brains[fac] = AiInsane.new(self, fac)
			_brains[fac].tick(dt)
			continue
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


# ---- an AI's Crypto budget: what it owes, what is coming, where a miner pays (its own hosts only: fair view) ----
func _ai_cash_owed(fac: int) -> float:   # Crypto its accepted construction jobs still have to pay (quotes are not reserved)
	var owed := 0.0
	for h in hosts:
		if int(h.owner) != fac: continue
		for job in (h.jobs as Dictionary).values(): owed += float(_job_cost_left(job).get("cash", 0.0))
	return owed


func _ai_cash_free(fac: int) -> float:   # the Crypto bank less running jobs' debts and the research still queued to run
	var free := float(cash[fac]) - _ai_cash_owed(fac)
	if bool(lab[fac].paused): return free
	var items := _research_items(fac); var queue: Array = lab[fac].queue
	for k in queue.size():
		if bool(items[k].paused): continue
		var key := str(queue[k])
		free -= float(_card_cost(key).get("cash", 0.0)) * (1.0 - float(items[k].progress) / _card_time(key))
	return free


func _ai_crypto_flow(fac: int) -> Dictionary:   # {rate: Crypto/s its standing miners send home, jobs: miner jobs under way}
	var rate := 0.0; var jobs := 0
	var home := int(rig.get(fac, -1))
	var home_ok := home >= 0 and int(hosts[home].owner) == fac
	for i in hosts.size():
		if int(hosts[i].owner) != fac: continue
		var jd: Dictionary = hosts[i].jobs
		for job in jd.values():
			if str(job.kind) == "cash": jobs += 1
		# a miner it paused itself still counts; one switched off by a card, stolen, or cut off from the rig does not
		if not home_ok or _prod_down(i) or _stolen(i) or not (hosts[i].builds as Array).has("cash"): continue
		if i != home and _route(i, home).is_empty(): continue
		var n := 0
		for k in (hosts[i].builds as Array).size():
			if str(hosts[i].builds[k]) == "cash" and not jd.has(k): n += 1
		rate += float(n) * float(hosts[i].value) * _tmult(i, "cash") / CASH_INTERVAL * _production_multiplier(i) * ai_cash_mult
	return {"rate": rate, "jobs": jobs}


func _ai_miner_site(fac: int, free_slot: Array) -> int:   # the richest free host with a road home (Crypto travels to the rig)
	var home := int(rig.get(fac, -1))
	if home < 0 or int(hosts[home].owner) != fac: return -1
	var site := -1; var bestv := -INF
	for e in free_slot:
		if int(e) != home and _route(int(e), home).is_empty(): continue
		var v := float(hosts[e].value) * 2.0 * _tmult(e, "cash") + float(int(hosts[e].slots) - _built_kinds(e).size()) * 0.3 - (1.0 if _ai_borders_botnet(e) else 0.0)
		if v > bestv: bestv = v; site = int(e)
	return site


# Saving Crypto for a build: the AI pauses its labs and queued research with the player's own clicks (producer
# pause, research item pause) and resumes exactly what it paused once the build is covered.
func _ai_hold_crypto(fac: int, st: Dictionary, hold: bool) -> void:
	var held: Dictionary = st.get("crypto_hold", {})
	if hold:
		for i in hosts.size():
			if int(hosts[i].owner) != fac or not (hosts[i].builds as Array).has("lab"): continue
			for slot in (hosts[i].builds as Array).size():
				if str(hosts[i].builds[slot]) != "lab" or (hosts[i].jobs as Dictionary).has(slot) or _producer_paused(i, slot): continue
				if not hosts[i].has("producer_paused"): hosts[i].producer_paused = {}
				hosts[i].producer_paused[slot] = true; held["lab:%d:%d" % [i, slot]] = [i, slot]
		var items := _research_items(fac); var queue: Array = lab[fac].queue
		for k in queue.size():
			if not bool(items[k].paused): _toggle_research_item(fac, k); held["card:" + str(queue[k])] = str(queue[k])
	elif not held.is_empty():
		for key in held:
			var v: Variant = held[key]
			if v is Array:
				var i := int(v[0]); var slot := int(v[1])
				if int(hosts[i].owner) == fac and str(hosts[i].builds[slot]) == "lab" and _producer_paused(i, slot): (hosts[i].producer_paused as Dictionary).erase(slot)
			else:
				var k := (lab[fac].queue as Array).find(str(v))
				if k >= 0 and bool(_research_items(fac)[k].paused): _toggle_research_item(fac, k)
		held = {}
	st.crypto_hold = held


# ---- the finite assault, for an AI: the same commands a player gives, sized from what the AI knows ----
func _ai_assault_plan(fac: int, c: int, cands: Array) -> Dictionary:   # cands = [[route size, source], …] nearest first; {} = no
	var srcs := []; var bots := 0; var lasts := {}; var hops := 99
	for pair in cands:
		if srcs.size() >= AI_MAX_STREAMS: break
		var e := int(pair[1])
		if _assault_active(e) or float(hosts[e].bots) < AI_RESERVE + 10.0: continue
		var quota := _assault_quota(e, AI_ASSAULT_PCT)
		var rt := _route(e, c)
		if quota < 5 or rt.size() < 2: continue
		srcs.append(e); bots += quota; lasts[int(rt[rt.size() - 2])] = true; hops = mini(hops, rt.size() - 1)
	if srcs.size() < 2: return {}
	var burst := minf(float(srcs.size()) * ASSAULT_RATE, float(LINK_CAP) * float(lasts.size()))   # the last streets cap the burst
	var travel := float(hops) * LINK_TIME + float(maxi(0, hops - 1)) * NODE_ROUTE_DELAY
	var need := _ai_known_bots(fac, c) + _ai_known_regen(fac, c) * (float(bots) / burst + travel) + 4.0
	if float(bots) < need * 1.2: return {}                                                     # it must win with room to spare
	if float(intel[fac]) + _intel_rate(fac) * (need / burst) < need: return {}                 # every landing bot costs 1 Intel
	return {"srcs": srcs, "secs": need / burst + travel, "bots": bots}


func _ai_launch_assault(fac: int, c: int, plan: Dictionary) -> void:
	_do_wire(fac, plan.srcs, c)
	_do_assault(fac, c, AI_ASSAULT_PCT)
	if _mine(c): _flash("%s launches an ASSAULT on %s from %d host(s) — their farms rest while it runs" % [fname(fac), str(hosts[c].name), (plan.srcs as Array).size()])


func _ai_release(e: int) -> void:
	hosts[e].assign = -1; hosts[e].live = false; _next_depart.erase(e); hosts[e].assault = {}


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
	if _regen_paused(i) and _visible_to(fac, i): return 0.0   # "ASSAULT · rest" is drawn on the map
	var kinds := _ai_known_builds(fac, i)
	var n := 0
	for k in kinds:   # every Bot farm it knows of works, whatever the garrison
		if str(k) == "bot": n += 1
	return float(n) * PROD_RATE * _tmult(i, "bot")


func _ai_seen_drain(i: int) -> float:   # bots/s visibly leaving i: a drawn live flow (never a quiet scan), or its bot packets in flight
	var d := _bot_target(i)
	if d >= 0 and _next_depart.has(i) and _route(i, d).size() >= 2:   # mirrors the draw path: a live non-scan route is drawn solid
		if not (int(hosts[i].assign) >= 0 and str(hosts[i].get("mode", "attack")) == "scan"): return _send_rate(i)
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


func _ai_chain_reach(fac: int, seed: int, remaining: int, seen: Dictionary) -> float:
	if remaining <= 1: return 1.0
	var candidates := []
	for neighbor in hosts[seed].links:
		var node := int(neighbor)
		if not seen.has(node) and int(hosts[node].owner) != fac: candidates.append(node)
	if candidates.is_empty(): return 1.0
	var continuation := 0.0
	for node in candidates:
		var visited := seen.duplicate(); visited[node] = true
		continuation += _ai_chain_reach(fac, int(node), remaining - 1, visited)
	return 1.0 + continuation / float(candidates.size())


func _ai_worm_value(fac: int, seed: int) -> float:
	return _ai_chain_reach(fac, seed, _card_levels(CARDS.phishworm), {seed: true})


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
			if ops.has(i): continue
			var free := []
			for e in mine:
				if _under_attack(e) or float(hosts[e].bots) < AI_RESERVE + 4.0 or _assault_active(e): continue
				var ea := int(hosts[e].assign)   # a source on a quiet errand (a scan, a neutral siege) may be pulled onto the attacker
				if ea >= 0 and not (str(hosts[e].get("mode", "attack")) == "scan" or (int(hosts[ea].owner) == NEUTRAL and bool(hosts[e].live))): continue
				var rt := _route(e, i)
				if not rt.is_empty(): free.append([rt.size(), e])
			free.sort_custom(func(a, b): return a[0] < b[0])
			if str(hosts[i].get("mode", "")) == "assault" and _scanned(fac, i):   # a known, draining origin: stand the errands down, keep Intel for it
				for pair in free:
					var e := int(pair[1])
					if int(hosts[e].assign) >= 0 and int(hosts[e].assign) != i: _ai_release(e)
			if float(intel[fac]) < 20.0: continue
			if str(hosts[i].get("mode", "")) == "assault" and not _scanned(fac, i) and not _scan_pending(fac, i) and not free.is_empty():
				var scout := int(free[0][1])   # an assault's origin may be thin now: learn it with one quiet scan
				hosts[scout].assign = i; hosts[scout].live = true; hosts[scout].mode = "scan"; _next_depart[scout] = _t
				continue
			var cs := _ai_fall_secs(fac, i, 2)
			if cs > AI_PATIENCE or 2.0 * SEND_RATE * cs > float(intel[fac]) + _intel_rate(fac) * cs:
				var punish := _ai_assault_plan(fac, i, free)   # too strong for two streams: a concentrated blow, if one fits
				if punish.is_empty() or float(punish.secs) > AI_PATIENCE: continue
				_ai_launch_assault(fac, i, punish)
				ops[i] = punish.srcs; recs[i] = {"since": _t, "bots": _ai_known_bots(fac, i), "prog": _scan_progress(fac, i)}
				continue
			if free.size() < 2: continue
			for h in free.slice(0, 2):
				hosts[int(h[1])].assign = i; hosts[int(h[1])].live = true; hosts[int(h[1])].mode = "attack"; _next_depart[int(h[1])] = _t
			ops[i] = [int(free[0][1]), int(free[1][1])]
			recs[i] = {"since": _t, "bots": _ai_known_bots(fac, i), "prog": _scan_progress(fac, i)}
			if _mine(i): _flash("%s counter-attacks %s" % [fname(fac), str(hosts[i].name)])
	st.threat_seen = seen
	# ── 2. build: one new job per think, chosen by need; jobs run on their own and several may overlap.
	# Prices differ per kind (cfg BUILD_COSTS): when the chosen build is short of Intel while the converters eat the
	# whole Intel income, it pauses its miners and harvesters and saves up, then resumes them.
	var saving := float(st.get("saving_for", 0.0))
	if bool(st.get("economy_paused", false)) and float(intel[fac]) >= saving + 5.0:
		for node in mine: hosts[node].producer_paused = {}
		st.economy_paused = false; st.saving_for = 0.0
	var free_slot := []
	if ai_build_hook.has(fac): (ai_build_hook[fac] as Callable).call(fac)   # a probe decides this faction's builds
	else:
		for e in mine:
			if _free_slot(e) >= 0: free_slot.append(e)
	var crypto_wait := false   # this think saves Crypto for a Crypto-priced build: its labs and research wait
	if not free_slot.is_empty():
		var site := -1; var kind := ""
		var want_intel: bool = _intel_rate(fac) < 1.0 + float(ops.size()) + _production_input_rate(fac, "intel") or float(intel[fac]) < 15.0
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
		if site >= 0:   # a Crypto-priced build (farm, lab) the free Crypto can't cover: bootstrap a miner, or save for it
			var cash_need := float(_build_cost(kind).get("cash", 0.0))
			var cash_free := _ai_cash_free(fac)
			if cash_need > 0.0 and cash_free < cash_need - 0.0001:
				var flow := _ai_crypto_flow(fac)
				var eta: float = INF if float(flow.rate) <= 0.0 else (cash_need - cash_free) / float(flow.rate)
				if int(flow.jobs) == 0 and eta > AI_CRYPTO_WAIT:   # no miner on the way and too little mining: build one first
					var ms := _ai_miner_site(fac, free_slot)
					if ms >= 0: site = ms; kind = "cash"
				if kind != "cash":   # Crypto is coming: wait for it rather than re-ordering the same build every think
					crypto_wait = float(flow.rate) > 0.0 or int(flow.jobs) > 0
					site = -1
		if site >= 0:
			if _can_afford_build(fac, kind): _start_job(site, kind)
			else:
				var need := float(_build_cost(kind).get("intel", 0.0))
				if float(intel[fac]) < need and _production_input_rate(fac, "intel") >= _intel_rate(fac):
					for node in mine:   # the converters eat all Intel income: pause them and save up
						for slot in (hosts[node].builds as Array).size():
							if str(hosts[node].builds[slot]) in ["cash", "cred"] and not (kind == "lab" and str(hosts[node].builds[slot]) == "cash" and float(cash[fac]) < float(_build_cost(kind).get("cash", 0.0))):
								if not hosts[node].has("producer_paused"): hosts[node].producer_paused = {}
								hosts[node].producer_paused[slot] = true
					st.economy_paused = true; st.saving_for = need
	# accepted Crypto-priced jobs are not reserved and card research is paid first: keep it waiting until they're covered
	if not crypto_wait and _ai_cash_owed(fac) > float(cash[fac]) + 0.0001: crypto_wait = float(_ai_crypto_flow(fac).rate) > 0.0
	_ai_hold_crypto(fac, st, crypto_wait)
	# ── 2b. research: a cheap card of each useful kind; phishing first when a rival leads the Cash race ──
	var L: Dictionary = lab[fac]
	# Recover ongoing attacks first, then maintain shields on the home network.
	var defensive_need := ""
	for node in mine:
		var defense := ""
		if _prod_down(node): defense = "cdn"
		elif _stolen(node): defense = "response"
		elif node == int(rig[fac]) and float(hosts[node].get("patch_until", 0.0)) <= _t: defense = "patch"
		elif _built_kinds(node).size() >= 3 and float(hosts[node].get("sca_until", 0.0)) <= _t: defense = "sca"
		if defense == "": continue
		var defense_key := _card_key(defense, "linked")
		if defensive_need == "": defensive_need = defense_key
		if _held(fac, defense_key) > 0:
			var pending := false
			for flight in flights:
				if str(flight.kind) == "card" and int(flight.owner) == fac and str(flight.get("card", "")) == defense_key: pending = true; break
			if not pending: _play_card(fac, defense_key, node)
	var leader := _ai_leader(fac)
	var chased: bool = leader >= 0 and _faction_nodes(leader) >= _faction_nodes(fac) + int(AI_CHOKE_LEAD)
	if (L.queue as Array).is_empty() and _kind_total(fac, "lab") > 0 and _kind_total(fac, "cred") > 0 and not crypto_wait:
		var want := ""
		if defensive_need != "" and (_prod_down(int(rig[fac])) or _stolen(int(rig[fac])) or _hand_size(fac) >= 2): want = defensive_need
		elif chased and _held(fac, "ddos:linked") < 1: want = "ddos:linked"
		elif _held(fac, "zeroday:linked") < 1: want = "zeroday:linked"
		elif _held(fac, "phishworm:linked") < 1: want = "phishworm:linked"
		elif _held(fac, "supply:linked") < 1: want = "supply:linked"
		elif _held(fac, "ddos:linked") < 1: want = "ddos:linked"
		if want != "": _queue_research(fac, want)
	# Cards soften a scanned siege target or disrupt a rival producer.
	var worm_seed := -1; var worm_best := 0.0
	for tk in ops.keys():
		var t2 := int(tk)
		if not _scanned(fac, t2) or _ai_known_bots(fac, t2) < 4.0: continue
		var kinds2 := _ai_known_builds(fac, t2)
		if _held(fac, "supply:linked") > 0 and not kinds2.is_empty():
			if _play_card(fac, "supply:linked", t2): break
		if _held(fac, "zeroday:linked") > 0:
			if _play_card(fac, "zeroday:linked", t2): break
		if _held(fac, "ddos:linked") > 0 and not _prod_down(t2) and not kinds2.is_empty():
			if _play_card(fac, "ddos:linked", t2): break
		if _held(fac, "phishworm:linked") > 0 and int(hosts[t2].owner) != NEUTRAL:
			var reach := _ai_worm_value(fac, t2)
			if reach > worm_best: worm_best = reach; worm_seed = t2
	if worm_seed >= 0: _play_card(fac, "phishworm:linked", worm_seed)
	if chased:
		for tk in (scans[fac] as Dictionary).keys():
			var target := int(tk)
			if int(hosts[target].owner) != leader or not _scanned(fac, target): continue
			var kinds := _ai_known_builds(fac, target)
			if not (kinds.has("cash") or kinds.has("intel") or kinds.has("cred") or kinds.has("lab")): continue
			var played := false
			for card in ["ddos", "supply", "phishworm"]:
				if card == "ddos" and _prod_down(target): continue
				var key := _card_key(card, "linked")
				if _held(fac, key) > 0 and _play_card(fac, key, target): played = true; break
			if played: break
	# Offence: scout unknown targets, then strike those it can take.
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
	var pick := -1; var pick_srcs := []; var best := 0.0; var pick_known := false; var pick_plan := {}
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
			var plan := {}
			if secs > AI_SIEGE_MAX:                                # streams cannot finish it: would a concentrated assault?
				plan = _ai_assault_plan(fac, c, srcs)
				if plan.is_empty(): continue                       # know your limits: a siege it cannot finish in its budget is not started
				secs = float(plan.secs)
			var quiet_c: bool = not known and pressure == 0 and plan.is_empty()
			var cost := secs * float(n) * SEND_RATE if not quiet_c else SCAN_BASE + SCAN_PER_BUILD * float(kinds.size()) + 0.5 * secs * float(n) * SEND_RATE
			if not plan.is_empty(): cost = 0.0                     # the plan already checked its Intel
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
			if not plan.is_empty(): score *= 0.85                  # an assault leaves its sources resting and thin
			if score > best: best = score; pick = c; pick_srcs = srcs.slice(0, n); pick_known = known; pick_plan = plan
	if pick >= 0 and not pick_plan.is_empty():
		_ai_launch_assault(fac, pick, pick_plan)
		recs[pick] = {"since": _t, "bots": _ai_known_bots(fac, pick), "prog": _scan_progress(fac, pick)}
	elif pick >= 0:
		var quiet: bool = not pick_known and _ai_others_on(fac, pick) == 0   # an alarmed target has nothing left to keep quiet for
		var launch: Array = pick_srcs.slice(0, 2) if quiet else pick_srcs
		for s in launch:
			hosts[int(s[1])].assign = pick; hosts[int(s[1])].live = true; hosts[int(s[1])].mode = "scan" if quiet else "attack"; _next_depart[int(s[1])] = _t
		if pick_known and _ai_known_bots(fac, pick) >= 4.0 and _linked(fac, pick):   # prepare the ground: soften it as the streams arrive
			for card in ["supply", "zeroday", "ddos", "phishworm"]:
				var key := _card_key(card, "linked")
				if card == "supply" and _ai_known_builds(fac, pick).is_empty(): continue
				if card == "ddos" and _prod_down(pick): continue
				if _held(fac, key) > 0 and _play_card(fac, key, pick): break
		recs[pick] = {"since": _t, "bots": _ai_known_bots(fac, pick), "prog": _scan_progress(fac, pick)}
		if _mine(pick) and not quiet: _flash("%s is attacking %s with %d source(s) — defend it!" % [fname(fac), str(hosts[pick].name), launch.size()])
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
	return t >= 0 and _can_play(PLAYER, str(data.card), t) == "" and _card_scale(str(CARDS[_card_of(str(data.card))].fam), t) > 0.0


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


# Four permanent cards: click to research/pause; drag held copies onto the map.
func _refresh_hand() -> void:
	if hand_bar == null: return
	if hand_bar.get_child_count() != CARD_ORDER.size():
		for c in hand_bar.get_children(): hand_bar.remove_child(c); c.queue_free()
		for card in CARD_ORDER:
			var tile := CardTile.new(); tile.game = self; tile.key = _card_key(str(card), "linked")
			hand_bar.add_child(tile)
	var width := floorf((hand_panel.size.x - CARD_DOCK_GAP * 3) / 4)
	for tile in hand_bar.get_children():
		tile.visible = bool(CARDS[_card_of(tile.key)].get("defense", false)) == (_card_bank == "defense")
		tile.custom_minimum_size = Vector2(width, CARD_DOCK_HEIGHT); tile.queue_redraw()
	hand_bar.size = hand_panel.size
	_update_card_banks()


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
	_card_bank = bank
	if _deck_open: _refresh_hand()
	else: _set_deck_open(true)


func _bank_of(key: String) -> String:
	return "defense" if bool(CARDS[_card_of(key)].get("defense", false)) else "attack"


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


func _card_queue_index(key: String) -> int:
	return (lab[PLAYER].queue as Array).find(key)


func _card_research_click(key: String) -> void:
	if menu_open or won or lost: return
	_cmd(["research", key])


func _do_research(fac: int, key: String) -> void:   # queue a card's research, or pause / resume it when queued
	var index := (lab[fac].queue as Array).find(key)
	if index >= 0: _toggle_research_item(fac, index)
	else: _queue_research(fac, key)


func _card_research_cancel(key: String) -> void:
	if _card_queue_index(key) >= 0 and not menu_open and not won and not lost: _cmd(["unresearch", key])


func _do_unresearch(fac: int, key: String) -> void:
	var index := (lab[fac].queue as Array).find(key)
	if index >= 0: _dequeue_research(fac, index)


func _card_research_state(key: String) -> Dictionary:
	var count := _held(PLAYER, key)
	var index := _card_queue_index(key)
	var result := {"count": count, "status": "Ready" if count > 0 else "Idle", "progress": 0.0, "queued": index >= 0}
	if index < 0: return result
	var items := _research_items(PLAYER)
	var item: Dictionary = items[index]
	result.progress = clampf(float(item.progress) / _card_time(key), 0.0, 1.0)
	if bool(lab[PLAYER].paused) or bool(item.paused): result.status = "Paused"; return result
	var active := -1
	for k in items.size():
		if not bool(items[k].paused): active = k; break
	result.status = "Queued"
	if active == index: result.status = "Waiting" if str(item.get("waiting_for", "")) != "" else "Researching"
	return result


func _clear_all() -> void:   # clears SELECTION + sidebar back to the bare map — never touches wired connections
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


func _host_at(p: Vector2) -> int:   # the host under a screen point — only one the player can see (fog of war)
	if not _map_rect().has_point(p): return -1
	var hit := -1; var nearest := INF
	for i in hosts.size():
		var distance := p.distance_to(_w2s(hosts[i].pos))
		if distance <= maxf(22, _r(i) * _zoom + 5) and distance < nearest and _visible_to(PLAYER, i):
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
	_cmd(["wire", sel.keys(), dest])


func _do_wire(fac: int, sources: Array, dest: int) -> void:
	if not _host_ok(dest): return
	var join_attack := false
	for i in hosts.size():   # fac's buildings already wired into dest: is that an attack in progress?
		if int(hosts[i].owner) == fac and int(hosts[i].assign) == dest and bool(hosts[i].live) and str(hosts[i].mode) == "attack": join_attack = true
	var done := 0; var nopath := 0
	for s in sources:
		var i := int(s)
		if not _owns(fac, i) or i == dest: continue
		if _route(i, dest).is_empty(): nopath += 1; continue
		if int(hosts[i].assign) != dest:
			hosts[i].assign = dest; hosts[i].live = join_attack; hosts[i].mode = "attack"; _next_depart.erase(i); hosts[i].assault = {}
		done += 1
	if fac != PLAYER: return
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
		_flash("No path to %s — links can only run through your own buildings" % str(hosts[dest].name))
	_refresh_panel(); queue_redraw()


# LAUNCH: the button on the TARGET's panel — turns every dormant connection into `t` live, together.
# Added contributors join an existing attack; new inactive targets need explicit launch.
func _launch(t: int, mode := "attack") -> void: _cmd(["launch", t, mode])   # "scan" = quiet reveal; "attack" = alarms, wounds, reveals as it lands


func _do_launch(fac: int, t: int, mode: String) -> void:
	if not _host_ok(t) or not mode in ["attack", "scan"]: return
	if mode == "scan" and _scanned(fac, t):
		if fac == PLAYER: _flash("Already scanned. Choose Attack to send combat bots.")
		return
	var started := 0; var unrouted := 0
	for i in hosts.size():
		if int(hosts[i].owner) != fac or int(hosts[i].assign) != t or bool(hosts[i].live): continue
		if _route(i, t).is_empty(): unrouted += 1; continue
		hosts[i].live = true; hosts[i].mode = mode; _next_depart[i] = _t; started += 1
	if fac != PLAYER: return
	var verb := "Scanning quietly" if mode == "scan" else ("Attacking blind (alarm raised)" if not _scanned(PLAYER, t) else "Attacking")
	if started > 0: _flash("%s %s — %d flow(s) launched%s" % [verb, str(hosts[t].name), started, ("  ·  %d held (no route)" % unrouted) if unrouted > 0 else ""])
	elif unrouted > 0: _flash("Cannot launch on %s — no routes (capture a bordering building first)" % str(hosts[t].name))
	else: _flash("Nothing to launch — no dormant connections into %s" % str(hosts[t].name))
	_refresh_panel(); queue_redraw()


# ASSAULT: every source of yours wired into `t` (dormant, or streaming at it) that has no order of its own gets one:
# pct % of the garrison it can send RIGHT NOW — a fixed number that later regeneration, reinforcements, more wires or
# pressing again never enlarge. It replaces that source's stream into t. A source already under an order keeps it.
func _assault(t: int, pct := -1) -> void: _cmd(["assault", t, _assault_pct if pct < 0 else pct])
func _cancel_assault(t: int) -> void: _cmd(["unassault", t])


func _do_assault(fac: int, t: int, pct: int) -> void:
	if not _host_ok(t) or not ASSAULT_COMMITS.has(pct): return
	if int(hosts[t].owner) == fac:
		if fac == PLAYER: _flash("An assault needs a hostile target")
		return
	var started := 0; var bots := 0; var kept := 0; var unrouted := 0; var empty := 0
	for i in hosts.size():
		if int(hosts[i].owner) != fac or int(hosts[i].assign) != t: continue
		if _assault_active(i): kept += 1; continue
		if _route(i, t).is_empty(): unrouted += 1; continue
		var quota := _assault_quota(i, pct)
		if quota < 1: empty += 1; continue
		hosts[i].assault = {"t": t, "left": quota, "total": quota, "sent": 0, "at": _t, "pct": pct}
		hosts[i].mode = "assault"; hosts[i].live = true; _next_depart[i] = _t
		started += 1; bots += quota
	if fac != PLAYER: return
	if started > 0:
		var why := ("  ·  %d already assaulting" % kept if kept > 0 else "") + ("  ·  %d without a route" % unrouted if unrouted > 0 else "")
		var over := (" · OVERCHARGED: each bot hits ×%s" % str(_assault_power(pct))) if pct > 100 else ""
		_flash("Assault on %s: %d bots from %d source(s) at %d/s each%s · %d Intel · their farms rest until it ends%s" % [str(hosts[t].name), bots, started, int(ASSAULT_RATE), over, int(ceil(float(bots) * _assault_intel(pct))), why])
	elif kept > 0: _flash("Already assaulting %s — cancel it to give a new order" % str(hosts[t].name))
	elif unrouted > 0: _flash("No route to %s — links can only run through your own buildings" % str(hosts[t].name))
	elif empty > 0: _flash("No bots to commit — the connected sources are empty")
	else: _flash("Nothing to assault with — connect sources to %s first" % str(hosts[t].name))
	_refresh_panel(); queue_redraw()


func _do_unassault(fac: int, t: int) -> void:   # cancel: unsent bots stay home, packets already out fly on
	if not _host_ok(t): return
	var n := 0; var kept := 0
	for i in hosts.size():
		if int(hosts[i].owner) != fac: continue
		var order := _assault_of(i)
		if order.is_empty() or int(order.t) != t: continue
		kept += int(order.left); n += 1
		_end_assault(i)
	if n > 0 and fac == PLAYER and _camp: _camp_cancelled = true
	if fac != PLAYER: return
	if n > 0: _flash("Assault on %s cancelled — %d unsent bots stay home" % [str(hosts[t].name), kept])
	_refresh_panel(); queue_redraw()


# STOP: pause every live attack flow into `t` — the wires stay, ready to launch again
func _halt(t: int) -> void: _cmd(["halt", t])


func _do_halt(fac: int, t: int) -> void:   # pause every live flow of fac's into t — the wires stay
	if not _host_ok(t): return
	var n := 0
	for i in hosts.size():
		if int(hosts[i].owner) == fac and int(hosts[i].assign) == t and bool(hosts[i].live):
			if _assault_active(i): _end_assault(i)
			else: hosts[i].live = false; _next_depart.erase(i)
			n += 1
	if fac != PLAYER: return
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





# ---- player commands: the one door through which a person changes the match ----
# Single player applies a command at once. Multiplayer queues it for the lockstep (_mp_begin_turn), and every screen
# applies it at the same step for the faction that sent it. Commands are plain arrays because they travel as JSON
# (server/PROTOCOL.md); _apply_cmd checks every field, so a malformed one does nothing — identically everywhere.
func _cmd(c: Array) -> void:
	if _camp and _camp_hold_left > 0.0: _camp_acted_in_hold = true   # acting during a result: the next step won't open frozen
	if _camp_paused: _camp_set_pause(false)   # taking any action resumes the campaign's reading pause
	if not _mp_on: _apply_cmd(PLAYER, c); return
	if _out or won or lost: return
	_mp_queue.append(c)


func _apply_cmd(fac: int, c: Array) -> void:
	if c.is_empty() or not botnets.has(fac) or _eliminated.has(fac): return
	var n := c.size()
	match str(c[0]):
		"wire": if n == 3 and c[1] is Array: _do_wire(fac, (c[1] as Array).slice(0, 64), _int(c[2]))
		"launch": if n == 3: _do_launch(fac, _int(c[1]), str(c[2]))
		"assault": if n == 3: _do_assault(fac, _int(c[1]), _int(c[2]))
		"unassault": if n == 2: _do_unassault(fac, _int(c[1]))
		"regenhold": if n == 1: _do_regen_hold(fac)
		"access": if n == 2: _do_access(fac, _int(c[1]))
		"resolve": if n == 3: _do_resolve(fac, _int(c[1]), str(c[2]))
		"halt": if n == 2: _do_halt(fac, _int(c[1]))
		"unwire": if n == 2: _do_unwire(fac, _int(c[1]))
		"build": if n == 4: _do_build(fac, _int(c[1]), _int(c[2]), str(c[3]))
		"job": if n == 3: _do_toggle_job(fac, _int(c[1]), _int(c[2]))
		"cancel": if n == 3: _do_cancel_job(fac, _int(c[1]), _int(c[2]))
		"demolish": if n == 3: _do_demolish(fac, _int(c[1]), _int(c[2]))
		"produce": if n == 3: _do_produce(fac, _int(c[1]), _int(c[2]))
		"research": if n == 2: _do_research(fac, str(c[1]))
		"unresearch": if n == 2: _do_unresearch(fac, str(c[1]))
		"card": if n == 3 and _host_ok(_int(c[2])): _play_card(fac, str(c[1]), _int(c[2]))


func _int(v: Variant) -> int:   # a JSON number (or anything else) as a building / slot index; garbage becomes -1
	return int(v) if (v is int or v is float) and is_finite(float(v)) else -1


func _host_ok(i: int) -> bool: return i >= 0 and i < hosts.size()
func _owns(fac: int, i: int) -> bool: return _host_ok(i) and int(hosts[i].owner) == fac


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
	if _mp_on:   # people only: every faction in the match is a player, no AI
		ais = []; botnets = humans.duplicate(); town_seed = _opt_seed; ai_level = {}
		return
	var pool := [RIVAL, RIVAL2, RIVAL3]
	ais = []
	for k in clampi(_opt_enemies, 1, 3): ais.append(pool[k])
	botnets = [PLAYER] + ais
	town_seed = _opt_seed   # 0 = random
	ai_level = {}
	for fac in ais: ai_level[fac] = _opt_ai_level if AI_LEVELS.has(_opt_ai_level) else "normal"


func _reset() -> void:   # a NEW town every restart, with the current options
	won = false; lost = false; _end_shown = false; _end_cause = ""; paused = false; _t = 0.0; _sim_acc = 0.0
	_emit_cursor = 0; _panel_t = 0.0
	_departures.clear(); _resource_samples.clear(); _defender_samples.clear(); _eliminated.clear()
	_panel_context = ""; _msg_t = 0.0; _msg_priority = 0
	_tab = ""; _hold = {}; _deck_drag_restore = false; _bank_alert = {}
	_tut = false; _ai_paused = false
	_tut_stage = 0; _tut_connected = false; _tut_attacked = false; _tut_combined = false; _tut_captured = false; _tut_target = -1; _tut_second = -1
	_camp = false; _camp_paused = false; _camp_chapter = 0; _camp_clock = 0.0; _camp_replay = false
	_camp_supplied = {}; _camp_events = {}; _camp_cash_landed = 0; _camp_detect_mark = 0.0; _camp_cancelled = false; _camp_src = -1
	_camp_home = -1; _camp_support = -1; _camp_relay = -1; _camp_gateway = -1; _camp_vault = -1; _camp_commrelay = -1; _camp_rivalhq = -1; _camp_practice = -1; _camp_practice2 = -1; _camp_guard = -1; _camp_foothold = -1; _camp_hold_left = 0.0; _camp_hold_text = ""; _camp_hold_target = -1; _camp_acted_in_hold = false
	if tut_panel != null: tut_panel.visible = false
	_apply_options()
	_clear_all()
	_gen()
	if _opt_mission: _author_scenario_mission()
	_refresh_sight(); _fit_view(); _refresh_panel(); _refresh_hand(); _refresh_top_tabs()


# Author one records objective into a freshly generated town: the richest neutral non-rig computer holds the records,
# and a rim neutral computer is the community relay the Publish choice can borrow. Entirely game state.
const SCENARIO_CORPS := ["Kessler Finance", "Halcyon Mutual", "Ostrava Credit Union", "Brightline Holdings"]
func _author_scenario_mission() -> void:
	var best := -1; var bv := -1.0
	for i in hosts.size():
		if int(hosts[i].owner) != NEUTRAL or bool(hosts[i].rig) or bool(hosts[i].hub): continue
		var v := float(hosts[i].value) * 2.0 + float(int(hosts[i].slots)) + (2.0 if str(hosts[i].type) in ["db", "file", "erp"] else 0.0)
		if v > bv: bv = v; best = i
	if best < 0: return
	hosts[best].sec = maxf(float(hosts[best].sec), 90.0); hosts[best].bots = float(hosts[best].sec)   # a defended vault
	_setup_mission(best, 8, SCENARIO_CORPS[town_seed % SCENARIO_CORPS.size()], "A neighbourhood's debt records are held here.")
	hosts[best].name = "%s · Records" % str(hosts[best].get("corp", "Vault"))
	var relay := -1; var rd := INF
	for i in hosts.size():
		if int(hosts[i].owner) != NEUTRAL or bool(hosts[i].rig) or i == best or _is_mission(i): continue
		if float(hosts[i].value) > 1.5: continue   # a rim (low-value) computer
		var d: float = (hosts[i].pos as Vector2).distance_to(hosts[int(rig[PLAYER])].pos)
		if d < rd: rd = d; relay = i
	if relay >= 0: hosts[relay].relay = true; hosts[relay].name = "Community Relay"


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
	icon.col = C_BAD if action in ["Disconnect", "Stop", "Cancel assault"] else (BANK_COL["attack"] if action in ["Attack", "Assault"] or action.ends_with("%") else C_GOOD)   # attack = red everywhere
	if action.ends_with("%") and float(action.trim_suffix("%")) > 100.0: icon.col = C_WARN   # an overcharge reads as a premium at a glance
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	button.custom_minimum_size = Vector2(96, 44)
	button.disabled = not enabled
	button.add_theme_font_size_override("font_size", 20)
	button.clip_text = true
	button.add_theme_color_override("font_color", C_BAD if action in ["Disconnect", "Stop", "Cancel assault"] else (C_WARN if action == "Attack" else C_GOOD))
	if action in ["Disconnect", "Stop", "Cancel assault"]:
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
	var parts := PackedStringArray([str(roundi(_t * 30.0)), str(flights.size())])
	for h in hosts:
		parts.append("%d,%d,%d,%d,%d,%s,%s,%s,%s,%d,%d,%d" % [int(h.owner), roundi(float(h.bots) * 1000.0), roundi(float(h.sec) * 1000.0), int(h.assign), int(bool(h.live)), str(h.get("mode", "")), ",".join(PackedStringArray(h.builds)), JSON.stringify(h.jobs), JSON.stringify(h.get("assault", {})), int(h.get("access_by", -1)), roundi(float(h.get("access_until", 0.0)) * 1000.0), roundi(float(h.get("alert", 0.0)) * 100.0)])
	for fac in botnets:
		parts.append("%d:%d:%d:%d:%d:%d" % [fac, roundi(float(intel[fac]) * 1000.0), roundi(float(cash[fac]) * 1000.0), roundi(float(creds[fac]) * 1000.0), roundi(float(research[fac]) * 1000.0), int(bool(regen_hold.get(fac, false)))])
		parts.append(JSON.stringify(cards[fac]) + JSON.stringify(lab[fac]))   # held cards, research queue and progress
	parts.append(JSON.stringify(records_home) + JSON.stringify(mission_done))
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
	_menu_label("AI difficulty")
	var drow := HBoxContainer.new(); drow.add_theme_constant_override("separation", 6)
	for level in AI_LEVELS:
		var b := Button.new(); b.text = str(level).capitalize(); b.name = "AI_%s" % level
		b.custom_minimum_size = Vector2(0, 36); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.focus_mode = Control.FOCUS_ALL
		if _opt_ai_level == level: b.add_theme_color_override("font_color", C_BAD if level == "insane" else C_GOOD)
		if level == "insane" and not INSANE_READY: b.disabled = true; b.text = "Insane · in progress"
		b.pressed.connect(func(l = level): _opt_ai_level = l; _refresh_menu())
		drow.add_child(b)
	menu_box.add_child(drow)
	if _opt_ai_level == "insane": _menu_label("Insane plays fair (same fog, same rules) but scouts, models your economy from what it sees, plans a win and micro-manages every attack.")
	_menu_label("Objective")
	var mrow := HBoxContainer.new(); mrow.add_theme_constant_override("separation", 6)
	for opt in [[false, "Conquest"], [true, "+ Records mission"]]:
		var b := Button.new(); b.text = str(opt[1]); b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.focus_mode = Control.FOCUS_ALL
		if _opt_mission == bool(opt[0]): b.add_theme_color_override("font_color", C_GOOD)
		b.pressed.connect(func(v = bool(opt[0])): _opt_mission = v; _refresh_menu())
		mrow.add_child(b)
	menu_box.add_child(mrow)
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


const HELP_PAGES := ["network", "build", "resources", "cards", "protection", "goal"]
const HELP_TITLES := ["Connect. Scan. Attack.", "Turn empty slots into production.", "Three production chains.", "ATTACK cards: research below, drag to play.", "DEFENCE cards protect your own hosts.", "Grow your network. Protect your rig."]

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
		"ai": _opt_ai_level,
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
		{"title": "Connect", "text": "Drag from YOUR RIG to TARGET. A dashed connection is a plan; it spends nothing. You see only your hosts, their neighbours and the rival rig: the rest is fog."},
		{"title": "Scan, then attack", "text": "Press Scan on %s's panel. When it finishes, the same button becomes Attack. Press it to capture." % target},
		{"title": "Combine", "text": "Drag SUPPORT to the same target. It immediately joins the running attack."},
		{"title": "Capture", "text": "Watch the target's defenders fall. Your connected sources become automatic guards when it turns green."},
		{"title": "Build", "text": "Select your captured building. Click Intel harvester below its slots. Wait for construction to finish."},
		{"title": "Research", "text": "Click Phishing in the deck at the bottom. Training support supplies all three inputs; watch its bar fill. ATTACK or C pulls the full cards up."},
		{"title": "Play a card", "text": "Drag your Phishing card from the deck onto a highlighted enemy to steal its production."},
		{"title": "Ready", "text": "Hold at least 51% of the town for 51 seconds, or capture the rival rig. Losing your rig ends the match."},
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
	"Phishing card": "card:phishworm", "Phishing": "card:phishworm", "0day": "card:zeroday", "DDOS": "card:ddos", "DDoS": "card:ddos",
	"DDOSed": "card:ddos", "Supply chain attack": "card:supply", "Supply chain attacks": "card:supply", "Supply": "card:supply",
	"CDN": "card:cdn", "Patch day": "card:patch", "Incident response": "card:response", "SCA": "card:sca",
	"ATTACK": "bank:attack", "DEFENCE": "bank:defense",
	# panel buttons: the button's colour (+ its glyph where one exists)
	"Scan": "act:Scan", "Attack": "act:Attack", "Assault": "act:Assault", "Cancel assault": "act:Cancel assault",
	"Establish access": "act:Establish access", "Sell": "act:Sell", "Publish": "act:Publish", "CUT": "cut",
	# computers: their CURRENT owner's colour (neutral = the gold highlight ring), no icon
	"YOUR RIG": "rig:p", "rival rig": "rig:r", "rival's rig": "rig:r", "Support": "role:support", "Neighborhood Relay": "role:relay",
	"relay": "role:relay", "Community Relay": "role:commrelay", "Corporate Gateway": "role:gateway", "Gateway": "role:gateway",
	"Practice host": "role:practice", "Practice host 2": "role:practice2", "Records vault": "role:vault", "vault": "role:vault",
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
			return [BANK_COL["defense" if bool(cd.get("defense", false)) else "attack"], "fam:" + str(cd.fam), Color.WHITE]
		"bank": return [BANK_COL[k], "", Color.WHITE]
		"act":
			var col: Color = BANK_COL["attack"]
			if k in ["Scan", "Establish access", "Publish"]: col = C_GOOD
			elif k == "Cancel assault": col = C_BAD
			elif k == "Sell": col = BUILD_KINDS.cash.col
			return [col, ("a:" + k) if k in ["Scan", "Attack", "Assault", "Cancel assault"] else "", col]
		"role":
			var h := _camp_role_host(k) if _camp else -1
			var c: Color = C_WARN   # neutral: the gold of the highlight ring
			if h >= 0 and h < hosts.size() and int(hosts[h].owner) != NEUTRAL: c = fcol(int(hosts[h].owner))
			return [c, "", Color.WHITE]
		"rig", "fac": return [fcol(PLAYER if k == "p" else RIVAL), "", Color.WHITE]
		"cut": return [Color(1, 0.4, 0.65), "", Color.WHITE]   # the map's CUT timer colour
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
	var ids := [["k", "bot"], ["k", "intel"], ["k", "cash"], ["k", "cred"], ["k", "lab"], ["a", "Scan"], ["a", "Attack"], ["a", "Assault"], ["a", "Cancel assault"]]
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


func _start_tutorial() -> void:
	_opt_size = SIZE_PRESETS[0]; _opt_enemies = 1; _opt_seed = 7
	_reset()
	for fac in ais: ai_level[fac] = "normal"   # the tutorial's rival is always the Normal one
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
	_link(source, _tut_target); _link(_tut_second, _tut_target); _refresh_sight()
	cash[PLAYER] = 100.0; creds[PLAYER] = 100.0; research[PLAYER] = 100.0
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
		5: done = _held(PLAYER, "phishworm:linked") > 0 or int(card_plays.get(PLAYER, 0)) > 0
		6: done = int(card_plays.get(PLAYER, 0)) > 0
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


# ============================================================ GUIDED CAMPAIGN
# Six chapters of ONE continuous game on CAMP_SEED. Chapters are phases; the step within a chapter reuses _tut_stage.
# Advancement is gated on real game-state outcomes (never a click, a timer, or a card launched-but-not-arrived).
# A reading pause (_camp_paused) freezes the WHOLE simulation; the player resumes with Space or by taking the action.
func _camp_chapters() -> Array:
	return ["Get Connected", "Establish Income", "Protect the Network", "Use Special Actions", "Recover the Records", "Choose Your Approach"]


# Each step: t title · r RESULT (what it did, shown for a few seconds once done) · a ACTION (what to do, shown bold) · w WHY (one short reason)
# · role (the TARGET computer, ringed on the map)
# · from (the computer a drag starts at: a green FROM marker + arrow until that wire exists) · ui (the UI element(s) to blink:
# "card:<id>" deck/hand card, "build:<kind>" palette card, "btn:<name>" panel button) · card (the step's card copy, handed back
# if it is used up) · pause (freeze for reading on entry) · fire (scripted beat on entry) · fire_leave (beat when the step completes).
# Text rules: plain words, no repetition, and every name is exactly what the map or the UI shows. {from} = the FROM computer's name.
func _camp_steps(chapter: int) -> Array:
	match chapter:
		0: return [
			{"t": "Your home computer", "r": "Connected. Your bots can now travel from YOUR RIG to the relay.", "a": "Drag from YOUR RIG onto the Neighborhood Relay to connect them.", "w": "YOUR RIG is your home base. Lose it and you lose the game.", "role": "relay", "from": "home", "pause": true},
			{"t": "Scan the relay", "r": "Scanned. The number on the relay now shows its real defenders.", "a": "Press the blinking Scan button, then wait for the scan to finish.", "w": "You can't see a computer's defenders until you scan it.", "role": "relay", "ui": "btn:Scan", "pause": true},
			{"t": "Attack with two", "r": "Your bots are wearing the relay down — watch its number fall.", "a": "Press Attack, then drag from Support onto the relay to add its bots.", "w": "Bots fight defenders one for one. Two attackers win faster.", "role": "relay", "from": "support", "ui": "btn:Attack", "pause": true},
			{"t": "Capture", "r": "The Neighborhood Relay is yours. Its slots can now hold your installations.", "a": "Keep attacking until the relay turns green.", "w": "When its defenders reach zero, the computer becomes yours.", "role": "relay", "pause": false},
		]
		1: return [
			{"t": "Make Intel", "r": "The Intel harvester is running — your Intel income went up.", "a": "Select the relay, then click the blinking Intel harvester card.", "w": "Computers have slots for installations. An Intel harvester makes Intel.", "role": "relay", "ui": "build:intel", "pause": true},
			{"t": "Make Crypto", "r": "The Crypto miner is turning Intel into Crypto packets.", "a": "Click the blinking Crypto miner card.", "w": "A Crypto miner turns Intel into Crypto, the money for farms and cards.", "role": "relay", "ui": "build:cash", "pause": true},
			{"t": "Bring it home", "r": "Crypto arrived home — see your Crypto at the top of the screen.", "a": "Wait for a Crypto packet to reach YOUR RIG.", "w": "Crypto counts only when it arrives home.", "role": "home", "pause": false},
			{"t": "Spend it", "r": "The Bot farm will now refill the relay's defenders over time.", "a": "Click the blinking Bot farm card (30 Crypto).", "w": "A Bot farm grows new defenders on the relay over time.", "role": "relay", "ui": "build:bot", "pause": true, "fire": "ch1_cash"},
		]
		2: return [
			{"t": "Guard Support", "r": "Support is guarded: if it is attacked, {from} sends help.", "a": "Drag from {from} onto Support (follow the green arrow).", "w": "A connection between two of your computers is a guard: it sends bots only when Support is attacked.", "role": "support", "from": "guard", "pause": true},
			{"t": "Assault", "r": "The Assault is on — watch the sender's bots drop as they leave.", "a": "Drag from {from} onto the Corporate Gateway, then press the blinking Assault button.", "w": "An Assault sends a fixed share of bots fast; the sender is left thin.", "role": "gateway", "from": "src", "ui": "btn:Assault", "pause": true},
			{"t": "Pull back", "r": "Cancelled. The bots that had not left yet stay home.", "a": "Press the blinking Cancel assault button.", "w": "Unsent bots stay home. Bots already on the way still arrive.", "role": "gateway", "ui": "btn:Cancel assault", "pause": true},
			{"t": "Hold through a cut", "r": "Support held, and its route is back. Your guard kept working through the cut.", "a": "Keep Support guarded and hold until the CUT timer under it runs out.", "w": "The Corporate Gateway hit back and cut Support's routing. Your guard still sends help, and the cut wears off.", "role": "support", "from": "guard", "pause": false, "fire": "ch2_cut"},
		]
		3: return [
			{"t": "Card workshop", "r": "The workshop is running: Credentials and Research now flow in.", "a": "Select the relay, then click the blinking Credential harvester and Research lab cards.", "w": "Cards cost Crypto, Credentials and Research. The harvester makes Credentials; the lab turns Crypto into Research.", "role": "relay", "ui": ["build:cred", "build:lab"], "pause": true, "fire_leave": "ch3_stock"},
			{"t": "Prepare Phishing", "r": "Phishing is ready. A prepared card waits at the bottom until you play it.", "a": "Click the blinking Phishing card at the bottom and wait for its bar to fill.", "w": "A card must be prepared before you can play it. Phishing lets you steal a rival's output.", "role": "", "ui": "card:phishworm", "pause": true},
			{"t": "Phishing", "r": "The Practice host's output now comes to you — and it still pays the costs.", "a": "Drag Phishing onto the Practice host.", "w": "Its output now comes to you, but the computer stays theirs.", "role": "practice", "ui": "card:phishworm", "card": "phishworm:linked", "pause": true},
			{"t": "Incident response", "r": "The theft stopped. Your relay's output is yours again.", "a": "Drag the blinking Incident response card onto the Neighborhood Relay.", "w": "A rival is phishing your relay. Incident response stops the theft.", "role": "relay", "ui": "card:response", "card": "response:linked", "pause": true, "fire": "ch3_phish"},
			{"t": "DDOS", "r": "The Practice host is frozen: no production and no traffic for a while.", "a": "Drag DDOS onto the Practice host.", "w": "DDOS stops a computer's production and traffic for a while. It does not capture it.", "role": "practice", "ui": "card:ddos", "card": "ddos:linked", "pause": true},
			{"t": "CDN", "r": "Your relay is back online.", "a": "Drag CDN onto the Neighborhood Relay.", "w": "A rival DDOSed your relay. CDN brings it back online.", "role": "relay", "ui": "card:cdn", "card": "cdn:linked", "pause": true, "fire": "ch3_ddos"},
			{"t": "0day", "r": "Practice host 2 is yours — taken without sending a single bot.", "a": "Drag 0day onto Practice host 2.", "w": "0day tries to take a computer you are connected to. It can miss; you'll get another copy.", "role": "practice2", "ui": "card:zeroday", "card": "zeroday:linked", "pause": true},
			{"t": "Patch day", "r": "Support is shielded. Watch: the rival's 0day bounces off.", "a": "Drag Patch day onto Support.", "w": "Patch day shields a computer from 0day and Supply chain attacks for a while.", "role": "support", "ui": "card:patch", "card": "patch:linked", "pause": true, "fire_leave": "ch3_0day"},
			{"t": "Supply chain attack", "r": "The Practice host lost its installations and bots — but it still belongs to the rival.", "a": "Drag Supply chain attack onto the Practice host.", "w": "It wipes a computer's installations and bots. The owner keeps the computer.", "role": "practice", "ui": "card:supply", "card": "supply:linked", "pause": true},
			{"t": "SCA", "r": "Support is shielded. Watch: the rival's Supply chain attack bounces off.", "a": "Drag SCA onto Support.", "w": "SCA shields a computer from Supply chain attacks.", "role": "support", "ui": "card:sca", "card": "sca:linked", "pause": true, "fire_leave": "ch3_supply"},
		]
		4: return [
			{"t": "Find the opening", "r": "The vault holds records you can copy out once you have access.", "a": "Drag from {from} onto the Records vault, then press the blinking Scan button.", "w": "Scanning shows what the vault holds and how to get in.", "role": "vault", "from": "foothold", "ui": "btn:Scan", "pause": true},
			{"t": "Get access", "r": "Access is open: records start flowing toward YOUR RIG.", "a": "Press the blinking Establish access button.", "w": "Access lets records flow out. The vault still belongs to its owner.", "role": "vault", "ui": "btn:Establish access", "pause": true},
			{"t": "Extract", "r": "The first record is home.", "a": "Wait for a record to reach YOUR RIG.", "w": "A record counts only when it arrives home.", "role": "vault", "pause": false},
			{"t": "They notice", "r": "The records kept flowing despite the cut.", "a": "Wait for the cut route to recover, then bring home one more record.", "w": "Taking records raises an alarm, so the owner cuts your route for a while.", "role": "vault", "pause": false, "fire": "ch4_detect"},
			{"t": "Decide", "r": "Done.", "a": "Bring home all the records, then press Sell or Publish.", "w": "Sell pays Crypto. Publish opens the Community Relay to you.", "role": "vault", "ui": ["btn:Sell", "btn:Publish"], "pause": false},
		]
		_: return [
			{"t": "Your move", "r": "Victory.", "a": "Win the district your way — any route, any tools.", "w": "Hold over half the computers for 51 seconds, or capture the rival rig. Lose your rig and you lose.", "role": "", "pause": true},
		]


func _camp_role_host(role: String) -> int:
	match role:
		"home": return _camp_home
		"support": return _camp_support
		"relay", "income": return _camp_relay
		"gateway", "frontier": return _camp_gateway
		"vault": return _camp_vault
		"commrelay": return _camp_commrelay
		"rivalhq": return _camp_rivalhq
		"practice": return _camp_practice
		"practice2": return _camp_practice2
		"guard": return _camp_guard
		"src": return _camp_src
		"foothold": return _camp_foothold
	return -1


func _camp_target() -> int:
	if not _camp: return -1
	if _camp_hold_left > 0.0: return _camp_hold_target
	var steps := _camp_steps(_camp_chapter)
	if _tut_stage < 0 or _tut_stage >= steps.size(): return -1
	if _camp_chapter == 5: return -1   # the open chapter highlights nothing
	return _camp_role_host(str(steps[_tut_stage].get("role", "")))


func _camp_step() -> Dictionary:
	if not _camp: return {}
	var s := _camp_steps(_camp_chapter)
	return s[_tut_stage] if _tut_stage >= 0 and _tut_stage < s.size() else {}


func _camp_pulse() -> float:   # 0..1 on the wall clock, so cues keep beating through the reading pause
	return 0.5 + 0.5 * sin(_camp_clock * TAU * 1.4)


func _camp_from() -> int:   # the FROM computer of the step's drag guide; -1 once that wire exists
	var st := _camp_step()
	if st.is_empty() or _camp_chapter == 5 or _camp_hold_left > 0.0: return -1
	var f := _camp_role_host(str(st.get("from", ""))); var t := _camp_target()
	if f < 0 or t < 0 or f == t or not _mine(f) or int(hosts[f].assign) == t: return -1
	return f


func _camp_fill(s: String) -> String:   # {from} -> the FROM computer's live name
	var f := _camp_role_host(str(_camp_step().get("from", "")))
	return s.replace("{from}", str(hosts[f].name) if f >= 0 and f < hosts.size() else "one of your computers")


func _camp_ui_targets() -> Array:   # the live Controls the step names, re-found every frame (panel and hand rebuild freely)
	var st := _camp_step()
	if st.is_empty() or menu_open or won or lost or _camp_hold_left > 0.0: return []
	var specs = st.get("ui", [])
	if specs is String: specs = [specs]
	var out := []
	for spec in specs:
		var p := str(spec).split(":", true, 1)
		if p.size() != 2: continue
		match p[0]:
			"card": out.append_array(_camp_card_ctrls(_card_key(p[1], "linked")))
			"build": out.append_array(_camp_build_ctrls(p[1]))
			"btn": out.append_array(_panel_find(func(c): return c is Button and c.is_visible_in_tree() and (str(c.name) == p[1] or c.text.begins_with(p[1]))))
	return out


func _camp_card_ctrls(key: String) -> Array:   # deck down: its chip · deck up on the other bank: that tab · else its big card
	if not _deck_open: return _deck_chip_nodes().filter(func(c): return str(c.key) == key)
	var bank := _bank_of(key)
	if bank != _card_bank: return [card_banks.get_child(0 if bank == "attack" else 1)]
	return hand_bar.get_children().filter(func(c): return str(c.key) == key and c.visible)


func _camp_build_ctrls(kind: String) -> Array:   # the palette card, while the selected computer still lacks that installation
	var h := int(sel.keys()[0]) if sel.size() == 1 else _inspect
	if h < 0 or not _mine(h) or _count_all(h, kind) > 0: return []
	for j in (hosts[h].jobs as Dictionary).values():
		if str(j.get("kind", "")) == kind and str(j.get("phase", "build")) == "build": return []
	return _panel_find(func(c): return c is BuildCard and c.kind == kind)


func _panel_find(ok: Callable) -> Array:
	var out := []; var stack: Array = panel_box.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if ok.call(n): out.append(n)
		stack.append_array(n.get_children())
	return out


func _camp_guard_src() -> int:   # Ch2 FROM: can guard Support; not the Assault source (the next lesson would rewire it), not the rig; nearest
	var t := _camp_support
	if t < 0: return -1
	return _camp_pick(func(i): return _mine(i) and i != t and _link_kind(i, t) == "defend",
		func(i): return [1 if i == _camp_src else 0, 1 if bool(hosts[i].rig) else 0, _route(i, t).size(), i])


# ---- role selection (deterministic BFS from Home) ----
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
	_camp_home = int(rig[PLAYER]); _camp_rivalhq = int(rig[RIVAL])
	_camp_support = -1
	for i in hosts.size():
		if _mine(i) and i != _camp_home: _camp_support = i; break
	var dist := _camp_bfs(_camp_home)
	# relay: a neutral neighbour of home or support, lowest [sec, index]
	_camp_relay = _camp_pick(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub) and (hosts[_camp_home].links.has(i) or (_camp_support >= 0 and hosts[_camp_support].links.has(i))),
		func(i): return [float(hosts[i].sec), i])
	# vault: a high-value neutral db/file/erp, far-ish; max [value, dist], min index
	_camp_vault = _camp_pick(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub) and str(hosts[i].type) in ["db", "file", "erp"] and i != _camp_relay,
		func(i): return [-float(hosts[i].value), -int(dist.get(i, 0)), i])
	# gateway: a neutral neighbour of the vault reachable from home avoiding the vault (so vault->gateway->home routes)
	_camp_gateway = _camp_pick(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub) and i not in [_camp_relay, _camp_vault] and hosts[_camp_vault].links.has(i) and _camp_bfs(_camp_home, _camp_vault).has(i),
		func(i): return [int(_camp_bfs(_camp_home, _camp_vault).get(i, 99)), float(hosts[i].sec), i])
	if _camp_gateway < 0:   # fallback: any neutral neighbour of the vault
		_camp_gateway = _camp_pick(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub) and i not in [_camp_relay, _camp_vault] and hosts[_camp_vault].links.has(i), func(i): return [i])
	# community relay: a rim (value 1) neutral, nearest
	_camp_commrelay = _camp_pick(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub) and int(hosts[i].value) == 1 and i not in [_camp_relay, _camp_vault, _camp_gateway],
		func(i): return [int(dist.get(i, 99)), i])
	# two rival practice computers for the card lessons: neutrals near home (chapter 3 makes them rival-owned)
	var prac := _camp_all(func(i): return int(hosts[i].owner) == NEUTRAL and not bool(hosts[i].hub) and i not in [_camp_relay, _camp_vault, _camp_gateway, _camp_commrelay],
		func(i): return [int(dist.get(i, 99)), i])
	_camp_practice = prac[0] if prac.size() > 0 else -1
	_camp_practice2 = prac[1] if prac.size() > 1 else -1


func _camp_pick(ok: Callable, key: Callable) -> int:   # the best host satisfying ok() by ascending key()
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


# ---- authored board per chapter checkpoint (idempotent; keyed on role indices only) ----
func _camp_own(i: int) -> void:
	if i >= 0 and not _mine(i):
		_capture(i, PLAYER)
		hosts[i].bots = maxf(float(hosts[i].bots), _cap_of(i))   # authored ownership starts garrisoned, not with _capture's negative overflow


func _camp_grant(i: float, c: float, k: float, r: float) -> void:   # called after the chapter's _set_builds, so the Intel limit is final
	intel[PLAYER] = maxf(float(intel[PLAYER]), minf(i, _intel_cap(PLAYER))); cash[PLAYER] = maxf(float(cash[PLAYER]), c)   # Intel is hard-capped: never show "200/115"
	creds[PLAYER] = maxf(float(creds[PLAYER]), minf(k, _res_cap(PLAYER, "cred"))); research[PLAYER] = maxf(float(research[PLAYER]), minf(r, _res_cap(PLAYER, "lab")))   # never "200/50"


func _camp_supply(key: String) -> void:   # grant one prepared card copy once, announced
	var id := "%d:%s" % [_camp_chapter, key]
	if _camp_supplied.get(id, false): return
	_camp_supplied[id] = true
	cards[PLAYER][key] = int(_held(PLAYER, key)) + 1


func _camp_slots(i: int, n: int) -> void:
	if i >= 0 and int(hosts[i].slots) < n: hosts[i].slots = n


func _camp_setup(chapter: int) -> void:
	_camp_own(_camp_support)
	if _camp_support >= 0: hosts[_camp_support].name = "Support"   # the banner says "Support": the map must too
	match chapter:
		0:
			hosts[_camp_relay].name = "Neighborhood Relay"; hosts[_camp_relay].sec = 40.0; hosts[_camp_relay].bots = 40.0; _set_builds(_camp_relay, [])
			_camp_grant(INTEL_START, 0.0, 0.0, 0.0)
		1:
			_camp_own(_camp_relay); _camp_slots(_camp_relay, 4); _set_builds(_camp_relay, []); hosts[_camp_relay].bots = minf(_cap_of(_camp_relay), 30.0)
			hosts[_camp_relay].name = "Neighborhood Relay"
			_camp_grant(120.0, 0.0, 0.0, 0.0)
		2:
			_camp_own(_camp_relay); _camp_slots(_camp_relay, 4); _set_builds(_camp_relay, ["intel", "cash", "bot"])
			hosts[_camp_relay].name = "Neighborhood Relay"
			hosts[_camp_support].bots = 30.0
			var front := -1; var fsrc := -1   # a rival frontier directly adjacent to an owned computer (so the assault can reach it)
			for base in [_camp_home, _camp_relay, _camp_support]:
				if base < 0 or not _mine(base): continue
				for o in hosts[base].links:
					var oi := int(o)
					if int(hosts[oi].owner) == NEUTRAL and not bool(hosts[oi].hub) and oi not in [_camp_relay, _camp_support, _camp_home]: front = oi; fsrc = base; break
				if front >= 0: break
			if front >= 0:
				hosts[front].owner = RIVAL; hosts[front].bots = 45.0; hosts[front].name = "Corporate Gateway"; _set_builds(front, ["bot"])
				_camp_gateway = front; _camp_src = fsrc; hosts[fsrc].bots = 60.0; _camp_slots(fsrc, 3)
			_camp_guard = _camp_guard_src()
			_assault_pct = ASSAULT_DEFAULT   # a 25 % pick from earlier play would be spent before Cancel can be taught
			_camp_grant(120.0, 60.0, 0.0, 0.0)
		3:
			_camp_own(_camp_relay); _camp_slots(_camp_relay, 5); _set_builds(_camp_relay, ["intel", "cash", "bot"]); hosts[_camp_relay].bots = _cap_of(_camp_relay)
			hosts[_camp_relay].name = "Neighborhood Relay"
			_camp_slots(_camp_support, 4); hosts[_camp_support].bots = 30.0
			for p in [_camp_practice, _camp_practice2]:
				if p < 0: continue
				hosts[p].owner = RIVAL; hosts[p].bots = 30.0; _camp_slots(p, 3); _set_builds(p, ["intel", "bot"])
				hosts[p].name = "Practice host" if p == _camp_practice else "Practice host 2"   # two targets, two names
			if _camp_practice2 >= 0:   # a dormant WIRE (sets assign, not just a graph edge) so 0day's needs_link is satisfied on the highlighted host
				var own0 := _nearest_owned(_camp_practice2)
				if own0 >= 0:
					_link(own0, _camp_practice2)
					hosts[own0].assign = _camp_practice2; hosts[own0].mode = "attack"; hosts[own0].live = false   # dormant: never fires on its own
			_camp_grant(200.0, 200.0, 200.0, 200.0)
			for key in ["ddos:linked", "zeroday:linked", "supply:linked", "cdn:linked", "patch:linked", "response:linked", "sca:linked"]: _camp_supply(key)
		4:
			_camp_own(_camp_relay); _camp_slots(_camp_relay, 5); _set_builds(_camp_relay, ["intel", "cash", "bot", "cred", "lab"])   # the card workshop carries over
			_setup_mission(_camp_vault, 6, "Kessler Finance", "A neighbourhood's debt records are held here.")
			hosts[_camp_vault].owner = RIVAL; hosts[_camp_vault].bots = 50.0; hosts[_camp_vault].sec = 50.0; hosts[_camp_vault].name = "Records vault"
			# own the whole corridor from home to a vault-neighbour (avoiding the vault) so records can travel home
			var foothold := _camp_gateway if (_camp_gateway >= 0 and hosts[_camp_vault].links.has(_camp_gateway)) else -1
			if foothold < 0:
				for o in hosts[_camp_vault].links:
					if int(hosts[int(o)].owner) != RIVAL: foothold = int(o); break
			if foothold >= 0: _camp_own_path(_camp_home, foothold, _camp_vault)
			_camp_foothold = foothold
			hosts[_camp_relay].name = "Neighborhood Relay"
			if _camp_commrelay >= 0: hosts[_camp_commrelay].relay = true; hosts[_camp_commrelay].name = "Community Relay"
			_camp_grant(80.0, 40.0, 80.0, 40.0)
		5:
			_camp_own(_camp_relay); _camp_slots(_camp_relay, 5); _set_builds(_camp_relay, ["intel", "cash", "bot", "cred", "lab"]); hosts[_camp_relay].bots = _cap_of(_camp_relay)
			hosts[_camp_relay].name = "Neighborhood Relay"
			_camp_grant(120.0, 120.0, 120.0, 120.0)
	_msg_t = 0.0; _msg_priority = 0   # the setup's own captures are not news (they named computers before their campaign names)
	_refresh_sight()


func _camp_own_path(a: int, b: int, avoid := -1) -> void:   # own every computer on a route a->b (so a route exists through our network)
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
		if int(hosts[n].owner) != RIVAL or n == b: _camp_own(n)
		n = int(prev[n])


func _camp_gateway_prev() -> int:   # a home-side neutral on the way to the gateway, owned to form a corridor
	if _camp_gateway < 0: return -1
	for o in hosts[_camp_gateway].links:
		if int(hosts[int(o)].owner) != RIVAL and int(o) != _camp_gateway: return int(o)
	return -1


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
	if _opt_backup.is_empty() and not _camp:   # remember the player's own New-game choices once
		_opt_backup = {"size": _opt_size, "enemies": _opt_enemies, "ai": _opt_ai_level, "mission": _opt_mission, "seed": _opt_seed}
	_opt_size = CAMP_SIZE; _opt_enemies = 1; _opt_ai_level = "normal"; _opt_mission = false; _opt_seed = CAMP_SEED
	_reset()
	for fac in ais: ai_level[fac] = "normal"
	_camp_roles()
	_camp_chapter = clampi(chapter, 0, CAMP_CHAPTERS - 1)
	_camp_supplied = {}; _camp_events = {}; _camp_cash_landed = 0; _camp_detect_mark = 0.0; _camp_cancelled = false
	_camp_setup(_camp_chapter)
	_camp = true; _tut = true; _tut_stage = 0; _camp_replay = replay
	_ai_paused = _camp_chapter < 5
	var steps := _camp_steps(_camp_chapter)
	_camp_paused = bool(steps[0].get("pause", false))
	_open_menu(false); _show_tut(); _fit_view()
	if not replay: _camp_save()


func _camp_save_path() -> String:   # the played game (main scene) keeps the real file; any harness that builds the script by hand gets its own
	return CAMP_SAVE if is_inside_tree() and get_tree().current_scene == self else CAMP_SAVE_HARNESS


func _camp_save() -> void: _camp_save_at(_camp_chapter, _tut_stage)


func _camp_save_at(chapter: int, step: int) -> void:
	var data := {"schema": 1, "game_version": GAME_VERSION, "campaign_seed": CAMP_SEED,
		"chapter": chapter, "step": step, "completed": _camp_done.count(true) >= CAMP_CHAPTERS,
		"chapters_completed": _camp_done.duplicate()}
	var f := FileAccess.open(_camp_save_path(), FileAccess.WRITE)
	if f != null: f.store_line(JSON.stringify(data)); f.close()


func _camp_load() -> Dictionary:
	if not FileAccess.file_exists(_camp_save_path()): return {}
	var f := FileAccess.open(_camp_save_path(), FileAccess.READ)
	if f == null: return {}
	var d = JSON.parse_string(f.get_as_text()); f.close()
	if not (d is Dictionary) or int((d as Dictionary).get("schema", 0)) != 1: return {}
	if int((d as Dictionary).get("campaign_seed", -1)) != CAMP_SEED:   # authoring changed: a veteran isn't re-forced, but an old checkpoint can't rebuild
		return {"completed": bool((d as Dictionary).get("completed", false)), "chapter": 0, "step": 0, "chapters_completed": [false, false, false, false, false, false]}
	var cc = (d as Dictionary).get("chapters_completed", [false, false, false, false, false, false])
	return {"completed": bool((d as Dictionary).get("completed", false)), "chapter": int((d as Dictionary).get("chapter", 0)), "step": int((d as Dictionary).get("step", 0)), "chapters_completed": cc}


func _camp_has_onboarded() -> bool:
	return bool(_camp_load().get("completed", false))


func _camp_first_run() -> void:   # force the campaign on first launch — only in the real played game, never under a test/probe harness
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


func _camp_restore_opts() -> void:   # put back the player's own New-game choices that _start_campaign overwrote
	if _opt_backup.is_empty(): return
	_opt_size = _opt_backup.get("size", _opt_size)
	_opt_enemies = int(_opt_backup.get("enemies", _opt_enemies))
	_opt_ai_level = str(_opt_backup.get("ai", _opt_ai_level))
	_opt_mission = bool(_opt_backup.get("mission", _opt_mission))
	_opt_seed = int(_opt_backup.get("seed", _opt_seed))
	_opt_backup = {}


func _camp_leave() -> void:
	_camp_save(); _camp_paused = false
	if _camp_replay: _camp_restore_opts()   # a replay ends here; the mandatory run restores them only when it is finished
	_open_menu(true)


func _camp_retry() -> void:
	_start_campaign(_camp_chapter, _camp_replay)


func _camp_finish() -> void:   # the whole campaign is done
	for k in CAMP_CHAPTERS: _camp_done[k] = true
	_camp = false; _tut = false; _camp_paused = false; _ai_paused = false
	if tut_panel != null: tut_panel.visible = false
	_camp_restore_opts()
	_camp_save()
	_flash("Training complete. The game is yours — New game is unlocked.", 0)
	_layout_ui(); _fit_view()


# ---- scripted beats (deterministic; the rival's AI is paused, so the lesson drives these directly) ----
func _camp_fire(name: String) -> void:   # beat flashes use priority 3 so the player's own command flash can't swallow them
	if bool(_camp_events.get(name, false)): return
	_camp_events[name] = true
	match name:
		"ch2_cut":   # the Gateway the player just assaulted hits back: a real wave on Support plus a routing cut
			_camp_events["ch2_cut_t"] = _t
			if _camp_support >= 0:
				hosts[_camp_support].route_off = CAMP_CUT_SECS; hosts[_camp_support].hit_t = _t
				if _camp_gateway >= 0 and int(hosts[_camp_gateway].owner) == RIVAL:
					_do_wire(RIVAL, [_camp_gateway], _camp_support); _do_assault(RIVAL, _camp_support, 75)
			_flash("The Corporate Gateway hit back — Support is under attack and its routing is cut. Keep it guarded.", 3)
		"ch1_cash":   # one delivered packet is ~2 Crypto: top up so the 30-Crypto farm can be bought right away
			_camp_grant(0.0, 30.0, 0.0, 0.0)
			_flash("Your Crypto was topped up to 30 for this lesson — the miner keeps adding more.", 3)
		"ch3_stock":   # the new workshop raised the limits: fill them so the first card can be prepared without a long wait
			_camp_grant(0.0, 0.0, 100.0, 100.0)
			_flash("Your workshop is running — Credentials and Research topped up for the lessons.", 3)
		"ch3_phish":
			if _camp_relay >= 0: _apply_effect(RIVAL, CARDS["phishworm"], _camp_relay, 1)
			_flash("A rival is phishing your relay — its output is being stolen.", 3)
		"ch3_ddos":
			if _camp_relay >= 0: _apply_effect(RIVAL, CARDS["ddos"], _camp_relay, 1)
			_flash("A rival DDOSed your relay — its service is down.", 3)
		"ch3_0day":
			if _camp_support >= 0: _apply_effect(RIVAL, CARDS["zeroday"], _camp_support, 1)
			_flash("A rival 0day hit Support — Patch day bounced it.", 3)
		"ch3_supply":
			if _camp_support >= 0: _apply_effect(RIVAL, CARDS["supply"], _camp_support, 1)
			_flash("A rival Supply chain attack hit Support — SCA bounced it.", 3)
		"ch4_detect":   # the owner traces the extraction and cuts an owned node on the records route; it recovers
			_camp_detect_mark = _records_got(PLAYER, _camp_vault)
			var rt := _extract_route(PLAYER, _camp_vault)
			for k in range(rt.size() - 2, 0, -1):   # skip the vault (0) and the rig (last); cut an owned relay in between
				var node := int(rt[k])
				if _mine(node):
					hosts[node].route_off = maxf(float(hosts[node].get("route_off", 0.0)), MIS_RESPOND_CUT)
					hosts[node].hit_t = _t
					break
			_flash("They traced the records route and cut it — it recovers. Keep extracting.", 3)


# ---- advancement (outcome-gated) ----
func _camp_step_done(chapter: int, step: int) -> bool:
	match chapter:
		0:
			match step:
				0: return not _owned_feeders(_camp_relay).is_empty()
				1: return _scanned(PLAYER, _camp_relay)
				2: return _mine(_camp_relay) or float(hosts[_camp_relay].bots) < float((scans[PLAYER] as Dictionary).get(_camp_relay, {}).get("bots", 1e9)) - 0.5
				3: return _mine(_camp_relay)
		1:
			match step:
				0: return _mine(_camp_relay) and _count_all(_camp_relay, "intel") >= 1
				1: return _count_all(_camp_relay, "cash") >= 1
				2: return _camp_cash_landed >= 1
				3: return _count_all(_camp_relay, "bot") >= 1
		2:
			match step:
				0: return _camp_guarded(_camp_support)
				1: return _camp_assaulted()
				2: return not _camp_assault_running()   # cancelled, or already spent (its result says what Cancel would have kept)
				3:   # Support held, guarded, the wave spent and the cut over (a stalled rival order can't hold the lesson hostage)
					var wave_over := _camp_gateway < 0 or not _assault_active(_camp_gateway) or _t > float(_camp_events.get("ch2_cut_t", 0.0)) + 25.0
					return bool(_camp_events.get("ch2_cut", false)) and _mine(_camp_support) and not _routing_down(_camp_support) \
						and _camp_guarded(_camp_support) and _hostile_incoming(_camp_support) <= 0.0 and wave_over
		3:
			match step:
				0: return _camp_has_kind("cred") and _camp_has_kind("lab")
				1: return _held(PLAYER, "phishworm:linked") >= 1
				2: return _camp_practice >= 0 and _stolen(_camp_practice) and int(hosts[_camp_practice].get("steal_by", -1)) == PLAYER
				3: return bool(_camp_events.get("ch3_phish", false)) and not _stolen(_camp_relay)
				4: return _camp_practice >= 0 and _prod_down(_camp_practice) and _routing_down(_camp_practice)
				5: return bool(_camp_events.get("ch3_ddos", false)) and not _prod_down(_camp_relay) and not _routing_down(_camp_relay)
				6: return _camp_practice2 >= 0 and _mine(_camp_practice2)
				7: return _camp_support >= 0 and float(hosts[_camp_support].get("patch_until", 0.0)) > _t
				8: return _camp_practice >= 0 and int(hosts[_camp_practice].owner) == RIVAL and _built_kinds(_camp_practice).is_empty()
				9: return _camp_support >= 0 and float(hosts[_camp_support].get("sca_until", 0.0)) > _t
		4:
			match step:
				0: return _scanned(PLAYER, _camp_vault)
				1: return _access_live(PLAYER, _camp_vault) and not _mine(_camp_vault)
				2: return _records_got(PLAYER, _camp_vault) >= 1.0
				3: return bool(_camp_events.get("ch4_detect", false)) and _records_got(PLAYER, _camp_vault) > _camp_detect_mark + 0.5
				4: return _mission_complete(PLAYER, _camp_vault) and mission_done.has(_mkey(PLAYER, _camp_vault))
		5:
			return won
	return false


func _camp_guarded(t: int) -> bool:   # some owned computer wires into t as a guard
	if t < 0 or not _mine(t): return false
	for i in hosts.size():
		if _mine(i) and i != t and int(hosts[i].assign) == t: return true
	return false


func _camp_assaulted() -> bool:
	for i in hosts.size():
		var o := _assault_of(i)
		if not o.is_empty() and int(o.get("sent", 0)) > 0: return true
	return false


func _camp_has_kind(kind: String) -> bool:
	for i in hosts.size():
		if _mine(i) and _count_all(i, kind) >= 1: return true
	return false


func _camp_assault_running() -> bool:   # some order of the player's still has bots to send
	for i in hosts.size():
		if _mine(i) and _assault_active(i): return true
	return false


func _camp_card_in_flight(key: String) -> bool:   # a copy of the player's card still on its way to land
	for f in flights:
		if str(f.kind) == "card" and int(f.owner) == PLAYER and str(f.get("card", "")) == key: return true
	return false


func _camp_tick() -> void:
	if not _camp or _camp_hold_left > 0.0: return   # a finished step is showing its result; _process moves on afterwards
	var step := _camp_step()
	# the step's single-use card was used up (a miss, or dropped on the wrong computer): hand one prepared copy back —
	# never while a copy is still flying or being researched. No lesson may dead-end on a spent card.
	var need := str(step.get("card", ""))
	if need != "" and not _camp_step_done(_camp_chapter, _tut_stage) and _held(PLAYER, need) <= 0 \
			and not _camp_card_in_flight(need) and not (lab[PLAYER].queue as Array).has(need):
		cards[PLAYER][need] = 1; _refresh_hand()
		_flash("Here's another %s — %s" % [str(CARDS[_card_of(need)].name), _camp_fill(str(step.get("a", "")))], 3)
	# the attack lessons need the Practice host to stay the rival's: if the player took it, the rival takes it back
	if _camp_chapter == 3 and _tut_stage in [2, 4, 8] and _camp_practice >= 0 and int(hosts[_camp_practice].owner) != RIVAL:
		_capture(_camp_practice, RIVAL); hosts[_camp_practice].bots = 30.0; _set_builds(_camp_practice, ["intel", "bot"])
		hosts[_camp_practice].name = "Practice host"
		_flash("The rival took the Practice host back — it is this lesson's target.", 3)
	# Ch4: owning the vault blocks the lesson (records only flow through access): its owner takes it back
	if _camp_chapter == 4 and _camp_vault >= 0 and _mine(_camp_vault) and not mission_done.has(_mkey(PLAYER, _camp_vault)):
		_capture(_camp_vault, RIVAL)
		hosts[_camp_vault].bots = 50.0; hosts[_camp_vault].sec = 50.0; hosts[_camp_vault].name = "Records vault"
		_refresh_panel(); queue_redraw()
		_flash("Kessler Finance took the vault back — you don't need to own it. Open access instead: records flow while you have it.", 3)
	# Ch2 retaliation: Support must survive the lesson (game-first: no unrecoverable state)
	if _camp_chapter == 2 and _tut_stage == 3 and _camp_support >= 0 and not _mine(_camp_support):
		_camp_own(_camp_support); hosts[_camp_support].name = "Support"
		_flash("Support fell — it is yours again. Guard it from %s." % _camp_fill("{from}"), 3)
	if _camp_step_done(_camp_chapter, _tut_stage): _camp_complete_step()


func _camp_complete_step() -> void:   # the outcome happened: show what it did (the game keeps running so it can be seen), then go on
	if _camp_chapter == 5: _camp_next(); return   # the open chapter ends in VICTORY, which says it all
	var st := _camp_step()
	if str(st.get("fire_leave", "")) != "": _camp_fire(str(st.fire_leave))   # its scripted answer plays DURING the result
	var last := _tut_stage + 1 >= _camp_steps(_camp_chapter).size()
	if last and not _camp_replay and _camp_chapter + 1 < CAMP_CHAPTERS:
		_camp_done[_camp_chapter] = true; _camp_save_at(_camp_chapter + 1, 0)
	_camp_hold_target = _camp_target()
	_camp_hold_text = _camp_outcome()
	_camp_hold_left = CAMP_HOLD_CHAPTER if last else CAMP_HOLD_STEP
	_show_tut(); queue_redraw()


func _camp_outcome() -> String:   # what the finished step did, in plain words
	var st := _camp_step()
	if _camp_chapter == 2 and _tut_stage == 2 and not _camp_cancelled:   # the order ran out before Cancel was pressed
		return "The Assault had already sent every bot — Cancel only keeps the bots that haven't left at home."
	if _camp_chapter == 4 and _tut_stage == 4 and _camp_vault >= 0:   # the decision: say what that choice changed
		match str(mission_done.get(_mkey(PLAYER, _camp_vault), "")):
			"sell": return "Sold: +%d Crypto went to your bank — and a rival now holds the records." % int(MIS_SELL_CRYPTO)
			"publish":
				if _camp_commrelay >= 0: _camp_hold_target = _camp_commrelay
				return "Published: the Community Relay works for you for %d seconds — your traffic can pass through it." % int(MIS_RELAY_SECS)
	return _camp_fill(str(st.get("r", "Done.")))


func _camp_next() -> void:
	var acted := _camp_acted_in_hold; _camp_acted_in_hold = false
	var steps := _camp_steps(_camp_chapter)
	var leaving: Dictionary = steps[_tut_stage] if _tut_stage < steps.size() else {}
	if str(leaving.get("fire_leave", "")) != "": _camp_fire(str(leaving.fire_leave))
	if _tut_stage + 1 < steps.size():
		_tut_stage += 1
		var step: Dictionary = steps[_tut_stage]
		if str(step.get("fire", "")) != "": _camp_fire(str(step.fire))
		if bool(step.get("pause", false)) and not acted and not _camp_step_done(_camp_chapter, _tut_stage): _camp_paused = true   # never freeze a step already done or under way
		var tgt := _camp_target()
		if str(step.get("card", "")) != "" or str(step.get("ui", "")).begins_with("card:"):
			sel = {}; _inspect = -1; _tab = ""   # a card step: the blinking card and the ringed target are the cue, not an unrelated build palette
		elif tgt >= 0:
			if _mine(tgt): sel = {tgt: true}; _inspect = -1
			else: sel = {}; _inspect = tgt
			_tab = ""
		if not _camp_replay: _camp_save()
		_show_tut(); _refresh_panel()
	else:
		_camp_done[_camp_chapter] = true
		if _camp_chapter + 1 < CAMP_CHAPTERS and not _camp_replay:
			var fin := _camp_chapter + 1
			_start_campaign(fin)   # its _reset clears the message line, so the closure flash comes after
			_flash("Chapter %d complete — %s. Next: %s." % [fin, _camp_chapters()[fin - 1], _camp_chapters()[fin]], 3)
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
	var head := "Ch %d/6 · %s — %d/%d · %s" % [_camp_chapter + 1, chapters[_camp_chapter], _tut_stage + 1, _camp_steps(_camp_chapter).size(), str(step.t)]
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
		panel_scroll.remove_child(previous); previous.queue_free()
		panel_scroll.add_child(panel_box)
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
		feedback_label.text = "DEFENCE · release over a highlighted host of yours." if bool(CARDS[_card_of(dragged)].get("defense", false)) else "ATTACK · release over a highlighted foreign host."
		if target >= 0:
			var reason := _can_play(PLAYER, dragged, target)
			var cd: Dictionary = CARDS[_card_of(dragged)]
			var scale := _card_scale(str(cd.fam), target)
			if reason == "" and scale <= 0: reason = "immune to this card family"
			feedback_label.text = "%s · %s" % [str(hosts[target].name), reason if reason != "" else _effect_text(cd, target, scale)]
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


func _panel_result() -> void:
	if won: _plabel("VICTORY", 20, C_GOOD)
	else: _plabel("DEFEATED", 20, C_BAD)
	if _end_cause != "": _plabel(_end_cause, 14, C_TEXT)
	var rivs := []
	for fac in botnets:
		if fac != PLAYER: rivs.append("%s %d" % [fname(fac), int(cash[fac])])
	_plabel("Elapsed %s  ·  buildings %d/%d  ·  Crypto you %d · %s  ·  town #%d" % [_fmt_time(_t), _player_nodes(), hosts.size(), int(cash[PLAYER]), " · ".join(rivs), town_seed], 14, C_TEXT)
	_btn("Tell us how it went", func(): _fb_status = ""; _open_menu(true); _menu_view = "feedback"; _refresh_menu())   # in-game feedback form
	if _mp_on: _btn("Leave match", _mp_leave)
	elif _camp: _btn("Retry chapter", _camp_retry)   # a campaign loss stays inside the mandatory flow
	else: _btn("Restart in a new town", _reset)


func _type_line(i: int) -> String:   # "Database · 4 slots · Intel ×2"
	var tp: Dictionary = NODE_TYPES[str(hosts[i].get("type", "pc"))]
	var mults := ""
	for what in ["bot", "intel", "cash", "cred", "research"]:
		if float(tp.get(what, 1.0)) != 1.0: mults += " · %s ×%.1f" % [{"bot": "bots", "intel": "Intel", "cash": "Crypto", "cred": "Creds", "research": "Research"}[what], float(tp[what])]
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
	var line := "%d/%d bots · %d/%d slots built" % [int(h.bots), int(_cap_of(i)), _built(i).size(), int(h.slots)]
	var order := _assault_of(i)
	if not order.is_empty():
		line += "
ASSAULT → %s: %d of %d left · %d sent%s · %s" % [str(hosts[int(order.t)].name), int(order.left), int(order.total), int(order.sent),
			" · farms resting" if _regen_paused(i) else "", _src_state(i)]
	return line


func _panel_build(i: int) -> void:
	var h: Dictionary = hosts[i]
	_plabel("Node buildings", 16, C_TEXT)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for slot in int(h.slots):
		var box := SlotBox.new(); box.game = self; box.host = i; box.slot = slot
		box.custom_minimum_size = Vector2(112, 140); row.add_child(box)
	panel_box.add_child(row)
	_plabel("Available buildings · %d s of funded work each" % int(BUILD_TIME), 16, C_TEXT)
	var palette := HBoxContainer.new(); palette.add_theme_constant_override("separation", 4)
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
	var effects := []
	for status in [["boost_until", "CDN x2"], ["patch_until", "Patch"], ["sca_until", "SCA"], ["steal_until", "Phishing"]]:
		var remaining := float(hosts[source].get(status[0], 0.0)) - _t
		if remaining > 0: effects.append("%s %.0fs" % [status[1], remaining])
	if _prod_down(source): effects.append("DDOS %.0fs" % float(hosts[source].prod_off))
	if not effects.is_empty(): _plabel(" · ".join(effects), 14, C_WARN)
	var target := int(hosts[source].assign)
	_panel_build(source)
	var guards := _owned_feeders(source)
	var connections: Array = guards.duplicate()
	if target >= 0: connections.push_front(source)
	if not connections.is_empty(): _connection_list(connections)


func _disconnect_source(source: int) -> void: _cmd(["unwire", source])


func _do_unwire(fac: int, source: int) -> void:
	if not _owns(fac, source): return
	hosts[source].assign = -1; hosts[source].live = false; _next_depart.erase(source); hosts[source].assault = {}
	if fac == PLAYER: _refresh_panel(); queue_redraw()


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


func _inset_focus(field: Control) -> void:   # the focus outline drawn INSIDE the field: the menu's scroll clips one drawn outside
	var style := StyleBoxFlat.new()
	style.draw_center = false; style.border_color = Color(0.45, 0.85, 1.0, 0.95)
	style.set_border_width_all(2); style.set_corner_radius_all(3)
	field.add_theme_stylebox_override("focus", style)


func _link_button_style(button: Button) -> void:   # a quiet text action (e.g. Cancel): dim, red with a soft box on hover
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


# A price as resource icons — the same icons as the HUD — with an optional clock for the time. Returns its width.
const _COST_ICON := {"intel": "intel", "cash": "cash", "creds": "cred", "research": "lab"}
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
	var live := 0; var attacks := 0; var assaults := 0; var left := 0; var sent := 0; var total := 0
	var waiting := {}
	for source in conns:
		var order := _assault_of(source)
		if not order.is_empty():
			assaults += 1; left += int(order.left); sent += int(order.sent); total += int(order.total)
		elif bool(hosts[source].live):
			live += 1
			if str(hosts[source].mode) == "attack": attacks += 1
		var state := _src_state(source)
		if state in ["no Intel", "no bots", "no route", "routing cut", "link busy"]: waiting[state] = true
	var unordered := conns.size() - assaults   # sources an Assault would give an order to
	var title := "Connected"
	if assaults > 0: title = "Assault"
	elif attacks > 0: title = "Attacking" if _scanned(PLAYER, t) else "Attacking blind"
	elif live > 0: title = "Scanning · no damage"
	_plabel(title, 18, C_TEXT)
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 12); panel_box.add_child(actions)
	if live > 0:
		_action_button("Stop", _halt.bind(t), actions)
	elif unordered > 0 and _scanned(PLAYER, t):
		_action_button("Attack", _launch.bind(t, "attack"), actions)
	elif unordered > 0:
		_action_button("Scan", _launch.bind(t, "scan"), actions)
	if assaults > 0: _action_button("Cancel assault", _cancel_assault.bind(t), actions)
	elif unordered > 0:
		_action_button("Assault", _assault.bind(t, -1), actions)
		_action_button("%d%%" % _assault_pct, _cycle_assault_pct, actions)
	var status := " "
	if waiting.has("no Intel"): status = "Waiting for Intel · add a harvester or stop another attack."
	elif waiting.has("no bots"): status = "Waiting for bots to regenerate"
	elif not waiting.is_empty(): status = ", ".join(waiting.keys())
	# Keep the command tree stable when resource blockers appear or clear.
	_plabel(status, 14, C_WARN)
	if assaults > 0: _plabel(_assault_progress(t, conns, left, sent, total), 14, C_TEXT)
	elif unordered > 0: _plabel(_assault_forecast(t, conns), 13, C_DIM)
	_connection_list(conns)
	_plabel(_operation_observation(t), 14, C_TEXT)


func _cycle_assault_pct() -> void:   # UI only: the share the next Assault commits
	var k := ASSAULT_COMMITS.find(_assault_pct)
	_assault_pct = int(ASSAULT_COMMITS[(k + 1) % ASSAULT_COMMITS.size()])
	_refresh_panel()


func _assault_progress(t: int, conns: Array, left: int, sent: int, total: int) -> String:
	var air := 0
	for f in flights:
		if int(f.owner) == PLAYER and int(f.route.back()) == t and str(f.kind) == "bot": air += 1
	var homes := []
	for source in conns:
		var order := _assault_of(source)
		if not order.is_empty(): homes.append("%s %d home · %d left" % [str(hosts[source].name), int(hosts[source].bots), int(order.left)])
	return "%d of %d bots left to send · %d sent · %d in the air
%s" % [left, total, sent, air, "
".join(homes)]


func _assault_forecast(t: int, conns: Array) -> String:   # what pressing Assault would commit, and what it might leave
	var bots := 0; var home := 0; var n := 0; var hops := 99
	for source in conns:
		if _assault_active(source): continue
		var rt := _route(source, t)
		if rt.is_empty(): continue
		var q := _assault_quota(source, _assault_pct)
		if q < 1: continue
		bots += q; home += int(float(hosts[source].bots)) - q; n += 1; hops = mini(hops, rt.size() - 1)
	if n == 0: return "Assault: no connected source has bots and a route"
	var power := _assault_power(_assault_pct); var cost := int(ceil(float(bots) * _assault_intel(_assault_pct)))
	var line := "Assault %d%%: %d bots from %d source(s) · %d stay home · %d Intel (you have %d) · farms rest until it ends" % [_assault_pct, bots, n, home, cost, int(intel[PLAYER])]
	if _assault_pct > 100: line = "Assault %d%% OVERCHARGED: all %d bots, each hits ×%s · %d Intel (%s per bot; you have %d) · farms rest until it ends" % [_assault_pct, bots, str(power), cost, str(_assault_intel(_assault_pct)), int(intel[PLAYER])]
	if _scanned(PLAYER, t):   # what you know of the target: its garrison and farms, live
		var secs := float(bots) / (float(n) * ASSAULT_RATE) + float(hops) * LINK_TIME + float(maxi(0, hops - 1)) * NODE_ROUTE_DELAY
		var after := float(hosts[t].bots) + _regen(t) * secs - float(bots) * power
		line += "
Predicted: %s (no guards, full Intel, free streets)" % ("captured, ~%d spare" % int(-after) if after < 0.0 else "~%d defenders left" % int(ceil(after)))
	else: line += "
Scan it to predict the defenders left"
	return line


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
		var connections := _owned_feeders(i)
		if int(hosts[i].assign) >= 0: connections.push_front(i)
		if not connections.is_empty(): _connection_list(connections)
		return
	_plabel(str(hosts[i].name), 20, C_TEXT)
	_plabel(_stage_line(i), 14, C_DIM)
	if _is_mission(i): _panel_mission(i)
	_panel_enemy_slots(i)
	_panel_node_in(i)


func _panel_mission(t: int) -> void:   # the "Recover the Corporate Records" objective on a foreign computer
	_gap(2.0)
	_kicker("Objective · Corporate Records")
	var corp := str(hosts[t].get("corp", ""))
	if corp != "": _plabel(corp, 15, C_WARN)
	if str(hosts[t].get("stake", "")) != "": _plabel(str(hosts[t].stake), 12, C_DIM)
	if not _scanned(PLAYER, t):
		_plabel("Scan this computer to find the records and a way in.", 13, C_TEXT)
		return
	var got := int(_records_got(PLAYER, t)); var total := int(hosts[t].records_total)
	_plabel("Records recovered: %d / %d" % [got, total], 14, C_TEXT)
	var bar := ProgressBar.new(); bar.max_value = total; bar.value = got; bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10); panel_box.add_child(bar)
	if _mission_complete(PLAYER, t):
		if mission_done.has(_mkey(PLAYER, t)):
			_plabel("Resolved: %s" % str(mission_done[_mkey(PLAYER, t)]), 13, C_GOOD)
			return
		_plabel("Delivered. Decide who benefits:", 13, C_TEXT)
		_btn_row([["Sell · +%d Crypto" % int(MIS_SELL_CRYPTO), _resolve_mission.bind(t, "sell"), true],
			["Publish · community relay", _resolve_mission.bind(t, "publish"), true]])
		return
	var alert := int(hosts[t].get("alert", 0.0))
	if _access_live(PLAYER, t):
		_plabel("ACCESS LIVE · %ds left — records stream to your rig while a route holds" % int(ceil(float(hosts[t].access_until) - _t)), 13, C_GOOD)
		if alert > 0: _plabel("Trace alert %d%% — a high alert lets %s isolate your route" % [alert, fname(int(hosts[t].owner))], 12, C_WARN)
		if _extract_route(PLAYER, t).size() < 2: _plabel("No route home right now — the records wait.", 12, C_WARN)
	else:
		var why := _can_access(PLAYER, t)
		_plabel("Temporary access (not ownership) lets the records flow out. Costs %s for %ds." % [_res_cost_text(_access_cost(t)), int(MIS_ACCESS_SECS)], 12, C_DIM)
		_btn("Establish access", _establish_access.bind(t), why == "")
		if why != "": _plabel(why.capitalize(), 12, C_WARN)
	_plabel("Or capture a route the ordinary way: access and ownership are different.", 11, C_DIM)
	_gap(2.0)


func _panel_attack_diag(t: int, _feeders: Array, _sending: Array) -> void:
	_plabel(_operation_observation(t), 16, C_TEXT)


func _panel_idle() -> void:
	_plabel("Hold at least 51%% of the town for %d s to win." % int(HOLD_SECS), 16, C_TEXT)
	_gap(2.0)
	_plabel("①  Drag from your building onto a target to connect.", 13)
	_plabel("②  Click the target → SCAN or ATTACK.", 13)
	_plabel("③  Drag a card from your hand onto a reachable enemy.", 13)
	_gap(4.0)
	_plabel("Drag empty map to pan · wheel to zoom · 0 recenters", 11, C_DIM)
	_plabel("Esc menu · Space pause", 11, C_DIM)


func _panel_board() -> void:
	_plabel("Leaderboard · Insane AI" if ai_level.values().has("insane") else "Leaderboard", 18, C_BAD if ai_level.values().has("insane") else C_TEXT)
	_plabel("Control %d / %d to win" % [_control_need() + 1, hosts.size()], 12, C_DIM)
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
		var bar := ProgressBar.new(); bar.custom_minimum_size = Vector2(0, 7)
		bar.show_percentage = false; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.value = 100.0 * count / maxf(1, hosts.size())
		var track := StyleBoxFlat.new(); track.bg_color = Color(0.1, 0.14, 0.2)
		bar.add_theme_stylebox_override("background", track)
		var fill := StyleBoxFlat.new(); fill.bg_color = fcol(fac)
		bar.add_theme_stylebox_override("fill", fill); panel_box.add_child(bar)


func _control_pct(fac: int) -> int:
	return int(round(100.0 * float(_faction_nodes(fac)) / float(maxi(1, hosts.size()))))


func _res_limit(res: String) -> float:   # the player's limit for a capped pool; Crypto has none
	match res:
		"intel": return _intel_cap(PLAYER)
		"creds": return _res_cap(PLAYER, "cred")
		"research": return _res_cap(PLAYER, "lab")
	return INF


func _res_now(res: String) -> float:
	match res:
		"intel": return float(intel[PLAYER])
		"creds": return float(creds[PLAYER])
		"research": return float(research[PLAYER])
	return float(cash[PLAYER])


func _res_full(res: String) -> bool:   # at its limit (now or within the 4 s window) and not draining: income past the limit is lost
	var lim := _res_limit(res)
	if lim == INF: return false
	var top := _res_now(res)
	for s in _resource_samples: top = maxf(top, float(s[res]))
	return top >= lim - 0.001 and _observed_net(res) > -0.5


func _rate_tag(res: String) -> String:
	if _res_full(res): return " full"   # a pinned bank would otherwise read "+0.0/s" while income is being thrown away
	var net := _observed_net(res)
	if absf(net) < 0.05: net = 0.0
	return " %+.1f/s" % net


func _rate_col(res: String) -> Color:
	if _res_full(res): return C_WARN   # amber: spend it or build another harvester
	var net := _observed_net(res)
	if net > 0.05: return C_GOOD
	if net < -0.05: return C_WARN
	return C_TEXT


func _hud_items() -> Array:   # resource reserves; territory shares live in the idle leaderboard
	# [kind, text, colour, column width] — every item owns a fixed column, so a growing number never shifts the row
	return [
		["intel", "%d/%d%s" % [int(intel[PLAYER]), int(_intel_cap(PLAYER)), _rate_tag("intel")], _rate_col("intel"), 185.0],
		["cash", "%d%s" % [int(cash[PLAYER]), _rate_tag("cash")], _rate_col("cash"), 150.0],
		["cred", "%d/%d%s" % [int(creds[PLAYER]), int(_res_cap(PLAYER, "cred")), _rate_tag("creds")], _rate_col("creds"), 170.0],
		["lab", "%d/%d%s" % [int(research[PLAYER]), int(_res_cap(PLAYER, "lab")), _rate_tag("research")], _rate_col("research"), 170.0],
	]


func _hud_text() -> String:   # probes and scripts: the HUD as one line
	var parts := []
	for it in _hud_items(): parts.append(("%s " % {"cash": "Crypto", "intel": "Intel", "cred": "Creds", "lab": "Research"}[str(it[0])] if str(it[0]) != "" else "") + str(it[1]))
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


# ---- fog of war: ONE rule for the player's screen and for every AI that plays fair (the Insane brain) ----
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


func _paint_ground(cx: Dictionary) -> void:   # territories, streets, wires
	var vis: Dictionary = cx.vis; var sight: Dictionary = cx.sight; var seen: Dictionary = cx.seen; var focus_on: bool = cx.focus_on; var fnodes: Dictionary = cx.fnodes; var flinks: Dictionary = cx.flinks
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))   # WORLD space (zoom/pan)
	_draw_territories(vis)
	var traffic := _street_traffic(sight)
	for i in hosts.size():   # streets, tinted by the botnet holding both ends; amber when at capacity
		for j in hosts[i].links:
			if j < i: continue
			var vi := vis.has(i); var vj := vis.has(int(j))
			if not ((vi or seen.has(i)) and (vj or seen.has(int(j)))): continue   # an unexplored end: fog
			if not (vi and vj):   # a remembered street at the edge of sight: faint, owners unknown
				_cv.draw_line(hosts[i].pos, hosts[int(j)].pos, Color(0.35, 0.5, 0.7, 0.08), 1.0, true)
				continue
			var oi := int(hosts[i].owner); var oj := int(hosts[j].owner)
			var key := _lk(i, int(j))
			var lcol := Color(0.35, 0.5, 0.7, 0.18); var w := 1.0
			if _highways.has(key): lcol = Color(0.55, 0.7, 0.85, 0.3); w = 2.2   # a highway across a gap
			if oi == oj and oi != NEUTRAL: lcol = fcol(oi); lcol.a = 0.35; w = (2.4 if _highways.has(key) else 1.3)
			if int(traffic.get(key, 0)) >= _link_cap(i, int(j)): lcol = Color(1, 0.75, 0.3, 0.65); w = 1.8   # at capacity, by the packets you can see
			if focus_on and not flinks.has(key): lcol.a *= 0.6
			_cv.draw_line(hosts[i].pos, hosts[int(j)].pos, lcol, w, true)
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
		if not _mine(i) and not sight.has(i): continue       # a foreign source out of sight (fog, or a rig seen from afar): no wire
		if bool(hosts[i].live) and not _mine(i):              # a foreign wire shows only along streets you can see
			for run in _sighted_runs(_route(i, a), sight): _draw_route_line(run, i, a, dimmed, int(run.back()) == a)
		elif bool(hosts[i].live):
			_draw_route_line(_route(i, a), i, a, dimmed)
		else:
			var kcol: Color = Color(0.45, 0.95, 0.7, 0.8) if int(hosts[a].owner) == int(hosts[i].owner) else Color(1, 0.85, 0.4, 0.8)
			if not _mine(i): kcol = fcol(int(hosts[i].owner)); kcol.a = 0.45
			if dimmed: kcol.a *= 0.25
			var rt := _route(i, a)
			if rt.size() >= 2: _draw_dashed(rt, kcol, 1.2)
			else: _draw_dashed([i, a], Color(0.8, 0.5, 0.5, (0.15 if dimmed else 0.55)), 1.0)   # your unrouted plan (only yours reach here)


func _paint_packets(cx: Dictionary) -> void:   # packets in flight and worm jumps (they pass UNDER the buildings)
	var sight: Dictionary = cx.sight; var vt: float = cx.vt; var focus_on: bool = cx.focus_on; var fnodes: Dictionary = cx.fnodes
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))   # WORLD space (zoom/pan)
	for fl in flights:   # packets: yours = circle, other botnets = square in their colour, Cash = diamond
		if not _flight_seen(fl, sight): continue
		var pp := _packet_pos(fl, vt)
		var endn := int((fl.route as Array)[(fl.route as Array).size() - 1])
		var threat: bool = int(fl.owner) != PLAYER and _mine(endn)
		var ba: float = 1.0 if (not focus_on or fnodes.has(endn) or threat) else 0.3
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
	if focus_on:   # rings: GOLD = friendly connections, wide RED = hostile buildings wired into it
		var gold := Color(1, 0.85, 0.3, 0.95)
		var red := Color(1, 0.35, 0.3, 0.95)
		for i in hosts.size():
			if i != aim and int(hosts[i].assign) == aim and (_mine(i) or (_wire_visible(i) and sight.has(i))):
				_node_frame(i, 11, gold if _mine(i) else red, 1.8)   # gold = yours, red = another botnet's
		var aout := int(hosts[aim].assign)
		if aout >= 0 and (_mine(aim) or _wire_visible(aim)): _node_frame(aout, 11, gold, 1.8)
		var reach := 0
		for s in _aim_sources():
			if _link_kind(int(s), aim) != "": _draw_dashed(_route(int(s), aim), Color(1, 0.95, 0.55, 0.95), 1.6); reach += 1
		if _dragging and reach == 0:
			_text(_cv, f, _label_pos(aim), "no path to %s" % str(hosts[aim].name), 14, Color(1, 0.45, 0.4))
		else:
			var act: String = "defend %s" if _mine(aim) else "attack %s"
			pass # selected target already has a readable screen-space name
	elif not sel.is_empty():   # connect step: glow where a wire could go + hover preview
		var src_keys: Array = sel.keys()
		var reach := _wire_reach(src_keys)
		for i in hosts.size():
			if reach.has(i): _frame(hosts[i].pos, _r(i) + 7.0, Color(1, 0.8, 0.4, 0.55), 2.0)
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0 and not sel.has(hov):
			var elig := 0
			for s in src_keys:
				if _link_kind(int(s), hov) != "": _draw_dashed(_route(int(s), hov)); elig += 1
			if elig > 0:
				_text(_cv, f, _label_pos(hov), "drag here to connect %s" % str(hosts[hov].name), 13, Color(1, 0.9, 0.5))
	var dk := _dragged_card()
	if dk != "":   # a hand card in the air: where it can land, and what it would do there
		var cd: Dictionary = CARDS[_card_of(dk)]
		var cc: Color = FAMILY_COL[str(cd.fam)]
		var rig_reach: Variant = _wire_reach([int(rig[PLAYER])]) if rig.has(PLAYER) else null   # one pass, not a route per host
		for i in hosts.size():
			if _can_play(PLAYER, dk, i, rig_reach) == "" and _card_scale(str(cd.fam), i) > 0.0: _frame(hosts[i].pos, _r(i) + 7.0, Color(cc.r, cc.g, cc.b, 0.7), 2.0)
		var hov := _host_at(get_local_mouse_position())
		if hov >= 0:
			var sc := _card_scale(str(cd.fam), hov)
			var why := _can_play(PLAYER, dk, hov)
			var txt: String = ("your own building" if int(hosts[hov].owner) == PLAYER else (why if why != "" else ("immune" if sc <= 0.0 else _effect_text(cd, hov, sc))))
			var ok: bool = why == "" and sc > 0.0
			if ok: _frame(hosts[hov].pos, _r(hov) + 9.0, cc, 2.5)
			pass # full-size preview is shown in the reserved feedback lane
	if _dragging and _drag_from >= 0:   # the rubber band: RED over a target no selected source has a path to
		var to := _mouse_world()
		var hv := _host_at(get_local_mouse_position())
		var lcol2 := Color(1, 0.95, 0.55, 0.95)
		if hv >= 0 and hv != _drag_from:
			to = hosts[hv].pos
			if not _wire_reach(_aim_sources()).has(hv): lcol2 = Color(1, 0.4, 0.35, 0.95)
		_cv.draw_line(hosts[_drag_from].pos, to, lcol2, 1.8, true)
		_cv.draw_circle(to, 3.0, lcol2)
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
		var nw := _text_w(f, str(hosts[k].name), 12)
		if box.intersects(Rect2(q.x - rk, q.y - rk, rk * 2.0, rk * 2.0 + 18.0)): return true                 # glyph + bot count
		if box.intersects(Rect2(q.x - nw * 0.5, q.y - rk - 22.0, nw, 16.0)): return true                       # name
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
	if _zoom >= 0.45:
		var nm := str(hosts[i].name)
		var nw := _text_w(f, nm, 12)
		_text(_cv, f, Vector2(p.x - nw * 0.5, p.y - rr - 8.0), nm, 12, Color(0.6, 0.66, 0.76, 0.3))
	_cv.draw_set_transform(_pan, 0, Vector2(_zoom, _zoom))


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
	return str(int(round(float(hosts[i].bots)))) if _mine(i) or _scanned(PLAYER, i) else "?"


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
	if _mine(i) and _under_attack(i):   # under attack → red frame, always full brightness (never fogged)
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
	var nb_txt := _visible_bot_count(i)
	var bw := 8.0 + 7.0 * float(nb_txt.length())
	_cv.draw_rect(Rect2(p.x - bw * 0.5, p.y + rr * 0.42, bw, 13.0), Color(0.03, 0.05, 0.08, 0.88 * a), true)
	_text(_cv, f, Vector2(p.x - 3.6 * float(nb_txt.length()), p.y + rr * 0.42 + 10.5), nb_txt, 12, Color(0.95, 0.97, 1.0, a))
	var nm := str(hosts[i].name)
	if _tut: nm = nm.replace("TRAINING TARGET", "TARGET").replace("TRAINING SUPPORT", "SUPPORT")
	if _zoom < 0.45 and not focused and not _mine(i) and i != _hover_host and not (_tut and i == _tut_target): nm = ""
	var nw := _text_w(f, nm, 12)
	var x0 := p.x - nw * 0.5   # name centred above the glyph
	var ncol := Color(0.85, 0.92, 1.0, a) if not _mine(i) else Color(0.95, 1.0, 0.95, a)
	_text(_cv, f, Vector2(x0, p.y - rr - 8.0), nm, 12, ncol)
	var sub := ""   # ONE warning under the glyph, most urgent first; the rest is in the panel
	if bool(hosts[i].get("junction", false)): sub = "junction"
	if _is_mission(i) and _access_live(PLAYER, i): sub = "RECORDS %d/%d" % [int(_records_got(PLAYER, i)), int(hosts[i].records_total)]
	elif _is_mission(i) and _scanned(PLAYER, i) and not _mission_complete(PLAYER, i): sub = "OBJECTIVE"
	if _mine(i) and _routing_down(i) and not _prod_down(i): sub = "CUT %ds" % int(ceil(float(hosts[i].route_off)))   # your cut outranks FULL
	elif _mine(i) and float(hosts[i].bots) >= _cap_of(i) - 0.5 and _incoming(i, PLAYER) > 0.0: sub = "FULL ↩"
	elif _assault_active(i): sub = ("ASSAULT %d" % int(_assault_of(i).left) if _mine(i) else "ASSAULT") + (" · rest" if _regen_paused(i) else "")
	elif _stolen(i): sub = "PHISHED %ds" % int(ceil(float(hosts[i].steal_until) - _t))   # its output goes to the caster
	elif _prod_down(i): sub = "OFF %ds" % int(ceil(float(hosts[i].prod_off)))
	elif float(hosts[i].get("patch_until", 0.0)) > _t: sub = "PATCH %ds" % int(ceil(float(hosts[i].patch_until) - _t))
	elif float(hosts[i].get("sca_until", 0.0)) > _t: sub = "SCA %ds" % int(ceil(float(hosts[i].sca_until) - _t))
	elif _production_multiplier(i) > 1: sub = "CDN x2 %ds" % int(ceil(float(hosts[i].boost_until) - _t))
	elif _routing_down(i): sub = "CUT %ds" % int(ceil(float(hosts[i].route_off)))
	var subcol := Color(1, 0.85, 0.4, a)
	if sub == "junction": subcol = Color(0.7, 0.85, 1.0, 0.8 * a)
	if sub.begins_with("PHISHED"): subcol = Color(FAMILY_COL["phish"].r, FAMILY_COL["phish"].g, FAMILY_COL["phish"].b, a)
	if sub.begins_with("OFF"): subcol = Color(1, 0.62, 0.2, a)
	elif sub.begins_with("RECORDS") or sub == "OBJECTIVE": subcol = Color(1, 0.8, 0.35, a)
	elif sub.begins_with("ASSAULT"): subcol = Color(1, 0.45, 0.35, a)
	elif sub.begins_with("CUT"): subcol = Color(1, 0.4, 0.65, a)
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
		var sw := _text_w(f, sub, 12)
		var sy := p.y + rr + (30.0 if i == _tutorial_target() else 16.0)   # clear of the campaign target frame (rr+13)
		_text(_cv, f, Vector2(p.x - sw * 0.5, sy), sub, 12, subcol)
	_cv.draw_set_transform(_pan, 0, Vector2(_zoom, _zoom))


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
			"Stop", "Cancel assault": draw_rect(Rect2(centre - Vector2(7, 7), Vector2(14, 14)), col)
			"Assault":   # three chevrons: a burst, not a stream
				for k in 3:
					var x := -10.0 + 8.0 * k
					draw_polyline(PackedVector2Array([centre + Vector2(x, -8), centre + Vector2(x + 7, 0), centre + Vector2(x, 8)]), col, 2.5, true)
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
			game._text(self, f, Vector2(tx, 36.0), str(it[1]), 15, it[2])
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
		# The illustration, inventory and complete rules stay inside this card.
		for line in 3:
			var y := 50.0 + line * 19.0
			draw_line(Vector2(100, y), Vector2(size.x - 16, y), Color(colour, 0.1))
		draw_rect(Rect2(16, 43, 72, 62), colour.darkened(0.9))
		game._draw_card_glyph(self, game._card_of(key), Vector2(52, 74), 62, colour, font)
		game._text(self, font, Vector2(110, 61), "OWNED", 10, game.C_DIM)
		game._text(self, font, Vector2(110, 92), "x%d" % int(state.count), 28, game.C_TEXT, size.x - 124, HORIZONTAL_ALIGNMENT_LEFT)
		draw_line(Vector2(14, 113), Vector2(size.x - 14, 113), Color(colour, 0.25))
		draw_multiline_string(font, Vector2(14, 130), game._research_effect(key), HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 12, 4, game.C_TEXT)
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
		var defense := bool(card.get("defense", false))
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
		game._draw_card_glyph(self, game._card_of(key), Vector2(18, size.y * 0.5), 32, Color(1, 1, 1, 1.0 if owned else 0.4), font)
		var line := "x%d" % int(state.count)
		if bool(state.queued):
			line += {"Paused": " pause", "Waiting": " wait", "Queued": " next"}.get(str(state.status), " %d%%" % int(float(state.progress) * 100))
		var warn: bool = str(state.status) in ["Paused", "Waiting"]
		var line_col: Color = game.C_WARN if warn else (bank.lightened(0.3) if owned else game.C_DIM)
		var room := size.x - 39.0
		if size.x >= 84:
			var title := str(card.get("short", card.name))
			var fs := 11 if game._text_w(font, title, 11) <= room else 10   # the whole name, never clipped
			game._text(self, font, Vector2(35, 16), title, fs, game.C_TEXT if owned else game.C_DIM, room, HORIZONTAL_ALIGNMENT_LEFT)
			game._text(self, font, Vector2(35, 31), line, 11, line_col, room, HORIZONTAL_ALIGNMENT_LEFT)
		else:
			game._text(self, font, Vector2(35, 25), "x%d" % int(state.count), 11, line_col, room, HORIZONTAL_ALIGNMENT_LEFT)
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
	"bot": ["+1 bot/s", "+30 bot cap"], "intel": ["+1 Intel/s", "+15 Intel cap"], "cash": ["+0.33 Crypto/s", "1 Intel each"],   # 1 Crypto every CASH_INTERVAL (3 s), like the others: the base rate
	"cred": ["+0.5 Creds/s", "1 Intel each"], "lab": ["+0.5 Research/s", "1 Crypto each"],
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
