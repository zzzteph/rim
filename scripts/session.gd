extends Node
## Autoload: carries choices between the main menu and the game scene.

const SAVE_PATH := "user://rim_save.json"
const BACKUP_PATH := "user://rim_save.bak.json"   # last-good backup (T95)
const NETRUN_SAVE := "user://rim_netrun.json"     # the city-infiltration run's save

var start_mode := "new"   # "new" or "load" (placement game); "netrun" / "netrun_load" (city loop)
var seed := 0
var city_size := "small"  # "small" | "medium" | "large" — seeded city dimensions chosen before a run

# Diving into a building's local network map: the city hands the picked building to building.gd here,
# and stashes its own camera/selection so Esc returns the city exactly where it was left.
var enter := {}           # {key:[x,y], name, kind, sec, did, col:[r,g,b], owner, industry, district, people:[names]}
var city_return := {}     # {cam:[x,y], zoom, sel:[x,y]}
var interior := {}        # per-building saved local-map state, keyed by "x,y" (progress persists this session)
var hacked := {}          # "x,y" -> {ctl:int, n:int} for every building you've started to compromise (city marker)

# CONQUEST — the campaign goal: own every host (building), culminating in the central HUB, which triggers
# the citywide OVERLOAD. A host is OWNED once its core (or, for minor hosts, every node) is controlled.
var owned := {}           # "x,y" -> true for every host you have fully conquered
var start_host := []      # [x,y] of your opening foothold (owned from the start); [] until a run begins
var overloaded := false   # true once the HUB has fallen and the city overload has fired (the win)


func reset_conquest() -> void:
	owned = {}; start_host = []; overloaded = false


func host_owned(key: String) -> bool:
	return bool(owned.get(key, false))


func has_save() -> bool:
	# a run is continuable if either the current save or the last-good backup exists (T95)
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func has_netrun_save() -> bool:
	return FileAccess.file_exists(NETRUN_SAVE)
