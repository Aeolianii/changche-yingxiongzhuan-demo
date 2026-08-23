extends SceneTree

const PIRATE_SCENE := preload("res://scenes/sea_overworld/sea_overworld_pirate.tscn")
const EXPECTED_HORIZONTAL_WATERLINE_Y := 17.0

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pirate := PIRATE_SCENE.instantiate() as SeaOverworldPirate
	root.add_child(pirate)
	await process_frame

	_verify_horizontal_wake(pirate, Vector2.LEFT, PI * 0.5, 1.0)
	_verify_horizontal_wake(pirate, Vector2.RIGHT, -PI * 0.5, -1.0)

	pirate.queue_free()
	if failures.is_empty():
		print("Sea-overworld pirate wake alignment verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_horizontal_wake(
	pirate: SeaOverworldPirate,
	direction: Vector2,
	expected_rotation: float,
	expected_stern_sign: float
) -> void:
	pirate.call("_update_facing", direction)
	pirate.call("_update_motion_visuals", 0.01, true)
	_expect(pirate.wake_sprite.visible, "A moving pirate must show its wake.")
	_expect(
		is_equal_approx(pirate.wake_sprite.rotation, expected_rotation),
		"Pirate wake rotation must continue to match the player wake logic."
	)
	_expect(
		signf(pirate.wake_sprite.position.x) == expected_stern_sign,
		"Pirate wake must remain on the stern side of horizontal movement."
	)
	_expect(
		is_equal_approx(pirate.wake_sprite.position.y, EXPECTED_HORIZONTAL_WATERLINE_Y),
		"Pirate wake must be lowered onto the horizontal hull waterline."
	)
	_expect(
		is_equal_approx(pirate.side_splash_sprite.position.y, EXPECTED_HORIZONTAL_WATERLINE_Y),
		"Pirate side splash must share the corrected horizontal hull waterline."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
