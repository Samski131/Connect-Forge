class_name TokenDragController
extends Node2D

const NETWORK_PREVIEW_SEND_INTERVAL:float = 0.05
const REMOTE_PREVIEW_FOLLOW_SPEED:float = 30.0
const DRAG_PREVIEW_Z_INDEX:int = 90

var game_manager:GameManager = null
var board:BoardManager = null

var preview_parent:Node2D = null
var preview_uses_ui_overlay:bool = false

var is_dragging:bool = false
var dragged_player_id:int = -1
var dragged_token_type:int = -1
var dragged_is_flipped:bool = false
var dragged_token_was_spent:bool = false
var preview_token:Token = null

var current_drag_id:int = 0
var network_preview_send_timer:float = 0.0

var remote_preview_token:Token = null
var remote_preview_drag_id:int = -1
var remote_preview_player_id:int = -1
var remote_preview_token_type:int = -1
var remote_preview_is_flipped:bool = false
var remote_preview_target_position:Vector2 = Vector2.ZERO


func setup(new_game_manager:GameManager, new_board:BoardManager) -> void:
	game_manager = new_game_manager
	board = new_board
	
	setup_preview_parent()


func setup_preview_parent() -> void:
	preview_parent = null
	preview_uses_ui_overlay = false
	
	var scene_root:Node = get_parent()
	
	if scene_root != null:
		var user_interface:CanvasLayer = scene_root.get_node_or_null("User Interface") as CanvasLayer
		
		if user_interface != null:
			var existing_preview_root:Node2D = user_interface.get_node_or_null("Runtime Drag Preview Root") as Node2D
			
			if existing_preview_root == null:
				existing_preview_root = Node2D.new()
				existing_preview_root.name = "Runtime Drag Preview Root"
				existing_preview_root.z_index = DRAG_PREVIEW_Z_INDEX
				existing_preview_root.z_as_relative = false
				user_interface.add_child(existing_preview_root)
			
			preview_parent = existing_preview_root
			preview_uses_ui_overlay = true
	
	if preview_parent == null:
		if board != null:
			preview_parent = board.token_pool
	
	if preview_parent == null:
		preview_parent = self
	
	update_preview_parent_transform()


func begin_drag(player_id:int, token_type:int) -> void:
	if is_dragging:
		cancel_drag()
	
	if game_manager == null:
		return
	
	if board == null:
		return
	
	if game_manager.get_current_turn_phase() != Global.TURN_PHASE.PLACEMENT:
		return
	
	if game_manager.can_player_drag_token(player_id, token_type) == false:
		return
	
	dragged_player_id = player_id
	dragged_token_type = token_type
	dragged_is_flipped = false
	dragged_token_was_spent = false
	
	if game_manager.should_spend_token_when_drag_begins():
		if game_manager.spend_token(player_id, token_type) == false:
			clear_drag_state()
			return
		
		dragged_token_was_spent = true
	
	if create_preview_token() == false:
		refund_dragged_token_if_needed()
		clear_drag_state()
		return
	
	is_dragging = true
	current_drag_id += 1
	network_preview_send_timer = 0.0
	
	update_preview_position()
	
	game_manager.send_local_drag_preview_started(current_drag_id, dragged_token_type, get_local_preview_board_position(), dragged_is_flipped)


func create_preview_token() -> bool:
	var token_scene:PackedScene = TokenLibrary.get_token_scene(dragged_token_type)
	
	if token_scene == null:
		return false
	
	var new_preview:Token = token_scene.instantiate() as Token
	
	if new_preview == null:
		return false
	
	preview_parent.add_child(new_preview)
	preview_token = new_preview
	
	preview_token.remove_from_group("token")
	preview_token.setup(board, Vector2i.ZERO, dragged_player_id)
	preview_token.modulate = Color(1.0, 1.0, 1.0, 1.0)
	preview_token.z_index = 0
	
	disable_preview_collision(preview_token)
	return true


func disable_preview_collision(node:Node) -> void:
	if node is CollisionShape2D:
		var collision_shape:CollisionShape2D = node as CollisionShape2D
		collision_shape.disabled = true
	
	if node is Area2D:
		var area:Area2D = node as Area2D
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0
	
	for child in node.get_children():
		disable_preview_collision(child)


func _process(delta:float) -> void:
	update_preview_parent_transform()
	
	if is_dragging:
		update_preview_position()
		update_network_preview_position(delta)
	
	update_remote_preview_position_visual(delta)


func _input(event:InputEvent) -> void:
	if is_dragging == false:
		return
	
	if event is InputEventMouseButton:
		var mouse_event:InputEventMouseButton = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed == false:
			try_drop_dragged_token()
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventKey:
		var key_event:InputEventKey = event as InputEventKey
		
		if key_event.pressed and key_event.echo == false and key_event.keycode == KEY_F:
			flip_dragged_token()
			get_viewport().set_input_as_handled()
			return
		
		if key_event.pressed and key_event.echo == false and key_event.keycode == KEY_ESCAPE:
			cancel_drag()
			get_viewport().set_input_as_handled()


func update_preview_parent_transform() -> void:
	if preview_uses_ui_overlay == false:
		return
	
	if preview_parent == null:
		return
	
	if board == null:
		return
	
	if board.token_pool == null:
		return
	
	var viewport_canvas_transform:Transform2D = get_viewport().get_canvas_transform()
	var token_pool_world_transform:Transform2D = board.token_pool.global_transform
	
	preview_parent.transform = viewport_canvas_transform * token_pool_world_transform


func update_preview_position() -> void:
	if preview_token == null:
		return
	
	if board == null:
		return
	
	if board.token_pool == null:
		return
	
	var mouse_world_position:Vector2 = get_global_mouse_position()
	preview_token.position = board.token_pool.to_local(mouse_world_position)


func update_network_preview_position(delta:float) -> void:
	if game_manager == null:
		return
	
	if game_manager.is_network_match_active() == false:
		return
	
	network_preview_send_timer += delta
	
	if network_preview_send_timer < NETWORK_PREVIEW_SEND_INTERVAL:
		return
	
	network_preview_send_timer = 0.0
	
	game_manager.send_local_drag_preview_position(current_drag_id, get_local_preview_board_position())


func get_local_preview_board_position() -> Vector2:
	if board == null:
		return Vector2.ZERO
	
	if board.token_pool == null:
		return Vector2.ZERO
	
	if preview_token == null:
		return Vector2.ZERO
	
	var preview_world_position:Vector2 = board.token_pool.to_global(preview_token.position)
	return board.to_local(preview_world_position)


func flip_dragged_token() -> void:
	if TokenLibrary.can_flip(dragged_token_type) == false:
		return
	
	if preview_token == null:
		return
	
	if is_instance_valid(preview_token) == false:
		return
	
	dragged_is_flipped = not dragged_is_flipped
	
	play_preview_flip_effect(preview_token, dragged_is_flipped)
	
	if game_manager != null:
		game_manager.send_local_drag_preview_flipped(current_drag_id, dragged_is_flipped)


func play_preview_flip_effect(token:Token, target_flipped:bool) -> void:
	if token == null:
		return
	
	if is_instance_valid(token) == false:
		return
	
	var used_duration:float = 0.28
	var used_min_scale_x:float = 0.08
	var used_pop_scale_y:float = 1.08
	
	if board != null and board.visuals != null:
		used_duration = board.visuals.flip_duration
		used_min_scale_x = board.visuals.flip_min_scale_x
		used_pop_scale_y = board.visuals.flip_pop_scale_y
	
	var effect:TokenFlipVisualEffect = TokenFlipVisualEffect.new(token, target_flipped, used_duration)
	effect.min_scale_x = used_min_scale_x
	effect.pop_scale_y = used_pop_scale_y
	effect.play(self, Callable())


func try_drop_dragged_token() -> void:
	if game_manager == null:
		return
	
	if board == null:
		return
	
	var slot_pos:Vector2i = board.global_position_to_slot(get_global_mouse_position())
	var placed:bool = game_manager.try_place_dragged_token(dragged_token_type, slot_pos, dragged_is_flipped)
	
	if placed == false:
		refund_dragged_token_if_needed()
	
	clear_drag_state()


func cancel_drag() -> void:
	refund_dragged_token_if_needed()
	clear_drag_state()


func refund_dragged_token_if_needed() -> void:
	if dragged_token_was_spent == false:
		return
	
	if game_manager == null:
		return
	
	if dragged_player_id == -1:
		return
	
	if dragged_token_type == -1:
		return
	
	game_manager.refund_token(dragged_player_id, dragged_token_type)
	dragged_token_was_spent = false


func clear_drag_state() -> void:
	if is_dragging and game_manager != null:
		game_manager.send_local_drag_preview_ended(current_drag_id)
	
	if preview_token != null and is_instance_valid(preview_token):
		preview_token.queue_free()
	
	is_dragging = false
	dragged_player_id = -1
	dragged_token_type = -1
	dragged_is_flipped = false
	dragged_token_was_spent = false
	preview_token = null
	network_preview_send_timer = 0.0


func show_remote_drag_preview(drag_id:int, player_id:int, token_type:int, board_local_position:Vector2, is_flipped:bool) -> void:
	clear_remote_drag_preview()
	
	if board == null:
		return
	
	if board.token_pool == null:
		return
	
	if preview_parent == null:
		return
	
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return
	
	var new_preview:Token = token_scene.instantiate() as Token
	
	if new_preview == null:
		return
	
	preview_parent.add_child(new_preview)
	
	remote_preview_token = new_preview
	remote_preview_drag_id = drag_id
	remote_preview_player_id = player_id
	remote_preview_token_type = token_type
	remote_preview_is_flipped = is_flipped
	
	remote_preview_token.remove_from_group("token")
	remote_preview_token.setup(board, Vector2i.ZERO, player_id)
	remote_preview_token.modulate = Color(1.0, 1.0, 1.0, 1.0)
	remote_preview_token.z_index = 0
	
	disable_preview_collision(remote_preview_token)
	
	var preview_world_position:Vector2 = board.to_global(board_local_position)
	remote_preview_target_position = board.token_pool.to_local(preview_world_position)
	remote_preview_token.position = remote_preview_target_position
	remote_preview_token.set_flipped(is_flipped)


func update_remote_drag_preview(drag_id:int, board_local_position:Vector2) -> void:
	if drag_id != remote_preview_drag_id:
		return
	
	if remote_preview_token == null:
		return
	
	if is_instance_valid(remote_preview_token) == false:
		return
	
	if board == null:
		return
	
	if board.token_pool == null:
		return
	
	var preview_world_position:Vector2 = board.to_global(board_local_position)
	remote_preview_target_position = board.token_pool.to_local(preview_world_position)


func update_remote_preview_position_visual(delta:float) -> void:
	if remote_preview_token == null:
		return
	
	if is_instance_valid(remote_preview_token) == false:
		remote_preview_token = null
		return
	
	var follow_weight:float = clamp(delta * REMOTE_PREVIEW_FOLLOW_SPEED, 0.0, 1.0)
	remote_preview_token.position = remote_preview_token.position.lerp(remote_preview_target_position, follow_weight)


func flip_remote_drag_preview(drag_id:int, is_flipped:bool) -> void:
	if drag_id != remote_preview_drag_id:
		return
	
	if remote_preview_token == null:
		return
	
	if is_instance_valid(remote_preview_token) == false:
		return
	
	if remote_preview_is_flipped == is_flipped:
		return
	
	remote_preview_is_flipped = is_flipped
	play_preview_flip_effect(remote_preview_token, remote_preview_is_flipped)


func clear_remote_drag_preview(drag_id:int = -1) -> void:
	if drag_id != -1:
		if drag_id != remote_preview_drag_id:
			return
	
	if remote_preview_token != null and is_instance_valid(remote_preview_token):
		remote_preview_token.queue_free()
	
	remote_preview_token = null
	remote_preview_drag_id = -1
	remote_preview_player_id = -1
	remote_preview_token_type = -1
	remote_preview_is_flipped = false
	remote_preview_target_position = Vector2.ZERO
