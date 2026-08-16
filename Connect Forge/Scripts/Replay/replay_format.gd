class_name ReplayFormat
extends RefCounted

const FORMAT_NAME:String = "advanced_four_replay"
const CURRENT_FORMAT_VERSION:int = 1
const MINIMUM_SUPPORTED_FORMAT_VERSION:int = 1

const FILE_EXTENSION:String = "afreplay"
const REPLAY_DIRECTORY:String = "user://replays"

const ACTION_VERSION_DEFAULT:int = 1

const ACTION_CHANNEL_STATE:String = "state"
const ACTION_CHANNEL_PRESENTATION:String = "presentation"
const ACTION_CHANNEL_GROUP:String = "group"

const GROUP_SEQUENCE:String = "sequence"
const GROUP_PARALLEL:String = "parallel"

const STEP_MATCH_START:String = "match_start"
const STEP_ROUND_START:String = "round_start"
const STEP_TURN_START:String = "turn_start"
const STEP_ACTION:String = "action"
const STEP_TURN_END:String = "turn_end"
const STEP_ROUND_END:String = "round_end"
const STEP_MATCH_END:String = "match_end"

const STATE_TOKEN_SPAWN:String = "token_spawn"
const STATE_TOKEN_MOVE:String = "token_move"
const STATE_TOKEN_DESTROY:String = "token_destroy"
const STATE_TOKEN_FLIP:String = "token_flip"
const STATE_TOKEN_UPDATE:String = "token_update"
const STATE_GRAVITY_CHANGE:String = "gravity_change"

const PRESENTATION_TOKEN_MOVE:String = "token_move"
const PRESENTATION_TOKEN_DESTROY:String = "token_destroy"
const PRESENTATION_TOKEN_FLIP:String = "token_flip"
const PRESENTATION_TOKEN_SHIMMER:String = "token_shimmer"
const PRESENTATION_TOKEN_FLASH:String = "token_flash"
const PRESENTATION_TOKEN_DARKEN:String = "token_darken"
const PRESENTATION_TOKEN_GRAVITY_ALIGN:String = "token_gravity_align"
const PRESENTATION_WIGGLE:String = "wiggle"
const PRESENTATION_PARTICLE:String = "particle"
const PRESENTATION_AUDIO:String = "audio"
const PRESENTATION_SCREEN_SHAKE:String = "screen_shake"
const PRESENTATION_CHAMELEON_TRANSFORM:String = "chameleon_transform"
const PRESENTATION_CHAMELEON_REVEAL:String = "chameleon_reveal"

const MOVEMENT_FALL:String = "fall"
const MOVEMENT_SLIDE:String = "slide"
const MOVEMENT_TELEPORT:String = "teleport"
const MOVEMENT_PATH:String = "path"
const MOVEMENT_INSTANT:String = "instant"

const GRAVITY_UP:String = "up"
const GRAVITY_RIGHT:String = "right"
const GRAVITY_DOWN:String = "down"
const GRAVITY_LEFT:String = "left"

static func get_file_extension() -> String:
	return FILE_EXTENSION


static func get_file_suffix() -> String:
	return "." + FILE_EXTENSION


static func is_supported_format_version(format_version:int) -> bool:
	if format_version < MINIMUM_SUPPORTED_FORMAT_VERSION:
		return false
	
	if format_version > CURRENT_FORMAT_VERSION:
		return false
	
	return true


static func create_file_header() -> Dictionary:
	return {
		"format": FORMAT_NAME,
		"format_version": CURRENT_FORMAT_VERSION
	}


static func is_valid_file_header(data:Dictionary) -> bool:
	if str(data.get("format", "")) != FORMAT_NAME:
		return false
	
	var format_version:int = int(data.get("format_version", -1))
	return is_supported_format_version(format_version)


static func is_valid_action_channel(channel:String) -> bool:
	if channel == ACTION_CHANNEL_STATE:
		return true
	
	if channel == ACTION_CHANNEL_PRESENTATION:
		return true
	
	if channel == ACTION_CHANNEL_GROUP:
		return true
	
	return false


static func is_group_type(action_type:String) -> bool:
	if action_type == GROUP_SEQUENCE:
		return true
	
	if action_type == GROUP_PARALLEL:
		return true
	
	return false


static func is_valid_step_type(step_type:String) -> bool:
	if step_type == STEP_MATCH_START:
		return true
	
	if step_type == STEP_ROUND_START:
		return true
	
	if step_type == STEP_TURN_START:
		return true
	
	if step_type == STEP_ACTION:
		return true
	
	if step_type == STEP_TURN_END:
		return true
	
	if step_type == STEP_ROUND_END:
		return true
	
	if step_type == STEP_MATCH_END:
		return true
	
	return false
