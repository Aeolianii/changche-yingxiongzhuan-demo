extends SceneTree

const CANAL_SCRIPT := preload("res://scripts/fubo_guling/fubo_canal_puzzle.gd")
const DRUM_SCRIPT := preload("res://scripts/fubo_guling/fubo_drum_memory.gd")
const FUBO_SCENE := preload("res://scenes/fubo_guling/fubo_guling.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_canal_truth_table()
	_test_drum_random_constraints()
	await _test_scene_contract()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("Fubo Guling skeleton verification passed.")
	quit(0)


func _test_canal_truth_table() -> void:
	var canal = CANAL_SCRIPT.new()
	var solved_count := 0
	for first in 3:
		for second in 3:
			for third in 3:
				canal.reset()
				canal.set_states_for_test(PackedInt32Array([first, second, third]), 6)
				var expected := first == 2 and second == 1 and third == 0
				if canal.is_completed() != expected:
					_fail("Canal completion mismatch for [%d, %d, %d]." % [first, second, third])
				if expected:
					solved_count += 1
				else:
					var active := canal.get_active_segments()
					if canal.get_spill_branch() != [first, second, third][active]:
						_fail("Canal spill branch must match the first incorrect gate.")
	_check(solved_count == 1, "Exactly one of the 27 canal states must solve the puzzle.")
	canal.reset()
	_check(canal.get_states() == PackedInt32Array([0, 2, 1]), "Canal initial state changed unexpectedly.")
	canal.set_states_for_test(PackedInt32Array([2, 1, 0]), 6)
	_check(canal.get_rating() == "善治", "Six-action canal solution must receive 善治.")
	canal.set_states_for_test(PackedInt32Array([2, 1, 0]), 8)
	_check(canal.get_rating() == "通达", "Eight-action canal solution must receive 通达.")


func _test_drum_random_constraints() -> void:
	var signatures: Array[String] = []
	for seed_value in [11, 22, 33]:
		var drum = DRUM_SCRIPT.new(seed_value)
		var sequences: Array[PackedInt32Array] = drum.get_sequences_for_test()
		var tempos: PackedFloat32Array = drum.get_round_tempos_for_test()
		_check(sequences.size() == 3, "Drum must generate three rounds.")
		_check(tempos.size() == 3, "Drum must generate one tempo per round.")
		for round_index in sequences.size():
			_check(sequences[round_index].size() == [4, 5, 6][round_index], "Drum round length mismatch.")
			for index in range(1, sequences[round_index].size()):
				_check(sequences[round_index][index] != sequences[round_index][index - 1], "Drum sequence cannot repeat an adjacent flag.")
		var third_round := sequences[2]
		_check(third_round.has(0) and third_round.has(1) and third_round.has(2), "Third drum round must contain all flag colors.")
		signatures.append(str(sequences) + str(tempos))
	var repeated = DRUM_SCRIPT.new(11)
	_check(str(repeated.get_sequences_for_test()) + str(repeated.get_round_tempos_for_test()) == signatures[0], "Identical drum seeds must reproduce the same challenge.")
	_check(signatures[0] != signatures[1] or signatures[1] != signatures[2], "Different drum seeds should produce varied challenges.")
	var mistake = DRUM_SCRIPT.new(44)
	mistake.start()
	var answer := mistake.get_current_sequence()
	var tempo := mistake.get_current_tempo()
	var wrong := (answer[0] + 1) % 3
	_check(mistake.submit(wrong) == DRUM_SCRIPT.SUBMIT_MISTAKE, "Wrong drum input must report a mistake.")
	_check(mistake.get_input_index() == 0, "Wrong drum input must reset only the current input cursor.")
	_check(mistake.get_current_sequence() == answer and is_equal_approx(mistake.get_current_tempo(), tempo), "Drum replay must retain the current answer and tempo.")


func _test_scene_contract() -> void:
	var level = FUBO_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	_check(level.get_phase_for_test() == 0, "Fubo scene must start in ARRIVAL phase.")
	_check(level.is_school_locked_for_test(), "School route must start locked.")
	_check(level.is_viewpoint_locked_for_test(), "Viewpoint route must start locked.")
	_check(level.get_node("World/WorldObjects").y_sort_enabled, "World objects must use Y sorting for occlusion.")
	_check(level.get_node("World/WorldObjects/Player/Camera2D").limit_right == 3200, "Camera right limit must match the medium map.")
	_check(level.get_node("World/WorldObjects/Player/Camera2D").limit_bottom == 2200, "Camera bottom limit must match the medium map.")
	_check(level.get_node("World/Ground/BackgroundPlates").get_child_count() == 4, "Medium map needs four local background plates.")
	for plate in level.get_node("World/Ground/BackgroundPlates").get_children():
		_check(plate is Sprite2D and plate.texture != null, "%s needs an imported background texture." % plate.name)
	var blocked_count := level.get_node("World/Collision/BlockedRegions").get_child_count()
	_check(blocked_count >= 6 and blocked_count <= 10, "Map must use 6-10 coarse blocked regions.")
	_check(level.get_node("World/Collision/HouseFoot/Shape").shape is RectangleShape2D, "House must use a separate foot collision shape.")
	_check(level.get_node("World/Triggers/CanalTrigger/Shape").shape is CircleShape2D, "Canal gameplay must be entered through a trigger area.")
	_check(level.get_node("World/Triggers/SchoolTrigger/Shape").shape is CircleShape2D, "School gameplay must be entered through a trigger area.")
	_check(level.get_node("Interface/MinigameHost") is Control, "Map needs a full-screen minigame host.")
	_check(level.get_node("World/WorldObjects").get_child_count() <= 16, "World object layer must stay deliberately sparse.")
	for prop_name in ["House", "Storage", "TreeCourtyard", "TreePath", "TreeCanal", "CanalMarker", "Drum", "FlagYellow", "FlagRed", "FlagBlue"]:
		_check(level.get_node("World/WorldObjects/" + prop_name).art_texture != null, "%s needs a modular pixel texture." % prop_name)
	level.finish_keeper_dialogue_for_test()
	_check(level.get_phase_for_test() == level.Phase.CANAL_AVAILABLE, "Keeper dialogue must only unlock the canal location.")
	_check(level.get_node("Interface/MinigameHost").active_minigame == null, "Keeper dialogue must not open the canal game directly.")
	level.trigger_canal_for_test()
	var host = level.get_node("Interface/MinigameHost")
	_check(host.active_minigame != null and host.active_minigame.game_id == "canal", "Canal trigger must open the canal minigame.")
	host.active_minigame.completed.emit({"game_id": "canal", "completed": true, "rating": "通达", "mistakes": 0, "duration_ms": 1000})
	await process_frame
	_check(level.get_phase_for_test() == level.Phase.DRUM_AVAILABLE and host.active_minigame == null, "Canal completion must restore the map and unlock the school.")
	level.trigger_drum_for_test()
	_check(host.active_minigame != null and host.active_minigame.game_id == "drum", "School trigger must open the drum minigame.")
	host.active_minigame.completed.emit({"game_id": "drum", "completed": true, "rating": "鼓点稳健", "mistakes": 1, "duration_ms": 1000})
	await process_frame
	_check(level.get_phase_for_test() == level.Phase.VIEWPOINT_OPEN and host.active_minigame == null, "Drum completion must restore the map and open the viewpoint.")
	level.queue_free()
	await process_frame
	await create_timer(0.55).timeout


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
