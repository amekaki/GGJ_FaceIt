extends Node2D
## Boss脚本：检测与player的碰撞，碰撞时加载level_2_ending_animation场景

@onready var area_2d: Area2D = $Area2D

const SCENE_LEVEL_2_ENDING: String = "res://scenes/ui/level_2_ending_animation.tscn"

func _ready() -> void:
	# 连接Area2D的body_entered信号
	if area_2d:
		area_2d.body_entered.connect(_on_body_entered)
		# 确保Area2D正在监控
		area_2d.monitoring = true
	else:
		print("警告：Boss脚本无法找到Area2D节点！")

func _on_body_entered(body: Node2D) -> void:
	# 检查进入的body是否是player（通过组名判断）
	if body.is_in_group("player"):
		print("Player与Boss碰撞！加载结束动画场景...")
		# 加载level_2_ending_animation场景
		get_tree().change_scene_to_file(SCENE_LEVEL_2_ENDING)
