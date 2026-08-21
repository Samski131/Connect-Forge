extends Node

const TEST_SEED:int = 123456
const GLOBAL_TEST_SEED:int = 24681357


func _ready() -> void:
	print("")
	print("========== BOT SIMULATION RANDOMNESS TEST ==========")
	
	test_same_seed_same_result()
	test_simulation_does_not_consume_global_rng()
	test_branch_rng_is_independent()
	test_chameleon_enumerates_all_four_player_outcomes()
	test_each_chameleon_chance_outcome_is_forced_and_simulatable()
	test_non_random_action_has_single_certain_outcome()
	
	print("========== ALL BOT SIMULATION RANDOMNESS TESTS PASSED ==========")
	print("")


func test_same_seed_same_result() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_four_player_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var action:BotAction = create_action(TokenLibrary.TokenType.CHAMELEON, Vector2i(3, 0))
	
	var result_a:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action, TEST_SEED)
	var result_b:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action, TEST_SEED)
	
	assert(result_a != null, "First deterministic simulation returned null.")
	assert(result_b != null, "Second deterministic simulation returned null.")
	assert(result_a.success, result_a.error_message)
	assert(result_b.success, result_b.error_message)
	
	var fake_player_a:int = int(result_a.action.get_placement_data().get("fake_player_id", -1))
	var fake_player_b:int = int(result_b.action.get_placement_data().get("fake_player_id", -1))
	
	assert(fake_player_a >= 1 and fake_player_a <= 3, "First Chameleon selected an invalid fake player.")
	assert(fake_player_b >= 1 and fake_player_b <= 3, "Second Chameleon selected an invalid fake player.")
	assert(fake_player_a == fake_player_b, "Identical simulation seeds produced different Chameleon outcomes.")
	
	var token_a:Token = result_a.board.get_token(Vector2i(3, 5))
	var token_b:Token = result_b.board.get_token(Vector2i(3, 5))
	
	assert(token_a != null, "First simulation has no final Chameleon.")
	assert(token_b != null, "Second simulation has no final Chameleon.")
	
	var state_a:Dictionary = token_a.create_network_state_data()
	var state_b:Dictionary = token_b.create_network_state_data()
	
	assert(int(state_a.get("fake_player_id", -1)) == fake_player_a, "First Chameleon transformed into the wrong fake player.")
	assert(int(state_b.get("fake_player_id", -1)) == fake_player_b, "Second Chameleon transformed into the wrong fake player.")
	assert(state_a == state_b, "Identical seeds produced different final Chameleon state.")
	
	result_a.dispose()
	result_b.dispose()
	
	print("PASS: Same simulation seed reproduces the same random gameplay result.")


func test_simulation_does_not_consume_global_rng() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_four_player_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var action:BotAction = create_action(TokenLibrary.TokenType.CHAMELEON, Vector2i(2, 0))
	
	seed(GLOBAL_TEST_SEED)
	var expected_first:int = randi()
	var expected_second:int = randi()
	
	seed(GLOBAL_TEST_SEED)
	var actual_first:int = randi()
	
	assert(actual_first == expected_first, "Global RNG setup did not reproduce its first value.")
	
	var result:BotSimulationResult = BotSimulator.simulate_action(session, source_board, settings, action, 999999)
	
	assert(result != null, "Global-RNG isolation simulation returned null.")
	assert(result.success, result.error_message)
	
	var actual_second:int = randi()
	
	assert(actual_second == expected_second, "Bot simulation consumed values from Godot's global RNG.")
	
	result.dispose()
	
	# Return the global RNG to ordinary non-test behaviour.
	randomize()
	
	print("PASS: Simulation randomness does not consume the global live RNG sequence.")


func test_branch_rng_is_independent() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_four_player_session()
	var source_board:BoardState = create_empty_board_state(settings)
	
	var branch_a:BotSimulationState = BotSimulationStateCloner.clone_state(session, source_board, settings, TEST_SEED)
	var branch_b:BotSimulationState = BotSimulationStateCloner.clone_state(session, source_board, settings, TEST_SEED)
	
	assert(branch_a != null, "Could not create RNG branch A.")
	assert(branch_b != null, "Could not create RNG branch B.")
	
	var rng_a:RandomNumberGenerator = branch_a.get_random_number_generator()
	var rng_b:RandomNumberGenerator = branch_b.get_random_number_generator()
	
	assert(rng_a != null, "Branch A has no RNG.")
	assert(rng_b != null, "Branch B has no RNG.")
	assert(rng_a != rng_b, "Two simulation branches share the same RandomNumberGenerator.")
	
	var control:RandomNumberGenerator = RandomNumberGenerator.new()
	control.seed = TEST_SEED
	
	var expected_first:int = control.randi()
	var expected_second:int = control.randi()
	
	var branch_a_first:int = rng_a.randi()
	var branch_a_second:int = rng_a.randi()
	
	assert(branch_a_first == expected_first, "Branch A did not begin at the expected seeded RNG state.")
	assert(branch_a_second == expected_second, "Branch A's second RNG result was not deterministic.")
	
	# Branch A has already consumed two values. Branch B should still be at
	# the beginning of its own independent sequence.
	var branch_b_first:int = rng_b.randi()
	
	assert(branch_b_first == expected_first, "Consuming Branch A's RNG advanced Branch B's RNG.")
	
	branch_a.dispose()
	branch_b.dispose()
	
	print("PASS: Simulation branches own independent RNG state.")


func test_chameleon_enumerates_all_four_player_outcomes() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_four_player_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var action:BotAction = create_action(TokenLibrary.TokenType.CHAMELEON, Vector2i(4, 0))
	
	var outcomes:Array[BotChanceOutcome] = BotSimulator.get_chance_outcomes(session, source_board, settings, action)
	
	assert(outcomes.size() == 3, "Four-player Chameleon should expose exactly three random disguise outcomes.")
	assert(action.get_placement_data().is_empty(), "Chance enumeration mutated the source BotAction.")
	
	var found_player_ids:Dictionary = {}
	var total_probability:float = 0.0
	
	for outcome in outcomes:
		assert(outcome != null, "Chance outcome is null.")
		assert(outcome.is_valid(), "Chance outcome is invalid.")
		
		var fake_player_id:int = int(outcome.action.get_placement_data().get("fake_player_id", -1))
		
		assert(fake_player_id != 0, "Chameleon exposed its owner as a disguise outcome.")
		assert(fake_player_id >= 1 and fake_player_id <= 3, "Chameleon exposed an invalid disguise player.")
		assert(found_player_ids.has(fake_player_id) == false, "Chameleon exposed the same random disguise outcome twice.")
		assert(abs(outcome.probability - (1.0 / 3.0)) < 0.0001, "Four-player Chameleon outcomes should each have probability 1/3.")
		
		found_player_ids[fake_player_id] = true
		total_probability += outcome.probability
	
	assert(found_player_ids.has(1), "Player 1 disguise outcome is missing.")
	assert(found_player_ids.has(2), "Player 2 disguise outcome is missing.")
	assert(found_player_ids.has(3), "Player 3 disguise outcome is missing.")
	assert(abs(total_probability - 1.0) < 0.0001, "Chameleon outcome probabilities do not total 1.0.")
	
	print("PASS: Four-player Chameleon exposes all three equal-probability disguise outcomes.")


func test_each_chameleon_chance_outcome_is_forced_and_simulatable() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_four_player_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var source_action:BotAction = create_action(TokenLibrary.TokenType.CHAMELEON, Vector2i(5, 0))
	
	var outcomes:Array[BotChanceOutcome] = BotSimulator.get_chance_outcomes(session, source_board, settings, source_action)
	
	assert(outcomes.size() == 3, "Expected three Chameleon chance branches.")
	
	for outcome in outcomes:
		var forced_fake_player_id:int = int(outcome.action.get_placement_data().get("fake_player_id", -1))
		
		# Every branch deliberately uses the same seed. The explicit chance
		# outcome must override the roll, proving it is not rolled again.
		var result:BotSimulationResult = BotSimulator.simulate_action(
			session,
			source_board,
			settings,
			outcome.action,
			TEST_SEED
		)
		
		assert(result != null, "Chance-outcome simulation returned null.")
		assert(result.success, result.error_message)
		
		var resolved_fake_player_id:int = int(result.action.get_placement_data().get("fake_player_id", -1))
		
		assert(resolved_fake_player_id == forced_fake_player_id, "Simulator re-rolled an already-enumerated Chameleon outcome.")
		
		var chameleon:Token = result.board.get_token(Vector2i(5, 5))
		
		assert(chameleon != null, "Chance branch did not leave a Chameleon on the board.")
		
		var token_state:Dictionary = chameleon.create_network_state_data()
		
		assert(int(token_state.get("fake_player_id", -1)) == forced_fake_player_id, "Chameleon transformed into a different player than the forced chance branch.")
		assert(bool(token_state.get("has_transformed", false)), "Chameleon did not transform in its chance branch.")
		
		result.dispose()
	
	print("PASS: Enumerated Chameleon chance outcomes simulate without being re-rolled.")


func test_non_random_action_has_single_certain_outcome() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_four_player_session()
	var source_board:BoardState = create_empty_board_state(settings)
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC, Vector2i(1, 0))
	
	var outcomes:Array[BotChanceOutcome] = BotSimulator.get_chance_outcomes(session, source_board, settings, action)
	
	assert(outcomes.size() == 1, "A deterministic Basic action should expose exactly one outcome.")
	assert(outcomes[0] != null, "Basic certain outcome is null.")
	assert(outcomes[0].is_valid(), "Basic certain outcome is invalid.")
	assert(abs(outcomes[0].probability - 1.0) < 0.0001, "Basic outcome should have probability 1.0.")
	assert(outcomes[0].action.get_placement_data().is_empty(), "Basic certain outcome unexpectedly contains placement data.")
	assert(outcomes[0].action != action, "Certain outcome shares the caller's BotAction instance.")
	
	print("PASS: Non-random actions expose one certain outcome.")


func create_test_settings() -> BoardSetting:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = 7
	settings.rows = 6
	settings.tokens_to_win = 4
	settings.gravity_direction = BoardSetting.GRID_DIRECTION.DOWN
	return settings


func create_four_player_session() -> MatchSession:
	var config:MatchConfig = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	config.turn_timer_seconds = 30
	config.starting_player_id = 0
	
	assert(config.add_player("Bot Player", MatchData.YELLOW_PALETTE), "Could not add bot test player.")
	assert(config.add_player("Player 2", MatchData.RED_PALETTE), "Could not add test player 2.")
	assert(config.add_player("Player 3", MatchData.VIOLET_PALETTE), "Could not add test player 3.")
	assert(config.add_player("Player 4", MatchData.PINK_PALETTE), "Could not add test player 4.")
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not create four-player MatchSession.")
	
	var player_zero:MatchSessionPlayerData = session.get_player(0)
	assert(player_zero != null, "Could not get Player 0.")
	
	player_zero.set_token_count(TokenLibrary.TokenType.BASIC, 10)
	player_zero.set_token_count(TokenLibrary.TokenType.CHAMELEON, 10)
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	assert(session.set_current_player(0), "Could not set Player 0 as the active player.")
	
	return session


func create_empty_board_state(settings:BoardSetting) -> BoardState:
	var board_state:BoardState = BoardState.new(settings)
	board_state.setup_empty_board()
	return board_state


func create_action(token_type:int, starting_slot:Vector2i, start_flipped:bool = false) -> BotAction:
	var action:BotAction = BotAction.new()
	action.setup(0, token_type, starting_slot, start_flipped)
	return action
