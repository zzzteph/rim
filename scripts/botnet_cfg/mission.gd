## "Recover the Corporate Records" — a network objective mission, entirely game state (fictional).
## A target computer carries an authored objective (records_total). A faction may either capture a delivery route
## the ordinary way, or spend resources to switch on a TEMPORARY ACCESS status on the target (no ownership change).
## While access is live and a route home exists, the target emits objective packets toward that faction's home
## (rig); each delivered packet is progress and raises the target's ALERT, which lets the owner interrupt the route.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases.

const RECORD_INTERVAL := 2.0       # seconds between objective packets while access is live and a route home exists
const RECORD_HOME_STEP := 1.0      # progress per packet delivered to home
const ACCESS_SECS := 45.0          # how long one purchase of temporary access lasts
# Access cost is target-specific so a big generic Credentials bank is not a universal key: a flat part plus a part
# that scales with the target's records and its type security. Paid once per purchase, from the buyer's banks.
const ACCESS_BASE := {"intel": 20.0, "creds": 15.0}
const ACCESS_PER_RECORD := {"intel": 0.5, "creds": 0.5}
const ACCESS_PER_SEC := 0.5        # extra Credentials per point of the target type's security rating

const ALERT_PER_RECORD := 8.0      # alert points added each time a record is delivered home
const ALERT_MAX := 100.0
const ALERT_DECAY := 1.5           # alert points shed per second while no record is being delivered
const ALERT_RESPOND := 60.0        # at or above this the target's owner (AI) interrupts the route
const RESPOND_COOLDOWN := 18.0     # seconds between an AI owner's route interruptions
const RESPOND_CUT_SECS := 8.0      # how long the owner's interruption cuts an intermediate node (reuses route_off)

const SELL_CRYPTO := 120.0         # "sell the records": Crypto paid to the faction that completed delivery
const RELAY_ACCESS_SECS := 90.0    # "publish": seconds of temporary use of the community relay (timed ownership)
