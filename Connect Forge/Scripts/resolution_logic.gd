extends Node
#This script handles the logic for the resolution state.
#This state is skipped just now but will handle win checking.

var game_manager:Node

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")

func enter_state():
	get_parent().current_turn_phase = Global.TURN_PHASE.RESOLUTION
	
func exit_state():
	game_manager.end_turn()
	
func process_state():
	exit_state()
