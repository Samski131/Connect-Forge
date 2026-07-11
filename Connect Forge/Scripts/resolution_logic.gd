extends Node
# This script handles the resolution state.
# It checks for wins, plays the winning sequence, then moves into game over.

const WIN_DIRECTIONS:Array[Vector2i] = [
	Vector2i(0, 1),   # row same, column right
	Vector2i(1, 0),   # row down, column same
	Vector2i(1, 1),   # row down, column right
	Vector2i(1, -1),  # row down, column left
]

var game_manager:Node
var board:BoardManager
var last_winning_slots:Array[Vector2i] = []


func setup(new_game_manager:Node, new_board:BoardManager):
	game_manager = new_game_manager
	board = new_board


func enter_state():
	get_parent().current_turn_phase = Global.TURN_PHASE.RESOLUTION


func exit_state():
	game_manager.end_turn()


func process_state():
	var win_result:Dictionary = check_for_win()
	var winner_id:int = int(win_result.get("winner_id", -1))
	
	if winner_id != -1:
		last_winning_slots.clear()
		
		var result_slots:Array = win_result.get("winning_slots", [])
		
		for slot in result_slots:
			last_winning_slots.append(slot)
		
		play_winning_sequence(winner_id, last_winning_slots)
		game_manager.record_match_result(winner_id)
		game_manager.game_over_state.enter_state(winner_id)
		return
	
	exit_state()


func check_for_win() -> Dictionary:
	var no_win_result:Dictionary = {
		"winner_id": -1,
		"winning_slots": []
	}
	
	if board == null:
		return no_win_result
	
	var rows:int = board.settings.rows
	var columns:int = board.settings.columns
	
	for row in range(rows):
		for column in range(columns):
			var start_pos:Vector2i = Vector2i(column, row)
			var current_token:Token = board.get_token(start_pos)
			
			if current_token == null:
				continue
			
			if is_instance_valid(current_token) == false:
				continue
			
			if current_token.being_destroyed:
				continue
			
			var current_player_id:int = current_token.player_id
			
			for direction in WIN_DIRECTIONS:
				var winning_slots:Array[Vector2i] = get_winning_slots_from(start_pos, direction, current_player_id)
				
				if winning_slots.is_empty() == false:
					return {
						"winner_id": current_player_id,
						"winning_slots": winning_slots
					}
	
	return no_win_result


func get_winning_slots_from(start_pos:Vector2i, row_column_direction:Vector2i, player_id:int) -> Array[Vector2i]:
	var slots:Array[Vector2i] = []
	var tokens_to_win:int = board.settings.tokens_to_win
	var rows:int = board.settings.rows
	var columns:int = board.settings.columns
	
	var row_step:int = row_column_direction.x
	var column_step:int = row_column_direction.y
	
	var start_row:int = start_pos.y
	var start_column:int = start_pos.x
	
	var farthest_row:int = start_row + row_step * (tokens_to_win - 1)
	var farthest_column:int = start_column + column_step * (tokens_to_win - 1)
	
	if farthest_row < 0 or farthest_row >= rows:
		return slots
	
	if farthest_column < 0 or farthest_column >= columns:
		return slots
	
	for i in range(tokens_to_win):
		var check_row:int = start_row + row_step * i
		var check_column:int = start_column + column_step * i
		var check_pos:Vector2i = Vector2i(check_column, check_row)
		var checked_token:Token = board.get_token(check_pos)
		
		if checked_token == null:
			slots.clear()
			return slots
		
		if is_instance_valid(checked_token) == false:
			slots.clear()
			return slots
		
		if checked_token.being_destroyed:
			slots.clear()
			return slots
		
		if checked_token.player_id != player_id:
			slots.clear()
			return slots
		
		slots.append(check_pos)
	
	return slots


func play_winning_sequence(winner_id:int, winning_slots:Array[Vector2i]) -> void:
	if board == null:
		return
	
	if board.visuals == null:
		return
	
	var reveal_effects:Array[BoardVisualEffect] = create_chameleon_reveal_effects()
	
	if reveal_effects.is_empty() == false:
		board.visuals.queue_effect(ParallelVisualEffect.new(reveal_effects))
	
	if winning_slots.size() < 2:
		return
	
	var winning_color:Color = get_player_win_color(winner_id)
	var effect:WinningLineVisualEffect = WinningLineVisualEffect.new(board, winning_slots, winning_color, board.visuals.winning_line_duration)
	
	effect.line_width = board.visuals.winning_line_width
	effect.line_padding = board.visuals.winning_line_padding
	effect.shadow_width_multiplier = board.visuals.winning_line_shadow_width_multiplier
	effect.shadow_color = board.visuals.winning_line_shadow_color
	effect.line_z_index = board.visuals.winning_line_z_index
	
	board.visuals.queue_effect(effect)


func create_chameleon_reveal_effects() -> Array[BoardVisualEffect]:
	var effects:Array[BoardVisualEffect] = []
	
	if board == null:
		return effects
	
	var rows:int = board.settings.rows
	var columns:int = board.settings.columns
	
	for row in range(rows):
		for column in range(columns):
			var pos:Vector2i = Vector2i(column, row)
			var token:Token = board.get_token(pos)
			
			if token == null:
				continue
			
			if is_instance_valid(token) == false:
				continue
			
			if token.being_destroyed:
				continue
			
			if token.has_method("create_chameleon_reveal_effect") == false:
				continue
			
			var reveal_effect:BoardVisualEffect = token.create_chameleon_reveal_effect()
			
			if reveal_effect == null:
				continue
			
			effects.append(reveal_effect)
	
	return effects


func get_player_win_color(player_id:int) -> Color:
	if game_manager == null:
		return Color.WHITE
	
	if player_id < 0:
		return Color.WHITE
	
	if player_id >= game_manager.player_colours.size():
		return Color.WHITE
	
	var palette:ColorPalette = game_manager.player_colours[player_id]
	
	if palette == null:
		return Color.WHITE
	
	if palette.colors.size() >= 3:
		return palette.colors[2]
	
	if palette.colors.size() > 0:
		return palette.colors[0]
	
	return Color.WHITE
