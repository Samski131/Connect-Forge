class_name MultiplayerDisconnectPopup
extends Control

const MAIN_MENU_SCENE_PATH:String = "res://Scenes/User Interface/main_menu.tscn"

@onready var return_to_main_menu_button:Button = find_child("ReturnToMainMenuButton", true, false) as Button
@onready var popup_juice_player:UIJuicePlayer = %UIJuicePlayer
@onready var backdrop:MenuBackdrop = $Backdrop

var scene_change_requested:bool = false
var popup_is_open:bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if return_to_main_menu_button == null:
		push_error("MultiplayerDisconnectPopup: Could not find ReturnToMainMenuButton.")
	else:
		if return_to_main_menu_button.pressed.is_connected(_on_return_to_main_menu_button_pressed) == false:
			return_to_main_menu_button.pressed.connect(_on_return_to_main_menu_button_pressed)
	
	hide_instant()


func show_host_disconnected() -> void:
	if popup_is_open:
		return
	
	popup_is_open = true
	scene_change_requested = false
	visible = true
	
	if return_to_main_menu_button != null:
		return_to_main_menu_button.disabled = false
	
	if backdrop != null:
		backdrop.enter()
	
	if popup_juice_player != null:
		popup_juice_player.enter()


func hide_instant() -> void:
	popup_is_open = false
	
	if backdrop != null:
		backdrop.hide_instant()
	
	if popup_juice_player != null:
		popup_juice_player.hide_instant()


func _on_return_to_main_menu_button_pressed() -> void:
	if scene_change_requested:
		return
	
	scene_change_requested = true
	
	if return_to_main_menu_button != null:
		return_to_main_menu_button.disabled = true
	
	get_tree().paused = false
	
	if SteamNetwork.is_in_lobby():
		SteamNetwork.leave_lobby("Returned to the main menu after the host disconnected.")
	
	MatchData.clear_session()
	
	var scene_change_error:Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	
	if scene_change_error == OK:
		return
	
	scene_change_requested = false
	
	if return_to_main_menu_button != null:
		return_to_main_menu_button.disabled = false
	
	push_error("MultiplayerDisconnectPopup: Could not return to the main menu. Error code: " + str(scene_change_error))
