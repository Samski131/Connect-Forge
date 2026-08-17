class_name PlacementRules
extends RefCounted


static func is_valid_starting_slot(board_state:BoardState, settings:BoardSetting, slot_pos:Vector2i) -> bool:
	if board_state == null:
		return false
	
	if settings == null:
		return false
	
	if board_state.is_position_in_bounds(slot_pos) == false:
		return false
	
	if board_state.get_token(slot_pos) != null:
		return false
	
	match settings.gravity_direction:
		BoardSetting.GRID_DIRECTION.DOWN:
			if slot_pos.y == 0:
				return true
		
		BoardSetting.GRID_DIRECTION.UP:
			if slot_pos.y == settings.rows - 1:
				return true
		
		BoardSetting.GRID_DIRECTION.RIGHT:
			if slot_pos.x == 0:
				return true
		
		BoardSetting.GRID_DIRECTION.LEFT:
			if slot_pos.x == settings.columns - 1:
				return true
	
	return false


static func get_valid_starting_slots(board_state:BoardState, settings:BoardSetting) -> Array[Vector2i]:
	var result:Array[Vector2i] = []
	
	if board_state == null:
		return result
	
	if settings == null:
		return result
	
	for y in range(settings.rows):
		for x in range(settings.columns):
			var slot_pos:Vector2i = Vector2i(x, y)
			
			if is_valid_starting_slot(board_state, settings, slot_pos):
				result.append(slot_pos)
	
	return result
