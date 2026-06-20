class_name BoardSetting
#Stores various bits of board information

enum DIRECTION {UP, RIGHT, DOWN, LEFT, UP_RIGHT,UP_LEFT,DOWN_RIGHT, DOWN_LEFT}

var gravity_direction = DIRECTION.DOWN
var rows:int =0
var columns:int=0
var tokens_to_win:int = 4 #how many tokens must be adjacent to win.

func get_direction_vector(direction:DIRECTION)->Vector2i:
	match direction:
		DIRECTION.UP:
			return Vector2i(0, -1)
		DIRECTION.RIGHT:
			return Vector2i(1, 0)
		DIRECTION.DOWN:
			return Vector2i(0, 1)
		DIRECTION.LEFT:
			return Vector2i(-1, 0)
		DIRECTION.UP_RIGHT:
			return Vector2i(1, -1)
		DIRECTION.UP_LEFT:
			return Vector2i(-1, -1)
		DIRECTION.DOWN_RIGHT:
			return Vector2i(1, 1)
		DIRECTION.DOWN_LEFT:
			return Vector2i(-1, 1)
	return Vector2i.ZERO
