class_name ReplayData
extends RefCounted

const DEVELOPMENT_GAME_VERSION:String = "development"

var game_version:String = ""
var match_id:String = ""
var created_utc:String = ""

var metadata:Dictionary = {}
var players:Array[Dictionary] = []
var steps:Array[ReplayStep] = []
var checkpoints:Array[ReplayCheckpoint] = []


func _init() -> void:
	clear()


func clear() -> void:
	game_version = ""
	match_id = ""
	created_utc = ""
	
	metadata.clear()
	players.clear()
	steps.clear()
	checkpoints.clear()


func setup_new_replay(new_match_id:String) -> bool:
	clear()
	
	var used_match_id:String = new_match_id.strip_edges()
	
	if used_match_id == "":
		return false
	
	match_id = used_match_id
	game_version = get_current_game_version()
	created_utc = Time.get_datetime_string_from_system(true, true)
	return true


func get_current_game_version() -> String:
	var project_version:String = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	
	if project_version == "":
		return DEVELOPMENT_GAME_VERSION
	
	return project_version


func add_step(step:ReplayStep) -> bool:
	if step == null:
		return false
	
	if step.is_valid() == false:
		return false
	
	if step.step_id != steps.size():
		return false
	
	steps.append(step)
	return true


func create_next_step(step_type:String = ReplayFormat.STEP_ACTION) -> ReplayStep:
	return ReplayStep.new(steps.size(), step_type)


func get_step(step_id:int) -> ReplayStep:
	if step_id < 0:
		return null
	
	if step_id >= steps.size():
		return null
	
	return steps[step_id]


func get_step_count() -> int:
	return steps.size()


func add_player(player_data:Dictionary) -> bool:
	if ReplayAction.is_json_safe_dictionary(player_data) == false:
		return false
	
	players.append(player_data.duplicate(true))
	return true


func set_metadata_value(key:String, value) -> bool:
	var used_key:String = key.strip_edges()
	
	if used_key == "":
		return false
	
	if ReplayAction.is_json_safe_value(value) == false:
		return false
	
	metadata[used_key] = value
	return true


func clear_checkpoints() -> void:
	checkpoints.clear()


func add_checkpoint(checkpoint:ReplayCheckpoint) -> bool:
	if checkpoint == null:
		return false
	
	if checkpoint.is_valid() == false:
		return false
	
	if checkpoint.after_step_id >= steps.size():
		return false
	
	if checkpoints.is_empty() == false:
		var previous_checkpoint:ReplayCheckpoint = checkpoints.back()
		
		if checkpoint.after_step_id <= previous_checkpoint.after_step_id:
			return false
	
	checkpoints.append(checkpoint)
	return true


func get_checkpoint_count() -> int:
	return checkpoints.size()


func is_valid() -> bool:
	if match_id.strip_edges() == "":
		return false
	
	if game_version.strip_edges() == "":
		return false
	
	if created_utc.strip_edges() == "":
		return false
	
	if ReplayAction.is_json_safe_dictionary(metadata) == false:
		return false
	
	for player_data in players:
		if ReplayAction.is_json_safe_dictionary(player_data) == false:
			return false
	
	for step_index in range(steps.size()):
		var step:ReplayStep = steps[step_index]
		
		if step == null:
			return false
		
		if step.step_id != step_index:
			return false
		
		if step.is_valid() == false:
			return false
	
	var previous_checkpoint_step:int = -2
	
	for checkpoint in checkpoints:
		if checkpoint == null:
			return false
		
		if checkpoint.is_valid() == false:
			return false
		
		if checkpoint.after_step_id >= steps.size():
			return false
		
		if checkpoint.after_step_id <= previous_checkpoint_step:
			return false
		
		previous_checkpoint_step = checkpoint.after_step_id
	
	return true


func to_dictionary() -> Dictionary:
	var result:Dictionary = ReplayFormat.create_file_header()
	
	result["game_version"] = game_version
	result["match_id"] = match_id
	result["created_utc"] = created_utc
	
	if metadata.is_empty() == false:
		result["metadata"] = metadata.duplicate(true)
	
	if players.is_empty() == false:
		result["players"] = players.duplicate(true)
	
	var serialized_steps:Array = []
	
	for step in steps:
		if step == null:
			continue
		
		serialized_steps.append(step.to_dictionary())
	
	result["steps"] = serialized_steps
	
	if checkpoints.is_empty() == false:
		var serialized_checkpoints:Array = []
		
		for checkpoint in checkpoints:
			if checkpoint == null:
				continue
			
			serialized_checkpoints.append(checkpoint.to_dictionary())
		
		result["checkpoints"] = serialized_checkpoints
	
	return result


static func from_dictionary(data:Dictionary) -> ReplayData:
	if ReplayFormat.is_valid_file_header(data) == false:
		return null
	
	var replay:ReplayData = ReplayData.new()
	
	replay.game_version = str(data.get("game_version", "")).strip_edges()
	replay.match_id = str(data.get("match_id", "")).strip_edges()
	replay.created_utc = str(data.get("created_utc", "")).strip_edges()
	
	if data.has("metadata"):
		if typeof(data["metadata"]) != TYPE_DICTIONARY:
			return null
		
		replay.metadata = data["metadata"].duplicate(true)
	
	if data.has("players"):
		if typeof(data["players"]) != TYPE_ARRAY:
			return null
		
		var serialized_players:Array = data["players"]
		
		for player_value in serialized_players:
			if typeof(player_value) != TYPE_DICTIONARY:
				return null
			
			var player_data:Dictionary = player_value
			
			if ReplayAction.is_json_safe_dictionary(player_data) == false:
				return null
			
			replay.players.append(player_data.duplicate(true))
	
	if data.has("steps") == false:
		return null
	
	if typeof(data["steps"]) != TYPE_ARRAY:
		return null
	
	var serialized_steps:Array = data["steps"]
	
	for step_value in serialized_steps:
		if typeof(step_value) != TYPE_DICTIONARY:
			return null
		
		var step:ReplayStep = ReplayStep.from_dictionary(step_value)
		
		if step == null:
			return null
		
		replay.steps.append(step)
	
	if data.has("checkpoints"):
		if typeof(data["checkpoints"]) != TYPE_ARRAY:
			return null
		
		var serialized_checkpoints:Array = data["checkpoints"]
		
		for checkpoint_value in serialized_checkpoints:
			if typeof(checkpoint_value) != TYPE_DICTIONARY:
				continue
			
			var checkpoint:ReplayCheckpoint = ReplayCheckpoint.from_dictionary(checkpoint_value)
			
			if checkpoint == null:
				continue
			
			if checkpoint.after_step_id >= replay.steps.size():
				continue
			
			if replay.checkpoints.is_empty() == false:
				var previous_checkpoint:ReplayCheckpoint = replay.checkpoints.back()
				
				if checkpoint.after_step_id <= previous_checkpoint.after_step_id:
					continue
			
			replay.checkpoints.append(checkpoint)
	
	if replay.is_valid() == false:
		return null
	
	return replay
