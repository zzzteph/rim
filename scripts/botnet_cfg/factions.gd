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
