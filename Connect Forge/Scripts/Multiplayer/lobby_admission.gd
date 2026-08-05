extends Node

signal admission_started(lobby_id:int)
signal admission_succeeded(lobby_id:int, assigned_role:int, player_slot:int)
signal admission_failed(message:String)

const SERVER_PEER_ID:int = 1
const ADMISSION_TIMEOUT_SECONDS:float = 30.0

var join_is_pending:bool = false
var admission_request_sent:bool = false

var pending_lobby_id:int = SteamNetwork.INVALID_LOBBY_ID
var pending_password:String = ""
var pending_requested_role:LobbyMemberData.MEMBER_ROLE = LobbyMemberData.MEMBER_ROLE.PLAYER

var active_request_id:int = 0
var next_request_id:int = 1


func _ready() -> void:
	connect_signals()


func connect_signals() -> void:
	if SteamNetwork.multiplayer_connection_ready.is_connected(_on_multiplayer_connection_ready) == false:
		SteamNetwork.multiplayer_connection_ready.connect(_on_multiplayer_connection_ready)
	
	if SteamNetwork.lobby_join_failed.is_connected(_on_steam_lobby_join_failed) == false:
		SteamNetwork.lobby_join_failed.connect(_on_steam_lobby_join_failed)
	
	if SteamNetwork.lobby_left.is_connected(_on_lobby_left) == false:
		SteamNetwork.lobby_left.connect(_on_lobby_left)
	
	if SteamNetwork.peer_disconnected.is_connected(_on_peer_disconnected) == false:
		SteamNetwork.peer_disconnected.connect(_on_peer_disconnected)
	
	if SteamNetwork.host_disconnected.is_connected(_on_host_disconnected) == false:
		SteamNetwork.host_disconnected.connect(_on_host_disconnected)


func start_join(lobby_id:int, password:String, requested_role:int) -> bool:
	if join_is_pending:
		return false
	
	if lobby_id <= SteamNetwork.INVALID_LOBBY_ID:
		admission_failed.emit("The selected lobby is unavailable.")
		return false
	
	if SteamNetwork.is_steam_initialised() == false:
		admission_failed.emit("Steam is not available.")
		return false
	
	if SteamNetwork.get_network_state() != SteamNetwork.NETWORK_STATE.IDLE:
		admission_failed.emit("The network is currently busy.")
		return false
	
	join_is_pending = true
	admission_request_sent = false
	pending_lobby_id = lobby_id
	pending_password = password
	pending_requested_role = LobbyMemberData.get_valid_role(requested_role)
	
	active_request_id = next_request_id
	next_request_id += 1
	
	DebugOverlay.log_message("LobbyAdmission", "Starting admission for lobby %d." % pending_lobby_id)
	admission_started.emit(pending_lobby_id)
	
	var join_started:bool = SteamNetwork.join_lobby(pending_lobby_id)
	
	if join_started == false:
		if join_is_pending:
			fail_pending_join("The Steam lobby join could not be started.", false)
		
		return false
	
	var timeout_timer:SceneTreeTimer = get_tree().create_timer(ADMISSION_TIMEOUT_SECONDS)
	timeout_timer.timeout.connect(_on_admission_timeout.bind(active_request_id), CONNECT_ONE_SHOT)
	return true


func is_join_pending() -> bool:
	return join_is_pending


func cancel_pending_join(reason:String = "The lobby join was cancelled.") -> void:
	if join_is_pending == false:
		return
	
	fail_pending_join(reason, true)


func _on_multiplayer_connection_ready() -> void:
	if join_is_pending == false:
		return
	
	if admission_request_sent:
		return
	
	if SteamNetwork.is_client() == false:
		return
	
	if SteamNetwork.get_lobby_id() != pending_lobby_id:
		fail_pending_join("Steam connected to an unexpected lobby.", true)
		return
	
	admission_request_sent = true
	
	DebugOverlay.log_message("LobbyAdmission", "Connected to the host. Sending the admission request.")
	
	rpc_id(SERVER_PEER_ID, "request_lobby_admission", SteamNetwork.get_local_steam_id(), SteamNetwork.get_local_persona_name(), pending_password, int(pending_requested_role), SteamNetwork.PROTOCOL_VERSION, SteamNetwork.get_build_version())


@rpc("any_peer", "call_remote", "reliable")
func request_lobby_admission(steam_id:int, display_name:String, password_attempt:String, requested_role:int, protocol_version:int, build_version:String) -> void:
	if multiplayer.is_server() == false:
		return
	
	if SteamNetwork.is_host() == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	
	if sender_peer_id <= SERVER_PEER_ID:
		return
	
	if protocol_version != SteamNetwork.PROTOCOL_VERSION:
		reject_remote_admission(sender_peer_id, "This lobby uses a different multiplayer protocol version.")
		return
	
	if build_version != SteamNetwork.get_build_version():
		reject_remote_admission(sender_peer_id, "This lobby uses a different game build.")
		return
	
	if LobbyData.has_active_lobby() == false:
		reject_remote_admission(sender_peer_id, "The host no longer has an active lobby.")
		return
	
	if LobbyData.get_lobby_phase() == LobbyData.LOBBY_PHASE.CLOSED:
		reject_remote_admission(sender_peer_id, "The lobby is closed.")
		return
	
	if steam_id <= SteamNetwork.INVALID_STEAM_ID:
		reject_remote_admission(sender_peer_id, "Steam returned an invalid account ID.")
		return
	
	var used_display_name:String = display_name.strip_edges()
	
	if used_display_name == "":
		reject_remote_admission(sender_peer_id, "Steam returned an empty persona name.")
		return
	
	if LobbyData.has_member(steam_id):
		reject_remote_admission(sender_peer_id, "This Steam account is already in the lobby.")
		return
	
	if SteamNetwork.get_lobby_access() == SteamNetwork.LOBBY_ACCESS.PASSWORD_PROTECTED:
		if SteamNetwork.validate_lobby_password(password_attempt) == false:
			reject_remote_admission(sender_peer_id, "The lobby password was incorrect.")
			return
	
	var used_requested_role:LobbyMemberData.MEMBER_ROLE = LobbyMemberData.get_valid_role(requested_role)
	var assigned_role:LobbyMemberData.MEMBER_ROLE = LobbyMemberData.MEMBER_ROLE.SPECTATOR
	var assigned_player_slot:int = LobbyData.INVALID_PLAYER_SLOT
	
	if LobbyData.is_token_selection_phase():
		if used_requested_role == LobbyMemberData.MEMBER_ROLE.PLAYER:
			assigned_player_slot = LobbyData.get_first_available_player_slot()
			
			if assigned_player_slot != LobbyData.INVALID_PLAYER_SLOT:
				assigned_role = LobbyMemberData.MEMBER_ROLE.PLAYER
	
	var new_member:LobbyMemberData = LobbyMemberData.new()
	new_member.setup(steam_id, sender_peer_id, used_display_name, LobbyMemberData.MEMBER_ROLE.SPECTATOR, false)
	
	if assigned_role == LobbyMemberData.MEMBER_ROLE.PLAYER:
		if new_member.assign_player_slot(assigned_player_slot) == false:
			reject_remote_admission(sender_peer_id, "The requested player slot could not be assigned.")
			return
		
		var palette:ColorPalette = MatchData.get_default_palette_for_player(assigned_player_slot)
		
		if palette != null:
			new_member.set_colour_palette(palette)
	else:
		new_member.make_spectator()
	
	if LobbyData.add_member(new_member) == false:
		reject_remote_admission(sender_peer_id, "The host could not add this member to the lobby.")
		return
	
	sync_match_config_from_lobby()
	SteamNetwork.refresh_host_lobby_metadata()
	
	var snapshot:Dictionary = LobbyData.create_snapshot()
	
	DebugOverlay.log_message("LobbyAdmission", "Approved %s as %s. Peer %d, Steam ID %d, player slot %d." % [used_display_name, new_member.get_role_display_name(), sender_peer_id, steam_id, new_member.player_slot])
	
	rpc_id(sender_peer_id, "receive_lobby_admission_result", true, "", snapshot)
	rpc("receive_lobby_snapshot", snapshot)


func reject_remote_admission(peer_id:int, message:String) -> void:
	DebugOverlay.log_warning("LobbyAdmission", "Rejected peer %d: %s" % [peer_id, message])
	rpc_id(peer_id, "receive_lobby_admission_result", false, message, {})


@rpc("authority", "call_remote", "reliable")
func receive_lobby_admission_result(was_accepted:bool, message:String, snapshot:Dictionary) -> void:
	if join_is_pending == false:
		return
	
	if was_accepted == false:
		var used_message:String = message.strip_edges()
		
		if used_message == "":
			used_message = "The host rejected the lobby join request."
		
		fail_pending_join(used_message, true)
		return
	
	if snapshot.is_empty():
		fail_pending_join("The host accepted the join but sent no lobby data.", true)
		return
	
	if LobbyData.apply_snapshot(snapshot) == false:
		fail_pending_join("The lobby member data received from the host was invalid.", true)
		return
	
	var local_member:LobbyMemberData = LobbyData.get_local_member()
	
	if local_member == null:
		fail_pending_join("The host response did not contain the local lobby member.", true)
		return
	
	var joined_lobby_id:int = pending_lobby_id
	var assigned_role:int = int(local_member.role)
	var player_slot:int = local_member.player_slot
	
	DebugOverlay.log_message("LobbyAdmission", "Admission approved as %s with player slot %d." % [local_member.get_role_display_name(), player_slot])
	
	clear_pending_join()
	admission_succeeded.emit(joined_lobby_id, assigned_role, player_slot)


@rpc("authority", "call_remote", "reliable")
func receive_lobby_snapshot(snapshot:Dictionary) -> void:
	if SteamNetwork.is_in_lobby() == false:
		return
	
	if snapshot.is_empty():
		return
	
	var snapshot_lobby_id:int = int(snapshot.get(LobbyData.KEY_LOBBY_ID, LobbyData.INVALID_LOBBY_ID))
	
	if snapshot_lobby_id != SteamNetwork.get_lobby_id():
		return
	
	if LobbyData.apply_snapshot(snapshot) == false:
		DebugOverlay.log_warning("LobbyAdmission", "Received an invalid lobby snapshot from the host.")
		return
	
	DebugOverlay.log_message("LobbyAdmission", "Applied a lobby snapshot containing %d members." % LobbyData.get_member_count())


func sync_match_config_from_lobby() -> void:
	if SteamNetwork.is_host() == false:
		return
	
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


func broadcast_current_snapshot() -> void:
	if SteamNetwork.is_host() == false:
		return
	
	if LobbyData.has_active_lobby() == false:
		return
	
	var snapshot:Dictionary = LobbyData.create_snapshot()
	rpc("receive_lobby_snapshot", snapshot)


func _on_peer_disconnected(_peer_id:int) -> void:
	if SteamNetwork.is_host() == false:
		return
	
	call_deferred("refresh_after_peer_disconnected")


func refresh_after_peer_disconnected() -> void:
	sync_match_config_from_lobby()
	SteamNetwork.refresh_host_lobby_metadata()
	broadcast_current_snapshot()


func _on_steam_lobby_join_failed(message:String) -> void:
	if join_is_pending == false:
		return
	
	fail_pending_join(message, false)


func _on_lobby_left(_lobby_id:int, reason:String) -> void:
	if join_is_pending == false:
		return
	
	var used_reason:String = reason.strip_edges()
	
	if used_reason == "":
		used_reason = "The lobby was left before admission completed."
	
	fail_pending_join(used_reason, false)


func _on_host_disconnected() -> void:
	if join_is_pending == false:
		return
	
	fail_pending_join("The host disconnected during admission.", false)


func _on_admission_timeout(request_id:int) -> void:
	if join_is_pending == false:
		return
	
	if request_id != active_request_id:
		return
	
	fail_pending_join("The lobby admission request timed out.", true)


func fail_pending_join(message:String, should_leave_lobby:bool) -> void:
	if join_is_pending == false:
		return
	
	var used_message:String = message.strip_edges()
	
	if used_message == "":
		used_message = "The lobby join failed."
	
	DebugOverlay.log_warning("LobbyAdmission", used_message)
	
	clear_pending_join()
	admission_failed.emit(used_message)
	
	if should_leave_lobby:
		SteamNetwork.leave_lobby(used_message)


func clear_pending_join() -> void:
	join_is_pending = false
	admission_request_sent = false
	pending_lobby_id = SteamNetwork.INVALID_LOBBY_ID
	pending_password = ""
	pending_requested_role = LobbyMemberData.MEMBER_ROLE.PLAYER
	active_request_id = 0
