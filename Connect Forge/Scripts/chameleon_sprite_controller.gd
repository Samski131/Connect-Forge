extends Node2D

const DISSOLVE_SHADER:Shader = preload("res://Shaders/chamelon_effect.gdshader")

@onready var fake_sprites:Node2D = $FakeSprites
@onready var chameleon_sprites:Node2D = $ChameleonSprites

var game_manager:Node = null
var current_fake_player_id:int = -1
var current_real_player_id:int = -1
var dissolve_materials:Array[ShaderMaterial] = []
var reveal_materials:Array[ShaderMaterial] = []


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")


func recolor(player_id:int) -> void:
	current_real_player_id = player_id
	
	if chameleon_sprites != null and chameleon_sprites.has_method("recolor"):
		chameleon_sprites.recolor(player_id)
	
	hide_fake_layer()


func darken(amount:float) -> void:
	if chameleon_sprites != null and chameleon_sprites.has_method("darken"):
		chameleon_sprites.darken(amount)


func play_shimmer(duration:float = 0.45, direction:Vector2 = Vector2(1.0, -1.0), strength:float = 0.75) -> void:
	if chameleon_sprites != null and chameleon_sprites.has_method("play_shimmer"):
		chameleon_sprites.play_shimmer(duration, direction, strength)


func set_flipped_visual(is_flipped:bool) -> void:
	_set_layer_flipped(chameleon_sprites, is_flipped)
	_set_layer_flipped(fake_sprites, is_flipped)


func hide_fake_layer() -> void:
	clear_dissolve_materials_from_layer(fake_sprites)
	clear_dissolve_materials_from_layer(chameleon_sprites)
	dissolve_materials.clear()
	reveal_materials.clear()
	
	if fake_sprites != null:
		fake_sprites.visible = false
		fake_sprites.modulate.a = 1.0
	
	if chameleon_sprites != null:
		chameleon_sprites.visible = true
		chameleon_sprites.modulate.a = 1.0
		
		if chameleon_sprites.has_method("setup_shimmer_materials"):
			chameleon_sprites.setup_shimmer_materials()


func prepare_fake_visual(fake_player_id:int) -> void:
	current_fake_player_id = fake_player_id
	reveal_materials.clear()
	clear_dissolve_materials_from_layer(fake_sprites)
	clear_dissolve_materials_from_layer(chameleon_sprites)
	
	if fake_sprites == null:
		return
	
	if fake_sprites.has_method("recolor"):
		fake_sprites.recolor(fake_player_id)
	
	fake_sprites.visible = true
	fake_sprites.modulate.a = 1.0
	
	if chameleon_sprites != null:
		chameleon_sprites.visible = true
		chameleon_sprites.modulate.a = 1.0
	
	setup_dissolve_materials()
	set_dissolve_progress(0.0)


func set_dissolve_progress(value:float) -> void:
	update_dissolve_screen_uniforms()
	
	for m in dissolve_materials:
		if m == null:
			continue
		
		m.set_shader_parameter("dissolve_progress", value)


func finish_fake_visual() -> void:
	set_dissolve_progress(1.0)
	
	if chameleon_sprites != null:
		chameleon_sprites.visible = false
	
	if fake_sprites != null:
		fake_sprites.visible = true
		fake_sprites.modulate.a = 1.0


func setup_dissolve_materials() -> void:
	dissolve_materials.clear()
	
	if chameleon_sprites == null:
		return
	
	var sprite_list:Array[Sprite2D] = []
	_collect_sprites(chameleon_sprites, sprite_list)
	
	var wave_color:Color = get_change_wave_color()
	
	for sprite in sprite_list:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		var m:ShaderMaterial = ShaderMaterial.new()
		m.shader = DISSOLVE_SHADER
		m.set_shader_parameter("dissolve_progress", 0.0)
		m.set_shader_parameter("beam_color", wave_color)
		sprite.material = m
		dissolve_materials.append(m)
	
	update_dissolve_screen_uniforms()


func prepare_reveal_visual() -> void:
	reveal_materials.clear()
	clear_dissolve_materials_from_layer(fake_sprites)
	clear_dissolve_materials_from_layer(chameleon_sprites)
	
	if fake_sprites != null:
		fake_sprites.visible = true
		fake_sprites.modulate.a = 1.0
	
	if chameleon_sprites != null:
		chameleon_sprites.visible = true
		chameleon_sprites.modulate.a = 1.0
	
	setup_reveal_dissolve_materials()
	set_reveal_dissolve_progress(0.0)


func set_reveal_dissolve_progress(value:float) -> void:
	var clamped_value:float = clamp(value, 0.0, 1.0)
	var shader_progress:float = 1.0 - clamped_value
	
	update_reveal_dissolve_screen_uniforms()
	
	for m in reveal_materials:
		if m == null:
			continue
		
		m.set_shader_parameter("dissolve_progress", shader_progress)


func finish_reveal_visual() -> void:
	set_reveal_dissolve_progress(1.0)
	clear_dissolve_materials_from_layer(fake_sprites)
	clear_dissolve_materials_from_layer(chameleon_sprites)
	
	if fake_sprites != null:
		fake_sprites.visible = false
		fake_sprites.modulate.a = 1.0
	
	if chameleon_sprites != null:
		chameleon_sprites.visible = true
		chameleon_sprites.modulate.a = 1.0
		
		if chameleon_sprites.has_method("setup_shimmer_materials"):
			chameleon_sprites.setup_shimmer_materials()
	
	current_fake_player_id = -1
	dissolve_materials.clear()
	reveal_materials.clear()


func setup_reveal_dissolve_materials() -> void:
	reveal_materials.clear()
	
	if chameleon_sprites == null:
		return
	
	var sprite_list:Array[Sprite2D] = []
	_collect_sprites(chameleon_sprites, sprite_list)
	
	var wave_color:Color = get_reveal_wave_color()
	
	for sprite in sprite_list:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		var m:ShaderMaterial = ShaderMaterial.new()
		m.shader = DISSOLVE_SHADER
		m.set_shader_parameter("dissolve_progress", 1.0)
		m.set_shader_parameter("beam_color", wave_color)
		sprite.material = m
		reveal_materials.append(m)
	
	update_reveal_dissolve_screen_uniforms()


func get_change_wave_color() -> Color:
	if game_manager == null:
		game_manager = get_tree().get_first_node_in_group("game manager")
	
	if game_manager == null:
		return Color.WHITE
	
	if current_fake_player_id < 0:
		return Color.WHITE
	
	if current_fake_player_id >= game_manager.player_colours.size():
		return Color.WHITE
	
	var palette:ColorPalette = game_manager.player_colours[current_fake_player_id]
	
	if palette == null:
		return Color.WHITE
	
	if palette.colors.is_empty():
		return Color.WHITE
	
	return palette.colors[4]


func get_reveal_wave_color() -> Color:
	if game_manager == null:
		game_manager = get_tree().get_first_node_in_group("game manager")
	
	if game_manager == null:
		return Color.WHITE
	
	if current_real_player_id < 0:
		return Color.WHITE
	
	if current_real_player_id >= game_manager.player_colours.size():
		return Color.WHITE
	
	var palette:ColorPalette = game_manager.player_colours[current_real_player_id]
	
	if palette == null:
		return Color.WHITE
	
	if palette.colors.is_empty():
		return Color.WHITE
	
	return palette.colors[4]


func _collect_sprites(node:Node, results:Array[Sprite2D]) -> void:
	if node == null:
		return
	
	for child in node.get_children():
		if child is Sprite2D:
			results.append(child)
		
		_collect_sprites(child, results)


func _set_layer_flipped(layer:Node2D, is_flipped:bool) -> void:
	if layer == null:
		return
	
	if layer.has_method("set_flipped_visual"):
		layer.set_flipped_visual(is_flipped)


func clear_dissolve_materials_from_layer(layer:Node2D) -> void:
	if layer == null:
		return
	
	var sprite_list:Array[Sprite2D] = []
	_collect_sprites(layer, sprite_list)
	
	for sprite in sprite_list:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		sprite.material = null


func update_dissolve_screen_uniforms() -> void:
	var parent_node:Node = get_parent()
	var token_center_screen:Vector2 = global_position
	var dissolve_height_pixels:float = 120.0
	
	if parent_node is Node2D:
		var parent_2d:Node2D = parent_node as Node2D
		var canvas_transform:Transform2D = parent_2d.get_global_transform_with_canvas()
		token_center_screen = canvas_transform.origin
		
		var visual_scale:float = canvas_transform.y.length()
		dissolve_height_pixels = 400.0 * visual_scale
		
		if dissolve_height_pixels < 1.0:
			dissolve_height_pixels = 120.0
	
	for material in dissolve_materials:
		if material == null:
			continue
		
		material.set_shader_parameter("token_center_screen", token_center_screen)
		material.set_shader_parameter("dissolve_height_pixels", dissolve_height_pixels)


func update_reveal_dissolve_screen_uniforms() -> void:
	var parent_node:Node = get_parent()
	var token_center_screen:Vector2 = global_position
	var dissolve_height_pixels:float = 120.0
	
	if parent_node is Node2D:
		var parent_2d:Node2D = parent_node as Node2D
		var canvas_transform:Transform2D = parent_2d.get_global_transform_with_canvas()
		token_center_screen = canvas_transform.origin
		
		var visual_scale:float = canvas_transform.y.length()
		dissolve_height_pixels = 400.0 * visual_scale
		
		if dissolve_height_pixels < 1.0:
			dissolve_height_pixels = 120.0
	
	for material in reveal_materials:
		if material == null:
			continue
		
		material.set_shader_parameter("token_center_screen", token_center_screen)
		material.set_shader_parameter("dissolve_height_pixels", dissolve_height_pixels)
