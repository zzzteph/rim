extends Node
## Autoload: carries choices between the main menu and the game scene.

const SAVE_PATH := "res://review_save.json"

var start_mode := "new"   # "new" or "load"
var seed := 0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

