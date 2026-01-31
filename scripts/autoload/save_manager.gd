extends Node
## 存档管理（Autoload）：当前关卡索引，供 START 界面「加载游戏」使用

const SAVE_PATH: String = "user://save.dat"
const KEY_LEVEL: String = "level"

func save_level(level: int) -> void:
	var data: Dictionary = { KEY_LEVEL: level }
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func get_saved_level() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 1
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return 1
	var data = file.get_var()
	file.close()
	if data is Dictionary and data.has(KEY_LEVEL):
		return int(data[KEY_LEVEL])
	return 1
