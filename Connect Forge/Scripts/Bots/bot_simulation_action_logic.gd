class_name BotSimulationActionLogic
extends ActionLogic

var resolution_finished:bool = false


func setup_simulation(new_board:BoardManager) -> bool:
	if new_board == null:
		return false
	
	game_manager = null
	board = new_board
	resolution_finished = false
	
	return true


func enter_state() -> void:
	resolution_finished = false
	reset_token_resolution()


func exit_state() -> void:
	resolution_finished = true


func reset_token_resolution() -> void:
	if board == null:
		return
	
	for position in board.get_positions_in_gravity_order():
		var token:Token = board.get_token(position)
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		if token.being_destroyed:
			continue
		
		token.reset_resolved()


func process_simulation_step() -> void:
	if resolution_finished:
		return
	
	if board == null:
		return
	
	process_state()
	
	var simulation_mover:BotSimulationTokenMover = board.token_mover as BotSimulationTokenMover
	
	if simulation_mover != null:
		simulation_mover.flush_destroyed_tokens()


func is_resolution_finished() -> bool:
	return resolution_finished
