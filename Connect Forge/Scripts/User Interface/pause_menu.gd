class_name PauseMenu
extends Control

signal opened
signal closed


enum MenuContext {
	TOKEN_LOBBY,
	GAME_BOARD
}

const MAIN_MENU_SCENE_PATH:String = "res://Scenes/User Interface/main_menu.tscn"

const RED_TOKEN_PALETTE:ColorPalette = preload("res://Scenes/Tokens/token colour resources/red_v3.tres")

@export_group("Context")
@export var menu_context:MenuContext = MenuContext.TOKEN_LOBBY

@export_group("Opening")
@export var toggle_button:BaseButton
@export var pause_input_action:StringName = &"ui_cancel"

@onready var resume_button:Button = %ResumeButton
@onready var token_codex_button:Button = %TokenCodex
@onready var options_button:Button = %OptionsButton
@onready var back_to_lobby_button:Button = %BackToLobbyButton
@onready var main_menu_button:Button = %MainMenuButton
@onready var quit_button:Button = %QuitButton
@onready var token_visual_display:TokenVisualDisplay = %TokenVisualDisplay

@onready var popup_juice_player:UIJuicePlayer = %UIJuicePlayer
@onready var backdrop:MenuBackdrop = $Backdrop

var is_open:bool = false
var is_transitioning:bool = false

var controls_tree_pause:bool = false
var tree_was_paused:bool = false

var pending_transition_players:int = 0
var transition_is_opening:bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MenuBackdrop.CLOSABLE_MENU_GROUP)
	
	connect_button(resume_button, _on_resume_button_pressed)
	connect_button(token_codex_button, _on_token_codex_button_pressed)
	connect_button(options_button, _on_options_button_pressed)
	connect_button(main_menu_button, _on_main_menu_button_pressed)
	connect_button(back_to_lobby_button, _on_back_to_lobby_button_pressed)
	connect_button(quit_button, _on_quit_button_pressed)
	
	setup(toggle_button)
	apply_menu_context()
	setup_pause_token_visual()
	hide_menu_instant()


func _exit_tree() -> void:
	restore_tree_pause()


func setup(new_toggle_button:BaseButton) -> void:
	if toggle_button != null and is_instance_valid(toggle_button):
		if toggle_button.pressed.is_connected(_on_toggle_button_pressed):
			toggle_button.pressed.disconnect(_on_toggle_button_pressed)
	
	toggle_button = new_toggle_button
	
	if toggle_button == null:
		return
	
	if toggle_button.pressed.is_connected(_on_toggle_button_pressed) == false:
		toggle_button.pressed.connect(_on_toggle_button_pressed)


func connect_button(button:BaseButton, function:Callable) -> void:
	if button == null:
		return
	
	if button.pressed.is_connected(function) == false:
		button.pressed.connect(function)


func set_menu_context(new_context:MenuContext) -> void:
	menu_context = new_context
	
	if is_node_ready():
		apply_menu_context()


func apply_menu_context() -> void:
	var is_game_board_menu:bool = menu_context == MenuContext.GAME_BOARD
	
	if resume_button != null:
		resume_button.visible = is_game_board_menu
		
		if is_game_board_menu:
			resume_button.focus_mode = Control.FOCUS_ALL
		else:
			resume_button.focus_mode = Control.FOCUS_NONE
	
	if main_menu_button != null:
		main_menu_button.visible = true
		main_menu_button.focus_mode = Control.FOCUS_ALL
	
	if back_to_lobby_button != null:
		back_to_lobby_button.visible = true
		back_to_lobby_button.focus_mode = Control.FOCUS_ALL
		back_to_lobby_button.disabled = false
	
	if quit_button != null:
		quit_button.visible = true
		quit_button.focus_mode = Control.FOCUS_ALL


func setup_pause_token_visual() -> void:
	if token_visual_display == null:
		return
	
	token_visual_display.setup_with_palette(TokenLibrary.TokenType.BASIC, -1, RED_TOKEN_PALETTE)


func open_menu() -> void:
	if is_open:
		return
	
	if is_transitioning:
		return
	
	MenuBackdrop.close_all_menus(get_tree(), self)
	
	is_open = true
	is_transitioning = true
	
	pause_scene_tree_if_required()
	
	visible = true
	start_transition(true)


func close_menu() -> void:
	if is_open == false:
		return
	
	if is_transitioning:
		return
	
	is_open = false
	is_transitioning = true
	
	start_transition(false)


func toggle_menu() -> void:
	if is_transitioning:
		return
	
	if is_open:
		close_menu()
		return
	
	open_menu()


func hide_menu_instant() -> void:
	is_open = false
	is_transitioning = false
	pending_transition_players = 0
	
	if popup_juice_player != null:
		popup_juice_player.hide_instant()
	
	if backdrop != null:
		backdrop.hide_instant()
	
	visible = false
	restore_tree_pause()


func start_transition(opening:bool) -> void:
	transition_is_opening = opening
	
	var transition_players:Array[UIJuicePlayer] = get_transition_players()
	pending_transition_players = transition_players.size()
	
	if pending_transition_players <= 0:
		finish_transition()
		return
	
	for player in transition_players:
		if opening:
			player.enter_finished.connect(_on_transition_player_finished, CONNECT_ONE_SHOT)
		else:
			player.exit_finished.connect(_on_transition_player_finished, CONNECT_ONE_SHOT)
	
	for player in transition_players:
		if opening:
			player.enter()
		else:
			player.exit()


func get_transition_players() -> Array[UIJuicePlayer]:
	var players:Array[UIJuicePlayer] = []
	
	if backdrop != null:
		if backdrop.juice_player != null:
			players.append(backdrop.juice_player)
	
	if popup_juice_player != null:
		players.append(popup_juice_player)
	
	return players


func _on_transition_player_finished() -> void:
	pending_transition_players -= 1
	
	if pending_transition_players > 0:
		return
	
	finish_transition()


func finish_transition() -> void:
	pending_transition_players = 0
	is_transitioning = false
	
	if transition_is_opening:
		if resume_button != null and resume_button.visible:
			resume_button.call_deferred("grab_focus")
		elif token_codex_button != null:
			token_codex_button.call_deferred("grab_focus")
		
		opened.emit()
		return
	
	visible = false
	restore_tree_pause()
	closed.emit()


func pause_scene_tree_if_required() -> void:
	if menu_context != MenuContext.GAME_BOARD:
		return
	
	if controls_tree_pause:
		return
	
	tree_was_paused = get_tree().paused
	controls_tree_pause = true
	get_tree().paused = true


func restore_tree_pause() -> void:
	if controls_tree_pause == false:
		return
	
	controls_tree_pause = false
	get_tree().paused = tree_was_paused


func _unhandled_input(event:InputEvent) -> void:
	if pause_input_action == &"":
		return
	
	if event.is_action_pressed(pause_input_action) == false:
		return
	
	if event is InputEventKey:
		var key_event:InputEventKey = event as InputEventKey
		
		if key_event.echo:
			return
	
	toggle_menu()
	get_viewport().set_input_as_handled()


func _on_toggle_button_pressed() -> void:
	toggle_menu()


func _on_resume_button_pressed() -> void:
	close_menu()


func _on_token_codex_button_pressed() -> void:
	pass


func _on_options_button_pressed() -> void:
	pass


func _on_back_to_lobby_button_pressed() -> void:
	if menu_context == MenuContext.TOKEN_LOBBY:
		close_menu()
		return
	
	if back_to_lobby_button != null:
		back_to_lobby_button.disabled = true
	
	controls_tree_pause = false
	get_tree().paused = false
	
	var return_started:bool = MultiplayerMatchFlow.request_return_to_lobby("Pause menu")
	
	if return_started:
		return
	
	DebugOverlay.log_warning("PauseMenu", "The return-to-lobby request could not be started.")
	
	if back_to_lobby_button != null:
		back_to_lobby_button.disabled = false
	
	if menu_context == MenuContext.GAME_BOARD:
		controls_tree_pause = true
		get_tree().paused = true


func _on_main_menu_button_pressed() -> void:
	change_to_main_menu()


func change_to_main_menu() -> void:
	var previous_tree_pause:bool = tree_was_paused
	
	controls_tree_pause = false
	get_tree().paused = false
	
	if SteamNetwork.is_in_lobby():
		SteamNetwork.leave_lobby("Returned to the main menu.")
	
	MatchData.clear_session()
	
	var scene_change_error:Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	
	if scene_change_error == OK:
		return
	
	push_error("PauseMenu: Could not return to the main menu. Error code: " + str(scene_change_error))
	
	tree_was_paused = previous_tree_pause
	
	if menu_context == MenuContext.GAME_BOARD:
		controls_tree_pause = true
		get_tree().paused = true


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func force_close_menu() -> void:
	hide_menu_instant()
