@tool
class_name BoardBuilder
extends Node2D

@export_tool_button("Rebuild Board") var rebuild_board_action:Callable = rebuild_board

@export_group("Editor Fallback Size")
@export var columns:int = 7
@export var rows:int = 6

@export_group("Border")
@export var border_width:Vector2 = Vector2(100, 100)
@export var border_highlight_width:int = 10
@export var border_corner_rounding:int = 16
@export_color_no_alpha var border_exterior_color:Color
@export_color_no_alpha var border_exterior_highlight_color:Color
@export_color_no_alpha var border_interior_color:Color

var game_board:Node2D = null
var board:BoardManager = null
var token_pool:Node2D = null
var board_area_fitter:PanelContainer = null
var match_session:MatchSession = null

var slot_instance:PackedScene = preload("res://Scenes/Slot.tscn")
var slot_width_and_height:float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		resolve_editor_references()
		rebuild_board(false)


func setup(new_game_board:Node2D, new_board:BoardManager, new_token_pool:Node2D, new_board_area_fitter:PanelContainer) -> void:
	game_board = new_game_board
	board = new_board
	token_pool = new_token_pool
	board_area_fitter = new_board_area_fitter
	
	connect_fit_area_signal()


func resolve_editor_references() -> void:
	game_board = get_parent() as Node2D
	board = get_node_or_null("../Board Manager") as BoardManager
	token_pool = get_node_or_null("../Token Pool") as Node2D


func connect_fit_area_signal() -> void:
	if Engine.is_editor_hint():
		return
	
	if board_area_fitter == null:
		return
	
	if board_area_fitter.resized.is_connected(_on_board_area_resized) == false:
		board_area_fitter.resized.connect(_on_board_area_resized)


func _on_board_area_resized() -> void:
	call_deferred("fit_board")


func rebuild_board(reapply_match_session:bool = true) -> void:
	if reapply_match_session and Engine.is_editor_hint() == false and match_session != null:
		apply_match_session(match_session, false)
	
	clear_board()
	setup_board_settings()
	build_board()


func apply_match_session(new_match_session:MatchSession, rebuild_if_size_changed:bool = true) -> bool:
	if Engine.is_editor_hint():
		return false
	
	if new_match_session == null:
		return false
	
	match_session = new_match_session
	
	var new_columns:int = new_match_session.get_board_columns()
	var new_rows:int = new_match_session.get_board_rows()
	var size_changed:bool = columns != new_columns or rows != new_rows
	
	columns = new_columns
	rows = new_rows
	
	apply_dimensions_to_board()
	
	if board != null and board.settings != null:
		board.settings.tokens_to_win = new_match_session.get_tokens_to_win()
	
	if size_changed and rebuild_if_size_changed:
		rebuild_board(false)
	
	return size_changed


func apply_dimensions_to_board() -> void:
	if Engine.is_editor_hint():
		return
	
	if board == null:
		return
	
	if board.settings == null:
		return
	
	board.settings.columns = columns
	board.settings.rows = rows
	board.refresh_gravity_order()


func clear_board() -> void:
	if board != null:
		clear_children(board)
	
	if token_pool != null:
		clear_children(token_pool)
	
	if Engine.is_editor_hint():
		return
	
	if board == null:
		return
	
	board.clear_board_state()
	board.hovered_slot = null


func clear_children(parent_node:Node) -> void:
	if parent_node == null:
		return
	
	for child in parent_node.get_children():
		parent_node.remove_child(child)
		child.free()


func build_board() -> void:
	if board == null:
		return
	
	if Engine.is_editor_hint():
		board.visible = false
	else:
		apply_dimensions_to_board()
		board.visible = true
	
	for x in range(columns):
		for y in range(rows):
			create_slot(x, y)
	
	resize_border_rectangles()
	
	if Engine.is_editor_hint() == false:
		board.setup_empty_board_state()
	
	call_deferred("fit_board")


func setup_board_settings() -> void:
	if slot_instance == null:
		return
	
	var new_slot:Node = slot_instance.instantiate()
	var front:Sprite2D = new_slot.find_child("Front") as Sprite2D
	
	if front == null:
		new_slot.free()
		return
	
	var texture:Texture2D = front.texture
	
	if texture == null:
		new_slot.free()
		return
	
	slot_width_and_height = float(texture.get_width())
	
	if Engine.is_editor_hint() == false and board != null:
		board.slot_size = Vector2(slot_width_and_height, slot_width_and_height)
		board.refresh_geometry()
	
	new_slot.free()


func create_slot(x:int, y:int) -> void:
	if slot_instance == null:
		return
	
	var new_slot:Slot = slot_instance.instantiate() as Slot
	
	if new_slot == null:
		return
	
	var front:Sprite2D = new_slot.find_child("Front") as Sprite2D
	
	if front == null or front.texture == null:
		new_slot.free()
		return
	
	var texture:Texture2D = front.texture
	slot_width_and_height = float(texture.get_width())
	
	var scaled_slot_width:float = slot_width_and_height * new_slot.scale.x
	var scaled_slot_height:float = slot_width_and_height * new_slot.scale.y
	var offset_x:float = scaled_slot_width * float(columns) * 0.5
	var offset_y:float = scaled_slot_height * float(rows) * 0.5
	
	new_slot.position.x = x * scaled_slot_width - offset_x + scaled_slot_width * 0.5
	new_slot.position.y = y * scaled_slot_height - offset_y + scaled_slot_height * 0.5
	
	var slot_pos:Vector2i = Vector2i(x, y)
	var types:Array = []
	
	if Engine.is_editor_hint() == false:
		types = assign_slot_types(x, y)
	
	new_slot.setup_slot(board, slot_pos, types)
	board.add_child(new_slot)


func assign_slot_types(x:int, y:int) -> Array:
	var slot_types:Array = []
	
	if x == 0:
		slot_types.append(Global.SLOT_TYPE.LEFT_EDGE)
	
	if x == columns - 1:
		slot_types.append(Global.SLOT_TYPE.RIGHT_EDGE)
	
	if y == 0:
		slot_types.append(Global.SLOT_TYPE.TOP_EDGE)
	
	if y == rows - 1:
		slot_types.append(Global.SLOT_TYPE.BOTTOM_EDGE)
	
	if slot_types.is_empty():
		slot_types.append(Global.SLOT_TYPE.INTERIOR)
	
	return slot_types


func resize_border_rectangles() -> void:
	if board == null:
		return
	
	var new_exterior_border:Sprite2D = Sprite2D.new()
	var new_exterior_border_highlight:Sprite2D = Sprite2D.new()
	var new_interior_border:Sprite2D = Sprite2D.new()
	
	var exterior_texture:ShapeTexture2D = ShapeTexture2D.new()
	var exterior_highlight_texture:ShapeTexture2D = ShapeTexture2D.new()
	var interior_texture:ShapeTexture2D = ShapeTexture2D.new()
	
	var exterior_shape:DrawableRectangle = DrawableRectangle.new()
	var exterior_highlight_shape:DrawableRectangle = DrawableRectangle.new()
	var interior_shape:DrawableRectangle = DrawableRectangle.new()
	
	exterior_shape.corner_rounding = border_corner_rounding
	exterior_highlight_shape.corner_rounding = border_corner_rounding
	interior_shape.corner_rounding = border_corner_rounding
	
	exterior_texture.shape = exterior_shape
	exterior_highlight_texture.shape = exterior_highlight_shape
	interior_texture.shape = interior_shape
	
	var board_size_pixels:Vector2 = get_board_content_size()
	
	exterior_texture.size = board_size_pixels + border_width * 2.0
	exterior_highlight_texture.size = board_size_pixels + border_width * 2.0 + Vector2.ONE * float(border_highlight_width)
	interior_texture.size = board_size_pixels + border_width
	
	new_exterior_border.texture = exterior_texture
	new_exterior_border_highlight.texture = exterior_highlight_texture
	new_interior_border.texture = interior_texture
	
	new_exterior_border.position = Vector2.ONE * float(border_highlight_width) * 0.5
	new_exterior_border_highlight.position = Vector2.ZERO
	new_interior_border.position = Vector2.ZERO
	
	new_exterior_border.modulate = border_exterior_color
	new_exterior_border_highlight.modulate = border_exterior_highlight_color
	new_interior_border.modulate = border_interior_color
	
	new_exterior_border.z_index = -2
	new_exterior_border_highlight.z_index = -3
	new_interior_border.z_index = -1
	
	board.add_child(new_exterior_border)
	board.add_child(new_exterior_border_highlight)
	board.add_child(new_interior_border)


func get_board_content_size() -> Vector2:
	return Vector2(slot_width_and_height * float(columns), slot_width_and_height * float(rows))


func get_board_total_size() -> Vector2:
	return get_board_content_size() + border_width * 2.0 + Vector2.ONE * float(border_highlight_width)


func fit_board() -> void:
	if Engine.is_editor_hint():
		return
	
	if game_board == null:
		return
	
	if board == null:
		return
	
	if board_area_fitter == null:
		return
	
	var board_size:Vector2 = get_board_total_size()
	
	if board_size.x <= 0.0 or board_size.y <= 0.0:
		return
	
	var fit_area_rect:Rect2 = board_area_fitter.get_global_rect()
	var inverse_canvas_transform:Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var fit_area_top_left_world:Vector2 = inverse_canvas_transform * fit_area_rect.position
	var fit_area_bottom_right_world:Vector2 = inverse_canvas_transform * fit_area_rect.end
	var fit_area_center_world:Vector2 = inverse_canvas_transform * fit_area_rect.get_center()
	var fit_area_size_world:Vector2 = Vector2(abs(fit_area_bottom_right_world.x - fit_area_top_left_world.x), abs(fit_area_bottom_right_world.y - fit_area_top_left_world.y))
	var scale_x:float = fit_area_size_world.x / board_size.x
	var scale_y:float = fit_area_size_world.y / board_size.y
	var new_board_scale:float = min(scale_x, scale_y)
	
	game_board.global_position = fit_area_center_world
	game_board.scale = Vector2(new_board_scale, new_board_scale)
