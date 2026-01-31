class_name LevelBeatPattern
extends Resource
## 节奏配置：节拍序列、BPM、加速规则（关卡用）

@export var bpm: float = 120.0
@export var beats_per_spawn: PackedInt32Array = [1, 0, 1, 0, 1, 1, 0, 1]
@export var speed_up_after_beats: int = 8
@export var min_interval_ratio: float = 0.5

func get_beat_interval_at(beat_index: int) -> float:
	var base_interval := 60.0 / bpm
	var cycle_len := beats_per_spawn.size()
	if cycle_len == 0:
		return base_interval
	var rounds := beat_index / cycle_len
	var ratio := 1.0 - (rounds * (1.0 - min_interval_ratio) / 10.0)
	ratio = clampf(ratio, min_interval_ratio, 1.0)
	return base_interval * ratio

func should_spawn_at(beat_index: int) -> bool:
	var cycle_len := beats_per_spawn.size()
	if cycle_len == 0:
		return true
	return beats_per_spawn[beat_index % cycle_len] != 0
