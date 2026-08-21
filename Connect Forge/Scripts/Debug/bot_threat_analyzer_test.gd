extends Node


func _ready() -> void:
	print("")
	print("========== BOT THREAT ANALYZER TEST ==========")
	
	test_neutral_board_has_no_immediate_threats()
	test_basic_immediate_win_is_detected()
	test_visible_line_is_not_a_threat_without_legal_action()
	test_multiple_opponents_are_analyzed_separately()
	test_inactive_players_are_skipped_in_turn_order()
	test_special_token_win_is_found_through_simulation()
	test_chance_outcomes_are_combined_into_one_action_probability()
	test_threat_analysis_does_not_mutate_source_state()
	
	print("========== ALL BOT THREAT ANALYZER TESTS PASSED ==========")
	print("")


func test_neutral_board_has_no_immediate_threats() -> void:
	var state:BotSimulationState = create_test_state(3)
	var analyzer:BotThreatAnalyzer = BotThreatAnalyzer.new()
	
	var analysis:BotThreatAnalysisResult = analyzer.analyze_state(state)
	
	assert(analysis != null, "Neutral threat analysis returned null.")
	assert(analysis.valid, analysis.error_message)
	assert(analysis.terminal == false, "Neutral state should not be terminal.")
	assert(analysis.next_player_id == 1, "Player 1 should be next.")
	
	for player_id in state.session.get_active_player_ids():
		var player_result:BotPlayerThreatResult = analysis.get_player_result(player_id)
		
		assert(player_result != null, "Missing neutral threat result for Player %d." % player_id)
		assert(player_result.has_immediate_win() == false, "Player %d unexpectedly has an immediate win." % player_id)
		assert(player_result.legal_action_count == 0, "Player %d should have no legal actions with an empty inventory." % player_id)
	
	state.dispose()
	
	print("PASS: Neutral states report no immediate tactical threats.")


func test_basic_immediate_win_is_detected() -> void:
	var state:BotSimulationState = create_test_state(2)
	var analyzer:BotThreatAnalyzer = BotThreatAnalyzer.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add Player 1 winning setup token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add Player 1 winning setup token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add Player 1 winning setup token 3.")
	
	set_token_count(state, 1, TokenLibrary.TokenType.BASIC, 1)
	
	var analysis:BotThreatAnalysisResult = analyzer.analyze_state(state)
	
	assert(analysis.valid, analysis.error_message)
	assert(analysis.next_player_id == 1, "Player 1 should be the next active player.")
	
	var player_result:BotPlayerThreatResult = analysis.get_player_result(1)
	
	assert(player_result != null, "Player 1 threat result is missing.")
	assert(player_result.turn_distance == 1, "Player 1 should act one turn from the reference player.")
	assert(player_result.has_immediate_win(), "Player 1's immediate Basic win was not detected.")
	assert(player_result.has_guaranteed_immediate_win(), "Player 1's deterministic Basic win should be guaranteed.")
	assert(player_result.get_immediate_winning_action_count() == 1, "Player 1 should have exactly one Basic winning placement.")
	assert(player_result.guaranteed_winning_action_count == 1, "Player 1 should have exactly one guaranteed winning action.")
	assert(abs(player_result.best_win_probability - 1.0) < 0.0001, "Player 1's Basic win should have probability 1.0.")
	
	var winning_action:BotImmediateWinAction = player_result.winning_actions[0]
	
	assert(winning_action.action.token_type == TokenLibrary.TokenType.BASIC, "Detected winning action is not Basic.")
	assert(winning_action.action.starting_slot == Vector2i(3, 0), "Detected the wrong winning Basic entry slot.")
	
	state.dispose()
	
	print("PASS: A next-player one-move Basic win is detected by full simulation.")


func test_visible_line_is_not_a_threat_without_legal_action() -> void:
	var state:BotSimulationState = create_test_state(2)
	var analyzer:BotThreatAnalyzer = BotThreatAnalyzer.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add no-inventory setup token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add no-inventory setup token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add no-inventory setup token 3.")
	
	# Player 1 deliberately has no remaining tokens.
	var analysis:BotThreatAnalysisResult = analyzer.analyze_state(state)
	
	assert(analysis.valid, analysis.error_message)
	
	var player_result:BotPlayerThreatResult = analysis.get_player_result(1)
	
	assert(player_result != null, "Player 1 threat result is missing.")
	assert(player_result.legal_action_count == 0, "Player 1 should have no legal action without inventory.")
	assert(player_result.has_immediate_win() == false, "A visually strong line was incorrectly treated as an actionable threat.")
	
	state.dispose()
	
	print("PASS: Winning-line shape alone is not treated as a threat when the player has no legal winning action.")


func test_multiple_opponents_are_analyzed_separately() -> void:
	var state:BotSimulationState = create_test_state(4)
	var analyzer:BotThreatAnalyzer = BotThreatAnalyzer.new()
	
	# Player 1 has a horizontal one-move win.
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add Player 1 token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add Player 1 token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add Player 1 token 3.")
	
	# Player 3 independently has a vertical one-move win.
	assert(add_token_to_state(state, Vector2i(6, 3), 3), "Could not add Player 3 token 1.")
	assert(add_token_to_state(state, Vector2i(6, 4), 3), "Could not add Player 3 token 2.")
	assert(add_token_to_state(state, Vector2i(6, 5), 3), "Could not add Player 3 token 3.")
	
	set_token_count(state, 1, TokenLibrary.TokenType.BASIC, 1)
	set_token_count(state, 3, TokenLibrary.TokenType.BASIC, 1)
	
	var analysis:BotThreatAnalysisResult = analyzer.analyze_state(state)
	
	assert(analysis.valid, analysis.error_message)
	assert(analysis.next_player_id == 1, "Player 1 should be next.")
	
	var player_zero:BotPlayerThreatResult = analysis.get_player_result(0)
	var player_one:BotPlayerThreatResult = analysis.get_player_result(1)
	var player_two:BotPlayerThreatResult = analysis.get_player_result(2)
	var player_three:BotPlayerThreatResult = analysis.get_player_result(3)
	
	assert(player_zero != null, "Player 0 result is missing.")
	assert(player_one != null, "Player 1 result is missing.")
	assert(player_two != null, "Player 2 result is missing.")
	assert(player_three != null, "Player 3 result is missing.")
	
	assert(player_zero.has_immediate_win() == false, "Player 0 should not have a threat.")
	assert(player_one.has_guaranteed_immediate_win(), "Player 1's horizontal threat was missed.")
	assert(player_two.has_immediate_win() == false, "Player 2 should not have a threat.")
	assert(player_three.has_guaranteed_immediate_win(), "Player 3's vertical threat was missed.")
	
	assert(player_one.turn_distance == 1, "Player 1 should be one active turn away.")
	assert(player_two.turn_distance == 2, "Player 2 should be two active turns away.")
	assert(player_three.turn_distance == 3, "Player 3 should be three active turns away.")
	
	state.dispose()
	
	print("PASS: Immediate threats from separate opponents are detected and retain turn-order distance.")


func test_inactive_players_are_skipped_in_turn_order() -> void:
	var state:BotSimulationState = create_test_state(3)
	var analyzer:BotThreatAnalyzer = BotThreatAnalyzer.new()
	
	assert(state.session.deactivate_player(1), "Could not deactivate Player 1.")
	
	assert(add_token_to_state(state, Vector2i(6, 3), 2), "Could not add Player 2 inactive-skip token 1.")
	assert(add_token_to_state(state, Vector2i(6, 4), 2), "Could not add Player 2 inactive-skip token 2.")
	assert(add_token_to_state(state, Vector2i(6, 5), 2), "Could not add Player 2 inactive-skip token 3.")
	
	set_token_count(state, 2, TokenLibrary.TokenType.BASIC, 1)
	
	var analysis:BotThreatAnalysisResult = analyzer.analyze_state(state)
	
	assert(analysis.valid, analysis.error_message)
	assert(analysis.next_player_id == 2, "Inactive Player 1 should have been skipped.")
	assert(analysis.has_player_result(1) == false, "Inactive Player 1 should not receive a threat analysis.")
	
	var player_two:BotPlayerThreatResult = analysis.get_player_result(2)
	
	assert(player_two != null, "Player 2 result is missing.")
	assert(player_two.turn_distance == 1, "Player 2 should now be the immediate next active player.")
	assert(player_two.has_guaranteed_immediate_win(), "Player 2's immediate threat was not detected.")
	
	state.dispose()
	
	print("PASS: Inactive player slots are skipped when determining tactical urgency.")


func test_special_token_win_is_found_through_simulation() -> void:
	var state:BotSimulationState = create_test_state(2)
	var analyzer:BotThreatAnalyzer = BotThreatAnalyzer.new()
	
	# Under DOWN gravity, Player 1 has three vertically stacked tokens
	# supported by Player 0 at the bottom.
	#
	# Player 1 cannot currently win by merely extending that stack because
	# the bottom token belongs to Player 0.
	#
	# A clockwise Rotate Gravity action changes gravity to LEFT. The three
	# Player 1 tokens move to x=0 on rows 2, 3 and 4, while the newly placed
	# Rotate Gravity token can occupy x=0 on row 5, creating four vertically.
	assert(add_token_to_state(state, Vector2i(6, 2), 1), "Could not add Rotate setup token 1.")
	assert(add_token_to_state(state, Vector2i(6, 3), 1), "Could not add Rotate setup token 2.")
	assert(add_token_to_state(state, Vector2i(6, 4), 1), "Could not add Rotate setup token 3.")
	assert(add_token_to_state(state, Vector2i(6, 5), 0), "Could not add Rotate setup support token.")
	
	set_token_count(state, 1, TokenLibrary.TokenType.ROTATE_GRAVITY, 1)
	
	var analysis:BotThreatAnalysisResult = analyzer.analyze_state(state)
	
	assert(analysis.valid, analysis.error_message)
	
	var player_result:BotPlayerThreatResult = analysis.get_player_result(1)
	
	assert(player_result != null, "Player 1 special-token result is missing.")
	assert(player_result.has_immediate_win(), "Rotate Gravity winning threat was not detected.")
	
	var found_rotate_gravity_win:bool = false
	
	for winning_action in player_result.winning_actions:
		if winning_action.action.token_type == TokenLibrary.TokenType.ROTATE_GRAVITY:
			found_rotate_gravity_win = true
			break
	
	assert(found_rotate_gravity_win, "Threat analyzer did not identify Rotate Gravity as a winning action.")
	
	state.dispose()
	
	print("PASS: Special-token tactical wins are discovered through normal simulation rather than bespoke threat rules.")


func test_chance_outcomes_are_combined_into_one_action_probability() -> void:
	var state:BotSimulationState = create_test_state(4)
	var analyzer:BotThreatAnalyzer = BotThreatAnalyzer.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add Chameleon winning setup token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add Chameleon winning setup token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add Chameleon winning setup token 3.")
	
	set_token_count(state, 1, TokenLibrary.TokenType.CHAMELEON, 1)
	
	var analysis:BotThreatAnalysisResult = analyzer.analyze_state(state, 123456)
	
	assert(analysis.valid, analysis.error_message)
	
	var player_result:BotPlayerThreatResult = analysis.get_player_result(1)
	
	assert(player_result != null, "Player 1 Chameleon threat result is missing.")
	assert(player_result.has_immediate_win(), "Winning Chameleon action was not detected.")
	
	var found_action:BotImmediateWinAction = null
	
	for winning_action in player_result.winning_actions:
		if winning_action.action.token_type != TokenLibrary.TokenType.CHAMELEON:
			continue
		
		if winning_action.action.starting_slot != Vector2i(3, 0):
			continue
		
		found_action = winning_action
		break
	
	assert(found_action != null, "Could not find the expected winning Chameleon action.")
	assert(found_action.total_outcome_count == 3, "Four-player Chameleon should have three possible disguise outcomes.")
	assert(found_action.winning_outcome_count == 3, "All Chameleon disguise outcomes should still complete the actual owner's winning line.")
	assert(abs(found_action.win_probability - 1.0) < 0.0001, "Three winning 1/3 Chameleon outcomes should combine to win probability 1.0.")
	assert(found_action.is_guaranteed_win(), "The aggregated Chameleon action should be recognised as guaranteed.")
	
	state.dispose()
	
	print("PASS: Random branches are probability-weighted back into a single player action.")


func test_threat_analysis_does_not_mutate_source_state() -> void:
	var state:BotSimulationState = create_test_state(2)
	var analyzer:BotThreatAnalyzer = BotThreatAnalyzer.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add isolation setup token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add isolation setup token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add isolation setup token 3.")
	
	set_token_count(state, 1, TokenLibrary.TokenType.BASIC, 2)
	
	var source_current_player:int = state.session.current_player_id
	var source_turn_phase:Global.TURN_PHASE = state.session.current_turn_phase
	var source_winner_id:int = state.session.winner_id
	var source_basic_count:int = state.session.get_token_count(1, TokenLibrary.TokenType.BASIC)
	var source_token_count:int = count_board_tokens(state)
	
	var source_token_one:Token = state.board_state.get_token(Vector2i(0, 5))
	var source_token_two:Token = state.board_state.get_token(Vector2i(1, 5))
	var source_token_three:Token = state.board_state.get_token(Vector2i(2, 5))
	
	var analysis:BotThreatAnalysisResult = analyzer.analyze_state(state)
	
	assert(analysis.valid, analysis.error_message)
	
	assert(state.session.current_player_id == source_current_player, "Threat analysis changed the source current player.")
	assert(state.session.current_turn_phase == source_turn_phase, "Threat analysis changed the source turn phase.")
	assert(state.session.winner_id == source_winner_id, "Threat analysis changed the source winner.")
	assert(state.session.get_token_count(1, TokenLibrary.TokenType.BASIC) == source_basic_count, "Threat analysis consumed source inventory.")
	assert(count_board_tokens(state) == source_token_count, "Threat analysis changed the source board token count.")
	
	assert(state.board_state.get_token(Vector2i(0, 5)) == source_token_one, "Threat analysis replaced source token 1.")
	assert(state.board_state.get_token(Vector2i(1, 5)) == source_token_two, "Threat analysis replaced source token 2.")
	assert(state.board_state.get_token(Vector2i(2, 5)) == source_token_three, "Threat analysis replaced source token 3.")
	
	state.dispose()
	
	print("PASS: Tactical analysis remains completely isolated from its source game state.")


func create_test_state(player_count:int) -> BotSimulationState:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = 7
	settings.rows = 6
	settings.tokens_to_win = 4
	settings.gravity_direction = BoardSetting.GRID_DIRECTION.DOWN
	
	var session:MatchSession = create_test_session(player_count)
	var state:BotSimulationState = BotSimulationState.new()
	
	assert(state.setup(settings, session, 98765), "Could not create tactical test simulation state.")
	
	return state


func create_test_session(player_count:int) -> MatchSession:
	var config:MatchConfig = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	config.turn_timer_seconds = 30
	config.starting_player_id = 0
	
	var palettes:Array[ColorPalette] = [
		MatchData.YELLOW_PALETTE,
		MatchData.RED_PALETTE,
		MatchData.GREEN_PALETTE,
		MatchData.VIOLET_PALETTE,
		MatchData.PINK_PALETTE
	]
	
	for player_id in range(player_count):
		assert(config.add_player("Test Player %d" % (player_id + 1), palettes[player_id]), "Could not add tactical test player %d." % player_id)
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not setup tactical test MatchSession.")
	
	for player_id in range(player_count):
		var player:MatchSessionPlayerData = session.get_player(player_id)
		
		assert(player != null, "Could not retrieve tactical test Player %d." % player_id)
		
		for token_type in TokenLibrary.get_all_token_types():
			player.set_token_count(token_type, 0)
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	assert(session.set_current_player(0), "Could not set tactical reference player.")
	
	return session


func set_token_count(state:BotSimulationState, player_id:int, token_type:int, count:int) -> void:
	var player:MatchSessionPlayerData = state.session.get_player(player_id)
	
	assert(player != null, "Could not retrieve Player %d for inventory setup." % player_id)
	
	player.set_token_count(token_type, count)


func add_token_to_state(state:BotSimulationState, pos:Vector2i, player_id:int, token_type:int = TokenLibrary.TokenType.BASIC) -> bool:
	if state == null:
		return false
	
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return false
	
	var token_node:Node = token_scene.instantiate()
	
	if token_node == null:
		return false
	
	var token:Token = token_node as Token
	
	if token == null:
		token_node.free()
		return false
	
	token.setup_special_token()
	token.player_id = player_id
	token.token_pos = pos
	token.resolved = true
	token.being_destroyed = false
	token.board = null
	token.replay_token_id = -1
	
	if state.own_token(token) == false:
		token.free()
		return false
	
	if state.board_state.add_token(token, pos) == false:
		token.free()
		return false
	
	return true


func count_board_tokens(state:BotSimulationState) -> int:
	var count:int = 0
	
	for y in range(state.settings.rows):
		for x in range(state.settings.columns):
			if state.board_state.get_token(Vector2i(x, y)) != null:
				count += 1
	
	return count
