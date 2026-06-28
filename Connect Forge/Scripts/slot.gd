@tool
class_name Slot
extends Area2D
# This script handles mouse over detection for hovering over each slot.
# It stores the type of slot as well as the position.

var slot_types:Array = []
var slot_position:Vector2i = Vector2i.ZERO
var background_color:Color = Color(0x1e6939ff)
var highlight_color:Color = Color(0.2, 0.667, 0.373, 1.0)
var board:BoardManager

@onready var back:Sprite2D = $Back
@onready var slot_label:Label = $"Slot Label"


func _ready():
	slot_label.text = str(int(slot_position.x)) + "," + str(int(slot_position.y))
	
	if board != null:
		gravity_change()


func setup_slot(new_board:BoardManager, new_position:Vector2i, new_slot_types:Array):
	board = new_board
	slot_position = new_position
	slot_types = new_slot_types


func _on_mouse_entered():
	if board != null:
		board.set_hovered_slot(self)


func _on_mouse_exited():
	if board != null:
		board.clear_hovered_slot(self)


func gravity_change():
	if board == null:
		return
	
	back.modulate = background_color
	
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	match board.settings.gravity_direction:
		GRID_DIRECTION.DOWN:
			if slot_types.has(Global.SLOT_TYPE.TOP_EDGE):
				back.modulate = highlight_color
		GRID_DIRECTION.UP:
			if slot_types.has(Global.SLOT_TYPE.BOTTOM_EDGE):
				back.modulate = highlight_color
		GRID_DIRECTION.RIGHT:
			if slot_types.has(Global.SLOT_TYPE.LEFT_EDGE):
				back.modulate = highlight_color
		GRID_DIRECTION.LEFT:
			if slot_types.has(Global.SLOT_TYPE.RIGHT_EDGE):
				back.modulate = highlight_color
