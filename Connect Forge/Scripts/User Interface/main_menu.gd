extends CanvasLayer

const HOST_MENU_SCENE_PATH:String = "res://Scenes/User Interface/host_menu.tscn"
const SERVER_LIST_SCENE_PATH:String = "res://Scenes/User Interface/server list.tscn"

const REPLAYS_SCENE_PATH:String = "res://Scenes/User Interface/replays.tscn"
const TOKEN_CODEX_SCENE_PATH:String = "res://Scenes/User Interface/token_codex.tscn"
const SETTINGS_POPUP_SCENE_PATH:String = "res://Scenes/User Interface/settings_menu.tscn"

const YOUTUBE_URL:String = "https://www.youtube.com/"
const DISCORD_URL:String = "https://discord.com/"
const STEAM_URL:String = "https://store.steampowered.com/"

const POPUP_Z_INDEX:int = 100

@onready var host_game_button:Button = find_child("Host Game Button", true, false) as Button
@onready var join_game_button:Button = find_child("Join Game Button", true, false) as Button
@onready var replays_button:Button = find_child("Replays Button", true, false) as Button
@onready var token_codex_button:Button = find_child("Token Codex Button", true, false) as Button
@onready var settings_button:Button = find_child("Settings Button", true, false) as Button
@onready var quit_button:Button = find_child("Quit Button", true, false) as Button

@onready var discord_button:Button = find_child("Discord Button", true, false) as Button
@onready var youtube_button:Button = find_child("YouTube Button", true, false) as Button
@onready var steam_button:Button = find_child("Steam Button", true, false) as Button

var active_popup:Node = null
var scene_change_requested:bool = false


func _ready() -> void:
	connect_button(host_game_button, Callable(self, "_on_host_game_pressed"), "Host Game Button")
	connect_button(join_game_button, Callable(self, "_on_join_game_pressed"), "Join Game Button")
	connect_button(replays_button, Callable(self, "_on_replays_pressed"), "Replays Button")
	connect_button(token_codex_button, Callable(self, "_on_token_codex_pressed"), "Token Codex Button")
	connect_button(settings_button, Callable(self, "_on_settings_pressed"), "Settings Button")
	connect_button(quit_button, Callable(self, "_on_quit_pressed"), "Quit Button")
	
	connect_button(discord_button, Callable(self, "_on_discord_pressed"), "Discord Button")
	connect_button(youtube_button, Callable(self, "_on_youtube_pressed"), "YouTube Button")
	connect_button(steam_button, Callable(self, "_on_steam_pressed"), "Steam Button")


func connect_button(button:Button, callback:Callable, button_name:String) -> void:
	if button == null:
		push_error("MainMenu: Could not find " + button_name + ".")
		return
	
	if button.pressed.is_connected(callback):
		return
	
	button.pressed.connect(callback)


func _on_host_game_pressed() -> void:
	open_popup_scene(HOST_MENU_SCENE_PATH, "host menu")


func _on_join_game_pressed() -> void:
	change_to_scene(SERVER_LIST_SCENE_PATH, "server list")


func _on_replays_pressed() -> void:
	change_to_scene(REPLAYS_SCENE_PATH, "replays")


func _on_token_codex_pressed() -> void:
	change_to_scene(TOKEN_CODEX_SCENE_PATH, "token codex")


func _on_settings_pressed() -> void:
	open_popup_scene(SETTINGS_POPUP_SCENE_PATH, "settings menu")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_discord_pressed() -> void:
	open_website(DISCORD_URL, "Discord")


func _on_youtube_pressed() -> void:
	open_website(YOUTUBE_URL, "YouTube")


func _on_steam_pressed() -> void:
	open_website(STEAM_URL, "Steam")


func change_to_scene(scene_path:String, scene_name:String) -> void:
	if scene_change_requested:
		return
	
	if is_valid_scene_path(scene_path, scene_name) == false:
		return
	
	scene_change_requested = true
	set_navigation_buttons_disabled(true)
	
	var change_error:Error = get_tree().change_scene_to_file(scene_path)
	
	if change_error == OK:
		return
	
	scene_change_requested = false
	set_navigation_buttons_disabled(false)
	
	push_error(
		"MainMenu: Could not change to the " +
		scene_name +
		" scene. Error code: " +
		str(change_error)
	)


func open_popup_scene(scene_path:String, popup_name:String) -> void:
	if active_popup != null:
		if is_instance_valid(active_popup):
			return
		
		active_popup = null
	
	if is_valid_scene_path(scene_path, popup_name) == false:
		return
	
	var popup_resource:Resource = load(scene_path)
	var popup_scene:PackedScene = popup_resource as PackedScene
	
	if popup_scene == null:
		push_error("MainMenu: " + scene_path + " is not a PackedScene.")
		return
	
	active_popup = popup_scene.instantiate()
	
	if active_popup == null:
		push_error("MainMenu: Could not instantiate the " + popup_name + ".")
		return
	
	var popup_control:Control = active_popup as Control
	
	if popup_control != null:
		popup_control.z_index = POPUP_Z_INDEX
		popup_control.z_as_relative = false
	
	add_child(active_popup)
	active_popup.tree_exited.connect(_on_active_popup_tree_exited, CONNECT_ONE_SHOT)
	
	call_deferred("play_active_popup_enter")


func play_active_popup_enter() -> void:
	if active_popup == null:
		return
	
	if is_instance_valid(active_popup) == false:
		active_popup = null
		return
	
	play_active_popup_backdrop_enter()
	play_active_popup_panel_enter()


func play_active_popup_backdrop_enter() -> void:
	if active_popup == null:
		return
	
	var backdrop:Control = active_popup.get_node_or_null("Backdrop") as Control
	
	if backdrop == null:
		return
	
	var backdrop_player:UIJuicePlayer = backdrop.get_node_or_null("UIJuicePlayer") as UIJuicePlayer
	
	if backdrop_player != null:
		backdrop_player.enter()
		return
	
	backdrop.visible = true
	backdrop.modulate.a = 1.0


func play_active_popup_panel_enter() -> void:
	if active_popup == null:
		return
	
	var popup_player:UIJuicePlayer = active_popup.get_node_or_null("%UIJuicePlayer") as UIJuicePlayer
	
	if popup_player != null:
		popup_player.enter()
		return
	
	var popup_root:Control = active_popup.get_node_or_null("PopupCenter/PopupRoot") as Control
	
	if popup_root != null:
		popup_root.visible = true
		popup_root.modulate.a = 1.0


func is_valid_scene_path(scene_path:String, scene_name:String) -> bool:
	if scene_path.strip_edges() == "":
		push_warning("MainMenu: No scene path has been set for the " + scene_name + ".")
		return false
	
	if ResourceLoader.exists(scene_path, "PackedScene") == false:
		push_warning(
			"MainMenu: The " +
			scene_name +
			" scene does not exist yet: " +
			scene_path
		)
		return false
	
	return true


func open_website(url:String, website_name:String) -> void:
	if url.strip_edges() == "":
		push_warning("MainMenu: No URL has been set for " + website_name + ".")
		return
	
	var open_error:Error = OS.shell_open(url)
	
	if open_error == OK:
		return
	
	push_error(
		"MainMenu: Could not open the " +
		website_name +
		" website. Error code: " +
		str(open_error)
	)


func set_navigation_buttons_disabled(should_be_disabled:bool) -> void:
	if host_game_button != null:
		host_game_button.disabled = should_be_disabled
	
	if join_game_button != null:
		join_game_button.disabled = should_be_disabled
	
	if replays_button != null:
		replays_button.disabled = should_be_disabled
	
	if token_codex_button != null:
		token_codex_button.disabled = should_be_disabled
	
	if settings_button != null:
		settings_button.disabled = should_be_disabled


func _on_active_popup_tree_exited() -> void:
	active_popup = null
