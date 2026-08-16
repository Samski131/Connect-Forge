class_name TokenFlipVisualEffect
extends BoardVisualEffect

var new_is_flipped:bool = false
var min_scale_x:float = 0.08
var pop_scale_y:float = 1.5

var _runner:Node
var _token:Token
var _sprites:Node2D
var _start_scale:Vector2


func _init(new_token:Token, target_flipped:bool, new_duration:float = 0.28):
	target = new_token
	new_is_flipped = target_flipped
	duration = new_duration


func _play_valid(runner:Node) -> void:
	_runner = runner
	_token = target as Token
	
	if _token == null:
		_finish()
		return
	
	if is_instance_valid(_token) == false:
		_finish()
		return
	
	_sprites = _token.sprites as Node2D
	
	if _sprites == null:
		_token.set_flipped(new_is_flipped)
		_finish()
		return
	
	_start_scale = _sprites.scale
	
	var half_duration:float = duration * 0.5
	var squash_scale:Vector2 = Vector2(min_scale_x, _start_scale.y * pop_scale_y)
	var tween:Tween = runner.create_tween()
	
	tween.tween_property(_sprites, "scale", squash_scale, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_swap_side)
	tween.tween_property(_sprites, "scale", _start_scale, half_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish)


func _swap_side() -> void:
	if _token == null:
		return
	
	if is_instance_valid(_token) == false:
		return
	
	_token.set_flipped(new_is_flipped)


func to_replay_action() -> ReplayAction:
	var token_id:int = get_replay_target_token_id()
	
	if token_id < 0:
		return null
	
	var payload:Dictionary = {
		"token_id": token_id,
		"flipped": new_is_flipped,
		"duration": duration,
		"min_scale_x": min_scale_x,
		"pop_scale_y": pop_scale_y
	}
	
	return ReplayAction.create_presentation(ReplayFormat.PRESENTATION_TOKEN_FLIP, payload)
