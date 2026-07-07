class_name ScoreLabelUI
extends Label

@export var label_prefix:String = ""
@export var player_separator:String = "  |  "

var game_manager:Node = null


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	
	if game_manager != null:
		if game_manager.has_signal("score_changed"):
			if game_manager.score_changed.is_connected(_on_score_changed) == false:
				game_manager.score_changed.connect(_on_score_changed)
		
		if game_manager.has_signal("player_names_changed"):
			if game_manager.player_names_changed.is_connected(_on_player_names_changed) == false:
				game_manager.player_names_changed.connect(_on_player_names_changed)
	
	refresh()


func refresh() -> void:
	if game_manager == null:
		self.text = "Score: "
		return
	
	var score_parts:Array[String] = []
	
	for player_id in range(game_manager.number_of_players):
		var player_name:String = get_display_player_name(player_id)
		var wins:int = get_player_wins(player_id)
		var score_text:String = player_name + ": " + str(wins)
		
		score_parts.append(score_text)
	
	self.text = label_prefix + join_strings(score_parts, player_separator)

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
	
	if player_id < 0:
		return "Player"
	
	if player_id >= game_manager.player_names.size():
		return "Player " + str(player_id + 1)
	
	var player_name:String = str(game_manager.player_names[player_id]).strip_edges()
	
	if player_name == "":
		return "Player " + str(player_id + 1)
	
	return player_name


func get_player_wins(player_id:int) -> int:
	if game_manager == null:
		return 0
	
	if game_manager.has_method("get_player_wins"):
		return game_manager.get_player_wins(player_id)
	
	return 0


func _on_score_changed() -> void:
	UIJuice.play(self, UIJuice.create_pulse_preset())
	refresh()


func _on_player_names_changed() -> void:
	refresh()
