class_name ParallelVisualEffect
extends BoardVisualEffect

var effects:Array[BoardVisualEffect] = []
var _remaining:int = 0


func _init(new_effects:Array[BoardVisualEffect] = []):
	effects = new_effects


func _play_valid(runner:Node) -> void:
	_remaining = 0
	
	for effect in effects:
		if effect == null:
			continue
		
		_remaining += 1
		effect.play(runner, _on_child_finished)
	
	if _remaining <= 0:
		_finish()


func _on_child_finished() -> void:
	_remaining -= 1
	
	if _remaining <= 0:
		_finish()
