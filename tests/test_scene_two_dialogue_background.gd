extends SceneTree

const SCENE_TWO_PATH := "res://scenes/Scene2.tscn"
const BACKGROUND_PATH := "res://assets/ui/dialogue/ink_dialogue_backdrop.png"
const NAMEPLATE_PATH := "res://assets/ui/dialogue/ink_speaker_nameplate.png"
const SCREENSHOT_PATH := "res://.godot/ink_dialogue_scene2_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var scene_resource := load(SCENE_TWO_PATH) as PackedScene
	if scene_resource == null:
		_finish_with_failure("Could not load Scene2 for dialogue background verification.")
		return

	var scene_two := scene_resource.instantiate()
	root.add_child(scene_two)
	current_scene = scene_two
	await process_frame

	var paper_panel := scene_two.get_node_or_null("UI/DialoguePanel/FullWidthPaperDialogueBox") as PanelContainer
	var portrait := scene_two.get_node_or_null("UI/DialoguePanel/LargeTransparentPortrait") as TextureRect
	var name_plate := scene_two.get_node_or_null("UI/DialoguePanel/NamePlate") as PanelContainer
	var dialogue_margin := scene_two.get_node_or_null("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin") as MarginContainer
	var option_box := scene_two.get_node_or_null("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer

	if paper_panel == null or portrait == null or name_plate == null or dialogue_margin == null or option_box == null:
		failures.append("Scene2 dialogue UI nodes are incomplete.")
	else:
		_verify_background(paper_panel)
		_verify_ink_layout(paper_panel, portrait, name_plate, dialogue_margin, option_box)
		if DisplayServer.get_name() != "headless":
			await _capture_preview(scene_two, portrait, name_plate)

	scene_two.queue_free()
	await process_frame
	_finish()


func _verify_background(paper_panel: PanelContainer) -> void:
	var style := paper_panel.get_theme_stylebox("panel")
	_expect(style is StyleBoxTexture, "Scene2 dialogue panel must use StyleBoxTexture.")
	if style is StyleBoxTexture:
		var texture_style := style as StyleBoxTexture
		_expect(texture_style.texture != null, "Scene2 dialogue background texture is missing.")
		if texture_style.texture != null:
			_expect(texture_style.texture.resource_path == BACKGROUND_PATH, "Scene2 dialogue panel uses the wrong background texture.")
			_expect(texture_style.texture.get_size().is_equal_approx(Vector2(1491.0, 354.0)), "Scene2 dialogue background must use the generated cropped ink texture.")
			var image := texture_style.texture.get_image()
			_expect(image != null and not image.is_empty(), "Scene2 dialogue background image data is unavailable.")
			if image != null and not image.is_empty():
				for corner in [Vector2i(0, 0), Vector2i(1490, 0), Vector2i(0, 353), Vector2i(1490, 353)]:
					_expect(image.get_pixelv(corner).a < 0.05, "Dialogue ink texture corners must be transparent.")
				_expect(image.get_pixel(745, 177).a > 0.9, "Dialogue ink center must remain readable for text.")
		_expect(texture_style.region_rect == Rect2(), "Dialogue ink background must stretch as a whole without a second crop.")
		_expect(is_equal_approx(texture_style.content_margin_left, 24.0), "Dialogue left content margin is incorrect.")
		_expect(is_equal_approx(texture_style.content_margin_right, 24.0), "Dialogue right content margin is incorrect.")
		_expect(is_equal_approx(texture_style.content_margin_top, 18.0), "Dialogue top content margin is incorrect.")
		_expect(is_equal_approx(texture_style.content_margin_bottom, 18.0), "Dialogue bottom content margin is incorrect.")
	_expect(is_equal_approx(paper_panel.self_modulate.a, 0.88), "Dialogue ink backdrop must be slightly transparent.")


func _verify_ink_layout(paper_panel: PanelContainer, portrait: TextureRect, name_plate: PanelContainer, dialogue_margin: MarginContainer, option_box: VBoxContainer) -> void:
	_expect(paper_panel.position.is_equal_approx(Vector2(-160.0, 536.0)), "Dialogue ink panel position is incorrect.")
	_expect(paper_panel.size.is_equal_approx(Vector2(1664.0, 360.0)), "Dialogue ink panel must cover dialogue text and options.")
	_expect(portrait.position.is_equal_approx(Vector2(884.0, 410.0)), "Right portrait position changed.")
	_expect(portrait.size.is_equal_approx(Vector2(440.0, 520.0)), "Portrait size changed.")
	_expect(name_plate.position.is_equal_approx(Vector2(1060.0, 830.0)), "NPC name brush position is incorrect.")
	_expect(name_plate.size.is_equal_approx(Vector2(260.0, 58.0)), "NPC name brush size is incorrect.")
	_expect(dialogue_margin.get_theme_constant("margin_left") == 246, "Dialogue left layout margin changed.")
	_expect(dialogue_margin.get_theme_constant("margin_right") == 608, "Dialogue right layout margin changed.")
	_expect(dialogue_margin.get_theme_constant("margin_top") == 166, "Dialogue top layout margin changed.")
	_expect(dialogue_margin.get_theme_constant("margin_bottom") == 18, "Dialogue bottom layout margin changed.")
	_expect(option_box.custom_minimum_size.is_equal_approx(Vector2(800.0, 50.0)), "Dialogue option area size changed.")
	var name_style := name_plate.get_theme_stylebox("panel")
	_expect(name_style is StyleBoxTexture, "Name plate must use the generated ink brush texture.")
	if name_style is StyleBoxTexture:
		_expect((name_style as StyleBoxTexture).texture.resource_path == NAMEPLATE_PATH, "Name plate uses the wrong ink texture.")


func _capture_preview(scene_two: Node, portrait: TextureRect, name_plate: PanelContainer) -> void:
	var dialogue_panel := scene_two.get_node("UI/DialoguePanel") as Control
	var exploration_hud := scene_two.get_node("UI/ExplorationHUD") as Control
	var player := scene_two.get_node("World/Actors/Player") as CharacterBody2D
	var soldier := scene_two.get_node("World/Actors/Npcs/MagistrateLeftGuard") as Node2D
	player.global_position = soldier.global_position + Vector2(0, 54)
	await physics_frame
	await physics_frame
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	scene_two._unhandled_input(interact)
	await process_frame
	_expect(portrait.visible and name_plate.visible, "Soldier dialogue preview did not show its portrait and name plate.")
	exploration_hud.hide()
	await process_frame
	var error := root.get_texture().get_image().save_png(SCREENSHOT_PATH)
	_expect(error == OK, "Could not save Scene2 ink dialogue preview.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish_with_failure(message: String) -> void:
	failures.append(message)
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("Scene2 ink dialogue runtime verification passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
