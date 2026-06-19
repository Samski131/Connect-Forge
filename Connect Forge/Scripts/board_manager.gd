extends Node2D
var board = []
var game_manager:Node

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")
	
#Controls various board functions and stores the under the hood board representation.

#gets a token from a given XY, error protection for numbers out of range
func get_token(x:float, y:float)->Token: 
	var width = Global.board_settings.width
	if (x <0 or x >= width):
		return
		
	if (y <0 or y > Global.board_settings.height):
		return

	if( y*width + x >= width*Global.board_settings.height):
		return
		
	return board[y*width + x]
	
func get_adjacent_pos(x:float, y:float, direction:BoardSetting.DIRECTION)->Vector2:
	var grav_direction = Global.board_settings.gravity_direction
	var grav_vector = Global.board_settings.displacement_direction.values()[grav_direction]
	var offset:Vector2
	
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
	
	return Vector2(x, y) + offset
	
func get_adjacent_token(x:float, y:float, direction:BoardSetting.DIRECTION)->Token:
	var check_token_pos = get_adjacent_pos(x, y, direction)
	return get_token(check_token_pos.x, check_token_pos.y)

#Adds a token to the board array DOES NOT ADD A TOKEN NODE.
func add_token_to_board(new_token:Token, slot_pos:Vector2):
	if(get_token(slot_pos.x,slot_pos.y)==null): #ensures there's not already a token in this slot
		Global.board_pool.board[slot_pos.y*Global.board_settings.width + slot_pos.x ]= new_token

func create_new_token(token:PackedScene,slot_pos:Vector2):
	#Create the node representation of the token and also add a board representation too.
	var new_token = token.instantiate()
	new_token.token_pos = slot_pos

	new_token.global_position = Global.hovered_slot.global_position
	new_token.player_id = game_manager.current_player_id
	Global.token_pool.add_child(new_token)
	new_token.recolor()
	add_token_to_board(new_token,Vector2(slot_pos.x,slot_pos.y))
	

#Removes a token from the board array DOES NOT REMOVE ADD A TOKEN NODE.
func remove_token_from_board(slot_pos:Vector2):
	var token = get_token(slot_pos.x,slot_pos.y)
	if(token!=null):#ensures there is already a token in this slot
		Global.board_pool.board[slot_pos.y*Global.board_settings.width + slot_pos.x ]= null

#Quick function to swap out a token with a new one.
func replace_token_on_board(new_token:Token, slot_pos:Vector2):
	remove_token_from_board(slot_pos)
	add_token_to_board(new_token, slot_pos)
	
func move_token_on_board(token:Token, new_pos:Vector2)->bool:
	if token == null:
		return false
	
	if get_token(new_pos.x, new_pos.y) != null:
		return false
	
	remove_token_from_board(token.token_pos)
	token.token_pos = new_pos
	add_token_to_board(token, new_pos)
	token.move_token_visual()
	
	return true
