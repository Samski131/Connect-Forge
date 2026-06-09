extends Node

#Game Managment
#Stores settings but mostly directs the games turn order and state machine.

@export var starting_number_of_players = 2
@export var max_number_of_players = 6
var number_of_players:int
@export var player_colours:Array[ColorPalette]
var player_names = []
var current_turn_phase = Global.TURN_PHASE.NONE
var current_player_id = 0
@onready var placement_state = $"Placement State"
@onready var action_state = $"Action State"
@onready var resolution_state = $"Resolution State"
@onready var game_over_state = $"Game Over State"

@onready var board_builder = $"../Board Builder"
var winner_ui:VBoxContainer

func _ready():
	gather_groups()
	start_game()

func gather_groups():
	winner_ui = get_tree().get_first_node_in_group("winner ui")
	
func start_game(): #start game on player 0s turn.
	start_turn(0)
	
func start_turn(_playerID:int):
	placement_state.enter_state()# begin first player's placement phase.
	
func end_turn(): #move on to the next player's turn
	current_player_id= getNextPlayerID()
	start_turn(current_player_id)
	
func getNextPlayerID()->int: #figure out who the next player is depending on how many players total there are.
	var next = (current_player_id + 1) % number_of_players
	return next
	
func _process(_delta): #runs the appropriate process_state based on the state machine phase.
	
	debug_gravity_changes()
	match(current_turn_phase):
		Global.TURN_PHASE.PLACEMENT:
			placement_state.process_state()
		Global.TURN_PHASE.ACTION:
			action_state.process_state()
		Global.TURN_PHASE.RESOLUTION:
			resolution_state.process_state()
		
func reset_game():
	print("reset")
	board_builder.rebuild_board()
	winner_ui.clear_winner()
	start_game()

func debug_gravity_changes():
	var change:bool = false
	if(Input.is_action_just_pressed("right_arrow")):
		Global.board_settings.gravity_direction = Global.board_settings.DIRECTION.RIGHT
		change = true
	if(Input.is_action_just_pressed("left_arrow")):
		Global.board_settings.gravity_direction = Global.board_settings.DIRECTION.LEFT
		change = true
	if(Input.is_action_just_pressed("up_arrow")):
		Global.board_settings.gravity_direction = Global.board_settings.DIRECTION.UP
		change = true
	if(Input.is_action_just_pressed("down_arrow")):
		Global.board_settings.gravity_direction = Global.board_settings.DIRECTION.DOWN
		change = true
	
	if(change):
		match(current_turn_phase):
			Global.TURN_PHASE.PLACEMENT:
				placement_state.exit_state()
			Global.TURN_PHASE.ACTION:
				action_state.exit_state()
			Global.TURN_PHASE.RESOLUTION:
				resolution_state.exit_state()
		get_tree().call_group("slot", "gravity_change")
		action_state.enter_state()
