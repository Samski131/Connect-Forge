class_name BoardState
extends RefCounted

var board:Array = []
var settings:BoardSetting


func _init(new_settings:BoardSetting):
	settings = new_settings


func clear() -> void:
	board.clear()


func setup_empty_board() -> void:
	board.clear()
	
	var total_slots := settings.columns * settings.rows
	
	for i in range(total_slots):
		board.append(null)


func get_token(pos:Vector2i) -> Token:
	if is_position_in_bounds(pos) == false:
		return null
	
	var index := _index_from_pos(pos)
	
	if index < 0 or index >= board.size():
		return null
	
	return board[index]


func set_token(pos:Vector2i, token:Token) -> bool:
	if is_position_in_bounds(pos) == false:
		return false
	
	var index := _index_from_pos(pos)
	
	if index < 0 or index >= board.size():
		return false
	
	board[index] = token
	return true


func add_token(token:Token, pos:Vector2i) -> bool:
	if token == null:
		return false
	
	if is_position_in_bounds(pos) == false:
		return false
	
	if get_token(pos) != null:
		return false
	
	return set_token(pos, token)


func remove_token(pos:Vector2i) -> bool:
	if is_position_in_bounds(pos) == false:
		return false
	
	if get_token(pos) == null:
		return false
	
	return set_token(pos, null)


func replace_token(token:Token, pos:Vector2i) -> bool:
	if remove_token(pos) == false:
		return false
	
	return add_token(token, pos)


func is_position_in_bounds(pos:Vector2i) -> bool:
	return (
		pos.x >= 0 and
		pos.x < settings.columns and
		pos.y >= 0 and
		pos.y < settings.rows
	)


func is_position_empty(pos:Vector2i) -> bool:
	if is_position_in_bounds(pos) == false:
		return false
	
	return get_token(pos) == null


func _index_from_pos(pos:Vector2i) -> int:
	return pos.y * settings.columns + pos.x
