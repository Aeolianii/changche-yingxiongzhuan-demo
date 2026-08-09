extends SceneTree

const SCENE_TWO := preload("res://scenes/Scene2.tscn")
const SCENE_TWO_ENTRY_META := "sea_overworld_from_scene_two"
const RETURN_TO_SCENE_TWO_META := "scene_two_return_from_sea_overworld"
const LOADING_SCREENSHOT_PATH := "res://.godot/lingnan_loading_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.remove_meta(SCENE_TWO_ENTRY_META)
	root.remove_meta(RETURN_TO_SCENE_TWO_META)
	var scene_two := SCENE_TWO.instantiate() as Node2D
	root.add_child(scene_two)
	current_scene = scene_two
	await process_frame
	await physics_frame

	scene_two.set("_patrol_task_stage", 5)
	scene_two.call("_update_task_hud")
	var task_name := scene_two.get_node("UI/ExplorationHUD/QuestTracker/MainQuest/TaskName") as Label
	_expect(task_name.text == "和县令对话探索岭南海域", "Post-drill Scene2 task was not prepared for sea departure.")

	var loading := scene_two.get_node("UI/SceneLoadingTransition") as SceneLoadingTransition
	_expect(is_equal_approx(loading.minimum_duration, 1.0), "Scene loading transition must default to a one-second minimum duration.")
	await _interact_with(scene_two, "World/Actors/Npcs/GuangzhouCountyMagistrate")
	var option_box := _option_box(scene_two)
	_expect(option_box.get_child_count() == 2, "Magistrate sea-departure dialogue choices are missing.")
	if option_box.get_child_count() < 1:
		_finish()
		return
	var departure_started_at := Time.get_ticks_msec()
	(option_box.get_child(0) as Button).pressed.emit()
	_expect(loading.visible and (loading.get_node("LoadingText") as Label).text == "正在进入大地图", "Scene2 departure must show the enter-overworld loading message immediately.")
	await create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless":
		var screenshot_error := root.get_texture().get_image().save_png(LOADING_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Lingnan loading preview screenshot could not be saved.")

	var sea_scene := await _wait_for_scene("SeaOverworld")
	_expect(sea_scene != null, "Scene2 did not transition to the sea overworld.")
	_expect(Time.get_ticks_msec() - departure_started_at >= 950, "Enter-overworld loading screen must remain visible for at least one second.")
	if sea_scene == null:
		_finish()
		return
	var sea_player := sea_scene.get_node("World/Player") as CharacterBody2D
	_expect(sea_player.global_position.is_equal_approx(Vector2(1300, 850)), "Sea-overworld entry must spawn on the collision-free water in front of South Sea Harbor.")
	await physics_frame
	await physics_frame
	var prompt := sea_scene.get_node("UI/Root/InteractionPrompt") as Control
	var location_name := sea_scene.get_node("UI/Root/InteractionPrompt/LocationName") as Label
	_expect(prompt.visible and "南海军港" in location_name.text, "South Sea Harbor entry prompt must be available at the Scene2 spawn point.")

	var return_loading := sea_scene.get_node("UI/SceneLoadingTransition") as SceneLoadingTransition
	_expect(is_equal_approx(return_loading.minimum_duration, 1.0), "Return loading transition must also default to one second.")
	var enter_button := sea_scene.get_node("UI/Root/InteractionPrompt/EnterButton") as BaseButton
	var return_started_at := Time.get_ticks_msec()
	enter_button.pressed.emit()
	_expect(return_loading.visible and (return_loading.get_node("LoadingText") as Label).text == "正在进入南海军港", "South Sea Harbor return must show the correct loading message immediately.")

	var returned_scene := await _wait_for_scene("Scene2")
	_expect(returned_scene != null, "South Sea Harbor did not return to Scene2.")
	_expect(Time.get_ticks_msec() - return_started_at >= 950, "Return-to-harbor loading screen must remain visible for at least one second.")
	if returned_scene == null:
		_finish()
		return
	await physics_frame
	var returned_task := returned_scene.get_node("UI/ExplorationHUD/QuestTracker/MainQuest/TaskName") as Label
	var returned_objective := returned_scene.get_node("UI/ExplorationHUD/QuestTracker/MainQuest/Objective") as Label
	_expect(returned_task.text == "和县令对话探索岭南海域", "Returning to Scene2 must preserve the completed patrol-and-drill task state.")
	_expect(returned_objective.text == "与广州县令交谈，选择是否立即出发", "Returning to Scene2 must not restore patrol or drill objectives.")
	_expect(not (returned_scene.get_node("UI/DialoguePanel") as Control).visible, "Returning from the sea must not replay the Scene2 arrival dialogue.")
	_expect(int(returned_scene.get("_patrol_task_stage")) == 5, "Returning from the sea must restore the post-drill task stage.")
	_expect((returned_scene.get("_heard_soldier_reports") as Dictionary).size() == 2, "Returning from the sea must keep both patrol reports completed.")

	var hud := returned_scene.get_node("UI/ExplorationHUD") as Control
	var quest_button := hud.find_child("QuestButton", true, false) as Button
	quest_button.pressed.emit()
	await process_frame
	var quest_screen := hud.get_node("QuestScreen") as Control
	var selected_title := quest_screen.get_node("SelectedQuestTitle") as RichTextLabel
	var steps := quest_screen.get_node("QuestStepsScroll/QuestSteps") as VBoxContainer
	_expect(quest_screen.visible and "和县令对话探索岭南海域" in selected_title.text, "Returned Scene2 quest screen must retain the sea-exploration task.")
	_expect(steps.get_child_count() == 3, "Sea-exploration quest screen must show completed patrol, completed drill, and departure steps.")

	_finish()


func _interact_with(scene: Node2D, actor_path: String) -> void:
	var player := scene.get_node("World/Actors/Player") as CharacterBody2D
	var actor := scene.get_node(actor_path) as Node2D
	player.global_position = actor.global_position + Vector2(0, 54)
	await physics_frame
	await physics_frame
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	scene._unhandled_input(event)
	await process_frame


func _option_box(scene: Node) -> VBoxContainer:
	return scene.get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer


func _wait_for_scene(expected_name: String) -> Node:
	for _attempt in range(150):
		await create_timer(0.02).timeout
		if current_scene != null and current_scene.name == expected_name:
			return current_scene
	return null


func _finish() -> void:
	root.remove_meta(SCENE_TWO_ENTRY_META)
	root.remove_meta(RETURN_TO_SCENE_TWO_META)
	if failures.is_empty():
		print("Scene2 and sea-overworld round-trip verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
