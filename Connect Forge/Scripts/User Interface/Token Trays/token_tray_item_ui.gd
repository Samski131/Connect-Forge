class_name TokenTrayItemUI
extends PanelContainer

var player_id:int = -1
var token_type:int = -1
var game_manager:Node = null
var token_tray_inventory:TokenTrayInventory = null
var drag_controller:TokenDragController = null

@onready var icon_rect:TextureRect = $"Margin/Root (Vbox)/Icon Control/Icon (Texture Rect)"
@onready var count_label:Label = $"Margin/Root (Vbox)/Icon Control/Count Badge Panel/Count Label"


func setup(new_game_manager:Node, new_player_id:int, new_token_type:int) -> void:
	game_manager = new_game_manager
	player_id = new_player_id
	token_type = new_token_type
	
	token_tray_inventory = get_tree().get_first_node_in_group("token tray inventory") as TokenTrayInventory
	drag_controller = get_tree().get_first_node_in_group("token drag controller") as TokenDragController
	
	if token_tray_inventory != null:
		if token_tray_inventory.token_count_changed.is_connected(_on_token_count_changed) == false:
			token_tray_inventory.token_count_changed.connect(_on_token_count_changed)
	
	refresh()


func refresh() -> void:

	if token_tray_inventory == null:
		return
	
	var icon_texture:Texture2D = token_tray_inventory.get_token_icon(token_type)
	var token_count:int = token_tray_inventory.get_token_count(player_id, token_type)
	
	icon_rect.texture = icon_texture
	count_label.text = "x" + str(token_count)
	tooltip_text = token_tray_inventory.get_token_description(token_type)
	
	apply_count_visual(token_count)


func apply_count_visual(token_count:int) -> void:
	if token_count <= 0:
		modulate = Color(0.35, 0.35, 0.35, 0.75)
		return
	
	modulate = Color.WHITE


func _gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton == false:
		return
	
	var mouse_event:InputEventMouseButton = event as InputEventMouseButton
	
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if mouse_event.pressed == false:
		return
	
	if drag_controller == null:
		return
	
	drag_controller.begin_drag(player_id, token_type)
	accept_event()


func _on_token_count_changed(changed_player_id:int, changed_token_type:int, _new_count:int) -> void:
	if changed_player_id != player_id:
		return
	
	if changed_token_type != token_type:
		return
	
	refresh()
