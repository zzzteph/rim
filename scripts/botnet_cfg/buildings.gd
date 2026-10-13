## What you build INSIDE a building — the five kinds and the build timings.
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# ── the LOCAL layer: buildings inside a building (slots). Click a building you own and build straight into
# its slots; jobs run on their own, several at once, each paid in Intel up front ──
const BUILD_TIME := 10.0           # seconds a build job needs
const DEMOLISH_TIME := 5.0         # seconds to clear an occupied slot first (replace = DEMOLISH_TIME + BUILD_TIME)
const BUILD_COST_INTEL := 10.0     # Intel paid when a build job starts (a replace pays it too; clearing is free)
const BUILD_KINDS := {
	"bot":   {"name": "Bot farm",             "card": "Bot farm",     "short": "B", "col": Color(0.45, 0.95, 0.6),  "desc": "+1 bot/s regeneration here"},
	"intel": {"name": "Intel harvester",      "card": "Intel harv.",  "short": "I", "col": Color(0.4, 0.85, 1.0),   "desc": "+1 Intel/s and +50 Intel limit. Attacks spend 1 Intel per bot."},
	"cash":  {"name": "Darknet market",       "card": "Market",       "short": "$", "col": Color(1.0, 0.85, 0.3),   "desc": "a Cash packet (worth the building's value) every 3 s, travelling home to your rig. Cash pays for cards and expansion."},
	"cred":  {"name": "Credential harvester", "card": "Cred. harv.",  "short": "K", "col": Color(1.0, 0.6, 0.45),   "desc": "+0.5 Credentials/s and +50 to their limit (× the building type). Credentials pay for cards."},
	"lab":   {"name": "Research lab",         "card": "Research lab", "short": "R", "col": Color(0.75, 0.55, 1.0),  "desc": "+0.5 Research/s and +50 to its limit (× the building type). Research pays for cards."},
}
