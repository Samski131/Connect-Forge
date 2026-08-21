extends Node


func _ready() -> void:
	print("")
	print("========== BOT RESOURCE EVALUATOR TEST ==========")
	
	test_non_purchasable_token_has_small_baseline_cost()
	test_purchasable_token_has_meaningful_preservation_cost()
	test_last_copy_is_more_valuable_than_abundant_copy()
	test_depleted_inventory_is_more_valuable_than_fresh_inventory()
	test_more_expensive_token_has_more_resource_value()
	test_zero_resource_change_has_zero_penalty()
	test_simulated_action_uses_real_before_and_after_inventory()
	test_resource_evaluation_does_not_mutate_sessions()
	
	print("========== ALL BOT RESOURCE EVALUATOR TESTS PASSED ==========")
	print("")


func test_non_purchasable_token_has_small_baseline_cost() -> void:
	var evaluator:BotResourceEvaluator = BotResourceEvaluator.new()
	var before_session:MatchSession = create_test_session()
	var after_session:MatchSession = create_test_session()
	
	set_inventory(before_session, 0, TokenLibrary.TokenType.BASIC, 10, 10)
	set_inventory(after_session, 0, TokenLibrary.TokenType.BASIC, 10, 9)
	
	var action:BotAction = create_action(TokenLibrary.TokenType.BASIC)
	var evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(before_session, after_session, action)
	
	assert(evaluation != null, "Basic resource evaluation returned null.")
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.purchasable == false, "Basic should not be treated as a lobby-purchasable special token.")
	assert(evaluation.spent_count == 1, "Basic evaluation should detect one consumed token.")
	assert(evaluation.preservation_penalty > 0.0, "Basic should still carry a small finite-tray opportunity cost.")
	
	var special_token_type:int = get_any_purchasable_token_type()
	assert(special_token_type != -1, "Could not find a purchasable token for Basic comparison.")
	
	var special_before:MatchSession = create_test_session()
	var special_after:MatchSession = create_test_session()
	
	set_inventory(special_before, 0, special_token_type, 10, 10)
	set_inventory(special_after, 0, special_token_type, 10, 9)
	
	var special_action:BotAction = create_action(special_token_type)
	var special_evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(special_before, special_after, special_action)
	
	assert(special_evaluation.valid, special_evaluation.error_message)
	assert(special_evaluation.preservation_penalty > evaluation.preservation_penalty, "Purchasable special token should carry more preservation value than an equally abundant Basic token.")
	
	print("PASS: Non-purchasable normal tokens carry only a small baseline resource cost.")


func test_purchasable_token_has_meaningful_preservation_cost() -> void:
	var token_type:int = get_any_purchasable_token_type()
	assert(token_type != -1, "Could not find a purchasable token.")
	
	var evaluator:BotResourceEvaluator = BotResourceEvaluator.new()
	var before_session:MatchSession = create_test_session()
	var after_session:MatchSession = create_test_session()
	
	set_inventory(before_session, 0, token_type, 4, 4)
	set_inventory(after_session, 0, token_type, 4, 3)
	
	var evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(before_session, after_session, create_action(token_type))
	
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.purchasable, "Lobby token was not recognised as purchasable.")
	assert(evaluation.token_cost == TokenLibrary.get_cost(token_type), "Evaluator did not use the TokenLibrary shop cost.")
	assert(evaluation.spent_count == 1, "Evaluator did not detect one spent special token.")
	assert(evaluation.preservation_penalty > 0.0, "Purchasable token should have positive preservation value.")
	
	print("PASS: Purchasable tokens derive generic preservation value from their real shop cost.")


func test_last_copy_is_more_valuable_than_abundant_copy() -> void:
	var token_type:int = get_any_purchasable_token_type()
	assert(token_type != -1, "Could not find a purchasable token.")
	
	var evaluator:BotResourceEvaluator = BotResourceEvaluator.new()
	
	var abundant_before:MatchSession = create_test_session()
	var abundant_after:MatchSession = create_test_session()
	set_inventory(abundant_before, 0, token_type, 5, 5)
	set_inventory(abundant_after, 0, token_type, 5, 4)
	
	var last_before:MatchSession = create_test_session()
	var last_after:MatchSession = create_test_session()
	set_inventory(last_before, 0, token_type, 5, 1)
	set_inventory(last_after, 0, token_type, 5, 0)
	
	var action:BotAction = create_action(token_type)
	var abundant_evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(abundant_before, abundant_after, action)
	var last_evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(last_before, last_after, action)
	
	assert(abundant_evaluation.valid, abundant_evaluation.error_message)
	assert(last_evaluation.valid, last_evaluation.error_message)
	
	assert(last_evaluation.used_last_copy(), "Final-copy use was not recognised.")
	assert(last_evaluation.scarcity_multiplier > abundant_evaluation.scarcity_multiplier, "Final copy should have a larger scarcity multiplier.")
	assert(last_evaluation.last_copy_multiplier > abundant_evaluation.last_copy_multiplier, "Final copy should receive the last-copy multiplier.")
	assert(last_evaluation.preservation_penalty > abundant_evaluation.preservation_penalty, "Using the final copy should cost more than using one of many copies.")
	
	print("PASS: Spending the final copy of a token carries substantially greater opportunity cost.")


func test_depleted_inventory_is_more_valuable_than_fresh_inventory() -> void:
	var token_type:int = get_any_purchasable_token_type()
	assert(token_type != -1, "Could not find a purchasable token.")
	
	var evaluator:BotResourceEvaluator = BotResourceEvaluator.new()
	
	var fresh_before:MatchSession = create_test_session()
	var fresh_after:MatchSession = create_test_session()
	set_inventory(fresh_before, 0, token_type, 5, 5)
	set_inventory(fresh_after, 0, token_type, 5, 4)
	
	var depleted_before:MatchSession = create_test_session()
	var depleted_after:MatchSession = create_test_session()
	set_inventory(depleted_before, 0, token_type, 5, 2)
	set_inventory(depleted_after, 0, token_type, 5, 1)
	
	var action:BotAction = create_action(token_type)
	var fresh_evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(fresh_before, fresh_after, action)
	var depleted_evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(depleted_before, depleted_after, action)
	
	assert(fresh_evaluation.valid, fresh_evaluation.error_message)
	assert(depleted_evaluation.valid, depleted_evaluation.error_message)
	
	assert(depleted_evaluation.depletion_multiplier > fresh_evaluation.depletion_multiplier, "Heavily depleted inventory should receive a larger depletion multiplier.")
	assert(depleted_evaluation.preservation_penalty > fresh_evaluation.preservation_penalty, "Spending from a depleted supply should be more expensive.")
	
	print("PASS: Resource value increases as a player's original supply is depleted.")


func test_more_expensive_token_has_more_resource_value() -> void:
	var cheapest_token_type:int = get_cheapest_purchasable_token_type()
	var most_expensive_token_type:int = get_most_expensive_purchasable_token_type()
	
	assert(cheapest_token_type != -1, "Could not find cheapest purchasable token.")
	assert(most_expensive_token_type != -1, "Could not find most expensive purchasable token.")
	assert(TokenLibrary.get_cost(most_expensive_token_type) > TokenLibrary.get_cost(cheapest_token_type), "Current token roster needs at least two different shop costs for this test.")
	
	var evaluator:BotResourceEvaluator = BotResourceEvaluator.new()
	
	var cheap_before:MatchSession = create_test_session()
	var cheap_after:MatchSession = create_test_session()
	set_inventory(cheap_before, 0, cheapest_token_type, 4, 4)
	set_inventory(cheap_after, 0, cheapest_token_type, 4, 3)
	
	var expensive_before:MatchSession = create_test_session()
	var expensive_after:MatchSession = create_test_session()
	set_inventory(expensive_before, 0, most_expensive_token_type, 4, 4)
	set_inventory(expensive_after, 0, most_expensive_token_type, 4, 3)
	
	var cheap_evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(cheap_before, cheap_after, create_action(cheapest_token_type))
	var expensive_evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(expensive_before, expensive_after, create_action(most_expensive_token_type))
	
	assert(cheap_evaluation.valid, cheap_evaluation.error_message)
	assert(expensive_evaluation.valid, expensive_evaluation.error_message)
	assert(expensive_evaluation.preservation_penalty > cheap_evaluation.preservation_penalty, "More expensive token should carry more generic resource value when scarcity is equal.")
	
	print("PASS: Higher shop cost increases token preservation value without token-specific strategy.")


func test_zero_resource_change_has_zero_penalty() -> void:
	var token_type:int = get_any_purchasable_token_type()
	assert(token_type != -1, "Could not find a purchasable token.")
	
	var evaluator:BotResourceEvaluator = BotResourceEvaluator.new()
	var before_session:MatchSession = create_test_session()
	var after_session:MatchSession = create_test_session()
	
	set_inventory(before_session, 0, token_type, 3, 2)
	set_inventory(after_session, 0, token_type, 3, 2)
	
	var evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(before_session, after_session, create_action(token_type))
	
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.spent_count == 0, "Unchanged inventory should report zero spent tokens.")
	assert(abs(evaluation.preservation_penalty) < 0.0001, "Unchanged inventory should have zero resource penalty.")
	
	print("PASS: Resource evaluation charges only for inventory that was actually consumed.")


func test_simulated_action_uses_real_before_and_after_inventory() -> void:
	var settings:BoardSetting = create_test_settings()
	var session:MatchSession = create_test_session()
	var board_state:BoardState = BoardState.new(settings)
	board_state.setup_empty_board()
	
	var player:MatchSessionPlayerData = session.get_player(0)
	assert(player != null, "Could not retrieve Player 0.")
	
	player.set_starting_token_count(TokenLibrary.TokenType.ANVIL, 3)
	player.set_token_count(TokenLibrary.TokenType.ANVIL, 2)
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	assert(session.set_current_player(0), "Could not set Player 0 as current player.")
	
	var action:BotAction = BotAction.new()
	action.setup(0, TokenLibrary.TokenType.ANVIL, Vector2i(3, 0), false)
	
	var simulation_result:BotSimulationResult = BotSimulator.simulate_action(session, board_state, settings, action)
	
	assert(simulation_result != null, "Resource integration simulation returned null.")
	assert(simulation_result.success, simulation_result.error_message)
	assert(session.get_token_count(0, TokenLibrary.TokenType.ANVIL) == 2, "Simulation changed source Anvil inventory.")
	assert(simulation_result.state.session.get_token_count(0, TokenLibrary.TokenType.ANVIL) == 1, "Simulation did not consume exactly one Anvil.")
	
	var evaluator:BotResourceEvaluator = BotResourceEvaluator.new()
	var evaluation:BotResourceEvaluationResult = evaluator.evaluate_simulation_result(session, simulation_result)
	
	assert(evaluation != null, "Simulation resource evaluation returned null.")
	assert(evaluation.valid, evaluation.error_message)
	assert(evaluation.token_type == TokenLibrary.TokenType.ANVIL, "Resource evaluator inspected the wrong action token.")
	assert(evaluation.starting_count == 3, "Resource evaluator lost original round inventory.")
	assert(evaluation.before_count == 2, "Resource evaluator read the wrong pre-action inventory.")
	assert(evaluation.after_count == 1, "Resource evaluator read the wrong simulated inventory.")
	assert(evaluation.spent_count == 1, "Resource evaluator did not detect the simulated token expenditure.")
	assert(evaluation.preservation_penalty > 0.0, "Simulated Anvil expenditure should have a preservation penalty.")
	
	simulation_result.dispose()
	
	print("PASS: Resource evaluator reads actual inventory expenditure from BotSimulator branches.")


func test_resource_evaluation_does_not_mutate_sessions() -> void:
	var token_type:int = get_any_purchasable_token_type()
	assert(token_type != -1, "Could not find a purchasable token.")
	
	var evaluator:BotResourceEvaluator = BotResourceEvaluator.new()
	var before_session:MatchSession = create_test_session()
	var after_session:MatchSession = create_test_session()
	
	set_inventory(before_session, 0, token_type, 4, 3)
	set_inventory(after_session, 0, token_type, 4, 2)
	
	var before_counts:Dictionary = before_session.get_player(0).get_token_counts()
	var after_counts:Dictionary = after_session.get_player(0).get_token_counts()
	
	var evaluation:BotResourceEvaluationResult = evaluator.evaluate_inventory_change(before_session, after_session, create_action(token_type))
	
	assert(evaluation.valid, evaluation.error_message)
	assert(before_session.get_player(0).get_token_counts() == before_counts, "Resource evaluation mutated the before session.")
	assert(after_session.get_player(0).get_token_counts() == after_counts, "Resource evaluation mutated the after session.")
	
	print("PASS: Resource evaluation is read-only and does not mutate either inventory.")


func create_test_settings() -> BoardSetting:
	var settings:BoardSetting = BoardSetting.new()
	settings.columns = 7
	settings.rows = 6
	settings.tokens_to_win = 4
	settings.gravity_direction = BoardSetting.GRID_DIRECTION.DOWN
	return settings


func create_test_session() -> MatchSession:
	var config:MatchConfig = MatchConfig.new()
	config.starting_token_points = 10
	config.board_columns = 7
	config.board_rows = 6
	config.tokens_to_win = 4
	config.turn_timer_seconds = 30
	config.starting_player_id = 0
	
	assert(config.add_player("Test Player 1", MatchData.YELLOW_PALETTE), "Could not add test Player 1.")
	assert(config.add_player("Test Player 2", MatchData.RED_PALETTE), "Could not add test Player 2.")
	
	var session:MatchSession = MatchSession.new()
	assert(session.setup(config), "Could not setup resource test MatchSession.")
	
	for player_id in range(session.get_player_count()):
		var player:MatchSessionPlayerData = session.get_player(player_id)
		
		assert(player != null, "Could not retrieve resource test Player %d." % player_id)
		
		for token_type in TokenLibrary.get_all_token_types():
			player.set_starting_token_count(token_type, 0)
			player.set_token_count(token_type, 0)
	
	session.set_turn_phase(Global.TURN_PHASE.PLACEMENT)
	assert(session.set_current_player(0), "Could not set resource test current player.")
	
	return session


func set_inventory(session:MatchSession, player_id:int, token_type:int, starting_count:int, current_count:int) -> void:
	var player:MatchSessionPlayerData = session.get_player(player_id)
	
	assert(player != null, "Could not retrieve Player %d for inventory setup." % player_id)
	
	player.set_starting_token_count(token_type, starting_count)
	player.set_token_count(token_type, current_count)


func create_action(token_type:int) -> BotAction:
	var action:BotAction = BotAction.new()
	action.setup(0, token_type, Vector2i(0, 0), false)
	return action


func get_any_purchasable_token_type() -> int:
	var lobby_token_types:Array[int] = TokenLibrary.get_lobby_token_types()
	
	if lobby_token_types.is_empty():
		return -1
	
	return lobby_token_types[0]


func get_cheapest_purchasable_token_type() -> int:
	var result:int = -1
	var cheapest_cost:int = 999999
	
	for token_type in TokenLibrary.get_lobby_token_types():
		var cost:int = TokenLibrary.get_cost(token_type)
		
		if cost < cheapest_cost:
			cheapest_cost = cost
			result = token_type
	
	return result


func get_most_expensive_purchasable_token_type() -> int:
	var result:int = -1
	var highest_cost:int = -1
	
	for token_type in TokenLibrary.get_lobby_token_types():
		var cost:int = TokenLibrary.get_cost(token_type)
		
		if cost > highest_cost:
			highest_cost = cost
			result = token_type
	
	return result
