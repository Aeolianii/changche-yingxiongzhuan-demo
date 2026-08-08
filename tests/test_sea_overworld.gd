extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const SCREENSHOT_PATH := "res://.godot/sea_overworld_preview.png"
const MOVEMENT_SCREENSHOT_PATH := "res://.godot/sea_overworld_movement_preview.png"

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
	await _verify_keyboard_movement(scene)
	await _verify_location_interaction(scene)
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
		"res://assets/sprites/sea_overworld/protagonist_chibi_4dir_v1.png",
		"res://assets/sprites/sea_overworld/player_ship_4dir_states_v1.png",
		"res://assets/sprites/sea_overworld/event_ships_atlas_v2.png",
		"res://assets/sprites/sea_overworld/ship_wake_fx_atlas_v1.png",
	]:
		var texture := load(asset_path) as Texture2D
		_expect(texture != null and texture.get_width() > 0, "%s could not be loaded." % asset_path)
	var hd_map := load("res://assets/backgrounds/sea_overworld/guangdong_sea_map_v2_hd.png") as Texture2D
	_expect(hd_map != null and hd_map.get_width() >= 3000, "Sea overworld map must use the high-resolution source texture.")
	var background := current_scene.get_node("World/Background") as Sprite2D
	_expect(background.scale.is_equal_approx(Vector2(0.75, 0.75)), "High-resolution map must retain the existing world footprint.")


func _verify_keyboard_movement(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var wake := player.get_node("WakeSprite") as Sprite2D
	var hero := player.get_node("VisualRoot/HeroSprite") as Sprite2D
	var starting_position := player.position
	Input.action_press("move_right")
	for _frame in range(4):
		await physics_frame
	var moving_hero_y := hero.position.y
	_expect(player.position.x > starting_position.x, "WASD/direction input did not move the sea-map ship.")
	_expect(wake.visible, "Moving ship must show the animated wake layer.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var screenshot_error := root.get_texture().get_image().save_png(MOVEMENT_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Sea overworld movement preview screenshot could not be saved.")
	Input.action_release("move_right")
	await physics_frame
	await physics_frame
	_expect(not wake.visible, "Ship wake must hide after movement stops.")
	_expect(hero.position.y <= -38.0 and hero.position.y < moving_hero_y, "The stopped protagonist must stand visibly above the ship deck.")


func _verify_location_interaction(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	var enter_button := scene.get_node("UI/Root/InteractionPrompt/PromptMargin/PromptRow/EnterButton") as Button
	var toast := scene.get_node("UI/Root/ToastPanel") as Control
	var toast_label := scene.get_node("UI/Root/ToastPanel/ToastMargin/ToastLabel") as Label
	var locations := get_nodes_in_group("sea_location")
	_expect(not locations.is_empty(), "Sea overworld must provide at least one location trigger.")
	if locations.is_empty():
		return
	var location := locations[0] as Area2D
	var outline := location.get_node_or_null("IslandOutline") as Line2D
	_expect(outline != null and outline.closed and outline.width <= 2.0, "Location highlight must be a thin closed island-edge outline.")
	_expect(location.get_node_or_null("HighlightRing") == null, "Location highlight must not use a circular ring.")
	var radius := float(location.get_meta("trigger_radius"))
	player.global_position = location.global_position + Vector2(radius - 30.0, 0)
	await physics_frame
	await physics_frame
	_expect(prompt.visible, "Approaching a location must show the highlighted interaction prompt.")
	var position_before_prompt := player.position
	await physics_frame
	_expect(player.position.is_equal_approx(position_before_prompt), "Location proximity must not automatically move or slow the stopped ship.")
	enter_button.pressed.emit()
	await process_frame
	_expect(toast.visible and "该地点即将开放" in toast_label.text, "Enter button must show the location coming-soon message.")
	player.global_position = Vector2(1180, 1320)
	for _frame in range(4):
		await physics_frame
	await process_frame
	_expect(not prompt.visible, "Leaving a location range must hide its interaction prompt.")


func _verify_auto_triggers(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var toast_label := scene.get_node("UI/Root/ToastPanel/ToastMargin/ToastLabel") as Label
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


func _capture_preview(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var enter_button := scene.get_node("UI/Root/InteractionPrompt/PromptMargin/PromptRow/EnterButton") as Button
	var locations := get_nodes_in_group("sea_location")
	if locations.is_empty():
		return
	var location := locations[0] as Area2D
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
