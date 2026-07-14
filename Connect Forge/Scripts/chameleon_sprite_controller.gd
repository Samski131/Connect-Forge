extends Node2D

const DISSOLVE_SHADER:Shader = preload("res://Shaders/chamelon_effect.gdshader")
const WAVE_COLOUR_INDEX:int = 4

@onready var fake_sprites:Node2D = $FakeSprites
@onready var chameleon_sprites:Node2D = $ChameleonSprites

var token:Token = null
var current_fake_player_id:int = -1
var current_real_player_id:int = -1
var dissolve_materials:Array[ShaderMaterial] = []
var reveal_materials:Array[ShaderMaterial] = []


func _ready() -> void:
	token = get_parent() as Token


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
	set_layer_flipped(chameleon_sprites, is_flipped)
	set_layer_flipped(fake_sprites, is_flipped)


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
	
	for dissolve_material in dissolve_materials:
		if dissolve_material == null:
			continue
		
		dissolve_material.set_shader_parameter("dissolve_progress", value)


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
	collect_sprites(chameleon_sprites, sprite_list)
	
	var wave_color:Color = get_change_wave_color()
	
	for sprite in sprite_list:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		var dissolve_material:ShaderMaterial = ShaderMaterial.new()
		dissolve_material.shader = DISSOLVE_SHADER
		dissolve_material.set_shader_parameter("dissolve_progress", 0.0)
		dissolve_material.set_shader_parameter("beam_color", wave_color)
		sprite.material = dissolve_material
		dissolve_materials.append(dissolve_material)
	
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
	
	for reveal_material in reveal_materials:
		if reveal_material == null:
			continue
		
		reveal_material.set_shader_parameter("dissolve_progress", shader_progress)


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
	collect_sprites(chameleon_sprites, sprite_list)
	
	var wave_color:Color = get_reveal_wave_color()
	
	for sprite in sprite_list:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		var reveal_material:ShaderMaterial = ShaderMaterial.new()
		reveal_material.shader = DISSOLVE_SHADER
		reveal_material.set_shader_parameter("dissolve_progress", 1.0)
		reveal_material.set_shader_parameter("beam_color", wave_color)
		sprite.material = reveal_material
		reveal_materials.append(reveal_material)
	
	update_reveal_dissolve_screen_uniforms()


func get_change_wave_color() -> Color:
	return get_player_wave_color(current_fake_player_id)


func get_reveal_wave_color() -> Color:
	return get_player_wave_color(current_real_player_id)


func get_player_wave_color(player_id:int) -> Color:
	var palette:ColorPalette = get_player_palette(player_id)
	
	if palette == null:
		return Color.WHITE
	
	if palette.colors.size() <= WAVE_COLOUR_INDEX:
		return Color.WHITE
	
	return palette.colors[WAVE_COLOUR_INDEX]


func get_player_palette(player_id:int) -> ColorPalette:
	if player_id < 0:
		return null
	
	var owning_token:Token = get_owning_token()
	
	if owning_token == null:
		return null
	
	if owning_token.board == null:
		return null
	
	return owning_token.board.get_player_palette(player_id)


func get_owning_token() -> Token:
	if token != null:
		if is_instance_valid(token):
			return token
	
	token = get_parent() as Token
	return token


func collect_sprites(node:Node, results:Array[Sprite2D]) -> void:
	if node == null:
		return
	
	for child in node.get_children():
		var sprite:Sprite2D = child as Sprite2D
		
		if sprite != null:
			results.append(sprite)
		
		collect_sprites(child, results)


func set_layer_flipped(layer:Node2D, is_flipped:bool) -> void:
	if layer == null:
		return
	
	if layer.has_method("set_flipped_visual"):
		layer.set_flipped_visual(is_flipped)


func clear_dissolve_materials_from_layer(layer:Node2D) -> void:
	if layer == null:
		return
	
	var sprite_list:Array[Sprite2D] = []
	collect_sprites(layer, sprite_list)
	
	for sprite in sprite_list:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		sprite.material = null


func update_dissolve_screen_uniforms() -> void:
	var screen_data:Dictionary = get_dissolve_screen_data()
	var token_center_screen:Vector2 = screen_data["token_center_screen"]
	var dissolve_height_pixels:float = screen_data["dissolve_height_pixels"]
	
	for dissolve_material in dissolve_materials:
		if dissolve_material == null:
			continue
		
		dissolve_material.set_shader_parameter("token_center_screen", token_center_screen)
		dissolve_material.set_shader_parameter("dissolve_height_pixels", dissolve_height_pixels)


func update_reveal_dissolve_screen_uniforms() -> void:
	var screen_data:Dictionary = get_dissolve_screen_data()
	var token_center_screen:Vector2 = screen_data["token_center_screen"]
	var dissolve_height_pixels:float = screen_data["dissolve_height_pixels"]
	
	for reveal_material in reveal_materials:
		if reveal_material == null:
			continue
		
		reveal_material.set_shader_parameter("token_center_screen", token_center_screen)
		reveal_material.set_shader_parameter("dissolve_height_pixels", dissolve_height_pixels)


func get_dissolve_screen_data() -> Dictionary:
	var parent_node:Node = get_parent()
	var token_center_screen:Vector2 = global_position
	var dissolve_height_pixels:float = 120.0
	var parent_2d:Node2D = parent_node as Node2D
	
	if parent_2d != null:
		var canvas_transform:Transform2D = parent_2d.get_global_transform_with_canvas()
		token_center_screen = canvas_transform.origin
		
		var visual_scale:float = canvas_transform.y.length()
		dissolve_height_pixels = 400.0 * visual_scale
		
		if dissolve_height_pixels < 1.0:
			dissolve_height_pixels = 120.0
	
	return {
		"token_center_screen": token_center_screen,
		"dissolve_height_pixels": dissolve_height_pixels
	}
