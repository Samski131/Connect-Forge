class_name UIJuiceStep
extends Resource

enum StepType {
	WAIT,
	FADE,
	MODULATE,
	OFFSET_POSITION,
	SCALE,
	ROTATE,
	SHAKE,
	WHITEOUT,
	CALL_METHOD,
	CHILD_STAGGER
}

enum TargetMode {
	MAIN_TARGET,
	NODE_PATH,
	CHILDREN_OF_NODE_PATH
}

@export var step_type:StepType = StepType.FADE
@export var target_mode:TargetMode = TargetMode.MAIN_TARGET
@export var target_path:NodePath

@export_group("Timing")
@export var delay:float = 0.0
@export var duration:float = 0.2
@export var trans_type:Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type:Tween.EaseType = Tween.EASE_OUT

@export_group("Start / End Values")
@export var use_from_value:bool = true
@export var float_from:float = 0.0
@export var float_to:float = 1.0
@export var vector_from:Vector2 = Vector2.ZERO
@export var vector_to:Vector2 = Vector2.ZERO
@export var scale_from:Vector2 = Vector2.ONE
@export var scale_to:Vector2 = Vector2.ONE
@export var color_from:Color = Color.WHITE
@export var color_to:Color = Color.WHITE

@export_group("Offset Transform")
@export var visual_only:bool = false
@export var pivot_ratio:Vector2 = Vector2(0.5, 0.5)

@export_group("Shake")
@export var shake_intensity:float = 8.0
@export var shake_count:int = 4

@export_group("Whiteout")
@export var whiteout_intensity:float = 0.85
@export var whiteout_color:Color = Color.WHITE
@export var whiteout_corner_radius:int = 8

@export_group("Call Method")
@export var method_name:String = ""
@export var method_arguments:Array = []

@export_group("Child Stagger")
@export var child_stagger_delay:float = 0.04
@export var include_invisible_children:bool = false


func get_total_duration() -> float:
	if step_type == StepType.SHAKE:
		return delay + duration
	
	if step_type == StepType.WHITEOUT:
		return delay + duration
	
	if step_type == StepType.CHILD_STAGGER:
		return delay + duration
	
	return delay + duration


func add_to_tween(tween:Tween, player:Node, main_target:Control, start_time:float) -> int:
	if tween == null:
		return 0
	
	if player == null:
		return 0
	
	if main_target == null:
		return 0
	
	var targets:Array[Control] = get_targets(player, main_target)
	
	if step_type == StepType.WAIT:
		var interval = tween.tween_interval(duration)
		interval.set_delay(start_time + delay)
		return 1
	
	if step_type == StepType.CALL_METHOD:
		return add_call_method_tween(tween, targets, start_time)
	
	if step_type == StepType.CHILD_STAGGER:
		return add_child_stagger_tweens(tween, player, main_target, start_time)
	
	var count:int = 0
	
	for target in targets:
		if target == null:
			continue
		
		if is_instance_valid(target) == false:
			continue
		
		count += add_target_tweens(tween, player, target, start_time)
	
	return count


func get_targets(player:Node, main_target:Control) -> Array[Control]:
	var targets:Array[Control] = []
	
	if target_mode == TargetMode.MAIN_TARGET:
		if main_target != null:
			targets.append(main_target)
		
		return targets
	
	var resolved_node:Node = null
	
	if target_path != NodePath(""):
		resolved_node = player.get_node_or_null(target_path)
	
	if resolved_node == null:
		return targets
	
	if target_mode == TargetMode.NODE_PATH:
		var control:Control = resolved_node as Control
		
		if control != null:
			targets.append(control)
		
		return targets
	
	if target_mode == TargetMode.CHILDREN_OF_NODE_PATH:
		for child in resolved_node.get_children():
			var child_control:Control = child as Control
			
			if child_control == null:
				continue
			
			if include_invisible_children == false:
				if child_control.visible == false:
					continue
			
			targets.append(child_control)
	
	return targets


func add_target_tweens(tween:Tween, player:Node, target:Control, start_time:float) -> int:
	match step_type:
		StepType.FADE:
			return add_fade_tween(tween, target, start_time)
		
		StepType.MODULATE:
			return add_modulate_tween(tween, target, start_time)
		
		StepType.OFFSET_POSITION:
			return add_offset_position_tween(tween, target, start_time)
		
		StepType.SCALE:
			return add_scale_tween(tween, target, start_time)
		
		StepType.ROTATE:
			return add_rotate_tween(tween, target, start_time)
		
		StepType.SHAKE:
			return add_shake_tween(tween, target, start_time)
		
		StepType.WHITEOUT:
			return add_whiteout_tween(tween, player, target, start_time)
	
	return 0


func add_fade_tween(tween:Tween, target:Control, start_time:float) -> int:
	if use_from_value:
		var setup_callable:Callable = Callable(self, "set_control_alpha").bind(target, float_from)
		var setup_tweener = tween.tween_callback(setup_callable)
		setup_tweener.set_delay(start_time + delay)
	
	var tweener = tween.tween_property(target, "modulate:a", float_to, duration)
	tweener.set_delay(start_time + delay + 0.001)
	tweener.set_trans(trans_type)
	tweener.set_ease(ease_type)
	
	return 1


func add_modulate_tween(tween:Tween, target:Control, start_time:float) -> int:
	if use_from_value:
		var setup_callable:Callable = Callable(self, "set_control_modulate").bind(target, color_from)
		var setup_tweener = tween.tween_callback(setup_callable)
		setup_tweener.set_delay(start_time + delay)
	
	var tweener = tween.tween_property(target, "modulate", color_to, duration)
	tweener.set_delay(start_time + delay + 0.001)
	tweener.set_trans(trans_type)
	tweener.set_ease(ease_type)
	
	return 1


func add_offset_position_tween(tween:Tween, target:Control, start_time:float) -> int:
	prepare_offset_transform(target)
	
	if use_from_value:
		var setup_callable:Callable = Callable(self, "set_offset_position").bind(target, vector_from)
		var setup_tweener = tween.tween_callback(setup_callable)
		setup_tweener.set_delay(start_time + delay)
	
	var tweener = tween.tween_property(target, "offset_transform_position", vector_to, duration)
	tweener.set_delay(start_time + delay + 0.001)
	tweener.set_trans(trans_type)
	tweener.set_ease(ease_type)
	
	return 1


func add_scale_tween(tween:Tween, target:Control, start_time:float) -> int:
	prepare_offset_transform(target)
	target.offset_transform_pivot_ratio = pivot_ratio
	
	if use_from_value:
		var setup_callable:Callable = Callable(self, "set_offset_scale").bind(target, scale_from)
		var setup_tweener = tween.tween_callback(setup_callable)
		setup_tweener.set_delay(start_time + delay)
	
	var tweener = tween.tween_property(target, "offset_transform_scale", scale_to, duration)
	tweener.set_delay(start_time + delay + 0.001)
	tweener.set_trans(trans_type)
	tweener.set_ease(ease_type)
	
	return 1


func add_rotate_tween(tween:Tween, target:Control, start_time:float) -> int:
	prepare_offset_transform(target)
	target.offset_transform_pivot_ratio = pivot_ratio
	
	if use_from_value:
		var setup_callable:Callable = Callable(self, "set_offset_rotation_degrees").bind(target, float_from)
		var setup_tweener = tween.tween_callback(setup_callable)
		setup_tweener.set_delay(start_time + delay)
	
	var target_radians:float = deg_to_rad(float_to)
	var tweener = tween.tween_property(target, "offset_transform_rotation", target_radians, duration)
	tweener.set_delay(start_time + delay + 0.001)
	tweener.set_trans(trans_type)
	tweener.set_ease(ease_type)
	
	return 1


func add_shake_tween(tween:Tween, target:Control, start_time:float) -> int:
	prepare_offset_transform(target)
	
	var setup_callable:Callable = Callable(self, "set_offset_position").bind(target, Vector2.ZERO)
	var setup_tweener = tween.tween_callback(setup_callable)
	setup_tweener.set_delay(start_time + delay)
	
	var total_steps:int = max(shake_count * 2 + 1, 1)
	var step_duration:float = duration / float(total_steps)
	var current_delay:float = start_time + delay + 0.001
	
	for i in range(shake_count):
		var right_tweener = tween.tween_property(target, "offset_transform_position", Vector2(shake_intensity, 0.0), step_duration)
		right_tweener.set_delay(current_delay)
		right_tweener.set_trans(Tween.TRANS_SINE)
		right_tweener.set_ease(Tween.EASE_IN_OUT)
		current_delay += step_duration
		
		var left_tweener = tween.tween_property(target, "offset_transform_position", Vector2(-shake_intensity, 0.0), step_duration)
		left_tweener.set_delay(current_delay)
		left_tweener.set_trans(Tween.TRANS_SINE)
		left_tweener.set_ease(Tween.EASE_IN_OUT)
		current_delay += step_duration
	
	var home_tweener = tween.tween_property(target, "offset_transform_position", Vector2.ZERO, step_duration)
	home_tweener.set_delay(current_delay)
	home_tweener.set_trans(Tween.TRANS_SINE)
	home_tweener.set_ease(Tween.EASE_OUT)
	
	return 1


func add_whiteout_tween(tween:Tween, _player:Node, target:Control, start_time:float) -> int:
	var overlay:Panel = create_whiteout_overlay(target)
	
	if overlay == null:
		return 0
	
	var half_duration:float = duration * 0.5
	
	var up_tweener = tween.tween_property(overlay, "modulate:a", whiteout_intensity, half_duration)
	up_tweener.set_delay(start_time + delay)
	up_tweener.set_trans(Tween.TRANS_SINE)
	up_tweener.set_ease(Tween.EASE_OUT)
	
	var down_tweener = tween.tween_property(overlay, "modulate:a", 0.0, half_duration)
	down_tweener.set_delay(start_time + delay + half_duration)
	down_tweener.set_trans(Tween.TRANS_SINE)
	down_tweener.set_ease(Tween.EASE_OUT)
	
	var remove_callable:Callable = Callable(self, "remove_whiteout_overlay").bind(overlay)
	var remove_tweener = tween.tween_callback(remove_callable)
	remove_tweener.set_delay(start_time + delay + duration + 0.001)
	
	return 1


func add_call_method_tween(tween:Tween, targets:Array[Control], start_time:float) -> int:
	if method_name == "":
		return 0
	
	var count:int = 0
	
	for target in targets:
		if target == null:
			continue
		
		if is_instance_valid(target) == false:
			continue
		
		if target.has_method(method_name) == false:
			continue
		
		var call_callable:Callable = Callable(self, "call_target_method").bind(target)
		var call_tweener = tween.tween_callback(call_callable)
		call_tweener.set_delay(start_time + delay)
		count += 1
	
	return count


func add_child_stagger_tweens(tween:Tween, player:Node, main_target:Control, start_time:float) -> int:
	var parent_targets:Array[Control] = get_targets(player, main_target)
	var count:int = 0
	
	for parent_target in parent_targets:
		if parent_target == null:
			continue
		
		if is_instance_valid(parent_target) == false:
			continue
		
		var child_index:int = 0
		
		for child in parent_target.get_children():
			var child_control:Control = child as Control
			
			if child_control == null:
				continue
			
			if include_invisible_children == false:
				if child_control.visible == false:
					continue
			
			prepare_offset_transform(child_control)
			
			var child_delay:float = start_time + delay + float(child_index) * child_stagger_delay
			
			var setup_alpha:Callable = Callable(self, "set_control_alpha").bind(child_control, float_from)
			var setup_alpha_tweener = tween.tween_callback(setup_alpha)
			setup_alpha_tweener.set_delay(child_delay)
			
			var setup_scale:Callable = Callable(self, "set_offset_scale").bind(child_control, scale_from)
			var setup_scale_tweener = tween.tween_callback(setup_scale)
			setup_scale_tweener.set_delay(child_delay)
			
			var alpha_tweener = tween.tween_property(child_control, "modulate:a", float_to, duration)
			alpha_tweener.set_delay(child_delay + 0.001)
			alpha_tweener.set_trans(trans_type)
			alpha_tweener.set_ease(ease_type)
			
			var scale_tweener = tween.tween_property(child_control, "offset_transform_scale", scale_to, duration)
			scale_tweener.set_delay(child_delay + 0.001)
			scale_tweener.set_trans(trans_type)
			scale_tweener.set_ease(ease_type)
			
			count += 1
			child_index += 1
	
	return count


func prepare_offset_transform(control:Control) -> void:
	if control == null:
		return
	
	if is_instance_valid(control) == false:
		return
	
	control.offset_transform_enabled = true
	control.offset_transform_visual_only = visual_only
	control.offset_transform_position_ratio = Vector2.ZERO
	control.offset_transform_pivot = Vector2.ZERO
	control.offset_transform_pivot_ratio = pivot_ratio


func set_control_alpha(control:Control, alpha:float) -> void:
	if control == null:
		return
	
	if is_instance_valid(control) == false:
		return
	
	control.modulate.a = alpha


func set_control_modulate(control:Control, new_modulate:Color) -> void:
	if control == null:
		return
	
	if is_instance_valid(control) == false:
		return
	
	control.modulate = new_modulate


func set_offset_position(control:Control, new_position:Vector2) -> void:
	if control == null:
		return
	
	if is_instance_valid(control) == false:
		return
	
	prepare_offset_transform(control)
	control.offset_transform_position = new_position
	control.offset_transform_position_ratio = Vector2.ZERO


func set_offset_scale(control:Control, new_scale:Vector2) -> void:
	if control == null:
		return
	
	if is_instance_valid(control) == false:
		return
	
	prepare_offset_transform(control)
	control.offset_transform_scale = new_scale


func set_offset_rotation_degrees(control:Control, degrees:float) -> void:
	if control == null:
		return
	
	if is_instance_valid(control) == false:
		return
	
	prepare_offset_transform(control)
	control.offset_transform_rotation = deg_to_rad(degrees)


func call_target_method(target:Control) -> void:
	if target == null:
		return
	
	if is_instance_valid(target) == false:
		return
	
	if method_name == "":
		return
	
	if target.has_method(method_name) == false:
		return
	
	target.callv(method_name, method_arguments)


func create_whiteout_overlay(target:Control) -> Panel:
	if target == null:
		return null
	
	if is_instance_valid(target) == false:
		return null
	
	var overlay:Panel = Panel.new()
	overlay.name = "Whiteout Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate = Color(whiteout_color.r, whiteout_color.g, whiteout_color.b, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style:StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = whiteout_color
	style.corner_radius_top_left = whiteout_corner_radius
	style.corner_radius_top_right = whiteout_corner_radius
	style.corner_radius_bottom_right = whiteout_corner_radius
	style.corner_radius_bottom_left = whiteout_corner_radius
	
	overlay.add_theme_stylebox_override("panel", style)
	target.add_child(overlay)
	target.move_child(overlay, target.get_child_count() - 1)
	
	return overlay


func remove_whiteout_overlay(overlay:Panel) -> void:
	if overlay == null:
		return
	
	if is_instance_valid(overlay) == false:
		return
	
	overlay.queue_free()
