class_name TooltipManager
extends CanvasLayer

@export_group("Behaviour")
@export_range(0.0, 10.0, 0.1) var hover_delay_seconds:float = 3.0

@export_group("Position")
@export var tooltip_offset:Vector2 = Vector2(24.0, 24.0)
@export_range(0.0, 100.0, 1.0) var viewport_margin:float = 12.0

var registered_tooltips:Dictionary = {}

var hovered_target:Control = null
var hover_elapsed_seconds:float = 0.0
var layout_request_id:int = 0

@onready var tooltip_panel:PanelContainer = %TooltipPanel
@onready var tooltip_label:Label = %TooltipLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	tooltip_panel.visible = true
	tooltip_panel.modulate.a = 0.0
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.position = Vector2(-10000.0, -10000.0)
	
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta:float) -> void:
	var new_hovered_target:Control = get_registered_target_under_mouse()
	
	if new_hovered_target != hovered_target:
		set_hovered_target(new_hovered_target)
		return
	
	if hovered_target == null:
		return
	
	if tooltip_panel.modulate.a > 0.0:
		return
	
	hover_elapsed_seconds += delta
	
	if hover_elapsed_seconds < hover_delay_seconds:
		return
	
	show_tooltip_for_target(hovered_target)


func _input(event:InputEvent) -> void:
	if event is InputEventMouseMotion == false:
		return
	
	if hovered_target == null:
		return
	
	hide_tooltip()
	hover_elapsed_seconds = 0.0


func register_tooltip(target:Control, text:String) -> void:
	if target == null:
		return
	
	if is_instance_valid(target) == false:
		return
	
	var used_text:String = text.strip_edges()
	
	target.tooltip_text = ""
	
	if used_text == "":
		unregister_tooltip(target)
		return
	
	registered_tooltips[target] = used_text
	
	var exit_callable:Callable = Callable(self, "_on_registered_target_tree_exiting").bind(target)
	
	if target.tree_exiting.is_connected(exit_callable) == false:
		target.tree_exiting.connect(exit_callable)


func unregister_tooltip(target:Control) -> void:
	if target == null:
		return
	
	if hovered_target == target:
		set_hovered_target(null)
	
	registered_tooltips.erase(target)


func update_tooltip(target:Control, text:String) -> void:
	register_tooltip(target, text)


func hide_tooltip() -> void:
	layout_request_id += 1
	
	if tooltip_panel == null:
		return
	
	tooltip_panel.modulate.a = 0.0
	
	if tooltip_label != null:
		tooltip_label.text = ""


func clear_hover() -> void:
	set_hovered_target(null)


func clear_all_tooltips() -> void:
	registered_tooltips.clear()
	set_hovered_target(null)


func set_hovered_target(new_target:Control) -> void:
	hovered_target = new_target
	hover_elapsed_seconds = 0.0
	hide_tooltip()


func get_registered_target_under_mouse() -> Control:
	var hovered_control:Control = get_viewport().gui_get_hovered_control()
	
	if hovered_control == null:
		return null
	
	var current_node:Node = hovered_control
	
	while current_node != null:
		var current_control:Control = current_node as Control
		
		if current_control != null:
			if registered_tooltips.has(current_control):
				if is_instance_valid(current_control):
					if current_control.is_visible_in_tree():
						return current_control
		
		current_node = current_node.get_parent()
	
	return null


func show_tooltip_for_target(target:Control) -> void:
	if target == null:
		return
	
	if is_instance_valid(target) == false:
		set_hovered_target(null)
		return
	
	if registered_tooltips.has(target) == false:
		set_hovered_target(null)
		return
	
	var used_text:String = str(registered_tooltips[target]).strip_edges()
	
	if used_text == "":
		return
	
	layout_request_id += 1
	var current_request_id:int = layout_request_id
	
	tooltip_panel.modulate.a = 0.0
	tooltip_label.text = used_text
	
	call_deferred("finish_tooltip_layout", target, current_request_id)


func finish_tooltip_layout(target:Control, request_id:int) -> void:
	if request_id != layout_request_id:
		return
	
	if target == null:
		return
	
	if is_instance_valid(target) == false:
		return
	
	if hovered_target != target:
		return
	
	if registered_tooltips.has(target) == false:
		return
	
	tooltip_panel.reset_size()
	
	call_deferred("finish_showing_tooltip", target, request_id)


func finish_showing_tooltip(target:Control, request_id:int) -> void:
	if request_id != layout_request_id:
		return
	
	if target == null:
		return
	
	if is_instance_valid(target) == false:
		return
	
	if hovered_target != target:
		return
	
	if registered_tooltips.has(target) == false:
		return
	
	tooltip_panel.reset_size()
	position_tooltip()
	tooltip_panel.modulate.a = 1.0


func position_tooltip() -> void:
	if tooltip_panel == null:
		return
	
	var viewport_size:Vector2 = get_viewport().get_visible_rect().size
	var mouse_position:Vector2 = get_viewport().get_mouse_position()
	var panel_size:Vector2 = tooltip_panel.size
	
	var new_position:Vector2 = mouse_position + tooltip_offset
	
	if new_position.x + panel_size.x > viewport_size.x - viewport_margin:
		new_position.x = mouse_position.x - panel_size.x - tooltip_offset.x
	
	if new_position.y + panel_size.y > viewport_size.y - viewport_margin:
		new_position.y = mouse_position.y - panel_size.y - tooltip_offset.y
	
	var maximum_x:float = max(viewport_margin, viewport_size.x - panel_size.x - viewport_margin)
	var maximum_y:float = max(viewport_margin, viewport_size.y - panel_size.y - viewport_margin)
	
	new_position.x = clamp(new_position.x, viewport_margin, maximum_x)
	new_position.y = clamp(new_position.y, viewport_margin, maximum_y)
	
	tooltip_panel.position = new_position


func _on_registered_target_tree_exiting(target:Control) -> void:
	unregister_tooltip(target)


static func find_for(node:Node) -> TooltipManager:
	if node == null:
		return null
	
	var current_node:Node = node
	
	while current_node != null:
		if current_node is TooltipManager:
			return current_node as TooltipManager
		
		for child in current_node.get_children():
			if child is TooltipManager:
				return child as TooltipManager
		
		current_node = current_node.get_parent()
	
	return null
