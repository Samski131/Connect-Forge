class_name CurrentPlayerLabelUI
extends Label

const PLAYER_COLOUR_INDEX:int = 2

var game_manager:Node = null


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	connect_game_manager_signals()
	refresh()


func connect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.has_signal("current_player_changed"):
		if game_manager.current_player_changed.is_connected(_on_current_player_changed) == false:
			game_manager.current_player_changed.connect(_on_current_player_changed)
	
	if game_manager.has_signal("player_names_changed"):
		if game_manager.player_names_changed.is_connected(_on_player_names_changed) == false:
			game_manager.player_names_changed.connect(_on_player_names_changed)
	
	if game_manager.has_signal("players_changed"):
		if game_manager.players_changed.is_connected(_on_players_changed) == false:
			game_manager.players_changed.connect(_on_players_changed)


func refresh() -> void:
	if game_manager == null:
		text = "Player's Turn"
		add_theme_color_override("font_color", Color.WHITE)
		return
	
	var player_id:int = game_manager.current_player_id
	var player_name:String = get_display_player_name(player_id)
	var player_color:Color = get_player_color(player_id)
	
	text = player_name + "'s Turn"
	add_theme_color_override("font_color", player_color)


func get_display_player_name(player_id:int) -> String:
	if game_manager == null:
		return "Player"
	
	if game_manager.has_method("is_valid_player_id"):
		if game_manager.is_valid_player_id(player_id) == false:
			return "Player"
	elif player_id < 0:
		return "Player"
	
	if game_manager.has_method("get_player_name") == false:
		return "Player"
	
	var player_name:String = str(game_manager.get_player_name(player_id)).strip_edges()
	
	if player_name == "":
		return "Player"
	
	return player_name


func get_player_color(player_id:int) -> Color:
	if game_manager == null:
		return Color.WHITE
	
	if game_manager.has_method("is_valid_player_id"):
		if game_manager.is_valid_player_id(player_id) == false:
			return Color.WHITE
	elif player_id < 0:
		return Color.WHITE
	
	if game_manager.has_method("get_player_palette") == false:
		return Color.WHITE
	
	var palette:ColorPalette = game_manager.get_player_palette(player_id)
	
	if palette == null:
		return Color.WHITE
	
	if palette.colors.size() <= PLAYER_COLOUR_INDEX:
		return Color.WHITE
	
	return palette.colors[PLAYER_COLOUR_INDEX]


func _on_current_player_changed(_player_id:int) -> void:
	UIJuice.play(self, UIJuice.create_pulse_preset())
	refresh()


func _on_player_names_changed() -> void:
	refresh()


func _on_players_changed() -> void:
	refresh()
