class_name ReplayBoardView
extends Node2D

const SLOT_SCENE:PackedScene = preload("res://Scenes/Slot.tscn")
const DEFAULT_SLOT_SIZE:Vector2 = Vector2(400.0, 400.0)

var replay:ReplayData = null

var columns:int = 0
var rows:int = 0
var slot_size:Vector2 = DEFAULT_SLOT_SIZE

var slots_root:Node2D = null
var token_pool:Node2D = null

var replay_tokens:Dictionary = {}


func _ready() -> void:
	ensure_internal_nodes()


func ensure_internal_nodes() -> void:
	if slots_root == null:
		slots_root = Node2D.new()
		slots_root.name = "Slots"
		add_child(slots_root)
	
	if token_pool == null:
		token_pool = Node2D.new()
		token_pool.name = "Token Pool"
		token_pool.z_index = 2
		add_child(token_pool)


func setup_from_replay(new_replay:ReplayData) -> bool:
	if new_replay == null:
		return false
	
	if new_replay.metadata.has("board") == false:
		return false
	
	var board_value = new_replay.metadata["board"]
	
	if typeof(board_value) != TYPE_DICTIONARY:
		return false
	
	var board_data:Dictionary = board_value
	
	var new_columns:int = int(board_data.get("columns", 0))
	var new_rows:int = int(board_data.get("rows", 0))
	
	if new_columns <= 0:
		return false
	
	if new_rows <= 0:
		return false
	
	replay = new_replay
	columns = new_columns
	rows = new_rows
	
	ensure_internal_nodes()
	clear_board()
	build_slots()
	
	return true


func clear_board() -> void:
	clear_tokens()
	clear_slots()


func clear_slots() -> void:
	if slots_root == null:
		return
	
	for child in slots_root.get_children():
		child.free()


func clear_tokens() -> void:
	replay_tokens.clear()
	
	if token_pool == null:
		return
	
	for child in token_pool.get_children():
		child.free()


func build_slots() -> void:
	if slots_root == null:
		return
	
	if columns <= 0 or rows <= 0:
		return
	
	clear_slots()
	slot_size = DEFAULT_SLOT_SIZE
	
	for y in range(rows):
		for x in range(columns):
			var slot_position:Vector2i = Vector2i(x, y)
			var slot:Slot = create_slot(slot_position)
			
			if slot == null:
				continue
			
			if x == 0 and y == 0:
				update_slot_size_from_slot(slot)
			
			slot.position = grid_position_to_local(slot_position)


func create_slot(grid_position:Vector2i) -> Slot:
	var slot:Slot = SLOT_SCENE.instantiate() as Slot
	
	if slot == null:
		return null
	
	slot.monitoring = false
	slot.monitorable = false
	slot.input_pickable = false
	
	slots_root.add_child(slot)
	
	var slot_types:Array = []
	slot.setup_slot(null, grid_position, slot_types)
	
	return slot


func update_slot_size_from_slot(slot:Slot) -> void:
	if slot == null:
		return
	
	var front:Sprite2D = slot.get_node_or_null("Front") as Sprite2D
	
	if front == null:
		return
	
	if front.texture == null:
		return
	
	var texture_size:Vector2 = front.texture.get_size()
	
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	
	slot_size = texture_size


func display_state(state:ReplayState) -> bool:
	if replay == null:
		return false
	
	if state == null:
		return false
	
	if state.columns != columns:
		return false
	
	if state.rows != rows:
		return false
	
	clear_tokens()
	
	var token_ids:Array[int] = []
	
	for token_id_value in state.tokens.keys():
		token_ids.append(int(token_id_value))
	
	token_ids.sort()
	
	for token_id in token_ids:
		var token_data:Dictionary = state.get_token_data(token_id)
		
		if token_data.is_empty():
			continue
		
		if create_token_from_state(token_data, state.gravity) == null:
			push_error("ReplayBoardView: Could not create replay token %d." % token_id)
			return false
	
	return true


func create_token_from_state(token_data:Dictionary, gravity:String) -> Token:
	if token_pool == null:
		return null
	
	var position_value = token_data.get("position", [])
	
	if ReplayState.is_valid_position_data(position_value) == false:
		return null
	
	var grid_position:Vector2i = ReplayState.position_from_data(position_value)
	
	if is_grid_position_in_bounds(grid_position) == false:
		return null
	
	var local_position:Vector2 = grid_position_to_local(grid_position)
	
	var token:Token = ReplayTokenFactory.create_token(token_pool, replay, token_data, local_position, gravity)
	
	if token == null:
		return null
	
	var token_id:int = int(token_data.get("token_id", -1))
	replay_tokens[token_id] = token
	
	return token


func get_replay_token(token_id:int) -> Token:
	if replay_tokens.has(token_id) == false:
		return null
	
	var token:Token = replay_tokens[token_id]
	
	if token == null:
		return null
	
	if is_instance_valid(token) == false:
		return null
	
	return token


func grid_position_to_local(grid_position:Vector2i) -> Vector2:
	var board_width:float = float(columns) * slot_size.x
	var board_height:float = float(rows) * slot_size.y
	
	var left:float = -board_width * 0.5
	var top:float = -board_height * 0.5
	
	return Vector2(
		left + float(grid_position.x) * slot_size.x + slot_size.x * 0.5,
		top + float(grid_position.y) * slot_size.y + slot_size.y * 0.5
	)


func is_grid_position_in_bounds(grid_position:Vector2i) -> bool:
	if grid_position.x < 0 or grid_position.x >= columns:
		return false
	
	if grid_position.y < 0 or grid_position.y >= rows:
		return false
	
	return true


func get_unscaled_board_size() -> Vector2:
	return Vector2(
		float(columns) * slot_size.x,
		float(rows) * slot_size.y
	)


func fit_to_rect(target_rect:Rect2, padding:float = 30.0) -> void:
	if columns <= 0 or rows <= 0:
		return
	
	var board_size:Vector2 = get_unscaled_board_size()
	
	if board_size.x <= 0.0 or board_size.y <= 0.0:
		return
	
	var available_width:float = max(target_rect.size.x - padding * 2.0, 1.0)
	var available_height:float = max(target_rect.size.y - padding * 2.0, 1.0)
	
	var horizontal_scale:float = available_width / board_size.x
	var vertical_scale:float = available_height / board_size.y
	var used_scale:float = min(horizontal_scale, vertical_scale)
	
	scale = Vector2(used_scale, used_scale)
	position = target_rect.position + target_rect.size * 0.5
