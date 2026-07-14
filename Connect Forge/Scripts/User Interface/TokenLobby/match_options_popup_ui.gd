class_name MatchOptionsPopupUI
extends Control

signal options_applied

enum DisplayMode {
	EDIT_CONFIG,
	VIEW_SESSION
}

const DEFAULT_PLAYER_COUNT:int = 2
const DEFAULT_STARTING_POINTS:int = 10
const DEFAULT_TOKENS_TO_WIN:int = 4
const DEFAULT_BOARD_COLUMNS:int = 7
const DEFAULT_BOARD_ROWS:int = 6
const DEFAULT_TURN_TIMER_SECONDS:int = 0
const DEFAULT_STARTING_PLAYER_ID:int = 0

@export_group("Starting Points")
@export var starting_points_step:int = 1

@export_group("Header Token")
@export var header_token_palette:ColorPalette = preload("res://Scenes/Tokens/token colour resources/red_v3.tres")

@onready var popup_juice_player:UIJuicePlayer = %UIJuicePlayer
@onready var backdrop:MenuBackdrop = $Backdrop

@onready var player_count_minus:Button = %PlayerCountMinus
@onready var player_count_value:Label = %PlayerCountValue
@onready var player_count_plus:Button = %PlayerCountPlus

@onready var starting_points_minus:Button = %StartingPointsMinus
@onready var starting_points_value:Label = %StartingPointsValue
@onready var starting_points_plus:Button = %StartingPointsPlus

@onready var tokens_to_win_minus:Button = %TokensToWinMinus
@onready var tokens_to_win_value:Label = %TokensToWinValue
@onready var tokens_to_win_plus:Button = %TokensToWinPlus

@onready var board_size_buttons:HBoxContainer = %BoardSizeButtons
@onready var board_size_read_only_label:Label = %BoardSizeReadOnlyLabel
@onready var board_7x6_button:Button = %Board7x6Button
@onready var board_10x9_button:Button = %Board10x9Button
@onready var board_14x12_button:Button = %Board14x12Button

@onready var timer_buttons:HBoxContainer = %TimerButtons
@onready var turn_timer_read_only_label:Label = %TurnTimerReadOnlyLabel
@onready var timer_off_button:Button = %TimerOffButton
@onready var timer_30_button:Button = %Timer30Button
@onready var timer_60_button:Button = %Timer60Button

@onready var starting_player_option:OptionButton = %StartingPlayerOption

@onready var restore_defaults_button:Button = %RestoreDefaultsButton
@onready var apply_options_button:Button = %ApplyOptionsButton
@onready var header_token_display:TokenVisualDisplay = $"PopupCenter/PopupRoot/OuterFrame/Token Overlay/Token Visual Display"

var display_mode:DisplayMode = DisplayMode.EDIT_CONFIG
var match_session:MatchSession = null
var hamburger_button:BaseButton = null

var draft_player_count:int = DEFAULT_PLAYER_COUNT
var draft_starting_points:int = DEFAULT_STARTING_POINTS
var draft_tokens_to_win:int = DEFAULT_TOKENS_TO_WIN
var draft_board_columns:int = DEFAULT_BOARD_COLUMNS
var draft_board_rows:int = DEFAULT_BOARD_ROWS
var draft_turn_timer_seconds:int = DEFAULT_TURN_TIMER_SECONDS
var draft_starting_player_id:int = DEFAULT_STARTING_PLAYER_ID
var hidden_arrow_texture:ImageTexture = null

var is_refreshing_ui:bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(MenuBackdrop.CLOSABLE_MENU_GROUP)
	
	visible = true
	
	setup_button_groups()
	connect_option_controls()
	apply_display_mode()
	load_values_for_display_mode()
	setup_header_token()


func setup(new_hamburger_button:BaseButton) -> void:
	display_mode = DisplayMode.EDIT_CONFIG
	match_session = null
	
	bind_hamburger_button(new_hamburger_button)
	
	if is_node_ready():
		apply_display_mode()
		load_values_for_display_mode()


func setup_read_only(new_hamburger_button:BaseButton, new_match_session:MatchSession) -> void:
	display_mode = DisplayMode.VIEW_SESSION
	match_session = new_match_session
	
	bind_hamburger_button(new_hamburger_button)
	
	if is_node_ready():
		apply_display_mode()
		load_values_for_display_mode()


func bind_hamburger_button(new_hamburger_button:BaseButton) -> void:
	if hamburger_button != null:
		if is_instance_valid(hamburger_button):
			if hamburger_button.pressed.is_connected(_on_hamburger_button_pressed):
				hamburger_button.pressed.disconnect(_on_hamburger_button_pressed)
	
	hamburger_button = new_hamburger_button
	
	if hamburger_button == null:
		return
	
	if hamburger_button.pressed.is_connected(_on_hamburger_button_pressed) == false:
		hamburger_button.pressed.connect(_on_hamburger_button_pressed)


func is_read_only() -> bool:
	return display_mode == DisplayMode.VIEW_SESSION


func setup_button_groups() -> void:
	var board_size_group:ButtonGroup = ButtonGroup.new()
	board_size_group.allow_unpress = false
	
	board_7x6_button.toggle_mode = true
	board_10x9_button.toggle_mode = true
	board_14x12_button.toggle_mode = true
	
	board_7x6_button.button_group = board_size_group
	board_10x9_button.button_group = board_size_group
	board_14x12_button.button_group = board_size_group
	
	var timer_group:ButtonGroup = ButtonGroup.new()
	timer_group.allow_unpress = false
	
	timer_off_button.toggle_mode = true
	timer_30_button.toggle_mode = true
	timer_60_button.toggle_mode = true
	
	timer_off_button.button_group = timer_group
	timer_30_button.button_group = timer_group
	timer_60_button.button_group = timer_group


func connect_option_controls() -> void:
	connect_button(player_count_minus, _on_player_count_minus_pressed)
	connect_button(player_count_plus, _on_player_count_plus_pressed)
	connect_button(starting_points_minus, _on_starting_points_minus_pressed)
	connect_button(starting_points_plus, _on_starting_points_plus_pressed)
	connect_button(tokens_to_win_minus, _on_tokens_to_win_minus_pressed)
	connect_button(tokens_to_win_plus, _on_tokens_to_win_plus_pressed)
	
	connect_button(board_7x6_button, _on_board_7x6_pressed)
	connect_button(board_10x9_button, _on_board_10x9_pressed)
	connect_button(board_14x12_button, _on_board_14x12_pressed)
	
	connect_button(timer_off_button, _on_timer_off_pressed)
	connect_button(timer_30_button, _on_timer_30_pressed)
	connect_button(timer_60_button, _on_timer_60_pressed)
	
	connect_button(restore_defaults_button, restore_defaults)
	connect_button(apply_options_button, _on_primary_button_pressed)
	
	if starting_player_option != null:
		if starting_player_option.item_selected.is_connected(_on_starting_player_selected) == false:
			starting_player_option.item_selected.connect(_on_starting_player_selected)


func connect_button(button:BaseButton, function:Callable) -> void:
	if button == null:
		return
	
	if button.pressed.is_connected(function) == false:
		button.pressed.connect(function)


func apply_display_mode() -> void:
	var editable:bool = is_read_only() == false
	
	player_count_minus.visible = editable
	player_count_plus.visible = editable
	starting_points_minus.visible = editable
	starting_points_plus.visible = editable
	tokens_to_win_minus.visible = editable
	tokens_to_win_plus.visible = editable
	
	board_size_buttons.visible = editable
	board_size_read_only_label.visible = editable == false
	
	timer_buttons.visible = editable
	turn_timer_read_only_label.visible = editable == false
	
	starting_player_option.disabled = editable == false
	set_starting_player_arrow_visible(editable)
	
	restore_defaults_button.visible = editable
	
	if editable:
		apply_options_button.text = "Apply Options"
	else:
		apply_options_button.text = "Close"

func open_popup() -> void:
	if popup_juice_player == null:
		return
	
	if popup_juice_player.is_transitioning:
		return
	
	load_values_for_display_mode()
	setup_header_token()
	visible = true
	
	if backdrop != null:
		backdrop.enter()
	
	popup_juice_player.enter()


func close_popup() -> void:
	if popup_juice_player == null:
		return
	
	if popup_juice_player.is_open == false:
		return
	
	if popup_juice_player.is_transitioning:
		return
	
	if backdrop != null:
		backdrop.exit()
	
	popup_juice_player.exit()


func close_menu() -> void:
	close_popup()


func force_close_popup() -> void:
	if popup_juice_player != null:
		popup_juice_player.hide_instant()
	
	if backdrop != null:
		backdrop.hide_instant()
	
	visible = false


func force_close_menu() -> void:
	force_close_popup()


func load_values_for_display_mode() -> void:
	if is_read_only():
		load_values_from_session()
		return
	
	load_draft_from_config()


func load_draft_from_config() -> void:
	if MatchData.config == null:
		load_default_values()
		return
	
	var config:MatchConfig = MatchData.config
	
	draft_player_count = config.get_player_count()
	draft_starting_points = config.starting_token_points
	draft_tokens_to_win = config.tokens_to_win
	draft_board_columns = config.board_columns
	draft_board_rows = config.board_rows
	draft_turn_timer_seconds = config.turn_timer_seconds
	draft_starting_player_id = config.starting_player_id
	
	clamp_draft_values()
	rebuild_starting_player_options()
	refresh_ui()


func load_values_from_session() -> void:
	if match_session == null:
		push_error("MatchOptionsPopupUI: Read-only mode requires a MatchSession.")
		load_default_values()
		return
	
	draft_player_count = match_session.get_player_count()
	draft_starting_points = match_session.get_starting_token_points()
	draft_tokens_to_win = match_session.get_tokens_to_win()
	draft_board_columns = match_session.get_board_columns()
	draft_board_rows = match_session.get_board_rows()
	draft_turn_timer_seconds = match_session.get_turn_timer_seconds()
	draft_starting_player_id = match_session.get_configured_starting_player_id()
	
	clamp_draft_values()
	rebuild_starting_player_options()
	refresh_ui()


func load_default_values() -> void:
	draft_player_count = DEFAULT_PLAYER_COUNT
	draft_starting_points = DEFAULT_STARTING_POINTS
	draft_tokens_to_win = DEFAULT_TOKENS_TO_WIN
	draft_board_columns = DEFAULT_BOARD_COLUMNS
	draft_board_rows = DEFAULT_BOARD_ROWS
	draft_turn_timer_seconds = DEFAULT_TURN_TIMER_SECONDS
	draft_starting_player_id = DEFAULT_STARTING_PLAYER_ID
	
	clamp_draft_values()
	rebuild_starting_player_options()
	refresh_ui()


func restore_defaults() -> void:
	if is_read_only():
		return
	
	load_default_values()


func clamp_draft_values() -> void:
	draft_player_count = clamp(draft_player_count, MatchConfig.MINIMUM_PLAYERS, MatchConfig.MAXIMUM_PLAYERS)
	draft_starting_points = clamp(draft_starting_points, MatchConfig.MINIMUM_STARTING_TOKEN_POINTS, MatchConfig.MAXIMUM_STARTING_TOKEN_POINTS)
	draft_board_columns = clamp(draft_board_columns, MatchConfig.MINIMUM_BOARD_COLUMNS, MatchConfig.MAXIMUM_BOARD_COLUMNS)
	draft_board_rows = clamp(draft_board_rows, MatchConfig.MINIMUM_BOARD_ROWS, MatchConfig.MAXIMUM_BOARD_ROWS)
	
	var maximum_line_length:int = max(draft_board_columns, draft_board_rows)
	draft_tokens_to_win = clamp(draft_tokens_to_win, MatchConfig.MINIMUM_TOKENS_TO_WIN, maximum_line_length)
	
	if draft_starting_player_id >= draft_player_count:
		draft_starting_player_id = MatchConfig.RANDOM_STARTING_PLAYER_ID


func refresh_ui() -> void:
	is_refreshing_ui = true
	
	player_count_value.text = str(draft_player_count)
	starting_points_value.text = str(draft_starting_points)
	tokens_to_win_value.text = str(draft_tokens_to_win)
	
	board_size_read_only_label.text = format_board_size()
	turn_timer_read_only_label.text = format_turn_timer()
	
	if is_read_only():
		player_count_minus.disabled = true
		player_count_plus.disabled = true
		starting_points_minus.disabled = true
		starting_points_plus.disabled = true
		tokens_to_win_minus.disabled = true
		tokens_to_win_plus.disabled = true
	else:
		player_count_minus.disabled = draft_player_count <= MatchConfig.MINIMUM_PLAYERS
		player_count_plus.disabled = draft_player_count >= MatchConfig.MAXIMUM_PLAYERS
		
		starting_points_minus.disabled = draft_starting_points <= MatchConfig.MINIMUM_STARTING_TOKEN_POINTS
		starting_points_plus.disabled = draft_starting_points >= MatchConfig.MAXIMUM_STARTING_TOKEN_POINTS
		
		tokens_to_win_minus.disabled = draft_tokens_to_win <= MatchConfig.MINIMUM_TOKENS_TO_WIN
		tokens_to_win_plus.disabled = draft_tokens_to_win >= max(draft_board_columns, draft_board_rows)
	
	board_7x6_button.button_pressed = draft_board_columns == 7 and draft_board_rows == 6
	board_10x9_button.button_pressed = draft_board_columns == 10 and draft_board_rows == 9
	board_14x12_button.button_pressed = draft_board_columns == 14 and draft_board_rows == 12
	
	timer_off_button.button_pressed = draft_turn_timer_seconds == 0
	timer_30_button.button_pressed = draft_turn_timer_seconds == 30
	timer_60_button.button_pressed = draft_turn_timer_seconds == 60
	
	select_starting_player_option()
	
	is_refreshing_ui = false


func format_board_size() -> String:
	return str(draft_board_columns) + " × " + str(draft_board_rows)


func format_turn_timer() -> String:
	if draft_turn_timer_seconds <= 0:
		return "Off"
	
	if draft_turn_timer_seconds == 1:
		return "1 second"
	
	return str(draft_turn_timer_seconds) + " seconds"


func rebuild_starting_player_options() -> void:
	if starting_player_option == null:
		return
	
	starting_player_option.clear()
	starting_player_option.add_item("Random")
	starting_player_option.set_item_metadata(0, MatchConfig.RANDOM_STARTING_PLAYER_ID)
	
	for player_id in range(draft_player_count):
		var player_name:String = get_display_player_name(player_id)
		
		starting_player_option.add_item(player_name)
		
		var option_index:int = starting_player_option.item_count - 1
		starting_player_option.set_item_metadata(option_index, player_id)
	
	select_starting_player_option()


func get_display_player_name(player_id:int) -> String:
	if is_read_only():
		if match_session != null:
			return match_session.get_player_name(player_id)
		
		return "Player " + str(player_id + 1)
	
	if MatchData.config != null:
		if player_id < MatchData.config.get_player_count():
			return MatchData.config.get_player_name(player_id)
	
	return "Player " + str(player_id + 1)


func select_starting_player_option() -> void:
	if starting_player_option == null:
		return
	
	for option_index in range(starting_player_option.item_count):
		var metadata:Variant = starting_player_option.get_item_metadata(option_index)
		
		if metadata == null:
			continue
		
		if int(metadata) == draft_starting_player_id:
			starting_player_option.select(option_index)
			return
	
	starting_player_option.select(0)


func apply_options() -> void:
	if is_read_only():
		close_popup()
		return
	
	if MatchData.config == null:
		return
	
	MatchData.set_player_count(draft_player_count)
	
	var config:MatchConfig = MatchData.config
	
	config.set_board_size(draft_board_columns, draft_board_rows)
	config.set_tokens_to_win(draft_tokens_to_win)
	config.set_turn_timer_seconds(draft_turn_timer_seconds)
	config.set_starting_player_id(draft_starting_player_id)
	config.set_starting_token_points(draft_starting_points)
	
	options_applied.emit()
	close_popup()


func _on_primary_button_pressed() -> void:
	if is_read_only():
		close_popup()
		return
	
	apply_options()


func _on_hamburger_button_pressed() -> void:
	if popup_juice_player == null:
		return
	
	if popup_juice_player.is_open:
		close_popup()
		return
	
	open_popup()


func _on_player_count_minus_pressed() -> void:
	if is_read_only():
		return
	
	draft_player_count -= 1
	clamp_draft_values()
	rebuild_starting_player_options()
	refresh_ui()


func _on_player_count_plus_pressed() -> void:
	if is_read_only():
		return
	
	draft_player_count += 1
	clamp_draft_values()
	rebuild_starting_player_options()
	refresh_ui()


func _on_starting_points_minus_pressed() -> void:
	if is_read_only():
		return
	
	draft_starting_points -= max(starting_points_step, 1)
	clamp_draft_values()
	refresh_ui()


func _on_starting_points_plus_pressed() -> void:
	if is_read_only():
		return
	
	draft_starting_points += max(starting_points_step, 1)
	clamp_draft_values()
	refresh_ui()


func _on_tokens_to_win_minus_pressed() -> void:
	if is_read_only():
		return
	
	draft_tokens_to_win -= 1
	clamp_draft_values()
	refresh_ui()


func _on_tokens_to_win_plus_pressed() -> void:
	if is_read_only():
		return
	
	draft_tokens_to_win += 1
	clamp_draft_values()
	refresh_ui()


func _on_board_7x6_pressed() -> void:
	if is_read_only():
		return
	
	set_draft_board_size(7, 6)


func _on_board_10x9_pressed() -> void:
	if is_read_only():
		return
	
	set_draft_board_size(10, 9)


func _on_board_14x12_pressed() -> void:
	if is_read_only():
		return
	
	set_draft_board_size(14, 12)


func set_draft_board_size(columns:int, rows:int) -> void:
	if is_read_only():
		return
	
	draft_board_columns = columns
	draft_board_rows = rows
	
	clamp_draft_values()
	refresh_ui()


func _on_timer_off_pressed() -> void:
	if is_read_only():
		return
	
	draft_turn_timer_seconds = 0
	refresh_ui()


func _on_timer_30_pressed() -> void:
	if is_read_only():
		return
	
	draft_turn_timer_seconds = 30
	refresh_ui()


func _on_timer_60_pressed() -> void:
	if is_read_only():
		return
	
	draft_turn_timer_seconds = 60
	refresh_ui()


func _on_starting_player_selected(option_index:int) -> void:
	if is_refreshing_ui:
		return
	
	if is_read_only():
		select_starting_player_option()
		return
	
	var metadata:Variant = starting_player_option.get_item_metadata(option_index)
	
	if metadata == null:
		return
	
	draft_starting_player_id = int(metadata)


func setup_header_token() -> void:
	if header_token_display == null:
		return
	
	if header_token_palette != null:
		header_token_display.setup_with_palette(TokenLibrary.TokenType.BASIC, 0, header_token_palette)
		return
	
	header_token_display.setup(TokenLibrary.TokenType.BASIC, 0)

func set_starting_player_arrow_visible(arrow_visible:bool) -> void:
	if starting_player_option == null:
		return
	
	if arrow_visible:
		starting_player_option.remove_theme_icon_override("arrow")
		starting_player_option.remove_theme_constant_override("arrow_margin")
		return
	
	if hidden_arrow_texture == null:
		var image:Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		hidden_arrow_texture = ImageTexture.create_from_image(image)
	
	starting_player_option.add_theme_icon_override("arrow", hidden_arrow_texture)
	starting_player_option.add_theme_constant_override("arrow_margin", 0)
