extends Node

const LOBBY_ROW_SCENE:PackedScene = preload("res://Scenes/User Interface/server_lobby_row.tscn")
const ROW_SEPARATOR_SCENE:PackedScene = preload("res://Scenes/User Interface/player_score_row_separator.tscn")
const ENTER_PASSWORD_POPUP_SCENE:PackedScene = preload("res://Scenes/User Interface/enter_password_popup.tscn")

const TOKEN_LOBBY_SCENE_PATH:String = "res://Scenes/User Interface/Token Lobby/token_lobby.tscn"
const MAIN_MENU_SCENE_PATH:String = "res://Scenes/User Interface/main_menu.tscn"

const PUBLIC_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/green_v3.tres")
const PASSWORD_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/red_v3.tres")

const PUBLIC_ICON:Texture2D = preload("res://Assets/User Interface/icons/globe.png")
const PASSWORD_ICON:Texture2D = preload("res://Assets/User Interface/icons/Locked.png")

const NO_SELECTION_TEXT:String = "—"

@onready var main_menu_button:Button = find_child("Main Menu Button", true, false) as Button
@onready var refresh_list_button:Button = find_child("Refresh List Button", true, false) as Button
@onready var join_selected_lobby_button:Button = find_child("Join Selected Lobby Button", true, false) as Button

@onready var lobby_listings_vbox:VBoxContainer = find_child("Lobby Listings Vbox", true, false) as VBoxContainer
@onready var lobby_count_label:Label = find_child("Lobby Count Label", true, false) as Label

@onready var lobby_access_token:TokenVisualDisplay = find_child("Lobby Access Token", true, false) as TokenVisualDisplay
@onready var lobby_name_detail_label:Label = find_child("Lobby Name Label", true, false) as Label
@onready var lobby_type_detail_label:Label = find_child("Lobby Type Label", true, false) as Label
@onready var player_count_detail_label:Label = find_child("Player Count Detail Label", true, false) as Label
@onready var lobby_description_label:Label = find_child("Lobby Description Label", true, false) as Label
@onready var board_size_detail_label:Label = find_child("Board Size Detail Label", true, false) as Label
@onready var starting_points_detail_label:Label = find_child("Starting Points Detail Label", true, false) as Label
@onready var tokens_to_win_detail_label:Label = find_child("Tokens in a row to win Detail Label", true, false) as Label
@onready var turn_timer_detail_label:Label = find_child("Turn Timer Detail Label", true, false) as Label
@onready var host_detail_label:Label = find_child("Host Detail Label", true, false) as Label

var join_button_label:Label = null

var selected_row:ServerLobbyRow = null
var selected_lobby:Dictionary = {}

var active_password_popup:EnterPasswordPopup = null
var join_is_in_progress:bool = false
var scene_change_requested:bool = false


func _ready() -> void:
	_find_join_button_label()
	_validate_required_nodes()
	_connect_steam_network_signals()
	_connect_lobby_admission_signals()
	_prepare_main_menu_button()
	_connect_buttons()
	
	_clear_lobby_list()
	_update_lobby_count(0)
	_reset_lobby_details()
	
	if SteamNetwork.is_steam_initialised():
		call_deferred("request_lobby_refresh")


func _find_join_button_label() -> void:
	if join_selected_lobby_button == null:
		return
	
	join_button_label = join_selected_lobby_button.find_child("Label", true, false) as Label


func _prepare_main_menu_button() -> void:
	if main_menu_button == null:
		return
	
	main_menu_button.disabled = false
	main_menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	for child in main_menu_button.find_children("*", "Control", true, false):
		var child_control:Control = child as Control
		
		if child_control == null:
			continue
		
		child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _validate_required_nodes() -> void:
	_log_missing_node(refresh_list_button, "Refresh List Button")
	_log_missing_node(join_selected_lobby_button, "Join Selected Lobby Button")
	_log_missing_node(lobby_listings_vbox, "Lobby Listings Vbox")
	_log_missing_node(lobby_count_label, "Lobby Count Label")
	_log_missing_node(lobby_access_token, "Lobby Access Token")
	_log_missing_node(lobby_name_detail_label, "Lobby Name Label")
	_log_missing_node(lobby_type_detail_label, "Lobby Type Label")
	_log_missing_node(player_count_detail_label, "Player Count Detail Label")
	_log_missing_node(lobby_description_label, "Lobby Description Label")
	_log_missing_node(board_size_detail_label, "Board Size Detail Label")
	_log_missing_node(starting_points_detail_label, "Starting Points Detail Label")
	_log_missing_node(tokens_to_win_detail_label, "Tokens in a row to win Detail Label")
	_log_missing_node(turn_timer_detail_label, "Turn Timer Detail Label")
	_log_missing_node(host_detail_label, "Host Detail Label")
	_log_missing_node(main_menu_button, "Main Menu Button")


func _log_missing_node(node:Node, node_name:String) -> void:
	if node != null:
		return
	
	DebugOverlay.log_error("ServerList", "Could not find %s." % node_name)


func _connect_steam_network_signals() -> void:
	if SteamNetwork.steam_initialised.is_connected(_on_steam_initialised) == false:
		SteamNetwork.steam_initialised.connect(_on_steam_initialised)
	
	if SteamNetwork.steam_initialisation_failed.is_connected(_on_steam_initialisation_failed) == false:
		SteamNetwork.steam_initialisation_failed.connect(_on_steam_initialisation_failed)
	
	if SteamNetwork.lobby_search_started.is_connected(_on_lobby_search_started) == false:
		SteamNetwork.lobby_search_started.connect(_on_lobby_search_started)
	
	if SteamNetwork.lobby_search_completed.is_connected(_on_lobby_search_completed) == false:
		SteamNetwork.lobby_search_completed.connect(_on_lobby_search_completed)
	
	if SteamNetwork.lobby_search_failed.is_connected(_on_lobby_search_failed) == false:
		SteamNetwork.lobby_search_failed.connect(_on_lobby_search_failed)


func _connect_lobby_admission_signals() -> void:
	if LobbyAdmission.admission_started.is_connected(_on_admission_started) == false:
		LobbyAdmission.admission_started.connect(_on_admission_started)
	
	if LobbyAdmission.admission_succeeded.is_connected(_on_admission_succeeded) == false:
		LobbyAdmission.admission_succeeded.connect(_on_admission_succeeded)
	
	if LobbyAdmission.admission_failed.is_connected(_on_admission_failed) == false:
		LobbyAdmission.admission_failed.connect(_on_admission_failed)


func _connect_buttons() -> void:
	if main_menu_button != null:
		if main_menu_button.pressed.is_connected(_on_main_menu_button_pressed) == false:
			main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	
	if refresh_list_button != null:
		if refresh_list_button.pressed.is_connected(request_lobby_refresh) == false:
			refresh_list_button.pressed.connect(request_lobby_refresh)
	
	if join_selected_lobby_button != null:
		if join_selected_lobby_button.pressed.is_connected(_on_join_selected_lobby_pressed) == false:
			join_selected_lobby_button.pressed.connect(_on_join_selected_lobby_pressed)


func request_lobby_refresh() -> void:
	if join_is_in_progress:
		return
	
	SteamNetwork.search_public_lobbies()


func get_selected_lobby() -> Dictionary:
	return selected_lobby.duplicate(true)


func has_selected_lobby() -> bool:
	return selected_lobby.is_empty() == false


func clear_selected_lobby() -> void:
	if selected_row != null:
		if is_instance_valid(selected_row):
			selected_row.set_selected(false)
	
	selected_row = null
	selected_lobby.clear()
	_reset_lobby_details()


func _on_steam_initialised(_steam_id:int, _persona_name:String) -> void:
	request_lobby_refresh()


func _on_steam_initialisation_failed(message:String) -> void:
	set_refresh_button_disabled(true)
	clear_selected_lobby()
	_clear_lobby_list()
	_show_status_message("Steam could not be initialised.")
	_set_lobby_count_text("Steam unavailable")
	
	DebugOverlay.log_error("ServerList", "Steam initialisation failed: " + message)


func _on_lobby_search_started() -> void:
	set_refresh_button_disabled(true)
	clear_selected_lobby()
	_clear_lobby_list()
	_show_status_message("Searching for compatible lobbies...")
	_set_lobby_count_text("Searching...")
	
	DebugOverlay.log_message("ServerList", "Searching for lobbies.")


func _on_lobby_search_completed(lobbies:Array) -> void:
	set_refresh_button_disabled(false)
	clear_selected_lobby()
	_clear_lobby_list()
	
	var valid_lobbies:Array[Dictionary] = []
	
	for lobby_value in lobbies:
		if lobby_value is Dictionary == false:
			continue
		
		var lobby:Dictionary = lobby_value
		
		if lobby.is_empty():
			continue
		
		valid_lobbies.append(lobby)
	
	_update_lobby_count(valid_lobbies.size())
	
	if valid_lobbies.is_empty():
		_show_status_message("No compatible lobbies found.")
		DebugOverlay.log_message("ServerList", "Search returned 0 compatible lobbies.")
		return
	
	if lobby_listings_vbox == null:
		DebugOverlay.log_error("ServerList", "Cannot display lobbies because Lobby Listings Vbox is missing.")
		return
	
	for lobby_index in range(valid_lobbies.size()):
		_add_lobby_row(valid_lobbies[lobby_index])
		
		if lobby_index < valid_lobbies.size() - 1:
			_add_lobby_separator()
	
	DebugOverlay.log_message("ServerList", "Displayed %d compatible lobbies." % valid_lobbies.size())


func _add_lobby_row(lobby:Dictionary) -> void:
	var row:ServerLobbyRow = LOBBY_ROW_SCENE.instantiate() as ServerLobbyRow
	
	if row == null:
		DebugOverlay.log_error("ServerList", "Could not instantiate server_lobby_row.tscn.")
		return
	
	lobby_listings_vbox.add_child(row)
	row.setup(lobby)
	
	if row.selected.is_connected(_on_lobby_row_selected) == false:
		row.selected.connect(_on_lobby_row_selected)


func _add_lobby_separator() -> void:
	var separator:Node = ROW_SEPARATOR_SCENE.instantiate()
	
	if separator == null:
		return
	
	lobby_listings_vbox.add_child(separator)


func _on_lobby_search_failed(message:String) -> void:
	set_refresh_button_disabled(false)
	clear_selected_lobby()
	_clear_lobby_list()
	_show_status_message("The lobby search failed.")
	_set_lobby_count_text("Search failed")
	
	DebugOverlay.log_warning("ServerList", message)


func _on_lobby_row_selected(row:ServerLobbyRow, lobby_data:Dictionary) -> void:
	if join_is_in_progress:
		return
	
	if row == null:
		return
	
	if lobby_data.is_empty():
		return
	
	if selected_row != null:
		if is_instance_valid(selected_row):
			selected_row.set_selected(false)
	
	selected_row = row
	selected_row.set_selected(true)
	selected_lobby = lobby_data.duplicate(true)
	
	_update_lobby_details(selected_lobby)
	
	var lobby_name:String = str(selected_lobby.get(SteamNetwork.RESULT_LOBBY_NAME, "Unnamed Lobby"))
	var lobby_id:int = int(selected_lobby.get(SteamNetwork.RESULT_LOBBY_ID, SteamNetwork.INVALID_LOBBY_ID))
	
	DebugOverlay.log_message("ServerList", "Selected lobby: %s — %d" % [lobby_name, lobby_id])


func _update_lobby_details(lobby_data:Dictionary) -> void:
	var lobby_name:String = str(lobby_data.get(SteamNetwork.RESULT_LOBBY_NAME, "Unnamed Lobby")).strip_edges()
	var description:String = str(lobby_data.get(SteamNetwork.RESULT_DESCRIPTION, "")).strip_edges()
	var access_type:String = str(lobby_data.get(SteamNetwork.RESULT_ACCESS_TYPE, "public")).strip_edges().to_lower()
	var lobby_phase:String = str(lobby_data.get(SteamNetwork.RESULT_LOBBY_PHASE, "none")).strip_edges().to_lower()
	var host_name:String = str(lobby_data.get(SteamNetwork.RESULT_HOST_NAME, "Unknown Host")).strip_edges()
	
	var active_player_count:int = max(int(lobby_data.get(SteamNetwork.RESULT_ACTIVE_PLAYER_COUNT, 0)), 0)
	var maximum_players:int = max(int(lobby_data.get(SteamNetwork.RESULT_MAXIMUM_PLAYERS, MatchConfig.MAXIMUM_PLAYERS)), 1)
	var spectator_count:int = max(int(lobby_data.get(SteamNetwork.RESULT_SPECTATOR_COUNT, 0)), 0)
	
	var board_columns:int = max(int(lobby_data.get(SteamNetwork.RESULT_BOARD_COLUMNS, 7)), 1)
	var board_rows:int = max(int(lobby_data.get(SteamNetwork.RESULT_BOARD_ROWS, 6)), 1)
	var starting_token_points:int = max(int(lobby_data.get(SteamNetwork.RESULT_STARTING_TOKEN_POINTS, 10)), 0)
	var tokens_to_win:int = max(int(lobby_data.get(SteamNetwork.RESULT_TOKENS_TO_WIN, 4)), 1)
	var turn_timer_seconds:int = max(int(lobby_data.get(SteamNetwork.RESULT_TURN_TIMER_SECONDS, 0)), 0)
	var lobby_is_full:bool = bool(lobby_data.get(SteamNetwork.RESULT_IS_FULL, false))
	
	if lobby_name == "":
		lobby_name = "Unnamed Lobby"
	
	if description == "":
		description = "No lobby description was provided."
	
	if host_name == "":
		host_name = "Unknown Host"
	
	_set_label_text(lobby_name_detail_label, lobby_name)
	_set_label_text(lobby_type_detail_label, _format_lobby_type_and_phase(access_type, lobby_phase))
	_set_label_text(player_count_detail_label, _format_player_count(active_player_count, maximum_players, spectator_count, lobby_is_full))
	_set_label_text(lobby_description_label, description)
	_set_label_text(board_size_detail_label, "%dx%d" % [board_columns, board_rows])
	_set_label_text(starting_points_detail_label, str(starting_token_points))
	_set_label_text(tokens_to_win_detail_label, str(tokens_to_win))
	_set_label_text(turn_timer_detail_label, _format_turn_timer(turn_timer_seconds))
	_set_label_text(host_detail_label, host_name)
	
	_update_lobby_access_token(access_type)
	_update_join_button_state(lobby_data)


func _reset_lobby_details() -> void:
	_set_label_text(lobby_name_detail_label, "Select a Lobby")
	_set_label_text(lobby_type_detail_label, "No lobby selected")
	_set_label_text(player_count_detail_label, NO_SELECTION_TEXT)
	_set_label_text(lobby_description_label, "Select a lobby from the list to view its details.")
	_set_label_text(board_size_detail_label, NO_SELECTION_TEXT)
	_set_label_text(starting_points_detail_label, NO_SELECTION_TEXT)
	_set_label_text(tokens_to_win_detail_label, NO_SELECTION_TEXT)
	_set_label_text(turn_timer_detail_label, NO_SELECTION_TEXT)
	_set_label_text(host_detail_label, NO_SELECTION_TEXT)
	
	_update_lobby_access_token("public")
	_set_join_button_state(true, "Select a Lobby")


func _set_label_text(label:Label, new_text:String) -> void:
	if label == null:
		return
	
	label.text = new_text


func _update_lobby_access_token(access_type:String) -> void:
	if lobby_access_token == null:
		return
	
	lobby_access_token.overridden_by_inspector = true
	lobby_access_token.override_icon_white = true
	
	if access_type == "password_protected":
		lobby_access_token.token_palette = PASSWORD_PALETTE
		lobby_access_token.override_icon = PASSWORD_ICON
	else:
		lobby_access_token.token_palette = PUBLIC_PALETTE
		lobby_access_token.override_icon = PUBLIC_ICON
	
	lobby_access_token.apply_inspector_override()


func _format_lobby_type_and_phase(access_type:String, lobby_phase:String) -> String:
	var access_text:String = "Public"
	
	if access_type == "password_protected":
		access_text = "Password Protected"
	elif access_type == "friends":
		access_text = "Friends"
	
	return access_text + "  •  " + _format_lobby_phase(lobby_phase)


func _format_lobby_phase(lobby_phase:String) -> String:
	match lobby_phase:
		"token_selection":
			return "Open"
		
		"match_in_progress":
			return "Match in Progress"
		
		"returning_to_lobby":
			return "Returning to Lobby"
		
		"closed":
			return "Closed"
	
	return "Unavailable"


func _format_player_count(active_players:int, maximum_players:int, spectators:int, lobby_is_full:bool) -> String:
	var result:String = "%d / %d Players" % [active_players, maximum_players]
	
	if spectators > 0:
		result += "  •  %d Watching" % spectators
	
	if lobby_is_full:
		result += "  •  Full"
	
	return result


func _format_turn_timer(turn_timer_seconds:int) -> String:
	if turn_timer_seconds <= 0:
		return "Off"
	
	if turn_timer_seconds == 1:
		return "1 second"
	
	return "%d seconds" % turn_timer_seconds


func _update_join_button_state(lobby_data:Dictionary) -> void:
	var lobby_id:int = int(lobby_data.get(SteamNetwork.RESULT_LOBBY_ID, SteamNetwork.INVALID_LOBBY_ID))
	var lobby_phase:String = str(lobby_data.get(SteamNetwork.RESULT_LOBBY_PHASE, "none")).strip_edges().to_lower()
	var lobby_is_full:bool = bool(lobby_data.get(SteamNetwork.RESULT_IS_FULL, false))
	var active_player_count:int = max(int(lobby_data.get(SteamNetwork.RESULT_ACTIVE_PLAYER_COUNT, 0)), 0)
	var maximum_players:int = max(int(lobby_data.get(SteamNetwork.RESULT_MAXIMUM_PLAYERS, MatchConfig.MAXIMUM_PLAYERS)), 1)
	
	if lobby_id <= SteamNetwork.INVALID_LOBBY_ID:
		_set_join_button_state(true, "Lobby Unavailable")
		return
	
	if lobby_is_full:
		_set_join_button_state(true, "Lobby Full")
		return
	
	if lobby_phase == "closed":
		_set_join_button_state(true, "Lobby Closed")
		return
	
	if lobby_phase == "returning_to_lobby":
		_set_join_button_state(true, "Returning to Lobby")
		return
	
	if lobby_phase == "match_in_progress":
		_set_join_button_state(true, "Spectating Not Ready")
		return
	
	if active_player_count >= maximum_players:
		_set_join_button_state(true, "Player Slots Full")
		return
	
	_set_join_button_state(false, "Join Lobby")


func _set_join_button_state(is_disabled:bool, button_text:String) -> void:
	if join_selected_lobby_button != null:
		join_selected_lobby_button.disabled = is_disabled
	
	if join_button_label != null:
		join_button_label.text = button_text


func _on_join_selected_lobby_pressed() -> void:
	if join_is_in_progress:
		return
	
	if selected_lobby.is_empty():
		return
	
	var lobby_phase:String = str(selected_lobby.get(SteamNetwork.RESULT_LOBBY_PHASE, "none")).strip_edges().to_lower()
	
	if lobby_phase != "token_selection":
		DebugOverlay.log_warning("ServerList", "Only token-selection lobbies can currently be joined.")
		return
	
	var has_password:bool = bool(selected_lobby.get(SteamNetwork.RESULT_HAS_PASSWORD, false))
	
	if has_password:
		_show_password_popup()
		return
	
	_begin_selected_lobby_join("")


func _show_password_popup() -> void:
	if active_password_popup != null:
		if is_instance_valid(active_password_popup):
			active_password_popup.focus_password_field()
			return
	
	var popup:EnterPasswordPopup = ENTER_PASSWORD_POPUP_SCENE.instantiate() as EnterPasswordPopup
	
	if popup == null:
		DebugOverlay.log_error("ServerList", "Could not instantiate enter_password_popup.tscn.")
		return
	
	active_password_popup = popup
	add_child(active_password_popup)
	
	active_password_popup.password_submitted.connect(_on_password_submitted)
	active_password_popup.cancelled.connect(_on_password_popup_cancelled)
	active_password_popup.closed.connect(_on_password_popup_closed)
	
	var lobby_name:String = str(selected_lobby.get(SteamNetwork.RESULT_LOBBY_NAME, "Lobby"))
	active_password_popup.open_popup(lobby_name)


func _on_password_submitted(password:String) -> void:
	_begin_selected_lobby_join(password)


func _on_password_popup_cancelled() -> void:
	if LobbyAdmission.is_join_pending():
		LobbyAdmission.cancel_pending_join("The lobby join was cancelled.")
		return
	
	join_is_in_progress = false
	_restore_join_controls()


func _on_password_popup_closed() -> void:
	active_password_popup = null


func _begin_selected_lobby_join(password:String) -> void:
	if selected_lobby.is_empty():
		return
	
	var lobby_id:int = int(selected_lobby.get(SteamNetwork.RESULT_LOBBY_ID, SteamNetwork.INVALID_LOBBY_ID))
	
	if lobby_id <= SteamNetwork.INVALID_LOBBY_ID:
		DebugOverlay.log_warning("ServerList", "The selected lobby is unavailable.")
		_reset_password_popup_after_failure()
		return
	
	var lobby_name:String = str(selected_lobby.get(SteamNetwork.RESULT_LOBBY_NAME, "Unnamed Lobby"))
	var requested_role:int = LobbyMemberData.MEMBER_ROLE.PLAYER
	
	DebugOverlay.log_message("ServerList", "Join requested for lobby: %s — %d" % [lobby_name, lobby_id])
	
	var join_started:bool = LobbyAdmission.start_join(lobby_id, password, requested_role)
	
	if join_started:
		return
	
	if LobbyAdmission.is_join_pending():
		return
	
	join_is_in_progress = false
	_restore_join_controls()
	_reset_password_popup_after_failure()


func _on_admission_started(_lobby_id:int) -> void:
	join_is_in_progress = true
	set_refresh_button_disabled(true)
	_set_join_button_state(true, "Joining...")
	
	if active_password_popup != null:
		if is_instance_valid(active_password_popup):
			active_password_popup.set_busy(true)


func _on_admission_succeeded(lobby_id:int, assigned_role:int, player_slot:int) -> void:
	if join_is_in_progress == false:
		return
	
	var selected_lobby_id:int = int(selected_lobby.get(SteamNetwork.RESULT_LOBBY_ID, SteamNetwork.INVALID_LOBBY_ID))
	
	if lobby_id != selected_lobby_id:
		SteamNetwork.leave_lobby("The admitted lobby did not match the selected lobby.")
		_on_admission_failed("The host admitted this client to an unexpected lobby.")
		return
	
	_apply_selected_lobby_match_settings()
	_sync_match_players_from_lobby()
	
	var role_name:String = "Spectator"
	
	if assigned_role == LobbyMemberData.MEMBER_ROLE.PLAYER:
		role_name = "Player"
	
	DebugOverlay.log_message("ServerList", "Admission completed as %s in slot %d." % [role_name, player_slot])
	
	if active_password_popup != null:
		if is_instance_valid(active_password_popup):
			active_password_popup.close_after_success()
	
	_open_token_lobby_scene()


func _on_admission_failed(message:String) -> void:
	join_is_in_progress = false
	scene_change_requested = false
	
	_restore_join_controls()
	DebugOverlay.log_warning("ServerList", message)
	
	if active_password_popup != null:
		if is_instance_valid(active_password_popup):
			active_password_popup.show_invalid_feedback()


func _restore_join_controls() -> void:
	set_refresh_button_disabled(false)
	
	if selected_lobby.is_empty():
		_set_join_button_state(true, "Select a Lobby")
		return
	
	_update_join_button_state(selected_lobby)


func _reset_password_popup_after_failure() -> void:
	if active_password_popup == null:
		return
	
	if is_instance_valid(active_password_popup) == false:
		return
	
	active_password_popup.show_invalid_feedback()


func _apply_selected_lobby_match_settings() -> void:
	if MatchData.config == null:
		MatchData.create_default_config()
	
	if MatchData.config == null:
		return
	
	var board_columns:int = max(int(selected_lobby.get(SteamNetwork.RESULT_BOARD_COLUMNS, 7)), 1)
	var board_rows:int = max(int(selected_lobby.get(SteamNetwork.RESULT_BOARD_ROWS, 6)), 1)
	var starting_token_points:int = max(int(selected_lobby.get(SteamNetwork.RESULT_STARTING_TOKEN_POINTS, 10)), 0)
	var tokens_to_win:int = max(int(selected_lobby.get(SteamNetwork.RESULT_TOKENS_TO_WIN, 4)), 1)
	var turn_timer_seconds:int = max(int(selected_lobby.get(SteamNetwork.RESULT_TURN_TIMER_SECONDS, 0)), 0)
	
	MatchData.config.set_starting_token_points(starting_token_points)
	MatchData.config.set_board_size(board_columns, board_rows)
	MatchData.config.set_tokens_to_win(tokens_to_win)
	MatchData.config.set_turn_timer_seconds(turn_timer_seconds)


func _sync_match_players_from_lobby() -> void:
	if MatchData.config == null:
		return
	
	var player_count:int = max(LobbyData.get_player_count(), MatchConfig.MINIMUM_PLAYERS)
	MatchData.set_player_count(player_count)
	
	for member in LobbyData.get_players():
		if member.player_slot < 0:
			continue
		
		if member.player_slot >= MatchData.config.get_player_count():
			continue
		
		MatchData.config.set_player_name(member.player_slot, member.display_name)
		
		var palette:ColorPalette = member.get_colour_palette()
		
		if palette != null:
			MatchData.config.set_player_palette(member.player_slot, palette)


func _open_token_lobby_scene() -> void:
	if scene_change_requested:
		return
	
	scene_change_requested = true
	
	var change_error:Error = get_tree().change_scene_to_file(TOKEN_LOBBY_SCENE_PATH)
	
	if change_error == OK:
		return
	
	scene_change_requested = false
	join_is_in_progress = false
	
	SteamNetwork.leave_lobby("The token lobby scene could not be opened.")
	_restore_join_controls()
	
	DebugOverlay.log_error("ServerList", "Could not change to token_lobby.tscn. Error code: %d" % change_error)


func _clear_lobby_list() -> void:
	if lobby_listings_vbox == null:
		DebugOverlay.log_error("ServerList", "Could not find Lobby Listings Vbox.")
		return
	
	for child in lobby_listings_vbox.get_children():
		lobby_listings_vbox.remove_child(child)
		child.queue_free()


func _show_status_message(message:String) -> void:
	if lobby_listings_vbox == null:
		return
	
	var status_label:Label = Label.new()
	status_label.name = "Lobby List Status"
	status_label.custom_minimum_size = Vector2(0, 120)
	status_label.text = message
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.modulate = Color(0.48, 0.58, 0.68, 1.0)
	
	lobby_listings_vbox.add_child(status_label)


func _update_lobby_count(lobby_count:int) -> void:
	if lobby_count == 1:
		_set_lobby_count_text("Showing 1 lobby")
		return
	
	_set_lobby_count_text("Showing %d lobbies" % lobby_count)


func _set_lobby_count_text(new_text:String) -> void:
	if lobby_count_label == null:
		DebugOverlay.log_error("ServerList", "Could not find Lobby Count Label.")
		return
	
	lobby_count_label.text = new_text


func set_refresh_button_disabled(is_disabled:bool) -> void:
	if refresh_list_button == null:
		return
	
	refresh_list_button.disabled = is_disabled


func _on_main_menu_button_pressed() -> void:
	if scene_change_requested:
		return
	
	DebugOverlay.log_message("ServerList", "Main Menu button pressed.")
	
	if LobbyAdmission.is_join_pending():
		LobbyAdmission.cancel_pending_join("Returned to the main menu.")
	
	scene_change_requested = true
	
	var change_error:Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	
	if change_error == OK:
		return
	
	scene_change_requested = false
	DebugOverlay.log_error("ServerList", "Could not change to main_menu.tscn. Error code: %d" % change_error)
