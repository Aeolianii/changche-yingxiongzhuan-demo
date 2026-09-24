extends Node

# Runs only when explicitly requested from an exported executable.
const FLAG := "--smoke-naval-export"
const DIALOGUE_FLAG := "--smoke-dialogue-export"


func _ready() -> void:
	if FLAG in OS.get_cmdline_user_args():
		_run.call_deferred()
	elif DIALOGUE_FLAG in OS.get_cmdline_user_args():
		_run_dialogue.call_deferred()


func _run() -> void:
	# Let the title screen finish its deferred focus request before replacing it.
	await get_tree().create_timer(0.1).timeout
	var error := get_tree().change_scene_to_file("res://scenes/naval/NavalDemo.tscn")
	if error != OK:
		_fail("scene load failed: %s" % error)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		_fail("scene is null")
		return
	var deployment := scene.get_node_or_null("Deployment")
	if deployment == null or not deployment.has_method("PlayerShipCount"):
		_fail("deployment controller is missing")
		return
	var player_count: int = deployment.PlayerShipCount()
	var enemy_count: int = deployment.EnemyShipCount()
	var ship_sprites := deployment.get_node_or_null("DeployShips")
	var sea := deployment.get_node_or_null("DeployGrid/AnimatedSeaSurface") as Polygon2D
	if player_count < 1 or enemy_count < 1 or ship_sprites == null or ship_sprites.get_child_count() < 1:
		_fail("fleet not initialized: player=%d enemy=%d" % [player_count, enemy_count])
		return
	if sea == null or sea.polygon.size() < 4 or sea.texture == null:
		_fail("sea surface not initialized")
		return
	if deployment.SelectShipForDeploy("p1") != "":
		_fail("first player ship cannot be selected")
		return
	var command_panel := deployment.get_node_or_null("DeployHud/Panel") as Panel
	var command_backdrop := deployment.get_node_or_null("DeployHud/Panel/Backdrop") as TextureRect
	if command_panel == null or not command_panel.visible or command_backdrop == null or command_backdrop.texture == null:
		_fail("deployment commands are not visible")
		return
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var screenshot_error := image.save_png("user://export_naval_smoke.png")
		if screenshot_error != OK:
			_fail("screenshot failed: %s" % screenshot_error)
			return
	print("EXPORT_NAVAL_SMOKE_OK player=%d enemy=%d sprites=%d sea_vertices=%d" % [
		player_count, enemy_count, ship_sprites.get_child_count(), sea.polygon.size()
	])
	get_tree().quit(0)


func _run_dialogue() -> void:
	await get_tree().create_timer(0.1).timeout
	var error := get_tree().change_scene_to_file("res://scenes/palace/palace_demo.tscn")
	if error != OK:
		_fail("palace scene load failed: %s" % error)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		_fail("palace scene is null")
		return
	var failures: Array[String] = []
	var label := scene.get_node_or_null("UI/Overlay/DialoguePanel/DialogueText") as Label
	if label == null:
		_fail("palace dialogue label is missing")
		return
	scene.call("_show_audience_dialogue")
	await get_tree().process_frame
	_check_dialogue_label(label, "palace_emperor", 650.0, 2, failures)
	if not await _capture_dialogue("emperor"):
		failures.append("emperor screenshot failed")
	scene.set("audience_index", 1)
	scene.call("_show_audience_dialogue")
	await get_tree().process_frame
	_check_dialogue_label(label, "palace_commander", 630.0, 2, failures)
	if not await _capture_dialogue("commander"):
		failures.append("commander screenshot failed")
	scene.call("_show_character_dialogue", "伏波大将军，陛下有旨，宣您即刻入殿觐见。", "内侍", load("res://assets/characters/attendant/picture.png"), false)
	await get_tree().process_frame
	_check_dialogue_label(label, "palace_attendant", 650.0, 1, failures)
	scene.call("_show_dialogue", "【圣旨·原型占位】\n命水师主帅总领岭南海防，筹建水师、剿除海寇、收复海岛、重开万国贡路。")
	await get_tree().process_frame
	_check_dialogue_label(label, "palace_edict", 728.0, 2, failures)
	scene.call("_show_dialogue", "【旁白】\n水师主帅领旨南下。场景一完成。")
	await get_tree().process_frame
	_check_dialogue_label(label, "palace_narrator", 728.0, 2, failures)

	error = get_tree().change_scene_to_file("res://scenes/Scene2.tscn")
	if error != OK:
		_fail("Scene2 load failed: %s" % error)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var scene_two := get_tree().current_scene
	var scene_two_label := scene_two.get_node_or_null("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	if scene_two_label == null:
		_fail("Scene2 dialogue label is missing")
		return
	scene_two.get_node("UI/DialoguePanel").show()
	var scene_two_lines: Array = []
	scene_two_lines.append_array(scene_two.get("_arrival_dialogues"))
	scene_two_lines.append_array(scene_two.get("_magistrate_dialogues"))
	for index in range(scene_two_lines.size()):
		var line: Array = scene_two_lines[index]
		var commander := str(line[0]) == "水师主帅"
		scene_two.call("_apply_dialogue_side", commander)
		scene_two_label.text = str(line[1])
		await get_tree().process_frame
		_check_dialogue_label(scene_two_label, "scene2_%d" % index, 630.0 if commander else 650.0, 1, failures)

	error = get_tree().change_scene_to_file("res://scenes/sea_overworld/sea_overworld.tscn")
	if error != OK:
		_fail("sea overworld load failed: %s" % error)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var sea_scene := get_tree().current_scene
	var event_dialogue := sea_scene.get("_event_dialogue") as FieldEventDialogue
	if event_dialogue == null:
		_fail("sea event dialogue is missing")
		return
	var options: Array[Dictionary] = [{"id": &"continue", "text": "继续"}]
	var pirate_options: Array[Dictionary] = [
		{"id": &"battle_difficulty_1", "text": "迎战（难度一）"},
		{"id": &"battle_difficulty_2", "text": "迎战（难度二）"},
		{"id": &"battle_difficulty_3", "text": "迎战（难度三）"},
		{"id": &"battle_formula", "text": "迎战（按我舰强度）"},
	]
	var event_cases: Array[Dictionary] = [
		{"name": "pirate", "speaker": "海盗小兵", "text": "兄弟们，抄家伙！狠狠干他们一票，把船和货全抢过来！", "portrait": "res://assets/sea_overworld/portraits/海盗小兵.png", "left": false},
		{"name": "crate", "speaker": "水师士兵", "text": "禀将军！前方海面发现一只漂流而来的木箱，箱体尚且完整，是否命人打捞？", "left": false},
		{"name": "crate_reward", "speaker": "水师士兵", "text": "禀将军，木箱已经打捞完毕，所得物资如下：\n铁石 +100　　木材 +100　　银钱 +1000", "left": false},
		{"name": "tea", "speaker": "茶叶商人", "text": "将军，这是姑苏新产的龙井茶。我们沿途遭遇风暴，船只受损，急需银钱修缮。还望将军购买一些茶叶，助我们渡过难关。", "left": false},
		{"name": "tea_result", "speaker": "茶叶商人", "text": "多谢将军相助！", "detail": "银钱 -100　　获得商品：[color=#f2c45c]龙井茶[/color]", "left": false},
		{"name": "salt", "speaker": "私盐商人", "text": "将军，小船只是寻常行商，装的都是沿海急需的盐货。若将军肯通融，我们愿奉上一份薄礼……", "left": false},
		{"name": "salt_result", "speaker": "私盐商人", "text": "官爷饶命！这些盐货都交由水师处置。", "detail": "查获物品：[color=#f2c45c]私盐[/color]", "left": false},
		{"name": "lingnan", "speaker": "水师士兵", "text": "禀将军，前方发现一艘岭南商船。看船上货箱齐备，似有不少沿海货物，是否靠近查看？", "left": false},
		{"name": "lingnan_result", "speaker": "岭南商人", "text": "多谢将军惠顾！愿将军此行顺风顺水，旗开得胜。", "left": false},
		{"name": "monster", "speaker": "水师士兵", "text": "将军，前方海面忽然漫起青灰薄雾，雾下似有一个庞大的黑影正随暗流缓缓移动……", "left": false},
		{"name": "monster_reveal", "speaker": "海中异兽", "text": "舰队靠近后，雾中的黑影骤然翻涌而出——竟是一头从未见过的海怪！", "portrait": "res://assets/sea_overworld/portraits/海怪1.png", "left": false},
		{"name": "fubo", "speaker": "水师士兵", "text": "将军，海域东北方有一座孤岛，名为伏波古岭。岛上军士扼守航道、巡查烽堠，以防倭寇乘隙侵扰。将军若得空，可登岛巡视军备，也好安定守军之心。", "left": false},
		{"name": "keeper", "speaker": "守岭人", "text": "此地名唤伏波古岭。岛上军民感念伏波将军马援南征靖边、开道安民之功，故以伏波为名，世代纪念。", "left": false},
		{"name": "boss_warning", "speaker": "水师士兵", "text": "将军，前方已近倭寇营地！水寨旌旗杂乱、哨船密布，贼众又据险死守，贸然突进万分凶险。还请将军传令各船收拢阵形、严守战位，切莫轻敌！", "portrait": "res://assets/characters/soldier/picture.png", "left": false},
		{"name": "boss_challenge", "speaker": "水师元帅", "text": "海霸天！你纵船劫掠商旅，焚毁渔村，杀伤我厂车军民，搅得沿海不得安生。本将奉命靖海，今日兵临贼巢，便是你束手伏诛之时！", "portrait": "res://assets/characters/protagonist/picture.png", "left": true},
		{"name": "boss_reply", "speaker": "倭寇头目·海霸天", "text": "呸！狗官，少在老子面前装腔作势！老子还没领船去寻你，你倒自己送上门来了。弟兄们，抄家伙守住寨门——既敢闯我营寨，今日便叫你有来无回！", "portrait": "res://assets/sea_overworld/portraits/倭寇头目海霸天.png", "left": false},
	]
	for event_case in event_cases:
		var portrait_path := str(event_case.get("portrait", ""))
		var portrait: Texture2D = load(portrait_path) as Texture2D if not portrait_path.is_empty() else null
		var is_pirate: bool = str(event_case["name"]) == "pirate"
		var event_options: Array[Dictionary] = pirate_options if is_pirate else options
		var detail: String = "选择战斗难度" if is_pirate else str(event_case.get("detail", ""))
		event_dialogue.present(event_case["speaker"], event_case["text"], portrait, event_options, detail, event_case["left"], 0.88 if event_case["name"] == "boss_reply" else 1.0, event_case["name"] == "boss_reply")
		await get_tree().process_frame
		_check_dialogue_label(event_dialogue.dialogue_label, "sea_%s" % event_case["name"], 630.0 if event_case["left"] else 650.0, 1, failures)
		var paper_bottom := event_dialogue.paper_panel.global_position.y + event_dialogue.paper_panel.size.y
		var options_bottom := event_dialogue.option_box.global_position.y + event_dialogue.option_box.size.y
		print("DIALOGUE_OPTIONS %s bottom=%.1f panel_bottom=%.1f" % [event_case["name"], options_bottom, paper_bottom])
		if options_bottom > paper_bottom + 1.0:
			failures.append("sea_%s_options" % event_case["name"])
		if paper_bottom > get_viewport().get_visible_rect().size.y + 1.0:
			failures.append("sea_%s_panel_offscreen" % event_case["name"])
		if is_pirate and event_dialogue.detail_label.get_line_count() < 1:
			failures.append("sea_pirate_detail")
		if event_case["name"] in ["pirate", "tea", "boss_reply"]:
			if not await _capture_dialogue(str(event_case["name"])):
				failures.append("%s screenshot failed" % event_case["name"])
	var victory := sea_scene.get("_wokou_victory_cutscene") as WokouVictoryCutscene
	if victory == null:
		failures.append("boss victory cutscene is missing")
	else:
		victory.show()
		var story_text := victory.get_node("StoryText") as Label
		for index in range(victory.story_captions_for_test().size()):
			story_text.text = str(victory.story_captions_for_test()[index])
			await get_tree().process_frame
			_check_dialogue_label(story_text, "boss_victory_%d" % index, story_text.size.x, 1, failures)
	if not failures.is_empty():
		_fail("dialogue layout: " + "; ".join(failures))
		return
	print("EXPORT_DIALOGUE_SMOKE_OK palace=5 scene2=%d sea=%d boss_victory=5" % [scene_two_lines.size(), event_cases.size()])
	get_tree().quit(0)


func _check_dialogue_label(label: Label, case_name: String, expected_width: float, min_lines: int, failures: Array[String]) -> void:
	var right_edge := 0.0
	var bottom_edge := 0.0
	for i in range(label.text.length()):
		var bounds := label.get_character_bounds(i)
		right_edge = maxf(right_edge, bounds.end.x)
		bottom_edge = maxf(bottom_edge, bounds.end.y)
	print("DIALOGUE_METRIC %s lines=%d visible=%d width=%.1f height=%.1f text_right=%.1f text_bottom=%.1f wrap=%d" % [
		case_name, label.get_line_count(), label.get_visible_line_count(), label.size.x, label.size.y,
		right_edge, bottom_edge, label.autowrap_mode
	])
	if label.get_line_count() < min_lines or label.get_visible_line_count() < label.get_line_count() \
		or absf(label.size.x - expected_width) > 1.0 or right_edge > label.size.x or bottom_edge > label.size.y:
		failures.append(case_name)


func _capture_dialogue(name: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image().save_png("user://export_dialogue_%s.png" % name) == OK


func _fail(message: String) -> void:
	push_error("EXPORT_SMOKE_FAILED " + message)
	get_tree().quit(1)
