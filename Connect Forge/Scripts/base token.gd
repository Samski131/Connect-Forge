class_name Token
extends Area2D

#This script is the basic behaviour for every single token.
#All common functions of tokens should go here, even if some special ones will override the functions.
enum TokenType{BASIC, ANVIL, PYRE, RAMP}
var player_id = 0
var token_pos :Vector2i = Vector2i.ZERO
var resolved:bool = false
var landed:bool = false
var token_type

@onready var sprites = $Sprites
@onready var token_pos_label = $"Token_pos Label"
var debug_label_visibility:bool = false
@export var charges:int =0
@export var ability_cost:int=0
func _ready():
	_setup()

func _setup():
	token_type = TokenType.BASIC
	
func update_token_position(): #checks if the token should move.
	var token_below =  Global.board_pool.get_adjacent_token(token_pos.x,token_pos.y, BoardSetting.DIRECTION.DOWN)
	if(token_below==null):
		var grav_direction =Global.board_settings.gravity_direction 
		var displacement_dirs =  Global.board_settings.displacement_direction.values() #the direction we should move based on the grav direction (0,-1) for down
		Global.board_pool.remove_token_from_board(Vector2i(token_pos.x,token_pos.y))
		token_pos += displacement_dirs[grav_direction] #move the token in the appropriate direction.
		Global.board_pool.add_token_to_board(self,Vector2i(token_pos.x,token_pos.y))
		move_token_visual()
		
	debug_token()

func _try_to_use_ability()->bool:
	return false #no ability to try it is always true
	
func move_token_visual(): #update the position of the actual token's tile not just the under the hood board representation.
	global_position.x = (token_pos.x * Global.slot_size.x) - (Global.board_settings.columns * Global.slot_size.x)/2 + Global.slot_size.x/2 
	global_position.y = (token_pos.y * Global.slot_size.y) - (Global.board_settings.rows * Global.slot_size.y)/2 + Global.slot_size.y/2

func check_if_token_at_limits()->bool: #check if the token is at the edge of the board based on the gravity direction.
	var limits:bool = false
	match Global.board_settings.gravity_direction:
		Global.board_settings.DIRECTION.UP: 
			if(token_pos.y == 0):
				limits=true
		Global.board_settings.DIRECTION.RIGHT: 
			if(token_pos.x == Global.board_settings.columns-1):
				limits=true
		Global.board_settings.DIRECTION.DOWN: 
			if(token_pos.y == Global.board_settings.rows-1):
				limits=true
		Global.board_settings.DIRECTION.LEFT: 
			if(token_pos.x == 0):
				limits=true
	var token_below =  Global.board_pool.get_adjacent_token(token_pos.x,token_pos.y, BoardSetting.DIRECTION.DOWN)
	if(token_below!=null):
		if(token_below.landed == true):
			limits = true
			
	if(limits):
		landed = true
	return limits
	
		
	
func reset_resolved():
	landed = false
	resolved = false

func check_enough_charges(cost:int)->bool:
	if charges >=cost:
		return true
	else:
		return false
		
func deduct_charges(cost:int):
	if(cost ==0):
		return
	charges-=cost
	sprites.darken(0.3)
	
func regain_charges(cost:int):
	charges+=cost
	sprites.recolor()
	
func recolor():
	sprites.recolor(player_id)

func debug_token():
	token_pos_label.visible = debug_label_visibility
	#token_pos_label.text = str(int(token_pos.x)) + "," + str(int(token_pos.y))
	#token_pos_label.text =str(token_pos.y * Global.board_settings.columns + token_pos.x)
	token_pos_label.text = str(player_id)
