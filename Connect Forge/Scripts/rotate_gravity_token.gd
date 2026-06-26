extends Token
# Rotate Gravity Token
# Rotates gravity clockwise on land, or anti-clockwise if flipped.

func setup_special_token():
	token_type = TokenType.ROTATE_GRAVITY
	charges = 1
	ability_cost = 1
	keywords = [Global.KEYWORD.ON_LAND]


func _try_to_use_ability() -> bool:
	return false


func _on_land(_context:Dictionary) -> bool:
	if check_enough_charges(ability_cost) == false:
		return false
	
	if board.visuals != null:
		board.visuals.queue_effect(TokenShimmerVisualEffect.new(self))
	
	deduct_charges(ability_cost)
	
	var clockwise:bool = true
	
	if is_flipped:
		clockwise = false
	
	board.rotate_gravity(clockwise)
	
	return true
