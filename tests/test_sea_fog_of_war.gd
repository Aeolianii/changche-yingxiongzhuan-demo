extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const SOUTH_SEA_HARBOR_SPAWN := Vector2(880, 1170)
const FAR_WATERS := Vector2(4380, 2460)
const FOG_CELL_SIZE := 8.0
const WORLD_SCREENSHOT_PATH := "res://.godot/sea_fog_world_preview.png"
const MAP_SCREENSHOT_PATH := "res://.godot/sea_fog_map_preview.png"
const ROUTE_SCREENSHOT_PATH := "res://.godot/sea_fog_route_preview.png"
const STAMP_SCREENSHOT_PATH := "res://.godot/sea_fog_stamp_preview.png"

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
	_expect(not bool(fog.call("is_world_position_revealed", FAR_WATERS)), "Far waters must remain covered by white ink mist on first entry.")
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
	var reveal_half_size := vision_size * 0.5 - Vector2(48.0, 48.0)
	var reveal_corner_radius := float(fog.call("get_reveal_corner_radius_world"))
	var rounded_inside_point := reveal_center + reveal_half_size - Vector2.ONE * reveal_corner_radius * 0.4
	var square_corner_point := reveal_center + reveal_half_size - Vector2(4.0, 4.0)
	_expect(reveal_corner_radius >= 160.0, "Sea vision must use a visibly rounded corner radius instead of a nearly square reveal stamp.")
	_expect(bool(fog.call("is_world_position_revealed", rounded_inside_point)), "A point inside the rounded camera corner must still be explored.")
	_expect(not bool(fog.call("is_world_position_revealed", square_corner_point)), "The sharp tip of the old rectangular camera footprint must remain fogged.")
	_expect(int(fog.call("get_pending_reveal_fade_count_for_test")) == 0, "Newly explored fog cells must not retain staggered per-cell alpha levels that form visible terraces.")
	_expect(float(fog.call("get_explored_ratio")) > initial_ratio, "Sailing into new waters must increase chart completion.")
	_expect(bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.45, 0))), "A point inside the camera-width reveal footprint must be visible.")
	_expect(not bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.49, 0))), "An unexplored direction must retain fog only near the viewport's outer edge.")
	_expect(not bool(fog.call("is_world_position_revealed", reveal_center + Vector2(vision_size.x * 0.65, 0))), "A point outside the camera-width reveal footprint must remain hidden.")
	_expect(bool(fog.call("is_world_position_revealed", SOUTH_SEA_HARBOR_SPAWN)), "Previously revealed harbor water must stay visible after sailing elsewhere.")

	var world_overlay := fog.get_node_or_null("WorldFogOverlay") as Sprite2D
	var player := scene.get_node("World/Player") as CanvasItem
	_expect(world_overlay != null and world_overlay.texture != null, "FogOfWar must render a world-space exploration mask.")
	var fog_stamp_texture := fog.call("get_fog_stamp_texture") as Texture2D
	var map_fog_stamp_texture := fog.call("get_map_fog_stamp_texture") as Texture2D
	var visual_fog_grid_size := fog.call("get_visual_fog_grid_size") as Vector2i
	var fog_stamp_stats := fog.call("get_fog_stamp_stats_for_test") as Dictionary
	_expect(fog_stamp_texture != null, "Sea exploration must precompose the naval white-ink stamps into a stable world-space texture.")
	_expect(map_fog_stamp_texture != null and map_fog_stamp_texture.get_size() == Vector2(870, 510), "Full sea map must precompose naval fog at its native 870x510 canvas size.")
	_expect(is_equal_approx(float(fog.call("get_visual_fog_cell_world_size")), 26.0), "Sea fog presentation must use the exact naval-battle 26-pixel cell size without changing the 8-pixel reveal grid.")
	_expect(visual_fog_grid_size.x > 150 and visual_fog_grid_size.y > 90, "The naval fog grid must provide many battle-scale placements instead of a few oversized cloud blocks.")
	_expect(int(fog_stamp_stats.get("transparent_count", 0)) > 0, "Precomposed fog must retain small transparent holes that reveal the sea beneath.")
	_expect(int(fog_stamp_stats.get("light_count", 0)) > 0 and int(fog_stamp_stats.get("dense_count", 0)) > 0, "Precomposed fog must contain both light and dense overlap regions.")
	_expect(float(fog_stamp_stats.get("maximum_alpha", 0.0)) > 0.45, "Overlapping naval fog stamps must form visibly denser regions.")
	if DisplayServer.get_name() != "headless":
		var stamp_screenshot_error := map_fog_stamp_texture.get_image().save_png(STAMP_SCREENSHOT_PATH)
		_expect(stamp_screenshot_error == OK, "The shared naval fog-stamp field preview could not be saved.")
	var world_concealment_texture: Texture2D
	if world_overlay != null:
		_expect(world_overlay.z_index < player.z_index, "World fog must render below the player ship.")
		var world_fog_material := world_overlay.material as ShaderMaterial
		_expect(world_fog_material != null and world_fog_material.shader.resource_path.ends_with("sea_world_fog_edge.gdshader"), "World fog must soften the narrow unexplored edge instead of drawing a hard black line.")
		_expect(float(world_fog_material.get_shader_parameter("feather_texels")) >= 3.0, "World edge fog must use one continuous distance-field feather instead of stacked blur layers.")
		_expect(float(world_fog_material.get_shader_parameter("edge_warp_texels")) > 0.0, "World edge fog must retain a restrained stable ink contour warp.")
		_expect(float(world_fog_material.get_shader_parameter("alpha_dither")) > 0.0, "World edge fog must dither intermediate alpha levels to break up visible gradient bands.")
		_expect("signed_distance" in world_fog_material.shader.code and "DISTANCE_SEARCH_RADIUS" in world_fog_material.shader.code, "World edge fog must derive one signed-distance alpha instead of stacking multiple translucent samples.")
		_expect("alpha_sum" not in world_fog_material.shader.code and "weight_sum" not in world_fog_material.shader.code, "World edge fog must not accumulate weighted alpha layers.")
		var world_mist_texture := world_fog_material.get_shader_parameter("mist_texture") as Texture2D
		world_concealment_texture = world_fog_material.get_shader_parameter("concealment_texture") as Texture2D
		_expect(world_mist_texture == fog_stamp_texture, "World exploration must sample the shared world-space naval fog-stamp texture.")
		_expect(world_concealment_texture != null and world_concealment_texture.resource_path.ends_with("sea_concealment_ink_pixel_v1.png"), "Unexplored world terrain must use the refined high-resolution ink-sea texture.")
		_expect((world_fog_material.get_shader_parameter("concealment_tint") as Color).is_equal_approx(Color(0.05, 0.56, 0.68, 1.0)), "The concealment sea must retain the established overworld blue at the exploration boundary.")
		_expect("layered_mist" not in world_fog_material.shader.code and "fog_base_alpha" not in world_fog_material.shader.code, "World fog must preserve stamp holes instead of filling them with global layered mist.")
		_expect("texture(mist_texture, UV)" in world_fog_material.shader.code, "World fog shader must sample each precomposed naval stamp at its stable world position.")
		_expect("mix(concealed_sea, mist.rgb, mist.a)" in world_fog_material.shader.code and "fog_opacity" not in world_fog_material.shader.code, "World fog must use the naval stamp's baked battle tint and alpha without another global fog multiplier.")
		_expect("concealed_sea" in world_fog_material.shader.code and "COLOR = vec4(concealed_fog, softened_alpha)" in world_fog_material.shader.code, "World fog holes must reveal an opaque sea concealment layer instead of unknown islands beneath.")
		_expect("texture(concealment_texture, UV)" in world_fog_material.shader.code and "fract(UV * concealment_uv_scale)" not in world_fog_material.shader.code, "The refined concealment sea must cover the world once without repeated tiles.")

	var hud := root.get_node("ExplorationUI/HUD") as Control
	var map_button := hud.get_node("SeaMapStatus/MapButton") as Button
	map_button.pressed.emit()
	await process_frame
	var map_screen := hud.get_node("SeaMapScreen") as Control
	var map_fog := map_screen.get_node_or_null("MapPanel/MapViewport/FogLayer") as TextureRect
	_expect(map_fog != null and map_fog.texture != null, "Full sea map must display the shared fog texture.")
	_expect(map_fog.position.is_equal_approx(Vector2.ZERO) and map_fog.size.is_equal_approx(Vector2(870, 510)), "Full sea-map content and fog must fill the entire inner frame without top or bottom letterboxing.")
	var map_fog_material := map_fog.material as ShaderMaterial
	_expect(map_fog_material != null and map_fog_material.shader.resource_path.ends_with("sea_map_fog_soft_edge.gdshader"), "Full sea map alone must soften and round the shared fog edge.")
	_expect(float(map_fog_material.get_shader_parameter("edge_warp_texels")) >= 4.0, "Full sea map fog must visibly warp straight exploration edges.")
	_expect(float(map_fog_material.get_shader_parameter("edge_irregularity")) >= 0.3, "Full sea map fog must vary its edge threshold with stable ink noise.")
	var map_mist_texture := map_fog_material.get_shader_parameter("mist_texture") as Texture2D
	var map_concealment_texture := map_fog_material.get_shader_parameter("concealment_texture") as Texture2D
	_expect(map_mist_texture == map_fog_stamp_texture and map_mist_texture != fog_stamp_texture, "Full sea map must use its native-pixel naval fog field instead of shrinking the world field into a solid mass.")
	_expect(map_concealment_texture == world_concealment_texture, "Full sea map and world view must reuse the same ink-sea concealment texture.")
	_expect((map_fog_material.get_shader_parameter("concealment_tint") as Color).is_equal_approx(Color(0.05, 0.56, 0.68, 1.0)), "Full sea map must use the same established overworld-blue concealment base.")
	_expect("layered_mist" not in map_fog_material.shader.code and "fog_base_alpha" not in map_fog_material.shader.code, "Full sea-map fog must not restore the uniform white base that erased texture depth.")
	_expect("texture(mist_texture, UV)" in map_fog_material.shader.code, "Full sea-map shader must sample the precomposed coarse-grid naval stamps directly.")
	_expect("concealed_sea" in map_fog_material.shader.code and "COLOR = vec4(concealed_fog, softened_alpha)" in map_fog_material.shader.code, "Full sea-map fog holes must reveal only the sea concealment layer until exploration clears the mask.")
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
