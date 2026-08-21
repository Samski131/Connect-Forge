extends Node


func _ready() -> void:
	print("")
	print("========== BOT SIMULATOR TEST ==========")
	
	test_basic_action()
	test_invalid_action_is_rejected()
	test_ramp_chain_resolution()
	test_passing_trigger_resolution()
	test_bomb_self_destruction()
	test_tetromino_line_clear()
	test_chameleon_placement_data()
	test_winner_detection()
	
	print("========== ALL BOT SIMULATOR TESTS PASSED ==========")
	print("")


func test_basic_action() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var live_basic_count:int = session.get_token_count(0, TokenLibrary.TokenType.BASIC)
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(3, 0))
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
	
	assert(result != null, "Basic simulation returned null.")
	assert(result.success, result.error_message)
	assert(result.state != null, "Basic simulation returned no state.")
	assert(result.board != null, "Basic simulation returned no board.")
	
	var simulated_token:Token = result.board.get_token(Vector2i(3, 5))
	
	assert(simulated_token != null, "Basic token did not fall to the bottom.")
	assert(simulated_token.token_type == TokenLibrary.TokenType.BASIC, "Final token is not Basic.")
	assert(simulated_token.player_id == 0, "Final Basic token has the wrong owner.")
	assert(simulated_token.resolved, "Basic token did not finish resolved.")
	
	assert(result.state.session.get_token_count(0, TokenLibrary.TokenType.BASIC) == live_basic_count - 1, "Simulation did not consume one Basic token.")
	assert(session.get_token_count(0, TokenLibrary.TokenType.BASIC) == live_basic_count, "Simulation consumed a live Basic token.")
	assert(source_board.get_token(Vector2i(3, 5)) == null, "Simulation changed the live board.")
	assert(result.winner_id == -1, "Empty-board Basic placement unexpectedly produced a winner.")
	
	result.dispose()
	
	print("PASS: BotAction placement consumes simulated inventory and fully resolves gravity.")


func test_invalid_action_is_rejected() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var live_basic_count:int = session.get_token_count(1, TokenLibrary.TokenType.BASIC)
	
	var action:BotAction = BotAction.new()
	action.setup(1, TokenLibrary.TokenType.BASIC, Vector2i(2, 0), false)
	
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
	
	assert(result != null, "Invalid-action simulation returned null.")
	assert(result.success == false, "Action for the wrong current player should have been rejected.")
	assert(result.error_message != "", "Rejected action should contain an error message.")
	assert(session.get_token_count(1, TokenLibrary.TokenType.BASIC) == live_basic_count, "Rejected simulation changed live inventory.")
	assert(count_board_tokens(source_board, settings) == 0, "Rejected simulation changed the live board.")
	
	result.dispose()
	
	print("PASS: Illegal BotActions are rejected without changing live state.")


func test_ramp_chain_resolution() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	var live_ramp:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.RAMP, Vector2i(3, 5), 1)
	assert(live_ramp != null, "Could not create Ramp for simulation test.")
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(3, 0))
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
	
	assert(result != null, "Ramp simulation returned null.")
	assert(result.success, result.error_message)
	
	var redirected_token:Token = result.board.get_token(Vector2i(2, 5))
	var simulated_ramp:Token = result.board.get_token(Vector2i(3, 5))
	
	assert(redirected_token != null, "Ramp did not redirect the falling token.")
	assert(redirected_token.token_type == TokenLibrary.TokenType.BASIC, "Redirected token has the wrong type.")
	assert(redirected_token.player_id == 0, "Redirected token has the wrong player.")
	assert(redirected_token.resolved, "Redirected token did not continue resolving after Ramp movement.")
	
	assert(simulated_ramp != null, "Ramp disappeared from the simulated board.")
	assert(simulated_ramp.token_type == TokenLibrary.TokenType.RAMP, "Wrong token remained in Ramp slot.")
	
	assert(source_board.get_token(Vector2i(3, 5)) == live_ramp, "Ramp simulation changed the live Ramp.")
	assert(source_board.get_token(Vector2i(2, 5)) == null, "Ramp simulation changed the live board.")
	
	result.dispose()
	live_token_root.free()
	
	print("PASS: Ramp movement chains back into gravity and resolves to a stable state.")


func test_passing_trigger_resolution() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	# The Basic falls down column 3.
	# An unflipped Dagger triggers when a token passes on the Dagger's
	# RIGHT side, so the Dagger must sit to the LEFT of that column.
	var live_dagger:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.DAGGER, Vector2i(2, 5), 1)
	assert(live_dagger != null, "Could not create Dagger for passing test.")
	assert(live_dagger.charges == 1, "Test Dagger should begin with one charge.")
	assert(live_dagger.is_flipped == false, "Test Dagger should begin unflipped.")
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(3, 0))
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
	
	assert(result != null, "Passing-trigger simulation returned null.")
	assert(result.success, result.error_message)
	
	assert(result.board.get_token(Vector2i(3, 5)) == null, "Dagger did not destroy the passing Basic token.")
	
	var simulated_dagger:Token = result.board.get_token(Vector2i(2, 5))
	
	assert(simulated_dagger != null, "Simulated Dagger disappeared.")
	assert(simulated_dagger.charges == 0, "Dagger did not spend its charge.")
	assert(live_dagger.charges == 1, "Simulation spent the live Dagger's charge.")
	
	result.dispose()
	live_token_root.free()
	
	print("PASS: Queued passing triggers resolve through the real trigger system.")

func test_bomb_self_destruction() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	var live_neighbour:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.BASIC, Vector2i(2, 5), 1)
	assert(live_neighbour != null, "Could not create Bomb neighbour.")
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BOMB, Vector2i(3, 0))
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
	
	assert(result != null, "Bomb simulation returned null.")
	assert(result.success, result.error_message)
	
	assert(result.board.get_token(Vector2i(3, 5)) == null, "Bomb did not destroy itself.")
	assert(result.board.get_token(Vector2i(2, 5)) == null, "Bomb did not destroy its neighbour.")
	assert(count_board_tokens(result.state.board_state, result.state.settings) == 0, "Bomb simulation should leave this test board empty.")
	
	assert(source_board.get_token(Vector2i(2, 5)) == live_neighbour, "Bomb simulation destroyed the live neighbour.")
	
	result.dispose()
	live_token_root.free()
	
	print("PASS: Self-destroying token callbacks resolve safely without locked-object errors.")


func test_tetromino_line_clear() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	for x in range(6):
		var player_id:int = x % 2
		var token:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.BASIC, Vector2i(x, 5), player_id)
		assert(token != null, "Could not create token %d for Tetromino row." % x)
	
	assert(count_board_tokens(source_board, settings) == 6, "Tetromino source row should contain six tokens.")
	
	var action:BotAction = create_action(TokenLibrary.TokenType.TETROMINO, Vector2i(6, 0))
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
	
	assert(result != null, "Tetromino simulation returned null.")
	assert(result.success, result.error_message)
	assert(count_board_tokens(result.state.board_state, result.state.settings) == 0, "Tetromino did not clear the completed line.")
	assert(count_board_tokens(source_board, settings) == 6, "Tetromino simulation changed the live row.")
	
	result.dispose()
	live_token_root.free()
	
	print("PASS: On-line-full effects resolve as part of the normal action loop.")


func test_chameleon_placement_data() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var action:BotAction = create_action(TokenLibrary.TokenType.CHAMELEON, Vector2i(1, 0))
	action.set_placement_data({
		"fake_player_id": 1
	})
	
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
	
	assert(result != null, "Chameleon simulation returned null.")
	assert(result.success, result.error_message)
	
	var chameleon:Token = result.board.get_token(Vector2i(1, 5))
	
	assert(chameleon != null, "Chameleon did not reach the bottom.")
	assert(chameleon.token_type == TokenLibrary.TokenType.CHAMELEON, "Final token is not Chameleon.")
	assert(chameleon.get_network_placement_data().get("fake_player_id", -1) == 1, "Chameleon placement data was not applied.")
	
	var state_data:Dictionary = chameleon.create_network_state_data()
	
	assert(bool(state_data.get("has_transformed", false)), "Chameleon did not transform during simulation.")
	assert(int(state_data.get("fake_player_id", -1)) == 1, "Chameleon transformed into the wrong player's colour.")
	assert(chameleon.charges == 0, "Chameleon did not spend its charge.")
	
	assert(result.action.get_placement_data().get("fake_player_id", -1) == 1, "Resolved BotAction did not preserve placement data.")
	
	result.dispose()
	
	print("PASS: Generic placement data is applied before token resolution.")


func test_winner_detection() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	for x in range(3):
		var token:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.BASIC, Vector2i(x, 5), 0)
		assert(token != null, "Could not create winning-line setup token.")
	
	assert(session.winner_id == -1, "Live session should not already have a winner.")
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(3, 0))
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
	
	assert(result != null, "Winning simulation returned null.")
	assert(result.success, result.error_message)
	assert(result.winner_id == 0, "Simulator did not detect Player 0's winning move.")
	assert(result.winning_slots.size() == 4, "Winning result should contain four slots.")
	assert(result.state.session.winner_id == 0, "Simulated MatchSession did not store the winner.")
	assert(session.winner_id == -1, "Simulation changed the live MatchSession winner.")
	
	result.dispose()
	live_token_root.free()
	
	print("PASS: Stable simulated positions use the real win-detection logic.")


func create_test_settings() -> BoardSetting:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = 7
	settings.rows = 6
	settings.tokens_to_win = 4
	settings.gravity_direction = BoardSetting.GRID_DIRECTION.DOWN
	return settings


func create_test_session() -> MatchSession:
	var config:MatchConfig = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	config.turn_timer_seconds = 30
	config.starting_player_id = 0
	
	assert(config.add_player("Test Player 1", MatchData.YELLOW_PALETTE), "Could not add test player 1.")
	assert(config.add_player("Test Player 2", MatchData.RED_PALETTE), "Could not add test player 2.")
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not create test MatchSession.")
	
	var player_zero:MatchSessionPlayerData = session.get_player(0)
	assert(player_zero != null, "Could not get test player 0.")
	
	player_zero.set_token_count(TokenLibrary.TokenType.BASIC, 10)
	player_zero.set_token_count(TokenLibrary.TokenType.BOMB, 3)
	player_zero.set_token_count(TokenLibrary.TokenType.CHAMELEON, 3)
	player_zero.set_token_count(TokenLibrary.TokenType.DAGGER, 3)
	player_zero.set_token_count(TokenLibrary.TokenType.DRILL, 3)
	player_zero.set_token_count(TokenLibrary.TokenType.FAN, 3)
	player_zero.set_token_count(TokenLibrary.TokenType.PYRE, 3)
	player_zero.set_token_count(TokenLibrary.TokenType.RAMP, 3)
	player_zero.set_token_count(TokenLibrary.TokenType.ROTATE_GRAVITY, 3)
	player_zero.set_token_count(TokenLibrary.TokenType.TETROMINO, 3)
	player_zero.set_token_count(TokenLibrary.TokenType.ANVIL, 3)
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	assert(session.set_current_player(0), "Could not set Player 0 as current player.")
	
	return session


func create_empty_board_state(settings:BoardSetting) -> BoardState:
	var board_state:BoardState = BoardState.new(settings)
	board_state.setup_empty_board()
	return board_state


func create_action(token_type:int, starting_slot:Vector2i, start_flipped:bool = false) -> BotAction:
	var action:BotAction = BotAction.new()
	action.setup(0, token_type, starting_slot, start_flipped)
	return action


func add_source_token(board_state:BoardState, token_root:Node2D, token_type:int, pos:Vector2i, player_id:int, flipped:bool = false) -> Token:
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return null
	
	var new_node:Node = token_scene.instantiate()
	
	if new_node == null:
		return null
	
	var token:Token = new_node as Token
	
	if token == null:
		new_node.free()
		return null
	
	token_root.add_child(token)
	token.setup_special_token()
	
	token.player_id = player_id
	token.token_pos = pos
	token.board = null
	token.resolved = false
	token.being_destroyed = false
	token.is_flipped = flipped
	token.replay_token_id = -1
	
	if board_state.add_token(token, pos) == false:
		token.free()
		return null
	
	return token


func count_board_tokens(board_state:BoardState, settings:BoardSetting) -> int:
	var count:int = 0
	
	for y in range(settings.rows):
		for x in range(settings.columns):
			if board_state.get_token(Vector2i(x, y)) != null:
				count += 1
	
	return count
