extends Node
var game_manager:Node

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")

func enter_state():
	game_manager.current_turn_phase = Global.TURN_PHASE.ACTION

func exit_state():
	game_manager.resolution_state.enter_state()

func process_state():
	#loop through all tokens until they are all reporting done.
	var tokens = Global.tokenPool.get_children(false)
	@warning_ignore("unused_variable")
	var not_ready :bool = false
	for token in tokens:
		if token.resolved != true:
			token.update_token_position()
			not_ready= true
	
	if(!not_ready):
	
		exit_state()
		
