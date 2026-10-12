## CARDS — the catalogue (cost, time, effect, rules text, flavour), families and their colours, the ANY multipliers, the worm fall-off and the alarm.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# ── CARDS: ultimate weapons researched over time from Cash, Credentials and Research. A card never captures:
# it removes defenders, switches production off or cuts routing for a while — bots still have to arrive.
# SINGLE hits one building; a WORM (chain) hits one and jumps along the streets: jump 1 is certain, then
# −WORM_FALLOFF per jump (75 % · 50 % · 25 % · 0), never onto the caster's own buildings. LINKED cards work
# only on a building the caster has a connection into; ANY cards work anywhere at ANY_COST_MULT × the cost
# and ANY_TIME_MULT × the time. Every hit reveals the building to the caster and alarms its owner.
const CARDS := {
	"stuff":    {"name": "Credential stuffing", "fam": "cred",    "chain": false, "effect": "defenders",  "power": 1.0, "dur": 0.0,  "cost": {"cash": 20, "creds": 30, "research": 10},  "time": 20.0,
		"desc": "wipes the defenders of one building", "rules": "Wipe all defenders of one building.", "flavor": "Reused passwords open more than one door."},
	"phish":    {"name": "Phishing",            "fam": "phish",   "chain": false, "effect": "production", "power": 0.0, "dur": 25.0, "cost": {"cash": 20, "creds": 20, "research": 15},  "time": 20.0,
		"desc": "switches one building's production off for 25 s (no regeneration, Intel, Cash…)", "rules": "Switch one building's production off for 25 s.", "flavor": "Click here to verify your account."},
	"oneday":   {"name": "1-day exploit",       "fam": "exploit", "chain": false, "effect": "routing",    "power": 0.0, "dur": 20.0, "cost": {"cash": 30, "creds": 10, "research": 30},  "time": 25.0,
		"desc": "cuts one building's routing for 20 s: nothing leaves it or passes through it", "rules": "Cut one building's routing for 20 s. Nothing leaves it or passes through.", "flavor": "Patched yesterday. Deployed never."},
	"zeroday":  {"name": "0-day exploit",       "fam": "exploit", "chain": false, "effect": "breach",     "power": 0.5, "dur": 20.0, "cost": {"cash": 60, "creds": 20, "research": 60},  "time": 40.0,
		"desc": "halves the defenders AND cuts routing for 20 s", "rules": "Halve the defenders and cut routing for 20 s.", "flavor": "Nobody knew. Now everybody does."},
	"credworm": {"name": "Credential worm",     "fam": "cred",    "chain": true,  "effect": "defenders",  "power": 1.0, "dur": 0.0,  "cost": {"cash": 60, "creds": 80, "research": 30},  "time": 40.0,
		"desc": "wipes defenders along a chain of buildings", "rules": "Wipe defenders, then spread along the streets: 100, 75, 50, 25 %.", "flavor": "One password, every door."},
	"supply":   {"name": "Supply-chain attack", "fam": "supply",  "chain": true,  "effect": "production", "power": 0.0, "dur": 25.0, "cost": {"cash": 80, "creds": 30, "research": 70},  "time": 45.0,
		"desc": "production off for 25 s along a chain", "rules": "Production off for 25 s, spreading along the streets.", "flavor": "The update came from upstream."},
	"zeroworm": {"name": "0-day worm",          "fam": "exploit", "chain": true,  "effect": "breach",     "power": 0.5, "dur": 20.0, "cost": {"cash": 120, "creds": 40, "research": 120}, "time": 60.0,
		"desc": "halves defenders and cuts routing for 20 s along a chain", "rules": "Halve defenders and cut routing, spreading along the streets.", "flavor": "It does not need to be invited."},
}
const CARD_ORDER := ["stuff", "phish", "oneday", "zeroday", "credworm", "supply", "zeroworm"]
const FAMILY_NAME := {"cred": "credential attacks", "phish": "phishing", "supply": "supply-chain attacks", "exploit": "exploits"}
# card art is procedural (no files): a dark tile with a chamfered corner and a neon glyph in the family's colour
const FAMILY_COL := {"cred": Color(1.0, 0.72, 0.2), "phish": Color(0.3, 0.9, 1.0), "supply": Color(1.0, 0.38, 0.75), "exploit": Color(0.72, 1.0, 0.25)}
const ANY_COST_MULT := 4.0
const ANY_TIME_MULT := 2.0
const WORM_FALLOFF := 0.25
const CARD_ALARM := 8.0            # seconds a hit building counts as under attack (its guards arm, its owner sees red)
