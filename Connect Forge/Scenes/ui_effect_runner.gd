class_name UIEffectRunner
extends Node

var effect_queue:Array[UIEffect] = []
var current_effect:UIEffect = null
var busy:bool = false


func _ready() -> void:
	add_to_group("ui effect runner")


func is_busy() -> bool:
	if busy:
		return true
	
	if effect_queue.is_empty() == false:
		return true
	
	return false


func play(effect:UIEffect) -> void:
	if effect == null:
		return
	
	effect.play(self, Callable())


func queue_effect(effect:UIEffect) -> void:
	if effect == null:
		return
	
	effect_queue.append(effect)
	_start_next_effect()


func _start_next_effect() -> void:
	if busy:
		return
	
	if effect_queue.is_empty():
		return
	
	current_effect = effect_queue.pop_front()
	busy = true
	
	current_effect.play(self, _finish_effect)


func _finish_effect() -> void:
	current_effect = null
	busy = false
	_start_next_effect()
