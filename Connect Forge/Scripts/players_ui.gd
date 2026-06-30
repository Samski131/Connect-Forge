extends VBoxContainer

var game_manager:Node
var player_entry_ui:PackedScene = load("res://Scenes/User Interface/Player Name Input.tscn")
var player_entries:Array[Node] = []

@onready var number_of_players_label:Label = $"Number of Players/number of players label"
@onready var remove_player_button:Button = $"Number of Players/-"
@onready var add_player_button:Button = $"Number of Players/+"


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	
	if remove_player_button != null:
		remove_player_button.pressed.connect(remove_player)
	
	if add_player_button != null:
		add_player_button.pressed.connect(add_player)
	
	sync_from_game_manager()


func add_player() -> void:
	if game_manager == null:
		return
	
	if game_manager.add_player() == false:
		update_player_counter()
		update_buttons()
		return
	
	sync_from_game_manager()


func remove_player() -> void:
	if game_manager == null:
		return
	
	if game_manager.remove_player() == false:
		update_player_counter()
		update_buttons()
		return
	
	sync_from_game_manager()


func sync_from_game_manager() -> void:
	clear_player_entries()
	
	if game_manager == null:
		update_player_counter()
		update_buttons()
		return
	
	for player_id in range(game_manager.number_of_players):
		create_player_entry(player_id)
	
	update_player_counter()
	update_buttons()


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
	refresh_related_player_ui()


func refresh_related_player_ui() -> void:
	var player_token_trays_ui:PlayerTokenTraysUI = get_tree().get_first_node_in_group("player token trays ui") as PlayerTokenTraysUI
	
	if player_token_trays_ui != null:
		player_token_trays_ui.refresh_trays()


func update_player_counter() -> void:
	if number_of_players_label == null:
		return
	
	if game_manager == null:
		number_of_players_label.text = "0"
		return
	
	number_of_players_label.text = str(game_manager.number_of_players)


func update_buttons() -> void:
	if game_manager == null:
		return
	
	if remove_player_button != null:
		remove_player_button.disabled = game_manager.number_of_players <= game_manager.minimum_number_of_players
	
	if add_player_button != null:
		add_player_button.disabled = game_manager.number_of_players >= game_manager.max_number_of_players
