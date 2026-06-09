@tool
extends Area2D
#This script handles mouse over detection for hovering over each slot.
#It stores the type of slot as well as the position.

var slot_types=[]
var slot_position:Vector2 = Vector2.ZERO
@onready var slot_label = $"Slot Label"

func _ready():
	slot_label.text= str(int(slot_position.x)) + "," + str(int(slot_position.y))
func _on_mouse_entered():
	Global.hovered_slot=self
	

func _on_mouse_exited():
	if(Global.hovered_slot == self):
		Global.hovered_slot=null
