extends Node2D
## 主角：右侧 AnimatedSprite2D、弹反区、输入检测、血条与状态动画

@onready var deflect_zone: Area2D = $DeflectZone
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _config: Node = get_node("/root/GameConfig")

var max_hp: int
var current_hp: int
var _texts_in_zone: Array[Node] = []
var _skip_next_idle: bool = false

signal hp_changed(current: int, maximum: int)
signal died

const ANIM_IDLE := "IDEL"
const ANIM_ATTACK := "ATTACK"
const ANIM_DAMAGE := "DAMAGE"
const ANIM_HAPPY := "HAPPY"
const ANIM_DEAD := "DEAD"

func _ready() -> void:
	max_hp = _config.PLAYER_MAX_HP
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
	deflect_zone.area_entered.connect(_on_deflect_zone_area_entered)
	deflect_zone.area_exited.connect(_on_deflect_zone_area_exited)
	anim.animation_finished.connect(_on_anim_finished)
	play_idle()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("deflect"):
		return
	try_deflect()

func try_deflect() -> void:
	for node in _texts_in_zone:
		if not is_instance_valid(node):
			continue
		if node.has_method("deflect"):
			node.deflect()
			_texts_in_zone.clear()
			play_attack()
			return

func take_damage(amount: int) -> void:
	current_hp = clampi(current_hp - amount, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	play_damage()
	if current_hp <= 0:
		play_dead()
		died.emit()

func play_idle() -> void:
	if anim.sprite_frames.has_animation(ANIM_IDLE):
		anim.play(ANIM_IDLE)

func play_attack() -> void:
	if anim.sprite_frames.has_animation(ANIM_ATTACK):
		anim.play(ANIM_ATTACK)

func play_damage() -> void:
	if anim.sprite_frames.has_animation(ANIM_DAMAGE):
		anim.play(ANIM_DAMAGE)

func play_happy() -> void:
	_skip_next_idle = true
	if anim.sprite_frames.has_animation(ANIM_HAPPY):
		anim.play(ANIM_HAPPY)

func play_dead() -> void:
	if anim.sprite_frames.has_animation(ANIM_DEAD):
		anim.play(ANIM_DEAD)
	elif anim.sprite_frames.has_animation(ANIM_DAMAGE):
		anim.play(ANIM_DAMAGE)

func _on_deflect_zone_area_entered(area: Area2D) -> void:
	if area.has_method("is_attacking") and area.is_attacking():
		_texts_in_zone.append(area)

func _on_deflect_zone_area_exited(area: Area2D) -> void:
	_texts_in_zone.erase(area)

func _on_anim_finished() -> void:
	if _skip_next_idle:
		_skip_next_idle = false
		return
	if anim.animation != ANIM_DEAD:
		play_idle()
