extends Node2D
## 浮动文字效果：向上淡出

@onready var label: Label = $Label

var duration: float = 0.5
var move_distance: float = 100.0
var _elapsed: float = 0.0
var _start_pos: Vector2

func _ready() -> void:
	_start_pos = global_position
	if label:
		label.modulate.a = 1.0

func setup(text: String, pos: Vector2, color: Color = Color.WHITE, font_size: int = 48, dur: float = 0.5, use_custom_font: bool = false) -> void:
	global_position = pos
	_start_pos = pos
	duration = dur
	if label:
		label.text = text
		label.add_theme_font_size_override("font_size", font_size)
		label.modulate.a = 1.0
		# 如果使用自定义字体和样式
		if use_custom_font:
			# 设置文字颜色（红色）和白色描边
			label.add_theme_color_override("font_color", color)
			label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))
			label.add_theme_constant_override("outline_size", 4)
		else:
			# 使用modulate来设置颜色（保持向后兼容）
			label.modulate = color

func _process(delta: float) -> void:
	if not label:
		return
	_elapsed += delta
	var progress: float = _elapsed / duration if duration > 0 else 1.0
	
	if progress >= 1.0:
		queue_free()
		return
	
	# 向上移动
	global_position = _start_pos + Vector2(0, -move_distance * progress)
	# 淡出
	label.modulate.a = 1.0 - progress
