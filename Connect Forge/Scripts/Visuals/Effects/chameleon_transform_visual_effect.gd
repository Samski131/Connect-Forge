class_name ChameleonTransformVisualEffect
extends BoardVisualEffect

var fake_player_id:int = -1


func _init(new_token:Token, new_fake_player_id:int, new_duration:float = 0.55):
	target = new_token
	fake_player_id = new_fake_player_id
	duration = new_duration


func _play_valid(runner:Node) -> void:
	var token:Token = target as Token
	
	if token == null:
		_finish()
		return
	
	if token.has_method("prepare_chameleon_transform") == false:
		_finish()
		return
	
	token.prepare_chameleon_transform(fake_player_id)
	
	var tween:Tween = runner.create_tween()
	tween.tween_method(token.set_chameleon_dissolve_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_finish_transform)


func _finish_transform() -> void:
	var token:Token = target as Token
	
	if token != null and is_instance_valid(token):
		if token.has_method("finish_chameleon_transform"):
			token.finish_chameleon_transform()
	
	_finish()
