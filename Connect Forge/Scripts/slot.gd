@tool
extends Area2D
var slot_types=[]
var slot_position:Vector2 = Vector2.ZERO


func _on_mouse_entered():
	Global.hovered_slot=self
	


func _on_mouse_exited():
	if(Global.hovered_slot == self):
		Global.hovered_slot=null
