@tool
extends Node
#Board building tool, sets up the physcial bard as well as the representation. Runs in the editor too.

@export_tool_button("Rebuild Board") var rebuild_board_action = rebuild_board #adds a button to the inspector to rebuild the board, calls the "Rebuild Board" function.
@export var collumns :int = 7
@export var rows :int = 6

@onready var board_pool = $"../Board Pool"
@onready var token_pool = $"../Token Pool"

var slot_instance:PackedScene = load("res://Scenes/Slot.tscn")

func _ready():
	setup_board_settings()
	build_board()
	
func rebuild_board():
	clear_board()
	build_board()

	
func build_board():
	#Creates a new board based on the height and width settings.
	#Instantiates the appropraite number of slots.
	#Sets the board array to be all null tiles.
	if not Engine.is_editor_hint():
		Global.board_settings.height= rows
		Global.board_settings.width = collumns
	for x in range(collumns):
		for y in range(rows):
			create_slot(x,y)
			if not Engine.is_editor_hint():
				Global.board_pool.board.append(null)
			
func clear_board():
	#delete all the slots and tokens on the board.
	for child in board_pool.get_children():
		child.queue_free()
	for child in Global.token_pool.get_children():
		child.queue_free()
		
func setup_board_settings():
	#passes important details to the Global script to be referenced elsewhere.
	var new_slot = slot_instance.instantiate()
	var texture:Texture2D= new_slot.find_child("Front").texture as Texture2D
	if not Engine.is_editor_hint():
		Global.slot_size = Vector2(texture.get_width(),texture.get_height())
		Global.board_settings.collumns = collumns
		Global.board_settings.rows = rows
	
func create_slot(x:int, y:int):
	#Create new slot nodes, sets up the appropriate slot types based on postion and positions the nodes.
	var new_slot = slot_instance.instantiate()
	var texture:Texture2D= new_slot.find_child("Front").texture as Texture2D
	var slot_width_and_height = texture.get_width()
	new_slot.global_position.x = x * (slot_width_and_height* new_slot.scale.x) - (slot_width_and_height* new_slot.scale.x * collumns)/2 + slot_width_and_height/2 
	new_slot.global_position.y = y * (slot_width_and_height* new_slot.scale.y) - (slot_width_and_height* new_slot.scale.y * rows)/2 + slot_width_and_height/2
	if not Engine.is_editor_hint():
		new_slot.slot_types = assign_slot_types(x,y)
	new_slot.slot_position = Vector2(x,y)
	board_pool.add_child(new_slot)
	
func assign_slot_types(x,y):
	var slot_types =[]
	if(x==0):
		slot_types.append(Global.SLOT_TYPE.LEFT_EDGE)
	if(x==collumns-1):
		slot_types.append(Global.SLOT_TYPE.RIGHT_EDGE)
	if(y==0):
		slot_types.append(Global.SLOT_TYPE.TOP_EDGE)
	if(y==rows-1):
		slot_types.append(Global.SLOT_TYPE.BOTTOM_EDGE)
	if(slot_types.is_empty()):
		slot_types.append(Global.SLOT_TYPE.INTERIOR)
	
	return slot_types
