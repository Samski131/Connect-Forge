extends Token
# Bomb Token
# Destroys itself and adjacent tokens when it lands.

func setup_special_token():
	token_type = TokenLibrary.TokenType.BOMB
	keywords = [Global.KEYWORD.ON_LAND]


func _try_to_use_ability()->bool:
	return false


func _on_land(_context:Dictionary)->bool:
	queue_visual_effect(TokenShimmerVisualEffect.new(self))
	board.destroy_token(self)
	
	var sides:Array[BoardSetting.RELATIVE_DIRECTION] = [
		BoardSetting.RELATIVE_DIRECTION.UP,
		BoardSetting.RELATIVE_DIRECTION.RIGHT,
		BoardSetting.RELATIVE_DIRECTION.DOWN,
		BoardSetting.RELATIVE_DIRECTION.LEFT
	]
	
	for side in sides:
		var side_token:Token = board.get_relative_adjacent_token(token_pos.x, token_pos.y, side)
		
		if side_token == null:
			continue
		
		board.destroy_token(side_token)
	
	return true
