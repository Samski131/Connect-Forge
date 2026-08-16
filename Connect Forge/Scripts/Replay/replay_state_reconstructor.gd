class_name ReplayStateReconstructor
extends RefCounted


static func reconstruct_to_step(replay:ReplayData, target_step_id:int) -> ReplayState:
	if replay == null:
		return null
	
	if target_step_id < -1:
		return null
	
	if target_step_id >= replay.get_step_count():
		return null
	
	var state:ReplayState = ReplayState.new()
	
	if state.setup_from_replay(replay) == false:
		return null
	
	if target_step_id == -1:
		return state
	
	var first_step_to_apply:int = 0
	
	for checkpoint_index in range(replay.checkpoints.size() - 1, -1, -1):
		var checkpoint:ReplayCheckpoint = replay.checkpoints[checkpoint_index]
		
		if checkpoint == null:
			continue
		
		if checkpoint.after_step_id > target_step_id:
			continue
		
		var checkpoint_state:ReplayState = ReplayState.new()
		
		if checkpoint_state.load_from_dictionary(replay, checkpoint.state_data) == false:
			continue
		
		state = checkpoint_state
		first_step_to_apply = checkpoint.after_step_id + 1
		break
	
	for step_id in range(first_step_to_apply, target_step_id + 1):
		var step:ReplayStep = replay.get_step(step_id)
		
		if step == null:
			return null
		
		if state.apply_step(step) == false:
			push_error("ReplayStateReconstructor: Could not apply replay step %d." % step_id)
			return null
	
	return state


static func reconstruct_final_state(replay:ReplayData) -> ReplayState:
	if replay == null:
		return null
	
	if replay.get_step_count() <= 0:
		return reconstruct_to_step(replay, -1)
	
	return reconstruct_to_step(replay, replay.get_step_count() - 1)
