extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const SCREENSHOT_PATH := "res://.godot/sea_overworld_preview.png"
const MOVEMENT_SCREENSHOT_PATH := "res://.godot/sea_overworld_movement_preview.png"
const QUEST_SCREENSHOT_PATH := "res://.godot/sea_overworld_quest_preview.png"
const MAP_SCREENSHOT_PATH := "res://.godot/sea_overworld_map_preview.png"
const FULL_MOON_SCREENSHOT_PATH := "res://.godot/sea_overworld_lunar_full_preview.png"
const EAST_SCREENSHOT_PATH := "res://.godot/sea_overworld_east_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := SEA_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	_verify_assets()
	await _verify_shared_exploration_hud(scene)
	await _verify_keyboard_movement(scene)
	await _verify_location_interaction(scene)
	await _verify_east_expansion(scene)
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
	for asset_path in [
		"res://assets/backgrounds/sea_overworld/guangdong_sea_map_v2_hd.png",
		"res://assets/backgrounds/sea_overworld/guangdong_east_sea_expansion_v1.png",
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
	var hd_map := load("res://assets/backgrounds/sea_overworld/guangdong_sea_map_v2_hd.png") as Texture2D
	_expect(hd_map != null and hd_map.get_width() >= 3000, "Sea overworld map must use the high-resolution source texture.")
	var background := current_scene.get_node("World/Background") as Sprite2D
	_expect(background.scale.is_equal_approx(Vector2(0.75, 0.75)), "High-resolution map must retain the existing world footprint.")
	var east_map := load("res://assets/backgrounds/sea_overworld/guangdong_east_sea_expansion_v1.png") as Texture2D
	_expect(east_map != null and east_map.get_size() == hd_map.get_size(), "East map chunk must match the base map source dimensions.")
	var east_background := current_scene.get_node("World/EastBackground") as Sprite2D
	_expect(east_background.texture == east_map and east_background.position.is_equal_approx(Vector2(2388, 0)), "East map chunk must overlap the base map at the configured seam.")
	_expect(east_background.material is ShaderMaterial, "East map chunk must use alpha seam blending.")
	var player := current_scene.get_node("World/Player") as CharacterBody2D
	var camera := player.get_node("Camera2D") as Camera2D
	_expect(camera.limit_right == 4896 and camera.limit_bottom == 1412, "Camera limits must cover both map chunks.")
	_expect((player.get("movement_bounds") as Rect2).end.is_equal_approx(Vector2(4862, 1378)), "Player movement bounds must cover the expanded sea world.")


func _verify_shared_exploration_hud(scene: Node) -> void:
	var hud := scene.get_node("UI/ExplorationHUD") as Control
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
	var map_texture_layer := map_screen.get_node("MapPanel/MapViewport/MapTextureLayer") as Control
	var map_texture := map_texture_layer.get_node("MapTexture") as TextureRect
	var east_map_texture := map_texture_layer.get_node("MapTexture2") as TextureRect
	var location_layer := map_screen.get_node("MapPanel/MapViewport/MapLocationLayer") as Control
	var player_name := map_screen.get_node("MapPanel/MapViewport/PlayerMarker/PlayerName") as Label
	_expect(map_screen.visible, "Clicking the sea-map diamond must open the full map screen.")
	_expect(not player.controls_enabled, "Opening the full map must pause sea-map movement.")
	var paused_lunar_day := float(root.get_meta("sea_overworld_lunar_day", 0.0))
	Input.action_press("move_right")
	for _frame in range(3):
		await physics_frame
	Input.action_release("move_right")
	_expect(is_equal_approx(float(root.get_meta("sea_overworld_lunar_day", 0.0)), paused_lunar_day), "Opening the full map must pause lunar time progression.")
	_expect(map_texture.texture.resource_path.ends_with("guangdong_sea_map_v2_hd.png"), "Full map screen must show the complete sea-overworld map texture.")
	_expect(east_map_texture.texture.resource_path.ends_with("guangdong_east_sea_expansion_v1.png"), "Full map screen must show the eastern expansion texture.")
	_expect(east_map_texture.material is ShaderMaterial, "Full map eastern texture must retain seam blending.")
	_expect(location_layer.get_child_count() == 7, "Full map must show exactly the seven enterable island labels.")
	var location_names: Array[String] = []
	for location_label in location_layer.get_children():
		location_names.append((location_label as Label).text)
	for expected_name in ["南海军港", "川山渔村", "东湾水寨", "青屿秘境", "红湾卫所", "南澳商港", "东极秘岛"]:
		_expect(location_names.any(func(text: String) -> bool: return expected_name in text), "Full map is missing the %s island label." % expected_name)
	for hidden_name in ["近海渔船", "岭南商船", "漂流木箱"]:
		_expect(location_names.all(func(text: String) -> bool: return hidden_name not in text), "Full map must not display NPC ships or random events.")
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
	var hero := player.get_node("VisualRoot/HeroSprite") as Sprite2D
	var starting_position := player.position
	var starting_lunar_day := float(root.get_meta("sea_overworld_lunar_day", 0.0))
	Input.action_press("move_right")
	for _frame in range(4):
		await physics_frame
	var moving_hero_y := hero.position.y
	_expect(player.position.x > starting_position.x, "WASD/direction input did not move the sea-map ship.")
	_expect(wake.visible, "Moving ship must show the animated wake layer.")
	_expect(float(root.get_meta("sea_overworld_lunar_day", 0.0)) > starting_lunar_day, "Sailing must advance lunar time.")
	var task_objective := scene.get_node("UI/ExplorationHUD/QuestTracker/MainQuest/Objective") as Label
	_expect("靠近任意岛屿" in task_objective.text, "First map-exploration step must advance after sailing.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var screenshot_error := root.get_texture().get_image().save_png(MOVEMENT_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Sea overworld movement preview screenshot could not be saved.")
	Input.action_release("move_right")
	await physics_frame
	await physics_frame
	_expect(not wake.visible, "Ship wake must hide after movement stops.")
	_expect(is_equal_approx(hero.position.y, moving_hero_y), "The protagonist must stay attached to the same ship-deck anchor when movement stops.")
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
	var toast := scene.get_node("UI/ExplorationHUD/ComingSoonToast") as Control
	var toast_label := scene.get_node("UI/ExplorationHUD/ComingSoonToast/Message") as Label
	var task_objective := scene.get_node("UI/ExplorationHUD/QuestTracker/MainQuest/Objective") as Label
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
	var radius := float(location.get_meta("trigger_radius"))
	player.global_position = location.global_position + Vector2(radius - 30.0, 0)
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
	player.global_position = Vector2(1180, 1320)
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
		_expect(east_bay_shape != null and east_bay_shape.size.x >= 680.0, "East Bay front entry range must be widened horizontally.")
		_expect(east_bay_shape_node.position.y > 0.0, "East Bay entry range must stay on the island's front side.")
		player.global_position = east_bay.global_position + Vector2(290.0, 210.0)
		for _frame in range(3):
			await physics_frame
		_expect(prompt.visible and "东湾水寨" in location_label.text, "Expanded East Bay range must expose its entry prompt near the outer shore.")
	player.global_position = Vector2(1180, 1320)
	for _frame in range(3):
		await physics_frame
	_expect(qingyu != null, "Qingyu secret realm trigger is missing.")
	if qingyu != null:
		var qingyu_shape_node := qingyu.get_node("EntryTriggerShape") as CollisionShape2D
		var qingyu_shape := qingyu_shape_node.shape as RectangleShape2D
		_expect(qingyu_shape != null and qingyu_shape_node.position.y > 0.0, "Qingyu secret realm must use a front-only entry range.")
		player.global_position = qingyu.global_position + Vector2(0.0, -240.0)
		await physics_frame
		await physics_frame
		_expect(not prompt.visible or "青屿秘境" not in location_label.text, "Qingyu secret realm must not trigger from behind the island.")
		player.global_position = qingyu.global_position + Vector2(0.0, 270.0)
		await physics_frame
		await physics_frame
		_expect(prompt.visible and "青屿秘境" in location_label.text, "Qingyu secret realm must still trigger from its front shore.")


func _verify_east_expansion(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	var enter_button := scene.get_node("UI/Root/InteractionPrompt/EnterButton") as BaseButton
	var location_label := scene.get_node("UI/Root/InteractionPrompt/LocationName") as Label
	var toast_label := scene.get_node("UI/ExplorationHUD/ComingSoonToast/Message") as Label
	var locations := get_nodes_in_group("sea_location")
	var east_locations: Array[Area2D] = []
	for expected_name in ["红湾卫所", "南澳商港", "东极秘岛"]:
		var location := _find_location(locations, expected_name)
		_expect(location != null, "East expansion location %s is missing." % expected_name)
		if location == null:
			continue
		east_locations.append(location)
		_expect(str(location.get_meta("entry_message", "")) == "该岛屿即将开放", "%s must use the island coming-soon message." % expected_name)

	for first_index in range(east_locations.size()):
		for second_index in range(first_index + 1, east_locations.size()):
			_expect(east_locations[first_index].position.distance_to(east_locations[second_index].position) > 700.0, "East expansion islands must remain widely separated by navigable water.")

	for location in east_locations:
		player.global_position = Vector2(2800, 700)
		for _frame in range(3):
			await physics_frame
		var radius := float(location.get_meta("trigger_radius", 0.0))
		player.global_position = location.global_position + Vector2(0, radius - 35.0)
		for _frame in range(3):
			await physics_frame
		var location_name := str(location.get_meta("location_name", ""))
		_expect(prompt.visible and location_name in location_label.text, "%s must expose its entry prompt from open water." % location_name)
		enter_button.pressed.emit()
		await process_frame
		_expect(location_name in toast_label.text and "该岛屿即将开放" in toast_label.text, "%s must show the island coming-soon toast." % location_name)

	if not east_locations.is_empty() and DisplayServer.get_name() != "headless":
		var preview_location: Area2D = east_locations.back() as Area2D
		player.global_position = preview_location.global_position + Vector2(0, float(preview_location.get_meta("trigger_radius")) - 35.0)
		for _frame in range(3):
			await physics_frame
		var screenshot_error := root.get_texture().get_image().save_png(EAST_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "East expansion preview screenshot could not be saved.")

	player.global_position = Vector2(2800, 700)
	for _frame in range(3):
		await physics_frame


func _verify_auto_triggers(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var toast_label := scene.get_node("UI/ExplorationHUD/ComingSoonToast/Message") as Label
	var triggers := get_nodes_in_group("sea_auto_trigger")
	var saw_event := false
	var saw_ship := false
	for trigger_node in triggers:
		var trigger := trigger_node as Area2D
		player.global_position = Vector2(1240, 1120)
		await physics_frame
		player.global_position = trigger.global_position
		await physics_frame
		await physics_frame
		var kind := str(trigger.get_meta("trigger_kind"))
		if kind == "ship":
			saw_ship = saw_ship or "该船只开发中" in toast_label.text
		elif kind == "event":
			saw_event = saw_event or "该事件开发中" in toast_label.text
	_expect(saw_ship, "Touching a sea-map ship must automatically show its development placeholder.")
	_expect(saw_event, "Touching a sea event must automatically show its development placeholder.")
	var task_objective := scene.get_node("UI/ExplorationHUD/QuestTracker/MainQuest/Objective") as Label
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
	var radius := float(location.get_meta("trigger_radius"))
	player.global_position = location.global_position + Vector2(radius - 32.0, 0)
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
