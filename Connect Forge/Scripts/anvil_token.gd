extends Token


func _setup():
	token_type = TokenType.ANVIL
	charges = 1
	ability_cost = 1
	
func _try_to_use_ability()->bool:
	if(check_enough_charges(ability_cost)==false):
		return true # it tried and it can't. True so we find out if the token is resolved.

	#check if there's a token below mine (in the direction of gravity
	
	var token_below = Global.board_pool.get_token_below(token_pos.x,token_pos.y)
	
	if(token_below !=null):#if there is a token
		deduct_charges(ability_cost) # deduct the cost from our charges
		Global.board_pool.remove_token_from_board(token_below.token_pos)
		return false
	else:
		return true
