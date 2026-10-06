extends Node2D
## Rim MVP — world, simulation, input and rendering.
## Placeholder-graphics prototype: neon shapes on a dark grid.

# ---- Tuning constants (placeholders, meant for playtesting) ----
const MAP_W := 100
const MAP_H := 100
const TILE := 24.0
const MAX_LEN := 255.0        # max tunnel length in cells; distance is limited by loss/upkeep/speed
const LANES := 4              # tunnels that may share one cell (4 parallel lanes)
const MCHARS := "01<>|/\\=+#%*:;"   # Matrix-style code glyphs for flowing packets
# How far each structure reveals the city (tiles). You can only build within vision.
const VISION := {"hub": 16, "nest": 7, "package": 8, "botfarm": 8, "phish": 8, "scraper": 8, "salami": 8, "fence": 6, "forge": 6, "mixer": 6, "lab": 6, "relay": 15}
const LAG_PER_TILE := 1.0     # packets of latency per tile (lower = faster)
const PACKET_SPEED := 60.0    # px/second a packet travels (× slow_factor when starved)
const NEST_SPACING := 5.0     # min tiles between Compute nodes
const GOAL_CREDITS := 1000.0
const TICK_DT := 0.1
const MIN_FEED := 0.25        # a starved network never drops below this speed — always recoverable

# Per-second production (1 packet/s each; a DNS holds 3, TCP holds 10)
const RATE_NEST := 1.0        # compute
const RATE_PHISH := 1.0       # data
const RATE_SALAMI := 1.0      # credits (Cash)
const RATE_PACKAGE := 3.0     # compute (Cycles) — supply-chain compromise reaches thousands of builds
const RATE_SCRAPER := 1.5     # data (Intel) — denser than Phishing, but tech-gated & noisy
const RATE_BOTFARM := 4.0     # compute (Cycles) — cryptojacked cloud racks
const INTEL_RANGE := 6.0      # tiles an Intel collector sweeps around itself
const COVERAGE_RADIUS := 4    # tiles a hack sweeps for city buildings → scales its output

# Processors convert a stored resource into another (pulled from C2, sent back).
const CONV := {
	"fence": {"in": "data", "out": "credits", "rate": 3.0},
	"forge": {"in": "data", "out": "tools", "rate": 0.6, "fuel": "compute", "fuelcost": 3.0},
	"mixer": {"in": "crypto", "out": "credits", "rate": 2.0},
	"lab": {"in": "data", "out": "research", "rate": 0.5, "fuel": "compute", "fuelcost": 2.0},
}
# Tech tree: researching unlocks facilities. Tools not listed are available from start.
const BASE_TOOLS := ["nest", "phish", "salami", "fence", "relay", "lab", "dns", "vpn", "tcp"]
const TECH := {
	"scraping": {"name": "Web-Scraping Botnet", "cost": 10, "unlocks": ["scraper"], "requires": [], "desc": "Mass-scrape sites for Intel — dense but noisy."},
	"supply_chain": {"name": "Supply-Chain Attacks", "cost": 10, "unlocks": ["package"], "requires": [], "desc": "Typosquat package registries — heavy Cycles."},
	"cloud": {"name": "Cloud Cryptojacking", "cost": 15, "unlocks": ["botfarm"], "requires": [], "desc": "Hijack cloud racks for Cycles."},
	"laundering": {"name": "Crypto Laundering", "cost": 15, "unlocks": ["mixer"], "requires": [], "desc": "Launder stolen Crypto into clean Cash."},
	"exploits": {"name": "Exploit Development", "cost": 20, "unlocks": ["forge"], "requires": [], "desc": "Forge Tools to breach ICE."},
	"onion": {"name": "Onion Routing", "cost": 20, "unlocks": ["proxy"], "requires": [], "desc": "Long-reach anonymized tunnels."},
	"http2": {"name": "HTTP/2 Flooding", "cost": 25, "unlocks": ["http"], "requires": ["exploits"], "desc": "Huge-throughput tunnels."},
}
const ICE_TRACE := 8.0        # Trace spike each time you breach an ICE zone
const TRACE_DECAY := 1.2      # Trace/s that cools off
const TRACE_HOT := 80.0       # above this, ICE throttles the whole botnet
# C2 commands pushed out along the links
const OVERCLOCK_COST := 20.0  # Cycles to double a structure's output
const OVERCLOCK_T := 20.0      # seconds the boost lasts
const SCRUB_COST := {"compute": 40.0, "tools": 1.0}  # DDoS smokescreen → Trace 0

# Tunnel capacity (packets) and upkeep (compute / tile / second)
const CAP := {"dns": 3.0, "vpn": 6.0, "tcp": 10.0, "http": 16.0, "proxy": 5.0}
const UPKEEP := {"dns": 0.05, "vpn": 0.12, "tcp": 0.2, "http": 0.3, "proxy": 0.28}
const TUNNEL_MAXLEN := {"dns": 255, "vpn": 255, "tcp": 255, "http": 255, "proxy": 255}
# Trace/s each live tunnel adds (negative = cools): VPN is anonymizing, Reverse Shell is loud
const TUNNEL_NOISE := {"dns": 0.0, "vpn": -0.25, "tcp": 0.4, "http": 0.2, "proxy": 0.1}
# Packet loss per cell of length — long routes bleed packets; Proxy/HTTP travel best
const TUNNEL_LOSS := {"dns": 0.015, "vpn": 0.012, "tcp": 0.010, "http": 0.006, "proxy": 0.004}
# Per-node relay throughput (packets/s a node can pass through). Any node can be a merge
# point now; past LINK_SOFT incoming links a node starts to overload (#5).
const NODE_CAP := {"hub": 999.0, "relay": 20.0, "fence": 12.0, "forge": 12.0, "mixer": 12.0, "lab": 12.0, "nest": 6.0, "package": 6.0, "botfarm": 6.0, "phish": 6.0, "scraper": 6.0, "salami": 6.0}
const LINK_SOFT := 4   # incoming links beyond this start to choke the node
# Contract clients (fictional darknet buyers) — flavor for the jobs board
const CLIENTS := ["Azevedo Syndicate", "Null Collective", "GRAYHAT ltd", "The Undertow", "Meridian Black", "K0LD Crew", "Vantablack Group"]

# Build costs
const COST := {
	"nest":   {"compute": 10.0},
	"package": {"compute": 40.0, "data": 10.0, "credits": 40.0},
	"scraper": {"compute": 15.0},
	"botfarm": {"compute": 30.0, "data": 10.0, "credits": 60.0},
	"forge":  {"compute": 30.0, "data": 10.0, "credits": 30.0},
	"mixer":  {"compute": 25.0, "data": 5.0, "credits": 50.0},
	"lab":    {"compute": 25.0, "data": 10.0},
	"relay":  {"compute": 15.0},
	"phish":  {"compute": 12.0},
	"salami": {"compute": 30.0, "data": 20.0, "credits": 30.0},
	"fence":  {"compute": 25.0},
	"dns":    {"compute": 5.0},
	"vpn":    {"compute": 20.0, "credits": 10.0},
	"tcp":    {"compute": 20.0, "credits": 10.0},
	"http":   {"compute": 35.0, "credits": 25.0},
	"proxy":  {"compute": 25.0, "credits": 15.0, "tools": 1.0},
}

# Building footprint side length in tiles (Hub 3×3=9, others 2×2=4)
const SIZE := {
	"hub": 3, "nest": 2, "phish": 2, "salami": 2, "fence": 2, "package": 2, "scraper": 2, "botfarm": 2, "forge": 2, "mixer": 2, "lab": 2,
}

# Node type colors
const COLORS := {
	"hub":    Color(0.2, 1.0, 0.9),
	"nest":   Color(0.4, 1.0, 0.4),
	"phish":  Color(0.3, 0.7, 1.0),
	"salami": Color(1.0, 0.55, 0.2),
	"package": Color(1.0, 0.55, 0.2),
	"scraper": Color(0.3, 0.9, 0.85),
	"botfarm": Color(0.55, 0.95, 0.4),
	"fence":  Color(1.0, 0.4, 0.9),
	"forge":  Color(0.75, 0.45, 1.0),
	"mixer":  Color(1.0, 0.6, 0.3),
	"lab":    Color(0.5, 0.9, 1.0),
	"relay":  Color(0.8, 0.8, 0.9),
}

# Hacking homages — every structure is a nod to something from the real net.
const DEFS := {
	"hub":    {"name": "C2 Server", "short": "C2",
			   "homage": "Command & Control. The heart of the botnet; every tunnel leads here."},
	"nest":   {"name": "Mirai Dropper", "short": "IOT", "zone": "residential",
			   "homage": "The Mirai botnet: default-password cameras and routers conscripted by the thousand. Each pwned device donates Cycles."},
	"package": {"name": "Poisoned Package", "short": "PKG", "zone": "registry",
			   "homage": "A typosquatted npm package quietly pulled into a thousand CI builds. A supply-chain compromise — big Cycles."},
	"botfarm": {"name": "Cloud Cryptojacker", "short": "FARM", "zone": "farm",
			   "homage": "Stolen cloud keys spin up racks of instances on someone else's bill. Heavy Cycles."},
	"phish":  {"name": "Phishing Kit", "short": "MAIL", "zone": "glasshouse", "range": true,
			   "homage": "An Emotet-style mail lure sprayed across an office. Sweeps Intel from inboxes in range."},
	"scraper": {"name": "Scraper Botnet", "short": "SCRP", "zone": "feeds", "range": true,
			   "homage": "Credential-stuffing bots grinding leaked dumps against logins across the feeds. Sweeps Intel in range."},
	"salami": {"name": "Magecart Skimmer", "short": "SKIM", "zone": "vault",
			   "homage": "A few lines of JavaScript on a checkout page. Skims card data — pays out in Crypto."},
	"fence":  {"name": "Darknet Market", "short": "MKT",
			   "homage": "A Silk Road stall. Sells your stolen Intel for Cash."},
	"forge":  {"name": "Exploit Forge", "short": "FORGE",
			   "homage": "A zero-day lab. Refines Intel (burning Cycles) into Tools — the exploits you need to breach ICE."},
	"mixer":  {"name": "Crypto Mixer", "short": "MIX",
			   "homage": "A tumbler that launders stolen Crypto into clean, spendable Cash."},
	"lab":    {"name": "Research Lab", "short": "LAB",
			   "homage": "A reverse-engineering rig. Grinds Intel (burning Cycles) into Research — the know-how to unlock new facilities."},
	"relay":  {"name": "Proxy", "short": "PXY",
			   "homage": "Turn ANY producer into a pure data proxy: it stops producing but forwards packets toward C2 at MINIMUM upkeep, sees far (scout/repeater), and merges many thin links into one fat trunk. Build proxies to push your reach toward new districts cheaply."},
}
const TUNNEL_DEFS := {
	"dns": {"name": "DNS Tunnel", "homage": "iodine-style: data smuggled inside DNS queries. Small, cheap, silent."},
	"vpn": {"name": "VPN Tunnel", "homage": "WireGuard: an encrypted link. Medium throughput, and it actively COOLS your Trace."},
	"tcp": {"name": "Reverse Shell", "homage": "A fat pipe straight back to C2. Fast — and LOUD (raises Trace)."},
	"http": {"name": "HTTP/2 Flood", "homage": "A multiplexed firehose. Huge throughput, pricey, moderately loud."},
	"proxy": {"name": "Onion Route", "homage": "Bounces through many hops — reaches far-off districts, costs a Tool."},
}
# Districts tile the whole map (a night city). Keys are the internal zone types.
const ZONE_NAMES := {"residential": "The Sprawl", "glasshouse": "Glasshouse Row", "vault": "The Exchange", "registry": "The Registry", "feeds": "The Feeds", "farm": "Server Farms", "spire": "The Spire", "slums": "The Undercity"}
const ZONE_RES := {"glasshouse": "Intel", "vault": "Crypto", "registry": "Cycles", "feeds": "Intel", "farm": "Cycles"}
const ZONE_PRODUCER := {"glasshouse": "phish", "vault": "salami", "registry": "package", "feeds": "scraper", "farm": "botfarm"}
# What each producer yields (display name), so a producer can go on ANY district of the
# matching resource/colour (e.g. any Intel/blue ground), not just one exact district.
const PRODUCER_RES := {"nest": "Cycles", "package": "Cycles", "botfarm": "Cycles", "phish": "Intel", "scraper": "Intel", "salami": "Crypto"}
# B43: a producer's output resource KEY and resource-name → key, so markers can borrow the
# SAME semantic (colour-blind-aware) palette as the resource packets.
const PRODUCER_OUT := {"nest": "compute", "package": "compute", "botfarm": "compute", "phish": "data", "scraper": "data", "salami": "crypto"}
const RES_KEY := {"Cycles": "compute", "Intel": "data", "Crypto": "crypto"}
const ZONE_COLOR := {  # ground tint = the resource you can place there
	"residential": Color(0.4, 0.95, 0.55),   # Cycles (green)
	"registry":    Color(0.65, 0.9, 0.35),   # Cycles (lime)
	"farm":        Color(0.35, 0.85, 0.6),   # Cycles (teal-green)
	"glasshouse":  Color(0.35, 0.65, 1.0),   # Intel (blue)
	"feeds":       Color(0.45, 0.78, 1.0),   # Intel (sky)
	"vault":       Color(1.0, 0.62, 0.2),    # Crypto (orange)
	"spire":       Color(0.6, 1.0, 1.0),     # endgame (cyan)
	"slums":       Color(0.55, 0.55, 0.62),  # no producer (grey)
}
# Building height range (in px-ish levels) per district — gives each a skyline
const DIST_H := {"residential": [1, 2], "glasshouse": [3, 5], "vault": [4, 6], "registry": [2, 3], "feeds": [2, 4], "farm": [1, 1], "spire": [8, 11], "slums": [1, 1]}
# Architectural profile per structure: height, setback tiers, roof style, window rows.
const STRUCT := {
	"hub":     {"h": 40, "tiers": 3, "roof": "spire",   "win": 3},
	"nest":    {"h": 14, "tiers": 1, "roof": "dome",    "win": 1},
	"package": {"h": 22, "tiers": 3, "roof": "flat",    "win": 2},
	"botfarm": {"h": 24, "tiers": 2, "roof": "vents",   "win": 2},
	"phish":   {"h": 30, "tiers": 2, "roof": "flat",    "win": 4},
	"scraper": {"h": 26, "tiers": 1, "roof": "mast",    "win": 1},
	"salami":  {"h": 28, "tiers": 2, "roof": "crown",   "win": 3},
	"fence":   {"h": 14, "tiers": 1, "roof": "awning",  "win": 1},
	"forge":   {"h": 22, "tiers": 2, "roof": "chimney", "win": 2},
	"mixer":   {"h": 22, "tiers": 1, "roof": "tank",    "win": 2},
	"lab":     {"h": 22, "tiers": 2, "roof": "dome",    "win": 2},
	"relay":   {"h": 26, "tiers": 1, "roof": "mast",    "win": 1},
}
# Rooftop silhouette for the background city buildings of each district.
const DIST_STYLE := {
	"residential": "dome", "glasshouse": "flat", "vault": "crown", "registry": "flat",
	"feeds": "billboard", "farm": "vents", "spire": "spire", "slums": "awning",
}
const COARSE := 5             # tiles per district cell; map is GW×GH district cells
const GW := 20
const GH := 20
const RES_NAMES := {"compute": "Cycles", "data": "Intel", "credits": "Cash", "crypto": "Crypto", "tools": "Tools", "research": "Research"}

# ---- State ----
var rng := RandomNumberGenerator.new()
var regions: Array = []        # one per district seed: {type, cells, cx, cy, ice}
var region_grid := PackedInt32Array()  # GW*GH: region index per district cell
var nodes: Dictionary = {}     # id -> {id,type,cell,parent,tunnel}
var next_id := 1
var hub_id := 0

var resources := {"compute": 80.0, "data": 0.0, "credits": 0.0, "crypto": 0.0, "tools": 0.0, "research": 0.0}
var trace := 0.0
var researched := {}  # set of unlocked tech ids
var rates := {}       # res -> net per second (for the HUD)
var _rate_t := 0.0
var _rate_prev := {}
var _undo := []       # stack of reversible actions
var total_upkeep := 0.0
var slow_factor := 1.0
var won := false

var current_tool := ""
var pending_child := -1
var message := "Pick a tool from the left, then click the map."
var hint := ""
var selected_id := -1
var selected_tunnel := -1
var paused := false
var ui = null                 # back-reference to the UI, registered by ui.gd
var pause_menu := false       # the modal PAUSE MENU is open (distinct from planning pause) — B39
var modal_open := false       # a blocking modal (Settings / win) is open; set each frame by ui — B35-B38
var _menu_prev_paused := false
var seed := 0
var warn_overload := false
var _panning := false
var _rmb_down := false
var _rmb_moved := false
var _lmb_down := false
var _lmb_moved := false
var _lmb_accum := 0.0   # cumulative drag distance since press, so slow drags still count (B45)
var _rmb_accum := 0.0
var _cursor_shape := 0  # Input.CURSOR_ARROW — cached so we only set it on change
# cached tunnel-route preview — avoid running A* every frame while placing a link
var _hint_cell := Vector2i(-99999, -99999)
var _hint_pending := -1
var _hint_tool := ""
var _hint_route := {}
# cached fog-of-war vision list — rebuilt only when the node set changes
var _vis_sig := []
var _vis_cache := []
var _vis_blocks := {}   # cached {block_key: true} for visible PxP blocks; rebuilt with _vis_cache
# repaint gating — skip full redraws on idle frames (paused, or reduced-motion with nothing moving)
var _last_cam_pos := Vector2.ZERO
var _last_cam_zoom := Vector2.ONE
var _last_mouse := Vector2.ZERO
var _last_vsig := 0            # last visual-state signature (B51 paused-repaint wake)
var _vsig_init := false
var _last_cb_pal := false      # B43: re-bake the city when the colour-blind palette changes


# A cheap hash of everything a discrete action can change on-screen, so repaint gating can
# wake once on toggles/dismantle/undo/settings/selection even while paused and stationary.
func _visual_sig() -> int:
	var h := hash([nodes.size(), selected_id, selected_tunnel, pending_child, _undo.size(),
		sweep.is_empty(), _blackout_t > 0.0, won, message,
		Settings.reduced_motion, Settings.high_contrast, Settings.cb, Settings.dots, Settings.text_scale])
	for id in nodes:
		var n = nodes[id]
		h = hash([h, id, n.parent, n.get("on", true), n.get("relay", false),
			n.get("boost_t", 0.0) > 0.0, n.get("cap_rate", 1.0), n.get("quarantine", 0.0) > 0.0])
	return h

# ICE Sweep antagonist + run stats
var notoriety := 0.0          # non-decaying heat driver: sets sweep strength/frequency
var sweep := {}               # active ICE sweep (empty = none)
var _sweep_charge := 0.0      # accumulates toward launching the next sweep
var _blackout_t := 0.0        # C2 blackout timer (production paused) after a sweep lands
var _run_time := 0.0          # seconds of active play, for the end-run scorecard
var _packets_delivered := 0
var _max_trace := 0.0
var _peak_cash_rate := 0.0
var _deliver_flash := {}      # resource -> flash timer (delivery juice)
# Contract board (jobs)
var contracts := []
var _contract_cd := 10.0
var _next_contract_id := 1
var _contracts_ver := 0
var _hist_cash := []          # Cash samples (1 Hz) for the Stats sparkline

# Emergency bootstrap — guarantees a run can never become permanently unrecoverable.
# When you have no live Cycles income and can't afford the cheapest producer, the C2
# slowly supplies Cycles up to a small floor (one Mirai Dropper + one DNS link). (B01/T40)
const EMERGENCY_FLOOR := 15.0   # Cycles guaranteed when stalled (nest 10 + dns 5)
const EMERGENCY_RATE := 1.5     # Cycles/sec trickle while stalled — just enough to rebuild
var _emergency_active := false

var _accum := 0.0
var _time := 0.0

# per-edge draw cache: child_id -> {frac, offered, delivered}
var _edge := {}
var _connected := {}  # ids with a live path to the Hub (for drawing warnings)
var packets: Array = []   # in-transit units: {res, route: Array[edge id], idx, dir (1 = to Hub), dist px}
var _drops: Array = []    # recent packet-loss flashes: {pos, t}
var _pl_cache := {}       # edge id -> {pts, total}; cleared when tunnels change

@onready var camera: Camera2D = $Camera2D


var _city_layer: Node2D  # static city backdrop, baked once


func _ready() -> void:
	seed = Session.seed if Session.seed != 0 else randi()
	rng.seed = seed
	var loaded := false
	if Session.start_mode == "load" and Session.has_save():
		loaded = load_game(true)   # Continue may recover from the last-good backup (T95)
	if not loaded:
		_generate_city()
		_place_hub()
		camera.position = _center_world(hub_id)
		camera.zoom = Vector2.ONE
	Session.start_mode = "new"
	_city_layer = Node2D.new()
	_city_layer.z_index = -10
	_city_layer.set_script(load("res://scripts/city_layer.gd"))
	add_child(_city_layer)
	_city_layer.queue_redraw()


func _invalidate_city() -> void:
	# re-bake the static city backdrop (e.g. when High-Contrast changes its shading)
	if _city_layer:
		_city_layer.queue_redraw()


# ---------- City generation ----------
# The whole map is partitioned into contiguous districts (seeded Voronoi): the
# valuable ones cluster toward the centre, residential/undercity fill the rim.
func _generate_city() -> void:
	regions.clear()
	var cx := GW / 2.0
	var cy := GH / 2.0
	var seeds := [{"type": "spire", "pos": Vector2(cx + rng.randf_range(-1, 1), cy + rng.randf_range(-1, 1))}]
	# more, smaller districts scattered across the map so resources are never far
	_add_seeds(seeds, "vault", 3, cx, cy, 2.5, 8.0)
	_add_seeds(seeds, "glasshouse", 5, cx, cy, 2.5, 10.0)
	_add_seeds(seeds, "feeds", 4, cx, cy, 2.5, 11.0)
	_add_seeds(seeds, "registry", 3, cx, cy, 2.5, 10.0)
	_add_seeds(seeds, "farm", 3, cx, cy, 3.0, 11.0)
	_add_seeds(seeds, "slums", 4, cx, cy, 4.0, 12.0)
	_add_seeds(seeds, "residential", 10, cx, cy, 4.0, 13.0)
	for s in seeds:
		var ice := 3 if s.type == "spire" else (1 if s.type == "vault" else 0)
		regions.append({"type": s.type, "cells": 0, "sx": 0.0, "sy": 0.0, "cx": s.pos.x, "cy": s.pos.y, "ice": ice})
	region_grid = PackedInt32Array()
	region_grid.resize(GW * GH)
	for gy in GH:
		for gx in GW:
			var best := 0
			var bd := INF
			for i in seeds.size():
				var d: float = Vector2(gx + 0.5, gy + 0.5).distance_squared_to(seeds[i].pos)
				if d < bd:
					bd = d
					best = i
			region_grid[gy * GW + gx] = best
			regions[best].cells += 1
			regions[best].sx += gx + 0.5
			regions[best].sy += gy + 0.5
	for r in regions:
		if r.cells > 0:
			r.cx = r.sx / r.cells
			r.cy = r.sy / r.cells


func _add_seeds(seeds: Array, type: String, n: int, cx: float, cy: float, rmin: float, rmax: float) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		seeds.append({"type": type, "pos": Vector2(clampf(cx + cos(a) * r, 0.5, GW - 0.5), clampf(cy + sin(a) * r, 0.5, GH - 0.5))})


func _place_hub() -> void:
	var cell := Vector2i(COARSE, GH / 2 * COARSE)  # fallback
	var placed := false
	for gx in GW:  # first residential district from the left edge = the Rim
		for gy in GH:
			if regions[region_grid[gy * GW + gx]].type == "residential":
				cell = Vector2i(gx * COARSE + 1, gy * COARSE + 1)
				placed = true
				break
		if placed:
			break
	hub_id = next_id
	nodes[hub_id] = {"id": hub_id, "type": "hub", "cell": cell, "size": SIZE["hub"], "parent": -1, "tunnel": "", "relay": false, "on": true, "cap_rate": 1.0, "boost_t": 0.0, "lane": 0, "path": []}
	next_id += 1


func _region_at(cell: Vector2i) -> int:
	var gx := clampi(int(cell.x) / COARSE, 0, GW - 1)
	var gy := clampi(int(cell.y) / COARSE, 0, GH - 1)
	return region_grid[gy * GW + gx]


func _tile_type(cell: Vector2i) -> String:
	if regions.is_empty():
		return "residential"
	return regions[_region_at(cell)].type


# ---------- Coordinate helpers ----------
func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)


func _mouse_cell() -> Vector2i:
	var w := get_global_mouse_position()
	return Vector2i(floori(w.x / TILE), floori(w.y / TILE))


func _node_at(cell: Vector2i) -> int:
	for id in nodes:
		if _covers(id, cell):
			return id
	return -1


# B48: hit-test the visible 2.5D silhouette (ground footprint up to the elevated roof), so a
# click on the drawn tower selects it even though the footprint sits below/left of the roof.
# Among overlapping hits the frontmost (largest cell.y + size, matching paint order) wins.
func _node_at_silhouette(wpos: Vector2) -> int:
	var best := -1
	var best_front := -1.0
	for id in nodes:
		var o: Vector2i = nodes[id].cell
		var s: int = nodes[id].size
		var pr: Dictionary = STRUCT.get("relay" if nodes[id].get("relay", false) else nodes[id].type, {"h": 14})
		var h: float = float(pr.h)
		var base := Rect2(o.x * TILE, o.y * TILE, s * TILE, s * TILE)
		var top := Rect2(base.position + Vector2(h * 0.35, -h), base.size)
		if base.merge(top).has_point(wpos):
			var front := float(o.y + s)
			if front > best_front:
				best_front = front
				best = id
	return best


func _is_parent_ok(id: int) -> bool:
	return nodes[id].type in ["hub", "fence"] or (nodes[id].type == "nest" and nodes[id].get("relay", false))


# True if linking child -> target would form a loop (target already routes through child).
func _would_cycle(child: int, target: int) -> bool:
	var cur := target
	var guard := 0
	while cur != -1 and guard < 10000:
		if cur == child:
			return true
		cur = nodes[cur].parent if nodes.has(cur) else -1
		guard += 1
	return false


# ---------- Building footprints ----------
func _cells_of(origin: Vector2i, size: int) -> Array:
	var a := []
	for x in size:
		for y in size:
			a.append(origin + Vector2i(x, y))
	return a


func _covers(id: int, cell: Vector2i) -> bool:
	var o: Vector2i = nodes[id].cell
	var s: int = nodes[id].size
	return cell.x >= o.x and cell.y >= o.y and cell.x < o.x + s and cell.y < o.y + s


func _center_world(id: int) -> Vector2:
	var o: Vector2i = nodes[id].cell
	var s: int = nodes[id].size
	return Vector2((o.x + s * 0.5) * TILE, (o.y + s * 0.5) * TILE)


func _center_cell(id: int) -> Vector2i:
	var o: Vector2i = nodes[id].cell
	var h: int = nodes[id].size / 2
	return o + Vector2i(h, h)


# ---------- Tunnel attachment (border ring) ----------
# World rect of a building's footprint.
func _rect_of(id: int) -> Rect2:
	var o: Vector2i = nodes[id].cell
	var s: int = nodes[id].size
	return Rect2(o.x * TILE, o.y * TILE, s * TILE, s * TILE)


# Nearest point on a building's border to a world point (where a tunnel touches it).
func _border_point(id: int, from: Vector2) -> Vector2:
	var r := _rect_of(id)
	return Vector2(clampf(from.x, r.position.x, r.end.x), clampf(from.y, r.position.y, r.end.y))


# The one-cell ring just outside a footprint — the cells a tunnel may attach from.
func _ring_cells(id: int) -> Array:
	var o: Vector2i = nodes[id].cell
	var s: int = nodes[id].size
	var ring := []
	for x in range(o.x - 1, o.x + s + 1):
		for y in range(o.y - 1, o.y + s + 1):
			var c := Vector2i(x, y)
			if _covers(id, c) or c.x < 0 or c.y < 0 or c.x >= MAP_W or c.y >= MAP_H:
				continue
			ring.append(c)
	return ring


# How many tunnels occupy each cell (up to LANES allowed — parallel lanes).
func _used_cells() -> Dictionary:
	var used := {}
	for id in nodes:
		if nodes[id].parent == -1:
			continue
		for c in nodes[id].get("path", []):
			used[c] = int(used.get(c, 0)) + 1
	return used


# ---------- Tunnel routing (A*) ----------
func _in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < MAP_W and c.y < MAP_H


func _cell_free(c: Vector2i, used: Dictionary, occ: Dictionary) -> bool:
	# a tunnel cell must be a street/open cell (not a building), so links follow roads.
	# `occ` is a precomputed node-footprint set so this stays O(1) (no per-cell node scan).
	return _in_map(c) and int(used.get(c, 0)) < LANES and not occ.has(c) and not _is_building_cell(c)


# A diagonal step may not cut a structure's corner (lanes let tunnels share cells).
func _diag_blocked(p: Vector2i, d: Vector2i, _used: Dictionary) -> bool:
	return _node_at(p + Vector2i(d.x, 0)) != -1 or _node_at(p + Vector2i(0, d.y)) != -1


const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
# Tunnels follow the streets: orthogonal steps only, so links run along the road grid
# and turn at 90° instead of cutting diagonally across building corners.
const ROAD_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


# A* over grid cells (8 directions, one step per cell, a small turn penalty for
# tidy roads) from any start cell to any goal cell, avoiding structures and other
# tunnels. Returns the cell path (≤ MAX_LEN cells) or [] if there is none.
# {cell: true} for every node footprint cell — an O(1) "is this cell a building" test
# for A*, built once per path request instead of scanning all nodes per cell.
func _node_occ() -> Dictionary:
	var occ := {}
	for id in nodes:
		var o: Vector2i = nodes[id].cell
		var s: int = nodes[id].size
		for x in s:
			for y in s:
				occ[o + Vector2i(x, y)] = true
	return occ


# Binary min-heap over [f, cell] pairs — A*'s open set. Replaces the old linear
# min-scan that made long/unreachable routes O(budget²) and froze the game.
func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if float(heap[p][0]) <= float(heap[i][0]):
			break
		var t = heap[p]; heap[p] = heap[i]; heap[i] = t
		i = p


func _heap_pop(heap: Array) -> Array:
	var top = heap[0]
	var last = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var n := heap.size()
		while true:
			var l := 2 * i + 1
			var r := 2 * i + 2
			var s := i
			if l < n and float(heap[l][0]) < float(heap[s][0]):
				s = l
			if r < n and float(heap[r][0]) < float(heap[s][0]):
				s = r
			if s == i:
				break
			var t = heap[s]; heap[s] = heap[i]; heap[i] = t
			i = s
	return top


func _astar(starts: Array, goals: Dictionary, used: Dictionary, occ: Dictionary, maxlen: int = int(MAX_LEN)) -> Array:
	if starts.is_empty() or goals.is_empty():
		return []
	var g := {}        # cell -> cost so far
	var steps := {}    # cell -> cells so far (1 at a start)
	var came := {}     # cell -> previous cell
	var dir_in := {}   # cell -> direction we arrived by
	var closed := {}
	var heap := []     # min-heap of [f, cell]; lazy deletion (stale entries skipped on pop)
	# mild weighted-A*: on an open street grid many routes tie on cost, so a small
	# heuristic bias greatly cuts how many cells we explore; the chosen path is at most
	# ~15% longer than optimal, invisible for tunnel routing but far cheaper to compute.
	const HW := 1.15
	for s in starts:
		g[s] = 0.0
		steps[s] = 1
		_heap_push(heap, [_h(s, goals) * HW, s])
	var budget := 60000  # generous bound; each step is now cheap (heap + O(1) cell test)
	while not heap.is_empty():
		budget -= 1
		if budget <= 0:
			return []
		var cur: Vector2i = _heap_pop(heap)[1]
		if closed.has(cur):
			continue
		if goals.has(cur):
			var path := [cur]
			while came.has(cur):
				cur = came[cur]
				path.push_front(cur)
			return path
		closed[cur] = true
		if int(steps[cur]) >= maxlen:
			continue
		for d in ROAD_DIRS:
			var n: Vector2i = cur + d
			if closed.has(n) or not _cell_free(n, used, occ):
				continue
			var turn := 0.0
			if dir_in.has(cur) and dir_in[cur] != d:
				turn = 0.35
			var ng: float = float(g[cur]) + 1.0 + turn
			if not g.has(n) or ng < float(g[n]):
				g[n] = ng
				steps[n] = int(steps[cur]) + 1
				came[n] = cur
				dir_in[n] = d
				_heap_push(heap, [ng + _h(n, goals) * HW, n])
	return []


func _h(c: Vector2i, goals: Dictionary) -> float:
	# Manhattan: tunnels move orthogonally (ROAD_DIRS), so |dx|+|dy| is the admissible,
	# tight heuristic. (Chebyshev underestimated badly here and made A* over-explore.)
	var best := INF
	for gcell in goals:
		var d := float(absi(c.x - gcell.x) + absi(c.y - gcell.y))
		if d < best:
			best = d
	return best


# Route a tunnel child→parent: from any free ring cell around the child to any
# free ring cell around the parent, winding around whatever is in the way.
func _find_path(child_id: int, parent_id: int, maxlen: int = int(MAX_LEN)) -> Array:
	var used := _used_cells()
	var occ := _node_occ()
	var starts := []
	for c in _ring_cells(child_id):
		if _cell_free(c, used, occ):
			starts.append(c)
	var goals := {}
	for c in _ring_cells(parent_id):
		if _cell_free(c, used, occ):
			goals[c] = true
	return _astar(starts, goals, used, occ, maxlen)


# Route from a child toward an arbitrary free cell (for the routing preview).
func _find_path_to_cell(child_id: int, cell: Vector2i, maxlen: int = int(MAX_LEN)) -> Array:
	var used := _used_cells()
	var occ := _node_occ()
	if not _cell_free(cell, used, occ):
		return []
	var starts := []
	for c in _ring_cells(child_id):
		if _cell_free(c, used, occ):
			starts.append(c)
	return _astar(starts, {cell: true}, used, occ, maxlen)


func _tool_maxlen(code: String) -> int:
	return int(TUNNEL_MAXLEN.get(code, int(MAX_LEN)))


# Polyline of a tunnel along its cell path: border stub → bend points → border stub
# (parent_id -1 = open-ended preview, no tail stub).
func _pts_for_path(child_id: int, parent_id: int, path: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if path.is_empty():
		return out
	var n := path.size()
	out.append(_border_point(child_id, _cell_center(path[0])))
	for i in n:
		var keep: bool = i == 0 or i == n - 1
		if not keep:
			var d1: Vector2i = path[i] - path[i - 1]
			var d2: Vector2i = path[i + 1] - path[i]
			keep = d1 != d2
		if keep:
			var p := _cell_center(path[i])
			if not out[out.size() - 1].is_equal_approx(p):
				out.append(p)
	if parent_id != -1:
		var tail := _border_point(parent_id, _cell_center(path[n - 1]))
		if not out[out.size() - 1].is_equal_approx(tail):
			out.append(tail)
	return out


func _edge_pts(child_id: int, parent_id: int) -> PackedVector2Array:
	var path: Array = nodes[child_id].get("path", [])
	if path.is_empty():
		return PackedVector2Array([_center_world(child_id), _center_world(parent_id)])
	var pts := _pts_for_path(child_id, parent_id, path)
	# offset parallel lanes perpendicular to the route so they don't overlap
	var lane := int(nodes[child_id].get("lane", 0))
	if lane != 0 and pts.size() >= 2:
		var dir := (pts[pts.size() - 1] - pts[0]).normalized()
		var off := Vector2(-dir.y, dir.x) * (float(lane) - float(LANES - 1) * 0.5) * 4.0
		for i in pts.size():
			pts[i] += off
	return pts


# Tunnel length = number of cells it occupies (its latency in packets).
func _edge_len(child_id: int, _parent_id: int) -> float:
	var path: Array = nodes[child_id].get("path", [])
	return float(path.size())


# Would-be route while placing a tunnel from pending_child toward the mouse cell.
func _preview_route(cell: Vector2i) -> Dictionary:
	var ml := _tool_maxlen(current_tool)
	var hovered := _node_at(cell)
	if hovered != -1 and hovered != pending_child:
		if _would_cycle(pending_child, hovered):
			return {"pts": PackedVector2Array(), "len": INF, "blocked": true,
				"why": "LOOP — that node already routes back through this one"}
		var p1 := _find_path(pending_child, hovered, ml)
		if p1.is_empty():
			return {"pts": PackedVector2Array(), "len": INF, "blocked": true,
				"why": "NO CLEAR ROUTE — blocked, or further than %d pkt" % _lag(ml)}
		return {"pts": _pts_for_path(pending_child, hovered, p1), "len": float(p1.size()), "blocked": false}
	var p2 := _find_path_to_cell(pending_child, cell, ml)
	if p2.is_empty():
		return {"pts": PackedVector2Array(), "len": INF, "blocked": true,
			"why": "NO CLEAR ROUTE — blocked, or further than %d pkt" % _lag(ml)}
	return {"pts": _pts_for_path(pending_child, -1, p2), "len": float(p2.size()), "blocked": false}


# Route preview cached by (cell, pending child, tool) so A* runs only when the
# hovered cell changes, not every frame while dragging a link.
func _cached_preview(cell: Vector2i) -> Dictionary:
	if cell != _hint_cell or pending_child != _hint_pending or current_tool != _hint_tool:
		_hint_cell = cell
		_hint_pending = pending_child
		_hint_tool = current_tool
		_hint_route = _preview_route(cell)
	return _hint_route


func _tunnel_at(cell: Vector2i) -> int:
	for id in nodes:
		if nodes[id].parent == -1:
			continue
		for c in nodes[id].get("path", []):
			if c == cell:
				return id
	return -1


# Nearest tunnel to a world point (forgiving click — hit-tests the drawn polyline).
func _tunnel_near(world: Vector2) -> int:
	var best := -1
	var bd := 9.0 / maxf(camera.zoom.x, 0.01)  # ~9px on screen regardless of zoom
	for id in nodes:
		if nodes[id].parent == -1:
			continue
		var pts := _edge_pts(id, nodes[id].parent)
		for i in range(pts.size() - 1):
			var d := _dist_to_seg(world, pts[i], pts[i + 1])
			if d < bd:
				bd = d
				best = id
	return best


func _dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 <= 0.0 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---------- Vision / fog of war ----------
# Each structure reveals a radius; you can only build where you have coverage.
func _vision_list() -> Array:
	# rebuild only when the node set changes (count + relay count catches add/remove/convert)
	var relays := 0
	for id in nodes:
		if nodes[id].get("relay", false):
			relays += 1
	var sig := [nodes.size(), relays]
	if sig != _vis_sig:
		_vis_sig = sig
		_vis_cache = []
		for id in nodes:
			var n = nodes[id]
			var ctr := Vector2(n.cell) + Vector2(n.size, n.size) * 0.5
			var r: float = float(VISION.get("relay", 11)) if n.get("relay", false) else float(VISION.get(n.type, 6))
			_vis_cache.append([ctr, r])
		# Precompute which PxP fog blocks are visible, once per vision change, so the
		# per-frame fog loop is a dictionary lookup instead of O(blocks × nodes).
		var P := 4
		_vis_blocks = {}
		for by in range(0, MAP_H / P + 1):
			for bx in range(0, MAP_W / P + 1):
				if _is_visible(Vector2i(bx * P + P / 2, by * P + P / 2), _vis_cache):
					_vis_blocks[by * 1000 + bx] = true
	return _vis_cache


func _is_visible(cell: Vector2i, vl: Array) -> bool:
	var p := Vector2(cell) + Vector2(0.5, 0.5)
	for v in vl:
		if p.distance_to(v[0]) <= float(v[1]):
			return true
	return false


# A cell is a building cell (not street/plaza) — must match the city render.
# B10: ONE authoritative descriptor of a city block's building, shared by placement/coverage/
# routing (_is_building_cell) and the render (_paint_city), so they can never disagree. The
# block-centre district decides vacancy/sparsity; Server Farms render a single front row.
func _block_desc(bx: int, by: int) -> Dictionary:
	var dtype: String = _tile_type(Vector2i(bx * 4 + 1, by * 4 + 1))
	var sparse: bool = dtype == "slums"
	return {"dtype": dtype, "rendered": _h2(bx, by) % 10 >= (4 if sparse else 2), "narrow": dtype == "farm"}


func _is_building_cell(cell: Vector2i) -> bool:
	if not _in_map(cell):
		return false
	var P := 4
	var bx := cell.x / P
	var by := cell.y / P
	var lx := cell.x - bx * P
	var ly := cell.y - by * P
	if lx >= 3 or ly >= 3:
		return false  # street gutter
	var d := _block_desc(bx, by)
	if not d.rendered:
		return false  # vacant lot
	if d.narrow and ly >= 1:
		return false  # Server Farms occupy only the front row
	return true


func _reaches_hub(id: int) -> bool:
	var cur := id
	var guard := 0
	while cur != -1 and guard < 10000:
		if cur == hub_id:
			return true
		cur = nodes[cur].parent if nodes.has(cur) else -1
		guard += 1
	return false


# Tile-steps along an octilinear (90° + 45°) path: a diagonal step covers one
# tile in both axes, so length is the larger of the two spans (Chebyshev).
func _tiles(a: Vector2i, b: Vector2i) -> float:
	return float(maxi(abs(a.x - b.x), abs(a.y - b.y)))


func _lag(tiles: float) -> int:
	return int(round(tiles * LAG_PER_TILE))


# Octilinear tunnel path: a 45° diagonal run, then a 90° axis run, along grid
# cell centres — tunnels may go straight or diagonal.
func _tunnel_pts(child_cell: Vector2i, parent_cell: Vector2i) -> PackedVector2Array:
	var dx := parent_cell.x - child_cell.x
	var dy := parent_cell.y - child_cell.y
	var k := mini(abs(dx), abs(dy))
	var corner := child_cell + Vector2i(signi(dx) * k, signi(dy) * k)
	return PackedVector2Array([
		_cell_center(child_cell), _cell_center(corner), _cell_center(parent_cell),
	])


# ---------- Packets (the data itself, in transit) ----------
# Cached polyline + length of a tunnel (edge = child id). Cleared when tunnels change.
func _polyline(edge_id: int) -> Dictionary:
	if _pl_cache.has(edge_id):
		return _pl_cache[edge_id]
	var pts := _edge_pts(edge_id, nodes[edge_id].parent)
	var total := 0.0
	for s in range(pts.size() - 1):
		total += pts[s].distance_to(pts[s + 1])
	var d := {"pts": pts, "total": total}
	_pl_cache[edge_id] = d
	return d


# Edge ids from a node up to (not including) the Hub; [] if it doesn't reach.
func _chain(id: int) -> Array:
	var out := []
	var cur := id
	var guard := 0
	while cur != hub_id and guard < 10000:
		if not nodes.has(cur) or nodes[cur].parent == -1:
			return []
		out.append(cur)
		cur = nodes[cur].parent
		guard += 1
	return out


# Roll packet loss for the edge a packet is about to enter. False = dropped.
func _enter_edge(p: Dictionary) -> bool:
	var e: int = p.route[p.idx]
	var loss := 0.0
	if _edge.has(e):
		loss = 1.0 - float(_edge[e].frac)
	if loss > 0.0 and rng.randf() < loss:
		var pl := _polyline(e)
		var at: float = 0.0 if p.dir == 1 else float(pl.total)
		_drops.append({"pos": _point_at_dist(pl.pts, at), "t": 0.6})
		return false
	return true


# One unit of a resource starts travelling along a route (dir 1 = toward Hub).
func _spawn(res: String, route: Array, dir: int, value := 1.0) -> void:
	if route.is_empty():
		return
	var p := {"res": res, "route": route, "idx": 0, "dir": dir, "dist": 0.0, "value": value}
	if _enter_edge(p):
		packets.append(p)


# Advance every packet; deliver, convert or drop as they reach nodes.
func _move_packets(dt: float) -> void:
	var speed := PACKET_SPEED * slow_factor
	var i := packets.size() - 1
	while i >= 0:
		var p: Dictionary = packets[i]
		var alive := true
		var e: int = p.route[p.idx]
		if not nodes.has(e) or nodes[e].parent == -1 or not _connected.has(e):
			alive = false  # its tunnel is gone or disconnected
		else:
			var pl := _polyline(e)
			p.dist += speed * dt
			while alive and p.dist >= float(pl.total):
				p.dist -= float(pl.total)
				var at_node: int = nodes[e].parent if p.dir == 1 else e
				# a Market only sells when it is operational — an OFF Market can't convert
				# passing Intel (B06); the Intel continues to C2 unsold
				if p.dir == 1 and nodes[at_node].type == "fence" and p.res == "data" and nodes[at_node].get("on", true):
					p.res = "credits"  # sold at the Darknet Market, continues to the Hub
					p["value"] = _market_price()  # price drops as the market saturates
				p.idx += 1
				if p.idx >= p.route.size():
					if p.dir == 1:
						if at_node == hub_id:
							resources[p.res] = resources.get(p.res, 0.0) + float(p.get("value", 1.0))
							_packets_delivered += 1
							_deliver_flash[p.res] = 0.5
					else:
						# input reached the processor — send the product back to C2
						var outr: String = CONV[nodes[at_node].type].out if CONV.has(nodes[at_node].type) else "credits"
						var oval := _market_price() if outr == "credits" else 1.0
						_spawn(outr, _chain(at_node), 1, oval)
					alive = false
				elif not _enter_edge(p):
					alive = false
				else:
					e = p.route[p.idx]
					# B07: the next stored hop must still match live topology. If the source was
					# reparented mid-flight, the stored route is stale — cancel the packet (loss)
					# rather than ride a dead route toward the wrong parent.
					if not nodes.has(e) or nodes[e].parent == -1 or (p.dir == 1 and e != at_node):
						alive = false
					else:
						pl = _polyline(e)
		if not alive:
			packets.remove_at(i)
		i -= 1


# A packet drawn as its resource pictogram: bolt = Cycles, eye = Intel, coin = Cash.
func _draw_packet(pos: Vector2, res: String) -> void:
	Glyphs.draw_resource(self, res, pos, 5.0)


func _matrix_char(res: String, d: float) -> String:
	return MCHARS[posmod(int(_time * 2.5 + d * 0.5) + res.hash(), MCHARS.length())]


# World-space point a given distance (px) along a polyline.
func _point_at_dist(pts: PackedVector2Array, dist: float) -> Vector2:
	var d := dist
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if d <= seg:
			return pts[i].lerp(pts[i + 1], d / seg) if seg > 0.0 else pts[i]
		d -= seg
	return pts[pts.size() - 1]


func _cost_str(code: String) -> String:
	var parts := PackedStringArray()
	for k in COST[code]:
		parts.append("%d %s" % [int(COST[code][k]), RES_NAMES.get(k, k)])
	return ", ".join(parts)


# Live hint shown in the HUD while a tool is active.
func _update_hint() -> void:
	hint = ""
	if current_tool == "":
		return
	var cell := _mouse_cell()
	var at := "cursor [%d, %d]" % [cell.x, cell.y]
	if current_tool in TUNNEL_MAXLEN:
		if pending_child == -1:
			hint = "%s — cap %d, cost %s + %.2f CPU/s per tile.  Click the structure to link.   %s" % [
				_tool_name(current_tool), int(CAP[current_tool]), _cost_str(current_tool), float(UPKEEP[current_tool]), at]
		else:
			var route := _cached_preview(cell)
			var length: float = route.len
			var upk := (length if length < INF else 0.0) * float(UPKEEP[current_tool])
			var tag := "OK"
			if route.blocked:
				tag = str(route.get("why", "NO CLEAR ROUTE"))
			elif length > _tool_maxlen(current_tool):
				tag = "LATENCY TOO HIGH (max %d pkt — add a Proxy)" % _lag(_tool_maxlen(current_tool))
			var lat := "—" if length == INF else str(_lag(length))
			hint = "%s → latency %s pkt, upkeep %.2f CPU/s, cost %s   [%s]   %s" % [
				_tool_name(current_tool), lat, upk, _cost_str(current_tool), tag, at]
	elif current_tool == "relay":
		hint = "Cost %s.  Click any producer to turn it into a Proxy — stops producing, routes data toward C2 at low upkeep, extends reach.   %s" % [
			_cost_str("relay"), at]
	else:
		var extra := ""
		if current_tool == "fence":
			extra = "  (sells stored Data → Credits while linked to C2)"
		# ICE clarity: show the breach cost of a guarded district right where you build
		var sz := int(SIZE.get(current_tool, 2))
		var ice := _zone_ice(cell - Vector2i(sz / 2, sz / 2))
		if ice > 0:
			extra += "   ⚠ ICE tier %d here — breaching costs +%d Tools (Trace +%d)" % [ice, ice, int(ICE_TRACE)]
		hint = "Cost %s%s   %s" % [_cost_str(current_tool), extra, at]


# ---------- Input ----------
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# B36: Esc dismisses the frontmost modal first; then cancels the armed tool / selection;
		# then toggles the modal pause MENU when nothing else is active.
		if modal_open and ui != null:
			ui.close_topmost_modal()
		elif pause_menu:
			pause_menu = false
			paused = _menu_prev_paused
		elif current_tool != "" or pending_child != -1 or selected_id != -1 or selected_tunnel != -1:
			set_tool("cancel")
			selected_id = -1
			selected_tunnel = -1
		else:
			_menu_prev_paused = paused
			pause_menu = true
			paused = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# B37: a blocking modal or the pause menu swallows gameplay shortcuts
		if modal_open or pause_menu:
			return
		if event.keycode == KEY_SPACE:
			set_paused(not paused)   # B39: non-modal planning pause — the map stays interactive
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DELETE and (selected_tunnel != -1 or (selected_id != -1 and selected_id != hub_id)):
			remove_selected()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z and event.ctrl_pressed:
			undo_last()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and selected_id != -1 and selected_id != hub_id:
			toggle_selected()  # Disable / Enable the selected structure
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_O and selected_id != -1:
			overclock_selected()
			get_viewport().set_input_as_handled()
		elif (event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT) and selected_id != -1:
			adjust_rate_selected(-0.25)  # lower output limit
			get_viewport().set_input_as_handled()
		elif (event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD) and selected_id != -1:
			adjust_rate_selected(0.25)  # raise output limit
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# B37: while a blocking modal / pause menu is open, the map ignores mouse input (planning
	# pause is non-modal and still interactive — it sets neither flag).
	if modal_open or pause_menu:
		if event is InputEventMouseButton and not event.pressed:
			_lmb_down = false
			_rmb_down = false
			_panning = false
		return
	# mouse events over the left control panel belong to the UI, never the map —
	# this stops a click that lands on the panel from also deselecting / acting on the map
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and get_viewport().get_mouse_position().x < 300.0:
		if event is InputEventMouseButton and not event.pressed:
			_lmb_down = false
			_rmb_down = false
		return
	# pause-to-plan: building/selecting still works while paused (sim stays frozen)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(1.0 / 1.1)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed  # middle-drag pans
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_down = true
				_lmb_moved = false
				_lmb_accum = 0.0
			else:
				if _lmb_down and not _lmb_moved:
					_handle_click(_mouse_cell())  # a click (not a drag) selects/places
				_lmb_down = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_rmb_down = true
				_rmb_moved = false
				_rmb_accum = 0.0
			else:
				if _rmb_down and not _rmb_moved:
					_handle_right_click(_mouse_cell())  # a click (not a drag) cancels/clears
				_rmb_down = false
	elif event is InputEventMouseMotion:
		# B46: only pan while the middle button is actually held — a release consumed by a UI
		# Control can otherwise leave _panning latched and keep moving the camera.
		if _panning and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) == 0:
			_panning = false
		var lmb_drag: bool = _lmb_down and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		var rmb_drag: bool = _rmb_down and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
		# B45: accumulate total displacement since press so many tiny steps still count as a
		# drag even though no single motion step crosses the threshold.
		if lmb_drag:
			_lmb_accum += event.relative.length()
			if _lmb_accum > 6.0:
				_lmb_moved = true
		if rmb_drag:
			_rmb_accum += event.relative.length()
			if _rmb_accum > 6.0:
				_rmb_moved = true
		if _panning or (lmb_drag and _lmb_moved) or rmb_drag:
			camera.position -= event.relative / camera.zoom.x  # drag the map (left/right/middle)


func _zoom(mult: float) -> void:
	var z := clampf(camera.zoom.x * mult, 0.4, 3.0)
	camera.zoom = Vector2(z, z)


func set_tool(code: String) -> void:
	pending_child = -1
	if code == "cancel":
		current_tool = ""
		message = "Cancelled."
	else:
		if not _is_unlocked(code):
			message = "%s is locked — research it in the Tech tab." % _tool_name(code)
			return
		current_tool = code
		selected_id = -1
		message = "%s — click the map." % _tool_name(code)


func _is_unlocked(code: String) -> bool:
	if code in BASE_TOOLS or code == "cancel":
		return true
	for t in researched:
		if code in TECH[t].unlocks:
			return true
	return false


func research_tech(tid: String) -> bool:
	if not TECH.has(tid) or researched.has(tid):
		return false
	var t = TECH[tid]
	for req in t.requires:
		if not researched.has(req):
			message = "Research %s first." % TECH[req].name
			return false
	if resources.research < float(t.cost):
		message = "Need %d Research for %s." % [int(t.cost), t.name]
		return false
	resources.research -= float(t.cost)
	researched[tid] = true
	var names := []
	for c in t.unlocks:
		names.append(_tool_name(c))
	message = "Researched %s — unlocked %s." % [t.name, ", ".join(names)]
	return true


func _handle_click(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_W or cell.y >= MAP_H:
		return
	if current_tool == "relay":
		_try_convert_relay(cell)
	elif current_tool in TUNNEL_MAXLEN:
		_try_tunnel(cell)
	elif SIZE.has(current_tool):
		_try_place_node(current_tool, cell)
	else:
		# no tool: select the structure or tunnel under the cursor (K&M-style)
		var id := _node_at(cell)
		if id == -1:
			id = _node_at_silhouette(get_global_mouse_position())  # B48: click the visible tower, not just its ground
		if id != -1:
			selected_id = id
			selected_tunnel = -1
			message = "%s selected. (Delete or Dismantle to remove)" % _node_name(id)
		else:
			var t := _tunnel_near(get_global_mouse_position())
			selected_tunnel = t
			selected_id = -1
			message = ("%s selected. (Delete or Dismantle to remove)" % _tool_name(nodes[t].tunnel)) if t != -1 else ""


func _handle_right_click(cell: Vector2i) -> void:
	if pending_child != -1:
		pending_child = -1
		message = "Tunnel cancelled."
		return
	if current_tool != "":
		set_tool("cancel")
		return
	if selected_id != -1 or selected_tunnel != -1:
		selected_id = -1
		selected_tunnel = -1
		message = "Selection cleared."


# ---------- Building ----------
# Darknet markets saturate: every Cash you bank drops the price of the next sale,
# so the sprint to the goal slows near the line and diversifying pays off.
func _market_price() -> float:
	return clampf(1.0 - resources.credits / 2000.0, 0.3, 1.0)


# The current suggested move, shown live in the C2 Console (signposts the core loop).
func _next_step() -> String:
	if resources.credits >= GOAL_CREDITS:
		return "Goal reached — the Rim is yours."
	var has_producer := false
	var has_intel := false
	var has_market := false
	for id in nodes:
		if id == hub_id or not _connected.has(id) or nodes[id].get("relay", false):
			continue
		var t: String = nodes[id].type
		if _is_producer(t):
			has_producer = true
		if t == "phish" or t == "scraper":
			has_intel = true
		if t == "fence":
			has_market = true
	if not has_intel:
		return "Build a Phishing Kit on blue Intel ground (Glasshouse Row or The Feeds) and link it to C2 — you need Intel to sell."
	if not has_market:
		return "Build a Darknet Market and link it to C2 — Intel routed through it becomes Cash."
	if resources.credits < 1.0:
		return "Route your Intel through the Darknet Market to C2 and watch the Cash arrive."
	if not has_producer:
		return "Add more producers and link them to C2 to grow throughput."
	return "Scale up Intel + Markets, or diversify into Crypto → Mixer. Reach %d Cash." % int(GOAL_CREDITS)


func _can_afford(code: String) -> bool:
	for k in COST[code]:
		if resources[k] < COST[code][k]:
			return false
	return true


func _pay(code: String) -> void:
	for k in COST[code]:
		resources[k] -= COST[code][k]


func _placement_error(code: String, origin: Vector2i, size: int) -> String:
	var cells := _cells_of(origin, size)
	var tunnel_cells := _used_cells()
	for c in cells:
		if c.x < 0 or c.y < 0 or c.x >= MAP_W or c.y >= MAP_H:
			return "Off the map."
		if _node_at(c) != -1:
			return "Overlaps another building."
		if tunnel_cells.has(c):   # B09: a footprint cell may fall on a street a tunnel runs through
			return "An active tunnel runs here — reroute or remove it before building."
	var vl := _vision_list()
	for c in cells:
		if not _is_visible(c, vl):
			return "Outside vision — no coverage here. Extend the botnet closer first."
	var bcount := 0
	for c in cells:
		if _is_building_cell(c):
			bcount += 1
	if bcount * 2 < cells.size():
		return "Must sit on a building — not an empty street or plaza."
	var center := Vector2(origin) + Vector2(size, size) * 0.5
	match code:
		"nest":
			for c in cells:
				var tt: String = _tile_type(c)
				if tt != "residential" and ZONE_RES.get(tt, "") != "Cycles":
					return "%s needs residential or Cycles (green) ground." % DEFS.nest.name
			for id in nodes:
				if nodes[id].type == "nest" and not nodes[id].get("relay", false):
					var oc := Vector2(nodes[id].cell) + Vector2(nodes[id].size, nodes[id].size) * 0.5
					if oc.distance_to(center) < NEST_SPACING:
						return "Too close to another %s." % DEFS.nest.name
		"phish", "salami", "package", "scraper", "botfarm":
			var need: String = PRODUCER_RES.get(code, "")
			for c in cells:
				if ZONE_RES.get(_tile_type(c), "") != need:
					return "%s needs %s ground (%s), whole footprint." % [DEFS[code].name, need, _zones_for_res(need)]
			# B54: count slots in the district this footprint will actually OCCUPY (its center
			# region — the same cell used for occupancy), not the origin's region, so a
			# boundary-straddling build can't sneak into a full neighbouring district.
			if _slots_left(origin + Vector2i(size / 2, size / 2)) <= 0:
				return "This district is full — no free slot for another %s producer." % need
	if not _can_afford(code):
		return "Not enough resources."
	# ICE affordability applies to ANY structure placed in a guarded district, not just
	# producers: breaching costs Tools ON TOP of the build cost. Validate here, before any
	# state change, so a placement can never drive Tools negative (B02).
	var ice: int = _zone_ice(origin)
	if ice > 0 and resources.tools < float(COST[code].get("tools", 0.0)) + float(ice):
		return "ICE tier %d — needs %d Tools to breach (forge it in an Exploit Forge)." % [ice, ice]
	return ""


func _zone_ice(cell: Vector2i) -> int:
	if regions.is_empty():
		return 0
	return int(regions[_region_at(cell)].ice)


# Districts of a resource list the districts you can build that resource's producer in.
func _zones_for_res(res_name: String) -> String:
	var names := []
	for z in ZONE_RES:
		if ZONE_RES[z] == res_name:
			names.append(str(ZONE_NAMES.get(z, z)))
	return " or ".join(names) if not names.is_empty() else "the matching district"


func _slots_left(anchor: Vector2i) -> int:
	# `anchor` is the OWNING cell (a footprint's centre), so validation and occupancy agree (B54)
	if regions.is_empty():
		return 0
	var ridx := _region_at(anchor)
	var res_name: String = ZONE_RES.get(regions[ridx].type, "")
	if res_name == "":
		return 0
	var cap := clampi(int(regions[ridx].cells), 2, 10)  # bigger district = more slots
	var used := 0
	for id in nodes:
		if nodes[id].get("relay", false):
			continue
		if PRODUCER_RES.get(nodes[id].type, "") == res_name and _region_at(_center_cell(id)) == ridx:
			used += 1
	return cap - used


func _try_place_node(code: String, cell: Vector2i) -> void:
	var size := int(SIZE[code])
	var origin := cell - Vector2i(size / 2, size / 2)
	var err := _placement_error(code, origin, size)
	if err != "":
		message = "Can't place: " + err
		return
	_pay(code)
	var ice := _zone_ice(origin)
	var breached := ""
	if ice > 0:
		resources.tools -= float(ice)
		trace = clampf(trace + ICE_TRACE, 0.0, 100.0)
		breached = "  ICE breached (−%d Tools, Trace +%d)." % [ice, int(ICE_TRACE)]
	nodes[next_id] = {"id": next_id, "type": code, "cell": origin, "size": size, "parent": -1, "tunnel": "", "relay": false, "on": true, "cap_rate": 1.0, "boost_t": 0.0, "lane": 0, "path": []}
	var refund: Dictionary = COST[code].duplicate()
	if ice > 0:
		refund["tools"] = float(refund.get("tools", 0.0)) + float(ice)
	_push_undo({"t": "place", "id": next_id, "cost": refund})
	next_id += 1
	message = "%s deployed. Link it back to C2 with a tunnel.  (Ctrl+Z to undo)%s" % [DEFS[code].name, breached]


func _try_convert_relay(cell: Vector2i) -> void:
	var id := _node_at(cell)
	if id == -1 or id == hub_id or not _is_producer(nodes[id].type):
		message = "Click one of your producer structures to turn it into a %s." % DEFS["relay"].name
		return
	if nodes[id].get("relay", false):
		message = "That structure is already a %s." % DEFS["relay"].name
		return
	if not _can_afford("relay"):
		message = "Not enough resources for a %s." % DEFS["relay"].name
		return
	_pay("relay")
	nodes[id].relay = true
	_push_undo({"t": "relay", "id": id, "cost": COST.relay.duplicate()})
	message = "Converted to a %s — it stops producing and now just routes data toward C2 at low upkeep." % DEFS["relay"].name


func _try_tunnel(cell: Vector2i) -> void:
	var id := _node_at(cell)
	if id == -1:
		message = "Click a node."
		return
	if pending_child == -1:
		if id == hub_id:
			message = "Start from a structure, not the C2 Server — tunnels lead back to it."
			return
		if nodes[id].parent != -1:
			message = "That structure already has a tunnel out."
			return
		pending_child = id
		message = "Now click any node to link toward — the C2, a Relay/Market, or another structure (data flows on to C2)."
		return
	# choosing parent
	if not nodes.has(pending_child):   # B53/B11: armed source vanished (undone) — drop the stale arm
		pending_child = -1
		message = "That link source no longer exists. Pick a structure to link from."
		return
	if nodes[pending_child].parent != -1:
		# B53: the source got (re)linked since it was armed (e.g. an Undo restored its old
		# link). Committing now would silently replace that link and lose it to Undo. Refuse.
		pending_child = -1
		message = "That structure is already linked now — its earlier arm was stale. Re-arm to reroute."
		return
	if id == pending_child:
		message = "Pick a different node to link to."
		return
	if _would_cycle(pending_child, id):
		message = "That would loop back on itself — link toward C2, not into your own downstream."
		return
	var path := _find_path(pending_child, id, _tool_maxlen(current_tool))
	if path.is_empty():
		message = "No clear route — blocked by tunnels or structures, or further than %d pkt. Use a Proxy or an Onion Route." % _lag(_tool_maxlen(current_tool))
		return
	if not _can_afford(current_tool):
		message = "Not enough resources for a %s." % _tool_name(current_tool)
		return
	_pay(current_tool)
	# pick a lane so parallel tunnels on shared cells don't overlap visually
	var used := _used_cells()
	var lane := 0
	for c in path:
		lane = maxi(lane, int(used.get(c, 0)))
	nodes[pending_child].parent = id
	nodes[pending_child].tunnel = current_tool
	nodes[pending_child].path = path
	nodes[pending_child].lane = clampi(lane, 0, LANES - 1)
	_push_undo({"t": "tunnel", "child": pending_child, "cost": COST[current_tool].duplicate()})
	_pl_cache.clear()
	if _reaches_hub(pending_child):
		message = "%s tunnel linked." % current_tool.to_upper()
	else:
		message = "%s linked — but this branch still has NO path to the Hub. Connect it onward (it shows red)." % current_tool.to_upper()
	pending_child = -1


func _remove_node(id: int) -> void:
	var snap = nodes[id].duplicate(true)
	var detached := []
	# detach children (they lose their tunnel out)
	for cid in nodes:
		if nodes[cid].parent == id:
			detached.append({"cid": cid, "parent": id, "tunnel": nodes[cid].tunnel, "path": nodes[cid].path.duplicate(), "lane": nodes[cid].get("lane", 0)})
			nodes[cid].parent = -1
			nodes[cid].tunnel = ""
			nodes[cid].path = []
	nodes.erase(id)
	_push_undo({"t": "dismantle", "node": snap, "detached": detached})
	_pl_cache.clear()
	message = "Removed.  (Ctrl+Z to undo)"


# ---------- Simulation ----------
func _process(delta: float) -> void:
	# B43: re-bake the static city backdrop when the colour-blind palette toggles
	if _last_cb_pal != Settings.cb:
		_last_cb_pal = Settings.cb
		_invalidate_city()
	# camera pan — B37: raw key/edge panning is suppressed while a blocking modal / pause menu is up
	var blocked: bool = modal_open or pause_menu
	var pan := Vector2.ZERO
	if not blocked:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.y += 1
	if pan != Vector2.ZERO:
		camera.position += pan.normalized() * 500.0 * delta / camera.zoom.x
	# edge-pan: push the mouse to a screen edge to scroll the map (no clicking needed)
	var mp := get_viewport().get_mouse_position()
	var vs: Vector2 = get_viewport_rect().size
	if not blocked and mp.x >= 300.0:  # ignore the left control panel
		var ep := Vector2.ZERO
		if mp.x <= 326.0: ep.x -= 1.0           # just right of the panel → scroll left
		elif mp.x >= vs.x - 22.0: ep.x += 1.0   # right edge → scroll right
		if mp.y <= 22.0: ep.y -= 1.0            # top edge → scroll up
		elif mp.y >= vs.y - 22.0: ep.y += 1.0   # bottom edge → scroll down
		if ep != Vector2.ZERO:
			camera.position += ep.normalized() * 480.0 * delta / camera.zoom.x
	# cursor feedback: crosshair while building/placing, a hand when a node is under it
	var cs: int = Input.CURSOR_ARROW
	if current_tool != "":
		cs = Input.CURSOR_CROSS
	elif _node_at(_mouse_cell()) != -1:
		cs = Input.CURSOR_POINTING_HAND
	if cs != _cursor_shape:
		_cursor_shape = cs
		Input.set_default_cursor_shape(cs)

	_update_hint()
	# sample net resource rates once per second for the HUD
	if not paused:
		_rate_t += delta
		if _rate_t >= 1.0:
			for k in resources:
				rates[k] = (resources[k] - float(_rate_prev.get(k, resources[k]))) / _rate_t
				_rate_prev[k] = resources[k]
			_peak_cash_rate = maxf(_peak_cash_rate, float(rates.get("credits", 0.0)))
			_hist_cash.append(float(resources.credits))
			if _hist_cash.size() > 120:
				_hist_cash.pop_front()
			_rate_t = 0.0
	if not paused:
		for k in range(_drops.size() - 1, -1, -1):
			_drops[k].t -= delta
			if _drops[k].t <= 0.0:
				_drops.remove_at(k)
		_time += delta
		_accum += delta
		while _accum >= TICK_DT:
			_accum -= TICK_DT
			_sim_tick(TICK_DT)
	# Repaint gating: only queue a redraw when something visible is actually changing.
	# With motion on, ambient animation (motes/pulses) needs a steady repaint; with
	# reduced motion only packets/drops/the sweep animate; when paused nothing animates,
	# so we repaint solely on view/pointer/tool changes. Big idle-CPU/GPU saving.
	var view_changed: bool = camera.position != _last_cam_pos or camera.zoom != _last_cam_zoom or mp != _last_mouse
	_last_cam_pos = camera.position
	_last_cam_zoom = camera.zoom
	_last_mouse = mp
	var animating: bool = not paused and (not Settings.reduced_motion or not packets.is_empty() or not _drops.is_empty() or not sweep.is_empty())
	# B51: discrete state changes (toggle, dismantle, undo, settings, selection) must repaint
	# once even on a stationary paused view. A cheap visual signature catches them.
	var vsig := _visual_sig()
	if not _vsig_init:
		_vsig_init = true
		_last_vsig = vsig
	var state_changed: bool = vsig != _last_vsig
	_last_vsig = vsig
	if animating or view_changed or state_changed or current_tool != "" or pending_child != -1:
		queue_redraw()


# How many distinct city buildings a hack sweeps (within COVERAGE_RADIUS) — more = more output.
func _coverage(center: Vector2i) -> int:
	var P := 4
	var blocks := {}
	for dy in range(-COVERAGE_RADIUS, COVERAGE_RADIUS + 1):
		for dx in range(-COVERAGE_RADIUS, COVERAGE_RADIUS + 1):
			if dx * dx + dy * dy > COVERAGE_RADIUS * COVERAGE_RADIUS:
				continue   # B26: count a DISK, matching the coverage circle that is drawn
			var c := center + Vector2i(dx, dy)
			if _is_building_cell(c):
				blocks[Vector2i(c.x / P, c.y / P)] = true
	return blocks.size()


# Output multiplier from coverage: ~1.0 for a typical spot, up to 2.5 in a dense district.
func _cov_mult(id: int) -> float:
	if not nodes[id].has("coverage"):
		nodes[id].coverage = _coverage(_center_cell(id))
	return clampf(float(nodes[id].coverage) / 5.0, 0.5, 2.5)


func _production(id: int) -> Dictionary:
	if nodes[id].get("relay", false) or not nodes[id].get("on", true):
		return {}  # a Proxy doesn't produce; neither does a disabled structure
	var m: float = float(nodes[id].get("cap_rate", 1.0)) * _cov_mult(id)  # output limit × city coverage
	if float(nodes[id].get("boost_t", 0.0)) > 0.0:
		m *= 2.0  # Overclock command
	match nodes[id].type:
		"nest": return {"compute": RATE_NEST * m}
		"package": return {"compute": RATE_PACKAGE * m}
		"botfarm": return {"compute": RATE_BOTFARM * m}
		"phish": return {"data": RATE_PHISH * m}
		"scraper": return {"data": RATE_SCRAPER * m}
		"salami": return {"crypto": RATE_SALAMI * m}
	return {}


func _is_producer(type: String) -> bool:
	return type in ["nest", "package", "botfarm", "phish", "scraper", "salami"]


# B43: a structure marker's colour. Under the colour-blind palette it borrows its resource's
# semantic colour (matching the packets), so map/minimap/chip colours stay consistent; the
# default palette keeps the hand-tuned COLORS look. Glyphs still carry identity as a pattern.
func _sem_color(type: String) -> Color:
	if Settings.cb and PRODUCER_OUT.has(type):
		return Settings.res_color(PRODUCER_OUT[type])
	return COLORS.get(type, Color(0.6, 0.65, 0.75))


# B43: ground district tint, likewise resource-consistent under the colour-blind palette.
func _zone_sem_color(dtype: String) -> Color:
	if Settings.cb and ZONE_RES.has(dtype) and RES_KEY.has(ZONE_RES[dtype]):
		var c: Color = Settings.res_color(RES_KEY[ZONE_RES[dtype]])
		return Color(c.r, c.g, c.b, 0.85)
	return ZONE_COLOR.get(dtype, Color(0.5, 0.5, 0.6))


# True if any connected, running, non-relay structure actually produces Cycles.
func _has_cycle_income() -> bool:
	for id in nodes:
		var n = nodes[id]
		if id == hub_id or n.get("relay", false) or not n.get("on", true):
			continue
		if _connected.has(id) and PRODUCER_RES.get(n.type, "") == "Cycles":
			return true
	return false


# Guarantee recoverability: if the run has no Cycles income and can't afford the cheapest
# producer, drip Cycles up to EMERGENCY_FLOOR. Only fires in a genuinely stalled run, so it
# never affects normal play; it is a floor, not an income. (B01/T40)
func _emergency_supply(dt: float) -> void:
	if resources.compute >= EMERGENCY_FLOOR or _has_cycle_income():
		if _emergency_active and resources.compute >= EMERGENCY_FLOOR:
			_emergency_active = false
		return
	resources.compute = minf(EMERGENCY_FLOOR, float(resources.compute) + EMERGENCY_RATE * dt)
	if not _emergency_active:
		_emergency_active = true
		message = "Emergency reserve online — the C2 is supplying Cycles to rebuild."


func _sim_tick(dt: float) -> void:
	_run_time += dt
	_max_trace = maxf(_max_trace, trace)
	for id in nodes:
		if float(nodes[id].get("quarantine", 0.0)) > 0.0:
			nodes[id].quarantine = maxf(0.0, float(nodes[id].quarantine) - dt)
	for fk in _deliver_flash.keys():
		_deliver_flash[fk] = maxf(0.0, float(_deliver_flash[fk]) - dt)
	_blackout_t = maxf(0.0, _blackout_t - dt)
	# children adjacency from parent pointers
	var children := {}
	for id in nodes:
		var p: int = nodes[id].parent
		if p != -1:
			if not children.has(p):
				children[p] = []
			children[p].append(id)

	# subtree packet load (raw, per-second magnitude) + reachable set from hub
	var subtree := {}
	var reachable := {}
	_calc_subtree(hub_id, children, subtree, reachable)
	_connected = reachable

	# upkeep over ALL built tunnels (connected or not). A link is physical infrastructure:
	# it costs upkeep as long as it is built and keeps routing, even when the structure's
	# production is switched OFF (disabling halts production, not forwarding). (B05)
	total_upkeep = 0.0
	for id in nodes:
		if nodes[id].parent != -1:
			var d := _edge_len(id, nodes[id].parent)
			var u := d * float(UPKEEP[nodes[id].tunnel])
			if nodes[id].get("relay", false):
				u *= 0.4  # a Proxy forwards data cheaply — minimum upkeep
			total_upkeep += u

	# how well can we feed the tunnels this tick (based on current compute stock).
	# Never below MIN_FEED: a hungry network crawls but can always recover.
	var needed := total_upkeep * dt
	if needed <= 0.0:
		slow_factor = 1.0
	else:
		slow_factor = clampf(resources.compute / needed, MIN_FEED, 1.0)
		resources.compute -= minf(resources.compute, needed * slow_factor)

	# per-edge delivered fraction under current throughput
	_edge.clear()
	warn_overload = false
	for id in reachable:
		if id == hub_id:
			continue
		# loss depends on load vs capacity only; hunger (slow_factor) slows packets
		# instead of destroying them
		var offered: float = subtree[id]
		var cap: float = float(CAP[nodes[id].tunnel])
		if nodes[id].get("relay", false) and children.has(id):
			cap += float(clampi(children[id].size() - 1, 0, 4))  # topology: a relay aggregating branches boosts its trunk
		# per-node throughput ceiling + connection overload (#5): any node relaying many
		# incoming links chokes past LINK_SOFT connections
		var ncap: float = NODE_CAP["relay"] if nodes[id].get("relay", false) else float(NODE_CAP.get(nodes[id].type, 8.0))
		var nconn: int = children[id].size() if children.has(id) else 0
		if nconn > LINK_SOFT:
			ncap *= maxf(0.4, 1.0 - 0.12 * float(nconn - LINK_SOFT))
		cap = minf(cap, ncap)
		# distance loss: long tunnels bleed packets (encourages relays / short hops)
		var length := float(nodes[id].get("path", []).size())
		var dist_loss := length * float(TUNNEL_LOSS.get(nodes[id].tunnel, 0.01))
		var loss := dist_loss
		var over: bool = offered > cap
		if over:
			loss += (offered - cap) * 0.5 / cap  # overload on top of distance loss
			warn_overload = true
		loss = clampf(loss, 0.0, 0.9)
		var frac := 1.0 - loss
		# ICE throttles the botnet while Trace is hot — a SEPARATE multiplier, not distance (B58)
		var trace_hot: bool = trace > TRACE_HOT
		if trace_hot:
			frac *= 0.8
		# store loss components so the UI can attribute each cause honestly (B58)
		_edge[id] = {"frac": frac, "offered": offered, "delivered": offered * frac, "cap": cap, "over": over,
			"dist_loss": clampf(dist_loss, 0.0, 0.9), "over_loss": clampf(loss - dist_loss, 0.0, 0.9), "trace_hot": trace_hot}

	# producers emit one packet per unit produced; it travels the tunnels for real
	for id in reachable:
		if _blackout_t > 0.0:
			break  # C2 blackout after an ICE sweep: production paused
		var prod := _production(id)
		if prod.is_empty():
			continue
		var res: String = prod.keys()[0]
		var acc: float = float(nodes[id].get("acc", 0.0)) + float(prod[res]) * dt
		while acc >= 1.0:
			acc -= 1.0
			_spawn(res, _chain(id), 1)
		nodes[id].acc = acc

	# Processors (Market/Forge/Mixer) pull a stored resource from C2 one unit at a
	# time, convert it, and send the product back — all as real travelling packets.
	for id in reachable:
		if _blackout_t > 0.0:
			break
		var ct: String = nodes[id].type
		if not CONV.has(ct) or not nodes[id].get("on", true):
			continue
		var cv: Dictionary = CONV[ct]
		# consumption speed is capped by the processor's own tunnel capacity (#5)
		var eff := minf(float(cv.rate), float(CAP.get(nodes[id].tunnel, 999.0)))
		var acc: float = float(nodes[id].get("acc", 0.0)) + eff * dt
		while acc >= 1.0 and resources[cv.in] >= 1.0 and (not cv.has("fuel") or resources[cv.fuel] >= float(cv.fuelcost)):
			acc -= 1.0
			resources[cv.in] -= 1.0
			if cv.has("fuel"):
				resources[cv.fuel] -= float(cv.fuelcost)
			var route := _chain(id)
			route.reverse()
			_spawn(cv.in, route, -1)
		nodes[id].acc = minf(acc, 1.0)  # don't bank pulls while input is empty

	# Trace: each live tunnel adds its protocol's noise (VPN cools), plus steady decay.
	# Overclock boosts also time out here.
	var noise := 0.0
	for id in nodes:
		if float(nodes[id].get("boost_t", 0.0)) > 0.0:
			nodes[id].boost_t = maxf(0.0, float(nodes[id].boost_t) - dt)
		if nodes[id].parent != -1 and nodes[id].get("on", true) and _connected.has(id):
			noise += float(TUNNEL_NOISE.get(nodes[id].tunnel, 0.0))
	trace = clampf(trace + (noise - TRACE_DECAY) * dt, 0.0, 100.0)

	# --- ICE Sweep antagonist: a telegraphed tracer that walks your tunnels to C2 ---
	var wealth: float = float(resources.credits) / 25.0 + float(nodes.size()) * 0.7
	notoriety = minf(100.0, maxf(notoriety, wealth) + dt * 0.03)
	_update_sweep(dt)
	_update_contracts(dt)

	_move_packets(dt)

	# clamp + win check
	for k in resources:
		if resources[k] < 0.0:
			resources[k] = 0.0
	_emergency_supply(dt)   # guarantee a recoverable Cycles floor (B01/T40)
	if not won and resources.credits >= GOAL_CREDITS:
		won = true
		message = "GOAL REACHED — %d Cash! The Rim is yours." % int(GOAL_CREDITS)


func _calc_subtree(id: int, children: Dictionary, subtree: Dictionary, reachable: Dictionary) -> float:
	if id != hub_id and float(nodes[id].get("quarantine", 0.0)) > 0.0:
		subtree[id] = 0.0
		return 0.0  # quarantined by an ICE sweep — cut from the network until it expires
	reachable[id] = true
	var load := _node_traffic(id)
	if children.has(id):
		for cid in children[id]:
			load += _calc_subtree(cid, children, subtree, reachable)
	subtree[id] = load
	return load


# Packets/sec this node injects onto its trunk toward C2: producer output PLUS a converter's
# input pull (down) and product return (up), which both ride the same edges. (B04)
func _node_traffic(id: int) -> float:
	var t := 0.0
	var prod := _production(id)
	for k in prod:
		t += float(prod[k])
	var ct: String = nodes[id].type
	if CONV.has(ct) and nodes[id].get("on", true) and not nodes[id].get("relay", false):
		var cv: Dictionary = CONV[ct]
		if float(resources.get(cv.in, 0.0)) >= 1.0:
			var eff := minf(float(cv.rate), float(CAP.get(nodes[id].tunnel, 999.0)))
			t += eff * 2.0   # one unit of input down + one unit of product up per conversion
	return t


# ---------- ICE Sweep antagonist ----------
func _launch_sweep() -> void:
	# target the deepest connected node (most hops to C2 = the most dramatic trace-back)
	var target := -1
	var best := 0
	for id in nodes:
		if id == hub_id or not _connected.has(id):
			continue
		var ch := _chain(id)
		if ch.size() > best:
			best = ch.size()
			target = id
	if target == -1:
		return
	var path := _chain(target)   # [target, ..., node whose parent is hub]
	path.append(hub_id)
	sweep = {"path": path, "step": 0, "t": 0.0, "warn": 6.0}
	message = "⚠ ICE SWEEP INBOUND — a trace is heading for your C2. Go quiet, reroute, cut the line, or DDoS!"


func _update_sweep(dt: float) -> void:
	if sweep.is_empty():
		# charge toward the next sweep while you're loud / notorious
		if trace > 35.0 or notoriety > 45.0:
			_sweep_charge += dt * (0.015 + trace / 500.0 + notoriety / 600.0)
			if _sweep_charge >= 1.0:
				_sweep_charge = 0.0
				_launch_sweep()
		return
	var path: Array = sweep.path
	var step: int = int(sweep.step)
	if step >= path.size():
		sweep = {}
		return
	var cur: int = path[step]
	# sever-the-branch counterplay: dismantle the node the tracer is on and the trail breaks
	if cur != hub_id and not nodes.has(cur):
		sweep = {}
		message = "Trace lost the trail — you cut the line. Sweep fizzled out."
		return
	# B13: the tracer can only follow a LIVE link. If the swept edge was cut or rerouted (the
	# traced node no longer links to the next node on the path), the trail breaks — rerouting
	# or cutting a swept link is real, immediate counterplay, not just future quieting.
	if cur != hub_id and step + 1 < path.size() and nodes[cur].parent != int(path[step + 1]):
		sweep = {}
		message = "Trace lost the trail — you rerouted the swept link. Sweep fizzled out."
		return
	if float(sweep.warn) > 0.0:
		sweep.warn = float(sweep.warn) - dt
		# B14: the telegraph is a warning, not an attack — no quarantine until it ends.
		# Impact lands on the first node the moment the warning expires.
		if float(sweep.warn) <= 0.0 and nodes.has(cur) and cur != hub_id:
			nodes[cur].quarantine = 7.0
		return
	var speed := 0.4 + float(step) / float(path.size()) * 1.1   # accelerates as it nears C2
	sweep.t = float(sweep.t) + speed * dt
	while float(sweep.t) >= 1.0 and not sweep.is_empty():
		sweep.t = float(sweep.t) - 1.0
		step = int(sweep.step) + 1
		sweep.step = step
		if step >= path.size():
			sweep = {}
			break
		var nid: int = path[step]
		if nid == hub_id:
			_sweep_blackout()
			sweep = {}
			break
		if nodes.has(nid):
			nodes[nid].quarantine = 7.0   # quarantined (offline), recoverable when it expires


func _sweep_blackout() -> void:
	_blackout_t = 4.0
	trace = clampf(trace - 40.0, 0.0, 100.0)
	resources.credits = maxf(0.0, resources.credits - 25.0)  # a telegraphed, survivable sting
	message = "ICE reached your C2 — BLACKOUT. Production paused ~4s, −25 Cash. Keep it quieter."


# ---------- Contracts (jobs board) ----------
func _gen_contract() -> Dictionary:
	var c := {"id": _next_contract_id, "client": CLIENTS[rng.randi() % CLIENTS.size()],
		"accepted": false, "done": false}
	_next_contract_id += 1
	var kinds := ["stock", "stock", "nodes", "cash"]
	c["kind"] = kinds[rng.randi() % kinds.size()]
	match c.kind:
		"stock":
			var opts := [["data", "Intel"], ["crypto", "Crypto"], ["compute", "Cycles"]]
			var o: Array = opts[rng.randi() % opts.size()]
			var amt := float((rng.randi() % 4 + 2) * 10)
			c["res"] = o[0]; c["amount"] = amt
			c["desc"] = "Deliver %d %s to C2" % [int(amt), o[1]]
			c["reward_cash"] = amt * 2.5; c["reward_rp"] = 5.0; c["deadline"] = 90.0
		"nodes":
			var amt := float(rng.randi() % 3 + 4)
			c["res"] = ""; c["amount"] = amt
			c["desc"] = "Add %d linked structures" % int(amt)
			c["reward_cash"] = 90.0; c["reward_rp"] = 8.0; c["deadline"] = 120.0
		"cash":
			var amt := float((rng.randi() % 3 + 2) * 50)
			c["res"] = ""; c["amount"] = amt
			c["desc"] = "Bank %d more Cash" % int(amt)
			c["reward_cash"] = 0.0; c["reward_rp"] = 14.0; c["deadline"] = 100.0
	return c


# Raw current value a contract measures (stockpile / cash / linked-structure count).
func _contract_raw(c: Dictionary) -> float:
	match c.kind:
		"stock": return float(resources.get(c.res, 0.0))
		"cash": return float(resources.credits)
		"nodes":
			var n := 0
			for id in nodes:
				if id != hub_id and _connected.has(id) and not nodes[id].get("relay", false):
					n += 1
			return float(n)
	return 0.0


# Progress is measured from a baseline captured when the job is ACCEPTED, so you must earn
# the amount AFTER taking the job — holding it already never auto-completes the contract.
func _contract_progress(c: Dictionary) -> float:
	return maxf(0.0, _contract_raw(c) - float(c.get("base", 0.0)))


func _update_contracts(dt: float) -> void:
	_contract_cd -= dt
	if _contract_cd <= 0.0 and contracts.size() < 3:
		contracts.append(_gen_contract())
		_contract_cd = 22.0
		_contracts_ver += 1
	for i in range(contracts.size() - 1, -1, -1):
		var c: Dictionary = contracts[i]
		if c.done:
			continue
		if c.accepted:
			if _contract_progress(c) >= float(c.amount):
				c.done = true
				_contracts_ver += 1
			else:
				c.deadline = float(c.deadline) - dt
				if float(c.deadline) <= 0.0:
					contracts.remove_at(i)
					_contracts_ver += 1
					message = "Contract expired — %s." % c.client


func accept_contract(id: int) -> void:
	for c in contracts:
		if int(c.id) == id and not c.accepted:
			c.accepted = true
			c["base"] = _contract_raw(c)   # progress counts only what you earn AFTER accepting
			_contracts_ver += 1
			message = "Contract accepted — %s: %s." % [c.client, c.desc]
			return


func claim_contract(id: int) -> void:
	for i in contracts.size():
		if int(contracts[i].id) == id and contracts[i].done:
			resources.credits += float(contracts[i].reward_cash)
			resources.research += float(contracts[i].reward_rp)
			message = "Contract paid — +%d Cash, +%d Research." % [int(contracts[i].reward_cash), int(contracts[i].reward_rp)]
			contracts.remove_at(i)
			_contracts_ver += 1
			return


func _scorecard() -> String:
	var mins := int(_run_time) / 60
	var secs := int(_run_time) % 60
	return "Time %d:%02d    Peak %0.1f Cash/s    Packets %d    Peak Trace %d%%    Nodes %d" % [
		mins, secs, _peak_cash_rate, _packets_delivered, int(_max_trace), nodes.size()]


# ---------- Rendering ----------
# World-space AABB of a tunnel: both node footprints plus every routed path cell, so culling
# keeps a tunnel (and its packets) visible whenever any part of its real route is on screen.
func _path_bounds(id: int) -> Rect2:
	var r := Rect2(Vector2(nodes[id].cell) * TILE, Vector2(nodes[id].size, nodes[id].size) * TILE)
	var pid: int = nodes[id].parent
	if pid != -1 and nodes.has(pid):
		r = r.merge(Rect2(Vector2(nodes[pid].cell) * TILE, Vector2(nodes[pid].size, nodes[pid].size) * TILE))
	for c in nodes[id].get("path", []):
		r = r.merge(Rect2(Vector2(c) * TILE, Vector2(TILE, TILE)))
	return r


func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_city_overlay(font)

	# view-frustum culling: only draw what's actually on screen. Everything below iterates
	# all nodes/packets, so without this the whole network is redrawn every frame even when
	# most of it is off the edge of the viewport — the dominant cost on big maps.
	var _vp: Vector2 = get_viewport_rect().size / camera.zoom.x
	var view := Rect2(camera.position - _vp * 0.5, _vp)
	var view_b := view.grow(TILE * 2.0)          # buildings (footprint + glow margin)
	var view_t := view.grow(TILE * 4.0)          # tunnels/packets (paths bow out a little)
	var vis_edge := {}                            # edge ids whose tunnel is on screen

	# tunnels
	for id in nodes:
		if nodes[id].parent == -1:
			continue
		# B52: cull against the tunnel's ACTUAL routed path bounds, not just its endpoints —
		# a detour can bow into view while both endpoints are off screen.
		if not view_t.intersects(_path_bounds(id)):
			continue
		vis_edge[id] = true
		var pts := _edge_pts(id, nodes[id].parent)
		var width := 2.0 if nodes[id].tunnel == "dns" else 4.0
		if Settings.high_contrast:
			width *= 1.6
		var connected := _connected.has(id)
		var on: bool = nodes[id].get("on", true)
		var col := Color(0.5, 0.5, 0.6, 0.6)
		var frac := 1.0
		if not on:
			col = Color(0.45, 0.45, 0.5, 0.4)
		elif not connected:
			col = Color(1.0, 0.35, 0.35, 0.5)         # red: no path to C2
		elif _edge.has(id):
			frac = _edge[id].frac
			var over: bool = _edge[id].get("over", false)
			# green unless actually OVER CAPACITY; a long link's distance bleed stays "ok"
			col = Settings.health_color("ok" if not over else ("bad" if frac <= 0.5 else "warn"))
			col.a = 0.85
		if id == selected_tunnel:
			draw_polyline(pts, Color(1, 1, 1, 0.5), width + 7.0)
		if camera.zoom.x > 0.55:
			draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.5), width + 3.0)   # dark casing for contrast
		draw_polyline(pts, col, width)
		# Per-tunnel labels are a per-frame draw_string each — only show them when zoomed in
		# enough to read, or for the one selected tunnel. Big networks drew dozens every frame.
		if id == selected_tunnel or camera.zoom.x > 0.6:
			var tlen := 0.0
			for s in range(pts.size() - 1):
				tlen += pts[s].distance_to(pts[s + 1])
			var lp := _point_at_dist(pts, tlen * 0.5) + Vector2(-12, -9)
			var lsz := int(round(11.0 * Settings.text_scale))
			if not on:
				draw_string(font, lp, "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, Color(0.8, 0.8, 0.85))
			elif not connected:
				draw_string(font, lp, ("ICE" if float(nodes[id].get("quarantine", 0.0)) > 0.0 and _reaches_hub(id) else "offline"), HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, Color(1, 0.45, 0.45))
			else:
				var lag := _lag(_edge_len(id, nodes[id].parent))
				var over: bool = _edge.has(id) and _edge[id].get("over", false)
				var trace_hot: bool = _edge.has(id) and _edge[id].get("trace_hot", false)
				var pct := int(round((1.0 - frac) * 100.0))
				# OVERLOADED only when truly over capacity; otherwise name the real cause of loss
				# instead of blaming distance for the ICE/Trace penalty (B58)
				var sym := " ✓"
				if over:
					sym = "  ▲ OVERLOADED -%d%%" % pct
				elif pct >= 1:
					sym = "  -%d%% (distance+ICE)" % pct if trace_hot else "  -%d%% (distance)" % pct
				draw_string(font, lp, "%d pkt%s" % [lag, sym], HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, col)

	# highlight the selected structure's route back to C2 (the path its packets take)
	if selected_id != -1 and selected_id != hub_id and nodes.has(selected_id) and _connected.has(selected_id):
		var hl := Color(1.0, 0.95, 0.3, 0.85)
		var hw := 8.0 if Settings.high_contrast else 6.0
		for cid in _chain(selected_id):
			if nodes.has(cid) and nodes[cid].parent != -1:
				draw_polyline(_edge_pts(cid, nodes[cid].parent), hl, hw)

	# ICE sweep telegraph: a red tracer walking your tunnels toward C2 (reduced-motion safe)
	if not sweep.is_empty():
		var spath: Array = sweep.path
		var sstep: int = int(sweep.step)
		var spulse := 0.7 if Settings.reduced_motion else (0.45 + 0.45 * absf(sin(_time * 4.0)))
		var scol := Color(1.0, 0.25, 0.2, spulse)
		for k in range(sstep, spath.size() - 1):
			if nodes.has(spath[k]) and nodes.has(spath[k + 1]):
				draw_line(_center_world(spath[k]), _center_world(spath[k + 1]), scol, 6.0 if Settings.high_contrast else 4.0)
		if sstep < spath.size() and nodes.has(spath[sstep]):
			var np: int = spath[min(sstep + 1, spath.size() - 1)]
			var a := _center_world(spath[sstep])
			var b := _center_world(np) if nodes.has(np) else a
			var tp := a.lerp(b, clampf(float(sweep.t), 0.0, 1.0))
			draw_circle(tp, 9.0, Color(1.0, 0.2, 0.15, 0.95))
			draw_arc(tp, 14.0, 0, TAU, 22, Color(1.0, 0.45, 0.3, spulse), 2.5)

	# packets — one unit of resource in transit. Shape-coded by resource pictogram
	# (identity never rides on colour alone), with a short Matrix-style trail up close.
	var dots_mode := Settings.dots or Settings.reduced_motion or camera.zoom.x <= 0.8 or packets.size() > 220
	var pkt_r := 4.4 if Settings.high_contrast else 3.3
	var trail_sz := int(round(11.0 * Settings.text_scale))
	for p in packets:
		var e: int = p.route[p.idx]
		if not nodes.has(e) or nodes[e].parent == -1:
			continue
		if not vis_edge.has(e):   # packet's current tunnel is off screen — skip it
			continue
		var pl := _polyline(e)
		var along: float = float(p.dist) if p.dir == 1 else maxf(0.0, float(pl.total) - float(p.dist))
		var col: Color = Settings.res_color(p.res)
		var pos := _point_at_dist(pl.pts, along)
		Glyphs.draw_resource(self, p.res, pos, pkt_r)   # head = resource shape, always drawn
		if dots_mode:
			continue
		for tr in range(1, 3):
			var dd := along - float(tr) * 7.0
			if dd < 0.0:
				break
			draw_string(font, _point_at_dist(pl.pts, dd) + Vector2(-3, 4), _matrix_char(p.res, dd - float(tr)), HORIZONTAL_ALIGNMENT_LEFT, -1, trail_sz, Color(col.r, col.g, col.b, 0.4 / float(tr)))

	# dropped packets (packet loss) flash a red X briefly
	for d in _drops:
		var a: float = 1.0 if Settings.reduced_motion else clampf(float(d.t) / 0.6, 0.0, 1.0)
		var xc := Color(1.0, 0.3, 0.3, a)
		var q: Vector2 = d.pos
		draw_line(q + Vector2(-4, -4), q + Vector2(4, 4), xc, 2.0)
		draw_line(q + Vector2(-4, 4), q + Vector2(4, -4), xc, 2.0)

	# structures — 2.5D neon blocks, painter-sorted so lower ones overlap upper ones.
	# Only gather + sort the on-screen ones (sorting every key each frame was pure overhead).
	var order := []
	for id in nodes:
		var r := Rect2(Vector2(nodes[id].cell) * TILE, Vector2(nodes[id].size, nodes[id].size) * TILE)
		var keep := view_b.intersects(r)
		# B52: keep the selected node whenever its vision/coverage ring crosses the view, even
		# if its footprint is off screen — so the ring stays visible.
		if not keep and id == selected_id:
			var sctr := _center_world(id)
			var vr: float = (float(VISION.get("relay", 11)) if nodes[id].get("relay", false) else float(VISION.get(nodes[id].type, 6))) * TILE
			var rr: float = maxf(vr, COVERAGE_RADIUS * TILE)
			if view.intersects(Rect2(sctr - Vector2(rr, rr), Vector2(rr, rr) * 2.0)):
				keep = true
		if keep:
			order.append(id)
	order.sort_custom(func(a, b): return (nodes[a].cell.y + nodes[a].size) < (nodes[b].cell.y + nodes[b].size))
	for id in order:
		_draw_building(id, font)

	# build preview
	if current_tool != "":
		var cell := _mouse_cell()
		if cell.x >= 0 and cell.y >= 0 and cell.x < MAP_W and cell.y < MAP_H:
			if SIZE.has(current_tool):
				var sz := int(SIZE[current_tool])
				var org := cell - Vector2i(sz / 2, sz / 2)
				var ok := _placement_error(current_tool, org, sz) == ""
				# B42: semantic palette colours (colour-blind safe) plus a redundant ✓/✗ symbol,
				# so placement validity never relies on red-vs-green alone.
				var gc: Color = Settings.health_color("ok" if ok else "bad")
				gc.a = 0.45
				var prect := Rect2(org.x * TILE + 2.0, org.y * TILE + 2.0, sz * TILE - 4.0, sz * TILE - 4.0)
				draw_rect(prect, gc, true)
				draw_rect(prect, Color(gc.r, gc.g, gc.b, 0.95), false, 2.0)
				draw_string(font, prect.get_center() + Vector2(-8, 8), "✓" if ok else "✗", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(22.0 * Settings.text_scale)), Color(gc.r, gc.g, gc.b, 1.0))
			elif current_tool == "relay":
				var gc := Color(0.8, 0.8, 0.9, 0.4)
				draw_rect(Rect2(cell.x * TILE, cell.y * TILE, TILE, TILE), gc, true)
			elif pending_child != -1:
				var route := _cached_preview(cell)
				var rpts: PackedVector2Array = route.pts
				if rpts.size() >= 2:
					var ok: bool = (not route.blocked) and float(route.len) <= _tool_maxlen(current_tool)
					var pcol: Color = Color(1, 1, 1, 0.5) if ok else Settings.health_color("bad")
					draw_polyline(rpts, pcol, 2.0)


func _h2(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h)


# The night city: every district rendered in its own neon style so you can read
# what you're hacking. Deterministic from the seed, culled to the view.
func _draw_city_overlay(font: Font) -> void:
	var vp: Vector2 = get_viewport_rect().size / camera.zoom.x
	var tl: Vector2 = camera.position - vp * 0.5
	var br: Vector2 = camera.position + vp * 0.5
	var cx0 := clampi(int(floor(tl.x / TILE)) - 1, 0, MAP_W)
	var cy0 := clampi(int(floor(tl.y / TILE)) - 1, 0, MAP_H)
	var cx1 := clampi(int(ceil(br.x / TILE)) + 1, 0, MAP_W)
	var cy1 := clampi(int(ceil(br.y / TILE)) + 1, 0, MAP_H)
	var P := 4
	# district labels at each region's centroid
	if camera.zoom.x < 1.8:
		for r in regions:
			var wc := Vector2(float(r.cx) * COARSE * TILE, float(r.cy) * COARSE * TILE)
			if wc.x < tl.x or wc.x > br.x or wc.y < tl.y or wc.y > br.y:
				continue
			var zc: Color = ZONE_COLOR.get(r.type, Color.GRAY)
			var label: String = str(ZONE_NAMES.get(r.type, r.type))
			if ZONE_RES.has(r.type):
				label += " · " + str(ZONE_RES[r.type])
			if int(r.ice) > 0:
				label += "  ICE %d" % int(r.ice)
			draw_string(font, wc - Vector2(label.length() * 4.0, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(16.0 * Settings.text_scale)), Color(zc.r, zc.g, zc.b, 0.9))
	# data motes drifting along the avenues — ambient city traffic
	var mote := Color(0.45, 0.9, 1.0, 0.5)
	var span_y := float((cy1 - cy0) * TILE)
	var span_x := float((cx1 - cx0) * TILE)
	if span_y > 1.0 and not Settings.reduced_motion:
		for x in range(cx0 - cx0 % 10, cx1 + 1, 10):
			for m in 3:
				var yy := fmod(_time * (26.0 + float(m) * 13.0) + float(x * 37 + m * 211), span_y)
				draw_circle(Vector2(float(x) * TILE, float(cy0) * TILE + yy), 1.3, mote)
	if span_x > 1.0 and not Settings.reduced_motion:
		for y in range(cy0 - cy0 % 10, cy1 + 1, 10):
			for m in 3:
				var xx := fmod(_time * (26.0 + float(m) * 13.0) + float(y * 53 + m * 197), span_x)
				draw_circle(Vector2(float(cx0) * TILE + xx, float(y) * TILE), 1.3, mote)
	# push the city backdrop back so your structures pop (a little always, more in HC)
	draw_rect(Rect2(tl, br - tl), Color(0.0, 0.0, 0.0, 0.45 if Settings.high_contrast else 0.16), true)
	# fog of war: darken the city outside your structures' vision.
	# Visible-block set is cached (rebuilt only when vision changes), so this is a hash lookup.
	_vision_list()
	var fog := Color(0.02, 0.03, 0.05, 0.68)
	for by in range(cy0 / P, cy1 / P + 1):
		for bx in range(cx0 / P, cx1 / P + 1):
			if not _vis_blocks.has(by * 1000 + bx):
				draw_rect(Rect2(float(bx * P) * TILE, float(by * P) * TILE, float(P) * TILE, float(P) * TILE), fog, true)


# A structure as a cyberspace hologram: pulsing ground glow, wireframe prism with
# a translucent top face and a sweeping scanline, and a vector glyph for its kind.
func _draw_building(id: int, font: Font) -> void:
	var o: Vector2i = nodes[id].cell
	var s: int = nodes[id].size
	var type: String = nodes[id].type
	var is_relay: bool = nodes[id].get("relay", false)
	var on: bool = nodes[id].get("on", true)
	var col: Color = COLORS["relay"] if is_relay else _sem_color(type)   # B43: palette-consistent marker
	if not on:
		col = Color(0.5, 0.52, 0.58)
	var base := Rect2(o.x * TILE + 2.0, o.y * TILE + 2.0, s * TILE - 4.0, s * TILE - 4.0)
	var ctr := _center_world(id)
	var detail: bool = camera.zoom.x > 0.8   # LOD: skip the costly dressing when zoomed out
	# dark knockout: carve a dark moat under the footprint so the neon prism pops out of
	# the bright city behind it (figure-ground separation, critical for low vision)
	draw_rect(base.grow(6.0), Color(0.03, 0.04, 0.07, 0.6), true)
	# coverage circle around EVERY structure (its vision/reach) — brighter when selected.
	# LOD: only the selected node shows rings when zoomed out; drawing a ring around every
	# structure every frame was a major cost, so gate the whole block behind zoom/selection.
	var sel: bool = id == selected_id
	if sel or camera.zoom.x > 0.55:
		var vis_r: float = (float(VISION.get("relay", 11)) if is_relay else float(VISION.get(type, 6))) * TILE
		var vc := col
		vc.a = 0.28 if sel else 0.09
		draw_arc(ctr, vis_r, 0, TAU, 26, vc, 2.0 if sel else 1.0)
		# every producer sweeps nearby city buildings — the coverage area (more buildings = more output).
		# Just the outline, no filled disc (a full-radius draw_circle fill is very expensive).
		if _is_producer(type) and not is_relay:
			var rc := col
			rc.a = 0.35 if sel else 0.13
			draw_arc(ctr, COVERAGE_RADIUS * TILE, 0, TAU, 22, rc, 1.0)
	# far-zoom LOD: the 2.5D prism is invisible at this scale, so draw a flat neon tile +
	# glyph. Keeps the two cues that read at a glance — resource colour and C2-link status —
	# while cutting ~15 primitives per structure down to ~3 (big win on the full-map view).
	if camera.zoom.x < 0.55 and not sel and id != pending_child:
		draw_rect(base, Color(col.r, col.g, col.b, 0.85 if on else 0.4), true)
		var linked: bool = id == hub_id or _connected.has(id)
		var kl := col if linked else Color(1.0, 0.35, 0.35, 1.0)
		draw_rect(base, Color(kl.r, kl.g, kl.b, 0.9), false, 1.5)
		Glyphs.draw(self, Glyphs.kind_for(type, id, is_relay), base.get_center(), Color(1, 1, 1, 0.9), 5.0)
		return
	if detail:
		# "infected" ground: a pulsing creep patch with tendrils reaching onto the city
		var inf := 0.6 if Settings.reduced_motion else (0.5 + 0.5 * sin(_time * 2.4 + float(id)))
		var rad := base.size.x * 0.55
		draw_circle(ctr, rad + 10.0, Color(col.r, col.g, col.b, (0.05 + 0.05 * inf) if on else 0.03))
		for k in 6:
			var ca := float(k) / 6.0 * TAU + (0.0 if Settings.reduced_motion else _time * 0.15)
			draw_circle(ctr + Vector2.from_angle(ca) * rad * 0.7, 4.0 + 2.0 * inf, Color(col.r, col.g, col.b, 0.06 if on else 0.03))
		if on:
			for k in 7:
				var ta := float(k) / 7.0 * TAU + float(id) * 0.4
				var wob := 0.0 if Settings.reduced_motion else (0.25 * sin(_time + float(k)))
				var p0 := ctr + Vector2.from_angle(ta) * (base.size.x * 0.4)
				var p1 := ctr + Vector2.from_angle(ta + wob) * (rad + 9.0 + 5.0 * inf)
				var mwob := 0.0 if Settings.reduced_motion else (3.0 * sin(_time * 2.0 + float(k)))
				var mid := (p0 + p1) * 0.5 + Vector2.from_angle(ta + 1.57) * mwob
				draw_polyline(PackedVector2Array([p0, mid, p1]), Color(col.r, col.g, col.b, 0.28 + 0.18 * inf), 1.2)
				draw_circle(p1, 1.4, Color(col.r, col.g, col.b, 0.5 + 0.3 * inf))
	var pr: Dictionary = STRUCT.get("relay" if is_relay else type, {"h": 14, "tiers": 1, "roof": "flat", "win": 1})
	var pulse := 0.3
	if on:
		pulse = 0.8 if Settings.reduced_motion else (0.75 + 0.25 * sin(_time * 2.0 + float(id) * 1.7))
	# ground glow (bigger for taller towers)
	var glow := col
	glow.a = 0.10 * pulse
	draw_rect(base.grow(6.0 + float(pr.h) * 0.12), glow, true)
	glow.a = 0.05
	draw_rect(base.grow(14.0 + float(pr.h) * 0.12), glow, true)
	# stacked setback tiers → a real tower silhouette
	var tiers := int(pr.tiers)
	var htot := float(pr.h)
	var tier_h := htot / float(tiers)
	var rect := base
	var z0 := 0.0
	var top_rect := base
	var top_z := htot
	for t in tiers:
		var z1 := z0 + tier_h
		_prism(rect, z0, z1, col, pulse, on, (int(pr.win) if detail else 0), id * 11 + t * 7)
		top_rect = rect
		top_z = z1
		var sh := rect.size * 0.17
		rect = Rect2(rect.position + sh, rect.size - sh * 2.0)
		z0 = z1
	_roof(str(pr.roof), top_rect, top_z, col, id, on)
	# identifying glyph + tag floating over the roof
	var vtop := Rect2(top_rect.position + Vector2(top_z * 0.35, -top_z), top_rect.size)
	Glyphs.draw(self, Glyphs.kind_for(type, id, is_relay), vtop.get_center(), Color(col.r, col.g, col.b, 0.95), 6.5)
	var tag: String = DEFS["relay"].short if is_relay else DEFS[type].short
	draw_string(font, vtop.position + Vector2(2, -4), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(9.0 * Settings.text_scale)), Color(1, 1, 1, 0.8))
	# status overlays
	var rate: float = float(nodes[id].get("cap_rate", 1.0))
	if on and _is_producer(type) and not is_relay and rate < 0.999:
		draw_string(font, _elev(base.position, 0.0) + Vector2(2, -2), "%d%%" % int(rate * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.8, 0.3))
	if float(nodes[id].get("boost_t", 0.0)) > 0.0:  # Overclock active
		var bp := 1.0 if Settings.reduced_motion else (0.5 + 0.5 * sin(_time * 10.0))
		draw_arc(vtop.get_center(), 16.0, 0, TAU, 20, Color(1.0, 0.85, 0.2, bp), 2.0)
		draw_string(font, vtop.end + Vector2(2, 0), "2×", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.2))
	if not on:
		draw_string(font, base.get_center() + Vector2(-14, 4), "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.5, 0.5))
	if on and (id == hub_id or _connected.has(id)):
		draw_rect(base.grow(2.0), Color(col.r, col.g, col.b, 0.85), false, 2.0)  # keyline: crisp edge over the city
	if id != hub_id and not _connected.has(id):
		draw_rect(base.grow(2.0), Color(1, 0.35, 0.35, 0.9), false, 2.0)  # not linked to C2
	if id == selected_id:
		var sp := 1.0 if Settings.reduced_motion else (0.6 + 0.4 * sin(_time * 6.0))
		draw_rect(base.grow(3.0), Color(1, 1, 1, sp), false, 2.5)
		draw_rect(vtop.grow(3.0), Color(0.2, 1.0, 0.9, sp * 0.7), false, 2.0)
	if id == pending_child:
		draw_rect(base.grow(4.0), Color(0.2, 1.0, 0.9, 0.95), false, 2.0)


# Iso-elevate a ground point by height z (the map's 2.5D projection).
func _elev(p: Vector2, z: float) -> Vector2:
	return p + Vector2(z * 0.35, -z)


func _bilerp(a: Vector2, b: Vector2, c: Vector2, d: Vector2, u: float, v: float) -> Vector2:
	return a.lerp(b, u).lerp(d.lerp(c, u), v)


# One tier of a tower: shaded front/right/top faces, neon edges, lit windows.
func _prism(R: Rect2, z0: float, z1: float, col: Color, pulse: float, on: bool, win: int, seed: int) -> void:
	var tl := R.position
	var tr := Vector2(R.end.x, R.position.y)
	var br := R.end
	var bl := Vector2(R.position.x, R.end.y)
	var front := PackedVector2Array([_elev(bl, z0), _elev(br, z0), _elev(br, z1), _elev(bl, z1)])
	var right := PackedVector2Array([_elev(br, z0), _elev(tr, z0), _elev(tr, z1), _elev(br, z1)])
	var topq := PackedVector2Array([_elev(tl, z1), _elev(tr, z1), _elev(br, z1), _elev(bl, z1)])
	draw_colored_polygon(front, Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.97))
	draw_colored_polygon(right, Color(col.r * 0.36, col.g * 0.36, col.b * 0.36, 0.97))
	draw_colored_polygon(topq, Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 0.97))
	var e := col
	e.a = (0.5 + 0.35 * pulse) if on else 0.4
	var ew := 2.4 if Settings.high_contrast else 1.3
	draw_polyline(PackedVector2Array([front[0], front[1], front[2], front[3], front[0]]), e, ew)
	draw_polyline(PackedVector2Array([right[1], right[2], right[3]]), e, ew)
	draw_polyline(PackedVector2Array([topq[0], topq[1], topq[2], topq[3], topq[0]]), e, ew)
	if on and win > 0:
		var ncol := clampi(int(R.size.x / 6.0), 2, 5)
		var nrow := win + 1
		for ri in nrow:
			for ci in ncol:
				var u := (float(ci) + 0.5) / float(ncol)
				var v := (float(ri) + 0.5) / float(nrow)
				var tw := 0.4 if Settings.reduced_motion else (0.08 + 0.5 * absf(sin(_time * 1.6 + float(seed + ri * 13 + ci * 5))))
				draw_rect(Rect2(_bilerp(front[0], front[1], front[2], front[3], u, v) - Vector2(1, 1), Vector2(2, 2)), Color(col.r, col.g, col.b, tw), true)
				var tw2 := 0.4 if Settings.reduced_motion else (0.08 + 0.5 * absf(sin(_time * 1.6 + float(seed + ri * 7 + ci * 11 + 99))))
				draw_rect(Rect2(_bilerp(right[0], right[1], right[2], right[3], u, v) - Vector2(1, 1), Vector2(2, 2)), Color(col.r, col.g, col.b, tw2), true)


# Distinct rooftop per structure type.
func _roof(kind: String, R: Rect2, z: float, col: Color, id: int, on: bool) -> void:
	var c := _elev(R.get_center(), z)
	var w := R.size.x
	var e := col
	e.a = 0.85 if on else 0.4
	match kind:
		"spire":  # C2 command spire: mast + rotating ring + light columns
			draw_line(c, c + Vector2(0, -24), e, 2.0)
			draw_arc(c + Vector2(0, -24), 9.0, 0, TAU, 22, e, 1.5)
			for i in 3:
				var a := (float(i) * TAU / 3.0) if Settings.reduced_motion else (_time * 1.2 + float(i) * TAU / 3.0)
				draw_line(c + Vector2(0, -24), c + Vector2(0, -24) + Vector2.from_angle(a) * 9.0, e, 1.5)
			draw_circle(c + Vector2(0, -24), 2.0, Color(0.6, 1.0, 1.0, 0.9))
		"dome":  # research/IoT: a glass dome
			draw_arc(c, w * 0.42, PI, TAU, 18, e, 1.6)
			draw_arc(c, w * 0.42, PI, TAU, 18, Color(col.r, col.g, col.b, 0.15), 6.0)
		"mast":  # broadcast/relay: tall antenna + blinking tip
			var tip := c + Vector2(0, -16.0 - float(id % 6))
			draw_line(c, tip, e, 1.4)
			draw_line(c + Vector2(-3, -6), c + Vector2(3, -6), e, 1.0)
			draw_circle(tip, 1.6, Color(1.0, 0.3, 0.3, 0.8 if Settings.reduced_motion else 0.3 + 0.7 * absf(sin(_time * 2.5 + float(id)))))
		"vents":  # server farm: rooftop units
			for i in 3:
				draw_rect(Rect2(c + Vector2(-9.0 + float(i) * 7.0, -5), Vector2(5, 5)), e, false, 1.0)
		"crown":  # bank: a stepped crown
			draw_line(c + Vector2(-w * 0.4, 0), c + Vector2(-w * 0.4, -6), e, 1.4)
			draw_line(c + Vector2(w * 0.4, 0), c + Vector2(w * 0.4, -6), e, 1.4)
			draw_line(c + Vector2(-w * 0.4, -6), c + Vector2(w * 0.4, -6), e, 1.4)
			draw_line(c + Vector2(0, -6), c + Vector2(0, -12), e, 1.6)
		"chimney":  # forge: a stack with furnace glow
			draw_rect(Rect2(c + Vector2(2, -14), Vector2(5, 14)), e, false, 1.2)
			draw_circle(c + Vector2(4.5, -14), 2.2, Color(1.0, 0.55, 0.2, 0.6 if Settings.reduced_motion else 0.4 + 0.4 * absf(sin(_time * 3.0 + float(id)))))
		"tank":  # mixer: a cylindrical tank
			draw_arc(c + Vector2(0, -10), w * 0.3, 0, TAU, 18, e, 1.4)
			draw_line(c + Vector2(-w * 0.3, 0), c + Vector2(-w * 0.3, -10), e, 1.2)
			draw_line(c + Vector2(w * 0.3, 0), c + Vector2(w * 0.3, -10), e, 1.2)
		"awning":  # market: a slanted stall roof
			draw_line(c + Vector2(-w * 0.45, -2), c + Vector2(w * 0.45, -8), e, 1.6)
		"billboard":  # media: a glowing sign
			draw_rect(Rect2(c + Vector2(-w * 0.42, -11), Vector2(w * 0.84, 7)), Color(col.r, col.g, col.b, 0.45 if Settings.reduced_motion else 0.35 + 0.25 * sin(_time * 4.0 + float(id))), true)
			draw_line(c, c + Vector2(0, -4), e, 1.0)
		_:  # office/flat: a slim rooftop antenna
			draw_line(c, c + Vector2(0, -9), e, 1.2)
			draw_circle(c + Vector2(0, -9), 1.3, Color(col.r, col.g, col.b, 0.8))


# A background city building — lightweight: ONE shaded prism (no tier-stacking or
# per-window twinkle) so hundreds of them stay cheap. A faint roof hint for tall ones.
func _bg_building(ci: CanvasItem, base: Rect2, lvl: int, pal: Color, roof: String, _seed: int, close: bool) -> void:
	var h := float(lvl) * 4.5
	var dimf := 0.6 if Settings.high_contrast else 1.0
	var tl := base.position
	var tr := Vector2(base.end.x, base.position.y)
	var br := base.end
	var bl := Vector2(base.position.x, base.end.y)
	var tlz := _elev(tl, h)
	var trz := _elev(tr, h)
	var brz := _elev(br, h)
	var blz := _elev(bl, h)
	ci.draw_colored_polygon(PackedVector2Array([bl, br, brz, blz]), Color(pal.r * 0.08 * dimf, pal.g * 0.08 * dimf, pal.b * 0.08 * dimf, 0.95))
	ci.draw_colored_polygon(PackedVector2Array([br, tr, trz, brz]), Color(pal.r * 0.14 * dimf, pal.g * 0.14 * dimf, pal.b * 0.14 * dimf, 0.95))
	var topq := PackedVector2Array([tlz, trz, brz, blz])
	ci.draw_colored_polygon(topq, Color(pal.r * 0.22 * dimf, pal.g * 0.22 * dimf, pal.b * 0.22 * dimf, 0.95))
	ci.draw_polyline(PackedVector2Array([tlz, trz, brz, blz, tlz]), Color(pal.r, pal.g, pal.b, 0.14 * dimf), 1.0)
	# a cheap roof hint only for tall buildings when zoomed in
	if close and lvl >= 5:
		var c := _elev(base.get_center(), h)
		match roof:
			"spire", "mast":
				ci.draw_line(c, c + Vector2(0, -8), Color(pal.r, pal.g, pal.b, 0.4), 1.0)
			"dome":
				ci.draw_arc(c, base.size.x * 0.28, PI, TAU, 8, Color(pal.r, pal.g, pal.b, 0.3), 1.0)
			_:
				pass


# Paint the static city backdrop (grid + background buildings + district edges) into
# the given canvas item. Whole map, no camera cull: drawn once and retained by Godot.
func _paint_city(ci: CanvasItem) -> void:
	for x in range(0, MAP_W + 1):
		ci.draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, MAP_H * TILE), Color(0.35, 0.55, 0.9, 0.09) if x % 10 == 0 else Color(0.3, 0.5, 0.8, 0.028))
	for y in range(0, MAP_H + 1):
		ci.draw_line(Vector2(0, y * TILE), Vector2(MAP_W * TILE, y * TILE), Color(0.35, 0.55, 0.9, 0.09) if y % 10 == 0 else Color(0.3, 0.5, 0.8, 0.028))
	var P := 4
	for by in range(0, MAP_H / P + 1):
		for bx in range(0, MAP_W / P + 1):
			var tx := bx * P + 1
			var ty := by * P + 1
			if tx >= MAP_W or ty >= MAP_H:
				continue
			var d := _block_desc(bx, by)   # B10: one authoritative geometry for render + collision
			if not d.rendered:
				continue
			var dtype: String = d.dtype
			var h := _h2(bx, by)
			var pal: Color = _zone_sem_color(dtype)   # B43: palette-consistent ground tint
			var hr: Array = DIST_H.get(dtype, [1, 2])
			var lvl: int = int(hr[0]) + (h / 7) % (int(hr[1]) - int(hr[0]) + 1)
			var bw := (3.0 * TILE - 3.0)
			var bh := (TILE if d.narrow else 3.0 * TILE - 3.0)
			var base := Rect2(float(bx * P) * TILE + 1.5, float(by * P) * TILE + 1.5, bw, bh)
			ci.draw_rect(base.grow(2.0 + float(lvl) * 1.2), Color(pal.r, pal.g, pal.b, 0.008 + 0.007 * float(lvl)), true)
			_bg_building(ci, base, lvl, pal, str(DIST_STYLE.get(dtype, "flat")), h, true)
	for gy in range(0, GH):
		for gx in range(0, GW):
			var ri := region_grid[gy * GW + gx]
			var x1 := float((gx + 1) * COARSE) * TILE
			var y1 := float((gy + 1) * COARSE) * TILE
			if gx + 1 < GW and region_grid[gy * GW + gx + 1] != ri:
				ci.draw_line(Vector2(x1, gy * COARSE * TILE), Vector2(x1, y1), Color(0.5, 0.9, 1.0, 0.22), 1.5)
			if gy + 1 < GH and region_grid[(gy + 1) * GW + gx] != ri:
				ci.draw_line(Vector2(gx * COARSE * TILE, y1), Vector2(x1, y1), Color(0.5, 0.9, 1.0, 0.22), 1.5)


# ---------- Names ----------
# Display name of a placed structure (a patched package reads as a Tor Relay).
func _node_name(id: int) -> String:
	if not nodes.has(id):
		return "?"
	if nodes[id].get("relay", false):
		return DEFS["relay"].name
	return DEFS[nodes[id].type].name


func _tool_name(code: String) -> String:
	if DEFS.has(code):
		return DEFS[code].name
	if TUNNEL_DEFS.has(code):
		return TUNNEL_DEFS[code].name
	return code.capitalize()


func _tool_homage(code: String) -> String:
	if DEFS.has(code):
		return DEFS[code].homage
	if TUNNEL_DEFS.has(code):
		return TUNNEL_DEFS[code].homage
	return ""


# ---------- Game flow: pause, dismantle, save / load, menu ----------
func set_paused(p: bool) -> void:
	paused = p
	message = "Paused." if p else "Resumed."


func remove_selected() -> void:
	if selected_tunnel != -1 and nodes.has(selected_tunnel) and nodes[selected_tunnel].parent != -1:
		_remove_tunnel(selected_tunnel)
		selected_tunnel = -1
		return
	if selected_id != -1 and selected_id != hub_id and nodes.has(selected_id):
		_remove_node(selected_id)
		selected_id = -1


func _remove_tunnel(child_id: int) -> void:
	_push_undo({"t": "restore_tunnel", "child": child_id, "parent": nodes[child_id].parent,
		"tunnel": nodes[child_id].tunnel, "path": nodes[child_id].path.duplicate(), "lane": nodes[child_id].get("lane", 0)})
	nodes[child_id].parent = -1
	nodes[child_id].tunnel = ""
	nodes[child_id].path = []
	_pl_cache.clear()
	message = "Tunnel dismantled."


func _push_undo(rec: Dictionary) -> void:
	_undo.append(rec)
	if _undo.size() > 20:
		_undo.pop_front()


func _refund(cost: Dictionary) -> void:
	for k in cost:
		resources[k] = resources.get(k, 0.0) + float(cost[k])


func undo_last() -> void:
	if _undo.is_empty():
		message = "Nothing to undo."
		return
	var a = _undo.pop_back()
	match a.t:
		"place":
			if nodes.has(a.id):
				nodes.erase(a.id)
				_refund(a.cost)
			if selected_id == a.id:
				selected_id = -1
			if pending_child == a.id:   # B11: don't leave a tunnel armed from an erased source
				pending_child = -1
				_hint_route = {}
				_hint_cell = Vector2i(-99999, -99999)
			_pl_cache.clear()
		"tunnel":
			if nodes.has(a.child):
				nodes[a.child].parent = -1
				nodes[a.child].tunnel = ""
				nodes[a.child].path = []
				_refund(a.cost)
				if selected_tunnel == a.child:   # B12: the inspected edge no longer exists
					selected_tunnel = -1
				_pl_cache.clear()
		"relay":
			if nodes.has(a.id):
				nodes[a.id].relay = false
				_refund(a.cost)
		"dismantle":
			var n = a.node
			nodes[int(n.id)] = n
			for c in a.detached:
				if nodes.has(c.cid):
					nodes[c.cid].parent = c.parent
					nodes[c.cid].tunnel = c.tunnel
					nodes[c.cid].path = c.path
					nodes[c.cid].lane = c.lane
			_pl_cache.clear()
		"restore_tunnel":
			if nodes.has(a.child):
				nodes[a.child].parent = a.parent
				nodes[a.child].tunnel = a.tunnel
				nodes[a.child].path = a.path
				nodes[a.child].lane = a.lane
				_pl_cache.clear()
	message = "Undid last action."


func toggle_selected() -> void:
	if selected_id == -1 or selected_id == hub_id or not nodes.has(selected_id):
		return
	nodes[selected_id].on = not nodes[selected_id].get("on", true)
	message = "%s %s." % [_node_name(selected_id), "enabled" if nodes[selected_id].on else "disabled"]


func adjust_rate_selected(d: float) -> void:
	if selected_id == -1 or not nodes.has(selected_id) or not _is_producer(nodes[selected_id].type):
		return
	if nodes[selected_id].get("relay", false):
		return
	var r: float = clampf(float(nodes[selected_id].get("cap_rate", 1.0)) + d, 0.0, 1.0)
	nodes[selected_id].cap_rate = r
	message = "%s output limit: %d%%." % [_node_name(selected_id), int(r * 100.0)]


# ---------- C2 commands (pushed along the links) ----------
func overclock_selected() -> void:
	if selected_id == -1 or not nodes.has(selected_id) or not _is_producer(nodes[selected_id].type) or nodes[selected_id].get("relay", false):
		message = "Select a producing structure first, then Overclock it."
		return
	if resources.compute < OVERCLOCK_COST:
		message = "Overclock needs %d Cycles." % int(OVERCLOCK_COST)
		return
	resources.compute -= OVERCLOCK_COST
	nodes[selected_id].boost_t = OVERCLOCK_T
	message = "%s overclocked — 2× output for %ds." % [_node_name(selected_id), int(OVERCLOCK_T)]


func scrub_trace() -> void:
	if resources.compute < SCRUB_COST.compute or resources.tools < SCRUB_COST.tools:
		message = "DDoS Smokescreen needs %d Cycles + %d Tools." % [int(SCRUB_COST.compute), int(SCRUB_COST.tools)]
		return
	resources.compute -= SCRUB_COST.compute
	resources.tools -= SCRUB_COST.tools
	trace = 0.0
	if not sweep.is_empty():
		sweep = {}
		message = "DDoS Smokescreen — Trace wiped and the ICE sweep scattered."
	_sweep_charge = 0.0
	message = "DDoS smokescreen launched — Trace scrubbed to 0."


func go_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func quit_game() -> void:
	get_tree().quit()


func _serialize() -> Dictionary:
	var data := {
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"seed": seed, "next_id": next_id, "hub_id": hub_id,
		"resources": resources, "won": won, "time": _time, "trace": trace, "researched": researched.keys(),
		"camera": [camera.position.x, camera.position.y, camera.zoom.x],
		"nodes": {}, "packets": [],
		# threat subsystem (B17)
		"notoriety": notoriety, "sweep": sweep.duplicate(true),
		"sweep_charge": _sweep_charge, "blackout_t": _blackout_t,
		# contract board + generation state (B19)
		"contracts": [], "next_contract_id": _next_contract_id, "contract_cd": _contract_cd,
		# cumulative run statistics + captured victory result (B20)
		"_run_time": _run_time, "_packets_delivered": _packets_delivered,
		"_max_trace": _max_trace, "_peak_cash_rate": _peak_cash_rate,
		"hist_cash": _hist_cash.duplicate(), "victory_card": (_scorecard() if won else ""),
		# simulation RNG, as a string to keep full 64-bit precision (B23)
		"rng_state": str(rng.state),
	}
	for id in nodes:
		var n = nodes[id]
		var path := []
		for c in n.get("path", []):
			path.append([c.x, c.y])
		data.nodes[str(id)] = {
			"id": id, "type": n.type, "cell": [n.cell.x, n.cell.y], "size": n.size,
			"parent": n.parent, "tunnel": n.tunnel, "relay": n.get("relay", false),
			"path": path, "acc": n.get("acc", 0.0),
			"on": n.get("on", true), "cap_rate": n.get("cap_rate", 1.0), "lane": n.get("lane", 0),
			"boost_t": n.get("boost_t", 0.0), "quarantine": n.get("quarantine", 0.0),  # B18, B17
		}
	for p in packets:
		data.packets.append({"res": p.res, "route": p.route, "idx": p.idx, "dir": p.dir,
			"dist": p.dist, "value": p.get("value", 1.0)})  # B16
	for c in contracts:
		data.contracts.append(c.duplicate(true))
	return data


# Durable, atomic save with a verified last-good backup (B22, T95). Writes a temp file,
# confirms it parses, rotates the previous valid save to the backup, then swaps the new file
# in. An interrupted or failed write therefore never destroys the last usable save.
func save_game() -> bool:
	var text := JSON.stringify(_serialize())
	var tmp := Session.SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		message = "Save failed (%s)." % error_string(FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.flush()
	var werr := f.get_error()
	f.close()
	if werr != OK:
		DirAccess.remove_absolute(tmp)
		message = "Save failed (write error)."
		return false
	# verify the temp file is readable and parses before trusting it
	var check := FileAccess.get_file_as_string(tmp)
	if check == "" or typeof(_json_or_null(check)) != TYPE_DICTIONARY:
		DirAccess.remove_absolute(tmp)
		message = "Save failed (verification)."
		return false
	# rotate: keep the previous valid save as the backup, then put the new file in place
	if FileAccess.file_exists(Session.SAVE_PATH):
		var prev := FileAccess.get_file_as_string(Session.SAVE_PATH)
		if typeof(_json_or_null(prev)) == TYPE_DICTIONARY:
			if FileAccess.file_exists(Session.BACKUP_PATH):
				DirAccess.remove_absolute(Session.BACKUP_PATH)
			DirAccess.copy_absolute(Session.SAVE_PATH, Session.BACKUP_PATH)
		DirAccess.remove_absolute(Session.SAVE_PATH)
	if DirAccess.rename_absolute(tmp, Session.SAVE_PATH) != OK:
		message = "Save failed (replace)."
		return false
	message = "Game saved."
	return true


# In-session Load restores ONLY the current save; a corrupt file is refused with the live run
# left untouched (B21). Fresh Continue passes allow_backup = true so it can recover from the
# verified last-good backup and explain the recovery (T95).
func load_game(allow_backup := false) -> bool:
	var parsed = _read_valid_save(Session.SAVE_PATH)
	var from_backup := false
	if parsed == null and allow_backup:
		parsed = _read_valid_save(Session.BACKUP_PATH)
		from_backup = parsed != null
	if parsed == null:
		if FileAccess.file_exists(Session.SAVE_PATH) or FileAccess.file_exists(Session.BACKUP_PATH):
			message = "Save file unreadable — the live run was left unchanged."
		else:
			message = "No saved game."
		return false
	_apply_save(parsed)
	message = "Recovered from the last-good backup." if from_backup else "Game loaded."
	return true


# Read + validate a save file into a Dictionary, or null if missing/corrupt/invalid (B21).
func _read_valid_save(path: String):
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return null
	var parsed = _json_or_null(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	if _validate_save(parsed) != "":
		return null
	return parsed


# Parse JSON without the engine-log error that JSON.parse_string prints on bad input —
# a corrupt save is an expected, handled runtime condition here, not a code fault.
func _json_or_null(text: String):
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


# Validate a parsed save has a usable schema BEFORE any live state is touched (B21).
func _validate_save(p: Dictionary) -> String:
	if not p.has("version"):
		return "no version"
	if typeof(p.get("resources")) != TYPE_DICTIONARY:
		return "no resources"
	var sn = p.get("nodes")
	if typeof(sn) != TYPE_DICTIONARY or sn.is_empty():
		return "no nodes"
	var hub := int(p.get("hub_id", -1))
	var hub_ok := false
	for k in sn:
		var n = sn[k]
		if typeof(n) != TYPE_DICTIONARY:
			return "bad node"
		if not (n.has("id") and n.has("type") and n.has("cell") and n.has("size") and n.has("parent")):
			return "node missing fields"
		if not (SIZE.has(str(n.type)) or str(n.type) == "hub"):
			return "unknown node type"
		if typeof(n.get("cell")) != TYPE_ARRAY or n.cell.size() < 2:
			return "bad cell"
		if int(n.id) == hub and str(n.type) == "hub":
			hub_ok = true
	if not hub_ok:
		return "no hub"
	for pk in p.get("packets", []):
		if typeof(pk) != TYPE_DICTIONARY:
			return "bad packet"
		if typeof(pk.get("route")) != TYPE_ARRAY or pk.route.is_empty():
			return "bad packet route"
		var idx := int(pk.get("idx", -1))
		if idx < 0 or idx >= pk.route.size():
			return "bad packet idx"
	return ""


# Replace the live run with a validated save, as one transaction. Restores the full
# simulation state and clears the discarded timeline's undo history and transient
# interaction state (B16-B24).
func _apply_save(parsed: Dictionary) -> void:
	seed = int(parsed.get("seed", 0))
	rng.seed = seed
	_generate_city()  # the city is deterministic from the seed
	nodes.clear()
	var saved_nodes: Dictionary = parsed.get("nodes", {})
	for k in saved_nodes:
		var n = saved_nodes[k]
		var path := []
		for c in n.get("path", []):
			path.append(Vector2i(int(c[0]), int(c[1])))
		var id := int(n.id)
		nodes[id] = {
			"id": id, "type": str(n.type), "cell": Vector2i(int(n.cell[0]), int(n.cell[1])), "size": int(n.size),
			"parent": int(n.parent), "tunnel": str(n.tunnel), "relay": bool(n.get("relay", false)),
			"path": path, "acc": float(n.get("acc", 0.0)),
			"on": bool(n.get("on", true)), "cap_rate": float(n.get("cap_rate", 1.0)), "lane": int(n.get("lane", 0)),
			"boost_t": float(n.get("boost_t", 0.0)), "quarantine": float(n.get("quarantine", 0.0)),
		}
	next_id = int(parsed.get("next_id", 1))
	hub_id = int(parsed.get("hub_id", 1))
	var r = parsed.get("resources", {})
	resources = {"compute": float(r.get("compute", 0.0)), "data": float(r.get("data", 0.0)), "credits": float(r.get("credits", 0.0)), "crypto": float(r.get("crypto", 0.0)), "tools": float(r.get("tools", 0.0)), "research": float(r.get("research", 0.0))}
	trace = float(parsed.get("trace", 0.0))
	researched = {}
	for t in parsed.get("researched", []):
		researched[str(t)] = true
	won = bool(parsed.get("won", false))
	_time = float(parsed.get("time", 0.0))
	packets.clear()
	for p in parsed.get("packets", []):
		var route := []
		for e in p.route:
			route.append(int(e))
		packets.append({"res": str(p.res), "route": route, "idx": int(p.idx), "dir": int(p.dir),
			"dist": float(p.dist), "value": float(p.get("value", 1.0))})  # B16
	# threat subsystem (B17)
	notoriety = float(parsed.get("notoriety", 0.0))
	_sweep_charge = float(parsed.get("sweep_charge", 0.0))
	_blackout_t = float(parsed.get("blackout_t", 0.0))
	sweep = _restore_sweep(parsed.get("sweep", {}))
	# contract board (B19)
	contracts = []
	for c in parsed.get("contracts", []):
		if typeof(c) == TYPE_DICTIONARY:
			var cc: Dictionary = c.duplicate(true)
			cc["id"] = int(cc.get("id", 0))
			contracts.append(cc)
	_next_contract_id = int(parsed.get("next_contract_id", 1))
	_contract_cd = float(parsed.get("contract_cd", 10.0))
	_contracts_ver += 1  # force the Jobs panel to rebuild against the restored board
	# cumulative run statistics (B20)
	_run_time = float(parsed.get("_run_time", 0.0))
	_packets_delivered = int(parsed.get("_packets_delivered", 0))
	_max_trace = float(parsed.get("_max_trace", 0.0))
	_peak_cash_rate = float(parsed.get("_peak_cash_rate", 0.0))
	_hist_cash = []
	for v in parsed.get("hist_cash", []):
		_hist_cash.append(float(v))
	# simulation RNG (B23) — restore AFTER city generation, which consumes the stream
	if parsed.has("rng_state"):
		rng.state = int(str(parsed.rng_state))
	# transient interaction state belongs to the discarded timeline — reset as one unit (B24)
	_undo.clear()
	_edge.clear()
	_connected.clear()
	_drops.clear()
	_deliver_flash.clear()
	_pl_cache.clear()
	_vis_sig.clear()
	selected_id = -1
	selected_tunnel = -1
	pending_child = -1
	current_tool = ""
	_panning = false
	_accum = 0.0
	rates = {}
	_rate_prev = {}
	_rate_t = 0.0
	_emergency_active = false
	_hint_cell = Vector2i(-99999, -99999)
	_hint_pending = -1
	_hint_tool = ""
	_hint_route = {}
	var cam = parsed.get("camera", null)
	if cam is Array and cam.size() >= 3:
		camera.position = Vector2(float(cam[0]), float(cam[1]))
		camera.zoom = Vector2(float(cam[2]), float(cam[2]))
	elif nodes.has(hub_id):
		camera.position = _center_world(hub_id)
	paused = false


# Restore a saved sweep dict, coercing node-id arrays back to ints (JSON stores them as floats).
func _restore_sweep(s) -> Dictionary:
	if typeof(s) != TYPE_DICTIONARY or s.is_empty():
		return {}
	var out: Dictionary = s.duplicate(true)
	for key in ["path", "route"]:
		if out.has(key) and typeof(out[key]) == TYPE_ARRAY:
			var arr := []
			for v in out[key]:
				arr.append(int(v))
			out[key] = arr
	if out.has("step"):
		out["step"] = int(out["step"])
	return out
