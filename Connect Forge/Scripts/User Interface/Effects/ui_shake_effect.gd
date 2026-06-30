class_name UIShakeEffect
extends UIEffect

var intensity:float = 8.0
var shakes:int = 4

var _start_position:Vector2 = Vector2.ZERO


func _init(new_target:Control, new_intensity:float = 8.0, new_duration:float = 0.22, new_shakes:int = 4):
	target = new_target
	intensity = new_intensity
	duration = new_duration
	shakes = new_shakes


func _play_valid(runner:Node) -> void:
	if target == null:
		_finish()
		return
	
	_start_position = target.position
	
	var total_steps:int = max(shakes * 2, 1)
	var step_duration:float = duration / float(total_steps)
	
	var tween:Tween = runner.create_tween()
	
	for i in range(shakes):
		tween.tween_property(target, "position:x", _start_position.x + intensity, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(target, "position:x", _start_position.x - intensity, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(target, "position", _start_position, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish)


func _finish() -> void:
	if target != null and is_instance_valid(target):
		target.position = _start_position
	
	super._finish()
