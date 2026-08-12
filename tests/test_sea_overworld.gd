extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const FUBO_TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")
const SCREENSHOT_PATH := "res://.godot/sea_overworld_preview.png"
const MOVEMENT_SCREENSHOT_PATH := "res://.godot/sea_overworld_movement_preview.png"
const STOPPED_SCREENSHOT_PATH := "res://.godot/sea_overworld_stopped_preview.png"
const QUEST_SCREENSHOT_PATH := "res://.godot/sea_overworld_quest_preview.png"
const MAP_SCREENSHOT_PATH := "res://.godot/sea_overworld_map_preview.png"
const FULL_MOON_SCREENSHOT_PATH := "res://.godot/sea_overworld_lunar_full_preview.png"
const B_ZONE_SCREENSHOT_PATH := "res://.godot/sea_overworld_b_zone_preview.png"
const C_ZONE_SCREENSHOT_PATH := "res://.godot/sea_overworld_c_zone_preview.png"
const D_ZONE_SCREENSHOT_PATH := "res://.godot/sea_overworld_d_zone_preview.png"
const CENTRAL_SEAM_SCREENSHOT_PATH := "res://.godot/sea_overworld_central_seam_preview.png"
const EXPECTED_LOCATIONS := {
	"南海军港": Vector2(1080, 650),
	"川山渔村": Vector2(480, 1040),
	"东湾水寨": Vector2(2040, 520),
	"青屿秘境": Vector2(2380, 540),
	"沧门礁堡": Vector2(2780, 1080),
	"月环商港": Vector2(3650, 360),
	"雾岚群岛": Vector2(3070, 850),
	"伏波古岭": Vector2(4260, 780),
	"珊湾渔链": Vector2(3670, 1150),
	"澄海灯岛": Vector2(480, 1680),
	"龙门海寨": Vector2(860, 2260),
	"白沙渔岛": Vector2(1460, 2460),
	"玄潮古屿": Vector2(2100, 2240),
	"红湾卫所": Vector2(2980, 1760),
	"南澳商港": Vector2(4380, 2460),
}
const A_LOCATIONS := ["南海军港", "川山渔村", "东湾水寨", "青屿秘境"]
const B_LOCATIONS := ["沧门礁堡", "月环商港", "雾岚群岛", "伏波古岭", "珊湾渔链"]
const C_LOCATIONS := ["澄海灯岛", "龙门海寨", "白沙渔岛", "玄潮古屿"]
const D_LOCATIONS := ["红湾卫所", "南澳商港"]
const NAVIGATION_ROUTES := {
	"A_TO_B": [Vector2(1500, 800), Vector2(2100, 800), Vector2(2388, 800), Vector2(2700, 800), Vector2(3050, 800)],
	"A_TO_C": [Vector2(1700, 1050), Vector2(1700, 1292), Vector2(1700, 1500), Vector2(1550, 1750), Vector2(1400, 1950)],
	"B_TO_D": [Vector2(4200, 1140), Vector2(4200, 1292), Vector2(4200, 1600), Vector2(3900, 1750)],
	"C_TO_D": [Vector2(1900, 1400), Vector2(2388, 1400), Vector2(2850, 1400), Vector2(3150, 1500)],
	"FORTRESS_ABOVE": [Vector2(2200, 800), Vector2(3050, 800)],
	"FORTRESS_BELOW": [Vector2(2200, 1450), Vector2(3400, 1450)],
	"FORTRESS_LEFT": [Vector2(2250, 800), Vector2(2250, 1450)],
	"FORTRESS_RIGHT": [Vector2(3125, 800), Vector2(3125, 1450)],
}
const LAND_COLLISION_PROBES := [
	Vector2(900, 500), Vector2(700, 885), Vector2(1900, 640), Vector2(2400, 520),
	Vector2(2780, 1080), Vector2(3650, 285), Vector2(3330, 730), Vector2(4300, 850),
	Vector2(3500, 1150), Vector2(620, 1650), Vector2(850, 2250), Vector2(1650, 2400),
	Vector2(2220, 2340), Vector2(3050, 1950), Vector2(3600, 2300), Vector2(4300, 2100),
]

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.call("clear_pending_scene_state")
	root.set_meta("sea_overworld_lunar_day", 0.0)
	var scene := SEA_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	_verify_assets()
	_verify_location_layout(scene)
	_verify_fubo_return_contract(scene)
	await _verify_shared_exploration_hud(scene)
	await _verify_keyboard_movement(scene)
	await _verify_location_interaction(scene)
	await _verify_b_expansion(scene)
	await _verify_c_expansion(scene)
	await _verify_d_expansion(scene)
	_verify_navigation_collisions(scene)
	await _capture_central_seam(scene)
	await _verify_auto_triggers(scene)
	await _capture_preview(scene)

	if failures.is_empty():
		print("Sea overworld runtime verification passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_assets() -> void:
	var packed_scene_state := SEA_SCENE.get_state()
	var serialized_backgrounds := {
		NodePath("./World/Background"): false,
		NodePath("./World/EastBackground"): false,
		NodePath("./World/CBackground"): false,
		NodePath("./World/DBackground"): false,
	}
	for node_index in range(packed_scene_state.get_node_count()):
		var node_path := packed_scene_state.get_node_path(node_index)
		if serialized_backgrounds.has(node_path):
			serialized_backgrounds[node_path] = true
	for background_path in serialized_backgrounds:
		_expect(bool(serialized_backgrounds[background_path]), "%s must be serialized for editor visibility." % background_path)

	var chunk_paths := [
		"res://assets/backgrounds/sea_overworld/guangdong_sea_zone_a_v3.png",
		"res://assets/backgrounds/sea_overworld/guangdong_sea_zone_b_v3.png",
		"res://assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v3.png",
		"res://assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v3.png",
	]
	var chunk_textures: Array[Texture2D] = []
	for asset_path in chunk_paths:
		var chunk_texture := load(asset_path) as Texture2D
		chunk_textures.append(chunk_texture)
		_expect(chunk_texture != null and chunk_texture.get_size() == Vector2(3344, 1882), "%s must be a 3344x1882 v3 production chunk." % asset_path)
	for asset_path in [
		"res://assets/sprites/sea_overworld/protagonist_chibi_4dir_v1.png",
		"res://assets/sprites/sea_overworld/player_ship_4dir_states_v1.png",
		"res://assets/sprites/sea_overworld/event_ships_atlas_v2.png",
		"res://assets/sprites/sea_overworld/ship_wake_fx_atlas_v1.png",
		"res://assets/ui/sea_overworld/interaction_button_ink_v1.png",
		"res://assets/ui/sea_overworld/interaction_button_ink_active_v1.png",
		"res://assets/ui/sea_overworld/moon_clock_moon.png",
	]:
		var texture := load(asset_path) as Texture2D
		_expect(texture != null and texture.get_width() > 0, "%s could not be loaded." % asset_path)
	var moon_texture := load("res://assets/ui/sea_overworld/moon_clock_moon.png") as Texture2D
	var moon_image := moon_texture.get_image() if moon_texture != null else null
	_expect(moon_texture != null and moon_texture.get_size() == Vector2(256, 256), "Generated moon texture must use the compact 256x256 project size.")
	_expect(moon_image != null and moon_image.get_pixel(0, 0).a == 0.0 and moon_image.get_pixel(255, 255).a == 0.0, "Generated moon texture must retain transparent outer corners.")
	_expect(load("res://shaders/moon_phase.gdshader") is Shader, "Moon phase shader could not be loaded.")
	_expect(load("res://shaders/map_chunk_blend.gdshader") is Shader, "Map chunk blend shader could not be loaded.")

	var background_names := ["Background", "EastBackground", "CBackground", "DBackground"]
	var expected_origins := [Vector2.ZERO, Vector2(2388, 0), Vector2(0, 1292), Vector2(2388, 1292)]
	for index in range(background_names.size()):
		var background := current_scene.get_node("World/%s" % background_names[index]) as Sprite2D
		_expect(background.texture == chunk_textures[index], "%s must use its matching v3 production chunk." % background_names[index])
		_expect(background.position.is_equal_approx(expected_origins[index]), "%s has the wrong two-by-two chunk origin." % background_names[index])
		_expect(background.scale.is_equal_approx(Vector2(0.75, 0.75)), "%s must retain the 0.75 production scale." % background_names[index])
		var texture_node_count := 0
		for world_child in current_scene.get_node("World").get_children():
			if world_child is Sprite2D and (world_child as Sprite2D).texture == chunk_textures[index]:
				texture_node_count += 1
		_expect(texture_node_count == 1, "%s must not be duplicated at runtime." % background_names[index])

	var b_background := current_scene.get_node("World/EastBackground") as Sprite2D
	var c_background := current_scene.get_node("World/CBackground") as Sprite2D
	var d_background := current_scene.get_node("World/DBackground") as Sprite2D
	_expect(b_background.material is ShaderMaterial, "B map chunk must use alpha seam blending.")
	_expect(c_background.material is ShaderMaterial and bool((c_background.material as ShaderMaterial).get_shader_parameter("fade_from_top")), "C map chunk must fade from its north edge.")
	_expect(not bool((c_background.material as ShaderMaterial).get_shader_parameter("fade_from_left")), "C map chunk must not fade from its west edge.")
	_expect(d_background.material is ShaderMaterial and bool((d_background.material as ShaderMaterial).get_shader_parameter("fade_from_left")), "D map chunk must fade from its west edge.")
	_expect(bool((d_background.material as ShaderMaterial).get_shader_parameter("fade_from_top")), "D map chunk must fade from its north edge.")

	var player := current_scene.get_node("World/Player") as CharacterBody2D
	var camera := player.get_node("Camera2D") as Camera2D
	var ship := player.get_node("VisualRoot/ShipSprite") as Sprite2D
	var hero := player.get_node("VisualRoot/HeroSprite") as Sprite2D
	var wake := player.get_node("WakeSprite") as Sprite2D
	var side_splash := player.get_node("SideSplashSprite") as Sprite2D
	var player_shape := (player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_expect(camera.limit_right == 4896 and camera.limit_bottom == 2704, "Camera limits must cover the complete A/B/C/D world.")
	_expect((player.get("movement_bounds") as Rect2).end.is_equal_approx(Vector2(4862, 2670)), "Player movement bounds must cover the complete sea-world envelope.")
	_expect(ship.scale.is_equal_approx(Vector2(0.28, 0.28)), "Player ship must use the compact production-map scale.")
	_expect(hero.scale.is_equal_approx(Vector2(0.088, 0.088)), "Player chibi must use the compact production-map scale.")
	_expect(wake.scale.is_equal_approx(Vector2(0.28, 0.28)) and side_splash.scale.is_equal_approx(Vector2(0.28, 0.28)), "Sailing effects must match the compact ship scale.")
	_expect(player_shape != null and is_equal_approx(player_shape.radius, 19.0), "Player collision radius must match the compact hull.")


func _verify_location_layout(scene: Node) -> void:
	var locations := get_nodes_in_group("sea_location")
	_expect(locations.size() == 15, "Production map must expose exactly fifteen enterable locations.")
	var region_names := {
		"A": A_LOCATIONS,
		"B": B_LOCATIONS,
		"C": C_LOCATIONS,
		"D": D_LOCATIONS,
	}
	for location_name in EXPECTED_LOCATIONS:
		var location := _find_location(locations, location_name)
		_expect(location != null, "Production location %s is missing." % location_name)
		if location != null:
			_expect(location.position.distance_to(EXPECTED_LOCATIONS[location_name]) <= 80.0, "%s exceeds the approved ±80 coordinate tolerance." % location_name)
	for location_name in region_names["A"]:
		var location := _find_location(locations, location_name)
		_expect(location != null and location.position.x < 2388.0 and location.position.y < 1292.0, "%s must remain in A northwest of both seams." % location_name)
	for location_name in region_names["B"]:
		var location := _find_location(locations, location_name)
		_expect(location != null and location.position.x > 2388.0 and location.position.y < 1292.0, "%s must remain in B northeast of the seams." % location_name)
	for location_name in region_names["C"]:
		var location := _find_location(locations, location_name)
		_expect(location != null and location.position.x < 2388.0 and location.position.y > 1292.0, "%s must remain in C southwest of the seams." % location_name)
	for location_name in region_names["D"]:
		var location := _find_location(locations, location_name)
		_expect(location != null and location.position.x > 2388.0 and location.position.y > 1292.0, "%s must remain in D southeast of the seams." % location_name)
	_expect(A_LOCATIONS.size() == 4 and B_LOCATIONS.size() == 5 and C_LOCATIONS.size() == 4 and D_LOCATIONS.size() == 2, "Region responsibility must remain A4/B5/C4/D2.")
	var moon_harbor := _find_location(locations, "月环商港")
	if moon_harbor != null:
		var moon_shape_node := moon_harbor.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(moon_shape_node.shape is RectangleShape2D and moon_shape_node.position.x < 0.0, "Moon harbor must retain its left-facing rectangular entry.")
	var qingyu := _find_location(locations, "青屿秘境")
	if qingyu != null:
		var qingyu_shape_node := qingyu.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(not _is_water_clear(qingyu.position, 2.0), "Qingyu location center must sit on the visible pagoda island.")
		_expect(qingyu_shape_node.shape is RectangleShape2D and qingyu_shape_node.position.y > 0.0, "Qingyu must use its south-side water entry.")
		_expect(_is_water_clear(_find_clear_entry_point(qingyu), 19.0), "Qingyu south-side entry must remain reachable open water.")
		var qingyu_map_offset := qingyu.get_meta("map_label_offset", Vector2.ZERO) as Vector2
		_expect(qingyu_map_offset.x > 0.0 and qingyu_map_offset.y < 0.0, "Qingyu full-map label must be offset to the pagoda island's upper-right.")
	var script_constants := (scene.get_script() as Script).get_script_constant_map()
	var spawn := script_constants.get("SOUTH_SEA_HARBOR_SPAWN", Vector2.ZERO) as Vector2
	var south_harbor := _find_location(locations, "南海军港")
	_expect(_is_water_clear(spawn, 19.0), "South Sea harbor spawn must remain outside static collision.")
	_expect(south_harbor != null and _trigger_contains_point(south_harbor, spawn), "South Sea harbor spawn must still activate its entry trigger.")
	var fubo := _find_location(locations, "伏波古岭")
	_expect(fubo != null and str(fubo.get_meta("target_scene_path", "")) == FUBO_TRAVEL.FUBO_SCENE_PATH, "Fubo must point to its real island scene.")
	_expect(fubo != null and str(fubo.get_meta("entry_message", "")) == "进入伏波古岭", "Fubo must no longer use coming-soon copy.")


func _verify_fubo_return_contract(scene: Node) -> void:
	if not scene.has_method("_consume_fubo_return") or not scene.has_method("_restore_fubo_return"):
		_expect(false, "Sea overworld must expose Fubo return consume and restore helpers.")
		return
	var original_context := FUBO_TRAVEL.make_context(
		(scene.get_node("World/Player") as CharacterBody2D).global_position,
		int(scene.get_node("World/Player").call("save_facing_index")),
		int(scene.get("_exploration_stage")),
		float(scene.get("_lunar_day"))
	)
	var expected_context := FUBO_TRAVEL.make_context(Vector2(4210, 1135), 2, 3, 8.5)
	root.set_meta(FUBO_TRAVEL.RETURN_REQUEST_META, true)
	root.set_meta(FUBO_TRAVEL.RETURN_CONTEXT_META, expected_context)
	var consumed: Dictionary = scene.call("_consume_fubo_return")
	_expect(consumed == expected_context, "Fubo return context must be consumed intact.")
	_expect(not root.has_meta(FUBO_TRAVEL.RETURN_REQUEST_META) and not root.has_meta(FUBO_TRAVEL.RETURN_CONTEXT_META), "Consumed Fubo return metadata must be removed.")
	scene.call("_restore_fubo_return", consumed)
	var player := scene.get_node("World/Player") as CharacterBody2D
	_expect(player.global_position.is_equal_approx(Vector2(4210, 1135)), "Fubo return must restore the ship position.")
	_expect(int(player.call("save_facing_index")) == 2, "Fubo return must restore ship facing.")
	_expect(int(scene.get("_exploration_stage")) == 3, "Fubo return must restore exploration stage.")
	_expect(is_equal_approx(float(scene.get("_lunar_day")), 8.5), "Fubo return must restore lunar day.")
	root.set_meta(FUBO_TRAVEL.RETURN_REQUEST_META, true)
	root.set_meta(FUBO_TRAVEL.RETURN_CONTEXT_META, {"ship_position": Vector2(INF, 0)})
	var invalid_context: Dictionary = scene.call("_consume_fubo_return")
	scene.call("_restore_fubo_return", invalid_context)
	_expect(player.global_position.is_equal_approx(FUBO_TRAVEL.FALLBACK_SEA_POSITION), "Invalid Fubo return data must use the approved safe sea position.")
	scene.call("_restore_fubo_return", original_context)


func _verify_shared_exploration_hud(scene: Node) -> void:
	var hud := root.get_node("ExplorationUI/HUD") as Control
	var player := scene.get_node("World/Player") as CharacterBody2D
	var main_task := hud.get_node("QuestTracker/MainQuest/TaskName") as Label
	var main_objective := hud.get_node("QuestTracker/MainQuest/Objective") as Label
	var side_task := hud.get_node("QuestTracker/SideQuest/TaskName") as Label
	_expect(hud.visible, "Sea overworld must reuse the shared exploration HUD from scenes one and two.")
	_expect(main_task.text == "探索大地图" and "WASD" in main_objective.text, "Sea overworld tracker must start with the map-exploration task.")
	_expect(side_task.text == "海上见闻", "Sea overworld must replace the shared HUD's old placeholder side task.")
	_expect(scene.get_node_or_null("UI/Root/TitlePanel") == null and scene.get_node_or_null("UI/Root/HelpPanel") == null, "Old sea-map title and help panels must be removed.")
	_expect(scene.get_node_or_null("UI/Root/ToastPanel") == null, "Old sea-map toast UI must be replaced by the shared HUD toast.")

	var quest_button := hud.find_child("QuestButton", true, false) as Button
	quest_button.pressed.emit()
	await process_frame
	var quest_screen := hud.get_node("QuestScreen") as Control
	var selected_title := quest_screen.get_node("SelectedQuestTitle") as RichTextLabel
	var steps := quest_screen.get_node("QuestStepsScroll/QuestSteps") as VBoxContainer
	_expect(quest_screen.visible and "探索大地图" in selected_title.text, "Shared quest screen must open on the sea-map exploration task.")
	_expect(steps.get_child_count() == 4, "Explore-map quest must display its four-step task flow.")
	_expect("奉诏入殿" not in selected_title.text and "巡视水师驻地" not in selected_title.text, "Sea-map quest screen must not show scene-one or scene-two task names.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var screenshot_error := root.get_texture().get_image().save_png(QUEST_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Sea overworld quest preview screenshot could not be saved.")
	var return_button := quest_screen.find_child("QuestReturnButton", true, false) as Button
	return_button.pressed.emit()
	await process_frame
	_expect(not quest_screen.visible, "Returning from the sea-map quest screen must restore exploration.")

	var moon_status := hud.get_node("PlayerStatus") as Control
	var moon_frame := moon_status.get_node("GeneratedStatusFrame") as TextureRect
	var moon_icon := moon_status.get_node("PortraitFrame/MoonIcon") as TextureRect
	var moon_phase_name := moon_status.get_node("MoonPhaseName") as Label
	var moon_material := moon_icon.material as ShaderMaterial
	var map_status := hud.get_node("SeaMapStatus") as Control
	var map_frame := map_status.get_node("GeneratedMapFrame") as TextureRect
	var map_icon := map_status.get_node("MapIcon") as TextureRect
	var map_button := map_status.get_node("MapButton") as Button
	var quest_tracker := hud.get_node("QuestTracker") as Control
	_expect(not moon_status.get_node("NamePlate").visible, "Sea-map HUD must remove the player information plate.")
	_expect(not moon_status.get_node("PortraitFrame/ProtagonistPortrait").visible, "Sea-map HUD must replace the protagonist portrait.")
	_expect(moon_frame.texture.resource_path.ends_with("function_button.png"), "Lunar clock must retain the standalone diamond frame.")
	_expect(moon_icon.texture.resource_path.ends_with("moon_clock_moon.png") and moon_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Lunar clock must use the generated nearest-filtered moon texture.")
	_expect(moon_phase_name.text == "新月", "Sea-map lunar clock must begin at the new moon.")
	hud.call("set_lunar_day", 7.375)
	_expect(moon_phase_name.text == "上弦月" and is_equal_approx(float(moon_material.get_shader_parameter("phase")), 0.25), "Quarter-cycle lunar day must display the first-quarter moon.")
	hud.call("set_lunar_day", 14.75)
	_expect(moon_phase_name.text == "满月" and is_equal_approx(float(moon_material.get_shader_parameter("phase")), 0.5), "Half-cycle lunar day must display the full moon.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var full_moon_screenshot_error := root.get_texture().get_image().save_png(FULL_MOON_SCREENSHOT_PATH)
		_expect(full_moon_screenshot_error == OK, "Full-moon HUD preview screenshot could not be saved.")
	hud.call("set_lunar_day", float(root.get_meta("sea_overworld_lunar_day", 0.0)))
	_expect(moon_status.size.is_equal_approx(Vector2(195.0, 195.0)), "Lunar clock must keep the large top-left diamond footprint.")
	_expect(moon_status.position.x > quest_tracker.position.x and moon_status.position.y + moon_status.size.y < quest_tracker.position.y, "Lunar clock must sit directly above and to the right of the task tracker origin.")
	_expect(map_frame.texture.resource_path.ends_with("function_button.png"), "Sea-map entry must retain the standalone diamond frame.")
	_expect(map_icon.texture.resource_path.ends_with("hud_map_v1.png"), "Sea-map entry must use the generated ink-wash map icon.")
	_expect(map_status.size.is_equal_approx(Vector2(136.0, 136.0)), "Sea-map diamond must use the compact bottom-right footprint.")
	_expect(is_equal_approx(map_status.anchor_left, 1.0) and is_equal_approx(map_status.anchor_top, 1.0), "Sea-map diamond must stay anchored to the bottom-right corner.")

	map_button.pressed.emit()
	await process_frame
	await process_frame
	var map_screen := hud.get_node("SeaMapScreen") as Control
	var map_panel := map_screen.get_node("MapPanel") as Panel
	var generated_scroll_frame := map_panel.get_node("GeneratedScrollFrame") as TextureRect
	var map_viewport := map_panel.get_node("MapViewport") as Control
	var map_texture_layer := map_screen.get_node("MapPanel/MapViewport/MapTextureLayer") as Control
	var map_texture := map_texture_layer.get_node("MapTexture") as TextureRect
	var east_map_texture := map_texture_layer.get_node("MapTexture2") as TextureRect
	var c_map_texture := map_texture_layer.get_node("MapTexture3") as TextureRect
	var d_map_texture := map_texture_layer.get_node("MapTexture4") as TextureRect
	var location_layer := map_screen.get_node("MapPanel/MapViewport/MapLocationLayer") as Control
	var player_name := map_screen.get_node("MapPanel/MapViewport/PlayerMarker/PlayerName") as Label
	_expect(map_screen.visible, "Clicking the sea-map diamond must open the full map screen.")
	_expect(map_panel.size.is_equal_approx(Vector2(1280, 853)), "Full sea map must use the large unfolded-chart footprint.")
	_expect(generated_scroll_frame.texture.resource_path.ends_with("sea_map_scroll_frame_v1.png"), "Full sea map must use the generated ink-pixel chart scroll frame.")
	_expect(map_viewport.size.is_equal_approx(Vector2(870, 510)), "Detailed map content must sit inside the scroll's central safe area.")
	_expect(map_panel.get_node_or_null("Hint") == null, "Full sea map must not retain the old bottom explanatory caption.")
	_expect(not player.controls_enabled, "Opening the full map must pause sea-map movement.")
	var paused_lunar_day := float(root.get_meta("sea_overworld_lunar_day", 0.0))
	Input.action_press("move_right")
	for _frame in range(3):
		await physics_frame
	Input.action_release("move_right")
	_expect(is_equal_approx(float(root.get_meta("sea_overworld_lunar_day", 0.0)), paused_lunar_day), "Opening the full map must pause lunar time progression.")
	_expect(map_texture.texture.resource_path.ends_with("guangdong_sea_zone_a_v3.png"), "Full map screen must show production chunk A.")
	_expect(east_map_texture.texture.resource_path.ends_with("guangdong_sea_zone_b_v3.png"), "Full map screen must show production chunk B.")
	_expect(east_map_texture.material is ShaderMaterial, "Full map B texture must retain seam blending.")
	_expect(c_map_texture.texture.resource_path.ends_with("guangdong_sea_zone_c_v3.png"), "Full map screen must show production chunk C.")
	_expect(c_map_texture.material is ShaderMaterial, "Full map C-zone texture must retain seam blending.")
	_expect(bool((c_map_texture.material as ShaderMaterial).get_shader_parameter("fade_from_top")), "Full map C-zone texture must fade from its north edge.")
	_expect(d_map_texture.texture.resource_path.ends_with("guangdong_sea_zone_d_v3.png"), "Full map screen must show production chunk D.")
	_expect(d_map_texture.material is ShaderMaterial, "Full map D-zone texture must retain seam blending.")
	_expect(bool((d_map_texture.material as ShaderMaterial).get_shader_parameter("fade_from_left")), "Full map D-zone texture must fade from its west edge.")
	_expect(bool((d_map_texture.material as ShaderMaterial).get_shader_parameter("fade_from_top")), "Full map D-zone texture must fade from its north edge.")
	_expect(location_layer.get_child_count() == 15, "Full map must show exactly the fifteen enterable island labels.")
	var location_names: Array[String] = []
	var east_bay_map_label: Label
	var qingyu_map_label: Label
	for location_label in location_layer.get_children():
		var label := location_label as Label
		location_names.append(label.text)
		if "东湾水寨" in label.text:
			east_bay_map_label = label
		elif "青屿秘境" in label.text:
			qingyu_map_label = label
	for expected_name in ["南海军港", "川山渔村", "东湾水寨", "青屿秘境", "红湾卫所", "南澳商港", "澄海灯岛", "龙门海寨", "白沙渔岛", "玄潮古屿", "沧门礁堡", "月环商港", "雾岚群岛", "伏波古岭", "珊湾渔链"]:
		_expect(location_names.any(func(text: String) -> bool: return expected_name in text), "Full map is missing the %s island label." % expected_name)
	for hidden_name in ["茶叶商船", "岭南商船", "私盐商船", "漂流木箱"]:
		_expect(location_names.all(func(text: String) -> bool: return hidden_name not in text), "Full map must not display NPC ships or random events.")
	_expect(qingyu_map_label != null and (qingyu_map_label.get_meta("world_position", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(2800, 400)), "Qingyu full-map label must align to the pagoda island's upper-right.")
	if east_bay_map_label != null and qingyu_map_label != null:
		var east_bay_label_center := east_bay_map_label.position + east_bay_map_label.size * 0.5
		var qingyu_label_center := qingyu_map_label.position + qingyu_map_label.size * 0.5
		_expect(absf(qingyu_label_center.x - east_bay_label_center.x) >= 120.0, "Qingyu and East Bay label text must retain clear horizontal separation on the full map.")
	_expect(player_name.text == "当前位置", "Full map player marker must display only the current-position label.")
	if DisplayServer.get_name() != "headless":
		var map_screenshot_error := root.get_texture().get_image().save_png(MAP_SCREENSHOT_PATH)
		_expect(map_screenshot_error == OK, "Sea overworld full-map preview screenshot could not be saved.")
	var map_close_button := map_screen.get_node("MapPanel/CloseButton") as Button
	map_close_button.pressed.emit()
	await process_frame
	_expect(not map_screen.visible and player.controls_enabled, "Closing the full map must restore sea-map movement.")


func _verify_keyboard_movement(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var wake := player.get_node("WakeSprite") as Sprite2D
	var ship := player.get_node("VisualRoot/ShipSprite") as Sprite2D
	var hero := player.get_node("VisualRoot/HeroSprite") as Sprite2D
	var starting_position := player.position
	var starting_lunar_day := float(root.get_meta("sea_overworld_lunar_day", 0.0))
	Input.action_press("move_right")
	for _frame in range(4):
		await physics_frame
	var moving_ship_y := ship.position.y
	var moving_hero_y := hero.position.y
	_expect(player.position.x > starting_position.x, "WASD/direction input did not move the sea-map ship.")
	_expect(wake.visible, "Moving ship must show the animated wake layer.")
	_expect(float(root.get_meta("sea_overworld_lunar_day", 0.0)) > starting_lunar_day, "Sailing must advance lunar time.")
	var task_objective := root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label
	_expect("靠近任意岛屿" in task_objective.text, "First map-exploration step must advance after sailing.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot_error := root.get_texture().get_image().save_png(MOVEMENT_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Sea overworld movement preview screenshot could not be saved.")
	Input.action_release("move_right")
	await physics_frame
	await physics_frame
	_expect(not wake.visible, "Ship wake must hide after movement stops.")
	_expect(is_zero_approx(moving_ship_y), "The sailing ship frame must retain its approved visual position.")
	_expect(is_equal_approx(ship.position.y, -98.0 * ship.scale.y), "The stopped ship frame must compensate its 98-pixel atlas deck-anchor offset.")
	_expect(is_equal_approx(hero.position.y, moving_hero_y), "The protagonist must stay attached to the same ship-deck anchor when movement stops.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var stopped_screenshot_error := root.get_texture().get_image().save_png(STOPPED_SCREENSHOT_PATH)
		_expect(stopped_screenshot_error == OK, "Sea overworld stopped-state preview screenshot could not be saved.")
	var stopped_lunar_day := float(root.get_meta("sea_overworld_lunar_day", 0.0))
	for _frame in range(3):
		await physics_frame
	_expect(is_equal_approx(float(root.get_meta("sea_overworld_lunar_day", 0.0)), stopped_lunar_day), "Lunar time must stop when the ship is not sailing.")


func _verify_location_interaction(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	var enter_button := scene.get_node("UI/Root/InteractionPrompt/EnterButton") as BaseButton
	var texture_button := enter_button as TextureButton
	var location_label := scene.get_node("UI/Root/InteractionPrompt/LocationName") as Label
	var toast := root.get_node("ExplorationUI/HUD/ComingSoonToast") as Control
	var toast_label := root.get_node("ExplorationUI/HUD/ComingSoonToast/Message") as Label
	var task_objective := root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label
	var locations := get_nodes_in_group("sea_location")
	_expect(not locations.is_empty(), "Sea overworld must provide at least one location trigger.")
	_expect(texture_button.texture_normal.resource_path == "res://assets/ui/sea_overworld/interaction_button_ink_v1.png", "Location interaction must use the ink-wash normal button asset.")
	_expect(texture_button.texture_pressed.resource_path == "res://assets/ui/sea_overworld/interaction_button_ink_active_v1.png", "Location interaction must use the ink-wash pressed button asset.")
	_expect(prompt.size.is_equal_approx(Vector2(360.0, 88.0)), "Ink-wash interaction prompt must keep its intended 2x asset scale.")
	if locations.is_empty():
		return
	var location := _find_location(locations, "川山渔村")
	_expect(location != null, "A non-harbor location is required for the coming-soon interaction check.")
	if location == null:
		return
	_expect(location.get_node_or_null("IslandOutline") == null, "Location proximity must not draw a yellow island outline.")
	_expect(location.get_node_or_null("HighlightRing") == null, "Location highlight must not use a circular ring.")
	_expect(location.get_node_or_null("HighlightedName") == null, "Location names must not be drawn over islands; the bottom prompt is sufficient.")
	player.global_position = _find_clear_entry_point(location)
	await physics_frame
	await physics_frame
	_expect(prompt.visible, "Approaching a location must show the highlighted interaction prompt.")
	_expect("川山渔村" in location_label.text, "The bottom interaction prompt must retain the active location name.")
	_expect("点击进入按钮" in task_objective.text, "Approaching an island must advance the explore-map task flow.")
	var position_before_prompt := player.position
	await physics_frame
	_expect(player.position.is_equal_approx(position_before_prompt), "Location proximity must not automatically move or slow the stopped ship.")
	enter_button.pressed.emit()
	await process_frame
	_expect(toast.visible and "该地点即将开放" in toast_label.text, "Enter button must show the location coming-soon message.")
	_expect("接触海上的船只" in task_objective.text, "Trying to enter an island must advance the explore-map task flow.")
	player.global_position = Vector2(2200, 1500)
	for _frame in range(4):
		await physics_frame
	await process_frame
	_expect(not prompt.visible, "Leaving a location range must hide its interaction prompt.")

	var east_bay: Area2D
	var qingyu: Area2D
	for location_node in locations:
		if str(location_node.get_meta("location_name", "")) == "东湾水寨":
			east_bay = location_node as Area2D
		elif str(location_node.get_meta("location_name", "")) == "青屿秘境":
			qingyu = location_node as Area2D
	_expect(east_bay != null, "East Bay stronghold trigger is missing.")
	if east_bay != null:
		var east_bay_shape_node := east_bay.get_node("EntryTriggerShape") as CollisionShape2D
		var east_bay_shape := east_bay_shape_node.shape as RectangleShape2D
		_expect(east_bay_shape != null and east_bay_shape.size.x >= 400.0, "East Bay must retain a broad dock-side rectangular entry.")
		_expect(east_bay_shape_node.position.y > 0.0, "East Bay entry range must stay on the island's front side.")
		player.global_position = _find_clear_entry_point(east_bay)
		for _frame in range(3):
			await physics_frame
		_expect(prompt.visible and "东湾水寨" in location_label.text, "East Bay entry must remain reachable from open water.")
	player.global_position = Vector2(2200, 1500)
	for _frame in range(3):
		await physics_frame
	_expect(qingyu != null, "Qingyu secret realm trigger is missing.")
	if qingyu != null:
		var qingyu_shape_node := qingyu.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(qingyu_shape_node.shape is RectangleShape2D and qingyu_shape_node.position.y > 0.0, "Qingyu pagoda-island entry must use a south-side rectangular trigger.")
		player.global_position = _find_clear_entry_point(qingyu)
		await physics_frame
		await physics_frame
		_expect(prompt.visible and "青屿秘境" in location_label.text, "Qingyu secret realm must remain reachable from open water.")


func _verify_b_expansion(scene: Node) -> void:
	var b_locations := _collect_region_locations(B_LOCATIONS, "B")
	_expect(b_locations.size() == 5, "B must contain five upper-right water-combat locations.")
	var placeholder_locations: Array[Area2D] = []
	for location in b_locations:
		if str(location.get_meta("location_name", "")) != "伏波古岭":
			placeholder_locations.append(location)
	await _verify_region_interactions(scene, placeholder_locations, "月环商港", B_ZONE_SCREENSHOT_PATH)


func _verify_c_expansion(scene: Node) -> void:
	var c_locations := _collect_region_locations(C_LOCATIONS, "C")
	_expect(c_locations.size() == 4, "C must contain four lower-left frontier locations.")
	await _verify_region_interactions(scene, c_locations, "龙门海寨", C_ZONE_SCREENSHOT_PATH)


func _verify_d_expansion(scene: Node) -> void:
	var d_locations := _collect_region_locations(D_LOCATIONS, "D")
	_expect(d_locations.size() == 2, "D must contain two lower-right enemy-core locations matching the two visible islands.")
	await _verify_region_interactions(scene, d_locations, "南澳商港", D_ZONE_SCREENSHOT_PATH)


func _collect_region_locations(names: Array, region_name: String) -> Array[Area2D]:
	var all_locations := get_nodes_in_group("sea_location")
	var region_locations: Array[Area2D] = []
	for expected_name in names:
		var location := _find_location(all_locations, expected_name)
		_expect(location != null, "%s-zone location %s is missing." % [region_name, expected_name])
		if location == null:
			continue
		region_locations.append(location)
		if expected_name != "伏波古岭":
			_expect(str(location.get_meta("entry_message", "")) == "该岛屿即将开放", "%s must use the island coming-soon message." % expected_name)
	return region_locations


func _verify_region_interactions(scene: Node, locations: Array[Area2D], preview_name: String, screenshot_path: String) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	var enter_button := scene.get_node("UI/Root/InteractionPrompt/EnterButton") as BaseButton
	var location_label := scene.get_node("UI/Root/InteractionPrompt/LocationName") as Label
	var toast_label := root.get_node("ExplorationUI/HUD/ComingSoonToast/Message") as Label
	for location in locations:
		player.global_position = Vector2(2200, 1500)
		for _frame in range(3):
			await physics_frame
		player.global_position = _find_clear_entry_point(location)
		for _frame in range(3):
			await physics_frame
		var location_name := str(location.get_meta("location_name", ""))
		_expect(prompt.visible and location_name in location_label.text, "%s must expose its entry prompt from collision-free water." % location_name)
		enter_button.pressed.emit()
		await process_frame
		_expect(location_name in toast_label.text and "该岛屿即将开放" in toast_label.text, "%s must show the island coming-soon toast." % location_name)

	if DisplayServer.get_name() != "headless":
		var preview_location := _find_location(locations, preview_name)
		if preview_location != null:
			player.global_position = _find_clear_entry_point(preview_location)
			(player.get_node("Camera2D") as Camera2D).reset_smoothing()
			for _frame in range(3):
				await physics_frame
			enter_button.pressed.emit()
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot_error := root.get_texture().get_image().save_png(screenshot_path)
			_expect(screenshot_error == OK, "%s preview screenshot could not be saved." % preview_name)

	player.global_position = Vector2(2200, 1500)
	for _frame in range(3):
		await physics_frame


func _verify_navigation_collisions(scene: Node) -> void:
	var world_collision := scene.get_node("World/WorldCollision") as StaticBody2D
	_expect(world_collision.get_child_count() == 32, "Production map must build the approved 32 named coastline/island blockers.")
	for collision_child in world_collision.get_children():
		_expect(not collision_child.name.is_empty(), "Every production collision component must have a diagnostic name.")
		_expect("wreck" not in collision_child.name.to_lower(), "The decorative central wreck must not receive collision.")
	for route_name in NAVIGATION_ROUTES:
		var points: Array = NAVIGATION_ROUTES[route_name]
		for index in range(points.size() - 1):
			var start: Vector2 = points[index]
			var finish: Vector2 = points[index + 1]
			var steps := maxi(1, ceili(start.distance_to(finish) / 24.0))
			for step in range(steps + 1):
				var point := start.lerp(finish, step / float(steps))
				if not _is_water_clear(point, 19.0):
					_expect(false, "Navigation route %s is blocked at %s." % [route_name, point])
					break
	for land_point in LAND_COLLISION_PROBES:
		_expect(not _is_water_clear(land_point, 2.0), "Major visible land at %s must block navigation." % land_point)
	for water_point in [Vector2(1300, 850), Vector2(3200, 440), Vector2(2150, 1720), Vector2(4280, 2640)]:
		_expect(_is_water_clear(water_point, 19.0), "Required spawn/harbor/wreck water at %s must remain clear." % water_point)
	for location in get_nodes_in_group("sea_location"):
		_expect(_is_water_clear(_find_clear_entry_point(location as Area2D), 19.0), "%s entry must retain reachable water." % location.get_meta("location_name"))
	for trigger in get_nodes_in_group("sea_auto_trigger"):
		_expect(_is_water_clear((trigger as Area2D).global_position, 19.0), "%s auto trigger must remain on open water." % trigger.get_meta("display_name"))


func _capture_central_seam(scene: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	player.global_position = Vector2(2450, 1400)
	(root.get_node("ExplorationUI/HUD/ComingSoonToast") as Control).hide()
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	for _frame in range(3):
		await physics_frame
	await RenderingServer.frame_post_draw
	var screenshot_error := root.get_texture().get_image().save_png(CENTRAL_SEAM_SCREENSHOT_PATH)
	_expect(screenshot_error == OK, "Central four-chunk seam screenshot could not be saved.")


func _verify_auto_triggers(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var toast_label := root.get_node("ExplorationUI/HUD/ComingSoonToast/Message") as Label
	var generic_ship := scene.get_node("World/WorldMarkers/ShipTrigger1") as Area2D
	player.global_position = Vector2(1240, 1120)
	await physics_frame
	player.global_position = generic_ship.global_position
	await physics_frame
	await physics_frame
	_expect("该船只开发中" in toast_label.text, "Touching the generic sea-map ship must show its development placeholder.")

	var crate := scene.get_node("World/WorldMarkers/DriftEvent") as Area2D
	player.global_position = Vector2(1240, 1120)
	await physics_frame
	player.global_position = crate.global_position
	await physics_frame
	await physics_frame
	var event_dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	_expect(event_dialogue.visible, "Touching the drifting crate must open the soldier choice dialogue.")
	var option_box := event_dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer
	if option_box.get_child_count() == 2:
		(option_box.get_child(1) as Button).pressed.emit()
		await process_frame
	var task_objective := root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label
	_expect(task_objective.text == "继续探索岭南海域", "Sea target contact must finish the prototype exploration task flow.")


func _capture_preview(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var enter_button := scene.get_node("UI/Root/InteractionPrompt/EnterButton") as BaseButton
	var locations := get_nodes_in_group("sea_location")
	if locations.is_empty():
		return
	var location := _find_location(locations, "川山渔村")
	if location == null:
		return
	player.global_position = _find_clear_entry_point(location)
	for _frame in range(4):
		await physics_frame
	enter_button.pressed.emit()
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("Sea overworld preview skipped in headless display mode.")
		return
	var screenshot_error := root.get_texture().get_image().save_png(SCREENSHOT_PATH)
	_expect(screenshot_error == OK, "Sea overworld preview screenshot could not be saved.")


func _find_location(locations: Array, location_name: String) -> Area2D:
	for location_node in locations:
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
	elif shape_node.shape is CircleShape2D:
		var radius := (shape_node.shape as CircleShape2D).radius * 0.75
		for index in range(8):
			offsets.append(shape_node.position + Vector2.from_angle(TAU * index / 8.0) * radius)
	for offset in offsets:
		var point := area.global_position + offset
		if _is_water_clear(point, 19.0):
			return point
	return area.global_position + shape_node.position


func _trigger_contains_point(area: Area2D, point: Vector2) -> bool:
	var shape_node := area.get_node("EntryTriggerShape") as CollisionShape2D
	var local_point := point - area.global_position - shape_node.position
	if shape_node.shape is RectangleShape2D:
		var half_size := (shape_node.shape as RectangleShape2D).size * 0.5
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y
	if shape_node.shape is CircleShape2D:
		return local_point.length() <= (shape_node.shape as CircleShape2D).radius
	return false


func _is_water_clear(point: Vector2, radius: float) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return root.world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
