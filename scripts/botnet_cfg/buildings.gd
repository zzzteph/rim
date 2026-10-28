## What you build INSIDE a host — the producers and the Firewall.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

const BUILD_TIME := 10.0           # seconds of fully funded work a build job needs (also in tuning.gd)
const DEMOLISH_TIME := 5.0         # seconds to clear an occupied slot first (replace = DEMOLISH_TIME + BUILD_TIME)

# Every host runs one production cycle each PROD_CYCLE (5 s): Intel harvesters first, then the Firewall's upkeep,
# then the converters (Miner, Credential harvester, Research lab) from what is in THAT host's storage (at the main
# node: the bank), then the Bot stations, whose new Bots leave at once carrying what the host made.
# "rate" is output per cycle at x1, "use" the input per cycle; host type multipliers scale both.
const BUILD_KINDS := {
	"intel": {"name": "Intel harvester",      "card": "Intel harv.",  "short": "I", "col": Color(0.4, 0.85, 1.0),
		"out": "intel", "rate": 2.0, "use": {}, "cost": {"intel": 12.0}, "cap": 50.0,
		"desc": "Makes 2 Intel every 5 s. The Miner, Credential harvester and Lab on this host use it first."},
	"bot":   {"name": "Bot station",          "card": "Bot station",  "short": "B", "col": Color(0.45, 0.95, 0.6),
		"out": "bots", "rate": 2.0, "use": {}, "cost": {"intel": 12.0, "cash": 4.0}, "cap": 50.0,
		"desc": "Every 5 s sends 2 new Bots home, each carrying 1 unit from this host. They join your Bots."},
	"cash":  {"name": "Crypto miner",         "card": "Miner",        "short": "C", "col": Color(1.0, 0.85, 0.3),
		"out": "cash", "rate": 1.0, "use": {"intel": 1.0}, "cost": {"intel": 15.0}, "cap": 50.0,
		"desc": "Every 5 s turns 1 Intel on this host into 1 Crypto."},
	"cred":  {"name": "Credential harvester", "card": "Cred. harv.",  "short": "K", "col": Color(1.0, 0.6, 0.45),
		"out": "creds", "rate": 1.0, "use": {"intel": 1.0}, "cost": {"intel": 15.0, "cash": 4.0}, "cap": 50.0,
		"desc": "Every 5 s turns 1 Intel on this host into 1 Credential."},
	"lab":   {"name": "Research lab",         "card": "Research lab", "short": "R", "col": Color(0.75, 0.55, 1.0),
		"out": "research", "rate": 1.0, "use": {"intel": 1.0, "cash": 1.0}, "cost": {"intel": 20.0, "cash": 8.0}, "cap": 50.0,
		"desc": "Every 5 s turns 1 Intel and 1 Crypto on this host into 1 Research."},
	"wall":  {"name": "Firewall",             "card": "Firewall",     "short": "F", "col": Color(0.9, 0.5, 0.5),
		"out": "", "rate": 0.0, "use": {"intel": 1.0}, "cost": {"intel": 25.0, "cash": 15.0}, "cap": 0.0,
		"desc": "3 sockets for defence cards, which fire on their own when this host is hit. Uses 1 Intel every 5 s."},
}
const PRODUCER_KINDS := ["intel", "bot", "cash", "cred", "lab"]   # the five that make a resource
const CONVERT_ORDER := ["cash", "cred", "lab"]                    # converters run in this order (a Lab can use the Miner's Crypto)
const BUILD_COSTS := {
	"intel": {"intel": 12.0},
	"bot":   {"intel": 12.0, "cash": 4.0},
	"cash":  {"intel": 15.0},
	"cred":  {"intel": 15.0, "cash": 4.0},
	"lab":   {"intel": 20.0, "cash": 8.0},
	"wall":  {"intel": 25.0, "cash": 15.0},
}
const BUILD_COST_INTEL := 20.0     # legacy alias
