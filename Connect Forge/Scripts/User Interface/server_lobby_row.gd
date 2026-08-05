class_name ServerLobbyRow
extends PanelContainer

signal selected(row:ServerLobbyRow, lobby_data:Dictionary)

const PUBLIC_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/green_v3.tres")
const PASSWORD_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/red_v3.tres")

const PUBLIC_ICON:Texture2D = preload("res://Assets/User Interface/icons/globe.png")
const PASSWORD_ICON:Texture2D = preload("res://Assets/User Interface/icons/Locked.png")

const NORMAL_MODULATE:Color = Color(1.0, 1.0, 1.0, 1.0)
const HOVER_MODULATE:Color = Color(0.94, 0.97, 1.0, 1.0)
const SELECTED_MODULATE:Color = Color(0.82, 0.91, 1.0, 1.0)

@onready var access_type_token:TokenVisualDisplay = find_child("Access Type Token", true, false) as TokenVisualDisplay

@onready var lobby_name_label:Label = find_child("Lobby Name Label", true, false) as Label
@onready var board_size_label:Label = find_child("Board Size Label", true, false) as Label
@onready var starting_points_label:Label = find_child("Starting Points Label", true, false) as Label
@onready var tokens_to_win_label:Label = find_child("Tokens to win Label", true, false) as Label
@onready var timer_label:Label = find_child("Timer Label", true, false) as Label
@onready var players_label:Label = find_child("Players Label", true, false) as Label
@onready var host_name_label:Label = find_child("Host Name Label", true, false) as Label

var lobby_data:Dictionary = {}

var is_selected:bool = false
var is_hovered:bool = false

var input_overlay:Button = null


func _ready() -> void:
	_create_input_overlay()
	_update_visual_state()


func setup(new_lobby_data:Dictionary) -> void:
	lobby_data = new_lobby_data.duplicate(true)
	
	var lobby_name:String = str(lobby_data.get(SteamNetwork.RESULT_LOBBY_NAME, "Unnamed Lobby"))
	var host_name:String = str(lobby_data.get(SteamNetwork.RESULT_HOST_NAME, "Unknown Host"))
	var access_type:String = str(lobby_data.get(SteamNetwork.RESULT_ACCESS_TYPE, "public"))
	var lobby_phase:String = str(lobby_data.get(SteamNetwork.RESULT_LOBBY_PHASE, "token_selection"))
	
	var board_columns:int = int(lobby_data.get(SteamNetwork.RESULT_BOARD_COLUMNS, 7))
	var board_rows:int = int(lobby_data.get(SteamNetwork.RESULT_BOARD_ROWS, 6))
	var starting_token_points:int = int(lobby_data.get(SteamNetwork.RESULT_STARTING_TOKEN_POINTS, 10))
	var tokens_to_win:int = int(lobby_data.get(SteamNetwork.RESULT_TOKENS_TO_WIN, 4))
	var turn_timer_seconds:int = int(lobby_data.get(SteamNetwork.RESULT_TURN_TIMER_SECONDS, 0))
	
	var active_player_count:int = int(lobby_data.get(SteamNetwork.RESULT_ACTIVE_PLAYER_COUNT, 0))
	var maximum_players:int = int(lobby_data.get(SteamNetwork.RESULT_MAXIMUM_PLAYERS, MatchConfig.MAXIMUM_PLAYERS))
	var spectator_count:int = int(lobby_data.get(SteamNetwork.RESULT_SPECTATOR_COUNT, 0))
	var lobby_is_full:bool = bool(lobby_data.get(SteamNetwork.RESULT_IS_FULL, false))
	
	if lobby_name_label != null:
		lobby_name_label.text = lobby_name
	
	if board_size_label != null:
		board_size_label.text = "%dx%d Board" % [board_columns, board_rows]
	
	if starting_points_label != null:
		starting_points_label.text = _format_points(starting_token_points)
	
	if tokens_to_win_label != null:
		tokens_to_win_label.text = "%d in a Row" % tokens_to_win
	
	if timer_label != null:
		timer_label.text = _format_turn_timer(turn_timer_seconds)
	
	if players_label != null:
		players_label.text = _format_player_count(active_player_count, maximum_players, spectator_count, lobby_is_full)
	
	if host_name_label != null:
		host_name_label.text = _format_host_and_phase(host_name, lobby_phase)
	
	_update_access_visual(access_type)
	
	if input_overlay != null:
		input_overlay.tooltip_text = lobby_name


func get_lobby_data() -> Dictionary:
	return lobby_data.duplicate(true)


func get_lobby_id() -> int:
	return int(lobby_data.get(SteamNetwork.RESULT_LOBBY_ID, SteamNetwork.INVALID_LOBBY_ID))


func set_selected(new_is_selected:bool) -> void:
	if is_selected == new_is_selected:
		return
	
	is_selected = new_is_selected
	_update_visual_state()


func _create_input_overlay() -> void:
	input_overlay = Button.new()
	input_overlay.name = "Input Overlay"
	input_overlay.flat = true
	input_overlay.focus_mode = Control.FOCUS_NONE
	input_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	input_overlay.z_index = 10
	
	add_child(input_overlay)
	input_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	input_overlay.pressed.connect(_on_input_overlay_pressed)
	input_overlay.mouse_entered.connect(_on_input_overlay_mouse_entered)
	input_overlay.mouse_exited.connect(_on_input_overlay_mouse_exited)


func _update_access_visual(access_type:String) -> void:
	if access_type_token == null:
		return
	
	access_type_token.overridden_by_inspector = true
	access_type_token.override_icon_white = true
	
	if access_type == "password_protected":
		access_type_token.token_palette = PASSWORD_PALETTE
		access_type_token.override_icon = PASSWORD_ICON
	else:
		access_type_token.token_palette = PUBLIC_PALETTE
		access_type_token.override_icon = PUBLIC_ICON
	
	access_type_token.apply_inspector_override()


func _format_points(starting_token_points:int) -> String:
	if starting_token_points == 1:
		return "1 Point"
	
	return "%d Points" % starting_token_points


func _format_turn_timer(turn_timer_seconds:int) -> String:
	if turn_timer_seconds <= 0:
		return "No Timer"
	
	return "%ds Timer" % turn_timer_seconds


func _format_player_count(active_players:int, maximum_players:int, spectators:int, lobby_is_full:bool) -> String:
	var result:String = "%d / %d" % [active_players, maximum_players]
	
	if spectators > 0:
		result += "  •  %d watching" % spectators
	
	if lobby_is_full:
		result += "  •  Full"
	
	return result


func _format_host_and_phase(host_name:String, lobby_phase:String) -> String:
	var result:String = "Hosted by " + host_name
	
	if lobby_phase == "match_in_progress":
		result += "  •  Match in progress"
	elif lobby_phase == "returning_to_lobby":
		result += "  •  Returning to lobby"
	
	return result


func _on_input_overlay_pressed() -> void:
	selected.emit(self, get_lobby_data())


func _on_input_overlay_mouse_entered() -> void:
	is_hovered = true
	_update_visual_state()


func _on_input_overlay_mouse_exited() -> void:
	is_hovered = false
	_update_visual_state()


func _update_visual_state() -> void:
	if is_selected:
		self_modulate = SELECTED_MODULATE
		return
	
	if is_hovered:
		self_modulate = HOVER_MODULATE
		return
	
	self_modulate = NORMAL_MODULATE
