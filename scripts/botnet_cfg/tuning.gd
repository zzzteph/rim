## Numbers for the RIM redesign — five banks, main-node income, couriers, routes, security, the win.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# ── the five resources. RES[k] is the order used by banks, hud and the state hash ──
const RES := ["bots", "intel", "cash", "creds", "research"]
const RES_NAME := {"bots": "Bots", "intel": "Intel", "cash": "Crypto", "creds": "Credentials", "research": "Research"}
const START := {"bots": 20.0, "intel": 30.0, "cash": 20.0, "creds": 12.0, "research": 8.0}
const BASE_CAP := {"bots": 200.0, "intel": 150.0, "cash": 300.0, "creds": 150.0, "research": 150.0}
const CAP_PER_PRODUCER := 50.0     # each installed producer adds this to its own output resource's cap

# ── the main node (rig). While operational it makes one of EACH resource per second, delivered locally. ──
const MAIN_INCOME := 1.0           # per resource per second, no type multiplier, one allowance per living faction

# ── couriers and delivery ──
const BUFFER_CAP := 20.0           # a remote producer's own local output buffer (per producer, per beneficiary)
const BOT_RESERVE_CHOICES := [0, 5, 10, 20, 40]
const BOT_RESERVE_DEFAULT := 10    # Bots kept available for operations; shipping and raid collection keep this
const SHIP_PRIORITY_TURNS := 2     # weighted round robin: the chosen resource gets this many turns, others one

# ── routes (unchanged baseline) ──
const LINK_TIME := 1.0             # seconds to cross one link (hop)
const NODE_ROUTE_DELAY := 0.25     # pause (s) at each intermediate forwarding step
const LINK_CAP := 8                # packets a link DIRECTION admits per LINK_TIME
const MAX_QUEUE := 1.0             # a source holds its packet if the first link can't admit it within this
const EXPRESS_MULT := 0.5          # Express route: half per-link travel and forwarding time

# ── security (a discrete eligibility threshold, not damageable health) ──
const SEC_BY_TYPE := {"iot": 1, "pc": 1, "server": 2, "web": 2, "file": 2, "db": 3, "erp": 3}
const SEC_MAIN := 3                # an active main node is always security 3, overriding its host type
const SEC_MAX := 3                 # the ceiling a Firewall can reach

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
