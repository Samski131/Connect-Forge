class_name UIEffect
extends RefCounted

var target:Control = null
var duration:float = 0.2

var _finished_callback:Callable


func _init(new_target:Control = null, new_duration:float = 0.2):
	target = new_target
	duration = new_duration


func play(runner:Node, finished_callback:Callable) -> void:
	_finished_callback = finished_callback
	
	if _has_valid_target() == false:
		_finish()
		return
	
	_play_valid(runner)


func _play_valid(_runner:Node) -> void:
	_finish()


func _has_valid_target() -> bool:
	if target == null:
		return false
	
	if is_instance_valid(target) == false:
		return false
	
	return true


func _finish() -> void:
	if _finished_callback.is_valid():
		_finished_callback.call()
