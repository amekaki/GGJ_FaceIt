extends Control
## 关卡 2：暂为「通过本关」按钮，点击后进入第二关结尾动画

@onready var btn_pass: Button = $MarginContainer/VBoxContainer/BtnPass
@onready var exit_btn: Button = $ExitButton
@onready var _save: Node = get_node("/root/SaveManager")
const SCENE_LEVEL_2_ENDING: String = "res://scenes/ui/level_2_ending_animation.tscn"

func _ready() -> void:
	_save.save_level(2)
	btn_pass.pressed.connect(_on_pass_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_pass_pressed() -> void:
	# 进入第二关结尾动画
	get_tree().change_scene_to_file(SCENE_LEVEL_2_ENDING)
