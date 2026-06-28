extends Token
# Drill Token
# Destroys the token below it when it lands, then keeps falling.

var drill_wiggle_strength:float = 14.0
var drill_wiggles:int = 5
var drill_wiggle_duration:float = 0.28


func setup_special_token():
	token_type = TokenType.DRILL
	keywords = [Global.KEYWORD.ON_LAND]


func _try_to_use_ability() -> bool:
	return false


func _on_land(_context:Dictionary) -> bool:
	var token_below:Token = board.get_relative_adjacent_token(token_pos.x, token_pos.y, BoardSetting.RELATIVE_DIRECTION.DOWN)
	
	if token_below == null:
		return false
	
	var effects:Array[BoardVisualEffect] = [
		TokenShimmerVisualEffect.new(self),
		WiggleVisualEffect.new(token_below, drill_wiggle_strength, drill_wiggles, drill_wiggle_duration)
	]
	
	queue_visual_effect(ParallelVisualEffect.new(effects))
	landed = false
	
	return board.destroy_token(token_below)
