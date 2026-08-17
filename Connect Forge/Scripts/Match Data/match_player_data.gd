class_name MatchPlayerData
extends Resource

enum CONTROLLER_TYPE {
	LOCAL_HUMAN,
	NETWORK_HUMAN,
	BOT
}

enum BOT_DIFFICULTY {
	EASY,
	NORMAL,
	HARD,
	EXPERT
}

@export var player_name:String = ""
@export var colour_palette:ColorPalette
@export var token_points_remaining:int = 0
@export var selected_tokens:Dictionary = {}

@export_group("Controller")
@export var controller_type:CONTROLLER_TYPE = CONTROLLER_TYPE.LOCAL_HUMAN

@export_group("Bot")
@export var bot_profile_id:String = ""
@export var bot_difficulty:BOT_DIFFICULTY = BOT_DIFFICULTY.NORMAL


func setup(new_name:String, new_palette:ColorPalette, starting_token_points:int, new_controller_type:CONTROLLER_TYPE = CONTROLLER_TYPE.LOCAL_HUMAN) -> void:
	player_name = new_name
	colour_palette = new_palette
	token_points_remaining = starting_token_points
	selected_tokens.clear()
	controller_type = new_controller_type
	bot_profile_id = ""
	bot_difficulty = BOT_DIFFICULTY.NORMAL


func configure_as_local_human() -> void:
	controller_type = CONTROLLER_TYPE.LOCAL_HUMAN
	bot_profile_id = ""
	bot_difficulty = BOT_DIFFICULTY.NORMAL


func configure_as_network_human() -> void:
	controller_type = CONTROLLER_TYPE.NETWORK_HUMAN
	bot_profile_id = ""
	bot_difficulty = BOT_DIFFICULTY.NORMAL


func configure_as_bot(new_profile_id:String, new_difficulty:BOT_DIFFICULTY = BOT_DIFFICULTY.NORMAL) -> bool:
	var used_profile_id:String = new_profile_id.strip_edges()
	
	if used_profile_id == "":
		return false
	
	controller_type = CONTROLLER_TYPE.BOT
	bot_profile_id = used_profile_id
	bot_difficulty = new_difficulty
	return true


func is_bot() -> bool:
	return controller_type == CONTROLLER_TYPE.BOT


func is_local_human() -> bool:
	return controller_type == CONTROLLER_TYPE.LOCAL_HUMAN


func is_network_human() -> bool:
	return controller_type == CONTROLLER_TYPE.NETWORK_HUMAN


func is_human() -> bool:
	return is_bot() == false


func get_controller_type_name() -> String:
	match controller_type:
		CONTROLLER_TYPE.LOCAL_HUMAN:
			return "Local Human"
		CONTROLLER_TYPE.NETWORK_HUMAN:
			return "Network Human"
		CONTROLLER_TYPE.BOT:
			return "Bot"
	
	return "Unknown"


func get_bot_difficulty_name() -> String:
	match bot_difficulty:
		BOT_DIFFICULTY.EASY:
			return "Easy"
		BOT_DIFFICULTY.NORMAL:
			return "Normal"
		BOT_DIFFICULTY.HARD:
			return "Hard"
		BOT_DIFFICULTY.EXPERT:
			return "Expert"
	
	return "Normal"


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
