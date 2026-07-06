class_name ChameleonRevealVisualEffect
extends BoardVisualEffect


func _init(new_token:Token, new_duration:float = 0.55):
	target = new_token
	duration = new_duration


func _play_valid(runner:Node) -> void:
	var token:Token = target as Token
	
	if token == null:
		_finish()
		return
	
	if is_instance_valid(token) == false:
		_finish()
		return
	
	if token.has_method("prepare_chameleon_reveal") == false:
		_finish()
		return
	
	token.prepare_chameleon_reveal()
	
	var tween:Tween = runner.create_tween()
	tween.tween_method(token.set_chameleon_reveal_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_finish_reveal)


func _finish_reveal() -> void:
	var token:Token = target as Token
	
	if token != null and is_instance_valid(token):
		if token.has_method("finish_chameleon_reveal"):
			token.finish_chameleon_reveal()
	
	_finish()
