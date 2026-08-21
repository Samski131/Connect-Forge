class_name BotSimulationTokenMover
extends BoardTokenMover

var pending_destroyed_tokens:Array[Token] = []


func _init(new_board:BoardManager):
	super(new_board)


func create_new_token(token_scene:PackedScene, slot_pos:Vector2i, player_id:int, start_flipped:bool = false) -> Token:
	if token_scene == null:
		return null
	
	if board == null:
		return null
	
	if board.is_position_in_bounds(slot_pos) == false:
		return null
	
	if board.get_token(slot_pos) != null:
		return null
	
	if board.token_pool == null:
		return null
	
	var new_node:Node = token_scene.instantiate()
	
	if new_node == null:
		return null
	
	var new_token:Token = new_node as Token
	
	if new_token == null:
		new_node.free()
		return null
	
	new_token.visible = false
	board.token_pool.add_child(new_token)
	
	new_token.setup(board, slot_pos, player_id)
	
	if new_token.has_method("set_flipped"):
		new_token.set_flipped(start_flipped)
	else:
		new_token.is_flipped = start_flipped
	
	if board.add_token_to_board(new_token, slot_pos) == false:
		new_token.free()
		return null
	
	new_token.replay_token_id = -1
	new_token.visible = false
	
	return new_token


func destroy_tokens(tokens:Array[Token], _presentation_effect:BoardVisualEffect = null) -> bool:
	var valid_tokens:Array[Token] = _get_valid_destroy_tokens(tokens)
	
	if valid_tokens.is_empty():
		return false
	
	for token in valid_tokens:
		if board.get_token(token.token_pos) == token:
			board.remove_token_from_board(token.token_pos)
		
		token.being_destroyed = true
		
		if pending_destroyed_tokens.has(token) == false:
			pending_destroyed_tokens.append(token)
	
	return true


func flush_destroyed_tokens() -> int:
	var removed_count:int = 0
	var tokens_to_remove:Array[Token] = pending_destroyed_tokens.duplicate()
	pending_destroyed_tokens.clear()
	
	for token in tokens_to_remove:
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		token.free()
		removed_count += 1
	
	return removed_count


func clear_pending_destroyed_tokens() -> void:
	pending_destroyed_tokens.clear()
