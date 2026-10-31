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
const UiIcons := preload("res://scripts/ui_icons.gd")

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
const CONVERT_ORDER := CfgBuildings.CONVERT_ORDER

const CARDS := CfgCards.CARDS
const RESEARCH := CfgCards.RESEARCH
const CARD_ORDER := CfgCards.CARD_ORDER
const ATTACK_ORDER := CfgCards.ATTACK_ORDER
const DEFENSE_ORDER := CfgCards.DEFENSE_ORDER
const KNOWN_START := CfgCards.KNOWN_START
const QUEUE_SIZE := CfgCards.QUEUE_SIZE
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
const PROD_CYCLE := CfgTuning.PROD_CYCLE
const STORE_CAP := CfgTuning.STORE_CAP
const FIREWALL_SOCKETS := CfgTuning.FIREWALL_SOCKETS
const LINK_TIME := CfgTuning.LINK_TIME
const NODE_ROUTE_DELAY := CfgTuning.NODE_ROUTE_DELAY
const LINK_CAP := CfgTuning.LINK_CAP
const MAX_QUEUE := CfgTuning.MAX_QUEUE
const EXPRESS_MULT := CfgTuning.EXPRESS_MULT
const RECON_CHANCE := CfgTuning.RECON_CHANCE
const SCOUTED_CHANCE := CfgTuning.SCOUTED_CHANCE
const UNSCOUTED_CHANCE := CfgTuning.UNSCOUTED_CHANCE
const WORKERS_PER_STATION := CfgTuning.WORKERS_PER_STATION
const WORKER_CARRY := CfgTuning.WORKER_CARRY
const WORKER_REPLACE := CfgTuning.WORKER_REPLACE
const PRIORITY_TURNS := CfgTuning.PRIORITY_TURNS
const CARD_GIVE_UP := CfgTuning.CARD_GIVE_UP
const RESEARCH_SLOTS := CfgTuning.RESEARCH_SLOTS
const HOLD_FRACTION := CfgTuning.HOLD_FRACTION
const HOLD_SECS := CfgTuning.HOLD_SECS
const AI_CADENCE := CfgTuning.AI_CADENCE
const LINK_INTEL_DRAIN := CfgTown.LINK_INTEL

const PANEL_W := 384.0   # the inspector: compact, so the map stays the main view at 1280×720
const LEADERBOARD_W := 280.0
const CARD_DOCK_HEIGHT := 264.0
const CARD_DOCK_GAP := 12.0
const MAP_CELL := 190.0         # world size of one town cell; each host sits in its own cell (territories are drawn per cell)
const DECK_BAR_HEIGHT := 40.0   # the always-visible deck strip: ATTACK / DEFENCE tabs, mini cards, pull handle
const DECK_GAP := 8.0           # between the strip and the pulled-up cards
const DECK_TAB_W := 164.0       # each of the drawer's four tabs: Ready, Attack recipes, Defence recipes, Research
const DRAWER_TABS := ["ready", "attack", "defense", "research"]
const DRAWER_TAB_NAME := {"ready": "Ready", "attack": "Attack recipes", "defense": "Defence recipes", "research": "Research"}
const QUEUE_CHIP_W := 138.0     # one of the manufacturing queue's four positions in the strip
const READY_CHIP_W := 124.0     # one ready card in the strip: a fixed size, never shrunk to make room
const READY_TILE := Vector2(236.0, 124.0)   # one ready card in the drawer
const RESEARCH_INFO_H := 50.0   # the RESEARCH view's row over the tree: the selected blueprint and its action
const QUEUE_DONE_SECS := 3.0    # how long the strip shows a finished copy as done
const MENU_W := 384.0           # menu panel width
const MENU_PAD := 24.0          # one rule for every menu view: the same visible inset on all four sides of its content
const MENU_MARGIN := 24.0       # a menu panel keeps this far from the window's edges
const GAME_VERSION := "0.6.5"   # AI drops cut-off projects and researches when boxed in, per-resource forecast, the view stays put (lobbies match exact versions)
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
var _opt_shape := ""   # internal fixture only (tests, Learn): force a layout. "" = the seed picks one (_layout_for_seed)
var _layout := "grid"              # the live layout of this match
var _opt_enemies := 2
var _seen := {}                    # fog memory: faction -> {host: Vector2(last-known owner, time seen)}
var _hover_host := -1              # the visible host under the mouse, found once per drawn frame
var _hover_flight := -1            # the id of the packet under the mouse (its details show beside it)
var _held_rects := {}              # host -> Rect2 (screen): the "held" tag drawn on it this frame
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
var sim_rng := RandomNumberGenerator.new()   # the match's own dice (Recon odds): seeded from the map, part of the lockstep fingerprint
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
var ship_cursor := {}  # faction -> which host plans first this step (the hosts share a short main node in turn)
var known := {}        # faction -> {recipe: true}: learned blueprints
var research_job := {} # faction -> {} or {key, progress, paused}
var mq := {}           # faction -> the manufacturing queue: [{id, recipe, paid, progress}] (at most QUEUE_SIZE; the head is made)
var mq_paused := {}    # faction -> true while the player has paused the queue (a paid head keeps its payment and progress)
var _mq_next := 0
var _mq_cids := {}     # faction -> {command id: true}: a replayed enqueue command makes no second copy
var cards := {}        # faction -> {recipe: ready copy count}
var recon := {}        # faction -> {host: {at, builds, buf}}: a dated Recon snapshot
var _hold := {}        # faction -> seconds it has continuously held the majority
var card_plays := {}   # faction -> operations launched (probes and the result screen)

# ── traffic and operations ──
var _delivered := {}   # faction -> cargo units that reached its main node (the campaign's delivery step)
var flights := []      # packets: {id, kind:"courier"|"op", route, hops, hop_i, depart_t, arrive_t, owner, dest, ...} (blocked: held at f.at)
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
var _route_memo = null           # routes cached within one step's phases (see _travel_route), else null
var _blocked_next := 0.0          # when held packets next look for a way on
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
var hand_panel: Control          # the drawer's body: ready cards, four recipes of a bank, or the research tree
var hand_bar: GridContainer
var card_banks: HBoxContainer    # the drawer's tabs, in DRAWER_TABS order
var deck_handle: Button          # the strip's cards button (three bars): open / close the drawer
var _card_bank := "ready"        # the drawer's view: "ready" (cards you hold), "attack" / "defense" (recipes), "research"
var _deck_open := false          # the drawer starts closed: the map gets the room
var _deck_page := 0              # which four of the open bank's cards the pulled-up deck shows
var research_tree: Control       # the RESEARCH tab: the development tree, in place of the cards
var _known_sig := ""             # which recipes the player knows, last time the deck was laid out
var deck_pager: HBoxContainer    # ← page n / m → in the drawer's header while its view holds more than one page
var lane_strip: HBoxContainer    # the strip's manufacturing lanes, one LaneChip each
var ready_strip: HBoxContainer   # the strip's ready cards, one ReadyChip per recipe held (never shrunk: the rest go to "+n")
var ready_more: Button           # "+n" in the strip when more ready cards are held than fit
var ready_empty: Label           # the strip when nothing is ready
var ready_grid: GridContainer    # the drawer's READY view: one ReadyTile per recipe held, paged
var research_info: Control       # the drawer's RESEARCH view: the selected blueprint and what you can do with it, over the tree
var research_status: Label       # in the drawer's header on the RESEARCH view: what is being researched and how it goes
var drawer_close: Button
var research_button: Button      # top-right, beside Economy and Menu
var research_bar: Control        # under the HUD while research runs: its name, track, progress, state and work left
var _armed := ""                 # the ready card you selected: click a host to launch it there (Esc or right-click cancels)
var _research_sel := ""          # the blueprint selected in the RESEARCH view
var queue_pause: Button         # the strip's queue pause / resume control (recipe clicks always mean enqueue)
var _ready_sig := ""
var _deck_drag_restore := false  # the deck was pushed down for a card drag; pull it back up when the drag ends
var _bank_alert := {}            # bank -> Time.get_ticks_msec() until which its tab blinks (a card became ready)
var _hand_sig := ""              # rebuild the hand only when its composition changes (keeps it cheap)
var menu_panel: Panel            # the Esc menu: Start / Resume / Restart (pauses while open)
var menu_box: VBoxContainer
var menu_sc: ScrollContainer
var menu_open := false
var _menu_view := "main"          # "main" · "newgame" · "campaign" · "help" · "feedback"
var _menu_shown_view := ""
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
const CAMP_RESULT_SECS := 8.0     # a finished step's result stays above the next instruction this long (nothing waits on it)
var _camp := false                # master flag; cleared in _reset(). _camp => _tut.
const CAMP_OPEN_BANNER_SECS := 10.0   # free play: the Learn banner shows this long, then gets out of the way
var _camp_banner_gone := false     # free play's banner has been hidden (the layout reclaims its room)
var _camp_open_t := -1.0           # sim time free play began (-1: not yet)
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
var _camp_result := ""            # what the last finished step did, shown above the next instruction
var _camp_result_at := -100.0     # _camp_clock when it was set
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
	research_bar = ResearchBar.new(); research_bar.game = self; research_bar.name = "ResearchBar"; add_child(research_bar)
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
	research_tree = ResearchTree.new(); research_tree.game = self; research_tree.name = "ResearchTree"
	research_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); research_tree.visible = false
	hand_panel.add_child(research_tree)
	research_info = ResearchInfo.new(); research_info.game = self; research_info.name = "ResearchInfo"; research_info.visible = false
	hand_panel.add_child(research_info)
	ready_grid = GridContainer.new(); ready_grid.name = "ReadyGrid"
	ready_grid.add_theme_constant_override("h_separation", int(CARD_DOCK_GAP)); ready_grid.add_theme_constant_override("v_separation", int(CARD_DOCK_GAP))
	ready_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE; hand_panel.add_child(ready_grid)
	for card in CARD_ORDER:
		var tile := ReadyTile.new(); tile.game = self; tile.key = _card_key(str(card), "linked"); ready_grid.add_child(tile)
	var none := Label.new(); none.name = "ReadyNone"
	none.text = "No ready cards yet. Open Attack recipes or Defence recipes and click a recipe to make a copy."
	none.add_theme_font_size_override("font_size", 15); none.add_theme_color_override("font_color", C_DIM)
	none.position = Vector2(8, 16); hand_panel.add_child(none)
	card_banks = HBoxContainer.new(); card_banks.add_theme_constant_override("separation", 8)   # the drawer's tabs
	add_child(card_banks)
	for bank in DRAWER_TABS:
		var button := Button.new(); button.name = str(DRAWER_TAB_NAME[bank])
		button.custom_minimum_size = Vector2(DECK_TAB_W, DECK_BAR_HEIGHT)   # fixed: a longer label never shifts the header
		button.clip_text = true; button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_bank_pressed.bind(bank))
		button.tooltip_text = {"ready": "The cards you hold: drag one onto a host, or click it and then click a host.",
			"attack": "Attack recipes you know: click one to make a copy.",
			"defense": "Defence recipes you know: click one to make a copy.",
			"research": "The development tree: select a blueprint, then research it (R)."}[bank]
		card_banks.add_child(button)
	research_status = Label.new(); research_status.name = "ResearchStatus"
	research_status.add_theme_font_size_override("font_size", 14); research_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	research_status.clip_text = true; research_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(research_status)
	drawer_close = Button.new(); drawer_close.name = "DrawerClose"; drawer_close.tooltip_text = "Close the drawer (C)"
	drawer_close.custom_minimum_size = Vector2(52, DECK_BAR_HEIGHT); drawer_close.focus_mode = Control.FOCUS_NONE
	_fixed_button_style(drawer_close)
	var shut := ActionGlyph.new(); shut.col = C_TEXT; shut.action = "DeckClose"
	shut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); drawer_close.add_child(shut)
	drawer_close.pressed.connect(func(): _set_deck_open(false))
	add_child(drawer_close)
	lane_strip = HBoxContainer.new(); lane_strip.name = "QueueStrip"; lane_strip.add_theme_constant_override("separation", 6)
	add_child(lane_strip)
	for pos in QUEUE_SIZE:
		var chip := QueueChip.new(); chip.game = self; chip.pos = pos; chip.name = "Queue%d" % (pos + 1)
		chip.custom_minimum_size = Vector2(QUEUE_CHIP_W, DECK_BAR_HEIGHT); lane_strip.add_child(chip)
	queue_pause = Button.new(); queue_pause.name = "QueuePause"; queue_pause.focus_mode = Control.FOCUS_NONE
	queue_pause.custom_minimum_size = Vector2(76, DECK_BAR_HEIGHT); queue_pause.add_theme_font_size_override("font_size", 13)
	queue_pause.tooltip_text = "Pause or resume the manufacturing queue. The copy being made keeps its payment and progress."
	_fixed_button_style(queue_pause); queue_pause.pressed.connect(func(): _cmd(["queue_pause"]))
	lane_strip.add_child(queue_pause)
	ready_strip = HBoxContainer.new(); ready_strip.name = "ReadyStrip"; ready_strip.add_theme_constant_override("separation", 6)
	add_child(ready_strip)
	for card in CARD_ORDER:
		var rc := ReadyChip.new(); rc.game = self; rc.key = _card_key(str(card), "linked")
		rc.custom_minimum_size = Vector2(READY_CHIP_W, DECK_BAR_HEIGHT); ready_strip.add_child(rc)
	ready_more = Button.new(); ready_more.name = "ReadyMore"; ready_more.focus_mode = Control.FOCUS_NONE
	ready_more.custom_minimum_size = Vector2(READY_CHIP_W * 0.6, DECK_BAR_HEIGHT); ready_more.add_theme_font_size_override("font_size", 14)
	ready_more.tooltip_text = "More ready cards: open the drawer"
	_fixed_button_style(ready_more); ready_more.pressed.connect(_open_drawer.bind("ready"))
	ready_strip.add_child(ready_more)
	ready_empty = Label.new(); ready_empty.name = "ReadyEmpty"; ready_empty.text = "No ready cards"
	ready_empty.add_theme_font_size_override("font_size", 14); ready_empty.add_theme_color_override("font_color", C_DIM)
	ready_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; ready_empty.custom_minimum_size = Vector2(0, DECK_BAR_HEIGHT)
	add_child(ready_empty)
	deck_handle = Button.new(); deck_handle.name = "DeckHandle"; deck_handle.tooltip_text = "Cards: ready copies, recipes and research (C)"
	deck_handle.custom_minimum_size = Vector2(52, DECK_BAR_HEIGHT); deck_handle.focus_mode = Control.FOCUS_NONE
	_fixed_button_style(deck_handle)
	var burger := ActionGlyph.new(); burger.col = C_TEXT; burger.action = "Drawer"
	burger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); deck_handle.add_child(burger)
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
	logs_button = Button.new(); logs_button.name = "Logs"; logs_button.focus_mode = Control.FOCUS_NONE
	logs_button.add_theme_font_size_override("font_size", 14); logs_button.custom_minimum_size = Vector2(LOGS_W, RESEARCH_BAR_H)
	logs_button.clip_text = true; logs_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; logs_button.text = "Logs"
	logs_button.tooltip_text = "What happened: your operations, attacks on you, captures, losses and problems (H)."
	_fixed_button_style(logs_button); logs_button.pressed.connect(_open_logs); add_child(logs_button)
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
	menu_sc.position = Vector2(MENU_PAD, MENU_PAD)
	menu_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO   # never DISABLED: that would let the box grow past the panel
	menu_panel.add_child(menu_sc)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	menu_box.custom_minimum_size = Vector2(MENU_W - 2.0 * MENU_PAD, 0)
	menu_sc.add_child(menu_box)
	menu_box.minimum_size_changed.connect(_layout_menu)   # content that grows or shrinks re-fits its panel
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
	set_process(true)


func fname(fac: int) -> String: return str(_mp_names.get(fac, FACTIONS[fac].name))   # multiplayer: the player's own name
func _is_human(fac: int) -> bool: return humans.has(fac)
func fcol(fac: int) -> Color: return FACTIONS[fac].col


# ============================================================ TOWN GENERATION
# A different town every run: cells may be gaps, positions jitter, streets are missing or diagonal,
# downtown is rich and well defended, the rim is poor and soft. Everything stays connected.
func _layout_for_seed(seed: int) -> String:   # every supported layout, picked by the seed alone: a seed always rebuilds its map
	var h := (seed * 1103515245 + 12345) & 0x7fffffff
	return str(SHAPES[(h >> 8) % SHAPES.size()])


func _gen() -> void:
	if town_seed == 0:
		rng.randomize(); town_seed = int(rng.randi() % 900000) + 1
	if _layout == "": _layout = _layout_for_seed(town_seed)
	rng.seed = town_seed
	sim_rng.seed = hash("rim-sim:%d" % town_seed)   # every screen of a match rolls the same dice in the same order
	var sz := get_viewport_rect().size
	hosts = []; hub = -1; rig = {}; _cell = {}; _terr = {}; _highways = {}; _roads = {}; flights = []; _execs = []; _res = {}; _flight_id = 0
	bank = {}; incoming = {}; _delivered = {}; ship_cursor = {}; known = {}; research_job = {}; mq = {}; mq_paused = {}; _mq_next = 0; _mq_cids = {}; cards = {}; recon = {}
	workers = {}; _wid_next = 0; _inst_gen = 0; _reqs = {}; _req_next = 0; _pool_turn = {}; _served = {}; _serve_n = {}; _served_res = {}; _plan_cache = {}; _job_next = 0
	_logi_dirty = {}; _logi_next = {}
	_ai = {}; _fx = []; _worms = []; _hold = {}; card_plays = {}
	_ledger = {}; op_outcomes = []; intrusions_resolved = 0; events = []; _ev_next_poll = 0.0; _ev_dirty = true; _ev_seen_t = -1.0   # per-match records
	_refresh_event_strip()   # the Logs button reads "Logs" from the first frame, even while a lesson opens paused
	for fac in botnets:
		bank[fac] = {}
		for res in RES: bank[fac][res] = float(START[res])
		incoming[fac] = {}; ship_cursor[fac] = 0
		known[fac] = {}
		for recipe in KNOWN_START: known[fac][recipe] = true
		research_job[fac] = {}; cards[fac] = {}; recon[fac] = {}; card_plays[fac] = 0; _hold[fac] = 0.0
		mq[fac] = []; mq_paused[fac] = false
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
	_tick_teams(0.0)   # the main node's starting Bot station has its two workers from the first moment


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
		"name": "HUB" if is_hub else "Host %d" % (hosts.size() + 1), "type": ntype,   # a public name says nothing about what it is
		"links": [], "owner": NEUTRAL, "gen": 0, "value": value, "slots": slots,
		"builds": _slot_array([], slots), "jobs": {}, "store": {}, "producer_paused": {}, "junction": false,
		"cyc": PROD_CYCLE * (0.2 + 0.8 * fposmod(float(hosts.size()) * 0.618034, 1.0)), "fw_on": true, "sockets": [], "ship_rr": 0,
		"ddos_until": 0.0, "filter_until": 0.0, "sabot_until": 0.0, "steal_by": -1, "steal_until": 0.0,
		"siphon": {}, "patch_armed_until": 0.0, "patch_recover_until": 0.0, "cover_until": 0.0, "express_until": 0.0,
		"teams": {}, "claim": {}, "inbound": {}, "loot": {},
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
	hosts[i].store = {}; hosts[i].jobs = {}; hosts[i].producer_paused = {}; hosts[i].sockets = []
	if is_rig:
		hosts[i].rig = true; rig[fac] = i; hosts[i].builds = _slot_array(["intel", "bot"], int(hosts[i].slots))
	else:
		hosts[i].builds = _slot_array([], int(hosts[i].slots))
		hosts[i].name = "Host %d" % (i + 1)
	if nm != "": hosts[i].name = nm


func _pick_type(value: int) -> String:   # weighted by district: soft IoT and PCs on the rim, data and ERP downtown
	var w: Dictionary = TYPE_WEIGHTS[clampi(value, 1, 3)]
	var r := rng.randf(); var acc := 0.0
	for k in w.keys():
		acc += float(w[k])
		if r <= acc: return str(k)
	return str(w.keys()[w.size() - 1])




# ---- the odds of a card: no security levels. A Recon gets through half the time; every other attack works half the
# time on a host you hold fresh Recon of, a quarter of the time otherwise. Defence cards (your own hosts) always work. ----
var rolls_always_hit := false   # tests only: every draw succeeds (recon_test covers the odds themselves); never set in play


func _op_chance(fac: int, t: int, recipe: String, at := -1.0) -> float:   # success chance of this card on t, judged at time `at`
	if not CARDS.has(recipe) or _is_defense(recipe): return 1.0
	if str(CARDS[recipe].effect) == "recon": return RECON_CHANCE
	return SCOUTED_CHANCE if _recon_fresh(fac, t, at) else UNSCOUTED_CHANCE


func _op_roll(fac: int, t: int, recipe: String) -> bool:   # one draw per resolved operation, only when the odds are not certain
	var c := _op_chance(fac, t, recipe)
	if c >= 1.0: return true
	var hit := sim_rng.randf() < c   # the draw is taken either way, so a test that forces hits keeps the same RNG sequence
	return hit or rolls_always_hit


func _pct(c: float) -> int: return int(round(c * 100.0))


func _miss_why(fac: int, t: int, recipe: String, scouted := -1) -> String:   # the chance a miss had: as recorded (scouted 0/1), else judged now
	if str(CARDS[recipe].effect) == "recon": return "a Recon gets through %d%% of the time" % _pct(RECON_CHANCE)
	if (scouted == 1) if scouted >= 0 else _recon_fresh(fac, t): return "a %d%% chance even with fresh Recon" % _pct(SCOUTED_CHANCE)
	return "a %d%% chance without fresh Recon" % _pct(UNSCOUTED_CHANCE)


func _has_firewall(i: int) -> bool: return (hosts[i].builds as Array).has("wall")


# ---- Recon: a dated snapshot of a foreign host's installations + buffers; your own hosts are always "known" ----
func _scanned(fac: int, t: int) -> bool:   # you know this host's contents (own, or a Recon still fresh)
	if t < 0 or fac == NEUTRAL: return false
	if int(hosts[t].owner) == fac: return true
	return _recon_fresh(fac, t)


func _seen_build(fac: int, t: int, slot: int) -> String:   # what a slot held when you last scanned it (your own: what it holds)
	if int(hosts[t].owner) == fac: return str(hosts[t].builds[slot])
	var seen: Array = ((recon.get(fac, {}) as Dictionary).get(t, {}) as Dictionary).get("builds", [])
	return str(seen[slot]) if slot < seen.size() else ""


func _recon_fresh(fac: int, t: int, at := -1.0) -> bool:   # fac has a Recon snapshot of t that is still fresh (now, or at time `at`)
	var rec: Dictionary = (recon.get(fac, {}) as Dictionary).get(t, {})
	if rec.is_empty() or int(rec.get("gen", int(hosts[t].gen))) != int(hosts[t].gen): return false   # a change of owner voids it
	return (_t if at < 0.0 else at) - float(rec.get("at", -1e9)) <= float(CARDS.recon.dur)


func _mark_scanned(fac: int, t: int) -> void:   # record a Recon snapshot (also used by scripts/campaign)
	if not recon.has(fac): recon[fac] = {}
	recon[fac][t] = {"at": _t, "gen": int(hosts[t].gen), "builds": (hosts[t].builds as Array).duplicate(), "store": _store_total(t), "sockets": (hosts[t].sockets as Array).duplicate()}


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
	_trim_sockets(i)
	_sync_teams(i)


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


func _r(i: int) -> float:   # drawn radius grows with the building's slots (one size for a host you know nothing about)
	if not _known_host(PLAYER, i): return R_UNKNOWN
	return 11.0 + 2.5 * float(hosts[i].slots)


const R_UNKNOWN := 18.5
func _known_host(fac: int, i: int) -> bool:   # fac knows its type, slots and contents: its own, or under a fresh Recon
	return int(hosts[i].owner) == fac or _recon_fresh(fac, i)


func _public_type(i: int) -> String: return str(hosts[i].get("type", "pc")) if _known_host(PLAYER, i) else "unknown"


func _recon_expired(fac: int, t: int) -> bool:   # a Recon of this host (same owner) has gone stale
	var rec: Dictionary = (recon.get(fac, {}) as Dictionary).get(t, {})
	return not rec.is_empty() and int(rec.get("gen", -1)) == int(hosts[t].gen) and not _recon_fresh(fac, t)


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
func _plan_hops(rt: Array, dep: float, express := false) -> Dictionary:   # link slots along rt from dep: each hop waits for room, then crosses
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
	return {"hops": hops, "lt": lt, "arrive": t}


# a packet along rt departing at dep (see _plan_hops); it moves hop by hop and is checked at every host (_advance_flights)
func _schedule(rt: Array, dep: float, fac: int, kind: String, express := false, extra := {}) -> Dictionary:
	_establish(fac, rt)
	var plan := _plan_hops(rt, dep, express)
	_flight_id += 1
	var f := {"id": _flight_id, "route": rt, "hops": plan.hops, "lt": plan.lt, "depart_t": dep, "arrive_t": plan.arrive, "owner": fac, "kind": kind,
		"node": 0, "hop_i": 0, "express": express, "dest": int(rt[rt.size() - 1])}
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
func _attack_route(fac: int, t: int) -> Array:   # main node -> your hosts -> the foreign target (only the target may be foreign)
	var home := _hub(fac)
	if home < 0 or t < 0 or int(hosts[t].owner) == fac: return []
	var rt := _travel_route(fac, home, t)
	return rt if rt.size() >= 2 else []


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


func _add_bank(fac: int, res: String, amt: float, cause := "other") -> float:   # credit, clamped to cap; returns what actually fit
	if not bank.has(fac): return 0.0
	var fit := minf(amt, maxf(0.0, _cap(fac, res) - _avail(fac, res)))
	bank[fac][res] = _avail(fac, res) + fit
	if fit > 0.0: _ledger_add(fac, "in", cause, res, fit)
	if amt - fit > 0.000001: _ledger_add(fac, "lost", "cap", res, amt - fit)
	return fit


func _spend(fac: int, res: String, amt: float, cause := "other") -> void:
	var paid := minf(amt, _avail(fac, res))
	bank[fac][res] = maxf(0.0, _avail(fac, res) - amt)
	if paid > 0.0: _ledger_add(fac, "out", cause, res, paid)


# ---- the economic ledger: what reached, left and was lost from each bank, by cause, over the last LEDGER_SECS of
# simulation time (1-s buckets in a ring). It only watches the simulation; nothing in it feeds back into the rules,
# so it is not part of the lockstep fingerprint.
const LEDGER_SECS := 30
var _ledger := {}   # faction -> {"sec": [bucket second], "data": [{"in:cause:res": amount, ...}]}


func _ledger_add(fac: int, kind: String, cause: String, res: String, amt: float) -> void:
	if not _ledger.has(fac):
		var secs := []; secs.resize(LEDGER_SECS); secs.fill(-1)
		var data := []
		for k in LEDGER_SECS: data.append({})
		_ledger[fac] = {"sec": secs, "data": data}
	var L: Dictionary = _ledger[fac]
	var sec := int(floor(_t)); var slot := posmod(sec, LEDGER_SECS)
	if int(L.sec[slot]) != sec: L.sec[slot] = sec; L.data[slot] = {}
	var key := "%s:%s:%s" % [kind, cause, res]
	L.data[slot][key] = float((L.data[slot] as Dictionary).get(key, 0.0)) + amt


func _ledger_window() -> float:   # seconds the buckets cover: 29 whole ones plus the running one, or less early on ("early estimate")
	if _t < float(LEDGER_SECS): return maxf(1.0, _t)
	return float(LEDGER_SECS - 1) + maxf(0.001, _t - floor(_t))


func _ledger_sums(fac: int) -> Dictionary:   # "kind:cause:res" -> total over the window
	var out := {}
	if not _ledger.has(fac): return out
	var L: Dictionary = _ledger[fac]
	var now := int(floor(_t))
	for slot in LEDGER_SECS:
		var sec := int(L.sec[slot])
		if sec < 0 or sec <= now - LEDGER_SECS or sec > now: continue
		for key in (L.data[slot] as Dictionary): out[key] = float(out.get(key, 0.0)) + float(L.data[slot][key])
	return out


func _econ_rates(fac: int, res: String) -> Dictionary:   # per-minute recent rates for one bank, split by cause
	var sums := _ledger_sums(fac)
	var per_min := 60.0 / _ledger_window()
	var out := {"in": 0.0, "out": 0.0, "lost": 0.0, "in_by": {}, "out_by": {}, "lost_by": {}, "early": _t < float(LEDGER_SECS)}
	for key in sums:
		var parts := str(key).split(":")
		if parts.size() != 3 or parts[2] != res or not (parts[0] in ["in", "out", "lost"]): continue   # "from:<host>" is per-host detail
		var v := float(sums[key]) * per_min
		out[parts[0]] = float(out[parts[0]]) + v
		(out[parts[0] + "_by"] as Dictionary)[parts[1]] = float((out[parts[0] + "_by"] as Dictionary).get(parts[1], 0.0)) + v
	out["net"] = float(out["in"]) - float(out["out"])
	return out


# ---- the income forecast (round B): what will reach the bank per minute with the network as it stands now ----
# Worked out from the network, never extrapolated from the ledger: the main node's trickle and buildings, then every
# host whose output can come home, at the rate its active producers, its inputs (made there, or supplied to its Keep-here
# stock), the couriers that carry it, its route and the bank's room allow. Remote output counts only as fast as it can
# be delivered (storage that fills stops production); what a host is kept stocked with is counted where it is used.
# It is presentation only (not in the lockstep fingerprint), recomputed at most every FORECAST_EVERY s or after a command.
const FORECAST_EVERY := 0.5
var _fc_cache := {}   # fac -> {"t", "gen", "data"}
var _fc_gen := 0      # bumped by every command: a change you make shows at once, even paused


func _forecast(fac: int) -> Dictionary:   # {rate: {res: per min}, from: {res: {source: per min}}, limits: {res: [why]}, need, spare, fleet}
	var c: Dictionary = _fc_cache.get(fac, {})
	if not c.is_empty() and int(c.gen) == _fc_gen and absf(_t - float(c.t)) < FORECAST_EVERY: return c.data
	var d := _forecast_now(fac)
	_fc_cache[fac] = {"t": _t, "gen": _fc_gen, "data": d}
	return d


func _fc_add(d: Dictionary, res: String, src: String, v: float) -> void:
	if v <= 0.0001: return
	d.rate[res] = float(d.rate[res]) + v
	if not (d.from as Dictionary).has(res): d.from[res] = {}
	d.from[res][src] = float((d.from[res] as Dictionary).get(src, 0.0)) + v


func _fc_limit(d: Dictionary, res: String, why: String) -> void:
	if not (d.limits as Dictionary).has(res): d.limits[res] = []
	if not (d.limits[res] as Array).has(why): (d.limits[res] as Array).append(why)


func _fc_cycle(i: int, fac: int, at_main: bool, inflow: Dictionary, budget := {}) -> Dictionary:   # one steady cycle of host i for fac: {out: {res: units}, used: {res: units supplied}}
	var out := {}; var used := {}
	for res in RES: out[res] = 0.0
	var supplied := {}   # inputs that keep coming: a remote host's Keep-here stock (from the bank's budget); at the main node, a bank with a buffer
	for res in RES:
		if at_main: supplied[res] = _avail(fac, res) >= 5.0
		else: supplied[res] = int(hosts[i].owner) == fac and float(budget.get(res, 0.0)) > 0.0001   # supplies are automatic
	out.intel = float(BUILD_KINDS.intel.rate) * _tmult(i, "intel") * _count(i, "intel")
	var made := out.duplicate()   # at the main node every output is income; what converters and Firewalls use is spending
	var walls := _count_all(i, "wall") - _walls_building(i)
	if walls > 0 and int(hosts[i].owner) == fac and not at_main:   # the Firewall eats first, from what is made here, then from supplies
		var need := float(BUILD_KINDS.wall.use.intel) * walls
		var own := minf(need, float(out.intel)); out.intel = float(out.intel) - own
		if need - own > 0.0001 and bool(supplied.intel):
			var got := minf(need - own, float(budget.intel)); budget.intel = float(budget.intel) - got
			used.intel = float(used.get("intel", 0.0)) + got
	for kind in CONVERT_ORDER:
		var k := _count(i, kind)
		if k == 0: continue
		var spec: Dictionary = BUILD_KINDS[kind]
		var m := _tmult(i, str(spec.out))
		var frac := 1.0
		for r in (spec.use as Dictionary):
			var need := float(spec.use[r]) * m * k
			var have := float(out[str(r)])
			if bool(supplied[str(r)]): have += INF if at_main else float(budget[str(r)])
			elif at_main: have += float(inflow.get(str(r), 0.0)) * PROD_CYCLE / 60.0
			frac = minf(frac, have / maxf(0.000001, need))
		for r in (spec.use as Dictionary):
			var take := float(spec.use[r]) * m * k * frac
			var local := minf(take, float(out[str(r)]))
			out[str(r)] = float(out[str(r)]) - local
			if take - local > 0.0001:
				used[str(r)] = float(used.get(str(r), 0.0)) + take - local
				if not at_main: budget[str(r)] = maxf(0.0, float(budget[str(r)]) - (take - local))
		out[str(spec.out)] = float(out[str(spec.out)]) + float(spec.rate) * m * k * frac
		made[str(spec.out)] = float(made.get(str(spec.out), 0.0)) + float(spec.rate) * m * k * frac
	if at_main: out = made
	return {"out": out, "used": used}


func _forecast_now(fac: int) -> Dictionary:
	var per := 60.0 / PROD_CYCLE
	var d := {"rate": {}, "from": {}, "limits": {}, "need": 0.0, "spare": 0.0, "fleet": 0}
	for res in RES: d.rate[res] = 0.0
	var hub := _hub(fac)
	if hub < 0 or _eliminated.has(fac): return d
	# what the bank can keep sending per cycle to hosts' supplies: plenty while it holds a buffer, else what the
	# main node itself brings in (its trickle and its Intel harvesters), shared by the hosts in turn
	var budget := {}
	for res in RES:
		if _avail(fac, res) >= 5.0: budget[res] = INF
		else:
			budget[res] = MAIN_INCOME * PROD_CYCLE if _main_ok(fac) else 0.0
			if res == "intel" and _main_ok(fac): budget[res] = float(budget[res]) + float(BUILD_KINDS.intel.rate) * _tmult(hub, "intel") * _count(hub, "intel")
	# remote hosts first: what each could send home per cycle, and what it needs supplied
	var remote := []   # [host, ship {res: units/cycle}, supply units/cycle, round trip s]
	for i in hosts.size():
		if i == hub: continue
		var owner := int(hosts[i].owner)
		var benef := _benef(i)
		if benef != fac or owner == NEUTRAL: continue   # only output that is fac's (its own, or phished from a rival)
		if _ddos_down(i):
			if _standing(i) > 0: for res in RES: _fc_limit(d, res, "a host under DDoS")
			continue
		var cyc := _fc_cycle(i, fac, false, {}, budget)
		var ship := {}; var sum := 0.0
		for res in RES:
			if float(cyc.out[res]) > 0.0001: ship[res] = float(cyc.out[res]); sum += float(cyc.out[res])
		var sup := 0.0
		for r in (cyc.used as Dictionary): sup += float(cyc.used[r])
		if sum <= 0.0001: continue
		var rt := _home_route(fac, i)
		if rt.size() < 2:
			for res in ship: _fc_limit(d, res, "no route home from %s" % str(hosts[i].name))
			continue
		var hub_x := float(hosts[hub].get("express_until", 0.0)) > _t; var host_x := float(hosts[i].get("express_until", 0.0)) > _t
		remote.append([i, ship, sup, _travel_time(rt, hub_x) + _travel_time(rt, host_x)])   # out leg leaves the main node, back leg the host
	# workers: one pool at the main node, with the dispatcher's priorities. Inputs go first, and each input trip brings
	# one unit of the host's output back on its return leg. What is left of the pool's time then carries the remaining
	# surplus, shared by the hosts in turn. Starved inputs starve that host's output in proportion.
	var fleet: int = int(_worker_counts(fac).total)
	var spare := float(fleet)
	var need_in := 0.0; var need := 0.0
	for row in remote:
		var units := 0.0
		for res in (row[1] as Dictionary): units += float(row[1][res])
		need_in += float(row[2]) * float(row[3]) / PROD_CYCLE
		need += maxf(units, float(row[2])) * float(row[3]) / PROD_CYCLE   # workers busy keeping up with all of it
	var share_in := 1.0 if need_in <= spare + 0.0001 else spare / maxf(0.0001, need_in)
	var left := maxf(0.0, spare - need_in * share_in)
	var rest := []   # per row: [ride units, surplus units still to carry]
	var need_out := 0.0
	for row in remote:
		var units := 0.0
		for res in (row[1] as Dictionary): units += float(row[1][res])
		var made := units * (share_in if float(row[2]) > 0.0001 else 1.0)   # outputs shrink with starved inputs
		var ride := minf(made, float(row[2]) * share_in)
		rest.append([ride, made - ride])
		need_out += (made - ride) * float(row[3]) / PROD_CYCLE
	var share_out := 1.0 if need_out <= left + 0.0001 else left / maxf(0.0001, need_out)
	d.need = need; d.spare = spare; d.fleet = fleet
	var inflow := {}
	for k in remote.size():
		var row: Array = remote[k]
		var i: int = row[0]
		var units := 0.0
		for res in (row[1] as Dictionary): units += float(row[1][res])
		var got := float(rest[k][0]) + float(rest[k][1]) * share_out
		var f := clampf(got / maxf(0.0001, units), 0.0, 1.0)
		if f < 0.999:
			for res in (row[1] as Dictionary): _fc_limit(d, str(res), "not enough workers")
		for res in (row[1] as Dictionary):
			if _room(fac, str(res)) < 1.0 and _avail(fac, str(res)) >= _cap(fac, str(res)) - 0.5: continue   # a full bank takes nothing
			var v := float(row[1][res]) * f * per
			inflow[res] = float(inflow.get(res, 0.0)) + v
			_fc_add(d, str(res), str(hosts[i].name), v)
	# the main node: the trickle, then its buildings (inputs straight from the bank)
	if _main_ok(fac):
		for res in RES:
			_fc_add(d, res, "main node trickle", MAIN_INCOME * 60.0)
			inflow[res] = float(inflow.get(res, 0.0)) + MAIN_INCOME * 60.0
		var mc := _fc_cycle(hub, fac, true, inflow)
		for res in RES: _fc_add(d, res, "main node buildings", float(mc.out[res]) * per)
	else: for res in RES: _fc_limit(d, res, "your main node is under DDoS")
	# a full bank takes nothing more
	for res in RES:
		if _avail(fac, res) >= _cap(fac, res) - 0.5 and float(d.rate[res]) > 0.0:
			d.rate[res] = 0.0; d.from[res] = {}; _fc_limit(d, res, "your bank is full")
	return d


func _incoming_eta(fac: int, res: String) -> Dictionary:   # cargo on the road for this bank: count, next arrival, how many are at risk
	var n := 0; var next := INF; var risk := 0
	var hub := _hub(fac)
	for f in flights:
		if int(f.owner) != fac or str(f.kind) != "courier" or int(f.get("dest", -1)) != hub: continue
		if not (f.cargo as Dictionary).has(res): continue
		n += 1
		if bool(f.get("blocked", false)): risk += 1   # held on the way: a route broke under it
		else: next = minf(next, float(f.arrive_t) - _t)
	return {"n": n, "next": next if n > risk else -1.0, "risk": risk}


func _reserve_incoming(fac: int, res: String, amt: float) -> void:
	if not incoming.has(fac): incoming[fac] = {}
	incoming[fac][res] = _incoming(fac, res) + amt


func _release_incoming(fac: int, res: String, amt: float) -> void:
	if incoming.has(fac): incoming[fac][res] = maxf(0.0, _incoming(fac, res) - amt)


func _pool(fac: int, res: String) -> float: return _avail(fac, res)   # legacy alias used by some callers


# ---- host storage: what a remote host has made and not yet sent home, split by beneficiary ----
# At the beneficiary's own main node the storage IS the bank: production there is credited at once.
func _store_of(i: int, fac: int) -> Dictionary:
	return (hosts[i].store as Dictionary).get(fac, {})


func _store_total(i: int) -> float:
	var s := 0.0
	for fac in (hosts[i].store as Dictionary):
		for res in (hosts[i].store[fac] as Dictionary): s += float(hosts[i].store[fac][res])
	return s


func _buf_total(i: int) -> float: return _store_total(i)   # legacy name (Recon snapshots, tests)


func _st_local(i: int, fac: int) -> bool: return i == int(rig.get(fac, -1))


func _st_get(i: int, fac: int, res: String) -> float:
	if _st_local(i, fac): return _avail(fac, res)
	return float(_store_of(i, fac).get(res, 0.0))


func _st_add(i: int, fac: int, res: String, amt: float) -> float:   # credit what fits; returns it
	if amt <= 0.0: return 0.0
	if _st_local(i, fac): return _add_bank(fac, res, amt, "production")
	var fit := minf(amt, maxf(0.0, STORE_CAP - _store_total(i)))
	if fit <= 0.0: return 0.0
	if not (hosts[i].store as Dictionary).has(fac): hosts[i].store[fac] = {}
	hosts[i].store[fac][res] = float((hosts[i].store[fac] as Dictionary).get(res, 0.0)) + fit
	return fit


func _st_take(i: int, fac: int, res: String, amt: float, cause := "converters") -> void:
	if _st_local(i, fac): _spend(fac, res, amt, cause); return
	_store_take(i, fac, res, amt)


func _store_take(i: int, fac: int, res: String, amt: float) -> void:   # from the host's storage dictionary itself, never a bank
	var st := _store_of(i, fac)
	if st.is_empty(): return
	var left := float(st.get(res, 0.0)) - amt
	if left <= 0.0001: st.erase(res)
	else: st[res] = left
	if st.is_empty(): (hosts[i].store as Dictionary).erase(fac)


# ---- income + production (Layer 4): one cycle per host every PROD_CYCLE seconds ----
func _main_ok(fac: int) -> bool:   # the faction's main node is operational (held and not DDoSed)
	var home := int(rig.get(fac, -1))
	return home >= 0 and int(hosts[home].owner) == fac and not _prod_down(home)


func _tick_production(dt: float) -> void:
	# 1) the main node makes one of each resource every 12 s, delivered locally (no worker, clamped to cap)
	for fac in botnets:
		if _eliminated.has(fac) or not _main_ok(fac): continue
		for res in RES: _add_bank(fac, res, MAIN_INCOME * dt, "trickle")
	# 2) every held host runs its cycle on its own phase, so the network does not pulse all at once
	for i in hosts.size():
		var owner := int(hosts[i].owner)
		if owner == NEUTRAL or not botnets.has(owner) or _eliminated.has(owner): continue
		hosts[i].cyc = float(hosts[i].get("cyc", PROD_CYCLE)) - dt
		if float(hosts[i].cyc) > 0.00001: continue
		hosts[i].cyc = float(hosts[i].cyc) + PROD_CYCLE
		_run_cycle(i)


func _cycle_kinds(i: int, kind: String) -> int: return _count(i, kind)   # active producers of a kind this cycle


func _run_cycle(i: int) -> void:
	var owner := int(hosts[i].owner)
	_logi_poke()   # new output and new needs: every pool looks again
	var benef := _benef(i)
	if not botnets.has(benef) or _eliminated.has(benef): benef = owner
	# a) Intel harvesters: no input
	var n := _cycle_kinds(i, "intel")
	if n > 0: _st_add(i, benef, "intel", float(BUILD_KINDS.intel.rate) * _tmult(i, "intel") * n)
	# b) the Firewall's upkeep, paid by the owner from this host before any converter eats the Intel
	var walls := _count_all(i, "wall") - _walls_building(i)
	if walls > 0:
		var need := float(BUILD_KINDS.wall.use.intel) * walls
		var have := _st_get(i, owner, "intel")
		if owner != benef: have += _st_get(i, benef, "intel")   # phished: the Firewall still eats what lands here
		hosts[i].fw_on = have >= need - 0.0001
		if bool(hosts[i].fw_on):
			var own := minf(need, _st_get(i, owner, "intel"))
			_st_take(i, owner, "intel", own, "upkeep")
			if need - own > 0.0001: _st_take(i, benef, "intel", need - own, "upkeep")
	# c) converters, from this host's own storage (the bank at the main node); a remote host runs the plan its
	#    deliveries were requested for (_host_plan), so an earlier converter never eats a later one's supplies
	var use_plan: bool = not _st_local(i, owner) and benef == owner
	var planned := {}
	if use_plan:   # the plan for this very cycle, from what is here and what can still come (never stale)
		var budget := {}
		for res in RES: budget[res] = _free(owner, res)
		var pl := _host_plan(i, owner, budget)
		planned = pl.frac; hosts[i].plan_limited = bool(pl.limited)
	for kind in CONVERT_ORDER:
		var spec: Dictionary = BUILD_KINDS[kind]
		var out := str(spec.out)
		var m := _tmult(i, out)
		for slot in (hosts[i].builds as Array).size():
			if str(hosts[i].builds[slot]) != kind or not _producer_active(i, slot): continue
			var frac := float(planned.get(slot, 0.0)) if use_plan else 1.0
			for r in (spec.use as Dictionary):
				frac = minf(frac, _st_get(i, benef, str(r)) / maxf(0.000001, float(spec.use[r]) * m))
			if _st_local(i, benef): frac = minf(frac, _room_now(benef, out) / maxf(0.000001, float(spec.rate) * m))
			if frac <= 0.0001: continue
			for r in (spec.use as Dictionary): _st_take(i, benef, str(r), float(spec.use[r]) * m * frac)
			_st_add(i, benef, out, float(spec.rate) * m * frac)
	if bool(hosts[i].get("plan_limited", false)): hosts[i].plan_rr = int(hosts[i].get("plan_rr", 0)) + 1   # the next cycle funds the next ones first


func _walls_building(i: int) -> int:   # installed Firewalls a job is taking down (no upkeep, no sockets): a new one counts only when finished
	var n := 0
	for slot_key in (hosts[i].jobs as Dictionary):
		var slot := int(hosts[i].jobs[slot_key].slot)
		if str(hosts[i].builds[slot]) == "wall": n += 1
	return n


func _room_now(fac: int, res: String) -> float: return maxf(0.0, _cap(fac, res) - _avail(fac, res))


func _attack_route_none(fac: int, src: int) -> bool:   # true if src has no route to fac's main node
	var home := _hub(fac)
	if src == home: return false
	return _home_route(fac, src).is_empty()


func _home_route(fac: int, src: int) -> Array:   # how fac's couriers travel from src to its main node (src may be a foreign end)
	var home := _hub(fac)
	if home < 0 or src < 0 or src == home: return []
	return _travel_route(fac, src, home)


# ============================================================ LOGISTICS (delivery workers)
# Bots are delivery WORKERS, not a material. Every operational Bot station has exactly two worker slots
# (WORKERS_PER_STATION); a completed station fills them with two workers that have stable identities and are never
# used up. All of a botnet's workers are ONE pool working from its main node: a new worker at a remote station first
# goes to the main node (carrying its host's surplus, if any), and from then on every trip is main node -> host ->
# main node, carrying at most one unit of one material per leg (WORKER_CARRY; a final fraction may be less): out with
# building materials or a host's missing input, back with a host's surplus or a theft / salvage pile.
# Nobody configures shipping: each host's needs come from its own work (_host_plan: the next production cycle's
# inputs after what it makes itself, its Firewall's upkeep, its construction bills) and whatever it holds beyond that
# is surplus to collect. Three of every four new assignments go by purpose - construction, then inputs, then surplus -
# and then to the host served least recently; every fourth goes to the host served least recently whatever it needs
# (_pick_request), so the hosts are served in turn and nothing waits forever.
# Every packet - worker or card - moves hop by hop through its owner's hosts only (_advance_flights): a relay that is
# taken or knocked out stops it at the last good host, where it waits, visibly, and goes on when a route opens.
# Losing a host destroys the workers of its stations wherever they are (_kill_home_workers); a worker lost on the
# road is replaced at its surviving station after WORKER_REPLACE s of operation; a demolished station's workers
# finish the leg they are on and retire. Materials are always in exactly one place: a bank, a host's storage, a
# worker's cargo, a construction escrow or a theft / salvage pile. Reservations only point at them.
func _travel_route(fac: int, a: int, b: int) -> Array:   # a ... b with every host in between fac's and up; the ends may be anyone's
	if a < 0 or b < 0: return []
	if a == b: return [a]
	if _route_memo != null:
		var key := (fac * 4096 + a) * 4096 + b
		if not _route_memo.has(key): _route_memo[key] = _travel_route_bfs(fac, a, b)
		return (_route_memo[key] as Array).duplicate()
	return _travel_route_bfs(fac, a, b)


func _travel_route_bfs(fac: int, a: int, b: int) -> Array:
	if (hosts[a].links as Array).has(b): return [a, b]
	var prev := {a: a}; var q := [a]; var head := 0; var hit := -1
	while head < q.size():
		var c: int = q[head]; head += 1
		if c != a and (hosts[c].links as Array).has(b): hit = c; break
		for o in hosts[c].links:
			var n := int(o)
			if prev.has(n) or n == b or int(hosts[n].owner) != fac or _routing_down(n): continue
			prev[n] = c; q.append(n)
	if hit < 0: return []
	var p := [hit]
	while int(p[p.size() - 1]) != a: p.append(prev[p[p.size() - 1]])
	p.reverse(); p.append(b)
	return p


func _hub(fac: int) -> int:   # fac's main node while fac holds it, else -1
	var h := int(rig.get(fac, -1))
	return h if h >= 0 and int(hosts[h].owner) == fac else -1


# ---- workers: two per operational Bot station, each with a stable identity ----
var workers := {}        # wid -> {fac, home, base, slot, gen, k, state: "idle" | "trip" | "retiring", fid}; base: where it rests (its
                         # station's host until its first trip to the main node, then the main node: one pool serves every host)
var _wid_next := 0
var _inst_gen := 0       # each completed station gets a new generation: its worker slots belong to that installation
var _reqs := {}          # fac -> {key: {id, since}}: open delivery requests keep their age while they last
var _req_next := 0
var _pool_turn := {}     # fac -> assignments made (every fourth goes to the least recently served host, whatever it needs)
var _served := {}        # fac -> {host: the assignment number that last served it}: round robin across hosts
var _serve_n := {}       # fac -> assignments counted for _served
var _served_res := {}    # fac -> {host: {res: the assignment number that last moved res there or from there}}: within a host, in turn
var _plan_cache := {}    # host -> its plan for this step (rebuilt every step)
var _logi_dirty := {}    # fac -> true: something that can create work happened (an arrival, a cycle, a command...): plan this step
var _logi_next := {}     # fac -> when it plans again anyway (time-based changes: a trickle, a route reopening)
const LOGI_EVERY := 0.25


func _logi_poke(fac := -1) -> void:   # plan at the next step (fac -1: everyone)
	if fac < 0:
		for f in botnets: _logi_dirty[f] = true
	else: _logi_dirty[fac] = true


func _station_live(i: int, slot: int) -> bool:   # a finished Bot station no job is working on
	return int(hosts[i].owner) != NEUTRAL and slot < (hosts[i].builds as Array).size() and str(hosts[i].builds[slot]) == "bot" and not _slot_busy(i, slot)


func _station_ok(i: int, slot: int) -> bool:   # ... and working: a vacant slot's replacement only advances then
	return _station_live(i, slot) and not _prod_down(i) and not _sabotaged(i)


func _teams(i: int) -> Dictionary:
	if not hosts[i].has("teams"): hosts[i].teams = {}
	return hosts[i].teams


func _has_team(i: int) -> bool: return not _teams(i).is_empty()


func _new_worker(i: int, slot: int, gen: int, k: int) -> int:
	_wid_next += 1
	workers[_wid_next] = {"fac": int(hosts[i].owner), "home": i, "base": i, "slot": slot, "gen": gen, "k": k, "state": "idle", "fid": -1}
	return _wid_next


func _sync_teams(i: int) -> void:   # a team for every finished station; a station that is gone or being replaced retires its own
	var teams := _teams(i)
	for slot in teams.keys():
		if not _station_live(i, int(slot)): _team_remove(i, int(slot))
	if int(hosts[i].owner) == NEUTRAL: return
	for slot in (hosts[i].builds as Array).size():
		if teams.has(slot) or not _station_live(i, slot): continue
		_inst_gen += 1
		var w := []; var re := []
		for k in WORKERS_PER_STATION:
			w.append(_new_worker(i, slot, _inst_gen, k)); re.append(-1.0)
		teams[slot] = {"gen": _inst_gen, "w": w, "re": re}
		_logi_poke(int(hosts[i].owner))


func _team_remove(i: int, slot: int) -> void:   # the station went (demolished, replaced): idle workers leave, travelling ones retire
	var teams := _teams(i)
	if not teams.has(slot): return
	for wid in (teams[slot].w as Array):
		if int(wid) >= 0 and workers.has(int(wid)): _retire_worker(int(wid))
	teams.erase(slot)


func _retire_worker(wid: int) -> void:   # no new job: it finishes the leg it is on (cargo and all), then it is gone
	var w: Dictionary = workers[wid]
	var f := _flight_of(wid)
	if f.is_empty(): workers.erase(wid); return
	w.state = "retiring"
	_drop_job(f)   # what it was to pick up is released; what it carries it delivers


func _flight_of(wid: int) -> Dictionary:
	var fid := int((workers.get(wid, {}) as Dictionary).get("fid", -1))
	if fid < 0: return {}
	for f in flights:
		if int(f.id) == fid: return f
	return {}


func _worker_lost(wid: int) -> void:   # lost on the road (not with its own host): the slot waits WORKER_REPLACE s of operation
	if not workers.has(wid): return
	var w: Dictionary = workers[wid]
	workers.erase(wid)
	var i := int(w.home)
	var teams := _teams(i)
	if str(w.state) == "retiring" or not teams.has(int(w.slot)) or int(teams[int(w.slot)].gen) != int(w.gen): return
	var t: Dictionary = teams[int(w.slot)]
	var k := (t.w as Array).find(wid)
	if k < 0: return
	t.w[k] = -1; t.re[k] = WORKER_REPLACE


func _kill_home_workers(i: int, by: int) -> int:   # the host is lost: every worker of its stations dies, wherever it is
	var dead := 0
	for wid in workers.keys():
		var w: Dictionary = workers[wid]
		if int(w.home) != i: continue
		var f := _flight_of(int(wid))
		if not f.is_empty(): _settle_lost(f, i, "captured")
		workers.erase(wid)
		dead += 1
	flights = flights.filter(func(x): return not bool(x.get("dead", false)))
	hosts[i].teams = {}
	return dead


func _tick_teams(dt: float) -> void:   # teams follow the stations; a vacant slot is refilled after WORKER_REPLACE s of operation
	for i in hosts.size():
		if int(hosts[i].owner) == NEUTRAL:
			if not _teams(i).is_empty(): hosts[i].teams = {}
			continue
		_sync_teams(i)
		for slot in _teams(i):
			var t: Dictionary = _teams(i)[slot]
			for k in (t.w as Array).size():
				if int(t.w[k]) >= 0 or float(t.re[k]) < 0.0 or not _station_ok(i, int(slot)): continue
				t.re[k] = float(t.re[k]) - dt
				if float(t.re[k]) <= 0.0: t.w[k] = _new_worker(i, int(slot), int(t.gen), k); t.re[k] = -1.0; _logi_poke(int(hosts[i].owner))


func _worker_counts(fac: int, home := -2) -> Dictionary:   # {total, idle, joining, collecting, carrying, blocked, retiring}: all of fac's, or one station host's (home)
	var out := {"total": 0, "idle": 0, "joining": 0, "collecting": 0, "carrying": 0, "blocked": 0, "retiring": 0}
	for wid in workers:
		var w: Dictionary = workers[wid]
		if int(w.fac) != fac or (home != -2 and int(w.home) != home): continue
		if str(w.state) == "retiring": out.retiring = int(out.retiring) + 1; continue
		out.total = int(out.total) + 1
		var st := _worker_state(int(wid))
		out[st] = int(out[st]) + 1
	return out


func _worker_state(wid: int) -> String:   # idle (free at the main node) · joining (not there yet) · collecting · carrying · blocked
	var w: Dictionary = workers.get(wid, {})
	if w.is_empty(): return "idle"
	var hub := _hub(int(w.fac))
	if str(w.state) == "idle": return "idle" if int(w.get("base", w.home)) == hub else "joining"   # waiting at its station for a route
	var f := _flight_of(wid)
	if f.is_empty(): return "idle"
	if bool(f.get("blocked", false)): return "blocked"
	if str(f.trip) == "join": return "joining"
	return "carrying" if not (f.cargo as Dictionary).is_empty() else "collecting"


# ---- where materials are: storage, piles, claims (reservations point at materials, they are never materials) ----
func _hfield(i: int, field: String) -> Dictionary:   # a host's per-faction ledger field ("claim", "loot"), created on first use
	if not hosts[i].has(field): hosts[i][field] = {}
	return hosts[i][field]


func _claimed(i: int, fac: int, res: String) -> float: return float(((hosts[i].get("claim", {}) as Dictionary).get(fac, {}) as Dictionary).get(res, 0.0))
func _loot(i: int, fac: int, res: String) -> float: return float(((hosts[i].get("loot", {}) as Dictionary).get(fac, {}) as Dictionary).get(res, 0.0))
func _inbound(i: int, res: String) -> float: return float((hosts[i].get("inbound", {}) as Dictionary).get(res, 0.0))


func _add_to(i: int, field: String, fac: int, res: String, d: float) -> void:   # claim / loot bookkeeping, never below zero
	var all := _hfield(i, field)
	if not all.has(fac): all[fac] = {}
	var v := maxf(0.0, float((all[fac] as Dictionary).get(res, 0.0)) + d)
	if v < 0.0001: (all[fac] as Dictionary).erase(res)
	else: all[fac][res] = v
	if (all[fac] as Dictionary).is_empty(): all.erase(fac)


func _hadd(i: int, field: String, res: String, d: float) -> void:   # a host-wide {res: amount} field ("inbound")
	if not hosts[i].has(field): hosts[i][field] = {}
	var v := maxf(0.0, float((hosts[i][field] as Dictionary).get(res, 0.0)) + d)
	if v < 0.0001: (hosts[i][field] as Dictionary).erase(res)
	else: hosts[i][field][res] = v


func _inbound_add(i: int, res: String, d: float) -> void: _hadd(i, "inbound", res, d)


func _field_total(i: int, field: String) -> float:
	var s := 0.0
	for r in (hosts[i].get(field, {}) as Dictionary): s += float(hosts[i][field][r])
	return s


func _inbound_total(i: int) -> float: return _field_total(i, "inbound")
func _store_room(i: int) -> float: return STORE_CAP - _store_total(i) - _inbound_total(i)   # what is on its way already holds its room


func _free(fac: int, res: String) -> float:   # main-node stock research, cards, construction and supplies may use (supplies leave with their worker)
	return maxf(0.0, _avail(fac, res))


# ---- what a host needs: its next production cycle, after what it makes itself ----
# One cycle ahead, never an open-ended stock target: Intel harvesters first, then the Firewall's upkeep, then the
# converters in CONVERT_ORDER (a Miner's Crypto can feed the Lab in the same cycle). A converter is funded only as far
# as its WHOLE bundle can be had - here, already on its way, or from the main node's unclaimed stock (shared by the
# hosts in turn through `budget`) - so no input is sequestered for a recipe whose other input cannot come. If the
# shortfalls would not fit the host's free storage, the converters take turns (plan_rr) instead of waiting for all.
func _host_plan(i: int, fac: int, budget: Dictionary) -> Dictionary:   # {frac: {slot: f}, short: {res}, reserve: {res}, export: {res}, limited}
	var out := {"frac": {}, "short": {}, "reserve": {}, "export": {}, "limited": false, "wall": true}
	var stock := {}; var pool := {}; var made := {}; var local_used := {}
	for res in RES:
		stock[res] = maxf(0.0, float(_store_of(i, fac).get(res, 0.0)) - _claimed(i, fac, res))
		made[res] = 0.0; local_used[res] = 0.0; out.short[res] = 0.0
	made.intel = float(BUILD_KINDS.intel.rate) * _tmult(i, "intel") * _count(i, "intel")
	for res in RES: pool[res] = float(stock[res]) + float(made[res]) + _inbound(i, res)
	var room := maxf(0.0, _store_room(i))
	var take := func(res: String, amt: float) -> void:   # amt from the local pool first, the rest asked of the main node
		var l := minf(amt, float(pool[res])); pool[res] = float(pool[res]) - l; local_used[res] = float(local_used[res]) + l
		if amt - l > 0.0001:
			out.short[res] = float(out.short[res]) + amt - l; budget[res] = maxf(0.0, float(budget.get(res, 0.0)) - (amt - l))
	var walls := _count_all(i, "wall") - _walls_building(i)
	if walls > 0:
		var need := float(BUILD_KINDS.wall.use.intel) * walls
		var can := float(pool.intel) + minf(float(budget.get("intel", 0.0)), room)
		if can >= need - 0.0001:
			var ext := maxf(0.0, need - float(pool.intel)); room -= ext
			take.call("intel", need)
		else: out.wall = false
	var inst := []   # the active converters in cycle order: [kind, slot]
	for kind in CONVERT_ORDER:
		for k in (hosts[i].builds as Array).size():
			if str(hosts[i].builds[k]) == kind and _producer_active(i, k): inst.append([kind, k])
	var n := inst.size()
	var rr := int(hosts[i].get("plan_rr", 0))
	for idx in n:
		var it: Array = inst[(idx + rr) % n] if n > 0 else []
		var spec: Dictionary = BUILD_KINDS[str(it[0])]
		var m := _tmult(i, str(spec.out))
		var f := 1.0; var ext_sum := 0.0
		for r in (spec.use as Dictionary):
			var u := float(spec.use[r]) * m
			var have := float(pool[str(r)]) + float(budget.get(str(r), 0.0))
			f = minf(f, have / maxf(0.000001, u))
		for r in (spec.use as Dictionary): ext_sum += maxf(0.0, float(spec.use[r]) * m * f - float(pool[str(r)]))
		if ext_sum > room + 0.0001:   # not enough free storage for its supplies this cycle: what is here only, and it waits its turn
			out.limited = true
			var fl := 1.0
			for r in (spec.use as Dictionary): fl = minf(fl, float(pool[str(r)]) / maxf(0.000001, float(spec.use[r]) * m))
			f = minf(f, fl); ext_sum = 0.0
		if f <= 0.0001: continue
		room -= ext_sum
		for r in (spec.use as Dictionary): take.call(str(r), float(spec.use[r]) * m * f)
		var o := float(spec.rate) * m * f
		pool[str(spec.out)] = float(pool[str(spec.out)]) + o; made[str(spec.out)] = float(made[str(spec.out)]) + o
		out.frac[int(it[1])] = f
	for res in RES:   # what this cycle takes from the current stock (beyond what it makes and what is coming) stays; the rest may go
		var from_stock := clampf(float(local_used[res]) - float(made[res]) - _inbound(i, res), 0.0, float(stock[res]))
		out.reserve[res] = from_stock
		out.export[res] = maxf(0.0, float(stock[res]) - float(out.reserve[res]))
	return out


# ---- requests: what each host needs brought in and has to send out, keeping their age ----
const REQ_CLASS := {"build": 0, "input": 1, "export": 2, "loot": 2}   # purpose order on three of four assignments: building first


func _open_requests(fac: int, hub: int, only := -1) -> Array:   # [{key, id, since, host, purpose, res, qty, dir}] in a stable order
	var want := {}   # key -> [host, purpose, res, qty, dir]
	var budget := {}
	for res in RES: budget[res] = _free(fac, res)
	var n := hosts.size()
	var start := posmod(int(ship_cursor.get(fac, 0)), maxi(1, n))   # the hosts share a short main node in turn
	for k in n:
		var i := (start + k) % n
		if i == hub or (only >= 0 and i != only): continue
		var own := int(hosts[i].owner) == fac
		if own:
			var plan := _host_plan(i, fac, budget)
			_plan_cache[i] = plan; hosts[i].plan_frac = plan.frac; hosts[i].plan_limited = bool(plan.limited)
			for res in RES:
				if float(plan.short[res]) > 0.0001: want["%d:input:%s" % [i, res]] = [i, "input", res, float(plan.short[res]), "in"]
				if float(plan.export[res]) >= 0.999: want["%d:export:%s" % [i, res]] = [i, "export", res, floorf(float(plan.export[res]) + 0.0001), "out"]
			for b in _build_requests(i, fac): want["%d:build:%s:%s" % [i, str(b[0]), str(b[1])]] = [i, "build:" + str(b[0]), str(b[1]), float(b[2]), "in"]
		var pile: Dictionary = (hosts[i].get("loot", {}) as Dictionary).get(fac, {})   # theft and salvage piles; a rival's host's output stored for you
		for res in pile:
			var q := float(pile[res]) - 0.0   # piles are collected as they are, a final fraction included
			if q > 0.0001: want["%d:loot:%s" % [i, res]] = [i, "loot", str(res), q, "out"]
		if not own:
			for res in _store_of(i, fac):
				var q2 := float(_store_of(i, fac)[res]) - _claimed(i, fac, str(res))
				if q2 >= 0.999: want["%d:loot:%s" % [i, res]] = [i, "loot", str(res), floorf(q2 + 0.0001), "out"]
	var keep: Dictionary = _reqs.get(fac, {})
	var now := {}
	for key in want:
		if keep.has(key): now[key] = keep[key]
		else:
			_req_next += 1
			now[key] = {"id": _req_next, "since": _t}
	if only < 0:   # a full pass: requests that ended are dropped; the next pass starts with the next host
		_reqs[fac] = now
		ship_cursor[fac] = (start + 1) % maxi(1, n)
	else:
		for key in now: keep[key] = now[key]
		_reqs[fac] = keep
	var out := []
	for key in now:
		var w: Array = want[key]
		out.append({"key": key, "id": int(now[key].id), "since": float(now[key].since), "host": int(w[0]), "purpose": str(w[1]), "res": str(w[2]), "qty": float(w[3]), "dir": str(w[4])})
	out.sort_custom(func(a, b): return int(a.id) < int(b.id))
	return out


func _req_class(r: Dictionary) -> int: return int(REQ_CLASS.get(str(r.purpose).split(":")[0], 2))


func _amount(fac: int, hub: int, r: Dictionary) -> float:   # what one worker could carry for request r right now (0: not feasible)
	var res := str(r.res); var i := int(r.host)
	var amt := minf(WORKER_CARRY, float(r.qty))
	if str(r.dir) == "in":
		if _free(fac, res) < amt - 0.0001: return 0.0                    # the main node does not have it
		if str(r.purpose).begins_with("build:"):
			if not _build_room(i, str(r.purpose).trim_prefix("build:"), res, amt): return 0.0
		elif _store_room(i) < amt - 0.0001: return 0.0                     # no room at the host for it
	else:
		var have := _pile_or_store(i, fac, res)
		amt = minf(amt, have)
		if amt <= 0.0001 or (str(r.purpose) == "export" and amt < 0.999): return 0.0
		if _room(fac, res) < amt - 0.0001: return 0.0                       # a full bank takes nothing more
	return amt


func _pile_or_store(i: int, fac: int, res: String) -> float:   # what fac's workers may take from host i: its pile, then what is stored for it
	return _loot(i, fac, res) + maxf(0.0, float(_store_of(i, fac).get(res, 0.0)) - _claimed(i, fac, res))


func _route_ok(fac: int, hub: int, i: int) -> bool:   # a worker can make the trip between the main node and host i
	if i == hub: return true
	if _routing_down(hub) or _routing_down(i): return false
	return _travel_route(fac, hub, i).size() >= 2 and _travel_route(fac, i, hub).size() >= 2


func _served_at(fac: int, i: int) -> int: return int((_served.get(fac, {}) as Dictionary).get(i, -1))


func _mark_served(fac: int, i: int) -> void:
	_serve_n[fac] = int(_serve_n.get(fac, 0)) + 1
	if not _served.has(fac): _served[fac] = {}
	_served[fac][i] = int(_serve_n[fac])


func _served_res_at(fac: int, i: int, res: String) -> int:
	return int(((_served_res.get(fac, {}) as Dictionary).get(i, {}) as Dictionary).get(res, -1))


func _mark_res(fac: int, r: Dictionary) -> void:   # this host's resource was just moved: its others go first next time
	if r.is_empty(): return
	if not _served_res.has(fac): _served_res[fac] = {}
	if not (_served_res[fac] as Dictionary).has(int(r.host)): _served_res[fac][int(r.host)] = {}
	_served_res[fac][int(r.host)][str(r.res)] = int(_serve_n.get(fac, 0))


func _pick_request(fac: int, cands: Array, turn: int) -> Dictionary:   # three of four by purpose, then the least recently served host;
	var best := {}                                                      # the fourth by host turn alone (round robin, nobody starves)
	var fair: bool = turn % (PRIORITY_TURNS + 1) == PRIORITY_TURNS
	var bk := []
	for r in cands:
		var h := int(r.host); var rs := _served_res_at(fac, h, str(r.res))   # (within a host, the resource moved longest ago)
		var k := [_served_at(fac, h), rs, int(r.id)] if fair else [_req_class(r), _served_at(fac, h), rs, int(r.id)]
		if best.is_empty() or k < bk: best = r; bk = k
	return best


func _tick_logistics() -> void:   # every step: free workers take the most useful feasible job (nothing waits for a planning pulse)
	_plan_cache = {}
	for fac in botnets:
		if _eliminated.has(fac): continue
		var hub := _hub(fac)
		if hub < 0: continue
		var idle := []; var joiners := []   # free at the main node / free at their station's host, not yet at the main node
		for wid in workers:
			var w: Dictionary = workers[wid]
			if int(w.fac) != fac or str(w.state) != "idle": continue
			if int(w.get("base", w.home)) == hub: idle.append(int(wid))
			elif not _routing_down(int(w.get("base", w.home))): joiners.append(int(wid))
		if idle.is_empty() and joiners.is_empty(): continue
		if not bool(_logi_dirty.get(fac, true)) and _t < float(_logi_next.get(fac, 0.0)): continue   # nothing new since the last look
		_logi_dirty[fac] = false; _logi_next[fac] = _t + LOGI_EVERY
		idle.sort(); joiners.sort()
		var reqs := _open_requests(fac, hub)
		for wid in joiners: _join(fac, hub, wid, reqs)
		for wid in idle:
			if not _assign(fac, hub, wid, reqs): break


func _join(fac: int, hub: int, wid: int, reqs: Array) -> void:   # a new worker goes to the main node, with its host's surplus if any
	var at := int(workers[wid].get("base", workers[wid].home))
	if not _route_ok(fac, hub, at): return
	var cands := []
	for r in reqs:
		if int(r.host) != at or str(r.dir) != "out": continue
		var amt := _amount(fac, hub, r)
		if amt > 0.0001: var c: Dictionary = r.duplicate(); c.amt = amt; cands.append(c)
	var cargo := {}
	var outr := _pick_request(fac, cands, 0)
	_mark_res(fac, outr)
	if not outr.is_empty():
		_take_from(at, fac, str(outr.res), float(outr.amt)); _reserve_incoming(fac, str(outr.res), float(outr.amt))
		cargo[str(outr.res)] = float(outr.amt)
		for q in reqs:
			if str(q.key) == str(outr.key): q.qty = float(q.qty) - float(outr.amt)
	var f := _launch(fac, wid, at, hub, cargo, at, {}, _travel_route(fac, at, hub))
	f.trip = "join"
	f.covered = float(hosts[at].get("cover_until", 0.0)) > _t


func _assign(fac: int, hub: int, wid: int, reqs: Array) -> bool:   # one new trip for this worker, or false if nothing is feasible
	var cands := []
	for r in reqs:
		if not _route_ok(fac, hub, int(r.host)): continue
		var amt := _amount(fac, hub, r)
		if amt > 0.0001: var c: Dictionary = r.duplicate(); c.amt = amt; cands.append(c)
	if cands.is_empty(): return false
	var turn := int(_pool_turn.get(fac, 0))
	var pick := _pick_request(fac, cands, turn)
	_pool_turn[fac] = turn + 1
	var i := int(pick.host)
	_mark_served(fac, i)
	var other := "out" if str(pick.dir) == "in" else "in"   # the other leg carries something too when it can
	var comp := _pick_request(fac, cands.filter(func(c): return int(c.host) == i and str(c.dir) == other and str(c.key) != str(pick.key)), 0)
	var inr: Dictionary = pick if str(pick.dir) == "in" else comp
	var outr: Dictionary = pick if str(pick.dir) == "out" else comp
	_mark_res(fac, inr); _mark_res(fac, outr)
	_send_from_hub(fac, hub, wid, i, inr, outr)
	for r in [inr, outr]:   # what this trip took is no longer open for the next worker in the same step
		if r.is_empty(): continue
		for q in reqs:
			if str(q.key) == str(r.key): q.qty = float(q.qty) - float(r.amt)
	return true


func _send_from_hub(fac: int, hub: int, wid: int, i: int, inr: Dictionary, outr: Dictionary) -> void:   # main node -> host -> main node
	var cargo := {}; var purpose := ""
	if not inr.is_empty():   # the supply leaves the bank with the worker
		_spend(fac, str(inr.res), float(inr.amt), "supply")
		_hold_dest(i, str(inr.purpose), str(inr.res), float(inr.amt), "inbound")
		cargo[str(inr.res)] = float(inr.amt); purpose = str(inr.purpose)
	var job := {}
	if not outr.is_empty():   # what it collects there is claimed for it now
		_claim_at(i, fac, str(outr.res), float(outr.amt)); _reserve_incoming(fac, str(outr.res), float(outr.amt))
		job = {"purpose": str(outr.purpose), "res": str(outr.res), "amt": float(outr.amt), "src": i}
	var f := _launch(fac, wid, hub, i, cargo, hub, job, _travel_route(fac, hub, i))
	f.purpose = purpose


func _launch(fac: int, wid: int, home: int, dest: int, cargo: Dictionary, src: int, job: Dictionary, rt: Array) -> Dictionary:
	var express := float(hosts[home].get("express_until", 0.0)) > _t
	var covered := float(hosts[home].get("cover_until", 0.0)) > _t
	var f := _schedule(rt, _t, fac, "courier", express, {"wid": wid, "origin": home, "dest": dest, "trip": "out", "cargo": cargo,
		"src": src, "job": job, "purpose": "", "covered": covered, "dest_own": _owns(fac, dest)})
	flights.append(f)
	workers[wid].state = "trip"; workers[wid].fid = int(f.id)
	return f


func _take_from(i: int, fac: int, res: String, amt: float) -> void:   # out of host i for fac: its pile first, then its storage
	var l := minf(amt, _loot(i, fac, res))
	if l > 0.0: _add_to(i, "loot", fac, res, -l)
	if amt - l > 0.0001: _store_take(i, fac, res, amt - l)


func _claim_at(i: int, fac: int, res: String, amt: float) -> void: _add_to(i, "claim", fac, res, amt)


func _hold_dest(i: int, purpose: String, res: String, amt: float, field: String) -> void:   # room held at the destination for what is coming
	if purpose.begins_with("build:"): _build_hold(i, purpose.trim_prefix("build:"), res, amt, field); return
	_hadd(i, field, res, amt)


func _release_dest(i: int, purpose: String, res: String, amt: float, field: String) -> void:
	if purpose.begins_with("build:"): _build_hold(i, purpose.trim_prefix("build:"), res, -amt, field); return
	_hadd(i, field, res, -amt)


func _drop_job(f: Dictionary) -> void:   # the pickup this worker was going to make is released (its cargo stays with it)
	var job: Dictionary = f.get("job", {})
	if job.is_empty() or str(f.trip) != "out": return
	var fac := int(f.owner)
	if job.has("src"):   # a worker going to collect at a host
		_add_to(int(job.src), "claim", fac, str(job.res), -float(job.amt)); _release_incoming(fac, str(job.res), float(job.amt))
	f.job = {}


func _end_ok(f: Dictionary, d: int) -> bool:   # may this packet enter its destination d right now?
	var fac := int(f.owner)
	match str(f.kind):
		"courier":
			if d == int(f.origin): return _owns(fac, d)        # home: must still be home
			return not bool(f.get("dest_own", false)) or _owns(fac, d)   # a host of yours must still be yours
		"op":
			if bool(f.get("returning", false)) or _is_defense(_card_of(str(f.get("card", "")))): return _owns(fac, d)
			return true   # an attack may end at a foreign host; a target taken meanwhile is void on landing
	return true


func _advance_flights() -> void:   # every packet leaves a host only if that host and the next are good for it
	for f in flights:
		if bool(f.get("blocked", false)) or bool(f.get("dead", false)): continue
		var rt: Array = f.route; var hops: Array = f.hops
		var fac := int(f.owner)
		while int(f.get("hop_i", 0)) < hops.size() and _t >= float(hops[int(f.hop_i)]) - 0.00001:
			var k := int(f.hop_i)
			var here := int(rt[k]); var nxt := int(rt[k + 1])
			if k > 0 and int(hosts[here].owner) != fac: _lose(f, here, "taken"); break   # the relay it was in was taken
			if _routing_down(here) and k > 0: _block(f, here); break                      # a relay under DDoS cannot forward
			_siphon_grab(f, here)
			var last := k + 1 == rt.size() - 1
			if (not last and (int(hosts[nxt].owner) != fac or _routing_down(nxt))) or (last and not _end_ok(f, nxt)):
				_block(f, here); break
			f.hop_i = k + 1
	flights = flights.filter(func(x): return not bool(x.get("dead", false)))


func _block(f: Dictionary, at: int) -> void:   # stop at host `at` and wait there; _tick_blocked tries again
	f.blocked = true; f.at = at; f.blocked_t = _t
	f.route = [at]; f.hops = []; f.hop_i = 0; f.arrive_t = INF   # the "held" event per host comes from _tick_events


func _reroute(f: Dictionary, rt: Array) -> void:   # go on from where it is, along rt, with fresh link slots
	var fac := int(f.owner)
	var plan := _plan_hops(rt, _t, bool(f.get("express", false)))
	_establish(fac, rt)
	f.route = rt; f.hops = plan.hops; f.lt = plan.lt; f.depart_t = _t; f.arrive_t = plan.arrive; f.hop_i = 0
	if bool(f.get("blocked", false)): f.blocked = false; f.erase("at")


func _tick_blocked() -> void:   # held packets: on when a route opens; turned back when their end is gone
	for f in flights:
		if not bool(f.get("blocked", false)) or bool(f.get("dead", false)): continue
		var fac := int(f.owner); var at := int(f.at)
		var foreign_end := str(f.kind) == "courier" and ((not bool(f.get("dest_own", true)) and at == int(f.get("dest", -1))) \
			or at == int(f.get("pickup", -1)))   # held where it collected on a rival's host: it waits there for a way home
		if int(hosts[at].owner) != fac and not foreign_end: _lose(f, at, "taken"); continue   # the host it waits in was taken
		if _routing_down(at): continue
		var dest := int(f.get("dest", -1))
		if str(f.kind) == "op":
			var giving_up := _t - float(f.get("blocked_t", _t)) >= CARD_GIVE_UP
			if not bool(f.get("returning", false)) and (giving_up or not _end_ok(f, dest)): _card_turn_home(f)
			dest = int(f.dest)
		elif str(f.kind) == "courier":
			if str(f.trip) == "out" and not _end_ok(f, dest): _courier_turn_home(f)
			dest = int(f.dest)
		if dest < 0: _lose(f, at, "stranded"); continue
		if dest == at:   # already where it has to be (it was held at its own end)
			if str(f.kind) == "courier":
				if not _courier_arrive(f): f.dead = true
			else:
				if bool(f.get("returning", false)): _card_back(f)
				f.dead = true
			continue
		var rt := _travel_route(fac, at, dest)
		if rt.size() >= 2 and _end_ok(f, dest): _reroute(f, rt)
	flights = flights.filter(func(x): return not bool(x.get("dead", false)))


func _card_back(f: Dictionary) -> void:   # a card that turned home is a ready copy again
	var fac := int(f.owner); var recipe := _card_of(str(f.card))
	cards[fac][recipe] = _held(fac, recipe) + 1
	if fac == PLAYER:
		_event("cardback:%d" % int(f.id), EV_INFO, "Your %s came back to your hand: it could not reach %s." % [str(CARDS[recipe].name), str(hosts[int(f.target)].name)], int(f.target))
		_refresh_hand()


func _card_turn_home(f: Dictionary) -> void:   # a card that cannot go on heads back; the copy returns to your hand there
	f.returning = true; f.dest = _hub(int(f.owner))
	if bool(f.get("load", false)): _release_socket(int(f.get("target", -1)), str(f.get("sock", ""))); f.load = false


func _courier_turn_home(f: Dictionary) -> void:   # its destination is gone: back home with what it carries; its pickup is released
	var fac := int(f.owner)
	_drop_job(f)
	var home := int(f.origin)
	var hub := _hub(fac)
	for res in (f.cargo as Dictionary):   # cargo for the lost destination: its room there is released, room at home is held
		var q := float(f.cargo[res])
		if int(f.dest) == hub: _release_incoming(fac, str(res), q)
		else: _release_dest(int(f.dest), str(f.get("purpose", "")), str(res), q, "inbound")
		if home == hub: _reserve_incoming(fac, str(res), q)
		else: _hadd(home, "inbound", str(res), q)
	f.purpose = "input"; f.trip = "back"; f.dest = home


func _settle_lost(f: Dictionary, at: int, why: String) -> void:   # the worker and its cargo are gone: every reservation it held is released once
	var fac := int(f.owner)
	f.dead = true
	_drop_job(f)
	var hub := _hub(fac)
	for res in (f.cargo as Dictionary):   # cargo for the main node held bank room; cargo for a host held storage (or escrow) room
		var q := float(f.cargo[res])
		if int(f.get("dest", -1)) == hub and hub >= 0: _release_incoming(fac, str(res), q)
		else: _release_dest(int(f.dest), str(f.get("purpose", "")), str(res), q, "inbound")
		_ledger_add(fac, "lost", "cargo", str(res), q)
	f.cargo = {}
	if fac == PLAYER and why != "captured": _event("lostworker", EV_ACT, "A worker was lost at %s: the host was %s." % [str(hosts[at].name), why], at)


func _lose(f: Dictionary, at: int, why: String) -> void:   # the packet is gone: settle every reservation it held
	var fac := int(f.owner)
	if str(f.kind) == "courier":
		_settle_lost(f, at, why)
		_worker_lost(int(f.get("wid", -1)))
		return
	f.dead = true
	if str(f.kind) == "op":
		if bool(f.get("load", false)): _release_socket(int(f.get("target", -1)), str(f.get("sock", "")))
		if fac == PLAYER: _event("lostcard:%d" % int(f.id), EV_ACT, "Your %s was lost at %s: the host was %s." % [str(CARDS[_card_of(str(f.card))].name), str(hosts[at].name), why], at)


func _siphon_grab(f: Dictionary, here: int) -> void:   # a Packet siphon on this host takes the matching cargo off a worker leaving it
	var sp: Dictionary = hosts[here].get("siphon", {})
	if sp.is_empty() or float(sp.get("until", 0.0)) <= _t or int(sp.get("left", 0)) <= 0: return
	var thief := int(sp.by); var res := str(sp.res)
	if str(f.kind) != "courier" or int(f.owner) == thief or bool(f.get("covered", false)) or not (f.cargo as Dictionary).has(res): return
	var victim := int(f.owner); var o := int(f.get("src", f.origin))   # the host the cargo left
	if _owns(victim, o) and _fire_socket(o, "cover", "Packet siphon"):   # a loaded Cover saves this cargo and its host's next ones
		_apply_cover(o); return
	var q := float(f.cargo[res])
	(f.cargo as Dictionary).erase(res)
	if int(f.dest) == _hub(victim): _release_incoming(victim, res, q)
	else: _release_dest(int(f.dest), str(f.get("purpose", "")), res, q, "inbound")
	_ledger_add(victim, "lost", "siphoned", res, q)
	_add_to(here, "loot", thief, res, q)   # it waits here for the thief's workers; the worker itself goes on
	sp.left = int(sp.left) - 1
	if int(sp.left) == 0 and thief == PLAYER: _flash("Packet siphon on %s: full haul taken" % str(hosts[here].name), 0)


func _courier_arrive(f: Dictionary) -> bool:   # true: the worker goes on (back home); false: it is home (free) or retired
	var fac := int(f.owner); var at := int(f.route[f.route.size() - 1])
	var hub := _hub(fac)
	var wid := int(f.get("wid", -1))
	for res in (f.cargo as Dictionary): _drop_unit(fac, at, str(res), float(f.cargo[res]), f)
	f.cargo = {}
	var retiring := str((workers.get(wid, {}) as Dictionary).get("state", "")) == "retiring"
	if retiring or not workers.has(wid):   # a retiring worker's last leg ends here
		_drop_job(f); workers.erase(wid); return false
	if str(f.trip) == "join":   # a new worker reached the main node: from now on it works from there
		workers[wid].base = at
		workers[wid].state = "idle"; workers[wid].fid = -1
		_logi_poke(fac)
		return false
	if str(f.trip) == "out":
		var home := int(f.origin)   # the main node
		var job: Dictionary = f.get("job", {})
		f.job = {}; f.purpose = ""
		if not job.is_empty():   # at the host: what it came for, else anything that may go
			_add_to(at, "claim", fac, str(job.res), -float(job.amt))
			var got := minf(float(job.amt), _pile_or_store(at, fac, str(job.res)))
			if got > 0.0001: _take_from(at, fac, str(job.res), got); f.cargo = {str(job.res): got}; f.src = at
			if float(job.amt) - got > 0.0001: _release_incoming(fac, str(job.res), float(job.amt) - got)
		elif at != home: _backhaul(fac, hub, f, at)
		f.trip = "back"; f.dest = home
		var own_here := int(hosts[at].owner) == fac   # a rival's Express or Cargo cover on its own host never helps your workers
		f.pickup = -1 if own_here else at
		f.express = own_here and float(hosts[at].get("express_until", 0.0)) > _t   # Express on this host speeds what leaves it
		if (f.cargo as Dictionary).size() > 0: f.covered = own_here and float(hosts[at].get("cover_until", 0.0)) > _t   # so does Cargo cover
		var rt := _travel_route(fac, at, home)
		if rt.size() >= 2 and _end_ok(f, home): _reroute(f, rt)
		else: _block(f, at)
		return true
	# home again: free for the next job at once (the same step's dispatch sees it)
	workers[wid].state = "idle"; workers[wid].fid = -1
	_logi_poke(fac)
	return false


func _backhaul(fac: int, hub: int, f: Dictionary, i: int) -> void:   # an empty return leg takes the host's surplus if any may go
	var cands := []
	for r in _open_requests(fac, hub, i):
		if str(r.dir) != "out": continue
		var amt := _amount(fac, hub, r)
		if amt > 0.0001: var c: Dictionary = r.duplicate(); c.amt = amt; cands.append(c)
	var r := _pick_request(fac, cands, 0)
	if r.is_empty(): return
	_mark_res(fac, r)
	_take_from(i, fac, str(r.res), float(r.amt)); _reserve_incoming(fac, str(r.res), float(r.amt))
	f.cargo = {str(r.res): float(r.amt)}; f.src = i


func _drop_unit(fac: int, at: int, res: String, q: float, f: Dictionary) -> void:   # carried cargo lands: the bank at the main node, a host's storage or escrow elsewhere
	if at == _hub(fac):
		_release_incoming(fac, res, q)
		var src := int(f.get("src", -1))
		var stolen := src >= 0 and src != at and int(hosts[src].owner) != fac
		_bank_put(fac, res, q, "stolen" if stolen else ("returned" if src == at else "delivered"))
		if src >= 0 and src != at: _ledger_add(fac, "from", str(src), res, q)
		_delivered[fac] = int(_delivered.get(fac, 0)) + 1
		return
	var purpose := str(f.get("purpose", ""))
	_release_dest(at, purpose, res, q, "inbound")
	if purpose.begins_with("build:") and _build_take(at, purpose.trim_prefix("build:"), res, q): return
	if not (hosts[at].store as Dictionary).has(fac): hosts[at].store[fac] = {}
	hosts[at].store[fac][res] = float((hosts[at].store[fac] as Dictionary).get(res, 0.0)) + q   # its room was held on the way


func _bank_put(fac: int, res: String, amt: float, cause: String) -> void:   # credit what was carried in (its room was held on the way)
	if not bank.has(fac): return
	bank[fac][res] = _avail(fac, res) + amt
	_ledger_add(fac, "in", cause, res, amt)


func _res_list(d: Dictionary) -> String:   # "1 Intel + 0.5 Crypto"
	var parts := []
	for res in RES:
		if float(d.get(res, 0.0)) > 0.0001: parts.append("%s %s" % [_amt(float(d[res])), RES_NAME[res]])
	return " + ".join(parts)


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


# ---- the Firewall: FIREWALL_SOCKETS defence cards per Firewall, each firing itself when its attack hits this host ----
const SOCKET_TRIGGER := {"patch": "a capture, Worm or Vault raid starts here", "response": "Phishing, Packet siphon or sabotage lands here",
	"filter": "a DDoS lands here", "cover": "a Packet siphon grabs cargo from here"}


func _sockets(i: int) -> int: return FIREWALL_SOCKETS * maxi(0, _count_all(i, "wall") - _walls_building(i))
func _socketable(recipe: String) -> bool: return SOCKET_TRIGGER.has(recipe)
# hosts[i].sockets holds one entry per socket position: "" empty, a recipe loaded, "@recipe#flight" held for a card on its way
# (a shorter array means the rest are empty). Positions are seated on the finished Firewalls in slot order, 3 each
# (_wall_seat): the leftmost Firewall holds positions 0-2, the next 3-5. A Firewall that finishes gets its 3 empty
# positions inserted at its seat, one that is demolished or replaced takes its own 3 away (and loses the cards in
# them), so every card stays in the Firewall it was loaded into.
func _socket_free(i: int) -> bool: return _free_socket(i) >= 0
func _fw_live(i: int) -> bool: return _sockets(i) > 0 and bool(hosts[i].get("fw_on", true))


func _free_socket(i: int) -> int:   # the first empty socket position (cards on their way hold theirs), -1 if none
	var socks: Array = hosts[i].sockets
	for k in _sockets(i):
		if k >= socks.size() or str(socks[k]) == "": return k
	return -1


func _put_socket(i: int, val: String) -> int:   # fill the first empty position with val; its index, -1 if full
	var k := _free_socket(i)
	if k < 0: return -1
	var socks: Array = hosts[i].sockets
	while socks.size() <= k: socks.append("")
	socks[k] = val
	return k


func _loaded(i: int) -> Array: return _loaded_of(hosts[i].sockets)
func _loaded_of(socks: Array) -> Array:   # the recipes loaded (not the empty or held positions)
	var out := []
	for v in socks:
		if str(v) != "" and not str(v).begins_with("@"): out.append(str(v))
	return out


func _socket_res(i: int) -> int:   # positions held for cards on their way
	var n := 0
	for v in (hosts[i].sockets as Array):
		if str(v).begins_with("@"): n += 1
	return n


func _release_socket(i: int, token: String) -> bool:   # a held position is free again (its card acts, turns back or is lost)
	if not _host_ok(i): return false
	var k := (hosts[i].sockets as Array).find(token)
	if k < 0: return false
	hosts[i].sockets[k] = ""
	return true


func _wall_seat(i: int, slot: int) -> int:   # which finished Firewall this slot's is, counting from the left
	var j := 0
	for k in slot:
		if str(hosts[i].builds[k]) == "wall" and not (hosts[i].jobs as Dictionary).has(k): j += 1
	return j


func _seat_out(i: int, slot: int) -> void:   # this Firewall stops working: its 3 positions go, with what is in them
	var socks: Array = hosts[i].sockets
	var a := FIREWALL_SOCKETS * _wall_seat(i, slot)
	for k in FIREWALL_SOCKETS:
		if a < socks.size(): socks.remove_at(a)


func _seat_in(i: int, slot: int) -> void:   # a Firewall starts working: 3 empty positions at its seat
	var socks: Array = hosts[i].sockets
	var a := FIREWALL_SOCKETS * _wall_seat(i, slot)
	if a < socks.size():
		for k in FIREWALL_SOCKETS: socks.insert(a, "")


func _trim_sockets(i: int) -> void:   # never more positions than the finished Firewalls have
	var socks: Array = hosts[i].sockets
	if socks.size() > _sockets(i): socks.resize(_sockets(i))


func _trigger_now(recipe: String, i: int) -> bool:   # the attack this card answers is already running here
	match recipe:
		"patch":
			for e in _execs:
				if int(e.target) == i and str(e.effect) in ["capture", "worm", "vault"]: return true
		"response": return _phished(i) or _sabotaged(i) or not (hosts[i].get("siphon", {}) as Dictionary).is_empty()
		"filter": return _ddos_down(i)
	return false


func _fire_socket(i: int, recipe: String, what: String) -> bool:   # a loaded card answers an attack; true if it fired
	if not _fw_live(i) or not (hosts[i].sockets as Array).has(recipe): return false
	hosts[i].sockets[(hosts[i].sockets as Array).find(recipe)] = ""   # the position stays where it is, empty
	var owner := int(hosts[i].owner)
	hosts[i].hit_t = _t
	_fx.append({"host": i, "until": _t + 2.0, "col": fcol(owner)})
	hosts[i].card_result = "Firewall fired %s" % str(CARDS[recipe].name)
	if owner == PLAYER:
		_flash("Firewall on %s fired %s against %s" % [str(hosts[i].name), str(CARDS[recipe].name), what], 0)
		var left := _loaded(i).size()
		_event("fw:%d:%s" % [i, recipe], EV_INFO, "Firewall on %s fired %s against %s; %s left in it." % [str(hosts[i].name), str(CARDS[recipe].name), what, "no cards" if left == 0 else ("1 card" if left == 1 else "%d cards" % left)], i)
	return true


# ---- construction: an order is supplied before it is built ----
# Ordering costs nothing yet: the project waits at its site with its exact bill. What the host has spare goes into the
# project's escrow at once (at the main node: unclaimed bank stock); the rest is brought by workers, one unit per leg,
# straight into that escrow (it is not ordinary storage, so a 16-unit bill fits a 10-unit host). Only when the whole
# bill is there does the BUILD_TIME of work run. Replacing an installation stops it at once and demolishes it first
# (DEMOLISH_TIME) while the materials are being delivered. Pausing stops work and new deliveries; cancelling leaves
# what was delivered (less what the work has used) at the site as a salvage pile, never back in the bank by magic.
var _job_next := 0


func _start_job(i: int, kind: String, slot := -1) -> bool:
	if i < 0 or int(hosts[i].owner) == NEUTRAL or not BUILD_KINDS.has(kind): return false
	if slot < 0: slot = _free_slot(i)
	if slot < 0 or slot >= (hosts[i].builds as Array).size() or _slot_busy(i, slot): return false
	var cur := str(hosts[i].builds[slot])
	if cur == kind: return false
	(hosts[i].get("producer_paused", {}) as Dictionary).erase(slot)
	if cur == "wall": _seat_out(i, slot)   # replaced: it stops working now
	_job_next += 1
	hosts[i].jobs[slot] = {"id": _job_next, "kind": kind, "slot": slot, "phase": "build" if cur == "" else "demolish",
		"left": BUILD_TIME if cur == "" else DEMOLISH_TIME, "total": BUILD_TIME if cur == "" else DEMOLISH_TIME,
		"bill": _build_cost(kind), "escrow": {}, "inbound": {}, "paused": false}
	if cur == "bot": _sync_teams(i)   # a replaced station's workers retire now
	return true


func _job_funded(job: Dictionary) -> bool:
	for r in (job.get("bill", {}) as Dictionary):
		if float((job.escrow as Dictionary).get(r, 0.0)) < float(job.bill[r]) - 0.0001: return false
	return true


func _job_short(job: Dictionary, res: String) -> float:   # bill not yet here or on its way
	return maxf(0.0, float((job.get("bill", {}) as Dictionary).get(res, 0.0)) - float((job.escrow as Dictionary).get(res, 0.0)) - float((job.inbound as Dictionary).get(res, 0.0)))


func _build_purpose(job: Dictionary) -> String: return "%d:%d" % [int(job.slot), int(job.id)]


func _job_for(i: int, key: String) -> Dictionary:   # the job a "slot:id" purpose names, or {} if it is gone
	var p := key.split(":")
	if p.size() != 2: return {}
	var job: Dictionary = (hosts[i].jobs as Dictionary).get(int(p[0]), {})
	if job.is_empty() or int(job.get("id", -1)) != int(p[1]): return {}
	return job


func _build_requests(i: int, fac: int) -> Array:   # [[slot:id, res, amount]] still to bring for this host's projects
	var out := []
	if i == _hub(fac): return out
	for slot in (hosts[i].jobs as Dictionary):
		var job: Dictionary = hosts[i].jobs[slot]
		if bool(job.get("paused", false)) or str(job.get("kind", "")) == "": continue
		for res in RES:
			var s := _job_short(job, res)
			if s > 0.0001: out.append([_build_purpose(job), res, s])
	return out


func _build_room(i: int, key: String, res: String, amt: float) -> bool:
	var job := _job_for(i, key)
	return not job.is_empty() and not bool(job.get("paused", false)) and _job_short(job, res) >= amt - 0.0001


func _build_hold(i: int, key: String, res: String, d: float, field: String) -> void:
	var job := _job_for(i, key)
	if job.is_empty(): return
	var v := maxf(0.0, float((job[field] as Dictionary).get(res, 0.0)) + d)
	if v < 0.0001: (job[field] as Dictionary).erase(res)
	else: job[field][res] = v


func _build_take(i: int, key: String, res: String, q: float) -> bool:   # delivered building material: into its escrow, the rest to the site's pile
	var job := _job_for(i, key)
	var fac := int(hosts[i].owner)
	var fit := 0.0
	if not job.is_empty():
		fit = minf(q, maxf(0.0, float(job.bill.get(res, 0.0)) - float((job.escrow as Dictionary).get(res, 0.0))))
		if fit > 0.0: job.escrow[res] = float((job.escrow as Dictionary).get(res, 0.0)) + fit
	if q - fit > 0.0001: _add_to(i, "loot", fac, res, q - fit)   # a cancelled project's delivery: salvage at the site
	return true


func _fill_escrow(i: int, job: Dictionary) -> void:   # what is already at the site goes in first (after its own production's needs)
	var fac := int(hosts[i].owner)
	var needs := {} if i == _hub(fac) else _cycle_needs(i)   # one cycle's inputs stay in storage: inputs come before construction
	for res in RES:
		var need := maxf(0.0, float(job.bill.get(res, 0.0)) - float((job.escrow as Dictionary).get(res, 0.0)))
		if need <= 0.0001: continue
		var have := 0.0
		if i == _hub(fac): have = _free(fac, res)
		else:
			var plan: Dictionary = _plan_cache.get(i, {})
			var keep := maxf(float((plan.get("reserve", {}) as Dictionary).get(res, 0.0)), float(needs.get(res, 0.0)))
			have = _loot(i, fac, res) + maxf(0.0, float(_store_of(i, fac).get(res, 0.0)) - _claimed(i, fac, res) - keep)
		var q := minf(need, have)
		if q <= 0.0001: continue
		_logi_poke(fac)
		if i == _hub(fac): _spend(fac, res, q, "buildings")
		else: _take_from(i, fac, res, q)
		job.escrow[res] = float((job.escrow as Dictionary).get(res, 0.0)) + q


func _job_salvage(i: int, job: Dictionary, frac: float) -> void:   # the unused share of the escrow stays at the site as a pile
	var fac := int(hosts[i].owner)
	for res in (job.escrow as Dictionary):
		var q := float(job.escrow[res]) * frac
		if q <= 0.0001: continue
		if i == _hub(fac): _bank_put(fac, str(res), q, "refunds")   # at the main node the site is the bank
		else: _add_to(i, "loot", fac, str(res), q)
	job.escrow = {}


func _can_drop(i: int, slot: int, kind: String) -> bool:
	return _can_build(PLAYER, i, slot, kind)


func _can_build(fac: int, i: int, slot: int, kind: String) -> bool:   # ownership and a free slot; the materials come after the order
	if not _owns(fac, i) or not BUILD_KINDS.has(kind): return false
	return slot >= 0 and slot < (hosts[i].builds as Array).size() and not _slot_busy(i, slot) and str(hosts[i].builds[slot]) != kind


func _drop_build(i: int, slot: int, kind: String) -> void: _cmd(["build", i, slot, kind])


func _do_build(fac: int, i: int, slot: int, kind: String) -> void:
	if not _owns(fac, i) or not BUILD_KINDS.has(kind): return   # a malformed command from the wire does nothing
	if _start_job(i, kind, slot) and fac == PLAYER:
		_flash("%s ordered at %s: its %s are on their way" % [str(BUILD_KINDS[kind].name), str(hosts[i].name), _build_cost_text(kind)] if i != _hub(fac) else "%s ordered: %s" % [str(BUILD_KINDS[kind].name), _build_cost_text(kind)], 0)
		_refresh_panel(); queue_redraw()


func _card_click(kind: String) -> void:
	var i := _build_site()
	if i >= 0: _cmd(["build", i, _free_slot(i), kind])


func _build_site() -> int:
	if sel.size() == 1 and _mine(int(sel.keys()[0])): return int(sel.keys()[0])
	return _inspect if _mine(_inspect) else -1


func _player_build(i: int, kind: String) -> void:
	_do_build(PLAYER, i, _free_slot(i), kind)


func _toggle_job(i: int, slot: int) -> void: _cmd(["job", i, slot])


func _do_toggle_job(fac: int, i: int, slot: int) -> void:   # pause: no work and no new deliveries; loaded ones still land in its escrow
	if not _owns(fac, i) or not (hosts[i].jobs as Dictionary).has(slot): return
	var job: Dictionary = hosts[i].jobs[slot]
	job.paused = not bool(job.get("paused", false))
	if fac == PLAYER: _refresh_panel()


func _cancel_job(i: int, slot: int) -> void: _cmd(["cancel", i, slot])


func _do_cancel_job(fac: int, i: int, slot: int) -> void:
	if not _owns(fac, i) or not (hosts[i].jobs as Dictionary).has(slot): return
	var job: Dictionary = hosts[i].jobs[slot]
	var started := str(job.phase) == "build" and _job_funded(job) and float(job.left) < float(job.total) - 0.0001
	_job_salvage(i, job, clampf(float(job.left) / maxf(0.001, float(job.total)), 0.0, 1.0) if started else 1.0)   # the worked share is used up
	(hosts[i].jobs as Dictionary).erase(slot)
	if fac == PLAYER: _refresh_panel(); queue_redraw()


func _demolish(i: int, slot: int) -> void: _cmd(["demolish", i, slot])


func _do_demolish(fac: int, i: int, slot: int) -> void:
	if not _owns(fac, i) or slot < 0 or slot >= (hosts[i].builds as Array).size(): return
	if str(hosts[i].builds[slot]) == "" or _slot_busy(i, slot): return
	if str(hosts[i].builds[slot]) == "wall": _seat_out(i, slot)
	_job_next += 1
	hosts[i].jobs[slot] = {"id": _job_next, "kind": "", "slot": slot, "phase": "demolish", "left": DEMOLISH_TIME, "total": DEMOLISH_TIME,
		"bill": {}, "escrow": {}, "inbound": {}, "paused": false}
	if str(hosts[i].builds[slot]) == "bot": _sync_teams(i)   # its workers retire now
	if fac == PLAYER: _refresh_panel()


func _tick_jobs(dt: float) -> void:
	for i in hosts.size():
		var fac := int(hosts[i].owner)
		if fac == NEUTRAL: continue
		var jobs: Dictionary = hosts[i].jobs
		for slot_key in jobs.keys():
			var job: Dictionary = jobs[slot_key]
			if bool(job.get("paused", false)): continue
			if str(job.kind) != "": _fill_escrow(i, job)
			if str(job.phase) == "build" and not _job_funded(job): continue   # building work waits for its materials
			job.left = maxf(0.0, float(job.left) - dt)
			if float(job.left) > 0.00001: continue
			var slot := int(job.slot)
			if str(job.phase) == "demolish":
				hosts[i].builds[slot] = ""
				_trim_sockets(i)
				if str(job.kind) != "":
					job.phase = "build"; job.left = BUILD_TIME; job.total = BUILD_TIME
					continue
			else:
				hosts[i].builds[slot] = str(job.kind)
				if str(job.kind) == "wall": hosts[i].fw_on = true
				job.escrow = {}   # the materials are now the building
			jobs.erase(slot_key)
			if str(hosts[i].builds[slot]) == "wall": _seat_in(i, slot)
			if str(hosts[i].builds[slot]) == "bot": _sync_teams(i)   # its two workers start at once
			if fac == PLAYER: _flash("%s · slot %d ready" % [str(hosts[i].name), slot + 1], 0)


func _job_state(job: Dictionary) -> String:   # paused · demolishing · waiting for materials · building
	if bool(job.get("paused", false)): return "paused"
	if str(job.phase) == "demolish": return "demolishing"
	return "building" if _job_funded(job) else "waiting"


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
	mq[fac] = []
	# accounting: incoming reservations, banks and inventory are all cleared; its claims and piles elsewhere go too
	incoming[fac] = {}; cards[fac] = {}
	for h in hosts:
		for field in ["claim", "loot"]: (h.get(field, {}) as Dictionary).erase(fac)
	for res in RES: bank[fac][res] = 0.0
	for i in hosts.size():
		if int(hosts[i].owner) != fac: continue
		hosts[i].owner = NEUTRAL; hosts[i].gen = int(hosts[i].get("gen", 0)) + 1
		hosts[i].builds = _slot_array([], int(hosts[i].slots)); hosts[i].jobs = {}; hosts[i].store = {}; hosts[i].sockets = []
		hosts[i].producer_paused = {}; hosts[i].rig = false
		hosts[i].teams = {}; hosts[i].claim = {}; hosts[i].inbound = {}
		_clear_effects(i)
	flights = flights.filter(func(f): return int(f.owner) != fac)
	for wid in workers.keys():
		if int(workers[wid].fac) == fac: workers.erase(wid)   # its workers go with it
	_reqs.erase(fac); _pool_turn.erase(fac); _served.erase(fac); _serve_n.erase(fac); _served_res.erase(fac)
	_execs = _execs.filter(func(e): return int(e.fac) != fac)
	if fac != PLAYER: _flash("%s eliminated · its remaining hosts are neutral" % fname(fac), 0)


func _clear_effects(i: int) -> void:
	for k in ["ddos_until", "filter_until", "sabot_until", "steal_until", "patch_armed_until", "patch_recover_until", "cover_until", "express_until"]:
		hosts[i][k] = 0.0
	hosts[i].steal_by = -1; hosts[i].siphon = {}; hosts[i].card_result = ""


func _bank_crypto(fac: int) -> float: return _avail(fac, "cash")   # the result screen's "Crypto you" line


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


func _objective() -> Dictionary:   # the win, in one place: the HUD, standings, Help, AI and the result all read this
	var need := _hold_need(hosts.size())
	var counts := {}; var leader := -1; var lead_n := -1; var holder := -1
	for fac in botnets:
		var n := _faction_nodes(fac)
		counts[fac] = n
		if n > lead_n: lead_n = n; leader = fac   # botnets are in faction order, so a tie goes to the lower number
		if not _eliminated.has(fac) and n >= need and float(_hold.get(fac, 0.0)) > 0.0: holder = fac
	return {"need": need, "total": hosts.size(), "secs": HOLD_SECS, "counts": counts, "leader": leader, "leader_n": lead_n,
		"holder": holder, "hold_left": maxf(0.0, HOLD_SECS - float(_hold.get(holder, 0.0))) if holder >= 0 else HOLD_SECS}


func _objective_lines() -> Array:   # [first line, second line, colour of the second] for the HUD
	var o := _objective()
	var mine := int((o.counts as Dictionary).get(PLAYER, 0))
	var first := "MAJORITY %d / %d · you %d" % [int(o.need), int(o.total), mine]
	var holder := int(o.holder)
	var left := int(ceil(float(o.hold_left) - 0.001))
	if holder == PLAYER: return [first, "You hold it: win in %d s" % left, C_GOOD]
	if holder >= 0: return [first, "%s holds it: wins in %d s" % [fname(holder), left], C_BAD]
	var leader := int(o.leader)
	if leader == PLAYER: return [first, "You lead; %d more to hold" % maxi(0, int(o.need) - mine), C_DIM]
	return [first, "Leader: %s with %d" % [fname(leader), int(o.leader_n)], C_DIM]


func _tick_domination(dt: float) -> void:
	var need := _hold_need(hosts.size())   # the same threshold _objective() reports
	var alive := []
	for fac in botnets:
		if _faction_nodes(fac) > 0: alive.append(fac)
		if _faction_nodes(fac) >= need: _hold[fac] = float(_hold[fac]) + dt
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
	if _camp and not menu_open: _camp_tick()   # every frame, paused or not: a done step hands over at once
	if _camp and _camp_result != "" and _camp_clock - _camp_result_at > CAMP_RESULT_SECS: _camp_result = ""; _show_tut()   # the result line fades; nothing waited on it
	if _camp and _camp_chapter == CAMP_OPEN and not _camp_banner_gone and not menu_open:
		if _camp_open_t < 0.0: _camp_open_t = _t
		if _t - _camp_open_t >= CAMP_OPEN_BANNER_SECS:   # 10 s of free play (a menu or a pause does not count): the banner gets out of the way
			_camp_banner_gone = true; tut_panel.visible = false; _layout_ui(); _redraw_map()
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
	if _camp and not menu_open: _camp_tick()   # ... and again after this frame's steps, so nothing waits a frame
	if (won or lost) and not _end_shown:
		_end_shown = true; _refresh_panel()
	_hover_host = _host_at(get_local_mouse_position())
	_hover_flight = _flight_at(get_local_mouse_position())
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
	return [_pan, _zoom, _hover_host, _aim_target(), sel.keys(), _inspect, _dragging, _drag_from, _boxing, _aimed_card(),
		get_viewport_rect().size, _deck_open, _card_bank, menu_open, paused, won, lost, _tut, _tut_stage, _camp_banner_gone]


func _over_fast() -> bool:   # the over layer animates: a wire, card or box being dragged, a card packet flying, a landing pulse
	if _dragging or _boxing or _aimed_card() != "": return true
	if _camp and not menu_open and (_camp_target() >= 0 or _camp_from() >= 0): return true   # the campaign's pulsing cues (they beat through the reading pause)
	if paused: return false
	if not _fx.is_empty(): return true
	if _hover_flight >= 0 or not _held_rects.is_empty(): return true
	for fl in flights:
		if str(fl.kind) == "op": return true
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
	_advance_flights()                            # 0) packets move on hop by hop; a taken or downed host stops them
	if not won and not lost: _deliver_due()      # 1) settle due arrivals (may capture / eliminate)
	_tick_jobs(dt)                                #    construction completions
	_tick_research(dt)                            #    blueprint research
	_tick_manufacture(dt)                         # 3) the manufacturing queue: its head is made, one copy at a time
	if not won and not lost: _tick_execs()        # 4) capture / raid / worm resolutions, after accepted defenses
	_tick_production(dt)                          # 5) income, local credit, buffers
	_tick_teams(dt)                               # 6) station teams follow the stations; lost workers are replaced in time
	_tick_logistics()                             #    free workers take the most useful feasible job (siphons act as they leave hosts)
	if _t >= _blocked_next: _blocked_next = _t + 0.5; _tick_blocked()   #    held packets look for a way on
	_tick_effects(dt)                             #    phishing diversion expiry reverts undispatched output
	_route_memo = null
	if not won and not lost and not _ai_paused: _ai_tick(dt)
	_check_rigs()
	if not won and not lost: _tick_domination(dt)
	_tick_events()
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


func _revert_phish(i: int) -> void:   # the thief's unsent storage on this host goes back to the host owner
	var owner := int(hosts[i].owner)
	var claims: Dictionary = hosts[i].get("claim", {})   # couriers on their way for it find nothing and release their room themselves
	for fac in claims.keys():
		if int(fac) != owner: claims.erase(fac)
	var store: Dictionary = hosts[i].store
	for fac in store.keys():
		if int(fac) == owner: continue
		for res in (store[fac] as Dictionary):
			if _st_local(i, owner): _add_bank(owner, str(res), float(store[fac][res]), "returned")   # their own main node: straight into the bank
			else:
				if not store.has(owner): store[owner] = {}
				store[owner][res] = float((store[owner] as Dictionary).get(res, 0.0)) + float(store[fac][res])
		store.erase(fac)


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
		if _deliver(f): flights.append(f)   # a courier going back keeps travelling


func _deliver(f: Dictionary) -> bool:   # a packet reached the end of its route (every host on the way was checked as it left)
	var fac := int(f.owner)
	if _eliminated.has(fac): return false
	match str(f.kind):
		"op":
			if bool(f.get("returning", false)): _card_back(f); return false
			var recipe := _card_of(str(f.get("card", "")))
			if CARDS.has(recipe) and _is_defense(recipe): _support_arrive(f); return false
			_op_land(fac, recipe, int(f.get("target", -1)), int(f.get("gen", -1)), f)
			return false
		"courier": return _courier_arrive(f)
	return false


func _support_arrive(f: Dictionary) -> void:   # a defence card reached your host: it loads into its held socket or acts now
	var fac := int(f.owner); var t := int(f.target)
	var recipe := _card_of(str(f.card))
	if bool(f.get("load", false)):
		var k := (hosts[t].sockets as Array).find(str(f.get("sock", "")))
		if k >= 0 and not _trigger_now(recipe, t):   # its own position, still there: it loads into it
			hosts[t].sockets[k] = recipe
			hosts[t].hit_t = _t
			_fx.append({"host": t, "until": _t + 2.0, "col": fcol(fac)})
			if fac == PLAYER: _flash("%s loaded into the Firewall on %s: it fires when %s" % [str(CARDS[recipe].name), str(hosts[t].name), str(SOCKET_TRIGGER[recipe])], 0)
			return
		if k >= 0: hosts[t].sockets[k] = ""
		_apply_support(fac, recipe, t, false)   # its Firewall went, or its attack is already here: it acts
		return
	_apply_support(fac, recipe, t)


# ---- ownership change ----
func _capture(t: int, fac: int) -> void:
	var prev := int(hosts[t].owner)
	var nm := str(hosts[t].name)
	var dead := _kill_home_workers(t, fac) if prev != NEUTRAL else 0   # its stations' workers die wherever they are, first
	_logi_poke()
	if prev != NEUTRAL:
		for slot in (hosts[t].jobs as Dictionary):   # the former owner's site materials are destroyed with it
			for res in (hosts[t].jobs[slot].get("escrow", {}) as Dictionary): _ledger_add(prev, "lost", "site", str(res), float(hosts[t].jobs[slot].escrow[res]))
	hosts[t].owner = fac; hosts[t].gen = int(hosts[t].get("gen", 0)) + 1
	hosts[t].builds = _slot_array([], int(hosts[t].slots))   # cleared: no salvage, the new owner develops empty slots
	hosts[t].jobs = {}; hosts[t].store = {}; hosts[t].producer_paused = {}; hosts[t].sockets = []
	hosts[t].teams = {}; hosts[t].claim = {}; hosts[t].inbound = {}   # its orders go with it
	if _served.has(prev): (_served[prev] as Dictionary).erase(t)   # a host retaken later starts afresh in the round robin
	if _served_res.has(prev): (_served_res[prev] as Dictionary).erase(t)
	hosts[t].plan_frac = {}; hosts[t].plan_rr = 0; hosts[t].plan_limited = false
	if prev == PLAYER:
		var what := "%s lost to %s — %d station worker%s destroyed." % [nm, fname(fac), dead, "" if dead == 1 else "s"] if dead > 0 else "%s lost to %s." % [nm, fname(fac)]
		_event("lostworkers:%d:%d" % [t, int(hosts[t].gen)], EV_CRIT if dead > 0 else EV_ACT, what, t)
	if _route_memo != null: _route_memo = {}   # routes through it change at once
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


func _ready_total(fac: int) -> int:   # the READY_SLOTS budget: ready copies, the copy being made, and cards in flight that may come back
	var n := 0
	for r in (cards.get(fac, {}) as Dictionary).values(): n += int(r)
	var q: Array = mq.get(fac, [])
	if not q.is_empty() and not (q[0].paid as Dictionary).is_empty(): n += 1
	for f in flights:
		if str(f.kind) == "op" and int(f.owner) == fac: n += 1   # held for it: a card that cannot arrive returns to the hand
	return n


func _can_play(fac: int, key: String, t: int) -> String:   # "" if playable, else why not
	if won or lost: return "match finished"
	var recipe := _card_of(key)
	if not CARDS.has(recipe): return "unknown card"
	if _held(fac, recipe) <= 0: return "none ready"
	if t < 0 or t >= hosts.size(): return "no host selected"
	if not rig.has(fac) or _eliminated.has(fac) or int(hosts[int(rig[fac])].owner) != fac: return "your main node is not under your control"
	var defense := _is_defense(recipe)
	if defense:   # it travels from your main node, through your hosts, like every card
		if int(hosts[t].owner) != fac: return "a support card needs one of your hosts"
		if t == _hub(fac): return ""
		if _routing_down(_hub(fac)): return "your main node's routing is cut"
		if _travel_route(fac, _hub(fac), t).size() < 2: return "no route from your main node to that host"
		return ""
	if int(hosts[t].owner) == fac: return "an attack needs a foreign host"
	var eff := str(CARDS[recipe].effect)
	if eff == "vault" and int(hosts[t].owner) == NEUTRAL: return "Vault raid needs a rival's host"
	if _routing_down(int(rig[fac])) and t != int(rig[fac]): return "your main node's routing is cut"
	if not _op_reachable(fac, t): return "no route from your main node — capture a path toward it first"
	# one capture-or-raid intrusion per attacker/target at a time
	if eff in ["capture", "worm", "vault"] and _intrusion_busy(fac, t): return "you already have an intrusion on this host"
	return ""


# ---- target preview (Milestone A, brief §12.2): what launching this card here would do, from what you can know ----
# It only reads: legality, security, route and travel, the execution and what stops it, the hosts an area or chain
# effect would hit as far as you can see, and defences that are public or in a dated Recon snapshot.
func _target_preview(fac: int, key: String, t: int, siphon_res := "", by_drag := false) -> Dictionary:   # {ok, why, lines [[text, colour]]}
	var recipe := _card_of(key)
	var lines := []
	if not CARDS.has(recipe) or not _host_ok(t): return {"ok": false, "why": "no target", "lines": lines}
	var card: Dictionary = CARDS[recipe]
	var why := _can_play(fac, key, t)
	if why == "": lines.append(["Ready: %s on %s." % [str(card.name), str(hosts[t].name)], C_GOOD])
	else: lines.append(["Cannot launch: %s." % why, C_BAD])
	if _is_defense(recipe):
		lines.append_array(_support_preview(recipe, t))
		return {"ok": why == "", "why": why, "lines": lines}
	var eff := str(card.effect)
	var rt := _attack_route(fac, t)
	var arrive := 0.0
	if rt.is_empty(): lines.append(["Route: none from your main node.", C_BAD])
	else:
		var eta := _route_eta(rt)
		arrive = float(eta.travel) + float(eta.wait)
		var s := "Route: %d hop%s from your main node, arrives in ~%.1f s" % [int(eta.hops), "" if int(eta.hops) == 1 else "s", arrive]
		if float(eta.wait) >= 0.1: s += " (%.1f s of it queueing)" % float(eta.wait)
		lines.append([s + ".", C_DIM])
	var owner_name := fname(int(hosts[t].owner)) if int(hosts[t].owner) != NEUTRAL else "neutral"
	var ex := _exec_time(recipe, t) if eff in ["capture", "worm", "vault"] else 0.0
	lines.append(_chance_line(fac, t, recipe, arrive + ex))
	match eff:
		"capture": lines.append(["Then executes for %d s. If its draw succeeds it captures the host; a Patch, a lost route or a change of owner stops it first." % int(ex), C_TEXT])
		"worm":
			lines.append(["Then executes for %d s. After a capture it moves on to the nearest linked %s host you can see (%d hosts in all); a Patch or a lost route ends the chain." % [int(ex), owner_name, int(card.reach)], C_TEXT])
			var nxt := _worm_next(fac, t, int(hosts[t].owner), [t])
			lines.append(["Next if it captures: %s." % (str(hosts[nxt].name) if nxt >= 0 else "no eligible host in sight"), C_DIM])
		"vault":
			lines.append(["Then executes for %d s. If its draw succeeds it empties up to %d units from this host and its owner's linked hosts; your workers carry them home." % [int(ex), int(card.cargo)], C_TEXT])
			lines.append(["Would raid, as far as you can see: %s." % _names(_preview_chain(fac, t, int(card.reach))), C_DIM])
			lines.append(["Your workers to collect it: %d." % int(_worker_counts(fac).total), C_DIM])
		"phish":
			lines.append(["On arrival, what this host makes goes to you for %d s. Incident response ends it." % int(card.dur), C_TEXT])
			lines.append([_recon_production(fac, t), C_DIM])
		"ddos":
			lines.append(["On arrival, production and routing stop for %d s on this host and the %d %s hosts nearest to it." % [int(card.dur), int(card.reach) - 1, owner_name], C_TEXT])
			lines.append(["Would hit, as far as you can see: %s." % _names(_preview_nearest(fac, t, int(card.reach))), C_DIM])
		"sabotage":
			lines.append(["On arrival, producers stop for %d s on this host and up to %d linked %s hosts, nearest first." % [int(card.dur), int(card.reach) - 1, owner_name], C_TEXT])
			lines.append(["Would hit, as far as you can see: %s." % _names(_preview_chain(fac, t, int(card.reach))), C_DIM])
		"siphon":
			var res := siphon_res if RES.has(siphon_res) and siphon_res != "bots" else "cash"
			lines.append(["On arrival, for %d s, %s carried by workers leaving or passing this host is dropped there for yours (up to %d)." % [int(card.dur), RES_NAME[res], int(card.cargo)], C_TEXT])
			if by_drag: lines.append(["A drag takes Crypto; choose another resource in the host's panel.", C_DIM])
		"recon": lines.append(["If it gets through, it shows the host's installations, storage and Firewall cards; the snapshot is fresh for %d s." % int(card.dur), C_TEXT])
	lines.append_array(_known_defences(fac, t, eff, arrive + ex))
	lines.append(["The card is used only when you launch it.", C_DIM])
	return {"ok": why == "", "why": why, "lines": lines}


func _chance_line(fac: int, t: int, recipe: String, resolve_in: float) -> Array:   # [text, colour]: the odds when it resolves
	var at := _t + resolve_in
	var rec: Dictionary = (recon.get(fac, {}) as Dictionary).get(t, {})
	var hi := _pct(SCOUTED_CHANCE); var lo := _pct(UNSCOUTED_CHANCE)
	if str(CARDS[recipe].effect) == "recon":
		return ["Chance: %d%%. A Recon gets through half the time; a miss shows nothing." % _pct(RECON_CHANCE), C_WARN]
	if _recon_fresh(fac, t, at):
		return ["Chance: %d%%, the best there is. Your Recon is %d s old and still fresh when it resolves (~%d s)." % [hi, _ago(float(rec.get("at", _t))), int(ceil(resolve_in))], C_GOOD]
	if _recon_fresh(fac, t):
		return ["Chance: %d%%. Your Recon goes stale before it resolves (~%d s); scout again for %d%%." % [lo, int(ceil(resolve_in)), hi], C_WARN]
	return ["Chance: %d%% without fresh Recon. Recon this host first for %d%%." % [lo, hi], C_WARN]


func _support_preview(recipe: String, t: int) -> Array:   # a defence card on your own host: its trip, then loaded into a socket or used
	var out := []
	var hub := _hub(PLAYER)
	var rt := _travel_route(PLAYER, hub, t) if hub >= 0 else []
	var when := "on arrival" if t != hub else "at once"
	if t != hub: out.append(["Travels from your main node: %d s." % int(ceil(_travel_time(rt))) if rt.size() >= 2 else "No route from your main node: it cannot get there.", C_DIM if rt.size() >= 2 else C_BAD])
	if _socketable(recipe) and _socket_free(t) and not _trigger_now(recipe, t):
		out.append(["Loads into the Firewall here %s; it fires when %s." % [when, str(SOCKET_TRIGGER[recipe])], C_TEXT])
	else: out.append(["Takes effect %s: %s" % [when, str(CARDS[recipe].get("lead", CARDS[recipe].rules))], C_TEXT])
	out.append(["The card is used only when you play it.", C_DIM])
	return out


func _preview_nearest(fac: int, t: int, n: int) -> Array:   # DDoS: t and the n-1 hosts of its owner nearest to it, among those fac can see
	var out := [t]
	var owner := int(hosts[t].owner)
	if owner == NEUTRAL or n <= 1: return out
	var others := []
	for i in hosts.size():
		if i != t and int(hosts[i].owner) == owner and _visible_to(fac, i): others.append([(hosts[t].pos as Vector2).distance_to(hosts[i].pos), i])
	others.sort_custom(func(a, b): return float(a[0]) < float(b[0]) if float(a[0]) != float(b[0]) else int(a[1]) < int(b[1]))
	for k in mini(n - 1, others.size()): out.append(int(others[k][1]))
	return out


func _preview_chain(fac: int, t: int, reach: int) -> Array:   # Sabotage / Vault: the chain of linked same-owner hosts, through hosts fac can see
	var owner := int(hosts[t].owner)
	var hit := [t]; var seen := {t: true}; var current := t
	while hit.size() < reach:
		var best := -1; var bd := INF
		for nb in hosts[current].links:
			var n := int(nb)
			if seen.has(n) or int(hosts[n].owner) != owner or not _visible_to(fac, n): continue
			var d := (hosts[current].pos as Vector2).distance_to(hosts[n].pos)
			if d < bd or (d == bd and n < best): bd = d; best = n
		if best < 0: break
		hit.append(best); seen[best] = true; current = best
	return hit


func _recon_production(fac: int, t: int) -> String:   # Phishing: what a dated Recon showed this host making, never live contents
	var rec: Dictionary = (recon.get(fac, {}) as Dictionary).get(t, {})
	if rec.is_empty(): return "Its production is unknown without Recon."
	var kinds := []
	for b in (rec.get("builds", []) as Array):
		if str(b) in PRODUCER_KINDS: kinds.append(str(BUILD_KINDS[str(b)].name))
	var age := _ago(float(rec.get("at", _t)))
	if kinds.is_empty(): return "Recon %d s ago: no producers." % age
	return "Recon %d s ago: %s." % [age, ", ".join(kinds)]


func _ago(at: float) -> int: return int(floor(_t - at + 0.001))   # whole seconds since `at`, steady against step rounding


const COUNTER_OF := {"capture": "patch", "worm": "patch", "vault": "patch", "phish": "response", "sabotage": "response", "siphon": "response", "ddos": "filter"}


func _known_defences(fac: int, t: int, eff: String, resolve_in: float) -> Array:   # public effects and the last Recon, dated
	var out := []
	var armed := float(hosts[t].get("patch_armed_until", 0.0)) - _t
	if eff in ["capture", "worm", "vault"] and armed > 0.0:   # an armed Patch is shown on the map
		out.append(["Patch armed here for %d s: an intrusion ending while it is armed is stopped (yours would end in ~%d s)." % [int(ceil(armed)), int(ceil(resolve_in))], C_WARN])
	if eff == "ddos" and float(hosts[t].get("filter_until", 0.0)) > _t:
		out.append(["Filter active here for %d s: the flood is absorbed on this host." % int(ceil(float(hosts[t].filter_until) - _t)), C_WARN])
	if eff == "recon": return out
	var rec: Dictionary = (recon.get(fac, {}) as Dictionary).get(t, {})
	if rec.is_empty():
		out.append(["Defences unknown: no Recon on this host.", C_DIM])
		return out
	var age := _ago(float(rec.get("at", _t)))
	var stale := "" if _recon_fresh(fac, t) else " (out of date)"
	if not (rec.get("builds", []) as Array).has("wall"):
		out.append(["Recon %d s ago%s: no Firewall." % [age, stale], C_DIM])
		return out
	var socks := []
	for r in _loaded_of(rec.get("sockets", [])): socks.append(str(CARDS[str(r)].name))
	var counter := str(COUNTER_OF.get(eff, ""))
	var hit := counter != "" and (rec.get("sockets", []) as Array).has(counter)
	out.append(["Recon %d s ago%s: Firewall holding %s%s" % [age, stale, ", ".join(socks) if not socks.is_empty() else "nothing",
		(" — its %s would fire against this card." % str(CARDS[counter].name)) if hit else "."], C_WARN if hit else C_DIM])
	return out


func _wrap_text(f: Font, s: String, fs: int, width: float) -> Array:   # words into lines no wider than width
	var out := []; var cur := ""
	for word in s.split(" "):
		var next := word if cur == "" else cur + " " + word
		if cur != "" and _text_w(f, next, fs) > width: out.append(cur); cur = word
		else: cur = next
	if cur != "": out.append(cur)
	return out


const PREVIEW_W := 360.0
func _paint_drag_preview(f: Font) -> void:   # screen space: the preview beside the cursor while a card is held (or selected) over a host
	var dk := _aimed_card()
	if dk == "": return
	var mouse := get_local_mouse_position()
	var t := _host_at(mouse)
	if t < 0: return
	var pv := _target_preview(PLAYER, dk, t, "", true)
	var rows := []   # [text, colour]
	for l in pv.lines:
		for w in _wrap_text(f, str(l[0]), 13, PREVIEW_W - 20.0): rows.append([w, l[1]])
	var h := 12.0 + 18.0 * rows.size()
	var area := _map_rect().grow(-6.0)
	var pos := mouse + Vector2(24.0, 16.0)
	if pos.x + PREVIEW_W > area.end.x: pos.x = mouse.x - 24.0 - PREVIEW_W
	pos = pos.clamp(area.position, area.end - Vector2(PREVIEW_W, h))
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var box := Rect2(pos, Vector2(PREVIEW_W, h))
	_cv.draw_rect(box, Color(0.03, 0.05, 0.08, 0.94), true)
	_cv.draw_rect(box, C_GOOD if bool(pv.ok) else C_BAD, false, 1.5)
	for k in rows.size(): _text(_cv, f, pos + Vector2(10.0, 20.0 + 18.0 * k), str(rows[k][0]), 13, rows[k][1])
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))


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
		var hub := _hub(fac)
		if t == hub: _apply_support(fac, recipe, t)   # at the main node it acts at once
		else:   # it travels there; a socket it will load is held for it on the way
			var load := _socketable(recipe) and _socket_free(t) and not _trigger_now(recipe, t)
			var df := _schedule(_travel_route(fac, hub, t), _t, fac, "op", false, {"card": recipe, "target": t, "gen": int(hosts[t].gen), "load": load})
			if load: df.sock = "@%s#%d" % [recipe, int(df.id)]; _put_socket(t, str(df.sock))
			flights.append(df)
			if fac == PLAYER: _flash("%s is on its way to %s — %s in %d s" % [str(CARDS[recipe].name), str(hosts[t].name), "loads its Firewall" if load else "acts", int(ceil(float(df.arrive_t) - _t))])
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
	if int(hosts[t].gen) != gen and gen >= 0:   # the host changed hands in transit: the card is void
		if str(CARDS[recipe].effect) in ["capture", "worm", "vault"]: _op_outcome({"id": int(f.get("id", 0)), "fac": fac, "card": recipe, "target": t}, "owner_changed")
		elif fac == PLAYER: _flash("Your %s on %s did nothing: the host changed owner while it flew" % [str(CARDS[recipe].name), str(hosts[t].name)], 1)
		return
	var eff := str(CARDS[recipe].effect)
	if eff != "recon":   # a scan is quiet: no red frame, no pulse on the target
		hosts[t].hit_t = _t
		_fx.append({"host": t, "until": _t + 2.0, "col": fcol(fac)})
	var what := str(CARDS[recipe].name)
	var op := {"id": int(f.get("id", 0)), "fac": fac, "card": recipe, "target": t}
	# an effect that lands on arrival: invalid first (above), then a counter on the target, then the Recon odds, then the effect
	match eff:
		"recon":   # half the time: a miss shows nothing, and only the side that sent it hears of it
			if _op_roll(fac, t, recipe): _mark_scanned(fac, t); _recon_outcome(op, "scouted")
			else: _recon_outcome(op, "missed")
		"phish", "siphon":
			if _fire_socket(t, "response", what): _apply_response(t); _op_outcome(op, "countered", "the Firewall's Response")
			elif not _op_roll(fac, t, recipe): _op_outcome(op, "missed")
			elif eff == "phish": hosts[t].steal_by = fac; hosts[t].steal_until = _t + float(CARDS[recipe].dur)
			else: hosts[t].siphon = {"by": fac, "res": str(f.get("res", "cash")), "since": _t, "until": _t + float(CARDS[recipe].dur), "left": int(CARDS[recipe].cargo)}
		"ddos":   # one operation, one draw (Recon of the target); each host it reaches then has its own Filter
			if not _op_roll(fac, t, recipe): _op_outcome(op, "missed")
			else:
				for h in _nearest_of_owner(t, int(CARDS[recipe].get("reach", 1))):
					if float(hosts[h].get("filter_until", 0.0)) > _t: continue   # a Filter here: the flood is absorbed
					if _fire_socket(h, "filter", what): _apply_filter(h)
					else: hosts[h].ddos_until = _t + float(CARDS[recipe].dur)
				if _route_memo != null: _route_memo = {}   # downed hosts forward nothing from now on
		"sabotage":   # likewise one draw; each host's Response socket answers for itself
			if not _op_roll(fac, t, recipe): _op_outcome(op, "missed")
			else:
				for h in _chain_hosts(t, int(CARDS[recipe].reach), int(hosts[t].owner)):
					hosts[int(h)].sabot_until = _t + float(CARDS[recipe].dur)
					if _fire_socket(int(h), "response", what): _apply_response(int(h))
		"capture", "worm", "vault":   # the odds are drawn when the execution ends (_tick_execs), after any Patch and the route
			_start_exec({"id": int(f.id), "fac": fac, "card": recipe, "effect": eff, "target": t, "gen": int(hosts[t].gen), "ends": _t + _exec_time(recipe, t), "stage": 1, "victim": int(hosts[t].owner), "seen": [t]})
	if fac == PLAYER or _mine(t): _refresh_panel()


func _exec_time(recipe: String, t: int) -> float:   # a capture, raid or Worm stage executes this long; longer on a held main node
	var card: Dictionary = CARDS[recipe]
	var ex := float(card.get("exec", 8.0))
	if bool(hosts[t].get("rig", false)) and int(hosts[t].owner) != NEUTRAL: ex = float(card.get("exec_rig", ex))
	return ex


func _nearest_of_owner(t: int, n: int) -> Array:   # t and the n-1 hosts of t's owner closest to it on the map
	var out := [t]
	var owner := int(hosts[t].owner)
	if owner == NEUTRAL or n <= 1: return out
	var others := []
	for i in hosts.size():
		if i != t and int(hosts[i].owner) == owner: others.append([(hosts[t].pos as Vector2).distance_to(hosts[i].pos), i])
	others.sort_custom(func(a, b): return float(a[0]) < float(b[0]) if float(a[0]) != float(b[0]) else int(a[1]) < int(b[1]))
	for k in mini(n - 1, others.size()): out.append(int(others[k][1]))
	return out


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
	# Intrusions whose countdown has ended resolve earliest end first; equal end times in launch order (operation id).
	# Commands for a turn (a manual Patch included) are applied before the turn's steps, so they always come first.
	var still := []
	_execs.sort_custom(func(a, b): return float(a.ends) < float(b.ends) if absf(float(a.ends) - float(b.ends)) > 0.0001 else int(a.id) < int(b.id))
	for e in _execs:
		var t := int(e.target); var fac := int(e.fac)
		if _eliminated.has(fac): continue   # the attacker is gone: nothing to report to anyone
		if int(hosts[t].gen) != int(e.gen):   # someone else took (or lost) the host first: a stale generation never captures
			_op_outcome(e, "owner_changed")
			continue
		if float(e.ends) > _t: still.append(e); continue
		# an armed Patch on the target consumes this intrusion instead of letting it resolve
		if float(hosts[t].get("patch_armed_until", 0.0)) > _t:
			hosts[t].patch_armed_until = 0.0; hosts[t].patch_recover_until = _t + float(CARDS.patch.dur)
			_op_outcome(e, "countered", "armed Patch")
			continue
		var eff := str(e.effect)
		if not _op_reachable(fac, t):   # the attacker no longer holds a path to it: this capture, raid or Worm stage ends
			_op_outcome(e, "route_failed")
		elif not _op_roll(fac, t, str(e.card)):   # only now, after counters and the route: 50% with fresh Recon, 25% without
			_op_outcome(e, "missed")
		elif eff == "vault":
			_op_outcome(e, "raided")
			_resolve_vault(fac, t)
		else:
			_op_outcome(e, "captured")
			_capture(t, fac)
			if eff == "worm" and int(e.stage) < int(CARDS.worm.reach):   # a Worm moves on only from a host it took
				var seen: Array = (e.get("seen", [t]) as Array).duplicate()
				var nxt := _worm_next(fac, t, int(e.get("victim", NEUTRAL)), seen)
				if nxt >= 0:
					seen.append(nxt)
					_start_exec({"id": int(e.id), "fac": fac, "card": "worm", "effect": "worm", "target": nxt, "gen": int(hosts[nxt].gen), "ends": _t + _exec_time("worm", nxt), "stage": int(e.stage) + 1, "victim": int(e.get("victim", NEUTRAL)), "seen": seen}, still)
	_execs = still


var intrusions_resolved := 0   # intrusions decided so far, whatever the outcome (the lockstep test checks both screens agree)
var op_outcomes := []          # the last OP_OUTCOME_KEEP outcomes (intrusions and Recons): {t, fac, card, target, victim, outcome, via, stage, scouted}
const OP_OUTCOME_KEEP := 256
const OUTCOME_TEXT := {"captured": "captured", "countered": "stopped by a Patch", "route_failed": "failed: no route to the host any more",
	"owner_changed": "stopped: the host changed owner first", "missed": "failed", "raided": "raided"}


func _op_outcome(e: Dictionary, outcome: String, via := "") -> void:   # one intrusion ended: record it and tell both sides
	var t := int(e.target); var fac := int(e.fac)
	var victim := int(hosts[t].owner)
	intrusions_resolved += 1
	op_outcomes.append({"t": _t, "fac": fac, "card": str(e.card), "target": t, "victim": victim, "outcome": outcome, "via": via, "stage": int(e.get("stage", 1)),
		"scouted": _recon_fresh(fac, t)})   # (before any capture voids the Recon)
	if op_outcomes.size() > OP_OUTCOME_KEEP: op_outcomes.pop_front()
	_event_outcome(e, outcome, via, victim)
	if outcome in ["captured", "raided"]: return   # _capture / _resolve_vault say it
	var card := str(CARDS[str(e.card)].name)
	var how: String = OUTCOME_TEXT[outcome]
	if outcome == "countered" and via != "": how = "stopped by %s" % via
	hosts[t].card_result = "%s %s" % [card, how]
	if outcome == "missed" and fac == PLAYER: how = "failed: %s" % _miss_why(fac, t, str(e.card))   # the victim is not told it was scouted
	if fac == PLAYER: _flash("Your %s on %s %s" % [card, str(hosts[t].name), how], 1)
	elif victim == PLAYER: _flash("%s's %s on %s %s" % [fname(fac), card, str(hosts[t].name), how], 0)


func _recon_outcome(e: Dictionary, outcome: String) -> void:   # "scouted" or "missed": a Recon is quiet, so only its sender hears
	var t := int(e.target); var fac := int(e.fac)
	op_outcomes.append({"t": _t, "fac": fac, "card": "recon", "target": t, "victim": int(hosts[t].owner), "outcome": outcome, "via": "", "stage": 1, "scouted": false})
	if op_outcomes.size() > OP_OUTCOME_KEEP: op_outcomes.pop_front()
	if fac != PLAYER or outcome != "missed": return
	var nm := str(hosts[t].name)
	_event("op:%d:1" % int(e.get("id", 0)), EV_ACT, "Your Recon on %s failed: %s. Send another." % [nm, _miss_why(fac, t, "recon")], t)
	_flash("Your Recon on %s failed (%d%% chance): it shows nothing. Send another." % [nm, _pct(RECON_CHANCE)], 1)


# ---- event history (Milestone A, brief §17.4): one persistent, deduplicated queue of what happened to you ----
# Presentation only: each screen keeps its own player's history and nothing in it feeds back into the rules (not
# hashed). A lasting condition (an intrusion, an effect, a cut route, a rival holding the majority) is ONE entry that
# updates while live and then ends; one-off news repeated within EV_MERGE_SECS counts up on one entry.
const EV_CRIT := 0
const EV_ACT := 1
const EV_INFO := 2
const EV_KEEP := 80
const EV_MERGE_SECS := 10.0
const EV_POLL := 0.5
const EV_MARK := ["!", "›", "·"]
var events := []          # newest first: {key, pri, text, done, host, t0, t, n, live}
var _ev_next_poll := 0.0
var _ev_dirty := false


func _event(key: String, pri: int, text: String, host := -1, live := false, done := "") -> void:
	for k in events.size():
		var e: Dictionary = events[k]
		if str(e.key) != key: continue
		if bool(e.live) or _t - float(e.t) < EV_MERGE_SECS:
			if not bool(e.live) and not live: e.n = int(e.n) + 1; e.news_t = _t   # the same news again: count it, bring it to the top
			elif not bool(e.live) and live: e.news_t = _t   # it is happening again
			if not bool(e.live) or not live: events.remove_at(k); events.push_front(e)
			e.text = text; e.t = _t; e.pri = mini(int(e.pri), pri); e.live = live
			if host >= 0: e.host = host
			if done != "": e.done = done
			_ev_dirty = true
			return
		break
	events.push_front({"key": key, "pri": pri, "text": text, "done": done, "host": host, "t0": _t, "t": _t, "news_t": _t, "n": 1, "live": live})
	if events.size() > EV_KEEP: events.pop_back()
	_ev_dirty = true


func _event_end(key: String, text := "", pri := -1) -> void:   # a live condition is over: it stays in the history, no longer active
	for e in events:
		if str(e.key) != key or not bool(e.live): continue
		e.live = false; e.t = _t; e.news_t = _t
		e.text = text if text != "" else (str(e.done) if str(e.done) != "" else str(e.text))
		if pri >= 0: e.pri = pri
		_ev_dirty = true
		return


func _tick_events() -> void:   # every EV_POLL s of play: post, update and end the lasting conditions
	if _t < _ev_next_poll or not rig.has(PLAYER): return
	_ev_next_poll = _t + EV_POLL
	var live := {}
	var home := int(rig.get(PLAYER, -1))
	for e in _execs:   # a rival intrusion running on one of your hosts
		var t := int(e.target)
		if int(e.fac) == PLAYER or int(hosts[t].owner) != PLAYER: continue
		var key := "intr:%d:%d" % [int(e.id), int(e.get("stage", 1))]
		live[key] = true
		_event(key, EV_CRIT if t == home else EV_ACT, "%s's %s on %s: %d s left. A Patch on it stops it." % [fname(int(e.fac)), str(CARDS[str(e.card)].name), str(hosts[t].name), int(ceil(float(e.ends) - _t))], t, true)
	var cut := []
	for i in hosts.size():
		if int(hosts[i].owner) != PLAYER: continue
		var nm := str(hosts[i].name)
		var timed := [["ddos", "DDoS", float(hosts[i].get("ddos_until", 0.0))], ["sabot", "Sabotage", float(hosts[i].get("sabot_until", 0.0)) if _sabotaged(i) else 0.0],
			["phish", "Phishing", float(hosts[i].get("steal_until", 0.0)) if _phished(i) else 0.0], ["siphon", "Packet siphon", float((hosts[i].get("siphon", {}) as Dictionary).get("until", 0.0))]]
		for fx in timed:
			if float(fx[2]) <= _t: continue
			var key := "fx:%s:%d" % [str(fx[0]), i]
			live[key] = true
			_event(key, EV_CRIT if i == home else EV_ACT, "%s on %s: %d s left." % [str(fx[1]), nm, int(ceil(float(fx[2]) - _t))], i, true, "%s on %s ended." % [str(fx[1]), nm])
		if _sockets(i) > 0 and not bool(hosts[i].get("fw_on", true)):
			live["fwoff:%d" % i] = true
			_event("fwoff:%d" % i, EV_ACT, "Firewall OFF on %s: no Intel there to run it." % nm, i, true, "Firewall on %s runs again." % nm)
		if i != home and (_store_total(i) >= 1.0 or _standing(i) > 0) and _attack_route_none(PLAYER, i): cut.append(i)
	if not cut.is_empty():
		live["cutoff"] = true
		var names := _names(cut.slice(0, 3)) + (", …" if cut.size() > 3 else "")
		_event("cutoff", EV_CRIT, "%d host%s cut off from your main node: %s." % [cut.size(), "" if cut.size() == 1 else "s", names], int(cut[0]), true, "Your hosts reach your main node again.")
	var o := _objective()
	if int(o.holder) >= 0 and int(o.holder) != PLAYER:
		live["majority"] = true
		_event("majority", EV_CRIT, "%s holds the majority: wins in %d s." % [fname(int(o.holder)), int(o.hold_left)], int(rig.get(int(o.holder), -1)), true, "%s lost the majority." % fname(int(o.holder)))
	var held := {}   # your packets waiting at a host for a way on
	for f in flights:
		if bool(f.get("blocked", false)) and int(f.owner) == PLAYER: held[int(f.at)] = int(held.get(int(f.at), 0)) + 1
	for i in held:
		var key := "held:%d" % int(i)
		live[key] = true
		_event(key, EV_ACT, "%d of your packets wait at %s: the way on is cut." % [int(held[i]), str(hosts[int(i)].name)], int(i), true, "Your packets move on from %s." % str(hosts[int(i)].name))
	if home >= 0 and int(_worker_counts(PLAYER, -2).total) == 0:   # no workers at all: nothing moves until a station is built
		live["noworkers"] = true
		_event("noworkers", EV_CRIT, "You have no delivery workers: build a Bot station.", home, true, "Your workers are back at work.")
	var stall := _research_stall(PLAYER)
	if stall != "":
		live["research"] = true
		_event("research", EV_ACT, stall, -1, true, "Research is moving again.")
	for e in events:   # what was live and is not any more has ended: history, read as news
		if bool(e.live) and not live.has(str(e.key)): _event_end(str(e.key), "", EV_INFO)
	if _ev_dirty: _refresh_event_strip()


func _research_short(fac: int) -> Array:   # what the bank lacks for a second of research at full speed (names)
	var job: Dictionary = research_job.get(fac, {})
	if job.is_empty() or bool(job.get("paused", false)): return []
	var recipe := str(job.key)
	var frac := 1.0 / maxf(0.001, _research_time(recipe))
	var cost := _research_cost(recipe)
	var short := []
	for r in cost:
		if _avail(fac, r) < float(cost[r]) * frac - 0.000001: short.append(str(RES_NAME[r]))
	return short


func _research_stall(fac: int) -> String:   # "" while research advances (even slowly); else what stops it (mirrors _tick_research)
	var short := _research_short(fac)
	if short.is_empty(): return ""
	var job: Dictionary = research_job.get(fac, {})
	if _t - float(job.get("paid_t", -999.0)) < RESEARCH_STALL_SECS: return ""   # it paid within the last cycle: slow, not stopped
	return "Research of %s stopped: no %s in your bank." % [str(CARDS[str(job.key)].name), " or ".join(short)]


func _research_slow(fac: int) -> String:   # "" at full speed or when stopped; else what it is short of while it still advances
	var short := _research_short(fac)
	if short.is_empty() or _research_stall(fac) != "": return ""
	return ("slowed: %s comes in slower than it uses it" if short.size() == 1 else "slowed: %s come in slower than it uses them") % " and ".join(short)


func _event_outcome(e: Dictionary, outcome: String, via: String, victim: int) -> void:   # from _op_outcome: your operations and attacks on you
	var t := int(e.target); var fac := int(e.fac)
	var card := str(CARDS[str(e.card)].name); var nm := str(hosts[t].name)
	var key := "op:%d:%d" % [int(e.get("id", 0)), int(e.get("stage", 1))]
	if fac == PLAYER:
		match outcome:
			"captured": _event(key, EV_INFO, "Captured %s with %s." % [nm, card], t)
			"countered": _event(key, EV_ACT, "Your %s on %s was stopped by %s." % [card, nm, via if via != "" else "a Patch"], t)
			"route_failed": _event(key, EV_ACT, "Your %s on %s failed: you lost the route to it." % [card, nm], t)
			"missed": _event(key, EV_ACT, "Your %s on %s failed: %s." % [card, nm, _miss_why(fac, t, str(e.card))], t)
			"raided": _event(key, EV_INFO, "Your %s on %s went through." % [card, nm], t)
			_: _event(key, EV_INFO, "Your %s on %s ended: the host changed owner first." % [card, nm], t)
	elif victim == PLAYER:
		var ikey := "intr:%d:%d" % [int(e.get("id", 0)), int(e.get("stage", 1))]
		var text := ""; var pri := EV_INFO
		match outcome:
			"captured": text = "%s took %s with %s." % [fname(fac), nm, card]; pri = EV_CRIT if t == int(rig.get(PLAYER, -1)) else EV_ACT
			"countered": text = "Your defence stopped %s's %s on %s (%s)." % [fname(fac), card, nm, via if via != "" else "a Patch"]
			"route_failed": text = "%s's %s on %s failed: its route broke." % [fname(fac), card, nm]
			"missed": text = "%s's %s on %s failed." % [fname(fac), card, nm]
			"raided": text = "%s's %s on %s went through." % [fname(fac), card, nm]; pri = EV_ACT
			_: text = "%s's %s on %s ended: the host changed owner." % [fname(fac), card, nm]
		var was_live := false
		for ev in events:
			if str(ev.key) == ikey and bool(ev.live): was_live = true; break
		if was_live: _event_end(ikey, text, pri)
		else: _event(ikey, pri, text, t)   # stopped on the spot (a socketed Patch) or between polls


# ---- the Logs button (top-left, under the HUD) and the Events view it opens (H) ----
var logs_button: Button
var _ev_seen_t := -1.0   # when the player last opened the Logs: what came after is new
const LOGS_W := 132.0


func _ev_text(e: Dictionary) -> String:
	return "%s %s%s" % [EV_MARK[int(e.pri)], str(e.text), (" ×%d" % int(e.n)) if int(e.n) > 1 else ""]


func _ev_col(e: Dictionary) -> Color: return [C_BAD, C_WARN, C_TEXT][int(e.pri)]


func _ev_style(b: Button, text: String, col: Color, width: float) -> void:   # one event row: its text, colour and width
	b.text = text; b.custom_minimum_size = Vector2(width, 26)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new(); st.bg_color = Color(0.03, 0.05, 0.08, 0.86 if state == "normal" else 0.96)
		st.border_color = col if state != "normal" else Color(col, 0.35); st.set_border_width_all(1); st.set_corner_radius_all(3)
		st.content_margin_left = 8; st.content_margin_right = 8
		b.add_theme_stylebox_override(state, st)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(key, col)


func _ev_button(parent: Control, text: String, col: Color, cb: Callable, width: float, wrap := false) -> Button:   # wrap: the history; the strip trims
	var b := Button.new(); b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if wrap: b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 14)
	_ev_style(b, text, col, width)
	b.pressed.connect(cb); parent.add_child(b)
	return b


func _logs_unseen() -> Array:   # [new entries since the Logs were last opened, the most urgent priority among them (or among live ones)]
	var n := 0; var pri := EV_INFO
	for e in events:
		if float(e.get("news_t", e.t0)) > _ev_seen_t: n += 1; pri = mini(pri, int(e.pri))   # a live condition's countdown is not news
		elif bool(e.live) and int(e.pri) < EV_INFO: pri = mini(pri, int(e.pri))
	return [n, pri]


func _refresh_event_strip() -> void:   # the Logs button: how many entries are new, coloured by the most urgent one
	_ev_dirty = false
	if logs_button == null: return
	if _tab == "events": _ev_seen_t = _t   # the open view counts as read
	var u := _logs_unseen()
	logs_button.text = "Logs · %d new" % int(u[0]) if int(u[0]) > 0 else "Logs"
	var col: Color = [C_BAD, C_WARN, C_TEXT][int(u[1])] if int(u[0]) > 0 or int(u[1]) < EV_INFO else C_DIM
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: logs_button.add_theme_color_override(key, col)


func _open_logs() -> void:
	_toggle_events()
	_ev_seen_t = _t; _refresh_event_strip()


func _place_event_strip() -> void: pass   # (the old map strip is gone; the Logs button has a fixed place)


func _focus_event(e: Dictionary) -> void:   # find the host it is about: pan to it and open its panel
	var h := int(e.get("host", -1))
	if not _host_ok(h) or not _visible_to(PLAYER, h):
		_toggle_events(); return
	var view := _map_rect()
	_pan = view.get_center() - (hosts[h].pos as Vector2) * _zoom
	if _mine(h): sel = {h: true}; _inspect = -1
	else: sel = {}; _inspect = h
	_tab = ""
	_refresh_panel(); queue_redraw()


func _toggle_events() -> void:   # the Events view in the sidebar (H or the strip's history button)
	if menu_open or won or lost: return
	if _tab == "events" and sel.is_empty() and _inspect < 0: _tab = ""
	else: _tab = "events"; sel = {}; _inspect = -1
	_refresh_panel(); queue_redraw()


func _panel_events() -> void:
	_plabel("Events", 20, C_TEXT)
	_plabel("Newest first. ! needs you now · › worth acting on · · news. Click one to find its host.", 12, C_DIM)
	if events.is_empty(): _plabel("Nothing has happened yet.", 14, C_DIM)
	var w := _panel_width() - 64.0
	for e in events:
		var when := "%s  " % _fmt_time(float(e.t0))
		var state := " (ongoing)" if bool(e.live) else ""
		_ev_button(panel_box, when + _ev_text(e) + state, _ev_col(e), _focus_event.bind(e), w, true)
	_plabel("H or Esc closes this view.", 11, C_DIM)


func _start_exec(e: Dictionary, into = null) -> void:   # an intrusion begins: a Patch in the target's Firewall stops it on the spot
	var t := int(e.target)
	if _fire_socket(t, "patch", str(CARDS[str(e.card)].name)):
		_op_outcome(e, "countered", "the Firewall's Patch")
		return
	if into != null: (into as Array).append(e)
	else: _execs.append(e)


func _worm_next(fac: int, from: int, victim: int, seen: Array = []) -> int:   # the nearest visible host the Worm can still try: same owner as its first target
	var best := -1; var bd := INF
	for nb in hosts[from].links:
		var n := int(nb)
		if seen.has(n) or int(hosts[n].owner) != victim or int(hosts[n].owner) == fac or not _visible_to(fac, n): continue
		var d := (hosts[from].pos as Vector2).distance_to(hosts[n].pos)
		if d < bd or (d == bd and n < best): bd = d; best = n
	return best


func _resolve_vault(fac: int, t: int) -> void:   # empty the storage of the target and its nearest linked hosts into a pile at t for fac
	var victim := int(hosts[t].owner)
	if victim == NEUTRAL or _eliminated.has(victim): return
	var card: Dictionary = CARDS.vault
	var left := int(card.cargo)
	var took := 0
	for h in _chain_hosts(t, int(card.reach), victim):
		var store: Dictionary = hosts[int(h)].store
		for owner_key in store.keys():
			if int(owner_key) == fac: continue   # your own stolen goods waiting there stay yours
			for res in RES:
				var have := int(floor(float((store.get(owner_key, {}) as Dictionary).get(res, 0.0)) + 0.0001))   # emptied entries disappear
				var n := mini(have, left)
				if n <= 0: continue
				_store_take(int(h), int(owner_key), res, float(n))
				_add_to(t, "loot", fac, res, float(n))   # it waits at the target for the raider's workers (outside its storage)
				left -= n; took += n
		for res in RES:   # the victim's salvage piles there are storage too
			var n2 := mini(int(floor(_loot(int(h), victim, res) + 0.0001)), left)
			if n2 <= 0: continue
			_add_to(int(h), "loot", victim, res, -float(n2)); _add_to(t, "loot", fac, res, float(n2))
			left -= n2; took += n2
		for slot in (hosts[int(h)].jobs as Dictionary):   # and so is construction material not yet built in (the worked share is the building)
			var job: Dictionary = hosts[int(h)].jobs[slot]
			var unused := 1.0
			if str(job.phase) == "build" and _job_funded(job): unused = clampf(float(job.left) / maxf(0.001, float(job.total)), 0.0, 1.0)
			for res in RES:
				var n3 := mini(int(floor(float((job.get("escrow", {}) as Dictionary).get(res, 0.0)) * unused + 0.0001)), left)
				if n3 <= 0: continue
				job.escrow[res] = float(job.escrow[res]) - float(n3)   # the project lacks it again: its work stops until it is replaced
				_add_to(t, "loot", fac, res, float(n3))
				_ledger_add(victim, "lost", "stolen", res, float(n3))
				left -= n3; took += n3
	if took <= 0:
		if fac == PLAYER: _flash("Vault raid on %s found nothing to carry" % str(hosts[t].name), 1)
		return
	if fac == PLAYER: _flash("Vault raid on %s: %d units wait there for your workers" % [str(hosts[t].name), took], 0)
	elif victim == PLAYER: _flash("%s emptied your storage near %s: %d units taken" % [fname(fac), str(hosts[t].name), took], 2)


# ---- support cards (applied locally, instantly) ----
func _apply_support(fac: int, recipe: String, t: int, may_load := true) -> void:
	var eff := str(CARDS[recipe].effect)
	hosts[t].hit_t = _t
	_fx.append({"host": t, "until": _t + 2.0, "col": fcol(fac)})
	if may_load and _socketable(recipe) and _socket_free(t) and not _trigger_now(recipe, t):
		_put_socket(t, recipe)
		if fac == PLAYER: _flash("%s loaded into the Firewall on %s: it fires when %s" % [str(CARDS[recipe].name), str(hosts[t].name), str(SOCKET_TRIGGER[recipe])], 0)
		return
	match eff:
		"patch":
			var cancelled := _patch_cancel(fac, t)
			if cancelled: hosts[t].patch_recover_until = _t + float(CARDS.patch.dur)
			else: hosts[t].patch_armed_until = _t + float(CARDS.patch.dur)
		"response": _apply_response(t)
		"filter": _apply_filter(t)
		"cover": _apply_cover(t)
		"express": hosts[t].express_until = _t + float(CARDS.express.dur)
	if fac == PLAYER: _flash("%s on %s" % [str(CARDS[recipe].name), str(hosts[t].name)])


func _apply_response(t: int) -> void:   # Incident response: theft and sabotage here end, unsent stolen output comes back
	if int(hosts[t].get("steal_by", -1)) >= 0: _revert_phish(t)
	hosts[t].steal_by = -1; hosts[t].steal_until = 0.0
	hosts[t].sabot_until = 0.0; hosts[t].siphon = {}


func _apply_filter(t: int) -> void: hosts[t].ddos_until = 0.0; hosts[t].filter_until = _t + float(CARDS.filter.dur)


func _apply_cover(t: int) -> void:   # Cargo cover: cargo leaving this host (on the road now, or later in its time) is safe from siphons
	hosts[t].cover_until = _t + float(CARDS.cover.dur)
	for f in flights:
		if str(f.kind) == "courier" and int(f.get("src", f.origin)) == t and int(f.owner) == int(hosts[t].owner): f.covered = true


func _patch_cancel(_fac: int, t: int) -> bool:   # cancel the earliest-ending capture/raid executing on t; true if one was cancelled
	var bi := -1
	for n in _execs.size():
		var e: Dictionary = _execs[n]
		if int(e.target) == t and str(e.effect) in ["capture", "worm", "vault"]:
			if bi < 0 or float(e.ends) < float(_execs[bi].ends) or (float(e.ends) == float(_execs[bi].ends) and int(e.id) < int(_execs[bi].id)): bi = n
	if bi < 0: return false
	var cancelled: Dictionary = _execs[bi]
	_execs.remove_at(bi)
	_op_outcome(cancelled, "countered", "a Patch")
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


func _cancel_research(fac: int) -> void:   # research is paid as it progresses: cancelling stops the payments, nothing comes back
	var job: Dictionary = research_job.get(fac, {})
	if job.is_empty(): return
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
		for r in cost: _spend(fac, r, float(cost[r]) * frac, "research")
		job.progress = float(job.progress) + work
		job.paid_t = _t   # it advanced: _research_stall tells a slow research from a stopped one
		if float(job.progress) >= duration - 0.00001:
			if not known.has(fac): known[fac] = {}
			known[fac][recipe] = true
			research_job[fac] = {}
			if fac == PLAYER:
				_flash("Blueprint learned: %s" % str(CARDS[recipe].name), 0)
				_event("bp:" + recipe, EV_INFO, "Blueprint learned: %s. Make copies from its tab." % str(CARDS[recipe].name))


# ---- manufacture: ONE first-in-first-out queue of at most QUEUE_SIZE copies, the one being made included ----
# Only the head is made. It pays its price once, from unclaimed main-node stock, when it starts (and needs a free
# ready slot); later entries never overtake it. A recipe click always appends one copy ("queue" command); pausing is
# a separate control for the whole queue; removing a waiting entry costs nothing, cancelling a paid head refunds
# the unworked share. Finished copies move to the ready inventory and leave the queue.
func _mq(fac: int) -> Array:
	if not mq.has(fac): mq[fac] = []
	return mq[fac]


func _mq_add(fac: int, recipe: String, cid := -1) -> bool:   # one more copy at the back of the queue, if there is room
	if not CARDS.has(recipe) or not _known(fac, recipe): return false
	if cid >= 0:
		if not _mq_cids.has(fac): _mq_cids[fac] = {}
		if (_mq_cids[fac] as Dictionary).has(cid): return false   # the same command again: no second copy
		_mq_cids[fac][cid] = true
	var q := _mq(fac)
	if q.size() >= QUEUE_SIZE:
		if fac == PLAYER: _flash("Queue full: %d of %d, the one being made included" % [q.size(), QUEUE_SIZE])
		return false
	_mq_next += 1
	q.append({"id": _mq_next, "recipe": recipe, "paid": {}, "progress": 0.0})
	if fac == PLAYER: _refresh_hand()
	return true


func _mq_remove(fac: int, jid: int) -> void:   # a waiting entry goes for nothing; a paid head refunds its unworked share
	var q := _mq(fac)
	for k in q.size():
		if int(q[k].id) != jid: continue
		var paid: Dictionary = q[k].paid
		if not paid.is_empty():
			var frac := clampf(1.0 - float(q[k].progress) / maxf(0.001, _make_time(str(q[k].recipe))), 0.0, 1.0)
			for r in paid: _add_bank(fac, str(r), float(paid[r]) * frac, "refunds")
			if fac == PLAYER: _flash("Cancelled %s: %s refunded" % [str(CARDS[str(q[k].recipe)].name), _res_list(_scaled(paid, frac))], 0)
		q.remove_at(k)
		break
	if fac == PLAYER: _refresh_hand()


func _scaled(d: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k in d: out[k] = float(d[k]) * f
	return out


func _mq_toggle_pause(fac: int) -> void: mq_paused[fac] = not bool(mq_paused.get(fac, false))


func _mq_head_short(fac: int) -> Dictionary:   # what the waiting head still needs at the main node ({} if it can start)
	var q := _mq(fac)
	if q.is_empty() or not (q[0].paid as Dictionary).is_empty(): return {}
	var out := {}
	var cost := _recipe_cost(str(q[0].recipe))
	for r in cost:
		var need := float(cost[r]) - _free(fac, str(r))
		if need > 0.0001: out[r] = need
	return out


func _mq_head_why(fac: int) -> String:   # "" while it is made or can start; else why the head waits
	var q := _mq(fac)
	if q.is_empty() or not (q[0].paid as Dictionary).is_empty(): return ""
	if _ready_total(fac) >= READY_SLOTS: return "Ready inventory full — use a card"
	var short := _mq_head_short(fac)
	if short.is_empty(): return ""
	var parts := []
	for r in RES:
		if not short.has(r): continue
		var coming := _incoming(fac, r)
		parts.append("%d %s%s" % [ceili(float(short[r]) - 0.0001), RES_NAME[r], (" · %s on the way" % _amt(coming)) if coming > 0.05 else ""])
	return "Needs " + ", ".join(parts) + " at Main rig"


func _mq_head_short_whole(fac: int) -> Dictionary:   # the head's shortage in whole units, for the strip's icons
	var out := {}
	var short := _mq_head_short(fac)
	for r in short: out[r] = ceili(float(short[r]) - 0.0001)
	return out


func _mq_head_why_short(fac: int) -> String:   # the strip's chip: the first thing the waiting head lacks, in a few words
	var q := _mq(fac)
	if q.is_empty() or not (q[0].paid as Dictionary).is_empty(): return ""
	if _ready_total(fac) >= READY_SLOTS: return "Ready full"
	var short := _mq_head_short(fac)
	for r in RES:
		if short.has(r): return "Needs %d %s%s" % [ceili(float(short[r]) - 0.0001), RES_NAME[r], "…" if short.size() > 1 else ""]
	return ""


func _can_start_recipe(fac: int, recipe: String) -> bool:
	if _ready_total(fac) >= READY_SLOTS: return false
	var cost := _recipe_cost(recipe)
	for r in cost:
		if _free(fac, r) < float(cost[r]) - 0.0001: return false   # stock held for a worker's pickup is not spent
	return true


func _start_recipe(fac: int, recipe: String) -> Dictionary:
	var cost := _recipe_cost(recipe)
	for r in cost: _spend(fac, r, float(cost[r]), "manufacturing")
	return cost.duplicate()


func _tick_manufacture(dt: float) -> void:
	for fac in botnets:
		var q := _mq(fac)
		if bool(mq_paused.get(fac, false)): continue
		var left := dt
		while left > 0.000001 and not q.is_empty():
			var job: Dictionary = q[0]
			if (job.paid as Dictionary).is_empty():
				if not _can_start_recipe(fac, str(job.recipe)): break   # the head waits; nothing overtakes it
				job.paid = _start_recipe(fac, str(job.recipe)); job.progress = 0.0
			var need := _make_time(str(job.recipe)) - float(job.progress)
			var used := minf(left, need)
			job.progress = float(job.progress) + used; left -= used
			if float(job.progress) < _make_time(str(job.recipe)) - 0.00001: break
			cards[fac][str(job.recipe)] = _held(fac, str(job.recipe)) + 1   # its ready slot was held while it was made
			q.remove_at(0)
			if fac == PLAYER:
				_mq_done_t = _t
				_flash("Ready: %s" % str(CARDS[str(job.recipe)].name), 0)
				_event("mf:" + str(job.recipe), EV_INFO, "Copy ready: %s (%d held)." % [str(CARDS[str(job.recipe)].name), _held(fac, str(job.recipe))])
				_bank_alert["ready"] = Time.get_ticks_msec() + 3000
				_refresh_hand()


var _mq_done_t := -100.0   # when the player's last copy finished (the strip shows it done for a moment; presentation only)
# ============================================================ AI BOTNETS
# One economic AI. It obeys the same income, workers, delivery, research, prices, four-place queue, room limits and fog as a
# person: it develops producers, learns blueprints, manufactures known cards and uses them to capture, steal and
# defend. It reads only what it can observe (public owners/types, and dated Recon snapshots).
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
	_ai_defend(fac, mine)


func _ai_develop(fac: int, mine: Array) -> void:   # every host gets a layout that feeds itself and carries its own output home
	var home := int(rig[fac])
	var sites := mine.duplicate()
	sites.erase(home); sites.push_front(home)   # the main node first: what it makes needs no courier
	# At 5 units a minute the bank rarely holds a whole bill: the card queue would spend it first. So, like a person, it
	# orders a project before it can pay and lets the workers bring the materials. Only one project at a time waits for
	# them, and building and cards take turns: after each such order, the next waits for a new copy to be made.
	_ai_drop_stranded(fac, mine)
	var may_owe := _ai_may_owe(fac)
	var owed_before := may_owe
	if _ai_workers_short(fac):   # the pool is short of workers: a station in the first free slot anywhere, ahead of the plans
		var spot := _ai_station_spot(fac, sites, mine.size())
		if not spot.is_empty() and (_can_afford_build(fac, "bot") or may_owe) and _start_job(int(spot[0]), "bot", int(spot[1])):
			may_owe = false
	for i in sites:
		if not (hosts[i].jobs as Dictionary).is_empty(): continue
		if i != home and _home_route(fac, i).is_empty(): continue   # a producer needs a road home
		var plan := _ai_plan(fac, i, mine.size())
		for slot in mini(plan.size(), (hosts[i].builds as Array).size()):   # the first empty slot, in plan order
			if str(hosts[i].builds[slot]) != "" or _slot_busy(i, slot): continue
			var kind := str(plan[slot])
			if _can_afford_build(fac, kind): _start_job(i, kind, slot)
			elif may_owe and _start_job(i, kind, slot): may_owe = false
			break
	_ai_rebalance(fac, sites, not _ai_waiting_build(fac))   # a retool may owe without waiting for a card: it fixes the shortage that starves them
	if owed_before and (not may_owe or _ai_waiting_build(fac)): _ai[fac].owe_mark = _ai_cards_made(fac)   # cards' turn now


func _ai_waiting_build(fac: int) -> bool:   # one of its projects (not paused) still waits for materials its workers can bring
	for i in hosts.size():
		if int(hosts[i].owner) != fac or (hosts[i].jobs as Dictionary).is_empty(): continue
		if i != int(rig[fac]) and _home_route(fac, i).is_empty(): continue   # cut off: nothing reaches it, so nothing waits on it
		for s in (hosts[i].jobs as Dictionary):
			if _ai_job_owed(hosts[i].jobs[s]) and not bool(hosts[i].jobs[s].get("paused", false)): return true
	return false


func _ai_job_owed(j: Dictionary) -> bool:   # a project (not a bare demolition) whose bill is not all there; a retool counts from its demolition on
	return str(j.get("kind", "")) != "" and not _job_funded(j)


const AI_STRAND_DROP := 60.0   # seconds a project may sit cut off from the main node before the AI cancels it (longer than a DDoS)


func _ai_drop_stranded(fac: int, mine: Array) -> void:   # a project whose host lost its road home cannot get its bill: drop it after a while,
	var was: Dictionary = _ai[fac].get("cut", {})       # so its slot, the retool turn and the worker count are free again
	var now := {}
	for i in mine:
		if i == int(rig[fac]) or (hosts[i].jobs as Dictionary).is_empty() or not _home_route(fac, i).is_empty(): continue
		for s in (hosts[i].jobs as Dictionary).keys():
			var j: Dictionary = hosts[i].jobs[s]
			if not _ai_job_owed(j): continue
			var id := int(j.id)
			now[id] = float(was.get(id, _t))
			if _t - float(now[id]) >= AI_STRAND_DROP: _do_cancel_job(fac, i, int(s)); now.erase(id)
	_ai[fac].cut = now


func _ai_capture_in_play(fac: int) -> bool:   # a capture copy in hand, on its way or executing (or nothing to capture): the
	if _ai_capture_targets(fac).is_empty(): return true   # card queue has done its part for now
	for r in ["breach", "exploit", "zeroday"]:
		if _held(fac, r) > 0: return true
	for f in flights:
		if str(f.kind) == "op" and int(f.owner) == fac and str(CARDS[_card_of(str(f.get("card", "recon")))].effect) in ["capture", "worm"]: return true
	for e in _execs:
		if int(e.fac) == fac and str(e.effect) in ["capture", "worm"]: return true
	return false


func _ai_cards_made(fac: int) -> int:   # copies made so far: the ones played plus the ones in hand
	var n := int(card_plays.get(fac, 0))
	for r in (cards.get(fac, {}) as Dictionary): n += int(cards[fac][r])
	return n


func _ai_may_owe(fac: int) -> bool:   # it may order a project it cannot pay for yet: none waits, it is not research's
	if _ai_waiting_build(fac) or _ai_research_due(fac): return false   # turn, and a copy was made since the last such order
	return _ai_capture_targets(fac).is_empty() or _ai_cards_made(fac) > int(_ai[fac].get("owe_mark", -1))


func _ai_station_spot(fac: int, sites: Array, held: int) -> Array:   # [host, slot] for a station (one anywhere serves all): the host with the most
	var best := []; var most := 0; var lab_spot := []                 # free slots and a road home; the host planned to make Research only when no
	for i in sites:                                                   # other has room, and then in a slot that keeps its layout
		if i != int(rig[fac]) and _home_route(fac, i).is_empty(): continue
		var free := 0
		for slot in (hosts[i].builds as Array).size():
			if str(hosts[i].builds[slot]) == "" and not _slot_busy(i, slot): free += 1
		if free == 0 or (free <= most and not lab_spot.is_empty()): continue
		var plan := [] if i == int(rig[fac]) else _ai_plan(fac, i, held)
		if plan.has("lab"):
			var k := _ai_lab_station_slot(i, plan)
			if lab_spot.is_empty() and k >= 0: lab_spot = [i, k]
		elif free > most: most = free; best = [i, _free_slot(i)]
	return best if not best.is_empty() else lab_spot


func _ai_lab_station_slot(i: int, plan: Array) -> int:   # a slot of the Research host a station may take without undoing its layout, else -1
	var b: Array = hosts[i].builds
	for k in plan.size():   # its plan's own station
		if str(plan[k]) == "bot" and str(b[k]) == "" and not _slot_busy(i, k): return k
	if plan.size() == 3: return 0 if str(b[0]) == "" and not _slot_busy(i, 0) else -1   # [station, Miner, Lab]: workers bring the Intel
	for k in range(plan.size() - 1, 0, -1):   # a spare harvester's place (never the first: it feeds the Miner)
		if str(plan[k]) == "intel" and str(b[k]) == "" and not _slot_busy(i, k): return k
	return -1


func _ai_plan(fac: int, i: int, held: int) -> Array:   # what each slot of host i should hold
	var n := int(hosts[i].slots)
	if i == int(rig[fac]): return ["intel", "bot", _ai_conv(fac, true), "lab", "cred"].slice(0, n)   # converters here use the bank
	var short_workers := _ai_workers_short(fac)
	if n == 1: return ["bot" if short_workers else "intel"]   # a lone slot: a station only while the pool lacks workers
	var conv := _ai_conv(fac)
	var plan := (["bot", "intel", conv, "intel", conv] if short_workers else ["intel", conv, "intel", conv, "intel"]).slice(0, n)   # a harvester per converter (1 Intel each a cycle); stations only as the pool needs them
	var b: Array = hosts[i].builds
	var near := _ai_capture_targets(fac)
	var wants_research := held >= 3 or (not near.is_empty() and int(hosts[int(near[0])].owner) != NEUTRAL)   # faster captures against a rival run on Research
	if n == 3 and wants_research and not _ai_has_lab_host(fac, i) and str(b[0]) in ["", "intel", "bot"] and str(b[1]) in ["", "cash"] and str(b[2]) in ["", "lab"]:
		plan = ["intel", "cash", "lab"]   # no Lab yet: one host makes Research (its Miner feeds the Lab; main-node workers carry it; a station
		                                  # that had to take the harvester's place leaves the Intel to them)
	if n >= 4 and not _ai_has_lab_host(fac, i):   # a self-fed Research host: one harvester for the Miner, one for the Lab
		plan = (["bot", "intel", "cash", "intel", "lab"] if short_workers and n >= 5 else ["intel", "cash", "intel", "lab", "intel"]).slice(0, n)
	elif n >= 4 and held >= 6 and not _ai_has_firewall(fac): plan[3] = "wall"   # one guarded host once the network is worth guarding
	return plan


func _ai_workers_short(fac: int) -> bool:   # one pool serves every host: about one station (2 workers) per two hosts held, stations on order counted
	var held := 0; var stations := 0
	for i in hosts.size():
		if int(hosts[i].owner) != fac: continue
		held += 1; stations += _count_all(i, "bot")
		for slot in (hosts[i].jobs as Dictionary): if str(hosts[i].jobs[slot].get("kind", "")) == "bot": stations += 1
	return stations * 2 < held


func _ai_has_lab_host(fac: int, except: int) -> bool:   # a host other than `except` (and not the main node) runs a Lab, or has one on order
	for i in hosts.size():
		if i == except or int(hosts[i].owner) != fac or i == int(rig[fac]): continue
		if (hosts[i].builds as Array).has("lab"): return true
		for s in (hosts[i].jobs as Dictionary):
			if str(hosts[i].jobs[s].get("kind", "")) == "lab": return true
	return false


func _ai_conv(fac: int, at_main := false) -> String:   # what the next card is short of, else the emptiest bank (a Lab only where the bank feeds it)
	var want := _ai_wanted(fac)
	var best := "cred"; var lo := INF
	for kind in (["cred", "cash", "intel", "lab"] if at_main else ["cred", "cash", "intel"]):
		var res := {"cred": "creds", "cash": "cash", "intel": "intel", "lab": "research"}[kind] as String
		var fill := _avail(fac, res) / maxf(1.0, _cap(fac, res)) - (1.0 if 2.0 * float(want.get(res, 0.0)) > _avail(fac, res) else 0.0)   # short of two copies
		if fill < lo: lo = fill; best = kind
	return best


func _ai_free_socket(fac: int) -> bool:
	for i in hosts.size():
		if int(hosts[i].owner) == fac and _socket_free(i): return true
	return false


func _ai_has_firewall(fac: int) -> bool:
	for i in hosts.size():
		if int(hosts[i].owner) == fac and (hosts[i].builds as Array).has("wall"): return true
	return false


const AI_RETOOL_GAP := 120.0   # seconds between two retools of one AI


func _ai_rebalance(fac: int, sites: Array, may_owe := false) -> void:   # a bank that overflows while another runs dry: retool one producer
	for i in sites:
		if not (hosts[i].jobs as Dictionary).is_empty(): return   # one retool at a time
	var makes := {"cash": "cash", "cred": "creds", "intel": "intel"}
	var want := _ai_wanted(fac)
	var full := ""; var short := ""; var lo := 0.15; var hi := -1.0
	var spot := {}   # kind -> [host, slot]: the first producer of it the AI may retool
	for kind in makes:
		spot[kind] = _ai_retool_spot(fac, sites, kind)
		var have := _avail(fac, makes[kind])
		var fill := have / maxf(1.0, _cap(fac, makes[kind]))
		var piling := fill >= 0.4 or have >= maxf(24.0, 3.0 * float(want.get(makes[kind], 0.0)))   # far more than its cards need
		if piling:   # only a piling bank with a producer to retool can give one up (the trickle alone fills Crypto)
			if fill > hi and not (spot[kind] as Array).is_empty(): hi = fill; full = kind
		elif fill < lo: lo = fill; short = kind
	if full == "" or short == "" or not (_can_afford_build(fac, short) or may_owe): return
	if _t < float(_ai[fac].get("retool_t", -999.0)) + AI_RETOOL_GAP: return   # let the last retool show before the next: no flip-flopping
	if _start_job(int(spot[full][0]), short, int(spot[full][1])): _ai[fac].retool_t = _t


func _ai_retool_spot(fac: int, sites: Array, kind: String) -> Array:   # [host, slot] of the first producer of `kind` it may retool, else []
	for i in sites:   # the main node first: its converters eat the bank's surplus directly
		if i != int(rig[fac]) and _home_route(fac, i).is_empty(): continue   # no road home: the new bill could never arrive
		var first := 0 if i == int(rig[fac]) else 2   # on other hosts never the station or the harvester that feeds them
		for k in range(first, (hosts[i].builds as Array).size()):
			if str(hosts[i].builds[k]) == kind and not _slot_busy(i, k): return [i, k]
	return []


func _ai_wanted(fac: int) -> Dictionary:   # the price of the card the AI is working towards: its capture card, else Breach
	var targets := _ai_capture_targets(fac)
	var card := _ai_capture_card(fac, int(targets[0]), false) if not targets.is_empty() else ""
	return _recipe_cost(card if card != "" else "breach")


func _ai_research(fac: int) -> void:
	# Capture ladder first (reach is what wins ground), then a counter, disruption, theft, then the rest. Research takes
	# its turn with building and cards: one blueprint per four of its buildings. A running research pays as it goes, so
	# it pauses while one of its projects waits for materials: its per-second payments would keep the bank below the
	# whole unit a worker carries.
	var job: Dictionary = research_job.get(fac, {})
	if not job.is_empty():
		job.paused = _ai_waiting_build(fac)   # construction first
		return
	if not _ai_research_due(fac): return
	for recipe in ["exploit", "filter", "ddos", "zeroday", "worm", "siphon", "cover", "sabotage", "vault", "express"]:
		if _known(fac, recipe) or _can_research(fac, recipe) != "": continue
		_do_research(fac, recipe)
		return


func _ai_research_due(fac: int) -> bool:   # research's turn: fewer blueprints learned than its buildings / 4, or nowhere left to build
	var learned := 0
	for r in RESEARCH:
		if _known(fac, str(r)): learned += 1
	var built := 0; var free := 0
	for i in hosts.size():
		if int(hosts[i].owner) != fac: continue
		var reach := i == int(rig[fac]) or not _home_route(fac, i).is_empty()
		for slot in (hosts[i].builds as Array).size():
			if str(hosts[i].builds[slot]) != "": built += 1
			elif reach and not _slot_busy(i, slot): free += 1
	return learned < built / 4 or (free == 0 and learned < RESEARCH.size())   # boxed in: building has no turn to take


func _ai_first_known(fac: int, options: Array) -> String:
	for r in options:
		if _known(fac, r): return str(r)
	return ""


func _ai_capture_targets(fac: int) -> Array:   # reachable foreign hosts to take: neutral first, then a rival's, main nodes last; nearest first
	var home := int(rig.get(fac, -1))
	var out := []
	for t in hosts.size():
		var owner := int(hosts[t].owner)
		if owner == fac or not _op_reachable(fac, t): continue
		var tier := 0 if owner == NEUTRAL else (2 if bool(hosts[t].get("rig", false)) else 1)
		out.append([tier, (hosts[home].pos as Vector2).distance_to(hosts[t].pos), t])
	out.sort_custom(func(a, b): return _less(a, b))
	return out.map(func(x): return int(x[2]))


func _ai_capture_card(fac: int, t: int, held_only: bool, kept := {}) -> String:   # neutral: the cheapest card; a rival's host: the fastest
	var order := ["breach", "exploit", "zeroday"] if int(hosts[t].owner) == NEUTRAL else ["zeroday", "exploit", "breach"]
	for recipe in order:   # (kept: copies held back for a host whose Recon is on its way)
		if (_held(fac, recipe) - int(kept.get(recipe, 0)) > 0 if held_only else _known(fac, recipe)): return recipe
	return ""


func _ai_scouting(fac: int, t: int) -> bool:   # a Recon of ours is on its way to t
	for f in flights:
		if str(f.kind) == "op" and int(f.owner) == fac and int(f.get("target", -1)) == t and str(f.get("card", "")) == "recon": return true
	return false


func _ai_scout_first(fac: int, t: int, recipe: String) -> bool:   # true: this attack waits for (or just launched) a Recon of t
	var rt := _attack_route(fac, t)
	var at := _t + _travel_time(rt) + (_exec_time(recipe, t) if str(CARDS[recipe].effect) in ["capture", "worm", "vault"] else 0.0)
	if _is_defense(recipe) or _recon_fresh(fac, t, at): return false   # scouted when it resolves: 50%, the best there is
	if at - _t > float(CARDS.recon.dur): return false   # resolves later than any Recon sent now stays fresh: scouting cannot help
	if _ai_scouting(fac, t): return true
	if _held(fac, "recon") > 0 and _can_play(fac, "recon", t) == "":
		_play_card(fac, "recon", t); return true
	if _known(fac, "recon") and _mq_count(fac, "recon") > 0 and _mq_head_why(fac) == "": return true   # one is being made: wait for it
	return false   # no Recon to hand or coming: attack at 25% rather than not at all


func _ai_manufacture(fac: int) -> void:
	# demand-driven: make only cards we can use, throttled by how many we already hold, so inventory never clogs
	var plan := []
	var targets := _ai_capture_targets(fac)
	if not targets.is_empty():
		var cap_card := _ai_capture_card(fac, int(targets[0]), false)
		if cap_card != "" and _held(fac, cap_card) < 3: plan.append(cap_card)
		if _known(fac, "recon") and _held(fac, "recon") < 1: plan.append("recon")   # unscouted attacks work half as often (25% vs 50%)
	var threatened := false   # a hostile capture or raid is executing on one of our hosts
	for e in _execs:
		if int(e.fac) != fac and int(hosts[int(e.target)].owner) == fac: threatened = true; break
	var spare_patch := 1 if _ai_mine(fac).size() >= 5 else 0   # a small network spends its Intel on growing, not on a spare
	if _known(fac, "patch") and _held(fac, "patch") < (2 if threatened else spare_patch): plan.append("patch")
	for recipe in ["response", "filter"]:   # a Firewall socket with room gets a card that fires on its own
		if _known(fac, recipe) and _held(fac, recipe) < 1 and _ai_free_socket(fac): plan.append(recipe); break
	for press in ["ddos", "phish"]:   # pressure only with somewhere to apply it: an idle copy is resources thrown away
		if _known(fac, press) and _held(fac, press) < 1 and _ai_press_target(fac, press) >= 0: plan.append(press); break
	var q := _mq(fac)   # the same one queue as a player's: top it up in plan order, never past QUEUE_SIZE
	for recipe in plan:
		if q.size() >= QUEUE_SIZE: break
		if _mq_count(fac, str(recipe)) == 0: _mq_add(fac, str(recipe))


func _ai_press_target(fac: int, recipe: String) -> int:   # the reachable rival host with the most producers its Recon saw, else -1
	var best := -1; var most := 0
	for t in hosts.size():
		var owner := int(hosts[t].owner)
		if owner == fac or owner == NEUTRAL or not _op_reachable(fac, t): continue
		if (recipe == "phish" and _phished(t)) or (recipe == "ddos" and _ddos_down(t)): continue
		var rec: Dictionary = (recon.get(fac, {}) as Dictionary).get(t, {})   # the same fog as a person: only what a Recon saw
		var n := 1   # never scouted: worth a look (it scouts first)
		if not rec.is_empty() and int(rec.get("gen", -1)) == int(hosts[t].gen):
			n = 0
			for k in (rec.get("builds", []) as Array): if str(k) in PRODUCER_KINDS: n += 1
		if n > most: most = n; best = t
	return best


func _ai_defend(fac: int, mine: Array) -> void:   # answer an intrusion with Patch; keep spare defence cards in Firewall sockets
	if _held(fac, "patch") > 0:
		for e in _execs:
			if int(e.fac) == fac: continue
			var t := int(e.target)
			if int(hosts[t].owner) != fac: continue
			if str(CARDS[str(e.card)].effect) in ["capture", "worm", "vault"] and _can_play(fac, "patch", t) == "":
				_play_card(fac, "patch", t)
				if _held(fac, "patch") <= 0: break
	for i in mine:   # the attacks the AI cannot watch for get a card that fires on its own
		if not _socket_free(i): continue
		for recipe in ["response", "filter", "patch"]:
			if _held(fac, recipe) > (1 if recipe == "patch" else 0) and not (hosts[i].sockets as Array).has(recipe) and _can_play(fac, recipe, i) == "":
				_play_card(fac, recipe, i)
				break


func _ai_operate(fac: int, mine: Array) -> void:
	var home := int(rig.get(fac, -1))
	if home < 0 or int(hosts[home].owner) != fac: return
	# expand: neutral hosts first, then a rival's, nearest first; scout each with Recon first when a copy is in hand
	var launches := 3
	var kept := {}   # a host being scouted keeps its capture copy: spending it elsewhere would waste the Recon
	for t in _ai_capture_targets(fac):
		if launches <= 0: break
		var card := _ai_capture_card(fac, t, true, kept)
		if card == "" or _intrusion_busy(fac, t) or _can_play(fac, card, t) != "": continue
		if _ai_scout_first(fac, t, card): launches -= 1; kept[card] = int(kept.get(card, 0)) + 1; continue
		if _play_card(fac, card, t): launches -= 1
	# pressure: Phishing steals the output of, DDoS stops, the reachable rival host with the most producers
	for press in ["phish", "ddos"]:
		if _held(fac, press) <= 0: continue
		var t := _ai_press_target(fac, press)
		if t >= 0 and _can_play(fac, press, t) == "" and not _ai_scout_first(fac, t, press): _play_card(fac, press, t)


# -- knowledge helpers kept for the UI/tests (dated Recon) --
func _ai_remember(_fac: int) -> void: pass

# ============================================================ INPUT

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.keycode == KEY_ESCAPE:
		if not menu_open and _armed != "": _armed = ""; _update_card_banks(); queue_redraw(); get_viewport().set_input_as_handled(); return
		if menu_open: _open_menu(false)
		elif _camp: _camp_leave()
		elif _panel_has_context(): _clear_all(); _refresh_panel(); queue_redraw()
		else: _open_menu(true)
		get_viewport().set_input_as_handled(); return
	if menu_open or won or lost: return
	if event.keycode == KEY_SPACE:
		if _camp_paused: _camp_set_pause(false); get_viewport().set_input_as_handled(); return   # resume the lesson's reading pause
		if _mp_on: return   # a shared match never pauses
		paused = not paused; _refresh_panel(); queue_redraw()   # your own pause (in Learn too): separate from the lesson's
		if _camp: _show_tut()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_0: _reset_view()
	elif event.keycode == KEY_C: _set_deck_open(not _deck_open); get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R: _toggle_research(); get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E: _toggle_economy(); get_viewport().set_input_as_handled()
	elif event.keycode == KEY_H: _open_logs(); get_viewport().set_input_as_handled()


func _can_drop_data(pos: Vector2, data: Variant) -> bool:   # a hand card held over the map
	if not (data is Dictionary) or not (data as Dictionary).has("card"): return false
	var t := _host_at(pos)
	return t >= 0 and _can_play(PLAYER, str(data.card), t) == ""


func _drop_data(pos: Vector2, data: Variant) -> void:
	var t := _host_at(pos)
	if t >= 0: _cmd(["card", str(data.card), t, _chosen_siphon_res])


func _dragged_card() -> String:   # the hand card being dragged right now, or ""
	if not is_inside_tree() or get_viewport() == null or not get_viewport().gui_is_dragging(): return ""
	var d: Variant = get_viewport().gui_get_drag_data()
	if d is Dictionary and (d as Dictionary).has("card"): return str(d.card)
	return ""


func _pointer_over_panel() -> bool:
	return panel != null and panel.visible and panel.get_global_rect().has_point(get_viewport().get_mouse_position())


# ATTACK and DEFENCE hold the recipes you know (the cards you can make), four at a time (paged);
# RESEARCH shows the development tree instead.
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
	var recipes := _card_bank in ["attack", "defense"]
	for tile in hand_bar.get_children():
		var index := shown.find(_card_of(tile.key))   # -1: the other bank
		tile.visible = recipes and index >= _deck_page * 4 and index < _deck_page * 4 + 4
		tile.custom_minimum_size = Vector2(width, CARD_DOCK_HEIGHT); tile.queue_redraw()
	hand_bar.size = Vector2(hand_panel.size.x, CARD_DOCK_HEIGHT)
	hand_bar.visible = recipes
	ready_grid.visible = _card_bank == "ready"
	if ready_grid.visible: _layout_ready_grid()
	(hand_panel.get_node("ReadyNone") as Label).visible = _card_bank == "ready" and _ready_list().is_empty()
	var research := _card_bank == "research"
	research_tree.visible = research; research_info.visible = research
	if research:
		research_info.position = Vector2.ZERO; research_info.size = Vector2(hand_panel.size.x, RESEARCH_INFO_H)
		research_tree.set_anchors_preset(Control.PRESET_TOP_LEFT)
		research_tree.position = Vector2(0, RESEARCH_INFO_H + 6.0); research_tree.size = Vector2(hand_panel.size.x, CARD_DOCK_HEIGHT)
		research_tree.call("relayout")
	_update_card_banks()


func _deck_cards() -> Array:   # what the drawer's view pages through: the cards you hold, or the open bank's KNOWN recipes
	match _card_bank:
		"ready": return _ready_list()
		"research": return []
	return _known_of(CfgCards.DEFENSE_ORDER if _card_bank == "defense" else CfgCards.ATTACK_ORDER)


func _ready_list() -> Array:   # the recipes you hold at least one copy of, in deck order
	return CARD_ORDER.filter(func(r): return _held(PLAYER, str(r)) > 0)


func _known_of(order: Array) -> Array: return order.filter(func(r): return _known(PLAYER, str(r)))


func _per_page() -> int:   # cards on one page of the drawer's view
	if _card_bank != "ready": return 4
	var cols := maxi(1, int((hand_panel.size.x + CARD_DOCK_GAP) / (READY_TILE.x + CARD_DOCK_GAP)))
	var rows := maxi(1, int((CARD_DOCK_HEIGHT + CARD_DOCK_GAP) / (READY_TILE.y + CARD_DOCK_GAP)))
	return cols * rows


func _deck_pages() -> int:
	return maxi(1, ceili(float(_deck_cards().size()) / float(_per_page())))


func _deck_page_of(recipe: String) -> int:   # the page a recipe sits on in its own bank's recipes
	var order: Array = _known_of(CfgCards.DEFENSE_ORDER if _is_defense(recipe) else CfgCards.ATTACK_ORDER)
	return maxi(0, order.find(recipe)) / 4


func _layout_ready_grid() -> void:   # fixed-size tiles, as many columns as fit; more cards turn the page, never shrink
	ready_grid.columns = maxi(1, int((hand_panel.size.x + CARD_DOCK_GAP) / (READY_TILE.x + CARD_DOCK_GAP)))
	var list := _ready_list()
	var per := _per_page()
	for tile in ready_grid.get_children():
		var index := list.find(_card_of(str(tile.key)))
		tile.visible = index >= _deck_page * per and index < _deck_page * per + per
		tile.custom_minimum_size = READY_TILE
	ready_grid.position = Vector2.ZERO; ready_grid.size = ready_grid.get_combined_minimum_size()


func _deck_turn(step: int) -> void:   # page the drawer; wraps round
	_deck_page = posmod(_deck_page + step, _deck_pages())
	_refresh_hand()


func _tab_col(bank: String) -> Color: return BANK_COL[bank] if BANK_COL.has(bank) else C_GOOD


func _update_card_banks(chips := true) -> void:   # tab text and look, pager, research line, top Research button; chips = repaint the strip
	if card_banks == null or deck_handle == null: return
	var now := Time.get_ticks_msec()
	var sig := _known_signature() + "|" + ",".join(PackedStringArray(_ready_list()))
	if sig != _ready_sig:   # a recipe was learned, or a card came into or went out of your hand: the strip and drawer change
		_ready_sig = sig
		if _armed != "" and _held(PLAYER, _armed) <= 0: _armed = ""
		_layout_deck(); _refresh_hand()
	var held := 0
	for r in CARD_ORDER: held += _held(PLAYER, str(r))
	for index in DRAWER_TABS.size():
		var bank: String = DRAWER_TABS[index]
		var button: Button = card_banks.get_child(index)
		button.text = {"ready": "Ready ×%d" % held, "research": _research_label()}.get(bank, str(DRAWER_TAB_NAME[bank]))
		var shown := _deck_open and bank == _card_bank
		var blink := not shown and now < int(_bank_alert.get(bank, 0)) and (now / 250) % 2 == 0
		var look := "flash" if blink else ("open" if shown else "closed")
		if str(button.get_meta("look", "")) != look:
			button.set_meta("look", look); _style_bank_tab(button, bank, look)
	if deck_pager != null:
		var pages := _deck_pages()
		deck_pager.visible = _deck_open and _card_bank != "research" and pages > 1 and not menu_open and not won and not lost
		(deck_pager.get_node("PageLabel") as Label).text = "Page %d / %d" % [mini(_deck_page, pages - 1) + 1, pages]
	if research_status != null:
		var rl := _research_status_line()
		research_status.text = str(rl[0]); research_status.add_theme_color_override("font_color", rl[1])
		research_status.visible = _deck_open and _card_bank == "research" and not menu_open and not won and not lost
	if research_button != null:
		research_button.text = _research_label()
		research_button.tooltip_text = "The development tree (R). " + str(_research_status_line()[0])
	if queue_pause != null: queue_pause.text = "Resume" if bool(mq_paused.get(PLAYER, false)) else "Pause"
	if chips:
		for c in lane_strip.get_children(): c.queue_redraw()
		for c in ready_strip.get_children(): c.queue_redraw()


func _known_signature() -> String:
	var bits := ""
	for r in CARD_ORDER: bits += "1" if _known(PLAYER, str(r)) else "0"
	return bits


func _research_label() -> String:   # the Research button and tab: "Research 45%", "Paused 45%", "Stalled 45%", or "Research +n" open
	var job: Dictionary = research_job.get(PLAYER, {})
	if not job.is_empty():
		var pct := int(100.0 * clampf(float(job.progress) / maxf(0.001, _research_time(str(job.key))), 0.0, 1.0))
		if bool(job.get("paused", false)): return "Paused %d%%" % pct
		if _research_stall(PLAYER) != "": return "Stalled %d%%" % pct
		return "Research %d%%" % pct
	var open := 0
	for r in RESEARCH:
		if _can_research(PLAYER, str(r)) == "": open += 1
	return "Research +%d" % open if open > 0 else "Research"


const RESEARCH_BAR_W := 520.0
const RESEARCH_STALL_SECS := 13.0   # research that paid nothing for longer than a production cycle is "stopped" (else "slowed")
const RESEARCH_BAR_H := 28.0


func _research_bar_y() -> float: return (64.0 + _camp_banner_h() + 6.0) if _banner_on() else 62.0


func _banner_on() -> bool: return _tut and not _camp_banner_gone   # the Learn banner takes room at the top


func _research_bar_state() -> Dictionary:   # {state: idle | active | paused | stalled, name, track, frac, left, why}
	var job: Dictionary = research_job.get(PLAYER, {})
	if job.is_empty():
		var open := 0
		for r in RESEARCH:
			if _can_research(PLAYER, str(r)) == "": open += 1
		return {"state": "idle", "name": "", "track": "", "frac": 0.0, "left": 0.0, "open": open, "why": ""}
	var recipe := str(job.key)
	var frac := clampf(float(job.progress) / maxf(0.001, _research_time(recipe)), 0.0, 1.0)
	var st := "active"
	var why := ""
	if bool(job.get("paused", false)): st = "paused"
	else:
		var stall := _research_stall(PLAYER)
		if stall != "": st = "stalled"; why = stall.trim_prefix("Research of %s stopped: " % str(CARDS[recipe].name)).trim_suffix(".")
	return {"state": st, "name": str(CARDS[recipe].name), "track": "Defence" if str(CARDS[recipe].bank) == "defense" else "Attack",
		"frac": frac, "left": maxf(0.0, _research_time(recipe) - float(job.progress)), "why": why, "slow": _research_slow(PLAYER) if st == "active" else ""}


func _research_status_line() -> Array:   # [text, colour]: the active research, by name, with its progress and state
	var job: Dictionary = research_job.get(PLAYER, {})
	if job.is_empty(): return ["No research running. Select a blueprint, then Research.", C_DIM]
	var recipe := str(job.key)
	var pct := int(100.0 * clampf(float(job.progress) / maxf(0.001, _research_time(recipe)), 0.0, 1.0))
	var left := int(ceil(maxf(0.0, _research_time(recipe) - float(job.progress))))
	if bool(job.get("paused", false)): return ["Paused: %s at %d%%." % [str(CARDS[recipe].name), pct], C_WARN]
	var stall := _research_stall(PLAYER)
	if stall != "": return ["Stalled at %d%%: %s" % [pct, stall.trim_prefix("Research of %s stopped: " % str(CARDS[recipe].name))], C_BAD]
	var slow := _research_slow(PLAYER)
	if slow != "": return ["Researching %s: %d%%, %s." % [str(CARDS[recipe].name), pct, slow], C_WARN]
	return ["Researching %s: %d%%, %d s left." % [str(CARDS[recipe].name), pct, left], C_TEXT]


func _research_node_state(recipe: String) -> Dictionary:   # one node of the development tree, as the RESEARCH view draws it
	var job: Dictionary = research_job.get(PLAYER, {})
	var out := {"state": "locked", "progress": 0.0, "line": ""}
	if _known(PLAYER, recipe):
		out.state = "known"; out.line = "Known"
	elif str(job.get("key", "")) == recipe:
		out.progress = clampf(float(job.progress) / maxf(0.001, _research_time(recipe)), 0.0, 1.0)
		var paused := bool(job.get("paused", false))
		var stalled := not paused and _research_stall(PLAYER) != ""
		out.state = "paused" if paused else ("stalled" if stalled else "working")
		out.line = ("Paused %d%%" if paused else ("Stalled %d%%" if stalled else "Researching %d%%")) % int(float(out.progress) * 100)
	elif _can_research(PLAYER, recipe) == "":
		out.state = "open"; out.line = "Open · %d s" % int(_research_time(recipe))
	else:
		out.line = "Needs %s" % str(CARDS[str(RESEARCH[recipe].prereq)].get("short", ""))
	return out


func _research_node_click(recipe: String) -> void:   # a click selects the blueprint; its action is in the row above the tree
	if menu_open or won or lost: return
	_research_sel = recipe
	_update_card_banks()


func _research_action(recipe: String) -> Array:   # [button text, enabled, command or ""] for the selected blueprint
	if recipe == "" or not CARDS.has(recipe): return ["Select a blueprint", false, ""]
	if _known(PLAYER, recipe): return ["Open its recipes", true, "open"]
	var job: Dictionary = research_job.get(PLAYER, {})
	if str(job.get("key", "")) == recipe: return ["Resume" if bool(job.get("paused", false)) else "Pause", true, "research"]
	var why := _can_research(PLAYER, recipe)
	if why != "": return ["Locked", false, ""]
	return ["Research" if job.is_empty() else "Research instead", true, "research"]


func _research_act() -> void:   # the RESEARCH view's action button
	var act := _research_action(_research_sel)
	if not bool(act[1]): return
	if str(act[2]) == "open": _open_drawer(str(CARDS[_research_sel].bank))
	else: _cmd(["research", _research_sel])
	_update_card_banks()


func _research_tooltip(recipe: String) -> String:
	var t := _card_tooltip(recipe)
	if RESEARCH.has(recipe):
		var c := _research_cost(recipe)
		var parts := []
		for r in RES:
			if float(c.get(r, 0.0)) > 0.0: parts.append("%d %s" % [int(c[r]), RES_NAME[r]])
		t += "\n\nResearch: %s, %d s. Needs %s. Click to select it." % [", ".join(parts), int(_research_time(recipe)), str(CARDS[str(RESEARCH[recipe].prereq)].name)]
	else:
		t += "\n\nKnown from the start."
	return t


func _style_bank_tab(button: Button, bank: String, look: String) -> void:   # a drawer tab in its colour, filled while its view shows
	var col: Color = _tab_col(bank)
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


# ---- the cards area: an always-visible strip (manufacturing lanes · ready cards · the cards button) and a drawer above it ----
func _drawer_h() -> float: return CARD_DOCK_HEIGHT + (RESEARCH_INFO_H + 6.0 if _card_bank == "research" else 0.0)


func _deck_top() -> float:   # the top edge of everything the strip and the drawer cover right now
	var top := get_viewport_rect().size.y - 12.0 - DECK_BAR_HEIGHT
	if _deck_open: top -= DECK_GAP + _drawer_h() + DECK_GAP + DECK_BAR_HEIGHT
	return top


func _layout_deck() -> void:
	if hand_panel == null or card_banks == null or lane_strip == null or deck_handle == null: return
	var sz := get_viewport_rect().size
	var playing := not menu_open and not won and not lost
	var strip_y := sz.y - 12.0 - DECK_BAR_HEIGHT
	var head_y := _deck_top()
	var open := playing and _deck_open
	hand_panel.position = Vector2(24, head_y + DECK_BAR_HEIGHT + DECK_GAP)
	hand_panel.size = Vector2(sz.x - 48, _drawer_h())
	hand_panel.visible = open
	card_banks.position = Vector2(24, head_y); card_banks.size = card_banks.get_combined_minimum_size()
	card_banks.visible = open
	drawer_close.size = drawer_close.custom_minimum_size
	drawer_close.position = Vector2(sz.x - 24 - drawer_close.size.x, head_y); drawer_close.visible = open
	var mid_left := card_banks.position.x + card_banks.size.x + 16.0
	var mid_room := drawer_close.position.x - 16.0 - mid_left
	research_status.position = Vector2(mid_left, head_y); research_status.size = Vector2(maxf(40.0, mid_room), DECK_BAR_HEIGHT)
	if deck_pager != null:
		deck_pager.size = deck_pager.get_combined_minimum_size()
		deck_pager.position = Vector2(mid_left + floorf((mid_room - deck_pager.size.x) * 0.5), head_y)
	deck_handle.size = deck_handle.custom_minimum_size
	deck_handle.position = Vector2(sz.x - 24 - deck_handle.size.x, strip_y)
	deck_handle.visible = playing
	lane_strip.position = Vector2(24, strip_y); lane_strip.size = lane_strip.get_combined_minimum_size()
	lane_strip.visible = playing
	# the ready cards: fixed-size chips from the lanes to the handle; what does not fit goes behind "+n"
	var left := lane_strip.position.x + lane_strip.size.x + 16.0
	var room := deck_handle.position.x - 12.0 - left
	var list := _ready_list()
	var step := READY_CHIP_W + 6.0
	var fit := maxi(0, int((room + 6.0) / step))
	var shown := list
	if list.size() > fit: shown = list.slice(0, maxi(0, int((room + 6.0 - ready_more.custom_minimum_size.x - 6.0) / step)))
	for chip in ready_strip.get_children():
		if chip == ready_more: continue
		chip.visible = shown.has(_card_of(str(chip.key)))
	ready_more.visible = shown.size() < list.size()
	ready_more.text = "+%d" % (list.size() - shown.size())
	ready_strip.position = Vector2(left, strip_y); ready_strip.size = ready_strip.get_combined_minimum_size()
	ready_strip.visible = playing and not list.is_empty()
	ready_empty.position = Vector2(left, strip_y); ready_empty.size = Vector2(maxf(40.0, room), DECK_BAR_HEIGHT)
	ready_empty.visible = playing and list.is_empty()
	_update_card_banks(false)


func _set_deck_open(open: bool) -> void:
	_deck_drag_restore = false
	if open == _deck_open: return
	_deck_open = open
	if open and not sel.is_empty():   # the drawer and your host's build menu share the right side: the drawer wins, no scrolling menu
		if sel.size() == 1: _inspect = -1
		sel = {}
		_refresh_panel()
	_layout_ui()
	if open: _keep_target_visible()


func _open_drawer(bank: String) -> void:   # the drawer on this view (from the strip, the Research button, a tab)
	if bank != _card_bank: _deck_page = 0
	_card_bank = bank
	if _deck_open: _layout_ui()
	else: _set_deck_open(true)


func _toggle_research() -> void:   # the top bar's Research button (R)
	if _deck_open and _card_bank == "research": _set_deck_open(false)
	else: _open_drawer("research")


func _bank_pressed(bank: String) -> void:   # a drawer tab: switch to its view (the open one closes the drawer)
	_bank_alert.erase(bank)
	if _deck_open and bank == _card_bank: _set_deck_open(false); return
	_open_drawer(bank)


const SELECT_COL := Color(0.45, 0.85, 1.0)   # a selected blueprint or ready card: never used for a state
const SIPHON_RES := ["intel", "cash", "creds", "research"]


func _draw_ready_face(c: Control, key: String, big: bool) -> void:   # a ready card in the strip (small) or the drawer (big)
	var f := c.get_theme_default_font()
	var recipe := _card_of(key)
	var card: Dictionary = CARDS[recipe]
	var bank: Color = BANK_COL[str(card.bank)]
	var fam: Color = FAMILY_COL[str(card.fam)]
	var picked := _armed == recipe
	var hot := Rect2(Vector2.ZERO, c.size).has_point(c.get_local_mouse_position())
	var fill := Color(0.06, 0.13, 0.17) if picked else Color(0.055, 0.075, 0.105)
	if hot: fill = fill.lightened(0.06)
	c.draw_rect(Rect2(Vector2.ZERO, c.size), fill)
	c.draw_rect(Rect2(1, 1, c.size.x - 2, c.size.y - 2), bank, false, 1)
	if picked:
		c.draw_rect(Rect2(0, 0, c.size.x, 4), SELECT_COL)
		c.draw_rect(Rect2(1, 1, c.size.x - 2, c.size.y - 2), SELECT_COL, false, 2)
	var n := _held(PLAYER, recipe)
	if not big:
		_draw_card_glyph(c, recipe, Vector2(18, c.size.y * 0.5), 24, Color.WHITE, f)
		_text(c, f, Vector2(34, 17), str(card.short), 12, C_TEXT, c.size.x - 40, HORIZONTAL_ALIGNMENT_LEFT)
		var line := "×%d" % n
		if str(card.effect) == "siphon": line += " · " + str({"intel": "Intel", "cash": "Crypto", "creds": "Creds", "research": "Res."}[_chosen_siphon_res])
		_text(c, f, Vector2(34, 33), line, 11, SELECT_COL if picked else bank.lightened(0.3), c.size.x - 40, HORIZONTAL_ALIGNMENT_LEFT)
		return
	c.draw_rect(Rect2(6, 8, c.size.x - 12, 26), fam.darkened(0.8))
	_text(c, f, Vector2(12, 27), str(card.name), 15, C_TEXT, c.size.x - 24, HORIZONTAL_ALIGNMENT_LEFT)
	c.draw_rect(Rect2(12, 42, 44, 44), fam.darkened(0.9))
	_draw_card_glyph(c, recipe, Vector2(34, 64), 38, fam, f)
	_text(c, f, Vector2(66, 62), "×%d ready" % n, 18, C_TEXT, c.size.x - 74, HORIZONTAL_ALIGNMENT_LEFT)
	var target := "To a host of yours" if _is_defense(recipe) else "To a foreign host"
	_text(c, f, Vector2(66, 82), "Selected: click a host" if picked else target, 11, SELECT_COL if picked else C_DIM, c.size.x - 74, HORIZONTAL_ALIGNMENT_LEFT)
	if str(card.effect) != "siphon":   # what it does, in two lines at most (the tooltip has the rules)
		var lines := _wrap_text(f, str(card.get("lead", "")), 11, c.size.x - 24.0)
		for k in mini(2, lines.size()): _text(c, f, Vector2(12, 102 + 14 * k), str(lines[k]), 11, C_DIM, c.size.x - 24, HORIZONTAL_ALIGNMENT_LEFT)


func _arm_card(key: String) -> void:   # click a ready card: select it (again: unselect). The drawer gets out of the way of the map.
	if menu_open or won or lost: return
	var recipe := _card_of(key)
	if _armed == recipe: _armed = ""
	elif _held(PLAYER, recipe) > 0:
		_armed = recipe
		if _deck_open: _set_deck_open(false)
	_update_card_banks(); queue_redraw()


func _aimed_card() -> String:   # the card being aimed: dragged right now, or selected and waiting for a click on a host
	var d := _dragged_card()
	return d if d != "" else _armed


func _launch_armed(t: int) -> bool:   # a click on a host while a card is selected: launch it there if it may go
	if _armed == "" or t < 0: return false
	var why := _can_play(PLAYER, _armed, t)
	if why != "":
		_flash("%s cannot go to %s: %s" % [str(CARDS[_armed].name), str(hosts[t].name), why]); return true
	_cmd(["card", _armed, t, _chosen_siphon_res])
	_armed = ""
	_update_card_banks()
	return true


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


# Card widget bridge: a recipe's "+ Queue" appends one copy (never pauses one); the queue and the ready inventory are
# shown apart. _mq_count is how many copies of a recipe are queued (the head included).
var _cid_next := 0


func _mq_count(fac: int, recipe: String) -> int:
	var n := 0
	for j in _mq(fac):
		if str(j.recipe) == recipe: n += 1
	return n


func _enqueue(key: String) -> void:   # the explicit + Queue action
	if menu_open or won or lost: return
	_cid_next += 1
	_cmd(["queue", _card_of(key), _cid_next])


func _card_research_click(key: String) -> void: _recipe_act(key)   # a recipe tile's action: + Queue, or Research when locked


func _recipe_action(key: String) -> Array:   # [label, enabled, tooltip] for a recipe tile's one button
	var recipe := _card_of(key)
	if not _known(PLAYER, recipe):
		var why := _can_research(PLAYER, recipe)
		if str(research_job.get(PLAYER, {}).get("key", "")) == recipe: return ["Research", true, "Being researched: open Research to pause or follow it."]
		return ["Research", true, "Learn the blueprint first: opens Research with it selected." + ("" if why == "" else " (%s)" % why)]
	if _mq(PLAYER).size() >= QUEUE_SIZE: return ["+ Queue", false, "The queue is full: %d copies, the one being made included." % QUEUE_SIZE]
	return ["+ Queue", true, "Add one copy to the back of the manufacturing queue. It pays when it starts: %s." % _res_list(_recipe_cost(recipe))]


func _recipe_act(key: String) -> void:
	var recipe := _card_of(key)
	if not _known(PLAYER, recipe):
		_open_drawer("research"); _research_node_click(recipe)
		return
	_enqueue(key)


func _recipe_hint(key: String) -> String:   # "2 queued · 1 ready"
	var recipe := _card_of(key)
	if not _known(PLAYER, recipe): return "Blueprint not learned"
	var parts := []
	var n := _mq_count(PLAYER, recipe)
	if n > 0: parts.append("%d queued" % n)
	parts.append("%d ready" % _held(PLAYER, recipe))
	return " · ".join(parts)


func _card_research_cancel(key: String) -> void:   # remove the newest queued copy of this recipe
	var q := _mq(PLAYER)
	for k in range(q.size() - 1, -1, -1):
		if str(q[k].recipe) == _card_of(key): _cmd(["unqueue", int(q[k].id)]); return


func _card_research_state(key: String) -> Dictionary:   # a recipe's view: copies ready, queued, and its place in the queue
	var recipe := _card_of(key)
	var count := _held(PLAYER, recipe)
	var result := {"count": count, "status": "Ready" if count > 0 else "Idle", "progress": 0.0, "queued": false, "n": _mq_count(PLAYER, recipe)}
	if not _known(PLAYER, recipe):
		var job: Dictionary = research_job.get(PLAYER, {})
		result.status = ("Paused" if bool(job.paused) else "Researching") if str(job.get("key", "")) == recipe else "Locked"
		if str(job.get("key", "")) == recipe: result.progress = clampf(float(job.progress) / maxf(0.001, _research_time(recipe)), 0.0, 1.0)
		return result
	var q := _mq(PLAYER)
	if not q.is_empty() and str(q[0].recipe) == recipe:
		result.queued = true
		if not (q[0].paid as Dictionary).is_empty():
			result.progress = clampf(float(q[0].progress) / maxf(0.001, _make_time(recipe)), 0.0, 1.0)
			result.status = "Paused" if bool(mq_paused.get(PLAYER, false)) else "Making"
		else: result.status = "Waiting"
	elif int(result.n) > 0: result.queued = true; result.status = "Queued"
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
		if _armed != "" and not moved:   # a card is selected: a click on a host launches it there, a click elsewhere unselects it
			_panning = false; _boxing = false; _drag_from = -1; _dragging = false
			if hit >= 0: _launch_armed(hit)
			else: _armed = ""; _update_card_banks()
			_refresh_panel(); queue_redraw(); return
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
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _armed != "":   # right-click: unselect the card
		_armed = ""; _update_card_banks(); queue_redraw(); return
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
		if _deck_open and _armed == "": _set_deck_open(false)   # its build panel gets the full height: no scrolling to build
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


# screen <-> world (map zoom/pan). Node positions are WORLD; mouse events are SCREEN.
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




func _owned_feeders(_node: int) -> Array: return []   # legacy: no wired feeders in this model


func _cancel_to(_dest: int) -> void: pass


func _cmd(c: Array) -> void:
	if _camp_paused: _camp_set_pause(false)
	if not _mp_on: _apply_cmd(PLAYER, c); return
	if _out or won or lost: return
	_mp_queue.append(c)


func _apply_cmd(fac: int, c: Array) -> void:
	if c.is_empty() or not botnets.has(fac) or _eliminated.has(fac): return
	_fc_gen += 1
	_logi_poke()
	var n := c.size()
	match str(c[0]):
		"build": if n == 4: _do_build(fac, _int(c[1]), _int(c[2]), str(c[3]))
		"job": if n == 3: _do_toggle_job(fac, _int(c[1]), _int(c[2]))
		"cancel": if n == 3: _do_cancel_job(fac, _int(c[1]), _int(c[2]))
		"demolish": if n == 3: _do_demolish(fac, _int(c[1]), _int(c[2]))
		"produce": if n == 3: _do_produce(fac, _int(c[1]), _int(c[2]))
		"research": if n == 2: _do_research(fac, str(c[1]))
		"cancel_research": if n == 1: _cancel_research(fac)
		"queue": if n >= 2: _mq_add(fac, str(c[1]), _int(c[2]) if n >= 3 else -1)
		"unqueue": if n == 2: _mq_remove(fac, _int(c[1]))
		"queue_pause": if n == 1: _mq_toggle_pause(fac)
		"card": if n >= 3 and _host_ok(_int(c[2])) and str(c[1]) != "": _play_card(fac, str(c[1]), _int(c[2]), str(c[3]) if n >= 4 else "")


func _int(v: Variant) -> int:   # a JSON number (or anything else) as a building / slot index; garbage becomes -1
	return int(v) if (v is int or v is float) and is_finite(float(v)) else -1


func _host_ok(i: int) -> bool: return i >= 0 and i < hosts.size()
func _owns(fac: int, i: int) -> bool: return _host_ok(i) and int(hosts[i].owner) == fac


func _apply_options() -> void:   # turn the menu choices into the live grid + faction set + seed
	_cols = _opt_size.x; _rows = _opt_size.y
	if _camp: _layout = "grid"   # the campaign's chapters are authored on its grid
	elif _mp_on: _layout = GALAXIES[maxi(0, _opt_seed) % GALAXIES.size()]   # every lockstep screen must build the same town: the seed picks the galaxy
	else: _layout = _opt_shape if SHAPES.has(_opt_shape) else ""   # "" = chosen from the seed in _gen, once the seed is known
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
	_camp = false; _camp_paused = false; _camp_chapter = 0; _camp_clock = 0.0; _camp_replay = false; _camp_banner_gone = false; _camp_open_t = -1.0
	_camp_supplied = {}; _camp_events = {}; _camp_cash_landed = 0; _camp_cancelled = false; _camp_src = -1
	_camp_home = -1; _camp_support = -1; _camp_relay = -1; _camp_gateway = -1; _camp_rivalhq = -1; _camp_practice = -1; _camp_practice2 = -1; _camp_guard = -1; _camp_result = ""; _camp_result_at = -100.0
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


var _compact_font: FontVariation   # the UI face without the symbol fallback, whose tall metrics would make every line 29 px
func _compact(txt: String) -> Font:   # null when the text needs a glyph only the symbol fallback has
	if _compact_font == null:
		_compact_font = FontVariation.new(); _compact_font.base_font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	for k in txt.length():
		var c := txt.unicode_at(k)
		if c > 127 and not _compact_font.has_char(c): return null
	return _compact_font


func _lbl(parent: Control, txt: String, sz: int, col: Color, minw: float) -> Label:
	var l := Label.new(); l.text = txt
	var cf := _compact(txt)
	if cf != null: l.add_theme_font_override("font", cf)
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
	if logs_button != null: logs_button.visible = not open
	if open and panel != null: panel.visible = false
	if tut_panel != null: tut_panel.visible = _banner_on() and not open   # the tutorial prompt hides under the menu
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


var _menu_w := MENU_W
var _menu_fill := false   # the view takes the whole window height (the multiplayer views)


func _size_menu(w: float, fill := false) -> void:   # a view's width; the height follows what it holds (_layout_menu)
	if menu_panel == null: return
	_menu_w = minf(w, get_viewport_rect().size.x - 2.0 * MENU_MARGIN)
	_menu_fill = fill
	if menu_box != null: menu_box.custom_minimum_size.x = _menu_w - 2.0 * MENU_PAD
	_layout_menu()


func _layout_menu() -> void:   # one rule for every view: MENU_PAD all round, the height of the content, scrolling past the window
	if menu_panel == null or menu_sc == null or menu_box == null: return
	var vp := get_viewport_rect().size
	var content := menu_box.get_combined_minimum_size().y
	var maxh := vp.y - 2.0 * MENU_MARGIN
	var h := maxh if _menu_fill else minf(content + 2.0 * MENU_PAD, maxh)
	var scrolls := content > h - 2.0 * MENU_PAD + 0.5
	menu_panel.size = Vector2(_menu_w, h)
	menu_panel.position = ((vp - menu_panel.size) * 0.5).floor()
	# the scrollbar, when there is one, sits in the right-hand inset: the content keeps the same width either way
	var bar := menu_sc.get_v_scroll_bar().get_combined_minimum_size().x if scrolls else 0.0
	menu_sc.position = Vector2(MENU_PAD, MENU_PAD)
	menu_sc.size = Vector2(_menu_w - 2.0 * MENU_PAD + bar, h - 2.0 * MENU_PAD)


func _refresh_menu() -> void:
	if menu_box == null: return
	if is_instance_valid(fb_details): _fb_draft.details = fb_details.text
	if is_instance_valid(fb_version): _fb_draft.version = fb_version.text
	if is_instance_valid(fb_name): _fb_draft.name = fb_name.text
	fb_details = null; fb_version = null; fb_name = null
	for c in menu_box.get_children(): menu_box.remove_child(c); c.queue_free()
	if is_instance_valid(menu_seed_edit): _seed_draft = menu_seed_edit.text
	menu_seed_edit = null
	if _menu_view != _menu_shown_view: menu_sc.scroll_vertical = 0   # a new view starts at its top
	_menu_shown_view = _menu_view
	menu_box.add_theme_constant_override("separation", 6 if _menu_view == "newgame" else 10)   # newgame packs the most rows; keep it inside the window
	match _menu_view:
		"help": _size_menu(680.0); _menu_help()
		"newgame": _size_menu(MENU_W); _menu_newgame()
		"campaign": _size_menu(MENU_W + 96.0); _menu_campaign()   # its lesson buttons are the widest menu rows
		"feedback": _size_menu(480.0); _menu_feedback()
		"mp", "lobby":   # the whole window (minus a margin), in two columns; reachable only by a direct call while Multiplayer is hidden
			_size_menu(maxf(560.0, get_viewport_rect().size.x - 2.0 * MENU_MARGIN), true)
			if _menu_view == "mp": _menu_mp()
			else: _menu_lobby()
		_: _size_menu(MENU_W); _menu_main()
	_layout_menu()


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
	for f in flights: parts.append("%d:%d:%d:%d:%s:%s:%s" % [int(f.id), int(f.get("hop_i", 0)), int(f.get("dest", -1)), int(f.get("wid", -1)), str(f.get("trip", "")), JSON.stringify(f.get("cargo", {})), JSON.stringify(f.get("job", {}))])
	var wids := workers.keys(); wids.sort()
	for wid in wids: parts.append("w%d:%d:%d:%d:%s:%d" % [int(wid), int(workers[wid].home), int(workers[wid].get("base", -1)), int(workers[wid].gen), str(workers[wid].state), int(workers[wid].fid)])
	var turns := _pool_turn.keys(); turns.sort()
	for k in turns: parts.append("t%s=%d" % [str(k), int(_pool_turn[k])])
	var sf := _served.keys(); sf.sort()
	for fac in sf:
		var hs: Array = (_served[fac] as Dictionary).keys(); hs.sort()
		parts.append("s%d=%d:%s" % [int(fac), int(_serve_n.get(fac, 0)), ",".join(PackedStringArray(hs.map(func(h): return "%d/%d" % [int(h), int(_served[fac][h])])))])
	var sr := _served_res.keys(); sr.sort()
	for fac in sr:
		var hs2: Array = (_served_res[fac] as Dictionary).keys(); hs2.sort()
		for h in hs2:
			var rs: Array = (_served_res[fac][h] as Dictionary).keys(); rs.sort()
			parts.append("r%d:%d:%s" % [int(fac), int(h), ",".join(PackedStringArray(rs.map(func(x): return "%s/%d" % [str(x), int(_served_res[fac][h][x])])))])
	for h in hosts:
		parts.append("%d,%d,%s,%s,%s,%s,%d,%d" % [int(h.owner), int(h.gen), ",".join(PackedStringArray(h.builds)), JSON.stringify(h.jobs), JSON.stringify(h.store), ",".join(PackedStringArray(h.sockets)), int(h.fw_on), int(round(float(h.cyc) * 30.0))])
		parts.append("%d,%d,%d,%d,%d" % [roundi(float(h.get("ddos_until", 0.0)) * 100.0), roundi(float(h.get("sabot_until", 0.0)) * 100.0), int(h.get("steal_by", -1)), roundi(float(h.get("steal_until", 0.0)) * 100.0), roundi(float(h.get("express_until", 0.0)) * 100.0)])
		parts.append("%s|%s|%s|%s|%d" % [JSON.stringify(h.get("teams", {})), JSON.stringify(h.get("claim", {})), JSON.stringify(h.get("inbound", {})), JSON.stringify(h.get("loot", {})), int(h.get("plan_rr", 0))])
	for fac in botnets:
		for res in RES: parts.append(str(roundi(_avail(fac, res) * 1000.0)))
		parts.append(JSON.stringify(_reqs.get(fac, {})))
		parts.append(JSON.stringify(incoming.get(fac, {})) + JSON.stringify(cards[fac]) + JSON.stringify(known.get(fac, {})) + JSON.stringify(research_job.get(fac, {})) + JSON.stringify(mq.get(fac, [])) + str(mq_paused.get(fac, false)))
		var rec: Dictionary = recon.get(fac, {})
		for t in rec: parts.append("r%d:%d:%d" % [int(t), roundi(float(rec[t].get("at", 0.0)) * 30.0), int(rec[t].get("gen", 0))])
	parts.append(str(sim_rng.state))   # the dice: two screens that rolled differently have drifted
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


func _menu_main() -> void:   # navigation only. Learn and Skirmish are both open from the first run.
	# Multiplayer is hidden for now: its lockstep backend and tests stay (_mp_open, botnet_net.gd).
	_menu_title("RIM")
	if (_t >= 0.01 or _camp or _tut) and not won and not lost: _mbtn("Resume", func(): _open_menu(false))   # a Learn session paused at _t==0 still resumes
	if _mp_on:
		_mbtn("Leave match", _mp_leave)
	else:
		if not _camp or won or lost: _mbtn("Learn", func(): _menu_go("campaign"))   # a live Learn session is continued with Resume above
		_mbtn("Skirmish", func(): _menu_go("newgame"))
	_mbtn("Help", func(): _help_page = 0; _menu_view = "help"; _refresh_menu())
	_mbtn("Feedback", func(): _fb_status = ""; _menu_view = "feedback"; _refresh_menu())
	_mbtn("Exit", func(): get_tree().quit())


func _menu_go(view: String) -> void: _menu_view = view; _refresh_menu()


func _menu_campaign() -> void:
	_menu_title("Learn")
	var save := _camp_load()
	var cc = save.get("chapters_completed", [])
	if cc is Array and (cc as Array).size() == CAMP_CHAPTERS:
		for k in CAMP_CHAPTERS: _camp_done[k] = bool((cc as Array)[k])
	var titles := _camp_chapters()
	var started := int(save.get("chapter", 0)) > 0 or int(save.get("step", 0)) > 0
	if bool(save.get("completed", false)) or not started: _mbtn("Start", func(): _camp_resume_or_start(0))
	else:
		_mbtn("Continue — %d. %s" % [int(save.get("chapter", 0)) + 1, titles[int(save.get("chapter", 0))]], func(): _camp_resume_or_start())
		_menu_label("Continue restarts that lesson with what the earlier lessons had you do.")
	for ch in CAMP_CHAPTERS:
		var unlocked: bool = ch == 0 or _camp_done[ch - 1] or bool(save.get("completed", false))
		var b := _mbtn_icon("%d. %s" % [ch + 1, titles[ch]], "check" if _camp_done[ch] else ("play" if unlocked else "lock"), func(c = ch): _camp_resume_or_start(c))
		b.disabled = not unlocked
		b.tooltip_text = "Finish the lesson before it to open this one." if not unlocked else ""
	_mbtn("← Back", func(): _menu_view = "main"; _refresh_menu())


func _mbtn_icon(txt: String, icon: String, cb: Callable) -> Button:   # a full-width menu button led by a bundled vector icon
	_mbtn(txt, cb)
	var b := menu_box.get_child(menu_box.get_child_count() - 1) as Button
	b.icon = UiIcons.texture(icon, 16); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("h_separation", 10)
	return b


func _menu_newgame() -> void:
	_menu_title("Skirmish")
	_menu_label("Map  ·  %d × %d" % [_opt_size.x, _opt_size.y])   # the layout is the seed's: there is no layout option
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
		var b := Button.new(); b.text = str(n); b.icon = UiIcons.texture("star", 14); b.custom_minimum_size = Vector2(0, 36); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.focus_mode = Control.FOCUS_ALL
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
	_mbtn("Submit", _submit_feedback)
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
		{"title": "Your main node", "text": "Your main node makes one of each resource every 12 seconds. What other hosts make is used there first; workers carry the surplus home."},
		{"title": "Manufacture", "text": "Open the recipes (C) and click + Queue to make a copy, then drag the ready card onto a target to launch it."},
		{"title": "Win", "text": "Hold at least 51% of the hosts for 51 seconds, or be the last network with its main node."},
	]


# Tutorial keywords take the colour of the thing they name: buildings their card colour, ATTACK things red, DEFENCE blue,
# your own pieces green, the target and the win numbers gold. Longest phrases first; placeholders stop nested matches.
# Training-text vocabulary: term -> colour/icon source. Whole words, case-sensitive, longest match wins, ONE regex pass
# (no placeholder round trip, so text like "30 Crypto" or "0day" can never be corrupted). "" = leave the word as typed.
const RICH_TERMS := {
	# installations: their building-card colour + pictogram
	"Intel harvester": "kind:intel", "Crypto miner": "kind:cash", "Bot station": "kind:bot", "Bot stations": "kind:bot",
	"Credential harvester": "kind:cred", "Research lab": "kind:lab", "Firewall": "kind:wall", "stations": "tint:bot",
	# resources: the HUD's colour + pictogram
	"Intel": "kind:intel", "Crypto": "kind:cash", "Credentials": "kind:cred", "Creds": "kind:cred", "Research": "kind:lab",
	"bots": "kind:bot", "defenders": "tint:bot",
	# cards: the deck tab's colour (ATTACK red / DEFENCE blue) + the card art
	"Recon": "card:recon", "Credential breach": "card:breach", "Known exploit": "card:exploit", "Phishing": "card:phish",
	"Packet siphon": "card:siphon", "Vault raid": "card:vault", "DDoS": "card:ddos", "0day": "card:zeroday",
	"Worm": "card:worm", "Supply-chain sabotage": "card:sabotage", "Patch": "card:patch", "Incident response": "card:response",
	"Traffic filter": "card:filter", "Cargo cover": "card:cover", "Express route": "card:express",
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
	return ["Scout and capture", "Build and deliver", "Research and manufacture", "Steal, protect, recover", "Run the network"]


# t title · a the instruction · r what it did · pause: the game waits only where the action is available at once ·
# ui: the control(s) to cue · card: an operation the step launches (cue stops on the accepted launch; the step ends on the result)
func _camp_steps(chapter: int) -> Array:
	match chapter:
		0: return [
			{"t": "Your main node", "r": "Your main node's stock is what pays for cards and research; its Bot station's 2 workers carry for it.", "a": "Select YOUR MAIN NODE: its stock is the top bar, and its Bot station gives it 2 workers.", "role": "home", "pause": true},
			{"t": "Scout", "r": "Recon revealed the relay: what it is, its slots and its storage.", "a": "Drag Recon onto the Neighborhood Relay. It gets through half the time.", "role": "relay", "ui": "card:recon", "card": "recon", "pause": true},
			{"t": "Manufacture a card", "r": "A Credential breach copy is in the queue.", "a": "Press C, open Attack recipes and click + Queue on Credential breach.", "role": "", "ui": "card:breach", "pause": true},
			{"t": "Capture", "r": "The Neighborhood Relay is yours.", "a": "When the copy is ready, drag the Credential breach onto the Neighborhood Relay.", "role": "relay", "ui": "card:breach", "card": "breach", "pause": false},
		]
		1: return [
			{"t": "A building far from home", "r": "The Bot station is built: 2 more workers join your pool at the main node.", "a": "Drag a Bot station onto a free relay slot: its materials travel there before work starts.", "role": "relay", "ui": "build:bot", "pause": true},
			{"t": "Local use first", "r": "The Miner uses the relay's own Intel first.", "a": "Build an Intel harvester and a Crypto miner on the relay.", "role": "relay", "ui": ["build:intel", "build:cash"], "pause": true},
			{"t": "Surplus goes home", "r": "Crypto made on the relay reached your main node.", "a": "Watch: your workers carry the relay's spare Intel and Crypto to your main node.", "role": "relay", "pause": false},
		]
		2: return [
			{"t": "Research a blueprint", "r": "Known exploit is learned.", "a": "Open Research (R), select Known exploit, then Research; the bar at the top shows progress.", "role": "", "ui": "card:exploit", "pause": true},
			{"t": "Queue two copies", "r": "Copies are made one at a time, in order.", "a": "In Attack recipes, click + Queue on Known exploit twice.", "role": "", "ui": "card:exploit", "copies": 2, "pause": false},
			{"t": "Scout the gateway", "r": "The gateway is scouted.", "a": "Drag Recon onto the Corporate Gateway.", "role": "gateway", "ui": "card:recon", "card": "recon", "pause": false},
			{"t": "Launch the ready copy", "r": "The Corporate Gateway is yours.", "a": "Launch the ready Known exploit at the Corporate Gateway.", "role": "gateway", "ui": "card:exploit", "card": "exploit", "pause": false},
			{"t": "A Miner far from Intel", "r": "The gateway's Miner is built.", "a": "Build a Crypto miner on the gateway. No Intel is made there.", "role": "gateway", "ui": "build:cash", "pause": true},
			{"t": "Missing inputs are fetched", "r": "Crypto from the gateway reached your main node.", "a": "Watch: your workers bring Intel to the gateway's Miner, and its Crypto comes home.", "role": "gateway", "pause": false},
		]
		3: return [
			{"t": "Scout the target", "r": "The Practice host is scouted.", "a": "Drag Recon onto the Practice host.", "role": "practice", "ui": "card:recon", "card": "recon", "pause": true},
			{"t": "Steal production", "r": "The Practice host's output now flows to you.", "a": "Launch Phishing on the Practice host.", "role": "practice", "ui": "card:phish", "card": "phish", "pause": false},
			{"t": "Protect", "r": "The theft on your relay is cleared.", "a": "Send Incident response to the Neighborhood Relay: it acts when it arrives.", "role": "relay", "ui": "card:response", "card": "response", "pause": false, "fire": "ch4_phish"},
			{"t": "Losses", "r": "A new Bot station is on order: its 2 workers start when it is built.", "a": "NYX took your Outpost: its 2 workers died with it. Order a Bot station on a host of yours.", "role": "", "ui": "build:bot", "fire": "ch4_outpost", "pause": true},
		]
		_: return [
			{"t": "Your move", "r": "Victory.", "a": "Win the district: hold a majority, or take the rival main node.", "role": "", "pause": false},
		]


func _camp_role_host(role: String) -> int:
	match role:
		"home": return _camp_home
		"relay", "income": return _camp_relay
		"gateway", "frontier": return _camp_gateway
		"practice": return _camp_practice
		"practice2", "outpost": return _camp_practice2
		"support": return _camp_support
	return -1


func _camp_target() -> int:
	if not _camp: return -1
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


func _camp_ui_targets() -> Array:   # the live Controls the step names (a deck card, a build card, a button), re-found each frame
	var st := _camp_step()
	if st.is_empty() or menu_open or won or lost: return []
	var specs = st.get("ui", [])
	if specs is String: specs = [specs]
	var out := []
	for spec in specs:
		var p := str(spec).split(":", true, 1)
		match p[0]:
			"card": if p.size() == 2: out.append_array(_camp_card_ctrls(p[1]))
			"build":
				if p.size() == 2:
					var c := _camp_build_ctrls(p[1])
					out.append_array(c)
					if not c.is_empty(): break   # one building at a time
	return out


func _camp_op_active(recipe: String, t: int) -> bool:   # your matching operation is on its way to t, or executing there
	for f in flights:
		if str(f.kind) == "op" and int(f.owner) == PLAYER and str(f.get("card", "")) == recipe and not bool(f.get("returning", false)) and int(f.get("target", f.get("dest", -1))) == t: return true
	for e in _execs:
		if int(e.fac) == PLAYER and str(e.card) == recipe and int(e.target) == t: return true
	return false


func _camp_card_ctrls(recipe: String) -> Array:   # where the step's card is: its research node, its recipe, or the ready copy to use
	var st := _camp_step()
	var launch := str(st.get("card", "")) == recipe   # this step launches it (else it makes or learns it)
	if not _known(PLAYER, recipe):   # still to research: the Research button, then its node in the tree and the action
		if str((research_job.get(PLAYER, {}) as Dictionary).get("key", "")) == recipe: return []   # accepted: the research bar shows it
		if not _deck_open or _card_bank != "research": return [research_button]
		if _research_sel != recipe: return research_tree.get_children().filter(func(c): return str(c.get("recipe")) == recipe)
		return [research_info]
	if launch and _camp_op_active(recipe, _camp_target()): return []   # accepted launch: it travels or executes; no second copy is asked for
	if not launch:   # a making step: its copies are queued or ready, so nothing more to click
		if _held(PLAYER, recipe) + _mq_count(PLAYER, recipe) >= int(st.get("copies", 1)): return []
	elif _held(PLAYER, recipe) == 0 and _mq_count(PLAYER, recipe) > 0: return []   # being made: it waits for the copy, not for another order
	if launch and _held(PLAYER, recipe) > 0:   # a copy is ready: its chip in the strip (drag it, or click it then the target)
		var chips := ready_strip.get_children().filter(func(c): return c != ready_more and _card_of(str(c.key)) == recipe and c.visible)
		return chips if not chips.is_empty() else [ready_more]
	var bank := _bank_of(recipe)   # nothing ready: make one from its recipe
	if not _deck_open: return [deck_handle]
	if bank != _card_bank: return [card_banks.get_child(DRAWER_TABS.find(bank))]
	if _deck_page_of(recipe) != _deck_page: return [deck_pager]   # the recipe is on another page: cue the pager
	var tiles := hand_bar.get_children().filter(func(c): return _card_of(str(c.key)) == recipe and c.visible)
	return tiles.map(func(t): return t.queue_button if t.queue_button != null else t)   # its + Queue button


func _camp_build_ctrls(kind: String) -> Array:   # the build card, until the order is accepted at the step's host
	var h := _camp_target()
	if h < 0: h = int(sel.keys()[0]) if sel.size() == 1 else _inspect
	if h < 0 or not _mine(h) or _camp_ordered(h, kind): return []
	var shown := int(sel.keys()[0]) if sel.size() == 1 else _inspect
	if shown != h: return []   # the map frames the host to select first
	return _panel_find(func(c): return c is BuildCard and c.kind == kind)


func _camp_ordered(i: int, kind: String) -> bool:   # installed, or a project for it at this host (waiting, paused or in work)
	if i < 0: return false
	if _count_all(i, kind) > 0: return true
	for slot in (hosts[i].jobs as Dictionary):
		if str(hosts[i].jobs[slot].get("kind", "")) == kind: return true
	return false


func _camp_status() -> String:   # what the game is still resolving for this step after your action was accepted ("" = nothing)
	var st := _camp_step()
	if st.is_empty(): return ""
	var tgt := _camp_target()
	var need := str(st.get("card", ""))
	if need != "" and tgt >= 0:
		var nm := str(CARDS[need].name)
		for e in _execs:
			if int(e.fac) == PLAYER and str(e.card) == need and int(e.target) == tgt: return "%s executing on %s: %d s left." % [nm, str(hosts[tgt].name), ceili(float(e.ends) - _t)]
		for f in flights:
			if str(f.kind) == "op" and int(f.owner) == PLAYER and str(f.get("card", "")) == need and not bool(f.get("returning", false)) and int(f.get("target", f.get("dest", -1))) == tgt:
				return "%s travelling to %s: arrives in %d s." % [nm, str(hosts[tgt].name), ceili(maxf(0.0, float(f.arrive_t) - _t))]
		for k in range(op_outcomes.size() - 1, -1, -1):   # it just failed its draw: say so, and that a new copy is in hand
			var o: Dictionary = op_outcomes[k]
			if _t - float(o.t) > 20.0: break
			if int(o.fac) == PLAYER and str(o.card) == need and int(o.target) == tgt:
				if str(o.outcome) == "missed":
					var next := "Your next copy is being made." if _held(PLAYER, need) <= 0 and _mq_count(PLAYER, need) > 0 else "Launch it again."
					return "Your %s failed: %s. %s" % [nm, _miss_why(PLAYER, tgt, need, 1 if bool(o.get("scouted", false)) else 0), next]
				break
	var specs = st.get("ui", [])
	if specs is String: specs = [specs]
	for spec in specs:
		var p := str(spec).split(":", true, 1)
		if p.size() != 2: continue
		if p[0] == "card":
			var r := p[1]
			var job: Dictionary = research_job.get(PLAYER, {})
			if str(job.get("key", "")) == r:
				var rb := _research_bar_state()
				return "Researching %s: %d%%%s." % [str(CARDS[r].name), int(float(rb.frac) * 100), "" if str(rb.state) == "active" else " (%s)" % str(rb.state)]
			if _known(PLAYER, r) and _held(PLAYER, r) == 0 and _mq_count(PLAYER, r) > 0:
				var q := _mq(PLAYER)
				var why := _mq_head_why(PLAYER)
				if not q.is_empty() and str(q[0].recipe) == r and not (q[0].paid as Dictionary).is_empty():
					return "Your order is underway: %s being made, %d%%." % [str(CARDS[r].name), int(100.0 * float(q[0].progress) / maxf(0.001, _make_time(r)))]
				return "%s is queued%s." % [str(CARDS[r].name), (": " + why) if why != "" else ""]
		elif p[0] == "build" and tgt >= 0:
			for slot in (hosts[tgt].jobs as Dictionary):
				var jb: Dictionary = hosts[tgt].jobs[slot]
				if str(jb.get("kind", "")) != p[1]: continue
				var what := str(BUILD_KINDS[p[1]].name)
				match _job_state(jb):
					"paused": return "%s is paused: click its slot to resume it." % what
					"demolishing": return "Your order is underway: clearing the slot for %s." % what
					"waiting":
						var bill := 0.0; var here := 0.0
						for r2 in (jb.bill as Dictionary): bill += float(jb.bill[r2]); here += minf(float(jb.bill[r2]), float((jb.escrow as Dictionary).get(r2, 0.0)))
						return "Your order is underway: %s materials %d of %d here; workers bring the rest, then %d s of work." % [what, int(here + 0.0001), int(bill + 0.0001), int(BUILD_TIME)]
					_: return "Your order is underway: building %s, %d s left." % [what, ceili(float(jb.left))]
	return ""


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
	for pair in [["intel", intel], ["cash", c], ["creds", k], ["research", r]]:   # (b: Bots are workers now; the stations make them)
		bank[PLAYER][str(pair[0])] = maxf(_avail(PLAYER, str(pair[0])), minf(float(pair[1]), _cap(PLAYER, str(pair[0]))))


func _camp_exec_running(recipe: String) -> bool:   # a copy already landed and is executing (its outcome is still to come)
	for e in _execs:
		if int(e.fac) == PLAYER and str(e.card) == recipe: return true
	return false


func _camp_supply(recipe: String, again := false) -> void:
	var id := "%d:%s" % [_camp_chapter, recipe]
	if _camp_supplied.get(id, false) and not again: return
	_camp_supplied[id] = true
	if not known.has(PLAYER): known[PLAYER] = {}
	known[PLAYER][recipe] = true
	cards[PLAYER][recipe] = _held(PLAYER, recipe) + 1


func _camp_slots(i: int, n: int) -> void:   # a lesson's host gets n slots (its installations stay)
	if i >= 0 and int(hosts[i].slots) < n:
		hosts[i].slots = n; hosts[i].builds = _slot_array(hosts[i].builds, n)


func _camp_ensure_builds(i: int, kinds: Array) -> void:   # catch-up only: put these kinds in free slots unless already there
	if i < 0: return
	_camp_slots(i, maxi(int(hosts[i].slots), kinds.size()))
	for kind in kinds:
		if _count_all(i, str(kind)) > 0: continue
		var slot := _free_slot(i)
		if slot >= 0: hosts[i].builds[slot] = str(kind)
	_sync_teams(i)


# Learn is ONE session on one board. A lesson's entry brings in what it is about, on top of whatever you have built;
# nothing is reset between lessons. _camp_catch_up(ch) re-creates what lesson ch had you do, and runs only when a
# session starts part-way (resume, replay), so the board matches what you would have had.
func _camp_enter(chapter: int, announce := true) -> void:
	match chapter:
		0:
			_camp_own(_camp_support)
			if _camp_support >= 0: hosts[_camp_support].name = "Support"
			if _camp_relay >= 0: hosts[_camp_relay].name = "Neighborhood Relay"
			if _camp_gateway >= 0: hosts[_camp_gateway].name = "Corporate Gateway"
			_camp_grant(20, 40, 20, 20, 10)
		1:
			_camp_slots(_camp_relay, 4)
			_camp_grant(20, 60, 20, 15, 10)
		2:
			if _camp_gateway >= 0 and int(hosts[_camp_gateway].owner) == NEUTRAL:   # a rival moves in next door
				hosts[_camp_gateway].owner = RIVAL; hosts[_camp_gateway].gen += 1; hosts[_camp_gateway].type = "server"
				if announce: _flash("NYX has taken the Corporate Gateway next to your network.", 3)
			_camp_grant(30, 80, 40, 40, 50)
		3:
			if _camp_practice >= 0 and int(hosts[_camp_practice].owner) == NEUTRAL:
				var p := _camp_practice
				hosts[p].owner = RIVAL; hosts[p].gen += 1; _camp_slots(p, 3); _set_builds(p, ["intel", "cash"]); hosts[p].name = "Practice host"
				if announce: _flash("NYX runs a Practice host with an Intel harvester and a Miner.", 3)
			if _camp_practice2 >= 0 and int(hosts[_camp_practice2].owner) == NEUTRAL:   # lesson fixture: an outpost of yours with a staffed station
				var o := _camp_practice2
				_camp_own(o); _camp_slots(o, 3); _set_builds(o, ["bot"]); hosts[o].name = "Outpost"
			_camp_grant(30, 80, 40, 40, 40)
			for recipe in ["phish", "response"]: _camp_supply(recipe)
		CAMP_OPEN:
			_ai_paused = false
			_camp_paused = false   # free play runs: only the lesson's own pause is cleared; a pause you chose stays yours
			_camp_grant(40, 80, 50, 40, 40)
	_refresh_sight()


func _camp_catch_up(chapter: int) -> void:
	match chapter:
		0: _camp_own(_camp_relay)
		1: _camp_own(_camp_relay); _camp_ensure_builds(_camp_relay, ["bot", "intel", "cash"])
		2:
			if not known.has(PLAYER): known[PLAYER] = {}
			known[PLAYER]["exploit"] = true
			_camp_own(_camp_gateway); _camp_ensure_builds(_camp_gateway, ["cash"])
		3:
			if _camp_practice2 >= 0 and _mine(_camp_practice2): _capture(_camp_practice2, RIVAL)   # the Outpost was lost


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
	_ai_paused = true
	for ch in range(_camp_chapter):   # starting part-way: the earlier lessons' conditions and what you did in them
		_camp_enter(ch, false); _camp_catch_up(ch)
	_camp_enter(_camp_chapter, false)
	_msg_t = 0.0; _msg_priority = 0
	_camp = true; _tut = true; _tut_stage = 0; _camp_replay = replay
	var steps := _camp_steps(_camp_chapter)
	_camp_paused = bool(steps[0].get("pause", false)); _camp_step_t = _camp_clock
	if str(steps[0].get("fire", "")) != "": _camp_fire(str(steps[0].fire))
	_open_menu(false); _show_tut(); _fit_view()
	if not replay: _camp_save()


func _camp_save_path() -> String:   # a test or probe (not the running game scene) writes its own per-process file, never a player's
	return CAMP_SAVE if is_inside_tree() and get_tree().current_scene == self else CAMP_SAVE_HARNESS.replace(".json", "_%d.json" % OS.get_process_id())


func _camp_save() -> void: _camp_save_at(_camp_chapter, _tut_stage)


func _camp_save_at(chapter: int, step: int) -> void: _camp_write(chapter, step)


func _camp_write(chapter: int, step: int) -> void:   # Learn progress; never an access key
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
	_flash("Learn complete. Start a skirmish from the menu.", 0)
	_layout_ui(); _fit_view()


func _camp_fire(name: String) -> void:
	if bool(_camp_events.get(name, false)): return
	_camp_events[name] = true
	match name:
		"ch4_phish":
			if _camp_relay >= 0:
				hosts[_camp_relay].steal_by = RIVAL; hosts[_camp_relay].steal_until = _t + 24.0
			_flash("A rival is phishing your relay — clear it with Incident response.", 3)
		"ch4_outpost":   # a scripted loss: the rival takes your Outpost, and its station's workers die with it
			var o := _camp_practice2
			if o >= 0 and _mine(o): _capture(o, RIVAL)
			_camp_station_base = _camp_stations()


func _camp_delivered(i: int, res: String) -> float:   # what host i delivered of res to your main node, recently
	return float(_ledger_sums(PLAYER).get("from:%d:%s" % [i, res], 0.0)) if i >= 0 else 0.0


func _camp_stations() -> int:   # your Bot stations, built or ordered
	var n := 0
	for i in hosts.size():
		if not _mine(i): continue
		n += _count_all(i, "bot")
		for slot in (hosts[i].jobs as Dictionary): if str(hosts[i].jobs[slot].get("kind", "")) == "bot": n += 1
	return n


var _camp_step_t := 0.0            # _camp_clock when the current step began (a reading step lasts its "secs")
var _camp_station_base := 0        # Ch4: your stations right after the Outpost fell


func _camp_step_done(chapter: int, step: int) -> bool:
	match chapter:
		0:
			match step:
				0: return _inspect == _camp_home or sel.has(_camp_home)
				1: return _recon_fresh(PLAYER, _camp_relay) or _mine(_camp_relay)
				2: return _held(PLAYER, "breach") > 0 or _mq_count(PLAYER, "breach") > 0 or _mine(_camp_relay)
				3: return _mine(_camp_relay)
		1:
			match step:
				0: return _count_all(_camp_relay, "bot") >= 1 and _worker_ids(PLAYER, _camp_relay).size() >= WORKERS_PER_STATION
				1: return _count_all(_camp_relay, "intel") >= 1 and _count_all(_camp_relay, "cash") >= 1
				2: return _camp_delivered(_camp_relay, "cash") > 0.0
		2:
			match step:
				0: return _known(PLAYER, "exploit")
				1: return (_held(PLAYER, "exploit") >= 1 and _held(PLAYER, "exploit") + _mq_count(PLAYER, "exploit") >= 2) or _mine(_camp_gateway)
				2: return _recon_fresh(PLAYER, _camp_gateway) or _mine(_camp_gateway)
				3: return _mine(_camp_gateway)
				4: return _count_all(_camp_gateway, "cash") >= 1
				5: return _camp_delivered(_camp_gateway, "cash") > 0.0
		3:
			match step:
				0: return _camp_practice >= 0 and (_recon_fresh(PLAYER, _camp_practice) or int(hosts[_camp_practice].get("steal_by", -1)) == PLAYER)
				1: return _camp_practice >= 0 and int(hosts[_camp_practice].get("steal_by", -1)) == PLAYER
				2: return bool(_camp_events.get("ch4_phish", false)) and int(hosts[_camp_relay].get("steal_by", -1)) < 0
				3: return bool(_camp_events.get("ch4_outpost", false)) and _camp_stations() > _camp_station_base
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


var _camp_status_shown := ""   # the banner's status line as last drawn (it is redrawn when the status changes)


func _camp_tick() -> void:
	if not _camp: return
	if _camp_status() != _camp_status_shown: _show_tut()
	var step := _camp_step()
	var need := str(step.get("card", ""))
	if need != "" and not _camp_step_done(_camp_chapter, _tut_stage) and _held(PLAYER, need) <= 0 \
			and not _camp_card_in_flight(need) and _mq_count(PLAYER, need) == 0 and not _camp_exec_running(need):
		_camp_supply(need, true); _refresh_hand()   # every time it is needed: a missed attack never stalls a lesson
	var guard := 0   # a step already done when it begins (you got ahead) hands straight on to the next
	while _camp and guard < 8 and _camp_step_done(_camp_chapter, _tut_stage):
		guard += 1; _camp_complete_step()


func _camp_complete_step() -> void:   # the step is done: say what it did and go straight on (nothing waits)
	var st := _camp_step()
	if str(st.get("fire_leave", "")) != "": _camp_fire(str(st.fire_leave))
	_camp_result = str(st.get("r", "")); _camp_result_at = _camp_clock
	_camp_next()


func _camp_outcome() -> String:
	return str(_camp_step().get("r", "Done."))


func _camp_next() -> void:   # the next step, or the next lesson on the same board
	var steps := _camp_steps(_camp_chapter)
	if _tut_stage + 1 < steps.size():
		_tut_stage += 1
	else:
		_camp_done[_camp_chapter] = true
		if _camp_chapter + 1 >= CAMP_CHAPTERS:
			_camp_finish(); return
		_camp_chapter += 1; _tut_stage = 0
		_camp_enter(_camp_chapter)
	_camp_step_t = _camp_clock
	var step := _camp_step()
	if str(step.get("fire", "")) != "": _camp_fire(str(step.fire))
	_camp_paused = bool(step.get("pause", false)) and not _camp_step_done(_camp_chapter, _tut_stage)   # the lesson's own pause only
	var tgt := _camp_target()
	if tgt >= 0 and _mine(tgt): sel = {tgt: true}; _inspect = -1
	elif tgt >= 0: sel = {}; _inspect = tgt
	if not _camp_replay: _camp_save()
	_show_tut(); _refresh_panel(); queue_redraw()


func _camp_set_pause(on: bool) -> void:
	_camp_paused = on
	_show_tut()


func _camp_banner_h() -> float:   # fixed: measuring tut_box right after a rebuild reads a width-0 transient and breaks _fit_view
	return 124.0 if _camp else 90.0   # header + a 19 px instruction + a 16 px reason (room for one wrapped line)


func _camp_show() -> void:   # one short instruction, the last result while it is fresh, and a clear pause mark
	if tut_box == null: return
	for c in tut_box.get_children(): tut_box.remove_child(c); c.queue_free()
	var step := _camp_step()
	if step.is_empty(): return
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); tut_box.add_child(row)
	var head := "LEARN  %d/%d  %s" % [_camp_chapter + 1, CAMP_CHAPTERS, _camp_chapters()[_camp_chapter]]
	if _camp_chapter < CAMP_OPEN: head += "  ·  step %d of %d" % [_tut_stage + 1, _camp_steps(_camp_chapter).size()]
	_lbl(row, head, 15, C_DIM, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _camp_paused or paused:   # the game waits: a bundled vector pause mark and plain words, never a font fallback
		var mark := TextureRect.new(); mark.texture = UiIcons.texture("pause", 18); mark.modulate = C_WARN
		mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED; mark.custom_minimum_size = Vector2(20, 20)
		row.add_child(mark); _lbl(row, "Paused until you act (Space resumes)" if _camp_paused else "Paused by you (Space resumes)", 15, C_WARN, 0)
	var body := RichTextLabel.new(); body.bbcode_enabled = true; body.fit_content = true; body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # the card art is shrunk to a 16 px inline icon
	body.add_theme_font_size_override("normal_font_size", 16); body.add_theme_color_override("default_color", C_TEXT)
	body.add_theme_font_size_override("bold_font_size", 19)
	var seen := {}   # each icon only on its first mention in this banner
	var txt := "[b]%s[/b]" % _tut_rich(_camp_fill(str(step.a)), seen)
	var status := _camp_status()
	_camp_status_shown = status
	if status != "": txt += "\n[color=#%s]%s[/color]" % [C_DIM.lightened(0.25).to_html(false), _tut_rich(status, seen)]
	elif _camp_result != "": txt += "\n[color=#%s]Done: %s[/color]" % [C_GOOD.to_html(false), _tut_rich(_camp_result, seen)]
	body.text = txt; tut_box.add_child(body)
	body.custom_minimum_size.x = maxf(200, get_viewport_rect().size.x - 80)
	tut_box.reset_size.call_deferred()   # a rebuilt box keeps the tall width-0 transient of its wrapped text unless shrunk back once laid out
	tut_panel.visible = _banner_on() and not menu_open
	_layout_ui()


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
func _panel_has_context() -> bool:
	return won or lost or not sel.is_empty() or _inspect >= 0 or _tab in ["economy", "events"]


func _panel_shown() -> bool:
	return true   # a compact leaderboard fills the sidebar when no building is selected


func _refresh_panel() -> void:
	if panel_box == null: return
	if is_inside_tree() and get_viewport().gui_is_dragging(): return
	var previous_width := panel.size.x
	_refresh_top_tabs()
	var shown := _panel_shown()
	panel.visible = shown and not menu_open
	var pruned := false
	for k in sel.keys():   # a selected host a rival took is no longer yours to build on: inspect it instead, behind its fog
		if _host_ok(int(k)) and not _mine(int(k)):
			sel.erase(k); pruned = true
			if sel.is_empty(): _inspect = int(k)
	if sel.size() == 1 and _deck_open and _armed == "" and not (won or lost):   # however one host became the selection (a capture, a lesson
		_deck_open = false; _deck_drag_restore = false                          # step, a shift-click, a log entry): its build menu gets the full height
	var context := "%s|%s|%d|%s|%s" % [_tab, str(sel.keys()), _inspect, str(won), str(lost)]
	if not sel.is_empty(): context += "|%s|%s" % [str(_banner_on()), str(_deck_open)]   # the build menu's density follows the banner and the drawer
	if _tab == "events": context += "|" + ",".join(PackedStringArray(events.map(func(e): return str(e.key))))   # a new order rebuilds the rows, so each still opens its own event
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
		elif _tab == "economy": _panel_economy()
		elif _tab == "events": _panel_events()
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
	if changed and not pruned: _keep_target_visible()   # a host lost to a rival never moves your view


func _sockets_first(box: Node) -> int:   # the first socket a slot card's embedded SocketList shows, or -1 without one
	for c in box.get_children():
		if c.get("first") != null: return int(c.first)
	return -1


func _same_ui_shape(a: Node, b: Node) -> bool:
	if a is SlotBox and b is SlotBox: return a.host == b.host and a.slot == b.slot and _sockets_first(a) == _sockets_first(b)   # (a Firewall's sockets inside)
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
	if menu_open: _refresh_menu.call_deferred()   # every view is rebuilt to the new window (drafts are kept)


func _layout_ui() -> void:
	if hud == null or feedback_label == null: return
	var sz := get_viewport_rect().size
	top_tabs.size = top_tabs.get_combined_minimum_size()
	top_tabs.position = Vector2(sz.x - 24 - top_tabs.size.x, 14)
	hud.position = Vector2(24, 8); hud.size = Vector2(maxf(200.0, top_tabs.position.x - 16.0 - 24.0), 46)   # never under the buttons
	objective_label.position = Vector2(24, 62); objective_label.size = Vector2(sz.x - 48, 24)
	panel.position = Vector2(sz.x - _panel_width() - 24, (_camp_banner_h() + 74) if _banner_on() else 64)
	if logs_button != null:
		logs_button.position = Vector2(24, _research_bar_y()); logs_button.size = Vector2(LOGS_W, RESEARCH_BAR_H)
		logs_button.visible = not menu_open and not won and not lost
	if research_bar != null:
		research_bar.position = Vector2(24 + LOGS_W + 8, _research_bar_y())
		research_bar.size = Vector2(clampf(sz.x - _panel_width() - 104.0 - LOGS_W, 200.0, RESEARCH_BAR_W), RESEARCH_BAR_H)
		research_bar.visible = not menu_open and not won and not lost and str(_research_bar_state().state) != "idle"   # nothing running: no bar
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
	tut_panel.visible = _banner_on() and not menu_open
	for c in tut_box.get_children():
		if c is Label or c is RichTextLabel: c.custom_minimum_size.x = tut_panel.size.x - 32
	queue_redraw()


func _map_rect() -> Rect2:
	var sz := get_viewport_rect().size
	var right := sz.x - _panel_width() - 48 if _panel_shown() else sz.x - 24
	var top := _research_bar_y() + RESEARCH_BAR_H + 10.0
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
	_place_event_strip()


func _update_chrome(tick := true) -> void:   # tick: also repaint the deck chips (the map's slow-layer cadence)
	if objective_label == null: return
	_update_card_banks(tick)
	objective_label.visible = false
	var was_shown := feedback_label.visible
	feedback_label.visible = not menu_open and _msg_t > 0
	feedback_label.text = _msg
	if paused and not menu_open and not won and not lost and not (_banner_on() and _camp):   # your pause, wherever no banner says it
		feedback_label.visible = true; feedback_label.text = "Paused · Space resumes"
	if was_shown != feedback_label.visible: _place_event_strip()   # the strip sits just above the message line
	if _dragging and _drag_from >= 0:
		feedback_label.visible = true
		var old := int(hosts[_drag_from].assign)
		feedback_label.text = "Connect %s · release over a target" % str(hosts[_drag_from].name)
		if old >= 0: feedback_label.text += " · replaces route to %s; travelling packets still arrive" % str(hosts[old].name)
	var dragged := _aimed_card()
	if dragged != "":
		feedback_label.visible = true
		var target := _host_at(get_local_mouse_position())
		var verb := "release" if _dragged_card() != "" else "click"
		feedback_label.text = ("%s selected · %s a highlighted %s · Esc cancels" % [str(CARDS[_card_of(dragged)].name), verb, "host of yours" if _is_defense(_card_of(dragged)) else "foreign host"])
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
	research_button = Button.new(); research_button.text = "Research"; research_button.name = "Research"
	research_button.custom_minimum_size = Vector2(150, 36); research_button.focus_mode = Control.FOCUS_NONE
	research_button.clip_text = true; research_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	research_button.pressed.connect(_toggle_research); top_tabs.add_child(research_button)
	var econ_button := Button.new(); econ_button.text = "Economy"; econ_button.name = "Economy"
	econ_button.custom_minimum_size = Vector2(104, 36); econ_button.focus_mode = Control.FOCUS_NONE
	econ_button.tooltip_text = "Your recent income, spending and losses for every bank (E)"
	econ_button.pressed.connect(_toggle_economy); top_tabs.add_child(econ_button)
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
	_plabel("Installations · %d slots" % int(hosts[i].slots) if scanned else "%d slots · Recon to see inside and for better odds" % int(hosts[i].slots), 14, C_DIM)
	var row := GridContainer.new(); row.columns = PANEL_COLS
	row.add_theme_constant_override("h_separation", PALETTE_GAP); row.add_theme_constant_override("v_separation", 6)
	for sl in int(hosts[i].slots):
		var ps := PeekSlot.new(); ps.game = self; ps.host = i; ps.slot = sl
		ps.custom_minimum_size.x = _palette_card_w()
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
	for what in ["intel", "cash", "cred", "research"]:   # (a station has 2 workers on any host type)
		if float(tp.get(what, 1.0)) != 1.0: mults += " · %s ×%.1f" % [{"intel": "Intel", "cash": "Crypto", "cred": "Creds", "research": "Research"}[what], float(tp[what])]
	return "%s · %d slots%s" % [str(tp.name), int(tp.slots), mults]


func _stage_line(i: int) -> String:
	var h: Dictionary = hosts[i]
	if not _known_host(PLAYER, i):   # an unknown host: who holds it (public) and nothing else
		var who := "Neutral" if int(h.owner) == NEUTRAL else fname(int(h.owner))
		if bool(h.get("rig", false)) and int(h.owner) != NEUTRAL: who += " · main node"
		return who + (" · Recon expired" if _recon_expired(PLAYER, i) else " · unknown")
	var tname := str(NODE_TYPES[str(h.get("type", "pc"))].name)
	if bool(h.get("junction", false)): tname += " · junction (×%d streets)" % JUNCTION_CAP_MULT
	if bool(h.get("rig", false)) and int(h.owner) != NEUTRAL: tname = "Main node · " + tname
	if int(h.owner) == NEUTRAL: return "Neutral · scouted"   # what it is: the line under it (_type_line)
	if not _mine(i):
		return "%s%s · scouted" % [fname(int(h.owner)), " · main node" if bool(h.get("rig", false)) else ""]
	return "%d/%d slots · %s" % [_standing(i), int(h.slots), tname]


func _effects_line(i: int) -> String:
	var e := []
	if not _known_host(PLAYER, i):   # an unknown host shows only what you did to it, and a DDoS (its routing visibly stops)
		if _ddos_down(i): e.append("DDoS %ds" % int(ceil(float(hosts[i].ddos_until) - _t)))
		if _phished(i) and int(hosts[i].get("steal_by", -1)) == PLAYER: e.append("Phished %ds" % int(ceil(float(hosts[i].steal_until) - _t)))
		var sp0: Dictionary = hosts[i].get("siphon", {})
		if not sp0.is_empty() and int(sp0.get("by", -1)) == PLAYER and float(sp0.get("until", 0.0)) > _t: e.append("Siphon %ds" % int(ceil(float(sp0.until) - _t)))
		for e0 in _execs:
			if int(e0.target) == i and int(e0.fac) == PLAYER: e.append("%s executing %ds" % [str(CARDS[str(e0.card)].short), int(ceil(float(e0.ends) - _t))])
		return " · ".join(e)
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


const SLOT_H := 112.0      # an installation slot in the inspector (the compact card: name, picture, what it makes, its state)
const PALETTE_H := 112.0   # a building card in the inspector's palette: name, picture, what it makes, its price
const PALETTE_H_MINI := 74.0   # ...when the whole menu would not fit (under Learn's banner): name, picture, price
const SLOT_VSEP := 4.0     # between two rows of slots


func _panel_avail_h() -> float:   # the build menu's scroll height, from the same layout _layout_ui applies
	var top := (_camp_banner_h() + 74.0) if _banner_on() else 64.0
	var bottom := get_viewport_rect().size.y - 24.0 if won or lost else _deck_top() - 12.0
	return maxf(180.0, bottom - top) - 24.0


func _palette_h(i: int) -> float:   # the full palette when the whole build menu fits, else the mini one; never a scrollbar
	var rows := ceili(float(int(hosts[i].slots)) / float(PANEL_COLS))
	var need := 32.0 + rows * SLOT_H + (rows - 1) * SLOT_VSEP + 14.0 + 2.0 * PALETTE_H + PALETTE_GAP
	return PALETTE_H if need <= _panel_avail_h() else PALETTE_H_MINI


func _slot_tip(i: int, slot: int) -> String:   # what is in a slot, what it is doing, and what holds this host back
	var h: Dictionary = hosts[i]
	var job: Dictionary = (h.jobs as Dictionary).get(slot, {})
	var kind := str(h.builds[slot]) if slot < (h.builds as Array).size() else ""
	if not job.is_empty() and str(job.kind) != "": kind = str(job.kind)
	if kind == "": return "Empty slot. Drag a building here, or click one of the buildings below."
	var out := [str(BUILD_KINDS[kind].desc)]
	if not job.is_empty():
		match _job_state(job):
			"paused": out.append("Paused by you: click to resume. The red button cancels it.")
			"demolishing": out.append("Clearing the slot: %d s." % ceili(float(job.left)))
			"waiting":
				var parts := []
				for r in RES:
					if not (job.bill as Dictionary).has(r): continue
					parts.append("%s %s/%s" % [RES_NAME[r], _amt(float((job.escrow as Dictionary).get(r, 0.0))), _amt(float(job.bill[r]))])
				out.append("Waiting for its materials (%s); workers bring them, then %d s of work. Click to pause." % [", ".join(parts), int(BUILD_TIME)])
			_: out.append("Building: %d s left. Click to pause." % ceili(float(job.left)))
	elif kind in PRODUCER_KINDS: out.append("Paused by you: click to resume." if _producer_paused(i, slot) else "Click to pause it.")
	if _mine(i):
		var d := _host_diag(i)
		for line in (d.lines as Array).slice(0, 2): out.append(str(line[0]))
	return "\n".join(PackedStringArray(out))


func _panel_build(i: int) -> void:   # the slots, then the six buildings: both always fully in view, the same height every frame
	var h: Dictionary = hosts[i]
	var cols := PANEL_COLS   # three cards a row, whatever the host: 4 and 5 slots take two rows
	var w := floorf((PANEL_W - 44.0 - PALETTE_GAP * (cols - 1)) / float(cols))
	var grid := GridContainer.new(); grid.columns = cols
	grid.add_theme_constant_override("h_separation", PALETTE_GAP); grid.add_theme_constant_override("v_separation", int(SLOT_VSEP))
	for slot in int(h.slots):
		var box := SlotBox.new(); box.game = self; box.host = i; box.slot = slot
		box.custom_minimum_size = Vector2(w, SLOT_H)
		if slot < (h.builds as Array).size() and str(h.builds[slot]) == "wall" and not _slot_busy(i, slot):   # a finished Firewall: its 3 sockets inside its card
			var sl := SocketList.new(); sl.game = self; sl.host = i; sl.first = FIREWALL_SOCKETS * _wall_seat(i, slot)
			sl.mouse_filter = Control.MOUSE_FILTER_PASS   # a building dragged onto it, or a right click, still reaches the slot
			sl.custom_minimum_size = Vector2(w - 8.0, SocketList.ROW * 3.0); sl.position = Vector2(4.0, 28.0); sl.size = sl.custom_minimum_size
			box.add_child(sl); box.sockets_inside = true
		grid.add_child(box)
	panel_box.add_child(grid)
	_gap(6.0)
	var palette := GridContainer.new(); palette.columns = PANEL_COLS
	palette.add_theme_constant_override("h_separation", PALETTE_GAP); palette.add_theme_constant_override("v_separation", PALETTE_GAP)
	var ph := _palette_h(i)
	for kind in BUILD_KINDS:
		var card := BuildCard.new(); card.game = self; card.kind = kind
		card.custom_minimum_size = Vector2(_palette_card_w(), ph); palette.add_child(card)
	panel_box.add_child(palette)


func _amt(x: float) -> String: return "%d" % int(round(x)) if absf(x - round(x)) < 0.05 else "%.1f" % x


func _cycle_text(i: int) -> String:   # what one production cycle on this host does, in words
	var parts := []
	var n := _count(i, "intel")
	if n > 0: parts.append("+%s Intel" % _amt(float(BUILD_KINDS.intel.rate) * _tmult(i, "intel") * n))
	var walls := _count_all(i, "wall") - _walls_building(i)
	if walls > 0: parts.append("Firewall uses %d Intel" % walls if bool(hosts[i].get("fw_on", true)) else "Firewall OFF: no Intel here")
	for kind in CONVERT_ORDER:
		var k := _count(i, kind)
		if k == 0: continue
		var spec: Dictionary = BUILD_KINDS[kind]
		var m := _tmult(i, str(spec.out))
		var ins := []
		for r in (spec.use as Dictionary): ins.append("%s %s" % [_amt(float(spec.use[r]) * m * k), RES_NAME[r]])
		parts.append("%s → %s %s" % [" + ".join(ins), _amt(float(spec.rate) * m * k), RES_NAME[str(spec.out)]])
	if parts.is_empty(): return ""
	return "Every %d s: %s" % [int(PROD_CYCLE), " · ".join(parts)]


func _input_here(i: int, res: String) -> bool:   # a converter's input is in this host's storage (the bank at the main node) or made here
	if _st_get(i, int(hosts[i].owner), res) >= 1.0: return true
	var maker: String = {"intel": "intel", "cash": "cash"}.get(res, "")
	return maker != "" and _count(i, maker) > 0


func _store_text(i: int) -> String:   # this host's storage, and why it is not leaving
	var tot := {}
	for fac in (hosts[i].store as Dictionary):
		for res in (hosts[i].store[fac] as Dictionary): tot[res] = float(tot.get(res, 0.0)) + float(hosts[i].store[fac][res])
	var parts := []
	for res in RES:
		if float(tot.get(res, 0.0)) >= 0.05: parts.append("%s %s" % [_amt(float(tot[res])), RES_NAME[res]])
	var line := "Storage %s/%d" % [_amt(_store_total(i)), int(STORE_CAP)]
	if not parts.is_empty(): line += ": " + ", ".join(parts)
	var owner := int(hosts[i].owner)
	if _store_total(i) >= STORE_CAP - 0.5: line += " · full, production stops"
	elif _store_total(i) >= 1.0 and owner != NEUTRAL and _attack_route_none(owner, i): line += " · no route home"
	return line


# ---- host diagnosis (Milestone A, brief §9.3): role → status → next cycle → delivery, read from the simulation ----
# _cycle_preview works out the host's next cycle exactly as _run_cycle will, on copies: nothing in the game changes.
func _cycle_preview(i: int) -> Dictionary:
	var owner := int(hosts[i].owner)
	var benef := _benef(i)
	if not botnets.has(benef) or _eliminated.has(benef): benef = owner
	var S := {"st": {}, "total": _store_total(i)}
	for fac in [owner, benef]:
		S.st[fac] = {}
		for res in RES: S.st[fac][res] = _st_get(i, fac, res)
	var out := {"benef": benef, "conv": [], "sent": []}
	# a) Intel harvesters
	var n := _cycle_kinds(i, "intel")
	if n > 0:
		var want := float(BUILD_KINDS.intel.rate) * _tmult(i, "intel") * n
		out["intel"] = [_pv_add(S, i, benef, "intel", want), want]
	# b) the Firewall's upkeep
	var walls := _count_all(i, "wall") - _walls_building(i)
	if walls > 0:
		var need := float(BUILD_KINDS.wall.use.intel) * walls
		var have := float(S.st[owner].intel)
		if owner != benef: have += float(S.st[benef].intel)
		var on := have >= need - 0.0001
		out["fw"] = {"need": need, "on": on}
		if on:
			var own := minf(need, float(S.st[owner].intel))
			_pv_take(S, i, owner, "intel", own)
			if need - own > 0.0001: _pv_take(S, i, benef, "intel", need - own)
	# c) converters, in order (a remote host's as far as its plan funds them, exactly as _run_cycle runs them)
	var use_plan: bool = not _st_local(i, owner) and benef == owner
	var planned := {}
	if use_plan:
		var budget := {}
		for res in RES: budget[res] = _free(owner, res)
		planned = _host_plan(i, owner, budget).frac
	for kind in CONVERT_ORDER:
		var count := _cycle_kinds(i, kind)
		if count == 0: continue
		var spec: Dictionary = BUILD_KINDS[kind]
		var res_out := str(spec.out)
		var m := _tmult(i, res_out)
		var row := {"kind": kind, "n": count, "frac": 0.0, "short": "", "made": 0.0, "use": {}}
		var done := 0.0
		var slots := []
		for sl in (hosts[i].builds as Array).size():
			if str(hosts[i].builds[sl]) == kind and _producer_active(i, sl): slots.append(sl)
		for k in count:
			var frac := float(planned.get(slots[k], 0.0)) if use_plan else 1.0; var lim := ""
			if frac < 0.9999:   # the plan holds it back: the input the main node cannot cover, else storage room for its supplies
				var best := 1.0e9; lim = "room"
				for r in (spec.use as Dictionary):
					var cover := (float(S.st[benef][str(r)]) + _inbound(i, str(r)) + _free(owner, str(r))) / maxf(0.000001, float(spec.use[r]) * m)
					if cover < 0.9999 and cover < best: best = cover; lim = str(r)
			for r in (spec.use as Dictionary):
				var fr := float(S.st[benef][str(r)]) / maxf(0.000001, float(spec.use[r]) * m)
				if fr < frac: frac = fr; lim = str(r)
			if _st_local(i, benef):
				var fr2 := maxf(0.0, _cap(benef, res_out) - float(S.st[benef][res_out])) / maxf(0.000001, float(spec.rate) * m)
				if fr2 < frac: frac = fr2; lim = "cap"
			if frac < 0.9999 and str(row.short) == "": row.short = lim
			if frac <= 0.0001: break
			for r in (spec.use as Dictionary):
				_pv_take(S, i, benef, str(r), float(spec.use[r]) * m * frac)
				row.use[str(r)] = float((row.use as Dictionary).get(str(r), 0.0)) + float(spec.use[r]) * m * frac
			row.made = float(row.made) + _pv_add(S, i, benef, res_out, float(spec.rate) * m * frac)
			done += frac
		row.frac = done / float(count)
		out.conv.append(row)
	out["after"] = S.st[benef]
	out["after_owner"] = S.st[owner]
	return out


func _pv_add(S: Dictionary, i: int, fac: int, res: String, amt: float) -> float:   # _st_add on the preview's copy
	if amt <= 0.0: return 0.0
	var local := _st_local(i, fac)
	var room := _cap(fac, res) - float(S.st[fac][res]) if local else STORE_CAP - float(S.total)
	var fit := minf(amt, maxf(0.0, room))
	if fit <= 0.0: return 0.0
	S.st[fac][res] = float(S.st[fac][res]) + fit
	if not local: S.total = float(S.total) + fit
	return fit


func _pv_take(S: Dictionary, i: int, fac: int, res: String, amt: float) -> void:   # _st_take on the preview's copy
	var have := float(S.st[fac][res])
	var left := maxf(0.0, have - amt)
	if not _st_local(i, fac):
		if have - amt <= 0.0001: left = 0.0
		S.total = float(S.total) - (have - left)
	S.st[fac][res] = left


func _host_role(i: int) -> String:   # what the host is for, from what is installed
	if i == int(rig.get(int(hosts[i].owner), -1)): return "MAIN NODE"
	var outs := []
	for kind in ["lab", "cred", "cash"]:
		if _count_all(i, kind) > 0: outs.append({"lab": "RESEARCH", "cred": "CREDENTIAL", "cash": "CRYPTO"}[kind])
	if outs.is_empty() and _count_all(i, "intel") > 0: outs.append("INTEL")
	if not outs.is_empty(): return " + ".join(outs) + " HOST"
	if _count_all(i, "bot") > 0: return "BOT STATION HOST"
	if _count_all(i, "wall") > 0: return "FIREWALL HOST"
	return "EMPTY HOST"


const _MAKER_OF := {"intel": "an Intel harvester", "cash": "a Crypto miner"}


func _host_diag(i: int) -> Dictionary:   # {role, status, col, lines [[text, colour]], next, full, pv}: the first problem names the status
	var owner := int(hosts[i].owner)
	var main := i == int(rig.get(owner, -1))
	var pv := _cycle_preview(i)
	var probs := []   # [status, colour, text]; status "" = a note that does not change the headline
	var producers := 0; var paused := 0
	for k in (hosts[i].builds as Array).size():
		if str(hosts[i].builds[k]) in PRODUCER_KINDS and not _slot_busy(i, k):
			producers += 1
			if _producer_paused(i, k): paused += 1
	if _ddos_down(i): probs.append(["under DDoS", C_BAD, "Under DDoS for %d s: nothing is made or sent from here." % int(ceil(float(hosts[i].ddos_until) - _t))])
	if _sabotaged(i): probs.append(["sabotaged", C_BAD, "Sabotaged for %d s: producers are off; cargo still passes through." % int(ceil(float(hosts[i].sabot_until) - _t))])
	if _phished(i): probs.append(["phished", C_BAD, "Phished by %s for %d s: what is made here goes to them." % [fname(int(hosts[i].steal_by)), int(ceil(float(hosts[i].steal_until) - _t))]])
	if not main and (producers > 0 or _store_total(i) >= 1.0) and _attack_route_none(owner, i):
		probs.append(["no route", C_BAD, "No route home: no chain of your hosts links this one to your main node. Retake a host between them."])
	for row in pv.conv:
		if float(row.frac) >= 0.9999: continue
		var nm := str(BUILD_KINDS[str(row.kind)].name)
		var lim := str(row.short)
		var out_res := str(BUILD_KINDS[str(row.kind)].out)
		if lim == "cap": probs.append(["blocked", C_WARN, "%s stops: your %s bank is full. Spend some, or pause the %s." % [nm, RES_NAME[out_res], nm]])
		elif lim == "room": probs.append(["starved", C_WARN, "%s waits its turn: storage here has no room for all its supplies this cycle. Let surplus ship, or pause a producer." % nm])
		elif main: probs.append(["starved", C_WARN, "%s has no %s in your bank to use." % [nm, RES_NAME[lim]]])
		elif float(row.frac) > 0.0001: probs.append(["starved", C_WARN, "%s runs at %d%%: not enough %s on this host." % [nm, int(round(100.0 * float(row.frac))), RES_NAME[lim]]])
		elif not _input_here(i, lim):
			if _inbound(i, lim) >= 1.0: probs.append(["starved", C_WARN, "%s waits for the %s on its way from your main node." % [nm, RES_NAME[lim]]])
			elif _free(owner, lim) < 0.999: probs.append(["starved", C_WARN, "%s needs %s here; your main node has none to send. Make %s, or build %s here." % [nm, RES_NAME[lim], RES_NAME[lim], _MAKER_OF.get(lim, "its input")]])
			elif not _route_ok(owner, _hub(owner), i): probs.append(["starved", C_WARN, "%s needs %s here, and no worker can reach this host." % [nm, RES_NAME[lim]]])
			elif int(_worker_counts(owner).total) == 0: probs.append(["starved", C_WARN, "%s needs %s here, but you have no workers to fetch it. Build a Bot station." % [nm, RES_NAME[lim]]])
			else: probs.append(["starved", C_WARN, "%s needs %s here: your workers are bringing it from your main node as they come free." % [nm, RES_NAME[lim]]])
		else: probs.append(["starved", C_WARN, "%s gets no %s: the converters before it use it all. Add %s here, or pause one." % [nm, RES_NAME[lim], _MAKER_OF.get(lim, "more input")]])
	if pv.has("fw") and not bool(pv.fw.on):
		probs.append(["Firewall off", C_WARN, "Firewall OFF next cycle: it needs %s Intel here and none is left. Build an Intel harvester here." % _amt(float(pv.fw.need))])
	if not main and not _ddos_down(i):
		var bank_full := []
		for res in RES:
			if _st_get(i, owner, res) >= 1.0 and _room(owner, res) < 1.0: bank_full.append(str(RES_NAME[res]))
		var wc := _worker_counts(owner)
		var waits := ("All %d of your workers are busy." % int(wc.total)) if int(wc.total) > 0 else "You have no workers: build a Bot station."
		if _store_total(i) >= STORE_CAP - 0.5:
			var why := "Storage %d/%d: producers here stop until it ships." % [int(round(_store_total(i))), int(STORE_CAP)]
			if not bank_full.is_empty(): why += " Your main node's %s is full: spend some, or pause what makes it." % " and ".join(bank_full)
			elif int(wc.idle) == 0: why += " " + waits
			probs.append(["blocked", C_WARN, why])
		elif not bank_full.is_empty(): probs.append(["blocked", C_WARN, "Your main node's %s is full: what is stored here waits." % " and ".join(bank_full)])
		elif _store_total(i) >= 1.0 and int(wc.idle) == 0 and not _attack_route_none(owner, i):
			probs.append(["waiting for workers", C_WARN, waits])
	if paused > 0: probs.append(["paused" if paused == producers else "", C_DIM, "%d producer%s paused by you." % [paused, "" if paused == 1 else "s"]])
	for slot_key in (hosts[i].jobs as Dictionary):
		var job: Dictionary = hosts[i].jobs[slot_key]
		var what := str(BUILD_KINDS[str(job.kind)].name) if str(job.kind) != "" else "nothing"
		var line := ""
		match _job_state(job):
			"paused": line = "%s is paused: no work and no new deliveries." % what
			"demolishing": line = "Clearing a slot for %s: %d s left." % [what, int(ceil(float(job.left)))]
			"waiting":
				var bill := 0.0; var here := 0.0
				for r in (job.bill as Dictionary): bill += float(job.bill[r]); here += minf(float(job.bill[r]), float((job.escrow as Dictionary).get(r, 0.0)))
				line = "%s waits for its materials: %d of %d here; workers bring the rest." % [what, int(here + 0.0001), int(bill + 0.0001)]
			_: line = "Building %s: %d s left." % [what, int(ceil(float(job.left)))]
		probs.append(["building" if producers == 0 else "", C_DIM, line])
	if producers == 0 and _count_all(i, "wall") == 0 and (hosts[i].jobs as Dictionary).is_empty():
		probs.append(["idle", C_DIM, "Nothing installed: drag a building onto an empty slot."])
	var status := "operating"; var col := C_GOOD
	for p in probs:
		if str(p[0]) != "": status = str(p[0]); col = p[1]; break
	var lines := []
	for p in probs: lines.append([str(p[2]), p[1]])
	var nxt := _next_cycle_text(i, pv)
	var full := _cycle_text(i)
	var short := false
	for row in pv.conv: short = short or float(row.frac) < 0.9999
	if pv.has("intel") and float(pv.intel[0]) < float(pv.intel[1]) - 0.05: short = true
	return {"role": _host_role(i), "status": status, "col": col, "lines": lines, "next": nxt, "full": full if short else "", "pv": pv}


func _next_cycle_text(i: int, pv: Dictionary) -> String:   # what the next cycle will really do (feasible, not theoretical)
	var parts := []
	if pv.has("intel"):
		var got := float(pv.intel[0]); var want := float(pv.intel[1])
		parts.append("+%s Intel" % _amt(got) + ("" if got >= want - 0.05 else " of %s (no room)" % _amt(want)))
	if pv.has("fw"): parts.append("Firewall uses %s Intel" % _amt(float(pv.fw.need)) if bool(pv.fw.on) else "Firewall OFF")
	for row in pv.conv:
		var spec: Dictionary = BUILD_KINDS[str(row.kind)]
		if float(row.made) < 0.05: parts.append("%s idle" % str(spec.card)); continue
		var ins := []
		for r in (spec.use as Dictionary): ins.append("%s %s" % [_amt(float((row.use as Dictionary).get(str(r), 0.0))), RES_NAME[str(r)]])
		parts.append("%s → %s %s" % [" + ".join(ins), _amt(float(row.made)), RES_NAME[str(spec.out)]])
	if parts.is_empty(): return ""
	return "Next cycle in %.1f s: %s" % [maxf(0.0, float(hosts[i].get("cyc", PROD_CYCLE))), " · ".join(parts)]


func _route_eta(rt: Array, express := false) -> Dictionary:   # a packet leaving now: hops, travel, and queueing on top (nothing is reserved)
	if rt.size() < 2: return {"hops": 0, "travel": 0.0, "wait": 0.0}
	var lt := LINK_TIME * (EXPRESS_MULT if express else 1.0)
	var fd := NODE_ROUTE_DELAY * (EXPRESS_MULT if express else 1.0)
	var t := _t
	for k in range(rt.size() - 1):
		t = _link_entry(_lkey(int(rt[k]), int(rt[k + 1])), t) + lt
		if k < rt.size() - 2: t += fd
	var travel := _travel_time(rt, express)
	return {"hops": rt.size() - 1, "travel": travel, "wait": maxf(0.0, (t - _t) - travel)}


func _host_delivered(fac: int, i: int) -> Dictionary:   # res -> per minute that reached the bank from host i, over the ledger window
	var out := {}
	var per_min := 60.0 / _ledger_window()
	var sums := _ledger_sums(fac)
	for key in sums:
		var parts := str(key).split(":")
		if parts.size() == 3 and parts[0] == "from" and parts[1] == str(i): out[parts[2]] = float(sums[key]) * per_min
	return out


func _route_home_line(i: int) -> String:   # "Route home: 4 hops, ~4.8 s + 1.2 s queue"
	var owner := int(hosts[i].owner)
	var rt := _home_route(owner, i)
	if rt.is_empty(): return "Route home: none"
	var eta := _route_eta(rt, float(hosts[i].get("express_until", 0.0)) > _t)
	var line := "Route home: %d hop%s, ~%.1f s" % [int(eta.hops), "" if int(eta.hops) == 1 else "s", float(eta.travel)]
	if float(eta.wait) >= 0.1: line += " + %.1f s queue" % float(eta.wait)
	return line


func _delivery_lines(i: int) -> Array:   # [[text, colour]] for a remote host: route, who carries, storage, what arrived
	var owner := int(hosts[i].owner)
	var lines := []
	var route := _route_home_line(i)
	lines.append([route, C_BAD if route.ends_with("none") else C_DIM])
	var c := _worker_counts(owner)
	lines.append(["Workers %d" % int(c.total) + " — %d available, %d collecting, %d carrying" % [int(c.idle), int(c.collecting), int(c.carrying)] + (", %d blocked" % int(c.blocked) if int(c.blocked) > 0 else ""), C_WARN if int(c.blocked) > 0 else C_DIM])
	lines.append([_store_text(i), C_WARN if _store_total(i) >= STORE_CAP - 0.5 else C_DIM])
	var got := _host_delivered(owner, i)
	var parts := []
	for res in RES:
		if float(got.get(res, 0.0)) >= 0.5: parts.append("%d %s" % [int(round(float(got[res]))), RES_NAME[res]])
	if not parts.is_empty(): lines.append(["Delivered recently: %s per min%s." % [", ".join(parts), " (early estimate)" if _t < float(LEDGER_SECS) else ""], C_DIM])
	return lines


func _cut_off(i: int) -> Array:   # your hosts that, with i, have no route to your main node (the disconnected segment)
	var fac := int(hosts[i].owner)
	if not _attack_route_none(fac, i): return []
	var seen := {i: true}; var q := [i]; var head := 0
	while head < q.size():
		var c: int = q[head]; head += 1
		for o in hosts[c].links:
			if int(hosts[o].owner) == fac and not seen.has(int(o)): seen[int(o)] = true; q.append(int(o))
	var out := seen.keys(); out.sort()
	return out


const PALETTE_GAP := 4
const PANEL_COLS := 3   # slots and building cards per row in the inspector


func _palette_card_w() -> float:   # three building cards (or slots) side by side within the inspector, never under its scrollbar
	return floorf((PANEL_W - 44.0 - PALETTE_GAP * (PANEL_COLS - 1)) / float(PANEL_COLS))


func _panel_selecting() -> void:   # your host: its name, its installations and what you can build there; nothing else
	if sel.size() != 1:
		_plabel("%d hosts selected" % sel.size(), 20, C_TEXT)
		return
	var source := int(sel.keys()[0])
	_plabel(str(hosts[source].name), 20, C_TEXT)
	_panel_build(source)


func _cycle_needs(i: int) -> Dictionary:   # {res: units} one full cycle uses from this host's storage, after what the host makes itself
	var gross := {}; var made := {}
	var walls := _count_all(i, "wall") - _walls_building(i)
	if walls > 0: gross.intel = float(BUILD_KINDS.wall.use.intel) * walls
	made.intel = float(BUILD_KINDS.intel.rate) * _tmult(i, "intel") * _count(i, "intel")
	for k in (hosts[i].builds as Array).size():
		var kind := str(hosts[i].builds[k])
		if not (kind in CONVERT_ORDER) or not _producer_active(i, k): continue
		var spec: Dictionary = BUILD_KINDS[kind]
		var m := _tmult(i, str(spec.out))
		for r in (spec.use as Dictionary): gross[str(r)] = float(gross.get(str(r), 0.0)) + float(spec.use[r]) * m
		made[str(spec.out)] = float(made.get(str(spec.out), 0.0)) + float(spec.rate) * m
	var out := {}
	for r in gross:
		var v := float(gross[r]) - float(made.get(r, 0.0))
		if v > 0.0001: out[r] = v
	return out


func _worker_ids(fac: int, home: int) -> Array:   # this host's workers by their stable number
	var out := []
	for wid in workers:
		if int(workers[wid].fac) == fac and int(workers[wid].home) == home: out.append(int(wid))
	out.sort()
	return out


func _worker_line(wid: int) -> Array:   # [text, colour]: one worker, by number, and what it is doing
	var w: Dictionary = workers[wid]
	var f := _flight_of(wid)
	var st := _worker_state(wid)
	var txt := "available at %s" % str(hosts[int(w.home)].name)
	var col := C_DIM
	match st:
		"blocked":
			txt = "blocked at %s: the way on is cut" % str(hosts[int(f.get("at", w.home))].name); col = C_WARN
		"collecting":
			var job: Dictionary = f.get("job", {})
			col = C_TEXT
			if job.has("src"): txt = "collecting %s %s at %s" % [_amt(float(job.amt)), RES_NAME[str(job.res)], str(hosts[int(job.src)].name)]
			elif job.has("dest"): txt = "fetching %s %s from your main node" % [_amt(float(job.amt)), RES_NAME[str(job.res)]]
			else: txt = "returning to %s" % str(hosts[int(w.home)].name); col = C_DIM
		"carrying":
			var to := int(f.dest) if str(f.trip) == "out" else int(f.origin)
			txt = "carrying %s → %s" % [_res_list(f.cargo), str(hosts[to].name)]; col = C_TEXT
	if str(w.state) == "retiring": txt = "retiring after this leg · " + txt
	return ["#%d  %s" % [wid, txt], col]


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
	for res in ["bots", "intel", "cash", "creds", "research"]:
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


func _connection_list(_sources: Array) -> void: pass   # no manual connections in this model


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
	if not _recon_fresh(PLAYER, i):   # nothing about what it is until a Recon lands
		if _recon_expired(PLAYER, i): _plabel("Recon expired — send Recon again to inspect it.", 14, C_WARN)
		else: _plabel("Unknown host — send Recon to inspect. Its buildings and storage are concealed.", 14, C_TEXT)
		_plabel("Your attacks here: %d%% without fresh Recon, %d%% with it." % [_pct(UNSCOUTED_CHANCE), _pct(SCOUTED_CHANCE)], 12, C_WARN)
		return
	if _recon_fresh(PLAYER, i):
		var rec: Dictionary = (recon.get(PLAYER, {}) as Dictionary).get(i, {})
		_plabel(_type_line(i), 13, C_TEXT)
		_plabel("Recon %d s ago, fresh for %d s more · storage %s/%d" % [int(_t - float(rec.get("at", _t))), maxi(0, int(float(rec.get("at", _t)) + float(CARDS.recon.dur) - _t)), _amt(float(rec.get("store", 0.0))), int(STORE_CAP)], 12, C_DIM)
		var socks: Array = _loaded_of(rec.get("sockets", []))
		if (rec.get("builds", []) as Array).has("wall"):
			var names := []
			for r in socks: names.append(str(CARDS[str(r)].short))
			_plabel("Firewall holds: %s" % (", ".join(names) if not names.is_empty() else "nothing"), 12, C_WARN if not names.is_empty() else C_DIM)
	_panel_enemy_slots(i)
	var scouted := _recon_fresh(PLAYER, i)
	_plabel("Your attacks here: %d%% while your Recon is fresh." % _pct(SCOUTED_CHANCE) if scouted else "Your attacks here: %d%% without fresh Recon, %d%% with it." % [_pct(UNSCOUTED_CHANCE), _pct(SCOUTED_CHANCE)], 12, C_GOOD if scouted else C_WARN)


func _panel_attack_diag(t: int, _f: Array, _s: Array) -> void:
	var o := _operation_observation(t)
	if o != "": _plabel(o, 14, C_TEXT)


func _panel_idle() -> void:
	_plabel("Hold at least 51%% of the hosts for %d s to win." % int(HOLD_SECS), 16, C_TEXT)
	_gap(2.0)
	_plabel("①  Make a card: C opens the recipes.", 13)
	_plabel("②  Drag a ready card onto a host, or click it, then a host.", 13)
	_plabel("③  Build producers; workers bring their output home.", 13)
	_gap(4.0)
	_plabel("Drag empty map to pan · wheel to zoom · 0 recenters", 11, C_DIM)
	_plabel("Esc menu · Space pause · C cards · R research · E economy · H events", 11, C_DIM)


func _panel_board() -> void:
	_plabel("Standings", 18, C_TEXT)
	var obj := _objective()
	_plabel("Hold %d of %d hosts for %d s to win" % [int(obj.need), int(obj.total), int(obj.secs)], 12, C_DIM)
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
		if hold > 0: status = "Holding: %d s left" % int(ceil(maxf(0.0, HOLD_SECS - hold) - 0.001))
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


func _hud_items() -> Array:   # [kind-icon, text, colour, column width, res]
	var wc := _worker_counts(PLAYER)   # first the delivery workers (a population, not a material), then the main node's four stocks
	var out := [["bot", "Workers %d" % int(wc.total), C_TEXT if int(wc.total) > 0 else C_BAD, HUD_BOTS_W, "workers"]]
	for res in RES:
		var kind := str({"intel": "intel", "cash": "cash", "creds": "cred", "research": "lab"}[res])
		var txt := "%d/%d" % [int(_avail(PLAYER, res)), int(_cap(PLAYER, res))]
		out.append([kind, txt, C_WARN if _res_full(res) else C_TEXT, _hud_col_w(), res])
	return out


const HUD_BOTS_W := 180.0   # the workers' column: "Workers 48" over "24 busy · 8 blocked"
const HUD_OBJ_W := 240.0    # the objective's two lines after the banks
func _hud_col_w() -> float:   # a material's column: the four share what the couriers' column and the objective leave
	var w := hud.size.x if hud != null else 950.0
	return clampf(floorf((w - HUD_BOTS_W - HUD_OBJ_W) / 4.0), 106.0, 150.0)


func _hud_rate(res: String) -> Array:   # [the HUD's second line, its colour]: the forecast inflow to the bank; for workers, what they do
	var fc := _forecast(PLAYER)
	if res == "workers":
		var wc := _worker_counts(PLAYER)
		var busy := int(wc.collecting) + int(wc.carrying) + int(wc.joining)   # on their way to the main node counts as busy, not free
		if int(wc.blocked) > 0: return ["%d busy · %d blocked" % [busy, int(wc.blocked)], C_WARN]
		return ["%d busy · %d free" % [busy, int(wc.idle)], C_DIM]
	if _res_full(res): return ["full", C_WARN]
	var v := float(fc.rate[res])
	return ["+%d/min" % int(round(v)), C_GOOD if v >= 0.5 else C_DIM]


func _rate_txt(v: float) -> String: return "%d/min" % int(round(v))


func _by_txt(by: Dictionary) -> String:   # "research 12, buildings 4" — largest first, zero rates left out
	var items := []
	for k in by:
		if float(by[k]) >= 0.5: items.append([str(k), float(by[k])])
	items.sort_custom(func(a, b): return float(a[1]) > float(b[1]) if float(a[1]) != float(b[1]) else str(a[0]) < str(b[0]))
	return ", ".join(PackedStringArray(items.map(func(it): return "%s %d" % [it[0], int(round(float(it[1])))])))


func _forecast_lines(res: String) -> Array:   # [[text, colour]]: the forecast for one bank, where it comes from, what holds it back
	var fc := _forecast(PLAYER)
	var out := []
	if res == "workers":
		var wc := _worker_counts(PLAYER)
		out.append(["Workers %d — %d working, %d free at your main node%s%s (2 per Bot station)." % [int(wc.total), int(wc.collecting) + int(wc.carrying), int(wc.idle), (", %d on their way to it" % int(wc.joining)) if int(wc.joining) > 0 else "", (", %d blocked" % int(wc.blocked)) if int(wc.blocked) > 0 else ""], C_TEXT])
		out.append(["All of them work from your main node and serve every host; keeping up with your hosts needs about %d." % int(ceil(float(fc.need) - 0.05)), C_WARN if float(fc.need) > float(fc.spare) else C_DIM])
		out.append(["Each carries one unit per leg and returns for another job; delivery does not consume them.", C_DIM])
		out.append(["Building materials go first, then missing inputs, then surplus home; the hosts are served in turn.", C_DIM])
		return out
	var full := _res_full(res)
	out.append(["Forecast: %s reaches your bank per minute." % ("nothing (the bank is full)" if full else "+%d" % int(round(float(fc.rate[res])))), C_WARN if full else C_TEXT])
	var src: Dictionary = (fc.from as Dictionary).get(res, {})
	if not src.is_empty(): out.append(["From: " + _by_txt(src), C_DIM])
	var lim: Array = (fc.limits as Dictionary).get(res, [])
	if not lim.is_empty(): out.append(["Held back: " + ", ".join(PackedStringArray(lim)), C_WARN])
	return out


func _history_lines(res: String) -> Array:   # the measured flows of one bank over the ledger window, clearly historical
	var r := _econ_rates(PLAYER, res)
	var inc := _incoming_eta(PLAYER, res)
	var out := []
	out.append("Historical, last %d s: received %s · spent %s · net %s%s" % [int(_ledger_window()), _rate_txt(float(r["in"])), _rate_txt(float(r.out)), "+" if float(r.net) >= 0.0 else "−", _rate_txt(absf(float(r.net)))])
	if not (r.in_by as Dictionary).is_empty(): out.append("Received from: " + _by_txt(r.in_by))
	if not (r.out_by as Dictionary).is_empty(): out.append("Spent on: " + _by_txt(r.out_by))
	if float(r.lost) >= 0.5: out.append("Lost: " + _by_txt(r.lost_by))
	if int(inc.n) > 0:
		var line := "On the road now: %d, next in ~%d s" % [int(inc.n), int(ceil(float(inc.next)))]
		if int(inc.risk) > 0: line += " (%d held: route cut)" % int(inc.risk)
		out.append(line)
	return out


func _econ_lines(res: String) -> Array:   # one bank's forecast and history in words (the HUD tooltip and the Economy view share them)
	var out := []
	for l in _forecast_lines(res): out.append(str(l[0]))
	if res != "workers": out.append_array(_history_lines(res))
	return out


func _where_is(fac: int, res: String) -> Dictionary:   # {hosts, transit, reserved}: the resource away from the bank, or spoken for in it
	var at_hosts := 0.0; var transit := 0.0
	for i in hosts.size():
		if int(hosts[i].owner) != fac or i == _hub(fac): continue
		at_hosts += float(_store_of(i, fac).get(res, 0.0)) + _loot(i, fac, res)
		for slot in (hosts[i].jobs as Dictionary): at_hosts += float((hosts[i].jobs[slot].get("escrow", {}) as Dictionary).get(res, 0.0))
	for f in flights:
		if str(f.kind) == "courier" and int(f.owner) == fac: transit += float((f.cargo as Dictionary).get(res, 0.0))
	return {"hosts": at_hosts, "transit": transit}


func _econ_tooltip(res: String) -> String:
	var head := "DELIVERY WORKERS" if res == "workers" else "%s  %d / %d at your main node" % [str(RES_NAME[res]).to_upper(), int(_avail(PLAYER, res)), int(_cap(PLAYER, res))]
	var where := ""
	if res != "workers":
		var w := _where_is(PLAYER, res)
		where = "\nStored at hosts: %s · In transit: %s" % [_amt(float(w.hosts)), _amt(float(w.transit))]
	return "%s%s\n%s\n\nClick for the Economy overview." % [head, where, "\n".join(PackedStringArray(_econ_lines(res)))]


func _objective_tooltip() -> String:
	var o := _objective()
	return "Win: hold %d of the %d hosts for %d s in a row, or be the last network with a main node." % [int(o.need), int(o.total), int(o.secs)]


func _toggle_economy() -> void:   # the Economy overview in the sidebar (E, the Economy button or a click on the HUD)
	if menu_open or won or lost: return
	if _tab == "economy" and sel.is_empty() and _inspect < 0: _tab = ""
	else: _tab = "economy"; sel = {}; _inspect = -1
	_refresh_panel(); queue_redraw()


func _panel_economy() -> void:
	_plabel("Economy", 20, C_TEXT)
	_plabel("Forecast: what will reach your bank per minute with your network as it is now. Historical: what did over the last %d s." % int(_ledger_window()), 12, C_DIM)
	_gap(4.0)
	_plabel("DELIVERY WORKERS", 14, BUILD_KINDS.bot.col)
	for l in _forecast_lines("workers"): _plabel(str(l[0]), 12, l[1])
	for res in RES:
		_gap(4.0)
		var col: Color = BUILD_KINDS[str({"intel": "intel", "cash": "cash", "creds": "cred", "research": "lab"}[res])].col
		_plabel("%s  %d / %d   forecast %s" % [str(RES_NAME[res]).to_upper(), int(_avail(PLAYER, res)), int(_cap(PLAYER, res)), str(_hud_rate(res)[0])], 14, col)
		for l in _forecast_lines(res).slice(1): _plabel(str(l[0]), 12, l[1])
		for l in _history_lines(res): _plabel(str(l), 12, C_DIM)
	_gap(4.0)
	_plabel("E or Esc closes this view.", 11, C_DIM)


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
	for fl in flights:   # yours: a worker is a dot in its cargo's colour (a ring when it travels empty) with an arrow; a rival's is a square
		if not _flight_seen(fl, sight): continue
		if str(fl.kind) == "op":   # a card: its remaining path dashed in its family's colour (the card is drawn above the buildings)
			if int(fl.owner) == PLAYER and not bool(fl.get("blocked", false)): _paint_card_path(fl, vt)
			continue
		if bool(fl.get("blocked", false)): continue   # held packets are counted on their host's "held" tag (_paint_held)
		var pp := _packet_pos(fl, vt)
		var endn := int(fl.get("dest", (fl.route as Array)[(fl.route as Array).size() - 1]))
		var threat: bool = int(fl.owner) != PLAYER and _mine(endn)
		var ba: float = 1.0 if (not focus_on or fnodes.has(endn) or threat) else 0.3
		var fc := fcol(int(fl.owner))
		if str(fl.kind) == "scan":
			if int(fl.owner) == PLAYER: _cv.draw_arc(pp, 3.5, 0.0, TAU, 12, Color(0.6, 0.95, 1.0, ba), 1.5, true)   # a quiet scan: only you see it
			continue
		if int(fl.owner) != PLAYER:   # a rival's courier: you see it pass, not what it carries
			_cv.draw_rect(Rect2(pp - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), Color(fc.r, fc.g, fc.b, ba).lightened(0.25), true)
			continue
		var res := _cargo_res(fl)
		var col := _res_col(res) if res != "" else COURIER_COL
		var dir := _flight_dir(fl, vt)
		var perp := Vector2(-dir.y, dir.x)
		pp += perp * (3.5 + 3.5 * float(int(fl.get("wid", 0)) % 2))   # each direction on its own side; two workers side by side, never one dot
		if res != "":   # loaded: a filled dot in its cargo's colour
			_cv.draw_circle(pp, 4.0, Color(col, ba)); _cv.draw_arc(pp, 4.0, 0.0, TAU, 12, Color(0.02, 0.03, 0.05, 0.8 * ba), 1.0, true)
		else: _cv.draw_arc(pp, 3.2, 0.0, TAU, 12, Color(col, 0.85 * ba), 1.4, true)   # empty: a hollow ring
		if dir != Vector2.ZERO:   # which way it is going
			_cv.draw_colored_polygon(PackedVector2Array([pp + dir * 9.0, pp + dir * 5.0 + perp * 3.0, pp + dir * 5.0 - perp * 3.0]), Color(col, 0.9 * ba))
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
	var names := []   # [screen position, text, colour]: your cards' names, written after the world-space shapes
	for fl in flights:   # cards ride above everything: a card shape in its family's colour (a rival's in its own colour, unnamed)
		if str(fl.kind) != "op" or not _flight_seen(fl, sight) or bool(fl.get("blocked", false)): continue
		var pp2 := _packet_pos(fl, vt)
		var yours := int(fl.owner) == PLAYER
		var cc2: Color = FAMILY_COL[str(CARDS[_card_of(str(fl.card))].fam)] if yours else fcol(int(fl.owner)).lightened(0.2)
		var hot := int(fl.id) == _hover_flight
		_cv.draw_circle(pp2, 13.0 if hot else 11.0, Color(cc2.r, cc2.g, cc2.b, 0.25))
		_cv.draw_rect(Rect2(pp2 - Vector2(5.0, 7.0), Vector2(10, 14)), cc2, true)
		_cv.draw_rect(Rect2(pp2 - Vector2(5.0, 7.0), Vector2(10, 14)), Color(1, 1, 1, 0.95), false, 1.2)
		if yours: names.append([_w2s(pp2), ("Back: " if bool(fl.get("returning", false)) else "") + str(CARDS[_card_of(str(fl.card))].name), cc2])
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var placed := []
	for nm in names:   # on a dark backing below-right of the card; cards waiting together stack their names
		var tw := _text_w(f, str(nm[1]), 12)
		var tb := Rect2((nm[0] as Vector2) + Vector2(9.0, 4.0), Vector2(tw + 8.0, 16.0))
		var guard := 0
		while guard < 12 and placed.any(func(r): return (r as Rect2).intersects(tb)):
			tb.position.y += 17.0; guard += 1
		placed.append(tb)
		_cv.draw_rect(tb, Color(0.03, 0.05, 0.08, 0.88), true)
		_text(_cv, f, tb.position + Vector2(4.0, 12.5), str(nm[1]), 12, (nm[2] as Color).lightened(0.35))
	_paint_link_loads(f, sight, vt)
	_paint_held(f, sight)
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))
	for x in _fx:   # a card landed: an expanding frame in the caster's colour
		if not sight.has(int(x.host)): continue
		var rem := clampf((float(x.until) - _t) / 3.0, 0.0, 1.0)
		var xc: Color = x.col; xc.a = rem
		_frame(hosts[int(x.host)].pos, _r(int(x.host)) + 10.0 + (1.0 - rem) * 14.0, xc, 1.5)
	_paint_inspect_links(cx)
	if focus_on and not _mine(aim) and rig.has(PLAYER):   # the automatic attack route to the focused foreign host
		var rt := _attack_route(PLAYER, aim)
		if not rt.is_empty(): _draw_dashed(rt, Color(1, 0.95, 0.55, 0.9), 1.6)   # no route: the sidebar says so (no map note over the name)
	var dk := _aimed_card()
	if dk != "":   # a card in the air or selected: where it can land
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
	_paint_route_tag(f)
	_paint_drag_preview(f)
	if _camp: _paint_camp_guide(f)
	_paint_flight_tip(f)


func _picked() -> int:   # the one host whose panel is open: your selected host, or the foreign host you inspect
	if sel.size() == 1: return int(sel.keys()[0])
	return _inspect


const ROUTE_HOME_COL := Color(0.4, 1.0, 0.7)
func _paint_inspect_links(cx: Dictionary) -> void:   # world space: the picked host's links you can see, its route home, any cut-off hosts
	var i := _picked()
	if not _host_ok(i) or not (cx.vis as Dictionary).has(i): return
	var sight: Dictionary = cx.sight
	for nb in hosts[i].links:   # never a link into fog: both ends on your map, and the street touches your sight (as for packets)
		var n := int(nb)
		if (cx.vis as Dictionary).has(n) and (sight.has(i) or sight.has(n)): _cv.draw_line(hosts[i].pos, hosts[n].pos, Color(0.75, 0.85, 1.0, 0.4), 1.2, true)
	if not _mine(i) or i == int(rig.get(PLAYER, -1)): return
	var rt := _home_route(PLAYER, i)
	if rt.is_empty():
		for c in _cut_off(i): _frame(hosts[int(c)].pos, _r(int(c)) + 7.0, Color(C_BAD, 0.85), 2.0)
		return
	var pts := PackedVector2Array()
	for n in rt: pts.append(hosts[int(n)].pos)
	_cv.draw_polyline(pts, Color(ROUTE_HOME_COL, 0.2), 6.0, true)
	_cv.draw_polyline(pts, Color(ROUTE_HOME_COL, 0.95), 2.0, true)
	for k in range(rt.size() - 1):   # a chevron at each link's middle, pointing home
		var a: Vector2 = hosts[int(rt[k])].pos; var b: Vector2 = hosts[int(rt[k + 1])].pos
		var dir := (b - a).normalized(); var perp := Vector2(-dir.y, dir.x); var mid := a.lerp(b, 0.5)
		_cv.draw_colored_polygon(PackedVector2Array([mid + dir * 5.0, mid - dir * 3.0 + perp * 4.5, mid - dir * 3.0 - perp * 4.5]), ROUTE_HOME_COL)


func _paint_route_tag(f: Font) -> void:   # screen space: hops and travel time home beside your selected host
	var i := _picked()
	if not _mine(i) or i == int(rig.get(PLAYER, -1)): return
	var line := _route_home_line(i)
	var none := line.ends_with("none")
	var txt := "No route home" if none else line.trim_prefix("Route home: ") + " home"
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var home := int(rig.get(PLAYER, -1))
	var away: Vector2 = (hosts[i].pos as Vector2) - (hosts[home].pos as Vector2) if home >= 0 else Vector2.RIGHT
	_camp_pill(f, _w2s(hosts[i].pos), maxf(16.0, _r(i) * _zoom), txt, C_BAD if none else ROUTE_HOME_COL, away)
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))


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
	box.position = box.position.clamp(inside.position, inside.end - box.size)   # never cut by the map's edge
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


const COURIER_COL := Color(0.5, 1.0, 0.7)   # an empty worker of yours
func _cargo_res(fl: Dictionary) -> String:   # what a worker carries ("" when it travels empty)
	var cg: Dictionary = fl.get("cargo", {})
	return "" if cg.is_empty() else str(cg.keys()[0])


func _res_col(res: String) -> Color: return BUILD_KINDS[_COST_ICON[res]].col


func _flight_dir(fl: Dictionary, now: float) -> Vector2:   # the way a packet is heading on its current link (zero while it waits)
	var seg := _flight_segment(fl, now)
	if seg.x == seg.y: return Vector2.ZERO
	return ((hosts[seg.y].pos as Vector2) - (hosts[seg.x].pos as Vector2)).normalized()


func _paint_card_path(fl: Dictionary, vt: float) -> void:   # world space: the rest of your card's way, dashed in its family's colour
	var cc: Color = FAMILY_COL[str(CARDS[_card_of(str(fl.card))].fam)]
	var rt: Array = fl.route; var hops: Array = fl.hops
	var nxt := rt.size() - 1
	for k in hops.size():
		if vt < float(hops[k]) + float(fl.get("lt", LINK_TIME)): nxt = k + 1; break
	var path := [_packet_pos(fl, vt)]
	for k in range(nxt, rt.size()): path.append(hosts[int(rt[k])].pos)
	for k in range(path.size() - 1):
		var a2: Vector2 = path[k]; var b2: Vector2 = path[k + 1]
		var ln := a2.distance_to(b2); var dir := (b2 - a2) / maxf(ln, 0.001); var d := 0.0
		while d < ln:
			_cv.draw_line(a2 + dir * d, a2 + dir * minf(d + 6.0, ln), Color(cc.r, cc.g, cc.b, 0.5), 1.2, true)
			d += 11.0


func _paint_link_loads(f: Font, sight: Dictionary, vt: float) -> void:   # screen space: on each link your couriers cross, what and how many, which way
	var loads := {}   # Vector2i(from, to) -> {res: units} ("" = empty couriers)
	for fl in flights:
		if str(fl.kind) != "courier" or int(fl.owner) != PLAYER or bool(fl.get("blocked", false)): continue
		var seg := _flight_segment(fl, vt)
		if seg.x == seg.y: continue
		if not loads.has(seg): loads[seg] = {}
		var res := _cargo_res(fl)
		loads[seg][res] = int((loads[seg] as Dictionary).get(res, 0)) + 1
	for seg in loads:
		var a := _w2s(hosts[(seg as Vector2i).x].pos); var b := _w2s(hosts[(seg as Vector2i).y].pos)
		if a.distance_to(b) < 90.0 or not (sight.has((seg as Vector2i).x) or sight.has((seg as Vector2i).y)): continue   # too short to label
		var dir := (b - a).normalized(); var perp := Vector2(-dir.y, dir.x)
		var at := a.lerp(b, 0.5) + perp * 12.0   # each direction on its own side of the link
		var parts: Array = []
		for res in RES:
			if (loads[seg] as Dictionary).has(res): parts.append([res, int(loads[seg][res])])
		if (loads[seg] as Dictionary).has(""): parts.append(["", int(loads[seg][""])])
		var w := 14.0
		for pr in parts: w += 26.0 + _text_w(f, str(pr[1]), 11)
		var box := Rect2(at.x - w * 0.5, at.y - 8.0, w, 16.0)
		_cv.draw_rect(box, Color(0.03, 0.05, 0.08, 0.82), true)
		var c0 := box.position + Vector2(7.0, 8.0)   # the arrow: which way this load is going
		_cv.draw_colored_polygon(PackedVector2Array([c0 + dir * 4.5, c0 - dir * 3.0 + perp * 3.5, c0 - dir * 3.0 - perp * 3.5]), C_DIM)
		var x := box.position.x + 14.0
		for pr in parts:
			var res := str(pr[0])
			if res == "": _cv.draw_arc(Vector2(x + 6.0, at.y), 3.2, 0.0, TAU, 12, COURIER_COL, 1.4, true)
			else: _draw_kind_icon(_cv, _COST_ICON[res], Vector2(x + 6.0, at.y), 11.0, _res_col(res), f)
			_text(_cv, f, Vector2(x + 13.0, at.y + 4.0), str(pr[1]), 11, C_TEXT)
			x += 26.0 + _text_w(f, str(pr[1]), 11)


func _paint_held(f: Font, sight: Dictionary) -> void:   # screen space: a red tag on each host where your packets wait for a way on
	_held_rects = {}
	var n := {}
	for fl in flights:
		if bool(fl.get("blocked", false)) and int(fl.owner) == PLAYER: n[int(fl.at)] = int(n.get(int(fl.at), 0)) + 1
	for i in n:
		var p := _w2s(hosts[int(i)].pos); var r := maxf(16.0, _r(int(i)) * _zoom)
		var txt := "%d held" % int(n[i])
		var w := _text_w(f, txt, 12) + 24.0
		var box := Rect2(p.x + r * 0.6, p.y - r - 4.0, w, 18.0)
		_cv.draw_rect(box, Color(0.12, 0.03, 0.03, 0.92), true); _cv.draw_rect(box, C_BAD, false, 1.5)
		_cv.draw_texture_rect(UiIcons.texture("pause", 12), Rect2(box.position + Vector2(5.0, 3.0), Vector2(12, 12)), false, C_BAD)
		_text(_cv, f, box.position + Vector2(20.0, 13.5), txt, 12, C_BAD)
		_held_rects[int(i)] = box


func _flight_at(mouse: Vector2) -> int:   # the id of your (or a visible) moving packet under the mouse, -1 if none
	if menu_open or flights.is_empty(): return -1
	var vt := _t + minf(_sim_acc, SIM_DT)
	var best := -1; var bd := 11.0
	for fl in flights:
		if bool(fl.get("blocked", false)) or str(fl.kind) == "scan" or not _flight_visible(PLAYER, fl): continue
		var d := _w2s(_packet_pos(fl, vt)).distance_to(mouse)
		if d < bd: bd = d; best = int(fl.id)
	return best


func _flight_lines(fl: Dictionary) -> Array:   # what the details beside a packet say
	var out := []
	var eta := maxf(0.0, float(fl.arrive_t) - _t)
	var dest := int(fl.get("dest", -1))
	var dname := str(hosts[dest].name) if _host_ok(dest) and _visible_to(PLAYER, dest) else "a host you cannot see"
	if int(fl.owner) != PLAYER:
		out.append("%s %s" % [fname(int(fl.owner)), "operation" if str(fl.kind) == "op" else "courier"])
		out.append("Heading to " + dname)
		return out
	if str(fl.kind) == "op":
		var recipe := _card_of(str(fl.card))
		out.append("%s → %s" % [str(CARDS[recipe].name), str(hosts[int(fl.target)].name)])
		if bool(fl.get("returning", false)): out.append("Coming back to your hand (%ds)" % ceili(eta))
		elif bool(fl.get("blocked", false)): out.append("Held at %s: the way on is cut" % str(hosts[int(fl.at)].name))
		else:
			out.append("Arrives in %ds" % ceili(eta))
			if _is_defense(recipe): out.append("Loads a Firewall socket on arrival" if bool(fl.get("load", false)) else "Acts on arrival")
			elif recipe == "recon": out.append("Chance: %d%%" % _pct(RECON_CHANCE))
			else:   # judged when it draws: on arrival, or when a capture, Worm stage or raid has executed
				var at := float(fl.arrive_t) + (_exec_time(recipe, int(fl.target)) if str(CARDS[recipe].effect) in ["capture", "worm", "vault"] else 0.0)
				var c := _op_chance(PLAYER, int(fl.target), recipe, at)
				out.append("Chance: %d%% (%s)" % [_pct(c), "scouted" if _recon_fresh(PLAYER, int(fl.target), at) else "unscouted"])
		return out
	var res := _cargo_res(fl)
	var origin := int(fl.origin)
	var station := int((workers.get(int(fl.get("wid", -1)), {}) as Dictionary).get("home", origin))
	out.append("Worker #%d (station on %s)" % [int(fl.get("wid", 0)), str(hosts[station].name)])
	if bool(fl.get("blocked", false)): out.append("Held at %s: the way on is cut" % str(hosts[int(fl.at)].name))
	if str(fl.trip) == "join": out.append("Joining your workers at the main node" + ((", with 1 %s" % str(RES_NAME[res])) if res != "" else ""))
	elif str(fl.trip) == "out":
		if res != "": out.append("Carrying 1 %s to %s" % [str(RES_NAME[res]), dname])
		else: out.append("Going to collect from " + dname)
	else: out.append(("Bringing 1 %s home" % str(RES_NAME[res])) if res != "" else "Coming home empty")
	if not bool(fl.get("blocked", false)): out.append("Arrives in %ds" % ceili(eta))
	return out


func _paint_flight_tip(f: Font) -> void:   # screen space: the details of the packet (or held packets) under the mouse
	var lines := []
	var mouse := get_local_mouse_position()
	if _hover_flight >= 0:
		for fl in flights:
			if int(fl.id) == _hover_flight: lines = _flight_lines(fl); break
	else:
		for i in _held_rects:
			if not (_held_rects[i] as Rect2).has_point(mouse): continue
			for fl in flights:
				if bool(fl.get("blocked", false)) and int(fl.owner) == PLAYER and int(fl.at) == int(i):
					var l := _flight_lines(fl)
					lines.append(str(l[0]) + (" · " + str(l[1]) if l.size() > 1 and str(l[0]).begins_with("Worker") and not str(l[1]).begins_with("Held") else ""))
			if not lines.is_empty(): lines.push_front("Held at %s: the way on is cut" % str(hosts[int(i)].name))
			break
	if lines.is_empty(): return
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var w := 0.0
	for l in lines: w = maxf(w, _text_w(f, str(l), 13))
	var box := Rect2(mouse + Vector2(16.0, 12.0), Vector2(w + 18.0, 8.0 + 18.0 * lines.size()))
	var view := get_viewport_rect().size
	if box.end.x > view.x - 8.0: box.position.x = mouse.x - 16.0 - box.size.x
	if box.end.y > view.y - 8.0: box.position.y = mouse.y - 12.0 - box.size.y
	_cv.draw_rect(box, Color(0.03, 0.05, 0.08, 0.95), true); _cv.draw_rect(box, Color(0.35, 0.55, 0.7, 0.9), false, 1.0)
	for k in lines.size(): _text(_cv, f, box.position + Vector2(9.0, 18.0 + 18.0 * k), str(lines[k]), 13, C_TEXT if k == 0 else C_DIM)
	_cv.draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))


func _draw_ghost(f: Font, i: int) -> void:   # a host you saw before but cannot see now: a dim outline — no owner, no bots
	var p := _w2s(hosts[i].pos)
	var rr := maxf(16, _r(i) * _zoom)
	_cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_draw_type_glyph(_cv, _public_type(i), p, rr * 1.9, Color(0.42, 0.48, 0.58, 0.2), Color(0.04, 0.06, 0.1, 0.22))
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


func _visible_bot_count(i: int) -> String:   # the slot badge: yours, or a host a fresh Recon saw; nothing on an unknown host
	if _mine(i): return "%d/%d" % [_standing(i), int(hosts[i].slots)]
	if not _recon_fresh(PLAYER, i): return ""
	var seen := 0
	for b in ((recon.get(PLAYER, {}) as Dictionary).get(i, {}) as Dictionary).get("builds", []):
		if str(b) != "": seen += 1
	return "%d/%d" % [seen, int(hosts[i].slots)]


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
	_draw_type_glyph(_cv, _public_type(i), p, rr * 1.9, fill, ink)   # the building IS its pictogram (a plain marker until you know it)
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
	var sec_txt := _visible_bot_count(i)
	if sec_txt != "":   # no badge at all on a host you know nothing about
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
	if not _known_host(PLAYER, i):   # an unknown host: its own defences and states stay hidden (as in its inspector)
		var sp0: Dictionary = hosts[i].get("siphon", {})
		if _ddos_down(i): sub = "DDoS %ds" % int(ceil(float(hosts[i].ddos_until) - _t))
		elif _phished(i) and int(hosts[i].get("steal_by", -1)) == PLAYER: sub = "PHISHED %ds" % int(ceil(float(hosts[i].steal_until) - _t))
		elif not sp0.is_empty() and int(sp0.get("by", -1)) == PLAYER and float(sp0.get("until", 0.0)) > _t: sub = "SIPHON %ds" % int(ceil(float(sp0.until) - _t))
	elif _ddos_down(i): sub = "DDoS %ds" % int(ceil(float(hosts[i].ddos_until) - _t))
	elif _sabotaged(i): sub = "SABOT %ds" % int(ceil(float(hosts[i].sabot_until) - _t))
	elif _phished(i): sub = "PHISHED %ds" % int(ceil(float(hosts[i].steal_until) - _t))
	elif not (hosts[i].get("siphon", {}) as Dictionary).is_empty() and float((hosts[i].siphon as Dictionary).get("until", 0.0)) > _t: sub = "SIPHON %ds" % int(ceil(float(hosts[i].siphon.until) - _t))
	elif float(hosts[i].get("patch_armed_until", 0.0)) > _t: sub = "PATCH"
	elif float(hosts[i].get("express_until", 0.0)) > _t: sub = "EXPRESS"
	for e in _execs:
		if int(e.target) == i and (_known_host(PLAYER, i) or int(e.fac) == PLAYER): sub = "%s %ds" % [str(CARDS[str(e.card)].short).to_upper(), int(ceil(float(e.ends) - _t))]; break
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
		"wall":   # a brick wall: three courses, the middle one offset
			var bw := sz * 0.3; var bh := sz * 0.22; var gap := sz * 0.04
			for row in 3:
				var y := centre.y - sz * 0.38 + float(row) * (bh + gap)
				var x0 := centre.x - sz * 0.46 - (bw * 0.5 if row == 1 else 0.0)
				for k in 4:
					var x := x0 + float(k) * (bw + gap)
					var l := maxf(x, centre.x - sz * 0.46); var r := minf(x + bw, centre.x + sz * 0.46)
					if r - l > gap: c.draw_rect(Rect2(l, y, r - l, bh), col, true)
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
		"unknown":   # a host you know nothing about: a plain hexagon with a dot, the same for every kind of building
			var pts := PackedVector2Array()
			for k in 6: pts.append(centre + Vector2.from_angle(TAU * float(k) / 6.0 - PI / 2.0) * sz * 0.4)
			c.draw_colored_polygon(pts, Color(fill.r, fill.g, fill.b, fill.a * 0.75))
			pts.append(pts[0]); c.draw_polyline(pts, ink, w, true)
			c.draw_circle(centre, sz * 0.07, ink)
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
			"Drawer":      # the cards drawer: three bars
				for k in 3: draw_line(centre + Vector2(-11, -7 + 7 * k), centre + Vector2(11, -7 + 7 * k), col, 2.5, true)
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


class HudBar extends Control:   # the HUD: each bank's stock and its recent net rate, then the objective
	var game

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS   # hover shows a bank's flows; a click opens the Economy overview
		clip_contents = true            # a hard guard: the row can never bleed under the right panel
		tooltip_text = " "

	func _get_tooltip(at: Vector2) -> String:
		var x := 0.0
		for it in game._hud_items():
			if at.x >= x and at.x < x + float(it[3]): return game._econ_tooltip(str(it[4]))
			x += float(it[3])
		return game._objective_tooltip()

	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			game._toggle_economy(); accept_event()

	func _draw() -> void:
		var f := get_theme_default_font()
		var x := 0.0
		for it in game._hud_items():
			var kind := str(it[0])
			var tx := x
			if kind != "":
				game._draw_kind_icon(self, kind, Vector2(x + 9.0, 20.0), 16.0, game.BUILD_KINDS[kind].col, f)
				tx += 22.0
			var fs: int = game._hud_fs(f, str(it[1]), float(it[3]) - (tx - x))
			game._text(self, f, Vector2(tx, 26.0), str(it[1]), fs, it[2])
			var rate: Array = game._hud_rate(str(it[4]))   # recent net flow into this bank, per minute
			game._text(self, f, Vector2(tx, 44.0), str(rate[0]), 12, rate[1], float(it[3]) - (tx - x) - 4.0, HORIZONTAL_ALIGNMENT_LEFT)
			x += float(it[3])   # a fixed column: the next item never moves when this number grows
		var obj: Array = game._objective_lines()   # the win, always on screen: needed / total, your count, who holds it
		var room := size.x - x - 8.0
		if room > 120.0:
			draw_line(Vector2(x, 8.0), Vector2(x, size.y - 8.0), Color(game.C_DIM, 0.35), 1.0)
			game._text(self, f, Vector2(x + 12.0, 22.0), str(obj[0]), 12, game.C_WARN, room - 12.0, HORIZONTAL_ALIGNMENT_LEFT)
			game._text(self, f, Vector2(x + 12.0, 40.0), str(obj[1]), 12, obj[2], room - 12.0, HORIZONTAL_ALIGNMENT_LEFT)





class CardTile extends Control:   # a recipe: what it does, copies ready and queued; + Queue (or Research for a locked one)
	var game
	var key := "phishworm:linked"
	var stop_button: Button
	var queue_button: Button
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
		stop_button = Button.new(); stop_button.text = "Remove"; stop_button.name = "CancelResearch"   # a quiet link: the newest queued copy goes
		stop_button.focus_mode = Control.FOCUS_NONE
		game._link_button_style(stop_button)
		stop_button.tooltip_text = "Remove the newest queued copy of this card (a copy being made refunds its unworked share)."
		stop_button.pressed.connect(game._card_research_cancel.bind(key)); add_child(stop_button)
		queue_button = Button.new(); queue_button.name = "Queue"; queue_button.focus_mode = Control.FOCUS_NONE
		queue_button.add_theme_font_size_override("font_size", 13)
		game._fixed_button_style(queue_button)
		queue_button.pressed.connect(_act); add_child(queue_button)
		tooltip_text = game._card_tooltip(key)   # the full lead + rules (the face shows whole sentences that fit)
	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)
	func _process(_dt: float) -> void:
		var state: Dictionary = game._card_research_state(key)
		stock_material.set_shader_parameter("saturation", 0.0 if int(state.count) == 0 else 1.0)
		stop_button.visible = int(state.n) > 0
		stop_button.size = Vector2(70, 22); stop_button.position = Vector2(size.x - 14 - 70, size.y - 56)
		var act: Array = game._recipe_action(key)
		queue_button.text = str(act[0]); queue_button.disabled = not bool(act[1]); queue_button.tooltip_text = str(act[2])
		queue_button.size = Vector2(96, 26); queue_button.position = Vector2(size.x - 14 - 96, size.y - 30)
		queue_redraw(); (get_child(0) as CanvasItem).queue_redraw()
	func _act() -> void: game._recipe_act(key)
	func _gui_input(event: InputEvent) -> void:   # the body only explains; + Queue (or Research) is the action. Enter = the action
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
			_act(); accept_event()
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
		game._text(self, font, Vector2(90, 58), "READY", 10, game.C_DIM)
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
		var status := "%s · %d%%" % [str(state.status), int(float(state.progress) * 100)] if str(state.status) in ["Making", "Paused", "Researching"] else str(state.status)
		game._text(self, font, Vector2(14, size.y - 41), status, 13, status_colour, size.x - 110, HORIZONTAL_ALIGNMENT_LEFT)
		draw_rect(Rect2(14, size.y - 34, size.x - 28 - 104, 6), Color(0.17, 0.20, 0.26))
		draw_rect(Rect2(14, size.y - 34, (size.x - 28 - 104) * float(state.progress), 6), status_colour)
		game._text(self, font, Vector2(14, size.y - 12), game._recipe_hint(key), 12, game.C_DIM, size.x - 28 - 104, HORIZONTAL_ALIGNMENT_LEFT)


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


class ResearchBar extends Control:   # always on screen: what is being researched, on which track, how far, and whether it moves
	var game
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = " "
	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)
	func _get_tooltip(_at: Vector2) -> String:
		var st: Dictionary = game._research_bar_state()
		match str(st.state):
			"idle": return "Nothing is being researched. Open Research (R), select a blueprint, then Research. Research costs Intel, Crypto and Research while it runs."
			"paused": return "%s is paused at %d%%. Open Research (R) and resume it." % [str(st.name), int(float(st.frac) * 100)]
			"stalled": return "%s has stopped at %d%%: %s. It continues by itself once your bank has it." % [str(st.name), int(float(st.frac) * 100), str(st.why)]
		if str(st.get("slow", "")) != "": return "Researching %s (%s track): %d%%, %s. It pays as it goes and goes faster once your bank keeps up. Click to open Research." % [str(st.name), str(st.track), int(float(st.frac) * 100), str(st.slow)]
		return "Researching %s (%s track): %d%%, %d s of work left. It pays as it goes. Click to open Research." % [str(st.name), str(st.track), int(float(st.frac) * 100), ceili(float(st.left))]
	func _process(_dt: float) -> void:
		var on: bool = not game.menu_open and not game.won and not game.lost and str(game._research_bar_state().state) != "idle"
		if visible != on: visible = on   # only while research runs: an idle bar says nothing useful
		if on: queue_redraw()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			game._toggle_research(); accept_event()
	func _draw() -> void:
		var f := get_theme_default_font()
		var st: Dictionary = game._research_bar_state()
		var state := str(st.state)
		var col: Color = {"active": Color(0.72, 0.55, 1.0), "paused": game.C_WARN, "stalled": game.C_BAD}.get(state, game.C_DIM)
		var hot := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.1, 0.92).lightened(0.05 if hot else 0.0))
		if state != "idle": draw_rect(Rect2(1, 1, (size.x - 2) * float(st.frac), size.y - 2), Color(col, 0.22))
		draw_rect(Rect2(0.5, 0.5, size.x - 1, size.y - 1), Color(col, 0.85), false, 1.0)
		game._draw_kind_icon(self, "lab", Vector2(15, size.y * 0.5), 15.0, col, f)
		var head := "RESEARCH"
		game._text(self, f, Vector2(28, size.y * 0.5 + 5), head, 12, col)
		var x: float = 28.0 + game._text_w(f, head, 12) + 10.0
		var txt := ""
		match state:
			"idle": txt = "idle · %d blueprint%s open · press R" % [int(st.open), "" if int(st.open) == 1 else "s"] if int(st.open) > 0 else "idle · nothing open to research"
			"active": txt = ("%s · %s · %d%% · slowed" % [str(st.name), str(st.track), int(float(st.frac) * 100)]) if str(st.get("slow", "")) != "" else "%s · %s · %d%% · %d s left" % [str(st.name), str(st.track), int(float(st.frac) * 100), ceili(float(st.left))]
			"paused": txt = "%s · %s · %d%% · paused" % [str(st.name), str(st.track), int(float(st.frac) * 100)]
			"stalled": txt = "%s · %d%% · stalled: %s" % [str(st.name), int(float(st.frac) * 100), str(st.why)]
		game._text(self, f, Vector2(x, size.y * 0.5 + 5), txt, 13, game.C_TEXT if state == "active" else col, size.x - x - 8.0, HORIZONTAL_ALIGNMENT_LEFT)


class QueueChip extends Control:   # one of the queue's four positions: the head (made now, or waiting and why) or a waiting copy; x removes it
	var game
	var pos := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = " "
	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)
	func job() -> Dictionary:
		var q: Array = game._mq(game.PLAYER)
		return q[pos] if pos < q.size() else {}
	func state() -> Dictionary:   # {recipe, kind: empty | making | paused | waiting | queued | done, progress, text}
		var j := job()
		if j.is_empty():
			if pos == 0 and game._t - float(game._mq_done_t) < game.QUEUE_DONE_SECS: return {"recipe": "", "kind": "done", "progress": 1.0, "text": "Done: 1 ready"}
			return {"recipe": "", "kind": "empty", "progress": 0.0, "text": "Empty" if pos > 0 else "+ Queue a card"}
		var recipe := str(j.recipe)
		var out := {"recipe": recipe, "kind": "queued", "progress": 0.0, "text": "%d · waiting" % (pos + 1)}
		if pos == 0:
			if not (j.paid as Dictionary).is_empty():
				out.progress = clampf(float(j.progress) / maxf(0.001, game._make_time(recipe)), 0.0, 1.0)
				out.kind = "paused" if bool(game.mq_paused.get(game.PLAYER, false)) else "making"
				out.text = ("Paused %d%%" if str(out.kind) == "paused" else "Making %d%%") % int(float(out.progress) * 100)
			else:
				out.kind = "waiting"; out.text = game._mq_head_why_short(game.PLAYER)
				if str(out.text) == "": out.kind = "making"; out.text = "Starting"   # it can pay: it starts on the next step
		return out
	func _get_tooltip(_at: Vector2) -> String:
		var st := state()
		if str(st.recipe) == "": return "The manufacturing queue holds %d copies, the one being made included. Open the recipes (C) and use + Queue." % game.QUEUE_SIZE
		var nm := str(game.CARDS[str(st.recipe)].name)
		match str(st.kind):
			"making": return "Making %s. Its price is paid. x cancels it and refunds the unworked share." % nm
			"paused": return "%s is paused with the queue. Resume continues it; x cancels it." % nm
			"waiting": return "%s waits to start. %s. Nothing behind it starts first. x removes it (nothing was spent)." % [nm, game._mq_head_why(game.PLAYER)]
		return "%s is number %d in the queue. It is made when the ones before it are done. x removes it (nothing was spent)." % [nm, pos + 1]
	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
		var j := job()
		if not j.is_empty() and event.position.x >= size.x - 24.0: game._cmd(["unqueue", int(j.id)])
		elif j.is_empty(): game._open_drawer("attack" if game._card_bank not in ["attack", "defense"] else game._card_bank)
		accept_event(); queue_redraw()
	func _draw() -> void:
		var f := get_theme_default_font()
		var st := state()
		var recipe := str(st.recipe)
		var kind := str(st.kind)
		var fam: Color = game.FAMILY_COL[str(game.CARDS[recipe].fam)] if recipe != "" else game.C_DIM
		var edge: Color = {"making": fam, "paused": game.C_WARN, "waiting": game.C_BAD, "done": game.C_GOOD, "queued": Color(0.4, 0.46, 0.56)}.get(kind, Color(0.25, 0.29, 0.36))
		var hot := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.075, 0.105).lightened(0.05 if hot else 0.0))
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), edge, false, 2 if kind in ["making", "waiting", "done"] else 1)
		if recipe == "":
			game._text(self, f, Vector2(10, size.y * 0.5 + 5), str(st.text), 12, game.C_GOOD if kind == "done" else game.C_DIM, size.x - 16, HORIZONTAL_ALIGNMENT_LEFT)
			return
		game._draw_card_glyph(self, recipe, Vector2(16, size.y * 0.5 - 1), 22, Color(1, 1, 1, 0.6 if kind == "queued" else 1.0), f)
		var room := size.x - 30.0 - 22.0
		game._text(self, f, Vector2(30, 16), str(game.CARDS[recipe].short), 12, game.C_TEXT, room, HORIZONTAL_ALIGNMENT_LEFT)
		var short: Dictionary = game._mq_head_short_whole(game.PLAYER) if kind == "waiting" else {}
		if not short.is_empty():   # what the head lacks, as icons and amounts ("Needs" in front when it fits)
			var row: float = game._draw_cost_row(self, short, -1.0, Vector2(30, 28), 11, 11.0, false)
			var x0 := 30.0
			if game._text_w(f, "Needs", 11) + 4.0 + row <= room:
				game._text(self, f, Vector2(30, 32), "Needs", 11, edge, room, HORIZONTAL_ALIGNMENT_LEFT); x0 += game._text_w(f, "Needs", 11) + 4.0
			game._draw_cost_row(self, short, -1.0, Vector2(x0, 28), 11, 11.0)
		else: game._text(self, f, Vector2(30, 32), str(st.text), 11, edge if kind != "queued" else game.C_DIM, room, HORIZONTAL_ALIGNMENT_LEFT)
		if kind in ["making", "paused"]:
			draw_rect(Rect2(3, size.y - 5, size.x - 6, 3), Color(0.17, 0.20, 0.26))
			draw_rect(Rect2(3, size.y - 5, (size.x - 6) * float(st.progress), 3), edge)
		var c := Vector2(size.x - 12, size.y * 0.5)   # remove / cancel
		draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), game.C_BAD, 2, true); draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), game.C_BAD, 2, true)


class ReadyChip extends Control:   # one ready card in the strip: drag it onto a host, or click it (selected) and then click a host
	var game
	var key := ""
	var press_position := Vector2.ZERO
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _ready() -> void:
		tooltip_text = game._card_tooltip(key) + "\n\nDrag onto a host, or click to select and then click a host."
	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)
	func _get_drag_data(_pos: Vector2) -> Variant:
		return game._card_drag_data(self, key)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: press_position = event.position
			elif Rect2(Vector2.ZERO, size).has_point(event.position) and press_position.distance_to(event.position) <= 8:
				game._arm_card(key); accept_event()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT: queue_redraw()
	func _draw() -> void:
		game._draw_ready_face(self, key, false)


class ReadyTile extends Control:   # one ready card in the drawer: picture, copies, what it does, where it goes; drag or click to select
	var game
	var key := ""
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
	func res_box(k: int) -> Rect2: return Rect2(size.x - 4.0 * 30.0 - 8.0 + k * 30.0, size.y - 32.0, 26.0, 24.0)   # a Packet siphon's resource choice
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: press_position = event.position
			elif Rect2(Vector2.ZERO, size).has_point(event.position) and press_position.distance_to(event.position) <= 8:
				if str(game.CARDS[game._card_of(key)].effect) == "siphon":
					for k in 4:
						if res_box(k).has_point(event.position):
							game._chosen_siphon_res = game.SIPHON_RES[k]; queue_redraw(); accept_event(); return
				game._arm_card(key); accept_event()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT: queue_redraw()
	func _draw() -> void:
		game._draw_ready_face(self, key, true)
		if str(game.CARDS[game._card_of(key)].effect) == "siphon":
			var f := get_theme_default_font()
			game._text(self, f, Vector2(12, size.y - 14), "Takes:", 11, game.C_DIM)
			for k in 4:
				var res: String = game.SIPHON_RES[k]
				var r := res_box(k)
				var on: bool = game._chosen_siphon_res == res
				draw_rect(r, Color(0.1, 0.13, 0.18) if not on else Color(game._res_col(res), 0.25), true)
				draw_rect(r, game._res_col(res) if on else Color(0.3, 0.34, 0.42), false, 2 if on else 1)
				game._draw_kind_icon(self, game._COST_ICON[res], r.get_center(), 14.0, game._res_col(res), f)


class ResearchInfo extends Control:   # the RESEARCH view's top row: the selected blueprint, its price and time, and its action
	var game
	var action_button: Button
	var cancel_button: Button
	func _ready() -> void:
		action_button = Button.new(); action_button.name = "ResearchAction"; action_button.focus_mode = Control.FOCUS_NONE
		action_button.custom_minimum_size = Vector2(170, 36); action_button.add_theme_font_size_override("font_size", 15)
		action_button.pressed.connect(game._research_act); add_child(action_button)
		cancel_button = Button.new(); cancel_button.name = "ResearchCancel"; cancel_button.text = "Cancel research"
		cancel_button.focus_mode = Control.FOCUS_NONE; game._link_button_style(cancel_button)
		cancel_button.tooltip_text = "Stop it: what it has used is not refunded."
		cancel_button.pressed.connect(func(): game._cmd(["cancel_research"])); add_child(cancel_button)
	func _process(_dt: float) -> void:
		if not visible: return
		var act: Array = game._research_action(game._research_sel)
		action_button.text = str(act[0]); action_button.disabled = not bool(act[1])
		action_button.size = action_button.custom_minimum_size
		action_button.position = Vector2(size.x - action_button.size.x - 8, (size.y - action_button.size.y) * 0.5)
		var job: Dictionary = game.research_job.get(game.PLAYER, {})
		cancel_button.visible = not job.is_empty() and str(job.get("key", "")) == game._research_sel
		cancel_button.size = cancel_button.get_combined_minimum_size()
		cancel_button.position = Vector2(action_button.position.x - cancel_button.size.x - 10, (size.y - cancel_button.size.y) * 0.5)
		queue_redraw()
	func _draw() -> void:
		var f := get_theme_default_font()
		var r: String = game._research_sel
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.06, 0.09))
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), game.SELECT_COL if r != "" else Color(0.3, 0.34, 0.42), false, 2 if r != "" else 1)
		if r == "":
			game._text(self, f, Vector2(14, size.y * 0.5 + 5), "Select a blueprint in the tree to see its price and research it.", 14, game.C_DIM, size.x - 200, HORIZONTAL_ALIGNMENT_LEFT)
			return
		var st: Dictionary = game._research_node_state(r)
		game._draw_card_glyph(self, r, Vector2(26, size.y * 0.5), 30, Color.WHITE, f)
		game._text(self, f, Vector2(48, 21), "Selected: %s" % str(game.CARDS[r].name), 15, game.C_TEXT, 330, HORIZONTAL_ALIGNMENT_LEFT)
		var sc: Color = {"working": Color.WHITE, "paused": game.C_WARN, "stalled": game.C_BAD, "open": game.BANK_COL.research, "known": game.C_GOOD}.get(str(st.state), game.C_DIM)
		game._text(self, f, Vector2(48, 40), str(st.line), 12, sc, 330, HORIZONTAL_ALIGNMENT_LEFT)
		if game.RESEARCH.has(r) and not game._known(game.PLAYER, r):
			game._draw_cost_row(self, game._research_cost(r), game._research_time(r), Vector2(400, size.y * 0.5), 13, 15.0)


class ResearchTree extends Control:   # the RESEARCH tab: every recipe as a node under the one it is researched from
	var game
	var col := {}; var depth := {}; var columns := 1
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _ready() -> void:
		var kids := {}
		for r in game.CARD_ORDER:
			if game.RESEARCH.has(r):
				var p := str(game.RESEARCH[r].prereq)
				if not kids.has(p): kids[p] = []
				kids[p].append(str(r))
		var next := [0]
		var place := func(self_ref: Callable, r: String, d: int) -> void:   # leaves take the next column; a parent sits over its children
			depth[r] = d
			var ch: Array = kids.get(r, [])
			if ch.is_empty():
				col[r] = float(next[0]); next[0] += 1
			else:
				for c in ch: self_ref.call(self_ref, str(c), d + 1)
				col[r] = (float(col[ch[0]]) + float(col[ch[-1]])) * 0.5
		for r in game.CARD_ORDER:
			if not game.RESEARCH.has(r): place.call(place, str(r), 0)
		columns = next[0]
		for r in game.CARD_ORDER:
			var node := ResearchNode.new(); node.game = game; node.recipe = str(r); node.name = "Research_%s" % r
			add_child(node)
		relayout()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: relayout()
	func node_rect(r: String) -> Rect2:
		var cw := size.x / float(maxi(1, columns))
		var h := 72.0; var gap := (size.y - 16.0 - 3.0 * h) / 2.0
		return Rect2(float(col[r]) * cw + 6.0, 8.0 + float(depth[r]) * (h + gap), cw - 12.0, h)
	func relayout() -> void:
		if col.is_empty(): return
		for node in get_children():
			var rect := node_rect(str(node.recipe))
			node.position = rect.position; node.size = rect.size
		queue_redraw()
	func _process(_dt: float) -> void:
		if visible: queue_redraw()
	func _draw() -> void:   # the links: a parent's bottom to each child's top, lit once the parent is known
		for r in game.CARD_ORDER:
			if not game.RESEARCH.has(r): continue
			var a := node_rect(str(game.RESEARCH[r].prereq)); var b := node_rect(str(r))
			var lit: bool = game._known(game.PLAYER, str(game.RESEARCH[r].prereq))
			var c: Color = Color(game.BANK_COL.research, 0.9) if lit else Color(0.3, 0.34, 0.42)
			var top := Vector2(a.get_center().x, a.end.y); var bottom := Vector2(b.get_center().x, b.position.y)
			var mid := (top.y + bottom.y) * 0.5
			draw_polyline(PackedVector2Array([top, Vector2(top.x, mid), Vector2(bottom.x, mid), bottom]), c, 2.0, true)


class ResearchNode extends Control:   # one recipe in the tree: known, researching, open to research, or locked
	var game
	var recipe := ""
	var press_position := Vector2.ZERO
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _ready() -> void:
		tooltip_text = game._research_tooltip(recipe)
	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)
	func _gui_input(event: InputEvent) -> void:   # click: select; double-click: select and do its action
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press_position = event.position
				if event.double_click: game._research_node_click(recipe); game._research_act(); accept_event()
			elif Rect2(Vector2.ZERO, size).has_point(event.position) and press_position.distance_to(event.position) <= 8:
				game._research_node_click(recipe); accept_event()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT: queue_redraw()
	func _draw() -> void:
		var font := get_theme_default_font()
		var card: Dictionary = game.CARDS[recipe]
		var st: Dictionary = game._research_node_state(recipe)
		var fam: Color = game.FAMILY_COL[str(card.fam)]
		var state := str(st.state)
		var hot := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
		var picked: bool = game._research_sel == recipe
		# state = the edge (known: family colour · working: white · paused: amber · stalled: red · open: violet · locked: grey);
		# hover only lifts the fill; the selection is a cyan band on top and a tinted fill, whatever the state
		var edge: Color = {"known": fam, "working": Color.WHITE, "paused": game.C_WARN, "stalled": game.C_BAD, "open": game.BANK_COL.research, "locked": Color(0.3, 0.34, 0.42)}[state]
		var fill := Color(0.055, 0.075, 0.105)
		if picked: fill = Color(0.06, 0.13, 0.17)   # a cyan-tinted fill
		if hot: fill = fill.lightened(0.06)
		draw_rect(Rect2(Vector2.ZERO, size), fill)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), edge, false, 2 if state in ["working", "open", "stalled"] else 1)
		if picked:
			draw_rect(Rect2(0, 0, size.x, 4), game.SELECT_COL)
			draw_rect(Rect2(-2, -2, size.x + 4, size.y + 4), game.SELECT_COL, false, 2)
		var dim := state == "locked"
		game._draw_card_glyph(self, recipe, Vector2(18, 18), 22, Color(1, 1, 1, 0.4 if dim else 1.0), font)
		var room := size.x - 40.0
		var title := str(card.name) if game._text_w(font, str(card.name), 13) <= room else str(card.get("short", card.name))
		game._text(self, font, Vector2(34, 22), title, 13, game.C_DIM if dim else game.C_TEXT, room, HORIZONTAL_ALIGNMENT_LEFT)
		if game.RESEARCH.has(recipe) and state in ["open", "locked"]:
			game._draw_cost_row(self, game._research_cost(recipe), -1.0, Vector2(10, 42), 11, 12.0)
		elif state == "known":
			game._text(self, font, Vector2(10, 46), "x%d ready" % game._held(game.PLAYER, recipe), 12, fam.lightened(0.3), size.x - 20, HORIZONTAL_ALIGNMENT_LEFT)
		var line_col: Color = game.C_WARN if state == "paused" else (game.C_BAD if state == "stalled" else (game.C_DIM if state in ["locked", "known"] else game.C_TEXT))
		game._text(self, font, Vector2(10, 64), str(st.line), 11, line_col, size.x - 20, HORIZONTAL_ALIGNMENT_LEFT)
		if state in ["working", "paused", "stalled"]:
			draw_rect(Rect2(10, size.y - 6, size.x - 20, 3), Color(0.17, 0.20, 0.26))
			draw_rect(Rect2(10, size.y - 6, (size.x - 20) * float(st.progress), 3), edge)


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
const BUILD_SHORT := {"bot": "2 workers", "intel": "+1 Intel", "cash": "+1 Crypto", "cred": "+1 Cred", "lab": "+1 Research", "wall": "3 sockets"}   # the compact card's one line (inputs: its tooltip)
const BUILD_EFFECT := {   # per 12-s cycle (the building tooltip says "Every 12 s")
	"bot": ["2 workers", "1 unit a leg"], "intel": ["+1 Intel", "+50 cap"], "cash": ["+1 Crypto", "uses 1 Intel"],
	"cred": ["+1 Cred", "uses 1 Intel"], "lab": ["+1 Research", "Intel+Crypto"], "wall": ["3 sockets", "uses 1 Intel"],
}
func _build_short(kind: String, host := -1) -> String:   # the compact card's one line; in a host's slot, what it makes THERE (type multiplier)
	var out := str(BUILD_KINDS[kind].out)
	if host < 0 or out == "" or not _host_ok(host): return str(BUILD_SHORT[kind])
	var amt := float(BUILD_KINDS[kind].rate) * _tmult(host, out)
	return "+%s %s" % [_amt(amt), {"intel": "Intel", "cash": "Crypto", "creds": "Cred", "research": "Research"}[out]]


func _draw_building_card(canvas: Control, kind: String, footer: String, gray := false, show_cost := false, host := -1) -> void:
	var font := canvas.get_theme_default_font()
	var w := canvas.size.x
	var colour: Color = BUILD_KINDS[kind].col if not gray else Color(0.6, 0.6, 0.6)
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.13, 0.15, 0.21) if not gray else Color(0.15, 0.15, 0.15))
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), colour, false, 2)
	if canvas.size.y < 90.0:   # the mini palette card: name 4-24 · picture 28-50 · price (what it makes: its tooltip)
		canvas.draw_rect(Rect2(4, 4, w - 8, 20), colour.darkened(0.8))
		_fit_text(canvas, str(BUILD_KINDS[kind].card), Rect2(6, 19, w - 12, 0), 12, C_TEXT)
		canvas.draw_rect(Rect2(6, 28, w - 12, 24), Color(0.04, 0.05, 0.07))
		_draw_kind_icon(canvas, kind, Vector2(w * 0.5, 40), 20, colour, font)
		if show_cost:
			var cw0 := _draw_cost_row(canvas, _build_cost(kind), -1.0, Vector2.ZERO, 11, 12.0, false)
			_draw_cost_row(canvas, _build_cost(kind), -1.0, Vector2((w - cw0) * 0.5, canvas.size.y - 10.0), 11, 12.0)
		elif footer != "": _fit_text(canvas, footer, Rect2(6, canvas.size.y - 10.0, w - 12, 0), 11, C_DIM)
		return
	if canvas.size.y < 130.0:   # the compact palette card: name 4-26 · picture 30-64 · what it makes 80 · price 99
		canvas.draw_rect(Rect2(4, 4, w - 8, 22), colour.darkened(0.8))
		_fit_text(canvas, str(BUILD_KINDS[kind].card), Rect2(6, 20, w - 12, 0), 12, C_TEXT)
		canvas.draw_rect(Rect2(6, 30, w - 12, 34), Color(0.04, 0.05, 0.07))
		_draw_kind_icon(canvas, kind, Vector2(w * 0.5, 47), 28, colour, font)
		_fit_text(canvas, _build_short(kind, host), Rect2(6, 80, w - 12, 0), 11, C_TEXT)
		if show_cost:
			var cw := _draw_cost_row(canvas, _build_cost(kind), -1.0, Vector2.ZERO, 11, 12.0, false)
			_draw_cost_row(canvas, _build_cost(kind), -1.0, Vector2((w - cw) * 0.5, 99), 11, 12.0)
		elif footer != "": _fit_text(canvas, footer, Rect2(6, 99, w - 12, 0), 11, C_DIM)
		return
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


func _text_fit_left(c: CanvasItem, f: Font, pos: Vector2, s: String, fs: int, col: Color, w: float) -> void:   # left-aligned, shrunk to fit w
	var size := fs
	while size > 8 and _text_w(f, s, size) > w: size -= 1
	_text(c, f, pos, s, size, col)


func _fit_text(c: CanvasItem, text: String, at: Rect2, fs: int, col: Color) -> void:   # centred on at.position.y, shrunk to fit the width
	var font := get_theme_default_font()
	var size := fs
	while size > 8 and _text_w(font, text, size) > at.size.x: size -= 1
	_text(c, font, at.position, text, size, col, at.size.x, HORIZONTAL_ALIGNMENT_CENTER)


class SlotBox extends Control:   # one installation slot: the compact card (name 4-26 · picture 30-64 · line 80 · state 99), a stop button when busy
	var game
	var host := -1
	var slot := 0
	var stop_button: Button
	var sockets_inside := false   # a finished Firewall: its SocketList child covers the picture (the card keeps one height)
	const STOP_H := 22.0
	func _init() -> void:
		custom_minimum_size = Vector2(112, 112)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		tooltip_text = " "
	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)
	func _get_tooltip(_at: Vector2) -> String: return game._slot_tip(host, slot)
	func _ready() -> void:
		stop_button = Button.new(); stop_button.text = "■"
		stop_button.add_theme_color_override("font_color", game.C_BAD)
		stop_button.add_theme_font_size_override("font_size", 12)
		stop_button.clip_text = true; stop_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		game._fixed_button_style(stop_button, true)
		stop_button.tooltip_text = "Cancel this project: what was delivered stays here as salvage, and workers take it home."
		stop_button.pressed.connect(game._cancel_job.bind(host, slot)); add_child(stop_button)
	func _process(_dt: float) -> void:
		if slot >= (game.hosts[host].builds as Array).size(): return   # the host lost slots (a lesson's reset): the panel is about to be rebuilt
		var busy: bool = game.hosts[host].jobs.has(slot)
		stop_button.visible = busy
		stop_button.size = Vector2(size.x, STOP_H)
		stop_button.position = Vector2(0, size.y - STOP_H)
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
		if slot >= (h.builds as Array).size(): return
		var job: Dictionary = h.jobs.get(slot, {})
		var kind := str(h.builds[slot])
		if not job.is_empty() and str(job.phase) == "build": kind = str(job.kind)
		if kind == "":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.17))
			draw_rect(Rect2(Vector2.ZERO, size), game.C_DIM, false, 1)
			game._text(self, font, Vector2(size.x * 0.5 - 8.0, size.y * 0.5 + 10.0), "+", 28, game.C_DIM)
			return
		var footer := "" if game._slot_active(host, slot) else "Inactive"
		if kind == "bot" and job.is_empty():   # a station: how many of its two workers are there
			var team: Dictionary = game._teams(host).get(slot, {})
			var alive := 0
			for wid in (team.get("w", []) as Array): if int(wid) >= 0: alive += 1
			footer = ("" if alive == game.WORKERS_PER_STATION else "%d of %d workers" % [alive, game.WORKERS_PER_STATION]) if not team.is_empty() else "Off: no workers"
		if kind in ["cash", "cred", "lab"]:
			if game._producer_paused(host, slot): footer = "Paused · click"
			elif game._slot_active(host, slot):
				footer = "Click to pause"
				for input in (game.BUILD_KINDS[kind].use as Dictionary):   # its input must be made on this host (or be in the bank at the main node)
					if not game._input_here(host, str(input)): footer = "Needs %s here" % game.RES_NAME[str(input)]
		elif kind == "wall":
			var a: int = game.FIREWALL_SOCKETS * game._wall_seat(host, slot)
			footer = "%d/%d loaded" % [game._loaded_of((h.sockets as Array).slice(a, a + game.FIREWALL_SOCKETS)).size(), game.FIREWALL_SOCKETS] if bool(h.get("fw_on", true)) else "OFF: no Intel"
		var waiting: bool = not job.is_empty() and str(job.phase) == "build" and not game._job_funded(job)
		if not job.is_empty():   # the card says the state (materials, paused); the red button cancels, with the work left on it
			footer = ""
			stop_button.text = "■  %.0fs" % float(job.left) if not waiting and not bool(job.get("paused", false)) else "■  Cancel"
		if sockets_inside and job.is_empty(): footer = ""   # its sockets say what is loaded, and OFF
		game._draw_building_card(self, kind, footer, not job.is_empty(), false, host)
		if sockets_inside and job.is_empty(): draw_rect(Rect2(4, 27, size.x - 8, 70), Color(0.13, 0.15, 0.21))   # under the sockets
		if not job.is_empty():
			var total: float = maxf(0.001, float(job.total))
			if not waiting: draw_rect(Rect2(6, size.y - STOP_H - 5.0, (size.x - 12) * (1 - float(job.left) / total), 3), Color(0.8, 0.8, 0.8))
			else:   # construction waits for its materials: how much of the bill is here
				var bill := 0.0; var here := 0.0
				for r in (job.bill as Dictionary): bill += float(job.bill[r]); here += minf(float(job.bill[r]), float((job.escrow as Dictionary).get(r, 0.0)))
				draw_rect(Rect2(4, 68, size.x - 8, 20), Color(0.12, 0.07, 0.03))
				game._fit_text(self, "Materials %d/%d" % [int(here + 0.0001), int(bill + 0.0001)], Rect2(6, 82, size.x - 12, 0), 11, game.C_WARN)
			if bool(job.get("paused", false)):   # paused by you: said on the card, above the cancel button
				draw_rect(Rect2(4, 68, size.x - 8, 20), Color(0.12, 0.10, 0.03))
				game._fit_text(self, "Paused · click", Rect2(6, 82, size.x - 12, 0), 11, game.C_WARN)



class SocketList extends Control:   # one finished Firewall's 3 socket positions, under its slot: empty, a card on its way, loaded, or off
	var game
	var host := -1
	var first := 0   # this Firewall's first position in hosts[host].sockets (_wall_seat × 3)
	const ROW := 22.0
	func _init() -> void:
		custom_minimum_size = Vector2(112, ROW * 3.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _process(_dt: float) -> void: queue_redraw()
	func state(k: int) -> Array:   # [kind, recipe]: kind = "empty" | "held" | "loaded"
		var socks: Array = game.hosts[host].sockets
		var v := str(socks[first + k]) if first + k < socks.size() else ""
		if v.begins_with("@"): return ["held", v.substr(1).split("#")[0]]
		if v != "": return ["loaded", v]
		return ["empty", ""]
	func eta(k: int) -> float:   # seconds until the card on its way to position k arrives
		var socks: Array = game.hosts[host].sockets
		var tok := str(socks[first + k]) if first + k < socks.size() else ""
		for f in game.flights:
			if str(f.get("sock", "")) == tok and tok != "": return maxf(0.0, float(f.arrive_t) - game._t)
		return -1.0
	func _draw() -> void:
		var f := get_theme_default_font()
		var on: bool = bool(game.hosts[host].get("fw_on", true))
		var drag: String = game._dragged_card()
		var can_drop: bool = drag != "" and game._socketable(game._card_of(drag)) and game._can_play(game.PLAYER, drag, host) == ""
		for k in 3:
			var r := Rect2(0, k * ROW, size.x, ROW - 3.0)
			var st := state(k)
			var a := 1.0 if on else 0.45
			match str(st[0]):
				"empty":
					draw_rect(r, Color(0.08, 0.1, 0.14, a), true)
					var dash := Color(game.C_DIM, 0.6 * a); var x := 0.0
					while x < r.size.x:   # a dashed outline: nothing loaded here
						draw_line(Vector2(x, r.position.y), Vector2(minf(x + 4.0, r.size.x), r.position.y), dash, 1.0)
						draw_line(Vector2(x, r.end.y), Vector2(minf(x + 4.0, r.size.x), r.end.y), dash, 1.0)
						x += 8.0
					game._text(self, f, r.position + Vector2(6, 14), "empty" if on else "OFF", 11, Color(game.C_DIM, a) if on else game.C_BAD)
					if can_drop and game._free_socket(host) == first + k: draw_rect(r, game.FAMILY_COL[str(game.CARDS[game._card_of(drag)].fam)], false, 2.0)
				"held":
					var cc: Color = game.FAMILY_COL[str(game.CARDS[str(st[1])].fam)]
					draw_rect(r, Color(cc.r, cc.g, cc.b, 0.12 * a), true); draw_rect(r, Color(cc, 0.7 * a), false, 1.0)
					game._draw_card_glyph(self, str(st[1]), r.position + Vector2(10, ROW * 0.5 - 1.5), 15.0, Color(1, 1, 1, 0.55 * a), f)
					var e := eta(k)
					game._text_fit_left(self, f, r.position + Vector2(21, 14), "%s %s" % [str(game.CARDS[str(st[1])].short), ("in %ds" % ceili(e)) if e >= 0.0 else "held"], 11, Color(cc.lightened(0.3), 0.8 * a), size.x - 25.0)
				"loaded":
					var cc2: Color = game.FAMILY_COL[str(game.CARDS[str(st[1])].fam)]
					draw_rect(r, Color(cc2.r, cc2.g, cc2.b, 0.3 * a), true); draw_rect(r, Color(cc2, a), false, 1.5)
					game._draw_card_glyph(self, str(st[1]), r.position + Vector2(10, ROW * 0.5 - 1.5), 15.0, Color(1, 1, 1, a), f)
					game._text_fit_left(self, f, r.position + Vector2(21, 14), str(game.CARDS[str(st[1])].short) if on else "%s · OFF" % str(game.CARDS[str(st[1])].short), 11, Color(game.C_TEXT, a) if on else game.C_BAD, size.x - 25.0)
	func _get_tooltip(at: Vector2) -> String:
		var k := clampi(int(at.y / ROW), 0, 2)
		var st := state(k)
		var on: bool = bool(game.hosts[host].get("fw_on", true))
		var off := "" if on else "\nThe Firewall is OFF: no Intel on this host, so loaded cards wait."
		match str(st[0]):
			"held": return "%s on its way: it loads here on arrival.%s" % [str(game.CARDS[str(st[1])].name), off]
			"loaded": return "%s loaded: it fires when %s.%s" % [str(game.CARDS[str(st[1])].name), str(game.SOCKET_TRIGGER[str(st[1])]), off]
		return "Empty socket. Send Patch, Incident response, Traffic filter or Cargo cover to this host: the first empty socket from the left takes it.%s" % off
	func _can_drop_data(_p: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).has("card") and game._socketable(game._card_of(str(data.card))) and game._can_play(game.PLAYER, str(data.card), host) == ""
	func _drop_data(_p: Vector2, data: Variant) -> void:
		game._cmd(["card", str(data.card), host])


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
		var kind: String = game._seen_build(game.PLAYER, host, slot)   # the Recon snapshot, not the live host
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
		tooltip_text = " "
	func _make_custom_tooltip(for_text: String) -> Object:
		return game._wrapped_tooltip(for_text)
	func _get_tooltip(_at: Vector2) -> String:
		return "%s\n\nMaterials: %s. They must reach this site before its %d s of work start; what the host has spare is used first, workers bring the rest." % [str(game.BUILD_KINDS[kind].desc), game._build_cost_text(kind), int(game.BUILD_TIME)]

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
