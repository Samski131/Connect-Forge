extends Node

signal remote_cursor_position_received(player_id:int, normalised_position:Vector2)
signal remote_cursor_presence_received(player_id:int, is_present:bool)

const SERVER_PEER_ID:int = 1


func is_active() -> bool:
	if LobbyData.has_active_lobby() == false:
		return false
	
	if LobbyData.get_local_member() == null:
		return false
	
	return true


func is_local_host() -> bool:
	if is_active() == false:
		return false
	
	if LobbyData.is_local_host() == false:
		return false
	
	if multiplayer.is_server() == false:
		return false
	
	return true


func get_local_player_id() -> int:
	var local_member:LobbyMemberData = LobbyData.get_local_member()
	
	if local_member == null:
		return LobbyData.INVALID_PLAYER_SLOT
	
	if local_member.is_player() == false:
		return LobbyData.INVALID_PLAYER_SLOT
	
	if local_member.has_player_slot() == false:
		return LobbyData.INVALID_PLAYER_SLOT
	
	return local_member.player_slot


func send_local_cursor_position(normalised_position:Vector2) -> void:
	if is_active() == false:
		return
	
	var local_player_id:int = get_local_player_id()
	
	if local_player_id < 0:
		return
	
	var used_position:Vector2 = clamp_normalised_cursor_position(normalised_position)
	
	if is_local_host():
		rpc("receive_authoritative_cursor_position", local_player_id, used_position)
		return
	
	rpc_id(SERVER_PEER_ID, "request_cursor_position", used_position)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func request_cursor_position(normalised_position:Vector2) -> void:
	if multiplayer.is_server() == false:
		return
	
	if LobbyData.is_local_host() == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	var sender_member:LobbyMemberData = LobbyData.get_member_by_peer_id(sender_peer_id)
	
	if is_valid_cursor_member(sender_member) == false:
		return
	
	var used_position:Vector2 = clamp_normalised_cursor_position(normalised_position)
	
	remote_cursor_position_received.emit(sender_member.player_slot, used_position)
	rpc("receive_authoritative_cursor_position", sender_member.player_slot, used_position)


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_authoritative_cursor_position(player_id:int, normalised_position:Vector2) -> void:
	if is_active() == false:
		return
	
	if is_valid_player_slot(player_id) == false:
		return
	
	if player_id == get_local_player_id():
		return
	
	var used_position:Vector2 = clamp_normalised_cursor_position(normalised_position)
	remote_cursor_position_received.emit(player_id, used_position)


func send_local_cursor_presence(is_present:bool) -> void:
	if is_active() == false:
		return
	
	var local_player_id:int = get_local_player_id()
	
	if local_player_id < 0:
		return
	
	if is_local_host():
		rpc("receive_authoritative_cursor_presence", local_player_id, is_present)
		return
	
	rpc_id(SERVER_PEER_ID, "request_cursor_presence", is_present)


@rpc("any_peer", "call_remote", "reliable")
func request_cursor_presence(is_present:bool) -> void:
	if multiplayer.is_server() == false:
		return
	
	if LobbyData.is_local_host() == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	var sender_member:LobbyMemberData = LobbyData.get_member_by_peer_id(sender_peer_id)
	
	if is_valid_cursor_member(sender_member) == false:
		return
	
	remote_cursor_presence_received.emit(sender_member.player_slot, is_present)
	rpc("receive_authoritative_cursor_presence", sender_member.player_slot, is_present)


@rpc("authority", "call_remote", "reliable")
func receive_authoritative_cursor_presence(player_id:int, is_present:bool) -> void:
	if is_active() == false:
		return
	
	if is_valid_player_slot(player_id) == false:
		return
	
	if player_id == get_local_player_id():
		return
	
	remote_cursor_presence_received.emit(player_id, is_present)


func is_valid_cursor_member(member:LobbyMemberData) -> bool:
	if member == null:
		return false
	
	if member.is_player() == false:
		return false
	
	if member.has_player_slot() == false:
		return false
	
	return is_valid_player_slot(member.player_slot)


func is_valid_player_slot(player_id:int) -> bool:
	if player_id < 0:
		return false
	
	var member:LobbyMemberData = LobbyData.get_member_at_player_slot(player_id)
	
	if member == null:
		return false
	
	if member.is_player() == false:
		return false
	
	if member.player_slot != player_id:
		return false
	
	return true


func clamp_normalised_cursor_position(normalised_position:Vector2) -> Vector2:
	return Vector2(clamp(normalised_position.x, 0.0, 1.0), clamp(normalised_position.y, 0.0, 1.0))
