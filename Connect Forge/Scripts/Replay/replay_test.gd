extends Node

const BASIC_TOKEN_SCENE:PackedScene = preload("res://Scenes/Tokens/base token.tscn")


func _ready() -> void:
	print("")
	print("========================================")
	print("REPLAY SYSTEM TESTS")
	print("========================================")
	
	if run_visual_encoder_test() == false:
		return
	
	if run_state_reconstruction_test() == false:
		return
	
	print("")
	print("========================================")
	print("=== ALL REPLAY TESTS PASSED ===")
	print("========================================")


func run_visual_encoder_test() -> bool:
	print("")
	print("=== GENERIC VISUAL REPLAY ENCODER TEST ===")
	
	var token:Token = BASIC_TOKEN_SCENE.instantiate() as Token
	
	if token == null:
		return fail("Could not create test token.")
	
	add_child(token)
	token.global_position = Vector2.ZERO
	
	if token.set_replay_token_id(12) == false:
		return fail("Could not assign replay token ID.")
	
	var movement_path:Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(3, 2),
		Vector2i(3, 3),
		Vector2i(3, 4),
		Vector2i(3, 5)
	]
	
	var move_effect:TokenMoveVisualEffect = TokenMoveVisualEffect.new(token, Vector2(0.0, 1000.0), BoardVisualManager.MOVE_VISUAL.FALL)
	move_effect.set_replay_movement_context(Vector2i(3, 0), Vector2i(3, 5), movement_path)
	
	var shimmer_effect:TokenShimmerVisualEffect = TokenShimmerVisualEffect.new(token, 0.45, Vector2(1.0, -1.0), 0.75)
	var wiggle_effect:WiggleVisualEffect = WiggleVisualEffect.new(token, 8.0, 3, 0.25)
	
	var parallel_effects:Array[BoardVisualEffect] = [
		move_effect,
		shimmer_effect
	]
	
	var parallel_effect:ParallelVisualEffect = ParallelVisualEffect.new(parallel_effects)
	
	var sequence_effects:Array[BoardVisualEffect] = [
		parallel_effect,
		wiggle_effect
	]
	
	var sequence_effect:SequenceVisualEffect = SequenceVisualEffect.new(sequence_effects)
	var replay_action:ReplayAction = sequence_effect.to_replay_action()
	
	if replay_action == null:
		return fail("Visual tree returned no replay action.")
	
	if replay_action.action_type != ReplayFormat.GROUP_SEQUENCE:
		return fail("Visual root should be sequence.")
	
	if replay_action.children.size() != 2:
		return fail("Visual sequence should contain two children.")
	
	var parallel_action:ReplayAction = replay_action.children[0]
	var wiggle_action:ReplayAction = replay_action.children[1]
	
	if parallel_action.action_type != ReplayFormat.GROUP_PARALLEL:
		return fail("First visual child should be parallel.")
	
	if parallel_action.children.size() != 2:
		return fail("Visual parallel group should contain two children.")
	
	if parallel_action.children[0].action_type != ReplayFormat.PRESENTATION_TOKEN_MOVE:
		return fail("First parallel child should be token_move.")
	
	if parallel_action.children[1].action_type != ReplayFormat.PRESENTATION_TOKEN_SHIMMER:
		return fail("Second parallel child should be token_shimmer.")
	
	if wiggle_action.action_type != ReplayFormat.PRESENTATION_WIGGLE:
		return fail("Second sequence child should be wiggle.")
	
	if replay_action.is_valid() == false:
		return fail("Generated visual replay tree is invalid.")
	
	print("Visual encoder: PASSED")
	
	token.queue_free()
	return true


func run_state_reconstruction_test() -> bool:
	print("")
	print("=== REPLAY STATE / CHECKPOINT / FILE TEST ===")
	
	var replay:ReplayData = create_state_test_replay()
	
	if replay == null:
		return fail("Could not create state test replay.")
	
	print("Created test replay with ", replay.get_step_count(), " steps.")
	
	if ReplayCheckpointBuilder.rebuild_checkpoints(replay) == false:
		return fail("Checkpoint builder rejected the replay.")
	
	print("Checkpoint count: ", replay.get_checkpoint_count())
	
	if replay.get_checkpoint_count() < 2:
		return fail("Expected multiple checkpoints.")
	
	# ---------------------------------------------------------
	# REAL DISK SAVE TEST
	# ---------------------------------------------------------
	
	var file_path:String = ReplayStorage.save_replay(replay)
	
	if file_path == "":
		return fail("Replay file could not be saved.")
	
	print("")
	print("Replay saved successfully.")
	print("Godot path: ", file_path)
	
	var absolute_file_path:String = ProjectSettings.globalize_path(file_path)
	print("Windows path: ", absolute_file_path)
	
	if FileAccess.file_exists(file_path) == false:
		return fail("ReplayStorage returned a path but the replay file does not exist.")
	
	var file:FileAccess = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		return fail("Saved replay exists but could not be opened.")
	
	var file_size:int = file.get_length()
	file.close()
	
	if file_size <= 0:
		return fail("Saved replay file is empty.")
	
	print("Replay file size: ", file_size, " bytes")
	print("Replay file exists: PASSED")
	
	# ---------------------------------------------------------
	# REAL DISK LOAD TEST
	# ---------------------------------------------------------
	
	var loaded:ReplayData = ReplayStorage.load_replay(file_path)
	
	if loaded == null:
		return fail("Replay file could not be loaded from disk.")
	
	print("Replay file load: PASSED")
	
	if loaded.match_id != replay.match_id:
		return fail("Loaded replay has the wrong match ID.")
	
	if loaded.get_step_count() != replay.get_step_count():
		return fail("Replay step count changed after disk save/load.")
	
	if loaded.get_checkpoint_count() != replay.get_checkpoint_count():
		return fail("Checkpoint count changed after disk save/load.")
	
	print("Replay disk round-trip: PASSED")
	
	# ---------------------------------------------------------
	# ATOMIC MULTI-TOKEN MOVEMENT TEST
	# ---------------------------------------------------------
	
	var swap_state:ReplayState = ReplayStateReconstructor.reconstruct_to_step(loaded, 6)
	
	if swap_state == null:
		return fail("Could not reconstruct swap state.")
	
	var token_one:Dictionary = swap_state.get_token_data(1)
	var token_two:Dictionary = swap_state.get_token_data(2)
	
	if token_one.is_empty():
		return fail("Token 1 is missing after atomic movement.")
	
	if token_two.is_empty():
		return fail("Token 2 is missing after atomic movement.")
	
	if ReplayState.position_from_data(token_one.get("position", [])) != Vector2i(4, 5):
		return fail("Atomic movement did not move token 1 correctly.")
	
	if ReplayState.position_from_data(token_two.get("position", [])) != Vector2i(3, 5):
		return fail("Atomic movement did not move token 2 correctly.")
	
	print("Atomic two-token movement: PASSED")
	
	# ---------------------------------------------------------
	# UPDATE / FLIP / GRAVITY / DESTRUCTION TEST
	# ---------------------------------------------------------
	
	var destruction_state:ReplayState = ReplayStateReconstructor.reconstruct_to_step(loaded, 10)
	
	if destruction_state == null:
		return fail("Could not reconstruct destruction state.")
	
	if destruction_state.get_token_count() != 1:
		return fail("Expected one surviving token after destruction.")
	
	if destruction_state.get_token_data(1).is_empty() == false:
		return fail("Destroyed token 1 still exists.")
	
	var surviving_token:Dictionary = destruction_state.get_token_data(2)
	
	if surviving_token.is_empty():
		return fail("Surviving token 2 is missing.")
	
	if bool(surviving_token.get("flipped", false)) == false:
		return fail("Token flip state was not reconstructed.")
	
	if int(surviving_token.get("charges", -1)) != 0:
		return fail("Token charge update was not reconstructed.")
	
	if surviving_token.has("state_data") == false:
		return fail("Custom token state_data was not reconstructed.")
	
	var state_data_value = surviving_token["state_data"]
	
	if typeof(state_data_value) != TYPE_DICTIONARY:
		return fail("Custom token state_data is not a dictionary.")
	
	var surviving_state_data:Dictionary = state_data_value
	
	if bool(surviving_state_data.get("activated", false)) == false:
		return fail("Custom token activated state was not reconstructed.")
	
	if destruction_state.gravity != ReplayFormat.GRAVITY_RIGHT:
		return fail("Gravity state was not reconstructed.")
	
	print("Token update: PASSED")
	print("Token flip: PASSED")
	print("Gravity change: PASSED")
	print("Token destruction: PASSED")
	
	# ---------------------------------------------------------
	# ROUND RESET TEST
	# ---------------------------------------------------------
	
	var round_two_state:ReplayState = ReplayStateReconstructor.reconstruct_to_step(loaded, 13)
	
	if round_two_state == null:
		return fail("Could not reconstruct round-two state.")
	
	if round_two_state.round_number != 2:
		return fail("Round number did not advance.")
	
	if round_two_state.get_token_count() != 0:
		return fail("Round start did not clear the previous board.")
	
	if round_two_state.gravity != ReplayFormat.GRAVITY_RIGHT:
		return fail("Round-start gravity was not restored.")
	
	print("Round reset reconstruction: PASSED")
	
	# ---------------------------------------------------------
	# FINAL STATE TEST
	# ---------------------------------------------------------
	
	var final_state:ReplayState = ReplayStateReconstructor.reconstruct_final_state(loaded)
	
	if final_state == null:
		return fail("Could not reconstruct final replay state.")
	
	if final_state.scores.size() != 2:
		return fail("Final score snapshot is missing.")
	
	var player_zero_score:Dictionary = final_state.scores[0]
	var player_one_score:Dictionary = final_state.scores[1]
	
	if int(player_zero_score.get("player_id", -1)) != 0:
		return fail("First score entry has the wrong player ID.")
	
	if int(player_zero_score.get("wins", 0)) != 1:
		return fail("Player 1 final wins are incorrect.")
	
	if int(player_zero_score.get("losses", 0)) != 0:
		return fail("Player 1 final losses are incorrect.")
	
	if int(player_one_score.get("player_id", -1)) != 1:
		return fail("Second score entry has the wrong player ID.")
	
	if int(player_one_score.get("wins", 0)) != 0:
		return fail("Player 2 final wins are incorrect.")
	
	if int(player_one_score.get("losses", 0)) != 1:
		return fail("Player 2 final losses are incorrect.")
	
	print("Final score reconstruction: PASSED")
	
	# ---------------------------------------------------------
	# CHECKPOINT VS FULL RECONSTRUCTION TEST
	# ---------------------------------------------------------
	
	var final_dictionary:Dictionary = final_state.to_dictionary()
	
	var replay_without_checkpoints:ReplayData = ReplaySerializer.deserialize(ReplaySerializer.serialize(loaded))
	
	if replay_without_checkpoints == null:
		return fail("Could not create comparison replay.")
	
	replay_without_checkpoints.clear_checkpoints()
	
	var final_without_checkpoints:ReplayState = ReplayStateReconstructor.reconstruct_final_state(replay_without_checkpoints)
	
	if final_without_checkpoints == null:
		return fail("Could not reconstruct replay without checkpoints.")
	
	var no_checkpoint_dictionary:Dictionary = final_without_checkpoints.to_dictionary()
	
	if final_dictionary != no_checkpoint_dictionary:
		return fail("Checkpoint reconstruction differs from full state reconstruction.")
	
	print("Checkpoint reconstruction matches full reconstruction: PASSED")
	
	print("")
	print("=== REPLAY STATE / CHECKPOINT / FILE TEST PASSED ===")
	print("Test replay remains on disk at:")
	print(absolute_file_path)
	
	return true


func create_state_test_replay() -> ReplayData:
	var replay:ReplayData = ReplayData.new()
	
	if replay.setup_new_replay("replay-state-checkpoint-test") == false:
		return null
	
	var board_metadata:Dictionary = {
		"columns": 7,
		"rows": 6,
		"tokens_to_win": 4,
		"initial_gravity": ReplayFormat.GRAVITY_DOWN
	}
	
	if replay.set_metadata_value("board", board_metadata) == false:
		return null
	
	var rules_metadata:Dictionary = {
		"turn_timer_seconds": 0,
		"starting_token_points": 10,
		"configured_starting_player_id": 0
	}
	
	if replay.set_metadata_value("rules", rules_metadata) == false:
		return null
	
	var player_zero:Dictionary = {
		"player_id": 0,
		"name": "Player 1",
		"palette": [],
		"starting_tokens": []
	}
	
	if replay.add_player(player_zero) == false:
		return null
	
	var player_one:Dictionary = {
		"player_id": 1,
		"name": "Player 2",
		"palette": [],
		"starting_tokens": []
	}
	
	if replay.add_player(player_one) == false:
		return null
	
	# Step 0
	var match_start_metadata:Dictionary = {
		"starting_player_id": 0
	}
	
	if add_boundary(replay, ReplayFormat.STEP_MATCH_START, 1, 1, 0, match_start_metadata) == false:
		return null
	
	# Step 1
	var round_start_metadata:Dictionary = {
		"starting_player_id": 0,
		"gravity": ReplayFormat.GRAVITY_DOWN
	}
	
	if add_boundary(replay, ReplayFormat.STEP_ROUND_START, 1, 1, 0, round_start_metadata) == false:
		return null
	
	# Step 2
	if add_boundary(replay, ReplayFormat.STEP_TURN_START, 1, 1, 0) == false:
		return null
	
	# Step 3
	var spawn_one:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_SPAWN, {
		"token_id": 1,
		"token_type": "basic",
		"player_id": 0,
		"position": [3, 0],
		"flipped": false,
		"charges": 0
	})
	
	if add_single_action_step(replay, 1, 1, 0, spawn_one) == false:
		return null
	
	# Step 4
	var move_one:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_MOVE, {
		"token_id": 1,
		"from": [3, 0],
		"to": [3, 5]
	})
	
	if add_single_action_step(replay, 1, 1, 0, move_one) == false:
		return null
	
	# Step 5
	var spawn_two:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_SPAWN, {
		"token_id": 2,
		"token_type": "basic",
		"player_id": 1,
		"position": [4, 5],
		"flipped": false,
		"charges": 1
	})
	
	if add_single_action_step(replay, 1, 1, 0, spawn_two) == false:
		return null
	
	# Step 6
	# Atomic two-token movement. Each token moves into the other's old square.
	var swap_one:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_MOVE, {
		"token_id": 1,
		"from": [3, 5],
		"to": [4, 5]
	})
	
	var swap_two:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_MOVE, {
		"token_id": 2,
		"from": [4, 5],
		"to": [3, 5]
	})
	
	var swap_actions:Array[ReplayAction] = [
		swap_one,
		swap_two
	]
	
	if add_action_step(replay, 1, 1, 0, swap_actions) == false:
		return null
	
	# Step 7
	var update_two:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_UPDATE, {
		"token_id": 2,
		"charges": 0,
		"flipped": false,
		"state_data": {
			"activated": true
		}
	})
	
	if add_single_action_step(replay, 1, 1, 0, update_two) == false:
		return null
	
	# Step 8
	var gravity_change:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_GRAVITY_CHANGE, {
		"from": ReplayFormat.GRAVITY_DOWN,
		"to": ReplayFormat.GRAVITY_RIGHT
	})
	
	if add_single_action_step(replay, 1, 1, 0, gravity_change) == false:
		return null
	
	# Step 9
	var flip_two:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_FLIP, {
		"token_id": 2,
		"flipped": true
	})
	
	if add_single_action_step(replay, 1, 1, 0, flip_two) == false:
		return null
	
	# Step 10
	var destroy_one:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_DESTROY, {
		"token_id": 1,
		"position": [4, 5]
	})
	
	if add_single_action_step(replay, 1, 1, 0, destroy_one) == false:
		return null
	
	# Step 11
	var turn_end_metadata:Dictionary = {
		"reason": "round_complete"
	}
	
	if add_boundary(replay, ReplayFormat.STEP_TURN_END, 1, 1, 0, turn_end_metadata) == false:
		return null
	
	var scores:Array = [
		{
			"player_id": 0,
			"wins": 1,
			"losses": 0
		},
		{
			"player_id": 1,
			"wins": 0,
			"losses": 1
		}
	]
	
	# Step 12
	var round_end_metadata:Dictionary = {
		"winner_id": 0,
		"scores": scores
	}
	
	if add_boundary(replay, ReplayFormat.STEP_ROUND_END, 1, 1, 0, round_end_metadata) == false:
		return null
	
	# Step 13
	var round_two_metadata:Dictionary = {
		"starting_player_id": 1,
		"gravity": ReplayFormat.GRAVITY_RIGHT
	}
	
	if add_boundary(replay, ReplayFormat.STEP_ROUND_START, 2, 1, 1, round_two_metadata) == false:
		return null
	
	# Step 14
	if add_boundary(replay, ReplayFormat.STEP_TURN_START, 2, 1, 1) == false:
		return null
	
	# Step 15
	var match_end_metadata:Dictionary = {
		"reason": "test",
		"scores": scores
	}
	
	if add_boundary(replay, ReplayFormat.STEP_MATCH_END, 2, 1, 1, match_end_metadata) == false:
		return null
	
	return replay


func add_boundary(replay:ReplayData, step_type:String, round_number:int, turn_number:int, player_id:int, metadata:Dictionary = {}) -> bool:
	if replay == null:
		return false
	
	var step:ReplayStep = replay.create_next_step(step_type)
	step.set_context(round_number, turn_number, player_id)
	
	for key in metadata.keys():
		if step.set_metadata_value(str(key), metadata[key]) == false:
			return false
	
	return replay.add_step(step)


func add_single_action_step(replay:ReplayData, round_number:int, turn_number:int, player_id:int, action:ReplayAction) -> bool:
	if action == null:
		return false
	
	var actions:Array[ReplayAction] = [action]
	return add_action_step(replay, round_number, turn_number, player_id, actions)


func add_action_step(replay:ReplayData, round_number:int, turn_number:int, player_id:int, actions:Array[ReplayAction]) -> bool:
	if replay == null:
		return false
	
	if actions.is_empty():
		return false
	
	var step:ReplayStep = replay.create_next_step(ReplayFormat.STEP_ACTION)
	step.set_context(round_number, turn_number, player_id)
	
	for action in actions:
		if action == null:
			return false
		
		if step.add_state_action(action) == false:
			return false
	
	return replay.add_step(step)


func fail(message:String) -> bool:
	print("")
	print("========================================")
	print("FAILED: ", message)
	print("========================================")
	return false
