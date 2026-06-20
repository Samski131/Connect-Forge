extends Token
#Anvil Token

func setup_special_token():
	token_type = TokenType.ANVIL
	charges = 1
	ability_cost = 1
	keywords = [Global.KEYWORD.ON_LAND]


func _try_to_use_ability()->bool:
	return false


func _on_land(_context:Dictionary)->bool:
	if check_enough_charges(ability_cost) == false:
		return false

	var token_below = board.get_adjacent_token(token_pos.x,token_pos.y, BoardSetting.DIRECTION.DOWN	)
	
	if token_below == null:
		return false
	
	deduct_charges(ability_cost)
	return board.destroy_token(token_below)
