extends Node
#This script handles the logic for the game over state.
#This state won't do very much just now aside from show the winner.

var game_manager:Node

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")

func enter_state():
	get_parent().current_turn_phase = Global.TURN_PHASE.GAME_OVER
	
func exit_state():
	pass
	
func process_state():

	exit_state()
