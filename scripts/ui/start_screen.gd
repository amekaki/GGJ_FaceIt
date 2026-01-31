extends Control
## START 界面：开始游戏、加载游戏、退出游戏

@onready var btn_start: Button = $MarginContainer/VBoxContainer/BtnStart
@onready var btn_load: Button = $MarginContainer/VBoxContainer/BtnLoad
@onready var btn_quit: Button = $MarginContainer/VBoxContainer/BtnQuit
@onready var _save: Node = get_node("/root/SaveManager")

const SCENE_LEVEL_1: String = "res://scenes/levels/level_1.tscn"
const SCENE_LEVEL_2: String = "res://scenes/levels/level_2.tscn"

func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	_save.save_level(1)
	get_tree().change_scene_to_file(SCENE_LEVEL_1)

func _on_load_pressed() -> void:
	var level: int = _save.get_saved_level()
	if level <= 1:
		get_tree().change_scene_to_file(SCENE_LEVEL_1)
	else:
		get_tree().change_scene_to_file(SCENE_LEVEL_2)

func _on_quit_pressed() -> void:
	get_tree().quit()
