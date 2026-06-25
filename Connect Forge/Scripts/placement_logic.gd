extends Node
#This script handles the logic for the placement state.
#This includes the ghostly placement token, detection of click inputs, and creating the token once it's placed.
var placement_token_sprite:PackedScene = load("res://Scenes/Tokens/placement token sprite.tscn")
var current_placement_token
var base_token: PackedScene = load("res://Scenes/Tokens/base token.tscn")
var anvil_token: PackedScene = load("res://Scenes/Tokens/anvil token.tscn")
var pyre_token: PackedScene = load("res://Scenes/Tokens/pyre token.tscn")
var ramp_token: PackedScene = load("res://Scenes/Tokens/ramp token.tscn")
var dagger_token: PackedScene = load("res://Scenes/Tokens/dagger token.tscn")
var bomb_token: PackedScene = load("res://Scenes/Tokens/bomb token.tscn")

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
	current_placement_token.global_position = Vector2(-100000, -100000)
	
	get_tree().root.call_deferred("add_child", current_placement_token)
func exit_state():
	clear_placement_token()
	#begin the action state.
	game_manager.action_state.enter_state()


func process_state():
	move_placement_token() # update where the ghost placement token is.
	

	if Input.is_action_just_pressed("action_1"):
		place_attempt(base_token)
	elif Input.is_action_just_pressed("action_2"):
		place_attempt(anvil_token)
	elif Input.is_action_just_pressed("action_3"):
		place_attempt(pyre_token)
	elif Input.is_action_just_pressed("action_4"):
		place_attempt(ramp_token)
	elif Input.is_action_just_pressed("action_5"):
		place_attempt(dagger_token)
	elif Input.is_action_just_pressed("action_6"):
		place_attempt(bomb_token)
		
func place_attempt(token:PackedScene):
	#checks that the hovered slot actually is a slot, ensures the hovered slot is on the top row
	if try_to_place_token() == false:
		return
		
	var slot_pos = board.hovered_slot.slot_position
	if board.get_token(Vector2i(slot_pos.x,slot_pos.y))==null: #if there is no token in the slot we click on
		board.create_new_token(token, slot_pos, game_manager.current_player_id)
		
		#move onto action state
		exit_state()
func move_placement_token():
	#move the placement token, only if the token exits, is over a real slot and in the top row
	if current_placement_token ==null:
		return
	
	if(board.hovered_slot ==null):
		current_placement_token.visible = false
		return
		
	var valid_slots:Global.SLOT_TYPE
	var DIRECTION = BoardSetting.DIRECTION
	match board.settings.gravity_direction:
		DIRECTION.DOWN:
			valid_slots = Global.SLOT_TYPE.TOP_EDGE
		DIRECTION.UP:
			valid_slots = Global.SLOT_TYPE.BOTTOM_EDGE
		DIRECTION.RIGHT:
			valid_slots = Global.SLOT_TYPE.LEFT_EDGE
		DIRECTION.LEFT:
			valid_slots = Global.SLOT_TYPE.RIGHT_EDGE
			
	if( valid_slots not in board.hovered_slot.slot_types):
		current_placement_token.visible = false
		return
		
	current_placement_token.global_position = board.hovered_slot.global_position
	current_placement_token.visible = true
func try_to_place_token()->bool:
	#check if we can place the token, true if yes, false if no.
	if(board.hovered_slot ==null):
		return false
	
	if(check_slot_type()==false):
		return false
		
	var slot = board.hovered_slot.slot_position
	var token_in_slot = board.get_token(Vector2i(slot.x,slot.y))

	if(token_in_slot):
		return false
	return true
		

func check_slot_type()->bool:
	var slot_types = board.hovered_slot.slot_types
	var DIRECTION = BoardSetting.DIRECTION

	match(board.settings.gravity_direction):
		DIRECTION.DOWN:
			if Global.SLOT_TYPE.TOP_EDGE not in slot_types:
				return false
		DIRECTION.UP:
			if Global.SLOT_TYPE.BOTTOM_EDGE not in slot_types:
				return false
		DIRECTION.LEFT:
			if Global.SLOT_TYPE.RIGHT_EDGE not in slot_types:
				return false
		DIRECTION.RIGHT:
			if Global.SLOT_TYPE.LEFT_EDGE not in slot_types:
				return false
	return true
			
			
func clear_placement_token():
	if current_placement_token != null:
		current_placement_token.queue_free()
		current_placement_token = null
			
			
			
			
			
			
