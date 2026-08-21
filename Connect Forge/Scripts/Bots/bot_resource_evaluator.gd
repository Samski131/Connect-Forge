class_name BotResourceEvaluator
extends RefCounted

# Purchasable tokens derive their underlying value from their shop cost.
# A 5-point token should therefore carry more opportunity cost than a
# 1-point token before scarcity is considered.
const PURCHASABLE_COST_WEIGHT:float = 2.0

# Tokens that are not bought from the lobby, such as Basic, still have
# a small opportunity cost because the tray count is finite, but their
# internal TokenLibrary cost is not treated as a shop value.
const NON_PURCHASABLE_BASE_VALUE:float = 0.5

# As the current number of copies falls, each remaining copy becomes
# more strategically significant.
const SCARCITY_STRENGTH:float = 1.0

# As the player works through their original round inventory, spending
# another copy becomes somewhat more expensive.
const DEPLETION_STRENGTH:float = 1.0

# Consuming the final remaining copy deserves an additional penalty.
const LAST_COPY_MULTIPLIER:float = 1.5


func evaluate_simulation_result(source_session:MatchSession, simulation_result:BotSimulationResult) -> BotResourceEvaluationResult:
	if source_session == null:
		return create_failure_result("BotResourceEvaluator: Source MatchSession is null.")
	
	if simulation_result == null:
		return create_failure_result("BotResourceEvaluator: Simulation result is null.")
	
	if simulation_result.success == false:
		return create_failure_result("BotResourceEvaluator: Cannot evaluate resources from a failed simulation: %s" % simulation_result.error_message)
	
	if simulation_result.state == null:
		return create_failure_result("BotResourceEvaluator: Simulation result has no state.")
	
	if simulation_result.state.session == null:
		return create_failure_result("BotResourceEvaluator: Simulation result has no MatchSession.")
	
	if simulation_result.action == null:
		return create_failure_result("BotResourceEvaluator: Simulation result has no BotAction.")
	
	return evaluate_inventory_change(source_session, simulation_result.state.session, simulation_result.action)


func evaluate_inventory_change(before_session:MatchSession, after_session:MatchSession, action:BotAction) -> BotResourceEvaluationResult:
	var result:BotResourceEvaluationResult = BotResourceEvaluationResult.new()
	
	if before_session == null:
		result.mark_failure("BotResourceEvaluator: Before MatchSession is null.")
		return result
	
	if after_session == null:
		result.mark_failure("BotResourceEvaluator: After MatchSession is null.")
		return result
	
	if action == null:
		result.mark_failure("BotResourceEvaluator: BotAction is null.")
		return result
	
	if action.is_well_formed() == false:
		result.mark_failure("BotResourceEvaluator: BotAction is not well formed.")
		return result
	
	if before_session.is_valid_player_id(action.player_id) == false:
		result.mark_failure("BotResourceEvaluator: Action player is invalid in the before session.")
		return result
	
	if after_session.is_valid_player_id(action.player_id) == false:
		result.mark_failure("BotResourceEvaluator: Action player is invalid in the after session.")
		return result
	
	var before_player:MatchSessionPlayerData = before_session.get_player(action.player_id)
	var after_player:MatchSessionPlayerData = after_session.get_player(action.player_id)
	
	if before_player == null:
		result.mark_failure("BotResourceEvaluator: Before session has no action player.")
		return result
	
	if after_player == null:
		result.mark_failure("BotResourceEvaluator: After session has no action player.")
		return result
	
	if TokenLibrary.get_token_data(action.token_type).is_empty():
		result.mark_failure("BotResourceEvaluator: Action references an unknown token type.")
		return result
	
	result.player_id = action.player_id
	result.token_type = action.token_type
	result.token_name = TokenLibrary.get_display_name(action.token_type)
	
	result.token_cost = max(TokenLibrary.get_cost(action.token_type), 0)
	result.purchasable = TokenLibrary.is_available_in_lobby(action.token_type)
	
	result.starting_count = before_player.get_starting_token_count(action.token_type)
	result.before_count = before_player.get_token_count(action.token_type)
	result.after_count = after_player.get_token_count(action.token_type)
	
	if result.before_count < 0:
		result.mark_failure("BotResourceEvaluator: Before token count is invalid.")
		return result
	
	if result.after_count < 0:
		result.mark_failure("BotResourceEvaluator: After token count is invalid.")
		return result
	
	result.spent_count = max(result.before_count - result.after_count, 0)
	
	if result.spent_count == 0:
		result.preservation_penalty = 0.0
		result.mark_success()
		return result
	
	var reference_starting_count:int = result.starting_count
	
	# This fallback makes the evaluator safe for debug/generated positions
	# where current inventory has been manually assigned without also
	# configuring the round's original inventory.
	if reference_starting_count < result.before_count:
		reference_starting_count = result.before_count
	
	if reference_starting_count <= 0:
		reference_starting_count = max(result.before_count, 1)
	
	result.scarcity_multiplier = calculate_scarcity_multiplier(result.before_count)
	result.depletion_multiplier = calculate_depletion_multiplier(result.after_count, reference_starting_count)
	
	if result.after_count == 0:
		result.last_copy_multiplier = LAST_COPY_MULTIPLIER
	else:
		result.last_copy_multiplier = 1.0
	
	var base_unit_value:float = calculate_base_unit_value(action.token_type)
	
	result.preservation_penalty = base_unit_value
	result.preservation_penalty *= float(result.spent_count)
	result.preservation_penalty *= result.scarcity_multiplier
	result.preservation_penalty *= result.depletion_multiplier
	result.preservation_penalty *= result.last_copy_multiplier
	
	result.mark_success()
	return result


func calculate_base_unit_value(token_type:int) -> float:
	if TokenLibrary.get_token_data(token_type).is_empty():
		return 0.0
	
	if TokenLibrary.is_available_in_lobby(token_type):
		var token_cost:int = max(TokenLibrary.get_cost(token_type), 1)
		return float(token_cost) * PURCHASABLE_COST_WEIGHT
	
	return NON_PURCHASABLE_BASE_VALUE


func calculate_scarcity_multiplier(before_count:int) -> float:
	if before_count <= 0:
		return 1.0
	
	return 1.0 + (SCARCITY_STRENGTH / float(before_count))


func calculate_depletion_multiplier(after_count:int, starting_count:int) -> float:
	if starting_count <= 0:
		return 1.0
	
	var remaining_fraction:float = float(max(after_count, 0)) / float(starting_count)
	remaining_fraction = clamp(remaining_fraction, 0.0, 1.0)
	
	var depletion_fraction:float = 1.0 - remaining_fraction
	
	return 1.0 + (depletion_fraction * DEPLETION_STRENGTH)


func create_failure_result(error_message:String) -> BotResourceEvaluationResult:
	var result:BotResourceEvaluationResult = BotResourceEvaluationResult.new()
	result.mark_failure(error_message)
	return result
