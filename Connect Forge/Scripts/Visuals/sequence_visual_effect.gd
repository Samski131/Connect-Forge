class_name SequenceVisualEffect
extends BoardVisualEffect

var effects:Array[BoardVisualEffect] = []
var _current_index:int = 0
var _runner:Node


func _init(new_effects:Array[BoardVisualEffect] = []):
	effects = new_effects


func _play_valid(runner:Node) -> void:
	_runner = runner
	_current_index = 0
	_play_next()


func _play_next() -> void:
	while _current_index < effects.size():
		var effect := effects[_current_index]
		_current_index += 1
		
		if effect == null:
			continue
		
		effect.play(_runner, _play_next)
		return
	
	_finish()
