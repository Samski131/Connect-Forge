extends Node

var detected_player_ids:Array[int] = []


func _ready() -> void:
	print("")
	print("========== BOT MANAGER TEST ==========")
	
	test_human_turn_is_not_detected_as_bot()
	test_bot_waits_until_placement_phase()
	test_bot_turn_is_emitted_only_once()
	test_multiple_bots_are_detected_independently()
	test_inactive_bot_is_not_detected()
	test_network_human_is_not_detected_as_bot()
	test_rebinding_disconnects_old_session()
	
	print("========== ALL BOT MANAGER TESTS PASSED ==========")
	print("")


func test_human_turn_is_not_detected_as_bot() -> void:
	detected_player_ids.clear()
	
	var session:MatchSession = create_human_and_bot_session()
	var manager:BotManager = create_manager(session)
	
	assert(session.set_current_player(0), "Could not select human Player 0.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(manager.is_current_player_bot() == false, "Human player was reported as a bot.")
	assert(manager.is_bot_turn_ready() == false, "Human placement turn was reported as bot-ready.")
	assert(manager.get_current_bot_player_id() == -1, "Human turn returned a bot player ID.")
	assert(detected_player_ids.is_empty(), "Human turn emitted bot_turn_ready.")
	
	cleanup_manager(manager)
	
	print("PASS: Human placement turns are ignored by BotManager.")


func test_bot_waits_until_placement_phase() -> void:
	detected_player_ids.clear()
	
	var session:MatchSession = create_human_and_bot_session()
	var manager:BotManager = create_manager(session)
	
	assert(session.set_current_player(1), "Could not select Duncan.")
	
	assert(manager.is_current_player_bot(), "Duncan was not recognised as a bot.")
	assert(manager.is_bot_turn_ready() == false, "Bot became ready before entering placement.")
	assert(detected_player_ids.is_empty(), "Bot turn emitted before placement began.")
	
	session.set_turn_phase(Global.TURN_PHASE.ACTION)
	
	assert(manager.is_bot_turn_ready() == false, "Bot ACTION phase should not be placement-ready.")
	assert(detected_player_ids.is_empty(), "Bot ACTION phase emitted bot_turn_ready.")
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(manager.is_bot_turn_ready(), "Bot was not ready after entering placement.")
	assert(manager.get_current_bot_player_id() == 1, "Wrong current bot player ID.")
	assert(detected_player_ids.size() == 1, "Bot placement turn should emit exactly once.")
	assert(detected_player_ids[0] == 1, "Wrong bot player emitted.")
	
	cleanup_manager(manager)
	
	print("PASS: Bot turns become ready only after the real match enters placement.")


func test_bot_turn_is_emitted_only_once() -> void:
	detected_player_ids.clear()
	
	var session:MatchSession = create_human_and_bot_session()
	var manager:BotManager = create_manager(session)
	
	assert(session.set_current_player(1), "Could not select Duncan.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(detected_player_ids.size() == 1, "Initial bot turn was not emitted exactly once.")
	
	manager.refresh_turn_detection()
	manager.refresh_turn_detection()
	manager.refresh_turn_detection()
	
	assert(detected_player_ids.size() == 1, "Manual refresh emitted the same bot turn more than once.")
	
	session.set_turn_phase(Global.TURN_PHASE.ACTION)
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(detected_player_ids.size() == 1, "Re-entering placement during the same logical turn emitted a duplicate bot turn.")
	
	cleanup_manager(manager)
	
	print("PASS: The same logical bot turn cannot be announced more than once.")


func test_multiple_bots_are_detected_independently() -> void:
	detected_player_ids.clear()
	
	var session:MatchSession = create_human_and_two_bot_session()
	var manager:BotManager = create_manager(session)
	
	assert(session.set_current_player(1), "Could not select Duncan.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(detected_player_ids.size() == 1, "Duncan's turn was not detected.")
	assert(detected_player_ids[0] == 1, "Wrong first bot detected.")
	
	session.set_turn_phase(Global.TURN_PHASE.ACTION)
	assert(session.set_current_player(2), "Could not select Periwinkle.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(detected_player_ids.size() == 2, "Periwinkle's turn was not independently detected.")
	assert(detected_player_ids[1] == 2, "Wrong second bot detected.")
	
	# Advance into the next complete turn cycle.
	session.set_turn_phase(Global.TURN_PHASE.ACTION)
	assert(session.set_current_player(0), "Could not return to Player 0.")
	session.increment_turn_number()
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(detected_player_ids.size() == 2, "Human turn unexpectedly emitted a bot event.")
	
	session.set_turn_phase(Global.TURN_PHASE.ACTION)
	assert(session.set_current_player(1), "Could not select Duncan on the next turn.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(detected_player_ids.size() == 3, "Duncan's later turn was not detected.")
	assert(detected_player_ids[2] == 1, "Wrong bot detected on the later turn.")
	
	cleanup_manager(manager)
	
	print("PASS: Separate bots and later turn cycles are detected independently.")


func test_inactive_bot_is_not_detected() -> void:
	detected_player_ids.clear()
	
	var session:MatchSession = create_human_and_bot_session()
	var manager:BotManager = create_manager(session)
	
	assert(session.set_current_player(1), "Could not select Duncan before deactivation.")
	assert(session.deactivate_player(1), "Could not deactivate Duncan.")
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(manager.is_current_player_bot(), "Inactive Duncan should still retain BOT controller identity.")
	assert(manager.is_bot_turn_ready() == false, "Inactive bot should not be considered ready to act.")
	assert(manager.get_current_bot_player_id() == -1, "Inactive bot returned as current actionable bot.")
	assert(detected_player_ids.is_empty(), "Inactive bot emitted bot_turn_ready.")
	
	cleanup_manager(manager)
	
	print("PASS: Inactive bot slots never begin automated turns.")


func test_network_human_is_not_detected_as_bot() -> void:
	detected_player_ids.clear()
	
	var session:MatchSession = create_network_human_and_bot_session()
	var manager:BotManager = create_manager(session)
	
	assert(session.set_current_player(1), "Could not select network human.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(manager.is_current_player_bot() == false, "Network human was mistaken for a bot.")
	assert(manager.is_bot_turn_ready() == false, "Network human became bot-ready.")
	assert(detected_player_ids.is_empty(), "Network human emitted bot_turn_ready.")
	
	session.set_turn_phase(Global.TURN_PHASE.ACTION)
	assert(session.set_current_player(2), "Could not select Duncan.")
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(manager.is_current_player_bot(), "Actual bot was not recognised after network human.")
	assert(manager.is_bot_turn_ready(), "Actual bot did not become ready.")
	assert(detected_player_ids.size() == 1, "Actual bot should have emitted exactly once.")
	assert(detected_player_ids[0] == 2, "Wrong player ID emitted for actual bot.")
	
	cleanup_manager(manager)
	
	print("PASS: Local humans, network humans and bots remain distinct controller types.")


func test_rebinding_disconnects_old_session() -> void:
	detected_player_ids.clear()
	
	var old_session:MatchSession = create_human_and_bot_session()
	var new_session:MatchSession = create_human_and_bot_session()
	
	var manager:BotManager = BotManager.new()
	add_child(manager)
	
	if manager.bot_turn_ready.is_connected(_on_bot_turn_ready) == false:
		manager.bot_turn_ready.connect(_on_bot_turn_ready)
	
	manager.setup(old_session)
	manager.setup(new_session)
	
	# Changes in the old session must now be invisible to this manager.
	assert(old_session.set_current_player(1), "Could not select old-session Duncan.")
	old_session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(detected_player_ids.is_empty(), "Rebound BotManager still reacted to its old MatchSession.")
	
	assert(new_session.set_current_player(1), "Could not select new-session Duncan.")
	new_session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	assert(detected_player_ids.size() == 1, "Rebound BotManager did not detect the new session.")
	assert(detected_player_ids[0] == 1, "Rebound BotManager emitted the wrong player.")
	
	cleanup_manager(manager)
	
	print("PASS: BotManager cleanly disconnects from obsolete MatchSession instances.")


func create_manager(session:MatchSession) -> BotManager:
	var manager:BotManager = BotManager.new()
	add_child(manager)
	
	if manager.bot_turn_ready.is_connected(_on_bot_turn_ready) == false:
		manager.bot_turn_ready.connect(_on_bot_turn_ready)
	
	manager.setup(session)
	return manager


func cleanup_manager(manager:BotManager) -> void:
	if manager == null:
		return
	
	manager.dispose()
	manager.queue_free()


func _on_bot_turn_ready(player_id:int) -> void:
	detected_player_ids.append(player_id)


func create_human_and_bot_session() -> MatchSession:
	var config:MatchConfig = create_base_config()
	
	assert(config.add_player("Human", MatchData.YELLOW_PALETTE), "Could not add local human.")
	assert(config.add_bot("duncan", MatchData.RED_PALETTE, MatchPlayerData.BOT_DIFFICULTY.NORMAL), "Could not add Duncan.")
	
	return create_session_from_config(config)


func create_human_and_two_bot_session() -> MatchSession:
	var config:MatchConfig = create_base_config()
	
	assert(config.add_player("Human", MatchData.YELLOW_PALETTE), "Could not add local human.")
	assert(config.add_bot("duncan", MatchData.RED_PALETTE, MatchPlayerData.BOT_DIFFICULTY.NORMAL), "Could not add Duncan.")
	assert(config.add_bot("periwinkle", MatchData.VIOLET_PALETTE, MatchPlayerData.BOT_DIFFICULTY.NORMAL), "Could not add Periwinkle.")
	
	return create_session_from_config(config)


func create_network_human_and_bot_session() -> MatchSession:
	var config:MatchConfig = create_base_config()
	
	assert(config.add_player("Local Human", MatchData.YELLOW_PALETTE), "Could not add local human.")
	assert(config.add_player("Network Human", MatchData.RED_PALETTE, MatchPlayerData.CONTROLLER_TYPE.NETWORK_HUMAN), "Could not add network human.")
	assert(config.add_bot("duncan", MatchData.GREEN_PALETTE, MatchPlayerData.BOT_DIFFICULTY.NORMAL), "Could not add Duncan.")
	
	return create_session_from_config(config)


func create_base_config() -> MatchConfig:
	var config:MatchConfig = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	config.turn_timer_seconds = 30
	config.starting_player_id = 0
	return config


func create_session_from_config(config:MatchConfig) -> MatchSession:
	var session:MatchSession = MatchSession.new()
	
	assert(session.setup(config), "Could not setup BotManager test MatchSession.")
	
	return session
