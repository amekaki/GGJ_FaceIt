extends Control
## 第二关开场动画：支持多张图片，左右箭头切换，最后一张有开始游戏按钮

@onready var image_container: Control = $ImageContainer
@onready var current_image: TextureRect = $ImageContainer/CurrentImage
@onready var left_arrow: Button = $LeftArrow
@onready var right_arrow: Button = $RightArrow
@onready var start_button: Button = $StartButton
@onready var text_label: Label = $TextLabel

# 图片路径配置（可以通过配置文件扩展）
var image_paths: Array[String] = [
	"res://assets/sprites/start/opening/1.png",
	"res://assets/sprites/start/opening/2.png",
	"res://assets/sprites/start/opening/3.png"
]
# 文字配置（与图片路径一一对应，如果为空字符串则不显示）
var text_configs: Array[String] = [
	"",
	"",
	""
]
var current_index: int = 0

const SCENE_LEVEL_2: String = "res://scenes/levels/level_2.tscn"
const SCENE_LOADING: String = "res://scenes/ui/loading_screen.tscn"

@onready var _scene_manager: Node = get_node("/root/SceneManager")

func _ready() -> void:
	left_arrow.pressed.connect(_on_left_arrow_pressed)
	right_arrow.pressed.connect(_on_right_arrow_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_update_display()

func _update_display() -> void:
	# 更新当前图片
	if current_index < image_paths.size():
		var texture: Texture2D = load(image_paths[current_index]) as Texture2D
		if texture:
			current_image.texture = texture
	
	# 更新文字显示
	if text_label:
		if current_index < text_configs.size() and text_configs[current_index] != "":
			text_label.text = text_configs[current_index]
			text_label.visible = true
		else:
			text_label.visible = false
	
	# 更新箭头显示
	left_arrow.visible = current_index > 0
	right_arrow.visible = current_index < image_paths.size() - 1
	
	# 更新开始按钮显示（只在最后一张显示）
	start_button.visible = current_index == image_paths.size() - 1

func _on_left_arrow_pressed() -> void:
	if current_index > 0:
		current_index -= 1
		_update_display()

func _on_right_arrow_pressed() -> void:
	if current_index < image_paths.size() - 1:
		current_index += 1
		_update_display()

func _on_start_pressed() -> void:
	# 设置加载完成后进入第二关
	_scene_manager.set_next_scene(SCENE_LEVEL_2)
	# 进入加载场景
	get_tree().change_scene_to_file(SCENE_LOADING)
