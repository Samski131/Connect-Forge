class_name TimeCounterLabelUI
extends EffectControl

var game_manager:Node = null


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	
	if game_manager != null:
		if game_manager.has_signal("game_time_changed"):
			if game_manager.game_time_changed.is_connected(_on_game_time_changed) == false:
				game_manager.game_time_changed.connect(_on_game_time_changed)
	
	refresh()


func refresh() -> void:
	if self == null:
		return
	
	if game_manager == null:
		self.text = "00:00"
		return
	
	if game_manager.has_method("get_elapsed_time_text"):
		self.text = game_manager.get_elapsed_time_text()
		return
	
	var elapsed_seconds:int = int(game_manager.get("elapsed_game_seconds"))
	self.text = format_seconds_as_minutes_seconds(elapsed_seconds)


func _on_game_time_changed(total_seconds:int) -> void:
	if self == null:
		return
	
	self.text = format_seconds_as_minutes_seconds(total_seconds)


func format_seconds_as_minutes_seconds(total_seconds:int) -> String:
	var used_seconds:int = max(total_seconds, 0)
	var minutes:int = int(used_seconds / 60)
	var seconds:int = used_seconds % 60
	
	return "%02d:%02d" % [minutes, seconds]
