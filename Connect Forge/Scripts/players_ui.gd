extends VBoxContainer

var game_manager:Node = null
var player_entry_ui:PackedScene = preload("res://Scenes/User Interface/Player Name Input.tscn")
var player_entries:Array[Node] = []
var is_rebuilding_entries:bool = false

@onready var number_of_players_label:Label = $"Number of Players/number of players label"
@onready var remove_player_button:Button = $"Number of Players/-"
@onready var add_player_button:Button = $"Number of Players/+"


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	connect_buttons()
	connect_game_manager_signals()
	sync_from_game_manager()


func connect_buttons() -> void:
	if remove_player_button != null:
		if remove_player_button.pressed.is_connected(remove_player) == false:
			remove_player_button.pressed.connect(remove_player)
	
	if add_player_button != null:
		if add_player_button.pressed.is_connected(add_player) == false:
			add_player_button.pressed.connect(add_player)


func connect_game_manager_signals() -> void:
	if game_manager == null:
		return
	
	if game_manager.has_signal("players_changed"):
		if game_manager.players_changed.is_connected(_on_players_changed) == false:
			game_manager.players_changed.connect(_on_players_changed)
	
	if game_manager.has_signal("player_names_changed"):
		if game_manager.player_names_changed.is_connected(_on_player_names_changed) == false:
			game_manager.player_names_changed.connect(_on_player_names_changed)


func add_player() -> void:
	if game_manager == null:
		return
	
	if game_manager.has_method("add_player") == false:
		return
	
	if game_manager.add_player() == false:
		update_player_counter()
		update_buttons()
		return
	
	sync_from_game_manager()


func remove_player() -> void:
	if game_manager == null:
		return
	
	if game_manager.has_method("remove_player") == false:
		return
	
	if game_manager.remove_player() == false:
		update_player_counter()
		update_buttons()
		return
	
	sync_from_game_manager()


func sync_from_game_manager() -> void:
	if is_rebuilding_entries:
		return
	
	is_rebuilding_entries = true
	clear_player_entries()
	
	var player_count:int = get_player_count()
	
	for player_id in range(player_count):
		create_player_entry(player_id)
	
	update_player_counter()
	update_buttons()
	is_rebuilding_entries = false


func clear_player_entries() -> void:
	for entry in player_entries:
		if entry == null:
			continue
		
		if is_instance_valid(entry) == false:
			continue
		
		if entry.get_parent() == self:
			remove_child(entry)
		
		entry.queue_free()
	
	player_entries.clear()


func create_player_entry(player_id:int) -> void:
	if player_entry_ui == null:
		return
	
	var new_player_entry:Node = player_entry_ui.instantiate()
	
	if new_player_entry == null:
		return
	
	var label:Label = new_player_entry.find_child("label", true, false) as Label
	var text_edit:TextEdit = new_player_entry.find_child("TextEdit", true, false) as TextEdit
	
	if label != null:
		label.text = "Player: " + str(player_id + 1)
	
	if text_edit != null:
		text_edit.text = get_player_name(player_id)
		text_edit.text_changed.connect(_on_player_name_changed.bind(player_id, text_edit))
	
	player_entries.append(new_player_entry)
	add_child(new_player_entry)


func _on_player_name_changed(player_id:int, text_edit:TextEdit) -> void:
	if is_rebuilding_entries:
		return
	
	if game_manager == null:
		return
	
	if text_edit == null:
		return
	
	if is_instance_valid(text_edit) == false:
		return
	
	if game_manager.has_method("set_player_name") == false:
		return
	
	game_manager.set_player_name(player_id, text_edit.text)


func get_player_count() -> int:
	if game_manager != null:
		if game_manager.has_method("get_player_count"):
			return int(game_manager.get_player_count())
	
	if MatchData.config != null:
		return MatchData.config.get_player_count()
	
	return 0


func get_player_name(player_id:int) -> String:
	if game_manager != null:
		if game_manager.has_method("get_player_name"):
			return str(game_manager.get_player_name(player_id))
	
	if MatchData.config != null:
		return MatchData.config.get_player_name(player_id)
	
	return "Player " + str(player_id + 1)


func update_player_counter() -> void:
	if number_of_players_label == null:
		return
	
	number_of_players_label.text = str(get_player_count())


func update_buttons() -> void:
	var player_count:int = get_player_count()
	
	if remove_player_button != null:
		remove_player_button.disabled = player_count <= MatchConfig.MINIMUM_PLAYERS
	
	if add_player_button != null:
		add_player_button.disabled = player_count >= MatchConfig.MAXIMUM_PLAYERS


func _on_players_changed() -> void:
	sync_from_game_manager()


func _on_player_names_changed() -> void:
	refresh_player_entry_names()
	update_player_counter()
	update_buttons()


func refresh_player_entry_names() -> void:
	for player_id in range(player_entries.size()):
		var entry:Node = player_entries[player_id]
		
		if entry == null:
			continue
		
		if is_instance_valid(entry) == false:
			continue
		
		var text_edit:TextEdit = entry.find_child("TextEdit", true, false) as TextEdit
		
		if text_edit == null:
			continue
		
		var player_name:String = get_player_name(player_id)
		
		if text_edit.text != player_name:
			text_edit.text = player_name
