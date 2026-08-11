extends SceneTree

const FISHING_SCRIPT := preload("res://scripts/fubo_guling/fubo_fishing_game.gd")
const FISHING_SCENE := preload("res://scenes/fubo_guling/minigames/fubo_fishing_minigame.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_seeded_items_are_reproducible()
	_test_cast_catches_and_scores()
	_test_heavy_catch_retracts_slower()
	_test_target_can_be_reached()
	_test_timeout_and_restart()
	await _test_scene_contract()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("Fubo fishing game verification passed.")
	quit(0)


func _test_seeded_items_are_reproducible() -> void:
	var first = FISHING_SCRIPT.new(20260811)
	var second = FISHING_SCRIPT.new(20260811)
	_check(first.get_items() == second.get_items(), "Identical seeds must reproduce fishing catches.")
	_check(first.get_score() == 0 and first.get_time_left() == 60.0, "Fishing must start at zero score with sixty seconds.")


func _test_cast_catches_and_scores() -> void:
	var game = FISHING_SCRIPT.new(9)
	game.place_item_on_hook_path_for_test(0, 105.0, "small_fish")
	_check(game.cast_hook(), "A swinging hook must launch.")
	_check(not game.cast_hook(), "A moving hook must reject a second launch.")
	_run_until_swinging(game)
	_check(game.get_score() == 55, "Landing a small fish must add its visible score.")
	_check(game.get_state() == FISHING_SCRIPT.State.SWINGING, "Hook must resume swinging after landing a catch.")


func _test_heavy_catch_retracts_slower() -> void:
	var light = FISHING_SCRIPT.new(12)
	light.place_item_on_hook_path_for_test(0, 165.0, "small_fish")
	light.cast_hook()
	var light_steps := _run_until_swinging(light)
	var heavy = FISHING_SCRIPT.new(12)
	heavy.place_item_on_hook_path_for_test(0, 165.0, "big_fish")
	heavy.cast_hook()
	var heavy_steps := _run_until_swinging(heavy)
	_check(heavy_steps > light_steps, "A valuable heavy fish must retract slower than a small fish.")
	_check(heavy.get_score() == 130, "A big fish must award its higher score.")


func _test_target_can_be_reached() -> void:
	var game = FISHING_SCRIPT.new(33)
	for catch_index in 4:
		game.place_item_on_hook_path_for_test(catch_index, 105.0, "big_fish")
		_check(game.cast_hook(), "Each returned hook must allow the next cast.")
		_run_until_swinging_or_finished(game)
	_check(game.get_score() == 520, "Four big fish must reach the documented 500-point target.")
	_check(game.get_state() == FISHING_SCRIPT.State.FINISHED, "Reaching the target must finish the fishing game.")


func _test_timeout_and_restart() -> void:
	var game = FISHING_SCRIPT.new(5)
	game.set_time_left_for_test(0.01)
	game.step(0.02)
	_check(game.get_state() == FISHING_SCRIPT.State.FAILED, "Running out of time below target must fail clearly.")
	game.restart()
	_check(game.get_state() == FISHING_SCRIPT.State.SWINGING, "Retry must restore the swinging hook.")
	_check(game.get_score() == 0 and game.get_time_left() == 60.0, "Retry must reset score and timer.")


func _run_until_swinging(game) -> int:
	var steps := 0
	while steps < 500 and game.get_state() != FISHING_SCRIPT.State.SWINGING:
		game.step(0.016)
		steps += 1
	return steps


func _run_until_swinging_or_finished(game) -> int:
	var steps := 0
	while steps < 500 and game.get_state() != FISHING_SCRIPT.State.SWINGING and game.get_state() != FISHING_SCRIPT.State.FINISHED:
		game.step(0.016)
		steps += 1
	return steps


func _test_scene_contract() -> void:
	var ui = FISHING_SCENE.instantiate()
	root.add_child(ui)
	await process_frame
	_check(ui.game_id == "fishing", "Fishing scene must expose fishing game id.")
	_check(ui.process_mode == Node.PROCESS_MODE_ALWAYS and ui.can_process(), "Fishing root must process while hosted.")
	_check(ui.get_node("ExitButton").can_process(), "Fishing exit button must receive input.")
	_check("空格" in ui.get_node("Layout/Instruction").text and "自动收线" in ui.get_node("Layout/Instruction").text, "Fishing instructions must explain the one-button loop.")
	_check(ui.get_node("Layout/FishingBoard").custom_minimum_size == Vector2(840, 520), "Fishing must reserve a large visible playfield.")
	_check(ui.get_node("Layout/ActionButton") is Button, "Fishing needs a clear on-screen cast button.")
	var backdrop: TextureRect = ui.get_node("BackdropArt")
	_check(backdrop.texture != null and backdrop.texture.resource_path == "res://assets/fubo_guling/backgrounds/fubo_guling_complete.png", "Fishing scene needs the approved pixel-art environment backdrop.")
	var accept_event := InputEventAction.new()
	accept_event.action = "ui_accept"
	accept_event.pressed = true
	Input.parse_input_event(accept_event)
	await process_frame
	_check(ui.get_game_for_test().get_state() != FISHING_SCRIPT.State.SWINGING, "Space/accept input must launch the real hosted hook.")
	ui.get_game_for_test().restart()
	ui.get_node("Layout/FishingBoard").emit_signal("cast_requested")
	await process_frame
	_check(ui.get_game_for_test().get_state() != FISHING_SCRIPT.State.SWINGING, "Clicking the illustrated sea must launch the hook.")
	var exit_seen := [false]
	ui.exit_requested.connect(func(): exit_seen[0] = true)
	ui.get_node("ExitButton").pressed.emit()
	await process_frame
	_check(exit_seen[0], "The top-right leave button must request exit in one action.")
	ui.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
