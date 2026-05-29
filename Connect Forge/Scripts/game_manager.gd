extends Node

#Game Managment
#Stores settings but mostly directs the games turn order and state machine.

@export var number_of_players = 2
@export var player_colours = [Color.GOLDENROD,Color.DARK_RED, Color.ROYAL_BLUE,Color.FOREST_GREEN]
var current_turn_phase = Global.TURN_PHASE.NONE
var current_player_id = 0
@onready var placement_state = $"Placement State"
@onready var action_state = $"Action State"
@onready var resolution_state = $"Resolution State"

func _ready():
	start_game()
	
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
	match(current_turn_phase):
		Global.TURN_PHASE.PLACEMENT:
			placement_state.process_state()
		Global.TURN_PHASE.ACTION:
			action_state.process_state()
		Global.TURN_PHASE.RESOLUTION:
			resolution_state.process_state()


	
