extends Control

const TEST_REPLAY_PATH:String = "user://replays/70bf6cda-5801-4b03-b034-3ecc1589971f.afreplay"

var controller:ReplayController = null
var board_view:ReplayBoardView = null
var presentation_player:ReplayPresentationPlayer = null

var title_label:Label = null
var state_label:Label = null
var step_label:Label = null
var status_label:Label = null

var timeline:HSlider = null

var first_button:Button = null
var previous_button:Button = null
var play_pause_button:Button = null
var next_button:Button = null
var last_button:Button = null
var speed_selector:OptionButton = null

var timeline_is_being_updated:bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	build_interface()
	setup_controller()
	
	if resized.is_connected(_on_resized) == false:
		resized.connect(_on_resized)
	
	call_deferred("load_test_replay")


func _unhandled_key_input(event:InputEvent) -> void:
	var key_event:InputEventKey = event as InputEventKey
	
	if key_event == null:
		return
	
	if key_event.pressed == false:
		return
	
	if key_event.echo:
		return
	
	if controller == null:
		return
	
	if key_event.keycode == KEY_SPACE:
		controller.toggle_playback()
		get_viewport().set_input_as_handled()
		return
	
	if controller.is_busy():
		return
	
	if key_event.keycode == KEY_LEFT:
		controller.go_to_previous_step()
		get_viewport().set_input_as_handled()
		return
	
	if key_event.keycode == KEY_RIGHT:
		controller.go_to_next_step()
		get_viewport().set_input_as_handled()
		return
	
	if key_event.keycode == KEY_HOME:
		controller.go_to_first_step()
		get_viewport().set_input_as_handled()
		return
	
	if key_event.keycode == KEY_END:
		controller.go_to_last_step()
		get_viewport().set_input_as_handled()


func build_interface() -> void:
	var background:ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.02, 0.04, 0.08, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	board_view = ReplayBoardView.new()
	board_view.name = "Replay Board View"
	add_child(board_view)
	
	presentation_player = ReplayPresentationPlayer.new()
	presentation_player.name = "Replay Presentation Player"
	add_child(presentation_player)
	
	create_title_labels()
	create_status_label()
	create_timeline()
	create_navigation_buttons()


func create_title_labels() -> void:
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "Replay Viewer — Continuous Playback Test"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	add_child(title_label)
	
	title_label.anchor_left = 0.0
	title_label.anchor_top = 0.0
	title_label.anchor_right = 1.0
	title_label.anchor_bottom = 0.0
	title_label.offset_left = 20.0
	title_label.offset_top = 12.0
	title_label.offset_right = -20.0
	title_label.offset_bottom = 52.0
	
	state_label = Label.new()
	state_label.name = "State"
	state_label.text = "No replay loaded"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 19)
	add_child(state_label)
	
	state_label.anchor_left = 0.0
	state_label.anchor_top = 0.0
	state_label.anchor_right = 1.0
	state_label.anchor_bottom = 0.0
	state_label.offset_left = 20.0
	state_label.offset_top = 52.0
	state_label.offset_right = -20.0
	state_label.offset_bottom = 82.0
	
	step_label = Label.new()
	step_label.name = "Step Details"
	step_label.text = ""
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override("font_size", 16)
	add_child(step_label)
	
	step_label.anchor_left = 0.0
	step_label.anchor_top = 0.0
	step_label.anchor_right = 1.0
	step_label.anchor_bottom = 0.0
	step_label.offset_left = 20.0
	step_label.offset_top = 80.0
	step_label.offset_right = -20.0
	step_label.offset_bottom = 108.0


func create_status_label() -> void:
	status_label = Label.new()
	status_label.name = "Status"
	status_label.text = "Loading replay..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	add_child(status_label)
	
	status_label.anchor_left = 0.0
	status_label.anchor_top = 1.0
	status_label.anchor_right = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_left = 20.0
	status_label.offset_top = -148.0
	status_label.offset_right = -20.0
	status_label.offset_bottom = -122.0


func create_timeline() -> void:
	timeline = HSlider.new()
	timeline.name = "Timeline"
	timeline.min_value = 0.0
	timeline.max_value = 1.0
	timeline.step = 1.0
	timeline.value = 0.0
	timeline.editable = false
	timeline.focus_mode = Control.FOCUS_NONE
	add_child(timeline)
	
	timeline.anchor_left = 0.0
	timeline.anchor_top = 1.0
	timeline.anchor_right = 1.0
	timeline.anchor_bottom = 1.0
	timeline.offset_left = 70.0
	timeline.offset_top = -116.0
	timeline.offset_right = -70.0
	timeline.offset_bottom = -84.0
	
	timeline.value_changed.connect(_on_timeline_value_changed)


func create_navigation_buttons() -> void:
	var controls:HBoxContainer = HBoxContainer.new()
	controls.name = "Navigation Controls"
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	add_child(controls)
	
	controls.anchor_left = 0.0
	controls.anchor_top = 1.0
	controls.anchor_right = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_left = 20.0
	controls.offset_top = -76.0
	controls.offset_right = -20.0
	controls.offset_bottom = -22.0
	
	first_button = create_navigation_button("First")
	previous_button = create_navigation_button("Previous")
	play_pause_button = create_navigation_button("Play")
	next_button = create_navigation_button("Next Instant")
	last_button = create_navigation_button("Last")
	
	speed_selector = OptionButton.new()
	speed_selector.name = "Playback Speed"
	speed_selector.custom_minimum_size = Vector2(100.0, 44.0)
	speed_selector.focus_mode = Control.FOCUS_NONE
	
	speed_selector.add_item("0.5×")
	speed_selector.add_item("1×")
	speed_selector.add_item("2×")
	speed_selector.add_item("4×")
	speed_selector.select(1)
	
	controls.add_child(first_button)
	controls.add_child(previous_button)
	controls.add_child(play_pause_button)
	controls.add_child(next_button)
	controls.add_child(last_button)
	controls.add_child(speed_selector)
	
	first_button.pressed.connect(_on_first_pressed)
	previous_button.pressed.connect(_on_previous_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	next_button.pressed.connect(_on_next_pressed)
	last_button.pressed.connect(_on_last_pressed)
	speed_selector.item_selected.connect(_on_speed_selected)


func create_navigation_button(button_text:String) -> Button:
	var button:Button = Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(125.0, 44.0)
	button.focus_mode = Control.FOCUS_NONE
	return button


func setup_controller() -> void:
	controller = ReplayController.new()
	
	if controller.setup(board_view, presentation_player) == false:
		show_failure("Could not set up ReplayController.")
		return
	
	controller.replay_loaded.connect(_on_replay_loaded)
	controller.step_changed.connect(_on_step_changed)
	controller.navigation_changed.connect(_on_navigation_changed)
	controller.replay_error.connect(_on_replay_error)
	
	controller.playback_changed.connect(_on_playback_changed)
	controller.playback_speed_changed.connect(_on_playback_speed_changed)
	controller.replay_finished.connect(_on_replay_finished)
	
	controller.animated_step_started.connect(_on_animated_step_started)
	controller.animated_step_finished.connect(_on_animated_step_finished)


func load_test_replay() -> void:
	if controller == null:
		show_failure("ReplayController does not exist.")
		return
	
	if controller.load_replay(TEST_REPLAY_PATH) == false:
		return
	
	controller.set_playback_speed(1.0)
	
	status_label.text = "REAL MATCH REPLAY READY — Space toggles Play/Pause."
	refresh_current_step_display()
	refresh_playback_controls()
	refresh_board_layout()


func _on_replay_loaded() -> void:
	if controller == null:
		return
	
	var last_step_id:int = controller.get_last_step_id()
	
	timeline.min_value = 0.0
	timeline.max_value = max(float(last_step_id), 0.0)
	timeline.step = 1.0
	
	refresh_replay_title()
	refresh_playback_controls()


func _on_step_changed(step_id:int, step:ReplayStep, state:ReplayState) -> void:
	if controller == null:
		return
	
	if step == null:
		return
	
	if state == null:
		return
	
	update_timeline_value(step_id)
	refresh_state_label(step_id, step, state)
	refresh_playback_controls()


func _on_navigation_changed(can_go_previous:bool, can_go_next:bool) -> void:
	if first_button != null:
		first_button.disabled = can_go_previous == false
	
	if previous_button != null:
		previous_button.disabled = can_go_previous == false
	
	if next_button != null:
		next_button.disabled = can_go_next == false
	
	if last_button != null:
		last_button.disabled = can_go_next == false
	
	refresh_playback_controls()


func _on_playback_changed(is_playing:bool) -> void:
	refresh_playback_controls()
	
	if status_label == null:
		return
	
	if is_playing:
		status_label.text = "PLAYING — %.1f×" % controller.get_playback_speed()
	else:
		if controller.is_step_playing():
			status_label.text = "PAUSE REQUESTED — current presentation will finish first."
		else:
			status_label.text = "PAUSED — Step %d" % controller.get_current_step_id()


func _on_playback_speed_changed(speed:float) -> void:
	refresh_playback_controls()
	
	if status_label == null:
		return
	
	if controller != null and controller.is_playing():
		status_label.text = "PLAYING — %.1f× — new speed applies from the next presentation." % speed
	else:
		status_label.text = "Playback speed: %.1f×" % speed


func _on_animated_step_started(step_id:int) -> void:
	refresh_playback_controls()
	
	if status_label != null:
		status_label.text = "PLAYING STEP %d — %.1f×" % [step_id, controller.get_playback_speed()]


func _on_animated_step_finished(step_id:int) -> void:
	refresh_playback_controls()
	
	if status_label == null:
		return
	
	if controller.is_playing():
		status_label.text = "Step %d complete — continuing..." % step_id
	else:
		status_label.text = "Paused at Step %d." % step_id


func _on_replay_finished() -> void:
	refresh_playback_controls()
	
	if status_label != null:
		status_label.text = "REPLAY FINISHED — press Play or Space to restart from the beginning."


func _on_timeline_value_changed(value:float) -> void:
	if timeline_is_being_updated:
		return
	
	if controller == null:
		return
	
	if controller.is_busy():
		return
	
	var target_step_id:int = int(round(value))
	controller.go_to_step(target_step_id)


func _on_first_pressed() -> void:
	if controller == null:
		return
	
	controller.go_to_first_step()


func _on_previous_pressed() -> void:
	if controller == null:
		return
	
	controller.go_to_previous_step()


func _on_play_pause_pressed() -> void:
	if controller == null:
		return
	
	controller.toggle_playback()


func _on_next_pressed() -> void:
	if controller == null:
		return
	
	controller.go_to_next_step()


func _on_last_pressed() -> void:
	if controller == null:
		return
	
	controller.go_to_last_step()


func _on_speed_selected(index:int) -> void:
	if controller == null:
		return
	
	match index:
		0:
			controller.set_playback_speed(0.5)
		1:
			controller.set_playback_speed(1.0)
		2:
			controller.set_playback_speed(2.0)
		3:
			controller.set_playback_speed(4.0)


func update_timeline_value(step_id:int) -> void:
	if timeline == null:
		return
	
	timeline_is_being_updated = true
	timeline.set_value_no_signal(float(step_id))
	timeline_is_being_updated = false


func refresh_playback_controls() -> void:
	if controller == null:
		return
	
	if timeline != null:
		timeline.editable = controller.has_loaded_replay() and controller.is_busy() == false and controller.get_last_step_id() > 0
	
	if play_pause_button != null:
		if controller.is_playing():
			play_pause_button.text = "Pause"
			play_pause_button.disabled = false
		else:
			play_pause_button.text = "Play"
			
			if controller.is_step_playing():
				play_pause_button.disabled = true
			else:
				play_pause_button.disabled = controller.has_loaded_replay() == false
	
	if speed_selector != null:
		speed_selector.disabled = controller.has_loaded_replay() == false


func refresh_replay_title() -> void:
	if title_label == null:
		return
	
	if controller == null:
		return
	
	var replay:ReplayData = controller.get_replay()
	
	if replay == null:
		return
	
	title_label.text = "Replay Viewer — %s — Continuous Playback Test" % replay.match_id


func refresh_current_step_display() -> void:
	if controller == null:
		return
	
	var step:ReplayStep = controller.get_current_step()
	var state:ReplayState = controller.get_current_state()
	
	if step == null or state == null:
		return
	
	refresh_state_label(controller.get_current_step_id(), step, state)


func refresh_state_label(step_id:int, step:ReplayStep, state:ReplayState) -> void:
	if state_label != null:
		state_label.text = "Step %d / %d   •   Round %d   •   Turn %d   •   Player %d   •   Gravity: %s   •   Tokens: %d" % [step_id, controller.get_last_step_id(), state.round_number, state.turn_number, state.player_id + 1, state.gravity.capitalize(), state.get_token_count()]
	
	if step_label != null:
		var presentation_text:String = "No presentation"
		
		if step.presentation != null:
			presentation_text = "Presentation: %s" % describe_presentation(step.presentation)
		
		step_label.text = "Type: %s   •   State actions: %d   •   %s" % [format_step_type(step.step_type), step.state_actions.size(), presentation_text]


func describe_presentation(action:ReplayAction) -> String:
	if action == null:
		return "none"
	
	if action.is_sequence():
		return "sequence (%d children)" % action.children.size()
	
	if action.is_parallel():
		return "parallel (%d children)" % action.children.size()
	
	return action.action_type.replace("_", " ")


func format_step_type(step_type:String) -> String:
	return step_type.replace("_", " ").capitalize()


func refresh_board_layout() -> void:
	if board_view == null:
		return
	
	var available_rect:Rect2 = Rect2(Vector2(0.0, 112.0), Vector2(size.x, max(size.y - 275.0, 1.0)))
	board_view.fit_to_rect(available_rect, 25.0)


func show_failure(message:String) -> void:
	push_error("ReplayViewerTest: " + message)
	
	if status_label != null:
		status_label.text = "FAILED: " + message


func _on_replay_error(message:String) -> void:
	show_failure(message)


func _on_resized() -> void:
	refresh_board_layout()
