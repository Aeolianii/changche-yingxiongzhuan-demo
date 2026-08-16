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
	var first_scene := SEA_SCENE.instantiate() as Node2D
	root.add_child(first_scene)
	current_scene = first_scene
	for _frame in range(6):
		await physics_frame
	var first_origins: Array[Vector2] = []
	for pirate_value in first_scene.get("_pirates") as Array:
		first_origins.append((pirate_value as SeaOverworldPirate).spawn_origin())
	_expect(first_origins.size() == 5, "Every sea-map entry must create five pirate ships.")
	current_scene = null
	first_scene.queue_free()
	await process_frame

	var scene := SEA_SCENE.instantiate() as Node2D
	root.add_child(scene)
	current_scene = scene
	for _frame in range(6):
		await physics_frame

	var player := scene.get_node("World/Player") as SeaOverworldPlayer
	var pirates := scene.get("_pirates") as Array
	for marker in scene.get_node("World/WorldMarkers").find_children("*", "Area2D", true, false):
		(marker as Area2D).monitoring = false
	_expect(pirates.size() == 5, "Sea overworld must spawn exactly five pirate ships.")
	var distribution_changed := first_origins.size() != pirates.size()
	if not distribution_changed:
		for pirate_index in range(pirates.size()):
			if not first_origins[pirate_index].is_equal_approx((pirates[pirate_index] as SeaOverworldPirate).spawn_origin()):
				distribution_changed = true
				break
	_expect(distribution_changed, "Re-entering the sea map must create a new random pirate distribution.")
	if pirates.is_empty():
		_finish(scene)
		return

	for pirate_value in pirates:
		var spawned_pirate := pirate_value as SeaOverworldPirate
		_expect(spawned_pirate.spawn_origin().distance_to(HARBOR_POSITION) >= 1100.0, "Pirates must spawn well outside the expanded South Sea Harbor safety radius.")
		_expect(is_equal_approx(spawned_pirate.move_speed, 168.0), "Pirate movement speed must be reduced by 20 percent from 210 to 168.")
		_expect(is_equal_approx(spawned_pirate.detection_radius, 360.0) and is_equal_approx(spawned_pirate.disengage_radius, 520.0), "Pirate chase must use the approved hysteresis distances.")
		_expect(is_equal_approx(spawned_pirate.pursuit_leash_radius, 720.0), "Pirate chase must use the approved birth-point leash radius.")
	for first_index in range(pirates.size()):
		for second_index in range(first_index + 1, pirates.size()):
			var first_origin := (pirates[first_index] as SeaOverworldPirate).spawn_origin()
			var second_origin := (pirates[second_index] as SeaOverworldPirate).spawn_origin()
			_expect(first_origin.distance_to(second_origin) >= 460.0, "Pirates must spawn in separated parts of the sea map.")
	var player_ship_scale := player.ship_sprite.scale
	var pirate_ship_scale := (pirates[0] as SeaOverworldPirate).ship_sprite.scale
	_expect(pirate_ship_scale.is_equal_approx(player_ship_scale * 0.95), "Pirate ship visuals must be five percent smaller than the player ship.")

	var behavior_probe := _find_open_water_behavior_probe(scene, pirates)
	var pirate := behavior_probe.get("pirate") as SeaOverworldPirate
	var probe_direction := behavior_probe.get("direction", Vector2.RIGHT) as Vector2
	_expect(pirate != null, "At least one spawned pirate must have an open-water lane for chase and return verification.")
	if pirate == null:
		_finish(scene)
		return
	for pirate_value in pirates:
		var other_pirate := pirate_value as SeaOverworldPirate
		if other_pirate != pirate:
			other_pirate.set_navigation_enabled(false)
	player.set_physics_process(false)
	player.global_position = HARBOR_POSITION
	pirate.set_navigation_enabled(true)
	pirate.force_rest_for_test(0.5)
	var rest_position := pirate.global_position
	await physics_frame
	_expect(pirate.behavior_name_for_test() == "rest" and pirate.velocity == Vector2.ZERO, "A resting pirate must stop before its next patrol leg.")
	_expect(pirate.global_position.is_equal_approx(rest_position), "A resting pirate must not drift.")

	pirate.force_wander_for_test(pirate.global_position + probe_direction * 30.0, 1.0)
	await physics_frame
	await physics_frame
	_expect(pirate.global_position.distance_to(rest_position) > 0.1, "A wandering pirate must move during its patrol leg.")
	_expect(pirate.global_position.distance_to(pirate.spawn_origin()) <= pirate.patrol_radius + 1.0, "A wandering pirate must remain within its birth patrol radius.")

	pirate.force_chase_for_test()
	_expect(pirate.is_chasing(), "A pirate must chase when the player enters its detection radius.")
	player.global_position = pirate.global_position + probe_direction * (pirate.detection_radius - 40.0)
	await physics_frame
	_expect(pirate.velocity.length() > 0.0, "A chasing pirate must move continuously toward the player.")
	pirate.global_position = pirate.spawn_origin() + probe_direction * 40.0
	player.global_position = pirate.global_position + probe_direction * (pirate.disengage_radius + 80.0)
	await physics_frame
	_expect(pirate.behavior_name_for_test() == "return", "A pirate must return home after the player leaves its disengage radius.")
	var distance_before_return := pirate.global_position.distance_to(pirate.spawn_origin())
	for _frame in range(3):
		await physics_frame
	_expect(pirate.global_position.distance_to(pirate.spawn_origin()) < distance_before_return, "A returning pirate must move toward its birth point.")

	pirate.global_position = pirate.spawn_origin() + probe_direction * 60.0
	pirate.pursuit_leash_radius = 40.0
	player.global_position = pirate.global_position + probe_direction * 200.0
	pirate.force_chase_for_test()
	await physics_frame
	_expect(pirate.behavior_name_for_test() == "return", "A pirate must abandon pursuit after crossing its birth-point leash.")
	player.global_position = pirate.global_position + probe_direction * 200.0
	await physics_frame
	_expect(pirate.behavior_name_for_test() == "return", "A returning pirate must ignore nearby players until it reaches home.")
	pirate.pursuit_leash_radius = 720.0
	pirate.global_position = pirate.spawn_origin() + probe_direction * 8.0
	await physics_frame
	_expect(pirate.behavior_name_for_test() == "wander", "A pirate must resume patrol after returning to its birth point.")

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
	_expect((scene.get("_pirates") as Array).size() == 4, "The contacted pirate must be removed after the placeholder encounter.")

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


func _find_open_water_behavior_probe(scene: Node, pirates: Array) -> Dictionary:
	var directions := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for pirate_value in pirates:
		var candidate := pirate_value as SeaOverworldPirate
		for direction in directions:
			var lane_is_clear := true
			for distance in [30.0, 40.0, 60.0, 80.0]:
				if not bool(scene.call("_is_open_water_for_pirate", candidate.spawn_origin() + direction * distance)):
					lane_is_clear = false
					break
			if lane_is_clear:
				return {"pirate": candidate, "direction": direction}
	return {}


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
