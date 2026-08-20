extends SceneTree

# CHG-20260817：海盗战入口冒烟——海盗接触弹 4 个难度选项、公式难度按舰队映射、
# 选择难度后写入海盗战请求 meta（供 C# NavalDeploymentController 消费生成随机遭遇）。
# headless 运行：godot --headless --script res://tests/test_sea_overworld_pirate_battle.gd

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const REQUEST_META := "sea_pirate_battle_request"
const RETURN_META := "sea_pirate_battle_return_context"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.remove_meta(REQUEST_META)
	root.remove_meta(RETURN_META)
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.call("reset_runtime_world_state")

	var scene := SEA_SCENE.instantiate() as Node2D
	root.add_child(scene)
	current_scene = scene
	for _frame in range(6):
		await physics_frame
	await process_frame

	var pirates := scene.get("_pirates") as Array
	_expect(pirates.size() == 5, "Sea map must spawn five pirate ships before the battle entry.")
	var battle_pirate: SeaOverworldPirate = null
	for pirate_value in pirates:
		var candidate := pirate_value as SeaOverworldPirate
		if candidate != null and candidate.is_navigation_enabled_for_test():
			battle_pirate = candidate
			break
	_expect(battle_pirate != null, "At least one pirate must be able to trigger the battle dialogue.")
	if battle_pirate == null:
		_finish(scene)
		return
	for pirate_value in pirates:
		var other := pirate_value as SeaOverworldPirate
		if other != battle_pirate:
			other.set_navigation_enabled(false)
	var player := scene.get_node("World/Player") as SeaOverworldPlayer
	player.set_physics_process(false)
	battle_pirate.set_navigation_enabled(true)
	battle_pirate.request_battle_for_test()
	for _frame in range(3):
		await process_frame

	# 4 个难度选项对话框
	var dialogue := scene.get("_event_dialogue") as FieldEventDialogue
	_expect(dialogue.visible and "即将接战" in dialogue.dialogue_label.text, "Touching a pirate must open the battle difficulty dialogue.")
	var option_box := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer
	_expect(option_box.get_child_count() == 4, "The battle dialogue must expose exactly four difficulty options.")
	var option_texts: Array[String] = []
	for child in option_box.get_children():
		if child is Button:
			option_texts.append((child as Button).text)
	for required in ["难度一", "难度二", "难度三", "按我舰强度"]:
		var found := false
		for text in option_texts:
			if required in text:
				found = true
				break
		_expect(found, "Battle dialogue must contain an option mentioning %s (got: %s)." % [required, option_texts])
	_expect(not player.controls_enabled, "The player ship must stop while the difficulty dialogue is open.")

	# 公式难度：默认舰队（5 艘、upgrades 全 0）→ 强度 5 → 难度一。
	var formula_difficulty: int = scene.call("_formula_pirate_difficulty")
	_expect(formula_difficulty == 1, "Formula difficulty must map the default fleet (strength 5) to difficulty one (got %d)." % formula_difficulty)

	# 选择难度 → 写入海盗战请求 meta（C# Deployment 消费后进入正式海战并生成对应难度遭遇）。
	scene.call("_on_event_dialogue_option_selected", &"battle_difficulty_2")
	var request_value: Variant = root.get_meta(REQUEST_META, null)
	_expect(request_value is Dictionary, "Choosing a difficulty must write the pirate battle request meta.")
	if request_value is Dictionary:
		_expect(int(request_value["difficulty"]) == 2, "Requested difficulty must match the chosen option (expected 2).")
		_expect(str(request_value["pirate_id"]) == str(battle_pirate.name), "Request must carry the contacted pirate id.")
		_expect(request_value.get("player_position") is Array, "Request must carry the pre-battle player position.")

	_finish(scene)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(scene: Node) -> void:
	current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	if failures.is_empty():
		print("Sea-overworld pirate battle entry verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
