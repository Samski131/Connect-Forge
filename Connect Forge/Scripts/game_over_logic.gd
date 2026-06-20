extends Node
#This script handles the logic for the game over state.
#This state won't do very much just now aside from show the winner.

var game_manager:Node
var board:BoardManager

func setup(new_game_manager:Node, new_board:BoardManager):
	game_manager = new_game_manager
	board = new_board
	
func enter_state():
	get_parent().current_turn_phase = Global.TURN_PHASE.GAME_OVER
	
func exit_state():
	pass
	
func process_state():
	pass
