extends Node2D
var board = []
#Controls various board functions and stores the under the hood board representation.

#gets a token from a given XY, error protection for numbers out of range
func get_token(x:float, y:float)->Token: 
	if (x <0 or x >= Global.board_settings.width):
		return
		
	if (y <0 or y > Global.board_settings.height):
		return
		
	var width = Global.board_settings.width

	return board[y*width + x]

#Adds a token to the board array DOES NOT ADD A TOKEN NODE.
func add_token_to_board(new_token:Token, slot_pos:Vector2):
	if(get_token(slot_pos.x,slot_pos.y)==null): #ensures there's not already a token in this slot
		Global.board_pool.board[slot_pos.y*Global.board_settings.width + slot_pos.x ]= new_token

#Removes a token from the board array DOES REMOVE ADD A TOKEN NODE.
func remove_token_from_board(slot_pos:Vector2):
	if(get_token(slot_pos.x,slot_pos.y)!=null):#ensures there is already a token in this slot
		Global.board_pool.board[slot_pos.y*Global.board_settings.width + slot_pos.x ]= null

#Quick function to swap out a token with a new one.
func replace_token_on_board(new_token:Token, slot_pos:Vector2):
	remove_token_from_board(slot_pos)
	add_token_to_board(new_token, slot_pos)
	
