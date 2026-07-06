extends Button

var game_manager:Node = null


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	
	if pressed.is_connected(_on_pressed) == false:
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if game_manager == null:
		return
	
	if game_manager.has_method("debug_start_next_round") == false:
		return
	
	game_manager.debug_start_next_round()
