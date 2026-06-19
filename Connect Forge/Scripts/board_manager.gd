extends Node2D
var board = []
var game_manager:Node

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")
	
#Controls various board functions and stores the under the hood board representation.

#gets a token from a given XY, error protection for numbers out of range
func get_token(pos:Vector2i)->Token:
	if pos.x < 0 or pos.x >= Global.board_settings.columns:
		return null
	
	if pos.y < 0 or pos.y >= Global.board_settings.rows:
		return null
	
	return board[pos.y * Global.board_settings.columns + pos.x]


func get_adjacent_pos(x:int, y:int, direction:BoardSetting.DIRECTION)->Vector2i:
	var grav_direction = Global.board_settings.gravity_direction
	var grav_vector = Global.board_settings.displacement_direction.values()[grav_direction]
	var offset:Vector2i
	
	match(direction):
		BoardSetting.DIRECTION.DOWN:
			offset = grav_vector
		BoardSetting.DIRECTION.UP:
			offset = -grav_vector
		BoardSetting.DIRECTION.RIGHT:
			offset = grav_vector.orthogonal()
		BoardSetting.DIRECTION.LEFT:
			offset = -grav_vector.orthogonal()
		BoardSetting.DIRECTION.UP_RIGHT:
			offset = -grav_vector + grav_vector.orthogonal()
		BoardSetting.DIRECTION.UP_LEFT:
			offset = -grav_vector - grav_vector.orthogonal()
		BoardSetting.DIRECTION.DOWN_RIGHT:
			offset = grav_vector + grav_vector.orthogonal()
		BoardSetting.DIRECTION.DOWN_LEFT:
			offset = grav_vector - grav_vector.orthogonal()
	
	return Vector2i(x, y) + offset
	
func get_adjacent_token(x:int, y:int, direction:BoardSetting.DIRECTION)->Token:
	var check_token_pos = get_adjacent_pos(x, y, direction)
	return get_token(Vector2i(check_token_pos.x, check_token_pos.y))

#Adds a token to the board array DOES NOT ADD A TOKEN NODE.
func add_token_to_board(new_token:Token, slot_pos:Vector2i):
	if is_position_in_bounds(slot_pos) == false: #if the position isn't on the board skip
		return false
	if(get_token(Vector2i(slot_pos.x,slot_pos.y))==null): #ensures there's not already a token in this slot
		Global.board_pool.board[slot_pos.y*Global.board_settings.columns + slot_pos.x ]= new_token


func create_new_token(token_scene:PackedScene, slot_pos:Vector2i, player_id:int):
	if is_position_in_bounds(slot_pos) == false: #if the position isn't on the board skip
		return false
		
	var new_token = token_scene.instantiate()
	new_token.token_pos = slot_pos
	new_token.player_id = player_id

	Global.token_pool.add_child(new_token)
	add_token_to_board(new_token, slot_pos)
	new_token.recolor()
	new_token.move_token_visual()

	return new_token

#Removes a token from the board array DOES NOT REMOVE ADD A TOKEN NODE.
func remove_token_from_board(slot_pos:Vector2i):
	if is_position_in_bounds(slot_pos) == false: #if the position isn't on the board skip
		return false
		
	var token = get_token(Vector2i(slot_pos.x,slot_pos.y))
	if(token!=null):#ensures there is already a token in this slot
		Global.board_pool.board[slot_pos.y*Global.board_settings.columns + slot_pos.x ]= null

#Quick function to swap out a token with a new one.
func replace_token_on_board(new_token:Token, slot_pos:Vector2i):
	remove_token_from_board(slot_pos)
	add_token_to_board(new_token, slot_pos)
	
func is_position_in_bounds(pos:Vector2i)->bool:
	return (pos.x >= 0 and pos.x < Global.board_settings.columns and pos.y >= 0 and pos.y < Global.board_settings.rows)

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
