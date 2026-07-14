class_name MatchPlayerData
extends Resource

@export var player_name:String = ""
@export var colour_palette:ColorPalette
@export var token_points_remaining:int = 0
@export var selected_tokens:Dictionary = {}


func setup(new_name:String, new_palette:ColorPalette, starting_token_points:int) -> void:
	player_name = new_name
	colour_palette = new_palette
	token_points_remaining = starting_token_points
	selected_tokens.clear()


func get_token_count(token_type:int) -> int:
	if selected_tokens.has(token_type) == false:
		return 0
	
	return int(selected_tokens[token_type])


func add_token(token_type:int, amount:int = 1) -> void:
	if amount <= 0:
		return
	
	var current_count:int = get_token_count(token_type)
	selected_tokens[token_type] = current_count + amount


func remove_token(token_type:int, amount:int = 1) -> bool:
	if amount <= 0:
		return false
	
	var current_count:int = get_token_count(token_type)
	
	if current_count < amount:
		return false
	
	var new_count:int = current_count - amount
	
	if new_count <= 0:
		selected_tokens.erase(token_type)
	else:
		selected_tokens[token_type] = new_count
	
	return true


func can_afford_token(token_type:int) -> bool:
	return token_points_remaining >= TokenLibrary.get_cost(token_type)


func try_purchase_token(token_type:int) -> bool:
	var cost:int = TokenLibrary.get_cost(token_type)
	
	if TokenLibrary.is_available_in_lobby(token_type) == false:
		return false
	
	if token_points_remaining < cost:
		return false
	
	token_points_remaining -= cost
	add_token(token_type)
	return true


func try_refund_token(token_type:int) -> bool:
	if remove_token(token_type) == false:
		return false
	
	token_points_remaining += TokenLibrary.get_cost(token_type)
	return true


func reset_token_selection(starting_token_points:int) -> void:
	token_points_remaining = starting_token_points
	selected_tokens.clear()
