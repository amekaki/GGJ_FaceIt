extends CanvasLayer
## 关卡内通用弹窗：可配置标题与按钮文字，发出 pressed 信号

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var action_btn: Button = $CenterContainer/PanelContainer/VBoxContainer/ActionButton

signal pressed

func _ready() -> void:
	action_btn.pressed.connect(_on_action_pressed)

func set_title(text: String) -> void:
	title_label.text = text

func set_button_text(text: String) -> void:
	action_btn.text = text

func show_popup(title: String, button_text: String) -> void:
	set_title(title)
	set_button_text(button_text)
	show()

func _on_action_pressed() -> void:
	pressed.emit()
	hide()
