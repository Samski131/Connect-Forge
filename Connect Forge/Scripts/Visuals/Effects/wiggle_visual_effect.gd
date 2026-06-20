class_name WiggleVisualEffect
extends VisualTweenEffect

var angle:float = 8.0
var wiggles:int = 3


func _init(
	new_target:Node2D,
	new_angle:float = 8.0,
	new_wiggles:int = 3,
	new_duration:float = 0.25
):
	target = new_target
	angle = new_angle
	wiggles = new_wiggles
	duration = new_duration
	
	parallel = false
	trans_type = Tween.TRANS_SINE
	ease_type = Tween.EASE_IN_OUT


func _build_tween(tween:Tween) -> void:
	var node := target as Node2D
	
	if node == null:
		return
	
	var start_rotation := node.rotation
	var step_duration := duration / float(max(wiggles * 2, 1))
	
	for i in range(wiggles):
		add_property_tween(
			tween,
			node,
			"rotation",
			start_rotation + deg_to_rad(angle),
			step_duration
		)
		
		add_property_tween(
			tween,
			node,
			"rotation",
			start_rotation - deg_to_rad(angle),
			step_duration
		)
	
	add_property_tween(
		tween,
		node,
		"rotation",
		start_rotation,
		step_duration
	)
