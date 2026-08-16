class_name TokenLibrary
extends RefCounted

enum TokenType {
	BASIC,
	ANVIL,
	PYRE,
	RAMP,
	DAGGER,
	BOMB,
	DRILL,
	TETROMINO,
	ROTATE_GRAVITY,
	FAN,
	CHAMELEON
}

const KEY_REPLAY_ID:String = "replay_id"
const KEY_DISPLAY_NAME:String = "display_name"
const KEY_DESCRIPTION:String = "description"
const KEY_SCENE_PATH:String = "scene_path"
const KEY_ICON_PATH:String = "icon_path"
const KEY_CAN_FLIP:String = "can_flip"
const KEY_TRAY_ORDER:String = "tray_order"
const KEY_COST:String = "cost"
const KEY_AVAILABLE_IN_LOBBY:String = "available_in_lobby"


static func get_token_data(token_type:int) -> Dictionary:
	var data:Dictionary = get_all_token_data()
	
	if data.has(token_type) == false:
		return {}
	
	return data[token_type]


static func get_all_token_types() -> Array[int]:
	return [
		TokenType.ANVIL,
		TokenType.BASIC,
		TokenType.BOMB,
		TokenType.CHAMELEON,
		TokenType.DAGGER,
		TokenType.DRILL,
		TokenType.FAN,
		TokenType.PYRE,
		TokenType.RAMP,
		TokenType.ROTATE_GRAVITY,
		TokenType.TETROMINO
	]


static func get_all_token_data() -> Dictionary:
	return {
		TokenType.BASIC: {
			KEY_REPLAY_ID: "basic",
			KEY_DISPLAY_NAME: "Basic",
			KEY_DESCRIPTION: "A normal token. It has no special effect.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/base token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/Asset 73.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 0,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: false
		},
		TokenType.ANVIL: {
			KEY_REPLAY_ID: "anvil",
			KEY_DISPLAY_NAME: "Anvil",
			KEY_DESCRIPTION: "On land, destroys the token directly below it.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/anvil token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Anvil.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 1,
			KEY_COST: 4,
			KEY_AVAILABLE_IN_LOBBY: true
		},
		TokenType.BOMB: {
			KEY_REPLAY_ID: "bomb",
			KEY_DISPLAY_NAME: "Bomb",
			KEY_DESCRIPTION: "On land, destroys itself and adjacent tokens.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/bomb token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Bomb.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 2,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: true
		},
		TokenType.CHAMELEON: {
			KEY_REPLAY_ID: "chameleon",
			KEY_DISPLAY_NAME: "Chameleon",
			KEY_DESCRIPTION: "Disguises itself as another player's token after landing.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/chameleon token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Chameleon.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 3,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: true
		},
		TokenType.DAGGER: {
			KEY_REPLAY_ID: "dagger",
			KEY_DISPLAY_NAME: "Dagger",
			KEY_DESCRIPTION: "Destroys a token that passes on its trigger side.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/dagger token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Dagger.png",
			KEY_CAN_FLIP: true,
			KEY_TRAY_ORDER: 4,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: true
		},
		TokenType.DRILL: {
			KEY_REPLAY_ID: "drill",
			KEY_DISPLAY_NAME: "Drill",
			KEY_DESCRIPTION: "Destroys the token below it when it lands, then keeps falling.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/drill token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Drill.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 5,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: true
		},
		TokenType.FAN: {
			KEY_REPLAY_ID: "fan",
			KEY_DISPLAY_NAME: "Fan",
			KEY_DESCRIPTION: "Pushes nearby tokens sideways relative to gravity. Can be flipped before placement.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/fan token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Fan.png",
			KEY_CAN_FLIP: true,
			KEY_TRAY_ORDER: 6,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: true
		},
		TokenType.PYRE: {
			KEY_REPLAY_ID: "pyre",
			KEY_DISPLAY_NAME: "Pyre",
			KEY_DESCRIPTION: "Special token with an on-board effect.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/pyre token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/pyre - main.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 7,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: true
		},
		TokenType.RAMP: {
			KEY_REPLAY_ID: "ramp",
			KEY_DISPLAY_NAME: "Ramp",
			KEY_DESCRIPTION: "Redirects a landing token to one side. Can be flipped before placement.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/ramp token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Ramp front.png",
			KEY_CAN_FLIP: true,
			KEY_TRAY_ORDER: 8,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: true
		},
		TokenType.ROTATE_GRAVITY: {
			KEY_REPLAY_ID: "rotate_gravity",
			KEY_DISPLAY_NAME: "Rotate Gravity",
			KEY_DESCRIPTION: "Rotates the board gravity direction.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/rotate gravity token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Rotate.png",
			KEY_CAN_FLIP: true,
			KEY_TRAY_ORDER: 9,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: true
		},
		TokenType.TETROMINO: {
			KEY_REPLAY_ID: "tetromino",
			KEY_DISPLAY_NAME: "Tetromino",
			KEY_DESCRIPTION: "Special shape-based token.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/tetromino token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/tetris body.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 10,
			KEY_COST: 2,
			KEY_AVAILABLE_IN_LOBBY: true
		}
	}


static func get_token_data_value(token_type:int, key:String, default_value):
	var data:Dictionary = get_token_data(token_type)
	
	if data.has(key) == false:
		return default_value
	
	return data[key]


static func get_replay_id(token_type:int) -> String:
	return str(get_token_data_value(token_type, KEY_REPLAY_ID, ""))


static func get_token_type_from_replay_id(replay_id:String) -> int:
	var used_replay_id:String = replay_id.strip_edges().to_lower()
	
	if used_replay_id == "":
		return -1
	
	for token_type in get_all_token_types():
		if get_replay_id(token_type) == used_replay_id:
			return token_type
	
	return -1


static func is_valid_replay_id(replay_id:String) -> bool:
	return get_token_type_from_replay_id(replay_id) != -1


static func validate_replay_ids() -> bool:
	var found_ids:Dictionary = {}
	
	for token_type in get_all_token_types():
		var replay_id:String = get_replay_id(token_type)
		
		if replay_id == "":
			push_error("TokenLibrary: Token type %d has no replay ID." % token_type)
			return false
		
		if found_ids.has(replay_id):
			push_error("TokenLibrary: Duplicate replay ID '%s'." % replay_id)
			return false
		
		found_ids[replay_id] = true
	
	return true


static func get_display_name(token_type:int) -> String:
	return str(get_token_data_value(token_type, KEY_DISPLAY_NAME, "Unknown Token"))


static func get_description(token_type:int) -> String:
	return str(get_token_data_value(token_type, KEY_DESCRIPTION, ""))


static func get_scene_path(token_type:int) -> String:
	return str(get_token_data_value(token_type, KEY_SCENE_PATH, ""))


static func get_icon_path(token_type:int) -> String:
	return str(get_token_data_value(token_type, KEY_ICON_PATH, ""))


static func can_flip(token_type:int) -> bool:
	return bool(get_token_data_value(token_type, KEY_CAN_FLIP, false))


static func get_tray_order(token_type:int) -> int:
	return int(get_token_data_value(token_type, KEY_TRAY_ORDER, 0))


static func get_token_scene(token_type:int) -> PackedScene:
	var scene_path:String = get_scene_path(token_type)
	
	if scene_path == "":
		return null
	
	return load(scene_path) as PackedScene


static func get_icon_texture(token_type:int) -> Texture2D:
	var icon_path:String = get_icon_path(token_type)
	
	if icon_path == "":
		return null
	
	return load(icon_path) as Texture2D


static func get_token_types_in_tray_order() -> Array[int]:
	var unsorted_types:Array[int] = get_all_token_types()
	var sorted_types:Array[int] = []
	
	for token_type in unsorted_types:
		var inserted:bool = false
		var token_order:int = get_tray_order(token_type)
		
		for i in range(sorted_types.size()):
			var other_type:int = sorted_types[i]
			var other_order:int = get_tray_order(other_type)
			
			if token_order < other_order:
				sorted_types.insert(i, token_type)
				inserted = true
				break
		
		if inserted == false:
			sorted_types.append(token_type)
	
	return sorted_types


static func get_cost(token_type:int) -> int:
	return int(get_token_data_value(token_type, KEY_COST, 1))


static func is_available_in_lobby(token_type:int) -> bool:
	return bool(get_token_data_value(token_type, KEY_AVAILABLE_IN_LOBBY, true))


static func get_lobby_token_types() -> Array[int]:
	var lobby_types:Array[int] = []
	
	for token_type in get_token_types_in_tray_order():
		if is_available_in_lobby(token_type):
			lobby_types.append(token_type)
	
	return lobby_types
