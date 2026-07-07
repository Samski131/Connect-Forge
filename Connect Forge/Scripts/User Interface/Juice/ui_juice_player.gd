class_name UIJuicePlayer
extends Node

signal preset_finished(preset:UIJuicePreset)
signal enter_finished
signal exit_finished

enum StartMode {
	DO_NOTHING,
	HIDE_INSTANT,
	SHOW_INSTANT,
	ENTER_ON_READY
}

@export var target_path:NodePath

@export_group("Startup")
@export var start_mode:StartMode = StartMode.DO_NOTHING
@export var process_while_paused:bool = true

@export_group("Presets")
@export var enter_preset:UIJuicePreset
@export var exit_preset:UIJuicePreset
@export var hover_enter_preset:UIJuicePreset
@export var hover_exit_preset:UIJuicePreset
@export var pressed_preset:UIJuicePreset
@export var released_preset:UIJuicePreset
@export var focus_enter_preset:UIJuicePreset
@export var focus_exit_preset:UIJuicePreset
@export var invalid_preset:UIJuicePreset
@export var active_preset:UIJuicePreset
@export var inactive_preset:UIJuicePreset

@export_group("Automatic Input")
@export var use_auto_hover:bool = false
@export var use_auto_button_press:bool = false
@export var use_auto_focus:bool = false

@export_group("Triggers")
@export var enter_button_paths:Array[NodePath] = []
@export var exit_button_paths:Array[NodePath] = []
@export var toggle_button_paths:Array[NodePath] = []
@export var toggle_input_action:String = ""

@export_group("Mouse Behaviour")
@export var disable_mouse_while_hidden:bool = true
@export var disable_mouse_while_transitioning:bool = true

var target:Control = null
var original_modulate:Color = Color.WHITE
var original_mouse_filter:Control.MouseFilter = Control.MOUSE_FILTER_PASS

var is_open:bool = false
var is_transitioning:bool = false
var is_hovered:bool = false

var active_tween:Tween = null
var juice_active_preset:UIJuicePreset = null


func _ready() -> void:
	if process_while_paused:
		process_mode = Node.PROCESS_MODE_ALWAYS
	
	resolve_target()
	
	if target == null:
		return
	
	original_modulate = target.modulate
	original_mouse_filter = target.mouse_filter
	
	setup_offset_transform(target)
	connect_automatic_input()
	connect_trigger_buttons()
	apply_start_mode()


func resolve_target() -> void:
	if target_path != NodePath(""):
		target = get_node_or_null(target_path) as Control
	
	if target == null:
		target = get_parent() as Control


func setup_offset_transform(control:Control) -> void:
	if control == null:
		return
	
	control.offset_transform_enabled = true
	control.offset_transform_visual_only = false
	control.offset_transform_position_ratio = Vector2.ZERO
	control.offset_transform_pivot = Vector2.ZERO
	control.offset_transform_pivot_ratio = Vector2(0.5, 0.5)

func connect_automatic_input() -> void:
	if target == null:
		return
	
	if use_auto_hover:
		if target.mouse_entered.is_connected(_on_target_mouse_entered) == false:
			target.mouse_entered.connect(_on_target_mouse_entered)
		
		if target.mouse_exited.is_connected(_on_target_mouse_exited) == false:
			target.mouse_exited.connect(_on_target_mouse_exited)
	
	var button:BaseButton = target as BaseButton
	
	if button != null and use_auto_button_press:
		if button.button_down.is_connected(_on_button_down) == false:
			button.button_down.connect(_on_button_down)
		
		if button.button_up.is_connected(_on_button_up) == false:
			button.button_up.connect(_on_button_up)
	
	if use_auto_focus:
		if target.focus_entered.is_connected(_on_focus_entered) == false:
			target.focus_entered.connect(_on_focus_entered)
		
		if target.focus_exited.is_connected(_on_focus_exited) == false:
			target.focus_exited.connect(_on_focus_exited)


func connect_trigger_buttons() -> void:
	connect_button_paths(enter_button_paths, enter)
	connect_button_paths(exit_button_paths, exit)
	connect_button_paths(toggle_button_paths, toggle)


func connect_button_paths(paths:Array[NodePath], callable:Callable) -> void:
	for path in paths:
		var button:BaseButton = get_node_or_null(path) as BaseButton
		
		if button == null:
			continue
		
		if button.pressed.is_connected(callable) == false:
			button.pressed.connect(callable)


func apply_start_mode() -> void:
	match start_mode:
		StartMode.DO_NOTHING:
			is_open = target.visible
		
		StartMode.HIDE_INSTANT:
			hide_instant()
		
		StartMode.SHOW_INSTANT:
			show_instant()
		
		StartMode.ENTER_ON_READY:
			hide_instant()
			call_deferred("enter")


func _unhandled_input(event:InputEvent) -> void:
	if toggle_input_action == "":
		return
	
	if event.is_action_pressed(toggle_input_action) == false:
		return
	
	if event is InputEventKey:
		var key_event:InputEventKey = event as InputEventKey
		
		if key_event.echo:
			return
	
	toggle()
	get_viewport().set_input_as_handled()


func enter() -> void:
	if enter_preset == null:
		show_instant()
		enter_finished.emit()
		return
	
	is_open = true
	play_preset(enter_preset, Callable(self, "_on_enter_finished"))


func exit() -> void:
	if exit_preset == null:
		hide_instant()
		exit_finished.emit()
		return
	
	is_open = false
	play_preset(exit_preset, Callable(self, "_on_exit_finished"))


func toggle() -> void:
	if is_open:
		exit()
		return
	
	enter()


func play_invalid() -> void:
	play_preset(invalid_preset)


func play_active() -> void:
	play_preset(active_preset)


func play_inactive() -> void:
	play_preset(inactive_preset)


func play_pressed() -> void:
	play_preset(pressed_preset)


func play_released() -> void:
	play_preset(released_preset)


func play_preset(preset:UIJuicePreset, finished_callback:Callable = Callable()) -> void:
	if preset == null:
		return
	
	if target == null:
		return
	
	kill_active_tween()
	
	juice_active_preset = preset
	is_transitioning = true
	
	if preset.make_visible_at_start:
		target.visible = true
	
	if preset.disable_mouse_during_play:
		set_target_mouse_enabled(false)
	
	apply_preset_resets(preset)
	
	var tween:Tween = create_tween()
	active_tween = tween
	tween.set_parallel(true)
	
	var tween_count:int = build_preset_tween(tween, preset)
	
	if tween_count <= 0:
		tween.kill()
		active_tween = null
		is_transitioning = false
		finish_preset(preset, finished_callback)
		return
	
	tween.finished.connect(_on_preset_tween_finished.bind(preset, finished_callback))


func build_preset_tween(tween:Tween, preset:UIJuicePreset) -> int:
	var tween_count:int = 0
	var current_start_time:float = 0.0
	
	for step in preset.steps:
		if step == null:
			continue
		
		tween_count += step.add_to_tween(tween, self, target, current_start_time)
		
		if preset.play_mode == UIJuicePreset.PlayMode.SEQUENCE:
			current_start_time += step.get_total_duration()
	
	return tween_count


func apply_preset_resets(preset:UIJuicePreset) -> void:
	if target == null:
		return
	
	setup_offset_transform(target)
	
	if preset.reset_offset_position:
		target.offset_transform_position = Vector2.ZERO
		target.offset_transform_position_ratio = Vector2.ZERO
	
	if preset.reset_offset_scale:
		target.offset_transform_scale = Vector2.ONE
	
	if preset.reset_offset_rotation:
		target.offset_transform_rotation = 0.0
	
	if preset.reset_modulate:
		target.modulate = original_modulate


func _on_preset_tween_finished(preset:UIJuicePreset, finished_callback:Callable) -> void:
	active_tween = null
	is_transitioning = false
	finish_preset(preset, finished_callback)


func finish_preset(preset:UIJuicePreset, finished_callback:Callable) -> void:
	if target != null:
		if preset.hide_at_end:
			target.visible = false
		
		if preset.restore_mouse_after_play:
			if is_open:
				set_target_mouse_enabled(true)
	
	juice_active_preset = null
	preset_finished.emit(preset)
	
	if finished_callback.is_valid():
		finished_callback.call()


func _on_enter_finished() -> void:
	is_open = true
	is_transitioning = false
	
	if target != null:
		target.visible = true
		set_target_mouse_enabled(true)
	
	enter_finished.emit()


func _on_exit_finished() -> void:
	is_open = false
	is_transitioning = false
	
	if target != null:
		target.visible = false
		set_target_mouse_enabled(false)
	
	exit_finished.emit()


func show_instant() -> void:
	if target == null:
		return
	
	kill_active_tween()
	
	is_open = true
	is_transitioning = false
	
	target.visible = true
	target.modulate = original_modulate
	target.offset_transform_position = Vector2.ZERO
	target.offset_transform_position_ratio = Vector2.ZERO
	target.offset_transform_scale = Vector2.ONE
	target.offset_transform_rotation = 0.0
	
	set_target_mouse_enabled(true)


func hide_instant() -> void:
	if target == null:
		return
	
	kill_active_tween()
	
	is_open = false
	is_transitioning = false
	
	target.visible = false
	target.modulate = Color(original_modulate.r, original_modulate.g, original_modulate.b, 0.0)
	target.offset_transform_position = Vector2.ZERO
	target.offset_transform_position_ratio = Vector2.ZERO
	target.offset_transform_scale = Vector2.ONE
	target.offset_transform_rotation = 0.0
	
	set_target_mouse_enabled(false)


func set_target_mouse_enabled(enabled:bool) -> void:
	if target == null:
		return
	
	if enabled:
		target.mouse_filter = original_mouse_filter
		return
	
	if disable_mouse_while_hidden:
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	
	if disable_mouse_while_transitioning:
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE


func kill_active_tween() -> void:
	if active_tween == null:
		return
	
	if active_tween.is_valid():
		active_tween.kill()
	
	active_tween = null


func _on_target_mouse_entered() -> void:
	if is_open == false:
		return
	
	if is_transitioning:
		return
	
	is_hovered = true
	play_preset(hover_enter_preset)


func _on_target_mouse_exited() -> void:
	if is_open == false:
		return
	
	if is_transitioning:
		return
	
	is_hovered = false
	play_preset(hover_exit_preset)


func _on_button_down() -> void:
	play_preset(pressed_preset)


func _on_button_up() -> void:
	play_preset(released_preset)


func _on_focus_entered() -> void:
	play_preset(focus_enter_preset)


func _on_focus_exited() -> void:
	play_preset(focus_exit_preset)
