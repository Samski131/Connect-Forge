extends Node

signal network_state_changed(new_state:NETWORK_STATE)

signal debug_message_requested(message:String)

signal steam_initialised(steam_id:int, persona_name:String)
signal steam_initialisation_failed(message:String)

signal lobby_creation_started
signal lobby_created(lobby_id:int)
signal lobby_metadata_published(lobby_id:int)
signal lobby_creation_failed(message:String)

signal lobby_search_started
signal lobby_search_completed(lobbies:Array)
signal lobby_search_failed(message:String)

signal lobby_join_started(lobby_id:int)
signal steam_lobby_joined(lobby_id:int, owner_steam_id:int)
signal lobby_join_failed(message:String)

signal lobby_left(lobby_id:int, reason:String)

signal multiplayer_host_created
signal multiplayer_client_created(owner_steam_id:int)
signal multiplayer_connection_ready

signal peer_connected(peer_id:int)
signal peer_disconnected(peer_id:int)
signal connection_failed
signal host_disconnected

enum NETWORK_STATE {
	UNINITIALISED,
	INITIALISING,
	IDLE,
	SEARCHING_LOBBIES,
	CREATING_LOBBY,
	JOINING_LOBBY,
	CONNECTING_TO_HOST,
	IN_LOBBY,
	LEAVING_LOBBY
}

enum LOBBY_ACCESS {
	PUBLIC,
	FRIENDS,
	PASSWORD_PROTECTED
}

const APP_ID:int = 480

const INVALID_LOBBY_ID:int = 0
const INVALID_STEAM_ID:int = 0
const INVALID_PEER_ID:int = 0

const DEFAULT_MAXIMUM_MEMBERS:int = 16
const STEAM_LOBBY_JOIN_SUCCESS:int = 1

const GAME_KEY:String = "connectforge_dev"
const PROTOCOL_VERSION:int = 11
const DEVELOPMENT_BUILD_VERSION:String = "development"

const MAXIMUM_LOBBY_NAME_LENGTH:int = 64
const MAXIMUM_LOBBY_DESCRIPTION_LENGTH:int = 240

const METADATA_GAME_KEY:String = "game_key"
const METADATA_PROTOCOL_VERSION:String = "protocol_version"
const METADATA_BUILD_VERSION:String = "build_version"
const METADATA_LOBBY_NAME:String = "lobby_name"
const METADATA_DESCRIPTION:String = "description"
const METADATA_ACCESS_TYPE:String = "access_type"
const METADATA_HAS_PASSWORD:String = "has_password"
const METADATA_LOBBY_PHASE:String = "lobby_phase"
const METADATA_ACTIVE_PLAYER_COUNT:String = "active_player_count"
const METADATA_MAXIMUM_PLAYERS:String = "maximum_players"
const METADATA_MAXIMUM_MEMBERS:String = "maximum_members"
const METADATA_HOST_NAME:String = "host_name"
const METADATA_BOARD_COLUMNS:String = "board_columns"
const METADATA_BOARD_ROWS:String = "board_rows"
const METADATA_TOKENS_TO_WIN:String = "tokens_to_win"
const METADATA_TURN_TIMER_SECONDS:String = "turn_timer_seconds"
const METADATA_STARTING_TOKEN_POINTS:String = "starting_token_points"

const MAXIMUM_LOBBY_SEARCH_RESULTS:int = 50
const LOBBY_SEARCH_TIMEOUT_SECONDS:float = 22.0

const RESULT_LOBBY_ID:String = "lobby_id"
const RESULT_LOBBY_NAME:String = "lobby_name"
const RESULT_DESCRIPTION:String = "description"
const RESULT_ACCESS_TYPE:String = "access_type"
const RESULT_HAS_PASSWORD:String = "has_password"
const RESULT_LOBBY_PHASE:String = "lobby_phase"
const RESULT_MEMBER_COUNT:String = "member_count"
const RESULT_MEMBER_LIMIT:String = "member_limit"
const RESULT_ACTIVE_PLAYER_COUNT:String = "active_player_count"
const RESULT_MAXIMUM_PLAYERS:String = "maximum_players"
const RESULT_SPECTATOR_COUNT:String = "spectator_count"
const RESULT_HOST_NAME:String = "host_name"
const RESULT_BOARD_COLUMNS:String = "board_columns"
const RESULT_BOARD_ROWS:String = "board_rows"
const RESULT_TOKENS_TO_WIN:String = "tokens_to_win"
const RESULT_TURN_TIMER_SECONDS:String = "turn_timer_seconds"
const RESULT_STARTING_TOKEN_POINTS:String = "starting_token_points"
const RESULT_IS_FULL:String = "is_full"
const RESULT_IS_MATCH_IN_PROGRESS:String = "is_match_in_progress"

var current_state:NETWORK_STATE = NETWORK_STATE.UNINITIALISED

var steam_initialised_successfully:bool = false
var local_steam_id:int = INVALID_STEAM_ID
var local_persona_name:String = ""

var current_lobby_id:int = INVALID_LOBBY_ID
var current_lobby_owner_steam_id:int = INVALID_STEAM_ID
var current_lobby_maximum_members:int = DEFAULT_MAXIMUM_MEMBERS

var current_lobby_name:String = ""
var current_lobby_description:String = ""
var current_lobby_access:LOBBY_ACCESS = LOBBY_ACCESS.PUBLIC
var current_lobby_password:String = ""

var pending_lobby_name:String = ""
var pending_lobby_description:String = ""
var pending_lobby_access:LOBBY_ACCESS = LOBBY_ACCESS.PUBLIC
var pending_lobby_password:String = ""
var pending_lobby_maximum_members:int = DEFAULT_MAXIMUM_MEMBERS

var last_lobby_search_results:Array[Dictionary] = []

var active_lobby_search_request_id:int = 0
var next_lobby_search_request_id:int = 1

var steam_peer:SteamMultiplayerPeer = null


func _init() -> void:
	OS.set_environment("SteamAppID", str(APP_ID))
	OS.set_environment("SteamGameID", str(APP_ID))


func _ready() -> void:
	_connect_steam_signals()
	_connect_multiplayer_signals()
	initialise_steam()


func _process(_delta:float) -> void:
	if steam_initialised_successfully == false:
		return
	
	Steam.run_callbacks()


func initialise_steam() -> bool:
	if steam_initialised_successfully:
		return true
	
	if current_state == NETWORK_STATE.INITIALISING:
		return false
	
	_set_network_state(NETWORK_STATE.INITIALISING)
	_emit_debug_message("Initialising Steam with App ID %d." % APP_ID)
	
	var initialisation_result:Dictionary = Steam.steamInitEx(APP_ID, false)
	var verbal_result:String = str(initialisation_result.get("verbal", "No Steam initialisation message was returned."))
	
	_emit_debug_message("Steam initialisation result: %s" % str(initialisation_result))
	
	if Steam.isSteamRunning() == false:
		_handle_steam_initialisation_failure(verbal_result)
		return false
	
	local_steam_id = Steam.getSteamID()
	local_persona_name = Steam.getPersonaName().strip_edges()
	
	if local_steam_id <= INVALID_STEAM_ID:
		_handle_steam_initialisation_failure("Steam returned an invalid local Steam ID.")
		return false
	
	if local_persona_name == "":
		local_persona_name = "Steam User"
	
	Steam.initRelayNetworkAccess()
	
	steam_initialised_successfully = true
	_set_network_state(NETWORK_STATE.IDLE)
	
	_emit_debug_message("Steam initialised successfully.")
	_emit_debug_message("Local Steam ID: %d" % local_steam_id)
	_emit_debug_message("Local Steam name: %s" % local_persona_name)
	
	steam_initialised.emit(local_steam_id, local_persona_name)
	return true


func create_lobby(lobby_name:String, description:String, access_type:LOBBY_ACCESS = LOBBY_ACCESS.PUBLIC, password:String = "", maximum_members:int = DEFAULT_MAXIMUM_MEMBERS) -> bool:
	if can_start_lobby_operation() == false:
		return false
	
	var used_lobby_name:String = lobby_name.strip_edges()
	var used_description:String = description.strip_edges()
	var used_password:String = password
	var used_access_type:LOBBY_ACCESS = get_valid_lobby_access(int(access_type))
	var used_maximum_members:int = max(maximum_members, MatchConfig.MAXIMUM_PLAYERS)
	
	if used_lobby_name == "":
		return _reject_lobby_creation("A lobby name is required.")
	
	if used_lobby_name.length() > MAXIMUM_LOBBY_NAME_LENGTH:
		used_lobby_name = used_lobby_name.substr(0, MAXIMUM_LOBBY_NAME_LENGTH)
	
	if used_description.length() > MAXIMUM_LOBBY_DESCRIPTION_LENGTH:
		used_description = used_description.substr(0, MAXIMUM_LOBBY_DESCRIPTION_LENGTH)
	
	if used_access_type == LOBBY_ACCESS.PASSWORD_PROTECTED:
		if used_password == "":
			return _reject_lobby_creation("Password-protected lobbies require a password.")
	else:
		used_password = ""
	
	pending_lobby_name = used_lobby_name
	pending_lobby_description = used_description
	pending_lobby_access = used_access_type
	pending_lobby_password = used_password
	pending_lobby_maximum_members = used_maximum_members
	
	current_lobby_id = INVALID_LOBBY_ID
	current_lobby_owner_steam_id = INVALID_STEAM_ID
	current_lobby_maximum_members = used_maximum_members
	
	var steam_lobby_type:int = get_steam_lobby_type(used_access_type)
	
	_set_network_state(NETWORK_STATE.CREATING_LOBBY)
	
	_emit_debug_message("Requesting Steam lobby creation.")
	_emit_debug_message("Lobby name: %s" % used_lobby_name)
	_emit_debug_message("Access type: %s" % get_lobby_access_display_name(used_access_type))
	_emit_debug_message("Maximum lobby members: %d" % used_maximum_members)
	
	lobby_creation_started.emit()
	Steam.createLobby(steam_lobby_type, used_maximum_members)
	return true


func search_public_lobbies() -> bool:
	if steam_initialised_successfully == false:
		return _reject_lobby_search("Steam is not initialised.")
	
	if current_state != NETWORK_STATE.IDLE:
		return _reject_lobby_search("A lobby search cannot begin while the network is busy.")
	
	if current_lobby_id > INVALID_LOBBY_ID:
		return _reject_lobby_search("A lobby search cannot begin while already inside a lobby.")
	
	last_lobby_search_results.clear()
	
	var request_id:int = next_lobby_search_request_id
	next_lobby_search_request_id += 1
	active_lobby_search_request_id = request_id
	
	_set_network_state(NETWORK_STATE.SEARCHING_LOBBIES)
	
	Steam.addRequestLobbyListDistanceFilter(Steam.LobbyDistanceFilter.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter(METADATA_GAME_KEY, GAME_KEY, Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListNumericalFilter(METADATA_PROTOCOL_VERSION, PROTOCOL_VERSION, Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter(METADATA_BUILD_VERSION, get_build_version(), Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListResultCountFilter(MAXIMUM_LOBBY_SEARCH_RESULTS)
	
	_emit_debug_message("Requesting compatible Steam lobbies.")
	_emit_debug_message("Search game key: %s" % GAME_KEY)
	_emit_debug_message("Search protocol version: %d" % PROTOCOL_VERSION)
	_emit_debug_message("Search build version: %s" % get_build_version())
	
	lobby_search_started.emit()
	Steam.requestLobbyList()
	
	var timeout_timer:SceneTreeTimer = get_tree().create_timer(LOBBY_SEARCH_TIMEOUT_SECONDS)
	timeout_timer.timeout.connect(_on_lobby_search_timeout.bind(request_id), CONNECT_ONE_SHOT)
	return true


func join_lobby(lobby_id:int) -> bool:
	if can_start_lobby_operation() == false:
		return false
	
	if lobby_id <= INVALID_LOBBY_ID:
		_emit_debug_message("Cannot join an invalid Steam lobby ID.")
		lobby_join_failed.emit("The lobby ID is invalid.")
		return false
	
	var lobby_owner_steam_id:int = Steam.getLobbyOwner(lobby_id)
	
	if lobby_owner_steam_id == local_steam_id:
		var message:String = "You cannot join a lobby hosted by the same Steam account."
		_emit_debug_message(message)
		lobby_join_failed.emit(message)
		return false
	
	current_lobby_id = lobby_id
	current_lobby_owner_steam_id = INVALID_STEAM_ID
	current_lobby_maximum_members = DEFAULT_MAXIMUM_MEMBERS
	
	_set_network_state(NETWORK_STATE.JOINING_LOBBY)
	
	_emit_debug_message("Requesting entry to Steam lobby %d." % current_lobby_id)
	
	lobby_join_started.emit(current_lobby_id)
	Steam.joinLobby(current_lobby_id)
	return true


func leave_lobby(reason:String = "") -> void:
	if current_state == NETWORK_STATE.LEAVING_LOBBY:
		return
	
	var previous_lobby_id:int = current_lobby_id
	
	_set_network_state(NETWORK_STATE.LEAVING_LOBBY)
	
	if previous_lobby_id > INVALID_LOBBY_ID:
		if steam_initialised_successfully:
			Steam.leaveLobby(previous_lobby_id)
	
	_reset_multiplayer_peer()
	
	if LobbyData.has_active_lobby():
		LobbyData.clear_lobby()
	
	_clear_current_lobby_data()
	_clear_pending_lobby_creation_data()
	
	if steam_initialised_successfully:
		_set_network_state(NETWORK_STATE.IDLE)
	else:
		_set_network_state(NETWORK_STATE.UNINITIALISED)
	
	_emit_debug_message("Left Steam lobby %d. %s" % [previous_lobby_id, reason])
	lobby_left.emit(previous_lobby_id, reason)


func refresh_host_lobby_metadata() -> bool:
	if is_host() == false:
		return false
	
	if current_lobby_id <= INVALID_LOBBY_ID:
		return false
	
	return _publish_current_lobby_metadata()


func validate_lobby_password(password_attempt:String) -> bool:
	if current_lobby_access != LOBBY_ACCESS.PASSWORD_PROTECTED:
		return true
	
	return password_attempt == current_lobby_password


func can_start_lobby_operation() -> bool:
	if steam_initialised_successfully == false:
		_emit_debug_message("A lobby operation was rejected because Steam is not initialised.")
		return false
	
	if current_state != NETWORK_STATE.IDLE:
		_emit_debug_message("A lobby operation was rejected because the network is busy.")
		return false
	
	if current_lobby_id > INVALID_LOBBY_ID:
		_emit_debug_message("A lobby operation was rejected because a lobby is already active.")
		return false
	
	return true


func is_steam_initialised() -> bool:
	return steam_initialised_successfully


func is_in_lobby() -> bool:
	return current_state == NETWORK_STATE.IN_LOBBY


func is_host() -> bool:
	if is_in_lobby() == false:
		return false
	
	if local_steam_id <= INVALID_STEAM_ID:
		return false
	
	return local_steam_id == current_lobby_owner_steam_id


func is_client() -> bool:
	if is_in_lobby() == false:
		return false
	
	return is_host() == false


func get_network_state() -> NETWORK_STATE:
	return current_state


func get_local_steam_id() -> int:
	return local_steam_id


func get_local_persona_name() -> String:
	return local_persona_name


func get_lobby_id() -> int:
	return current_lobby_id


func get_lobby_owner_steam_id() -> int:
	return current_lobby_owner_steam_id


func get_lobby_name() -> String:
	return current_lobby_name


func get_lobby_description() -> String:
	return current_lobby_description


func get_lobby_access() -> LOBBY_ACCESS:
	return current_lobby_access


func get_multiplayer_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return INVALID_PEER_ID
	
	return multiplayer.get_unique_id()


func get_network_state_display_name() -> String:
	match current_state:
		NETWORK_STATE.UNINITIALISED:
			return "Uninitialised"
		
		NETWORK_STATE.INITIALISING:
			return "Initialising"
		
		NETWORK_STATE.IDLE:
			return "Idle"
		
		NETWORK_STATE.CREATING_LOBBY:
			return "Creating Lobby"
		
		NETWORK_STATE.JOINING_LOBBY:
			return "Joining Lobby"
		
		NETWORK_STATE.CONNECTING_TO_HOST:
			return "Connecting To Host"
		
		NETWORK_STATE.IN_LOBBY:
			return "In Lobby"
		
		NETWORK_STATE.LEAVING_LOBBY:
			return "Leaving Lobby"
		
		NETWORK_STATE.SEARCHING_LOBBIES:
			return "Searching Lobbies"
	
	return "Unknown"


func get_lobby_access_display_name(access_type:LOBBY_ACCESS) -> String:
	match access_type:
		LOBBY_ACCESS.PUBLIC:
			return "Public"
		
		LOBBY_ACCESS.FRIENDS:
			return "Friends"
		
		LOBBY_ACCESS.PASSWORD_PROTECTED:
			return "Password Protected"
	
	return "Public"


func get_lobby_metadata_value(key:String) -> String:
	if current_lobby_id <= INVALID_LOBBY_ID:
		return ""
	
	return Steam.getLobbyData(current_lobby_id, key)


func _connect_steam_signals() -> void:
	if Steam.lobby_created.is_connected(_on_steam_lobby_created) == false:
		Steam.lobby_created.connect(_on_steam_lobby_created)
	
	if Steam.lobby_joined.is_connected(_on_steam_lobby_joined) == false:
		Steam.lobby_joined.connect(_on_steam_lobby_joined)
	
	if Steam.lobby_match_list.is_connected(_on_steam_lobby_match_list) == false:
		Steam.lobby_match_list.connect(_on_steam_lobby_match_list)


func _connect_multiplayer_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_multiplayer_peer_connected) == false:
		multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	
	if multiplayer.peer_disconnected.is_connected(_on_multiplayer_peer_disconnected) == false:
		multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server) == false:
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	if multiplayer.connection_failed.is_connected(_on_multiplayer_connection_failed) == false:
		multiplayer.connection_failed.connect(_on_multiplayer_connection_failed)
	
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected) == false:
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_steam_lobby_created(result:int, created_lobby_id:int) -> void:
	if current_state != NETWORK_STATE.CREATING_LOBBY:
		_emit_debug_message("Ignoring an unexpected Steam lobby-created callback.")
		return
	
	if result != Steam.Result.RESULT_OK:
		_handle_lobby_creation_failure("Steam failed to create the lobby. Result code: %d" % result)
		return
	
	if created_lobby_id <= INVALID_LOBBY_ID:
		_handle_lobby_creation_failure("Steam created a lobby with an invalid lobby ID.")
		return
	
	current_lobby_id = created_lobby_id
	current_lobby_owner_steam_id = local_steam_id
	current_lobby_maximum_members = pending_lobby_maximum_members
	
	current_lobby_name = pending_lobby_name
	current_lobby_description = pending_lobby_description
	current_lobby_access = pending_lobby_access
	current_lobby_password = pending_lobby_password
	
	if _create_host_multiplayer_peer() == false:
		Steam.leaveLobby(current_lobby_id)
		_handle_lobby_creation_failure("The Steam lobby was created, but the multiplayer host could not be created.")
		return
	
	if _begin_host_lobby_data() == false:
		Steam.leaveLobby(current_lobby_id)
		_reset_multiplayer_peer()
		_handle_lobby_creation_failure("The Steam lobby was created, but its local lobby data could not be created.")
		return
	
	if Steam.setLobbyJoinable(current_lobby_id, true) == false:
		Steam.leaveLobby(current_lobby_id)
		_reset_multiplayer_peer()
		LobbyData.clear_lobby()
		_handle_lobby_creation_failure("The Steam lobby was created, but it could not be made joinable.")
		return
	
	if _publish_current_lobby_metadata() == false:
		Steam.leaveLobby(current_lobby_id)
		_reset_multiplayer_peer()
		LobbyData.clear_lobby()
		_handle_lobby_creation_failure("The Steam lobby was created, but its metadata could not be published.")
		return
	
	_clear_pending_lobby_creation_data()
	_set_network_state(NETWORK_STATE.IN_LOBBY)
	
	_emit_debug_message("Steam lobby created successfully.")
	_emit_debug_message("Lobby ID: %d" % current_lobby_id)
	_emit_debug_message("Host peer ID: %d" % multiplayer.get_unique_id())
	
	_print_current_lobby_metadata()
	
	lobby_created.emit(current_lobby_id)
	multiplayer_host_created.emit()
	multiplayer_connection_ready.emit()


func _on_steam_lobby_joined(joined_lobby_id:int, permissions:int, locked:int, response:int) -> void:
	_emit_debug_message("Steam lobby-joined callback received.")
	_emit_debug_message("Lobby ID: %d" % joined_lobby_id)
	_emit_debug_message("Permissions: %d" % permissions)
	_emit_debug_message("Locked: %d" % locked)
	_emit_debug_message("Response: %d" % response)
	
	if current_state != NETWORK_STATE.JOINING_LOBBY:
		_emit_debug_message("Ignoring the lobby-joined callback because no join operation is active.")
		return
	
	if response != STEAM_LOBBY_JOIN_SUCCESS:
		_handle_lobby_join_failure("Steam rejected the lobby join request. Response code: %d" % response)
		return
	
	if joined_lobby_id <= INVALID_LOBBY_ID:
		_handle_lobby_join_failure("Steam returned an invalid joined lobby ID.")
		return
	
	current_lobby_id = joined_lobby_id
	current_lobby_owner_steam_id = Steam.getLobbyOwner(current_lobby_id)
	current_lobby_maximum_members = Steam.getLobbyMemberLimit(current_lobby_id)
	
	if current_lobby_maximum_members <= 0:
		current_lobby_maximum_members = DEFAULT_MAXIMUM_MEMBERS
	
	if current_lobby_owner_steam_id <= INVALID_STEAM_ID:
		Steam.leaveLobby(current_lobby_id)
		_handle_lobby_join_failure("The owner of the Steam lobby could not be found.")
		return
	
	_read_current_lobby_metadata()
	
	if _create_client_multiplayer_peer(current_lobby_owner_steam_id) == false:
		Steam.leaveLobby(current_lobby_id)
		_handle_lobby_join_failure("The Steam lobby was joined, but its multiplayer client could not be created.")
		return
	
	if LobbyData.begin_lobby(current_lobby_id, current_lobby_owner_steam_id, local_steam_id, current_lobby_maximum_members) == false:
		Steam.leaveLobby(current_lobby_id)
		_reset_multiplayer_peer()
		_handle_lobby_join_failure("The Steam lobby was joined, but its local lobby data could not be created.")
		return
	
	_set_network_state(NETWORK_STATE.CONNECTING_TO_HOST)
	
	_emit_debug_message("Joined the Steam lobby.")
	_emit_debug_message("Connecting to Steam lobby owner %d." % current_lobby_owner_steam_id)
	
	steam_lobby_joined.emit(current_lobby_id, current_lobby_owner_steam_id)
	multiplayer_client_created.emit(current_lobby_owner_steam_id)


func _create_host_multiplayer_peer() -> bool:
	_reset_multiplayer_peer()
	
	steam_peer = SteamMultiplayerPeer.new()
	steam_peer.server_relay = true
	
	var create_result:Error = steam_peer.create_host()
	
	if create_result != OK:
		_emit_debug_message("Failed to create the Steam multiplayer host: %s" % error_string(create_result))
		steam_peer = null
		return false
	
	multiplayer.multiplayer_peer = steam_peer
	return true


func _create_client_multiplayer_peer(owner_steam_id:int) -> bool:
	if owner_steam_id <= INVALID_STEAM_ID:
		return false
	
	_reset_multiplayer_peer()
	
	steam_peer = SteamMultiplayerPeer.new()
	steam_peer.server_relay = true
	
	var create_result:Error = steam_peer.create_client(owner_steam_id)
	
	if create_result != OK:
		_emit_debug_message("Failed to create the Steam multiplayer client: %s" % error_string(create_result))
		steam_peer = null
		return false
	
	multiplayer.multiplayer_peer = steam_peer
	return true


func _begin_host_lobby_data() -> bool:
	if LobbyData.begin_lobby(current_lobby_id, local_steam_id, local_steam_id, current_lobby_maximum_members) == false:
		return false
	
	var host_member:LobbyMemberData = LobbyMemberData.new()
	host_member.setup(local_steam_id, multiplayer.get_unique_id(), local_persona_name, LobbyMemberData.MEMBER_ROLE.SPECTATOR, true)
	
	if host_member.assign_player_slot(0) == false:
		LobbyData.clear_lobby()
		return false
	
	if LobbyData.add_member(host_member) == false:
		LobbyData.clear_lobby()
		return false
	
	return true


func _publish_current_lobby_metadata() -> bool:
	if current_lobby_id <= INVALID_LOBBY_ID:
		return false
	
	if current_lobby_owner_steam_id != local_steam_id:
		return false
	
	var metadata:Dictionary = _create_current_lobby_metadata()
	var all_metadata_succeeded:bool = true
	
	for key_value in metadata.keys():
		var key:String = str(key_value)
		var value:String = str(metadata[key_value])
		
		if _set_lobby_metadata_value(key, value) == false:
			all_metadata_succeeded = false
	
	if all_metadata_succeeded:
		_emit_debug_message("Lobby metadata published successfully.")
		lobby_metadata_published.emit(current_lobby_id)
	else:
		_emit_debug_message("One or more lobby metadata values failed to publish.")
	
	return all_metadata_succeeded


func _create_current_lobby_metadata() -> Dictionary:
	var metadata:Dictionary = {
		METADATA_GAME_KEY: GAME_KEY,
		METADATA_PROTOCOL_VERSION: str(PROTOCOL_VERSION),
		METADATA_BUILD_VERSION: get_build_version(),
		METADATA_LOBBY_NAME: current_lobby_name,
		METADATA_DESCRIPTION: current_lobby_description,
		METADATA_ACCESS_TYPE: get_lobby_access_metadata_value(current_lobby_access),
		METADATA_HAS_PASSWORD: get_password_metadata_value(),
		METADATA_LOBBY_PHASE: get_lobby_phase_metadata_value(),
		METADATA_ACTIVE_PLAYER_COUNT: str(LobbyData.get_player_count()),
		METADATA_MAXIMUM_PLAYERS: str(MatchConfig.MAXIMUM_PLAYERS),
		METADATA_MAXIMUM_MEMBERS: str(current_lobby_maximum_members),
		METADATA_HOST_NAME: local_persona_name
	}
	
	var config:MatchConfig = MatchData.config
	
	if config != null:
		metadata[METADATA_STARTING_TOKEN_POINTS] = str(config.starting_token_points)
		metadata[METADATA_BOARD_COLUMNS] = str(config.board_columns)
		metadata[METADATA_BOARD_ROWS] = str(config.board_rows)
		metadata[METADATA_TOKENS_TO_WIN] = str(config.tokens_to_win)
		metadata[METADATA_TURN_TIMER_SECONDS] = str(config.turn_timer_seconds)
	else:
		metadata[METADATA_STARTING_TOKEN_POINTS] = "10"
		metadata[METADATA_BOARD_COLUMNS] = "7"
		metadata[METADATA_BOARD_ROWS] = "6"
		metadata[METADATA_TOKENS_TO_WIN] = "4"
		metadata[METADATA_TURN_TIMER_SECONDS] = "0"
	
	return metadata


func _set_lobby_metadata_value(key:String, value:String) -> bool:
	if key == "":
		return false
	
	var succeeded:bool = Steam.setLobbyData(current_lobby_id, key, value)
	
	if succeeded == false:
		_emit_debug_message("Failed to set lobby metadata: %s = %s" % [key, value])
		return false
	
	_emit_debug_message("Set lobby metadata: %s = %s" % [key, value])
	return true


func _read_current_lobby_metadata() -> void:
	current_lobby_name = Steam.getLobbyData(current_lobby_id, METADATA_LOBBY_NAME)
	current_lobby_description = Steam.getLobbyData(current_lobby_id, METADATA_DESCRIPTION)
	
	var access_value:String = Steam.getLobbyData(current_lobby_id, METADATA_ACCESS_TYPE)
	current_lobby_access = get_lobby_access_from_metadata(access_value)
	
	current_lobby_password = ""


func _print_current_lobby_metadata() -> void:
	if current_lobby_id <= INVALID_LOBBY_ID:
		return
	
	_emit_debug_message("--- Published Lobby Metadata ---")
	
	var metadata:Dictionary = _create_current_lobby_metadata()
	
	for key_value in metadata.keys():
		var key:String = str(key_value)
		var value:String = Steam.getLobbyData(current_lobby_id, key)
		_emit_debug_message("%s: %s" % [key, value])
	
	_emit_debug_message("--- End Lobby Metadata ---")


func get_build_version() -> String:
	if ProjectSettings.has_setting("application/config/version"):
		var configured_version:String = str(ProjectSettings.get_setting("application/config/version")).strip_edges()
		
		if configured_version != "":
			return configured_version
	
	return DEVELOPMENT_BUILD_VERSION


func get_password_metadata_value() -> String:
	if current_lobby_access == LOBBY_ACCESS.PASSWORD_PROTECTED:
		return "1"
	
	return "0"


func get_lobby_phase_metadata_value() -> String:
	match LobbyData.get_lobby_phase():
		LobbyData.LOBBY_PHASE.TOKEN_SELECTION:
			return "token_selection"
		
		LobbyData.LOBBY_PHASE.MATCH_IN_PROGRESS:
			return "match_in_progress"
		
		LobbyData.LOBBY_PHASE.RETURNING_TO_LOBBY:
			return "returning_to_lobby"
		
		LobbyData.LOBBY_PHASE.CLOSED:
			return "closed"
	
	return "none"


func get_lobby_access_metadata_value(access_type:LOBBY_ACCESS) -> String:
	match access_type:
		LOBBY_ACCESS.PUBLIC:
			return "public"
		
		LOBBY_ACCESS.FRIENDS:
			return "friends"
		
		LOBBY_ACCESS.PASSWORD_PROTECTED:
			return "password_protected"
	
	return "public"


func get_lobby_access_from_metadata(access_value:String) -> LOBBY_ACCESS:
	match access_value.strip_edges().to_lower():
		"friends":
			return LOBBY_ACCESS.FRIENDS
		
		"password_protected":
			return LOBBY_ACCESS.PASSWORD_PROTECTED
	
	return LOBBY_ACCESS.PUBLIC


func get_steam_lobby_type(access_type:LOBBY_ACCESS) -> int:
	if access_type == LOBBY_ACCESS.FRIENDS:
		return Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
	
	return Steam.LobbyType.LOBBY_TYPE_PUBLIC


func get_valid_lobby_access(access_value:int) -> LOBBY_ACCESS:
	if access_value == LOBBY_ACCESS.FRIENDS:
		return LOBBY_ACCESS.FRIENDS
	
	if access_value == LOBBY_ACCESS.PASSWORD_PROTECTED:
		return LOBBY_ACCESS.PASSWORD_PROTECTED
	
	return LOBBY_ACCESS.PUBLIC


func _reset_multiplayer_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	steam_peer = null


func _on_connected_to_server() -> void:
	_set_network_state(NETWORK_STATE.IN_LOBBY)
	
	_emit_debug_message("Connected to the Steam multiplayer host.")
	_emit_debug_message("Local multiplayer peer ID: %d" % multiplayer.get_unique_id())
	
	multiplayer_connection_ready.emit()


func _on_multiplayer_peer_connected(peer_id:int) -> void:
	_emit_debug_message("Multiplayer peer connected: %d" % peer_id)
	peer_connected.emit(peer_id)


func _on_multiplayer_peer_disconnected(peer_id:int) -> void:
	_emit_debug_message("Multiplayer peer disconnected: %d" % peer_id)
	
	if multiplayer.is_server():
		var disconnected_member:LobbyMemberData = LobbyData.get_member_by_peer_id(peer_id)
		
		if disconnected_member != null:
			LobbyData.remove_member(disconnected_member.steam_id)
	
	peer_disconnected.emit(peer_id)


func _on_multiplayer_connection_failed() -> void:
	_emit_debug_message("The multiplayer connection to the host failed.")
	
	connection_failed.emit()
	leave_lobby("The connection to the host failed.")


func _on_server_disconnected() -> void:
	_emit_debug_message("The multiplayer host disconnected.")
	
	host_disconnected.emit()
	leave_lobby("The host closed the lobby.")


func _handle_steam_initialisation_failure(message:String) -> void:
	steam_initialised_successfully = false
	local_steam_id = INVALID_STEAM_ID
	local_persona_name = ""
	last_lobby_search_results.clear()
	active_lobby_search_request_id = 0
	
	_set_network_state(NETWORK_STATE.UNINITIALISED)
	_emit_debug_message("Steam initialisation failed: %s" % message)
	
	steam_initialisation_failed.emit(message)


func _handle_lobby_creation_failure(message:String) -> void:
	_reset_multiplayer_peer()
	
	if LobbyData.has_active_lobby():
		LobbyData.clear_lobby()
	
	_clear_current_lobby_data()
	_clear_pending_lobby_creation_data()
	
	_set_network_state(NETWORK_STATE.IDLE)
	_emit_debug_message(message)
	
	lobby_creation_failed.emit(message)


func _handle_lobby_join_failure(message:String) -> void:
	_reset_multiplayer_peer()
	
	if LobbyData.has_active_lobby():
		LobbyData.clear_lobby()
	
	_clear_current_lobby_data()
	
	_set_network_state(NETWORK_STATE.IDLE)
	_emit_debug_message(message)
	
	lobby_join_failed.emit(message)


func _reject_lobby_creation(message:String) -> bool:
	_emit_debug_message("Lobby creation rejected: %s" % message)
	lobby_creation_failed.emit(message)
	return false


func _clear_current_lobby_data() -> void:
	current_lobby_id = INVALID_LOBBY_ID
	current_lobby_owner_steam_id = INVALID_STEAM_ID
	current_lobby_maximum_members = DEFAULT_MAXIMUM_MEMBERS
	
	current_lobby_name = ""
	current_lobby_description = ""
	current_lobby_access = LOBBY_ACCESS.PUBLIC
	current_lobby_password = ""


func _clear_pending_lobby_creation_data() -> void:
	pending_lobby_name = ""
	pending_lobby_description = ""
	pending_lobby_access = LOBBY_ACCESS.PUBLIC
	pending_lobby_password = ""
	pending_lobby_maximum_members = DEFAULT_MAXIMUM_MEMBERS


func _set_network_state(new_state:NETWORK_STATE) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	
	_emit_debug_message("Network state changed to: %s" % get_network_state_display_name())
	network_state_changed.emit(current_state)


func _emit_debug_message(message:String) -> void:
	DebugOverlay.log_message("SteamNetwork", message)
	debug_message_requested.emit(message)


func _on_steam_lobby_match_list(lobbies:Array) -> void:
	if current_state != NETWORK_STATE.SEARCHING_LOBBIES:
		_emit_debug_message("Ignoring an unexpected Steam lobby-list callback.")
		return
	
	active_lobby_search_request_id = 0
	
	var filtered_results:Array[Dictionary] = []
	
	for lobby_value in lobbies:
		var lobby_id:int = int(lobby_value)
		var lobby_result:Dictionary = _create_lobby_search_result(lobby_id)
		
		if lobby_result.is_empty():
			continue
		
		filtered_results.append(lobby_result)
	
	filtered_results.sort_custom(_sort_lobby_search_results)
	last_lobby_search_results = filtered_results
	
	_set_network_state(NETWORK_STATE.IDLE)
	
	_emit_debug_message("Lobby search completed.")
	_emit_debug_message("Steam returned %d lobby IDs." % lobbies.size())
	_emit_debug_message("Accepted %d compatible lobbies." % last_lobby_search_results.size())
	
	for lobby_result in last_lobby_search_results:
		_print_lobby_search_result(lobby_result)
	
	lobby_search_completed.emit(get_last_lobby_search_results())


func _create_lobby_search_result(lobby_id:int) -> Dictionary:
	if lobby_id <= INVALID_LOBBY_ID:
		return {}
	
	var game_key:String = Steam.getLobbyData(lobby_id, METADATA_GAME_KEY)
	
	if game_key != GAME_KEY:
		return {}
	
	var protocol_version:int = _get_lobby_metadata_int(lobby_id, METADATA_PROTOCOL_VERSION, -1)
	
	if protocol_version != PROTOCOL_VERSION:
		return {}
	
	var build_version:String = Steam.getLobbyData(lobby_id, METADATA_BUILD_VERSION)
	
	if build_version != get_build_version():
		return {}
	
	var lobby_name:String = Steam.getLobbyData(lobby_id, METADATA_LOBBY_NAME).strip_edges()
	
	if lobby_name == "":
		return {}
	
	var access_type:String = Steam.getLobbyData(lobby_id, METADATA_ACCESS_TYPE).strip_edges().to_lower()
	
	if access_type != "public" and access_type != "password_protected":
		return {}
	
	var description:String = Steam.getLobbyData(lobby_id, METADATA_DESCRIPTION)
	var lobby_phase:String = Steam.getLobbyData(lobby_id, METADATA_LOBBY_PHASE).strip_edges().to_lower()
	var host_name:String = Steam.getLobbyData(lobby_id, METADATA_HOST_NAME).strip_edges()
	var has_password:bool = Steam.getLobbyData(lobby_id, METADATA_HAS_PASSWORD) == "1"
	
	var member_count:int = max(Steam.getNumLobbyMembers(lobby_id), 0)
	var member_limit:int = max(Steam.getLobbyMemberLimit(lobby_id), 0)
	var active_player_count:int = max(_get_lobby_metadata_int(lobby_id, METADATA_ACTIVE_PLAYER_COUNT, 0), 0)
	var maximum_players:int = max(_get_lobby_metadata_int(lobby_id, METADATA_MAXIMUM_PLAYERS, MatchConfig.MAXIMUM_PLAYERS), 1)
	var spectator_count:int = max(member_count - active_player_count, 0)
	
	var starting_token_points:int = max(_get_lobby_metadata_int(lobby_id, METADATA_STARTING_TOKEN_POINTS, 10), 0)
	var board_columns:int = _get_lobby_metadata_int(lobby_id, METADATA_BOARD_COLUMNS, 7)
	var board_rows:int = _get_lobby_metadata_int(lobby_id, METADATA_BOARD_ROWS, 6)
	var tokens_to_win:int = _get_lobby_metadata_int(lobby_id, METADATA_TOKENS_TO_WIN, 4)
	var turn_timer_seconds:int = _get_lobby_metadata_int(lobby_id, METADATA_TURN_TIMER_SECONDS, 0)
	
	var is_full:bool = false
	
	if member_limit > 0:
		is_full = member_count >= member_limit
	
	return {
		RESULT_LOBBY_ID: lobby_id,
		RESULT_LOBBY_NAME: lobby_name,
		RESULT_DESCRIPTION: description,
		RESULT_ACCESS_TYPE: access_type,
		RESULT_HAS_PASSWORD: has_password,
		RESULT_LOBBY_PHASE: lobby_phase,
		RESULT_MEMBER_COUNT: member_count,
		RESULT_MEMBER_LIMIT: member_limit,
		RESULT_ACTIVE_PLAYER_COUNT: active_player_count,
		RESULT_MAXIMUM_PLAYERS: maximum_players,
		RESULT_SPECTATOR_COUNT: spectator_count,
		RESULT_HOST_NAME: host_name,
		RESULT_STARTING_TOKEN_POINTS: starting_token_points,
		RESULT_BOARD_COLUMNS: board_columns,
		RESULT_BOARD_ROWS: board_rows,
		RESULT_TOKENS_TO_WIN: tokens_to_win,
		RESULT_TURN_TIMER_SECONDS: turn_timer_seconds,
		RESULT_IS_FULL: is_full,
		RESULT_IS_MATCH_IN_PROGRESS: lobby_phase == "match_in_progress"
	}


func get_last_lobby_search_results() -> Array[Dictionary]:
	var copied_results:Array[Dictionary] = []
	
	for lobby_result in last_lobby_search_results:
		copied_results.append(lobby_result.duplicate(true))
	
	return copied_results


func _get_lobby_metadata_int(lobby_id:int, key:String, default_value:int) -> int:
	var raw_value:String = Steam.getLobbyData(lobby_id, key).strip_edges()
	
	if raw_value.is_valid_int() == false:
		return default_value
	
	return raw_value.to_int()


func _sort_lobby_search_results(first_result:Dictionary, second_result:Dictionary) -> bool:
	var first_phase:String = str(first_result.get(RESULT_LOBBY_PHASE, ""))
	var second_phase:String = str(second_result.get(RESULT_LOBBY_PHASE, ""))
	
	if first_phase != second_phase:
		if first_phase == "token_selection":
			return true
		
		if second_phase == "token_selection":
			return false
	
	var first_name:String = str(first_result.get(RESULT_LOBBY_NAME, ""))
	var second_name:String = str(second_result.get(RESULT_LOBBY_NAME, ""))
	var comparison:int = first_name.naturalnocasecmp_to(second_name)
	return comparison < 0


func _print_lobby_search_result(lobby_result:Dictionary) -> void:
	var lobby_id:int = int(lobby_result.get(RESULT_LOBBY_ID, INVALID_LOBBY_ID))
	var lobby_name:String = str(lobby_result.get(RESULT_LOBBY_NAME, "Unnamed Lobby"))
	var active_players:int = int(lobby_result.get(RESULT_ACTIVE_PLAYER_COUNT, 0))
	var maximum_players:int = int(lobby_result.get(RESULT_MAXIMUM_PLAYERS, MatchConfig.MAXIMUM_PLAYERS))
	var spectators:int = int(lobby_result.get(RESULT_SPECTATOR_COUNT, 0))
	var lobby_phase:String = str(lobby_result.get(RESULT_LOBBY_PHASE, "none"))
	var has_password:bool = bool(lobby_result.get(RESULT_HAS_PASSWORD, false))
	
	_emit_debug_message(
		"Lobby result: %s | ID %d | Players %d/%d | Spectators %d | Phase %s | Password %s" %
		[lobby_name, lobby_id, active_players, maximum_players, spectators, lobby_phase, str(has_password)]
	)


func _on_lobby_search_timeout(request_id:int) -> void:
	if current_state != NETWORK_STATE.SEARCHING_LOBBIES:
		return
	
	if request_id != active_lobby_search_request_id:
		return
	
	active_lobby_search_request_id = 0
	last_lobby_search_results.clear()
	
	_set_network_state(NETWORK_STATE.IDLE)
	
	var message:String = "The Steam lobby search timed out."
	_emit_debug_message(message)
	lobby_search_failed.emit(message)


func _reject_lobby_search(message:String) -> bool:
	_emit_debug_message("Lobby search rejected: %s" % message)
	lobby_search_failed.emit(message)
	return false
