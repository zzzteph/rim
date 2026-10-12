## Numbers — bots, combat, resources and their limits, Cash, scanning, links, control stages, rally.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

const NODE_CAP := 30.0             # bots limit per OWNED building
const PROD_RATE := 1.0             # bots/sec PER active Bot farm

# combat power — a defender is worth 1.5× an attacker (D = 1.5·A); an arriving attack bot removes A/D
const ATTACK_POWER := 1.0
const DEFEND_POWER := 1.5
const INTEL_START := 50.0
const INTEL_CAP_BASE := 100.0
const INTEL_CAP_PER_BUILD := 50.0  # each Intel harvester also raises the Intel limit
const INTEL_PER_BUILD := 1.0
const CRED_PER_BUILD := 0.5        # Credentials/s per active Credential harvester (× the type's cred multiplier)
const RESEARCH_PER_BUILD := 0.5    # Research/s per active Research lab (× the type's research multiplier)
const RES_CAP_BASE := 50.0         # Credentials and Research limits start here …
const RES_CAP_PER_BUILD := 50.0    # … and each harvester / lab raises its own resource's limit by this
const CASH_INTERVAL := 3.0         # seconds between Cash packets per active Darknet market

# ── the win: three ways, in order. (1) hold a true majority (> HOLD_FRACTION of ALL buildings) for HOLD_SECS
# without a break → instant win. (2) be the last botnet with buildings. (3) at the MATCH_TIME bell, whoever
# controls the most buildings wins (ties: the most bots). So control always decides, and a snowball wins early.
const HOLD_FRACTION := 0.5         # a true-majority instant win needs more than half of ALL buildings (16 of 31)
const HOLD_SECS := 45.0            # seconds of continuous majority for the instant win
const MATCH_TIME := 300.0          # a 5-minute match; at the bell the biggest holder wins

# ── the bot-flow dials ──
# ── scanning: a foreign building must be SCANNED before it can be attacked. Scan bots travel like attack
# bots, cost the same, and are consumed on arrival without hurting a defender; they reveal the target's bots
# and slots once SCAN_BASE + SCAN_PER_BUILD × (buildings inside) of them have landed. The protection is a
# fixed threshold: not regenerated, not depleted. A changed inside (built, demolished, replaced) needs a rescan.
const SCAN_BASE := 10.0
const SCAN_PER_BUILD := 5.0
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

# ── rally (command-unit experiment) & the AI botnets ──
const RALLY_RESERVE := 10.0        # an auto-supplying building keeps this garrison at home
