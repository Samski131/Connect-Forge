class_name MatchSession
extends RefCounted

signal players_changed
signal current_player_changed(player_id:int)
signal turn_phase_changed(turn_phase:Global.TURN_PHASE)
signal turn_number_changed(turn_number:int)
signal round_number_changed(round_number:int)
signal game_time_changed(total_seconds:int)
signal winner_changed(winner_id:int)
signal result_recorded(winner_id:int)
signal score_changed
signal token_type_added(player_id:int, token_type:int)
signal token_count_changed(player_id:int, token_type:int, new_count:int)
signal player_tokens_reset(player_id:int)
signal all_tokens_reset

const BASIC_TOKEN_COUNT:int = 99

var players:Array[MatchSessionPlayerData] = []

var starting_token_points:int = 10
var board_columns:int = 7
var board_rows:int = 6
var tokens_to_win:int = 4
var turn_timer_seconds:int = 0
var starting_player_id:int = 0

var current_turn_phase:Global.TURN_PHASE = Global.TURN_PHASE.NONE
var current_player_id:int = -1
var current_turn_number:int = 1
var current_round_number:int = 1

var elapsed_game_time:float = 0.0
var elapsed_game_seconds:int = 0
var game_timer_running:bool = false

var winner_id:int = -1
var match_result_recorded:bool = false

var is_batching_score_changes:bool = false


func setup(config:MatchConfig) -> bool:
	clear()
	
	if config == null:
		return false
	
	snapshot_rules_from_config(config)
	create_players_from_config(config)
	reset_match_state()
	return players.is_empty() == false


func clear() -> void:
	players.clear()
	
	starting_token_points = 10
	board_columns = 7
	board_rows = 6
	tokens_to_win = 4
	turn_timer_seconds = 0
	starting_player_id = 0
	
	current_turn_phase = Global.TURN_PHASE.NONE
	current_player_id = -1
	current_turn_number = 1
	current_round_number = 1
	
	elapsed_game_time = 0.0
	elapsed_game_seconds = 0
	game_timer_running = false
	
	winner_id = -1
	match_result_recorded = false
	is_batching_score_changes = false


func snapshot_rules_from_config(config:MatchConfig) -> void:
	if config == null:
		return
	
	starting_token_points = clamp(config.starting_token_points, MatchConfig.MINIMUM_STARTING_TOKEN_POINTS, MatchConfig.MAXIMUM_STARTING_TOKEN_POINTS)
	board_columns = clamp(config.board_columns, MatchConfig.MINIMUM_BOARD_COLUMNS, MatchConfig.MAXIMUM_BOARD_COLUMNS)
	board_rows = clamp(config.board_rows, MatchConfig.MINIMUM_BOARD_ROWS, MatchConfig.MAXIMUM_BOARD_ROWS)
	
	var maximum_line_length:int = max(board_columns, board_rows)
	tokens_to_win = clamp(config.tokens_to_win, MatchConfig.MINIMUM_TOKENS_TO_WIN, maximum_line_length)
	
	turn_timer_seconds = max(config.turn_timer_seconds, 0)
	
	if config.starting_player_id == MatchConfig.RANDOM_STARTING_PLAYER_ID:
		starting_player_id = MatchConfig.RANDOM_STARTING_PLAYER_ID
	elif config.starting_player_id >= 0 and config.starting_player_id < config.get_player_count():
		starting_player_id = config.starting_player_id
	elif config.get_player_count() > 0:
		starting_player_id = 0
	else:
		starting_player_id = MatchConfig.RANDOM_STARTING_PLAYER_ID


func create_players_from_config(config:MatchConfig) -> void:
	players.clear()
	
	if config == null:
		players_changed.emit()
		return
	
	for player_id in range(config.get_player_count()):
		var source_player:MatchPlayerData = config.get_player(player_id)
		var session_player:MatchSessionPlayerData = MatchSessionPlayerData.new()
		
		session_player.setup(player_id, source_player)
		session_player.set_starting_token_count(TokenLibrary.TokenType.BASIC, BASIC_TOKEN_COUNT)
		
		connect_player_signals(session_player)
		session_player.reset_tokens_for_round()
		
		players.append(session_player)
	
	players_changed.emit()


func connect_player_signals(player:MatchSessionPlayerData) -> void:
	if player == null:
		return
	
	if player.score_changed.is_connected(_on_player_score_changed) == false:
		player.score_changed.connect(_on_player_score_changed)
	
	if player.token_type_added.is_connected(_on_player_token_type_added) == false:
		player.token_type_added.connect(_on_player_token_type_added)
	
	if player.token_count_changed.is_connected(_on_player_token_count_changed) == false:
		player.token_count_changed.connect(_on_player_token_count_changed)
	
	if player.tokens_reset.is_connected(_on_player_tokens_reset) == false:
		player.tokens_reset.connect(_on_player_tokens_reset)


func reset_match_state() -> void:
	current_turn_phase = Global.TURN_PHASE.NONE
	
	if players.is_empty():
		current_player_id = -1
	else:
		current_player_id = 0
	
	current_turn_number = 1
	current_round_number = 1
	
	elapsed_game_time = 0.0
	elapsed_game_seconds = 0
	game_timer_running = false
	
	winner_id = -1
	match_result_recorded = false
	
	reset_scores()
	reset_tokens_for_round()


func prepare_first_round(new_starting_player_id:int) -> void:
	current_round_number = 1
	round_number_changed.emit(current_round_number)
	
	reset_round_state(new_starting_player_id)


func prepare_next_round(new_starting_player_id:int) -> void:
	current_round_number += 1
	round_number_changed.emit(current_round_number)
	
	reset_round_state(new_starting_player_id)


func reset_round_state(new_starting_player_id:int) -> void:
	set_turn_phase(Global.TURN_PHASE.NONE)
	set_turn_number(1)
	set_winner_id(-1)
	
	match_result_recorded = false
	
	reset_game_timer()
	reset_tokens_for_round()
	
	if is_valid_player_id(new_starting_player_id):
		set_current_player(new_starting_player_id)
	elif players.is_empty():
		set_current_player(-1)
	else:
		set_current_player(0)


func get_starting_token_points() -> int:
	return starting_token_points


func get_board_columns() -> int:
	return board_columns


func get_board_rows() -> int:
	return board_rows


func get_tokens_to_win() -> int:
	return tokens_to_win


func get_turn_timer_seconds() -> int:
	return turn_timer_seconds


func get_configured_starting_player_id() -> int:
	return starting_player_id


func get_resolved_starting_player_id() -> int:
	if players.is_empty():
		return -1
	
	if is_valid_player_id(starting_player_id):
		return starting_player_id
	
	return randi_range(0, players.size() - 1)


func get_player_count() -> int:
	return players.size()


func get_player(player_id:int) -> MatchSessionPlayerData:
	if is_valid_player_id(player_id) == false:
		return null
	
	return players[player_id]


func is_valid_player_id(player_id:int) -> bool:
	if player_id < 0:
		return false
	
	if player_id >= players.size():
		return false
	
	return true


func get_player_name(player_id:int) -> String:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return "Player " + str(player_id + 1)
	
	var used_name:String = player.player_name.strip_edges()
	
	if used_name == "":
		return "Player " + str(player_id + 1)
	
	return used_name


func get_player_palette(player_id:int) -> ColorPalette:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return null
	
	return player.colour_palette


func set_current_player(player_id:int) -> bool:
	if player_id == -1 and players.is_empty():
		if current_player_id == -1:
			return true
		
		current_player_id = -1
		current_player_changed.emit(current_player_id)
		return true
	
	if is_valid_player_id(player_id) == false:
		return false
	
	if current_player_id == player_id:
		return true
	
	current_player_id = player_id
	current_player_changed.emit(current_player_id)
	return true


func get_next_player_id() -> int:
	if players.is_empty():
		return -1
	
	if is_valid_player_id(current_player_id) == false:
		return 0
	
	return (current_player_id + 1) % players.size()


func set_turn_phase(new_phase:Global.TURN_PHASE) -> void:
	if current_turn_phase == new_phase:
		return
	
	current_turn_phase = new_phase
	turn_phase_changed.emit(current_turn_phase)


func set_turn_number(new_turn_number:int) -> void:
	var used_turn_number:int = max(new_turn_number, 1)
	
	if current_turn_number == used_turn_number:
		return
	
	current_turn_number = used_turn_number
	turn_number_changed.emit(current_turn_number)


func increment_turn_number() -> void:
	set_turn_number(current_turn_number + 1)


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
	
	elapsed_game_time += max(delta, 0.0)
	
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


func set_winner_id(new_winner_id:int) -> bool:
	if new_winner_id != -1 and is_valid_player_id(new_winner_id) == false:
		return false
	
	if winner_id == new_winner_id:
		return true
	
	winner_id = new_winner_id
	winner_changed.emit(winner_id)
	return true


func record_match_result(new_winner_id:int) -> bool:
	if match_result_recorded:
		return false
	
	if is_valid_player_id(new_winner_id) == false:
		return false
	
	match_result_recorded = true
	set_winner_id(new_winner_id)
	
	is_batching_score_changes = true
	
	for player_id in range(players.size()):
		var player:MatchSessionPlayerData = players[player_id]
		
		if player == null:
			continue
		
		if player_id == new_winner_id:
			player.record_win()
		else:
			player.record_loss()
	
	is_batching_score_changes = false
	
	score_changed.emit()
	result_recorded.emit(new_winner_id)
	return true


func reset_scores() -> void:
	is_batching_score_changes = true
	
	for player in players:
		if player == null:
			continue
		
		player.reset_score()
	
	is_batching_score_changes = false
	score_changed.emit()


func get_player_wins(player_id:int) -> int:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return 0
	
	return player.wins


func get_player_losses(player_id:int) -> int:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return 0
	
	return player.losses


func reset_tokens_for_round() -> void:
	for player in players:
		if player == null:
			continue
		
		player.reset_tokens_for_round()
	
	all_tokens_reset.emit()


func get_token_count(player_id:int, token_type:int) -> int:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return 0
	
	return player.get_token_count(token_type)


func get_token_types_for_player(player_id:int) -> Array[int]:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		var empty_types:Array[int] = []
		return empty_types
	
	return player.get_token_types_in_tray_order()


func player_has_token(player_id:int, token_type:int) -> bool:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	return player.has_token(token_type)


func spend_token(player_id:int, token_type:int, amount:int = 1) -> bool:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	return player.spend_token(token_type, amount)


func refund_token(player_id:int, token_type:int, amount:int = 1) -> bool:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	return player.refund_token(token_type, amount)


func add_tokens(player_id:int, token_type:int, amount:int = 1) -> bool:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	return player.add_tokens(token_type, amount)


func set_token_count(player_id:int, token_type:int, amount:int) -> bool:
	var player:MatchSessionPlayerData = get_player(player_id)
	
	if player == null:
		return false
	
	player.set_token_count(token_type, amount)
	return true


func _on_player_score_changed(_player_id:int, _wins:int, _losses:int) -> void:
	if is_batching_score_changes:
		return
	
	score_changed.emit()


func _on_player_token_type_added(player_id:int, token_type:int) -> void:
	token_type_added.emit(player_id, token_type)


func _on_player_token_count_changed(player_id:int, token_type:int, new_count:int) -> void:
	token_count_changed.emit(player_id, token_type, new_count)


func _on_player_tokens_reset(player_id:int) -> void:
	player_tokens_reset.emit(player_id)
