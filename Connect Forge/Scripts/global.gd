extends Node
enum TURN_PHASE {NONE,PLACEMENT, ACTION, RESOLUTION, GAME_OVER}
enum SLOT_TYPE {TOP_EDGE, BOTTOM_EDGE, LEFT_EDGE, RIGHT_EDGE, INTERIOR}

var hovered_slot = null
var slot_size:Vector2 = Vector2.ZERO
var board_settings:BoardSetting = BoardSetting.new()
var boardPool:Node2D
var tokenPool:Node2D
func _ready():
	boardPool = get_tree().get_first_node_in_group("board pool")
	tokenPool = get_tree().get_first_node_in_group("token pool")
	
func slot_to_global_position(sX,sY):
	return Vector2(sX,sY) * slot_size

func global_position_to_slot(gX,gY):
	return floor( Vector2(gX,gY) / slot_size)
