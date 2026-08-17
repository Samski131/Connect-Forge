class_name BotProfile
extends Resource

@export_group("Identity")
@export var profile_id:String = ""
@export var display_name:String = ""
@export_multiline var description:String = ""

@export_group("Loadout")
@export var token_preferences:Array[BotTokenPreference] = []


func get_normalized_profile_id() -> String:
	return profile_id.strip_edges().to_lower()


func get_standard_loadout_cost() -> int:
	var total_cost:int = 0
	
	for preference in token_preferences:
		if preference == null:
			continue
		
		total_cost += preference.get_token_cost() * preference.standard_count
	
	return total_cost


func get_token_preference(token_type:int) -> BotTokenPreference:
	for preference in token_preferences:
		if preference == null:
			continue
		
		if preference.token_type == token_type:
			return preference
	
	return null


func get_standard_token_count(token_type:int) -> int:
	var preference:BotTokenPreference = get_token_preference(token_type)
	
	if preference == null:
		return 0
	
	return preference.standard_count


func get_preference_for_fallback_priority(priority:int) -> BotTokenPreference:
	if priority <= 0:
		return null
	
	for preference in token_preferences:
		if preference == null:
			continue
		
		if preference.fallback_priority == priority:
			return preference
	
	return null


func get_highest_fallback_priority() -> int:
	var highest_priority:int = 0
	
	for preference in token_preferences:
		if preference == null:
			continue
		
		if preference.fallback_priority > highest_priority:
			highest_priority = preference.fallback_priority
	
	return highest_priority


func is_valid() -> bool:
	if get_normalized_profile_id() == "":
		push_error("BotProfile: Profile ID cannot be empty.")
		return false
	
	if display_name.strip_edges() == "":
		push_error("BotProfile %s: Display name cannot be empty." % profile_id)
		return false
	
	if token_preferences.is_empty():
		push_error("BotProfile %s: Token preferences cannot be empty." % profile_id)
		return false
	
	var found_token_types:Dictionary = {}
	var found_fallback_priorities:Dictionary = {}
	var has_standard_tokens:bool = false
	var has_extra_purchase_preferences:bool = false
	var has_fallback_preferences:bool = false
	
	for preference in token_preferences:
		if preference == null:
			push_error("BotProfile %s: Token preferences cannot contain empty entries." % profile_id)
			return false
		
		if preference.is_valid() == false:
			push_error("BotProfile %s: Invalid token preference for %s." % [profile_id, preference.get_token_name()])
			return false
		
		if found_token_types.has(preference.token_type):
			push_error("BotProfile %s: Token %s appears more than once." % [profile_id, preference.get_token_name()])
			return false
		
		found_token_types[preference.token_type] = true
		
		if preference.standard_count > 0:
			has_standard_tokens = true
		
		if preference.extra_purchase_weight > 0:
			has_extra_purchase_preferences = true
		
		if preference.fallback_priority > 0:
			has_fallback_preferences = true
			
			if found_fallback_priorities.has(preference.fallback_priority):
				push_error("BotProfile %s: More than one token uses fallback priority %d." % [profile_id, preference.fallback_priority])
				return false
			
			found_fallback_priorities[preference.fallback_priority] = true
	
	if has_standard_tokens == false:
		push_error("BotProfile %s: At least one token must have a Standard Count greater than zero." % profile_id)
		return false
	
	if has_extra_purchase_preferences == false:
		push_error("BotProfile %s: At least one token must have an Extra Purchase Weight greater than zero." % profile_id)
		return false
	
	if has_fallback_preferences == false:
		push_error("BotProfile %s: At least one token must have a Fallback Priority greater than zero." % profile_id)
		return false
	
	return true
