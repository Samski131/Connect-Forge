extends Token
# Chameleon Token
# Visually disguises itself as another player's basic token, but still belongs to its original player.

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
	has_revealed = false
	charges -= ability_cost
	
	if board.visuals != null:
		queue_visual_effect(ChameleonTransformVisualEffect.new(self, fake_player_id, transform_duration))
	else:
		prepare_chameleon_transform(fake_player_id)
		set_chameleon_dissolve_progress(1.0)
		finish_chameleon_transform()
	
	return true


func pick_fake_player_id() -> int:
	var game_manager:Node = get_tree().get_first_node_in_group("game manager")
	
	if game_manager == null:
		return -1
	
	if game_manager.has_method("get_player_count") == false:
		return -1
	
	var player_count:int = game_manager.get_player_count()
	var valid_player_ids:Array[int] = []
	
	for possible_player_id in range(player_count):
		if possible_player_id != player_id:
			valid_player_ids.append(possible_player_id)
	
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
	return ChameleonRevealVisualEffect.new(self, reveal_duration)


func reveal_chameleon_instantly() -> bool:
	if can_reveal_chameleon_after_win() == false:
		return false
	
	has_revealed = true
	
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
