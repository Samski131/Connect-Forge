class_name UIJuice
extends RefCounted


static func play(target:Control, preset:UIJuicePreset) -> UIJuicePlayer:
	if target == null:
		return null
	
	if preset == null:
		return null
	
	var player:UIJuicePlayer = get_or_create_player(target)
	
	if player == null:
		return null
	
	player.play_preset(preset)
	return player


static func get_or_create_player(target:Control) -> UIJuicePlayer:
	if target == null:
		return null
	
	for child in target.get_children():
		var player:UIJuicePlayer = child as UIJuicePlayer
		
		if player != null:
			return player
	
	var new_player:UIJuicePlayer = UIJuicePlayer.new()
	new_player.name = "UI Juice Player"
	target.add_child(new_player)
	new_player.target = target
	new_player.original_modulate = target.modulate
	new_player.original_mouse_filter = target.mouse_filter
	new_player.setup_offset_transform(target)
	
	return new_player


static func create_pulse_preset(scale:float = 1.12, duration:float = 0.18, visual_only:bool = true) -> UIJuicePreset:
	var preset:UIJuicePreset = UIJuicePreset.new()
	preset.play_mode = UIJuicePreset.PlayMode.SEQUENCE
	
	var grow:UIJuiceStep = UIJuiceStep.new()
	grow.step_type = UIJuiceStep.StepType.SCALE
	grow.duration = duration * 0.5
	grow.use_from_value = false
	grow.scale_to = Vector2(scale, scale)
	grow.visual_only = visual_only
	grow.trans_type = Tween.TRANS_BACK
	grow.ease_type = Tween.EASE_OUT
	
	var shrink:UIJuiceStep = UIJuiceStep.new()
	shrink.step_type = UIJuiceStep.StepType.SCALE
	shrink.duration = duration * 0.5
	shrink.use_from_value = false
	shrink.scale_to = Vector2.ONE
	shrink.visual_only = visual_only
	shrink.trans_type = Tween.TRANS_SINE
	shrink.ease_type = Tween.EASE_OUT
	
	preset.steps.append(grow)
	preset.steps.append(shrink)
	
	return preset


static func create_shake_preset(intensity:float = 8.0, duration:float = 0.22, shakes:int = 4, visual_only:bool = true) -> UIJuicePreset:
	var preset:UIJuicePreset = UIJuicePreset.new()
	preset.play_mode = UIJuicePreset.PlayMode.PARALLEL
	
	var shake:UIJuiceStep = UIJuiceStep.new()
	shake.step_type = UIJuiceStep.StepType.SHAKE
	shake.duration = duration
	shake.shake_intensity = intensity
	shake.shake_count = shakes
	shake.visual_only = visual_only
	
	preset.steps.append(shake)
	
	return preset


static func create_modulate_preset(target_modulate:Color, duration:float = 0.2) -> UIJuicePreset:
	var preset:UIJuicePreset = UIJuicePreset.new()
	preset.play_mode = UIJuicePreset.PlayMode.PARALLEL
	
	var modulate_step:UIJuiceStep = UIJuiceStep.new()
	modulate_step.step_type = UIJuiceStep.StepType.MODULATE
	modulate_step.duration = duration
	modulate_step.use_from_value = false
	modulate_step.color_to = target_modulate
	
	preset.steps.append(modulate_step)
	
	return preset


static func create_slide_offset_preset(offset:Vector2, duration:float = 0.18, visual_only:bool = false, trans_type:Tween.TransitionType = Tween.TRANS_SINE, ease_type:Tween.EaseType = Tween.EASE_OUT) -> UIJuicePreset:
	var preset:UIJuicePreset = UIJuicePreset.new()
	preset.play_mode = UIJuicePreset.PlayMode.PARALLEL
	
	var slide:UIJuiceStep = UIJuiceStep.new()
	slide.step_type = UIJuiceStep.StepType.OFFSET_POSITION
	slide.duration = duration
	slide.use_from_value = false
	slide.vector_to = offset
	slide.visual_only = visual_only
	slide.trans_type = trans_type
	slide.ease_type = ease_type
	
	preset.steps.append(slide)
	
	return preset
