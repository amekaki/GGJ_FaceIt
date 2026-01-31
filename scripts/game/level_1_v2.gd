extends Node
## 关卡 1 V2：蓄力→堆叠文字→按节拍发射→击中爆炸，全中则反击句飞向怪物

@onready var gameplay: Node2D = $GamePlay
@onready var player: Node2D = $GamePlay/Player
@onready var enemy: Node2D = $GamePlay/Enemy
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Camera2D
@onready var beat_timer: Timer = $BeatTimer
@onready var tap_sound: AudioStreamPlayer = $TapSound
@onready var _config: Node = get_node("/root/GameConfig")
@onready var _save: Node = get_node("/root/SaveManager")

var level_data: Dictionary = {}
var waves: Array = []
var beat_bpm: float = 120.0
var beat_index: int = 0
var current_wave_index: int = 0
var wave_start_beat: int = 0
var game_over: bool = false
var _shake_remaining: float = 0.0
const _shake_intensity: float = 8.0
const _shake_duration: float = 0.12

var _word_stack: Node2D
var _phase: String = "CHARGING"  ## CHARGING | WAITING | FIRING | RESOLVING | COUNTER

const WORD_STACK_OFFSET_X: float = 100.0
var _flying_count: int = 0
var _hit_count: int = 0
var _pending_counter_wave: Dictionary = {}

const FLYING_TEXT_SCENE := preload("res://scenes/flying_text.tscn")
const POPUP_LEVEL_SCENE := preload("res://scenes/ui/popup_level.tscn")
const SCENE_LEVEL_2: String = "res://scenes/levels/level_2.tscn"

func _ready() -> void:
	_save.save_level(1)
	_load_level()
	_apply_layout()
	hud.bind_enemy(enemy)
	hud.bind_player(player)
	enemy.died.connect(_on_enemy_died)
	player.died.connect(_on_player_died)
	beat_timer.timeout.connect(_on_beat)
	beat_timer.start(60.0 / beat_bpm)
	game_over = false
	beat_index = 0
	current_wave_index = 0
	wave_start_beat = 0
	_start_wave()

func _load_level() -> void:
	var path: String = _config.LEVEL_CONFIG_PATH
	if not FileAccess.file_exists(path):
		push_error("Level config not found: " + path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var json_text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_text)
	if parsed == null:
		push_error("Invalid JSON: " + path)
		return
	level_data = parsed
	beat_bpm = float(level_data.get("beat_bpm", 120))
	waves = level_data.get("waves", [])
	if waves.is_empty():
		push_warning("Level has no waves")

func _apply_layout() -> void:
	pass

func _start_wave() -> void:
	if current_wave_index >= waves.size():
		_finish_game(true)
		return
	var _wave: Dictionary = waves[current_wave_index]
	wave_start_beat = beat_index
	_phase = "CHARGING"
	_flying_count = 0
	_hit_count = 0
	_pending_counter_wave = {}

func _get_attack_speed(spawn_pos: Vector2, travel_beats: float) -> float:
	var target_pos: Vector2 = player.global_position
	var distance: float = target_pos.x - spawn_pos.x
	if distance <= 0 or travel_beats <= 0:
		return _config.TEXT_SPEED_ATTACK
	var beat_interval: float = 60.0 / beat_bpm
	var travel_time: float = travel_beats * beat_interval
	return distance / travel_time

func _get_counter_speed(travel_beats: float = 4.0) -> float:
	var deflect_zone: Node2D = player.get_node_or_null("DeflectZone")
	var spawn_x: float = deflect_zone.global_position.x if deflect_zone else player.global_position.x
	var target_x: float = enemy.global_position.x
	var distance: float = target_x - spawn_x
	if distance <= 0 or travel_beats <= 0:
		return _config.TEXT_SPEED_ATTACK
	var beat_interval: float = 60.0 / beat_bpm
	return abs(distance) / (travel_beats * beat_interval)

func _on_beat() -> void:
	if game_over:
		beat_timer.start(60.0 / beat_bpm)
		return
	if tap_sound and tap_sound.stream:
		tap_sound.play()
	if _pending_counter_wave.size() > 0:
		_spawn_counter_sentence(_pending_counter_wave)
		_pending_counter_wave = {}
		_phase = "CHARGING"
		_advance_wave(true)
		beat_index += 1
		beat_timer.start(60.0 / beat_bpm)
		return
	if current_wave_index >= waves.size():
		beat_index += 1
		beat_timer.start(60.0 / beat_bpm)
		return
	var wave: Dictionary = waves[current_wave_index]
	if beat_index < wave_start_beat:
		beat_index += 1
		beat_timer.start(60.0 / beat_bpm)
		return
	var get_ready: int = int(wave.get("get_ready_time", 4))
	var wait_time: int = int(wave.get("attack_wait_time", 2))
	var travel_beats: float = float(wave.get("travel_beats", 4))
	var fire_start: int = get_ready + wait_time
	var beat_in_wave: int = beat_index - wave_start_beat
	var beat_after_wait: int = beat_in_wave - fire_start

	if _phase == "CHARGING":
		if beat_in_wave >= get_ready:
			_phase = "WAITING"
			_spawn_word_stack(wave)
			enemy.play_attack()
		if beat_in_wave >= fire_start:
			_phase = "FIRING"
			var spawn_pos: Vector2 = enemy.global_position + Vector2(WORD_STACK_OFFSET_X, 0)
			var speed: float = _get_attack_speed(spawn_pos, travel_beats)
			_try_fire_word(beat_after_wait, wave, speed)
	elif _phase == "WAITING":
		if beat_in_wave >= fire_start:
			_phase = "FIRING"
			var spawn_pos: Vector2 = enemy.global_position + Vector2(WORD_STACK_OFFSET_X, 0)
			var speed: float = _get_attack_speed(spawn_pos, travel_beats)
			_try_fire_word(beat_after_wait, wave, speed)
	elif _phase == "FIRING":
		var spawn_pos: Vector2 = enemy.global_position + Vector2(WORD_STACK_OFFSET_X, 0)
		var speed: float = _get_attack_speed(spawn_pos, travel_beats)
		_try_fire_word(beat_after_wait, wave, speed)
		# _check_resolve(wave)
	elif _phase == "RESOLVING":
		_check_resolve(wave)

	beat_index += 1
	beat_timer.start(60.0 / beat_bpm)

func _spawn_word_stack(wave: Dictionary) -> void:
	var attack_words: Array = wave.get("attack_words", [])
	if attack_words.is_empty():
		return
	if _word_stack and is_instance_valid(_word_stack):
		_word_stack.queue_free()
	var stack_scene: PackedScene = preload("res://scenes/levels/level_1/word_stack.tscn") as PackedScene
	if stack_scene:
		_word_stack = stack_scene.instantiate()
		gameplay.add_child(_word_stack)
		_word_stack.setup(enemy, attack_words)

func _try_fire_word(beat_from_ready: int, wave: Dictionary, speed: float) -> void:
	var beat_config: Array = wave.get("beat_config", [])
	var attack_words: Array = wave.get("attack_words", [])
	for i in range(beat_config.size()):
		var target_beat: int = int(beat_config[i]) if beat_config[i] is int else int(beat_config[i])
		if beat_from_ready == target_beat and i < attack_words.size():
			var word: String = str(attack_words[i])
			var spawn_pos: Vector2 = enemy.global_position + Vector2(WORD_STACK_OFFSET_X, 0)
			if _word_stack and _word_stack.has_method("fire_first_and_drop_next"):
				var fired: String = _word_stack.fire_first_and_drop_next(0.12)
				if fired.is_empty():
					fired = word
				_spawn_flying_text(spawn_pos, fired, "", 1, speed, true)
				enemy.play_attack()
			else:
				_spawn_flying_text(spawn_pos, word, "", 1, speed, true)
				enemy.play_attack()
			break

func _check_resolve(wave: Dictionary) -> void:
	if _flying_count > 0:
		return
	var get_ready: int = int(wave.get("get_ready_time", 4))
	var wait_time: int = int(wave.get("attack_wait_time", 2))
	var fire_start: int = get_ready + wait_time
	var beat_after_wait: int = beat_index - wave_start_beat - fire_start
	var beat_config: Array = wave.get("beat_config", [])
	var max_fire_beat: int = -1
	for b in beat_config:
		var vb: int = int(b) if b is int else int(float(b))
		if vb > max_fire_beat:
			max_fire_beat = vb
	if beat_after_wait <= max_fire_beat:
		return
	var total: int = beat_config.size()
	print("total: ", total, " _hit_count: ", _hit_count)
	if _hit_count >= total:
		_phase = "COUNTER"
		_pending_counter_wave = wave
		player.play_happy()
	else:
		var damage_arr: Array = wave.get("damage_value", [])
		var total_dmg: int = 0
		for i in range(total):
			total_dmg += int(damage_arr[i]) if i < damage_arr.size() else 1
		player.take_damage(total_dmg)
		_phase = "CHARGING"
		_advance_wave(false)

func _advance_wave(success: bool) -> void:
	var wave: Dictionary = waves[current_wave_index] if current_wave_index < waves.size() else {}
	var interval: int = int(wave.get("interval_time", 4))
	current_wave_index += 1
	wave_start_beat = beat_index + interval
	if current_wave_index >= waves.size():
		_finish_game(success)
	else:
		_phase = "CHARGING"
		_flying_count = 0
		_hit_count = 0

func _spawn_flying_text(spawn_pos: Vector2, attack_word: String, _counter_word: String, damage: int, attack_speed: float, deflect_explode: bool) -> void:
	var ft: Area2D = FLYING_TEXT_SCENE.instantiate()
	gameplay.add_child(ft)
	ft.init_attack(spawn_pos, attack_word, "", damage, current_wave_index, attack_speed, deflect_explode)
	ft.missed.connect(_on_flying_text_missed)
	ft.hit_enemy.connect(_on_flying_text_hit_enemy)
	ft.deflected.connect(_on_flying_text_deflected)
	_flying_count += 1

func _spawn_counter_sentence(wave: Dictionary) -> void:
	if wave.is_empty():
		return
	var sentence: String = str(wave.get("attack_sentence", "反击！"))
	if sentence.is_empty():
		sentence = "反击！"
	var dmg: int = int(wave.get("sentence_damage_value", 16))
	var travel_beats: float = 4.0
	var speed: float = _get_counter_speed(travel_beats)
	var deflect_zone: Node2D = player.get_node_or_null("DeflectZone")
	var spawn_pos: Vector2 = deflect_zone.global_position if deflect_zone else player.global_position
	spawn_pos += Vector2(-20, 0)
	var ft: Area2D = FLYING_TEXT_SCENE.instantiate()
	gameplay.add_child(ft)
	ft.init_counter_sentence(spawn_pos, sentence, dmg, speed)
	ft.hit_enemy.connect(_on_counter_sentence_hit_enemy)

func _on_flying_text_deflected(_ft: Node) -> void:
	_shake_remaining = _shake_duration
	_hit_count += 1
	_flying_count -= 1

func _on_flying_text_missed(ft: Node) -> void:
	if ft and ft.has_method("get_damage"):
		pass
	_flying_count -= 1

func _on_flying_text_hit_enemy(_ft: Node) -> void:
	pass

func _on_counter_sentence_hit_enemy(_ft: Node) -> void:
	enemy.play_damage()

func _process(delta: float) -> void:
	if _shake_remaining > 0 and camera:
		_shake_remaining -= delta
		var decay: float = _shake_remaining / _shake_duration
		camera.offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity) * decay,
			randf_range(-_shake_intensity, _shake_intensity) * decay
		)
		if _shake_remaining <= 0:
			camera.offset = Vector2.ZERO

func _on_enemy_died() -> void:
	_finish_game(true)

func _on_player_died() -> void:
	_finish_game(false)

func _finish_game(victory: bool) -> void:
	game_over = true
	beat_timer.stop()
	var popup: CanvasLayer = POPUP_LEVEL_SCENE.instantiate()
	add_child(popup)
	if victory:
		popup.show_popup("胜利", "进入下一关")
		popup.pressed.connect(_go_next_level)
	else:
		popup.show_popup("失败", "重新开始本关")
		popup.pressed.connect(_restart_level)

func _go_next_level() -> void:
	_save.save_level(2)
	get_tree().change_scene_to_file(SCENE_LEVEL_2)

func _restart_level() -> void:
	get_tree().reload_current_scene()
