extends Node

var placement_token_sprite:PackedScene = load("res://Scenes/Tokens/placement token sprite.tscn")
var current_placement_token
var base_token: PackedScene = load("res://Scenes/Tokens/base token.tscn")
var game_manager:Node

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")
func enter_state():
	get_parent().current_turn_phase = Global.TURN_PHASE.PLACEMENT
	current_placement_token = placement_token_sprite.instantiate()
	get_tree().root.call_deferred("add_child",current_placement_token)
	
func exit_state():
	if current_placement_token !=null:
		current_placement_token.queue_free()

	game_manager.action_state.enter_state()
	
func process_state():
	move_placement_token()
	if Input.is_action_just_pressed("left_click"):
		#if the slot we clicked on is empty
		
		if try_to_place_token() == false:
			return
		var slot_pos = Global.hovered_slot.slot_position
		if not Global.boardPool.getToken(slot_pos.x,slot_pos.y):
			createNewToken(slot_pos)
			
			#move onto action state
			exit_state()

func move_placement_token():
	if current_placement_token ==null:
		return
	
	if(Global.hovered_slot ==null):
		current_placement_token.visible = false
		return
	if(Global.SLOT_TYPE.TOP_EDGE not in Global.hovered_slot.slot_types):
		current_placement_token.visible = false
		return
	current_placement_token.visible = true
	current_placement_token.global_position = Global.hovered_slot.global_position

func try_to_place_token()->bool:
	if(Global.hovered_slot ==null):
		return false
	if(Global.SLOT_TYPE.TOP_EDGE not in Global.hovered_slot.slot_types):
		return false
	return true
		
func createNewToken(slot_pos:Vector2):
	var newToken = base_token.instantiate()
	newToken.tokenPos = slot_pos
	newToken.modulate = game_manager.player_colours[game_manager.current_player_ID]
	newToken.global_position = Global.hovered_slot.global_position
	Global.tokenPool.add_child(newToken)
	
