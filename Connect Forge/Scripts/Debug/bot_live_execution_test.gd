extends Node

var selected_actions:Array[BotAction] = []
var executed_actions:Array[BotAction] = []
var execution_results:Array[bool] = []


func _ready() -> void:
	print("")
	print("========== BOT LIVE EXECUTION TEST ==========")
	
	test_bot_manager_selects_and_executes_real_local_move()
	test_real_execution_preserves_flipped_state()
	test_explicit_placement_data_reaches_real_token()
	test_human_action_cannot_use_bot_execution_path()
	test_network_match_refuses_local_bot_execution()
	
	print("========== ALL BOT LIVE EXECUTION TESTS PASSED ==========")
	print("")


func test_bot_manager_selects_and_executes_real_local_move() -> void:
	clear_signal_records()
	
	var context:Dictionary = create_live_test_context()
	var game_manager:GameManager = context["game_manager"] as GameManager
	var board:BoardManager = context["board"] as BoardManager
	var session:MatchSession = context["session"] as MatchSession
	
	set_inventory(session, 1, TokenLibrary.TokenType.BASIC, 1, 1)
	
	assert(session.set_current_player(1), "Could not select Duncan.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	var manager:BotManager = BotManager.new()
	add_child(manager)
	
	manager.bot_action_selected.connect(_on_bot_action_selected)
	manager.bot_action_executed.connect(_on_bot_action_executed)
	
	# Disable deferred automatic execution in this unit test so we can
	# invoke the exact production turn method synchronously.
	manager.setup(session, game_manager, false)
	
	var count_before:int = session.get_token_count(
		1,
		TokenLibrary.TokenType.BASIC
	)
	
	var executed:bool = manager.try_run_bot_turn(1, 123456)
	
	assert(executed, "BotManager failed to execute Duncan's selected move.")
	assert(selected_actions.size() == 1, "BotManager did not report exactly one selected action.")
	assert(executed_actions.size() == 1, "BotManager did not report exactly one executed action.")
	assert(execution_results.size() == 1, "BotManager did not report exactly one execution result.")
	assert(execution_results[0], "BotManager reported that live execution failed.")
	
	var selected_action:BotAction = selected_actions[0]
	
	assert(selected_action != null, "Selected BotAction is null.")
	assert(selected_action.player_id == 1, "Duncan selected an action for the wrong player.")
	assert(selected_action.token_type == TokenLibrary.TokenType.BASIC, "Duncan should only have been able to select Basic.")
	
	var real_token:Token = board.get_token(selected_action.starting_slot)
	
	assert(real_token != null, "Selected action did not create a real board token.")
	assert(real_token.player_id == 1, "Real board token belongs to the wrong player.")
	assert(real_token.token_type == TokenLibrary.TokenType.BASIC, "Real board token has the wrong token type.")
	
	assert(
		session.get_token_count(1, TokenLibrary.TokenType.BASIC) == count_before - 1,
		"Real bot execution did not consume exactly one token."
	)
	
	assert(
		session.current_turn_phase == Global.TURN_PHASE.ACTION,
		"Real bot placement did not enter the normal action phase."
	)
	
	manager.dispose()
	manager.free()
	cleanup_live_test_context(context)
	
	print("PASS: BotManager selects and submits a real local move through normal PlacementLogic.")


func test_real_execution_preserves_flipped_state() -> void:
	var context:Dictionary = create_live_test_context()
	var game_manager:GameManager = context["game_manager"] as GameManager
	var board:BoardManager = context["board"] as BoardManager
	var session:MatchSession = context["session"] as MatchSession
	
	set_inventory(session, 1, TokenLibrary.TokenType.RAMP, 1, 1)
	
	assert(session.set_current_player(1), "Could not select Duncan for flipped test.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	var action:BotAction = BotAction.new()
	action.setup(
		1,
		TokenLibrary.TokenType.RAMP,
		Vector2i(3, 0),
		true
	)
	
	var executed:bool = game_manager.try_execute_bot_action(action)
	
	assert(executed, "Could not execute flipped Ramp bot action.")
	
	var real_token:Token = board.get_token(Vector2i(3, 0))
	
	assert(real_token != null, "Flipped Ramp was not created on the real board.")
	assert(real_token.token_type == TokenLibrary.TokenType.RAMP, "Created token is not a Ramp.")
	assert(real_token.is_flipped, "BotAction flipped state was lost during real placement.")
	assert(session.get_token_count(1, TokenLibrary.TokenType.RAMP) == 0, "Flipped Ramp inventory was not consumed.")
	
	cleanup_live_test_context(context)
	
	print("PASS: BotAction flipped state survives the real local placement path.")


func test_explicit_placement_data_reaches_real_token() -> void:
	var context:Dictionary = create_live_test_context()
	var game_manager:GameManager = context["game_manager"] as GameManager
	var board:BoardManager = context["board"] as BoardManager
	var session:MatchSession = context["session"] as MatchSession
	
	set_inventory(session, 1, TokenLibrary.TokenType.CHAMELEON, 1, 1)
	
	assert(session.set_current_player(1), "Could not select Duncan for placement-data test.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	var action:BotAction = BotAction.new()
	action.setup(
		1,
		TokenLibrary.TokenType.CHAMELEON,
		Vector2i(3, 0),
		false
	)
	
	action.set_placement_data({
		"fake_player_id": 0
	})
	
	var executed:bool = game_manager.try_execute_bot_action(action)
	
	assert(executed, "Could not execute Chameleon bot action.")
	
	var real_token:Token = board.get_token(Vector2i(3, 0))
	
	assert(real_token != null, "Chameleon was not created on the real board.")
	assert(real_token.token_type == TokenLibrary.TokenType.CHAMELEON, "Created token is not a Chameleon.")
	
	var placement_data:Dictionary = real_token.get_network_placement_data()
	
	assert(placement_data.has("fake_player_id"), "Real Chameleon lost its placement data.")
	assert(int(placement_data["fake_player_id"]) == 0, "Real Chameleon received the wrong placement data.")
	assert(session.get_token_count(1, TokenLibrary.TokenType.CHAMELEON) == 0, "Chameleon inventory was not consumed.")
	
	cleanup_live_test_context(context)
	
	print("PASS: Generic BotAction placement data is applied to the real placed token.")


func test_human_action_cannot_use_bot_execution_path() -> void:
	var context:Dictionary = create_live_test_context()
	var game_manager:GameManager = context["game_manager"] as GameManager
	var board:BoardManager = context["board"] as BoardManager
	var session:MatchSession = context["session"] as MatchSession
	
	set_inventory(session, 0, TokenLibrary.TokenType.BASIC, 2, 2)
	
	assert(session.set_current_player(0), "Could not select local human.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	var action:BotAction = BotAction.new()
	action.setup(
		0,
		TokenLibrary.TokenType.BASIC,
		Vector2i(3, 0),
		false
	)
	
	var count_before:int = session.get_token_count(0, TokenLibrary.TokenType.BASIC)
	var executed:bool = game_manager.try_execute_bot_action(action)
	
	assert(executed == false, "Human player was incorrectly accepted by the bot execution path.")
	assert(session.get_token_count(0, TokenLibrary.TokenType.BASIC) == count_before, "Rejected human bot-action consumed inventory.")
	assert(board.get_token(Vector2i(3, 0)) == null, "Rejected human bot-action changed the board.")
	
	cleanup_live_test_context(context)
	
	print("PASS: Bot execution path cannot be used to submit a human player's move.")


func test_network_match_refuses_local_bot_execution() -> void:
	var context:Dictionary = create_live_test_context()
	var game_manager:GameManager = context["game_manager"] as GameManager
	var board:BoardManager = context["board"] as BoardManager
	var session:MatchSession = context["session"] as MatchSession
	
	set_inventory(session, 1, TokenLibrary.TokenType.BASIC, 1, 1)
	
	assert(session.set_current_player(1), "Could not select Duncan for network guard test.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	var network_controller:NetworkMatchController = NetworkMatchController.new()
	network_controller.network_active = true
	game_manager.network_match_controller = network_controller
	
	var action:BotAction = BotAction.new()
	action.setup(
		1,
		TokenLibrary.TokenType.BASIC,
		Vector2i(3, 0),
		false
	)
	
	var count_before:int = session.get_token_count(1, TokenLibrary.TokenType.BASIC)
	var executed:bool = game_manager.try_execute_bot_action(action)
	
	assert(executed == false, "Local bot path should refuse execution in a network match.")
	assert(session.get_token_count(1, TokenLibrary.TokenType.BASIC) == count_before, "Rejected network bot move consumed inventory.")
	assert(board.get_token(Vector2i(3, 0)) == null, "Rejected network bot move changed the board.")
	
	game_manager.network_match_controller = null
	network_controller.free()
	
	cleanup_live_test_context(context)
	
	print("PASS: Local bot execution is disabled in network matches pending host-authoritative integration.")


func create_live_test_context() -> Dictionary:
	var config:MatchConfig = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	config.turn_timer_seconds = 30
	config.starting_player_id = 0
	
	assert(
		config.add_player(
			"Human",
			MatchData.YELLOW_PALETTE,
			MatchPlayerData.CONTROLLER_TYPE.LOCAL_HUMAN
		),
		"Could not add local human."
	)
	
	assert(
		config.add_bot(
			"duncan",
			MatchData.RED_PALETTE,
			MatchPlayerData.BOT_DIFFICULTY.NORMAL
		),
		"Could not add Duncan."
	)
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not setup live bot test MatchSession.")
	
	for player_id in range(session.get_player_count()):
		var player:MatchSessionPlayerData = session.get_player(player_id)
		
		assert(player != null, "Could not retrieve live test Player %d." % player_id)
		
		for token_type in TokenLibrary.get_all_token_types():
			player.set_starting_token_count(token_type, 0)
			player.set_token_count(token_type, 0)
	
	var board:BoardManager = BoardManager.new()
	board.name = "Live Bot Test Board"
	
	board.settings.columns = 7
	board.settings.rows = 6
	board.settings.tokens_to_win = 4
	board.settings.gravity_direction = BoardSetting.GRID_DIRECTION.DOWN
	
	var token_pool:Node2D = Node2D.new()
	token_pool.name = "Token Pool"
	board.add_child(token_pool)
	
	add_child(board)
	
	board.setup(token_pool, null)
	board.set_match_session(session)
	board.setup_empty_board_state()
	
	var game_manager:GameManager = GameManager.new()
	game_manager.name = "Live Bot Test Game Manager"
	
	var placement_state:PlacementLogic = PlacementLogic.new()
	placement_state.name = "Placement State"
	
	var action_state:ActionLogic = ActionLogic.new()
	action_state.name = "Action State"
	
	var resolution_state:ResolutionLogic = ResolutionLogic.new()
	resolution_state.name = "Resolution State"
	
	game_manager.add_child(placement_state)
	game_manager.add_child(action_state)
	game_manager.add_child(resolution_state)
	
	add_child(game_manager)
	
	game_manager.session = session
	game_manager.board = board
	
	game_manager.setup_states()
	
	return {
		"session": session,
		"board": board,
		"game_manager": game_manager
	}


func cleanup_live_test_context(context:Dictionary) -> void:
	var game_manager:GameManager = context.get("game_manager", null) as GameManager
	var board:BoardManager = context.get("board", null) as BoardManager
	
	if game_manager != null and is_instance_valid(game_manager):
		game_manager.free()
	
	if board != null and is_instance_valid(board):
		board.free()


func set_inventory(session:MatchSession, player_id:int, token_type:int, starting_count:int, current_count:int) -> void:
	var player:MatchSessionPlayerData = session.get_player(player_id)
	
	assert(player != null, "Could not retrieve Player %d for inventory setup." % player_id)
	
	player.set_starting_token_count(token_type, starting_count)
	player.set_token_count(token_type, current_count)


func clear_signal_records() -> void:
	selected_actions.clear()
	executed_actions.clear()
	execution_results.clear()


func _on_bot_action_selected(_player_id:int, action:BotAction, _score:float) -> void:
	if action == null:
		return
	
	selected_actions.append(action.duplicate_action())


func _on_bot_action_executed(_player_id:int, action:BotAction, success:bool) -> void:
	if action != null:
		executed_actions.append(action.duplicate_action())
	
	execution_results.append(success)
