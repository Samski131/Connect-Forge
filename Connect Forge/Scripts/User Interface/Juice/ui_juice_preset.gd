class_name UIJuicePreset
extends Resource

enum PlayMode {
	PARALLEL,
	SEQUENCE
}

@export var play_mode:PlayMode = PlayMode.PARALLEL
@export var steps:Array[UIJuiceStep] = []

@export_group("Target State")
@export var make_visible_at_start:bool = true
@export var hide_at_end:bool = false
@export var disable_mouse_during_play:bool = false
@export var restore_mouse_after_play:bool = true

@export_group("Reset Before Play")
@export var reset_offset_position:bool = false
@export var reset_offset_scale:bool = false
@export var reset_offset_rotation:bool = false
@export var reset_modulate:bool = false


func get_total_duration() -> float:
	var total_duration:float = 0.0
	
	if play_mode == PlayMode.PARALLEL:
		for step in steps:
			if step == null:
				continue
			
			total_duration = max(total_duration, step.get_total_duration())
		
		return total_duration
	
	for step in steps:
		if step == null:
			continue
		
		total_duration += step.get_total_duration()
	
	return total_duration
