extends SceneTree

const PALACE_SCENE := preload("res://scenes/palace/palace_demo.tscn")
const SCENE_TWO := preload("res://scenes/Scene2.tscn")
const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const FUBO_SCENE := preload("res://scenes/fubo_guling/fubo_guling.tscn")
const FUBO_SAVE_STATE := preload("res://scripts/fubo_guling/fubo_save_state.gd")
const FUBO_TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")
const PALACE_PATH := "res://scenes/palace/palace_demo.tscn"
const SCENE_TWO_PATH := "res://scenes/Scene2.tscn"
const SEA_PATH := "res://scenes/sea_overworld/sea_overworld.tscn"
const FUBO_PATH := "res://scenes/fubo_guling/fubo_guling.tscn"
const TEST_SAVE_PATH := "user://test_main_flow_save.json"

var failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game_state = root.get_node_or_null("GameState")
	_expect(game_state != null, "GameState autoload must exist.")
	if game_state == null:
		_finish()
		return
	game_state.set("save_path_override", TEST_SAVE_PATH)
	_cleanup_test_files()
	_verify_save_file_contract()
	await _verify_palace_restore()
	await _verify_scene_two_restore()
	await _verify_sea_restore()
	await _verify_fubo_restore()
	_cleanup_test_files()
	game_state.set("save_path_override", "")
	game_state.call("clear_pending_scene_state")
	_finish()


func _verify_save_file_contract() -> void:
	var missing_result: Dictionary = game_state.call("load_game")
	_expect(not missing_result.get("ok", false) and missing_result.get("reason") == "missing_save", "Missing save must fail without changing progress.")
	var snapshot := {
		"story_state": 2,
		"player_position": [700.0, 820.0],
		"attendant_position": [710.0, 832.0],
	}
	var save_result: Dictionary = game_state.call("save_game", PALACE_PATH, snapshot)
	_expect(save_result.get("ok", false), "GameState must write a valid versioned save.")
	var load_result: Dictionary = game_state.call("load_game")
	_expect(load_result.get("ok", false) and load_result.get("scene_path") == PALACE_PATH, "GameState must load the saved scene path.")
	var restored: Dictionary = game_state.call("consume_pending_scene_state", PALACE_PATH)
	_expect(int(restored.get("story_state", -1)) == 2, "GameState must preserve integer-like scene progress.")
	_expect(restored.get("player_position", []) == [700.0, 820.0], "GameState must preserve serialized positions.")
	_expect((game_state.call("consume_pending_scene_state", PALACE_PATH) as Dictionary).is_empty(), "Pending scene state must be one-shot.")
	var corrupt_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	corrupt_file.store_string("{not valid json")
	corrupt_file.close()
	var corrupt_result: Dictionary = game_state.call("load_game")
	_expect(not corrupt_result.get("ok", false) and corrupt_result.get("reason") == "invalid_json", "Corrupt saves must fail without creating pending state.")
	var incompatible_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	incompatible_file.store_string(JSON.stringify({
		"version": 99,
		"saved_at_unix": 1,
		"scene_path": PALACE_PATH,
		"scene_state": {},
	}))
	incompatible_file.close()
	var incompatible_result: Dictionary = game_state.call("load_game")
	_expect(not incompatible_result.get("ok", false) and incompatible_result.get("reason") == "unsupported_version", "Incompatible save versions must be rejected safely.")


func _verify_palace_restore() -> void:
	var snapshot := {
		"story_state": 2,
		"player_position": [742.0, 806.0],
		"attendant_position": [710.0, 832.0],
	}
	game_state.call("save_game", PALACE_PATH, snapshot)
	game_state.call("load_game")
	var scene := PALACE_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	_expect(int(scene.get("story_state")) == 2, "Palace must restore the stable WAIT_TALK story state.")
	_expect((scene.get_node("YSortedCharacters/Player") as Node2D).global_position.is_equal_approx(Vector2(742, 806)), "Palace must restore the player position.")
	_expect((root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/TaskName") as Label).text == "听取内侍传召", "Palace must restore the task projection for WAIT_TALK.")
	(root.get_node("ExplorationUI/HUD").find_child("SaveGameButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(_saved_scene_path() == PALACE_PATH, "Palace menu save signal must write a palace snapshot.")
	await _free_current_scene(scene)


func _verify_scene_two_restore() -> void:
	var snapshot := {
		"patrol_task_stage": 2,
		"heard_soldier_roles": ["patrol_soldier_left", "patrol_soldier_right"],
		"player_position": [640.0, 690.0],
		"last_direction": "left",
	}
	game_state.call("save_game", SCENE_TWO_PATH, snapshot)
	game_state.call("load_game")
	var scene := SCENE_TWO.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	_expect(int(scene.get("_patrol_task_stage")) == 2, "Scene2 must restore the patrol task stage.")
	_expect((scene.get("_heard_soldier_reports") as Dictionary).size() == 2, "Scene2 must restore deduplicated soldier reports.")
	_expect((scene.get_node("World/Actors/Player") as Node2D).global_position.is_equal_approx(Vector2(640, 690)), "Scene2 must restore the player position.")
	_expect("中军军官" in (root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label).text, "Scene2 must restore the officer-report objective.")
	(root.get_node("ExplorationUI/HUD").find_child("SaveGameButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(_saved_scene_path() == SCENE_TWO_PATH, "Scene2 menu save signal must write a Scene2 snapshot.")
	await _free_current_scene(scene)


func _verify_sea_restore() -> void:
	var snapshot := {
		"player_position": [2450.0, 1400.0],
		"facing_index": 2,
		"exploration_stage": 3,
		"lunar_day": 14.75,
	}
	game_state.call("save_game", SEA_PATH, snapshot)
	game_state.call("load_game")
	var scene := SEA_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	var player := scene.get_node("World/Player") as Node2D
	_expect(player.global_position.is_equal_approx(Vector2(2450, 1400)), "Sea overworld must restore the player position on clear production-map water.")
	_expect(int(player.call("save_facing_index")) == 2, "Sea overworld must restore the ship facing direction.")
	_expect(int(scene.get("_exploration_stage")) == 3, "Sea overworld must restore its exploration stage.")
	_expect(is_equal_approx(float(scene.get("_lunar_day")), 14.75), "Sea overworld must restore lunar progress.")
	_expect("海上的船只" in (root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label).text, "Sea overworld must restore the stage-three objective.")
	(root.get_node("ExplorationUI/HUD").find_child("SaveGameButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(_saved_scene_path() == SEA_PATH, "Sea-overworld menu save signal must write a sea snapshot.")
	await _free_current_scene(scene)


func _verify_fubo_restore() -> void:
	var sea_context := FUBO_TRAVEL.make_context(Vector2(4260, 780), 2, 3, 14.75)
	var snapshot: Dictionary = FUBO_SAVE_STATE.make_snapshot(Vector2(902, 518), "left", 3, sea_context)
	var save_result: Dictionary = game_state.call("save_game", FUBO_PATH, snapshot)
	_expect(save_result.get("ok", false), "GameState must accept a validated Fubo stable snapshot.")
	game_state.call("load_game")
	var scene := FUBO_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	var player := scene.get_node("World/WorldObjects/Player") as CharacterBody2D
	_expect(int(scene.get("phase")) == 3, "Fubo must restore the stable DRUM_AVAILABLE phase.")
	_expect(player.global_position.is_equal_approx(Vector2(902, 518)), "Fubo must restore the player position.")
	_expect(str(player.get("facing")) == "left", "Fubo must restore the player facing.")
	_expect(not scene.call("is_school_locked_for_test") and scene.call("is_viewpoint_locked_for_test"), "Fubo must derive its barrier state from saved progress.")
	_expect("古校场" in (root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label).text, "Fubo must restore its task projection.")
	var restored_context := FUBO_TRAVEL.decode_context(root.get_meta(FUBO_TRAVEL.RETURN_CONTEXT_META, {}))
	_expect(not restored_context.is_empty() and (restored_context["ship_position"] as Vector2).is_equal_approx(Vector2(4260, 780)), "Fubo must restore its sea-return context.")
	(root.get_node("ExplorationUI/HUD").find_child("SaveGameButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(_saved_scene_path() == FUBO_PATH, "Fubo menu save signal must write a Fubo snapshot.")
	var stable_save := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	_expect(scene.call("trigger_drum_for_test"), "Fubo save test must enter the drum minigame.")
	(root.get_node("ExplorationUI/HUD").find_child("SaveGameButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(FileAccess.get_file_as_string(TEST_SAVE_PATH) == stable_save, "Saving during a Fubo minigame must not overwrite the stable save.")
	await _free_current_scene(scene)


func _free_current_scene(scene: Node) -> void:
	current_scene = null
	scene.queue_free()
	await process_frame


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE_PATH, TEST_SAVE_PATH + ".tmp", TEST_SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _saved_scene_path() -> String:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return str(parsed.get("scene_path", "")) if parsed is Dictionary else ""


func _finish() -> void:
	if failures.is_empty():
		print("Main-flow save runtime verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
