extends CanvasLayer

const MAXIMUM_MESSAGE_COUNT:int = 300
const LOG_FILE_PATH:String = "user://multiplayer_debug.log"
const SHOW_PANEL_ON_STARTUP:bool = false

var messages:Array[String] = []

var panel_is_visible:bool = false
var interface_is_ready:bool = false

var root_control:Control = null
var toggle_button:Button = null
var debug_panel:PanelContainer = null
var output_label:RichTextLabel = null
var status_label:Label = null

var log_file:FileAccess = null


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_open_log_file()
	_build_interface()
	
	interface_is_ready = true
	set_panel_visible(SHOW_PANEL_ON_STARTUP)
	
	_log_startup_information()
	_refresh_output()


func _input(event:InputEvent) -> void:
	var key_event:InputEventKey = event as InputEventKey
	
	if key_event == null:
		return
	
	if key_event.pressed == false:
		return
	
	if key_event.echo:
		return
	
	if key_event.keycode != KEY_F3:
		return
	
	toggle_panel()
	get_viewport().set_input_as_handled()


func log_message(source:String, message:String) -> void:
	var console_message:String = _create_console_message(source, message)
	print(console_message)
	_store_message("INFO", source, message)


func log_warning(source:String, message:String) -> void:
	var console_message:String = _create_console_message(source, message)
	push_warning(console_message)
	_store_message("WARNING", source, message)


func log_error(source:String, message:String) -> void:
	var console_message:String = _create_console_message(source, message)
	push_error(console_message)
	_store_message("ERROR", source, message)


func add_message(source:String, message:String) -> void:
	_store_message("INFO", source, message)


func toggle_panel() -> void:
	set_panel_visible(panel_is_visible == false)


func show_panel() -> void:
	set_panel_visible(true)


func hide_panel() -> void:
	set_panel_visible(false)


func set_panel_visible(should_be_visible:bool) -> void:
	panel_is_visible = should_be_visible
	
	if debug_panel != null:
		debug_panel.visible = panel_is_visible
	
	if toggle_button == null:
		return
	
	if panel_is_visible:
		toggle_button.text = "Hide Debug Logs  F3"
	else:
		toggle_button.text = "Debug Logs  F3"


func clear_messages() -> void:
	messages.clear()
	_open_log_file()
	_store_message("INFO", "DebugOverlay", "Debug log cleared.")


func get_log_text() -> String:
	var result:String = ""
	
	for message_index in range(messages.size()):
		if message_index > 0:
			result += "\n"
		
		result += messages[message_index]
	
	return result


func _store_message(level:String, source:String, message:String) -> void:
	var used_source:String = source.strip_edges()
	var used_message:String = message.strip_edges()
	
	if used_source == "":
		used_source = "General"
	
	if used_message == "":
		return
	
	var time_string:String = Time.get_time_string_from_system()
	var formatted_message:String = "[%s] [%s] [%s] %s" % [time_string, level, used_source, used_message]
	
	messages.append(formatted_message)
	
	while messages.size() > MAXIMUM_MESSAGE_COUNT:
		messages.pop_front()
	
	_write_log_line(formatted_message)
	
	if interface_is_ready:
		_refresh_output()


func _create_console_message(source:String, message:String) -> String:
	var used_source:String = source.strip_edges()
	
	if used_source == "":
		used_source = "General"
	
	return "[%s] %s" % [used_source, message]


func _open_log_file() -> void:
	log_file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	
	if log_file == null:
		return
	
	log_file.store_line("Multiplayer debug log")
	log_file.store_line("=====================")
	log_file.flush()


func _write_log_line(message:String) -> void:
	if log_file == null:
		return
	
	log_file.store_line(message)
	log_file.flush()


func _log_startup_information() -> void:
	var engine_version:Dictionary = Engine.get_version_info()
	var engine_version_string:String = str(engine_version.get("string", "Unknown"))
	var project_version:String = str(ProjectSettings.get_setting("application/config/version", "development"))
	var executable_name:String = OS.get_executable_path().get_file()
	
	log_message("DebugOverlay", "Debug overlay initialised. Press F3 to show or hide it.")
	log_message("System", "Godot version: %s" % engine_version_string)
	log_message("System", "Operating system: %s" % OS.get_name())
	log_message("System", "Debug build: %s" % str(OS.is_debug_build()))
	log_message("System", "Project version: %s" % project_version)
	log_message("System", "Executable: %s" % executable_name)
	log_message("System", "Persistent log: user://multiplayer_debug.log")


func _build_interface() -> void:
	root_control = Control.new()
	root_control.name = "Debug Overlay Root"
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_create_toggle_button()
	_create_debug_panel()


func _create_toggle_button() -> void:
	toggle_button = Button.new()
	toggle_button.name = "Debug Toggle Button"
	toggle_button.text = "Debug Logs  F3"
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle_button.add_theme_font_size_override("font_size", 17)
	
	root_control.add_child(toggle_button)
	
	toggle_button.set_anchor(SIDE_LEFT, 1.0)
	toggle_button.set_anchor(SIDE_TOP, 0.0)
	toggle_button.set_anchor(SIDE_RIGHT, 1.0)
	toggle_button.set_anchor(SIDE_BOTTOM, 0.0)
	
	toggle_button.offset_left = -188.0
	toggle_button.offset_top = 12.0
	toggle_button.offset_right = -12.0
	toggle_button.offset_bottom = 52.0
	
	toggle_button.pressed.connect(toggle_panel)


func _create_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "Debug Panel"
	debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var panel_style:StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.035, 0.065, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.31, 0.55, 0.76, 1.0)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	
	debug_panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(debug_panel)
	
	debug_panel.set_anchor(SIDE_LEFT, 0.50)
	debug_panel.set_anchor(SIDE_TOP, 0.08)
	debug_panel.set_anchor(SIDE_RIGHT, 0.99)
	debug_panel.set_anchor(SIDE_BOTTOM, 0.60)
	
	debug_panel.offset_left = 0.0
	debug_panel.offset_top = 0.0
	debug_panel.offset_right = 0.0
	debug_panel.offset_bottom = 0.0
	
	var panel_margin:MarginContainer = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_top", 12)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 12)
	debug_panel.add_child(panel_margin)
	
	var main_layout:VBoxContainer = VBoxContainer.new()
	main_layout.add_theme_constant_override("separation", 10)
	panel_margin.add_child(main_layout)
	
	var header:HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main_layout.add_child(header)
	
	var title_label:Label = Label.new()
	title_label.text = "Multiplayer Debug Log"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0, 1.0))
	header.add_child(title_label)
	
	var copy_button:Button = Button.new()
	copy_button.text = "Copy"
	copy_button.focus_mode = Control.FOCUS_NONE
	copy_button.pressed.connect(_on_copy_button_pressed)
	header.add_child(copy_button)
	
	var clear_button:Button = Button.new()
	clear_button.text = "Clear"
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.pressed.connect(clear_messages)
	header.add_child(clear_button)
	
	var hide_button:Button = Button.new()
	hide_button.text = "Hide"
	hide_button.focus_mode = Control.FOCUS_NONE
	hide_button.pressed.connect(hide_panel)
	header.add_child(hide_button)
	
	status_label = Label.new()
	status_label.text = "F3 toggles this panel. The log is also written to user://multiplayer_debug.log."
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.60, 0.72, 0.82, 1.0))
	main_layout.add_child(status_label)
	
	output_label = RichTextLabel.new()
	output_label.name = "Debug Output"
	output_label.bbcode_enabled = false
	output_label.selection_enabled = true
	output_label.context_menu_enabled = true
	output_label.scroll_active = true
	output_label.scroll_following = true
	output_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.add_theme_font_size_override("normal_font_size", 16)
	output_label.add_theme_color_override("default_color", Color(0.86, 0.90, 0.94, 1.0))
	main_layout.add_child(output_label)


func _refresh_output() -> void:
	if output_label == null:
		return
	
	output_label.text = get_log_text()


func _on_copy_button_pressed() -> void:
	DisplayServer.clipboard_set(get_log_text())
	
	if status_label == null:
		return
	
	status_label.text = "Copied %d debug messages to the clipboard." % messages.size()
