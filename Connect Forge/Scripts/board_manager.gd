class_name BoardManager
extends Node2D

var board = []
var token_pool:Node2D
var settings:BoardSetting = BoardSetting.new()
var hovered_slot:Slot = null
var slot_size:Vector2 = Vector2.ZERO
@onready var visuals:BoardVisualManager = $"../Board Visual Manager"

func _ready():
	token_pool = get_tree().get_first_node_in_group("token pool")
#Controls various board functions and stores the under the hood board representation.

#gets a token from a given XY, error protection for numbers out of range
func get_token(pos:Vector2i)->Token:
	if pos.x < 0 or pos.x >= settings.columns:
		return null
	
	if pos.y < 0 or pos.y >= settings.rows:
		return null
	
	return board[pos.y * settings.columns + pos.x]


func get_adjacent_pos(x:int, y:int, direction:BoardSetting.DIRECTION)->Vector2i:
	var grav_direction = settings.gravity_direction
	var grav_vector = settings.get_direction_vector(grav_direction)
	var right_vector = settings.get_right_relative_vector(grav_vector)
	var offset:Vector2i
	var DIRECTION = BoardSetting.DIRECTION
	
	match(direction):
		DIRECTION.DOWN:
			offset = grav_vector
		DIRECTION.UP:
			offset = -grav_vector
		DIRECTION.RIGHT:
			offset = right_vector
		DIRECTION.LEFT:
			offset = -right_vector
		DIRECTION.UP_RIGHT:
			offset = -grav_vector + right_vector
		DIRECTION.UP_LEFT:
			offset = -grav_vector - right_vector
		DIRECTION.DOWN_RIGHT:
			offset = grav_vector + right_vector
		DIRECTION.DOWN_LEFT:
			offset = grav_vector - right_vector
	
	return Vector2i(x, y) + offset
	
func get_adjacent_token(x:int, y:int, direction:BoardSetting.DIRECTION)->Token:
	var check_token_pos = get_adjacent_pos(x, y, direction)
	return get_token(Vector2i(check_token_pos.x, check_token_pos.y))

#Adds a token to the board array DOES NOT ADD A TOKEN NODE.
func add_token_to_board(new_token:Token, slot_pos:Vector2i)->bool:
	if is_position_in_bounds(slot_pos) == false: #if the position isn't on the board skip
		return false
	if(get_token(Vector2i(slot_pos.x,slot_pos.y))==null): #ensures there's not already a token in this slot
		board[slot_pos.y* settings.columns + slot_pos.x ]= new_token
		return true
	return false

func create_new_token(token_scene:PackedScene, slot_pos:Vector2i, player_id:int):
	if is_position_in_bounds(slot_pos) == false:
		return null
	
	if get_token(slot_pos) != null:
		return null
		
	var new_token:Token = token_scene.instantiate()
	token_pool.add_child(new_token)
	
	new_token.setup(self, slot_pos, player_id)
	add_token_to_board(new_token, slot_pos)

	return new_token

#Removes a token from the board array DOES NOT REMOVE ADD A TOKEN NODE.
func remove_token_from_board(slot_pos:Vector2i)->bool:
	if is_position_in_bounds(slot_pos) == false: #if the position isn't on the board skip
		return false
		
	var token = get_token(Vector2i(slot_pos.x,slot_pos.y))
	if(token!=null):#ensures there is already a token in this slot
		board[slot_pos.y* settings.columns + slot_pos.x ]= null
		return true
	return false
	
#Quick function to swap out a token with a new one.
func replace_token_on_board(new_token:Token, slot_pos:Vector2i)->bool:
	var success:bool
	success = remove_token_from_board(slot_pos)
	if(success):
		success = add_token_to_board(new_token, slot_pos)
	return success
	
func is_position_in_bounds(pos:Vector2i)->bool:
	return (pos.x >= 0 and pos.x < settings.columns and pos.y >= 0 and pos.y < settings.rows)

func move_token_on_board(token:Token, new_pos:Vector2i, move_visual:BoardVisualManager.MOVE_VISUAL = BoardVisualManager.MOVE_VISUAL.SLIDE)->bool:
	if token == null:
		return false
	
	if is_instance_valid(token) == false:
		return false
	
	if token.being_destroyed:
		return false
	
	if is_position_in_bounds(new_pos) == false:
		return false
	
	if get_token(new_pos) != null:
		return false
	
	remove_token_from_board(token.token_pos)
	token.token_pos = new_pos
	add_token_to_board(token, new_pos)
	
	if visuals != null:
		visuals.queue_token_move(token, slot_to_global_position(new_pos),move_visual)
	else:
		token.move_token_visual()
	
	return true

func destroy_token(token:Token)->bool:
	if token == null:
		return false
	
	if is_instance_valid(token) == false:
		return false
	
	if token.being_destroyed:
		return false
	
	if get_token(token.token_pos) == token:
		remove_token_from_board(token.token_pos)
	
	token.being_destroyed = true
	
	if visuals != null:
		visuals.queue_token_destroy(token)
	else:
		token.queue_free()
	
	return true

func set_hovered_slot(slot:Slot):
	hovered_slot = slot

func clear_hovered_slot(slot:Slot):
	if hovered_slot == slot:
		hovered_slot = null

func slot_to_global_position(slot_pos:Vector2i)->Vector2:
	var local_pos := Vector2(
		(slot_pos.x * slot_size.x) - (settings.columns * slot_size.x) / 2 + slot_size.x / 2,
		(slot_pos.y * slot_size.y) - (settings.rows * slot_size.y) / 2 + slot_size.y / 2
	)
	
	return to_global(local_pos)
	
func global_position_to_slot(global_pos:Vector2)->Vector2i:
	var local_pos := to_local(global_pos)
	
	var board_top_left := Vector2(-(settings.columns * slot_size.x) / 2,-(settings.rows * slot_size.y) / 2)
	
	var local_slot_pos := (local_pos - board_top_left) / slot_size
	
	return Vector2i(floor(local_slot_pos.x), floor(local_slot_pos.y))

func get_fall_path(token:Token)->Array[Vector2i]:
	var path:Array[Vector2i] = []
	
	if token == null:
		return path
	
	if is_instance_valid(token) == false:
		return path
	
	var current_pos := token.token_pos
	var next_pos := get_adjacent_pos(current_pos.x, current_pos.y,BoardSetting.DIRECTION.DOWN)
	
	while is_position_in_bounds(next_pos) and get_token(next_pos) == null:
		path.append(next_pos)
		current_pos = next_pos
		next_pos = get_adjacent_pos(current_pos.x, current_pos.y,BoardSetting.DIRECTION.DOWN)
	
	return path

func find_first_pass_trigger_step(moving_token:Token,start_pos:Vector2i,path:Array[Vector2i])->Dictionary:
	var previous_pos := start_pos
	
	for to_pos in path:
		if has_passing_reactor_for_step(moving_token, previous_pos, to_pos):
			return {
				"has_pass_trigger": true,
				"from_pos": previous_pos,
				"to_pos": to_pos
			}
		
		previous_pos = to_pos
	
	return {
		"has_pass_trigger": false,
		"from_pos": start_pos,
		"to_pos": path.back() if path.size() > 0 else start_pos
	}

func has_passing_reactor_for_step(moving_token:Token,_from_pos:Vector2i,to_pos:Vector2i)->bool:
	var pass_checks := [
		[BoardSetting.DIRECTION.RIGHT, Global.KEYWORD.ON_PASS_LEFT],
		[BoardSetting.DIRECTION.LEFT, Global.KEYWORD.ON_PASS_RIGHT],
		[BoardSetting.DIRECTION.DOWN, Global.KEYWORD.ON_PASS_ABOVE],
		[BoardSetting.DIRECTION.UP, Global.KEYWORD.ON_PASS_BELOW],
	]
	
	for check in pass_checks:
		var neighbour_direction:BoardSetting.DIRECTION = check[0]
		var keyword:Global.KEYWORD = check[1]
		
		var reacting_pos := get_adjacent_pos(to_pos.x, to_pos.y, neighbour_direction)
		var reacting_token := get_token(reacting_pos)
		
		if reacting_token == null:
			continue
		
		if reacting_token == moving_token:
			continue
		
		if reacting_token.has_keyword(keyword):
			return true
	
	return false

func resolve_landing_triggers(landing_token:Token)->bool:
	if landing_token == null:
		return false
	
	var changed_board := false
	
	var token_below := get_adjacent_token(landing_token.token_pos.x, landing_token.token_pos.y, BoardSetting.DIRECTION.DOWN	)
	
	if token_below != null:
		#if the token below exists, pack a dictionary ful of some context.
		var impact_context := {
			"landing_token": landing_token,
			"impacted_token": token_below,
			"board": self
		}
		
		if token_below.trigger_keyword(Global.KEYWORD.ON_IMPACT, impact_context):
			changed_board = true
	
	# The landing token may have been deleted by On Impact.
	if get_token(landing_token.token_pos) != landing_token:
		return changed_board
	
	var land_context := {
		"landing_token": landing_token,
		"board": self
	}
	
	if landing_token.trigger_keyword(Global.KEYWORD.ON_LAND, land_context):
		changed_board = true
	
	return changed_board

func resolve_passing_triggers(moving_token:Token, from_pos:Vector2i, to_pos:Vector2i)->bool:
	if moving_token == null: #if the moving token doesn't eist
		return false
	
	if get_token(to_pos) != moving_token: #if our token didn't manage to move where it wanted.
		return false
	
	var changed_board := false
	
	#definte which sides we care about
	var pass_checks := [
		[BoardSetting.DIRECTION.RIGHT, Global.KEYWORD.ON_PASS_LEFT],
		[BoardSetting.DIRECTION.LEFT, Global.KEYWORD.ON_PASS_RIGHT],
		[BoardSetting.DIRECTION.DOWN, Global.KEYWORD.ON_PASS_ABOVE],
		[BoardSetting.DIRECTION.UP, Global.KEYWORD.ON_PASS_BELOW],
	]
	
	for check in pass_checks:
		var neighbour_direction:BoardSetting.DIRECTION = check[0] #set which direction to check
		var keyword:Global.KEYWORD = check[1] #set which keyword we are checking for
		
		var reacting_pos := get_adjacent_pos(to_pos.x, to_pos.y, neighbour_direction)
		var reacting_token := get_token(reacting_pos)
		
		if reacting_token == null: #if the token that would react doesn't exist, skip
			continue
		
		if reacting_token == moving_token: #if the token that would react is the current token somehow, skip
			continue
		
		var context := {
			"moving_token": moving_token,
			"reacting_token": reacting_token,
			"from_pos": from_pos,
			"to_pos": to_pos,
			"keyword": keyword,
			"board": self
		}
		
		if reacting_token.trigger_keyword(keyword, context):
			changed_board = true
		
		# Stop resolving pass triggers if the moving token was destroyed or moved
		if get_token(to_pos) != moving_token:
			break
	
	return changed_board
