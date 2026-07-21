extends SceneTree

const SCENE_ONE_PATH := "res://scenes/palace/palace_demo.tscn"
const SOLDIER_PORTRAIT_PATH := "res://assets/characters/soldier/picture.png"
const GENERAL_PORTRAIT_PATH := "res://assets/characters/protagonist/picture.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var scene_resource := load(SCENE_ONE_PATH) as PackedScene
	if scene_resource == null:
		_finish_with_failure("Could not load Scene1 for portrait verification.")
		return

	var scene_one := scene_resource.instantiate()
	root.add_child(scene_one)
	current_scene = scene_one
	await process_frame

	var portrait_display := scene_one.get_node_or_null("UI/Overlay/PortraitDisplay") as Control
	var portrait_image := scene_one.get_node_or_null("UI/Overlay/PortraitDisplay/PortraitImage") as TextureRect
	var placeholder_frame := scene_one.get_node_or_null("UI/Overlay/PortraitDisplay/PlaceholderFrame") as ColorRect
	var placeholder_text := scene_one.get_node_or_null("UI/Overlay/PortraitDisplay/PlaceholderFrame/PlaceholderInner/PlaceholderText") as Label
	var name_text := scene_one.get_node_or_null("UI/Overlay/PortraitDisplay/NamePlate/NameText") as Label

	if portrait_display == null or portrait_image == null or placeholder_frame == null or placeholder_text == null or name_text == null:
		failures.append("Scene1 portrait UI nodes are incomplete.")
	elif not scene_one.has_method("_show_character_dialogue"):
		failures.append("Scene1 does not expose the character dialogue portrait behavior.")
	else:
		_verify_image_portrait(scene_one, portrait_display, portrait_image, placeholder_frame, name_text, SOLDIER_PORTRAIT_PATH, "内侍", false)
		_verify_placeholder(scene_one, portrait_display, portrait_image, placeholder_frame, placeholder_text, name_text)
		_verify_image_portrait(scene_one, portrait_display, portrait_image, placeholder_frame, name_text, GENERAL_PORTRAIT_PATH, "水师主帅", true)
		_verify_narration_hides_portrait(scene_one, portrait_display)

	scene_one.queue_free()
	await process_frame
	_finish()


func _verify_image_portrait(scene_one: Node, portrait_display: Control, portrait_image: TextureRect, placeholder_frame: ColorRect, name_text: Label, portrait_path: String, speaker: String, portrait_on_left: bool) -> void:
	var portrait := load(portrait_path) as Texture2D
	if portrait == null:
		failures.append("Could not load portrait: %s" % portrait_path)
		return

	scene_one.call("_show_character_dialogue", "立绘自动化测试", speaker, portrait, portrait_on_left)
	_expect(portrait_display.visible, "%s portrait display should be visible." % speaker)
	_expect(portrait_image.visible, "%s should show an image portrait." % speaker)
	_expect(not placeholder_frame.visible, "%s should hide the placeholder card." % speaker)
	_expect(portrait_image.texture == portrait, "%s should use the documented picture.png." % speaker)
	_expect(name_text.text == speaker, "%s name plate is incorrect." % speaker)
	_expect(is_equal_approx(portrait_display.anchor_left, 0.0 if portrait_on_left else 1.0), "%s portrait is on the wrong side." % speaker)


func _verify_placeholder(scene_one: Node, portrait_display: Control, portrait_image: TextureRect, placeholder_frame: ColorRect, placeholder_text: Label, name_text: Label) -> void:
	scene_one.call("_show_character_dialogue", "皇帝占位测试", "皇帝", null, false, "帝")
	_expect(portrait_display.visible, "Emperor placeholder should be visible.")
	_expect(not portrait_image.visible, "Emperor placeholder should not show an image portrait.")
	_expect(placeholder_frame.visible, "Emperor placeholder card should be visible.")
	_expect(placeholder_text.text == "帝", "Emperor placeholder glyph should be 帝.")
	_expect(name_text.text == "皇帝", "Emperor name plate is incorrect.")
	_expect(is_equal_approx(portrait_display.anchor_left, 1.0), "Emperor placeholder should be on the right.")


func _verify_narration_hides_portrait(scene_one: Node, portrait_display: Control) -> void:
	scene_one.call("_show_dialogue", "【旁白】\n立绘应隐藏。")
	_expect(not portrait_display.visible, "Narration should hide the previous character portrait.")
	scene_one.call("_hide_dialogue")
	_expect(not portrait_display.visible, "Closing dialogue should keep the portrait hidden.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish_with_failure(message: String) -> void:
	failures.append(message)
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("Scene1 portrait runtime verification passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
