class_name ColorTweenVisualEffect
extends VisualTweenEffect

enum MODE {DARKEN, LIGHTEN, TO_COLOR}

var mode:MODE = MODE.DARKEN
var amount:float = 0.3
var target_color:Color = Color.WHITE

var include_target:bool = false
var include_children:bool = true


func _init(new_target:Object, new_mode:MODE = MODE.DARKEN, new_amount:float = 0.3, new_duration:float = 0.12):
	target = new_target
	mode = new_mode
	amount = new_amount
	duration = new_duration
	
	parallel = true
	trans_type = Tween.TRANS_SINE
	ease_type = Tween.EASE_OUT


func _build_tween(tween:Tween) -> void:
	var canvas_items:Array[CanvasItem] = _get_canvas_items()
	
	for item in canvas_items:
		var current_color:Color = item.modulate
		var final_color:Color = current_color
		
		match mode:
			MODE.DARKEN:
				final_color = current_color.darkened(amount)
			
			MODE.LIGHTEN:
				final_color = current_color.lightened(amount)
			
			MODE.TO_COLOR:
				final_color = target_color
		
		add_property_tween(tween, item, "modulate", final_color)


func _get_canvas_items() -> Array[CanvasItem]:
	var results:Array[CanvasItem] = []
	
	if target == null:
		return results
	
	if is_instance_valid(target) == false:
		return results
	
	if include_target and target is CanvasItem:
		results.append(target)
	
	if include_children and target is Node:
		_collect_canvas_items(target, results)
	
	return results


func _collect_canvas_items(node:Node, results:Array[CanvasItem]) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			results.append(child)
		
		_collect_canvas_items(child, results)


func to_replay_action() -> ReplayAction:
	if mode != MODE.DARKEN:
		return null
	
	var token_id:int = get_replay_target_token_id()
	
	if token_id < 0:
		return null
	
	var payload:Dictionary = {
		"token_id": token_id,
		"amount": amount,
		"duration": duration
	}
	
	return ReplayAction.create_presentation(ReplayFormat.PRESENTATION_TOKEN_DARKEN, payload)
