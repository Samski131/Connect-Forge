extends Token
#Ramp Token
var base_token: PackedScene = load("res://Scenes/Tokens/base token.tscn")
func _setup():
	token_type = TokenType.RAMP
	charges = 1
	ability_cost = 1
	
func _try_to_use_ability()->bool:
	if(check_enough_charges(ability_cost)==false):
		return true # it tried and it can't. True so we find out if the token is resolved.

	#check if there's a token below this token (in the direction of gravity)
	var token_above = Global.board_pool.get_adjacent_token(token_pos.x,token_pos.y, BoardSetting.DIRECTION.UP)
	
	if(token_above !=null):#if there is a token

		var ramp_drop_off = Global.board_pool.get_adjacent_token(token_pos.x,token_pos.y, BoardSetting.DIRECTION.DOWN_LEFT)
		var ramp_drop_off_pos = token_above.token_pos + Global.board_settings.displacement_direction.values()[BoardSetting.DIRECTION.DOWN_LEFT]

		if(ramp_drop_off ==null): #if there's an empty space where the ramp should drop

			#add copy of token
			Global.board_pool.create_new_token(base_token, ramp_drop_off_pos)
			
			#destroy old token
			Global.board_pool.remove_token_from_board(token_above.token_pos)
			token_above.queue_free()
		
		return false
	else:
		return true
