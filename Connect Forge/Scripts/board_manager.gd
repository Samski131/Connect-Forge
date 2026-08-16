class_name BoardManager
extends Node2D

const NETWORK_TOKEN_ENTRY_SIZE:int = 8
const NETWORK_TOKEN_X:int = 0
const NETWORK_TOKEN_Y:int = 1
const NETWORK_TOKEN_TYPE:int = 2
const NETWORK_TOKEN_PLAYER_ID:int = 3
const NETWORK_TOKEN_IS_FLIPPED:int = 4
const NETWORK_TOKEN_CHARGES:int = 5
const NETWORK_TOKEN_PLACEMENT_DATA:int = 6
const NETWORK_TOKEN_STATE_DATA:int = 7

var token_pool:Node2D = null
var visuals:BoardVisualManager = null
var match_session:MatchSession = null
var replay_recorder:ReplayRecorder = null

var settings:BoardSetting = BoardSetting.new()
var state:BoardState = null
var geometry:BoardGeometry = null
var trigger_resolver:BoardTriggerResolver = null
var token_mover:BoardTokenMover = null
var gravity_order:BoardGravityOrder = null

var hovered_slot:Slot = null
var slot_size:Vector2 = Vector2.ZERO



func _ready() -> void:
	initialize_components()


func setup(new_token_pool:Node2D, new_visuals:BoardVisualManager) -> void:
	token_pool = new_token_pool
	visuals = new_visuals
	
	if visuals != null:
		visuals.set_replay_recorder(replay_recorder)
	
	initialize_components()


func set_match_session(new_match_session:MatchSession) -> void:
	match_session = new_match_session


func set_replay_recorder(new_replay_recorder:ReplayRecorder) -> void:
	replay_recorder = new_replay_recorder
	
	if visuals != null:
		visuals.set_replay_recorder(replay_recorder)


func get_replay_recorder() -> ReplayRecorder:
	return replay_recorder


func register_replay_token(token:Token) -> int:
	if replay_recorder == null:
		return -1
	
	if replay_recorder.is_recording() == false:
		return -1
	
	return replay_recorder.register_token(token)
	
func record_replay_token_update(token:Token, presentation_effect:BoardVisualEffect = null) -> bool:
	if replay_recorder == null:
		return false
	
	if replay_recorder.is_recording() == false:
		return false
	
	if match_session == null:
		return false
	
	var presentation_action:ReplayAction = null
	
	if presentation_effect != null:
		presentation_action = presentation_effect.to_replay_action()
	
	return replay_recorder.record_token_update(token, match_session.current_round_number, match_session.current_turn_number, match_session.current_player_id, presentation_action)


func record_replay_token_updates(tokens:Array[Token], presentation_effect:BoardVisualEffect = null) -> bool:
	if replay_recorder == null:
		return false
	
	if replay_recorder.is_recording() == false:
		return false
	
	if match_session == null:
		return false
	
	if tokens.is_empty():
		return false
	
	var presentation_action:ReplayAction = null
	
	if presentation_effect != null:
		presentation_action = presentation_effect.to_replay_action()
	
	return replay_recorder.record_token_updates(tokens, match_session.current_round_number, match_session.current_turn_number, match_session.current_player_id, presentation_action)
	
func record_replay_presentation_effect(effect:BoardVisualEffect) -> bool:
	if replay_recorder == null:
		return false
	
	if replay_recorder.is_recording() == false:
		return false
	
	if match_session == null:
		return false
	
	if effect == null:
		return false
	
	if visuals != null:
		if visuals.is_move_batch_active():
			return true
	
	var presentation_action:ReplayAction = effect.to_replay_action()
	
	if presentation_action == null:
		return true
	
	return replay_recorder.record_presentation(presentation_action, match_session.current_round_number, match_session.current_turn_number, match_session.current_player_id)


func record_replay_gravity_change(previous_direction:BoardSetting.GRID_DIRECTION, new_direction:BoardSetting.GRID_DIRECTION, effect:BoardVisualEffect) -> bool:
	if replay_recorder == null:
		return false
	
	if replay_recorder.is_recording() == false:
		return false
	
	if match_session == null:
		return false
	
	var previous_gravity:String = get_replay_gravity_id(previous_direction)
	var new_gravity:String = get_replay_gravity_id(new_direction)
	
	if previous_gravity == "":
		return false
	
	if new_gravity == "":
		return false
	
	var presentation_action:ReplayAction = null
	
	if effect != null:
		presentation_action = effect.to_replay_action()
	
	return replay_recorder.record_gravity_change(previous_gravity, new_gravity, presentation_action, match_session.current_round_number, match_session.current_turn_number, match_session.current_player_id)


func get_replay_gravity_id(direction:BoardSetting.GRID_DIRECTION) -> String:
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	match direction:
		GRID_DIRECTION.UP:
			return ReplayFormat.GRAVITY_UP
		
		GRID_DIRECTION.RIGHT:
			return ReplayFormat.GRAVITY_RIGHT
		
		GRID_DIRECTION.DOWN:
			return ReplayFormat.GRAVITY_DOWN
		
		GRID_DIRECTION.LEFT:
			return ReplayFormat.GRAVITY_LEFT
	
	return ""
	
	
func get_player_count() -> int:
	if match_session == null:
		return 0
	
	return match_session.get_player_count()


func is_valid_player_id(player_id:int) -> bool:
	if match_session == null:
		return false
	
	return match_session.is_valid_player_id(player_id)


func get_player_palette(player_id:int) -> ColorPalette:
	if match_session == null:
		return null
	
	return match_session.get_player_palette(player_id)


func initialize_components() -> void:
	if state == null:
		state = BoardState.new(settings)
	
	if geometry == null:
		geometry = BoardGeometry.new(settings, self, slot_size)
	else:
		geometry.settings = settings
		geometry.board_node = self
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
		geometry.settings = settings
		geometry.board_node = self
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
	if geometry == null:
		return Vector2i(x, y)
	
	return geometry.get_relative_adjacent_pos(Vector2i(x, y), direction)


func get_relative_adjacent_token(x:int, y:int, direction:BoardSetting.RELATIVE_DIRECTION) -> Token:
	var check_token_pos:Vector2i = get_relative_adjacent_pos(x, y, direction)
	return get_token(check_token_pos)


func add_token_to_board(new_token:Token, slot_pos:Vector2i) -> bool:
	if state == null:
		return false
	
	return state.add_token(new_token, slot_pos)


func remove_token_from_board(slot_pos:Vector2i) -> bool:
	if state == null:
		return false
	
	return state.remove_token(slot_pos)


func replace_token_on_board(new_token:Token, slot_pos:Vector2i) -> bool:
	if state == null:
		return false
	
	return state.replace_token(new_token, slot_pos)


func is_position_in_bounds(pos:Vector2i) -> bool:
	if state == null:
		return false
	
	return state.is_position_in_bounds(pos)


func create_new_token(token_scene:PackedScene, slot_pos:Vector2i, player_id:int, is_flipped:bool) -> Token:
	if token_mover == null:
		return null
	
	return token_mover.create_new_token(token_scene, slot_pos, player_id, is_flipped)


func move_token_on_board(token:Token, new_pos:Vector2i, move_visual:BoardVisualManager.MOVE_VISUAL = BoardVisualManager.MOVE_VISUAL.SLIDE, extra_parallel_effects:Array[BoardVisualEffect] = [], check_pass_triggers:bool = true, movement_path:Array[Vector2i] = []) -> bool:
	if token_mover == null:
		return false
	
	return token_mover.move_token_on_board(token, new_pos, move_visual, extra_parallel_effects, check_pass_triggers, movement_path)


func destroy_token(token:Token) -> bool:
	if token_mover == null:
		return false
	
	return token_mover.destroy_token(token)

func destroy_tokens(tokens:Array[Token], presentation_effect:BoardVisualEffect = null) -> bool:
	if token_mover == null:
		return false
	
	return token_mover.destroy_tokens(tokens, presentation_effect)
	
	
func set_hovered_slot(slot:Slot) -> void:
	hovered_slot = slot


func clear_hovered_slot(slot:Slot) -> void:
	if hovered_slot == slot:
		hovered_slot = null


func slot_to_global_position(slot_pos:Vector2i) -> Vector2:
	if geometry == null:
		return global_position
	
	return geometry.slot_to_global_position(slot_pos)


func global_position_to_slot(global_pos:Vector2) -> Vector2i:
	if geometry == null:
		return Vector2i(-1, -1)
	
	return geometry.global_position_to_slot(global_pos)


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
	var gravity_order_directions:Array[BoardSetting.GRID_DIRECTION] = [GRID_DIRECTION.UP, GRID_DIRECTION.RIGHT, GRID_DIRECTION.DOWN, GRID_DIRECTION.LEFT]
	var current_index:int = gravity_order_directions.find(settings.gravity_direction)
	
	if current_index == -1:
		set_gravity_direction(GRID_DIRECTION.DOWN)
		return
	
	var step:int = 1
	
	if clockwise == false:
		step = -1
	
	var new_index:int = current_index + step
	
	if new_index >= gravity_order_directions.size():
		new_index = 0
	
	if new_index < 0:
		new_index = gravity_order_directions.size() - 1
	
	var new_direction:BoardSetting.GRID_DIRECTION = gravity_order_directions[new_index]
	set_gravity_direction(new_direction)


func create_all_tokens_gravity_visual_rotation_effect() -> BoardVisualEffect:
	if visuals == null:
		return null
	
	var effects:Array[BoardVisualEffect] = []
	var target_rotation_degrees:float = get_gravity_visual_rotation_degrees()
	
	for pos in get_positions_in_gravity_order():
		var token:Token = get_token(pos)
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		if token.being_destroyed:
			continue
		
		var effect:TokenGravityAlignVisualEffect = TokenGravityAlignVisualEffect.new(token, target_rotation_degrees, visuals.gravity_rotate_duration)
		effects.append(effect)
	
	if effects.is_empty():
		return null
	
	return ParallelVisualEffect.new(effects)


func queue_all_tokens_gravity_visual_rotation() -> void:
	if visuals == null:
		apply_all_tokens_gravity_visual_rotation()
		return
	
	var effect:BoardVisualEffect = create_all_tokens_gravity_visual_rotation_effect()
	
	if effect == null:
		return
	
	visuals.queue_effect(effect)


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
	
	var previous_direction:BoardSetting.GRID_DIRECTION = settings.gravity_direction
	
	settings.gravity_direction = new_direction
	
	refresh_gravity_order()
	get_tree().call_group("slot", "refresh_visual_state")
	get_tree().call_group("token", "reset_resolved")
	
	if animate_visual:
		var gravity_effect:BoardVisualEffect = create_all_tokens_gravity_visual_rotation_effect()
		
		record_replay_gravity_change(previous_direction, new_direction, gravity_effect)
		
		if visuals != null and gravity_effect != null:
			visuals.queue_effect(gravity_effect)
		else:
			apply_all_tokens_gravity_visual_rotation()
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
	
	
func get_all_tokens_on_board() -> Array[Token]:
	var found_tokens:Array[Token] = []
	
	if state == null:
		return found_tokens
	
	for y in range(settings.rows):
		for x in range(settings.columns):
			var pos:Vector2i = Vector2i(x, y)
			var token:Token = get_token(pos)
			
			if token == null:
				continue
			
			if is_instance_valid(token) == false:
				continue
			
			if found_tokens.has(token):
				continue
			
			found_tokens.append(token)
	
	return found_tokens

func create_network_board_snapshot() -> Array:
	var snapshot:Array = []
	
	for y in range(settings.rows):
		for x in range(settings.columns):
			var slot_pos:Vector2i = Vector2i(x, y)
			var token:Token = get_token(slot_pos)
			
			if token == null:
				continue
			
			if is_instance_valid(token) == false:
				continue
			
			if token.being_destroyed:
				continue
			
			var token_entry:Array = [
				x,
				y,
				int(token.token_type),
				token.player_id,
				token.is_flipped,
				token.charges,
				token.get_network_placement_data(),
				token.create_network_state_data()
			]
			
			snapshot.append(token_entry)
	
	return snapshot


func is_network_board_snapshot_valid(snapshot:Array) -> bool:
	var occupied_positions:Dictionary = {}
	
	for token_entry_value in snapshot:
		if typeof(token_entry_value) != TYPE_ARRAY:
			return false
		
		var token_entry:Array = token_entry_value
		
		if token_entry.size() != NETWORK_TOKEN_ENTRY_SIZE:
			return false
		
		var slot_pos:Vector2i = Vector2i(
			int(token_entry[NETWORK_TOKEN_X]),
			int(token_entry[NETWORK_TOKEN_Y])
		)
		
		var token_type:int = int(token_entry[NETWORK_TOKEN_TYPE])
		var player_id:int = int(token_entry[NETWORK_TOKEN_PLAYER_ID])
		var charges:int = int(token_entry[NETWORK_TOKEN_CHARGES])
		
		if is_position_in_bounds(slot_pos) == false:
			return false
		
		if is_valid_player_id(player_id) == false:
			return false
		
		if TokenLibrary.get_token_data(token_type).is_empty():
			return false
		
		if TokenLibrary.get_token_scene(token_type) == null:
			return false
		
		if charges < 0:
			return false
		
		if typeof(token_entry[NETWORK_TOKEN_PLACEMENT_DATA]) != TYPE_DICTIONARY:
			return false
		
		if typeof(token_entry[NETWORK_TOKEN_STATE_DATA]) != TYPE_DICTIONARY:
			return false
		
		var position_key:String = "%d:%d" % [slot_pos.x, slot_pos.y]
		
		if occupied_positions.has(position_key):
			return false
		
		occupied_positions[position_key] = true
	
	return true


func apply_network_board_snapshot(snapshot:Array) -> bool:
	if is_network_board_snapshot_valid(snapshot) == false:
		return false
	
	clear_tokens_for_network_snapshot()
	
	for token_entry_value in snapshot:
		var token_entry:Array = token_entry_value
		var slot_pos:Vector2i = Vector2i(
			int(token_entry[NETWORK_TOKEN_X]),
			int(token_entry[NETWORK_TOKEN_Y])
		)
		
		var token_type:int = int(token_entry[NETWORK_TOKEN_TYPE])
		var player_id:int = int(token_entry[NETWORK_TOKEN_PLAYER_ID])
		var is_flipped:bool = bool(token_entry[NETWORK_TOKEN_IS_FLIPPED])
		var charges:int = int(token_entry[NETWORK_TOKEN_CHARGES])
		var placement_data:Dictionary = token_entry[NETWORK_TOKEN_PLACEMENT_DATA]
		var state_data:Dictionary = token_entry[NETWORK_TOKEN_STATE_DATA]
		var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
		
		var new_token:Token = create_new_token(token_scene, slot_pos, player_id, is_flipped)
		
		if new_token == null:
			return false
		
		new_token.charges = charges
		new_token.apply_network_placement_data(placement_data)
		new_token.apply_network_state_data(state_data)
		new_token.reset_resolved()
	
	return true


func clear_tokens_for_network_snapshot() -> void:
	if token_pool != null:
		for child in token_pool.get_children():
			var token:Token = child as Token
			
			if token == null:
				continue
			
			token_pool.remove_child(token)
			token.free()
	
	setup_empty_board_state()
	
	if trigger_resolver != null:
		trigger_resolver.clear_pending_pass_triggers()
	
	hovered_slot = null
	

func remove_all_tokens_from_board_state() -> void:
	if state == null:
		return
	
	for y in range(settings.rows):
		for x in range(settings.columns):
			var pos:Vector2i = Vector2i(x, y)
			state.set_token(pos, null)
	
	if trigger_resolver != null:
		trigger_resolver.clear_pending_pass_triggers()
	
	hovered_slot = null


func empty_board_with_fall_effect() -> void:
	var tokens:Array[Token] = get_all_tokens_on_board()
	
	if tokens.is_empty():
		remove_all_tokens_from_board_state()
		return
	
	for token in tokens:
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		token.being_destroyed = true
	
	remove_all_tokens_from_board_state()
	
	if visuals == null:
		for token in tokens:
			if token == null:
				continue
			
			if is_instance_valid(token):
				token.queue_free()
		
		return
	
	var effect:TokenFallOutBoardVisualEffect = TokenFallOutBoardVisualEffect.new(tokens, self, visuals.clear_fall_duration)
	effect.fall_distance = visuals.clear_fall_distance
	effect.row_stagger = visuals.clear_fall_row_stagger
	effect.token_stagger = visuals.clear_fall_token_stagger
	
	visuals.queue_effect(effect)
	
	if visuals.is_busy():
		await visuals.visual_queue_empty
