## Four fixed-effect cards. Levels count successive nodes in a spreading chain.
## Edit prices and research times here; restart the scene after changing constants.
## Cards travel from the caster's owned rig and never capture a node themselves.
## Spread follows one adjacent foreign node per level, never repeats a node,
## and stops at a dead end. Building-type resistance does not alter these effects.
const CARDS := {
	"phishworm": {"role": "Steal resources\nAcross three nodes", "name": "Phishing campaign", "fam": "phish", "chain": true, "effect": "campaign", "power": 0.1, "dur": 30.0, "durations": [30.0, 20.0, 10.0], "cost": {"cash": 60, "creds": 70, "research": 40}, "time": 42.0,
		"rules": "Remove 10% of defenders on each of up to 3 successive nodes. Steal all resource output for 30 / 20 / 10 seconds.", "flavor": "Forwarded to the whole address book."},
	"zeroday": {"role": "Remove defenders\nCut a route", "name": "0day", "fam": "zeroday", "chain": false, "effect": "breach", "power": 0.75, "dur": 20.0, "cost": {"cash": 50, "creds": 25, "research": 55}, "time": 40.0,
		"rules": "Remove 75% of defenders and cut routing for 20 seconds on one node.", "flavor": "Nobody knew. Now everybody does."},
	"ddos": {"role": "Disable production\nAcross five nodes", "name": "DDOS", "fam": "dos", "chain": true, "effect": "deny", "power": 0.0, "dur": 30.0, "durations": [30.0, 20.0, 10.0, 5.0, 2.0], "cost": {"cash": 80, "creds": 40, "research": 70}, "time": 45.0,
		"rules": "Disable production and routing on up to 5 successive nodes for 30 / 20 / 10 / 5 / 2 seconds.", "flavor": "From everywhere at once."},
	"supply": {"role": "Destroy slot buildings\nCancel construction", "name": "Supply chain attack", "fam": "supply", "chain": false, "effect": "wipe", "power": 0.0, "dur": 0.0, "cost": {"cash": 40, "creds": 30, "research": 40}, "time": 35.0,
		"rules": "Remove every installed slot building on one node and cancel its construction. Defenders and ownership stay.", "flavor": "The update came from upstream."},
}
const CARD_ORDER := ["phishworm", "zeroday", "ddos", "supply"]
const FAMILY_NAME := {"phish": "phishing", "zeroday": "0day exploits", "supply": "supply chain attacks", "dos": "denial of service"}
const FAMILY_ART := {
	"phish": preload("res://assets/cards/schematic/phishing.png"),
	"zeroday": preload("res://assets/cards/schematic/zeroday.png"),
	"supply": preload("res://assets/cards/schematic/supply.png"),
	"dos": preload("res://assets/cards/schematic/dos.png"),
}
const FAMILY_COL := {
	"phish": Color(0.3, 0.9, 1.0),
	"zeroday": Color(1.0, 0.45, 0.2),
	"supply": Color(1.0, 0.38, 0.75),
	"dos": Color(0.68, 0.55, 1.0),
}
const CARD_ALARM := 8.0
