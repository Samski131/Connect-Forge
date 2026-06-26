class_name BoardManager
extends Node2D

var token_pool:Node2D
var settings:BoardSetting = BoardSetting.new()
var state:BoardState
var geometry:BoardGeometry
var trigger_resolver:BoardTriggerResolver
var token_mover:BoardTokenMover
var gravity_order:BoardGravityOrder

var hovered_slot:Slot = null
var slot_size:Vector2 = Vector2.ZERO

@onready var visuals:BoardVisualManager = $"../Board Visual Manager"

func _ready():
	refresh_token_pool()
	
	if state == null:
		state = BoardState.new(settings)
	
	if geometry == null:
		geometry = BoardGeometry.new(settings, self, slot_size)
	else:
		geometry.slot_size = slot_size
	
	if trigger_resolver == null:
		trigger_resolver = BoardTriggerResolver.new(self)
	
	if token_mover == null:
		token_mover = BoardTokenMover.new(self)
	
	if gravity_order == null:
		gravity_order = BoardGravityOrder.new(settings)
	
	refresh_gravity_order()
	
func refresh_geometry() -> void:
	if geometry == null:
		geometry = BoardGeometry.new(settings, self, slot_size)
	else:
		geometry.slot_size = slot_size

func setup_empty_board_state() -> void:
	if state == null:
		state = BoardState.new(settings)
	
	state.settings = settings
	state.setup_empty_board()


func clear_board_state() -> void:
	if state != null:
		state.clear()
	
	if trigger_resolver != null:
		trigger_resolver.clear_pending_pass_triggers()

func get_token(pos:Vector2i) -> Token:
	if state == null:
		return null
	
	return state.get_token(pos)

func get_adjacent_pos(x:int,y:int,direction:BoardSetting.DIRECTION) -> Vector2i:
	return geometry.get_adjacent_pos(Vector2i(x, y), direction)

func get_adjacent_token(x:int,y:int,direction:BoardSetting.DIRECTION) -> Token:
	var check_token_pos := get_adjacent_pos(x, y, direction)
	return get_token(check_token_pos)
	
func add_token_to_board(new_token:Token, slot_pos:Vector2i) -> bool:
	return state.add_token(new_token, slot_pos)

func remove_token_from_board(slot_pos:Vector2i) -> bool:
	return state.remove_token(slot_pos)
	
func replace_token_on_board(new_token:Token, slot_pos:Vector2i) -> bool:
	return state.replace_token(new_token, slot_pos)
	
func is_position_in_bounds(pos:Vector2i) -> bool:
	return state.is_position_in_bounds(pos)
	
func create_new_token(token_scene:PackedScene, slot_pos:Vector2i, player_id:int) -> Token:
	return token_mover.create_new_token(token_scene, slot_pos, player_id)

func move_token_on_board(token:Token, new_pos:Vector2i, move_visual:BoardVisualManager.MOVE_VISUAL = BoardVisualManager.MOVE_VISUAL.SLIDE, extra_parallel_effects:Array[BoardVisualEffect] = []) -> bool:
	return token_mover.move_token_on_board(token, new_pos, move_visual, extra_parallel_effects)

func destroy_token(token:Token) -> bool:
	return token_mover.destroy_token(token)

func set_hovered_slot(slot:Slot):
	hovered_slot = slot

func clear_hovered_slot(slot:Slot):
	if hovered_slot == slot:
		hovered_slot = null

func slot_to_global_position(slot_pos:Vector2i) -> Vector2:
	return geometry.slot_to_global_position(slot_pos)
	
func global_position_to_slot(global_pos:Vector2) -> Vector2i:
	return geometry.global_position_to_slot(global_pos)

func get_fall_path(token:Token) -> Array[Vector2i]:
	return trigger_resolver.get_fall_path(token)


func find_first_pass_trigger_step(moving_token:Token, start_pos:Vector2i, path:Array[Vector2i]) -> Dictionary:
	return trigger_resolver.find_first_pass_trigger_step(moving_token, start_pos, path)


func has_passing_reactor_for_step(moving_token:Token, from_pos:Vector2i, to_pos:Vector2i) -> bool:
	return trigger_resolver.has_passing_reactor_for_step(moving_token, from_pos, to_pos)


func resolve_landing_triggers(landing_token:Token) -> bool:
	return trigger_resolver.resolve_landing_triggers(landing_token)


func resolve_passing_triggers(moving_token:Token, from_pos:Vector2i, to_pos:Vector2i) -> bool:
	return trigger_resolver.resolve_passing_triggers(moving_token, from_pos, to_pos)

func resolve_line_full_triggers() -> bool:
	return trigger_resolver.resolve_line_full_triggers()
	
func queue_passing_trigger(moving_token:Token, from_pos:Vector2i, to_pos:Vector2i) -> void:
	trigger_resolver.queue_passing_trigger( moving_token, from_pos, to_pos)


func resolve_pending_pass_triggers() -> bool:
	return trigger_resolver.resolve_pending_pass_triggers()

func refresh_token_pool() -> void:
	token_pool = get_tree().get_first_node_in_group("token pool")

func refresh_gravity_order() -> void:
	if gravity_order == null:
		gravity_order = BoardGravityOrder.new(settings)
	else:
		gravity_order.settings = settings

func get_positions_in_gravity_order() -> Array[Vector2i]:
	if gravity_order == null:
		gravity_order = BoardGravityOrder.new(settings)
	
	return gravity_order.get_positions_in_gravity_order()
