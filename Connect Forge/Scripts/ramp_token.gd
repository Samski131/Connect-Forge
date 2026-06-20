extends Token
#Ramp Token

func setup_special_token():
	token_type = TokenType.RAMP
	keywords = [Global.KEYWORD.ON_IMPACT]


func _try_to_use_ability()->bool:
	return false


func _on_impact(context:Dictionary)->bool:
	var landing_token:Token = context.get("landing_token", null)
	
	if landing_token == null:
		return false
	
	var ramp_drop_off_pos = board.get_adjacent_pos(token_pos.x,token_pos.y,BoardSetting.DIRECTION.LEFT)
	
	if board.is_position_in_bounds(ramp_drop_off_pos) == false:
		return false
	
	if board.get_token(ramp_drop_off_pos) != null:
		return false
	
	return board.move_token_on_board(landing_token, ramp_drop_off_pos)
