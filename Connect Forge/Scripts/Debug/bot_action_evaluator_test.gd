extends Node


func _ready() -> void:
	print("")
	print("========== BOT ACTION EVALUATOR TEST ==========")
	
	test_weighted_score_math()
	test_deterministic_action_combines_board_and_resource_scores()
	test_next_player_guaranteed_win_receives_large_penalty()
	test_blocking_immediate_win_is_preferred()
	test_later_player_threat_is_discounted()
	test_chameleon_outcomes_are_probability_weighted_and_resource_is_charged_once()
	test_immediate_win_dominates_resource_cost()
	test_action_evaluation_does_not_mutate_source_state()
	
	print("========== ALL BOT ACTION EVALUATOR TESTS PASSED ==========")
	print("")


func test_weighted_score_math() -> void:
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(0, 0))
	var evaluation:BotActionEvaluation = BotActionEvaluation.new()
	
	assert(evaluation.setup(action), "Could not setup synthetic action evaluation.")
	
	var outcome_a:BotActionOutcomeEvaluation = BotActionOutcomeEvaluation.new()
	var outcome_b:BotActionOutcomeEvaluation = BotActionOutcomeEvaluation.new()
	
	assert(outcome_a.setup(0.25), "Could not setup synthetic outcome A.")
	assert(outcome_b.setup(0.75), "Could not setup synthetic outcome B.")
	
	outcome_a.set_board_evaluation(100.0, false, -1)
	outcome_a.set_tactical_adjustment(-20.0)
	
	outcome_b.set_board_evaluation(20.0, false, -1)
	outcome_b.set_tactical_adjustment(0.0)
	
	assert(evaluation.add_outcome_evaluation(outcome_a), "Could not add synthetic outcome A.")
	assert(evaluation.add_outcome_evaluation(outcome_b), "Could not add synthetic outcome B.")
	assert(evaluation.finalize(10.0), evaluation.error_message)
	
	# Board:
	# 100 * 0.25 + 20 * 0.75 = 40
	assert(abs(evaluation.expected_board_score - 40.0) < 0.0001, "Weighted board score is incorrect.")
	
	# Tactics:
	# -20 * 0.25 + 0 * 0.75 = -5
	assert(abs(evaluation.expected_tactical_adjustment - (-5.0)) < 0.0001, "Weighted tactical score is incorrect.")
	
	# Position = 35, resource penalty = 10, final = 25.
	assert(abs(evaluation.expected_position_score - 35.0) < 0.0001, "Weighted position score is incorrect.")
	assert(abs(evaluation.resource_penalty - 10.0) < 0.0001, "Resource penalty is incorrect.")
	assert(abs(evaluation.final_score - 25.0) < 0.0001, "Final weighted action score is incorrect.")
	
	print("PASS: Chance-weighted board, tactical and resource score arithmetic is correct.")


func test_deterministic_action_combines_board_and_resource_scores() -> void:
	var state:BotSimulationState = create_test_state(2)
	var evaluator:BotActionEvaluator = BotActionEvaluator.new()
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 10, 3)
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(3, 0))
	var evaluation:BotActionEvaluation = evaluate_action_from_state(evaluator, state, action)
	
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.chance_outcome_count == 1, "Deterministic Basic action should have exactly one chance outcome.")
	assert(abs(evaluation.probability_total - 1.0) < 0.0001, "Deterministic action probability should total 1.")
	assert(abs(evaluation.expected_tactical_adjustment) < 0.0001, "Neutral opponent should create no tactical adjustment.")
	assert(evaluation.resource_penalty > 0.0, "Basic should retain its small finite-inventory resource cost.")
	assert(abs(evaluation.final_score - (evaluation.expected_board_score - evaluation.resource_penalty)) < 0.0001, "Deterministic final score did not combine board and resource values correctly.")
	
	state.dispose()
	
	print("PASS: Deterministic actions combine positional evaluation and one resource cost.")


func test_next_player_guaranteed_win_receives_large_penalty() -> void:
	var state:BotSimulationState = create_test_state(2)
	var evaluator:BotActionEvaluator = BotActionEvaluator.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add threat token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add threat token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add threat token 3.")
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 10, 2)
	set_inventory(state, 1, TokenLibrary.TokenType.BASIC, 10, 1)
	
	# Player 0 deliberately plays elsewhere and leaves x=3 open.
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(5, 0))
	var evaluation:BotActionEvaluation = evaluate_action_from_state(evaluator, state, action)
	
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.outcome_evaluations.size() == 1, "Expected one deterministic outcome.")
	
	var outcome:BotActionOutcomeEvaluation = evaluation.outcome_evaluations[0]
	
	assert(outcome.has_opponent_immediate_threat(1), "Next player's guaranteed winning response was not detected.")
	assert(outcome.get_opponent_turn_distance(1) == 1, "Player 1 should be the next active player.")
	assert(abs(outcome.get_opponent_best_win_probability(1) - 1.0) < 0.0001, "Player 1's Basic win should have probability 1.")
	assert(abs(outcome.get_opponent_threat_penalty(1) - BotActionEvaluator.IMMEDIATE_THREAT_BASE_PENALTY) < 0.0001, "Next-player guaranteed threat received the wrong penalty.")
	assert(evaluation.expected_tactical_adjustment <= -BotActionEvaluator.IMMEDIATE_THREAT_BASE_PENALTY, "Guaranteed immediate threat did not dominate tactical evaluation.")
	
	state.dispose()
	
	print("PASS: A next-player guaranteed win receives the full immediate-threat penalty.")


func test_blocking_immediate_win_is_preferred() -> void:
	var state:BotSimulationState = create_test_state(2)
	var evaluator:BotActionEvaluator = BotActionEvaluator.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add blocking setup token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add blocking setup token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add blocking setup token 3.")
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 10, 2)
	set_inventory(state, 1, TokenLibrary.TokenType.BASIC, 10, 1)
	
	var blocking_action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(3, 0))
	var ignoring_action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(5, 0))
	
	var blocking_evaluation:BotActionEvaluation = evaluate_action_from_state(evaluator, state, blocking_action, 1000)
	var ignoring_evaluation:BotActionEvaluation = evaluate_action_from_state(evaluator, state, ignoring_action, 2000)
	
	assert(blocking_evaluation.valid, blocking_evaluation.error_message)
	assert(ignoring_evaluation.valid, ignoring_evaluation.error_message)
	
	var blocking_outcome:BotActionOutcomeEvaluation = blocking_evaluation.outcome_evaluations[0]
	var ignoring_outcome:BotActionOutcomeEvaluation = ignoring_evaluation.outcome_evaluations[0]
	
	assert(blocking_outcome.has_opponent_immediate_threat(1) == false, "Blocking move still reports Player 1's horizontal win.")
	assert(ignoring_outcome.has_opponent_immediate_threat(1), "Ignoring move failed to expose Player 1's winning response.")
	assert(blocking_evaluation.final_score > ignoring_evaluation.final_score, "Blocking an immediate guaranteed loss should strongly outperform ignoring it.")
	
	state.dispose()
	
	print("PASS: Blocking an opponent's immediate win is strongly preferred over a superficially reasonable non-blocking move.")


func test_later_player_threat_is_discounted() -> void:
	var state:BotSimulationState = create_test_state(3)
	var evaluator:BotActionEvaluator = BotActionEvaluator.new()
	
	# Player 1: horizontal threat, acts next.
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add Player 1 threat token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add Player 1 threat token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add Player 1 threat token 3.")
	
	# Player 2: vertical threat, acts after Player 1.
	assert(add_token_to_state(state, Vector2i(6, 3), 2), "Could not add Player 2 threat token 1.")
	assert(add_token_to_state(state, Vector2i(6, 4), 2), "Could not add Player 2 threat token 2.")
	assert(add_token_to_state(state, Vector2i(6, 5), 2), "Could not add Player 2 threat token 3.")
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 10, 2)
	set_inventory(state, 1, TokenLibrary.TokenType.BASIC, 10, 1)
	set_inventory(state, 2, TokenLibrary.TokenType.BASIC, 10, 1)
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(4, 0))
	var evaluation:BotActionEvaluation = evaluate_action_from_state(evaluator, state, action)
	
	assert(evaluation.valid, evaluation.error_message)
	
	var outcome:BotActionOutcomeEvaluation = evaluation.outcome_evaluations[0]
	var player_one_penalty:float = outcome.get_opponent_threat_penalty(1)
	var player_two_penalty:float = outcome.get_opponent_threat_penalty(2)
	
	assert(outcome.get_opponent_turn_distance(1) == 1, "Player 1 should act next.")
	assert(outcome.get_opponent_turn_distance(2) == 2, "Player 2 should be two active turns away.")
	assert(player_one_penalty > player_two_penalty, "Next player's threat should be more urgent than the later player's equivalent threat.")
	assert(abs(player_one_penalty - BotActionEvaluator.IMMEDIATE_THREAT_BASE_PENALTY) < 0.0001, "Player 1 received the wrong threat penalty.")
	assert(abs(player_two_penalty - (BotActionEvaluator.IMMEDIATE_THREAT_BASE_PENALTY * BotActionEvaluator.THREAT_TURN_DISTANCE_FALLOFF)) < 0.0001, "Player 2 threat was not correctly turn-distance discounted.")
	
	state.dispose()
	
	print("PASS: Equivalent opponent threats are discounted according to active turn distance.")


func test_chameleon_outcomes_are_probability_weighted_and_resource_is_charged_once() -> void:
	var state:BotSimulationState = create_test_state(4)
	var evaluator:BotActionEvaluator = BotActionEvaluator.new()
	
	set_inventory(state, 0, TokenLibrary.TokenType.CHAMELEON, 2, 1)
	
	var action:BotAction = create_action(TokenLibrary.TokenType.CHAMELEON, Vector2i(3, 0))
	var evaluation:BotActionEvaluation = evaluate_action_from_state(evaluator, state, action, 123456)
	
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.chance_outcome_count == 3, "Four-player Chameleon should create three chance branches.")
	assert(evaluation.outcome_evaluations.size() == 3, "Chameleon outcome evaluations were not retained.")
	assert(abs(evaluation.probability_total - 1.0) < 0.0001, "Chameleon probabilities should total 1.")
	assert(evaluation.resource_penalty > 0.0, "Chameleon should carry a special-token resource cost.")
	
	for outcome in evaluation.outcome_evaluations:
		assert(abs(outcome.probability - (1.0 / 3.0)) < 0.0001, "Each four-player Chameleon outcome should have probability 1/3.")
	
	var recomputed_board_score:float = 0.0
	var recomputed_tactical_score:float = 0.0
	
	for outcome in evaluation.outcome_evaluations:
		recomputed_board_score += outcome.board_score * outcome.probability
		recomputed_tactical_score += outcome.tactical_adjustment * outcome.probability
	
	assert(abs(evaluation.expected_board_score - recomputed_board_score) < 0.0001, "Chameleon board branches were not probability weighted.")
	assert(abs(evaluation.expected_tactical_adjustment - recomputed_tactical_score) < 0.0001, "Chameleon tactical branches were not probability weighted.")
	
	var expected_final_score:float = evaluation.expected_board_score
	expected_final_score += evaluation.expected_tactical_adjustment
	expected_final_score -= evaluation.resource_penalty
	
	assert(abs(evaluation.final_score - expected_final_score) < 0.0001, "Chameleon resource cost was not applied exactly once after chance weighting.")
	
	state.dispose()
	
	print("PASS: Random Chameleon outcomes are probability-weighted while the committed token cost is charged once.")


func test_immediate_win_dominates_resource_cost() -> void:
	var state:BotSimulationState = create_test_state(2)
	var evaluator:BotActionEvaluator = BotActionEvaluator.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 0), "Could not add winning setup token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 0), "Could not add winning setup token 2.")
	assert(add_token_to_state(state, Vector2i(2, 5), 0), "Could not add winning setup token 3.")
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 3, 1)
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(3, 0))
	var evaluation:BotActionEvaluation = evaluate_action_from_state(evaluator, state, action)
	
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.is_guaranteed_win(), "Winning Basic action should have 100% win probability.")
	assert(abs(evaluation.win_probability - 1.0) < 0.0001, "Winning Basic action should have win probability 1.")
	assert(evaluation.expected_board_score == BotEvaluator.TERMINAL_WIN_SCORE, "Winning action did not receive the terminal board score.")
	assert(evaluation.resource_penalty > 0.0, "Final Basic copy should still register its opportunity cost.")
	assert(evaluation.final_score > 900000.0, "Resource preservation should never outweigh an immediate match win.")
	
	state.dispose()
	
	print("PASS: Immediate victory overwhelms normal resource-preservation concerns.")


func test_action_evaluation_does_not_mutate_source_state() -> void:
	var state:BotSimulationState = create_test_state(2)
	var evaluator:BotActionEvaluator = BotActionEvaluator.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add isolation token 1.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add isolation token 2.")
	
	set_inventory(state, 0, TokenLibrary.TokenType.BASIC, 10, 3)
	set_inventory(state, 1, TokenLibrary.TokenType.BASIC, 10, 2)
	
	var source_current_player_id:int = state.session.current_player_id
	var source_winner_id:int = state.session.winner_id
	var source_player_zero_basic_count:int = state.session.get_token_count(0, TokenLibrary.TokenType.BASIC)
	var source_player_one_basic_count:int = state.session.get_token_count(1, TokenLibrary.TokenType.BASIC)
	var source_board_token_count:int = count_board_tokens(state)
	
	var source_token_one:Token = state.board_state.get_token(Vector2i(0, 5))
	var source_token_two:Token = state.board_state.get_token(Vector2i(1, 5))
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(4, 0))
	var evaluation:BotActionEvaluation = evaluate_action_from_state(evaluator, state, action)
	
	assert(evaluation.valid, evaluation.error_message)
	
	assert(state.session.current_player_id == source_current_player_id, "Action evaluation changed the source current player.")
	assert(state.session.winner_id == source_winner_id, "Action evaluation changed the source winner.")
	assert(state.session.get_token_count(0, TokenLibrary.TokenType.BASIC) == source_player_zero_basic_count, "Action evaluation consumed source Player 0 inventory.")
	assert(state.session.get_token_count(1, TokenLibrary.TokenType.BASIC) == source_player_one_basic_count, "Threat analysis consumed source Player 1 inventory.")
	assert(count_board_tokens(state) == source_board_token_count, "Action evaluation changed the source board.")
	assert(state.board_state.get_token(Vector2i(0, 5)) == source_token_one, "Action evaluation replaced source token 1.")
	assert(state.board_state.get_token(Vector2i(1, 5)) == source_token_two, "Action evaluation replaced source token 2.")
	
	state.dispose()
	
	print("PASS: Complete action evaluation remains isolated from the source match state.")


func evaluate_action_from_state(evaluator:BotActionEvaluator, state:BotSimulationState, action:BotAction, seed:int = BotActionEvaluator.DEFAULT_EVALUATION_SEED) -> BotActionEvaluation:
	return evaluator.evaluate_action(
		state.session,
		state.board_state,
		state.settings,
		action,
		seed
	)


func create_test_state(player_count:int) -> BotSimulationState:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = 7
	settings.rows = 6
	settings.tokens_to_win = 4
	settings.gravity_direction = BoardSetting.GRID_DIRECTION.DOWN
	
	var session:MatchSession = create_test_session(player_count)
	var state:BotSimulationState = BotSimulationState.new()
	
	assert(state.setup(settings, session, 456789), "Could not setup action-evaluator test state.")
	
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
		assert(config.add_player("Test Player %d" % (player_id + 1), palettes[player_id]), "Could not add action-evaluator test Player %d." % player_id)
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not setup action-evaluator MatchSession.")
	
	for player_id in range(player_count):
		var player:MatchSessionPlayerData = session.get_player(player_id)
		
		assert(player != null, "Could not retrieve action-evaluator Player %d." % player_id)
		
		for token_type in TokenLibrary.get_all_token_types():
			player.set_starting_token_count(token_type, 0)
			player.set_token_count(token_type, 0)
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	assert(session.set_current_player(0), "Could not set Player 0 as action-evaluator current player.")
	
	return session


func set_inventory(state:BotSimulationState, player_id:int, token_type:int, starting_count:int, current_count:int) -> void:
	var player:MatchSessionPlayerData = state.session.get_player(player_id)
	
	assert(player != null, "Could not retrieve Player %d for action-evaluator inventory setup." % player_id)
	
	player.set_starting_token_count(token_type, starting_count)
	player.set_token_count(token_type, current_count)


func create_action(token_type:int, starting_slot:Vector2i, start_flipped:bool = false) -> BotAction:
	var action:BotAction = BotAction.new()
	action.setup(0, token_type, starting_slot, start_flipped)
	return action


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
