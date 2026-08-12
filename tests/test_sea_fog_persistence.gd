extends SceneTree

const PALACE_PATH := "res://scenes/palace/palace_demo.tscn"
const TEST_SAVE_PATH := "user://test_sea_fog_persistence.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	_expect(game_state != null, "GameState autoload must exist.")
	if game_state == null:
		_finish()
		return
	for method_name in ["set_sea_fog_state", "get_sea_fog_state", "reset_runtime_world_state"]:
		_expect(game_state.has_method(method_name), "GameState must provide %s for persistent chart exploration." % method_name)
	if not game_state.has_method("set_sea_fog_state"):
		_finish()
		return

	game_state.set("save_path_override", TEST_SAVE_PATH)
	_cleanup()
	var fog_state := {
		"version": 1,
		"cell_size": 16.0,
		"grid_width": 299,
		"grid_height": 169,
		"revealed_bits": "AQIDBA==",
	}
	game_state.call("set_sea_fog_state", fog_state)
	var save_result: Dictionary = game_state.call("save_game", PALACE_PATH, {"story_state": 2})
	_expect(bool(save_result.get("ok", false)), "Saving from a land scene must include the current sea-fog world state.")
	var saved_data = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	_expect(saved_data is Dictionary and (saved_data as Dictionary).has("world_state"), "Version-one save JSON must accept an optional world_state object.")

	game_state.call("reset_runtime_world_state")
	_expect((game_state.call("get_sea_fog_state") as Dictionary).is_empty(), "New-session reset must clear only runtime sea-fog state.")
	var load_result: Dictionary = game_state.call("load_game")
	_expect(bool(load_result.get("ok", false)), "Save containing sea-fog world state must load.")
	var restored_fog := game_state.call("get_sea_fog_state") as Dictionary
	_expect(
		int(restored_fog.get("version", 0)) == 1
		and int(restored_fog.get("grid_width", 0)) == 299
		and int(restored_fog.get("grid_height", 0)) == 169
		and str(restored_fog.get("revealed_bits", "")) == "AQIDBA==",
		"Loading from a land scene must restore the serialized sea-fog payload."
	)

	var legacy_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({
		"version": 1,
		"saved_at_unix": 1,
		"scene_path": PALACE_PATH,
		"scene_state": {"story_state": 2},
	}))
	legacy_file.close()
	game_state.call("set_sea_fog_state", fog_state)
	var legacy_result: Dictionary = game_state.call("load_game")
	_expect(bool(legacy_result.get("ok", false)), "Legacy saves without world_state must remain loadable.")
	_expect((game_state.call("get_sea_fog_state") as Dictionary).is_empty(), "Legacy saves must fall back to an empty fog state for harbor initialization.")

	game_state.set("save_path_override", "")
	game_state.call("reset_runtime_world_state")
	_cleanup()
	_finish()


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Sea fog persistence verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
