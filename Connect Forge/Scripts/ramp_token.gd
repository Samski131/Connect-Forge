extends Token
#Ramp Token

var wiggle_strength:float = 4.0
var number_of_wiggles:int = 3


func setup_special_token():
	token_type = TokenType.RAMP
	keywords = [Global.KEYWORD.ON_IMPACT]


func _try_to_use_ability() -> bool:
	return false


func _on_impact(_context:Dictionary) -> bool:
	var landing_token:Token = _context.get("landing_token", null)
	
	if landing_token == null:
		return false
	
	
	var drop_direction:BoardSetting.DIRECTION
	if(is_flipped):
		drop_direction = BoardSetting.DIRECTION.RIGHT
	else:
		drop_direction = BoardSetting.DIRECTION.LEFT
	
	var ramp_drop_off_pos = board.get_adjacent_pos(token_pos.x, token_pos.y, drop_direction)
	
	if board.is_position_in_bounds(ramp_drop_off_pos) == false:
		return false
	
	if board.get_token(ramp_drop_off_pos) != null:
		return false
	
	var target_flipped_state:bool = not is_flipped

	var effects:Array[BoardVisualEffect] = [
		WiggleVisualEffect.new(self, wiggle_strength, number_of_wiggles),
		TokenFlipVisualEffect.new(self, target_flipped_state, board.visuals.flip_duration)
	]
	
	return board.move_token_on_board(landing_token, ramp_drop_off_pos, BoardVisualManager.MOVE_VISUAL.SLIDE, effects)
