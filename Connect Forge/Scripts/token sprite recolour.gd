extends Node2D

const SHIMMER_SHADER:Shader = preload("res://Shaders/token_shimmer.gdshader")
const FALLBACK_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/blue.tres")

enum PART {
	red,
	green,
	blue,
	cyan,
	yellow
}

var sprites:Array[Sprite2D] = []
var shimmer_materials:Array[ShaderMaterial] = []

var shimmer_tween:Tween = null
var darken_tween:Tween = null


func _ready() -> void:
	gather_sprites()
	setup_shimmer_materials()
	
	var game_manager:Node = get_tree().get_first_node_in_group("game manager")
	
	if game_manager != null:
		recolor(game_manager.current_player_id)


func recolor(player_id:int) -> void:
	var palette:ColorPalette = get_player_palette(player_id)
	recolor_with_palette(palette)


func recolor_with_palette(palette:ColorPalette) -> void:
	gather_sprites()
	
	var used_palette:ColorPalette = get_valid_palette_or_fallback(palette)
	
	for sprite in sprites:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		if sprite.name.contains("red"):
			sprite.modulate = get_part_color(PART.red, used_palette)
		elif sprite.name.contains("green"):
			sprite.modulate = get_part_color(PART.green, used_palette)
		elif sprite.name.contains("blue"):
			sprite.modulate = get_part_color(PART.blue, used_palette)
		elif sprite.name.contains("cyan"):
			sprite.modulate = get_part_color(PART.cyan, used_palette)
		elif sprite.name.contains("yellow"):
			sprite.modulate = get_part_color(PART.yellow, used_palette)


func get_player_palette(player_id:int) -> ColorPalette:
	if MatchData.config == null:
		return FALLBACK_PALETTE
	
	var palette:ColorPalette = MatchData.config.get_player_palette(player_id)
	
	if is_valid_palette(palette):
		return palette
	
	return FALLBACK_PALETTE


func get_valid_palette_or_fallback(palette:ColorPalette) -> ColorPalette:
	if is_valid_palette(palette):
		return palette
	
	return FALLBACK_PALETTE


func is_valid_palette(palette:ColorPalette) -> bool:
	if palette == null:
		return false
	
	if palette.colors.size() < 5:
		return false
	
	return true


func get_part_color(part_id:int, palette:ColorPalette) -> Color:
	var used_palette:ColorPalette = get_valid_palette_or_fallback(palette)
	
	if used_palette == null:
		return Color.WHITE
	
	if part_id < 0:
		return Color.WHITE
	
	if part_id >= used_palette.colors.size():
		return Color.WHITE
	
	return used_palette.colors[part_id]


func darken(amount:float) -> void:
	gather_sprites()
	
	for sprite in sprites:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		sprite.modulate = sprite.modulate.darkened(amount)


func gather_sprites() -> void:
	sprites.clear()
	_collect_sprites(self)


func _collect_sprites(node:Node) -> void:
	if node == null:
		return
	
	for child in node.get_children():
		var sprite:Sprite2D = child as Sprite2D
		
		if sprite != null:
			sprites.append(sprite)
		
		_collect_sprites(child)


func setup_shimmer_materials() -> void:
	shimmer_materials.clear()
	gather_sprites()
	
	for sprite in sprites:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		var shimmer_material:ShaderMaterial = sprite.material as ShaderMaterial
		
		if shimmer_material == null or shimmer_material.shader != SHIMMER_SHADER:
			shimmer_material = ShaderMaterial.new()
			shimmer_material.shader = SHIMMER_SHADER
			sprite.material = shimmer_material
		else:
			shimmer_material = shimmer_material.duplicate() as ShaderMaterial
			sprite.material = shimmer_material
		
		shimmer_material.set_shader_parameter("shimmer_progress", -1.0)
		shimmer_materials.append(shimmer_material)


func play_shimmer(duration:float = 0.45, direction:Vector2 = Vector2(1.0, -1.0), strength:float = 0.75) -> void:
	setup_shimmer_materials()
	
	if shimmer_materials.is_empty():
		return
	
	if shimmer_tween != null and shimmer_tween.is_running():
		shimmer_tween.kill()
	
	var normal_direction:Vector2 = direction.normalized()
	
	if normal_direction == Vector2.ZERO:
		normal_direction = Vector2(1.0, -1.0).normalized()
	
	var center:Vector2 = get_shimmer_center()
	
	for shimmer_material in shimmer_materials:
		if shimmer_material == null:
			continue
		
		shimmer_material.set_shader_parameter("token_center_global", center)
		shimmer_material.set_shader_parameter("shimmer_direction", normal_direction)
		shimmer_material.set_shader_parameter("shimmer_strength", strength)
		shimmer_material.set_shader_parameter("shimmer_progress", 0.0)
	
	shimmer_tween = create_tween()
	shimmer_tween.tween_method(set_shimmer_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shimmer_tween.finished.connect(finish_shimmer)


func set_shimmer_progress(value:float) -> void:
	var center:Vector2 = get_shimmer_center()
	
	for shimmer_material in shimmer_materials:
		if shimmer_material == null:
			continue
		
		shimmer_material.set_shader_parameter("token_center_global", center)
		shimmer_material.set_shader_parameter("shimmer_progress", value)


func finish_shimmer() -> void:
	for shimmer_material in shimmer_materials:
		if shimmer_material == null:
			continue
		
		shimmer_material.set_shader_parameter("shimmer_progress", -1.0)


func get_shimmer_center() -> Vector2:
	var parent_node:Node = get_parent()
	var parent_node_2d:Node2D = parent_node as Node2D
	
	if parent_node_2d != null:
		return parent_node_2d.global_position
	
	return global_position


func tween_darken(amount:float = 0.3, duration:float = 0.18) -> Tween:
	gather_sprites()
	
	if darken_tween != null and darken_tween.is_running():
		darken_tween.kill()
	
	darken_tween = create_tween()
	darken_tween.set_parallel(true)
	
	for sprite in sprites:
		if sprite == null:
			continue
		
		if is_instance_valid(sprite) == false:
			continue
		
		var target_color:Color = sprite.modulate.darkened(amount)
		darken_tween.tween_property(sprite, "modulate", target_color, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	return darken_tween


func set_flipped_visual(is_flipped:bool) -> void:
	var icon:Node2D = get_icon_node()
	
	if icon == null:
		return
	
	if is_flipped:
		icon.scale.x = -abs(icon.scale.x)
	else:
		icon.scale.x = abs(icon.scale.x)


func get_icon_node() -> Node2D:
	var icon:Node = find_child("Icon", true, false)
	return icon as Node2D
