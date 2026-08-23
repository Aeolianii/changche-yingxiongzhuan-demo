extends SceneTree

const PIRATE_SCENE := preload("res://scenes/sea_overworld/sea_overworld_pirate.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pirate := PIRATE_SCENE.instantiate() as SeaOverworldPirate
	root.add_child(pirate)
	await process_frame

	_verify_horizontal_wake(pirate, Vector2.LEFT, 1, -PI * 0.5, 1.0)
	_verify_horizontal_wake(pirate, Vector2.RIGHT, 2, PI * 0.5, -1.0)

	pirate.queue_free()
	if failures.is_empty():
		print("Sea-overworld pirate wake verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_horizontal_wake(
	pirate: SeaOverworldPirate,
	direction: Vector2,
	expected_facing: int,
	expected_rotation: float,
	expected_position_sign: float
) -> void:
	pirate.call("_update_facing", direction)
	pirate.call("_update_motion_visuals", 0.01, true)
	_expect(int(pirate.get("_facing_index")) == expected_facing, "Pirate facing did not match horizontal movement.")
	_expect(pirate.wake_sprite.visible, "A moving pirate must show its wake.")
	_expect(
		is_equal_approx(pirate.wake_sprite.rotation, expected_rotation),
		"Horizontal pirate wake must rotate away from the stern instead of across the ship."
	)
	_expect(
		signf(pirate.wake_sprite.position.x) == expected_position_sign,
		"Horizontal pirate wake must be positioned behind the stern."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
