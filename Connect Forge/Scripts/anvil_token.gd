extends Token
#Anvil Token

func _setup():
	token_type = TokenType.ANVIL
	charges = 1
	ability_cost = 1
	
func _try_to_use_ability()->bool:
	#return true if it works and changes the board.
	#return false if it fails to activate for any reason
	if(check_enough_charges(ability_cost)==false):
		return false # it tried and it can't. True so we find out if the token is resolved.

	#check if there's a token below this token (in the direction of gravity)
	var token_below = Global.board_pool.get_adjacent_token(token_pos.x,token_pos.y, BoardSetting.DIRECTION.DOWN)
	
	if(token_below !=null):#if there is a token
		deduct_charges(ability_cost) # deduct the cost from our charges
		Global.board_pool.remove_token_from_board(token_below.token_pos)
		token_below.queue_free()
		return true
	else:
		return false
