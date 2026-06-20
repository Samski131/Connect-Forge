@tool
extends Node
#Global script with useful variables as well as common helper functions.

enum TURN_PHASE {NONE,PLACEMENT, ACTION, RESOLUTION, GAME_OVER}
enum SLOT_TYPE {TOP_EDGE, BOTTOM_EDGE, LEFT_EDGE, RIGHT_EDGE, INTERIOR}

func _ready():
	pass
