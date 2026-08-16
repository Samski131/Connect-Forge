class_name ParallelVisualEffect
extends BoardVisualEffect

var effects:Array[BoardVisualEffect] = []
var _remaining:int = 0
var _finished:bool = false


func _init(new_effects:Array[BoardVisualEffect] = []):
	effects = new_effects


func _play_valid(runner:Node) -> void:
	_finished = false
	
	var valid_effects:Array[BoardVisualEffect] = []
	
	for effect in effects:
		if effect == null:
			continue
		
		valid_effects.append(effect)
	
	_remaining = valid_effects.size()
	
	if _remaining <= 0:
		_finish_once()
		return
	
	for effect in valid_effects:
		effect.play(runner, _on_child_finished)


func _on_child_finished() -> void:
	if _finished:
		return
	
	_remaining -= 1
	
	if _remaining <= 0:
		_finish_once()


func _finish_once() -> void:
	if _finished:
		return
	
	_finished = true
	_finish()


func to_replay_action() -> ReplayAction:
	var replay_actions:Array[ReplayAction] = []
	
	for effect in effects:
		if effect == null:
			continue
		
		var replay_action:ReplayAction = effect.to_replay_action()
		
		if replay_action == null:
			continue
		
		replay_actions.append(replay_action)
	
	if replay_actions.is_empty():
		return null
	
	return ReplayAction.create_parallel(replay_actions)
