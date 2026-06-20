# res://Scripts/Visuals/Effects/token_shimmer_visual_effect.gd
class_name TokenShimmerVisualEffect
extends BoardVisualEffect

var direction:Vector2 = Vector2(1.0, -1.0)
var strength:float = 0.75


func _init(
	new_token:Token,
	new_duration:float = 0.45,
	new_direction:Vector2 = Vector2(1.0, -1.0),
	new_strength:float = 0.75
):
	target = new_token
	duration = new_duration
	direction = new_direction
	strength = new_strength


func _play_valid(runner:Node) -> void:
	var token := target as Token
	
	if token == null or is_instance_valid(token) == false:
		_finish()
		return
	
	token.play_shimmer(duration, direction, strength)
	
	var timer := runner.get_tree().create_timer(duration)
	timer.timeout.connect(_finish)
