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
	var drum = DRUM_SCRIPT.new(55)
	drum.start()
	drum.begin_input()
	var sequence := drum.get_current_sequence()
	_check(drum.submit(sequence[0], 120) == DRUM_SCRIPT.SUBMIT_PROGRESS, "+120 ms must pass.")
	_check(drum.submit(sequence[1], -280) == DRUM_SCRIPT.SUBMIT_PROGRESS, "-280 ms must pass.")
	_check(drum.submit(sequence[2], 281) == DRUM_SCRIPT.SUBMIT_MISTAKE, "+281 ms must fail.")
	_check(drum.get_input_index() == 0, "Timing mistake must reset only the current input cursor.")
	_check(drum.get_current_sequence() == sequence, "Timing mistake must preserve the current sequence.")
	drum.begin_input()
	var wrong := (sequence[0] + 1) % 3
	_check(drum.submit(wrong, 0) == DRUM_SCRIPT.SUBMIT_MISTAKE, "Wrong drum must fail even on time.")
	_check(drum.get_round_index() == 0, "Wrong drum must retain current round.")


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
	for node_path in ["Layout/Drums/LeftDrum", "Layout/Drums/CenterDrum", "Layout/Drums/RightDrum"]:
		_check(scene.has_node(node_path) and scene.get_node(node_path) is Button, "%s must be a playable drum button." % node_path)
	var streams: Array[AudioStream] = []
	for node_path in ["AudioLow", "AudioMid", "AudioRim", "AudioFail"]:
		_check(scene.has_node(node_path) and scene.get_node(node_path) is AudioStreamPlayer, "%s must be an audio player." % node_path)
		if scene.has_node(node_path):
			streams.append(scene.get_node(node_path).stream)
	_check(streams.size() == 4 and not streams.has(null), "Every drum audio player needs a real stream.")
	if streams.size() == 4:
		_check(streams[0].resource_path != streams[1].resource_path and streams[1].resource_path != streams[2].resource_path, "The three drums must use distinct samples.")
	_check(scene.has_node("ExitConfirm") and not scene.get_node("ExitConfirm").visible, "Exit confirmation must start hidden.")
	_check(scene.has_node("ResumeCountdown") and not scene.get_node("ResumeCountdown").visible, "Resume countdown must start hidden.")
	scene.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
