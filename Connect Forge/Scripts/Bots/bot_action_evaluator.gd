class_name BotActionEvaluator
extends RefCounted

const DEFAULT_EVALUATION_SEED:int = 70000

# An opponent who can certainly win on their immediately upcoming turn
# should overwhelm ordinary positional evaluation.
const IMMEDIATE_THREAT_BASE_PENALTY:float = 50000.0

# Each additional active turn before an opponent acts halves the urgency.
const THREAT_TURN_DISTANCE_FALLOFF:float = 0.5


func evaluate_action(source_session:MatchSession, source_board_state:BoardState, source_settings:BoardSetting, source_action:BotAction, base_simulation_seed:int = DEFAULT_EVALUATION_SEED) -> BotActionEvaluation:
	var evaluation_start_usec:int = Time.get_ticks_usec()
	var result:BotActionEvaluation = BotActionEvaluation.new()
	
	if source_action == null:
		result.mark_failure("BotActionEvaluator: Cannot evaluate a null action.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	if result.setup(source_action) == false:
		result.mark_failure("BotActionEvaluator: BotAction is not well formed.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	if source_session == null:
		result.mark_failure("BotActionEvaluator: Source MatchSession is null.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	if source_board_state == null:
		result.mark_failure("BotActionEvaluator: Source BoardState is null.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	if source_settings == null:
		result.mark_failure("BotActionEvaluator: Source BoardSetting is null.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	if source_session.is_valid_player_id(source_action.player_id) == false:
		result.mark_failure("BotActionEvaluator: Action player is invalid.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	if source_session.is_player_active(source_action.player_id) == false:
		result.mark_failure("BotActionEvaluator: Action player is not active.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	if source_session.current_player_id != source_action.player_id:
		result.mark_failure("BotActionEvaluator: Action player is not the current player.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	var chance_start_usec:int = Time.get_ticks_usec()
	
	var chance_outcomes:Array[BotChanceOutcome] = BotSimulator.get_chance_outcomes(
		source_session,
		source_board_state,
		source_settings,
		source_action
	)
	
	result.chance_outcome_generation_time_usec += Time.get_ticks_usec() - chance_start_usec
	
	if chance_outcomes.is_empty():
		result.mark_failure("BotActionEvaluator: Action has no legal chance outcomes.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	var board_evaluator:BotEvaluator = BotEvaluator.new()
	var threat_analyzer:BotThreatAnalyzer = BotThreatAnalyzer.new()
	var resource_evaluator:BotResourceEvaluator = BotResourceEvaluator.new()
	
	var resource_evaluation:BotResourceEvaluationResult = null
	
	for outcome_index in range(chance_outcomes.size()):
		var chance_outcome:BotChanceOutcome = chance_outcomes[outcome_index]
		
		if chance_outcome == null:
			result.mark_failure("BotActionEvaluator: Chance outcome %d is null." % outcome_index)
			result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			return result
		
		if chance_outcome.is_valid() == false:
			result.mark_failure("BotActionEvaluator: Chance outcome %d is invalid." % outcome_index)
			result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			return result
		
		var branch_seed:int = create_outcome_seed(base_simulation_seed, source_action, outcome_index)
		
		var primary_simulation_start_usec:int = Time.get_ticks_usec()
		
		var simulation_result:BotSimulationResult = BotSimulator.simulate_action(
			source_session,
			source_board_state,
			source_settings,
			chance_outcome.action,
			branch_seed
		)
		
		result.primary_simulation_time_usec += Time.get_ticks_usec() - primary_simulation_start_usec
		
		if simulation_result == null:
			result.mark_failure("BotActionEvaluator: Simulation returned null.")
			result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			return result
		
		if simulation_result.success == false:
			var simulation_error:String = simulation_result.error_message
			simulation_result.dispose()
			result.mark_failure("BotActionEvaluator: Simulation failed: %s" % simulation_error)
			result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			return result
		
		var board_evaluation_start_usec:int = Time.get_ticks_usec()
		
		var board_evaluation:BotEvaluationResult = board_evaluator.evaluate_simulation_result(
			simulation_result,
			source_action.player_id
		)
		
		result.board_evaluation_time_usec += Time.get_ticks_usec() - board_evaluation_start_usec
		
		if board_evaluation == null:
			simulation_result.dispose()
			result.mark_failure("BotActionEvaluator: Board evaluation returned null.")
			result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			return result
		
		if board_evaluation.valid == false:
			var board_error:String = board_evaluation.error_message
			simulation_result.dispose()
			result.mark_failure("BotActionEvaluator: Board evaluation failed: %s" % board_error)
			result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			return result
		
		var outcome_evaluation:BotActionOutcomeEvaluation = BotActionOutcomeEvaluation.new()
		
		if outcome_evaluation.setup(chance_outcome.probability) == false:
			simulation_result.dispose()
			result.mark_failure("BotActionEvaluator: Could not create outcome evaluation.")
			result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			return result
		
		outcome_evaluation.set_board_evaluation(
			board_evaluation.score,
			board_evaluation.terminal,
			board_evaluation.winner_id
		)
		
		if board_evaluation.terminal == false:
			var tactical_start_usec:int = Time.get_ticks_usec()
			
			var tactical_error:String = evaluate_opponent_threats(
				simulation_result.state,
				source_action.player_id,
				create_tactical_seed(base_simulation_seed, outcome_index),
				threat_analyzer,
				outcome_evaluation
			)
			
			result.tactical_analysis_time_usec += Time.get_ticks_usec() - tactical_start_usec
			
			if tactical_error != "":
				simulation_result.dispose()
				result.mark_failure(tactical_error)
				result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
				return result
		
		if resource_evaluation == null:
			var resource_start_usec:int = Time.get_ticks_usec()
			
			resource_evaluation = resource_evaluator.evaluate_simulation_result(
				source_session,
				simulation_result
			)
			
			result.resource_evaluation_time_usec += Time.get_ticks_usec() - resource_start_usec
			
			if resource_evaluation == null:
				simulation_result.dispose()
				result.mark_failure("BotActionEvaluator: Resource evaluation returned null.")
				result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
				return result
			
			if resource_evaluation.valid == false:
				var resource_error:String = resource_evaluation.error_message
				simulation_result.dispose()
				result.mark_failure("BotActionEvaluator: Resource evaluation failed: %s" % resource_error)
				result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
				return result
		
		if result.add_outcome_evaluation(outcome_evaluation) == false:
			simulation_result.dispose()
			result.mark_failure("BotActionEvaluator: Could not add outcome evaluation.")
			result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			return result
		
		simulation_result.dispose()
	
	if resource_evaluation == null:
		result.mark_failure("BotActionEvaluator: No resource evaluation was produced.")
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	if result.finalize(resource_evaluation.preservation_penalty) == false:
		result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
		return result
	
	result.total_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
	
	return result


func evaluate_opponent_threats(state:BotSimulationState, perspective_player_id:int, base_simulation_seed:int, threat_analyzer:BotThreatAnalyzer, outcome_evaluation:BotActionOutcomeEvaluation) -> String:
	if state == null:
		return "BotActionEvaluator: Cannot evaluate threats without simulation state."
	
	if state.is_valid_state() == false:
		return "BotActionEvaluator: Cannot evaluate threats from an invalid simulation state."
	
	if threat_analyzer == null:
		return "BotActionEvaluator: Threat analyzer is null."
	
	if outcome_evaluation == null:
		return "BotActionEvaluator: Outcome evaluation is null."
	
	if state.session.is_valid_player_id(perspective_player_id) == false:
		return "BotActionEvaluator: Perspective player is invalid during threat analysis."
	
	var active_player_ids:Array[int] = state.session.get_active_player_ids()
	
	for opponent_player_id in active_player_ids:
		if opponent_player_id == perspective_player_id:
			continue
		
		var turn_distance:int = threat_analyzer.get_turn_distance(
			state.session,
			opponent_player_id
		)
		
		if turn_distance <= 0:
			return "BotActionEvaluator: Could not determine positive turn distance for opponent Player %d." % opponent_player_id
		
		var player_seed:int = threat_analyzer.create_player_seed(
			base_simulation_seed,
			opponent_player_id
		)
		
		var player_result:BotPlayerThreatResult = threat_analyzer.analyze_player_immediate_wins(
			state,
			opponent_player_id,
			turn_distance,
			player_seed
		)
		
		if player_result == null:
			return "BotActionEvaluator: Threat analysis returned null for Player %d." % opponent_player_id
		
		if player_result.valid == false:
			return "BotActionEvaluator: Threat analysis failed for Player %d: %s" % [opponent_player_id, player_result.error_message]
		
		outcome_evaluation.tactical_simulated_outcome_count += player_result.simulated_outcome_count
		
		if player_result.has_immediate_win() == false:
			continue
		
		var threat_penalty:float = calculate_threat_penalty(
			player_result.best_win_probability,
			turn_distance
		)
		
		outcome_evaluation.add_opponent_threat(
			opponent_player_id,
			turn_distance,
			player_result.best_win_probability,
			threat_penalty
		)
	
	return ""


func calculate_threat_penalty(best_win_probability:float, turn_distance:int) -> float:
	if best_win_probability <= 0.0:
		return 0.0
	
	if turn_distance <= 0:
		return 0.0
	
	var used_probability:float = clamp(best_win_probability, 0.0, 1.0)
	var distance_steps:int = turn_distance - 1
	var distance_multiplier:float = pow(
		THREAT_TURN_DISTANCE_FALLOFF,
		float(distance_steps)
	)
	
	return IMMEDIATE_THREAT_BASE_PENALTY * used_probability * distance_multiplier


func create_outcome_seed(base_seed:int, action:BotAction, outcome_index:int) -> int:
	var result:int = base_seed
	
	if action != null:
		result += (action.player_id + 1) * 1000003
		result += (action.token_type + 1) * 1009
		result += (action.starting_slot.x + 1) * 101
		result += (action.starting_slot.y + 1) * 53
		
		if action.start_flipped:
			result += 17
	
	result += (outcome_index + 1) * 37
	
	return result


func create_tactical_seed(base_seed:int, outcome_index:int) -> int:
	return base_seed + 5000003 + ((outcome_index + 1) * 10007)
