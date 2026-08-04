class_name HostMenu
extends Control

const NAVY_TEXT_COLOR:Color = Color(0.02745098, 0.15686275, 0.29803923, 1.0)
const SELECTED_TEXT_COLOR:Color = Color.WHITE

@onready var cancel_button:Button = find_child("Cancel Button", true, false) as Button
@onready var create_lobby_button:Button = find_child("Create Lobby Button", true, false) as Button

@onready var public_button:Button = find_child("Public Button", true, false) as Button
@onready var friends_button:Button = find_child("Friends Button", true, false) as Button
@onready var private_button:Button = find_child("Private Button", true, false) as Button

@onready var password_line_edit:LineEdit = find_child("Password Edit Lineedit", true, false) as LineEdit
@onready var password_visibility_button:TextureButton = find_child("Secret Password Visibility", true, false) as TextureButton

@onready var popup_juice_player:UIJuicePlayer = %UIJuicePlayer
@onready var backdrop:MenuBackdrop = $Backdrop

var is_closing:bool = false
var pending_exit_animations:int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MenuBackdrop.CLOSABLE_MENU_GROUP)
	
	connect_button(cancel_button, Callable(self, "_on_cancel_button_pressed"), "Cancel Button")
	connect_button(public_button, Callable(self, "_on_visibility_button_pressed"), "Public Button")
	connect_button(friends_button, Callable(self, "_on_visibility_button_pressed"), "Friends Button")
	connect_button(private_button, Callable(self, "_on_visibility_button_pressed"), "Private Button")
	
	setup_password_visibility()
	update_visibility_button_text_colours()


func connect_button(button:Button, callback:Callable, button_name:String) -> void:
	if button == null:
		push_error("HostMenu: Could not find " + button_name + ".")
		return
	
	if button.pressed.is_connected(callback):
		return
	
	button.pressed.connect(callback)


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
	call_deferred("update_visibility_button_text_colours")


func update_visibility_button_text_colours() -> void:
	var visibility_buttons:Array[Button] = [
		public_button,
		friends_button,
		private_button
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


func _on_cancel_button_pressed() -> void:
	close_menu()


func close_menu() -> void:
	if is_closing:
		return
	
	is_closing = true
	disable_menu_input()
	play_exit_animations()


func force_close_menu() -> void:
	if is_queued_for_deletion():
		return
	
	is_closing = true
	queue_free()


func disable_menu_input() -> void:
	if cancel_button != null:
		cancel_button.disabled = true
	
	if create_lobby_button != null:
		create_lobby_button.disabled = true
	
	if public_button != null:
		public_button.disabled = true
	
	if friends_button != null:
		friends_button.disabled = true
	
	if private_button != null:
		private_button.disabled = true
	
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
