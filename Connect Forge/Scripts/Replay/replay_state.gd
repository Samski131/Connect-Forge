class_name ReplayState
extends RefCounted

const STATE_VERSION:int = 2

var columns:int = 0
var rows:int = 0
var tokens_to_win:int = 0

var round_number:int = 1
var turn_number:int = 1
var player_id:int = -1

var gravity:String = ReplayFormat.GRAVITY_DOWN
var winner_id:int = -1

var scores:Array = []
var tokens:Dictionary = {}


func clear() -> void:
	columns = 0
	rows = 0
	tokens_to_win = 0
	
	round_number = 1
	turn_number = 1
	player_id = -1
	
	gravity = ReplayFormat.GRAVITY_DOWN
	winner_id = -1
	
	scores.clear()
	tokens.clear()


func setup_from_replay(replay:ReplayData) -> bool:
	clear()
	
	if replay == null:
		return false
	
	if replay.metadata.has("board") == false:
		return false
	
	var board_value = replay.metadata["board"]
	
	if typeof(board_value) != TYPE_DICTIONARY:
		return false
	
	var board_data:Dictionary = board_value
	
	columns = int(board_data.get("columns", 0))
	rows = int(board_data.get("rows", 0))
	tokens_to_win = int(board_data.get("tokens_to_win", 0))
	gravity = str(board_data.get("initial_gravity", ReplayFormat.GRAVITY_DOWN))
	
	if columns <= 0:
		return false
	
	if rows <= 0:
		return false
	
	if tokens_to_win <= 0:
		return false
	
	if is_valid_gravity_id(gravity) == false:
		return false
	
	var found_player_ids:Dictionary = {}
	
	for player_value in replay.players:
		if typeof(player_value) != TYPE_DICTIONARY:
			return false
		
		var player_data:Dictionary = player_value
		var replay_player_id:int = int(player_data.get("player_id", -1))
		
		if replay_player_id < 0:
			return false
		
		if found_player_ids.has(replay_player_id):
			return false
		
		found_player_ids[replay_player_id] = true
		
		scores.append({
			"player_id": replay_player_id,
			"wins": 0,
			"losses": 0
		})
	
	return true


func apply_step(step:ReplayStep) -> bool:
	if step == null:
		return false
	
	if step.is_valid() == false:
		return false
	
	round_number = step.round_number
	turn_number = step.turn_number
	player_id = step.player_id
	
	if step.step_type == ReplayFormat.STEP_ROUND_START:
		tokens.clear()
		winner_id = -1
		
		var round_gravity:String = str(step.metadata.get("gravity", gravity))
		
		if is_valid_gravity_id(round_gravity) == false:
			return false
		
		gravity = round_gravity
	
	if step.step_type == ReplayFormat.STEP_ROUND_END:
		winner_id = int(step.metadata.get("winner_id", -1))
		
		if step.metadata.has("scores"):
			if set_scores_from_value(step.metadata["scores"]) == false:
				return false
	
	if step.step_type == ReplayFormat.STEP_MATCH_END:
		if step.metadata.has("scores"):
			if set_scores_from_value(step.metadata["scores"]) == false:
				return false
	
	var move_actions:Array[ReplayAction] = []
	
	for action in step.state_actions:
		if action == null:
			return false
		
		if action.action_type == ReplayFormat.STATE_TOKEN_MOVE:
			move_actions.append(action)
	
	if move_actions.size() > 1:
		if apply_move_batch(move_actions) == false:
			return false
		
		for action in step.state_actions:
			if action.action_type == ReplayFormat.STATE_TOKEN_MOVE:
				continue
			
			if apply_state_action(action) == false:
				return false
	else:
		for action in step.state_actions:
			if apply_state_action(action) == false:
				return false
	
	if apply_persistent_presentation(step.presentation) == false:
		return false
	
	return true

func apply_persistent_presentation(action:ReplayAction) -> bool:
	if action == null:
		return true
	
	if action.action_version != ReplayFormat.ACTION_VERSION_DEFAULT:
		return true
	
	if action.is_sequence() or action.is_parallel():
		for child in action.children:
			if apply_persistent_presentation(child) == false:
				return false
		
		return true
	
	if action.is_presentation_action() == false:
		return true
	
	if action.action_type == ReplayFormat.PRESENTATION_TOKEN_DARKEN:
		return apply_persistent_token_darken(action)
	
	return true


func apply_persistent_token_darken(action:ReplayAction) -> bool:
	var token_id:int = int(action.payload.get("token_id", -1))
	
	if tokens.has(token_id) == false:
		return true
	
	var amount:float = clamp(float(action.payload.get("amount", 0.0)), 0.0, 1.0)
	
	if amount <= 0.0:
		return true
	
	var token_data:Dictionary = tokens[token_id]
	var visual_state:Dictionary = {}
	
	if token_data.has("visual_state"):
		if typeof(token_data["visual_state"]) != TYPE_DICTIONARY:
			return false
		
		visual_state = token_data["visual_state"].duplicate(true)
	
	var current_darken_amount:float = clamp(float(visual_state.get("darken_amount", 0.0)), 0.0, 1.0)
	var combined_darken_amount:float = 1.0 - ((1.0 - current_darken_amount) * (1.0 - amount))
	
	visual_state["darken_amount"] = combined_darken_amount
	token_data["visual_state"] = visual_state
	tokens[token_id] = token_data
	return true

func apply_state_action(action:ReplayAction) -> bool:
	if action == null:
		return false
	
	if action.is_state_action() == false:
		return false
	
	if action.action_version != 1:
		return false
	
	if action.action_type == ReplayFormat.STATE_TOKEN_SPAWN:
		return apply_token_spawn(action)
	
	if action.action_type == ReplayFormat.STATE_TOKEN_MOVE:
		return apply_token_move(action)
	
	if action.action_type == ReplayFormat.STATE_TOKEN_DESTROY:
		return apply_token_destroy(action)
	
	if action.action_type == ReplayFormat.STATE_TOKEN_FLIP:
		return apply_token_flip(action)
	
	if action.action_type == ReplayFormat.STATE_TOKEN_UPDATE:
		return apply_token_update(action)
	
	if action.action_type == ReplayFormat.STATE_GRAVITY_CHANGE:
		return apply_gravity_change(action)
	
	return false


func apply_token_spawn(action:ReplayAction) -> bool:
	var token_id:int = int(action.payload.get("token_id", -1))
	var token_type:String = str(action.payload.get("token_type", ""))
	var replay_player_id:int = int(action.payload.get("player_id", -1))
	
	if token_id < 0:
		return false
	
	if tokens.has(token_id):
		return false
	
	if TokenLibrary.is_valid_replay_id(token_type) == false:
		return false
	
	if replay_player_id < 0:
		return false
	
	if action.payload.has("position") == false:
		return false
	
	var position_value = action.payload["position"]
	
	if is_valid_position_data(position_value) == false:
		return false
	
	var position:Vector2i = position_from_data(position_value)
	
	if is_position_in_bounds(position) == false:
		return false
	
	if get_token_id_at_position(position) >= 0:
		return false
	
	var token_data:Dictionary = action.payload.duplicate(true)
	token_data["token_id"] = token_id
	token_data["token_type"] = token_type
	token_data["player_id"] = replay_player_id
	token_data["position"] = position_to_data(position)
	token_data["flipped"] = bool(action.payload.get("flipped", false))
	token_data["charges"] = int(action.payload.get("charges", 0))
	
	if ReplayAction.is_json_safe_dictionary(token_data) == false:
		return false
	
	tokens[token_id] = token_data
	return true


func apply_token_move(action:ReplayAction) -> bool:
	var token_id:int = int(action.payload.get("token_id", -1))
	
	if tokens.has(token_id) == false:
		return false
	
	if action.payload.has("from") == false:
		return false
	
	if action.payload.has("to") == false:
		return false
	
	if is_valid_position_data(action.payload["from"]) == false:
		return false
	
	if is_valid_position_data(action.payload["to"]) == false:
		return false
	
	var from_pos:Vector2i = position_from_data(action.payload["from"])
	var to_pos:Vector2i = position_from_data(action.payload["to"])
	var token_data:Dictionary = tokens[token_id]
	
	if position_from_data(token_data.get("position", [])) != from_pos:
		return false
	
	if is_position_in_bounds(to_pos) == false:
		return false
	
	var occupying_token_id:int = get_token_id_at_position(to_pos)
	
	if occupying_token_id >= 0 and occupying_token_id != token_id:
		return false
	
	token_data["position"] = position_to_data(to_pos)
	tokens[token_id] = token_data
	return true


func apply_move_batch(actions:Array[ReplayAction]) -> bool:
	if actions.is_empty():
		return true
	
	var moving_token_ids:Dictionary = {}
	var destinations:Dictionary = {}
	var prepared_moves:Array[Dictionary] = []
	
	for action in actions:
		if action == null:
			return false
		
		if action.is_state_action() == false:
			return false
		
		if action.action_version != 1:
			return false
		
		if action.action_type != ReplayFormat.STATE_TOKEN_MOVE:
			return false
		
		var token_id:int = int(action.payload.get("token_id", -1))
		
		if token_id < 0:
			return false
		
		if tokens.has(token_id) == false:
			return false
		
		if moving_token_ids.has(token_id):
			return false
		
		if action.payload.has("from") == false:
			return false
		
		if action.payload.has("to") == false:
			return false
		
		if is_valid_position_data(action.payload["from"]) == false:
			return false
		
		if is_valid_position_data(action.payload["to"]) == false:
			return false
		
		var from_pos:Vector2i = position_from_data(action.payload["from"])
		var to_pos:Vector2i = position_from_data(action.payload["to"])
		var token_data:Dictionary = tokens[token_id]
		
		if position_from_data(token_data.get("position", [])) != from_pos:
			return false
		
		if is_position_in_bounds(to_pos) == false:
			return false
		
		if destinations.has(to_pos):
			return false
		
		moving_token_ids[token_id] = true
		destinations[to_pos] = token_id
		
		prepared_moves.append({
			"token_id": token_id,
			"to": to_pos
		})
	
	for move_data in prepared_moves:
		var to_pos:Vector2i = move_data["to"]
		var occupying_token_id:int = get_token_id_at_position(to_pos)
		
		if occupying_token_id < 0:
			continue
		
		if moving_token_ids.has(occupying_token_id):
			continue
		
		return false
	
	for move_data in prepared_moves:
		var token_id:int = int(move_data["token_id"])
		var to_pos:Vector2i = move_data["to"]
		var token_data:Dictionary = tokens[token_id]
		
		token_data["position"] = position_to_data(to_pos)
		tokens[token_id] = token_data
	
	return true


func apply_token_destroy(action:ReplayAction) -> bool:
	var token_id:int = int(action.payload.get("token_id", -1))
	
	if tokens.has(token_id) == false:
		return false
	
	var token_data:Dictionary = tokens[token_id]
	
	if action.payload.has("position"):
		if is_valid_position_data(action.payload["position"]) == false:
			return false
		
		var expected_pos:Vector2i = position_from_data(action.payload["position"])
		var current_pos:Vector2i = position_from_data(token_data.get("position", []))
		
		if expected_pos != current_pos:
			return false
	
	tokens.erase(token_id)
	return true


func apply_token_flip(action:ReplayAction) -> bool:
	var token_id:int = int(action.payload.get("token_id", -1))
	
	if tokens.has(token_id) == false:
		return false
	
	var token_data:Dictionary = tokens[token_id]
	token_data["flipped"] = bool(action.payload.get("flipped", false))
	tokens[token_id] = token_data
	return true


func apply_token_update(action:ReplayAction) -> bool:
	var token_id:int = int(action.payload.get("token_id", -1))
	
	if tokens.has(token_id) == false:
		return false
	
	var token_data:Dictionary = tokens[token_id]
	
	if action.payload.has("charges"):
		token_data["charges"] = int(action.payload["charges"])
	
	if action.payload.has("flipped"):
		token_data["flipped"] = bool(action.payload["flipped"])
	
	if action.payload.has("state_data"):
		if typeof(action.payload["state_data"]) != TYPE_DICTIONARY:
			return false
		
		var state_data:Dictionary = action.payload["state_data"]
		
		if ReplayAction.is_json_safe_dictionary(state_data) == false:
			return false
		
		token_data["state_data"] = state_data.duplicate(true)
	
	tokens[token_id] = token_data
	return true


func apply_gravity_change(action:ReplayAction) -> bool:
	var from_gravity:String = str(action.payload.get("from", ""))
	var to_gravity:String = str(action.payload.get("to", ""))
	
	if is_valid_gravity_id(from_gravity) == false:
		return false
	
	if is_valid_gravity_id(to_gravity) == false:
		return false
	
	if gravity != from_gravity:
		return false
	
	gravity = to_gravity
	return true


func set_scores_from_value(value) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	
	var score_values:Array = value
	var new_scores:Array = []
	var found_player_ids:Dictionary = {}
	
	for score_value in score_values:
		if typeof(score_value) != TYPE_DICTIONARY:
			return false
		
		var score_data:Dictionary = score_value
		var score_player_id:int = int(score_data.get("player_id", -1))
		var wins:int = int(score_data.get("wins", 0))
		var losses:int = int(score_data.get("losses", 0))
		
		if score_player_id < 0:
			return false
		
		if wins < 0 or losses < 0:
			return false
		
		if found_player_ids.has(score_player_id):
			return false
		
		found_player_ids[score_player_id] = true
		
		new_scores.append({
			"player_id": score_player_id,
			"wins": wins,
			"losses": losses
		})
	
	scores = new_scores
	return true


func get_token_data(token_id:int) -> Dictionary:
	if tokens.has(token_id) == false:
		return {}
	
	var token_data:Dictionary = tokens[token_id]
	return token_data.duplicate(true)


func get_token_count() -> int:
	return tokens.size()


func get_token_id_at_position(position:Vector2i) -> int:
	for token_id_value in tokens.keys():
		var token_id:int = int(token_id_value)
		var token_data:Dictionary = tokens[token_id]
		
		if is_valid_position_data(token_data.get("position", [])) == false:
			continue
		
		if position_from_data(token_data["position"]) == position:
			return token_id
	
	return -1


func is_position_in_bounds(position:Vector2i) -> bool:
	if position.x < 0 or position.x >= columns:
		return false
	
	if position.y < 0 or position.y >= rows:
		return false
	
	return true


func to_dictionary() -> Dictionary:
	var serialized_tokens:Array = []
	var token_ids:Array[int] = []
	
	for token_id_value in tokens.keys():
		token_ids.append(int(token_id_value))
	
	token_ids.sort()
	
	for token_id in token_ids:
		var token_data:Dictionary = tokens[token_id]
		serialized_tokens.append(token_data.duplicate(true))
	
	return {
		"state_version": STATE_VERSION,
		"round": round_number,
		"turn": turn_number,
		"player": player_id,
		"gravity": gravity,
		"winner": winner_id,
		"scores": scores.duplicate(true),
		"tokens": serialized_tokens
	}


func load_from_dictionary(replay:ReplayData, data:Dictionary) -> bool:
	if setup_from_replay(replay) == false:
		return false
	
	if ReplayAction.is_json_safe_dictionary(data) == false:
		return false
	
	if int(data.get("state_version", -1)) != STATE_VERSION:
		return false
	
	round_number = max(int(data.get("round", 1)), 1)
	turn_number = max(int(data.get("turn", 1)), 1)
	player_id = int(data.get("player", -1))
	winner_id = int(data.get("winner", -1))
	
	var used_gravity:String = str(data.get("gravity", gravity))
	
	if is_valid_gravity_id(used_gravity) == false:
		return false
	
	gravity = used_gravity
	
	if data.has("scores"):
		if set_scores_from_value(data["scores"]) == false:
			return false
	
	tokens.clear()
	
	if data.has("tokens") == false:
		return true
	
	if typeof(data["tokens"]) != TYPE_ARRAY:
		return false
	
	var token_values:Array = data["tokens"]
	var found_positions:Dictionary = {}
	
	for token_value in token_values:
		if typeof(token_value) != TYPE_DICTIONARY:
			return false
		
		var token_data:Dictionary = token_value
		
		if ReplayAction.is_json_safe_dictionary(token_data) == false:
			return false
		
		var token_id:int = int(token_data.get("token_id", -1))
		var token_type:String = str(token_data.get("token_type", ""))
		
		if token_id < 0:
			return false
		
		if tokens.has(token_id):
			return false
		
		if TokenLibrary.is_valid_replay_id(token_type) == false:
			return false
		
		if token_data.has("position") == false:
			return false
		
		if is_valid_position_data(token_data["position"]) == false:
			return false
		
		var position:Vector2i = position_from_data(token_data["position"])
		
		if is_position_in_bounds(position) == false:
			return false
		
		if found_positions.has(position):
			return false
		
		found_positions[position] = true
		
		var normalized_data:Dictionary = token_data.duplicate(true)
		normalized_data["token_id"] = token_id
		normalized_data["token_type"] = token_type
		normalized_data["player_id"] = int(token_data.get("player_id", -1))
		normalized_data["position"] = position_to_data(position)
		normalized_data["flipped"] = bool(token_data.get("flipped", false))
		normalized_data["charges"] = int(token_data.get("charges", 0))
		
		tokens[token_id] = normalized_data
	
	return true


static func position_to_data(position:Vector2i) -> Array:
	return [position.x, position.y]


static func position_from_data(value) -> Vector2i:
	if is_valid_position_data(value) == false:
		return Vector2i(-999999, -999999)
	
	var data:Array = value
	return Vector2i(int(data[0]), int(data[1]))


static func is_valid_position_data(value) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	
	var data:Array = value
	
	if data.size() != 2:
		return false
	
	if is_numeric_json_value(data[0]) == false:
		return false
	
	if is_numeric_json_value(data[1]) == false:
		return false
	
	return true


static func is_numeric_json_value(value) -> bool:
	var value_type:int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


static func is_valid_gravity_id(value:String) -> bool:
	if value == ReplayFormat.GRAVITY_UP:
		return true
	
	if value == ReplayFormat.GRAVITY_RIGHT:
		return true
	
	if value == ReplayFormat.GRAVITY_DOWN:
		return true
	
	if value == ReplayFormat.GRAVITY_LEFT:
		return true
	
	return false
