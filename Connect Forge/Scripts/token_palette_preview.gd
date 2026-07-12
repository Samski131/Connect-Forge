extends Control

const PALETTE_DIRECTORY:String = "res://Scenes/Tokens/token colour resources"
const PALETTE_EXTENSION:String = ".tres"

@export_group("Grid")
@export var grid_columns:int = 7
@export var item_minimum_size:Vector2 = Vector2(240.0, 280.0)

@export_group("Token")
@export var token_visual_size:Vector2 = Vector2(220.0, 220.0)
@export var token_visual_scale:float = 0.5

@export_group("Labels")
@export var label_font_size:int = 24

@onready var palette_grid:GridContainer = $Background/ScreenMargin/Layout/PaletteScroll/PaletteGrid


func _ready() -> void:
	if palette_grid == null:
		push_error("TokenPalettePreview could not find PaletteGrid.")
		return
	
	palette_grid.columns = max(grid_columns, 1)
	clear_grid()
	build_palette_grid()


func clear_grid() -> void:
	for child in palette_grid.get_children():
		child.queue_free()


func build_palette_grid() -> void:
	var palette_paths:Array[String] = get_palette_paths()
	
	if palette_paths.is_empty():
		push_warning("No colour palettes were found in: " + PALETTE_DIRECTORY)
		return
	
	for palette_path in palette_paths:
		create_palette_item(palette_path)


func get_palette_paths() -> Array[String]:
	var palette_paths:Array[String] = []
	var directory:DirAccess = DirAccess.open(PALETTE_DIRECTORY)
	
	if directory == null:
		push_error("Could not open palette directory: " + PALETTE_DIRECTORY)
		return palette_paths
	
	directory.list_dir_begin()
	
	var file_name:String = directory.get_next()
	
	while file_name != "":
		if directory.current_is_dir() == false and file_name.ends_with(PALETTE_EXTENSION):
			palette_paths.append(PALETTE_DIRECTORY.path_join(file_name))
		
		file_name = directory.get_next()
	
	directory.list_dir_end()
	palette_paths.sort()
	
	return palette_paths


func create_palette_item(palette_path:String) -> void:
	var palette:ColorPalette = load(palette_path) as ColorPalette
	
	if palette == null:
		push_warning("Could not load palette: " + palette_path)
		return
	
	var item:VBoxContainer = VBoxContainer.new()
	item.name = get_palette_display_name(palette_path)
	item.custom_minimum_size = item_minimum_size
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	item.add_theme_constant_override("separation", 8)
	palette_grid.add_child(item)
	
	var token_display:TokenVisualDisplay = TokenVisualDisplay.new()
	token_display.name = "Anvil Display"
	token_display.custom_minimum_size = token_visual_size
	token_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	token_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	token_display.visual_scale = token_visual_scale
	item.add_child(token_display)
	
	var palette_label:Label = Label.new()
	palette_label.name = "Palette Name"
	palette_label.text = get_palette_display_name(palette_path)
	palette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	palette_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	palette_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_label.add_theme_font_size_override("font_size", label_font_size)
	item.add_child(palette_label)
	
	token_display.setup_with_palette(TokenLibrary.TokenType.ANVIL, -1, palette)


func get_palette_display_name(palette_path:String) -> String:
	var file_name:String = palette_path.get_file().get_basename()
	var words:PackedStringArray = file_name.replace("-", " ").replace("_", " ").split(" ", false)
	var formatted_words:Array[String] = []
	
	for word in words:
		formatted_words.append(word.capitalize())
	
	return " ".join(formatted_words)
