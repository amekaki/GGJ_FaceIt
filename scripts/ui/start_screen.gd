extends Control
## START 界面：按任意键开始游戏

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var hint_label: Label = $CenterContainer/VBoxContainer/HintLabel
@onready var _save: Node = get_node("/root/SaveManager")
@onready var _music_manager: Node = get_node("/root/MusicManager")

const SCENE_LOADING: String = "res://scenes/ui/loading_screen.tscn"

func _ready() -> void:
	# 设置标题文字
	title_label.text = "START"
	hint_label.text = "按任意键开始"
	# 开始播放开始音乐
	if _music_manager and _music_manager.has_method("play_start_music"):
		_music_manager.play_start_music()

func _input(event: InputEvent) -> void:
	# 检测任意按键或鼠标点击
	if event is InputEventKey and event.pressed:
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()

func _start_game() -> void:
	_save.save_level(1)
	get_tree().change_scene_to_file(SCENE_LOADING)
