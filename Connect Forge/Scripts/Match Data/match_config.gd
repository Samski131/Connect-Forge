class_name MatchConfig
extends Resource

signal players_changed
signal board_settings_changed
signal token_settings_changed
signal match_rules_changed

const MINIMUM_PLAYERS:int = 2
const MAXIMUM_PLAYERS:int = 5
const MINIMUM_BOARD_COLUMNS:int = 4
const MAXIMUM_BOARD_COLUMNS:int = 14
const MINIMUM_BOARD_ROWS:int = 4
const MAXIMUM_BOARD_ROWS:int = 12
const MINIMUM_TOKENS_TO_WIN:int = 3
const MINIMUM_STARTING_TOKEN_POINTS:int = 0
const MAXIMUM_STARTING_TOKEN_POINTS:int = 99
const RANDOM_STARTING_PLAYER_ID:int = -1

@export_group("Players")
@export var players:Array[MatchPlayerData] = []

@export_group("Token Selection")
@export var starting_token_points:int = 10

@export_group("Board")
@export var board_columns:int = 7
@export var board_rows:int = 6
@export var tokens_to_win:int = 4

@export_group("Match Rules")
@export var turn_timer_seconds:int = 0
@export var starting_player_id:int = 0


func get_player_count() -> int:
	return players.size()


func get_player(player_id:int) -> MatchPlayerData:
	if player_id < 0:
		return null
	
	if player_id >= players.size():
		return null
	
	return players[player_id]


func get_player_name(player_id:int) -> String:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return "Player " + str(player_id + 1)
	
	var used_name:String = player.player_name.strip_edges()
	
	if used_name == "":
		return "Player " + str(player_id + 1)
	
	return used_name


func get_player_palette(player_id:int) -> ColorPalette:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return null
	
	return player.colour_palette


func get_player_controller_type(player_id:int) -> MatchPlayerData.CONTROLLER_TYPE:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return MatchPlayerData.CONTROLLER_TYPE.LOCAL_HUMAN
	
	return player.controller_type


func is_player_bot(player_id:int) -> bool:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	return player.is_bot()


func add_player(player_name:String, palette:ColorPalette, controller_type:MatchPlayerData.CONTROLLER_TYPE = MatchPlayerData.CONTROLLER_TYPE.LOCAL_HUMAN) -> bool:
	if players.size() >= MAXIMUM_PLAYERS:
		return false
	
	if palette == null:
		return false
	
	var player:MatchPlayerData = MatchPlayerData.new()
	player.setup(player_name, palette, starting_token_points, controller_type)
	players.append(player)
	players_changed.emit()
	return true


func add_bot(bot_profile_id:String, palette:ColorPalette, difficulty:MatchPlayerData.BOT_DIFFICULTY = MatchPlayerData.BOT_DIFFICULTY.NORMAL) -> bool:
	if players.size() >= MAXIMUM_PLAYERS:
		return false
	
	if palette == null:
		return false
	
	var profile:BotProfile = BotProfileLibrary.get_profile(bot_profile_id)
	
	if profile == null:
		push_error("MatchConfig: Could not add bot because profile '%s' does not exist." % bot_profile_id)
		return false
	
	var player:MatchPlayerData = MatchPlayerData.new()
	player.setup(profile.display_name, palette, starting_token_points, MatchPlayerData.CONTROLLER_TYPE.BOT)
	
	if player.configure_as_bot(profile.profile_id, difficulty) == false:
		return false
	
	if BotProfileLibrary.apply_profile_loadout(player, profile, starting_token_points) == false:
		return false
	
	players.append(player)
	players_changed.emit()
	token_settings_changed.emit()
	return true


func remove_last_player() -> bool:
	if players.size() <= MINIMUM_PLAYERS:
		return false
	
	players.pop_back()
	players_changed.emit()
	
	if clamp_starting_player_id():
		match_rules_changed.emit()
	
	return true


func set_player_name(player_id:int, new_name:String) -> bool:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	player.player_name = new_name
	players_changed.emit()
	return true


func set_player_palette(player_id:int, palette:ColorPalette) -> bool:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	if palette == null:
		return false
	
	if player.colour_palette == palette:
		return true
	
	player.colour_palette = palette
	players_changed.emit()
	return true


func set_player_as_local_human(player_id:int) -> bool:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	player.configure_as_local_human()
	player.reset_token_selection(starting_token_points)
	players_changed.emit()
	token_settings_changed.emit()
	return true


func set_player_as_network_human(player_id:int) -> bool:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	player.configure_as_network_human()
	player.reset_token_selection(starting_token_points)
	players_changed.emit()
	token_settings_changed.emit()
	return true


func set_player_as_bot(player_id:int, bot_profile_id:String, difficulty:MatchPlayerData.BOT_DIFFICULTY = MatchPlayerData.BOT_DIFFICULTY.NORMAL) -> bool:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	var profile:BotProfile = BotProfileLibrary.get_profile(bot_profile_id)
	
	if profile == null:
		push_error("MatchConfig: Could not configure player %d as bot because profile '%s' does not exist." % [player_id, bot_profile_id])
		return false
	
	if player.configure_as_bot(profile.profile_id, difficulty) == false:
		return false
	
	player.player_name = profile.display_name
	
	if BotProfileLibrary.apply_profile_loadout(player, profile, starting_token_points) == false:
		return false
	
	players_changed.emit()
	token_settings_changed.emit()
	return true


func set_bot_difficulty(player_id:int, difficulty:MatchPlayerData.BOT_DIFFICULTY) -> bool:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	if player.is_bot() == false:
		return false
	
	if player.bot_difficulty == difficulty:
		return true
	
	player.bot_difficulty = difficulty
	players_changed.emit()
	return true


func set_bot_profile_id(player_id:int, new_profile_id:String) -> bool:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	if player.is_bot() == false:
		return false
	
	var profile:BotProfile = BotProfileLibrary.get_profile(new_profile_id)
	
	if profile == null:
		push_error("MatchConfig: Could not change bot profile because profile '%s' does not exist." % new_profile_id)
		return false
	
	if player.bot_profile_id == profile.profile_id:
		return true
	
	player.bot_profile_id = profile.profile_id
	player.player_name = profile.display_name
	
	if BotProfileLibrary.apply_profile_loadout(player, profile, starting_token_points) == false:
		return false
	
	players_changed.emit()
	token_settings_changed.emit()
	return true


func rebuild_bot_loadout(player_id:int) -> bool:
	var player:MatchPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	if player.is_bot() == false:
		return false
	
	var profile:BotProfile = BotProfileLibrary.get_profile(player.bot_profile_id)
	
	if profile == null:
		return false
	
	if BotProfileLibrary.apply_profile_loadout(player, profile, starting_token_points) == false:
		return false
	
	token_settings_changed.emit()
	return true


func rebuild_all_bot_loadouts() -> void:
	for player in players:
		if player == null:
			continue
		
		if player.is_bot() == false:
			continue
		
		var profile:BotProfile = BotProfileLibrary.get_profile(player.bot_profile_id)
		
		if profile == null:
			player.reset_token_selection(starting_token_points)
			continue
		
		BotProfileLibrary.apply_profile_loadout(player, profile, starting_token_points)
	
	token_settings_changed.emit()


func set_starting_token_points(new_amount:int) -> void:
	var used_amount:int = clamp(new_amount, MINIMUM_STARTING_TOKEN_POINTS, MAXIMUM_STARTING_TOKEN_POINTS)
	
	if starting_token_points == used_amount:
		return
	
	starting_token_points = used_amount
	
	for player in players:
		if player == null:
			continue
		
		if player.is_bot():
			var profile:BotProfile = BotProfileLibrary.get_profile(player.bot_profile_id)
			
			if profile != null:
				BotProfileLibrary.apply_profile_loadout(player, profile, starting_token_points)
				continue
		
		player.reset_token_selection(starting_token_points)
	
	token_settings_changed.emit()


func set_board_size(new_columns:int, new_rows:int) -> void:
	var used_columns:int = clamp(new_columns, MINIMUM_BOARD_COLUMNS, MAXIMUM_BOARD_COLUMNS)
	var used_rows:int = clamp(new_rows, MINIMUM_BOARD_ROWS, MAXIMUM_BOARD_ROWS)
	
	if board_columns == used_columns and board_rows == used_rows:
		return
	
	board_columns = used_columns
	board_rows = used_rows
	
	clamp_tokens_to_win()
	board_settings_changed.emit()


func set_tokens_to_win(new_amount:int) -> void:
	var maximum_line_length:int = max(board_columns, board_rows)
	var used_amount:int = clamp(new_amount, MINIMUM_TOKENS_TO_WIN, maximum_line_length)
	
	if tokens_to_win == used_amount:
		return
	
	tokens_to_win = used_amount
	board_settings_changed.emit()


func clamp_tokens_to_win() -> void:
	var maximum_line_length:int = max(board_columns, board_rows)
	tokens_to_win = clamp(tokens_to_win, MINIMUM_TOKENS_TO_WIN, maximum_line_length)


func set_turn_timer_seconds(new_seconds:int) -> void:
	var used_seconds:int = max(new_seconds, 0)
	
	if turn_timer_seconds == used_seconds:
		return
	
	turn_timer_seconds = used_seconds
	match_rules_changed.emit()


func set_starting_player_id(new_player_id:int) -> void:
	var used_player_id:int = RANDOM_STARTING_PLAYER_ID
	
	if new_player_id >= 0 and new_player_id < get_player_count():
		used_player_id = new_player_id
	
	if starting_player_id == used_player_id:
		return
	
	starting_player_id = used_player_id
	match_rules_changed.emit()


func clamp_starting_player_id() -> bool:
	if starting_player_id == RANDOM_STARTING_PLAYER_ID:
		return false
	
	if starting_player_id >= 0:
		if starting_player_id < get_player_count():
			return false
	
	if get_player_count() > 0:
		starting_player_id = 0
	else:
		starting_player_id = RANDOM_STARTING_PLAYER_ID
	
	return true
