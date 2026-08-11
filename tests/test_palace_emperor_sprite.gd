extends SceneTree

const PALACE_SCENE := preload("res://scenes/palace/palace_demo.tscn")
const SCREENSHOT_PATH := "res://.godot/palace_emperor_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var palace := PALACE_SCENE.instantiate()
	root.add_child(palace)
	current_scene = palace
	await process_frame
	await process_frame

	var emperor := palace.get_node("YSortedCharacters/Emperor") as CharacterBody2D
	var sprite := emperor.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_expect(str(emperor.get("character_key")) == "emperor", "First-act Emperor must use the emperor asset set.")
	_expect(emperor.position.is_equal_approx(Vector2(768.0, 270.0)), "Emperor root position changed.")
	_expect(sprite.scale.is_equal_approx(Vector2(0.55, 0.55)), "Emperor visual must use 0.55 scale.")
	_expect(sprite.position.is_equal_approx(Vector2(0.0, -25.0)), "Emperor foot offset changed.")
	_expect(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Emperor must use nearest filtering.")
	_expect(sprite.animation == &"idle_down" and sprite.is_playing(), "Emperor must start in idle_down.")
	for state in ["idle", "walk"]:
		for direction in ["up", "left", "down", "right"]:
			var animation_name := "%s_%s" % [state, direction]
			_expect(sprite.sprite_frames.has_animation(animation_name), "Missing %s." % animation_name)
			if sprite.sprite_frames.has_animation(animation_name):
				_expect(sprite.sprite_frames.get_frame_count(animation_name) == 4, "%s must have four frames." % animation_name)

	if DisplayServer.get_name() != "headless":
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(SCREENSHOT_PATH) == OK, "Could not save emperor preview.")

	palace.queue_free()
	await process_frame
	if failures.is_empty():
		print("Palace emperor sprite verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
