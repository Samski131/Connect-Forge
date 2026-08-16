class_name ReplayStep
extends RefCounted

var step_id:int = -1
var step_type:String = ReplayFormat.STEP_ACTION

var round_number:int = 1
var turn_number:int = 1
var player_id:int = -1

var state_actions:Array[ReplayAction] = []
var presentation:ReplayAction = null

var metadata:Dictionary = {}


func _init(new_step_id:int = -1, new_step_type:String = ReplayFormat.STEP_ACTION) -> void:
	step_id = new_step_id
	step_type = new_step_type
	round_number = 1
	turn_number = 1
	player_id = -1
	state_actions.clear()
	presentation = null
	metadata.clear()


func add_state_action(action:ReplayAction) -> bool:
	if action == null:
		return false
	
	if action.is_state_action() == false:
		return false
	
	state_actions.append(action)
	return true


func set_presentation(action:ReplayAction) -> bool:
	if action == null:
		presentation = null
		return true
	
	if action.is_state_action():
		return false
	
	presentation = action
	return true


func set_context(new_round_number:int, new_turn_number:int, new_player_id:int) -> void:
	round_number = max(new_round_number, 1)
	turn_number = max(new_turn_number, 1)
	player_id = new_player_id


func set_metadata_value(key:String, value) -> bool:
	var used_key:String = key.strip_edges()
	
	if used_key == "":
		return false
	
	if ReplayAction.is_json_safe_value(value) == false:
		return false
	
	metadata[used_key] = value
	return true


func is_valid() -> bool:
	if step_id < 0:
		return false
	
	if ReplayFormat.is_valid_step_type(step_type) == false:
		return false
	
	if round_number < 1:
		return false
	
	if turn_number < 1:
		return false
	
	if ReplayAction.is_json_safe_dictionary(metadata) == false:
		return false
	
	for action in state_actions:
		if action == null:
			return false
		
		if action.is_state_action() == false:
			return false
		
		if action.is_valid() == false:
			return false
	
	if presentation != null:
		if presentation.is_state_action():
			return false
		
		if presentation.is_valid() == false:
			return false
	
	return true


func to_dictionary() -> Dictionary:
	var result:Dictionary = {
		"id": step_id,
		"type": step_type,
		"round": round_number,
		"turn": turn_number,
		"player": player_id
	}
	
	if state_actions.is_empty() == false:
		var serialized_state_actions:Array = []
		
		for action in state_actions:
			if action == null:
				continue
			
			serialized_state_actions.append(action.to_dictionary())
		
		result["state"] = serialized_state_actions
	
	if presentation != null:
		result["presentation"] = presentation.to_dictionary()
	
	if metadata.is_empty() == false:
		result["metadata"] = metadata.duplicate(true)
	
	return result


static func from_dictionary(data:Dictionary) -> ReplayStep:
	var used_step_id:int = int(data.get("id", -1))
	var used_step_type:String = str(data.get("type", ReplayFormat.STEP_ACTION))
	
	var step:ReplayStep = ReplayStep.new(used_step_id, used_step_type)
	step.round_number = int(data.get("round", 1))
	step.turn_number = int(data.get("turn", 1))
	step.player_id = int(data.get("player", -1))
	
	if data.has("state"):
		if typeof(data["state"]) != TYPE_ARRAY:
			return null
		
		var serialized_state_actions:Array = data["state"]
		
		for action_value in serialized_state_actions:
			if typeof(action_value) != TYPE_DICTIONARY:
				return null
			
			var action:ReplayAction = ReplayAction.from_dictionary(action_value)
			
			if action == null:
				return null
			
			if action.is_state_action() == false:
				return null
			
			step.state_actions.append(action)
	
	if data.has("presentation"):
		if typeof(data["presentation"]) != TYPE_DICTIONARY:
			return null
		
		var presentation_action:ReplayAction = ReplayAction.from_dictionary(data["presentation"])
		
		if presentation_action == null:
			return null
		
		if presentation_action.is_state_action():
			return null
		
		step.presentation = presentation_action
	
	if data.has("metadata"):
		if typeof(data["metadata"]) != TYPE_DICTIONARY:
			return null
		
		step.metadata = data["metadata"].duplicate(true)
	
	if step.is_valid() == false:
		return null
	
	return step
