extends Node

signal config_changed
signal session_changed

const YELLOW_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/yellow_v3.tres")
const RED_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/red_v3.tres")
const GREEN_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/green_v3.tres")
const PINK_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/pink_v3.tres")
const VIOLET_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/violet_v3.tres")
const BLUE_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/blue_v3.tres")

var config:MatchConfig = null
var session:MatchSession = null


func _ready() -> void:
	create_default_config()


func create_default_config() -> void:
	clear_session()
	
	config = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	config.turn_timer_seconds = 0
	config.starting_player_id = 0
	config.add_player("Player 1", YELLOW_PALETTE)
	config.add_player("Player 2", RED_PALETTE)
	
	config_changed.emit()


func set_config(new_config:MatchConfig) -> bool:
	if new_config == null:
		return false
	
	clear_session()
	config = new_config
	config_changed.emit()
	return true


func create_session_from_config() -> MatchSession:
	if config == null:
		push_error("MatchData: Cannot create a match session without a MatchConfig.")
		return null
	
	var new_session:MatchSession = MatchSession.new()
	
	if new_session.setup(config) == false:
		push_error("MatchData: MatchSession could not be created from the current configuration.")
		return null
	
	session = new_session
	session_changed.emit()
	return session


func clear_session() -> void:
	if session == null:
		return
	
	session = null
	session_changed.emit()


func has_active_session() -> bool:
	return session != null


func get_player(player_id:int) -> MatchPlayerData:
	if config == null:
		return null
	
	return config.get_player(player_id)


func get_session_player(player_id:int) -> MatchSessionPlayerData:
	if session == null:
		return null
	
	return session.get_player(player_id)


func get_default_player_palettes() -> Array[ColorPalette]:
	var palettes:Array[ColorPalette] = [
		YELLOW_PALETTE,
		RED_PALETTE,
		VIOLET_PALETTE,
		PINK_PALETTE,
		GREEN_PALETTE,
		BLUE_PALETTE
	]
	
	return palettes


func get_default_palette_for_player(player_id:int) -> ColorPalette:
	var palettes:Array[ColorPalette] = get_default_player_palettes()
	
	if palettes.is_empty():
		return null
	
	var palette_index:int = player_id % palettes.size()
	return palettes[palette_index]


func set_player_count(new_player_count:int) -> bool:
	if config == null:
		return false
	
	var target_count:int = clamp(new_player_count, MatchConfig.MINIMUM_PLAYERS, MatchConfig.MAXIMUM_PLAYERS)
	
	while config.get_player_count() < target_count:
		var new_player_id:int = config.get_player_count()
		var player_name:String = "Player " + str(new_player_id + 1)
		var palette:ColorPalette = get_default_palette_for_player(new_player_id)
		
		if config.add_player(player_name, palette) == false:
			break
	
	while config.get_player_count() > target_count:
		if config.remove_last_player() == false:
			break
	
	return config.get_player_count() == target_count


func get_resolved_starting_player_id() -> int:
	if config == null:
		return -1
	
	var player_count:int = config.get_player_count()
	
	if player_count <= 0:
		return -1
	
	if config.starting_player_id >= 0 and config.starting_player_id < player_count:
		return config.starting_player_id
	
	return randi_range(0, player_count - 1)
