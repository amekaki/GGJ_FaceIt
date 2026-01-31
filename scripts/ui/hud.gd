extends CanvasLayer
## HUD：敌人血条、玩家血条、退出游戏按钮（右下角）

@onready var enemy_hp_bar: ProgressBar = $MarginContainer/HPContainer/EnemyHPLabel/ProgressBar
@onready var player_hp_bar: ProgressBar = $MarginContainer/HPContainer/PlayerHPLabel/ProgressBar
@onready var enemy_hp_label: VBoxContainer = $MarginContainer/HPContainer/EnemyHPLabel
@onready var player_hp_label: VBoxContainer = $MarginContainer/HPContainer/PlayerHPLabel
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBoxContainer/ResultLabel
@onready var restart_btn: Button = $ResultPanel/VBoxContainer/RestartButton
@onready var exit_btn: Button = $ExitButton

const FLOATING_TEXT_SCENE := preload("res://scenes/ui/floating_text.tscn")
const FLOATING_TEXT_DURATION: float = 0.5

func _ready() -> void:
	result_panel.hide()
	restart_btn.pressed.connect(_on_restart_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

func bind_enemy(enemy: Node2D) -> void:
	if enemy.has_signal("hp_changed"):
		enemy.hp_changed.connect(_on_enemy_hp_changed)
		enemy_hp_bar.max_value = enemy.max_hp
		enemy_hp_bar.value = enemy.current_hp

func bind_player(player: Node2D) -> void:
	if player.has_signal("hp_changed"):
		player.hp_changed.connect(_on_player_hp_changed)
		player_hp_bar.max_value = player.max_hp
		player_hp_bar.value = player.current_hp

func _on_enemy_hp_changed(current: int, maximum: int) -> void:
	enemy_hp_bar.max_value = maximum
	enemy_hp_bar.value = current

func _on_player_hp_changed(current: int, maximum: int) -> void:
	player_hp_bar.max_value = maximum
	player_hp_bar.value = current

func show_damage_text(damage: int, is_enemy: bool) -> void:
	# 在进度条附近显示伤害值
	var bar: ProgressBar = enemy_hp_bar if is_enemy else player_hp_bar
	var bar_pos: Vector2 = bar.global_position
	# 进度条中心位置上方
	var text_pos: Vector2 = bar_pos + Vector2(bar.size.x / 2, -30)
	var ft: Node2D = FLOATING_TEXT_SCENE.instantiate()
	add_child(ft)
	ft.setup("-" + str(damage), text_pos, Color(1, 0.3, 0.3), 36, FLOATING_TEXT_DURATION)

func show_victory() -> void:
	result_label.text = "胜利！"
	result_panel.show()

func show_defeat() -> void:
	result_label.text = "失败"
	result_panel.show()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	get_tree().quit()
