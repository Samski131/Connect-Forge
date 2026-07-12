extends Node

signal current_player_changed(player_id:int)
signal players_changed
signal player_names_changed
signal turn_number_changed(turn_number:int)
signal game_time_changed(total_seconds:int)
signal score_changed

const BASIC_TOKEN_COUNT:int = 99

var current_turn_phase:Global.TURN_PHASE = Global.TURN_PHASE.NONE
var current_player_id:int = 0
var current_turn_number:int = 1
var elapsed_game_time:float = 0.0
var elapsed_game_seconds:int = 0
var game_timer_running:bool = false
var match_result_recorded:bool = false

@onready var placement_state:Node = $"Placement State"
@onready var action_state:Node = $"Action State"
@onready var resolution_state:Node = $"Resolution State"
@onready var game_over_state:Node = $"Game Over State"

var board_builder:Node = null
var board:BoardManager = null
var token_tray_inventory:TokenTrayInventory = null
var player_token_trays_ui:PlayerTokenTraysUI = null
var connected_match_config:MatchConfig = null


func _ready() -> void:
	gather_groups()
	connect_match_data_signals()
	connect_match_config_signals()
	apply_board_config()
	setup_token_tray_inventory()
	setup_states()
	rebuild_player_trays()
	start_game()


func gather_groups() -> void:
	board = get_tree().get_first_node_in_group("board pool") as BoardManager
	board_builder = get_tree().get_first_node_in_group("board builder")
	player_token_trays_ui = get_tree().get_first_node_in_group("player token trays ui") as PlayerTokenTraysUI


func setup_states() -> void:
	if placement_state != null:
		placement_state.setup(self, board)
	
	if action_state != null:
		action_state.setup(self, board)
	
	if resolution_state != null:
		resolution_state.setup(self, board)
	
	if game_over_state != null:
		game_over_state.setup(self, board)


func connect_match_data_signals() -> void:
	if MatchData.config_changed.is_connected(_on_match_config_changed) == false:
		MatchData.config_changed.connect(_on_match_config_changed)


func connect_match_config_signals() -> void:
	disconnect_match_config_signals()
	
	if MatchData.config == null:
		return
	
	connected_match_config = MatchData.config
	
	if connected_match_config.players_changed.is_connected(_on_match_players_changed) == false:
		connected_match_config.players_changed.connect(_on_match_players_changed)
	
	if connected_match_config.board_settings_changed.is_connected(_on_board_settings_changed) == false:
		connected_match_config.board_settings_changed.connect(_on_board_settings_changed)
	
	if connected_match_config.token_settings_changed.is_connected(_on_token_settings_changed) == false:
		connected_match_config.token_settings_changed.connect(_on_token_settings_changed)


func disconnect_match_config_signals() -> void:
	if connected_match_config == null:
		return
	
	if connected_match_config.players_changed.is_connected(_on_match_players_changed):
		connected_match_config.players_changed.disconnect(_on_match_players_changed)
	
	if connected_match_config.board_settings_changed.is_connected(_on_board_settings_changed):
		connected_match_config.board_settings_changed.disconnect(_on_board_settings_changed)
	
	if connected_match_config.token_settings_changed.is_connected(_on_token_settings_changed):
		connected_match_config.token_settings_changed.disconnect(_on_token_settings_changed)
	
	connected_match_config = null


func _on_match_config_changed() -> void:
	connect_match_config_signals()
	apply_board_config()
	
	if token_tray_inventory != null:
		setup_token_trays_from_match_data()
	
	if current_player_id >= get_player_count():
		current_player_id = 0
	
	rebuild_player_trays()
	players_changed.emit()
	player_names_changed.emit()
	score_changed.emit()


func _on_match_players_changed() -> void:
	if token_tray_inventory != null:
		setup_token_trays_from_match_data()
	
	if current_player_id >= get_player_count():
		current_player_id = 0
	
	rebuild_player_trays()
	players_changed.emit()
	player_names_changed.emit()
	score_changed.emit()


func _on_board_settings_changed() -> void:
	apply_board_config()


func _on_token_settings_changed() -> void:
	if token_tray_inventory == null:
		return
	
	setup_token_trays_from_match_data()


func get_match_config() -> MatchConfig:
	return MatchData.config


func get_player_data(player_id:int) -> MatchPlayerData:
	if MatchData.config == null:
		return null
	
	return MatchData.config.get_player(player_id)


func get_player_count() -> int:
	if MatchData.config == null:
		return 0
	
	return MatchData.config.get_player_count()


func get_minimum_player_count() -> int:
	return MatchConfig.MINIMUM_PLAYERS


func get_maximum_player_count() -> int:
	return MatchConfig.MAXIMUM_PLAYERS


func get_player_name(player_id:int) -> String:
	if MatchData.config == null:
		return "Player " + str(player_id + 1)
	
	return MatchData.config.get_player_name(player_id)


func get_player_palette(player_id:int) -> ColorPalette:
	if MatchData.config == null:
		return null
	
	return MatchData.config.get_player_palette(player_id)


func is_valid_player_id(player_id:int) -> bool:
	if player_id < 0:
		return false
	
	if player_id >= get_player_count():
		return false
	
	return true


func add_player() -> bool:
	if MatchData.config == null:
		return false
	
	var new_player_id:int = get_player_count()
	var player_name:String = "Player " + str(new_player_id + 1)
	var palette:ColorPalette = get_default_palette_for_player(new_player_id)
	
	if palette == null:
		return false
	
	return MatchData.config.add_player(player_name, palette)


func remove_player() -> bool:
	if MatchData.config == null:
		return false
	
	return MatchData.config.remove_last_player()


func set_player_name(player_id:int, new_name:String) -> bool:
	if MatchData.config == null:
		return false
	
	return MatchData.config.set_player_name(player_id, new_name)


func set_player_palette(player_id:int, palette:ColorPalette) -> bool:
	if MatchData.config == null:
		return false
	
	return MatchData.config.set_player_palette(player_id, palette)


func get_default_palette_for_player(player_id:int) -> ColorPalette:
	var palettes:Array[ColorPalette] = [
		MatchData.YELLOW_PALETTE,
		MatchData.RED_PALETTE,
		MatchData.GREEN_PALETTE,
		MatchData.PINK_PALETTE,
		MatchData.VIOLET_PALETTE,
		MatchData.BLUE_PALETTE
	]
	
	if palettes.is_empty():
		return null
	
	var palette_index:int = player_id % palettes.size()
	return palettes[palette_index]


func apply_board_config() -> void:
	if MatchData.config == null:
		return
	
	if board == null:
		return
	
	if board.settings == null:
		return
	
	board.settings.columns = MatchData.config.board_columns
	board.settings.rows = MatchData.config.board_rows
	board.settings.tokens_to_win = MatchData.config.tokens_to_win


func start_game() -> void:
	match_result_recorded = false
	current_turn_number = 1
	turn_number_changed.emit(current_turn_number)
	reset_game_timer()
	start_game_timer()
	
	if get_player_count() <= 0:
		current_turn_phase = Global.TURN_PHASE.NONE
		return
	
	start_turn(0)


func start_turn(player_id:int) -> void:
	if is_valid_player_id(player_id) == false:
		return
	
	current_player_id = player_id
	current_player_changed.emit(current_player_id)
	
	if placement_state != null:
		placement_state.enter_state()


func end_turn() -> void:
	if get_player_count() <= 0:
		return
	
	var next_player_id:int = get_next_player_id()
	
	if has_completed_full_turn(next_player_id):
		current_turn_number += 1
		turn_number_changed.emit(current_turn_number)
	
	start_turn(next_player_id)


func has_completed_full_turn(next_player_id:int) -> bool:
	if get_player_count() <= 1:
		return true
	
	if next_player_id == 0 and current_player_id != 0:
		return true
	
	return false


func get_next_player_id() -> int:
	var player_count:int = get_player_count()
	
	if player_count <= 0:
		return 0
	
	return (current_player_id + 1) % player_count


func _process(delta:float) -> void:
	update_game_timer(delta)
	debug_gravity_changes()
	
	match current_turn_phase:
		Global.TURN_PHASE.PLACEMENT:
			if placement_state != null:
				placement_state.process_state()
		
		Global.TURN_PHASE.ACTION:
			if action_state != null:
				action_state.process_state()
		
		Global.TURN_PHASE.RESOLUTION:
			if resolution_state != null:
				resolution_state.process_state()


func reset_game() -> void:
	if board_builder != null:
		board_builder.rebuild_board()
	
	reset_token_trays()
	get_tree().call_group("winning_line_visual", "queue_free")
	start_game()


func debug_gravity_changes() -> void:
	if board == null:
		return
	
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
	
	if changed == false:
		return
	
	if placement_state != null and placement_state.has_method("clear_placement_token"):
		placement_state.clear_placement_token()
	
	if action_state != null:
		action_state.enter_state()


func setup_token_tray_inventory() -> void:
	token_tray_inventory = get_tree().get_first_node_in_group("token tray inventory") as TokenTrayInventory
	
	if token_tray_inventory == null:
		token_tray_inventory = TokenTrayInventory.new()
		token_tray_inventory.add_to_group("token tray inventory")
		add_child(token_tray_inventory)
	
	setup_token_trays_from_match_data()


func setup_token_trays_from_match_data() -> void:
	if token_tray_inventory == null:
		return
	
	token_tray_inventory.setup_for_players(get_player_count())
	
	for player_id in range(get_player_count()):
		load_player_tokens_into_tray(player_id)


func load_player_tokens_into_tray(player_id:int) -> void:
	if token_tray_inventory == null:
		return
	
	var player:MatchPlayerData = get_player_data(player_id)
	
	if player == null:
		return
	
	token_tray_inventory.set_token_count(player_id, TokenLibrary.TokenType.BASIC, BASIC_TOKEN_COUNT)
	
	for token_type_value in player.selected_tokens.keys():
		var token_type:int = int(token_type_value)
		var token_count:int = player.get_token_count(token_type)
		
		if token_count <= 0:
			continue
		
		token_tray_inventory.set_token_count(player_id, token_type, token_count)


func reset_token_trays() -> void:
	setup_token_trays_from_match_data()


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
	
	if is_valid_player_id(winner_id) == false:
		return false
	
	for player_id in range(get_player_count()):
		var player:MatchPlayerData = get_player_data(player_id)
		
		if player == null:
			continue
		
		if player_id == winner_id:
			player.wins += 1
		else:
			player.losses += 1
	
	match_result_recorded = true
	score_changed.emit()
	return true


func get_player_wins(player_id:int) -> int:
	var player:MatchPlayerData = get_player_data(player_id)
	
	if player == null:
		return 0
	
	return player.wins


func get_player_losses(player_id:int) -> int:
	var player:MatchPlayerData = get_player_data(player_id)
	
	if player == null:
		return 0
	
	return player.losses


func reset_scores() -> void:
	if MatchData.config == null:
		return
	
	for player in MatchData.config.players:
		if player == null:
			continue
		
		player.wins = 0
		player.losses = 0
	
	score_changed.emit()


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
	
	apply_board_config()
	
	if board_builder != null:
		board_builder.rebuild_board()
	
	reset_token_trays()
	start_game()
