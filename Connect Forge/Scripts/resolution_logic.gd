extends Node
#This script handles the logic for the resolution state.
#This state handles checking for wins, once all possible wins are checked it starts the next turn.

var game_manager:Node
const  WIN_DIRECTIONS = [
	Vector2(0, 1),   # horizontal right
	Vector2(1, 0),   # vertical down
	Vector2(1, 1),   # diagonal down-right
	Vector2(1, -1),  # diagonal down-left
]
func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")

func enter_state():
	get_parent().current_turn_phase = Global.TURN_PHASE.RESOLUTION
	
func exit_state():
	game_manager.end_turn()
	
func process_state():
	var winner_id = check_for_win()
	if(winner_id != -1):
		game_manager.winner_ui.update_winner(winner_id)
		game_manager.game_over_state.enter_state()
	else:
		#print("No win!")
		pass
	exit_state()

func check_for_win()->int:
	
	#Grab variables for easier typing
	var board = Global.board_pool.board
	var rows = Global.board_settings.rows
	var collumns = Global.board_settings.collumns
	
	for r in rows:
		for c in collumns:
			
			#if(r== 0 and c ==0):
				#print("Checking from: (", r, ",",c,")")
			var current_index = r* collumns + c
			var current_board_slot = board[current_index]

			#if the current board slot doesn't have a token then move on.
			if current_board_slot == null:
				continue
			
			#find the playerID (Colour) of the current token
			var current_player_id = current_board_slot.player_id
			

			
			#all the directions that a win can be detected in (to the right, down, diagonal up and right, diagonal down and right.)

			for dir in WIN_DIRECTIONS: #for each of the 4 win directions
				
				#Check if the last token in the streak is out of bounds
				#a streak is a row, collumn or diagonal of tokens
				var steps = Global.board_settings.tokens_to_win - 1
				var farthest_r = r + dir.x * steps
				var farthest_c = c + dir.y * steps

				if (farthest_r <0 or farthest_r >= rows) or (farthest_c <0 or farthest_c >= collumns):
					continue #skips to next direction to check
				
				
				var token_indices= [] # array to hold the indices of the other tokens in a given streak
				
				for i in range(1,Global.board_settings.tokens_to_win): #add all of the other indices to an array to be checked
					var index = (r + dir.x * i) * collumns + (c+dir.y * i)
					token_indices.push_back(index)
				
				#for any given streak we are checking, assume the player has won until we find one of the two reasons those streaks don't win.
				var win:bool = true
				for index in token_indices:
					if(board[index] == null): #you don't win if there's an empty slot in your streak
						win = false
					elif(board[index].player_id != current_player_id): #you don't win if an oponent's token is in your streak
						win = false
				
				if win:
					return current_player_id
	return -1
