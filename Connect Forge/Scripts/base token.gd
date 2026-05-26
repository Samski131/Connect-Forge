class_name Token
extends Area2D


var playerID = 0
var tokenPos :Vector2 = Vector2(0,0)
var ability_charges = 0
var resolved:bool = false
@onready var timer:Timer = $Timer

#check if I should move DONE
#check if I should effect tokens around me?
#use my ability if needed
#Tell board I'm finished.

func setupToken():
	#set position and stuff
	pass

func update_token_position():
	var attempts =0
	while (can_fall() and attempts<Global.board_settings.board_height+1):
		attempts +=1
		var grav_direction =Global.board_settings.gravity_direction
		var displacement_dirs =  Global.board_settings.displacement_direction.values()
		Global.boardPool.board[tokenPos.x*Global.board_settings.board_width + tokenPos.y]= null
		tokenPos += displacement_dirs[grav_direction]
		Global.boardPool.board[tokenPos.x*Global.board_settings.board_width + tokenPos.y]= self
		moveToken(tokenPos)
		timer.start(0.1)
		
func moveToken(pos:Vector2):
	global_position.x = (tokenPos.x * Global.slot_size.x) - (Global.board_settings.board_collumns * Global.slot_size.x)/2 + Global.slot_size.x/2 
	global_position.y = (tokenPos.y * Global.slot_size.y) - (Global.board_settings.board_rows * Global.slot_size.y)/2 + Global.slot_size.y/2

func check_if_token_at_limits()->bool:
	match Global.board_settings.gravity_direction:
		Global.board_settings.DIRECTION.UP: 
			if(tokenPos.y == 0):
				return true
		Global.board_settings.DIRECTION.RIGHT: 
			if(tokenPos.x == Global.board_settings.board_width-1):
				return true
		Global.board_settings.DIRECTION.DOWN: 
			if(tokenPos.y == Global.board_settings.board_height-1):
				return true
		Global.board_settings.DIRECTION.LEFT: 
			if(tokenPos.x == 0):
				return true
	return false
	
func can_fall()->bool:
	#if there is space to fall in the direction of gravity, fall.
	#check for piece "down"
	var grav_direction =Global.board_settings.gravity_direction
	var displacement_dirs =  Global.board_settings.displacement_direction.values()
	var dis:Vector2 =displacement_dirs[grav_direction]
	#check we're not already at the furthest we can go
	if check_if_token_at_limits():
		resolved = true
		return false
		
	#Checks if there is a token "below" the current token (in the direction of gravity)
	print("Token pos", tokenPos)
	print("Other token pos", Vector2(tokenPos.x + dis.x,tokenPos.y + dis.y ))
	if Global.boardPool.getToken(tokenPos.x + dis.x,tokenPos.y + dis.y ) != null:
		resolved = true
		return false
	
	#move token
	return true
