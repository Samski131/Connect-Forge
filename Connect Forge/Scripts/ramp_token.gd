extends Token
#Ramp Token
var base_token: PackedScene = load("res://Scenes/Tokens/base token.tscn")
func _setup():
	token_type = TokenType.RAMP
	charges = 1
	ability_cost = 0
	
func _try_to_use_ability()->bool:
	if check_enough_charges(ability_cost) == false:
		return true

	var token_above = Global.board_pool.get_adjacent_token(token_pos.x, token_pos.y,BoardSetting.DIRECTION.UP)
	
	if token_above == null:
		return true
	
	var ramp_drop_off_pos = Global.board_pool.get_adjacent_pos(token_pos.x,token_pos.y,BoardSetting.DIRECTION.DOWN_LEFT)
	
	var ramp_drop_off = Global.board_pool.get_token(ramp_drop_off_pos.x,ramp_drop_off_pos.y) #check if there's a token in the drop off slot
	
	if ramp_drop_off != null: # there's no token in the position we want to drop into
		return true
	deduct_charges(ability_cost)
		
	Global.board_pool.move_token_on_board(token_above, ramp_drop_off_pos)
	
	
	return false
