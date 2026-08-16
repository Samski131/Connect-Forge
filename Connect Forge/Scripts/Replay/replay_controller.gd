class_name ReplayController
extends RefCounted

signal replay_loaded
signal step_changed(step_id:int, step:ReplayStep, state:ReplayState)
signal navigation_changed(can_go_previous:bool, can_go_next:bool)
signal replay_error(message:String)

signal playback_changed(is_playing:bool)
signal playback_speed_changed(speed:float)
signal replay_finished

signal animated_step_started(step_id:int)
signal animated_step_finished(step_id:int)

const MINIMUM_PLAYBACK_SPEED:float = 0.1
const MAXIMUM_PLAYBACK_SPEED:float = 8.0

const DEFAULT_INTER_STEP_DELAY_SECONDS:float = 0.20
const MAXIMUM_INTER_STEP_DELAY_SECONDS:float = 2.0

var replay:ReplayData = null
var current_state:ReplayState = null
var current_step_id:int = -1

var board_view:ReplayBoardView = null
var presentation_player:ReplayPresentationPlayer = null
var loaded_file_path:String = ""

var playback_in_progress:bool = false
var continuous_playback_enabled:bool = false
var playback_speed:float = 1.0
var inter_step_delay_seconds:float = DEFAULT_INTER_STEP_DELAY_SECONDS

var pending_step_id:int = -1
var pending_step:ReplayStep = null
var pending_state:ReplayState = null

var playback_generation:int = 0


func setup(new_board_view:ReplayBoardView, new_presentation_player:ReplayPresentationPlayer = null) -> bool:
	if new_board_view == null:
		return false
	
	board_view = new_board_view
	presentation_player = new_presentation_player
	
	if presentation_player != null:
		if presentation_player.setup(board_view) == false:
			presentation_player = null
			return false
	
	return true


func load_replay(file_path:String) -> bool:
	if playback_in_progress:
		return false
	
	if continuous_playback_enabled:
		pause()
	
	invalidate_pending_playback()
	
	if board_view == null:
		return report_error("ReplayController has no ReplayBoardView.")
	
	var used_file_path:String = file_path.strip_edges()
	
	if used_file_path == "":
		return report_error("Replay file path is empty.")
	
	if FileAccess.file_exists(used_file_path) == false:
		return report_error("Replay file does not exist: %s" % used_file_path)
	
	var loaded_replay:ReplayData = ReplayStorage.load_replay(used_file_path)
	
	if loaded_replay == null:
		return report_error("ReplayStorage could not load: %s" % used_file_path)
	
	if board_view.setup_from_replay(loaded_replay) == false:
		return report_error("ReplayBoardView could not set up the replay board.")
	
	replay = loaded_replay
	loaded_file_path = used_file_path
	current_step_id = -1
	
	clear_pending_animated_step()
	
	current_state = ReplayStateReconstructor.reconstruct_to_step(replay, -1)
	
	if current_state == null:
		clear_loaded_replay()
		return report_error("Could not reconstruct the initial replay state.")
	
	if board_view.display_state(current_state) == false:
		clear_loaded_replay()
		return report_error("Could not display the initial replay state.")
	
	replay_loaded.emit()
	
	if replay.get_step_count() > 0:
		return go_to_step(0)
	
	emit_navigation_changed()
	return true


func go_to_step(step_id:int) -> bool:
	if playback_in_progress:
		return false
	
	if continuous_playback_enabled:
		pause()
	
	invalidate_pending_playback()
	
	if replay == null:
		return report_error("No replay is loaded.")
	
	if step_id < 0:
		return false
	
	if step_id >= replay.get_step_count():
		return false
	
	var reconstructed_state:ReplayState = ReplayStateReconstructor.reconstruct_to_step(replay, step_id)
	
	if reconstructed_state == null:
		return report_error("Could not reconstruct replay step %d." % step_id)
	
	if board_view == null:
		return report_error("ReplayController has no ReplayBoardView.")
	
	if board_view.display_state(reconstructed_state) == false:
		return report_error("Could not display replay step %d." % step_id)
	
	current_step_id = step_id
	current_state = reconstructed_state
	
	var step:ReplayStep = replay.get_step(current_step_id)
	
	step_changed.emit(current_step_id, step, current_state)
	emit_navigation_changed()
	return true


func play() -> bool:
	if replay == null:
		return report_error("No replay is loaded.")
	
	if presentation_player == null:
		return report_error("ReplayController has no ReplayPresentationPlayer.")
	
	if playback_in_progress:
		return false
	
	if replay.get_step_count() <= 0:
		return false
	
	if continuous_playback_enabled:
		return true
	
	if has_next_step() == false:
		if go_to_first_step() == false:
			return false
	
	invalidate_pending_playback()
	continuous_playback_enabled = true
	
	playback_changed.emit(true)
	emit_navigation_changed()
	
	var generation:int = playback_generation
	call_deferred("_continue_continuous_playback", generation)
	return true


func pause() -> bool:
	if continuous_playback_enabled == false:
		return false
	
	continuous_playback_enabled = false
	invalidate_pending_playback()
	
	playback_changed.emit(false)
	emit_navigation_changed()
	return true


func toggle_playback() -> bool:
	if continuous_playback_enabled:
		return pause()
	
	return play()


func play_next_step() -> bool:
	if playback_in_progress:
		return false
	
	if replay == null:
		return report_error("No replay is loaded.")
	
	if presentation_player == null:
		return report_error("ReplayController has no ReplayPresentationPlayer.")
	
	if has_next_step() == false:
		return false
	
	var target_step_id:int = current_step_id + 1
	var target_step:ReplayStep = replay.get_step(target_step_id)
	
	if target_step == null:
		return report_error("Replay step %d does not exist." % target_step_id)
	
	var target_state:ReplayState = ReplayStateReconstructor.reconstruct_to_step(replay, target_step_id)
	
	if target_state == null:
		return report_error("Could not reconstruct replay step %d before animation." % target_step_id)
	
	pending_step_id = target_step_id
	pending_step = target_step
	pending_state = target_state
	playback_in_progress = true
	
	animated_step_started.emit(pending_step_id)
	emit_navigation_changed()
	
	if target_step.presentation == null:
		return commit_pending_animated_step()
	
	if presentation_player.play_action(target_step.presentation, playback_speed, _on_presentation_finished) == false:
		var failed_step_id:int = pending_step_id
		
		playback_in_progress = false
		clear_pending_animated_step()
		
		if continuous_playback_enabled:
			continuous_playback_enabled = false
			invalidate_pending_playback()
			playback_changed.emit(false)
		
		emit_navigation_changed()
		return report_error("Could not play presentation for replay step %d." % failed_step_id)
	
	return true


func go_to_first_step() -> bool:
	if playback_in_progress:
		return false
	
	if continuous_playback_enabled:
		pause()
	
	if replay == null:
		return false
	
	if replay.get_step_count() <= 0:
		return false
	
	return go_to_step(0)


func go_to_previous_step() -> bool:
	if can_go_to_previous_step() == false:
		return false
	
	return go_to_step(current_step_id - 1)


func go_to_next_step() -> bool:
	if can_go_to_next_step() == false:
		return false
	
	return go_to_step(current_step_id + 1)


func go_to_last_step() -> bool:
	if playback_in_progress:
		return false
	
	if continuous_playback_enabled:
		pause()
	
	if replay == null:
		return false
	
	if replay.get_step_count() <= 0:
		return false
	
	return go_to_step(replay.get_step_count() - 1)


func has_previous_step() -> bool:
	if replay == null:
		return false
	
	return current_step_id > 0


func has_next_step() -> bool:
	if replay == null:
		return false
	
	return current_step_id >= 0 and current_step_id < replay.get_step_count() - 1


func can_go_to_previous_step() -> bool:
	if playback_in_progress:
		return false
	
	if continuous_playback_enabled:
		return false
	
	return has_previous_step()


func can_go_to_next_step() -> bool:
	if playback_in_progress:
		return false
	
	if continuous_playback_enabled:
		return false
	
	return has_next_step()


func is_playing() -> bool:
	return continuous_playback_enabled


func is_step_playing() -> bool:
	return playback_in_progress


func is_busy() -> bool:
	if continuous_playback_enabled:
		return true
	
	if playback_in_progress:
		return true
	
	return false


func set_playback_speed(new_speed:float) -> void:
	var used_speed:float = clamp(new_speed, MINIMUM_PLAYBACK_SPEED, MAXIMUM_PLAYBACK_SPEED)
	
	if is_equal_approx(playback_speed, used_speed):
		return
	
	playback_speed = used_speed
	playback_speed_changed.emit(playback_speed)


func get_playback_speed() -> float:
	return playback_speed


func set_inter_step_delay(new_delay_seconds:float) -> void:
	inter_step_delay_seconds = clamp(new_delay_seconds, 0.0, MAXIMUM_INTER_STEP_DELAY_SECONDS)


func get_inter_step_delay() -> float:
	return inter_step_delay_seconds


func get_scaled_inter_step_delay() -> float:
	if inter_step_delay_seconds <= 0.0:
		return 0.0
	
	return inter_step_delay_seconds / max(playback_speed, MINIMUM_PLAYBACK_SPEED)


func get_replay() -> ReplayData:
	return replay


func get_current_state() -> ReplayState:
	return current_state


func get_current_step() -> ReplayStep:
	if replay == null:
		return null
	
	return replay.get_step(current_step_id)


func get_current_step_id() -> int:
	return current_step_id


func get_step_count() -> int:
	if replay == null:
		return 0
	
	return replay.get_step_count()


func get_last_step_id() -> int:
	var step_count:int = get_step_count()
	
	if step_count <= 0:
		return -1
	
	return step_count - 1


func get_loaded_file_path() -> String:
	return loaded_file_path


func has_loaded_replay() -> bool:
	return replay != null


func clear_loaded_replay() -> void:
	if playback_in_progress:
		return
	
	if continuous_playback_enabled:
		pause()
	
	invalidate_pending_playback()
	
	replay = null
	current_state = null
	current_step_id = -1
	loaded_file_path = ""
	
	clear_pending_animated_step()
	emit_navigation_changed()


func emit_navigation_changed() -> void:
	navigation_changed.emit(can_go_to_previous_step(), can_go_to_next_step())


func report_error(message:String) -> bool:
	push_error("ReplayController: " + message)
	replay_error.emit(message)
	return false


func _continue_continuous_playback(expected_generation:int) -> void:
	if expected_generation != playback_generation:
		return
	
	if continuous_playback_enabled == false:
		return
	
	if playback_in_progress:
		return
	
	if replay == null:
		_stop_continuous_playback(false)
		return
	
	if has_next_step() == false:
		_stop_continuous_playback(true)
		return
	
	if play_next_step() == false:
		_stop_continuous_playback(false)


func _schedule_next_continuous_step() -> void:
	if continuous_playback_enabled == false:
		return
	
	if board_view == null:
		_stop_continuous_playback(false)
		return
	
	var generation:int = playback_generation
	var delay_seconds:float = get_scaled_inter_step_delay()
	
	if delay_seconds <= 0.0:
		call_deferred("_continue_continuous_playback", generation)
		return
	
	var scene_tree:SceneTree = board_view.get_tree()
	
	if scene_tree == null:
		_stop_continuous_playback(false)
		return
	
	var timer:SceneTreeTimer = scene_tree.create_timer(delay_seconds)
	timer.timeout.connect(_on_inter_step_delay_finished.bind(generation), CONNECT_ONE_SHOT)


func _on_inter_step_delay_finished(expected_generation:int) -> void:
	_continue_continuous_playback(expected_generation)


func _on_presentation_finished() -> void:
	commit_pending_animated_step()


func commit_pending_animated_step() -> bool:
	if playback_in_progress == false:
		return false
	
	if pending_step_id < 0:
		return finish_failed_animated_step("Animated replay step has no pending step ID.")
	
	if pending_step == null:
		return finish_failed_animated_step("Animated replay step has no pending ReplayStep.")
	
	if pending_state == null:
		return finish_failed_animated_step("Animated replay step has no pending ReplayState.")
	
	if board_view == null:
		return finish_failed_animated_step("ReplayController has no ReplayBoardView.")
	
	var completed_step_id:int = pending_step_id
	var completed_step:ReplayStep = pending_step
	var completed_state:ReplayState = pending_state
	
	if board_view.display_state(completed_state) == false:
		return finish_failed_animated_step("Could not display replay step %d after its presentation." % completed_step_id)
	
	current_step_id = completed_step_id
	current_state = completed_state
	playback_in_progress = false
	
	clear_pending_animated_step()
	
	step_changed.emit(current_step_id, completed_step, current_state)
	animated_step_finished.emit(current_step_id)
	emit_navigation_changed()
	
	if continuous_playback_enabled:
		if has_next_step():
			_schedule_next_continuous_step()
		else:
			_stop_continuous_playback(true)
	
	return true


func finish_failed_animated_step(message:String) -> bool:
	playback_in_progress = false
	clear_pending_animated_step()
	
	if continuous_playback_enabled:
		continuous_playback_enabled = false
		invalidate_pending_playback()
		playback_changed.emit(false)
	
	emit_navigation_changed()
	return report_error(message)


func clear_pending_animated_step() -> void:
	pending_step_id = -1
	pending_step = null
	pending_state = null


func invalidate_pending_playback() -> void:
	playback_generation += 1


func _stop_continuous_playback(reached_end:bool) -> void:
	if continuous_playback_enabled == false:
		return
	
	continuous_playback_enabled = false
	invalidate_pending_playback()
	
	playback_changed.emit(false)
	emit_navigation_changed()
	
	if reached_end:
		replay_finished.emit()
