class_name PlayerTokenTraysUI
extends VBoxContainer

@export var player_tray_scene:PackedScene

var game_manager:Node = null
var trays:Array[PlayerTokenTrayUI] = []


func _ready() -> void:
	add_to_group("player token trays ui")
	game_manager = get_tree().get_first_node_in_group("game manager")
	rebuild_trays()


func rebuild_trays() -> void:
	clear_trays()
	
	if game_manager == null:
		game_manager = get_tree().get_first_node_in_group("game manager")
	
	if game_manager == null:
		return
	
	if player_tray_scene == null:
		return
	
	for player_id in range(game_manager.number_of_players):
		create_player_tray(player_id)


func create_player_tray(player_id:int) -> void:
	var tray:PlayerTokenTrayUI = player_tray_scene.instantiate() as PlayerTokenTrayUI
	
	if tray == null:
		return
	
	add_child(tray)
	tray.setup_tray(game_manager, player_id)
	trays.append(tray)


func clear_trays() -> void:
	trays.clear()
	
	for child in get_children():
		child.queue_free()


func refresh_trays() -> void:
	for tray in trays:
		if tray == null:
			continue
		
		if is_instance_valid(tray) == false:
			continue
		
		tray.refresh_player_details()
