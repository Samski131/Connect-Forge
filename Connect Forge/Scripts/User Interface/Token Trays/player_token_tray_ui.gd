class_name PlayerTokenTrayUI
extends MarginContainer

@export var player_id:int = 0
@export var item_scene:PackedScene

var game_manager:Node = null
var token_tray_inventory:TokenTrayInventory = null
var item_uis:Dictionary = {}

@onready var color_indicator:Panel = $"Token Tray (Outline)/Token Tray (Hbox)/Color Indicator"
@onready var player_name_label:Label = $"Token Tray (Outline)/Token Tray (Hbox)/Token Tray (Vbox)/Player Header (Panel Container)/Margin/Header content (Hbox)/Player Name"
@onready var token_grid:GridContainer = $"Token Tray (Outline)/Token Tray (Hbox)/Token Tray (Vbox)/Bottom Panel of Token Tray/Interior panel/MarginContainer/Token Grid"
@onready var header_token_visual_display:TokenVisualDisplay = $"Token Tray (Outline)/Token Tray (Hbox)/Token Tray (Vbox)/Player Header (Panel Container)/Margin/Header content (Hbox)/Header Token Visual Display"

func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game manager")
	token_tray_inventory = get_tree().get_first_node_in_group("token tray inventory") as TokenTrayInventory
	
	clear_existing_items()
	connect_inventory_signals()
	refresh_player_details()
	rebuild_from_inventory()


func setup_tray(new_game_manager:Node, new_player_id:int) -> void:
	game_manager = new_game_manager
	player_id = new_player_id
	
	token_tray_inventory = get_tree().get_first_node_in_group("token tray inventory") as TokenTrayInventory
	
	clear_existing_items()
	connect_inventory_signals()
	refresh_player_details()
	rebuild_from_inventory()


func refresh_player_details() -> void:
	set_player_name()
	set_color_indicator()
	set_header_token_visual()


func set_player_name() -> void:
	if player_name_label == null:
		return
	
	if game_manager == null:
		player_name_label.text = "Player " + str(player_id + 1)
		return
	
	if player_id >= 0 and player_id < game_manager.player_names.size():
		player_name_label.text = game_manager.player_names[player_id]
		return
	
	player_name_label.text = "Player " + str(player_id + 1)


func set_color_indicator() -> void:
	if color_indicator == null:
		return
	
	var player_color:Color = get_player_indicator_color()
	var current_style:StyleBoxFlat = color_indicator.get_theme_stylebox("panel") as StyleBoxFlat
	
	if current_style == null:
		current_style = StyleBoxFlat.new()
	else:
		current_style = current_style.duplicate() as StyleBoxFlat
	
	current_style.bg_color = player_color
	color_indicator.add_theme_stylebox_override("panel", current_style)


func get_player_indicator_color() -> Color:
	if game_manager == null:
		return Color.WHITE
	
	if player_id < 0:
		return Color.WHITE
	
	if player_id >= game_manager.player_colours.size():
		return Color.WHITE
	
	var palette:ColorPalette = game_manager.player_colours[player_id]
	
	if palette == null:
		return Color.WHITE
	
	if palette.colors.size() < 3:
		return Color.WHITE
	
	return palette.colors[2]


func clear_existing_items() -> void:
	item_uis.clear()
	
	if token_grid == null:
		return
	
	for child in token_grid.get_children():
		child.queue_free()


func connect_inventory_signals() -> void:
	if token_tray_inventory == null:
		return
	
	if token_tray_inventory.token_type_added.is_connected(_on_token_type_added) == false:
		token_tray_inventory.token_type_added.connect(_on_token_type_added)
	
	if token_tray_inventory.trays_reset.is_connected(_on_trays_reset) == false:
		token_tray_inventory.trays_reset.connect(_on_trays_reset)


func rebuild_from_inventory() -> void:
	if token_tray_inventory == null:
		return
	
	var token_types:Array[int] = token_tray_inventory.get_token_types_for_player(player_id)
	
	for token_type in token_types:
		ensure_item_ui_exists(token_type)


func ensure_item_ui_exists(token_type:int) -> void:
	if item_uis.has(token_type):
		return
	
	if item_scene == null:
		return
	
	if token_grid == null:
		return
	
	var item:TokenTrayItemUI = item_scene.instantiate() as TokenTrayItemUI
	
	if item == null:
		return
	
	token_grid.add_child(item)
	item.setup(game_manager, player_id, token_type)
	item_uis[token_type] = item
	
	sort_items_by_tray_order()


func sort_items_by_tray_order() -> void:
	var token_types:Array = item_uis.keys()
	token_types.sort_custom(_sort_token_types_by_tray_order)
	
	for token_type in token_types:
		var item:Control = item_uis[token_type] as Control
		
		if item == null:
			continue
		
		token_grid.move_child(item, token_grid.get_child_count() - 1)


func _sort_token_types_by_tray_order(a:int, b:int) -> bool:
	var a_order:int = TokenLibrary.get_tray_order(a)
	var b_order:int = TokenLibrary.get_tray_order(b)
	
	return a_order < b_order


func _on_token_type_added(changed_player_id:int, token_type:int) -> void:
	if changed_player_id != player_id:
		return
	
	ensure_item_ui_exists(token_type)


func _on_trays_reset() -> void:
	clear_existing_items()
	rebuild_from_inventory()

func set_header_token_visual() -> void:
	if header_token_visual_display == null:
		return
	header_token_visual_display.setup(TokenLibrary.TokenType.BASIC, player_id)
