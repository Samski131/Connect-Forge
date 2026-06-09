extends Node2D
var board = []
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

func get_adjacent_token(x:float, y:float, direction:BoardSetting.DIRECTION)->Token:
		#check if there's a token below mine (in the direction of gravity
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
			offset =  -grav_vector.orthogonal()
	var check_token_pos = Vector2(x,y) + offset
	var checked_token = Global.board_pool.get_token(check_token_pos.x,check_token_pos.y)
	return checked_token

#Adds a token to the board array DOES NOT ADD A TOKEN NODE.
func add_token_to_board(new_token:Token, slot_pos:Vector2):
	if(get_token(slot_pos.x,slot_pos.y)==null): #ensures there's not already a token in this slot
		Global.board_pool.board[slot_pos.y*Global.board_settings.width + slot_pos.x ]= new_token

#Removes a token from the board array DOES NOT REMOVE ADD A TOKEN NODE.
func remove_token_from_board(slot_pos:Vector2):
	var token = get_token(slot_pos.x,slot_pos.y)
	if(token!=null):#ensures there is already a token in this slot
		Global.board_pool.board[slot_pos.y*Global.board_settings.width + slot_pos.x ]= null

#Quick function to swap out a token with a new one.
func replace_token_on_board(new_token:Token, slot_pos:Vector2):
	remove_token_from_board(slot_pos)
	add_token_to_board(new_token, slot_pos)
	
