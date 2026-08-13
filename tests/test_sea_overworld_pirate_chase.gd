extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const PIRATE_ATLAS := preload("res://assets/sprites/sea_overworld/pirate_ship_4dir_states_v1.png")
const HARBOR_POSITION := Vector2(880, 1170)

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(_atlas_boundaries_are_clear(), "Pirate atlas sprites must not bleed across 4x2 cell boundaries.")
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.call("reset_runtime_world_state")
	var scene := SEA_SCENE.instantiate() as Node2D
	root.add_child(scene)
	current_scene = scene
	for _frame in range(6):
		await physics_frame

	var player := scene.get_node("World/Player") as SeaOverworldPlayer
	var pirates := scene.get("_pirates") as Array
	_expect(pirates.size() == 3, "Sea overworld must spawn exactly three pirate ships.")
	if pirates.is_empty():
		_finish(scene)
		return

	for pirate_value in pirates:
		var spawned_pirate := pirate_value as SeaOverworldPirate
		_expect(spawned_pirate.spawn_origin().distance_to(HARBOR_POSITION) >= 700.0, "Pirates must not spawn inside the South Sea Harbor safety radius.")
		_expect(spawned_pirate.move_speed < player.move_speed, "Pirate movement speed must remain lower than the player ship speed.")
		_expect(is_equal_approx(spawned_pirate.detection_radius, 360.0) and is_equal_approx(spawned_pirate.disengage_radius, 520.0), "Pirate chase must use the approved hysteresis distances.")

	var pirate := pirates[0] as SeaOverworldPirate
	for pirate_index in range(1, pirates.size()):
		(pirates[pirate_index] as SeaOverworldPirate).set_navigation_enabled(false)
	player.global_position = HARBOR_POSITION
	pirate.set_navigation_enabled(true)
	pirate.force_rest_for_test(0.5)
	var rest_position := pirate.global_position
	await physics_frame
	_expect(pirate.behavior_name_for_test() == "rest" and pirate.velocity == Vector2.ZERO, "A resting pirate must stop before its next patrol leg.")
	_expect(pirate.global_position.is_equal_approx(rest_position), "A resting pirate must not drift.")

	pirate.force_wander_for_test(pirate.global_position + Vector2(30, 0), 1.0)
	await physics_frame
	await physics_frame
	_expect(pirate.global_position.distance_to(rest_position) > 0.1, "A wandering pirate must move during its patrol leg.")
	_expect(pirate.global_position.distance_to(pirate.spawn_origin()) <= pirate.patrol_radius + 1.0, "A wandering pirate must remain within its birth patrol radius.")

	player.global_position = pirate.global_position + Vector2(pirate.detection_radius - 40.0, 0)
	await physics_frame
	_expect(pirate.is_chasing(), "A pirate must chase when the player enters its detection radius.")
	_expect(pirate.velocity.length() > 0.0, "A chasing pirate must move continuously toward the player.")
	player.global_position = pirate.global_position + Vector2(pirate.disengage_radius + 80.0, 0)
	await physics_frame
	_expect(not pirate.is_chasing(), "A pirate must stop chasing after the player leaves its disengage radius.")

	pirate.set_navigation_enabled(true)
	pirate.request_battle_for_test()
	for _frame in range(3):
		await process_frame
	var dialogue := scene.get("_event_dialogue") as FieldEventDialogue
	_expect(dialogue.visible and "即将接战" in dialogue.dialogue_label.text, "Touching a pirate must open the battle placeholder dialogue.")
	_expect(not player.controls_enabled, "The player ship must stop while the pirate battle placeholder is open.")
	for pirate_value in scene.get("_pirates") as Array:
		var paused_pirate := pirate_value as SeaOverworldPirate
		_expect(not paused_pirate.is_navigation_enabled_for_test(), "All pirates must pause while the battle placeholder is open.")
	scene.call("_on_event_dialogue_option_selected", &"finish_pirate_placeholder")
	await process_frame
	_expect(not dialogue.visible, "Closing the battle placeholder must restore the sea map.")
	_expect(player.controls_enabled, "Closing the battle placeholder must restore player movement.")
	_expect((scene.get("_pirates") as Array).size() == 2, "The contacted pirate must be removed after the placeholder encounter.")

	_finish(scene)


func _atlas_boundaries_are_clear() -> bool:
	var image := PIRATE_ATLAS.get_image()
	var boundary_x_values := [384, 768, 1152]
	for boundary_x in boundary_x_values:
		for x in range(boundary_x - 8, boundary_x + 8):
			for y in range(image.get_height()):
				if image.get_pixel(x, y).a > 0.02:
					return false
	for y in range(504, 520):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.02:
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(scene: Node) -> void:
	current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	if failures.is_empty():
		print("Sea-overworld pirate chase verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
