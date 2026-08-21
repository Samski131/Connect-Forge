class_name BotMoveSelectionResult
extends RefCounted

var valid:bool = false
var error_message:String = ""

var player_id:int = -1

var generated_action_count:int = 0
var evaluated_action_count:int = 0

var primary_simulated_outcome_count:int = 0
var tactical_simulated_outcome_count:int = 0

var action_generation_time_usec:int = 0
var chance_outcome_generation_time_usec:int = 0
var primary_simulation_time_usec:int = 0
var board_evaluation_time_usec:int = 0
var tactical_analysis_time_usec:int = 0
var resource_evaluation_time_usec:int = 0
var action_evaluation_time_usec:int = 0
var ranking_time_usec:int = 0
var total_selection_time_usec:int = 0

var best_action:BotAction = null
var best_evaluation:BotActionEvaluation = null

var ranked_evaluations:Array[BotActionEvaluation] = []


func mark_success() -> void:
	valid = true
	error_message = ""


func mark_failure(new_error_message:String) -> void:
	valid = false
	error_message = new_error_message
	best_action = null
	best_evaluation = null
	ranked_evaluations.clear()
	evaluated_action_count = 0
	primary_simulated_outcome_count = 0
	tactical_simulated_outcome_count = 0


func set_ranked_evaluations(new_ranked_evaluations:Array[BotActionEvaluation]) -> bool:
	ranked_evaluations.clear()
	evaluated_action_count = 0
	primary_simulated_outcome_count = 0
	tactical_simulated_outcome_count = 0
	
	chance_outcome_generation_time_usec = 0
	primary_simulation_time_usec = 0
	board_evaluation_time_usec = 0
	tactical_analysis_time_usec = 0
	resource_evaluation_time_usec = 0
	
	best_action = null
	best_evaluation = null
	
	if new_ranked_evaluations.is_empty():
		return false
	
	for evaluation in new_ranked_evaluations:
		if evaluation == null:
			return false
		
		if evaluation.valid == false:
			return false
		
		if evaluation.action == null:
			return false
		
		ranked_evaluations.append(evaluation)
		
		evaluated_action_count += 1
		primary_simulated_outcome_count += evaluation.primary_simulated_outcome_count
		tactical_simulated_outcome_count += evaluation.tactical_simulated_outcome_count
		
		chance_outcome_generation_time_usec += evaluation.chance_outcome_generation_time_usec
		primary_simulation_time_usec += evaluation.primary_simulation_time_usec
		board_evaluation_time_usec += evaluation.board_evaluation_time_usec
		tactical_analysis_time_usec += evaluation.tactical_analysis_time_usec
		resource_evaluation_time_usec += evaluation.resource_evaluation_time_usec
	
	best_evaluation = ranked_evaluations[0]
	best_action = best_evaluation.action.duplicate_action()
	
	return best_action != null


func has_selection() -> bool:
	return valid and best_action != null and best_evaluation != null


func get_second_best_evaluation() -> BotActionEvaluation:
	if ranked_evaluations.size() < 2:
		return null
	
	return ranked_evaluations[1]


func get_score_margin() -> float:
	var second_best:BotActionEvaluation = get_second_best_evaluation()
	
	if best_evaluation == null:
		return 0.0
	
	if second_best == null:
		return 0.0
	
	return best_evaluation.final_score - second_best.final_score


func get_unaccounted_evaluation_time_usec() -> int:
	var accounted_time:int = 0
	
	accounted_time += chance_outcome_generation_time_usec
	accounted_time += primary_simulation_time_usec
	accounted_time += board_evaluation_time_usec
	accounted_time += tactical_analysis_time_usec
	accounted_time += resource_evaluation_time_usec
	
	return max(action_evaluation_time_usec - accounted_time, 0)


func usec_to_msec(usec:int) -> float:
	return float(usec) / 1000.0
