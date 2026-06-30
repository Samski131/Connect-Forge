class_name TokenTrayItemUI
extends EffectControl

@export_group("Invalid Drag Feedback")
@export var invalid_turn_shake_intensity:float = 5.0
@export var invalid_turn_shake_duration:float = 0.18
@export var invalid_turn_shakes:int = 3
@export var invalid_turn_shake_visual_only:bool = true

var player_id:int = -1
var token_type:int = -1
var game_manager:Node = null
var token_tray_inventory:TokenTrayInventory = null
var drag_controller:TokenDragController = null

@onready var token_visual_display:TokenVisualDisplay = $"Margin/Root (Vbox)/Icon Control/Token Visual Display"
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
	
	setup_visual()
	refresh()


func setup_visual() -> void:
	if token_visual_display == null:
		return
	
	token_visual_display.setup(token_type, player_id)


func refresh() -> void:
	if token_tray_inventory == null:
		return
	
	var token_count:int = token_tray_inventory.get_token_count(player_id, token_type)
	
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
	
	if is_wrong_player_turn():
		play_invalid_turn_feedback()
		accept_event()
		return
	
	if player_has_no_tokens():
		play_invalid_turn_feedback()
		accept_event()
		return
	
	if drag_controller == null:
		return
	
	drag_controller.begin_drag(player_id, token_type)
	accept_event()


func is_wrong_player_turn() -> bool:
	if game_manager == null:
		return false
	
	if player_id != game_manager.current_player_id:
		return true
	
	return false


func play_invalid_turn_feedback() -> void:
	queue_ui_effect(UIShakeEffect.new(self, invalid_turn_shake_intensity, invalid_turn_shake_duration, invalid_turn_shakes, invalid_turn_shake_visual_only), false)


func _on_token_count_changed(changed_player_id:int, changed_token_type:int, _new_count:int) -> void:
	if changed_player_id != player_id:
		return
	
	if changed_token_type != token_type:
		return
	
	pulse()
	refresh()

func player_has_no_tokens() -> bool:
	if token_tray_inventory == null:
		return false
	
	var token_count:int = token_tray_inventory.get_token_count(player_id, token_type)
	
	if token_count <= 0:
		return true
	
	return false
