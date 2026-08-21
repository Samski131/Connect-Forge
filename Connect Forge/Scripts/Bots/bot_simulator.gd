class_name BotSimulator
extends RefCounted

const MAX_RESOLUTION_STEPS:int = 4096
const DEFAULT_SIMULATION_SEED:int = 1

const PLACEMENT_RESULT_VALID:String = "valid"
const PLACEMENT_RESULT_DATA:String = "data"
const PLACEMENT_RESULT_ERROR:String = "error"

const CHANCE_PROBABILITY:String = "probability"
const CHANCE_PLACEMENT_DATA:String = "placement_data"
const CHANCE_DESCRIPTION:String = "description"

const PROBABILITY_TOLERANCE:float = 0.0001


static func simulate_action(source_session:MatchSession, source_board_state:BoardState, source_settings:BoardSetting, source_action:BotAction, simulation_seed:int = DEFAULT_SIMULATION_SEED) -> BotSimulationResult:
	var result:BotSimulationResult = BotSimulationResult.new()
	result.set_action(source_action)
	
	if source_action == null:
		result.mark_failure("BotSimulator: Cannot simulate a null BotAction.")
		return result
	
	if source_session == null:
		result.mark_failure("BotSimulator: Cannot simulate without a MatchSession.")
		return result
	
	if source_board_state == null:
		result.mark_failure("BotSimulator: Cannot simulate without a BoardState.")
		return result
	
	if source_settings == null:
		result.mark_failure("BotSimulator: Cannot simulate without BoardSetting.")
		return result
	
	var simulation_state:BotSimulationState = BotSimulationStateCloner.clone_state(source_session, source_board_state, source_settings, simulation_seed)
	
	if simulation_state == null:
		result.mark_failure("BotSimulator: Could not clone the source game state.")
		return result
	
	var simulation_board:BotSimulationBoard = BotSimulationBoard.new()
	
	if simulation_board.setup_from_state(simulation_state) == false:
		simulation_board.free()
		simulation_state.dispose()
		result.mark_failure("BotSimulator: Could not create the headless simulation board.")
		return result
	
	result.set_simulation_resources(simulation_state, simulation_board)
	
	var action:BotAction = result.action
	var validation_error:String = _validate_action_against_state(action, simulation_state)
	
	if validation_error != "":
		result.mark_failure(validation_error)
		return result
	
	var application_error:String = _apply_action(action, simulation_state, simulation_board)
	
	if application_error != "":
		result.mark_failure(application_error)
		return result
	
	var resolution_error:String = _resolve_until_stable(result)
	
	if resolution_error != "":
		result.mark_failure(resolution_error)
		return result
	
	_check_for_winner(result)
	result.mark_success()
	
	return result


static func get_chance_outcomes(source_session:MatchSession, source_board_state:BoardState, source_settings:BoardSetting, source_action:BotAction) -> Array[BotChanceOutcome]:
	var result:Array[BotChanceOutcome] = []
	
	if source_session == null:
		return result
	
	if source_board_state == null:
		return result
	
	if source_settings == null:
		return result
	
	if source_action == null:
		return result
	
	if source_action.is_well_formed() == false:
		return result
	
	if source_session.is_valid_player_id(source_action.player_id) == false:
		return result
	
	if source_session.is_player_active(source_action.player_id) == false:
		return result
	
	if source_session.current_player_id != source_action.player_id:
		return result
	
	if source_session.get_token_count(source_action.player_id, source_action.token_type) <= 0:
		return result
	
	if PlacementRules.is_valid_starting_slot(source_board_state, source_settings, source_action.starting_slot) == false:
		return result
	
	if _is_action_choice_legal_for_sources(source_action, source_session, source_board_state, source_settings) == false:
		return result
	
	# Placement data already present means this action already represents
	# one resolved random outcome. It must not be rolled again.
	if source_action.get_placement_data().is_empty() == false:
		var forced_outcome:BotChanceOutcome = _create_certain_outcome(source_action, "Forced placement outcome")
		
		if forced_outcome != null:
			result.append(forced_outcome)
		
		return result
	
	var token_provider:Token = BotActionGenerator.create_token_provider(source_action.token_type)
	
	if token_provider == null:
		return result
	
	var context:Dictionary = BotActionGenerator.create_placement_choice_context(
		source_session,
		source_board_state,
		source_settings,
		source_action.player_id,
		source_action.token_type,
		source_action.starting_slot,
		source_action.start_flipped
	)
	
	var choice_data:Dictionary = source_action.get_choice_data()
	context["choice_data"] = choice_data.duplicate(true)
	
	for choice_key in choice_data.keys():
		if context.has(choice_key):
			continue
		
		context[choice_key] = choice_data[choice_key]
	
	var variants:Array[Dictionary] = token_provider.get_random_placement_outcome_variants(context)
	token_provider.free()
	
	# Most tokens are deterministic. They simply have one outcome with
	# probability 1.0.
	if variants.is_empty():
		var certain_outcome:BotChanceOutcome = _create_certain_outcome(source_action, "Certain outcome")
		
		if certain_outcome != null:
			result.append(certain_outcome)
		
		return result
	
	var total_probability:float = 0.0
	
	for variant in variants:
		var probability:float = float(variant.get(CHANCE_PROBABILITY, 0.0))
		var placement_data:Dictionary = variant.get(CHANCE_PLACEMENT_DATA, {}) as Dictionary
		var description:String = str(variant.get(CHANCE_DESCRIPTION, ""))
		
		if probability <= 0.0:
			push_error("BotSimulator: Token supplied a random outcome with a non-positive probability.")
			result.clear()
			return result
		
		if placement_data.is_empty():
			push_error("BotSimulator: Token supplied a random placement outcome without placement data.")
			result.clear()
			return result
		
		var outcome_action:BotAction = source_action.duplicate_action()
		outcome_action.set_placement_data(placement_data)
		
		var outcome:BotChanceOutcome = BotChanceOutcome.new()
		
		if outcome.setup(probability, outcome_action, description) == false:
			result.clear()
			return result
		
		result.append(outcome)
		total_probability += probability
	
	if abs(total_probability - 1.0) > PROBABILITY_TOLERANCE:
		push_error("BotSimulator: Random outcome probabilities total %.6f instead of 1.0." % total_probability)
		result.clear()
		return result
	
	return result


static func _create_certain_outcome(action:BotAction, description:String) -> BotChanceOutcome:
	if action == null:
		return null
	
	var outcome:BotChanceOutcome = BotChanceOutcome.new()
	
	if outcome.setup(1.0, action, description) == false:
		return null
	
	return outcome


static func _validate_action_against_state(action:BotAction, simulation_state:BotSimulationState) -> String:
	if action == null:
		return "BotSimulator: Action is null."
	
	if simulation_state == null:
		return "BotSimulator: Simulation state is null."
	
	if simulation_state.is_valid_state() == false:
		return "BotSimulator: Simulation state is invalid."
	
	if action.is_well_formed() == false:
		return "BotSimulator: BotAction is not well formed."
	
	var session:MatchSession = simulation_state.session
	
	if session == null:
		return "BotSimulator: Simulation has no MatchSession."
	
	if session.winner_id != -1:
		return "BotSimulator: Cannot apply an action after the match already has a winner."
	
	if session.current_turn_phase != Global.TURN_PHASE.PLACEMENT:
		return "BotSimulator: Actions may only be simulated from the placement phase."
	
	if session.is_valid_player_id(action.player_id) == false:
		return "BotSimulator: Action contains an invalid player ID."
	
	if session.is_player_active(action.player_id) == false:
		return "BotSimulator: Action player is not active."
	
	if session.current_player_id != action.player_id:
		return "BotSimulator: Action player is not the current player."
	
	if session.get_token_count(action.player_id, action.token_type) <= 0:
		return "BotSimulator: Action player has no remaining copies of this token."
	
	if TokenLibrary.get_token_scene(action.token_type) == null:
		return "BotSimulator: Action token has no token scene."
	
	if PlacementRules.is_valid_starting_slot(simulation_state.board_state, simulation_state.settings, action.starting_slot) == false:
		return "BotSimulator: Action starting slot is not currently legal."
	
	if _is_action_choice_legal(action, simulation_state) == false:
		return "BotSimulator: Action contains an illegal token-specific choice."
	
	return ""


static func _is_action_choice_legal(action:BotAction, simulation_state:BotSimulationState) -> bool:
	if simulation_state == null:
		return false
	
	return _is_action_choice_legal_for_sources(
		action,
		simulation_state.session,
		simulation_state.board_state,
		simulation_state.settings
	)


static func _is_action_choice_legal_for_sources(action:BotAction, session:MatchSession, board_state:BoardState, settings:BoardSetting) -> bool:
	if action == null:
		return false
	
	var token_provider:Token = BotActionGenerator.create_token_provider(action.token_type)
	
	if token_provider == null:
		return false
	
	var legal_actions:Array[BotAction] = BotActionGenerator.generate_actions_for_token_placement(
		token_provider,
		session,
		board_state,
		settings,
		action.player_id,
		action.token_type,
		action.starting_slot,
		action.start_flipped
	)
	
	token_provider.free()
	
	var requested_choice_data:Dictionary = action.get_choice_data()
	
	for legal_action in legal_actions:
		if legal_action == null:
			continue
		
		if legal_action.get_choice_data() == requested_choice_data:
			return true
	
	return false


static func _apply_action(action:BotAction, simulation_state:BotSimulationState, simulation_board:BotSimulationBoard) -> String:
	if action == null:
		return "BotSimulator: Cannot apply a null action."
	
	if simulation_state == null:
		return "BotSimulator: Cannot apply an action without simulation state."
	
	if simulation_board == null:
		return "BotSimulator: Cannot apply an action without simulation board."
	
	var token_scene:PackedScene = TokenLibrary.get_token_scene(action.token_type)
	
	if token_scene == null:
		return "BotSimulator: Could not find the action token scene."
	
	if simulation_state.session.spend_token(action.player_id, action.token_type) == false:
		return "BotSimulator: Could not spend the simulated token."
	
	var new_token:Token = simulation_board.create_new_token(token_scene, action.starting_slot, action.player_id, action.start_flipped)
	
	if new_token == null:
		simulation_state.session.refund_token(action.player_id, action.token_type)
		return "BotSimulator: Could not create the simulated token."
	
	var placement_result:Dictionary = _resolve_placement_data(action, new_token, simulation_state, simulation_board)
	var placement_is_valid:bool = bool(placement_result.get(PLACEMENT_RESULT_VALID, false))
	
	if placement_is_valid == false:
		simulation_board.destroy_token(new_token)
		
		var simulation_mover:BotSimulationTokenMover = simulation_board.token_mover as BotSimulationTokenMover
		
		if simulation_mover != null:
			simulation_mover.flush_destroyed_tokens()
		
		simulation_state.session.refund_token(action.player_id, action.token_type)
		
		return str(placement_result.get(PLACEMENT_RESULT_ERROR, "BotSimulator: Could not resolve placement data."))
	
	var placement_data:Dictionary = placement_result.get(PLACEMENT_RESULT_DATA, {}) as Dictionary
	
	new_token.apply_network_placement_data(placement_data)
	action.set_placement_data(placement_data)
	
	return ""


static func _resolve_placement_data(action:BotAction, new_token:Token, simulation_state:BotSimulationState, simulation_board:BotSimulationBoard) -> Dictionary:
	var explicit_placement_data:Dictionary = action.get_placement_data()
	
	if explicit_placement_data.is_empty() == false:
		return {
			PLACEMENT_RESULT_VALID: true,
			PLACEMENT_RESULT_DATA: explicit_placement_data.duplicate(true),
			PLACEMENT_RESULT_ERROR: ""
		}
	
	var choice_data:Dictionary = action.get_choice_data()
	
	var context:Dictionary = {
		"game_manager": null,
		"session": simulation_state.session,
		"board": simulation_board,
		"board_state": simulation_state.board_state,
		"settings": simulation_state.settings,
		"player_id": action.player_id,
		"player_count": simulation_state.session.get_player_count(),
		"token_type": action.token_type,
		"slot_pos": action.starting_slot,
		"start_flipped": action.start_flipped,
		"choice_data": choice_data.duplicate(true),
		"random_number_generator": simulation_state.get_random_number_generator(),
		"random_seed": simulation_state.get_random_seed()
	}
	
	for choice_key in choice_data.keys():
		if context.has(choice_key):
			continue
		
		context[choice_key] = choice_data[choice_key]
	
	var generated_placement_data:Dictionary = new_token.create_network_placement_data(context)
	
	if new_token.requires_network_placement_data() and generated_placement_data.is_empty():
		return {
			PLACEMENT_RESULT_VALID: false,
			PLACEMENT_RESULT_DATA: {},
			PLACEMENT_RESULT_ERROR: "BotSimulator: Token requires placement data but none could be generated."
		}
	
	return {
		PLACEMENT_RESULT_VALID: true,
		PLACEMENT_RESULT_DATA: generated_placement_data.duplicate(true),
		PLACEMENT_RESULT_ERROR: ""
	}


static func _resolve_until_stable(result:BotSimulationResult) -> String:
	if result == null:
		return "BotSimulator: Simulation result is null."
	
	if result.board == null:
		return "BotSimulator: Simulation result has no board."
	
	var action_logic:BotSimulationActionLogic = BotSimulationActionLogic.new()
	
	if action_logic.setup_simulation(result.board) == false:
		action_logic.free()
		return "BotSimulator: Could not create simulation ActionLogic."
	
	action_logic.enter_state()
	
	var resolution_steps:int = 0
	
	while action_logic.is_resolution_finished() == false:
		if resolution_steps >= MAX_RESOLUTION_STEPS:
			action_logic.free()
			return "BotSimulator: Resolution exceeded the maximum number of simulation steps."
		
		action_logic.process_simulation_step()
		resolution_steps += 1
	
	result.resolution_steps = resolution_steps
	action_logic.free()
	
	return ""


static func _check_for_winner(result:BotSimulationResult) -> void:
	if result == null:
		return
	
	if result.board == null:
		return
	
	if result.state == null:
		return
	
	var resolution_logic:BotSimulationResolutionLogic = BotSimulationResolutionLogic.new()
	
	if resolution_logic.setup_simulation(result.board, result.state.session) == false:
		resolution_logic.free()
		return
	
	var winning_result:Dictionary = resolution_logic.find_winning_result()
	resolution_logic.free()
	
	if winning_result.is_empty():
		result.state.session.set_winner_id(-1)
		result.set_winning_result(-1, [])
		return
	
	var winner_id:int = int(winning_result.get("player_id", -1))
	var winning_slots:Array[Vector2i] = []
	var found_slots:Array = winning_result.get("slots", [])
	
	for slot_value in found_slots:
		var slot:Vector2i = slot_value
		winning_slots.append(slot)
	
	result.state.session.set_winner_id(winner_id)
	result.set_winning_result(winner_id, winning_slots)
