class_name GameManager
extends Node

signal current_player_changed(player_id:int)
signal players_changed
signal player_names_changed
signal turn_number_changed(turn_number:int)
signal game_time_changed(total_seconds:int)
signal score_changed

var session:MatchSession = null

@onready var placement_state:Node = $"Placement State"
@onready var action_state:Node = $"Action State"
@onready var resolution_state:Node = $"Resolution State"
@onready var game_over_state:Node = $"Game Over State"

var board_builder:BoardBuilder = null
var board:BoardManager = null
var token_tray_inventory:TokenTrayInventory = null
var player_token_trays_ui:PlayerTokenTraysUI = null
var turn_timer:MatchTurnTimer = null
var token_drag_controller:TokenDragController = null
var game_over_menu:GameOverMenu = null

var connected_session:MatchSession = null
var is_initialized:bool = false


func setup(new_board_builder:BoardBuilder, new_board:BoardManager, new_token_tray_inventory:TokenTrayInventory, new_player_token_trays_ui:PlayerTokenTraysUI, new_turn_timer:MatchTurnTimer, new_token_drag_controller:TokenDragController, new_game_over_menu:GameOverMenu) -> void:
	board_builder = new_board_builder
	board = new_board
	token_tray_inventory = new_token_tray_inventory
	player_token_trays_ui = new_player_token_trays_ui
	turn_timer = new_turn_timer
	token_drag_controller = new_token_drag_controller
	game_over_menu = new_game_over_menu


func initialize_game() -> void:
	if is_initialized:
		return
	
	if validate_dependencies() == false:
		return
	
	if create_match_session() == false:
		return
	
	apply_board_session(false)
	board_builder.rebuild_board(false)
	
	if setup_token_inventory_from_session() == false:
		return
	
	setup_states()
	
	is_initialized = true
	
	players_changed.emit()
	player_names_changed.emit()
	score_changed.emit()
	
	start_game()


func create_match_session() -> bool:
	disconnect_session_signals()
	
	session = MatchData.create_session_from_config()
	
	if session == null:
		push_error("GameManager: MatchData could not create a MatchSession.")
		return false
	
	board.set_match_session(session)
	
	connected_session = session
	connect_session_signals()
	return true


func validate_dependencies() -> bool:
	var dependencies_are_valid:bool = true
	
	if board_builder == null:
		push_error("GameManager: BoardBuilder dependency is missing.")
		dependencies_are_valid = false
	
	if board == null:
		push_error("GameManager: BoardManager dependency is missing.")
		dependencies_are_valid = false
	
	if token_tray_inventory == null:
		push_error("GameManager: TokenTrayInventory dependency is missing.")
		dependencies_are_valid = false
	
	if player_token_trays_ui == null:
		push_error("GameManager: PlayerTokenTraysUI dependency is missing.")
		dependencies_are_valid = false
	
	if turn_timer == null:
		push_error("GameManager: MatchTurnTimer dependency is missing.")
		dependencies_are_valid = false
	
	if token_drag_controller == null:
		push_error("GameManager: TokenDragController dependency is missing.")
		dependencies_are_valid = false
	
	if game_over_menu == null:
		push_error("GameManager: GameOverMenu dependency is missing.")
		dependencies_are_valid = false
	
	return dependencies_are_valid


func setup_states() -> void:
	if placement_state != null:
		placement_state.setup(self, board)
	
	if action_state != null:
		action_state.setup(self, board)
	
	if resolution_state != null:
		resolution_state.setup(self, board)
	
	if game_over_state != null:
		game_over_state.setup(self, board, game_over_menu)


func connect_session_signals() -> void:
	if connected_session == null:
		return
	
	if connected_session.players_changed.is_connected(_on_session_players_changed) == false:
		connected_session.players_changed.connect(_on_session_players_changed)
	
	if connected_session.current_player_changed.is_connected(_on_session_current_player_changed) == false:
		connected_session.current_player_changed.connect(_on_session_current_player_changed)
	
	if connected_session.turn_number_changed.is_connected(_on_session_turn_number_changed) == false:
		connected_session.turn_number_changed.connect(_on_session_turn_number_changed)
	
	if connected_session.game_time_changed.is_connected(_on_session_game_time_changed) == false:
		connected_session.game_time_changed.connect(_on_session_game_time_changed)
	
	if connected_session.score_changed.is_connected(_on_session_score_changed) == false:
		connected_session.score_changed.connect(_on_session_score_changed)


func disconnect_session_signals() -> void:
	if connected_session == null:
		return
	
	if connected_session.players_changed.is_connected(_on_session_players_changed):
		connected_session.players_changed.disconnect(_on_session_players_changed)
	
	if connected_session.current_player_changed.is_connected(_on_session_current_player_changed):
		connected_session.current_player_changed.disconnect(_on_session_current_player_changed)
	
	if connected_session.turn_number_changed.is_connected(_on_session_turn_number_changed):
		connected_session.turn_number_changed.disconnect(_on_session_turn_number_changed)
	
	if connected_session.game_time_changed.is_connected(_on_session_game_time_changed):
		connected_session.game_time_changed.disconnect(_on_session_game_time_changed)
	
	if connected_session.score_changed.is_connected(_on_session_score_changed):
		connected_session.score_changed.disconnect(_on_session_score_changed)
	
	connected_session = null


func _on_session_players_changed() -> void:
	players_changed.emit()
	player_names_changed.emit()


func _on_session_current_player_changed(player_id:int) -> void:
	current_player_changed.emit(player_id)


func _on_session_turn_number_changed(turn_number:int) -> void:
	turn_number_changed.emit(turn_number)


func _on_session_game_time_changed(total_seconds:int) -> void:
	game_time_changed.emit(total_seconds)


func _on_session_score_changed() -> void:
	score_changed.emit()


func get_current_turn_phase() -> Global.TURN_PHASE:
	if session == null:
		return Global.TURN_PHASE.NONE
	
	return session.current_turn_phase


func set_current_turn_phase(new_phase:Global.TURN_PHASE) -> void:
	if session == null:
		return
	
	session.set_turn_phase(new_phase)


func get_current_player_id() -> int:
	if session == null:
		return -1
	
	return session.current_player_id


func set_current_player_id(player_id:int) -> bool:
	if session == null:
		return false
	
	return session.set_current_player(player_id)


func get_current_turn_number() -> int:
	if session == null:
		return 1
	
	return session.current_turn_number


func set_current_turn_number(new_turn_number:int) -> void:
	if session == null:
		return
	
	session.set_turn_number(new_turn_number)


func increment_current_turn_number() -> void:
	if session == null:
		return
	
	session.increment_turn_number()


func get_session_player_data(player_id:int) -> MatchSessionPlayerData:
	if session == null:
		return null
	
	return session.get_player(player_id)


func get_player_count() -> int:
	if session == null:
		return 0
	
	return session.get_player_count()


func get_player_name(player_id:int) -> String:
	if session == null:
		return "Player " + str(player_id + 1)
	
	return session.get_player_name(player_id)


func get_player_palette(player_id:int) -> ColorPalette:
	if session == null:
		return null
	
	return session.get_player_palette(player_id)


func is_valid_player_id(player_id:int) -> bool:
	if session == null:
		return false
	
	return session.is_valid_player_id(player_id)


func get_current_round_number() -> int:
	if session == null:
		return 1
	
	return session.current_round_number


func get_turn_timer_seconds() -> int:
	if session == null:
		return 0
	
	return session.get_turn_timer_seconds()


func apply_board_session(rebuild_if_size_changed:bool = true) -> void:
	if session == null:
		return
	
	if board_builder != null:
		board_builder.apply_match_session(session, rebuild_if_size_changed)
		return
	
	if board == null:
		return
	
	if board.settings == null:
		return
	
	board.settings.columns = session.get_board_columns()
	board.settings.rows = session.get_board_rows()
	board.settings.tokens_to_win = session.get_tokens_to_win()
	board.refresh_gravity_order()


func start_game() -> void:
	if session == null:
		return
	
	if get_player_count() <= 0:
		set_current_turn_phase(Global.TURN_PHASE.NONE)
		return
	
	var starting_player_id:int = session.get_resolved_starting_player_id()
	
	if is_valid_player_id(starting_player_id) == false:
		starting_player_id = 0
	
	session.prepare_first_round(starting_player_id)
	session.start_game_timer()
	
	start_turn(starting_player_id)
	
	turn_number_changed.emit(get_current_turn_number())
	game_time_changed.emit(session.elapsed_game_seconds)
	score_changed.emit()


func start_turn(player_id:int) -> void:
	if session == null:
		return
	
	if is_valid_player_id(player_id) == false:
		return
	
	var player_changed:bool = get_current_player_id() != player_id
	
	set_current_player_id(player_id)
	
	if player_changed == false:
		current_player_changed.emit(player_id)
	
	if placement_state != null:
		placement_state.enter_state()
	
	start_turn_timer()


func end_turn() -> void:
	if session == null:
		return
	
	if get_player_count() <= 0:
		return
	
	var next_player_id:int = get_next_player_id()
	
	if has_completed_full_turn(next_player_id):
		increment_current_turn_number()
	
	start_turn(next_player_id)


func has_completed_full_turn(next_player_id:int) -> bool:
	if get_player_count() <= 1:
		return true
	
	if next_player_id == 0 and get_current_player_id() != 0:
		return true
	
	return false


func get_next_player_id() -> int:
	if session == null:
		return -1
	
	return session.get_next_player_id()


func _process(delta:float) -> void:
	if session != null:
		session.update_game_timer(delta)
	
	debug_gravity_changes()
	
	match get_current_turn_phase():
		Global.TURN_PHASE.ACTION:
			if action_state != null:
				action_state.process_state()
		
		Global.TURN_PHASE.RESOLUTION:
			if resolution_state != null:
				resolution_state.process_state()


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
	
	if action_state != null:
		action_state.enter_state()


func setup_token_inventory_from_session() -> bool:
	if token_tray_inventory == null:
		push_error("GameManager: TokenTrayInventory dependency is missing.")
		return false
	
	if session == null:
		push_error("GameManager: Cannot configure gameplay inventory without a MatchSession.")
		return false
	
	return token_tray_inventory.setup_for_session(session)


func rebuild_player_trays() -> void:
	if player_token_trays_ui == null:
		return
	
	player_token_trays_ui.rebuild_trays()


func reset_game_timer() -> void:
	if session == null:
		return
	
	session.reset_game_timer()


func start_game_timer() -> void:
	if session == null:
		return
	
	session.start_game_timer()


func stop_game_timer() -> void:
	if session == null:
		return
	
	session.stop_game_timer()


func get_elapsed_game_seconds() -> int:
	if session == null:
		return 0
	
	return session.elapsed_game_seconds


func get_elapsed_time_text() -> String:
	if session == null:
		return "00:00"
	
	return session.get_elapsed_time_text()


func format_seconds_as_minutes_seconds(total_seconds:int) -> String:
	if session != null:
		return session.format_seconds_as_minutes_seconds(total_seconds)
	
	var used_seconds:int = max(total_seconds, 0)
	var minutes:int = int(used_seconds / 60.0)
	var seconds:int = used_seconds % 60
	
	return "%02d:%02d" % [minutes, seconds]


func record_match_result(winner_id:int) -> bool:
	if session == null:
		return false
	
	return session.record_match_result(winner_id)


func get_player_wins(player_id:int) -> int:
	if session == null:
		return 0
	
	return session.get_player_wins(player_id)


func get_player_losses(player_id:int) -> int:
	if session == null:
		return 0
	
	return session.get_player_losses(player_id)


func start_next_round() -> void:
	if session == null:
		return
	
	get_tree().call_group("winning_line_visual", "queue_free")
	set_current_turn_phase(Global.TURN_PHASE.NONE)
	stop_turn_timer()
	
	if token_drag_controller != null:
		token_drag_controller.cancel_drag()
	
	if board != null:
		await board.empty_board_with_fall_effect()
		board.set_gravity_direction(BoardSetting.GRID_DIRECTION.DOWN, false)
	
	apply_board_session(false)
	
	if board_builder != null:
		board_builder.rebuild_board(false)
	
	var starting_player_id:int = session.get_resolved_starting_player_id()
	
	if is_valid_player_id(starting_player_id) == false:
		starting_player_id = 0
	
	session.prepare_next_round(starting_player_id)
	session.start_game_timer()
	
	start_turn(starting_player_id)


func start_turn_timer() -> void:
	if turn_timer == null:
		return
	
	turn_timer.start_turn_timer()


func stop_turn_timer() -> void:
	if turn_timer == null:
		return
	
	turn_timer.stop_turn_timer()
