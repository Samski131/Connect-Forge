class_name PlacementLogic
extends Node

var game_manager:GameManager = null
var board:BoardManager = null


func setup(new_game_manager:GameManager, new_board:BoardManager) -> void:
	game_manager = new_game_manager
	board = new_board


func exit_state() -> void:
	if game_manager == null:
		return
	
	game_manager.enter_action_phase()


func try_place_dragged_token(token_type:int, slot_pos:Vector2i, start_flipped:bool, placement_data:Dictionary = {}) -> bool:
	if game_manager == null:
		return false
	
	if board == null:
		return false
	
	if game_manager.get_current_turn_phase() != Global.TURN_PHASE.PLACEMENT:
		return false
	
	if is_valid_starting_slot(slot_pos) == false:
		return false
	
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return false
	
	var current_player_id:int = game_manager.get_current_player_id()
	
	if game_manager.is_valid_player_id(current_player_id) == false:
		return false
	
	var new_token:Token = board.create_new_token(token_scene, slot_pos, current_player_id, start_flipped)
	
	if new_token == null:
		return false
	
	new_token.apply_network_placement_data(placement_data)
	
	record_replay_token_spawn(new_token)
	
	exit_state()
	return true


func record_replay_token_spawn(token:Token) -> void:
	if token == null:
		return
	
	if board == null:
		return
	
	var recorder:ReplayRecorder = board.get_replay_recorder()
	
	if recorder == null:
		return
	
	if recorder.is_recording() == false:
		return
	
	var round_number:int = game_manager.get_current_round_number()
	var turn_number:int = game_manager.get_current_turn_number()
	
	if recorder.record_token_spawn(token, round_number, turn_number) == false:
		DebugOverlay.log_error("ReplayRecorder", "Failed to record the spawn of replay token %d." % token.get_replay_token_id())


func is_valid_starting_slot(slot_pos:Vector2i) -> bool:
	if board == null:
		return false
	
	if board.state == null:
		return false
	
	return PlacementRules.is_valid_starting_slot(board.state, board.settings, slot_pos)
