## CARDS — the catalogue. Six FAMILIES, each with a SINGLE card and a WORM (mass) card = 12 cards.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# A card never captures: it removes defenders, switches production off, cuts routing, or siphons production —
# your bots still have to arrive. SINGLE hits one building. A WORM hits one and jumps along the streets:
# jump 1 is certain, then −WORM_FALLOFF per jump (75 % · 50 % · 25 % · 0), never onto the caster's own
# buildings, stopping at a building immune to the family. A card is played on a building the caster has a
# connection into and travels there along the streets. Every hit reveals the building to the caster and alarms
# its owner.
#
# effect: "defenders" removes `power` × its bots · "breach" removes `power` × bots AND cuts routing `dur` s ·
#         "steal" sends the target's production to the caster for `dur` s · "deny" switches production off AND
#         cuts routing for `dur` s. The landed amount scales by the type's RESIST (scripts/botnet_cfg/types.gd).
const CARDS := {
	# ── credential attacks: steal the logins, wipe every defender ──
	"stuff":       {"name": "Credential stuffing", "fam": "cred",    "chain": false, "effect": "defenders", "power": 1.0, "dur": 0.0,  "cost": {"cash": 20, "creds": 35, "research": 10},  "time": 25.0,
		"rules": "Wipe every defender of one building.", "flavor": "Reused passwords open more than one door."},
	"credworm":    {"name": "Credential worm",     "fam": "cred",    "chain": true,  "effect": "defenders", "power": 1.0, "dur": 0.0,  "cost": {"cash": 60, "creds": 90, "research": 30},  "time": 45.0,
		"rules": "Wipe defenders, then spread along the streets.", "flavor": "One password, every door."},
	# ── phishing: trick the staff, half the defenders fold ──
	"phish":       {"name": "Phishing",            "fam": "phish",   "chain": false, "effect": "defenders", "power": 0.5, "dur": 0.0,  "cost": {"cash": 20, "creds": 25, "research": 15},  "time": 22.0,
		"rules": "Remove half of one building's defenders.", "flavor": "Click here to verify your account."},
	"phishworm":   {"name": "Phishing worm",       "fam": "phish",   "chain": true,  "effect": "defenders", "power": 0.5, "dur": 0.0,  "cost": {"cash": 60, "creds": 70, "research": 40},  "time": 42.0,
		"rules": "Remove half the defenders, spreading along the streets.", "flavor": "Forwarded to the whole address book."},
	# ── 1-day exploits: a known hole, a quarter of the defenders gone ──
	"oneday":      {"name": "1-day exploit",       "fam": "oneday",  "chain": false, "effect": "defenders", "power": 0.25, "dur": 0.0, "cost": {"cash": 20, "creds": 10, "research": 25},  "time": 20.0,
		"rules": "Remove a quarter of one building's defenders.", "flavor": "Patched yesterday. Deployed never."},
	"onedayworm":  {"name": "1-day worm",          "fam": "oneday",  "chain": true,  "effect": "defenders", "power": 0.25, "dur": 0.0, "cost": {"cash": 60, "creds": 30, "research": 60},  "time": 40.0,
		"rules": "Remove a quarter of the defenders, spreading along the streets.", "flavor": "Scanned the whole subnet by lunch."},
	# ── 0-day exploits: an unknown hole, half the defenders and the routing ──
	"zeroday":     {"name": "0-day exploit",       "fam": "zeroday", "chain": false, "effect": "breach",    "power": 0.5, "dur": 20.0, "cost": {"cash": 50, "creds": 25, "research": 55},  "time": 40.0,
		"rules": "Remove half the defenders and cut routing 20 s.", "flavor": "Nobody knew. Now everybody does."},
	"zeroworm":    {"name": "0-day worm",          "fam": "zeroday", "chain": true,  "effect": "breach",    "power": 0.5, "dur": 20.0, "cost": {"cash": 110, "creds": 40, "research": 110}, "time": 60.0,
		"rules": "Remove half the defenders and cut routing, spreading along the streets.", "flavor": "It does not need to be invited."},
	# ── supply-chain: ride the vendor in, take its output ──
	"supply":      {"name": "Supply-chain hit",    "fam": "supply",  "chain": false, "effect": "steal",     "power": 0.0, "dur": 5.0,  "cost": {"cash": 40, "creds": 30, "research": 40},  "time": 35.0,
		"rules": "For 5 s the building's production is yours.", "flavor": "The update came from upstream."},
	"supplyworm":  {"name": "Supply-chain worm",   "fam": "supply",  "chain": true,  "effect": "steal",     "power": 0.0, "dur": 5.0,  "cost": {"cash": 90, "creds": 50, "research": 80},  "time": 50.0,
		"rules": "Siphon production for 5 s, spreading along the streets.", "flavor": "Signed by a trusted certificate."},
	# ── denial of service: drown it, nothing works ──
	"dos":         {"name": "DoS",                 "fam": "dos",     "chain": false, "effect": "deny",      "power": 0.0, "dur": 25.0, "cost": {"cash": 30, "creds": 20, "research": 30},  "time": 25.0,
		"rules": "Production off and routing cut for 25 s.", "flavor": "GET / … GET / … GET / …"},
	"ddos":        {"name": "DDoS",                "fam": "dos",     "chain": true,  "effect": "deny",      "power": 0.0, "dur": 25.0, "cost": {"cash": 80, "creds": 40, "research": 70},  "time": 45.0,
		"rules": "Production off and routing cut, spreading along the streets.", "flavor": "From everywhere at once."},
}
# catalogue order: each family's single then its worm
const CARD_ORDER := ["stuff", "credworm", "phish", "phishworm", "oneday", "onedayworm", "zeroday", "zeroworm", "supply", "supplyworm", "dos", "ddos"]
const FAMILY_NAME := {"cred": "credential attacks", "phish": "phishing", "oneday": "1-day exploits", "zeroday": "0-day exploits", "supply": "supply-chain", "dos": "denial of service"}
# card art is procedural (no files): a dark tile with a chamfered corner and a neon glyph in the family's colour
const FAMILY_COL := {
	"cred":    Color(1.0, 0.72, 0.2),
	"phish":   Color(0.3, 0.9, 1.0),
	"oneday":  Color(0.72, 1.0, 0.25),
	"zeroday": Color(1.0, 0.45, 0.2),
	"supply":  Color(1.0, 0.38, 0.75),
	"dos":     Color(0.68, 0.55, 1.0),
}
const WORM_FALLOFF := 0.25
const STEAL_DUR := 5.0             # seconds a supply-chain hit siphons a building's production to the caster
const CARD_ALARM := 8.0            # seconds a hit building counts as under attack (its guards arm, its owner sees red)
