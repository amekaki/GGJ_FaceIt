extends Control
## 游戏结束界面：恭喜通关

@onready var btn_back: Button = $MarginContainer/VBoxContainer/BtnBack

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
