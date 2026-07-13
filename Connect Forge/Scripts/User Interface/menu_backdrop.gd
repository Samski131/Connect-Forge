class_name MenuBackdrop
extends ColorRect

signal close_all_menus_requested

const CLOSABLE_MENU_GROUP:StringName = &"closable_menus"

@onready var juice_player:UIJuicePlayer = $UIJuicePlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func enter() -> void:
	if juice_player == null:
		visible = true
		return
	
	juice_player.enter()


func exit() -> void:
	if juice_player == null:
		visible = false
		return
	
	juice_player.exit()


func hide_instant() -> void:
	if juice_player == null:
		visible = false
		return
	
	juice_player.hide_instant()


func show_instant() -> void:
	if juice_player == null:
		visible = true
		return
	
	juice_player.show_instant()


func is_transitioning() -> bool:
	if juice_player == null:
		return false
	
	return juice_player.is_transitioning


func _gui_input(event:InputEvent) -> void:
	if is_close_input(event) == false:
		return
	
	accept_event()
	close_all_menus_requested.emit()
	close_all_menus(get_tree())


func is_close_input(event:InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event:InputEventMouseButton = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			return true
	
	if event is InputEventScreenTouch:
		var touch_event:InputEventScreenTouch = event as InputEventScreenTouch
		
		if touch_event.pressed:
			return true
	
	return false


static func close_all_menus(scene_tree:SceneTree, excluded_menu:Node = null, instant:bool = false) -> void:
	if scene_tree == null:
		return
	
	var menus:Array[Node] = scene_tree.get_nodes_in_group(CLOSABLE_MENU_GROUP)
	
	for menu in menus:
		if menu == null:
			continue
		
		if is_instance_valid(menu) == false:
			continue
		
		if menu == excluded_menu:
			continue
		
		if instant:
			if menu.has_method("force_close_menu"):
				menu.call("force_close_menu")
			
			continue
		
		if menu.has_method("close_menu"):
			menu.call("close_menu")
			continue
		
		if menu.has_method("force_close_menu"):
			menu.call("force_close_menu")
