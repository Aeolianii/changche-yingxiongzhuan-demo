extends SceneTree

const SCENE_TWO_PATH := "res://scenes/Scene2.tscn"
const BACKGROUND_PATH := "res://assest/Paper UI/PNGs/Backgrounds/BackgroundBar.png"

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
		_verify_unchanged_layout(paper_panel, portrait, name_plate, dialogue_margin, option_box)

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
			_expect(texture_style.texture.get_size().is_equal_approx(Vector2(512.0, 144.0)), "Scene2 dialogue background must use the cropped 512x144 texture.")
			var image := texture_style.texture.get_image()
			_expect(image != null and not image.is_empty(), "Scene2 dialogue background image data is unavailable.")
			if image != null and not image.is_empty():
				for corner in [Vector2i(0, 0), Vector2i(511, 0), Vector2i(0, 143), Vector2i(511, 143)]:
					_expect(image.get_pixelv(corner).a < 0.05, "Dialogue background outside the dark border must be transparent.")
				_expect(image.get_pixel(256, 72).a > 0.95, "Dialogue paper interior must remain opaque.")
				_expect(image.get_pixel(200, 4).a > 0.95, "Dialogue dark border must remain opaque.")
		_expect(texture_style.region_rect == Rect2(), "Cropped dialogue background must stretch as a whole without a second crop.")
		_expect(is_equal_approx(texture_style.content_margin_left, 5.0), "Dialogue left content margin changed.")
		_expect(is_equal_approx(texture_style.content_margin_right, 5.0), "Dialogue right content margin changed.")
		_expect(is_equal_approx(texture_style.content_margin_top, 5.0), "Dialogue top content margin changed.")
		_expect(is_equal_approx(texture_style.content_margin_bottom, 5.0), "Dialogue bottom content margin changed.")


func _verify_unchanged_layout(paper_panel: PanelContainer, portrait: TextureRect, name_plate: PanelContainer, dialogue_margin: MarginContainer, option_box: VBoxContainer) -> void:
	_expect(paper_panel.position.is_equal_approx(Vector2(0.0, 706.0)), "Dialogue panel position changed.")
	_expect(paper_panel.size.is_equal_approx(Vector2(1344.0, 190.0)), "Dialogue panel size changed.")
	_expect(portrait.position.is_equal_approx(Vector2(884.0, 410.0)), "Right portrait position changed.")
	_expect(portrait.size.is_equal_approx(Vector2(440.0, 520.0)), "Portrait size changed.")
	_expect(name_plate.position.is_equal_approx(Vector2(1078.0, 846.0)), "Name plate position changed.")
	_expect(name_plate.size.is_equal_approx(Vector2(230.0, 44.0)), "Name plate size changed.")
	_expect(dialogue_margin.get_theme_constant("margin_left") == 54, "Dialogue left layout margin changed.")
	_expect(dialogue_margin.get_theme_constant("margin_right") == 450, "Dialogue right layout margin changed.")
	_expect(dialogue_margin.get_theme_constant("margin_top") == 16, "Dialogue top layout margin changed.")
	_expect(dialogue_margin.get_theme_constant("margin_bottom") == 18, "Dialogue bottom layout margin changed.")
	_expect(option_box.custom_minimum_size.is_equal_approx(Vector2(800.0, 50.0)), "Dialogue option area size changed.")
	_expect(name_plate.get_theme_stylebox("panel") is StyleBoxFlat, "Name plate black bar style changed.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish_with_failure(message: String) -> void:
	failures.append(message)
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("Scene2 dialogue background runtime verification passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
