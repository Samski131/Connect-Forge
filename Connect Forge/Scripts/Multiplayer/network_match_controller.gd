class_name NetworkMatchController
extends Node

const SERVER_PEER_ID:int = 1

const PLACEMENT_RESULT_VALID:String = "is_valid"
const PLACEMENT_RESULT_DATA:String = "data"

var game_manager:GameManager = null

var network_active:bool = false
var local_is_host:bool = false
var local_player_id:int = -1

var move_request_pending:bool = false
var move_in_progress:bool = false
var authoritative_revision:int = 0
var last_applied_revision:int = 0
var pending_turn_state:Dictionary = {}
var pending_state_checkpoint:Dictionary = {}
var last_verified_revision:int = 0
var active_drag_preview_id:int = -1
var active_drag_preview_player_id:int = -1
var active_drag_preview_token_type:int = -1

var applied_game_over_revision:int = -1
var applied_round_revision:int = -1
var waiting_for_authoritative_game_over:bool = false
var round_transition_in_progress:bool = false


func setup(new_game_manager:GameManager) -> void:
	game_manager = new_game_manager
	
	var local_member:LobbyMemberData = LobbyData.get_local_member()
	var has_lobby_data:bool = LobbyData.has_active_lobby()
	var has_local_member:bool = local_member != null
	
	network_active = has_lobby_data and has_local_member
	local_is_host = network_active and LobbyData.is_local_host() and multiplayer.is_server()
	
	local_player_id = -1
	move_request_pending = false
	move_in_progress = false
	authoritative_revision = 0
	last_applied_revision = 0
	pending_turn_state.clear()
	pending_state_checkpoint.clear()
	last_verified_revision = 0
	applied_game_over_revision = -1
	applied_round_revision = -1
	waiting_for_authoritative_game_over = false
	round_transition_in_progress = false
	
	active_drag_preview_id = -1
	active_drag_preview_player_id = -1
	active_drag_preview_token_type = -1
	
	if network_active == false:
		DebugOverlay.log_error("NetworkMatch", "Network gameplay was not activated. Steam state: %s. Lobby active: %s. Lobby phase: %s. Local member found: %s." % [SteamNetwork.get_network_state_display_name(), str(has_lobby_data), LobbyData.get_lobby_phase_display_name(), str(has_local_member)])
		return
	
	if LobbyData.is_match_in_progress() == false:
		DebugOverlay.log_warning("NetworkMatch", "The game scene opened before the local lobby phase changed to Match In Progress. Correcting the local phase.")
		LobbyData.set_lobby_phase(LobbyData.LOBBY_PHASE.MATCH_IN_PROGRESS)
	
	if local_member.is_player():
		local_player_id = local_member.player_slot
	
	var role_name:String = "Client"
	
	if local_is_host:
		role_name = "Host"
	
	DebugOverlay.log_message("NetworkMatch", "Network gameplay initialised as %s. Local player slot: %d. Peer ID: %d. Controller path: %s." % [role_name, local_player_id, multiplayer.get_unique_id(), str(get_path())])


func is_active() -> bool:
	return network_active


func is_host() -> bool:
	return local_is_host


func get_local_player_id() -> int:
	return local_player_id


func is_registered_token_type(token_type:int) -> bool:
	var token_data:Dictionary = TokenLibrary.get_token_data(token_type)
	
	if token_data.is_empty():
		return false
	
	return TokenLibrary.get_token_scene(token_type) != null


func can_local_player_drag_token(player_id:int, token_type:int) -> bool:
	if network_active == false:
		return true
	
	if move_request_pending:
		return false
	
	if move_in_progress:
		return false
	
	if round_transition_in_progress:
		return false
	
	if is_registered_token_type(token_type) == false:
		return false
	
	if player_id != local_player_id:
		return false
	
	if game_manager == null:
		return false
	
	if player_id != game_manager.get_current_player_id():
		return false
	
	return true


func request_local_token_placement(token_type:int, slot_pos:Vector2i, start_flipped:bool) -> bool:
	if network_active == false:
		return false
	
	if game_manager == null:
		return false
	
	if move_request_pending:
		return false
	
	if move_in_progress:
		return false
	
	if round_transition_in_progress:
		return false
	
	if is_registered_token_type(token_type) == false:
		DebugOverlay.log_warning("NetworkMatch", "The selected token is not registered correctly.")
		return false
	
	if local_player_id != game_manager.get_current_player_id():
		return false
	
	if game_manager.get_token_count(local_player_id, token_type) <= 0:
		return false
	
	if game_manager.is_valid_starting_slot(slot_pos) == false:
		return false
	
	move_request_pending = true
	
	if local_is_host:
		var local_member:LobbyMemberData = LobbyData.get_local_member()
		
		if local_member == null:
			move_request_pending = false
			return false
		
		process_token_placement_request(local_member.peer_id, token_type, slot_pos, start_flipped)
		return true
	
	rpc_id(SERVER_PEER_ID, "request_token_placement", token_type, slot_pos, start_flipped)
	DebugOverlay.log_message("NetworkMatch", "Requested %s placement at %s." % [TokenLibrary.get_display_name(token_type), str(slot_pos)])
	return true


@rpc("any_peer", "call_remote", "reliable")
func request_token_placement(token_type:int, slot_pos:Vector2i, start_flipped:bool) -> void:
	if local_is_host == false:
		return
	
	if multiplayer.is_server() == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	process_token_placement_request(sender_peer_id, token_type, slot_pos, start_flipped)


func process_token_placement_request(peer_id:int, token_type:int, slot_pos:Vector2i, start_flipped:bool) -> void:
	if local_is_host == false:
		return
	
	if game_manager == null:
		return
	
	if move_in_progress:
		reject_placement_request(peer_id, "Another placement is already being resolved.")
		return
	
	if round_transition_in_progress:
		reject_placement_request(peer_id, "The next round is still being prepared.")
		return
	
	if game_manager.get_current_turn_phase() != Global.TURN_PHASE.PLACEMENT:
		reject_placement_request(peer_id, "The match is not currently accepting placements.")
		return
	
	if is_registered_token_type(token_type) == false:
		reject_placement_request(peer_id, "The requested token is not registered correctly.")
		return
	
	var member:LobbyMemberData = LobbyData.get_member_by_peer_id(peer_id)
	
	if member == null:
		reject_placement_request(peer_id, "The placement request did not belong to a lobby member.")
		return
	
	if member.is_player() == false:
		reject_placement_request(peer_id, "Spectators cannot place tokens.")
		return
	
	if member.player_slot != game_manager.get_current_player_id():
		reject_placement_request(peer_id, "It is not that player's turn.")
		return
	
	if game_manager.get_token_count(member.player_slot, token_type) <= 0:
		reject_placement_request(peer_id, "That player has no %s tokens remaining." % TokenLibrary.get_display_name(token_type))
		return
	
	if game_manager.is_valid_starting_slot(slot_pos) == false:
		reject_placement_request(peer_id, "The requested starting slot is not valid.")
		return
	
	var used_start_flipped:bool = false
	
	if TokenLibrary.can_flip(token_type):
		used_start_flipped = start_flipped
	
	var placement_result:Dictionary = create_authoritative_placement_data(token_type, member.player_slot, slot_pos, used_start_flipped)
	var placement_data_is_valid:bool = bool(placement_result.get(PLACEMENT_RESULT_VALID, false))
	
	if placement_data_is_valid == false:
		reject_placement_request(peer_id, "The host could not create the token's authoritative placement data.")
		return
	
	var placement_data:Dictionary = placement_result.get(PLACEMENT_RESULT_DATA, {}) as Dictionary
	
	authoritative_revision += 1
	move_in_progress = true
	
	DebugOverlay.log_message("NetworkMatch", "Accepted move %d from %s: %s at %s, flipped %s." % [authoritative_revision, member.display_name, TokenLibrary.get_display_name(token_type), str(slot_pos), str(used_start_flipped)])
	rpc("apply_authoritative_token_placement", authoritative_revision, member.player_slot, token_type, slot_pos, used_start_flipped, placement_data)


func create_authoritative_placement_data(token_type:int, player_id:int, slot_pos:Vector2i, start_flipped:bool) -> Dictionary:
	var failed_result:Dictionary = {
		PLACEMENT_RESULT_VALID: false,
		PLACEMENT_RESULT_DATA: {}
	}
	
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return failed_result
	
	var temporary_node:Node = token_scene.instantiate()
	
	if temporary_node == null:
		return failed_result
	
	var temporary_token:Token = temporary_node as Token
	
	if temporary_token == null:
		temporary_node.free()
		return failed_result
	
	var context:Dictionary = {
		"game_manager": game_manager,
		"board": game_manager.board,
		"player_id": player_id,
		"player_count": game_manager.get_player_count(),
		"token_type": token_type,
		"slot_pos": slot_pos,
		"start_flipped": start_flipped
	}
	
	var placement_data:Dictionary = temporary_token.create_network_placement_data(context)
	var placement_data_is_required:bool = temporary_token.requires_network_placement_data()
	
	temporary_token.free()
	
	if placement_data_is_required and placement_data.is_empty():
		return failed_result
	
	return {
		PLACEMENT_RESULT_VALID: true,
		PLACEMENT_RESULT_DATA: placement_data.duplicate(true)
	}


func reject_placement_request(peer_id:int, message:String) -> void:
	DebugOverlay.log_warning("NetworkMatch", message)
	
	if peer_id == SERVER_PEER_ID:
		move_request_pending = false
		return
	
	rpc_id(peer_id, "receive_placement_rejected", message)


@rpc("authority", "call_remote", "reliable")
func receive_placement_rejected(message:String) -> void:
	move_request_pending = false
	DebugOverlay.log_warning("NetworkMatch", "The host rejected the placement: %s" % message)


@rpc("authority", "call_local", "reliable")
func apply_authoritative_token_placement(move_revision:int, player_id:int, token_type:int, slot_pos:Vector2i, start_flipped:bool, placement_data:Dictionary) -> void:
	if network_active == false:
		return
	
	if game_manager == null:
		return
	
	if move_revision <= last_applied_revision:
		return
	
	game_manager.clear_remote_drag_preview()
	
	last_applied_revision = move_revision
	authoritative_revision = max(authoritative_revision, move_revision)
	move_request_pending = false
	move_in_progress = true
	pending_turn_state.clear()
	pending_state_checkpoint.clear()
	game_manager.stop_turn_timer()
	
	var placed:bool = game_manager.reproduce_authoritative_token_placement(player_id, token_type, slot_pos, start_flipped, placement_data)
	
	if placed == false:
		move_in_progress = false
		DebugOverlay.log_error("NetworkMatch", "Move %d could not be reproduced locally." % move_revision)
		return
	
	DebugOverlay.log_message("NetworkMatch", "Applied move %d: %s for player slot %d." % [move_revision, TokenLibrary.get_display_name(token_type), player_id])


func create_network_snapshot_checksum(snapshot:Dictionary) -> String:
	var canonical_snapshot:Variant = canonicalize_network_snapshot_value(snapshot)
	var snapshot_json:String = JSON.stringify(canonical_snapshot)
	return snapshot_json.sha256_text()


func canonicalize_network_snapshot_value(value:Variant) -> Variant:
	var value_type:int = typeof(value)
	
	if value_type == TYPE_DICTIONARY:
		var dictionary_value:Dictionary = value
		var keys:Array = dictionary_value.keys()
		var canonical_entries:Array = []
		
		keys.sort_custom(sort_network_snapshot_keys)
		
		for key in keys:
			canonical_entries.append([str(key), canonicalize_network_snapshot_value(dictionary_value[key])])
		
		return ["dictionary", canonical_entries]
	
	if value_type == TYPE_ARRAY:
		var array_value:Array = value
		var canonical_array:Array = []
		
		for array_item in array_value:
			canonical_array.append(canonicalize_network_snapshot_value(array_item))
		
		return canonical_array
	
	return value


func sort_network_snapshot_keys(first_key:Variant, second_key:Variant) -> bool:
	return str(first_key) < str(second_key)


func verify_or_recover_authoritative_snapshot(authoritative_snapshot:Dictionary, expected_checksum:String, context_name:String) -> bool:
	if game_manager == null:
		return false
	
	if authoritative_snapshot.is_empty():
		DebugOverlay.log_error("NetworkMatch", "Received an empty authoritative snapshot for %s." % context_name)
		return false
	
	if expected_checksum == "":
		DebugOverlay.log_error("NetworkMatch", "Received an empty authoritative checksum for %s." % context_name)
		return false
	
	var received_checksum:String = create_network_snapshot_checksum(authoritative_snapshot)
	
	if received_checksum != expected_checksum:
		DebugOverlay.log_error("NetworkMatch", "The received %s snapshot did not match its transmitted checksum." % context_name)
		return false
	
	var local_snapshot:Dictionary = game_manager.create_network_match_snapshot()
	var local_checksum:String = create_network_snapshot_checksum(local_snapshot)
	
	if local_checksum == expected_checksum:
		DebugOverlay.log_message("NetworkMatch", "State verified for %s. Checksum %s." % [context_name, expected_checksum.left(12)])
		return true
	
	DebugOverlay.log_warning("NetworkMatch", "State mismatch detected for %s. Local %s, host %s. Applying host snapshot." % [context_name, local_checksum.left(12), expected_checksum.left(12)])
	
	if game_manager.apply_authoritative_network_match_snapshot(authoritative_snapshot) == false:
		DebugOverlay.log_error("NetworkMatch", "The host snapshot for %s could not be applied." % context_name)
		return false
	
	var recovered_snapshot:Dictionary = game_manager.create_network_match_snapshot()
	var recovered_checksum:String = create_network_snapshot_checksum(recovered_snapshot)
	
	if recovered_checksum != expected_checksum:
		DebugOverlay.log_error("NetworkMatch", "Recovery failed for %s. Rebuilt checksum %s, host checksum %s." % [context_name, recovered_checksum.left(12), expected_checksum.left(12)])
		return false
	
	DebugOverlay.log_message("NetworkMatch", "Recovered %s from the host snapshot. Checksum %s." % [context_name, expected_checksum.left(12)])
	return true


func handle_local_turn_finished() -> bool:
	if network_active == false:
		return false
	
	if game_manager == null:
		return true
	
	move_in_progress = false
	
	if local_is_host:
		game_manager.advance_to_next_turn()
		broadcast_authoritative_turn_state()
		return true
	
	game_manager.set_current_turn_phase(Global.TURN_PHASE.NONE)
	game_manager.stop_turn_timer()
	
	apply_pending_turn_state()
	apply_pending_state_checkpoint()
	return true


func broadcast_authoritative_turn_state() -> void:
	if local_is_host == false:
		return
	
	if game_manager == null:
		return
	
	var turn_revision:int = authoritative_revision
	var current_player_id:int = game_manager.get_current_player_id()
	var current_turn_number:int = game_manager.get_current_turn_number()
	
	rpc("receive_authoritative_turn_state", turn_revision, current_player_id, current_turn_number)
	DebugOverlay.log_message("NetworkMatch", "Broadcast turn %d for player slot %d after revision %d." % [current_turn_number, current_player_id, turn_revision])
	
	broadcast_authoritative_state_checkpoint(turn_revision)


@rpc("authority", "call_remote", "reliable")
func receive_authoritative_turn_state(move_revision:int, player_id:int, turn_number:int) -> void:
	if network_active == false:
		return
	
	authoritative_revision = max(authoritative_revision, move_revision)
	
	var turn_state:Dictionary = {
		"move_revision": move_revision,
		"player_id": player_id,
		"turn_number": turn_number
	}
	
	if move_in_progress:
		pending_turn_state = turn_state
		return
	
	apply_turn_state(turn_state)


func apply_pending_turn_state() -> void:
	if pending_turn_state.is_empty():
		return
	
	var turn_state:Dictionary = pending_turn_state.duplicate(true)
	pending_turn_state.clear()
	apply_turn_state(turn_state)


func apply_turn_state(turn_state:Dictionary) -> void:
	if game_manager == null:
		return
	
	var move_revision:int = int(turn_state.get("move_revision", 0))
	var player_id:int = int(turn_state.get("player_id", -1))
	var turn_number:int = int(turn_state.get("turn_number", 1))
	
	if move_revision < last_applied_revision:
		return
	
	if game_manager.is_valid_player_id(player_id) == false:
		DebugOverlay.log_error("NetworkMatch", "Received an invalid authoritative player slot: %d." % player_id)
		return
	
	last_applied_revision = max(last_applied_revision, move_revision)
	authoritative_revision = max(authoritative_revision, move_revision)
	move_request_pending = false
	move_in_progress = false
	
	game_manager.set_current_turn_number(turn_number)
	game_manager.start_turn(player_id)
	
	DebugOverlay.log_message("NetworkMatch", "Applied authoritative turn %d for player slot %d." % [turn_number, player_id])
	
	apply_pending_state_checkpoint()


func broadcast_authoritative_state_checkpoint(move_revision:int) -> void:
	if local_is_host == false:
		return
	
	if game_manager == null:
		return
	
	var authoritative_snapshot:Dictionary = game_manager.create_network_match_snapshot()
	
	if authoritative_snapshot.is_empty():
		DebugOverlay.log_error("NetworkMatch", "Could not create the authoritative state checkpoint for revision %d." % move_revision)
		return
	
	var snapshot_checksum:String = create_network_snapshot_checksum(authoritative_snapshot)
	
	rpc("receive_authoritative_state_checkpoint", move_revision, authoritative_snapshot, snapshot_checksum)
	DebugOverlay.log_message("NetworkMatch", "Broadcast state checkpoint for revision %d. Checksum %s." % [move_revision, snapshot_checksum.left(12)])


@rpc("authority", "call_remote", "reliable")
func receive_authoritative_state_checkpoint(move_revision:int, authoritative_snapshot:Dictionary, snapshot_checksum:String) -> void:
	if network_active == false:
		return
	
	var checkpoint:Dictionary = {
		"move_revision": move_revision,
		"snapshot": authoritative_snapshot,
		"checksum": snapshot_checksum
	}
	
	if move_in_progress:
		pending_state_checkpoint = checkpoint
		return
	
	if move_revision > last_applied_revision:
		pending_state_checkpoint = checkpoint
		return
	
	apply_authoritative_state_checkpoint(checkpoint)


func apply_pending_state_checkpoint() -> void:
	if pending_state_checkpoint.is_empty():
		return
	
	var checkpoint:Dictionary = pending_state_checkpoint.duplicate(true)
	var move_revision:int = int(checkpoint.get("move_revision", 0))
	
	if move_in_progress:
		return
	
	if move_revision > last_applied_revision:
		return
	
	pending_state_checkpoint.clear()
	apply_authoritative_state_checkpoint(checkpoint)


func apply_authoritative_state_checkpoint(checkpoint:Dictionary) -> void:
	if game_manager == null:
		return
	
	var move_revision:int = int(checkpoint.get("move_revision", 0))
	var authoritative_snapshot:Dictionary = checkpoint.get("snapshot", {})
	var snapshot_checksum:String = str(checkpoint.get("checksum", ""))
	
	if move_revision < last_verified_revision:
		return
	
	var context_name:String = "revision %d" % move_revision
	var checkpoint_verified:bool = verify_or_recover_authoritative_snapshot(authoritative_snapshot, snapshot_checksum, context_name)
	
	if checkpoint_verified == false:
		move_request_pending = false
		move_in_progress = true
		
		game_manager.set_current_turn_phase(Global.TURN_PHASE.NONE)
		game_manager.stop_turn_timer()
		
		DebugOverlay.log_error("NetworkMatch", "Further placement has been locked because checkpoint recovery failed for revision %d." % move_revision)
		return
	
	last_verified_revision = move_revision


func handle_local_winner_found(winner_id:int, winning_slots:Array[Vector2i]) -> bool:
	if network_active == false:
		return false
	
	if game_manager == null:
		return true
	
	move_request_pending = false
	move_in_progress = false
	pending_turn_state.clear()
	pending_state_checkpoint.clear()
	
	game_manager.set_current_turn_phase(Global.TURN_PHASE.NONE)
	game_manager.stop_turn_timer()
	game_manager.stop_game_timer()
	
	if local_is_host == false:
		if waiting_for_authoritative_game_over == false:
			waiting_for_authoritative_game_over = true
			DebugOverlay.log_message("NetworkMatch", "A local winning line was found. Waiting for the host's result.")
		
		return true
	
	if game_manager.is_valid_player_id(winner_id) == false:
		DebugOverlay.log_error("NetworkMatch", "The host found an invalid winning player slot: %d." % winner_id)
		return true
	
	authoritative_revision += 1
	
	var safe_winning_slots:Array[Vector2i] = []
	
	for slot_position in winning_slots:
		safe_winning_slots.append(slot_position)
	
	DebugOverlay.log_message("NetworkMatch", "Confirmed player slot %d as the winner at revision %d." % [winner_id, authoritative_revision])
	
	var authoritative_snapshot:Dictionary = game_manager.create_network_match_snapshot()
	
	if authoritative_snapshot.is_empty():
		DebugOverlay.log_error("NetworkMatch", "Could not create the authoritative game-over snapshot.")
		return true
	
	var snapshot_checksum:String = create_network_snapshot_checksum(authoritative_snapshot)
	rpc("apply_authoritative_game_over", authoritative_revision, winner_id, safe_winning_slots, authoritative_snapshot, snapshot_checksum)
	return true


@rpc("authority", "call_local", "reliable")
func apply_authoritative_game_over(result_revision:int, winner_id:int, winning_slots:Array[Vector2i], authoritative_snapshot:Dictionary, snapshot_checksum:String) -> void:
	if network_active == false:
		return
	
	if game_manager == null:
		return
	
	if result_revision <= applied_game_over_revision:
		return
	
	if game_manager.is_valid_player_id(winner_id) == false:
		DebugOverlay.log_error("NetworkMatch", "Received an invalid authoritative winner: %d." % winner_id)
		return
	
	applied_game_over_revision = result_revision
	last_applied_revision = max(last_applied_revision, result_revision)
	authoritative_revision = max(authoritative_revision, result_revision)
	
	move_request_pending = false
	move_in_progress = false
	waiting_for_authoritative_game_over = false
	pending_turn_state.clear()
	pending_state_checkpoint.clear()
	
	DebugOverlay.log_message("NetworkMatch", "Applying authoritative winner player slot %d at revision %d." % [winner_id, result_revision])
	
	var applied:bool = game_manager.apply_authoritative_match_result(winner_id, winning_slots)
	
	if applied == false:
		DebugOverlay.log_error("NetworkMatch", "The authoritative game-over result could not be applied.")
		return
	
	DebugOverlay.log_message("NetworkMatch", "Applied authoritative winner player slot %d at revision %d." % [winner_id, result_revision])
	
	var context_name:String = "game over revision %d" % result_revision
	var checkpoint_verified:bool = verify_or_recover_authoritative_snapshot(authoritative_snapshot, snapshot_checksum, context_name)
	
	if checkpoint_verified:
		last_verified_revision = max(last_verified_revision, result_revision)
		return
	
	DebugOverlay.log_warning("NetworkMatch", "The game-over state was applied, but state verification failed for revision %d." % result_revision)


func request_next_round() -> bool:
	if network_active == false:
		return false
	
	if local_is_host == false:
		return false
	
	if game_manager == null:
		return false
	
	if round_transition_in_progress:
		return false
	
	if game_manager.get_current_turn_phase() != Global.TURN_PHASE.GAME_OVER:
		return false
	
	var starting_player_id:int = game_manager.get_resolved_round_starting_player_id()
	
	if game_manager.is_valid_player_id(starting_player_id) == false:
		DebugOverlay.log_error("NetworkMatch", "The host could not resolve the next round's starting player.")
		return false
	
	round_transition_in_progress = true
	authoritative_revision += 1
	
	DebugOverlay.log_message("NetworkMatch", "Starting round %d with player slot %d at revision %d." % [game_manager.get_current_round_number() + 1, starting_player_id, authoritative_revision])
	rpc("apply_authoritative_next_round", authoritative_revision, starting_player_id)
	return true


@rpc("authority", "call_local", "reliable")
func apply_authoritative_next_round(round_revision:int, starting_player_id:int) -> void:
	if network_active == false:
		return
	
	if game_manager == null:
		return
	
	if round_revision <= applied_round_revision:
		return
	
	if game_manager.is_valid_player_id(starting_player_id) == false:
		DebugOverlay.log_error("NetworkMatch", "Received an invalid next-round starting player: %d." % starting_player_id)
		return
	
	applied_round_revision = round_revision
	last_applied_revision = max(last_applied_revision, round_revision)
	authoritative_revision = max(authoritative_revision, round_revision)
	
	move_request_pending = false
	move_in_progress = true
	waiting_for_authoritative_game_over = false
	round_transition_in_progress = true
	pending_turn_state.clear()
	pending_state_checkpoint.clear()
	last_verified_revision = round_revision
	
	await game_manager.start_next_round_with_player(starting_player_id)
	
	move_in_progress = false
	round_transition_in_progress = false
	
	DebugOverlay.log_message("NetworkMatch", "Applied the authoritative next round with player slot %d starting." % starting_player_id)


func handle_turn_timeout() -> bool:
	if network_active == false:
		return false
	
	if game_manager == null:
		return true
	
	if local_is_host == false:
		return true
	
	if move_request_pending:
		return true
	
	if move_in_progress:
		return true
	
	authoritative_revision += 1
	last_applied_revision = authoritative_revision
	game_manager.set_current_turn_phase(Global.TURN_PHASE.NONE)
	
	if game_manager.token_drag_controller != null:
		game_manager.token_drag_controller.cancel_drag()
	
	game_manager.advance_to_next_turn()
	broadcast_authoritative_turn_state()
	return true


func send_local_drag_preview_started(drag_id:int, token_type:int, board_local_position:Vector2, is_flipped:bool) -> void:
	if network_active == false:
		return
	
	if game_manager == null:
		return
	
	if local_player_id != game_manager.get_current_player_id():
		return
	
	if local_is_host:
		process_drag_preview_started(multiplayer.get_unique_id(), drag_id, token_type, board_local_position, is_flipped)
		return
	
	rpc_id(SERVER_PEER_ID, "request_drag_preview_started", drag_id, token_type, board_local_position, is_flipped)


func send_local_drag_preview_position(drag_id:int, board_local_position:Vector2) -> void:
	if network_active == false:
		return
	
	if local_is_host:
		process_drag_preview_position(multiplayer.get_unique_id(), drag_id, board_local_position)
		return
	
	rpc_id(SERVER_PEER_ID, "request_drag_preview_position", drag_id, board_local_position)


func send_local_drag_preview_flipped(drag_id:int, is_flipped:bool) -> void:
	if network_active == false:
		return
	
	if local_is_host:
		process_drag_preview_flipped(multiplayer.get_unique_id(), drag_id, is_flipped)
		return
	
	rpc_id(SERVER_PEER_ID, "request_drag_preview_flipped", drag_id, is_flipped)


func send_local_drag_preview_ended(drag_id:int) -> void:
	if network_active == false:
		return
	
	if local_is_host:
		process_drag_preview_ended(multiplayer.get_unique_id(), drag_id)
		return
	
	rpc_id(SERVER_PEER_ID, "request_drag_preview_ended", drag_id)


func get_drag_preview_player_for_peer(peer_id:int) -> int:
	var member:LobbyMemberData = LobbyData.get_member_by_peer_id(peer_id)
	
	if member == null:
		return -1
	
	if member.is_player() == false:
		return -1
	
	if game_manager == null:
		return -1
	
	if member.player_slot != game_manager.get_current_player_id():
		return -1
	
	return member.player_slot


@rpc("any_peer", "call_remote", "reliable")
func request_drag_preview_started(drag_id:int, token_type:int, board_local_position:Vector2, is_flipped:bool) -> void:
	if local_is_host == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	process_drag_preview_started(sender_peer_id, drag_id, token_type, board_local_position, is_flipped)


func process_drag_preview_started(peer_id:int, drag_id:int, token_type:int, board_local_position:Vector2, is_flipped:bool) -> void:
	if local_is_host == false:
		return
	
	if game_manager == null:
		return
	
	if game_manager.get_current_turn_phase() != Global.TURN_PHASE.PLACEMENT:
		return
	
	var player_id:int = get_drag_preview_player_for_peer(peer_id)
	
	if player_id == -1:
		return
	
	if is_registered_token_type(token_type) == false:
		return
	
	if game_manager.get_token_count(player_id, token_type) <= 0:
		return
	
	var used_is_flipped:bool = false
	
	if TokenLibrary.can_flip(token_type):
		used_is_flipped = is_flipped
	
	active_drag_preview_id = drag_id
	active_drag_preview_player_id = player_id
	active_drag_preview_token_type = token_type
	
	rpc("apply_drag_preview_started", drag_id, player_id, token_type, board_local_position, used_is_flipped)


@rpc("authority", "call_local", "reliable")
func apply_drag_preview_started(drag_id:int, player_id:int, token_type:int, board_local_position:Vector2, is_flipped:bool) -> void:
	if network_active == false:
		return
	
	if game_manager == null:
		return
	
	if player_id == local_player_id:
		return
	
	game_manager.show_remote_drag_preview(drag_id, player_id, token_type, board_local_position, is_flipped)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func request_drag_preview_position(drag_id:int, board_local_position:Vector2) -> void:
	if local_is_host == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	process_drag_preview_position(sender_peer_id, drag_id, board_local_position)


func process_drag_preview_position(peer_id:int, drag_id:int, board_local_position:Vector2) -> void:
	if local_is_host == false:
		return
	
	var player_id:int = get_drag_preview_player_for_peer(peer_id)
	
	if player_id == -1:
		return
	
	if drag_id != active_drag_preview_id:
		return
	
	if player_id != active_drag_preview_player_id:
		return
	
	rpc("apply_drag_preview_position", drag_id, player_id, board_local_position)


@rpc("authority", "call_local", "unreliable_ordered")
func apply_drag_preview_position(drag_id:int, player_id:int, board_local_position:Vector2) -> void:
	if network_active == false:
		return
	
	if game_manager == null:
		return
	
	if player_id == local_player_id:
		return
	
	game_manager.update_remote_drag_preview(drag_id, board_local_position)


@rpc("any_peer", "call_remote", "reliable")
func request_drag_preview_flipped(drag_id:int, is_flipped:bool) -> void:
	if local_is_host == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	process_drag_preview_flipped(sender_peer_id, drag_id, is_flipped)


func process_drag_preview_flipped(peer_id:int, drag_id:int, is_flipped:bool) -> void:
	if local_is_host == false:
		return
	
	var player_id:int = get_drag_preview_player_for_peer(peer_id)
	
	if player_id == -1:
		return
	
	if drag_id != active_drag_preview_id:
		return
	
	if player_id != active_drag_preview_player_id:
		return
	
	if TokenLibrary.can_flip(active_drag_preview_token_type) == false:
		return
	
	rpc("apply_drag_preview_flipped", drag_id, player_id, is_flipped)


@rpc("authority", "call_local", "reliable")
func apply_drag_preview_flipped(drag_id:int, player_id:int, is_flipped:bool) -> void:
	if network_active == false:
		return
	
	if game_manager == null:
		return
	
	if player_id == local_player_id:
		return
	
	game_manager.flip_remote_drag_preview(drag_id, is_flipped)


@rpc("any_peer", "call_remote", "reliable")
func request_drag_preview_ended(drag_id:int) -> void:
	if local_is_host == false:
		return
	
	var sender_peer_id:int = multiplayer.get_remote_sender_id()
	process_drag_preview_ended(sender_peer_id, drag_id)


func process_drag_preview_ended(peer_id:int, drag_id:int) -> void:
	if local_is_host == false:
		return
	
	var player_id:int = get_drag_preview_player_for_peer(peer_id)
	
	if player_id == -1:
		return
	
	if drag_id != active_drag_preview_id:
		return
	
	if player_id != active_drag_preview_player_id:
		return
	
	rpc("apply_drag_preview_ended", drag_id, player_id)
	clear_active_drag_preview_state()


@rpc("authority", "call_local", "reliable")
func apply_drag_preview_ended(drag_id:int, player_id:int) -> void:
	if network_active == false:
		return
	
	if game_manager == null:
		return
	
	if player_id == local_player_id:
		return
	
	game_manager.clear_remote_drag_preview(drag_id)


func clear_active_drag_preview_state() -> void:
	active_drag_preview_id = -1
	active_drag_preview_player_id = -1
	active_drag_preview_token_type = -1
