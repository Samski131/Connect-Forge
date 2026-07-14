class_name TurnCounterLabelUI
extends Label

@export var label_prefix:String = "Turn "

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
	
	if game_manager.turn_number_changed.is_connected(_on_turn_number_changed) == false:
		game_manager.turn_number_changed.connect(_on_turn_number_changed)


func disconnect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.turn_number_changed.is_connected(_on_turn_number_changed):
		game_manager.turn_number_changed.disconnect(_on_turn_number_changed)


func refresh() -> void:
	if game_manager == null:
		text = label_prefix + "1"
		return
	
	text = label_prefix + str(game_manager.get_current_turn_number())


func _on_turn_number_changed(_turn_number:int) -> void:
	UIJuice.play(self, UIJuice.create_pulse_preset())
	refresh()
