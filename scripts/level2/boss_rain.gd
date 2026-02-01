extends AnimatedSprite2D

const SPEED = 60
const SPAWN_ANGLE_INTERVAL = 30.0 # 每隔多少度生成一个 rain
const RAIN_DISTANCE = 50.0 # rain 生成的距离

@onready var boss_rain: AnimatedSprite2D = $"."
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
const RAIN := preload("res://scenes/level2/rain.tscn")


var last_spawn_angle = 0.0
var attack_timer = 0.0
var ATTACK_INTERVAL = 6.0


func spawn_rain(rotation: float) -> void:
	var rain_instance: Node2D = RAIN.instantiate()

	rain_instance.rotation = rotation
	rain_instance.scale.x = 0.1
	rain_instance.scale.y = 0.1

	# 将 rain 添加到父节点（而不是 boss_rain 自己）
	get_parent().add_child(rain_instance)

func attack1() -> void:
	var current_angle = randf_range(0.0, 360.0)
	# 向12个方向发射rain，每个方向间隔30度
	for i in range(12):
		var angle_degrees = current_angle + 30.0 * i
		var angle_radians = deg_to_rad(angle_degrees)
		spawn_rain(angle_radians)

func attack2() -> void:
	# 从随机角度开始，向左右交替偏转发射，形成S型
	var last_angle = randf_range(0.0, 360.0) # 随机中心角度
	var spawn_delay = 0.3 # 每次发射的间隔时间（秒）

	spawn_rain(deg_to_rad(last_angle))
	await get_tree().create_timer(spawn_delay).timeout

	for i in range(5):
		last_angle = last_angle + 15.0
		var angle_radians = deg_to_rad(last_angle)
		spawn_rain(angle_radians)
		# 等待一小段时间再发射下一个
		await get_tree().create_timer(spawn_delay).timeout

	await get_tree().create_timer(spawn_delay).timeout

	for i in range(5):
		last_angle = last_angle - 15.0
		var angle_radians = deg_to_rad(last_angle)
		spawn_rain(angle_radians)
		# 等待一小段时间再发射下一个
		await get_tree().create_timer(spawn_delay).timeout

	await get_tree().create_timer(spawn_delay).timeout

	for i in range(5):
		last_angle = last_angle + 15.0
		var angle_radians = deg_to_rad(last_angle)
		spawn_rain(angle_radians)
		# 等待一小段时间再发射下一个
		await get_tree().create_timer(spawn_delay).timeout


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	last_spawn_angle = rotation_degrees
	if randi() % 2 == 0:
		attack1()
		ATTACK_INTERVAL = 4.0
	else:
		attack2()
		ATTACK_INTERVAL = 6.0
	pass


func _process(delta: float) -> void:
	# 每 6 s执行一次 attack
	attack_timer += delta
	if attack_timer >= ATTACK_INTERVAL:
		if randi() % 2 == 0:
			attack1()
			ATTACK_INTERVAL = 4.0
		else:
			attack2()
			ATTACK_INTERVAL = 6.0
		attack_timer = 0.0
