class_name TokenTrayInventory
extends Node

signal trays_reset
signal tray_changed(player_id:int)
signal token_type_added(player_id:int, token_type:int)
signal token_count_changed(player_id:int, token_type:int, new_count:int)

var session:MatchSession = null
var player_trays:Array[PlayerTokenTrayData] = []


func setup_for_session(new_session:MatchSession) -> bool:
	disconnect_session_signals()
	player_trays.clear()
	session = new_session
	
	if session == null:
		push_error("TokenTrayInventory: Cannot use session mode without a MatchSession.")
		return false
	
	connect_session_signals()
	trays_reset.emit()
	return true


func setup_for_players(player_count:int) -> void:
	disconnect_session_signals()
	session = null
	player_trays.clear()
	
	var used_player_count:int = max(player_count, 0)
	
	for player_id in range(used_player_count):
		var tray:PlayerTokenTrayData = PlayerTokenTrayData.new()
		tray.setup(player_id)
		player_trays.append(tray)
	
	trays_reset.emit()


func is_using_session() -> bool:
	return session != null


func connect_session_signals() -> void:
	if session == null:
		return
	
	if session.token_type_added.is_connected(_on_session_token_type_added) == false:
		session.token_type_added.connect(_on_session_token_type_added)
	
	if session.token_count_changed.is_connected(_on_session_token_count_changed) == false:
		session.token_count_changed.connect(_on_session_token_count_changed)
	
	if session.player_tokens_reset.is_connected(_on_session_player_tokens_reset) == false:
		session.player_tokens_reset.connect(_on_session_player_tokens_reset)
	
	if session.all_tokens_reset.is_connected(_on_session_all_tokens_reset) == false:
		session.all_tokens_reset.connect(_on_session_all_tokens_reset)


func disconnect_session_signals() -> void:
	if session == null:
		return
	
	if session.token_type_added.is_connected(_on_session_token_type_added):
		session.token_type_added.disconnect(_on_session_token_type_added)
	
	if session.token_count_changed.is_connected(_on_session_token_count_changed):
		session.token_count_changed.disconnect(_on_session_token_count_changed)
	
	if session.player_tokens_reset.is_connected(_on_session_player_tokens_reset):
		session.player_tokens_reset.disconnect(_on_session_player_tokens_reset)
	
	if session.all_tokens_reset.is_connected(_on_session_all_tokens_reset):
		session.all_tokens_reset.disconnect(_on_session_all_tokens_reset)


func reset_all_trays() -> void:
	if session != null:
		session.reset_tokens_for_round()
		return
	
	for tray in player_trays:
		if tray == null:
			continue
		
		tray.reset_counts()
	
	trays_reset.emit()


func get_player_tray(player_id:int) -> PlayerTokenTrayData:
	if session != null:
		return null
	
	if player_id < 0:
		return null
	
	if player_id >= player_trays.size():
		return null
	
	return player_trays[player_id]


func has_player(player_id:int) -> bool:
	if session != null:
		return session.is_valid_player_id(player_id)
	
	return get_player_tray(player_id) != null


func get_token_types_for_player(player_id:int) -> Array[int]:
	if session != null:
		return session.get_token_types_for_player(player_id)
	
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	var result:Array[int] = []
	
	if tray == null:
		return result
	
	for token_type in TokenLibrary.get_token_types_in_tray_order():
		if tray.has_token_type(token_type):
			result.append(token_type)
	
	return result


func get_token_count(player_id:int, token_type:int) -> int:
	if session != null:
		return session.get_token_count(player_id, token_type)
	
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return 0
	
	return tray.get_count(token_type)


func set_token_count(player_id:int, token_type:int, amount:int) -> void:
	if session != null:
		session.set_token_count(player_id, token_type, amount)
		return
	
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return
	
	var was_new_token_type:bool = tray.has_token_type(token_type) == false
	
	tray.set_count(token_type, amount)
	
	if was_new_token_type:
		token_type_added.emit(player_id, token_type)
	
	var new_count:int = tray.get_count(token_type)
	token_count_changed.emit(player_id, token_type, new_count)
	tray_changed.emit(player_id)


func player_has_token(player_id:int, token_type:int) -> bool:
	if session != null:
		return session.player_has_token(player_id, token_type)
	
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
	if session != null:
		return session.spend_token(player_id, token_type)
	
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
	if session != null:
		session.refund_token(player_id, token_type, amount)
		return
	
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return
	
	var was_new_token_type:bool = tray.has_token_type(token_type) == false
	
	tray.refund_token(token_type, amount)
	
	if was_new_token_type:
		token_type_added.emit(player_id, token_type)
	
	var new_count:int = tray.get_count(token_type)
	token_count_changed.emit(player_id, token_type, new_count)
	tray_changed.emit(player_id)


func add_tokens(player_id:int, token_type:int, amount:int = 1) -> void:
	if session != null:
		session.add_tokens(player_id, token_type, amount)
		return
	
	var tray:PlayerTokenTrayData = get_player_tray(player_id)
	
	if tray == null:
		return
	
	if amount <= 0:
		return
	
	var was_new_token_type:bool = tray.has_token_type(token_type) == false
	
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


func _on_session_token_type_added(player_id:int, token_type:int) -> void:
	token_type_added.emit(player_id, token_type)


func _on_session_token_count_changed(player_id:int, token_type:int, new_count:int) -> void:
	token_count_changed.emit(player_id, token_type, new_count)
	tray_changed.emit(player_id)


func _on_session_player_tokens_reset(player_id:int) -> void:
	tray_changed.emit(player_id)


func _on_session_all_tokens_reset() -> void:
	trays_reset.emit()
