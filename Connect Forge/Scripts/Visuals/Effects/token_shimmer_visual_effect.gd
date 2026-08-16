class_name TokenShimmerVisualEffect
extends BoardVisualEffect

var direction:Vector2 = Vector2(1.0, -1.0)
var strength:float = 0.75


func _init(new_token:Token, new_duration:float = 0.45, new_direction:Vector2 = Vector2(1.0, -1.0), new_strength:float = 0.75):
	target = new_token
	duration = new_duration
	direction = new_direction
	strength = new_strength


func _play_valid(runner:Node) -> void:
	var token:Token = target as Token
	
	if token == null or is_instance_valid(token) == false:
		_finish()
		return
	
	if token.sprites == null:
		_finish()
		return
	
	if token.sprites.has_method("play_shimmer") == false:
		_finish()
		return
	
	token.sprites.play_shimmer(duration, direction, strength)
	
	var timer:SceneTreeTimer = runner.get_tree().create_timer(duration)
	timer.timeout.connect(_finish)


func to_replay_action() -> ReplayAction:
	var token_id:int = get_replay_target_token_id()
	
	if token_id < 0:
		return null
	
	var payload:Dictionary = {
		"token_id": token_id,
		"duration": duration,
		"direction": [direction.x, direction.y],
		"strength": strength
	}
	
	return ReplayAction.create_presentation(ReplayFormat.PRESENTATION_TOKEN_SHIMMER, payload)
