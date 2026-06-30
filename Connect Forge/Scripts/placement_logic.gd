extends Node
# This script handles the logic for the placement state.
# This includes the ghostly placement token, detection of click inputs, and creating the token once it is placed.

var placement_token_sprite:PackedScene = load("res://Scenes/Tokens/placement token sprite.tscn")
var current_placement_token:Node2D = null

var game_manager:Node
var board:BoardManager


func setup(new_game_manager:Node, new_board:BoardManager):
	game_manager = new_game_manager
	board = new_board


func enter_state():
	get_parent().current_turn_phase = Global.TURN_PHASE.PLACEMENT
	clear_placement_token()
	
	current_placement_token = placement_token_sprite.instantiate()
	current_placement_token.visible = false
	current_placement_token.position = Vector2.ZERO
	current_placement_token.scale = Vector2.ONE
	
	if board != null and board.token_pool != null:
		board.token_pool.add_child(current_placement_token)
	else:
		add_child(current_placement_token)
		
		
func exit_state():
	clear_placement_token()
	game_manager.action_state.enter_state()


func process_state():
	move_placement_token()
	
	if Input.is_action_just_pressed("action_1"):
		place_attempt(TokenLibrary.TokenType.BASIC)
	elif Input.is_action_just_pressed("action_2"):
		place_attempt(TokenLibrary.TokenType.ANVIL)
	elif Input.is_action_just_pressed("action_3"):
		place_attempt(TokenLibrary.TokenType.PYRE)
	elif Input.is_action_just_pressed("action_4"):
		place_attempt(TokenLibrary.TokenType.RAMP)
	elif Input.is_action_just_pressed("action_5"):
		place_attempt(TokenLibrary.TokenType.DAGGER)
	elif Input.is_action_just_pressed("action_6"):
		place_attempt(TokenLibrary.TokenType.BOMB)
	elif Input.is_action_just_pressed("action_7"):
		place_attempt(TokenLibrary.TokenType.DRILL)
	elif Input.is_action_just_pressed("action_8"):
		place_attempt(TokenLibrary.TokenType.TETROMINO)
	elif Input.is_action_just_pressed("action_9"):
		place_attempt(TokenLibrary.TokenType.ROTATE_GRAVITY)
	elif Input.is_action_just_pressed("action_0"):
		place_attempt(TokenLibrary.TokenType.FAN)
	elif Input.is_action_just_pressed("action_-"):
		place_attempt(TokenLibrary.TokenType.CHAMELEON)


func place_attempt(token_type:int) -> void:
	if board == null:
		return
	
	if board.hovered_slot == null:
		return
	
	var slot_pos:Vector2i = board.hovered_slot.slot_position
	try_place_dragged_token(token_type, slot_pos, false)


func move_placement_token():
	if current_placement_token == null:
		return
	
	if board.hovered_slot == null:
		current_placement_token.visible = false
		return
	
	var valid_slot_type:Global.SLOT_TYPE = get_valid_placement_slot_type()
	
	if valid_slot_type not in board.hovered_slot.slot_types:
		current_placement_token.visible = false
		return
	
	current_placement_token.visible = true
	current_placement_token.global_position = board.slot_to_global_position(board.hovered_slot.slot_position)


func try_to_place_token()->bool:
	if board.hovered_slot == null:
		return false
	
	if check_slot_type() == false:
		return false
	
	var slot_pos:Vector2i = board.hovered_slot.slot_position
	var token_in_slot:Token = board.get_token(slot_pos)
	
	if token_in_slot != null:
		return false
	
	return true


func check_slot_type()->bool:
	if board.hovered_slot == null:
		return false
	
	var slot_types:Array = board.hovered_slot.slot_types
	var valid_slot_type:Global.SLOT_TYPE = get_valid_placement_slot_type()
	
	if valid_slot_type not in slot_types:
		return false
	
	return true


func get_valid_placement_slot_type() -> Global.SLOT_TYPE:
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	match board.settings.gravity_direction:
		GRID_DIRECTION.DOWN:
			return Global.SLOT_TYPE.TOP_EDGE
		GRID_DIRECTION.UP:
			return Global.SLOT_TYPE.BOTTOM_EDGE
		GRID_DIRECTION.RIGHT:
			return Global.SLOT_TYPE.LEFT_EDGE
		GRID_DIRECTION.LEFT:
			return Global.SLOT_TYPE.RIGHT_EDGE
	
	return Global.SLOT_TYPE.TOP_EDGE


func clear_placement_token():
	if current_placement_token != null:
		current_placement_token.queue_free()
		current_placement_token = null

func try_place_dragged_token(token_type:int, slot_pos:Vector2i, start_flipped:bool) -> bool:
	if game_manager == null:
		return false
	
	if board == null:
		return false
	
	if game_manager.current_turn_phase != Global.TURN_PHASE.PLACEMENT:
		return false
	
	if is_valid_starting_slot(slot_pos) == false:
		return false
	
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return false
	
	var new_token:Token = board.create_new_token(token_scene, slot_pos, game_manager.current_player_id, start_flipped)
	
	if new_token == null:
		return false
	
	exit_state()
	return true


func is_valid_starting_slot(slot_pos:Vector2i) -> bool:
	if board == null:
		return false
	
	if board.is_position_in_bounds(slot_pos) == false:
		return false
	
	if board.get_token(slot_pos) != null:
		return false
	
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	match board.settings.gravity_direction:
		GRID_DIRECTION.DOWN:
			if slot_pos.y == 0:
				return true
		
		GRID_DIRECTION.UP:
			if slot_pos.y == board.settings.rows - 1:
				return true
		
		GRID_DIRECTION.RIGHT:
			if slot_pos.x == 0:
				return true
		
		GRID_DIRECTION.LEFT:
			if slot_pos.x == board.settings.columns - 1:
				return true
	
	return false
