@tool
extends Node2D
#Board building tool, sets up the physcial bard as well as the representation. Runs in the editor too.

@export_tool_button("Rebuild Board") var rebuild_board_action = rebuild_board #adds a button to the inspector to rebuild the board, calls the "Rebuild Board" function.
@export var columns :int = 7
@export var rows :int = 6
@export var border_width:Vector2 = Vector2(100,100)
@export var border_highlight_width:int = 10
@export var border_corner_rounding:int = 16
@export_color_no_alpha var border_exterior_color:Color
@export_color_no_alpha var border_exterior_highlight_color:Color
@export_color_no_alpha var border_interior_color:Color

@onready var game_board = $".."

@onready var board = $"../Board Manager"

@onready var token_pool = $"../Token Pool"

var slot_instance:PackedScene = load("res://Scenes/Slot.tscn")
var sprite_2d_rectangle:PackedScene = load("uid://dcdpt1usuprbf")
var slot_width_and_height:float
var board_area_fitter:PanelContainer
func _ready():

	board_area_fitter = get_tree().get_first_node_in_group("board area fitter")
	clear_board()
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
		board.visible = true
	else:
		board.visible = false
	
	for x in range(columns):
		for y in range(rows):
			create_slot(x,y)
	
	resize_border_rectangles()
	call_deferred("fit_board")
	
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
	slot_width_and_height = texture.get_width()

	var offset_x:float = (slot_width_and_height * new_slot.scale.x * columns) / 2
	var offset_y:float = (slot_width_and_height * new_slot.scale.y * rows) / 2

	# This is the actual visual/world position.
	new_slot.position.x = x * (slot_width_and_height * new_slot.scale.x) - offset_x + slot_width_and_height / 2
	new_slot.position.y = y * (slot_width_and_height * new_slot.scale.y) - offset_y + slot_width_and_height / 2
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

func resize_border_rectangles():
	var new_exterior_border = sprite_2d_rectangle.instantiate()
	var new_exterior_border_highlight = sprite_2d_rectangle.instantiate()
	var new_interior_border = sprite_2d_rectangle.instantiate()
	
	new_exterior_border.texture = ShapeTexture2D.new()
	new_exterior_border_highlight.texture = ShapeTexture2D.new()
	new_interior_border.texture = ShapeTexture2D.new()
	
	new_exterior_border.texture.shape = DrawableRectangle.new()
	new_exterior_border_highlight.texture.shape = DrawableRectangle.new()
	new_interior_border.texture.shape = DrawableRectangle.new()
	
	
	new_exterior_border.texture.shape.corner_rounding = border_corner_rounding
	new_exterior_border_highlight.texture.shape.corner_rounding = border_corner_rounding
	new_interior_border.texture.shape.corner_rounding = border_corner_rounding
	
	new_exterior_border.position = Vector2.ZERO + (Vector2(1,1) * border_highlight_width/2)
	new_exterior_border_highlight.position = Vector2.ZERO
	new_interior_border.position = Vector2.ZERO
	
	var board_size_pixels = Vector2((slot_width_and_height * columns),(slot_width_and_height * rows))
	new_exterior_border.texture.size =board_size_pixels + (border_width *2)

	new_exterior_border_highlight.texture.size = board_size_pixels + (border_width *2) +(Vector2.ONE * border_highlight_width)

	new_interior_border.texture.size = board_size_pixels  + border_width

	new_exterior_border.modulate = border_exterior_color
	new_exterior_border_highlight.modulate = border_exterior_highlight_color
	new_interior_border.modulate = border_interior_color
	
	new_exterior_border.z_index = -2
	new_exterior_border_highlight.z_index = -3
	new_interior_border.z_index = -1
	
	board.add_child(new_exterior_border)
	board.add_child(new_exterior_border_highlight)
	board.add_child(new_interior_border)
	
func fit_board():
	var camera:Camera2D = get_viewport().get_camera_2d()
	
	if board == null:
		return
	
	if board_area_fitter == null:
		return
	
	var board_size:Vector2 = Vector2(slot_width_and_height * columns+ (border_width.x*2 + border_highlight_width), slot_width_and_height * rows+ (border_width.y*2 +border_highlight_width))
	var fit_area_rect:Rect2 = board_area_fitter.get_global_rect()
	print("Fit Area Rect Pos ", fit_area_rect.position)
	print("Fit Area Rect center ", fit_area_rect.get_center())
	print("Fit Area Rect width ", fit_area_rect.size.x)
	print("Fit Area Rect height ", fit_area_rect.size.y)
	print("Fit area pos ", board_area_fitter.global_position)
	
	game_board.global_position = Vector2(get_canvas_transform().affine_inverse() * fit_area_rect.position) + (fit_area_rect.size*2)
	var fit_area_size_world = Vector2(fit_area_rect.size.x / camera.zoom.x, fit_area_rect.size.y / camera.zoom.y)
	
	var scale_x:float = fit_area_size_world.x / board_size.x
	var scale_y:float = fit_area_size_world.y / board_size.y
	var new_board_scale:float = min(scale_x, scale_y)
	game_board.scale = Vector2(new_board_scale, new_board_scale)
