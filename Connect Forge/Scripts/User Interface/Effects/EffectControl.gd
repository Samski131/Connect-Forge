class_name EffectControl
extends Control

var ui_effect_runner:UIEffectRunner = null


func _ready() -> void:
	ui_effect_runner = get_tree().get_first_node_in_group("ui effect runner") as UIEffectRunner
	setup_offset_transform()


func setup_offset_transform(visual_only:bool = true) -> void:
	offset_transform_enabled = true
	offset_transform_visual_only = visual_only
	offset_transform_pivot = Vector2.ZERO
	offset_transform_pivot_ratio = Vector2(0.5, 0.5)


func reset_offset_transform() -> void:
	offset_transform_position = Vector2.ZERO
	offset_transform_position_ratio = Vector2.ZERO
	offset_transform_scale = Vector2.ONE
	offset_transform_rotation = 0.0
	offset_transform_pivot = Vector2.ZERO
	offset_transform_pivot_ratio = Vector2(0.5, 0.5)


func queue_ui_effect(effect:UIEffect, queued:bool = false) -> void:
	if effect == null:
		return
	
	if ui_effect_runner == null:
		ui_effect_runner = get_tree().get_first_node_in_group("ui effect runner") as UIEffectRunner
	
	if ui_effect_runner == null:
		return
	
	if queued:
		ui_effect_runner.queue_effect(effect)
	else:
		ui_effect_runner.play(effect)


func pulse(intensity:float = 1.12, duration:float = 0.18, queued:bool = false, visual_only:bool = true) -> void:
	queue_ui_effect(UIPulseEffect.new(self, intensity, duration, visual_only), queued)


func flash(flash_color:Color = Color.WHITE, intensity:float = 1.0, duration:float = 0.22, queued:bool = false) -> void:
	queue_ui_effect(UIFlashEffect.new(self, flash_color, intensity, duration), queued)


func whiteout(intensity:float = 0.85, duration:float = 0.22, corner_radius:int = 8, queued:bool = false) -> void:
	queue_ui_effect(UIWhiteOutEffect.new(self, intensity, duration, corner_radius), queued)


func shake(intensity:float = 8.0, duration:float = 0.22, shakes:int = 4, queued:bool = false, visual_only:bool = true) -> void:
	queue_ui_effect(UIShakeEffect.new(self, intensity, duration, shakes, visual_only), queued)


func slide_to_offset(target_offset:Vector2, duration:float = 0.18, queued:bool = false, visual_only:bool = false, trans_type:Tween.TransitionType = Tween.TRANS_SINE, ease_type:Tween.EaseType = Tween.EASE_OUT) -> void:
	queue_ui_effect(UISlideToOffsetEffect.new(self, target_offset, duration, visual_only, trans_type, ease_type), queued)


func slide_home(duration:float = 0.18, queued:bool = false, visual_only:bool = false, trans_type:Tween.TransitionType = Tween.TRANS_SINE, ease_type:Tween.EaseType = Tween.EASE_OUT) -> void:
	slide_to_offset(Vector2.ZERO, duration, queued, visual_only, trans_type, ease_type)


func slide_left(distance:float = 16.0, duration:float = 0.18, queued:bool = false, visual_only:bool = false, trans_type:Tween.TransitionType = Tween.TRANS_SINE, ease_type:Tween.EaseType = Tween.EASE_OUT) -> void:
	slide_to_offset(Vector2(-abs(distance), 0.0), duration, queued, visual_only, trans_type, ease_type)


func slide_right(distance:float = 16.0, duration:float = 0.18, queued:bool = false, visual_only:bool = false, trans_type:Tween.TransitionType = Tween.TRANS_SINE, ease_type:Tween.EaseType = Tween.EASE_OUT) -> void:
	slide_to_offset(Vector2(abs(distance), 0.0), duration, queued, visual_only, trans_type, ease_type)


func slide_up(distance:float = 16.0, duration:float = 0.18, queued:bool = false, visual_only:bool = false, trans_type:Tween.TransitionType = Tween.TRANS_SINE, ease_type:Tween.EaseType = Tween.EASE_OUT) -> void:
	slide_to_offset(Vector2(0.0, -abs(distance)), duration, queued, visual_only, trans_type, ease_type)


func slide_down(distance:float = 16.0, duration:float = 0.18, queued:bool = false, visual_only:bool = false, trans_type:Tween.TransitionType = Tween.TRANS_SINE, ease_type:Tween.EaseType = Tween.EASE_OUT) -> void:
	slide_to_offset(Vector2(0.0, abs(distance)), duration, queued, visual_only, trans_type, ease_type)
