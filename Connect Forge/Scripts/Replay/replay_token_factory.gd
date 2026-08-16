class_name ReplayTokenFactory
extends RefCounted

const FALLBACK_YELLOW_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/yellow_v3.tres")
const FALLBACK_RED_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/red_v3.tres")
const FALLBACK_VIOLET_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/violet_v3.tres")
const FALLBACK_PINK_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/pink_v3.tres")
const FALLBACK_GREEN_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/green_v3.tres")


static func create_token(parent:Node2D, replay:ReplayData, token_data:Dictionary, local_position:Vector2, gravity:String) -> Token:
	if parent == null:
		return null
	
	if replay == null:
		return null
	
	var token_id:int = int(token_data.get("token_id", -1))
	var replay_token_type:String = str(token_data.get("token_type", ""))
	var player_id:int = int(token_data.get("player_id", -1))
	
	if token_id < 0:
		return null
	
	if player_id < 0:
		return null
	
	if TokenLibrary.is_valid_replay_id(replay_token_type) == false:
		push_error("ReplayTokenFactory: Unknown replay token type '%s'." % replay_token_type)
		return null
	
	var token_type:int = TokenLibrary.get_token_type_from_replay_id(replay_token_type)
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		push_error("ReplayTokenFactory: Could not load scene for replay token '%s'." % replay_token_type)
		return null
	
	var token:Token = token_scene.instantiate() as Token
	
	if token == null:
		push_error("ReplayTokenFactory: Scene for '%s' did not create a Token." % replay_token_type)
		return null
	
	token.visible = false
	token.monitoring = false
	token.monitorable = false
	token.input_pickable = false
	
	parent.add_child(token)
	
	var token_position:Vector2i = ReplayState.position_from_data(token_data.get("position", []))
	
	token.setup(null, token_position, player_id)
	
	if token.set_replay_token_id(token_id) == false:
		token.free()
		return null
	
	token.charges = int(token_data.get("charges", token.charges))

	apply_recorded_player_palettes(token, replay)
	apply_placement_data(token, token_data)
	apply_owner_palette(token, replay, player_id)
	apply_state_data(token, token_data)
	
	var flipped:bool = bool(token_data.get("flipped", false))
	token.set_flipped(flipped)
	
	apply_gravity_rotation(token, gravity)
	apply_persistent_visual_state(token, token_data)

	token.position = local_position
	token.visible = true
	
	return token


static func apply_placement_data(token:Token, token_data:Dictionary) -> void:
	if token == null:
		return
	
	if token_data.has("placement_data") == false:
		return
	
	var placement_value = token_data["placement_data"]
	
	if typeof(placement_value) != TYPE_DICTIONARY:
		return
	
	var placement_data:Dictionary = placement_value
	token.apply_network_placement_data(placement_data)


static func apply_state_data(token:Token, token_data:Dictionary) -> void:
	if token == null:
		return
	
	if token_data.has("state_data") == false:
		return
	
	var state_value = token_data["state_data"]
	
	if typeof(state_value) != TYPE_DICTIONARY:
		return
	
	var state_data:Dictionary = state_value
	token.apply_network_state_data(state_data)

static func apply_recorded_player_palettes(token:Token, replay:ReplayData) -> void:
	if token == null:
		return
	
	if replay == null:
		return
	
	token.clear_visual_player_palettes()
	
	for player_data_value in replay.players:
		if typeof(player_data_value) != TYPE_DICTIONARY:
			continue
		
		var player_data:Dictionary = player_data_value
		var replay_player_id:int = int(player_data.get("player_id", -1))
		
		if replay_player_id < 0:
			continue
		
		var palette:ColorPalette = get_player_palette(replay, replay_player_id)
		
		if palette == null:
			continue
		
		token.set_visual_player_palette(replay_player_id, palette)
		
		
static func apply_owner_palette(token:Token, replay:ReplayData, player_id:int) -> void:
	if token == null:
		return
	
	if token.sprites == null:
		return
	
	var palette:ColorPalette = token.get_visual_player_palette(player_id)

	if palette == null:
		palette = get_player_palette(replay, player_id)

	if palette == null:
		return
	
	apply_palette_recursive(token.sprites, palette)


static func apply_palette_recursive(node:Node, palette:ColorPalette) -> void:
	if node == null:
		return
	
	if node.has_method("recolor_with_palette"):
		node.call("recolor_with_palette", palette)
	
	for child in node.get_children():
		apply_palette_recursive(child, palette)

static func apply_persistent_visual_state(token:Token, token_data:Dictionary) -> void:
	if token == null:
		return
	
	if token_data.has("visual_state") == false:
		return
	
	var visual_state_value = token_data["visual_state"]
	
	if typeof(visual_state_value) != TYPE_DICTIONARY:
		return
	
	var visual_state:Dictionary = visual_state_value
	var darken_amount:float = clamp(float(visual_state.get("darken_amount", 0.0)), 0.0, 1.0)
	
	if darken_amount <= 0.0:
		return
	
	darken_canvas_items_recursive(token, darken_amount)


static func darken_canvas_items_recursive(node:Node, amount:float) -> void:
	if node == null:
		return
	
	for child in node.get_children():
		if child is CanvasItem:
			var item:CanvasItem = child as CanvasItem
			item.modulate = item.modulate.darkened(amount)
		
		darken_canvas_items_recursive(child, amount)
		
		
static func get_player_palette(replay:ReplayData, player_id:int) -> ColorPalette:
	if replay != null:
		for player_data in replay.players:
			if int(player_data.get("player_id", -1)) != player_id:
				continue
			
			var replay_palette:ColorPalette = create_palette_from_replay_data(player_data.get("palette", []))
			
			if replay_palette != null:
				return replay_palette
	
	return get_fallback_palette(player_id)


static func create_palette_from_replay_data(value) -> ColorPalette:
	if typeof(value) != TYPE_ARRAY:
		return null
	
	var colour_values:Array = value
	
	if colour_values.size() < 5:
		return null
	
	var colours:PackedColorArray = PackedColorArray()
	
	for colour_value in colour_values:
		if is_valid_colour_data(colour_value) == false:
			return null
		
		var colour_data:Array = colour_value
		
		var colour:Color = Color(
			float(colour_data[0]),
			float(colour_data[1]),
			float(colour_data[2]),
			float(colour_data[3])
		)
		
		colours.append(colour)
	
	var palette:ColorPalette = ColorPalette.new()
	palette.colors = colours
	return palette


static func is_valid_colour_data(value) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	
	var data:Array = value
	
	if data.size() != 4:
		return false
	
	for component in data:
		var component_type:int = typeof(component)
		
		if component_type != TYPE_INT and component_type != TYPE_FLOAT:
			return false
	
	return true


static func get_fallback_palette(player_id:int) -> ColorPalette:
	var palette_index:int = player_id % 5
	
	match palette_index:
		0:
			return FALLBACK_YELLOW_PALETTE
		1:
			return FALLBACK_RED_PALETTE
		2:
			return FALLBACK_VIOLET_PALETTE
		3:
			return FALLBACK_PINK_PALETTE
		4:
			return FALLBACK_GREEN_PALETTE
	
	return FALLBACK_YELLOW_PALETTE


static func apply_gravity_rotation(token:Token, gravity:String) -> void:
	if token == null:
		return
	
	if token.sprites == null:
		return
	
	var rotation_degrees:float = get_gravity_rotation_degrees(gravity)
	
	token.gravity_visual_rotation_degrees = rotation_degrees
	token.sprites.rotation_degrees = rotation_degrees


static func get_gravity_rotation_degrees(gravity:String) -> float:
	match gravity:
		ReplayFormat.GRAVITY_DOWN:
			return 0.0
		ReplayFormat.GRAVITY_LEFT:
			return 90.0
		ReplayFormat.GRAVITY_UP:
			return 180.0
		ReplayFormat.GRAVITY_RIGHT:
			return 270.0
	
	return 0.0
