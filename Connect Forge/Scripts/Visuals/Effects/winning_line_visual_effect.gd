class_name WinningLineVisualEffect
extends BoardVisualEffect

var board:BoardManager = null
var winning_slots:Array[Vector2i] = []
var line_color:Color = Color.WHITE

var line_width:float = 26.0
var line_padding:float = 115.0
var shadow_width_multiplier:float = 1.65
var shadow_color:Color = Color(0.0, 0.0, 0.0, 0.45)
var line_z_index:int = 100

var _root:Node2D = null
var _shadow_line:Line2D = null
var _main_line:Line2D = null
var _start_point:Vector2 = Vector2.ZERO
var _end_point:Vector2 = Vector2.ZERO


func _init(new_board:BoardManager, new_winning_slots:Array[Vector2i], new_line_color:Color = Color.WHITE, new_duration:float = 0.5):
	board = new_board
	target = new_board
	line_color = new_line_color
	duration = new_duration
	
	winning_slots.clear()
	for slot in new_winning_slots:
		winning_slots.append(slot)


func _play_valid(runner:Node) -> void:
	if board == null:
		_finish()
		return
	
	if is_instance_valid(board) == false:
		_finish()
		return
	
	if winning_slots.size() < 2:
		_finish()
		return
	
	_clear_existing_winning_lines()
	
	var line_parent:Node2D = _get_line_parent()
	
	if line_parent == null:
		_finish()
		return
	
	_calculate_points(line_parent)
	_create_lines(line_parent)
	_set_draw_progress(0.0)
	
	if duration <= 0.0:
		_set_draw_progress(1.0)
		_finish()
		return
	
	var tween:Tween = runner.create_tween()
	tween.tween_method(_set_draw_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish)


func _get_line_parent() -> Node2D:
	if board.token_pool != null:
		if is_instance_valid(board.token_pool):
			return board.token_pool
	
	return board


func _calculate_points(line_parent:Node2D) -> void:
	var first_slot:Vector2i = winning_slots.front()
	var last_slot:Vector2i = winning_slots.back()
	
	var first_global:Vector2 = board.slot_to_global_position(first_slot)
	var last_global:Vector2 = board.slot_to_global_position(last_slot)
	
	var first_local:Vector2 = line_parent.to_local(first_global)
	var last_local:Vector2 = line_parent.to_local(last_global)
	
	var direction:Vector2 = last_local - first_local
	
	if direction.length() <= 0.001:
		_start_point = first_local
		_end_point = last_local
		return
	
	direction = direction.normalized()
	
	_start_point = first_local - direction * line_padding
	_end_point = last_local + direction * line_padding


func _create_lines(line_parent:Node2D) -> void:
	_root = Node2D.new()
	_root.name = "Winning Line Visual"
	_root.z_index = line_z_index
	_root.add_to_group("winning_line_visual")
	
	line_parent.add_child(_root)
	
	_shadow_line = _create_line(shadow_color, line_width * shadow_width_multiplier, line_z_index)
	_main_line = _create_line(line_color, line_width, line_z_index + 1)
	
	_root.add_child(_shadow_line)
	_root.add_child(_main_line)


func _create_line(used_color:Color, used_width:float, used_z_index:int) -> Line2D:
	var line:Line2D = Line2D.new()
	
	line.width = used_width
	line.default_color = used_color
	line.antialiased = true
	line.z_index = used_z_index
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = PackedVector2Array([_start_point, _start_point])
	
	return line


func _set_draw_progress(progress:float) -> void:
	var clamped_progress:float = clamp(progress, 0.0, 1.0)
	var current_end:Vector2 = _start_point.lerp(_end_point, clamped_progress)
	var points:PackedVector2Array = PackedVector2Array([_start_point, current_end])
	
	if _shadow_line != null and is_instance_valid(_shadow_line):
		_shadow_line.points = points
	
	if _main_line != null and is_instance_valid(_main_line):
		_main_line.points = points


func _clear_existing_winning_lines() -> void:
	if board == null:
		return
	
	var tree:SceneTree = board.get_tree()
	
	if tree == null:
		return
	
	tree.call_group("winning_line_visual", "queue_free")
