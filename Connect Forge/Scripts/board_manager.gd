class_name BoardManager
extends Node2D
var board = []
var token_pool:Node2D
var settings:BoardSetting = BoardSetting.new()
var hovered_slot:Slot = null
var slot_size:Vector2 = Vector2.ZERO

func _ready():
	token_pool = get_tree().get_first_node_in_group("token pool")
#Controls various board functions and stores the under the hood board representation.

#gets a token from a given XY, error protection for numbers out of range
func get_token(pos:Vector2i)->Token:
	if pos.x < 0 or pos.x >= settings.columns:
		return null
	
	if pos.y < 0 or pos.y >= settings.rows:
		return null
	
	return board[pos.y * settings.columns + pos.x]


func get_adjacent_pos(x:int, y:int, direction:BoardSetting.DIRECTION)->Vector2i:
	var grav_direction = settings.gravity_direction
	var grav_vector = settings.get_direction_vector(grav_direction)
	var right_vector = settings.get_right_relative_vector(grav_vector)
	var offset:Vector2i
	var DIRECTION = BoardSetting.DIRECTION
	
	match(direction):
		DIRECTION.DOWN:
			offset = grav_vector
		DIRECTION.UP:
			offset = -grav_vector
		DIRECTION.RIGHT:
			offset = right_vector
		DIRECTION.LEFT:
			offset = -right_vector
		DIRECTION.UP_RIGHT:
			offset = -grav_vector + right_vector
		DIRECTION.UP_LEFT:
			offset = -grav_vector - right_vector
		DIRECTION.DOWN_RIGHT:
			offset = grav_vector + right_vector
		DIRECTION.DOWN_LEFT:
			offset = grav_vector - right_vector
	
	return Vector2i(x, y) + offset
	
func get_adjacent_token(x:int, y:int, direction:BoardSetting.DIRECTION)->Token:
	var check_token_pos = get_adjacent_pos(x, y, direction)
	return get_token(Vector2i(check_token_pos.x, check_token_pos.y))

#Adds a token to the board array DOES NOT ADD A TOKEN NODE.
func add_token_to_board(new_token:Token, slot_pos:Vector2i)->bool:
	if is_position_in_bounds(slot_pos) == false: #if the position isn't on the board skip
		return false
	if(get_token(Vector2i(slot_pos.x,slot_pos.y))==null): #ensures there's not already a token in this slot
		board[slot_pos.y* settings.columns + slot_pos.x ]= new_token
		return true
	return false

func create_new_token(token_scene:PackedScene, slot_pos:Vector2i, player_id:int):
	if is_position_in_bounds(slot_pos) == false:
		return null
	
	if get_token(slot_pos) != null:
		return null
		
	var new_token:Token = token_scene.instantiate()
	token_pool.add_child(new_token)
	
	new_token.setup(self, slot_pos, player_id)
	add_token_to_board(new_token, slot_pos)

	return new_token

#Removes a token from the board array DOES NOT REMOVE ADD A TOKEN NODE.
func remove_token_from_board(slot_pos:Vector2i)->bool:
	if is_position_in_bounds(slot_pos) == false: #if the position isn't on the board skip
		return false
		
	var token = get_token(Vector2i(slot_pos.x,slot_pos.y))
	if(token!=null):#ensures there is already a token in this slot
		board[slot_pos.y* settings.columns + slot_pos.x ]= null
		return true
	return false
	
#Quick function to swap out a token with a new one.
func replace_token_on_board(new_token:Token, slot_pos:Vector2i)->bool:
	var success:bool
	success = remove_token_from_board(slot_pos)
	if(success):
		success = add_token_to_board(new_token, slot_pos)
	return success
	
func is_position_in_bounds(pos:Vector2i)->bool:
	return (pos.x >= 0 and pos.x < settings.columns and pos.y >= 0 and pos.y < settings.rows)

func move_token_on_board(token:Token, new_pos:Vector2i)->bool:
	if token == null: #if you've sent an invalid token to move
		return false
	
	if is_position_in_bounds(new_pos) == false: #if the position isn't on the board
		return false
	
	if get_token(Vector2i(new_pos.x, new_pos.y)) != null: #if there's already a token at the new position don't move.
		return false
	
	remove_token_from_board(token.token_pos)
	token.token_pos = new_pos
	add_token_to_board(token, new_pos)
	token.move_token_visual()
	
	return true

func set_hovered_slot(slot:Slot):
	hovered_slot = slot

func clear_hovered_slot(slot:Slot):
	if hovered_slot == slot:
		hovered_slot = null

func slot_to_global_position(slot_pos:Vector2i)->Vector2:
	var local_pos := Vector2(
		(slot_pos.x * slot_size.x) - (settings.columns * slot_size.x) / 2 + slot_size.x / 2,
		(slot_pos.y * slot_size.y) - (settings.rows * slot_size.y) / 2 + slot_size.y / 2
	)
	
	return to_global(local_pos)
	
func global_position_to_slot(global_pos:Vector2)->Vector2i:
	var local_pos := to_local(global_pos)
	
	var board_top_left := Vector2(-(settings.columns * slot_size.x) / 2,-(settings.rows * slot_size.y) / 2)
	
	var local_slot_pos := (local_pos - board_top_left) / slot_size
	
	return Vector2i(floor(local_slot_pos.x), floor(local_slot_pos.y))

func resolve_landing_triggers(landing_token:Token)->bool:
	if landing_token == null:
		return false
	
	var changed_board := false
	
	var token_below := get_adjacent_token(landing_token.token_pos.x, landing_token.token_pos.y, BoardSetting.DIRECTION.DOWN	)
	
	if token_below != null:
		#if the token below exists, pack a dictionary ful of some context.
		var impact_context := {
			"landing_token": landing_token,
			"impacted_token": token_below,
			"board": self
		}
		
		if token_below.trigger_keyword(Global.KEYWORD.ON_IMPACT, impact_context):
			changed_board = true
	
	# The landing token may have been deleted by On Impact.
	if get_token(landing_token.token_pos) != landing_token:
		return changed_board
	
	var land_context := {
		"landing_token": landing_token,
		"board": self
	}
	
	if landing_token.trigger_keyword(Global.KEYWORD.ON_LAND, land_context):
		changed_board = true
	
	return changed_board
