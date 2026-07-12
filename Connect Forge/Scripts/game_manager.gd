extends Node

# Game Management
# Stores settings but mostly directs the game's turn order and state machine.
signal current_player_changed(player_id:int)
signal player_names_changed
signal turn_number_changed(turn_number:int)
signal game_time_changed(total_seconds:int)
signal score_changed

@export var starting_number_of_players:int = 3
@export var minimum_number_of_players:int = 2
@export var max_number_of_players:int = 6
@export var default_player_names:Array[String] = ["Sam", "Ross", "Jack", "Jack", "Ross"]
@export var player_colours:Array[ColorPalette]

var number_of_players:int = 0
var player_names:Array[String] = []
var current_turn_phase:Global.TURN_PHASE = Global.TURN_PHASE.NONE
var current_player_id:int = 0
var current_turn_number:int = 1
var elapsed_game_time:float = 0.0
var elapsed_game_seconds:int = 0
var game_timer_running:bool = false
var player_wins:Array[int] = []
var player_losses:Array[int] = []
var match_result_recorded:bool = false

@onready var placement_state:Node = $"Placement State"
@onready var action_state:Node = $"Action State"
@onready var resolution_state:Node = $"Resolution State"
@onready var game_over_state:Node = $"Game Over State"
@onready var board_builder:Node 
@onready var board:BoardManager

var token_tray_inventory:TokenTrayInventory = null
var player_token_trays_ui:PlayerTokenTraysUI = null

func _ready():
	gather_groups()
	setup_default_players()
	setup_token_tray_inventory()
	setup_states()
	rebuild_player_trays()
	start_game()
	give_test_tokens()


func setup_states():
	placement_state.setup(self, board)
	action_state.setup(self, board)
	resolution_state.setup(self, board)
	game_over_state.setup(self, board)


func gather_groups():
	board = get_tree().get_first_node_in_group("board pool")
	board_builder = get_tree().get_first_node_in_group("board builder")
	player_token_trays_ui = get_tree().get_first_node_in_group("player token trays ui") as PlayerTokenTraysUI

func setup_default_players() -> void:
	player_names.clear()
	player_wins.clear()
	player_losses.clear()
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
	player_wins.append(0)
	player_losses.append(0)
	
	if token_tray_inventory != null:
		token_tray_inventory.resize_for_players(number_of_players)
	
	rebuild_player_trays()
	score_changed.emit()
	
	return true


func remove_player() -> bool:
	if number_of_players <= minimum_number_of_players:
		return false
	
	number_of_players -= 1
	
	if player_names.size() > number_of_players:
		player_names.pop_back()
	
	if player_wins.size() > number_of_players:
		player_wins.pop_back()
	
	if player_losses.size() > number_of_players:
		player_losses.pop_back()
	
	if token_tray_inventory != null:
		token_tray_inventory.resize_for_players(number_of_players)
	
	if current_player_id >= number_of_players:
		current_player_id = 0
	
	rebuild_player_trays()
	score_changed.emit()
	
	return true

func set_player_name(player_id:int, new_name:String) -> bool:
	if player_id < 0:
		return false
	
	if player_id >= number_of_players:
		return false
	
	if player_id >= player_names.size():
		return false
	
	player_names[player_id] = new_name
	player_names_changed.emit()
	
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
	match_result_recorded = false
	current_turn_number = 1
	turn_number_changed.emit(current_turn_number)
	reset_game_timer()
	start_game_timer()
	start_turn(0)

func start_turn(player_id:int):
	current_player_id = player_id
	current_player_changed.emit(current_player_id)
	placement_state.enter_state()

func end_turn():
	var next_player_id:int = get_next_player_id()
	
	if has_completed_full_turn(next_player_id):
		current_turn_number += 1
		turn_number_changed.emit(current_turn_number)
	
	start_turn(next_player_id)


func has_completed_full_turn(next_player_id:int) -> bool:
	if number_of_players <= 1:
		return true
	
	if next_player_id == 0 and current_player_id != 0:
		return true
	
	return false

func get_next_player_id()->int:
	if number_of_players <= 0:
		return 0
	
	var next_player_id:int = (current_player_id + 1) % number_of_players
	return next_player_id


func _process(delta:float) -> void:
	update_game_timer(delta)
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
	reset_test_token_trays()
	get_tree().call_group("winning_line_visual", "queue_free")
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

func setup_token_tray_inventory() -> void:
	token_tray_inventory = get_tree().get_first_node_in_group("token tray inventory") as TokenTrayInventory
	
	if token_tray_inventory == null:
		token_tray_inventory = TokenTrayInventory.new()
		token_tray_inventory.add_to_group("token tray inventory")
		add_child(token_tray_inventory)
	
	token_tray_inventory.setup_for_players(number_of_players)
	

	
func rebuild_player_trays() -> void:
	if player_token_trays_ui == null:
		player_token_trays_ui = get_tree().get_first_node_in_group("player token trays ui") as PlayerTokenTraysUI
	
	if player_token_trays_ui == null:
		return
	
	player_token_trays_ui.rebuild_trays()

func reset_game_timer() -> void:
	elapsed_game_time = 0.0
	elapsed_game_seconds = 0
	game_time_changed.emit(elapsed_game_seconds)


func start_game_timer() -> void:
	game_timer_running = true


func stop_game_timer() -> void:
	game_timer_running = false
	game_time_changed.emit(elapsed_game_seconds)


func update_game_timer(delta:float) -> void:
	if game_timer_running == false:
		return
	
	if current_turn_phase == Global.TURN_PHASE.GAME_OVER:
		stop_game_timer()
		return
	
	elapsed_game_time += delta
	
	var new_elapsed_seconds:int = int(floor(elapsed_game_time))
	
	if new_elapsed_seconds == elapsed_game_seconds:
		return
	
	elapsed_game_seconds = new_elapsed_seconds
	game_time_changed.emit(elapsed_game_seconds)


func get_elapsed_time_text() -> String:
	return format_seconds_as_minutes_seconds(elapsed_game_seconds)


func format_seconds_as_minutes_seconds(total_seconds:int) -> String:
	var used_seconds:int = max(total_seconds, 0)
	var minutes:int = int(used_seconds / 60.0)
	var seconds:int = used_seconds % 60
	
	return "%02d:%02d" % [minutes, seconds]

func record_match_result(winner_id:int) -> bool:
	if match_result_recorded:
		return false
	
	if winner_id < 0:
		return false
	
	if winner_id >= number_of_players:
		return false
	
	ensure_score_arrays_match_players()
	
	for player_id in range(number_of_players):
		if player_id == winner_id:
			player_wins[player_id] += 1
		else:
			player_losses[player_id] += 1
	
	match_result_recorded = true
	score_changed.emit()
	
	return true


func ensure_score_arrays_match_players() -> void:
	while player_wins.size() < number_of_players:
		player_wins.append(0)
	
	while player_losses.size() < number_of_players:
		player_losses.append(0)
	
	while player_wins.size() > number_of_players:
		player_wins.pop_back()
	
	while player_losses.size() > number_of_players:
		player_losses.pop_back()


func get_player_wins(player_id:int) -> int:
	ensure_score_arrays_match_players()
	
	if player_id < 0:
		return 0
	
	if player_id >= player_wins.size():
		return 0
	
	return player_wins[player_id]


func get_player_losses(player_id:int) -> int:
	ensure_score_arrays_match_players()
	
	if player_id < 0:
		return 0
	
	if player_id >= player_losses.size():
		return 0
	
	return player_losses[player_id]


func reset_scores() -> void:
	for player_id in range(player_wins.size()):
		player_wins[player_id] = 0
	
	for player_id in range(player_losses.size()):
		player_losses[player_id] = 0
	
	score_changed.emit()


func reset_test_token_trays() -> void:
	if token_tray_inventory == null:
		return
	
	token_tray_inventory.reset_all_trays()
	give_test_tokens()
	
func start_next_round() -> void:
	get_tree().call_group("winning_line_visual", "queue_free")
	current_turn_phase = Global.TURN_PHASE.NONE
	
	var drag_controller:TokenDragController = get_tree().get_first_node_in_group("token drag controller") as TokenDragController
	
	if drag_controller != null:
		drag_controller.cancel_drag()
	
	if placement_state != null and placement_state.has_method("clear_placement_token"):
		placement_state.clear_placement_token()
	
	if board != null:
		await board.empty_board_with_fall_effect()
		board.set_gravity_direction(BoardSetting.GRID_DIRECTION.DOWN, false)
	
	if board_builder != null:
		board_builder.rebuild_board()
	
	reset_test_token_trays()
	start_game()

func apply_match_config() -> void:
	if MatchData.config == null:
		return
	
	number_of_players = MatchData.config.get_player_count()
	player_names.clear()
	player_colours.clear()
	
	for player_id in range(number_of_players):
		var player:MatchPlayerData = MatchData.config.get_player(player_id)
		
		if player == null:
			continue
		
		player_names.append(player.player_name)
		player_colours.append(player.colour_palette)

func apply_board_config() -> void:
	if MatchData.config == null:
		return
	
	board.settings.columns = MatchData.config.board_columns
	board.settings.rows = MatchData.config.board_rows
	board.settings.tokens_to_win = MatchData.config.tokens_to_win
	
	
func give_test_tokens() -> void:
	if token_tray_inventory == null:
		return
	
	#for player_id in range(number_of_players):
		#token_tray_inventory.add_tokens(player_id, TokenLibrary.TokenType.BASIC, 99)
		#token_tray_inventory.add_tokens(player_id, TokenLibrary.TokenType.ANVIL, 3)
		#token_tray_inventory.add_tokens(player_id, TokenLibrary.TokenType.BOMB, 3)
		#token_tray_inventory.add_tokens(player_id, TokenLibrary.TokenType.FAN, 3)
		#token_tray_inventory.add_tokens(player_id, TokenLibrary.TokenType.RAMP, 3)
		#token_tray_inventory.add_tokens(player_id, TokenLibrary.TokenType.TETROMINO, 3)
	#Player 1
	token_tray_inventory.add_tokens(0, TokenLibrary.TokenType.BASIC, 99)
	token_tray_inventory.add_tokens(0, TokenLibrary.TokenType.ANVIL, 2)
	token_tray_inventory.add_tokens(0, TokenLibrary.TokenType.DRILL, 2)
	token_tray_inventory.add_tokens(0, TokenLibrary.TokenType.CHAMELEON, 2)
	token_tray_inventory.add_tokens(0, TokenLibrary.TokenType.FAN, 2)
	#player 2
	token_tray_inventory.add_tokens(1, TokenLibrary.TokenType.BASIC, 99)
	token_tray_inventory.add_tokens(1, TokenLibrary.TokenType.ANVIL, 2)
	token_tray_inventory.add_tokens(1, TokenLibrary.TokenType.DRILL, 2)
	token_tray_inventory.add_tokens(1, TokenLibrary.TokenType.CHAMELEON, 2)
	token_tray_inventory.add_tokens(1, TokenLibrary.TokenType.DAGGER, 2)

	if(number_of_players>=3):
		for i in range(2,number_of_players):
			token_tray_inventory.add_tokens(i, TokenLibrary.TokenType.BASIC, 99)
			token_tray_inventory.add_tokens(i, TokenLibrary.TokenType.ANVIL, 2)
			token_tray_inventory.add_tokens(i, TokenLibrary.TokenType.DRILL, 2)
			token_tray_inventory.add_tokens(i, TokenLibrary.TokenType.CHAMELEON, 2)
			token_tray_inventory.add_tokens(i, TokenLibrary.TokenType.DAGGER, 2)
