class_name TokenLobby
extends CanvasLayer

const SERVER_PEER_ID:int = 1

const STATE_REVISION:String = "revision"
const STATE_LOBBY_ID:String = "lobby_id"
const STATE_STARTING_POINTS:String = "starting_points"
const STATE_BOARD_COLUMNS:String = "board_columns"
const STATE_BOARD_ROWS:String = "board_rows"
const STATE_TOKENS_TO_WIN:String = "tokens_to_win"
const STATE_TURN_TIMER_SECONDS:String = "turn_timer_seconds"
const STATE_STARTING_PLAYER_ID:String = "starting_player_id"
const STATE_PLAYERS:String = "players"

const PLAYER_STATE_SLOT:String = "player_slot"
const PLAYER_STATE_POINTS:String = "token_points_remaining"
const PLAYER_STATE_TOKENS:String = "selected_tokens"

@export_group("Scenes")
@export var token_shop_card_scene:PackedScene
@export var lobby_player_tray_scene:PackedScene
@export var purchased_token_item_scene:PackedScene
@export var game_board_scene:PackedScene = preload("res://Scenes/game_board.tscn")

@onready var token_grid:GridContainer = %TokenGrid
@onready var player_tray_row:HBoxContainer = %PlayerTrayRow
@onready var start_button:Button = $"Control/ScreenMargin/ScreenLayout/Footer/Footer/Start Button"

@onready var options_button:TextureButton = $"Control/ScreenMargin/ScreenLayout/Top Panel/Margin/PanelContainer/HBoxContainer/Options Button/PanelContainer/OptionsButton/Button"
@onready var pause_button:TextureButton = $"Control/ScreenMargin/ScreenLayout/Top Panel/Margin/PanelContainer/HBoxContainer/Pause Button/PanelContainer/Pause Button/Button"

@onready var match_options_popup:MatchOptionsPopupUI = $Control/ScreenMargin/MatchOptionsPopupUI
@onready var pause_menu:PauseMenu = $Control/ScreenMargin/PauseMenuPopupUI
@onready var multiplayer_disconnect_popup:MultiplayerDisconnectPopup = $MultiplayerDisconnectPopup

var is_starting_match:bool = false
var multiplayer_lobby_active:bool = false

var known_member_steam_ids_by_slot:Dictionary = {}
var player_trays_by_id:Dictionary = {}

var host_state_revision:int = 0
var last_applied_state_revision:int = -1
var state_request_sent:bool = false


func _ready() -> void:
	MatchData.clear_session()
	multiplayer_lobby_active = is_multiplayer_lobby_active()
	
	connect_buttons()
	setup_pause_menu()
	setup_match_options_popup()
	connect_multiplayer_lobby_signals()
	
	if multiplayer_lobby_active:
		synchronise_match_config_from_lobby()
	else:
		setup_local_bot_smoke_test()
	
	create_shop_cards()
	create_player_trays()
	update_multiplayer_controls()
	
	if multiplayer_lobby_active:
		call_deferred("initialise_multiplayer_token_state")

	
func connect_buttons() -> void:
	if start_button != null:
		if start_button.pressed.is_connected(_on_start_button_pressed) == false:
			start_button.pressed.connect(_on_start_button_pressed)


func setup_match_options_popup() -> void:
	if match_options_popup == null:
		push_error("TokenLobby: MatchOptionsPopupUI could not be found.")
		return
	
	if options_button == null:
		push_error("TokenLobby: Options button could not be found.")
		return
	
	if multiplayer_lobby_active and LobbyData.is_local_host() == false:
		match_options_popup.setup_config_read_only(options_button)
	else:
		match_options_popup.setup(options_button)
	
	if match_options_popup.options_applied.is_connected(_on_match_options_applied) == false:
		match_options_popup.options_applied.connect(_on_match_options_applied)


func setup_pause_menu() -> void:
	if pause_menu == null:
		push_error("TokenLobby: PauseMenuPopupUI could not be found.")
		return
	
	if pause_button == null:
		push_error("TokenLobby: Pause button could not be found.")
		return
	
	pause_menu.set_menu_context(PauseMenu.MenuContext.TOKEN_LOBBY)
	pause_menu.setup(pause_button)


func connect_multiplayer_lobby_signals() -> void:
	if multiplayer_lobby_active == false:
		return
	
	if LobbyData.members_changed.is_connected(_on_lobby_members_changed) == false:
		LobbyData.members_changed.connect(_on_lobby_members_changed)
	
	if LobbyData.lobby_cleared.is_connected(_on_lobby_cleared) == false:
		LobbyData.lobby_cleared.connect(_on_lobby_cleared)
	
	if SteamNetwork.host_disconnected.is_connected(_on_host_disconnected) == false:
		SteamNetwork.host_disconnected.connect(_on_host_disconnected)


func initialise_multiplayer_token_state() -> void:
	if multiplayer_lobby_active == false:
		return
	
	if SteamNetwork.is_host():
		refresh_player_trays()
		return
	
	request_current_token_lobby_state()


func request_current_token_lobby_state() -> void:
	if multiplayer_lobby_active == false:
		return
	
	if SteamNetwork.is_client() == false:
		return
	
	if state_request_sent:
		return
	
	state_request_sent = true
	
	DebugOverlay.log_message("TokenLobby", "Requesting the current token-selection state from the host.")
	rpc_id(SERVER_PEER_ID, "request_token_lobby_state")


func is_multiplayer_lobby_active() -> bool:
	if SteamNetwork.is_in_lobby() == false:
		return false
	
	return LobbyData.has_active_lobby()


func get_player_count() -> int:
	if multiplayer_lobby_active:
		return LobbyData.get_player_count()
	
	if MatchData.config == null:
		return 0
	
	return MatchData.config.get_player_count()


func create_shop_cards() -> void:
	clear_container(token_grid)
	
	if token_shop_card_scene == null:
		return
	
	var token_types:Array[int] = TokenLibrary.get_lobby_token_types()
	
	for token_type in token_types:
		create_shop_card(token_type)


func create_shop_card(token_type:int) -> void:
	if token_grid == null:
		return
	
	var card:TokenShopCard = token_shop_card_scene.instantiate() as TokenShopCard
	
	if card == null:
		return
	
	token_grid.add_child(card)
	card.setup(token_type)


func create_player_trays() -> void:
	clear_container(player_tray_row)
	player_trays_by_id.clear()
	
	if lobby_player_tray_scene == null:
		return
	
	if multiplayer_lobby_active:
		create_multiplayer_player_trays()
		return
	
	var player_count:int = get_player_count()
	
	for player_id in range(player_count):
		create_local_player_tray(player_id)


func create_multiplayer_player_trays() -> void:
	if MatchData.config == null:
		return
	
	var local_steam_id:int = LobbyData.get_local_steam_id()
	var players:Array[LobbyMemberData] = LobbyData.get_players()
	
	for member in players:
		if member == null:
			continue
		
		if member.has_player_slot() == false:
			continue
		
		var player_id:int = member.player_slot
		var player:MatchPlayerData = MatchData.config.get_player(player_id)
		
		if player == null:
			continue
		
		var tray:LobbyPlayerTray = create_player_tray_instance()
		
		if tray == null:
			continue
		
		var is_local_player:bool = member.steam_id == local_steam_id
		
		connect_multiplayer_tray_signals(tray)
		tray.setup_multiplayer(player_id, player, member, is_local_player)
		
		player_trays_by_id[player_id] = tray
	
	DebugOverlay.log_message("TokenLobby", "Displayed %d Steam player trays." % players.size())


func create_local_player_tray(player_id:int) -> void:
	if MatchData.config == null:
		return
	
	var player:MatchPlayerData = MatchData.config.get_player(player_id)
	
	if player == null:
		return
	
	var tray:LobbyPlayerTray = create_player_tray_instance()
	
	if tray == null:
		return
	
	tray.setup(player_id, player)
	player_trays_by_id[player_id] = tray


func create_player_tray_instance() -> LobbyPlayerTray:
	if player_tray_row == null:
		return null
	
	var tray:LobbyPlayerTray = lobby_player_tray_scene.instantiate() as LobbyPlayerTray
	
	if tray == null:
		return null
	
	tray.purchased_token_item_scene = purchased_token_item_scene
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.size_flags_vertical = Control.SIZE_FILL
	
	player_tray_row.add_child(tray)
	return tray


func connect_multiplayer_tray_signals(tray:LobbyPlayerTray) -> void:
	if tray == null:
		return
	
	if tray.multiplayer_purchase_requested.is_connected(_on_multiplayer_purchase_requested) == false:
		tray.multiplayer_purchase_requested.connect(_on_multiplayer_purchase_requested)
	
	if tray.multiplayer_refund_requested.is_connected(_on_multiplayer_refund_requested) == false:
		tray.multiplayer_refund_requested.connect(_on_multiplayer_refund_requested)


func refresh_player_trays() -> void:
	if MatchData.config == null:
		return
	
	for player_id_value in player_trays_by_id.keys():
		var player_id:int = int(player_id_value)
		var tray:LobbyPlayerTray = player_trays_by_id[player_id] as LobbyPlayerTray
		
		if tray == null:
			continue
		
		if is_instance_valid(tray) == false:
			continue
		
		var player:MatchPlayerData = MatchData.config.get_player(player_id)
		var member:LobbyMemberData = null
		
		if multiplayer_lobby_active:
			member = LobbyData.get_member_at_player_slot(player_id)
		
		tray.refresh_from_player_data(player, member)


func synchronise_match_config_from_lobby() -> void:
	if multiplayer_lobby_active == false:
		return
	
	if MatchData.config == null:
		MatchData.create_default_config()
	
	if MatchData.config == null:
		return
	
	var players:Array[LobbyMemberData] = LobbyData.get_players()
	var highest_player_slot:int = -1
	
	for member in players:
		if member == null:
			continue
		
		if member.player_slot > highest_player_slot:
			highest_player_slot = member.player_slot
	
	var required_config_count:int = max(highest_player_slot + 1, MatchConfig.MINIMUM_PLAYERS)
	MatchData.set_player_count(required_config_count)
	
	var current_member_steam_ids_by_slot:Dictionary = {}
	
	for member in players:
		synchronise_lobby_member_to_match_config(member, current_member_steam_ids_by_slot)
	
	reset_empty_match_config_slots(current_member_steam_ids_by_slot)
	known_member_steam_ids_by_slot = current_member_steam_ids_by_slot


func synchronise_lobby_member_to_match_config(member:LobbyMemberData, current_member_steam_ids_by_slot:Dictionary) -> void:
	if member == null:
		return
	
	if member.has_player_slot() == false:
		return
	
	var player_id:int = member.player_slot
	var player:MatchPlayerData = MatchData.config.get_player(player_id)
	
	if player == null:
		return
	
	var previous_steam_id:int = int(known_member_steam_ids_by_slot.get(player_id, LobbyData.INVALID_STEAM_ID))
	
	if previous_steam_id != member.steam_id:
		player.reset_token_selection(MatchData.config.starting_token_points)
	
	MatchData.config.set_player_name(player_id, member.display_name)
	
	var palette:ColorPalette = member.get_colour_palette()
	
	if palette == null:
		palette = MatchData.get_default_palette_for_player(player_id)
	
	if palette != null:
		MatchData.config.set_player_palette(player_id, palette)
	
	current_member_steam_ids_by_slot[player_id] = member.steam_id


func reset_empty_match_config_slots(current_member_steam_ids_by_slot:Dictionary) -> void:
	if MatchData.config == null:
		return
	
	for player_id in range(MatchData.config.get_player_count()):
		if current_member_steam_ids_by_slot.has(player_id):
			continue
		
		var player:MatchPlayerData = MatchData.config.get_player(player_id)
		
		if player == null:
			continue
		
		player.reset_token_selection(MatchData.config.starting_token_points)
		MatchData.config.set_player_name(player_id, "Player " + str(player_id + 1))
		
		var palette:ColorPalette = MatchData.get_default_palette_for_player(player_id)
		
		if palette != null:
			MatchData.config.set_player_palette(player_id, palette)


func create_token_lobby_state() -> Dictionary:
	if MatchData.config == null:
		return {}
	
	var players_state:Array[Dictionary] = []
	
	for member in LobbyData.get_players():
		if member == null:
			continue
		
		if member.has_player_slot() == false:
			continue
		
		var player:MatchPlayerData = MatchData.config.get_player(member.player_slot)
		
		if player == null:
			continue
		
		players_state.append({
			PLAYER_STATE_SLOT: member.player_slot,
			PLAYER_STATE_POINTS: player.token_points_remaining,
			PLAYER_STATE_TOKENS: create_safe_token_dictionary(player.selected_tokens)
		})
	
	return {
		STATE_REVISION: host_state_revision,
		STATE_LOBBY_ID: LobbyData.get_lobby_id(),
		STATE_STARTING_POINTS: MatchData.config.starting_token_points,
		STATE_BOARD_COLUMNS: MatchData.config.board_columns,
		STATE_BOARD_ROWS: MatchData.config.board_rows,
		STATE_TOKENS_TO_WIN: MatchData.config.tokens_to_win,
		STATE_TURN_TIMER_SECONDS: MatchData.config.turn_timer_seconds,
		STATE_STARTING_PLAYER_ID: MatchData.config.starting_player_id,
		STATE_PLAYERS: players_state
	}


func create_safe_token_dictionary(source_tokens:Dictionary) -> Dictionary:
	var result:Dictionary = {}
	
	for token_type_value in source_tokens.keys():
		var token_type:int = int(token_type_value)
		var token_count:int = max(int(source_tokens[token_type_value]), 0)
		
		if TokenLibrary.is_available_in_lobby(token_type) == false:
			continue
		
		if token_count <= 0:
			continue
		
		result[token_type] = token_count
	
	return result


func apply_token_lobby_state(state:Dictionary) -> bool:
	if multiplayer_lobby_active == false:
		return false
	
	if state.is_empty():
		return false
	
	var state_lobby_id:int = int(state.get(STATE_LOBBY_ID, LobbyData.INVALID_LOBBY_ID))
	
	if state_lobby_id != LobbyData.get_lobby_id():
		DebugOverlay.log_warning("TokenLobby", "Ignored token-selection data for an unexpected lobby.")
		return false
	
	var state_revision:int = int(state.get(STATE_REVISION, 0))
	
	if state_revision < last_applied_state_revision:
		return false
	
	var players_state_value:Variant = state.get(STATE_PLAYERS, [])
	
	if players_state_value is Array == false:
		return false
	
	if MatchData.config == null:
		MatchData.create_default_config()
	
	if MatchData.config == null:
		return false
	
	var starting_points:int = int(state.get(STATE_STARTING_POINTS, MatchData.config.starting_token_points))
	var board_columns:int = int(state.get(STATE_BOARD_COLUMNS, MatchData.config.board_columns))
	var board_rows:int = int(state.get(STATE_BOARD_ROWS, MatchData.config.board_rows))
	var tokens_to_win:int = int(state.get(STATE_TOKENS_TO_WIN, MatchData.config.tokens_to_win))
	var turn_timer_seconds:int = int(state.get(STATE_TURN_TIMER_SECONDS, MatchData.config.turn_timer_seconds))
	var starting_player_id:int = int(state.get(STATE_STARTING_PLAYER_ID, MatchData.config.starting_player_id))
	
	MatchData.config.set_board_size(board_columns, board_rows)
	MatchData.config.set_tokens_to_win(tokens_to_win)
	MatchData.config.set_turn_timer_seconds(turn_timer_seconds)
	MatchData.config.set_starting_player_id(starting_player_id)
	MatchData.config.set_starting_token_points(starting_points)
	
	synchronise_match_config_from_lobby()
	
	var players_state:Array = players_state_value
	
	for player_state_value in players_state:
		if player_state_value is Dictionary == false:
			continue
		
		var player_state:Dictionary = player_state_value
		apply_player_selection_state(player_state)
	
	last_applied_state_revision = state_revision
	state_request_sent = false
	
	refresh_player_trays()
	refresh_match_options_display()
	
	DebugOverlay.log_message("TokenLobby", "Applied token-selection state revision %d." % state_revision)
	return true


func apply_player_selection_state(player_state:Dictionary) -> void:
	if MatchData.config == null:
		return
	
	var player_slot:int = int(player_state.get(PLAYER_STATE_SLOT, -1))
	
	if player_slot < 0:
		return
	
	if player_slot >= MatchData.config.get_player_count():
		return
	
	var player:MatchPlayerData = MatchData.config.get_player(player_slot)
	
	if player == null:
		return
	
	var maximum_points:int = max(MatchData.config.starting_token_points, 0)
	var remaining_points:int = clamp(int(player_state.get(PLAYER_STATE_POINTS, maximum_points)), 0, maximum_points)
	var token_data_value:Variant = player_state.get(PLAYER_STATE_TOKENS, {})
	
	if token_data_value is Dictionary == false:
		return
	
	var token_data:Dictionary = token_data_value
	
	player.token_points_remaining = remaining_points
	player.selected_tokens.clear()
	
	for token_type_value in token_data.keys():
		var token_type:int = int(token_type_value)
		var token_count:int = max(int(token_data[token_type_value]), 0)
		
		if TokenLibrary.is_available_in_lobby(token_type) == false:
			continue
		
		if token_count <= 0:
			continue
		
		player.selected_tokens[token_type] = token_count


func refresh_match_options_display() -> void:
	if match_options_popup == null:
		return
	
	match_options_popup.load_values_for_display_mode()


func publish_token_lobby_state(reason:String = "") -> void:
	if multiplayer_lobby_active == false:
		return
	
	if SteamNetwork.is_host() == false:
		return
	
	if multiplayer.is_server() == false:
		return
	
	host_state_revision += 1
	
	var state:Dictionary = create_token_lobby_state()
	
	if state.is_empty():
		return
	
	last_applied_state_revision = host_state_revision
	refresh_player_trays()
	refresh_match_options_display()
	
	rpc("receive_token_lobby_state", state)
	
	if reason.strip_edges() != "":
		DebugOverlay.log_message("TokenLobby", "%s State revision %d was broadcast." % [reason, host_state_revision])


func send_token_lobby_state_to_peer(peer_id:int) -> void:
	if SteamNetwork.is_host() == false:
		return
	
	if peer_id <= SERVER_PEER_ID:
		return
	
	var state:Dictionary = create_token_lobby_state()
	
	if state.is_empty():
		return
	
	rpc_id(peer_id, "receive_token_lobby_state", state)


@rpc("any_peer", "call_remote", "reliable")
func request_token_lobby_state() -> void:
	if SteamNetwork.is_host() == false:
		return
	
	if multiplayer.is_server() == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	var sender_member:LobbyMemberData = LobbyData.get_member_by_peer_id(sender_peer_id)
	
	if sender_member == null:
		DebugOverlay.log_warning("TokenLobby", "An unknown peer requested token-selection data.")
		return
	
	send_token_lobby_state_to_peer(sender_peer_id)
	
	DebugOverlay.log_message("TokenLobby", "Sent token-selection state to %s." % sender_member.display_name)


@rpc("authority", "call_remote", "reliable")
func receive_token_lobby_state(state:Dictionary) -> void:
	apply_token_lobby_state(state)


func _on_multiplayer_purchase_requested(_player_id:int, token_type:int) -> void:
	if multiplayer_lobby_active == false:
		return
	
	if SteamNetwork.is_host():
		var local_member:LobbyMemberData = LobbyData.get_local_member()
		
		if local_member == null:
			return
		
		process_purchase_request(local_member.peer_id, token_type)
		return
	
	rpc_id(SERVER_PEER_ID, "request_token_purchase", token_type)

func request_local_ready_state(new_is_ready:bool) -> void:
	if multiplayer_lobby_active == false:
		return
	
	if is_starting_match:
		return
	
	var local_member:LobbyMemberData = LobbyData.get_local_member()
	
	if local_member == null:
		return
	
	if local_member.is_player() == false:
		return
	
	if start_button != null:
		start_button.disabled = true
		start_button.text = "Updating..."
	
	if SteamNetwork.is_host():
		process_ready_request(local_member.peer_id, new_is_ready)
		return
	
	rpc_id(SERVER_PEER_ID, "request_player_ready", new_is_ready)


@rpc("any_peer", "call_remote", "reliable")
func request_player_ready(new_is_ready:bool) -> void:
	if SteamNetwork.is_host() == false:
		return
	
	if multiplayer.is_server() == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	process_ready_request(sender_peer_id, new_is_ready)


func process_ready_request(peer_id:int, new_is_ready:bool) -> void:
	var member:LobbyMemberData = get_valid_requesting_player(peer_id)
	
	if member == null:
		reject_ready_request(peer_id, "The ready request could not be linked to a lobby player.")
		return
	
	if LobbyData.set_member_ready(member.steam_id, new_is_ready) == false:
		reject_ready_request(peer_id, "The player's ready state could not be changed.")
		return
	
	refresh_player_trays()
	update_multiplayer_controls()
	LobbyAdmission.broadcast_current_snapshot()
	
	if new_is_ready:
		DebugOverlay.log_message("TokenLobby", "%s is ready." % member.display_name)
	else:
		DebugOverlay.log_message("TokenLobby", "%s is no longer ready." % member.display_name)


func reject_ready_request(peer_id:int, message:String) -> void:
	DebugOverlay.log_warning("TokenLobby", message)
	
	if peer_id == SERVER_PEER_ID:
		update_multiplayer_controls()
		return
	
	rpc_id(peer_id, "receive_ready_request_rejected", message)


@rpc("authority", "call_remote", "reliable")
func receive_ready_request_rejected(message:String) -> void:
	DebugOverlay.log_warning("TokenLobby", message)
	update_multiplayer_controls()


func reset_all_players_ready(reason:String = "") -> bool:
	if SteamNetwork.is_host() == false:
		return false
	
	var ready_state_changed:bool = false
	
	for member in LobbyData.get_players():
		if member == null:
			continue
		
		if member.is_ready == false:
			continue
		
		if LobbyData.set_member_ready(member.steam_id, false):
			ready_state_changed = true
	
	if ready_state_changed == false:
		return false
	
	refresh_player_trays()
	update_multiplayer_controls()
	LobbyAdmission.broadcast_current_snapshot()
	
	if reason.strip_edges() != "":
		DebugOverlay.log_message("TokenLobby", "%s Player readiness was reset." % reason)
	
	return true
	
func _on_multiplayer_refund_requested(_player_id:int, token_type:int) -> void:
	if multiplayer_lobby_active == false:
		return
	
	if SteamNetwork.is_host():
		var local_member:LobbyMemberData = LobbyData.get_local_member()
		
		if local_member == null:
			return
		
		process_refund_request(local_member.peer_id, token_type)
		return
	
	rpc_id(SERVER_PEER_ID, "request_token_refund", token_type)


@rpc("any_peer", "call_remote", "reliable")
func request_token_purchase(token_type:int) -> void:
	if SteamNetwork.is_host() == false:
		return
	
	if multiplayer.is_server() == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	process_purchase_request(sender_peer_id, token_type)


@rpc("any_peer", "call_remote", "reliable")
func request_token_refund(token_type:int) -> void:
	if SteamNetwork.is_host() == false:
		return
	
	if multiplayer.is_server() == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	process_refund_request(sender_peer_id, token_type)


func process_purchase_request(peer_id:int, token_type:int) -> void:
	var member:LobbyMemberData = get_valid_requesting_player(peer_id)
	
	if member == null:
		reject_token_request(peer_id, "The token purchase could not be linked to a lobby player.")
		return
	
	if member.is_ready:
		reject_token_request(peer_id, "Cancel ready before changing your token selection.")
		return
	
	if TokenLibrary.is_available_in_lobby(token_type) == false:
		reject_token_request(peer_id, "That token is not available in the lobby shop.")
		return
	
	var player:MatchPlayerData = MatchData.config.get_player(member.player_slot)
	
	if player == null:
		reject_token_request(peer_id, "The player selection data could not be found.")
		return
	
	if player.try_purchase_token(token_type) == false:
		reject_token_request(peer_id, "The token could not be purchased.")
		return
	
	DebugOverlay.log_message("TokenLobby", "%s purchased %s." % [member.display_name, TokenLibrary.get_display_name(token_type)])
	publish_token_lobby_state("Token purchase accepted.")


func process_refund_request(peer_id:int, token_type:int) -> void:
	var member:LobbyMemberData = get_valid_requesting_player(peer_id)
	
	if member == null:
		reject_token_request(peer_id, "The token refund could not be linked to a lobby player.")
		return
	
	if member.is_ready:
		reject_token_request(peer_id, "Cancel ready before changing your token selection.")
		return
	
	var player:MatchPlayerData = MatchData.config.get_player(member.player_slot)
	
	if player == null:
		reject_token_request(peer_id, "The player selection data could not be found.")
		return
	
	if player.try_refund_token(token_type) == false:
		reject_token_request(peer_id, "The token could not be refunded.")
		return
	
	DebugOverlay.log_message("TokenLobby", "%s refunded %s." % [member.display_name, TokenLibrary.get_display_name(token_type)])
	publish_token_lobby_state("Token refund accepted.")


func get_valid_requesting_player(peer_id:int) -> LobbyMemberData:
	if multiplayer_lobby_active == false:
		return null
	
	if LobbyData.is_token_selection_phase() == false:
		return null
	
	if MatchData.config == null:
		return null
	
	var member:LobbyMemberData = LobbyData.get_member_by_peer_id(peer_id)
	
	if member == null:
		return null
	
	if member.is_player() == false:
		return null
	
	if member.has_player_slot() == false:
		return null
	
	if member.player_slot >= MatchData.config.get_player_count():
		return null
	
	return member


func reject_token_request(peer_id:int, message:String) -> void:
	DebugOverlay.log_warning("TokenLobby", message)
	
	if peer_id == SERVER_PEER_ID:
		show_local_invalid_feedback()
		return
	
	rpc_id(peer_id, "receive_token_request_rejected", message)
	send_token_lobby_state_to_peer(peer_id)


@rpc("authority", "call_remote", "reliable")
func receive_token_request_rejected(message:String) -> void:
	DebugOverlay.log_warning("TokenLobby", message)
	show_local_invalid_feedback()


func show_local_invalid_feedback() -> void:
	var local_member:LobbyMemberData = LobbyData.get_local_member()
	
	if local_member == null:
		return
	
	if local_member.has_player_slot() == false:
		return
	
	if player_trays_by_id.has(local_member.player_slot) == false:
		return
	
	var tray:LobbyPlayerTray = player_trays_by_id[local_member.player_slot] as LobbyPlayerTray
	
	if tray == null:
		return
	
	if is_instance_valid(tray) == false:
		return
	
	tray.play_invalid_feedback()


func update_multiplayer_controls() -> void:
	if multiplayer_lobby_active == false:
		return
	
	if options_button != null:
		options_button.disabled = is_starting_match
	
	if start_button == null:
		return
	
	var local_member:LobbyMemberData = LobbyData.get_local_member()
	
	if local_member == null:
		start_button.visible = false
		return
	
	if local_member.is_player() == false:
		start_button.visible = false
		return
	
	start_button.visible = true
	
	if is_starting_match:
		start_button.disabled = true
		start_button.text = "Starting Match..."
		return
	
	if LobbyData.get_player_count() < MatchConfig.MINIMUM_PLAYERS:
		start_button.disabled = true
		start_button.text = "Waiting for Players"
		return
	
	start_button.disabled = false
	
	var local_is_host:bool = LobbyData.is_local_host() and SteamNetwork.is_host()
	
	if local_is_host and LobbyData.all_players_ready():
		start_button.text = "Start Match"
		return
	
	if local_member.is_ready:
		start_button.text = "Cancel Ready"
	else:
		start_button.text = "Ready"


func clear_container(container:Container) -> void:
	if container == null:
		return
	
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func start_match() -> void:
	if multiplayer_lobby_active:
		start_network_match()
		return
	
	if is_starting_match:
		return
	
	if MatchData.config == null:
		push_error("Cannot start match because MatchData.config is null.")
		return
	
	if MatchData.config.get_player_count() < MatchConfig.MINIMUM_PLAYERS:
		push_error("Cannot start match without at least " + str(MatchConfig.MINIMUM_PLAYERS) + " players.")
		return
	
	if game_board_scene == null:
		push_error("Cannot start match because no game board scene has been assigned.")
		return
	
	is_starting_match = true
	
	if start_button != null:
		start_button.disabled = true
	
	var change_error:Error = get_tree().change_scene_to_packed(game_board_scene)
	
	if change_error == OK:
		return
	
	is_starting_match = false
	
	if start_button != null:
		start_button.disabled = false
	
	push_error("Could not change to the game board scene. Error code: " + str(change_error))


func start_network_match() -> void:
	if multiplayer_lobby_active == false:
		return
	
	if SteamNetwork.is_host() == false:
		return
	
	if multiplayer.is_server() == false:
		return
	
	if is_starting_match:
		return
	
	if LobbyData.all_players_ready() == false:
		DebugOverlay.log_warning("TokenLobby", "The match cannot start until every player is ready.")
		update_multiplayer_controls()
		return
	
	if MatchData.config == null:
		DebugOverlay.log_error("TokenLobby", "The networked match cannot start without match configuration data.")
		return
	
	if game_board_scene == null:
		DebugOverlay.log_error("TokenLobby", "The networked match cannot start because the game board scene is missing.")
		return
	
	var resolved_starting_player_id:int = MatchData.get_resolved_starting_player_id()
	
	if resolved_starting_player_id < 0:
		DebugOverlay.log_error("TokenLobby", "The networked match could not resolve a starting player.")
		return
	
	MatchData.config.set_starting_player_id(resolved_starting_player_id)
	
	host_state_revision += 1
	var final_state:Dictionary = create_token_lobby_state()
	
	if final_state.is_empty():
		DebugOverlay.log_error("TokenLobby", "The final token-selection state could not be created.")
		return
	
	is_starting_match = true
	last_applied_state_revision = host_state_revision
	
	LobbyData.set_lobby_phase(LobbyData.LOBBY_PHASE.MATCH_IN_PROGRESS)
	SteamNetwork.refresh_host_lobby_metadata()
	LobbyAdmission.broadcast_current_snapshot()
	update_multiplayer_controls()
	
	DebugOverlay.log_message("TokenLobby", "Starting the networked match with player slot %d taking the first turn." % resolved_starting_player_id)
	
	rpc("receive_network_match_start", final_state)
	call_deferred("begin_network_match_locally", final_state)


@rpc("authority", "call_remote", "reliable")
func receive_network_match_start(final_state:Dictionary) -> void:
	DebugOverlay.log_message("TokenLobby", "The host instructed this peer to start the match.")
	begin_network_match_locally(final_state)


func begin_network_match_locally(final_state:Dictionary) -> void:
	if final_state.is_empty():
		DebugOverlay.log_error("TokenLobby", "The match start message contained no token-selection state.")
		return
	
	if apply_token_lobby_state(final_state) == false:
		DebugOverlay.log_error("TokenLobby", "The final token-selection state could not be applied before entering the match.")
		return
	
	is_starting_match = true
	LobbyData.set_lobby_phase(LobbyData.LOBBY_PHASE.MATCH_IN_PROGRESS)
	update_multiplayer_controls()
	
	var change_error:Error = get_tree().change_scene_to_packed(game_board_scene)
	
	if change_error == OK:
		return
	
	is_starting_match = false
	DebugOverlay.log_error("TokenLobby", "Could not change to the networked game board scene. Error code: %d" % int(change_error))
	update_multiplayer_controls()


func _on_start_button_pressed() -> void:
	if multiplayer_lobby_active == false:
		start_match()
		return
	
	var local_member:LobbyMemberData = LobbyData.get_local_member()
	
	if local_member == null:
		return
	
	if SteamNetwork.is_host() and LobbyData.all_players_ready():
		start_network_match()
		return
	
	request_local_ready_state(local_member.is_ready == false)


func _on_match_options_applied() -> void:
	if multiplayer_lobby_active:
		if LobbyData.is_local_host() == false:
			return
		
		synchronise_match_config_from_lobby()
		reset_all_players_ready("Match options changed.")
		SteamNetwork.refresh_host_lobby_metadata()
		publish_token_lobby_state("Match options changed.")
		return
	
	create_player_trays()


func _on_lobby_members_changed() -> void:
	if is_multiplayer_lobby_active() == false:
		return
	
	multiplayer_lobby_active = true
	synchronise_match_config_from_lobby()
	create_player_trays()
	update_multiplayer_controls()
	
	if SteamNetwork.is_host():
		reset_all_players_ready("Lobby roster changed.")
		call_deferred("publish_token_lobby_state", "Lobby roster changed.")
	
	DebugOverlay.log_message("TokenLobby", "Lobby roster updated: %d players and %d spectators." % [LobbyData.get_player_count(), LobbyData.get_spectator_count()])

func _on_lobby_cleared() -> void:
	multiplayer_lobby_active = false
	known_member_steam_ids_by_slot.clear()
	player_trays_by_id.clear()
	state_request_sent = false
	last_applied_state_revision = -1
	create_player_trays()

func _on_host_disconnected() -> void:
	if multiplayer_disconnect_popup == null:
		push_error("TokenLobby: MultiplayerDisconnectPopup could not be found.")
		return
	
	DebugOverlay.log_message("TokenLobby", "The host disconnected. Showing the lobby closed popup.")
	multiplayer_disconnect_popup.show_host_disconnected()

func setup_local_bot_smoke_test() -> void:
	if MatchData.config == null:
		return
	
	if MatchData.config.get_player_count() < 2:
		return
	
	if MatchData.config.set_player_as_bot(
		0,
		"duncan",
		MatchPlayerData.BOT_DIFFICULTY.NORMAL
	) == false:
		push_error("TokenLobby: Could not configure Player 1 as Duncan.")
		return
	
	if MatchData.config.set_player_as_bot(
		1,
		"periwinkle",
		MatchPlayerData.BOT_DIFFICULTY.NORMAL
	) == false:
		push_error("TokenLobby: Could not configure Player 2 as Periwinkle.")
