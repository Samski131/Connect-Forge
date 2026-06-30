class_name UIWhiteOutEffect
extends UIEffect

var intensity:float = 0.85
var corner_radius:int = 8

var _overlay:Panel = null


func _init(new_target:Control, new_intensity:float = 0.85, new_duration:float = 0.22, new_corner_radius:int = 8):
	target = new_target
	intensity = new_intensity
	duration = new_duration
	corner_radius = new_corner_radius


func _play_valid(runner:Node) -> void:
	if target == null:
		_finish()
		return
	
	_overlay = Panel.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style:StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	
	_overlay.add_theme_stylebox_override("panel", style)
	
	target.add_child(_overlay)
	target.move_child(_overlay, target.get_child_count() - 1)
	
	var half_duration:float = duration * 0.5
	
	var tween:Tween = runner.create_tween()
	tween.tween_property(_overlay, "modulate:a", intensity, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "modulate:a", 0.0, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish)


func _finish() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	
	_overlay = null
	
	super._finish()
