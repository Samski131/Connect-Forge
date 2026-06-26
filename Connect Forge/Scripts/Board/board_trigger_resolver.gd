class_name BoardTriggerResolver
extends RefCounted

var board:BoardManager
var pending_pass_triggers:Array[Dictionary] = []


func _init(new_board:BoardManager):
	board = new_board


func clear_pending_pass_triggers() -> void:
	pending_pass_triggers.clear()


func get_fall_path(token:Token) -> Array[Vector2i]:
	var path:Array[Vector2i] = []
	
	if token == null:
		return path
	
	if is_instance_valid(token) == false:
		return path
	
	var current_pos := token.token_pos
	var next_pos := board.get_adjacent_pos(
		current_pos.x,
		current_pos.y,
		BoardSetting.DIRECTION.DOWN
	)
	
	while board.is_position_in_bounds(next_pos) and board.get_token(next_pos) == null:
		path.append(next_pos)
		current_pos = next_pos
		next_pos = board.get_adjacent_pos(
			current_pos.x,
			current_pos.y,
			BoardSetting.DIRECTION.DOWN
		)
	
	return path


func find_first_pass_trigger_step(
	moving_token:Token,
	start_pos:Vector2i,
	path:Array[Vector2i]
) -> Dictionary:
	var previous_pos := start_pos
	
	for to_pos in path:
		if has_passing_reactor_for_step(moving_token, previous_pos, to_pos):
			return {
				"has_pass_trigger": true,
				"from_pos": previous_pos,
				"to_pos": to_pos
			}
		
		previous_pos = to_pos
	
	return {
		"has_pass_trigger": false,
		"from_pos": start_pos,
		"to_pos": path.back() if path.size() > 0 else start_pos
	}


func has_passing_reactor_for_step(
	moving_token:Token,
	from_pos:Vector2i,
	to_pos:Vector2i
) -> bool:
	var pass_checks := [
		[BoardSetting.DIRECTION.RIGHT, Global.KEYWORD.ON_PASS_LEFT],
		[BoardSetting.DIRECTION.LEFT, Global.KEYWORD.ON_PASS_RIGHT],
		[BoardSetting.DIRECTION.DOWN, Global.KEYWORD.ON_PASS_ABOVE],
		[BoardSetting.DIRECTION.UP, Global.KEYWORD.ON_PASS_BELOW],
	]
	
	for check in pass_checks:
		var neighbour_direction:BoardSetting.DIRECTION = check[0]
		var keyword:Global.KEYWORD = check[1]
		
		var reacting_pos := board.get_adjacent_pos(
			to_pos.x,
			to_pos.y,
			neighbour_direction
		)
		
		var reacting_token := board.get_token(reacting_pos)
		
		if reacting_token == null:
			continue
		
		if reacting_token == moving_token:
			continue
		
		var context := {
			"moving_token": moving_token,
			"reacting_token": reacting_token,
			"from_pos": from_pos,
			"to_pos": to_pos,
			"keyword": keyword,
			"board": board
		}
		
		if reacting_token._can_trigger_keyword(keyword, context):
			return true
	
	return false


func resolve_landing_triggers(landing_token:Token) -> bool:
	if landing_token == null:
		return false
	
	var changed_board := false
	
	var token_below := board.get_adjacent_token(
		landing_token.token_pos.x,
		landing_token.token_pos.y,
		BoardSetting.DIRECTION.DOWN
	)
	
	if token_below != null:
		var impact_context := {
			"landing_token": landing_token,
			"impacted_token": token_below,
			"board": board
		}
		
		if token_below.trigger_keyword(Global.KEYWORD.ON_IMPACT, impact_context):
			changed_board = true
	
	# The landing token may have been deleted or moved by On Impact.
	if board.get_token(landing_token.token_pos) != landing_token:
		return changed_board
	
	var land_context := {
		"landing_token": landing_token,
		"board": board
	}
	
	if landing_token.trigger_keyword(Global.KEYWORD.ON_LAND, land_context):
		changed_board = true
	
	return changed_board


func resolve_passing_triggers(
	moving_token:Token,
	from_pos:Vector2i,
	to_pos:Vector2i
) -> bool:
	if moving_token == null:
		return false
	
	if board.get_token(to_pos) != moving_token:
		return false
	
	var changed_board := false
	
	var pass_checks := [
		[BoardSetting.DIRECTION.RIGHT, Global.KEYWORD.ON_PASS_LEFT],
		[BoardSetting.DIRECTION.LEFT, Global.KEYWORD.ON_PASS_RIGHT],
		[BoardSetting.DIRECTION.DOWN, Global.KEYWORD.ON_PASS_ABOVE],
		[BoardSetting.DIRECTION.UP, Global.KEYWORD.ON_PASS_BELOW],
	]
	
	for check in pass_checks:
		var neighbour_direction:BoardSetting.DIRECTION = check[0]
		var keyword:Global.KEYWORD = check[1]
		
		var reacting_pos := board.get_adjacent_pos(
			to_pos.x,
			to_pos.y,
			neighbour_direction
		)
		
		var reacting_token := board.get_token(reacting_pos)
		
		if reacting_token == null:
			continue
		
		if reacting_token == moving_token:
			continue
		
		var context := {
			"moving_token": moving_token,
			"reacting_token": reacting_token,
			"from_pos": from_pos,
			"to_pos": to_pos,
			"keyword": keyword,
			"board": board
		}
		
		if reacting_token.trigger_keyword(keyword, context):
			changed_board = true
		
		# Stop resolving pass triggers if the moving token was destroyed or moved.
		if board.get_token(to_pos) != moving_token:
			break
	
	return changed_board

func resolve_line_full_triggers() -> bool:
	for pos in board.get_positions_in_gravity_order():
		var token := board.get_token(pos)
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		if token.being_destroyed:
			continue
		
		var context := {
			"line_token": token,
			"board": board
		}
		
		if token.trigger_keyword(Global.KEYWORD.ON_LINE_FULL, context):
			return true
	
	return false

func queue_passing_trigger(
	moving_token:Token,
	from_pos:Vector2i,
	to_pos:Vector2i
) -> void:
	pending_pass_triggers.append({
		"moving_token": moving_token,
		"from_pos": from_pos,
		"to_pos": to_pos
	})


func resolve_pending_pass_triggers() -> bool:
	if pending_pass_triggers.is_empty():
		return false
	
	var changed_board := false
	var triggers := pending_pass_triggers.duplicate()
	pending_pass_triggers.clear()
	
	for trigger in triggers:
		var moving_token:Token = trigger["moving_token"]
		
		if moving_token == null:
			continue
		
		if is_instance_valid(moving_token) == false:
			continue
		
		if moving_token.being_destroyed:
			continue
		
		var from_pos:Vector2i = trigger["from_pos"]
		var to_pos:Vector2i = trigger["to_pos"]
		
		if resolve_passing_triggers(moving_token, from_pos, to_pos):
			changed_board = true
	
	return changed_board
