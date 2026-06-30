class_name UIShakeEffect
extends UIEffect

const ACTIVE_TWEEN_META:String = "_active_ui_shake_tween"

var intensity:float = 8.0
var shakes:int = 4
var visual_only:bool = true


func _init(new_target:Control, new_intensity:float = 8.0, new_duration:float = 0.22, new_shakes:int = 4, new_visual_only:bool = true):
	target = new_target
	intensity = new_intensity
	duration = new_duration
	shakes = new_shakes
	visual_only = new_visual_only


func _play_valid(runner:Node) -> void:
	if target == null:
		_finish()
		return
	
	_enable_offset_transform(target, visual_only)
	_restart_shake()
	
	if duration <= 0.0:
		target.offset_transform_position = Vector2.ZERO
		_finish()
		return
	
	var total_steps:int = max(shakes * 2 + 1, 1)
	var step_duration:float = duration / float(total_steps)
	var right_offset:Vector2 = Vector2(intensity, 0.0)
	var left_offset:Vector2 = Vector2(-intensity, 0.0)
	
	var tween:Tween = runner.create_tween()
	target.set_meta(ACTIVE_TWEEN_META, tween)
	
	for i in range(shakes):
		tween.tween_property(target, "offset_transform_position", right_offset, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(target, "offset_transform_position", left_offset, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(target, "offset_transform_position", Vector2.ZERO, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_tween_finished.bind(tween))


func _restart_shake() -> void:
	if target.has_meta(ACTIVE_TWEEN_META):
		var existing_tween:Tween = target.get_meta(ACTIVE_TWEEN_META) as Tween
		
		if existing_tween != null:
			if existing_tween.is_valid():
				existing_tween.kill()
		
		target.remove_meta(ACTIVE_TWEEN_META)
	
	target.offset_transform_position = Vector2.ZERO
	target.offset_transform_position_ratio = Vector2.ZERO


func _on_tween_finished(tween:Tween) -> void:
	if target != null and is_instance_valid(target):
		if target.has_meta(ACTIVE_TWEEN_META):
			var active_tween:Tween = target.get_meta(ACTIVE_TWEEN_META) as Tween
			
			if active_tween == tween:
				target.remove_meta(ACTIVE_TWEEN_META)
		
		target.offset_transform_position = Vector2.ZERO
	
	_finish()
