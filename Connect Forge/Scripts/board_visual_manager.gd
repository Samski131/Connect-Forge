class_name BoardVisualManager
extends Node

enum MOVE_VISUAL {FALL, SLIDE}

@export var slide_duration:float = 0.12
@export var min_fall_duration:float = 0.14
@export var max_fall_duration:float = 0.55
@export var fall_pixels_per_second:float = 2200.0
@export var destroy_duration:float = 0.2

var visual_busy:bool = false
var visual_queue:Array[Dictionary] = []

var batching_moves:bool = false
var move_batch:Array[Dictionary] = []
var post_batch_events:Array[Dictionary] = []
var active_batch_tweens:int = 0


func is_busy()->bool:
	return visual_busy or visual_queue.is_empty() == false


func queue_token_move(token:Token, target_global:Vector2, move_visual:MOVE_VISUAL):
	if token == null:
		return
	
	if is_instance_valid(token) == false:
		return
	
	var event := {
		"type": "move",
		"token": token,
		"target_global": target_global,
		"move_visual": move_visual
	}
	
	if batching_moves and move_visual == MOVE_VISUAL.FALL:
		move_batch.append(event)
		return
	
	_queue_visual_event(event)

func queue_token_destroy(token:Token):
	if token == null:
		return
	
	if is_instance_valid(token) == false:
		return
	
	var event := {
		"type": "destroy",
		"token": token
	}
	
	_queue_visual_event(event)


func _start_next_visual_event():
	if visual_busy:
		return
	
	if visual_queue.is_empty():
		return
	
	var event:Dictionary = visual_queue.pop_front()
	var event_type:String = event.get("type", "")
	
	visual_busy = true
	
	match event_type:
		"move_batch":
			_play_move_batch_event(event)
		
		"move":
			var token:Token = event.get("token", null)
			
			if token == null or is_instance_valid(token) == false:
				_finish_visual_event()
				return
			
			_play_move_event(event)
		
		"destroy":
			var token:Token = event.get("token", null)
			
			if token == null or is_instance_valid(token) == false:
				_finish_visual_event()
				return
			
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

func begin_move_batch():
	batching_moves = true
	move_batch.clear()
	post_batch_events.clear()


func end_move_batch():
	batching_moves = false
	
	if move_batch.is_empty() == false:
		visual_queue.append({
			"type": "move_batch",
			"moves": move_batch.duplicate()
		})
	
	for event in post_batch_events:
		visual_queue.append(event)
	
	move_batch.clear()
	post_batch_events.clear()
	
	_start_next_visual_event()
	
func _queue_visual_event(event:Dictionary):
	if batching_moves:
		post_batch_events.append(event)
	else:
		visual_queue.append(event)
		_start_next_visual_event()
		
func _play_move_batch_event(event:Dictionary):
	var moves:Array = event.get("moves", [])
	active_batch_tweens = 0
	
	for move_event in moves:
		var token:Token = move_event.get("token", null)
		
		if token == null or is_instance_valid(token) == false:
			continue
		
		var target_global:Vector2 = move_event["target_global"]
		var move_visual:MOVE_VISUAL = move_event["move_visual"]
		
		var distance:float = token.global_position.distance_to(target_global)
		var duration:float = slide_duration
		
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
		
		active_batch_tweens += 1
		tween.finished.connect(_on_batch_tween_finished)
	
	if active_batch_tweens == 0:
		_finish_visual_event()


func _on_batch_tween_finished():
	active_batch_tweens -= 1
	
	if active_batch_tweens <= 0:
		_finish_visual_event()
		
