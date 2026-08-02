class_name ActionLogic
extends Node

enum Report {RESOLVED, IN_PROGRESS,EMPTY}

var game_manager:GameManager = null
var board:BoardManager = null


func setup(new_game_manager:GameManager, new_board:BoardManager) -> void:
	game_manager = new_game_manager
	board = new_board


func enter_state() -> void:
	reset_token_resolution()


func exit_state() -> void:
	if game_manager == null:
		return
	
	game_manager.enter_resolution_phase()


func process_state() -> void:
	if board == null:
		return
	
	if board.visuals != null and board.visuals.is_busy():
		return
	
	if board.trigger_resolver.resolve_pending_pass_triggers():
		return
	
	if board.visuals != null and board.visuals.is_busy():
		return
	
	if process_movement_pass():
		return
	
	if board.visuals != null and board.visuals.is_busy():
		return
	
	if board.trigger_resolver.resolve_line_full_triggers():
		return
	
	if board.visuals != null and board.visuals.is_busy():
		return
	
	process_resolution_pass()


func report_on_token(token:Token) -> Report:
	if token == null:
		return Report.EMPTY
	
	if token.resolved:
		return Report.RESOLVED
	
	var reached_limit:bool = board.token_mover.is_token_supported(token)
	
	if reached_limit == false:
		return Report.IN_PROGRESS
	
	var trigger_was_used:bool = board.trigger_resolver.resolve_landing_triggers(token)
	
	if trigger_was_used:
		return Report.IN_PROGRESS
	
	var ability_was_used:bool = token._try_to_use_ability()
	
	if ability_was_used:
		return Report.IN_PROGRESS
	
	token.resolved = true
	return Report.RESOLVED


func reset_token_resolution() -> void:
	get_tree().call_group("token", "reset_resolved")


func process_movement_pass() -> bool:
	if board == null:
		return false
	
	var moved_any_token:bool = false
	
	if board.visuals != null:
		board.visuals.begin_move_batch()
	
	for position in board.get_positions_in_gravity_order():
		var token:Token = board.get_token(position)
		
		if token == null:
			continue
		
		if token.resolved:
			continue
		
		if token.being_destroyed:
			continue
		
		if board.token_mover.is_token_supported(token):
			continue
		
		if board.token_mover.try_apply_gravity_to_token(token):
			moved_any_token = true
	
	if board.visuals != null:
		board.visuals.end_move_batch()
	
	return moved_any_token


func process_resolution_pass() -> void:
	if board == null:
		return
	
	for position in board.get_positions_in_gravity_order():
		var token:Token = board.get_token(position)
		var report:Report = report_on_token(token)
		
		if report == Report.IN_PROGRESS:
			return
		
		if board.visuals != null and board.visuals.is_busy():
			return
	
	if board.visuals != null and board.visuals.is_busy():
		return
	
	exit_state()
