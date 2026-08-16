class_name ReplayRecorder
extends RefCounted

const FIRST_TOKEN_ID:int = 1

var replay:ReplayData = null
var recording_enabled:bool = false

var next_token_id:int = FIRST_TOKEN_ID
var registered_token_ids:Dictionary = {}
var spawn_recorded_token_ids:Dictionary = {}
var destroyed_token_ids:Dictionary = {}

var move_batch_depth:int = 0
var batched_move_state_actions:Array[ReplayAction] = []

var batched_move_round_number:int = 1
var batched_move_turn_number:int = 1
var batched_move_player_id:int = -1
var batched_move_has_context:bool = false

var match_configured:bool = false
var match_started:bool = false
var match_ended:bool = false

var recorded_round_starts:Dictionary = {}

var current_turn_is_open:bool = false
var open_turn_round_number:int = 1
var open_turn_number:int = 1
var open_turn_player_id:int = -1

var last_saved_file_path:String = ""


func start_recording(match_id:String) -> bool:
	stop_recording()
	
	var used_match_id:String = match_id.strip_edges()
	
	if used_match_id == "":
		return false
	
	var new_replay:ReplayData = ReplayData.new()
	
	if new_replay.setup_new_replay(used_match_id) == false:
		return false
	
	replay = new_replay
	recording_enabled = true
	next_token_id = FIRST_TOKEN_ID
	
	registered_token_ids.clear()
	spawn_recorded_token_ids.clear()
	destroyed_token_ids.clear()
	clear_move_batch()
	
	match_configured = false
	match_started = false
	match_ended = false
	recorded_round_starts.clear()
	current_turn_is_open = false
	open_turn_round_number = 1
	open_turn_number = 1
	open_turn_player_id = -1
	last_saved_file_path = ""

	return true


func stop_recording() -> void:
	recording_enabled = false
	replay = null
	next_token_id = FIRST_TOKEN_ID
	
	registered_token_ids.clear()
	spawn_recorded_token_ids.clear()
	destroyed_token_ids.clear()
	clear_move_batch()
	
	match_configured = false
	match_started = false
	match_ended = false
	recorded_round_starts.clear()
	current_turn_is_open = false
	open_turn_round_number = 1
	open_turn_number = 1
	open_turn_player_id = -1
	last_saved_file_path = ""
	


func is_recording() -> bool:
	return recording_enabled and replay != null


func get_replay() -> ReplayData:
	return replay


func get_match_id() -> String:
	if replay == null:
		return ""
	
	return replay.match_id


func register_token(token:Token) -> int:
	if is_recording() == false:
		return -1
	
	if token == null:
		return -1
	
	if is_instance_valid(token) == false:
		return -1
	
	if token.has_replay_token_id():
		var existing_id:int = token.get_replay_token_id()
		
		if registered_token_ids.has(existing_id) == false:
			registered_token_ids[existing_id] = token.get_instance_id()
		
		return existing_id
	
	var new_token_id:int = get_next_token_id()
	
	if token.set_replay_token_id(new_token_id) == false:
		return -1
	
	registered_token_ids[new_token_id] = token.get_instance_id()
	return new_token_id


func record_token_spawn(token:Token, round_number:int, turn_number:int) -> bool:
	if is_recording() == false:
		return false
	
	if token == null:
		return false
	
	if is_instance_valid(token) == false:
		return false
	
	var token_id:int = register_token(token)
	
	if token_id < 0:
		return false
	
	if spawn_recorded_token_ids.has(token_id):
		return true
	
	var replay_token_type:String = TokenLibrary.get_replay_id(token.token_type)
	
	if replay_token_type == "":
		push_error("ReplayRecorder: Token %d has no stable replay token type." % token_id)
		return false
	
	var placement_data:Dictionary = token.get_network_placement_data()
	var state_data:Dictionary = token.create_network_state_data()
	
	var payload:Dictionary = {
		"token_id": token_id,
		"token_type": replay_token_type,
		"player_id": token.player_id,
		"position": ReplayAction.grid_position_to_data(token.token_pos),
		"flipped": token.is_flipped,
		"charges": token.charges
	}
	
	if placement_data.is_empty() == false:
		payload["placement_data"] = placement_data.duplicate(true)
	
	if state_data.is_empty() == false:
		payload["state_data"] = state_data.duplicate(true)
	
	if ReplayAction.is_json_safe_dictionary(payload) == false:
		return false
	
	var spawn_action:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_SPAWN, payload)
	var step:ReplayStep = replay.create_next_step(ReplayFormat.STEP_ACTION)
	
	step.set_context(round_number, turn_number, token.player_id)
	
	if step.add_state_action(spawn_action) == false:
		return false
	
	if replay.add_step(step) == false:
		return false
	
	spawn_recorded_token_ids[token_id] = true
	
	DebugOverlay.log_message("ReplayRecorder", "Recorded token_spawn step %d for token %d: %s, player %d, position %s, round %d, turn %d." % [step.step_id, token_id, replay_token_type, token.player_id, str(token.token_pos), step.round_number, step.turn_number])
	return true


func record_token_move(token:Token, from_pos:Vector2i, to_pos:Vector2i, presentation_action:ReplayAction, round_number:int, turn_number:int, acting_player_id:int) -> bool:
	if is_recording() == false:
		return false
	
	if token == null:
		return false
	
	if is_instance_valid(token) == false:
		return false
	
	if token.has_replay_token_id() == false:
		return false
	
	var token_id:int = token.get_replay_token_id()
	
	if spawn_recorded_token_ids.has(token_id) == false:
		return false
	
	if destroyed_token_ids.has(token_id):
		return false
	
	var state_payload:Dictionary = {
		"token_id": token_id,
		"from": ReplayAction.grid_position_to_data(from_pos),
		"to": ReplayAction.grid_position_to_data(to_pos)
	}
	
	var state_action:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_MOVE, state_payload)
	
	if state_action.is_valid() == false:
		return false
	
	if presentation_action != null:
		if presentation_action.is_state_action():
			return false
		
		if presentation_action.is_valid() == false:
			return false
	
	if is_move_batch_active():
		return buffer_token_move(token_id, state_action, from_pos, to_pos, round_number, turn_number, acting_player_id)
	
	return commit_single_token_move(token_id, state_action, presentation_action, from_pos, to_pos, round_number, turn_number, acting_player_id)


func record_token_destruction(tokens:Array[Token], positions:Array[Vector2i], presentation_action:ReplayAction, round_number:int, turn_number:int, acting_player_id:int) -> bool:
	if is_recording() == false:
		return false
	
	if tokens.is_empty():
		return false
	
	if tokens.size() != positions.size():
		return false
	
	if presentation_action != null:
		if presentation_action.is_state_action():
			return false
		
		if presentation_action.is_valid() == false:
			return false
	
	var destroy_actions:Array[ReplayAction] = []
	var token_ids:Array[int] = []
	
	for index in range(tokens.size()):
		var token:Token = tokens[index]
		
		if token == null:
			return false
		
		if is_instance_valid(token) == false:
			return false
		
		if token.has_replay_token_id() == false:
			return false
		
		var token_id:int = token.get_replay_token_id()
		
		if spawn_recorded_token_ids.has(token_id) == false:
			return false
		
		if destroyed_token_ids.has(token_id):
			return false
		
		if token_ids.has(token_id):
			return false
		
		var payload:Dictionary = {
			"token_id": token_id,
			"position": ReplayAction.grid_position_to_data(positions[index])
		}
		
		var destroy_action:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_DESTROY, payload)
		
		if destroy_action.is_valid() == false:
			return false
		
		token_ids.append(token_id)
		destroy_actions.append(destroy_action)
	
	var step:ReplayStep = replay.create_next_step(ReplayFormat.STEP_ACTION)
	step.set_context(round_number, turn_number, acting_player_id)
	
	for destroy_action in destroy_actions:
		if step.add_state_action(destroy_action) == false:
			return false
	
	if presentation_action != null:
		if step.set_presentation(presentation_action) == false:
			return false
	
	if replay.add_step(step) == false:
		return false
	
	for token_id in token_ids:
		destroyed_token_ids[token_id] = true
	
	var presentation_type:String = "none"
	var presentation_child_count:int = 0
	
	if presentation_action != null:
		presentation_type = presentation_action.action_type
		presentation_child_count = presentation_action.children.size()
	
	DebugOverlay.log_message("ReplayRecorder", "Recorded token_destroy step %d with %d token(s), presentation %s with %d child action(s)." % [step.step_id, token_ids.size(), presentation_type, presentation_child_count])
	return true


func record_token_update(token:Token, round_number:int, turn_number:int, acting_player_id:int, presentation_action:ReplayAction = null) -> bool:
	var tokens:Array[Token] = []
	
	if token != null:
		tokens.append(token)
	
	return record_token_updates(tokens, round_number, turn_number, acting_player_id, presentation_action)


func record_token_updates(tokens:Array[Token], round_number:int, turn_number:int, acting_player_id:int, presentation_action:ReplayAction = null) -> bool:
	if is_recording() == false:
		return false
	
	if tokens.is_empty():
		return false
	
	var step:ReplayStep = replay.create_next_step(ReplayFormat.STEP_ACTION)
	step.set_context(round_number, turn_number, acting_player_id)
	
	var recorded_token_ids:Dictionary = {}
	var update_count:int = 0
	
	for token in tokens:
		var update_action:ReplayAction = create_token_update_action(token)
		
		if update_action == null:
			return false
		
		var token_id:int = int(update_action.payload.get("token_id", -1))
		
		if recorded_token_ids.has(token_id):
			continue
		
		recorded_token_ids[token_id] = true
		
		if step.add_state_action(update_action) == false:
			return false
		
		update_count += 1
	
	if update_count <= 0:
		return false
	
	if presentation_action != null:
		if presentation_action.is_state_action():
			return false
		
		if presentation_action.is_valid() == false:
			return false
		
		if step.set_presentation(presentation_action) == false:
			return false
	
	if replay.add_step(step) == false:
		return false
	
	var presentation_type:String = "none"
	
	if presentation_action != null:
		presentation_type = presentation_action.action_type
	
	DebugOverlay.log_message("ReplayRecorder", "Recorded token_update step %d with %d token update(s), presentation %s." % [step.step_id, update_count, presentation_type])
	return true


func create_token_update_action(token:Token) -> ReplayAction:
	if token == null:
		return null
	
	if is_instance_valid(token) == false:
		return null
	
	if token.has_replay_token_id() == false:
		return null
	
	var token_id:int = token.get_replay_token_id()
	
	if spawn_recorded_token_ids.has(token_id) == false:
		return null
	
	if destroyed_token_ids.has(token_id):
		return null
	
	var state_data:Dictionary = token.create_network_state_data()
	var payload:Dictionary = {
		"token_id": token_id,
		"charges": token.charges,
		"flipped": token.is_flipped
	}
	
	if state_data.is_empty() == false:
		payload["state_data"] = state_data.duplicate(true)
	
	if ReplayAction.is_json_safe_dictionary(payload) == false:
		return null
	
	var update_action:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_UPDATE, payload)
	
	if update_action.is_valid() == false:
		return null
	
	return update_action


func record_gravity_change(previous_gravity:String, new_gravity:String, presentation_action:ReplayAction, round_number:int, turn_number:int, acting_player_id:int) -> bool:
	if is_recording() == false:
		return false
	
	if previous_gravity.strip_edges() == "":
		return false
	
	if new_gravity.strip_edges() == "":
		return false
	
	if previous_gravity == new_gravity:
		return false
	
	var payload:Dictionary = {
		"from": previous_gravity,
		"to": new_gravity
	}
	
	var gravity_action:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_GRAVITY_CHANGE, payload)
	
	if gravity_action.is_valid() == false:
		return false
	
	var step:ReplayStep = replay.create_next_step(ReplayFormat.STEP_ACTION)
	step.set_context(round_number, turn_number, acting_player_id)
	
	if step.add_state_action(gravity_action) == false:
		return false
	
	if presentation_action != null:
		if presentation_action.is_state_action():
			return false
		
		if presentation_action.is_valid() == false:
			return false
		
		if step.set_presentation(presentation_action) == false:
			return false
	
	if replay.add_step(step) == false:
		return false
	
	var presentation_type:String = "none"
	var child_count:int = 0
	
	if presentation_action != null:
		presentation_type = presentation_action.action_type
		child_count = presentation_action.children.size()
	
	DebugOverlay.log_message("ReplayRecorder", "Recorded gravity_change step %d: %s -> %s, presentation %s with %d child action(s)." % [step.step_id, previous_gravity, new_gravity, presentation_type, child_count])
	return true


func record_presentation(presentation_action:ReplayAction, round_number:int, turn_number:int, acting_player_id:int) -> bool:
	if is_recording() == false:
		return false
	
	if presentation_action == null:
		return false
	
	if presentation_action.is_state_action():
		return false
	
	if presentation_action.is_valid() == false:
		return false
	
	var step:ReplayStep = replay.create_next_step(ReplayFormat.STEP_ACTION)
	step.set_context(round_number, turn_number, acting_player_id)
	
	if add_implied_state_actions_from_presentation(step, presentation_action) == false:
		return false
	
	if step.set_presentation(presentation_action) == false:
		return false
	
	if replay.add_step(step) == false:
		return false
	
	DebugOverlay.log_message("ReplayRecorder", "Recorded presentation step %d: %s with %d child action(s)." % [step.step_id, presentation_action.action_type, presentation_action.children.size()])
	return true


func add_implied_state_actions_from_presentation(step:ReplayStep, presentation_action:ReplayAction) -> bool:
	if step == null:
		return false
	
	if presentation_action == null:
		return true
	
	if presentation_action.channel == ReplayFormat.ACTION_CHANNEL_PRESENTATION:
		if presentation_action.action_type == ReplayFormat.PRESENTATION_TOKEN_FLIP:
			var token_id:int = int(presentation_action.payload.get("token_id", -1))
			var flipped:bool = bool(presentation_action.payload.get("flipped", false))
			
			if token_id < 0:
				return false
			
			if spawn_recorded_token_ids.has(token_id) == false:
				return false
			
			if destroyed_token_ids.has(token_id):
				return false
			
			var flip_payload:Dictionary = {
				"token_id": token_id,
				"flipped": flipped
			}
			
			var flip_action:ReplayAction = ReplayAction.create_state(ReplayFormat.STATE_TOKEN_FLIP, flip_payload)
			
			if step.add_state_action(flip_action) == false:
				return false
	
	for child in presentation_action.children:
		if add_implied_state_actions_from_presentation(step, child) == false:
			return false
	
	return true


func begin_move_batch() -> void:
	if is_recording() == false:
		return
	
	if move_batch_depth == 0:
		batched_move_state_actions.clear()
		batched_move_round_number = 1
		batched_move_turn_number = 1
		batched_move_player_id = -1
		batched_move_has_context = false
	
	move_batch_depth += 1


func end_move_batch(presentation_action:ReplayAction = null) -> bool:
	if is_recording() == false:
		clear_move_batch()
		return false
	
	if move_batch_depth <= 0:
		return false
	
	move_batch_depth -= 1
	
	if move_batch_depth > 0:
		return true
	
	if batched_move_state_actions.is_empty():
		clear_move_batch()
		return true
	
	if batched_move_has_context == false:
		clear_move_batch()
		return false
	
	var step:ReplayStep = replay.create_next_step(ReplayFormat.STEP_ACTION)
	step.set_context(batched_move_round_number, batched_move_turn_number, batched_move_player_id)
	
	for state_action in batched_move_state_actions:
		if step.add_state_action(state_action) == false:
			clear_move_batch()
			return false
	
	if presentation_action != null:
		if presentation_action.is_state_action():
			clear_move_batch()
			return false
		
		if presentation_action.is_valid() == false:
			clear_move_batch()
			return false
		
		if add_implied_state_actions_from_presentation(step, presentation_action) == false:
			clear_move_batch()
			return false
		
		if step.set_presentation(presentation_action) == false:
			clear_move_batch()
			return false
	
	var movement_count:int = batched_move_state_actions.size()
	
	if replay.add_step(step) == false:
		clear_move_batch()
		return false
	
	var presentation_type:String = "none"
	var presentation_child_count:int = 0
	
	if presentation_action != null:
		presentation_type = presentation_action.action_type
		presentation_child_count = presentation_action.children.size()
	
	DebugOverlay.log_message("ReplayRecorder", "Recorded movement batch step %d with %d state movement(s), presentation %s with %d child action(s)." % [step.step_id, movement_count, presentation_type, presentation_child_count])
	
	clear_move_batch()
	return true


func buffer_token_move(token_id:int, state_action:ReplayAction, from_pos:Vector2i, to_pos:Vector2i, round_number:int, turn_number:int, acting_player_id:int) -> bool:
	if batched_move_has_context == false:
		batched_move_round_number = max(round_number, 1)
		batched_move_turn_number = max(turn_number, 1)
		batched_move_player_id = acting_player_id
		batched_move_has_context = true
	else:
		if batched_move_round_number != max(round_number, 1):
			return false
		
		if batched_move_turn_number != max(turn_number, 1):
			return false
		
		if batched_move_player_id != acting_player_id:
			return false
	
	batched_move_state_actions.append(state_action)
	
	DebugOverlay.log_message("ReplayRecorder", "Buffered token_move state for token %d: %s -> %s." % [token_id, str(from_pos), str(to_pos)])
	return true


func commit_single_token_move(token_id:int, state_action:ReplayAction, presentation_action:ReplayAction, from_pos:Vector2i, to_pos:Vector2i, round_number:int, turn_number:int, acting_player_id:int) -> bool:
	var step:ReplayStep = replay.create_next_step(ReplayFormat.STEP_ACTION)
	step.set_context(round_number, turn_number, acting_player_id)
	
	if step.add_state_action(state_action) == false:
		return false
	
	if presentation_action != null:
		if add_implied_state_actions_from_presentation(step, presentation_action) == false:
			return false
		
		if step.set_presentation(presentation_action) == false:
			return false
	
	if replay.add_step(step) == false:
		return false
	
	var presentation_type:String = "none"
	var presentation_child_count:int = 0
	
	if presentation_action != null:
		presentation_type = presentation_action.action_type
		presentation_child_count = presentation_action.children.size()
	
	DebugOverlay.log_message("ReplayRecorder", "Recorded token_move step %d for token %d: %s -> %s, presentation %s with %d child action(s)." % [step.step_id, token_id, str(from_pos), str(to_pos), presentation_type, presentation_child_count])
	return true


func clear_move_batch() -> void:
	move_batch_depth = 0
	batched_move_state_actions.clear()
	batched_move_round_number = 1
	batched_move_turn_number = 1
	batched_move_player_id = -1
	batched_move_has_context = false


func is_move_batch_active() -> bool:
	return move_batch_depth > 0


func get_next_token_id() -> int:
	var result:int = next_token_id
	next_token_id += 1
	return result


func is_token_id_registered(token_id:int) -> bool:
	return registered_token_ids.has(token_id)


func has_recorded_token_spawn(token_id:int) -> bool:
	return spawn_recorded_token_ids.has(token_id)


func has_recorded_token_destruction(token_id:int) -> bool:
	return destroyed_token_ids.has(token_id)


func get_registered_token_count() -> int:
	return registered_token_ids.size()


func get_recorded_spawn_count() -> int:
	return spawn_recorded_token_ids.size()


func get_registered_instance_id(token_id:int) -> int:
	if registered_token_ids.has(token_id) == false:
		return -1
	
	return int(registered_token_ids[token_id])


static func generate_match_id() -> String:
	var crypto:Crypto = Crypto.new()
	var bytes:PackedByteArray = crypto.generate_random_bytes(16)
	
	if bytes.size() != 16:
		return create_fallback_match_id()
	
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	
	var result:String = ""
	
	for index in range(bytes.size()):
		if index == 4 or index == 6 or index == 8 or index == 10:
			result += "-"
		
		result += "%02x" % int(bytes[index])
	
	return result


static func create_fallback_match_id() -> String:
	var unix_time:int = int(Time.get_unix_time_from_system())
	var ticks:int = Time.get_ticks_usec()
	var random_value:int = randi()
	
	return "%d-%d-%d" % [unix_time, ticks, random_value]

func configure_match(session:MatchSession, initial_gravity:String) -> bool:
	if is_recording() == false:
		return false
	
	if session == null:
		return false
	
	if match_configured:
		return true
	
	var used_initial_gravity:String = initial_gravity.strip_edges()
	
	if used_initial_gravity == "":
		return false
	
	var board_metadata:Dictionary = {
		"columns": session.get_board_columns(),
		"rows": session.get_board_rows(),
		"tokens_to_win": session.get_tokens_to_win(),
		"initial_gravity": used_initial_gravity
	}
	
	var rules_metadata:Dictionary = {
		"turn_timer_seconds": session.get_turn_timer_seconds(),
		"starting_token_points": session.get_starting_token_points(),
		"configured_starting_player_id": session.get_configured_starting_player_id()
	}
	
	if replay.set_metadata_value("board", board_metadata) == false:
		return false
	
	if replay.set_metadata_value("rules", rules_metadata) == false:
		return false
	
	for player_id in range(session.get_player_count()):
		var player:MatchSessionPlayerData = session.get_player(player_id)
		
		if player == null:
			return false
		
		var player_data:Dictionary = create_replay_player_data(player)
		
		if player_data.is_empty():
			return false
		
		if replay.add_player(player_data) == false:
			return false
	
	match_configured = true
	
	DebugOverlay.log_message("ReplayRecorder", "Configured replay header for %d player(s) on a %dx%d board." % [session.get_player_count(), session.get_board_columns(), session.get_board_rows()])
	return true


func create_replay_player_data(player:MatchSessionPlayerData) -> Dictionary:
	if player == null:
		return {}
	
	var palette_data:Array = []
	
	if player.colour_palette != null:
		for colour in player.colour_palette.colors:
			palette_data.append(ReplayAction.colour_to_data(colour))
	
	var loadout_data:Array = []
	var starting_counts:Dictionary = player.get_starting_token_counts()
	var token_types:Array = starting_counts.keys()
	token_types.sort()
	
	for token_type_value in token_types:
		var token_type:int = int(token_type_value)
		var token_count:int = int(starting_counts[token_type_value])
		
		if token_count <= 0:
			continue
		
		var replay_token_type:String = TokenLibrary.get_replay_id(token_type)
		
		if replay_token_type == "":
			push_error("ReplayRecorder: Player %d has a token type without a stable replay ID." % player.player_id)
			return {}
		
		loadout_data.append({
			"token_type": replay_token_type,
			"count": token_count
		})
	
	return {
		"player_id": player.player_id,
		"name": player.player_name,
		"palette": palette_data,
		"starting_tokens": loadout_data
	}
	
func record_boundary_step(step_type:String, round_number:int, turn_number:int, player_id:int, metadata:Dictionary = {}) -> bool:
	if is_recording() == false:
		return false
	
	if ReplayFormat.is_valid_step_type(step_type) == false:
		return false
	
	if ReplayAction.is_json_safe_dictionary(metadata) == false:
		return false
	
	var step:ReplayStep = replay.create_next_step(step_type)
	step.set_context(round_number, turn_number, player_id)
	
	for key in metadata.keys():
		if step.set_metadata_value(str(key), metadata[key]) == false:
			return false
	
	if replay.add_step(step) == false:
		return false
	
	DebugOverlay.log_message("ReplayRecorder", "Recorded %s step %d: round %d, turn %d, player %d." % [step_type, step.step_id, step.round_number, step.turn_number, step.player_id])
	return true


func record_match_start(round_number:int, turn_number:int, starting_player_id:int) -> bool:
	if is_recording() == false:
		return false
	
	if match_configured == false:
		push_error("ReplayRecorder: Match cannot start before the replay header is configured.")
		return false
	
	if match_started:
		return true
	
	var metadata:Dictionary = {
		"starting_player_id": starting_player_id
	}
	
	if record_boundary_step(ReplayFormat.STEP_MATCH_START, round_number, turn_number, starting_player_id, metadata) == false:
		return false
	
	match_started = true
	return true


func record_round_start(round_number:int, turn_number:int, starting_player_id:int, gravity:String) -> bool:
	if is_recording() == false:
		return false
	
	if match_started == false:
		return false
	
	if recorded_round_starts.has(round_number):
		return true
	
	var metadata:Dictionary = {
		"starting_player_id": starting_player_id,
		"gravity": gravity
	}
	
	if record_boundary_step(ReplayFormat.STEP_ROUND_START, round_number, turn_number, starting_player_id, metadata) == false:
		return false
	
	recorded_round_starts[round_number] = true
	return true


func record_turn_start(round_number:int, turn_number:int, player_id:int) -> bool:
	if is_recording() == false:
		return false
	
	if current_turn_is_open:
		if open_turn_round_number == round_number and open_turn_number == turn_number and open_turn_player_id == player_id:
			return true
		
		push_error("ReplayRecorder: Tried to start a replay turn before the previous turn was closed.")
		return false
	
	if record_boundary_step(ReplayFormat.STEP_TURN_START, round_number, turn_number, player_id) == false:
		return false
	
	current_turn_is_open = true
	open_turn_round_number = round_number
	open_turn_number = turn_number
	open_turn_player_id = player_id
	return true


func record_turn_end(reason:String = "completed") -> bool:
	if is_recording() == false:
		return false
	
	if current_turn_is_open == false:
		return true
	
	var metadata:Dictionary = {
		"reason": reason
	}
	
	if record_boundary_step(ReplayFormat.STEP_TURN_END, open_turn_round_number, open_turn_number, open_turn_player_id, metadata) == false:
		return false
	
	current_turn_is_open = false
	return true


func record_round_end(round_number:int, turn_number:int, winner_id:int, scores:Array) -> bool:
	if is_recording() == false:
		return false
	
	if record_turn_end("round_complete") == false:
		return false
	
	var metadata:Dictionary = {
		"winner_id": winner_id,
		"scores": scores
	}
	
	return record_boundary_step(ReplayFormat.STEP_ROUND_END, round_number, turn_number, winner_id, metadata)


func record_match_end(round_number:int, turn_number:int, player_id:int, scores:Array, reason:String = "scene_exit") -> bool:
	if is_recording() == false:
		return false
	
	if match_ended:
		return true
	
	if current_turn_is_open:
		if record_turn_end("match_end") == false:
			return false
	
	var metadata:Dictionary = {
		"reason": reason,
		"scores": scores
	}
	
	if record_boundary_step(ReplayFormat.STEP_MATCH_END, round_number, turn_number, player_id, metadata) == false:
		return false
	
	match_ended = true
	return true
	
func save_replay() -> String:
	if is_recording() == false:
		return ""
	
	if ReplayCheckpointBuilder.rebuild_checkpoints(replay) == false:
		DebugOverlay.log_error("ReplayRecorder", "Replay %s failed state reconstruction and could not be saved." % get_match_id())
		return ""
	
	var file_path:String = ReplayStorage.save_replay(replay)
	
	if file_path == "":
		DebugOverlay.log_error("ReplayRecorder", "Could not save replay %s." % get_match_id())
		return ""
	
	last_saved_file_path = file_path
	
	DebugOverlay.log_message("ReplayRecorder", "Saved replay %s with %d step(s) and %d checkpoint(s) to %s." % [get_match_id(), replay.get_step_count(), replay.get_checkpoint_count(), file_path])
	return file_path


func get_last_saved_file_path() -> String:
	return last_saved_file_path
	
