class_name Token
extends Area2D

#This script is the basic behaviour for every single token.
#All common functions of tokens should go here, even if some special ones will override the functions.

var player_id = 0
var token_pos :Vector2 = Vector2(0,0)
var ability_charges = 0
var resolved:bool = false
@onready var timer:Timer = $Timer
@onready var sprites = $Sprites

func update_token_position(): #checks if the token should move.
	var attempts =0
	while (can_fall() and attempts<Global.board_settings.height+1): #keeps trying to fall until it can't anymore. Will try to fall the entire height of the board +1
		attempts +=1 #attempts counter keeps us from getting stalled in case there's something getting us stuck in a loop.
		var grav_direction =Global.board_settings.gravity_direction 
		var displacement_dirs =  Global.board_settings.displacement_direction.values() #the direction we should move based on the grav direction (0,-1) for down
		Global.board_pool.remove_token_from_board(Vector2(token_pos.x,token_pos.y))
		token_pos += displacement_dirs[grav_direction] #move the token in the appropriate direction.
		Global.board_pool.add_token_to_board(self,Vector2(token_pos.x,token_pos.y))
		move_token()

func move_token(): #update the position of the actual token's tile not just the under the hood board representation.
	global_position.x = (token_pos.x * Global.slot_size.x) - (Global.board_settings.collumns * Global.slot_size.x)/2 + Global.slot_size.x/2 
	global_position.y = (token_pos.y * Global.slot_size.y) - (Global.board_settings.rows * Global.slot_size.y)/2 + Global.slot_size.y/2

func check_if_token_at_limits()->bool: #check if the token is at the edge of the board based on the gravity direction.
	match Global.board_settings.gravity_direction:
		Global.board_settings.DIRECTION.UP: 
			if(token_pos.y == 0):
				return true
		Global.board_settings.DIRECTION.RIGHT: 
			if(token_pos.x == Global.board_settings.width-1):
				return true
		Global.board_settings.DIRECTION.DOWN: 
			if(token_pos.y == Global.board_settings.height-1):
				return true
		Global.board_settings.DIRECTION.LEFT: 
			if(token_pos.x == 0):
				return true
	return false
	
func can_fall()->bool:
	#if there is space to fall in the direction of gravity, fall.
	#check for piece "down"
	var grav_direction =Global.board_settings.gravity_direction
	var displacement_dirs =  Global.board_settings.displacement_direction.values()
	var dis:Vector2 =displacement_dirs[grav_direction]
	
	#Check if the token has hit the edge of the board, the maximum it can go based on gravity.
	if check_if_token_at_limits(): 
		#mark the token as resolved.
		resolved = true
		return false
		
	#Checks if there is a token "below" the current token (in the direction of gravity)
	if Global.board_pool.get_token(token_pos.x + dis.x,token_pos.y + dis.y ) != null:
		#mark the token as resolved.
		resolved = true
		return false
	
	#move token
	return true

func reset_resolved():
	resolved = false

func recolor(player_id):
	sprites.recolor(player_id)
