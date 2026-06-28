extends Token
# Tetromino Token
# Clears its full row, or full column when gravity is sideways.

var line_flash_pulses:int = 3
var line_flash_duration:float = 0.4


func setup_special_token():
	token_type = TokenType.TETROMINO
	keywords = [Global.KEYWORD.ON_LINE_FULL]


func _try_to_use_ability() -> bool:
	return _try_clear_full_line()


func _on_line_full(_context:Dictionary) -> bool:
	return _try_clear_full_line()


func _try_clear_full_line() -> bool:
	var line_tokens:Array[Token] = _get_full_line_tokens()
	
	if line_tokens.is_empty():
		return false
	
	_clear_line_tokens(line_tokens)
	
	return true


func _get_full_line_tokens() -> Array[Token]:
	var line_tokens:Array[Token] = []
	var positions:Array[Vector2i] = _get_line_positions()
	
	for pos in positions:
		var token:Token = board.get_token(pos)
		
		if token == null:
			return []
		
		if is_instance_valid(token) == false:
			return []
		
		if token.being_destroyed:
			return []
		
		line_tokens.append(token)
	
	return line_tokens


func _get_line_positions() -> Array[Vector2i]:
	var positions:Array[Vector2i] = []
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	match board.settings.gravity_direction:
		GRID_DIRECTION.DOWN, GRID_DIRECTION.UP:
			for x in range(board.settings.columns):
				positions.append(Vector2i(x, token_pos.y))
		
		GRID_DIRECTION.LEFT, GRID_DIRECTION.RIGHT:
			for y in range(board.settings.rows):
				positions.append(Vector2i(token_pos.x, y))
	
	return positions


func _clear_line_tokens(line_tokens:Array[Token]) -> void:
	for token in line_tokens:
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		if board.get_token(token.token_pos) == token:
			board.remove_token_from_board(token.token_pos)
		
		token.being_destroyed = true
	
	if board.visuals != null:
		var destroy_effects:Array[BoardVisualEffect] = []
		
		for token in line_tokens:
			if token == null:
				continue
			
			if is_instance_valid(token) == false:
				continue
			
			destroy_effects.append(TokenDestroyVisualEffect.new(token, board.visuals.destroy_duration))
		
		var effect_sequence:Array[BoardVisualEffect] = [
			TokensFlashVisualEffect.new(line_tokens, line_flash_pulses, line_flash_duration),
			ParallelVisualEffect.new(destroy_effects)
		]
		
		queue_visual_effect(SequenceVisualEffect.new(effect_sequence))
	else:
		for token in line_tokens:
			if token != null and is_instance_valid(token):
				token.queue_free()
