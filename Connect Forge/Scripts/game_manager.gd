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
@onready var board:BoardManager = $"../Board Manager"
var winner_ui:VBoxContainer

func _ready():
	gather_groups()
	setup_states()
	start_game()

func setup_states():
	placement_state.setup(self, board)
	action_state.setup(self, board)
	resolution_state.setup(self, board)
	game_over_state.setup(self, board)
	
func gather_groups():
	winner_ui = get_tree().get_first_node_in_group("winner ui")
	
func start_game(): #start game on player 0s turn.
	
	start_turn(0)
	
func start_turn(player_id:int):
	current_player_id = player_id
	placement_state.enter_state()# begin first player's placement phase.
	
func end_turn(): #move on to the next player's turn
	current_player_id= get_next_player_id()
	start_turn(current_player_id)
	
func get_next_player_id()->int: #figure out who the next player is depending on how many players total there are.
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
	board_builder.rebuild_board()
	winner_ui.clear_winner()
	start_game()

func debug_gravity_changes():
	var changed:bool = false
	var DIRECTION = BoardSetting.DIRECTION
	
	if Input.is_action_just_pressed("right_arrow"):
		changed = board.set_gravity_direction(DIRECTION.RIGHT)
	
	if Input.is_action_just_pressed("left_arrow"):
		changed = board.set_gravity_direction(DIRECTION.LEFT)
	
	if Input.is_action_just_pressed("up_arrow"):
		changed = board.set_gravity_direction(DIRECTION.UP)
	
	if Input.is_action_just_pressed("down_arrow"):
		changed = board.set_gravity_direction(DIRECTION.DOWN)
	
	if changed:
		placement_state.clear_placement_token()
		action_state.enter_state()
