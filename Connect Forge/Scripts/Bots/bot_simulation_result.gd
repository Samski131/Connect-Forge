class_name BotSimulationResult
extends RefCounted

var success:bool = false
var error_message:String = ""

var state:BotSimulationState = null
var board:BotSimulationBoard = null
var action:BotAction = null

var winner_id:int = -1
var winning_slots:Array[Vector2i] = []
var resolution_steps:int = 0

var disposed:bool = false


func set_action(new_action:BotAction) -> void:
	if new_action == null:
		action = null
		return
	
	action = new_action.duplicate_action()


func set_simulation_resources(new_state:BotSimulationState, new_board:BotSimulationBoard) -> void:
	state = new_state
	board = new_board


func mark_success() -> void:
	success = true
	error_message = ""


func mark_failure(new_error_message:String) -> void:
	success = false
	error_message = new_error_message
	clear_simulation_resources()


func set_winning_result(new_winner_id:int, new_winning_slots:Array[Vector2i]) -> void:
	winner_id = new_winner_id
	winning_slots.clear()
	
	for slot in new_winning_slots:
		winning_slots.append(slot)


func clear_simulation_resources() -> void:
	if board != null:
		if is_instance_valid(board):
			board.dispose()
			board.free()
	
	board = null
	
	if state != null:
		state.dispose()
	
	state = null


func dispose() -> void:
	if disposed:
		return
	
	disposed = true
	
	clear_simulation_resources()
	
	action = null
	winning_slots.clear()
	winner_id = -1
	resolution_steps = 0
