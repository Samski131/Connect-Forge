extends Node


func _ready() -> void:
	print("")
	print("========== BOT MOVE SELECTOR TEST ==========")
	
	test_normal_position_ranks_every_legal_action()
	test_immediate_win_is_selected()
	test_immediate_threat_is_blocked()
	test_basic_is_preferred_when_special_token_gives_same_position()
	test_special_token_can_be_selected_when_it_is_the_available_winning_move()
	test_chameleon_expected_value_competes_with_deterministic_actions()
	test_entire_current_token_roster_can_be_ranked()
	test_selection_is_deterministic_and_returns_independent_action()
	test_no_legal_actions_fails_cleanly()
	
	print("========== ALL BOT MOVE SELECTOR TESTS PASSED ==========")
	print("")


func test_normal_position_ranks_every_legal_action() -> void:
	var state:BotSimulationState = create_test_state(2)
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 10, 3)
	
	var expected_actions:Array[BotAction] = BotActionGenerator.generate_actions(
		state.session,
		state.board_state,
		state.settings,
		0
	)
	
	var selection:BotMoveSelectionResult = select_from_state(selector, state)
	
	assert(selection != null, "Normal move selection returned null.")
	assert(selection.valid, selection.error_message)
	assert(selection.has_selection(), "Normal position produced no selected action.")
	assert(selection.generated_action_count == expected_actions.size(), "Selector generated a different number of legal actions.")
	assert(selection.evaluated_action_count == expected_actions.size(), "Selector did not evaluate every generated action.")
	assert(selection.ranked_evaluations.size() == expected_actions.size(), "Selector did not retain every ranked action.")
	assert(selection.best_evaluation == selection.ranked_evaluations[0], "Best evaluation is not rank zero.")
	assert(selection.best_action != selection.best_evaluation.action, "Returned BotAction should be an independent copy.")
	
	for rank_index in range(1, selection.ranked_evaluations.size()):
		var previous:BotActionEvaluation = selection.ranked_evaluations[rank_index - 1]
		var current:BotActionEvaluation = selection.ranked_evaluations[rank_index]
		
		assert(previous.final_score + BotMoveSelector.SCORE_TOLERANCE >= current.final_score, "Ranked action scores are not in descending order.")
	
	state.dispose()
	
	print("PASS: A normal position generates, evaluates and ranks every legal action.")


func test_immediate_win_is_selected() -> void:
	var state:BotSimulationState = create_test_state(2)
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 0), "Could not add winning token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 0), "Could not add winning token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 0), "Could not add winning token 3.")
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 10, 2)
	
	var selection:BotMoveSelectionResult = select_from_state(selector, state)
	
	assert(selection.valid, selection.error_message)
	assert(selection.has_selection(), "Winning position produced no selected action.")
	assert(selection.best_action.token_type == TokenLibrary.TokenType.BASIC, "Winning selection used the wrong token type.")
	assert(selection.best_action.starting_slot == Vector2i(3, 0), "Selector did not choose the immediate winning entry slot.")
	assert(selection.best_evaluation.is_guaranteed_win(), "Selected immediate win was not evaluated as guaranteed.")
	assert(abs(selection.best_evaluation.win_probability - 1.0) < 0.0001, "Selected immediate win should have probability 1.")
	assert(selection.best_evaluation.final_score > 900000.0, "Immediate win did not dominate the ranking.")
	
	state.dispose()
	
	print("PASS: Best-action selection chooses an available immediate win.")


func test_immediate_threat_is_blocked() -> void:
	var state:BotSimulationState = create_test_state(2)
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add threat token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add threat token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add threat token 3.")
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 10, 2)
	set_inventory(state, 1, TokenLibrary.TokenType.BASIC, 10, 1)
	
	var selection:BotMoveSelectionResult = select_from_state(selector, state)
	
	assert(selection.valid, selection.error_message)
	assert(selection.best_action != null, "Threat position produced no action.")
	assert(selection.best_action.token_type == TokenLibrary.TokenType.BASIC, "Blocking move used the wrong token.")
	assert(selection.best_action.starting_slot == Vector2i(3, 0), "Selector failed to block the opponent's immediate horizontal win.")
	
	var best_outcome:BotActionOutcomeEvaluation = selection.best_evaluation.outcome_evaluations[0]
	assert(best_outcome.has_opponent_immediate_threat(1) == false, "Selected blocking action still leaves the tested immediate threat.")
	
	state.dispose()
	
	print("PASS: Best-action selection blocks a next-player guaranteed win.")


func test_basic_is_preferred_when_special_token_gives_same_position() -> void:
	var state:BotSimulationState = create_test_state(2)
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	# On an empty board an Anvil landing at the gravity edge has no token
	# beneath it to destroy, so its resulting ownership position is equivalent
	# to placing a Basic in the same column.
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 5, 5)
	set_inventory(state, 0, TokenLibrary.TokenType.ANVIL, 1, 1)
	
	var selection:BotMoveSelectionResult = select_from_state(selector, state)
	
	assert(selection.valid, selection.error_message)
	assert(selection.best_action != null, "Resource-comparison position produced no action.")
	assert(selection.best_action.token_type == TokenLibrary.TokenType.BASIC, "Selector spent the scarce Anvil when Basic could produce the stronger resource-adjusted result.")
	
	var best_basic:BotActionEvaluation = find_best_evaluation_for_token(selection, TokenLibrary.TokenType.BASIC)
	var best_anvil:BotActionEvaluation = find_best_evaluation_for_token(selection, TokenLibrary.TokenType.ANVIL)
	
	assert(best_basic != null, "Could not find ranked Basic evaluation.")
	assert(best_anvil != null, "Could not find ranked Anvil evaluation.")
	assert(best_basic.resource_penalty < best_anvil.resource_penalty, "Basic should have the lower resource penalty.")
	assert(best_basic.final_score > best_anvil.final_score, "Resource preservation should break the otherwise similar Basic/Anvil comparison.")
	
	state.dispose()
	
	print("PASS: Selector preserves a scarce special token when Basic achieves the better resource-adjusted result.")


func test_special_token_can_be_selected_when_it_is_the_available_winning_move() -> void:
	var state:BotSimulationState = create_test_state(2)
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 0), "Could not add special-win token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 0), "Could not add special-win token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 0), "Could not add special-win token 3.")
	
	# No Basic tokens remain. The final Anvil is still a perfectly legal
	# fourth owned token and therefore completes the line.
	set_inventory(state, 0, TokenLibrary.TokenType.ANVIL, 1, 1)
	
	var selection:BotMoveSelectionResult = select_from_state(selector, state)
	
	assert(selection.valid, selection.error_message)
	assert(selection.best_action != null, "Special-token winning position produced no action.")
	assert(selection.best_action.token_type == TokenLibrary.TokenType.ANVIL, "Selector failed to use the available special token.")
	assert(selection.best_action.starting_slot == Vector2i(3, 0), "Selector did not place the Anvil on the winning entry.")
	assert(selection.best_evaluation.is_guaranteed_win(), "Winning Anvil placement was not recognised as guaranteed.")
	assert(selection.best_evaluation.resource_penalty > 0.0, "Final Anvil should still have a resource penalty.")
	assert(selection.best_evaluation.final_score > 900000.0, "Resource cost improperly outweighed the winning result.")
	
	state.dispose()
	
	print("PASS: Selector will spend a scarce special token when doing so produces an immediate win.")


func test_chameleon_expected_value_competes_with_deterministic_actions() -> void:
	var state:BotSimulationState = create_test_state(4)
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 5, 5)
	set_inventory(state, 0, TokenLibrary.TokenType.CHAMELEON, 2, 1)
	
	var selection:BotMoveSelectionResult = select_from_state(selector, state, 123456)
	
	assert(selection.valid, selection.error_message)
	
	var best_chameleon:BotActionEvaluation = find_best_evaluation_for_token(selection, TokenLibrary.TokenType.CHAMELEON)
	var best_basic:BotActionEvaluation = find_best_evaluation_for_token(selection, TokenLibrary.TokenType.BASIC)
	
	assert(best_chameleon != null, "Chameleon was not evaluated as a candidate.")
	assert(best_basic != null, "Basic was not evaluated as a candidate.")
	assert(best_chameleon.chance_outcome_count == 3, "Four-player Chameleon should be evaluated through three chance branches.")
	assert(abs(best_chameleon.probability_total - 1.0) < 0.0001, "Chameleon chance probabilities do not total 1.")
	
	var recomputed_expected_position:float = 0.0
	
	for outcome in best_chameleon.outcome_evaluations:
		recomputed_expected_position += outcome.combined_score * outcome.probability
	
	assert(abs(best_chameleon.expected_position_score - recomputed_expected_position) < 0.0001, "Selector received an incorrectly weighted Chameleon expected score.")
	
	# On this otherwise empty board the Chameleon does not gain enough
	# positional value to justify consuming the scarce special token.
	assert(selection.best_action.token_type == TokenLibrary.TokenType.BASIC, "Selector appears to have treated a Chameleon chance branch as guaranteed favourable value.")
	assert(best_basic.final_score > best_chameleon.final_score, "Expected-value comparison should favour the cheaper deterministic Basic here.")
	
	state.dispose()
	
	print("PASS: Chance-weighted Chameleon value competes normally against deterministic actions.")


func test_entire_current_token_roster_can_be_ranked() -> void:
	var state:BotSimulationState = create_test_state(2)
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	var source_starting_counts:Dictionary = {}
	var source_current_counts:Dictionary = {}
	
	for token_type in TokenLibrary.get_all_token_types():
		set_inventory(state, 0, token_type, 1, 1)
	
	source_starting_counts = state.session.get_player(0).get_starting_token_counts()
	source_current_counts = state.session.get_player(0).get_token_counts()
	
	var generated_actions:Array[BotAction] = BotActionGenerator.generate_actions(
		state.session,
		state.board_state,
		state.settings,
		0
	)
	
	assert(generated_actions.is_empty() == false, "Full-roster position generated no legal actions.")
	
	var selection:BotMoveSelectionResult = select_from_state(selector, state, 246810)
	
	assert(selection.valid, selection.error_message)
	assert(selection.generated_action_count == generated_actions.size(), "Full-roster selector generated the wrong number of actions.")
	assert(selection.evaluated_action_count == generated_actions.size(), "Not every full-roster action was evaluated.")
	assert(selection.ranked_evaluations.size() == generated_actions.size(), "Not every full-roster action was ranked.")
	assert(selection.best_action != null, "Full-roster selector returned no best action.")
	assert(selection.best_action.is_well_formed(), "Full-roster selector returned a malformed action.")
	assert(PlacementRules.is_valid_starting_slot(state.board_state, state.settings, selection.best_action.starting_slot), "Full-roster selector returned an illegal entry slot.")
	assert(state.session.get_token_count(0, selection.best_action.token_type) > 0, "Full-roster selector returned a token the player does not possess.")
	
	assert(state.session.get_player(0).get_starting_token_counts() == source_starting_counts, "Full-roster selection changed source starting inventory.")
	assert(state.session.get_player(0).get_token_counts() == source_current_counts, "Full-roster selection changed source current inventory.")
	assert(count_board_tokens(state) == 0, "Full-roster selection changed the source board.")
	
	state.dispose()
	
	print("PASS: Every legal action from the complete current token roster can be evaluated and ranked together.")


func test_selection_is_deterministic_and_returns_independent_action() -> void:
	var state:BotSimulationState = create_test_state(2)
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 10, 4)
	
	var selection_a:BotMoveSelectionResult = select_from_state(selector, state, 999999)
	var selection_b:BotMoveSelectionResult = select_from_state(selector, state, 999999)
	
	assert(selection_a.valid, selection_a.error_message)
	assert(selection_b.valid, selection_b.error_message)
	
	assert(actions_match(selection_a.best_action, selection_b.best_action), "Same state and seed selected different actions.")
	assert(abs(selection_a.best_evaluation.final_score - selection_b.best_evaluation.final_score) < 0.0001, "Same state and seed produced different best scores.")
	
	assert(selection_a.best_action != selection_a.best_evaluation.action, "Selected action shares the best evaluation's BotAction instance.")
	
	var stored_slot:Vector2i = selection_a.best_evaluation.action.starting_slot
	selection_a.best_action.starting_slot = Vector2i(99, 99)
	
	assert(selection_a.best_evaluation.action.starting_slot == stored_slot, "Mutating returned action changed the stored best evaluation.")
	
	state.dispose()
	
	print("PASS: Best-action selection is deterministic and returns an independent BotAction copy.")


func test_no_legal_actions_fails_cleanly() -> void:
	var state:BotSimulationState = create_test_state(2)
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	var selection:BotMoveSelectionResult = select_from_state(selector, state)
	
	assert(selection != null, "No-action selection returned null.")
	assert(selection.valid == false, "No-action position should not report a valid selection.")
	assert(selection.generated_action_count == 0, "No-action position unexpectedly generated actions.")
	assert(selection.best_action == null, "No-action position returned a BotAction.")
	assert(selection.best_evaluation == null, "No-action position returned a best evaluation.")
	assert(selection.ranked_evaluations.is_empty(), "No-action position retained ranked evaluations.")
	
	state.dispose()
	
	print("PASS: Positions with no legal actions fail cleanly without inventing a move.")


func select_from_state(selector:BotMoveSelector, state:BotSimulationState, seed:int = BotMoveSelector.DEFAULT_SELECTION_SEED) -> BotMoveSelectionResult:
	return selector.select_best_action(
		state.session,
		state.board_state,
		state.settings,
		state.session.current_player_id,
		seed
	)


func find_best_evaluation_for_token(selection:BotMoveSelectionResult, token_type:int) -> BotActionEvaluation:
	if selection == null:
		return null
	
	for evaluation in selection.ranked_evaluations:
		if evaluation == null:
			continue
		
		if evaluation.action == null:
			continue
		
		if evaluation.action.token_type == token_type:
			return evaluation
	
	return null


func actions_match(action_a:BotAction, action_b:BotAction) -> bool:
	if action_a == null or action_b == null:
		return false
	
	if action_a.player_id != action_b.player_id:
		return false
	
	if action_a.token_type != action_b.token_type:
		return false
	
	if action_a.starting_slot != action_b.starting_slot:
		return false
	
	if action_a.start_flipped != action_b.start_flipped:
		return false
	
	if action_a.get_choice_data() != action_b.get_choice_data():
		return false
	
	if action_a.get_placement_data() != action_b.get_placement_data():
		return false
	
	return true


func create_test_state(player_count:int) -> BotSimulationState:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = 7
	settings.rows = 6
	settings.tokens_to_win = 4
	settings.gravity_direction = BoardSetting.GRID_DIRECTION.DOWN
	
	var session:MatchSession = create_test_session(player_count)
	var state:BotSimulationState = BotSimulationState.new()
	
	assert(state.setup(settings, session, 1357911), "Could not setup move-selector test state.")
	
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
		assert(config.add_player("Test Player %d" % (player_id + 1), palettes[player_id]), "Could not add move-selector test Player %d." % player_id)
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not setup move-selector MatchSession.")
	
	for player_id in range(player_count):
		var player:MatchSessionPlayerData = session.get_player(player_id)
		
		assert(player != null, "Could not retrieve move-selector Player %d." % player_id)
		
		for token_type in TokenLibrary.get_all_token_types():
			player.set_starting_token_count(token_type, 0)
			player.set_token_count(token_type, 0)
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	assert(session.set_current_player(0), "Could not set move-selector current player.")
	
	return session


func set_inventory(state:BotSimulationState, player_id:int, token_type:int, starting_count:int, current_count:int) -> void:
	var player:MatchSessionPlayerData = state.session.get_player(player_id)
	
	assert(player != null, "Could not retrieve Player %d for move-selector inventory setup." % player_id)
	
	player.set_starting_token_count(token_type, starting_count)
	player.set_token_count(token_type, current_count)


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
	var result:int = 0
	
	for y in range(state.settings.rows):
		for x in range(state.settings.columns):
			if state.board_state.get_token(Vector2i(x, y)) != null:
				result += 1
	
	return result
