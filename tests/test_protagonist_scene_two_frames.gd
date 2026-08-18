extends SceneTree

const SCENE_TWO := preload("res://scenes/Scene2.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_two := SCENE_TWO.instantiate()
	root.add_child(scene_two)
	current_scene = scene_two
	await process_frame
	await process_frame

	var sprite := scene_two.get_node("World/Actors/Player/Sprite") as AnimatedSprite2D
	_expect(sprite != null, "Scene 2 player sprite is missing.")
	if sprite != null:
		for state in ["idle", "walk"]:
			for direction in ["down", "left", "right", "up"]:
				var animation_name := "%s_%s" % [state, direction]
				_expect(sprite.sprite_frames.has_animation(animation_name), "Missing %s." % animation_name)
				if sprite.sprite_frames.has_animation(animation_name):
					_expect(sprite.sprite_frames.get_frame_count(animation_name) == 4, "%s must have four frames in Scene 2." % animation_name)

	scene_two.queue_free()
	await process_frame
	if failures.is_empty():
		print("Scene 2 protagonist frame verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
