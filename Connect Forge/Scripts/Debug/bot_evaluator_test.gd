extends Node


func _ready() -> void:
	print("")
	print("========== BOT EVALUATOR TEST ==========")
	
	test_empty_board_is_neutral()
	test_own_and_opponent_positions_are_symmetric()
	test_connected_lines_are_more_valuable()
	test_contested_window_has_no_line_value()
	test_multiple_opponents_are_scored_separately()
	test_line_value_adapts_to_win_length()
	test_terminal_win_and_loss_scores()
	test_simulated_winning_move_receives_terminal_score()
	
	print("========== ALL BOT EVALUATOR TESTS PASSED ==========")
	print("")


func test_empty_board_is_neutral() -> void:
	var state:BotSimulationState = create_evaluation_state(2, 7, 6, 4)
	var evaluator:BotEvaluator = BotEvaluator.new()
	
	var evaluation:BotEvaluationResult = evaluator.evaluate_state(state, 0)
	
	assert(evaluation != null, "Empty-board evaluation returned null.")
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.terminal == false, "Empty board should not be terminal.")
	assert(abs(evaluation.score) < 0.0001, "Empty board should evaluate to zero.")
	assert(abs(evaluation.get_player_line_score(0)) < 0.0001, "Player 0 should have no line score on an empty board.")
	assert(abs(evaluation.get_player_line_score(1)) < 0.0001, "Player 1 should have no line score on an empty board.")
	assert(evaluation.total_windows > 0, "Evaluator found no valid winning windows.")
	
	state.dispose()
	
	print("PASS: Empty board evaluates as neutral.")


func test_own_and_opponent_positions_are_symmetric() -> void:
	var own_state:BotSimulationState = create_evaluation_state(2, 7, 6, 4)
	var opponent_state:BotSimulationState = create_evaluation_state(2, 7, 6, 4)
	var evaluator:BotEvaluator = BotEvaluator.new()
	
	assert(add_token_to_state(own_state, Vector2i(3, 5), 0), "Could not add own test token.")
	assert(add_token_to_state(opponent_state, Vector2i(3, 5), 1), "Could not add opponent test token.")
	
	var own_evaluation:BotEvaluationResult = evaluator.evaluate_state(own_state, 0)
	var opponent_evaluation:BotEvaluationResult = evaluator.evaluate_state(opponent_state, 0)
	
	assert(own_evaluation.valid, own_evaluation.error_message)
	assert(opponent_evaluation.valid, opponent_evaluation.error_message)
	
	assert(own_evaluation.score > 0.0, "Own uncontested token should produce a positive score.")
	assert(opponent_evaluation.score < 0.0, "Opponent uncontested token should produce a negative score.")
	assert(abs(own_evaluation.score + opponent_evaluation.score) < 0.0001, "Equivalent own and opponent positions should be symmetric.")
	
	own_state.dispose()
	opponent_state.dispose()
	
	print("PASS: Equivalent own and opponent board control is scored symmetrically.")


func test_connected_lines_are_more_valuable() -> void:
	var single_state:BotSimulationState = create_evaluation_state(2, 7, 6, 4)
	var connected_state:BotSimulationState = create_evaluation_state(2, 7, 6, 4)
	var evaluator:BotEvaluator = BotEvaluator.new()
	
	assert(add_token_to_state(single_state, Vector2i(2, 5), 0), "Could not add single test token.")
	
	assert(add_token_to_state(connected_state, Vector2i(2, 5), 0), "Could not add first connected token.")
	assert(add_token_to_state(connected_state, Vector2i(3, 5), 0), "Could not add second connected token.")
	
	var single_evaluation:BotEvaluationResult = evaluator.evaluate_state(single_state, 0)
	var connected_evaluation:BotEvaluationResult = evaluator.evaluate_state(connected_state, 0)
	
	assert(single_evaluation.valid, single_evaluation.error_message)
	assert(connected_evaluation.valid, connected_evaluation.error_message)
	
	assert(connected_evaluation.get_player_line_score(0) > single_evaluation.get_player_line_score(0), "Connected tokens should create stronger winning potential.")
	assert(connected_evaluation.score > single_evaluation.score, "Connected position should be preferred to the single-token position.")
	
	single_state.dispose()
	connected_state.dispose()
	
	print("PASS: Progress toward an uncontested winning line increases evaluation sharply.")


func test_contested_window_has_no_line_value() -> void:
	var state:BotSimulationState = create_evaluation_state(2, 7, 6, 4)
	var evaluator:BotEvaluator = BotEvaluator.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 0), "Could not add first own token.")
	assert(add_token_to_state(state, Vector2i(1, 5), 0), "Could not add second own token.")
	assert(add_token_to_state(state, Vector2i(2, 5), 1), "Could not add blocking opponent token.")
	
	var window:Dictionary = evaluator.evaluate_window(state.board_state, state.settings, Vector2i(0, 5), Vector2i(1, 0))
	
	assert(bool(window.get(BotEvaluator.WINDOW_VALID, false)), "Contested test window was invalid.")
	assert(bool(window.get(BotEvaluator.WINDOW_CONTESTED, false)), "Mixed-owner window was not identified as contested.")
	assert(bool(window.get(BotEvaluator.WINDOW_EMPTY, true)) == false, "Contested window should not be empty.")
	assert(abs(float(window.get(BotEvaluator.WINDOW_VALUE, -1.0))) < 0.0001, "Contested window should have zero strategic line value.")
	
	state.dispose()
	
	print("PASS: Mixed-owner winning windows are treated as blocked.")


func test_multiple_opponents_are_scored_separately() -> void:
	var state:BotSimulationState = create_evaluation_state(4, 7, 6, 4)
	var evaluator:BotEvaluator = BotEvaluator.new()
	
	assert(add_token_to_state(state, Vector2i(0, 5), 1), "Could not add Player 1 token A.")
	assert(add_token_to_state(state, Vector2i(1, 5), 1), "Could not add Player 1 token B.")
	
	assert(add_token_to_state(state, Vector2i(5, 0), 2), "Could not add Player 2 token A.")
	assert(add_token_to_state(state, Vector2i(6, 0), 2), "Could not add Player 2 token B.")
	
	var evaluation:BotEvaluationResult = evaluator.evaluate_state(state, 0)
	
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.get_player_line_score(1) > 0.0, "Player 1 received no independent threat score.")
	assert(evaluation.get_player_line_score(2) > 0.0, "Player 2 received no independent threat score.")
	assert(abs(evaluation.get_player_line_score(3)) < 0.0001, "Player 3 should have no line score.")
	
	var expected_score:float = evaluation.get_player_line_score(0)
	expected_score -= evaluation.get_player_line_score(1)
	expected_score -= evaluation.get_player_line_score(2)
	expected_score -= evaluation.get_player_line_score(3)
	
	assert(abs(evaluation.score - expected_score) < 0.0001, "Perspective score did not include each opponent independently.")
	assert(evaluation.score < 0.0, "Two opponent positions should be bad for Player 0.")
	
	state.dispose()
	
	print("PASS: Threats from multiple opponents remain separate and all affect evaluation.")


func test_line_value_adapts_to_win_length() -> void:
	var short_state:BotSimulationState = create_evaluation_state(2, 7, 6, 3)
	var long_state:BotSimulationState = create_evaluation_state(2, 7, 6, 5)
	var evaluator:BotEvaluator = BotEvaluator.new()
	
	assert(add_token_to_state(short_state, Vector2i(0, 5), 0), "Could not add first short-game token.")
	assert(add_token_to_state(short_state, Vector2i(1, 5), 0), "Could not add second short-game token.")
	
	assert(add_token_to_state(long_state, Vector2i(0, 5), 0), "Could not add first long-game token.")
	assert(add_token_to_state(long_state, Vector2i(1, 5), 0), "Could not add second long-game token.")
	
	var short_window:Dictionary = evaluator.evaluate_window(short_state.board_state, short_state.settings, Vector2i(0, 5), Vector2i(1, 0))
	var long_window:Dictionary = evaluator.evaluate_window(long_state.board_state, long_state.settings, Vector2i(0, 5), Vector2i(1, 0))
	
	assert(bool(short_window.get(BotEvaluator.WINDOW_VALID, false)), "Three-to-win window was invalid.")
	assert(bool(long_window.get(BotEvaluator.WINDOW_VALID, false)), "Five-to-win window was invalid.")
	
	var short_value:float = float(short_window.get(BotEvaluator.WINDOW_VALUE, 0.0))
	var long_value:float = float(long_window.get(BotEvaluator.WINDOW_VALUE, 0.0))
	
	assert(short_value > long_value, "Two tokens should be more urgent in a three-to-win game than a five-to-win game.")
	assert(abs(short_value - BotEvaluator.NEAR_WIN_LINE_SCORE) < 0.0001, "Two tokens in a three-to-win window should be one move from winning.")
	
	short_state.dispose()
	long_state.dispose()
	
	print("PASS: Winning-line values adapt to configurable win length.")


func test_terminal_win_and_loss_scores() -> void:
	var winning_state:BotSimulationState = create_evaluation_state(3, 7, 6, 4)
	var losing_state:BotSimulationState = create_evaluation_state(3, 7, 6, 4)
	var evaluator:BotEvaluator = BotEvaluator.new()
	
	assert(winning_state.session.set_winner_id(0), "Could not set Player 0 as winner.")
	assert(losing_state.session.set_winner_id(2), "Could not set Player 2 as winner.")
	
	var winning_evaluation:BotEvaluationResult = evaluator.evaluate_state(winning_state, 0)
	var losing_evaluation:BotEvaluationResult = evaluator.evaluate_state(losing_state, 0)
	
	assert(winning_evaluation.valid, winning_evaluation.error_message)
	assert(losing_evaluation.valid, losing_evaluation.error_message)
	
	assert(winning_evaluation.terminal, "Winning state should be terminal.")
	assert(losing_evaluation.terminal, "Losing state should be terminal.")
	assert(winning_evaluation.winner_id == 0, "Winning evaluation stored the wrong winner.")
	assert(losing_evaluation.winner_id == 2, "Losing evaluation stored the wrong winner.")
	assert(winning_evaluation.score == BotEvaluator.TERMINAL_WIN_SCORE, "Own win did not receive terminal win score.")
	assert(losing_evaluation.score == BotEvaluator.TERMINAL_LOSS_SCORE, "Opponent win did not receive terminal loss score.")
	
	winning_state.dispose()
	losing_state.dispose()
	
	print("PASS: Completed wins dominate all non-terminal board heuristics.")


func test_simulated_winning_move_receives_terminal_score() -> void:
	var settings:BoardSetting = create_settings(7, 6, 4)
	var session:MatchSession = create_match_session(2, 7, 6, 4)
	var source_board:BoardState = BoardState.new(settings)
	var source_token_root:Node2D = Node2D.new()
	
	source_board.setup_empty_board()
	
	assert(add_source_token(source_board, source_token_root, Vector2i(0, 5), 0), "Could not add winning setup token 1.")
	assert(add_source_token(source_board, source_token_root, Vector2i(1, 5), 0), "Could not add winning setup token 2.")
	assert(add_source_token(source_board, source_token_root, Vector2i(2, 5), 0), "Could not add winning setup token 3.")
	
	session.get_player(0).set_token_count(TokenLibrary.TokenType.BASIC, 5)
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	assert(session.set_current_player(0), "Could not set Player 0 as current player.")
	
	var action:BotAction = BotAction.new()
	action.setup(0, TokenLibrary.TokenType.BASIC, Vector2i(3, 0), false)
	
	var simulation_result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
	
	assert(simulation_result != null, "Winning simulation returned null.")
	assert(simulation_result.success, simulation_result.error_message)
	assert(simulation_result.winner_id == 0, "Winning simulation did not detect Player 0.")
	
	var evaluator:BotEvaluator = BotEvaluator.new()
	var evaluation:BotEvaluationResult = evaluator.evaluate_simulation_result(simulation_result, 0)
	
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.terminal, "Winning simulated result was not recognised as terminal.")
	assert(evaluation.winner_id == 0, "Evaluator stored the wrong simulated winner.")
	assert(evaluation.score == BotEvaluator.TERMINAL_WIN_SCORE, "Winning simulated move did not receive terminal win score.")
	
	simulation_result.dispose()
	source_token_root.free()
	
	print("PASS: Fully simulated winning actions flow directly into terminal evaluation.")


func create_evaluation_state(player_count:int, columns:int, rows:int, tokens_to_win:int) -> BotSimulationState:
	var settings:BoardSetting = create_settings(columns, rows, tokens_to_win)
	var session:MatchSession = create_match_session(player_count, columns, rows, tokens_to_win)
	var state:BotSimulationState = BotSimulationState.new()
	
	assert(state.setup(settings, session, 12345), "Could not create evaluation state.")
	
	return state


func create_settings(columns:int, rows:int, tokens_to_win:int) -> BoardSetting:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = columns
	settings.rows = rows
	settings.tokens_to_win = tokens_to_win
	settings.gravity_direction = BoardSetting.GRID_DIRECTION.DOWN
	return settings


func create_match_session(player_count:int, columns:int, rows:int, tokens_to_win:int) -> MatchSession:
	var config:MatchConfig = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = columns
	config.board_rows = rows
	config.tokens_to_win = tokens_to_win
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
		assert(config.add_player("Test Player %d" % (player_id + 1), palettes[player_id]), "Could not add test player %d." % player_id)
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not setup test MatchSession.")
	
	return session


func add_token_to_state(state:BotSimulationState, pos:Vector2i, player_id:int, token_type:int = TokenLibrary.TokenType.BASIC) -> bool:
	if state == null:
		return false
	
	var token:Token = create_test_token(token_type, pos, player_id)
	
	if token == null:
		return false
	
	if state.own_token(token) == false:
		token.free()
		return false
	
	if state.board_state.add_token(token, pos) == false:
		token.free()
		return false
	
	return true


func add_source_token(board_state:BoardState, token_root:Node2D, pos:Vector2i, player_id:int) -> bool:
	var token:Token = create_test_token(TokenLibrary.TokenType.BASIC, pos, player_id)
	
	if token == null:
		return false
	
	token_root.add_child(token)
	
	if board_state.add_token(token, pos) == false:
		token.free()
		return false
	
	return true


func create_test_token(token_type:int, pos:Vector2i, player_id:int) -> Token:
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return null
	
	var node:Node = token_scene.instantiate()
	
	if node == null:
		return null
	
	var token:Token = node as Token
	
	if token == null:
		node.free()
		return null
	
	token.setup_special_token()
	token.player_id = player_id
	token.token_pos = pos
	token.resolved = true
	token.being_destroyed = false
	token.board = null
	token.replay_token_id = -1
	
	return token
