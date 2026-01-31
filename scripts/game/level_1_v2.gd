extends Node
## 关卡 1 V2：蓄力→堆叠文字→按节拍发射→击中爆炸，全中则反击句飞向怪物

@onready var gameplay: Node2D = $GamePlay
@onready var player: Node2D = $GamePlay/Player
@onready var enemy: Node2D = $GamePlay/Enemy
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Camera2D
@onready var beat_timer: Timer = $BeatTimer
@onready var tap_sound: AudioStreamPlayer = $TapSound
@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var wave_warning_label: Label = $WaveWarningLabel
@onready var _config: Node = get_node("/root/GameConfig")
@onready var _save: Node = get_node("/root/SaveManager")

var level_data: Dictionary = {}
var normal_waves: Array = []
var intermediate_waves: Array = []
var advanced_waves: Array = []
var intermediate_threshold: float = 0.5
var advanced_threshold: float = 0.8
var waves: Array = []  # 当前使用的wavelist
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
var _should_check_resolve_next_beat: bool = false
var _music_started: bool = false  # 标记背景音乐是否已启动
var _prev_player_hp: int = 100
var _prev_enemy_hp: int = 100

# 音调映射：do re mi fa sol la si 对应的pitch_scale值（基于C大调）
const PITCH_SCALES: Dictionary = {
	"do": 1.0,      # C
	"re": 1.122462048,  # D (2^(2/12))
	"mi": 1.259921049,  # E (2^(4/12))
	"fa": 1.334839854,  # F (2^(5/12))
	"sol": 1.498307077, # G (2^(7/12))
	"la": 1.681792831,  # A (2^(9/12))
	"si": 1.887748625,  # B (2^(11/12))
	# 高八度
	"do2": 2.0,
	"re2": 2.244924096,
	"mi2": 2.519842098,
	"fa2": 2.669679708,
	"sol2": 2.996614154,
	"la2": 3.363585662,
	"si2": 3.77549725,
	# 低八度
	"do0": 0.5,
	"re0": 0.561231024,
	"mi0": 0.629960525,
	"fa0": 0.667419927,
	"sol0": 0.749153539,
	"la0": 0.840896416,
	"si0": 0.943874313,
}

const FLYING_TEXT_SCENE := preload("res://scenes/flying_text.tscn")
const POPUP_LEVEL_SCENE := preload("res://scenes/ui/popup_level.tscn")
const SCENE_LEVEL_2: String = "res://scenes/levels/level_2.tscn"
const FLOATING_TEXT_SCENE := preload("res://scenes/ui/floating_text.tscn")

const FLOATING_TEXT_DURATION: float = 0.5  # 浮动文字持续时间（可配置）

func _ready() -> void:
	_save.save_level(1)
	_load_level()
	_apply_layout()
	hud.bind_enemy(enemy)
	hud.bind_player(player)
	enemy.died.connect(_on_enemy_died)
	enemy.hp_changed.connect(_on_enemy_hp_changed)
	player.died.connect(_on_player_died)
	player.hp_changed.connect(_on_player_hp_changed)
	beat_timer.timeout.connect(_on_beat)
	beat_timer.start(60.0 / beat_bpm)
	game_over = false
	beat_index = 0
	current_wave_index = 0
	wave_start_beat = 0
	_music_started = false
	_prev_player_hp = player.current_hp if player else 100
	_prev_enemy_hp = enemy.current_hp if enemy else 100
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
	intermediate_threshold = float(level_data.get("intermediate_threshold", 0.5))
	advanced_threshold = float(level_data.get("advanced_threshold", 0.8))
	normal_waves = level_data.get("normal_waves", [])
	intermediate_waves = level_data.get("intermediate_waves", [])
	advanced_waves = level_data.get("advanced_waves", [])
	_update_waves_by_hp()
	if waves.is_empty():
		push_warning("Level has no waves")

func _apply_layout() -> void:
	pass

func _start_background_music() -> void:
	if not background_music:
		return
	if not background_music.stream:
		return
	# 设置循环播放
	if background_music.stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = background_music.stream as AudioStreamMP3
		mp3_stream.loop = true
	# 连接finished信号作为备用循环机制
	if not background_music.finished.is_connected(_on_background_music_finished):
		background_music.finished.connect(_on_background_music_finished)
	background_music.play()

func _on_background_music_finished() -> void:
	# 如果音乐播放完毕，重新播放（用于不支持loop的音频流）
	if background_music and not game_over:
		background_music.play()

func _update_waves_by_hp() -> void:
	if not enemy:
		waves = normal_waves
		return
	var hp_ratio: float = float(enemy.current_hp) / float(enemy.max_hp) if enemy.max_hp > 0 else 1.0
	if hp_ratio <= advanced_threshold:
		waves = advanced_waves
		current_wave_index = 0
	elif hp_ratio <= intermediate_threshold:
		waves = intermediate_waves
		current_wave_index = 0
	else:
		waves = normal_waves
	# 如果当前wave_index超出范围，重置为0（循环读取）
	if current_wave_index >= waves.size() and waves.size() > 0:
		current_wave_index = 0

func _start_wave() -> void:
	_update_waves_by_hp()
	if waves.is_empty():
		return
	if current_wave_index >= waves.size():
		current_wave_index = 0
	var _wave: Dictionary = waves[current_wave_index]
	wave_start_beat = beat_index
	_phase = "CHARGING"
	_flying_count = 0
	_hit_count = 0
	_pending_counter_wave = {}
	_should_check_resolve_next_beat = false
	# 显示"下一波即将到达"提示
	if wave_warning_label:
		wave_warning_label.visible = true

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

func _get_counter_speed_from_positions(spawn_pos: Vector2, travel_beats: float = 4.0) -> float:
	# 从spawn_pos的中心到enemy的中心计算距离
	var target_pos: Vector2 = enemy.global_position
	var distance: float = spawn_pos.x - target_pos.x  # 从左到右的距离（spawn_pos在右，target_pos在左）
	if distance <= 0 or travel_beats <= 0:
		return _config.TEXT_SPEED_ATTACK
	var beat_interval: float = 60.0 / beat_bpm
	var travel_time: float = travel_beats * beat_interval
	return distance / travel_time

func _on_beat() -> void:
	# 第一次执行_on_beat时启动背景音乐
	if not _music_started:
		_start_background_music()
		_music_started = true
	if game_over:
		beat_timer.start(60.0 / beat_bpm)
		return
	# 根据当前血量更新wavelist（可能在战斗中血量变化导致阶段切换）
	_update_waves_by_hp()
	if _pending_counter_wave.size() > 0:
		# 生成反击文字时，使用当前wave的interval更新wave_start_beat
		var counter_wave: Dictionary = _pending_counter_wave
		var interval: int = int(counter_wave.get("interval_time", 4))
		wave_start_beat = wave_start_beat + interval
		_spawn_counter_sentence(counter_wave)
		_pending_counter_wave = {}
		_phase = "CHARGING"
		_advance_wave(true)
		beat_index += 1
		beat_timer.start(60.0 / beat_bpm)
		return
	if waves.is_empty() or current_wave_index >= waves.size():
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
		# 当attack_wait_time开始时，隐藏"下一波攻击即将到来"提示
		if beat_in_wave >= fire_start:
			_phase = "FIRING"
			# 隐藏"下一波攻击即将到来"提示
			if wave_warning_label:
				wave_warning_label.visible = false
			var spawn_pos: Vector2 = enemy.global_position + Vector2(WORD_STACK_OFFSET_X, 0)
			var speed: float = _get_attack_speed(spawn_pos, travel_beats)
			_try_fire_word(beat_after_wait, wave, speed)
	elif _phase == "WAITING":
		# 当attack_wait_time开始时，隐藏"下一波攻击即将到来"提示
		if beat_in_wave >= fire_start:
			_phase = "FIRING"
			# 隐藏"下一波攻击即将到来"提示
			if wave_warning_label:
				wave_warning_label.visible = false
			var spawn_pos: Vector2 = enemy.global_position + Vector2(WORD_STACK_OFFSET_X, 0)
			var speed: float = _get_attack_speed(spawn_pos, travel_beats)
			_try_fire_word(beat_after_wait, wave, speed)
	elif _phase == "FIRING":
		var spawn_pos: Vector2 = enemy.global_position + Vector2(WORD_STACK_OFFSET_X, 0)
		var speed: float = _get_attack_speed(spawn_pos, travel_beats)
		_try_fire_word(beat_after_wait, wave, speed)
		if _should_check_resolve_next_beat and _flying_count == 0:
			var beat_config: Array = wave.get("beat_config", [])
			var max_fire_beat: int = -1
			for b in beat_config:
				var vb: int = int(b) if b is int else int(float(b))
				if vb > max_fire_beat:
					max_fire_beat = vb
			if beat_after_wait > max_fire_beat:
				_should_check_resolve_next_beat = false
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

func _get_pitch_scale(pitch_name: String) -> float:
	# 将音调名称转换为pitch_scale值
	if pitch_name.is_empty():
		return 1.0
	var pitch_lower: String = pitch_name.to_lower().strip_edges()
	if PITCH_SCALES.has(pitch_lower):
		return PITCH_SCALES[pitch_lower]
	# 如果没有找到，返回默认值1.0
	return 1.0

func _try_fire_word(beat_from_ready: int, wave: Dictionary, speed: float) -> void:
	var beat_config: Array = wave.get("beat_config", [])
	var attack_words: Array = wave.get("attack_words", [])
	var pitch_config: Array = wave.get("pitch_config", [])  # 音调配置数组
	for i in range(beat_config.size()):
		var target_beat: int = int(beat_config[i]) if beat_config[i] is int else int(beat_config[i])
		if beat_from_ready == target_beat and i < attack_words.size():
			var word: String = str(attack_words[i])
			var spawn_pos: Vector2 = enemy.global_position + Vector2(WORD_STACK_OFFSET_X, 0)
			# 怪兽吐字时播放TapSound，根据配置设置音调
			if tap_sound and tap_sound.stream:
				# 获取当前字的音调配置
				var pitch_name: String = ""
				if i < pitch_config.size() and pitch_config[i] != null:
					pitch_name = str(pitch_config[i]).strip_edges()
				# 设置音调
				var pitch_scale: float = _get_pitch_scale(pitch_name)
				tap_sound.pitch_scale = pitch_scale
				tap_sound.play()
			if _word_stack and _word_stack.has_method("fire_first_and_drop_next"):
				var fired: String = _word_stack.fire_first_and_drop_next(0.12)
				if fired.is_empty():
					fired = word
				_spawn_flying_text(spawn_pos, fired, "", 1, speed, true, i)
				enemy.play_attack()
			else:
				_spawn_flying_text(spawn_pos, word, "", 1, speed, true, i)
				enemy.play_attack()
			break

func _check_resolve(wave: Dictionary) -> void:
	if _flying_count > 0:
		return
	var beat_config: Array = wave.get("beat_config", [])
	var total: int = beat_config.size()
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

func _advance_wave(_success: bool) -> void:
	# 根据当前血量更新wavelist
	_update_waves_by_hp()
	# 获取当前wave的interval（用于计算下一个wave的开始时间）
	var current_wave: Dictionary = waves[current_wave_index] if current_wave_index < waves.size() else {}
	var interval: int = int(current_wave.get("interval_time", 4))
	current_wave_index += 1
	# 如果超出范围，循环到第一个
	if current_wave_index >= waves.size() and waves.size() > 0:
		current_wave_index = 0
	# 如果wave_start_beat还没有被设置（比如在生成反击文字时已经设置过了），则使用当前beat_index加上当前wave的interval
	# 否则保持已经设置的值（在生成反击文字时设置的）
	if wave_start_beat <= beat_index:
		wave_start_beat = wave_start_beat + interval
	_phase = "CHARGING"
	_flying_count = 0
	_hit_count = 0
	# 显示"下一波即将到达"提示
	if wave_warning_label:
		wave_warning_label.visible = true

func _spawn_flying_text(spawn_pos: Vector2, attack_word: String, _counter_word: String, damage: int, attack_speed: float, deflect_explode: bool, word_idx: int = -1) -> void:
	var ft: Area2D = FLYING_TEXT_SCENE.instantiate()
	gameplay.add_child(ft)
	ft.init_attack(spawn_pos, attack_word, "", damage, current_wave_index, attack_speed, deflect_explode, word_idx)
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
	var deflect_zone: Node2D = player.get_node_or_null("DeflectZone")
	var spawn_pos: Vector2 = deflect_zone.global_position if deflect_zone else player.global_position
	spawn_pos += Vector2(-20, 0)
	# 使用实际的spawn_pos和enemy位置计算速度
	var speed: float = _get_counter_speed_from_positions(spawn_pos, travel_beats)
	var ft: Area2D = FLYING_TEXT_SCENE.instantiate()
	gameplay.add_child(ft)
	ft.init_counter_sentence(spawn_pos, sentence, dmg, speed)
	ft.hit_enemy.connect(_on_counter_sentence_hit_enemy)

func _on_flying_text_deflected(_ft: Node) -> void:
	# 玩家击打文字时播放TapSound，使用配置的音调
	if tap_sound and tap_sound.stream:
		var pitch_scale: float = 1.0
		# 直接访问word_index和spawn_wave_index属性（flying_text已定义这些属性）
		# 使用spawn_wave_index来获取对应的wave配置
		var wave_idx: int = _ft.spawn_wave_index
		if wave_idx < waves.size() and _ft.word_index >= 0:
			var wave: Dictionary = waves[wave_idx]
			var pitch_config: Array = wave.get("pitch_config", [])
			if _ft.word_index < pitch_config.size():
				var pitch_name: String = str(pitch_config[_ft.word_index])
				pitch_scale = _get_pitch_scale(pitch_name)
		tap_sound.pitch_scale = pitch_scale
		tap_sound.play()
	_shake_remaining = _shake_duration
	_hit_count += 1
	_flying_count -= 1
	if _flying_count == 0:
		_should_check_resolve_next_beat = true

func _on_flying_text_missed(ft: Node) -> void:
	if ft and ft.has_method("get_damage"):
		pass
	# 显示MISS文字（在玩家上方）
	_show_floating_text("MISS", player.global_position + Vector2(0, -80), Color(1, 0.2, 0.2))
	_flying_count -= 1
	if _flying_count == 0:
		_should_check_resolve_next_beat = true

func _on_flying_text_hit_enemy(_ft: Node) -> void:
	pass

func _on_counter_sentence_hit_enemy(_ft: Node) -> void:
	enemy.play_damage()
	# 显示GOOD文字（在敌人上方）
	_show_floating_text("GOOD！", enemy.global_position + Vector2(0, -80), Color(0.2, 1, 0.2))
	# 敌人受伤后，检查是否需要切换阶段
	_update_waves_by_hp()

func _on_player_hp_changed(current: int, maximum: int) -> void:
	# 计算伤害值
	var damage: int = _prev_player_hp - current
	_prev_player_hp = current
	if damage > 0:
		# 显示伤害值（在玩家进度条附近）
		hud.show_damage_text(damage, false)

func _on_enemy_hp_changed(current: int, maximum: int) -> void:
	# 计算伤害值
	var damage: int = _prev_enemy_hp - current
	_prev_enemy_hp = current
	if damage > 0:
		# 显示伤害值（在敌人进度条附近）
		hud.show_damage_text(damage, true)

func _show_floating_text(text: String, pos: Vector2, color: Color = Color.WHITE, font_size: int = 48) -> void:
	var ft: Node2D = FLOATING_TEXT_SCENE.instantiate()
	gameplay.add_child(ft)
	ft.setup(text, pos, color, font_size, FLOATING_TEXT_DURATION)

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
