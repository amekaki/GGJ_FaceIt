extends CharacterBody2D

const SPEED = 350
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
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
