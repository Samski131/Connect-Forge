class_name TokenVisualDisplay
extends Control

const FALLBACK_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/blue_v3.tres")

@export_group("Visual")
@export var visual_scale:float = 0.19
@export var visual_rotation_degrees:float = 0.0

@export_group("Inspector Override")
@export var overridden_by_inspector:bool = false
@export var token_palette:ColorPalette = null
@export var token_type:TokenLibrary.TokenType = TokenLibrary.TokenType.BASIC

@export_subgroup("Override Icon")
@export var override_icon:Texture2D = null
@export var override_icon_white:bool = false
@export var override_icon_offset:Vector2 = Vector2.ZERO
@export_range(0.01, 5.0, 0.01) var override_icon_scale:float = 1.0
@export var override_icon_shadow_offset:Vector2 = Vector2(0.0, 8.0)

var player_id:int = -1
var is_flipped:bool = false
var visual_root:Node2D = null
var explicit_palette:ColorPalette = null

var override_icon_root:Node2D = null
var override_icon_front:TextureRect = null
var override_icon_shadow:TextureRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	
	if overridden_by_inspector:
		apply_inspector_override()
	
	call_deferred("refresh_layout")


func setup(new_token_type:int, new_player_id:int, new_is_flipped:bool = false) -> void:
	if overridden_by_inspector:
		return
	
	explicit_palette = null
	setup_internal(new_token_type, new_player_id, new_is_flipped)


func setup_with_palette(new_token_type:int, new_player_id:int, new_palette:ColorPalette, new_is_flipped:bool = false) -> void:
	if overridden_by_inspector:
		return
	
	explicit_palette = new_palette
	setup_internal(new_token_type, new_player_id, new_is_flipped)


func apply_inspector_override() -> void:
	explicit_palette = token_palette
	setup_internal(token_type, 0, false)


func setup_internal(new_token_type:int, new_player_id:int, new_is_flipped:bool) -> void:
	if token_type == new_token_type and player_id == new_player_id and is_flipped == new_is_flipped and visual_root != null:
		call_deferred("apply_visual_setup")
		return
	
	token_type = new_token_type
	player_id = new_player_id
	is_flipped = new_is_flipped
	
	clear_visual()
	create_visual()


func clear_visual() -> void:
	override_icon_root = null
	override_icon_front = null
	override_icon_shadow = null
	
	if visual_root != null and is_instance_valid(visual_root):
		visual_root.queue_free()
	
	visual_root = null


func create_visual() -> void:
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return
	
	var token_instance:Node = token_scene.instantiate()
	
	if token_instance == null:
		return
	
	var sprites:Node2D = token_instance.get_node_or_null("Sprites") as Node2D
	
	if sprites == null:
		token_instance.free()
		return
	
	token_instance.remove_child(sprites)
	token_instance.free()
	
	visual_root = sprites
	visual_root.name = "Visual Root"
	
	add_child(visual_root)
	
	call_deferred("apply_visual_setup")
	call_deferred("refresh_layout")


func apply_visual_setup() -> void:
	if visual_root == null:
		return
	
	if is_instance_valid(visual_root) == false:
		return
	
	if explicit_palette != null:
		_call_method_recursive(visual_root, "recolor_with_palette", [explicit_palette])
	else:
		_call_method_recursive(visual_root, "recolor", [player_id])
	
	_call_method_recursive(visual_root, "set_flipped_visual", [is_flipped])
	
	refresh_override_icon()
	refresh_layout()


func refresh_override_icon() -> void:
	clear_override_icon()
	
	var should_use_override_icon:bool = overridden_by_inspector and override_icon != null
	
	set_original_icon_visibility(should_use_override_icon == false)
	
	if should_use_override_icon == false:
		return
	
	create_override_icon()


func clear_override_icon() -> void:
	if override_icon_root != null and is_instance_valid(override_icon_root):
		override_icon_root.free()
	
	override_icon_root = null
	override_icon_front = null
	override_icon_shadow = null


func create_override_icon() -> void:
	if visual_root == null:
		return
	
	if override_icon == null:
		return
	
	override_icon_root = Node2D.new()
	override_icon_root.name = "Override Icon"
	visual_root.add_child(override_icon_root)
	
	override_icon_shadow = create_icon_texture_rect("Override Icon Shadow")
	override_icon_front = create_icon_texture_rect("Override Icon Front")
	
	override_icon_root.add_child(override_icon_shadow)
	override_icon_root.add_child(override_icon_front)
	
	override_icon_shadow.z_index = 0
	override_icon_front.z_index = 1
	
	apply_override_icon_colours()
	refresh_override_icon_layout()


func create_icon_texture_rect(node_name:String) -> TextureRect:
	var texture_rect:TextureRect = TextureRect.new()
	texture_rect.name = node_name
	texture_rect.texture = override_icon
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	
	return texture_rect


func apply_override_icon_colours() -> void:
	if override_icon_front == null:
		return
	
	if override_icon_shadow == null:
		return
	
	var used_palette:ColorPalette = get_used_override_palette()
	
	if override_icon_white:
		override_icon_front.modulate = Color.WHITE
	else:
		override_icon_front.modulate = get_palette_colour(used_palette, 0, Color.WHITE)
	
	override_icon_shadow.modulate = get_palette_colour(used_palette, 3, Color(0.2, 0.2, 0.2, 1.0))


func get_used_override_palette() -> ColorPalette:
	if token_palette != null and token_palette.colors.size() >= 4:
		return token_palette
	
	if explicit_palette != null and explicit_palette.colors.size() >= 4:
		return explicit_palette
	
	return FALLBACK_PALETTE


func get_palette_colour(palette:ColorPalette, colour_index:int, fallback_colour:Color) -> Color:
	if palette == null:
		return fallback_colour
	
	if colour_index < 0:
		return fallback_colour
	
	if colour_index >= palette.colors.size():
		return fallback_colour
	
	return palette.colors[colour_index]


func refresh_override_icon_layout() -> void:
	if override_icon == null:
		return
	
	if override_icon_front == null:
		return
	
	if override_icon_shadow == null:
		return
	
	var texture_size:Vector2 = override_icon.get_size()
	var displayed_size:Vector2 = texture_size * override_icon_scale
	var centred_position:Vector2 = override_icon_offset - displayed_size * 0.5
	
	override_icon_front.size = displayed_size
	override_icon_front.position = centred_position
	
	override_icon_shadow.size = displayed_size
	override_icon_shadow.position = centred_position + override_icon_shadow_offset


func set_original_icon_visibility(should_be_visible:bool) -> void:
	if visual_root == null:
		return
	
	set_named_icon_visibility_recursive(visual_root, should_be_visible)


func set_named_icon_visibility_recursive(node:Node, should_be_visible:bool) -> void:
	if node == null:
		return
	
	if node != override_icon_root and node.name == "Icon":
		var canvas_item:CanvasItem = node as CanvasItem
		
		if canvas_item != null:
			canvas_item.visible = should_be_visible
	
	for child in node.get_children():
		set_named_icon_visibility_recursive(child, should_be_visible)


func refresh_layout() -> void:
	if visual_root == null:
		return
	
	if is_instance_valid(visual_root) == false:
		return
	
	visual_root.position = size * 0.5
	visual_root.scale = Vector2(visual_scale, visual_scale)
	visual_root.rotation_degrees = visual_rotation_degrees
	
	refresh_override_icon_layout()


func _notification(what:int) -> void:
	if what == NOTIFICATION_RESIZED:
		refresh_layout()


func _call_method_recursive(node:Node, method_name:String, arguments:Array) -> void:
	if node == null:
		return
	
	if node.has_method(method_name):
		node.callv(method_name, arguments)
	
	for child in node.get_children():
		_call_method_recursive(child, method_name, arguments)
