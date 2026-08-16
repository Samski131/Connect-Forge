class_name ReplayPresentationPlayer
extends Node

signal playback_started
signal playback_finished
signal presentation_skipped(action_type:String)

const MINIMUM_PLAYBACK_SPEED:float = 0.1
const MAXIMUM_PLAYBACK_SPEED:float = 8.0

var board_view:ReplayBoardView = null
var playback_active:bool = false
var playback_speed:float = 1.0
var active_effect:BoardVisualEffect = null
var finished_callback:Callable = Callable()


func setup(new_board_view:ReplayBoardView) -> bool:
	if new_board_view == null:
		return false
	
	board_view = new_board_view
	return true


func play_action(action:ReplayAction, speed:float = 1.0, callback:Callable = Callable()) -> bool:
	if playback_active:
		return false
	
	if board_view == null:
		return false
	
	if action == null:
		return false
	
	if action.is_state_action():
		return false
	
	playback_speed = clamp(speed, MINIMUM_PLAYBACK_SPEED, MAXIMUM_PLAYBACK_SPEED)
	finished_callback = callback
	active_effect = build_effect(action)
	playback_active = true
	playback_started.emit()
	
	if active_effect == null:
		_finish_playback()
		return true
	
	active_effect.play(self, _finish_playback)
	return true


func is_playing() -> bool:
	return playback_active


func build_effect(action:ReplayAction) -> BoardVisualEffect:
	if action == null:
		return null
	
	if action.action_version != ReplayFormat.ACTION_VERSION_DEFAULT:
		return skip_action(action, "Unsupported presentation action version %d." % action.action_version)
	
	if action.is_sequence():
		return build_sequence_effect(action)
	
	if action.is_parallel():
		return build_parallel_effect(action)
	
	if action.is_presentation_action() == false:
		return skip_action(action, "Unsupported replay action channel '%s'." % action.channel)
	
	match action.action_type:
		ReplayFormat.PRESENTATION_TOKEN_MOVE:
			return build_token_move_effect(action)
		ReplayFormat.PRESENTATION_TOKEN_DESTROY:
			return build_token_destroy_effect(action)
		ReplayFormat.PRESENTATION_TOKEN_FLIP:
			return build_token_flip_effect(action)
		ReplayFormat.PRESENTATION_TOKEN_SHIMMER:
			return build_token_shimmer_effect(action)
		ReplayFormat.PRESENTATION_TOKEN_FLASH:
			return build_token_flash_effect(action)
		ReplayFormat.PRESENTATION_TOKEN_DARKEN:
			return build_token_darken_effect(action)
		ReplayFormat.PRESENTATION_TOKEN_GRAVITY_ALIGN:
			return build_token_gravity_align_effect(action)
		ReplayFormat.PRESENTATION_WIGGLE:
			return build_wiggle_effect(action)
		ReplayFormat.PRESENTATION_CHAMELEON_TRANSFORM:
			return build_chameleon_transform_effect(action)
		ReplayFormat.PRESENTATION_CHAMELEON_REVEAL:
			return build_chameleon_reveal_effect(action)
	
	return skip_action(action, "Presentation type is not implemented by the replay viewer.")


func build_sequence_effect(action:ReplayAction) -> BoardVisualEffect:
	var effects:Array[BoardVisualEffect] = []
	
	for child in action.children:
		var effect:BoardVisualEffect = build_effect(child)
		
		if effect != null:
			effects.append(effect)
	
	if effects.is_empty():
		return null
	
	return SequenceVisualEffect.new(effects)


func build_parallel_effect(action:ReplayAction) -> BoardVisualEffect:
	var effects:Array[BoardVisualEffect] = []
	
	for child in action.children:
		var effect:BoardVisualEffect = build_effect(child)
		
		if effect != null:
			effects.append(effect)
	
	if effects.is_empty():
		return null
	
	return ParallelVisualEffect.new(effects)


func build_token_move_effect(action:ReplayAction) -> BoardVisualEffect:
	var token:Token = get_action_token(action)
	
	if token == null:
		return skip_action(action, "Replay token does not exist on the current puppet board.")
	
	var to_value = action.payload.get("to", [])
	
	if ReplayState.is_valid_position_data(to_value) == false:
		return skip_action(action, "Movement has an invalid destination.")
	
	var to_pos:Vector2i = ReplayState.position_from_data(to_value)
	
	if board_view.is_grid_position_in_bounds(to_pos) == false:
		return skip_action(action, "Movement destination is outside the replay board.")
	
	var target_local:Vector2 = board_view.grid_position_to_local(to_pos)
	var target_global:Vector2 = board_view.to_global(target_local)
	var movement:String = str(action.payload.get("movement", ReplayFormat.MOVEMENT_SLIDE))
	var duration:float = get_scaled_duration(action.payload, 0.12)
	
	if movement == ReplayFormat.MOVEMENT_FALL:
		var fall_effect:TokenMoveVisualEffect = TokenMoveVisualEffect.new(token, target_global, BoardVisualManager.MOVE_VISUAL.FALL)
		fall_effect.min_fall_duration = duration
		fall_effect.max_fall_duration = duration
		return fall_effect
	
	if movement == ReplayFormat.MOVEMENT_SLIDE:
		var slide_effect:TokenMoveVisualEffect = TokenMoveVisualEffect.new(token, target_global, BoardVisualManager.MOVE_VISUAL.SLIDE)
		slide_effect.slide_duration = duration
		return slide_effect
	
	return skip_action(action, "Movement type '%s' is not implemented by the replay viewer." % movement)


func build_token_destroy_effect(action:ReplayAction) -> BoardVisualEffect:
	var token:Token = get_action_token(action)
	
	if token == null:
		return skip_action(action, "Replay token does not exist on the current puppet board.")
	
	var duration:float = get_scaled_duration(action.payload, 0.2)
	return TokenDestroyVisualEffect.new(token, duration)


func build_token_flip_effect(action:ReplayAction) -> BoardVisualEffect:
	var token:Token = get_action_token(action)
	
	if token == null:
		return skip_action(action, "Replay token does not exist on the current puppet board.")
	
	var flipped:bool = bool(action.payload.get("flipped", false))
	var duration:float = get_scaled_duration(action.payload, 0.28)
	var effect:TokenFlipVisualEffect = TokenFlipVisualEffect.new(token, flipped, duration)
	effect.min_scale_x = max(float(action.payload.get("min_scale_x", effect.min_scale_x)), 0.001)
	effect.pop_scale_y = max(float(action.payload.get("pop_scale_y", effect.pop_scale_y)), 0.001)
	return effect


func build_token_shimmer_effect(action:ReplayAction) -> BoardVisualEffect:
	var token:Token = get_action_token(action)
	
	if token == null:
		return skip_action(action, "Replay token does not exist on the current puppet board.")
	
	var duration:float = get_scaled_duration(action.payload, 0.45)
	var direction:Vector2 = vector2_from_data(action.payload.get("direction", [1.0, -1.0]), Vector2(1.0, -1.0))
	var strength:float = max(float(action.payload.get("strength", 0.75)), 0.0)
	return TokenShimmerVisualEffect.new(token, duration, direction, strength)


func build_token_flash_effect(action:ReplayAction) -> BoardVisualEffect:
	var token_ids_value = action.payload.get("token_ids", [])
	
	if typeof(token_ids_value) != TYPE_ARRAY:
		return skip_action(action, "Token flash has invalid token IDs.")
	
	var token_ids:Array = token_ids_value
	var tokens:Array[Token] = []
	
	for token_id_value in token_ids:
		var token_id:int = int(token_id_value)
		var token:Token = board_view.get_replay_token(token_id)
		
		if token != null:
			tokens.append(token)
	
	if tokens.is_empty():
		return skip_action(action, "Token flash has no visible replay tokens to target.")
	
	var pulses:int = max(int(action.payload.get("pulses", 6)), 1)
	var duration:float = get_scaled_duration(action.payload, 0.35)
	var flash_color:Color = colour_from_data(action.payload.get("flash_color", [1.0, 1.0, 1.0, 1.0]), Color.WHITE)
	var effect:TokensFlashVisualEffect = TokensFlashVisualEffect.new(tokens, pulses, duration)
	effect.flash_color = flash_color
	return effect


func build_token_darken_effect(action:ReplayAction) -> BoardVisualEffect:
	var token:Token = get_action_token(action)
	
	if token == null:
		return skip_action(action, "Replay token does not exist on the current puppet board.")
	
	var amount:float = clamp(float(action.payload.get("amount", 0.3)), 0.0, 1.0)
	var duration:float = get_scaled_duration(action.payload, 0.12)
	return ColorTweenVisualEffect.new(token, ColorTweenVisualEffect.MODE.DARKEN, amount, duration)


func build_token_gravity_align_effect(action:ReplayAction) -> BoardVisualEffect:
	var token:Token = get_action_token(action)
	
	if token == null:
		return skip_action(action, "Replay token does not exist on the current puppet board.")
	
	var rotation_degrees:float = float(action.payload.get("rotation_degrees", 0.0))
	var duration:float = get_scaled_duration(action.payload, 0.18)
	return TokenGravityAlignVisualEffect.new(token, rotation_degrees, duration)


func build_wiggle_effect(action:ReplayAction) -> BoardVisualEffect:
	var token:Token = get_action_token(action)
	
	if token == null:
		return skip_action(action, "Replay token does not exist on the current puppet board.")
	
	var angle_degrees:float = float(action.payload.get("angle_degrees", 8.0))
	var wiggles:int = max(int(action.payload.get("wiggles", 3)), 1)
	var duration:float = get_scaled_duration(action.payload, 0.25)
	return WiggleVisualEffect.new(token, angle_degrees, wiggles, duration)

func build_chameleon_transform_effect(action:ReplayAction) -> BoardVisualEffect:
	var token:Token = get_action_token(action)
	
	if token == null:
		return skip_action(action, "Replay token does not exist on the current puppet board.")
	
	var fake_player_id:int = int(action.payload.get("fake_player_id", -1))
	
	if fake_player_id < 0:
		return skip_action(action, "Chameleon transform has no valid fake player ID.")
	
	var duration:float = get_scaled_duration(action.payload, 1.0)
	return ChameleonTransformVisualEffect.new(token, fake_player_id, duration)


func build_chameleon_reveal_effect(action:ReplayAction) -> BoardVisualEffect:
	var token:Token = get_action_token(action)
	
	if token == null:
		return skip_action(action, "Replay token does not exist on the current puppet board.")
	
	var duration:float = get_scaled_duration(action.payload, 0.55)
	return ChameleonRevealVisualEffect.new(token, duration)
	

func get_action_token(action:ReplayAction) -> Token:
	if action == null:
		return null
	
	if board_view == null:
		return null
	
	var token_id:int = int(action.payload.get("token_id", -1))
	
	if token_id < 0:
		return null
	
	return board_view.get_replay_token(token_id)


func get_scaled_duration(payload:Dictionary, default_duration:float) -> float:
	var recorded_duration:float = max(float(payload.get("duration", default_duration)), 0.0)
	return recorded_duration / max(playback_speed, MINIMUM_PLAYBACK_SPEED)


func vector2_from_data(value, fallback:Vector2) -> Vector2:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	
	var data:Array = value
	
	if data.size() != 2:
		return fallback
	
	return Vector2(float(data[0]), float(data[1]))


func colour_from_data(value, fallback:Color) -> Color:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	
	var data:Array = value
	
	if data.size() != 4:
		return fallback
	
	return Color(float(data[0]), float(data[1]), float(data[2]), float(data[3]))


func skip_action(action:ReplayAction, reason:String) -> BoardVisualEffect:
	var action_type:String = "unknown"
	
	if action != null:
		action_type = action.action_type
	
	push_warning("ReplayPresentationPlayer: Skipping presentation '%s'. %s" % [action_type, reason])
	presentation_skipped.emit(action_type)
	return null


func _finish_playback() -> void:
	if playback_active == false:
		return
	
	playback_active = false
	active_effect = null
	playback_finished.emit()
	
	var callback:Callable = finished_callback
	finished_callback = Callable()
	
	if callback.is_valid():
		callback.call()
