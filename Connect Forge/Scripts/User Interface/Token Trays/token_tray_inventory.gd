class_name TokenTrayInventory
extends Node

signal trays_reset
signal tray_changed(player_id:int)
signal token_type_added(player_id:int, token_type:int)
signal token_count_changed(player_id:int, token_type:int, new_count:int)

var player_trays:Array[PlayerTokenTrayData] = []


func setup_for_players(player_count:int) -> void:
	player_trays.clear()
	
	var used_player_count:int = max(player_count, 0)
	
	for player_id in range(used_player_count):
		var tray:PlayerTokenTrayData = PlayerTokenTrayData.new()
		tray.setup(player_id)
		player_trays.append(tray)
	
	trays_reset.emit()


func reset_all_trays() -> void:
	for tray in player_trays:
		if tray == null:
			continue
		
		tray.reset_counts()
	
	trays_reset.emit()


func get_player_tray(player_id:int) -> PlayerTokenTrayData:
	if player_id < 0:
		return null
	
	if player_id >= player_trays.size():
		return null
	
	return player_trays[player_id]


func get_token_types_for_player(player_id:int) -> Array[int]:
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return []
	
	var result:Array[int] = []
	var ordered_types:Array[int] = TokenLibrary.get_token_types_in_tray_order()
	
	for token_type in ordered_types:
		if tray.has_token_type(token_type):
			result.append(token_type)
	
	return result


func get_token_count(player_id:int, token_type:int) -> int:
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return 0
	
	return tray.get_count(token_type)


func set_token_count(player_id:int, token_type:int, amount:int) -> void:
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return
	
	var was_new_token_type:bool = false
	
	if tray.has_token_type(token_type) == false:
		was_new_token_type = true
	
	tray.set_count(token_type, amount)
	
	if was_new_token_type:
		token_type_added.emit(player_id, token_type)
	
	var new_count:int = tray.get_count(token_type)
	token_count_changed.emit(player_id, token_type, new_count)
	tray_changed.emit(player_id)


func player_has_token(player_id:int, token_type:int) -> bool:
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return false
	
	return tray.has_token(token_type)


func can_player_drag_token(player_id:int, token_type:int, current_player_id:int) -> bool:
	if player_id != current_player_id:
		return false
	
	if player_has_token(player_id, token_type) == false:
		return false
	
	var token_scene:PackedScene = TokenLibrary.get_token_scene(token_type)
	
	if token_scene == null:
		return false
	
	return true


func spend_token(player_id:int, token_type:int) -> bool:
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return false
	
	if tray.spend_token(token_type) == false:
		return false
	
	var new_count:int = tray.get_count(token_type)
	token_count_changed.emit(player_id, token_type, new_count)
	tray_changed.emit(player_id)
	
	return true


func refund_token(player_id:int, token_type:int, amount:int = 1) -> void:
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return
	
	var was_new_token_type:bool = false
	
	if tray.has_token_type(token_type) == false:
		was_new_token_type = true
	
	tray.refund_token(token_type, amount)
	
	if was_new_token_type:
		token_type_added.emit(player_id, token_type)
	
	var new_count:int = tray.get_count(token_type)
	token_count_changed.emit(player_id, token_type, new_count)
	tray_changed.emit(player_id)


func add_tokens(player_id:int, token_type:int, amount:int = 1) -> void:
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return
	
	if amount <= 0:
		return
	
	var was_new_token_type:bool = false
	
	if tray.has_token_type(token_type) == false:
		was_new_token_type = true
	
	tray.add_tokens(token_type, amount)
	
	if was_new_token_type:
		token_type_added.emit(player_id, token_type)
	
	var new_count:int = tray.get_count(token_type)
	token_count_changed.emit(player_id, token_type, new_count)
	tray_changed.emit(player_id)


func get_token_display_name(token_type:int) -> String:
	return TokenLibrary.get_display_name(token_type)


func get_token_description(token_type:int) -> String:
	return TokenLibrary.get_description(token_type)


func get_token_scene(token_type:int) -> PackedScene:
	return TokenLibrary.get_token_scene(token_type)


func can_token_flip(token_type:int) -> bool:
	return TokenLibrary.can_flip(token_type)
