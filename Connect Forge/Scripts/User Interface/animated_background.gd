@tool
class_name AnimatedBackground
extends ColorRect

enum PatternShape { DOTS, DIAMONDS, SQUARES, HEXES, DIAGONAL_LINES, OCTAGONS }

const BACKGROUND_SHADER:Shader = preload("res://Shaders/background.gdshader")

@export_group("Colours")
## Top of the base vertical background gradient.
@export var top_color:Color = Color(0.02, 0.10, 0.35, 1.0)
## Bottom of the base vertical background gradient.
@export var bottom_color:Color = Color(0.03, 0.01, 0.18, 1.0)
## Main glow colour blended into the background.
@export var accent_color:Color = Color(0.0, 0.75, 1.0, 1.0)
## Secondary glow colour blended into the background.
@export var second_accent_color:Color = Color(0.45, 0.1, 1.0, 1.0)
## Colour used for the repeating background pattern.
@export var pattern_color:Color = Color(0.25, 0.75, 1.0, 1.0)
## Colour used around the screen edges for the vignette.
@export var vignette_color:Color = Color(0.0, 0.0, 0.08, 1.0)

@export_group("Accent Glows")
## Strength of the main glow.
@export_range(0.0, 1.0) var accent_strength:float = 0.32
## Strength of the secondary glow.
@export_range(0.0, 1.0) var second_accent_strength:float = 0.22
## Size of the main glow. Higher values spread it further.
@export_range(0.05, 1.5) var accent_radius:float = 0.75
## Size of the secondary glow. Higher values spread it further.
@export_range(0.05, 1.5) var second_accent_radius:float = 0.85
## Screen-space position of the main glow. Uses 0.0 to 1.0 UV coordinates.
@export var accent_position:Vector2 = Vector2(0.82, 0.18)
## Screen-space position of the secondary glow. Uses 0.0 to 1.0 UV coordinates.
@export var second_accent_position:Vector2 = Vector2(0.18, 0.88)

@export_group("Pattern")
## Pattern shape selector.
@export var pattern_shape:PatternShape = PatternShape.OCTAGONS
## Number of pattern cells across the screen. Higher values make smaller, denser shapes.
@export_range(2.0, 80.0) var pattern_scale:float = 15
## Base size of each pattern shape inside its cell.
@export_range(0.01, 0.5) var pattern_size:float = 0.3
## Edge softness of each pattern shape.
@export_range(0.001, 0.2) var pattern_softness:float = 0.07
## Overall visibility of the pattern.
@export_range(0.0, 1.0) var pattern_alpha:float = 0.085
## Direction the pattern moves in, measured in degrees. 0 moves right, 90 moves down.
@export_range(0.0, 360.0) var pattern_direction_degrees:float = 25.0
## Speed of the pattern drift.
@export_range(0.0, 0.2) var pattern_move_speed:float = 0.014
## Gentle wave distortion applied to the pattern movement.
@export_range(0.0, 0.1) var wave_strength:float = 0.015

@export_group("Shape Noise")
## Strength of random per-shape size variation.
@export_range(0.0, 1.0) var shape_noise_strength:float = 1.0
## Scale of the noise controlling shape sizes. Higher values make variation change more frequently.
@export_range(0.1, 20.0) var shape_noise_scale:float = 20.0
## Speed of the animated noise controlling shape sizes.
@export_range(0.0, 2.0) var shape_noise_speed:float = 0.492

@export_group("Vignette")
## Strength of darkening around the screen edges.
@export_range(0.0, 1.0) var vignette_strength:float = 0.55

var shader_material:ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_material()
	_apply_shader_parameters()




func _notification(what:int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_shader_parameters()


func _setup_material() -> void:
	var current_material:ShaderMaterial = material as ShaderMaterial
	
	if current_material == null:
		current_material = ShaderMaterial.new()
		material = current_material
	
	shader_material = current_material
	shader_material.shader = BACKGROUND_SHADER


func _apply_shader_parameters() -> void:
	if shader_material == null:
		_setup_material()
	
	if shader_material == null:
		return
	
	var used_size:Vector2 = size
	
	if used_size.x <= 0.0 or used_size.y <= 0.0:
		used_size = get_viewport_rect().size
	
	var aspect_ratio:float = 1.0
	
	if used_size.y > 0.0:
		aspect_ratio = used_size.x / used_size.y
	
	shader_material.set_shader_parameter("top_color", top_color)
	shader_material.set_shader_parameter("bottom_color", bottom_color)
	shader_material.set_shader_parameter("accent_color", accent_color)
	shader_material.set_shader_parameter("second_accent_color", second_accent_color)
	shader_material.set_shader_parameter("pattern_color", pattern_color)
	shader_material.set_shader_parameter("vignette_color", vignette_color)
	
	shader_material.set_shader_parameter("accent_strength", accent_strength)
	shader_material.set_shader_parameter("second_accent_strength", second_accent_strength)
	shader_material.set_shader_parameter("accent_radius", accent_radius)
	shader_material.set_shader_parameter("second_accent_radius", second_accent_radius)
	shader_material.set_shader_parameter("accent_position", accent_position)
	shader_material.set_shader_parameter("second_accent_position", second_accent_position)
	
	shader_material.set_shader_parameter("pattern_shape", int(pattern_shape))
	shader_material.set_shader_parameter("pattern_scale", pattern_scale)
	shader_material.set_shader_parameter("pattern_size", pattern_size)
	shader_material.set_shader_parameter("pattern_softness", pattern_softness)
	shader_material.set_shader_parameter("pattern_alpha", pattern_alpha)
	shader_material.set_shader_parameter("pattern_direction_degrees", pattern_direction_degrees)
	shader_material.set_shader_parameter("pattern_move_speed", pattern_move_speed)
	shader_material.set_shader_parameter("wave_strength", wave_strength)
	
	shader_material.set_shader_parameter("shape_noise_strength", shape_noise_strength)
	shader_material.set_shader_parameter("shape_noise_scale", shape_noise_scale)
	shader_material.set_shader_parameter("shape_noise_speed", shape_noise_speed)
	
	shader_material.set_shader_parameter("vignette_strength", vignette_strength)
	shader_material.set_shader_parameter("aspect_ratio", aspect_ratio)
