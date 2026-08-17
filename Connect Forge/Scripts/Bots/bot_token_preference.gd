class_name BotTokenPreference
extends Resource

@export_group("Token")
@export var token_type:TokenLibrary.TokenType = TokenLibrary.TokenType.ANVIL

@export_group("Loadout")
@export_range(0, 99, 1) var standard_count:int = 0
@export_range(0, 10, 1) var extra_purchase_weight:int = 0
@export_range(0, 99, 1) var fallback_priority:int = 0


func is_valid() -> bool:
	if TokenLibrary.get_token_data(token_type).is_empty():
		return false
	
	if TokenLibrary.is_available_in_lobby(token_type) == false:
		return false
	
	if standard_count <= 0 and extra_purchase_weight <= 0 and fallback_priority <= 0:
		return false
	
	return true


func get_token_name() -> String:
	return TokenLibrary.get_display_name(token_type)


func get_token_cost() -> int:
	return TokenLibrary.get_cost(token_type)
