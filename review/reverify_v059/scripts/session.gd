extends Node
## Autoload: carries choices between the main menu and the game scene.

const SAVE_PATH := "res://probe_save.json"
const BACKUP_PATH := "res://probe_save.bak.json"   # last-good backup (T95)

var start_mode := "new"   # "new" or "load"
var seed := 0


func has_save() -> bool:
	# a run is continuable if either the current save or the last-good backup exists (T95)
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)
