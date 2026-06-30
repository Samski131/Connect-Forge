class_name UIPulseEffect
extends UIEffect

var intensity:float = 1.12

var _start_scale:Vector2 = Vector2.ONE
var _start_pivot:Vector2 = Vector2.ZERO


func _init(new_target:Control, new_intensity:float = 1.12, new_duration:float = 0.18):
	target = new_target
	intensity = new_intensity
	duration = new_duration


func _play_valid(runner:Node) -> void:
	if target == null:
		_finish()
		return
	
	_start_scale = target.scale
	_start_pivot = target.pivot_offset
	
	target.pivot_offset = target.size * 0.5
	
	var half_duration:float = duration * 0.5
	var pulse_scale:Vector2 = _start_scale * intensity
	
	var tween:Tween = runner.create_tween()
	tween.tween_property(target, "scale", pulse_scale, half_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", _start_scale, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish)


func _finish() -> void:
	if target != null and is_instance_valid(target):
		target.scale = _start_scale
		target.pivot_offset = _start_pivot
	
	super._finish()
