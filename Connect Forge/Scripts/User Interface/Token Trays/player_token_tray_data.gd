class_name PlayerTokenTrayData
extends RefCounted

var player_id:int = -1
var token_counts:Dictionary = {}


func setup(new_player_id:int) -> void:
	player_id = new_player_id
	reset_counts()


func reset_counts() -> void:
	token_counts.clear()
	
	for token_type in TokenLibrary.get_all_token_types():
		token_counts[token_type] = 0


func ensure_token_exists(token_type:int) -> void:
	if token_counts.has(token_type):
		return
	
	token_counts[token_type] = 0


func get_count(token_type:int) -> int:
	if token_counts.has(token_type) == false:
		return 0
	
	return int(token_counts[token_type])


func set_count(token_type:int, amount:int) -> void:
	token_counts[token_type] = max(amount, 0)


func has_token(token_type:int) -> bool:
	if get_count(token_type) > 0:
		return true
	
	return false


func spend_token(token_type:int) -> bool:
	if has_token(token_type) == false:
		return false
	
	var current_count:int = get_count(token_type)
	token_counts[token_type] = current_count - 1
	
	return true


func refund_token(token_type:int, amount:int = 1) -> void:
	if amount <= 0:
		return
	
	var current_count:int = get_count(token_type)
	token_counts[token_type] = current_count + amount


func get_all_counts() -> Dictionary:
	return token_counts.duplicate()

func add_tokens(token_type:int, amount:int = 1) -> void:
	if amount <= 0:
		return
	
	var current_count:int = get_count(token_type)
	token_counts[token_type] = current_count + amount
