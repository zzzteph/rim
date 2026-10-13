## CARDS — eight prototype cards. Campaign and DDOS spread; the others hit one target.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# A card never captures: it removes defenders, switches production off, cuts routing, or siphons production —
# your bots still have to arrive. SINGLE hits one building. A WORM hits one and jumps along the streets:
# jump 1 is certain, then −WORM_FALLOFF per jump (75 % · 50 % · 25 % · 0), never onto the caster's own
# buildings, stopping at a building immune to the family. A card is played on a building the caster has a
# route to from its owned rig, through its own buildings. It travels along those streets. Every hit reveals the building to the caster and alarms
# its owner.
#
# effect: "defenders" removes `power` × its bots · "breach" removes `power` × bots AND cuts routing `dur` s ·
#         "steal" sends the target's production to the caster for `dur` s · "deny" switches production off AND
#         cuts routing for `dur` s. The landed amount scales by the type's RESIST (scripts/botnet_cfg/types.gd).
const CARDS := {
	# ── credential attacks: steal the logins, wipe every defender ──
	"stuff":       {"role": "Heavy defender wipe\nCredential hungry", "name": "Credential stuffing", "fam": "cred",    "chain": false, "effect": "defenders", "power": 1.0, "dur": 0.0,  "cost": {"cash": 20, "creds": 35, "research": 10},  "time": 25.0,
		"rules": "Base: remove 100% of defenders. Type resistance reduces the effect; bots still capture.", "flavor": "Reused passwords open more than one door."},
	# ── phishing: trick the staff, half the defenders fold ──
	"phish":       {"role": "Cheap staff attack\nStrong vs PCs", "name": "Phishing",            "fam": "phish",   "chain": false, "effect": "defenders", "power": 0.5, "dur": 0.0,  "cost": {"cash": 20, "creds": 25, "research": 15},  "time": 22.0,
		"rules": "Base: remove 50% of current defenders. Building type changes the effect.", "flavor": "Click here to verify your account."},
	"phishworm":   {"role": "Spread a staff attack\nAcross a cluster", "name": "Phishing campaign",       "fam": "phish",   "chain": true,  "effect": "defenders", "power": 0.5, "dur": 0.0,  "cost": {"cash": 60, "creds": 70, "research": 40},  "time": 42.0,
		"rules": "Base: remove 50% of defenders, then spread. Building type changes the effect.", "flavor": "Forwarded to the whole address book."},
	# ── 1-day exploits: a known hole, a quarter of the defenders gone ──
	"oneday":      {"role": "Low credential cost\nStrong vs IoT", "name": "1 day",       "fam": "oneday",  "chain": false, "effect": "defenders", "power": 0.25, "dur": 0.0, "cost": {"cash": 20, "creds": 10, "research": 25},  "time": 20.0,
		"rules": "Base: remove 25% of current defenders. Building type changes the effect.", "flavor": "Patched yesterday. Deployed never."},
	# ── 0-day exploits: an unknown hole, half the defenders and the routing ──
	"zeroday":     {"role": "Damage + routing cut\nBreak a chokepoint", "name": "0 day",       "fam": "zeroday", "chain": false, "effect": "breach",    "power": 0.5, "dur": 20.0, "cost": {"cash": 50, "creds": 25, "research": 55},  "time": 40.0,
		"rules": "Base: remove 50% of defenders and cut routing for 20 s. Building type changes both effects.", "flavor": "Nobody knew. Now everybody does."},
	# ── supply-chain: ride the vendor in, take its output ──
	"supply":      {"role": "Steal resource output\nTarget producers", "name": "Supplychain",    "fam": "supply",  "chain": false, "effect": "steal",     "power": 0.0, "dur": 15.0,  "cost": {"cash": 40, "creds": 30, "research": 40},  "time": 35.0,
		"rules": "Base: siphon resource production for 15 s. Building type changes the duration.", "flavor": "The update came from upstream."},
	# ── denial of service: drown it, nothing works ──
	"dos":         {"role": "Stop production\nand reinforcement", "name": "DOS",                 "fam": "dos",     "chain": false, "effect": "deny",      "power": 0.0, "dur": 25.0, "cost": {"cash": 30, "creds": 20, "research": 30},  "time": 25.0,
		"rules": "Base: disable production and routing for 25 s. Building type changes the duration.", "flavor": "GET / … GET / … GET / …"},
	"ddos":        {"role": "Disable a cluster\nHigher research cost", "name": "DDOS",                "fam": "dos",     "chain": true,  "effect": "deny",      "power": 0.0, "dur": 25.0, "cost": {"cash": 80, "creds": 40, "research": 70},  "time": 45.0,
		"rules": "Base: disable production and routing for 25 s, then spread. Type changes the duration.", "flavor": "From everywhere at once."},
}
# catalogue order: each family's single then its worm
const CARD_ORDER := ["stuff", "phish", "phishworm", "oneday", "zeroday", "dos", "ddos", "supply"]
const FAMILY_NAME := {"cred": "credential attacks", "phish": "phishing", "oneday": "1-day exploits", "zeroday": "0-day exploits", "supply": "supply-chain", "dos": "denial of service"}
# One schematic image per family; single-target and worm cards share the same art.
# Preloads keep the images cached and included in exported builds.
const FAMILY_ART := {
	"cred": preload("res://assets/cards/schematic/credential.png"),
	"phish": preload("res://assets/cards/schematic/phishing.png"),
	"oneday": preload("res://assets/cards/schematic/oneday.png"),
	"zeroday": preload("res://assets/cards/schematic/zeroday.png"),
	"supply": preload("res://assets/cards/schematic/supply.png"),
	"dos": preload("res://assets/cards/schematic/dos.png"),
}
# Family colours also identify the card frame, type line and spreading marker.
const FAMILY_COL := {
	"cred":    Color(1.0, 0.72, 0.2),
	"phish":   Color(0.3, 0.9, 1.0),
	"oneday":  Color(0.72, 1.0, 0.25),
	"zeroday": Color(1.0, 0.45, 0.2),
	"supply":  Color(1.0, 0.38, 0.75),
	"dos":     Color(0.68, 0.55, 1.0),
}
const WORM_FALLOFF := 0.25
const STEAL_DUR := 15.0            # first-pass tuning: longer economic disruption; validated against self-financing loadouts
const CARD_ALARM := 8.0            # seconds a hit building counts as under attack (its guards arm, its owner sees red)
