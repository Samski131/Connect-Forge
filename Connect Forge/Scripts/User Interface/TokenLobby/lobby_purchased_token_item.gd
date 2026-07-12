class_name LobbyPurchasedTokenItem
extends PanelContainer

signal refund_requested(player_id:int, token_type:int)

var player_id:int = -1
var token_type:int = -1
var token_count:int = 0

@onready var token_visual_display:TokenVisualDisplay = %TokenVisualDisplay
@onready var count_label:Label = %CountLabel
@onready var remove_button:Button = %RemoveButton
@onready var juice_player:UIJuicePlayer = get_node_or_null("UIJuicePlayer") as UIJuicePlayer


func _ready() -> void:
	if remove_button != null:
		if remove_button.pressed.is_connected(_on_remove_button_pressed) == false:
			remove_button.pressed.connect(_on_remove_button_pressed)


func setup(new_player_id:int, new_token_type:int, new_count:int) -> void:
	player_id = new_player_id
	token_type = new_token_type
	
	if is_node_ready() == false:
		await ready
	
	token_visual_display.setup(token_type, player_id)
	tooltip_text = TokenLibrary.get_display_name(token_type) + "\n" + TokenLibrary.get_description(token_type)
	set_count(new_count)


func set_count(new_count:int) -> void:
	token_count = max(new_count, 0)
	count_label.text = "x" + str(token_count)


func play_added_feedback() -> void:
	if juice_player == null:
		return
	
	juice_player.play_active()


func _on_remove_button_pressed() -> void:
	refund_requested.emit(player_id, token_type)
