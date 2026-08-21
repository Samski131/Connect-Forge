class_name BotMoveSelector
extends RefCounted

const DEFAULT_SELECTION_SEED:int = 90000
const SCORE_TOLERANCE:float = 0.0001



func select_best_action(source_session:MatchSession, source_board_state:BoardState, source_settings:BoardSetting, player_id:int, base_simulation_seed:int = DEFAULT_SELECTION_SEED) -> BotMoveSelectionResult:
	var selection_start_usec:int = Time.get_ticks_usec()
	
	var result:BotMoveSelectionResult = BotMoveSelectionResult.new()
	result.player_id = player_id
	
	var validation_error:String = validate_selection_sources(
		source_session,
		source_board_state,
		source_settings,
		player_id
	)
	
	if validation_error != "":
		result.mark_failure(validation_error)
		result.total_selection_time_usec = Time.get_ticks_usec() - selection_start_usec
		return result
	
	var generation_start_usec:int = Time.get_ticks_usec()
	
	var actions:Array[BotAction] = BotActionGenerator.generate_actions(
		source_session,
		source_board_state,
		source_settings,
		player_id
	)
	
	result.action_generation_time_usec = Time.get_ticks_usec() - generation_start_usec
	result.generated_action_count = actions.size()
	
	if actions.is_empty():
		result.mark_failure("BotMoveSelector: Current player has no legal BotActions.")
		result.total_selection_time_usec = Time.get_ticks_usec() - selection_start_usec
		return result
	
	var action_evaluator:BotActionEvaluator = BotActionEvaluator.new()
	var evaluations:Array[BotActionEvaluation] = []
	
	var evaluation_start_usec:int = Time.get_ticks_usec()
	
	for action in actions:
		if action == null:
			result.mark_failure("BotMoveSelector: BotActionGenerator returned a null action.")
			result.action_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			result.total_selection_time_usec = Time.get_ticks_usec() - selection_start_usec
			return result
		
		if action.is_well_formed() == false:
			result.mark_failure("BotMoveSelector: BotActionGenerator returned a malformed action.")
			result.action_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			result.total_selection_time_usec = Time.get_ticks_usec() - selection_start_usec
			return result
		
		var evaluation:BotActionEvaluation = action_evaluator.evaluate_action(
			source_session,
			source_board_state,
			source_settings,
			action,
			base_simulation_seed
		)
		
		if evaluation == null:
			result.mark_failure("BotMoveSelector: BotActionEvaluator returned null for %s." % action.get_description())
			result.action_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			result.total_selection_time_usec = Time.get_ticks_usec() - selection_start_usec
			return result
		
		if evaluation.valid == false:
			result.mark_failure("BotMoveSelector: Evaluation failed for %s: %s" % [action.get_description(), evaluation.error_message])
			result.action_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
			result.total_selection_time_usec = Time.get_ticks_usec() - selection_start_usec
			return result
		
		evaluations.append(evaluation)
	
	result.action_evaluation_time_usec = Time.get_ticks_usec() - evaluation_start_usec
	
	var ranking_start_usec:int = Time.get_ticks_usec()
	var ranked_evaluations:Array[BotActionEvaluation] = rank_evaluations(evaluations)
	result.ranking_time_usec = Time.get_ticks_usec() - ranking_start_usec
	
	if ranked_evaluations.size() != actions.size():
		result.mark_failure("BotMoveSelector: Ranked evaluation count does not match generated action count.")
		result.total_selection_time_usec = Time.get_ticks_usec() - selection_start_usec
		return result
	
	if result.set_ranked_evaluations(ranked_evaluations) == false:
		result.mark_failure("BotMoveSelector: Could not store ranked action evaluations.")
		result.total_selection_time_usec = Time.get_ticks_usec() - selection_start_usec
		return result
	
	result.mark_success()
	result.total_selection_time_usec = Time.get_ticks_usec() - selection_start_usec
	
	return result

func validate_selection_sources(source_session:MatchSession, source_board_state:BoardState, source_settings:BoardSetting, player_id:int) -> String:
	if source_session == null:
		return "BotMoveSelector: MatchSession is null."
	
	if source_board_state == null:
		return "BotMoveSelector: BoardState is null."
	
	if source_settings == null:
		return "BotMoveSelector: BoardSetting is null."
	
	if source_session.is_valid_player_id(player_id) == false:
		return "BotMoveSelector: Player ID is invalid."
	
	if source_session.is_player_active(player_id) == false:
		return "BotMoveSelector: Player is not active."
	
	if source_session.current_player_id != player_id:
		return "BotMoveSelector: Requested player is not the current player."
	
	if source_session.current_turn_phase != Global.TURN_PHASE.PLACEMENT:
		return "BotMoveSelector: Bot move selection can only run during the placement phase."
	
	if source_session.winner_id != -1:
		return "BotMoveSelector: Cannot choose another move after a winner has been recorded."
	
	return ""


func rank_evaluations(evaluations:Array[BotActionEvaluation]) -> Array[BotActionEvaluation]:
	var ranked:Array[BotActionEvaluation] = []
	
	for evaluation in evaluations:
		if evaluation == null:
			continue
		
		var inserted:bool = false
		
		for rank_index in range(ranked.size()):
			var existing:BotActionEvaluation = ranked[rank_index]
			
			if is_evaluation_better(evaluation, existing):
				ranked.insert(rank_index, evaluation)
				inserted = true
				break
		
		if inserted == false:
			ranked.append(evaluation)
	
	return ranked


func is_evaluation_better(candidate:BotActionEvaluation, incumbent:BotActionEvaluation) -> bool:
	if candidate == null:
		return false
	
	if incumbent == null:
		return true
	
	if candidate.final_score > incumbent.final_score + SCORE_TOLERANCE:
		return true
	
	if incumbent.final_score > candidate.final_score + SCORE_TOLERANCE:
		return false
	
	# In a near-tie, prefer the action with the greater immediate win chance.
	if candidate.win_probability > incumbent.win_probability + SCORE_TOLERANCE:
		return true
	
	if incumbent.win_probability > candidate.win_probability + SCORE_TOLERANCE:
		return false
	
	# Then prefer the action with less immediate loss probability.
	if candidate.loss_probability + SCORE_TOLERANCE < incumbent.loss_probability:
		return true
	
	if incumbent.loss_probability + SCORE_TOLERANCE < candidate.loss_probability:
		return false
	
	# Prefer the safer tactical position.
	if candidate.expected_tactical_adjustment > incumbent.expected_tactical_adjustment + SCORE_TOLERANCE:
		return true
	
	if incumbent.expected_tactical_adjustment > candidate.expected_tactical_adjustment + SCORE_TOLERANCE:
		return false
	
	# Then the stronger raw board position.
	if candidate.expected_board_score > incumbent.expected_board_score + SCORE_TOLERANCE:
		return true
	
	if incumbent.expected_board_score > candidate.expected_board_score + SCORE_TOLERANCE:
		return false
	
	# Then preserve the cheaper resource.
	if candidate.resource_penalty + SCORE_TOLERANCE < incumbent.resource_penalty:
		return true
	
	if incumbent.resource_penalty + SCORE_TOLERANCE < candidate.resource_penalty:
		return false
	
	return is_action_before(candidate.action, incumbent.action)


func is_action_before(candidate:BotAction, incumbent:BotAction) -> bool:
	if candidate == null:
		return false
	
	if incumbent == null:
		return true
	
	if candidate.token_type != incumbent.token_type:
		return candidate.token_type < incumbent.token_type
	
	if candidate.starting_slot.x != incumbent.starting_slot.x:
		return candidate.starting_slot.x < incumbent.starting_slot.x
	
	if candidate.starting_slot.y != incumbent.starting_slot.y:
		return candidate.starting_slot.y < incumbent.starting_slot.y
	
	if candidate.start_flipped != incumbent.start_flipped:
		return candidate.start_flipped == false
	
	var candidate_choice_key:String = var_to_str(candidate.get_choice_data())
	var incumbent_choice_key:String = var_to_str(incumbent.get_choice_data())
	
	if candidate_choice_key != incumbent_choice_key:
		return candidate_choice_key < incumbent_choice_key
	
	var candidate_placement_key:String = var_to_str(candidate.get_placement_data())
	var incumbent_placement_key:String = var_to_str(incumbent.get_placement_data())
	
	return candidate_placement_key < incumbent_placement_key
