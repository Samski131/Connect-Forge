extends VBoxContainer

var game_manager:Node
var player_entry_ui:PackedScene = load("res://Scenes/User Interface/Player Name Input.tscn")
var player_entries:Array[Node] = []

@onready var number_of_players_label:Label = $"Number of Players/number of players label"
@onready var remove_player_button:Button = $"Number of Players/-"
@onready var add_player_button:Button = $"Number of Players/+"


func _ready():
	game_manager = get_tree().get_first_node_in_group("game manager")
	remove_player_button.pressed.connect(remove_player)
	add_player_button.pressed.connect(add_player)
	sync_from_game_manager()


func add_player():
	if game_manager == null:
		return
	
	if game_manager.add_player():
		sync_from_game_manager()


func remove_player():
	if game_manager == null:
		return
	
	if game_manager.remove_player():
		sync_from_game_manager()


func sync_from_game_manager() -> void:
	clear_player_entries()
	
	if game_manager == null:
		update_player_counter()
		return
	
	for i in range(game_manager.number_of_players):
		create_player_entry(i)
	
	update_player_counter()


func clear_player_entries() -> void:
	for entry in player_entries:
		if entry == null:
			continue
		
		if is_instance_valid(entry) == false:
			continue
		
		entry.queue_free()
	
	player_entries.clear()


func create_player_entry(player_id:int) -> void:
	var new_player_entry:Node = player_entry_ui.instantiate()
	var label:Label = new_player_entry.find_child("label") as Label
	var text_edit:TextEdit = new_player_entry.find_child("TextEdit") as TextEdit
	
	if label != null:
		label.text = "Player: " + str(player_id + 1)
	
	if text_edit != null:
		text_edit.text = game_manager.get_player_name(player_id)
		text_edit.text_changed.connect(_on_player_name_changed.bind(player_id, text_edit))
	
	player_entries.append(new_player_entry)
	add_child(new_player_entry)


func _on_player_name_changed(player_id:int, text_edit:TextEdit) -> void:
	if game_manager == null:
		return
	
	if text_edit == null:
		return
	
	game_manager.set_player_name(player_id, text_edit.text)


func update_player_counter() -> void:
	if game_manager == null:
		number_of_players_label.text = "0"
		return
	
	number_of_players_label.text = str(game_manager.number_of_players)
