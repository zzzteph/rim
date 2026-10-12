## Numbers — bots, combat, resources and their limits, Cash, scanning, links, control stages.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

const NODE_CAP := 30.0             # bots limit per OWNED building
const PROD_RATE := 1.0             # bots/sec PER active Bot farm

# combat power — attack equals defence (A = D): an arriving attack bot removes exactly one defender
const ATTACK_POWER := 1.0
const DEFEND_POWER := 1.0
const INTEL_START := 50.0
const RIG_INTEL := 1.0             # Intel/s a botnet's own rig produces by itself, so there is always something to build with
const INTEL_CAP_BASE := 100.0
const INTEL_CAP_PER_BUILD := 50.0  # each Intel harvester also raises the Intel limit
const INTEL_PER_BUILD := 1.0
const CRED_PER_BUILD := 0.5        # Credentials/s per active Credential harvester (× the type's cred multiplier)
const RESEARCH_PER_BUILD := 0.5    # Research/s per active Research lab (× the type's research multiplier)
const RES_CAP_BASE := 50.0         # Credentials and Research limits start here …
const RES_CAP_PER_BUILD := 50.0    # … and each harvester / lab raises its own resource's limit by this
const CASH_INTERVAL := 3.0         # seconds between Cash packets per active Darknet market

# ── the win: two ways, no clock. (1) hold a true majority (> HOLD_FRACTION of ALL buildings) for HOLD_SECS
# without a break → win. (2) be the last botnet with buildings. The match runs until one of these happens.
const HOLD_FRACTION := 0.5         # a true-majority win needs more than half of ALL buildings (16 of 31)
const HOLD_SECS := 45.0            # seconds of continuous majority for the win

# ── the bot-flow dials ──
# ── scanning: a foreign building must be SCANNED before it can be attacked. A scan bot travels like an
# attack bot, costs the same, and is consumed on arrival without hurting a defender; the FIRST one to land
# reveals the target's bots and slots (no quota). A changed inside (built, demolished, replaced) needs a rescan.
const SCAN_BASE := 1.0
const SCAN_PER_BUILD := 0.0
const SCAN_COSTS_INTEL := true     # scan bots are attack bots: 1 Intel each
# Any ATTACK on an unscanned building reveals it as its bots land — but it raises the alarm (red frame,
# guards arm, the owner's AI reacts). The SCAN launch is the quiet route: nothing alerts the owner.

const SEND_RATE := 1.0             # bots/sec a live flow releases at rate dial 100%
const LINK_TIME := 1.0             # seconds to cross one link (hop)
const NODE_ROUTE_DELAY := 0.25     # pause (s) at each intermediate building
const LINK_CAP := 2                # packets a link DIRECTION admits per LINK_TIME (throughput 2/s)
const MAX_QUEUE := 1.0             # a source holds its packet if the first link can't admit it within this

# ── control stages: fewer bots → fewer working slots (first slot always works) ──
const STAGE_FULL := 2.0 / 3.0
const STAGE_SHAKY := 1.0 / 3.0
const STAGE_NAME := ["FULL", "SHAKY", "CRITICAL"]

