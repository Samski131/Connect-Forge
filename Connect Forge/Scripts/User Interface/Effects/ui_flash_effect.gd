class_name UIFlashEffect
extends UIEffect

var flash_color:Color = Color.WHITE
var intensity:float = 1.0

var _start_modulate:Color = Color.WHITE


func _init(new_target:Control, new_flash_color:Color = Color.WHITE, new_intensity:float = 1.0, new_duration:float = 0.22):
	target = new_target
	flash_color = new_flash_color
	intensity = new_intensity
	duration = new_duration


func _play_valid(runner:Node) -> void:
	if target == null:
		_finish()
		return
	
	_start_modulate = target.modulate
	
	var used_flash_color:Color = _start_modulate.lerp(flash_color, intensity)
	var half_duration:float = duration * 0.5
	
	var tween:Tween = runner.create_tween()
	tween.tween_property(target, "modulate", used_flash_color, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate", _start_modulate, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish)


func _finish() -> void:
	if target != null and is_instance_valid(target):
		target.modulate = _start_modulate
	
	super._finish()
