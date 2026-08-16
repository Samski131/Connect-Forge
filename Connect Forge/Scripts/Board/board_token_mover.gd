class_name BoardTokenMover
extends RefCounted

var board:BoardManager


func _init(new_board:BoardManager):
	board = new_board


func create_new_token(token_scene:PackedScene, slot_pos:Vector2i, player_id:int, start_flipped:bool = false) -> Token:
	if token_scene == null:
		return null
	
	if board.is_position_in_bounds(slot_pos) == false:
		return null
	
	if board.get_token(slot_pos) != null:
		return null
	
	if board.token_pool == null:
		return null
	
	var new_token:Token = token_scene.instantiate()
	
	if new_token == null:
		return null
	
	new_token.visible = false
	new_token.global_position = board.slot_to_global_position(slot_pos)
	board.token_pool.add_child(new_token)
	
	new_token.setup(board, slot_pos, player_id)
	
	if new_token.has_method("set_flipped"):
		new_token.set_flipped(start_flipped)
	else:
		new_token.is_flipped = start_flipped
	
	if board.add_token_to_board(new_token, slot_pos) == false:
		new_token.queue_free()
		return null
	
	var replay_token_id:int = board.register_replay_token(new_token)
	
	if replay_token_id >= 0:
		var replay_token_type:String = TokenLibrary.get_replay_id(new_token.token_type)
		DebugOverlay.log_message("ReplayRecorder", "Registered board token %d: %s, player %d, slot %s." % [replay_token_id, replay_token_type, player_id, str(slot_pos)])
	
	new_token.visible = true
	return new_token


func move_token_on_board(token:Token, new_pos:Vector2i, move_visual:BoardVisualManager.MOVE_VISUAL = BoardVisualManager.MOVE_VISUAL.SLIDE, extra_parallel_effects:Array[BoardVisualEffect] = [], check_pass_triggers:bool = true, movement_path:Array[Vector2i] = []) -> bool:
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
	
	var start_pos:Vector2i = token.token_pos
	var destination:Vector2i = new_pos
	var pass_step:Dictionary = {}
	
	if check_pass_triggers:
		pass_step = _get_first_pass_step(token, start_pos, new_pos, movement_path)
		
		if pass_step.has("has_pass_trigger"):
			if pass_step["has_pass_trigger"]:
				destination = pass_step["to_pos"]
	
	if board.is_position_in_bounds(destination) == false:
		return false
	
	if board.get_token(destination) != null:
		return false
	
	var recorded_movement_path:Array[Vector2i] = _get_recorded_movement_path(start_pos, destination, movement_path)
	
	board.remove_token_from_board(token.token_pos)
	token.token_pos = destination
	board.add_token_to_board(token, destination)
	
	var effect_to_queue:BoardVisualEffect = null
	
	if board.visuals != null:
		var move_effect:TokenMoveVisualEffect = _create_move_effect(token, destination, move_visual)
		move_effect.set_replay_movement_context(start_pos, destination, recorded_movement_path)
		effect_to_queue = _combine_with_extra_parallel_effects(move_effect, extra_parallel_effects)
	
	_record_replay_token_move(token, start_pos, destination, effect_to_queue)
	
	if board.visuals != null:
		board.visuals.queue_movement_effect(effect_to_queue)
	else:
		token.move_token_visual()
	
	if check_pass_triggers:
		if pass_step.has("has_pass_trigger"):
			if pass_step["has_pass_trigger"]:
				board.trigger_resolver.queue_passing_trigger(token, pass_step["from_pos"], pass_step["to_pos"])
	
	return true


func destroy_token(token:Token) -> bool:
	var tokens:Array[Token] = []
	
	if token != null:
		tokens.append(token)
	
	return destroy_tokens(tokens)


func destroy_tokens(tokens:Array[Token], presentation_effect:BoardVisualEffect = null) -> bool:
	var valid_tokens:Array[Token] = _get_valid_destroy_tokens(tokens)
	
	if valid_tokens.is_empty():
		return false
	
	var positions:Array[Vector2i] = []
	
	for token in valid_tokens:
		positions.append(token.token_pos)
	
	var effect_to_queue:BoardVisualEffect = presentation_effect
	
	if board.visuals != null:
		if effect_to_queue == null:
			effect_to_queue = _create_default_destroy_effect(valid_tokens)
	
	for token in valid_tokens:
		if board.get_token(token.token_pos) == token:
			board.remove_token_from_board(token.token_pos)
		
		token.being_destroyed = true
	
	_record_replay_token_destruction(valid_tokens, positions, effect_to_queue)
	
	if board.visuals != null and effect_to_queue != null:
		board.visuals.queue_effect(effect_to_queue)
	else:
		for token in valid_tokens:
			if token != null and is_instance_valid(token):
				token.queue_free()
	
	return true


func _get_valid_destroy_tokens(tokens:Array[Token]) -> Array[Token]:
	var result:Array[Token] = []
	var found_instances:Dictionary = {}
	
	for token in tokens:
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		if token.being_destroyed:
			continue
		
		var instance_id:int = token.get_instance_id()
		
		if found_instances.has(instance_id):
			continue
		
		found_instances[instance_id] = true
		result.append(token)
	
	return result


func _create_default_destroy_effect(tokens:Array[Token]) -> BoardVisualEffect:
	if board.visuals == null:
		return null
	
	if tokens.is_empty():
		return null
	
	if tokens.size() == 1:
		return TokenDestroyVisualEffect.new(tokens[0], board.visuals.destroy_duration)
	
	var destroy_effects:Array[BoardVisualEffect] = []
	
	for token in tokens:
		destroy_effects.append(TokenDestroyVisualEffect.new(token, board.visuals.destroy_duration))
	
	return ParallelVisualEffect.new(destroy_effects)


func _record_replay_token_destruction(tokens:Array[Token], positions:Array[Vector2i], visual_effect:BoardVisualEffect) -> void:
	if board == null:
		return
	
	var recorder:ReplayRecorder = board.get_replay_recorder()
	
	if recorder == null:
		return
	
	if recorder.is_recording() == false:
		return
	
	if board.match_session == null:
		DebugOverlay.log_error("ReplayRecorder", "Could not record token destruction because the board has no MatchSession.")
		return
	
	var presentation_action:ReplayAction = null
	
	if visual_effect != null:
		presentation_action = visual_effect.to_replay_action()
	
	var round_number:int = board.match_session.current_round_number
	var turn_number:int = board.match_session.current_turn_number
	var acting_player_id:int = board.match_session.current_player_id
	
	if recorder.record_token_destruction(tokens, positions, presentation_action, round_number, turn_number, acting_player_id) == false:
		DebugOverlay.log_error("ReplayRecorder", "Failed to record token destruction.")


func _record_replay_token_move(token:Token, start_pos:Vector2i, destination:Vector2i, visual_effect:BoardVisualEffect) -> void:
	if board == null:
		return
	
	var recorder:ReplayRecorder = board.get_replay_recorder()
	
	if recorder == null:
		return
	
	if recorder.is_recording() == false:
		return
	
	if board.match_session == null:
		DebugOverlay.log_error("ReplayRecorder", "Could not record token movement because the board has no MatchSession.")
		return
	
	var presentation_action:ReplayAction = null
	
	if recorder.is_move_batch_active() == false:
		if visual_effect != null:
			presentation_action = visual_effect.to_replay_action()
	
	var round_number:int = board.match_session.current_round_number
	var turn_number:int = board.match_session.current_turn_number
	var acting_player_id:int = board.match_session.current_player_id
	
	if recorder.record_token_move(token, start_pos, destination, presentation_action, round_number, turn_number, acting_player_id) == false:
		DebugOverlay.log_error("ReplayRecorder", "Failed to record movement for replay token %d." % token.get_replay_token_id())


func _get_recorded_movement_path(start_pos:Vector2i, destination:Vector2i, requested_path:Array[Vector2i]) -> Array[Vector2i]:
	var result:Array[Vector2i] = []
	
	if requested_path.is_empty():
		return _create_straight_movement_path(start_pos, destination)
	
	for path_pos in requested_path:
		result.append(path_pos)
		
		if path_pos == destination:
			break
	
	if result.is_empty():
		return _create_straight_movement_path(start_pos, destination)
	
	if result.back() != destination:
		return _create_straight_movement_path(start_pos, destination)
	
	return result


func _create_move_effect(token:Token, new_pos:Vector2i, move_visual:BoardVisualManager.MOVE_VISUAL) -> TokenMoveVisualEffect:
	var move_effect:TokenMoveVisualEffect = TokenMoveVisualEffect.new(token, board.slot_to_global_position(new_pos), move_visual)
	
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


func try_apply_gravity_to_token(token:Token) -> bool:
	if token == null:
		return false
	
	if is_instance_valid(token) == false:
		return false
	
	if token.being_destroyed:
		return false
	
	var fall_path:Array[Vector2i] = board.trigger_resolver.get_fall_path(token)
	
	if fall_path.is_empty():
		return false
	
	var destination:Vector2i = fall_path.back()
	var extra_effects:Array[BoardVisualEffect] = []
	var moved:bool = move_token_on_board(token, destination, BoardVisualManager.MOVE_VISUAL.FALL, extra_effects, true, fall_path)
	
	if moved:
		token.reset_resolved()
	
	return moved


func is_token_supported(token:Token) -> bool:
	if token == null:
		return false
	
	if is_instance_valid(token) == false:
		return false
	
	if token.being_destroyed:
		return false
	
	if is_token_at_gravity_edge(token):
		return true
	
	var support_token:Token = get_supporting_token(token)
	
	if support_token == null:
		return false
	
	return true


func is_token_at_gravity_edge(token:Token) -> bool:
	if token == null:
		return false
	
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	match board.settings.gravity_direction:
		GRID_DIRECTION.UP:
			if token.token_pos.y == 0:
				return true
		
		GRID_DIRECTION.RIGHT:
			if token.token_pos.x == board.settings.columns - 1:
				return true
		
		GRID_DIRECTION.DOWN:
			if token.token_pos.y == board.settings.rows - 1:
				return true
		
		GRID_DIRECTION.LEFT:
			if token.token_pos.x == 0:
				return true
	
	return false


func get_supporting_token(token:Token) -> Token:
	if token == null:
		return null
	
	if is_instance_valid(token) == false:
		return null
	
	var support_token:Token = board.get_relative_adjacent_token(token.token_pos.x, token.token_pos.y, BoardSetting.RELATIVE_DIRECTION.DOWN)
	
	if support_token == null:
		return null
	
	if is_instance_valid(support_token) == false:
		return null
	
	if support_token.being_destroyed:
		return null
	
	return support_token


func _get_first_pass_step(token:Token, start_pos:Vector2i, new_pos:Vector2i, movement_path:Array[Vector2i]) -> Dictionary:
	var path:Array[Vector2i] = _get_pass_check_path(start_pos, new_pos, movement_path)
	
	if path.is_empty():
		return {
			"has_pass_trigger": false,
			"from_pos": start_pos,
			"to_pos": start_pos
		}
	
	return board.trigger_resolver.find_first_pass_trigger_step(token, start_pos, path)


func _get_pass_check_path(start_pos:Vector2i, new_pos:Vector2i, movement_path:Array[Vector2i]) -> Array[Vector2i]:
	var path:Array[Vector2i] = []
	
	if movement_path.is_empty() == false:
		for pos in movement_path:
			path.append(pos)
		
		return path
	
	return _create_straight_movement_path(start_pos, new_pos)


func _create_straight_movement_path(start_pos:Vector2i, new_pos:Vector2i) -> Array[Vector2i]:
	var path:Array[Vector2i] = []
	
	if start_pos == new_pos:
		return path
	
	var difference:Vector2i = new_pos - start_pos
	var step:Vector2i = Vector2i.ZERO
	
	if difference.x > 0:
		step.x = 1
	elif difference.x < 0:
		step.x = -1
	
	if difference.y > 0:
		step.y = 1
	elif difference.y < 0:
		step.y = -1
	
	if difference.x != 0 and difference.y != 0:
		if abs(difference.x) != abs(difference.y):
			path.append(new_pos)
			return path
	
	var current_pos:Vector2i = start_pos + step
	
	while current_pos != new_pos:
		path.append(current_pos)
		current_pos += step
	
	path.append(new_pos)
	return path
