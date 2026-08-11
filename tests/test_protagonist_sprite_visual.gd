extends SceneTree

const PALACE_SCENE := preload("res://scenes/palace/palace_demo.tscn")
const SCREENSHOT_PATH := "res://.godot/protagonist_sprite_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var palace := PALACE_SCENE.instantiate()
	root.add_child(palace)
	current_scene = palace
	await process_frame
	await process_frame

	var player := palace.get_node("YSortedCharacters/Player") as CharacterBody2D
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	player.set("controls_enabled", false)
	player.position = Vector2(768.0, 610.0)
	palace.get_node("UI").visible = false

	_expect(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Player must use nearest filtering.")
	_expect(sprite.scale.is_equal_approx(Vector2.ONE), "Player must keep native 1.0 scale.")
	_expect(sprite.position.is_equal_approx(Vector2(0.0, -25.0)), "Player foot offset changed.")
	for state in ["idle", "walk"]:
		for direction in ["up", "left", "down", "right"]:
			var animation_name := "%s_%s" % [state, direction]
			_expect(sprite.sprite_frames.has_animation(animation_name), "Missing %s." % animation_name)
			if sprite.sprite_frames.has_animation(animation_name):
				_expect(sprite.sprite_frames.get_frame_count(animation_name) == 4, "%s must have four frames." % animation_name)
				var texture := sprite.sprite_frames.get_frame_texture(animation_name, 0)
				_expect(texture != null and texture.get_size().is_equal_approx(Vector2(64.0, 64.0)), "%s must use 64x64 frames." % animation_name)

	if DisplayServer.get_name() != "headless":
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(SCREENSHOT_PATH) == OK, "Could not save protagonist preview.")

	palace.queue_free()
	await process_frame
	if failures.is_empty():
		print("Protagonist sprite visual verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
