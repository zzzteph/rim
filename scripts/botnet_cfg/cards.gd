## The card catalogue for the research-manufacture-launch redesign (RIM).
## 15 recipes: 10 ATTACK/information, 5 DEFENCE/support. A recipe is learned once (a blueprint), then
## manufactured into single-use copies. scripts/botnet_proto.gd reads these through aliases and never
## redefines them. A changed value needs the scene restarted (constants are read when the script loads).

# Each recipe:
#   name/short    display name and a compact label
#   fam           art + colour family (assets/cards/schematic/<fam>.png)
#   bank          "attack" (foreign target) or "defense" (your own host)
#   effect        the rule the simulation applies (see botnet_proto.gd _op_* / _apply_support)
#   known         true: available from match start · false: behind the research tree
#   make          {bots,intel,cash,creds,research} paid once when a copy STARTS manufacturing; make_time seconds
#   sec_max       capture ceiling (capture cards only)
#   exec          execution seconds after travel (capture/raid/worm-stage)
#   dur           timed-effect seconds (theft/disruption/support)
#   reach         how many hosts a chain covers (worm/sabotage)
#   needs_link    the first target must have one of your connections into it
const CARDS := {
	"recon":     {"name": "Recon",                  "short": "Recon",   "fam": "recon",    "bank": "attack",  "effect": "recon",   "known": true,
		"make": {"bots": 1, "intel": 3, "cash": 0, "creds": 0, "research": 0}, "make_time": 2.0, "dur": 30.0,
		"lead": "Reveal a host's contents for 30 s.", "rules": "Shows its installations, local cargo and mission access. The snapshot goes stale after 30 s. Not an alarm, and not needed to capture."},
	"breach":    {"name": "Credential breach",      "short": "Breach",  "fam": "breach",   "bank": "attack",  "effect": "capture", "known": true,  "sec_max": 1, "exec": 8.0,
		"make": {"bots": 3, "intel": 4, "cash": 3, "creds": 3, "research": 0}, "make_time": 6.0,
		"lead": "Capture one security-1 host.", "rules": "Travels from your main node, then executes for 8 s. Patch, more security, a lost route or a new owner stops it."},
	"exploit":   {"name": "Known exploit",          "short": "Exploit", "fam": "exploit",  "bank": "attack",  "effect": "capture", "known": false, "sec_max": 2, "exec": 8.0,
		"make": {"bots": 4, "intel": 6, "cash": 6, "creds": 4, "research": 4}, "make_time": 10.0,
		"lead": "Capture one host up to security 2.", "rules": "Travels, then executes for 8 s. Breach is cheaper against a security-1 host."},
	"phish":     {"name": "Phishing",               "short": "Phish",   "fam": "phish",    "bank": "attack",  "effect": "phish",   "known": true,  "dur": 24.0,
		"make": {"bots": 3, "intel": 5, "cash": 5, "creds": 6, "research": 2}, "make_time": 10.0,
		"lead": "Divert new output for 24 s.", "rules": "A rival host's new producer output goes to you. They keep the host and still pay its inputs. Each stolen non-Bot unit needs your courier home."},
	"siphon":    {"name": "Packet siphon",          "short": "Siphon",  "fam": "siphon",   "bank": "attack",  "effect": "siphon",  "known": false, "dur": 18.0, "cargo": 6,
		"make": {"bots": 4, "intel": 4, "cash": 4, "creds": 2, "research": 2}, "make_time": 8.0,
		"lead": "Steal up to 6 cargo units in 18 s.", "rules": "Pick a resource. Its couriers leaving a foreign host bring it to your main node instead. The original courier carries on. Courier cover protects cargo."},
	"vault":     {"name": "Vault raid",             "short": "Vault",   "fam": "vault",    "bank": "attack",  "effect": "vault",   "known": false, "exec": 8.0, "cargo": 8,
		"make": {"bots": 5, "intel": 6, "cash": 3, "creds": 6, "research": 4}, "make_time": 14.0,
		"lead": "Steal up to 8 stored Crypto.", "rules": "Raids a rival's main node for 8 s. Takes what their stock, your couriers and your room allow. The loot travels home as real shipments. Patch or a lost route stops it."},
	"ddos":      {"name": "DDoS",                   "short": "DDoS",    "fam": "dos",      "bank": "attack",  "effect": "ddos",    "known": false, "dur": 18.0,
		"make": {"bots": 10, "intel": 8, "cash": 6, "creds": 0, "research": 2}, "make_time": 12.0,
		"lead": "Halt a host's output for 18 s.", "rules": "Stops its producers, main-node income and outgoing dispatch. Incoming cargo still arrives. Traffic filter clears it."},
	"zeroday":   {"name": "0day",                   "short": "0day",    "fam": "zeroday",  "bank": "attack",  "effect": "capture", "known": false, "sec_max": 3, "exec": 8.0, "exec_rig": 12.0,
		"make": {"bots": 6, "intel": 10, "cash": 15, "creds": 9, "research": 15}, "make_time": 20.0,
		"lead": "Capture one host up to security 3.", "rules": "Travels, then executes for 8 s. On an active rival main node it executes for 12 s, with a countdown they can see. Patch or a lost route stops it."},
	"worm":      {"name": "Worm",                   "short": "Worm",    "fam": "worm",     "bank": "attack",  "effect": "worm",    "known": false, "sec_max": 1, "exec": 4.0, "reach": 3,
		"make": {"bots": 9, "intel": 12, "cash": 12, "creds": 12, "research": 8}, "make_time": 18.0,
		"lead": "Capture up to 3 linked hosts.", "rules": "Takes adjacent visible security-1 hosts of one owner. Only the first needs a route; each capture opens the next. Each takes 4 s; Patch or a change stops the chain."},
	"sabotage":  {"name": "Supply-chain sabotage",  "short": "Sabotage","fam": "supply",   "bank": "attack",  "effect": "sabotage","known": false, "dur": 20.0, "reach": 3,
		"make": {"bots": 8, "intel": 10, "cash": 12, "creds": 10, "research": 12}, "make_time": 18.0,
		"lead": "Shut producers on 3 hosts for 20 s.", "rules": "Hits the target and up to 2 adjacent hosts of its owner. Routing and dispatch keep working. Incident response clears it."},
	"patch":     {"name": "Patch",                  "short": "Patch",   "fam": "patch",    "bank": "defense", "effect": "patch",   "known": true,  "dur": 20.0,
		"make": {"bots": 2, "intel": 4, "cash": 4, "creds": 0, "research": 3}, "make_time": 6.0,
		"lead": "Stop a capture or a raid.", "rules": "Cancels the earliest hostile capture or Vault raid here. With none running, it arms one interception for 20 s. Then it recovers for 20 s; it does not stack."},
	"response":  {"name": "Incident response",      "short": "Response","fam": "response", "bank": "defense", "effect": "response", "known": true,
		"make": {"bots": 2, "intel": 4, "cash": 3, "creds": 3, "research": 1}, "make_time": 4.0,
		"lead": "Clear theft and sabotage here.", "rules": "Removes Phishing, Packet siphon and Supply-chain sabotage. Stolen output not yet shipped comes back to you. It does not clear DDoS or undo shipped theft."},
	"filter":    {"name": "Traffic filter",         "short": "Filter",  "fam": "filter",   "bank": "defense", "effect": "filter",  "known": false, "dur": 12.0,
		"make": {"bots": 5, "intel": 5, "cash": 4, "creds": 0, "research": 1}, "make_time": 6.0,
		"lead": "Clear DDoS and block it for 12 s.", "rules": "Works before an attack too. It does not boost production or stop capture."},
	"cover":     {"name": "Courier cover",          "short": "Cover",   "fam": "cover",    "bank": "defense", "effect": "cover",   "known": false, "dur": 16.0,
		"make": {"bots": 2, "intel": 4, "cash": 4, "creds": 0, "research": 2}, "make_time": 6.0,
		"lead": "Shield new cargo for 16 s.", "rules": "Cargo this host sends is safe from Packet siphon all the way. It does not stop Phishing or Vault raid."},
	"express":   {"name": "Express route",          "short": "Express", "fam": "express",  "bank": "defense", "effect": "express", "known": false, "dur": 16.0,
		"make": {"bots": 2, "intel": 5, "cash": 4, "creds": 0, "research": 2}, "make_time": 8.0,
		"lead": "Halve delivery time for 16 s.", "rules": "Shipments and new Bots from this host cross each link twice as fast. It does not save couriers or raise street capacity."},
}

# The research tree: a locked recipe, its prerequisite blueprint, one-time cost and time.
const RESEARCH := {
	"exploit":  {"prereq": "breach",  "intel": 8,  "cash": 8,  "research": 12, "time": 20.0},
	"zeroday":  {"prereq": "exploit", "intel": 16, "cash": 18, "research": 30, "time": 40.0},
	"worm":     {"prereq": "exploit", "intel": 12, "cash": 12, "research": 20, "time": 30.0},
	"ddos":     {"prereq": "recon",   "intel": 8,  "cash": 8,  "research": 10, "time": 18.0},
	"sabotage": {"prereq": "ddos",    "intel": 14, "cash": 16, "research": 24, "time": 35.0},
	"siphon":   {"prereq": "phish",   "intel": 8,  "cash": 8,  "research": 12, "time": 20.0},
	"vault":    {"prereq": "siphon",  "intel": 12, "cash": 14, "research": 22, "time": 30.0},
	"filter":   {"prereq": "patch",   "intel": 6,  "cash": 6,  "research": 8,  "time": 12.0},
	"cover":    {"prereq": "patch",   "intel": 6,  "cash": 6,  "research": 8,  "time": 12.0},
	"express":  {"prereq": "recon",   "intel": 8,  "cash": 6,  "research": 12, "time": 18.0},
}

const ATTACK_ORDER := ["recon", "breach", "exploit", "phish", "siphon", "vault", "ddos", "zeroday", "worm", "sabotage"]
const DEFENSE_ORDER := ["patch", "response", "filter", "cover", "express"]
const CARD_ORDER := ["recon", "breach", "exploit", "phish", "siphon", "vault", "ddos", "zeroday", "worm", "sabotage", "patch", "response", "filter", "cover", "express"]
const KNOWN_START := ["recon", "breach", "phish", "patch", "response"]
const MANUFACTURE_LANES := 3
const READY_SLOTS := 12            # active manufacturing jobs + ready copies, across all lanes

# the two deck tabs: red ATTACK, blue DEFENCE (internal key stays "defense")
const BANK_NAME := {"attack": "ATTACK", "defense": "DEFENCE"}
const BANK_COL := {"attack": Color(1.0, 0.36, 0.33), "defense": Color(0.36, 0.6, 1.0)}
const FAMILY_NAME := {"recon": "recon", "breach": "credential breach", "exploit": "known exploits", "phish": "phishing", "siphon": "packet siphon", "vault": "vault raids", "dos": "denial of service", "zeroday": "0day exploits", "worm": "worms", "supply": "supply-chain sabotage", "patch": "patches", "response": "incident response", "filter": "traffic filters", "cover": "courier cover", "express": "express routes"}
# Schematic art: reuse the existing eight silhouettes, mapping the new families onto the nearest picture.
const FAMILY_ART := {
	"recon": preload("res://assets/cards/schematic/sca.png"),
	"breach": preload("res://assets/cards/schematic/zeroday.png"),
	"exploit": preload("res://assets/cards/schematic/zeroday.png"),
	"phish": preload("res://assets/cards/schematic/phishing.png"),
	"siphon": preload("res://assets/cards/schematic/phishing.png"),
	"vault": preload("res://assets/cards/schematic/supply.png"),
	"dos": preload("res://assets/cards/schematic/dos.png"),
	"zeroday": preload("res://assets/cards/schematic/zeroday.png"),
	"worm": preload("res://assets/cards/schematic/supply.png"),
	"supply": preload("res://assets/cards/schematic/supply.png"),
	"patch": preload("res://assets/cards/schematic/patch.png"),
	"response": preload("res://assets/cards/schematic/response.png"),
	"filter": preload("res://assets/cards/schematic/cdn.png"),
	"cover": preload("res://assets/cards/schematic/cdn.png"),
	"express": preload("res://assets/cards/schematic/cdn.png"),
}
const FAMILY_COL := {
	"recon": Color(0.5, 0.85, 1.0), "breach": Color(1.0, 0.55, 0.4), "exploit": Color(1.0, 0.5, 0.3),
	"phish": Color(0.3, 0.9, 1.0), "siphon": Color(0.4, 0.8, 0.9), "vault": Color(1.0, 0.38, 0.75),
	"dos": Color(0.68, 0.55, 1.0), "zeroday": Color(1.0, 0.45, 0.2), "worm": Color(0.9, 0.4, 0.6),
	"supply": Color(1.0, 0.38, 0.75), "patch": Color(0.35, 0.95, 0.85), "response": Color(0.55, 0.62, 1.0),
	"filter": Color(0.3, 0.75, 1.0), "cover": Color(0.4, 0.7, 1.0), "express": Color(0.45, 0.9, 0.8),
}
const CARD_ALARM := 8.0
