class_name ReplayCheckpoint
extends RefCounted

var after_step_id:int = -1
var state_data:Dictionary = {}


func _init(new_after_step_id:int = -1, new_state_data:Dictionary = {}) -> void:
	after_step_id = new_after_step_id
	state_data = new_state_data.duplicate(true)


func is_valid() -> bool:
	if after_step_id < -1:
		return false
	
	return ReplayAction.is_json_safe_dictionary(state_data)


func to_dictionary() -> Dictionary:
	return {
		"after_step": after_step_id,
		"state": state_data.duplicate(true)
	}


static func from_dictionary(data:Dictionary) -> ReplayCheckpoint:
	var after_step:int = int(data.get("after_step", -2))
	
	if data.has("state") == false:
		return null
	
	if typeof(data["state"]) != TYPE_DICTIONARY:
		return null
	
	var used_state_data:Dictionary = data["state"]
	var checkpoint:ReplayCheckpoint = ReplayCheckpoint.new(after_step, used_state_data)
	
	if checkpoint.is_valid() == false:
		return null
	
	return checkpoint
