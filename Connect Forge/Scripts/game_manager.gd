extends Node

# Game Management
# Stores settings but mostly directs the game's turn order and state machine.

@export var starting_number_of_players:int = 2
@export var minimum_number_of_players:int = 2
@export var max_number_of_players:int = 6
@export var default_player_names:Array[String] = ["Sam", "Jordan"]
@export var player_colours:Array[ColorPalette]

var number_of_players:int = 0
var player_names:Array[String] = []
var current_turn_phase:Global.TURN_PHASE = Global.TURN_PHASE.NONE
var current_player_id:int = 0

@onready var placement_state:Node = $"Placement State"
@onready var action_state:Node = $"Action State"
@onready var resolution_state:Node = $"Resolution State"
@onready var game_over_state:Node = $"Game Over State"
@onready var board_builder:Node 
@onready var board:BoardManager



var winner_ui:VBoxContainer
var token_tray_model:TokenTrayModel = null

func _ready():
	gather_groups()
	setup_default_players()
	setup_token_tray_model()
	setup_states()
	start_game()


func setup_states():
	placement_state.setup(self, board)
	action_state.setup(self, board)
	resolution_state.setup(self, board)
	game_over_state.setup(self, board)


func gather_groups():
	board = get_tree().get_first_node_in_group("board pool")
	board_builder = get_tree().get_first_node_in_group("board builder")
	winner_ui = get_tree().get_first_node_in_group("winner ui")


func setup_default_players() -> void:
	player_names.clear()
	number_of_players = 0
	
	var players_to_add:int = clamp(starting_number_of_players, minimum_number_of_players, max_number_of_players)
	
	for i in range(players_to_add):
		add_player()


func add_player() -> bool:
	if number_of_players >= max_number_of_players:
		return false
	
	var new_player_id:int = number_of_players
	number_of_players += 1
	player_names.append(get_default_player_name(new_player_id))
	
	if token_tray_model != null:
		token_tray_model.resize_for_players(number_of_players)
		
	return true


func remove_player() -> bool:
	if number_of_players <= minimum_number_of_players:
		return false
	
	number_of_players -= 1
	
	if player_names.size() > number_of_players:
		player_names.resize(number_of_players)
	
	if current_player_id >= number_of_players:
		current_player_id = 0
		
	if token_tray_model != null:
		token_tray_model.resize_for_players(number_of_players)
	return true


func set_player_name(player_id:int, new_name:String) -> bool:
	if player_id < 0:
		return false
	
	if player_id >= number_of_players:
		return false
	
	if player_id >= player_names.size():
		return false
	
	player_names[player_id] = new_name
	
	return true


func get_player_name(player_id:int) -> String:
	if player_id < 0:
		return ""
	
	if player_id >= player_names.size():
		return get_default_player_name(player_id)
	
	return player_names[player_id]


func get_default_player_name(player_id:int) -> String:
	if player_id >= 0 and player_id < default_player_names.size():
		return default_player_names[player_id]
	
	return "Player " + str(player_id + 1)


func start_game():
	if token_tray_model != null:
		token_tray_model.setup_for_players(number_of_players)
	
	start_turn(0)


func start_turn(player_id:int):
	current_player_id = player_id
	placement_state.enter_state()


func end_turn():
	current_player_id = get_next_player_id()
	start_turn(current_player_id)


func get_next_player_id()->int:
	if number_of_players <= 0:
		return 0
	
	var next_player_id:int = (current_player_id + 1) % number_of_players
	return next_player_id


func _process(_delta):
	debug_gravity_changes()
	
	match current_turn_phase:
		Global.TURN_PHASE.PLACEMENT:
			placement_state.process_state()
		Global.TURN_PHASE.ACTION:
			action_state.process_state()
		Global.TURN_PHASE.RESOLUTION:
			resolution_state.process_state()


func reset_game():
	board_builder.rebuild_board()
	winner_ui.clear_winner()
	start_game()


func debug_gravity_changes():
	var changed:bool = false
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	if Input.is_action_just_pressed("right_arrow"):
		changed = board.set_gravity_direction(GRID_DIRECTION.RIGHT)
	
	if Input.is_action_just_pressed("left_arrow"):
		changed = board.set_gravity_direction(GRID_DIRECTION.LEFT)
	
	if Input.is_action_just_pressed("up_arrow"):
		changed = board.set_gravity_direction(GRID_DIRECTION.UP)
	
	if Input.is_action_just_pressed("down_arrow"):
		changed = board.set_gravity_direction(GRID_DIRECTION.DOWN)
	
	if changed:
		placement_state.clear_placement_token()
		action_state.enter_state()

func setup_token_tray_model() -> void:
	token_tray_model = get_node_or_null("Token Tray Model") as TokenTrayModel
	
	if token_tray_model == null:
		token_tray_model = TokenTrayModel.new()
		token_tray_model.name = "Token Tray Model"
		add_child(token_tray_model)
	
	token_tray_model.setup_for_players(number_of_players)
