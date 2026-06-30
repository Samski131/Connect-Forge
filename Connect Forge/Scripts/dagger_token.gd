extends Token
# Dagger Token
# Destroys a token that passes on this token's right side.

func setup_special_token():
	token_type = TokenLibrary.TokenType.DAGGER
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
	
	queue_visual_effect(TokenShimmerVisualEffect.new(self))
	deduct_charges(ability_cost)
	
	return board.destroy_token(moving_token)


func _can_trigger_keyword(keyword:Global.KEYWORD, context:Dictionary = {})->bool:
	if keyword != Global.KEYWORD.ON_PASS_RIGHT:
		return false
	
	if check_enough_charges(ability_cost) == false:
		return false
	
	var moving_token:Token = context.get("moving_token", null)
	
	if moving_token == null:
		return false
	
	if moving_token.being_destroyed:
		return false
	
	return true
