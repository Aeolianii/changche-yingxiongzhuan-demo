extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const MERCHANT_PORTRAIT_PATH := "res://assets/sea_overworld/portraits/大地图茶叶商人.png"
const RESULT_SCREENSHOT_PATH := "res://.godot/sea_overworld_tea_merchant_result_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var purchase_scene := await _spawn_scene(true)
	await _verify_purchase_branch(purchase_scene)
	purchase_scene.queue_free()
	await process_frame

	var decline_scene := await _spawn_scene(true)
	await _verify_decline_branch(decline_scene)
	decline_scene.queue_free()
	await process_frame

	var completed_reentry := await _spawn_scene(false)
	_verify_completed_reentry(completed_reentry)
	completed_reentry.queue_free()
	await process_frame

	var restored_scene := await _spawn_scene(true)
	await _verify_resolved_state_restore(restored_scene)
	restored_scene.queue_free()
	await process_frame

	if failures.is_empty():
		print("Sea overworld tea-merchant event verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _spawn_scene(reset_world_state: bool) -> Node:
	if reset_world_state:
		root.get_node("GameState").call("reset_runtime_world_state")
	var scene := SEA_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	return scene


func _verify_purchase_branch(scene: Node) -> void:
	var merchant_ship := _verify_merchant_ship(scene)
	if merchant_ship == null:
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	player.global_position = merchant_ship.global_position
	for _frame in range(3):
		await physics_frame
	_verify_initial_dialogue(scene, dialogue, player)
	var option_box := _option_box(dialogue)
	if option_box.get_child_count() != 2:
		return
	(option_box.get_child(0) as Button).pressed.emit()
	await process_frame
	await process_frame
	await _capture_result_preview()
	_expect(dialogue.visible, "Buying tea must keep the result dialogue open.")
	_expect(scene.get_node_or_null("World/WorldMarkers/ShipTrigger0") != null, "Tea merchant ship must remain until the result dialogue ends.")
	var result_line := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	var detail_label := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DetailLabel") as RichTextLabel
	_expect(result_line.text == "多谢将军相助！", "Tea purchase dialogue and transaction details must use separate lines.")
	_expect("军饷 -100" in detail_label.get_parsed_text(), "Tea purchase detail must display the 100-pay deduction.")
	_expect("获得商品：龙井茶" in detail_label.get_parsed_text(), "Tea purchase detail must display the Longjing tea reward.")
	_expect("[color=#f2c45c]龙井茶[/color]" in detail_label.text, "Longjing tea must use yellow item highlighting.")
	_expect(detail_label.get_theme_font_size("normal_font_size") < result_line.get_theme_font_size("font_size"), "Transaction details must use smaller text than merchant dialogue.")
	_expect(is_equal_approx(result_line.custom_minimum_size.y, 34.0), "Short purchase dialogue must compact its line height so transaction details move upward.")
	_expect(detail_label.position.y - (result_line.position.y + result_line.size.y) <= 10.0, "Transaction details must sit directly on the line below merchant dialogue.")
	option_box = _option_box(dialogue)
	_expect(option_box.get_child_count() == 1, "Tea purchase result must provide one continue option.")
	if option_box.get_child_count() == 1:
		(option_box.get_child(0) as Button).pressed.emit()
		await process_frame
		await process_frame
	_expect(not dialogue.visible and player.controls_enabled, "Acknowledging the tea purchase must resume sailing.")
	_expect(scene.get_node_or_null("World/WorldMarkers/ShipTrigger0") == null, "Tea merchant ship must disappear after the purchase dialogue ends.")
	_expect(bool(scene.get("_tea_merchant_event_resolved")), "Tea purchase must resolve the merchant event.")
	var economy: Dictionary = root.get_node("GameState").call("get_economy_state")
	_expect(economy["pay"] == 700 and economy["items"].get("longjing_tea", 0) == 1, "Tea purchase must deduct pay and add one real inventory item.")


func _capture_result_preview() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(RESULT_SCREENSHOT_PATH)
	_expect(save_error == OK, "Tea merchant result preview could not be saved.")


func _verify_decline_branch(scene: Node) -> void:
	var merchant_ship := _verify_merchant_ship(scene)
	if merchant_ship == null:
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	player.global_position = merchant_ship.global_position
	for _frame in range(3):
		await physics_frame
	_verify_initial_dialogue(scene, dialogue, player)
	var option_box := _option_box(dialogue)
	if option_box.get_child_count() != 2:
		return
	(option_box.get_child(1) as Button).pressed.emit()
	await process_frame
	await process_frame
	_expect(not dialogue.visible and player.controls_enabled, "Declining the tea purchase must close dialogue and resume sailing.")
	_expect(scene.get_node_or_null("World/WorldMarkers/ShipTrigger0") == null, "Tea merchant ship must disappear after declining the purchase.")
	_expect(bool(scene.get("_tea_merchant_event_resolved")), "Declining the purchase must resolve the merchant event.")


func _verify_resolved_state_restore(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	scene.call("_restore_saved_scene_state", {
		"player_position": [player.global_position.x, player.global_position.y],
		"facing_index": 0,
		"exploration_stage": 4,
		"lunar_day": 0.0,
		"tea_merchant_event_resolved": true,
	})
	await process_frame
	await physics_frame
	_expect(bool(scene.get("_tea_merchant_event_resolved")), "Loaded tea-merchant resolution flag must be restored.")
	_expect(scene.get_node_or_null("World/WorldMarkers/ShipTrigger0") == null, "A resolved tea merchant ship must stay removed after state restoration.")
	_expect(bool(root.get_node("GameState").call("is_tea_merchant_event_completed")), "Legacy tea completion must migrate into persistent world state.")


func _verify_completed_reentry(scene: Node) -> void:
	var events: Array = scene.call("_active_random_events") as Array
	_expect(events.size() == 2, "Re-entering after tea completion must still fill both random-event slots.")
	_expect(scene.get_node_or_null("World/WorldMarkers/ShipTrigger0") == null, "A completed tea merchant must not be forced on later entries.")
	_expect(bool(scene.get("_tea_merchant_event_resolved")), "Tea completion must be read from persistent world state on entry.")


func _verify_merchant_ship(scene: Node) -> Area2D:
	var merchant_ship := scene.get_node_or_null("World/WorldMarkers/ShipTrigger0") as Area2D
	_expect(merchant_ship != null, "Tea merchant ship event node is missing.")
	if merchant_ship == null:
		return null
	_expect(_is_water_clear(merchant_ship.global_position, 19.0), "Tea merchant ship must remain approachable on open water.")
	_expect(str(merchant_ship.get_meta("display_name")) == "茶叶商船", "Nearshore ship must be renamed to Tea Merchant Ship.")
	_expect(merchant_ship.find_children("*", "Label", true, false).is_empty(), "Tea merchant ship name must not be rendered on the overworld.")
	return merchant_ship


func _verify_initial_dialogue(scene: Node, dialogue: Control, player: CharacterBody2D) -> void:
	_expect(dialogue.visible, "Approaching the tea merchant ship must open dialogue.")
	_expect(not player.controls_enabled, "Tea merchant dialogue must pause sailing.")
	var sea_map_status := root.get_node_or_null("ExplorationUI/HUD/SeaMapStatus") as Control
	_expect(sea_map_status != null and not sea_map_status.visible, "Sea map button must be hidden during tea merchant dialogue.")
	var speaker := dialogue.get_node("NamePlate/SpeakerLabel") as Label
	var line := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	var portrait := dialogue.get_node("LargeTransparentPortrait") as TextureRect
	_expect(speaker.text == "茶叶商人", "Tea merchant portrait must speak as the tea merchant.")
	_expect("姑苏新产的龙井茶" in line.text and "风暴" in line.text and "船只受损" in line.text, "Merchant dialogue must explain the Longjing tea and storm damage.")
	_expect(portrait.texture != null and portrait.texture.resource_path == MERCHANT_PORTRAIT_PATH, "Tea merchant dialogue must use the supplied merchant portrait.")
	var option_box := _option_box(dialogue)
	_expect(option_box.get_child_count() == 2, "Tea merchant dialogue must show exactly two choices.")
	if option_box.get_child_count() == 2:
		_expect((option_box.get_child(0) as Button).text == "购买龙井茶  ▶", "First tea merchant choice must be arrow-marked purchase Longjing tea.")
		_expect((option_box.get_child(1) as Button).text == "不购买  ▶", "Second tea merchant choice must be arrow-marked decline purchase.")


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
