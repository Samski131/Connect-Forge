class_name TokenMoveVisualEffect
extends VisualTweenEffect

var target_global:Vector2
var move_visual:BoardVisualManager.MOVE_VISUAL

var slide_duration:float = 0.12
var min_fall_duration:float = 0.14
var max_fall_duration:float = 0.55
var fall_pixels_per_second:float = 2200.0


func _init(
	new_token:Token,
	new_target_global:Vector2,
	new_move_visual:BoardVisualManager.MOVE_VISUAL
):
	target = new_token
	target_global = new_target_global
	move_visual = new_move_visual


func _play_valid(runner:Node) -> void:
	var token := target as Token
	
	if token == null or is_instance_valid(token) == false:
		_finish()
		return
	
	if move_visual == BoardVisualManager.MOVE_VISUAL.FALL:
		var distance := token.global_position.distance_to(target_global)
		duration = clamp(
			distance / fall_pixels_per_second,
			min_fall_duration,
			max_fall_duration
		)
		trans_type = Tween.TRANS_QUAD
		ease_type = Tween.EASE_IN
	else:
		duration = slide_duration
		trans_type = Tween.TRANS_SINE
		ease_type = Tween.EASE_OUT
	
	super._play_valid(runner)


func _build_tween(tween:Tween) -> void:
	add_property_tween(
		tween,
		target,
		"global_position",
		target_global
	)
