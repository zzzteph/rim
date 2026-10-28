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
#   make          {bots,intel,cash,creds,research} paid once when a copy STARTS manufacturing; make_time seconds.
#                 Bots stay 0: Bots are the couriers that carry what the network makes, not an ingredient.
#   sec_max       capture ceiling (capture cards only)
#   exec          execution seconds after travel (capture/raid/worm-stage); a capture that runs to the end succeeds
#   dur           timed-effect seconds (theft/disruption/support)
#   reach         how many hosts it covers (worm, sabotage, DDoS, Vault raid)
#   needs_link    the first target must have one of your connections into it
const CARDS := {
	"recon":     {"name": "Recon", "short": "Recon", "fam": "recon", "bank": "attack", "effect": "recon", "known": true, "dur": 45.0,
		"make": {"bots": 0, "intel": 8, "cash": 0, "creds": 0, "research": 0}, "make_time": 3.0,
		"lead": "Reveal a host's contents for 45 s.", "rules": "Shows its installations, storage and Firewall cards. The snapshot goes stale after 45 s. Not an alarm, and not needed to capture."},
	"breach":    {"name": "Credential breach", "short": "Breach", "fam": "breach", "bank": "attack", "effect": "capture", "known": true, "sec_max": 1, "exec": 15.0,
		"make": {"bots": 0, "intel": 12, "cash": 0, "creds": 12, "research": 0}, "make_time": 12.0,
		"lead": "Capture a security-1 host.", "rules": "Travels from your main node, then executes for 15 s. It captures the host unless a Patch, a lost route or a change of owner stops it first."},
	"exploit":   {"name": "Known exploit", "short": "Exploit", "fam": "exploit", "bank": "attack", "effect": "capture", "known": false, "sec_max": 2, "exec": 12.0,
		"make": {"bots": 0, "intel": 14, "cash": 0, "creds": 0, "research": 12}, "make_time": 14.0,
		"lead": "Capture a host up to security 2.", "rules": "Travels, then executes for 12 s. It captures unless a Patch, a lost route or a change of owner stops it first. Breach is cheaper against a security-1 host."},
	"phish":     {"name": "Phishing", "short": "Phish", "fam": "phish", "bank": "attack", "effect": "phish", "known": true, "dur": 60.0,
		"make": {"bots": 0, "intel": 18, "cash": 6, "creds": 8, "research": 4}, "make_time": 12.0,
		"lead": "Divert new output for 60 s.", "rules": "Everything a rival host makes goes to you, its Bot stations' couriers too. They keep the host but get nothing from it. Incident response ends it."},
	"siphon":    {"name": "Packet siphon", "short": "Siphon", "fam": "siphon", "bank": "attack", "effect": "siphon", "known": false, "dur": 30.0, "cargo": 30,
		"make": {"bots": 0, "intel": 20, "cash": 6, "creds": 6, "research": 5}, "make_time": 12.0,
		"lead": "Hijack couriers crossing a host.", "rules": "Pick a resource. For 30 s, their couriers carrying it that leave or pass this host bring it to you instead, up to 30. Best on a host their deliveries cross. Courier cover protects cargo."},
	"vault":     {"name": "Vault raid", "short": "Vault", "fam": "vault", "bank": "attack", "effect": "vault", "known": false, "exec": 10.0, "cargo": 30, "reach": 3,
		"make": {"bots": 0, "intel": 24, "cash": 0, "creds": 10, "research": 8}, "make_time": 16.0,
		"lead": "Empty the storage of 3 linked hosts.", "rules": "Raids a rival host for 10 s. Then it takes all that is stored there and on the 2 nearest linked hosts of that owner, up to 30 units. Each unit rides home on one of your Bots. A Patch stops it."},
	"ddos":      {"name": "DDoS", "short": "DDoS", "fam": "dos", "bank": "attack", "effect": "ddos", "known": false, "dur": 45.0, "reach": 3,
		"make": {"bots": 0, "intel": 34, "cash": 14, "creds": 0, "research": 5}, "make_time": 14.0,
		"lead": "Halt 3 hosts' output for 45 s.", "rules": "Hits the target and its owner's 2 nearest hosts. They stop producing, main-node income and outgoing couriers; incoming cargo still arrives. Traffic filter clears it."},
	"zeroday":   {"name": "0day", "short": "0day", "fam": "zeroday", "bank": "attack", "effect": "capture", "known": false, "sec_max": 3, "exec": 10.0, "exec_rig": 15.0,
		"make": {"bots": 0, "intel": 16, "cash": 12, "creds": 12, "research": 16}, "make_time": 26.0,
		"lead": "Capture a host up to security 3.", "rules": "Travels, then executes for 10 s, or 15 s on a rival main node with a countdown they see. It captures unless a Patch, a lost route or a change of owner stops it."},
	"worm":      {"name": "Worm", "short": "Worm", "fam": "worm", "bank": "attack", "effect": "worm", "known": false, "sec_max": 2, "exec": 12.0, "reach": 2,
		"make": {"bots": 0, "intel": 24, "cash": 0, "creds": 0, "research": 24}, "make_time": 22.0,
		"lead": "Known exploit on 2 linked hosts.", "rules": "Captures the target, then its nearest linked host of the same owner, security 2 or less. Each stage executes for 12 s and can be stopped on its own. A Patch, a lost route or a change of owner ends it."},
	"sabotage":  {"name": "Supply-chain sabotage", "short": "Sabotage", "fam": "supply", "bank": "attack", "effect": "sabotage", "known": false, "dur": 60.0, "reach": 3,
		"make": {"bots": 0, "intel": 36, "cash": 12, "creds": 8, "research": 14}, "make_time": 22.0,
		"lead": "Shut producers on 3 hosts for 60 s.", "rules": "Hits the target and up to 2 adjacent hosts of its owner. Routing and dispatch keep working. Incident response clears it."},
	"patch":     {"name": "Patch", "short": "Patch", "fam": "patch", "bank": "defense", "effect": "patch", "known": true, "dur": 30.0,
		"make": {"bots": 0, "intel": 12, "cash": 4, "creds": 0, "research": 3}, "make_time": 8.0,
		"lead": "Stop a capture or a raid.", "rules": "Cancels a capture, Worm or Vault raid running here, or guards 30 s against the next. In a Firewall socket it waits, however long, and stops the next one as it starts."},
	"response":  {"name": "Incident response", "short": "Response", "fam": "response", "bank": "defense", "effect": "response", "known": true,
		"make": {"bots": 0, "intel": 12, "cash": 3, "creds": 3, "research": 2}, "make_time": 6.0,
		"lead": "Clear theft and sabotage here.", "rules": "Removes Phishing, Packet siphon and sabotage here; unsent stolen output comes back. In a Firewall socket it fires the moment one lands. It does not clear DDoS."},
	"filter":    {"name": "Traffic filter", "short": "Filter", "fam": "filter", "bank": "defense", "effect": "filter", "known": false, "dur": 30.0,
		"make": {"bots": 0, "intel": 14, "cash": 4, "creds": 0, "research": 2}, "make_time": 8.0,
		"lead": "Clear DDoS and block it for 30 s.", "rules": "In a Firewall socket it waits and blocks the next DDoS as it lands. It does not boost production or stop capture."},
	"cover":     {"name": "Courier cover", "short": "Cover", "fam": "cover", "bank": "defense", "effect": "cover", "known": false, "dur": 30.0,
		"make": {"bots": 0, "intel": 12, "cash": 4, "creds": 0, "research": 2}, "make_time": 8.0,
		"lead": "Shield this host's cargo for 30 s.", "rules": "Its couriers are safe from Packet siphon all the way. In a Firewall socket it fires when a siphon grabs one, and saves that courier."},
	"express":   {"name": "Express route", "short": "Express", "fam": "express", "bank": "defense", "effect": "express", "known": false, "dur": 45.0,
		"make": {"bots": 0, "intel": 14, "cash": 4, "creds": 0, "research": 2}, "make_time": 10.0,
		"lead": "Halve delivery time for 45 s.", "rules": "Shipments and new Bots from this host cross each link twice as fast. It cannot go in a Firewall socket: play it when you need the speed."},
}

# The research tree: a locked recipe, its prerequisite blueprint, one-time cost and time.
const RESEARCH := {
	"exploit":  {"prereq": "breach",  "intel": 24, "cash": 4, "research": 20, "time": 40.0},
	"zeroday":  {"prereq": "exploit", "intel": 48, "cash": 12, "research": 50, "time": 70.0},
	"worm":     {"prereq": "exploit", "intel": 36, "cash": 8, "research": 36, "time": 55.0},
	"ddos":     {"prereq": "recon",   "intel": 24, "cash": 4, "research": 18, "time": 35.0},
	"sabotage": {"prereq": "ddos",    "intel": 40, "cash": 12, "research": 44, "time": 60.0},
	"siphon":   {"prereq": "phish",   "intel": 24, "cash": 4, "research": 20, "time": 40.0},
	"vault":    {"prereq": "siphon",  "intel": 36, "cash": 8, "research": 40, "time": 55.0},
	"filter":   {"prereq": "patch",   "intel": 18, "cash": 4, "research": 14, "time": 30.0},
	"cover":    {"prereq": "patch",   "intel": 18, "cash": 4, "research": 14, "time": 30.0},
	"express":  {"prereq": "recon",   "intel": 24, "cash": 4, "research": 20, "time": 35.0},
}

const ATTACK_ORDER := ["recon", "breach", "exploit", "phish", "siphon", "vault", "ddos", "zeroday", "worm", "sabotage"]
const DEFENSE_ORDER := ["patch", "response", "filter", "cover", "express"]
const CARD_ORDER := ["recon", "breach", "exploit", "phish", "siphon", "vault", "ddos", "zeroday", "worm", "sabotage", "patch", "response", "filter", "cover", "express"]
const KNOWN_START := ["recon", "breach", "phish", "patch", "response"]
const MANUFACTURE_LANES := 3
const READY_SLOTS := 12            # active manufacturing jobs + ready copies, across all lanes

# the two deck tabs: red ATTACK, blue DEFENCE (internal key stays "defense")
const BANK_NAME := {"attack": "ATTACK", "defense": "DEFENCE", "research": "RESEARCH"}
const BANK_COL := {"attack": Color(1.0, 0.36, 0.33), "defense": Color(0.36, 0.6, 1.0), "research": Color(0.75, 0.55, 1.0)}
const FAMILY_NAME := {"recon": "recon", "breach": "credential breach", "exploit": "known exploits", "phish": "phishing", "siphon": "packet siphon", "vault": "vault raids", "dos": "denial of service", "zeroday": "0day exploits", "worm": "worms", "supply": "supply-chain sabotage", "patch": "patches", "response": "incident response", "filter": "traffic filters", "cover": "courier cover", "express": "express routes"}
# Schematic art: one picture per family (assets/cards/schematic/; make_art.py draws vault, worm, siphon,
# cover and express in the style of the hand-made ones). tests/text_fit_test.gd checks no two cards share one.
const FAMILY_ART := {
	"recon": preload("res://assets/cards/schematic/sca.png"),
	"breach": preload("res://assets/cards/schematic/credential.png"),
	"exploit": preload("res://assets/cards/schematic/oneday.png"),
	"phish": preload("res://assets/cards/schematic/phishing.png"),
	"siphon": preload("res://assets/cards/schematic/siphon.png"),
	"vault": preload("res://assets/cards/schematic/vault.png"),
	"dos": preload("res://assets/cards/schematic/dos.png"),
	"zeroday": preload("res://assets/cards/schematic/zeroday.png"),
	"worm": preload("res://assets/cards/schematic/worm.png"),
	"supply": preload("res://assets/cards/schematic/supply.png"),
	"patch": preload("res://assets/cards/schematic/patch.png"),
	"response": preload("res://assets/cards/schematic/response.png"),
	"filter": preload("res://assets/cards/schematic/cdn.png"),
	"cover": preload("res://assets/cards/schematic/cover.png"),
	"express": preload("res://assets/cards/schematic/express.png"),
}
const FAMILY_COL := {
	"recon": Color(0.5, 0.85, 1.0), "breach": Color(0.97, 0.69, 0.16), "exploit": Color(0.72, 0.97, 0.22),
	"phish": Color(0.3, 0.9, 1.0), "siphon": Color(0.25, 0.84, 0.66), "vault": Color(1.0, 0.82, 0.31),
	"dos": Color(0.68, 0.55, 1.0), "zeroday": Color(1.0, 0.45, 0.2), "worm": Color(0.49, 0.87, 0.38),
	"supply": Color(1.0, 0.38, 0.75), "patch": Color(0.35, 0.95, 0.85), "response": Color(0.55, 0.62, 1.0),
	"filter": Color(0.3, 0.75, 1.0), "cover": Color(1.0, 0.72, 0.36), "express": Color(0.91, 0.49, 0.91),
}
const CARD_ALARM := 8.0
