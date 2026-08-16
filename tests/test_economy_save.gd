extends SceneTree

const TEST_SAVE := "user://test_economy_save.json"
const PALACE := "res://scenes/palace/palace_demo.tscn"
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("save_path_override", TEST_SAVE)
	_cleanup()
	game_state.call("reset_runtime_world_state")
	var defaults: Dictionary = game_state.call("get_economy_state")
	_expect(defaults["pay"] == 800 and defaults["ships"].size() == 3, "GameState must expose all three starting ship types.")
	game_state.call("add_economy_item", "grouper", 2)
	game_state.call("add_military_pay", 75)
	_expect(game_state.call("buy_economy_blueprint", "patrol_boat").get("ok", false), "GameState trade facade must buy a blueprint.")
	_expect(game_state.call("save_game", PALACE, {}).get("ok", false), "Version 2 save must succeed.")
	game_state.call("reset_runtime_world_state")
	_expect(game_state.call("load_game").get("ok", false), "Version 2 save must load.")
	var restored: Dictionary = game_state.call("get_economy_state")
	_expect(restored["pay"] == 575 and restored["items"]["grouper"] == 2, "Economy must survive disk round trip.")
	var v1 := {"version": 1, "saved_at_unix": 1, "scene_path": PALACE, "scene_state": {}, "world_state": {}}
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1)); file.close()
	game_state.call("reset_runtime_world_state")
	_expect(game_state.call("load_game").get("ok", false), "Version 1 save must remain readable.")
	_expect(game_state.call("get_economy_state")["pay"] == 800, "Version 1 must receive default economy.")
	_cleanup(); game_state.set("save_path_override", ""); game_state.call("clear_pending_scene_state")
	if failures.is_empty(): print("Economy save verification passed."); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)

func _cleanup() -> void:
	for path in [TEST_SAVE, TEST_SAVE + ".tmp", TEST_SAVE + ".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
