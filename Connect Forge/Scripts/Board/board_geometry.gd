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


func get_adjacent_pos(
	pos:Vector2i,
	direction:BoardSetting.DIRECTION
) -> Vector2i:
	var grav_direction = settings.gravity_direction
	var grav_vector = settings.get_direction_vector(grav_direction)
	var right_vector = settings.get_right_relative_vector(grav_vector)
	var offset:Vector2i = Vector2i.ZERO
	var DIRECTION = BoardSetting.DIRECTION
	
	match direction:
		DIRECTION.DOWN:
			offset = grav_vector
		DIRECTION.UP:
			offset = -grav_vector
		DIRECTION.RIGHT:
			offset = right_vector
		DIRECTION.LEFT:
			offset = -right_vector
		DIRECTION.UP_RIGHT:
			offset = -grav_vector + right_vector
		DIRECTION.UP_LEFT:
			offset = -grav_vector - right_vector
		DIRECTION.DOWN_RIGHT:
			offset = grav_vector + right_vector
		DIRECTION.DOWN_LEFT:
			offset = grav_vector - right_vector
	
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
