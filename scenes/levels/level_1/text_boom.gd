extends Node2D
## 文字击中敌人时的爆炸效果，boom 动画播放完毕后自动销毁

@onready var boom: AnimatedSprite2D = $boom

func _ready() -> void:
	if boom and boom.sprite_frames and boom.sprite_frames.has_animation("boom"):
		boom.animation_finished.connect(_on_boom_finished)
		boom.play("boom")
	else:
		queue_free()

func _on_boom_finished() -> void:
	queue_free()
