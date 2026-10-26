## Numbers — bots, combat, resources and their limits, Cash, scanning, links, control stages.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

const NODE_CAP := 30.0             # bots limit per OWNED building
const PROD_RATE := 1.0             # bots/sec PER active Bot farm
# ── PAID REPLENISHMENT (experiment; off until measured and kept). A working rig regenerates up to RIG_FREE_REGEN
# bots/s free (limited by its own farms); every other bot actually added below a garrison's limit costs
# REGEN_PRICE Crypto, paid from Crypto left after card preparation and construction, before labs convert any.
# Full garrisons cost nothing; short funding slows replenishment for all of a faction's computers alike.
const PAID_REGEN := false
const REGEN_PRICE := 0.25          # Crypto per replenished bot (provisional)
const RIG_FREE_REGEN := 2.0        # free bots/s at a working rig (its two starting farms)

# combat power — attack equals defence (A = D): an arriving attack bot removes exactly one defender
const ATTACK_POWER := 1.0
const DEFEND_POWER := 1.0
const INTEL_START := 50.0
const RIG_INTEL := 1.0             # Intel/s a botnet's own rig produces by itself, so there is always something to build with
const INTEL_CAP_BASE := 100.0
const INTEL_CAP_PER_BUILD := 15.0  # each Intel harvester also raises the Intel limit (a small bank: spend as you earn)
const INTEL_PER_BUILD := 1.0
const CRED_PER_BUILD := 0.5        # Credentials/s per active Credential harvester (× the type's cred multiplier)
const RESEARCH_PER_BUILD := 0.5    # Research/s per active Research lab (× the type's research multiplier)
const RES_CAP_BASE := 50.0         # Credentials and Research limits start here …
const RES_CAP_PER_BUILD := 50.0    # … and each harvester / lab raises its own resource's limit by this
const CASH_INTERVAL := 3.0         # seconds between Crypto packets per active Crypto miner

# ── the win: two ways, no clock. (1) hold AT LEAST HOLD_FRACTION of ALL buildings for HOLD_SECS without a
# break → win. (2) be the last botnet with its rig. Losing a rig eliminates any faction.
const HOLD_FRACTION := 0.51        # at least 51 % of ALL buildings (rounded up: 16 of 31, 19 of 37)
const HOLD_SECS := 51.0            # seconds of continuous hold for the win

# ── the bot-flow dials ──
# ── scanning: optional quiet scouting, separate from a blind attack. One pending scout per faction/target.
# A scan bot travels like an
# attack bot, costs the same, and is consumed on arrival without hurting a defender; the FIRST one to land
# reveals the target's bots and slots (no quota). A changed inside (built, demolished, replaced) needs a rescan.
const SCAN_BASE := 1.0
const SCAN_PER_BUILD := 0.0
const SCAN_COSTS_INTEL := true     # scan bots are attack bots: 1 Intel each
# Any ATTACK on an unscanned building reveals it as its bots land — but it raises the alarm (red frame,
# guards arm, the owner's AI reacts). The SCAN launch is the quiet route: nothing alerts the owner.

const SEND_RATE := 1.0             # bots/sec a live flow releases at rate dial 100%
# ── ASSAULT: a FINITE order (prototype). A source commits a share of the garrison it holds when the order is given;
# exactly that many bots leave, faster than a stream, then the order ends. Provisional values chosen with
# tools/balance/economy_handoff/assault_model.py: 4/s lets three sources out-burst one 8/s street (the approach
# matters) and sends a 75 % order from a 90-bot host in ~17 s — long enough to be answered.
const ASSAULT_RATE := 4.0          # bots/s per source while its assault has quota left (a stream sends SEND_RATE)
const ASSAULT_COMMITS := [25, 50, 75, 100, 125, 150]   # <=100: % of the source's sendable garrison an order commits;
                                                      # >100: OVERCHARGE — the whole garrison, each bot hits ×pct/100
const ASSAULT_DEFAULT := 75
const ASSAULT_PAUSES_REGEN := true # exposure: a source's own Bot farms rest while its assault order stands (blocked or not)
const ASSAULT_OVERCHARGE_INTEL := 2.0   # extra Intel per bot for every +100 % above 100 % (125 %: 1.5 Intel/bot, 150 %: 2 Intel/bot)
const LINK_TIME := 1.0             # seconds to cross one link (hop)
const NODE_ROUTE_DELAY := 0.25     # pause (s) at each intermediate building
const LINK_CAP := 8                # packets a link DIRECTION admits per LINK_TIME (throughput 8/s) — bots flow freely, little queuing
const MAX_QUEUE := 1.0             # a source holds its packet if the first link can't admit it within this

# ── control stages use the BASE 30-bot capacity, regardless of added storage.
# 20+ bots: stable; 10–19: shaky; below 10: critical. First slot always works.
const STAGE_FULL := 2.0 / 3.0
const STAGE_SHAKY := 1.0 / 3.0
const STAGE_NAME := ["STABLE", "SHAKY", "CRITICAL"]

