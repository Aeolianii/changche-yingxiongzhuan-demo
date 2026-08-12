extends SceneTree

const CHAPTER_TRANSITION := preload("res://scenes/ui/chapter_transition.tscn")
const SCREENSHOT_PATH := "res://.godot/chapter_transition_preview.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var transition := CHAPTER_TRANSITION.instantiate() as Control
	canvas.add_child(transition)
	if not is_equal_approx(float(transition.get("duration_seconds")), 5.97):
		push_error("Scene1-to-Scene2 chapter transition must extend its original duration by 1.5 seconds.")
		quit(1)
		return
	transition.call("play")
	await create_timer(2.75).timeout
	await process_frame

	var journey_image := transition.get_node("JourneyImage") as TextureRect
	var journey_text := transition.get_node("JourneyText") as Label
	if transition.get_node_or_null("ChapterTitle") != null or transition.get_node_or_null("ChapterSubtitle") != null:
		push_error("Removed chapter title cards must not remain in the transition scene.")
		quit(1)
		return
	if not transition.visible or journey_image.modulate.a < 0.9 or journey_text.text.is_empty():
		push_error("Chapter transition journey image did not become visible.")
		quit(1)
		return

	if DisplayServer.get_name() != "headless":
		var screenshot_error := root.get_texture().get_image().save_png(SCREENSHOT_PATH)
		if screenshot_error != OK:
			push_error("Could not save chapter transition preview screenshot.")
			quit(1)
			return

	print("Chapter transition visual verification passed: %s" % SCREENSHOT_PATH)
	quit(0)
