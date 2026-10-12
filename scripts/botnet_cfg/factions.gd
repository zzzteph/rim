## Factions and the AI personalities — who plays, and how the AI botnets think.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

const NEUTRAL := 0
const PLAYER := 1
const RIVAL := 2          # NYX
const RIVAL2 := 3         # KRAKEN
const FACTIONS := {
	0: {"name": "city security", "col": Color(0.35, 0.45, 0.6)},
	1: {"name": "yours",         "col": Color(0.25, 0.85, 0.45)},
	2: {"name": "NYX",           "col": Color(0.85, 0.3, 0.33)},
	3: {"name": "KRAKEN",        "col": Color(0.7, 0.4, 0.95)},
}
const BOTNETS := [1, 2, 3]
const AIS := [2, 3]
# AI personalities: aggr = taste for attacking other botnets and opening a second front; cadence = think rate
const AI_PROFILE := {2: {"aggr": 0.8, "cadence": 3.0}, 3: {"aggr": 0.45, "cadence": 3.5}}
const AI_MAX_STREAMS := 4          # sources an AI concentrates on one target
const AI_RESERVE := 6.0            # garrison an AI building keeps
const AI_PATIENCE := 30.0          # seconds WITHOUT PROGRESS before an AI gives up an attack
const AI_SPEED := 1.0              # multiplies every AI's think cadence (measured: it barely moves the clock — the AIs' clock is their Cash income)
const AI_CASH_MULT := 1.0          # multiplies the AI botnets' Cash income: measured idle clock 1.0 → ~5 min, 0.75 → ~5¾, 0.5 → ~7 (they expand to compensate)
# ── what an AI may assume about what it has not scanned (it plays under the player's fog) ──
const AI_PRIOR_BOTNET := 0.6       # an unscanned building of another botnet is assumed to hold this × NODE_CAP bots
const AI_SCOUT_INTEL := 20.0       # Intel it keeps before spending a quiet scan on learning alone
const AI_CHOKE_LEAD := 50.0        # Cash lead of a rival that makes an AI phish that rival's markets
const AI_EDGE_MEMORY := 60.0       # seconds it remembers where it was last hit (pre-wired guards go there)
const AI_SIEGE_MAX := 120.0        # the longest siege an AI starts, on what it knows (a slow steady siege still counts as progress)
