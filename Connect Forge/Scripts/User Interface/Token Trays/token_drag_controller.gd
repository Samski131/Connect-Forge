class_name TokenDragController
extends Node2D

var game_manager:GameManager = null
var board:BoardManager = null
var preview_parent:Node = null

var is_dragging:bool = false
var dragged_player_id:int = -1
var dragged_token_type:int = -1
var dragged_is_flipped:bool = false
var preview_token:Token = null


func setup(new_game_manager:GameManager, new_board:BoardManager) -> void:
	game_manager = new_game_manager
	board = new_board
	
	if board != null:
		preview_parent = board.token_pool
	
	if preview_parent == null:
		preview_parent = self


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
	
	if game_manager.spend_token(player_id, token_type) == false:
		return
	
	dragged_player_id = player_id
	dragged_token_type = token_type
	dragged_is_flipped = false
	
	if create_preview_token() == false:
		game_manager.refund_token(dragged_player_id, dragged_token_type)
		clear_drag_state()
		return
	
	is_dragging = true
	update_preview_position()


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
	preview_token.z_index = 1000
	
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


func _process(_delta:float) -> void:
	if is_dragging == false:
		return
	
	update_preview_position()


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


func update_preview_position() -> void:
	if preview_token == null:
		return
	
	preview_token.global_position = get_global_mouse_position()


func flip_dragged_token() -> void:
	if TokenLibrary.can_flip(dragged_token_type) == false:
		return
	
	if preview_token == null:
		return
	
	if is_instance_valid(preview_token) == false:
		return
	
	dragged_is_flipped = not dragged_is_flipped
	
	var used_duration:float = 0.28
	var used_min_scale_x:float = 0.08
	var used_pop_scale_y:float = 1.08
	
	if board != null and board.visuals != null:
		used_duration = board.visuals.flip_duration
		used_min_scale_x = board.visuals.flip_min_scale_x
		used_pop_scale_y = board.visuals.flip_pop_scale_y
	
	var effect:TokenFlipVisualEffect = TokenFlipVisualEffect.new(preview_token, dragged_is_flipped, used_duration)
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
		game_manager.refund_token(dragged_player_id, dragged_token_type)
	
	clear_drag_state()


func cancel_drag() -> void:
	if game_manager != null and dragged_player_id != -1 and dragged_token_type != -1:
		game_manager.refund_token(dragged_player_id, dragged_token_type)
	
	clear_drag_state()


func clear_drag_state() -> void:
	if preview_token != null and is_instance_valid(preview_token):
		preview_token.queue_free()
	
	is_dragging = false
	dragged_player_id = -1
	dragged_token_type = -1
	dragged_is_flipped = false
	preview_token = null
