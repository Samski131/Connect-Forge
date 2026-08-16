class_name ReplayAction
extends RefCounted

var action_type:String = ""
var action_version:int = ReplayFormat.ACTION_VERSION_DEFAULT
var channel:String = ReplayFormat.ACTION_CHANNEL_PRESENTATION
var payload:Dictionary = {}
var children:Array[ReplayAction] = []


func _init(new_action_type:String = "", new_channel:String = ReplayFormat.ACTION_CHANNEL_PRESENTATION, new_action_version:int = ReplayFormat.ACTION_VERSION_DEFAULT, new_payload:Dictionary = {}) -> void:
	action_type = new_action_type
	channel = new_channel
	action_version = max(new_action_version, 1)
	payload = new_payload.duplicate(true)
	children.clear()


func add_child(action:ReplayAction) -> bool:
	if action == null:
		return false
	
	children.append(action)
	return true


func add_children(actions:Array[ReplayAction]) -> void:
	for action in actions:
		if action == null:
			continue
		
		children.append(action)


func is_group() -> bool:
	return channel == ReplayFormat.ACTION_CHANNEL_GROUP


func is_state_action() -> bool:
	return channel == ReplayFormat.ACTION_CHANNEL_STATE


func is_presentation_action() -> bool:
	return channel == ReplayFormat.ACTION_CHANNEL_PRESENTATION


func is_sequence() -> bool:
	return is_group() and action_type == ReplayFormat.GROUP_SEQUENCE


func is_parallel() -> bool:
	return is_group() and action_type == ReplayFormat.GROUP_PARALLEL


func is_valid() -> bool:
	if action_type.strip_edges() == "":
		return false
	
	if action_version < 1:
		return false
	
	if ReplayFormat.is_valid_action_channel(channel) == false:
		return false
	
	if is_json_safe_dictionary(payload) == false:
		return false
	
	if is_group():
		if ReplayFormat.is_group_type(action_type) == false:
			return false
		
		for child in children:
			if child == null:
				return false
			
			if child.is_valid() == false:
				return false
		
		return true
	
	if children.is_empty() == false:
		return false
	
	return true


func to_dictionary() -> Dictionary:
	var result:Dictionary = {
		"type": action_type,
		"version": action_version,
		"channel": channel
	}
	
	if payload.is_empty() == false:
		result["payload"] = payload.duplicate(true)
	
	if children.is_empty() == false:
		var serialized_children:Array = []
		
		for child in children:
			if child == null:
				continue
			
			serialized_children.append(child.to_dictionary())
		
		result["children"] = serialized_children
	
	return result


static func from_dictionary(data:Dictionary) -> ReplayAction:
	var used_type:String = str(data.get("type", "")).strip_edges()
	var used_channel:String = str(data.get("channel", "")).strip_edges()
	var used_version:int = int(data.get("version", ReplayFormat.ACTION_VERSION_DEFAULT))
	var used_payload:Dictionary = {}
	
	if data.has("payload"):
		if typeof(data["payload"]) != TYPE_DICTIONARY:
			return null
		
		used_payload = data["payload"].duplicate(true)
	
	var action:ReplayAction = ReplayAction.new(used_type, used_channel, used_version, used_payload)
	
	if data.has("children"):
		if typeof(data["children"]) != TYPE_ARRAY:
			return null
		
		var serialized_children:Array = data["children"]
		
		for child_value in serialized_children:
			if typeof(child_value) != TYPE_DICTIONARY:
				return null
			
			var child:ReplayAction = ReplayAction.from_dictionary(child_value)
			
			if child == null:
				return null
			
			action.children.append(child)
	
	if action.is_valid() == false:
		return null
	
	return action


static func create_state(action_type:String, payload:Dictionary = {}, action_version:int = ReplayFormat.ACTION_VERSION_DEFAULT) -> ReplayAction:
	return ReplayAction.new(action_type, ReplayFormat.ACTION_CHANNEL_STATE, action_version, payload)


static func create_presentation(action_type:String, payload:Dictionary = {}, action_version:int = ReplayFormat.ACTION_VERSION_DEFAULT) -> ReplayAction:
	return ReplayAction.new(action_type, ReplayFormat.ACTION_CHANNEL_PRESENTATION, action_version, payload)


static func create_sequence(actions:Array[ReplayAction]) -> ReplayAction:
	var group:ReplayAction = ReplayAction.new(ReplayFormat.GROUP_SEQUENCE, ReplayFormat.ACTION_CHANNEL_GROUP)
	group.add_children(actions)
	return group


static func create_parallel(actions:Array[ReplayAction]) -> ReplayAction:
	var group:ReplayAction = ReplayAction.new(ReplayFormat.GROUP_PARALLEL, ReplayFormat.ACTION_CHANNEL_GROUP)
	group.add_children(actions)
	return group


static func grid_position_to_data(position:Vector2i) -> Array:
	return [position.x, position.y]


static func grid_path_to_data(path:Array[Vector2i]) -> Array:
	var result:Array = []
	
	for position in path:
		result.append(grid_position_to_data(position))
	
	return result


static func colour_to_data(colour:Color) -> Array:
	return [colour.r, colour.g, colour.b, colour.a]


static func is_json_safe_dictionary(dictionary:Dictionary) -> bool:
	for key in dictionary.keys():
		if typeof(key) != TYPE_STRING:
			return false
		
		if is_json_safe_value(dictionary[key]) == false:
			return false
	
	return true


static func is_json_safe_value(value) -> bool:
	var value_type:int = typeof(value)
	
	if value_type == TYPE_NIL:
		return true
	
	if value_type == TYPE_BOOL:
		return true
	
	if value_type == TYPE_INT:
		return true
	
	if value_type == TYPE_FLOAT:
		return true
	
	if value_type == TYPE_STRING:
		return true
	
	if value_type == TYPE_ARRAY:
		var array_value:Array = value
		
		for entry in array_value:
			if is_json_safe_value(entry) == false:
				return false
		
		return true
	
	if value_type == TYPE_DICTIONARY:
		return is_json_safe_dictionary(value)
	
	return false
