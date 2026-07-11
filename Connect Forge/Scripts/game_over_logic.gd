extends Node

var game_manager:Node = null
var board:BoardManager = null
var game_over_menu:GameOverMenu = null
var winner_id:int = -1


func setup(
	new_game_manager:Node,
	new_board:BoardManager
) -> void:
	game_manager = new_game_manager
	board = new_board
	
	game_over_menu = get_tree().get_first_node_in_group(
		"game over menu"
	) as GameOverMenu


func enter_state(new_winner_id:int) -> void:
	winner_id = new_winner_id
	
	if game_manager == null:
		return
	
	game_manager.current_turn_phase = Global.TURN_PHASE.GAME_OVER
	game_manager.stop_game_timer()
	
	if game_over_menu == null:
		game_over_menu = get_tree().get_first_node_in_group(
			"game over menu"
		) as GameOverMenu
	
	if game_over_menu != null:
		game_over_menu.show_game_over(winner_id)


func exit_state() -> void:
	if game_over_menu != null:
		game_over_menu.hide_game_over()


func process_state() -> void:
	pass
