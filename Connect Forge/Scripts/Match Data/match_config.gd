class_name MatchConfig
extends Resource

signal players_changed
signal board_settings_changed
signal token_settings_changed

const MINIMUM_PLAYERS:int = 2
const MAXIMUM_PLAYERS:int = 6
const MINIMUM_BOARD_COLUMNS:int = 4
const MAXIMUM_BOARD_COLUMNS:int = 12
const MINIMUM_BOARD_ROWS:int = 4
const MAXIMUM_BOARD_ROWS:int = 12
const MINIMUM_TOKENS_TO_WIN:int = 3

@export_group("Players")
@export var players:Array[MatchPlayerData] = []

@export_group("Token Selection")
@export var starting_token_points:int = 10

@export_group("Board")
@export var board_columns:int = 7
@export var board_rows:int = 6
@export var tokens_to_win:int = 4


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


func add_player(player_name:String, palette:ColorPalette) -> bool:
	if players.size() >= MAXIMUM_PLAYERS:
		return false
	
	var player:MatchPlayerData = MatchPlayerData.new()
	player.setup(player_name, palette, starting_token_points)
	players.append(player)
	players_changed.emit()
	return true


func remove_last_player() -> bool:
	if players.size() <= MINIMUM_PLAYERS:
		return false
	
	players.pop_back()
	players_changed.emit()
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
	
	player.colour_palette = palette
	players_changed.emit()
	return true


func set_starting_token_points(new_amount:int) -> void:
	starting_token_points = max(new_amount, 0)
	
	for player in players:
		if player == null:
			continue
		
		player.reset_token_selection(starting_token_points)
	
	token_settings_changed.emit()


func set_board_size(new_columns:int, new_rows:int) -> void:
	board_columns = clamp(new_columns, MINIMUM_BOARD_COLUMNS, MAXIMUM_BOARD_COLUMNS)
	board_rows = clamp(new_rows, MINIMUM_BOARD_ROWS, MAXIMUM_BOARD_ROWS)
	clamp_tokens_to_win()
	board_settings_changed.emit()


func set_tokens_to_win(new_amount:int) -> void:
	var maximum_line_length:int = max(board_columns, board_rows)
	tokens_to_win = clamp(new_amount, MINIMUM_TOKENS_TO_WIN, maximum_line_length)
	board_settings_changed.emit()


func clamp_tokens_to_win() -> void:
	var maximum_line_length:int = max(board_columns, board_rows)
	tokens_to_win = clamp(tokens_to_win, MINIMUM_TOKENS_TO_WIN, maximum_line_length)


func reset_token_selections() -> void:
	for player in players:
		if player == null:
			continue
		
		player.reset_token_selection(starting_token_points)
	
	token_settings_changed.emit()
