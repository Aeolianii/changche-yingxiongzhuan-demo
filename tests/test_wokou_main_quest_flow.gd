extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
# CHG-20260819（S-2 海面接入）：营寨迎战 → 讨伐战请求/返回 meta（与 C# HuntBattleSession 同值）。
const REQUEST_META := "sea_hunt_battle_request"
const RETURN_META := "sea_hunt_battle_return_context"
const HAIBATIAN_PORTRAIT_PATH := "res://assets/sea_overworld/portraits/倭寇头目海霸天.png"
const VICTORY_CG_PATH := "res://assets/sea_overworld/cutscenes/wokou_victory_cg_v1.png"
const PROTAGONIST_SCREENSHOT_PATH := "res://.godot/wokou_quest_protagonist_dialogue.png"
const HAIBATIAN_SCREENSHOT_PATH := "res://.godot/wokou_quest_haibatian_dialogue.png"
const VICTORY_SCREENSHOT_PATH := "res://.godot/wokou_victory_cutscene.png"

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
	_expect(warning_shape.shape is CircleShape2D and is_equal_approx((warning_shape.shape as CircleShape2D).radius, 1200.0), "The Wokou warning radius must extend one hundred pixels farther from the camp.")
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
	var acknowledged_world_state := game_state.call("get_sea_main_quest_state") as Dictionary
	_expect(bool(acknowledged_world_state.get("wokou_warning_acknowledged", false)), "Acknowledging the warning must persist the campaign in global main-quest state.")
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
	_expect(dialogue.portrait_image.position.x > 860.0 and dialogue.portrait_image.size.is_equal_approx(Vector2(457.6, 457.6)), "Hai Batian must remain on the right at a modestly reduced size in a square frame.")
	_expect(dialogue.portrait_image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Hai Batian's complete square source must be centered without cropping either shoulder.")
	await _capture_dialogue(HAIBATIAN_SCREENSHOT_PATH)
	option_box = dialogue.option_box
	_expect(option_box.get_child_count() == 1, "Hai Batian's reply must expose one battle option.")
	if option_box.get_child_count() == 1:
		var battle_option := option_box.get_child(0) as Button
		_expect("进军" in battle_option.text and "一决胜负" in battle_option.text, "The battle option must order the fleet to advance and fight.")
		# CHG-20260819（S-2 海面接入）：选择进军 → 写讨伐大本营战请求 meta（hunt_stage3）并进入正式海战。
		root.remove_meta(REQUEST_META)
		root.remove_meta(RETURN_META)
		battle_option.pressed.emit()
		await process_frame
		await process_frame
		var request_value: Variant = root.get_meta(REQUEST_META, null)
		_expect(request_value is Dictionary, "Choosing battle must write the hunt battle request meta.")
		if request_value is Dictionary:
			_expect(str(request_value["stage_id"]) == "hunt_stage3", "The stronghold fight must request the wokou camp stage (hunt_stage3, got %s)." % str(request_value.get("stage_id", "")))
			_expect(request_value.get("player_position") is Array, "The request must carry the pre-battle player position.")
		# 移除请求 meta 模拟「返回海面」——就地结算（headless 不执行真正切场景）。
		root.remove_meta(REQUEST_META)

	# 胜利返回（outcome 0）：营寨战完成主线 + 补播胜利过场 CG。
	# 玩家位置取触发战斗时的实际船位（靠近营寨的可航行点，非营寨中心陆块）。
	root.set_meta(RETURN_META, {
		"stage_id": "hunt_stage3",
		"outcome": 0,
		"player_position": [3750.0, 2600.0],
		"lunar_day": 3.0,
	})
	current_scene = null
	scene.queue_free()
	await process_frame
	var victory_scene := SEA_SCENE.instantiate()
	root.add_child(victory_scene)
	current_scene = victory_scene
	var cutscene := victory_scene.get("_wokou_victory_cutscene") as WokouVictoryCutscene
	# 胜利过场在 _ready 里延后播放（deferred）；趁 deferred 调用尚未执行，先把时长压缩以加速测试。
	cutscene.duration_scale = 0.08
	for _frame in range(8):
		await physics_frame
	await process_frame
	_expect(bool(victory_scene.get("_wokou_battle_completed")) and bool(victory_scene.get("_wokou_warning_acknowledged")), "Victory return must mark the wokou camp completed and warning acknowledged.")
	_expect(cutscene.visible and cutscene.is_playing_for_test(), "The victory return must play the Wokou ending CG.")
	var cg_image := cutscene.get_node("CGImage") as TextureRect
	_expect(cg_image.texture != null and cg_image.texture.resource_path == VICTORY_CG_PATH, "The ending must use the generated camp-destruction CG.")
	var ending_captions := cutscene.story_captions_for_test()
	var ending_text := "".join(ending_captions)
	_expect(ending_captions.size() == 5 and ending_text.length() >= 100, "The ending must present at least one hundred Chinese characters across five readable captions.")
	_expect("伏波将军上任以来" in ending_text and "倭寇之乱终告平定" in ending_text and "海晏民安" in ending_text, "The ending text must praise the general, record the campaign victory and close on peace for the people.")
	_expect(cutscene.estimated_duration_seconds_for_test() > 10.0, "The full-speed CG duration must be derived from the longer ending text.")
	var story_label := cutscene.get_node("StoryText") as Label
	for _caption_frame in range(120):
		if not story_label.text.is_empty() and story_label.modulate.a > 0.98:
			break
		await process_frame
	_expect(story_label.modulate.a > 0.98, "The ending caption must become fully opaque over the CG.")
	await _capture_cutscene(VICTORY_SCREENSHOT_PATH)
	if cutscene.is_playing_for_test():
		await cutscene.cutscene_finished
	await process_frame

	_expect(not bool(victory_scene.get("_transitioning")) and (victory_scene.get_node("World/Player") as CharacterBody2D).controls_enabled, "Finishing the victory CG must restore sailing controls.")
	var victory_player := victory_scene.get_node("World/Player") as Node2D
	_expect(victory_player.global_position.is_equal_approx(Vector2(3750, 2600)), "Victory return must restore the pre-battle ship position (got %s)." % victory_player.global_position)
	_expect(main_task_name.text == "讨伐倭寇" and "倭寇营地已平定" in main_task_objective.text, "Victory must keep the campaign title and mark the camp pacified.")
	var event_state := victory_scene.call("_current_event_state") as Dictionary
	_expect(bool(event_state.get("wokou_warning_acknowledged", false)) and bool(event_state.get("wokou_battle_completed", false)), "The warning and victory flags must be included in persistent sea event state.")
	var completed_world_state := game_state.call("get_sea_main_quest_state") as Dictionary
	_expect(bool(completed_world_state.get("wokou_battle_completed", false)), "Wokou victory must remain completed in global main-quest state across scene changes.")

	await _finish(victory_scene, game_state)


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


func _capture_cutscene(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(path)
	_expect(save_error == OK, "Wokou ending preview could not be saved to %s." % path)


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
