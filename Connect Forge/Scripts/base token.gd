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
var keywords:Array[Global.KEYWORD] = []
var board:BoardManager

@onready var sprites = $Sprites
@onready var token_pos_label = $"Token_pos Label"
var debug_label_visibility:bool = false
@export var charges:int =0
@export var ability_cost:int=0
func _ready():
	pass

func setup(new_board:BoardManager, new_pos:Vector2i, new_player_id:int):
	board = new_board
	token_pos = new_pos
	player_id = new_player_id
	setup_special_token()
	recolor()
	move_token_visual()

func setup_special_token():
	token_type = TokenType.BASIC
	keywords = []
	
func update_token_position(): #checks if the token should move.
	var token_below =  board.get_adjacent_token(token_pos.x,token_pos.y, BoardSetting.DIRECTION.DOWN)
	if(token_below==null):
		var grav_direction = board.settings.gravity_direction 
		var displacement_dir = board.settings.get_direction_vector(grav_direction) #the direction we should move based on the grav direction (0,-1) for down
		board.remove_token_from_board(Vector2i(token_pos.x,token_pos.y))
		token_pos += displacement_dir #move the token in the appropriate direction.
		board.add_token_to_board(self,Vector2i(token_pos.x,token_pos.y))
		move_token_visual()
		
	debug_token()

func _try_to_use_ability()->bool:
	return false #no ability to try it is always false
	
func move_token_visual(): #move the token to the correct location on the board
	global_position = board.slot_to_global_position(token_pos)
	
func check_if_token_at_limits()->bool: #check if the token is at the edge of the board based on the gravity direction.
	var limits:bool = false
	var direction = BoardSetting.DIRECTION
	match board.settings.gravity_direction:
		direction.UP: 
			if(token_pos.y == 0):
				limits=true
		direction.RIGHT: 
			if(token_pos.x == board.settings.columns-1):
				limits=true
		direction.DOWN: 
			if(token_pos.y == board.settings.rows-1):
				limits=true
		direction.LEFT: 
			if(token_pos.x == 0):
				limits=true
	var token_below =  board.get_adjacent_token(token_pos.x,token_pos.y, BoardSetting.DIRECTION.DOWN)
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
	#token_pos_label.text =str(token_pos.y * board.settings.columns + token_pos.x)
	token_pos_label.text = str(player_id)

func has_keyword(keyword:Global.KEYWORD)->bool:
	return keyword in keywords


func trigger_keyword(keyword:Global.KEYWORD, context:Dictionary)->bool:
	if has_keyword(keyword) == false:
		return false
	
	match keyword:
		Global.KEYWORD.ON_LAND:
			return _on_land(context)
		Global.KEYWORD.ON_IMPACT:
			return _on_impact(context)
		Global.KEYWORD.ON_PASS_LEFT:
			return _on_pass_left(context)
		Global.KEYWORD.ON_PASS_RIGHT:
			return _on_pass_right(context)
		Global.KEYWORD.ON_PASS_ABOVE:
			return _on_pass_above(context)
		Global.KEYWORD.ON_PASS_BELOW:
			return _on_pass_below(context)
	
	return false
	
func _on_land(context:Dictionary)->bool:
	return false


func _on_impact(context:Dictionary)->bool:
	return false


func _on_pass_left(context:Dictionary)->bool:
	return false


func _on_pass_right(context:Dictionary)->bool:
	return false


func _on_pass_above(context:Dictionary)->bool:
	return false


func _on_pass_below(context:Dictionary)->bool:
	return false
