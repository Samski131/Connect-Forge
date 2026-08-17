class_name BotSimulationState
extends RefCounted

var settings:BoardSetting = null
var session:MatchSession = null
var board_state:BoardState = null

var token_root:Node = null
var disposed:bool = true


func setup(new_settings:BoardSetting, new_session:MatchSession) -> bool:
	dispose()
	
	if new_settings == null:
		return false
	
	if new_session == null:
		return false
	
	settings = new_settings
	session = new_session
	
	board_state = BoardState.new(settings)
	board_state.setup_empty_board()
	
	token_root = Node.new()
	disposed = false
	
	return true


func own_token(token:Token) -> bool:
	if disposed:
		return false
	
	if token == null:
		return false
	
	if is_instance_valid(token) == false:
		return false
	
	if token_root == null:
		return false
	
	if token.get_parent() != null:
		return false
	
	token_root.add_child(token)
	return true


func get_owned_tokens() -> Array[Token]:
	var result:Array[Token] = []
	
	if disposed:
		return result
	
	if token_root == null:
		return result
	
	for child in token_root.get_children():
		var token:Token = child as Token
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		result.append(token)
	
	return result


func is_valid_state() -> bool:
	if disposed:
		return false
	
	if settings == null:
		return false
	
	if session == null:
		return false
	
	if board_state == null:
		return false
	
	if token_root == null:
		return false
	
	return true


func dispose() -> void:
	if disposed:
		return
	
	disposed = true
	
	if board_state != null:
		board_state.clear()
	
	if token_root != null:
		if is_instance_valid(token_root):
			token_root.free()
	
	token_root = null
	board_state = null
	session = null
	settings = null
