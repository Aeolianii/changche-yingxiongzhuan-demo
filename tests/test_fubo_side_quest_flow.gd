extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const TEST_SAVE_PATH := "user://test_fubo_side_quest_flow.json"

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_runtime_world_state")
	game_state.set("save_path_override", TEST_SAVE_PATH)
	_cleanup_save()
	var scene := SEA_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	_expect(not bool(game_state.call("has_fubo_side_quest")), "Fresh sea exploration must not grant the Fubo side quest before the soldier report.")
	var fubo_location: Area2D
	for location in get_nodes_in_group("sea_location"):
		if str(location.get_meta("location_name", "")) == "伏波古岭":
			fubo_location = location as Area2D
			break
	_expect(fubo_location != null, "Fubo Ridge must remain an enterable sea-map location.")
	if fubo_location != null:
		scene.set("_active_location_area", fubo_location)
		scene.set("_active_location_name", "伏波古岭")
		scene.call("_enter_active_location")

	var dialogue := scene.get("_event_dialogue") as FieldEventDialogue
	_expect(dialogue != null and dialogue.visible, "Trying to enter Fubo without its side quest must open the soldier report instead of changing scenes.")
	_expect(not bool(scene.get("_transitioning")), "The sea map must not start a Fubo loading transition before the side quest is accepted.")
	_expect("海域东北方" in dialogue.dialogue_label.text and "防倭寇" in dialogue.dialogue_label.text, "The soldier report must identify Fubo's northeast position and anti-pirate duty.")
	_expect(dialogue.option_box.get_child_count() == 1, "The Fubo report must expose one acknowledgement option.")
	var accept_button := dialogue.option_box.get_child(0) as Button
	_expect(accept_button.text == "收到，我会前去巡视。  ▶", "The protagonist must acknowledge the Fubo assignment with an arrow-marked response.")
	accept_button.pressed.emit()
	await process_frame

	_expect(bool(game_state.call("has_fubo_side_quest")), "Acknowledging the report must persistently accept the Fubo side quest.")
	_expect(game_state.call("get_tracked_side_quest") == &"fubo_guling", "The newly accepted Fubo side quest must become the tracked side quest.")
	var hud := root.get_node("ExplorationUI/HUD") as Control
	_expect((hud.get_node("QuestTracker/MainQuest/TaskName") as Label).text == "探索海域，完善海图", "Accepting Fubo must not replace the chart-exploration main quest.")
	_expect((hud.get_node("QuestTracker/SideQuest/TaskName") as Label).text == "伏波古岭", "Accepting Fubo must show it in the compact side-quest tracker.")

	var quest_screen := hud.get_node("QuestScreen")
	var quests: Array = quest_screen.get("_quests")
	_expect(quests.size() == 3 and str(quests[2].get("title", "")) == "伏波古岭" and str(quests[2].get("type", "")) == "支线", "Accepted Fubo must appear as a side quest in the sea-map quest list.")
	quest_screen.call("show_screen")
	var fubo_choice := quest_screen.get_node("QuestChoices/QuestChoice2") as Button
	fubo_choice.pressed.emit()
	_expect((hud.get_node("QuestTracker/SideQuest/TaskName") as Label).text == "伏波古岭", "Clicking the Fubo side quest must project it into the left tracker.")
	var sea_choice := quest_screen.get_node("QuestChoices/QuestChoice1") as Button
	sea_choice.pressed.emit()
	_expect((hud.get_node("QuestTracker/SideQuest/TaskName") as Label).text == "海上见闻", "Clicking another side quest must replace the left tracked side quest.")
	var save_result: Dictionary = game_state.call("save_game", "res://scenes/sea_overworld/sea_overworld.tscn", {})
	_expect(bool(save_result.get("ok", false)), "Fubo side-quest world state must be accepted by the formal save pipeline.")
	game_state.call("reset_runtime_world_state")
	var load_result: Dictionary = game_state.call("load_game")
	_expect(bool(load_result.get("ok", false)) and bool(game_state.call("has_fubo_side_quest")), "Loading must restore the accepted Fubo side quest from world state.")
	_expect(game_state.call("get_tracked_side_quest") == &"sea_encounters", "Loading must restore the side quest last selected in the quest screen.")
	game_state.call("set_tracked_side_quest", &"fubo_guling")
	game_state.call("set_fubo_side_quest_progress", 4, true)
	var completed_state := game_state.call("get_fubo_side_quest_state") as Dictionary
	_expect(bool(completed_state.get("completed", false)), "Fubo progress stage four must migrate into an explicit completed state.")
	_expect(game_state.call("get_tracked_side_quest") == &"", "Completing Fubo must clear it from the tracked side-quest slot.")
	_expect(str((game_state.get("_world_state") as Dictionary).get("tracked_side_quest", "stale")) == "", "Completing Fubo must clear the persisted tracked quest id, not only hide it at read time.")
	game_state.call("set_tracked_side_quest", &"fubo_guling")
	_expect(game_state.call("get_tracked_side_quest") == &"", "A completed Fubo quest must not be trackable again from stale UI state.")
	scene.call("_refresh_exploration_task")
	_expect(not hud.get_node("QuestTracker/SideQuest").visible, "Completing Fubo must hide it from the compact left tracker.")
	var active_quests := quest_screen.get("_quests") as Array
	var completed_quests := quest_screen.get("_completed_quests") as Array
	var fubo_is_active := false
	for quest_value in active_quests:
		var quest := quest_value as Dictionary
		if str(quest.get("id", "")) == "fubo_guling":
			fubo_is_active = true
			break
	_expect(not fubo_is_active, "Completing Fubo must remove it from the active quest list.")
	var archived_fubo: Dictionary = {}
	for quest_value in completed_quests:
		var quest := quest_value as Dictionary
		if str(quest.get("id", "")) == "fubo_guling":
			archived_fubo = quest
			break
	_expect(not archived_fubo.is_empty() and str(archived_fubo.get("objective", "")) == "已完成", "Completing Fubo must add it to the completed quest list.")
	if not archived_fubo.is_empty():
		var every_step_completed := true
		for step_value in archived_fubo.get("steps", []):
			if not bool((step_value as Dictionary).get("completed", false)):
				every_step_completed = false
				break
		_expect(every_step_completed, "The archived Fubo quest must check every task-flow step.")
	quest_screen.call("show_screen")
	var sea_choice_after_completion := quest_screen.get_node("QuestChoices/QuestChoice1") as Button
	sea_choice_after_completion.pressed.emit()
	_expect(hud.get_node("QuestTracker/SideQuest").visible and (hud.get_node("QuestTracker/SideQuest/TaskName") as Label).text == "海上见闻", "Selecting another active side quest after Fubo completion must restore the compact tracker with that quest.")
	var completed_save_result: Dictionary = game_state.call("save_game", "res://scenes/sea_overworld/sea_overworld.tscn", {})
	_expect(bool(completed_save_result.get("ok", false)), "The archived Fubo quest must remain valid formal save data.")
	game_state.call("reset_runtime_world_state")
	var completed_load_result: Dictionary = game_state.call("load_game")
	var restored_completed_state := game_state.call("get_fubo_side_quest_state") as Dictionary
	_expect(bool(completed_load_result.get("ok", false)) and bool(restored_completed_state.get("completed", false)), "Loading must preserve the Fubo quest in its completed archive state.")
	_expect(game_state.call("get_tracked_side_quest") == &"sea_encounters", "Loading an archived Fubo quest may restore another selected side quest, but must not restore Fubo to the tracker.")
	game_state.set("_world_state", {
		"fubo_side_quest": {"accepted": true, "progress_stage": 4, "keeper_intro_completed": true},
		"tracked_side_quest": "fubo_guling",
	})
	_expect(bool((game_state.call("get_fubo_side_quest_state") as Dictionary).get("completed", false)), "Legacy stage-four saves must infer Fubo completion without a completed field.")
	_expect(game_state.call("get_tracked_side_quest") == &"", "Legacy completed Fubo saves must ignore their stale tracked quest id.")

	current_scene = null
	scene.queue_free()
	await process_frame
	game_state.call("reset_runtime_world_state")
	game_state.set("save_path_override", "")
	_cleanup_save()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Fubo side quest flow verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _cleanup_save() -> void:
	for path in [TEST_SAVE_PATH, TEST_SAVE_PATH + ".tmp", TEST_SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
