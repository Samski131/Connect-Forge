class_name BotManager
extends Node

signal bot_turn_ready(player_id:int)
signal bot_action_selected(player_id:int, action:BotAction, score:float)
signal bot_action_executed(player_id:int, action:BotAction, success:bool)

var session:MatchSession = null
var connected_session:MatchSession = null
var game_manager:GameManager = null

var automatic_execution_enabled:bool = true

var last_emitted_round_number:int = -1
var last_emitted_turn_number:int = -1
var last_emitted_player_id:int = -1

var decision_pending:bool = false
var decision_in_progress:bool = false
var schedule_generation:int = 0


func setup(new_session:MatchSession, new_game_manager:GameManager = null, new_automatic_execution_enabled:bool = true) -> void:
	dispose()
	
	session = new_session
	game_manager = new_game_manager
	automatic_execution_enabled = new_automatic_execution_enabled
	
	if session == null:
		return
	
	connected_session = session
	connect_session_signals()
	reset_detection_history()
	refresh_turn_detection()


func dispose() -> void:
	schedule_generation += 1
	decision_pending = false
	decision_in_progress = false
	
	disconnect_session_signals()
	
	session = null
	game_manager = null
	
	reset_detection_history()


func _exit_tree() -> void:
	dispose()


func connect_session_signals() -> void:
	if connected_session == null:
		return
	
	if connected_session.current_player_changed.is_connected(_on_current_player_changed) == false:
		connected_session.current_player_changed.connect(_on_current_player_changed)
	
	if connected_session.turn_phase_changed.is_connected(_on_turn_phase_changed) == false:
		connected_session.turn_phase_changed.connect(_on_turn_phase_changed)
	
	if connected_session.turn_number_changed.is_connected(_on_turn_number_changed) == false:
		connected_session.turn_number_changed.connect(_on_turn_number_changed)
	
	if connected_session.round_number_changed.is_connected(_on_round_number_changed) == false:
		connected_session.round_number_changed.connect(_on_round_number_changed)
	
	if connected_session.winner_changed.is_connected(_on_winner_changed) == false:
		connected_session.winner_changed.connect(_on_winner_changed)
	
	if connected_session.active_players_changed.is_connected(_on_active_players_changed) == false:
		connected_session.active_players_changed.connect(_on_active_players_changed)


func disconnect_session_signals() -> void:
	if connected_session == null:
		return
	
	if connected_session.current_player_changed.is_connected(_on_current_player_changed):
		connected_session.current_player_changed.disconnect(_on_current_player_changed)
	
	if connected_session.turn_phase_changed.is_connected(_on_turn_phase_changed):
		connected_session.turn_phase_changed.disconnect(_on_turn_phase_changed)
	
	if connected_session.turn_number_changed.is_connected(_on_turn_number_changed):
		connected_session.turn_number_changed.disconnect(_on_turn_number_changed)
	
	if connected_session.round_number_changed.is_connected(_on_round_number_changed):
		connected_session.round_number_changed.disconnect(_on_round_number_changed)
	
	if connected_session.winner_changed.is_connected(_on_winner_changed):
		connected_session.winner_changed.disconnect(_on_winner_changed)
	
	if connected_session.active_players_changed.is_connected(_on_active_players_changed):
		connected_session.active_players_changed.disconnect(_on_active_players_changed)
	
	connected_session = null


func get_current_player() -> MatchSessionPlayerData:
	if session == null:
		return null
	
	return session.get_player(session.current_player_id)


func is_current_player_bot() -> bool:
	var player:MatchSessionPlayerData = get_current_player()
	
	if player == null:
		return false
	
	return player.is_bot()


func is_bot_turn_ready() -> bool:
	if session == null:
		return false
	
	if session.winner_id != -1:
		return false
	
	if session.current_turn_phase != Global.TURN_PHASE.PLACEMENT:
		return false
	
	var player_id:int = session.current_player_id
	
	if session.is_valid_player_id(player_id) == false:
		return false
	
	if session.is_player_active(player_id) == false:
		return false
	
	var player:MatchSessionPlayerData = session.get_player(player_id)
	
	if player == null:
		return false
	
	return player.is_bot()


func get_current_bot_player_id() -> int:
	if is_bot_turn_ready() == false:
		return -1
	
	return session.current_player_id


func refresh_turn_detection() -> bool:
	if is_bot_turn_ready() == false:
		return false
	
	var player_id:int = session.current_player_id
	var round_number:int = session.current_round_number
	var turn_number:int = session.current_turn_number
	
	if has_already_emitted_turn(round_number, turn_number, player_id):
		return false
	
	last_emitted_round_number = round_number
	last_emitted_turn_number = turn_number
	last_emitted_player_id = player_id
	
	bot_turn_ready.emit(player_id)
	
	if automatic_execution_enabled and game_manager != null:
		schedule_current_bot_turn(player_id, round_number, turn_number)
	
	return true


func schedule_current_bot_turn(player_id:int, round_number:int, turn_number:int) -> bool:
	if automatic_execution_enabled == false:
		return false
	
	if game_manager == null:
		return false
	
	if decision_pending:
		return false
	
	if decision_in_progress:
		return false
	
	if is_expected_bot_turn(player_id, round_number, turn_number) == false:
		return false
	
	decision_pending = true
	schedule_generation += 1
	
	var used_generation:int = schedule_generation
	
	call_deferred(
		"_run_scheduled_bot_turn",
		player_id,
		round_number,
		turn_number,
		used_generation
	)
	
	return true


func _run_scheduled_bot_turn(player_id:int, round_number:int, turn_number:int, expected_generation:int) -> void:
	if expected_generation != schedule_generation:
		return
	
	decision_pending = false
	
	if is_expected_bot_turn(player_id, round_number, turn_number) == false:
		return
	
	if try_run_bot_turn(player_id) == false:
		DebugOverlay.log_error(
			"BotAI",
			"Bot Player %d could not complete its local turn." % player_id
		)

func try_run_bot_turn(player_id:int, base_simulation_seed:int = -1) -> bool:
	if decision_in_progress:
		return false
	
	if session == null:
		return false
	
	if game_manager == null:
		return false
	
	if game_manager.board == null:
		return false
	
	if game_manager.board.state == null:
		return false
	
	if game_manager.board.settings == null:
		return false
	
	if is_bot_turn_ready() == false:
		return false
	
	if session.current_player_id != player_id:
		return false
	
	var total_start_usec:int = Time.get_ticks_usec()
	
	var round_number:int = session.current_round_number
	var turn_number:int = session.current_turn_number
	
	decision_pending = false
	decision_in_progress = true
	
	var used_seed:int = base_simulation_seed
	
	if used_seed < 0:
		used_seed = create_turn_seed(player_id, round_number, turn_number)
	
	var player_name:String = session.get_player_name(player_id)
	
	DebugOverlay.log_message(
		"BotAI",
		"%s began immediate move evaluation for turn %d." % [
			player_name,
			turn_number
		]
	)
	
	var selector:BotMoveSelector = BotMoveSelector.new()
	
	var selection:BotMoveSelectionResult = selector.select_best_action(
		session,
		game_manager.board.state,
		game_manager.board.settings,
		player_id,
		used_seed
	)
	
	if selection == null:
		decision_in_progress = false
		
		DebugOverlay.log_error(
			"BotAI",
			"%s produced no BotMoveSelectionResult." % player_name
		)
		
		return false
	
	if selection.valid == false:
		decision_in_progress = false
		
		DebugOverlay.log_error(
			"BotAI",
			"%s could not select a move: %s" % [
				player_name,
				selection.error_message
			]
		)
		
		return false
	
	if selection.has_selection() == false:
		decision_in_progress = false
		
		DebugOverlay.log_error(
			"BotAI",
			"%s completed evaluation without selecting a legal action." % player_name
		)
		
		return false
	
	if is_expected_bot_turn(player_id, round_number, turn_number) == false:
		decision_in_progress = false
		
		DebugOverlay.log_warning(
			"BotAI",
			"%s's selected move was discarded because the match state changed." % player_name
		)
		
		return false
	
	var selected_action:BotAction = selection.best_action.duplicate_action()
	
	if selected_action == null:
		decision_in_progress = false
		return false
	
	DebugOverlay.log_message(
		"BotAI",
		"%s evaluated %d legal actions and selected %s with score %.2f." % [
			player_name,
			selection.evaluated_action_count,
			selected_action.get_description(),
			selection.best_evaluation.final_score
		]
	)
	
	log_performance_report(player_name, selection)
	
	bot_action_selected.emit(
		player_id,
		selected_action.duplicate_action(),
		selection.best_evaluation.final_score
	)
	
	var execution_start_usec:int = Time.get_ticks_usec()
	var executed:bool = game_manager.try_execute_bot_action(selected_action)
	var execution_time_usec:int = Time.get_ticks_usec() - execution_start_usec
	
	bot_action_executed.emit(
		player_id,
		selected_action.duplicate_action(),
		executed
	)
	
	var total_time_usec:int = Time.get_ticks_usec() - total_start_usec
	
	DebugOverlay.log_message(
		"BotAI",
		"%s live execution: %.2f ms | total decision + submission: %.2f ms." % [
			player_name,
			usec_to_msec(execution_time_usec),
			usec_to_msec(total_time_usec)
		]
	)
	
	decision_in_progress = false
	
	if executed:
		DebugOverlay.log_message(
			"BotAI",
			"%s submitted its selected action through the local match placement path." % player_name
		)
	else:
		DebugOverlay.log_error(
			"BotAI",
			"%s selected a legal action but the live match rejected it." % player_name
		)
	
	return executed

func log_performance_report(player_name:String, selection:BotMoveSelectionResult) -> void:
	if selection == null:
		return
	
	DebugOverlay.log_message(
		"BotAI",
		"%s performance | actions %d generated / %d evaluated | primary sims %d | tactical sims %d." % [
			player_name,
			selection.generated_action_count,
			selection.evaluated_action_count,
			selection.primary_simulated_outcome_count,
			selection.tactical_simulated_outcome_count
		]
	)
	
	DebugOverlay.log_message(
		"BotAI",
		"%s timing | action generation %.2f ms | chance generation %.2f ms | primary simulation %.2f ms | board evaluation %.2f ms." % [
			player_name,
			usec_to_msec(selection.action_generation_time_usec),
			usec_to_msec(selection.chance_outcome_generation_time_usec),
			usec_to_msec(selection.primary_simulation_time_usec),
			usec_to_msec(selection.board_evaluation_time_usec)
		]
	)
	
	DebugOverlay.log_message(
		"BotAI",
		"%s timing | tactical analysis %.2f ms | resource evaluation %.2f ms | other evaluation %.2f ms | ranking %.2f ms | TOTAL %.2f ms." % [
			player_name,
			usec_to_msec(selection.tactical_analysis_time_usec),
			usec_to_msec(selection.resource_evaluation_time_usec),
			usec_to_msec(selection.get_unaccounted_evaluation_time_usec()),
			usec_to_msec(selection.ranking_time_usec),
			usec_to_msec(selection.total_selection_time_usec)
		]
	)


func usec_to_msec(usec:int) -> float:
	return float(usec) / 1000.0
	
	
func is_expected_bot_turn(player_id:int, round_number:int, turn_number:int) -> bool:
	if session == null:
		return false
	
	if is_bot_turn_ready() == false:
		return false
	
	if session.current_player_id != player_id:
		return false
	
	if session.current_round_number != round_number:
		return false
	
	if session.current_turn_number != turn_number:
		return false
	
	return true


func create_turn_seed(player_id:int, round_number:int, turn_number:int) -> int:
	var result:int = BotMoveSelector.DEFAULT_SELECTION_SEED
	
	result += (player_id + 1) * 1000003
	result += max(round_number, 0) * 10007
	result += max(turn_number, 0) * 1009
	
	return result


func has_already_emitted_turn(round_number:int, turn_number:int, player_id:int) -> bool:
	if last_emitted_round_number != round_number:
		return false
	
	if last_emitted_turn_number != turn_number:
		return false
	
	if last_emitted_player_id != player_id:
		return false
	
	return true


func reset_detection_history() -> void:
	last_emitted_round_number = -1
	last_emitted_turn_number = -1
	last_emitted_player_id = -1


func _on_current_player_changed(_player_id:int) -> void:
	refresh_turn_detection()


func _on_turn_phase_changed(_turn_phase:Global.TURN_PHASE) -> void:
	refresh_turn_detection()


func _on_turn_number_changed(_turn_number:int) -> void:
	refresh_turn_detection()


func _on_round_number_changed(_round_number:int) -> void:
	refresh_turn_detection()


func _on_winner_changed(_winner_id:int) -> void:
	refresh_turn_detection()


func _on_active_players_changed() -> void:
	refresh_turn_detection()
