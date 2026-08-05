extends Control

const TOKEN_LOBBY_SCENE_PATH:String = "res://Scenes/User Interface/Token Lobby/token_lobby.tscn"

const NAVY_TEXT_COLOR:Color = Color(0.02745098, 0.15686275, 0.29803923, 1.0)
const SELECTED_TEXT_COLOR:Color = Color.WHITE

const NORMAL_STATUS_COLOR:Color = Color(0.101960786, 0.18431373, 0.32156864, 1.0)
const ERROR_STATUS_COLOR:Color = Color(0.78, 0.12, 0.16, 1.0)

const ENABLED_FORM_MODULATE:Color = Color.WHITE
const DISABLED_FIELD_MODULATE:Color = Color(1.0, 1.0, 1.0, 0.55)

const CREATE_BUTTON_TEXT:String = "Create Lobby"
const CREATING_BUTTON_TEXT:String = "Creating..."

@onready var cancel_button:Button = find_child("Cancel Button", true, false) as Button
@onready var create_lobby_button:Button = find_child("Create Lobby Button", true, false) as Button

@onready var lobby_name_line_edit:LineEdit = find_child("Lobby Name Edit Field", true, false) as LineEdit
@onready var lobby_description_line_edit:LineEdit = find_child("Lobby Description Edit Field", true, false) as LineEdit

@onready var public_button:Button = find_child("Public Button", true, false) as Button
@onready var friends_button:Button = find_child("Friends Button", true, false) as Button
@onready var password_protected_button:Button = find_child("Password Protected Button", true, false) as Button

@onready var password_line_edit:LineEdit = find_child("Password Edit Lineedit", true, false) as LineEdit
@onready var password_visibility_button:TextureButton = find_child("Secret Password Visibility", true, false) as TextureButton

@onready var status_label:Label = find_child("Lobby Creation Status Label", true, false) as Label

@onready var popup_juice_player:UIJuicePlayer = %UIJuicePlayer
@onready var backdrop:MenuBackdrop = $Backdrop

var is_closing:bool = false
var is_creating_lobby:bool = false
var form_is_enabled:bool = true

var pending_exit_animations:int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MenuBackdrop.CLOSABLE_MENU_GROUP)
	
	connect_button(cancel_button, Callable(self, "_on_cancel_button_pressed"), "Cancel Button")
	connect_button(create_lobby_button, Callable(self, "_on_create_lobby_button_pressed"), "Create Lobby Button")
	
	connect_button(public_button, Callable(self, "_on_visibility_button_pressed"), "Public Button")
	connect_button(friends_button, Callable(self, "_on_visibility_button_pressed"), "Friends Button")
	connect_button(password_protected_button, Callable(self, "_on_visibility_button_pressed"), "Password Protected Button")
	
	connect_steam_network_signals()
	setup_password_visibility()
	setup_default_lobby_name()
	
	update_visibility_button_text_colours()
	update_password_field_state()
	clear_status_message()


func connect_button(button:Button, callback:Callable, button_name:String) -> void:
	if button == null:
		push_error("HostMenu: Could not find " + button_name + ".")
		return
	
	if button.pressed.is_connected(callback):
		return
	
	button.pressed.connect(callback)


func connect_steam_network_signals() -> void:
	if SteamNetwork.lobby_created.is_connected(_on_lobby_created) == false:
		SteamNetwork.lobby_created.connect(_on_lobby_created)
	
	if SteamNetwork.lobby_creation_failed.is_connected(_on_lobby_creation_failed) == false:
		SteamNetwork.lobby_creation_failed.connect(_on_lobby_creation_failed)


func setup_default_lobby_name() -> void:
	if lobby_name_line_edit == null:
		return
	
	if lobby_name_line_edit.text.strip_edges() != "":
		return
	
	var persona_name:String = SteamNetwork.get_local_persona_name().strip_edges()
	
	if persona_name == "":
		return
	
	lobby_name_line_edit.text = persona_name + "'s Lobby"


func setup_password_visibility() -> void:
	if password_line_edit == null:
		push_error("HostMenu: Could not find Password Edit Lineedit.")
		return
	
	if password_visibility_button == null:
		push_error("HostMenu: Could not find Secret Password Visibility.")
		return
	
	var callback:Callable = Callable(self, "_on_password_visibility_toggled")
	
	if password_visibility_button.toggled.is_connected(callback) == false:
		password_visibility_button.toggled.connect(callback)
	
	update_password_visibility(password_visibility_button.button_pressed)


func _on_password_visibility_toggled(is_pressed:bool) -> void:
	update_password_visibility(is_pressed)


func update_password_visibility(should_be_secret:bool) -> void:
	if password_line_edit == null:
		return
	
	password_line_edit.secret = should_be_secret


func _on_visibility_button_pressed() -> void:
	call_deferred("update_visibility_controls")


func update_visibility_controls() -> void:
	update_visibility_button_text_colours()
	update_password_field_state()
	clear_status_message()


func update_visibility_button_text_colours() -> void:
	var visibility_buttons:Array[Button] = [
		public_button,
		friends_button,
		password_protected_button
	]
	
	for button in visibility_buttons:
		if button == null:
			continue
		
		var text_colour:Color = NAVY_TEXT_COLOR
		
		if button.button_pressed:
			text_colour = SELECTED_TEXT_COLOR
		
		var label_nodes:Array[Node] = button.find_children("*", "Label", true, false)
		
		for label_node in label_nodes:
			var label:Label = label_node as Label
			
			if label == null:
				continue
			
			if label.label_settings == null:
				continue
			
			label.label_settings.font_color = text_colour


func update_password_field_state() -> void:
	var password_is_required:bool = false
	
	if password_protected_button != null:
		password_is_required = password_protected_button.button_pressed
	
	if password_line_edit != null:
		password_line_edit.editable = form_is_enabled and password_is_required
		
		if password_is_required:
			password_line_edit.modulate = ENABLED_FORM_MODULATE
		else:
			password_line_edit.modulate = DISABLED_FIELD_MODULATE
	
	if password_visibility_button != null:
		password_visibility_button.disabled = form_is_enabled == false or password_is_required == false
		
		if password_is_required:
			password_visibility_button.modulate = ENABLED_FORM_MODULATE
		else:
			password_visibility_button.modulate = DISABLED_FIELD_MODULATE


func _on_create_lobby_button_pressed() -> void:
	if is_creating_lobby:
		return
	
	if is_closing:
		return
	
	clear_status_message()
	
	var validation_message:String = validate_lobby_form()
	
	if validation_message != "":
		show_status_message(validation_message, true)
		return
	
	if SteamNetwork.is_steam_initialised() == false:
		show_status_message("Steam is not available.", true)
		return
	
	var lobby_name:String = lobby_name_line_edit.text.strip_edges()
	var lobby_description:String = lobby_description_line_edit.text.strip_edges()
	var access_type:int = get_selected_access_type()
	var password:String = ""
	
	if access_type == SteamNetwork.LOBBY_ACCESS.PASSWORD_PROTECTED:
		password = password_line_edit.text
	
	is_creating_lobby = true
	set_form_enabled(false)
	show_status_message("Creating Steam lobby...", false)
	
	var creation_started:bool = SteamNetwork.create_lobby(lobby_name, lobby_description, access_type, password)
	
	if creation_started:
		return
	
	is_creating_lobby = false
	set_form_enabled(true)
	show_status_message("The lobby could not be created.", true)


func validate_lobby_form() -> String:
	if lobby_name_line_edit == null:
		return "The lobby name field could not be found."
	
	var lobby_name:String = lobby_name_line_edit.text.strip_edges()
	
	if lobby_name == "":
		lobby_name_line_edit.grab_focus()
		return "Enter a lobby name."
	
	if password_protected_button != null:
		if password_protected_button.button_pressed:
			if password_line_edit == null:
				return "The password field could not be found."
			
			if password_line_edit.text == "":
				password_line_edit.grab_focus()
				return "Enter a password for this lobby."
	
	return ""


func get_selected_access_type() -> int:
	if friends_button != null:
		if friends_button.button_pressed:
			return SteamNetwork.LOBBY_ACCESS.FRIENDS
	
	if password_protected_button != null:
		if password_protected_button.button_pressed:
			return SteamNetwork.LOBBY_ACCESS.PASSWORD_PROTECTED
	
	return SteamNetwork.LOBBY_ACCESS.PUBLIC


func _on_lobby_created(lobby_id:int) -> void:
	if is_creating_lobby == false:
		return
	
	show_status_message("Lobby created. Opening token selection...", false)
	
	if MatchData.config != null:
		MatchData.config.set_player_name(0, SteamNetwork.get_local_persona_name())
	
	var change_error:Error = get_tree().change_scene_to_file(TOKEN_LOBBY_SCENE_PATH)
	
	if change_error == OK:
		return
	
	SteamNetwork.leave_lobby("The token lobby scene could not be opened.")
	
	is_creating_lobby = false
	set_form_enabled(true)
	show_status_message("Lobby %d was created, but token selection could not be opened." % lobby_id, true)
	
	push_error(
		"HostMenu: Could not change to the token lobby scene. Error code: " +
		str(change_error)
	)


func _on_lobby_creation_failed(message:String) -> void:
	if is_creating_lobby == false:
		return
	
	is_creating_lobby = false
	set_form_enabled(true)
	show_status_message(message, true)


func set_form_enabled(is_enabled:bool) -> void:
	form_is_enabled = is_enabled
	
	if cancel_button != null:
		cancel_button.disabled = is_enabled == false
	
	if create_lobby_button != null:
		create_lobby_button.disabled = is_enabled == false
		
		if is_enabled:
			create_lobby_button.text = CREATE_BUTTON_TEXT
		else:
			create_lobby_button.text = CREATING_BUTTON_TEXT
	
	if lobby_name_line_edit != null:
		lobby_name_line_edit.editable = is_enabled
	
	if lobby_description_line_edit != null:
		lobby_description_line_edit.editable = is_enabled
	
	if public_button != null:
		public_button.disabled = is_enabled == false
	
	if friends_button != null:
		friends_button.disabled = is_enabled == false
	
	if password_protected_button != null:
		password_protected_button.disabled = is_enabled == false
	
	update_password_field_state()
	
	if backdrop != null:
		if is_enabled:
			backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_status_message(message:String, is_error:bool) -> void:
	if status_label == null:
		if is_error:
			push_warning("HostMenu: " + message)
		else:
			print("[HostMenu] " + message)
		
		return
	
	status_label.text = message
	status_label.visible = message != ""
	
	if is_error:
		status_label.modulate = ERROR_STATUS_COLOR
	else:
		status_label.modulate = NORMAL_STATUS_COLOR


func clear_status_message() -> void:
	if status_label == null:
		return
	
	status_label.text = ""
	status_label.visible = false


func _on_cancel_button_pressed() -> void:
	if is_creating_lobby:
		return
	
	close_menu()


func close_menu() -> void:
	if is_closing:
		return
	
	if is_creating_lobby:
		return
	
	is_closing = true
	disable_menu_input()
	play_exit_animations()


func force_close_menu() -> void:
	if is_queued_for_deletion():
		return
	
	if is_creating_lobby:
		return
	
	is_closing = true
	queue_free()


func disable_menu_input() -> void:
	form_is_enabled = false
	
	if cancel_button != null:
		cancel_button.disabled = true
	
	if create_lobby_button != null:
		create_lobby_button.disabled = true
	
	if lobby_name_line_edit != null:
		lobby_name_line_edit.editable = false
	
	if lobby_description_line_edit != null:
		lobby_description_line_edit.editable = false
	
	if public_button != null:
		public_button.disabled = true
	
	if friends_button != null:
		friends_button.disabled = true
	
	if password_protected_button != null:
		password_protected_button.disabled = true
	
	if password_visibility_button != null:
		password_visibility_button.disabled = true
	
	if password_line_edit != null:
		password_line_edit.editable = false
	
	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE


func play_exit_animations() -> void:
	var exit_players:Array[UIJuicePlayer] = []
	
	if popup_juice_player != null:
		exit_players.append(popup_juice_player)
	
	if backdrop != null:
		if backdrop.juice_player != null:
			exit_players.append(backdrop.juice_player)
	
	pending_exit_animations = exit_players.size()
	
	if pending_exit_animations <= 0:
		queue_free()
		return
	
	for exit_player in exit_players:
		exit_player.exit_finished.connect(_on_exit_animation_finished, CONNECT_ONE_SHOT)
		exit_player.exit()


func _on_exit_animation_finished() -> void:
	pending_exit_animations = max(pending_exit_animations - 1, 0)
	
	if pending_exit_animations > 0:
		return
	
	queue_free()
