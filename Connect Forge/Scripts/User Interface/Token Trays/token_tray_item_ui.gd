class_name TokenTrayItemUI
extends PanelContainer

var player_id:int = -1
var token_type:int = -1
var game_manager:Node = null
var token_tray_model:TokenTrayModel = null

@onready var icon_rect = $"Margin/Root (Vbox)/Icon Control/Icon (Texture Rect)"
@onready var count_label = $"Margin/Root (Vbox)/Icon Control/PanelContainer/Count Label"
@onready var count_badge = $"Margin/Root (Vbox)/Icon Control/Count Badge Panel"

func setup(new_game_manager:Node, new_player_id:int, new_token_type:int) -> void:
	game_manager = new_game_manager
	player_id = new_player_id
	token_type = new_token_type
	
	if game_manager != null:
		var model_value = game_manager.get("token_tray_model")
		
		if model_value is TokenTrayModel:
			token_tray_model = model_value as TokenTrayModel
	
	refresh()


func refresh() -> void:
	if token_tray_model == null:
		return
	
	var icon_texture:Texture2D = token_tray_model.get_token_icon(token_type)
	var token_count:int = token_tray_model.get_token_count(player_id, token_type)
	var token_name:String = token_tray_model.get_token_display_name(token_type)
	
	icon_rect.texture = icon_texture
	count_label.text = str(token_count)
	tooltip_text = token_tray_model.get_token_description(token_type)
	
	apply_count_visual(token_count)


func apply_count_visual(token_count:int) -> void:
	if token_count <= 0:
		modulate = Color(0.35, 0.35, 0.35, 0.75)
		return
	
	modulate = Color.WHITE
