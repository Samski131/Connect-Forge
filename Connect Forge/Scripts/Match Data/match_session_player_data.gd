class_name MatchSessionPlayerData
extends RefCounted

signal score_changed(player_id:int, wins:int, losses:int)
signal token_type_added(player_id:int, token_type:int)
signal token_count_changed(player_id:int, token_type:int, new_count:int)
signal tokens_reset(player_id:int)

var player_id:int = -1
var player_name:String = ""
var colour_palette:ColorPalette = null

var controller_type:MatchPlayerData.CONTROLLER_TYPE = MatchPlayerData.CONTROLLER_TYPE.LOCAL_HUMAN
var bot_profile_id:String = ""
var bot_difficulty:MatchPlayerData.BOT_DIFFICULTY = MatchPlayerData.BOT_DIFFICULTY.NORMAL

var wins:int = 0
var losses:int = 0

var starting_token_counts:Dictionary = {}
var token_counts:Dictionary = {}


func setup(new_player_id:int, source_player:MatchPlayerData) -> void:
	player_id = new_player_id
	player_name = "Player " + str(player_id + 1)
	colour_palette = null
	controller_type = MatchPlayerData.CONTROLLER_TYPE.LOCAL_HUMAN
	bot_profile_id = ""
	bot_difficulty = MatchPlayerData.BOT_DIFFICULTY.NORMAL
	wins = 0
	losses = 0
	starting_token_counts.clear()
	token_counts.clear()
	
	if source_player != null:
		player_name = get_valid_player_name(source_player.player_name)
		colour_palette = source_player.colour_palette
		controller_type = source_player.controller_type
		bot_profile_id = source_player.bot_profile_id
		bot_difficulty = source_player.bot_difficulty
		set_starting_token_counts(source_player.selected_tokens)
	
	reset_tokens_for_round()


func is_bot() -> bool:
	return controller_type == MatchPlayerData.CONTROLLER_TYPE.BOT


func is_local_human() -> bool:
	return controller_type == MatchPlayerData.CONTROLLER_TYPE.LOCAL_HUMAN


func is_network_human() -> bool:
	return controller_type == MatchPlayerData.CONTROLLER_TYPE.NETWORK_HUMAN


func is_human() -> bool:
	return is_bot() == false


func get_controller_type_name() -> String:
	match controller_type:
		MatchPlayerData.CONTROLLER_TYPE.LOCAL_HUMAN:
			return "Local Human"
		MatchPlayerData.CONTROLLER_TYPE.NETWORK_HUMAN:
			return "Network Human"
		MatchPlayerData.CONTROLLER_TYPE.BOT:
			return "Bot"
	
	return "Unknown"


func get_bot_difficulty_name() -> String:
	match bot_difficulty:
		MatchPlayerData.BOT_DIFFICULTY.EASY:
			return "Easy"
		MatchPlayerData.BOT_DIFFICULTY.NORMAL:
			return "Normal"
		MatchPlayerData.BOT_DIFFICULTY.HARD:
			return "Hard"
		MatchPlayerData.BOT_DIFFICULTY.EXPERT:
			return "Expert"
	
	return "Normal"


func get_valid_player_name(new_name:String) -> String:
	var used_name:String = new_name.strip_edges()
	
	if used_name == "":
		return "Player " + str(player_id + 1)
	
	return used_name


func set_starting_token_counts(new_counts:Dictionary) -> void:
	starting_token_counts.clear()
	
	for token_type_value in new_counts.keys():
		var token_type:int = int(token_type_value)
		var token_count:int = max(int(new_counts[token_type_value]), 0)
		
		if token_count <= 0:
			continue
		
		starting_token_counts[token_type] = token_count


func set_starting_token_count(token_type:int, amount:int) -> void:
	var used_amount:int = max(amount, 0)
	
	if used_amount <= 0:
		starting_token_counts.erase(token_type)
		return
	
	starting_token_counts[token_type] = used_amount


func get_starting_token_count(token_type:int) -> int:
	if starting_token_counts.has(token_type) == false:
		return 0
	
	return int(starting_token_counts[token_type])


func get_starting_token_counts() -> Dictionary:
	return starting_token_counts.duplicate(true)


func reset_tokens_for_round() -> void:
	token_counts = starting_token_counts.duplicate(true)
	tokens_reset.emit(player_id)


func has_token_type(token_type:int) -> bool:
	return token_counts.has(token_type)


func has_token(token_type:int) -> bool:
	return get_token_count(token_type) > 0


func get_token_count(token_type:int) -> int:
	if token_counts.has(token_type) == false:
		return 0
	
	return int(token_counts[token_type])


func get_token_counts() -> Dictionary:
	return token_counts.duplicate(true)


func replace_token_counts(new_counts:Dictionary) -> bool:
	var validated_counts:Dictionary = {}
	
	for token_type_value in new_counts.keys():
		var token_type:int = int(token_type_value)
		var token_count:int = int(new_counts[token_type_value])
		
		if TokenLibrary.get_token_data(token_type).is_empty():
			return false
		
		if token_count < 0:
			return false
		
		validated_counts[token_type] = token_count
	
	token_counts = validated_counts
	tokens_reset.emit(player_id)
	return true


func get_token_types() -> Array[int]:
	var result:Array[int] = []
	
	for token_type_value in token_counts.keys():
		result.append(int(token_type_value))
	
	return result


func get_token_types_in_tray_order() -> Array[int]:
	var result:Array[int] = []
	
	for token_type in TokenLibrary.get_token_types_in_tray_order():
		if has_token_type(token_type):
			result.append(token_type)
	
	return result


func set_token_count(token_type:int, amount:int) -> void:
	var used_amount:int = max(amount, 0)
	var is_new_token_type:bool = has_token_type(token_type) == false
	
	token_counts[token_type] = used_amount
	
	if is_new_token_type:
		token_type_added.emit(player_id, token_type)
	
	token_count_changed.emit(player_id, token_type, used_amount)


func spend_token(token_type:int, amount:int = 1) -> bool:
	if amount <= 0:
		return false
	
	var current_count:int = get_token_count(token_type)
	
	if current_count < amount:
		return false
	
	set_token_count(token_type, current_count - amount)
	return true


func refund_token(token_type:int, amount:int = 1) -> bool:
	if amount <= 0:
		return false
	
	var current_count:int = get_token_count(token_type)
	set_token_count(token_type, current_count + amount)
	return true


func add_tokens(token_type:int, amount:int = 1) -> bool:
	if amount <= 0:
		return false
	
	var current_count:int = get_token_count(token_type)
	set_token_count(token_type, current_count + amount)
	return true


func record_win() -> void:
	wins += 1
	score_changed.emit(player_id, wins, losses)


func record_loss() -> void:
	losses += 1
	score_changed.emit(player_id, wins, losses)


func reset_score() -> void:
	wins = 0
	losses = 0
	score_changed.emit(player_id, wins, losses)
