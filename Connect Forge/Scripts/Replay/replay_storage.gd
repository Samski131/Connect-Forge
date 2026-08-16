class_name ReplayStorage
extends RefCounted


static func save_replay(replay:ReplayData) -> String:
	if replay == null:
		push_error("ReplayStorage: Cannot save a null replay.")
		return ""
	
	var json_text:String = ReplaySerializer.serialize(replay)
	
	if json_text == "":
		return ""
	
	if ensure_replay_directory() == false:
		push_error("ReplayStorage: Could not create the replay directory.")
		return ""
	
	var file_name:String = create_replay_file_name(replay)
	var file_path:String = ReplayFormat.REPLAY_DIRECTORY.path_join(file_name)
	
	var file:FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		push_error("ReplayStorage: Could not open '%s' for writing." % file_path)
		return ""
	
	file.store_string(json_text)
	file.flush()
	file.close()
	
	return file_path


static func load_replay(file_path:String) -> ReplayData:
	var used_path:String = file_path.strip_edges()
	
	if used_path == "":
		push_error("ReplayStorage: Cannot load an empty file path.")
		return null
	
	if FileAccess.file_exists(used_path) == false:
		push_error("ReplayStorage: Replay file does not exist: %s" % used_path)
		return null
	
	if used_path.get_extension().to_lower() != ReplayFormat.FILE_EXTENSION:
		push_error("ReplayStorage: File does not use the .%s extension." % ReplayFormat.FILE_EXTENSION)
		return null
	
	var file:FileAccess = FileAccess.open(used_path, FileAccess.READ)
	
	if file == null:
		push_error("ReplayStorage: Could not open replay file: %s" % used_path)
		return null
	
	var file_length:int = file.get_length()
	
	if file_length <= 0:
		file.close()
		push_error("ReplayStorage: Replay file is empty.")
		return null
	
	if file_length > ReplaySerializer.MAXIMUM_REPLAY_SIZE_BYTES:
		file.close()
		push_error("ReplayStorage: Replay file exceeds the maximum allowed size.")
		return null
	
	var json_text:String = file.get_as_text()
	file.close()
	
	return ReplaySerializer.deserialize(json_text)


static func ensure_replay_directory() -> bool:
	var user_directory:DirAccess = DirAccess.open("user://")
	
	if user_directory == null:
		return false
	
	if user_directory.dir_exists("replays"):
		return true
	
	var result:Error = user_directory.make_dir_recursive("replays")
	return result == OK


static func create_replay_file_name(replay:ReplayData) -> String:
	var safe_match_id:String = sanitize_file_component(replay.match_id)
	
	if safe_match_id == "":
		safe_match_id = "replay"
	
	return safe_match_id + ReplayFormat.get_file_suffix()


static func sanitize_file_component(value:String) -> String:
	var result:String = ""
	var used_value:String = value.strip_edges()
	
	for character in used_value:
		if character >= "a" and character <= "z":
			result += character
			continue
		
		if character >= "A" and character <= "Z":
			result += character
			continue
		
		if character >= "0" and character <= "9":
			result += character
			continue
		
		if character == "-":
			result += character
			continue
		
		if character == "_":
			result += character
			continue
		
		result += "_"
	
	return result
