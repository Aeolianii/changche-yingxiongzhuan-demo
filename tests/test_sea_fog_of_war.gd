extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const SOUTH_SEA_HARBOR_SPAWN := Vector2(760, 1130)
const FAR_WATERS := Vector2(4380, 2460)
const FOG_CELL_SIZE := 16.0
const WORLD_SCREENSHOT_PATH := "res://.godot/sea_fog_world_preview.png"
const MAP_SCREENSHOT_PATH := "res://.godot/sea_fog_map_preview.png"

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
	_expect_polygon_revealed(fog, scene.get_node("World/WorldCollision/NorthwestCoast") as CollisionPolygon2D, scene.get_node("World") as Node2D)
	_expect(not bool(fog.call("is_world_position_revealed", FAR_WATERS)), "Far waters must remain black on first entry.")
	var initial_ratio := float(fog.call("get_explored_ratio"))
	_expect(initial_ratio > 0.0 and initial_ratio < 0.35, "Initial land and harbor vision must still leave most of the chart hidden.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var world_screenshot_error := root.get_texture().get_image().save_png(WORLD_SCREENSHOT_PATH)
		_expect(world_screenshot_error == OK, "Initial world-fog preview screenshot could not be saved.")

	var vision_size: Vector2 = fog.call("get_vision_world_size")
	_expect(vision_size.is_equal_approx(Vector2(1344, 896)), "Fog reveal size must match the current Camera2D world viewport.")
	for corner_sign: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner_probe: Vector2 = SOUTH_SEA_HARBOR_SPAWN + corner_sign * vision_size * 0.49
		_expect(bool(fog.call("is_world_position_revealed", corner_probe)), "Every corner inside the player's initial camera viewport must be revealed.")
	var camera := scene.get_node("World/Player/Camera2D") as Camera2D
	var camera_center := (scene.get_node("World") as Node2D).to_local(camera.get_screen_center_position())
	for corner_sign: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner_probe: Vector2 = camera_center + corner_sign * vision_size * 0.5
		_expect(bool(fog.call("is_world_position_revealed", corner_probe)), "The smoothed Camera2D's actual visible corners must remain revealed.")
	var reveal_center := Vector2(2500, 1350)
	fog.call("reveal_at", reveal_center)
	_expect(float(fog.call("get_explored_ratio")) > initial_ratio, "Sailing into new waters must increase chart completion.")
	_expect(bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.45, 0))), "A point inside the camera-width reveal footprint must be visible.")
	_expect(not bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.65, 0))), "A point outside the camera-width reveal footprint must remain hidden.")
	_expect(bool(fog.call("is_world_position_revealed", SOUTH_SEA_HARBOR_SPAWN)), "Previously revealed harbor water must stay visible after sailing elsewhere.")

	var world_overlay := fog.get_node_or_null("WorldFogOverlay") as Sprite2D
	var player := scene.get_node("World/Player") as CanvasItem
	_expect(world_overlay != null and world_overlay.texture != null, "FogOfWar must render a world-space black overlay texture.")
	if world_overlay != null:
		_expect(world_overlay.z_index < player.z_index, "World fog must render below the player ship.")
		_expect(world_overlay.material == null, "World fog must keep the raw rectangular reveal so the full camera viewport stays bright.")

	var hud := scene.get_node("UI/ExplorationHUD") as Control
	var map_button := hud.get_node("SeaMapStatus/MapButton") as Button
	map_button.pressed.emit()
	await process_frame
	var map_screen := hud.get_node("SeaMapScreen") as Control
	var map_fog := map_screen.get_node_or_null("MapPanel/MapViewport/FogLayer") as TextureRect
	_expect(map_fog != null and map_fog.texture != null, "Full sea map must display the shared fog texture.")
	var map_fog_material := map_fog.material as ShaderMaterial
	_expect(map_fog_material != null and map_fog_material.shader.resource_path.ends_with("sea_map_fog_soft_edge.gdshader"), "Full sea map alone must soften and round the shared fog edge.")
	_expect(float(map_fog_material.get_shader_parameter("edge_warp_texels")) >= 4.0, "Full sea map fog must visibly warp straight exploration edges.")
	_expect(float(map_fog_material.get_shader_parameter("edge_irregularity")) >= 0.3, "Full sea map fog must vary its edge threshold with stable ink noise.")
	var close_button := map_screen.get_node("MapPanel/CloseButton") as Button
	var close_button_style := close_button.get_theme_stylebox("normal") as StyleBoxTexture
	_expect(close_button.text == "返回", "Sea-map brush button must display the exact Return label.")
	_expect(close_button.size.is_equal_approx(Vector2(160, 64)), "Sea-map brush button must provide a larger text-safe click area.")
	_expect(close_button_style != null and close_button_style.texture.resource_path.ends_with("sea_map_return_brush_v1.png"), "Sea-map Return button must use the generated ink-brush texture instead of a rectangular panel.")

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
	if DisplayServer.get_name() != "headless":
		await process_frame
		var map_screenshot_error := root.get_texture().get_image().save_png(MAP_SCREENSHOT_PATH)
		_expect(map_screenshot_error == OK, "Full-chart fog preview screenshot could not be saved.")
	close_button.pressed.emit()
	await process_frame
	_expect(not map_screen.visible, "Pressing the generated sea-map Return button must restore exploration.")

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


func _expect_polygon_revealed(fog: Node, polygon_node: CollisionPolygon2D, world: Node2D) -> void:
	var world_polygon := PackedVector2Array()
	for local_point in polygon_node.polygon:
		world_polygon.append(world.to_local(polygon_node.to_global(local_point)))
	var bounds := Rect2(world_polygon[0], Vector2.ZERO)
	for world_point in world_polygon:
		bounds = bounds.expand(world_point)
	var sampled_cells := 0
	var first_hidden_cell := Vector2.ZERO
	for cell_y in range(floori(bounds.position.y / FOG_CELL_SIZE), ceili(bounds.end.y / FOG_CELL_SIZE)):
		for cell_x in range(floori(bounds.position.x / FOG_CELL_SIZE), ceili(bounds.end.x / FOG_CELL_SIZE)):
			var cell_center := Vector2(cell_x + 0.5, cell_y + 0.5) * FOG_CELL_SIZE
			if not Geometry2D.is_point_in_polygon(cell_center, world_polygon):
				continue
			sampled_cells += 1
			if first_hidden_cell == Vector2.ZERO and not bool(fog.call("is_world_position_revealed", cell_center)):
				first_hidden_cell = cell_center
	_expect(sampled_cells > 0, "NorthwestCoast must provide initial-land fog samples.")
	_expect(first_hidden_cell == Vector2.ZERO, "Every fog cell inside NorthwestCoast must be initially revealed; first hidden cell: %s" % first_hidden_cell)


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
