class_name BotSimulationResolutionLogic
extends ResolutionLogic

var simulation_session:MatchSession = null


func setup_simulation(new_board:BoardManager, new_session:MatchSession) -> bool:
	if new_board == null:
		return false
	
	if new_session == null:
		return false
	
	board = new_board
	simulation_session = new_session
	game_manager = null
	
	return true


func is_valid_winning_player(player_id:int) -> bool:
	if simulation_session == null:
		return false
	
	return simulation_session.is_valid_player_id(player_id)
