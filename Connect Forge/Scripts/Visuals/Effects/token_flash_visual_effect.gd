class_name TokensFlashVisualEffect
extends BoardVisualEffect

var tokens:Array[Token] = []
var pulses:int = 6
var flash_color:Color = Color.WHITE

var _items:Array[CanvasItem] = []
var _original_colors:Array[Color] = []


func _init(new_tokens:Array[Token], new_pulses:int = 6, new_duration:float = 0.35):
	tokens = new_tokens
	pulses = new_pulses
	duration = new_duration
	target = null


func _play_valid(runner:Node) -> void:
	_collect_items()
	
	if _items.is_empty():
		_finish()
		return
	
	var tween:Tween = runner.create_tween()
	tween.tween_method(_set_flash_progress, 0.0, float(pulses), duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_finish)


func _collect_items() -> void:
	_items.clear()
	_original_colors.clear()
	
	for token in tokens:
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		_collect_canvas_items(token)


func _collect_canvas_items(node:Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			var item:CanvasItem = child as CanvasItem
			_items.append(item)
			_original_colors.append(item.modulate)
		
		_collect_canvas_items(child)


func _set_flash_progress(value:float) -> void:
	var amount:float = abs(sin(value * PI))
	
	for i in range(_items.size()):
		var item:CanvasItem = _items[i]
		
		if item == null:
			continue
		
		if is_instance_valid(item) == false:
			continue
		
		var original:Color = _original_colors[i]
		var used_flash_color:Color = Color(flash_color.r, flash_color.g, flash_color.b, original.a)
		item.modulate = original.lerp(used_flash_color, amount)


func to_replay_action() -> ReplayAction:
	var token_ids:Array = []
	
	for token in tokens:
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		if token.has_replay_token_id() == false:
			continue
		
		token_ids.append(token.get_replay_token_id())
	
	if token_ids.is_empty():
		return null
	
	var payload:Dictionary = {
		"token_ids": token_ids,
		"pulses": pulses,
		"duration": duration,
		"flash_color": ReplayAction.colour_to_data(flash_color)
	}
	
	return ReplayAction.create_presentation(ReplayFormat.PRESENTATION_TOKEN_FLASH, payload)


func _finish() -> void:
	for i in range(_items.size()):
		var item:CanvasItem = _items[i]
		
		if item == null:
			continue
		
		if is_instance_valid(item) == false:
			continue
		
		item.modulate = _original_colors[i]
	
	super._finish()
