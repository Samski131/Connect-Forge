extends Node
var game_manager:Node
enum Report {RESOLVED,IN_PROGRESS, EMPTY}
var all_resolved:bool =true
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
	all_resolved= true #default is that token is resolved
	var grav_dir:int =Global.board_settings.gravity_direction
	var rows:int = Global.board_settings.rows
	var collumns:int = Global.board_settings.collumns 
	match(grav_dir):
		BoardSetting.DIRECTION.DOWN:
			for y in range(rows, -1, -1):
				for x in range(0, collumns, 1):
					process_token(x,y)
		BoardSetting.DIRECTION.UP:
			for y in range(0, rows, 1):
				for x in range(0, collumns, 1):
					process_token(x,y)
		BoardSetting.DIRECTION.LEFT:
			for x in range(0, collumns, 1):
				for y in range(0, rows, 1):
					process_token(x,y)
		BoardSetting.DIRECTION.RIGHT:
			for x in range(collumns, -1, -1):
				for y in range(0, rows, 1):
					process_token(x,y)

	if(all_resolved):
		exit_state()

func report_on_token(token)-> Report:
	if token ==null:
		return Report.EMPTY #slot is empty
	
	if token.resolved == true: #if the token has resolved already
		return Report.RESOLVED
	
	var reached_limit:bool = token.check_if_token_at_limits()
	var cant_use_ability:bool = false
	if(reached_limit):
		cant_use_ability = token._try_to_use_ability()
	else:
		token.update_token_position()
	
	if (reached_limit and cant_use_ability):
		return Report.RESOLVED
	else:
		return Report.IN_PROGRESS
		
func reset_token_resolution():
	get_tree().call_group("token", "reset_resolved")
	
func process_token(x:int,y:int):
	var token = Global.board_pool.get_token(x,y)
	var report = report_on_token(token)
	if(report == Report.IN_PROGRESS):
		all_resolved = false
