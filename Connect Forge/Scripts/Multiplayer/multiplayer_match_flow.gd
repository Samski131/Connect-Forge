extends Node

const SERVER_PEER_ID:int = 1
const TOKEN_LOBBY_SCENE_PATH:String = "res://Scenes/User Interface/Token Lobby/token_lobby.tscn"

var return_in_progress:bool = false
var match_player_info_by_peer_id:Dictionary = {}
var match_player_config_by_player_id:Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_multiplayer_authority(SERVER_PEER_ID)
	connect_signals()
	
	if LobbyData.is_match_in_progress():
		cache_match_player_roster()


func connect_signals() -> void:
	if LobbyData.lobby_phase_changed.is_connected(_on_lobby_phase_changed) == false:
		LobbyData.lobby_phase_changed.connect(_on_lobby_phase_changed)
	
	if SteamNetwork.peer_disconnected.is_connected(_on_peer_disconnected) == false:
		SteamNetwork.peer_disconnected.connect(_on_peer_disconnected)


func request_return_to_lobby(reason:String = "") -> bool:
	if return_in_progress:
		return false
	
	if SteamNetwork.is_in_lobby() == false or LobbyData.has_active_lobby() == false:
		return _return_local_game_to_lobby(reason)
	
	return_in_progress = true
	
	if SteamNetwork.is_host():
		_begin_host_return_to_lobby(reason)
		return true
	
	if SteamNetwork.is_client() == false:
		return_in_progress = false
		return false
	
	DebugOverlay.log_message("MultiplayerMatchFlow", "Requesting that the host return everyone to the token lobby.")
	rpc_id(SERVER_PEER_ID, "request_network_return_to_lobby", reason)
	return true


@rpc("any_peer", "call_remote", "reliable")
func request_network_return_to_lobby(reason:String = "") -> void:
	if multiplayer.is_server() == false:
		return
	
	if SteamNetwork.is_host() == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	var sender_member:LobbyMemberData = LobbyData.get_member_by_peer_id(sender_peer_id)
	
	if sender_member == null:
		DebugOverlay.log_warning("MultiplayerMatchFlow", "Ignored a return-to-lobby request from unknown peer %d." % sender_peer_id)
		return
	
	DebugOverlay.log_message("MultiplayerMatchFlow", "%s requested a return to the token lobby." % sender_member.display_name)
	_begin_host_return_to_lobby(reason)


func _begin_host_return_to_lobby(reason:String = "") -> void:
	if SteamNetwork.is_host() == false:
		return_in_progress = false
		return
	
	if multiplayer.is_server() == false:
		return_in_progress = false
		return
	
	if LobbyData.has_active_lobby() == false:
		return_in_progress = false
		return
	
	return_in_progress = true
	
	_reset_all_player_ready_states()
	LobbyData.set_lobby_phase(LobbyData.LOBBY_PHASE.RETURNING_TO_LOBBY)
	compact_lobby_players_for_token_selection()
	SteamNetwork.refresh_host_lobby_metadata()
	
	var snapshot:Dictionary = LobbyData.create_snapshot()
	var used_reason:String = reason.strip_edges()
	
	if used_reason == "":
		used_reason = "Return to lobby requested."
	
	DebugOverlay.log_message("MultiplayerMatchFlow", "Host is returning all connected players to the token lobby. %s" % used_reason)
	LobbyAdmission.broadcast_current_snapshot()
	rpc("apply_network_return_to_lobby", snapshot, used_reason)


@rpc("authority", "call_local", "reliable")
func apply_network_return_to_lobby(snapshot:Dictionary, reason:String = "") -> void:
	return_in_progress = true
	
	if snapshot.is_empty() == false:
		if LobbyData.apply_snapshot(snapshot) == false:
			DebugOverlay.log_warning("MultiplayerMatchFlow", "The pre-return lobby snapshot could not be applied locally. The token lobby will request fresh state after loading.")
	
	MatchData.clear_session()
	get_tree().paused = false
	
	var change_error:Error = get_tree().change_scene_to_file(TOKEN_LOBBY_SCENE_PATH)
	
	if change_error != OK:
		DebugOverlay.log_error("MultiplayerMatchFlow", "Could not open the token lobby. Error code: %d." % int(change_error))
		return_in_progress = false
		return
	
	DebugOverlay.log_message("MultiplayerMatchFlow", "Return to token lobby accepted. %s" % reason)
	_finish_return_after_scene_change()


func _finish_return_after_scene_change() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	if SteamNetwork.is_host() and multiplayer.is_server() and LobbyData.has_active_lobby():
		LobbyData.set_lobby_phase(LobbyData.LOBBY_PHASE.TOKEN_SELECTION)
		SteamNetwork.refresh_host_lobby_metadata()
		LobbyAdmission.broadcast_current_snapshot()
		DebugOverlay.log_message("MultiplayerMatchFlow", "Host completed the return to token selection and broadcast the refreshed lobby roster.")
	
	match_player_info_by_peer_id.clear()
	match_player_config_by_player_id.clear()
	return_in_progress = false


func _reset_all_player_ready_states() -> void:
	if SteamNetwork.is_host() == false:
		return
	
	for member in LobbyData.get_players():
		if member == null:
			continue
		
		if member.is_ready == false:
			continue
		
		if member.set_ready(false) == false:
			DebugOverlay.log_warning("MultiplayerMatchFlow", "Could not clear ready state for %s." % member.display_name)
			continue
		
		if LobbyData.update_member(member) == false:
			DebugOverlay.log_warning("MultiplayerMatchFlow", "Could not store cleared ready state for %s." % member.display_name)


func compact_lobby_players_for_token_selection() -> void:
	if SteamNetwork.is_host() == false:
		return
	
	var players:Array[LobbyMemberData] = LobbyData.get_players()
	var player_config_snapshots:Array[Dictionary] = []
	
	for member in players:
		var player_snapshot:Dictionary = {
			"player_name": member.display_name,
			"colour_palette": member.get_colour_palette(),
			"token_points_remaining": 0,
			"selected_tokens": {}
		}
		
		if match_player_config_by_player_id.has(member.player_slot):
			var cached_snapshot:Dictionary = match_player_config_by_player_id[member.player_slot]
			player_snapshot = cached_snapshot.duplicate(true)
		elif MatchData.config != null:
			var source_player:MatchPlayerData = MatchData.config.get_player(member.player_slot)
			
			if source_player != null:
				player_snapshot["player_name"] = source_player.player_name
				player_snapshot["colour_palette"] = source_player.colour_palette
				player_snapshot["token_points_remaining"] = source_player.token_points_remaining
				player_snapshot["selected_tokens"] = source_player.selected_tokens.duplicate(true)
		
		player_config_snapshots.append(player_snapshot)
	
	for new_player_slot in range(players.size()):
		var member:LobbyMemberData = players[new_player_slot]
		
		if member.player_slot != new_player_slot:
			member.assign_player_slot(new_player_slot)
			LobbyData.update_member(member)
	
	if MatchData.config == null:
		return
	
	var target_config_count:int = max(players.size(), MatchConfig.MINIMUM_PLAYERS)
	MatchData.set_player_count(target_config_count)
	
	for new_player_slot in range(players.size()):
		var target_player:MatchPlayerData = MatchData.config.get_player(new_player_slot)
		
		if target_player == null:
			continue
		
		var player_snapshot:Dictionary = player_config_snapshots[new_player_slot]
		var player_name:String = str(player_snapshot.get("player_name", "Player " + str(new_player_slot + 1)))
		var palette:ColorPalette = player_snapshot.get("colour_palette", null) as ColorPalette
		var token_points_remaining:int = int(player_snapshot.get("token_points_remaining", MatchData.config.starting_token_points))
		var selected_tokens:Dictionary = player_snapshot.get("selected_tokens", {})
		
		MatchData.config.set_player_name(new_player_slot, player_name)
		
		if palette != null:
			MatchData.config.set_player_palette(new_player_slot, palette)
		
		target_player.token_points_remaining = token_points_remaining
		target_player.selected_tokens = selected_tokens.duplicate(true)
	
	DebugOverlay.log_message("MultiplayerMatchFlow", "Compacted the token-lobby player slots to %d connected players." % players.size())


func cache_match_player_roster() -> void:
	match_player_info_by_peer_id.clear()
	match_player_config_by_player_id.clear()
	
	for member in LobbyData.get_players():
		if member == null:
			continue
		
		if member.has_player_slot() == false:
			continue
		
		if member.peer_id > LobbyData.INVALID_PEER_ID:
			match_player_info_by_peer_id[member.peer_id] = {
				"player_id": member.player_slot,
				"display_name": member.display_name
			}
		
		var player_snapshot:Dictionary = {
			"player_name": member.display_name,
			"colour_palette": member.get_colour_palette(),
			"token_points_remaining": 0,
			"selected_tokens": {}
		}
		
		if MatchData.config != null:
			var source_player:MatchPlayerData = MatchData.config.get_player(member.player_slot)
			
			if source_player != null:
				player_snapshot["player_name"] = source_player.player_name
				player_snapshot["colour_palette"] = source_player.colour_palette
				player_snapshot["token_points_remaining"] = source_player.token_points_remaining
				player_snapshot["selected_tokens"] = source_player.selected_tokens.duplicate(true)
		
		match_player_config_by_player_id[member.player_slot] = player_snapshot
	
	DebugOverlay.log_message("MultiplayerMatchFlow", "Cached %d match player peer mappings." % match_player_info_by_peer_id.size())


func _on_lobby_phase_changed(new_phase:int) -> void:
	if new_phase == LobbyData.LOBBY_PHASE.MATCH_IN_PROGRESS:
		cache_match_player_roster()
		return
	
	if new_phase == LobbyData.LOBBY_PHASE.TOKEN_SELECTION:
		match_player_info_by_peer_id.clear()
		match_player_config_by_player_id.clear()
		return
	
	if new_phase == LobbyData.LOBBY_PHASE.NONE or new_phase == LobbyData.LOBBY_PHASE.CLOSED:
		match_player_info_by_peer_id.clear()
		match_player_config_by_player_id.clear()


func _on_peer_disconnected(peer_id:int) -> void:
	if SteamNetwork.is_host() == false:
		return
	
	if LobbyData.is_match_in_progress() == false:
		return
	
	if match_player_info_by_peer_id.has(peer_id) == false:
		return
	
	var player_info:Dictionary = match_player_info_by_peer_id[peer_id]
	match_player_info_by_peer_id.erase(peer_id)
	
	var player_id:int = int(player_info.get("player_id", -1))
	var display_name:String = str(player_info.get("display_name", "Player " + str(player_id + 1)))
	var game_manager:GameManager = get_current_game_manager()
	
	if game_manager == null:
		DebugOverlay.log_warning("MultiplayerMatchFlow", "Could not find the active GameManager after peer %d disconnected." % peer_id)
		return
	
	if game_manager.session == null:
		return
	
	if game_manager.session.is_player_active(player_id) == false:
		return
	
	var disconnected_player_was_current:bool = game_manager.get_current_player_id() == player_id
	
	if game_manager.session.deactivate_player(player_id) == false:
		return
	
	game_manager.clear_remote_drag_preview()
	rpc("apply_network_player_deactivated", player_id, display_name)
	
	DebugOverlay.log_message("MultiplayerMatchFlow", "%s disconnected during the match. Player slot %d is now inactive." % [display_name, player_id])
	
	if game_manager.session.get_active_player_count() < MatchConfig.MINIMUM_PLAYERS:
		game_manager.set_current_turn_phase(Global.TURN_PHASE.NONE)
		game_manager.stop_turn_timer()
		
		if game_manager.token_drag_controller != null:
			game_manager.token_drag_controller.cancel_drag()
		
		call_deferred("return_after_insufficient_players", display_name)
		return
	
	if disconnected_player_was_current:
		handle_disconnected_current_player(game_manager)


@rpc("authority", "call_remote", "reliable")
func apply_network_player_deactivated(player_id:int, display_name:String) -> void:
	var game_manager:GameManager = get_current_game_manager()
	
	if game_manager == null:
		return
	
	if game_manager.session == null:
		return
	
	if game_manager.session.is_player_active(player_id) == false:
		return
	
	if game_manager.session.deactivate_player(player_id) == false:
		return
	
	game_manager.clear_remote_drag_preview()
	DebugOverlay.log_message("MultiplayerMatchFlow", "%s left the match. Removed player slot %d from the active roster." % [display_name, player_id])


func handle_disconnected_current_player(game_manager:GameManager) -> void:
	if game_manager == null:
		return
	
	if game_manager.get_current_turn_phase() != Global.TURN_PHASE.PLACEMENT:
		return
	
	if game_manager.network_match_controller != null:
		if game_manager.network_match_controller.move_in_progress:
			return
	
	game_manager.set_current_turn_phase(Global.TURN_PHASE.NONE)
	game_manager.stop_turn_timer()
	game_manager.clear_remote_drag_preview()
	game_manager.advance_to_next_turn()
	
	if game_manager.network_match_controller != null:
		game_manager.network_match_controller.broadcast_authoritative_turn_state()


func return_after_insufficient_players(disconnected_player_name:String) -> void:
	if SteamNetwork.is_host() == false:
		return
	
	if LobbyData.is_match_in_progress() == false:
		return
	
	var reason:String = "%s disconnected, leaving fewer than two active players." % disconnected_player_name
	request_return_to_lobby(reason)


func get_current_game_manager() -> GameManager:
	var current_scene:Node = get_tree().current_scene
	
	if current_scene == null:
		return null
	
	return find_game_manager_recursive(current_scene)


func find_game_manager_recursive(node:Node) -> GameManager:
	if node == null:
		return null
	
	var game_manager:GameManager = node as GameManager
	
	if game_manager != null:
		return game_manager
	
	for child in node.get_children():
		var found_game_manager:GameManager = find_game_manager_recursive(child)
		
		if found_game_manager != null:
			return found_game_manager
	
	return null


func _return_local_game_to_lobby(reason:String = "") -> bool:
	return_in_progress = true
	MatchData.clear_session()
	get_tree().paused = false
	
	var change_error:Error = get_tree().change_scene_to_file(TOKEN_LOBBY_SCENE_PATH)
	
	if change_error != OK:
		DebugOverlay.log_error("MultiplayerMatchFlow", "Could not return the local game to the token lobby. Error code: %d." % int(change_error))
		return_in_progress = false
		return false
	
	if reason.strip_edges() != "":
		DebugOverlay.log_message("MultiplayerMatchFlow", "Returning local game to the token lobby. %s" % reason)
	
	_finish_return_after_scene_change()
	return true
