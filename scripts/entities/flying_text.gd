extends Area2D
## 飞行文字：使用 RichTextLabel + SubViewport + Sprite2D，支持 BBCode 动效

enum State { ATTACKING, RETURNING, VANISH_PLAYER }

@onready var viewport: SubViewport = $SubViewport
@onready var rich_label: RichTextLabel = $SubViewport/RichTextLabel
@onready var sprite: Sprite2D = $Sprite2D
@onready var _config: Node = get_node("/root/GameConfig")

var _state: State = State.ATTACKING
var _word: String = ""
var _counter_word: String = ""
var _damage: int = 1
var _velocity: Vector2 = Vector2.ZERO
var _in_deflect_zone: bool = false
var spawn_wave_index: int = 0
var _entrance_t: float = 1.0
var _deflect_t: float = 1.0
var _anim_time: float = 0.0
var _impact_t: float = 0.0  ## 被玩家击中时的冲击效果时长
var _vanish_t: float = 0.0  ## 击中玩家时的消失效果时长

const TEXT_BOOM_SCENE := preload("res://scenes/levels/level_1/text_boom.tscn")

signal deflected(flying_text: Area2D)
signal hit_enemy(flying_text: Area2D)
signal missed(flying_text: Area2D)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	sprite.texture = viewport.get_texture()

func _format_attack_text(txt: String) -> String:
	## 怪物发射：大小变化(pulse，透明度变化弱) + 形状扭曲(tornado+shake)
	return "[center][pulse freq=2.0 color=#ffffffff][tornado radius=12 freq=1.5][shake rate=18 level=3]%s[/shake][/tornado][/pulse][/center]" % txt

func _format_return_text(txt: String) -> String:
	## 反弹文字：描边 + 轻微波浪
	return "[center][outline_size=4][outline_color=#1a5c3a][wave amp=5 freq=4]%s[/wave][/outline_color][/outline_size][/center]" % txt

func _format_impact_text(txt: String, color: String = "#ffffff") -> String:
	## 冲击时刻：很粗的描边
	return "[center][outline_size=14][outline_color=%s]%s[/outline_color][/outline_size][/center]" % [color, txt]

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
	rich_label.text = _format_attack_text(_word)
	scale = Vector2(0.4, 0.4)
	modulate = Color(1, 1, 1, 0)

func get_damage() -> int:
	return _damage

func deflect() -> void:
	if _state != State.ATTACKING or not _in_deflect_zone:
		return
	_state = State.RETURNING
	rich_label.text = _format_impact_text(_counter_word, "#ffdd44")
	var prev_speed: float = abs(_velocity.x)
	_velocity = Vector2(-prev_speed, 0)
	_in_deflect_zone = false
	_deflect_t = 0.0
	_anim_time = 0.0
	_impact_t = 0.18
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

func _ease_out_back(t: float) -> float:
	const c1: float = 1.70158
	const c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

func _impact_scale(base: float = 1.2, remaining: float = 0.18, duration: float = 0.18) -> Vector2:
	## 冲击时的大小震动
	var decay: float = remaining / duration if duration > 0 else 0.0
	var shake: float = 0.22 * sin(_anim_time * 50.0) * decay
	return Vector2(base + shake, base + shake * 0.9)

func _physics_process(delta: float) -> void:
	_anim_time += delta
	if _entrance_t < 1.0:
		_entrance_t = minf(_entrance_t + delta / 0.15, 1.0)
		var t: float = _ease_out_back(_entrance_t)
		scale = Vector2(0.4 + 0.6 * t, 0.4 + 0.6 * t)
		modulate = Color(1, 1, 1, t)
		if _entrance_t >= 1.0:
			scale = Vector2(1.0, 1.0)
			modulate = Color(1, 1, 1, 1)
	elif _state == State.VANISH_PLAYER:
		_vanish_t -= delta
		scale = _impact_scale(1.2, _vanish_t, 0.18)
		if _vanish_t <= 0:
			queue_free()
		return
	elif _state == State.ATTACKING:
		## 发射中：大小变化更明显 (0.82~1.18) + X/Y 不等比制造扭曲感
		var breath: float = 0.82 + 0.18 * (1.0 + sin(_anim_time * 4.0))
		var stretch: float = 1.0 + 0.08 * sin(_anim_time * 3.0)
		scale = Vector2(breath * stretch, breath / stretch)
	elif _impact_t > 0:
		_impact_t -= delta
		scale = _impact_scale(1.2, _impact_t, 0.18)
		if _impact_t <= 0:
			rich_label.text = _format_return_text(_counter_word)
			_deflect_t = 0.0
	elif _deflect_t < 1.0:
		_deflect_t = minf(_deflect_t + delta / 0.1, 1.0)
		var t: float = _ease_out_back(_deflect_t)
		scale = Vector2(1.15 - 0.15 * t, 1.15 - 0.15 * t)
		if _deflect_t >= 1.0:
			scale = Vector2(1.0, 1.0)
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
		_start_hit_enemy_effect()

func _start_hit_enemy_effect() -> void:
	var parent_node: Node = get_parent()
	if parent_node:
		var boom_inst: Node2D = TEXT_BOOM_SCENE.instantiate()
		parent_node.add_child(boom_inst)
		boom_inst.global_position = global_position
	hit_enemy.emit(self)
	queue_free()

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("player_deflect_zone"):
		if _state == State.ATTACKING:
			## 文字飞出击打区未被弹反，击中玩家
			_start_hit_player_effect()
		exit_deflect_zone()

func _start_hit_player_effect() -> void:
	_state = State.VANISH_PLAYER
	_velocity = Vector2.ZERO
	_vanish_t = 0.18
	_anim_time = 0.0
	rich_label.text = _format_impact_text(_word, "#ff4444")
	missed.emit(self)
