class_name TokenVisualDisplay
extends Control

@export var visual_scale:float = 0.19
@export var visual_rotation_degrees:float = 0.0

var token_type:int = -1
var player_id:int = -1
var is_flipped:bool = false
var visual_root:Node2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	call_deferred("refresh_layout")
	setup(0,0,false)


func setup(new_token_type:int, new_player_id:int, new_is_flipped:bool = false) -> void:
	if token_type == new_token_type and player_id == new_player_id and is_flipped == new_is_flipped and visual_root != null:
		call_deferred("apply_visual_setup")
		return
	
	token_type = new_token_type
	player_id = new_player_id
	is_flipped = new_is_flipped
	
	clear_visual()
	create_visual()


func clear_visual() -> void:
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
	
	_call_method_recursive(visual_root, "recolor", [player_id])
	
	if is_flipped:
		_call_method_recursive(visual_root, "set_flipped_visual", [true])
	else:
		_call_method_recursive(visual_root, "set_flipped_visual", [false])
	
	refresh_layout()


func refresh_layout() -> void:
	if visual_root == null:
		return
	
	if is_instance_valid(visual_root) == false:
		return
	
	visual_root.position = size * 0.5
	visual_root.scale = Vector2(visual_scale, visual_scale)
	visual_root.rotation_degrees = visual_rotation_degrees


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
