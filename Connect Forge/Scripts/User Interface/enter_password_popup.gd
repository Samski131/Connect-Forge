class_name EnterPasswordPopup
extends Control

signal password_submitted(password:String)
signal cancelled
signal closed

const INVALID_FEEDBACK_PRESET:UIJuicePreset = preload("res://Assets/User Interface/Resources/Feedback/invalid_shake.tres")

@onready var title_label:Label = find_child("TitleLabel", true, false) as Label
@onready var password_line_edit:LineEdit = find_child("Password Edit Lineedit", true, false) as LineEdit
@onready var password_visibility_button:TextureButton = find_child("Secret Password Visibility", true, false) as TextureButton
@onready var cancel_button:Button = find_child("Cancel Button", true, false) as Button

@onready var popup_juice_player:UIJuicePlayer = %UIJuicePlayer
@onready var backdrop:MenuBackdrop = $Backdrop

var join_game_button:Button = null

var is_closing:bool = false
var is_busy:bool = false
var is_closing_after_success:bool = false
var cancellation_has_been_emitted:bool = false

var pending_exit_animations:int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MenuBackdrop.CLOSABLE_MENU_GROUP)
	
	join_game_button = _find_join_game_button()
	
	_connect_button(cancel_button, _on_cancel_button_pressed, "Cancel Button")
	_connect_button(join_game_button, _on_join_game_button_pressed, "Join Game Button")
	
	_setup_password_line_edit()
	_setup_password_visibility()
	_setup_invalid_feedback()
	set_busy(false)


func _find_join_game_button() -> Button:
	var button:Button = find_child("Join Game Button", true, false) as Button
	
	if button != null:
		return button
	
	return find_child("Create Lobby Button", true, false) as Button


func _connect_button(button:BaseButton, callback:Callable, button_name:String) -> void:
	if button == null:
		push_error("EnterPasswordPopup: Could not find " + button_name + ".")
		return
	
	if button.pressed.is_connected(callback):
		return
	
	button.pressed.connect(callback)


func _setup_password_line_edit() -> void:
	if password_line_edit == null:
		push_error("EnterPasswordPopup: Could not find Password Edit Lineedit.")
		return
	
	if password_line_edit.text_submitted.is_connected(_on_password_text_submitted) == false:
		password_line_edit.text_submitted.connect(_on_password_text_submitted)


func _setup_password_visibility() -> void:
	if password_line_edit == null:
		return
	
	if password_visibility_button == null:
		push_error("EnterPasswordPopup: Could not find Secret Password Visibility.")
		return
	
	if password_visibility_button.toggled.is_connected(_on_password_visibility_toggled) == false:
		password_visibility_button.toggled.connect(_on_password_visibility_toggled)
	
	password_visibility_button.set_pressed_no_signal(true)
	_update_password_visibility(true)


func _setup_invalid_feedback() -> void:
	if popup_juice_player == null:
		push_error("EnterPasswordPopup: Could not find UIJuicePlayer.")
		return
	
	popup_juice_player.invalid_preset = INVALID_FEEDBACK_PRESET


func open_popup(_lobby_name:String = "") -> void:
	is_closing = false
	is_busy = false
	is_closing_after_success = false
	cancellation_has_been_emitted = false
	
	if title_label != null:
		title_label.text = "Enter Password"
	
	if password_line_edit != null:
		password_line_edit.text = ""
	
	if password_visibility_button != null:
		password_visibility_button.set_pressed_no_signal(true)
	
	_update_password_visibility(true)
	set_busy(false)
	
	if popup_juice_player != null:
		popup_juice_player.enter()
	
	if backdrop != null:
		backdrop.enter()
	
	focus_password_field()


func focus_password_field() -> void:
	if password_line_edit == null:
		return
	
	password_line_edit.call_deferred("grab_focus")


func _on_password_visibility_toggled(should_be_secret:bool) -> void:
	_update_password_visibility(should_be_secret)


func _update_password_visibility(should_be_secret:bool) -> void:
	if password_line_edit == null:
		return
	
	password_line_edit.secret = should_be_secret


func _on_password_text_submitted(_submitted_text:String) -> void:
	_submit_password()


func _on_join_game_button_pressed() -> void:
	_submit_password()


func _submit_password() -> void:
	if is_closing:
		return
	
	if is_busy:
		return
	
	if password_line_edit == null:
		return
	
	var password:String = password_line_edit.text
	
	if password == "":
		show_invalid_feedback()
		return
	
	set_busy(true)
	password_submitted.emit(password)


func show_invalid_feedback() -> void:
	if is_closing:
		return
	
	set_busy(false)
	
	if password_line_edit != null:
		password_line_edit.text = ""
	
	if popup_juice_player != null:
		popup_juice_player.play_invalid()
	
	focus_password_field()


func set_busy(should_be_busy:bool) -> void:
	is_busy = should_be_busy
	
	if password_line_edit != null:
		password_line_edit.editable = should_be_busy == false
	
	if password_visibility_button != null:
		password_visibility_button.disabled = should_be_busy
	
	if join_game_button != null:
		join_game_button.disabled = should_be_busy
	
	if cancel_button != null:
		cancel_button.disabled = false
	
	if join_game_button != null:
		if should_be_busy:
			join_game_button.text = "Joining..."
		else:
			join_game_button.text = "Join Game"


func _on_cancel_button_pressed() -> void:
	close_menu()


func close_after_success() -> void:
	if is_closing:
		return
	
	is_closing_after_success = true
	close_menu()


func close_menu() -> void:
	if is_closing:
		return
	
	is_closing = true
	
	if is_closing_after_success == false:
		_emit_cancelled_once()
	
	_disable_input()
	_play_exit_animations()


func force_close_menu() -> void:
	if is_queued_for_deletion():
		return
	
	if is_closing_after_success == false:
		_emit_cancelled_once()
	
	is_closing = true
	closed.emit()
	queue_free()


func _emit_cancelled_once() -> void:
	if cancellation_has_been_emitted:
		return
	
	cancellation_has_been_emitted = true
	cancelled.emit()


func _disable_input() -> void:
	if password_line_edit != null:
		password_line_edit.editable = false
	
	if password_visibility_button != null:
		password_visibility_button.disabled = true
	
	if cancel_button != null:
		cancel_button.disabled = true
	
	if join_game_button != null:
		join_game_button.disabled = true
	
	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _play_exit_animations() -> void:
	var exit_players:Array[UIJuicePlayer] = []
	
	if popup_juice_player != null:
		exit_players.append(popup_juice_player)
	
	if backdrop != null:
		if backdrop.juice_player != null:
			exit_players.append(backdrop.juice_player)
	
	pending_exit_animations = exit_players.size()
	
	if pending_exit_animations <= 0:
		_finish_closing()
		return
	
	for exit_player in exit_players:
		exit_player.exit_finished.connect(_on_exit_animation_finished, CONNECT_ONE_SHOT)
		exit_player.exit()


func _on_exit_animation_finished() -> void:
	pending_exit_animations = max(pending_exit_animations - 1, 0)
	
	if pending_exit_animations > 0:
		return
	
	_finish_closing()


func _finish_closing() -> void:
	closed.emit()
	queue_free()
