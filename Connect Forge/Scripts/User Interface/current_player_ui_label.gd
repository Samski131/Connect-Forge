class_name CurrentPlayerLabelUI
extends EffectControl

var game_manager:Node = null


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	
	if game_manager != null:
		if game_manager.has_signal("current_player_changed"):
			if game_manager.current_player_changed.is_connected(_on_current_player_changed) == false:
				game_manager.current_player_changed.connect(_on_current_player_changed)
		
		if game_manager.has_signal("player_names_changed"):
			if game_manager.player_names_changed.is_connected(_on_player_names_changed) == false:
				game_manager.player_names_changed.connect(_on_player_names_changed)
	
	refresh()


func refresh() -> void:
	if game_manager == null:
		self.text = "Player's Turn"
		add_theme_color_override("font_color", Color.WHITE)
		return
	
	var player_id:int = game_manager.current_player_id
	var player_name:String = get_display_player_name(player_id)
	var player_color:Color = get_player_color(player_id)
	
	self.text = player_name + "'s Turn"
	add_theme_color_override("font_color", player_color)


func get_display_player_name(player_id:int) -> String:
	if game_manager == null:
		return "Player"
	
	if player_id < 0:
		return "Player"
	
	if player_id >= game_manager.player_names.size():
		return "Player"
	
	var player_name:String = str(game_manager.player_names[player_id]).strip_edges()
	
	if player_name == "":
		return "Player"
	
	return player_name


func get_player_color(player_id:int) -> Color:
	if game_manager == null:
		return Color.WHITE
	
	if player_id < 0:
		return Color.WHITE
	
	if player_id >= game_manager.player_colours.size():
		return Color.WHITE
	
	var palette:ColorPalette = game_manager.player_colours[player_id]
	
	if palette == null:
		return Color.WHITE
	
	if palette.colors.size() < 3:
		return Color.WHITE
	
	return palette.colors[2]


func _on_current_player_changed(_player_id:int) -> void:
	queue_ui_effect(UIPulseEffect.new(get_parent()))
	refresh()


func _on_player_names_changed() -> void:
	refresh()
