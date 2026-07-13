class_name MatchTurnTimer
extends Node

signal timer_enabled_changed(enabled:bool)
signal time_changed(seconds_remaining:int, total_seconds:int)
signal turn_timed_out(player_id:int)

var game_manager:Node = null

var turn_limit_seconds:int = 0
var time_remaining:float = 0.0
var displayed_seconds_remaining:int = 0

var is_running:bool = false
var timeout_is_being_handled:bool = false


func _ready() -> void:
	add_to_group("turn timer")
	process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(new_game_manager:Node) -> void:
	game_manager = new_game_manager
	refresh_limit_from_match_data()
	emit_current_state()


func _process(delta:float) -> void:
	update_turn_timer(delta)


func refresh_limit_from_match_data() -> void:
	turn_limit_seconds = 0
	
	if MatchData.config == null:
		return
	
	turn_limit_seconds = max(MatchData.config.turn_timer_seconds, 0)


func start_turn_timer() -> void:
	refresh_limit_from_match_data()
	timeout_is_being_handled = false
	
	if turn_limit_seconds <= 0:
		is_running = false
		time_remaining = 0.0
		displayed_seconds_remaining = 0
		timer_enabled_changed.emit(false)
		time_changed.emit(0, 0)
		return
	
	time_remaining = float(turn_limit_seconds)
	displayed_seconds_remaining = turn_limit_seconds
	is_running = true
	
	timer_enabled_changed.emit(true)
	time_changed.emit(displayed_seconds_remaining, turn_limit_seconds)


func stop_turn_timer() -> void:
	is_running = false


func reset_turn_timer() -> void:
	is_running = false
	timeout_is_being_handled = false
	time_remaining = 0.0
	displayed_seconds_remaining = 0
	
	refresh_limit_from_match_data()
	emit_current_state()


func update_turn_timer(delta:float) -> void:
	if is_running == false:
		return
	
	if game_manager == null:
		stop_turn_timer()
		return
	
	if game_manager.current_turn_phase != Global.TURN_PHASE.PLACEMENT:
		return
	
	time_remaining = max(time_remaining - delta, 0.0)
	
	var new_displayed_seconds:int = int(ceil(time_remaining))
	
	if new_displayed_seconds != displayed_seconds_remaining:
		displayed_seconds_remaining = new_displayed_seconds
		time_changed.emit(displayed_seconds_remaining, turn_limit_seconds)
	
	if time_remaining > 0.0:
		return
	
	handle_turn_timeout()


func handle_turn_timeout() -> void:
	if timeout_is_being_handled:
		return
	
	if game_manager == null:
		return
	
	timeout_is_being_handled = true
	is_running = false
	time_remaining = 0.0
	displayed_seconds_remaining = 0
	
	time_changed.emit(0, turn_limit_seconds)
	
	var expired_player_id:int = game_manager.current_player_id
	
	game_manager.current_turn_phase = Global.TURN_PHASE.NONE
	cancel_current_drag()
	clear_placement_visual()
	
	turn_timed_out.emit(expired_player_id)
	game_manager.end_turn()


func cancel_current_drag() -> void:
	var drag_controller:TokenDragController = get_tree().get_first_node_in_group("token drag controller") as TokenDragController
	
	if drag_controller == null:
		return
	
	drag_controller.cancel_drag()


func clear_placement_visual() -> void:
	if game_manager == null:
		return
	
	if game_manager.placement_state == null:
		return
	
	if game_manager.placement_state.has_method("clear_placement_token"):
		game_manager.placement_state.clear_placement_token()


func is_timer_enabled() -> bool:
	return turn_limit_seconds > 0


func get_seconds_remaining() -> int:
	return max(displayed_seconds_remaining, 0)


func get_total_seconds() -> int:
	return max(turn_limit_seconds, 0)


func get_time_text() -> String:
	var used_seconds:int = get_seconds_remaining()
	var minutes:int = int(used_seconds / 60.0)
	var seconds:int = used_seconds % 60
	
	return "%02d:%02d" % [minutes, seconds]


func get_progress_ratio() -> float:
	if turn_limit_seconds <= 0:
		return 0.0
	
	return clamp(time_remaining / float(turn_limit_seconds), 0.0, 1.0)


func emit_current_state() -> void:
	timer_enabled_changed.emit(is_timer_enabled())
	time_changed.emit(displayed_seconds_remaining, turn_limit_seconds)
