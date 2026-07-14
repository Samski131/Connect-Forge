class_name ScoreLabelUI
extends Label

@export var label_prefix:String = ""
@export var player_separator:String = "  |  "

var game_manager:GameManager = null


func _ready() -> void:
	refresh()


func setup(new_game_manager:GameManager) -> void:
	disconnect_game_manager_signals()
	game_manager = new_game_manager
	connect_game_manager_signals()
	refresh()


func connect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.score_changed.is_connected(_on_score_changed) == false:
		game_manager.score_changed.connect(_on_score_changed)
	
	if game_manager.player_names_changed.is_connected(_on_player_names_changed) == false:
		game_manager.player_names_changed.connect(_on_player_names_changed)
	
	if game_manager.players_changed.is_connected(_on_players_changed) == false:
		game_manager.players_changed.connect(_on_players_changed)


func disconnect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.score_changed.is_connected(_on_score_changed):
		game_manager.score_changed.disconnect(_on_score_changed)
	
	if game_manager.player_names_changed.is_connected(_on_player_names_changed):
		game_manager.player_names_changed.disconnect(_on_player_names_changed)
	
	if game_manager.players_changed.is_connected(_on_players_changed):
		game_manager.players_changed.disconnect(_on_players_changed)


func refresh() -> void:
	if game_manager == null:
		text = label_prefix
		return
	
	var score_parts:Array[String] = []
	var player_count:int = game_manager.get_player_count()
	
	for player_id in range(player_count):
		var player_name:String = get_display_player_name(player_id)
		var wins:int = game_manager.get_player_wins(player_id)
		var score_text:String = player_name + ": " + str(wins)
		score_parts.append(score_text)
	
	text = label_prefix + join_strings(score_parts, player_separator)


func join_strings(parts:Array[String], separator:String) -> String:
	var result:String = ""
	
	for i in range(parts.size()):
		if i > 0:
			result += separator
		
		result += parts[i]
	
	return result


func get_display_player_name(player_id:int) -> String:
	if game_manager == null:
		return "Player " + str(player_id + 1)
	
	if game_manager.is_valid_player_id(player_id) == false:
		return "Player " + str(player_id + 1)
	
	var player_name:String = game_manager.get_player_name(player_id).strip_edges()
	
	if player_name == "":
		return "Player " + str(player_id + 1)
	
	return player_name


func _on_score_changed() -> void:
	UIJuice.play(self, UIJuice.create_pulse_preset())
	refresh()


func _on_player_names_changed() -> void:
	refresh()


func _on_players_changed() -> void:
	refresh()
