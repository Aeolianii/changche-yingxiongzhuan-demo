extends SceneTree

const SCENE_ONE_PATH := "res://scenes/palace/palace_demo.tscn"
const SCENE_TWO_NAME := "Scene2"
const IMPERIAL_EDICT_STATE := 6

var failures: Array[String] = []


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	await _verify_transition(false, 3.4, "automatic timer")
	await _verify_transition(true, 1.0, "skip button")

	if failures.is_empty():
		print("Scene transition runtime verification passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_transition(skip_wait: bool, wait_seconds: float, label: String) -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame

	var scene_resource := load(SCENE_ONE_PATH) as PackedScene
	if scene_resource == null:
		failures.append("Could not load Scene1 for %s transition test." % label)
		return

	var scene_one := scene_resource.instantiate()
	root.add_child(scene_one)
	current_scene = scene_one
	await process_frame
	var chapter_transition := scene_one.get_node("UI/Overlay/ChapterTransition")
	chapter_transition.set("duration_scale", 0.03)

	# Enter the final documented state without replaying the full dialogue chain.
	scene_one.set("story_state", IMPERIAL_EDICT_STATE)
	scene_one.call("_on_continue_pressed")
	if skip_wait:
		scene_one.call("_on_continue_pressed")

	await create_timer(wait_seconds).timeout
	await process_frame

	if current_scene == null or current_scene.name != SCENE_TWO_NAME:
		failures.append("Scene2 was not active after the %s transition." % label)
		return

	var dialogue_panel := current_scene.get_node("UI/DialoguePanel") as Control
	var speaker_label := current_scene.get_node("UI/DialoguePanel/NamePlate/SpeakerLabel") as Label
	var exploration_hud := root.get_node("ExplorationUI/HUD") as Control
	if not dialogue_panel.visible or speaker_label.text != "水师副将":
		failures.append("Scene2 did not open with the deputy greeting after the %s transition." % label)
	if exploration_hud.visible:
		failures.append("Exploration HUD was visible during the deputy greeting after the %s transition." % label)

	var space_event := InputEventKey.new()
	space_event.physical_keycode = KEY_SPACE
	space_event.pressed = true
	current_scene.call("_unhandled_input", space_event)
	await process_frame
	current_scene.call("_unhandled_input", space_event)
	await process_frame

	var main_task := exploration_hud.get_node("QuestTracker/MainQuest/TaskName") as Label
	if dialogue_panel.visible:
		failures.append("Deputy greeting did not close after the %s transition." % label)
	if not exploration_hud.visible:
		failures.append("Exploration HUD did not return after the %s deputy greeting." % label)
	if main_task.text != "巡视水师驻地":
		failures.append("Scene2 main task was not activated after the %s deputy greeting." % label)
