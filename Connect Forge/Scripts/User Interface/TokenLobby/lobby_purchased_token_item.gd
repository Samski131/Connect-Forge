class_name LobbyPurchasedTokenItem
extends PanelContainer

signal refund_requested(player_id:int, token_type:int)

var player_id:int = -1
var token_type:int = -1
var token_count:int = 0
var player_palette:ColorPalette = null
var refund_enabled:bool = true

@onready var token_visual_display:TokenVisualDisplay = %TokenVisualDisplay
@onready var count_label:Label = %CountLabel
@onready var remove_button:Button = %RemoveButton
@onready var juice_player:UIJuicePlayer = get_node_or_null("UIJuicePlayer") as UIJuicePlayer


func _ready() -> void:
	if remove_button != null:
		if remove_button.pressed.is_connected(_on_remove_button_pressed) == false:
			remove_button.pressed.connect(_on_remove_button_pressed)


func setup(new_player_id:int, new_token_type:int, new_count:int, new_player_palette:ColorPalette = null) -> void:
	player_id = new_player_id
	token_type = new_token_type
	player_palette = new_player_palette
	
	if is_node_ready() == false:
		await ready
	
	setup_token_visual()
	setup_tooltip()
	set_count(new_count)
	set_refund_enabled(refund_enabled)


func setup_tooltip() -> void:
	var tooltip_manager:TooltipManager = TooltipManager.find_for(self)
	
	if tooltip_manager == null:
		return
	
	var tooltip_text:String = TokenLibrary.get_display_name(token_type) + "\n" + TokenLibrary.get_description(token_type)
	tooltip_manager.register_tooltip(self, tooltip_text)


func set_refund_enabled(is_enabled:bool) -> void:
	refund_enabled = is_enabled
	
	if remove_button != null:
		remove_button.disabled = refund_enabled == false
		
		if refund_enabled:
			remove_button.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			remove_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup_token_visual() -> void:
	if token_visual_display == null:
		return
	
	if player_palette == null:
		token_visual_display.setup(token_type, player_id)
		return
	
	token_visual_display.setup_with_palette(token_type, player_id, player_palette)


func set_count(new_count:int) -> void:
	token_count = max(new_count, 0)
	
	if count_label != null:
		count_label.text = "x" + str(token_count)


func play_added_feedback() -> void:
	if juice_player == null:
		return
	
	juice_player.play_active()


func _on_remove_button_pressed() -> void:
	if refund_enabled == false:
		return
	
	refund_requested.emit(player_id, token_type)
