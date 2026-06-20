extends Token
#Ramp Token

func setup_special_token():
	token_type = TokenType.RAMP
	
func _try_to_use_ability()->bool:
	#return true if it works and changes the board.
	#return false if it fails to activate for any reason

	var token_above = board.get_adjacent_token(token_pos.x, token_pos.y,BoardSetting.DIRECTION.UP)
	
	if token_above == null:
		return false
	
	var ramp_drop_off_pos = board.get_adjacent_pos(token_pos.x,token_pos.y,BoardSetting.DIRECTION.DOWN_LEFT)
	
	var ramp_drop_off = board.get_token(Vector2i(ramp_drop_off_pos.x,ramp_drop_off_pos.y)) #check if there's a token in the drop off slot
	
	if ramp_drop_off != null: # there's a token in the position we want to drop into
		return false
		
	board.move_token_on_board(token_above, ramp_drop_off_pos)
	
	return true
