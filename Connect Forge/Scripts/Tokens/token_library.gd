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

const KEY_DISPLAY_NAME:String = "display_name"
const KEY_DESCRIPTION:String = "description"
const KEY_SCENE_PATH:String = "scene_path"
const KEY_ICON_PATH:String = "icon_path"
const KEY_CAN_FLIP:String = "can_flip"
const KEY_TRAY_ORDER:String = "tray_order"



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
			KEY_DISPLAY_NAME: "Basic",
			KEY_DESCRIPTION: "A normal token. It has no special effect.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/base token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/Asset 73.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 0
		},
		TokenType.ANVIL: {
			KEY_DISPLAY_NAME: "Anvil",
			KEY_DESCRIPTION: "On land, destroys the token directly below it.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/anvil token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Anvil.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 1
		},
		TokenType.BOMB: {
			KEY_DISPLAY_NAME: "Bomb",
			KEY_DESCRIPTION: "Destroys itself and adjacent tokens when it lands.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/bomb token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Bomb.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 2
		},
		TokenType.CHAMELEON: {
			KEY_DISPLAY_NAME: "Chameleon",
			KEY_DESCRIPTION: "Disguises itself as another player's token after landing.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/chameleon token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Chameleon.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 3
		},
		TokenType.DAGGER: {
			KEY_DISPLAY_NAME: "Dagger",
			KEY_DESCRIPTION: "Destroys a token that passes on its trigger side.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/dagger token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Dagger.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 4
		},
		TokenType.DRILL: {
			KEY_DISPLAY_NAME: "Drill",
			KEY_DESCRIPTION: "Destroys the token below it when it lands, then keeps falling.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/drill token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Drill.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 5
		},
		TokenType.FAN: {
			KEY_DISPLAY_NAME: "Fan",
			KEY_DESCRIPTION: "Pushes nearby tokens sideways relative to gravity. Can be flipped before placement.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/fan token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Fan.png",
			KEY_CAN_FLIP: true,
			KEY_TRAY_ORDER: 6
		},
		TokenType.PYRE: {
			KEY_DISPLAY_NAME: "Pyre",
			KEY_DESCRIPTION: "Special token with an on-board effect.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/pyre token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/pyre - main.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 7
		},
		TokenType.RAMP: {
			KEY_DISPLAY_NAME: "Ramp",
			KEY_DESCRIPTION: "Redirects a landing token to one side. Can be flipped before placement.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/ramp token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Ramp front.png",
			KEY_CAN_FLIP: true,
			KEY_TRAY_ORDER: 8
		},
		TokenType.ROTATE_GRAVITY: {
			KEY_DISPLAY_NAME: "Rotate Gravity",
			KEY_DESCRIPTION: "Rotates the board gravity direction.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/rotate gravity token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/Rotate.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 9
		},
		TokenType.TETROMINO: {
			KEY_DISPLAY_NAME: "Tetromino",
			KEY_DESCRIPTION: "Special shape-based token.",
			KEY_SCENE_PATH: "res://Scenes/Tokens/tetromino token.tscn",
			KEY_ICON_PATH: "res://Assets/tokens/parts of tokens/token decoration/tetris body.png",
			KEY_CAN_FLIP: false,
			KEY_TRAY_ORDER: 10
		}
	}

static func get_token_data_value(token_type:int, key:String, default_value):
	var data:Dictionary = get_token_data(token_type)
	
	if data.has(key) == false:
		return default_value
	
	return data[key]


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
