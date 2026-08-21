class_name BotActionOutcomeEvaluation
extends RefCounted

var probability:float = 0.0

var board_score:float = 0.0
var tactical_adjustment:float = 0.0
var combined_score:float = 0.0

var terminal:bool = false
var winner_id:int = -1

var opponent_threat_penalties:Dictionary = {}
var opponent_best_win_probabilities:Dictionary = {}
var opponent_turn_distances:Dictionary = {}

var tactical_simulated_outcome_count:int = 0


func setup(new_probability:float) -> bool:
	if new_probability <= 0.0:
		return false
	
	probability = new_probability
	return true


func set_board_evaluation(new_board_score:float, new_terminal:bool, new_winner_id:int) -> void:
	board_score = new_board_score
	terminal = new_terminal
	winner_id = new_winner_id
	update_combined_score()


func set_tactical_adjustment(new_tactical_adjustment:float) -> void:
	tactical_adjustment = new_tactical_adjustment
	update_combined_score()


func add_opponent_threat(player_id:int, turn_distance:int, best_win_probability:float, penalty:float) -> void:
	opponent_threat_penalties[player_id] = penalty
	opponent_best_win_probabilities[player_id] = best_win_probability
	opponent_turn_distances[player_id] = turn_distance
	
	tactical_adjustment -= penalty
	update_combined_score()


func get_opponent_threat_penalty(player_id:int) -> float:
	return float(opponent_threat_penalties.get(player_id, 0.0))


func get_opponent_best_win_probability(player_id:int) -> float:
	return float(opponent_best_win_probabilities.get(player_id, 0.0))


func get_opponent_turn_distance(player_id:int) -> int:
	return int(opponent_turn_distances.get(player_id, -1))


func has_opponent_immediate_threat(player_id:int) -> bool:
	return get_opponent_threat_penalty(player_id) > 0.0


func update_combined_score() -> void:
	combined_score = board_score + tactical_adjustment
