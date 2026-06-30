class_name PlayerTokenTraysUI
extends VBoxContainer

@export var player_tray_scene:PackedScene

@export_group("Active Tray Slide")
@export var active_slide_distance:float = 30.0
@export var active_slide_duration:float = 0.45
@export var active_slide_trans:Tween.TransitionType = Tween.TRANS_ELASTIC
@export var active_slide_ease:Tween.EaseType = Tween.EASE_OUT

@export_group("Inactive Tray Slide")
@export var home_slide_duration:float = 0.2
@export var home_slide_trans:Tween.TransitionType = Tween.TRANS_BOUNCE
@export var home_slide_ease:Tween.EaseType = Tween.EASE_OUT

@export_group("Tray Dimming")
@export var active_tray_modulate:Color = Color.WHITE
@export var inactive_tray_modulate:Color = Color(0.82, 0.82, 0.82, 1.0)
@export var tray_dim_duration:float = 0.25
@export var tray_dim_trans:Tween.TransitionType = Tween.TRANS_SINE
@export var tray_dim_ease:Tween.EaseType = Tween.EASE_OUT

var game_manager:Node = null
var trays:Array[PlayerTokenTrayUI] = []


func _ready() -> void:
	add_to_group("player token trays ui")
	game_manager = get_tree().get_first_node_in_group("game manager")
	connect_game_manager_signals()
	rebuild_trays()


func connect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.has_signal("current_player_changed"):
		if game_manager.current_player_changed.is_connected(_on_current_player_changed) == false:
			game_manager.current_player_changed.connect(_on_current_player_changed)


func rebuild_trays() -> void:
	clear_trays()
	
	if game_manager == null:
		game_manager = get_tree().get_first_node_in_group("game manager")
	
	if game_manager == null:
		return
	
	connect_game_manager_signals()
	
	if player_tray_scene == null:
		return
	
	for player_id in range(game_manager.number_of_players):
		create_player_tray(player_id)
	
	update_current_player_tray_visuals(false)


func create_player_tray(player_id:int) -> void:
	var tray:PlayerTokenTrayUI = player_tray_scene.instantiate() as PlayerTokenTrayUI
	
	if tray == null:
		return
	
	add_child(tray)
	tray.setup_tray(game_manager, player_id)
	setup_tray_offset_transform(tray)
	trays.append(tray)


func setup_tray_offset_transform(tray:Control) -> void:
	if tray == null:
		return
	
	tray.offset_transform_enabled = true
	tray.offset_transform_visual_only = false
	tray.offset_transform_position_ratio = Vector2.ZERO
	
	if tray.offset_transform_position == Vector2.ZERO:
		tray.offset_transform_position = Vector2.ZERO


func clear_trays() -> void:
	trays.clear()
	
	for child in get_children():
		child.queue_free()


func refresh_trays() -> void:
	for tray in trays:
		if tray == null:
			continue
		
		if is_instance_valid(tray) == false:
			continue
		
		tray.refresh_player_details()


func update_current_player_tray_visuals(animated:bool = true) -> void:
	if game_manager == null:
		return
	
	for tray in trays:
		if tray == null:
			continue
		
		if is_instance_valid(tray) == false:
			continue
		
		setup_tray_offset_transform(tray)
		
		var target_offset:Vector2 = Vector2.ZERO
		var target_modulate:Color = inactive_tray_modulate
		var slide_duration:float = home_slide_duration
		var slide_trans:Tween.TransitionType = home_slide_trans
		var slide_ease:Tween.EaseType = home_slide_ease
		
		if tray.player_id == game_manager.current_player_id:
			target_offset = Vector2(-active_slide_distance, 0.0)
			target_modulate = active_tray_modulate
			slide_duration = active_slide_duration
			slide_trans = active_slide_trans
			slide_ease = active_slide_ease
		
		if animated:
			tray.queue_ui_effect(UISlideToOffsetEffect.new(tray, target_offset, slide_duration, false, slide_trans, slide_ease), false)
			tray.queue_ui_effect(UIModulateEffect.new(tray, target_modulate, tray_dim_duration, tray_dim_trans, tray_dim_ease), false)
		else:
			tray.offset_transform_position = target_offset
			tray.modulate = target_modulate

func _on_current_player_changed(_player_id:int) -> void:
	update_current_player_tray_visuals(true)
