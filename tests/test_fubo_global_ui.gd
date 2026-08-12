extends SceneTree

const FUBO_SCENE := preload("res://scenes/fubo_guling/fubo_guling.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := FUBO_SCENE.instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var global_ui := root.get_node("ExplorationUI")
	var global_hud := global_ui.call("get_hud") as Control
	_check(global_ui.call("current_owner") == level and global_ui.call("current_context") == &"fubo_guling", "Fubo must acquire the global HUD with its own context.")
	_check(global_hud.visible, "Fubo free exploration must show the global HUD.")
	_check(level.get_node_or_null("Interface/HUD/TitlePanel") == null, "Fubo must remove the old title rectangle.")
	_check(level.get_node_or_null("Interface/HUD/FishingPanel") == null and level.get_node_or_null("Interface/HUD/DrumPanel") == null, "Fubo must remove old minigame status rectangles.")
	_check((global_hud.get_node("QuestTracker/MainQuest/TaskName") as Label).text == "伏波古岭", "Fubo must project its task into the global tracker.")
	var prompt := level.get_node("Interface/HUD/PromptPanel") as TextureButton
	_check(prompt != null and prompt.texture_normal != null and prompt.texture_normal.resource_path.ends_with("interaction_button_ink_v1.png"), "Fubo prompt must use the existing ink interaction art.")
	_check(prompt.texture_pressed != null and prompt.texture_pressed.resource_path.ends_with("interaction_button_ink_active_v1.png"), "Fubo prompt must use the shared active interaction art.")
	var dialogue := level.get_node("Interface/HUD/DialoguePanel") as TextureRect
	_check(dialogue != null and dialogue.texture != null and dialogue.texture.resource_path.ends_with("ink_dialogue_backdrop.png"), "Fubo dialogue must use the shared ink backdrop.")
	_check(level.has_node("Interface/HUD/DialoguePanel/SpeakerPlate"), "Fubo dialogue must use the shared speaker nameplate.")
	var notice_backdrop := level.get_node("Interface/HUD/Overlay/NoticeBackdrop") as TextureRect
	_check(notice_backdrop != null and notice_backdrop.texture != null and notice_backdrop.texture.resource_path.ends_with("ink_dialogue_backdrop.png"), "Fubo notices must use an ink backdrop over a separate dimmer.")

	_check(level.call("_is_stable_save_state"), "Fubo arrival exploration must be saveable.")
	level.call("_start_dialogue")
	_check(not level.call("_is_stable_save_state"), "Fubo dialogue must not be saveable.")
	for _index in 3:
		level.call("_advance_dialogue")
	_check(level.call("_is_stable_save_state"), "Fubo fishing-available exploration must be saveable.")
	var fishing_entry_position := Vector2(620, 810)
	(level.get_node("World/WorldObjects/Player") as CharacterBody2D).global_position = fishing_entry_position
	level.call("trigger_fishing_for_test")
	var host := level.get_node("Interface/MinigameHost")
	_check(host.active_minigame != null and not global_hud.visible, "Opening a Fubo minigame must hide the global HUD.")
	if host.active_minigame != null:
		host.active_minigame.exit_requested.emit()
		await process_frame
	_check(host.active_minigame == null and global_hud.visible, "Leaving a Fubo minigame must restore the global HUD.")
	var restored_position := (level.get_node("World/WorldObjects/Player") as CharacterBody2D).global_position
	_check(restored_position == fishing_entry_position, "Leaving coastal fishing must restore the position used to enter it: expected %s, got %s." % [fishing_entry_position, restored_position])
	_check(level.call("_is_stable_save_state"), "Leaving a Fubo minigame must restore a saveable exploration state.")
	level.set("_transitioning", true)
	_check(not level.call("_is_stable_save_state"), "Fubo loading transitions must not be saveable.")
	level.set("_transitioning", false)
	(level.get_node("Interface/HUD/Overlay") as Control).visible = true
	_check(not level.call("_is_stable_save_state"), "Fubo notice and completion overlays must not be saveable.")
	level.free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Fubo global UI verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
