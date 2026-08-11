class_name FuboMinigameBase
extends Control

signal completed(result: Dictionary)
signal exit_requested
signal round_restarted(round_index: int)

@export var game_id := ""
@export_file("*.tscn") var standalone_return_scene_path := ""


func build_result(rating: String, mistakes: int, duration_ms: int) -> Dictionary:
	return {
		"game_id": game_id,
		"completed": true,
		"rating": rating,
		"mistakes": maxi(0, mistakes),
		"duration_ms": maxi(0, duration_ms),
	}


func request_exit() -> void:
	if get_signal_connection_list(&"exit_requested").is_empty():
		if standalone_return_scene_path.is_empty():
			push_warning("Minigame exit requested without a host or standalone return scene.")
			return
		_change_to_standalone_return_scene(standalone_return_scene_path)
		return
	exit_requested.emit()


func _change_to_standalone_return_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not return from standalone minigame to %s: %s" % [scene_path, error_string(error)])
