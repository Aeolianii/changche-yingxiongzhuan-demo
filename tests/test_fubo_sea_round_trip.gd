extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")
const SEA_ENTRY_SCREENSHOT := "res://.godot/fubo_sea_entry_preview.png"
const ISLAND_RETURN_SCREENSHOT := "res://.godot/fubo_island_return_preview.png"

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.remove_meta(TRAVEL.RETURN_REQUEST_META)
	root.remove_meta(TRAVEL.RETURN_CONTEXT_META)
	root.set_meta("sea_overworld_lunar_day", 0.0)

	var sea := SEA_SCENE.instantiate()
	root.add_child(sea)
	current_scene = sea
	await process_frame
	await physics_frame

	var ship := sea.get_node("World/Player") as CharacterBody2D
	var fubo := _find_location("伏波古岭")
	_check(fubo != null, "Fubo sea location must exist for the round trip.")
	if fubo == null:
		_finish()
		return
	ship.global_position = _find_clear_entry_point(fubo)
	ship.call("restore_facing_index", 2)
	sea.set("_exploration_stage", 4)
	sea.set("_lunar_day", 8.5)
	sea.set("_crate_event_resolved", true)
	sea.set("_tea_merchant_event_resolved", true)
	sea.set("_salt_merchant_event_resolved", true)
	var fog_probe := Vector2(3000, 1500)
	var sea_fog := sea.get_node("World/FogOfWar")
	sea_fog.call("reveal_at", fog_probe)
	root.set_meta("sea_overworld_lunar_day", 8.5)
	var expected_position := ship.global_position
	for _frame in range(3):
		await physics_frame
	_check((sea.get_node("UI/Root/InteractionPrompt") as Control).visible, "Fubo entry prompt must appear on reachable water.")
	await _capture_if_visible(SEA_ENTRY_SCREENSHOT, "Fubo sea entry screenshot could not be saved.")

	var enter_event := InputEventKey.new()
	enter_event.physical_keycode = KEY_E
	enter_event.pressed = true
	sea.get_viewport().push_input(enter_event)
	_check(await _wait_for_scene(TRAVEL.FUBO_SCENE_PATH), "Pressing E at Fubo must load the real island scene.")
	if current_scene == null or current_scene.scene_file_path != TRAVEL.FUBO_SCENE_PATH:
		_finish()
		return

	var island := current_scene
	var island_player := island.get_node("World/WorldObjects/Player") as CharacterBody2D
	island_player.global_position = Vector2(235, 835)
	for _frame in range(3):
		await physics_frame
	var return_prompt := island.get_node("Interface/HUD/PromptPanel") as Control
	var return_label := island.get_node("Interface/HUD/PromptPanel/Prompt") as Label
	_check(return_prompt.visible and "返回海图" in return_label.text, "Dock return prompt must appear before leaving the island.")
	await _capture_if_visible(ISLAND_RETURN_SCREENSHOT, "Fubo dock return screenshot could not be saved.")

	var interact_event := InputEventAction.new()
	interact_event.action = &"interact"
	interact_event.pressed = true
	island.get_viewport().push_input(interact_event)
	_check(await _wait_for_scene(TRAVEL.SEA_SCENE_PATH), "Confirming at the dock must return to the sea map without quitting.")
	if current_scene != null and current_scene.scene_file_path == TRAVEL.SEA_SCENE_PATH:
		var returned_sea := current_scene
		var returned_ship := returned_sea.get_node("World/Player") as CharacterBody2D
		_check(returned_ship.global_position.is_equal_approx(expected_position), "Sea return must restore the pre-landing ship position.")
		_check(int(returned_ship.call("save_facing_index")) == 2, "Sea return must restore the pre-landing facing.")
		_check(int(returned_sea.get("_exploration_stage")) == 4, "Sea return must restore exploration progress.")
		_check(is_equal_approx(float(returned_sea.get("_lunar_day")), 8.5), "Sea return must restore lunar progress.")
		_check(returned_sea.get_node_or_null("World/WorldMarkers/DriftEvent") == null, "Sea return must preserve the resolved drifting-crate state.")
		_check(returned_sea.get_node_or_null("World/WorldMarkers/ShipTrigger0") == null, "Sea return must preserve the resolved tea-merchant state.")
		_check(returned_sea.get_node_or_null("World/WorldMarkers/SaltMerchantShip") == null, "Sea return must preserve the resolved salt-merchant state.")
		var returned_fog := returned_sea.get_node("World/FogOfWar")
		_check(bool(returned_fog.call("is_world_position_revealed", fog_probe)), "Sea return must preserve the explored fog route.")
	_check(not root.has_meta(TRAVEL.RETURN_REQUEST_META) and not root.has_meta(TRAVEL.RETURN_CONTEXT_META), "Round-trip metadata must be consumed after returning.")
	_finish()


func _wait_for_scene(scene_path: String, timeout_seconds := 4.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.scene_file_path == scene_path:
			await process_frame
			await physics_frame
			return true
		await process_frame
	return false


func _find_location(location_name: String) -> Area2D:
	for location_node in get_nodes_in_group("sea_location"):
		if str(location_node.get_meta("location_name", "")) == location_name:
			return location_node as Area2D
	return null


func _find_clear_entry_point(area: Area2D) -> Vector2:
	var shape_node := area.get_node("EntryTriggerShape") as CollisionShape2D
	var offsets: Array[Vector2] = [shape_node.position]
	if shape_node.shape is RectangleShape2D:
		var size := (shape_node.shape as RectangleShape2D).size
		for x_factor in [-0.4, 0.0, 0.4]:
			for y_factor in [-0.4, 0.0, 0.4]:
				offsets.append(shape_node.position + Vector2(size.x * x_factor, size.y * y_factor))
	for offset in offsets:
		var point := area.global_position + offset
		if _is_water_clear(point):
			return point
	return area.global_position + shape_node.position


func _is_water_clear(point: Vector2) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = 19.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return root.world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


func _capture_if_visible(path: String, failure_message: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(path) == OK, failure_message)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Fubo sea round-trip verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
