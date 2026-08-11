extends SceneTree

const DRUM_SCRIPT := preload("res://scripts/fubo_guling/fubo_drum_memory.gd")
const DRUM_SCENE := preload("res://scenes/fubo_guling/minigames/fubo_drum_minigame.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_random_constraints()
	_test_timing_windows_and_round_reset()
	_test_seed_reproducibility()
	await _test_scene_contract()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("Fubo drum game verification passed.")
	quit(0)


func _test_random_constraints() -> void:
	var drum = DRUM_SCRIPT.new(20260810)
	var sequences: Array[PackedInt32Array] = drum.get_sequences_for_test()
	var bpms: PackedInt32Array = drum.get_round_bpms_for_test()
	var intervals: Array[PackedInt32Array] = drum.get_round_intervals_for_test()
	_check(sequences.size() == 3 and bpms.size() == 3 and intervals.size() == 3, "Drum must generate three rounds.")
	for round_index in 3:
		_check(sequences[round_index].size() == [4, 5, 6][round_index], "Drum round length mismatch.")
		_check(bpms[round_index] in [72, 84, 96], "Drum BPM must use the approved set.")
		_check(intervals[round_index].size() == sequences[round_index].size(), "Every beat needs an interval.")
		if round_index > 0:
			_check(bpms[round_index] != bpms[round_index - 1], "Adjacent rounds cannot reuse BPM.")
		for index in range(1, sequences[round_index].size()):
			_check(sequences[round_index][index] != sequences[round_index][index - 1], "Adjacent drums cannot repeat.")
	_check(sequences[2].has(0) and sequences[2].has(1) and sequences[2].has(2), "Third round must include all drums.")


func _test_timing_windows_and_round_reset() -> void:
	for timing_ms in [-1000, -281, -120, 0, 280, 520]:
		var boundary_drum = DRUM_SCRIPT.new(55)
		boundary_drum.start()
		boundary_drum.begin_input()
		var boundary_sequence := boundary_drum.get_current_sequence()
		_check(boundary_drum.submit(boundary_sequence[0], timing_ms) == DRUM_SCRIPT.SUBMIT_PROGRESS, "%+d ms on the correct drum must pass." % timing_ms)

	var drum = DRUM_SCRIPT.new(55)
	drum.start()
	drum.begin_input()
	var sequence := drum.get_current_sequence()
	_check(drum.submit(sequence[0], 521) == DRUM_SCRIPT.SUBMIT_MISTAKE, "+521 ms must fail.")
	_check(drum.get_input_index() == 0, "Timing mistake must reset only the current input cursor.")
	_check(drum.get_current_sequence() == sequence, "Timing mistake must preserve the current sequence.")
	drum.begin_input()
	var wrong := (sequence[0] + 1) % 3
	_check(drum.submit(wrong, -1000) == DRUM_SCRIPT.SUBMIT_MISTAKE, "Wrong drum must fail even when played early.")
	_check(drum.get_round_index() == 0, "Wrong drum must retain current round.")
	_check(drum.get_timing_label(-121) == "提前 · 通过", "Early correct input needs an explicit passing label.")
	_check(drum.get_timing_label(-120) == "正拍", "-120 ms must be labelled on beat.")
	_check(drum.get_timing_label(120) == "正拍", "+120 ms must be labelled on beat.")
	_check(drum.get_timing_label(121) == "稍晚 · 通过", "Late passing input needs an explicit label.")
	_check(drum.get_timing_label(521) == "过晚", "Late failure needs an explicit label.")


func _test_seed_reproducibility() -> void:
	var first = DRUM_SCRIPT.new(91)
	var second = DRUM_SCRIPT.new(91)
	_check(first.get_sequences_for_test() == second.get_sequences_for_test(), "Identical seeds must reproduce sequences.")
	_check(first.get_round_bpms_for_test() == second.get_round_bpms_for_test(), "Identical seeds must reproduce BPMs.")
	_check(first.get_round_intervals_for_test() == second.get_round_intervals_for_test(), "Identical seeds must reproduce beat intervals.")


func _test_scene_contract() -> void:
	var scene = DRUM_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.game_id == "drum", "Drum scene must identify itself to the minigame host.")
	var return_path = scene.get("standalone_return_scene_path")
	_check(return_path == "res://scenes/fubo_guling/fubo_guling.tscn", "Standalone drum play must return to the Fubo map instead of closing the application.")
	_check(scene.process_mode == Node.PROCESS_MODE_ALWAYS and scene.can_process(), "Drum root must process keyboard input while the hosted map tree is not paused.")
	for node_path in ["Layout/Drums/LeftDrum", "Layout/Drums/CenterDrum", "Layout/Drums/RightDrum"]:
		_check(scene.has_node(node_path) and scene.get_node(node_path) is Button, "%s must be a playable drum button." % node_path)
	var stage = scene.get_node("Layout/DrumStage")
	_check(stage is FuboDrumStage, "Drum scene must have a visible clickable pixel-art court.")
	_check(stage.drum_texture != null and stage.drum_texture.resource_path == "res://assets/fubo_guling/generated/modular/drum.png", "Drum stage must use the existing transparent Chinese war-drum art.")
	var drum_rects: Array[Rect2] = stage.get_drum_rects_for_test()
	_check(drum_rects.size() == 3 and drum_rects[0].size.x > drum_rects[1].size.x and drum_rects[1].size.x > drum_rects[2].size.x, "The three visible drums need distinct sizes and hierarchy.")
	var clicked := [-1]
	stage.drum_pressed.connect(func(index: int): clicked[0] = index)
	stage.set_input_enabled(true)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = drum_rects[1].get_center()
	stage._gui_input(click_event)
	_check(clicked[0] == 1, "Clicking a visible drum face must use the real stage input path.")
	var streams: Array[AudioStream] = []
	for node_path in ["AudioLow", "AudioMid", "AudioRim", "AudioFail"]:
		_check(scene.has_node(node_path) and scene.get_node(node_path) is AudioStreamPlayer, "%s must be an audio player." % node_path)
		if scene.has_node(node_path):
			streams.append(scene.get_node(node_path).stream)
	_check(streams.size() == 4 and not streams.has(null), "Every drum audio player needs a real stream.")
	if streams.size() == 4:
		_check(streams[0].resource_path != streams[1].resource_path and streams[1].resource_path != streams[2].resource_path, "The three drums must use distinct samples.")
		_check(streams[0].get_length() > streams[1].get_length() and streams[1].get_length() > streams[2].get_length(), "Low, middle and rim drums must have clearly different decay lengths.")
	_check(FileAccess.file_exists("res://assets/audio/fubo_guling/sources/taiko_drum_001_hq.mp3"), "The licensed source sample must remain in the project for provenance.")
	_check(not scene.has_node("ExitConfirm"), "Drum exit must not use a second confirmation dialog.")
	var exit_button: Button = scene.get_node("ExitButton")
	_check(exit_button.text == "返回古岭", "The exit action must clearly describe where it goes.")
	_check(exit_button.has_theme_stylebox_override("normal") and exit_button.has_theme_stylebox_override("hover") and exit_button.has_theme_stylebox_override("pressed"), "The return action must look like a clickable bronze-framed button, not floating text.")
	var exit_count := [0]
	scene.exit_requested.connect(func(): exit_count[0] += 1)
	exit_button.pressed.emit()
	await process_frame
	_check(exit_count[0] == 1, "The visible return button must immediately request exit.")
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true
	scene._unhandled_input(escape_event)
	_check(exit_count[0] == 2, "Escape must use the same direct-exit path as the return button.")
	_check(scene.has_node("ResumeCountdown") and not scene.get_node("ResumeCountdown").visible, "Resume countdown must start hidden.")
	_check(scene.has_node("Layout/ReadyButton") and scene.get_node("Layout/ReadyButton") is Button, "Drum scene needs an explicit player-ready button.")
	var timing_meter = scene.get_node_or_null("Layout/BeatTrack")
	_check(timing_meter != null and timing_meter.has_method("set_timing_error"), "The ordinary progress bar must be replaced by an explanatory timing meter.")
	_check(scene.has_node("Layout/TimingLabels"), "The timing meter needs visible early, on-beat and late zones.")
	var rule_label = scene.get_node_or_null("Layout/RuleLabel")
	_check(rule_label is Label and "提前按下不会失败" in rule_label.text and "0.52" in rule_label.text, "Failure rules must stay visible instead of being inferred from a mistake.")
	if streams.size() == 4:
		_check(streams[3].get_length() < 0.3, "The failure cue must be a short, gentle accent under 0.3 seconds.")
	scene.enter_ready_state_for_test()
	var mistakes_before: int = scene.get_mistakes_for_test()
	scene._process(10.0)
	_check(scene.is_waiting_for_ready_for_test(), "The ready phase must wait indefinitely after the demonstration.")
	_check(scene.get_mistakes_for_test() == mistakes_before, "Waiting before starting must never count as a timing mistake.")
	_check(scene.get_node("Layout/ReadyButton").visible, "The ready button must be visible while timing is suspended.")
	scene.get_node("Layout/ReadyButton").pressed.emit()
	await process_frame
	_check(scene.is_counting_in_for_test(), "Pressing the ready button must begin the 3-2-1 countdown.")
	scene.enter_ready_state_for_test()
	scene.begin_player_turn_immediately_for_test()
	_check(scene.is_waiting_for_first_input_for_test(), "The first input must wait for the player's active downbeat.")
	var first_result: int = await scene.submit_drum_for_test(scene.get_current_sequence_for_test()[0])
	_check(first_result == DRUM_SCRIPT.SUBMIT_PROGRESS, "A correct first drum must start the rhythm without a waiting-time penalty.")
	_check(not scene.is_waiting_for_first_input_for_test(), "Timing must begin only after the player plays the first beat.")
	scene.queue_free()
	await process_frame

	var standalone_scene = DRUM_SCENE.instantiate()
	root.add_child(standalone_scene)
	current_scene = standalone_scene
	await process_frame
	standalone_scene.request_exit()
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/fubo_guling/fubo_guling.tscn", "Standalone return must keep the application alive and switch to the Fubo map.")
	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
