@tool
class_name Slot
extends Area2D

enum VisualState { NORMAL, HIGHLIGHTED, HOVERED }

const SLOT_BACK_SHADER:Shader = preload("res://Shaders/slot_back.gdshader")

@export_group("Slot Colours")
## Normal colour used by most slots.
@export var background_color:Color = Color(0.0392157, 0.2901961, 0.2862745, 1.0) #0A4A49
## Colour used for the valid placement edge based on gravity direction.
@export var highlight_color:Color = Color(0.2, 0.5254902, 0.5098039, 1.0) #338682
## Colour used when the mouse is over this slot.
@export var hover_color:Color = Color(0.5411765, 0.9490196, 0.7882353, 1.0) #8AF2C9
## Inner rim glow colour.
@export var rim_color:Color = Color(0.7137255, 0.9607843, 0.8705882, 1.0) #B6F5DE
## Colour tint applied to the front frame texture.
@export var front_frame_color:Color = Color(0.9490196, 0.9803922, 1.0, 1.0) #F2FAFF

@export_group("Slot Shader")
## How strongly the highlight colour replaces the normal colour.
@export_range(0.0, 1.0) var highlight_mix:float = 0.68
## How strongly the hover colour replaces the normal colour.
@export_range(0.0, 1.0) var hover_mix:float = 0.82
## Strength of the soft inner rim.
@export_range(0.0, 1.0) var rim_strength:float = 0.18
## Extra rim strength added when the slot is highlighted or hovered.
@export_range(0.0, 1.0) var active_rim_boost:float = 0.24
## How far inward the rim reaches.
@export_range(0.0, 0.5) var rim_size:float = 0.361
## Softness of the inner rim.
@export_range(0.001, 0.5) var rim_softness:float = 0.386
## Strength of the animated pulse on highlighted or hovered slots.
@export_range(0.0, 1.0) var pulse_strength:float = 0.08
## Speed of the animated pulse.
@export_range(0.0, 10.0) var pulse_speed:float = 1.4
## Darkening in the centre of the slot, giving it recessed depth.
@export_range(0.0, 1.0) var centre_depth_strength:float = 0.707
## Size of the central recessed area.
@export_range(0.0, 1.0) var centre_depth_size:float = 0.42
## Softness of the central recessed area.
@export_range(0.001, 1.0) var centre_depth_softness:float = 0.38
## Subtle lower shading amount.
@export_range(0.0, 1.0) var vertical_shade_strength:float = 0.28
## How octagonal the depth shape is. Lower is softer/rounder, higher is sharper.
@export_range(0.0, 1.0) var octagon_corner_strength:float = 0.7

@export_group("Debug")
## Shows the grid coordinate label on this slot.
@export var show_debug_label:bool = false

var slot_types:Array = []
var slot_position:Vector2i = Vector2i.ZERO
var board:Node = null
var visual_state:VisualState = VisualState.NORMAL
var back_material:ShaderMaterial = null

@onready var back:Sprite2D = $Back
@onready var front:Sprite2D = $Front
@onready var slot_label:Label = $"Slot Label"


func _ready() -> void:
	_setup_visuals()
	_update_debug_label()
	refresh_visual_state()

func _process(_delta:float) -> void:
	if Engine.is_editor_hint():
		_apply_shader_parameters()


func setup_slot(new_board:Node, new_position:Vector2i, new_slot_types:Array) -> void:
	board = new_board
	slot_position = new_position
	slot_types = new_slot_types
	
	_update_debug_label()
	refresh_visual_state()


func _on_mouse_entered() -> void:
	if _is_current_placeable_slot() == false:
		if board != null and board.has_method("clear_hovered_slot"):
			board.clear_hovered_slot(self)
		
		refresh_visual_state()
		return
	
	if board != null and board.has_method("set_hovered_slot"):
		board.set_hovered_slot(self)
	
	set_visual_state(VisualState.HOVERED)


func _on_mouse_exited() -> void:
	if board != null and board.has_method("clear_hovered_slot"):
		board.clear_hovered_slot(self)
	
	refresh_visual_state()


func refresh_visual_state() -> void:
	if Engine.is_editor_hint():
		if _is_valid_gravity_edge():
			set_visual_state(VisualState.HIGHLIGHTED)
			return
		
		set_visual_state(VisualState.NORMAL)
		return
	
	if board == null:
		set_visual_state(VisualState.NORMAL)
		return
	
	if _is_current_placeable_slot():
		set_visual_state(VisualState.HIGHLIGHTED)
		return
	
	set_visual_state(VisualState.NORMAL)


func _is_current_placeable_slot() -> bool:
	if board == null:
		return false
	
	if _is_valid_gravity_edge() == false:
		return false
	
	if board.has_method("get_token") == false:
		return false
	
	if board.get_token(slot_position) != null:
		return false
	
	return true

func set_visual_state(new_visual_state:VisualState) -> void:
	visual_state = new_visual_state
	_apply_shader_parameters()


func _setup_visuals() -> void:
	if back != null:
		var new_material:ShaderMaterial = null
		var current_material:ShaderMaterial = back.material as ShaderMaterial
		
		if current_material != null:
			new_material = current_material.duplicate(true) as ShaderMaterial
		else:
			new_material = ShaderMaterial.new()
		
		new_material.resource_local_to_scene = true
		new_material.shader = SLOT_BACK_SHADER
		
		back.material = new_material
		back_material = new_material
	
	if front != null:
		front.modulate = front_frame_color
	
	_apply_shader_parameters()


func _apply_shader_parameters() -> void:
	if back == null:
		return
	
	if back_material == null:
		var current_material:ShaderMaterial = back.material as ShaderMaterial
		
		if current_material == null:
			current_material = ShaderMaterial.new()
			back.material = current_material
		
		back_material = current_material
		back_material.shader = SLOT_BACK_SHADER
	
	back_material.set_shader_parameter("base_color", background_color)
	back_material.set_shader_parameter("highlight_color", highlight_color)
	back_material.set_shader_parameter("hover_color", hover_color)
	back_material.set_shader_parameter("rim_color", rim_color)
	back_material.set_shader_parameter("visual_state", int(visual_state))
	back_material.set_shader_parameter("highlight_mix", highlight_mix)
	back_material.set_shader_parameter("hover_mix", hover_mix)
	back_material.set_shader_parameter("rim_strength", rim_strength)
	back_material.set_shader_parameter("active_rim_boost", active_rim_boost)
	back_material.set_shader_parameter("rim_size", rim_size)
	back_material.set_shader_parameter("rim_softness", rim_softness)
	back_material.set_shader_parameter("pulse_strength", pulse_strength)
	back_material.set_shader_parameter("pulse_speed", pulse_speed)
	back_material.set_shader_parameter("centre_depth_strength", centre_depth_strength)
	back_material.set_shader_parameter("centre_depth_size", centre_depth_size)
	back_material.set_shader_parameter("centre_depth_softness", centre_depth_softness)
	back_material.set_shader_parameter("vertical_shade_strength", vertical_shade_strength)
	back_material.set_shader_parameter("octagon_corner_strength", octagon_corner_strength)
	
	if front != null:
		front.modulate = front_frame_color


func _is_valid_gravity_edge() -> bool:
	var gravity_direction:int = _get_board_gravity_direction()
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	match gravity_direction:
		GRID_DIRECTION.DOWN:
			if slot_types.has(Global.SLOT_TYPE.TOP_EDGE):
				return true
		
		GRID_DIRECTION.UP:
			if slot_types.has(Global.SLOT_TYPE.BOTTOM_EDGE):
				return true
		
		GRID_DIRECTION.RIGHT:
			if slot_types.has(Global.SLOT_TYPE.LEFT_EDGE):
				return true
		
		GRID_DIRECTION.LEFT:
			if slot_types.has(Global.SLOT_TYPE.RIGHT_EDGE):
				return true
	
	return false

func _get_board_gravity_direction() -> int:
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	if board == null:
		return GRID_DIRECTION.DOWN
	
	var settings_value = board.get("settings")
	
	if settings_value == null:
		return GRID_DIRECTION.DOWN
	
	var gravity_value = settings_value.get("gravity_direction")
	
	if gravity_value == null:
		return GRID_DIRECTION.DOWN
	
	return int(gravity_value)

func _update_debug_label() -> void:
	if slot_label == null:
		return
	
	slot_label.visible = show_debug_label
	slot_label.text = str(int(slot_position.x)) + "," + str(int(slot_position.y))
