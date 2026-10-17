## What you build INSIDE a building — the five kinds and the build timings.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# ── the LOCAL layer: buildings inside a building (slots). Click a building you own and build straight into
# its slots; jobs run on their own, sharing Intel left after attack departures.
const BUILD_TIME := 10.0           # seconds of fully funded work a build job needs
const DEMOLISH_TIME := 5.0         # seconds to clear an occupied slot first (replace = DEMOLISH_TIME + BUILD_TIME)
# Each kind's price, paid evenly over BUILD_TIME of funded work. The full price must be in the bank to queue
# a job, but it is not reserved: a short resource slows the build instead. Keys are pools: "intel", "cash" (Crypto).
const BUILD_COSTS := {
	"intel": {"intel": 10.0},
	"bot":   {"cash": 30.0},       # Crypto: farms are an investment fed by miners (1 Intel per Crypto), not more Intel
	"cash":  {"intel": 50.0},
	"cred":  {"intel": 50.0},
	"lab":   {"intel": 50.0, "cash": 25.0},
}
const BUILD_COST_INTEL := 10.0     # the cheapest price (an Intel harvester); legacy alias for scripts and probes
const BUILD_KINDS := {
	"bot":   {"name": "Bot farm",             "card": "Bot farm",     "short": "B", "col": Color(0.45, 0.95, 0.6),  "desc": "+1 bot/s regeneration here. Costs Crypto, so mine first."},
	"intel": {"name": "Intel harvester",      "card": "Intel harv.",  "short": "I", "col": Color(0.4, 0.85, 1.0),   "desc": "+1 Intel/s and +15 Intel limit. Attacks spend 1 Intel per bot."},
	"cash":  {"name": "Crypto miner",         "card": "Miner",        "short": "C", "col": Color(1.0, 0.85, 0.3),   "desc": "1 Intel per Crypto mined. Funded packets travel home to your rig every 3 s. Click to pause/resume."},
	"cred":  {"name": "Credential harvester", "card": "Cred. harv.",  "short": "K", "col": Color(1.0, 0.6, 0.45),   "desc": "1 Intel per Credential. Base output 0.5/s, scaled by host type. +50 capacity. Click to pause/resume."},
	"lab":   {"name": "Research lab",         "card": "Research lab", "short": "R", "col": Color(0.75, 0.55, 1.0),  "desc": "1 Crypto per Research. Base output 0.5/s, scaled by host type. +50 capacity. Click to pause/resume."},
}
