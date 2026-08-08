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
	task_name = scene_two.get_node("UI/ExplorationHUD/QuestTracker/MainQuest/TaskName") as Label
	objective = scene_two.get_node("UI/ExplorationHUD/QuestTracker/MainQuest/Objective") as Label
	drill_overlay = scene_two.get_node("UI/DrillOverlay") as Control

	_expect(task_name.text == "巡视水师驻地", "Scene2 must begin with the patrol task.")
	_expect("0/2" in objective.text, "Patrol task must begin with zero of two soldier reports.")

	await _interact_with("World/Actors/Npcs/GuangzhouCountyMagistrate")
	_expect(not drill_overlay.visible, "Magistrate must not open the drill before the patrol report.")
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
	await _advance_scripted_dialogue(3)
	_expect(drill_overlay.visible, "Completing the magistrate briefing must open the drill.")
	_expect(task_name.text == "参加水师操练", "Opening the drill must update the main task.")

	var drill_return := drill_overlay.get_node("ReturnButton") as Button
	drill_return.pressed.emit()
	await process_frame
	_expect(task_name.text == "和县令对话探索岭南海域", "Completing the drill must unlock the Lingnan sea exploration task.")
	_expect(objective.text == "与广州县令交谈，选择是否立即出发", "Post-drill task must direct the player back to the magistrate.")

	await _interact_with("World/Actors/Npcs/GuangzhouCountyMagistrate")
	_expect(_speaker_text() == "广州县令", "Sea-departure dialogue must still use the magistrate identity.")
	_expect((scene_two.get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label).text == "将军是否要巡视一下岭南海域？", "Magistrate must ask whether the player wants to inspect Lingnan waters.")
	_expect(option_box.get_child_count() == 2, "Sea-departure dialogue must provide exactly two choices.")
	if option_box.get_child_count() == 2:
		_expect((option_box.get_child(0) as Button).text == "立即出发", "First sea-departure choice must be 立即出发.")
		_expect((option_box.get_child(1) as Button).text == "稍后再说", "Second sea-departure choice must be 稍后再说.")
	await _press_option(1)
	_expect(not dialogue_panel.visible and task_name.text == "和县令对话探索岭南海域", "Choosing 稍后再说 must keep the post-drill exploration task available.")

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
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	scene_two._unhandled_input(event)
	await process_frame
	_expect(dialogue_panel.visible, "Dialogue did not open for %s." % actor_path)


func _complete_soldier_report(actor_path: String) -> void:
	await _interact_with(actor_path)
	await _press_option(0)
	await _advance_scripted_dialogue(2)


func _press_option(index: int) -> void:
	_expect(option_box.get_child_count() > index, "Expected dialogue option %d was missing." % index)
	if option_box.get_child_count() <= index:
		return
	(option_box.get_child(index) as Button).pressed.emit()
	await process_frame


func _advance_scripted_dialogue(line_count: int) -> void:
	for _index in range(line_count):
		next_button.pressed.emit()
		await process_frame


func _speaker_text() -> String:
	return (scene_two.get_node("UI/DialoguePanel/NamePlate/SpeakerLabel") as Label).text


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
