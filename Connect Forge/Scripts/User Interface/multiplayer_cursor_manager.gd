class_name MultiplayerCursorManager
extends Control

const CURSOR_SEND_INTERVAL:float = 0.05
const CURSOR_MINIMUM_MOVEMENT:float = 0.001
const CURSOR_INACTIVITY_SECONDS:float = 2.5

@export_group("Cursor")
@export var cursor_scene:PackedScene = preload("res://Scenes/User Interface/multiplyer_cursor_visual.tscn")
@export_range(0.25, 1.5, 0.05) var remote_cursor_scale:float = 0.70

var local_player_id:int = -1
var remote_cursors:Dictionary = {}

var cursor_send_timer:float = 0.0
var last_sent_position:Vector2 = Vector2(-1.0, -1.0)
var has_sent_position:bool = false

var remote_cursor_inactivity:Dictionary = {}
var remote_cursor_is_idle:Dictionary = {}

var local_mouse_inside_window:bool = true
var is_setup:bool = false

var cursor_texture_generator:CursorTextureGenerator = CursorTextureGenerator.new()
var local_cursor_texture:Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	connect_window_signals()
	setup()


func _process(delta:float) -> void:
	if is_setup == false:
		return
	
	update_local_cursor_networking(delta)
	update_remote_cursor_inactivity(delta)


func _exit_tree() -> void:
	disconnect_network_signals()
	disconnect_lobby_signals()
	disconnect_window_signals()
	clear_remote_cursors()
	restore_default_hardware_cursor()


func setup() -> void:
	disconnect_network_signals()
	disconnect_lobby_signals()
	clear_remote_cursors()
	restore_default_hardware_cursor()
	
	local_player_id = -1
	cursor_send_timer = 0.0
	last_sent_position = Vector2(-1.0, -1.0)
	has_sent_position = false
	local_mouse_inside_window = true
	is_setup = true
	
	connect_network_signals()
	connect_lobby_signals()
	refresh_players()


func refresh_players() -> void:
	if is_setup == false:
		return
	
	if MultiplayerCursorNetwork.is_active() == false:
		local_player_id = -1
		clear_remote_cursors()
		restore_default_hardware_cursor()
		return
	
	var previous_local_player_id:int = local_player_id
	local_player_id = MultiplayerCursorNetwork.get_local_player_id()
	
	if previous_local_player_id != local_player_id:
		has_sent_position = false
		cursor_send_timer = CURSOR_SEND_INTERVAL
	
	var players:Array[LobbyMemberData] = LobbyData.get_players()
	var required_remote_player_ids:Dictionary = {}
	
	for member in players:
		if is_valid_player_member(member) == false:
			continue
		
		var player_id:int = member.player_slot
		
		if player_id == local_player_id:
			continue
		
		required_remote_player_ids[player_id] = true
		refresh_or_create_remote_cursor(member)
	
	var existing_player_ids:Array = remote_cursors.keys()
	
	for player_id_value in existing_player_ids:
		var player_id:int = int(player_id_value)
		
		if required_remote_player_ids.has(player_id):
			continue
		
		remove_remote_cursor(player_id)
	
	if local_player_id >= 0:
		apply_local_hardware_cursor()
	else:
		restore_default_hardware_cursor()


func refresh_or_create_remote_cursor(member:LobbyMemberData) -> void:
	if is_valid_player_member(member) == false:
		return
	
	var player_id:int = member.player_slot
	var existing_cursor:MultiplayerCursorVisual = get_remote_cursor(player_id)
	
	if existing_cursor == null:
		create_remote_cursor(member)
		return
	
	var player_name:String = get_member_display_name(member)
	var player_palette:ColorPalette = get_member_palette(member)
	
	existing_cursor.setup(player_id, player_name, player_palette)
	existing_cursor.set_visual_scale(remote_cursor_scale)


func create_remote_cursor(member:LobbyMemberData) -> void:
	if is_valid_player_member(member) == false:
		return
	
	if cursor_scene == null:
		push_error("MultiplayerCursorManager: Cursor scene is missing.")
		return
	
	var player_id:int = member.player_slot
	
	if player_id == local_player_id:
		return
	
	if remote_cursors.has(player_id):
		return
	
	var cursor_instance:MultiplayerCursorVisual = cursor_scene.instantiate() as MultiplayerCursorVisual
	
	if cursor_instance == null:
		push_error("MultiplayerCursorManager: Could not instantiate MultiplayerCursorVisual.")
		return
	
	cursor_instance.name = "Player " + str(player_id + 1) + " Cursor"
	cursor_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(cursor_instance)
	
	var player_name:String = get_member_display_name(member)
	var player_palette:ColorPalette = get_member_palette(member)
	
	cursor_instance.setup(player_id, player_name, player_palette)
	cursor_instance.set_visual_scale(remote_cursor_scale)
	cursor_instance.set_cursor_visible(false)
	
	remote_cursors[player_id] = cursor_instance
	remote_cursor_inactivity[player_id] = 0.0
	remote_cursor_is_idle[player_id] = false


func remove_remote_cursor(player_id:int) -> void:
	var cursor:MultiplayerCursorVisual = get_remote_cursor(player_id)
	
	if cursor != null:
		if is_instance_valid(cursor):
			cursor.queue_free()
	
	remote_cursors.erase(player_id)
	remote_cursor_inactivity.erase(player_id)
	remote_cursor_is_idle.erase(player_id)


func get_member_display_name(member:LobbyMemberData) -> String:
	if member == null:
		return "Player"
	
	var player_name:String = member.display_name.strip_edges()
	
	if player_name == "":
		return "Player " + str(member.player_slot + 1)
	
	return player_name


func get_member_palette(member:LobbyMemberData) -> ColorPalette:
	if member == null:
		return null
	
	var palette:ColorPalette = member.get_colour_palette()
	
	if palette != null:
		return palette
	
	if member.has_player_slot() == false:
		return null
	
	return MatchData.get_default_palette_for_player(member.player_slot)


func is_valid_player_member(member:LobbyMemberData) -> bool:
	if member == null:
		return false
	
	if member.is_player() == false:
		return false
	
	if member.has_player_slot() == false:
		return false
	
	return true


func connect_network_signals() -> void:
	if MultiplayerCursorNetwork.remote_cursor_position_received.is_connected(_on_remote_cursor_position_received) == false:
		MultiplayerCursorNetwork.remote_cursor_position_received.connect(_on_remote_cursor_position_received)
	
	if MultiplayerCursorNetwork.remote_cursor_presence_received.is_connected(_on_remote_cursor_presence_received) == false:
		MultiplayerCursorNetwork.remote_cursor_presence_received.connect(_on_remote_cursor_presence_received)


func disconnect_network_signals() -> void:
	if MultiplayerCursorNetwork.remote_cursor_position_received.is_connected(_on_remote_cursor_position_received):
		MultiplayerCursorNetwork.remote_cursor_position_received.disconnect(_on_remote_cursor_position_received)
	
	if MultiplayerCursorNetwork.remote_cursor_presence_received.is_connected(_on_remote_cursor_presence_received):
		MultiplayerCursorNetwork.remote_cursor_presence_received.disconnect(_on_remote_cursor_presence_received)


func connect_lobby_signals() -> void:
	if LobbyData.members_changed.is_connected(_on_lobby_members_changed) == false:
		LobbyData.members_changed.connect(_on_lobby_members_changed)
	
	if LobbyData.local_member_changed.is_connected(_on_local_member_changed) == false:
		LobbyData.local_member_changed.connect(_on_local_member_changed)
	
	if LobbyData.lobby_cleared.is_connected(_on_lobby_cleared) == false:
		LobbyData.lobby_cleared.connect(_on_lobby_cleared)


func disconnect_lobby_signals() -> void:
	if LobbyData.members_changed.is_connected(_on_lobby_members_changed):
		LobbyData.members_changed.disconnect(_on_lobby_members_changed)
	
	if LobbyData.local_member_changed.is_connected(_on_local_member_changed):
		LobbyData.local_member_changed.disconnect(_on_local_member_changed)
	
	if LobbyData.lobby_cleared.is_connected(_on_lobby_cleared):
		LobbyData.lobby_cleared.disconnect(_on_lobby_cleared)


func connect_window_signals() -> void:
	var window:Window = get_window()
	
	if window == null:
		return
	
	if window.mouse_entered.is_connected(_on_window_mouse_entered) == false:
		window.mouse_entered.connect(_on_window_mouse_entered)
	
	if window.mouse_exited.is_connected(_on_window_mouse_exited) == false:
		window.mouse_exited.connect(_on_window_mouse_exited)


func disconnect_window_signals() -> void:
	var window:Window = get_window()
	
	if window == null:
		return
	
	if window.mouse_entered.is_connected(_on_window_mouse_entered):
		window.mouse_entered.disconnect(_on_window_mouse_entered)
	
	if window.mouse_exited.is_connected(_on_window_mouse_exited):
		window.mouse_exited.disconnect(_on_window_mouse_exited)


func update_local_cursor_networking(delta:float) -> void:
	if MultiplayerCursorNetwork.is_active() == false:
		return
	
	if local_player_id < 0:
		return
	
	if local_mouse_inside_window == false:
		return
	
	cursor_send_timer += delta
	
	if cursor_send_timer < CURSOR_SEND_INTERVAL:
		return
	
	cursor_send_timer = 0.0
	
	var normalised_position:Vector2 = get_normalised_local_mouse_position()
	
	if should_send_cursor_position(normalised_position) == false:
		return
	
	last_sent_position = normalised_position
	has_sent_position = true
	
	MultiplayerCursorNetwork.send_local_cursor_position(normalised_position)


func get_normalised_local_mouse_position() -> Vector2:
	var viewport_size:Vector2 = get_viewport_rect().size
	
	if viewport_size.x <= 0.0:
		return Vector2.ZERO
	
	if viewport_size.y <= 0.0:
		return Vector2.ZERO
	
	var mouse_position:Vector2 = get_viewport().get_mouse_position()
	
	return Vector2(clamp(mouse_position.x / viewport_size.x, 0.0, 1.0), clamp(mouse_position.y / viewport_size.y, 0.0, 1.0))


func should_send_cursor_position(normalised_position:Vector2) -> bool:
	if has_sent_position == false:
		return true
	
	var distance_moved:float = normalised_position.distance_to(last_sent_position)
	
	if distance_moved >= CURSOR_MINIMUM_MOVEMENT:
		return true
	
	return false


func update_player_cursor(player_id:int, normalised_position:Vector2) -> void:
	var cursor:MultiplayerCursorVisual = get_remote_cursor(player_id)
	
	if cursor == null:
		var member:LobbyMemberData = LobbyData.get_member_at_player_slot(player_id)
		
		if is_valid_player_member(member):
			create_remote_cursor(member)
			cursor = get_remote_cursor(player_id)
	
	if cursor == null:
		return
	
	var used_normalised_position:Vector2 = Vector2(clamp(normalised_position.x, 0.0, 1.0), clamp(normalised_position.y, 0.0, 1.0))
	var viewport_size:Vector2 = get_viewport_rect().size
	var screen_position:Vector2 = Vector2(used_normalised_position.x * viewport_size.x, used_normalised_position.y * viewport_size.y)
	
	cursor.set_target_position(screen_position)


func set_player_cursor_visible(player_id:int, should_be_visible:bool) -> void:
	var cursor:MultiplayerCursorVisual = get_remote_cursor(player_id)
	
	if cursor == null:
		return
	
	cursor.set_cursor_visible(should_be_visible)


func set_remote_cursor_scale(new_scale:float) -> void:
	remote_cursor_scale = clamp(new_scale, 0.25, 1.5)
	
	for cursor_value in remote_cursors.values():
		var cursor:MultiplayerCursorVisual = cursor_value as MultiplayerCursorVisual
		
		if cursor == null:
			continue
		
		cursor.set_visual_scale(remote_cursor_scale)
	
	if local_player_id >= 0:
		apply_local_hardware_cursor()


func get_remote_cursor(player_id:int) -> MultiplayerCursorVisual:
	if remote_cursors.has(player_id) == false:
		return null
	
	var cursor:MultiplayerCursorVisual = remote_cursors[player_id] as MultiplayerCursorVisual
	
	if cursor == null:
		remote_cursors.erase(player_id)
		remote_cursor_inactivity.erase(player_id)
		remote_cursor_is_idle.erase(player_id)
		return null
	
	if is_instance_valid(cursor) == false:
		remote_cursors.erase(player_id)
		remote_cursor_inactivity.erase(player_id)
		remote_cursor_is_idle.erase(player_id)
		return null
	
	return cursor


func clear_remote_cursors() -> void:
	for cursor_value in remote_cursors.values():
		var cursor:MultiplayerCursorVisual = cursor_value as MultiplayerCursorVisual
		
		if cursor == null:
			continue
		
		if is_instance_valid(cursor):
			cursor.queue_free()
	
	remote_cursors.clear()
	remote_cursor_inactivity.clear()
	remote_cursor_is_idle.clear()


func mark_remote_cursor_active(player_id:int) -> void:
	remote_cursor_inactivity[player_id] = 0.0
	
	var was_idle:bool = bool(remote_cursor_is_idle.get(player_id, false))
	remote_cursor_is_idle[player_id] = false
	
	if was_idle == false:
		return
	
	var cursor:MultiplayerCursorVisual = get_remote_cursor(player_id)
	
	if cursor == null:
		return
	
	cursor.set_idle_visual(false)


func update_remote_cursor_inactivity(delta:float) -> void:
	for player_id_value in remote_cursors.keys():
		var player_id:int = int(player_id_value)
		var cursor:MultiplayerCursorVisual = get_remote_cursor(player_id)
		
		if cursor == null:
			continue
		
		if cursor.visible == false:
			continue
		
		var inactivity_time:float = float(remote_cursor_inactivity.get(player_id, 0.0))
		inactivity_time += delta
		remote_cursor_inactivity[player_id] = inactivity_time
		
		if inactivity_time < CURSOR_INACTIVITY_SECONDS:
			continue
		
		var is_idle:bool = bool(remote_cursor_is_idle.get(player_id, false))
		
		if is_idle:
			continue
		
		remote_cursor_is_idle[player_id] = true
		cursor.set_idle_visual(true)


func apply_local_hardware_cursor() -> void:
	if local_player_id < 0:
		restore_default_hardware_cursor()
		return
	
	var local_member:LobbyMemberData = LobbyData.get_member_at_player_slot(local_player_id)
	
	if local_member == null:
		restore_default_hardware_cursor()
		return
	
	var player_palette:ColorPalette = get_member_palette(local_member)
	
	if player_palette == null:
		restore_default_hardware_cursor()
		return
	
	local_cursor_texture = cursor_texture_generator.create_cursor_texture(player_palette, remote_cursor_scale)
	
	if local_cursor_texture == null:
		restore_default_hardware_cursor()
		return
	
	var hotspot:Vector2 = Vector2(1.0, 1.0)
	Input.set_custom_mouse_cursor(local_cursor_texture, Input.CURSOR_ARROW, hotspot)


func restore_default_hardware_cursor() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	local_cursor_texture = null


func _on_remote_cursor_position_received(player_id:int, normalised_position:Vector2) -> void:
	if player_id == local_player_id:
		return
	
	mark_remote_cursor_active(player_id)
	update_player_cursor(player_id, normalised_position)


func _on_remote_cursor_presence_received(player_id:int, is_present:bool) -> void:
	if player_id == local_player_id:
		return
	
	if is_present:
		remote_cursor_inactivity[player_id] = 0.0
		remote_cursor_is_idle[player_id] = false
		return
	
	var cursor:MultiplayerCursorVisual = get_remote_cursor(player_id)
	
	if cursor == null:
		return
	
	remote_cursor_inactivity[player_id] = 0.0
	remote_cursor_is_idle[player_id] = false
	cursor.set_cursor_visible(false)


func _on_window_mouse_exited() -> void:
	if local_mouse_inside_window == false:
		return
	
	local_mouse_inside_window = false
	
	if is_setup == false:
		return
	
	if MultiplayerCursorNetwork.is_active() == false:
		return
	
	if local_player_id < 0:
		return
	
	MultiplayerCursorNetwork.send_local_cursor_presence(false)


func _on_window_mouse_entered() -> void:
	if local_mouse_inside_window:
		return
	
	local_mouse_inside_window = true
	
	if is_setup == false:
		return
	
	if MultiplayerCursorNetwork.is_active() == false:
		return
	
	if local_player_id < 0:
		return
	
	has_sent_position = false
	cursor_send_timer = CURSOR_SEND_INTERVAL
	
	MultiplayerCursorNetwork.send_local_cursor_presence(true)


func _on_lobby_members_changed() -> void:
	refresh_players()


func _on_local_member_changed(_member:LobbyMemberData) -> void:
	refresh_players()


func _on_lobby_cleared() -> void:
	local_player_id = -1
	has_sent_position = false
	clear_remote_cursors()
	restore_default_hardware_cursor()
