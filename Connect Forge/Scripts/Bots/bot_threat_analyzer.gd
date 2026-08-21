class_name BotThreatAnalyzer
extends RefCounted

const DEFAULT_ANALYSIS_SEED:int = 50000
const PROBABILITY_TOLERANCE:float = 0.0001


func analyze_simulation_result(simulation_result:BotSimulationResult, base_simulation_seed:int = DEFAULT_ANALYSIS_SEED) -> BotThreatAnalysisResult:
	if simulation_result == null:
		return create_failure_result("BotThreatAnalyzer: Simulation result is null.")
	
	if simulation_result.success == false:
		return create_failure_result("BotThreatAnalyzer: Cannot analyze a failed simulation: %s" % simulation_result.error_message)
	
	if simulation_result.state == null:
		return create_failure_result("BotThreatAnalyzer: Simulation result has no state.")
	
	return analyze_state(simulation_result.state, base_simulation_seed)


func analyze_state(state:BotSimulationState, base_simulation_seed:int = DEFAULT_ANALYSIS_SEED) -> BotThreatAnalysisResult:
	var result:BotThreatAnalysisResult = BotThreatAnalysisResult.new()
	
	if state == null:
		result.mark_failure("BotThreatAnalyzer: Cannot analyze a null simulation state.")
		return result
	
	if state.is_valid_state() == false:
		result.mark_failure("BotThreatAnalyzer: Simulation state is invalid.")
		return result
	
	if state.session == null:
		result.mark_failure("BotThreatAnalyzer: Simulation state has no MatchSession.")
		return result
	
	if state.board_state == null:
		result.mark_failure("BotThreatAnalyzer: Simulation state has no BoardState.")
		return result
	
	if state.settings == null:
		result.mark_failure("BotThreatAnalyzer: Simulation state has no BoardSetting.")
		return result
	
	var session:MatchSession = state.session
	
	result.reference_current_player_id = session.current_player_id
	result.winner_id = session.winner_id
	
	if result.winner_id != -1:
		result.terminal = true
		result.next_player_id = -1
		result.mark_success()
		return result
	
	if session.is_player_active(session.current_player_id) == false:
		result.mark_failure("BotThreatAnalyzer: Current player is not an active player.")
		return result
	
	result.next_player_id = session.get_next_player_id()
	
	var active_player_ids:Array[int] = session.get_active_player_ids()
	
	for player_id in active_player_ids:
		var turn_distance:int = get_turn_distance(session, player_id)
		
		if turn_distance < 0:
			result.mark_failure("BotThreatAnalyzer: Could not determine turn distance for Player %d." % player_id)
			return result
		
		var player_seed:int = create_player_seed(base_simulation_seed, player_id)
		var player_result:BotPlayerThreatResult = analyze_player_immediate_wins(state, player_id, turn_distance, player_seed)
		
		if player_result == null:
			result.mark_failure("BotThreatAnalyzer: Player %d threat analysis returned null." % player_id)
			return result
		
		if player_result.valid == false:
			result.mark_failure(player_result.error_message)
			return result
		
		result.add_player_result(player_result)
	
	result.mark_success()
	return result


func analyze_player_immediate_wins(state:BotSimulationState, player_id:int, turn_distance:int, base_simulation_seed:int = DEFAULT_ANALYSIS_SEED) -> BotPlayerThreatResult:
	var result:BotPlayerThreatResult = BotPlayerThreatResult.new()
	result.setup(player_id, turn_distance)
	
	if state == null:
		result.mark_failure("BotThreatAnalyzer: Cannot analyze Player %d without a simulation state." % player_id)
		return result
	
	if state.is_valid_state() == false:
		result.mark_failure("BotThreatAnalyzer: Cannot analyze Player %d because the simulation state is invalid." % player_id)
		return result
	
	if state.session.is_valid_player_id(player_id) == false:
		result.mark_failure("BotThreatAnalyzer: Player %d is invalid." % player_id)
		return result
	
	if state.session.is_player_active(player_id) == false:
		result.mark_failure("BotThreatAnalyzer: Player %d is not active." % player_id)
		return result
	
	if state.session.winner_id != -1:
		result.mark_success()
		return result
	
	var analysis_source:BotSimulationState = BotSimulationStateCloner.clone_state(state.session, state.board_state, state.settings, base_simulation_seed)
	
	if analysis_source == null:
		result.mark_failure("BotThreatAnalyzer: Could not clone analysis state for Player %d." % player_id)
		return result
	
	analysis_source.session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	
	if analysis_source.session.set_current_player(player_id) == false:
		analysis_source.dispose()
		result.mark_failure("BotThreatAnalyzer: Could not make Player %d the hypothetical active player." % player_id)
		return result
	
	var actions:Array[BotAction] = BotActionGenerator.generate_actions(analysis_source.session, analysis_source.board_state, analysis_source.settings, player_id)
	result.legal_action_count = actions.size()
	
	for action_index in range(actions.size()):
		var action:BotAction = actions[action_index]
		
		if action == null:
			analysis_source.dispose()
			result.mark_failure("BotThreatAnalyzer: Player %d generated a null BotAction." % player_id)
			return result
		
		var chance_outcomes:Array[BotChanceOutcome] = BotSimulator.get_chance_outcomes(analysis_source.session, analysis_source.board_state, analysis_source.settings, action)
		
		if chance_outcomes.is_empty():
			analysis_source.dispose()
			result.mark_failure("BotThreatAnalyzer: Legal action produced no chance outcomes: %s" % action.get_description())
			return result
		
		var win_probability:float = 0.0
		var winning_outcome_count:int = 0
		
		for outcome_index in range(chance_outcomes.size()):
			var chance_outcome:BotChanceOutcome = chance_outcomes[outcome_index]
			
			if chance_outcome == null:
				analysis_source.dispose()
				result.mark_failure("BotThreatAnalyzer: Action contains a null chance outcome: %s" % action.get_description())
				return result
			
			if chance_outcome.is_valid() == false:
				analysis_source.dispose()
				result.mark_failure("BotThreatAnalyzer: Action contains an invalid chance outcome: %s" % action.get_description())
				return result
			
			var branch_seed:int = create_branch_seed(base_simulation_seed, player_id, action_index, outcome_index)
			var simulation_result:BotSimulationResult = BotSimulator.simulate_action(analysis_source.session, analysis_source.board_state, analysis_source.settings, chance_outcome.action, branch_seed)
			
			result.simulated_outcome_count += 1
			
			if simulation_result == null:
				analysis_source.dispose()
				result.mark_failure("BotThreatAnalyzer: Simulation returned null for %s." % action.get_description())
				return result
			
			if simulation_result.success == false:
				var simulation_error:String = simulation_result.error_message
				simulation_result.dispose()
				analysis_source.dispose()
				result.mark_failure("BotThreatAnalyzer: Simulation failed for %s: %s" % [action.get_description(), simulation_error])
				return result
			
			if simulation_result.winner_id == player_id:
				win_probability += chance_outcome.probability
				winning_outcome_count += 1
			
			simulation_result.dispose()
		
		if win_probability > PROBABILITY_TOLERANCE:
			var winning_action:BotImmediateWinAction = BotImmediateWinAction.new()
			
			if winning_action.setup(action, win_probability, chance_outcomes.size(), winning_outcome_count) == false:
				analysis_source.dispose()
				result.mark_failure("BotThreatAnalyzer: Could not store winning action %s." % action.get_description())
				return result
			
			result.add_winning_action(winning_action)
	
	analysis_source.dispose()
	result.mark_success()
	
	return result


func get_turn_distance(session:MatchSession, target_player_id:int) -> int:
	if session == null:
		return -1
	
	if session.is_player_active(target_player_id) == false:
		return -1
	
	if session.is_player_active(session.current_player_id) == false:
		return -1
	
	if target_player_id == session.current_player_id:
		return 0
	
	var player_count:int = session.get_player_count()
	var active_turn_distance:int = 0
	
	for offset in range(1, player_count + 1):
		var candidate_player_id:int = (session.current_player_id + offset) % player_count
		
		if session.is_player_active(candidate_player_id) == false:
			continue
		
		active_turn_distance += 1
		
		if candidate_player_id == target_player_id:
			return active_turn_distance
	
	return -1


func create_player_seed(base_seed:int, player_id:int) -> int:
	return base_seed + ((player_id + 1) * 1000003)


func create_branch_seed(base_seed:int, player_id:int, action_index:int, outcome_index:int) -> int:
	var result:int = base_seed
	result += (player_id + 1) * 1000003
	result += (action_index + 1) * 1009
	result += (outcome_index + 1) * 37
	return result


func create_failure_result(error_message:String) -> BotThreatAnalysisResult:
	var result:BotThreatAnalysisResult = BotThreatAnalysisResult.new()
	result.mark_failure(error_message)
	return result
