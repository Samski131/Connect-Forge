extends Token

const NETWORK_KEY_FAKE_PLAYER_ID:String = "fake_player_id"
const NETWORK_STATE_HAS_TRANSFORMED:String = "has_transformed"
const NETWORK_STATE_HAS_REVEALED:String = "has_revealed"

var fake_player_id:int = -1
var transform_duration:float = 1.0
var reveal_duration:float = 0.55
var has_transformed:bool = false
var has_revealed:bool = false


func setup_special_token() -> void:
	token_type = TokenLibrary.TokenType.CHAMELEON
	charges = 1
	ability_cost = 1
	keywords = [Global.KEYWORD.ON_LAND]


func requires_network_placement_data() -> bool:
	return true


func get_random_placement_outcome_variants(context:Dictionary) -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	
	var placement_player_id:int = int(context.get("player_id", -1))
	var player_count:int = int(context.get("player_count", 0))
	
	var valid_player_ids:Array[int] = get_valid_fake_player_ids(placement_player_id, player_count)
	
	if valid_player_ids.is_empty():
		return result
	
	var probability:float = 1.0 / float(valid_player_ids.size())
	
	for valid_player_id in valid_player_ids:
		result.append({
			"probability": probability,
			"placement_data": {
				NETWORK_KEY_FAKE_PLAYER_ID: valid_player_id
			},
			"description": "Disguise as Player %d" % (valid_player_id + 1)
		})
	
	return result


func create_network_placement_data(context:Dictionary) -> Dictionary:
	var placement_player_id:int = int(context.get("player_id", -1))
	var player_count:int = int(context.get("player_count", 0))
	var random_source:RandomNumberGenerator = context.get("random_number_generator", null) as RandomNumberGenerator
	
	var chosen_player_id:int = choose_fake_player_id(placement_player_id, player_count, random_source)
	
	if chosen_player_id == -1:
		return {}
	
	return {
		NETWORK_KEY_FAKE_PLAYER_ID: chosen_player_id
	}


func create_network_state_data() -> Dictionary:
	return {
		NETWORK_KEY_FAKE_PLAYER_ID: fake_player_id,
		NETWORK_STATE_HAS_TRANSFORMED: has_transformed,
		NETWORK_STATE_HAS_REVEALED: has_revealed
	}


func apply_network_state_data(new_state_data:Dictionary) -> void:
	fake_player_id = int(new_state_data.get(NETWORK_KEY_FAKE_PLAYER_ID, -1))
	has_transformed = bool(new_state_data.get(NETWORK_STATE_HAS_TRANSFORMED, false))
	has_revealed = bool(new_state_data.get(NETWORK_STATE_HAS_REVEALED, false))
	
	if sprites == null:
		return
	
	if has_transformed and has_revealed == false and fake_player_id >= 0:
		prepare_chameleon_transform(fake_player_id)
		set_chameleon_dissolve_progress(1.0)
		finish_chameleon_transform()
		return
	
	if sprites.has_method("hide_fake_layer"):
		sprites.hide_fake_layer()


func _try_to_use_ability() -> bool:
	return false


func _on_land(_context:Dictionary) -> bool:
	if has_transformed:
		return false
	
	if check_enough_charges(ability_cost) == false:
		return false
	
	var chosen_player_id:int = get_network_fake_player_id()
	
	if chosen_player_id == -1:
		chosen_player_id = pick_fake_player_id()
	
	if chosen_player_id == -1:
		return false
	
	fake_player_id = chosen_player_id
	has_transformed = true
	has_revealed = false
	charges -= ability_cost
	
	if board.visuals != null:
		var transform_effect:ChameleonTransformVisualEffect = ChameleonTransformVisualEffect.new(self, fake_player_id, transform_duration)
		queue_visual_effect_with_state_update(transform_effect)
	else:
		record_replay_state_update()
		prepare_chameleon_transform(fake_player_id)
		set_chameleon_dissolve_progress(1.0)
		finish_chameleon_transform()
	
	return true


func get_network_fake_player_id() -> int:
	var placement_data:Dictionary = get_network_placement_data()
	
	if placement_data.has(NETWORK_KEY_FAKE_PLAYER_ID) == false:
		return -1
	
	var chosen_player_id:int = int(placement_data[NETWORK_KEY_FAKE_PLAYER_ID])
	
	if chosen_player_id < 0:
		return -1
	
	if chosen_player_id == player_id:
		return -1
	
	return chosen_player_id


func pick_fake_player_id() -> int:
	if board == null:
		return -1
	
	if board.is_valid_player_id(player_id) == false:
		return -1
	
	var player_count:int = board.get_player_count()
	
	if player_count <= 1:
		return -1
	
	var random_source:RandomNumberGenerator = null
	
	if board.has_method("get_gameplay_random_number_generator"):
		random_source = board.call("get_gameplay_random_number_generator") as RandomNumberGenerator
	
	return choose_fake_player_id(player_id, player_count, random_source)


func choose_fake_player_id(used_player_id:int, player_count:int, random_source:RandomNumberGenerator = null) -> int:
	var valid_player_ids:Array[int] = get_valid_fake_player_ids(used_player_id, player_count)
	
	if valid_player_ids.is_empty():
		return -1
	
	var random_index:int = 0
	
	if random_source != null:
		random_index = random_source.randi_range(0, valid_player_ids.size() - 1)
	else:
		random_index = randi_range(0, valid_player_ids.size() - 1)
	
	return valid_player_ids[random_index]


func get_valid_fake_player_ids(used_player_id:int, player_count:int) -> Array[int]:
	var valid_player_ids:Array[int] = []
	var used_player_count:int = max(player_count, 0)
	
	for candidate_player_id in range(used_player_count):
		if candidate_player_id == used_player_id:
			continue
		
		valid_player_ids.append(candidate_player_id)
	
	return valid_player_ids


func prepare_chameleon_transform(new_fake_player_id:int) -> void:
	if sprites == null:
		return
	
	if sprites.has_method("prepare_fake_visual"):
		sprites.prepare_fake_visual(new_fake_player_id)


func set_chameleon_dissolve_progress(value:float) -> void:
	if sprites == null:
		return
	
	if sprites.has_method("set_dissolve_progress"):
		sprites.set_dissolve_progress(value)


func finish_chameleon_transform() -> void:
	if sprites == null:
		return
	
	if sprites.has_method("finish_fake_visual"):
		sprites.finish_fake_visual()


func can_reveal_chameleon_after_win() -> bool:
	if has_transformed == false:
		return false
	
	if has_revealed:
		return false
	
	if being_destroyed:
		return false
	
	return true


func create_chameleon_reveal_effect() -> BoardVisualEffect:
	if can_reveal_chameleon_after_win() == false:
		return null
	
	has_revealed = true
	fake_player_id = -1
	
	return ChameleonRevealVisualEffect.new(self, reveal_duration)


func reveal_chameleon_instantly() -> bool:
	if can_reveal_chameleon_after_win() == false:
		return false
	
	has_revealed = true
	fake_player_id = -1
	record_replay_state_update()
	
	prepare_chameleon_reveal()
	set_chameleon_reveal_progress(1.0)
	finish_chameleon_reveal()
	
	return true


func prepare_chameleon_reveal() -> void:
	if sprites == null:
		return
	
	if sprites.has_method("prepare_reveal_visual"):
		sprites.prepare_reveal_visual()


func set_chameleon_reveal_progress(value:float) -> void:
	if sprites == null:
		return
	
	if sprites.has_method("set_reveal_dissolve_progress"):
		sprites.set_reveal_dissolve_progress(value)


func finish_chameleon_reveal() -> void:
	fake_player_id = -1
	
	if sprites == null:
		return
	
	if sprites.has_method("finish_reveal_visual"):
		sprites.finish_reveal_visual()
