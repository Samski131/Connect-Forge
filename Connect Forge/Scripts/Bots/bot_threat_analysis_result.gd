class_name BotThreatAnalysisResult
extends RefCounted

var valid:bool = false
var error_message:String = ""

var terminal:bool = false
var winner_id:int = -1

var reference_current_player_id:int = -1
var next_player_id:int = -1

var player_results_by_id:Dictionary = {}

var total_legal_actions:int = 0
var total_simulated_outcomes:int = 0


func mark_success() -> void:
	valid = true
	error_message = ""


func mark_failure(new_error_message:String) -> void:
	valid = false
	error_message = new_error_message


func add_player_result(player_result:BotPlayerThreatResult) -> void:
	if player_result == null:
		return
	
	player_results_by_id[player_result.player_id] = player_result
	total_legal_actions += player_result.legal_action_count
	total_simulated_outcomes += player_result.simulated_outcome_count


func has_player_result(player_id:int) -> bool:
	return player_results_by_id.has(player_id)


func get_player_result(player_id:int) -> BotPlayerThreatResult:
	if player_results_by_id.has(player_id) == false:
		return null
	
	var player_result:BotPlayerThreatResult = player_results_by_id[player_id] as BotPlayerThreatResult
	return player_result


func get_next_player_result() -> BotPlayerThreatResult:
	return get_player_result(next_player_id)


func next_player_has_immediate_win() -> bool:
	var player_result:BotPlayerThreatResult = get_next_player_result()
	
	if player_result == null:
		return false
	
	return player_result.has_immediate_win()


func next_player_has_guaranteed_immediate_win() -> bool:
	var player_result:BotPlayerThreatResult = get_next_player_result()
	
	if player_result == null:
		return false
	
	return player_result.has_guaranteed_immediate_win()
