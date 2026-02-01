extends Control
## 加载游戏场景：右下角播放精灵图动画，播放完毕后根据SceneManager的设置进入相应场景

@onready var sprite: AnimatedSprite2D = $SpriteContainer/AnimatedSprite2D
@onready var _scene_manager: Node = get_node("/root/SceneManager")

const SCENE_OPENING: String = "res://scenes/ui/opening_animation.tscn"

func _ready() -> void:
	# 等待精灵图动画播放完毕
	if sprite and sprite.sprite_frames:
		sprite.animation_finished.connect(_on_animation_finished)
		# 播放动画（假设动画名为"default"或第一个动画）
		var anim_name: String = sprite.sprite_frames.get_animation_names()[0] if sprite.sprite_frames.get_animation_names().size() > 0 else "default"
		sprite.play(anim_name)
	else:
		# 如果没有动画，直接进入目标场景
		call_deferred("_go_to_target_scene")

func _on_animation_finished() -> void:
	_go_to_target_scene()

func _go_to_target_scene() -> void:
	# 获取SceneManager中设置的下一个场景
	var next_scene: String = _scene_manager.get_next_scene()
	if next_scene.is_empty():
		# 如果没有设置，默认进入开场动画（用于首次启动）
		next_scene = SCENE_OPENING
	_scene_manager.clear_next_scene()
	get_tree().change_scene_to_file(next_scene)
