extends Node
## Autoload: carries choices between the main menu and the game scene.

const SAVE_PATH := "user://rim_save.json"
const BACKUP_PATH := "user://rim_save.bak.json"   # last-good backup (T95)
const NETRUN_SAVE := "user://rim_netrun.json"     # the city-infiltration run's save

var start_mode := "new"   # "new" or "load" (placement game); "netrun" / "netrun_load" (city loop)
var seed := 0
var city_size := "small"  # "small" | "medium" | "large" — seeded city dimensions chosen before a run


func has_save() -> bool:
	# a run is continuable if either the current save or the last-good backup exists (T95)
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func has_netrun_save() -> bool:
	return FileAccess.file_exists(NETRUN_SAVE)
