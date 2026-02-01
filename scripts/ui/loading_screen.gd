extends Control
## 加载游戏场景：右下角播放精灵图动画，播放完毕后进入开场动画

@onready var sprite: AnimatedSprite2D = $SpriteContainer/AnimatedSprite2D

const SCENE_OPENING: String = "res://scenes/ui/opening_animation.tscn"

func _ready() -> void:
	# 等待精灵图动画播放完毕
	if sprite and sprite.sprite_frames:
		sprite.animation_finished.connect(_on_animation_finished)
		# 播放动画（假设动画名为"default"或第一个动画）
		var anim_name: String = sprite.sprite_frames.get_animation_names()[0] if sprite.sprite_frames.get_animation_names().size() > 0 else "default"
		sprite.play(anim_name)
	else:
		# 如果没有动画，直接进入开场动画
		call_deferred("_go_to_opening")

func _on_animation_finished() -> void:
	_go_to_opening()

func _go_to_opening() -> void:
	get_tree().change_scene_to_file(SCENE_OPENING)
