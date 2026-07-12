class_name PlayerTokenTraysUI
extends VBoxContainer

@export_group("References")
@export var player_tray_scene:PackedScene

@export_group("Tray State Presets")
@export var active_tray_preset:UIJuicePreset
@export var inactive_tray_preset:UIJuicePreset

var game_manager:Node = null
var trays:Array[PlayerTokenTrayUI] = []


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	add_to_group("player token trays ui")
	connect_game_manager_signals()
	rebuild_trays()


func connect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.has_signal("current_player_changed"):
		if game_manager.current_player_changed.is_connected(_on_current_player_changed) == false:
			game_manager.current_player_changed.connect(_on_current_player_changed)
	
	if game_manager.has_signal("players_changed"):
		if game_manager.players_changed.is_connected(_on_players_changed) == false:
			game_manager.players_changed.connect(_on_players_changed)
	
	if game_manager.has_signal("player_names_changed"):
		if game_manager.player_names_changed.is_connected(_on_player_names_changed) == false:
			game_manager.player_names_changed.connect(_on_player_names_changed)


func rebuild_trays() -> void:
	clear_trays()
	
	if game_manager == null:
		return
	
	connect_game_manager_signals()
	
	if player_tray_scene == null:
		return
	
	if game_manager.has_method("get_player_count") == false:
		return
	
	var player_count:int = game_manager.get_player_count()
	
	for player_id in range(player_count):
		create_player_tray(player_id)
	
	call_deferred("update_current_player_tray_visuals")


func create_player_tray(player_id:int) -> void:
	if player_tray_scene == null:
		return
	
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
	tray.offset_transform_pivot = Vector2.ZERO
	tray.offset_transform_pivot_ratio = Vector2(0.5, 0.5)


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


func update_current_player_tray_visuals() -> void:
	if game_manager == null:
		return
	
	for tray in trays:
		if tray == null:
			continue
		
		if is_instance_valid(tray) == false:
			continue
		
		setup_tray_offset_transform(tray)
		
		var preset:UIJuicePreset = get_tray_state_preset(tray)
		
		if preset == null:
			continue
		
		UIJuice.play(tray, preset)


func get_tray_state_preset(tray:PlayerTokenTrayUI) -> UIJuicePreset:
	if tray == null:
		return null
	
	if game_manager == null:
		return null
	
	if tray.player_id == game_manager.current_player_id:
		return active_tray_preset
	
	return inactive_tray_preset


func _on_current_player_changed(_player_id:int) -> void:
	update_current_player_tray_visuals()


func _on_players_changed() -> void:
	rebuild_trays()


func _on_player_names_changed() -> void:
	refresh_trays()
