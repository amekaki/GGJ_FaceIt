extends Area2D
## 飞行文字：ATTACKING 飞向主角，被弹反后 RETURNING 飞向敌人
## 使用 _draw 绘制文字，避免 Control 子节点 scale/modulate 不生效

enum State { ATTACKING, RETURNING }

const FONT_PATH := "res://assets/fonts/像素字 像素字 Regular.ttf"
const FONT_SIZE := 60

@onready var _config: Node = get_node("/root/GameConfig")

var _state: State = State.ATTACKING
var _word: String = ""
var _counter_word: String = ""
var _damage: int = 1
var _velocity: Vector2 = Vector2.ZERO
var _in_deflect_zone: bool = false
var spawn_wave_index: int = 0
var _entrance_t: float = 1.0  ## 出场动画进度 0→1
var _deflect_t: float = 1.0   ## 弹反动效进度 0→1
var _font: Font

signal deflected(flying_text: Area2D)
signal hit_enemy(flying_text: Area2D)
signal missed(flying_text: Area2D)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_font = load(FONT_PATH) as Font
	$Label.visible = false  ## 用 _draw 绘制，隐藏 Label

func init_attack(spawn_pos: Vector2, attack_word: String = "", counter_word: String = "", damage: int = 1, wave_index: int = 0, custom_speed: float = -1.0) -> void:
	global_position = spawn_pos
	spawn_wave_index = wave_index
	_word = attack_word if attack_word.is_empty() == false else _config.get_random_attack_word()
	_counter_word = counter_word if counter_word.is_empty() == false else _config.get_counter_word_for(_word)
	_damage = damage
	_state = State.ATTACKING
	var speed: float = custom_speed if custom_speed > 0 else _config.TEXT_SPEED_ATTACK
	_velocity = Vector2(speed, 0)
	_in_deflect_zone = false
	_entrance_t = 0.0
	_deflect_t = 1.0
	scale = Vector2(0.5, 0.5)
	modulate = Color(1, 1, 1, 0)
	queue_redraw()

func get_damage() -> int:
	return _damage

func deflect() -> void:
	if _state != State.ATTACKING or not _in_deflect_zone:
		return
	_state = State.RETURNING
	_velocity = Vector2(-_config.TEXT_SPEED_RETURN, 0)
	_in_deflect_zone = false
	_deflect_t = 0.0
	scale = Vector2(1.2, 1.2)
	deflected.emit(self)

func is_attacking() -> bool:
	return _state == State.ATTACKING

func is_returning() -> bool:
	return _state == State.RETURNING

func enter_deflect_zone() -> void:
	_in_deflect_zone = true

func exit_deflect_zone() -> void:
	_in_deflect_zone = false

func _get_display_text() -> String:
	return _counter_word if _state == State.RETURNING else _word

func _ease_out_back(t: float) -> float:
	const c1: float = 1.70158
	const c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

func _draw() -> void:
	if _font == null:
		return
	var txt: String = _get_display_text()
	var ascent: float = _font.get_ascent(FONT_SIZE)
	var pos: Vector2 = Vector2(0, ascent * 0.5)
	draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE)

func _physics_process(delta: float) -> void:
	if _entrance_t < 1.0:
		_entrance_t = minf(_entrance_t + delta / 0.15, 1.0)
		var t: float = _ease_out_back(_entrance_t)
		scale = Vector2(0.5 + 0.5 * t, 0.5 + 0.5 * t)
		modulate = Color(1, 1, 1, t)
		if _entrance_t >= 1.0:
			scale = Vector2(1.0, 1.0)
			modulate = Color(1, 1, 1, 1)
	elif _deflect_t < 1.0:
		_deflect_t = minf(_deflect_t + delta / 0.1, 1.0)
		var t: float = _ease_out_back(_deflect_t)
		scale = Vector2(1.2 - 0.2 * t, 1.2 - 0.2 * t)
		if _deflect_t >= 1.0:
			scale = Vector2(1.0, 1.0)
	queue_redraw()
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
