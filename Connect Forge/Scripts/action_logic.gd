extends Node
var game_manager:Node

#This script handles the logic for the action state.
#It handles entry, processing and exiting states.
#The action state is where tokens will effect each other, fall and generally interact.
#Each token handles it's own interactions and reports when it is finished during the processed state.

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")

func enter_state():
	game_manager.current_turn_phase = Global.TURN_PHASE.ACTION #Sets the game manager phase to the Action phase.
	reset_token_resolution()
func exit_state():
	game_manager.resolution_state.enter_state() #enters the resolution state.

func process_state():
	#loop through all tokensin the token pool until they are all reporting done.
	var not_ready :bool = false #default is that token isn't ready
	var grav_dir:int =Global.board_settings.gravity_direction
	var rows:int = Global.board_settings.rows
	var collumns:int = Global.board_settings.collumns 
	match(grav_dir):
		BoardSetting.DIRECTION.DOWN:
			for y in range(rows, -1, -1):
				for x in range(0, collumns, 1):
					var token = Global.board_pool.get_token(x,y)
					not_ready = process_token(token)==true#since this goes through every token, if even a single token isn't ready we don't leave the state.
		BoardSetting.DIRECTION.UP:
			for y in range(0, rows, 1):
				for x in range(0, collumns, 1):
					var token = Global.board_pool.get_token(x,y)
					not_ready = process_token(token)==true#since this goes through every token, if even a single token isn't ready we don't leave the state.
		BoardSetting.DIRECTION.LEFT:
			for x in range(0, collumns, 1):
				for y in range(0, rows, 1):
					var token = Global.board_pool.get_token(x,y)
					not_ready = process_token(token)==true#since this goes through every token, if even a single token isn't ready we don't leave the state.
		BoardSetting.DIRECTION.RIGHT:
			for x in range(collumns, -1, -1):
				for y in range(0, rows, 1):
					var token = Global.board_pool.get_token(x,y)
					not_ready = process_token(token)==true#since this goes through every token, if even a single token isn't ready we don't leave the state.
					
	if(!not_ready):
		exit_state()

func process_token(token):
	if token ==null:
		return
	
	if token.resolved != true: #check if the token hasn't managed to be resolved (each token knows if it's resolved it's actions)
		token.update_token_position() # update the position (falling, fan, etc)

func reset_token_resolution():
	get_tree().call_group("token", "reset_resolved")
