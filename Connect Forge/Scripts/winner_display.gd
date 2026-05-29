extends VBoxContainer

@onready var winner_result = $"Winner Result"

var game_manager:Node

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")
	
func update_winner(winner_id:int):
	if(game_manager.player_names[winner_id]==""):
		winner_result.text = "Player " + str(winner_id+1)
	else:
		winner_result.text = game_manager.player_names[winner_id]
	winner_result.label_settings.font_color = game_manager.player_colours[winner_id]

func clear_winner():
	winner_result.text = ""
	winner_result.label_settings.font_color = Color.WHITE
