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
		"lead": "Reveal installations and useful output.", "rules": "Reveal a foreign host's installations, local cargo and mission access. Snapshot goes stale after 30 s. Not an alarm; optional for capture."},
	"breach":    {"name": "Credential breach",      "short": "Breach",  "fam": "breach",   "bank": "attack",  "effect": "capture", "known": true,  "sec_max": 1, "exec": 8.0,
		"make": {"bots": 3, "intel": 4, "cash": 3, "creds": 3, "research": 0}, "make_time": 6.0,
		"lead": "Capture one security-1 host.", "rules": "After travel, execute 8 s and capture a host of security 1. Patch, more security, a lost route or changed owner can stop it."},
	"exploit":   {"name": "Known exploit",          "short": "Exploit", "fam": "exploit",  "bank": "attack",  "effect": "capture", "known": false, "sec_max": 2, "exec": 8.0,
		"make": {"bots": 4, "intel": 6, "cash": 6, "creds": 4, "research": 4}, "make_time": 10.0,
		"lead": "Capture one host up to security 2.", "rules": "Execute 8 s and capture a host up to security 2. The cheaper Breach often serves a soft host better."},
	"phish":     {"name": "Phishing",               "short": "Phish",   "fam": "phish",    "bank": "attack",  "effect": "phish",   "known": true,  "dur": 24.0,
		"make": {"bots": 3, "intel": 5, "cash": 5, "creds": 6, "research": 2}, "make_time": 10.0,
		"lead": "Divert new production for 24 seconds.", "rules": "Divert a rival host's new producer output for 24 s. They keep the host and pay inputs. Each stolen non-Bot unit needs an attacker courier home."},
	"siphon":    {"name": "Packet siphon",          "short": "Siphon",  "fam": "siphon",   "bank": "attack",  "effect": "siphon",  "known": false, "dur": 18.0, "cargo": 6,
		"make": {"bots": 4, "intel": 4, "cash": 4, "creds": 2, "research": 2}, "make_time": 8.0,
		"lead": "Redirect up to six cargo units for 18 seconds.", "rules": "Choose a resource; for 18 s redirect up to 6 of its courier packets at a foreign host to your main node. The original courier carries on. Courier cover protects cargo."},
	"vault":     {"name": "Vault raid",             "short": "Vault",   "fam": "vault",    "bank": "attack",  "effect": "vault",   "known": false, "exec": 8.0, "cargo": 8,
		"make": {"bots": 5, "intel": 6, "cash": 3, "creds": 6, "research": 4}, "make_time": 14.0,
		"lead": "Steal up to eight stored Crypto.", "rules": "Raid a rival's main node 8 s. At completion take up to 8 Crypto, limited by their stock and your haulers/room, returned as real shipments. Patch or a lost route stops it."},
	"ddos":      {"name": "DDoS",                   "short": "DDoS",    "fam": "dos",      "bank": "attack",  "effect": "ddos",    "known": false, "dur": 18.0,
		"make": {"bots": 10, "intel": 8, "cash": 6, "creds": 0, "research": 2}, "make_time": 12.0,
		"lead": "Stop production and outgoing traffic for 18 seconds.", "rules": "Disable a foreign host's producers, intrinsic income and outgoing dispatch for 18 s. Incoming still arrives. Traffic filter clears it."},
	"zeroday":   {"name": "0day",                   "short": "0day",    "fam": "zeroday",  "bank": "attack",  "effect": "capture", "known": false, "sec_max": 3, "exec": 8.0, "exec_rig": 12.0,
		"make": {"bots": 6, "intel": 10, "cash": 15, "creds": 9, "research": 15}, "make_time": 20.0,
		"lead": "Capture one host up to security 3.", "rules": "Execute 8 s (12 s on an active rival main node) and capture a host up to security 3. Deterministic; Patch and a prominent rig-threat countdown give counterplay."},
	"worm":      {"name": "Worm",                   "short": "Worm",    "fam": "worm",     "bank": "attack",  "effect": "worm",    "known": false, "sec_max": 1, "exec": 4.0, "reach": 3,
		"make": {"bots": 9, "intel": 12, "cash": 12, "creds": 12, "research": 8}, "make_time": 18.0,
		"lead": "Capture up to three linked security-1 hosts.", "rules": "Chain up to 3 adjacent visible security-1 hosts of one owner. Only the first needs a route; each capture opens the next. 4 s each; Patch or a change stops the chain."},
	"sabotage":  {"name": "Supply-chain sabotage",  "short": "Sabotage","fam": "supply",   "bank": "attack",  "effect": "sabotage","known": false, "dur": 20.0, "reach": 3,
		"make": {"bots": 8, "intel": 10, "cash": 12, "creds": 10, "research": 12}, "make_time": 18.0,
		"lead": "Disable installed production on up to three hosts for 20 seconds.", "rules": "Disable the producers (not routing or dispatch) on the target and up to 2 adjacent same-owner hosts for 20 s. Incident response clears it."},
	"patch":     {"name": "Patch",                  "short": "Patch",   "fam": "patch",    "bank": "defense", "effect": "patch",   "known": true,  "dur": 20.0,
		"make": {"bots": 2, "intel": 4, "cash": 4, "creds": 0, "research": 3}, "make_time": 6.0,
		"lead": "Cancel a capture or raid, or arm a shield.", "rules": "Cancel the earliest hostile capture or Vault raid executing on this host; else arm one interception for 20 s. Then 20 s recovery. No stacking."},
	"response":  {"name": "Incident response",      "short": "Response","fam": "response", "bank": "defense", "effect": "response", "known": true,
		"make": {"bots": 2, "intel": 4, "cash": 3, "creds": 3, "research": 1}, "make_time": 4.0,
		"lead": "Clear theft and sabotage from a host.", "rules": "Remove active Phishing, Packet siphon and Supply-chain sabotage from this host. Undispatched stolen output reverts to you. Does not clear DDoS or undo departed theft."},
	"filter":    {"name": "Traffic filter",         "short": "Filter",  "fam": "filter",   "bank": "defense", "effect": "filter",  "known": false, "dur": 12.0,
		"make": {"bots": 5, "intel": 5, "cash": 4, "creds": 0, "research": 1}, "make_time": 6.0,
		"lead": "Clear DDoS and block it for 12 seconds.", "rules": "Clear a DDoS on this host and prevent a new one for 12 s. Can be used proactively. Does not boost production or stop capture."},
	"cover":     {"name": "Courier cover",          "short": "Cover",   "fam": "cover",    "bank": "defense", "effect": "cover",   "known": false, "dur": 16.0,
		"make": {"bots": 2, "intel": 4, "cash": 4, "creds": 0, "research": 2}, "make_time": 6.0,
		"lead": "Protect emitted cargo from interception.", "rules": "For 16 s, cargo newly emitted by this host is protected from Packet siphon for its whole journey. Does not stop Phishing or Vault raid."},
	"express":   {"name": "Express route",          "short": "Express", "fam": "express",  "bank": "defense", "effect": "express", "known": false, "dur": 16.0,
		"make": {"bots": 2, "intel": 5, "cash": 4, "creds": 0, "research": 2}, "make_time": 8.0,
		"lead": "Halve delivery travel time for 16 seconds.", "rules": "For 16 s, resource shipments and new Bots emitted by this host travel at half per-link time. Does not save couriers or raise street capacity."},
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
