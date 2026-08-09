class_name CursorTextureGenerator
extends RefCounted

const DARK_MAIN_TEXTURE:Texture2D = preload("res://Assets/User Interface/cursor/Cursor parts/dark main.png")
const OUTLINE_TEXTURE:Texture2D = preload("res://Assets/User Interface/cursor/Cursor parts/Outline.png")
const BRIGHT_MAIN_TEXTURE:Texture2D = preload("res://Assets/User Interface/cursor/Cursor parts/Bright main.png")
const OUTLINE_HIGHLIGHT_TEXTURE:Texture2D = preload("res://Assets/User Interface/cursor/Cursor parts/Outline highlight.png")

const BRIGHT_MAIN_PALETTE_INDEX:int = 1
const DARK_MAIN_PALETTE_INDEX:int = 2

const OUTLINE_COLOUR:Color = Color(0.90, 0.93, 0.94, 1.0)
const OUTLINE_HIGHLIGHT_COLOUR:Color = Color.WHITE

const SOURCE_WIDTH:int = 71
const SOURCE_HEIGHT:int = 96


func create_cursor_texture(palette:ColorPalette, cursor_scale:float = 0.70) -> Texture2D:
	if palette == null:
		return null
	
	if palette.colors.is_empty():
		return null
	
	var bright_colour:Color = get_palette_colour(
		palette,
		BRIGHT_MAIN_PALETTE_INDEX,
		Color.WHITE
	)
	
	var dark_colour:Color = get_palette_colour(
		palette,
		DARK_MAIN_PALETTE_INDEX,
		Color(0.3, 0.3, 0.3, 1.0)
	)
	
	var result_image:Image = Image.create(
		SOURCE_WIDTH,
		SOURCE_HEIGHT,
		false,
		Image.FORMAT_RGBA8
	)
	
	result_image.fill(Color.TRANSPARENT)
	
	blend_tinted_layer(
		result_image,
		DARK_MAIN_TEXTURE,
		dark_colour
	)
	
	blend_tinted_layer(
		result_image,
		OUTLINE_TEXTURE,
		OUTLINE_COLOUR
	)
	
	blend_tinted_layer(
		result_image,
		BRIGHT_MAIN_TEXTURE,
		bright_colour
	)
	
	blend_tinted_layer(
		result_image,
		OUTLINE_HIGHLIGHT_TEXTURE,
		OUTLINE_HIGHLIGHT_COLOUR
	)
	
	resize_cursor_image(result_image, cursor_scale)
	
	return ImageTexture.create_from_image(result_image)


func blend_tinted_layer(destination:Image, source_texture:Texture2D, tint_colour:Color) -> void:
	if destination == null:
		return
	
	if source_texture == null:
		return
	
	var source_image:Image = source_texture.get_image()
	
	if source_image == null:
		return
	
	if source_image.is_empty():
		return
	
	if source_image.is_compressed():
		var decompress_result:Error = source_image.decompress()
		
		if decompress_result != OK:
			return
	
	source_image.convert(Image.FORMAT_RGBA8)
	tint_image(source_image, tint_colour)
	
	var source_rect:Rect2i = Rect2i(
		Vector2i.ZERO,
		source_image.get_size()
	)
	
	destination.blend_rect(
		source_image,
		source_rect,
		Vector2i.ZERO
	)


func tint_image(image:Image, tint_colour:Color) -> void:
	if image == null:
		return
	
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var source_colour:Color = image.get_pixel(x, y)
			
			if source_colour.a <= 0.0:
				continue
			
			var tinted_colour:Color = Color(
				source_colour.r * tint_colour.r,
				source_colour.g * tint_colour.g,
				source_colour.b * tint_colour.b,
				source_colour.a * tint_colour.a
			)
			
			image.set_pixel(x, y, tinted_colour)


func resize_cursor_image(image:Image, cursor_scale:float) -> void:
	if image == null:
		return
	
	var used_scale:float = clamp(cursor_scale, 0.25, 1.5)
	
	if is_equal_approx(used_scale, 1.0):
		return
	
	var new_width:int = max(
		int(round(float(SOURCE_WIDTH) * used_scale)),
		1
	)
	
	var new_height:int = max(
		int(round(float(SOURCE_HEIGHT) * used_scale)),
		1
	)
	
	image.resize(
		new_width,
		new_height,
		Image.INTERPOLATE_LANCZOS
	)


func get_palette_colour(palette:ColorPalette, palette_index:int, fallback_colour:Color) -> Color:
	if palette == null:
		return fallback_colour
	
	if palette_index < 0:
		return fallback_colour
	
	if palette_index >= palette.colors.size():
		return fallback_colour
	
	return palette.colors[palette_index]
