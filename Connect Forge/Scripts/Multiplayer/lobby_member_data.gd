class_name LobbyMemberData
extends RefCounted

enum MEMBER_ROLE {
	PLAYER,
	SPECTATOR
}

const INVALID_STEAM_ID:int = 0
const INVALID_PEER_ID:int = 0
const INVALID_PLAYER_SLOT:int = -1

const KEY_STEAM_ID:String = "steam_id"
const KEY_PEER_ID:String = "peer_id"
const KEY_DISPLAY_NAME:String = "display_name"
const KEY_ROLE:String = "role"
const KEY_REQUESTED_ROLE:String = "requested_role"
const KEY_PLAYER_SLOT:String = "player_slot"
const KEY_COLOUR_PALETTE_PATH:String = "colour_palette_path"
const KEY_IS_READY:String = "is_ready"
const KEY_IS_HOST:String = "is_host"

var steam_id:int = INVALID_STEAM_ID
var peer_id:int = INVALID_PEER_ID
var display_name:String = ""

var role:MEMBER_ROLE = MEMBER_ROLE.SPECTATOR
var requested_role:MEMBER_ROLE = MEMBER_ROLE.SPECTATOR
var player_slot:int = INVALID_PLAYER_SLOT

var colour_palette_path:String = ""

var is_ready:bool = false
var is_host:bool = false


func setup(new_steam_id:int, new_peer_id:int, new_display_name:String, new_role:MEMBER_ROLE = MEMBER_ROLE.SPECTATOR, new_is_host:bool = false) -> void:
	clear()
	
	steam_id = max(new_steam_id, INVALID_STEAM_ID)
	peer_id = max(new_peer_id, INVALID_PEER_ID)
	set_display_name(new_display_name)
	
	role = get_valid_role(new_role)
	requested_role = role
	is_host = new_is_host
	
	if role == MEMBER_ROLE.SPECTATOR:
		player_slot = INVALID_PLAYER_SLOT


func clear() -> void:
	steam_id = INVALID_STEAM_ID
	peer_id = INVALID_PEER_ID
	display_name = ""
	
	role = MEMBER_ROLE.SPECTATOR
	requested_role = MEMBER_ROLE.SPECTATOR
	player_slot = INVALID_PLAYER_SLOT
	
	colour_palette_path = ""
	
	is_ready = false
	is_host = false


func set_steam_id(new_steam_id:int) -> bool:
	if new_steam_id <= INVALID_STEAM_ID:
		return false
	
	steam_id = new_steam_id
	return true


func set_peer_id(new_peer_id:int) -> bool:
	if new_peer_id <= INVALID_PEER_ID:
		return false
	
	peer_id = new_peer_id
	return true


func set_display_name(new_display_name:String) -> void:
	display_name = new_display_name.strip_edges()


func set_requested_role(new_requested_role:MEMBER_ROLE) -> void:
	requested_role = get_valid_role(new_requested_role)


func assign_player_slot(new_player_slot:int) -> bool:
	if new_player_slot < 0:
		return false
	
	role = MEMBER_ROLE.PLAYER
	requested_role = MEMBER_ROLE.PLAYER
	player_slot = new_player_slot
	is_ready = false
	return true


func make_spectator() -> void:
	role = MEMBER_ROLE.SPECTATOR
	requested_role = MEMBER_ROLE.SPECTATOR
	player_slot = INVALID_PLAYER_SLOT
	is_ready = false


func set_ready(new_is_ready:bool) -> bool:
	if is_player() == false:
		is_ready = false
		return false
	
	if has_player_slot() == false:
		is_ready = false
		return false
	
	is_ready = new_is_ready
	return true


func set_colour_palette(new_palette:ColorPalette) -> bool:
	if new_palette == null:
		colour_palette_path = ""
		return true
	
	var new_palette_path:String = new_palette.resource_path
	
	if new_palette_path == "":
		return false
	
	return set_colour_palette_path(new_palette_path)


func set_colour_palette_path(new_palette_path:String) -> bool:
	var used_path:String = new_palette_path.strip_edges()
	
	if used_path == "":
		colour_palette_path = ""
		return true
	
	if used_path.begins_with("res://") == false:
		return false
	
	if ResourceLoader.exists(used_path) == false:
		return false
	
	var loaded_resource:Resource = ResourceLoader.load(used_path)
	var loaded_palette:ColorPalette = loaded_resource as ColorPalette
	
	if loaded_palette == null:
		return false
	
	colour_palette_path = used_path
	return true


func get_colour_palette() -> ColorPalette:
	if colour_palette_path == "":
		return null
	
	if ResourceLoader.exists(colour_palette_path) == false:
		return null
	
	return ResourceLoader.load(colour_palette_path) as ColorPalette


func is_player() -> bool:
	return role == MEMBER_ROLE.PLAYER


func is_spectator() -> bool:
	return role == MEMBER_ROLE.SPECTATOR


func wants_to_be_player() -> bool:
	return requested_role == MEMBER_ROLE.PLAYER


func has_player_slot() -> bool:
	return player_slot >= 0


func has_valid_steam_id() -> bool:
	return steam_id > INVALID_STEAM_ID


func has_valid_peer_id() -> bool:
	return peer_id > INVALID_PEER_ID


func has_valid_display_name() -> bool:
	return display_name.strip_edges() != ""


func is_valid() -> bool:
	if has_valid_steam_id() == false:
		return false
	
	if has_valid_peer_id() == false:
		return false
	
	if has_valid_display_name() == false:
		return false
	
	if is_player() and has_player_slot() == false:
		return false
	
	if is_spectator() and has_player_slot():
		return false
	
	return true


func get_role_display_name() -> String:
	if is_player():
		return "Player"
	
	return "Spectator"


func to_dictionary() -> Dictionary:
	return {
		KEY_STEAM_ID: steam_id,
		KEY_PEER_ID: peer_id,
		KEY_DISPLAY_NAME: display_name,
		KEY_ROLE: int(role),
		KEY_REQUESTED_ROLE: int(requested_role),
		KEY_PLAYER_SLOT: player_slot,
		KEY_COLOUR_PALETTE_PATH: colour_palette_path,
		KEY_IS_READY: is_ready,
		KEY_IS_HOST: is_host
	}


func apply_dictionary(data:Dictionary) -> bool:
	if data.has(KEY_STEAM_ID) == false:
		return false
	
	if data.has(KEY_PEER_ID) == false:
		return false
	
	if data.has(KEY_DISPLAY_NAME) == false:
		return false
	
	var new_steam_id:int = int(data.get(KEY_STEAM_ID, INVALID_STEAM_ID))
	var new_peer_id:int = int(data.get(KEY_PEER_ID, INVALID_PEER_ID))
	var new_display_name:String = str(data.get(KEY_DISPLAY_NAME, "")).strip_edges()
	var new_role:MEMBER_ROLE = get_valid_role(int(data.get(KEY_ROLE, MEMBER_ROLE.SPECTATOR)))
	var new_requested_role:MEMBER_ROLE = get_valid_role(int(data.get(KEY_REQUESTED_ROLE, MEMBER_ROLE.SPECTATOR)))
	var new_player_slot:int = int(data.get(KEY_PLAYER_SLOT, INVALID_PLAYER_SLOT))
	var new_palette_path:String = str(data.get(KEY_COLOUR_PALETTE_PATH, ""))
	var new_is_ready:bool = bool(data.get(KEY_IS_READY, false))
	var new_is_host:bool = bool(data.get(KEY_IS_HOST, false))
	
	if new_steam_id <= INVALID_STEAM_ID:
		return false
	
	if new_peer_id <= INVALID_PEER_ID:
		return false
	
	if new_display_name == "":
		return false
	
	if new_role == MEMBER_ROLE.PLAYER and new_player_slot < 0:
		return false
	
	clear()
	
	steam_id = new_steam_id
	peer_id = new_peer_id
	display_name = new_display_name
	role = new_role
	requested_role = new_requested_role
	is_host = new_is_host
	
	if role == MEMBER_ROLE.PLAYER:
		player_slot = new_player_slot
		is_ready = new_is_ready
	else:
		player_slot = INVALID_PLAYER_SLOT
		is_ready = false
	
	if new_palette_path != "":
		if set_colour_palette_path(new_palette_path) == false:
			clear()
			return false
	
	return is_valid()


static func create_from_dictionary(data:Dictionary) -> LobbyMemberData:
	var member:LobbyMemberData = LobbyMemberData.new()
	
	if member.apply_dictionary(data) == false:
		return null
	
	return member


static func get_valid_role(role_value:int) -> MEMBER_ROLE:
	if role_value == MEMBER_ROLE.PLAYER:
		return MEMBER_ROLE.PLAYER
	
	return MEMBER_ROLE.SPECTATOR
