extends CharacterBody2D

const SPEED = 350
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
#@onready var ray_cast_up: RayCast2D = $RayCastUp
#@onready var ray_cast_right: RayCast2D = $RayCastRight
#@onready var ray_cast_down: RayCast2D = $RayCastDown
#@onready var ray_cast_left: RayCast2D = $RayCastLeft


func _physics_process(delta: float) -> void:
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
	
	if isAxisY:
		animated_sprite.play("up")
	else:
		animated_sprite.play("right")
	
	
	if xDirection > 0:
		animated_sprite.flip_h = false
	elif xDirection < 0:
		animated_sprite.flip_h = true

	
	if xDirection:
		velocity.x = xDirection * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		

	
	
	if yDirection:
		velocity.y = yDirection * SPEED
	else:
		velocity.y = move_toward(velocity.y, 0, SPEED)

	move_and_slide()
