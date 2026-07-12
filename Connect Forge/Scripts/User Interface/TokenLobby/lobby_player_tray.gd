class_name LobbyPlayerTray
extends PanelContainer

@export_group("Player")
@export var player_id:int = 0


@export_group("Scenes")
@export var purchased_token_item_scene:PackedScene

@export_group("Player Colours")
@export_range(0, 4) var header_colour_index:int = 6
@export_range(0, 4) var border_colour_index:int = 3
@export_range(0, 4) var strip_colour_index:int = 2
@export_range(0, 5) var interior_colour_index:int = 5

var player_data:MatchPlayerData = null
var token_tray_inventory:TokenTrayInventory = null
var purchased_item_uis:Dictionary = {}

@onready var player_name_label:Label = %PlayerNameLabel
@onready var points_label:Label = %PointsLabel
@onready var header_token_visual_display:TokenVisualDisplay = %TokenVisualDisplay
@onready var purchased_tokens:GridContainer = %PurchaseTokens
@onready var token_grid_background:PanelContainer = %TokenGridBackground
@onready var juice_player:UIJuicePlayer = %UIJuicePlayer
@onready var colour_strip:PanelContainer = %ColourStrip

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(new_player_id:int, new_player_data:MatchPlayerData, new_token_tray_inventory:TokenTrayInventory) -> void:
	player_id = new_player_id
	player_data = new_player_data
	token_tray_inventory = new_token_tray_inventory
	
	if is_node_ready() == false:
		await ready
	
	connect_inventory_signals()
	refresh_player_details()
	refresh_points()
	rebuild_purchased_tokens()


func connect_inventory_signals() -> void:
	if token_tray_inventory == null:
		return
	
	if token_tray_inventory.token_type_added.is_connected(_on_token_type_added) == false:
		token_tray_inventory.token_type_added.connect(_on_token_type_added)
	
	if token_tray_inventory.token_count_changed.is_connected(_on_token_count_changed) == false:
		token_tray_inventory.token_count_changed.connect(_on_token_count_changed)
	
	if token_tray_inventory.trays_reset.is_connected(_on_trays_reset) == false:
		token_tray_inventory.trays_reset.connect(_on_trays_reset)

func refresh_player_details() -> void:
	if player_data == null:
		player_name_label.text = "Player " + str(player_id + 1)
		header_token_visual_display.setup(TokenLibrary.TokenType.BASIC, player_id)
		return
	
	player_name_label.text = player_data.player_name
	apply_player_colours()
	header_token_visual_display.setup(TokenLibrary.TokenType.BASIC, player_id)
	
func refresh_points() -> void:
	if player_data == null:
		points_label.text = "0"
		return
	
	points_label.text = str(player_data.token_points_remaining)

func _can_drop_data(_at_position:Vector2, data:Variant) -> bool:
	print("Checking drop on player ", player_id, ": ", data)
	
	if data is Dictionary == false:
		return false
	
	var drag_data:Dictionary = data
	
	if drag_data.has("drag_type") == false:
		return false
	
	if drag_data["drag_type"] != "lobby_token_purchase":
		return false
	
	if drag_data.has("token_type") == false:
		return false
	
	if player_data == null:
		print("Rejected: player_data is null")
		return false
	
	if token_tray_inventory == null:
		print("Rejected: token_tray_inventory is null")
		return false
	
	var token_type:int = int(drag_data["token_type"])
	var can_afford:bool = player_data.can_afford_token(token_type)
	print("Player ", player_id, " can afford: ", can_afford)
	return can_afford

func _drop_data(_at_position:Vector2, data:Variant) -> void:
	print("Dropped token onto player ", player_id)
	if data is Dictionary == false:
		return
	
	var drag_data:Dictionary = data
	
	if drag_data.has("token_type") == false:
		return
	
	var token_type:int = int(drag_data["token_type"])
	
	if try_purchase_token(token_type) == false:
		play_invalid_feedback()
		return
	
	play_purchase_feedback()

func try_purchase_token(token_type:int) -> bool:
	if player_data == null:
		print("Purchase rejected: player_data is null")
		return false
	
	if token_tray_inventory == null:
		print("Purchase rejected: token_tray_inventory is null")
		return false
	
	if token_tray_inventory.get_player_tray(player_id) == null:
		print("Purchase rejected: inventory has no tray for player ", player_id)
		print("Inventory tray count: ", token_tray_inventory.player_trays.size())
		return false
	
	if player_data.try_purchase_token(token_type) == false:
		print("Purchase rejected by MatchPlayerData")
		return false
	
	token_tray_inventory.add_tokens(player_id, token_type, 1)
	refresh_points()
	print("Purchase completed. Points remaining: ", player_data.token_points_remaining)
	return true


func rebuild_purchased_tokens() -> void:
	clear_purchased_tokens()
	
	if token_tray_inventory == null:
		return
	
	var token_types:Array[int] = token_tray_inventory.get_token_types_for_player(player_id)
	
	for token_type in token_types:
		ensure_purchased_item_exists(token_type)


func clear_purchased_tokens() -> void:
	purchased_item_uis.clear()
	
	for child in purchased_tokens.get_children():
		child.queue_free()


func ensure_purchased_item_exists(token_type:int) -> void:
	if purchased_item_uis.has(token_type):
		return
	
	if purchased_token_item_scene == null:
		return
	
	if purchased_tokens == null:
		return
	
	if token_tray_inventory == null:
		return
	
	var item:LobbyPurchasedTokenItem = purchased_token_item_scene.instantiate() as LobbyPurchasedTokenItem
	
	if item == null:
		return
	
	purchased_tokens.add_child(item)
	
	var token_count:int = token_tray_inventory.get_token_count(player_id, token_type)
	item.setup(player_id, token_type, token_count)
	
	if item.refund_requested.is_connected(_on_refund_requested) == false:
		item.refund_requested.connect(_on_refund_requested)
	
	purchased_item_uis[token_type] = item
	sort_purchased_items()


func sort_purchased_items() -> void:
	var token_types:Array = purchased_item_uis.keys()
	token_types.sort_custom(_sort_token_types)
	
	for token_type in token_types:
		var item:Control = purchased_item_uis[token_type] as Control
		
		if item == null:
			continue
		
		purchased_tokens.move_child(item, purchased_tokens.get_child_count() - 1)


func _sort_token_types(first_token_type:int, second_token_type:int) -> bool:
	return TokenLibrary.get_tray_order(first_token_type) < TokenLibrary.get_tray_order(second_token_type)


func refresh_purchased_item(token_type:int, play_feedback:bool) -> void:
	if token_tray_inventory == null:
		return
	
	var token_count:int = token_tray_inventory.get_token_count(player_id, token_type)
	
	if token_count <= 0:
		remove_purchased_item(token_type)
		return
	
	ensure_purchased_item_exists(token_type)
	
	if purchased_item_uis.has(token_type) == false:
		return
	
	var item:LobbyPurchasedTokenItem = purchased_item_uis[token_type] as LobbyPurchasedTokenItem
	
	if item == null:
		return
	
	item.set_count(token_count)
	
	if play_feedback:
		item.play_added_feedback()


func play_purchase_feedback() -> void:
	if juice_player == null:
		return
	
	juice_player.play_active()


func play_invalid_feedback() -> void:
	if juice_player == null:
		return
	
	juice_player.play_invalid()


func _on_token_type_added(changed_player_id:int, token_type:int) -> void:
	if changed_player_id != player_id:
		return
	
	ensure_purchased_item_exists(token_type)


func _on_token_count_changed(changed_player_id:int, token_type:int, _new_count:int) -> void:
	if changed_player_id != player_id:
		return
	
	refresh_purchased_item(token_type, true)


func _on_trays_reset() -> void:
	if player_data == null:
		return
	
	refresh_points()
	rebuild_purchased_tokens()


func _on_refund_requested(changed_player_id:int, token_type:int) -> void:
	if changed_player_id != player_id:
		return
	
	if player_data == null:
		return
	
	if token_tray_inventory == null:
		return
	
	if player_data.try_refund_token(token_type) == false:
		return
	
	if token_tray_inventory.spend_token(player_id, token_type) == false:
		player_data.try_purchase_token(token_type)
		return
	
	refresh_points()
	refresh_purchased_item(token_type, false)

func apply_player_colours() -> void:
	if player_data == null:
		return
	
	var palette:ColorPalette = player_data.colour_palette
	
	if palette == null:
		return
	
	if palette.colors.size() < 5:
		return
	
	var header_colour:Color = palette.colors[header_colour_index]
	var border_colour:Color = palette.colors[border_colour_index]
	var strip_colour:Color = palette.colors[strip_colour_index]
	var interior_colour:Color = get_interior_colour(palette)
	
	apply_panel_style(self, header_colour, border_colour)
	apply_panel_style(colour_strip, strip_colour, strip_colour)
	apply_panel_style(token_grid_background, interior_colour, interior_colour)

func get_interior_colour(palette:ColorPalette) -> Color:
	if palette.colors.size() > interior_colour_index:
		return palette.colors[interior_colour_index]
	
	var fallback_base:Color = Color("#F2EBDD")
	return fallback_base.lerp(palette.colors[0], 0.18)
	
func apply_panel_style(panel:PanelContainer, background_colour:Color, border_colour:Color) -> void:
	if panel == null:
		return
	
	var source_style:StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	var new_style:StyleBoxFlat = null
	
	if source_style == null:
		new_style = StyleBoxFlat.new()
	else:
		new_style = source_style.duplicate(true) as StyleBoxFlat
	
	if new_style == null:
		return
	
	new_style.bg_color = background_colour
	new_style.border_color = border_colour
	panel.add_theme_stylebox_override("panel", new_style)



func remove_purchased_item(token_type:int) -> void:
	if purchased_item_uis.has(token_type) == false:
		return
	
	var item:LobbyPurchasedTokenItem = purchased_item_uis[token_type] as LobbyPurchasedTokenItem
	purchased_item_uis.erase(token_type)
	
	if item == null:
		return
	
	if is_instance_valid(item):
		item.queue_free()
