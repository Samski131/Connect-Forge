extends Node2D

const SHIMMER_SHADER:Shader = preload("res://Shaders/token_shimmer.gdshader")

var sprites:Array = []
var shimmer_materials:Array = []

enum PART { red, green, blue, cyan, yellow }

var game_manager:Node
var shimmer_tween:Tween = null
var darken_tween:Tween = null

func _ready():
	game_manager = get_tree().get_first_node_in_group("game manager")
	gather_sprites()
	setup_shimmer_materials()
	recolor(game_manager.current_player_id)


func recolor(player_id:int):
	gather_sprites()

	for sprite in sprites:
		if sprite.name.contains("red"):
			sprite.modulate = get_part_color(PART.red, player_id)
		elif sprite.name.contains("green"):
			sprite.modulate = get_part_color(PART.green, player_id)
		elif sprite.name.contains("blue"):
			sprite.modulate = get_part_color(PART.blue, player_id)
		elif sprite.name.contains("cyan"):
			sprite.modulate = get_part_color(PART.cyan, player_id)
		elif sprite.name.contains("yellow"):
			sprite.modulate = get_part_color(PART.yellow, player_id)


func darken(amount:float):
	gather_sprites()

	for sprite in sprites:
		sprite.modulate = sprite.modulate.darkened(amount)


func gather_sprites():
	sprites.clear()

	for child in get_children(true):
		if child is Sprite2D:
			sprites.append(child)


func setup_shimmer_materials():
	shimmer_materials.clear()
	gather_sprites()

	for sprite in sprites:
		if sprite == null:
			continue

		if is_instance_valid(sprite) == false:
			continue

		var material := sprite.material as ShaderMaterial

		if material == null:
			material = ShaderMaterial.new()
			material.shader = SHIMMER_SHADER
			sprite.material = material

		material.set_shader_parameter("shimmer_progress", -1.0)
		shimmer_materials.append(material)


func play_shimmer(
	duration:float = 0.45,
	direction:Vector2 = Vector2(1.0, -1.0),
	strength:float = 0.75
):
	setup_shimmer_materials()

	if shimmer_materials.is_empty():
		return

	if shimmer_tween != null and shimmer_tween.is_running():
		shimmer_tween.kill()

	var normal_direction := direction.normalized()
	var center := get_shimmer_center()

	for material in shimmer_materials:
		if material == null:
			continue

		material.set_shader_parameter("token_center_global", center)
		material.set_shader_parameter("shimmer_direction", normal_direction)
		material.set_shader_parameter("shimmer_strength", strength)
		material.set_shader_parameter("shimmer_progress", 0.0)

	shimmer_tween = create_tween()
	shimmer_tween.tween_method(
		set_shimmer_progress,
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	shimmer_tween.finished.connect(finish_shimmer)
	
func set_shimmer_progress(value:float):
	var center := get_shimmer_center()

	for material in shimmer_materials:
		if material == null:
			continue

		material.set_shader_parameter("token_center_global", center)
		material.set_shader_parameter("shimmer_progress", value)
		
func finish_shimmer():
	for material in shimmer_materials:
		if material == null:
			continue

		material.set_shader_parameter("shimmer_progress", -1.0)

func get_shimmer_center()->Vector2:
	var parent_node := get_parent()

	if parent_node is Node2D:
		return parent_node.global_position

	return global_position

func tween_darken(amount:float = 0.3, duration:float = 0.18)->Tween:
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

		darken_tween.tween_property(
			sprite,
			"modulate",
			target_color,
			duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	return darken_tween
	
func get_part_color(part_id:int, player_id:int)->Color:
	return game_manager.player_colours[player_id].colors[part_id]
