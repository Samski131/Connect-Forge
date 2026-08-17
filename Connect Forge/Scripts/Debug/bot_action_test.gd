extends Node


func _ready() -> void:
	print("")
	print("========== BOT ACTION TEST ==========")
	
	test_placement_rules_down()
	test_placement_rules_all_gravity_directions()
	test_occupied_entry_is_removed()
	test_bot_action_representation()
	test_action_generation()
	test_zero_count_tokens_are_excluded()
	test_generic_choice_variants()
	test_entire_current_token_roster()
	
	print("========== ALL BOT ACTION TESTS PASSED ==========")
	print("")


func test_placement_rules_down() -> void:
	var settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var board_state:BoardState = create_empty_board_state(settings)
	var valid_slots:Array[Vector2i] = PlacementRules.get_valid_starting_slots(board_state, settings)
	
	assert(valid_slots.size() == 7, "A 7-column board with DOWN gravity should have 7 starting slots.")
	
	for x in range(7):
		assert(valid_slots.has(Vector2i(x, 0)), "DOWN gravity should allow every empty slot on the top edge.")
	
	print("PASS: DOWN gravity placement rules are correct.")


func test_placement_rules_all_gravity_directions() -> void:
	var down_settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var down_state:BoardState = create_empty_board_state(down_settings)
	assert(PlacementRules.get_valid_starting_slots(down_state, down_settings).size() == 7, "DOWN should have 7 entry slots.")
	
	var up_settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.UP)
	var up_state:BoardState = create_empty_board_state(up_settings)
	assert(PlacementRules.get_valid_starting_slots(up_state, up_settings).size() == 7, "UP should have 7 entry slots.")
	
	var right_settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.RIGHT)
	var right_state:BoardState = create_empty_board_state(right_settings)
	assert(PlacementRules.get_valid_starting_slots(right_state, right_settings).size() == 6, "RIGHT should have 6 entry slots.")
	
	var left_settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.LEFT)
	var left_state:BoardState = create_empty_board_state(left_settings)
	assert(PlacementRules.get_valid_starting_slots(left_state, left_settings).size() == 6, "LEFT should have 6 entry slots.")
	
	assert(PlacementRules.is_valid_starting_slot(up_state, up_settings, Vector2i(0, 5)), "UP gravity should use the bottom edge.")
	assert(PlacementRules.is_valid_starting_slot(right_state, right_settings, Vector2i(0, 0)), "RIGHT gravity should use the left edge.")
	assert(PlacementRules.is_valid_starting_slot(left_state, left_settings, Vector2i(6, 0)), "LEFT gravity should use the right edge.")
	
	print("PASS: All four gravity directions use the correct placement edge.")


func test_occupied_entry_is_removed() -> void:
	var settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var board_state:BoardState = create_empty_board_state(settings)
	var blocking_token:Token = Token.new()
	
	assert(board_state.add_token(blocking_token, Vector2i(3, 0)), "Could not add blocking token to test board.")
	
	var valid_slots:Array[Vector2i] = PlacementRules.get_valid_starting_slots(board_state, settings)
	
	assert(valid_slots.size() == 6, "One occupied top entry should leave 6 legal starting slots.")
	assert(valid_slots.has(Vector2i(3, 0)) == false, "An occupied entry slot must not be legal.")
	
	board_state.remove_token(Vector2i(3, 0))
	blocking_token.free()
	
	print("PASS: Occupied entry slots are excluded.")


func test_bot_action_representation() -> void:
	var action:BotAction = BotAction.new()
	action.setup(1, TokenLibrary.TokenType.RAMP, Vector2i(4, 0), true)
	
	assert(action.player_id == 1, "BotAction stored the wrong player ID.")
	assert(action.token_type == TokenLibrary.TokenType.RAMP, "BotAction stored the wrong token type.")
	assert(action.starting_slot == Vector2i(4, 0), "BotAction stored the wrong starting slot.")
	assert(action.start_flipped, "BotAction should be flipped.")
	assert(action.is_well_formed(), "Valid Ramp action should be well formed.")
	
	var copied_action:BotAction = action.duplicate_action()
	assert(copied_action != action, "duplicate_action should create a different BotAction instance.")
	assert(copied_action.player_id == action.player_id, "Duplicated action has the wrong player ID.")
	assert(copied_action.token_type == action.token_type, "Duplicated action has the wrong token type.")
	assert(copied_action.starting_slot == action.starting_slot, "Duplicated action has the wrong starting slot.")
	assert(copied_action.start_flipped == action.start_flipped, "Duplicated action has the wrong flipped state.")
	
	print("PASS: BotAction stores and duplicates generic action data.")


func test_action_generation() -> void:
	var session:MatchSession = create_test_session()
	var settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var board_state:BoardState = create_empty_board_state(settings)
	var actions:Array[BotAction] = BotActionGenerator.generate_actions(session, board_state, settings, 0)
	
	assert(actions.size() == 28, "Basic + Bomb + Ramp should generate 28 actions on an empty 7-column board.")
	assert(count_actions_for_token(actions, TokenLibrary.TokenType.BASIC) == 7, "Basic should generate one action per entry slot.")
	assert(count_actions_for_token(actions, TokenLibrary.TokenType.BOMB) == 7, "Bomb should generate one action per entry slot.")
	assert(count_actions_for_token(actions, TokenLibrary.TokenType.RAMP) == 14, "Ramp should generate flipped and unflipped actions for every entry slot.")
	assert(count_flipped_actions_for_token(actions, TokenLibrary.TokenType.RAMP) == 7, "Ramp should have 7 flipped actions.")
	assert(count_unflipped_actions_for_token(actions, TokenLibrary.TokenType.RAMP) == 7, "Ramp should have 7 unflipped actions.")
	assert(count_flipped_actions_for_token(actions, TokenLibrary.TokenType.BASIC) == 0, "Basic should never generate a flipped action.")
	assert(count_flipped_actions_for_token(actions, TokenLibrary.TokenType.BOMB) == 0, "Bomb should never generate a flipped action.")
	
	for action in actions:
		assert(action != null, "Generated actions must not contain null.")
		assert(action.is_well_formed(), "Every generated action should be well formed.")
		assert(PlacementRules.is_valid_starting_slot(board_state, settings, action.starting_slot), "Generated action used an illegal starting slot.")
		assert(session.get_token_count(action.player_id, action.token_type) > 0, "Generated action used a token the player does not possess.")
	
	print("PASS: Current tray generates all legal Basic, Bomb and Ramp actions.")


func test_zero_count_tokens_are_excluded() -> void:
	var session:MatchSession = create_test_session()
	var player:MatchSessionPlayerData = session.get_player(0)
	
	assert(player != null, "Test session player was not found.")
	
	player.set_token_count(TokenLibrary.TokenType.BOMB, 0)
	
	var settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var board_state:BoardState = create_empty_board_state(settings)
	var actions:Array[BotAction] = BotActionGenerator.generate_actions(session, board_state, settings, 0)
	
	assert(actions.size() == 21, "Basic + Ramp should generate 21 actions after Bomb reaches zero.")
	assert(count_actions_for_token(actions, TokenLibrary.TokenType.BOMB) == 0, "A zero-count Bomb must not generate actions.")
	
	print("PASS: Tokens with zero remaining count are excluded.")


func test_generic_choice_variants() -> void:
	var session:MatchSession = create_test_session()
	var settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var board_state:BoardState = create_empty_board_state(settings)
	var test_token:BotActionChoiceTestToken = BotActionChoiceTestToken.new()
	
	var actions:Array[BotAction] = BotActionGenerator.generate_actions_for_token_placement(test_token, session, board_state, settings, 0, TokenLibrary.TokenType.BASIC, Vector2i(0, 0), false)
	
	assert(actions.size() == 3, "A token exposing three placement choices should generate three BotActions.")
	assert(actions[0].choice_data.get("target_pos", Vector2i(-1, -1)) == Vector2i(1, 1), "First generic choice was not preserved.")
	assert(actions[1].choice_data.get("target_pos", Vector2i(-1, -1)) == Vector2i(2, 2), "Second generic choice was not preserved.")
	assert(actions[2].choice_data.get("target_pos", Vector2i(-1, -1)) == Vector2i(3, 3), "Third generic choice was not preserved.")
	
	for action in actions:
		assert(action.player_id == 0, "Choice action has the wrong player ID.")
		assert(action.token_type == TokenLibrary.TokenType.BASIC, "Choice action has the wrong token type.")
		assert(action.starting_slot == Vector2i(0, 0), "Choice action has the wrong starting slot.")
		assert(action.is_well_formed(), "Choice action should be well formed.")
	
	test_token.free()
	
	print("PASS: Generic token-specific placement choices expand into separate BotActions.")


func test_entire_current_token_roster() -> void:
	var session:MatchSession = create_test_session()
	var player:MatchSessionPlayerData = session.get_player(0)
	
	assert(player != null, "Test session player was not found.")
	
	for token_type in TokenLibrary.get_all_token_types():
		player.set_token_count(token_type, 1)
	
	var settings:BoardSetting = create_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var board_state:BoardState = create_empty_board_state(settings)
	var actions:Array[BotAction] = BotActionGenerator.generate_actions(session, board_state, settings, 0)
	
	assert(actions.size() == 105, "The full current token roster should generate 105 actions on an empty 7-column board.")
	
	for token_type in TokenLibrary.get_all_token_types():
		var expected_actions:int = 7
		
		if TokenLibrary.can_flip(token_type):
			expected_actions = 14
		
		assert(count_actions_for_token(actions, token_type) == expected_actions, "%s generated the wrong number of actions." % TokenLibrary.get_display_name(token_type))
	
	print("PASS: Every currently registered token generates legal actions through the generic system.")


func create_test_session() -> MatchSession:
	var config:MatchConfig = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	
	assert(config.add_player("Test Player 1", MatchData.YELLOW_PALETTE), "Could not add test player 1.")
	assert(config.add_player("Test Player 2", MatchData.RED_PALETTE), "Could not add test player 2.")
	
	var player:MatchPlayerData = config.get_player(0)
	assert(player != null, "Could not retrieve test player.")
	assert(player.try_purchase_token(TokenLibrary.TokenType.BOMB), "Could not purchase test Bomb.")
	assert(player.try_purchase_token(TokenLibrary.TokenType.RAMP), "Could not purchase test Ramp.")
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not create test MatchSession.")
	return session


func create_settings(gravity_direction:BoardSetting.GRID_DIRECTION) -> BoardSetting:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = 7
	settings.rows = 6
	settings.tokens_to_win = 4
	settings.gravity_direction = gravity_direction
	return settings


func create_empty_board_state(settings:BoardSetting) -> BoardState:
	var board_state:BoardState = BoardState.new(settings)
	board_state.setup_empty_board()
	return board_state


func count_actions_for_token(actions:Array[BotAction], token_type:int) -> int:
	var count:int = 0
	
	for action in actions:
		if action.token_type == token_type:
			count += 1
	
	return count


func count_flipped_actions_for_token(actions:Array[BotAction], token_type:int) -> int:
	var count:int = 0
	
	for action in actions:
		if action.token_type != token_type:
			continue
		
		if action.start_flipped:
			count += 1
	
	return count


func count_unflipped_actions_for_token(actions:Array[BotAction], token_type:int) -> int:
	var count:int = 0
	
	for action in actions:
		if action.token_type != token_type:
			continue
		
		if action.start_flipped == false:
			count += 1
	
	return count
