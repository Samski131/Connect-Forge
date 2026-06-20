extends Token
# Dagger Token
# Destroys a token that passes on this token's right side.

func setup_special_token():
	token_type = TokenType.DAGGER
	charges = 1
	ability_cost = 1
	keywords = [Global.KEYWORD.ON_PASS_RIGHT]


func _try_to_use_ability()->bool:
	return false


func _on_pass_right(context:Dictionary)->bool:
	if check_enough_charges(ability_cost) == false:
		return false
	
	var moving_token:Token = context.get("moving_token", null)
	
	if moving_token == null:
		return false
	
	if board.get_token(moving_token.token_pos) != moving_token:
		return false
	
	deduct_charges(ability_cost)
	board.remove_token_from_board(moving_token.token_pos)
	moving_token.queue_free()
	
	return true
