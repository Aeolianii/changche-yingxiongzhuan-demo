extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const SALT_MERCHANT_PORTRAIT_PATH := "res://assets/sea_overworld/portraits/大地图私盐商人.png"
const RESULT_SCREENSHOT_PATH := "res://.godot/sea_overworld_salt_merchant_result_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var seize_scene := await _spawn_scene()
	await _verify_choice_branch(seize_scene, 0, "查获物品：私盐", true)
	seize_scene.queue_free()
	await process_frame

	var bribe_scene := await _spawn_scene()
	await _verify_choice_branch(bribe_scene, 1, "军饷 +800", false)
	bribe_scene.queue_free()
	await process_frame

	var release_scene := await _spawn_scene()
	await _verify_choice_branch(release_scene, 2, "商船离开，无事发生", false)
	release_scene.queue_free()
	await process_frame

	var restored_scene := await _spawn_scene()
	await _verify_entry_reroll_ignores_old_resolution(restored_scene)
	restored_scene.queue_free()
	await process_frame

	if failures.is_empty():
		print("Sea overworld salt-merchant event verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _spawn_scene() -> Node:
	var scene := SEA_SCENE.instantiate()
	scene.set("_random_event_seed_override", 1)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	return scene


func _verify_choice_branch(scene: Node, option_index: int, expected_detail: String, expects_salt_highlight: bool) -> void:
	var salt_ship := _verify_salt_ship_setup(scene)
	if salt_ship == null:
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	player.global_position = salt_ship.global_position + Vector2(74, 0)
	for _frame in range(3):
		await physics_frame
	_expect(not dialogue.visible, "Salt merchant dialogue must not trigger before the player reaches the ship's immediate vicinity.")
	player.global_position = salt_ship.global_position
	for _frame in range(3):
		await physics_frame
	_verify_initial_dialogue(scene, dialogue, player)
	var option_box := _option_box(dialogue)
	if option_box.get_child_count() != 3:
		return
	(option_box.get_child(option_index) as Button).pressed.emit()
	await process_frame
	await process_frame
	if option_index == 0:
		await _capture_result_preview()
	_expect(dialogue.visible, "Salt merchant choice must show a result before the event closes.")
	_expect(scene.get_node_or_null("World/WorldMarkers/SaltMerchantShip") != null, "Salt merchant ship must remain until its result dialogue ends.")
	var detail_label := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DetailLabel") as RichTextLabel
	_expect(expected_detail in detail_label.get_parsed_text(), "Salt merchant result must display: %s." % expected_detail)
	if expects_salt_highlight:
		_expect("[color=#f2c45c]私盐[/color]" in detail_label.text, "Confiscated private salt must use yellow item highlighting.")
	option_box = _option_box(dialogue)
	_expect(option_box.get_child_count() == 1, "Salt merchant result must provide one continue option.")
	if option_box.get_child_count() == 1:
		(option_box.get_child(0) as Button).pressed.emit()
		await process_frame
		await process_frame
	_expect(not dialogue.visible and player.controls_enabled, "Finishing a salt merchant result must resume sailing.")
	_expect(scene.get_node_or_null("World/WorldMarkers/SaltMerchantShip") == null, "Salt merchant ship must disappear after the result dialogue ends.")
	_expect(bool(scene.get("_salt_merchant_event_resolved")), "Every salt merchant choice must resolve the event.")


func _verify_salt_ship_setup(scene: Node) -> Area2D:
	var salt_ship := scene.get_node_or_null("World/WorldMarkers/SaltMerchantShip") as Area2D
	var tea_ship := scene.get_node_or_null("World/WorldMarkers/ShipTrigger0") as Area2D
	var crate := scene.get_node_or_null("World/WorldMarkers/DriftEvent") as Area2D
	_expect(salt_ship != null and tea_ship != null and crate == null, "A salt-seeded map must start with tea and salt as its two random events.")
	if salt_ship == null or tea_ship == null:
		return null
	var spawn_origin: Vector2 = salt_ship.get_meta("spawn_origin", Vector2.ZERO)
	_expect(salt_ship.position.distance_to(spawn_origin) <= 240.0, "Salt merchant patrol must stay within its pirate-matched 240-unit range.")
	_expect(_is_water_clear(salt_ship.global_position, 48.0), "Salt merchant ship must stay clear of land.")
	_expect(spawn_origin.distance_to(tea_ship.position) >= 360.0, "Salt and tea merchant refresh points must respect random-event separation.")
	_expect(str(salt_ship.get_meta("display_name")) == "私盐商船", "Salt ship event must retain its private event identity.")
	_expect(salt_ship.find_children("*", "Label", true, false).is_empty(), "Salt ship identity must not be shown before interaction.")
	var trigger_shapes := salt_ship.find_children("*", "CollisionShape2D", false, false)
	var trigger_shape := trigger_shapes[0] as CollisionShape2D if not trigger_shapes.is_empty() else null
	var trigger_circle := trigger_shape.shape as CircleShape2D if trigger_shape != null else null
	_expect(trigger_circle != null and is_equal_approx(trigger_circle.radius, 48.0), "Salt merchant interaction radius must stay tightly wrapped around the ship.")
	var salt_sprite := salt_ship.get_node("ShipSprite") as Sprite2D
	var tea_sprite := tea_ship.get_node("ShipSprite") as Sprite2D
	var salt_texture := salt_sprite.texture as AtlasTexture
	var tea_texture := tea_sprite.texture as AtlasTexture
	_expect(salt_texture != null and tea_texture != null and salt_texture.atlas.resource_path == tea_texture.atlas.resource_path and salt_texture.region == tea_texture.region, "Salt and tea merchants must share exactly the same ship appearance.")
	return salt_ship


func _verify_initial_dialogue(scene: Node, dialogue: Control, player: CharacterBody2D) -> void:
	_expect(dialogue.visible, "Approaching the salt merchant ship must open dialogue.")
	_expect(not player.controls_enabled, "Salt merchant dialogue must pause sailing.")
	var map_status := root.get_node_or_null("ExplorationUI/HUD/SeaMapStatus") as Control
	_expect(map_status != null and not map_status.visible, "Sea map button must hide during salt merchant dialogue.")
	var speaker := dialogue.get_node("NamePlate/SpeakerLabel") as Label
	var line := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	var portrait := dialogue.get_node("LargeTransparentPortrait") as TextureRect
	_expect(speaker.text == "私盐商人", "Salt merchant portrait must speak as the private-salt merchant.")
	_expect("盐货" in line.text and "通融" in line.text and "薄礼" in line.text, "Salt merchant dialogue must hint at illegal salt and a bribe.")
	_expect(portrait.texture != null and portrait.texture.resource_path == SALT_MERCHANT_PORTRAIT_PATH, "Salt merchant dialogue must use the supplied portrait from the overworld portrait folder.")
	var option_box := _option_box(dialogue)
	_expect(option_box.get_child_count() == 3, "Salt merchant dialogue must show exactly three choices.")
	if option_box.get_child_count() == 3:
		_expect((option_box.get_child(0) as Button).text == "查扣私盐  ▶", "First salt merchant choice must be arrow-marked confiscation.")
		_expect((option_box.get_child(1) as Button).text == "收下贿赂  ▶", "Second salt merchant choice must be arrow-marked bribe acceptance.")
		_expect((option_box.get_child(2) as Button).text == "放行商船  ▶", "Third salt merchant choice must be arrow-marked release.")


func _verify_entry_reroll_ignores_old_resolution(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	scene.call("_restore_saved_scene_state", {
		"player_position": [player.global_position.x, player.global_position.y],
		"facing_index": 0,
		"exploration_stage": 4,
		"lunar_day": 0.0,
		"salt_merchant_event_resolved": true,
	})
	await process_frame
	await physics_frame
	_expect(not bool(scene.get("_salt_merchant_event_resolved")), "Old salt completion flags must reset when a new sea-map entry rerolls events.")
	_expect(scene.get_node_or_null("World/WorldMarkers/SaltMerchantShip") != null, "A private-salt event may be freshly rolled again on entry.")


func _capture_result_preview() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(RESULT_SCREENSHOT_PATH)
	_expect(save_error == OK, "Salt merchant result preview could not be saved.")


func _option_box(dialogue: Control) -> VBoxContainer:
	return dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer


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
