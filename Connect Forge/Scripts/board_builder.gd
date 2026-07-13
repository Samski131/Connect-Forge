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

@onready var game_board:Node2D = get_parent() as Node2D
@onready var board:BoardManager = $"../Board Manager"
@onready var token_pool:Node2D = $"../Token Pool"

var slot_instance:PackedScene = preload("res://Scenes/Slot.tscn")
var sprite_2d_rectangle:PackedScene = preload("uid://dcdpt1usuprbf")
var slot_width_and_height:float = 0.0
var board_area_fitter:PanelContainer = null


func _ready() -> void:
	board_area_fitter = get_tree().get_first_node_in_group("board area fitter") as PanelContainer
	connect_fit_area_signal()
	rebuild_board()


func connect_fit_area_signal() -> void:
	if Engine.is_editor_hint():
		return
	
	if board_area_fitter == null:
		return
	
	if board_area_fitter.resized.is_connected(_on_board_area_resized) == false:
		board_area_fitter.resized.connect(_on_board_area_resized)


func _on_board_area_resized() -> void:
	call_deferred("fit_board")


func rebuild_board(use_match_config:bool = true) -> void:
	if use_match_config and Engine.is_editor_hint() == false:
		apply_match_config(MatchData.config, false)
	
	clear_board()
	setup_board_settings()
	build_board()


func apply_match_config(
	config:MatchConfig,
	rebuild_if_size_changed:bool = true
) -> bool:
	if Engine.is_editor_hint():
		return false
	
	if config == null:
		return false
	
	var new_columns:int = clamp(
		config.board_columns,
		MatchConfig.MINIMUM_BOARD_COLUMNS,
		MatchConfig.MAXIMUM_BOARD_COLUMNS
	)
	
	var new_rows:int = clamp(
		config.board_rows,
		MatchConfig.MINIMUM_BOARD_ROWS,
		MatchConfig.MAXIMUM_BOARD_ROWS
	)
	
	var size_changed:bool = (
		columns != new_columns or
		rows != new_rows
	)
	
	columns = new_columns
	rows = new_rows
	
	apply_dimensions_to_board()
	
	if board != null:
		board.settings.tokens_to_win = clamp(
			config.tokens_to_win,
			MatchConfig.MINIMUM_TOKENS_TO_WIN,
			max(columns, rows)
		)
	
	if size_changed and rebuild_if_size_changed:
		rebuild_board(false)
	
	return size_changed


func apply_dimensions_to_board() -> void:
	if Engine.is_editor_hint():
		return
	
	if board == null:
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
	
	board.refresh_token_pool()
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
		board.slot_size = Vector2(
			slot_width_and_height,
			slot_width_and_height
		)
		
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
	
	var scaled_slot_width:float = (
		slot_width_and_height *
		new_slot.scale.x
	)
	
	var scaled_slot_height:float = (
		slot_width_and_height *
		new_slot.scale.y
	)
	
	var offset_x:float = (
		scaled_slot_width *
		float(columns) *
		0.5
	)
	
	var offset_y:float = (
		scaled_slot_height *
		float(rows) *
		0.5
	)
	
	new_slot.position.x = (
		x * scaled_slot_width -
		offset_x +
		scaled_slot_width * 0.5
	)
	
	new_slot.position.y = (
		y * scaled_slot_height -
		offset_y +
		scaled_slot_height * 0.5
	)
	
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
	if sprite_2d_rectangle == null:
		return
	
	var new_exterior_border:Sprite2D = (
		sprite_2d_rectangle.instantiate() as Sprite2D
	)
	
	var new_exterior_border_highlight:Sprite2D = (
		sprite_2d_rectangle.instantiate() as Sprite2D
	)
	
	var new_interior_border:Sprite2D = (
		sprite_2d_rectangle.instantiate() as Sprite2D
	)
	
	if new_exterior_border == null:
		return
	
	if new_exterior_border_highlight == null:
		new_exterior_border.free()
		return
	
	if new_interior_border == null:
		new_exterior_border.free()
		new_exterior_border_highlight.free()
		return
	
	new_exterior_border.texture = ShapeTexture2D.new()
	new_exterior_border_highlight.texture = ShapeTexture2D.new()
	new_interior_border.texture = ShapeTexture2D.new()
	
	new_exterior_border.texture.shape = DrawableRectangle.new()
	new_exterior_border_highlight.texture.shape = DrawableRectangle.new()
	new_interior_border.texture.shape = DrawableRectangle.new()
	
	new_exterior_border.texture.shape.corner_rounding = (
		border_corner_rounding
	)
	
	new_exterior_border_highlight.texture.shape.corner_rounding = (
		border_corner_rounding
	)
	
	new_interior_border.texture.shape.corner_rounding = (
		border_corner_rounding
	)
	
	new_exterior_border.position = (
		Vector2.ONE *
		float(border_highlight_width) *
		0.5
	)
	
	new_exterior_border_highlight.position = Vector2.ZERO
	new_interior_border.position = Vector2.ZERO
	
	var board_size_pixels:Vector2 = get_board_content_size()
	
	new_exterior_border.texture.size = (
		board_size_pixels +
		border_width * 2.0
	)
	
	new_exterior_border_highlight.texture.size = (
		board_size_pixels +
		border_width * 2.0 +
		Vector2.ONE * float(border_highlight_width)
	)
	
	new_interior_border.texture.size = (
		board_size_pixels +
		border_width
	)
	
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
	return Vector2(
		slot_width_and_height * float(columns),
		slot_width_and_height * float(rows)
	)


func get_board_total_size() -> Vector2:
	return (
		get_board_content_size() +
		border_width * 2.0 +
		Vector2.ONE * float(border_highlight_width)
	)


func fit_board() -> void:
	if Engine.is_editor_hint():
		return
	
	if game_board == null:
		return
	
	if board == null:
		return
	
	if board_area_fitter == null:
		board_area_fitter = (
			get_tree().get_first_node_in_group(
				"board area fitter"
			) as PanelContainer
		)
	
	if board_area_fitter == null:
		return
	
	var board_size:Vector2 = get_board_total_size()
	
	if board_size.x <= 0.0 or board_size.y <= 0.0:
		return
	
	var fit_area_rect:Rect2 = board_area_fitter.get_global_rect()
	
	var inverse_canvas_transform:Transform2D = (
		get_viewport()
		.get_canvas_transform()
		.affine_inverse()
	)
	
	var fit_area_top_left_world:Vector2 = (
		inverse_canvas_transform *
		fit_area_rect.position
	)
	
	var fit_area_bottom_right_world:Vector2 = (
		inverse_canvas_transform *
		fit_area_rect.end
	)
	
	var fit_area_center_world:Vector2 = (
		inverse_canvas_transform *
		fit_area_rect.get_center()
	)
	
	var fit_area_size_world:Vector2 = Vector2(
		abs(
			fit_area_bottom_right_world.x -
			fit_area_top_left_world.x
		),
		abs(
			fit_area_bottom_right_world.y -
			fit_area_top_left_world.y
		)
	)
	
	var scale_x:float = (
		fit_area_size_world.x /
		board_size.x
	)
	
	var scale_y:float = (
		fit_area_size_world.y /
		board_size.y
	)
	
	var new_board_scale:float = min(
		scale_x,
		scale_y
	)
	
	game_board.global_position = fit_area_center_world
	game_board.scale = Vector2(
		new_board_scale,
		new_board_scale
	)
