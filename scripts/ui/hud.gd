extends CanvasLayer
## HUD：敌人血条、玩家血条、退出游戏按钮（右下角）

@onready var enemy_hp_bar: ProgressBar = $MarginContainer/VBoxContainer/EnemyHPLabel/ProgressBar
@onready var player_hp_bar: ProgressBar = $MarginContainer/VBoxContainer/PlayerHPLabel/ProgressBar
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBoxContainer/ResultLabel
@onready var restart_btn: Button = $ResultPanel/VBoxContainer/RestartButton
@onready var exit_btn: Button = $ExitButton

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
