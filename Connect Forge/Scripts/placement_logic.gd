extends Node
#This script handles the logic for the placement state.
#This includes the ghostly placement token, detection of click inputs, and creating the token once it's placed.
var placement_token_sprite:PackedScene = load("res://Scenes/Tokens/placement token sprite.tscn")
var current_placement_token
var base_token: PackedScene = load("res://Scenes/Tokens/base token.tscn")
var anvil_token: PackedScene = load("res://Scenes/Tokens/anvil token.tscn")
var pyre_token: PackedScene = load("res://Scenes/Tokens/pyre token.tscn")
var ramp_token: PackedScene = load("res://Scenes/Tokens/ramp token.tscn")

var game_manager:Node

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")
	
func enter_state():
	get_parent().current_turn_phase = Global.TURN_PHASE.PLACEMENT
	current_placement_token = placement_token_sprite.instantiate()
	get_tree().root.call_deferred("add_child",current_placement_token)
	
func exit_state():
	#delete the ghost image placement token
	if current_placement_token !=null:
		current_placement_token.queue_free()

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
func place_attempt(token:PackedScene):
	#checks that the hovered slot actually is a slot, ensures the hovered slot is on the top row
	if try_to_place_token() == false:
		return
		
	var slot_pos = Global.hovered_slot.slot_position
	if Global.board_pool.get_token(Vector2i(slot_pos.x,slot_pos.y))==null: #if there is no token in the slot we click on
		Global.board_pool.create_new_token(token, slot_pos, game_manager.current_player_id)
		
		#move onto action state
		exit_state()
func move_placement_token():
	#move the placement token, only if the token exits, is over a real slot and in the top row
	if current_placement_token ==null:
		return
	
	if(Global.hovered_slot ==null):
		current_placement_token.visible = false
		return
		
	var valid_slots:Global.SLOT_TYPE
	match Global.board_settings.gravity_direction:
		BoardSetting.DIRECTION.DOWN:
			valid_slots = Global.SLOT_TYPE.TOP_EDGE
		BoardSetting.DIRECTION.UP:
			valid_slots = Global.SLOT_TYPE.BOTTOM_EDGE
		BoardSetting.DIRECTION.RIGHT:
			valid_slots = Global.SLOT_TYPE.LEFT_EDGE
		BoardSetting.DIRECTION.LEFT:
			valid_slots = Global.SLOT_TYPE.RIGHT_EDGE
			
	if( valid_slots not in Global.hovered_slot.slot_types):
		current_placement_token.visible = false
		return
	current_placement_token.visible = true
	current_placement_token.global_position = Global.hovered_slot.global_position

func try_to_place_token()->bool:
	#check if we can place the token, true if yes, false if no.
	if(Global.hovered_slot ==null):
		return false
	
	if(check_slot_type()==false):
		return false
		
	var slot = Global.hovered_slot.slot_position
	var token_in_slot = Global.board_pool.get_token(Vector2i(slot.x,slot.y))

	if(token_in_slot):
		return false
	return true
		

func check_slot_type()->bool:
	var slot_types = Global.hovered_slot.slot_types
	
	match(Global.board_settings.gravity_direction):
		BoardSetting.DIRECTION.DOWN:
			if Global.SLOT_TYPE.TOP_EDGE not in Global.hovered_slot.slot_types:
				return false
		BoardSetting.DIRECTION.UP:
			if Global.SLOT_TYPE.BOTTOM_EDGE not in Global.hovered_slot.slot_types:
				return false
		BoardSetting.DIRECTION.LEFT:
			if Global.SLOT_TYPE.RIGHT_EDGE not in Global.hovered_slot.slot_types:
				return false
		BoardSetting.DIRECTION.RIGHT:
			if Global.SLOT_TYPE.LEFT_EDGE not in Global.hovered_slot.slot_types:
				return false
	return true
			
			
			
			
			
			
			
			
			
			
