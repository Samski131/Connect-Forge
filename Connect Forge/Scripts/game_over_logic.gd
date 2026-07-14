extends Node

var game_manager:GameManager = null
var board:BoardManager = null
var game_over_menu:GameOverMenu = null
var winner_id:int = -1


func setup(new_game_manager:GameManager, new_board:BoardManager, new_game_over_menu:GameOverMenu) -> void:
	game_manager = new_game_manager
	board = new_board
	game_over_menu = new_game_over_menu


func enter_state(new_winner_id:int) -> void:
	if game_manager == null:
		return
	
	if game_manager.is_valid_player_id(new_winner_id) == false:
		return
	
	winner_id = new_winner_id
	
	game_manager.set_current_turn_phase(Global.TURN_PHASE.GAME_OVER)
	game_manager.stop_game_timer()
	game_manager.stop_turn_timer()
	
	if game_over_menu != null:
		game_over_menu.show_game_over(winner_id)


func exit_state() -> void:
	winner_id = -1
	
	if game_over_menu != null:
		game_over_menu.hide_game_over()
