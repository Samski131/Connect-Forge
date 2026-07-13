class_name CurrentTurnCardUI
extends PanelContainer

const PLAYER_COLOUR_INDEX:int = 2

@export_group("Timer")
@export var warning_seconds:int = 10

var game_manager:Node = null
var turn_timer:MatchTurnTimer = null
var timer_is_displayed:bool = false
var initial_timer_state_applied:bool = false
var last_warning_second:int = -1

@onready var current_player_label:Label = $"Margin/Text Layout/Current Player Label"
@onready var turn_time_label:Label = $"Margin/Text Layout/Turn Time Label"
@onready var turn_change_juice:UIJuicePlayer = $"Margin/Text Layout/Current Player Label/Turn Change Juice"
@onready var timer_juice:UIJuicePlayer = $"Margin/Text Layout/Turn Time Label/Timer Juice"


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	turn_timer = get_tree().get_first_node_in_group("turn timer") as MatchTurnTimer
	
	connect_game_manager_signals()
	connect_turn_timer_signals()
	refresh_current_player()
	apply_initial_timer_state()


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


func connect_turn_timer_signals() -> void:
	if turn_timer == null:
		return
	
	if turn_timer.timer_enabled_changed.is_connected(_on_timer_enabled_changed) == false:
		turn_timer.timer_enabled_changed.connect(_on_timer_enabled_changed)
	
	if turn_timer.time_changed.is_connected(_on_turn_time_changed) == false:
		turn_timer.time_changed.connect(_on_turn_time_changed)


func apply_initial_timer_state() -> void:
	initial_timer_state_applied = true
	
	if should_display_turn_timer():
		timer_is_displayed = true
		update_turn_timer_text(turn_timer.get_seconds_remaining())
		show_turn_timer_instant()
		return
	
	timer_is_displayed = false
	hide_turn_timer_instant()


func refresh_current_player() -> void:
	if current_player_label == null:
		return
	
	if game_manager == null:
		current_player_label.text = "Player's Turn"
		current_player_label.add_theme_color_override("font_color", Color.WHITE)
		return
	
	var player_id:int = game_manager.current_player_id
	var player_name:String = get_display_player_name(player_id)
	var player_colour:Color = get_player_colour(player_id)
	
	current_player_label.text = player_name + "'s Turn"
	current_player_label.add_theme_color_override("font_color", player_colour)


func refresh_turn_timer() -> void:
	if initial_timer_state_applied == false:
		apply_initial_timer_state()
		return
	
	if should_display_turn_timer() == false:
		hide_turn_timer()
		return
	
	var seconds_remaining:int = turn_timer.get_seconds_remaining()
	
	show_turn_timer()
	update_turn_timer_text(seconds_remaining)
	update_warning_effect(seconds_remaining)


func should_display_turn_timer() -> bool:
	if turn_timer == null:
		return false
	
	if turn_timer.is_timer_enabled() == false:
		return false
	
	if game_manager == null:
		return false
	
	if game_manager.current_turn_phase == Global.TURN_PHASE.GAME_OVER:
		return false
	
	return true


func show_turn_timer() -> void:
	if timer_is_displayed:
		ensure_timer_is_visible()
		return
	
	timer_is_displayed = true
	
	if timer_juice != null:
		timer_juice.enter()
		return
	
	set_timer_label_visible()


func hide_turn_timer() -> void:
	last_warning_second = -1
	
	if timer_is_displayed == false:
		return
	
	timer_is_displayed = false
	
	if timer_juice != null:
		timer_juice.exit()
		return
	
	turn_time_label.visible = false


func show_turn_timer_instant() -> void:
	if timer_juice != null:
		timer_juice.show_instant()
		return
	
	set_timer_label_visible()


func hide_turn_timer_instant() -> void:
	if timer_juice != null:
		timer_juice.hide_instant()
		return
	
	if turn_time_label != null:
		turn_time_label.visible = false


func ensure_timer_is_visible() -> void:
	if turn_time_label == null:
		return
	
	if turn_time_label.visible and turn_time_label.modulate.a > 0.99:
		return
	
	show_turn_timer_instant()


func set_timer_label_visible() -> void:
	if turn_time_label == null:
		return
	
	var visible_modulate:Color = turn_time_label.modulate
	visible_modulate.a = 1.0
	
	turn_time_label.visible = true
	turn_time_label.modulate = visible_modulate


func update_turn_timer_text(seconds_remaining:int) -> void:
	if turn_time_label == null:
		return
	
	if seconds_remaining == 1:
		turn_time_label.text = "Time remaining: 1 second"
		return
	
	turn_time_label.text = "Time remaining: " + str(seconds_remaining) + " seconds"


func update_warning_effect(seconds_remaining:int) -> void:
	if seconds_remaining <= 0:
		clear_warning_effect()
		return
	
	if seconds_remaining > warning_seconds:
		clear_warning_effect()
		return
	
	if seconds_remaining == last_warning_second:
		return
	
	last_warning_second = seconds_remaining
	
	if timer_juice != null:
		timer_juice.play_active()


func clear_warning_effect() -> void:
	if last_warning_second == -1:
		return
	
	last_warning_second = -1
	
	if timer_juice != null:
		timer_juice.show_instant()


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


func get_player_colour(player_id:int) -> Color:
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
	refresh_current_player()
	clear_warning_effect()
	refresh_turn_timer()
	
	if turn_change_juice != null:
		turn_change_juice.play_active()


func _on_player_names_changed() -> void:
	refresh_current_player()


func _on_players_changed() -> void:
	refresh_current_player()


func _on_timer_enabled_changed(_enabled:bool) -> void:
	refresh_turn_timer()


func _on_turn_time_changed(_seconds_remaining:int, _total_seconds:int) -> void:
	refresh_turn_timer()
