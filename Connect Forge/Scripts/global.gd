@tool
extends Node
#Global script with useful variables as well as common helper functions.

enum TURN_PHASE {NONE,PLACEMENT, ACTION, RESOLUTION, GAME_OVER}
enum SLOT_TYPE {TOP_EDGE, BOTTOM_EDGE, LEFT_EDGE, RIGHT_EDGE, INTERIOR}

var hovered_slot = null #the current slot that is moused over.
var slot_size:Vector2 = Vector2.ZERO #the size of the texture for the slot
var board_settings:BoardSetting = BoardSetting.new()
var board_pool:Node2D
var token_pool:Node2D

func _ready():
	board_pool = get_tree().get_first_node_in_group("board pool")
	token_pool = get_tree().get_first_node_in_group("token pool")
	
func slot_to_global_position(sX,sY): #changes slot position from e.g (0,1) to (200,400). From slot to actual position.
	return Vector2(sX,sY) * slot_size

func global_position_to_slot(gX,gY): #detect which slot a certain position on the screen falls under.
	return floor( Vector2(gX,gY) / slot_size)
