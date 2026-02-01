extends Node2D
## 敌人：左侧 AnimatedSprite2D、血量、被弹回文字命中时受伤与状态动画

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var _config: Node = get_node("/root/GameConfig")

var max_hp: int
var current_hp: int
var _skip_next_idle: bool = false

signal hp_changed(current: int, maximum: int)
signal died

const ANIM_IDLE := "IDEL"
const ANIM_ATTACK := "ATTACK"
const ANIM_DAMAGE := "DAMAGE"
const ANIM_HAPPY := "HAPPY"
const ANIM_DEAD := "DEAD"

func _ready() -> void:
	max_hp = _config.ENEMY_MAX_HP
	current_hp = max_hp
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	anim.animation_finished.connect(_on_anim_finished)
	hp_changed.emit(current_hp, max_hp)
	play_idle()

func take_damage(amount: int) -> void:
	# 如果已经死亡，不再处理伤害
	if current_hp <= 0:
		return
	current_hp = clampi(current_hp - amount, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		# 死亡时直接播放死亡动画，不播放受伤动画
		play_dead()
		died.emit()
	else:
		# 未死亡时播放受伤动画
		play_damage()

func play_idle() -> void:
	# 如果已经死亡，不再播放其他动画
	if current_hp <= 0:
		return
	if anim.sprite_frames.has_animation(ANIM_IDLE):
		anim.play(ANIM_IDLE)

func play_attack() -> void:
	# 如果已经死亡，不再播放其他动画
	if current_hp <= 0:
		return
	if anim.sprite_frames.has_animation(ANIM_ATTACK):
		anim.play(ANIM_ATTACK)

func play_damage() -> void:
	# 如果已经死亡，不再播放其他动画
	if current_hp <= 0:
		return
	if anim.sprite_frames.has_animation(ANIM_DAMAGE):
		anim.play(ANIM_DAMAGE)

func play_happy() -> void:
	# 如果已经死亡，不再播放其他动画
	if current_hp <= 0:
		return
	_skip_next_idle = true
	if anim.sprite_frames.has_animation(ANIM_HAPPY):
		anim.play(ANIM_HAPPY)

func play_dead() -> void:
	if anim.sprite_frames.has_animation(ANIM_DEAD):
		anim.play(ANIM_DEAD)
	elif anim.sprite_frames.has_animation(ANIM_DAMAGE):
		anim.play(ANIM_DAMAGE)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.has_method("is_returning") and area.is_returning() and area.has_method("get_damage"):
		take_damage(area.get_damage())

func _on_anim_finished() -> void:
	# 如果已经死亡，不再切换动画
	if current_hp <= 0:
		return
	if _skip_next_idle:
		_skip_next_idle = false
		return
	if anim.animation != ANIM_DEAD:
		play_idle()
