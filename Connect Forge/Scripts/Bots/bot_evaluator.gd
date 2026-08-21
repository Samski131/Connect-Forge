class_name BotEvaluator
extends RefCounted

const TERMINAL_WIN_SCORE:float = 1000000.0
const TERMINAL_LOSS_SCORE:float = -1000000.0

# A line that is one token away from winning is worth this amount.
# Lines further from completion fall away exponentially.
const NEAR_WIN_LINE_SCORE:float = 100.0
const LINE_DISTANCE_FALLOFF:float = 6.0

const WINDOW_VALID:String = "valid"
const WINDOW_EMPTY:String = "empty"
const WINDOW_CONTESTED:String = "contested"
const WINDOW_OWNER_ID:String = "owner_id"
const WINDOW_TOKEN_COUNT:String = "token_count"
const WINDOW_VALUE:String = "value"


func evaluate_simulation_result(simulation_result:BotSimulationResult, perspective_player_id:int) -> BotEvaluationResult:
	if simulation_result == null:
		return create_failure_result(perspective_player_id, "BotEvaluator: Simulation result is null.")
	
	if simulation_result.success == false:
		return create_failure_result(perspective_player_id, "BotEvaluator: Cannot evaluate a failed simulation: %s" % simulation_result.error_message)
	
	if simulation_result.state == null:
		return create_failure_result(perspective_player_id, "BotEvaluator: Simulation result has no state.")
	
	return evaluate_state(simulation_result.state, perspective_player_id)


func evaluate_state(state:BotSimulationState, perspective_player_id:int) -> BotEvaluationResult:
	var result:BotEvaluationResult = BotEvaluationResult.new()
	result.perspective_player_id = perspective_player_id
	
	if state == null:
		result.mark_failure("BotEvaluator: Cannot evaluate a null simulation state.")
		return result
	
	if state.is_valid_state() == false:
		result.mark_failure("BotEvaluator: Simulation state is invalid.")
		return result
	
	if state.session == null:
		result.mark_failure("BotEvaluator: Simulation state has no MatchSession.")
		return result
	
	if state.board_state == null:
		result.mark_failure("BotEvaluator: Simulation state has no BoardState.")
		return result
	
	if state.settings == null:
		result.mark_failure("BotEvaluator: Simulation state has no BoardSetting.")
		return result
	
	var session:MatchSession = state.session
	var board_state:BoardState = state.board_state
	var settings:BoardSetting = state.settings
	
	if session.is_valid_player_id(perspective_player_id) == false:
		result.mark_failure("BotEvaluator: Perspective player ID is invalid.")
		return result
	
	if session.is_player_active(perspective_player_id) == false:
		result.mark_failure("BotEvaluator: Perspective player is not active.")
		return result
	
	if settings.columns <= 0 or settings.rows <= 0:
		result.mark_failure("BotEvaluator: Board dimensions are invalid.")
		return result
	
	if settings.tokens_to_win <= 0:
		result.mark_failure("BotEvaluator: tokens_to_win must be greater than zero.")
		return result
	
	var active_player_ids:Array[int] = session.get_active_player_ids()
	
	for player_id in active_player_ids:
		result.initialize_player(player_id)
	
	result.winner_id = session.winner_id
	
	if result.winner_id != -1:
		result.terminal = true
		
		if result.winner_id == perspective_player_id:
			result.score = TERMINAL_WIN_SCORE
		else:
			result.score = TERMINAL_LOSS_SCORE
		
		result.mark_success()
		return result
	
	for y in range(settings.rows):
		for x in range(settings.columns):
			var start_pos:Vector2i = Vector2i(x, y)
			
			for direction in ResolutionLogic.WIN_DIRECTIONS:
				if window_fits_board(start_pos, direction, settings) == false:
					continue
				
				var window:Dictionary = evaluate_window(board_state, settings, start_pos, direction)
				
				if bool(window.get(WINDOW_VALID, false)) == false:
					result.mark_failure("BotEvaluator: Encountered invalid token data while evaluating window from %s in direction %s." % [str(start_pos), str(direction)])
					return result
				
				result.total_windows += 1
				
				if bool(window.get(WINDOW_EMPTY, false)):
					result.empty_windows += 1
					continue
				
				if bool(window.get(WINDOW_CONTESTED, false)):
					result.contested_windows += 1
					continue
				
				var owner_id:int = int(window.get(WINDOW_OWNER_ID, -1))
				
				if session.is_valid_player_id(owner_id) == false:
					result.mark_failure("BotEvaluator: Board contains a token with invalid player ownership.")
					return result
				
				# Tokens belonging to an inactive player still physically block
				# windows, but the inactive player is no longer a competing
				# participant and therefore receives no strategic score.
				if session.is_player_active(owner_id) == false:
					continue
				
				var line_value:float = float(window.get(WINDOW_VALUE, 0.0))
				result.add_line_score(owner_id, line_value)
	
	var perspective_score:float = result.get_player_line_score(perspective_player_id)
	var opponent_score:float = 0.0
	
	for player_id in active_player_ids:
		if player_id == perspective_player_id:
			continue
		
		opponent_score += result.get_player_line_score(player_id)
	
	result.score = perspective_score - opponent_score
	result.mark_success()
	
	return result


func evaluate_window(board_state:BoardState, settings:BoardSetting, start_pos:Vector2i, direction:Vector2i) -> Dictionary:
	var invalid_result:Dictionary = {
		WINDOW_VALID: false,
		WINDOW_EMPTY: false,
		WINDOW_CONTESTED: false,
		WINDOW_OWNER_ID: -1,
		WINDOW_TOKEN_COUNT: 0,
		WINDOW_VALUE: 0.0
	}
	
	if board_state == null:
		return invalid_result
	
	if settings == null:
		return invalid_result
	
	if settings.tokens_to_win <= 0:
		return invalid_result
	
	if direction == Vector2i.ZERO:
		return invalid_result
	
	if window_fits_board(start_pos, direction, settings) == false:
		return invalid_result
	
	var owner_id:int = -1
	var token_count:int = 0
	var contested:bool = false
	
	for step_index in range(settings.tokens_to_win):
		var check_pos:Vector2i = start_pos + direction * step_index
		var token:Token = board_state.get_token(check_pos)
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			return invalid_result
		
		if token.being_destroyed:
			return invalid_result
		
		var token_owner_id:int = get_token_owner_for_evaluation(token)
		
		if token_owner_id < 0:
			return invalid_result
		
		if owner_id == -1:
			owner_id = token_owner_id
		elif owner_id != token_owner_id:
			contested = true
		
		token_count += 1
	
	if token_count == 0:
		return {
			WINDOW_VALID: true,
			WINDOW_EMPTY: true,
			WINDOW_CONTESTED: false,
			WINDOW_OWNER_ID: -1,
			WINDOW_TOKEN_COUNT: 0,
			WINDOW_VALUE: 0.0
		}
	
	if contested:
		return {
			WINDOW_VALID: true,
			WINDOW_EMPTY: false,
			WINDOW_CONTESTED: true,
			WINDOW_OWNER_ID: -1,
			WINDOW_TOKEN_COUNT: token_count,
			WINDOW_VALUE: 0.0
		}
	
	return {
		WINDOW_VALID: true,
		WINDOW_EMPTY: false,
		WINDOW_CONTESTED: false,
		WINDOW_OWNER_ID: owner_id,
		WINDOW_TOKEN_COUNT: token_count,
		WINDOW_VALUE: calculate_line_value(token_count, settings.tokens_to_win)
	}


func calculate_line_value(token_count:int, tokens_to_win:int) -> float:
	if token_count <= 0:
		return 0.0
	
	if tokens_to_win <= 0:
		return 0.0
	
	var distance_to_win:int = tokens_to_win - token_count
	
	if distance_to_win <= 0:
		return NEAR_WIN_LINE_SCORE * LINE_DISTANCE_FALLOFF
	
	var falloff_steps:int = distance_to_win - 1
	var divisor:float = pow(LINE_DISTANCE_FALLOFF, float(falloff_steps))
	
	return NEAR_WIN_LINE_SCORE / divisor


func window_fits_board(start_pos:Vector2i, direction:Vector2i, settings:BoardSetting) -> bool:
	if settings == null:
		return false
	
	if settings.tokens_to_win <= 0:
		return false
	
	if start_pos.x < 0 or start_pos.x >= settings.columns:
		return false
	
	if start_pos.y < 0 or start_pos.y >= settings.rows:
		return false
	
	var end_pos:Vector2i = start_pos + direction * (settings.tokens_to_win - 1)
	
	if end_pos.x < 0 or end_pos.x >= settings.columns:
		return false
	
	if end_pos.y < 0 or end_pos.y >= settings.rows:
		return false
	
	return true


func get_token_owner_for_evaluation(token:Token) -> int:
	if token == null:
		return -1
	
	if is_instance_valid(token) == false:
		return -1
	
	return token.player_id


func create_failure_result(perspective_player_id:int, error_message:String) -> BotEvaluationResult:
	var result:BotEvaluationResult = BotEvaluationResult.new()
	result.perspective_player_id = perspective_player_id
	result.mark_failure(error_message)
	return result
