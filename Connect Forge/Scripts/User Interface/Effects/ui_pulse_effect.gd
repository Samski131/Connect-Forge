class_name UIPulseEffect
extends UIEffect

const ACTIVE_TWEEN_META:String = "_active_ui_pulse_tween"

var intensity:float = 1.12
var visual_only:bool = true


func _init(new_target:Control, new_intensity:float = 1.12, new_duration:float = 0.18, new_visual_only:bool = true):
	target = new_target
	intensity = new_intensity
	duration = new_duration
	visual_only = new_visual_only


func _play_valid(runner:Node) -> void:
	if target == null:
		_finish()
		return
	
	_enable_offset_transform(target, visual_only)
	_restart_pulse()
	
	var half_duration:float = duration * 0.5
	var pulse_scale:Vector2 = Vector2.ONE * intensity
	
	var tween:Tween = runner.create_tween()
	target.set_meta(ACTIVE_TWEEN_META, tween)
	
	tween.tween_property(target, "offset_transform_scale", pulse_scale, half_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "offset_transform_scale", Vector2.ONE, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_tween_finished.bind(tween))


func _restart_pulse() -> void:
	if target.has_meta(ACTIVE_TWEEN_META):
		var existing_tween:Tween = target.get_meta(ACTIVE_TWEEN_META) as Tween
		
		if existing_tween != null:
			if existing_tween.is_valid():
				existing_tween.kill()
		
		target.remove_meta(ACTIVE_TWEEN_META)
	
	target.offset_transform_scale = Vector2.ONE
	target.offset_transform_pivot = Vector2.ZERO
	target.offset_transform_pivot_ratio = Vector2(0.5, 0.5)


func _on_tween_finished(tween:Tween) -> void:
	if target != null and is_instance_valid(target):
		if target.has_meta(ACTIVE_TWEEN_META):
			var active_tween:Tween = target.get_meta(ACTIVE_TWEEN_META) as Tween
			
			if active_tween == tween:
				target.remove_meta(ACTIVE_TWEEN_META)
		
		target.offset_transform_scale = Vector2.ONE
	
	_finish()
