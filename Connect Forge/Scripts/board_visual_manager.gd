class_name BoardVisualManager
extends Node

enum MOVE_VISUAL {FALL, SLIDE}
signal visual_queue_empty

@export_group("Movement")
@export var slide_duration:float = 0.12
@export var min_fall_duration:float = 0.14
@export var max_fall_duration:float = 0.55
@export var fall_pixels_per_second:float = 2200.0

@export_group("Token Effects")
@export var destroy_duration:float = 0.2
@export var shimmer_duration:float = 0.45
@export var darken_duration:float = 0.12
@export var darken_amount:float = 0.3
@export var lighten_duration:float = 0.12
@export var lighten_amount:float = 0.3
@export var gravity_rotate_duration:float = 0.18

@export_group("Token Flip")
@export var flip_duration:float = 0.4
@export var flip_min_scale_x:float = 0.08
@export var flip_pop_scale_y:float = 1.08

@export_group("Winning Line")
@export var winning_line_duration:float = 0.55
@export var winning_line_width:float = 40.0
@export var winning_line_padding:float = 115.0
@export var winning_line_shadow_width_multiplier:float = 1.65
@export var winning_line_shadow_color:Color = Color(0.0, 0.0, 0.0, 0.45)
@export var winning_line_z_index:int = 100

@export_group("Board Clear Fall Out")
@export var clear_fall_duration:float = 0.62
@export var clear_fall_distance:float = 2600.0
@export var clear_fall_row_stagger:float = 0.035
@export var clear_fall_token_stagger:float = 0.006


var visual_busy:bool = false
var visual_queue:Array[BoardVisualEffect] = []
var current_effect:BoardVisualEffect = null

var batching_moves:bool = false
var batched_parallel_effects:Array[BoardVisualEffect] = []
var post_batch_effects:Array[BoardVisualEffect] = []


func is_busy() -> bool:
	if visual_busy:
		return true
	
	if visual_queue.is_empty() == false:
		return true
	
	if batching_moves:
		return true
	
	if batched_parallel_effects.is_empty() == false:
		return true
	
	if post_batch_effects.is_empty() == false:
		return true
	
	return false
	
func queue_effect(effect:BoardVisualEffect, batch_parallel:bool = false) -> void:
	if effect == null:
		return
	
	if batching_moves:
		if batch_parallel:
			batched_parallel_effects.append(effect)
		else:
			post_batch_effects.append(effect)
		return
	
	visual_queue.append(effect)
	_start_next_visual_event()


func _start_next_visual_event() -> void:
	if visual_busy:
		return
	
	if visual_queue.is_empty():
		return
	
	current_effect = visual_queue.pop_front()
	visual_busy = true
	
	current_effect.play(self, _finish_visual_event)


func _finish_visual_event() -> void:
	current_effect = null
	visual_busy = false
	_start_next_visual_event()
	
	if is_busy() == false:
		visual_queue_empty.emit()


func begin_move_batch() -> void:
	batching_moves = true
	batched_parallel_effects.clear()
	post_batch_effects.clear()


func end_move_batch() -> void:
	batching_moves = false
	
	if batched_parallel_effects.is_empty() == false:
		visual_queue.append(ParallelVisualEffect.new(batched_parallel_effects.duplicate()))
	
	for event in post_batch_effects:
		visual_queue.append(event)
	
	batched_parallel_effects.clear()
	post_batch_effects.clear()
	
	_start_next_visual_event()
