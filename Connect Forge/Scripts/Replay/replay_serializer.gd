class_name ReplaySerializer
extends RefCounted

const MAXIMUM_REPLAY_SIZE_BYTES:int = 10 * 1024 * 1024
const MAXIMUM_PLAYERS:int = 16
const MAXIMUM_STEPS:int = 100000
const MAXIMUM_CHECKPOINTS:int = 5000
const MAXIMUM_ACTIONS:int = 500000
const MAXIMUM_ACTION_TREE_DEPTH:int = 32


static func serialize(replay:ReplayData) -> String:
	if replay == null:
		push_error("ReplaySerializer: Cannot serialize a null replay.")
		return ""
	
	if validate_replay_limits(replay) == false:
		push_error("ReplaySerializer: Replay failed validation.")
		return ""
	
	var data:Dictionary = replay.to_dictionary()
	var json_text:String = JSON.stringify(data, "\t")
	
	if json_text.to_utf8_buffer().size() > MAXIMUM_REPLAY_SIZE_BYTES:
		push_error("ReplaySerializer: Serialized replay exceeds the maximum file size.")
		return ""
	
	return json_text


static func deserialize(json_text:String) -> ReplayData:
	if json_text.strip_edges() == "":
		push_error("ReplaySerializer: Cannot deserialize empty replay data.")
		return null
	
	if json_text.to_utf8_buffer().size() > MAXIMUM_REPLAY_SIZE_BYTES:
		push_error("ReplaySerializer: Replay data exceeds the maximum allowed size.")
		return null
	
	var json:JSON = JSON.new()
	var parse_result:Error = json.parse(json_text)
	
	if parse_result != OK:
		push_error("ReplaySerializer: JSON parsing failed on line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null
	
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("ReplaySerializer: Replay root must be a dictionary.")
		return null
	
	var data:Dictionary = json.data
	var replay:ReplayData = ReplayData.from_dictionary(data)
	
	if replay == null:
		push_error("ReplaySerializer: Replay structure is invalid or unsupported.")
		return null
	
	if validate_replay_limits(replay) == false:
		push_error("ReplaySerializer: Loaded replay exceeded safety limits.")
		return null
	
	return replay


static func validate_replay_limits(replay:ReplayData) -> bool:
	if replay == null:
		return false
	
	if replay.is_valid() == false:
		return false
	
	if replay.players.size() > MAXIMUM_PLAYERS:
		return false
	
	if replay.steps.size() > MAXIMUM_STEPS:
		return false
	
	if replay.checkpoints.size() > MAXIMUM_CHECKPOINTS:
		return false
	
	for checkpoint in replay.checkpoints:
		if checkpoint == null:
			return false
		
		if checkpoint.is_valid() == false:
			return false
	
	var total_action_count:int = 0
	
	for step in replay.steps:
		if step == null:
			return false
		
		for state_action in step.state_actions:
			if state_action == null:
				return false
			
			var state_action_count:int = count_action_tree(state_action, 0)
			
			if state_action_count < 0:
				return false
			
			total_action_count += state_action_count
			
			if total_action_count > MAXIMUM_ACTIONS:
				return false
		
		if step.presentation != null:
			var presentation_action_count:int = count_action_tree(step.presentation, 0)
			
			if presentation_action_count < 0:
				return false
			
			total_action_count += presentation_action_count
			
			if total_action_count > MAXIMUM_ACTIONS:
				return false
	
	return true


static func count_action_tree(action:ReplayAction, depth:int) -> int:
	if action == null:
		return -1
	
	if depth > MAXIMUM_ACTION_TREE_DEPTH:
		return -1
	
	var action_count:int = 1
	
	for child in action.children:
		var child_count:int = count_action_tree(child, depth + 1)
		
		if child_count < 0:
			return -1
		
		action_count += child_count
		
		if action_count > MAXIMUM_ACTIONS:
			return -1
	
	return action_count
