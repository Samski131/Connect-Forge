class_name BoardTokenMover
extends RefCounted

var board:BoardManager


func _init(new_board:BoardManager):
	board = new_board


func create_new_token(token_scene:PackedScene, slot_pos:Vector2i, player_id:int) -> Token:
	if token_scene == null:
		return null
	
	if board.is_position_in_bounds(slot_pos) == false:
		return null
	
	if board.get_token(slot_pos) != null:
		return null
	
	if board.token_pool == null:
		return null
	
	var new_token:Token = token_scene.instantiate()
	new_token.visible = false
	new_token.global_position = board.slot_to_global_position(slot_pos)
	
	board.token_pool.add_child(new_token)
	
	new_token.setup(board, slot_pos, player_id)
	board.add_token_to_board(new_token, slot_pos)
	
	new_token.visible = true
	
	return new_token


func move_token_on_board(token:Token, new_pos:Vector2i, move_visual:BoardVisualManager.MOVE_VISUAL = BoardVisualManager.MOVE_VISUAL.SLIDE, extra_parallel_effects:Array[BoardVisualEffect] = []) -> bool:
	if token == null:
		return false
	
	if is_instance_valid(token) == false:
		return false
	
	if token.being_destroyed:
		return false
	
	if board.is_position_in_bounds(new_pos) == false:
		return false
	
	if board.get_token(new_pos) != null:
		return false
	
	board.remove_token_from_board(token.token_pos)
	token.token_pos = new_pos
	board.add_token_to_board(token, new_pos)
	
	if board.visuals != null:
		var move_effect := _create_move_effect(token, new_pos, move_visual)
		var effect_to_queue := _combine_with_extra_parallel_effects(move_effect, extra_parallel_effects)
		
		board.visuals.queue_effect(effect_to_queue, move_visual == BoardVisualManager.MOVE_VISUAL.FALL)
	else:
		token.move_token_visual()
	
	return true


func destroy_token(token:Token) -> bool:
	if token == null:
		return false
	
	if is_instance_valid(token) == false:
		return false
	
	if token.being_destroyed:
		return false
	
	if board.get_token(token.token_pos) == token:
		board.remove_token_from_board(token.token_pos)
	
	token.being_destroyed = true
	
	if board.visuals != null:
		board.visuals.queue_effect(TokenDestroyVisualEffect.new(token, board.visuals.destroy_duration))
	else:
		token.queue_free()
	
	return true


func _create_move_effect(token:Token, new_pos:Vector2i, move_visual:BoardVisualManager.MOVE_VISUAL) -> TokenMoveVisualEffect:
	var move_effect := TokenMoveVisualEffect.new(token, board.slot_to_global_position(new_pos), move_visual)
	
	move_effect.slide_duration = board.visuals.slide_duration
	move_effect.min_fall_duration = board.visuals.min_fall_duration
	move_effect.max_fall_duration = board.visuals.max_fall_duration
	move_effect.fall_pixels_per_second = board.visuals.fall_pixels_per_second
	
	return move_effect


func _combine_with_extra_parallel_effects(move_effect:BoardVisualEffect, extra_parallel_effects:Array[BoardVisualEffect]) -> BoardVisualEffect:
	if extra_parallel_effects.is_empty():
		return move_effect
	
	var effects:Array[BoardVisualEffect] = [move_effect]
	
	for extra_effect in extra_parallel_effects:
		if extra_effect != null:
			effects.append(extra_effect)
	
	return ParallelVisualEffect.new(effects)
