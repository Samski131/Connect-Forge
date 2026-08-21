class_name BotImmediateWinAction
extends RefCounted

const PROBABILITY_TOLERANCE:float = 0.0001

var action:BotAction = null

var win_probability:float = 0.0

var total_outcome_count:int = 0
var winning_outcome_count:int = 0


func setup(new_action:BotAction, new_win_probability:float, new_total_outcome_count:int, new_winning_outcome_count:int) -> bool:
	if new_action == null:
		return false
	
	if new_action.is_well_formed() == false:
		return false
	
	if new_win_probability <= 0.0:
		return false
	
	if new_total_outcome_count <= 0:
		return false
	
	if new_winning_outcome_count <= 0:
		return false
	
	if new_winning_outcome_count > new_total_outcome_count:
		return false
	
	action = new_action.duplicate_action()
	win_probability = clamp(new_win_probability, 0.0, 1.0)
	total_outcome_count = new_total_outcome_count
	winning_outcome_count = new_winning_outcome_count
	
	return true


func is_guaranteed_win() -> bool:
	return win_probability >= 1.0 - PROBABILITY_TOLERANCE


func is_possible_win() -> bool:
	return win_probability > PROBABILITY_TOLERANCE
