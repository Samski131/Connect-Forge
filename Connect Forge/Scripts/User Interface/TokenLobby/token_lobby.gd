class_name TokenLobby
extends CanvasLayer



@export_group("Scenes")
@export var token_shop_card_scene:PackedScene
@export var lobby_player_tray_scene:PackedScene
@export var purchased_token_item_scene:PackedScene

@onready var token_tray_inventory:TokenTrayInventory = $TokenTrayInventory
@onready var token_grid:GridContainer = %TokenGrid
@onready var player_tray_row:HBoxContainer = %PlayerTrayRow


func _ready() -> void:
	setup_inventory()
	create_shop_cards()
	create_player_trays()

func setup_inventory() -> void:
	if token_tray_inventory == null:
		return
	
	if MatchData.config == null:
		return
	
	token_tray_inventory.setup_for_players(MatchData.config.get_player_count())

func get_player_count() -> int:
	if MatchData.config == null:
		return 0
	
	return MatchData.config.get_player_count()


func create_shop_cards() -> void:
	clear_container(token_grid)
	
	if token_shop_card_scene == null:
		return
	
	var token_types:Array[int] = TokenLibrary.get_lobby_token_types()
	
	for token_type in token_types:
		create_shop_card(token_type)


func create_shop_card(token_type:int) -> void:
	var card:TokenShopCard = token_shop_card_scene.instantiate() as TokenShopCard
	
	if card == null:
		return
	
	token_grid.add_child(card)
	card.setup(token_type)


func create_player_trays() -> void:
	clear_container(player_tray_row)
	
	if lobby_player_tray_scene == null:
		return
	
	var player_count:int = get_player_count()
	
	for player_id in range(player_count):
		create_player_tray(player_id)


func create_player_tray(player_id:int) -> void:
	var tray:LobbyPlayerTray = lobby_player_tray_scene.instantiate() as LobbyPlayerTray
	
	if tray == null:
		return
	
	var player:MatchPlayerData = MatchData.config.get_player(player_id)
	
	if player == null:
		return
	
	tray.purchased_token_item_scene = purchased_token_item_scene
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.size_flags_vertical = Control.SIZE_FILL
	
	player_tray_row.add_child(tray)
	tray.setup(player_id, player, token_tray_inventory)


func clear_container(container:Container) -> void:
	if container == null:
		return
	
	for child in container.get_children():
		child.queue_free()


func _on_player_count_changed(_player_count:int) -> void:
	token_tray_inventory.resize_for_players(get_player_count())
	create_player_trays()
