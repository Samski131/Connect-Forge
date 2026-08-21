class_name BotActionEvaluation
extends RefCounted

const PROBABILITY_TOLERANCE:float = 0.0001

var valid:bool = false
var error_message:String = ""

var action:BotAction = null

var final_score:float = 0.0

var expected_board_score:float = 0.0
var expected_tactical_adjustment:float = 0.0
var expected_position_score:float = 0.0

var resource_penalty:float = 0.0

var chance_outcome_count:int = 0
var primary_simulated_outcome_count:int = 0
var tactical_simulated_outcome_count:int = 0

var chance_outcome_generation_time_usec:int = 0
var primary_simulation_time_usec:int = 0
var board_evaluation_time_usec:int = 0
var tactical_analysis_time_usec:int = 0
var resource_evaluation_time_usec:int = 0
var total_evaluation_time_usec:int = 0

var probability_total:float = 0.0

var win_probability:float = 0.0
var loss_probability:float = 0.0
var nonterminal_probability:float = 0.0

var outcome_evaluations:Array[BotActionOutcomeEvaluation] = []


func setup(new_action:BotAction) -> bool:
	if new_action == null:
		return false
	
	if new_action.is_well_formed() == false:
		return false
	
	action = new_action.duplicate_action()
	return true


func mark_success() -> void:
	valid = true
	error_message = ""


func mark_failure(new_error_message:String) -> void:
	valid = false
	error_message = new_error_message
	final_score = 0.0


func add_outcome_evaluation(outcome:BotActionOutcomeEvaluation) -> bool:
	if outcome == null:
		return false
	
	if outcome.probability <= 0.0:
		return false
	
	outcome_evaluations.append(outcome)
	chance_outcome_count += 1
	primary_simulated_outcome_count += 1
	tactical_simulated_outcome_count += outcome.tactical_simulated_outcome_count
	
	probability_total += outcome.probability
	
	expected_board_score += outcome.board_score * outcome.probability
	expected_tactical_adjustment += outcome.tactical_adjustment * outcome.probability
	expected_position_score += outcome.combined_score * outcome.probability
	
	if action != null:
		if outcome.winner_id == action.player_id:
			win_probability += outcome.probability
		elif outcome.winner_id != -1:
			loss_probability += outcome.probability
		else:
			nonterminal_probability += outcome.probability
	
	return true


func finalize(new_resource_penalty:float) -> bool:
	if action == null:
		mark_failure("BotActionEvaluation: Cannot finalize without an action.")
		return false
	
	if outcome_evaluations.is_empty():
		mark_failure("BotActionEvaluation: Cannot finalize without simulated outcomes.")
		return false
	
	if abs(probability_total - 1.0) > PROBABILITY_TOLERANCE:
		mark_failure("BotActionEvaluation: Outcome probabilities total %.6f instead of 1.0." % probability_total)
		return false
	
	resource_penalty = max(new_resource_penalty, 0.0)
	final_score = expected_position_score - resource_penalty
	
	mark_success()
	return true


func is_guaranteed_win() -> bool:
	return win_probability >= 1.0 - PROBABILITY_TOLERANCE


func has_possible_win() -> bool:
	return win_probability > PROBABILITY_TOLERANCE


func has_possible_loss() -> bool:
	return loss_probability > PROBABILITY_TOLERANCE
