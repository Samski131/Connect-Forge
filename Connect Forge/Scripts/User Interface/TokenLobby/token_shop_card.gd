class_name TokenShopCard
extends PanelContainer

@export var token_type:int = TokenLibrary.TokenType.ANVIL
@export var display_palette:ColorPalette = load("res://Scenes/Tokens/token colour resources/blue_v3.tres")

@onready var token_visual_display:TokenVisualDisplay = %TokenVisualDisplay
@onready var token_name_label:Label = %TokenNameLabel
@onready var cost_label:Label = %CostLabel
@onready var juice_player:UIJuicePlayer = %UIJuicePlayer

var mouse_mode_before_drag:Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var lobby_drag_active:bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(new_token_type:int) -> void:
	token_type = new_token_type
	
	if is_node_ready() == false:
		return
	
	var token_name:String = TokenLibrary.get_display_name(token_type)
	var cost:int = TokenLibrary.get_cost(token_type)
	
	token_name_label.text = token_name
	cost_label.text = str(cost)
	
	setup_tooltip()
	token_visual_display.setup_with_palette(token_type, -1, display_palette)


func setup_tooltip() -> void:
	var tooltip_manager:TooltipManager = TooltipManager.find_for(self)
	
	if tooltip_manager == null:
		return
	
	var token_name:String = TokenLibrary.get_display_name(token_type)
	var description:String = TokenLibrary.get_description(token_type)
	var cost:int = TokenLibrary.get_cost(token_type)
	var tooltip_text:String = token_name + "\n" + description + "\nCost: " + str(cost)
	
	tooltip_manager.register_tooltip(self, tooltip_text)


func _get_drag_data(_at_position:Vector2):
	if TokenLibrary.is_available_in_lobby(token_type) == false:
		play_invalid_feedback()
		return null
	
	var drag_data:Dictionary = {
		"drag_type": "lobby_token_purchase",
		"token_type": token_type,
		"cost": TokenLibrary.get_cost(token_type),
		"source_card": self
	}
	
	mouse_mode_before_drag = Input.get_mouse_mode()
	lobby_drag_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	set_drag_preview(create_drag_preview())
	return drag_data


func create_drag_preview() -> Control:
	var preview_size:Vector2 = Vector2(150, 150)
	var preview_root:Control = Control.new()
	var preview_container:Control = Control.new()
	var preview_visual:TokenVisualDisplay = TokenVisualDisplay.new()
	
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.custom_minimum_size = Vector2.ZERO
	preview_root.size = Vector2.ZERO
	
	preview_container.position = -preview_size * 0.5
	preview_container.custom_minimum_size = preview_size
	preview_container.size = preview_size
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	preview_root.add_child(preview_container)
	preview_container.add_child(preview_visual)
	
	preview_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_visual.visual_scale = 0.35
	preview_visual.setup_with_palette(token_type, -1, display_palette)
	
	return preview_root


func play_invalid_feedback() -> void:
	if juice_player == null:
		return
	
	juice_player.play_invalid()


func _notification(what:int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	
	if lobby_drag_active == false:
		return
	
	lobby_drag_active = false
	Input.set_mouse_mode(mouse_mode_before_drag)


func _exit_tree() -> void:
	if lobby_drag_active == false:
		return
	
	Input.set_mouse_mode(mouse_mode_before_drag)
