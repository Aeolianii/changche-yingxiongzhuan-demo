extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const SOUTH_SEA_HARBOR_SPAWN := Vector2(760, 1130)
const FAR_WATERS := Vector2(4380, 2460)

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null and game_state.has_method("reset_runtime_world_state"):
		game_state.call("reset_runtime_world_state")

	var scene := SEA_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var fog := scene.get_node_or_null("World/FogOfWar")
	_expect(fog != null, "Sea overworld must create a FogOfWar node at runtime.")
	if fog == null:
		_finish()
		return

	_expect(fog.has_method("is_world_position_revealed"), "FogOfWar must expose world-position reveal queries.")
	_expect(bool(fog.call("is_world_position_revealed", SOUTH_SEA_HARBOR_SPAWN)), "South Sea Harbor must be revealed on first entry.")
	_expect(not bool(fog.call("is_world_position_revealed", FAR_WATERS)), "Far waters must remain black on first entry.")

	var vision_size: Vector2 = fog.call("get_vision_world_size")
	_expect(vision_size.is_equal_approx(Vector2(1344, 896)), "Fog reveal size must match the current Camera2D world viewport.")
	var reveal_center := Vector2(2500, 1350)
	fog.call("reveal_at", reveal_center)
	_expect(bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.45, 0))), "A point inside the camera-width reveal footprint must be visible.")
	_expect(not bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.65, 0))), "A point outside the camera-width reveal footprint must remain hidden.")
	_expect(bool(fog.call("is_world_position_revealed", SOUTH_SEA_HARBOR_SPAWN)), "Previously revealed harbor water must stay visible after sailing elsewhere.")

	var world_overlay := fog.get_node_or_null("WorldFogOverlay") as Sprite2D
	var player := scene.get_node("World/Player") as CanvasItem
	_expect(world_overlay != null and world_overlay.texture != null, "FogOfWar must render a world-space black overlay texture.")
	if world_overlay != null:
		_expect(world_overlay.z_index < player.z_index, "World fog must render below the player ship.")

	var hud := scene.get_node("UI/ExplorationHUD") as Control
	var map_button := hud.get_node("SeaMapStatus/MapButton") as Button
	map_button.pressed.emit()
	await process_frame
	var map_screen := hud.get_node("SeaMapScreen") as Control
	var map_fog := map_screen.get_node_or_null("MapPanel/MapViewport/FogLayer") as TextureRect
	_expect(map_fog != null and map_fog.texture != null, "Full sea map must display the shared fog texture.")

	var south_harbor_label: Label
	var pirate_camp_label: Label
	for location_label in map_screen.get_node("MapPanel/MapViewport/MapLocationLayer").get_children():
		var label := location_label as Label
		if "南海军港" in label.text:
			south_harbor_label = label
		elif "倭寇营地" in label.text:
			pirate_camp_label = label
	_expect(south_harbor_label != null and south_harbor_label.visible, "Revealed South Sea Harbor name must appear on the full chart.")
	_expect(pirate_camp_label != null and not pirate_camp_label.visible, "Unexplored pirate-camp name must stay hidden.")
	_expect(map_screen.get_node("MapPanel/MapViewport/PlayerMarker").visible, "Current-position marker must remain visible above fog.")

	var revealed_probe := reveal_center
	current_scene = null
	scene.queue_free()
	await process_frame
	var restored_scene := SEA_SCENE.instantiate()
	root.add_child(restored_scene)
	current_scene = restored_scene
	await process_frame
	await physics_frame
	var restored_fog := restored_scene.get_node_or_null("World/FogOfWar")
	_expect(restored_fog != null and bool(restored_fog.call("is_world_position_revealed", revealed_probe)), "Re-entering the sea scene must restore the previously revealed sailing route.")
	if game_state != null and game_state.has_method("reset_runtime_world_state"):
		game_state.call("reset_runtime_world_state")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if current_scene != null:
		current_scene.queue_free()
	if failures.is_empty():
		print("Sea fog-of-war runtime verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
