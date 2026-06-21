@tool
extends Node
#Board building tool, sets up the physcial bard as well as the representation. Runs in the editor too.

@export_tool_button("Rebuild Board") var rebuild_board_action = rebuild_board #adds a button to the inspector to rebuild the board, calls the "Rebuild Board" function.
@export var columns :int = 7
@export var rows :int = 6

@onready var board = $"../Board Manager"

@onready var token_pool = $"../Token Pool"

var slot_instance:PackedScene = load("res://Scenes/Slot.tscn")

func _ready():
	setup_board_settings()
	build_board()
	
func rebuild_board():
	clear_board()
	build_board()

func clear_board():
	#delete all the slots and tokens on the board.
	for child in board.get_children():
		child.queue_free()
	for child in token_pool.get_children():
		child.queue_free()
	
	if not Engine.is_editor_hint():
		board.refresh_token_pool()
		board.clear_board_state()
		board.hovered_slot = null
		
func build_board():
	if not Engine.is_editor_hint():
		board.settings.columns = columns
		board.settings.rows = rows
	
	for x in range(columns):
		for y in range(rows):
			create_slot(x,y)
	
	if not Engine.is_editor_hint():
		board.setup_empty_board_state()

func setup_board_settings():
	var new_slot = slot_instance.instantiate()
	var texture:Texture2D = new_slot.find_child("Front").texture as Texture2D
	
	if not Engine.is_editor_hint():
		board.slot_size = Vector2(texture.get_width(), texture.get_height())
		board.refresh_geometry()
	
	new_slot.queue_free()
	
func create_slot(x:int, y:int):
	var new_slot = slot_instance.instantiate()
	var texture:Texture2D = new_slot.find_child("Front").texture as Texture2D
	var slot_width_and_height = texture.get_width()

	var offset_x:float = (slot_width_and_height * new_slot.scale.x * columns) / 2
	var offset_y:float = (slot_width_and_height * new_slot.scale.y * rows) / 2

	# This is the actual visual/world position.
	new_slot.global_position.x = x * (slot_width_and_height * new_slot.scale.x) - offset_x + slot_width_and_height / 2
	new_slot.global_position.y = y * (slot_width_and_height * new_slot.scale.y) - offset_y + slot_width_and_height / 2

	# This is the grid position used for board logic.
	var slot_pos := Vector2i(x, y)
	var types := []

	if not Engine.is_editor_hint():
		types = assign_slot_types(x, y)

	new_slot.setup_slot(board, slot_pos, types)
	board.add_child(new_slot)
	
func assign_slot_types(x,y):
	var slot_types =[]
	if(x==0):
		slot_types.append(Global.SLOT_TYPE.LEFT_EDGE)
	if(x==columns-1):
		slot_types.append(Global.SLOT_TYPE.RIGHT_EDGE)
	if(y==0):
		slot_types.append(Global.SLOT_TYPE.TOP_EDGE)
	if(y==rows-1):
		slot_types.append(Global.SLOT_TYPE.BOTTOM_EDGE)
	if(slot_types.is_empty()):
		slot_types.append(Global.SLOT_TYPE.INTERIOR)
	
	return slot_types
