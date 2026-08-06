class_name GameOverMenu
extends Control

const DEFAULT_PLAYER_SCORE_ROW_SCENE:PackedScene = preload("res://Scenes/User Interface/player_score_row.tscn")
const TOKEN_LOBBY_SCENE_PATH:String = "res://Scenes/User Interface/Token Lobby/token_lobby.tscn"

@export_group("Scenes")
@export var player_score_row_scene:PackedScene = DEFAULT_PLAYER_SCORE_ROW_SCENE

@export_group("Timing")
@export_range(0.0, 20.0, 0.1) var popup_delay_seconds:float = 1.5

@export_group("Palette Indices")
@export var frame_colour_index:int = 2
@export var frame_border_colour_index:int = 0
@export var winner_label_colour_index:int = 2

@onready var popup_root:Control = $PopupCenter/PopupRoot
@onready var winner_token_display:TokenVisualDisplay = $"PopupCenter/PopupRoot/OuterFrame/Token Overlay/Token Visual Display"
@onready var outer_frame:PanelContainer = $PopupCenter/PopupRoot/OuterFrame
@onready var winner_name_label:Label = $"PopupCenter/PopupRoot/OuterFrame/OuterMargin/Inner Panel/ContentMargin/ContentVbox/WinnerLabelHbox/Winner Labels/WinnerNameLabel"
@onready var score_rows:VBoxContainer = $"PopupCenter/PopupRoot/OuterFrame/OuterMargin/Inner Panel/ContentMargin/ContentVbox/ScoreMargin/ScorePanel/ScoreRows"
@onready var next_round_button:Button = $"PopupCenter/PopupRoot/OuterFrame/OuterMargin/Inner Panel/ContentMargin/ContentVbox/VBoxContainer/MarginContainer/Button Hbox/Next Round"
@onready var return_to_lobby_button:Button = $"PopupCenter/PopupRoot/OuterFrame/OuterMargin/Inner Panel/ContentMargin/ContentVbox/VBoxContainer/MarginContainer/Button Hbox/Return to Lobby"
@onready var backdrop:ColorRect = $Backdrop
@onready var popup_juice_player:UIJuicePlayer = $PopupCenter/PopupRoot/UIJuicePlayer
@onready var backdrop_juice_player:UIJuicePlayer = $PopupCenter/PopupRoot/UIJuicePlayerBackdrop

var game_manager:GameManager = null
var winner_id:int = -1
var show_request_id:int = 0


func _ready() -> void:
	if player_score_row_scene == null:
		player_score_row_scene = DEFAULT_PLAYER_SCORE_ROW_SCENE
	
	if next_round_button != null:
		if next_round_button.pressed.is_connected(_on_next_round_pressed) == false:
			next_round_button.pressed.connect(_on_next_round_pressed)
	
	if return_to_lobby_button != null:
		if return_to_lobby_button.pressed.is_connected(_on_return_to_lobby_pressed) == false:
			return_to_lobby_button.pressed.connect(_on_return_to_lobby_pressed)
	
	hide_menu_instant()


func setup(new_game_manager:GameManager) -> void:
	game_manager = new_game_manager
	refresh_network_controls()

func refresh_network_controls() -> void:
	if next_round_button == null:
		return
	
	if return_to_lobby_button == null:
		return
	
	if game_manager == null:
		next_round_button.text = "Next Round"
		next_round_button.disabled = false
		return_to_lobby_button.text = "Return to Lobby"
		return_to_lobby_button.disabled = false
		return
	
	if game_manager.is_network_match_active() == false:
		next_round_button.text = "Next Round"
		next_round_button.disabled = false
		return_to_lobby_button.text = "Return to Lobby"
		return_to_lobby_button.disabled = false
		return
	
	if game_manager.is_network_match_host():
		next_round_button.text = "Next Round"
		next_round_button.disabled = false
	else:
		next_round_button.text = "Waiting for Host"
		next_round_button.disabled = true
	
	return_to_lobby_button.text = "Return to Lobby"
	return_to_lobby_button.disabled = true
	return_to_lobby_button.tooltip_text = "Network return-to-lobby synchronisation will be added in a later stage."
	
func show_game_over(new_winner_id:int) -> void:
	if game_manager == null:
		return
	
	if is_valid_player_id(new_winner_id) == false:
		return
	
	refresh_network_controls()
	
	winner_id = new_winner_id
	show_request_id += 1
	
	var current_request_id:int = show_request_id
	var winner_palette:ColorPalette = get_player_palette(winner_id)
	
	setup_winner_token(winner_palette)
	setup_winner_name(winner_palette)
	setup_outer_frame(winner_palette)
	rebuild_score_rows()
	
	visible = false
	
	if popup_delay_seconds > 0.0:
		await get_tree().create_timer(popup_delay_seconds).timeout
	
	if current_request_id != show_request_id:
		return
	
	if is_inside_tree() == false:
		return
	
	visible = true
	
	if backdrop_juice_player != null:
		backdrop_juice_player.enter()
	elif backdrop != null:
		backdrop.visible = true
		backdrop.modulate.a = 1.0
	
	if popup_juice_player != null:
		popup_juice_player.enter()
	elif popup_root != null:
		popup_root.visible = true
		popup_root.modulate.a = 1.0


func hide_game_over() -> void:
	show_request_id += 1
	
	if visible == false:
		hide_menu_instant()
		return
	
	if backdrop_juice_player != null:
		backdrop_juice_player.exit()
	elif backdrop != null:
		backdrop.visible = false
	
	if popup_juice_player == null:
		hide_menu_instant()
		return
	
	if popup_juice_player.exit_finished.is_connected(_on_popup_exit_finished) == false:
		popup_juice_player.exit_finished.connect(_on_popup_exit_finished, CONNECT_ONE_SHOT)
	
	popup_juice_player.exit()


func _on_popup_exit_finished() -> void:
	visible = false


func hide_menu_instant() -> void:
	show_request_id += 1
	
	if popup_juice_player != null:
		popup_juice_player.hide_instant()
	elif popup_root != null:
		popup_root.visible = false
	
	if backdrop_juice_player != null:
		backdrop_juice_player.hide_instant()
	elif backdrop != null:
		backdrop.visible = false
	
	visible = false


func setup_winner_token(winner_palette:ColorPalette) -> void:
	if winner_token_display == null:
		return
	
	winner_token_display.setup_with_palette(TokenLibrary.TokenType.BASIC, winner_id, winner_palette, false)

func setup_winner_name(winner_palette:ColorPalette) -> void:
	if winner_name_label == null:
		return
	
	winner_name_label.text = get_player_name(winner_id)
	
	var winner_colour:Color = get_palette_colour(winner_palette, winner_label_colour_index, Color.WHITE)
	var current_settings:LabelSettings = winner_name_label.label_settings
	var new_settings:LabelSettings = null
	
	if current_settings == null:
		new_settings = LabelSettings.new()
	else:
		new_settings = current_settings.duplicate() as LabelSettings
	
	if new_settings == null:
		return
	
	new_settings.font_color = winner_colour
	winner_name_label.label_settings = new_settings


func setup_outer_frame(winner_palette:ColorPalette) -> void:
	if outer_frame == null:
		return
	
	var existing_style:StyleBoxFlat = outer_frame.get_theme_stylebox("panel") as StyleBoxFlat
	var frame_style:StyleBoxFlat = null
	
	if existing_style == null:
		frame_style = StyleBoxFlat.new()
	else:
		frame_style = existing_style.duplicate() as StyleBoxFlat
	
	if frame_style == null:
		return
	
	frame_style.bg_color = get_palette_colour(winner_palette, frame_colour_index, Color.WHITE)
	frame_style.border_color = get_palette_colour(winner_palette, frame_border_colour_index, Color.WHITE)
	outer_frame.add_theme_stylebox_override("panel", frame_style)


func rebuild_score_rows() -> void:
	clear_score_rows()
	
	if game_manager == null:
		return
	
	if score_rows == null:
		return
	
	if player_score_row_scene == null:
		player_score_row_scene = DEFAULT_PLAYER_SCORE_ROW_SCENE
	
	if player_score_row_scene == null:
		push_error("GameOverMenu: player_score_row_scene could not be loaded.")
		return
	
	var sorted_player_ids:Array[int] = get_sorted_player_ids()
	var row_count:int = sorted_player_ids.size()
	
	for row_index in range(row_count):
		var player_id:int = sorted_player_ids[row_index]
		var row_position:PlayerScoreRow.RowPosition = get_row_position(row_index, row_count)
		create_score_row(player_id, row_position)


func clear_score_rows() -> void:
	if score_rows == null:
		return
	
	for child in score_rows.get_children():
		score_rows.remove_child(child)
		child.queue_free()


func create_score_row(player_id:int, row_position:PlayerScoreRow.RowPosition) -> void:
	var instantiated_node:Node = player_score_row_scene.instantiate()
	
	if instantiated_node == null:
		push_error("GameOverMenu: Failed to instantiate player score row.")
		return
	
	var new_row:PlayerScoreRow = instantiated_node as PlayerScoreRow
	
	if new_row == null:
		instantiated_node.queue_free()
		push_error("GameOverMenu: player_score_row.tscn root must use PlayerScoreRow.")
		return
	
	score_rows.add_child(new_row)
	
	var player_name:String = get_player_name(player_id)
	var player_score:int = get_player_score(player_id)
	var player_palette:ColorPalette = get_player_palette(player_id)
	var is_winner:bool = player_id == winner_id
	
	new_row.setup(player_id, player_name, player_score, player_palette, is_winner, row_position)


func get_sorted_player_ids() -> Array[int]:
	var player_ids:Array[int] = []
	var player_count:int = get_player_count()
	
	for player_id in range(player_count):
		player_ids.append(player_id)
	
	player_ids.sort_custom(sort_players_by_score)
	return player_ids


func sort_players_by_score(first_player_id:int, second_player_id:int) -> bool:
	var first_score:int = get_player_score(first_player_id)
	var second_score:int = get_player_score(second_player_id)
	
	if first_score == second_score:
		return first_player_id < second_player_id
	
	return first_score > second_score


func get_row_position(row_index:int, row_count:int) -> PlayerScoreRow.RowPosition:
	if row_count <= 1:
		return PlayerScoreRow.RowPosition.ONLY
	
	if row_index == 0:
		return PlayerScoreRow.RowPosition.FIRST
	
	if row_index == row_count - 1:
		return PlayerScoreRow.RowPosition.LAST
	
	return PlayerScoreRow.RowPosition.MIDDLE


func get_player_count() -> int:
	if game_manager == null:
		return 0
	
	return game_manager.get_player_count()


func get_player_name(player_id:int) -> String:
	if game_manager == null:
		return "Player " + str(player_id + 1)
	
	return game_manager.get_player_name(player_id)


func get_player_score(player_id:int) -> int:
	if game_manager == null:
		return 0
	
	return game_manager.get_player_wins(player_id)


func get_player_palette(player_id:int) -> ColorPalette:
	if game_manager == null:
		return null
	
	return game_manager.get_player_palette(player_id)


func get_palette_colour(palette:ColorPalette, colour_index:int, fallback:Color) -> Color:
	if palette == null:
		return fallback
	
	if colour_index < 0:
		return fallback
	
	if colour_index >= palette.colors.size():
		return fallback
	
	return palette.colors[colour_index]


func is_valid_player_id(player_id:int) -> bool:
	if game_manager == null:
		return false
	
	return game_manager.is_valid_player_id(player_id)


func _on_next_round_pressed() -> void:
	if game_manager == null:
		return
	
	if game_manager.is_network_match_active():
		if game_manager.is_network_match_host() == false:
			return
	
	if next_round_button != null:
		next_round_button.disabled = true
	
	var juice_player:UIJuicePlayer = UIJuice.get_or_create_player(popup_root)
	
	if juice_player == null:
		finish_next_round_transition()
		return
	
	if juice_player.exit_finished.is_connected(finish_next_round_transition) == false:
		juice_player.exit_finished.connect(finish_next_round_transition, CONNECT_ONE_SHOT)
	
	juice_player.exit()


func finish_next_round_transition() -> void:
	visible = false
	
	if game_manager == null:
		return
	
	var round_started:bool = game_manager.request_next_round()
	
	if round_started:
		winner_id = -1
		return
	
	refresh_network_controls()
	
	if winner_id >= 0:
		show_game_over(winner_id)


func _on_return_to_lobby_pressed() -> void:
	if game_manager != null:
		if game_manager.is_network_match_active():
			DebugOverlay.log_warning("GameOverMenu", "Network return to lobby is not connected yet.")
			return
		
	if return_to_lobby_button != null:
		return_to_lobby_button.disabled = true
	
	if next_round_button != null:
		next_round_button.disabled = true
	
	var change_error:Error = get_tree().change_scene_to_file(TOKEN_LOBBY_SCENE_PATH)
	
	if change_error == OK:
		MatchData.clear_session()
		return
	
	push_error("GameOverMenu: Could not return to the token lobby. Error code: " + str(change_error))
	
	if return_to_lobby_button != null:
		return_to_lobby_button.disabled = false
	
	if next_round_button != null:
		next_round_button.disabled = false
