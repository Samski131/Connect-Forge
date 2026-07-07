class_name TokenFallOutBoardVisualEffect
extends BoardVisualEffect

var tokens:Array[Token] = []
var board:BoardManager = null

var fall_distance:float = 2600.0
var row_stagger:float = 0.035
var token_stagger:float = 0.006

# Kept so existing board_manager.gd assignments do not break.
# Trapdoor Drop does not use these.
var side_scatter:float = 0.0
var spin_degrees:float = 0.0

var fade_out:bool = true
var shrink_out:bool = false

var squash_scale:Vector2 = Vector2(1.08, 0.86)
var squash_duration:float = 0.08
var drop_duration_multiplier:float = 0.82

var _tokens_to_free:Array[Token] = []
var _original_scales:Dictionary = {}


func _init(new_tokens:Array[Token], new_board:BoardManager, new_duration:float = 0.62):
	tokens = new_tokens
	board = new_board
	duration = new_duration
	target = null


func _play_valid(runner:Node) -> void:
	_tokens_to_free.clear()
	_original_scales.clear()
	
	var valid_tokens:Array[Token] = get_valid_tokens()
	
	if valid_tokens.is_empty():
		_finish()
		return
	
	sort_tokens_for_trapdoor(valid_tokens)
	
	var tween:Tween = runner.create_tween()
	tween.set_parallel(true)
	
	for i in range(valid_tokens.size()):
		var token:Token = valid_tokens[i]
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		disable_token_collision(token)
		

		_tokens_to_free.append(token)
		_original_scales[token] = token.scale
		
		var delay:float = get_token_delay(token, i)
		var original_scale:Vector2 = token.scale
		var squashed_scale:Vector2 = Vector2(original_scale.x * squash_scale.x, original_scale.y * squash_scale.y)
		var final_position:Vector2 = token.global_position + Vector2.DOWN * fall_distance
		
		var squash_tweener:PropertyTweener = tween.tween_property(token, "scale", squashed_scale, squash_duration)
		squash_tweener.set_delay(delay)
		squash_tweener.set_trans(Tween.TRANS_SINE)
		squash_tweener.set_ease(Tween.EASE_OUT)
		
		var drop_duration:float = duration * drop_duration_multiplier
		var drop_delay:float = delay + squash_duration
		
		var move_tweener:PropertyTweener = tween.tween_property(token, "global_position", final_position, drop_duration)
		move_tweener.set_delay(drop_delay)
		move_tweener.set_trans(Tween.TRANS_QUAD)
		move_tweener.set_ease(Tween.EASE_IN)
		
		var stretch_scale:Vector2 = Vector2(original_scale.x * 0.94, original_scale.y * 1.08)
		var stretch_tweener:PropertyTweener = tween.tween_property(token, "scale", stretch_scale, drop_duration * 0.28)
		stretch_tweener.set_delay(drop_delay)
		stretch_tweener.set_trans(Tween.TRANS_SINE)
		stretch_tweener.set_ease(Tween.EASE_OUT)
		
		var settle_tweener:PropertyTweener = tween.tween_property(token, "scale", original_scale, drop_duration * 0.22)
		settle_tweener.set_delay(drop_delay + drop_duration * 0.28)
		settle_tweener.set_trans(Tween.TRANS_SINE)
		settle_tweener.set_ease(Tween.EASE_OUT)
		
		if fade_out:
			var fade_tweener:PropertyTweener = tween.tween_property(token, "modulate:a", 0.0, drop_duration * 0.35)
			fade_tweener.set_delay(drop_delay + drop_duration * 0.65)
			fade_tweener.set_trans(Tween.TRANS_SINE)
			fade_tweener.set_ease(Tween.EASE_IN)
		
		if shrink_out:
			var shrink_tweener:PropertyTweener = tween.tween_property(token, "scale", Vector2.ZERO, drop_duration * 0.3)
			shrink_tweener.set_delay(drop_delay + drop_duration * 0.7)
			shrink_tweener.set_trans(Tween.TRANS_BACK)
			shrink_tweener.set_ease(Tween.EASE_IN)
	
	tween.finished.connect(_on_tween_finished)


func get_valid_tokens() -> Array[Token]:
	var valid_tokens:Array[Token] = []
	
	for token in tokens:
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		valid_tokens.append(token)
	
	return valid_tokens


func sort_tokens_for_trapdoor(valid_tokens:Array[Token]) -> void:
	valid_tokens.sort_custom(_sort_token_bottom_first)


func _sort_token_bottom_first(a:Token, b:Token) -> bool:
	if a == null:
		return false
	
	if b == null:
		return true
	
	if a.token_pos.y == b.token_pos.y:
		return a.token_pos.x < b.token_pos.x
	
	return a.token_pos.y > b.token_pos.y


func get_token_delay(token:Token, token_index:int) -> float:
	if board == null:
		return float(token_index) * token_stagger
	
	if board.settings == null:
		return float(token_index) * token_stagger
	
	var distance_from_bottom:int = get_distance_from_bottom(token.token_pos)
	var column_offset:float = get_column_delay(token.token_pos.x)
	
	return float(distance_from_bottom) * row_stagger + column_offset


func get_distance_from_bottom(pos:Vector2i) -> int:
	if board == null:
		return 0
	
	if board.settings == null:
		return 0
	
	return board.settings.rows - 1 - pos.y


func get_column_delay(column:int) -> float:
	var noise:float = get_noise_value(column + 14)
	return noise * token_stagger


func get_noise_value(seed_value:int) -> float:
	var value:float = sin(float(seed_value) * 12.9898) * 43758.5453
	return fposmod(value, 1.0)


func disable_token_collision(node:Node) -> void:
	if node is Area2D:
		var area:Area2D = node as Area2D
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0
	
	if node is CollisionShape2D:
		var collision_shape:CollisionShape2D = node as CollisionShape2D
		collision_shape.disabled = true
	
	for child in node.get_children():
		disable_token_collision(child)


func _on_tween_finished() -> void:
	for token in _tokens_to_free:
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		token.queue_free()
	
	_tokens_to_free.clear()
	_original_scales.clear()
	_finish()
