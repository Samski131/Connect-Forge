class_name WiggleVisualEffect
extends VisualTweenEffect

var angle:float = 8.0
var wiggles:int = 3


func _init(new_target:Node2D, new_angle:float = 8.0, new_wiggles:int = 3, new_duration:float = 0.25):
	target = new_target
	angle = new_angle
	wiggles = new_wiggles
	duration = new_duration
	
	parallel = false
	trans_type = Tween.TRANS_SINE
	ease_type = Tween.EASE_IN_OUT


func _build_tween(tween:Tween) -> void:
	var node:Node2D = target as Node2D
	
	if node == null:
		return
	
	var start_rotation:float = node.rotation
	var step_duration:float = duration / float(max(wiggles * 2, 1))
	
	for i in range(wiggles):
		add_property_tween(tween, node, "rotation", start_rotation + deg_to_rad(angle), step_duration)
		add_property_tween(tween, node, "rotation", start_rotation - deg_to_rad(angle), step_duration)
	
	add_property_tween(tween, node, "rotation", start_rotation, step_duration)


func to_replay_action() -> ReplayAction:
	var token_id:int = get_replay_target_token_id()
	
	if token_id < 0:
		return null
	
	var payload:Dictionary = {
		"token_id": token_id,
		"angle_degrees": angle,
		"wiggles": wiggles,
		"duration": duration
	}
	
	return ReplayAction.create_presentation(ReplayFormat.PRESENTATION_WIGGLE, payload)
