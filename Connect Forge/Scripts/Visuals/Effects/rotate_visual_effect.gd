class_name RotateVisualEffect
extends VisualTweenEffect

var rotation_amount:float = TAU


func _init(
	new_target:Node2D,
	new_rotation_amount:float = TAU,
	new_duration:float = 0.25
):
	target = new_target
	rotation_amount = new_rotation_amount
	duration = new_duration
	
	trans_type = Tween.TRANS_SINE
	ease_type = Tween.EASE_IN_OUT


func _build_tween(tween:Tween) -> void:
	var node := target as Node2D
	
	if node == null:
		return
	
	add_property_tween(
		tween,
		node,
		"rotation",
		node.rotation + rotation_amount
	)
