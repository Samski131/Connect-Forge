class_name TokenGravityAlignVisualEffect
extends VisualTweenEffect

var target_rotation_degrees:float = 0.0


func _init(new_token:Token, new_target_rotation_degrees:float, new_duration:float = 0.18):
	target = new_token
	target_rotation_degrees = new_target_rotation_degrees
	duration = new_duration
	
	trans_type = Tween.TRANS_SINE
	ease_type = Tween.EASE_OUT


func _build_tween(tween:Tween) -> void:
	var token:Token = target as Token
	
	if token == null:
		return
	
	if token.sprites == null:
		return
	
	token.gravity_visual_rotation_degrees = target_rotation_degrees
	
	add_property_tween(
		tween,
		token.sprites,
		"rotation_degrees",
		target_rotation_degrees
	)
