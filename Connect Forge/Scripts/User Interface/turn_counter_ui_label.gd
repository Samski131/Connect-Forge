class_name TurnCounterLabelUI
extends Label

@export var label_prefix:String = "Turn "

var game_manager:Node = null


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	
	if game_manager != null:
		if game_manager.has_signal("turn_number_changed"):
			if game_manager.turn_number_changed.is_connected(_on_turn_number_changed) == false:
				game_manager.turn_number_changed.connect(_on_turn_number_changed)
	
	refresh()


func refresh() -> void:

	
	if self == null:
		return
	
	if game_manager == null:
		self.text = label_prefix + "1"
		return
	
	var turn_number:int = int(game_manager.get("current_turn_number"))
	self.text = label_prefix + str(turn_number)


func _on_turn_number_changed(_turn_number:int) -> void:
	UIJuice.play(self, UIJuice.create_pulse_preset())
	refresh()
