extends Token
#Anvil Token

func _setup():
	token_type = TokenType.PYRE
	charges = 1
	ability_cost = 1
	
func _try_to_use_ability()->bool:
	if(check_enough_charges(ability_cost)==false):
		return true # it tried and it can't. True so we find out if the token is resolved.

	#check if there's a token below this token (in the direction of gravity)
	var token_above = Global.board_pool.get_adjacent_token(token_pos.x,token_pos.y, BoardSetting.DIRECTION.UP)
	
	if(token_above !=null):#if there is a token
		deduct_charges(ability_cost) # deduct the cost from our charges
		
		Global.board_pool.remove_token_from_board(token_above.token_pos)
		token_above.queue_free()
		return false
	else:
		return true
