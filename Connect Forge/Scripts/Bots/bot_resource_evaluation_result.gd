class_name BotResourceEvaluationResult
extends RefCounted

var valid:bool = false
var error_message:String = ""

var player_id:int = -1
var token_type:int = -1
var token_name:String = ""

var token_cost:int = 0
var purchasable:bool = false

var starting_count:int = 0
var before_count:int = 0
var after_count:int = 0
var spent_count:int = 0

var scarcity_multiplier:float = 1.0
var depletion_multiplier:float = 1.0
var last_copy_multiplier:float = 1.0

var preservation_penalty:float = 0.0


func mark_success() -> void:
	valid = true
	error_message = ""


func mark_failure(new_error_message:String) -> void:
	valid = false
	error_message = new_error_message
	preservation_penalty = 0.0


func was_resource_spent() -> bool:
	return spent_count > 0


func used_last_copy() -> bool:
	return before_count > 0 and after_count == 0 and spent_count > 0
