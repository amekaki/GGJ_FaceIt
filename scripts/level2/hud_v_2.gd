extends CanvasLayer

@onready var progress_bar: ProgressBar = $MarginContainer/HPContainer/PlayerHPLabel/ProgressBar



func changeHP(data: int):
	progress_bar.value = data
