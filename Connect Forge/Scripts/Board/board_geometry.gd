class_name BoardGeometry
extends RefCounted

var settings:BoardSetting
var board_node:Node2D
var slot_size:Vector2 = Vector2.ZERO


func _init(
	new_settings:BoardSetting,
	new_board_node:Node2D,
	new_slot_size:Vector2 = Vector2.ZERO
):
	settings = new_settings
	board_node = new_board_node
	slot_size = new_slot_size


func get_relative_adjacent_pos(pos:Vector2i, direction:BoardSetting.RELATIVE_DIRECTION) -> Vector2i:
	var gravity_direction:BoardSetting.GRID_DIRECTION = settings.gravity_direction
	var gravity_vector:Vector2i = settings.get_grid_direction_vector(gravity_direction)
	var right_vector:Vector2i = settings.get_right_relative_vector(gravity_vector)
	var offset:Vector2i = Vector2i.ZERO
	var RELATIVE_DIRECTION = BoardSetting.RELATIVE_DIRECTION
	
	match direction:
		RELATIVE_DIRECTION.DOWN:
			offset = gravity_vector
		RELATIVE_DIRECTION.UP:
			offset = -gravity_vector
		RELATIVE_DIRECTION.RIGHT:
			offset = right_vector
		RELATIVE_DIRECTION.LEFT:
			offset = -right_vector
		RELATIVE_DIRECTION.DOWN_RIGHT:
			offset = gravity_vector + right_vector
		RELATIVE_DIRECTION.DOWN_LEFT:
			offset = gravity_vector - right_vector
		RELATIVE_DIRECTION.UP_RIGHT:
			offset = -gravity_vector + right_vector
		RELATIVE_DIRECTION.UP_LEFT:
			offset = -gravity_vector - right_vector
	
	return pos + offset

func slot_to_global_position(slot_pos:Vector2i) -> Vector2:
	var local_pos := Vector2(
		(slot_pos.x * slot_size.x) - (settings.columns * slot_size.x) / 2 + slot_size.x / 2,
		(slot_pos.y * slot_size.y) - (settings.rows * slot_size.y) / 2 + slot_size.y / 2
	)
	
	return board_node.to_global(local_pos)


func global_position_to_slot(global_pos:Vector2) -> Vector2i:
	var local_pos := board_node.to_local(global_pos)
	
	var board_top_left := Vector2(
		-(settings.columns * slot_size.x) / 2,
		-(settings.rows * slot_size.y) / 2
	)
	
	var local_slot_pos := (local_pos - board_top_left) / slot_size
	
	return Vector2i(
		floor(local_slot_pos.x),
		floor(local_slot_pos.y)
	)
