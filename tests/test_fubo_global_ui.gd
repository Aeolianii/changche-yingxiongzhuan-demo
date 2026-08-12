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
	_check(level.get_phase_for_test() == level.Phase.FISHING_AVAILABLE, "Fubo must expose fishing immediately on initial load.")
	var prompt := level.get_node("Interface/HUD/PromptPanel") as TextureButton
	_check(prompt != null and prompt.texture_normal != null and prompt.texture_normal.resource_path.ends_with("interaction_button_ink_v1.png"), "Fubo prompt must use the existing ink interaction art.")
	_check(prompt.texture_pressed != null and prompt.texture_pressed.resource_path.ends_with("interaction_button_ink_active_v1.png"), "Fubo prompt must use the shared active interaction art.")
	var dialogue := level.get_node("Interface/KeeperDialogue") as FieldEventDialogue
	_check(dialogue != null and not level.has_node("Interface/HUD/DialoguePanel"), "Fubo must replace its bespoke dialogue panel with the shared field dialogue.")
	var paper_panel := dialogue.get_node("FullWidthPaperDialogueBox") as PanelContainer
	var paper_style := paper_panel.get_theme_stylebox("panel") as StyleBoxTexture
	_check(paper_panel.position == Vector2(0, 596) and paper_panel.size == Vector2(1344, 300), "Keeper dialogue must match the scene-one/two full-width layout.")
	_check(paper_style != null and paper_style.texture.resource_path.ends_with("ink_dialogue_backdrop.png"), "Keeper dialogue must use the shared ink backdrop.")
	var name_plate := dialogue.get_node("NamePlate") as PanelContainer
	var name_style := name_plate.get_theme_stylebox("panel") as StyleBoxTexture
	_check(name_plate.position == Vector2(1060, 830) and name_style != null and name_style.texture.resource_path.ends_with("ink_speaker_nameplate.png"), "Keeper dialogue must use the scene-two ink nameplate position and art.")
	var notice_backdrop := level.get_node("Interface/HUD/Overlay/NoticeBackdrop") as TextureRect
	_check(notice_backdrop != null and notice_backdrop.texture != null and notice_backdrop.texture.resource_path.ends_with("ink_dialogue_backdrop.png"), "Fubo notices must use an ink backdrop over a separate dimmer.")
	var notice_overlay := level.get_node("Interface/HUD/Overlay") as ColorRect
	_check(is_zero_approx(notice_overlay.color.a) and notice_overlay.size == Vector2(800, 180), "Fubo notices must expose only the cleanly cut ink stroke without a rectangular backing plate.")
	var fubo_source := FileAccess.get_file_as_string("res://scripts/fubo_guling/fubo_guling.gd")
	_check("渔获满舱，收竿归岸" in fubo_source and "渔获满舱\\n收竿归岸" not in fubo_source, "Fishing return notice must be one line joined by a Chinese comma.")

	_check(level.call("_is_stable_save_state"), "Fubo initial fishing-available exploration must be saveable.")
	level.call("_start_dialogue")
	var keeper_portrait := dialogue.get_node("LargeTransparentPortrait") as TextureRect
	_check(keeper_portrait.visible and keeper_portrait.texture != null and keeper_portrait.texture.resource_path == "res://assets/characters/soldier/picture.png", "Keeper dialogue must reuse the soldier portrait.")
	_check("伏波将军马援" in dialogue.dialogue_label.text and "南征靖边" in dialogue.dialogue_label.text, "The keeper must introduce Fubo Ridge through Ma Yuan's frontier legacy.")
	_check((dialogue.get_node("NamePlate/SpeakerLabel") as Label).text == "守岭人", "The shared nameplate must identify the keeper.")
	_check(dialogue.option_box.get_child_count() == 1 and (dialogue.option_box.get_child(0) as Button).text == "继续  ▶", "Keeper dialogue must expose the shared clickable continue option.")
	_check(not level.call("_is_stable_save_state"), "Fubo dialogue must not be saveable.")
	(dialogue.option_box.get_child(0) as Button).pressed.emit()
	_check("伏波岛扼守海道" in dialogue.dialogue_label.text and "校场鼓令" in dialogue.dialogue_label.text, "The keeper must explain the island's present frontier duty.")
	level.call("_advance_dialogue")
	_check("鱼竿鱼篓" in dialogue.dialogue_label.text and "随时都可下钩" in dialogue.dialogue_label.text, "The keeper must clearly present fishing as an always-available activity.")
	level.call("_advance_dialogue")
	_check("古校场听令回鼓" in dialogue.dialogue_label.text and "切莫误了军机" in dialogue.dialogue_label.text, "The keeper must connect fishing to the schoolyard drum task in a frontier voice.")
	level.call("_advance_dialogue")
	_check(level.get_phase_for_test() == level.Phase.FISHING_AVAILABLE and level.call("is_keeper_intro_completed_for_test"), "Keeper dialogue must not gate or change the fishing phase.")
	_check(level.call("_is_stable_save_state"), "Fubo fishing-available exploration must remain saveable after the keeper hint.")
	var fishing_entry_position := Vector2(665, 810)
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
	_check(str(level.get("_pending_trigger")) == "fishing" and prompt.visible, "Returning inside the fishing ring must immediately restore its interaction.")
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
