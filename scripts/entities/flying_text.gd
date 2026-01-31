extends Area2D
## 飞行文字：ATTACKING 飞向主角，被弹反后 RETURNING 飞向敌人

enum State { ATTACKING, RETURNING }

@onready var label: Label = $Label
@onready var _config: Node = get_node("/root/GameConfig")

var _state: State = State.ATTACKING
var _word: String = ""
var _counter_word: String = ""
var _damage: int = 1
var _velocity: Vector2 = Vector2.ZERO
var _in_deflect_zone: bool = false
var spawn_wave_index: int = 0

signal deflected(flying_text: Area2D)
signal hit_enemy(flying_text: Area2D)
signal missed(flying_text: Area2D)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func init_attack(spawn_pos: Vector2, attack_word: String = "", counter_word: String = "", damage: int = 1, wave_index: int = 0) -> void:
	global_position = spawn_pos
	spawn_wave_index = wave_index
	_word = attack_word if attack_word.is_empty() == false else _config.get_random_attack_word()
	_counter_word = counter_word if counter_word.is_empty() == false else _config.get_counter_word_for(_word)
	_damage = damage
	label.text = _word
	_state = State.ATTACKING
	_velocity = Vector2(_config.TEXT_SPEED_ATTACK, 0)
	_in_deflect_zone = false

func get_damage() -> int:
	return _damage

func deflect() -> void:
	if _state != State.ATTACKING or not _in_deflect_zone:
		return
	_state = State.RETURNING
	label.text = _counter_word
	_velocity = Vector2(-_config.TEXT_SPEED_RETURN, 0)
	_in_deflect_zone = false
	deflected.emit(self)

func is_attacking() -> bool:
	return _state == State.ATTACKING

func is_returning() -> bool:
	return _state == State.RETURNING

func enter_deflect_zone() -> void:
	_in_deflect_zone = true

func exit_deflect_zone() -> void:
	_in_deflect_zone = false

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	var view_rect := get_viewport_rect()
	if _state == State.ATTACKING and global_position.x > view_rect.end.x + 50:
		missed.emit(self)
		queue_free()
	elif _state == State.RETURNING and global_position.x < view_rect.position.x - 50:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_deflect_zone") and _state == State.ATTACKING:
		enter_deflect_zone()
	elif _state == State.RETURNING and area.is_in_group("enemy_hitbox"):
		hit_enemy.emit(self)
		queue_free()

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("player_deflect_zone"):
		exit_deflect_zone()
