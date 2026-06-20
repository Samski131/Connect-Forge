extends Node
#This script handles the logic for the resolution state.
#This state handles checking for wins, once all possible wins are checked it starts the next turn.

const  WIN_DIRECTIONS = [
	Vector2i(0, 1),   # horizontal right
	Vector2i(1, 0),   # vertical down
	Vector2i(1, 1),   # diagonal down-right
	Vector2i(1, -1),  # diagonal down-left
]

var game_manager:Node
var board:BoardManager

func setup(new_game_manager:Node, new_board:BoardManager):
	game_manager = new_game_manager
	board = new_board
	
func enter_state():
	get_parent().current_turn_phase = Global.TURN_PHASE.RESOLUTION
	
func exit_state():
	game_manager.end_turn()
	
func process_state():
	var winner_id = check_for_win()
	if winner_id != -1 :
		game_manager.winner_ui.update_winner(winner_id)
		game_manager.game_over_state.enter_state()
		return
		
	exit_state()

func check_for_win()->int:
	
	#Grab variables for easier typing
	var rows = board.settings.rows
	var columns = board.settings.columns
	
	for r in rows:
		for c in columns:
			var current_board_slot = board.get_token(Vector2i(c,r))

			#if the current board slot doesn't have a token then move on.
			if current_board_slot == null:
				continue
			
			#find the playerID (Colour) of the current token
			var current_player_id = current_board_slot.player_id
			
			#all the directions that a win can be detected in (to the right, down, diagonal up and right, diagonal down and right.)

			for dir in WIN_DIRECTIONS:
				var steps = board.settings.tokens_to_win - 1
				var farthest_r = r + dir.x * steps
				var farthest_c = c + dir.y * steps

				if farthest_r < 0 or farthest_r >= rows or farthest_c < 0 or farthest_c >= columns:
					continue

				var win := true

				for i in range(1, board.settings.tokens_to_win):
					var check_r = r + dir.x * i
					var check_c = c + dir.y * i
					var checked_token = board.get_token(Vector2i(check_c, check_r))

					if checked_token == null:
						win = false
						break

					if checked_token.player_id != current_player_id:
						win = false
						break

				if win:
					return current_player_id
	return -1
