# res://Scripts/Visuals/Effects/token_destroy_visual_effect.gd
class_name TokenDestroyVisualEffect
extends VisualTweenEffect


func _init(new_token:Token, new_duration:float = 0.2):
	target = new_token
	duration = new_duration
	parallel = true
	trans_type = Tween.TRANS_BACK
	ease_type = Tween.EASE_IN


func _build_tween(tween:Tween) -> void:
	add_property_tween(
		tween,
		target,
		"scale",
		Vector2.ZERO
	)
	
	add_property_tween(
		tween,
		target,
		"modulate:a",
		0.0
	)


func _finish() -> void:
	if target != null and is_instance_valid(target):
		var node := target as Node
		if node != null:
			node.queue_free()
	
	super._finish()
