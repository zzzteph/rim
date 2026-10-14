## Levels count successive hosts. Defenses spread through owned hosts only.
## Two banks: ATTACK cards target foreign hosts, DEFENCE cards target your own.
## "needs_link": the target must have one of your connections running into it.
const CARDS := {
	"phishworm": {"role": "Steal all production\nAcross three hosts", "name": "Phishing campaign", "short": "Phishing", "fam": "phish", "chain": true, "effect": "campaign", "power": 0.0, "dur": 30.0, "durations": [30.0, 20.0, 10.0], "cost": {"cash": 60, "creds": 70, "research": 40}, "time": 42.0,
		"rules": "Steal all resource output on up to 3 successive foreign hosts for 30 / 20 / 10 seconds. Their owner pays production costs.", "flavor": "Forwarded to the whole address book."},
	"zeroday": {"role": "Instant capture\nConnected hosts only", "name": "0day", "short": "0day", "fam": "zeroday", "chain": false, "needs_link": true, "effect": "breach", "power": 0.75, "dur": 0.0, "cost": {"cash": 50, "creds": 25, "research": 55}, "time": 40.0,
		"rules": "75% chance to capture one foreign host you have a connection into. A failed attempt changes nothing. Blocked by Patch day.", "flavor": "Nobody knew. Now everybody does."},
	"ddos": {"role": "Stop production + routing\nAcross five hosts", "name": "DDOS", "short": "DDOS", "fam": "dos", "chain": true, "effect": "deny", "power": 0.0, "dur": 30.0, "durations": [30.0, 20.0, 10.0, 5.0, 2.0], "cost": {"cash": 80, "creds": 40, "research": 70}, "time": 45.0,
		"rules": "Stop all production and routing, including bots and rig Intel, on up to 5 successive foreign hosts for 30 / 20 / 10 / 5 / 2 seconds.", "flavor": "From everywhere at once."},
	"supply": {"role": "Wipe buildings + bots\nOwnership stays", "name": "Supply chain attack", "short": "Supply", "fam": "supply", "chain": false, "effect": "wipe", "power": 0.0, "dur": 0.0, "cost": {"cash": 40, "creds": 30, "research": 40}, "time": 35.0,
		"rules": "Wipe buildings, construction and defenders from one foreign host. Ownership stays. Blocked by Patch day or SCA.", "flavor": "The update came from upstream."},
	"cdn": {"role": "Clear DDOS or boost\nUp to five own hosts", "name": "CDN", "short": "CDN", "fam": "cdn", "defense": true, "pair": "ddos", "chain": true, "levels": 5, "effect": "cdn", "dur": 10.0, "cost": {"cash": 160, "creds": 80, "research": 140}, "time": 45.0,
		"rules": "On each host: clear DDOS (production and routing) if present; otherwise double all production for 10 seconds. Input costs remain 1:1. Own hosts only.", "flavor": "Keep the network moving."},
	"patch": {"role": "Block 0day + supply\n30 seconds per host", "name": "Patch day", "short": "Patch", "fam": "patch", "defense": true, "pair": "zeroday", "chain": true, "levels": 5, "effect": "patch", "dur": 30.0, "cost": {"cash": 100, "creds": 50, "research": 110}, "time": 40.0,
		"rules": "Protect up to 5 successive owned hosts from 0day and Supply chain attacks for 30 seconds each.", "flavor": "Update. Restart. Secure."},
	"response": {"role": "Remove phishing\nUp to five own hosts", "name": "Incident response", "short": "Response", "fam": "response", "defense": true, "pair": "phishworm", "chain": true, "levels": 5, "effect": "response", "dur": 0.0, "cost": {"cash": 120, "creds": 140, "research": 80}, "time": 42.0,
		"rules": "Remove active Phishing from up to 5 successive owned hosts. Production returns to you. No future immunity.", "flavor": "Contain. Clean. Recover."},
	"sca": {"role": "Block supply chain\n60 seconds per host", "name": "SCA", "short": "SCA", "fam": "sca", "defense": true, "pair": "supply", "chain": true, "levels": 5, "effect": "sca", "dur": 60.0, "cost": {"cash": 80, "creds": 60, "research": 80}, "time": 35.0,
		"rules": "Protect up to 5 successive owned hosts from Supply chain attacks for 60 seconds each.", "flavor": "Verify every dependency."},
}
const ATTACK_ORDER := ["phishworm", "zeroday", "ddos", "supply"]
const DEFENSE_ORDER := ["cdn", "patch", "response", "sca"]
const CARD_ORDER := ["phishworm", "zeroday", "ddos", "supply", "cdn", "patch", "response", "sca"]
# the two deck tabs: red ATTACK, blue DEFENCE (internal key stays "defense")
const BANK_NAME := {"attack": "ATTACK", "defense": "DEFENCE"}
const BANK_COL := {"attack": Color(1.0, 0.36, 0.33), "defense": Color(0.36, 0.6, 1.0)}
const FAMILY_NAME := {"phish": "phishing", "zeroday": "0day exploits", "supply": "supply chain attacks", "dos": "denial of service", "cdn": "CDN", "patch": "patches", "response": "incident response", "sca": "dependency protection"}
const FAMILY_ART := {
	"phish": preload("res://assets/cards/schematic/phishing.png"),
	"zeroday": preload("res://assets/cards/schematic/zeroday.png"),
	"supply": preload("res://assets/cards/schematic/supply.png"),
	"dos": preload("res://assets/cards/schematic/dos.png"),
	"cdn": preload("res://assets/cards/schematic/cdn.png"),
	"patch": preload("res://assets/cards/schematic/patch.png"),
	"response": preload("res://assets/cards/schematic/response.png"),
	"sca": preload("res://assets/cards/schematic/sca.png"),
}
const FAMILY_COL := {
	"phish": Color(0.3, 0.9, 1.0), "zeroday": Color(1.0, 0.45, 0.2),
	"supply": Color(1.0, 0.38, 0.75), "dos": Color(0.68, 0.55, 1.0),
	"cdn": Color(0.25, 0.75, 1.0), "patch": Color(0.35, 0.95, 0.85),
	"response": Color(0.55, 0.62, 1.0), "sca": Color(0.3, 0.52, 1.0),
}
const CARD_ALARM := 8.0
