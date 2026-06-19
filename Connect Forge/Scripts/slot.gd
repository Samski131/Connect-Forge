@tool
extends Area2D
#This script handles mouse over detection for hovering over each slot.
#It stores the type of slot as well as the position.

var slot_types=[]
var slot_position:Vector2i = Vector2i.ZERO
var background_color:Color = Color(0x1e6939ff)
var highlight_color:Color = Color(0.2, 0.667, 0.373, 1.0)
@onready var back = $Back
@onready var slot_label = $"Slot Label"

func _ready():
	slot_label.text= str(int(slot_position.x)) + "," + str(int(slot_position.y))
	gravity_change()
	
func _on_mouse_entered():
	Global.hovered_slot=self
	

func _on_mouse_exited():
	if(Global.hovered_slot == self):
		Global.hovered_slot=null

func gravity_change():
	back.modulate = background_color
	match Global.board_settings.gravity_direction:
		BoardSetting.DIRECTION.DOWN:
			if(slot_types.has(Global.SLOT_TYPE.TOP_EDGE)):
				back.modulate = highlight_color
		BoardSetting.DIRECTION.UP:
			if(slot_types.has(Global.SLOT_TYPE.BOTTOM_EDGE)):
				back.modulate = highlight_color
		BoardSetting.DIRECTION.RIGHT:
			if(slot_types.has(Global.SLOT_TYPE.LEFT_EDGE)):
				back.modulate = highlight_color
		BoardSetting.DIRECTION.LEFT:
			if(slot_types.has(Global.SLOT_TYPE.RIGHT_EDGE)):
				back.modulate = highlight_color
