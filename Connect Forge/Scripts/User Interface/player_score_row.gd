class_name PlayerScoreRow
extends PanelContainer

enum RowPosition {
	ONLY,
	FIRST,
	MIDDLE,
	LAST
}

const LIGHT_ROW_STYLE:StyleBox = preload("res://Assets/User Interface/Resources/Theme Presets/Game Over Menu/Light_Player_Row_Panel.stylebox")
const DARK_ROW_STYLE:StyleBox = preload("res://Assets/User Interface/Resources/Theme Presets/Game Over Menu/Dark_Player_Row_Panel.stylebox")
const STRIP_STYLE:StyleBox = preload("res://Assets/User Interface/Resources/Theme Presets/Game Over Menu/colour chip on score panel.stylebox")

const CORNER_RADIUS:int = 16
const STRIP_PALETTE_INDEX:int = 2

@onready var colour_strip:PanelContainer = %ColourStrip
@onready var token_visual_display:TokenVisualDisplay = $"PlayerRowHbox/Token Holder/Token Visual Display"
@onready var player_name_label:Label = $PlayerRowHbox/PlayerNameLabel
@onready var winner_star_label:Label = $PlayerRowHbox/WinnerStarLabel
@onready var score_label:Label = $PlayerRowHbox/MarginContainer/ScoreLabel

var stored_player_id:int = -1
var stored_player_name:String = ""
var stored_player_score:int = 0
var stored_player_palette:ColorPalette = null
var stored_is_winner:bool = false
var stored_row_position:RowPosition = RowPosition.MIDDLE
var has_setup_data:bool = false


func _ready() -> void:
	clip_contents = true
	
	if has_setup_data:
		apply_setup()


func setup(player_id:int, player_name:String, player_score:int, player_palette:ColorPalette, is_winner:bool, row_position:RowPosition) -> void:
	stored_player_id = player_id
	stored_player_name = player_name
	stored_player_score = player_score
	stored_player_palette = player_palette
	stored_is_winner = is_winner
	stored_row_position = row_position
	has_setup_data = true
	
	if is_node_ready():
		apply_setup()


func apply_setup() -> void:
	if has_setup_data == false:
		return
	
	setup_text()
	setup_token()
	setup_row_style()
	setup_colour_strip()


func setup_text() -> void:
	if player_name_label != null:
		player_name_label.text = stored_player_name
	
	if score_label != null:
		score_label.text = str(stored_player_score)
	
	if winner_star_label == null:
		return
	
	winner_star_label.visible = stored_is_winner
	
	if stored_is_winner == false:
		return
	
	var star_colour:Color = get_palette_colour(stored_player_palette, STRIP_PALETTE_INDEX, Color.WHITE)
	var current_settings:LabelSettings = winner_star_label.label_settings
	
	if current_settings == null:
		return
	
	var star_settings:LabelSettings = current_settings.duplicate(true) as LabelSettings
	
	if star_settings == null:
		return
	
	star_settings.font_color = star_colour
	winner_star_label.label_settings = star_settings


func setup_token() -> void:
	if token_visual_display == null:
		return
	
	if stored_player_palette == null:
		token_visual_display.setup(TokenLibrary.TokenType.BASIC, stored_player_id, false)
		return
	
	token_visual_display.setup_with_palette(TokenLibrary.TokenType.BASIC, stored_player_id, stored_player_palette, false)


func setup_row_style() -> void:
	var source_style:StyleBox = LIGHT_ROW_STYLE
	
	if stored_is_winner:
		source_style = DARK_ROW_STYLE
	
	if source_style == null:
		return
	
	var row_style:StyleBoxFlat = source_style.duplicate() as StyleBoxFlat
	
	if row_style == null:
		push_error("PlayerScoreRow: Player row style must be a StyleBoxFlat.")
		return
	
	clear_corner_radii(row_style)
	apply_row_corners(row_style, stored_row_position)
	add_theme_stylebox_override("panel", row_style)


func setup_colour_strip() -> void:
	if colour_strip == null:
		push_error("PlayerScoreRow: ColourStrip node was not found.")
		return
	
	var strip_style:StyleBoxFlat = STRIP_STYLE.duplicate(true) as StyleBoxFlat
	
	if strip_style == null:
		push_error("PlayerScoreRow: STRIP_STYLE must be a StyleBoxFlat.")
		return
	
	strip_style.bg_color = get_palette_colour(stored_player_palette, STRIP_PALETTE_INDEX, Color.WHITE)
	strip_style.draw_center = true
	strip_style.border_width_left = 0
	strip_style.border_width_top = 0
	strip_style.border_width_right = 0
	strip_style.border_width_bottom = 0
	
	clear_corner_radii(strip_style)
	apply_strip_corners(strip_style, stored_row_position)
	colour_strip.add_theme_stylebox_override("panel", strip_style)


func clear_corner_radii(style:StyleBoxFlat) -> void:
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0


func apply_row_corners(style:StyleBoxFlat, row_position:RowPosition) -> void:
	if row_position == RowPosition.ONLY:
		style.corner_radius_top_left = CORNER_RADIUS
		style.corner_radius_top_right = CORNER_RADIUS
		style.corner_radius_bottom_left = CORNER_RADIUS
		style.corner_radius_bottom_right = CORNER_RADIUS
		return
	
	if row_position == RowPosition.FIRST:
		style.corner_radius_top_left = CORNER_RADIUS
		style.corner_radius_top_right = CORNER_RADIUS
		return
	
	if row_position == RowPosition.LAST:
		style.corner_radius_bottom_left = CORNER_RADIUS
		style.corner_radius_bottom_right = CORNER_RADIUS


func apply_strip_corners(style:StyleBoxFlat, row_position:RowPosition) -> void:
	if row_position == RowPosition.ONLY:
		style.corner_radius_top_left = CORNER_RADIUS
		style.corner_radius_bottom_left = CORNER_RADIUS
		return
	
	if row_position == RowPosition.FIRST:
		style.corner_radius_top_left = CORNER_RADIUS
		return
	
	if row_position == RowPosition.LAST:
		style.corner_radius_bottom_left = CORNER_RADIUS


func get_palette_colour(palette:ColorPalette, colour_index:int, fallback:Color) -> Color:
	if palette == null:
		return fallback
	
	if colour_index < 0:
		return fallback
	
	if colour_index >= palette.colors.size():
		return fallback
	
	return palette.colors[colour_index]
