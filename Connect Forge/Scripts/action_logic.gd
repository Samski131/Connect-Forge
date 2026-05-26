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

func exit_state():
	game_manager.resolution_state.enter_state() #enters the resolution state.

func process_state():
	#loop through all tokensin the token pool until they are all reporting done.
	var tokens = Global.token_pool.get_children(false)
	var not_ready :bool = false #default is that token isn't ready
	for token in tokens: #for each token in the pool
		if token.resolved != true: #check if the token hasn't managed to be resolved (each token knows if it's resolved it's actions)
			token.update_token_position() # update the position (falling, fan, etc)
			not_ready= true #since this goes through every token, if even a single token isn't ready we don't leave the state.
	
	if(!not_ready):
		exit_state()
		
