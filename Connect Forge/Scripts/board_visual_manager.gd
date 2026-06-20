class_name BoardVisualManager
extends Node

enum MOVE_VISUAL {FALL, SLIDE}

@export var slide_duration:float = 0.12
@export var min_fall_duration:float = 0.14
@export var max_fall_duration:float = 0.55
@export var fall_pixels_per_second:float = 2200.0
@export var destroy_duration:float = 0.16

var visual_busy:bool = false
var visual_queue:Array[Dictionary] = []


func is_busy()->bool:
	return visual_busy or visual_queue.is_empty() == false


func queue_token_move(token:Token, target_global:Vector2, move_visual:MOVE_VISUAL):
	if token == null:
		return
	
	if is_instance_valid(token) == false:
		return
	
	visual_queue.append({
		"type": "move",
		"token": token,
		"target_global": target_global,
		"move_visual": move_visual
	})
	
	_start_next_visual_event()


func queue_token_destroy(token:Token):
	if token == null:
		return
	
	if is_instance_valid(token) == false:
		return
	
	visual_queue.append({
		"type": "destroy",
		"token": token
	})
	
	_start_next_visual_event()


func _start_next_visual_event():
	if visual_busy:
		return
	
	if visual_queue.is_empty():
		return
	
	var event:Dictionary = visual_queue.pop_front()
	var token:Token = event.get("token", null)
	
	if token == null or is_instance_valid(token) == false:
		_start_next_visual_event()
		return
	
	visual_busy = true
	
	match event.get("type", ""):
		"move":
			_play_move_event(event)
		"destroy":
			_play_destroy_event(event)
		_:
			_finish_visual_event()


func _play_move_event(event:Dictionary):
	var token:Token = event["token"]
	var target_global:Vector2 = event["target_global"]
	var move_visual:MOVE_VISUAL = event["move_visual"]
	
	if token == null or is_instance_valid(token) == false:
		_finish_visual_event()
		return
	
	var distance : float = token.global_position.distance_to(target_global)
	var duration : float = slide_duration
	
	if move_visual == MOVE_VISUAL.FALL:
		duration = clamp(distance / fall_pixels_per_second, min_fall_duration, max_fall_duration)
	
	var tween := create_tween()
	
	if move_visual == MOVE_VISUAL.FALL:
		tween.tween_property(token, "global_position", target_global, duration) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(token, "global_position", target_global, duration) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(_finish_visual_event)


func _play_destroy_event(event:Dictionary):
	var token:Token = event["token"]
	
	if token == null or is_instance_valid(token) == false:
		_finish_visual_event()
		return
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(token, "scale", Vector2.ZERO, destroy_duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_IN)
	tween.tween_property(token, "modulate:a", 0.0, destroy_duration)
	
	tween.finished.connect(_finish_destroy_event.bind(token))


func _finish_destroy_event(token:Token):
	if token != null and is_instance_valid(token):
		token.queue_free()
	
	_finish_visual_event()


func _finish_visual_event():
	visual_busy = false
	_start_next_visual_event()
