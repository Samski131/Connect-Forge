class_name GameManager
extends Node

signal current_player_changed(player_id:int)
signal players_changed
signal turn_number_changed(turn_number:int)
signal game_time_changed(total_seconds:int)
signal score_changed
signal token_type_added(player_id:int, token_type:int)
signal token_count_changed(player_id:int, token_type:int, new_count:int)
signal tokens_reset

var session:MatchSession = null

@onready var placement_state:PlacementLogic = $"Placement State"
@onready var action_state:ActionLogic = $"Action State"
@onready var resolution_state:ResolutionLogic = $"Resolution State"

var board_builder:BoardBuilder = null
var board:BoardManager = null
var turn_timer:MatchTurnTimer = null
var token_drag_controller:TokenDragController = null
var game_over_menu:GameOverMenu = null

var connected_session:MatchSession = null
var is_initialized:bool = false
var network_match_controller:NetworkMatchController = null
var replay_recorder:ReplayRecorder = null

func setup(new_board_builder:BoardBuilder, new_board:BoardManager, new_turn_timer:MatchTurnTimer, new_token_drag_controller:TokenDragController, new_game_over_menu:GameOverMenu) -> void:
	board_builder = new_board_builder
	board = new_board
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
	
	setup_states()
	setup_network_match_controller()
	setup_replay_recorder()

	is_initialized = true
	
	players_changed.emit()
	score_changed.emit()
	
	start_game()

func _exit_tree() -> void:
	if replay_recorder == null:
		return
	
	if replay_recorder.is_recording() == false:
		return
	
	var round_number:int = 1
	var turn_number:int = 1
	var player_id:int = -1
	var scores:Array = []
	
	if session != null:
		round_number = session.current_round_number
		turn_number = session.current_turn_number
		player_id = session.current_player_id
		scores = create_replay_score_snapshot()
	
	if replay_recorder.record_match_end(round_number, turn_number, player_id, scores, "scene_exit") == false:
		DebugOverlay.log_error("ReplayRecorder", "Could not record the match-end boundary.")
	
	replay_recorder.save_replay()
	
	
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

func setup_network_match_controller() -> void:
	if network_match_controller != null:
		return
	
	network_match_controller = NetworkMatchController.new()
	network_match_controller.name = "Network Match Controller"
	add_child(network_match_controller)
	network_match_controller.set_multiplayer_authority(1)
	network_match_controller.setup(self)
	
	if game_over_menu != null:
		game_over_menu.refresh_network_controls()


func is_network_match_active() -> bool:
	if network_match_controller == null:
		return false
	
	return network_match_controller.is_active()

func is_network_match_host() -> bool:
	if network_match_controller == null:
		return false
	
	if network_match_controller.is_active() == false:
		return false
	
	return network_match_controller.is_host()
	
	
func should_spend_token_when_drag_begins() -> bool:
	return is_network_match_active() == false

func enter_placement_phase() -> bool:
	if placement_state == null:
		return false
	
	set_current_turn_phase(Global.TURN_PHASE.PLACEMENT)
	return true


func try_place_dragged_token(token_type:int, slot_pos:Vector2i, start_flipped:bool) -> bool:
	if placement_state == null:
		return false
	
	if is_network_match_active():
		return network_match_controller.request_local_token_placement(token_type, slot_pos, start_flipped)
	
	return placement_state.try_place_dragged_token(token_type, slot_pos, start_flipped)
	
	
func reproduce_authoritative_token_placement(player_id:int, token_type:int, slot_pos:Vector2i, start_flipped:bool, placement_data:Dictionary) -> bool:
	if placement_state == null:
		return false
	
	if is_valid_player_id(player_id) == false:
		return false
	
	if TokenLibrary.get_token_data(token_type).is_empty():
		return false
	
	if TokenLibrary.get_token_scene(token_type) == null:
		return false
	
	if get_current_player_id() != player_id:
		set_current_player_id(player_id)
	
	if get_current_turn_phase() != Global.TURN_PHASE.PLACEMENT:
		set_current_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	if spend_token(player_id, token_type) == false:
		return false
	
	var placed:bool = placement_state.try_place_dragged_token(token_type, slot_pos, start_flipped, placement_data)
	
	if placed == false:
		refund_token(player_id, token_type)
		return false
	
	return true


func is_valid_starting_slot(slot_pos:Vector2i) -> bool:
	if placement_state == null:
		return false
	
	return placement_state.is_valid_starting_slot(slot_pos)

func enter_action_phase() -> bool:
	if action_state == null:
		return false
	
	set_current_turn_phase(Global.TURN_PHASE.ACTION)
	action_state.enter_state()
	return true


func enter_resolution_phase() -> bool:
	if resolution_state == null:
		return false
	
	set_current_turn_phase(Global.TURN_PHASE.RESOLUTION)
	resolution_state.enter_state()
	return true

func finish_match_with_winner(winner_id:int, winning_slots:Array[Vector2i] = []) -> bool:
	if is_valid_player_id(winner_id) == false:
		return false
	
	if is_network_match_active():
		return network_match_controller.handle_local_winner_found(winner_id, winning_slots)
	
	return apply_match_result_locally(winner_id)


func apply_authoritative_match_result(winner_id:int, winning_slots:Array[Vector2i]) -> bool:
	if is_valid_player_id(winner_id) == false:
		return false
	
	if resolution_state != null:
		resolution_state.ensure_authoritative_winning_line(winner_id, winning_slots)
	
	return apply_match_result_locally(winner_id)


func apply_match_result_locally(winner_id:int) -> bool:
	if is_valid_player_id(winner_id) == false:
		return false
	
	if record_match_result(winner_id) == false:
		return false
	
	set_current_turn_phase(Global.TURN_PHASE.GAME_OVER)
	stop_game_timer()
	stop_turn_timer()
	
	if game_over_menu != null:
		game_over_menu.show_game_over(winner_id)
	
	return true

func create_network_match_snapshot() -> Dictionary:
	if session == null:
		return {}
	
	if board == null:
		return {}
	
	if board.settings == null:
		return {}
	
	return {
		"gravity_direction": int(board.settings.gravity_direction),
		"board_tokens": board.create_network_board_snapshot(),
		"token_counts": session.create_network_token_count_snapshot()
	}


func apply_authoritative_network_match_snapshot(snapshot:Dictionary) -> bool:
	if session == null:
		return false
	
	if board == null:
		return false
	
	if snapshot.has("gravity_direction") == false:
		return false
	
	if snapshot.has("board_tokens") == false:
		return false
	
	if snapshot.has("token_counts") == false:
		return false
	
	if typeof(snapshot["board_tokens"]) != TYPE_ARRAY:
		return false
	
	if typeof(snapshot["token_counts"]) != TYPE_ARRAY:
		return false
	
	var gravity_direction_value:int = int(snapshot["gravity_direction"])
	
	if is_valid_network_gravity_direction(gravity_direction_value) == false:
		return false
	
	var board_snapshot:Array = snapshot["board_tokens"]
	var token_count_snapshot:Array = snapshot["token_counts"]
	
	if board.is_network_board_snapshot_valid(board_snapshot) == false:
		return false
	
	if session.is_network_token_count_snapshot_valid(token_count_snapshot) == false:
		return false
	
	var gravity_direction:BoardSetting.GRID_DIRECTION = gravity_direction_value
	board.set_gravity_direction(gravity_direction, false)
	
	if board.apply_network_board_snapshot(board_snapshot) == false:
		return false
	
	if session.apply_network_token_count_snapshot(token_count_snapshot) == false:
		return false
	
	return true


func is_valid_network_gravity_direction(gravity_direction_value:int) -> bool:
	if gravity_direction_value == int(BoardSetting.GRID_DIRECTION.UP):
		return true
	
	if gravity_direction_value == int(BoardSetting.GRID_DIRECTION.RIGHT):
		return true
	
	if gravity_direction_value == int(BoardSetting.GRID_DIRECTION.DOWN):
		return true
	
	if gravity_direction_value == int(BoardSetting.GRID_DIRECTION.LEFT):
		return true
	
	return false
	
func connect_session_signals() -> void:
	if connected_session == null:
		return
	
	if connected_session.current_player_changed.is_connected(_on_session_current_player_changed) == false:
		connected_session.current_player_changed.connect(_on_session_current_player_changed)
	
	if connected_session.turn_number_changed.is_connected(_on_session_turn_number_changed) == false:
		connected_session.turn_number_changed.connect(_on_session_turn_number_changed)
	
	if connected_session.game_time_changed.is_connected(_on_session_game_time_changed) == false:
		connected_session.game_time_changed.connect(_on_session_game_time_changed)
	
	if connected_session.score_changed.is_connected(_on_session_score_changed) == false:
		connected_session.score_changed.connect(_on_session_score_changed)
	
	if connected_session.token_type_added.is_connected(_on_session_token_type_added) == false:
		connected_session.token_type_added.connect(_on_session_token_type_added)
	
	if connected_session.token_count_changed.is_connected(_on_session_token_count_changed) == false:
		connected_session.token_count_changed.connect(_on_session_token_count_changed)
	
	if connected_session.all_tokens_reset.is_connected(_on_session_all_tokens_reset) == false:
		connected_session.all_tokens_reset.connect(_on_session_all_tokens_reset)


func disconnect_session_signals() -> void:
	if connected_session == null:
		return
	
	if connected_session.current_player_changed.is_connected(_on_session_current_player_changed):
		connected_session.current_player_changed.disconnect(_on_session_current_player_changed)
	
	if connected_session.turn_number_changed.is_connected(_on_session_turn_number_changed):
		connected_session.turn_number_changed.disconnect(_on_session_turn_number_changed)
	
	if connected_session.game_time_changed.is_connected(_on_session_game_time_changed):
		connected_session.game_time_changed.disconnect(_on_session_game_time_changed)
	
	if connected_session.score_changed.is_connected(_on_session_score_changed):
		connected_session.score_changed.disconnect(_on_session_score_changed)
	
	if connected_session.token_type_added.is_connected(_on_session_token_type_added):
		connected_session.token_type_added.disconnect(_on_session_token_type_added)
	
	if connected_session.token_count_changed.is_connected(_on_session_token_count_changed):
		connected_session.token_count_changed.disconnect(_on_session_token_count_changed)
	
	if connected_session.all_tokens_reset.is_connected(_on_session_all_tokens_reset):
		connected_session.all_tokens_reset.disconnect(_on_session_all_tokens_reset)
	
	connected_session = null


func _on_session_current_player_changed(player_id:int) -> void:
	current_player_changed.emit(player_id)


func _on_session_turn_number_changed(turn_number:int) -> void:
	turn_number_changed.emit(turn_number)


func _on_session_game_time_changed(total_seconds:int) -> void:
	game_time_changed.emit(total_seconds)


func _on_session_score_changed() -> void:
	score_changed.emit()


func _on_session_token_type_added(player_id:int, token_type:int) -> void:
	token_type_added.emit(player_id, token_type)


func _on_session_token_count_changed(player_id:int, token_type:int, new_count:int) -> void:
	token_count_changed.emit(player_id, token_type, new_count)


func _on_session_all_tokens_reset() -> void:
	tokens_reset.emit()


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

func get_current_round_number() -> int:
	if session == null:
		return 1
	
	return session.current_round_number


func get_resolved_round_starting_player_id() -> int:
	if session == null:
		return -1
	
	return session.get_resolved_starting_player_id()
	
	
func set_current_turn_number(new_turn_number:int) -> void:
	if session == null:
		return
	
	session.set_turn_number(new_turn_number)


func increment_current_turn_number() -> void:
	if session == null:
		return
	
	session.increment_turn_number()


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


func get_token_types_for_player(player_id:int) -> Array[int]:
	if session == null:
		var empty_types:Array[int] = []
		return empty_types
	
	return session.get_token_types_for_player(player_id)


func get_token_count(player_id:int, token_type:int) -> int:
	if session == null:
		return 0
	
	return session.get_token_count(player_id, token_type)


func can_player_drag_token(player_id:int, token_type:int) -> bool:
	if session == null:
		return false
	
	if LobbyData.has_active_lobby():
		if network_match_controller == null:
			return false
		
		if network_match_controller.is_active() == false:
			return false
		
		if network_match_controller.can_local_player_drag_token(player_id, token_type) == false:
			return false
	
	if player_id != get_current_player_id():
		return false
	
	if session.is_valid_player_id(player_id) == false:
		return false
	
	if session.player_has_token(player_id, token_type) == false:
		return false
	
	if TokenLibrary.get_token_scene(token_type) == null:
		return false
	
	return true

func spend_token(player_id:int, token_type:int) -> bool:
	if session == null:
		return false
	
	return session.spend_token(player_id, token_type)


func refund_token(player_id:int, token_type:int, amount:int = 1) -> bool:
	if session == null:
		return false
	
	return session.refund_token(player_id, token_type, amount)


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
	
	if replay_recorder != null:
		if replay_recorder.is_recording():
			replay_recorder.record_match_start(session.current_round_number, session.current_turn_number, starting_player_id)
			
			var gravity:String = ReplayFormat.GRAVITY_DOWN
			
			if board != null:
				var board_gravity:String = board.get_replay_gravity_id(board.settings.gravity_direction)
				
				if board_gravity != "":
					gravity = board_gravity
			
			replay_recorder.record_round_start(session.current_round_number, session.current_turn_number, starting_player_id, gravity)
	
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
	
	if replay_recorder != null:
		if replay_recorder.is_recording():
			if replay_recorder.record_turn_start(session.current_round_number, session.current_turn_number, player_id) == false:
				DebugOverlay.log_error("ReplayRecorder", "Could not record the start of round %d turn %d." % [session.current_round_number, session.current_turn_number])
	
	enter_placement_phase()
	start_turn_timer()


func end_turn() -> void:
	if session == null:
		return
	
	if get_player_count() <= 0:
		return
	
	if is_network_match_active():
		if network_match_controller.handle_local_turn_finished():
			return
	
	advance_to_next_turn()


func advance_to_next_turn() -> void:
	if replay_recorder != null:
		if replay_recorder.is_recording():
			if replay_recorder.record_turn_end() == false:
				DebugOverlay.log_error("ReplayRecorder", "Could not record the end of the current turn.")
	
	var next_player_id:int = get_next_player_id()
	
	if has_completed_full_turn(next_player_id):
		increment_current_turn_number()
	
	start_turn(next_player_id)
	
	

func handle_turn_timeout() -> void:
	if session == null:
		return
	
	if get_current_turn_phase() != Global.TURN_PHASE.PLACEMENT:
		return
	
	if is_network_match_active():
		if network_match_controller.handle_turn_timeout():
			return
	
	set_current_turn_phase(Global.TURN_PHASE.NONE)
	
	if token_drag_controller != null:
		token_drag_controller.cancel_drag()
	
	end_turn()
	
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
	if is_network_match_active():
		return
	
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
	
	enter_action_phase()


func stop_game_timer() -> void:
	if session == null:
		return
	
	session.stop_game_timer()


func get_elapsed_time_text() -> String:
	if session == null:
		return "00:00"
	
	return session.get_elapsed_time_text()


func record_match_result(winner_id:int) -> bool:
	if session == null:
		return false
	
	if session.record_match_result(winner_id) == false:
		return false
	
	if replay_recorder != null:
		if replay_recorder.is_recording():
			var scores:Array = create_replay_score_snapshot()
			
			if replay_recorder.record_round_end(session.current_round_number, session.current_turn_number, winner_id, scores) == false:
				DebugOverlay.log_error("ReplayRecorder", "Could not record the end of round %d." % session.current_round_number)
			
			replay_recorder.save_replay()
	
	return true


func get_player_wins(player_id:int) -> int:
	if session == null:
		return 0
	
	return session.get_player_wins(player_id)


func request_next_round() -> bool:
	if session == null:
		return false
	
	if is_network_match_active():
		return network_match_controller.request_next_round()
	
	start_next_round()
	return true


func start_next_round() -> void:
	if session == null:
		return
	
	var starting_player_id:int = session.get_resolved_starting_player_id()
	
	if is_valid_player_id(starting_player_id) == false:
		starting_player_id = 0
	
	await start_next_round_with_player(starting_player_id)


func start_next_round_with_player(starting_player_id:int) -> void:
	if session == null:
		return
	
	if is_valid_player_id(starting_player_id) == false:
		return
	
	if game_over_menu != null:
		game_over_menu.hide_menu_instant()
	
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
	
	session.prepare_next_round(starting_player_id)
	session.start_game_timer()
	
	if replay_recorder != null:
		if replay_recorder.is_recording():
			var gravity:String = ReplayFormat.GRAVITY_DOWN
			
			if board != null:
				var board_gravity:String = board.get_replay_gravity_id(board.settings.gravity_direction)
				
				if board_gravity != "":
					gravity = board_gravity
			
			if replay_recorder.record_round_start(session.current_round_number, session.current_turn_number, starting_player_id, gravity) == false:
				DebugOverlay.log_error("ReplayRecorder", "Could not record the start of round %d." % session.current_round_number)
	start_turn(starting_player_id)


func start_turn_timer() -> void:
	if turn_timer == null:
		return
	
	turn_timer.start_turn_timer()


func stop_turn_timer() -> void:
	if turn_timer == null:
		return
	
	turn_timer.stop_turn_timer()
	
func send_local_drag_preview_started(drag_id:int, token_type:int, board_local_position:Vector2, is_flipped:bool) -> void:
	if is_network_match_active() == false:
		return
	
	if network_match_controller == null:
		return
	
	network_match_controller.send_local_drag_preview_started(drag_id, token_type, board_local_position, is_flipped)


func send_local_drag_preview_position(drag_id:int, board_local_position:Vector2) -> void:
	if is_network_match_active() == false:
		return
	
	if network_match_controller == null:
		return
	
	network_match_controller.send_local_drag_preview_position(drag_id, board_local_position)


func send_local_drag_preview_flipped(drag_id:int, is_flipped:bool) -> void:
	if is_network_match_active() == false:
		return
	
	if network_match_controller == null:
		return
	
	network_match_controller.send_local_drag_preview_flipped(drag_id, is_flipped)


func send_local_drag_preview_ended(drag_id:int) -> void:
	if is_network_match_active() == false:
		return
	
	if network_match_controller == null:
		return
	
	network_match_controller.send_local_drag_preview_ended(drag_id)


func show_remote_drag_preview(drag_id:int, player_id:int, token_type:int, board_local_position:Vector2, is_flipped:bool) -> void:
	if token_drag_controller == null:
		return
	
	token_drag_controller.show_remote_drag_preview(drag_id, player_id, token_type, board_local_position, is_flipped)


func update_remote_drag_preview(drag_id:int, board_local_position:Vector2) -> void:
	if token_drag_controller == null:
		return
	
	token_drag_controller.update_remote_drag_preview(drag_id, board_local_position)


func flip_remote_drag_preview(drag_id:int, is_flipped:bool) -> void:
	if token_drag_controller == null:
		return
	
	token_drag_controller.flip_remote_drag_preview(drag_id, is_flipped)


func clear_remote_drag_preview(drag_id:int = -1) -> void:
	if token_drag_controller == null:
		return
	
	token_drag_controller.clear_remote_drag_preview(drag_id)


func setup_replay_recorder() -> void:
	replay_recorder = null
	
	if board != null:
		board.set_replay_recorder(null)
	
	if should_record_replay() == false:
		DebugOverlay.log_message("ReplayRecorder", "Replay recording disabled on this match client.")
		return
	
	var new_recorder:ReplayRecorder = ReplayRecorder.new()
	var match_id:String = ReplayRecorder.generate_match_id()
	
	if new_recorder.start_recording(match_id) == false:
		DebugOverlay.log_error("ReplayRecorder", "Could not start the replay recorder.")
		return
	
	var initial_gravity:String = ReplayFormat.GRAVITY_DOWN
	
	if board != null:
		var board_gravity:String = board.get_replay_gravity_id(board.settings.gravity_direction)
		
		if board_gravity != "":
			initial_gravity = board_gravity
	
	if new_recorder.configure_match(session, initial_gravity) == false:
		DebugOverlay.log_error("ReplayRecorder", "Could not configure the replay header.")
		new_recorder.stop_recording()
		return
	
	replay_recorder = new_recorder
	
	if board != null:
		board.set_replay_recorder(replay_recorder)
	
	DebugOverlay.log_message("ReplayRecorder", "Started replay %s." % replay_recorder.get_match_id())

func should_record_replay() -> bool:
	if is_network_match_active() == false:
		return true
	
	return is_network_match_host()


func get_replay_recorder() -> ReplayRecorder:
	return replay_recorder


func create_replay_score_snapshot() -> Array:
	var scores:Array = []
	
	if session == null:
		return scores
	
	for player_id in range(session.get_player_count()):
		scores.append({
			"player_id": player_id,
			"wins": session.get_player_wins(player_id),
			"losses": session.get_player_losses(player_id)
		})
	
	return scores
