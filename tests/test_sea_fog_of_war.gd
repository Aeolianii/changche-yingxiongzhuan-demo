extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const SOUTH_SEA_HARBOR_SPAWN := Vector2(880, 1170)
const FAR_WATERS := Vector2(4380, 2460)
const FOG_CELL_SIZE := 8.0
const WORLD_SCREENSHOT_PATH := "res://.godot/sea_fog_world_preview.png"
const MAP_SCREENSHOT_PATH := "res://.godot/sea_fog_map_preview.png"
const ROUTE_SCREENSHOT_PATH := "res://.godot/sea_fog_route_preview.png"

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
	_expect(is_equal_approx(float(fog.call("get_view_edge_fog_inset")), 48.0), "World exploration must reserve only a narrow 48-pixel fog strip at unexplored viewport edges.")
	var reveal_center := Vector2(2500, 1350)
	fog.call("reveal_at", reveal_center)
	_expect(int(fog.call("get_pending_reveal_fade_count_for_test")) == 0, "Newly explored fog cells must not retain staggered per-cell alpha levels that form visible terraces.")
	_expect(float(fog.call("get_explored_ratio")) > initial_ratio, "Sailing into new waters must increase chart completion.")
	_expect(bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.45, 0))), "A point inside the camera-width reveal footprint must be visible.")
	_expect(not bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.49, 0))), "An unexplored direction must retain fog only near the viewport's outer edge.")
	_expect(not bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.65, 0))), "A point outside the camera-width reveal footprint must remain hidden.")
	_expect(bool(fog.call("is_world_position_revealed", SOUTH_SEA_HARBOR_SPAWN)), "Previously revealed harbor water must stay visible after sailing elsewhere.")

	var world_overlay := fog.get_node_or_null("WorldFogOverlay") as Sprite2D
	var player := scene.get_node("World/Player") as CanvasItem
	_expect(world_overlay != null and world_overlay.texture != null, "FogOfWar must render a world-space black overlay texture.")
	if world_overlay != null:
		_expect(world_overlay.z_index < player.z_index, "World fog must render below the player ship.")
		var world_fog_material := world_overlay.material as ShaderMaterial
		_expect(world_fog_material != null and world_fog_material.shader.resource_path.ends_with("sea_world_fog_edge.gdshader"), "World fog must soften the narrow unexplored edge instead of drawing a hard black line.")
		_expect(float(world_fog_material.get_shader_parameter("blur_texels")) >= 2.0, "World edge fog must use the wider soft transition.")
		_expect(float(world_fog_material.get_shader_parameter("edge_warp_texels")) >= 2.5, "World edge fog must warp the 8-pixel reveal grid strongly enough to hide its rectangular contour.")
		_expect(float(world_fog_material.get_shader_parameter("alpha_dither")) > 0.0, "World edge fog must dither intermediate alpha levels to break up visible gradient bands.")
		_expect("weight_x" in world_fog_material.shader.code and "GAUSSIAN_RADIUS" in world_fog_material.shader.code, "World edge fog must use a continuous 5x5 Gaussian kernel instead of nine fixed alpha bands.")
		_expect(float(world_fog_material.get_shader_parameter("fog_opacity")) <= 0.75, "World edge fog must stay gently translucent rather than covering the view with solid black.")

	var hud := root.get_node("ExplorationUI/HUD") as Control
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
	if DisplayServer.get_name() != "headless":
		for route_step in range(36):
			var route_position := Vector2(1500.0 + route_step * 52.0, 1560.0 + sin(route_step * 0.47) * 22.0)
			fog.call("reveal_at", route_position, true)
		var sea_player := scene.get_node("World/Player") as CharacterBody2D
		var sea_camera := scene.get_node("World/Player/Camera2D") as Camera2D
		sea_player.set_physics_process(false)
		sea_player.global_position = Vector2(2400, 1560)
		sea_camera.position_smoothing_enabled = false
		sea_camera.reset_smoothing()
		await process_frame
		await RenderingServer.frame_post_draw
		var route_screenshot_error := root.get_texture().get_image().save_png(ROUTE_SCREENSHOT_PATH)
		_expect(route_screenshot_error == OK, "Continuous-route fog preview screenshot could not be saved.")

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
	for cell_y in range(maxi(0, floori(bounds.position.y / FOG_CELL_SIZE)), ceili(bounds.end.y / FOG_CELL_SIZE)):
		for cell_x in range(maxi(0, floori(bounds.position.x / FOG_CELL_SIZE)), ceili(bounds.end.x / FOG_CELL_SIZE)):
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
