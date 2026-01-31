extends Node
## 游戏配置（Autoload）：文字表、伤害、速度等

const ATTACK_WORDS: Array[String] = [
	"恶意", "嘲讽", "否定", "贬低", "攻击", "伤害", "诅咒", "谩骂"
]
const COUNTER_WORDS: Array[String] = [
	"善意", "赞美", "肯定", "尊重", "守护", "治愈", "祝福", "礼貌"
]
const DEFLECT_DAMAGE: int = 25
const TEXT_SPEED_ATTACK: float = 400.0
const TEXT_SPEED_RETURN: float = 500.0
const ENEMY_MAX_HP: int = 100
const PLAYER_MAX_HP: int = 100
const DEFLECT_WINDOW_SEC: float = 0.35
const MAX_MISS_COUNT: int = 5
const LEVEL_CONFIG_PATH: String = "res://assets/level_config.json"
const TAP_SOUND_PATH: String = "res://assets/music/tap.wav"

static func get_random_attack_word() -> String:
	return ATTACK_WORDS[randi() % ATTACK_WORDS.size()]

static func get_counter_word_for(attack_word: String) -> String:
	var idx := ATTACK_WORDS.find(attack_word)
	if idx >= 0 and idx < COUNTER_WORDS.size():
		return COUNTER_WORDS[idx]
	return COUNTER_WORDS[randi() % COUNTER_WORDS.size()]
