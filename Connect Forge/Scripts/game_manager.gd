extends Node


@export var number_of_players = 2 
@export var player_colours = [Color.GOLDENROD,Color.DARK_RED, Color.ROYAL_BLUE,Color.FOREST_GREEN]
var current_turn_phase = Global.TURN_PHASE.NONE
var current_player_ID = 0
@onready var placement_state = $"Placement State"
@onready var action_state = $"Action State"
@onready var resolution_state = $"Resolution State"

func _ready():
	start_game()
	
func start_game():
	start_turn(0)
	
func start_turn(_playerID:int):
	placement_state.enter_state()
	
func end_turn():
	current_player_ID= getNextPlayerID()
	start_turn(current_player_ID)
	
func getNextPlayerID()->int:
	var next = (current_player_ID + 1) % number_of_players
	return next
	
func _process(_delta):
	
	match(current_turn_phase):
		Global.TURN_PHASE.PLACEMENT:
			placement_state.process_state()
		Global.TURN_PHASE.ACTION:
			action_state.process_state()
		Global.TURN_PHASE.RESOLUTION:
			resolution_state.process_state()


	
