class_name TokenTrayItemUI
extends PanelContainer

@export_group("Invalid Drag Feedback")
@export var invalid_feedback_preset:UIJuicePreset = preload("res://Assets/User Interface/Resources/Feedback/invalid_shake.tres")

var player_id:int = -1
var token_type:int = -1
var game_manager:GameManager = null
var token_tray_inventory:TokenTrayInventory = null
var drag_controller:TokenDragController = null

@onready var token_visual_display:TokenVisualDisplay = $"Margin/Root (Vbox)/Icon Control/Token Visual Display"
@onready var count_label:Label = $"Margin/Root (Vbox)/Icon Control/Count Badge Panel/Count Label"


func setup(new_game_manager:GameManager, new_token_tray_inventory:TokenTrayInventory, new_drag_controller:TokenDragController, new_player_id:int, new_token_type:int) -> void:
	disconnect_inventory_signals()
	
	game_manager = new_game_manager
	token_tray_inventory = new_token_tray_inventory
	drag_controller = new_drag_controller
	player_id = new_player_id
	token_type = new_token_type
	
	connect_inventory_signals()
	setup_visual()
	refresh()


func connect_inventory_signals() -> void:
	if token_tray_inventory == null:
		return
	
	if token_tray_inventory.token_count_changed.is_connected(_on_token_count_changed) == false:
		token_tray_inventory.token_count_changed.connect(_on_token_count_changed)


func disconnect_inventory_signals() -> void:
	if token_tray_inventory == null:
		return
	
	if token_tray_inventory.token_count_changed.is_connected(_on_token_count_changed):
		token_tray_inventory.token_count_changed.disconnect(_on_token_count_changed)


func setup_visual() -> void:
	if token_visual_display == null:
		return
	
	if game_manager == null:
		token_visual_display.setup(token_type, player_id)
		return
	
	var palette:ColorPalette = game_manager.get_player_palette(player_id)
	
	if palette == null:
		token_visual_display.setup(token_type, player_id)
		return
	
	token_visual_display.setup_with_palette(token_type, player_id, palette)


func refresh() -> void:
	if token_tray_inventory == null:
		return
	
	if count_label == null:
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
	
	if player_id != game_manager.get_current_player_id():
		return true
	
	return false


func player_has_no_tokens() -> bool:
	if token_tray_inventory == null:
		return false
	
	var token_count:int = token_tray_inventory.get_token_count(player_id, token_type)
	
	if token_count <= 0:
		return true
	
	return false


func play_invalid_turn_feedback() -> void:
	if invalid_feedback_preset == null:
		return
	
	var player:UIJuicePlayer = UIJuice.get_or_create_player(self)
	
	if player == null:
		return
	
	player.play_preset(invalid_feedback_preset, Callable(self, "_on_invalid_feedback_finished"))


func _on_invalid_feedback_finished() -> void:
	refresh()


func play_count_changed_feedback() -> void:
	var preset:UIJuicePreset = UIJuice.create_pulse_preset()
	UIJuice.play(self, preset)


func _on_token_count_changed(changed_player_id:int, changed_token_type:int, _new_count:int) -> void:
	if changed_player_id != player_id:
		return
	
	if changed_token_type != token_type:
		return
	
	play_count_changed_feedback()
	refresh()
