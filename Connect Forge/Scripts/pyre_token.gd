extends Token
#Pyre Token

func setup_special_token():
	token_type = TokenType.PYRE
	charges = 1
	ability_cost = 1
	keywords = [Global.KEYWORD.ON_IMPACT]


func _try_to_use_ability()->bool:
	return false


func _on_impact(context:Dictionary)->bool:
	if check_enough_charges(ability_cost) == false:
		return false
	
	var landing_token:Token = context.get("landing_token", null) #gets the token that landed on the pyre
	
	if landing_token == null:
		return false
	
	deduct_charges(ability_cost)
	board.remove_token_from_board(landing_token.token_pos)
	landing_token.queue_free()
	
	return true
