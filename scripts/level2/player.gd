extends CharacterBody2D

const SPEED = 350
const MAX_HEALTH = 100

var health = MAX_HEALTH

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var light: AnimatedSprite2D = $light
#@onready var ray_cast_up: RayCast2D = $RayCastUp
#@onready var ray_cast_right: RayCast2D = $RayCastRight
#@onready var ray_cast_down: RayCast2D = $RayCastDown
#@onready var ray_cast_left: RayCast2D = $RayCastLeft


func _ready() -> void:
	# 将 player 添加到 "player" 组，方便识别
	add_to_group("player")


var fixPosition = false
var hurt = false

func _physics_process(delta: float) -> void:
	if hurt:
		return
	#if ray_cast_up.is_colliding():
		#return
	#if ray_cast_right.is_colliding():
		#return
	#if ray_cast_down.is_colliding():
		#return
	#if ray_cast_left.is_colliding():
		#return
	var xDirection := Input.get_axis("left", "right")
	var yDirection := Input.get_axis("up", "down")
	
	var isAxisY = abs(yDirection) > abs(xDirection)
	
	if xDirection != 0 or yDirection != 0:
		animated_sprite.play("right-2")
	else:
		animated_sprite.play("idle2")
	
	if xDirection > 0:
		animated_sprite.flip_h = true
		light.flip_h = true
		if fixPosition == true:
			fixPosition = false
			light.position.x = 8.0
			
	elif xDirection < 0:
		if fixPosition == false:
			fixPosition = true
			light.position.x = -8.0
			
		animated_sprite.flip_h = false
		light.flip_h = false
		

	
	if xDirection:
		velocity.x = xDirection * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		

	
	
	if yDirection:
		velocity.y = yDirection * SPEED
	else:
		velocity.y = move_toward(velocity.y, 0, SPEED)

	move_and_slide()


func take_damage(damage: int) -> void:
	hurt = true
	health -= damage
	
	animated_sprite.play("hurt")
	print("Player 受到伤害: ", damage, " | 剩余生命值: ", health)
	
	# 可以添加受伤动画或效果
	# animated_sprite.modulate = Color.RED
	await get_tree().create_timer(0.2).timeout
	# animated_sprite.modulate = Color.WHITE
	
	if health <= 0:
		die()
	hurt = false


func die() -> void:
	print("Player 死亡!")
	# 这里可以添加死亡逻辑，比如重新开始关卡
	# queue_free()
	# get_tree().reload_current_scene()
