class_name BotSimulationStateCloner
extends RefCounted


static func clone_state(source_session:MatchSession, source_board_state:BoardState, source_settings:BoardSetting, random_seed:int = BotSimulationState.DEFAULT_RANDOM_SEED) -> BotSimulationState:
	if source_session == null:
		push_error("BotSimulationStateCloner: Cannot clone a null MatchSession.")
		return null
	
	if source_board_state == null:
		push_error("BotSimulationStateCloner: Cannot clone a null BoardState.")
		return null
	
	if source_settings == null:
		push_error("BotSimulationStateCloner: Cannot clone null BoardSetting.")
		return null
	
	if _validate_source_dimensions(source_session, source_board_state, source_settings) == false:
		return null
	
	var cloned_settings:BoardSetting = _clone_settings(source_settings)
	var cloned_session:MatchSession = _clone_session(source_session)
	
	if cloned_settings == null:
		return null
	
	if cloned_session == null:
		return null
	
	var result:BotSimulationState = BotSimulationState.new()
	
	if result.setup(cloned_settings, cloned_session, random_seed) == false:
		return null
	
	if _clone_board(source_board_state, result) == false:
		result.dispose()
		return null
	
	return result


static func _validate_source_dimensions(source_session:MatchSession, source_board_state:BoardState, source_settings:BoardSetting) -> bool:
	if source_board_state.settings == null:
		push_error("BotSimulationStateCloner: Source BoardState has no settings.")
		return false
	
	if source_board_state.settings.columns != source_settings.columns:
		push_error("BotSimulationStateCloner: BoardState and BoardSetting column counts do not match.")
		return false
	
	if source_board_state.settings.rows != source_settings.rows:
		push_error("BotSimulationStateCloner: BoardState and BoardSetting row counts do not match.")
		return false
	
	if source_session.board_columns != source_settings.columns:
		push_error("BotSimulationStateCloner: MatchSession and BoardSetting column counts do not match.")
		return false
	
	if source_session.board_rows != source_settings.rows:
		push_error("BotSimulationStateCloner: MatchSession and BoardSetting row counts do not match.")
		return false
	
	if source_session.tokens_to_win != source_settings.tokens_to_win:
		push_error("BotSimulationStateCloner: MatchSession and BoardSetting tokens-to-win values do not match.")
		return false
	
	return true


static func _clone_settings(source:BoardSetting) -> BoardSetting:
	if source == null:
		return null
	
	var result:BoardSetting = BoardSetting.new()
	result.rows = source.rows
	result.columns = source.columns
	result.tokens_to_win = source.tokens_to_win
	result.gravity_direction = source.gravity_direction
	
	return result


static func _clone_session(source:MatchSession) -> MatchSession:
	if source == null:
		return null
	
	var result:MatchSession = MatchSession.new()
	
	result.players.clear()
	result.active_player_ids.clear()
	
	for source_player in source.players:
		if source_player == null:
			push_error("BotSimulationStateCloner: Source MatchSession contains a null player.")
			return null
		
		var cloned_player:MatchSessionPlayerData = _clone_session_player(source_player)
		
		if cloned_player == null:
			return null
		
		result.players.append(cloned_player)
		result.connect_player_signals(cloned_player)
	
	result.active_player_ids = source.active_player_ids.duplicate()
	
	result.starting_token_points = source.starting_token_points
	result.board_columns = source.board_columns
	result.board_rows = source.board_rows
	result.tokens_to_win = source.tokens_to_win
	result.turn_timer_seconds = source.turn_timer_seconds
	result.starting_player_id = source.starting_player_id
	
	result.current_turn_phase = source.current_turn_phase
	result.current_player_id = source.current_player_id
	result.current_turn_number = source.current_turn_number
	result.current_round_number = source.current_round_number
	
	result.elapsed_game_time = source.elapsed_game_time
	result.elapsed_game_seconds = source.elapsed_game_seconds
	result.game_timer_running = source.game_timer_running
	
	result.winner_id = source.winner_id
	result.match_result_recorded = source.match_result_recorded
	result.is_batching_score_changes = source.is_batching_score_changes
	
	return result


static func _clone_session_player(source:MatchSessionPlayerData) -> MatchSessionPlayerData:
	if source == null:
		return null
	
	var result:MatchSessionPlayerData = MatchSessionPlayerData.new()
	
	result.player_id = source.player_id
	result.player_name = source.player_name
	
	if source.colour_palette != null:
		var duplicated_palette_resource:Resource = source.colour_palette.duplicate(true)
		var duplicated_palette:ColorPalette = duplicated_palette_resource as ColorPalette
		
		if duplicated_palette == null:
			push_error("BotSimulationStateCloner: Could not duplicate the colour palette for player %d." % source.player_id)
			return null
		
		result.colour_palette = duplicated_palette
	else:
		result.colour_palette = null
	
	result.controller_type = source.controller_type
	result.bot_profile_id = source.bot_profile_id
	result.bot_difficulty = source.bot_difficulty
	
	result.wins = source.wins
	result.losses = source.losses
	
	result.starting_token_counts = source.get_starting_token_counts()
	result.token_counts = source.get_token_counts()
	
	return result


static func _clone_board(source_board_state:BoardState, simulation_state:BotSimulationState) -> bool:
	if source_board_state == null:
		return false
	
	if simulation_state == null:
		return false
	
	if simulation_state.board_state == null:
		return false
	
	for y in range(simulation_state.settings.rows):
		for x in range(simulation_state.settings.columns):
			var pos:Vector2i = Vector2i(x, y)
			var source_token:Token = source_board_state.get_token(pos)
			
			if source_token == null:
				continue
			
			if is_instance_valid(source_token) == false:
				push_error("BotSimulationStateCloner: Source board contains an invalid token at %s." % str(pos))
				return false
			
			var cloned_token:Token = _clone_token(source_token)
			
			if cloned_token == null:
				push_error("BotSimulationStateCloner: Could not clone token at %s." % str(pos))
				return false
			
			if simulation_state.own_token(cloned_token) == false:
				cloned_token.free()
				push_error("BotSimulationStateCloner: Could not take ownership of cloned token at %s." % str(pos))
				return false
			
			if simulation_state.board_state.add_token(cloned_token, pos) == false:
				push_error("BotSimulationStateCloner: Could not add cloned token at %s." % str(pos))
				return false
	
	return true


static func _clone_token(source:Token) -> Token:
	if source == null:
		return null
	
	if is_instance_valid(source) == false:
		return null
	
	var token_scene:PackedScene = TokenLibrary.get_token_scene(source.token_type)
	
	if token_scene == null:
		push_error("BotSimulationStateCloner: No scene exists for token type %d." % source.token_type)
		return null
	
	var cloned_node:Node = token_scene.instantiate()
	
	if cloned_node == null:
		return null
	
	var result:Token = cloned_node as Token
	
	if result == null:
		cloned_node.free()
		push_error("BotSimulationStateCloner: Token scene for type %d did not instantiate a Token." % source.token_type)
		return null
	
	result.setup_special_token()
	
	result.player_id = source.player_id
	result.token_pos = source.token_pos
	result.resolved = source.resolved
	result.being_destroyed = source.being_destroyed
	result.is_flipped = source.is_flipped
	result.charges = source.charges
	result.ability_cost = source.ability_cost
	result.keywords = source.keywords.duplicate()
	
	result.board = null
	
	result.gravity_visual_rotation_degrees = source.gravity_visual_rotation_degrees
	result.replay_token_id = -1
	result.clear_visual_player_palettes()
	
	var placement_data:Dictionary = source.get_network_placement_data()
	result.apply_network_placement_data(placement_data.duplicate(true))
	
	var token_state_data:Dictionary = source.create_network_state_data()
	result.apply_network_state_data(token_state_data.duplicate(true))
	
	return result
