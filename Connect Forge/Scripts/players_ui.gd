extends VBoxContainer

var game_manager:Node
var player_entry_ui:PackedScene = load("res://Scenes/User Interface/Player Name Input.tscn")
var player_entries = []
@onready var number_of_players_label = $"Number of Players/number of players label"
@onready var remove_player_button = $"Number of Players/-"
@onready var add_player_button = $"Number of Players/+"

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")
	remove_player_button.connect("pressed",remove_player)
	add_player_button.connect("pressed",add_player)
	
	for i in range(game_manager.starting_number_of_players):
		add_player()
	
	set_default_names()
	
func set_default_names():
	if(game_manager.starting_number_of_players==2):
		var text_edits=[]
		for child in get_children(true):
			for baby in child.get_children(true):
				if(baby.name == "TextEdit"):
					text_edits.push_back(baby)
		text_edits[0].text = "Sam"
		text_edits[1].text = "Jordan"
		
	update_players_names()
	
func add_player():
	if(game_manager.number_of_players <game_manager.max_number_of_players):
		var new_player_entry = player_entry_ui.instantiate()
		new_player_entry.find_child("label").text = "Player: " + str(game_manager.number_of_players+1)
		new_player_entry.find_child("TextEdit").connect("text_changed",update_players_names)
		player_entries.push_back(new_player_entry)
		game_manager.number_of_players +=1
		add_child(new_player_entry)
		update_players_names()
		update_player_counter()
	
func remove_player():
	if(game_manager.number_of_players >=1):
		player_entries.back().queue_free()
		game_manager.number_of_players -=1
		player_entries.pop_back()
		update_players_names()
		update_player_counter()
	
func update_players_names():
	var text_edits=[]
	for child in get_children(true):
		for baby in child.get_children(true):
			if(baby.name == "TextEdit"):
				text_edits.push_back(baby)
	
	for i in range(text_edits.size()):
		if(game_manager.player_names.size()<=i):
			game_manager.player_names.append("")
		game_manager.player_names[i] = text_edits[i].text
	
func update_player_counter():
	number_of_players_label.text = str(game_manager.number_of_players)


			
