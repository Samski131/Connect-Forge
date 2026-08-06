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
	
	exit_state()
	return true


func is_valid_starting_slot(slot_pos:Vector2i) -> bool:
	if board == null:
		return false
	
	if board.is_position_in_bounds(slot_pos) == false:
		return false
	
	if board.get_token(slot_pos) != null:
		return false
	
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	
	match board.settings.gravity_direction:
		GRID_DIRECTION.DOWN:
			if slot_pos.y == 0:
				return true
		
		GRID_DIRECTION.UP:
			if slot_pos.y == board.settings.rows - 1:
				return true
		
		GRID_DIRECTION.RIGHT:
			if slot_pos.x == 0:
				return true
		
		GRID_DIRECTION.LEFT:
			if slot_pos.x == board.settings.columns - 1:
				return true
	
	return false
