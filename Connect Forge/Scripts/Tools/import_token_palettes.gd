@tool
extends EditorScript

const PALETTE_TEXT_PATH:String = "res://Scenes/Tokens/token colour resources/token_palettes.txt"
const PALETTE_OUTPUT_DIRECTORY:String = "res://Scenes/Tokens/token colour resources"
const REQUIRED_COLOUR_COUNT:int = 7


func _run() -> void:
	print("")
	print("--- TOKEN PALETTE IMPORT ---")
	
	if FileAccess.file_exists(PALETTE_TEXT_PATH) == false:
		push_error("Palette text file was not found: " + PALETTE_TEXT_PATH)
		return
	
	var file:FileAccess = FileAccess.open(PALETTE_TEXT_PATH, FileAccess.READ)
	
	if file == null:
		push_error("Could not open palette text file: " + PALETTE_TEXT_PATH)
		return
	
	var imported_count:int = 0
	var failed_count:int = 0
	var line_number:int = 0
	
	while file.eof_reached() == false:
		line_number += 1
		
		var raw_line:String = file.get_line()
		var line:String = raw_line.strip_edges()
		
		if line == "":
			continue
		
		if line.begins_with("#"):
			continue
		
		if import_palette_line(line, line_number):
			imported_count += 1
		else:
			failed_count += 1
	
	file.close()
	
	get_editor_interface().get_resource_filesystem().scan()
	
	print("")
	print("Imported palettes: " + str(imported_count))
	print("Failed palettes: " + str(failed_count))
	print("--- IMPORT COMPLETE ---")


func import_palette_line(line:String, line_number:int) -> bool:
	var separator_index:int = line.find(":")
	
	if separator_index == -1:
		report_line_error(line_number, "Missing ':' separator.")
		return false
	
	var palette_name:String = line.substr(0, separator_index).strip_edges()
	var colour_text:String = line.substr(separator_index + 1).strip_edges()
	
	if is_valid_palette_name(palette_name) == false:
		report_line_error(line_number, "Invalid palette name: " + palette_name)
		return false
	
	var colour_strings:PackedStringArray = colour_text.split(",", false)
	
	if colour_strings.size() != REQUIRED_COLOUR_COUNT:
		report_line_error(line_number, "Palette '" + palette_name + "' contains " + str(colour_strings.size()) + " colours. Expected " + str(REQUIRED_COLOUR_COUNT) + ".")
		return false
	
	var parsed_colours:PackedColorArray = PackedColorArray()
	
	for colour_index in range(colour_strings.size()):
		var colour_string:String = colour_strings[colour_index].strip_edges()
		
		if Color.html_is_valid(colour_string) == false:
			report_line_error(line_number, "Invalid colour at index " + str(colour_index + 1) + ": " + colour_string)
			return false
		
		var parsed_colour:Color = Color.from_string(colour_string, Color.TRANSPARENT)
		parsed_colours.append(parsed_colour)
	
	var resource_path:String = PALETTE_OUTPUT_DIRECTORY.path_join(palette_name + ".tres")
	var palette:ColorPalette = load_existing_palette(resource_path)
	
	if palette == null:
		palette = ColorPalette.new()
		print("Creating: " + resource_path)
	else:
		print("Overwriting: " + resource_path)
	
	palette.colors = parsed_colours
	
	var save_error:Error = ResourceSaver.save(palette, resource_path)
	
	if save_error != OK:
		report_line_error(line_number, "Could not save '" + resource_path + "'. Error code: " + str(save_error))
		return false
	
	print_palette_colours(palette_name, parsed_colours)
	return true


func load_existing_palette(resource_path:String) -> ColorPalette:
	if ResourceLoader.exists(resource_path) == false:
		return null
	
	var resource:Resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var palette:ColorPalette = resource as ColorPalette
	
	if palette == null:
		push_error("Existing resource is not a ColorPalette: " + resource_path)
		return null
	
	return palette


func is_valid_palette_name(palette_name:String) -> bool:
	if palette_name == "":
		return false
	
	for character in palette_name:
		var is_lowercase_letter:bool = character >= "a" and character <= "z"
		var is_number:bool = character >= "0" and character <= "9"
		var is_underscore:bool = character == "_"
		
		if is_lowercase_letter == false and is_number == false and is_underscore == false:
			return false
	
	return true


func print_palette_colours(palette_name:String, colours:PackedColorArray) -> void:
	print("  " + palette_name + ":")
	
	for colour_index in range(colours.size()):
		print("    " + str(colour_index + 1) + ": #" + colours[colour_index].to_html(false).to_upper())


func report_line_error(line_number:int, message:String) -> void:
	push_error("Palette file line " + str(line_number) + ": " + message)
