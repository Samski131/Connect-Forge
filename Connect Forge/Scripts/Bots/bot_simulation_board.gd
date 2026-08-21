class_name BotSimulationBoard
extends BoardManager

var simulation_state:BotSimulationState = null
var disposed:bool = false


func setup_from_state(new_simulation_state:BotSimulationState) -> bool:
	if disposed:
		return false
	
	if new_simulation_state == null:
		return false
	
	if new_simulation_state.is_valid_state() == false:
		return false
	
	simulation_state = new_simulation_state
	
	settings = simulation_state.settings
	state = simulation_state.board_state
	match_session = simulation_state.session
	token_pool = simulation_state.token_root
	
	visuals = null
	replay_recorder = null
	hovered_slot = null
	
	slot_size = Vector2.ONE
	
	geometry = BoardGeometry.new(settings, self, slot_size)
	trigger_resolver = BoardTriggerResolver.new(self)
	gravity_order = BoardGravityOrder.new(settings)
	token_mover = BotSimulationTokenMover.new(self)
	
	refresh_gravity_order()
	_attach_simulation_tokens()
	
	return true


func _attach_simulation_tokens() -> void:
	if simulation_state == null:
		return
	
	for token in simulation_state.get_owned_tokens():
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		token.board = self
		token.visible = false


func get_gameplay_random_number_generator() -> RandomNumberGenerator:
	if simulation_state == null:
		return null
	
	return simulation_state.get_random_number_generator()


func get_simulation_random_seed() -> int:
	if simulation_state == null:
		return BotSimulationState.DEFAULT_RANDOM_SEED
	
	return simulation_state.get_random_seed()


func set_replay_recorder(_new_replay_recorder:ReplayRecorder) -> void:
	replay_recorder = null


func set_gravity_direction(new_direction:BoardSetting.GRID_DIRECTION, _animate_visual:bool = true) -> bool:
	if disposed:
		return false
	
	if settings == null:
		return false
	
	if settings.gravity_direction == new_direction:
		return false
	
	settings.gravity_direction = new_direction
	refresh_gravity_order()
	
	for pos in get_positions_in_gravity_order():
		var token:Token = get_token(pos)
		
		if token == null:
			continue
		
		if is_instance_valid(token) == false:
			continue
		
		if token.being_destroyed:
			continue
		
		token.reset_resolved()
	
	return true


func rotate_gravity(clockwise:bool = true) -> void:
	if disposed:
		return
	
	if settings == null:
		return
	
	var GRID_DIRECTION = BoardSetting.GRID_DIRECTION
	var directions:Array[BoardSetting.GRID_DIRECTION] = [
		GRID_DIRECTION.UP,
		GRID_DIRECTION.RIGHT,
		GRID_DIRECTION.DOWN,
		GRID_DIRECTION.LEFT
	]
	
	var current_index:int = directions.find(settings.gravity_direction)
	
	if current_index == -1:
		set_gravity_direction(GRID_DIRECTION.DOWN, false)
		return
	
	var step:int = 1
	
	if clockwise == false:
		step = -1
	
	var new_index:int = current_index + step
	
	if new_index >= directions.size():
		new_index = 0
	
	if new_index < 0:
		new_index = directions.size() - 1
	
	var new_direction:BoardSetting.GRID_DIRECTION = directions[new_index]
	set_gravity_direction(new_direction, false)


func dispose() -> void:
	if disposed:
		return
	
	disposed = true
	
	if trigger_resolver != null:
		trigger_resolver.clear_pending_pass_triggers()
	
	if simulation_state != null:
		for token in simulation_state.get_owned_tokens():
			if token == null:
				continue
			
			if is_instance_valid(token) == false:
				continue
			
			if token.board == self:
				token.board = null
	
	simulation_state = null
	
	token_mover = null
	trigger_resolver = null
	gravity_order = null
	geometry = null
	
	token_pool = null
	visuals = null
	replay_recorder = null
	match_session = null
	state = null
