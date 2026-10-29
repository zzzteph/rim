## Building TYPES — slots, production multipliers, security bonus, spawn weights by district, and the resistance table (how much of each card family lands on each type).
## Edit the numbers here; scripts/botnet_proto.gd reads them through aliases and never defines them itself.
## A changed value needs the scene restarted (constants are read when the script loads).

# ── building TYPES: slots and production multipliers; the picture on the map is the type's icon ──
const NODE_TYPES := {
	"pc":     {"name": "PC",          "short": "PC",   "slots": 3, "bot": 1.0, "intel": 1.0, "cash": 1.0, "cred": 1.0, "research": 1.0, "desc": "an office workstation — 3 slots"},
	"iot":    {"name": "IoT device",  "short": "IoT",  "slots": 1, "bot": 1.0, "intel": 1.0, "cash": 1.0, "cred": 0.5, "research": 0.5, "desc": "a camera or a router — 1 slot, soft, poor harvests"},
	"server": {"name": "Server",      "short": "Srv",  "slots": 3, "bot": 1.0, "intel": 1.5, "cash": 1.0, "cred": 1.0, "research": 1.5, "desc": "a rack server — 3 slots, Intel ×1.5, Research ×1.5"},
	"web":    {"name": "Web server",  "short": "Web",  "slots": 3, "bot": 1.0, "intel": 1.5, "cash": 1.0, "cred": 2.0, "research": 1.0, "desc": "a public web host — 3 slots, Intel ×1.5, Credentials ×2"},
	"db":     {"name": "Database",    "short": "DB",   "slots": 4, "bot": 1.0, "intel": 2.0, "cash": 1.0, "cred": 1.5, "research": 1.5, "desc": "a database cluster — 4 slots, Intel ×2, Credentials & Research ×1.5"},
	"file":   {"name": "File server", "short": "Files","slots": 4, "bot": 1.0, "intel": 2.0, "cash": 1.0, "cred": 1.0, "research": 2.0, "desc": "a file server — 4 slots, Intel ×2, Research ×2"},
	"erp":    {"name": "ERP system",  "short": "ERP",  "slots": 5, "bot": 1.5, "intel": 1.5, "cash": 1.5, "cred": 1.5, "research": 1.5, "desc": "an enterprise core — 5 slots, everything ×1.5"},
}
# spawn weights by district value (rim 1 … downtown 3)
const TYPE_WEIGHTS := {
	1: {"iot": 0.35, "pc": 0.40, "web": 0.10, "server": 0.10, "file": 0.05},
	2: {"pc": 0.30, "server": 0.20, "web": 0.20, "db": 0.15, "file": 0.15},
	3: {"db": 0.25, "file": 0.20, "server": 0.20, "web": 0.15, "erp": 0.20},
}
# There are no security levels: a host's type decides its slots and production specialties above, and any card
# can target any foreign host. What changes an attack's odds is Recon (tuning.gd UNSCOUTED_CHANCE).
