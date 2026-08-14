extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const CRATE_TEXTURE := preload("res://assets/sprites/sea_overworld/drifting_supply_crate_v1.png")
const SOLDIER_PORTRAIT_PATH := "res://assets/characters/soldier/picture.png"
const DIALOGUE_BACKGROUND_PATH := "res://assets/ui/dialogue/ink_dialogue_backdrop.png"
const DIALOGUE_NAMEPLATE_PATH := "res://assets/ui/dialogue/ink_speaker_nameplate.png"
const CRATE_SCREENSHOT_PATH := "res://.godot/sea_overworld_crate_preview.png"
const CRATE_DIALOGUE_SCREENSHOT_PATH := "res://.godot/sea_overworld_crate_dialogue_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_verify_crate_asset()
	var salvage_scene := await _spawn_scene()
	await _verify_salvage_branch(salvage_scene)
	salvage_scene.queue_free()
	await process_frame

	var ignore_scene := await _spawn_scene()
	await _verify_ignore_branch(ignore_scene)
	ignore_scene.queue_free()
	await process_frame

	var restored_scene := await _spawn_scene()
	await _verify_entry_reroll_ignores_old_resolution(restored_scene)
	restored_scene.queue_free()
	await process_frame

	if failures.is_empty():
		print("Sea overworld drifting-crate event verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _spawn_scene() -> Node:
	var scene := SEA_SCENE.instantiate()
	scene.set("_random_event_seed_override", 0)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	return scene


func _verify_crate_asset() -> void:
	var image := CRATE_TEXTURE.get_image()
	_expect(image != null and image.get_size() == Vector2i(512, 512), "Drifting-crate texture must be a 512x512 production asset.")
	if image == null:
		return
	for corner in [Vector2i(0, 0), Vector2i(511, 0), Vector2i(0, 511), Vector2i(511, 511)]:
		_expect(image.get_pixelv(corner).a <= 0.01, "Drifting-crate texture corners must be transparent.")
	_expect(image.get_pixel(256, 256).a >= 0.95, "Drifting-crate texture must retain an opaque central subject.")


func _verify_salvage_branch(scene: Node) -> void:
	var crate := _verify_crate_visual(scene)
	if crate == null:
		return
	await _capture_crate_preview(scene, crate)
	var player := scene.get_node("World/Player") as CharacterBody2D
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	var sea_map_status := root.get_node_or_null("ExplorationUI/HUD/SeaMapStatus") as Control
	_expect(sea_map_status != null, "Sea map button container must exist on the overworld HUD.")
	if sea_map_status == null:
		return
	player.global_position = crate.global_position
	for _frame in range(3):
		await physics_frame
	_verify_initial_dialogue(dialogue, player, sea_map_status)
	await _capture_dialogue_preview()
	var option_box := _option_box(dialogue)
	if option_box.get_child_count() != 2:
		return
	(option_box.get_child(0) as Button).pressed.emit()
	await process_frame
	await process_frame
	_expect(scene.get_node_or_null("World/WorldMarkers/DriftEvent") == null, "Salvaging must remove the drifting crate immediately.")
	_expect(dialogue.visible, "Salvaging must keep the dialogue open for the resource result.")
	_expect(not sea_map_status.visible, "Sea map button must remain hidden while the salvage result dialogue is open.")
	var result_text := (dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label).text
	_expect("铁石 +100" in result_text and "木材 +100" in result_text and "军饷 +1000" in result_text, "Salvage result must show all three exact resource gains.")
	_expect(not player.controls_enabled, "Player movement must remain locked until the salvage result is acknowledged.")
	option_box = _option_box(dialogue)
	_expect(option_box.get_child_count() == 1, "Salvage result must provide one continue option.")
	if option_box.get_child_count() == 1:
		(option_box.get_child(0) as Button).pressed.emit()
		await process_frame
	_expect(not dialogue.visible and player.controls_enabled, "Acknowledging the salvage result must resume sailing.")
	_expect(sea_map_status.visible, "Sea map button must return after the salvage dialogue closes.")


func _capture_crate_preview(scene: Node, crate: Area2D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	player.global_position = crate.global_position + Vector2(-150, 110)
	(scene.get_node("World/Player/Camera2D") as Camera2D).reset_smoothing()
	for _frame in range(4):
		await physics_frame
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(CRATE_SCREENSHOT_PATH)
	_expect(save_error == OK, "Drifting-crate in-scene preview could not be saved.")


func _capture_dialogue_preview() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(CRATE_DIALOGUE_SCREENSHOT_PATH)
	_expect(save_error == OK, "Drifting-crate dialogue preview could not be saved.")


func _verify_ignore_branch(scene: Node) -> void:
	var crate := _verify_crate_visual(scene)
	if crate == null:
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	var sea_map_status := root.get_node_or_null("ExplorationUI/HUD/SeaMapStatus") as Control
	_expect(sea_map_status != null, "Sea map button container must exist on the overworld HUD.")
	if sea_map_status == null:
		return
	player.global_position = crate.global_position
	for _frame in range(3):
		await physics_frame
	_verify_initial_dialogue(dialogue, player, sea_map_status)
	var option_box := _option_box(dialogue)
	if option_box.get_child_count() != 2:
		return
	(option_box.get_child(1) as Button).pressed.emit()
	await process_frame
	await process_frame
	_expect(scene.get_node_or_null("World/WorldMarkers/DriftEvent") == null, "Ignoring must remove the drifting crate.")
	_expect(not dialogue.visible and player.controls_enabled, "Ignoring the crate must close dialogue and resume sailing.")
	_expect(sea_map_status.visible, "Sea map button must return after the ignored crate dialogue closes.")


func _verify_entry_reroll_ignores_old_resolution(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	scene.call("_restore_saved_scene_state", {
		"player_position": [player.global_position.x, player.global_position.y],
		"facing_index": 0,
		"exploration_stage": 4,
		"lunar_day": 0.0,
		"crate_event_resolved": true,
	})
	await process_frame
	await physics_frame
	_expect(not bool(scene.get("_crate_event_resolved")), "Old crate completion flags must reset when a new sea-map entry rerolls events.")
	_expect(scene.get_node_or_null("World/WorldMarkers/DriftEvent") != null, "A drifting crate may be freshly rolled again on entry.")


func _verify_crate_visual(scene: Node) -> Area2D:
	var crate := scene.get_node_or_null("World/WorldMarkers/DriftEvent") as Area2D
	_expect(crate != null, "Drifting-crate event node is missing.")
	if crate == null:
		return null
	var visual := crate.get_node("EventVisual") as Node2D
	var sprite := visual.get_node_or_null("CrateSprite") as Sprite2D
	_expect(sprite != null and sprite.texture.resource_path == CRATE_TEXTURE.resource_path, "Drifting-crate event must use the generated crate sprite.")
	_expect(visual.find_children("*", "Label", true, false).is_empty(), "Drifting-crate map visual must not show its four-character name.")
	return crate


func _verify_initial_dialogue(dialogue: Control, player: CharacterBody2D, sea_map_status: Control) -> void:
	_expect(dialogue.visible, "Touching the crate must open the field dialogue.")
	_expect(not player.controls_enabled, "Touching the crate must pause sailing.")
	_expect(not sea_map_status.visible, "Sea map button must be hidden while the crate dialogue is open.")
	var speaker := dialogue.get_node("NamePlate/SpeakerLabel") as Label
	var line := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	var portrait := dialogue.get_node("LargeTransparentPortrait") as TextureRect
	var paper_style := (dialogue.get_node("FullWidthPaperDialogueBox") as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture
	var name_style := (dialogue.get_node("NamePlate") as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture
	_expect(speaker.text == "水师士兵", "Crate report must use the soldier speaker name.")
	_expect("禀将军" in line.text and "漂流而来的木箱" in line.text, "Soldier report must describe the discovered drifting crate.")
	_expect(portrait.texture != null and portrait.texture.resource_path == SOLDIER_PORTRAIT_PATH, "Crate report must reuse Scene2's soldier portrait.")
	_expect(paper_style != null and paper_style.texture.resource_path == DIALOGUE_BACKGROUND_PATH, "Crate report must reuse Scene2's paper dialogue backdrop.")
	_expect(name_style != null and name_style.texture.resource_path == DIALOGUE_NAMEPLATE_PATH, "Crate report must reuse Scene2's speaker nameplate.")
	var option_box := _option_box(dialogue)
	_expect(option_box.get_child_count() == 2, "Crate report must show exactly two choices.")
	if option_box.get_child_count() == 2:
		_expect((option_box.get_child(0) as Button).text == "打捞上来  ▶", "First crate choice must be arrow-marked salvage.")
		_expect((option_box.get_child(1) as Button).text == "置之不理  ▶", "Second crate choice must be arrow-marked ignore.")


func _option_box(dialogue: Control) -> VBoxContainer:
	return dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
