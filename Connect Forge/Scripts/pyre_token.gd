extends Token
# Pyre Token

func setup_special_token():
	token_type = TokenLibrary.TokenType.PYRE
	charges = 1
	ability_cost = 1
	keywords = [Global.KEYWORD.ON_IMPACT]


func _try_to_use_ability()->bool:
	return false


func _on_impact(context:Dictionary)->bool:
	if check_enough_charges(ability_cost) == false:
		return false
	
	var landing_token:Token = context.get("landing_token", null)
	
	if landing_token == null:
		return false
	
	queue_visual_effect(TokenShimmerVisualEffect.new(self))
	deduct_charges(ability_cost)
	
	return board.destroy_token(landing_token)
