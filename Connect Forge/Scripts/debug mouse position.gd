extends Node2D


@onready var label = $Label

func _process(delta):
	var mouse_pos = get_global_mouse_position()
	label.text = "Mouse Position: (" + str(mouse_pos.x) + " , " + str(mouse_pos.y) + ")"
