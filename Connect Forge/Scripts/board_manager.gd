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

func get_relative_adjacent_pos(x:int, y:int, direction:BoardSetting.RELATIVE_DIRECTION) -> Vector2i:
	return geometry.get_relative_adjacent_pos(Vector2i(x, y), direction)

func get_relative_adjacent_token(x:int, y:int, direction:BoardSetting.RELATIVE_DIRECTION) -> Token:
	var check_token_pos:Vector2i = get_relative_adjacent_pos(x, y, direction)
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

func rotate_gravity(clockwise:bool = true) -> void:
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	var gravity_order:Array[BoardSetting.GRID_DIRECTION] = [
		GRID_DIRECTION.UP,
		GRID_DIRECTION.RIGHT,
		GRID_DIRECTION.DOWN,
		GRID_DIRECTION.LEFT
	]
	
	var current_index:int = gravity_order.find(settings.gravity_direction)
	
	if current_index == -1:
		set_gravity_direction(GRID_DIRECTION.DOWN)
		return
	
	var step:int = 1
	
	if clockwise == false:
		step = -1
	
	var new_index:int = current_index + step
	
	if new_index >= gravity_order.size():
		new_index = 0
	
	if new_index < 0:
		new_index = gravity_order.size() - 1
	
	var new_direction:BoardSetting.GRID_DIRECTION = gravity_order[new_index]
	set_gravity_direction(new_direction)
	

func queue_all_tokens_gravity_visual_rotation() -> void:
	if visuals == null:
		apply_all_tokens_gravity_visual_rotation()
		return
	
	var effects:Array[BoardVisualEffect] = []
	
	for pos in get_positions_in_gravity_order():
		var token:Token = get_token(pos)
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		if token.being_destroyed:
			continue
		
		var target_rotation_degrees:float = get_gravity_visual_rotation_degrees()
		var effect:TokenGravityAlignVisualEffect = TokenGravityAlignVisualEffect.new(
			token,
			target_rotation_degrees,
			visuals.gravity_rotate_duration
		)
		
		effects.append(effect)
	
	if effects.is_empty():
		return
	
	visuals.queue_effect(ParallelVisualEffect.new(effects))


func apply_all_tokens_gravity_visual_rotation() -> void:
	for pos in get_positions_in_gravity_order():
		var token:Token = get_token(pos)
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		apply_token_gravity_visual(token)

func set_gravity_direction(new_direction:BoardSetting.GRID_DIRECTION, animate_visual:bool = true) -> bool:
	if settings.gravity_direction == new_direction:
		return false
	
	settings.gravity_direction = new_direction
	
	refresh_gravity_order()
	get_tree().call_group("slot", "gravity_change")
	get_tree().call_group("token", "reset_resolved")
	
	if animate_visual:
		queue_all_tokens_gravity_visual_rotation()
	else:
		apply_all_tokens_gravity_visual_rotation()
	
	return true

func get_gravity_visual_rotation_degrees() -> float:
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	match settings.gravity_direction:
		GRID_DIRECTION.DOWN:
			return 0.0
		GRID_DIRECTION.LEFT:
			return 90.0
		GRID_DIRECTION.UP:
			return 180.0
		GRID_DIRECTION.RIGHT:
			return 270.0
	
	return 0.0
	
func apply_token_gravity_visual(token:Token) -> void:
	if token == null:
		return
	
	if is_instance_valid(token) == false:
		return
	
	if token.sprites == null:
		return
	
	var target_rotation_degrees:float = get_gravity_visual_rotation_degrees()
	token.gravity_visual_rotation_degrees = target_rotation_degrees
	token.sprites.rotation_degrees = target_rotation_degrees
