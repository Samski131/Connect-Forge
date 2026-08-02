class_name ResolutionLogic
extends Node

const WIN_DIRECTIONS:Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(1, -1)
]

@export_group("Winning Line")
@export var winning_line_colour_index:int = 0

var game_manager:GameManager = null
var board:BoardManager = null

var win_sequence_started:bool = false
var stored_winner_id:int = -1
var stored_winning_slots:Array[Vector2i] = []


func setup(new_game_manager:GameManager, new_board:BoardManager) -> void:
	game_manager = new_game_manager
	board = new_board


func enter_state() -> void:
	clear_stored_win()


func exit_state() -> void:
	if game_manager == null:
		return
	
	clear_stored_win()
	game_manager.end_turn()


func process_state() -> void:
	if game_manager == null:
		return
	
	if board == null:
		return
	
	if board.visuals != null and board.visuals.is_busy():
		return
	
	if win_sequence_started:
		finish_game_with_winner(stored_winner_id)
		return
	
	var winning_result:Dictionary = find_winning_result()
	
	if winning_result.is_empty():
		exit_state()
		return
	
	stored_winner_id = int(winning_result["player_id"])
	stored_winning_slots.clear()
	
	var found_slots:Array = winning_result["slots"]
	
	for slot_value in found_slots:
		var slot_position:Vector2i = slot_value
		stored_winning_slots.append(slot_position)
	
	win_sequence_started = true
	
	reveal_chameleon_tokens_after_win()
	queue_winning_line(stored_winner_id, stored_winning_slots)
	
	if board.visuals != null and board.visuals.is_busy():
		return
	
	finish_game_with_winner(stored_winner_id)


func find_winning_result() -> Dictionary:
	if board == null:
		return {}
	
	if board.settings == null:
		return {}
	
	var rows:int = board.settings.rows
	var columns:int = board.settings.columns
	var tokens_to_win:int = board.settings.tokens_to_win
	
	if rows <= 0:
		return {}
	
	if columns <= 0:
		return {}
	
	if tokens_to_win <= 0:
		return {}
	
	for row in range(rows):
		for column in range(columns):
			var start_position:Vector2i = Vector2i(column, row)
			var starting_token:Token = board.get_token(start_position)
			
			if starting_token == null:
				continue
			
			if is_instance_valid(starting_token) == false:
				continue
			
			if starting_token.being_destroyed:
				continue
			
			var player_id:int = starting_token.player_id
			
			if is_valid_winning_player(player_id) == false:
				continue
			
			for direction in WIN_DIRECTIONS:
				var winning_slots:Array[Vector2i] = get_winning_slots(start_position, direction, player_id, tokens_to_win)
				
				if winning_slots.is_empty() == false:
					return {
						"player_id": player_id,
						"slots": winning_slots
					}
	
	return {}


func get_winning_slots(start_position:Vector2i, direction:Vector2i, player_id:int, tokens_to_win:int) -> Array[Vector2i]:
	var winning_slots:Array[Vector2i] = []
	var final_position:Vector2i = start_position + direction * (tokens_to_win - 1)
	
	if board.is_position_in_bounds(final_position) == false:
		return winning_slots
	
	for step in range(tokens_to_win):
		var checked_position:Vector2i = start_position + direction * step
		var checked_token:Token = board.get_token(checked_position)
		
		if checked_token == null:
			winning_slots.clear()
			return winning_slots
		
		if is_instance_valid(checked_token) == false:
			winning_slots.clear()
			return winning_slots
		
		if checked_token.being_destroyed:
			winning_slots.clear()
			return winning_slots
		
		if checked_token.player_id != player_id:
			winning_slots.clear()
			return winning_slots
		
		winning_slots.append(checked_position)
	
	return winning_slots


func is_valid_winning_player(player_id:int) -> bool:
	if player_id < 0:
		return false
	
	if game_manager == null:
		return false
	
	return game_manager.is_valid_player_id(player_id)


func queue_winning_line(winner_id:int, winning_slots:Array[Vector2i]) -> void:
	if board == null:
		return
	
	if board.visuals == null:
		return
	
	if winning_slots.size() < 2:
		return
	
	var line_colour:Color = get_winning_line_colour(winner_id)
	var line_effect:WinningLineVisualEffect = WinningLineVisualEffect.new(board, winning_slots, line_colour, board.visuals.winning_line_duration)
	
	line_effect.line_width = board.visuals.winning_line_width
	line_effect.line_padding = board.visuals.winning_line_padding
	line_effect.shadow_width_multiplier = board.visuals.winning_line_shadow_width_multiplier
	line_effect.shadow_color = board.visuals.winning_line_shadow_color
	line_effect.line_z_index = board.visuals.winning_line_z_index
	
	board.visuals.queue_effect(line_effect)


func get_winning_line_colour(winner_id:int) -> Color:
	if game_manager == null:
		return Color.WHITE
	
	var palette:ColorPalette = game_manager.get_player_palette(winner_id)
	
	if palette == null:
		return Color.WHITE
	
	if palette.colors.is_empty():
		return Color.WHITE
	
	var used_colour_index:int = clamp(winning_line_colour_index, 0, palette.colors.size() - 1)
	return palette.colors[used_colour_index]


func reveal_chameleon_tokens_after_win() -> void:
	if board == null:
		return
	
	var reveal_effects:Array[BoardVisualEffect] = []
	
	for position in board.get_positions_in_gravity_order():
		var token:Token = board.get_token(position)
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		if token.being_destroyed:
			continue
		
		if token.has_method("can_reveal_chameleon_after_win") == false:
			continue
		
		var can_reveal:bool = bool(token.call("can_reveal_chameleon_after_win"))
		
		if can_reveal == false:
			continue
		
		var reveal_effect:BoardVisualEffect = null
		
		if board.visuals != null and token.has_method("create_chameleon_reveal_effect"):
			reveal_effect = token.call("create_chameleon_reveal_effect") as BoardVisualEffect
		
		if reveal_effect != null:
			reveal_effects.append(reveal_effect)
			continue
		
		if token.has_method("reveal_chameleon_instantly"):
			token.call("reveal_chameleon_instantly")
	
	if reveal_effects.is_empty():
		return
	
	if board.visuals == null:
		return
	
	board.visuals.queue_effect(ParallelVisualEffect.new(reveal_effects))


func finish_game_with_winner(winner_id:int) -> void:
	if game_manager == null:
		return
	
	game_manager.finish_match_with_winner(winner_id)


func clear_stored_win() -> void:
	win_sequence_started = false
	stored_winner_id = -1
	stored_winning_slots.clear()
