extends Node

const REPEAT_SIMULATION_COUNT:int = 25


func _ready() -> void:
	print("")
	print("========== BOT SIMULATION ISOLATION TEST ==========")
	
	test_parallel_branches_are_independent()
	test_disposing_one_branch_does_not_damage_others()
	test_failed_simulations_release_resources()
	test_repeated_simulation_does_not_change_source()
	test_every_generated_action_resolves_independently()
	test_result_action_is_an_independent_copy()
	
	print("========== ALL BOT SIMULATION ISOLATION TESTS PASSED ==========")
	print("")


func test_parallel_branches_are_independent() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var live_basic_count:int = session.get_token_count(0, TokenLibrary.TokenType.BASIC)
	var live_rotate_count:int = session.get_token_count(0, TokenLibrary.TokenType.ROTATE_GRAVITY)
	
	var rotate_action:BotAction = create_action(TokenLibrary.TokenType.ROTATE_GRAVITY, Vector2i(3, 0))
	var basic_action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(5, 0))
	
	var rotate_result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, rotate_action)
	var basic_result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, basic_action)
	
	assert(rotate_result != null, "Rotate branch returned null.")
	assert(basic_result != null, "Basic branch returned null.")
	assert(rotate_result.success, rotate_result.error_message)
	assert(basic_result.success, basic_result.error_message)
	
	assert(rotate_result.state != basic_result.state, "Two simulations share the same BotSimulationState.")
	assert(rotate_result.board != basic_result.board, "Two simulations share the same BotSimulationBoard.")
	assert(rotate_result.state.settings != basic_result.state.settings, "Two simulations share BoardSetting.")
	assert(rotate_result.state.session != basic_result.state.session, "Two simulations share MatchSession.")
	assert(rotate_result.state.board_state != basic_result.state.board_state, "Two simulations share BoardState.")
	assert(rotate_result.state.token_root != basic_result.state.token_root, "Two simulations share their token root.")
	
	var rotate_player:MatchSessionPlayerData = rotate_result.state.session.get_player(0)
	var basic_player:MatchSessionPlayerData = basic_result.state.session.get_player(0)
	var live_player:MatchSessionPlayerData = session.get_player(0)
	
	assert(rotate_player != null, "Rotate branch has no Player 0.")
	assert(basic_player != null, "Basic branch has no Player 0.")
	assert(live_player != null, "Live session has no Player 0.")
	assert(rotate_player != basic_player, "Simulation branches share MatchSessionPlayerData.")
	assert(rotate_player != live_player, "Rotate branch shares the live player instance.")
	assert(basic_player != live_player, "Basic branch shares the live player instance.")
	
	# The Rotate Gravity branch should change only its own gravity.
	assert(rotate_result.state.settings.gravity_direction == BoardSetting.GRID_DIRECTION.LEFT, "Rotate branch did not finish with LEFT gravity.")
	assert(basic_result.state.settings.gravity_direction == BoardSetting.GRID_DIRECTION.DOWN, "Rotate branch changed Basic branch gravity.")
	assert(settings.gravity_direction == BoardSetting.GRID_DIRECTION.DOWN, "Rotate branch changed live gravity.")
	
	# Each branch should spend only its own chosen resource.
	assert(rotate_result.state.session.get_token_count(0, TokenLibrary.TokenType.ROTATE_GRAVITY) == live_rotate_count - 1, "Rotate branch did not spend one Rotate Gravity token.")
	assert(rotate_result.state.session.get_token_count(0, TokenLibrary.TokenType.BASIC) == live_basic_count, "Rotate branch changed its Basic inventory.")
	
	assert(basic_result.state.session.get_token_count(0, TokenLibrary.TokenType.BASIC) == live_basic_count - 1, "Basic branch did not spend one Basic token.")
	assert(basic_result.state.session.get_token_count(0, TokenLibrary.TokenType.ROTATE_GRAVITY) == live_rotate_count, "Basic branch changed its Rotate Gravity inventory.")
	
	assert(session.get_token_count(0, TokenLibrary.TokenType.BASIC) == live_basic_count, "A simulation changed the live Basic inventory.")
	assert(session.get_token_count(0, TokenLibrary.TokenType.ROTATE_GRAVITY) == live_rotate_count, "A simulation changed the live Rotate Gravity inventory.")
	
	# Mutating one completed branch must not affect the other branch or live state.
	rotate_result.state.settings.tokens_to_win = 5
	rotate_player.set_token_count(TokenLibrary.TokenType.BASIC, 1)
	
	assert(basic_result.state.settings.tokens_to_win == 4, "Mutating Rotate branch settings changed Basic branch settings.")
	assert(settings.tokens_to_win == 4, "Mutating Rotate branch settings changed live settings.")
	assert(basic_player.get_token_count(TokenLibrary.TokenType.BASIC) == live_basic_count - 1, "Mutating Rotate branch inventory changed Basic branch inventory.")
	assert(live_player.get_token_count(TokenLibrary.TokenType.BASIC) == live_basic_count, "Mutating Rotate branch inventory changed live inventory.")
	
	# Mutating the live source after both simulations exist must not flow back
	# into either already-created simulation.
	settings.tokens_to_win = 6
	live_player.set_token_count(TokenLibrary.TokenType.BASIC, 7)
	
	assert(rotate_result.state.settings.tokens_to_win == 5, "Live settings mutation changed the Rotate branch.")
	assert(basic_result.state.settings.tokens_to_win == 4, "Live settings mutation changed the Basic branch.")
	assert(rotate_player.get_token_count(TokenLibrary.TokenType.BASIC) == 1, "Live inventory mutation changed the Rotate branch.")
	assert(basic_player.get_token_count(TokenLibrary.TokenType.BASIC) == live_basic_count - 1, "Live inventory mutation changed the Basic branch.")
	
	rotate_result.dispose()
	basic_result.dispose()
	
	print("PASS: Simulated candidate branches are isolated from each other and from live state.")


func test_disposing_one_branch_does_not_damage_others() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var result_a:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, create_action(TokenLibrary.TokenType.BASIC, Vector2i(0, 0)))
	var result_b:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, create_action(TokenLibrary.TokenType.BASIC, Vector2i(1, 0)))
	var result_c:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, create_action(TokenLibrary.TokenType.BASIC, Vector2i(2, 0)))
	
	assert(result_a.success, result_a.error_message)
	assert(result_b.success, result_b.error_message)
	assert(result_c.success, result_c.error_message)
	
	var board_a:BotSimulationBoard = result_a.board
	var root_a:Node2D = result_a.state.token_root
	
	var board_b:BotSimulationBoard = result_b.board
	var root_b:Node2D = result_b.state.token_root
	
	var board_c:BotSimulationBoard = result_c.board
	var root_c:Node2D = result_c.state.token_root
	
	assert(is_instance_valid(board_a), "Branch A board is unexpectedly invalid.")
	assert(is_instance_valid(root_a), "Branch A token root is unexpectedly invalid.")
	assert(is_instance_valid(board_b), "Branch B board is unexpectedly invalid.")
	assert(is_instance_valid(root_b), "Branch B token root is unexpectedly invalid.")
	assert(is_instance_valid(board_c), "Branch C board is unexpectedly invalid.")
	assert(is_instance_valid(root_c), "Branch C token root is unexpectedly invalid.")
	
	result_a.dispose()
	
	assert(result_a.board == null, "Disposed Branch A still exposes its board.")
	assert(result_a.state == null, "Disposed Branch A still exposes its state.")
	assert(is_instance_valid(board_a) == false, "Disposed Branch A board is still alive.")
	assert(is_instance_valid(root_a) == false, "Disposed Branch A token root is still alive.")
	
	assert(result_b.success, "Disposing Branch A changed Branch B success state.")
	assert(result_c.success, "Disposing Branch A changed Branch C success state.")
	assert(is_instance_valid(board_b), "Disposing Branch A destroyed Branch B's board.")
	assert(is_instance_valid(root_b), "Disposing Branch A destroyed Branch B's token root.")
	assert(is_instance_valid(board_c), "Disposing Branch A destroyed Branch C's board.")
	assert(is_instance_valid(root_c), "Disposing Branch A destroyed Branch C's token root.")
	
	var token_b:Token = result_b.board.get_token(Vector2i(1, 5))
	var token_c:Token = result_c.board.get_token(Vector2i(2, 5))
	
	assert(token_b != null, "Branch B lost its placed token when Branch A was disposed.")
	assert(token_c != null, "Branch C lost its placed token when Branch A was disposed.")
	assert(token_b.player_id == 0, "Branch B token was corrupted.")
	assert(token_c.player_id == 0, "Branch C token was corrupted.")
	
	# Dispose the remaining branches in a different order.
	result_c.dispose()
	
	assert(is_instance_valid(board_b), "Disposing Branch C destroyed Branch B.")
	assert(is_instance_valid(root_b), "Disposing Branch C destroyed Branch B's token tree.")
	
	result_b.dispose()
	
	# Disposal should also be safely idempotent.
	result_a.dispose()
	result_b.dispose()
	result_c.dispose()
	
	print("PASS: Simulation branches can be disposed independently and in any order.")


func test_failed_simulations_release_resources() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var live_player_zero_counts:Dictionary = session.get_player(0).get_token_counts().duplicate(true)
	var live_player_one_counts:Dictionary = session.get_player(1).get_token_counts().duplicate(true)
	
	for attempt in range(20):
		var invalid_action:BotAction = BotAction.new()
		
		# Player 1 is not the active player, so this is well-formed data
		# that must fail simulation validation after a clone has been created.
		invalid_action.setup(1, TokenLibrary.TokenType.BASIC, Vector2i(attempt % 7, 0), false)
		
		var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, invalid_action)
		
		assert(result != null, "Failed simulation returned null.")
		assert(result.success == false, "Invalid action unexpectedly succeeded.")
		assert(result.error_message != "", "Failed simulation has no error message.")
		assert(result.state == null, "Failed simulation retained its BotSimulationState.")
		assert(result.board == null, "Failed simulation retained its BotSimulationBoard.")
		
		result.dispose()
		result.dispose()
	
	assert(session.get_player(0).get_token_counts() == live_player_zero_counts, "Failed simulations changed Player 0 live inventory.")
	assert(session.get_player(1).get_token_counts() == live_player_one_counts, "Failed simulations changed Player 1 live inventory.")
	assert(count_board_tokens(source_board, settings) == 0, "Failed simulations changed the live board.")
	
	print("PASS: Failed simulations release their disposable resources without leaving live-state residue.")


func test_repeated_simulation_does_not_change_source() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var live_token_root:Node2D = Node2D.new()
	
	var live_left:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.BASIC, Vector2i(0, 5), 1)
	var live_right:Token = add_source_token(source_board, live_token_root, TokenLibrary.TokenType.PYRE, Vector2i(6, 5), 1)
	
	assert(live_left != null, "Could not create repeated-simulation source Basic.")
	assert(live_right != null, "Could not create repeated-simulation source Pyre.")
	
	var board_signature:Array[Dictionary] = capture_board_signature(source_board, settings)
	var inventory_signature:Dictionary = session.get_player(0).get_token_counts().duplicate(true)
	var gravity_signature:BoardSetting.GRID_DIRECTION = settings.gravity_direction
	var winner_signature:int = session.winner_id
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(3, 0))
	
	for simulation_index in range(REPEAT_SIMULATION_COUNT):
		var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
		
		assert(result != null, "Repeated simulation %d returned null." % simulation_index)
		assert(result.success, "Repeated simulation %d failed: %s" % [simulation_index, result.error_message])
		assert(result.board.get_token(Vector2i(3, 5)) != null, "Repeated simulation %d did not resolve its Basic token." % simulation_index)
		
		result.dispose()
		
		assert(capture_board_signature(source_board, settings) == board_signature, "Repeated simulation %d changed the live board." % simulation_index)
		assert(session.get_player(0).get_token_counts() == inventory_signature, "Repeated simulation %d changed live inventory." % simulation_index)
		assert(settings.gravity_direction == gravity_signature, "Repeated simulation %d changed live gravity." % simulation_index)
		assert(session.winner_id == winner_signature, "Repeated simulation %d changed the live winner." % simulation_index)
	
	live_token_root.free()
	
	print("PASS: Repeated simulation of the same candidate leaves the source match unchanged.")


func test_every_generated_action_resolves_independently() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var source_inventory:Dictionary = session.get_player(0).get_token_counts().duplicate(true)
	var source_gravity:BoardSetting.GRID_DIRECTION = settings.gravity_direction
	
	var actions:Array[BotAction] = BotActionGenerator.generate_actions(session, source_board, settings, 0)
	
	assert(actions.is_empty() == false, "BotActionGenerator produced no actions for the complete test tray.")
	
	var seen_token_types:Dictionary = {}
	var seen_unflipped:Dictionary = {}
	var seen_flipped:Dictionary = {}
	var simulated_action_count:int = 0
	
	for action in actions:
		assert(action != null, "BotActionGenerator returned a null action.")
		
		var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action)
		
		assert(result != null, "Simulator returned null for %s." % action.get_description())
		assert(result.success, "Simulation failed for %s: %s" % [action.get_description(), result.error_message])
		assert(result.state != null, "Successful simulation has no state for %s." % action.get_description())
		assert(result.board != null, "Successful simulation has no board for %s." % action.get_description())
		
		assert(result.board.visuals == null, "Simulation unexpectedly owns visuals for %s." % action.get_description())
		assert(result.board.get_replay_recorder() == null, "Simulation unexpectedly owns a replay recorder for %s." % action.get_description())
		
		var simulation_mover:BotSimulationTokenMover = result.board.token_mover as BotSimulationTokenMover
		
		assert(simulation_mover != null, "Simulation is not using BotSimulationTokenMover.")
		assert(simulation_mover.pending_destroyed_tokens.is_empty(), "Simulation finished with pending destroyed tokens for %s." % action.get_description())
		assert(result.board.trigger_resolver.pending_pass_triggers.is_empty(), "Simulation finished with pending pass triggers for %s." % action.get_description())
		
		assert_board_is_stable(result.state.board_state, result.state.settings, action.get_description())
		
		seen_token_types[action.token_type] = true
		
		if action.start_flipped:
			seen_flipped[action.token_type] = true
		else:
			seen_unflipped[action.token_type] = true
		
		simulated_action_count += 1
		result.dispose()
		
		# Every candidate starts from the exact same source position.
		assert(count_board_tokens(source_board, settings) == 0, "Candidate simulation changed the live board.")
		assert(session.get_player(0).get_token_counts() == source_inventory, "Candidate simulation changed the live inventory.")
		assert(settings.gravity_direction == source_gravity, "Candidate simulation changed live gravity.")
		assert(session.winner_id == -1, "Candidate simulation changed the live winner.")
	
	var token_types:Array[int] = TokenLibrary.get_all_token_types()
	
	for token_type in token_types:
		assert(seen_token_types.has(token_type), "Registered token %s did not generate a simulated action." % TokenLibrary.get_display_name(token_type))
		assert(seen_unflipped.has(token_type), "Registered token %s did not generate an unflipped simulated action." % TokenLibrary.get_display_name(token_type))
		
		if TokenLibrary.can_flip(token_type):
			assert(seen_flipped.has(token_type), "Flippable token %s did not generate a flipped simulated action." % TokenLibrary.get_display_name(token_type))
	
	print("PASS: Every generated legal action resolves independently through BotSimulator (%d candidates)." % simulated_action_count)


func test_result_action_is_an_independent_copy() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var source_action:BotAction = create_action(TokenLibrary.TokenType.CHAMELEON, Vector2i(4, 0))
	
	assert(source_action.get_placement_data().is_empty(), "Source Chameleon action should begin without placement data.")
	
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, source_action)
	
	assert(result != null, "Chameleon action-copy simulation returned null.")
	assert(result.success, result.error_message)
	assert(result.action != null, "Simulation result has no action.")
	assert(result.action != source_action, "Simulation result retained the caller's BotAction instance.")
	
	# The simulator may resolve placement data on its private action copy.
	# That must not back-propagate into the candidate supplied by the caller.
	assert(result.action.get_placement_data().is_empty() == false, "Resolved Chameleon action has no placement data.")
	assert(source_action.get_placement_data().is_empty(), "Simulation mutated the caller's BotAction placement data.")
	
	var result_placement_data:Dictionary = result.action.get_placement_data()
	var original_fake_player_id:int = int(result_placement_data.get("fake_player_id", -1))
	
	result.action.set_placement_data({
		"fake_player_id": 99
	})
	
	assert(source_action.get_placement_data().is_empty(), "Mutating the result BotAction changed the source BotAction.")
	assert(int(result.action.get_placement_data().get("fake_player_id", -1)) == 99, "Could not mutate the result BotAction independently.")
	assert(original_fake_player_id != 99, "Test unexpectedly began with the mutation sentinel value.")
	
	result.dispose()
	
	print("PASS: BotSimulator owns an independent copy of the candidate BotAction.")


func assert_board_is_stable(board_state:BoardState, settings:BoardSetting, action_description:String) -> void:
	for y in range(settings.rows):
		for x in range(settings.columns):
			var token:Token = board_state.get_token(Vector2i(x, y))
			
			if token == null:
				continue
			
			assert(is_instance_valid(token), "Stable board contains an invalid token after %s." % action_description)
			assert(token.being_destroyed == false, "Stable board contains a token still marked for destruction after %s." % action_description)
			assert(token.resolved, "Stable board contains an unresolved token after %s." % action_description)


func capture_board_signature(board_state:BoardState, settings:BoardSetting) -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	
	for y in range(settings.rows):
		for x in range(settings.columns):
			var pos:Vector2i = Vector2i(x, y)
			var token:Token = board_state.get_token(pos)
			
			if token == null:
				continue
			
			var token_signature:Dictionary = {
				"pos": pos,
				"token_type": token.token_type,
				"player_id": token.player_id,
				"resolved": token.resolved,
				"being_destroyed": token.being_destroyed,
				"is_flipped": token.is_flipped,
				"charges": token.charges,
				"placement_data": token.get_network_placement_data().duplicate(true),
				"state_data": token.create_network_state_data().duplicate(true)
			}
			
			result.append(token_signature)
	
	return result


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
	var player_one:MatchSessionPlayerData = session.get_player(1)
	
	assert(player_zero != null, "Could not get test player 0.")
	assert(player_one != null, "Could not get test player 1.")
	
	# Give Player 0 every currently registered token so this test automatically
	# exercises the complete roster through BotActionGenerator.
	for token_type in TokenLibrary.get_all_token_types():
		player_zero.set_token_count(token_type, 3)
	
	# Basic gets a few extra copies for the repeated-isolation tests.
	player_zero.set_token_count(TokenLibrary.TokenType.BASIC, 10)
	
	# Player 1 needs a visible inventory as well so failed simulations can prove
	# that neither player's source inventory changes.
	player_one.set_token_count(TokenLibrary.TokenType.BASIC, 5)
	
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
