extends Control
## 第二关结尾动画：显示多张图片，每张停留3秒，最后一张显示结束游戏按钮，带切入切出动画

@onready var image_container: Control = $ImageContainer
@onready var current_image: TextureRect = $ImageContainer/CurrentImage
@onready var next_image: TextureRect = $ImageContainer/NextImage
@onready var end_button: Button = $EndButton
@onready var text_label: Label = $TextLabel

# 图片路径配置（可以通过配置文件扩展）
var image_paths: Array[String] = [
	"res://assets/sprites/level_2/ending/1.png",
	"res://assets/sprites/level_2/ending/2.png",
	"res://assets/sprites/level_2/ending/3.png"
]
# 文字配置（与图片路径一一对应，如果为空字符串则不显示）
var text_configs: Array[String] = [
	"",
	"",
	""
]
var current_index: int = 0
var display_timer: Timer
var is_last_image: bool = false
var is_transitioning: bool = false
var transition_tween: Tween

const SCENE_END: String = "res://scenes/ui/end_screen.tscn"
const TRANSITION_DURATION: float = 0.5  # 切换动画持续时间

func _ready() -> void:
	end_button.pressed.connect(_on_end_pressed)
	end_button.visible = false
	end_button.modulate.a = 0.0
	# 初始化下一张图片为透明
	next_image.modulate.a = 0.0
	# 创建定时器用于自动切换
	display_timer = Timer.new()
	display_timer.wait_time = 3.0
	display_timer.one_shot = true
	display_timer.timeout.connect(_on_display_timer_timeout)
	add_child(display_timer)
	# 开始显示第一张图片（带淡入效果）
	_show_image_with_fade_in(0)

func _show_image_with_fade_in(index: int) -> void:
	if index >= image_paths.size():
		return
	var texture: Texture2D = load(image_paths[index]) as Texture2D
	if texture:
		current_image.texture = texture
		current_image.modulate.a = 0.0
		# 淡入动画
		if transition_tween:
			transition_tween.kill()
		transition_tween = create_tween()
		transition_tween.tween_property(current_image, "modulate:a", 1.0, TRANSITION_DURATION)
		# 检查是否是最后一张
		is_last_image = (index == image_paths.size() - 1)
		# 如果是最后一张，3秒后显示按钮
		if is_last_image:
			display_timer.wait_time = 3.0
			display_timer.start()
		else:
			# 否则3秒后切换到下一张
			display_timer.wait_time = 3.0
			display_timer.start()

func _transition_to_next() -> void:
	if is_transitioning or current_index >= image_paths.size() - 1:
		return
	is_transitioning = true
	current_index += 1
	var texture: Texture2D = load(image_paths[current_index]) as Texture2D
	if not texture:
		is_transitioning = false
		return
	# 将下一张图片设置到next_image
	next_image.texture = texture
	next_image.modulate.a = 0.0
	# 更新下一张图片的文字
	var next_text: String = ""
	if current_index < text_configs.size():
		next_text = text_configs[current_index]
	# 创建切换动画：当前图片淡出，下一张图片淡入
	if transition_tween:
		transition_tween.kill()
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	# 当前图片淡出
	transition_tween.tween_property(current_image, "modulate:a", 0.0, TRANSITION_DURATION)
	# 下一张图片淡入
	transition_tween.tween_property(next_image, "modulate:a", 1.0, TRANSITION_DURATION)
	# 文字淡出淡入
	if text_label:
		if next_text != "":
			text_label.text = next_text
			text_label.visible = true
			text_label.modulate.a = 0.0
			transition_tween.tween_property(text_label, "modulate:a", 1.0, TRANSITION_DURATION)
		else:
			transition_tween.tween_property(text_label, "modulate:a", 0.0, TRANSITION_DURATION)
			transition_tween.tween_callback(func(): text_label.visible = false).set_delay(TRANSITION_DURATION)
	# 动画完成后交换图片
	transition_tween.tween_callback(_swap_images).set_delay(TRANSITION_DURATION)

func _swap_images() -> void:
	# 交换current_image和next_image的内容
	var temp_texture = current_image.texture
	var temp_alpha = current_image.modulate.a
	current_image.texture = next_image.texture
	current_image.modulate.a = next_image.modulate.a
	next_image.texture = temp_texture
	next_image.modulate.a = 0.0
	is_transitioning = false
	# 检查是否是最后一张
	is_last_image = (current_index == image_paths.size() - 1)
	# 如果是最后一张，3秒后显示按钮
	if is_last_image:
		display_timer.wait_time = 3.0
		display_timer.start()
	else:
		# 否则3秒后切换到下一张
		display_timer.wait_time = 3.0
		display_timer.start()

func _on_display_timer_timeout() -> void:
	if is_last_image:
		# 最后一张图片，显示按钮（带淡入效果）
		end_button.modulate.a = 0.0
		end_button.visible = true
		if transition_tween:
			transition_tween.kill()
		transition_tween = create_tween()
		transition_tween.tween_property(end_button, "modulate:a", 1.0, TRANSITION_DURATION)
	else:
		# 切换到下一张图片
		_transition_to_next()

func _on_end_pressed() -> void:
	# 进入游戏结束界面
	get_tree().change_scene_to_file(SCENE_END)
