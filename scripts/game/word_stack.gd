extends Node2D
## 怪物蓄力后的文字堆叠显示，支持下落动画

const STACKED_WORD_SCENE := preload("res://scenes/stacked_word.tscn")

var _words: Array[String] = []
var _word_nodes: Array[Node2D] = []
var _enemy_ref: Node2D
var _row_spacing: float = 55.0
var _center_offset: Vector2 = Vector2(100, 0)
var _drop_tween: Tween

func setup(enemy: Node2D, words: Array) -> void:
	_enemy_ref = enemy
	_words.clear()
	for w in words:
		_words.append(str(w) if w is String else str(w))
	_rebuild_stack()

func _rebuild_stack() -> void:
	for n in _word_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_word_nodes.clear()
	if not _enemy_ref:
		return
	var center: Vector2 = _enemy_ref.global_position + _center_offset
	for i in range(_words.size()):
		var sw: Node2D = STACKED_WORD_SCENE.instantiate()
		add_child(sw)
		sw.set_word(_words[i])
		var row_offset: float = -i * _row_spacing
		sw.global_position = center + Vector2(0, row_offset)
		_word_nodes.append(sw)

func fire_first_and_drop_next(duration: float = 0.12) -> String:
	## 发射第一个字，下落第二个到中心，返回被发射的字
	if _words.is_empty():
		return ""
	var w: String = _words[0]
	_words.remove_at(0)
	if _word_nodes.size() > 0:
		var n: Node2D = _word_nodes[0]
		if is_instance_valid(n):
			n.queue_free()
		_word_nodes.remove_at(0)
	if _word_nodes.size() > 0 and _enemy_ref:
		var next_node: Node2D = _word_nodes[0]
		if is_instance_valid(next_node):
			var target: Vector2 = _enemy_ref.global_position + _center_offset
			if _drop_tween and _drop_tween.is_valid():
				_drop_tween.kill()
			_drop_tween = create_tween()
			_drop_tween.tween_property(next_node, "global_position", target, duration).set_ease(Tween.EASE_OUT)
	return w

func drop_word_to_center(index: int, duration: float = 0.12) -> void:
	if index < 0 or index >= _word_nodes.size() or not _enemy_ref:
		return
	var n: Node2D = _word_nodes[index]
	if not is_instance_valid(n):
		return
	var target: Vector2 = _enemy_ref.global_position + _center_offset
	if _drop_tween and _drop_tween.is_valid():
		_drop_tween.kill()
	_drop_tween = create_tween()
	_drop_tween.tween_property(n, "global_position", target, duration).set_ease(Tween.EASE_OUT)

func get_word_node_at(index: int) -> Node2D:
	if index < 0 or index >= _word_nodes.size():
		return null
	return _word_nodes[index]

func get_word_count() -> int:
	return _word_nodes.size()

func get_word_at(index: int) -> String:
	if index < 0 or index >= _words.size():
		return ""
	return _words[index]
