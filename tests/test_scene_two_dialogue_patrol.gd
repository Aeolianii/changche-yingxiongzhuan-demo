extends SceneTree

const SCENE_TWO := preload("res://scenes/Scene2.tscn")

var failures: Array[String] = []
var scene_two: Node2D
var player: CharacterBody2D
var dialogue_panel: Control
var option_box: VBoxContainer
var next_button: Button
var task_name: Label
var objective: Label
var drill_overlay: Control
var used_interaction_button := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	scene_two = SCENE_TWO.instantiate()
	root.add_child(scene_two)
	current_scene = scene_two
	await process_frame
	await physics_frame

	player = scene_two.get_node("World/Actors/Player") as CharacterBody2D
	dialogue_panel = scene_two.get_node("UI/DialoguePanel") as Control
	option_box = scene_two.get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer
	next_button = scene_two.get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/NextDialogueButton") as Button
	task_name = root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/TaskName") as Label
	objective = root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label
	drill_overlay = scene_two.get_node("UI/DrillOverlay") as Control

	_expect(task_name.text == "巡视水师驻地", "Scene2 must begin with the patrol task.")
	_expect("0/2" in objective.text, "Patrol task must begin with zero of two soldier reports.")

	await _interact_with("World/Actors/Npcs/GuangzhouCountyMagistrate")
	_expect(not drill_overlay.visible, "Magistrate must not open the drill before the patrol report.")
	await _press_space()
	_expect(dialogue_panel.visible and option_box.get_child_count() > 0, "Space must not auto-select an option dialogue.")
	await _press_option(0)

	await _interact_with("World/Actors/Npcs/FleetCommander")
	_expect(_speaker_text() == "中军军官", "The patrol officer must be distinct from the magistrate.")
	await _press_option(0)

	await _complete_soldier_report("World/Actors/Npcs/MagistrateLeftGuard")
	_expect("1/2" in objective.text, "First unique soldier report must advance patrol progress to one of two.")

	await _interact_with("World/Actors/Npcs/MagistrateLeftGuard")
	await _press_option(0)
	_expect("1/2" in objective.text, "Repeated soldier dialogue must not advance patrol progress twice.")

	await _complete_soldier_report("World/Actors/Npcs/MagistrateRightGuard")
	_expect("2/2" in objective.text and "中军军官" in objective.text, "Two soldier reports must unlock the officer report objective.")

	await _interact_with("World/Actors/Npcs/FleetCommander")
	await _press_option(0)
	await _advance_scripted_dialogue(3)
	_expect(task_name.text == "筹备水师操练", "Officer report must complete patrol and start drill preparation.")
	_expect(objective.text == "与广州县令交谈", "After reporting to the officer, the task must point to the magistrate.")

	await _interact_with("World/Actors/Npcs/GuangzhouCountyMagistrate")
	_expect(_speaker_text() == "广州县令", "Magistrate dialogue must use the magistrate identity.")
	await _press_option(0)
	var first_magistrate_line := (scene_two.get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label).text
	_expect("多年未操练" in first_magistrate_line and "沿海海域情况未明" in first_magistrate_line, "First magistrate briefing must explain the neglected navy and unknown coastal waters.")
	await _advance_scripted_dialogue(3)
	_expect(drill_overlay.visible, "Completing the magistrate briefing must open the drill.")
	_expect(task_name.text == "参加水师操练", "Opening the drill must update the main task.")

	var drill_return := drill_overlay.get_node("ReturnButton") as Button
	drill_return.pressed.emit()
	await process_frame
	_expect(task_name.text == "探索海域，完善海图", "Completing the drill must unlock the chart-completion task.")
	_expect(objective.text == "与广州县令交谈，选择是否立即出发", "Post-drill task must direct the player back to the magistrate.")

	await _interact_with("World/Actors/Npcs/GuangzhouCountyMagistrate")
	_expect(_speaker_text() == "广州县令", "Sea-departure dialogue must still use the magistrate identity.")
	_expect((scene_two.get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label).text == "将军是否要巡视一下岭南海域？", "Magistrate must ask whether the player wants to inspect Lingnan waters.")
	_expect(option_box.get_child_count() == 2, "Sea-departure dialogue must provide exactly two choices.")
	if option_box.get_child_count() == 2:
		_expect((option_box.get_child(0) as Button).text == "立即出发", "First sea-departure choice must be 立即出发.")
		_expect((option_box.get_child(1) as Button).text == "稍后再说", "Second sea-departure choice must be 稍后再说.")
	await _press_option(1)
	_expect(not dialogue_panel.visible and task_name.text == "探索海域，完善海图", "Choosing 稍后再说 must keep the chart-completion task available.")

	if failures.is_empty():
		print("Scene2 dialogue patrol runtime verification passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _interact_with(actor_path: String) -> void:
	var actor := scene_two.get_node(actor_path) as Node2D
	player.global_position = actor.global_position + Vector2(0, 54)
	await physics_frame
	await physics_frame
	var interaction_panel := scene_two.get_node("UI/InteractionPanel") as TextureButton
	var interaction_label := interaction_panel.get_node("Text") as Label
	var actor_sprite := actor.get_node("Sprite") as AnimatedSprite2D
	_expect(interaction_panel.visible, "Scene2 must show the bottom interaction button for %s." % actor_path)
	_expect("交谈" in interaction_label.text, "Scene2 interaction button must describe the talk action.")
	_expect(actor_sprite.modulate.r > 1.0, "Scene2 must highlight %s while its interaction button is available." % actor_path)
	if not used_interaction_button:
		used_interaction_button = true
		interaction_panel.pressed.emit()
	else:
		var event := InputEventAction.new()
		event.action = &"interact"
		event.pressed = true
		scene_two._unhandled_input(event)
	await process_frame
	_expect(not interaction_panel.visible, "Scene2 interaction button must hide after dialogue starts.")
	_expect(dialogue_panel.visible, "Dialogue did not open for %s." % actor_path)


func _complete_soldier_report(actor_path: String) -> void:
	await _interact_with(actor_path)
	await _press_option(0)
	var line_before_echo := (scene_two.get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label).text
	await _press_space(true)
	var line_after_echo := (scene_two.get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label).text
	_expect(line_after_echo == line_before_echo, "A held-space echo must not skip a Scene2 dialogue line.")
	await _advance_scripted_dialogue(2)


func _press_option(index: int) -> void:
	_expect(option_box.get_child_count() > index, "Expected dialogue option %d was missing." % index)
	if option_box.get_child_count() <= index:
		return
	(option_box.get_child(index) as Button).pressed.emit()
	await process_frame


func _advance_scripted_dialogue(line_count: int) -> void:
	for _index in range(line_count):
		await _press_space()


func _press_space(is_echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	event.echo = is_echo
	scene_two._unhandled_input(event)
	await process_frame


func _speaker_text() -> String:
	return (scene_two.get_node("UI/DialoguePanel/NamePlate/SpeakerLabel") as Label).text


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
