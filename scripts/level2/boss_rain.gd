extends AnimatedSprite2D

const SPEED = 60
const SPAWN_ANGLE_INTERVAL = 30.0  # 每隔多少度生成一个 rain
const RAIN_DISTANCE = 50.0  # rain 生成的距离

@onready var boss_rain: AnimatedSprite2D = $"."
const RAIN := preload("res://scenes/level2/rain.tscn")

var last_spawn_angle = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	last_spawn_angle = rotation_degrees
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 检查旋转角度是否超过了生成间隔
	var current_angle = rotation_degrees
	var angle_diff = abs(current_angle - last_spawn_angle)
	
	# 处理角度跨越 360 度的情况
	if angle_diff > 180:
		angle_diff = 360 - angle_diff
	
	if angle_diff >= SPAWN_ANGLE_INTERVAL:
		spawn_rain()
		last_spawn_angle = current_angle


func spawn_rain() -> void:
	var rain_instance: Node2D = RAIN.instantiate()
	
	rain_instance.rotation = rotation
	rain_instance.scale.x = 0.1
	rain_instance.scale.y = 0.1
	
	# 将 rain 添加到父节点（而不是 boss_rain 自己）
	get_parent().add_child(rain_instance)
	
