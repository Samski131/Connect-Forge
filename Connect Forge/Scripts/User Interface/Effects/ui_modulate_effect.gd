class_name UIModulateEffect
extends UIEffect

const ACTIVE_TWEEN_META:String = "_active_ui_modulate_tween"

var target_modulate:Color = Color.WHITE
var trans_type:Tween.TransitionType = Tween.TRANS_SINE
var ease_type:Tween.EaseType = Tween.EASE_OUT


func _init(new_target:Control, new_target_modulate:Color = Color.WHITE, new_duration:float = 0.2, new_trans_type:Tween.TransitionType = Tween.TRANS_SINE, new_ease_type:Tween.EaseType = Tween.EASE_OUT):
	target = new_target
	target_modulate = new_target_modulate
	duration = new_duration
	trans_type = new_trans_type
	ease_type = new_ease_type


func _play_valid(runner:Node) -> void:
	if target == null:
		_finish()
		return
	
	_kill_existing_modulate_tween()
	
	if duration <= 0.0:
		target.modulate = target_modulate
		_finish()
		return
	
	var tween:Tween = runner.create_tween()
	target.set_meta(ACTIVE_TWEEN_META, tween)
	
	tween.tween_property(target, "modulate", target_modulate, duration).set_trans(trans_type).set_ease(ease_type)
	tween.finished.connect(_on_tween_finished.bind(tween))


func _kill_existing_modulate_tween() -> void:
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
