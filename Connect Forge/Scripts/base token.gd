class_name Token
extends Area2D

# This script is the basic behaviour for every single token.
# All common functions of tokens should go here, even if some special ones will override the functions.

var player_id:int = 0
var token_pos:Vector2i = Vector2i.ZERO
var resolved:bool = false
var token_type:TokenLibrary.TokenType
var keywords:Array[Global.KEYWORD] = []
var board:BoardManager
var being_destroyed:bool = false
var is_flipped:bool = false
var gravity_visual_rotation_degrees:float = 0.0

@onready var sprites:Node2D = $Sprites
@onready var token_pos_label:Label = $"Token_pos Label"

var debug_label_visibility:bool = false

@export_group("Charges")
@export var charges:int = 0
@export var ability_cost:int = 0

@export_group("Visual Effects")
@export var destroy_duration:float = 0.2
@export var shimmer_duration:float = 0.45
@export var charge_darken_duration:float = 0.12
@export var charge_darken_amount:float = 0.3

@export_group("Flip Visual")
@export var flip_duration:float = 0.4
@export var flip_min_scale_x:float = 0.08
@export var flip_pop_scale_y:float = 1.08
func _ready():
	pass


func setup(new_board:BoardManager, new_pos:Vector2i, new_player_id:int):
	board = new_board
	token_pos = new_pos
	player_id = new_player_id
	being_destroyed = false
	is_flipped = false
	scale = Vector2.ONE
	modulate = Color.WHITE
	setup_special_token()
	recolor()
	apply_starting_flipped_visual()
	
	if board != null:
		board.apply_token_gravity_visual(self)
	
	move_token_visual()


func setup_special_token():
	token_type = TokenLibrary.TokenType.BASIC
	keywords = []


func _try_to_use_ability()->bool:
	return false


func move_token_visual():
	if board == null:
		return
	
	global_position = board.slot_to_global_position(token_pos)


func reset_resolved():
	resolved = false


func check_enough_charges(cost:int)->bool:
	if charges >= cost:
		return true
	
	return false


func deduct_charges(cost:int):
	if cost == 0:
		return
	
	charges -= cost
	
	if board != null and board.visuals != null:
		var darken_effect:ColorTweenVisualEffect = ColorTweenVisualEffect.new(self, ColorTweenVisualEffect.MODE.DARKEN, board.visuals.darken_amount, board.visuals.darken_duration)
		queue_visual_effect(darken_effect)
		return
	
	if sprites != null and sprites.has_method("darken"):
		sprites.darken(0.3)


func regain_charges(cost:int) -> void:
	charges += cost
	
	if sprites != null and sprites.has_method("recolor"):
		sprites.recolor(player_id)


func recolor():
	if sprites == null:
		return
	
	if sprites.has_method("recolor"):
		sprites.recolor(player_id)


func debug_token():
	token_pos_label.visible = debug_label_visibility
	token_pos_label.text = str(player_id)


func has_keyword(keyword:Global.KEYWORD)->bool:
	return keyword in keywords


func trigger_keyword(keyword:Global.KEYWORD, context:Dictionary) -> bool:
	if has_keyword(keyword) == false:
		return false
	
	match keyword:
		Global.KEYWORD.ON_LAND:
			return _on_land(context)
		Global.KEYWORD.ON_IMPACT:
			return _on_impact(context)
		Global.KEYWORD.ON_PASS_LEFT:
			return _on_pass_left(context)
		Global.KEYWORD.ON_PASS_RIGHT:
			return _on_pass_right(context)
		Global.KEYWORD.ON_PASS_ABOVE:
			return _on_pass_above(context)
		Global.KEYWORD.ON_PASS_BELOW:
			return _on_pass_below(context)
		Global.KEYWORD.ON_LINE_FULL:
			return _on_line_full(context)
	
	return false


func _on_land(_context:Dictionary)->bool:
	return false


func _on_impact(_context:Dictionary)->bool:
	return false


func _on_pass_left(_context:Dictionary)->bool:
	return false


func _on_pass_right(_context:Dictionary)->bool:
	return false


func _on_pass_above(_context:Dictionary)->bool:
	return false


func _on_pass_below(_context:Dictionary)->bool:
	return false


func _on_line_full(_context:Dictionary)->bool:
	return false


func _can_trigger_keyword(keyword:Global.KEYWORD, _context:Dictionary = {})->bool:
	if has_keyword(keyword) == false:
		return false
	
	if check_enough_charges(ability_cost) == false:
		return false
	
	return true



func toggle_flipped() -> void:
	set_flipped(not is_flipped)



func queue_visual_effect(effect:BoardVisualEffect, batch_parallel:bool = false) -> void:
	if effect == null:
		return
	
	if board == null:
		return
	
	if board.visuals == null:
		return
	
	board.visuals.queue_effect(effect, batch_parallel)


func set_flipped(new_is_flipped:bool) -> void:
	is_flipped = new_is_flipped
	apply_flipped_visual()


func flip_token() -> void:
	if is_flipped:
		set_flipped(false)
	else:
		set_flipped(true)


func apply_starting_flipped_visual() -> void:
	apply_flipped_visual()


func apply_flipped_visual() -> void:
	if sprites == null:
		return
	
	if is_flipped:
		sprites.scale.x = -abs(sprites.scale.x)
	else:
		sprites.scale.x = abs(sprites.scale.x)
