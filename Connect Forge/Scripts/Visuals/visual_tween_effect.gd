class_name VisualTweenEffect
extends BoardVisualEffect

var trans_type:Tween.TransitionType = Tween.TRANS_SINE
var ease_type:Tween.EaseType = Tween.EASE_OUT
var parallel:bool = false

var _tween_count:int = 0


func _play_valid(runner:Node) -> void:
	_tween_count = 0
	
	var tween := runner.create_tween()
	tween.set_parallel(parallel)
	
	_build_tween(tween)
	
	if _tween_count <= 0:
		tween.kill()
		_finish()
		return
	
	tween.finished.connect(_finish)


func _build_tween(_tween:Tween) -> void:
	pass


func add_property_tween(tween:Tween,object:Object,property:String,final_value, custom_duration:float = -1.0):
	if object == null:
		return null
	
	if is_instance_valid(object) == false:
		return null
	
	var used_duration := duration
	
	if custom_duration >= 0.0:
		used_duration = custom_duration
	
	var tweener := tween.tween_property(
		object,
		property,
		final_value,
		used_duration
	)
	
	tweener.set_trans(trans_type)
	tweener.set_ease(ease_type)
	
	_tween_count += 1
	
	return tweener
