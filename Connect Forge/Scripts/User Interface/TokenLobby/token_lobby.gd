class_name TokenLobby
extends CanvasLayer

@export_group("Scenes")
@export var token_shop_card_scene:PackedScene
@export var lobby_player_tray_scene:PackedScene
@export var purchased_token_item_scene:PackedScene
@export var game_board_scene:PackedScene = preload("res://Scenes/game_board.tscn")

@onready var token_grid:GridContainer = %TokenGrid
@onready var player_tray_row:HBoxContainer = %PlayerTrayRow
@onready var start_button:Button = $"Control/ScreenMargin/ScreenLayout/Footer/Footer/Start Button"

@onready var options_button:TextureButton = $"Control/ScreenMargin/ScreenLayout/Top Panel/Margin/PanelContainer/HBoxContainer/Options Button/PanelContainer/OptionsButton/Button"
@onready var pause_button:TextureButton = $"Control/ScreenMargin/ScreenLayout/Top Panel/Margin/PanelContainer/HBoxContainer/Pause Button/PanelContainer/Pause Button/Button"

@onready var match_options_popup:MatchOptionsPopupUI = $Control/ScreenMargin/MatchOptionsPopupUI
@onready var pause_menu:PauseMenu = $Control/ScreenMargin/PauseMenuPopupUI

var is_starting_match:bool = false


func _ready() -> void:
	MatchData.clear_session()
	connect_buttons()
	setup_pause_menu()
	setup_match_options_popup()
	create_shop_cards()
	create_player_trays()


func connect_buttons() -> void:
	if start_button != null:
		if start_button.pressed.is_connected(_on_start_button_pressed) == false:
			start_button.pressed.connect(_on_start_button_pressed)


func setup_match_options_popup() -> void:
	if match_options_popup == null:
		push_error("TokenLobby: MatchOptionsPopupUI could not be found.")
		return
	
	if options_button == null:
		push_error("TokenLobby: Options button could not be found.")
		return
	
	match_options_popup.setup(options_button)
	
	if match_options_popup.options_applied.is_connected(_on_match_options_applied) == false:
		match_options_popup.options_applied.connect(_on_match_options_applied)


func get_player_count() -> int:
	if MatchData.config == null:
		return 0
	
	return MatchData.config.get_player_count()


func create_shop_cards() -> void:
	clear_container(token_grid)
	
	if token_shop_card_scene == null:
		return
	
	var token_types:Array[int] = TokenLibrary.get_lobby_token_types()
	
	for token_type in token_types:
		create_shop_card(token_type)


func create_shop_card(token_type:int) -> void:
	if token_grid == null:
		return
	
	var card:TokenShopCard = token_shop_card_scene.instantiate() as TokenShopCard
	
	if card == null:
		return
	
	token_grid.add_child(card)
	card.setup(token_type)


func create_player_trays() -> void:
	clear_container(player_tray_row)
	
	if lobby_player_tray_scene == null:
		return
	
	var player_count:int = get_player_count()
	
	for player_id in range(player_count):
		create_player_tray(player_id)


func create_player_tray(player_id:int) -> void:
	if player_tray_row == null:
		return
	
	if MatchData.config == null:
		return
	
	var tray:LobbyPlayerTray = lobby_player_tray_scene.instantiate() as LobbyPlayerTray
	
	if tray == null:
		return
	
	var player:MatchPlayerData = MatchData.config.get_player(player_id)
	
	if player == null:
		tray.queue_free()
		return
	
	tray.purchased_token_item_scene = purchased_token_item_scene
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.size_flags_vertical = Control.SIZE_FILL
	
	player_tray_row.add_child(tray)
	tray.setup(player_id, player)


func clear_container(container:Container) -> void:
	if container == null:
		return
	
	for child in container.get_children():
		child.queue_free()


func start_match() -> void:
	if is_starting_match:
		return
	
	if MatchData.config == null:
		push_error("Cannot start match because MatchData.config is null.")
		return
	
	if MatchData.config.get_player_count() < MatchConfig.MINIMUM_PLAYERS:
		push_error("Cannot start match without at least " + str(MatchConfig.MINIMUM_PLAYERS) + " players.")
		return
	
	if game_board_scene == null:
		push_error("Cannot start match because no game board scene has been assigned.")
		return
	
	is_starting_match = true
	
	if start_button != null:
		start_button.disabled = true
	
	var change_error:Error = get_tree().change_scene_to_packed(game_board_scene)
	
	if change_error == OK:
		return
	
	is_starting_match = false
	
	if start_button != null:
		start_button.disabled = false
	
	push_error("Could not change to the game board scene. Error code: " + str(change_error))


func _on_start_button_pressed() -> void:
	start_match()


func _on_match_options_applied() -> void:
	create_player_trays()


func setup_pause_menu() -> void:
	if pause_menu == null:
		push_error("TokenLobby: PauseMenuPopupUI could not be found.")
		return
	
	if pause_button == null:
		push_error("TokenLobby: Pause button could not be found.")
		return
	
	pause_menu.set_menu_context(PauseMenu.MenuContext.TOKEN_LOBBY)
	pause_menu.setup(pause_button)
