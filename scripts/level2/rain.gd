extends Area2D
const SPEED = 60
const DAMAGE = 10  # rain 造成的伤害值

@onready var sprite: AnimatedSprite2D = $Rain
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 连接 Area2D 的信号
	body_entered.connect(_on_body_entered)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 根据 rain 的旋转角度向外移动
	var direction = Vector2(cos(rotation), sin(rotation))
	position += direction * SPEED * delta
	pass


func _on_body_entered(body: Node2D) -> void:
	# 检查碰撞的是否是 player
	if body.is_in_group("player") or body.name == "Player":
		print("检测到 Player!")
		animation_player.play("hurt")
		# 调用 player 的受伤方法
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE)
		
		# rain 碰撞后销毁自己
		#queue_free()
