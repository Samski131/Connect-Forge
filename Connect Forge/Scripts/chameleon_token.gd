extends Token
# Chameleon Token
# Visually disguises itself as another player's basic token, but still belongs to its original player.

var fake_player_id:int = -1
var transform_duration:float = 1.0
var has_transformed:bool = false


func setup_special_token():
	token_type = TokenType.CHAMELEON
	charges = 1
	ability_cost = 1
	keywords = [Global.KEYWORD.ON_LAND]


func _try_to_use_ability() -> bool:
	return false


func _on_land(_context:Dictionary) -> bool:
	if has_transformed:
		return false
	
	if check_enough_charges(ability_cost) == false:
		return false
	
	var chosen_player_id:int = pick_fake_player_id()
	
	if chosen_player_id == -1:
		return false
	
	fake_player_id = chosen_player_id
	has_transformed = true
	
	# Do not call deduct_charges().
	# Chameleon spends its charge without darkening.
	charges -= ability_cost
	
	if board.visuals != null:
		board.visuals.queue_effect(ChameleonTransformVisualEffect.new(self, fake_player_id, transform_duration))
	else:
		prepare_chameleon_transform(fake_player_id)
		set_chameleon_dissolve_progress(1.0)
		finish_chameleon_transform()
	
	return true


func pick_fake_player_id() -> int:
	var game_manager:Node = get_tree().get_first_node_in_group("game manager")
	
	if game_manager == null:
		return -1
	
	var valid_player_ids:Array[int] = []
	
	for i in range(game_manager.number_of_players):
		if i != player_id:
			valid_player_ids.append(i)
	
	if valid_player_ids.is_empty():
		return -1
	
	var random_index:int = randi_range(0, valid_player_ids.size() - 1)
	return valid_player_ids[random_index]


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
