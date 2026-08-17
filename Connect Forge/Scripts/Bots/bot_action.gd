class_name BotAction
extends RefCounted

var player_id:int = -1
var token_type:int = -1
var starting_slot:Vector2i = Vector2i(-1, -1)
var start_flipped:bool = false

var choice_data:Dictionary = {}
var placement_data:Dictionary = {}


func setup(new_player_id:int, new_token_type:int, new_starting_slot:Vector2i, new_start_flipped:bool = false, new_choice_data:Dictionary = {}) -> void:
	player_id = new_player_id
	token_type = new_token_type
	starting_slot = new_starting_slot
	start_flipped = new_start_flipped
	choice_data = new_choice_data.duplicate(true)
	placement_data.clear()


func set_choice_data(new_choice_data:Dictionary) -> void:
	choice_data = new_choice_data.duplicate(true)


func get_choice_data() -> Dictionary:
	return choice_data.duplicate(true)


func set_placement_data(new_placement_data:Dictionary) -> void:
	placement_data = new_placement_data.duplicate(true)


func get_placement_data() -> Dictionary:
	return placement_data.duplicate(true)


func is_well_formed() -> bool:
	if player_id < 0:
		return false
	
	if TokenLibrary.get_token_data(token_type).is_empty():
		return false
	
	if starting_slot.x < 0 or starting_slot.y < 0:
		return false
	
	if start_flipped and TokenLibrary.can_flip(token_type) == false:
		return false
	
	return true


func duplicate_action() -> BotAction:
	var result:BotAction = BotAction.new()
	result.setup(player_id, token_type, starting_slot, start_flipped, choice_data)
	result.set_placement_data(placement_data)
	return result


func get_description() -> String:
	var result:String = "Player %d: %s at %s" % [player_id, TokenLibrary.get_display_name(token_type), str(starting_slot)]
	
	if start_flipped:
		result += " flipped"
	
	if choice_data.is_empty() == false:
		result += " choices=%s" % str(choice_data)
	
	return result
