class_name BoardGravityOrder
extends RefCounted

var settings:BoardSetting


func _init(new_settings:BoardSetting):
	settings = new_settings


func get_positions_in_gravity_order() -> Array[Vector2i]:
	var positions:Array[Vector2i] = []
	var rows:int = settings.rows
	var columns:int = settings.columns
	var DIRECTION = BoardSetting.DIRECTION
	
	match settings.gravity_direction:
		DIRECTION.DOWN:
			for y in range(rows - 1, -1, -1):
				for x in range(0, columns):
					positions.append(Vector2i(x, y))
		
		DIRECTION.UP:
			for y in range(0, rows):
				for x in range(0, columns):
					positions.append(Vector2i(x, y))
		
		DIRECTION.LEFT:
			for x in range(0, columns):
				for y in range(0, rows):
					positions.append(Vector2i(x, y))
		
		DIRECTION.RIGHT:
			for x in range(columns - 1, -1, -1):
				for y in range(0, rows):
					positions.append(Vector2i(x, y))
	
	return positions
