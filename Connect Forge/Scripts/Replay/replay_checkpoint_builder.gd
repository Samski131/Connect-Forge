class_name ReplayCheckpointBuilder
extends RefCounted

const CHECKPOINT_INTERVAL_STEPS:int = 100


static func rebuild_checkpoints(replay:ReplayData) -> bool:
	if replay == null:
		return false
	
	replay.clear_checkpoints()
	
	var state:ReplayState = ReplayState.new()
	
	if state.setup_from_replay(replay) == false:
		push_error("ReplayCheckpointBuilder: Could not create the initial replay state.")
		return false
	
	var initial_checkpoint:ReplayCheckpoint = ReplayCheckpoint.new(-1, state.to_dictionary())
	
	if replay.add_checkpoint(initial_checkpoint) == false:
		return false
	
	for step in replay.steps:
		if state.apply_step(step) == false:
			push_error("ReplayCheckpointBuilder: Replay state became invalid while applying step %d." % step.step_id)
			replay.clear_checkpoints()
			return false
		
		if should_capture_checkpoint(step):
			var checkpoint:ReplayCheckpoint = ReplayCheckpoint.new(step.step_id, state.to_dictionary())
			
			if replay.add_checkpoint(checkpoint) == false:
				replay.clear_checkpoints()
				return false
	
	if replay.steps.is_empty() == false:
		var final_step_id:int = replay.steps.size() - 1
		var final_checkpoint_is_present:bool = false
		
		if replay.checkpoints.is_empty() == false:
			var final_checkpoint:ReplayCheckpoint = replay.checkpoints.back()
			final_checkpoint_is_present = final_checkpoint.after_step_id == final_step_id
		
		if final_checkpoint_is_present == false:
			var final_checkpoint:ReplayCheckpoint = ReplayCheckpoint.new(final_step_id, state.to_dictionary())
			
			if replay.add_checkpoint(final_checkpoint) == false:
				replay.clear_checkpoints()
				return false
	
	return true


static func should_capture_checkpoint(step:ReplayStep) -> bool:
	if step == null:
		return false
	
	if step.step_type == ReplayFormat.STEP_ROUND_START:
		return true
	
	if step.step_type == ReplayFormat.STEP_ROUND_END:
		return true
	
	if step.step_type == ReplayFormat.STEP_MATCH_END:
		return true
	
	if (step.step_id + 1) % CHECKPOINT_INTERVAL_STEPS == 0:
		return true
	
	return false
