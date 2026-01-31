extends Control
## 关卡 2：暂为「通过本关」按钮，点击后弹窗「游戏通关」→ 进入结束界面

@onready var btn_pass: Button = $MarginContainer/VBoxContainer/BtnPass
@onready var exit_btn: Button = $ExitButton
@onready var _save: Node = get_node("/root/SaveManager")
const POPUP_LEVEL_SCENE := preload("res://scenes/ui/popup_level.tscn")
const SCENE_END: String = "res://scenes/ui/end_screen.tscn"

func _ready() -> void:
	_save.save_level(2)
	btn_pass.pressed.connect(_on_pass_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_pass_pressed() -> void:
	var popup: CanvasLayer = POPUP_LEVEL_SCENE.instantiate()
	add_child(popup)
	popup.show_popup("游戏通关", "进入游戏结束界面")
	popup.pressed.connect(_go_to_end_screen)

func _go_to_end_screen() -> void:
	get_tree().change_scene_to_file(SCENE_END)
