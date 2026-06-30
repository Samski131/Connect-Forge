class_name UISlideToOffsetEffect
extends UIEffect

const ACTIVE_TWEEN_META:String = "_active_ui_slide_to_offset_tween"

var target_offset:Vector2 = Vector2.ZERO
var visual_only:bool = false
var trans_type:Tween.TransitionType = Tween.TRANS_SINE
var ease_type:Tween.EaseType = Tween.EASE_OUT


func _init(new_target:Control, new_target_offset:Vector2 = Vector2.ZERO, new_duration:float = 0.18, new_visual_only:bool = false, new_trans_type:Tween.TransitionType = Tween.TRANS_SINE, new_ease_type:Tween.EaseType = Tween.EASE_OUT):
	target = new_target
	target_offset = new_target_offset
	duration = new_duration
	visual_only = new_visual_only
	trans_type = new_trans_type
	ease_type = new_ease_type


func _play_valid(runner:Node) -> void:
	if target == null:
		_finish()
		return
	
	target.offset_transform_enabled = true
	target.offset_transform_visual_only = visual_only
	target.offset_transform_position_ratio = Vector2.ZERO
	
	_kill_existing_slide_tween()
	
	var tween:Tween = runner.create_tween()
	target.set_meta(ACTIVE_TWEEN_META, tween)
	
	tween.tween_property(target, "offset_transform_position", target_offset, duration).set_trans(trans_type).set_ease(ease_type)
	tween.finished.connect(_on_tween_finished.bind(tween))


func _kill_existing_slide_tween() -> void:
	if target == null:
		return
	
	if target.has_meta(ACTIVE_TWEEN_META) == false:
		return
	
	var existing_tween:Tween = target.get_meta(ACTIVE_TWEEN_META) as Tween
	
	if existing_tween != null:
		if existing_tween.is_valid():
			existing_tween.kill()
	
	target.remove_meta(ACTIVE_TWEEN_META)


func _on_tween_finished(tween:Tween) -> void:
	if target != null and is_instance_valid(target):
		if target.has_meta(ACTIVE_TWEEN_META):
			var active_tween:Tween = target.get_meta(ACTIVE_TWEEN_META) as Tween
			
			if active_tween == tween:
				target.remove_meta(ACTIVE_TWEEN_META)
	
	_finish()
