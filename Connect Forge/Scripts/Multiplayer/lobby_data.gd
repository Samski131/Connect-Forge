extends Node

signal lobby_started(lobby_id:int, host_steam_id:int)
signal lobby_cleared
signal lobby_phase_changed(new_phase:LOBBY_PHASE)
signal host_changed(new_host_steam_id:int)
signal maximum_members_changed(new_maximum:int)

signal member_added(member:LobbyMemberData)
signal member_updated(member:LobbyMemberData)
signal member_removed(steam_id:int)
signal members_changed
signal local_member_changed(member:LobbyMemberData)

signal snapshot_applied

enum LOBBY_PHASE {
	NONE,
	TOKEN_SELECTION,
	MATCH_IN_PROGRESS,
	RETURNING_TO_LOBBY,
	CLOSED
}

const INVALID_LOBBY_ID:int = 0
const INVALID_STEAM_ID:int = 0
const INVALID_PEER_ID:int = 0
const INVALID_PLAYER_SLOT:int = -1

const MAXIMUM_ACTIVE_PLAYERS:int = MatchConfig.MAXIMUM_PLAYERS
const MINIMUM_ACTIVE_PLAYERS:int = MatchConfig.MINIMUM_PLAYERS
const DEFAULT_MAXIMUM_MEMBERS:int = 16

const KEY_LOBBY_ID:String = "lobby_id"
const KEY_HOST_STEAM_ID:String = "host_steam_id"
const KEY_LOBBY_PHASE:String = "lobby_phase"
const KEY_MAXIMUM_MEMBERS:String = "maximum_members"
const KEY_MEMBERS:String = "members"

var current_lobby_id:int = INVALID_LOBBY_ID
var local_steam_id:int = INVALID_STEAM_ID
var host_steam_id:int = INVALID_STEAM_ID

var current_lobby_phase:LOBBY_PHASE = LOBBY_PHASE.NONE
var maximum_members:int = DEFAULT_MAXIMUM_MEMBERS

var members_by_steam_id:Dictionary = {}


func begin_lobby(new_lobby_id:int, new_host_steam_id:int, new_local_steam_id:int, new_maximum_members:int = DEFAULT_MAXIMUM_MEMBERS) -> bool:
	if new_lobby_id <= INVALID_LOBBY_ID:
		return false
	
	if new_host_steam_id <= INVALID_STEAM_ID:
		return false
	
	if new_local_steam_id <= INVALID_STEAM_ID:
		return false
	
	_reset_data()
	
	current_lobby_id = new_lobby_id
	host_steam_id = new_host_steam_id
	local_steam_id = new_local_steam_id
	maximum_members = max(new_maximum_members, MAXIMUM_ACTIVE_PLAYERS)
	current_lobby_phase = LOBBY_PHASE.TOKEN_SELECTION
	
	lobby_started.emit(current_lobby_id, host_steam_id)
	host_changed.emit(host_steam_id)
	maximum_members_changed.emit(maximum_members)
	lobby_phase_changed.emit(current_lobby_phase)
	local_member_changed.emit(get_local_member())
	return true


func clear_lobby() -> void:
	_reset_data()
	
	lobby_cleared.emit()
	members_changed.emit()
	host_changed.emit(host_steam_id)
	maximum_members_changed.emit(maximum_members)
	lobby_phase_changed.emit(current_lobby_phase)
	local_member_changed.emit(null)


func _reset_data() -> void:
	current_lobby_id = INVALID_LOBBY_ID
	local_steam_id = INVALID_STEAM_ID
	host_steam_id = INVALID_STEAM_ID
	
	current_lobby_phase = LOBBY_PHASE.NONE
	maximum_members = DEFAULT_MAXIMUM_MEMBERS
	
	members_by_steam_id.clear()


func has_active_lobby() -> bool:
	return current_lobby_id > INVALID_LOBBY_ID


func get_lobby_id() -> int:
	return current_lobby_id


func set_local_steam_id(new_local_steam_id:int) -> bool:
	if new_local_steam_id <= INVALID_STEAM_ID:
		return false
	
	if local_steam_id == new_local_steam_id:
		return true
	
	local_steam_id = new_local_steam_id
	local_member_changed.emit(get_local_member())
	return true


func get_local_steam_id() -> int:
	return local_steam_id


func set_host_steam_id(new_host_steam_id:int) -> bool:
	if new_host_steam_id <= INVALID_STEAM_ID:
		return false
	
	if host_steam_id == new_host_steam_id:
		return true
	
	host_steam_id = new_host_steam_id
	
	for member in get_members():
		var should_be_host:bool = member.steam_id == host_steam_id
		
		if member.is_host == should_be_host:
			continue
		
		member.is_host = should_be_host
		member_updated.emit(member)
	
	host_changed.emit(host_steam_id)
	members_changed.emit()
	local_member_changed.emit(get_local_member())
	return true


func get_host_steam_id() -> int:
	return host_steam_id


func is_local_host() -> bool:
	if local_steam_id <= INVALID_STEAM_ID:
		return false
	
	return local_steam_id == host_steam_id


func set_lobby_phase(new_phase:LOBBY_PHASE) -> bool:
	if is_valid_lobby_phase(int(new_phase)) == false:
		return false
	
	if current_lobby_phase == new_phase:
		return true
	
	current_lobby_phase = new_phase
	lobby_phase_changed.emit(current_lobby_phase)
	return true


func get_lobby_phase() -> LOBBY_PHASE:
	return current_lobby_phase


func is_token_selection_phase() -> bool:
	return current_lobby_phase == LOBBY_PHASE.TOKEN_SELECTION


func is_match_in_progress() -> bool:
	return current_lobby_phase == LOBBY_PHASE.MATCH_IN_PROGRESS


func get_lobby_phase_display_name() -> String:
	match current_lobby_phase:
		LOBBY_PHASE.TOKEN_SELECTION:
			return "Token Selection"
		
		LOBBY_PHASE.MATCH_IN_PROGRESS:
			return "Match In Progress"
		
		LOBBY_PHASE.RETURNING_TO_LOBBY:
			return "Returning To Lobby"
		
		LOBBY_PHASE.CLOSED:
			return "Closed"
	
	return "None"


func set_maximum_members(new_maximum_members:int) -> bool:
	var used_maximum:int = max(new_maximum_members, MAXIMUM_ACTIVE_PLAYERS)
	
	if used_maximum < get_member_count():
		return false
	
	if maximum_members == used_maximum:
		return true
	
	maximum_members = used_maximum
	maximum_members_changed.emit(maximum_members)
	return true


func get_maximum_members() -> int:
	return maximum_members


func add_member(new_member:LobbyMemberData) -> bool:
	if has_active_lobby() == false:
		return false
	
	if new_member == null:
		return false
	
	if new_member.is_valid() == false:
		return false
	
	if get_member_count() >= maximum_members:
		return false
	
	if has_member(new_member.steam_id):
		return false
	
	if has_peer_id(new_member.peer_id):
		return false
	
	if new_member.is_player():
		if is_valid_player_slot(new_member.player_slot) == false:
			return false
		
		if is_player_slot_available(new_member.player_slot) == false:
			return false
	
	var stored_member:LobbyMemberData = LobbyMemberData.create_from_dictionary(new_member.to_dictionary())
	
	if stored_member == null:
		return false
	
	stored_member.is_host = stored_member.steam_id == host_steam_id
	members_by_steam_id[stored_member.steam_id] = stored_member
	
	member_added.emit(stored_member)
	members_changed.emit()
	
	if stored_member.steam_id == local_steam_id:
		local_member_changed.emit(stored_member)
	
	return true


func update_member(updated_member:LobbyMemberData) -> bool:
	if updated_member == null:
		return false
	
	if updated_member.is_valid() == false:
		return false
	
	if has_member(updated_member.steam_id) == false:
		return false
	
	var peer_owner:LobbyMemberData = get_member_by_peer_id(updated_member.peer_id)
	
	if peer_owner != null:
		if peer_owner.steam_id != updated_member.steam_id:
			return false
	
	if updated_member.is_player():
		if is_valid_player_slot(updated_member.player_slot) == false:
			return false
		
		if is_player_slot_available(updated_member.player_slot, updated_member.steam_id) == false:
			return false
	
	var stored_member:LobbyMemberData = LobbyMemberData.create_from_dictionary(updated_member.to_dictionary())
	
	if stored_member == null:
		return false
	
	stored_member.is_host = stored_member.steam_id == host_steam_id
	members_by_steam_id[stored_member.steam_id] = stored_member
	
	member_updated.emit(stored_member)
	members_changed.emit()
	
	if stored_member.steam_id == local_steam_id:
		local_member_changed.emit(stored_member)
	
	return true


func upsert_member_from_dictionary(member_data:Dictionary) -> bool:
	var member:LobbyMemberData = LobbyMemberData.create_from_dictionary(member_data)
	
	if member == null:
		return false
	
	if has_member(member.steam_id):
		return update_member(member)
	
	return add_member(member)


func remove_member(steam_id:int) -> bool:
	var member:LobbyMemberData = get_member(steam_id)
	
	if member == null:
		return false
	
	members_by_steam_id.erase(steam_id)
	
	member_removed.emit(steam_id)
	members_changed.emit()
	
	if steam_id == local_steam_id:
		local_member_changed.emit(null)
	
	if steam_id == host_steam_id:
		host_steam_id = INVALID_STEAM_ID
		host_changed.emit(host_steam_id)
	
	return true


func has_member(steam_id:int) -> bool:
	return members_by_steam_id.has(steam_id)


func has_peer_id(peer_id:int) -> bool:
	return get_member_by_peer_id(peer_id) != null


func get_member(steam_id:int) -> LobbyMemberData:
	if members_by_steam_id.has(steam_id) == false:
		return null
	
	return members_by_steam_id[steam_id] as LobbyMemberData


func get_member_by_peer_id(peer_id:int) -> LobbyMemberData:
	if peer_id <= INVALID_PEER_ID:
		return null
	
	for member in get_members():
		if member.peer_id == peer_id:
			return member
	
	return null


func get_local_member() -> LobbyMemberData:
	return get_member(local_steam_id)


func get_host_member() -> LobbyMemberData:
	return get_member(host_steam_id)


func get_member_at_player_slot(player_slot:int) -> LobbyMemberData:
	if is_valid_player_slot(player_slot) == false:
		return null
	
	for member in get_players():
		if member.player_slot == player_slot:
			return member
	
	return null


func get_members() -> Array[LobbyMemberData]:
	var result:Array[LobbyMemberData] = []
	
	for member_value in members_by_steam_id.values():
		var member:LobbyMemberData = member_value as LobbyMemberData
		
		if member == null:
			continue
		
		result.append(member)
	
	return result


func get_members_in_display_order() -> Array[LobbyMemberData]:
	var result:Array[LobbyMemberData] = []
	
	for player in get_players():
		result.append(player)
	
	for spectator in get_spectators():
		result.append(spectator)
	
	return result


func get_players() -> Array[LobbyMemberData]:
	var players:Array[LobbyMemberData] = []
	
	for member in get_members():
		if member.is_player():
			players.append(member)
	
	players.sort_custom(_sort_members_by_player_slot)
	return players


func get_spectators() -> Array[LobbyMemberData]:
	var spectators:Array[LobbyMemberData] = []
	
	for member in get_members():
		if member.is_spectator():
			spectators.append(member)
	
	spectators.sort_custom(_sort_members_by_display_name)
	return spectators


func get_member_count() -> int:
	return members_by_steam_id.size()


func get_player_count() -> int:
	return get_players().size()


func get_spectator_count() -> int:
	return get_spectators().size()


func has_available_player_slot() -> bool:
	return get_first_available_player_slot() != INVALID_PLAYER_SLOT


func get_first_available_player_slot() -> int:
	for player_slot in range(MAXIMUM_ACTIVE_PLAYERS):
		if is_player_slot_available(player_slot):
			return player_slot
	
	return INVALID_PLAYER_SLOT


func is_valid_player_slot(player_slot:int) -> bool:
	if player_slot < 0:
		return false
	
	if player_slot >= MAXIMUM_ACTIVE_PLAYERS:
		return false
	
	return true


func is_player_slot_available(player_slot:int, ignored_steam_id:int = INVALID_STEAM_ID) -> bool:
	if is_valid_player_slot(player_slot) == false:
		return false
	
	for member in get_players():
		if member.steam_id == ignored_steam_id:
			continue
		
		if member.player_slot == player_slot:
			return false
	
	return true


func assign_member_to_player_slot(steam_id:int, requested_player_slot:int = INVALID_PLAYER_SLOT) -> bool:
	if is_token_selection_phase() == false:
		return false
	
	var member:LobbyMemberData = get_member(steam_id)
	
	if member == null:
		return false
	
	var used_player_slot:int = requested_player_slot
	
	if used_player_slot == INVALID_PLAYER_SLOT:
		used_player_slot = get_first_available_player_slot()
	
	if is_valid_player_slot(used_player_slot) == false:
		return false
	
	if is_player_slot_available(used_player_slot, steam_id) == false:
		return false
	
	if member.is_player() and member.player_slot == used_player_slot:
		member.set_requested_role(LobbyMemberData.MEMBER_ROLE.PLAYER)
		return true
	
	if member.assign_player_slot(used_player_slot) == false:
		return false
	
	member_updated.emit(member)
	members_changed.emit()
	
	if member.steam_id == local_steam_id:
		local_member_changed.emit(member)
	
	return true


func make_member_spectator(steam_id:int) -> bool:
	if is_token_selection_phase() == false:
		return false
	
	var member:LobbyMemberData = get_member(steam_id)
	
	if member == null:
		return false
	
	if member.is_spectator():
		member.set_requested_role(LobbyMemberData.MEMBER_ROLE.SPECTATOR)
		return true
	
	member.make_spectator()
	
	member_updated.emit(member)
	members_changed.emit()
	
	if member.steam_id == local_steam_id:
		local_member_changed.emit(member)
	
	return true


func set_member_requested_role(steam_id:int, requested_role:int) -> bool:
	var member:LobbyMemberData = get_member(steam_id)
	
	if member == null:
		return false
	
	member.set_requested_role(LobbyMemberData.get_valid_role(requested_role))
	
	member_updated.emit(member)
	
	if member.steam_id == local_steam_id:
		local_member_changed.emit(member)
	
	return true


func set_member_ready(steam_id:int, new_is_ready:bool) -> bool:
	if is_token_selection_phase() == false:
		return false
	
	var member:LobbyMemberData = get_member(steam_id)
	
	if member == null:
		return false
	
	if member.set_ready(new_is_ready) == false:
		return false
	
	member_updated.emit(member)
	
	if member.steam_id == local_steam_id:
		local_member_changed.emit(member)
	
	return true


func set_member_peer_id(steam_id:int, new_peer_id:int) -> bool:
	if new_peer_id <= INVALID_PEER_ID:
		return false
	
	var member:LobbyMemberData = get_member(steam_id)
	
	if member == null:
		return false
	
	if member.peer_id == new_peer_id:
		return true
	
	var peer_owner:LobbyMemberData = get_member_by_peer_id(new_peer_id)
	
	if peer_owner != null:
		if peer_owner.steam_id != steam_id:
			return false
	
	if member.set_peer_id(new_peer_id) == false:
		return false
	
	member_updated.emit(member)
	return true


func set_member_display_name(steam_id:int, new_display_name:String) -> bool:
	var used_name:String = new_display_name.strip_edges()
	
	if used_name == "":
		return false
	
	var member:LobbyMemberData = get_member(steam_id)
	
	if member == null:
		return false
	
	member.set_display_name(used_name)
	member_updated.emit(member)
	
	if member.steam_id == local_steam_id:
		local_member_changed.emit(member)
	
	return true


func set_member_colour_palette(steam_id:int, new_palette:ColorPalette) -> bool:
	if is_token_selection_phase() == false:
		return false
	
	var member:LobbyMemberData = get_member(steam_id)
	
	if member == null:
		return false
	
	if member.set_colour_palette(new_palette) == false:
		return false
	
	member_updated.emit(member)
	
	if member.steam_id == local_steam_id:
		local_member_changed.emit(member)
	
	return true


func set_member_colour_palette_path(steam_id:int, new_palette_path:String) -> bool:
	if is_token_selection_phase() == false:
		return false
	
	var member:LobbyMemberData = get_member(steam_id)
	
	if member == null:
		return false
	
	if member.set_colour_palette_path(new_palette_path) == false:
		return false
	
	member_updated.emit(member)
	
	if member.steam_id == local_steam_id:
		local_member_changed.emit(member)
	
	return true


func all_players_ready() -> bool:
	var players:Array[LobbyMemberData] = get_players()
	
	if players.size() < MINIMUM_ACTIVE_PLAYERS:
		return false
	
	for player in players:
		if player.is_ready == false:
			return false
	
	return true


func create_snapshot() -> Dictionary:
	var serialized_members:Array = []
	
	for member in get_members_in_display_order():
		serialized_members.append(member.to_dictionary())
	
	return {
		KEY_LOBBY_ID: current_lobby_id,
		KEY_HOST_STEAM_ID: host_steam_id,
		KEY_LOBBY_PHASE: int(current_lobby_phase),
		KEY_MAXIMUM_MEMBERS: maximum_members,
		KEY_MEMBERS: serialized_members
	}


func apply_snapshot(snapshot:Dictionary) -> bool:
	if snapshot.has(KEY_LOBBY_ID) == false:
		return false
	
	if snapshot.has(KEY_HOST_STEAM_ID) == false:
		return false
	
	if snapshot.has(KEY_MEMBERS) == false:
		return false
	
	var new_lobby_id:int = int(snapshot.get(KEY_LOBBY_ID, INVALID_LOBBY_ID))
	var new_host_steam_id:int = int(snapshot.get(KEY_HOST_STEAM_ID, INVALID_STEAM_ID))
	var new_phase_value:int = int(snapshot.get(KEY_LOBBY_PHASE, LOBBY_PHASE.NONE))
	var new_maximum_members:int = int(snapshot.get(KEY_MAXIMUM_MEMBERS, DEFAULT_MAXIMUM_MEMBERS))
	var raw_members:Array = snapshot.get(KEY_MEMBERS, [])
	
	if new_lobby_id <= INVALID_LOBBY_ID:
		return false
	
	if new_host_steam_id <= INVALID_STEAM_ID:
		return false
	
	if is_valid_lobby_phase(new_phase_value) == false:
		return false
	
	new_maximum_members = max(new_maximum_members, MAXIMUM_ACTIVE_PLAYERS)
	
	if raw_members.size() > new_maximum_members:
		return false
	
	var new_members:Dictionary = {}
	var used_peer_ids:Dictionary = {}
	var used_player_slots:Dictionary = {}
	var found_host:bool = false
	
	for raw_member_value in raw_members:
		if raw_member_value is Dictionary == false:
			return false
		
		var raw_member:Dictionary = raw_member_value
		var member:LobbyMemberData = LobbyMemberData.create_from_dictionary(raw_member)
		
		if member == null:
			return false
		
		if new_members.has(member.steam_id):
			return false
		
		if used_peer_ids.has(member.peer_id):
			return false
		
		if member.is_player():
			if is_valid_player_slot(member.player_slot) == false:
				return false
			
			if used_player_slots.has(member.player_slot):
				return false
			
			used_player_slots[member.player_slot] = member.steam_id
		
		member.is_host = member.steam_id == new_host_steam_id
		
		if member.is_host:
			found_host = true
		
		new_members[member.steam_id] = member
		used_peer_ids[member.peer_id] = member.steam_id
	
	if found_host == false:
		return false
	
	current_lobby_id = new_lobby_id
	host_steam_id = new_host_steam_id
	current_lobby_phase = new_phase_value as LOBBY_PHASE
	maximum_members = new_maximum_members
	members_by_steam_id = new_members
	
	snapshot_applied.emit()
	host_changed.emit(host_steam_id)
	maximum_members_changed.emit(maximum_members)
	lobby_phase_changed.emit(current_lobby_phase)
	members_changed.emit()
	local_member_changed.emit(get_local_member())
	return true


func _sort_members_by_player_slot(first_member:LobbyMemberData, second_member:LobbyMemberData) -> bool:
	return first_member.player_slot < second_member.player_slot


func _sort_members_by_display_name(first_member:LobbyMemberData, second_member:LobbyMemberData) -> bool:
	var comparison:int = first_member.display_name.naturalnocasecmp_to(second_member.display_name)
	return comparison < 0


static func is_valid_lobby_phase(phase_value:int) -> bool:
	if phase_value < LOBBY_PHASE.NONE:
		return false
	
	if phase_value > LOBBY_PHASE.CLOSED:
		return false
	
	return true
