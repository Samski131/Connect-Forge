extends Token
# Dagger Token
# Destroys a token that passes on this token's right side.

func setup_special_token():
	token_type = TokenType.BOMB
	keywords = [Global.KEYWORD.ON_LAND]

func _try_to_use_ability()->bool:
	return false


func _on_land(_context:Dictionary)->bool:
	board.visuals.queue_effect(TokenShimmerVisualEffect.new(self))
	board.destroy_token(self)
	var sides = [BoardSetting.DIRECTION.UP, BoardSetting.DIRECTION.RIGHT, BoardSetting.DIRECTION.DOWN, BoardSetting.DIRECTION.LEFT ]
	for side in sides:
		var side_token = board.get_adjacent_token(token_pos.x, token_pos.y, side)

		if side_token == null:
			continue
		
		board.destroy_token(side_token)


	return true
