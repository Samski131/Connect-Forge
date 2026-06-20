extends Node
#This script handles the logic for the action state.
#It handles entry, processing and exiting states.
#The action state is where tokens will effect each other, fall and generally interact.
#Each token handles it's own interactions and reports when it is finished during the processed state.

enum Report {RESOLVED,IN_PROGRESS, EMPTY}
var all_resolved:bool =true
var game_manager:Node
var board:BoardManager

func setup(new_game_manager:Node, new_board:BoardManager):
	game_manager = new_game_manager
	board = new_board
	
func enter_state():
	game_manager.current_turn_phase = Global.TURN_PHASE.ACTION #Sets the game manager phase to the Action phase.
	reset_token_resolution()
	
func exit_state():
	game_manager.resolution_state.enter_state() #enters the resolution state.

func process_state():
	if board.visuals != null and board.visuals.is_busy():
		return
	
	all_resolved = true
	
	var grav_dir:int = board.settings.gravity_direction
	var rows:int = board.settings.rows
	var columns:int = board.settings.columns 
	var DIRECTION = BoardSetting.DIRECTION
	
	match grav_dir:
		DIRECTION.DOWN:
			for y in range(rows - 1, -1, -1):
				for x in range(0, columns, 1):
					process_token(x, y)
					if board.visuals != null and board.visuals.is_busy():
						all_resolved = false
						return
		
		DIRECTION.UP:
			for y in range(0, rows, 1):
				for x in range(0, columns, 1):
					process_token(x, y)
					if board.visuals != null and board.visuals.is_busy():
						all_resolved = false
						return
		
		DIRECTION.LEFT:
			for x in range(0, columns, 1):
				for y in range(0, rows, 1):
					process_token(x, y)
					if board.visuals != null and board.visuals.is_busy():
						all_resolved = false
						return
		
		DIRECTION.RIGHT:
			for x in range(columns - 1, -1, -1):
				for y in range(0, rows, 1):
					process_token(x, y)
					if board.visuals != null and board.visuals.is_busy():
						all_resolved = false
						return
	
	if all_resolved:
		exit_state()

func report_on_token(token)-> Report:
	if token == null:
		return Report.EMPTY
	
	if token.resolved:
		return Report.RESOLVED
	
	var reached_limit:bool = token.check_if_token_at_limits()
	
	if reached_limit == false:
		token.update_token_position()
		
		return Report.IN_PROGRESS
	
	var trigger_was_used:bool = board.resolve_landing_triggers(token)

	if trigger_was_used:
		return Report.IN_PROGRESS

	var ability_was_used:bool = token._try_to_use_ability()

	if ability_was_used:
		return Report.IN_PROGRESS

	token.resolved = true
	return Report.RESOLVED
		
func reset_token_resolution():
	get_tree().call_group("token", "reset_resolved")
	
func process_token(x:int,y:int):
	var token = board.get_token(Vector2i(x,y))
	var report = report_on_token(token)
	if(report == Report.IN_PROGRESS):
		all_resolved = false
