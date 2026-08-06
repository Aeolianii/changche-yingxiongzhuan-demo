extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/exploration_hud.tscn")
const PALACE_SCENE := preload("res://scenes/palace/palace_demo.tscn")
const SCENE_TWO := preload("res://scenes/Scene2.tscn")
const SCREENSHOT_PATH := "res://.godot/exploration_hud_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_component_contract()
	await _verify_palace_visibility()
	await _verify_scene_two_visibility()

	if failures.is_empty():
		print("Exploration HUD runtime verification passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_component_contract() -> void:
	var hud := HUD_SCENE.instantiate() as Control
	root.add_child(hud)
	await process_frame
	_expect(not hud.visible, "Exploration HUD must start hidden until a scene reports free movement.")

	hud.call("set_exploration_visible", true)
	_expect(hud.visible, "Exploration HUD did not become visible through its public interface.")
	_expect(hud.get_node_or_null("PlayerStatus/PortraitFrame/ProtagonistPortrait") != null, "Player portrait is missing.")
	_expect(hud.get_node_or_null("QuestTracker/MainQuest/CharacterPlaceholder") != null, "Main quest character placeholder is missing.")
	_expect(hud.get_node_or_null("QuestTracker/SideQuest/CharacterPlaceholder") != null, "Side quest character placeholder is missing.")

	for button_name in ["MenuButton", "InventoryButton", "ShipButton", "CharacterButton"]:
		var button := hud.find_child(button_name, true, false) as Button
		_expect(button != null, "%s is missing." % button_name)
	var action_row := hud.get_node("FunctionButtons")
	_expect(
		action_row.get_child(0).name == "CharacterButtonSlot"
		and action_row.get_child(1).name == "InventoryButtonSlot"
		and action_row.get_child(2).name == "ShipButtonSlot"
		and action_row.get_child(3).name == "MenuButtonSlot",
		"Function buttons must end with MenuButton on the far right."
	)

	var menu_button := hud.find_child("MenuButton", true, false) as Button
	if menu_button != null:
		menu_button.pressed.emit()
		var toast := hud.get_node("ComingSoonToast") as Control
		var message := hud.get_node("ComingSoonToast/Message") as Label
		_expect(toast.visible, "Clicking a function button must show the coming-soon message.")
		_expect("功能即将开放" in message.text, "Coming-soon message uses the wrong text.")

	hud.call("set_exploration_visible", false)
	_expect(not hud.visible, "Exploration HUD did not hide through its public interface.")
	hud.queue_free()
	await process_frame


func _verify_palace_visibility() -> void:
	var palace := PALACE_SCENE.instantiate()
	root.add_child(palace)
	await process_frame
	var hud := palace.get_node("UI/ExplorationHUD") as Control
	var dialogue := palace.get_node("UI/Overlay/DialoguePanel") as Control
	_expect(not hud.visible, "Palace opening dialogue must hide the exploration HUD.")

	palace.set("story_state", 2)
	dialogue.hide()
	palace.call("_refresh_exploration_hud")
	_expect(hud.visible, "Palace WAIT_TALK free-movement state must show the exploration HUD.")
	hud.call("set_main_task", "听取内侍传召")
	await process_frame
	if DisplayServer.get_name() != "headless":
		var screenshot_error := root.get_texture().get_image().save_png(SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Exploration HUD preview screenshot could not be saved.")

	dialogue.show()
	palace.call("_refresh_exploration_hud")
	_expect(not hud.visible, "Palace dialogue must hide the exploration HUD.")
	palace.queue_free()
	await process_frame


func _verify_scene_two_visibility() -> void:
	var scene_two := SCENE_TWO.instantiate()
	if scene_two == null:
		failures.append("Scene2 could not be instantiated for HUD visibility checks.")
		return
	root.add_child(scene_two)
	await process_frame
	await process_frame

	var hud := scene_two.get_node("UI/ExplorationHUD") as Control
	var dialogue := scene_two.get_node("UI/DialoguePanel") as Control
	var drill := scene_two.get_node_or_null("UI/DrillOverlay") as Control
	_expect(hud.visible, "Scene2 free-movement state must show the exploration HUD.")

	dialogue.show()
	await physics_frame
	await physics_frame
	_expect(not hud.visible, "Scene2 dialogue must hide the exploration HUD.")

	dialogue.hide()
	if drill != null:
		drill.show()
		await physics_frame
		await physics_frame
		_expect(not hud.visible, "Scene2 drill overlay must hide the exploration HUD.")
		drill.hide()
		await physics_frame
		await physics_frame
		_expect(hud.visible, "Scene2 HUD must return after the drill overlay closes.")
	else:
		failures.append("Scene2 drill overlay was not created.")

	scene_two.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
