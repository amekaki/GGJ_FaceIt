extends Node
## 关卡 1：节奏战玩法；通关弹窗「进入下一关」，失败弹窗「重新开始本关」；存档与多关流程

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
var miss_count: int = 0
var game_over: bool = false
var wave_deflected_hit: Dictionary = {}
var wave_missed_count: Dictionary = {}
var _shake_remaining: float = 0.0
const _shake_intensity: float = 8.0
const _shake_duration: float = 0.12

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
	miss_count = 0
	beat_index = 0
	current_wave_index = 0
	wave_start_beat = 0
	wave_deflected_hit.clear()
	wave_missed_count.clear()

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
	var view := get_viewport().get_visible_rect()
	var center_y := view.size.y * 0.5


func _get_attack_speed_for_beat_arrival(travel_beats: float = 10) -> float:
	## 根据生成点到击打位置的距离计算飞行速度，使文字在 travel_beats 节拍后到达击打区踩点
	var spawn_x: float = enemy.global_position.x + 50
	var deflect_zone: Node2D = player.get_node_or_null("DeflectZone")
	var target_x: float = deflect_zone.global_position.x if deflect_zone else player.global_position.x
	var distance: float = target_x - spawn_x
	if distance <= 0 or travel_beats <= 0:
		return _config.TEXT_SPEED_ATTACK
	var beat_interval: float = 60.0 / beat_bpm
	var travel_time: float = travel_beats * beat_interval
	return distance / travel_time

func _on_beat() -> void:
	if game_over:
		beat_timer.start(60.0 / beat_bpm)
		return
	if tap_sound and tap_sound.stream:
		tap_sound.play()
	var beat_in_wave := beat_index - wave_start_beat
	var travel_beats: float = 4.0  ## 文字飞行节拍数，到达击打区时踩点
	var speed: float = _get_attack_speed_for_beat_arrival(travel_beats)
	if current_wave_index < waves.size():
		var wave: Dictionary = waves[current_wave_index]
		var attack_words: Array = wave.get("attack_words", [])
		var counter_words: Array = wave.get("counterattack_words", [])
		var damage_arr: Array = wave.get("damage_value", [])
		var beat_config: Array = wave.get("beat_config", [])
		for i in range(beat_config.size()):
			if i >= attack_words.size():
				continue
			var target_beat: int = int(beat_config[i]) if beat_config[i] is int else int(beat_config[i])
			if beat_in_wave == target_beat:
				var attack_word: String = attack_words[i] if attack_words[i] is String else str(attack_words[i])
				var counter_word: String = counter_words[i] if i < counter_words.size() and counter_words[i] is String else attack_word
				var damage: int = int(damage_arr[i]) if i < damage_arr.size() else 1
				_spawn_flying_text(attack_word, counter_word, damage, speed)
				enemy.play_attack()
			
		var interval: int = int(wave.get("interval_time", 0))
		if beat_index == wave_start_beat + interval-1:
			wave_start_beat = beat_index+1
			current_wave_index += 1
		# 	## 下一波若 beat_config 含 0，需在过渡节拍立即生成（否则会跳过 beat 0）
		# 	if current_wave_index < waves.size():
		# 		var next_wave: Dictionary = waves[current_wave_index]
		# 		var next_words: Array = next_wave.get("attack_words", [])
		# 		var next_counter: Array = next_wave.get("counterattack_words", [])
		# 		var next_damage: Array = next_wave.get("damage_value", [])
		# 		var next_beat_cfg: Array = next_wave.get("beat_config", [])
		# 		for j in range(next_beat_cfg.size()):
		# 			if j >= next_words.size():
		# 				continue
		# 			if int(next_beat_cfg[j]) == 0:
		# 				var aw: String = next_words[j] if next_words[j] is String else str(next_words[j])
		# 				var cw: String = next_counter[j] if j < next_counter.size() and next_counter[j] is String else aw
		# 				var dmg: int = int(next_damage[j]) if j < next_damage.size() else 1
		# 				_spawn_flying_text(aw, cw, dmg, speed, current_wave_index)
		# 				enemy.play_attack()
	beat_index += 1
	beat_timer.start(60.0 / beat_bpm)

func _on_flying_text_deflected(_ft: Node) -> void:
	_shake_remaining = _shake_duration

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

func _array_max(arr: Array) -> int:
	var m: int = 0
	for x in arr:
		if x is int and x > m:
			m = x
		elif x is float and int(x) > m:
			m = int(x)
	return m

func _spawn_flying_text(attack_word: String, counter_word: String, damage: int, attack_speed: float = -1.0, wave_idx: int = -1) -> void:
	var wi: int = wave_idx if wave_idx >= 0 else current_wave_index
	var ft: Area2D = FLYING_TEXT_SCENE.instantiate()
	gameplay.add_child(ft)
	ft.init_attack(enemy.global_position + Vector2(50, 0), attack_word, counter_word, damage, wi, attack_speed)
	ft.missed.connect(_on_flying_text_missed)
	ft.hit_enemy.connect(_on_flying_text_hit_enemy)
	ft.deflected.connect(_on_flying_text_deflected)

func _on_flying_text_missed(ft: Area2D) -> void:
	if game_over:
		return
	var d: int = ft.get_damage() if ft.has_method("get_damage") else 1
	player.take_damage(d)
	var wi: int = ft.spawn_wave_index
	wave_missed_count[wi] = wave_missed_count.get(wi, 0) + 1
	var wave: Dictionary = waves[wi] if wi < waves.size() else {}
	var beat_config: Array = wave.get("beat_config", [])
	if beat_config.size() > 0 and wave_missed_count[wi] == beat_config.size():
		enemy.play_happy()
	# miss_count += 1
	# if miss_count >= _config.MAX_MISS_COUNT:
	# 	_finish_game(false)

func _on_flying_text_hit_enemy(ft: Node) -> void:
	if game_over:
		return
	var wi: int = ft.spawn_wave_index
	wave_deflected_hit[wi] = wave_deflected_hit.get(wi, 0) + 1
	var wave: Dictionary = waves[wi] if wi < waves.size() else {}
	var beat_config: Array = wave.get("beat_config", [])
	if beat_config.size() > 0 and wave_deflected_hit[wi] == beat_config.size():
		player.play_happy()

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
