extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const HAIBATIAN_PORTRAIT_PATH := "res://assets/sea_overworld/portraits/倭寇头目海霸天.png"
const PROTAGONIST_SCREENSHOT_PATH := "res://.godot/wokou_quest_protagonist_dialogue.png"
const HAIBATIAN_SCREENSHOT_PATH := "res://.godot/wokou_quest_haibatian_dialogue.png"

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_runtime_world_state")
	var scene := SEA_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var hud := root.get_node("ExplorationUI/HUD") as Control
	var main_task_name := hud.get_node("QuestTracker/MainQuest/TaskName") as Label
	var main_task_objective := hud.get_node("QuestTracker/MainQuest/Objective") as Label
	_expect(main_task_name.text == "探索海域，完善海图", "Entering the sea map must retain the chart-exploration main quest.")

	var stronghold := _find_location("倭寇营地")
	_expect(stronghold != null, "The sea map must expose the renamed Wokou stronghold location.")
	var warning_trigger := scene.get_node_or_null("World/WorldMarkers/WokouStrongholdWarningTrigger") as Area2D
	_expect(warning_trigger != null, "The Wokou stronghold must have a nearby automatic warning trigger.")
	if stronghold == null or warning_trigger == null:
		await _finish(scene, game_state)
		return

	var player := scene.get_node("World/Player") as SeaOverworldPlayer
	var dialogue := scene.get("_event_dialogue") as FieldEventDialogue
	var warning_shape := warning_trigger.get_child(0) as CollisionShape2D
	_expect(warning_shape.shape is CircleShape2D and is_equal_approx((warning_shape.shape as CircleShape2D).radius, 1100.0), "The Wokou warning must trigger well before the fleet reaches the camp entrance.")
	scene.call("_on_auto_trigger_body_entered", player, warning_trigger)
	await process_frame
	_expect(dialogue.visible and dialogue.speaker_label.text == "水师士兵", "Approaching the stronghold must automatically open the soldier warning.")
	_expect("前方已近倭寇营地" in dialogue.dialogue_label.text and "万分凶险" in dialogue.dialogue_label.text, "The warning must identify the camp and stress its danger.")
	_expect(not player.controls_enabled, "The warning dialogue must pause sailing.")
	var option_box := dialogue.option_box
	_expect(option_box.get_child_count() == 1, "The warning must provide one military acknowledgement.")
	if option_box.get_child_count() == 1:
		var warning_option := option_box.get_child(0) as Button
		_expect("传令全军戒备，列阵前进" in warning_option.text, "The warning option must order the fleet to advance on alert.")
		warning_option.pressed.emit()
		await process_frame

	_expect(bool(scene.get("_wokou_warning_acknowledged")), "Acknowledging the warning must persist its local quest state.")
	_expect(not dialogue.visible and player.controls_enabled, "Acknowledging the warning must resume sailing.")
	_expect(main_task_name.text == "讨伐倭寇", "Acknowledging the warning must replace chart exploration with the Wokou campaign title.")
	_expect("按E发起讨伐" in main_task_objective.text, "The main objective must direct the player to interact with the stronghold.")

	scene.set("_active_location_area", stronghold)
	scene.set("_active_location_name", "倭寇营地")
	player.global_position = Vector2(3750, 2600)
	(scene.get_node("World/Player/Camera2D") as Camera2D).reset_smoothing()
	await physics_frame
	scene.call("_enter_active_location")
	await process_frame
	_expect(dialogue.visible and dialogue.speaker_label.text == "水师元帅", "Pressing E at the stronghold must let the protagonist speak first.")
	_expect("海霸天" in dialogue.dialogue_label.text and "厂车军民" in dialogue.dialogue_label.text and "伏诛" in dialogue.dialogue_label.text, "The protagonist must denounce Hai Batian without naming a real dynasty.")
	_expect("大明" not in dialogue.dialogue_label.text and dialogue.portrait_image.position.x < 0.0, "The protagonist portrait must use the scene-one/scene-two left-side dialogue layout.")
	await _capture_dialogue(PROTAGONIST_SCREENSHOT_PATH)
	option_box = dialogue.option_box
	if option_box.get_child_count() == 1:
		(option_box.get_child(0) as Button).pressed.emit()
		await process_frame
	else:
		_expect(false, "The protagonist line must provide one continuation.")

	_expect(dialogue.speaker_label.text == "倭寇头目·海霸天", "Hai Batian must answer the protagonist.")
	_expect(main_task_name.text == "讨伐倭寇", "The campaign title must remain visible throughout the confrontation.")
	_expect("狗官" in dialogue.dialogue_label.text and "自己送上门" in dialogue.dialogue_label.text and "抄家伙" in dialogue.dialogue_label.text, "Hai Batian must answer as a coarse bandit without self-identifying through a Wokou weapon.")
	_expect("倭刀" not in dialogue.dialogue_label.text, "Hai Batian must not claim that his men wield Wokou swords.")
	_expect(dialogue.portrait_image.texture != null and dialogue.portrait_image.texture.resource_path == HAIBATIAN_PORTRAIT_PATH, "Hai Batian's dialogue must use the supplied portrait.")
	_expect(dialogue.portrait_image.position.x > 800.0 and dialogue.portrait_image.size.is_equal_approx(Vector2(520, 520)), "Hai Batian must remain on the right at the original portrait height in an expanded square frame.")
	_expect(dialogue.portrait_image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Hai Batian's complete square source must be centered without cropping either shoulder.")
	await _capture_dialogue(HAIBATIAN_SCREENSHOT_PATH)
	option_box = dialogue.option_box
	_expect(option_box.get_child_count() == 1, "Hai Batian's reply must expose one battle option.")
	if option_box.get_child_count() == 1:
		var battle_option := option_box.get_child(0) as Button
		_expect("一决胜负" in battle_option.text and "战斗系统还未完善，此战默认获胜" in battle_option.text, "The battle option must state the placeholder auto-victory rule.")
		var cutscene := scene.get("_wokou_victory_cutscene") as WokouVictoryCutscene
		cutscene.duration_scale = 0.01
		battle_option.pressed.emit()
		await process_frame
		_expect(cutscene.visible and cutscene.is_playing_for_test(), "Choosing battle must immediately show the victory CG placeholder.")
		_expect((cutscene.get_node("Caption/Title") as Label).text == "靖海奏捷", "The victory placeholder must show its approved main caption.")
		_expect((cutscene.get_node("Caption/Subtitle") as Label).text == "倭巢已破，海疆暂安", "The victory placeholder must show its approved result caption.")
		_expect(bool(scene.get("_wokou_battle_completed")) and not player.controls_enabled, "The placeholder battle must default to victory while controls remain locked for the CG.")
		for _frame in range(120):
			if not bool(scene.get("_transitioning")):
				break
			await process_frame

	_expect(not bool(scene.get("_transitioning")) and player.controls_enabled, "Finishing the victory CG must restore sailing controls.")
	_expect(main_task_name.text == "讨伐倭寇" and "倭寇营地已平定" in main_task_objective.text, "Victory must keep the campaign title and mark the camp pacified.")
	var event_state := scene.call("_current_event_state") as Dictionary
	_expect(bool(event_state.get("wokou_warning_acknowledged", false)) and bool(event_state.get("wokou_battle_completed", false)), "The warning and victory flags must be included in persistent sea event state.")

	await _finish(scene, game_state)


func _find_location(location_name: String) -> Area2D:
	for location in get_nodes_in_group("sea_location"):
		if str(location.get_meta("location_name", "")) == location_name:
			return location as Area2D
	return null


func _capture_dialogue(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(path)
	_expect(save_error == OK, "Wokou dialogue preview could not be saved to %s." % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(scene: Node, game_state: Node) -> void:
	current_scene = null
	scene.queue_free()
	await process_frame
	game_state.call("reset_runtime_world_state")
	if _failures.is_empty():
		print("Wokou main-quest flow verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
