extends Node2D
## 堆叠显示的单字，用于怪物蓄力后的文字队列

@onready var label: Label = $Label

func set_word(txt: String) -> void:
	if label:
		label.text = txt
