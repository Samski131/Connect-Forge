class_name MultiplayerCursorVisual
extends Control

const FALLBACK_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/blue_v3.tres")

@export_group("Palette")
@export_range(0, 6, 1) var bright_main_palette_index:int = 1
@export_range(0, 6, 1) var dark_main_palette_index:int = 2
@export_range(0, 6, 1) var player_name_palette_index:int = 1

@export_group("Neutral Colours")
@export var outline_colour:Color = Color(0.90, 0.93, 0.94, 1.0)
@export var outline_highlight_colour:Color = Color.WHITE

@export_group("Appearance")
@export_range(0.25, 1.5, 0.05) var visual_scale:float = 0.70

@export_group("Movement")
@export var follow_speed:float = 22.0

@export_group("Inactivity")
@export_range(0.0, 1.0, 0.05) var idle_alpha:float = 0.35
@export_range(0.0, 1.0, 0.05) var idle_fade_duration:float = 0.25

@onready var dark_main:TextureRect = %DarkMain
@onready var outline:TextureRect = %Outline
@onready var bright_main:TextureRect = %BrightMain
@onready var outline_highlight:TextureRect = %OutlineHighlight
@onready var player_name_label:Label = %PlayerName

var player_id:int = -1
var target_position:Vector2 = Vector2.ZERO
var has_received_position:bool = false
var opacity_tween:Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	dark_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bright_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	apply_visual_scale()
	visible = false


func _process(delta:float) -> void:
	if has_received_position == false:
		return
	
	update_visual_position(delta)


func setup(new_player_id:int, new_player_name:String, palette:ColorPalette) -> void:
	player_id = new_player_id
	
	set_player_name(new_player_name)
	apply_palette(palette)
	apply_visual_scale()


func set_player_name(new_player_name:String) -> void:
	var used_name:String = new_player_name.strip_edges()
	
	if used_name == "":
		used_name = "Player " + str(player_id + 1)
	
	player_name_label.text = used_name


func apply_palette(palette:ColorPalette) -> void:
	var used_palette:ColorPalette = get_valid_palette_or_fallback(palette)
	
	bright_main.modulate = get_palette_colour(used_palette, bright_main_palette_index, Color.WHITE)
	dark_main.modulate = get_palette_colour(used_palette, dark_main_palette_index, Color(0.3, 0.3, 0.3, 1.0))
	
	outline.modulate = outline_colour
	outline_highlight.modulate = outline_highlight_colour
	
	var name_colour:Color = get_palette_colour(used_palette, player_name_palette_index, Color.WHITE)
	player_name_label.add_theme_color_override("font_color", name_colour)


func set_visual_scale(new_scale:float) -> void:
	visual_scale = clamp(new_scale, 0.25, 1.5)
	apply_visual_scale()


func apply_visual_scale() -> void:
	scale = Vector2(visual_scale, visual_scale)


func set_target_position(new_position:Vector2) -> void:
	if has_received_position == false:
		set_position_immediately(new_position)
		return
	
	target_position = new_position


func set_position_immediately(new_position:Vector2) -> void:
	target_position = new_position
	position = new_position
	has_received_position = true
	visible = true


func set_cursor_visible(should_be_visible:bool) -> void:
	visible = should_be_visible
	
	if should_be_visible == false:
		has_received_position = false
		reset_idle_visual()


func set_idle_visual(is_idle:bool) -> void:
	var target_alpha:float = 1.0
	
	if is_idle:
		target_alpha = idle_alpha
	
	if opacity_tween != null:
		if opacity_tween.is_valid():
			opacity_tween.kill()
	
	if idle_fade_duration <= 0.0:
		modulate.a = target_alpha
		return
	
	opacity_tween = create_tween()
	opacity_tween.tween_property(self, "modulate:a", target_alpha, idle_fade_duration)


func reset_idle_visual() -> void:
	if opacity_tween != null:
		if opacity_tween.is_valid():
			opacity_tween.kill()
	
	modulate.a = 1.0


func update_visual_position(delta:float) -> void:
	if follow_speed <= 0.0:
		position = target_position
		return
	
	var follow_weight:float = 1.0 - exp(-follow_speed * delta)
	position = position.lerp(target_position, follow_weight)


func get_valid_palette_or_fallback(palette:ColorPalette) -> ColorPalette:
	if is_valid_palette(palette):
		return palette
	
	return FALLBACK_PALETTE


func is_valid_palette(palette:ColorPalette) -> bool:
	if palette == null:
		return false
	
	if palette.colors.is_empty():
		return false
	
	return true


func get_palette_colour(palette:ColorPalette, palette_index:int, fallback_colour:Color) -> Color:
	if palette == null:
		return fallback_colour
	
	if palette_index < 0:
		return fallback_colour
	
	if palette_index >= palette.colors.size():
		return fallback_colour
	
	return palette.colors[palette_index]
