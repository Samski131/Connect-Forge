class_name BotProfileLibrary
extends RefCounted

const PROFILE_DIRECTORY:String = "res://Scripts/Bots/profiles"

static var profiles_by_id:Dictionary = {}
static var profiles_loaded:bool = false


static func get_profile(profile_id:String) -> BotProfile:
	_ensure_profiles_loaded()
	
	var used_profile_id:String = profile_id.strip_edges().to_lower()
	
	if profiles_by_id.has(used_profile_id) == false:
		return null
	
	return profiles_by_id[used_profile_id]


static func has_profile(profile_id:String) -> bool:
	return get_profile(profile_id) != null


static func get_all_profiles() -> Array[BotProfile]:
	_ensure_profiles_loaded()
	
	var result:Array[BotProfile] = []
	var profile_ids:Array = profiles_by_id.keys()
	profile_ids.sort()
	
	for profile_id_value in profile_ids:
		var profile:BotProfile = profiles_by_id[profile_id_value]
		
		if profile != null:
			result.append(profile)
	
	return result


static func get_profile_count() -> int:
	_ensure_profiles_loaded()
	return profiles_by_id.size()


static func reload_profiles() -> void:
	profiles_by_id.clear()
	profiles_loaded = false
	_load_profiles()


static func apply_profile_loadout(player:MatchPlayerData, profile:BotProfile, starting_token_points:int) -> bool:
	if player == null:
		return false
	
	if profile == null:
		return false
	
	if profile.is_valid() == false:
		return false
	
	var used_starting_points:int = max(starting_token_points, 0)
	player.reset_token_selection(used_starting_points)
	
	var standard_loadout_cost:int = profile.get_standard_loadout_cost()
	
	if standard_loadout_cost <= used_starting_points:
		if _purchase_standard_loadout(player, profile) == false:
			return false
		
		_spend_extra_points(player, profile)
	else:
		_spend_fallback_points(player, profile)
	
	return true


static func apply_profile_loadout_by_id(player:MatchPlayerData, profile_id:String, starting_token_points:int) -> bool:
	var profile:BotProfile = get_profile(profile_id)
	
	if profile == null:
		push_error("BotProfileLibrary: Could not find profile '%s'." % profile_id)
		return false
	
	return apply_profile_loadout(player, profile, starting_token_points)


static func _ensure_profiles_loaded() -> void:
	if profiles_loaded:
		return
	
	_load_profiles()


static func _load_profiles() -> void:
	profiles_by_id.clear()
	
	var directory:DirAccess = DirAccess.open(PROFILE_DIRECTORY)
	
	if directory == null:
		push_error("BotProfileLibrary: Could not open profile directory %s." % PROFILE_DIRECTORY)
		profiles_loaded = true
		return
	
	var file_names:PackedStringArray = directory.get_files()
	file_names.sort()
	
	for file_name in file_names:
		var extension:String = file_name.get_extension().to_lower()
		
		if extension != "tres" and extension != "res":
			continue
		
		var profile_path:String = PROFILE_DIRECTORY.path_join(file_name)
		var loaded_resource:Resource = ResourceLoader.load(profile_path)
		var profile:BotProfile = loaded_resource as BotProfile
		
		if profile == null:
			push_warning("BotProfileLibrary: %s is not a BotProfile." % profile_path)
			continue
		
		if profile.is_valid() == false:
			push_warning("BotProfileLibrary: Ignoring invalid profile %s." % profile_path)
			continue
		
		var profile_id:String = profile.get_normalized_profile_id()
		
		if profiles_by_id.has(profile_id):
			push_error("BotProfileLibrary: Duplicate bot profile ID '%s'." % profile_id)
			continue
		
		profiles_by_id[profile_id] = profile
	
	profiles_loaded = true


static func _purchase_standard_loadout(player:MatchPlayerData, profile:BotProfile) -> bool:
	for preference in profile.token_preferences:
		if preference == null:
			continue
		
		for purchase_index in range(preference.standard_count):
			if player.try_purchase_token(preference.token_type) == false:
				push_error("BotProfileLibrary: Could not purchase standard %s token for %s." % [preference.get_token_name(), profile.display_name])
				return false
	
	return true


static func _spend_extra_points(player:MatchPlayerData, profile:BotProfile) -> void:
	while true:
		var purchased_during_cycle:bool = false
		
		for preference in profile.token_preferences:
			if preference == null:
				continue
			
			if preference.extra_purchase_weight <= 0:
				continue
			
			for purchase_attempt in range(preference.extra_purchase_weight):
				if player.try_purchase_token(preference.token_type):
					purchased_during_cycle = true
		
		if purchased_during_cycle == false:
			break


static func _spend_fallback_points(player:MatchPlayerData, profile:BotProfile) -> void:
	var highest_priority:int = profile.get_highest_fallback_priority()
	
	while true:
		var purchased_during_cycle:bool = false
		
		for priority in range(1, highest_priority + 1):
			var preference:BotTokenPreference = profile.get_preference_for_fallback_priority(priority)
			
			if preference == null:
				continue
			
			if player.try_purchase_token(preference.token_type):
				purchased_during_cycle = true
		
		if purchased_during_cycle == false:
			break
