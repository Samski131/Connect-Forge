class_name TokenDestroyVisualEffect
extends VisualTweenEffect


func _init(new_token:Token, new_duration:float = 0.2):
	target = new_token
	duration = new_duration
	parallel = true
	trans_type = Tween.TRANS_BACK
	ease_type = Tween.EASE_IN


func _build_tween(tween:Tween) -> void:
	add_property_tween(tween, target, "scale", Vector2.ZERO)
	add_property_tween(tween, target, "modulate:a", 0.0)


func to_replay_action() -> ReplayAction:
	var token_id:int = get_replay_target_token_id()
	
	if token_id < 0:
		return null
	
	var payload:Dictionary = {
		"token_id": token_id,
		"duration": duration
	}
	
	return ReplayAction.create_presentation(ReplayFormat.PRESENTATION_TOKEN_DESTROY, payload)


func _finish() -> void:
	if target != null and is_instance_valid(target):
		var node:Node = target as Node
		
		if node != null:
			node.queue_free()
	
	super._finish()
