class_name PlayerTokenTraysUI
extends VBoxContainer

@export_group("References")
@export var player_tray_scene:PackedScene

@export_group("Tray State Presets")
@export var active_tray_preset:UIJuicePreset
@export var inactive_tray_preset:UIJuicePreset

var game_manager:GameManager = null
var drag_controller:TokenDragController = null
var trays:Array[PlayerTokenTrayUI] = []
var connected_session:MatchSession = null


func _exit_tree() -> void:
	disconnect_game_manager_signals()
	disconnect_session_signals()


func setup(new_game_manager:GameManager, new_drag_controller:TokenDragController) -> void:
	disconnect_game_manager_signals()
	
	game_manager = new_game_manager
	drag_controller = new_drag_controller
	
	connect_game_manager_signals()
	connect_session_signals()


func connect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.current_player_changed.is_connected(_on_current_player_changed) == false:
		game_manager.current_player_changed.connect(_on_current_player_changed)
	
	if game_manager.players_changed.is_connected(_on_players_changed) == false:
		game_manager.players_changed.connect(_on_players_changed)


func disconnect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.current_player_changed.is_connected(_on_current_player_changed):
		game_manager.current_player_changed.disconnect(_on_current_player_changed)
	
	if game_manager.players_changed.is_connected(_on_players_changed):
		game_manager.players_changed.disconnect(_on_players_changed)


func connect_session_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.session == null:
		return
	
	if connected_session == game_manager.session:
		return
	
	disconnect_session_signals()
	connected_session = game_manager.session
	
	if connected_session.active_players_changed.is_connected(_on_active_players_changed) == false:
		connected_session.active_players_changed.connect(_on_active_players_changed)


func disconnect_session_signals() -> void:
	if connected_session == null:
		return
	
	if connected_session.active_players_changed.is_connected(_on_active_players_changed):
		connected_session.active_players_changed.disconnect(_on_active_players_changed)
	
	connected_session = null


func rebuild_trays() -> void:
	clear_trays()
	
	if game_manager == null:
		return
	
	if drag_controller == null:
		return
	
	if player_tray_scene == null:
		return
	
	connect_session_signals()
	
	if game_manager.session == null:
		return
	
	var active_player_ids:Array[int] = game_manager.session.get_active_player_ids()
	
	for player_id in active_player_ids:
		create_player_tray(player_id)
	
	call_deferred("update_current_player_tray_visuals")


func create_player_tray(player_id:int) -> void:
	if player_tray_scene == null:
		return
	
	var tray:PlayerTokenTrayUI = player_tray_scene.instantiate() as PlayerTokenTrayUI
	
	if tray == null:
		return
	
	add_child(tray)
	tray.setup_tray(game_manager, drag_controller, player_id)
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
	
	if tray.player_id == game_manager.get_current_player_id():
		return active_tray_preset
	
	return inactive_tray_preset


func _on_current_player_changed(_player_id:int) -> void:
	update_current_player_tray_visuals()


func _on_players_changed() -> void:
	rebuild_trays()


func _on_active_players_changed() -> void:
	rebuild_trays()
