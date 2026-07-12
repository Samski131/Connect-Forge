extends Node

signal config_changed

const YELLOW_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/yellow.tres")
const RED_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/red.tres")
const GREEN_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/green.tres")
const PINK_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/pink.tres")
const VIOLET_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/violet.tres")
const BLUE_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/blue.tres")

var config:MatchConfig = null


func _ready() -> void:
	create_default_config()


func create_default_config() -> void:
	config = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	config.add_player("Sam", YELLOW_PALETTE)
	config.add_player("Jordan", RED_PALETTE)
	config.add_player("Ross", GREEN_PALETTE)
	config.add_player("Jack", PINK_PALETTE)
	config_changed.emit()


func get_player(player_id:int) -> MatchPlayerData:
	if config == null:
		return null
	
	return config.get_player(player_id)


func reset_match() -> void:
	create_default_config()
