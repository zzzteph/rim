## What you build INSIDE a host — the producers (and the Firewall) for the RIM redesign.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

const BUILD_TIME := 10.0           # seconds of fully funded work a build job needs (also in tuning.gd)
const DEMOLISH_TIME := 5.0         # seconds to clear an occupied slot first (replace = DEMOLISH_TIME + BUILD_TIME)

# Each producer: its output resource and per-second rate at ×1, its input resource and rate, the build price
# (paid over BUILD_TIME), and the capacity it adds to its output bank. Type multipliers scale output AND input.
# Firewall is an installation, not a producer: one slot, +1 security (cap 3), no upkeep or storage.
const BUILD_KINDS := {
	"intel": {"name": "Intel harvester",      "card": "Intel harv.",  "short": "I", "col": Color(0.4, 0.85, 1.0),
		"out": "intel", "rate": 2.0, "in": "",     "in_rate": 0.0, "cost": {"intel": 20.0, "cash": 10.0}, "cap": 50.0,
		"desc": "2 Intel/s, no input. +50 Intel cap. Its output still needs a courier home."},
	"bot":   {"name": "Bot farm",             "card": "Bot farm",     "short": "B", "col": Color(0.45, 0.95, 0.6),
		"out": "bots", "rate": 2.0, "in": "intel", "in_rate": 1.0, "cost": {"intel": 15.0, "cash": 20.0}, "cap": 50.0,
		"desc": "Turns 1 Intel into 2 Bots/s. New Bots deliver themselves home. +50 Bot cap."},
	"cash":  {"name": "Crypto miner",         "card": "Miner",        "short": "C", "col": Color(1.0, 0.85, 0.3),
		"out": "cash", "rate": 1.0, "in": "intel", "in_rate": 1.0, "cost": {"intel": 25.0, "cash": 10.0}, "cap": 50.0,
		"desc": "Turns 1 Intel into 1 Crypto/s. A courier carries each unit home. +50 Crypto cap."},
	"cred":  {"name": "Credential harvester", "card": "Cred. harv.",  "short": "K", "col": Color(1.0, 0.6, 0.45),
		"out": "creds", "rate": 1.0, "in": "intel", "in_rate": 1.0, "cost": {"intel": 25.0, "cash": 15.0}, "cap": 50.0,
		"desc": "Turns 1 Intel into 1 Credential/s. +50 Credential cap."},
	"lab":   {"name": "Research lab",         "card": "Research lab", "short": "R", "col": Color(0.75, 0.55, 1.0),
		"out": "research", "rate": 1.0, "in": "cash", "in_rate": 1.0, "cost": {"intel": 25.0, "cash": 25.0}, "cap": 50.0,
		"desc": "Turns 1 Crypto into 1 Research/s. +50 Research cap."},
	"wall":  {"name": "Firewall",             "card": "Firewall",     "short": "F", "col": Color(0.9, 0.5, 0.5),
		"out": "", "rate": 0.0, "in": "", "in_rate": 0.0, "cost": {"intel": 20.0, "cash": 20.0}, "cap": 0.0,
		"desc": "+1 security (max 3). One per host. No upkeep or storage."},
}
const PRODUCER_KINDS := ["intel", "bot", "cash", "cred", "lab"]   # the five that make and ship a resource
const BUILD_COSTS := {
	"intel": {"intel": 20.0, "cash": 10.0},
	"bot":   {"intel": 15.0, "cash": 20.0},
	"cash":  {"intel": 25.0, "cash": 10.0},
	"cred":  {"intel": 25.0, "cash": 15.0},
	"lab":   {"intel": 25.0, "cash": 25.0},
	"wall":  {"intel": 20.0, "cash": 20.0},
}
const BUILD_COST_INTEL := 20.0     # legacy alias
