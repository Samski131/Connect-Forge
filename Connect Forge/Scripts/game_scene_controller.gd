class_name GameSceneController
extends Node2D

@onready var game_board:Node2D = $"Game Board"
@onready var token_pool:Node2D = $"Game Board/Token Pool"
@onready var board_builder:BoardBuilder = $"Game Board/Board Builder"
@onready var board_manager:BoardManager = $"Game Board/Board Manager"
@onready var board_visual_manager:BoardVisualManager = $"Game Board/Board Visual Manager"

@onready var game_manager:GameManager = $"Game Manager"
@onready var turn_timer:MatchTurnTimer = $"Game Manager/Turn Timer"
@onready var token_drag_controller:TokenDragController = $"Token Drag Controller"

@onready var board_area_fitter:PanelContainer = $"User Interface/Game UI/Panels/Centre Panels/Margin/Board Area Panel"
@onready var player_token_trays_ui:PlayerTokenTraysUI = $"User Interface/Game UI/Panels/Centre Panels/Right Sidebar (PanelContainer)/Right Sidebar Margin (Margin Container)/Content (Vbox)/MarginContainer/Token Tray Scroll (Scroll)/Token Trays (Vbox)"
@onready var current_turn_card:CurrentTurnCardUI = $"User Interface/Game UI/Panels/Centre Panels/Right Sidebar (PanelContainer)/Right Sidebar Margin (Margin Container)/Content (Vbox)/Current Turn Header/Current Turn Card (Panel Container)"

@onready var turn_counter_label:TurnCounterLabelUI = $"User Interface/Game UI/Panels/Top Panel/MarginContainer/PanelContainer/HBoxContainer/Center Scoreboard/PanelContainer/MarginContainer/HBoxContainer/Turn Counter"
@onready var time_counter_label:TimeCounterLabelUI = $"User Interface/Game UI/Panels/Top Panel/MarginContainer/PanelContainer/HBoxContainer/Center Scoreboard/PanelContainer/MarginContainer/HBoxContainer/Time Counter"
@onready var score_label:ScoreLabelUI = $"User Interface/Game UI/Panels/Top Panel/MarginContainer/PanelContainer/HBoxContainer/Center Scoreboard/PanelContainer/MarginContainer/HBoxContainer/Time Counter2"

@onready var match_options_button:BaseButton = $"User Interface/Game UI/Panels/Top Panel/MarginContainer/PanelContainer/HBoxContainer/Options Button/PanelContainer/Options Button/Button"
@onready var match_options_popup:MatchOptionsPopupUI = $"User Interface/Game UI/MatchOptionsPopupUI"
@onready var game_over_menu:GameOverMenu = $"User Interface/Game UI/Game Over Menu"


func _ready() -> void:
	if validate_scene_references() == false:
		push_error("GameSceneController: Scene wiring failed. The match was not initialised.")
		return
	
	wire_board_systems()
	wire_match_systems()
	wire_user_interface()
	
	game_manager.initialize_game()
	
	if game_manager.session == null:
		push_error("GameSceneController: GameManager did not create a MatchSession.")
		return
	
	wire_match_options()


func wire_board_systems() -> void:
	board_manager.setup(token_pool, board_visual_manager)
	board_builder.setup(game_board, board_manager, token_pool, board_area_fitter)


func wire_match_systems() -> void:
	game_manager.setup(board_builder, board_manager, turn_timer, token_drag_controller, game_over_menu)
	token_drag_controller.setup(game_manager, board_manager)
	turn_timer.setup(game_manager)
	game_over_menu.setup(game_manager)

func wire_user_interface() -> void:
	player_token_trays_ui.setup(game_manager, token_drag_controller)
	current_turn_card.setup(game_manager, turn_timer)
	turn_counter_label.setup(game_manager)
	time_counter_label.setup(game_manager)
	score_label.setup(game_manager)


func wire_match_options() -> void:
	if match_options_popup == null:
		return
	
	if match_options_button == null:
		return
	
	if game_manager == null:
		return
	
	if game_manager.session == null:
		return
	
	match_options_popup.setup_read_only(match_options_button, game_manager.session)


func validate_scene_references() -> bool:
	var references_are_valid:bool = true
	
	if validate_reference(game_board, "Game Board") == false:
		references_are_valid = false
	
	if validate_reference(token_pool, "Token Pool") == false:
		references_are_valid = false
	
	if validate_reference(board_builder, "Board Builder") == false:
		references_are_valid = false
	
	if validate_reference(board_manager, "Board Manager") == false:
		references_are_valid = false
	
	if validate_reference(board_visual_manager, "Board Visual Manager") == false:
		references_are_valid = false
	
	if validate_reference(game_manager, "Game Manager") == false:
		references_are_valid = false
	
	if validate_reference(turn_timer, "Turn Timer") == false:
		references_are_valid = false
	
	if validate_reference(token_drag_controller, "Token Drag Controller") == false:
		references_are_valid = false
	
	if validate_reference(board_area_fitter, "Board Area Panel") == false:
		references_are_valid = false
	
	if validate_reference(player_token_trays_ui, "Token Trays") == false:
		references_are_valid = false
	
	if validate_reference(current_turn_card, "Current Turn Card") == false:
		references_are_valid = false
	
	if validate_reference(turn_counter_label, "Turn Counter") == false:
		references_are_valid = false
	
	if validate_reference(time_counter_label, "Time Counter") == false:
		references_are_valid = false
	
	if validate_reference(score_label, "Score Label") == false:
		references_are_valid = false
	
	if validate_reference(match_options_button, "Match Options Button") == false:
		references_are_valid = false
	
	if validate_reference(match_options_popup, "Match Options Popup") == false:
		references_are_valid = false
	
	if validate_reference(game_over_menu, "Game Over Menu") == false:
		references_are_valid = false
	
	return references_are_valid


func validate_reference(node:Node, reference_name:String) -> bool:
	if node != null:
		return true
	
	push_error("GameSceneController: Missing required scene reference: " + reference_name)
	return false
