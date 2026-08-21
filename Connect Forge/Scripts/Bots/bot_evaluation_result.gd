class_name BotEvaluationResult
extends RefCounted

var valid:bool = false
var error_message:String = ""

var perspective_player_id:int = -1
var score:float = 0.0

var terminal:bool = false
var winner_id:int = -1

var player_line_scores:Dictionary = {}
var player_open_line_counts:Dictionary = {}

var total_windows:int = 0
var empty_windows:int = 0
var contested_windows:int = 0


func mark_success() -> void:
	valid = true
	error_message = ""


func mark_failure(new_error_message:String) -> void:
	valid = false
	error_message = new_error_message
	score = 0.0


func initialize_player(player_id:int) -> void:
	if player_line_scores.has(player_id) == false:
		player_line_scores[player_id] = 0.0
	
	if player_open_line_counts.has(player_id) == false:
		player_open_line_counts[player_id] = 0


func add_line_score(player_id:int, value:float) -> void:
	initialize_player(player_id)
	
	var current_score:float = float(player_line_scores.get(player_id, 0.0))
	player_line_scores[player_id] = current_score + value
	
	var current_count:int = int(player_open_line_counts.get(player_id, 0))
	player_open_line_counts[player_id] = current_count + 1


func get_player_line_score(player_id:int) -> float:
	return float(player_line_scores.get(player_id, 0.0))


func get_player_open_line_count(player_id:int) -> int:
	return int(player_open_line_counts.get(player_id, 0))
