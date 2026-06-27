extends Token
# Fan Token
# Pushes tokens sideways relative to gravity.

@export var fan_range:int = 2


func setup_special_token():
	token_type = TokenType.FAN
	keywords = []


func _try_to_use_ability() -> bool:
	return _try_push_tokens()


func _try_push_tokens() -> bool:
	var push_direction:BoardSetting.DIRECTION = _get_push_direction()
	var check_positions:Array[Vector2i] = _get_positions_in_range(push_direction)
	var moved_tokens:Array[Token] = []
	
	if check_positions.is_empty():
		return false
	
	if board.visuals != null:
		board.visuals.begin_move_batch()
	
	for i in range(check_positions.size() - 1, -1, -1):
		var check_pos:Vector2i = check_positions[i]
		var pushed_token:Token = board.get_token(check_pos)
		
		if pushed_token == null:
			continue
		
		if pushed_token == self:
			continue
		
		if is_instance_valid(pushed_token) == false:
			continue
		
		if pushed_token.being_destroyed:
			continue
		
		var target_pos:Vector2i = board.get_adjacent_pos(
			pushed_token.token_pos.x,
			pushed_token.token_pos.y,
			push_direction
		)
		
		if board.is_position_in_bounds(target_pos) == false:
			continue
		
		if board.get_token(target_pos) != null:
			continue
		
		if board.move_token_on_board(pushed_token, target_pos, BoardVisualManager.MOVE_VISUAL.SLIDE):
			moved_tokens.append(pushed_token)
	
	if board.visuals != null:
		if moved_tokens.is_empty() == false:
			queue_visual_effect(TokenShimmerVisualEffect.new(self), true)
		
		board.visuals.end_move_batch()
	
	if moved_tokens.is_empty():
		return false
	
	for moved_token in moved_tokens:
		_resolve_push_impact(moved_token)
	
	return true


func _resolve_push_impact(moved_token:Token) -> void:
	if moved_token == null:
		return
	
	if is_instance_valid(moved_token) == false:
		return
	
	if moved_token.being_destroyed:
		return
	
	if board.get_token(moved_token.token_pos) != moved_token:
		return
	
	board.trigger_resolver.resolve_impact_trigger_for_token(moved_token)


func _get_push_direction() -> BoardSetting.DIRECTION:
	if is_flipped:
		return BoardSetting.DIRECTION.LEFT
	
	return BoardSetting.DIRECTION.RIGHT


func _get_positions_in_range(push_direction:BoardSetting.DIRECTION) -> Array[Vector2i]:
	var positions:Array[Vector2i] = []
	var current_pos:Vector2i = token_pos
	
	for i in range(fan_range):
		current_pos = board.get_adjacent_pos(
			current_pos.x,
			current_pos.y,
			push_direction
		)
		
		if board.is_position_in_bounds(current_pos) == false:
			break
		
		positions.append(current_pos)
	
	return positions
