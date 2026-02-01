extends Node
## 场景管理器：管理场景流程和切换

var next_scene: String = ""  # 加载完成后要进入的场景路径

func set_next_scene(scene_path: String) -> void:
	next_scene = scene_path

func get_next_scene() -> String:
	return next_scene

func clear_next_scene() -> void:
	next_scene = ""
