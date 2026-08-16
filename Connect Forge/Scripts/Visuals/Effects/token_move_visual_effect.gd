class_name TokenMoveVisualEffect
extends VisualTweenEffect

var target_global:Vector2
var move_visual:BoardVisualManager.MOVE_VISUAL

var slide_duration:float = 0.12
var min_fall_duration:float = 0.14
var max_fall_duration:float = 0.55
var fall_pixels_per_second:float = 2200.0

var replay_from_pos:Vector2i = Vector2i.ZERO
var replay_to_pos:Vector2i = Vector2i.ZERO
var replay_movement_path:Array[Vector2i] = []
var replay_context_is_set:bool = false


func _init(new_token:Token, new_target_global:Vector2, new_move_visual:BoardVisualManager.MOVE_VISUAL):
	target = new_token
	target_global = new_target_global
	move_visual = new_move_visual


func _play_valid(runner:Node) -> void:
	var token:Token = target as Token
	
	if token == null or is_instance_valid(token) == false:
		_finish()
		return
	
	if move_visual == BoardVisualManager.MOVE_VISUAL.FALL:
		var distance:float = token.global_position.distance_to(target_global)
		duration = clamp(distance / fall_pixels_per_second, min_fall_duration, max_fall_duration)
		trans_type = Tween.TRANS_QUAD
		ease_type = Tween.EASE_IN
	else:
		duration = slide_duration
		trans_type = Tween.TRANS_SINE
		ease_type = Tween.EASE_OUT
	
	super._play_valid(runner)


func _build_tween(tween:Tween) -> void:
	add_property_tween(tween, target, "global_position", target_global)


func set_replay_movement_context(from_pos:Vector2i, to_pos:Vector2i, movement_path:Array[Vector2i] = []) -> void:
	replay_from_pos = from_pos
	replay_to_pos = to_pos
	replay_movement_path.clear()
	
	for path_pos in movement_path:
		replay_movement_path.append(path_pos)
	
	replay_context_is_set = true


func to_replay_action() -> ReplayAction:
	if replay_context_is_set == false:
		return null
	
	var token_id:int = get_replay_target_token_id()
	
	if token_id < 0:
		return null
	
	var payload:Dictionary = {
		"token_id": token_id,
		"from": ReplayAction.grid_position_to_data(replay_from_pos),
		"to": ReplayAction.grid_position_to_data(replay_to_pos),
		"movement": get_replay_movement_type(),
		"duration": get_replay_duration()
	}
	
	if replay_movement_path.is_empty() == false:
		payload["path"] = ReplayAction.grid_path_to_data(replay_movement_path)
	
	return ReplayAction.create_presentation(ReplayFormat.PRESENTATION_TOKEN_MOVE, payload)


func get_replay_movement_type() -> String:
	if move_visual == BoardVisualManager.MOVE_VISUAL.FALL:
		return ReplayFormat.MOVEMENT_FALL
	
	return ReplayFormat.MOVEMENT_SLIDE


func get_replay_duration() -> float:
	if move_visual == BoardVisualManager.MOVE_VISUAL.FALL:
		var token:Token = get_replay_target_token()
		
		if token == null:
			return min_fall_duration
		
		var distance:float = token.global_position.distance_to(target_global)
		return clamp(distance / fall_pixels_per_second, min_fall_duration, max_fall_duration)
	
	return slide_duration
