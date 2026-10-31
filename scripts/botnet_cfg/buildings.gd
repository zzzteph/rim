## What you build INSIDE a host — the producers and the Firewall.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

const BUILD_TIME := 10.0           # seconds of fully funded work a build job needs (also in tuning.gd)
const DEMOLISH_TIME := 5.0         # seconds to clear an occupied slot first (replace = DEMOLISH_TIME + BUILD_TIME)

# Every host runs one production cycle each PROD_CYCLE (12 s): every producer makes 1 unit of its own resource (0.6.12:
# the Miner, Credential harvester and Research lab need no input), then the Firewall's upkeep comes out of the host's
# storage (at the main node: the bank). Each Bot station adds two reusable workers to the one pool working from the
# main node (they die with the station's host).
# "rate" is output per cycle at x1, "use" the input per cycle; host type multipliers scale both.
const BUILD_KINDS := {
	"intel": {"name": "Intel harvester",      "card": "Intel harv.",  "short": "I", "col": Color(0.4, 0.85, 1.0),
		"out": "intel", "rate": 1.0, "use": {}, "cost": {"intel": 12.0}, "cap": 50.0,
		"desc": "Makes 1 Intel every 12 s."},
	"bot":   {"name": "Bot station",          "card": "Bot station",  "short": "B", "col": Color(0.45, 0.95, 0.6),
		"out": "", "rate": 0.0, "use": {}, "cost": {"intel": 4.0, "cash": 12.0}, "cap": 0.0,
		"desc": "Provides 2 reusable delivery workers. Each carries 1 resource unit per trip leg."},
	"cash":  {"name": "Crypto miner",         "card": "Miner",        "short": "C", "col": Color(1.0, 0.85, 0.3),
		"out": "cash", "rate": 1.0, "use": {}, "cost": {"intel": 15.0}, "cap": 50.0,
		"desc": "Makes 1 Crypto every 12 s."},
	"cred":  {"name": "Credential harvester", "card": "Cred. harv.",  "short": "K", "col": Color(1.0, 0.6, 0.45),
		"out": "creds", "rate": 1.0, "use": {}, "cost": {"intel": 15.0, "cash": 4.0}, "cap": 50.0,
		"desc": "Makes 1 Credential every 12 s."},
	"lab":   {"name": "Research lab",         "card": "Research lab", "short": "R", "col": Color(0.75, 0.55, 1.0),
		"out": "research", "rate": 1.0, "use": {}, "cost": {"intel": 12.0, "cash": 16.0}, "cap": 50.0,
		"desc": "Makes 1 Research every 12 s."},
	"wall":  {"name": "Firewall",             "card": "Firewall",     "short": "F", "col": Color(0.9, 0.5, 0.5),
		"out": "", "rate": 0.0, "use": {"intel": 1.0}, "cost": {"intel": 10.0, "cash": 30.0}, "cap": 0.0,
		"desc": "3 sockets for defence cards, which fire on their own when this host is hit. Uses 1 Intel every 12 s."},
}
const PRODUCER_KINDS := ["intel", "cash", "cred", "lab"]   # the four that make a material (a Bot station houses workers)
const CONVERT_ORDER := ["cash", "cred", "lab"]                    # converters run in this order (a Lab can use the Miner's Crypto)
const BUILD_COSTS := {
	"intel": {"intel": 12.0},
	"bot":   {"intel": 4.0, "cash": 12.0},   # (0.6.12: infrastructure is paid mainly in Crypto, the same totals)
	"cash":  {"intel": 15.0},
	"cred":  {"intel": 15.0, "cash": 4.0},
	"lab":   {"intel": 12.0, "cash": 16.0},
	"wall":  {"intel": 10.0, "cash": 30.0},
}
const BUILD_COST_INTEL := 20.0     # legacy alias
