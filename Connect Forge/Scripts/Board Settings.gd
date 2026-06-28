class_name BoardSetting
# Stores board configuration and direction helpers.

enum GRID_DIRECTION {
	UP,
	RIGHT,
	DOWN,
	LEFT,
	UP_RIGHT,
	UP_LEFT,
	DOWN_RIGHT,
	DOWN_LEFT
}

enum RELATIVE_DIRECTION {
	DOWN,
	RIGHT,
	UP,
	LEFT,
	DOWN_RIGHT,
	DOWN_LEFT,
	UP_RIGHT,
	UP_LEFT
}

var gravity_direction:GRID_DIRECTION = GRID_DIRECTION.DOWN
var rows:int = 0
var columns:int = 0
var tokens_to_win:int = 4


func get_grid_direction_vector(direction:GRID_DIRECTION) -> Vector2i:
	match direction:
		GRID_DIRECTION.UP:
			return Vector2i(0, -1)
		GRID_DIRECTION.RIGHT:
			return Vector2i(1, 0)
		GRID_DIRECTION.DOWN:
			return Vector2i(0, 1)
		GRID_DIRECTION.LEFT:
			return Vector2i(-1, 0)
		GRID_DIRECTION.UP_RIGHT:
			return Vector2i(1, -1)
		GRID_DIRECTION.UP_LEFT:
			return Vector2i(-1, -1)
		GRID_DIRECTION.DOWN_RIGHT:
			return Vector2i(1, 1)
		GRID_DIRECTION.DOWN_LEFT:
			return Vector2i(-1, 1)
	
	return Vector2i.ZERO


func get_right_relative_vector(direction_vector:Vector2i) -> Vector2i:
	return Vector2i(direction_vector.y, -direction_vector.x)
