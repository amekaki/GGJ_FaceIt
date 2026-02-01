extends Node
## 音乐管理器：管理开始音乐，在场景切换时保持播放

var start_music_player: AudioStreamPlayer
var start_music_path: String = "res://assets/music/开始.mp3"

func _ready() -> void:
	# 创建音乐播放器
	start_music_player = AudioStreamPlayer.new()
	start_music_player.name = "StartMusicPlayer"
	add_child(start_music_player)
	# 设置进程模式，确保场景切换时不被销毁
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_music_player.process_mode = Node.PROCESS_MODE_ALWAYS

func play_start_music() -> void:
	if not start_music_player:
		return
	# 如果已经在播放，不重复播放
	if start_music_player.playing:
		return
	# 加载音乐文件
	var stream: AudioStream = load(start_music_path) as AudioStream
	if not stream:
		push_error("Failed to load start music: " + start_music_path)
		return
	start_music_player.stream = stream
	# 设置循环播放
	if stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = stream as AudioStreamMP3
		mp3_stream.loop = true
	# 连接finished信号作为备用循环机制
	if not start_music_player.finished.is_connected(_on_start_music_finished):
		start_music_player.finished.connect(_on_start_music_finished)
	start_music_player.play()

func stop_start_music() -> void:
	if start_music_player and start_music_player.playing:
		start_music_player.stop()

func _on_start_music_finished() -> void:
	# 如果音乐播放完毕，重新播放（用于不支持loop的音频流）
	if start_music_player:
		start_music_player.play()
