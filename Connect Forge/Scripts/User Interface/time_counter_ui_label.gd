class_name TimeCounterLabelUI
extends Label

var game_manager:GameManager = null


func _ready() -> void:
	refresh()


func setup(new_game_manager:GameManager) -> void:
	disconnect_game_manager_signals()
	game_manager = new_game_manager
	connect_game_manager_signals()
	refresh()


func connect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.game_time_changed.is_connected(_on_game_time_changed) == false:
		game_manager.game_time_changed.connect(_on_game_time_changed)


func disconnect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.game_time_changed.is_connected(_on_game_time_changed):
		game_manager.game_time_changed.disconnect(_on_game_time_changed)


func refresh() -> void:
	if game_manager == null:
		text = "00:00"
		return
	
	text = game_manager.get_elapsed_time_text()


func _on_game_time_changed(total_seconds:int) -> void:
	text = format_seconds_as_minutes_seconds(total_seconds)


func format_seconds_as_minutes_seconds(total_seconds:int) -> String:
	var used_seconds:int = max(total_seconds, 0)
	var minutes:int = int(used_seconds / 60.0)
	var seconds:int = used_seconds % 60
	
	return "%02d:%02d" % [minutes, seconds]
