class_name BotActionGenerator
extends RefCounted


static func generate_actions(session:MatchSession, board_state:BoardState, settings:BoardSetting, player_id:int) -> Array[BotAction]:
	var result:Array[BotAction] = []
	
	if session == null:
		return result
	
	if board_state == null:
		return result
	
	if settings == null:
		return result
	
	var player:MatchSessionPlayerData = session.get_player(player_id)
	
	if player == null:
		return result
	
	if session.is_player_active(player_id) == false:
		return result
	
	var valid_starting_slots:Array[Vector2i] = PlacementRules.get_valid_starting_slots(board_state, settings)
	
	if valid_starting_slots.is_empty():
		return result
	
	var token_types:Array[int] = session.get_token_types_for_player(player_id)
	
	for token_type in token_types:
		if session.get_token_count(player_id, token_type) <= 0:
			continue
		
		if TokenLibrary.get_token_data(token_type).is_empty():
			continue
		
		var token_provider:Token = create_token_provider(token_type)
		
		if token_provider == null:
			continue
		
		for starting_slot in valid_starting_slots:
			append_actions_for_token_placement(result, token_provider, session, board_state, settings, player_id, token_type, starting_slot, false)
			
			if TokenLibrary.can_flip(token_type):
				append_actions_for_token_placement(result, token_provider, session, board_state, settings, player_id, token_type, starting_slot, true)
		
		token_provider.free()
	
	return result


static func append_actions_for_token_placement(result:Array[BotAction], token_provider:Token, session:MatchSession, board_state:BoardState, settings:BoardSetting, player_id:int, token_type:int, starting_slot:Vector2i, start_flipped:bool) -> void:
	var actions:Array[BotAction] = generate_actions_for_token_placement(token_provider, session, board_state, settings, player_id, token_type, starting_slot, start_flipped)
	
	for action in actions:
		result.append(action)


static func generate_actions_for_token_placement(token_provider:Token, session:MatchSession, board_state:BoardState, settings:BoardSetting, player_id:int, token_type:int, starting_slot:Vector2i, start_flipped:bool) -> Array[BotAction]:
	var result:Array[BotAction] = []
	
	if token_provider == null:
		return result
	
	if session == null:
		return result
	
	if board_state == null:
		return result
	
	if settings == null:
		return result
	
	if session.get_player(player_id) == null:
		return result
	
	if session.is_player_active(player_id) == false:
		return result
	
	if session.get_token_count(player_id, token_type) <= 0:
		return result
	
	if TokenLibrary.get_token_data(token_type).is_empty():
		return result
	
	if start_flipped and TokenLibrary.can_flip(token_type) == false:
		return result
	
	if PlacementRules.is_valid_starting_slot(board_state, settings, starting_slot) == false:
		return result
	
	var context:Dictionary = create_placement_choice_context(session, board_state, settings, player_id, token_type, starting_slot, start_flipped)
	var choice_variants:Array[Dictionary] = token_provider.get_placement_choice_variants(context)
	
	for choice_data in choice_variants:
		var action:BotAction = create_action(player_id, token_type, starting_slot, start_flipped, choice_data)
		
		if action.is_well_formed():
			result.append(action)
	
	return result


static func create_placement_choice_context(session:MatchSession, board_state:BoardState, settings:BoardSetting, player_id:int, token_type:int, starting_slot:Vector2i, start_flipped:bool) -> Dictionary:
	return {
		"session": session,
		"board_state": board_state,
		"settings": settings,
		"player_id": player_id,
		"player_count": session.get_player_count(),
		"token_type": token_type,
		"slot_pos": starting_slot,
		"start_flipped": start_flipped
	}


static func create_token_provider(token_type:int) -> Token:
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return null
	
	var temporary_node:Node = token_scene.instantiate()
	
	if temporary_node == null:
		return null
	
	var temporary_token:Token = temporary_node as Token
	
	if temporary_token == null:
		temporary_node.free()
		return null
	
	return temporary_token


static func create_action(player_id:int, token_type:int, starting_slot:Vector2i, start_flipped:bool, choice_data:Dictionary = {}) -> BotAction:
	var action:BotAction = BotAction.new()
	action.setup(player_id, token_type, starting_slot, start_flipped, choice_data)
	return action
