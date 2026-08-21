class_name BotPlayerThreatResult
extends RefCounted

var valid:bool = false
var error_message:String = ""

var player_id:int = -1
var turn_distance:int = -1

var legal_action_count:int = 0
var simulated_outcome_count:int = 0

var winning_actions:Array[BotImmediateWinAction] = []

var guaranteed_winning_action_count:int = 0
var best_win_probability:float = 0.0


func setup(new_player_id:int, new_turn_distance:int) -> void:
	player_id = new_player_id
	turn_distance = new_turn_distance


func mark_success() -> void:
	valid = true
	error_message = ""


func mark_failure(new_error_message:String) -> void:
	valid = false
	error_message = new_error_message


func add_winning_action(winning_action:BotImmediateWinAction) -> void:
	if winning_action == null:
		return
	
	if winning_action.is_possible_win() == false:
		return
	
	winning_actions.append(winning_action)
	
	if winning_action.is_guaranteed_win():
		guaranteed_winning_action_count += 1
	
	if winning_action.win_probability > best_win_probability:
		best_win_probability = winning_action.win_probability


func has_immediate_win() -> bool:
	return winning_actions.is_empty() == false


func has_guaranteed_immediate_win() -> bool:
	return guaranteed_winning_action_count > 0


func get_immediate_winning_action_count() -> int:
	return winning_actions.size()
