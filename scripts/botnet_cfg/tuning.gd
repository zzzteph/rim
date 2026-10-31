## Numbers for the RIM redesign — four materials, main-node income, delivery workers, routes, Recon odds, the win.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# ── the four materials. RES[k] is the order used by banks, hud and the state hash. Bots are not a material: they are
#    delivery workers, two per Bot station (WORKERS_PER_STATION), counted as a population, never banked or spent ──
const RES := ["intel", "cash", "creds", "research"]
const RES_NAME := {"intel": "Intel", "cash": "Crypto", "creds": "Credentials", "research": "Research"}
const START := {"intel": 40.0, "cash": 20.0, "creds": 15.0, "research": 10.0}   # a producer or two and a first Breach
const BASE_CAP := {"intel": 150.0, "cash": 300.0, "creds": 150.0, "research": 150.0}
const CAP_PER_PRODUCER := 50.0     # each installed producer adds this to its own output resource's cap

# ── production: every host runs one cycle each PROD_CYCLE seconds ──
const PROD_CYCLE := 5.0            # seconds per production cycle (all producers, the Firewall's upkeep, Bot stations)
const STORE_CAP := 10.0            # what a remote host can hold before its producers stop (all resources together)

# ── the main node (rig). While operational it makes one of EACH resource per cycle, delivered locally. ──
const MAIN_INCOME := 0.2           # per resource per second (one of each every 5 s): a trickle that keeps a stalled player alive; producers are the economy

# ── delivery workers ──
const WORKERS_PER_STATION := 2     # every operational Bot station has exactly this many reusable workers (any host type)
const WORKER_CARRY := 1.0          # one resource unit of one type per trip leg (a valid final fraction may be less)
const WORKER_REPLACE := 5.0        # a worker lost on the road is replaced at its surviving, operational station after this
const PRIORITY_TURNS := 3          # of every PRIORITY_TURNS + 1 new assignments in a pool, this many go by purpose
                                   # (production inputs, then construction, then collection); the next to the oldest request
const CARD_GIVE_UP := 20.0         # a card held this long on its way heads back to its main node; the copy returns to your hand

# ── routes (unchanged baseline) ──
const LINK_TIME := 1.0             # seconds to cross one link (hop)
const NODE_ROUTE_DELAY := 0.25     # pause (s) at each intermediate forwarding step
const LINK_CAP := 8                # packets a link DIRECTION admits per LINK_TIME
const MAX_QUEUE := 1.0             # a source holds its packet if the first link can't admit it within this
const EXPRESS_MULT := 0.5          # Express route: half per-link travel and forwarding time

# ── Recon and the odds of an attack (there are no security levels: every attack can target any foreign host) ──
const UNSCOUTED_CHANCE := 0.5      # an offensive card (not Recon) against a host you have no FRESH Recon of succeeds
                                   # this share of the time (0.5 x its baseline, which is always 1.0); one draw per
                                   # resolved operation from the match's deterministic RNG, after counters and routes

# ── the Firewall ──
const FIREWALL_SOCKETS := 3        # defence cards one Firewall holds; each fires itself on its trigger

# ── construction ──
const BUILD_TIME := 10.0           # seconds of fully funded work a build job needs
const DEMOLISH_TIME := 5.0         # seconds to clear an occupied slot first

# ── manufacture / research ──
const RESEARCH_SLOTS := 1          # one blueprint research at a time, at the main node

# ── the win: hold a majority, or be the last main node standing. No clock. ──
const HOLD_FRACTION := 0.51        # at least 51 % of ALL hosts (rounded up)
const HOLD_SECS := 51.0            # seconds of continuous hold for the win

# ── AI pacing ──
const AI_CADENCE := 2.5            # seconds between an AI faction's plan ticks
