extends Node


func _ready() -> void:
	print("")
	print("========== BOT HEADLESS BOARD TEST ==========")
	
	test_headless_board_binding()
	test_relative_directions()
	test_real_gravity_movement()
	test_headless_token_creation()
	test_immediate_destruction()
	test_real_pyre_impact()
	test_rotate_gravity_is_isolated()
	
	print("========== ALL BOT HEADLESS BOARD TESTS PASSED ==========")
	print("")


func test_headless_board_binding() -> void:
	var settings:BoardSetting = create_test_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	var live_token:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.BASIC, Vector2i(3, 5), 0)
	assert(live_token != null, "Could not create source Basic token.")
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, source_board, settings)
	assert(simulation != null, "Could not clone simulation state.")
	
	var board:BotSimulationBoard = BotSimulationBoard.new()
	assert(board.setup_from_state(simulation), "Could not set up headless simulation board.")
	
	assert(board is BoardManager, "BotSimulationBoard must remain compatible with BoardManager.")
	assert(board.settings == simulation.settings, "Headless board is not using simulation settings.")
	assert(board.state == simulation.board_state, "Headless board is not using simulation BoardState.")
	assert(board.match_session == simulation.session, "Headless board is not using simulation MatchSession.")
	assert(board.token_pool == simulation.token_root, "Headless board is not using the simulation token root.")
	assert(board.visuals == null, "Headless board must not have BoardVisualManager.")
	assert(board.get_replay_recorder() == null, "Headless board must not have ReplayRecorder.")
	assert(board.trigger_resolver != null, "Headless board has no trigger resolver.")
	assert(board.token_mover != null, "Headless board has no token mover.")
	assert(board.token_mover is BotSimulationTokenMover, "Headless board is not using BotSimulationTokenMover.")
	
	var simulated_token:Token = board.get_token(Vector2i(3, 5))
	assert(simulated_token != null, "Simulated token was not found.")
	assert(simulated_token != live_token, "Simulation is using the live token instance.")
	assert(simulated_token.board == board, "Simulated token was not attached to the headless board.")
	assert(live_token.board == null, "Binding the simulation changed the live token's board reference.")
	
	board.dispose()
	board.free()
	simulation.dispose()
	live_token_root.free()
	
	print("PASS: Cloned state binds to an isolated headless BoardManager.")


func test_relative_directions() -> void:
	var settings:BoardSetting = create_test_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, source_board, settings)
	assert(simulation != null, "Could not clone relative-direction test state.")
	
	var board:BotSimulationBoard = BotSimulationBoard.new()
	assert(board.setup_from_state(simulation), "Could not set up relative-direction board.")
	
	var origin:Vector2i = Vector2i(3, 3)
	
	assert(board.get_relative_adjacent_pos(origin.x, origin.y, BoardSetting.RELATIVE_DIRECTION.DOWN) == Vector2i(3, 4), "Relative DOWN is wrong with DOWN gravity.")
	assert(board.get_relative_adjacent_pos(origin.x, origin.y, BoardSetting.RELATIVE_DIRECTION.RIGHT) == Vector2i(4, 3), "Relative RIGHT is wrong with DOWN gravity.")
	
	assert(board.set_gravity_direction(BoardSetting.GRID_DIRECTION.RIGHT, false), "Could not change simulated gravity to RIGHT.")
	
	assert(board.get_relative_adjacent_pos(origin.x, origin.y, BoardSetting.RELATIVE_DIRECTION.DOWN) == Vector2i(4, 3), "Relative DOWN is wrong with RIGHT gravity.")
	assert(board.get_relative_adjacent_pos(origin.x, origin.y, BoardSetting.RELATIVE_DIRECTION.RIGHT) == Vector2i(3, 2), "Relative RIGHT is wrong with RIGHT gravity.")
	
	board.dispose()
	board.free()
	simulation.dispose()
	
	print("PASS: Headless board uses the real gravity-relative board geometry.")


func test_real_gravity_movement() -> void:
	var settings:BoardSetting = create_test_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	assert(add_source_token(source_board, live_token_root, TokenLibrary.TokenType.BASIC, Vector2i(3, 0), 0) != null, "Could not create gravity test token.")
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, source_board, settings)
	assert(simulation != null, "Could not clone gravity test state.")
	
	var board:BotSimulationBoard = BotSimulationBoard.new()
	assert(board.setup_from_state(simulation), "Could not set up gravity test board.")
	
	var token:Token = board.get_token(Vector2i(3, 0))
	assert(token != null, "Gravity test token was not found.")
	
	var moved:bool = board.token_mover.try_apply_gravity_to_token(token)
	
	assert(moved, "Real BoardTokenMover did not apply gravity.")
	assert(token.token_pos == Vector2i(3, 5), "Token did not fall to the bottom of the board.")
	assert(board.get_token(Vector2i(3, 0)) == null, "Old board position was not cleared.")
	assert(board.get_token(Vector2i(3, 5)) == token, "Destination does not contain the moved token.")
	assert(board.visuals == null, "Gravity movement unexpectedly enabled visuals.")
	assert(board.get_replay_recorder() == null, "Gravity movement unexpectedly enabled replay recording.")
	
	board.dispose()
	board.free()
	simulation.dispose()
	live_token_root.free()
	
	print("PASS: Real BoardTokenMover gravity movement runs headlessly.")


func test_headless_token_creation() -> void:
	var settings:BoardSetting = create_test_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, source_board, settings)
	assert(simulation != null, "Could not clone token-creation test state.")
	
	var board:BotSimulationBoard = BotSimulationBoard.new()
	assert(board.setup_from_state(simulation), "Could not set up token-creation test board.")
	
	var ramp_scene:PackedScene = TokenLibrary.get_token_scene(TokenLibrary.TokenType.RAMP)
	assert(ramp_scene != null, "Ramp scene was not found.")
	
	var new_token:Token = board.create_new_token(ramp_scene, Vector2i(2, 0), 0, true)
	
	assert(new_token != null, "Headless board could not create a token.")
	assert(new_token.token_type == TokenLibrary.TokenType.RAMP, "Created token has the wrong type.")
	assert(new_token.player_id == 0, "Created token has the wrong player.")
	assert(new_token.token_pos == Vector2i(2, 0), "Created token has the wrong position.")
	assert(new_token.is_flipped, "Created Ramp did not preserve flipped state.")
	assert(new_token.board == board, "Created token is not attached to the headless board.")
	assert(new_token.get_parent() == simulation.token_root, "Created token is not owned by the simulation token root.")
	assert(board.get_token(Vector2i(2, 0)) == new_token, "Created token was not inserted into BoardState.")
	assert(new_token.replay_token_id == -1, "Simulation token received a replay ID.")
	assert(new_token.visible == false, "Simulation-created token should remain hidden.")
	
	board.dispose()
	board.free()
	simulation.dispose()
	
	print("PASS: Tokens can be created headlessly without replay or presentation ownership.")


func test_immediate_destruction() -> void:
	var settings:BoardSetting = create_test_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	assert(add_source_token(source_board, live_token_root, TokenLibrary.TokenType.BASIC, Vector2i(2, 4), 0) != null, "Could not create destruction test token.")
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, source_board, settings)
	assert(simulation != null, "Could not clone destruction test state.")
	
	var board:BotSimulationBoard = BotSimulationBoard.new()
	assert(board.setup_from_state(simulation), "Could not set up destruction test board.")
	
	var token:Token = board.get_token(Vector2i(2, 4))
	assert(token != null, "Destruction test token was not found.")
	
	assert(board.destroy_token(token), "Headless destruction returned false.")
	assert(board.get_token(Vector2i(2, 4)) == null, "Destroyed token remained in BoardState.")
	assert(is_instance_valid(token) == false, "Headless destruction must free the token immediately.")
	
	board.dispose()
	board.free()
	simulation.dispose()
	live_token_root.free()
	
	print("PASS: Headless token destruction is immediate and synchronous.")


func test_real_pyre_impact() -> void:
	var settings:BoardSetting = create_test_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	var live_landing_token:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.BASIC, Vector2i(3, 4), 0)
	var live_pyre:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.PYRE, Vector2i(3, 5), 1)
	
	assert(live_landing_token != null, "Could not create live landing token.")
	assert(live_pyre != null, "Could not create live Pyre.")
	
	var live_pyre_charges:int = live_pyre.charges
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, source_board, settings)
	assert(simulation != null, "Could not clone Pyre test state.")
	
	var board:BotSimulationBoard = BotSimulationBoard.new()
	assert(board.setup_from_state(simulation), "Could not set up Pyre test board.")
	
	var landing_token:Token = board.get_token(Vector2i(3, 4))
	var pyre:Token = board.get_token(Vector2i(3, 5))
	
	assert(landing_token != null, "Simulated landing token was not found.")
	assert(pyre != null, "Simulated Pyre was not found.")
	assert(pyre.charges == 1, "Pyre should begin with one charge.")
	
	var triggered:bool = board.trigger_resolver.resolve_impact_trigger_for_token(landing_token)
	
	assert(triggered, "Real Pyre ON_IMPACT behaviour did not trigger.")
	assert(board.get_token(Vector2i(3, 4)) == null, "Pyre did not destroy the landing token.")
	assert(is_instance_valid(landing_token) == false, "Pyre destruction was not immediate.")
	assert(pyre.charges == 0, "Pyre did not spend its charge.")
	
	assert(source_board.get_token(Vector2i(3, 4)) == live_landing_token, "Simulated Pyre destroyed the live landing token.")
	assert(source_board.get_token(Vector2i(3, 5)) == live_pyre, "Simulated Pyre changed the live Pyre position.")
	assert(live_pyre.charges == live_pyre_charges, "Simulated Pyre spent the live Pyre's charge.")
	
	board.dispose()
	board.free()
	simulation.dispose()
	live_token_root.free()
	
	print("PASS: Real token impact behaviour resolves correctly on the headless board.")


func test_rotate_gravity_is_isolated() -> void:
	var settings:BoardSetting = create_test_settings(BoardSetting.GRID_DIRECTION.DOWN)
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	var live_rotate_token:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.ROTATE_GRAVITY, Vector2i(3, 5), 0)
	var live_other_token:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.BASIC, Vector2i(1, 5), 1)
	
	assert(live_rotate_token != null, "Could not create live Rotate Gravity token.")
	assert(live_other_token != null, "Could not create live Basic token.")
	
	live_rotate_token.resolved = true
	live_other_token.resolved = true
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, source_board, settings)
	assert(simulation != null, "Could not clone gravity-isolation test state.")
	
	var board:BotSimulationBoard = BotSimulationBoard.new()
	assert(board.setup_from_state(simulation), "Could not set up gravity-isolation board.")
	
	var rotate_token:Token = board.get_token(Vector2i(3, 5))
	var simulated_other_token:Token = board.get_token(Vector2i(1, 5))
	
	assert(rotate_token != null, "Simulated Rotate Gravity token was not found.")
	assert(simulated_other_token != null, "Simulated Basic token was not found.")
	
	rotate_token.resolved = true
	simulated_other_token.resolved = true
	
	# This token is deliberately in the real SceneTree and in the "token"
	# group. The simulation must not reset it via a global group call.
	var scene_tree_sentinel:Token = Token.new()
	scene_tree_sentinel.resolved = true
	add_child(scene_tree_sentinel)
	scene_tree_sentinel.add_to_group("token")
	
	var changed_board:bool = board.trigger_resolver.resolve_landing_triggers(rotate_token)
	
	assert(changed_board, "Rotate Gravity ON_LAND behaviour did not trigger.")
	assert(simulation.settings.gravity_direction == BoardSetting.GRID_DIRECTION.LEFT, "Clockwise rotation from DOWN should produce LEFT gravity.")
	assert(settings.gravity_direction == BoardSetting.GRID_DIRECTION.DOWN, "Simulation gravity changed the live BoardSetting.")
	
	assert(rotate_token.charges == 0, "Rotate Gravity did not spend its charge.")
	assert(rotate_token.resolved == false, "Simulation gravity change did not reset simulated Rotate Gravity token.")
	assert(simulated_other_token.resolved == false, "Simulation gravity change did not reset other simulated tokens.")
	
	assert(live_rotate_token.resolved, "Simulation gravity reset the live Rotate Gravity token.")
	assert(live_other_token.resolved, "Simulation gravity reset the live Basic token.")
	assert(scene_tree_sentinel.resolved, "Simulation gravity used a global SceneTree token reset.")
	
	scene_tree_sentinel.free()
	
	board.dispose()
	board.free()
	simulation.dispose()
	live_token_root.free()
	
	print("PASS: Rotate Gravity uses real token rules without touching live SceneTree state.")


func create_test_settings(gravity_direction:BoardSetting.GRID_DIRECTION) -> BoardSetting:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = 7
	settings.rows = 6
	settings.tokens_to_win = 4
	settings.gravity_direction = gravity_direction
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
	return session


func create_empty_board_state(settings:BoardSetting) -> BoardState:
	var board_state:BoardState = BoardState.new(settings)
	board_state.setup_empty_board()
	return board_state


func add_source_token(board_state:BoardState, token_root:Node2D, token_type:int, pos:Vector2i, player_id:int) -> Token:
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
	token.is_flipped = false
	token.replay_token_id = -1
	
	if board_state.add_token(token, pos) == false:
		token.free()
		return null
	
	return token
