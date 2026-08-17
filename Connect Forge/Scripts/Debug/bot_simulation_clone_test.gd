extends Node


func _ready() -> void:
	print("")
	print("========== BOT SIMULATION CLONE TEST ==========")
	
	test_settings_are_cloned()
	test_session_is_cloned()
	test_entire_board_and_token_roster_is_cloned()
	test_clone_mutation_cannot_change_live_state()
	
	print("========== ALL BOT SIMULATION CLONE TESTS PASSED ==========")
	print("")


func test_settings_are_cloned() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var board_state:BoardState = create_empty_board_state(settings)
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, board_state, settings)
	
	assert(simulation != null, "Simulation clone could not be created.")
	assert(simulation.settings != settings, "Simulation must own a different BoardSetting instance.")
	assert(simulation.settings.columns == settings.columns, "Cloned settings have the wrong column count.")
	assert(simulation.settings.rows == settings.rows, "Cloned settings have the wrong row count.")
	assert(simulation.settings.tokens_to_win == settings.tokens_to_win, "Cloned settings have the wrong win length.")
	assert(simulation.settings.gravity_direction == settings.gravity_direction, "Cloned settings have the wrong gravity direction.")
	
	simulation.settings.gravity_direction = BoardSetting.GRID_DIRECTION.UP
	
	assert(settings.gravity_direction == BoardSetting.GRID_DIRECTION.LEFT, "Changing simulation gravity changed the live gravity.")
	
	simulation.dispose()
	
	print("PASS: Board settings are independently cloned.")


func test_session_is_cloned() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var board_state:BoardState = create_empty_board_state(settings)
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, board_state, settings)
	
	assert(simulation != null, "Simulation clone could not be created.")
	assert(simulation.session != session, "Simulation must own a different MatchSession instance.")
	assert(simulation.session.players.size() == session.players.size(), "Simulation cloned the wrong number of players.")
	assert(simulation.session.active_player_ids == session.active_player_ids, "Active player IDs were not copied.")
	assert(simulation.session.current_player_id == session.current_player_id, "Current player was not copied.")
	assert(simulation.session.current_turn_phase == session.current_turn_phase, "Turn phase was not copied.")
	assert(simulation.session.current_turn_number == session.current_turn_number, "Turn number was not copied.")
	assert(simulation.session.current_round_number == session.current_round_number, "Round number was not copied.")
	assert(simulation.session.elapsed_game_time == session.elapsed_game_time, "Elapsed game time was not copied.")
	assert(simulation.session.elapsed_game_seconds == session.elapsed_game_seconds, "Elapsed game seconds were not copied.")
	
	for player_id in range(session.get_player_count()):
		var live_player:MatchSessionPlayerData = session.get_player(player_id)
		var simulated_player:MatchSessionPlayerData = simulation.session.get_player(player_id)
		
		assert(live_player != null, "Live player is missing.")
		assert(simulated_player != null, "Simulated player is missing.")
		assert(simulated_player != live_player, "Simulation player shares the live MatchSessionPlayerData instance.")
		assert(simulated_player.player_name == live_player.player_name, "Player name was not copied.")
		assert(simulated_player.controller_type == live_player.controller_type, "Controller type was not copied.")
		assert(simulated_player.bot_profile_id == live_player.bot_profile_id, "Bot profile was not copied.")
		assert(simulated_player.bot_difficulty == live_player.bot_difficulty, "Bot difficulty was not copied.")
		assert(simulated_player.wins == live_player.wins, "Wins were not copied.")
		assert(simulated_player.losses == live_player.losses, "Losses were not copied.")
		assert(simulated_player.get_starting_token_counts() == live_player.get_starting_token_counts(), "Starting token inventory was not copied.")
		assert(simulated_player.get_token_counts() == live_player.get_token_counts(), "Current token inventory was not copied.")
		
		if live_player.colour_palette != null:
			assert(simulated_player.colour_palette != live_player.colour_palette, "Simulation shares the live player's mutable colour palette resource.")
	
	simulation.dispose()
	
	print("PASS: MatchSession, players, scores, activity and inventories are independently cloned.")


func test_entire_board_and_token_roster_is_cloned() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var board_state:BoardState = create_empty_board_state(settings)
	var live_token_root:Node = Node.new()
	
	populate_board_with_every_token(board_state, live_token_root)
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, board_state, settings)
	
	assert(simulation != null, "Simulation clone could not be created.")
	assert(simulation.board_state != board_state, "Simulation must own a different BoardState instance.")
	
	var token_types:Array[int] = TokenLibrary.get_all_token_types()
	
	for index in range(token_types.size()):
		var pos:Vector2i = get_test_token_position(index, settings.columns)
		var live_token:Token = board_state.get_token(pos)
		var simulated_token:Token = simulation.board_state.get_token(pos)
		
		assert(live_token != null, "Expected live token is missing at %s." % str(pos))
		assert(simulated_token != null, "Expected simulated token is missing at %s." % str(pos))
		assert(simulated_token != live_token, "Simulation shares a live Token instance at %s." % str(pos))
		
		assert(simulated_token.token_type == live_token.token_type, "Token type was not copied at %s." % str(pos))
		assert(simulated_token.player_id == live_token.player_id, "Token owner was not copied at %s." % str(pos))
		assert(simulated_token.token_pos == live_token.token_pos, "Token position was not copied at %s." % str(pos))
		assert(simulated_token.is_flipped == live_token.is_flipped, "Flipped state was not copied at %s." % str(pos))
		assert(simulated_token.charges == live_token.charges, "Charges were not copied at %s." % str(pos))
		assert(simulated_token.ability_cost == live_token.ability_cost, "Ability cost was not copied at %s." % str(pos))
		assert(simulated_token.resolved == live_token.resolved, "Resolved state was not copied at %s." % str(pos))
		assert(simulated_token.being_destroyed == live_token.being_destroyed, "Destruction state was not copied at %s." % str(pos))
		assert(simulated_token.keywords == live_token.keywords, "Token keywords were not copied at %s." % str(pos))
		assert(simulated_token.get_network_placement_data() == live_token.get_network_placement_data(), "Placement data was not copied at %s." % str(pos))
		assert(simulated_token.create_network_state_data() == live_token.create_network_state_data(), "Token-specific persistent state was not copied at %s." % str(pos))
		
		assert(simulated_token.board == null, "A cloned token must not point at the live BoardManager.")
		assert(simulated_token.replay_token_id == -1, "A cloned token must not retain a live replay token ID.")
		assert(simulated_token.get_parent() != live_token.get_parent(), "Simulation and live tokens share their owning node.")
	
	var live_chameleon:Token = find_token_of_type(board_state, settings, TokenLibrary.TokenType.CHAMELEON)
	var simulated_chameleon:Token = find_token_of_type(simulation.board_state, simulation.settings, TokenLibrary.TokenType.CHAMELEON)
	var live_drill:Token = find_token_of_type(board_state, settings, TokenLibrary.TokenType.DRILL)
	var simulated_drill:Token = find_token_of_type(simulation.board_state, simulation.settings, TokenLibrary.TokenType.DRILL)
	
	assert(live_chameleon != null, "Live Chameleon was not found.")
	assert(simulated_chameleon != null, "Simulated Chameleon was not found.")
	assert(live_drill != null, "Live Drill was not found.")
	assert(simulated_drill != null, "Simulated Drill was not found.")
	
	assert(bool(simulated_chameleon.create_network_state_data().get("has_transformed", false)), "Chameleon transformed state was not cloned.")
	assert(bool(simulated_chameleon.create_network_state_data().get("has_revealed", true)) == false, "Chameleon revealed state was not cloned.")
	assert(int(simulated_chameleon.create_network_state_data().get("fake_player_id", -1)) == 2, "Chameleon fake player ID was not cloned.")
	assert(bool(simulated_drill.create_network_state_data().get("has_activated", false)), "Drill activation state was not cloned.")
	
	simulation.dispose()
	live_token_root.free()
	
	print("PASS: Every current token is cloned with independent common and token-specific persistent state.")


func test_clone_mutation_cannot_change_live_state() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var board_state:BoardState = create_empty_board_state(settings)
	var live_token_root:Node = Node.new()
	
	populate_board_with_every_token(board_state, live_token_root)
	
	var simulation:BotSimulationState = BotSimulationStateCloner.clone_state(session, board_state, settings)
	
	assert(simulation != null, "Simulation clone could not be created.")
	
	var live_player:MatchSessionPlayerData = session.get_player(0)
	var simulated_player:MatchSessionPlayerData = simulation.session.get_player(0)
	
	assert(live_player != null, "Live player was not found.")
	assert(simulated_player != null, "Simulated player was not found.")
	
	var original_live_bomb_count:int = live_player.get_token_count(TokenLibrary.TokenType.BOMB)
	var original_live_wins:int = live_player.wins
	var original_live_active_players:Array[int] = session.get_active_player_ids()
	
	simulated_player.set_token_count(TokenLibrary.TokenType.BOMB, 77)
	simulated_player.wins = 99
	simulation.session.deactivate_player(1)
	simulation.settings.gravity_direction = BoardSetting.GRID_DIRECTION.UP
	
	assert(live_player.get_token_count(TokenLibrary.TokenType.BOMB) == original_live_bomb_count, "Changing simulated inventory changed the live inventory.")
	assert(live_player.wins == original_live_wins, "Changing simulated score changed the live score.")
	assert(session.get_active_player_ids() == original_live_active_players, "Changing simulated active players changed the live active players.")
	assert(settings.gravity_direction == BoardSetting.GRID_DIRECTION.LEFT, "Changing simulated gravity changed live gravity.")
	
	var live_chameleon:Token = find_token_of_type(board_state, settings, TokenLibrary.TokenType.CHAMELEON)
	var simulated_chameleon:Token = find_token_of_type(simulation.board_state, simulation.settings, TokenLibrary.TokenType.CHAMELEON)
	
	assert(live_chameleon != null, "Live Chameleon was not found.")
	assert(simulated_chameleon != null, "Simulated Chameleon was not found.")
	
	var live_chameleon_charges:int = live_chameleon.charges
	var live_chameleon_state:Dictionary = live_chameleon.create_network_state_data().duplicate(true)
	
	simulated_chameleon.charges = 55
	simulated_chameleon.apply_network_state_data({
		"fake_player_id": 0,
		"has_transformed": false,
		"has_revealed": true
	})
	
	assert(live_chameleon.charges == live_chameleon_charges, "Changing simulated token charges changed the live token.")
	assert(live_chameleon.create_network_state_data() == live_chameleon_state, "Changing simulated token-specific state changed the live token.")
	
	var chameleon_pos:Vector2i = live_chameleon.token_pos
	
	assert(simulation.board_state.remove_token(chameleon_pos), "Could not remove token from simulated board.")
	assert(board_state.get_token(chameleon_pos) == live_chameleon, "Removing a simulated token changed the live BoardState.")
	
	# Now mutate the live state and make sure the simulation does not follow it.
	var simulated_bomb_count_before_live_change:int = simulated_player.get_token_count(TokenLibrary.TokenType.BOMB)
	var simulated_gravity_before_live_change:BoardSetting.GRID_DIRECTION = simulation.settings.gravity_direction
	
	live_player.set_token_count(TokenLibrary.TokenType.BOMB, 12)
	settings.gravity_direction = BoardSetting.GRID_DIRECTION.RIGHT
	live_chameleon.charges = 88
	
	assert(simulated_player.get_token_count(TokenLibrary.TokenType.BOMB) == simulated_bomb_count_before_live_change, "Changing live inventory changed simulated inventory.")
	assert(simulation.settings.gravity_direction == simulated_gravity_before_live_change, "Changing live gravity changed simulated gravity.")
	assert(simulated_chameleon.charges == 55, "Changing a live token changed its simulated clone.")
	
	simulation.dispose()
	live_token_root.free()
	
	print("PASS: Live and simulated settings, sessions, inventories, boards and token state are isolated in both directions.")


func create_test_settings() -> BoardSetting:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = 7
	settings.rows = 6
	settings.tokens_to_win = 4
	settings.gravity_direction = BoardSetting.GRID_DIRECTION.LEFT
	return settings


func create_test_session() -> MatchSession:
	var config:MatchConfig = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	config.turn_timer_seconds = 30
	config.starting_player_id = 0
	
	assert(config.add_bot("duncan", MatchData.YELLOW_PALETTE, MatchPlayerData.BOT_DIFFICULTY.HARD), "Could not add Duncan to clone test.")
	assert(config.add_player("Test Player 2", MatchData.RED_PALETTE), "Could not add test player 2.")
	assert(config.add_player("Test Player 3", MatchData.GREEN_PALETTE), "Could not add test player 3.")
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not create test MatchSession.")
	
	var player_zero:MatchSessionPlayerData = session.get_player(0)
	var player_one:MatchSessionPlayerData = session.get_player(1)
	
	assert(player_zero != null, "Could not retrieve player 0.")
	assert(player_one != null, "Could not retrieve player 1.")
	
	player_zero.wins = 3
	player_zero.losses = 1
	player_one.wins = 1
	player_one.losses = 3
	
	player_zero.set_starting_token_count(TokenLibrary.TokenType.BOMB, 4)
	player_zero.set_token_count(TokenLibrary.TokenType.BOMB, 2)
	player_zero.set_token_count(TokenLibrary.TokenType.ANVIL, 0)
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	assert(session.set_current_player(1), "Could not set current player for clone test.")
	session.set_turn_number(9)
	session.current_round_number = 3
	
	session.elapsed_game_time = 42.5
	session.elapsed_game_seconds = 42
	session.game_timer_running = true
	
	assert(session.deactivate_player(2), "Could not deactivate player 2 for clone test.")
	
	return session


func create_empty_board_state(settings:BoardSetting) -> BoardState:
	var board_state:BoardState = BoardState.new(settings)
	board_state.setup_empty_board()
	return board_state


func populate_board_with_every_token(board_state:BoardState, token_root:Node) -> void:
	var token_types:Array[int] = TokenLibrary.get_all_token_types()
	
	for index in range(token_types.size()):
		var token_type:int = token_types[index]
		var pos:Vector2i = get_test_token_position(index, board_state.settings.columns)
		var player_id:int = index % 3
		var flipped:bool = false
		
		if TokenLibrary.can_flip(token_type):
			flipped = index % 2 == 0
		
		var token:Token = create_test_token(token_type, pos, player_id, flipped)
		
		assert(token != null, "Could not create %s for clone test." % TokenLibrary.get_display_name(token_type))
		
		token.resolved = index % 2 == 0
		
		var placement_data:Dictionary = {
			"test_nested_data": {
				"value": index
			}
		}
		
		if token_type == TokenLibrary.TokenType.CHAMELEON:
			placement_data["fake_player_id"] = 2
		
		token.apply_network_placement_data(placement_data)
		
		if token_type == TokenLibrary.TokenType.CHAMELEON:
			token.charges = 0
			token.apply_network_state_data({
				"fake_player_id": 2,
				"has_transformed": true,
				"has_revealed": false
			})
		
		if token_type == TokenLibrary.TokenType.DRILL:
			token.apply_network_state_data({
				"has_activated": true
			})
		
		token_root.add_child(token)
		
		assert(board_state.add_token(token, pos), "Could not add %s to clone test board." % TokenLibrary.get_display_name(token_type))


func create_test_token(token_type:int, pos:Vector2i, player_id:int, flipped:bool) -> Token:
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return null
	
	var token_node:Node = token_scene.instantiate()
	
	if token_node == null:
		return null
	
	var token:Token = token_node as Token
	
	if token == null:
		token_node.free()
		return null
	
	token.setup_special_token()
	token.player_id = player_id
	token.token_pos = pos
	token.is_flipped = flipped
	token.board = null
	
	return token


func get_test_token_position(index:int, columns:int) -> Vector2i:
	var x:int = index % columns
	var y:int = int(index / columns)
	return Vector2i(x, y)


func find_token_of_type(board_state:BoardState, settings:BoardSetting, token_type:int) -> Token:
	for y in range(settings.rows):
		for x in range(settings.columns):
			var token:Token = board_state.get_token(Vector2i(x, y))
			
			if token == null:
				continue
			
			if token.token_type == token_type:
				return token
	
	return null
