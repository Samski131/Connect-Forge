class_name LobbyPlayerTray
extends PanelContainer

@export_group("Player")
@export var player_id:int = 0

@export_group("Scenes")
@export var purchased_token_item_scene:PackedScene

@export_group("Player Colours")
@export_range(0, 6) var header_colour_index:int = 6
@export_range(0, 6) var border_colour_index:int = 3
@export_range(0, 6) var strip_colour_index:int = 2
@export_range(0, 6) var interior_colour_index:int = 5

var player_data:MatchPlayerData = null
var token_tray_inventory:TokenTrayInventory = null
var purchased_item_uis:Dictionary = {}

@onready var player_name_edit:LineEdit = %PlayerNameEdit
@onready var points_label:Label = %PointsLabel
@onready var header_token_visual_display:TokenVisualDisplay = %TokenVisualDisplay
@onready var purchased_tokens:GridContainer = %PurchaseTokens
@onready var token_grid_background:PanelContainer = %TokenGridBackground
@onready var juice_player:UIJuicePlayer = %UIJuicePlayer
@onready var colour_strip:PanelContainer = %ColourStrip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	connect_player_name_signals()


func setup(new_player_id:int, new_player_data:MatchPlayerData, new_token_tray_inventory:TokenTrayInventory) -> void:
	player_id = new_player_id
	player_data = new_player_data
	token_tray_inventory = new_token_tray_inventory
	
	if is_node_ready() == false:
		await ready
	
	connect_player_name_signals()
	connect_inventory_signals()
	refresh_player_details()
	refresh_points()
	rebuild_purchased_tokens()


func connect_player_name_signals() -> void:
	if player_name_edit == null:
		return
	
	if player_name_edit.text_submitted.is_connected(_on_player_name_submitted) == false:
		player_name_edit.text_submitted.connect(_on_player_name_submitted)
	
	if player_name_edit.focus_exited.is_connected(_on_player_name_focus_exited) == false:
		player_name_edit.focus_exited.connect(_on_player_name_focus_exited)


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
	refresh_player_name()
	
	if header_token_visual_display == null:
		return
	
	if player_data == null:
		header_token_visual_display.setup(TokenLibrary.TokenType.BASIC, player_id)
		return
	
	apply_player_colours()
	
	if player_data.colour_palette == null:
		header_token_visual_display.setup(TokenLibrary.TokenType.BASIC, player_id)
		return
	
	header_token_visual_display.setup_with_palette(TokenLibrary.TokenType.BASIC, player_id, player_data.colour_palette)


func refresh_player_name() -> void:
	if player_name_edit == null:
		return
	
	if MatchData.config != null:
		player_name_edit.text = MatchData.config.get_player_name(player_id)
		return
	
	if player_data != null:
		var used_name:String = player_data.player_name.strip_edges()
		
		if used_name != "":
			player_name_edit.text = used_name
			return
	
	player_name_edit.text = get_default_player_name()


func get_default_player_name() -> String:
	return "Player " + str(player_id + 1)


func commit_player_name() -> void:
	if player_name_edit == null:
		return
	
	var new_name:String = player_name_edit.text.strip_edges()
	
	if new_name == "":
		new_name = get_default_player_name()
	
	if player_data != null:
		if player_data.player_name == new_name:
			player_name_edit.text = new_name
			return
	
	if MatchData.config == null:
		if player_data != null:
			player_data.player_name = new_name
		
		player_name_edit.text = new_name
		return
	
	var name_was_changed:bool = MatchData.config.set_player_name(player_id, new_name)
	
	if name_was_changed == false:
		refresh_player_name()
		return
	
	player_data = MatchData.config.get_player(player_id)
	player_name_edit.text = MatchData.config.get_player_name(player_id)


func refresh_points() -> void:
	if points_label == null:
		return
	
	if player_data == null:
		points_label.text = "0"
		return
	
	points_label.text = str(player_data.token_points_remaining)


func _can_drop_data(_at_position:Vector2, data:Variant) -> bool:
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
		return false
	
	if token_tray_inventory == null:
		return false
	
	var token_type:int = int(drag_data["token_type"])
	return player_data.can_afford_token(token_type)


func _drop_data(_at_position:Vector2, data:Variant) -> void:
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
		return false
	
	if token_tray_inventory == null:
		return false
	
	if token_tray_inventory.get_player_tray(player_id) == null:
		return false
	
	if player_data.try_purchase_token(token_type) == false:
		return false
	
	token_tray_inventory.add_tokens(player_id, token_type, 1)
	refresh_points()
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
	
	if purchased_tokens == null:
		return
	
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
	var palette:ColorPalette = null
	
	if player_data != null:
		palette = player_data.colour_palette
	
	item.setup(player_id, token_type, token_count, palette)
	
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
	var first_order:int = TokenLibrary.get_tray_order(first_token_type)
	var second_order:int = TokenLibrary.get_tray_order(second_token_type)
	return first_order < second_order


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


func apply_player_colours() -> void:
	if player_data == null:
		return
	
	var palette:ColorPalette = player_data.colour_palette
	
	if palette == null:
		return
	
	var header_colour:Color = get_palette_colour(palette, header_colour_index, Color.WHITE)
	var border_colour:Color = get_palette_colour(palette, border_colour_index, header_colour)
	var strip_colour:Color = get_palette_colour(palette, strip_colour_index, header_colour)
	var interior_colour:Color = get_interior_colour(palette)
	
	apply_panel_style(self, header_colour, border_colour)
	apply_panel_style(colour_strip, strip_colour, strip_colour)
	apply_panel_style(token_grid_background, interior_colour, interior_colour)


func get_palette_colour(palette:ColorPalette, colour_index:int, fallback:Color) -> Color:
	if palette == null:
		return fallback
	
	if colour_index < 0:
		return fallback
	
	if colour_index >= palette.colors.size():
		return fallback
	
	return palette.colors[colour_index]


func get_interior_colour(palette:ColorPalette) -> Color:
	if palette != null:
		if interior_colour_index >= 0 and interior_colour_index < palette.colors.size():
			return palette.colors[interior_colour_index]
		
		if palette.colors.is_empty() == false:
			var fallback_base:Color = Color("#F2EBDD")
			return fallback_base.lerp(palette.colors[0], 0.18)
	
	return Color("#F2EBDD")


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


func _on_player_name_submitted(_submitted_text:String) -> void:
	commit_player_name()
	
	if player_name_edit != null:
		player_name_edit.release_focus()


func _on_player_name_focus_exited() -> void:
	commit_player_name()


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
